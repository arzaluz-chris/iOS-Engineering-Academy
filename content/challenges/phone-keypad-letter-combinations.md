---
id: phone-keypad-letter-combinations
title: Phone Keypad Letter Combinations
difficulty: medium
order: 57
patterns: [Backtracking, Cartesian product]
prerequisites: [m18-l02]
summary: List every string a sequence of phone keys could spell. One level of recursion per key, one branch per letter.
solutionFile: KeypadCombinations.swift
testFile: KeypadCombinationsTests.swift
starter: |
  func keypadCombinations(_ digits: String) -> [String] {
      // Your solution
      return []
  }
time: O(n · 4^n) for n digits
space: O(n) besides the output
edgeCases:
  - Empty input, which returns an empty list
  - Keys with four letters (7 and 9)
  - The same digit repeated
  - Characters other than 2 through 9
askInterviewer:
  - Which keys can appear? What about 0, 1, * and #?
  - For an empty input, do you want [] or [""]?
  - Does the order of the results matter?
  - How many digits at most? The output grows by 3 or 4 times per digit.
hints:
  - With two digits you'd write two nested loops. Why doesn't that work for any number of digits?
  - Recursion gives you one loop per level, as many levels as you need.
  - At level i, loop over the letters of digit i, append one, recurse, and remove it.
followUps:
  - Filter the results to the strings that are real words. How would a trie of the dictionary prune the search?
  - Return the k-th combination in this order directly, without generating the others.
  - How would you produce the combinations lazily, one at a time, as a Sequence?
rubric:
  - I mapped each digit to its letters with a lookup table.
  - I wrote the backtracking with one level per digit and recorded at full length.
  - I handled the empty input as specified.
  - I gave the O(4^n) output size as the reason the time can't be better.
codeStatus: tested
---

A dialer app suggests words as you type digits, using the letters printed on a phone keypad: 2 is `abc`, 3 `def`, 4 `ghi`, 5 `jkl`, 6 `mno`, 7 `pqrs`, 8 `tuv`, 9 `wxyz`. Write `keypadCombinations(_:)` that returns every string the digits could spell, in keypad order: the first digit's letters change slowest, as in the examples. An empty input returns an empty list.

```swift
keypadCombinations("29")
// ["aw", "ax", "ay", "az", "bw", "bx", "by", "bz", "cw", "cx", "cy", "cz"]
keypadCombinations("5")  // ["j", "k", "l"]
keypadCombinations("")   // []
```

**Constraints:** `0 ≤ digits.count ≤ 8`; every character is a digit from 2 to 9.

<!-- reveal -->

## First approach

Each digit contributes one letter, and every combination of choices is an answer: it's a Cartesian product. For a known number of digits that's nested loops. For any number of digits, the nesting has to come from recursion: each level of the recursion is one loop, over one digit's letters.

## Naive solution

Build the strings level by level, without recursion: start with one empty prefix, and for each digit, extend every prefix with every letter of that key.

```swift
func keypadCombinations(_ digits: String) -> [String] {
    guard !digits.isEmpty else { return [] }
    var prefixes = [""]
    for digit in digits {
        let value = digit.wholeNumberValue!
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
```

## Problems with the naive solution

This one isn't slow in big-O terms: both versions are O(n · 4ⁿ), because the output itself has up to 4ⁿ strings of length n. The difference is memory along the way. The iterative version holds every prefix of the previous length while building the next level, and creates a new `String` for each with `prefix + String(letter)`. The backtracking version keeps one working string of at most n characters. It's worth saying in an interview that neither can beat the size of the output.

## Optimized solution

Backtracking with one level per digit. `current` is the string built so far. At level `index`, loop over that key's letters: append the letter, recurse to `index + 1`, remove the letter. When `index` reaches the number of digits, `current` is a complete answer.

## Line by line

- `keypadCombinationsLetters`: an array indexed by digit, with empty entries for 0 and 1, so `keypadCombinationsLetters[7]` is `["p", "q", "r", "s"]`.
- The `for digit in digits` loop with `guard let value = digit.wholeNumberValue, (2...9).contains(value)`: converts and validates every digit up front. Anything else is a programmer error here, so it stops with `preconditionFailure`.
- `guard !keys.isEmpty else { return [] }`: the problem asks for `[]`, not `[""]`. Without this guard the recursion would record the empty string once.
- `if index == keys.count { results.append(current); return }`: every key has contributed a letter.
- `for letter in keys[index]`: the choices at this level.
- `current.append(letter)`, `explore(index + 1)`, `current.removeLast()`: choose, explore, unchoose. `removeLast()` on a `String` removes the last `Character`.

## Common mistakes

- Returning `[""]` for an empty input, or crashing on it.
- Building `current + String(letter)` and passing it down instead of append and remove. It's correct, but every level allocates a new string, which is the overhead the backtracking version avoids.
- Forgetting that 7 and 9 have four letters, and writing the size as `3^n`.
- Indexing a `String` with an `Int`, which Swift doesn't allow: convert the digits to an array first.

## Variation

**Generate Parentheses:** list every valid string of n pairs of parentheses. Same structure, one level per character, but the choices depend on the state: you can add `(` while fewer than n are open, and `)` only while it would close something. That constraint is the pruning.
