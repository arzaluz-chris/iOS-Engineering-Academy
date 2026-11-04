/// Returns whether some stretch of consecutive characters of `text` is a rearrangement of
/// `pattern`: the same letters with the same counts, in any order. Both strings contain only
/// the lowercase letters a to z. The empty pattern is found in any text.
///
/// A fixed-size window of `pattern`'s length slides over `text`, keeping 26 counters for the
/// letters inside it. Each slide adds one letter and removes one, and the window matches when
/// its counters equal the pattern's. Comparing two 26-element arrays is O(26), so the total
/// is O(26 · n), which is O(n). O(n + m) space for the byte arrays, O(1) for the counters.
public func containsRearrangement(of pattern: String, in text: String) -> Bool {
    let wanted = Array(pattern.utf8)
    let letters = Array(text.utf8)
    let size = wanted.count
    guard size <= letters.count else { return false }

    var patternCounts = Array(repeating: 0, count: 26)
    var windowCounts = Array(repeating: 0, count: 26)
    for index in 0..<size {
        patternCounts[Int(wanted[index] - 97)] += 1
        windowCounts[Int(letters[index] - 97)] += 1
    }
    if windowCounts == patternCounts { return true }

    for right in size..<letters.count {
        windowCounts[Int(letters[right] - 97)] += 1
        windowCounts[Int(letters[right - size] - 97)] -= 1
        if windowCounts == patternCounts { return true }
    }
    return false
}

/// Naive solution: sort every window of the right length and compare it with the sorted
/// pattern. O(n · m log m) time for a text of n letters and a pattern of m.
public func containsRearrangementBruteForce(of pattern: String, in text: String) -> Bool {
    let wanted = pattern.sorted()
    let letters = Array(text)
    guard wanted.count <= letters.count else { return false }
    for start in 0...(letters.count - wanted.count)
    where letters[start..<(start + wanted.count)].sorted() == wanted {
        return true
    }
    return false
}
