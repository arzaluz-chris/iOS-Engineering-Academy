---
id: m28-l01
title: Processes, threads and blocking
description: The vocabulary every concurrency discussion assumes. You separate a process from a thread, blocking work from non-blocking work, a synchronous call from an asynchronous one, and concurrency from parallelism, then see why all of it comes back to one rule on iOS, the main thread must never wait.
module: m28
order: 1
level: advanced
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l05, m21-l03]
objectives:
  - Explain what a process and a thread are and what threads in the same process share.
  - Tell blocking work from non-blocking work, and CPU-bound work from work that waits.
  - Tell a synchronous call from an asynchronous one by when it returns and how it delivers its result.
  - Distinguish concurrency from parallelism, including on a single core.
  - Explain why blocking the main thread causes hangs and, in the worst case, termination by the watchdog.
terms:
  - term: Process
    definition: "A running program. The operating system gives each process its own address space and resources and isolates it from other processes. An iOS app runs as one process."
  - term: Thread
    definition: "One sequence of instructions the CPU executes inside a process. Each thread has its own stack and position in the code; all threads in a process share its memory."
  - term: Blocking call
    definition: "A call that doesn't return until its work is done or what it waits for arrives. Meanwhile the calling thread can't do anything else."
  - term: Asynchronous call
    definition: "A call that starts work and returns right away. The result is delivered later, through a callback, a delegate or an await."
  - term: Concurrency
    definition: "Structuring a program so several tasks are in progress during the same period. They may interleave on one core or run at the same instant on several."
  - term: Parallelism
    definition: "Several tasks executing at the same instant on different CPU cores. It needs concurrency in the program and more than one core in the hardware."
mastery:
  - Say which of two threads in the same app can read a global variable (both) and why that's the source of concurrency bugs.
  - Classify a call as blocking or not, and as CPU-bound or waiting.
  - Predict the print order when a handler starts background work that reports back on the main queue.
  - Explain to a colleague why "concurrent" and "parallel" aren't synonyms, with a single-core example.
  - Move a slow step out of a main-thread handler and deliver its result back on the main queue.
resources: [understanding-hangs, swift-mainactor]
cards:
  - id: m28-l01-c1
    front: Process vs thread?
    back: "A process is a running program with its own address space, isolated by the OS. A thread is one path of execution inside a process; threads have their own stacks but share the process's memory."
  - id: m28-l01-c2
    front: Synchronous vs asynchronous call?
    back: "A synchronous call returns when the work is done and hands back the result. An asynchronous call returns right away and delivers the result later (callback, delegate, await)."
  - id: m28-l01-c3
    front: Concurrency vs parallelism?
    back: "Concurrency: several tasks in progress over the same period, possibly interleaved on one core. Parallelism: tasks executing at the same instant on different cores."
  - id: m28-l01-c4
    front: What happens if the main thread blocks for too long?
    back: "The UI freezes (a hang). If it's unresponsive long enough, iOS's watchdog terminates the app; Apple's DispatchQueue.main docs mention the 0x8badf00d exception code."
---

## The idea in one sentence

A thread can only do one thing at a time, so any call that makes it wait (for the disk, the network or a long computation) takes that thread away from everything else, and on iOS the thread you can least afford to lose is the main one.

> [!note] Where this module sits
> Module 21, lesson 3 showed the main thread and its run loop: one thread processes events one at a time, and slow work in a handler delays everything behind it. This module is about getting work **off** that thread with the tools that predate Swift Concurrency: threads, Grand Central Dispatch (GCD) and operation queues. You'll meet them in almost every existing codebase. Module 29 teaches `async`/`await`, tasks and actors, which is where new code is going. The Swift blocks here were compiled and run with Swift 6.3 on Linux, where Foundation and Dispatch are open source, and their output was written so it doesn't depend on thread timing or platform.

## Processes and threads

A **process** is a running program. When you tap an app's icon, iOS starts a process for it and gives it its own address space: its own view of memory that no other process can read or write. That isolation is what the sandbox from Module 21 builds on. An iOS app is one process; the system runs many others (the home screen, the render server, background daemons) next to it.

A **thread** is one sequence of instructions executing inside a process. Every process starts with one thread, the main thread, and can create more. Each thread has:

- its own **stack**, where the local variables of the functions it's running live;
- its own position in the code (which instruction it executes next).

