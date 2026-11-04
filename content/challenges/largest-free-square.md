---
id: largest-free-square
title: Largest Free Square
difficulty: medium
order: 87
patterns: [2-D dynamic programming, Grid]
prerequisites: [m20-l05]
summary: Find the biggest square of empty cells on a home-screen grid. A 2-D table where each cell reads its three neighbors above and to the left.
solutionFile: LargestFreeSquare.swift
testFile: LargestFreeSquareTests.swift
starter: |
  func largestFreeSquare(_ rows: [String]) -> Int {
      // Your solution
      return 0
  }
time: O(rows × columns)
space: O(columns) extra
edgeCases:
  - An empty grid, or rows with no columns
  - A grid with no free cells
  - A single row or column (at most 1)
  - A fully free rectangle, limited by its shorter side
  - One taken cell in the middle of a free area
askInterviewer:
  - Do you want the side length or the area?
  - Do all rows have the same length?
  - Which characters can appear besides "." and "#"?
  - How large can the grid be?
hints:
  - Instead of asking about every square, ask about squares whose bottom-right corner is a given cell.
  - If the cell above, the one to the left and the one diagonally up-left are each the corner of a free square of side 2, how big a square can end at this cell?
  - Each row only reads the row above it. How much of the table do you need to keep?
followUps:
  - Return the position of the square, not just its size.
  - Count every free square of every size. (Hint, the same table sums to it.)
  - Find the largest free rectangle instead. (Histogram plus monotonic stack, row by row.)
rubric:
  - I defined side[r][c] as the largest free square with its bottom-right corner at (r, c).
  - I wrote the transition 1 + min(above, left, diagonal) and explained why the minimum.
  - I avoided special cases for the first row and column with padding.
  - I reduced the space to one previous row.
codeStatus: tested
---

A launcher app lays icons out on a grid. To place a square widget, it needs the largest square area with no icons in it. Each row of the grid is a string where `.` is a free cell and `#` is taken. Return the **side length** of the largest square made only of free cells, or 0 if there are none.

```swift
largestFreeSquare([
    "#...#",
    "#....",
    "#...#",
    "..##.",
])                                // 3: rows 0 to 2, columns 1 to 3

largestFreeSquare([".#", "#."])  // 1
largestFreeSquare(["###"])        // 0
```

**Constraints:** `0 ≤ rows.count ≤ 300`; every row has the same length, from 0 to 300; rows contain only `.` and `#`.

<!-- reveal -->

## First approach

A square is fixed by its bottom-right corner and its size. For the corner at `(r, c)`, a free square of side `k` needs free squares of side `k - 1` ending at the cell above, the cell to the left and the cell diagonally up-left. Those three overlap to cover the whole `k × k` square except the corner itself. So the largest square ending at `(r, c)` is one more than the smallest of the three. That's a 2-D table filled row by row, like the path grids in Module 20, lesson 5.

## Naive solution

From every cell, grow a square while every cell in it is free:

```swift
func largestFreeSquare(_ rows: [String]) -> Int {
    let grid = rows.map { Array($0) }
    guard let width = grid.first?.count else { return 0 }
    var best = 0
    for top in grid.indices {
        for left in 0..<width {
            var size = 1
            while top + size <= grid.count && left + size <= width {
                var allFree = true
                for r in top..<(top + size) {
                    for c in left..<(left + size) where grid[r][c] != "." {
                        allFree = false
                    }
                }
                guard allFree else { break }
                best = max(best, size)
                size += 1
            }
        }
    }
    return best
}
```

## Problems with the naive solution

For each of the `r · c` top-left cells it tries up to `k = min(r, c)` sizes, and checking a square of size `s` costs `s²`. That's O(r · c · k³) in the worst case. For a free 300 × 300 grid it works out to roughly 10^11 cell reads. It also rechecks the same cells for every size: growing from 5 to 6 re-reads all 25 cells it already knew were free.

## Optimized solution

Keep `side` values for the row above and compute the current row from left to right. A taken cell is 0. A free cell is `1 + min(above, left, diagonal)`. Pad each row with an extra column 0 that's always 0, so the first column needs no special case. Track the largest value seen.

## Line by line

- `let grid = rows.map { Array($0) }`: arrays of `Character` so cells can be read by index.
- `guard let width = grid.first?.count else { return 0 }`: an empty grid has no squares.
- `var above = Array(repeating: 0, count: width + 1)`: the previous row's values, shifted one column right. Before the first row, everything above is 0.
- `var current = Array(repeating: 0, count: width + 1)`: a new row; taken cells keep their 0, and so does the padding at index 0.
- `for column in 0..<width where row[column] == "."`: only free cells can end a square.
- `current[column + 1] = 1 + min(above[column + 1], above[column], current[column])`: the cell above, diagonally up-left and to the left, all shifted by the padding. Note `current[column]` is the value just computed on this row.
- `best = max(best, current[column + 1])`: the answer can end anywhere.
- `above = current`: this row becomes the previous one.

## Common mistakes

- Using `max` instead of `min`. The square is limited by the smallest of the three neighbors, because each one is missing a different part.
- Returning the value at the bottom-right cell instead of the maximum over all cells.
- Overwriting a one-row table in place without saving the diagonal value first. The padded two-row version above avoids the problem.
- Returning the area when the side was asked for, or the other way around.

## Variation

**Count all free squares:** a cell with `side = 3` is the bottom-right corner of exactly three free squares (sides 1, 2 and 3). Sum the table instead of taking its maximum. Same O(r · c) time.
