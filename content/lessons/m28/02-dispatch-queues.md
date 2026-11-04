---
id: m28-l02
title: Dispatch queues
description: Grand Central Dispatch's core idea is that you don't manage threads, you submit closures to queues. You learn serial and concurrent queues, the main queue and the global queues with their quality-of-service classes, when to create your own queue, the difference between async and sync, what a target queue does, and how DispatchWorkItem lets you cancel work that hasn't started.
module: m28
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l01]
objectives:
  - Explain what a dispatch queue is and what it guarantees about order and threads.
  - Choose between a serial and a concurrent queue for a job.
  - Pick a global queue by quality-of-service class and justify the choice.
  - Create a custom queue with a label, QoS and target queue.
  - Predict what async and sync do to the calling code, including the value sync returns.
  - Cancel a DispatchWorkItem that hasn't started, and say why cancel can't stop one that has.
terms:
  - term: Dispatch queue
    definition: "A FIFO queue of closures (work items) managed by Grand Central Dispatch. The queue decides when each item runs and on which of the system's threads."
  - term: Serial queue
    definition: "A queue that runs one work item at a time, in the order they were submitted. The main queue and queues you create without attributes are serial."
  - term: Concurrent queue
    definition: "A queue that starts work items in order but lets several run at the same time, so they can finish in any order. The global queues are concurrent."
  - term: Quality of service (QoS)
    definition: "A class (userInteractive, userInitiated, default, utility, background) that tells the system how important work is to the user, so it can prioritize it and choose cores and power use."
  - term: Target queue
    definition: "The queue a dispatch queue forwards its work items to. Serial queues that share a serial target never run their items at the same time."
  - term: DispatchWorkItem
    definition: "An object wrapping a closure for a queue. It can be cancelled before it starts, waited on, or given a notify closure for when it finishes."
mastery:
  - Predict the order of prints from closures submitted with async to a serial queue followed by a sync.
  - Explain why work submitted to a concurrent queue can finish in a different order, and collect results so the output doesn't depend on it.
  - Choose a QoS class for loading an email the user just tapped, for a prefetch, and for a cleanup job.
  - Create a labeled serial queue that targets a global queue.
  - Cancel a queued DispatchWorkItem and predict which items still run.
resources: [understanding-hangs, swift-mainactor]
cards:
  - id: m28-l02-c1
    front: Serial vs concurrent dispatch queue?
    back: "Serial: one work item at a time, in submission order. Concurrent: items start in submission order but can run at the same time and finish in any order."
  - id: m28-l02-c2
    front: async vs sync on a dispatch queue?
    back: "async submits the closure and returns immediately. sync submits it and waits until it has run, then returns its result. sync on the queue you're already on deadlocks."
  - id: m28-l02-c3
    front: The QoS classes, highest to lowest?
    back: "userInteractive (UI, animations), userInitiated (results the user is waiting for), default, utility (long work the user isn't watching), background (maintenance)."
  - id: m28-l02-c4
    front: What does DispatchWorkItem.cancel() do to an item that's already running?
    back: "Nothing. Apple: cancellation makes future attempts to run it return immediately, and \"does not affect the execution of a work item that has already begun.\""
  - id: m28-l02-c5
    front: Why give a custom serial queue a global queue as its target?
    back: "So it doesn't need its own threads. Apple recommends it to limit thread use; the queue keeps its serial behavior and inherits the target's minimum QoS."
---

## The idea in one sentence

With Grand Central Dispatch you stop thinking about threads: you put closures on a **queue**, the queue promises an order (one at a time, or several at once), and the system decides which of its threads runs each one.

> [!note] Sources and what was run
> Quotes come from Apple's Dispatch documentation (`DispatchQueue`, `DispatchQueue.main`, `global(qos:)`, `DispatchQoS.QoSClass`, `setTarget(queue:)`, `DispatchWorkItem.cancel()`), read November 2026. Every block was compiled and run with Swift 6.3 on Linux, where Dispatch is the open-source libdispatch. Outputs were written so they don't depend on thread timing; the course's macOS CI runs the same blocks.

