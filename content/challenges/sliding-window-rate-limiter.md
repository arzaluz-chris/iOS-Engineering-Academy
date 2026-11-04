---
id: sliding-window-rate-limiter
title: Sliding Window Rate Limiter
difficulty: medium
order: 96
patterns: [Sliding window, Ring buffer, Injected clock]
prerequisites: [m17-l02, m33-l04]
summary: Allow at most N requests per key in any rolling time window, with time read from an injected clock. A queue of accepted timestamps that never needs to hold more than N of them.
solutionFile: SlidingWindowRateLimiter.swift
testFile: SlidingWindowRateLimiterTests.swift
starter: |
  final class SlidingWindowRateLimiter {
      init(limit: Int, window: Int, now: @escaping () -> Int) {
          // Your solution
      }

      func allow(_ key: String) -> Bool {
          // Your solution
          return false
      }
  }
time: O(1) per call on average
space: O(keys × limit)
edgeCases:
  - The first request for a key
  - A request exactly window milliseconds after an accepted one (the old one has left)
  - Many requests at the same instant
  - Rejected requests, which must not count against the key
  - Different keys, which never affect each other
askInterviewer:
  - Is the window rolling, or fixed buckets like "per calendar minute"?
  - Do rejected requests count toward the limit?
  - Is the window's lower edge inclusive or exclusive?
  - Where does the time come from? Can it go backward?
  - Does it need to be safe to call from several threads?
hints:
  - Keep the times of the accepted requests per key. Which of them matter for a request at time t?
  - Times arrive in order, so the oldest accepted time is always the first to leave the window. What structure gives you the oldest in O(1)?
  - You never need more than the last `limit` accepted times. If the oldest of those is still in the window, what does that tell you?
followUps:
  - Make it safe for concurrent callers. (Turn it into an actor; the method has no suspension points, so it's still atomic.)
  - Keys that stop sending keep their buffers forever. How would you clean them up?
  - Compare with a token bucket. Which allows bursts, and which is cheaper per key?
rubric:
  - I asked whether rejected requests count and where the time comes from.
  - I described the store-everything solution and why its time and memory grow.
  - I kept at most `limit` times per key and explained why the oldest of them decides.
  - I injected the clock and tested the window edge without sleeping.
codeStatus: tested
---

A networking layer must not send more than `limit` requests per user in any rolling window of `window` milliseconds, or the server starts returning 429s. Build `SlidingWindowRateLimiter`. `allow(key)` returns `true` and records the request if fewer than `limit` requests for that key were **accepted** at times in `(t - window, t]`, where `t` is the current time; otherwise it returns `false` and records nothing.

The time comes from the injected `now` closure, in milliseconds. It never goes backward. Tests pass a clock they move by hand, so nothing ever sleeps.

```swift
final class ManualClock { var now = 0 }   // a clock the test moves by hand

let clock = ManualClock()
let limiter = SlidingWindowRateLimiter(limit: 3, window: 1_000, now: { clock.now })
limiter.allow("ana")    // true  (time 0)
clock.now = 200
limiter.allow("ana")    // true
clock.now = 400
limiter.allow("ana")    // true
clock.now = 900
limiter.allow("ana")    // false: 0, 200 and 400 are all inside (-100, 900]
limiter.allow("ben")    // true:  keys are independent
clock.now = 1_000
limiter.allow("ana")    // true:  the request at 0 has left the window
```

**Constraints:** `1 ≤ limit ≤ 1,000`; `1 ≤ window ≤ 3,600,000`; up to `10^6` calls.

<!-- reveal -->

## First approach

For a request at `t`, only the accepted requests after `t - window` matter. Times only grow, so the oldest stored time is always the first to fall out of the window: a queue, as in the request counter from Module 17, lesson 2. There's one more saving here. A request is rejected only when `limit` accepted requests are already in the window, and rejected requests aren't stored, so you never need more than the last `limit` accepted times. If the oldest of those is still in the window, all of them are and the answer is no; if it's out, there's room.

## Naive solution

Store every accepted time and count the ones in the window on each call:

```swift
final class SlidingWindowRateLimiter {
    private let limit: Int
    private let window: Int
    private let now: () -> Int
    private var acceptedTimes: [String: [Int]] = [:]

    init(limit: Int, window: Int, now: @escaping () -> Int) {
        self.limit = limit
        self.window = window
        self.now = now
    }

    func allow(_ key: String) -> Bool {
        let time = now()
        let inWindow = acceptedTimes[key, default: []].filter { $0 > time - window }.count
        guard inWindow < limit else { return false }
        acceptedTimes[key, default: []].append(time)
        return true
    }
}
```

## Problems with the naive solution

The arrays never shrink. After a day of traffic, each call filters every request that user ever made: O(r) time per call and memory that grows without bound. Dropping old times from the front with `removeFirst()` bounds the memory but costs O(n) per removal on an `Array`.

## Optimized solution

For each key, keep a ring buffer of at most `limit` accepted times and the index of the oldest. While the buffer isn't full, accept and append. Once it's full, compare the oldest time with `t - window`: if it's still inside, reject; if not, overwrite it with `t` and advance the oldest index. Each call does one dictionary access and O(1) work.

## Line by line

- `struct RecentRequests`: the per-key state, `times` (at most `limit` entries) and `oldestIndex` (where the oldest time is once the buffer is full).
- `if times.count < limit { times.append(time); return true }`: fewer than `limit` requests were ever accepted for this key, so there's room.
- `guard times[oldestIndex] <= time - window else { return false }`: the window is `(t - window, t]`, so a time equal to `t - window` is outside. If the oldest of the last `limit` accepted times is inside, there are already `limit` requests in the window.
- `times[oldestIndex] = time` and `oldestIndex = (oldestIndex + 1) % limit`: the new time replaces the one that left, and the next-oldest becomes the oldest.
- `let time = now()`: read the clock once per call, so the whole decision uses one instant.
- `recentByKey[key, default: RecentRequests()].admit(...)`: calling a `mutating` method through the `default:` subscript changes the stored value in place. Copying it into a local `var`, mutating and writing it back would copy the array on every call, because two references to the buffer exist during the mutation.

## Common mistakes

- Recording rejected requests, so a client that keeps retrying stays locked out forever.
- Using a fixed window ("requests this minute"), which lets `2 × limit` requests through around a minute boundary.
- Reading `Date()` inside the limiter. Tests then need real sleeps, and the wall clock can jump backward when the user changes the time. Inject a monotonic clock.
- Off-by-one at the edge: decide whether a request exactly `window` ago counts and test that case.

## Variation

**Token bucket:** each key has a bucket of up to `limit` tokens that refills at `limit / window` tokens per millisecond. A request takes one token or is rejected. It stores two numbers per key (tokens and last refill time) instead of `limit` timestamps and allows a burst of `limit` after a quiet period, which is often what you want for a client.
