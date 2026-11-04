---
id: m29-l02
title: Tasks and structured concurrency
description: "Run work at the same time without losing track of it. You separate a task from a thread, start a fixed number of child tasks with async let and a variable number with task groups, collect their results in a predictable order, see why a child can never outlive its parent, and learn when an unstructured Task or Task.detached is the right tool. Priorities, and what they do and don't promise, close the lesson."
module: m29
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l01]
objectives:
  - Explain the difference between a task and a thread, and what the task tree is.
  - Run a fixed number of independent operations concurrently with async let.
  - Run a variable number of operations with withTaskGroup and withThrowingTaskGroup, and collect results in a defined order.
  - State the lifetime rule for child tasks and what happens to children you never await.
  - Choose between structured child tasks, Task { } and Task.detached, and say what each inherits.
  - Describe what task priority influences and what it doesn't guarantee.
terms:
  - term: Structured concurrency
    definition: "Concurrency where every child task belongs to a scope (an async let or a task group) and is finished, awaited or cancelled before that scope exits. Children can't outlive their parent."
  - term: Child task
    definition: "A task created by async let or a task group. It inherits its parent's priority and task-local values, is cancelled when the parent is, and must finish before the parent's scope ends."
  - term: async let
    definition: "A declaration that starts its initializer as a child task right away and lets the parent continue. Using the value later requires await."
  - term: Task group
    definition: "A scope created by withTaskGroup or withThrowingTaskGroup where you add any number of child tasks and consume their results, in completion order, with for await or next()."
  - term: Unstructured task
    definition: "A top-level task created with Task { } or Task.detached. It has no parent scope: nobody waits for it automatically and nobody cancels it automatically."
  - term: Task priority
    definition: "A hint (high, medium, low, background, plus the aliases userInitiated and utility) that executors may use to run more urgent tasks first. It doesn't order results."
mastery:
  - Turn two sequential awaits of independent calls into async let and show the time drop.
  - Write a task group that fetches a list of ids and returns results keyed by id, in a stable order.
  - Explain why a withTaskGroup body that returns early still waits for every child.
  - Make a throwing task group fail fast and say what happens to the other children.
  - Say what Task { } inherits from main-actor code and why Task.detached is rarely the answer.
  - Explain priority escalation when a high-priority task awaits a low-priority one.
resources: [swift-book, swift-evolution, swift-mainactor]
cards:
  - id: m29-l02-c1
    front: Task vs thread?
    back: "A thread is an OS execution resource. A task is a unit of async work that the runtime schedules onto threads; it holds no thread while suspended. Thousands of tasks can share a handful of threads."
  - id: m29-l02-c2
    front: async let vs a task group?
    back: "async let: a fixed number of child tasks, each with its own name and possibly different types. Task group: any number of children of one result type, added in a loop, consumed in completion order."
  - id: m29-l02-c3
    front: In what order do a task group's results arrive?
    back: "In the order the children finish, which varies run to run. Return an id with each result and put them in a dictionary or sort them if order matters."
  - id: m29-l02-c4
    front: What happens to a child task you never await?
    back: "An un-awaited async let is cancelled and then awaited when its scope ends. A task group always waits for all its children before withTaskGroup returns."
  - id: m29-l02-c5
    front: What does Task { } inherit? Task.detached?
    back: "Task { } inherits the current actor isolation, priority and task-local values, but isn't a child: it isn't cancelled with the caller. Task.detached inherits none of them."
---

## The idea in one sentence

Structured concurrency lets one task split into child tasks that run at the same time, with one firm rule that keeps it manageable: a child task never outlives the scope that created it.

> [!note] What you already know
> Lesson 1: `await` waits in order, and two awaits never overlap. Module 28, lesson 3 ran work at the same time with `DispatchGroup` and had to make sure every `enter()` met a `leave()`, then waited with `notify` or a blocking `wait()`. Child tasks do the same job, and the compiler does the bookkeeping. The plain-Swift blocks were run with Swift 6.3 on Linux; results that finish in an unpredictable order are always collected and sorted before printing.

## Tasks aren't threads