## What a queue is

Apple's definition: "Dispatch queues are FIFO queues to which your application can submit tasks in the form of block objects." A block is the C/Objective-C name for a closure. Two promises come with it:

- **Order of starting.** Items leave the queue in the order they were submitted (first in, first out).
- **Nothing about threads**, with one exception: "Except for the dispatch queue representing your app's main thread, the system makes no guarantees about which thread it uses to execute a task."

The second point is the whole design. A queue is not a thread. Dispatch keeps a pool of threads sized for the device, and queues borrow them. Two items on the same serial queue may run on different threads; that's fine, because the queue still guarantees they don't overlap.

## Serial queues

A **serial** queue runs one item at a time, and the next one starts only when the previous one has finished. Queues you create with just a label are serial:

```swift
import Dispatch

let queue = DispatchQueue(label: "com.example.uploads")

for number in 1...4 {
    queue.async {
        print("upload \(number)")
    }
}
queue.sync {
    print("everything submitted before this has finished")
}
print("main thread continues")
```

```output
upload 1
upload 2
upload 3
upload 4
everything submitted before this has finished
main thread continues
```

1. `DispatchQueue(label:)` creates a serial queue. The label is for you: it appears in the debugger, Instruments and crash reports, so use a reverse-DNS name that says what the queue is for.
2. `async` submits each closure and returns at once. The loop finishes before (or while) the first upload prints.
3. The four closures run in order, one at a time, because the queue is serial.
4. `sync` submits one more closure and **waits** for it. Since the queue is serial, it can't run until the four before it have finished. When `sync` returns, all of them are done.
5. Only then does the main thread print its last line. The main thread printed nothing while the uploads ran, so the whole output has one possible order.

Serial queues are the simplest tool in this module for protecting shared state: if every read and write of some data happens on one serial queue, no two of them overlap. Lesson 6 builds on that.

## Concurrent queues

A **concurrent** queue also starts items in submission order, but doesn't wait for one to finish before starting the next. Apple's description of the attribute: "The queue schedules tasks concurrently. If this attribute is not present, the queue schedules tasks serially in first-in, first-out (FIFO) order."

Because they overlap, items finish in whatever order the threads happen to finish. Printing from inside them would give a different output on different runs, so this program sends each result back to the main queue and sorts them at the end:

```swift
import Foundation

let workQueue = DispatchQueue(label: "com.example.resize", attributes: .concurrent)
var finishedPixelCounts: [Int] = []

for side in [640, 320, 1280, 160] {
    workQueue.async {
        let pixels = side * side   // stands in for resizing an image
        DispatchQueue.main.async {
            finishedPixelCounts.append(pixels)
        }
    }
}

while finishedPixelCounts.count < 4 {
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))
}
print(finishedPixelCounts.sorted())
```

```output
[25600, 102400, 409600, 1638400]
```

- `attributes: .concurrent` makes the queue concurrent.
- Each closure computes on a background thread, then hops to the main queue to record its result. The array is only touched on the main thread, so the four results can't trample each other.
- The arrival order changes from run to run; `sorted()` makes the output stable. In an app you'd usually key results by an id instead (a dictionary from image id to thumbnail), so arrival order doesn't matter.

You won't create concurrent queues often. Apple's `DispatchQueue` documentation advises against it: each private concurrent queue "consumes thread resources", and "instead of creating private concurrent queues, submit tasks to one of the global concurrent dispatch queues." The main reason to create your own is the reader-writer pattern with barriers in lesson 3.

## The main queue and the global queues

The system gives you two kinds of queues for free.

**`DispatchQueue.main`** is a serial queue whose items run on the main thread. It's the one queue with a thread guarantee, which is why UI work goes through it. Apple lists three ways a program drains it: calling `dispatchMain()`, starting the app with `UIApplicationMain` (or `NSApplicationMain` on macOS), or "using a `CFRunLoop` on the main thread". The `RunLoop.main.run(until:)` loops in this module's examples are the third.

**`DispatchQueue.global(qos:)`** returns one of the system's concurrent queues, one per **quality-of-service** class. The class tells the system how much the user cares about the work right now:

