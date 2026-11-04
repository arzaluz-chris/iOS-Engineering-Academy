---
id: group-shifted-strings
title: Group Shifted Strings
difficulty: medium
order: 7
patterns: [Hash map, Canonical key, Strings]
prerequisites: [m07, m15, m16-l05]
summary: Group words that are the same message under a Caesar cipher. The trick is finding a key every member of a group shares.
solutionFile: GroupShiftedStrings.swift
testFile: GroupShiftedStringsTests.swift
starter: |
  func groupShiftedWords(_ words: [String]) -> [[String]] {
      // Your solution
      return []
  }
time: O(n · k) on average, for n words of up to k letters
space: O(n · k)
edgeCases:
  - An empty list
  - The empty word, and several copies of it
  - A shift that wraps around, like "az" and "ba"
  - The same word twice
  - Words with the same shape but different lengths, which never match
askInterviewer:
  - Are the words only lowercase a to z?
  - Does the shift wrap from z back to a?
  - In what order should the groups, and the words inside each group, come out?
  - Can a word be empty, or appear twice?
hints:
  - "Comparing every word with every other word works. To group in one pass instead, you need something every word in a group has in common. What stays the same when you shift all the letters by one?"
  - "Look at the gaps: in \"ace\" each letter is two after the previous one, and the same is true of \"bdf\". Or shift every word so it starts with \"a\" and see what you get."
  - "Distances have to wrap: in \"za\", the \"a\" is one step after \"z\". Compute them modulo 26."
followUps:
  - "Why does the key use each letter's distance from the first letter, and not the raw letters?"
  - What would change if the shift could also go backward, or if words could contain uppercase letters?
  - How would you return the groups sorted by size, largest first?
rubric:
  - I identified a canonical key that's equal exactly for words in the same group.
  - I handled the wrap-around from z to a with modulo arithmetic.
  - I kept the output order deterministic instead of depending on dictionary order.
  - I stated O(n · k) time on average and compared it with the O(n² · k) pairwise version.
codeStatus: tested
---

A puzzle app hides messages with a Caesar cipher: every letter moves forward the same number of places in the alphabet, wrapping from `z` back to `a`. Shifting `"ace"` by one gives `"bdf"`; shifting `"zbd"` by one gives `"ace"`. Two words belong together if one is a shift of the other.

Write `groupShiftedWords(_ words: [String]) -> [[String]]` that groups the words. Groups come out in the order their first word appears in the input, and words keep their input order inside each group.

```swift
groupShiftedWords(["ace", "bdf", "hal", "zbd", "ibm", "x", "a", "yza"])
// [["ace", "bdf", "zbd"], ["hal", "ibm"], ["x", "a"], ["yza"]]

groupShiftedWords(["az", "ba", "za"])  // [["az", "ba"], ["za"]]
```

**Constraints:** `0 ≤ words.count ≤ 10^4`; each word has `0` to `50` lowercase letters `a` to `z`. A shift of 0 is a shift, so equal words go together, and so do empty words.

<!-- reveal -->

## First approach

A group needs a fingerprint that every member shares and no outsider has. Shifting a word changes every letter, but not the **distance** between its letters. Measure each letter's distance from the word's first letter, modulo 26, and you get a key that's the same for the whole group: it's what the word looks like after shifting it to start with `a`. Then it's grouping by a key with a dictionary.

## Naive solution

Compare each word with the first word of every group so far, and add it to the first group that matches:

```swift
func groupShiftedWords(_ words: [String]) -> [[String]] {
    var groups: [[String]] = []
    for word in words {
        if let index = groups.firstIndex(where: { isShift($0[0], of: word) }) {
            groups[index].append(word)
        } else {
            groups.append([word])
        }
    }
    return groups
}

func isShift(_ first: String, of second: String) -> Bool {
    let a = Array(first.utf8)
    let b = Array(second.utf8)
    guard a.count == b.count else { return false }
    guard let firstA = a.first, let firstB = b.first else { return true }
    let shift = (Int(firstB) - Int(firstA) + 26) % 26
    for (x, y) in zip(a, b) where (Int(x) - 97 + shift) % 26 != Int(y) - 97 {
        return false
    }
    return true
}
```

## Problems with the naive solution

Each word is compared with every group, and each comparison is O(k). If no two words match, there are n groups, so it's **O(n² · k)**: with 10^4 words that's 5·10^7 comparisons of up to 50 letters. `firstIndex(where:)` hides the inner loop, which makes the cost easy to miss.

## Optimized solution

Compute the key of each word once: the list of distances from its first letter, each in `0...25`. A dictionary maps each key to the index of its group in the result array. A new key starts a new group at the end of the array, which keeps groups in order of first appearance without sorting anything.

## Line by line

- `groupIndexByKey: [[UInt8]: Int]`: arrays are `Hashable` when their elements are, so `[UInt8]` works as a key directly.
- `groups: [[String]]`: the answer, built in order. The dictionary stores positions in it rather than the groups themselves, so the output order never depends on dictionary order.
- `shiftKey(of:)` reads the word's UTF-8 bytes. All the letters are ASCII, so each one is a single byte from 97 (`a`) to 122 (`z`).
- `guard let first = letters.first else { return [] }`: the empty word gets the empty key, so all empty words land in one group.
- `(letter + 26 - first) % 26`: the distance from the first letter, wrapped into `0...25`. Adding 26 first keeps the subtraction from going below zero, which would trap for `UInt8`. For `"za"`, the distances are 0 and (97 + 26 − 122) % 26 = 1; for `"ab"` they're 0 and 1 too.
- `if let index = groupIndexByKey[key]`: a known key appends to its group; a new one records `groups.count` as its index and appends a new group.

## Common mistakes

- Using the gaps between neighbors without wrapping: `"az"` has a gap of 25 and `"ba"` a gap of −1, and they'd land in different groups.
- Building the key as a `String` of numbers with no separator: distances `[1, 12]` and `[11, 2]` both become `"112"`. Use an array, or put a separator between the numbers.
- Returning `Array(dictionary.values)`. The groups are right, but their order changes from run to run, and tests that compare arrays fail at random.

## Variation

**Group Anagrams** uses the same structure with a different key: the sorted letters, or 26 letter counts. Picking a key that's equal exactly for the things you consider "the same" is the whole problem in both.
