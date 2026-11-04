/// Returns the length of the longest subsequence of `values` (elements kept in their original
/// order, not necessarily next to each other) in which each element is exactly `step` more
/// than the one before it. A single element counts as a subsequence of length 1.
///
/// A dictionary maps each value to the length of the longest such subsequence that ends with
/// that value among the elements seen so far. A new element extends the best one ending at
/// `value - step`. O(n) time on average, O(u) space for u distinct values.
public func longestStepSubsequence(_ values: [Int], step: Int) -> Int {
    var longestEndingAt: [Int: Int] = [:]
    var longest = 0
    for value in values {
        let length = longestEndingAt[value - step, default: 0] + 1
        longestEndingAt[value] = length
        longest = max(longest, length)
    }
    return longest
}

/// Naive solution: for each element, look back at every earlier element that could come right
/// before it in the subsequence. O(n²) time, O(n) space.
public func longestStepSubsequenceBruteForce(_ values: [Int], step: Int) -> Int {
    var lengths = Array(repeating: 1, count: values.count)
    for end in values.indices {
        for previous in 0..<end where values[previous] + step == values[end] {
            lengths[end] = max(lengths[end], lengths[previous] + 1)
        }
    }
    return lengths.max() ?? 0
}