| QoS class | Apple's description, shortened | Typical use |
| --- | --- | --- |
| `.userInteractive` | "animations, event handling, or updating your app's user interface" | Work that must finish within a frame; rarely needed off the main thread |
| `.userInitiated` | "tasks that provide immediate results for something the user is doing" | Loading the email the user just tapped, applying a filter they chose |
| `.default` | Between user-initiated and utility | What you get with `global()` and no argument |
| `.utility` | "tasks that do not prevent the user from continuing to use your app" | A long import with a progress bar, prefetching |
| `.background` | "maintenance or cleanup tasks" | Cleaning caches, indexing, backups |

Apple's QoS documentation explains what the class buys you: the system gives higher priority to user-interactive work and "may attempt to save power by executing [background tasks] on more power-efficient CPU cores." Picking `.userInitiated` for everything defeats that; picking `.background` for something the user is staring at makes it slow.

```swift
import Dispatch

let emailQueue = DispatchQueue.global(qos: .userInitiated)
let cleanupQueue = DispatchQueue.global(qos: .background)

let bodyLength = emailQueue.sync { () -> Int in
    let body = "Hi Christian, the build is green."
    return body.count
}
print("body has \(bodyLength) characters")

cleanupQueue.sync {
    print("old cache entries removed")
}
```

```output
body has 33 characters
old cache entries removed
```

(Using `sync` here keeps the output ordered; the next section explains it. In an app, work like this goes through `async`.)

## async and sync

Every queue has both, and they differ in what the **caller** does:

- `queue.async { … }` submits the closure and returns immediately. The caller keeps running; the closure runs later, somewhere.
- `queue.sync { … }` submits the closure and **blocks the caller** until it has run. It can return a value.

`sync` is how you get a value out of a queue:

```swift
import Dispatch

let settingsQueue = DispatchQueue(label: "com.example.settings")

func loadVolume() -> Int {
    settingsQueue.sync {
        // Imagine reading this from storage that only settingsQueue touches.
        7
    }
}

print("volume is \(loadVolume())")
```

```output
volume is 7
```

`sync` is a blocking call, with everything lesson 1 said about blocking. Two consequences:

- **Never `sync` onto the main queue from the main thread.** Apple's `DispatchQueue` documentation: "Attempting to synchronously execute a work item on the main queue results in deadlock." More generally, `sync` onto the serial queue you're already running on waits for itself forever. Lesson 6 shows the trace.
- Use `sync` for short critical sections (read a value, update a dictionary), not for slow work. A `sync` around a network call just moves the blocking somewhere harder to see.

As an optimization, Apple notes that `sync` "executes blocks on the current thread whenever possible", except that blocks submitted to the main queue always run on the main thread. So `sync` doesn't necessarily involve another thread at all; it guarantees exclusion and order, not a thread.

> [!note] Why the async closure is @Sendable
> In Swift 6, `async`'s parameter is declared `@escaping @Sendable`. `@Sendable` means the compiler checks that whatever the closure captures is safe to use from another thread: `let` constants of value types like `Int` and `String` are fine; a `var` or a plain class instance isn't. `sync`'s closure isn't `@Sendable`, because it never outlives the call. Lesson 6 shows the diagnostics you get when a capture isn't safe. Swift 6.3 on Linux reports them as errors; Xcode (macOS, Swift 6.3.3) reports them as warnings for closures passed to `DispatchQueue.async` (most likely because Dispatch is imported as `@preconcurrency` on Apple platforms). Treat those warnings as errors. Module 29 explains `Sendable` in full.

## Custom queues and target queues

The full initializer:

```swift illustrative
DispatchQueue(
    label: String,
    qos: DispatchQoS = .unspecified,
    attributes: DispatchQueue.Attributes = [],          // [] serial, .concurrent
    autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
    target: DispatchQueue? = nil
)
```

Create your own queue when you need a **serial** context for one job: a queue that owns a cache, a queue that writes a log file, a queue for one database connection. Give it a QoS that matches the work.

