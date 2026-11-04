---
id: debounce-and-throttle
title: Debounce and Throttle
difficulty: medium
order: 97
patterns: [State machine, Injected clock, Deterministic testing]
prerequisites: [m11-l04, m33-l04]
summary: Write a debouncer and a leading-and-trailing throttler as plain Swift state machines that read time from an injected clock, so tests run in microseconds without sleeping.
solutionFile: DebounceAndThrottle.swift
testFile: DebounceAndThrottleTests.swift
starter: |
  final class EventDebouncer<Value> {
      init(interval: Int, now: @escaping () -> Int) {
          // Your solution
      }

      var nextDeadline: Int? { nil }

      func send(_ value: Value) {
          // Your solution
      }

      func flushIfDue() -> Value? {
          // Your solution
          return nil
      }
  }

  final class EventThrottler<Value> {
      init(interval: Int, now: @escaping () -> Int) {
          // Your solution
      }

      var nextDeadline: Int? { nil }

      func send(_ value: Value) -> Value? {
          // Your solution
          return nil
      }

      func flushIfDue() -> Value? {
          // Your solution
          return nil
      }
  }
time: O(1) per call
space: O(1)
edgeCases:
  - Several events at the same instant (the latest one wins)
  - An event exactly at a deadline
  - A flush before the deadline, which must change nothing
  - A flush long after the deadline, which still delivers the value once
  - A throttle window that ends with nothing held, which goes idle
  - An event after the throttler went idle, which goes out at once
askInterviewer:
  - For the throttle, do you want the first event (leading edge), the last one (trailing edge) or both?
  - When several events arrive in a window, which one should the trailing edge deliver?
  - What drives the timing in the app, a timer, a display link, or Swift Concurrency?
  - What unit is time in, and is the clock monotonic?
hints:
  - A debouncer only needs to remember one thing besides the interval. What is it?
  - If the type can't schedule anything, someone else has to call it at the right time. What does it need to tell that someone?
  - For the throttle, list its states. When idle, what happens to an event? When a window is open? When the window ends with a held value? Without one?
followUps:
  - Wire these to a real timer with an injected `Clock`, so the app sleeps until `nextDeadline` and tests use a manual clock.
  - Add a maximum wait to the debouncer, so a user who never stops typing still gets a search every two seconds.
  - Make them safe for concurrent callers.
rubric:
  - I explained why a Task.sleep debounce is hard to test and what injecting the clock changes.
  - I described each type as a small state machine and listed its states.
  - I exposed the next deadline so a driver knows when to call.
  - I tested edge timings (exactly at the deadline, same instant) without sleeping.
codeStatus: tested
---

A search field shouldn't hit the server on every keystroke, and a scroll handler shouldn't run a layout pass on every frame. Build two small types, with time read from an injected `now` closure (milliseconds, never going backward). Neither type sleeps or schedules anything; whoever drives it (a timer, a run loop, a test) calls `flushIfDue()`, and `nextDeadline` says when that call will produce something.

**`EventDebouncer`** emits a value only after `interval` milliseconds pass with no newer one. `send(value)` replaces the pending value and restarts the wait. `flushIfDue()` returns the pending value once its deadline (`send` time + `interval`) has arrived, and clears it; otherwise it returns `nil`.

**`EventThrottler`** emits at most one value per window, on both edges. When it's idle, `send(value)` returns the value at once (the leading edge) and opens a window of `interval`. While a window is open, `send` returns `nil` and holds the value; a later `send` replaces it. When the window ends, `flushIfDue()` returns the held value (the trailing edge) and opens a new window from that moment. A window that ends with nothing held closes, and the throttler is idle again.

