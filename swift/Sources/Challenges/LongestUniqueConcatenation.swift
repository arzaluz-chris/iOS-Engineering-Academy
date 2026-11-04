/// Returns the length of the longest string you can build by concatenating some of `words`
/// (each at most once) so that no letter appears twice. Words contain only "a" through "z".
///
/// Each usable word becomes a 26-bit mask of its letters; a word with a repeated letter can
/// never be used and is dropped. Backtracking then decides, word by word, to take it or skip
/// it, and "take" is only tried when the word's mask doesn't overlap the letters already used:
/// one `&` instead of comparing letters. Each node of the search loops over the words after it,
/// so the worst case (every subset compatible) is O(n · 2^n) time, plus O(L) to build the masks
/// for L total letters. O(n) space for the masks and the recursion.
public func longestUniqueConcatenation(_ words: [String]) -> Int {
    var masks: [(mask: Int, length: Int)] = []
    for word in words {
        var mask = 0
        var valid = true
        for byte in word.utf8 {
            precondition(byte >= 97 && byte <= 122, "words contain only a-z")
            let bit = 1 << Int(byte - 97)
            if mask & bit != 0 {
                valid = false
                break
            }
            mask |= bit
        }
        if valid {
            masks.append((mask, word.utf8.count))
        }
    }

    var best = 0
    func explore(from index: Int, used: Int, length: Int) {
        best = max(best, length)
        for next in index..<masks.count where masks[next].mask & used == 0 {
            explore(from: next + 1, used: used | masks[next].mask, length: length + masks[next].length)
        }
    }
    explore(from: 0, used: 0, length: 0)
    return best
}

/// Naive solution: build every subset's concatenation and check it with a Set.
/// O(2^n · L) time, O(L) space.
public func longestUniqueConcatenationBruteForce(_ words: [String]) -> Int {
    var best = 0
    for selection in 0..<(1 << words.count) {
        var text = ""
        for index in words.indices where selection & (1 << index) != 0 {
            text += words[index]
        }
        if Set(text).count == text.count {
            best = max(best, text.count)
        }
    }
    return best
}
