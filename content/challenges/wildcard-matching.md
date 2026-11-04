---
id: wildcard-matching
title: Wildcard Matching
difficulty: hard
order: 89
patterns: [2-D dynamic programming, String matching]
prerequisites: [m20-l03, m20-l05]
summary: Match file names against patterns with ? and *. A 2-D table over a text prefix and a pattern prefix, where a star either matches nothing or eats one more character.
solutionFile: WildcardMatching.swift
testFile: WildcardMatchingTests.swift
starter: |
  func wildcardMatches(_ text: String, pattern: String) -> Bool {
      // Your solution
      return false
  }
time: O(n · m) for text length n and pattern length m
space: O(m) extra
edgeCases:
  - Empty text and empty pattern (match)
  - Empty text with a pattern of only stars (match)
  - A pattern that matches a prefix but not the whole text
  - Several stars in a row
  - A star that has to match nothing
  - Question marks that need exactly one character each
askInterviewer:
  - Does the pattern have to match the whole text, or any part of it?
  - Can a star match an empty run of characters?
  - Is there an escape character for a literal * or ?
  - Is the match case-sensitive?
hints:
  - Write it as a recursion over (position in text, position in pattern). What are the cases for a letter, a ? and a *?
  - A star has exactly two choices, match nothing (move on in the pattern) or match one more character (move on in the text and stay on the star).
  - Turn the recursion into a table over prefixes. Which entries does matches[i][j] read when the pattern character is a star?
followUps:
  - Add an escape character so \* matches a literal star.
  - There's a greedy algorithm with backtracking to the last star that uses O(1) extra space. Explain why it works for * but not for regular expressions with x*.
  - Support character classes like [a-z].
rubric:
  - I wrote the recursion with the three cases and the base case for an exhausted pattern.
  - I explained the two choices for a star.
  - I built the table over prefixes, initializing the empty-text row for leading stars.
  - I reduced the space to one row and stated O(n · m) time.
codeStatus: tested
---

A photo app lets people filter files with simple patterns. In a pattern, `?` matches exactly one character, `*` matches any run of characters (including an empty one), and every other character matches itself. Return `true` if `pattern` matches **all** of `text`.

```swift
wildcardMatches("IMG_0042.HEIC", pattern: "IMG_????.HEIC")          // true
wildcardMatches("report.pdf", pattern: "*.png")                    // false
wildcardMatches("backup-2026-11.zip", pattern: "backup-*.zip")     // true
wildcardMatches("IMG_42.HEIC", pattern: "IMG_????.HEIC")           // false: ? needs exactly one character
```

**Constraints:** `0 ≤ text.count, pattern.count ≤ 2,000`. The text contains no `?` or `*`.

<!-- reveal -->

## First approach

Match from the left. A normal character in the pattern has to equal the next text character, and so must a `?`, except it accepts anything. A `*` is the only real decision: it can match nothing (skip it in the pattern) or swallow the next text character and stay put, ready to swallow more. The state is "how much of the text and how much of the pattern have been used", two indexes, so the subproblems fit in a 2-D table, as with edit distance in Module 20, lesson 5.

## Naive solution

The recursion, as described:

```swift
func wildcardMatches(_ text: String, pattern: String) -> Bool {
    let textCharacters = Array(text)
    let patternCharacters = Array(pattern)
    func matches(_ i: Int, _ j: Int) -> Bool {
        if j == patternCharacters.count { return i == textCharacters.count }
        if patternCharacters[j] == "*" {
            return matches(i, j + 1) || (i < textCharacters.count && matches(i + 1, j))
        }
        guard i < textCharacters.count,
              patternCharacters[j] == "?" || patternCharacters[j] == textCharacters[i] else { return false }
        return matches(i + 1, j + 1)
    }
    return matches(0, 0)
}
```

## Problems with the naive solution

Every star branches in two, and the branches meet again at the same `(i, j)` many times. A pattern like `"*a*a*a*a*b"` against a long run of `a`s with no `b` makes it try every way to split the `a`s between the stars before failing: on the order of n^k attempts for k stars, so it grows exponentially with the pattern. There are only `(n + 1) · (m + 1)` distinct states, so memoizing or tabulating makes it polynomial.

## Optimized solution

Let `matches[i][j]` say whether the first `j` pattern characters match the first `i` text characters. The empty pattern matches only the empty text. For the empty text, a pattern prefix matches only if it's all stars. Then, row by row:

- a star: `matches[i][j - 1]` (it matches nothing) or `matches[i - 1][j]` (it took the text character `i - 1` and may have taken more before);
- a `?`: `matches[i - 1][j - 1]`;
- a letter: `matches[i - 1][j - 1]` and the two characters are equal.

Each row reads only the row above and the entry to its left, so keep two rows.

## Line by line

- `var previous = Array(repeating: false, count: patternCount + 1)` with `previous[0] = true`: the row for the empty text. The empty pattern matches it.
- `previous[j] = previous[j - 1] && patternCharacters[j - 1] == "*"`: leading stars can match nothing; the first non-star breaks the chain for the rest of the row.
- `for character in textCharacters`: one row per text character. `current[0]` stays `false`: an empty pattern can't match non-empty text.
- `case "*": current[j] = current[j - 1] || previous[j]`: `current[j - 1]` is "the star matches nothing here"; `previous[j]` is "the star matches this character, plus whatever it matched before".
- `case "?": current[j] = previous[j - 1]`: any single character works.
- `default: current[j] = previous[j - 1] && patternCharacters[j - 1] == character`: a literal must match exactly.
- `previous = current` and finally `return previous[patternCount]`: the whole pattern against the whole text.

## Common mistakes

- Initializing only `matches[0][0]` and forgetting that `"*"`, `"**"` and so on match the empty text.
- Treating the star like a regular expression `x*`, which repeats the previous character. Here it stands on its own.
- Returning `true` when the pattern is used up but text remains (matching a prefix).
- Updating a single row in place for the `?` and letter cases, which overwrites `previous[j - 1]` before it's read.

## Variation

**Greedy with backtracking:** walk both strings; on a star, remember its position and the text position, and try matching nothing. On a mismatch, go back to the last star and let it swallow one more character. Only the last star needs remembering, because any earlier star could absorb whatever a later one would. O(1) extra space, O(n · m) worst-case time, and usually much faster in practice.