```swift
final class ManualClock { var now = 0 }
let clock = ManualClock()

let debouncer = EventDebouncer<String>(interval: 300, now: { clock.now })
debouncer.send("s")          // at 0
clock.now = 100
debouncer.send("sw")
clock.now = 250
debouncer.send("swi")        // nextDeadline is now 550
clock.now = 549
debouncer.flushIfDue()       // nil
clock.now = 550
debouncer.flushIfDue()       // "swi"

let throttler = EventThrottler<String>(interval: 100, now: { clock.now })
clock.now = 1_000
throttler.send("a")          // "a": leading edge, window until 1,100
clock.now = 1_030
throttler.send("b")          // nil: held
clock.now = 1_060
throttler.send("c")          // nil: replaces "b"
clock.now = 1_100
throttler.flushIfDue()       // "c": trailing edge, new window until 1,200
clock.now = 1_200
throttler.flushIfDue()       // nil: nothing held, so the throttler goes idle
```

**Constraints:** `1 ≤ interval ≤ 60,000`.

<!-- reveal -->

## First approach

Each type is a tiny state machine. The debouncer is either empty or holding one value with a deadline. The throttler is idle, or has a window open with or without a held value. All a call has to do is read the clock, compare it with a stored deadline, and move to the next state. The awkward part in real code is time itself, and Module 33, lesson 4 showed the fix: don't let the type read or wait on real time; inject it.

## Naive solution

The usual debounce in an app cancels and restarts a sleeping task:

```swift
@MainActor
final class SearchDebouncer {
    private var pending: Task<Void, Never>?

    func send(_ query: String, action: @escaping @MainActor (String) -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            action(query)
        }
    }
}
```

## Problems with the naive solution

It works in the app, but it's hard to test. A test has to sleep for longer than 300 ms and hope the scheduler ran the task by then, which makes the suite slow and, on a busy CI machine, flaky. You also can't check the interesting cases, like a keystroke exactly at the deadline, because you can't control when "now" is. The `try?` is load-bearing: it swallows the `CancellationError`, which is why the `isCancelled` check after it is needed. The logic and the timing are tangled in one closure.

## Optimized solution

Separate the decision from the waiting. Both types store deadlines as numbers and read the time through `now`, so a test sets the clock and calls methods in any order it likes. The app keeps the waiting part outside: sleep until `nextDeadline` (with an injected `Clock`), then call `flushIfDue()`.

## Line by line

- `EventDebouncer.pending: (value: Value, deadline: Int)?`: the whole state. `nil` means nothing to deliver.
- `send`: `pending = (value, now() + interval)`. Replacing the tuple both drops the older value and restarts the wait.
- `flushIfDue`: `guard let pending, now() >= pending.deadline else { return nil }` keeps early calls side-effect free. `>=` means a flush exactly at the deadline delivers, and a late flush still delivers, once, because `self.pending = nil` clears it.
- `EventThrottler.windowEnd: Int?`: `nil` means idle. `held: Value?` is the value waiting for the trailing edge.
- `send`, inside an open window (`time < windowEnd`): hold the value, replacing any older one, and return `nil`.
- `send`, otherwise: the throttler is idle (or the window has run out), so this is a leading edge. `held = nil` drops anything left from a window nobody flushed, `windowEnd = time + interval` opens the window, and the value is returned.
- `flushIfDue`, before the window ends: `return nil` and change nothing.
- `flushIfDue`, at the end with nothing held: `self.windowEnd = nil`, idle again.
- `flushIfDue`, at the end with a held value: return it and open a new window from now, so trailing emissions are spaced at least `interval` apart too.
- Both `nextDeadline` properties expose the stored deadline so a driver knows when to call back.

## Common mistakes

- Reading `Date()` or calling `Task.sleep` inside the logic, which brings real time back into every test.
- Letting `flushIfDue` deliver the same value twice because it doesn't clear the pending state.
- A throttle that drops the trailing value, so the last scroll position or the last keystroke is never processed.
- Opening the new window from the old deadline instead of the flush time when a flush is late, which can put the next emission less than `interval` after this one.

## Variation

**Debounce with a maximum wait:** keep the time the first value of a burst arrived. `flushIfDue` delivers when either the quiet deadline or `firstArrival + maxWait` has passed, so continuous typing still triggers a search every `maxWait` milliseconds.
