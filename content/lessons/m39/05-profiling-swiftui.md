---
id: m39-l05
title: Profiling SwiftUI with Instruments
description: "Lesson 4 gave you the rules; this lesson gives you the measurement. Following Apple's article on SwiftUI performance, you record with the SwiftUI template, read the update lanes, tell long view body updates from too-frequent ones, follow Show Causes to the state that triggered them, and use Time Profiler for what a long body does. You run plain-Swift models of an update summary and of Apple's hitch thresholds, mark your own work with OSSignposter, and use _printChanges for what it is: an undocumented debugging aid."
module: m39
order: 5
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l04, m33-l06]
objectives:
  - Record a SwiftUI trace on a device in a Release build and name what the SwiftUI track's lanes show.
  - Tell a long view body update from a group of frequent short updates, and pick the next tool for each.
  - Use the cause-and-effect graph to find which state or observable property triggered updates.
  - Relate update durations to the frame budget at 60 and 120 Hz and to Apple's hitch rate thresholds.
  - Mark your own work with OSSignposter so it shows in the trace next to SwiftUI's.
  - Use Self._printChanges() as a temporary, undocumented debugging aid.
terms:
  - term: SwiftUI instrument
    definition: "The Instruments tool for SwiftUI work. In Apple's current article, its track has lanes for View Body Updates, Platform View Updates, Other Updates and Update Groups, next to Hitches and Time Profiler."
  - term: Update group
    definition: "A span of time during which SwiftUI is doing a sequence of related updates. A long group made of short updates points to update frequency, not slow bodies."
  - term: Cause-and-effect graph
    definition: "Instruments' Show Causes view: nodes are things that produce or receive updates (view bodies, observable objects, transactions); edges are the causal links. Blue nodes are your code, gray are the system's."
  - term: Hitch rate
    definition: "Milliseconds of hitch per second of animation or scrolling. Apple's thresholds for the Organizer metric: at or below 10 ms/s good, 25 warning, 50 critical, above 50 needs immediate attention."
  - term: Signpost
    definition: "A named mark or interval you emit with OSSignposter. Instruments shows intervals on a timeline, so you can line up your own work with SwiftUI updates and hitches."
mastery:
  - Start a SwiftUI recording and find the longest view body update in a trace.
  - Explain what Set Inspection Range and Zoom, Show Calls Made by, and Show Causes are for.
  - Compute the frame budget at 120 Hz and say whether a 14 ms body update can hitch.
  - Add a signposted interval around a model's filtering function.
  - Use _printChanges to see why a body ran, and remove it afterwards.
resources: [xcode-improving-performance, xcode-understanding-hitches, understanding-hangs, swiftui-performant-scrollable-stacks, xcode-performance-tests]
cards:
  - id: m39-l05-c1
    front: How do you start profiling SwiftUI work?
    back: "Apple's steps: Product > Profile, choose the SwiftUI template, Record (a deferred recording), use the feature, Stop. Profile builds for Release; use a physical device, not the simulator."
  - id: m39-l05-c2
    front: "Long update or frequent updates: what next?"
    back: "A long view body update: Set Inspection Range and Zoom, then the Time Profiler call tree or flame graph for that range to see what the body computes. A long update group of short updates: Show Causes on an update to see which state or observable property triggers them, and reduce how often it changes or who reads it."
  - id: m39-l05-c3
    front: What's the frame budget at 60 and 120 Hz?
    back: "16.7 ms and 8.3 ms per frame (Apple). Apple's responsiveness article says main-thread work for an update under about 5 ms is usually ready in time; a body that takes 14 ms will make frames late at either rate."
  - id: m39-l05-c4
    front: What is _printChanges()?
    back: "An underscored, undocumented method on View. Call let _ = Self._printChanges() in body to log what changed before that evaluation. Its output format isn't specified; use it while debugging and remove it before committing."
  - id: m39-l05-c5
    front: How do you see your own code's work in a SwiftUI trace?
    back: "Wrap it in an OSSignposter interval (beginInterval/endInterval or withIntervalSignpost). Intervals show on a timeline in Instruments, aligned with SwiftUI updates and hitches. The pointsOfInterest category shows them in the Points of Interest track."
