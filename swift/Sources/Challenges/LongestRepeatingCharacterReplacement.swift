/// Given a row of tiles, each painted one of the colors `A` to `Z` (a string of uppercase
/// English letters), returns the length of the longest stretch of consecutive tiles that can
/// all be made the same color by repainting at most `k` tiles.
///
/// A sliding window is valid when its length minus the count of its most common letter is at
/// most `k`: those are the tiles to repaint. For each right end, shrink from the left while the
/// window is invalid. The most common count is read from 26 counters, so each step costs
/// O(26). O(n) time, O(n) space for the byte array (the counters are O(1)).
public func longestUniformRun(_ tiles: String, repaints k: Int) -> Int {
    let letters = Array(tiles.utf8)
    var counts = Array(repeating: 0, count: 26)
    var left = 0
    var longest = 0
    for right in letters.indices {
        counts[Int(letters[right] - 65)] += 1
        while (right - left + 1) - (counts.max() ?? 0) > k {
            counts[Int(letters[left] - 65)] -= 1
            left += 1
        }
        longest = max(longest, right - left + 1)
    }
    return longest
}

/// Naive solution: for each start, extend to the right while tracking the most common letter.
/// O(n²) time, O(n) space for the byte array.
public func longestUniformRunBruteForce(_ tiles: String, repaints k: Int) -> Int {
    let letters = Array(tiles.utf8)
    var longest = 0
    for start in letters.indices {
        var counts = Array(repeating: 0, count: 26)
        var mostCommon = 0
        for end in start..<letters.count {
            let letter = Int(letters[end] - 65)
            counts[letter] += 1
            mostCommon = max(mostCommon, counts[letter])
            if (end - start + 1) - mostCommon <= k {
                longest = max(longest, end - start + 1)
            }
        }
    }
    return longest
}
