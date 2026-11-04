---
id: m28-l04
title: Operations and operation queues
description: Foundation's object-oriented layer over GCD. You wrap work in BlockOperation or your own Operation subclass, order it with dependencies, cap how many run at once with maxConcurrentOperationCount, cancel it cooperatively by checking isCancelled, and learn when an operation queue is the better tool than a raw dispatch queue.
module: m28
order: 4
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l03]
objectives:
  - Create BlockOperation objects and run them on an OperationQueue.
  - Order operations with addDependency, including across queues.
  - Limit concurrency with maxConcurrentOperationCount.
  - Write an Operation subclass whose main() checks isCancelled, and predict what cancellation does to queued and dependent operations.
  - Choose between OperationQueue and GCD for a given job.
terms:
  - term: Operation
    definition: "An abstract Foundation class for one single-shot unit of work. It tracks its state (ready, executing, finished, cancelled) and its dependencies."
  - term: BlockOperation
    definition: "A concrete Operation that runs one or more closures. It's finished when all of them have returned."
  - term: OperationQueue
    definition: "A queue that runs Operation objects when they're ready, by priority, with an optional limit on how many run at once. It's built on GCD."
  - term: Dependency
    definition: "A rule that an operation isn't ready until another one has finished, set with addDependency. It works across queues."
  - term: Cooperative cancellation
    definition: "Cancelling only sets a flag; the running code has to check it (isCancelled) and stop itself. Nothing is interrupted by force."
mastery:
  - Build a download, parse and render pipeline whose order comes from dependencies, not from submission order.
  - Cap simultaneous image downloads at three without blocking any thread.
  - Write an Operation subclass that stops at the next item after being cancelled.
  - Predict that an operation still runs when its dependency was cancelled, and guard against it.
  - Argue for OperationQueue or GCD given a feature's needs.
resources: [foundation-operationqueue, foundation-operation, understanding-hangs]
cards:
  - id: m28-l04-c1
    front: How do you make operation B run only after A has finished?
    back: "b.addDependency(a). B isn't ready until A is finished, whatever order they were added in, even if they're on different queues."
  - id: m28-l04-c2
    front: What does cancel() do to an Operation?
    back: "It sets isCancelled. A queued operation that hasn't started finishes without running main(); a running one keeps going until its own code checks isCancelled and returns."
  - id: m28-l04-c3
    front: Does an operation run if its dependency was cancelled?
    back: "Yes. Apple: dependencies \"make no distinction\" between finishing successfully and being cancelled. Check the dependency's state yourself if it matters."
  - id: m28-l04-c4
    front: When does OperationQueue beat raw GCD?
    back: "When you need dependencies between jobs, a concurrency limit without blocking threads, cancellation state you can query, or to cancel a whole batch with cancelAllOperations()."
---

## The idea in one sentence

An operation queue is GCD with objects: each piece of work becomes an `Operation` that knows whether it's ready, running, finished or cancelled, which lets you declare **dependencies**, set a **concurrency limit** and **cancel** work in ways that are awkward with closures on a dispatch queue.

> [!note] Sources and what was run
> Descriptions and quotes come from Apple's documentation for `Operation`, `OperationQueue`, `BlockOperation` and `Operation.isCancelled`, read November 2026. The blocks were compiled and run with Swift 6.3 on Linux, where `OperationQueue` is part of the open-source Foundation. Outputs only print in an order guaranteed by dependencies, or totals read after the queue has finished.

## Operations and BlockOperation

`Operation` is an abstract class; Apple describes it as representing "the code and data associated with a single task". An operation is "a single-shot object": it runs once and can't be restarted.

You use it in two ways:

- **`BlockOperation`** wraps closures. It's the quickest way in.
- **A subclass of `Operation`** overrides `main()` with the work. Use it when the operation needs its own state, like the cancellation example below.

You hand operations to an `OperationQueue`, which runs them on threads it gets from GCD. Apple: "An operation queue executes its operations either directly, by running them on secondary threads, or indirectly using the `libdispatch` library (also known as Grand Central Dispatch)."

## Dependencies

A dependency says "don't start this until that has finished". Apple: "Interoperation dependencies provide an absolute execution order for operations, even if those operations are located in different operation queues."

