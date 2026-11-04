---
id: m28-l03
title: Dispatch groups, barriers and semaphores
description: "Three GCD tools for coordinating work you've already sent off: DispatchGroup to find out when several jobs have all finished, barrier blocks to build a reader-writer cache on a concurrent queue, and DispatchSemaphore to limit how many jobs run at once. You also see why waiting on the main thread is dangerous and how blocked work leads to thread explosion."
module: m28
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l02]
objectives:
  - Track several asynchronous jobs with a DispatchGroup using async(group:), enter and leave.
  - Get notified when a group finishes with notify, and know when wait is acceptable.
  - Build a reader-writer store with sync reads and barrier writes on a private concurrent queue.
  - Limit concurrency with a DispatchSemaphore and keep wait and signal balanced.
  - Explain why waiting on the main thread risks deadlock and what thread explosion is.
terms:
  - term: DispatchGroup
    definition: "A counter of unfinished work. enter() adds one, leave() subtracts one; notify runs a closure when the count reaches zero, and wait() blocks until it does."
  - term: Barrier block
    definition: "A work item submitted with flags .barrier to a private concurrent queue. It waits for everything submitted before it, runs alone, and only then lets later items start."
  - term: Reader-writer pattern
    definition: "Letting many reads run at the same time but giving each write exclusive access. With GCD: sync reads and barrier writes on one concurrent queue."
  - term: DispatchSemaphore
    definition: "A counting semaphore. wait() decrements the count and blocks while it's below zero; signal() increments it and wakes a waiter. Starting at N, it lets N holders through at once."
  - term: Thread explosion
    definition: "When many work items block their threads (waiting on a semaphore, a lock, I/O), GCD creates more threads to keep going, until the app has far more threads than cores, or runs out."
mastery:
  - Wrap a callback-based API call in enter and leave so the group is balanced on every path.
  - Print a summary when three loads finish, with output independent of finishing order.
  - Write a thread-safe dictionary wrapper with sync reads and barrier writes.
  - Cap simultaneous downloads at two with a semaphore and verify the cap.
  - Explain why semaphore.wait() on the main thread for a result delivered on the main queue never returns.
resources: [understanding-hangs]
cards:
  - id: m28-l03-c1
    front: DispatchGroup notify vs wait?
    back: "notify(queue:) schedules a closure to run when the group's count reaches zero and returns immediately. wait() blocks the calling thread until then: fine in a background job or a test, never on the main thread."
  - id: m28-l03-c2
    front: What does enter/leave have to satisfy?
    back: "Exactly one leave() for every enter(), on every path, including errors. A missing leave means notify never runs; an extra leave crashes the program."
  - id: m28-l03-c3
    front: How does a barrier write work?
    back: "queue.async(flags: .barrier) on a private concurrent queue waits for the items submitted before it, runs alone, then lets later items run. Reads use queue.sync, so many can run at once."
  - id: m28-l03-c4
    front: Why is a barrier useless on a global queue?
    back: "Barriers only work on a concurrent queue you created. Apple's dispatch_barrier_async docs: on a serial queue or a global concurrent queue it behaves like a plain async, so on a global queue the write overlaps with other work."
  - id: m28-l03-c5
    front: How do you limit work to N at a time with GCD?
    back: "DispatchSemaphore(value: N): wait() before the work, signal() after it (defer). Mind that each waiting item blocks a thread; OperationQueue.maxConcurrentOperationCount is often a better fit."
---

## The idea in one sentence

Once work is on a queue you've lost sight of it, and these three tools get it back: a **group** tells you when a set of jobs has finished, a **barrier** gives one job exclusive access to a queue's data, and a **semaphore** caps how many jobs run at once.

> [!note] Sources and what was run
> Descriptions and quotes come from Apple's Dispatch documentation (`DispatchGroup`, `DispatchSemaphore`, `DispatchWorkItemFlags.barrier`, `dispatch_barrier_async`, `DispatchQueue`), read November 2026. Every block was compiled and run with Swift 6.3 on Linux. The outputs only print totals, sorted values or yes/no checks computed after the work has finished, so they're the same on every run; the course's macOS CI runs the same blocks.

