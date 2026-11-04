---
id: text-justification
title: Text Justification
difficulty: hard
order: 100
patterns: [Greedy line packing, Simulation, String building]
prerequisites: [m04-l06, m20-l01]
summary: Lay out words in fixed-width, fully justified lines with the spaces spread evenly. No clever algorithm, just greedy packing and arithmetic that has to be exactly right.
solutionFile: TextJustification.swift
testFile: TextJustificationTests.swift
starter: |
  func justifyText(_ words: [String], width: Int) -> [String] {
      // Your solution
      return []
  }
time: O(c + l · width) for c characters in the words and l lines
space: O(c + l · width) for the output
edgeCases:
  - No words, which gives no lines
  - A word exactly as wide as the line
  - A line with a single word, which is left-aligned
  - The last line, which is left-aligned and padded
  - Spaces that don't divide evenly, where the extra ones go to the left
askInterviewer:
  - How are the extra spaces distributed when they don't divide evenly?
  - How should the last line and single-word lines be aligned? Padded with trailing spaces?
  - Can a word be longer than the width? Can words contain spaces?
  - Are lengths counted in characters, or in rendered width?
hints:
  - Separate the two jobs, deciding which words go on each line, then laying out one line.
  - A line with k words needs at least k - 1 spaces. When does the next word still fit?
  - With s spaces to share over g gaps, every gap gets s / g. How many gaps get one more, and which ones?
followUps:
  - Real labels measure rendered width, not characters. What changes with proportional fonts?
  - Instead of greedy packing, minimize the total squared slack at the end of lines (dynamic programming, as in Knuth's line breaking).
  - Break a word that's longer than the width, with a hyphen.
rubric:
  - I asked how extra spaces, single-word lines and the last line are handled.
  - I packed lines greedily with the right fit condition (letters plus one space per gap).
  - I distributed spaces with division and remainder, extras to the left.
  - I tested the edge cases, including a word exactly the width and the empty input.
codeStatus: tested
---

A custom text view for an e-reader needs fully justified lines in a monospaced font. Given `words` and a line `width`, return the lines of text, each **exactly `width` characters** long:

- Each line holds as many words as fit, in order, with at least one space between neighbors.
- The spaces on a line are spread over the gaps as evenly as possible. When they don't divide evenly, the leftmost gaps get one more.
- A line with a single word, and the last line, are left-aligned: one space between words, then spaces on the right up to `width`.

```swift
justifyText(["Your", "order", "is", "on", "its", "way", "to", "you"], width: 12)
// ["Your   order",
//  "is   on  its",
//  "way to you  "]

justifyText(["Hello", "world"], width: 7)
// ["Hello  ", "world  "]
```

**Constraints:** `0 ≤ words.count ≤ 300`; `1 ≤ width ≤ 100`; every word has 1 to `width` characters and no spaces. Lengths are counted in `Character`s.

<!-- reveal -->

## First approach

There are two separate jobs. First, decide which words go on each line: take words while they fit, which is a greedy rule, and it's the right one here because the problem defines the layout that way. Second, lay out one line: the leftover width is shared by the gaps, which is integer division with a remainder. Nearly all the difficulty is in getting the fit condition, the special lines and the remainder exactly right.

## Naive solution

Pack each line, join it with single spaces, then insert one extra space at a time, cycling through the gaps from the left:

```swift
func justifyText(_ words: [String], width: Int) -> [String] {
    var lines: [String] = []
    var start = 0
    while start < words.count {
        var end = start
        var length = -1
        while end < words.count && length + 1 + words[end].count <= width {
            length += 1 + words[end].count
            end += 1
        }
        var line = Array(words[start..<end].joined(separator: " "))
        let gaps = end - start - 1
        if gaps == 0 || end == words.count {
            line += Array(repeating: " ", count: width - line.count)
        } else {
            var gap = 0
            while line.count < width {
                // Find where gap number `gap` starts: the first space after word number `gap`.
                var wordsPassed = 0
                var index = 0
                while true {
                    if line[index] == " " && line[index - 1] != " " {
                        if wordsPassed == gap { break }
                        wordsPassed += 1
                    }
                    index += 1
                }
                line.insert(" ", at: index)
                gap = (gap + 1) % gaps
            }
        }
        lines.append(String(line))
        start = end
    }
    return lines
}
```

## Problems with the naive solution

It produces the right output, and it's how many people first think about the problem: "add spaces round-robin". But each insertion scans the line to find the gap and shifts everything after it, O(width), and a line can need up to `width` insertions: O(width²) per line. The scan for "the start of gap number k" is also fiddly code that's easy to get wrong. Since the number of spaces each gap gets can be computed directly, there's no reason to simulate it.

## Optimized solution

Pack greedily, counting only letters: the next word fits if `letters + nextWord.count + (number of words already on the line) ≤ width`, because adding it brings the number of gaps up to the number of words already there. Then, for a normal line with `gaps` gaps and `spaces = width - letters`, each gap gets `spaces / gaps` and the first `spaces % gaps` gaps get one more. Single-word lines and the last line are joined with single spaces and padded on the right.

## Line by line

- `var end = start + 1` and `var letters = words[start].count`: every line takes at least one word, which always fits by the constraints.
- `while end < words.count && letters + words[end].count + (end - start) <= width`: `end - start` is the number of words already on the line, which is how many single spaces the line needs once `words[end]` joins it.
- `let gaps = end - start - 1`: spaces go between words, so one fewer than the word count.
- `if gaps == 0 || end == words.count`: a single word, or the last line. Join with single spaces and pad with `width - line.count` spaces on the right.
- `let spacesPerGap = spaces / gaps` and `let gapsWithExtraSpace = spaces % gaps`: the even share and the remainder.
- `spacesPerGap + (gap < gapsWithExtraSpace ? 1 : 0)`: the first `gapsWithExtraSpace` gaps, the leftmost ones, get one extra space.
- `line += words[end - 1]`: the last word on the line has no gap after it.
- `start = end`: the next line starts with the first word that didn't fit.

## Common mistakes

- Counting a space after the last word in the fit check, which pushes a word that fits exactly onto the next line.
- Dividing by `gaps` on a single-word line: a division by zero, which traps in Swift.
- Justifying the last line.
- Giving the extra spaces to the rightmost gaps, or to the first gap only.
- Measuring with `utf16.count` or byte counts when the problem counts characters. For "é" or an emoji they differ.

## Variation

**Minimum raggedness:** for left-aligned text that looks even, choose line breaks that minimize the sum of the squared trailing spaces over all lines but the last. Greedy packing can leave one very short line; a DP over "the best layout of words i...n-1" considers every possible first line and fixes that, in O(n²) time or O(n · width) if you stop when the line overflows.
