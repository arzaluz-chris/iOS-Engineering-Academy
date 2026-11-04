/// Returns whether `pattern` matches all of `text`. In the pattern, `?` matches exactly one
/// character, `*` matches any run of characters (including none), and every other character
/// matches itself.
///
/// matches[i][j] says whether the first j pattern characters match the first i text characters.
/// A `*` either matches nothing (matches[i][j - 1]) or takes one more text character
/// (matches[i - 1][j]). Only the row for the previous text prefix is kept.
/// O(n · m) time for text length n and pattern length m, O(m) extra space.
public func wildcardMatches(_ text: String, pattern: String) -> Bool {
    let textCharacters = Array(text)
    let patternCharacters = Array(pattern)
    let patternCount = patternCharacters.count
    // Row for the empty text prefix: only a run of leading stars matches it.
    var previous = Array(repeating: false, count: patternCount + 1)
    previous[0] = true
    for j in stride(from: 1, through: patternCount, by: 1) {
        previous[j] = previous[j - 1] && patternCharacters[j - 1] == "*"
    }
    for character in textCharacters {
        var current = Array(repeating: false, count: patternCount + 1)   // current[0]: empty pattern, non-empty text
        for j in stride(from: 1, through: patternCount, by: 1) {
            switch patternCharacters[j - 1] {
            case "*":
                current[j] = current[j - 1] || previous[j]
            case "?":
                current[j] = previous[j - 1]
            default:
                current[j] = previous[j - 1] && patternCharacters[j - 1] == character
            }
        }
        previous = current
    }
    return previous[patternCount]
}

/// Naive solution: plain recursion. Each `*` tries matching nothing or one more character.
/// Exponential time in the worst case (patterns with many stars), O(n + m) stack depth.
public func wildcardMatchesBruteForce(_ text: String, pattern: String) -> Bool {
    let textCharacters = Array(text)
    let patternCharacters = Array(pattern)
    func matches(_ i: Int, _ j: Int) -> Bool {
        if j == patternCharacters.count { return i == textCharacters.count }
        if patternCharacters[j] == "*" {
            return matches(i, j + 1) || (i < textCharacters.count && matches(i + 1, j))
        }
        guard i < textCharacters.count,
              patternCharacters[j] == "?" || patternCharacters[j] == textCharacters[i] else { return false }
        return matches(i + 1, j + 1)
    }
    return matches(0, 0)
}
