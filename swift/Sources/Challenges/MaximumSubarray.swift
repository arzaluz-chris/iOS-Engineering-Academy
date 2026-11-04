/// Returns the largest sum of a non-empty run of consecutive elements. `nums` must not be empty.
///
/// Kadane's algorithm: `bestEndingHere` is the best sum of a run that ends at the current element.
/// Either the run continues from the previous element, or it starts over here; it starts over when
/// the previous run's sum is negative, because a negative prefix only makes things worse.
/// O(n) time, O(1) extra space.
public func maximumSubarraySum(_ nums: [Int]) -> Int {
    precondition(!nums.isEmpty, "maximumSubarraySum needs at least one element")
    var bestEndingHere = nums[0]
    var best = nums[0]
    for value in nums.dropFirst() {
        bestEndingHere = max(value, bestEndingHere + value)
        best = max(best, bestEndingHere)
    }
    return best
}

/// Naive solution: try every start and extend the run one element at a time.
/// O(n²) time, O(1) extra space.
public func maximumSubarraySumBruteForce(_ nums: [Int]) -> Int {
    precondition(!nums.isEmpty, "maximumSubarraySumBruteForce needs at least one element")
    var best = nums[0]
    for start in nums.indices {
        var sum = 0
        for end in start..<nums.count {
            sum += nums[end]
            best = max(best, sum)
        }
    }
    return best
}