```swift
import Foundation

func buildReport() {
    let queue = OperationQueue()
    queue.name = "com.example.report"

    let download = BlockOperation { print("1. download data") }
    let parse = BlockOperation { print("2. parse data") }
    let render = BlockOperation { print("3. render report") }

    parse.addDependency(download)
    render.addDependency(parse)

    queue.addOperations([render, parse, download], waitUntilFinished: true)
    print("render finished: \(render.isFinished)")
}

buildReport()
```

```output
1. download data
2. parse data
3. render report
render finished: true
```

1. Three `BlockOperation`s, each wrapping one closure.
2. `parse.addDependency(download)`: `parse` isn't ready until `download` is finished. Same for `render` and `parse`.
3. The operations are added in the **wrong** order on purpose. The queue is concurrent by default, so without dependencies `render` could run first. With them, there's exactly one possible order.
4. `waitUntilFinished: true` blocks the caller until all three have finished. Fine in a command-line tool or a test; on the main thread, pass `false`.

Dependencies are what GCD doesn't have. With dispatch queues you'd get the same order from a serial queue (but then nothing else can run in parallel on it) or by nesting callbacks. With operations, you can build a graph: two downloads in parallel, then one step that needs both:

```swift
import Foundation

final class Bag: @unchecked Sendable {
    private let lock = NSLock()   // lesson 6 explains locks
    private var items: [String] = []

    func add(_ item: String) {
        lock.lock()
        items.append(item)
        lock.unlock()
    }

    var sorted: [String] {
        lock.lock()
        defer { lock.unlock() }
        return items.sorted()
    }
}

func loadProfileScreen() {
    let queue = OperationQueue()
    let parts = Bag()

    let loadUser = BlockOperation { parts.add("user") }
    let loadAvatar = BlockOperation { parts.add("avatar") }
    let combine = BlockOperation {
        print("combining \(parts.sorted)")
    }
    combine.addDependency(loadUser)
    combine.addDependency(loadAvatar)

    queue.addOperations([loadUser, loadAvatar, combine], waitUntilFinished: true)
}

loadProfileScreen()
```

```output
combining ["avatar", "user"]
```

`loadUser` and `loadAvatar` may run at the same time, in either order, so they record what they did instead of printing. `combine` waits for both. The `Bag` class protects its array with a lock, a tool lesson 6 covers; for now, read `lock()`/`unlock()` as "one thread at a time in here".

> [!warning] A dependency doesn't check success
> Apple: dependencies "make no distinction about whether a dependent operation finished successfully or unsuccessfully. (In other words, canceling an operation similarly marks it as finished.)" If `download` fails or is cancelled, `parse` still runs. Check the dependency's result or `isCancelled` at the top of the dependent operation if it matters.

## Limiting concurrency

`maxConcurrentOperationCount` caps how many operations of a queue run at the same time:

```swift
import Foundation

let imageQueue = OperationQueue()
imageQueue.maxConcurrentOperationCount = 3
print("limit: \(imageQueue.maxConcurrentOperationCount)")
```

```output
limit: 3
```

This is the operation-queue answer to lesson 3's semaphore, and it's better in one important way: operations above the limit **aren't started**. They wait in the queue as objects, not as blocked threads, so 500 queued downloads cost 500 small objects, not 500 threads.

```swift
import Foundation

final class Activity: @unchecked Sendable {
    private let lock = NSLock()
    private var running = 0
    private var peak = 0
    private var finished = 0

    func start() {
        lock.lock()
        running += 1
        peak = max(peak, running)
        lock.unlock()
    }

    func finish() {
        lock.lock()
        running -= 1
        finished += 1
        lock.unlock()
    }

    var report: (finished: Int, peak: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (finished, peak)
    }
}

func downloadImages() {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 3
    let activity = Activity()

    for _ in 1...20 {
        queue.addOperation {
            activity.start()
            Thread.sleep(forTimeInterval: 0.005)   // stands in for a download
            activity.finish()
        }
    }

    queue.waitUntilAllOperationsAreFinished()
    let report = activity.report
    print("downloaded: \(report.finished)")
    print("at most 3 at once: \(report.peak <= 3)")
}

downloadImages()
```

