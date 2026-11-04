import Testing
@testable import Challenges

@Suite("Maximum Subarray")
struct MaximumSubarrayTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(maximumSubarraySum([-3, 5, -1, 4, -10, 2]) == 8)
        #expect(maximumSubarraySum([-4, -2, -7]) == -2)
        #expect(maximumSubarraySum([2, -1, 2]) == 3)
    }

    @Test("A single element")
    func single() {
        #expect(maximumSubarraySum([6]) == 6)
        #expect(maximumSubarraySum([-6]) == -6)
    }

    @Test("All positive: the whole array")
    func allPositive() {
        #expect(maximumSubarraySum([1, 2, 3, 4]) == 10)
    }

    @Test("Zeros")
    func zeros() {
        #expect(maximumSubarraySum([0, 0, 0]) == 0)
        #expect(maximumSubarraySum([-1, 0, -2]) == 0)
    }

    @Test("A deep dip splits two good runs")
    func dip() {
        #expect(maximumSubarraySum([5, 5, -20, 6, 6]) == 12)
        #expect(maximumSubarraySum([5, 5, -3, 6, 6]) == 19)
    }

    @Test("Agrees with trying every run on random arrays")
    func agreesWithBruteForce() {
        var generator = MaximumSubarrayLCG(seed: 2718)
        for _ in 0..<500 {
            let nums = (0..<(1 + generator.next(below: 20))).map { _ in generator.next(below: 41) - 20 }
            #expect(maximumSubarraySum(nums) == maximumSubarraySumBruteForce(nums), "\(nums)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct MaximumSubarrayLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
