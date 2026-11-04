---
id: sort-k-colors
title: Sort K Colors
difficulty: medium
order: 59
patterns: [Partition, Divide and conquer]
prerequisites: [m18-l04, m18-l06]
summary: Sort a list whose values are k colors, in place, faster than a general sort. Partition on the middle color, then recurse on each half of the colors.
solutionFile: SortKColors.swift
testFile: SortKColorsTests.swift
starter: |
  func sortKColors(_ colors: inout [Int], colorCount: Int) {
      // Your solution
  }
time: O(n log k)
space: O(log k) for the recursion
edgeCases:
  - Empty and single-element lists
  - Only one color
  - Colors that never appear
  - k as large as n
askInterviewer:
  - Can I use extra memory proportional to k, like a counting array?
  - Are all values guaranteed to be in 1...k?
  - Does the sort need to be stable? (Values are plain colors, so stability doesn't matter.)
  - Is k small, like 3, or can it be close to n?
hints:
  - The quicksort lesson's three-way partition sorts 3 colors in one pass. What's the cost of doing one such pass per color?
  - Instead of splitting the positions in half, split the colors. One partition pass puts every color <= middle before every color > middle.
  - After that pass, each side only holds half of the colors. How many levels until a side holds one color?
followUps:
  - When is counting sort better, and what does it cost in memory?
  - What's the lower bound for comparison sorting n items with only k distinct values? (About n log k comparisons.)
  - How would you make the recursion iterative?
rubric:
  - I recognized that the values come from a small range and used it.
  - I partitioned on a middle color and recursed on each half of the color range.
  - I stopped when a range had one color or fewer than two elements.
  - I gave O(n log k) time, O(log k) space, and compared with sort() and counting sort.
codeStatus: tested
---

A design tool groups layers by label color before exporting them. Colors are numbered 1 to `k`. Write `sortKColors(_:colorCount:)` that sorts `colors` in place in ascending order. Don't allocate another array or a table of counts: aim for O(log k) extra memory and better than O(n log n) time when k is much smaller than n.

```swift
var layers = [3, 1, 4, 2, 1, 4, 3]
sortKColors(&layers, colorCount: 4)  // layers is now [1, 1, 2, 3, 3, 4, 4]

var pair = [2, 1, 2, 1]
sortKColors(&pair, colorCount: 2)    // [1, 1, 2, 2]
```

**Constraints:** `0 ≤ colors.count ≤ 10^5`; `1 ≤ k ≤ 10^5`; every value is in `1...k`.

<!-- reveal -->

## First approach

`colors.sort()` works, in O(n log n), but it doesn't use the fact that there are only k distinct values. The quicksort lesson showed that one three-way partition sorts three colors in a single pass. For k colors, partition on the **colors** instead of the positions: put every color up to the middle one on the left, the rest on the right, then sort each side with its half of the colors.

## Naive solution

One pass per color, each pulling that color forward to the end of the sorted prefix:

```swift
func sortKColors(_ colors: inout [Int], colorCount: Int) {
    var placed = 0
    for color in 1...colorCount {
        for index in placed..<colors.count where colors[index] == color {
            colors.swapAt(index, placed)
            placed += 1
        }
    }
}
```

## Problems with the naive solution

It's **O(n · k)**. For three colors that's fine and close to the Dutch national flag. For k = 1,000 colors and n = 10^5 layers it's 10^8 steps, slower than just calling `sort()`. It also scans colors that don't appear at all.

## Optimized solution

`sort(low, high, firstColor, lastColor)` sorts the slice `low..<high`, which only holds colors in `firstColor...lastColor`. If the slice has fewer than two elements or a single color, it's already sorted. Otherwise, pick `middle` halfway between the colors, partition the slice with two pointers so colors `<= middle` come first, and recurse on each part with its half of the colors. Each level of recursion touches every element once, and there are about log₂ k levels.

## Line by line

- `if high - low < 2 || firstColor >= lastColor { return }`: a slice of 0 or 1 elements, or one with only one possible color, is sorted.
- `let middle = firstColor + (lastColor - firstColor) / 2`: the color that splits the range in half.
- `var left = low` and `var right = high - 1`: everything before `left` is `<= middle`; everything after `right` is `> middle`; `left...right` hasn't been looked at.
- `if colors[left] <= middle { left += 1 }`: already on the correct side.
- `else { colors.swapAt(left, right); right -= 1 }`: send it to the right side. `left` stays put because the element swapped in hasn't been examined, the same reason as in the lesson's three-way partition.
- When the loop ends, `left == right + 1`, and `left` is where the right part starts.
- `sort(low, left, firstColor, middle)` and `sort(left, high, middle + 1, lastColor)`: each side gets its half of the colors. Even if one side is empty, its call returns immediately.
- `sort(0, colors.count, 1, colorCount)`: the whole list, all colors.

## Common mistakes

- Splitting on positions and calling it done: that's quicksort, O(n log n), with no gain from the small range of values.
- Recursing with `middle` on both sides instead of `middle` and `middle + 1`. When the right side's colors are all `middle + 1`, the range never shrinks.
- Using a counting array after being asked not to allocate. It's the best answer when memory is allowed, O(n + k), so say so, but follow the constraint.

## Variation

**Sort Colors** (k = 3, the Dutch national flag): one three-way partition pass around color 2 is enough, as in the quicksort lesson. **Wiggle Sort:** rearrange so that `a[0] <= a[1] >= a[2] <= a[3]...`; a single pass that swaps neighbors that break the pattern does it in O(n).
