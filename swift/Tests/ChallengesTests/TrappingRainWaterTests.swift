import Testing
@testable import Challenges

@Suite("Trapping Rain Water")
struct TrappingRainWaterTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(trappedWater([3, 0, 2, 0, 4]) == 7)
        #expect(trappedWater([1, 0, 2, 1, 0, 1, 3, 1, 2]) == 6)
        #expect(trappedWater([1, 2, 3]) == 0)
    }

    @Test("Empty, one and two columns")
    func tiny() {
        #expect(trappedWater([]) == 0)
        #expect(trappedWater([5]) == 0)
        #expect(trappedWater([5, 0]) == 0)
    }

    @Test("A valley and a peak")
    func shapes() {
        #expect(trappedWater([5, 4, 3, 4, 5]) == 4)
        #expect(trappedWater([1, 3, 5, 3, 1]) == 0)
    }

    @Test("Flat ground and equal walls")
    func flat() {
        #expect(trappedWater([2, 2, 2]) == 0)
        #expect(trappedWater([4, 0, 0, 4]) == 8)
    }

    @Test("All three versions agree on random heights")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 15)
        for _ in 0..<1_000 {
            let heights = (0..<generator.next(below: 15)).map { _ in generator.next(below: 7) }
            let slow = trappedWaterBruteForce(heights)
            #expect(trappedWater(heights) == slow)
            #expect(trappedWaterWithPrefixMaxima(heights) == slow)
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