The **target** is where the queue's items actually go. Apple's `setTarget(queue:)` documentation: a target queue "redirects all blocks from the current dispatch queue to the specified target queue", and "the system doesn't allocate threads to the dispatch queue if it has a target queue, unless that target queue is a global concurrent queue." It also says the queue keeps its own semantics ("blocks submitted to a serial queue still execute serially, even if the underlying target queue is concurrent") and "inherits the minimum quality-of-service level from its target queue."

That gives you two uses:

- **Fewer threads.** Apple's `DispatchQueue` page: "For serial tasks, set the target of your serial queue to one of the global concurrent queues." The queue stays serial and borrows the global queue's threads.
- **Mutual exclusion across queues.** If two serial queues target the same serial queue, their items never run at the same time; they're funneled through one line.

```swift
import Dispatch

let databaseQueue = DispatchQueue(
    label: "com.example.database",
    qos: .utility,
    target: .global(qos: .utility)
)

for table in ["users", "orders", "items"] {
    databaseQueue.async {
        print("vacuuming \(table)")
    }
}
databaseQueue.sync {}
print("database queue is serial: \(databaseQueue.label)")
```

```output
vacuuming users
vacuuming orders
vacuuming items
database queue is serial: com.example.database
```

The three items still run one at a time and in order, even though the target is concurrent. Don't create cycles (A targets B, B targets A); Apple calls that "a programmer error".

## DispatchWorkItem and cancellation

A closure passed to `async` is gone once submitted: you can't take it back. Wrap it in a `DispatchWorkItem` and you get an object you can keep:

- `cancel()`: Apple says it "causes future attempts to execute the work item to return immediately." If the item is still waiting in a queue, it will never run.
- `isCancelled`: whether `cancel()` was called.
- `wait()`: block until the item has run (with the usual warning about blocking).
- `notify(queue:execute:)`: run another closure on a queue when the item finishes.

This program queues three thumbnail jobs behind a suspended queue, cancels the middle one, then lets the queue go:

```swift
import Dispatch

func renderThumbnails() {
    let queue = DispatchQueue(label: "com.example.thumbnails")
    queue.suspend()   // hold the queue so nothing starts yet

    let first = DispatchWorkItem { print("thumbnail 1") }
    let second = DispatchWorkItem { print("thumbnail 2") }
    let third = DispatchWorkItem { print("thumbnail 3") }
    queue.async(execute: first)
    queue.async(execute: second)
    queue.async(execute: third)

    second.cancel()   // the user scrolled past it
    queue.resume()
    queue.sync {}     // wait for the queue to drain
    print("second cancelled: \(second.isCancelled)")
}

renderThumbnails()
```

```output
thumbnail 1
thumbnail 3
second cancelled: true
```

- `suspend()` stops the queue from starting new items (it doesn't interrupt one that's running). Every `suspend()` must be balanced by a `resume()`. Here it only exists so the cancellation is guaranteed to happen before anything runs; in an app, items are usually still waiting because the queue is busy.
- `queue.async(execute:)` takes the work item instead of a closure.
- The cancelled item is still in the queue, but when its turn comes it returns immediately, so `thumbnail 2` never prints.

The limit is in the same documentation: "Cancellation does not affect the execution of a work item that has already begun." `cancel()` doesn't stop a running closure, and the closure has no convenient way to check whether it was cancelled. A classic use where that's fine is **debouncing** a search field: every keystroke cancels the previous pending search and schedules a new one with `asyncAfter(deadline:execute:)` a few hundred milliseconds later, so only the last one runs. For long work that must stop halfway, `Operation` has a cancellation flag you can check (lesson 4), and Swift Concurrency's task cancellation is built for it (Module 29).

> [!tip] Create work items inside functions
> The examples create closures inside functions rather than at the top level of `main.swift`. Top-level code runs on the main actor, and in Swift 6 a closure created there that isn't `@Sendable` can be treated as main-actor code and checked at runtime when it runs on another thread. In an app this rarely comes up, since your code lives in types and functions, but it's a confusing crash to hit in a playground or a script.

## Common mistakes

