---
id: m29-l01
title: async and await
description: "The core of Swift Concurrency. You turn a completion handler into an async function, learn exactly what await promises (a possible suspension point that frees the thread) and what it doesn't (parallelism, a background thread, blocking), see why thousands of waiting async functions don't need thousands of threads, start async work from synchronous code with Task, and run top-level await in main.swift."
module: m29
order: 1
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l06, m26-l02]
objectives:
  - Declare and call async and async throws functions, and put try and await in the right order.
  - Explain what a suspension point is and what happens to the thread while a function is suspended.
  - List what await doesn't do, starting with blocking and running things in parallel.
  - Explain why async functions don't map one-to-one to threads, and why blocking inside one is a bug.
  - Start async work from synchronous code with Task, and keep a handle when you need the result.
  - Use top-level await in main.swift and know when the program ends.
terms:
  - term: Asynchronous function
    definition: "A function or method declared with async. It can suspend partway through, at a call marked with await, and resume later. Only async code can call it directly."
  - term: Suspension point
    definition: "A place where an async function may pause and give up its thread so other work can run. Every one is marked with await (or async let and for await, which you'll see later)."
  - term: Task
    definition: "A unit of asynchronous work that runs async code. Every async function runs as part of some task. Task { } creates a new top-level task from any context, including synchronous code."
  - term: Cooperative thread pool
    definition: "The small set of threads, about one per CPU core, that Swift Concurrency uses to run tasks that aren't tied to the main actor. Tasks give the thread back at suspension points instead of blocking it."
  - term: Top-level await
    definition: "Using await directly in main.swift. The top-level code then runs as an async program on the main actor, and the program exits when that code reaches the end."
mastery:
  - Rewrite a completion-handler function as async throws and call it with try await inside do/catch.
  - Point at each suspension point in a function and say what other code can run there.
  - Predict the order of prints when top-level code creates a Task and then awaits it.
  - Explain to a colleague why two awaits in a row don't run in parallel.
  - Replace a semaphore or Thread.sleep inside async code with a non-blocking alternative.
  - Call an async function from a button handler with Task and keep a handle when it must be cancelled or awaited.
resources: [swift-book, swift-evolution, swift-mainactor, understanding-hangs]
cards:
  - id: m29-l01-c1
    front: What does await mean?
    back: "It marks a possible suspension point: the function may pause there until the call finishes. While paused it holds no thread, so other work can run on that thread. It doesn't block, and it doesn't start anything in parallel."
  - id: m29-l01-c2
    front: Do two awaits in a row run in parallel?
    back: "No. await a() then await b() runs a to completion, then b. Inside one task, code runs in order. Parallel work needs child tasks (async let, task groups) or separate tasks."
  - id: m29-l01-c3
    front: How do you call an async function from a synchronous function?
    back: "Create a task: Task { await doWork() }. The synchronous function returns right away and the task runs the async code. Keep the Task value if you need its result or want to cancel it."
  - id: m29-l01-c4
    front: Why must you never block (semaphore.wait, Thread.sleep) inside async code?
    back: "Tasks share a small pool of threads, about one per core. A blocked task holds its thread, so enough of them starve the pool and stall every other task. Use await-based APIs like Task.sleep instead."
  - id: m29-l01-c5
    front: When does a main.swift program with top-level await exit?
    back: "When the top-level code reaches its end. Tasks that haven't finished are abandoned, so await their value (or otherwise wait for them) before the end."
---

## The idea in one sentence

An `async` function can pause at each `await` without holding on to a thread, so code that waits for something reads top to bottom like ordinary code while the thread stays free for other work.

> [!note] Where this lesson sits
> Module 28 got work off the main thread with threads, dispatch queues and completion handlers, and ended with the data races Swift 6 catches at compile time. Module 26, lesson 2 previewed `withCheckedThrowingContinuation`. This module is Swift Concurrency proper: `async`/`await` here, tasks in lesson 2, cancellation in 3, actors in 4, `Sendable` and isolation in 5, and migration in 6. Swift Concurrency runs on Linux too, so the plain-Swift blocks were compiled and run with Swift 6.3 there, and every output was written so it doesn't depend on which thread runs what or how fast. Where code tells you where it's running, it uses `#isolation` (introduced in lesson 2) rather than `Thread.isMainThread`: on Linux, Swift 6.3 printed `false` from a task on the main actor, so thread checks aren't a reliable teaching tool inside async code.

