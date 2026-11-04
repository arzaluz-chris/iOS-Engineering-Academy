---
id: m21-l03
title: The main thread, the run loop and events
description: Why one thread runs your whole UI, and what happens when you make it wait. You see the main run loop process work items one at a time, watch a real timer arrive late because the main thread was busy, follow a touch from the glass to your code, learn the frame budget at 60 and 120 Hz, and meet @MainActor, the compiler's way of keeping UI code on the main thread.
module: m21
order: 3
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m21-l02]
objectives:
  - Explain why UI work must happen on the main thread and what the main thread is responsible for.
  - Describe the main run loop and the kinds of work it processes.
  - Trace a touch from the hardware to your handler, including hit-testing and the responder chain.
  - Compute the frame budget for a display refresh rate and tell a hitch from a hang.
  - Use @MainActor to make the compiler enforce main-thread access, and read its isolation error.
terms:
  - term: Main thread
    definition: "The thread your app starts on. It handles incoming events and is the only thread allowed to change the UI."
  - term: Run loop
    definition: "A loop attached to a thread that sleeps until work arrives (an event, a timer, a queued block), runs it, and goes back to sleep. The main thread's is the main run loop."
  - term: "@MainActor"
    definition: "A global actor whose executor is the main dispatch queue. Code marked @MainActor runs on the main thread, and the compiler rejects synchronous calls into it from code that isn't."
  - term: Hit-testing
    definition: "How UIKit finds which view a touch belongs to: it walks the view hierarchy for the deepest view whose bounds contain the touch location."
  - term: Responder chain
    definition: "The sequence of responder objects (view, superview, view controller, window, scene, application) that an unhandled event is passed along."
  - term: Hitch
    definition: "A frame that isn't ready by the display's refresh, so motion stutters. A delay of one refresh interval (about 8–17 ms) is enough."
  - term: Hang
    definition: "A noticeable delay between a discrete interaction, like a tap, and the screen update. Apple says delays over about 100 ms start to be noticed; most tools report from 250 ms."
mastery:
  - Explain why a 400 ms task in a button handler delays timers and other taps that arrive meanwhile.
  - Predict the order in which queued main run loop work runs relative to the code that queued it.
  - Compute the frame interval at 60 and 120 Hz and say how many frames a given amount of main-thread work misses.
  - Describe hit-testing and what happens to a touch nobody handles.
  - Fix "call to main actor-isolated … in a synchronous nonisolated context" by isolating the caller, and say when that's the right fix.
resources: [swift-mainactor, understanding-hangs, swift-book]
cards:
  - id: m21-l03-c1
    front: Why does only one thread update the UI?
    back: "UI updates aren't thread-safe, so they have to be serialized. Apple's frameworks do that by allowing only the main thread to change the view hierarchy."
  - id: m21-l03-c2
    front: What kinds of work does the main run loop process?
    back: "Incoming user events, timer callbacks scheduled on it, and work submitted to the main dispatch queue, the main operation queue or the main actor. They all run one at a time on the main thread."
  - id: m21-l03-c3
    front: Frame interval at 60 Hz and at 120 Hz?
    back: "16.7 ms and 8.3 ms. Apple: main-thread work under about 5 ms per update is usually ready in time."
  - id: m21-l03-c4
    front: Hitch vs hang?
    back: "A hitch is a late frame during motion (one refresh interval late is enough). A hang is a noticeable delay after a discrete action like a tap (over about 100 ms). Both usually come from too much work on the main thread."
  - id: m21-l03-c5
    front: "What does \"call to main actor-isolated global function in a synchronous nonisolated context\" mean?"
    back: "Code that isn't known to be on the main actor called a @MainActor function synchronously. Either the caller belongs on the main actor too (mark it @MainActor) or it must call asynchronously, which Module 29 covers."
---

## The idea in one sentence

Your app's UI is driven by one thread running one loop: it wakes when something happens, runs the matching code to completion, hands the changes to the system to draw, and sleeps again, so anything slow you do there delays every touch, timer and frame queued behind it.