## DispatchGroup

A group is a counter of unfinished work. The simplest way to use it is to pass it to `async`:

```swift
import Dispatch

final class Dashboard: @unchecked Sendable {
    // Only touched on `queue`.
    private let queue = DispatchQueue(label: "com.example.dashboard")
    private var sections: [String] = []

    func add(_ section: String) {
        queue.sync { sections.append(section) }
    }

    var loadedSections: [String] {
        queue.sync { sections.sorted() }
    }
}

func loadDashboard() -> [String] {
    let dashboard = Dashboard()
    let group = DispatchGroup()

    for section in ["weather", "calendar", "news"] {
        DispatchQueue.global(qos: .userInitiated).async(group: group) {
            // Pretend this loads the section from disk.
            dashboard.add(section)
        }
    }

    group.wait()
    return dashboard.loadedSections
}

print(loadDashboard())
```

```output
["calendar", "news", "weather"]
```

1. `Dashboard` keeps its array behind a serial queue, like lesson 2's checksum store. `@unchecked Sendable` lets it be captured by the `async` closures; it's a promise that every access is synchronized, which lesson 6 examines.
2. `async(group: group)` counts the closure as part of the group: the counter goes up when it's submitted and down when it finishes.
3. `group.wait()` blocks the current thread until the counter is zero. Here that's the program's main thread, in a command-line tool; in an app you'd use `notify` instead (below).
4. The three sections finish in any order, so the result is sorted before it's returned.

### enter and leave for callback APIs

`async(group:)` only works when the work finishes when the closure returns. A function that starts a network request returns long before the response arrives, so the group would count it as done too early. For that, you count by hand:

- `group.enter()` before starting each job.
- `group.leave()` when the job is really finished, **on every path**, success or failure.

Here a fake price service calls its completion handler from a background queue, and the group finishes when all three answers are in:

```swift
import Dispatch

enum PriceError: Error {
    case unknownSymbol(String)
}

func fetchPrice(for symbol: String, completion: @escaping @Sendable (Result<Int, PriceError>) -> Void) {
    DispatchQueue.global().async {
        let prices = ["AAPL": 230, "MSFT": 410]
        if let price = prices[symbol] {
            completion(.success(price))
        } else {
            completion(.failure(.unknownSymbol(symbol)))
        }
    }
}

final class PriceBoard: @unchecked Sendable {
    // Only touched on `queue`.
    private let queue = DispatchQueue(label: "com.example.prices")
    private var lines: [String] = []

    func record(_ line: String) {
        queue.sync { lines.append(line) }
    }

    var summary: [String] {
        queue.sync { lines.sorted() }
    }
}

func loadBoard(symbols: [String]) {
    let board = PriceBoard()
    let group = DispatchGroup()
    let printed = DispatchSemaphore(value: 0)

    for symbol in symbols {
        group.enter()
        fetchPrice(for: symbol) { result in
            switch result {
            case .success(let price):
                board.record("\(symbol): \(price)")
            case .failure(let error):
                board.record("\(symbol): failed (\(error))")
            }
            group.leave()
        }
    }

    let summaryQueue = DispatchQueue(label: "com.example.summary")
    group.notify(queue: summaryQueue) {
        for line in board.summary {
            print(line)
        }
        printed.signal()
    }
    printed.wait()   // only so this command-line program doesn't exit early
}

loadBoard(symbols: ["MSFT", "TSLA", "AAPL"])
```

```output
AAPL: 230
MSFT: 410
TSLA: failed (unknownSymbol("TSLA"))
```

- `group.enter()` runs on the calling thread **before** the request starts. If you called it inside the completion instead, the group could reach zero before the later requests were counted.
- `group.leave()` sits after the `switch`, so success and failure both reach it. A `leave` inside only the `.success` case would leave the group waiting forever for TSLA.
- `notify(queue:)` doesn't block: it schedules the closure on the given queue for when the count reaches zero and returns. In an app you'd pass `.main` and update the screen there. This program prints from a serial queue and uses a semaphore only to keep the process alive until the summary is printed.