```output
downloaded: 20
at most 3 at once: true
```

`addOperation { … }` is shorthand for wrapping a closure in a `BlockOperation` and adding it. The program prints whether the cap held, not the exact peak, which depends on timing.

Setting the limit to 1 makes the queue run one operation at a time. That isn't quite a serial dispatch queue: Apple's `OperationQueue` documentation says operations of equal priority that are ready run in the order you added them, but warns "don't rely on queue semantics to ensure a specific execution order of operations because changes in the readiness of an operation can change the resulting execution order." If order matters, use dependencies.

`OperationQueue.main` is the operation queue for the main thread, the counterpart of `DispatchQueue.main`. It runs one operation at a time, on the main thread.

## Cancellation

Apple's documentation for `isCancelled` sets the rules:

- "Canceling an operation does not actively stop the receiver's code from executing. An operation object is responsible for calling this method periodically and stopping itself if the method returns `true`."
- "It is possible for an operation to be cancelled before it begins executing or at any time while it is executing." So check at the start of `main()` and periodically during it.

For an operation that hasn't started, the queue does the work: it still calls `start()`, which sees the flag and marks the operation finished without calling `main()`. For a running one, cancellation is **cooperative**: your loop has to look.

Here's an import that saves rows one at a time and checks the flag before each one. To make the run repeatable, the "user" cancels from the progress callback after the third row; in an app, `cancel()` would come from a Cancel button on the main thread at an unpredictable moment, and the loop would notice at its next check:

```swift
import Foundation

final class ImportOperation: Operation, @unchecked Sendable {
    private let rows: [String]
    private let onProgress: @Sendable (ImportOperation, Int) -> Void
    // Written only by main(); read by others only after the operation has finished.
    private(set) var importedCount = 0

    init(rows: [String], onProgress: @escaping @Sendable (ImportOperation, Int) -> Void) {
        self.rows = rows
        self.onProgress = onProgress
    }

    override func main() {
        for _ in rows {
            guard !isCancelled else { return }
            importedCount += 1   // pretend to save the row
            onProgress(self, importedCount)
        }
    }
}

func runImport() {
    let rows = (1...10).map { "row \($0)" }
    let operation = ImportOperation(rows: rows) { operation, count in
        if count == 3 {
            operation.cancel()   // the user taps Cancel
        }
    }

    let queue = OperationQueue()
    queue.addOperation(operation)
    queue.waitUntilAllOperationsAreFinished()

    print("imported \(operation.importedCount) of \(rows.count)")
    print("cancelled: \(operation.isCancelled), finished: \(operation.isFinished)")
}

runImport()
```

```output
imported 3 of 10
cancelled: true, finished: true
```

- `final class ImportOperation: Operation, @unchecked Sendable`: subclasses override `main()` for synchronous work. `@unchecked Sendable` is needed because the class has a mutable stored property and is used from several threads; the comment says what makes it safe.
- `guard !isCancelled else { return }` runs before each row. Returning from `main()` is enough: the operation then counts as finished.
- After `cancel()`, the loop stops at its next check, so exactly three rows were imported. The operation is both cancelled and finished.

Cancelling a whole batch is one call, `queue.cancelAllOperations()`, which is common when a screen goes away. Operations that haven't started finish immediately; running ones get the flag and stop at their next check.

> [!note] Asynchronous operations
> `main()` must do its work synchronously: when it returns, the operation is finished. Wrapping callback-based work (a network request) in an operation means writing an "asynchronous" subclass that overrides `start()`, `isAsynchronous`, `isExecuting` and `isFinished` and sends the matching key-value observing notifications by hand. It's well documented in `Operation`'s reference and easy to get subtly wrong. It's one of the reasons new code moves to Swift Concurrency, where awaiting a request inside a task needs none of it.

## OperationQueue or GCD?

| You need… | Reach for |
| --- | --- |
| Run a closure in the background, then hop to the main thread | GCD: `global().async` + `main.async` |
| Protect a piece of state | A serial dispatch queue or a lock (lesson 6) |
| A CPU-bound parallel loop | `DispatchQueue.concurrentPerform` |
| Steps that depend on other steps, maybe across queues | `OperationQueue` with `addDependency` |
| At most N jobs at once, with hundreds queued | `OperationQueue.maxConcurrentOperationCount` |
| Cancel a batch, or check whether a job was cancelled | `Operation` with `isCancelled`, `cancelAllOperations()` |

