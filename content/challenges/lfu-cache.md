---
id: lfu-cache
title: LFU Cache
difficulty: hard
order: 95
patterns: [Hash map, Doubly linked list, Data structure design]
prerequisites: [m17-l03, m48-l04]
summary: Build a cache that evicts the least frequently used entry, breaking ties by recency, with O(1) get and put. The LRU design from Module 48, one list per use count.
solutionFile: LFUCache.swift
testFile: LFUCacheTests.swift
starter: |
  final class LFUCache<Key: Hashable, Value> {
      let capacity: Int

      init(capacity: Int) {
          self.capacity = capacity
      }

      func get(_ key: Key) -> Value? {
          // Your solution
          return nil
      }

      func put(_ key: Key, _ value: Value) {
          // Your solution
      }
  }
time: O(1) on average for get and put
space: O(capacity)
edgeCases:
  - Capacity 0, which stores nothing
  - Capacity 1, where every new key replaces the old one
  - Updating an existing key, which counts as a use and never evicts
  - A tie on use count, broken by least recent use
  - A miss, which changes nothing
  - A new key evicting while a heavily used key stays
askInterviewer:
  - Does put on an existing key count as a use?
  - How are ties on use count broken?
  - Does a miss count for anything?
  - Does it need to be thread-safe?
hints:
  - Start from the LRU cache, a dictionary for lookups plus a linked list in recency order. What's missing to find the least frequently used entry?
  - Group the entries by use count, and keep each group in recency order. Which entry gets evicted from which group?
  - The smallest use count in the cache only changes in two ways, a new key arrives (it becomes 1), or the last entry with the smallest count gets used (it goes up by 1).
followUps:
  - Make it safe to call from several tasks. (An actor, or a lock around each method.)
  - Add a cost per entry and a total cost limit, as in Module 48's LRU.
  - Use counts grow forever, so an entry that was popular last month never leaves. How would you age them?
rubric:
  - I described the O(n) scan version and why it doesn't meet the requirement.
  - I designed one recency-ordered list per use count, plus a dictionary from key to entry.
  - I kept the smallest use count up to date in O(1) on use and on insert.
  - I handled capacity 0, updates and ties.
codeStatus: tested
---

An image pipeline wants a memory cache that keeps the images people come back to, not just the ones they saw last. Build `LFUCache` with a fixed `capacity`:

- `get(key)` returns the value, or `nil` if the key isn't there.
- `put(key, value)` inserts or replaces the value.

When a new key arrives and the cache is full, evict the entry that has been **used the fewest times**. If several entries tie, evict the **least recently used** of them. Both a `get` that finds the key and a `put` count as a use. Both operations must be O(1) on average. A capacity of 0 stores nothing.

```swift
let cache = LFUCache<String, Int>(capacity: 2)
cache.put("a", 1)
cache.put("b", 2)
cache.get("a")       // 1. a has 2 uses, b has 1
cache.put("c", 3)    // full: evicts b, the least used
cache.get("b")       // nil
cache.get("c")       // 3. a and c both have 2 uses; c is more recent
cache.put("d", 4)    // tie on uses: evicts a, the least recently used
cache.get("a")       // nil
```

**Constraints:** `0 ≤ capacity ≤ 10^4`; up to `2 · 10^5` calls.

<!-- reveal -->

## First approach

Module 48, lesson 4 built an LRU cache with a dictionary and a doubly linked list in recency order, so the oldest entry is always at the end of the list. LFU adds a second key, the use count, with recency only as the tie-breaker. So keep **one recency list per use count**. The victim is the oldest entry in the list for the smallest count. Using an entry moves it from the list for `k` to the newest end of the list for `k + 1`, which is O(1) with links.

## Naive solution

Keep an array of entries with a use count and the time of the last use, and scan it:

```swift
final class LFUCache<Key: Hashable, Value> {
    private struct Entry {
        let key: Key
        var value: Value
        var uses: Int
        var lastUsed: Int
    }

    let capacity: Int
    private var entries: [Entry] = []
    private var clock = 0

    init(capacity: Int) {
        self.capacity = capacity
    }

    func get(_ key: Key) -> Value? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        clock += 1
        entries[index].uses += 1
        entries[index].lastUsed = clock
        return entries[index].value
    }

    func put(_ key: Key, _ value: Value) {
        guard capacity > 0 else { return }
        clock += 1
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries[index].value = value
            entries[index].uses += 1
            entries[index].lastUsed = clock
            return
        }
        if entries.count == capacity {
            let victim = entries.indices.min { a, b in
                (entries[a].uses, entries[a].lastUsed) < (entries[b].uses, entries[b].lastUsed)
            }!
            entries.remove(at: victim)
        }
        entries.append(Entry(key: key, value: value, uses: 1, lastUsed: clock))
    }
}
```

## Problems with the naive solution

Every `get` scans for the key and every eviction scans for the minimum: O(capacity) per call, so 2 · 10^5 calls on a full cache of 10^4 entries is around 2 · 10^9 comparisons. A dictionary fixes the lookup, and a heap ordered by (uses, lastUsed) would make eviction O(log n), but a use changes an entry's priority, and updating an arbitrary heap element needs extra bookkeeping. The lists-per-count design gets O(1) for everything.

## Optimized solution

Three pieces of state:

- `entries: [Key: Entry]`, where each entry holds its value, its use count and the keys of its newer and older neighbors in its count's list. Links are keys rather than object references, as in Module 48's LRU, so there are no reference cycles to manage.
- `buckets: [Int: Bucket]`, the newest and oldest key of the list for each use count that has entries.
- `fewestUses`, the smallest use count present.

Using a key unlinks it from its list, bumps its count and links it at the newest end of the next list. Inserting a key evicts `buckets[fewestUses].oldest` if the cache is full, then links the new key into the list for 1 and sets `fewestUses = 1`.

## Line by line

- `get`: on a miss, `return nil` before touching anything, so misses don't change counts or order. On a hit, `recordUse(of:)` then return the value read before the move.
- `put`, `guard capacity > 0`: with no room, inserting and then evicting would be wasted work, and the eviction lookup would find nothing.
- `put` on an existing key: replace the value and record a use. The size doesn't change, so nothing is evicted.
- `if entries.count == capacity, let victim = buckets[fewestUses]?.oldest`: the least used entry, and among those the least recent, is the oldest in the list for the smallest count.
- `fewestUses = 1`: the new key has one use, and no entry can have fewer.
- `recordUse(of:)`: after `unlink(key)`, if the key was the last one in the list for `fewestUses`, the smallest count is now `uses + 1`, which is exactly where the key is going. That's the only other way the minimum changes.
- `link(_:)`: the key's `older` becomes the list's current newest, and that key's `newer` becomes this one. An empty list gets this key as both ends.
- `unlink(_:)`: neighbors point past the key; if it was an end of the list, the end moves. `buckets[entry.uses] = bucket.newest == nil ? nil : bucket` drops the list when it empties, which is what `recordUse` checks.

## Common mistakes

- Evicting by count alone, without a recency order inside each count, so ties go to an arbitrary key.
- Recomputing the smallest count by scanning `buckets` after every use, which is O(number of distinct counts).
- Updating `fewestUses` on eviction instead of on insert. After an eviction a new key always arrives with count 1.
- Not counting `put` on an existing key as a use, or evicting on an update when the cache is full.
- Using class nodes with strong references in both directions, which leaks: each node keeps its neighbors alive.

## Variation

**LFU with aging:** halve every use count once a day, or count uses in a recent time window only, so yesterday's popular images don't stay forever. Halving every entry is O(n) once per period, which is a fine price if it runs off the main path.
