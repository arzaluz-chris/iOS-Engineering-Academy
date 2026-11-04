---
id: m43-l02
title: Hangs, memory and battery
description: "Three ways an app degrades on real devices without ever crashing in testing. You learn the hang thresholds Apple's tools use and how Organizer computes a hang rate, find hangs with the Thread Performance Checker, on-device hang detection and Instruments, and move work off the main actor; you tell memory footprint from leaks and abandoned memory, read a jetsam report and respond to memory warnings; and you cut energy use the way Apple describes it: batch networking, back off background refreshes, stop location updates you don't need, and adapt to Low Power Mode and thermal state."
module: m43
order: 2
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m43-l01, m21-l03, m13-l05]
objectives:
  - State the hang thresholds Apple documents and explain how Organizer's hang rate is computed.
  - Choose a tool to find hangs during development and in shipped builds, and fix a hang by moving work off the main actor.
  - Distinguish memory footprint, leaks and abandoned memory, and read the reason and size of a jetsam event.
  - Respond to memory warnings without making memory pressure worse.
  - Reduce energy use by batching network work, backing off background refreshes, using location only when needed, and adapting to Low Power Mode and thermal state.
terms:
  - term: Hang
    definition: "A noticeable delay in responding to a discrete interaction, almost always caused by long-running or blocked work on the main thread. Apple's tools mostly report main run loop unresponsiveness over 250 ms."
  - term: Hang rate
    definition: "Xcode Organizer's metric: seconds per hour that the app is unresponsive, counting only periods longer than 250 ms, shown as the median and the 90th percentile."
  - term: Memory footprint
    definition: "The memory your app allocated that must stay in RAM. The system's memory limit applies to it; os_proc_available_memory() returns the limit minus the current footprint."
  - term: Jetsam event
    definition: "The system terminating processes to reclaim memory under pressure. The jetsam event report (JSON, no backtraces) records each process's memory pages and, for the terminated one, a reason such as per-process-limit."
  - term: Abandoned memory
    definition: "Memory the app can still reach but no longer uses, such as a dictionary of messages that only grows. Leak detection doesn't report it, because nothing is unreachable."
  - term: Thermal state
    definition: "ProcessInfo.thermalState: nominal, fair, serious or critical. Apple's guidance scales back work at each level, up to stopping power-intensive subsystems at critical."
mastery:
  - Turn a main-thread timeline into busy periods and say which are hangs, which get a hang report backtrace, and the hang rate.
  - Fix a hang caused by synchronous decoding in a main-actor task.
  - Compute an app's memory from a jetsam report and say what the reason means.
  - Bound a cache that grows with scrolling, and purge on a memory warning.
  - Design a background refresh with Apple's exponential backoff and a batched analytics upload.
  - Map Low Power Mode and thermal state to concrete feature changes.
resources: [understanding-hangs, xcode-memory-use, xcode-reduce-memory, metrickit, swift-mainactor, foundation-nscache, foundation-urlsessionconfiguration]
cards:
  - id: m43-l02-c1
    front: What thresholds does Apple use for hangs?
    back: "Delays over 100 ms in a discrete interaction become noticeable. Most of Apple's tools report main run loop unresponsiveness over 250 ms; Organizer's hang rate counts only periods over 250 ms, and the system samples a backtrace for hang reports when the main thread is unresponsive for 1 s or longer."
  - id: m43-l02-c2
    front: Three tools to find hangs before release?
    back: "The Thread Performance Checker in the scheme (priority inversions, non-UI work on the main thread), on-device Hang Detection (Settings > Developer, for development and TestFlight builds), and the Hangs instrument in the Time Profiler and related Instruments templates."
  - id: m43-l02-c3
    front: Leak versus abandoned memory?
    back: "A leak is unreachable memory that's never freed (often a retain cycle); the Leaks instrument finds it. Abandoned memory is still reachable but unused, like a cache that only grows; only the Allocations instrument's generations or a memory graph show it."
  - id: m43-l02-c4
    front: How do you read a jetsam report?
    back: "Find the process with a reason key (only the terminated one has it). per-process-limit means it crossed its memory limit; vm-pageshortage means the system reclaimed background memory for the foreground app. Memory in bytes is rpages × pageSize from the header."
  - id: m43-l02-c5
    front: Apple's backoff for a failed BGAppRefreshTask?
    back: "Exponential: retry after 5 minutes by setting earliestBeginDate, then 10, then 20, and so on. Call setTaskCompleted(success:) promptly either way so the device can sleep."
---

## The idea in one sentence

Hangs, memory terminations and battery drain rarely show up on a developer's phone, so **you learn the thresholds the system uses, measure against them, and change the app's behavior to fit the device it's on**, not the device you test with.

> [!note] Sources and what was checked
> Thresholds and tool descriptions come from Apple's "Understanding hangs in your app", "Improving app responsiveness", "Analyzing responsiveness issues in your shipping app", "Diagnosing performance issues early", "Addressing watchdog terminations", "Identifying high-memory use with jetsam event reports", "Responding to low-memory warnings", "Making changes to reduce memory use", "Gathering information about memory use", `os_proc_available_memory`, "Analyzing your app's battery use", "Reducing your app's battery use", "Scheduling CPU work efficiently", "Reducing networking and Bluetooth power usage", "Accessing the device's location efficiently" and "Responding to power notifications", all read in November 2026. Instruments, Organizer and the device's Developer settings weren't used for this lesson. The UIKit and Foundation blocks are type-checked against the iOS SDK, not run. The timeline, jetsam, cache, backoff and policy models are plain Swift, compiled and run with Swift 6.3, on invented data except where a number is attributed to Apple.

