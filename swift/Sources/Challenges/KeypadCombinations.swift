/// Letters on each phone keypad key, indexed by digit. 0 and 1 have none.
let keypadCombinationsLetters: [[Character]] = [
    [], [],
    ["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"], ["j", "k", "l"],
    ["m", "n", "o"], ["p", "q", "r", "s"], ["t", "u", "v"], ["w", "x", "y", "z"],
]

/// Returns every string the digits 2–9 in `digits` could spell on a phone keypad, in keypad
/// order (the first key's letters vary slowest). An empty input spells nothing, so it returns `[]`.
///
/// Backtracking, one digit per level: for each letter on the current key, append it, recurse
/// on the next digit, remove it. A full-length string is an answer. O(n · 4^n) time (up to 4^n
/// strings of length n), O(n) space besides the output.
public func keypadCombinations(_ digits: String) -> [String] {
    var keys: [[Character]] = []
    for digit in digits {
        guard let value = digit.wholeNumberValue, (2...9).contains(value) else {
            preconditionFailure("digits must be 2 through 9")
        }
        keys.append(keypadCombinationsLetters[value])
    }
    guard !keys.isEmpty else { return [] }

    var results: [String] = []
    var current = ""

    func explore(_ index: Int) {
        if index == keys.count {
            results.append(current)
            return
        }
        for letter in keys[index] {
            current.append(letter)
            explore(index + 1)
            current.removeLast()
        }
    }

    explore(0)
    return results
}

/// Iterative version: start from [""] and extend every prefix with every letter of the next key.
/// Same O(n · 4^n) time, but it builds the full list of prefixes at every level.
public func keypadCombinationsIterative(_ digits: String) -> [String] {
    guard !digits.isEmpty else { return [] }
    var prefixes = [""]
    for digit in digits {
        guard let value = digit.wholeNumberValue, (2...9).contains(value) else {
            preconditionFailure("digits must be 2 through 9")
        }
        var extended: [String] = []
        for prefix in prefixes {
            for letter in keypadCombinationsLetters[value] {
                extended.append(prefix + String(letter))
            }
        }
        prefixes = extended
    }
    return prefixes
}
