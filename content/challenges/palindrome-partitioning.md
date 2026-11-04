---
id: palindrome-partitioning
title: Palindrome Partitioning
difficulty: medium
order: 56
patterns: [Backtracking, Precomputed table]
prerequisites: [m16-l03, m18-l02]
summary: List every way to cut a string into palindromes. Backtrack over where the next piece ends, with a table that answers "is this piece a palindrome?" in O(1).
solutionFile: PalindromePartitions.swift
testFile: PalindromePartitionsTests.swift
starter: |
  func palindromePartitions(_ text: String) -> [[String]] {
      // Your solution
      return []
  }
time: O(n · 2^n) in the worst case
space: O(n²) for the table, plus O(n) for the recursion
edgeCases:
  - Empty string, which has one partition with no pieces
  - A single character
  - One repeated letter, which has 2^(n-1) partitions
  - Odd- and even-length palindromes inside the string
askInterviewer:
  - Does the order of the partitions matter?
  - Is a single character a palindrome? (Yes, so there's always at least one partition.)
  - Is the comparison by Character, case-sensitive, with no normalization?
  - How long can the string be? The output can be exponential.
hints:
  - The first piece is some prefix of the string. Which prefixes can it be?
  - After choosing a palindromic first piece, the rest is the same problem on a shorter string.
  - The search checks the same substring many times. Can you answer "is text[i...j] a palindrome?" in O(1) after some preparation?
followUps:
  - What's the minimum number of cuts so every piece is a palindrome? (Dynamic programming, Module 20.)
  - How would you count partitions without listing them?
  - How does expanding around each center compare to the table for finding palindromes?
rubric:
  - I recursed on where the next piece ends and only continued with palindromic pieces.
  - I recorded a partition when the whole string was consumed.
  - I precomputed palindrome checks, or explained what that would save.
  - I explained why the output size makes the exponential bound unavoidable.
codeStatus: tested
---

A text-art feature wants to split a word into pieces that each read the same forwards and backwards. Write `palindromePartitions(_:)` that returns every way to cut `text` into consecutive pieces that are all palindromes. Each partition lists its pieces from left to right; the partitions can come in any order. The empty string has one partition with no pieces.

```swift
palindromePartitions("noon")  // [["n", "o", "o", "n"], ["n", "oo", "n"], ["noon"]]
palindromePartitions("abc")   // [["a", "b", "c"]]
palindromePartitions("")      // [[]]
```

**Constraints:** `0 ≤ text.count ≤ 16`; any characters, compared as Swift `Character`s.

<!-- reveal -->

## First approach

Read left to right. The first piece ends somewhere; for each place it could end where it's a palindrome, cut there and solve the rest of the string the same way. When nothing is left, the pieces collected so far are one answer. It's the backtracking template with "where does the next piece end?" as the choice.

## Naive solution

Every partition is a choice of where to cut among the n − 1 gaps. Try all 2^(n−1) choices and keep the ones where every piece is a palindrome:

```swift
func palindromePartitions(_ text: String) -> [[String]] {
    let characters = Array(text)
    guard !characters.isEmpty else { return [[]] }
    var results: [[String]] = []
    for cuts in 0..<(1 << (characters.count - 1)) {
        var pieces: [String] = []
        var piece: [Character] = [characters[0]]
        for index in 1..<characters.count {
            if cuts & (1 << (index - 1)) != 0 {
                pieces.append(String(piece))
                piece = []
            }
            piece.append(characters[index])
        }
        pieces.append(String(piece))
        if pieces.allSatisfy({ String($0.reversed()) == $0 }) {
            results.append(pieces)
        }
    }
    return results
}
```

## Problems with the naive solution

It always tries 2^(n−1) cut patterns, even for a string like "abcdefghijklmnop" that has exactly one answer: 32,768 patterns to keep one. It also checks palindromes by reversing strings, over and over: the piece "noon" gets checked in every pattern that contains it. The backtracking version never continues past a non-palindromic piece, so its work tracks the answers.

## Optimized solution

First, a table: `isPalindrome[i][j]` is true when characters `i` through `j` form a palindrome. A range is a palindrome when its two ends match and the inside is a palindrome, so filling it from the shortest ranges up costs O(n²). Then backtrack: from position `start`, try every `end` where `isPalindrome[start][end]`, add that piece, recurse from `end + 1`, and remove it.

## Line by line

- `let characters = Array(text)`: indexing a `String` by position is O(n) per access in Swift; an array of `Character`s is O(1).
- `guard n > 0 else { return [[]] }`: the empty string's one partition. The search would return the same thing on its own, because `explore(from: 0)` would record an empty partition immediately, but the guard makes the case visible to a reader.
- `for start in stride(from: n - 1, through: 0, by: -1)`: rows from the bottom up, so `isPalindrome[start + 1][...]` is already filled when row `start` needs it.
- `for end in start..<n where characters[start] == characters[end]`: only ranges whose ends match can be palindromes; the rest stay `false`.
- `isPalindrome[start][end] = end - start < 2 || isPalindrome[start + 1][end - 1]`: lengths 1 and 2 with matching ends are palindromes; longer ones depend on their inside.
- `if start == n { results.append(pieces); return }`: the whole string is consumed, so `pieces` is a complete partition.
- `for end in start..<n where isPalindrome[start][end]`: only palindromic next pieces.
- `pieces.append(String(characters[start...end]))`, `explore(from: end + 1)`, `pieces.removeLast()`: choose, explore, unchoose.

## Common mistakes

- Filling the table top-down (`start` increasing), which reads `isPalindrome[start + 1][end - 1]` before it's set.
- Recording a partition when `start == n - 1` instead of `start == n`, which drops the last piece.
- Taking the substring with `String.Index` arithmetic inside the loop, which is easy to get wrong and slower than working with the array.
- Claiming O(n²) or O(n³) total. The table is O(n²), but a string of one repeated letter has 2^(n−1) partitions; no algorithm that lists them can be faster than the output.

## Variation

**Palindrome Partitioning II:** return the fewest cuts needed. Listing is hopeless for long strings, but `cuts[i]`, the fewest cuts for the first i characters, follows from smaller prefixes: for every `j < i` where characters `j..<i` form a palindrome, `cuts[i] = min(cuts[i], cuts[j] + 1)`. With the same table, O(n²) total.
