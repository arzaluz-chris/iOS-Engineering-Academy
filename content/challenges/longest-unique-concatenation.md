---
id: longest-unique-concatenation
title: Longest Concatenation of Unique Letters
difficulty: medium
order: 51
patterns: [Backtracking, Subsets, Bit masks]
prerequisites: [m18-l02, m18-l03]
summary: Pick words so that no letter repeats and the total length is as large as possible. Take-or-skip backtracking, with each word turned into a 26-bit mask.
solutionFile: LongestUniqueConcatenation.swift
testFile: LongestUniqueConcatenationTests.swift
starter: |
  func longestUniqueConcatenation(_ words: [String]) -> Int {
      // Your solution
      return 0
  }
time: O(n · 2^n) in the worst case, plus O(L) to read the letters
space: O(n)
edgeCases:
  - Empty list, and empty words
  - A word that repeats a letter by itself, which can never be used
  - Words that together use all 26 letters
  - Inputs where taking the longest word first is wrong
askInterviewer:
  - Which characters can appear? Only lowercase a to z?
  - Does the order of the chosen words matter? (Not for the length.)
  - How many words can there be? That decides whether trying subsets is acceptable.
  - Do I return the length or the string itself?
hints:
  - Each word is either in the answer or not. What does that remind you of from the backtracking lesson?
  - A word with a repeated letter can never be chosen. Drop those first.
  - Checking "do these two sets of letters overlap?" letter by letter is slow. With only 26 letters, how could one Int hold a word's letters?
followUps:
  - How would you return the string itself, or every string of maximum length?
  - What bound could prune more? (If the current length plus all remaining lengths can't beat the best, stop.)
  - How would you handle all of Unicode instead of a to z?
rubric:
  - I saw this as choosing a subset and wrote take-or-skip backtracking.
  - I discarded words with internal repeats before searching.
  - I represented letter sets as bit masks and tested overlap with a single &.
  - I explained why a greedy choice doesn't work, with an example.
codeStatus: tested
---

A word game gives you a handful of word tiles. You can lay any of them side by side, in any order, but the result must not contain the same letter twice. Write `longestUniqueConcatenation(_:)` that returns the length of the longest string you can build. Each tile can be used at most once, and you can use none.

```swift
longestUniqueConcatenation(["sky", "lab", "kite", "mud"])  // 10: "kite" + "lab" + "mud"
longestUniqueConcatenation(["moon", "sun", "star"])        // 4: "moon" repeats "o", and "sun" and "star" share "s"
longestUniqueConcatenation(["aa", "bb"])                   // 0
```

**Constraints:** `0 ≤ words.count ≤ 16`; `0 ≤ words[i].count ≤ 26`; words contain only lowercase letters `a` to `z`.

<!-- reveal -->

## First approach

Every word is a yes-or-no decision, so the candidates are the subsets of the word list: Module 18's subsets generator. The work at each step is checking whether a word clashes with the letters already chosen. With 16 words there are at most 65,536 subsets, so searching them is fine; what matters is making each check cheap and cutting branches that already clash.

## Naive solution

Build each subset's concatenation and check it with a `Set`:

```swift
func longestUniqueConcatenation(_ words: [String]) -> Int {
    var best = 0
    for selection in 0..<(1 << words.count) {
        var text = ""
        for index in words.indices where selection & (1 << index) != 0 {
            text += words[index]
        }
        if Set(text).count == text.count {
            best = max(best, text.count)
        }
    }
    return best
}
```

`1 << index` is a number with only bit `index` set, so `selection & (1 << index) != 0` asks "is word `index` in this subset?". Counting `selection` from 0 to 2ⁿ − 1 walks through every subset once.

## Problems with the naive solution

It visits all 2ⁿ subsets **even after a clash**: once "sun" and "star" collide, every larger subset containing both is still built and checked. Each check builds a string and a `Set` of up to 26 characters. It's **O(2ⁿ · L)** for L total letters, with a large constant from string concatenation and hashing.

## Optimized solution

Turn each word into a mask: bit 0 for `a`, bit 1 for `b`, and so on. A word with a repeated letter is skipped while building its mask. Then backtrack: from each state, try adding each later word, but only if `mask & used == 0`, meaning no shared letters. A clash cuts the whole branch. Every state visited is a valid string, so the answer is the largest length seen.

## Line by line

- `for byte in word.utf8`: letters `a` to `z` are single bytes 97 to 122 in UTF-8, which is faster to read than `Character`s. The `precondition` enforces the input rule.
- `let bit = 1 << Int(byte - 97)`: `a` is bit 0, `z` is bit 25.
- `if mask & bit != 0 { valid = false; break }`: the letter is already in this word, so the word can never be used.
- `masks.append((mask, word.utf8.count))`: keep the mask and the length together; the length is all the answer needs.
- `func explore(from index: Int, used: Int, length: Int)`: `used` holds the letters chosen so far, `length` their count. Passing them as parameters means there's nothing to undo after each call.
- `best = max(best, length)`: every state is a valid concatenation, including the empty one.
- `for next in index..<masks.count where masks[next].mask & used == 0`: only words after the current one (so each subset is built once) and only words with no shared letters.
- `explore(from: next + 1, used: used | masks[next].mask, length: length + masks[next].length)`: choose the word by adding its letters with `|`.

## Common mistakes

- Taking the longest word first. With `["abcdef", "abcg", "dehi"]`, "abcdef" (6) blocks both others, while "abcg" + "dehi" gives 8.
- Keeping words that repeat a letter internally. Their mask looks fine (bits can't be set twice), so you have to catch the repeat while building it.
- Starting the loop at 0 instead of `index`, which builds the same subset in every order: n! work instead of 2ⁿ.
- Comparing `Set<Character>`s for every pair. It works, but the mask is what makes the check O(1).

## Variation

**Maximum score words:** each letter has a score and you have a limited supply of each letter; pick words to maximize the score. Same take-or-skip search, but the state is a count per letter instead of a mask, and "choose" subtracts from the counts while "unchoose" adds them back.
