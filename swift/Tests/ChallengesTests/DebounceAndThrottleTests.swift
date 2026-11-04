import Testing
@testable import Challenges

@Suite("Debounce and Throttle")
struct DebounceAndThrottleTests {
    @Test("Debounce example from the problem statement")
    func debounceExample() {
        let clock = DebounceTestClock()
        let debouncer = EventDebouncer<String>(interval: 300, now: { clock.now })
        debouncer.send("s")
        clock.now = 100
        debouncer.send("sw")
        clock.now = 250
        debouncer.send("swi")
        #expect(debouncer.nextDeadline == 550)
        clock.now = 549
        #expect(debouncer.flushIfDue() == nil)
        clock.now = 550
        #expect(debouncer.flushIfDue() == "swi")
        #expect(debouncer.flushIfDue() == nil)       // emitted once
        #expect(debouncer.nextDeadline == nil)
    }

    @Test("Debounce: a quiet debouncer emits nothing")
    func debounceIdle() {
        let clock = DebounceTestClock()
        let debouncer = EventDebouncer<Int>(interval: 10, now: { clock.now })
        clock.now = 1_000
        #expect(debouncer.flushIfDue() == nil)
    }

    @Test("Debounce: a late flush still delivers the latest value")
    func debounceLateFlush() {
        let clock = DebounceTestClock()
        let debouncer = EventDebouncer<Int>(interval: 10, now: { clock.now })
        debouncer.send(1)
        debouncer.send(2)
        clock.now = 500
        #expect(debouncer.flushIfDue() == 2)
    }

    @Test("Throttle example from the problem statement")
    func throttleExample() {
        let clock = DebounceTestClock()
        let throttler = EventThrottler<String>(interval: 100, now: { clock.now })
        #expect(throttler.send("a") == "a")          // leading edge
        clock.now = 30
        #expect(throttler.send("b") == nil)
        clock.now = 60
        #expect(throttler.send("c") == nil)
        #expect(throttler.nextDeadline == 100)
        clock.now = 100
        #expect(throttler.flushIfDue() == "c")       // trailing edge: the latest, b is dropped
        clock.now = 150
        #expect(throttler.send("d") == nil)
        clock.now = 200
        #expect(throttler.flushIfDue() == "d")
        clock.now = 300
        #expect(throttler.flushIfDue() == nil)       // nothing held: the window closes
        #expect(throttler.nextDeadline == nil)
        clock.now = 310
        #expect(throttler.send("e") == "e")          // idle again: leading edge
    }

    @Test("Throttle: a flush before the window ends does nothing")
    func throttleEarlyFlush() {
        let clock = DebounceTestClock()
        let throttler = EventThrottler<Int>(interval: 50, now: { clock.now })
        #expect(throttler.send(1) == 1)
        #expect(throttler.send(2) == nil)
        clock.now = 49
        #expect(throttler.flushIfDue() == nil)
        clock.now = 50
        #expect(throttler.flushIfDue() == 2)
    }

    @Test("Agree with an event-by-event reference on random timelines")
    func agreeWithReference() {
        var generator = DebounceLCG(seed: 90)
        for _ in 0..<150 {
            let interval = 1 + generator.next(below: 30)
            var time = 0
            var events: [(time: Int, value: Int)] = []
            for value in 0..<generator.next(below: 25) {
                time += generator.next(below: 3) == 0 ? 0 : generator.next(below: 45)
                events.append((time, value))
            }
            let end = time + 3 * interval

            // Drive both types one millisecond at a time: flush first, then deliver that instant's events.
            let clock = DebounceTestClock()
            let debouncer = EventDebouncer<Int>(interval: interval, now: { clock.now })
            let throttler = EventThrottler<Int>(interval: interval, now: { clock.now })
            var debounced: [DebounceEmission] = []
            var throttled: [DebounceEmission] = []
            var next = 0
            for now in 0...end {
                clock.now = now
                if let value = debouncer.flushIfDue() { debounced.append(DebounceEmission(time: now, value: value)) }
                if let value = throttler.flushIfDue() { throttled.append(DebounceEmission(time: now, value: value)) }
                while next < events.count && events[next].time == now {
                    debouncer.send(events[next].value)
                    if let value = throttler.send(events[next].value) {
                        throttled.append(DebounceEmission(time: now, value: value))
                    }
                    next += 1
                }
            }
            #expect(debounced == referenceDebounce(events, interval: interval))
            #expect(throttled == referenceThrottle(events, interval: interval))
        }
    }
}

private struct DebounceEmission: Equatable {
    let time: Int
    let value: Int
}

/// An event survives the debounce if the next one comes at least `interval` later.
private func referenceDebounce(_ events: [(time: Int, value: Int)], interval: Int) -> [DebounceEmission] {
    events.indices.compactMap { index in
        let isLast = index == events.count - 1
        guard isLast || events[index + 1].time >= events[index].time + interval else { return nil }
        return DebounceEmission(time: events[index].time + interval, value: events[index].value)
    }
}

/// Walks the events in order, closing every window that ends before each one.
private func referenceThrottle(_ events: [(time: Int, value: Int)], interval: Int) -> [DebounceEmission] {
    var output: [DebounceEmission] = []
    var windowEnd: Int?
    var held: Int?
    func closeWindows(through time: Int) {
        while let end = windowEnd, end <= time {
            if let value = held {
                output.append(DebounceEmission(time: end, value: value))
                held = nil
                windowEnd = end + interval
            } else {
                windowEnd = nil
            }
        }
    }
    for event in events {
        closeWindows(through: event.time)
        if let end = windowEnd, event.time < end {
            held = event.value
        } else {
            windowEnd = event.time + interval
            output.append(DebounceEmission(time: event.time, value: event.value))
        }
    }
    closeWindows(through: Int.max)
    return output
}

/// A clock the test moves by hand.
private final class DebounceTestClock {
    var now = 0
}

/// Deterministic generator so failures reproduce.
private struct DebounceLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
