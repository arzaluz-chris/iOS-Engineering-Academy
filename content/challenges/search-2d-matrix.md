---
id: search-2d-matrix
title: Search a Sorted Matrix
difficulty: medium
order: 45
patterns: [Binary search, Index mapping]
prerequisites: [m15-l03, m16-l02]
summary: Find a value in a grid that's sorted row by row. Treat the grid as one long sorted array without building it.
solutionFile: SearchSortedMatrix.swift
testFile: SearchSortedMatrixTests.swift
starter: |
  func searchSortedMatrix(_ matrix: [[Int]], _ target: Int) -> Bool {
      // Your solution
      return false
  }
time: O(log(m · n))
space: O(1)
edgeCases:
  - Empty matrix, or rows with no columns
  - A single cell
  - Target smaller than the first cell or larger than the last
  - A single row or a single column
askInterviewer:
  - Is the first value of each row greater than the last value of the previous row, or are rows and columns only sorted separately?
  - Do all rows have the same length?
  - Can values repeat?
  - Do I return a Bool, or the position?
hints:
  - If you wrote the rows one after another, what would the resulting list look like?
  - You don't need to build that list. Given a position i in it, which row and column does it come from?
  - With c columns, position i is at row i / c and column i % c.
followUps:
  - "What if each row and each column is sorted, but a row's first value can be smaller than the previous row's last? (Start at the top-right corner and step left or down: O(m + n).)"
  - How would you return the position instead of a Bool?
  - Two binary searches (first the row, then the column) also work. Is that faster or slower than one search over m · n?
rubric:
  - I asked how the rows relate to each other before choosing an approach.
  - I mapped a flat index to a row and column with / and %.
  - I handled the empty matrix and empty rows without crashing.
  - I stated O(log(m · n)) time and O(1) space.
codeStatus: tested
---

A warehouse app stores bin numbers in a grid: each row is a shelf, sorted left to right, and every shelf starts with a larger number than the one before it ended. Write `searchSortedMatrix(_:_:)` that returns whether `target` is somewhere in the grid.

```swift
let shelves = [
    [2, 5, 9, 12],
    [15, 18, 21, 30],
    [34, 40, 47, 51],
]
searchSortedMatrix(shelves, 21)  // true
searchSortedMatrix(shelves, 13)  // false, it would fall between 12 and 15
searchSortedMatrix(shelves, 51)  // true
```

**Constraints:** `0 ≤ m, n ≤ 100`, where m is the number of rows and n the number of columns; all rows have the same length; values are distinct and fit in `Int`.

<!-- reveal -->

## First approach

Read the shelves left to right, top to bottom, and you get one sorted list: 2, 5, 9, 12, 15, 18 and so on. Any search that works on a sorted array works here, as long as you can turn a position in that imaginary list into a cell of the grid.

## Naive solution

Look at every cell:

```swift
func searchSortedMatrix(_ matrix: [[Int]], _ target: Int) -> Bool {
    for row in matrix {
        for value in row where value == target {
            return true
        }
    }
    return false
}
```

## Problems with the naive solution

It's **O(m · n)** and ignores the ordering completely. With 100 × 100 cells that's up to 10,000 comparisons for something binary search answers in 14. Flattening the grid into an array first and then searching it is no better: building the array alone is O(m · n) time and memory.

## Optimized solution

Run the lesson's lower-bound search over positions `0..<m · n`. To read position `i`, look at `matrix[i / columns][i % columns]`. When the search ends, check whether the cell at the boundary holds the target.

## Line by line

- `guard let columns = matrix.first?.count, columns > 0 else { return false }`: an empty matrix and a matrix of empty rows both have nothing to find. This also guarantees we never divide by zero.
- `var low = 0` and `var high = matrix.count * columns`: the half-open range of flat positions.
- `matrix[mid / columns][mid % columns]`: integer division gives how many full rows come before position `mid`; the remainder is how far into that row it is. With 4 columns, position 6 is row 1, column 2: the 21.
- `if ... < target { low = mid + 1 } else { high = mid }`: lower bound. Everything before `low` is smaller than the target; everything from `high` on is at least the target.
- `return low < matrix.count * columns && matrix[low / columns][low % columns] == target`: `low` is where the target would be. It's found only if that position exists (it might be one past the end) and holds exactly the target.

## Common mistakes

- Using `i / rows` and `i % rows`. The row length is the number of **columns**; mixing them up only works for square grids, which is why tests with a single row or column catch it.
- Reading `matrix[low / columns]` after the loop without checking `low` against the total count first.
- Assuming the grid is the other kind of sorted (rows and columns sorted independently) without asking. The flat-index trick is wrong for that grid.

## Variation

**Search a 2D Matrix II:** rows sorted left to right and columns sorted top to bottom, but nothing links the end of one row to the start of the next. Start at the top-right cell. If it's bigger than the target, the whole column below is too, so move left; if it's smaller, the whole row to the left is too, so move down. Each step discards a row or a column: O(m + n).
