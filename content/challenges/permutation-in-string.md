---
id: permutation-in-string
title: Permutation in String
difficulty: medium
order: 19
patterns: [Sliding window, Fixed-size window, Frequency counter]
prerequisites: [m07, m15, m16-l04, m16-l05]
summary: Does the text contain some rearrangement of a short pattern? A window of fixed width that compares letter counts as it slides.
solutionFile: PermutationInString.swift
testFile: PermutationInStringTests.swift
starter: |
  func containsRearrangement(of pattern: String, in text: String) -> Bool {
      // Your solution
      return false
  }
time: O(n + m)
space: O(n + m) for the byte arrays, O(1) for the counters
edgeCases:
  - Empty pattern
  - Pattern longer than the text
  - The match is the whole text, its start or its end
  - Repeated letters, where counts have to match exactly
askInterviewer:
  - Are both strings only lowercase a to z?
  - Does the match have to be consecutive characters?
  - What should an empty pattern return?
  - Do I need the position of the match, or just whether it exists?
hints:
  - "A rearrangement of the pattern has exactly the pattern's length. So which stretches of the text are candidates?"
  - "Two strings are rearrangements of each other when their letter counts match. How do the counts change when the window moves one step?"
  - "Keep 26 counters for the window: add the letter that enters, subtract the one that leaves, and compare with the pattern's counters."
followUps:
  - "Find all anagrams: return every start index where a rearrangement begins."
  - "How would you avoid comparing all 26 counters on each step? (Track how many letters currently match.)"
  - What changes if the alphabet is all of Unicode?
rubric:
  - I noticed the window has a fixed size equal to the pattern's length.
  - I compared letter counts, not sorted strings.
  - I updated the counts in O(1) per slide (add one, remove one).
  - I handled an empty pattern and a pattern longer than the text.
codeStatus: tested
---

A word game hides a word inside a longer line of letters, with its letters shuffled but kept together. Given a short `pattern` and a `text`, return `true` if some stretch of consecutive characters in `text` uses exactly the letters of `pattern`, each as many times, in any order.

Write `containsRearrangement(of pattern: String, in text: String) -> Bool`.

```swift
containsRearrangement(of: "tea", in: "neatly")     // true: "eat"
containsRearrangement(of: "tea", in: "breakfast")  // false
containsRearrangement(of: "aab", in: "cbaac")      // true: "baa"
containsRearrangement(of: "", in: "abc")           // true: the empty stretch
```

**Constraints:** `0 ≤ pattern.count, text.count ≤ 10^4`; both contain only the lowercase letters `a` to `z`.

<!-- reveal -->

## First approach

Any rearrangement of the pattern has the pattern's length, m. So the candidates are exactly the n − m + 1 stretches of length m: a window of fixed size. Two strings are rearrangements of each other when their letter counts are equal, and when the window moves one step, its counts change by one letter in and one letter out.

## Naive solution

Sort every window and compare it with the sorted pattern:

```swift
func containsRearrangement(of pattern: String, in text: String) -> Bool {
    let wanted = pattern.sorted()
    let letters = Array(text)
    guard wanted.count <= letters.count else { return false }
    for start in 0...(letters.count - wanted.count)
    where letters[start..<(start + wanted.count)].sorted() == wanted {
        return true
    }
    return false
}
```

## Problems with the naive solution

Each of the n − m + 1 windows is sorted from scratch: **O(n · m log m)**. With a 5,000-letter pattern in a 10,000-letter text, that's about 5,000 sorts of 5,000 letters. Consecutive windows share all but two letters, and sorting throws that away.

## Optimized solution

Count the pattern's letters into 26 counters, and the first m letters of the text into another 26. If they're equal, done. Then slide: for each new position `right`, add `letters[right]` and remove `letters[right − m]`, and compare again.

## Line by line

- `Array(pattern.utf8)`, `Array(text.utf8)`: lowercase ASCII letters are one byte each, and `byte - 97` maps `a`...`z` to 0...25 (97 is the code of `a`).
- `guard size <= letters.count else { return false }`: a longer pattern can't fit. It also keeps the first loop from reading past the end of the text.
- The first loop fills both sets of counters over the first `size` positions. With an empty pattern it doesn't run, both arrays are all zeros, and the function returns `true`.
- `for right in size..<letters.count`: `right` is the letter entering; `right - size` is the letter leaving, so the window is always `(right − size + 1)...right`, exactly `size` letters.
- `windowCounts == patternCounts`: array equality compares 26 integers, a constant. So the whole function is **O(26 · n + m)**, which is O(n + m).

## Common mistakes

- Comparing sets of letters instead of counts: "aab" and "abb" have the same set.
- Getting the leaving index wrong by one, so the window is `size + 1` or `size − 1` letters wide.
- Forgetting the very first window, or checking only after sliding, which misses a match at the start of the text.
- Writing the guard as `size < letters.count`, which wrongly rejects a pattern that's exactly as long as the text.

## Variation

**Find all anagrams:** return every start index where a rearrangement of the pattern begins. Same window; instead of returning `true`, append `right − size + 1` (and 0 for the first window). To drop the 26-counter comparison, keep a number `matches`, the count of letters whose counters agree, and update it as each letter enters and leaves; the window matches when it's 26.
