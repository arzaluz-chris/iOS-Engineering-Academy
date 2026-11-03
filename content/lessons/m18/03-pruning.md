---
id: m18-l03
title: Pruning the search
description: You make backtracking fast enough to use by cutting branches that can't lead to an answer. You check constraints when you make a choice instead of at the end, sort the candidates so one failed check can end a whole loop, track a board's constraints in arrays for O(1) checks, and solve N-Queens while counting the nodes you visit, so you can see exactly what each cut saves.
module: m18
order: 3
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l02]
objectives:
  - Explain pruning as skipping a subtree of the decision tree that provably contains no answer.
  - Check constraints at the moment of choice rather than on complete candidates.
  - Use sorted candidates to replace continue with break, and say when that's valid.
  - Solve a target-sum selection problem with and without reusing elements.
  - Solve N-Queens with O(1) safety checks and undo every piece of constraint state.
  - Measure the effect of pruning by counting explored nodes.
terms:
  - term: Pruning
    definition: Cutting off a branch of a search as soon as you can prove that nothing below it can be a valid answer, so none of its descendants are visited.
  - term: Constraint
    definition: A rule every valid answer must satisfy, like "the values add up to 50" or "no two queens share a column".
  - term: Feasibility check
    definition: A test applied to a partial answer that asks "can this still be completed into a valid answer?" A false result prunes the branch.
  - term: Node count
    definition: The number of calls a search makes, one per partial answer visited. Counting it is the honest way to compare search strategies.
  - term: N-Queens
    definition: The puzzle of placing n chess queens on an n × n board so that no two share a row, a column or a diagonal.
mastery:
  - Add a feasibility check to a backtracking function and show the node count drop.
  - Decide whether a failed check allows break or only continue.
  - Write N-Queens with column and diagonal arrays from memory.
  - Turn "pick numbers that add up to a target" into backtracking with the right start index for reuse or no reuse.
  - Describe a Sudoku solver as state, choices, constraints and pruning.
resources: [swift-book-functions, swift-book-control-flow, swift-array]
cards:
  - id: m18-l03-c1
    front: What does pruning a backtracking search mean?
    back: Not exploring a branch once you can prove no answer lies below it. The check runs when the choice is made, so the whole subtree under it is skipped.
  - id: m18-l03-c2
    front: When can a failed check use break instead of continue?
    back: When the candidates are sorted so that if this one fails, every later one fails too. For a target sum with positive values in ascending order, a value bigger than what's left means all later values are too.
  - id: m18-l03-c3
    front: In a target-sum search, how do you allow reusing the same element?
    back: "Recurse with explore(from: i) instead of explore(from: i + 1), so the same index can be chosen again. The remaining sum still has to drop, so it terminates if all values are positive."
  - id: m18-l03-c4
    front: How does N-Queens check whether a square is safe in O(1)?
    back: "Three Bool arrays: columns, diagonals indexed by row − column + n − 1, anti-diagonals indexed by row + column. A square is safe if all three are false. Mark them when placing, clear them when removing."
  - id: m18-l03-c5
    front: How many nodes does 8-Queens visit with and without pruning?
    back: "Placing one queen per row and checking only full boards: 19,173,961 nodes. Checking each placement against columns and diagonals: 2,057 nodes. Same 92 solutions."
---

## The idea in one sentence

Pruning means asking "can this partial answer still become a valid one?" **at every choice**, and turning back the moment the answer is no, so that a whole subtree of the search is never visited.

## Check when you choose, not at the end

You have gift cards worth 25, 10, 40, 5, 30, 15, 20, 50, 35 and 45 dollars, and you want every way to pay exactly $50, each card used at most once. That's the subsets generator from lesson 2 with a test:

```swift
func exactSumsNoPruning(_ values: [Int], target: Int) -> (results: [[Int]], nodes: Int) {
    var results: [[Int]] = []
    var current: [Int] = []
    var nodes = 0

    func explore(from start: Int, sum: Int) {
        nodes += 1
        if sum == target {
            results.append(current)
        }
        for i in start..<values.count {
            current.append(values[i])
            explore(from: i + 1, sum: sum + values[i])
            current.removeLast()
        }
    }

    explore(from: 0, sum: 0)
    return (results, nodes)
}

let cards = [25, 10, 40, 5, 30, 15, 20, 50, 35, 45]
let plain = exactSumsNoPruning(cards, target: 50)
print(plain.results.count, "ways,", plain.nodes, "nodes")
```