---

## The idea in one sentence

Don't guess which view is slow: **record the interaction, find the update that's long or the group that's busy, ask Instruments what caused it**, fix that one thing, and record again.

> [!note] What was checked, and what wasn't
> Every Instruments step, lane name, menu item and color in this lesson comes from Apple's documentation, mainly "Understanding and improving SwiftUI performance" (Xcode), with "Understanding hitches in your app", "Improving app responsiveness" and "Creating performant scrollable stacks", read in November 2026. **None of it was checked in Instruments for this lesson**, and Instruments' SwiftUI tooling has changed between Xcode releases; if your version looks different, follow the article for your Xcode. `_printChanges()` isn't in Apple's documentation at all. The SwiftUI and `OSSignposter` blocks are type-checked against the iOS 17 SDK, not run. The update summary and hitch models are plain Swift, compiled and run with Swift 6.3, on invented sample numbers.

## Before you record

Module 33, lesson 6 set the ground rules; they matter more for SwiftUI, where debug builds do extra work:

- **Product > Profile** (Command-I). Apple's Instruments tutorial: it "builds your target in release mode, as debug builds can have different performance characteristics."
- **A real device.** "Creating performant scrollable stacks" is blunt: "Never profile your code using the iOS simulator. Always use real devices for performance testing." Use the slowest device you support.
- **Realistic data.** A list of 20 sample items won't show what 5,000 do. Load production-sized data (Module 33's launch arguments are one way).
- **One interaction per recording.** Scroll the feed, type in the search field, open the detail. A trace of everything shows nothing clearly.

## Recording with the SwiftUI template

Apple's steps, from "Understanding and improving SwiftUI performance":

1. In Xcode, choose **Product > Profile** to build and open the app in Instruments.
2. Choose the **SwiftUI** template.
3. Click **Record** to start a deferred recording.
4. Use the feature you want to test.
5. Stop the recording.

The timeline shows "a time profile of the code in your app, in parallel with a SwiftUI track." What the track contains, in Apple's words:

| Lane | What it shows |
| --- | --- |
| **View Body Updates** | Body evaluations, per module, so you can tell your views from a third-party SDK's and the system's |
| **Platform View Updates** | Updates to the UIKit/AppKit views SwiftUI manages for you |
| **Other Updates** | SwiftUI work that isn't a body or a platform view |
| **Update Groups** | Spans where SwiftUI is busy with a sequence of related updates |
| **Hitches** | "Situations in which your app didn't prepare a view update in time for the system to render its updated UI" |

Selecting the SwiftUI track shows a **summary of all updates**, organized "by module, view name, and category." That table is where you start.

> [!version] Older Xcode versions
> Apple's older article, "Creating performant scrollable stacks," describes a SwiftUI template with four instruments: View Body, View Properties, Core Animation Commits and Time Profiler, where the View Body instrument counts how many times each body ran. If your Xcode shows that layout, the counting idea is the same; the update groups and cause graph described below are from the newer tooling.

## Reading the summary: long or frequent?

The summary answers two different questions, and the two point at different fixes (lesson 4). Here is the kind of reasoning it supports, as a model: invented trace data, grouped per view, sorted by total time.

```swift
/// A model of reading Instruments' "Summary: All Updates": count, total and longest update per view.
/// The rows are invented sample data, in microseconds, not a real trace.
struct Update {
    let view: String
    let microseconds: Int
}

struct ViewSummary {
    let view: String
    var count = 0
    var total = 0
    var longest = 0
}

func summarize(_ updates: [Update]) -> [ViewSummary] {
    var byView: [String: ViewSummary] = [:]
    for update in updates {
        var summary = byView[update.view] ?? ViewSummary(view: update.view)
        summary.count += 1
        summary.total += update.microseconds
        summary.longest = max(summary.longest, update.microseconds)
        byView[update.view] = summary
    }
    return byView.values.sorted { $0.total > $1.total }
}

func milliseconds(_ microseconds: Int) -> String {
    let hundredths = microseconds % 1000 / 10
    return "\(microseconds / 1000).\(hundredths < 10 ? "0" : "")\(hundredths) ms"
}

let trace = Array(repeating: Update(view: "ProductRow", microseconds: 150), count: 240)
    + Array(repeating: Update(view: "SearchBar", microseconds: 90), count: 40)
    + [Update(view: "ChartView", microseconds: 14_000), Update(view: "ChartView", microseconds: 13_500)]

let frameBudget = 8_300           // 120 Hz: one frame every 8.3 ms
for summary in summarize(trace) {
    let kind = summary.longest > frameBudget ? "long update" : (summary.count > 100 ? "frequent" : "fine")
    print("\(summary.view): \(summary.count)×, total \(milliseconds(summary.total)), longest \(milliseconds(summary.longest)) → \(kind)")
}
```

