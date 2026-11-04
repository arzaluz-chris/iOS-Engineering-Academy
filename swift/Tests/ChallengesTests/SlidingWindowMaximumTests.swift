import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

@Suite("Sliding Window Maximum")
struct SlidingWindowMaximumTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(slidingWindowMaximum([4, 2, 12, 3, 8, 7, 1, 5], 3) == [12, 12, 12, 8, 8, 7])
        #expect(slidingWindowMaximum([9, 8, 7, 6], 2) == [9, 8, 7])
        #expect(slidingWindowMaximum([5], 1) == [5])
    }

    @Test("k equal to 1 returns the input")
    func windowOfOne() {
        #expect(slidingWindowMaximum([3, -1, 4], 1) == [3, -1, 4])
    }

    @Test("k equal to the count returns one maximum")
    func windowOfAll() {
        #expect(slidingWindowMaximum([3, 9, 4, 1], 4) == [9])
    }

    @Test("Increasing and decreasing input")
    func monotonicInput() {
        #expect(slidingWindowMaximum([1, 2, 3, 4, 5], 2) == [2, 3, 4, 5])
        #expect(slidingWindowMaximum([5, 4, 3, 2, 1], 3) == [5, 4, 3])
    }

    @Test("Equal values and negatives")
    func duplicates() {
        #expect(slidingWindowMaximum([2, 2, 2, 2], 2) == [2, 2, 2])
        #expect(slidingWindowMaximum([-7, -3, -9, -3, -8], 2) == [-3, -3, -3, -3])
    }

    @Test("Invalid k returns an empty array")
    func invalidWindow() {
        #expect(slidingWindowMaximum([], 1) == [])
        #expect(slidingWindowMaximum([1, 2], 3) == [])
        #expect(slidingWindowMaximum([1, 2], 0) == [])
    }

    @Test("Random arrays agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 314)
        for _ in 0..<500 {
            let count = 1 + generator.next(below: 20)
            let values = (0..<count).map { _ in generator.next(below: 9) - 4 }
            let k = 1 + generator.next(below: count)
            #expect(slidingWindowMaximum(values, k) == slidingWindowMaximumBruteForce(values, k), "values: \(values), k: \(k)")
        }
    }
}