> [!note] Sources and what was run
> The descriptions of the main thread, run loop, event delivery and rendering come from Apple's articles "Understanding user interface responsiveness", "Understanding hangs in your app", "Improving app responsiveness" and "Using responders and the responder chain to handle events" (read November 2026). The Swift blocks were compiled and run with Swift 6.3 on Linux, where Foundation provides `RunLoop`, `Timer` and `Thread`. The one SwiftUI block was type-checked against the iOS SDK, not run.

## The main thread

When the system starts your process it creates one thread, the **main thread**. Lesson 2 ended with `UIApplicationMain` starting "the main event loop" on it and never returning. From then on, Apple's frameworks give the main thread two jobs:

1. **Handle incoming events**: touches, key presses, timers, results of work you scheduled.
2. **Update the UI.** Apple's hang article: updating the UI "isn't thread-safe", so updates must be serialized, and "for this reason, there's only one thread that can make UI updates: the main thread." UIKit's `UIView` documentation says the same: "Manipulations to your app's user interface must occur on the main thread."

Handling one event goes through three stages, all on the main thread:

1. **Event delivery**: UIKit or SwiftUI finds the right view and calls its handler.
2. **Your code**: state changes, data work, UI updates. This is where your time goes.
3. **The Core Animation commit**: the framework sends all the view changes to the render server. It usually happens automatically when your handler returns.

## The run loop

The main thread can't simply wait for a tap, because timers fire and network results arrive too. Something has to collect all of that and run it in order. That's the **run loop**. Apple's hang article sketches it like this (simplified, not the real implementation):

```pseudo
Repeat until stopped
    If there is a work item then
        Process the work item
    Else
        Sleep until new work arrives
```

Work items include incoming user events, the callbacks of timers scheduled on the run loop, and work submitted to the main `DispatchQueue`, the main `OperationQueue` or the main actor. Apple's description of how they relate: "The main dispatch queue, the main `NSOperationQueue`, and the main actor are clients of the run loop", and the run loop executes them all on the main thread, **one at a time**.

Foundation's `RunLoop` exists outside Apple platforms too, so the behavior can be shown in a plain program. `RunLoop.main.perform` queues a block on the main run loop; it runs only when the loop gets a chance:

```swift
import Foundation

print("1. top-level code starts")
RunLoop.main.perform {
    print("3. first work item")
}
RunLoop.main.perform {
    print("4. second work item")
}
print("2. top-level code ends; nothing above has run yet")
RunLoop.main.run(until: Date().addingTimeInterval(0.1))
print("5. run loop returned")
```

```output
1. top-level code starts
2. top-level code ends; nothing above has run yet
3. first work item
4. second work item
5. run loop returned
```

Line by line:

1. `perform` doesn't run the block. It adds it to the run loop's queue and returns.
2. The current code keeps the main thread until it finishes, which is why line 2 prints before 3.
3. `RunLoop.main.run(until:)` hands the thread to the loop for up to 0.1 seconds. The loop finds two items and runs them in the order they were queued.

In an app you never call `run(until:)`; `UIApplicationMain` runs the loop forever, and **every** event handler and callback you write is one of these work items.

### A busy main thread makes everything late

Here's a timer due in 50 ms, and a handler that keeps the main thread busy for 300 ms before the run loop gets control back:

```swift
import Foundation

let start = Date()

// A timer that should fire 50 ms from now, on the main run loop.
let timer = Timer(timeInterval: 0.05, repeats: false) { _ in
    let elapsed = Date().timeIntervalSince(start)
    print("timer fired; at least 300 ms had passed: \(elapsed >= 0.3)")
}
RunLoop.main.add(timer, forMode: .default)

// A slow "event handler": it keeps the main thread busy for 300 ms.
print("handler starts")
Thread.sleep(forTimeInterval: 0.3)
print("handler ends")

// Back in the run loop, pending work finally runs.
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
print("done")
```

```output
handler starts
handler ends
timer fired; at least 300 ms had passed: true
done
```

The timer was due at 50 ms and couldn't fire until the handler returned. In an app, the same thing happens to a tap that arrives during the slow handler, to an animation's next frame, and to the result of a network request. `Thread.sleep` stands in for real slow work: decoding a big JSON file, resizing images, a synchronous network call, a heavy database query.

