import Testing
@testable import Challenges

@Suite("Sliding Window Rate Limiter")
struct SlidingWindowRateLimiterTests {
    @Test("Example from the problem statement")
    func example() {
        let clock = RateLimiterTestClock()
        let limiter = SlidingWindowRateLimiter(limit: 3, window: 1_000, now: { clock.now })
        #expect(limiter.allow("ana"))
        clock.now = 200
        #expect(limiter.allow("ana"))
        clock.now = 400
        #expect(limiter.allow("ana"))
        clock.now = 900
        #expect(!limiter.allow("ana"))      // 0, 200 and 400 are still inside (−100, 900]
        #expect(limiter.allow("ben"))       // keys are independent
        clock.now = 1_000
        #expect(limiter.allow("ana"))       // the request at 0 has left the window
        #expect(!limiter.allow("ana"))
    }

    @Test("The window's lower edge is exclusive")
    func edge() {
        let clock = RateLimiterTestClock()
        let limiter = SlidingWindowRateLimiter(limit: 1, window: 10, now: { clock.now })
        #expect(limiter.allow("k"))
        clock.now = 9
        #expect(!limiter.allow("k"))
        clock.now = 10
        #expect(limiter.allow("k"))
    }

    @Test("Rejected requests don't use up the allowance")
    func rejectedNotRecorded() {
        let clock = RateLimiterTestClock()
        let limiter = SlidingWindowRateLimiter(limit: 2, window: 100, now: { clock.now })
        #expect(limiter.allow("k"))
        #expect(limiter.allow("k"))
        for time in stride(from: 10, through: 90, by: 10) {
            clock.now = time
            #expect(!limiter.allow("k"))
        }
        clock.now = 100
        #expect(limiter.allow("k"))
        #expect(limiter.allow("k"))
    }

    @Test("Many requests at the same instant")
    func burst() {
        let clock = RateLimiterTestClock()
        clock.now = 5_000
        let limiter = SlidingWindowRateLimiter(limit: 4, window: 1, now: { clock.now })
        let results = (0..<10).map { _ in limiter.allow("k") }
        #expect(results.filter { $0 }.count == 4)
        clock.now = 5_001
        #expect(limiter.allow("k"))
    }

    @Test("Agrees with counting every accepted request on random traffic")
    func agreesWithBruteForce() {
        var generator = RateLimiterLCG(seed: 600)
        let keys = ["a", "b", "c"]
        for _ in 0..<100 {
            let clock = RateLimiterTestClock()
            let limit = 1 + generator.next(below: 4)
            let window = 1 + generator.next(below: 50)
            let fast = SlidingWindowRateLimiter(limit: limit, window: window, now: { clock.now })
            let slow = SlidingWindowRateLimiterBruteForce(limit: limit, window: window, now: { clock.now })
            for _ in 0..<200 {
                clock.now += generator.next(below: 3) == 0 ? 0 : generator.next(below: 20)
                let key = keys[generator.next(below: keys.count)]
                #expect(fast.allow(key) == slow.allow(key))
            }
        }
    }
}

/// A clock the test moves by hand.
private final class RateLimiterTestClock {
    var now = 0
}

/// Deterministic generator so failures reproduce.
private struct RateLimiterLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
