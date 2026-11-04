/// Splits `text` into pieces where each piece is either a word from `words` or a single leftover
/// character, and returns the fewest leftover characters any split can have.
///
/// fewest[i] is the answer for the suffix that starts at i. Either the character at i is left over
/// (1 + fewest[i + 1]) or a dictionary word starts at i and ends at some `end` (fewest[end]).
/// Only ends up to the longest word's length are worth trying.
/// O(n · L²) time, where L is the length of the longest word (each candidate piece of up to L
/// characters is built and hashed); O(n + L) extra space.
public func fewestLeftoverCharacters(_ text: String, words: Set<String>) -> Int {
    let characters = Array(text)
    let longestWord = words.map(\.count).max() ?? 0
    var fewest = Array(repeating: 0, count: characters.count + 1)   // fewest[count] = 0: nothing left
    for start in stride(from: characters.count - 1, through: 0, by: -1) {
        var best = 1 + fewest[start + 1]
        let farthestEnd = min(characters.count, start + longestWord)
        for end in stride(from: start + 1, through: farthestEnd, by: 1)
        where words.contains(String(characters[start..<end])) {
            best = min(best, fewest[end])
        }
        fewest[start] = best
    }
    return fewest[0]
}

/// Naive solution: the same choices as plain recursion, without remembering any suffix.
/// Exponential time in the worst case, O(n) stack depth.
public func fewestLeftoverCharactersBruteForce(_ text: String, words: Set<String>) -> Int {
    let characters = Array(text)
    func fewest(from start: Int) -> Int {
        guard start < characters.count else { return 0 }
        var best = 1 + fewest(from: start + 1)
        for end in (start + 1)...characters.count where words.contains(String(characters[start..<end])) {
            best = min(best, fewest(from: end))
        }
        return best
    }
    return fewest(from: 0)
}