```output
ProductRow: 240×, total 36.00 ms, longest 0.15 ms → frequent
ChartView: 2×, total 27.50 ms, longest 14.00 ms → long update
SearchBar: 40×, total 3.60 ms, longest 0.09 ms → fine
```

- **`ProductRow`** costs the most in total, but no single update is slow. 240 updates during one interaction means many rows re-ran many times: a frequency problem. The fix is in lesson 4: who depends on what changed.
- **`ChartView`** ran twice, but each update is longer than a 120 Hz frame. Each one can make a frame late. That's a long update: the fix is less work in that body.
- **`SearchBar`** is busy (40 updates while typing 40 characters) but cheap. Leave it alone.

Sorting by total time alone would send you to `ProductRow` and leave the visible stutter, which comes from `ChartView`. Look at both columns.

## Long updates: what is the body doing?

Apple's procedure for a long view body update:

1. Expand the SwiftUI track and find the long update in **View Body Updates**.
2. Control-click it and choose **Set Inspection Range and Zoom**, which focuses the timeline and the detail view on that update.
3. Click in the **Time Profiler** track to see the call tree for that range, or switch to the **Flame Graph**.

One long update may not contain enough samples to show anything; the Time Profiler samples at intervals (Module 33). Apple's advice: "repeat the long-running update while you record," then clear the range and, in the detail view, Control-click `MySwiftUIView.body` and choose **Show Calls Made by `MySwiftUIView.body`**, which filters the call tree to every instance of that body. **Callers/Callees > Clear Selection** in the bottom bar resets it.

What you're looking for is the code from lesson 4's list: sorting, filtering, formatting, decoding, parsing, building formatters, inside `body` or in an initializer. Apple's fix: "perform the calculation asynchronously, and cache the result."

## Frequent updates: what caused them?

When the summary shows many short updates, look at the **Update Groups** lane for "groups that are active for a long time, but not associated with long updates." Then:

1. Control-click the group and choose **Set Inspection Range**. (Apple notes you may need to move the start earlier to include the event that caused it.)
2. In **Summary: All Updates**, see which views updated and how many times.
3. Hold the pointer over an update, click the arrow and choose **Show Causes**.

The cause-and-effect graph is the most useful thing in the template. "Nodes in the graph represent objects that generate or receive updates; for example, view bodies, environment objects, and transactions. Edges in the graph represent causal links," such as "the connection from an `Observable()` object to a view that reads one of the object's properties in its `body`." **Blue nodes are your code; gray nodes are the system's.** Clicking an edge shows details of that update in the inspector, "for example, changes to your view's properties."

Apple lists typical causes, which map onto lesson 4:

- A view observes an object and "updates when one of the other properties changes": an `ObservableObject`, where any `@Published` change updates every observer. Migrate to `@Observable`.
- A view's update makes its children update "in ways that don't contribute to meaningful changes in the UI," for example a layout built on `GeometryReader` recalculating for updates that don't change anything. Move the update to a view that only changes what's relevant.
- A blue → gray → blue chain: your code causes an event that your own code then responds to, through SwiftUI. Apple's example is `onGeometryChange` driving a layout update on every size change; check that the change exceeds a threshold before updating.

One caution from the article: the graph "only shows one changing property for each edge." After a fix, record again: the same views may still update, now because of the next cause in line.

## What "too slow" means: frames and hitches

Numbers to compare durations with, all from Apple:

