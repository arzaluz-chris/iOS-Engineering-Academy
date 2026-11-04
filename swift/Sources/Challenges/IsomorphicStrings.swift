/// Returns whether `second` can be produced from `first` by a one-to-one substitution:
/// every occurrence of a character becomes the same character, and two different
/// characters never become the same one. A character may map to itself.
///
/// Two dictionaries record the mapping in both directions, so a conflict in either one
/// is caught the moment it appears. O(n) time on average, O(n) space (the character
/// arrays, plus one dictionary entry per distinct character).
public func isIsomorphic(_ first: String, _ second: String) -> Bool {
    let source = Array(first)
    let target = Array(second)
    guard source.count == target.count else { return false }

    var forward: [Character: Character] = [:]
    var backward: [Character: Character] = [:]
    for (from, to) in zip(source, target) {
        if let mapped = forward[from], mapped != to { return false }
        if let mapped = backward[to], mapped != from { return false }
        forward[from] = to
        backward[to] = from
    }
    return true
}

/// Naive solution: two positions must agree in both strings about whether their characters
/// are equal. Checks every pair of positions. O(n²) time, O(n) space for the arrays.
public func isIsomorphicBruteForce(_ first: String, _ second: String) -> Bool {
    let source = Array(first)
    let target = Array(second)
    guard source.count == target.count else { return false }
    for i in source.indices {
        for j in (i + 1)..<source.count where (source[i] == source[j]) != (target[i] == target[j]) {
            return false
        }
    }
    return true
}
