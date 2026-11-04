/// Counts the stretches of consecutive elements of `values` (all positive) whose product is
/// strictly less than `limit`.
///
/// A sliding window: for each right end, shrink from the left while the product is too big.
/// Every stretch that ends at `right` and starts at `left` or later then has a small enough
/// product, and there are `right - left + 1` of them. O(n) time, O(1) space.
public func countLowProductStretches(_ values: [Int], below limit: Int) -> Int {
    var left = 0
    var product = 1
    var count = 0
    for right in values.indices {
        product *= values[right]
        while product >= limit && left <= right {
            product /= values[left]
            left += 1
        }
        count += right - left + 1
    }
    return count
}

/// Naive solution: for each start, extend while the product stays below the limit.
/// O(n²) time in the worst case, O(1) space.
public func countLowProductStretchesBruteForce(_ values: [Int], below limit: Int) -> Int {
    var count = 0
    for start in values.indices {
        var product = 1
        for end in start..<values.count {
            product *= values[end]
            if product >= limit { break }
            count += 1
        }
    }
    return count
}