## From a completion handler to an async function

Here's the shape you know from Module 28, lesson 5: the function returns immediately and reports later through a closure.

```swift illustrative
func loadProfile(id: Int, completion: @escaping @Sendable (Result<Profile, LoadError>) -> Void)
```

The async version says the same thing in the signature, and hands the result back as a return value:

```swift
struct Profile {
    let id: Int
    let name: String
}

enum LoadError: Error {
    case notFound(Int)
}

func loadProfile(id: Int) async throws -> Profile {
    try await Task.sleep(for: .milliseconds(50))   // stands in for a network request
    guard id == 1 else { throw LoadError.notFound(id) }
    return Profile(id: id, name: "Ana")
}

do {
    let profile = try await loadProfile(id: 1)
    print("loaded \(profile.name)")
    let missing = try await loadProfile(id: 7)
    print("loaded \(missing.name)")
} catch {
    print("failed: \(error)")
}
```

```output
loaded Ana
failed: notFound(7)
```

Line by line:

1. `async throws` goes after the parameter list, `async` first. The function can suspend and can throw.
2. `Task.sleep(for:)` suspends for at least the given duration without blocking a thread. It's how the Swift book simulates slow work in examples, and so does this module. It throws if the task is cancelled (lesson 3), so it needs `try`.
3. The result is a `return` and the failure is a `throw`. There's no completion handler to forget to call, and no way to call it twice: the compiler checks that every path returns or throws exactly once, which is the rule Module 26 made you enforce by hand.
4. The caller writes `try await`, in that order, and handles errors with an ordinary `do`/`catch`.
5. The `await` calls are at the top level of `main.swift`. That's allowed and covered at the end of this lesson.

## What await means

`await` marks a **possible suspension point**: a place where the function may pause until the call it's making has finished. The Swift book puts the mechanism plainly: an async function "can give up the thread that it's running on, which lets another asynchronous function run on that thread while the first function is blocked. When an asynchronous function resumes, Swift doesn't make any guarantee about which thread that function will run on."

So at each `await`:

- the function may stop and its local state is saved (not on a thread's stack, which is why it doesn't need to keep one);
- the thread it was on goes off and runs something else;
- when the awaited call finishes, the function continues from that point, possibly on another thread.

"Possible" matters. If the callee finishes without ever needing to wait, there may be no pause at all. You can't tell from the call site, and you shouldn't care: write code that's correct whether or not it suspends.

The compiler makes every possible suspension point visible. Leave out `await` and it refuses:

```swift no-compile expression is 'async' but is not marked with 'await'
func fetchScore() async -> Int {
    42
}

func showScore() async {
    let score = fetchScore()
    print(score)
}
```

Swift 6.3: `error: expression is 'async' but is not marked with 'await'`, with the note `call is 'async'`. That's on purpose. Anything can happen at a suspension point (other code can run and change shared state, as you'll see with actors), so you get to see every one of them when reading the code.

And only async code can call async code directly:

```swift no-compile 'async' call in a function that does not support concurrency
func fetchScore() async -> Int {
    42
}

func showScore() {
    let score = await fetchScore()
    print(score)
}
```

Swift 6.3: `error: 'async' call in a function that does not support concurrency`, with the note `add 'async' to function 'showScore()' to make it asynchronous`. That note is one fix. The other, for code that must stay synchronous (a button action, `viewDidLoad`), is a `Task`, later in this lesson.

## What await doesn't mean

Most confusion about Swift Concurrency comes from reading more into `await` than it says.

**It doesn't block.** `semaphore.wait()` and `group.wait()` from Module 28 park a thread until something happens. `await` gives the thread back. That's the whole point: a function waiting on the network costs no thread at all.

**It doesn't run anything in parallel.** Inside one task, code runs in order. Two awaits in a row are two waits, one after the other:

```swift
func simulateRequest() async {
    try? await Task.sleep(for: .milliseconds(100))
}

let clock = ContinuousClock()
let start = clock.now
await simulateRequest()
await simulateRequest()
let elapsed = clock.now - start
print("at least 200 ms: \(elapsed >= .milliseconds(200))")
```

```output
at least 200 ms: true
```

`ContinuousClock` measures elapsed time, and `Task.sleep` waits at least as long as asked, so the check holds on every run. The two requests are independent, yet the second doesn't start until the first is done. Running them at the same time needs **child tasks** (`async let` or a task group), which is lesson 2.

**It doesn't mean "on a background thread".** `await` says the call might pause, not where the callee runs. Where an async function runs is decided by its **isolation**: a `@MainActor` async function runs on the main actor no matter who awaits it, an actor's method runs on that actor, and a plain (nonisolated) async function runs either on the cooperative pool or on the caller's actor depending on a Swift 6.2 setting. Lessons 4 and 6 sort that out. Until then, don't assume `await` moved your work off the main thread.

**It doesn't make code thread-safe.** Shared mutable state that two tasks can reach is still a data race, and Swift 6 still rejects it. Actors (lesson 4) are the tool for that.

## The main actor can only do one thing at a time

In `main.swift`, top-level code runs on the main actor (Module 21, lesson 3). A task you create there with `Task { }` inherits that: its code also runs on the main actor. And the main actor runs one piece of code at a time. So the task can't start until the top-level code gives the main actor up, at an `await`:

```swift
var log: [String] = []

let task = Task {
    log.append("task runs")
}
log.append("top-level code keeps going")
await task.value
log.append("after the await")

for line in log {
    print(line)
}
```

```output
top-level code keeps going
task runs
after the await
```

1. `var log` is a top-level variable, so it belongs to the main actor. The task can touch it because the task runs on the main actor too.
2. `Task { … }` creates the task and returns at once. The task is ready to run but the main actor is busy, running this very code.
3. `log.append("top-level code keeps going")` runs first, every time.
4. `await task.value` suspends the top-level code until the task finishes. The main actor is now free, the task runs, and then the top-level code resumes.

Read this as the rule for UI code: **between two awaits, code on the main actor runs without interruption**, and at each await other main-actor work (a tap, a layout pass, another task) can get in. Lesson 4 turns that into the reentrancy rule for actors.

## Async functions aren't threads

In Module 28, waiting meant a thread: a thread blocked in `sync`, `wait()` or `Thread.sleep` stays allocated and idle until it's woken. A suspended async function holds no thread. Tasks that aren't on the main actor or another actor run on a **cooperative thread pool** that has about as many threads as the device has cores. When a task suspends, its thread picks up another task.

That's why this program finishes in about a tenth of a second, not a hundred seconds, and without creating 1,000 threads:

```swift
func waitBriefly() async {
    try? await Task.sleep(for: .milliseconds(100))
}

let clock = ContinuousClock()
let start = clock.now
var tasks: [Task<Void, Never>] = []
for _ in 1...1_000 {
    tasks.append(Task { await waitBriefly() })
}
for task in tasks {
    await task.value
}
let elapsed = clock.now - start
print("finished: \(tasks.count)")
print("under 10 seconds: \(elapsed < .seconds(10))")
```

```output
finished: 1000
under 10 seconds: true
```

On the Linux machine that ran it, the elapsed time was about 0.1 seconds. (The check is generous so a slow CI machine doesn't fail it.) All 1,000 tasks wait at the same time, and waiting costs nothing.

The flip side is a hard rule: **never block a thread inside async code**. `Thread.sleep`, `semaphore.wait()`, `group.wait()` or a long synchronous read in an async function keeps a pool thread busy doing nothing. With a pool the size of the core count, a handful of those stall every other task in the app. Swift's migration guide says it directly: "The Swift concurrency runtime expects code to never block on future work, allowing the system to always make forward progress." Use the await-based version (`Task.sleep`, `URLSession`'s async methods, a continuation from lesson 6) instead.

