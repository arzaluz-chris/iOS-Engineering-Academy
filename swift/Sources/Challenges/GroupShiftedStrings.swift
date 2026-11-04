/// Groups words that are Caesar shifts of each other: moving every letter of one word forward
/// by the same number of places in the alphabet, wrapping from z to a, gives the other.
/// Words contain only the lowercase letters a to z.
///
/// Groups appear in the order of their first word, and words keep their input order inside
/// each group. The key of a word is the distance of each letter from the first letter,
/// modulo 26, which is the same for every word in a group and different across groups.
/// O(n · k) time on average for n words of up to k letters, O(n · k) space.
public func groupShiftedWords(_ words: [String]) -> [[String]] {
    var groupIndexByKey: [[UInt8]: Int] = [:]
    var groups: [[String]] = []
    for word in words {
        let key = shiftKey(of: word)
        if let index = groupIndexByKey[key] {
            groups[index].append(word)
        } else {
            groupIndexByKey[key] = groups.count
            groups.append([word])
        }
    }
    return groups
}

/// The distance of each letter from the word's first letter, wrapped into 0...25.
/// The empty word gets the empty key.
private func shiftKey(of word: String) -> [UInt8] {
    let letters = Array(word.utf8)
    guard let first = letters.first else { return [] }
    return letters.map { letter in (letter + 26 - first) % 26 }
}

/// Whether `second` is `first` with every letter moved forward by the same amount.
private func isShift(_ first: String, of second: String) -> Bool {
    let a = Array(first.utf8)
    let b = Array(second.utf8)
    guard a.count == b.count else { return false }
    guard let firstA = a.first, let firstB = b.first else { return true }
    let shift = (Int(firstB) - Int(firstA) + 26) % 26
    for (x, y) in zip(a, b) where (Int(x) - 97 + shift) % 26 != Int(y) - 97 {
        return false
    }
    return true
}

/// Naive solution: compare each word with the first word of every group so far.
/// O(n · g · k) time for g groups, which is O(n² · k) when every word is alone.
public func groupShiftedWordsBruteForce(_ words: [String]) -> [[String]] {
    var groups: [[String]] = []
    for word in words {
        if let index = groups.firstIndex(where: { isShift($0[0], of: word) }) {
            groups[index].append(word)
        } else {
            groups.append([word])
        }
    }
    return groups
}
