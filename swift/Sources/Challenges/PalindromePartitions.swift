/// Returns every way to cut `text` into pieces that are all palindromes. Each partition lists
/// its pieces left to right; partitions come in the order the search finds them (shorter first
/// piece first).
///
/// First a table: `isPalindrome[i][j]` says whether characters `i...j` read the same both ways,
/// filled from short ranges to long ones in O(n²). Then backtracking chooses the end of the next
/// piece; only palindromic pieces are tried, so every leaf is an answer.
/// O(n · 2^n) time in the worst case (a string of one repeated letter has 2^(n-1) partitions),
/// O(n²) space for the table.
public func palindromePartitions(_ text: String) -> [[String]] {
    let characters = Array(text)
    let n = characters.count
    guard n > 0 else { return [[]] }

    var isPalindrome = Array(repeating: Array(repeating: false, count: n), count: n)
    for start in stride(from: n - 1, through: 0, by: -1) {
        for end in start..<n where characters[start] == characters[end] {
            isPalindrome[start][end] = end - start < 2 || isPalindrome[start + 1][end - 1]
        }
    }

    var results: [[String]] = []
    var pieces: [String] = []

    func explore(from start: Int) {
        if start == n {
            results.append(pieces)
            return
        }
        for end in start..<n where isPalindrome[start][end] {
            pieces.append(String(characters[start...end]))
            explore(from: end + 1)
            pieces.removeLast()
        }
    }

    explore(from: 0)
    return results
}

/// Naive solution: try all 2^(n-1) ways to place cuts and check every piece by reversing it.
/// O(n · 2^n) time for every input, not only the worst one.
public func palindromePartitionsBruteForce(_ text: String) -> [[String]] {
    let characters = Array(text)
    guard !characters.isEmpty else { return [[]] }
    var results: [[String]] = []
    for cuts in 0..<(1 << (characters.count - 1)) {
        var pieces: [String] = []
        var piece: [Character] = [characters[0]]
        for index in 1..<characters.count {
            if cuts & (1 << (index - 1)) != 0 {
                pieces.append(String(piece))
                piece = []
            }
            piece.append(characters[index])
        }
        pieces.append(String(piece))
        if pieces.allSatisfy({ String($0.reversed()) == $0 }) {
            results.append(pieces)
        }
    }
    return results
}
