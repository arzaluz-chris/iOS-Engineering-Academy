---
id: m20-l05
title: 2-D dynamic programming
description: You fill tables with two indexes. Paths through a warehouse grid with blocked cells, the longest common subsequence of two strings and the edit distance behind "did you mean". You state what each cell means, fill the table in an order that respects its three neighbors, print it, and walk it backward to recover the actual subsequence or the list of edits.
module: m20
order: 5
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l04]
objectives:
  - Define a 2-D table entry precisely, including the empty-prefix row and column, and set its base cases.
  - Fill a 2-D table row by row when each cell depends on the cells above, to the left and diagonally above-left.
  - Count grid paths with blocked cells.
  - Compute the longest common subsequence and the edit distance of two strings, and reconstruct the subsequence and the edits by walking the table backward.
  - Reduce a 2-D table to two rows when only the previous row is read.
terms:
  - term: 2-D table
    definition: A table indexed by two values, usually a position in each of two inputs or a row and a column. Stored as an array of arrays.
  - term: Prefix state
    definition: A state that means "the first i elements of one input and the first j of the other". Row 0 and column 0 stand for empty prefixes and hold the base cases.
  - term: Subsequence
    definition: Elements taken from a sequence in their original order, not necessarily next to each other. "ONE" is a subsequence of "LONGEST"; "NOE" isn't.
  - term: Longest common subsequence (LCS)
    definition: The longest sequence that is a subsequence of both inputs. The basis of diff tools.
  - term: Edit distance
    definition: The fewest single-character insertions, deletions and replacements that turn one string into another. Also called Levenshtein distance.
mastery:
  - Count the paths through a grid with obstacles, including obstacles in the first row and column.
  - Write the LCS and edit distance recurrences from memory and explain each case.
  - Print a 2-D table and read the answer and the choices from it.
  - Reconstruct the LCS string and the list of edits by walking back from the bottom-right cell.
  - Cut a 2-D table's memory to two rows and say what that costs.
resources: [swift-array, swift-book-collection-types, swift-book-strings, swift-book-control-flow]
cards:
  - id: m20-l05-c1
    front: "Grid paths, right and down only, with blocked cells: recurrence?"
    back: paths[r][c] = 0 if blocked; 1 at the start; otherwise paths[r − 1][c] + paths[r][c − 1], treating cells outside the grid as 0. A block in the first row cuts off everything to its right in that row.
  - id: m20-l05-c2
    front: LCS recurrence?
    back: With L[i][j] for the first i of x and first j of y, and row and column 0 all zeros. If x[i − 1] == y[j − 1], L[i][j] = L[i − 1][j − 1] + 1; otherwise max(L[i − 1][j], L[i][j − 1]).
  - id: m20-l05-c3
    front: Edit distance recurrence?
    back: E[i][0] = i, E[0][j] = j. If the characters match, E[i][j] = E[i − 1][j − 1]; otherwise 1 + min(E[i − 1][j − 1] (replace), E[i − 1][j] (delete), E[i][j − 1] (insert)).
  - id: m20-l05-c4
    front: How do you recover the actual LCS or the edits?
    back: Start at the bottom-right cell and repeat the decision that produced each cell, moving diagonally, up or left, until you reach row or column 0. Collect characters (or edits) on the way and reverse them.
  - id: m20-l05-c5
    front: When can a 2-D table use two rows?
    back: When each cell reads only its own row and the previous one. Memory drops from O(m × n) to O(n), but the full table is gone, so you can't walk back for the reconstruction.
---

## The idea in one sentence

When the state needs two numbers, the table is a grid, and the method is the same as in lesson 4: **say what one cell means, set the edges, fill in an order that respects the dependencies**, then read the answer and walk back for the choices.

Module 18 counted paths through an empty grid with a memo. Here the grids have walls, and then the two indexes stop being coordinates and become positions in two strings.

## Paths around obstacles

A warehouse robot moves only right or down, from the top-left cell to the bottom-right one. Cells marked `#` hold shelves. How many routes are there?

A cell's paths come from the cell above it and the cell to its left. A blocked cell has no paths through it.