> [!tip] Asleep is the healthy state
> Apple: "Ideally, the run loop only wakes up briefly to process an incoming event, goes to sleep again, and spends most of the time asleep waiting for new work." In Instruments, a healthy main thread looks mostly idle.

## From a finger to your code

Apple's responsiveness article describes the path of one touch:

1. **Hardware**: the touchscreen recognizes the contact and passes it to the operating system.
2. **OS event delivery**: the system decides which process owns the event (usually the app in front).
3. **Main thread**: the event goes into an app-specific queue; the main run loop picks it up.
4. **Hit-testing**: UIKit compares the touch location with the views' bounds. `hitTest(_:with:)` walks the hierarchy looking for "the deepest subview that contains the specified touch", which becomes the first responder for that touch.
5. **Gesture recognizers first**: they "receive touch and press events before their view does." If they don't recognize a gesture, the view gets the touches.
6. **The responder chain**: if the view doesn't handle the event, UIKit passes it to the next responder: the superview, up to the view controller's root view, the view controller, the window, the window scene, the `UIApplication`, and possibly the app delegate.

Two details from the same articles explain behavior you'll see:

- A touch stays with the view it started in. The touch-up "goes to the same view that received the corresponding touch-down event, even if the finger has moved", and a `Button` only runs its action if the finger is still inside its bounds.
- A subview outside its parent's bounds can't receive touches, even if it's visible, because hit-testing skips a view and all its subviews when the touch is outside that view.

Module 22 builds on this with target-action and delegation.

## Frames: the render loop

After your handler returns, the Core Animation commit sends the changed layer tree to the **render server**, which Apple describes as "a separate process" that composites every app's layers into the final image. The display picks up a new image at each **vsync**, a fixed interval set by the refresh rate.

That interval is your budget:

```swift
import Foundation

func frameInterval(hz: Double) -> Double {
    1000 / hz
}

func missedFrames(mainThreadWorkMs: Double, hz: Double) -> Int {
    let interval = frameInterval(hz: hz)
    var missed = 0
    var budget = interval
    while mainThreadWorkMs > budget {
        missed += 1
        budget += interval
    }
    return missed
}

for hz in [60.0, 120.0] {
    let interval = frameInterval(hz: hz)
    print("\(Int(hz)) Hz: a frame every \((interval * 10).rounded() / 10) ms")
}
for work in [4.0, 12.0, 30.0, 210.0] {
    let at60 = missedFrames(mainThreadWorkMs: work, hz: 60)
    let at120 = missedFrames(mainThreadWorkMs: work, hz: 120)
    print("\(work) ms of work: misses \(at60) at 60 Hz, \(at120) at 120 Hz")
}
```

```output
60 Hz: a frame every 16.7 ms
120 Hz: a frame every 8.3 ms
4.0 ms of work: misses 0 at 60 Hz, 0 at 120 Hz
12.0 ms of work: misses 0 at 60 Hz, 1 at 120 Hz
30.0 ms of work: misses 1 at 60 Hz, 3 at 120 Hz
210.0 ms of work: misses 12 at 60 Hz, 25 at 120 Hz
```

This is a simplification (the render server needs part of each interval too, so the real budget is smaller), but the shape is right: work that's fine at 60 Hz can stutter at 120 Hz. Apple's rough targets:

- **Under one refresh interval** (8 or 17 ms) for main-thread work during continuous interactions like scrolling. Apple adds that under about 5 ms "the update is usually ready in time."
- **Under 100 ms** for the synchronous work after a discrete interaction like a tap, and you only get part of that, because delivery and rendering take time too.

Missing the first target causes **hitches**: a scroll that sticks and jumps. Missing the second causes **hangs**: a tap that seems ignored. Apple's tools start reporting hangs when the main run loop is busy for more than **250 ms**. Lesson 6 shows how to find which code is responsible.

## @MainActor: the compiler's version of the rule

"Only touch the UI from the main thread" used to be a convention you could break and find out at runtime. Swift concurrency turns it into a compile-time rule. `MainActor` is, in Apple's words, "a singleton actor whose executor is equivalent to the main dispatch queue". Mark a function, property or type `@MainActor` and it runs on the main thread, and the compiler checks every call into it.

