/// Returns the smallest index whose left side (the elements before it) and right side (the
/// elements after it) have the same sum, or `nil` if there's none. An empty side sums to 0.
///
/// The total is computed once. Walking left to right with a running sum of the left side,
/// the right side's sum is `total - leftSum - value`. O(n) time, O(1) space.
public func balanceIndex(_ values: [Int]) -> Int? {
    let total = values.reduce(0, +)
    var leftSum = 0
    for (index, value) in values.enumerated() {
        if leftSum == total - leftSum - value {
            return index
        }
        leftSum += value
    }
    return nil
}

/// Naive solution: for each index, add up both sides from scratch. O(n²) time, O(1) space.
public func balanceIndexBruteForce(_ values: [Int]) -> Int? {
    for index in values.indices {
        let leftSum = values[..<index].reduce(0, +)
        let rightSum = values[(index + 1)...].reduce(0, +)
        if leftSum == rightSum {
            return index
        }
    }
    return nil
}
