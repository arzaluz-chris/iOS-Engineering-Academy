---
id: m29-l03
title: Cancellation
description: "Stop work nobody needs anymore. You learn that cancelling a task only sets a flag, make your own code check it with Task.isCancelled and Task.checkCancellation(), react by throwing CancellationError or returning partial results, avoid the try? that silently swallows cancellation, hook non-async work into it with withTaskCancellationHandler, see how cancellation flows to child tasks and not to unstructured ones, and cancel a screen's work when it disappears or deinitializes."
module: m29
order: 3
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l02]
objectives:
  - Explain what cancel() does and doesn't do to a running task.
  - Check for cancellation with Task.isCancelled and Task.checkCancellation(), and choose between throwing and returning partial results.
  - Recognize code that swallows cancellation, such as try? await Task.sleep in a loop.
  - Use withTaskCancellationHandler to cancel work that doesn't check the flag itself.
  - Predict which tasks a cancellation reaches, child or unstructured.
  - Cancel a screen's tasks when it disappears or is deallocated, without a retain cycle keeping it alive.
terms:
  - term: Cooperative cancellation
    definition: "Cancelling a task only marks it as cancelled. The code running in the task has to notice (check the flag, or call something that does) and stop on its own."
  - term: CancellationError
    definition: "The error conventionally thrown when a task stops because it was cancelled. Task.checkCancellation() and Task.sleep throw it."
  - term: Cancellation handler
    definition: "A closure registered with withTaskCancellationHandler that runs once, immediately, when the task is cancelled, even if the operation never checks the flag. It may run concurrently with the operation."
  - term: Cancellation propagation
    definition: "Cancelling a task also cancels all of its child tasks (async let and task groups), including ones created later. Unstructured tasks it created aren't affected."
mastery:
  - Add a cancellation check to a long loop and return the work done so far when it fires.
  - Find the try? that makes a polling loop ignore cancellation and fix it.
  - Predict the output when a cancelled parent has async let children and an inner Task { }.
  - Wrap a legacy cancellable operation so cancelling the task cancels the operation.
  - Store a screen's task in a property, cancel it in viewDidDisappear and deinit, and explain why a strong self capture defeats the deinit.
resources: [swift-book, swift-evolution, swift-checkedcontinuation]
cards:
  - id: m29-l03-c1
    front: What does task.cancel() do?
    back: "It flags the task as cancelled, runs its active cancellation handlers once, and cancels its child tasks. It doesn't stop any code: the task has to check and stop itself (cooperative cancellation)."
  - id: m29-l03-c2
    front: Task.isCancelled vs Task.checkCancellation()?
    back: "isCancelled returns a Bool, so you decide what to do (return partial results, clean up). checkCancellation() throws CancellationError if cancelled, the usual choice in throwing code."
  - id: m29-l03-c3
    front: Why is try? await Task.sleep(...) in a loop a cancellation bug?
    back: "Task.sleep reports cancellation by throwing CancellationError. try? throws that away, so the loop keeps going. Use try and let it propagate, or check Task.isCancelled after."
  - id: m29-l03-c4
    front: Does cancelling a task cancel a Task { } created inside it?
    back: "No. Cancellation propagates to child tasks (async let, task groups) only. An unstructured task has its own lifetime; keep its handle and cancel it yourself."
  - id: m29-l03-c5
    front: When does withTaskCancellationHandler's onCancel run?
    back: "Immediately when the task is cancelled, possibly concurrently with the operation. If the task is already cancelled, it runs right away, before the operation starts."
---

## The idea in one sentence

Cancelling a task is a polite request: Swift marks the task and its children as cancelled, and it's up to the code inside to notice and stop.

