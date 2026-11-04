---
id: m48-l04
title: Images, feeds and performance
description: "The other deep dive interviewers reach for: a scrolling feed of images. You design an image pipeline stage by stage (memory cache of decoded images, disk cache of encoded bytes with a byte budget, request coalescing, downsampling), size it with memory arithmetic, build an LRU cache with cost-based eviction, decide what to prefetch and cancel as the person scrolls, and merge feed pages and refreshes without duplicates or lost items. Each model is plain Swift, compiled and run."
module: m48
order: 4
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l03, m27-l05, m43-l02]
objectives:
  - Describe an image pipeline from request to pixels and what each stage caches, in which form, under which limit.
  - Compute decoded image memory for a layout and turn it into a memory-cache budget.
  - Implement an LRU cache with a total-cost limit and trace its evictions.
  - Decide which requests to start and cancel from the visible range and scroll direction.
  - Merge next pages and pull-to-refresh results into a feed without duplicates, and detect a gap.
  - Name the performance budgets a feed design should state and how you'd measure them.
terms:
  - term: Image pipeline
    definition: "The chain from an image URL to pixels on screen: memory cache, disk cache, network (with coalescing of duplicate requests), decoding and downsampling, then display."
  - term: LRU (least recently used)
    definition: An eviction policy that removes the entry that was read or written longest ago. With a cost limit, it evicts from the least recently used end until the total cost fits.
  - term: Request coalescing
    definition: When several callers ask for the same resource while a request is already in flight, they share the one request instead of starting new ones.
  - term: Prefetch window
    definition: The range of items just beyond the visible ones whose data is requested ahead of time, so it's ready when they scroll into view.
  - term: Gap
    definition: "In a feed merged from a refresh at the top and older pages below, a range of items the client has never loaded, because the refresh page didn't reach the items it already had."
mastery:
  - Draw the image pipeline and say what each cache holds and how it's limited.
  - Compute decoded memory for a cell size at a screen scale and set a cost limit from it.
  - Trace an LRU cache with a cost limit through a sequence of reads and writes.
  - Compute the prefetch and cancel sets for a scroll position.
  - Merge a refresh into a feed and say whether a gap exists.
resources: [foundation-nscache, uikit-prefetching, xcode-reduce-memory, xcode-understanding-hitches, swiftui-performant-scrollable-stacks, uikit-diffable-data-sources, network-nwpath-isconstrained]
cards:
  - id: m48-l04-c1
    front: What does each cache in an image pipeline hold?
    back: "Memory: decoded images at display size (expensive to make, big), limited by total cost in bytes. Disk: the encoded bytes from the network (small, cheap to keep), limited by a byte budget with LRU eviction. Neither is the source of truth."
  - id: m48-l04-c2
    front: Does NSCache evict in LRU order, and are its limits strict?
    back: "Neither is guaranteed. Apple: \"The order in which the cache evicts objects is not guaranteed,\" and totalCostLimit \"is not a strict limit.\" If you need a guaranteed policy (a disk cache budget), implement it."
  - id: m48-l04-c3
    front: How do you compute an image's memory cost for the cache?
    back: "Decoded pixel width × height × 4 bytes (8-bit RGBA) at the size you decoded it. Pass that as the cost when inserting, and decode at display size, not the source size."
  - id: m48-l04-c4
    front: When does a pull-to-refresh create a gap in a feed?
    back: "When the refresh page is full of new items and none of them is an item you already have. Everything between the refresh page and your old items is unknown. Show a \"load more\" row there, or replace the feed."
  - id: m48-l04-c5
    front: What should happen to image requests for cells that scroll far out of view?
    back: "Cancel them (UICollectionView's prefetching cancel callback, or a task cancelled when the cell is reused). Keep requests for items that are still in the prefetch window, and let coalescing share any request a visible cell needs."
---

## The idea in one sentence

**A feed's performance is decided by its images**: decode them at the size they're shown, cache the decoded pixels in memory under a byte budget and the encoded bytes on disk under another, request ahead in the direction of scrolling and cancel behind it, and merge pages so nothing repeats or disappears.

