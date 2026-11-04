---
id: m28-l06
title: Race conditions and deadlocks
description: "The two ways shared state goes wrong with threads: corrupted by accesses that overlap, or stuck because everyone is waiting. You separate data races from race conditions, watch Swift 6 flag data races at compile time (as errors, or as warnings for closures passed straight to Dispatch in Xcode), protect state with a serial queue or a lock and keep the promise @unchecked Sendable makes, trace the sync-on-the-current-queue and lock-ordering deadlocks, meet priority inversion, and learn what Thread Sanitizer checks for."
module: m28
order: 6
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l05]
objectives:
  - Define a data race and a race condition and tell them apart in code.
  - Read the Swift 6 diagnostics for captured vars, non-Sendable captures, mutable global state and mutable Sendable classes, and know why Xcode shows some of them as warnings.
  - Protect mutable state with a serial queue or a lock, and make check-then-act operations atomic.
  - Explain what @unchecked Sendable promises and when the promise holds.
  - Trace a sync-on-the-current-queue deadlock and a lock-ordering deadlock, and fix each.
  - Describe priority inversion and what Thread Sanitizer detects.
terms:
  - term: Data race
    definition: "Two threads access the same memory at the same time without synchronization, and at least one access is a write. The result is undefined behavior: anything can happen, including nothing visible."
  - term: Race condition
    definition: "A bug where the result depends on the timing or order of operations, even if every single access is synchronized. Check-then-act on shared state is the classic one."
  - term: Critical section
    definition: "Code that must run on one thread at a time because it reads or changes shared state. A lock or a serial queue guards it."
  - term: Deadlock
    definition: "Two or more threads each waiting for something only another of them can provide, so none ever continues."
  - term: Priority inversion
    definition: "High-priority work waiting on something held by low-priority work, which in turn can't run because medium-priority work keeps the CPU busy."
  - term: "@unchecked Sendable"
    definition: "A conformance that tells the compiler to stop checking a type for thread safety. It's your promise that you synchronize all access to its mutable state yourself."
  - term: Thread Sanitizer (TSan)
    definition: "A runtime tool in Xcode that records memory accesses from each thread and reports accesses to the same memory from different threads without synchronization."
mastery:
  - Classify a bug as a data race, a race condition, or both.
  - Turn a class that Swift 6 rejects as Sendable into one guarded by a lock or a serial queue, and say what makes @unchecked honest.
  - Rewrite a check-then-act pair as one atomic method and show the counts are right under concurrency.
  - Explain why queue.sync from inside a block on the same serial queue never returns.
  - Fix a lock-ordering deadlock by imposing one order.
  - Turn on Thread Sanitizer and say where it can't run.
resources: [foundation-nslock, os-allocated-unfair-lock, synchronization-mutex, xcode-data-races, understanding-hangs]
cards:
  - id: m28-l06-c1
    front: Data race vs race condition?
    back: "Data race: unsynchronized simultaneous access to the same memory with at least one write; undefined behavior, and what Swift 6 flags at compile time. Race condition: a logic bug where the outcome depends on timing, possible even when every access is locked (check-then-act)."
  - id: m28-l06-c2
    front: What does @unchecked Sendable promise?
    back: "That you synchronize every access to the type's mutable state yourself (a lock, a serial queue). The compiler stops checking; if you break the promise, you get data races that Swift 6 was supposed to prevent."
  - id: m28-l06-c3
    front: Why does queue.sync inside a block running on the same serial queue deadlock?
    back: "sync waits for the new block to finish. The serial queue can't start it until the current block ends, and the current block is the one waiting. Apple: calling sync targeting the current queue \"results in deadlock\"."
  - id: m28-l06-c4
    front: How do you prevent lock-ordering deadlocks?
    back: "Always take multiple locks in the same global order, or never hold one lock while taking another (copy what you need, release, then lock the next)."
  - id: m28-l06-c5
    front: Where can Thread Sanitizer run?
    back: "On 64-bit macOS apps and on iOS (and other) apps in the Simulator, not on a device. Enable it in the scheme's Run > Diagnostics. Expect 2x to 20x slowdown and 5x to 10x memory."
---

## The idea in one sentence

Threads share memory, so you have to decide who may touch which data when: get it wrong one way and accesses overlap (races), get it wrong the other way and everyone waits for everyone else (deadlocks).