UIKit and SwiftUI already do this for you. `UIView`, `UIViewController` and the delegate protocols from lesson 2 are main-actor isolated; SwiftUI's `App` is declared `@MainActor @preconcurrency protocol App`.

In a `main.swift`, top-level code is on the main actor, so it can call a `@MainActor` function directly:

```swift
import Foundation

@MainActor
func updateTitle(_ title: String) {
    print("on the main thread: \(Thread.isMainThread)")
    print("title is now \(title)")
}

updateTitle("Inbox (3)")
```

```output
on the main thread: true
title is now Inbox (3)
```

A plain function isn't known to be on the main actor, so calling the same function from it is rejected:

```swift no-compile call to main actor-isolated global function 'updateTitle' in a synchronous nonisolated context
@MainActor
func updateTitle(_ title: String) {
    print("title is now \(title)")
}

func refreshFromNetwork() {
    updateTitle("Inbox (3)")
}

refreshFromNetwork()
```

Swift 6.3 reports `error: call to main actor-isolated global function 'updateTitle' in a synchronous nonisolated context`, with the note `add '@MainActor' to make global function 'refreshFromNetwork()' part of global actor 'MainActor'`. That note is one of two fixes:

- If `refreshFromNetwork` is UI code (it reads views, updates state the screen shows), mark it `@MainActor` too. Now both run on the main thread and the call is synchronous.
- If it's slow work that shouldn't block the main thread, don't pull it onto the main actor. Do the work elsewhere and **asynchronously** hop to the main actor to show the result. That needs `async`/`await`, which Module 29 teaches.

> [!warning] Async doesn't mean "off the main thread"
> Apple's "Improving app responsiveness" shows a trap: wrapping slow synchronous work in `Task { }` inside a SwiftUI view still runs it on the main actor, because the task inherits its surroundings, so the hang just happens a moment later. Which thread a `nonisolated async` function runs on also depends on a language setting introduced in Swift 6.2 (SE-0461, on with Xcode's "Approachable Concurrency" build setting). Module 29 sorts this out properly. For now: decide where heavy work runs on purpose, and measure.

Here's the shape of the trap, adapted from Apple's article (type-checked against the iOS SDK, not run):

```swift ios
import SwiftUI

func doLongRunningWork() {
    // Imagine a few hundred milliseconds of synchronous work here.
}

struct ContentView: View {
    var body: some View {
        Button("Hang later!") {
            Task {
                doLongRunningWork()   // synchronous and slow: still blocks the main actor
                updateUI()
            }
        }
    }

    @MainActor func updateUI() {
        // Update the state the screen shows.
    }
}
```

> [!note] Default main-actor isolation
> Xcode has a "Default Actor Isolation" build setting (`SWIFT_DEFAULT_ACTOR_ISOLATION`). Set to `MainActor`, unannotated code in that target is treated as `@MainActor` (SE-0466, Swift 6.2). That makes UI-heavy app code simpler and the error above rarer; it also means heavy work you write without thinking runs on the main thread. This lesson didn't verify which value Xcode 27's templates choose; check your target's build settings.

## What runs where

Apple's article walks through a pull-to-refresh: the action method and updating the views need the main thread; the network request, the JSON decoding and updating model objects don't. A rule of thumb that follows from it:

| On the main thread | Off the main thread |
| --- | --- |
| Responding to the event | Network requests |
| Updating views and the state they display | Decoding and encoding (JSON, images) |
| Small, quick model updates the screen depends on | Database queries over many rows |
| Starting background work and showing progress | Image resizing, filtering, compression |

## Common mistakes

> [!error] Doing slow work in an event handler "because it's only once"
> A 400 ms decode in a button action is a 400 ms hang, and the timers and taps queued behind it wait too. Start the work elsewhere and update the UI when it's done.

> [!error] Updating the UI from a background thread
> UIKit's docs require the main thread. Without `@MainActor` checks this fails unpredictably: views that don't update, crashes far from the cause. Let the compiler enforce it.

> [!error] Silencing the isolation error by making everything @MainActor
> It compiles, and then the slow parts run on the main thread too. Mark UI code `@MainActor`; keep heavy work out of it.