- **Frame interval.** "On Apple devices, this can be as often as 120 times per second, or every 8.3 ms. Another common display refresh rate for Apple devices is 60Hz, so one update every 16.7ms."
- **Main-thread budget.** "If the work that your app needs to perform on the main thread to update the screen is less than 5 ms, the update is usually ready in time." Beyond that, it depends on the device and its refresh rate.
- **Hangs.** For a discrete interaction like a tap, a delay "longer than 100 ms … starts to become noticeable and causes a hang."
- **Hitch rate.** Xcode Organizer's Hitches metric "measures hitch rate in milliseconds of pause per second (ms/s)": "at or below 10 ms/s is good; at or below 25 ms/s is a warning; at or below 50 ms/s is critical; and above 50 ms/s warrants immediate attention."

A model of the hitch rate for a five-second scroll at 120 Hz, where each late frame costs one frame interval:

```swift
/// Apple's thresholds for the Hitches metric in Xcode Organizer, in ms of hitch per second.
func hitchRating(hitchMilliseconds: Double, seconds: Double) -> String {
    let rate = hitchMilliseconds / seconds
    let label: String
    switch rate {
    case ...10: label = "good"
    case ...25: label = "warning"
    case ...50: label = "critical"
    default: label = "needs immediate attention"
    }
    return "\(Int(rate.rounded())) ms/s, \(label)"
}

/// A frame hitches when it's late; at 120 Hz each late frame costs at least one 8.3 ms interval.
let interval120 = 1000.0 / 120
print(hitchRating(hitchMilliseconds: 3 * interval120, seconds: 5))
print(hitchRating(hitchMilliseconds: 12 * interval120, seconds: 5))
print(hitchRating(hitchMilliseconds: 40 * interval120, seconds: 5))
```

```output
5 ms/s, good
20 ms/s, warning
67 ms/s, needs immediate attention
```

Three late frames in five seconds is "good"; forty is a scroll that visibly stutters. `ChartView`'s 14 ms updates from the summary would each make at least one 120 Hz frame late if they happened during a scroll. Apple's hitch article explains the rest of the pipeline (commit hitches in your process, render hitches in the render server); the SwiftUI instrument's Hitches lane tells you when one happened, and the update lanes next to it tell you what your app was doing at that moment.

## Your own code on the timeline: signposts

SwiftUI's lanes show bodies. Your model's work (a search, a decode, a sync) appears only as functions in the Time Profiler, unless you mark it. `OSSignposter` (iOS 15) emits named intervals that Instruments draws on a timeline. Apple: "use Instruments' `os_signposts` instrument to record those intervals."

```swift ios
import SwiftUI
import Observation
import os

@MainActor
@Observable
final class SearchModel {
    private static let signposter = OSSignposter(subsystem: "com.example.Catalog", category: .pointsOfInterest)

    var products: [String] = []
    private(set) var results: [String] = []

    func search(_ term: String) {
        let state = Self.signposter.beginInterval("Search", id: Self.signposter.makeSignpostID())
        results = products.filter { $0.localizedStandardContains(term) }
        Self.signposter.endInterval("Search", state)
    }

    func sortByName() {
        results = Self.signposter.withIntervalSignpost("Sort") {
            results.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
    }
}

struct SearchScreen: View {
    @State private var model = SearchModel()
    @State private var term = ""

    var body: some View {
        List(model.results, id: \.self) { Text($0) }
            .searchable(text: $term)
            .onSubmit(of: .search) { model.search(term) }
            .toolbar {
                Button("Sort") { model.sortByName() }
            }
    }
}
```

- **`category: .pointsOfInterest`** is the system-defined category for points of interest; Instruments shows signposts in it in its Points of Interest instrument. With your own category string, add the os_signpost instrument to the trace instead.
- **`beginInterval(_:id:)` / `endInterval(_:_:)`** bracket the work. The returned state pairs them; Apple notes that in debug builds a mismatched pair (ending twice, different names) is an assertion failure.
- **`withIntervalSignpost(_:id:around:)`** does both around a closure and returns its result, which is harder to get wrong.

