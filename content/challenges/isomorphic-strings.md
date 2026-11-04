---
id: isomorphic-strings
title: Isomorphic Strings
difficulty: easy
order: 6
patterns: [Hash map, Strings]
prerequisites: [m07, m15, m16-l05]
summary: Can one string become the other by swapping characters one for one? A mapping that has to hold in both directions.
solutionFile: IsomorphicStrings.swift
testFile: IsomorphicStringsTests.swift
starter: |
  func isIsomorphic(_ first: String, _ second: String) -> Bool {
      // Your solution
      return false
  }
time: O(n) on average
space: O(n)
edgeCases:
  - Two empty strings
  - Strings of different lengths
  - Two different characters that would map to the same one, like "ab" and "aa"
  - One character that would map to two different ones, like "aa" and "ab"
  - Characters that map to themselves, or two characters that swap
askInterviewer:
  - Can a character map to itself?
  - Do spaces, digits and emoji count as characters, or only letters?
  - Is the comparison case-sensitive?
  - Can the strings have different lengths?
hints:
  - "Write down what each character of `first` turns into as you walk both strings together. When does that table contradict itself?"
  - "\"paper\" and \"title\" pass a one-way table, and so do \"ab\" and \"aa\". What does the second pair break that the first doesn't?"
  - Keep two tables, one for each direction, and check both at every position.
followUps:
  - "Word Pattern: does a list of words follow a pattern like \"abba\"? (The same two maps, with words on one side.)"
  - How would you group a list of words by their pattern, so that "paper" and "title" land together?
  - If the strings are known to be ASCII, what could replace the dictionaries?
rubric:
  - I asked about character set and case before coding.
  - I checked the mapping in both directions, not only from first to second.
  - I returned false right away for different lengths.
  - "I stated O(n) time on average and O(n) space, and explained the Array conversion."
codeStatus: tested
---

A word game swaps letters with a secret code: every occurrence of a character becomes the same replacement, and two different characters never get the same replacement. A character may be replaced by itself.

Write `isIsomorphic(_ first: String, _ second: String) -> Bool` that returns `true` if some code like that turns `first` into `second`.

```swift
isIsomorphic("paper", "title")  // true: p→t, a→i, e→l, r→e
isIsomorphic("moon", "deer")    // true: m→d, o→e, n→r
isIsomorphic("moon", "dear")    // false: o would have to become both e and a
isIsomorphic("ab", "aa")        // false: a and b can't both become a
```

**Constraints:** `0 ≤ first.count, second.count ≤ 5·10^4`. Any `Character` can appear, and case matters.

<!-- reveal -->

## First approach

Walk both strings together, position by position. Each pair `(from, to)` is a promise: "`from` always becomes `to`". The answer is `false` the first time a promise is broken. There are two ways to break one: a character of `first` that already promised a different replacement, and a character of `second` that's already the replacement of a different character.

## Naive solution

Two positions `i` and `j` have to agree: if `first[i] == first[j]` then `second[i] == second[j]`, and the other way around. Check every pair of positions:

```swift
func isIsomorphic(_ first: String, _ second: String) -> Bool {
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
```

## Problems with the naive solution

It's **O(n²)**: with 5·10^4 characters that's about 1.25·10^9 comparisons. It's correct, though, and the "every pair must agree" idea is a good way to explain what the problem asks before you speed it up.

## Optimized solution

Remember the promises. One dictionary maps each character of `first` to its replacement; a second maps each replacement back to the character it came from. At every position, a lookup in each answers "does this pair contradict an earlier one?" in O(1) on average.

## Line by line

- `Array(first)` and `Array(second)`: `String` can't be indexed with integers, and `zip` needs two sequences of `Character` to pair up.
- `guard source.count == target.count`: strings of different lengths can't match, and without this check `zip` would silently stop at the shorter one.
- `forward` maps a character of `first` to its replacement; `backward` maps a replacement to the character of `first` that uses it.
- `if let mapped = forward[from], mapped != to`: `from` already promised something else. That's "moon" and "dear".
- `if let mapped = backward[to], mapped != from`: `to` is already taken by a different character. That's "ab" and "aa", which a one-way map would accept.
- `forward[from] = to` and `backward[to] = from`: recording a promise that's already there rewrites the same value, so there's no need for an `else`.

## Common mistakes

- Checking only one direction. "ab" and "aa" pass a single `forward` map.
- Comparing the number of distinct characters on each side, `Set(first).count == Set(second).count`. Equal counts are necessary but not enough: "aab" and "abb" both have two distinct characters, yet the first "a" would have to become both "a" and "b".
- Forgetting the length check and relying on `zip`, which truncates to the shorter string.

## Variation

**Word Pattern:** given `pattern = "abba"` and the words `["dog", "cat", "cat", "dog"]`, does the list follow the pattern? It's the same problem with `[Character: String]` and `[String: Character]`. Check the counts first: a pattern of four letters can't match three words.
