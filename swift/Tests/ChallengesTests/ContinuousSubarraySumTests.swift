import Testing
@testable import Challenges

@Suite("Continuous Subarray Sum")
struct ContinuousSubarraySumTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(hasStretchSummingToMultiple([5, 7, 2, 4], of: 6))
        #expect(hasStretchSummingToMultiple([5, 7, 2, 3], of: 8) == false)
        #expect(hasStretchSummingToMultiple([12, 5], of: 12) == false)
    }

    @Test("A single multiple isn't enough; it needs a partner")
    func lengthTwo() {
        #expect(hasStretchSummingToMultiple([6], of: 6) == false)
        #expect(hasStretchSummingToMultiple([6, 0], of: 6))
        #expect(hasStretchSummingToMultiple([0, 0], of: 5))
    }

    @Test("Empty input")
    func empty() {
        #expect(hasStretchSummingToMultiple([], of: 3) == false)
    }

    @Test("k of 1 accepts any two elements")
    func kIsOne() {
        #expect(hasStretchSummingToMultiple([3, 8], of: 1))
    }

    @Test("Negative values and negative remainders")
    func negatives() {
        #expect(hasStretchSummingToMultiple([-4, 1], of: 3))
        #expect(hasStretchSummingToMultiple([2, -5, 1], of: 7) == false)
        #expect(hasStretchSummingToMultiple([-1, 3, 5], of: 7))
    }

    @Test("Agrees with the naive solution on random arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 21)
        for _ in 0..<2_000 {
            let values = (0..<generator.next(below: 8)).map { _ in generator.next(below: 21) - 10 }
            let k = generator.next(below: 12) + 1
            #expect(hasStretchSummingToMultiple(values, of: k) == hasStretchSummingToMultipleBruteForce(values, of: k))
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