CPU-heavy work is different: it doesn't wait, it computes. It's fine on the pool, as long as you don't put it on the main actor, and a long loop should check for cancellation (lesson 3).

## Calling async code from synchronous code: Task

Button actions, `viewDidLoad` and delegate callbacks are synchronous. To start async work from them, create a task:

```swift
func fetchGreeting() async -> String {
    try? await Task.sleep(for: .milliseconds(20))
    return "hello"
}

func refreshButtonTapped() -> Task<Void, Never> {
    print("tap handled")
    return Task {
        let greeting = await fetchGreeting()
        print("greeting: \(greeting)")
    }
}

let refresh = refreshButtonTapped()
print("handler returned")
await refresh.value
```

```output
tap handled
handler returned
greeting: hello
```

`Task { }` takes an async closure, starts running it as a new task and returns a `Task` value immediately. The synchronous function never waits. The print order is fixed here because `greeting:` can only be printed after `fetchGreeting()` returns, and the program doesn't look at the task again until `await refresh.value`.

The `Task` value is a handle. Apple's documentation: "A task runs regardless of whether you keep a reference to it. However, if you discard the reference to a task, you give up the ability to wait for that task's result or cancel the task." In app code you keep it in a property when the screen might go away before the work finishes (lesson 3), and drop it for fire-and-forget work.

In UIKit it looks like this. The view controller is `@MainActor`, so the task inherits the main actor and can update the label after the `await` with no hop back:

```swift ios
import UIKit

final class GreetingViewController: UIViewController {
    private let label = UILabel()
    private let button = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        button.configuration?.title = "Refresh"
        button.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
    }

    @objc private func refreshTapped() {
        label.text = "Loading…"
        Task {
            let greeting = await fetchGreeting()
            label.text = greeting
        }
    }

    private func fetchGreeting() async -> String {
        try? await Task.sleep(for: .milliseconds(300))
        return "Hello"
    }
}
```

