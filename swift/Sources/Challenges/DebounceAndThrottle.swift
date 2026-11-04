/// Emits a value only after `interval` milliseconds pass with no newer value: each `send` replaces
/// the pending value and restarts the wait. The time comes from the injected `now` closure, so the
/// type never sleeps or schedules anything. Whoever drives it (a timer, a run loop tick, a test)
/// calls `flushIfDue()`; `nextDeadline` says when that call will produce something.
///
/// `send` and `flushIfDue` are O(1); O(1) space.
public final class EventDebouncer<Value> {
    private let interval: Int
    private let now: () -> Int
    private var pending: (value: Value, deadline: Int)?

    public init(interval: Int, now: @escaping () -> Int) {
        precondition(interval > 0, "interval must be positive")
        self.interval = interval
        self.now = now
    }

    /// The time at which the pending value becomes due, or `nil` if nothing is pending.
    public var nextDeadline: Int? { pending?.deadline }

    /// Replaces the pending value and restarts the wait.
    public func send(_ value: Value) {
        pending = (value, now() + interval)
    }

    /// Returns the pending value if its deadline has arrived, and clears it.
    public func flushIfDue() -> Value? {
        guard let pending, now() >= pending.deadline else { return nil }
        self.pending = nil
        return pending.value
    }
}

/// Emits at most one value per `interval` milliseconds, on both edges. When it's idle, a value goes
/// out at once (the leading edge) and opens a window of `interval`. Values sent while the window is
/// open aren't emitted; the latest one is held and goes out when the window ends (the trailing edge),
/// which opens a new window. A window that ends with nothing held closes, and the throttler is idle.
/// The time comes from the injected `now` closure; whoever drives it calls `flushIfDue()` when
/// `nextDeadline` arrives.
///
/// `send` and `flushIfDue` are O(1); O(1) space.
public final class EventThrottler<Value> {
    private let interval: Int
    private let now: () -> Int
    private var windowEnd: Int?
    private var held: Value?

    public init(interval: Int, now: @escaping () -> Int) {
        precondition(interval > 0, "interval must be positive")
        self.interval = interval
        self.now = now
    }

    /// When the open window ends, or `nil` if the throttler is idle.
    public var nextDeadline: Int? { windowEnd }

    /// Returns `value` if it goes out now (leading edge); otherwise holds it and returns `nil`.
    public func send(_ value: Value) -> Value? {
        let time = now()
        if let windowEnd, time < windowEnd {
            held = value
            return nil
        }
        held = nil
        windowEnd = time + interval
        return value
    }

    /// At the end of a window, returns the held value (trailing edge) and opens a new window,
    /// or closes the window if nothing is held. Before the end, returns `nil` and changes nothing.
    public func flushIfDue() -> Value? {
        let time = now()
        guard let windowEnd, time >= windowEnd else { return nil }
        guard let value = held else {
            self.windowEnd = nil
            return nil
        }
        held = nil
        self.windowEnd = time + interval
        return value
    }
}