> [!error] Testing smoothness only on a 60 Hz screen
> 12 ms of work per frame is fine at 60 Hz and drops a frame at 120 Hz. Test on the device class your users have.

> [!error] Expecting touches on a subview outside its parent's bounds
> Hit-testing skips a view's subviews when the touch is outside that view's bounds, even if they're drawn there.

## Exercises

````exercise
id: m21-l03-e1
type: prediction
prompt: What does this program print?
code: |
  import Foundation

  RunLoop.main.perform {
      print("B")
  }
  print("A")
  RunLoop.main.perform {
      print("C")
  }
  RunLoop.main.run(until: Date().addingTimeInterval(0.1))
  print("D")
output: |
  A
  B
  C
  D
hints:
  - "perform queues the block; it doesn't run it."
  - "Queued blocks run in order once the run loop runs."
solution: |
  ```output
  A
  B
  C
  D
  ```

  The top-level code owns the main thread until it calls `run(until:)`, so `A` prints first even though the `B` block was queued before it. The run loop then runs its queue in order (`B`, `C`) and returns after 0.1 seconds, and `D` prints. In an app, this is why UI work you queue on the main thread never interrupts the handler that's currently running.
````

````exercise
id: m21-l03-e2
type: prediction
prompt: "A simulated main thread handles three work items, each starting only when the previous one has finished. What does it print?"
code: |
  struct WorkItem {
      let name: String
      let arrivesAt: Int
      let durationMs: Int
  }

  var clock = 0
  let items = [
      WorkItem(name: "tap Refresh", arrivesAt: 0, durationMs: 400),
      WorkItem(name: "timer tick", arrivesAt: 50, durationMs: 2),
      WorkItem(name: "tap Back", arrivesAt: 120, durationMs: 5),
  ]
  for item in items {
      if clock < item.arrivesAt {
          clock = item.arrivesAt
      }
      let waited = clock - item.arrivesAt
      clock += item.durationMs
      print("\(item.name): waited \(waited) ms")
  }
output: |
  tap Refresh: waited 0 ms
  timer tick: waited 350 ms
  tap Back: waited 282 ms
hints:
  - "After the first item, the clock is at 400."
  - "The timer arrived at 50 but starts at 400; it ends at 402."
solution: |
  ```output
  tap Refresh: waited 0 ms
  timer tick: waited 350 ms
  tap Back: waited 282 ms
  ```

  `tap Refresh` starts at 0 and runs to 400. The timer, due at 50, starts at 400 (waited 350) and finishes at 402. `tap Back`, which arrived at 120, starts at 402: it waited 282 ms, well past the ~100 ms where people notice. One slow handler made two other things late, which is the busy-main-thread hang from Apple's articles.
````

````exercise
id: m21-l03-e3
type: comprehension
multiple: true
prompt: Which of these are processed as work items by the main run loop, on the main thread? Mark all that apply.
choices:
  - text: A touch event being delivered to a button.
    correct: true
    why: User events arrive in the app's queue and the main thread processes them.
  - text: "A `Timer` scheduled on the main run loop firing."
    correct: true
    why: "Timer callbacks are run-loop work, which is why a busy main thread delays them."
  - text: "A block submitted with `DispatchQueue.main.async`."
    correct: true
    why: The main dispatch queue is a client of the main run loop.
  - text: The render server compositing the final frame.
    correct: false
    why: The render server is a separate process; it isn't your main thread.
  - text: "A `@MainActor` function called from top-level code."
    correct: true
    why: The main actor's executor is the main queue, so its work runs on the main thread too.
solution: |
  Everything except the render server. Events, main run loop timers, the main dispatch queue and main-actor work all end up as items on the main run loop, executed one at a time. Compositing happens in the render server, a separate process; your app only sends it the layer changes in the Core Animation commit.
````

