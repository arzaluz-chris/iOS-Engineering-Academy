/// Allows at most `limit` requests per key in any window of `window` milliseconds. A request at time
/// t is accepted if fewer than `limit` requests for its key were accepted at times in
/// (t - window, t]. Rejected requests aren't recorded, so they don't use up the allowance.
///
/// The time comes from the injected `now` closure, in milliseconds, which must never go backward
/// (in an app, read a monotonic clock such as `ContinuousClock`, not `Date`).
///
/// For each key, only the last `limit` accepted times are kept, in a ring buffer. When the buffer
/// is full, its oldest time decides: if that request is still inside the window, there are already
/// `limit` requests in it; if it's outside, so is every earlier one and there's room.
/// `allow` is O(1) on average (one dictionary access); O(keys × limit) space.
public final class SlidingWindowRateLimiter {
    private struct RecentRequests {
        var times: [Int] = []
        var oldestIndex = 0

        /// Records `time` and returns `true` if there's room in the window, otherwise returns `false`.
        mutating func admit(at time: Int, limit: Int, window: Int) -> Bool {
            if times.count < limit {
                times.append(time)
                return true
            }
            guard times[oldestIndex] <= time - window else { return false }
            times[oldestIndex] = time
            oldestIndex = (oldestIndex + 1) % limit
            return true
        }
    }

    private let limit: Int
    private let window: Int
    private let now: () -> Int
    private var recentByKey: [String: RecentRequests] = [:]

    public init(limit: Int, window: Int, now: @escaping () -> Int) {
        precondition(limit > 0 && window > 0, "limit and window must be positive")
        self.limit = limit
        self.window = window
        self.now = now
    }

    /// Returns whether a request for `key` is allowed right now, and records it if so.
    public func allow(_ key: String) -> Bool {
        let time = now()
        return recentByKey[key, default: RecentRequests()].admit(at: time, limit: limit, window: window)
    }
}

/// Naive solution: keep every accepted time per key and count the ones inside the window on each
/// call. O(r) per call, where r is the number of requests ever accepted for that key; O(total
/// accepted) space, which grows forever.
public final class SlidingWindowRateLimiterBruteForce {
    private let limit: Int
    private let window: Int
    private let now: () -> Int
    private var acceptedTimes: [String: [Int]] = [:]

    public init(limit: Int, window: Int, now: @escaping () -> Int) {
        self.limit = limit
        self.window = window
        self.now = now
    }

    public func allow(_ key: String) -> Bool {
        let time = now()
        let inWindow = acceptedTimes[key, default: []].filter { $0 > time - window }.count
        guard inWindow < limit else { return false }
        acceptedTimes[key, default: []].append(time)
        return true
    }
}
