/// Returns the length of the longest subsequence of `text` that reads the same forward and
/// backward. Characters are compared as Swift `Character` values.
///
/// longest(i, j) is the answer for characters i through j. If the two ends match, they wrap the
/// best answer for the inside (+2); otherwise one of them is dropped. Rows go from i = n - 1 down
/// to 0, so only the row for i + 1 is kept.
/// O(n²) time, O(n) extra space.
public func longestPalindromicSubsequence(_ text: String) -> Int {
    let characters = Array(text)
    let count = characters.count
    guard count > 0 else { return 0 }
    var below = Array(repeating: 0, count: count)   // longest(start + 1, end) for each end
    for start in stride(from: count - 1, through: 0, by: -1) {
        var row = Array(repeating: 0, count: count)   // longest(start, end) for each end
        row[start] = 1
        for end in stride(from: start + 1, to: count, by: 1) {
            if characters[start] == characters[end] {
                row[end] = below[end - 1] + 2
            } else {
                row[end] = max(below[end], row[end - 1])
            }
        }
        below = row
    }
    return below[count - 1]
}

/// Naive solution: check every subset of positions. O(2ⁿ · n) time, O(n) space.
/// Only practical for short strings (the tests use up to 14 characters).
public func longestPalindromicSubsequenceBruteForce(_ text: String) -> Int {
    let characters = Array(text)
    var best = 0
    for mask in 0..<(1 << characters.count) {
        let picked = characters.indices.filter { mask & (1 << $0) != 0 }.map { characters[$0] }
        if picked.count > best && picked == picked.reversed() {
            best = picked.count
        }
    }
    return best
}