Everything else is **shared**: global variables, objects on the heap, open files. Two threads in the same app can both hold a reference to the same object and change it. That's what makes threads cheap to communicate with, and it's also the root of every bug in lesson 6.

Foundation lets you see the main thread and start another one:

```swift
import Foundation

print("process id is positive: \(ProcessInfo.processInfo.processIdentifier > 0)")
print("top-level code on the main thread: \(Thread.isMainThread)")

let workerFinished = DispatchSemaphore(value: 0)
let worker = Thread {
    print("worker on the main thread: \(Thread.isMainThread)")
    workerFinished.signal()
}
worker.start()
workerFinished.wait()
print("main thread continues after the worker")
```

```output
process id is positive: true
top-level code on the main thread: true
worker on the main thread: false
main thread continues after the worker
```

Line by line:

1. `ProcessInfo.processInfo` describes the current process. The id itself changes on every run, so the program prints only whether it's positive.
2. Top-level code in `main.swift` runs on the main thread.
3. `Thread { … }` creates a thread object with a closure to run; `start()` asks the system to run it. From then on two threads are executing in this process.
4. `DispatchSemaphore` makes the main thread wait until the worker says it's done. Without it, the program could reach its end and exit before the worker printed anything. Lesson 3 explains semaphores; here it only exists so the output is the same on every run.

You'll rarely create a `Thread` yourself in app code. Creating and tearing down threads costs time and memory, and the system knows better than you how many the device can run well. The tools in the rest of this module hand work to a pool of threads the system manages.

## Blocking and non-blocking work

A **blocking** call doesn't return until it has finished, and while it hasn't, its thread can't do anything else. Blocking comes in two flavors:

| | The CPU is… | Examples |
| --- | --- | --- |
| **CPU-bound work** | busy the whole time | parsing a large JSON file, resizing an image, sorting a million items |
| **Waiting** | idle, the thread sleeps | reading a file, a synchronous network request, `Thread.sleep`, waiting on a lock or a semaphore |

From the caller's point of view they're the same: the call takes a long time and the thread is stuck. The difference matters when you choose a fix. CPU-bound work needs to run on another thread (and benefits from more cores). Waiting doesn't need a CPU at all; it needs an API that doesn't make a thread wait, so the thread is free while the disk or the server takes its time.

A **non-blocking** call returns quickly whatever happens. Appending to an array, reading a property, or *starting* a download are non-blocking.

## Synchronous and asynchronous calls

The same distinction, seen from the API:

- A **synchronous** call returns when the work is done, and hands you the result as its return value. `let total = sum(numbers)` is synchronous. If the work is slow, a synchronous call is a blocking call.
- An **asynchronous** call starts the work and returns right away. The result arrives later, through a completion handler (Module 26, lesson 2), a delegate, or `await` in Swift Concurrency.

An asynchronous call isn't magic: someone still does the work. Either another thread does it, or the system does it outside your process (the network stack, the disk controller) and tells you when it's finished. What changes is that **your** thread is free in the meantime.

Here's the shape every iOS app uses. A handler on the main thread starts slow work on a background queue, returns, and the result comes back to the main thread later:

```swift
import Foundation

var finished = false

print("1. handler starts the work")
DispatchQueue.global().async {
    let total = (1...1_000_000).reduce(0, +)
    DispatchQueue.main.async {
        print("3. result arrives on the main thread: \(total)")
        finished = true
    }
}
print("2. handler returns; the main thread is free")

// Stands in for the app's main run loop (Module 21, lesson 3).
while !finished {
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))
}
```

```output
1. handler starts the work
2. handler returns; the main thread is free
3. result arrives on the main thread: 500000500000
```

1. `DispatchQueue.global().async { … }` hands the closure to a pool of background threads and returns immediately. Lesson 2 covers queues in detail.
2. Line 2 prints while the sum is still running, or before it has started. It doesn't matter which: the main thread didn't wait.
3. When the sum is done, the background thread doesn't print the result itself. It sends a second closure to `DispatchQueue.main`, the queue the main thread's run loop drains.
4. That closure runs only when the main run loop gets to it, which is why line 3 always prints after line 2, even if the sum finishes first.
5. The `while` loop keeps the main run loop running until the result has arrived. In an app you never write it: `UIApplicationMain` runs the loop for as long as the app lives.

The order 1, 2, 3 isn't luck. Line 3 is printed by the main thread, and the main thread was busy with the top-level code until the loop at the bottom.

## Concurrency and parallelism

