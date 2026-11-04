---
id: m47-l04
title: Concurrency questions
description: "Concurrency questions past the first answer, each proved with a deterministic program: what Swift Concurrency gives you that queues don't, a reentrancy bug in an actor reproduced on demand, why a Sendable struct rejects a closure property, where a nonisolated async function runs when the main actor calls it, which tasks inherit cancellation, and how the compiler stops a data race in a task group."
module: m47
order: 4
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l03]
objectives:
  - Compare GCD and Swift Concurrency on lifetime, cancellation, isolation and blocking, and say where GCD still fits.
  - Reproduce an actor reentrancy bug deterministically and fix it by keeping the check and the update together.
  - Explain and fix Sendable diagnostics for closure properties and non-Sendable captures.
  - Say where a nonisolated async function runs when called from the main actor, with and without nonisolated(nonsending).
  - Predict which tasks see a parent's cancellation.
  - Explain how Swift 6 rejects a data race in a task group, and restructure the code so it doesn't need shared mutable state.
terms:
  - term: Reentrancy
    definition: "While an actor-isolated function is suspended at an await, the actor can run other calls. State checked before the await may have changed after it."
  - term: Suspension point
    definition: "An await where the current task may give up its thread. Other work, including other calls on the same actor, can run before it resumes."
  - term: Isolation domain
    definition: "Where a piece of code is allowed to touch state: a specific actor, a global actor such as the main actor, or nonisolated. Values crossing between domains must be Sendable or sent."
  - term: "#isolation"
    definition: "A macro that evaluates to the actor the current code is isolated to, as an `(any Actor)?`, or nil when it's nonisolated."
  - term: Structured task
    definition: "A child task created with async let or a task group. It can't outlive its scope, and it's cancelled when its parent is. Task { } and Task.detached { } are unstructured."
mastery:
  - Give a five-part answer to "GCD or Swift Concurrency?" that ends with where GCD still belongs.
  - Write a program that forces two actor calls to interleave at an await, and fix it.
  - Read a Sendable diagnostic and choose between @Sendable, a value type, copying before the crossing and an actor.
  - Predict the isolation printed by #isolation in main-actor, nonisolated and nonisolated(nonsending) functions.
  - Rewrite a task group that mutates a captured variable so each child returns its result instead.
resources: [swift-book-concurrency, swift-actor, swift-sendable, swift-mainactor, swift-task, swift-taskgroup, swift-migration-guide]
cards:
  - id: m47-l04-c1
    front: Name three things Swift Concurrency gives you that dispatch queues don't.
    back: "Child tasks can't outlive their scope (structured lifetime); cancellation propagates to children; the compiler checks isolation and Sendable at compile time. It also never needs more threads than the cooperative pool provides, as long as nothing blocks."
  - id: m47-l04-c2
    front: How do you make an actor method safe when it has to await in the middle?
    back: "Don't let a check before the await guard an update after it. Do the awaited work first and then check and update with no await in between, or reserve the change before the await and undo it if the awaited step fails."
  - id: m47-l04-c3
    front: "`struct RetryPolicy: Sendable { let onRetry: (Int) -> Void }` doesn't compile. Why, and what's the fix?"
    back: "A plain function type isn't Sendable, because the closure could capture mutable state. Declare it `@Sendable (Int) -> Void`, so every closure stored there is checked for safe captures."
  - id: m47-l04-c4
    front: "Called from @MainActor code, where does a plain `nonisolated func f() async` run in Swift 6.3's default mode?"
    back: "Off the main actor, on the generic executor (#isolation is nil). A `nonisolated(nonsending)` function runs on the caller's actor instead, and the NonisolatedNonsendingByDefault upcoming feature makes that the default."
  - id: m47-l04-c5
    front: A cancelled task creates an async let, a task group child, a Task { } and a Task.detached { }. Which see the cancellation?
    back: "The async let child and the task group child (structured). Task { } and Task.detached { } don't inherit cancellation."
---

## The idea in one sentence