> [!warning] enter and leave must balance exactly
> A missing `leave()` means `notify` never runs and `wait()` never returns: the screen stays on its spinner. An extra `leave()` is worse: libdispatch treats an unbalanced leave as a programming error and stops the program. On Linux, Swift 6.3 reported only "Illegal instruction" in `libdispatch`; on Apple platforms the crash report names the unbalanced `dispatch_group_leave`. Neither shows up as a compiler error.

`wait()` also has a version with a timeout, which returns `.success` or `.timedOut` instead of blocking forever:

```swift
import Dispatch

func waitBriefly() {
    let group = DispatchGroup()
    group.enter()   // never balanced: simulates a job that hangs

    let result = group.wait(timeout: .now() + .milliseconds(50))
    print(result == .timedOut ? "gave up waiting" : "finished")

    group.leave()   // balance it before returning
}

waitBriefly()
```

```output
gave up waiting
```

## Barriers: a reader-writer cache

Lesson 2 protected data with a serial queue: every read and write runs one at a time. That's correct, but reads don't conflict with each other, only writes do. A reader-writer design lets reads overlap and gives each write exclusive access.

With GCD you get that from a **private concurrent queue** and the **barrier** flag:

- Reads use `queue.sync { … }`. On a concurrent queue, many can run at the same time.
- Writes use `queue.async(flags: .barrier) { … }`. A barrier item waits until everything submitted before it has finished, runs alone, and only then lets the items behind it start.

```swift
import Dispatch

final class ProfileCache: @unchecked Sendable {
    // Reads run concurrently on `queue`; writes are barriers.
    private let queue = DispatchQueue(label: "com.example.profile-cache", attributes: .concurrent)
    private var names: [Int: String] = [:]

    func name(for id: Int) -> String? {
        queue.sync { names[id] }
    }

    func setName(_ name: String, for id: Int) {
        queue.async(flags: .barrier) {
            self.names[id] = name
        }
    }

    var count: Int {
        queue.sync { names.count }
    }
}

func fillCache() {
    let cache = ProfileCache()
    DispatchQueue.concurrentPerform(iterations: 100) { id in
        cache.setName("user \(id)", for: id)
        _ = cache.name(for: id)
    }
    print("profiles cached: \(cache.count)")
    print(cache.name(for: 42) ?? "missing")
}

fillCache()
```

```output
profiles cached: 100
user 42
```

1. `DispatchQueue.concurrentPerform(iterations:execute:)` runs the closure 100 times, spread over the available cores, and returns when all of them are done. It's the GCD tool for a CPU-bound loop you want to parallelize.
2. Every iteration writes with a barrier and reads with `sync`, from many threads at once. Writes never overlap with anything; reads can overlap with each other.
3. `setName` returns without waiting (`async`), so the caller isn't blocked while earlier reads finish.
4. `count` is a `sync` read submitted after all 100 barriers. Because the queue starts items in order and each barrier waits for what's before it, the read sees all 100 writes. The output doesn't depend on timing.

> [!warning] Barriers need a queue you created
> Apple's documentation for `dispatch_barrier_async` (the C function behind `async(flags: .barrier)`): the queue "should be a concurrent queue that you create yourself", and "if the queue you pass to this function is a serial queue or one of the global concurrent queues, this function behaves like the `dispatch_async` function." On a serial queue that changes nothing, since everything is already exclusive. On a global queue it means the "barrier" write runs at the same time as other work. Use your own `.concurrent` queue for this pattern.

Is the reader-writer cache worth it over a plain serial queue? Only when reads are frequent and contention is real. A serial queue or a lock (lesson 6) is simpler and, for short critical sections, often faster. Measure before reaching for barriers.

## DispatchSemaphore

A semaphore is a counter with two operations. Apple: you "increment a semaphore count by calling the `signal()` method, and decrement a semaphore count by calling `wait()`". When the count would go below zero, `wait()` blocks until someone signals.