In the trace, a "Search" interval that lines up with a hitch and a long `List` update tells you the search ran on the main thread during the scroll, which is Apple's "Improving app responsiveness" warning: keep non-UI work off the main thread.

## _printChanges: a quick look, not a tool

Module 36, lesson 5 introduced `Self._printChanges()`. Here is where it fits next to Instruments: it's the fastest way to answer "why did *this* view's body run?" while you're developing, before you profile.

```swift ios
import SwiftUI

struct BasketBadge: View {
    let count: Int
    @State private var isPulsing = false

    var body: some View {
        let _ = Self._printChanges()       // debugging only: remove before committing
        Text("\(count)")
            .padding(6)
            .background(Color.accentColor, in: Circle())
            .scaleEffect(isPulsing ? 1.2 : 1)
            .onChange(of: count) {
                isPulsing.toggle()
            }
    }
}
```

What you should know about it:

- **It's undocumented.** It isn't in Apple's reference documentation; the leading underscore is Swift's convention for "not public API." It may change or disappear.
- **Its output format isn't specified.** Developers commonly report lines with the view's name followed by what changed, such as `@self` (the view's own value, its inputs), `@identity` (a new identity), or a property wrapper's storage name like `_isPulsing`. That's an observation, not a contract, and it wasn't checked for this lesson.
- **It's per view and per run.** It tells you *that* `BasketBadge` ran and *roughly why*, not how long it took or what caused the chain. For that, the cause graph.
- **It writes to the console on every evaluation**, which is itself slow in a list. Remove it before you measure anything.

## A workflow

1. **Reproduce** the problem on a device with real data. Describe it as an interaction: "typing in search on an iPhone 12 stutters."
2. **Record** that one interaction with the SwiftUI template (Release build).
3. **Classify**: long updates (Time Profiler on the range) or many short ones (Update Groups and Show Causes).
4. **Fix one cause**, using lesson 4: narrower dependencies, work out of `body`, stable ids.
5. **Record again** and compare the same columns. Keep a performance test (Module 33, lesson 6) for any non-UI function you sped up.

## Common mistakes

> [!error] Profiling in the simulator or a Debug build
> The simulator runs on your Mac's CPU and GPU, and Debug builds skip optimizations. Apple: never profile in the simulator; Profile builds Release for a reason.

> [!error] Sorting by total time only
> A view with hundreds of cheap updates tops the list while a view with two 14 ms updates causes the visible hitch. Look at the longest update and the count.

> [!error] Fixing the first cause and stopping
> The cause graph shows one changing property per edge. After a fix, record again: the next cause may now be visible.

> [!error] Leaving _printChanges in the code
> It's undocumented, it logs on every body evaluation, and it distorts any measurement. Remove it, or keep it behind a debug-only flag you never ship.

> [!error] Optimizing without a recording
> `.equatable()`, lazy stacks and caches all have costs. Apple's advice for layout caches applies everywhere: only add it "if profiling shows that it improves performance."

## Exercises

````exercise
id: m39-l05-e1
type: prediction
prompt: "The summary model with a different trace, at a 60 Hz budget. What does it print?"
code: |
  struct Update {
      let view: String
      let microseconds: Int
  }

  struct ViewSummary {
      let view: String
      var count = 0
      var total = 0
      var longest = 0
  }

  func summarize(_ updates: [Update]) -> [ViewSummary] {
      var byView: [String: ViewSummary] = [:]
      for update in updates {
          var summary = byView[update.view] ?? ViewSummary(view: update.view)
          summary.count += 1
          summary.total += update.microseconds
          summary.longest = max(summary.longest, update.microseconds)
          byView[update.view] = summary
      }
      return byView.values.sorted { $0.total > $1.total }
  }

  let trace = Array(repeating: Update(view: "FeedCell", microseconds: 400), count: 50)
      + [Update(view: "Header", microseconds: 18_000)]
      + Array(repeating: Update(view: "Avatar", microseconds: 50), count: 300)

  let frameBudget = 16_700          // 60 Hz
  for summary in summarize(trace) {
      let kind = summary.longest > frameBudget ? "long update" : (summary.count > 100 ? "frequent" : "fine")
      print(summary.view, summary.count, summary.total / 1000, kind)
  }
output: |
  FeedCell 50 20 fine
  Header 1 18 long update
  Avatar 300 15 frequent
hints:
  - "Totals: 50 × 400 µs, 18,000 µs, 300 × 50 µs."
  - "Only Header has an update longer than 16.7 ms."
solution: |
  ```output
  FeedCell 50 20 fine
  Header 1 18 long update
  Avatar 300 15 frequent
  ```

  Sorted by total: `FeedCell` 20 ms, `Header` 18 ms, `Avatar` 15 ms. `FeedCell`'s updates are each 0.4 ms and there are 50 of them, below the model's "frequent" threshold. `Header` ran once for 18 ms, longer than a 60 Hz frame: a likely hitch, and the first thing to fix even though it isn't first in the list. `Avatar` ran 300 times; each is cheap, but 300 avatar updates in one interaction suggests they depend on something that changes far more often than avatars do. That's a job for Show Causes.
````

````exercise
id: m39-l05-e2
type: prediction
prompt: "Apple's hitch rate thresholds, applied to three recordings. What does it print?"
code: |
  func hitchRating(hitchMilliseconds: Double, seconds: Double) -> String {
      let rate = hitchMilliseconds / seconds
      let label: String
      switch rate {
      case ...10: label = "good"
      case ...25: label = "warning"
      case ...50: label = "critical"
      default: label = "needs immediate attention"
      }
      return "\(Int(rate.rounded())) ms/s, \(label)"
  }

  print(hitchRating(hitchMilliseconds: 100, seconds: 10))
  print(hitchRating(hitchMilliseconds: 200, seconds: 4))
  print(hitchRating(hitchMilliseconds: 90, seconds: 6))
output: |
  10 ms/s, good
  50 ms/s, critical
  15 ms/s, warning
hints:
  - "Divide, then compare: the boundaries are inclusive (at or below)."
solution: |
  ```output
  10 ms/s, good
  50 ms/s, critical
  15 ms/s, warning
  ```

  100 ÷ 10 = 10, exactly at the "good" boundary ("at or below 10 ms/s is good"). 200 ÷ 4 = 50, at the critical boundary. 90 ÷ 6 = 15, a warning. The `...10` patterns in the switch are the "at or below" in Apple's wording.
````

````exercise
id: m39-l05-e3
type: comprehension
prompt: "A trace of scrolling a feed shows a long Update Groups span, no individual view body update longer than 1 ms, and about 2,000 updates of FeedCell for 30 visible cells. What's the best next step in Instruments?"
choices:
  - text: "Set the inspection range to the group, then Show Causes on a FeedCell update to see what triggers them."
    correct: true
    why: "Many short updates are a frequency problem; the cause graph shows which state or object drives them."
  - text: "Zoom into the longest FeedCell body update and read the Time Profiler call tree."
    correct: false
    why: "No update is long; making one 1 ms body faster won't remove 2,000 of them."
  - text: "Switch the feed to a LazyVStack."
    correct: false
    why: "It may already be lazy, and it's a change, not a measurement; find the cause first."
  - text: "Add .equatable() to FeedCell."
    correct: false
    why: "Possibly part of a fix, but you don't know yet whether inputs or a dependency cause the updates."
solution: |
  **Show Causes on the update group.** 2,000 updates for 30 cells means each cell updates dozens of times during the scroll, almost certainly because it depends on something that changes on every frame (a scroll offset stored in state, an `ObservableObject` with a frequently published property, a timer). The cause-and-effect graph shows the edge from that source to `FeedCell`, and that tells you which of lesson 4's fixes applies.
````

````exercise
id: m39-l05-e4
type: solve
prompt: |
  Write `lateFrames(updateMilliseconds:refreshRate:)` that returns how many of the given main-thread update durations exceed one frame interval at that refresh rate (1000 ÷ rate milliseconds), and `budgetSummary` that prints the interval with one decimal and the count for 60 and 120 Hz. Use these durations from a scroll:

  ```swift
  let updates = [3.0, 4.5, 9.0, 12.0, 2.0, 17.5, 6.0, 8.0]
  ```
starter: |
  func lateFrames(updateMilliseconds: [Double], refreshRate: Double) -> Int {
      // your code
      0
  }

  let updates = [3.0, 4.5, 9.0, 12.0, 2.0, 17.5, 6.0, 8.0]
hints:
  - "At 60 Hz the interval is 16.7 ms; at 120 Hz, 8.3 ms."
  - "Format one decimal with (value * 10).rounded() / 10."
rubric:
  - Computes the interval as 1000 ÷ refresh rate.
  - Counts durations strictly greater than the interval.
  - Prints both rates with the interval to one decimal.
  - Notes that this is a lower bound because the app rarely has the full interval.
solution: |
  ```swift
  func frameInterval(refreshRate: Double) -> Double {
      1000 / refreshRate
  }

  func lateFrames(updateMilliseconds: [Double], refreshRate: Double) -> Int {
      let interval = frameInterval(refreshRate: refreshRate)
      return updateMilliseconds.filter { $0 > interval }.count
  }

  let updates = [3.0, 4.5, 9.0, 12.0, 2.0, 17.5, 6.0, 8.0]
  for rate in [60.0, 120.0] {
      let interval = (frameInterval(refreshRate: rate) * 10).rounded() / 10
      print("\(Int(rate)) Hz: \(interval) ms per frame, \(lateFrames(updateMilliseconds: updates, refreshRate: rate)) updates over budget")
  }
  ```

  ```output
  60 Hz: 16.7 ms per frame, 1 updates over budget
  120 Hz: 8.3 ms per frame, 3 updates over budget
  ```

  At 60 Hz only the 17.5 ms update exceeds the interval; at 120 Hz, 9, 12 and 17.5 do. This count is optimistic: Apple notes "you might not have the full display refresh interval," and suggests aiming for under 5 ms of main-thread work, which only three of these eight updates meet. The same scroll that's fine on a 60 Hz device can hitch on a 120 Hz one.
````

````exercise
id: m39-l05-e5
type: fill-in
prompt: "Complete the signposted interval around an image decode, so it appears in Instruments' Points of Interest track."
code: |
  import Foundation
  import os

  let signposter = OSSignposter(subsystem: "com.example.Gallery", category: .[[1]])

  @MainActor
  func decodeThumbnail(_ data: Data) -> Int {
      let id = signposter.[[2]]()
      let state = signposter.[[3]]("Decode", id: id)
      let pixels = data.count / 4          // stands in for real decoding
      signposter.[[4]]("Decode", state)
      return pixels
  }
blanks:
  - id: "1"
    answers: ["pointsOfInterest"]
  - id: "2"
    answers: ["makeSignpostID"]
  - id: "3"
    answers: ["beginInterval"]
  - id: "4"
    answers: ["endInterval"]
hints:
  - "The OSLog.Category that Instruments shows in its own track."
  - "The end call takes the name and the state the begin call returned."
solution: |
  ```swift ios
  import Foundation
  import os

  let signposter = OSSignposter(subsystem: "com.example.Gallery", category: .pointsOfInterest)

  @MainActor
  func decodeThumbnail(_ data: Data) -> Int {
      let id = signposter.makeSignpostID()
      let state = signposter.beginInterval("Decode", id: id)
      let pixels = data.count / 4          // stands in for real decoding
      signposter.endInterval("Decode", state)
      return pixels
  }

  print(decodeThumbnail(Data(count: 400)))
  ```

  `.pointsOfInterest` puts the intervals in the Points of Interest track. `makeSignpostID()` returns an id "unique within the scope of the signposter," so concurrent decodes don't get paired with each other's ends. `beginInterval` returns the state that `endInterval` consumes. `withIntervalSignpost("Decode") { … }` does the same in one call.
````

````exercise
id: m39-l05-e6
type: find-errors
prompt: "A teammate reports: 'I profiled the feed and it's fine, the slowness must be the network.' Which of these points in their method are real problems?"
code: |
  1. Ran the app from Xcode with Run (Debug) on the iPhone simulator.
  2. Attached Instruments' Time Profiler template while scrolling.
  3. Used the demo account with 15 posts.
  4. Recorded app launch, login, scrolling and opening a post in one trace.
  5. Added Self._printChanges() to every view during the recording to count updates.
  6. Looked for functions from their own module in the heaviest stack trace.
choices:
  - text: "Profiling in the simulator."
    correct: true
    why: "Apple: never profile in the simulator; use a real device."
  - text: "Profiling a Debug build instead of using Product > Profile."
    correct: true
    why: "Profile builds Release; Debug performance differs."
  - text: "15 posts isn't production-sized data."
    correct: true
    why: "Problems that scale with data don't show up."
  - text: "Recording several interactions in one trace."
    correct: true
    why: "It's hard to attribute updates and hitches to one interaction."
  - text: "_printChanges() in every view during a performance recording."
    correct: true
    why: "Console logging on every body evaluation adds work and distorts the measurement."
  - text: "Looking for their own module's functions in the heaviest stack trace."
    correct: false
    why: "That's a reasonable step in the Time Profiler (Module 33)."
rubric:
  - Flags the simulator and the Debug build.
  - Flags the small data set and the mixed recording.
  - Flags _printChanges during measurement.
  - Accepts the heaviest-stack step as valid.
solution: |
  Five of the six are problems; only the last step is sound. A repeatable method: Product > Profile with the SwiftUI template, on the slowest supported device, signed in to an account with realistic data (or launched with a fixture), recording only the scroll, with no debugging output. Then the summary and update groups say whether the feed is slow because of long bodies, frequent updates, or neither, in which case signposts around the network and decoding code would show whether the teammate's theory holds.
````

````exercise
id: m39-l05-e7
type: design
prompt: "Users report that the order history screen stutters when scrolling on older iPhones. Write a profiling plan: what you'd set up, what you'd record, what you'd look at first, how you'd decide between a long-update fix and a frequency fix, and how you'd confirm the fix."
rubric:
  - Release build via Product > Profile on an older physical device, with production-sized data.
  - Records only the scroll with the SwiftUI template; optionally adds signposts around model work.
  - Checks the summary for long updates versus high counts, and the Hitches lane for when frames were late.
  - Uses Time Profiler on the range for long updates and Show Causes for frequent ones.
  - Re-records the same interaction after the fix and compares; adds a performance test for any model function changed.
solution: |
  A sample plan:

  1. **Setup.** The oldest iPhone we support, a Release build via Product > Profile, an account (or launch fixture) with a few thousand orders. Signposts around order loading and formatting so model work shows on the timeline.
  2. **Record.** SwiftUI template, deferred recording, open the screen, wait for it to settle, then scroll top to bottom twice. Nothing else.
  3. **First look.** The Hitches lane: when were frames late? The summary of all updates: which views have the longest single update, and which have the highest counts.
  4. **Decide.** If a row or header has updates over the frame budget, set the inspection range on one, use Time Profiler and Show Calls Made by that body, and move the expensive part out of `body` (for example, date and currency formatting precomputed in the model). If instead rows update hundreds of times with short durations, open the update group, Show Causes, and find the state or object driving them; fix the dependency.
  5. **Confirm.** Record the same scroll again on the same device and compare the hitch count, the longest update and the counts. Keep a `measure` test for the model function that changed (Module 33), and remove the signposts or keep them if they're cheap and useful.
````

## Summary

- Profile a Release build (Product > Profile) on a real device, with realistic data, one interaction per recording.
- The SwiftUI template's track has lanes for View Body Updates, Platform View Updates, Other Updates and Update Groups, next to Hitches and Time Profiler. The summary groups updates by module, view and category. (All from Apple's article; not checked in Instruments here.)
- Long view body updates: set the inspection range, read the Time Profiler call tree or flame graph, and move the work out of `body`.
- Many short updates: inspect the update group, Show Causes, and follow the edges from the changing state or object to the views. Blue nodes are yours.
- Frame intervals are 16.7 ms at 60 Hz and 8.3 ms at 120 Hz; under 5 ms of main-thread work is usually safe. Hitch rate: ≤10 ms/s good, ≤25 warning, ≤50 critical.
- `OSSignposter` intervals put your own work on the timeline. `_printChanges()` is an undocumented aid for one view at a time; remove it before measuring.