> [!note] What you already know
> Module 28, lesson 2: `DispatchWorkItem.cancel()` "does not affect the execution of a work item that has already begun". Lesson 4 there: `Operation` has `isCancelled`, and a long operation has to check it. Swift Concurrency keeps the same cooperative model but builds it into every task and propagates it through the task tree. The blocks were run with Swift 6.3 on Linux. To keep output fixed, most cancel a task before it gets to run (a task created from top-level code can't start until the top-level code reaches an `await`, lesson 1); the one that cancels mid-work prints only whether it stopped early.

## What cancel() does

Apple's documentation for `Task.cancel()` lists three effects:

- "It flags the task as canceled."
- "It causes any active cancellation handlers on the task to run, once."
- "It cancels any child tasks and task groups of the task, including those created in the future."

And then the part that matters: "a function that doesn't specifically check for cancellation will run to completion normally, even if the task it is running on is canceled." There's no way to kill a task from outside. Stopping is the task's own decision, made at points where its state is consistent, which is exactly why Swift doesn't force it: a task stopped halfway through updating two related values would leave them out of sync.

Cancellation is also a plain Boolean, with no reason attached. "Cancellation is a purely Boolean state; there's no way to include additional information like the reason for cancellation." Cancelling twice is the same as once.

## Checking for cancellation

You have two tools, both static, because they ask about the task the code is running in:

- `Task.isCancelled` returns a `Bool`.
- `try Task.checkCancellation()` throws `CancellationError` if the task is cancelled, and does nothing otherwise.

```swift
enum ImportError: Error {
    case badRow(Int)
}

func importRows(_ rows: [String]) async throws -> Int {
    var imported = 0
    for (index, row) in rows.enumerated() {
        try Task.checkCancellation()
        guard !row.isEmpty else { throw ImportError.badRow(index) }
        imported += 1
    }
    return imported
}

let task = Task {
    try await importRows(["a", "b", "c"])
}
task.cancel()

do {
    let count = try await task.value
    print("imported \(count)")
} catch is CancellationError {
    print("import cancelled")
} catch {
    print("import failed: \(error)")
}
```

```output
import cancelled
```

1. The task is created and cancelled before it gets a chance to run (the main actor is still busy with top-level code).
2. When it does run, the first `checkCancellation()` throws, so not a single row is imported.
3. `task.value` rethrows the task's error. `catch is CancellationError` separates "the user cancelled" from a real failure, which you usually don't want to show as an error alert.

`Task.sleep` checks too: a cancelled sleep throws `CancellationError` right away. So do many async APIs from Apple's frameworks, though not all of them use `CancellationError`. A cancelled `URLSession` request typically fails with a `URLError` whose code is `.cancelled` ("An asynchronous load has been canceled", in Apple's reference); this lesson doesn't run `URLSession`, so check what the API you call documents and handle both.

### Returning partial results

Throwing is the convention, but not the only reaction. Apple: "Other responses to cancellation include returning the work completed so far, returning an empty result, or returning nil." A long computation that never suspends must check the flag itself, or cancelling it does nothing:

```swift
@concurrent
func countPrimes(upTo limit: Int) async -> (checked: Int, primes: Int) {
    var primes = 0
    for n in 2...limit {
        if n % 1_000 == 0 && Task.isCancelled {
            return (n - 1, primes)
        }
        var isPrime = true
        var divisor = 2
        while divisor * divisor <= n {
            if n % divisor == 0 {
                isPrime = false
                break
            }
            divisor += 1
        }
        if isPrime {
            primes += 1
        }
    }
    return (limit, primes)
}

let quick = await countPrimes(upTo: 100)
print("primes up to 100: \(quick.primes)")

let task = Task {
    await countPrimes(upTo: 20_000_000)
}
try await Task.sleep(for: .milliseconds(100))
task.cancel()
let partial = await task.value
print("stopped early: \(partial.checked < 20_000_000)")
```

```output
primes up to 100: 25
stopped early: true
```