```output
10 ways, 1024 nodes
```

It visits all 2¹⁰ = 1,024 subsets and keeps 10. But all the values are positive, so once a selection goes over $50, adding more cards can only make it worse. Everything under `[40, 30]` is hopeless, and the search walks it anyway.

Turn the question around: track what's **remaining** and refuse any card that doesn't fit:

```swift
func exactSums(_ values: [Int], target: Int) -> (results: [[Int]], nodes: Int, checks: Int) {
    var results: [[Int]] = []
    var current: [Int] = []
    var nodes = 0
    var checks = 0

    func explore(from start: Int, remaining: Int) {
        nodes += 1
        if remaining == 0 {
            results.append(current)
            return
        }
        for i in start..<values.count {
            checks += 1
            if values[i] > remaining {
                continue
            }
            current.append(values[i])
            explore(from: i + 1, remaining: remaining - values[i])
            current.removeLast()
        }
    }

    explore(from: 0, remaining: target)
    return (results, nodes, checks)
}

let cards = [25, 10, 40, 5, 30, 15, 20, 50, 35, 45]
let pruned = exactSums(cards, target: 50)
print(pruned.results.count, "ways,", pruned.nodes, "nodes,", pruned.checks, "checks")
```

```output
10 ways, 43 nodes, 147 checks
```

From 1,024 nodes to 43, same 10 answers. Two cuts are doing the work:

- `if values[i] > remaining { continue }` refuses a card **before** recursing. The subtree under it is never created.
- `return` after recording at `remaining == 0`: with positive values, nothing below an exact match can be exact again.

A pruning rule has to be **safe**: it may only cut branches that contain no answers. "Values are positive, so the sum only grows" is what makes these two safe. With negative values allowed, a selection over $50 could come back down, and the same rule would silently lose answers.

## Sort, then break

The loop above still checks every remaining card, even after a check fails. If the cards are sorted ascending, a card that doesn't fit means **no later card fits either**, so the loop can stop:

```swift
func exactSumsSorted(_ values: [Int], target: Int) -> (results: [[Int]], nodes: Int, checks: Int) {
    let sorted = values.sorted()
    var results: [[Int]] = []
    var current: [Int] = []
    var nodes = 0
    var checks = 0

    func explore(from start: Int, remaining: Int) {
        nodes += 1
        if remaining == 0 {
            results.append(current)
            return
        }
        for i in start..<sorted.count {
            checks += 1
            if sorted[i] > remaining {
                break
            }
            current.append(sorted[i])
            explore(from: i + 1, remaining: remaining - sorted[i])
            current.removeLast()
        }
    }

    explore(from: 0, remaining: target)
    return (results, nodes, checks)
}

let cards = [25, 10, 40, 5, 30, 15, 20, 50, 35, 45]
let fast = exactSumsSorted(cards, target: 50)
print(fast.results.count, "ways,", fast.nodes, "nodes,", fast.checks, "checks")
print(fast.results)
```

```output
10 ways, 43 nodes, 74 checks
[[5, 10, 15, 20], [5, 10, 35], [5, 15, 30], [5, 20, 25], [5, 45], [10, 15, 25], [10, 40], [15, 35], [20, 30], [50]]
```

Same 43 nodes (the same branches were already being refused), but half the checks, because each loop ends at the first card that's too big. Sorting also puts each answer's values in ascending order, which makes the output easier to read and to test. The sort costs O(n log n) once, which is nothing next to the search.

The gap grows with the input. With twenty cards (the ten above plus 55, 60, … 100), these three versions measure 1,048,576 nodes without pruning, and 43 nodes with either pruned version, but 477 checks with `continue` against 75 with sorted `break`. That's from running the three functions on that input; try it.