Starting the count at N turns it into "at most N at a time". Here at most two downloads run at once, out of six:

```swift
import Foundation

final class ActivityTracker: @unchecked Sendable {
    // Only touched on `queue`.
    private let queue = DispatchQueue(label: "com.example.tracker")
    private var running = 0
    private var peak = 0
    private var finished = 0

    func start() {
        queue.sync {
            running += 1
            peak = max(peak, running)
        }
    }

    func finish() {
        queue.sync {
            running -= 1
            finished += 1
        }
    }

    var report: (finished: Int, peak: Int) {
        queue.sync { (finished, peak) }
    }
}

func downloadAll(count: Int, maxAtOnce: Int) {
    let tracker = ActivityTracker()
    let slots = DispatchSemaphore(value: maxAtOnce)
    let group = DispatchGroup()

    for _ in 1...count {
        DispatchQueue.global(qos: .utility).async(group: group) {
            slots.wait()
            defer { slots.signal() }

            tracker.start()
            Thread.sleep(forTimeInterval: 0.01)   // stands in for the download
            tracker.finish()
        }
    }

    group.wait()
    let report = tracker.report
    print("finished: \(report.finished)")
    print("never more than \(maxAtOnce) at once: \(report.peak <= maxAtOnce)")
}

downloadAll(count: 6, maxAtOnce: 2)
```

```output
finished: 6
never more than 2 at once: true
```

- `DispatchSemaphore(value: 2)`: two slots.
- Each job calls `wait()` before downloading. The first two get through; the third blocks until one of them calls `signal()`.
- `defer { slots.signal() }` returns the slot on every path out of the closure. A forgotten `signal()` loses a slot for good; lose both and every later job waits forever.
- The tracker records the highest number of simultaneous downloads. The program prints whether it stayed within the limit, not the exact peak, since the peak could be 1 on a slow machine.

### Two dangers: the main thread and thread explosion

**Waiting on the main thread.** `slots.wait()` is a blocking call. On the main thread it's a hang at best. At worst it's a deadlock: if the code you're waiting for needs the main thread to finish, it never will. This pattern shows up when someone tries to make an asynchronous API "synchronous":

```swift illustrative
// Called on the main thread. Never returns.
func currentUserName() -> String {
    let semaphore = DispatchSemaphore(value: 0)
    var name = ""
    api.loadUser { user in          // the API delivers its callback on the main queue
        name = user.name
        semaphore.signal()
    }
    semaphore.wait()                 // main thread blocks here...
    return name                      // ...so the callback queued on main never runs
}
```

The callback is waiting in the main queue for the main thread to be free; the main thread is waiting for the callback. Neither moves. The same happens with `group.wait()` and with `DispatchQueue.main.sync` from the main thread. (Swift 6 would also reject capturing and mutating `var name` from a `@Sendable` callback, which is a hint that this design is fighting the tools.) The fix is to stay asynchronous: return the name through a completion handler (lesson 5) or `async` (Module 29).

**Thread explosion.** In the download example, jobs waiting on the semaphore are still sitting on a thread each. Apple's `DispatchQueue` documentation explains the consequence: "When a task scheduled by a concurrent dispatch queue blocks a thread, the system creates additional threads to run other queued concurrent tasks. If too many tasks block, the system may run out of threads for your app." Submit 500 jobs with two slots and up to 498 threads may be created just to wait. Each thread costs memory, and switching between them costs time.

Ways to avoid it:

- Wait **before** submitting, on one background thread that feeds the queue, so only that thread blocks.
- Use `OperationQueue` with `maxConcurrentOperationCount` (lesson 4), which doesn't start the extra operations at all.
- For CPU-bound loops, use `concurrentPerform`, which uses roughly as many threads as there are cores.
- In new code, Swift Concurrency's task groups (Module 29) don't block threads while waiting.

## Common mistakes

> [!error] Calling enter() inside the callback
> By then the group may already have reached zero and fired `notify`. Call `enter()` before starting each job.

