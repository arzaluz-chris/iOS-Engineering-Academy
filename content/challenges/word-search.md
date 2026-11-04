---
id: word-search
title: Word Search
difficulty: medium
order: 55
patterns: [Backtracking, Grid DFS]
prerequisites: [m18-l02, m18-l03]
summary: Decide whether a word can be traced through a letter grid without reusing a cell. Depth-first backtracking that marks a cell on the way in and restores it on the way out.
solutionFile: WordSearchGrid.swift
testFile: WordSearchGridTests.swift
starter: |
  func gridContainsWord(_ grid: [[Character]], _ word: String) -> Bool {
      // Your solution
      return false
  }
time: O(m · n · 3^L) for an m × n grid and a word of length L
space: O(L) for the recursion, plus O(m · n) for the working copy of the grid
edgeCases:
  - A path that would need to reuse a cell
  - Letters that touch only diagonally
  - A one-cell grid, and one-letter words
  - A word longer than the number of cells
askInterviewer:
  - Which moves are allowed? Only up, down, left and right, or diagonals too?
  - Can a cell be used more than once in the same word?
  - Is the comparison case-sensitive?
  - Will I search for many words on the same grid? (That changes the approach.)
hints:
  - Every cell that holds the first letter is a possible start. From there, each step has up to four choices.
  - You need to know which cells the current path already uses. What's the cheapest way to mark a cell and unmark it later?
  - Before searching, can you rule out some words without exploring at all?
followUps:
  - How would you find all the words of a dictionary in the same grid? (A trie built from the words, Module 19.)
  - Which end of the word should you start from, and why can that matter?
  - Write it with an explicit stack instead of recursion. What has to go on the stack to support undoing?
rubric:
  - I tried every cell as a start and explored the four neighbors recursively.
  - I marked the current cell as used and restored it before returning.
  - I checked bounds and the letter before recursing, and stopped as soon as the word was found.
  - I gave the O(m · n · 3^L) bound and explained the 3.
codeStatus: tested
---

A puzzle app shows a grid of letters. A word counts as found if you can trace it by moving one cell at a time up, down, left or right, without stepping on the same cell twice in that word. Write `gridContainsWord(_:_:)` that returns whether `word` can be traced in `grid`.

```swift
let board: [[Character]] = [
    ["C", "A", "T", "S"],
    ["O", "R", "E", "N"],
    ["D", "E", "A", "R"],
]
gridContainsWord(board, "CARE")   // true: C(0,0) A(0,1) R(1,1) E(1,2)
gridContainsWord(board, "TEAR")   // true: T(0,2) E(1,2) A(2,2) R(2,3)
gridContainsWord(board, "CATCH")  // false: there's no H
gridContainsWord(board, "RACER")  // false
```

**Constraints:** `1 ≤ m, n ≤ 6`; `1 ≤ word.count ≤ 15`; the grid is rectangular; letters are compared exactly.

<!-- reveal -->

## First approach

It's backtracking on a grid. The state is the current cell and how much of the word is matched. The choices are the neighbors. The constraint is that a path can't revisit a cell, so the search needs to remember which cells the current path uses, and forget them as it backs out, because a cell that's wrong for one path may be right for another.

## Naive solution

The same search, with each path carrying its own copy of the visited cells:

```swift
func gridContainsWord(_ grid: [[Character]], _ word: String) -> Bool {
    let letters = Array(word)

    func search(_ row: Int, _ column: Int, _ index: Int, _ visited: Set<[Int]>) -> Bool {
        guard row >= 0, row < grid.count, column >= 0, column < grid[row].count,
              !visited.contains([row, column]), grid[row][column] == letters[index] else { return false }
        if index == letters.count - 1 {
            return true
        }
        let next = visited.union([[row, column]])
        return search(row + 1, column, index + 1, next)
            || search(row - 1, column, index + 1, next)
            || search(row, column + 1, index + 1, next)
            || search(row, column - 1, index + 1, next)
    }

    for row in grid.indices {
        for column in grid[row].indices where search(row, column, 0, []) {
            return true
        }
    }
    return false
}
```

## Problems with the naive solution

It's correct, and it explores the same tree as the optimized version. The cost is per step: `visited.union` copies a set of up to L positions at every node, and hashing an `[Int]` array is far slower than reading a cell. It also starts searching even when the grid plainly can't contain the word, like "CATCH" with no H.

## Optimized solution

Search on a mutable copy of the grid. When a cell matches, overwrite it with a character that can't match anything, explore the four neighbors, then write the letter back. That's the choose/unchoose pattern with O(1) marking. Before searching, compare letter counts: if the word needs more of some letter than the grid has, return `false` without exploring.

## Line by line

- `guard rows > 0, columns > 0, letters.count <= rows * columns`: a path can't be longer than the number of cells.
- The `available` dictionary and the loop over the word's counts: if any letter is short, no path exists. It's O(m · n + L), much cheaper than a failed search.
- `var board = grid`: a working copy, since the input is a `let` and the caller's grid must not change.
- `let used: Character = "\0"`: the null character never appears in a word, so a marked cell can never match.
- `guard row >= 0, row < rows, column >= 0, column < columns, board[row][column] == letters[index]`: out of bounds, already used (it holds `used`), or the wrong letter all fail here.
- `if index == letters.count - 1 { return true }`: the last letter matched.
- `board[row][column] = used`: choose.
- `let found = match(...) || match(...) || ...`: `||` stops at the first neighbor that succeeds, so the search ends as soon as the word is found.
- `board[row][column] = letters[index]`: unchoose. If this path failed, sibling branches and later start cells may need this cell, so it has to hold its letter again. (If the path succeeded, the restore is harmless: the search is over.)
- The outer loops try each cell as the start.

The bound: m · n starts; the first step has up to 4 neighbors, and every later step has at most 3, because the cell you came from is marked. So at most m · n · 4 · 3^(L−1) calls.

## Common mistakes

- Forgetting to unmark, so a cell used by a dead-end path stays blocked for every other path.
- Marking with a shared `visited` array but unmarking only on failure, then reusing the array for the next start cell.
- Checking bounds after indexing, which crashes on the edges.
- Treating diagonal neighbors as adjacent when the problem says they aren't.

## Variation

**Word Search II:** find every word from a list in the same grid. Running this search once per word repeats the same paths many times. Build a trie of the words and walk it alongside the grid: one search from each cell follows every word that shares the current prefix at once, and a branch stops as soon as no word continues it.