Concurrency answers are only as good as the evidence behind them, and in Swift you can usually produce that evidence deterministically: force the interleaving you're talking about, or let the compiler show you the race it refuses to build.

> [!note] What this lesson builds on, and how its code was run
> Module 28 (threads, GCD, races and deadlocks) and Module 29 (async/await, tasks, cancellation, actors, Sendable, migration). The bank covers the first-level questions: thread versus task, data race versus race condition, what `await` does, actors, reentrancy with an image cache, `@MainActor`, `Sendable`, cancellation basics and GCD deadlocks. Everything below was compiled and run with Swift 6.3 on Linux, in the Swift 6 language mode with no extra flags. No output depends on timing or on which thread runs what: every interleaving the lesson talks about is forced, not hoped for. As in Modules 28 and 29, the `no-compile` examples use only types and closures they declare, so their diagnostics are errors on every platform.

## GCD or Swift Concurrency?

**The question:** "Your team still uses GCD everywhere. What do you gain by moving to Swift Concurrency, and where would you keep GCD?"

**Direct answer.** "Lifetime, cancellation and compile-time checking. Child tasks can't outlive the function that created them, cancelling a parent cancels its children, and the compiler rejects data races that GCD lets you write. I'd keep GCD at the edges: APIs that require a dispatch queue, and old code that works and isn't worth touching."

**Mechanism.** The comparison, with the module that covered each row:

| | GCD | Swift Concurrency |
| --- | --- | --- |
| Unit of work | A closure on a queue (Module 28, lesson 2) | A task; `async let` and groups create children (Module 29, lesson 2) |
| Lifetime | The closure runs whenever the queue gets to it; nothing ties it to the caller | A child task ends before its scope does |
| Cancellation | `DispatchWorkItem.cancel()` only before it starts; `Operation` has a flag you check (Module 28, lessons 2 and 4) | Cooperative, and propagates to child tasks (Module 29, lesson 3) |
| Protecting state | A serial queue or a lock, by convention (Module 28, lesson 6) | Actors and isolation, checked by the compiler (Module 29, lessons 4 and 5) |
| Blocking | Blocking a queue's thread makes GCD start more threads, up to a limit | The cooperative pool doesn't grow; blocking one of its threads starves other tasks |

