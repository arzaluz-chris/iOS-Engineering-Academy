/// Returns the shortest stretch of consecutive characters of `text` that contains every
/// character of `required`, counting repeats (if `required` has two "a", the stretch needs
/// two "a"). If several stretches are equally short, returns the leftmost. Returns "" if no
/// stretch qualifies or if `required` is empty.
///
/// A variable sliding window. `owed` holds, for each character, how many more copies the
/// window needs (negative when it has extras), and `missing` counts the required characters
/// still absent. The right end grows the window until `missing` is 0, then the left end shrinks
/// it while it stays valid, recording each valid window. O(n + m) time on average for a text
/// of n characters and m required ones, O(n + m) space.
public func smallestCoveringWindow(_ text: String, covering required: String) -> String {
    guard !required.isEmpty else { return "" }
    let characters = Array(text)
    var owed: [Character: Int] = [:]
    for character in required {
        owed[character, default: 0] += 1
    }
    var missing = required.count

    var left = 0
    var bestStart = 0
    var bestLength = Int.max
    for right in characters.indices {
        let incoming = characters[right]
        if owed[incoming, default: 0] > 0 {
            missing -= 1
        }
        owed[incoming, default: 0] -= 1

        while missing == 0 {
            if right - left + 1 < bestLength {
                bestStart = left
                bestLength = right - left + 1
            }
            let outgoing = characters[left]
            owed[outgoing, default: 0] += 1
            if owed[outgoing, default: 0] > 0 {
                missing += 1
            }
            left += 1
        }
    }
    guard bestLength != Int.max else { return "" }
    return String(characters[bestStart..<(bestStart + bestLength)])
}

/// Naive solution: from each start, extend the end until the window covers `required`.
/// O(n²) time on average, O(n + m) space.
public func smallestCoveringWindowBruteForce(_ text: String, covering required: String) -> String {
    guard !required.isEmpty else { return "" }
    let characters = Array(text)
    var needed: [Character: Int] = [:]
    for character in required {
        needed[character, default: 0] += 1
    }
    var best: ArraySlice<Character>?
    for start in characters.indices {
        var owed = needed
        var missing = required.count
        for end in start..<characters.count {
            if owed[characters[end], default: 0] > 0 {
                missing -= 1
            }
            owed[characters[end], default: 0] -= 1
            if missing == 0 {
                if end - start + 1 < (best?.count ?? Int.max) {
                    best = characters[start...end]
                }
                break
            }
        }
    }
    return best.map { String($0) } ?? ""
}