```swift
func cell(_ value: Int) -> String {
    let text = String(value)
    return String(repeating: " ", count: max(0, 3 - text.count)) + text
}

func countPaths(_ grid: [[Character]]) -> Int {
    let rows = grid.count
    let columns = grid[0].count
    var paths = Array(repeating: Array(repeating: 0, count: columns), count: rows)
    for r in 0..<rows {
        for c in 0..<columns {
            if grid[r][c] == "#" {
                paths[r][c] = 0
            } else if r == 0 && c == 0 {
                paths[r][c] = 1
            } else {
                let fromAbove = r > 0 ? paths[r - 1][c] : 0
                let fromLeft = c > 0 ? paths[r][c - 1] : 0
                paths[r][c] = fromAbove + fromLeft
            }
        }
    }
    for row in paths {
        print(row.map(cell).joined())
    }
    return paths[rows - 1][columns - 1]
}

let warehouse: [[Character]] = [
    Array("....."),
    Array(".#..."),
    Array("...#."),
    Array("#...."),
    Array("..#.."),
]
print(countPaths(warehouse))
```

```output
  1  1  1  1  1
  1  0  1  2  3
  1  1  2  0  3
  0  1  3  3  6
  0  1  0  3  9
9
```

- **What a cell means:** `paths[r][c]` is the number of routes from the start to cell (r, c).
- **Order:** each cell reads the one above (previous row) and the one to its left (same row, earlier column). Row by row, left to right, both are ready.
- **Edges:** instead of special first-row and first-column loops, `fromAbove` and `fromLeft` are 0 outside the grid. That handles a block in the first row or column without extra code: the `#` at the start of row 3 makes everything below it in column 0 zero, because nothing can reach it from the left.
- **The answer** is the bottom-right cell: 9 routes. Cost: O(rows × columns) time and space.
- `row.map(cell)` passes the `cell` function itself to `map`, as Module 11 did with functions as values.

Read the table to check it: the 0 at (2, 3) is the shelf, and the 3 below it at (3, 3) gets only its left neighbor's 3. Every number is the sum of the one above and the one to the left.

## Longest common subsequence

A **subsequence** keeps the order but can skip elements. The longest common subsequence of two inputs is the core of every diff: the lines (or characters) the two versions share in the same order are the ones that didn't change.

The state is a pair of prefixes: `length[i][j]` is the LCS length of **the first i characters of x and the first j characters of y**. Row 0 and column 0 are the empty prefixes, where the answer is 0. For the rest, look at the last character of each prefix:

- **They match:** that character ends a common subsequence. `length[i][j] = length[i - 1][j - 1] + 1`.
- **They don't:** at least one of the two last characters isn't in the LCS. Drop one or the other and keep the better: `max(length[i - 1][j], length[i][j - 1])`.

```swift
func longestCommonSubsequence(_ a: String, _ b: String) -> String {
    let x = Array(a)
    let y = Array(b)
    // length[i][j]: LCS length of the first i characters of x and the first j of y.
    var length = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
    for i in stride(from: 1, through: x.count, by: 1) {
        for j in stride(from: 1, through: y.count, by: 1) {
            if x[i - 1] == y[j - 1] {
                length[i][j] = length[i - 1][j - 1] + 1
            } else {
                length[i][j] = max(length[i - 1][j], length[i][j - 1])
            }
        }
    }
    print("    " + y.map { " \($0)" }.joined())
    for i in 0...x.count {
        let label = i == 0 ? " " : String(x[i - 1])
        print(label + " " + length[i].map { " \($0)" }.joined())
    }

    var result: [Character] = []
    var i = x.count
    var j = y.count
    while i > 0 && j > 0 {
        if x[i - 1] == y[j - 1] {
            result.append(x[i - 1])
            i -= 1
            j -= 1
        } else if length[i - 1][j] >= length[i][j - 1] {
            i -= 1
        } else {
            j -= 1
        }
    }
    return String(result.reversed())
}

print(longestCommonSubsequence("STONE", "LONGEST"))
```

```output
     L O N G E S T
   0 0 0 0 0 0 0 0
S  0 0 0 0 0 0 1 1
T  0 0 0 0 0 0 1 2
O  0 0 1 1 1 1 1 2
N  0 0 1 2 2 2 2 2
E  0 0 1 2 2 3 3 3
ONE
```

