/// Returns the characters of `text` rearranged so the most frequent character comes first,
/// with all copies of each character together. Characters with the same count keep the
/// order of their first appearance in `text`.
///
/// Counts with a dictionary, then places each distinct character in a bucket indexed by its
/// count, visiting characters in order of first appearance so ties come out in that order.
/// Reading the buckets from the highest count down gives the answer without sorting.
/// O(n) time on average, O(n) space.
public func sortedByFrequency(_ text: String) -> String {
    var counts: [Character: Int] = [:]
    var firstAppearance: [Character] = []
    for character in text {
        if counts[character] == nil {
            firstAppearance.append(character)
        }
        counts[character, default: 0] += 1
    }

    var buckets = Array(repeating: [Character](), count: text.count + 1)
    for character in firstAppearance {
        buckets[counts[character, default: 0]].append(character)
    }

    var result = ""
    for count in buckets.indices.reversed() {
        for character in buckets[count] {
            result.append(String(repeating: character, count: count))
        }
    }
    return result
}

/// Naive solution: count each distinct character by scanning the whole text again,
/// then sort the distinct characters by count (a stable sort keeps first-appearance order
/// for ties). O(n · u) time for u distinct characters, O(n) space.
public func sortedByFrequencyBruteForce(_ text: String) -> String {
    var distinct: [Character] = []
    for character in text where !distinct.contains(character) {
        distinct.append(character)
    }
    let counted = distinct.map { character in
        (character: character, count: text.filter { $0 == character }.count)
    }
    let ranked = counted.enumerated().sorted { first, second in
        if first.element.count != second.element.count {
            return first.element.count > second.element.count
        }
        return first.offset < second.offset
    }
    return ranked.map { String(repeating: $0.element.character, count: $0.element.count) }.joined()
}