## Hangs

Module 21 explained why one busy main thread freezes everything, and Module 39 measured hitches in SwiftUI. This section is about finding hangs in an app you didn't write.

### The thresholds

From Apple's documentation:

- "A delay of less than 100 ms in a discrete user interaction is rarely noticeable, but even a few hundred milliseconds can make people feel that an app is unresponsive."
- "Most of Apple's developer tools start reporting issues when the period of unresponsiveness for the main run loop exceeds 250 ms." The Hangs instrument lets you choose a lower threshold.
- Hang reporting measures the main run loop's **busy period**: "the duration between two waiting for events periods of the run loop." Delivering the event and rendering the result "can add 10 ms to 50 ms" that hang reporting doesn't see.
- Organizer "reports the hang rate as the number of seconds per hour that the app is unresponsive, while only counting periods of unresponsiveness of more than 250 ms," as a median and a 90th percentile.
- "When the main thread is unresponsive for 1 s or longer, the system also samples the app to capture a backtrace profile." Those samples become Organizer's hang reports, grouped by similar backtraces.
- Beyond that is the **watchdog**: an app that blocks the main thread long enough is terminated with code `0x8badf00d`. Apple's example report shows a 19.97 second wall-clock allowance for scene creation; that's one example, not a budget you should approach.

### A model of what the tools see

Pantry's support team forwarded a session from a customer who said the app "freezes when opening orders." Here's that session's main-thread work as a list of items, with gaps where the run loop waited for events:

```swift
struct WorkItem {
    let name: String
    let startMilliseconds: Int
    let durationMilliseconds: Int
}

struct BusyPeriod {
    let start: Int
    var end: Int
    var names: [String]
    var duration: Int { end - start }
}

/// Back-to-back items form one busy period: the run loop never got back to waiting between them.
func busyPeriods(_ items: [WorkItem]) -> [BusyPeriod] {
    var periods: [BusyPeriod] = []
    for item in items.sorted(by: { $0.startMilliseconds < $1.startMilliseconds }) {
        let itemEnd = item.startMilliseconds + item.durationMilliseconds
        if var last = periods.last, item.startMilliseconds <= last.end {
            last.end = max(last.end, itemEnd)
            last.names.append(item.name)
            periods[periods.count - 1] = last
        } else {
            periods.append(BusyPeriod(start: item.startMilliseconds, end: itemEnd, names: [item.name]))
        }
    }
    return periods
}

let session = [
    WorkItem(name: "tap Orders", startMilliseconds: 10_000, durationMilliseconds: 20),
    WorkItem(name: "decode orders JSON", startMilliseconds: 10_020, durationMilliseconds: 210),
    WorkItem(name: "reload table", startMilliseconds: 10_230, durationMilliseconds: 30),
    WorkItem(name: "scroll", startMilliseconds: 12_000, durationMilliseconds: 12),
    WorkItem(name: "open receipt PDF", startMilliseconds: 30_000, durationMilliseconds: 1_350),
    WorkItem(name: "image decode", startMilliseconds: 45_000, durationMilliseconds: 180),
    WorkItem(name: "search keystroke", startMilliseconds: 60_000, durationMilliseconds: 90),
    WorkItem(name: "search keystroke", startMilliseconds: 60_090, durationMilliseconds: 95),
    WorkItem(name: "search keystroke", startMilliseconds: 60_185, durationMilliseconds: 100),
]
let sessionMilliseconds = 10 * 60 * 1_000

var hangMilliseconds = 0
for period in busyPeriods(session) where period.duration > 250 {
    hangMilliseconds += period.duration
    let report = period.duration >= 1_000 ? ", backtrace sampled" : ""
    print("hang \(period.duration) ms: \(period.names.joined(separator: " + "))\(report)")
}
// Seconds per hour, in tenths: hang ms × (3,600,000 / session ms) / 1,000 × 10.
let tenthsOfSecondPerHour = hangMilliseconds * 36_000 / sessionMilliseconds
print("hang rate: \(tenthsOfSecondPerHour / 10).\(tenthsOfSecondPerHour % 10) s/hour")
```

```output
hang 260 ms: tap Orders + decode orders JSON + reload table
hang 1350 ms: open receipt PDF, backtrace sampled
hang 285 ms: search keystroke + search keystroke + search keystroke
hang rate: 11.3 s/hour
```

- **The orders hang is three items.** None of them crosses 250 ms on its own, and each looks tolerable in a profiler sorted by function, but the run loop never waited between them. Reporting works on busy periods, so they add up.
- **The image decode, 180 ms, isn't counted.** It's above Apple's 100 ms "noticeable" line but below the 250 ms reporting line, so it never reaches Organizer. Your budget (lesson 1) should catch it; the field data won't.
- **Only the PDF produces a backtrace** in a hang report, because only it reached 1 second. If you rely on Organizer's hang reports alone, you'll see the PDF and never the orders screen the customer complained about.
- **Three keystrokes of 90 to 100 ms** chain into a 285 ms hang because each arrives before the previous one finished. Debouncing search (Module 37) or making each keystroke cheaper fixes it.
- The hang rate is 1,895 ms of hangs in 10 minutes, scaled to an hour: 11.37 seconds, truncated to tenths with integer math. Treating the whole busy period as hang time is this model's simplification; Apple's article doesn't spell out the accounting beyond the 250 ms rule.

### Finding hangs in an unfamiliar app

Apple lists three tools for development, each catching something different:

- **Thread Performance Checker**, enabled in the scheme's diagnostics. It "detects priority inversions and non-UI work on the main thread" while you run from Xcode, and "doesn't require any recompilation." In an old codebase it finds `DispatchSemaphore.wait()` used to make async APIs look synchronous, which Apple calls out: "Don't use `dispatch_semaphore_wait` and `dispatch_group_wait` to emulate synchronous behavior."
- **On-device Hang Detection**, which you enable "by opening the Settings app and navigating to Developer > Hang Detection." It notifies you of hangs while you use development-signed or TestFlight builds, and the tailspin it captures opens in Instruments. Give it to the people who use the app most: support, QA, the product manager.
- **The Hangs instrument**, included in the Time Profiler, CPU Profiler and Hitches templates, with a configurable threshold.

Then look for the usual suspects. Apple's watchdog article names synchronous networking "hidden behind abstraction layers," such as `Data(contentsOf:)` with an `https` URL, and the synchronous `SCNetworkReachability` calls; use `URLSession` and `NWPathMonitor` instead. Add to that: JSON decoding of large responses, image decoding at full size, Core Data or SwiftData fetches on the main context for thousands of rows, PDF rendering, and file I/O.

### Moving the work off the main actor

Pantry's orders screen, as it was:

```swift ios
import UIKit

struct Order: Decodable, Sendable {
    let id: String
    let totalCents: Int
}

@MainActor
final class LegacyOrdersViewController: UITableViewController {
    private var orders: [Order] = []

    func show(_ data: Data) {
        Task {
            // Hangs: the Task inherits the main actor, and decoding is synchronous.
            orders = (try? JSONDecoder().decode([Order].self, from: data)) ?? []
            tableView.reloadData()
        }
    }
}
```

It looks asynchronous because of the `Task`, but the task inherits the main actor from the view controller and the decode is synchronous, so it runs on the main thread a moment later. That's the trap Apple's "Improving app responsiveness" shows and Module 21 described. The fix puts the decode in an `async` function that runs off the main actor:

```swift ios
import UIKit

struct Order: Decodable, Sendable {
    let id: String
    let totalCents: Int
}

/// Runs on the concurrent thread pool regardless of the caller or the project's isolation defaults.
@concurrent
func decodeOrders(from data: Data) async throws -> [Order] {
    try JSONDecoder().decode([Order].self, from: data)
}

@MainActor
final class OrdersViewController: UITableViewController {
    private var orders: [Order] = []

    func show(_ data: Data) {
        Task {
            do {
                orders = try await decodeOrders(from: data)
            } catch {
                orders = []
            }
            tableView.reloadData()      // back on the main actor
        }
    }
}
```

- **`@concurrent`** (Swift 6.2, Module 29) makes the function run on the concurrent pool "whatever the project's settings." Apple's article relies on nonisolated `async` functions leaving the actor; under Xcode's Approachable Concurrency setting a plain nonisolated `async` function runs on the caller's actor instead, so in a mixed old-and-new codebase, say what you mean.
- **`Order` is `Sendable`**, so the array can cross back to the main actor.
- **Only the assignment and `reloadData()`** run on the main actor. Apple's advice in one line: "separate your UI updates into preparing data for display, and updating view objects to display that data."
- Granularity matters too. Apple's CPU scheduling article suggests that "ideally, each independent operation requires between 10-100 ms to complete": enough work per task to be worth scheduling, not so much that it can't be cancelled promptly.

## Memory

Module 13 found leaks with the memory graph. A shipped app has three different memory problems, and only one of them is a leak.

- **Footprint** is "the data that you allocated in RAM, and that must stay in RAM." The system's limit applies to it, and "memory limits can change during the app life cycle and don't necessarily correspond to the amount of physical memory available on the device."
- **Leaks** are memory that "becomes unreachable and the app can't deallocate it," usually a retain cycle. The Leaks instrument and the memory graph find them.
- **Abandoned memory** is reachable but useless. Apple's example: a social app keeps every loaded message in a dictionary, so "it can grow without bounds as the user scrolls." It "doesn't show up in leak-detection tools." Allocations' **generations** (mark, use a feature, mark again) find it.

### Jetsam: when the system ends the app

When memory runs short, the system first sends low-memory warnings; "if memory pressure continues because apps haven't relinquished enough memory, the system frees memory by terminating applications." That's a **jetsam event**. If it happens while your app is visible, "it will look like your app crashed," but there's no crash report with a backtrace; there's a JSON jetsam report (Module 41 showed where to find them). Reading one:

```swift
import Foundation

struct JetsamReport: Decodable {
    struct MemoryStatus: Decodable { let pageSize: Int }
    struct Process: Decodable {
        let name: String
        let rpages: Int
        let states: [String]
        let reason: String?
    }
    let memoryStatus: MemoryStatus
    let largestProcess: String
    let processes: [Process]
}

let json = """
{
  "memoryStatus": { "pageSize": 16384 },
  "largestProcess": "Pantry",
  "processes": [
    { "name": "Pantry", "rpages": 92802, "states": ["frontmost"], "reason": "per-process-limit" },
    { "name": "Mail", "rpages": 6120, "states": ["suspended"] },
    { "name": "PantryWidget", "rpages": 1800, "states": ["suspended"] }
  ]
}
"""

let report = try JSONDecoder().decode(JetsamReport.self, from: Data(json.utf8))
for process in report.processes {
    let bytes = process.rpages * report.memoryStatus.pageSize
    let reason = process.reason.map { " ← terminated: \($0)" } ?? ""
    print("\(process.name): \(bytes) bytes (\(bytes / 1_000_000) MB), \(process.states.joined(separator: ","))\(reason)")
}
print("largest process:", report.largestProcess)
```