> [!error] Printing from concurrent work and expecting a fixed order
> Items on a concurrent queue (or on different queues) finish in any order. Collect results and sort them, key them by id, or funnel them through one serial queue.

> [!error] Using sync to "make it safe" on the main thread
> `DispatchQueue.main.sync` from the main thread deadlocks, and `someQueue.sync { slowWork() }` from the main thread blocks it just as if you'd called `slowWork()` directly.

> [!error] Picking QoS by habit
> `.background` for work the user is waiting for makes it slow on purpose; `.userInteractive` for a cache cleanup competes with the UI. Ask "is the user waiting for this right now?"

> [!error] Expecting cancel() to stop a running work item
> It only prevents items that haven't started. A closure that's already running finishes.

> [!error] Creating a private concurrent queue for every feature
> Each one can grow its own threads. Use the global queues for concurrent work, and serial queues targeting them for exclusive work.

## Exercises

````exercise
id: m28-l02-e1
type: prediction
prompt: "What does this program print?"
code: |
  import Dispatch

  let queue = DispatchQueue(label: "com.example.log")

  queue.async { print("one") }
  let count = queue.sync { () -> Int in
      print("two")
      return 2
  }
  queue.async { print("three") }
  queue.sync { print("four") }
  print("count \(count)")
output: |
  one
  two
  three
  four
  count 2
hints:
  - "The queue is serial: one closure at a time, in submission order."
  - "Each sync waits until its closure has run, and it can't run before what was submitted earlier."
solution: |
  ```output
  one
  two
  three
  four
  count 2
  ```

  All four closures go to the same serial queue, so they run in submission order. Each `sync` blocks the main thread until its closure has run, and its closure can only run after everything before it, so the main thread never gets ahead of the queue. The first `sync` returns `2`, which the last line prints.
````

````exercise
id: m28-l02-e2
type: comprehension
prompt: "Which QoS class fits loading the body of an email the user just tapped in the inbox?"
choices:
  - text: ".userInitiated"
    correct: true
    why: "The user is waiting for the result of something they just did. Apple uses this exact example."
  - text: ".userInteractive"
    correct: false
    why: "That's for work like animations and event handling that must finish within a frame, typically on the main thread."
  - text: ".utility"
    correct: false
    why: "Utility is for long work the user isn't actively following. Here they're staring at an empty screen."
  - text: ".background"
    correct: false
    why: "Background is for maintenance. The system may run it slowly on efficiency cores, which is the opposite of what the user wants."
solution: |
  `.userInitiated`. Apple's description of it is "tasks that provide immediate results for something the user is doing", and its example is loading an email you want to display. `.userInteractive` is above that (frame-critical work), `.utility` and `.background` are for work the user isn't waiting on.
````

````exercise
id: m28-l02-e3
type: prediction
prompt: "Three work items are queued on a suspended serial queue. What does the program print?"
code: |
  import Dispatch

  func run() {
      let queue = DispatchQueue(label: "com.example.jobs")
      queue.suspend()
      let items = (1...3).map { number in
          DispatchWorkItem { print("job \(number)") }
      }
      for item in items {
          queue.async(execute: item)
      }
      items[0].cancel()
      items[2].cancel()
      queue.resume()
      queue.sync {}
      let cancelled = items.filter { $0.isCancelled }.count
      print("cancelled \(cancelled)")
  }

  run()
output: |
  job 2
  cancelled 2
hints:
  - "Nothing runs until resume(), so both cancellations happen before any job starts."
solution: |
  ```output
  job 2
  cancelled 2
  ```

  The queue is suspended while the items are submitted and two of them are cancelled, so no job has started yet. After `resume()`, the queue runs the three items in order, but cancelled ones return immediately: only `job 2` prints. `queue.sync {}` waits for the queue to drain, then two items report `isCancelled`.
````