> [!warning] break needs a reason
> `break` is only correct when the order guarantees that every later candidate fails too. On unsorted cards, `break` at the first card over the remaining amount would pick 25, then stop at 40 with $25 left, and never try the 5, 15 or 20 that come after it. Exercise 4 is that bug.

### When an element can be reused

If the values are denominations you can use any number of times (coins, or ticket prices for a group), the only change is where the next level starts:

```swift
func waysToPay(_ prices: [Int], total: Int) -> [[Int]] {
    let sorted = prices.sorted()
    var results: [[Int]] = []
    var current: [Int] = []

    func explore(from start: Int, remaining: Int) {
        if remaining == 0 {
            results.append(current)
            return
        }
        for i in start..<sorted.count {
            if sorted[i] > remaining {
                break
            }
            current.append(sorted[i])
            explore(from: i, remaining: remaining - sorted[i])
            current.removeLast()
        }
    }

    explore(from: 0, remaining: total)
    return results
}

print(waysToPay([5, 3, 2], total: 8))
```

```output
[[2, 2, 2, 2], [2, 3, 3], [3, 5]]
```

`explore(from: i, …)` lets the same price be chosen again; starting from `i` and not from 0 still keeps each multiset in ascending order, so `[3, 2, 3]` never appears. It terminates because every choice lowers `remaining` by at least the smallest price. A price of 0 would break that, and the recursion would never end.

## N-Queens: constraints you check in O(1)

Place n queens on an n × n chessboard so that no two attack each other: no shared row, column or diagonal. Only one queen fits per row, so the decision is "which column for the queen in this row?", one row per level of recursion.

A square is safe when its column and both of its diagonals are free. All squares on one diagonal (going down-right) share the value `row − column`; all squares on one anti-diagonal (going down-left) share `row + column`. Three arrays of `Bool` answer "is it free?" in O(1):

```swift
func queens(_ n: Int) -> (solutions: [[Int]], nodes: Int) {
    var solutions: [[Int]] = []
    var columnOfRow: [Int] = []
    var columnUsed = Array(repeating: false, count: n)
    var diagonalUsed = Array(repeating: false, count: 2 * n - 1)
    var antiDiagonalUsed = Array(repeating: false, count: 2 * n - 1)
    var nodes = 0

    func place(row: Int) {
        nodes += 1
        if row == n {
            solutions.append(columnOfRow)
            return
        }
        for column in 0..<n {
            let diagonal = row - column + n - 1
            let antiDiagonal = row + column
            if columnUsed[column] || diagonalUsed[diagonal] || antiDiagonalUsed[antiDiagonal] {
                continue
            }
            columnUsed[column] = true
            diagonalUsed[diagonal] = true
            antiDiagonalUsed[antiDiagonal] = true
            columnOfRow.append(column)

            place(row: row + 1)

            columnOfRow.removeLast()
            columnUsed[column] = false
            diagonalUsed[diagonal] = false
            antiDiagonalUsed[antiDiagonal] = false
        }
    }

    place(row: 0)
    return (solutions, nodes)
}

let four = queens(4)
print(four.solutions)
for column in four.solutions[0] {
    var squares: [String] = []
    for c in 0..<4 {
        squares.append(c == column ? "Q" : ".")
    }
    print(squares.joined(separator: " "))
}
for n in 5...8 {
    let result = queens(n)
    print("n = \(n): \(result.solutions.count) solutions, \(result.nodes) nodes")
}
```

```output
[[1, 3, 0, 2], [2, 0, 3, 1]]
. Q . .
. . . Q
Q . . .
. . Q .
n = 5: 10 solutions, 54 nodes
n = 6: 4 solutions, 153 nodes
n = 7: 40 solutions, 552 nodes
n = 8: 92 solutions, 2057 nodes
```

Line by line:

- `columnOfRow[r]` is the column of the queen in row r, so a solution is an array like `[1, 3, 0, 2]`. Rows never conflict, by construction.
- `row - column` runs from −(n − 1) to n − 1, so adding `n - 1` makes it a valid index from 0 to 2n − 2. `row + column` already runs from 0 to 2n − 2.
- The `if … continue` is the pruning: a square that's attacked is never placed, and nothing under it is explored.
- Choose sets **four** pieces of state; unchoose clears all four. Forgetting one diagonal is the classic N-Queens bug: the search runs, and quietly returns too few solutions.
- `row == n` means every row has a queen, and every placement was checked when it was made, so the board is valid without checking it again.