```output
Pantry: 1520467968 bytes (1520 MB), frontmost ← terminated: per-process-limit
Mail: 100270080 bytes (100 MB), suspended
PantryWidget: 29491200 bytes (29 MB), suspended
largest process: Pantry
```

- **Only the terminated process has a `reason`.** If your app died but the process with a reason is someone else, Apple says "the crash isn't due to memory pressure"; look for a crash report instead.
- **Bytes are `rpages × pageSize`.** The first line reproduces Apple's own example: 92,802 pages × 16,384 bytes = 1,520,467,968 bytes, about 1.52 GB.
- **`per-process-limit`**: "The process crossed the resident memory limit imposed by the system on all apps." `vm-pageshortage` means the system reclaimed background memory for the foreground app; others include `vnode-limit` (too many open files system-wide) and `fc-thrashing` (file cache thrashing from memory-mapped files).
- **Extensions have much lower limits.** Apple warns about "technologies with a high-baseline memory cost, such as SpriteKit or a MKMapView, in an extension point," and suggests `MKMapSnapshotter` as a lighter alternative.

The real report has many more fields; this decoder reads the ones Apple's article uses to diagnose, and ignores the rest.

### Abandoned memory in Pantry's catalog

Pantry's catalog keeps every product it has loaded, keyed by ID, so returning to a product is instant. Here's what that does over a long scroll, compared with keeping only a window around what's visible:

```swift
struct Product {
    let id: Int
    let name: String
}

struct ProductStore {
    /// How many products to keep on each side of the visible range; nil keeps everything.
    let keepAround: Int?
    private(set) var loaded: [Int: Product] = [:]

    init(keepAround: Int?) { self.keepAround = keepAround }

    mutating func show(_ visible: ClosedRange<Int>) {
        for id in visible where loaded[id] == nil {
            loaded[id] = Product(id: id, name: "Product \(id)")
        }
        guard let keepAround else { return }
        let kept = (visible.lowerBound - keepAround)...(visible.upperBound + keepAround)
        loaded = loaded.filter { kept.contains($0.key) }
    }
}

var everything = ProductStore(keepAround: nil)
var windowed = ProductStore(keepAround: 60)
for top in stride(from: 0, through: 4_980, by: 10) {     // scroll through 5,000 products
    let visible = top...(top + 19)
    everything.show(visible)
    windowed.show(visible)
}
print("keep everything:", everything.loaded.count)
print("keep a window:", windowed.loaded.count)
windowed.show(100...119)                                 // scroll back to the top
print("after scrolling back:", windowed.loaded.count, "kept, 100...119 loaded again")
```

```output
keep everything: 5000
keep a window: 80
after scrolling back: 20 kept, 100...119 loaded again
```

- **5,000 products, all reachable, none leaked.** The memory graph shows them as legitimately owned by the store. That's why leak tools are silent, and why this kind of growth only shows up as a footprint that climbs the longer someone uses the app.
- **The window** keeps loaded products within 60 of the visible range. At the end of the scroll that's 4,920 to 4,999: 80 products. After the jump back to the top, none of those are near the new range, so only the 20 visible products are loaded again. The store reloads what it needs; it never holds more than a screen and its margins.
- In the app the window is driven by prefetching (Module 27) and the evicted data is cheap to reload, either from disk or from the `URLCache`. Apple's advice: "Discard old content, or write it to disk for later retrieval."

### Memory warnings

Apple lists four ways a warning arrives: `applicationDidReceiveMemoryWarning(_:)` on the app delegate, `didReceiveMemoryWarning()` on active view controllers, `UIApplication.didReceiveMemoryWarningNotification`, and a dispatch source of type `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE`. They're "best-effort": if demand rises faster than apps respond, the system may terminate apps without waiting. Respond quickly and simply:

```swift ios
import UIKit
import os

@MainActor
final class ProductImageCache {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.totalCostLimit = 50 * 1024 * 1024      // about 50 MB of decoded pixels
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        let pixels = Int(image.size.width * image.scale * image.size.height * image.scale)
        cache.setObject(image, forKey: key as NSString, cost: pixels * 4)
    }

    func purge() {
        cache.removeAllObjects()
    }
}

@MainActor
final class CatalogViewController: UICollectionViewController {
    let imageCache = ProductImageCache()

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        imageCache.purge()            // decoded images are the cheapest thing to recreate
    }

    /// Advisory only: decide whether a full-resolution zoom view is worth decoding now.
    func canAffordFullResolution(bytes: Int) -> Bool {
        let available = os_proc_available_memory()
        return available > bytes * 2
    }
}
```

- **Purge what's cheap to recreate**: decoded images, layout caches, prefetched pages.
- **Don't walk the object graph looking for things to free.** Apple: "iOS compresses memory pages that apps haven't accessed recently. Searching for memory to purge brings these pages out of the compressor, and increases memory demands on the system."
- **`os_proc_available_memory()`** returns "the number of bytes the app may allocate before it hits its memory limit." Apple: "Use the returned value as advisory information only and don't cache it," and don't use it to maximize your usage. Here it decides whether to decode a full-resolution image or keep the downsampled one (Module 27's downsampling).
- **Large allocations in one go** can get the app terminated before any warning arrives. Apple suggests to "slowly allocate the necessary memory, so the system has adequate time to free memory."
- `XCTMemoryMetric` (lesson 1) measures "the peak memory use observed while the block runs, and the growth in memory allocated between the block's beginning and end," which is how Pantry keeps the catalog's window from regressing.