GCD is lighter and shorter for one-off work. Operations cost an object per job and more code, and pay that back when jobs have relationships or a lifecycle you need to manage.

## Common mistakes

> [!error] Expecting cancel() to stop a running operation
> It only sets `isCancelled`. If `main()` never checks it, the operation runs to the end.

> [!error] Assuming a dependent operation won't run after a failure
> A cancelled or failed dependency still counts as finished. Check its state at the top of `main()` or in the block.

> [!error] Relying on maxConcurrentOperationCount = 1 for order
> Apple says not to rely on queue order. If B must follow A, add a dependency.

> [!error] waitUntilFinished: true on the main thread
> It's a blocking wait, like `group.wait()`. Pass `false` and use a final dependent operation (or `addBarrierBlock`) to react when the work is done.

> [!error] Reusing an operation
> Operations are single-shot. Apple's `addOperation(_:)` documentation: it throws an `invalidArgumentException` "if the operation is currently executing or has already finished executing", or if it's already in another queue. That's an Objective-C exception, which stops a Swift program. Create a new operation instead.

## Exercises

````exercise
id: m28-l04-e1
type: prediction
prompt: "Four operations with dependencies are added in reverse order. What does the program print?"
code: |
  import Foundation

  func run() {
      let queue = OperationQueue()
      let a = BlockOperation { print("a") }
      let b = BlockOperation { print("b") }
      let c = BlockOperation { print("c") }
      let d = BlockOperation { print("d") }

      d.addDependency(c)
      c.addDependency(a)
      b.addDependency(d)

      queue.addOperations([d, c, b, a], waitUntilFinished: true)
      print("done")
  }

  run()
output: |
  a
  c
  d
  b
  done
hints:
  - "Follow the arrows: which operation has no dependency at all?"
solution: |
  ```output
  a
  c
  d
  b
  done
  ```

  `a` has no dependencies, so it's the only one ready at the start. `c` waits for `a`, `d` waits for `c`, and `b` waits for `d`, so the dependencies form one chain: a, c, d, b. The order they were added in doesn't matter. `waitUntilFinished: true` returns after all four, then `done` prints.
````

````exercise
id: m28-l04-e2
type: prediction
prompt: "An upload depends on a compression step that's cancelled before the queue starts. What does the program print?"
code: |
  import Foundation

  func run() {
      let queue = OperationQueue()
      queue.isSuspended = true

      let compress = BlockOperation { print("compressing") }
      let upload = BlockOperation { print("uploading") }
      upload.addDependency(compress)

      queue.addOperations([compress, upload], waitUntilFinished: false)
      compress.cancel()
      queue.isSuspended = false
      queue.waitUntilAllOperationsAreFinished()

      print("compress cancelled: \(compress.isCancelled)")
  }

  run()
output: |
  uploading
  compress cancelled: true
hints:
  - "A cancelled operation that hasn't started finishes without running its work."
  - "What does a dependency check: success, or only that the other operation is finished?"
solution: |
  ```output
  uploading
  compress cancelled: true
  ```

  The queue is suspended while `compress` is cancelled, so it never runs its closure; the queue still starts it, it sees the flag and moves to finished. For `upload`, a cancelled dependency is a finished dependency (Apple: dependencies "make no distinction" between success and cancellation), so it runs. In a real app that would upload an uncompressed or missing file: `upload` should check `compress.isCancelled` (or a result the compression stored) before doing anything.
````

````exercise
id: m28-l04-e3
type: solve
prompt: |
  Write `final class ChecksumOperation: Operation, @unchecked Sendable` that adds up the numbers in an array, one at a time, and stops early if it's cancelled. It takes `numbers: [Int]` and an `onStep: @Sendable (ChecksumOperation, Int) -> Void` callback that it calls after each number with the count processed so far, and exposes `private(set) var sum = 0` and `private(set) var processed = 0`.

  Then run it on an `OperationQueue` with the numbers 1 through 100, cancel it from `onStep` when 10 numbers have been processed, wait for the queue, and print exactly:

  ```plaintext
  processed 10, sum 55
  cancelled: true
  ```
