import Testing
@testable import Challenges

@Suite("Two Sum")
struct TwoSumTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(twoSum([2, 7, 11, 15], 9) == [0, 1])
        #expect(twoSum([3, 2, 4], 6) == [1, 2])
        #expect(twoSum([3, 3], 6) == [0, 1])
    }

    @Test("An element doesn't pair with itself")
    func doesNotReuseSameIndex() {
        #expect(twoSum([3, 5], 6) == nil)
    }

    @Test("No solution")
    func noSolution() {
        #expect(twoSum([1, 2, 3], 100) == nil)
        #expect(twoSum([], 0) == nil)
        #expect(twoSum([5], 5) == nil)
    }

    @Test("Negatives and zero")
    func negatives() {
        #expect(twoSum([-3, 4, 3, 90], 0) == [0, 2])
        #expect(twoSum([0, 4, 3, 0], 0) == [0, 3])
    }

    @Test("Optimized solution agrees with the naive one", arguments: [
        ([2, 7, 11, 15], 9),
        ([1, 5, 1, 5], 10),
        ([4, -2, 8, 0, 6], 6),
        ([1, 2, 3], 7),
    ])
    func agreesWithBruteForce(nums: [Int], target: Int) {
        let fast = twoSum(nums, target)
        let slow = twoSumBruteForce(nums, target)
        #expect((fast == nil) == (slow == nil))
        if let fast {
            #expect(fast[0] < fast[1])
            #expect(nums[fast[0]] + nums[fast[1]] == target)
        }
    }
}