Compare it with Module 28: no `DispatchQueue.main.async`, no `[weak self]` dance to get back to the main thread. The compiler knows `label.text = greeting` runs on the main actor, because the task inherited it. (`fetchGreeting()` is a method of a `@MainActor` class, so it runs on the main actor too; `Task.sleep` suspends without blocking it. If it did heavy computing, you'd move that off the main actor, lesson 4.)

> [!tip] Task {} inherits, Task.detached doesn't
> `Task { }` created in main-actor code runs on the main actor, and created in an actor's method runs on that actor. That's usually what you want for UI code. The exception, `Task.detached`, and when (rarely) to use it, is lesson 2.

## Top-level await

Every block in this lesson uses `await` at the top level of `main.swift`. When a `main.swift` contains an `await`, Swift runs its top-level code as an async program on the main actor ([SE-0343](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0343-top-level-concurrency.md), Swift 5.7). In an app you won't write `main.swift` code like this (UIKit and SwiftUI start your app), but command-line tools and these examples do.

One consequence: the program exits when the top-level code reaches its end. Tasks still waiting are abandoned:

```swift
let task = Task {
    print("this never prints")
}
print("end of top-level code")
```

```output
end of top-level code
```

The task inherits the main actor, and the main actor is busy until the top-level code finishes, at which point the program exits. Nothing gave the task a chance to run. `await task.value` before the end fixes it. In an app the process keeps running, so the equivalent problem is a task that keeps running after its screen is gone, which is what cancellation is for.

## Common mistakes

> [!error] error: expression is 'async' but is not marked with 'await'
> You called an async function without `await`. Add it, and `try` before it if the function throws: `try await`.

> [!error] error: 'async' call in a function that does not support concurrency
> A synchronous function called an async one. Make the caller `async` if its callers can await it; otherwise start a `Task` at the boundary (a button action, `viewDidLoad`).

> [!error] Expecting two awaits to overlap
> `let a = await loadA(); let b = await loadB()` takes as long as both together. That's correct when `b` needs `a`. When they're independent, use `async let` (lesson 2).

> [!error] Blocking inside async code
> `semaphore.wait()`, `Thread.sleep(forTimeInterval:)` or `DispatchGroup.wait()` inside an async function holds a thread from a pool the size of your core count. Use `Task.sleep`, async APIs, or a continuation.

> [!error] Assuming await moved the work off the main thread
> `Task { heavyComputation() }` from a view controller runs `heavyComputation()` on the main actor, because the task inherits it. Decide on purpose where heavy work runs (lessons 4 and 6).

> [!error] Assuming the same thread after an await
> Code after an `await` can resume on a different thread. Don't keep thread-local state across an await, and don't hold a lock across one.

## Exercises

````exercise
id: m29-l01-e1
type: prediction
prompt: "Top-level code creates a task, prints, and then awaits the task. What does the program print?"
code: |
  func double(_ n: Int) async -> Int {
      n * 2
  }

  print("1: start")
  let task = Task {
      let result = await double(21)
      print("2: task got \(result)")
  }
  print("3: task created")
  await task.value
  print("4: done")
output: |
  1: start
  3: task created
  2: task got 42
  4: done
solution: |
  The task is created from top-level code, which runs on the main actor, so the task inherits the main actor. The main actor is busy running the top-level code, so the task can't start until that code suspends.

  1. `1: start` prints.
  2. `Task { … }` returns immediately; the task is waiting for the main actor.
  3. `3: task created` prints.
  4. `await task.value` suspends the top-level code. The task runs, awaits `double(21)`, and prints `2: task got 42`.
  5. The task finishes, the top-level code resumes and prints `4: done`.

  ```output
  1: start
  3: task created
  2: task got 42
  4: done
  ```
````

````exercise
id: m29-l01-e2
type: comprehension
multiple: true
prompt: "Which statements about `let user = try await api.loadUser(id: 1)` are true? Select all that apply."
choices:
  - text: "The function containing this line may pause here, and while it's paused it doesn't hold a thread."
    correct: true
    why: "That's a suspension point: the thread is given back and can run other work."
  - text: "The current thread blocks until loadUser returns, like semaphore.wait()."
    correct: false
    why: "await never blocks the thread. Blocking is what it replaces."
  - text: "loadUser is guaranteed to run on a background thread."
    correct: false
    why: "Where it runs depends on its isolation. A @MainActor loadUser runs on the main actor."
  - text: "When the function continues after this line, it may be on a different thread than before."
    correct: true
    why: "The Swift book: when an async function resumes, Swift doesn't guarantee which thread it runs on."
  - text: "If the next line is another await, the two calls run in parallel."
    correct: false
    why: "Inside one task, code runs in order. Parallelism needs child tasks."
solution: |
  `await` marks a possible suspension point: the function may pause, its thread goes off to do other work, and it may resume on another thread. It doesn't block, doesn't pick a thread for the callee (isolation does), and doesn't make the next await overlap with this one.
````

````exercise
id: m29-l01-e3
type: fill-in
prompt: "Complete the async function and its caller."
code: |
  func loadBalance(account: String) [[1]] -> Int {
      try await Task.sleep(for: .milliseconds(10))
      return 120
  }

  func showBalance() async {
      do {
          let balance = [[2]] loadBalance(account: "main")
          print(balance)
      } catch {
          print("failed")
      }
  }

  func balanceButtonTapped() {
      [[3]] {
          await showBalance()
      }
  }
blanks:
  - id: "1"
    answers: ["async throws"]
  - id: "2"
    answers: ["try await"]
  - id: "3"
    answers: ["Task"]
solution: |
  - `async throws`: the body uses `try await Task.sleep`, so the function both suspends and throws. `async` comes first.
  - `try await`: the call can throw and can suspend. `try` comes first.
  - `Task`: a synchronous function can't `await`, so it starts a task to run the async code.

  ```swift
  func loadBalance(account: String) async throws -> Int {
      try await Task.sleep(for: .milliseconds(10))
      return 120
  }

  func showBalance() async {
      do {
          let balance = try await loadBalance(account: "main")
          print(balance)
      } catch {
          print("failed")
      }
  }

  func balanceButtonTapped() -> Task<Void, Never> {
      Task {
          await showBalance()
      }
  }

  await balanceButtonTapped().value
  ```

  ```output
  120
  ```

  The tested version returns the task so the program can wait for it before exiting.
````

````exercise
id: m29-l01-e4
type: find-errors
prompt: "A teammate wrote this download helper. Which of these are real problems?"
code: |
  import Foundation

  func download(_ name: String) async -> Int {
      Thread.sleep(forTimeInterval: 0.5)   // simulate the network
      return name.count
  }

  func downloadAll() async -> Int {
      let a = await download("first")
      let b = await download("second")
      return a + b
  }

  func refresh() {
      let total = await downloadAll()
      print(total)
  }
choices:
  - text: "Thread.sleep blocks a pool thread for half a second instead of suspending."
    correct: true
    why: "Use try await Task.sleep(for:), which gives the thread back. Blocking calls starve the cooperative pool."
  - text: "refresh() is synchronous, so it can't use await; it doesn't compile."
    correct: true
    why: "'async' call in a function that does not support concurrency. Wrap it in Task { } or make refresh async."
  - text: "The two downloads run one after the other, not at the same time."
    correct: true
    why: "Not a compile error, but if the goal was to overlap them, it fails: two awaits in a row are sequential. async let fixes it (lesson 2)."
  - text: "download must be marked throws because it's async."
    correct: false
    why: "async and throws are independent. A function can be async without throwing."
rubric:
  - Identifies the blocking Thread.sleep.
  - Identifies the await in a synchronous function.
  - Notes that the downloads are sequential.
solution: |
  Three problems:

  1. `Thread.sleep` inside an async function blocks a thread from a pool with about one thread per core. Use `try? await Task.sleep(for: .milliseconds(500))`.
  2. `refresh()` isn't async, so `await` is a compile error. A button handler can't be async; start a task.
  3. The downloads are independent but awaited one after the other. That's correct code, just slower than it needs to be; lesson 2 shows `async let`.

  A fixed version:

  ```swift
  func download(_ name: String) async -> Int {
      try? await Task.sleep(for: .milliseconds(50))   // simulate the network
      return name.count
  }

  func downloadAll() async -> Int {
      let a = await download("first")
      let b = await download("second")
      return a + b
  }

  func refresh() -> Task<Void, Never> {
      Task {
          let total = await downloadAll()
          print(total)
      }
  }

  await refresh().value
  ```

  ```output
  11
  ```
````

````exercise
id: m29-l01-e5
type: solve
prompt: "You have three async steps: `logIn(user:)` returns a token, `loadProfilePath(token:)` returns a path, and `loadAvatar(path:)` returns the image size in bytes. Each one throws `AppError.failed(step)` when its input is empty. Write `func avatarSize(for user: String) async throws -> Int` that chains them, and a synchronous `func avatarButtonTapped(user: String) -> Task<Void, Never>` that runs it and prints either `avatar: <bytes> bytes` or `error: <error>`. Call it for \"ana\" and for \"\" and await both tasks."
starter: |
  enum AppError: Error {
      case failed(String)
  }

  func logIn(user: String) async throws -> String {
      try await Task.sleep(for: .milliseconds(10))
      guard !user.isEmpty else { throw AppError.failed("logIn") }
      return "token-\(user)"
  }

  func loadProfilePath(token: String) async throws -> String {
      try await Task.sleep(for: .milliseconds(10))
      guard !token.isEmpty else { throw AppError.failed("profile") }
      return "/avatars/\(token).png"
  }

  func loadAvatar(path: String) async throws -> Int {
      try await Task.sleep(for: .milliseconds(10))
      guard !path.isEmpty else { throw AppError.failed("avatar") }
      return path.count * 100
  }

  // Write avatarSize(for:) and avatarButtonTapped(user:) here.
rubric:
  - avatarSize is async throws and uses try await for each step, in order.
  - Errors propagate with throw instead of being caught inside avatarSize.
  - The button handler is synchronous and starts a Task that handles errors with do/catch.
  - Both tasks are awaited before the program ends, so the output is complete and in order.
solution: |
  ```swift
  enum AppError: Error {
      case failed(String)
  }

  func logIn(user: String) async throws -> String {
      try await Task.sleep(for: .milliseconds(10))
      guard !user.isEmpty else { throw AppError.failed("logIn") }
      return "token-\(user)"
  }

  func loadProfilePath(token: String) async throws -> String {
      try await Task.sleep(for: .milliseconds(10))
      guard !token.isEmpty else { throw AppError.failed("profile") }
      return "/avatars/\(token).png"
  }

  func loadAvatar(path: String) async throws -> Int {
      try await Task.sleep(for: .milliseconds(10))
      guard !path.isEmpty else { throw AppError.failed("avatar") }
      return path.count * 100
  }

  func avatarSize(for user: String) async throws -> Int {
      let token = try await logIn(user: user)
      let path = try await loadProfilePath(token: token)
      return try await loadAvatar(path: path)
  }

  func avatarButtonTapped(user: String) -> Task<Void, Never> {
      Task {
          do {
              let bytes = try await avatarSize(for: user)
              print("avatar: \(bytes) bytes")
          } catch {
              print("error: \(error)")
          }
      }
  }

  await avatarButtonTapped(user: "ana").value
  await avatarButtonTapped(user: "").value
  ```

  ```output
  avatar: 2200 bytes
  error: failed("logIn")
  ```

  - The Module 26 callback pyramid becomes three lines. Each step uses the previous result, so sequential awaits are exactly right here.
  - `avatarSize` doesn't catch anything: errors propagate to whoever handles them, like synchronous throwing code.
  - `"/avatars/token-ana.png"` has 22 characters, so the fake size is 2200. The empty user fails at the first step and the later steps never run.
  - Awaiting the first task before creating the second keeps the output order fixed. Created together, the two tasks could finish in either order.
````

````exercise
id: m29-l01-e6
type: explain
prompt: "1,000 tasks that each `try await Task.sleep(for: .milliseconds(100))` finish in about 0.1 seconds. Explain why, and what would happen if each one called `Thread.sleep(forTimeInterval: 0.1)` instead."
code: |
  for _ in 1...1_000 {
      tasks.append(Task { try? await Task.sleep(for: .milliseconds(100)) })
  }
rubric:
  - Task.sleep suspends the task, so it holds no thread while it waits.
  - All 1,000 waits overlap, so the total is about one wait.
  - Thread.sleep blocks a thread from the cooperative pool, which has about one thread per core.
  - With blocking, only a few tasks wait at a time, so the total grows to roughly 1,000 × 0.1 s divided by the core count, and every other task in the program stalls meanwhile.
solution: |
  `Task.sleep` is a suspension point. Each task records "wake me in 100 ms" and gives its thread back, so all 1,000 tasks wait at the same time and the whole batch takes about as long as one wait.

  `Thread.sleep` blocks the thread it runs on. The tasks run on the cooperative pool, which has about as many threads as cores. On an 8-core machine only 8 tasks sleep at once; the other 992 queue behind them, so the batch takes about 1,000 × 0.1 / 8 ≈ 12.5 seconds, and any other task in the program (including ones the UI is waiting for, if they use the pool) can't run in the meantime. That's why blocking calls don't belong in async code.
````

## Summary

- `async` in a signature means the function can suspend; callers use `await` (and `try await` if it throws). Results come back as return values and errors as thrown errors, so "call the handler exactly once" is checked by the compiler.
- `await` marks a **possible suspension point**. The function may pause there without holding a thread and may resume on another thread.
- `await` doesn't block, doesn't run things in parallel, doesn't choose a background thread and doesn't make shared state safe. Isolation decides where code runs; child tasks give you parallelism.
- Code on the main actor runs uninterrupted between two awaits; at an await, other main-actor work can run.
- Suspended functions hold no thread, so thousands of waiting tasks are cheap. Never block a thread inside async code.
- `Task { }` starts async work from synchronous code and returns a handle you can await or cancel. It inherits the actor it's created on.
- Top-level `await` in `main.swift` makes the program async on the main actor, and the program exits when the top-level code ends, abandoning unfinished tasks.