starter: |
  import Foundation

  final class ChecksumOperation: Operation, @unchecked Sendable {
      // your code
  }

  func run() {
      // create the operation, add it to a queue, wait, print
  }

  run()
hints:
  - "Check isCancelled at the top of each loop iteration, before touching sum."
  - "In onStep: if count == 10 { operation.cancel() }."
  - "queue.waitUntilAllOperationsAreFinished() before reading sum and processed."
rubric:
  - Subclasses Operation and overrides main().
  - Checks isCancelled before each step and returns when it's set.
  - Reads the results only after the queue has finished.
  - The output matches.
solution: |
  ```swift
  import Foundation

  final class ChecksumOperation: Operation, @unchecked Sendable {
      private let numbers: [Int]
      private let onStep: @Sendable (ChecksumOperation, Int) -> Void
      // Written only by main(); read only after the operation has finished.
      private(set) var sum = 0
      private(set) var processed = 0

      init(numbers: [Int], onStep: @escaping @Sendable (ChecksumOperation, Int) -> Void) {
          self.numbers = numbers
          self.onStep = onStep
      }

      override func main() {
          for number in numbers {
              guard !isCancelled else { return }
              sum += number
              processed += 1
              onStep(self, processed)
          }
      }
  }

  func run() {
      let operation = ChecksumOperation(numbers: Array(1...100)) { operation, count in
          if count == 10 {
              operation.cancel()
          }
      }
      let queue = OperationQueue()
      queue.addOperation(operation)
      queue.waitUntilAllOperationsAreFinished()

      print("processed \(operation.processed), sum \(operation.sum)")
      print("cancelled: \(operation.isCancelled)")
  }

  run()
  ```

  ```output
  processed 10, sum 55
  cancelled: true
  ```

  The guard at the top of each iteration is where cancellation takes effect. After the tenth number, `onStep` cancels, the next iteration sees `isCancelled` and returns, so `sum` is `1 + … + 10 = 55`. Reading `sum` and `processed` after `waitUntilAllOperationsAreFinished()` is safe: the operation has finished writing them. That's also why `@unchecked Sendable` is honest here, as long as nobody reads them while it runs.
````

````exercise
id: m28-l04-e4
type: comprehension
multiple: true
prompt: "A photo app needs this feature: download up to 4 full-size photos at a time out of an album of 300, then for each photo make a thumbnail only after its download finishes, and cancel everything when the user leaves the album. Which statements are true? Select all that apply."
choices:
  - text: "An OperationQueue with maxConcurrentOperationCount = 4 can hold all 300 downloads without blocking 296 threads."
    correct: true
    why: "Operations above the limit aren't started; they wait as objects."
  - text: "Each thumbnail operation can depend on its photo's download operation with addDependency."
    correct: true
    why: "Dependencies express exactly \"after this download\", even if thumbnails run on another queue."
  - text: "cancelAllOperations() on leaving the album stops downloads that are in progress immediately."
    correct: false
    why: "It sets isCancelled on all of them. Pending ones finish without running; running ones stop only when their code checks the flag."
  - text: "A thumbnail operation whose download was cancelled won't run, because its dependency didn't succeed."
    correct: false
    why: "Cancelled counts as finished. The thumbnail operation runs unless it checks the download's state itself (or is cancelled too)."
solution: |
  The first two are true: the concurrency limit holds the extra downloads without blocking threads, and dependencies tie each thumbnail to its download. The last two are the classic surprises. `cancelAllOperations()` is cooperative, so in-progress downloads need to check `isCancelled` (or cancel their network task). And a dependent operation still runs when its dependency was cancelled; here `cancelAllOperations()` on the thumbnail queue too, plus a check of the download's state at the start of the thumbnail operation, covers it.
````

