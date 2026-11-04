import Testing
@testable import Challenges

@Suite("Three Sum")
struct ThreeSumTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(threeSum([3, -1, -2, 0, 1, -1]) == [[-2, -1, 3], [-1, 0, 1]])
        #expect(threeSum([1, 2, -4]) == [])
        #expect(threeSum([0, 0, 0, 0]) == [[0, 0, 0]])
    }

    @Test("Fewer than three elements")
    func tooShort() {
        #expect(threeSum([]) == [])
        #expect(threeSum([0]) == [])
        #expect(threeSum([1, -1]) == [])
    }

    @Test("Many duplicates produce each triple once")
    func duplicates() {
        #expect(threeSum([-2, -2, -2, 1, 1, 1, 4, 4]) == [[-2, -2, 4], [-2, 1, 1]])
    }

    @Test("All positive or all negative values have no answer")
    func oneSign() {
        #expect(threeSum([1, 2, 3, 4]) == [])
        #expect(threeSum([-1, -2, -3]) == [])
    }

    @Test("Agrees with the naive solution on random arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 13)
        for _ in 0..<1_000 {
            let nums = (0..<generator.next(below: 12)).map { _ in generator.next(below: 11) - 5 }
            #expect(threeSum(nums) == threeSumBruteForce(nums))
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
