import Testing
@testable import Challenges

@Suite("Longest Step Subsequence")
struct LongestStepSubsequenceTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(longestStepSubsequence([5, 1, 7, 3, 9, 5, 7], step: 2) == 4)
        #expect(longestStepSubsequence([4, 3, 2, 1], step: 1) == 1)
        #expect(longestStepSubsequence([4, 3, 2, 1], step: -1) == 4)
    }

    @Test("Empty input and a single element")
    func tiny() {
        #expect(longestStepSubsequence([], step: 3) == 0)
        #expect(longestStepSubsequence([42], step: 3) == 1)
    }

    @Test("A step of 0 counts the most repeated value")
    func zeroStep() {
        #expect(longestStepSubsequence([2, 7, 2, 7, 2], step: 0) == 3)
    }

    @Test("Order matters: an earlier larger value doesn't help")
    func orderMatters() {
        #expect(longestStepSubsequence([3, 2, 1], step: 1) == 1)
        #expect(longestStepSubsequence([1, 3, 2, 3], step: 1) == 3)
    }

    @Test("Negative values")
    func negatives() {
        #expect(longestStepSubsequence([-3, 0, -1, 1, -5, 2], step: 1) == 3)
    }

    @Test("Agrees with the naive solution and with checking every subsequence")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 10)
        for _ in 0..<500 {
            let values = (0..<generator.next(below: 10)).map { _ in generator.next(below: 9) - 4 }
            let step = generator.next(below: 5) - 2
            let fast = longestStepSubsequence(values, step: step)
            #expect(fast == longestStepSubsequenceBruteForce(values, step: step))
            #expect(fast == exhaustive(values, step: step))
        }
    }

    /// Checks all 2^n subsequences. Only for tiny inputs.
    private func exhaustive(_ values: [Int], step: Int) -> Int {
        var best = 0
        for mask in 0..<(1 << values.count) {
            let chosen = values.indices.filter { mask & (1 << $0) != 0 }.map { values[$0] }
            if zip(chosen, chosen.dropFirst()).allSatisfy({ $1 - $0 == step }) {
                best = max(best, chosen.count)
            }
        }
        return best
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
