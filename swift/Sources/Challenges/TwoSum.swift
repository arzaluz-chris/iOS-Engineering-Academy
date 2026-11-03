/// Returns the indices `[i, j]` (with `i < j`) of two different elements that add up to `target`,
/// or `nil` if there aren't any. If several pairs work, returns the one whose second index is smallest.
///
/// A dictionary maps each value seen so far to its index. For each element, the loop looks up
/// its complement `target - value` before recording it, so an element never pairs with itself.
/// O(n) time on average, O(n) space.
///
/// Assumes values in a range where `target - value` can't overflow `Int`
/// (the problem statement says values and target are between -10^9 and 10^9).
public func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
    var indexByValue: [Int: Int] = [:]
    for (index, value) in nums.enumerated() {
        if let complementIndex = indexByValue[target - value] {
            return [complementIndex, index]
        }
        indexByValue[value] = index
    }
    return nil
}

/// Naive solution: try every pair. O(n²) time, O(1) space.
public func twoSumBruteForce(_ nums: [Int], _ target: Int) -> [Int]? {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] + nums[j] == target {
            return [i, j]
        }
    }
    return nil
}