### What the pruning bought

Compare the version that places a queen in every column of every row and checks only complete boards. It visits 1 + n + n² + … + nⁿ nodes. Measured for n = 4 to 6 with a version that counts its nodes, and computed from that formula for 7 and 8 (the 8 × 8 count was also measured once, at 19,173,961):

| n | Check full boards only | Check each placement | Solutions |
| --- | --- | --- | --- |
| 4 | 341 | 17 | 2 |
| 5 | 3,906 | 54 | 10 |
| 6 | 55,987 | 153 | 4 |
| 7 | 960,800 | 552 | 40 |
| 8 | 19,173,961 | 2,057 | 92 |

The pruned search is still exponential (n = 10 takes 35,539 nodes for 724 solutions), but its base is far smaller, and that's the difference between a puzzle you can solve and one you can't. Pruning doesn't change the worst-case Big O you can prove easily; it changes how much of the tree you actually visit, which is why **counting nodes** is how you judge it.

## Making pruning stronger

Three ideas, roughly in order of how often they pay off:

1. **Check early.** Every constraint you can test on a partial answer should be tested at the choice, not at the end. That's everything this lesson did.
2. **Order the candidates** so that failure is detected early and can end the loop: sorted values with `break`.
3. **Choose the most constrained decision first.** In Sudoku, fill the empty cell with the fewest legal digits next. A cell with one option costs nothing to branch on; a cell with zero options proves the branch dead immediately. Exercise 6 asks you to design that solver.

## Common mistakes

> [!error] Pruning that isn't safe
> A cut that removes a branch containing an answer gives wrong results without any error. "Over the target, stop" is only safe with non-negative values; `break` is only safe when the order guarantees every later candidate fails. Before adding a cut, say out loud why no answer can be below it.

> [!error] Checking only complete answers
> Testing `sum == target` at the leaves is correct and visits every subset. If a constraint can be checked on a partial answer, check it there.

> [!error] Not undoing constraint state
> The `used` arrays are state, exactly like `current`. Mark on choose, clear on unchoose, every one of them. A missed clear makes later branches look blocked, and solutions disappear.

> [!error] Continuing past a complete answer
> When an exact match can't be extended into another exact match (positive values), `return` after recording. Otherwise the search keeps exploring children that can only overshoot.

## Exercises

````exercise
id: m18-l03-e1
type: comprehension
prompt: |
  A search picks values that add up to a target. The values are sorted **descending**: `[50, 45, 40, …, 5]`. Inside the loop, a value is bigger than what's remaining. What can the loop do?
choices:
  - text: "continue: skip this value; a later, smaller one might fit."
    correct: true
    why: "In descending order, later values are smaller, so one of them may still fit. Only skipping this one is safe."
  - text: "break: no later value can fit."
    correct: false
    why: "That's the rule for ascending order. In descending order, the values after this one are smaller."
  - text: "return: the whole branch is dead."
    correct: false
    why: "The branch still has smaller values to try."
  - text: "Record the current selection, since it's as close as it can get."
    correct: false
    why: "The problem asks for exact sums. Close isn't an answer."
solution: |
  **continue.** `break` is valid when every later candidate fails for the same reason. In ascending order "too big" carries forward; in descending order it doesn't. You could make descending order useful the other way round: skip ahead to the first value that fits (a binary search, Module 16), but the simple fix is to sort ascending.
````

````exercise
id: m18-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  func exactSums(_ values: [Int], target: Int) -> (results: [[Int]], nodes: Int) {
      var results: [[Int]] = []
      var current: [Int] = []
      var nodes = 0

      func explore(from start: Int, remaining: Int) {
          nodes += 1
          if remaining == 0 {
              results.append(current)
              return
          }
          for i in start..<values.count {
              if values[i] > remaining {
                  break
              }
              current.append(values[i])
              explore(from: i + 1, remaining: remaining - values[i])
              current.removeLast()
          }
      }

      explore(from: 0, remaining: target)
      return (results, nodes)
  }

  let result = exactSums([1, 2, 3, 4], target: 5)
  print(result.results)
  print(result.nodes)
