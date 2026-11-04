---
id: decode-string
title: Decode String
difficulty: medium
order: 26
patterns: [Stack, Nested structure]
prerequisites: [m17-l01, m07]
summary: Expand a compressed string like "2[a3[b]]" where groups nest inside groups. A stack remembers where you were before each bracket opened.
solutionFile: DecodeString.swift
testFile: DecodeStringTests.swift
starter: |
  func decodeString(_ encoded: String) -> String {
      // Your solution
      return ""
  }
time: O(m · d) worst case, where m is the output length and d the nesting depth
space: O(m + d)
edgeCases:
  - The empty string, and a string with no brackets at all
  - Counts with more than one digit, like "12[a]"
  - Text after a closing bracket, like "2[a2[b]c]d", which belongs to the enclosing level
  - Several groups side by side, like "2[x]3[yz]"
  - Deep nesting, like "2[2[2[2[z]]]]"
askInterviewer:
  - Is the input always well formed, with balanced brackets and a count before every "["?
  - Can a count be 0, or have leading zeros?
  - Which characters can appear outside the counts and brackets?
  - How long can the decoded output get?
hints:
  - Without nesting, a single left-to-right pass is enough. What do you have to remember when a "[" opens inside another group?
  - When you meet "]", you need two things that were known when the matching "[" opened. Which ones?
  - "Push the text built so far and the pending count when you see \"[\", start fresh, and on \"]\" pop them and glue: prefix + piece repeated count times."
followUps:
  - How would you write it recursively? (A function that decodes until it hits "]" and returns where it stopped.)
  - The output can be huge compared with the input. How would you return the character at position i without building the whole string?
  - How would you validate malformed input instead of assuming it's correct?
rubric:
  - I explained why nested groups need a stack and not a single saved prefix.
  - I parsed counts with more than one digit.
  - On "]", I combined the saved prefix with the repeated piece, in that order.
  - I gave the cost in terms of the output length, not the input length.
codeStatus: tested
---

A sticker keyboard stores long repeated text in a compressed form: `k[text]` means `text` repeated `k` times, and groups can nest. Write `decodeString(_:)` that returns the expanded text.

```swift
decodeString("3[ha]")       // "hahaha"
decodeString("2[a3[b]]")    // "abbbabbb"
decodeString("ab2[go]")     // "abgogo"
decodeString("2[x]3[yz]")   // "xxyzyzyz"
```

**Constraints:** the input is well formed. Plain characters are lowercase English letters. Every `[` is immediately preceded by a count between 1 and 300 written in decimal, and brackets are balanced. Digits appear only in counts. `0 ≤ encoded.count ≤ 30`, and the decoded result has at most 10^5 characters.

<!-- reveal -->

## First approach

Read left to right, building the current piece of text. A count followed by `[` starts a group, and its `]` ends it, at which point the group's text is repeated and attached to whatever came before the `[`. Groups nest, so when a `]` arrives you need the state from the **most recent** `[` that's still open. That's a stack, the same signal as matching tags in lesson m17-l01.

## Naive solution

Repeatedly find an innermost group (the last `[` before the first `]`), expand it in place and start over:

```swift
func decodeString(_ encoded: String) -> String {
    var characters = Array(encoded)
    while let close = characters.firstIndex(of: "]") {
        guard let open = characters[..<close].lastIndex(of: "[") else { break }
        var digitsStart = open
        while digitsStart > 0, characters[digitsStart - 1].isASCII, characters[digitsStart - 1].isNumber {
            digitsStart -= 1
        }
        let repeats = Int(String(characters[digitsStart..<open])) ?? 1
        let inner = characters[(open + 1)..<close]
        var expanded: [Character] = []
        for _ in 0..<repeats {
            expanded.append(contentsOf: inner)
        }
        characters.replaceSubrange(digitsStart...close, with: expanded)
    }
    return String(characters)
}
```

## Problems with the naive solution

Each expansion rescans from the start and rebuilds the array with `replaceSubrange`, which moves everything after the group. With g groups and intermediate strings up to length L, that's **O(g · L)**. It's correct, which makes it a good reference for tests, but the repeated scanning is wasted: one pass with a stack sees every bracket exactly once.

## Optimized solution

Walk the string once with three pieces of state: `current`, the text being built at the current nesting level; `count`, the number being read; and a stack of `(prefix, repeats)` pairs. A digit extends `count`. A `[` pushes the current text and the count, then resets both, because the group starts from nothing. A `]` pops the pair and replaces `current` with `prefix` followed by `current` repeated `repeats` times. Any other character is appended to `current`.

## Line by line

- `var saved: [(prefix: String, repeats: Int)] = []`: the stack. Each entry is the text that came before a `[` at the enclosing level, and how many times the group opened by that `[` repeats.
- `if character.isASCII, let digit = character.wholeNumberValue`: a decimal digit. `wholeNumberValue` alone also accepts digits from other scripts, so `isASCII` limits it to `0` through `9`.
- `count = count * 10 + digit`: builds counts with several digits, like 12.
- `saved.append((prefix: current, repeats: count))`, then `current = ""` and `count = 0`: entering a group. The text before it is parked, and the group starts empty.
- `guard let group = saved.popLast() else { continue }`: leaving a group. With valid input the stack is never empty here; the `guard` keeps a stray `]` from crashing.
- `current = group.prefix + String(repeating: current, count: group.repeats)`: the finished group is repeated and attached after the parked text, which becomes the current text of the enclosing level again. That's why `"2[a2[b]c]d"` gets its `c` inside the outer group and its `d` outside it.
- `current.append(character)`: a plain letter.
- `return current`: after the last character, the stack is empty and `current` is the whole result.

Every `]` copies its group into the level above, so a character nested d levels deep is copied up to d times: **O(m · d)** time for an output of length m. The stack holds at most d entries whose prefixes add up to at most m characters: **O(m + d)** space.

## Common mistakes

- Reading only one digit, so `12[a]` becomes `1` and `2[a]`.
- Forgetting to reset `count` after pushing, so the next group's count starts at the old value times 10.
- Concatenating in the wrong order (`repeated + prefix`), which moves the group in front of the text that came before it.
- Saving only the count on the stack and not the prefix, which loses the text outside the group.
- Building the result with `insert(contentsOf:at: 0)` or other front insertions, which turns a linear pass into a quadratic one.

## Variation

**Basic Calculator** (`"2 * (3 + 4) - 5"`): the same stack of "state before the parenthesis opened", except the state is a running total and a pending sign instead of a prefix and a count. On `)`, the value inside the parentheses is combined with the saved total.
