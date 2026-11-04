---
id: concurrency-limiter-actor
title: Concurrency Limiter Actor
difficulty: medium
order: 99
patterns: [Actors, Continuations, FIFO queue]
prerequisites: [m28-l03, m29-l04, m29-l06]
summary: Build an async semaphore as an actor, so at most N downloads run at once and the rest wait their turn without blocking a thread. Tested with concurrent tasks and checks that only run after they all finish.
solutionFile: ConcurrencyLimiter.swift
testFile: ConcurrencyLimiterTests.swift
starter: |
  actor ConcurrencyLimiter {
      let limit: Int

      init(limit: Int) {
          self.limit = limit
      }

      func acquire() async {
          // Your solution
      }

      func release() {
          // Your solution
      }

      func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
          // Your solution
          try await operation()
      }
  }
time: O(1) amortized per acquire and release
space: O(w) for w waiting callers
edgeCases:
  - A limit of 1, which makes it a mutual-exclusion lock
  - Callers that arrive while all permits are taken, which must be served in order
  - A release with nobody waiting, which returns the permit to the pool
  - An operation that throws, which must still release its permit
  - Many more callers than permits
askInterviewer:
  - Should waiters be served in arrival order?
  - What happens if a waiting task is cancelled?
  - Is calling release() without a matching acquire() a programming error?
  - Do callers want acquire and release, a closure-based API, or both?
hints:
  - The actor's methods run one at a time, but every await inside them is a point where another caller can get in. Where must there be no await?
  - A caller with no permit has to suspend until someone calls release(). What lets you suspend now and be resumed later by other code?
  - When release() finds a waiter, should it add the permit to the pool or give it straight to that waiter? What could go wrong with the first option?
followUps:
  - Make a waiting caller give up when its task is cancelled. (withTaskCancellationHandler, removing its continuation from the queue.)
  - Why not use DispatchSemaphore inside an async function?
  - How would you test that the limit is actually reached, not just respected?
rubric:
  - I kept the check and the decrement in acquire() free of any await.
  - I suspended waiters with a continuation stored in a FIFO queue and resumed each exactly once.
  - I handed the permit directly to the next waiter on release.
  - I wrote tests whose assertions run after every task has finished, with no sleeps.
codeStatus: tested
---

An image feed starts a download for every cell that appears, and scrolling fast can start a hundred at once. Build an actor that lets at most `limit` operations hold a **permit** at the same time:

- `acquire()` takes a permit, or suspends until one is free. It must not block a thread.
- `release()` gives a permit back. If callers are waiting, the one that has waited longest gets it.
- `withPermit(operation)` runs `operation` while holding a permit and releases it however the operation ends, including when it throws.
- `availablePermits` and `waitingCount` report the current state (for tests and debugging).

```swift
let limiter = ConcurrencyLimiter(limit: 4)

await withTaskGroup(of: Void.self) { group in
    for url in thumbnailURLs {
        group.addTask {
            await limiter.withPermit {
                await downloadThumbnail(from: url)   // never more than 4 at once
            }
        }
    }
}
```

**Constraints:** `limit ≥ 1`. Calling `release()` more times than `acquire()` is a programming error.

<!-- reveal -->

## First approach

An actor gives you mutual exclusion for free, but only between suspension points (Module 29, lesson 4). So the "is there a free permit? take it" step must have no `await` in it. A caller that finds no permit has to wait without spinning, and a continuation (Module 29, lesson 6) is exactly a way to suspend now and let other code resume you later. Store those continuations in a queue, and `release()` resumes the first one.

## Naive solution

Keep a counter and poll until there's room:

```swift
actor PollingLimiter {
    private let limit: Int
    private var running = 0

    init(limit: Int) {
        self.limit = limit
    }

    func acquire() async {
        while running >= limit {
            await Task.yield()   // let other tasks run, then check again
        }
        running += 1
    }

    func release() {
        running -= 1
    }
}
```

## Problems with the naive solution

It's correct about the limit: the last check and the increment run with no `await` between them. But every waiting task keeps waking up, hopping onto the actor and checking again. With 100 waiters, the cooperative thread pool spends its time on those checks instead of on the downloads. There's no order either: whichever task happens to check right after a release wins, so an unlucky task can wait indefinitely. Replacing `Task.yield()` with `Task.sleep` cuts the CPU cost but adds latency and still isn't fair.

## Optimized solution

Keep a count of free permits and a FIFO queue of suspended callers' continuations. `acquire()` takes a free permit if there is one; otherwise it suspends with `withCheckedContinuation` and appends the continuation to the queue. `release()` resumes the first waiter if there is one, which **hands over** the permit without returning it to the pool; otherwise it adds the permit back. `withPermit` wraps the two with `defer`.

## Line by line

- `freePermits` starts at `limit`. `waiters` is the queue, and `firstWaiter` is the index of its front, so removing from the front is O(1).
- `acquire()`, fast path: `if freePermits > 0 { freePermits -= 1; return }` has no `await`, so two callers can't both take the last permit.
- `await withCheckedContinuation { continuation in waiters.append(continuation) }`: the closure runs right away, on the actor, before the caller suspends, so the continuation is in the queue before any other caller can run `release()`.
- When `acquire()` resumes, it doesn't check `freePermits` again: the permit came straight from `release()`.
- `release()` with nobody waiting: `freePermits += 1`, after a `precondition` that catches unbalanced calls.
- `release()` with waiters: take `waiters[firstWaiter]` and advance the index. When the resumed entries make up half the array, `removeFirst(firstWaiter)` drops them, which keeps memory bounded at O(1) amortized cost per call.
- `next.resume()`: each continuation is resumed exactly once. A checked continuation traps if resumed twice and logs a warning if it's never resumed.
- Handing the permit over matters. If `release()` incremented `freePermits` and resumed the waiter to try again, a new caller could arrive first, take the permit, and send the waiter back to the queue.
- `withPermit`: `defer { release() }` runs whether `operation` returns or throws. `release()` is synchronous and the method is isolated to the actor, so the `defer` can call it without `await`.
- The tests are deterministic because every assertion runs after the task group has finished: the peak number of operations running at once is at most `limit`, every operation finished, and all permits are back. The ordering test waits for each task to be queued (by polling `waitingCount` with `Task.yield()`) before starting the next, so the arrival order is known without any sleep.

## Common mistakes

- An `await` between the check and the decrement in `acquire()`, for example logging through another actor, which lets two callers take the last permit.
- Calling `DispatchSemaphore.wait()` inside an async function. It blocks a thread of the cooperative pool, and with enough waiters nothing is left to run the work that would signal it.
- Resuming a continuation twice, or forgetting one on some path, so a task hangs forever.
- Forgetting to release when the operation throws.
- Asserting on timing in tests ("after 50 ms, 3 are running"), which is flaky on a loaded CI machine.

## Variation

**Cancellation:** wrap the suspension in `withTaskCancellationHandler`. Give each waiter an ID, and when its task is cancelled, remove its continuation from the queue (on the actor) and resume it so `acquire()` can throw `CancellationError`. The tricky part is the race with `release()`: whichever runs first must take the continuation out of the queue, so it's resumed exactly once.