> [!error] leave() on the success path only
> One failed request and `notify` never runs. Put `leave()` where every path reaches it, or use `defer { group.leave() }` at the top of the callback.

> [!error] group.wait() or semaphore.wait() on the main thread
> It hangs the UI while it waits and deadlocks if the result is delivered on the main queue. Use `notify(queue: .main)` or a completion handler.

> [!error] A barrier on a global queue
> On a global queue a barrier behaves like a plain `async`, so the "exclusive" write overlaps with reads. Create your own concurrent queue.

> [!error] Using a semaphore to cap hundreds of queued jobs
> Every waiting job holds a thread. Gate submission instead, or use an operation queue's concurrency limit.

## Exercises

````exercise
id: m28-l03-e1
type: prediction
prompt: "Four jobs join a group, one of which is counted by hand. What does the program print?"
code: |
  import Dispatch

  final class Tally: @unchecked Sendable {
      private let queue = DispatchQueue(label: "com.example.tally")
      private var total = 0
      func add(_ value: Int) { queue.sync { total += value } }
      var value: Int { queue.sync { total } }
  }

  func run() {
      let tally = Tally()
      let group = DispatchGroup()

      for value in [1, 2, 3] {
          DispatchQueue.global().async(group: group) {
              tally.add(value)
          }
      }

      group.enter()
      DispatchQueue.global().async {
          tally.add(10)
          group.leave()
      }

      group.wait()
      print("total \(tally.value)")
  }

  run()
output: |
  total 16
hints:
  - "group.wait() returns only after all three async(group:) closures and the entered job have finished."
solution: |
  ```output
  total 16
  ```

  Three closures join the group through `async(group:)` and one through `enter()`/`leave()`. `wait()` returns only when all four have finished, so the tally is `1 + 2 + 3 + 10 = 16` regardless of the order in which they ran. Without the `enter()`, the fourth job wouldn't be counted and the total could be 6 or 16 depending on timing.
````

````exercise
id: m28-l03-e2
type: comprehension
prompt: "On a private concurrent queue, reads A and B are running, a barrier write W is submitted, then read C. What happens?"
choices:
  - text: "W waits for A and B to finish, runs alone, and C starts only after W finishes."
    correct: true
    why: "A barrier waits for everything submitted before it and holds back everything submitted after it."
  - text: "W starts immediately and A and B are paused until it finishes."
    correct: false
    why: "GCD never pauses a running closure. The barrier waits for them."
  - text: "C runs alongside A and B, because it's a read, and W runs when the queue is idle."
    correct: false
    why: "The queue starts items in order, so C can't jump ahead of the barrier submitted before it."
  - text: "W runs alongside A and B, because the queue is concurrent."
    correct: false
    why: "That's what happens on a global queue, where a barrier behaves like a plain async. On your own concurrent queue the barrier is exclusive."
solution: |
  The barrier waits until A and B (submitted before it) finish, runs with nothing else on the queue, and only then lets C and anything after it start. That's what makes `sync` reads plus barrier writes a correct reader-writer lock: a read can never observe a half-finished write.
````

````exercise
id: m28-l03-e3
type: find-errors
prompt: "This screen loads three feeds and shows them together. Mark every real problem."
code: |
  // FeedViewController, main thread
  func loadFeeds() {
      let group = DispatchGroup()
      var feeds: [Feed] = []

      for url in feedURLs {
          api.loadFeed(url) { result in        // completion runs on a background queue
              group.enter()
              if case .success(let feed) = result {
                  feeds.append(feed)
                  group.leave()
              }
          }
      }

      group.wait()
      show(feeds)
  }
choices:
  - text: "enter() is called inside the completion, so the group may be empty when it's checked."
    correct: true
  - text: "leave() only runs on success; one failed feed keeps the group from ever finishing."
    correct: true
  - text: "group.wait() blocks the main thread until every feed has loaded."
    correct: true
  - text: "feeds is appended from background callbacks without synchronization (and Swift 6 rejects mutating a captured var there)."
    correct: true
  - text: "A DispatchGroup can only track closures passed to async(group:), not callbacks."
    correct: false