> [!note] Sources and what was run
> Thread Sanitizer details come from Apple's articles "Diagnosing memory, thread, and crash issues early" and "Data races"; lock behavior from the `NSLock` and `OSAllocatedUnfairLock` references; deadlock rules from `DispatchQueue` and `sync(execute:)`, all read November 2026. Plain-Swift blocks were compiled and run with Swift 6.3 on Linux, and the compiler diagnostics quoted are the ones it printed there. Racy programs aren't run here: a data race is undefined behavior, so a run that "looks fine" proves nothing. The deadlock blocks are marked as not run, because a deadlocked program never finishes.

## Data races and race conditions

These sound alike and are different problems.

A **data race** is a memory-level problem. Apple's definition, from the Thread Sanitizer documentation: "multiple threads access the same memory without synchronization, and at least one access is a write." `count += 1` is a read, an add and a write; two threads interleaving those steps can lose an update, but in Swift it's worse than a wrong number: the behavior is undefined. A data race on a `Dictionary` or `Array` can corrupt its storage and crash somewhere else entirely.

A **race condition** is a logic-level problem: the outcome depends on the order things happen in. It can exist with no data race at all, when every individual access is properly locked but the sequence of them isn't. You'll see one below with a bank account.

Fixing data races is necessary but not sufficient. Swift 6 helps with the first; only design fixes the second.

## Swift 6 flags data races at compile time

In Swift 6 language mode, the compiler checks every closure that can run on another thread (`@Sendable` closures) and every piece of global state. The racy versions of this module's examples are rejected, with one Xcode caveat:

> [!warning] In Xcode, Dispatch closures give warnings, not errors
> The examples below pass the closure to a small helper, `runInBackground`, whose parameter **this lesson** declares `@Sendable`. Swift 6 checks a closure parameter you declare yourself strictly, so these are errors everywhere. If you pass the same closure straight to `DispatchQueue.global().async { … }`, the result depends on the platform: Swift 6.3 on Linux reports errors, but on macOS (Xcode 26.6, Swift 6.3.3, Swift 6 language mode) the same three diagnostics appear as **warnings** and the program builds and runs. The likely reason is that Dispatch is imported as `@preconcurrency` on Apple platforms, which downgrades these Sendable diagnostics; this lesson didn't verify the mechanism, only the behavior. The warnings still describe real data races. Treat every one of them as an error: fix it, don't ship it.

Mutating a local variable from concurrent closures:

```swift no-compile mutation of captured var 'finished' in concurrently-executing code
import Dispatch

func runInBackground(_ work: @escaping @Sendable () -> Void) {
    DispatchQueue.global().async(execute: work)
}

func countDownloads() {
    var finished = 0
    for _ in 1...3 {
        runInBackground {
            finished += 1
        }
    }
}

countDownloads()
```

Swift 6.3: `error: mutation of captured var 'finished' in concurrently-executing code`. Three closures on a concurrent queue could increment it at the same time. (With `DispatchQueue.global().async` directly, Xcode shows the same text as a warning.)

Mutable global or static state that any thread can reach:

```swift no-compile static property 'downloads' is not concurrency-safe because it is nonisolated global shared mutable state
import Dispatch

enum Stats {
    static var downloads = 0
}

func recordDownload() {
    DispatchQueue.global().async {
        Stats.downloads += 1
    }
}

recordDownload()
```