Reading the table:

- Row "T", column "T" holds 2: "ST" is common to "ST" and "LONGEST" (the S and T at the end).
- Row "E", column "E" holds 3: the E matches and adds 1 to the diagonal cell (row "N", column "G"), which is 2 ("ON").
- The bottom-right 3 is the answer for the full strings. The table can't hold both "ST" and "ONE"; the max keeps the longer.

**Reconstruction** starts at the bottom-right and replays the decisions. If the characters match, that character is in the LCS: take it and go diagonally. If not, move toward the neighbor that holds the larger value (up on a tie). Characters come out last first, so the result is reversed. The walk takes at most m + n steps.

The `stride(from: 1, through: x.count, by: 1)` loops do nothing for an empty string, where `1...x.count` would crash: a closed range `1...0` is invalid.

Cost: O(m × n) time and space for strings of length m and n. `Array(a)` comes first because a `String` can't be indexed by an integer; the array gives O(1) access to each character, as in Module 16's sliding-window lesson.

## Edit distance

A search field gets "kitten" and the catalog has "sitting". How far apart are they? **Edit distance** counts the fewest single-character edits: insert one, delete one or replace one.

Same prefix state: `cost[i][j]` is the fewest edits to turn **the first i characters of x into the first j of y**. The edges are real answers now, not zeros: turning i characters into nothing takes i deletions, and turning nothing into j characters takes j insertions. Then, at (i, j):

- **Last characters match:** no edit needed for them. `cost[i - 1][j - 1]`.
- **They don't:** one edit, plus the best of three ways to have handled the rest:
  - **replace** x's last character with y's: `cost[i - 1][j - 1]`
  - **delete** x's last character: `cost[i - 1][j]`
  - **insert** y's last character: `cost[i][j - 1]`

```swift
func editDistance(_ a: String, _ b: String) -> (distance: Int, steps: [String]) {
    let x = Array(a)
    let y = Array(b)
    // cost[i][j]: edits to turn the first i characters of x into the first j of y.
    var cost = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
    for i in 0...x.count { cost[i][0] = i }
    for j in 0...y.count { cost[0][j] = j }
    for i in stride(from: 1, through: x.count, by: 1) {
        for j in stride(from: 1, through: y.count, by: 1) {
            if x[i - 1] == y[j - 1] {
                cost[i][j] = cost[i - 1][j - 1]
            } else {
                cost[i][j] = 1 + min(cost[i - 1][j - 1], cost[i - 1][j], cost[i][j - 1])
            }
        }
    }

    var steps: [String] = []
    var i = x.count
    var j = y.count
    while i > 0 || j > 0 {
        if i > 0 && j > 0 && x[i - 1] == y[j - 1] {
            i -= 1
            j -= 1
        } else if i > 0 && j > 0 && cost[i][j] == cost[i - 1][j - 1] + 1 {
            steps.append("replace \(x[i - 1]) with \(y[j - 1])")
            i -= 1
            j -= 1
        } else if i > 0 && cost[i][j] == cost[i - 1][j] + 1 {
            steps.append("delete \(x[i - 1])")
            i -= 1
        } else {
            steps.append("insert \(y[j - 1])")
            j -= 1
        }
    }
    return (cost[x.count][y.count], steps.reversed())
}

let result = editDistance("kitten", "sitting")
print(result.distance, result.steps)
for word in ["swift", "shift", "swing", "spirit", "sift"] {
    print(word, editDistance("swfit", word).distance)
}
print(editDistance("", "abc").distance, editDistance("abc", "").distance)
```

```output
3 ["replace k with s", "replace e with i", "insert g"]
swift 2
shift 3
swing 3
spirit 3
sift 2
3 3
```

- `min` with three arguments is a standard library function; it takes any number of `Comparable` values.
- **Reconstruction** asks, at each cell, which case produced its value: a free diagonal move for matching characters, then replace, delete or insert, checked in that order. Any case that reproduces the value is part of some optimal edit list; the order of the checks only picks among equally good ones. The walk stops at (0, 0), and the `i > 0`, `j > 0` checks handle the edges, where only deletions or only insertions are left.
- `editDistance("", "abc")` is 3 insertions; the reverse is 3 deletions.

