import Testing
@testable import Challenges

@Suite("Two Sum II (sorted input)")
struct TwoSumSortedTests {
    /// Checks that a returned pair is valid, since any valid pair is accepted.
    private func isValid(_ pair: (first: Int, second: Int)?, in sorted: [Int], target: Int) -> Bool {
        guard let pair else { return false }
        return pair.first < pair.second && sorted.indices.contains(pair.first)
            && sorted.indices.contains(pair.second)
            && sorted[pair.first] + sorted[pair.second] == target
    }

    /// The result as an array, so it can be compared with `==`.
    private func pair(_ sorted: [Int], _ target: Int) -> [Int]? {
        twoSumSorted(sorted, target).map { [$0.first, $0.second] }
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(pair([1, 4, 6, 9, 12], 15) == [2, 3])
        #expect(pair([-5, -2, 0, 3], -7) == [0, 1])
        #expect(pair([2, 3, 8], 4) == nil)
    }

    @Test("Equal values can form the pair, but one element can't pair with itself")
    func equalValues() {
        #expect(pair([1, 5, 5, 7], 10) == [1, 2])
        #expect(pair([1, 5, 7], 10) == nil)
    }

    @Test("Empty and one-element lists")
    func tiny() {
        #expect(pair([], 0) == nil)
        #expect(pair([4], 8) == nil)
    }

    @Test("The pair at the very ends")
    func ends() {
        #expect(pair([1, 2, 3, 4, 50], 51) == [0, 4])
    }

    @Test("Agrees with the naive solution on random sorted arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 12)
        for _ in 0..<2_000 {
            let sorted = (0..<generator.next(below: 10)).map { _ in generator.next(below: 21) - 10 }.sorted()
            let target = generator.next(below: 41) - 20
            let fast = twoSumSorted(sorted, target)
            let slow = twoSumSortedBruteForce(sorted, target)
            #expect((fast == nil) == (slow == nil))
            if fast != nil {
                #expect(isValid(fast, in: sorted, target: target))
            }
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
