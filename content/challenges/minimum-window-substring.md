---
id: minimum-window-substring
title: Minimum Window Substring
difficulty: hard
order: 20
patterns: [Sliding window, Frequency counter]
prerequisites: [m07, m15, m16-l04, m16-l05]
summary: The shortest stretch of a text that contains every required character, repeats included. A variable window that grows until it covers, then shrinks while it still does.
solutionFile: MinimumWindowSubstring.swift
testFile: MinimumWindowSubstringTests.swift
starter: |
  func smallestCoveringWindow(_ text: String, covering required: String) -> String {
      // Your solution
      return ""
  }
time: O(n + m) on average
space: O(n + m)
edgeCases:
  - No window qualifies
  - Required characters that repeat, like "aa"
  - An empty text or an empty required string
  - Two equally short windows, where the leftmost wins
  - The whole text is the only window
askInterviewer:
  - Do repeated required characters need repeated copies in the window?
  - Is the match case-sensitive? Which characters can appear?
  - If several windows tie, which one do I return?
  - What do I return when there's no window, or when nothing is required?
hints:
  - "Grow a window from the left edge of the text until it contains everything. Now, how much can you drop from its left side and still be valid?"
  - "Keep a dictionary of how many copies of each character the window still owes, and a single number for how many required characters are missing in total. When does that number change?"
  - "Record the window inside the shrinking loop, before each shrink: every window you see there is valid."
followUps:
  - How do you know the window never needs to move its left edge backward?
  - "What if you only need each distinct character once, ignoring repeats?"
  - How would you return the start and length instead of building a String?
rubric:
  - I clarified repeats, case and the tie rule.
  - I tracked coverage with a counter dictionary plus a single missing count, not by rescanning.
  - I recorded the best window while shrinking, when it's valid.
  - I stated O(n + m) time on average and explained the amortized argument.
codeStatus: tested
---

A search feature highlights the shortest part of a document that contains every character the user typed. Given a `text` and a string `required`, return the shortest stretch of consecutive characters of `text` that contains every character of `required`, **including repeats**: if `required` has two `a`, the stretch needs at least two `a`. If several stretches are equally short, return the leftmost. If none qualifies, or `required` is empty, return `""`.

Write `smallestCoveringWindow(_ text: String, covering required: String) -> String`.

```swift
smallestCoveringWindow("XAYBZCABX", covering: "ABC")  // "CAB"
smallestCoveringWindow("banana", covering: "aan")     // "ana"
smallestCoveringWindow("ab", covering: "aa")          // "": only one a
```

**Constraints:** `0 ≤ text.count, required.count ≤ 10^5`. Any `Character` can appear, and case matters.

<!-- reveal -->

## First approach

This is the "shortest valid window" shape: grow the window on the right until it's valid, then shrink it from the left while it stays valid, recording as you go. Validity here is "covers every required character with enough copies". Checking that from scratch would be slow, so keep a running record of what the window still owes.

## Naive solution

From each start, extend until the window covers everything, and keep the shortest:

```swift
func smallestCoveringWindow(_ text: String, covering required: String) -> String {
    guard !required.isEmpty else { return "" }
    let characters = Array(text)
    var needed: [Character: Int] = [:]
    for character in required {
        needed[character, default: 0] += 1
    }
    var best: ArraySlice<Character>?
    for start in characters.indices {
        var owed = needed
        var missing = required.count
        for end in start..<characters.count {
            if owed[characters[end], default: 0] > 0 {
                missing -= 1
            }
            owed[characters[end], default: 0] -= 1
            if missing == 0 {
                if end - start + 1 < (best?.count ?? Int.max) {
                    best = characters[start...end]
                }
                break
            }
        }
    }
    return best.map { String($0) } ?? ""
}
```

## Problems with the naive solution

Each start can scan to the end of the text, so it's **O(n²)** (plus copying the dictionary for each start): 10^10 steps for 10^5 characters. When the window starting at `start` is found, the one starting at `start + 1` usually ends at or after the same place, and the naive version rediscovers that from scratch.

## Optimized solution

`owed[c]` is how many more copies of `c` the window needs; it goes negative when the window has extras. `missing` is the sum of the positive parts: how many required characters the window still lacks. Add characters on the right; when `missing` reaches 0, the window covers everything. Then, while it still does, record it if it's the shortest so far, and remove the leftmost character. The `while` ends at the first removal that breaks coverage.

## Line by line

- `guard !required.isEmpty`: the statement defines this case as `""`. Without the guard, `missing` would start at 0 and never rise, so the `while` loop would keep moving `left` past `right` until it read past the end of the array.
- `owed[character, default: 0] += 1` for each required character: the initial debt, repeats included.
- `missing = required.count`: total copies needed, counting repeats.
- `if owed[incoming, default: 0] > 0 { missing -= 1 }`: the incoming character pays a real debt only if the window still owed some. Extra copies, and characters nobody asked for, don't change `missing`.
- `owed[incoming, default: 0] -= 1` happens either way, so extras show up as negative values. That's what lets the window drop them later without becoming invalid.
- `while missing == 0`: every window this loop sees is valid. `right - left + 1 < bestLength` keeps the first of equally short windows, which is the leftmost, because windows are found in order of their right end.
- `owed[outgoing, default: 0] += 1`, then `if ... > 0 { missing += 1 }`: if removing the character creates a real debt, the window stops being valid and the `while` ends.
- `String(characters[bestStart..<(bestStart + bestLength)])`: the answer is built once, at the end, not on every improvement.
- **O(n + m) time on average:** `right` and `left` each move at most n times, and every step is O(1) dictionary work. **O(n + m) space** for the character array and the dictionary.

## Common mistakes

- Using a `Set` of required characters, which ignores repeats: "aa" would be covered by a single "a".
- Decrementing `missing` for every matching character, including extras, so `missing` reaches 0 too early.
- Recording the window after the `while` loop. By then the window has just become invalid.
- Building a new `String` every time the best window improves, which costs O(n) each time.

## Variation

**Distinct characters only:** if each required character only needs to appear once, start `owed` at 1 for each distinct character and `missing` at the number of distinct characters. The loop doesn't change, which shows how much of the logic lives in those two initial values.