> [!warning] The simulator never warns
> Apple: "When you run your app in the simulator, the memory gauge always stays in the green (safe) region because macOS doesn't issue memory warnings or out-of-memory terminations." Memory limits can only be tested on a device, ideally the smallest one you support.

## Battery

Apple's battery article starts from how the device saves power: it switches off subsystems nobody's using. "When there aren't any apps making a network request, the device can switch off its Wi-Fi and cellular components." Every request, location update and timer you add keeps something awake. People see the result in Settings > Battery, and Apple notes that "they might choose to use your app less, or uninstall your app."

The tools: Organizer's Battery Usage pane breaks power use down by version into Audio, Networking, Processing, Display, Bluetooth, Location, Camera, Torch, NFC and Other, foreground and background; the Energy pane shows **energy exception reports** when an app "uses a significant amount of energy over a 24-hour period"; Xcode's Energy Impact gauge works while you run on a device; the Power Profiler in Instruments records sessions; and `XCTCPUMetric` guards CPU-heavy code against regressions.

Apple's process is three steps: **do less work, work more efficiently, avoid misusing APIs.**

### Networking: batch and wait

From "Reducing networking and Bluetooth power usage": use one `URLSession` so connections are reused, "batch multiple requests together and compress payloads to reduce the total time network interfaces remain active," set `waitsForConnectivity` "to avoid wasteful connection attempts when the network is unavailable," and use background sessions with `isDiscretionary` for large downloads, which lets the system wait "until the device is charging or connected to Wi-Fi."

Pantry sends an analytics event for each product view, one request each. A model of an hour of browsing:

```swift
/// Minutes since the start of the session at which the person viewed a product.
let viewMinutes = [1, 2, 2, 3, 5, 6, 6, 7, 9, 12, 14, 15, 15, 16, 18, 22, 23, 23, 24, 30,
                   31, 33, 34, 34, 36, 40, 41, 41, 44, 47, 50, 51, 52, 52, 55, 57, 58, 58, 59, 59]

/// Uploads whenever `maxEvents` are waiting, or the oldest waiting event is `maxAgeMinutes` old.
func uploads(for minutes: [Int], maxEvents: Int, maxAgeMinutes: Int) -> [Int] {
    var sent: [Int] = []
    var waiting: [Int] = []
    for minute in minutes {
        if let oldest = waiting.first, minute - oldest >= maxAgeMinutes {
            sent.append(minute)
            waiting.removeAll()
        }
        waiting.append(minute)
        if waiting.count == maxEvents {
            sent.append(minute)
            waiting.removeAll()
        }
    }
    if !waiting.isEmpty { sent.append(60) }      // flush when the session ends
    return sent
}

let oneByOne = uploads(for: viewMinutes, maxEvents: 1, maxAgeMinutes: 60)
let batched = uploads(for: viewMinutes, maxEvents: 25, maxAgeMinutes: 15)
print("one request per event:", oneByOne.count, "radio wake-ups")
print("batched:", batched.count, "radio wake-ups at minutes", batched)
```

```output
one request per event: 40 radio wake-ups
batched: 4 radio wake-ups at minutes [16, 31, 47, 60]
```

- **40 events, 4 uploads.** Each upload still sends everything; the radio just wakes up a tenth as often.
- **Two limits** keep batching honest: a count (so a burst doesn't build a huge payload) and an age (so data isn't held for hours). The numbers 25 and 15 are Pantry's choices, not Apple's.
- **The age limit is checked when an event arrives**, so the first batch goes at minute 16 (when an event finds the minute-1 event 15 minutes old), not at minute 15. A real implementation also flushes on a timer and when the app goes to the background (the minute-60 flush here), and persists waiting events so a termination doesn't lose them.
- Counting "radio wake-ups" as one per upload is a simplification; how long the radio stays on after a request is up to the system.

### Background refresh: back off on failure

Apple's guidance for `BGAppRefreshTask` is specific: "Set an appropriate value for your request's `earliestBeginDate` to avoid frequent wake-ups, using exponential backoff for failed attempts to prevent energy-draining retry loops. For example, if your first refresh task fails, set the `earliestBeginDate` on the first retry 5 minutes later. If that fails, wait 10 minutes before retrying, then 20 minutes, and so on." And: call `setTaskCompleted(success:)` "promptly when your task succeeds or fails to allow the system to return to sleep."

```swift
/// Minutes to wait before the next background refresh after `consecutiveFailures` failures in a row.
func refreshDelayMinutes(afterFailures consecutiveFailures: Int, normalMinutes: Int = 60, capMinutes: Int = 6 * 60) -> Int {
    guard consecutiveFailures > 0 else { return normalMinutes }
    var delay = 5
    for _ in 1..<consecutiveFailures {
        delay *= 2
        if delay >= capMinutes { return capMinutes }
    }
    return min(delay, capMinutes)
}

for failures in 0...8 {
    print(failures, "failures →", refreshDelayMinutes(afterFailures: failures), "min")
}
```

```output
0 failures → 60 min
1 failures → 5 min
2 failures → 10 min
3 failures → 20 min
4 failures → 40 min
5 failures → 80 min
6 failures → 160 min
7 failures → 320 min
8 failures → 360 min
```

- **5, 10, 20** is Apple's example sequence; the cap of six hours and the normal 60-minute interval are Pantry's choices. `earliestBeginDate` is a lower bound: the system decides when the task actually runs.
- **The doubling stops at the cap** inside the loop, so a long outage can't overflow the integer.
- **Success resets the count.** Store `consecutiveFailures` with the scheduler, not in memory: the app is usually not running between background tasks. Module 44 builds the `BGTaskScheduler` side.

