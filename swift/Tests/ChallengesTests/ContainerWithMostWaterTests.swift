import Testing
@testable import Challenges

@Suite("Container With Most Water")
struct ContainerWithMostWaterTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(largestTank([3, 8, 4, 2, 7, 5]) == 21)
        #expect(largestTank([4, 4]) == 4)
        #expect(largestTank([1, 2, 3, 4, 5]) == 6)
    }

    @Test("Fewer than two boards hold nothing")
    func tooFew() {
        #expect(largestTank([]) == 0)
        #expect(largestTank([10]) == 0)
    }

    @Test("Boards of height 0")
    func zeros() {
        #expect(largestTank([0, 0, 0]) == 0)
        #expect(largestTank([0, 5, 0, 5, 0]) == 10)
    }

    @Test("Equal heights at both ends")
    func equalEnds() {
        #expect(largestTank([6, 1, 9, 9, 1, 6]) == 30)
    }

    @Test("Agrees with the naive solution on random heights")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 14)
        for _ in 0..<1_000 {
            let heights = (0..<generator.next(below: 15)).map { _ in generator.next(below: 10) }
            #expect(largestTank(heights) == largestTankBruteForce(heights))
        }
    }
}

/// Small deterministic generator (a linear congruential generator) so failures reproduce.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A value in `0..<bound`.
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