A **task** is a unit of async work. Every async function runs inside one. A **thread** is what actually executes instructions. The runtime runs a task's code on some thread until the task reaches a suspension point, then puts that thread to work on another task. When the first task resumes, it gets whatever thread is free (or the main thread, if it's on the main actor).

| | Thread (Module 28) | Task |
| --- | --- | --- |
| What it is | An OS resource with its own stack | A unit of async work, scheduled by the Swift runtime |
| While waiting | Blocked, still allocated | Suspended, holds no thread |
| How many is fine | Dozens | Thousands |
| Relationship | None between threads | A tree: parents and child tasks |
| Cancellation | You build it (flags, `isCancelled` on `Operation`) | Built in and propagated to children (lesson 3) |

That last row matters most. Tasks form a **tree**. A task can create child tasks, which can create their own. The tree is what lets Swift propagate cancellation and priority downward and guarantee that nothing keeps running after the work that wanted it is over.

## async let: a fixed number of children

Three independent requests, awaited one after the other, take the sum of their times. `async let` starts each one as a child task immediately and lets the parent continue:

```swift
func fetchNumber(_ value: Int) async -> Int {
    try? await Task.sleep(for: .milliseconds(400))
    return value
}

let clock = ContinuousClock()

var start = clock.now
let a = await fetchNumber(1)
let b = await fetchNumber(2)
let c = await fetchNumber(3)
print("sequential sum: \(a + b + c), at least 1200 ms: \(clock.now - start >= .milliseconds(1_200))")

start = clock.now
async let x = fetchNumber(1)
async let y = fetchNumber(2)
async let z = fetchNumber(3)
let total = await x + y + z
print("concurrent sum: \(total), under 1100 ms: \(clock.now - start < .milliseconds(1_100))")
```

```output
sequential sum: 6, at least 1200 ms: true
concurrent sum: 6, under 1100 ms: true
```

The concurrent version took about 400 ms on Linux: the three waits overlapped. The checks leave plenty of room so a slow machine still passes.

How `async let` works:

1. `async let x = fetchNumber(1)` creates a child task that starts evaluating the right-hand side right away. The parent doesn't wait; it goes on to the next line.
2. `x` isn't an `Int` yet; it's a promise of one. Reading it requires `await`, because the child may not have finished. One `await` can cover a whole expression: `await x + y + z`.
3. If the child throws, reading it requires `try await`, and that's where the error surfaces.
4. Each `async let` can have its own type: `async let user = loadUser()` next to `async let feed = loadFeed()` is common.

### Children you don't await

An `async let` you never read isn't left running. When its scope ends, Swift cancels it and then waits for it to finish. The Swift 6.3 compiler warns about an `async let` you never use (`initialization of immutable value 'x' was never used`), because it's almost always a mistake: you paid for work you threw away. If you start an `async let` on one branch and return early on another, the unread child gets cancelled, which is usually what you want.

You can't pass an `async let` out of its scope or capture it in an escaping closure. That's the "structured" in structured concurrency: the child lives and dies inside the function that made it.

## Task groups: any number of children

`async let` needs one line per child, so it doesn't work for "fetch every id in this array". A **task group** does:

```swift
func thumbnailSize(for id: Int) async -> Int {
    // Later ids finish first, so completion order is the reverse of the input.
    try? await Task.sleep(for: .milliseconds(20 * (5 - id)))
    return id * 1_000
}

func loadThumbnails(ids: [Int]) async -> [Int: Int] {
    await withTaskGroup(of: (Int, Int).self) { group in
        for id in ids {
            group.addTask {
                (id, await thumbnailSize(for: id))
            }
        }

        var sizes: [Int: Int] = [:]
        for await (id, size) in group {
            sizes[id] = size
        }
        return sizes
    }
}

let sizes = await loadThumbnails(ids: [1, 2, 3, 4])
for id in sizes.keys.sorted() {
    print("thumbnail \(id): \(sizes[id]!) bytes")
}
```

```output
thumbnail 1: 1000 bytes
thumbnail 2: 2000 bytes
thumbnail 3: 3000 bytes
thumbnail 4: 4000 bytes
```

Walkthrough:

1. `withTaskGroup(of: (Int, Int).self)` creates a group whose children all return `(Int, Int)`. The closure gets the group; whatever it returns, `withTaskGroup` returns.
2. `group.addTask { … }` starts a child task. Each child here returns its id along with the result.
3. `for await (id, size) in group` receives results **in the order the children finish**, not the order they were added. Apple's documentation for `TaskGroup`: "Tasks added to a task group execute concurrently, and may be scheduled in any order." In this program the delays make id 4 finish first; in a real app, the network decides.
4. That's why each child returns its id, and the results go into a dictionary. Sorting the keys before printing makes the output identical on every run. If you need an array in input order, build it from the dictionary: `ids.map { sizes[$0]! }`.

Children can't touch the parent's local variables (`sizes` is mutated only in the `for await` loop, which runs in the parent). Write `group.addTask { sizes[id] = … }` and Swift 6.3 rejects it with `passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure`. It's the Module 28 data-race check in a new form; lesson 5 explains `sending`.

### Throwing groups fail fast

`withThrowingTaskGroup` lets children throw. When the error comes out of `for try await`, it propagates out of the group's closure, and the group then cancels the remaining children and waits for them:

```swift
enum DownloadError: Error {
    case badFile(Int)
}

func download(_ id: Int) async throws -> Int {
    if id == 2 {
        throw DownloadError.badFile(id)
    }
    try await Task.sleep(for: .seconds(60))   // would take a minute if not cancelled
    return id
}

func downloadAll() async {
    let clock = ContinuousClock()
    let start = clock.now
    do {
        let total = try await withThrowingTaskGroup(of: Int.self) { group in
            for id in 1...3 {
                group.addTask { try await download(id) }
            }
            var sum = 0
            for try await value in group {
                sum += value
            }
            return sum
        }
        print("total: \(total)")
    } catch {
        print("group failed: \(error)")
    }
    print("finished in under 5 seconds: \(clock.now - start < .seconds(5))")
}

await downloadAll()
```

```output
group failed: badFile(2)
finished in under 5 seconds: true
```

The two healthy downloads were sleeping for a minute. They stopped early because the group cancelled them and `Task.sleep` throws `CancellationError` when its task is cancelled. Cancellation is cooperative: a child that never checks would keep running, and the group would wait for it. That's lesson 3.

> [!note] Discarding groups
> When children produce no results (fire off 50 uploads, wait for all), `withDiscardingTaskGroup` and `withThrowingDiscardingTaskGroup` free each child's result as soon as it finishes instead of keeping it until you iterate. They need Swift 5.9 and iOS 17.

### Limiting how many children run at once

A group with 500 image downloads starts 500 children. To keep at most a few in flight, add the first few, then add one more each time one finishes:

```swift
func process(_ item: Int) async -> Int {
    try? await Task.sleep(for: .milliseconds(10))
    return item * item
}

func processAll(_ items: [Int], maxConcurrent: Int) async -> [Int: Int] {
    await withTaskGroup(of: (Int, Int).self) { group in
        var results: [Int: Int] = [:]
        var next = 0

        for _ in 0..<min(maxConcurrent, items.count) {
            let item = items[next]
            group.addTask { (item, await process(item)) }
            next += 1
        }

        for await (item, value) in group {
            results[item] = value
            if next < items.count {
                let item = items[next]
                group.addTask { (item, await process(item)) }
                next += 1
            }
        }
        return results
    }
}

let squares = await processAll(Array(1...10), maxConcurrent: 3)
print(squares.keys.sorted().map { squares[$0]! })
```

```output
[1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
```

At most three children exist at any moment, because a new one is added only after one has finished. The `let item = items[next]` copy matters: the child must capture a constant, not the mutable `next`.

## Lifetimes: children never outlive the scope

The guarantee that makes this "structured", in Apple's words: "a task group always waits for all child tasks to complete before it's destroyed." Even if the closure returns early:

```swift
func firstResult() async -> Int? {
    await withTaskGroup(of: Int.self) { group in
        group.addTask {
            try? await Task.sleep(for: .milliseconds(50))
            return 1
        }
        group.addTask {
            try? await Task.sleep(for: .milliseconds(300))
            return 2
        }
        return await group.next()   // the first child to finish
    }
}

let clock = ContinuousClock()
let start = clock.now
let first = await firstResult()
print("first: \(first ?? 0)")
print("waited for the slow child too: \(clock.now - start >= .milliseconds(300))")
```

```output
first: 1
waited for the slow child too: true
```

`group.next()` returned the 50 ms child's result, and the closure returned. `withTaskGroup` still didn't return until the 300 ms child finished. If you want the slow child to stop instead, call `group.cancelAll()` before returning and make sure it checks for cancellation (here `Task.sleep` would throw and `try?` would swallow it, so the child would end at once).

The same rule holds for `async let`, as you saw: cancelled and awaited at the end of the scope. So when a function that uses only structured concurrency returns, **all the work it started is over**. No orphaned work keeps writing to state you've moved on from. With dispatch queues you couldn't say that without a `DispatchGroup` and discipline.

## Unstructured tasks: Task { } and Task.detached

Sometimes you need work that isn't scoped to a function: a button tap in synchronous code (lesson 1), or work that should continue after the function that started it returns. That's an **unstructured task**. There are two kinds, and they differ in what they inherit. `#isolation` (a macro you'll meet properly in lesson 5) reports which actor the current code runs on, so it can show the difference:

```swift
func describe(_ isolation: (any Actor)?) -> String {
    switch isolation {
    case nil: "nonisolated"
    case is MainActor: "main actor"
    case let other?: "\(type(of: other))"
    }
}

print("top-level code:", describe(#isolation))

let inherited = Task {
    describe(#isolation)
}
print("Task { }:", await inherited.value)

let detached = Task.detached {
    describe(#isolation)
}
print("Task.detached:", await detached.value)
```

```output
top-level code: main actor
Task { }: main actor
Task.detached: nonisolated
```

| | Child task (`async let`, group) | `Task { }` | `Task.detached { }` |
| --- | --- | --- | --- |
| Actor isolation | Nonisolated unless the closure says otherwise | **Inherited** from where it's created | Not inherited |
| Priority | Inherited | Inherited | Not inherited (unless you pass one) |
| Task-local values | Inherited | Inherited | Not inherited |
| Cancelled when the creator is | Yes | No | No |
| Awaited automatically | Yes | No | No |

`Task { }` is the everyday tool for starting async work from synchronous code. It isn't a child: cancelling the code that created it does nothing to it, and nobody waits for it. If you need to cancel it, keep the handle (lesson 3).

`Task.detached` cuts every tie. Apple's documentation is blunt: "Don't use a detached unstructured task if it's possible to model the operation using structured concurrency features like child tasks." People reach for it to "get off the main actor", but a function that isn't main-actor isolated does that more clearly (lesson 6 covers `@concurrent`), and a detached task also drops priority and task-local values you may have wanted. Legitimate uses are rare: low-priority maintenance that genuinely shouldn't inherit anything from the code that triggered it.

> [!version] Newer task APIs
> Swift 6.2 added **task names** ([SE-0469](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0469-task-names.md), `Task(name: "Thumbnails") { … }`, shown by debugging tools and readable through `Task.name`) and **`Task.immediate`** ([SE-0472](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)), which starts running the task synchronously on the caller's context until its first suspension. Both need iOS 26 or later at runtime, so this lesson doesn't run them. Swift 6.4 makes the result of the `Task` initializers discardable by default ([SE-0520](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0520-discardableresult-task-initializers.md)).

## Priorities

`TaskPriority` has these values:

```swift
let priorities: [(String, TaskPriority)] = [
    ("high", .high),
    ("userInitiated", .userInitiated),
    ("medium", .medium),
    ("low", .low),
    ("utility", .utility),
    ("background", .background),
]
for (name, priority) in priorities {
    print(name, priority.rawValue)
}
```

```output
high 25
userInitiated 25
medium 21
low 17
utility 17
background 9
```

`userInitiated` and `utility` are aliases for `high` and `low`, named after the QoS classes from Module 28, lesson 2. Pass one when you create a task: `Task(priority: .background) { … }`, `group.addTask(priority: .low) { … }`.

What priority does, from Apple's `TaskPriority` page: "Typically, executors attempt to run tasks with a higher priority before tasks with a lower priority. However, the semantics of how priority is treated are left up to each platform and Executor implementation." So:

- It's a **hint about urgency**, not an ordering. Two tasks with different priorities can finish in either order. Never use priority to make output come out in a certain order.
- Child tasks inherit their parent's priority; `Task { }` inherits the current task's; `Task.detached` doesn't.
- **Priority escalation.** "If a higher-priority task accesses the value property, then the priority of this task increases until the task completes." A low-priority task that the UI is now waiting for gets bumped, which avoids the priority inversion from Module 28, lesson 6. A consequence: `Task.currentPriority` inside a task you're awaiting can report a higher priority than the one you passed. On Linux, a `.low` task awaited from top-level code reported `.medium` for exactly this reason.

## Common mistakes

> [!error] Printing from children and expecting input order
> Children finish in any order. Return an id with each result, collect, then sort or map back to input order.

> [!error] Using Task { } where async let or a group belongs
> `Task { await loadA() }; Task { await loadB() }` from an async function creates two unstructured tasks nobody waits for or cancels. Inside async code, prefer child tasks.

> [!error] Reaching for Task.detached to leave the main actor
> It also drops priority and task-locals, and the work isn't cancelled with anything. Use a nonisolated or `@concurrent` function (lesson 6) or an actor.

> [!error] Expecting an early return from a group to stop the other children
> The group waits for all children. Call `group.cancelAll()` and make the children check for cancellation.

> [!error] Capturing a mutable loop variable in a child
> `group.addTask { await process(items[next]) }` with a `var next` is rejected: Swift 6.3 reports `sending value of non-Sendable type '() async -> Int' risks causing data races`, because the child would read a `var` the parent keeps changing. Copy it into a `let` first.

> [!error] Starting thousands of children at once
> A group with one child per row of a 10,000-item list floods the network and memory. Keep a window of N children in flight.

## Exercises

````exercise
id: m29-l02-e1
type: prediction
prompt: "Each child sleeps for a different time, and the group collects results into a dictionary. What does the program print?"
code: |
  func score(for player: String) async -> Int {
      try? await Task.sleep(for: .milliseconds(10 * (6 - player.count)))
      return player.count * 10
  }

  let players = ["Ana", "Bo", "Carmen"]
  let scores = await withTaskGroup(of: (String, Int).self) { group in
      for player in players {
          group.addTask { (player, await score(for: player)) }
      }
      var result: [String: Int] = [:]
      for await (player, points) in group {
          result[player] = points
      }
      return result
  }
  for player in players {
      print("\(player): \(scores[player]!)")
  }
  print("children: \(scores.count)")
output: |
  Ana: 30
  Bo: 20
  Carmen: 60
  children: 3
solution: |
  The delays decide only the order in which results arrive (Carmen first, then Ana, then Bo), and that order never reaches the output: results go into a dictionary keyed by player, and the final loop walks the original `players` array.

  Each score is `count * 10`: Ana 30, Bo 20, Carmen 60. Three children, three entries.

  ```output
  Ana: 30
  Bo: 20
  Carmen: 60
  children: 3
  ```
````

````exercise
id: m29-l02-e2
type: comprehension
prompt: "A function does `async let profile = loadProfile()` and `async let feed = loadFeed()`, then hits a `guard` that returns early before reading either. What happens to the two child tasks?"
choices:
  - text: "They're cancelled and then awaited before the function returns."
    correct: true
    why: "An un-awaited async let is implicitly cancelled and awaited when its scope ends. Nothing outlives the function."
  - text: "They keep running in the background until they finish, and their results are discarded."
    correct: false
    why: "That's what an unstructured Task { } would do. Child tasks can't outlive their scope."
  - text: "The function returns immediately and the children are destroyed mid-flight without cleanup."
    correct: false
    why: "Swift doesn't kill tasks. It cancels them (a request) and waits for them to finish."
  - text: "It's a compile error to return before reading an async let."
    correct: false
    why: "It compiles. Swift 6.3 only warns when an async let is never used anywhere."
solution: |
  They're cancelled and awaited. Leaving the scope cancels any `async let` that wasn't awaited and then waits for it, so the function returns only after both children have finished. If the children check for cancellation (or use APIs like `Task.sleep` and `URLSession` that do), that's quick.
````

````exercise
id: m29-l02-e3
type: solve
prompt: "Write `func loadDashboard() async throws -> String` that loads a user name, an unread count and a balance concurrently using the given functions, and returns `\"<name>: <unread> unread, balance <balance>\"`. Then call it at the top level inside do/catch, print the result, and print whether it took under 250 ms (each call takes about 100 ms)."
starter: |
  func loadName() async throws -> String {
      try await Task.sleep(for: .milliseconds(100))
      return "Ana"
  }

  func loadUnreadCount() async throws -> Int {
      try await Task.sleep(for: .milliseconds(100))
      return 3
  }

  func loadBalance() async throws -> Int {
      try await Task.sleep(for: .milliseconds(100))
      return 250
  }

  // Write loadDashboard() and call it.
rubric:
  - Uses three async let declarations so the calls overlap.
  - Reads the values with try await (one expression or three).
  - Doesn't use Task { } or Task.detached for this.
  - Measures with ContinuousClock and prints a boolean instead of the raw time.
solution: |
  ```swift
  func loadName() async throws -> String {
      try await Task.sleep(for: .milliseconds(100))
      return "Ana"
  }

  func loadUnreadCount() async throws -> Int {
      try await Task.sleep(for: .milliseconds(100))
      return 3
  }

  func loadBalance() async throws -> Int {
      try await Task.sleep(for: .milliseconds(100))
      return 250
  }

  func loadDashboard() async throws -> String {
      async let name = loadName()
      async let unread = loadUnreadCount()
      async let balance = loadBalance()
      return try await "\(name): \(unread) unread, balance \(balance)"
  }

  let clock = ContinuousClock()
  let start = clock.now
  do {
      let dashboard = try await loadDashboard()
      print(dashboard)
  } catch {
      print("failed: \(error)")
  }
  print("under 250 ms: \(clock.now - start < .milliseconds(250))")
  ```

  ```output
  Ana: 3 unread, balance 250
  under 250 ms: true
  ```

  The three calls have different types, which is what `async let` handles well; a task group would need one shared result type. One `try await` covers the whole interpolated string. If any call throws, the error propagates and the other two children are cancelled and awaited when the function exits. Sequential awaits would take about 300 ms.
````

````exercise
id: m29-l02-e4
type: find-errors
prompt: "This code is meant to download all files and return their sizes in input order. Which are real problems?"
code: |
  func size(of file: String) async -> Int {
      try? await Task.sleep(for: .milliseconds(10))
      return file.count
  }

  func sizes(of files: [String]) async -> [Int] {
      var result: [Int] = []
      await withTaskGroup(of: Void.self) { group in
          for file in files {
              group.addTask {
                  result.append(await size(of: file))
              }
          }
      }
      return result
  }
choices:
  - text: "Children mutate the parent's local var result, which is a data race; Swift 6 rejects it."
    correct: true
    why: "Children run concurrently. Return values from the children and collect them in the parent's for await loop."
  - text: "Even if it compiled, sizes would be in completion order, not input order."
    correct: true
    why: "Results arrive as children finish. Return (index, size) pairs and place them by index."
  - text: "The group returns before the children finish, so result is empty."
    correct: false
    why: "A task group always waits for all of its children before returning."
  - text: "withTaskGroup can't be used with Void children."
    correct: false
    why: "Void children are allowed (withDiscardingTaskGroup is the better fit, but Void works)."
rubric:
  - Identifies the concurrent mutation of a captured var.
  - Identifies completion order versus input order.
  - Rejects the claim that the group doesn't wait.
solution: |
  Two problems. Children can't append to the parent's `var` (Swift 6.3: `passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure`), and even with a lock, appending as children finish loses the input order. Return an index with each result:

  ```swift
  func size(of file: String) async -> Int {
      try? await Task.sleep(for: .milliseconds(10 * file.count))
      return file.count
  }

  func sizes(of files: [String]) async -> [Int] {
      await withTaskGroup(of: (Int, Int).self) { group in
          for (index, file) in files.enumerated() {
              group.addTask { (index, await size(of: file)) }
          }
          var result = Array(repeating: 0, count: files.count)
          for await (index, size) in group {
              result[index] = size
          }
          return result
      }
  }

  print(await sizes(of: ["report.pdf", "a.txt", "photo.jpeg"]))
  ```

  ```output
  [10, 5, 10]
  ```

  The shortest name finishes first, but each size lands at its own index.
````

````exercise
id: m29-l02-e5
type: comprehension
prompt: "In a @MainActor view controller, `refresh()` runs `Task.detached { let items = await self.store.load(); self.tableView.reloadData() }`. What's the best description?"
choices:
  - text: "It doesn't compile as written: the detached closure isn't on the main actor, so touching tableView needs an await hop, and the task drops the caller's priority. Task { } (or a nonisolated loading function) is the better tool."
    correct: true
    why: "Detached tasks inherit no isolation. UI code from a detached task has to hop back explicitly, which is exactly what Task { } gives you for free."
  - text: "It's the recommended way to keep the main thread free while loading."
    correct: false
    why: "Apple recommends against detached tasks when structured or inherited tasks work. Keeping the main thread free is about where load() runs."
  - text: "It's equivalent to Task { } except that it runs sooner."
    correct: false
    why: "Detached differs in isolation, priority and task-locals, not in start time."
  - text: "The detached task is cancelled automatically when the view controller is deallocated."
    correct: false
    why: "No unstructured task is cancelled automatically. You cancel it through its handle."
solution: |
  `Task.detached` inherits no actor, so `self.tableView.reloadData()` (a main-actor method) can't be called synchronously from it; you'd need `await MainActor.run { … }`. It also drops the priority the user's tap gave the work. A `Task { }` inherits the main actor, so updating the table after the `await` is direct, and if `load()` is an actor method or a `@concurrent` function, the slow part still runs off the main actor.
````

````exercise
id: m29-l02-e6
type: explain
prompt: "Your colleague says: 'I set the image download task to .high and the analytics upload to .background, so the image always finishes first.' Explain what's right and wrong about that."
code: |
  let imageTask = Task(priority: .high) {
      await downloadImage()
  }
  let analyticsTask = Task(priority: .background) {
      await uploadAnalytics()
  }
rubric:
  - Priority is a scheduling hint that executors may use; it isn't a guarantee of completion order.
  - Completion depends on how long each piece of work takes (network, size), not only on scheduling.
  - Escalation can raise the background task's effective priority if a high-priority task awaits it.
  - If order matters, express it in code (await one before starting the other, or sequence dependencies).
solution: |
  The intent is right: urgent user-visible work should have higher priority, and maintenance work lower. The conclusion is wrong. Apple's `TaskPriority` documentation says executors "typically" run higher-priority tasks first and that the semantics are "left up to each platform and Executor implementation". Priority affects which ready task gets a thread first; it can't make a slow download finish before a fast upload, and an escalation (a higher-priority task awaiting the upload) can raise the upload's priority anyway. If one result must come before the other, write it: await the image before starting the upload, or make the upload depend on the image's task.
````

## Summary

- A task is a unit of async work; threads execute it. Suspended tasks hold no thread, so tasks are cheap. Tasks form a tree.
- `async let` starts a fixed number of child tasks that run while the parent continues; reading one needs `await` (`try await` if it throws). Un-awaited ones are cancelled and awaited at scope exit.
- Task groups (`withTaskGroup`, `withThrowingTaskGroup`) run any number of children of one result type. Results arrive in completion order, so return an id and collect, sort or index.
- A throwing group whose closure throws cancels the remaining children and waits for them. Keep a window of N children for large inputs.
- Children never outlive their scope: a group waits for all of them even if the body returns early.
- `Task { }` is unstructured but inherits isolation, priority and task-locals. `Task.detached` inherits nothing; Apple recommends against it when structure works.
- Priority is a hint, inherited by children, and escalates when a higher-priority task awaits a lower one. It never defines result order.