output: |
  [[1, 4], [2, 3]]
  9
hints:
  - "Count the root call, then each call that happens after a value passes the check."
  - "Under [1], the remaining is 4: 2, 3 and 4 are tried in turn. Under [1, 2], remaining is 2, and 3 is already too big."
solution: |
  ```output
  [[1, 4], [2, 3]]
  9
  ```

  The calls, in order, with the remaining amount:

  1. `[]` (5)
  2. `[1]` (4)
  3. `[1, 2]` (2): 3 > 2, break
  4. `[1, 3]` (1): 4 > 1, break
  5. `[1, 4]` (0): recorded
  6. `[2]` (3)
  7. `[2, 3]` (0): recorded
  8. `[3]` (2): 4 > 2, break
  9. `[4]` (1): no values left after 4

  9 nodes, where all subsets would be 16. Back in the root, 4 fits (4 ≤ 5), so `[4]` is a node; its loop has nothing after index 3.
````

````exercise
id: m18-l03-e3
type: fill-in
prompt: Complete the N-Queens placement loop. `d` and `a` are the diagonal and anti-diagonal indexes.
code: |
  for column in 0..<n {
      let d = row - column + n - 1
      let a = [[1]]
      if columnUsed[column] || diagonalUsed[d] || antiDiagonalUsed[a] {
          [[2]]
      }
      columnUsed[column] = true
      diagonalUsed[d] = true
      antiDiagonalUsed[a] = true
      columnOfRow.append(column)
      place(row: [[3]])
      columnOfRow.removeLast()
      columnUsed[column] = false
      diagonalUsed[d] = false
      antiDiagonalUsed[a] = [[4]]
  }
blanks:
  - id: "1"
    answers: ["row + column", "column + row", "row+column", "column+row"]
  - id: "2"
    answers: ["continue"]
  - id: "3"
    answers: ["row + 1", "row+1"]
  - id: "4"
    answers: ["false"]
solution: |
  - `row + column`: every square on one anti-diagonal has the same sum.
  - `continue`: an attacked square is skipped, but the next column in the same row may be safe. `break` would be wrong; columns aren't ordered by safety.
  - `row + 1`: one queen per row, so the next level is the next row.
  - `false`: every mark made on choose is cleared on unchoose.

  ```swift
  func countQueens(_ n: Int) -> Int {
      var count = 0
      var columnOfRow: [Int] = []
      var columnUsed = Array(repeating: false, count: n)
      var diagonalUsed = Array(repeating: false, count: 2 * n - 1)
      var antiDiagonalUsed = Array(repeating: false, count: 2 * n - 1)

      func place(row: Int) {
          if row == n {
              count += 1
              return
          }
          for column in 0..<n {
              let d = row - column + n - 1
              let a = row + column
              if columnUsed[column] || diagonalUsed[d] || antiDiagonalUsed[a] {
                  continue
              }
              columnUsed[column] = true
              diagonalUsed[d] = true
              antiDiagonalUsed[a] = true
              columnOfRow.append(column)
              place(row: row + 1)
              columnOfRow.removeLast()
              columnUsed[column] = false
              diagonalUsed[d] = false
              antiDiagonalUsed[a] = false
          }
      }

      place(row: 0)
      return count
  }

  print(countQueens(4), countQueens(6), countQueens(8))
  ```

  ```output
  2 4 92
  ```
````

````exercise
id: m18-l03-e4
type: find-errors
prompt: |
  This should return every selection from `values` (positive, in any order) that adds up to `target`. For `[25, 10, 40, 5, 30, 15, 20, 50, 35, 45]` and 50 it finds 5 ways instead of 10. Which statements are true?
code: |
  func exactSums(_ values: [Int], target: Int) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int, remaining: Int) {
          if remaining == 0 {
              results.append(current)
              return
          }
          for i in start..<values.count {
              if values[i] > remaining {
                  break
              }
              current.append(values[i])
              explore(from: i + 1, remaining: remaining - values[i])
              current.removeLast()
          }
      }

      explore(from: 0, remaining: target)
      return results
  }