These two words get used interchangeably, and they shouldn't be.

- **Concurrency** is about structure: several tasks are *in progress* during the same period. A task can start before another one finishes.
- **Parallelism** is about execution: several tasks *run at the same instant*, on different CPU cores.

On a single core, two threads are concurrent but never parallel: the operating system switches between them many times a second (each gets a time slice), so both make progress, but at any instant only one is executing. On a phone with six cores, the same two threads may also run in parallel. Your program can't tell which will happen; the scheduler decides.

```plaintext
One core, two threads (concurrent, not parallel):
  core 1:  A A B B A A B B A A

Two cores, two threads (concurrent and parallel):
  core 1:  A A A A A A
  core 2:  B B B B B B
```

`ProcessInfo` reports how many cores the process can use right now:

```swift
import Foundation

let cores = ProcessInfo.processInfo.activeProcessorCount
print("at least one active core: \(cores >= 1)")
```

```output
at least one active core: true
```

(The real number depends on the device, so the program doesn't print it.)

Why does the distinction matter?

- Concurrency is what keeps an app **responsive**: the main thread handles a tap while a download is in progress. That works even on one core.
- Parallelism is what makes CPU-bound work **faster**: splitting an image filter across six cores. Code that only waits (for the network) gains nothing from more cores.
- The bugs come from concurrency, not parallelism. Two threads interleaved on one core can corrupt shared state just as well as two threads on two cores, because a switch can happen between any two instructions.

## Why the main thread must not block

Module 21, lesson 3 showed what happens when the main thread is busy: every event, timer and frame queued behind the slow work waits. Here's what that means for the choices in this module:

- **Anything that might block goes elsewhere.** Network requests, file I/O beyond small reads, decoding, image processing, database queries.
- **Waiting is also blocking.** A synchronous network call can feel instant on office Wi-Fi and take 30 seconds on a train. The fix isn't "it's usually fast"; the fix is to not wait on the main thread.
- **The system enforces it.** Apple's documentation for `DispatchQueue.main` warns that an unresponsive main thread "can lead to a `0x8badf00d` exception", raised when iOS's watchdog "detects that your app failed to respond to certain user interface events in time". The system terminates the app, and the user sees it as a crash.

Here's the most common way it happens in old code. It compiles and works, and it's wrong:

```swift illustrative
// Inside a button handler, on the main thread. Don't do this.
let url = URL(string: "https://example.com/report.json")!
let data = try Data(contentsOf: url)   // blocks until the whole response arrives
let report = try JSONDecoder().decode(Report.self, from: data)
titleLabel.text = report.title
```

`Data(contentsOf:)` with a remote URL is a synchronous network request. The tap that triggered it, every other tap, and all animations wait for the server. The fix is the shape you saw above: start the work elsewhere, come back to the main thread with the result. Module 30 does networking properly with `URLSession`.

> [!tip] Which thread am I on?
> `Thread.isMainThread` is handy for learning and debugging, like in the blocks above. In app code, prefer making the compiler check it: `@MainActor` (Module 21, lesson 3) fails the build when UI code could be called from the wrong place. You'll lean on that more in Module 29.

## Common mistakes

> [!error] Thinking "asynchronous" means "on another thread"
> Asynchronous means "returns before the work is done". The work may run on another thread, in another process, or later on the same thread: `DispatchQueue.main.async` called from the main thread runs the closure on the main thread, just not now.

> [!error] Treating "concurrent" and "parallel" as the same thing
> A single-core device runs concurrent code without any parallelism, and the data races in lesson 6 still happen there.

> [!error] Keeping a blocking call on the main thread because it's fast on your machine
> Your simulator has a fast Mac's disk and network. The user has a three-year-old phone in a tunnel. If a call can wait, it doesn't belong on the main thread.

> [!error] Creating a Thread for each piece of work
> Each thread costs memory and setup time, and a hundred threads on six cores mostly wait for their turn. Hand work to a queue (lesson 2) and let the system size the thread pool.

## Exercises

````exercise
id: m28-l01-e1
type: comprehension
prompt: "An app runs on a device with a single CPU core. While a download is in progress on a background thread, the user scrolls and the list moves smoothly. Which statement is correct?"
choices:
  - text: "The app is concurrent but not parallel: the core switches between the main thread and the download thread."
    correct: true
    why: "Both tasks are in progress over the same period, and with one core only one executes at any instant."
  - text: "The app is parallel: the download and the scrolling happen at the same time."
    correct: false
    why: "They overlap in time, but on one core they never execute at the same instant. That's concurrency without parallelism."
  - text: "The app is neither: with one core, a second thread can't make progress until the main thread is idle."
    correct: false
    why: "The scheduler gives each thread time slices, so both make progress even while both are busy."
  - text: "The download must be on the main thread, because a single core has only one thread."
    correct: false
    why: "Threads aren't cores. A single core can run any number of threads, one at a time."
solution: |
  The first statement. Concurrency is about tasks being in progress over the same period; parallelism needs them to execute at the same instant, which needs more than one core. On one core the scheduler interleaves the two threads quickly enough that scrolling stays smooth, and the download still progresses.
````

````exercise
id: m28-l01-e2
type: prediction
prompt: "A handler queues one closure on the main queue and starts background work that reports back on the main queue. What does the program print?"
code: |
  import Foundation

  var done = false

  print("A")
  DispatchQueue.main.async {
      print("C")
  }
  DispatchQueue.global().async {
      let count = (1...10).filter { $0 % 2 == 0 }.count
      DispatchQueue.main.async {
          print("D \(count)")
          done = true
      }
  }
  print("B")
  while !done {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
  }
  print("E")
output: |
  A
  B
  C
  D 5
  E
hints:
  - "Nothing sent to DispatchQueue.main runs while the top-level code is still executing."
  - "The main queue runs its closures in the order they were added. Which one was added first?"
solution: |
  ```output
  A
  B
  C
  D 5
  E
  ```

  `A` and `B` print from the top-level code, which keeps the main thread busy until the `while` loop, so neither main-queue closure can run before `B`. The `C` closure is added to the main queue before the background work even starts. The `D` closure is added later, by the background thread, once the count is done. The main queue runs its closures in the order they were added, so `C` comes before `D 5`. Then `done` is `true`, the loop ends and `E` prints.

  The order is guaranteed by **when each closure was queued**, not by which thread is faster. If the `C` closure were queued after `DispatchQueue.global().async`, the background work could finish first and queue `D` ahead of it, and the order would change from run to run.
````

````exercise
id: m28-l01-e3
type: comprehension
multiple: true
prompt: "Which of these block the calling thread until something finishes? Select all that apply."
choices:
  - text: "Data(contentsOf:) with an https URL"
    correct: true
    why: "It performs a synchronous network request and returns only when the whole response has arrived."
  - text: "Thread.sleep(forTimeInterval: 1)"
    correct: true
    why: "The thread sleeps for the whole second and can't do anything else."
  - text: "DispatchQueue.global().async { heavyWork() }"
    correct: false
    why: "async hands the closure to a queue and returns right away. The heavy work blocks a background thread, not the caller."
  - text: "Sorting an array of two million strings"
    correct: true
    why: "It's CPU-bound: the call returns only when the sort is done, and the thread is busy the whole time."
  - text: "Appending one element to an array"
    correct: false
    why: "It returns almost immediately. Not every synchronous call is a problem; slow ones are."
solution: |
  `Data(contentsOf:)` with a remote URL, `Thread.sleep` and a big sort all block: the first two wait, the sort keeps the CPU busy. `async` only queues work and returns, and appending to an array is synchronous but quick. "Synchronous" isn't the problem; synchronous **and slow** on the main thread is.
````

````exercise
id: m28-l01-e4
type: solve
prompt: |
  This "button handler" runs a slow word count on the main thread:

  ```swift
  import Foundation

  let text = String(repeating: "lorem ipsum dolor ", count: 20_000)

  print("tap")
  let words = text.split(separator: " ").count
  print("words: \(words)")
  print("handler returns")
  ```

  Change it so that the count runs on a global queue and the result is printed on the main queue, after the handler has returned. Keep the main run loop running until the result has arrived, as in the lesson. The program must print exactly:

  ```plaintext
  tap
  handler returns
  words: 60000
  ```
starter: |
  import Foundation

  let text = String(repeating: "lorem ipsum dolor ", count: 20_000)

  print("tap")
  let words = text.split(separator: " ").count
  print("words: \(words)")
  print("handler returns")
hints:
  - "DispatchQueue.global().async { … } for the count, DispatchQueue.main.async { … } around the print."
  - "A top-level var finished = false and a while loop around RunLoop.main.run(until:) keep the program alive."
  - "text is a let String, so the background closure can capture it."
rubric:
  - The count runs inside DispatchQueue.global().async.
  - The result is printed inside DispatchQueue.main.async.
  - "\"handler returns\" prints before the result, guaranteed by where each print runs, not by timing."
  - The program exits cleanly after printing the result.
solution: |
  ```swift
  import Foundation

  let text = String(repeating: "lorem ipsum dolor ", count: 20_000)
  var finished = false

  print("tap")
  DispatchQueue.global().async {
      let words = text.split(separator: " ").count
      DispatchQueue.main.async {
          print("words: \(words)")
          finished = true
      }
  }
  print("handler returns")

  while !finished {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
  }
  ```

  ```output
  tap
  handler returns
  words: 60000
  ```

  The order is guaranteed: `words:` is printed by a closure on the main queue, and the main queue can't run anything until the top-level code (which prints `handler returns`) reaches the run loop. `text` is an immutable `String`, a value type that's safe to read from another thread, so the background closure can capture it. Lesson 6 explains why capturing a `var` instead would be rejected.
````

````exercise
id: m28-l01-e5
type: explain
prompt: "A teammate says: \"The settings screen loads its JSON with Data(contentsOf:) on the main thread, but the file is on our CDN and it's always under 50 ms, so it's fine.\" Explain what's wrong with that reasoning and what the user could see in the worst case."
code: |
  // SettingsViewController, called from viewDidLoad (main thread)
  func loadSettings() throws {
      let url = URL(string: "https://cdn.example.com/settings.json")!
      let data = try Data(contentsOf: url)
      settings = try JSONDecoder().decode(Settings.self, from: data)
      tableView.reloadData()
  }
rubric:
  - Points out that the call blocks the main thread for however long the network takes, which isn't bounded by the usual case.
  - Mentions that every event, timer and frame behind it waits (a hang).
  - Mentions that a long enough block can get the app terminated by the watchdog (0x8badf00d).
  - Proposes doing the request off the main thread (or with an asynchronous API) and updating the UI on the main thread.
solution: |
  "Always under 50 ms" describes the office network, not the user's. `Data(contentsOf:)` blocks its thread until the response arrives or the request times out, and on a bad connection that can be many seconds. While it waits, the main run loop can't process taps, timers or frames, so the app hangs. If it stays unresponsive long enough, iOS's watchdog terminates it (Apple's `DispatchQueue.main` docs mention the `0x8badf00d` code), which the user experiences as a crash.

  The fix doesn't depend on measurements: do the request off the main thread, or better with an asynchronous API (`URLSession`, Module 30), and update the UI on the main thread when the result arrives.