````exercise
id: m21-l03-e4
type: find-errors
prompt: "A photo app's code. Mark every real problem with how it uses the main thread."
code: |
  @MainActor
  final class GalleryScreen {
      var thumbnails: [String] = []

      func didTapImport(paths: [String]) {
          for path in paths {
              let resized = resizeImage(at: path, maxSide: 2048)   // ~150 ms each
              thumbnails.append(resized)
          }
          showThumbnails()
      }

      func showThumbnails() {
          print("showing \(thumbnails.count) thumbnails")
      }
  }

  func resizeImage(at path: String, maxSide: Int) -> String {
      // decodes and scales a full-size photo
      return path + "@thumb"
  }
choices:
  - text: "Resizing every photo inside didTapImport runs on the main thread; with 20 photos that's about 3 seconds of hang."
    correct: true
  - text: "Nothing redraws until the whole loop finishes, so the user sees no progress at all."
    correct: true
  - text: "@MainActor on GalleryScreen is wrong; UI classes shouldn't be isolated."
    correct: false
    why: "A screen that owns UI state belongs on the main actor. The problem is the heavy work inside it."
  - text: "resizeImage must also be marked @MainActor, or the call won't compile."
    correct: false
    why: "resizeImage is a synchronous nonisolated function; calling it from the main actor is allowed. Marking it @MainActor would only make things worse."
rubric:
  - I identified the image resizing as main-thread work in an event handler.
  - I estimated the hang from the number of photos.
  - I noticed the UI can't update during the loop.
  - I kept @MainActor on the screen and proposed moving only the resizing off the main thread.
solution: |
  The class is correctly isolated: it holds what the screen shows. The problem is **what it does there**. `resizeImage` is synchronous and slow, and `didTapImport` calls it in a loop on the main thread, so 20 photos block the run loop for about 3 seconds. During that time no frame is committed, so there's no progress indicator either, and every tap queues up behind it.

  The fix keeps `GalleryScreen` on the main actor, runs the resizing off the main thread, and appends each finished thumbnail back on the main actor so progress shows as it goes. How to write that safely is Module 29's job; the decision about **where** the work runs is this lesson's.

  Calling a synchronous nonisolated function from main-actor code compiles fine; it just runs on the main thread, which is exactly the problem here.
````

````exercise
id: m21-l03-e5
type: solve
prompt: |
  Write `worstWait(_:)` for the work-item simulator in exercise 2. Given a list of work items (already sorted by arrival time), it returns the name of the item that waited longest before starting, and that wait in milliseconds. Then use it to show that splitting a 400 ms import into four 100 ms chunks, with a tap arriving at 120 ms, cuts the worst wait.

  ```swift
  let oneBigItem = [
      WorkItem(name: "import", arrivesAt: 0, durationMs: 400),
      WorkItem(name: "tap", arrivesAt: 120, durationMs: 5),
  ]
  let chunked = [
      WorkItem(name: "import 1", arrivesAt: 0, durationMs: 100),
      WorkItem(name: "import 2", arrivesAt: 100, durationMs: 100),
      WorkItem(name: "tap", arrivesAt: 120, durationMs: 5),
      WorkItem(name: "import 3", arrivesAt: 200, durationMs: 100),
      WorkItem(name: "import 4", arrivesAt: 300, durationMs: 100),
  ]
  ```

  Expected output:

  ```output
  one big item: tap waited 280 ms
  chunked: tap waited 80 ms
  ```
starter: |
  struct WorkItem {
      let name: String
      let arrivesAt: Int
      let durationMs: Int
  }

  func worstWait(_ items: [WorkItem]) -> (name: String, waited: Int) {
      // your code
      return ("", 0)
  }
hints:
  - "Reuse the clock logic from exercise 2: if the clock is behind an item's arrival, jump forward; the wait is clock minus arrival."
  - "Track the largest wait and the name that had it."
  - "Return a tuple with labels so the call site reads result.name and result.waited."
rubric:
  - Advances the clock to each item's arrival when the main thread was idle.
  - Computes each wait as start time minus arrival time.
  - Returns the name and wait of the longest one.
  - Prints both scenarios in the expected format.
