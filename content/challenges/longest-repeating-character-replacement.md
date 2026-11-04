---
id: longest-repeating-character-replacement
title: Longest Repeating Character Replacement
difficulty: medium
order: 18
patterns: [Sliding window, Frequency counter]
prerequisites: [m07, m15, m16-l04, m16-l05]
summary: Repaint at most k tiles to get the longest run of one color. The window is valid when everything except its most common letter fits in k.
solutionFile: LongestRepeatingCharacterReplacement.swift
testFile: LongestRepeatingCharacterReplacementTests.swift
starter: |
  func longestUniformRun(_ tiles: String, repaints k: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n) (O(26 · n) with a fixed alphabet)
space: O(n) for the byte array, O(1) for the counters
edgeCases:
  - Empty string
  - More repaints than tiles
  - A row that's already one color
  - The best run at the very end
  - k = 0, where the answer is the longest existing run
askInterviewer:
  - Are the letters only A to Z?
  - Can k be 0, or larger than the row?
  - Do I return the length or the stretch itself?
  - Does the repainted color have to be one that's already in the stretch? (It never helps to pick another one.)
hints:
  - "For a fixed stretch, which color would you repaint everything to, and how many repaints does that take?"
  - "A stretch needs (its length − the count of its most common letter) repaints. When is that at most k?"
  - "Slide a window with 26 counters. Shrink from the left while it needs more than k repaints."
followUps:
  - "The classic trick keeps the largest count ever seen instead of recomputing it. Why does the stale value still give the right answer?"
  - What if the alphabet were all of Unicode?
  - How would you return the stretch and the color?
rubric:
  - I reduced a stretch's cost to length minus the most common count.
  - I used a variable sliding window with counters, shrinking while invalid.
  - I explained the cost of finding the most common count (26 counters) and why it's still O(n).
  - I tested k = 0 and k larger than the string.
codeStatus: tested
---

A puzzle shows a row of tiles, each painted one of 26 colors written as the letters `A` to `Z`. You may repaint **at most `k`** tiles, each to any color. Return the length of the longest stretch of consecutive tiles that can end up all the same color.

Write `longestUniformRun(_ tiles: String, repaints k: Int) -> Int`.

```swift
longestUniformRun("RGRRBR", repaints: 1)  // 4: repaint the G in "RGRR" (or the B in "RRBR")
longestUniformRun("RGRRBR", repaints: 2)  // 6: repaint G and B
longestUniformRun("RGBY", repaints: 0)    // 1
```

**Constraints:** `0 ≤ tiles.count ≤ 10^5`; only the letters `A` to `Z`; `0 ≤ k ≤ tiles.count`.

<!-- reveal -->

## First approach

For one stretch, the cheapest plan is to keep its most common color and repaint everything else. So a stretch works when `length − mostCommonCount ≤ k`. Adding a tile to a stretch never makes it cheaper to fix, which is the property a sliding window needs: find, for each right end, the leftmost start that still works.

## Naive solution

From each start, extend to the right, tracking the counts and the most common one:

```swift
func longestUniformRun(_ tiles: String, repaints k: Int) -> Int {
    let letters = Array(tiles.utf8)
    var longest = 0
    for start in letters.indices {
        var counts = Array(repeating: 0, count: 26)
        var mostCommon = 0
        for end in start..<letters.count {
            let letter = Int(letters[end] - 65)
            counts[letter] += 1
            mostCommon = max(mostCommon, counts[letter])
            if (end - start + 1) - mostCommon <= k {
                longest = max(longest, end - start + 1)
            }
        }
    }
    return longest
}
```

## Problems with the naive solution

Every start scans to the end: **O(n²)**, 5·10^9 steps for 10^5 tiles. Neighboring starts share almost all their work, which is what a window reuses.

## Optimized solution

A window `left...right` with 26 counters. Each step adds `letters[right]` to the counters. While the window needs more than `k` repaints (its length minus its largest counter), remove `letters[left]` and move `left`. Then the window is the longest valid one ending at `right`; record its length.

## Line by line

- `Array(tiles.utf8)`: every tile is an ASCII letter, so one byte each, and `letters[right] - 65` turns `A`...`Z` into 0...25 (65 is the code of `A`).
- `counts[Int(letters[right] - 65)] += 1`: the new tile joins the window.
- `(right - left + 1) - (counts.max() ?? 0) > k`: the repaints this window needs. `counts.max()` scans 26 counters, a constant, so each check is O(1) in n. It returns an optional because an array could be empty; this one never is, and `?? 0` satisfies the type.
- The `while` removes the leftmost tile and moves `left` until the window is valid again.
- `longest = max(longest, right - left + 1)`: recorded after shrinking, when the window is guaranteed valid.
- **O(26 · n) = O(n) time:** `left` moves at most n times in total, and each check costs 26. **O(1) space** for the counters, plus O(n) for the byte array.

## Common mistakes

- Computing repaints as "number of distinct colors − 1" or "count of the first tile's color". It's the length minus the **most common** count.
- Recording the length before shrinking, which can record an invalid window.
- Indexing the `String` directly with `Int`s, which doesn't compile; or using `index(_:offsetBy:)` inside the loop, which makes it O(n²).

## Variation

**The stale-maximum trick:** many solutions keep `maxCount`, the largest counter value ever seen, and never lower it when tiles leave, and they shrink with `if` instead of `while`, so the window slides without ever getting shorter. The window may then be invalid, but it only gets longer on a step where it's genuinely valid: either before it has ever slid, or when the incoming tile's counter sets a new `maxCount`, and that counter is a real count in the current window. So the final length is still the right answer, in O(n) without the 26-counter scan. It's correct but hard to explain under pressure; the version above is easier to defend.
