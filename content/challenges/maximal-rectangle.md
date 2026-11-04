---
id: maximal-rectangle
title: Maximal Rectangle
difficulty: hard
order: 30
patterns: [Monotonic stack, Reduction to a solved problem]
prerequisites: [m17-l05, m16-l06]
summary: Find the largest rectangular block of free seats in a seat map. Each row turns into a histogram, and histograms are a monotonic-stack problem you already know.
solutionFile: MaximalRectangle.swift
testFile: MaximalRectangleTests.swift
starter: |
  func maximalRectangle(_ grid: [[Int]]) -> Int {
      // Your solution
      return 0
  }
time: O(rows · columns)
space: O(columns)
edgeCases:
  - An empty grid, and a grid whose rows are empty
  - A grid with no 1s
  - A grid that's all 1s
  - A single row or a single column
  - A tall, thin block that beats a wide, short one
askInterviewer:
  - Are all rows the same length?
  - Is the grid given as numbers, characters or booleans?
  - Do you need the area only, or the rectangle's position too?
  - How big can the grid be?
hints:
  - Fix the bottom row of the rectangle. For each column, how many free seats are stacked directly above that row, including it?
  - Those counts form a bar chart. What's the largest rectangle in a bar chart?
  - "Going from one row to the next, each column's count either grows by 1 or drops to 0. Lesson m17-l05 solves the bar chart in O(columns)."
followUps:
  - How would you return the rectangle's corners as well as its area?
  - What if you wanted the largest square instead? (A simpler dynamic programming recurrence.)
  - What if rows arrive one at a time from a server and you can't keep the whole map in memory? (The heights array is all you carry between rows.)
rubric:
  - I reduced the problem to "largest rectangle in a histogram" for each row.
  - I updated the heights in O(1) per cell, resetting to 0 on a taken seat.
  - I used a monotonic stack for each histogram, so each row is O(columns).
  - I tested against a brute force on small random grids.
codeStatus: tested
---

A ticketing app shows a theater's seat map as a grid: `1` is a free seat, `0` a taken one. A group wants to sit together in a rectangular block of free seats. Write `maximalRectangle(_:)` that returns the area of the largest block made only of `1`s.

```swift
let seats = [
    [1, 0, 1, 1, 0],
    [1, 1, 1, 1, 0],
    [0, 1, 1, 1, 1],
    [1, 1, 0, 1, 1],
]
maximalRectangle(seats)              // 6: rows 1–2, columns 1–3
maximalRectangle([[0, 0], [0, 0]])   // 0
maximalRectangle([[1, 1, 1]])        // 3
```

**Constraints:** `0 ≤ rows, columns ≤ 200`; all rows have the same length; every cell is 0 or 1.

<!-- reveal -->

## First approach

A rectangle has a bottom row. Fix that row and look up: in each column, the free seats stacked contiguously on top of it, counting the row itself, form a bar. A rectangle whose bottom edge is on this row is a rectangle under that bar chart. So the answer is the best "largest rectangle in a histogram" over all rows, and lesson m17-l05 solves the histogram in linear time with a monotonic stack. Building each row's bars from the previous row's is O(1) per cell.

## Naive solution

Try every rectangle and check whether it's all 1s. A two-dimensional version of the prefix sums from lesson m16-l06 counts the 1s inside any rectangle in O(1), so the check is cheap; the number of rectangles is the problem:

```swift
func maximalRectangle(_ grid: [[Int]]) -> Int {
    let rows = grid.count
    guard let columns = grid.first?.count else { return 0 }
    var ones = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
    for r in 0..<rows {
        for c in 0..<columns {
            ones[r + 1][c + 1] = grid[r][c] + ones[r][c + 1] + ones[r + 1][c] - ones[r][c]
        }
    }
    var best = 0
    for top in 0..<rows {
        for bottom in top..<rows {
            for left in 0..<columns {
                for right in left..<columns {
                    let area = (bottom - top + 1) * (right - left + 1)
                    let count = ones[bottom + 1][right + 1] - ones[top][right + 1]
                        - ones[bottom + 1][left] + ones[top][left]
                    if count == area {
                        best = max(best, area)
                    }
                }
            }
        }
    }
    return best
}
```

`ones[r][c]` is the number of 1s in the first r rows and first c columns. A rectangle is all 1s exactly when its count of 1s equals its area.

## Problems with the naive solution

There are about rows² · columns² / 4 rectangles. For a 200 × 200 grid that's 4 · 10^8 checks: each one is cheap, but there are far too many. Without the prefix sum, each check would also scan the rectangle, which is worse still. The histogram view doesn't look at rectangles one at a time at all.

## Optimized solution

Keep an array `heights` with one entry per column. For each row, update it: a free seat extends the bar by one, a taken seat resets it to 0. Then find the largest rectangle under `heights` with an increasing monotonic stack, and keep the best over all rows.

The histogram helper is the algorithm from lesson m17-l05. When a bar is popped, the bar that pops it is its right limit and the new top of the stack is its left limit, so its widest rectangle is known right then. A sentinel height of 0 after the last column flushes the stack.

## Line by line

- `guard let columns = grid.first?.count else { return 0 }`: an empty grid has no rectangle. A grid of empty rows gives `columns == 0`, every histogram is empty, and the answer is 0.
- `var heights = Array(repeating: 0, count: columns)`: one bar per column, carried from row to row.
- `heights[column] = row[column] == 1 ? heights[column] + 1 : 0`: the run of free seats ending at this row. A taken seat breaks every rectangle that would pass through it, so the bar starts over.
- `best = max(best, maximalRectangleHistogramArea(heights))`: the largest rectangle whose bottom edge is on this row.
- In the helper, `for index in 0...heights.count` runs one step past the end, where `height` is the sentinel 0.
- `while let top = rising.last, heights[top] >= height`: the bar on top can't extend past `index`. Pop it.
- `let left = rising.last ?? -1`: the nearest earlier bar that's lower, or -1 if it extends to the first column.
- `best = max(best, heights[top] * (index - left - 1))`: every bar strictly between `left` and `index` is at least as tall as the popped one, so the rectangle spans all of them.
- `rising.append(index)`: the stack stays increasing from bottom to top.

Each row does O(columns) work to update the heights and O(columns) in the helper, since every column is pushed and popped once: **O(rows · columns) time**. `heights` and the stack are **O(columns) space**.

## Common mistakes

- Treating each row's histogram independently, so `heights` only counts the current row and only one-row rectangles are found.
- Forgetting to reset a bar to 0 on a taken seat, which lets a rectangle stretch through it.
- Dropping the sentinel and forgetting to empty the stack after the last column. A row that ends in increasing bars, like `[1, 2, 3]`, then never computes its biggest areas.
- Computing the width as `index - top` instead of `index - left - 1`. The popped bar may have extended left past its own index, over taller bars that were popped earlier.
- Starting from "largest square" logic. A square recurrence doesn't extend to rectangles.

## Variation

**Count all-ones submatrices**: instead of the largest rectangle, count how many rectangles contain only 1s. The same row-by-row histogram works; for each bar you count the rectangles ending at it, using a monotonic stack to carry the count from the nearest lower bar on the left.