### Location

From "Accessing the device's location efficiently": high `desiredAccuracy` combines several power-hungry subsystems; "don't leave location updates running when your app doesn't need them." With `CLLocationUpdate`, Core Location sets `stationary` when the device stops moving, and if you don't expect movement soon, stop updates and use `CLMonitor` "to get notified of significant changes." Background location only "if your app's functionality doesn't work without it." Pantry's old store finder started location updates at launch and never stopped them; now it requests a location when the store-finder screen appears and stops when it disappears.

### Low Power Mode and thermal state

Apple's "Responding to power notifications" lists what to do when Low Power Mode is on: "Pausing any optional activities, reducing display updates, minimizing animations, reducing the frequency of network connections, stopping location updates." For thermal state it gives one line per level:

| `ProcessInfo.ThermalState` | Apple's guidance |
| --- | --- |
| `.nominal` | "Enable all of your app's functionality." |
| `.fair` | "Defer work for which a person doesn't immediately need the results." |
| `.serious` | "Reduce networking and location activity, screen updates, and animations." |
| `.critical` | "Reduce or stop all work that your app is doing," and "stop or significantly reduce use of the camera, Bluetooth, location, and other power-intensive subsystems." |

Pantry turns both signals into one policy that features read, so no screen has to interpret thermal states on its own:

```swift
enum Thermal: Int, Comparable {
    case nominal, fair, serious, critical
    static func < (lhs: Thermal, rhs: Thermal) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct EnergyPolicy: Equatable {
    var prefetchImages = true
    var backgroundSync = true
    var animatedBanners = true
    var liveDeliveryMap = true
}

func policy(lowPowerMode: Bool, thermal: Thermal) -> EnergyPolicy {
    var policy = EnergyPolicy()
    if lowPowerMode || thermal >= .fair {
        policy.prefetchImages = false          // optional work the person isn't waiting for
        policy.backgroundSync = false
    }
    if lowPowerMode || thermal >= .serious {
        policy.animatedBanners = false         // fewer screen updates and animations
    }
    if thermal >= .critical {
        policy.liveDeliveryMap = false         // stop location-heavy features
    }
    return policy
}

func describe(_ p: EnergyPolicy) -> String {
    [("prefetch", p.prefetchImages), ("sync", p.backgroundSync), ("banners", p.animatedBanners), ("map", p.liveDeliveryMap)]
        .map { "\($0.0) \($0.1 ? "on" : "off")" }
        .joined(separator: ", ")
}

print(describe(policy(lowPowerMode: false, thermal: .nominal)))
print(describe(policy(lowPowerMode: false, thermal: .fair)))
print(describe(policy(lowPowerMode: true, thermal: .nominal)))
print(describe(policy(lowPowerMode: false, thermal: .critical)))
```

```output
prefetch on, sync on, banners on, map on
prefetch off, sync off, banners on, map on
prefetch off, sync off, banners off, map on
prefetch off, sync off, banners off, map off
```

- **The policy is a value**, so it's testable without a device that's actually hot.
- **Low Power Mode keeps the delivery map.** It's something the person is actively watching, and Apple's list for Low Power Mode is about optional activity. Only `.critical` stops it.
- The mapping from levels to features is Pantry's judgment, following the direction of Apple's table.

The device-facing side observes the two notifications Apple names and recomputes:

```swift ios
import Foundation

@MainActor
final class EnergyConditions {
    private(set) var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append(token)
        }
    }

    private func refresh() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        onChange?()
    }
}
```

`queue: .main` delivers the notifications on the main queue, which is what makes `MainActor.assumeIsolated` correct here; the closure is `@Sendable`, so the compiler can't know that on its own (Module 40 used the same pattern).

## Common mistakes

> [!error] Trusting Organizer's hang reports to show every hang
> Backtraces are only sampled at 1 second, and the hang rate ignores anything up to 250 ms. A 180 ms stall on every tap never appears there but still makes the app feel slow. Use on-device Hang Detection and Instruments during development.

> [!error] Task { } as a way to leave the main thread
> A `Task` created on the main actor runs on the main actor. Synchronous work inside it hangs a moment later. Move the work into a `@concurrent` (or, in default settings, nonisolated) `async` function.

> [!error] Calling it a leak when it's abandoned memory
> If the memory graph shows the objects owned by something real, fixing retain cycles won't help. Bound the collection, evict what isn't visible, or write it to disk.

> [!error] Testing memory in the simulator
> The simulator never issues memory warnings or jetsam terminations. Test on a device, preferably the smallest one you support.

> [!error] Retrying background work in a tight loop
> A failed refresh that reschedules itself immediately keeps the device awake. Back off exponentially (5, 10, 20 minutes…) and complete the task promptly.

> [!error] Location updates that never stop
> Starting updates at launch "just in case" is one of the most expensive things an app can do. Request location when a feature needs it, stop when the feature goes away, and use `stationary` and `CLMonitor` for long-running cases.

## Exercises

