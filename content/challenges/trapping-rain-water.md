---
id: trapping-rain-water
title: Trapping Rain Water
difficulty: hard
order: 15
patterns: [Two pointers, Prefix maximum]
prerequisites: [m07, m15, m16-l03, m16-l06]
summary: How much rain stays on a skyline of columns? From an O(n²) definition to two precomputed arrays, then to two pointers and no extra memory.
solutionFile: TrappingRainWater.swift
testFile: TrappingRainWaterTests.swift
starter: |
  func trappedWater(_ heights: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1)
edgeCases:
  - Fewer than three columns, which can't trap anything
  - Strictly increasing, decreasing or peaked heights (no water)
  - Flat ground
  - A wide valley between two equal walls
askInterviewer:
  - Are the columns all width 1, with no gaps between them?
  - Can a height be 0?
  - Does water spill off both ends?
  - How many columns can there be, and how tall?
hints:
  - "Look at a single column. How high can water stand above it? It depends on the tallest column to its left and the tallest to its right."
  - "Water above column i = min(tallest on the left, tallest on the right) − heights[i], counting column i itself on both sides. Can you compute both maxima for every column in two passes?"
  - "To drop the two arrays: walk two pointers inward, each with the tallest column seen on its side. Whichever side has the lower maximum can be settled now. Why?"
followUps:
  - Prove that the side with the lower running maximum can be settled without knowing the rest.
  - "How does a monotonic stack (Module 17) solve the same problem, filling water layer by layer?"
  - What changes in two dimensions, with a grid of heights? (A heap-based flood fill.)
rubric:
  - I stated the per-column formula before writing code.
  - I went from O(n²) to O(n) with prefix and suffix maxima, and said what it costs in memory.
  - I got to the two-pointer version and explained why the lower side is safe to settle.
  - I tested on a valley, a peak and arrays with fewer than three columns.
codeStatus: tested
---

A weather app draws a skyline as columns of width 1 standing side by side. After a storm, water collects in the dips between taller columns and spills off both ends. Given the heights from left to right, return how many units of water stay trapped.

Write `trappedWater(_ heights: [Int]) -> Int`.

```swift
trappedWater([3, 0, 2, 0, 4])              // 7: 3 + 1 + 3 above the three middle columns
trappedWater([1, 0, 2, 1, 0, 1, 3, 1, 2])  // 6
trappedWater([1, 2, 3])                    // 0: nothing holds water in
```

**Constraints:** `0 ≤ heights.count ≤ 2·10^4`; `0 ≤ heights[i] ≤ 10^5`.

<!-- reveal -->

## First approach

Think about one column at a time. Water above it rises until it would spill over the lower of two walls: the tallest column on its left and the tallest on its right. So the water above column `i` is `min(tallestLeft, tallestRight) − heights[i]`, where both maxima include column `i` itself, which makes the result never negative. The total is the sum over all columns. The rest of the problem is computing those two maxima cheaply.

## Naive solution

Apply the formula directly, scanning both sides for every column:

```swift
func trappedWater(_ heights: [Int]) -> Int {
    var water = 0
    for index in heights.indices {
        let tallestLeft = heights[...index].max() ?? 0
        let tallestRight = heights[index...].max() ?? 0
        water += min(tallestLeft, tallestRight) - heights[index]
    }
    return water
}
```

## Problems with the naive solution

Each column scans the whole array: **O(n²)**, 4·10^8 steps for 2·10^4 columns. The scans repeat almost the same work for neighboring columns: the tallest column to the left of `i + 1` is just the tallest to the left of `i`, compared with one more value. That's a running maximum, and you can precompute it for every position in one pass from each side (the reference file includes this version as `trappedWaterWithPrefixMaxima`). That's O(n) time with O(n) extra memory.

## Optimized solution

Avoid the arrays with two pointers walking inward. `leftMax` is the tallest column in `heights[0...left]` and `rightMax` the tallest in `heights[right...]`, as far as each pointer has gone. If `leftMax <= rightMax`, column `left` can be settled now: its left wall is exactly `leftMax`, and its right wall is at least `rightMax`, which is already at least `leftMax`. So its water level is `leftMax`, whatever the unexplored middle holds. Otherwise the same reasoning settles column `right`.

## Line by line

- `left`, `right`: the next unsettled column on each side. `while left <= right` settles every column exactly once, including the last one where they meet.
- `if leftMax <= rightMax`: the left side has the lower wall, so its level is decided.
- `leftMax = max(leftMax, heights[left])` comes **before** adding water, so the column counts as its own wall. If it's the tallest so far, `leftMax − heights[left]` is 0 and no water is added; there's no separate "is this a wall?" branch.
- `water += leftMax - heights[left]`: the level minus the column's height.
- The `else` branch is the mirror image for the right side.
- For an empty array, `right` is −1 and the loop doesn't run. With one or two columns the loop runs but adds 0, as it should: no column has walls on both sides.
- **O(n) time, O(1) space.** The largest possible total is about 2·10^4 × 10^5 = 2·10^9, which fits in a 64-bit `Int`.

## Common mistakes

- Using the maxima **excluding** the column itself and getting negative water for columns taller than both sides. Either include the column or clamp with `max(0, …)`.
- Settling the side with the **higher** maximum. Its level depends on the other side's true maximum, which isn't known yet.
- Treating water as only forming between two adjacent taller columns. Water spans across columns, as in `[3, 0, 2, 0, 4]`.

## Variation

**Monotonic stack:** keep a stack of indexes with decreasing heights. When a taller column arrives, pop the bottom of a dip and add the layer of water between the new column and the one now on top of the stack: width × (min of the two walls − the popped height). It's also O(n), with O(n) space for the stack, and it computes water in horizontal layers instead of vertical columns.