Swift 6.3: `error: static property 'downloads' is not concurrency-safe because it is nonisolated global shared mutable state`, with three notes: make it a `let`, put it on the main actor with `@MainActor`, or "disable concurrency-safety checks if accesses are protected by an external synchronization mechanism" (that's `nonisolated(unsafe)`, the same kind of promise as `@unchecked` below).

Sharing a class instance that isn't `Sendable`:

```swift no-compile capture of 'cache' with non-Sendable type 'Cache' in a '@Sendable' closure
import Dispatch

final class Cache {
    var items: [String: Int] = [:]
}

func runInBackground(_ work: @escaping @Sendable () -> Void) {
    DispatchQueue.global().async(execute: work)
}

func fill(_ cache: Cache) {
    runInBackground {
        cache.items["a"] = 1
    }
}

fill(Cache())
```

Swift 6.3: `error: capture of 'cache' with non-Sendable type 'Cache' in a '@Sendable' closure`, with the note `class 'Cache' does not conform to the 'Sendable' protocol`. Again, Xcode shows it as a warning when the closure goes straight to `DispatchQueue.async`.

And you can't just declare it `Sendable` while it has unprotected mutable state:

```swift no-compile stored property 'balance' of 'Sendable'-conforming class 'Account' is mutable
import Foundation

final class Account: Sendable {
    private let lock = NSLock()
    private var balance = 0
}
```

Swift 6.3: `error: stored property 'balance' of 'Sendable'-conforming class 'Account' is mutable`. The compiler can't see that the lock protects `balance`; it only sees a `var` that several threads could reach.

These diagnostics are the compiler doing what Thread Sanitizer does at runtime, but before you ship. That's why a Sendable warning in Xcode deserves the same attention as an error. The next sections are how to satisfy it **honestly**.

## Protecting state: a serial queue or a lock

There are two classic ways to make a class safe to share. Both make every access to the mutable state go through one door, one thread at a time.

**A serial queue** (lessons 2 and 3): all reads and writes run as closures on one private serial queue.

**A lock**: a thread calls `lock()` before touching the state and `unlock()` after. Another thread calling `lock()` meanwhile waits. `NSLock` is Foundation's, available on every platform Swift runs on:

```swift
import Foundation

final class DownloadCounter: @unchecked Sendable {
    // `finished` is only read or written while holding `lock`.
    private let lock = NSLock()
    private var finished = 0

    func recordFinished() {
        lock.lock()
        defer { lock.unlock() }
        finished += 1
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }
}

func simulateDownloads() {
    let counter = DownloadCounter()
    DispatchQueue.concurrentPerform(iterations: 1_000) { _ in
        counter.recordFinished()
    }
    print("finished: \(counter.count)")
}

simulateDownloads()
```

```output
finished: 1000
```

1. `private let lock = NSLock()` and `private var finished`: the state and its guard live together, both private, so no code outside the class can touch `finished` without the lock.
2. `lock.lock()` then `defer { lock.unlock() }`: the `defer` guarantees the unlock on every path out, including early returns and thrown errors. A missing `unlock()` is a deadlock waiting for the next caller.
3. Reads take the lock too. Reading while another thread writes is also a data race.
4. 1,000 concurrent increments, 1,000 counted, every run. The number isn't the proof, though; the design is: every access is inside the lock.

Two rules from Apple's `NSLock` documentation: unlock from the same thread that locked ("Unlocking a lock from a different thread can result in undefined behavior"), and don't lock twice on one thread: "Calling the `lock` method twice on the same thread will lock up your thread permanently."

### What @unchecked Sendable promises

`final class DownloadCounter: @unchecked Sendable` tells the compiler: "don't check this class; I promise it's safe to use from any thread." The compiler believes you completely. This compiles just as happily:

```swift illustrative
final class BrokenCounter: @unchecked Sendable {
    private var finished = 0          // no lock, no queue
    func recordFinished() { finished += 1 }
}
```

and it's exactly the data race Swift 6 was protecting you from. So `@unchecked Sendable` is only honest when all of these hold:

- the class is `final` (a subclass could add unprotected state);
- every mutable stored property is `private`;
- every access to it, read or write, happens inside the lock or on the queue;
- immutable properties are `let` and themselves `Sendable`.

Write a comment next to the state saying what guards it, like the examples do. Reviewers, and you in six months, need to know which promise to check.

### Other locks on Apple platforms

Two newer locks keep the state **inside** the lock, so you can't touch it without locking:

- `OSAllocatedUnfairLock` (the `os` module, iOS 16 and later). Apple recommends it over the raw `os_unfair_lock`, which "is unsafe to use from Swift because it's a value type". It isn't available on Linux.
- `Mutex` (the `Synchronization` module, iOS 18 and later). It's part of the Swift standard library's distribution, so it also exists on Linux. Because `Mutex` itself is `Sendable`, a class that holds its state only in a `Mutex` can be plain `Sendable`, with no `@unchecked` promise for the compiler to trust.

```swift ios 18.0
import os
import Synchronization

final class UnfairCounter: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: 0)

    func increment() {
        state.withLock { $0 += 1 }
    }

    var value: Int {
        state.withLock { $0 }
    }
}

final class MutexCounter: Sendable {
    private let state = Mutex(0)

    func increment() {
        state.withLock { $0 += 1 }
    }

    var value: Int {
        state.withLock { $0 }
    }
}
```

`withLock` passes the protected value into the closure as `inout`, locks around it and returns what the closure returns. (This block is type-checked against the iOS 18 SDK, not run; the `Mutex` version was also compiled and run on Linux.) `NSLock` stays the portable choice for code that must run on older systems; this module's tested examples use it for that reason.

## Race conditions survive locking

Here's an account where every method is properly locked:

```swift
import Foundation

final class Account: @unchecked Sendable {
    // `balance` is only accessed while holding `lock`.
    private let lock = NSLock()
    private var balance: Int

    init(balance: Int) {
        self.balance = balance
    }

    var currentBalance: Int {
        lock.lock()
        defer { lock.unlock() }
        return balance
    }

    func withdraw(_ amount: Int) {
        lock.lock()
        defer { lock.unlock() }
        balance -= amount
    }
}

let account = Account(balance: 100)

// One unlucky interleaving of two threads, replayed step by step:
let threadACanPay = account.currentBalance >= 80   // A checks: 100
let threadBCanPay = account.currentBalance >= 80   // B checks: still 100
if threadACanPay { account.withdraw(80) }           // A withdraws
if threadBCanPay { account.withdraw(80) }           // B withdraws
print("balance: \(account.currentBalance)")
```

```output
balance: -60
```

No data race: each read and each write holds the lock. The bug is that "check" and "act" are two separate critical sections, and another thread can act between them. With real threads this interleaving happens rarely, which makes it worse: it passes every test and shows up in production. (The block replays it on one thread so the output is fixed.)

The fix is to make the check and the act **one** critical section:

```swift
import Foundation

final class Account: @unchecked Sendable {
    // `balance` is only accessed while holding `lock`.
    private let lock = NSLock()
    private var balance: Int

    init(balance: Int) {
        self.balance = balance
    }

    /// Withdraws only if the balance covers it. Check and withdrawal are atomic.
    func withdrawIfPossible(_ amount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    var currentBalance: Int {
        lock.lock()
        defer { lock.unlock() }
        return balance
    }
}

final class Tally: @unchecked Sendable {
    private let lock = NSLock()
    private var approved = 0

    func add() {
        lock.lock()
        defer { lock.unlock() }
        approved += 1
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return approved
    }
}

func runPayments() {
    let account = Account(balance: 100)
    let approved = Tally()
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
        if account.withdrawIfPossible(30) {
            approved.add()
        }
    }
    print("approved: \(approved.value), balance: \(account.currentBalance)")
}

runPayments()
```

```output
approved: 3, balance: 10
```

Ten simultaneous attempts to take 30 from 100: exactly three succeed and the balance never goes negative, on every run, because no thread can slip in between the `guard` and the subtraction. The general rule: an API that's thread-safe method by method can still be used unsafely; design methods around the **operations** callers need ("withdraw if possible", "insert if absent"), not around getters and setters.

## Deadlocks

A deadlock is the opposite failure: nothing is corrupted, nothing moves. Each thread waits for something only another waiting thread can give.

### sync on the queue you're already on

Apple's documentation for `sync(execute:)`: "Calling this function and targeting the current queue results in deadlock."

```swift illustrative
// Not run: it never finishes normally.
let queue = DispatchQueue(label: "com.example.serial")

queue.sync {
    print("outer block")
    queue.sync {            // waits for the inner block...
        print("inner block")
    }                       // ...which can't start until the outer block ends
}
print("never printed")
```

Trace it:

1. The outer block is running on `queue`, a serial queue.
2. The inner `sync` submits a block to `queue` and waits for it to finish.
3. The serial queue won't start the inner block until the current one, the outer block, finishes.
4. The outer block won't finish until the inner `sync` returns. Neither can move.

libdispatch can detect this exact case, because the waiting thread is the one that owns the queue. Running this with Swift 6.3 on Linux printed `outer block` and then the program crashed with an illegal-instruction signal inside libdispatch's `__DISPATCH_WAIT_FOR_QUEUE__` instead of hanging. libdispatch on Apple platforms has the same check, though this lesson didn't run it there. Don't rely on detection either way: the same mistake through layers of code, or across two threads, simply hangs. The usual real-world shape is a method that does `queue.sync { … }` being called from another method that's already running on `queue`.

The fixes:

- Know which queue each method runs on. A private method meant to be called only from inside the queue shouldn't `sync` again; document that it assumes it's already on the queue.
- Never `DispatchQueue.main.sync` from code that might be on the main thread (lesson 2).
- If a method can be called from both inside and outside the queue, split it: a public method that does `queue.sync { unsafeWork() }` and a private `unsafeWork()` that never syncs.

### Lock ordering

Two threads, two locks, opposite order:

```swift illustrative
// Not run: it hangs when the timing is unlucky.
// Thread 1: transfer from checking to savings
checking.lock.lock()
savings.lock.lock()      // waits for thread 2 to release savings

// Thread 2, at the same time: transfer from savings to checking
savings.lock.lock()
checking.lock.lock()     // waits for thread 1 to release checking
```

Each thread holds one lock and waits forever for the other. It only happens when both threads get their first lock before either gets its second, so it can survive months of testing.

Fixes, in order of preference:

1. **Don't hold two locks at once.** Copy what you need out of the first critical section, release it, then take the second.
2. **One global order.** If you must hold both, always take them in the same order everywhere, for example by account id: lower id first. Then a cycle can't form.
3. Make one object own both pieces of state behind one lock or one serial queue.

The same cycle can form with queues instead of locks: code on queue A does `B.sync`, while code on queue B does `A.sync`. The fixes are the same.

### Priority inversion

QoS (lesson 2) decides which work gets the CPU first. **Priority inversion** is when high-priority work waits on something held by low-priority work: a `.userInitiated` load waits for a lock held by a `.background` cleanup, and the cleanup barely gets CPU time because `.utility` work keeps the cores busy. The user waits on the least important work in the app.

Ways to stay out of it:

- Keep critical sections short, so a lock is never held for long by anyone.
- Don't make high-QoS work wait (`sync`, `semaphore.wait()`, `group.wait()`) for work you started at a lower QoS.
- Prefer locks and serial queues for mutual exclusion over semaphores: a semaphore has no owner, so the system can't tell whose work to speed up.

## Finding races at runtime: Thread Sanitizer

The Swift 6 compiler catches data races in code it can check. It can't see through `@unchecked Sendable`, `nonisolated(unsafe)`, C and Objective-C code, or races inside libraries. For those, Xcode has **Thread Sanitizer** (TSan). From Apple's "Diagnosing memory, thread, and crash issues early":

- **What it does:** it "inserts diagnostics into your code to record each memory read or write operation", with a timestamp and location, and "reports any operations that occur at the same location at approximately the same time." It "also detects other thread-related bugs, such as uninitialized mutexes and thread leaks."
- **How to turn it on:** in the scheme editor, Run action, Diagnostics section, select Thread Sanitizer. For tests, set it in the test plan's configuration. From the command line: `-sanitize=thread` for `swiftc`, `-enableThreadSanitizer YES` for `xcodebuild`.
- **Where it runs:** "Use Thread Sanitizer only on your 64-bit macOS app, or to diagnose your 64-bit iOS, iPadOS, tvOS, visionOS, and watchOS app running in Simulator." Not on a device.
- **What it costs:** memory use goes up "by five to ten times" and the app runs "2x to 20x" slower.

TSan only reports races that actually happen during the run, so it's as good as the code paths you exercise: run your unit tests with it enabled, not just the happy path by hand. The same article describes the **Main Thread Checker**, which "verifies that system APIs that must run on the main thread actually do run on that thread".

## Common mistakes

> [!error] Protecting writes but not reads
> A read that overlaps a write is a data race too. Every access to the state goes through the lock or the queue.

> [!error] Making a class @unchecked Sendable to silence the compiler
> If the class has no lock or queue, you've turned a compile error into undefined behavior. Use `@unchecked` only after the synchronization exists, and write down what guards what.

> [!error] Thread-safe getters and setters, unsafe callers
> `if cache.value(for: key) == nil { cache.set(…, for: key) }` is a race condition even with a perfect lock inside. Add an atomic `insertIfAbsent`.

> [!error] queue.sync from code that may already be on that queue
> It deadlocks (or crashes when libdispatch notices). Keep track of which queue each method assumes, and don't re-enter with `sync`.

> [!error] Taking two locks in different orders in different places
> It deadlocks under unlucky timing. Hold one lock at a time, or one global order.

> [!error] Trusting "it ran fine 1,000 times"
> A data race is undefined behavior; a clean run proves nothing. Let the compiler check it, and run your tests under Thread Sanitizer for what the compiler can't see.

## Exercises

````exercise
id: m28-l06-e1
type: comprehension
multiple: true
prompt: "A ticket service keeps `remaining` behind an NSLock: `remaining()` and `sell()` each lock, read or decrement, and unlock. Two threads run `if service.remaining() > 0 { service.sell() }` at the same time with one ticket left. Which statements are true? Select all that apply."
choices:
  - text: "There's no data race: every access to the count holds the lock."
    correct: true
    why: "Each read and each write is inside the lock, so no two accesses overlap."
  - text: "There's a race condition: both threads can see 1 before either sells, and the count reaches -1."
    correct: true
    why: "The check and the sale are separate critical sections. The order of operations decides the outcome."
  - text: "Swift 6 rejects this code at compile time."
    correct: false
    why: "The compiler checks for data races, and there aren't any. A logic race is invisible to it."
  - text: "Adding a sellIfAvailable() that checks and decrements under one lock fixes it."
    correct: true
    why: "That makes check-then-act one atomic operation."
solution: |
  No data race (every access holds the lock), but a race condition: check and act are two critical sections, so both threads can pass the check. The compiler can't see logic races; Thread Sanitizer won't report it either, because no memory access is unsynchronized. The fix is an operation-level method, `sellIfAvailable() -> Bool`, that checks and decrements under one lock.
````

````exercise
id: m28-l06-e2
type: prediction
prompt: "A shopping cart guarded by a serial queue is filled from 50 concurrent iterations. What does the program print?"
code: |
  import Dispatch

  final class Cart: @unchecked Sendable {
      // `items` is only touched on `queue`.
      private let queue = DispatchQueue(label: "com.example.cart")
      private var items: [String: Int] = [:]

      func add(_ product: String) {
          queue.sync { items[product, default: 0] += 1 }
      }

      func quantity(of product: String) -> Int {
          queue.sync { items[product] ?? 0 }
      }
  }

  func run() {
      let cart = Cart()
      DispatchQueue.concurrentPerform(iterations: 50) { index in
          cart.add(index.isMultiple(of: 5) ? "apple" : "pear")
      }
      print("apples: \(cart.quantity(of: "apple"))")
      print("pears: \(cart.quantity(of: "pear"))")
  }

  run()
output: |
  apples: 10
  pears: 40
hints:
  - "Every add runs on the serial queue, so no update is lost."
  - "How many numbers from 0 to 49 are multiples of 5?"
solution: |
  ```output
  apples: 10
  pears: 40
  ```

  The 50 `add` calls come from many threads, but each one runs its closure on the serial queue, one at a time, so no increment is lost. 0, 5, …, 45 are ten multiples of 5, so 10 apples and 40 pears. `concurrentPerform` returns only when every iteration is done, and every `sync` has finished by then, so the reads see all 50 additions.
````

````exercise
id: m28-l06-e3
type: solve
prompt: |
  Swift 6 flags this class when you try to share it between threads (an error, or a warning in Xcode if the closure goes straight to `DispatchQueue.async`), and it's also racy by design:

  ```swift
  final class SeatMap {
      private var taken: Set<Int> = []

      func isTaken(_ seat: Int) -> Bool { taken.contains(seat) }
      func take(_ seat: Int) { taken.insert(seat) }
  }
  ```

  Rewrite it as `final class SeatMap: @unchecked Sendable` guarded by an `NSLock`, with one atomic method `func reserve(_ seat: Int) -> Bool` that takes the seat and returns `true` only if it was free, plus `var takenCount: Int`. Then make 100 concurrent attempts (`DispatchQueue.concurrentPerform(iterations: 100)`) where attempt `i` tries seat `i % 20`, count how many succeeded with a second lock-protected counter, and print exactly:

  ```plaintext
  reserved: 20
  seats taken: 20
  ```
starter: |
  import Foundation

  final class SeatMap: @unchecked Sendable {
      // your code
  }

  func run() {
      // 100 concurrent attempts, then print the results
  }

  run()
hints:
  - "Set.insert returns a tuple whose inserted field tells you whether the element was new."
  - "lock.lock(); defer { lock.unlock() }; return taken.insert(seat).inserted"
  - "The success counter can be a small final class with its own NSLock, like the lesson's Tally."
rubric:
  - All access to taken happens while holding the lock, reads included.
  - reserve checks and inserts in one critical section.
  - The success count is also synchronized.
  - The output matches on every run.
solution: |
  ```swift
  import Foundation

  final class SeatMap: @unchecked Sendable {
      // `taken` is only accessed while holding `lock`.
      private let lock = NSLock()
      private var taken: Set<Int> = []

      /// Takes the seat if it's free. Returns false if someone already has it.
      func reserve(_ seat: Int) -> Bool {
          lock.lock()
          defer { lock.unlock() }
          return taken.insert(seat).inserted
      }

      var takenCount: Int {
          lock.lock()
          defer { lock.unlock() }
          return taken.count
      }
  }

  final class SuccessCounter: @unchecked Sendable {
      // `count` is only accessed while holding `lock`.
      private let lock = NSLock()
      private var count = 0

      func add() {
          lock.lock()
          defer { lock.unlock() }
          count += 1
      }

      var value: Int {
          lock.lock()
          defer { lock.unlock() }
          return count
      }
  }

  func run() {
      let seats = SeatMap()
      let successes = SuccessCounter()
      DispatchQueue.concurrentPerform(iterations: 100) { attempt in
          if seats.reserve(attempt % 20) {
              successes.add()
          }
      }
      print("reserved: \(successes.value)")
      print("seats taken: \(seats.takenCount)")
  }

  run()
  ```

  ```output
  reserved: 20
  seats taken: 20
  ```

  100 attempts over 20 seats: each seat is attempted five times and exactly one attempt wins, because the check ("is it free?") and the act ("take it") happen inside one locked section. `Set.insert` already returns whether the element was new, so the check and the insert are a single call. `@unchecked Sendable` is honest for both classes: they're `final`, their mutable state is `private`, and every access holds the lock.
````

````exercise
id: m28-l06-e4
type: find-errors
prompt: "This image store is used from several queues. Mark every real problem."
code: |
  class ImageStore: @unchecked Sendable {
      private let queue = DispatchQueue(label: "com.example.images")
      var images: [String: Image] = [:]

      func image(named name: String) -> Image? {
          images[name]
      }

      func save(_ image: Image, named name: String) {
          queue.sync {
              images[name] = image
              trimIfNeeded()
          }
      }

      private func trimIfNeeded() {
          queue.sync {
              if images.count > 100 { images.removeAll() }
          }
      }
  }
choices:
  - text: "image(named:) reads images without going through the queue."
    correct: true
  - text: "images is internal (not private), so other code can touch it without the queue."
    correct: true
  - text: "The class isn't final, so a subclass could add unprotected state and still be @unchecked Sendable."
    correct: true
  - text: "trimIfNeeded() calls queue.sync while already running on queue (from save), which deadlocks."
    correct: true
  - text: "A serial queue can't protect a dictionary; only a lock can."
    correct: false
rubric:
  - Finds the unsynchronized read.
  - Finds the non-private state.
  - Finds the missing final.
  - Finds the re-entrant sync deadlock.
solution: |
  1. **Unsynchronized read.** `image(named:)` reads `images` on the caller's thread while `save` may be writing on the queue: a data race. Use `queue.sync { images[name] }`.
  2. **Non-private state.** `var images` is visible to the module, so any code can bypass the queue. Make it `private`.
  3. **Not final.** `@unchecked Sendable` is a promise about every stored property; a subclass could add its own without any synchronization. Mark the class `final`.
  4. **Re-entrant `sync`.** `save` runs its closure on `queue` and calls `trimIfNeeded()`, which does `queue.sync` on the same serial queue: the deadlock from this lesson. `trimIfNeeded()` is private and only called from inside the queue, so it should just do the work without `sync` (and its name or a comment should say it assumes it's on the queue).

  Serial queues and locks are interchangeable for this job; the problems are in how the class uses its queue.
````

````exercise
id: m28-l06-e5
type: explain
prompt: "Explain why this transfer function can hang, under what timing, and give two different fixes."
code: |
  final class Wallet: @unchecked Sendable {
      let id: Int
      let lock = NSLock()
      var balance: Int
      init(id: Int, balance: Int) { self.id = id; self.balance = balance }
  }

  func transfer(_ amount: Int, from source: Wallet, to destination: Wallet) {
      source.lock.lock()
      defer { source.lock.unlock() }
      destination.lock.lock()
      defer { destination.lock.unlock() }
      source.balance -= amount
      destination.balance += amount
  }

  // Thread 1: transfer(10, from: alice, to: bob)
  // Thread 2: transfer(5, from: bob, to: alice)
rubric:
  - Identifies the opposite lock order between the two calls.
  - Describes the interleaving where each thread holds its first lock and waits for the second.
  - Proposes a consistent global order (for example by id).
  - Proposes a second fix (one lock for both, not holding two locks, or a single serial queue).
solution: |
  The two calls take the same two locks in opposite order: thread 1 locks Alice then Bob, thread 2 locks Bob then Alice. If thread 1 takes Alice's lock and, before it takes Bob's, thread 2 takes Bob's, each now waits for the lock the other holds. Neither ever releases, so both hang. It only happens when both first locks are taken before either second lock, which is why it's rare and hard to reproduce.

  Fixes:

  1. **One global order.** Lock the wallet with the lower `id` first, whatever the direction of the transfer. A cycle can't form when everyone climbs the same ladder.
  2. **One guard for both.** Put all balances behind a single lock or serial queue (a `Ledger` that owns the wallets), so a transfer takes exactly one lock.

  (Also worth fixing while you're there: `lock` and `balance` aren't `private`, so other code can change `balance` without the lock, and the `@unchecked Sendable` promise isn't kept.)
````

````exercise
id: m28-l06-e6
type: comprehension
prompt: "Your team wants to catch data races in a module that uses a C library and a few @unchecked Sendable classes. Which plan works?"
choices:
  - text: "Keep Swift 6 mode for compile-time checks, and run the unit tests with Thread Sanitizer enabled in the test plan, in the Simulator."
    correct: true
    why: "The compiler covers what it can see; TSan covers the C code and @unchecked classes at runtime, in the Simulator where it's supported."
  - text: "Enable Thread Sanitizer on a release build and ship it to TestFlight users."
    correct: false
    why: "TSan doesn't run on devices, and it slows the app 2x to 20x."
  - text: "Rely on Swift 6 mode alone: it flags every data race at compile time."
    correct: false
    why: "It can't check inside C code or through @unchecked Sendable, which is exactly where this module's risks are."
  - text: "Run the app 1,000 times and check the results are always the same."
    correct: false
    why: "A data race is undefined behavior: identical results don't prove there isn't one."
solution: |
  Combine both tools. Swift 6's checks catch races in Swift code at compile time but trust `@unchecked Sendable` and can't see into C. Thread Sanitizer records the accesses that actually happen at runtime, including in C code, and reports unsynchronized ones; Apple's documentation limits it to macOS apps and to iOS apps in the Simulator, and warns about a 2x to 20x slowdown. Running the test suite under TSan exercises far more paths than manual runs.
````

## Summary

- A **data race** is unsynchronized simultaneous access to the same memory with at least one write: undefined behavior. A **race condition** is a timing-dependent logic bug that can exist even when every access is locked.
- Swift 6 flags data races it can see: mutating captured `var`s in concurrent closures, mutable global and static state, non-`Sendable` captures, and mutable stored properties in `Sendable` classes. For closures passed straight to `DispatchQueue.async`, Xcode reports the capture problems as warnings (Linux reports errors); treat them as errors.
- Protect state with a private serial queue or a lock (`NSLock` everywhere; `OSAllocatedUnfairLock` and `Mutex` on newer Apple systems). Guard reads as well as writes, and use `defer` to unlock.
- `@unchecked Sendable` turns off the compiler's check. It's honest only for a `final` class whose mutable state is `private` and always accessed under its lock or queue. `Mutex` lets you skip the promise entirely.
- Make check-then-act operations atomic: design methods around the operation callers need.
- Deadlocks: `sync` onto the queue you're on (libdispatch may crash instead of hanging, don't count on it), and locks taken in different orders. Fix with clear queue ownership, one lock at a time, or one global lock order.
- Priority inversion makes important work wait on unimportant work; keep critical sections short and don't make high-QoS work wait on low-QoS work.
- Thread Sanitizer finds races at runtime, in macOS apps and in the Simulator, at a 2x to 20x slowdown. Run your tests with it, and treat Module 29's actors as the next step in letting the compiler do this work.
