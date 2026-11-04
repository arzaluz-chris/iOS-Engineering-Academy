/// Returns whether `values` has a stretch of at least two consecutive elements whose sum is a
/// multiple of `k` (0 counts as a multiple). `k` is positive; values can be negative.
///
/// Two prefix sums with the same remainder modulo `k` bound a stretch whose sum is a multiple
/// of `k`. A dictionary keeps the first prefix length at which each remainder appeared, so the
/// longest stretch for each remainder is checked against the minimum length of 2.
/// O(n) time on average, O(min(n, k)) space.
public func hasStretchSummingToMultiple(_ values: [Int], of k: Int) -> Bool {
    var firstPrefixLength: [Int: Int] = [0: 0]
    var prefix = 0
    for (index, value) in values.enumerated() {
        prefix += value
        let remainder = ((prefix % k) + k) % k
        let length = index + 1
        if let earlier = firstPrefixLength[remainder] {
            if length - earlier >= 2 {
                return true
            }
        } else {
            firstPrefixLength[remainder] = length
        }
    }
    return false
}

/// Naive solution: try every stretch of length 2 or more with a running sum per start.
/// O(n²) time, O(1) space.
public func hasStretchSummingToMultipleBruteForce(_ values: [Int], of k: Int) -> Bool {
    for start in values.indices {
        var sum = values[start]
        for end in (start + 1)..<values.count {
            sum += values[end]
            if sum % k == 0 {
                return true
            }
        }
    }
    return false
}