- `@concurrent` makes the function run on the cooperative pool rather than on the caller's actor, whatever the project's settings (lesson 6 explains why you'd otherwise have to care). Without it, under Xcode's "Approachable Concurrency" setting, this loop would run on the main actor and the top-level code couldn't even get to `task.cancel()` until it finished.
- Checking every 1,000 numbers keeps the check cheap. On the Linux machine that ran it, the task had checked about 640,000 numbers when it noticed; the full run would take many seconds. The program prints only the Boolean because the exact count depends on machine speed.

### The try? that swallows cancellation

This is the most common cancellation bug in real code:

```swift
func pollForUpdates(times: Int) async -> Int {
    var polls = 0
    for _ in 1...times {
        try? await Task.sleep(for: .milliseconds(10))   // throws CancellationError... into try?
        polls += 1
    }
    return polls
}

let poller = Task {
    await pollForUpdates(times: 5)
}
poller.cancel()
print("polled \(await poller.value) times after being cancelled")
```

```output
polled 5 times after being cancelled
```

`Task.sleep` noticed the cancellation and threw, five times; `try?` turned each error into `nil` and the loop went on. A polling loop written like this, in a view model, keeps polling after the screen is gone. Two fixes: make the function `throws` and use `try await Task.sleep`, or keep `try?` and add `if Task.isCancelled { break }` right after it.

## withTaskCancellationHandler

Checking a flag works for loops you write. It doesn't work when the task is suspended inside something that doesn't know about Swift tasks: a legacy download object with its own `cancel()`, a callback-based API wrapped in a continuation (lesson 6). For that, register a handler that runs the moment the task is cancelled:

```swift
let task = Task {
    await withTaskCancellationHandler {
        print("operation runs")
        return "done"
    } onCancel: {
        print("onCancel runs")
    }
}
task.cancel()
print(await task.value)
```

```output
onCancel runs
operation runs
done
```

The order here is guaranteed by the documentation: "When withTaskCancellationHandler(operation:onCancel:) is used in a task that has already been canceled, the cancellation handler will be executed immediately before the operation closure gets to execute." And the operation always runs anyway, so it has to check the flag itself if it wants to skip work.

If the task is cancelled while the operation is running, the handler "executes concurrently with the operation". That's why `onCancel` is `@Sendable`: it can't touch the operation's non-Sendable local state. In practice it calls one thread-safe method:

```swift
import Foundation

/// A pre-concurrency download object: thread-safe, with its own cancel().
final class LegacyDownload: @unchecked Sendable {
    // `cancelled` is only accessed while holding `lock`.
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

func runDownload() async -> String {
    let download = LegacyDownload()
    return await withTaskCancellationHandler {
        // Imagine the download starting here and reporting back later.
        download.isCancelled ? "download cancelled" : "download finished"
    } onCancel: {
        download.cancel()
    }
}

let finished = Task { await runDownload() }
print(await finished.value)

let cancelled = Task { await runDownload() }
cancelled.cancel()
print(await cancelled.value)
```

```output
download finished
download cancelled
```

The download object is `Sendable` (it guards its state with a lock, Module 28, lesson 6), so the `@Sendable` handler may capture it. Lesson 6 combines this with a continuation to make a real callback API cancellable.

> [!warning] Don't hold a lock while cancelling
> Apple warns that the handler "may be invoked while holding internal locks associated with the task", so a handler that takes a lock can deadlock with code that cancels tasks or resumes continuations while holding that same lock. Keep handlers tiny, and release your own locks before calling `cancel()`.

## How cancellation spreads

Cancelling a task cancels its **children**: every `async let`, every task in its groups, and their children in turn. It doesn't touch **unstructured** tasks it created with `Task { }`, which have their own lifetime:

```swift
func child(_ name: String) async -> String {
    do {
        try await Task.sleep(for: .seconds(60))
        return "\(name) finished"
    } catch {
        return "\(name) cancelled"
    }
}

let parent = Task {
    async let first = child("first")
    async let second = child("second")
    let unstructured = Task { Task.isCancelled }
    return (await [first, second], await unstructured.value)
}
parent.cancel()

let (children, innerTaskCancelled) = await parent.value
print(children)
print("inner Task { } cancelled: \(innerTaskCancelled)")
```

```output
["first cancelled", "second cancelled"]
inner Task { } cancelled: false
```

The two children were cancelled with their parent (and returned within milliseconds, not a minute). The inner `Task { }` wasn't, even though it was created by a cancelled task. Apple's `Task.detached` documentation spells out what you lose without structure: "canceling a parent task automatically cancels all of its child tasks. You need to handle these considerations manually with a detached task." The same is true of `Task { }`.

Inside a task group, `group.cancelAll()` cancels the remaining children without cancelling the parent, and `group.addTaskUnlessCancelled { … }` skips adding a child to a group that's already cancelled (plain `addTask` adds it already cancelled).

> [!version] Swift 6.4: cleanup that ignores cancellation
> Cleanup code that must run even in a cancelled task (closing a file, sending a final "logged out" request) used to fight with `Task.sleep` and `checkCancellation()` throwing. Swift 6.4 adds `withTaskCancellationShield { … }` ([SE-0504](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md)): inside it, `Task.isCancelled` reads `false` and new child tasks aren't cancelled automatically. It pairs with `await` in `defer` blocks, also new in 6.4 ([SE-0493](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0493-defer-async.md)). Apple lists the shield as iOS 27 and later; this lesson doesn't run it.

## Cancelling when a screen goes away

A `Task { }` started by a view controller doesn't know about the view controller. If the person taps Back, the task keeps loading and then updates a screen nobody sees, and a polling loop runs forever. Keep the handle and cancel it yourself:

```swift ios
import UIKit

final class OrderStatusViewController: UIViewController {
    private let statusLabel = UILabel()
    private var pollingTask: Task<Void, Never>?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let status = await OrderStatusViewController.fetchStatus()
                self?.statusLabel.text = status
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pollingTask?.cancel()
        pollingTask = nil
    }

    deinit {
        pollingTask?.cancel()
    }

    private static func fetchStatus() async -> String {
        try? await Task.sleep(for: .milliseconds(200))
        return "Out for delivery"
    }
}
```

The pieces:

- `pollingTask` holds the handle. Starting a new task cancels the old one first, so `viewDidAppear` running twice doesn't leave two pollers.
- `viewDidDisappear` is the main exit. `deinit` is the backstop if the controller goes away without disappearing (it compiles in Swift 6.3 because a `Task` is `Sendable` and `deinit` has the object to itself).
- `while !Task.isCancelled` checks the flag each round. Here `try?` on the sleep is fine, because the loop condition checks the flag right after it.
- **`[weak self]` is what makes `deinit` reachable.** A `Task` keeps its closure, and everything the closure captures, alive until the task finishes. Apple's `Task` documentation notes that this is usually harmless ("tasks rarely need to capture weak references") because a finished task releases its closure. A loop that never finishes is the exception: with a strong `self`, the controller can't be deallocated, so `deinit` never runs to cancel the task that's keeping it alive. Capturing `[weak self]` and only touching `self?` between awaits breaks that cycle.

The same shape works in table and collection view cells: Module 24, lesson 3 cancelled a cell's image task in `prepareForReuse()`.

SwiftUI does all of this for you with the `.task` modifier. From Apple's documentation: "If the task doesn't finish before SwiftUI removes the view or the view changes identity, SwiftUI cancels the task."

```swift ios
import SwiftUI

struct OrderStatusView: View {
    @State private var status = "Loading…"

    var body: some View {
        Text(status)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    status = "Updated"
                }
            }
    }
}
```

## Common mistakes

> [!error] Expecting cancel() to stop the work
> It sets a flag. Loops need a check, and long computations need one every few thousand iterations.

> [!error] try? around Task.sleep or other throwing awaits in a loop
> It throws away the `CancellationError` and the loop keeps going. Use `try`, or check `Task.isCancelled` right after.

> [!error] Treating CancellationError as a failure
> Showing "Something went wrong" because the user navigated away is a bug. Catch `CancellationError` (and `URLError.cancelled` from `URLSession`) separately and do nothing.

> [!error] Assuming an inner Task { } is cancelled with its creator
> Only child tasks are. Prefer `async let` or a group inside async code; if you need an unstructured task, keep its handle and cancel it.

> [!error] A never-ending task capturing self strongly
> The task keeps `self` alive, so the `deinit` that would cancel it never runs. Capture `[weak self]` or cancel in `viewDidDisappear`.

> [!error] Doing real work in onCancel
> The handler runs concurrently with the operation and possibly while runtime locks are held. Flip a flag or call one thread-safe `cancel()`.

## Exercises

````exercise
id: m29-l03-e1
type: prediction
prompt: "A cancelled task runs a loop that mixes try? and a cancellation check. What does the program print?"
code: |
  func sync(batches: Int) async -> [String] {
      var log: [String] = []
      for batch in 1...batches {
          try? await Task.sleep(for: .milliseconds(5))
          log.append("batch \(batch) sent")
          if Task.isCancelled {
              log.append("stopping")
              break
          }
      }
      return log
  }

  let task = Task {
      await sync(batches: 3)
  }
  task.cancel()
  for line in await task.value {
      print(line)
  }
output: |
  batch 1 sent
  stopping
solution: |
  The task is cancelled before it runs. In the first iteration `Task.sleep` throws `CancellationError` immediately and `try?` discards it, so `batch 1 sent` is still appended. Then the explicit check sees the flag, appends `stopping` and breaks. Batches 2 and 3 never happen.

  ```output
  batch 1 sent
  stopping
  ```

  Without the `if Task.isCancelled` check, all three batches would be "sent".
````

````exercise
id: m29-l03-e2
type: comprehension
multiple: true
prompt: "A task runs `async let a = fetchA()`, a task group with three children, and `let log = Task { await upload() }`. You cancel the task. Which become cancelled? Select all that apply."
choices:
  - text: "The async let child running fetchA()."
    correct: true
    why: "async let creates a child task, and cancellation propagates to children."
  - text: "All three children in the task group, and any child added to the group afterward."
    correct: true
    why: "Apple: cancel() cancels child tasks and task groups, \"including those created in the future\"."
  - text: "The Task { } running upload()."
    correct: false
    why: "It's unstructured: it inherits priority and isolation but not cancellation. Keep the handle to cancel it."
  - text: "Code inside the cancelled task stops at its next line."
    correct: false
    why: "Cancellation is cooperative; code stops only where it checks or calls something that does."
solution: |
  The `async let` child and every group child (present and future) are cancelled. The `Task { }` isn't, and nothing is stopped by force: each piece of code reacts only when it checks `Task.isCancelled`, calls `checkCancellation()`, or awaits an API like `Task.sleep` that throws on cancellation.
````

````exercise
id: m29-l03-e3
type: solve
prompt: "Write `func checksum(of values: [Int]) async throws -> Int` that adds up the values but calls `Task.checkCancellation()` before each one, and `func searchFirstMatch(in values: [Int], target: Int) async -> Int?` that returns the index of the first value equal to `target`, or `nil` if not found or if the task is cancelled (check `Task.isCancelled` each iteration). Then run each in a task that you cancel before awaiting, plus one uncancelled checksum, and print what each returns (`cancelled` for the CancellationError)."
starter: |
  // Write checksum(of:) and searchFirstMatch(in:target:) here.
rubric:
  - checksum throws CancellationError via Task.checkCancellation() inside the loop.
  - searchFirstMatch returns nil when cancelled instead of throwing.
  - The caller distinguishes CancellationError from other errors.
  - The uncancelled run prints the real sum.
solution: |
  ```swift
  func checksum(of values: [Int]) async throws -> Int {
      var sum = 0
      for value in values {
          try Task.checkCancellation()
          sum += value
      }
      return sum
  }

  func searchFirstMatch(in values: [Int], target: Int) async -> Int? {
      for (index, value) in values.enumerated() {
          if Task.isCancelled {
              return nil
          }
          if value == target {
              return index
          }
      }
      return nil
  }

  let values = [4, 8, 15, 16, 23, 42]

  let full = Task { try await checksum(of: values) }
  print("checksum: \(try await full.value)")

  let stopped = Task { try await checksum(of: values) }
  stopped.cancel()
  do {
      print("checksum: \(try await stopped.value)")
  } catch is CancellationError {
      print("checksum: cancelled")
  }

  let search = Task { await searchFirstMatch(in: values, target: 23) }
  search.cancel()
  print("search: \(String(describing: await search.value))")
  ```

  ```output
  checksum: 108
  checksum: cancelled
  search: nil
  ```

  The two styles match the two kinds of callers: a throwing function signals "I didn't finish" with `CancellationError`, which callers already handle in their `catch`. A non-throwing search returns `nil`, an answer the caller already handles. Either way, cancellation is checked inside the loop, where the work is.
````

````exercise
id: m29-l03-e4
type: find-errors
prompt: "This view model refreshes prices every 10 seconds. The screen that owns it is dismissed, but the logs show the refresh continuing forever. Which are real causes?"
code: |
  @MainActor
  final class PricesViewModel {
      var prices: [String] = []

      func startRefreshing() {
          Task {
              while true {
                  prices = await PriceService.fetch()
                  try? await Task.sleep(for: .seconds(10))
              }
          }
      }

      deinit {
          print("PricesViewModel deinit")
      }
  }
choices:
  - text: "The loop never checks Task.isCancelled, and try? swallows the CancellationError from Task.sleep."
    correct: true
    why: "Even if something cancelled the task, this loop wouldn't stop."
  - text: "The task handle is discarded, so nothing can ever cancel the task."
    correct: true
    why: "Keep it in a property and cancel it when the screen goes away."
  - text: "The closure captures self strongly and never ends, so the view model can't be deallocated and its deinit never runs."
    correct: true
    why: "A task retains its closure until it finishes. An endless loop with strong self is a leak."
  - text: "Task { } inside a @MainActor class runs on a background thread, so prices is updated off the main thread."
    correct: false
    why: "The task inherits the main actor. The assignment to prices is on the main actor."
rubric:
  - Finds the missing cancellation check and the swallowing try?.
  - Finds the discarded handle.
  - Finds the strong self capture in a never-ending task.
solution: |
  Three problems combine: nothing can cancel the task (no handle), the loop wouldn't stop if cancelled (no check, `try?` swallows), and the task keeps the view model alive forever (strong `self` in an endless loop), so `deinit` never runs. A fixed version:

  ```swift
  enum PriceService {
      static func fetch() async -> [String] {
          try? await Task.sleep(for: .milliseconds(10))
          return ["AAPL 1", "MSFT 2"]
      }
  }

  @MainActor
  final class PricesViewModel {
      var prices: [String] = []
      private var refreshTask: Task<Void, Never>?

      func startRefreshing() {
          refreshTask?.cancel()
          refreshTask = Task { [weak self] in
              while !Task.isCancelled {
                  let latest = await PriceService.fetch()
                  self?.prices = latest
                  try? await Task.sleep(for: .seconds(10))
              }
          }
      }

      func stopRefreshing() {
          refreshTask?.cancel()
          refreshTask = nil
      }

      deinit {
          refreshTask?.cancel()
          print("PricesViewModel deinit")
      }
  }

  var model: PricesViewModel? = PricesViewModel()
  model?.startRefreshing()
  model?.stopRefreshing()
  model = nil
  ```

  ```output
  PricesViewModel deinit
  ```

  The screen calls `stopRefreshing()` when it disappears; `deinit` cancels as a backstop, and it can run because the task only holds `self` weakly.
````

````exercise
id: m29-l03-e5
type: fill-in
prompt: "Complete the wrapper so cancelling the task cancels the legacy job."
code: |
  func run(_ job: LegacyJob) async -> Bool {
      await [[1]] {
          job.waitUntilDone()
      } [[2]]: {
          job.[[3]]()
      }
  }
blanks:
  - id: "1"
    answers: ["withTaskCancellationHandler"]
  - id: "2"
    answers: ["onCancel"]
  - id: "3"
    answers: ["cancel"]
solution: |
  `withTaskCancellationHandler { operation } onCancel: { handler }`. The handler calls the legacy object's own `cancel()`, which is the only way to stop work that doesn't check `Task.isCancelled`. The handler is `@Sendable` and can run concurrently with the operation, so `LegacyJob` must be thread-safe (Sendable).
````

````exercise
id: m29-l03-e6
type: explain
prompt: "Why doesn't Swift let you force-stop a task from outside, the way you might kill a thread? Explain using this task, which updates two pieces of state."
code: |
  let transfer = Task {
      await checking.withdraw(50)
      await savings.deposit(50)
  }
  transfer.cancel()
rubric:
  - A forced stop could happen between two related updates and leave state inconsistent.
  - Cooperative cancellation lets the task stop at points where its state is consistent.
  - The task can also clean up (close files, cancel underlying requests) before stopping.
  - Mentions that Apple's documentation describes cancellation as cooperative.
solution: |
  Picture a task that moves money: it subtracts from one account and then adds to another. If something could kill it between the two lines, the money would vanish. A thread that's killed mid-function can also leave locks held and files half-written. Swift's cancellation is cooperative ("Task cancellation is cooperative and idempotent", in Apple's words) so the task decides where it's safe to stop: before starting the transfer, or after both updates, never in between. It also gets to clean up on the way out: cancel the underlying network request, close a file, return the partial results. The price is that you must put checks in long-running code.
````

## Summary

- `cancel()` flags the task, runs its cancellation handlers once and cancels its children. It never stops code by force.
- Check with `Task.isCancelled` (decide yourself) or `try Task.checkCancellation()` (throws `CancellationError`). `Task.sleep` throws on cancellation; `URLSession` throws `URLError.cancelled`.
- React by throwing, or by returning partial or empty results. Long computations need a check every so often.
- `try?` around a throwing await in a loop swallows cancellation. Use `try` or check the flag right after.
- `withTaskCancellationHandler` runs a `@Sendable` handler immediately on cancellation (before the operation, if already cancelled), for work that can't check the flag itself.
- Cancellation reaches `async let` and group children, not unstructured `Task { }` or `Task.detached`.
- Keep a screen's task in a property and cancel it in `viewDidDisappear` and `deinit`; capture `[weak self]` in never-ending loops. SwiftUI's `.task` cancels for you when the view goes away.