The "did you mean" loop shows the limit of this definition. The typo "swfit" swaps two letters, which costs 2 here (two replacements), and "sift" also costs 2 (delete `w`, then replace). A tie. The Damerau–Levenshtein variant adds "swap two adjacent characters" as one edit, which would make "swift" the clear winner at 1. Choosing the right distance is a product decision as much as an algorithmic one.

## Two rows instead of a table

In all three problems, a cell reads only its own row and the row above. Keep two rows and swap them:

```swift
func lcsLength(_ a: String, _ b: String) -> Int {
    let x = Array(a)
    let y = Array(b)
    var previous = Array(repeating: 0, count: y.count + 1)
    var current = previous
    for i in stride(from: 1, through: x.count, by: 1) {
        for j in stride(from: 1, through: y.count, by: 1) {
            if x[i - 1] == y[j - 1] {
                current[j] = previous[j - 1] + 1
            } else {
                current[j] = max(previous[j], current[j - 1])
            }
        }
        swap(&previous, &current)
    }
    return previous[y.count]
}

print(lcsLength("STONE", "LONGEST"), lcsLength("ABCBDAB", "BDCABA"), lcsLength("", "ABC"))
```

```output
3 4 0
```

After each row, `swap` makes the row just filled the new `previous`. `current[0]` stays 0, the empty-prefix column, because the loop never writes it. Memory drops from O(m × n) to O(n), with the same O(m × n) time. The cost is the same as in lesson 4: no table, no walk back. Put the shorter string as `y` to use the smaller row.

## Common mistakes

> [!error] Setting the whole first row and column to 1
> In an empty grid, every cell of the first row has exactly one path. With a shelf in the first row, the cells to its right have none. A loop that fills the first row with 1s before looking at obstacles reports routes through walls. Treat outside-the-grid neighbors as 0 and let the recurrence handle the edges, as the lesson's code does.

> [!error] Mixing table indexes and string indexes
> With an empty-prefix row and column, table cell (i, j) talks about `x[i - 1]` and `y[j - 1]`. Writing `x[i]` reads the wrong character and runs off the end at the last row. Comment what (i, j) means right above the table.

> [!error] Wrong edges in edit distance
> Copying the LCS setup (zeros on the edges) into edit distance says that turning "abc" into "" is free. The edges are i and j: deletions and insertions.