````exercise
id: m43-l02-e1
type: prediction
prompt: "The busy-period model from the lesson, on a different session. What does it print?"
code: |
  struct WorkItem {
      let name: String
      let startMilliseconds: Int
      let durationMilliseconds: Int
  }

  func busyDurations(_ items: [WorkItem]) -> [Int] {
      var periods: [(start: Int, end: Int)] = []
      for item in items.sorted(by: { $0.startMilliseconds < $1.startMilliseconds }) {
          let end = item.startMilliseconds + item.durationMilliseconds
          if let last = periods.last, item.startMilliseconds <= last.end {
              periods[periods.count - 1].end = max(last.end, end)
          } else {
              periods.append((item.startMilliseconds, end))
          }
      }
      return periods.map { $0.end - $0.start }
  }

  let items = [
      WorkItem(name: "a", startMilliseconds: 0, durationMilliseconds: 200),
      WorkItem(name: "b", startMilliseconds: 200, durationMilliseconds: 100),
      WorkItem(name: "c", startMilliseconds: 500, durationMilliseconds: 240),
      WorkItem(name: "d", startMilliseconds: 2_000, durationMilliseconds: 1_100),
  ]
  let durations = busyDurations(items)
  print(durations)
  print(durations.filter { $0 > 250 }.count)
  print(durations.filter { $0 >= 1_000 }.count)
output: |
  [300, 240, 1100]
  2
  1
hints:
  - "b starts exactly when a ends, so they're one busy period."
  - "c starts at 500, after the first period ended at 300."
solution: |
  ```output
  [300, 240, 1100]
  2
  1
  ```

  - **a + b** are back to back (b starts at 200, when a ends), so the run loop never waits: one 300 ms busy period, a hang by the 250 ms rule even though neither item is.
  - **c** is 240 ms on its own: noticeable by Apple's 100 ms guidance, but not reported.
  - **d** is 1,100 ms: a hang, and the only one long enough (1 s) for the system to sample a backtrace for a hang report.
````

````exercise
id: m43-l02-e2
type: comprehension
prompt: "A jetsam report from a Pantry user shows Pantry with `\"states\": [\"suspended\"]` and no reason key, and a game with `\"reason\": \"per-process-limit\"`. The user says Pantry crashed. What does the report tell you?"
choices:
  - text: "This jetsam event didn't terminate Pantry; if Pantry crashed, look for a crash report instead."
    correct: true
    why: "Only the terminated process has a reason key. Apple: if the jettisoned process isn't your app, the crash isn't due to memory pressure."
  - text: "Pantry was terminated because it was suspended."
    correct: false
    why: "States describe memory use; termination is marked by the reason key, which Pantry doesn't have."
  - text: "Pantry crossed its per-process limit."
    correct: false
    why: "The per-process-limit reason belongs to the game's entry."
  - text: "Jetsam reports can't be used for apps that were in the background."
    correct: false
    why: "They list all processes with their memory use, foreground or not."
solution: |
  Jetsam reports list every process, but only the one the system terminated has a `reason`. Here it's the game, which crossed its own limit. Pantry was suspended and survived this event. If Pantry really disappeared for the user, either it was terminated in a different event (find that report) or it crashed for another reason, which produces a crash report with a backtrace.
````

````exercise
id: m43-l02-e3
type: fill-in
prompt: "Complete the off-main decoding for Pantry's receipts screen."
code: |
  struct Receipt: Decodable, [[1]] {
      let id: String
      let lines: [String]
  }

  [[2]]
  func decodeReceipts(from data: Data) async throws -> [Receipt] {
      try JSONDecoder().decode([Receipt].self, from: data)
  }

  @MainActor
  final class ReceiptsModel {
      private(set) var receipts: [Receipt] = []

      func load(_ data: Data) async {
          receipts = (try? [[3]] decodeReceipts(from: data)) ?? []
      }
  }
blanks:
  - id: "1"
    answers: ["Sendable"]
  - id: "2"
    answers: ["@concurrent"]
  - id: "3"
    answers: ["await"]
solution: |
  ```swift ios
  import Foundation

  struct Receipt: Decodable, Sendable {
      let id: String
      let lines: [String]
  }

  @concurrent
  func decodeReceipts(from data: Data) async throws -> [Receipt] {
      try JSONDecoder().decode([Receipt].self, from: data)
  }

  @MainActor
  final class ReceiptsModel {
      private(set) var receipts: [Receipt] = []

      func load(_ data: Data) async {
          receipts = (try? await decodeReceipts(from: data)) ?? []
      }
  }
  ```

  `@concurrent` runs the decode on the concurrent pool whatever the module's default isolation. The result crosses back to the main actor, so `Receipt` must be `Sendable`. `try? await` suspends the main actor without blocking it; only the assignment runs there.
````

````exercise
id: m43-l02-e4
type: find-errors
prompt: "Pantry's old image cache and its memory-warning handling. Mark every real problem."
code: |
  @MainActor
  final class ImageStore {
      static let shared = ImageStore()
      private var images: [URL: UIImage] = [:]       // every image ever shown

      func image(for url: URL) -> UIImage? { images[url] }
      func store(_ image: UIImage, for url: URL) { images[url] = image }

      func handleMemoryWarning() {
          // Find big objects and free them.
          for controller in allViewControllersInTheApp() {
              controller.view.subviews.forEach { $0.layer.contents = nil }
          }
      }
  }
choices:
  - text: "The dictionary grows without bound: abandoned memory that leak tools won't report."
    correct: true
  - text: "The memory-warning handler walks the whole UI, touching compressed pages and adding memory demand."
    correct: true
  - text: "The cache itself is never cleared on a warning, though decoded images are the cheapest thing to recreate."
    correct: true
  - text: "Clearing layer contents of arbitrary views breaks what's on screen."
    correct: true
  - text: "UIImage can't be stored in a dictionary."
    correct: false
    why: "It can; the problem is that nothing ever removes them."
rubric:
  - I flagged the unbounded dictionary.
  - I flagged the object-graph walk in the warning handler.
  - I flagged that the cache isn't purged.
  - I flagged the visual breakage from clearing layer contents.
