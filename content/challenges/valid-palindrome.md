---
id: valid-palindrome
title: Valid Palindrome
difficulty: easy
order: 4
patterns: [Two pointers, Strings]
prerequisites: [m07, m15]
summary: Does it read the same forward and backward? Two converging indices and a performance trap that's specific to Swift.
solutionFile: ValidPalindrome.swift
testFile: ValidPalindromeTests.swift
starter: |
  func isPalindrome(_ s: String) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(n) for the Array copy
edgeCases:
  - Empty string
  - A string with only spaces or punctuation
  - A mix of letters and digits, like "0P"
  - A single character
askInterviewer:
  - Which characters count? Only letters and digits?
  - Is the comparison case-sensitive?
  - Can the input contain non-ASCII characters, like accents or emoji?
hints:
  - Solve it first by cleaning the string and comparing it with its reverse. Then look for a way to skip the cleaned copy.
  - Two indices, one at each end. What do you do when one of them points at a space?
  - "In Swift, `s[i]` with an integer doesn't compile: String indices aren't integers. What conversion lets you index in O(1)?"
followUps:
  - "Valid Palindrome II: what if you're allowed to delete at most one character?"
  - Why doesn't Swift let you index a String with integers?
  - How does your solution change if the input has emoji or combining accents?
rubric:
  - I clarified which characters count and whether case matters.
  - I used two converging indices without building a cleaned string, or I explained that trade-off.
  - The empty string returns true.
  - I explained why I converted to an Array for indexing.
codeStatus: tested
---

A phrase is a palindrome if, after lowercasing everything and removing anything that isn't a letter or a digit, it reads the same forward and backward.

Write `isPalindrome(_ s: String) -> Bool`.

```swift
isPalindrome("A man, a plan, a canal: Panama")  // true
isPalindrome("race a car")                      // false
isPalindrome(" ")                               // true: nothing is left
```

**Constraints:** `0 ≤ s.count ≤ 2·10^5`.

<!-- reveal -->

## First approach

There are two jobs: decide which characters count, and compare from the outside in. You can do both at once with two indices.

## Naive solution

```swift
func isPalindrome(_ s: String) -> Bool {
    let cleaned = s.lowercased().filter { $0.isLetter || $0.isNumber }
    return cleaned == String(cleaned.reversed())
}
```

## Problems with the naive solution

It's correct and O(n), and in Swift it's a legitimate answer. The cost is memory: it builds the cleaned string and its reverse, two extra copies. In an interview you'll usually be asked for the next step: compare without building the cleaned string.

## Optimized solution

Convert the string to an `Array` of `Character` so you can index by position in O(1). Start `left` at the beginning and `right` at the end. Skip anything that doesn't count; if the two valid characters differ, it's not a palindrome. If the indices cross without a mismatch, it is.

## Line by line

- `Array(s.lowercased())`: in Swift, `String` can't be indexed with integers because a `Character` can take up several bytes (an emoji, or a letter with a combining accent). Asking for "character 5000" would mean walking from the start. The `Array` gives you O(1) access in exchange for O(n) memory.
- `var right = characters.count - 1`: for the empty string this is −1, the loop never runs, and the answer is `true`.
- `while left < right`: once they cross, everything has been compared.
- The two `continue` statements skip characters that don't count without moving the other index.
- `characters[left] != characters[right]`: the first mismatch is enough to answer `false`.

## Common mistakes

- Trying `s[i]` with an `Int`: it doesn't compile in Swift.
- Using `s.index(s.startIndex, offsetBy: i)` inside the loop. It compiles, but each call is O(i), so the total becomes O(n²).
- Forgetting to lowercase and deciding that "Aa" isn't a palindrome.

## Variation

**Valid Palindrome II:** you may delete at most one character. At the first mismatch, check whether `[left+1...right]` or `[left...right-1]` is a palindrome. It's still O(n).
