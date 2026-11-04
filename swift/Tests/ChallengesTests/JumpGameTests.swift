import Testing
@testable import Challenges

@Suite("Jump Game")
struct JumpGameTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(canReachLastPlatform([1, 2, 0, 1]))
        #expect(!canReachLastPlatform([3, 1, 0, 0, 2]))
        #expect(canReachLastPlatform([4, 0, 0, 0, 1]))
    }

    @Test("A single platform is already the last one")
    func single() {
        #expect(canReachLastPlatform([0]))
        #expect(canReachLastPlatform([7]))
    }

    @Test("Empty input")
    func empty() {
        #expect(canReachLastPlatform([]))
    }

    @Test("Stuck at the first platform")
    func stuckAtStart() {
        #expect(!canReachLastPlatform([0, 1]))
    }

    @Test("A zero you can jump over")
    func jumpOverZero() {
        #expect(canReachLastPlatform([2, 0, 0]))
        #expect(!canReachLastPlatform([1, 0, 0]))
    }

    @Test("Agrees with marking reachable platforms on random inputs")
    func agreesWithBruteForce() {
        var generator = JumpGameLCG(seed: 314)
        for _ in 0..<500 {
            let jumps = (0..<generator.next(below: 15)).map { _ in generator.next(below: 4) }
            #expect(canReachLastPlatform(jumps) == canReachLastPlatformBruteForce(jumps), "\(jumps)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct JumpGameLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
