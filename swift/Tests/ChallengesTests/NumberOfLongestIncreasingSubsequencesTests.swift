import Testing
@testable import Challenges

@Suite("Number of Longest Increasing Subsequences")
struct NumberOfLongestIncreasingSubsequencesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(countLongestIncreasing([3, 1, 4, 2, 5]) == 3)
        #expect(countLongestIncreasing([2, 6, 4, 8]) == 2)
        #expect(countLongestIncreasing([7, 7, 7]) == 3)
    }

    @Test("Empty and single element")
    func small() {
        #expect(countLongestIncreasing([]) == 0)
        #expect(countLongestIncreasing([42]) == 1)
    }

    @Test("Strictly decreasing: every element is its own longest subsequence")
    func decreasing() {
        #expect(countLongestIncreasing([5, 4, 3, 2, 1]) == 5)
    }

    @Test("Strictly increasing: exactly one")
    func increasing() {
        #expect(countLongestIncreasing([1, 2, 3, 4, 5, 6]) == 1)
    }

    @Test("Equal values never extend each other, and negatives work")
    func duplicatesAndNegatives() {
        #expect(countLongestIncreasing([-1, 3, 3, 5]) == 2)
        #expect(countLongestIncreasing([1, 2, 2, 2, 3]) == 3)
    }

    @Test("Counts grow multiplicatively")
    func multiplicative() {
        // Pairs (2, 1), (4, 3), (6, 5): pick one from each pair.
        #expect(countLongestIncreasing([2, 1, 4, 3, 6, 5]) == 8)
    }

    @Test("Agrees with checking every subset on random arrays")
    func agreesWithBruteForce() {
        var generator = LongestIncreasingLCG(seed: 2024)
        for _ in 0..<300 {
            let count = generator.next(below: 13)
            let nums = (0..<count).map { _ in generator.next(below: 8) - 3 }
            #expect(countLongestIncreasing(nums) == countLongestIncreasingBruteForce(nums), "\(nums)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct LongestIncreasingLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