**Example.** The cancellation row is the easiest to prove. A parent task is cancelled before it starts (a task created from top-level code can't start until that code reaches an `await`, Module 29, lesson 1), then creates one child of each kind:

```swift
let parent = Task {
    async let child: Bool = Task.isCancelled
    let unstructured = Task { Task.isCancelled }
    let detached = Task.detached { Task.isCancelled }
    let group = await withTaskGroup(of: Bool.self) { group in
        group.addTask { Task.isCancelled }
        return await group.next() ?? false
    }
    print("async let:", await child)
    print("task group:", group)
    print("Task {}:", await unstructured.value)
    print("Task.detached:", await detached.value)
}
parent.cancel()
await parent.value
```

```output
async let: true
task group: true
Task {}: false
Task.detached: false
```

Structured children inherit the cancellation. `Task { }` inherits the actor and priority but not cancellation, and `Task.detached { }` inherits nothing. That's the bank's cancellation answer made concrete, and it's the bug in "I cancelled the screen's task but the download kept going": the download was started with `Task { }` inside it.

**Trade-off.** Migration has a cost: wrapping callback APIs in continuations (Module 29, lesson 6), learning isolation, and a period where both models coexist. GCD's mental model is simpler for one-off "run this later on the main queue" code.

**When it breaks.** Mixing them carelessly: calling `DispatchSemaphore.wait()` or `DispatchGroup.wait()` inside an async function blocks a cooperative-pool thread. With few enough threads, the work that would signal the semaphore can't run, and the program stalls. The bank's question on priorities and executors goes deeper.

## Actors and reentrancy, reproduced

**The question:** "You said actors are reentrant. Show me the bug that causes, on demand, not as a race that happens sometimes."

**Direct answer.** "An actor method that checks state, awaits, and then updates based on the check. While it's suspended, another call can run and pass the same check. I can force the interleaving with a gate that holds the first call at its `await` until the second one arrives."

**Mechanism.** A suspended actor method doesn't hold the actor. Module 29, lesson 4 showed this with a nested call; here the interleaving comes from two independent tasks, and a `Gate` actor makes it deterministic: it suspends every caller until `count` of them have arrived, then releases them all.

```swift
/// Suspends every caller until `count` callers have arrived, then lets all of them continue.
actor Gate {
    private let count: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(count: Int) { self.count = count }

    func arrive() async {
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            if waiting.count == count {
                for waiter in waiting { waiter.resume() }
                waiting.removeAll()
            }
        }
    }
}

actor Wallet {
    private(set) var balance: Int
    private let fraudCheck: Gate

    init(balance: Int, fraudCheck: Gate) {
        self.balance = balance
        self.fraudCheck = fraudCheck
    }

    func withdraw(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        await fraudCheck.arrive()          // suspension point: the actor runs other calls here
        balance -= amount
        return true
    }
}

let wallet = Wallet(balance: 100, fraudCheck: Gate(count: 2))
async let first = wallet.withdraw(80)
async let second = wallet.withdraw(80)
let results = await [first, second]
print(results)
print("balance:", await wallet.balance)
```

```output
[true, true]
balance: -60
```

Whichever call runs first sees 100, passes the guard and suspends in the gate. The actor is free, so the second call runs, also sees 100 and arrives at the gate. Now both are released and both subtract 80. The gate stands in for any real `await`: a server-side fraud check, a Keychain read, a logging call. In production the bug needs two taps within the time of that call; here it happens every run.

**The fix.** Keep the check and the update together, with no `await` between them. Here the fraud check moves first:

```swift
actor Gate {
    private let count: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(count: Int) { self.count = count }

    func arrive() async {
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            if waiting.count == count {
                for waiter in waiting { waiter.resume() }
                waiting.removeAll()
            }
        }
    }
}

actor Wallet {
    private(set) var balance: Int
    private let fraudCheck: Gate

    init(balance: Int, fraudCheck: Gate) {
        self.balance = balance
        self.fraudCheck = fraudCheck
    }

    func withdraw(_ amount: Int) async -> Bool {
        await fraudCheck.arrive()
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}

let wallet = Wallet(balance: 100, fraudCheck: Gate(count: 2))
async let first = wallet.withdraw(80)
async let second = wallet.withdraw(80)
let results = await [first, second]
print("succeeded:", results.filter { $0 }.count)
print("balance:", await wallet.balance)
```

```output
succeeded: 1
balance: 20
```

Both calls still meet in the gate, but after they're released each one checks and subtracts without suspending, and the actor runs those parts one at a time. The program prints how many succeeded, not which, because which call wins depends on scheduling.

**Trade-off.** Sometimes the await can't move: you need the balance check to decide whether to call the fraud service at all. Then reserve before the await (subtract first) and give the amount back if the awaited step fails; exercise 5 does that. The bank's reentrancy question shows the third pattern, storing the in-flight `Task` so the second caller awaits the first one's work.

**When it breaks.** Every `await` inside an actor method is a place where invariants must hold. A method with three awaits has four regions where other calls can see intermediate state. Review actor code by asking, at each `await`, "what could another caller change here, and do I depend on it afterwards?"

## Sendable, beyond "it's thread-safe"

**The question:** "Why won't this compile? It's a struct, and structs are value types."

```swift no-compile stored property 'onRetry' of 'Sendable'-conforming struct 'RetryPolicy' has non-Sendable type '(Int) -> ()'
struct RetryPolicy: Sendable {
    let attempts: Int
    let onRetry: (Int) -> Void
}
```

**Direct answer.** "The struct is a value, but a closure isn't necessarily safe to share: it can capture a mutable variable or a class instance by reference. A plain function type isn't `Sendable`, so a `Sendable` struct can't store one. Declare it `@Sendable (Int) -> Void`."

**Mechanism.** `Sendable` is a promise that a value can be used from several isolation domains at once without a data race. A struct gets it if every stored property is `Sendable` (Module 29, lesson 5). `@Sendable` on a function type moves the check to every closure stored there: it can only capture `Sendable` values, and it can't capture mutable variables.

```swift
struct RetryPolicy: Sendable {
    let attempts: Int
    let onRetry: @Sendable (Int) -> Void
}

let policy = RetryPolicy(attempts: 3) { attempt in print("retry", attempt) }
let task = Task.detached { policy.onRetry(2) }
await task.value
```

```output
retry 2
```

**The same idea with a class.** A non-`Sendable` class instance can be handed over to another task only if nothing else can still reach it. A parameter can be reached by the caller, so this fails:

```swift no-compile closure captures 'draft' which is accessible to code in the current task
final class Draft {
    var text = ""
}

func save(_ draft: Draft) async {
    let detached = Task.detached {
        print(draft.text)
    }
    await detached.value
}
```

Swift 6.3 reports `passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure`, with the note quoted above. The fixes, in the order to consider them: copy what the task needs (`let text = draft.text`, then capture `text`), make the type a struct, make it an actor if it really is shared mutable state, or isolate both sides to the main actor. `@unchecked Sendable` with a lock is the last resort (Module 28, lesson 6), because the compiler stops checking.

**When it breaks.** Module 28 found that for closures passed straight to `DispatchQueue.async`, Xcode reports the same diagnostics as warnings, because Dispatch is imported `@preconcurrency` on Apple platforms. "It's only a warning" is the wrong conclusion: it describes the same crossing.

## The main actor and nonisolated async functions

**The question:** "A `@MainActor` view model awaits a `nonisolated` async function that parses a big file. Does the parsing run on the main thread?"

**Direct answer.** "In Swift 6.3's default mode, no: a nonisolated async function runs off the main actor, on the generic executor. With `nonisolated(nonsending)`, or with the `NonisolatedNonsendingByDefault` upcoming feature that Xcode's Approachable Concurrency setting turns on, it runs on the caller's actor, so it would parse on the main actor. `@concurrent` forces it off in either mode."

**Example.** `#isolation` reports the actor the current code is isolated to, which is more reliable than checking threads (Module 29, lesson 1 explains why):

```swift
func describe(_ isolation: (any Actor)?) -> String {
    guard let isolation else { return "nonisolated" }
    return "\(type(of: isolation))"
}

nonisolated func plainWork() async -> String {
    describe(#isolation)
}

nonisolated(nonsending) func callerWork() async -> String {
    describe(#isolation)
}

@MainActor
func refreshScreen() async {
    print("refreshScreen:", describe(#isolation))
    print("plainWork:", await plainWork())
    print("callerWork:", await callerWork())
}

await refreshScreen()
```

```output
refreshScreen: MainActor
plainWork: nonisolated
callerWork: MainActor
```

**Mechanism.** These rules come from SE-0338 (nonisolated async functions don't run on an actor's executor) and SE-0461 (Swift 6.2, which added `nonisolated(nonsending)` and `@concurrent` and the upcoming feature that changes the default). Module 29, lesson 6 covers the flags and versions.

**Trade-off.** Running on the caller's actor means non-`Sendable` arguments never cross a boundary, which removes a whole class of diagnostics. The cost is that heavy work no longer leaves the main actor by default, so you mark it `@concurrent` on purpose.

**When it breaks.** An answer that says "async functions run in the background" is wrong in both modes: `refreshScreen` is async and runs on the main actor. And a `@MainActor` function doesn't block the main thread while it awaits; the main actor runs other work until it resumes.

## Data races the compiler rejects

**The question:** "Count the even numbers concurrently with a task group. Why doesn't the obvious version compile?"

```swift no-compile closure captures reference to mutable var 'count'
func countEven(_ numbers: [Int]) async -> Int {
    var count = 0
    await withTaskGroup(of: Void.self) { group in
        for number in numbers {
            group.addTask {
                if number % 2 == 0 { count += 1 }
            }
        }
    }
    return count
}
```

**Direct answer.** "Every child task would increment the same variable at the same time, which is a data race. Swift 6 rejects it: `addTask` takes its closure as `sending`, and a closure that captures a local `var` by reference can't be sent while the caller can still touch that variable."

Swift 6.3's message is `passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure`, with the note `closure captures reference to mutable var 'count' which is accessible to code in the current task`.

**The fix.** Don't share the counter. Let each child return its result and combine them in the parent, which iterates the group one result at a time:

```swift
func countEven(_ numbers: [Int]) async -> Int {
    await withTaskGroup(of: Int.self) { group in
        for number in numbers {
            group.addTask { number % 2 == 0 ? 1 : 0 }
        }
        var count = 0
        for await result in group {
            count += result
        }
        return count
    }
}

print(await countEven(Array(1...10)))
```

```output
5
```

**Trade-off.** One child task per number is far too fine-grained for real work; the overhead of creating tasks dwarfs a modulo. Chunk the input so each child does meaningful work. An actor counter would also compile, but every increment would be an actor hop, which is more expensive than returning values.

**When it breaks.** The compiler catches data races in code it can see. It trusts `@unchecked Sendable`, `nonisolated(unsafe)` and C code. Thread Sanitizer finds races at run time in those places (Module 28, lesson 6), and race conditions that aren't data races, like the wallet above, are caught by neither: that's what design and tests are for.

## Exercises

````exercise
id: m47-l04-e1
type: prediction
prompt: "A cancelled parent creates two children. What does the program print?"
code: |
  let parent = Task {
      let inherited = await withTaskGroup(of: Bool.self) { group in
          group.addTask { Task.isCancelled }
          return await group.next() ?? false
      }
      let fresh = Task { Task.isCancelled }
      print("group child:", inherited)
      print("Task {}:", await fresh.value)
      print("parent:", Task.isCancelled)
  }
  parent.cancel()
  await parent.value
output: |
  group child: true
  Task {}: false
  parent: true
solution: |
  The parent is cancelled before it starts running. The group's child is structured, so it inherits the cancellation. `Task { }` is unstructured: it inherits the actor context and priority but not cancellation. The parent itself stays cancelled; cancellation is a flag, and nothing in the parent checked it and stopped.

  ```output
  group child: true
  Task {}: false
  parent: true
  ```
````

````exercise
id: m47-l04-e2
type: prediction
prompt: "Where does each function run? Predict what `#isolation` reports."
code: |
  func describe(_ isolation: (any Actor)?) -> String {
      guard let isolation else { return "nonisolated" }
      return "\(type(of: isolation))"
  }

  actor Store {
      func load() async -> String {
          "load: " + describe(#isolation) + ", " + (await helper())
      }

      nonisolated func helper() async -> String {
          "helper: " + describe(#isolation)
      }
  }

  @MainActor
  func start() async {
      print("start: " + describe(#isolation))
      print(await Store().load())
  }

  await start()
output: |
  start: MainActor
  load: Store, helper: nonisolated
solution: |
  `start()` is `@MainActor`. `load()` is isolated to the `Store` actor, so `#isolation` is that actor and `type(of:)` prints `Store`. `helper()` is a nonisolated async method; in Swift 6.3's default mode it runs on the generic executor even when called from inside the actor.

  ```output
  start: MainActor
  load: Store, helper: nonisolated
  ```

  With `nonisolated(nonsending)` on `helper()`, it would report `Store`, its caller's actor.
````

````exercise
id: m47-l04-e3
type: comprehension
multiple: true
prompt: "Which statements are true? Select all that apply."
choices:
  - text: "An actor guarantees that a method's state is unchanged between its first line and its last line."
    correct: false
    why: "Only between suspension points. At each await, other calls can run."
  - text: "Calling DispatchSemaphore.wait() inside an async function can stall the program, because it blocks a thread of the cooperative pool."
    correct: true
    why: "The pool doesn't grow to compensate. The task that would signal may never get a thread."
  - text: "A struct is Sendable as long as it has no var properties."
    correct: false
    why: "Every stored property must be Sendable. A let holding a class instance or a plain closure fails."
  - text: "A @MainActor async function blocks the main thread while it awaits a network call."
    correct: false
    why: "It suspends; the main actor runs other work until it resumes."
  - text: "Swift 6 catches data races at compile time, but not race conditions like check-then-act across an await."
    correct: true
    why: "Data isolation prevents simultaneous unsynchronized access; it can't know your invariants."
solution: |
  True: the second and fifth. An actor only serializes the code between suspension points; a Sendable struct needs Sendable stored properties, not just `let`s; awaiting on the main actor suspends without blocking.
````

````exercise
id: m47-l04-e4
type: find-errors
prompt: "This actor caches user profiles. Which statements describe real problems?"
code: |
  actor ProfileCache {
      private var profiles: [String: String] = [:]
      private var requests = 0

      func profile(for id: String, fetch: @Sendable (String) async -> String) async -> String {
          if let cached = profiles[id] { return cached }      // line A
          requests += 1
          let profile = await fetch(id)                      // line B
          profiles[id] = profile                             // line C
          return profile
      }

      func reset() {
          profiles.removeAll()
          requests = 0
      }
  }
choices:
  - text: "Two concurrent calls for the same id can both miss the cache at line A and both fetch, because the actor runs the second call while the first is suspended at line B."
    correct: true
    why: "Classic reentrancy: the check at A doesn't hold across the await at B."
  - text: "A reset() during the await at line B can be undone: line C writes the profile back after the cache was cleared."
    correct: true
    why: "Another invariant that doesn't hold across a suspension point."
  - text: "Line C is a data race, because profiles is mutated after an await."
    correct: false
    why: "After resuming, the method is back on the actor. It's a logic problem, not a data race."
  - text: "Marking the fetch parameter @Sendable makes it impossible to call from inside the actor."
    correct: false
    why: "A @Sendable closure can be called from any isolation domain. It restricts what the closure captures, not where it's called."
rubric:
  - Identifies duplicate fetches from reentrancy.
  - Identifies the reset race.
  - Doesn't call line C a data race.
solution: |
  The first two are real, and they're the same lesson: nothing checked before line B can be trusted after it. Fixes: store the in-flight `Task` in the dictionary before awaiting (the bank's reentrancy answer), and give the cache a generation number that `reset()` increments, so a fetch that started before a reset doesn't write its result back.
````

````exercise
id: m47-l04-e5
type: solve
prompt: "The fraud check needs to know the amount, so it can't move before the balance check. Rewrite `withdraw` so it reserves the amount before awaiting and gives it back if the check rejects it. Use the `Gate` from the lesson to force both calls to be suspended at the same time, and a check that rejects amounts over 90. Run two withdrawals of 80 from a balance of 100 and print how many succeeded and the final balance."
starter: |
  actor Wallet {
      private(set) var balance: Int
      // init and withdraw(_:)
  }
rubric:
  - The balance check and the deduction happen with no await between them.
  - The awaited check happens after the deduction, and a rejection restores the amount.
  - The output doesn't depend on which call wins.
  - The balance never goes negative.
solution: |
  ```swift
  actor Gate {
      private let count: Int
      private var waiting: [CheckedContinuation<Void, Never>] = []

      init(count: Int) { self.count = count }

      func arrive() async {
          await withCheckedContinuation { continuation in
              waiting.append(continuation)
              if waiting.count == count {
                  for waiter in waiting { waiter.resume() }
                  waiting.removeAll()
              }
          }
      }
  }

  actor Wallet {
      private(set) var balance: Int
      private let gate: Gate

      init(balance: Int, gate: Gate) {
          self.balance = balance
          self.gate = gate
      }

      private func fraudCheckApproves(_ amount: Int) async -> Bool {
          await gate.arrive()
          return amount <= 90
      }

      func withdraw(_ amount: Int) async -> Bool {
          guard balance >= amount else {
              await gate.arrive()          // keep the gate's count honest for this demo
              return false
          }
          balance -= amount                // reserve before suspending
          if await fraudCheckApproves(amount) {
              return true
          }
          balance += amount                // give it back
          return false
      }
  }

  let wallet = Wallet(balance: 100, gate: Gate(count: 2))
  async let first = wallet.withdraw(80)
  async let second = wallet.withdraw(80)
  let results = await [first, second]
  print("succeeded:", results.filter { $0 }.count)
  print("balance:", await wallet.balance)
  ```

  ```output
  succeeded: 1
  balance: 20
  ```

  The first call reserves 80 (balance 20) and suspends. The second call sees 20, fails the guard, and arrives at the gate only so the demo's gate opens; in real code it would just return. When the check approves, the first call keeps the reservation. If the check rejected it, the `balance += amount` line would restore the money. The balance is never negative, at any instant, whichever call runs first.
````

````exercise
id: m47-l04-e6
type: explain
prompt: "A candidate says: \"I mark the class @unchecked Sendable and protect its dictionary with a lock, so it's as safe as an actor and faster.\" Respond as the interviewer would want: what's right, what's wrong, and when you'd accept it."
code: |
  final class TokenStore: @unchecked Sendable {
      private let lock = NSLock()
      private var tokens: [String: String] = [:]

      func token(for user: String) -> String? {
          lock.lock(); defer { lock.unlock() }
          return tokens[user]
      }

      func setToken(_ token: String, for user: String) {
          lock.lock(); defer { lock.unlock() }
          tokens[user] = token
      }
  }
rubric:
  - Acknowledges that every access is under the lock, so there's no data race as written, and that synchronous access avoids an await.
  - "Points out that @unchecked turns off the compiler's checking: a future property added without the lock compiles silently."
  - Notes that the lock doesn't prevent race conditions across two calls (get-then-set from two callers).
  - "Says when it's reasonable: synchronous APIs that can't become async, hot paths measured to matter, or code that must run on older systems; and mentions Mutex (iOS 18+) as a checked alternative."
solution: |
  As written, every read and write is under the lock, so there's no data race, and callers don't need `await`, which matters for synchronous APIs. What's wrong is "as safe as an actor": `@unchecked Sendable` tells the compiler to stop checking, so the next person who adds `var lastRefresh: Date` without the lock ships a data race with no warning. And the lock only protects each call: "read the token, refresh if missing, write it" from two callers is still a race condition, exactly like the wallet, unless the whole sequence is one locked method.

  I'd accept it for a small, synchronous utility that's measured to be hot or that can't be async, with a comment explaining why. On iOS 18 and later, `Mutex` from the Synchronization module is better: a class whose state lives only in a `Mutex` can be plain `Sendable`, and the compiler keeps checking (Module 28, lesson 6). "Faster" needs a measurement; an uncontended actor hop is cheap, and the lesson's point in lesson 1 applies: say faster than what, measured how.
````

## Summary

- Swift Concurrency adds structured lifetime, cancellation that propagates to `async let` and task group children (not to `Task { }` or `Task.detached { }`), and compile-time isolation. Keep GCD at the edges, and never block a cooperative-pool thread with a semaphore or `wait()`.
- Actor reentrancy is reproducible: force two calls to suspend at the same `await` and both pass a stale check. Keep the check and the update together, or reserve before awaiting and undo on failure.
- A `Sendable` struct can't store a plain closure; use `@Sendable`. A non-`Sendable` class can't be captured by a task while the caller can still reach it; copy what you need, use a value type, or use an actor.
- In Swift 6.3's default mode a nonisolated async function runs off the caller's actor; `nonisolated(nonsending)` (SE-0461) runs it on the caller's actor, and `@concurrent` forces it off. `#isolation` shows which.
- Swift 6 rejects a task group whose children mutate a captured `var`. Have children return values and combine them in the parent. The compiler can't see race conditions or code it was told to trust.
