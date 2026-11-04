---
id: rotting-oranges
title: Rotting Oranges
difficulty: medium
order: 78
patterns: [Graph, Grid, Breadth-first search, Multi-source BFS]
prerequisites: [m17-l02, m19-l05]
summary: How long until rot spreads through a whole crate? Breadth-first search from every rotten fruit at once, where each BFS level is one minute.
solutionFile: RottingOranges.swift
testFile: RottingOrangesTests.swift
starter: |
  func minutesUntilAllRotten(_ grid: [[Int]]) -> Int? {
      // Your solution
      return nil
  }
time: O(r · c) for an r × c grid
space: O(r · c)
edgeCases:
  - No fresh fruit at the start (the answer is 0), including an empty grid
  - Fresh fruit but nothing rotten
  - Fresh fruit walled off by empty cells
  - Several rotten fruit spreading at the same time
askInterviewer:
  - Does rot spread diagonally?
  - What do I return when some fruit never rots?
  - Can I modify the grid I'm given?
  - Are all rows the same length?
hints:
  - The rot from one fruit spreads like the BFS distances in the Module 19 lesson on graphs. What changes when there are several starting points?
  - Put every rotten fruit in the first BFS level. Then each level of the BFS is one minute.
  - How do you know, at the end, whether any fruit was never reached? Count instead of rescanning.
followUps:
  - Return, for every cell, the minute it rots. (Store the BFS level per cell.)
  - "What if some fruit takes two minutes to rot once infected? (Weights: Dijkstra, or a 0-1 BFS variant.)"
  - "Walls and gates: fill each empty room with its distance to the nearest gate. Same multi-source BFS."
rubric:
  - I started the BFS from all rotten fruit at once instead of from each separately.
  - I processed the BFS level by level and counted levels as minutes.
  - I tracked the number of fresh fruit to detect unreachable ones and to stop early.
  - I gave O(r · c) time and space.
codeStatus: tested
---

A grocery delivery app models a crate of fruit as a grid. Each cell is `0` (empty), `1` (fresh fruit) or `2` (rotten fruit). Every minute, each rotten fruit spoils the fresh fruit directly above, below, left and right of it. Diagonals don't count, and rot can't cross an empty cell.

Write `minutesUntilAllRotten(_:)`, which returns the number of minutes until no fresh fruit is left, or `nil` if some fresh fruit will never rot.

```swift
minutesUntilAllRotten([
    [2, 1, 1],
    [1, 1, 0],
    [0, 1, 1],
])  // 4

minutesUntilAllRotten([
    [2, 1, 0],
    [0, 0, 1],
])  // nil: the bottom-right fruit is cut off

minutesUntilAllRotten([[0, 2, 0]])           // 0: nothing fresh to begin with
minutesUntilAllRotten([[2, 1, 1, 1, 1, 1, 2]])  // 3: rot comes from both ends
```

**Constraints:** `0 ≤ r, c ≤ 100`; every row has the same length.

<!-- reveal -->

## First approach

The minute a fruit rots is its distance, in steps through fruit cells, from the nearest rotten fruit. Distances in an unweighted grid are what breadth-first search computes. The difference from the graphs lesson is that there are several starting points, and a fruit should get its distance to the **nearest** one. Start the BFS with all of them in the first level, and every level after that is one minute.

## Naive solution

Simulate it as stated: every minute, scan the grid for fresh fruit next to rotten fruit, then spoil them all at once.

```swift
func minutesUntilAllRotten(_ grid: [[Int]]) -> Int? {
    var grid = grid
    var minutes = 0
    while true {
        var spoilsNow: [(row: Int, column: Int)] = []
        var freshLeft = false
        for row in grid.indices {
            for column in grid[row].indices where grid[row][column] == 1 {
                freshLeft = true
                let touchesRotten = [(row - 1, column), (row + 1, column), (row, column - 1), (row, column + 1)]
                    .contains { r, c in grid.indices.contains(r) && grid[r].indices.contains(c) && grid[r][c] == 2 }
                if touchesRotten { spoilsNow.append((row, column)) }
            }
        }
        if !freshLeft { return minutes }
        if spoilsNow.isEmpty { return nil }
        for cell in spoilsNow { grid[cell.row][cell.column] = 2 }
        minutes += 1
    }
}
```

Collecting first and spoiling after the scan matters: spoiling during the scan would let rot travel several cells in one minute.

## Problems with the naive solution

Each minute rescans all r · c cells, and a winding path of fruit can take about r · c minutes to rot completely. That's O((r · c)²): for a 100 × 100 crate, up to 10^8 cell checks. Most of each scan looks at cells that didn't change. Only the fruit that rotted in the last minute can spread rot in the next one.

## Optimized solution

Multi-source BFS. Scan once to collect every rotten fruit and count the fresh ones. Then process level by level: for each fruit that rotted last minute, spoil its fresh neighbors and add them to the next level. Each spoiled fruit decrements the fresh count. When the count hits 0, the number of levels processed is the answer; if the BFS runs out of fruit to spread from while the count is still positive, some fruit is unreachable.

## Line by line

- `var grid = grid`: a local copy, so the caller's array isn't modified. Arrays are value types; the copy is made when the first write happens.
- The first loop collects every `2` into `spoiling` and counts every `1`.
- `while freshCount > 0 && !spoiling.isEmpty`: stop when nothing fresh is left, or when nothing can spread any more. With no fresh fruit at the start, the loop never runs and the answer is 0.
- `for (rowStep, columnStep) in steps`: the four neighbors.
- `guard grid.indices.contains(row), grid[row].indices.contains(column), grid[row][column] == 1`: in bounds and fresh. Checking the bounds first keeps the subscript from trapping.
- `grid[row][column] = 2`: marking it here, when it's added to the next level, keeps it from being added twice by two different neighbors.
- `minutes += 1`: one level is one minute.
- `return freshCount == 0 ? minutes : nil`: any fresh fruit left was never reached.

## Common mistakes

- Running a separate BFS from each rotten fruit. It can be made correct by keeping, for each cell, the minimum over all searches, but with k rotten fruit it costs O(k · r · c), which is O((r · c)²) when most of the crate starts rotten.
- Counting minutes per fruit processed instead of per level.
- Incrementing the minute counter one extra time after the last level, which happens if the loop runs until the queue is empty rather than until the fresh count reaches 0.
- Marking a fruit as rotten when it's taken out of the level instead of when it's added, so it gets added twice.

## Variation

**Distance to the nearest exit:** given a maze with several exits, fill every open cell with its distance to the closest one. Same multi-source BFS, starting from all exits at once.