choices:
  - text: "break assumes the values are sorted ascending, and they aren't."
    correct: true
    why: "After 25 is chosen, $25 remains: 10 fits, then 40 doesn't and the loop stops, never trying the 5, 15 or 20 later in the array. [25, 5, 20] and [25, 10, 15] are lost, among others."
  - text: "Sorting the values at the start (and searching the sorted copy) fixes it."
    correct: true
    why: "Then a value that's too big means every later one is too, which is what break assumes."
  - text: "Changing break to continue would also fix it, with more checks."
    correct: true
    why: "continue is safe in any order. It finds all 10 ways; it just can't stop early."
  - text: "The return after recording loses answers."
    correct: false
    why: "With positive values, nothing below an exact match can be another exact match, so the return is a safe cut."
rubric:
  - I identified break on unsorted input as the bug.
  - I gave both fixes (sort first, or continue) and the trade-off between them.
  - I explained why the return after recording is safe.
solution: |
  The cut `break` is only safe when every later value is at least as big as this one. On the unsorted array it ends loops too early. Either fix works:

  ```swift
  func exactSums(_ values: [Int], target: Int) -> [[Int]] {
      let sorted = values.sorted()
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int, remaining: Int) {
          if remaining == 0 {
              results.append(current)
              return
          }
          for i in start..<sorted.count {
              if sorted[i] > remaining {
                  break
              }
              current.append(sorted[i])
              explore(from: i + 1, remaining: remaining - sorted[i])
              current.removeLast()
          }
      }

      explore(from: 0, remaining: target)
      return results
  }

  print(exactSums([25, 10, 40, 5, 30, 15, 20, 50, 35, 45], target: 50).count)
  ```

  ```output
  10
  ```

  Sorting costs O(n log n) once and lets every loop stop at the first misfit; `continue` keeps the original order and checks every remaining value. The lesson measured the difference: 74 checks against 147 on these ten values.
````

````exercise
id: m18-l03-e5
type: solve
prompt: |
  Write `func digitSets(count k: Int, sum target: Int) -> [[Int]]` that returns every set of `k` **distinct** digits from 1 to 9 that add up to `target`, each set in ascending order. Prune: stop a branch when the sum is exceeded or when it already has `k` digits.

  Print `digitSets(count: 3, sum: 7)`, `digitSets(count: 3, sum: 9)`, `digitSets(count: 4, sum: 1)` and the number of sets for `count: 5, sum: 25`:

  ```output
  [[1, 2, 4]]
  [[1, 2, 6], [1, 3, 5], [2, 3, 4]]
  []
  12
  ```
starter: |
  func digitSets(count k: Int, sum target: Int) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from digit: Int, remaining: Int) {
          // Record when current has k digits and remaining is 0
          // Stop when current has k digits
          // Try digits from `digit` to 9, break when one is too big
      }

      explore(from: 1, remaining: target)
      return results
  }
hints:
  - "When current.count == k, record if remaining == 0, then return either way."
  - "Digits are tried in ascending order, so a digit bigger than remaining means every later one is too: break."
  - "Distinct digits: recurse with d + 1."
rubric:
  - The function stops at k digits whether or not the sum matches.
  - It uses ascending digits with break, and recurses from d + 1 so digits are distinct.
  - The four lines match.
solution: |
  ```swift
  func digitSets(count k: Int, sum target: Int) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from digit: Int, remaining: Int) {
          if current.count == k {
              if remaining == 0 {
                  results.append(current)
              }
              return
          }
          if digit > 9 {
              return
          }
          for d in digit...9 {
              if d > remaining {
                  break
              }
              current.append(d)
              explore(from: d + 1, remaining: remaining - d)
              current.removeLast()
          }
      }

      explore(from: 1, remaining: target)
      return results
  }

  print(digitSets(count: 3, sum: 7))
  print(digitSets(count: 3, sum: 9))
  print(digitSets(count: 4, sum: 1))
  print(digitSets(count: 5, sum: 25).count)
  ```

  ```output
  [[1, 2, 4]]
  [[1, 2, 6], [1, 3, 5], [2, 3, 4]]
  []
  12
  ```

  Two cuts: at k digits the branch ends whatever the sum, and a digit bigger than what remains ends the loop. The `if digit > 9 { return }` guard is needed because `digit...9` with `digit` equal to 10 is an invalid range and crashes; `digit..<10` would avoid it too. There are only 2⁹ = 512 subsets of the digits, so this would be fast without pruning; the point is the shape, which is the same one you'd use on a much larger set of candidates.
