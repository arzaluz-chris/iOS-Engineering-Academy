/// Expands a string where `k[text]` means `text` repeated `k` times, with brackets nested
/// to any depth: `"2[a3[b]]"` becomes `"abbbabbb"`.
///
/// One left-to-right pass. On `[`, the text built so far and the pending repeat count are pushed
/// on a stack and a fresh piece starts; on `]`, the finished piece is repeated and appended
/// to the text that was saved. Assumes valid input: lowercase letters, ASCII digits and
/// balanced brackets, with every `[` preceded by a positive count.
///
/// Time is proportional to the total length of the strings built along the way:
/// O(m · d) in the worst case, where m is the length of the output and d the nesting depth,
/// because each closing bracket copies its piece into the enclosing one. O(m + d) space.
public func decodeString(_ encoded: String) -> String {
    var saved: [(prefix: String, repeats: Int)] = []
    var current = ""
    var count = 0

    for character in encoded {
        if character.isASCII, let digit = character.wholeNumberValue {
            count = count * 10 + digit
        } else if character == "[" {
            saved.append((prefix: current, repeats: count))
            current = ""
            count = 0
        } else if character == "]" {
            guard let group = saved.popLast() else { continue }
            current = group.prefix + String(repeating: current, count: group.repeats)
        } else {
            current.append(character)
        }
    }
    return current
}

/// Naive version: repeatedly find an innermost `k[letters]` group, expand it in place,
/// and start again from the beginning. Each round rescans and rebuilds the whole string,
/// so it's O(g · L) for g groups and a longest intermediate string of length L.
public func decodeStringBruteForce(_ encoded: String) -> String {
    var characters = Array(encoded)
    while let close = characters.firstIndex(of: "]") {
        guard let open = characters[..<close].lastIndex(of: "[") else { break }
        var digitsStart = open
        while digitsStart > 0, characters[digitsStart - 1].isASCII, characters[digitsStart - 1].isNumber {
            digitsStart -= 1
        }
        let repeats = Int(String(characters[digitsStart..<open])) ?? 1
        let inner = characters[(open + 1)..<close]
        var expanded: [Character] = []
        for _ in 0..<repeats {
            expanded.append(contentsOf: inner)
        }
        characters.replaceSubrange(digitsStart...close, with: expanded)
    }
    return String(characters)
}
