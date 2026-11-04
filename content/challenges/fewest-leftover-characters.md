---
id: fewest-leftover-characters
title: Fewest Leftover Characters
difficulty: medium
order: 86
patterns: [1-D dynamic programming over suffixes, String segmentation]
prerequisites: [m20-l03, m20-l04]
summary: Split a string into dictionary words and stray characters, with as few strays as possible. Word segmentation that has to cope with text that doesn't split cleanly.
solutionFile: FewestLeftoverCharacters.swift
testFile: FewestLeftoverCharactersTests.swift
starter: |
  func fewestLeftoverCharacters(_ text: String, words: Set<String>) -> Int {
      // Your solution
      return 0
  }
time: O(n · L²), where L is the length of the longest word
space: O(n + L) extra
edgeCases:
  - Empty text (0) and an empty dictionary (every character is left over)
  - A string that splits completely
  - Overlapping words where taking one blocks the other
  - The same word used several times
  - A longest-match-first split that's worse than another split
askInterviewer:
  - Can a word be used more than once?
  - Is the comparison case-sensitive? Which characters can appear?
  - How long are the text and the longest word?
  - Do you want the count only, or the split itself?
hints:
  - At position i, there are two kinds of moves. What are they, and where does each one leave you?
  - Let fewest[i] be the answer for the suffix that starts at i. Which entries does it read? In which order should you fill the table?
  - A word can't be longer than the longest word in the dictionary. How does that bound the inner loop?
followUps:
  - Build a trie of the words so each start position walks forward once instead of hashing every substring.
  - Return the actual split, with the leftover characters marked.
  - What if each leftover character had a different cost?
rubric:
  - I identified the two choices at each position (leave a character, or match a word).
  - I defined fewest[i] over suffixes and filled it from right to left.
  - I bounded candidate words by the longest word's length and stated the resulting complexity.
  - I showed that greedily taking the longest match can be wrong.
codeStatus: tested
---

A social app turns run-together hashtags into readable text: `#darkmodeon` becomes "dark mode on". Not every hashtag splits cleanly, so the app wants to know how messy the best split is. Given `text` and a set of dictionary `words`, split `text` into pieces where each piece is either a word from the set or a **single leftover character**. Return the fewest leftover characters any split can have. Words can be used any number of times.

```swift
fewestLeftoverCharacters("swiftxui", words: ["swift", "ui"])                         // 1: swift, x, ui
fewestLeftoverCharacters("darkmodeon", words: ["dark", "mode", "darkmode", "on"])   // 0
fewestLeftoverCharacters("abc", words: ["xyz"])                                     // 3
```

**Constraints:** `0 ≤ text.count ≤ 10^4`; `0 ≤ words.count ≤ 1,000`; each word has 1 to 30 lowercase ASCII letters, and so does `text`.

<!-- reveal -->

## First approach

Stand at position `i`. Either the character at `i` is left over, and you continue from `i + 1` with one more leftover, or some dictionary word starts at `i` and ends at `end`, and you continue from `end` for free. The best result from a position doesn't depend on how you got there, and many different splits reach the same position. That's Module 20, lesson 3's hashtag problem, with a minimum instead of a yes or no.

## Naive solution

The same choices as a plain recursion:

```swift
func fewestLeftoverCharacters(_ text: String, words: Set<String>) -> Int {
    let characters = Array(text)
    func fewest(from start: Int) -> Int {
        guard start < characters.count else { return 0 }
        var best = 1 + fewest(from: start + 1)
        for end in (start + 1)...characters.count where words.contains(String(characters[start..<end])) {
            best = min(best, fewest(from: end))
        }
        return best
    }
    return fewest(from: 0)
}
```

## Problems with the naive solution

Every call makes at least one recursive call for the next position plus one for every word that matches, and none of the answers are remembered. On a text like `"aaaa…"` with the words `"a"` and `"aa"`, each position is reached through exponentially many paths, so the number of calls grows exponentially. It also builds a substring for every possible end, up to the end of the text, even though no word is longer than 30 characters.

## Optimized solution

Fill `fewest[i]`, the answer for the suffix starting at `i`, from the end of the text to the start. `fewest[n] = 0`: nothing left, nothing over. For each `start`, begin with the leftover option, `1 + fewest[start + 1]`, then try every `end` up to `start + longestWord` and, when `characters[start..<end]` is a word, take `fewest[end]` if it's smaller. The answer is `fewest[0]`.

## Line by line

- `let characters = Array(text)`: Swift strings can't be indexed by `Int`. An array of `Character` can.
- `let longestWord = words.map(\.count).max() ?? 0`: no word is longer than this, so no longer piece is worth building. With an empty dictionary it's 0 and the inner loop never runs.
- `var fewest = Array(repeating: 0, count: characters.count + 1)`: one extra entry for the empty suffix.
- `stride(from: characters.count - 1, through: 0, by: -1)`: right to left, because `fewest[start]` reads entries to its right. With an empty text this stride is empty.
- `var best = 1 + fewest[start + 1]`: the leftover option is always available.
- `stride(from: start + 1, through: farthestEnd, by: 1)`: every end that keeps the piece within the longest word and the text. `stride` is empty when the bound is smaller, where a closed range `start + 1...farthestEnd` would trap.
- `where words.contains(String(characters[start..<end]))`: builds the candidate and hashes it, O(L) each, which is where O(n · L²) comes from.
- `return fewest[0]`: the answer for the whole text.

## Common mistakes

- Taking the longest matching word first. On `"abcdef"` with `"abcd"`, `"ab"` and `"cdef"`, greedy leaves 2 characters over; `"ab"` + `"cdef"` leaves none.
- Filling the table left to right while reading entries to the right.
- Looping `end` all the way to the end of the text: correct, but O(n²) substrings for no reason.
- Treating a failed match as "impossible" (as in the yes/no version) and forgetting that a leftover character is always an option.

## Variation

**Word Break II, all splits:** return every way to split the text into words only. The number of splits can be exponential, so memoize the list of sentences for each suffix and expect the output size to dominate. Prune first with the yes/no table so you never explore a suffix that can't be split.
