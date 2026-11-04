/// Returns how many strictly increasing subsequences of `nums` have the maximum possible length.
/// Two subsequences count as different when they use different positions, even if the values match.
/// An empty array has no subsequences to count, so the answer is 0.
///
/// For each index i, `length[i]` is the length of the longest increasing subsequence ending at i
/// and `count[i]` is how many of that length end there. Each j < i with nums[j] < nums[i] either
/// sets a new best length (copy its count) or ties it (add its count).
/// O(n²) time, O(n) space.
public func countLongestIncreasing(_ nums: [Int]) -> Int {
    guard !nums.isEmpty else { return 0 }
    var length = Array(repeating: 1, count: nums.count)
    var count = Array(repeating: 1, count: nums.count)
    for i in nums.indices {
        for j in 0..<i where nums[j] < nums[i] {
            if length[j] + 1 > length[i] {
                length[i] = length[j] + 1
                count[i] = count[j]
            } else if length[j] + 1 == length[i] {
                count[i] += count[j]
            }
        }
    }
    let longest = length.max()!
    var total = 0
    for i in nums.indices where length[i] == longest {
        total += count[i]
    }
    return total
}

/// Naive solution: check every non-empty subset of positions. O(2ⁿ · n) time, O(1) extra space.
/// Only practical for small arrays (the tests use up to 14 elements).
public func countLongestIncreasingBruteForce(_ nums: [Int]) -> Int {
    var bestLength = 0
    var bestCount = 0
    if nums.isEmpty { return 0 }
    for mask in 1..<(1 << nums.count) {
        var previous: Int?
        var length = 0
        var isIncreasing = true
        for index in nums.indices where mask & (1 << index) != 0 {
            if let previous, nums[index] <= previous {
                isIncreasing = false
                break
            }
            previous = nums[index]
            length += 1
        }
        guard isIncreasing else { continue }
        if length > bestLength {
            bestLength = length
            bestCount = 1
        } else if length == bestLength {
            bestCount += 1
        }
    }
    return bestCount
}
