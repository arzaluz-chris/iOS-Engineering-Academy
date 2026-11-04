/// Given values sorted in non-decreasing order, returns the indices `(first, second)`,
/// with `first < second`, of two elements that add up to `target`, or `nil` if there are none.
/// If several pairs work, any of them is a valid answer.
///
/// Converging pointers: if the pair at the ends is too small, the left value can't be part
/// of any answer, so the left index moves right; if it's too big, the right index moves left.
/// O(n) time, O(1) extra space.
public func twoSumSorted(_ sorted: [Int], _ target: Int) -> (first: Int, second: Int)? {
    var left = 0
    var right = sorted.count - 1
    while left < right {
        let sum = sorted[left] + sorted[right]
        if sum == target {
            return (left, right)
        } else if sum < target {
            left += 1
        } else {
            right -= 1
        }
    }
    return nil
}

/// Naive solution: try every pair. O(n²) time, O(1) space.
public func twoSumSortedBruteForce(_ sorted: [Int], _ target: Int) -> (first: Int, second: Int)? {
    for i in sorted.indices {
        for j in (i + 1)..<sorted.count where sorted[i] + sorted[j] == target {
            return (i, j)
        }
    }
    return nil
}