> [!error] Reconstructing from the two-row version
> Once rows are overwritten, the walk back has nothing to read. Keep the full table when you need the subsequence or the edits, or use a more advanced technique (Hirschberg's algorithm) that's outside this course.

## Exercises

````exercise
id: m20-l05-e1
type: comprehension
prompt: |
  In the lesson's edit distance table for x = "kitten" and y = "sitting", what does `cost[3][2]` mean?
choices:
  - text: "The fewest edits that turn \"kit\" into \"si\"."
    correct: true
    why: "Cell (i, j) is about the first i characters of x and the first j characters of y."
  - text: "The fewest edits that turn \"kitt\" into \"sit\"."
    correct: false
    why: "That would be the characters at indexes 0 through 3 and 0 through 2. The table's indexes count characters, so 3 means three characters."
  - text: "The cost of replacing x[3] with y[2]."
    correct: false
    why: "A cell holds the answer for two prefixes, not the cost of one edit."
  - text: "The number of edits made after 3 deletions and 2 insertions."
    correct: false
    why: "The indexes are prefix lengths, not counts of operations."
solution: |
  **"kit" into "si".** Prefix states always mean "the first i of one input and the first j of the other", with row and column 0 for the empty prefix. That's what makes the edges simple (i deletions, j insertions) and the answer easy to find: `cost[6][7]`, the full strings, in the bottom-right corner. `cost[3][2]` is 2: replace k with s, delete t.
````

````exercise
id: m20-l05-e2
type: prediction
prompt: Predict the exact output. `#` is a blocked cell.
code: |
  let grid: [[Character]] = [
      Array("..."),
      Array(".#."),
      Array("..."),
  ]
  var paths = Array(repeating: Array(repeating: 0, count: 3), count: 3)
  for r in 0..<3 {
      for c in 0..<3 {
          if grid[r][c] == "#" {
              paths[r][c] = 0
          } else if r == 0 && c == 0 {
              paths[r][c] = 1
          } else {
              let fromAbove = r > 0 ? paths[r - 1][c] : 0
              let fromLeft = c > 0 ? paths[r][c - 1] : 0
              paths[r][c] = fromAbove + fromLeft
          }
      }
  }
  for row in paths {
      print(row)
  }
output: |
  [1, 1, 1]
  [1, 0, 1]
  [1, 1, 2]
hints:
  - "The first row and column have one path each, since nothing blocks them."
  - "The middle cell is blocked, so it contributes 0 to its neighbors."
solution: |
  ```output
  [1, 1, 1]
  [1, 0, 1]
  [1, 1, 2]
  ```

  The first row and column are 1s: one straight route each. The center is 0. Cell (1, 2) gets 1 from above and 0 from the blocked center: 1. Cell (2, 1) gets 0 from the center and 1 from the left: 1. The corner gets 1 + 1 = 2: around the top and right, or around the left and bottom. Without the block it would be 6.
````

````exercise
id: m20-l05-e3
type: fill-in
prompt: Complete the LCS table loop. `x` and `y` are arrays of characters, and row and column 0 stay 0.
code: |
  for i in stride(from: 1, through: x.count, by: 1) {
      for j in stride(from: 1, through: y.count, by: 1) {
          if x[[[1]]] == y[j - 1] {
              length[i][j] = [[2]] + 1
          } else {
              length[i][j] = max(length[i - 1][j], [[3]])
          }
      }
  }
blanks:
  - id: "1"
    answers: ["i - 1", "i-1"]
  - id: "2"
    answers: ["length[i - 1][j - 1]", "length[i-1][j-1]"]
  - id: "3"
    answers: ["length[i][j - 1]", "length[i][j-1]"]
solution: |
  - `i - 1`: cell i talks about the first i characters, whose last one is `x[i - 1]`.
  - `length[i - 1][j - 1]`: a match extends the LCS of both shorter prefixes.
  - `length[i][j - 1]`: drop y's last character (the other option, `length[i - 1][j]`, drops x's).

  ```swift
  func lcsLength(_ a: String, _ b: String) -> Int {
      let x = Array(a)
      let y = Array(b)
      var length = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
      for i in stride(from: 1, through: x.count, by: 1) {
          for j in stride(from: 1, through: y.count, by: 1) {
              if x[i - 1] == y[j - 1] {
                  length[i][j] = length[i - 1][j - 1] + 1
              } else {
                  length[i][j] = max(length[i - 1][j], length[i][j - 1])
              }
          }
      }
      return length[x.count][y.count]
  }

  print(lcsLength("ABCBDAB", "BDCABA"), lcsLength("swift", "shift"), lcsLength("abc", "xyz"))
  ```

  ```output
  4 4 0
  ```

  "ABCBDAB" and "BDCABA" share several subsequences of length 4, such as "BCBA". "swift" and "shift" share "sift".
````

````exercise
id: m20-l05-e4
type: find-errors
prompt: |
  This counts grid paths (right and down only). It sets the edges first, then fills the inside. On the grid below it returns 2, but the only route goes down the left column and along the bottom. Which statements are true?

  ```text
  . # .
  . # .
  . . .
  ```
code: |
  func countPaths(_ grid: [[Character]]) -> Int {
      let rows = grid.count
      let columns = grid[0].count
      var paths = Array(repeating: Array(repeating: 0, count: columns), count: rows)
      for c in 0..<columns { paths[0][c] = 1 }
      for r in 0..<rows { paths[r][0] = 1 }
      for r in 1..<rows {
          for c in 1..<columns {
              if grid[r][c] == "#" {
                  paths[r][c] = 0
              } else {
                  paths[r][c] = paths[r - 1][c] + paths[r][c - 1]
              }
          }
      }
      return paths[rows - 1][columns - 1]
  }