````exercise
id: m28-l02-e4
type: solve
prompt: |
  Write `func checksums(of files: [String]) -> [String: Int]` that computes, for every file name, the sum of the Unicode scalar values of its name (`name.unicodeScalars.reduce(0) { $0 + Int($1.value) }`), with each computation submitted to `DispatchQueue.global(qos: .utility)` using `async`. Results must be recorded on a **serial** queue that you create, and the function must return only when every result is in.

  Without groups (that's lesson 3), you can wait like this: after submitting all the work, call `resultsQueue.sync` in a loop until the dictionary has as many entries as there are files. Keep the dictionary in a small `final class` whose storage is only touched on `resultsQueue`, and mark it `@unchecked Sendable` (lesson 6 explains exactly why that's allowed here).

  This code:

  ```swift
  let result = checksums(of: ["a.txt", "b.txt", "notes.md"])
  for name in result.keys.sorted() {
      print("\(name): \(result[name]!)")
  }
  ```

  should print:

  ```plaintext
  a.txt: 495
  b.txt: 496
  notes.md: 808
  ```
starter: |
  import Dispatch

  final class ChecksumStore: @unchecked Sendable {
      // Only read or written on the results queue you create.
      var values: [String: Int] = [:]
  }

  func checksums(of files: [String]) -> [String: Int] {
      // your code
      return [:]
  }

  let result = checksums(of: ["a.txt", "b.txt", "notes.md"])
  for name in result.keys.sorted() {
      print("\(name): \(result[name]!)")
  }
hints:
  - "Create let resultsQueue = DispatchQueue(label: \"com.example.checksums\") and let store = ChecksumStore() inside the function."
  - "Inside each global async closure: compute the sum, then resultsQueue.async { store.values[name] = sum }."
  - "To wait: var finished = false; while !finished { finished = resultsQueue.sync { store.values.count == files.count } }. The last read can be another sync that returns store.values."
rubric:
  - "Each checksum is computed inside DispatchQueue.global(qos: .utility).async."
  - Every read and write of the dictionary happens on the serial results queue.
  - The function returns only after all results are recorded.
  - The output matches, independent of which file finishes first.
solution: |
  ```swift
  import Dispatch

  final class ChecksumStore: @unchecked Sendable {
      // Only read or written on resultsQueue.
      var values: [String: Int] = [:]
  }

  func checksums(of files: [String]) -> [String: Int] {
      let resultsQueue = DispatchQueue(label: "com.example.checksums")
      let store = ChecksumStore()

      for name in files {
          DispatchQueue.global(qos: .utility).async {
              let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
              resultsQueue.async {
                  store.values[name] = sum
              }
          }
      }

      var finished = false
      while !finished {
          finished = resultsQueue.sync { store.values.count == files.count }
      }
      return resultsQueue.sync { store.values }
  }

  let result = checksums(of: ["a.txt", "b.txt", "notes.md"])
  for name in result.keys.sorted() {
      print("\(name): \(result[name]!)")
  }
  ```

  ```output
  a.txt: 495
  b.txt: 496
  notes.md: 808
  ```

  The three sums run on a global queue in any order. Each one sends its result to `resultsQueue`, a serial queue, so the dictionary is never touched by two threads at once; the loop's `sync` reads happen on the same queue. Printing sorted keys makes the output independent of finishing order.

  The waiting loop is a busy wait: it keeps asking until the answer is yes. It's correct but wasteful, and lesson 3 replaces it with `DispatchGroup`. `@unchecked Sendable` is a promise to the compiler that you synchronize access yourself; it holds here only because every access goes through `resultsQueue`.
````

````exercise
id: m28-l02-e5
type: find-errors
prompt: "This image cache was written by someone new to GCD. Mark every real problem."
code: |
  final class ThumbnailCache {
      private let queue = DispatchQueue(label: "cache", attributes: .concurrent)
      private var thumbnails: [String: Thumbnail] = [:]

      // Called from the main thread when a cell appears.
      func thumbnail(for id: String) -> Thumbnail? {
          DispatchQueue.main.sync {
              thumbnails[id]
          }
      }

      func prefetch(ids: [String]) {
          for id in ids {
              DispatchQueue.global(qos: .userInteractive).async {
                  let image = renderThumbnail(id)   // ~50 ms each
                  self.store(image, for: id)
              }
          }
      }

      func cancelPrefetch(_ item: DispatchWorkItem) {
          item.cancel()   // stops the render even if it already started
      }
  }