solution: |
  - **Unbounded growth.** Every image stays forever. Use `NSCache` with a `totalCostLimit` (it also evicts on its own under pressure), keyed by URL.
  - **Walking the object graph.** Apple: don't traverse "your app's whole object graph looking for memory to release"; it brings compressed pages back into memory, making pressure worse.
  - **The cache survives the warning.** The one thing that's cheap to rebuild isn't touched. `removeAllObjects()` is the right response.
  - **Clearing `layer.contents`** of visible views blanks the screen and fights UIKit, which owns those layers.
````

````exercise
id: m43-l02-e5
type: solve
prompt: |
  Pantry syncs the cart in the background. Write `nextRefreshMinutes(history:)`: given the results of past refresh attempts (oldest first, `true` for success), return how many minutes to wait before the next one. Count only the failures since the last success. With none, wait 60 minutes; otherwise use Apple's sequence 5, 10, 20… doubling, capped at 240.

  Expected output:

  ```output
  60
  5
  20
  60
  240
  10
  ```
starter: |
  func nextRefreshMinutes(history: [Bool]) -> Int {
      // your code
      return 0
  }

  print(nextRefreshMinutes(history: []))
  print(nextRefreshMinutes(history: [false]))
  print(nextRefreshMinutes(history: [true, false, false, false]))
  print(nextRefreshMinutes(history: [false, false, true]))
  print(nextRefreshMinutes(history: Array(repeating: false, count: 30)))
  print(nextRefreshMinutes(history: [false, false, false, true, false, false]))
hints:
  - "Walk the history backwards and count failures until you meet a success."
  - "Double inside a loop and stop at the cap, so 30 failures can't overflow."
rubric:
  - Counts only trailing failures.
  - Returns 60 when the last attempt succeeded or there's no history.
  - Produces 5, 10, 20… and caps at 240 without overflowing.
solution: |
  ```swift
  func nextRefreshMinutes(history: [Bool]) -> Int {
      var failures = 0
      for succeeded in history.reversed() {
          if succeeded { break }
          failures += 1
      }
      guard failures > 0 else { return 60 }
      var delay = 5
      for _ in 1..<failures {
          delay *= 2
          if delay >= 240 { return 240 }
      }
      return delay
  }

  print(nextRefreshMinutes(history: []))
  print(nextRefreshMinutes(history: [false]))
  print(nextRefreshMinutes(history: [true, false, false, false]))
  print(nextRefreshMinutes(history: [false, false, true]))
  print(nextRefreshMinutes(history: Array(repeating: false, count: 30)))
  print(nextRefreshMinutes(history: [false, false, false, true, false, false]))
  ```

  ```output
  60
  5
  20
  60
  240
  10
  ```

  Only failures after the last success count, so a recovery resets the backoff. The early return at the cap keeps 30 failures from computing 5 × 2²⁹. In the app, the result becomes `earliestBeginDate`, and `setTaskCompleted(success:)` is called as soon as the attempt finishes either way.
````

````exercise
id: m43-l02-e6
type: design
prompt: "Pantry's delivery-tracking screen shows a live map of the courier, polls the server every 2 seconds for the courier's position, plays an animated banner, and keeps running in the background so it can post a notification on arrival. Customers report battery drain. Redesign it using this lesson's guidance."
rubric:
  - Replaces polling with pushes or much less frequent requests, and stops network activity when the screen isn't visible.
  - Doesn't use the device's own location unless the feature needs it; if it does, stops when not needed.
  - Moves the arrival notification to the server (push) instead of background execution.
  - Adapts to Low Power Mode and thermal state, and measures the result with Organizer's battery data or the Power Profiler.
solution: |
  - **No polling.** The courier's position comes from the server; push updates (or a Live Activity updated by push, Module 44) replace a request every 2 seconds. If polling must stay, poll only while the screen is visible, at a slower rate, and back off when the position hasn't changed. Use the app's single `URLSession`.
  - **Arrival notification from the server.** The server knows when the courier arrives; a push notification needs no app running in the background. Background location isn't needed at all, because the app isn't tracking the customer.
  - **The customer's location** is only needed to center the map, once, when the screen opens.
  - **Banner animation** stops under Low Power Mode and at `.serious` thermal state, via the energy policy; the map stops live updates at `.critical` and shows the last known position with a refresh button.
  - **Measure** before and after: the Battery Usage pane per version (Networking and Location categories), energy exception reports, and a Power Profiler session of a 10-minute delivery.

  The biggest win is almost always removing work (the polling and the background execution), not making the same work cheaper.
````

## Summary

- Apple: delays over 100 ms are noticeable; most tools report main run loop unresponsiveness over 250 ms; Organizer's hang rate is seconds per hour of hangs over 250 ms; hang reports with backtraces need 1 s. Consecutive work items form one busy period, so short items can add up to a hang.
- Find hangs with the Thread Performance Checker, on-device Hang Detection and the Hangs instrument. Fix them by moving synchronous work into a `@concurrent` async function and keeping only UI updates on the main actor.
- Footprint is what counts against the memory limit. Leaks are unreachable; abandoned memory is reachable but useless and invisible to leak tools. Bound caches and evict what isn't near the screen.
- A jetsam report names the terminated process with a `reason`; memory is `rpages × pageSize`. Respond to memory warnings by purging cheap caches, without walking the object graph. The simulator never warns.
- Save energy by doing less: batch network requests, wait for connectivity, use discretionary background downloads, back off failed refreshes (5, 10, 20 minutes…), stop location updates you don't need, and scale features down for Low Power Mode and thermal state.