choices:
  - text: "The first row is set to 1 everywhere, so the cell after the # in row 0 counts a path through the wall."
    correct: true
    why: "paths[0][2] should be 0: the only way to reach it is from the left, through the block."
  - text: "The block at (0, 1) itself is set to 1 and never corrected, because the inner loop starts at row 1."
    correct: true
    why: "Obstacles in row 0 or column 0 are never checked at all."
  - text: "Treating neighbors outside the grid as 0 and checking every cell for #, including the first row and column, fixes both."
    correct: true
    why: "That's the lesson's version: the edges follow from the recurrence."
  - text: "The loops should go bottom to top, since paths end at the bottom."
    correct: false
    why: "Each cell reads above and left, so top to bottom is the right order. Counting from the end backward would also work, with the recurrence reversed, but it isn't the bug."
rubric:
  - I identified that the edge initialization ignores obstacles.
  - I noted that blocked cells in row 0 and column 0 are never zeroed.
  - I described a fix that checks every cell and treats outside neighbors as 0.
solution: |
  The edges are filled with 1s as if the grid were empty, and the obstacle check only runs on the inside. On the grid above, `paths[0][2]` becomes 1 although nothing can reach it, and `paths[0][1]`, the wall itself, is 1. Both leak into the inside cells. The fix checks every cell and lets the recurrence handle the edges:

  ```swift
  func countPaths(_ grid: [[Character]]) -> Int {
      let rows = grid.count
      let columns = grid[0].count
      var paths = Array(repeating: Array(repeating: 0, count: columns), count: rows)
      for r in 0..<rows {
          for c in 0..<columns {
              if grid[r][c] == "#" {
                  paths[r][c] = 0
              } else if r == 0 && c == 0 {
                  paths[r][c] = 1
              } else {
                  let fromAbove = r > 0 ? paths[r - 1][c] : 0
                  let fromLeft = c > 0 ? paths[r][c - 1] : 0
                  paths[r][c] = fromAbove + fromLeft
              }
          }
      }
      return paths[rows - 1][columns - 1]
  }

  print(countPaths([Array(".#."), Array(".#."), Array("...")]))
  print(countPaths([Array("#.."), Array("..."), Array("...")]))
  ```

  ```output
  1
  0
  ```

  The buggy version returns 2 and 6 for these two grids. A blocked start must give 0; the buggy version sets the start to 1 regardless, so it counts all 6 routes of an empty 3 × 3 grid.
````

````exercise
id: m20-l05-e5
type: solve
prompt: |
  A hiking app shows a map as a grid of tile costs (effort to cross each tile). You start at the top-left tile and finish at the bottom-right one, moving only right or down, and you pay for every tile you step on, including the first and last. Write `func cheapestRoute(_ costs: [[Int]]) -> Int`.

  Print:

  ```output
  7
  12
  5
  ```

  for `[[1, 3, 1], [1, 5, 1], [4, 2, 1]]`, `[[1, 2, 3], [4, 5, 6]]` and `[[5]]`.
starter: |
  func cheapestRoute(_ costs: [[Int]]) -> Int {
      // best[r][c]: the lowest total cost to reach tile (r, c), including it.
      return 0
  }
hints:
  - "best[r][c] = costs[r][c] + the cheaper of the tile above and the tile to the left."
  - "In the first row only the left neighbor exists; in the first column only the one above."
rubric:
  - The recurrence takes the min of the two predecessors and adds the tile's own cost.
  - The first row and column are handled (only one predecessor).
  - The answer is the bottom-right entry, and the three lines match.
  - O(rows × columns) time.