choices:
  - text: "thumbnail(for:) calls DispatchQueue.main.sync from the main thread, which deadlocks."
    correct: true
  - text: "Prefetching uses .userInteractive, which competes with UI work for something the user isn't waiting on."
    correct: true
  - text: "The comment on cancelPrefetch is wrong: cancel() doesn't stop a work item that has already begun."
    correct: true
  - text: "The queue's label must be a reverse-DNS string or the initializer fails."
    correct: false
  - text: "A global queue can't run closures that call methods on self."
    correct: false
rubric:
  - Finds the main.sync deadlock.
  - Finds the wrong QoS for prefetching.
  - Finds the incorrect claim about cancel().
solution: |
  1. **Deadlock.** `thumbnail(for:)` runs on the main thread and calls `DispatchQueue.main.sync`, which waits for the main queue to run the closure, which can't happen until the main thread stops waiting. Apple's docs say this "results in deadlock." The cache should protect `thumbnails` with its own queue (`queue.sync { thumbnails[id] }`), not the main one.
  2. **Wrong QoS.** Prefetching is speculative work the user didn't ask for yet. `.utility` fits; `.userInteractive` is the highest class and competes with UI work.
  3. **cancel() can't stop running work.** Apple: cancellation "does not affect the execution of a work item that has already begun." Renders already in progress will finish.

  A label is any string (reverse-DNS is a convention that makes debugging easier), and global-queue closures can call methods on `self`. Whether `self` may be captured is a Swift 6 question: this class isn't `Sendable`, so the `async` closure wouldn't compile. Lesson 6 shows how to fix that properly.
````

````exercise
id: m28-l02-e6
type: fill-in
prompt: "Create a serial queue for a log file that borrows the threads of the utility global queue, then write one line and wait for it."
code: |
  let logQueue = DispatchQueue(
      label: "com.example.logfile",
      qos: .[[1]],
      [[2]]: .global(qos: .utility)
  )
  logQueue.[[3]] {
      print("app launched")
  }
  logQueue.[[4]] {}
blanks:
  - id: "1"
    answers: ["utility"]
  - id: "2"
    answers: ["target"]
  - id: "3"
    answers: ["async"]
  - id: "4"
    answers: ["sync"]
hints:
  - "The queue's own QoS should match its target's."
  - "Submitting without waiting, then an empty closure that waits for everything before it."
solution: |
  ```swift
  import Dispatch

  let logQueue = DispatchQueue(
      label: "com.example.logfile",
      qos: .utility,
      target: .global(qos: .utility)
  )
  logQueue.async {
      print("app launched")
  }
  logQueue.sync {}
  ```

  ```output
  app launched
  ```

  `target:` makes the queue forward its items to the utility global queue, so it doesn't need threads of its own, and it stays serial. `async` submits the write without waiting; the empty `sync` returns only after everything submitted before it has run, which is a common way to flush a serial queue.
````

## Summary

- A dispatch queue is a FIFO line of closures. It guarantees order of starting; only the main queue guarantees a thread.
- **Serial** queues run one item at a time in order: queues you create are serial unless you pass `.concurrent`. **Concurrent** queues overlap items, so they finish in any order; collect results instead of printing from inside them.
- `DispatchQueue.main` runs on the main thread. `DispatchQueue.global(qos:)` gives you concurrent queues by **quality of service**: `.userInteractive`, `.userInitiated`, `.default`, `.utility`, `.background`. Pick by "is the user waiting for this?"
- `async` returns immediately; `sync` blocks the caller until the closure has run and can return its value. `sync` onto the queue you're on, including the main queue from the main thread, deadlocks.
- Create a custom serial queue for a job that needs exclusive access, with a label you'll recognize in crash reports. Give it a global queue as its **target** so it doesn't grow its own threads.
- A `DispatchWorkItem` can be cancelled before it starts; a cancelled item returns immediately when its turn comes. `cancel()` doesn't stop work that has already begun.