> [!note] What was checked
> `NSCache` behavior is quoted from Apple's `NSCache` and `totalCostLimit` reference pages; prefetching from the `UICollectionViewDataSourcePrefetching` page; both read in November 2026. The caches, prefetch windows and merges are plain Swift models compiled and run with Swift 6.3. No numbers here come from profiling a device; Module 43's tools are how you'd get real ones.

## The pipeline

Module 27 built a loader with a cache, coalescing and downsampling inside one screen. In a design interview, you draw the whole pipeline and say what each stage holds:

```text
 cell asks for (url, display size)
        │
        ▼
 ┌─ Memory cache ─────────────┐ hit → show immediately (no flicker)
 │ decoded images at display  │
 │ size; cost = bytes; limit  │
 └────────────┬───────────────┘ miss
              ▼
 ┌─ In-flight table ──────────┐ same key already loading → await that task
 └────────────┬───────────────┘ new
              ▼
 ┌─ Disk cache ───────────────┐ hit → decode + downsample off the main actor
 │ encoded bytes by URL;      │
 │ byte budget, LRU eviction  │
 └────────────┬───────────────┘ miss
              ▼
 ┌─ Network ──────────────────┐ request the size you need from the image
 │ discretionary vs           │ server (?w=1080); smaller on Low Data Mode
 │ interactive session        │
 └────────────┬───────────────┘
              ▼
   write bytes to disk → decode at display size → memory cache → cell
```

Decisions to say out loud:

- **Key by URL and display size.** The same photo in a 120-point thumbnail and a full-width header are two different decoded images.
- **Memory holds decoded pixels, disk holds encoded bytes.** Decoding is the expensive part (CPU and memory); bytes are cheap to keep.
- **Ask the server for the size you need.** A CDN that resizes (`?w=1080`) saves data and decoding time; downsampling on the device is the fallback, not the plan.
- **Decode off the main actor**, and never at full resolution for a thumbnail (Module 27's ImageIO downsampling).
- **The disk cache is not storage.** Saved recipes' photos for offline (lesson 1) live in the app's own store with their own budget; the feed cache can be evicted at any time, and the system can purge the Caches directory when space runs low.

## How much memory: the arithmetic

The memory cost of a decoded image depends only on its pixel dimensions: width × height × 4 bytes for 8-bit RGBA. The file size doesn't enter into it.

```swift
func megabytes(_ bytes: Int) -> String {
    let tenths = (bytes + 50_000) / 100_000
    return "\(tenths / 10).\(tenths % 10) MB"
}

func decodedBytes(widthPoints: Int, heightPoints: Int, scale: Int) -> Int {
    (widthPoints * scale) * (heightPoints * scale) * 4
}

let source = 4_032 * 3_024 * 4                         // a 12-megapixel photo, fully decoded
let fullWidth = decodedBytes(widthPoints: 390, heightPoints: 293, scale: 3)
let thumbnail = decodedBytes(widthPoints: 120, heightPoints: 90, scale: 3)

print("Source, decoded:      \(megabytes(source))")
print("Full-width cell @3x:  \(megabytes(fullWidth))")
print("Thumbnail @3x:        \(megabytes(thumbnail))")

// Budget: what's visible, plus a screen ahead and a screen behind.
let visibleCells = 3
let screens = 3
let budget = fullWidth * visibleCells * screens
print("Memory cache budget:  \(megabytes(budget)) for \(visibleCells * screens) full-width images")
```

```output
Source, decoded:      48.8 MB
Full-width cell @3x:  4.1 MB
Thumbnail @3x:        0.4 MB
Memory cache budget:  37.0 MB for 9 full-width images
```

- **Decoding the source for a cell costs about twelve times** what downsampling to the cell does. Three cells decoded at full size would be about 150 MB, which on many devices is close to the point where the system terminates apps for memory (Module 43).
- **The budget comes from the layout**, not from a round number: the visible images, plus one screen in each direction for scrolling back and prefetching. Thirty-seven megabytes is a defensible number to say, and you can set `NSCache.totalCostLimit` from it, passing each image's decoded bytes as its cost.
- **On memory warnings**, drop the memory cache entirely. Everything in it can be recreated from disk.

`NSCache` is a fine memory cache, as long as you know what it doesn't promise. Apple's documentation says the cache "may automatically evict objects until its total cost falls below `totalCostLimit`. The order in which the cache evicts objects is not guaranteed," and that the limit "is not a strict limit." It's also safe to use from several threads without your own lock. For the disk cache, where you do want a guaranteed policy and an exact byte budget, you write one.

## An LRU cache with a cost limit

The disk cache's index: keys with sizes, ordered by last use, evicting from the least recently used end when the total exceeds the budget. A doubly linked list over the keys gives O(1) reads, writes and evictions:

```swift
final class LRUCache {
    private struct Node {
        var cost: Int
        var newer: String?
        var older: String?
    }

    private var nodes: [String: Node] = [:]
    private var newest: String?
    private var oldest: String?
    private(set) var totalCost = 0
    let costLimit: Int

    init(costLimit: Int) {
        self.costLimit = costLimit
    }

    /// Reading an entry makes it the most recently used.
    func get(_ key: String) -> Bool {
        guard nodes[key] != nil else { return false }
        moveToNewest(key)
        return true
    }

    /// Inserts or replaces an entry, then evicts least recently used entries until the total fits.
    /// Returns the evicted keys, oldest first.
    @discardableResult
    func set(_ key: String, cost: Int) -> [String] {
        guard cost <= costLimit else { return [] }            // would evict everything and still not fit
        if let existing = nodes[key] {
            totalCost += cost - existing.cost
            nodes[key]!.cost = cost
            moveToNewest(key)
        } else {
            nodes[key] = Node(cost: cost, newer: nil, older: newest)
            if let newest { nodes[newest]!.newer = key }
            newest = key
            if oldest == nil { oldest = key }
            totalCost += cost
        }
        var evicted: [String] = []
        while totalCost > costLimit, let victim = oldest {
            remove(victim)
            evicted.append(victim)
        }
        return evicted
    }

    var keysNewestFirst: [String] {
        var result: [String] = []
        var cursor = newest
        while let key = cursor {
            result.append(key)
            cursor = nodes[key]!.older
        }
        return result
    }

    private func moveToNewest(_ key: String) {
        guard newest != key, let node = nodes[key] else { return }
        let cost = node.cost
        remove(key)
        set(key, cost: cost)
    }

    private func remove(_ key: String) {
        guard let node = nodes.removeValue(forKey: key) else { return }
        if let newer = node.newer { nodes[newer]!.older = node.older } else { newest = node.older }
        if let older = node.older { nodes[older]!.newer = node.newer } else { oldest = node.newer }
        totalCost -= node.cost
    }
}

let cache = LRUCache(costLimit: 100)
@MainActor                          // top-level code runs on the main actor; so does this helper
func show(_ action: String, _ evicted: [String] = []) {
    let note = evicted.isEmpty ? "" : "  evicted \(evicted)"
    print("\(action): \(cache.keysNewestFirst) total \(cache.totalCost)\(note)")
}

show("set a 40", cache.set("a", cost: 40))
show("set b 30", cache.set("b", cost: 30))
show("set c 20", cache.set("c", cost: 20))
_ = cache.get("a")
show("get a")
show("set d 25", cache.set("d", cost: 25))
show("set e 70", cache.set("e", cost: 70))
show("set f 150", cache.set("f", cost: 150))
show("set e 10", cache.set("e", cost: 10))
```

```output
set a 40: ["a"] total 40
set b 30: ["b", "a"] total 70
set c 20: ["c", "b", "a"] total 90
get a: ["a", "c", "b"] total 90
set d 25: ["d", "a", "c"] total 85  evicted ["b"]
set e 70: ["e", "d"] total 95  evicted ["c", "a"]
set f 150: ["e", "d"] total 95
set e 10: ["e", "d"] total 35
```

- **Reading `a` saved it.** When `d` pushed the total to 115, the least recently used entry was `b`, not `a`, even though `a` was inserted first.
- **One insert can evict several entries.** Adding `e` (70) brought the total to 155; the loop removed the oldest entries, `c` and then `a`, until it fit at 95.
- **`f` is larger than the whole budget** and is refused rather than emptying the cache for nothing. A pipeline would still show it, just not cache it.
- **Replacing `e` with a smaller cost** updates the total and moves it to the newest end.
- On disk, the index lives in a small database or file next to the cached files, the cache writes "last used" lazily (not on every read, which would be a disk write per scroll), and eviction runs off the main actor, at launch or after writes.

## Prefetching: start ahead, cancel behind

`UICollectionViewDataSourcePrefetching` (and `UITableView`'s equivalent) tells you which index paths are coming up and which are no longer needed. Apple's page has the important caveat: the prefetch method "isn't necessarily called for every cell," so the cell's own load must handle three cases: already loaded, loading, and not requested. Coalescing in the pipeline covers that: the cell asks for the same key, and joins the prefetch's request if one is in flight.

In SwiftUI there's no prefetching callback, so you compute the window yourself from the visible range. Either way, the decision is the same:

```swift
/// Indices to keep loading: the visible range plus `ahead` items in the scroll direction
/// and `behind` items in the other direction.
func window(visible: ClosedRange<Int>, scrollingDown: Bool, ahead: Int, behind: Int, count: Int) -> Set<Int> {
    let before = scrollingDown ? behind : ahead
    let after = scrollingDown ? ahead : behind
    let low = max(0, visible.lowerBound - before)
    let high = min(count - 1, visible.upperBound + after)
    return Set(low...high)
}

struct Prefetcher {
    var inFlight: Set<Int> = []

    mutating func scroll(to visible: ClosedRange<Int>, down: Bool) {
        let wanted = window(visible: visible, scrollingDown: down, ahead: 6, behind: 2, count: 40)
        let start = wanted.subtracting(inFlight).sorted()
        let cancel = inFlight.subtracting(wanted).sorted()
        inFlight = wanted
        print("visible \(visible) \(down ? "down" : "up"): start \(start), cancel \(cancel)")
    }
}

var prefetcher = Prefetcher()
prefetcher.scroll(to: 0...2, down: true)
prefetcher.scroll(to: 3...5, down: true)
prefetcher.scroll(to: 30...32, down: true)
prefetcher.scroll(to: 28...30, down: false)
prefetcher.scroll(to: 37...39, down: true)
```

```output
visible 0...2 down: start [0, 1, 2, 3, 4, 5, 6, 7, 8], cancel []
visible 3...5 down: start [9, 10, 11], cancel [0]
visible 30...32 down: start [28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38], cancel [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
visible 28...30 up: start [22, 23, 24, 25, 26, 27], cancel [33, 34, 35, 36, 37, 38]
visible 37...39 down: start [35, 36, 37, 38, 39], cancel [22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
```

- **The window is asymmetric**: six ahead, two behind, and it flips when the scroll direction flips (the fourth call).
- **A fast fling cancels a lot.** Jumping to item 30 cancels eleven requests the person will never see. Without cancellation they'd still download, compete with the visible cells for bandwidth, and fill the caches with images nobody looked at.
- **Cancelling isn't free if it's naive**: a cancelled download that was 90% done is wasted. A common refinement is to cancel only requests that haven't started receiving data, or to lower the priority of the rest. Say it as a trade-off; this model doesn't do it.
- **The ends are clamped** to the feed's bounds. The window near the end is also the natural trigger for loading the next page.

On Low Data Mode or an expensive network (Module 43), shrink `ahead` and request smaller images; prefetching is discretionary work.

## Feed pages: merge without duplicates or holes

Lesson 2's contract pages backward with a cursor. A feed also refreshes at the top. The client merges both into one list, and two things go wrong: **duplicates** (an item arrives twice, which crashes a diffable data source that requires unique identifiers) and **gaps** (a refresh with many new items doesn't reach the ones you already had).

```swift
struct Post: Equatable {
    let id: Int
    var likes: Int
}

struct Feed {
    var items: [Post] = []
    var gapAfterIndex: Int? = nil          // a "load more" row goes after this index

    /// An older page, appended at the bottom. Known items are updated in place, not repeated.
    mutating func appendPage(_ page: [Post]) {
        for post in page {
            if let index = items.firstIndex(where: { $0.id == post.id }) {
                items[index] = post
            } else {
                items.append(post)
            }
        }
    }

    /// The newest page, from pull to refresh. If it doesn't overlap what we have, there's a gap.
    mutating func applyRefresh(_ page: [Post]) {
        let known = Set(items.map(\.id))
        let overlaps = page.contains { known.contains($0.id) }
        let fresh = page.filter { !known.contains($0.id) }
        for post in page where known.contains(post.id) {
            items[items.firstIndex { $0.id == post.id }!] = post
        }
        items.insert(contentsOf: fresh, at: 0)
        if let gap = gapAfterIndex { gapAfterIndex = gap + fresh.count }
        if !overlaps && !fresh.isEmpty && fresh.count < items.count { gapAfterIndex = fresh.count - 1 }
    }

    func render() -> String {
        var parts: [String] = []
        for (index, post) in items.enumerated() {
            parts.append(post.likes > 0 ? "\(post.id)(♥\(post.likes))" : "\(post.id)")
            if index == gapAfterIndex { parts.append("[gap]") }
        }
        return parts.joined(separator: " ")
    }
}

var feed = Feed()
feed.appendPage([Post(id: 10, likes: 0), Post(id: 9, likes: 0), Post(id: 8, likes: 0)])
print("page 1:          ", feed.render())

// Offset-style overlap: the next page repeats 8 because something was inserted upstream.
feed.appendPage([Post(id: 8, likes: 3), Post(id: 7, likes: 0), Post(id: 6, likes: 0)])
print("page 2:          ", feed.render())

feed.applyRefresh([Post(id: 12, likes: 0), Post(id: 11, likes: 0), Post(id: 10, likes: 5)])
print("small refresh:   ", feed.render())

feed.applyRefresh([Post(id: 20, likes: 0), Post(id: 19, likes: 0), Post(id: 18, likes: 0)])
print("large refresh:   ", feed.render())
```

```output
page 1:           10 9 8
page 2:           10 9 8(♥3) 7 6
small refresh:    12 11 10(♥5) 9 8(♥3) 7 6
large refresh:    20 19 18 [gap] 12 11 10(♥5) 9 8(♥3) 7 6
```

- **Post 8 arrived twice** and was updated in place with its new like count, not repeated.
- **The small refresh overlapped** (post 10 was already there), so the feed is continuous, and post 10's likes were updated.
- **The large refresh didn't overlap**: posts 13 to 17 may exist and the client has never seen them. The gap row loads them with a cursor that starts after post 18. The alternative many apps choose is simpler: if a refresh doesn't overlap, replace the whole feed and scroll to the top. Say which you'd do and why.
- **`firstIndex(where:)` is O(n)** per item. For a feed of a few hundred items it doesn't matter; for thousands, keep a dictionary from ID to index next to the array.
- **Keep the scroll position**: inserting at the top of a list the person is reading moves everything down. Show a "New posts" pill and insert when they tap it or scroll to the top.

## Performance budgets to state

Lesson 1's habit applies: name numbers and how you'd measure them (Module 43 has the tools).

| Budget | Example target | Measured with |
| --- | --- | --- |
| Time to first content at launch | Cached feed visible within about a second on a mid-range device | Signposts, XCTest launch metrics, MetricKit in the field |
| Scrolling | No hitches you can see; frames delivered on time | Instruments hitches tool, MetricKit hitch rate |
| Memory | Memory cache under its computed budget; no growth over a long scroll | Xcode memory gauge, Allocations, a long-scroll UI test |
| Data per session | About the estimate from lesson 1; much less on Low Data Mode | Network instrument, server logs per app version |
| Image load time | Visible images mostly from memory or disk when scrolling back | Cache hit rate counters in your own telemetry |

The targets are this design's choices, not Apple's numbers. In an interview, saying "I'd set a budget, measure it on the oldest supported device, and alert on regressions" matters more than the exact value.

## Common mistakes

> [!error] Caching full-resolution decoded images
> A 12-megapixel photo is about 49 MB decoded. Decode at display size and key the cache by URL and size.

> [!error] Assuming NSCache is LRU with a hard limit
> Apple says the eviction order isn't guaranteed and the limit isn't strict. That's fine for a memory cache; implement your own policy for a disk budget.

> [!error] Treating the disk cache as storage
> The feed cache can be evicted and Caches can be purged. Images the person saved for offline go in the app's own store.

> [!error] Prefetching without cancelling
> A fast fling queues dozens of downloads nobody will see. Cancel requests outside the window, and coalesce so a visible cell can reuse a prefetch.

> [!error] Appending pages without de-duplicating
> Repeated IDs show duplicates or crash a diffable data source. Merge by ID.

> [!error] Ignoring the gap after a large refresh
> If the refresh doesn't overlap, items between are missing. Mark the gap or replace the feed.

## Exercises

````exercise
id: m48-l04-e1
type: prediction
prompt: "The lesson's LRU cache with a limit of 50. What does it print?"
code: |
  final class LRU {
      private var order: [String] = []           // oldest first
      private var costs: [String: Int] = [:]
      private(set) var total = 0
      let limit: Int
      init(limit: Int) { self.limit = limit }

      func get(_ key: String) {
          guard let index = order.firstIndex(of: key) else { return }
          order.append(order.remove(at: index))
      }

      func set(_ key: String, cost: Int) -> [String] {
          guard cost <= limit else { return [] }
          if let index = order.firstIndex(of: key) {
              order.remove(at: index)
              total -= costs[key]!
          }
          order.append(key)
          costs[key] = cost
          total += cost
          var evicted: [String] = []
          while total > limit {
              let victim = order.removeFirst()
              total -= costs.removeValue(forKey: victim)!
              evicted.append(victim)
          }
          return evicted
      }
  }

  let cache = LRU(limit: 50)
  print(cache.set("x", cost: 20))
  print(cache.set("y", cost: 20))
  cache.get("x")
  print(cache.set("z", cost: 20))
  print(cache.set("w", cost: 45))
  print(cache.set("v", cost: 60), cache.total)
output: |
  []
  []
  ["y"]
  ["x", "z"]
  [] 45
hints:
  - "After get(\"x\"), the order from oldest is y, x."
  - "Adding w (45) to x and z (40) makes 85; evict from the oldest until ≤ 50."
solution: |
  ```output
  []
  []
  ["y"]
  ["x", "z"]
  [] 45
  ```

  Reading `x` makes `y` the oldest, so adding `z` (total 60) evicts `y`. Adding `w` gives 85: evicting `x` leaves 65, still over, so `z` goes too, leaving 45. `v` costs more than the whole limit and is refused, so the total stays 45. This version uses an array (O(n) per operation), which is fine for a quiz; the lesson's linked list makes each operation O(1).
````

````exercise
id: m48-l04-e2
type: comprehension
prompt: "A feed's memory cache uses NSCache with totalCostLimit set to 40 MB, and each image's cost is its JPEG file size. What's the problem?"
choices:
  - text: "The cost underestimates memory by an order of magnitude, because decoded images take width × height × 4 bytes, not the file size."
    correct: true
    why: "A 300 KB JPEG might be 4 MB decoded; the cache thinks it holds 40 MB of images while holding hundreds of megabytes."
  - text: "NSCache can't be used from background threads."
    correct: false
    why: "Apple: you can add, remove and query items from different threads without locking."
  - text: "totalCostLimit is in kilobytes, not bytes."
    correct: false
    why: "The cost is whatever unit you choose; Apple's documentation suggests the object's size in bytes. Consistency is what matters."
  - text: "NSCache always evicts the oldest image first, which is wrong for feeds."
    correct: false
    why: "The eviction order isn't guaranteed at all."
solution: |
  The cost has to describe what the cache actually holds: decoded pixels. Compute it from the decoded image's pixel dimensions (width × height × 4 for 8-bit RGBA) when you insert. With file sizes as costs, the limit is meaningless and the app can be terminated for memory during a long scroll.
````

````exercise
id: m48-l04-e3
type: solve
prompt: |
  Write `prefetchPlan(visible:down:ahead:behind:count:inFlight:)` returning `(start, cancel)` as sorted arrays, using the lesson's window rule: `ahead` items in the scroll direction, `behind` in the other, clamped to `0...count-1`.

  Expected output:

  ```output
  start [0, 1, 2, 3, 4], cancel []
  start [5, 6, 7], cancel [0, 1]
  start [8], cancel [2]
  ```
starter: |
  func prefetchPlan(visible: ClosedRange<Int>, down: Bool, ahead: Int, behind: Int, count: Int,
                    inFlight: Set<Int>) -> (start: [Int], cancel: [Int]) {
      // your code
      return ([], [])
  }

  var current: Set<Int> = []
  for (visible, down) in [(0...1, true), (3...4, true), (6...7, false)] {
      let plan = prefetchPlan(visible: visible, down: down, ahead: 3, behind: 1, count: 10, inFlight: current)
      print("start \(plan.start), cancel \(plan.cancel)")
      current = current.union(plan.start).subtracting(plan.cancel)
  }
hints:
  - "Before the visible range you keep `behind` items when scrolling down and `ahead` when scrolling up."
  - "Start is wanted minus in flight; cancel is in flight minus wanted."
rubric:
  - Swaps ahead and behind by direction.
  - Clamps to the feed's bounds.
  - Computes start and cancel as set differences, sorted.
solution: |
  ```swift
  func prefetchPlan(visible: ClosedRange<Int>, down: Bool, ahead: Int, behind: Int, count: Int,
                    inFlight: Set<Int>) -> (start: [Int], cancel: [Int]) {
      let before = down ? behind : ahead
      let after = down ? ahead : behind
      let wanted = Set(max(0, visible.lowerBound - before)...min(count - 1, visible.upperBound + after))
      return (wanted.subtracting(inFlight).sorted(), inFlight.subtracting(wanted).sorted())
  }

  var current: Set<Int> = []
  for (visible, down) in [(0...1, true), (3...4, true), (6...7, false)] {
      let plan = prefetchPlan(visible: visible, down: down, ahead: 3, behind: 1, count: 10, inFlight: current)
      print("start \(plan.start), cancel \(plan.cancel)")
      current = current.union(plan.start).subtracting(plan.cancel)
  }
  ```

  ```output
  start [0, 1, 2, 3, 4], cancel []
  start [5, 6, 7], cancel [0, 1]
  start [8], cancel [2]
  ```

  - **0...1, down:** one behind is clamped at 0, three ahead reaches 4, so the window is 0...4.
  - **3...4, down:** the window is 2...7. Items 2, 3 and 4 are already in flight, so only 5, 6 and 7 start; 0 and 1 fell out and are cancelled.
  - **6...7, up:** the direction flipped, so three go before the visible range and one after: 3...8. Item 8 starts and item 2 is cancelled.

  The set differences do all the bookkeeping. In an app, "start" and "cancel" become calls into the image pipeline, which coalesces a start for a key that's already loading.
````

````exercise
id: m48-l04-e4
type: find-errors
prompt: "An image loader proposed for Mise's feed. Mark every real problem."
code: |
  - Memory cache: a Dictionary<URL, UIImage> with no limit, cleared on logout.
  - Images are decoded at full size and scaled by the image view.
  - Disk cache: files in Documents, never deleted.
  - Each cell starts its own download in cellForItemAt; no cancellation.
  - Prefetching downloads the next 50 images on any network.
choices:
  - text: "An unbounded dictionary grows until the system terminates the app; no cost limit, no response to memory warnings."
    correct: true
  - text: "Full-size decoding wastes memory and CPU; decode at display size."
    correct: true
  - text: "A cache in Documents is backed up and never trimmed; caches belong in Caches with a byte budget."
    correct: true
  - text: "No coalescing or cancellation: duplicate downloads, wrong images in reused cells, wasted bandwidth after a fling."
    correct: true
  - text: "Prefetching 50 images regardless of Low Data Mode or an expensive network."
    correct: true
  - text: "Keying the memory cache by URL is wrong; it should be keyed by index path."
    correct: false
    why: "Index paths change as the feed changes. URL (plus display size) is the right key."
rubric:
  - I flagged the unbounded memory cache.
  - I flagged full-size decoding.
  - I flagged the disk cache location and lack of budget.
  - I flagged per-cell downloads without coalescing or cancellation.
  - I flagged unconditional prefetching.
solution: |
  All but the index-path point are real problems. The fixes are the pipeline in this lesson: `NSCache` with a cost of decoded bytes and a limit from the layout; downsampling to display size off the main actor; a disk cache in Caches with an LRU byte budget; an in-flight table that coalesces requests and lets cells cancel; and a prefetch window that shrinks on constrained or expensive paths. Key by URL and display size (or the CDN's sized URL), never by index path.
````

````exercise
id: m48-l04-e5
type: explain
prompt: "Explain what this merge does wrong when the refresh page has three new posts and none of the old ones, and propose two fixes with their costs."
code: |
  mutating func applyRefresh(_ page: [Post]) {
      let known = Set(items.map(\.id))
      items.insert(contentsOf: page.filter { !known.contains($0.id) }, at: 0)
  }
rubric:
  - Identifies that items between the refresh page and the old feed are silently missing.
  - Proposes a gap marker with a "load more" row, and its cost (extra UI state and a cursor for the gap).
  - Proposes replacing the feed when there's no overlap, and its cost (losing the person's place and loaded pages).
  - Notes that existing items in the page aren't updated in place either.
solution: |
  With no overlap, the feed shows the three newest posts directly above the old ones, as if nothing came between them. Anything published between them is silently missing, and the person has no way to load it.

  - **Gap marker:** remember that the boundary is a gap and show a "Load more" row there that pages from after the last refreshed post. Costs: extra state in the feed model, a cursor per gap, and a row type in the list.
  - **Replace on no overlap:** throw away the old items and start from the refresh page, scrolling to the top. Simple, but the person loses their place and the pages they'd loaded. Fine for a news feed people skim; poor for a timeline people read carefully.

  The snippet also ignores updated versions of items it already has (new like counts); merge those in place.
````

````exercise
id: m48-l04-e6
type: design
prompt: "Design the image handling for Mise's recipe detail screen: one large hero photo (full width, 4:3) and up to 20 step photos in a horizontal carousel. Give the memory math at 3x for a 390-point-wide screen, the cache keys, what's prefetched and when, and what changes under Low Data Mode."
rubric:
  - Computes the hero's decoded size (about 390 × 293 points → 1,170 × 879 pixels → about 4.1 MB).
  - Sizes the carousel photos to their display size and limits how many are decoded at once.
  - Keys by URL and display size; separates the saved-for-offline store from the evictable cache.
  - Prefetches the next one or two carousel photos, cancels when the person leaves the screen.
  - Requests smaller variants and avoids prefetching on Low Data Mode or expensive networks.
solution: |
  - **Hero:** 390 × 293 points at 3x is 1,170 × 879 pixels, about 4.1 MB decoded. Request a 1,200-pixel-wide variant from the image server and decode at display size.
  - **Carousel:** if each photo shows at 300 × 225 points, that's 900 × 675 pixels, about 2.4 MB decoded. Twenty decoded at once would be about 49 MB, so keep only the visible one and its neighbors decoded; the rest stay as bytes on disk.
  - **Keys:** URL plus pixel size. Saved recipes store their hero and step photos in the app's own store (lesson 1's offline budget); the feed cache stays evictable.
  - **Prefetch:** when the screen opens, the hero first, then the first two carousel photos. As the person swipes, prefetch the next one or two and cancel anything more than two away. Leaving the screen cancels everything that hasn't started receiving data.
  - **Low Data Mode:** request smaller variants (for example 600 pixels wide), don't prefetch carousel photos, and load each when it becomes visible.
````

## Summary

- The pipeline is memory cache (decoded, by URL and size, cost-limited), coalesced in-flight requests, disk cache (encoded bytes, byte budget, LRU), then the network, asking the server for the size you need.
- Decoded images cost width × height × 4 bytes. Decode at display size, and derive the memory budget from the layout.
- `NSCache` doesn't guarantee its eviction order or a strict limit; implement LRU with a cost limit where you need a guaranteed policy.
- Prefetch a window ahead in the scroll direction, cancel what falls out of it, and shrink it on constrained networks.
- Merge pages by ID, update known items in place, and detect gaps when a refresh doesn't overlap.
- State budgets for launch, scrolling, memory, data and image load time, and say how you'd measure each.
