---
id: wildcard-word-dictionary
title: Wildcard Word Dictionary
difficulty: medium
order: 74
patterns: [Trie, Depth-first search, Backtracking]
prerequisites: [m18-l02, m19-l03]
summary: A word list that answers searches where a dot matches any letter. A trie handles fixed letters in O(L); the dot is where you branch.
solutionFile: WildcardWordDictionary.swift
testFile: WildcardWordDictionaryTests.swift
starter: |
  final class WildcardWordDictionary {
      init() {}

      func addWord(_ word: String) {
          // Your solution
      }

      func search(_ pattern: String) -> Bool {
          // Your solution
          return false
      }
  }
time: addWord O(L); search O(L) without dots, O(total characters stored) in the worst case
space: O(total characters stored)
edgeCases:
  - A pattern that's a prefix of a stored word, but not a word itself
  - A pattern made only of dots
  - The empty word and the empty pattern
  - A dot whose first matching child leads to a dead end, so the search has to try the next one
askInterviewer:
  - Which characters can words contain? Can a word contain a dot?
  - Does a dot match exactly one character, or any number?
  - How many words, and how many searches? Which happens more often?
  - Is the empty string a valid word?
hints:
  - Without dots, this is the trie from the Module 19 lesson on tries. What does a search for "c.t" need to do at the second character?
  - A dot means "try every child". That's a branch, so recursion (or a stack) fits naturally.
  - "Why can the search never visit the same trie node twice? Think about which pattern position goes with which depth."
followUps:
  - Support `*` for any run of letters, including none. (The state becomes node plus pattern position, and you'd want memoization.)
  - Return all matching words, sorted.
  - Store children in an array of 26 instead of a dictionary. What do you gain and what do you lose?
rubric:
  - I used a trie with an end-of-word flag, so prefixes don't count as words.
  - I branched on every child for a dot and stopped at the first full match.
  - I gave the cost of search with and without dots.
  - I compared it with scanning a list of words.
codeStatus: tested
---

A crossword helper lets you type a pattern where `.` stands for an unknown letter: `c.t` should match `cat` and `cut`, but not `cart`. Build the word store behind it:

- `addWord(_:)` adds a word.
- `search(_:)` returns `true` if any added word matches the pattern. A `.` matches exactly one character; any other character matches only itself. The match has to cover the whole word.

```swift
let dictionary = WildcardWordDictionary()
for word in ["cat", "car", "card", "dog"] { dictionary.addWord(word) }

dictionary.search("car")    // true
dictionary.search("ca")     // false: "ca" is only a prefix
dictionary.search("c.r")    // true
dictionary.search("..g")    // true:  dog
dictionary.search("....")   // true:  card
dictionary.search("d.t")    // false
```

**Constraints:** up to `10^4` words, each up to 25 lowercase letters; patterns use lowercase letters and `.`; up to `10^4` calls in total.

<!-- reveal -->

## First approach

Without dots, this is exactly the trie from Module 19: walk one child per character, and check the end-of-word flag at the end. A dot means "any child will do", so at that position the search has to try each child and succeed if any of them leads to a match. That's a depth-first search over the trie, guided by the pattern.

## Naive solution

Store the words in a list and compare the pattern with every word of the same length:

```swift
final class WildcardWordDictionary {
    private var words: [[Character]] = []

    func addWord(_ word: String) {
        words.append(Array(word))
    }

    func search(_ pattern: String) -> Bool {
        let characters = Array(pattern)
        return words.contains { word in
            word.count == characters.count
                && zip(word, characters).allSatisfy { $1 == "." || $0 == $1 }
        }
    }
}
```

## Problems with the naive solution

Adding is O(1), but every search compares against every stored word: O(N · L) for N words of length up to L, even for a pattern with no dots at all. With 10^4 words and 10^4 searches that's around 10^9 character comparisons. Words that share a prefix are compared again from the start every time.

## Optimized solution

A trie shares prefixes, so a pattern with no dots follows one path: O(L). A dot fans out into every child at that depth. The worst case is a pattern of all dots, which can visit every node down to that depth. But the pattern position is always the node's depth, so no node is visited twice in one search: the cost is bounded by the size of the trie, O(total characters stored).

## Line by line

- `private final class Node`: a nested class, so its name can't clash with anything else. `children` maps a character to the next node; `endsWord` marks where a stored word ends.
- `addWord`: walks down, creating missing nodes, and sets `endsWord` on the last one. Adding the same word twice just sets the flag again.
- `let characters = Array(pattern)`: `String` can't be indexed by integer in O(1), so convert once.
- `func matches(from node: Node, at position: Int) -> Bool`: is there a stored word that continues from `node` and matches `characters[position...]`?
- `if position == characters.count { return node.endsWord }`: the pattern is used up. This is what makes `"ca"` false: the node exists, but no word ends there.
- `if character == "."`: try every child; `for … where matches(…)` returns `true` at the first child that leads to a match. If none does, `false`.
- `guard let child = node.children[character] else { return false }`: a fixed letter with no matching child is a dead end.
- `return matches(from: root, at: 0)`: the recursion depth is at most the pattern length, 25 here.

## Common mistakes

- Returning `true` when the pattern runs out, without checking `endsWord`, so prefixes count as words.
- For a dot, returning the result of the first child instead of trying the others when it fails. With `abx`, `acy` and `adz` stored, `a.z` has to get past `b` and `c`.
- Converting the pattern to an array inside the recursion, which turns O(L) into O(L²).

## Variation

**Word Search II:** given a letter grid and a list of words, find every word that can be traced through adjacent cells. Put the words in a trie and run the grid's depth-first search and the trie walk together, so a path is abandoned as soon as no stored word starts with it.