rubric:
  - Finds the late enter().
  - Finds the missing leave() on failure.
  - Finds the blocking wait on the main thread.
  - Finds the unsynchronized append.
solution: |
  1. **Late `enter()`.** `loadFeed` returns before its callback runs, so the loop finishes with the group's count at zero and `wait()` can return immediately with no feeds. Call `group.enter()` before `api.loadFeed`.
  2. **`leave()` on success only.** A failed feed never leaves, so the group never finishes. Use `defer { group.leave() }` as the first line of the callback.
  3. **`wait()` on the main thread.** Even when it works, it hangs the UI for as long as the slowest feed. Use `group.notify(queue: .main) { self.show(feeds) }`.
  4. **Unsynchronized `append`.** The callbacks run on background threads, possibly at the same time, and all append to the same array. That's a data race; Swift 6 rejects it with "mutation of captured var 'feeds' in concurrently-executing code" if the callback is `@Sendable`. Record results through a serial queue (or append on the main queue).

  `enter()`/`leave()` exist precisely so groups can track callback-based work.
````

````exercise
id: m28-l03-e4
type: solve
prompt: |
  Write a thread-safe word counter, `final class WordCounter: @unchecked Sendable`, using the reader-writer pattern:

  - a private concurrent queue;
  - `func add(_ word: String)` that increments the word's count with a **barrier** write;
  - `func count(of word: String) -> Int` that reads with `sync` (0 if the word isn't there);
  - `var distinctWords: Int` that reads with `sync`.

  Then make this code print exactly the output below, from 300 concurrent iterations:

  ```swift
  let counter = WordCounter()
  let words = ["swift", "queue", "thread"]
  DispatchQueue.concurrentPerform(iterations: 300) { index in
      counter.add(words[index % 3])
  }
  print("distinct: \(counter.distinctWords)")
  print("swift: \(counter.count(of: "swift"))")
  print("actor: \(counter.count(of: "actor"))")
  ```

  ```plaintext
  distinct: 3
  swift: 100
  actor: 0
  ```
starter: |
  import Dispatch

  final class WordCounter: @unchecked Sendable {
      // your code
  }

  func run() {
      let counter = WordCounter()
      let words = ["swift", "queue", "thread"]
      DispatchQueue.concurrentPerform(iterations: 300) { index in
          counter.add(words[index % 3])
      }
      print("distinct: \(counter.distinctWords)")
      print("swift: \(counter.count(of: "swift"))")
      print("actor: \(counter.count(of: "actor"))")
  }

  run()
hints:
  - "private let queue = DispatchQueue(label: \"…\", attributes: .concurrent) and private var counts: [String: Int] = [:]."
  - "In the barrier closure: self.counts[word, default: 0] += 1."
  - "Reads after concurrentPerform see every write, because they're submitted after all the barriers."
rubric:
  - Uses a private concurrent queue it created, not a global queue.
  - Writes are async barriers; reads are sync.
  - The dictionary is only touched inside closures on that queue.
  - The output matches.
solution: |
  ```swift
  import Dispatch

  final class WordCounter: @unchecked Sendable {
      // Reads run concurrently on `queue`; writes are barriers.
      private let queue = DispatchQueue(label: "com.example.word-counter", attributes: .concurrent)
      private var counts: [String: Int] = [:]

      func add(_ word: String) {
          queue.async(flags: .barrier) {
              self.counts[word, default: 0] += 1
          }
      }

      func count(of word: String) -> Int {
          queue.sync { counts[word] ?? 0 }
      }

      var distinctWords: Int {
          queue.sync { counts.count }
      }
  }

  func run() {
      let counter = WordCounter()
      let words = ["swift", "queue", "thread"]
      DispatchQueue.concurrentPerform(iterations: 300) { index in
          counter.add(words[index % 3])
      }
      print("distinct: \(counter.distinctWords)")
      print("swift: \(counter.count(of: "swift"))")
      print("actor: \(counter.count(of: "actor"))")
  }

  run()
  ```

  ```output
  distinct: 3
  swift: 100
  actor: 0
  ```

  Each `add` is a barrier, so no two increments overlap and none is lost: 300 iterations, 100 per word. The reads are submitted after `concurrentPerform` returns, which is after all 300 barriers were submitted, so they wait for every write. `@unchecked Sendable` is honest here because `counts` is only touched inside closures on `queue`.
````

````exercise
id: m28-l03-e5
type: explain
prompt: "A teammate wants a synchronous accessor for a value an SDK only delivers through a callback on the main queue, and writes the code below. The app freezes the first time it runs on the main thread. Explain exactly why, and what to do instead."
code: |
  func currentToken() -> String {
      let semaphore = DispatchSemaphore(value: 0)
      let box = TokenBox()
      sdk.fetchToken { token in      // delivered on DispatchQueue.main
          box.value = token
          semaphore.signal()
      }
      semaphore.wait()
      return box.value
  }
rubric:
  - Explains that wait() blocks the main thread.
  - Explains that the callback is queued on the main queue and can only run when the main thread is free, so signal() never happens.
  - Names it a deadlock (not just a slow call).
  - Proposes keeping the API asynchronous (completion handler, notify, or async/await) instead of blocking.
solution: |
  `semaphore.wait()` blocks the main thread until someone calls `signal()`. The only `signal()` is inside the SDK's callback, and the SDK delivers that callback on the main queue, which runs closures only when the main thread is free. The main thread waits for the callback; the callback waits for the main thread. It's a deadlock, not a slow call: it will never finish, and the watchdog eventually kills the app.

  You can't turn an asynchronous API into a synchronous one on the thread it calls back on. Keep it asynchronous: `func currentToken(completion: @escaping (String) -> Void)` that passes the callback through, or an `async` function with a continuation (Module 26 previewed it; Module 29 covers it). Then whoever needs the token continues from the callback instead of waiting for it.
````

````exercise
id: m28-l03-e6
type: fill-in
prompt: "Complete the semaphore that limits uploads to three at a time and always gives its slot back."
code: |
  let slots = DispatchSemaphore([[1]]: 3)

  for file in files {
      DispatchQueue.global(qos: .utility).async(group: group) {
          slots.[[2]]()
          [[3]] { slots.[[4]]() }
          upload(file)
      }
  }
blanks:
  - id: "1"
    answers: ["value"]
  - id: "2"
    answers: ["wait"]
  - id: "3"
    answers: ["defer"]
  - id: "4"
    answers: ["signal"]
hints:
  - "The initializer takes the starting count."
  - "Take a slot before the work; give it back on every way out of the closure."
solution: |
  `DispatchSemaphore(value: 3)` starts with three slots. `slots.wait()` takes one (blocking if none are free), and `defer { slots.signal() }` gives it back when the closure exits, even if `upload` throws or returns early in a later version. Remember the cost: every upload waiting for a slot still holds a thread, so for hundreds of files an operation queue with `maxConcurrentOperationCount = 3` (lesson 4) is the better tool.
````

## Summary

- A `DispatchGroup` counts unfinished work. Use `async(group:)` for closures that finish when they return, and `enter()`/`leave()` around callback-based work, with exactly one `leave()` on every path.
- `notify(queue:)` runs a closure when the group finishes, without blocking. `wait()` blocks; it's fine in a background job, a command-line tool or a test, and wrong on the main thread.
- Reader-writer with GCD: a private concurrent queue, `sync` for reads, `async(flags: .barrier)` for writes. On a serial queue or a global queue, a barrier behaves like a plain `async`.
- `DispatchSemaphore(value: N)` lets N holders through. Pair every `wait()` with a `signal()` (use `defer`).
- Never wait on the main thread for something that needs the main thread: it deadlocks. And every work item blocked on a semaphore or lock holds a thread, so many of them cause thread explosion; gate submission, use an operation queue's limit, or move to Swift Concurrency.