solution: |
  ```swift
  struct WorkItem {
      let name: String
      let arrivesAt: Int
      let durationMs: Int
  }

  func worstWait(_ items: [WorkItem]) -> (name: String, waited: Int) {
      var clock = 0
      var worst = (name: "", waited: 0)
      for item in items {
          if clock < item.arrivesAt {
              clock = item.arrivesAt
          }
          let waited = clock - item.arrivesAt
          if waited > worst.waited {
              worst = (item.name, waited)
          }
          clock += item.durationMs
      }
      return worst
  }

  let oneBigItem = [
      WorkItem(name: "import", arrivesAt: 0, durationMs: 400),
      WorkItem(name: "tap", arrivesAt: 120, durationMs: 5),
  ]
  let chunked = [
      WorkItem(name: "import 1", arrivesAt: 0, durationMs: 100),
      WorkItem(name: "import 2", arrivesAt: 100, durationMs: 100),
      WorkItem(name: "tap", arrivesAt: 120, durationMs: 5),
      WorkItem(name: "import 3", arrivesAt: 200, durationMs: 100),
      WorkItem(name: "import 4", arrivesAt: 300, durationMs: 100),
  ]

  let big = worstWait(oneBigItem)
  print("one big item: \(big.name) waited \(big.waited) ms")
  let small = worstWait(chunked)
  print("chunked: \(small.name) waited \(small.waited) ms")
  ```

  ```output
  one big item: tap waited 280 ms
  chunked: tap waited 80 ms
  ```

  With one 400 ms item, the tap waits until 400: 280 ms, a hang. Chunked, the tap only waits for the chunk that's running when it arrives (`import 2`, from 100 to 200), so 80 ms. The total work is the same; the main thread just gets back to the run loop more often. That's one strategy; moving the work off the main thread entirely is usually better, and it's what Apple's articles recommend first.
````

````exercise
id: m21-l03-e6
type: explain
prompt: "A teammate says: \"The app gets 60 fps on my phone, so there are no hangs.\" Explain why frame rate during scrolling and hangs after taps are different problems, with the thresholds from this lesson."
code: |
  // During scrolling: each frame's main-thread work is 6 ms.
  // Tapping "Export": the handler runs 900 ms of PDF generation.
rubric:
  - I defined a hitch as a missed frame during continuous motion, tied to the refresh interval (16.7 ms at 60 Hz, 8.3 ms at 120 Hz).
  - I defined a hang as a long delay after a discrete action, noticeable over about 100 ms, reported by tools over 250 ms.
  - I noted that 6 ms per frame is within budget at 60 Hz but tight at 120 Hz.
  - I explained the 900 ms export is a hang regardless of scrolling frame rate, and that it also blocks timers and other events.
solution: |
  They measure different things. **Hitches** are about continuous motion: each frame must be ready by the next refresh, 16.7 ms at 60 Hz or 8.3 ms at 120 Hz. Six milliseconds of main-thread work per frame fits at 60 Hz and is tight at 120 Hz once rendering takes its share; Apple suggests staying under about 5 ms.

  **Hangs** are about discrete actions. The 900 ms export runs inside one event handler, so for 900 ms the main run loop processes nothing else: no frames, no timers, no other taps. Apple says delays start to be noticeable around 100 ms and its tools report hangs over 250 ms. Smooth scrolling elsewhere says nothing about it.

  The fix is the same idea in both cases (less work on the main thread), but you find them differently: scroll and watch for stutter at 120 Hz; tap and watch the main thread's busy time in Instruments (lesson 6).
````

## Summary

- The main thread handles events and is the only thread that may change the UI, because UI updates must be serialized.
- The main run loop sleeps until work arrives, then runs it one item at a time: events, timers, main queue and main actor work. A slow item delays everything behind it.
- A touch goes hardware → OS → app queue → main thread → hit-testing (deepest view containing it) → gesture recognizers → view → responder chain.
- The frame interval is 16.7 ms at 60 Hz and 8.3 ms at 120 Hz. Missing it causes hitches; long handlers after a tap cause hangs (noticeable over ~100 ms, reported over 250 ms).
- `@MainActor` makes the compiler enforce the main-thread rule. "Call to main actor-isolated … in a synchronous nonisolated context" means the caller isn't on the main actor: isolate it if it's UI code, or call asynchronously (Module 29) if it isn't.
- Keep the main thread for events and view updates; move networking, decoding and heavy processing elsewhere.
