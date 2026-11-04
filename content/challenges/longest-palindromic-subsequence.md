---
id: longest-palindromic-subsequence
title: Longest Palindromic Subsequence
difficulty: medium
order: 88
patterns: [2-D dynamic programming, Interval DP]
prerequisites: [m20-l05]
summary: Find the longest subsequence that reads the same both ways. A 2-D table over the two ends of a substring, filled from short intervals to long ones.
solutionFile: LongestPalindromicSubsequence.swift
testFile: LongestPalindromicSubsequenceTests.swift
starter: |
  func longestPalindromicSubsequence(_ text: String) -> Int {
      // Your solution
      return 0
  }
time: O(n²)
space: O(n) extra
edgeCases:
  - Empty string (0) and a single character (1)
  - A string that's already a palindrome
  - No repeated characters, where the answer is 1
  - All the same character
  - Uppercase and lowercase versions of a letter, which are different characters
askInterviewer:
  - Subsequence or substring? (Characters don't have to be next to each other here.)
  - Is the comparison case-sensitive? What counts as a character?
  - Do you want the length or the subsequence itself?
  - How long can the string be?
hints:
  - Look at the first and last characters. If they're equal, what can you say about the best palindrome?
  - If they differ, at least one of them isn't used. Which two smaller problems does that leave?
  - The state is a pair (start, end). Which entries does (start, end) read, and in what order should you fill them?
followUps:
  - What's the fewest characters to delete to make the string a palindrome? (n minus this answer.)
  - Return the palindrome itself.
  - How is this related to the longest common subsequence of the string and its reverse?
rubric:
  - I defined the state as the best answer for the substring from start to end.
  - I wrote both transitions (matching ends add 2, otherwise drop one end) and the base cases.
  - I chose a fill order where every read entry is already computed.
  - I reduced the space to O(n) or explained how.
codeStatus: tested
---

A word game rewards players for finding hidden palindromes: pick some letters of a word, in order, so that they read the same forward and backward. Given `text`, return the length of the longest such **subsequence** (the picked characters keep their order but don't have to be next to each other). Characters are compared exactly, so `A` and `a` are different.

```swift
longestPalindromicSubsequence("character")  // 5: "carac"
longestPalindromicSubsequence("banana")     // 5: "anana"
longestPalindromicSubsequence("swift")      // 1: no letter repeats
```

**Constraints:** `0 ≤ text.count ≤ 1,000`.

<!-- reveal -->

## First approach

Look at the two ends of the string. If they're the same character, there's a best palindrome that uses both, wrapped around the best palindrome of what's between them. If they differ, they can't both be the outer pair, so the best answer drops one end: the better of "without the first character" and "without the last". The subproblems are substrings, identified by their start and end, so the table is 2-D, as in Module 20, lesson 5. (It's also the longest common subsequence of the string and its reverse, which that lesson solves; the direct version is worth knowing.)

## Naive solution

Try every subset of positions and keep the longest palindrome:

```swift
func longestPalindromicSubsequence(_ text: String) -> Int {
    let characters = Array(text)
    var best = 0
    for mask in 0..<(1 << characters.count) {
        let picked = characters.indices.filter { mask & (1 << $0) != 0 }.map { characters[$0] }
        if picked.count > best && picked == picked.reversed() {
            best = picked.count
        }
    }
    return best
}
```

## Problems with the naive solution

2ⁿ subsets, each built and checked in O(n). A 30-character word already means a billion subsets; 1,000 characters is hopeless. The same inner substrings are judged again and again inside different subsets, which is what the table avoids.

## Optimized solution

Let `longest(start, end)` be the answer for `characters[start...end]`. A single character gives 1. For `start < end`: if the ends match, `longest(start + 1, end - 1) + 2`; otherwise `max(longest(start + 1, end), longest(start, end - 1))`. Each entry reads the row for `start + 1` and the entry to its left in its own row, so fill rows from `start = n - 1` down to 0, each from left to right, and keep only the row below.

## Line by line

- `let characters = Array(text)`: index access by `Int`.
- `guard count > 0 else { return 0 }`: an empty string has an empty palindrome, and `below[count - 1]` would be out of range.
- `var below = Array(repeating: 0, count: count)`: the row for `start + 1`. Before the first row it stands for an empty interval, which is 0 everywhere.
- `row[start] = 1`: one character alone. Entries left of `start` stay 0; they're empty intervals.
- `for end in stride(from: start + 1, to: count, by: 1)`: longer intervals with the same start. `stride` is empty when `start` is the last index.
- `row[end] = below[end - 1] + 2`: matching ends wrap the inside. When `end == start + 1` the inside is empty and `below[start]` is 0, which gives 2 for a pair like "aa".
- `row[end] = max(below[end], row[end - 1])`: drop the first character or drop the last.
- `below = row`: this row becomes the one below for the next `start`.
- `return below[count - 1]`: after the loop, `below` is the row for `start = 0`, and its last entry covers the whole string.

## Common mistakes

- Confusing subsequence with substring. For substrings ("longest palindromic substring") you'd expand around centers instead; the answers differ on "character".
- Filling rows from `start = 0` upward, so `below` hasn't been computed yet.
- Forgetting that an interval of length 2 with equal ends reads an empty inside, and indexing past it.
- Adding 2 when the ends match but `start == end`, which counts one character twice.

## Variation

**Fewest insertions to make a palindrome:** the characters outside the longest palindromic subsequence each need a partner inserted, so the answer is `n - longestPalindromicSubsequence(text)`. The same holds for the fewest deletions.