````

````exercise
id: m28-l01-e6
type: comprehension
prompt: "Two threads in the same app both hold a reference to the same Cart object. Which statement is true?"
choices:
  - text: "Both threads see and can change the same Cart, because threads in one process share its memory."
    correct: true
    why: "Each thread has its own stack, but objects on the heap are shared by every thread in the process."
  - text: "Each thread gets its own copy of the Cart, because each thread has its own stack."
    correct: false
    why: "The references live on the stacks; the object they point to lives once, on the heap."
  - text: "Only the thread that created the Cart can access it; the other gets a runtime error."
    correct: false
    why: "Nothing ties an object to the thread that created it. That's exactly why unsynchronized access is possible."
solution: |
  Threads share their process's memory. Each thread's stack holds its own local variables, including its own **reference** to the cart, but both references point to the one `Cart` object on the heap. Two threads changing it at the same time is a data race, which lesson 6 covers along with how Swift 6 catches it at compile time.
````

## Summary

- A **process** is a running program with its own isolated memory; a **thread** is one path of execution inside it. Threads have their own stacks and share everything else, which is both why they're useful and why they're dangerous.
- A **blocking** call keeps its thread until it's done: CPU-bound work keeps a core busy, waiting work keeps a thread asleep. Either way, the thread can't do anything else.
- A **synchronous** call returns its result when the work is done; an **asynchronous** call returns right away and delivers the result later.
- **Concurrency** is several tasks in progress over the same period; **parallelism** is several tasks executing at the same instant on different cores. Responsiveness needs the first; speeding up CPU work needs the second; data races only need the first.
- On iOS, the main thread must not block. Start slow work elsewhere and bring the result back to the main queue, which runs it only when the main thread is free. A main thread blocked long enough gets the app terminated by the watchdog.