````exercise
id: m28-l04-e5
type: design
prompt: "You're adding an \"Export all\" feature: for each of up to 2,000 notes, render a PDF (CPU-heavy, about 40 ms each), then when all PDFs are done, zip them into one file and show a share sheet. The user can cancel from a progress screen. Design the concurrency: which tool runs each step, how the zip waits for the PDFs, how the concurrency is limited, how cancellation works, and where the UI is updated."
rubric:
  - Runs PDF rendering off the main thread with a sensible concurrency limit (about the number of cores), not 2,000 threads.
  - Makes the zip step wait for all PDFs (dependencies, a group, or a barrier block), not by polling.
  - Makes cancellation reach both pending and running work, with running work checking a flag.
  - Updates progress and shows the share sheet on the main thread.
  - Handles the zip step after a cancellation (doesn't zip a partial export).
solution: |
  One reasonable design:

  - **Rendering:** an `OperationQueue` with `maxConcurrentOperationCount` set to around `ProcessInfo.processInfo.activeProcessorCount`, since the work is CPU-bound and more threads than cores won't help. One `Operation` subclass per note; `main()` checks `isCancelled` before rendering (and between pages for long notes).
  - **Zip:** one more operation that depends on all 2,000 render operations (`addDependency` in a loop). It starts only when they're all finished. Its first line checks whether the export was cancelled, because cancelled render operations count as finished.
  - **Cancel:** the progress screen's Cancel button calls `cancelAllOperations()` on the queue. Pending renders finish without running, running ones stop at their next check, and the zip operation sees the cancellation and skips zipping.
  - **UI:** each render operation reports progress with `OperationQueue.main.addOperation { … }` (or `DispatchQueue.main.async`), and the zip operation presents the share sheet the same way.

  A `DispatchGroup` with `notify` and a semaphore would also work, but the semaphore would block a thread for every waiting note, and cancellation would need a flag you build yourself. The operation queue gives you the limit, the dependency and the cancellation state for free.
````

````exercise
id: m28-l04-e6
type: fill-in
prompt: "Complete the custom operation so it stops at the next file after being cancelled."
code: |
  final class CleanupOperation: [[1]], @unchecked Sendable {
      let files: [String]

      init(files: [String]) {
          self.files = files
      }

      override func [[2]]() {
          for file in files {
              guard ![[3]] else { return }
              delete(file)
          }
      }
  }

  let queue = OperationQueue()
  queue.[[4]] = 2
  queue.addOperation(CleanupOperation(files: oldFiles))
blanks:
  - id: "1"
    answers: ["Operation"]
  - id: "2"
    answers: ["main"]
  - id: "3"
    answers: ["isCancelled", "self.isCancelled"]
  - id: "4"
    answers: ["maxConcurrentOperationCount"]
hints:
  - "The abstract superclass, the method the queue calls for synchronous work, the flag cancel() sets, and the property that limits a queue."
solution: |
  ```swift illustrative
  final class CleanupOperation: Operation, @unchecked Sendable {
      let files: [String]

      init(files: [String]) {
          self.files = files
      }

      override func main() {
          for file in files {
              guard !isCancelled else { return }
              delete(file)
          }
      }
  }

  let queue = OperationQueue()
  queue.maxConcurrentOperationCount = 2
  queue.addOperation(CleanupOperation(files: oldFiles))
  ```

  Subclass `Operation`, put synchronous work in `main()`, check `isCancelled` before each unit of work, and limit the queue with `maxConcurrentOperationCount`. (`delete` and `oldFiles` stand for your own code, so this block isn't run.)
````

## Summary

- An `Operation` is a single-shot unit of work with state: ready, executing, finished, cancelled. `BlockOperation` wraps closures; subclasses override `main()`.
- `addDependency` gives an absolute order, even across queues, and lets you build graphs (two downloads, then a combine) that GCD can't express directly. A cancelled dependency still counts as finished.
- `maxConcurrentOperationCount` limits how many operations run at once without blocking threads for the rest. Don't rely on queue order for sequencing; use dependencies.
- Cancellation is cooperative: `cancel()` sets `isCancelled`, pending operations finish without running, and running ones stop only where their code checks the flag. `cancelAllOperations()` cancels a batch.
- Use GCD for quick one-off hops and protecting state; use operation queues when jobs depend on each other, need a concurrency limit, or need a lifecycle you can cancel and inspect.