solution: |
  ```swift
  func cheapestRoute(_ costs: [[Int]]) -> Int {
      let rows = costs.count
      let columns = costs[0].count
      var best = costs
      for r in 0..<rows {
          for c in 0..<columns {
              if r == 0 && c == 0 {
                  continue
              } else if r == 0 {
                  best[r][c] += best[r][c - 1]
              } else if c == 0 {
                  best[r][c] += best[r - 1][c]
              } else {
                  best[r][c] += min(best[r - 1][c], best[r][c - 1])
              }
          }
      }
      return best[rows - 1][columns - 1]
  }

  print(cheapestRoute([[1, 3, 1], [1, 5, 1], [4, 2, 1]]))
  print(cheapestRoute([[1, 2, 3], [4, 5, 6]]))
  print(cheapestRoute([[5]]))
  ```

  ```output
  7
  12
  5
  ```

  `best` starts as a copy of `costs`, so each entry already holds its own tile's cost and the loop adds the cheaper way in. Unlike path counting, `min` can't treat an outside neighbor as 0 (that would be a free route from nowhere), so the first row and column take their one real predecessor. The 7 is 1 → 3 → 1 → 1 → 1 along the top and right edges; the 12 is 1 → 2 → 3 → 6. O(rows × columns) time; the copy is O(rows × columns) space, which two rows (or one) could replace.
````

````exercise
id: m20-l05-e6
type: refactor
prompt: |
  Rewrite this edit distance so it keeps only two rows of the table. Keep the function's results the same, and print the distances for ("kitten", "sitting"), ("", "abc") and ("flaw", "lawn").
code: |
  func editDistance(_ a: String, _ b: String) -> Int {
      let x = Array(a)
      let y = Array(b)
      var cost = Array(repeating: Array(repeating: 0, count: y.count + 1), count: x.count + 1)
      for i in 0...x.count { cost[i][0] = i }
      for j in 0...y.count { cost[0][j] = j }
      for i in stride(from: 1, through: x.count, by: 1) {
          for j in stride(from: 1, through: y.count, by: 1) {
              if x[i - 1] == y[j - 1] {
                  cost[i][j] = cost[i - 1][j - 1]
              } else {
                  cost[i][j] = 1 + min(cost[i - 1][j - 1], cost[i - 1][j], cost[i][j - 1])
              }
          }
      }
      return cost[x.count][y.count]
  }
rubric:
  - The first previous row is 0...y.count (the insertions edge).
  - Each new row starts with current[0] = i (the deletions edge).
  - The cell reads previous[j - 1], previous[j] and current[j - 1], and the rows are swapped after each row.
  - The three distances match the full-table version.
solution: |
  ```swift
  func editDistance(_ a: String, _ b: String) -> Int {
      let x = Array(a)
      let y = Array(b)
      var previous = Array(0...y.count)
      var current = Array(repeating: 0, count: y.count + 1)
      for i in stride(from: 1, through: x.count, by: 1) {
          current[0] = i
          for j in stride(from: 1, through: y.count, by: 1) {
              if x[i - 1] == y[j - 1] {
                  current[j] = previous[j - 1]
              } else {
                  current[j] = 1 + min(previous[j - 1], previous[j], current[j - 1])
              }
          }
          swap(&previous, &current)
      }
      return previous[y.count]
  }

  print(editDistance("kitten", "sitting"), editDistance("", "abc"), editDistance("flaw", "lawn"))
  ```

  ```output
  3 3 2
  ```

  Unlike LCS, the edges here aren't zero, so both have to be written: `Array(0...y.count)` is row 0 (j insertions), and `current[0] = i` is column 0 for each new row (i deletions). Forgetting the second one leaves the value from two rows back in `current[0]`, which is wrong from the third row on. After the swap, `previous` holds the row just finished, and when x is empty the loop never runs and `previous[y.count]` is y's length. "flaw" to "lawn" is 2: delete f, insert n.
````

## Summary

- A 2-D table needs a sentence that says what cell (i, j) means. For two sequences, it's almost always "the first i of one and the first j of the other", with row and column 0 for empty prefixes.
- **Grid paths:** `paths[r][c] = above + left`, 0 for blocked cells and for neighbors outside the grid. Don't pre-fill edges with 1s.
- **LCS:** match → diagonal + 1; otherwise max of up and left. Edges are 0.
- **Edit distance:** match → diagonal; otherwise 1 + min of replace (diagonal), delete (up) and insert (left). Edges are i and j.
- **Reconstruct** by walking from the bottom-right corner, repeating whichever case produced each cell, and reversing what you collect.
- Fill row by row when cells read up, left and up-left. Two rows are enough for the value, O(n) memory, but not for the reconstruction.