````

````exercise
id: m18-l03-e6
type: design
prompt: |
  Design a backtracking solver for a standard 9 × 9 Sudoku. You don't have to write all of it. Describe: the state and how you store it, the choices at each step, how you check a choice in O(1), what you undo, when you stop, and one ordering idea that prunes more than going cell by cell. Write the key pieces of Swift if it helps.
rubric:
  - "State: the grid (for example [[Int]] with 0 for empty) plus, for each row, column and 3 × 3 box, which digits are used (Bool arrays or bit masks)."
  - "Choice: a digit 1–9 for one empty cell. Check: the digit isn't used in that cell's row, column or box, using box index (row / 3) * 3 + column / 3."
  - "Choose marks the digit in the grid and the three used structures; unchoose clears all of them."
  - "Stop when no empty cell is left (solved), and return a success flag so the search unwinds without undoing the solution."
  - "Ordering: pick the empty cell with the fewest legal digits next; a cell with zero options prunes the branch at once."
solution: |
  **State.** `grid: [[Int]]` with 0 for empty, and three lookups: `rowUsed[r][d]`, `columnUsed[c][d]`, `boxUsed[b][d]` (Bool arrays of 9 × 10, or one 9-bit mask per row, column and box). Fill them from the given digits before searching. The box of a cell is `(row / 3) * 3 + column / 3`.

  **Choice.** Pick an empty cell; try each digit d from 1 to 9 for which `rowUsed[r][d]`, `columnUsed[c][d]` and `boxUsed[b][d]` are all false. That's three O(1) lookups per candidate.

  **Choose / unchoose.** Set `grid[r][c] = d` and the three flags; recurse; if the recursion didn't solve the puzzle, set `grid[r][c] = 0` and clear the three flags.

  **Stop.** When there's no empty cell, the grid is solved. Have the function return `Bool` and return `true` immediately up the stack, skipping the undo, so the solved grid survives. Unlike N-Queens, you usually want one solution, not all of them.

  **Ordering.** Going cell by cell works for easy puzzles. Choosing the empty cell with the **fewest legal digits** each time is much stronger: a cell with exactly one option is a forced move with no branching, and a cell with zero options means the branch is dead before you've tried anything. Finding that cell costs a scan of up to 81 cells per node, which is cheap next to the branches it avoids.

  ```swift
  func boxIndex(row: Int, column: Int) -> Int {
      (row / 3) * 3 + column / 3
  }

  print(boxIndex(row: 0, column: 0), boxIndex(row: 4, column: 7), boxIndex(row: 8, column: 8))
  ```

  ```output
  0 5 8
  ```

  This exercise has no single right answer for how much to precompute. What matters is that every check is O(1), every mark is undone, and the most constrained cell goes first.
````

## Summary

- **Pruning** skips a subtree once you can prove it has no answer. Check constraints when you make a choice, not on complete candidates.
- Every cut needs a reason it's safe. "Over the target" only works with non-negative values; `break` only works when the order guarantees later candidates fail too (sorted ascending for "too big").
- Target-sum selections: track `remaining`, refuse values that don't fit, `return` after an exact match. Recurse with `i + 1` for each value at most once, with `i` to allow reuse.
- **N-Queens**: one queen per row; columns, `row − column + n − 1` diagonals and `row + column` anti-diagonals in Bool arrays give O(1) checks. Mark four things on choose, clear four on unchoose.
- Measure with a node counter: 8-Queens drops from 19,173,961 nodes to 2,057 with placement checks. Pruned searches are still exponential, just with a far smaller base.
- Stronger pruning: check early, order candidates so failure ends loops, and branch on the most constrained decision first.
