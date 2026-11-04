---
id: m20-l06
title: Recognizing DP problems
description: You learn to spot dynamic programming from a problem statement and its constraints, pick a state and transitions on purpose, and work the 0/1 knapsack from end to end. Greedy fails on it, brute force explodes, then the memo, the table, the walk back and the one-row version each fix one problem. The module closes with a recipe for interviews and a table for choosing between greedy, DP and backtracking.
module: m20
order: 6
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l05]
objectives:
  - Recognize the wording and constraints that point to dynamic programming, greedy or backtracking.
  - Choose a state and transitions for a new problem by asking what decision is made at each step and what must be remembered.
  - Solve the 0/1 knapsack top-down and bottom-up, reconstruct the chosen items, and reduce it to one row with a backward loop.
  - Follow a step-by-step recipe to present a DP solution in an interview.
terms:
  - term: 0/1 knapsack
    definition: Choose a subset of items, each with a weight and a value, to maximize total value without exceeding a capacity. Each item is taken whole or not at all, at most once.
  - term: Unbounded knapsack
    definition: The variant where each item can be taken any number of times, like coins in coin change. Its 1-D table is filled in the forward direction.
  - term: Transition
    definition: One way to move from a state to smaller states, corresponding to one choice. "Skip item i" and "take item i" are the two transitions of the knapsack.
  - term: Pseudo-polynomial time
    definition: A running time that is polynomial in a number's value rather than in its size in digits, like O(n × capacity). Fast for small capacities, impractical for huge ones.
mastery:
  - Read a problem statement and say whether it suggests DP, greedy or backtracking, citing the wording and the constraints.
  - Define the knapsack state, write both transitions, and give its time and space.
  - Explain why a ratio-based greedy fails on 0/1 knapsack, with a counterexample.
  - Write the one-row knapsack with the backward capacity loop and explain why forward would allow reuse.
  - Walk through a new DP problem out loud with the five-step recipe.
resources: [swift-array, swift-dictionary, swift-book-structures-classes, swift-array-sorted-by]
cards:
  - id: m20-l06-c1
    front: Which words in a problem statement suggest dynamic programming?
    back: "\"Count the number of ways\", \"minimum or maximum\" over choices, \"is it possible to reach / make / split\", with decisions per element that interact (adjacent, capacity, both strings). Plus constraints like n ≤ 1,000 or a target ≤ 10,000, too big for 2ⁿ."
  - id: m20-l06-c2
    front: 0/1 knapsack state and transitions?
    back: "State: (item index i, remaining capacity c). Transitions: skip i → (i + 1, c); take i if it fits → value + (i + 1, c − weight). O(n × capacity) time and states."
  - id: m20-l06-c3
    front: Why does the 1-D knapsack loop over capacity backward?
    back: Going down, best[c − weight] still holds the value from before this item, so each item is used at most once. Going up, it may already include this item, which turns it into the unbounded knapsack.
  - id: m20-l06-c4
    front: Greedy, DP or backtracking?
    back: "Greedy when an exchange argument shows the local choice is safe (intervals by end, shortest job first). DP when choices interact but the future depends on a small state (knapsack, LCS). Backtracking when you must list every solution or the state can't be compressed (permutations, N-Queens)."
  - id: m20-l06-c5
    front: The DP recipe for an interview?
    back: 1. Brute-force recursion in words. 2. State and its meaning. 3. Transitions and base cases. 4. Memo or table, with fill order. 5. Time, space, then optimize space or reconstruct if asked.
---

## The idea in one sentence

A problem is a DP problem when it asks for the best, the count or the possibility over **many interacting choices**, and **what matters about the past fits in a small state**; once you see that, the rest is the method from the last three lessons.

## Signals in the statement

Interview problems don't say "use dynamic programming". They say things like these:

| The statement says | What it often means |
| --- | --- |
| "How many ways…", "count the number of…" | DP counting. Greedy can't count, and listing every way is backtracking, too slow when the count is huge. |
| "Minimum cost / fewest steps / maximum value / longest…" | DP or greedy. Try for a greedy counterexample; if one exists, DP. |
| "Is it possible to make / reach / split…" | DP with Bool entries (or a set of reachable states). |
| "Each item at most once", "within a budget / capacity / weight" | Knapsack-like: state includes the remaining capacity. |
| "No two adjacent", "with a cooldown", "you can't…right after…" | The state includes what you did last. |
| Two strings or two arrays, "common", "transform", "match" | A 2-D table over prefixes (lesson 5). |
| "Return all…", "list every…" | Backtracking. The output alone is exponential. |
| "Schedule", "intervals", "earliest / latest" with no weights | Try greedy first, sorted by the right key (lesson 2). |

The **constraints** narrow it down. As a rough rule of thumb, assuming on the order of 10⁸ simple steps per second:

| Size of the input | What fits |
| --- | --- |
| n ≤ 10 to 12 | n!: permutations, plain backtracking |
| n ≤ 20 to 25 | 2ⁿ: subsets, backtracking with pruning |
| n ≤ 1,000 to 5,000 | n²: a 2-D table over two indexes |
| n ≤ 10⁵ to 10⁶ | n log n or n: sorting, greedy, a 1-D table, hashing |
| A target value up to 10⁴ or 10⁵ alongside n ≤ 100 or so | n × target: a table indexed by the value (coin change, knapsack) |

These are estimates, not guarantees; a constant factor or a debug build moves the line. But "n ≤ 100, capacity ≤ 10,000" is a strong hint that the capacity belongs in the state.

## Choosing the state and the transitions

For a problem you haven't seen, ask three questions:

1. **What decision is made at each step?** Usually one per element: take it or skip it, which coin comes last, which character to edit, where to move.
2. **What do I need to know to make the rest of the decisions?** That's the state. For coin change, the amount left. For the ad slots, the position (and whether the previous slot was taken, which the recurrence handles by jumping two). For the knight, the key and the moves left.
3. **What are the options from a state, and what's the smallest state?** The options are the transitions; the smallest states are the base cases.

If the answer to question 2 is "everything I've chosen so far", it's not a DP problem as stated. Either a smarter state exists, or it's backtracking.

## The capstone: 0/1 knapsack

A team plans a sprint with 13 story points of capacity. Each feature has a cost in points and an estimated value. Each feature is built whole or not at all. Which features maximize value?

Signals: "maximize value", "within a capacity", "each at most once", and both the number of features and the capacity are small. That's the 0/1 knapsack.

### Greedy fails

The tempting rule: take features in order of value per point. Here it is next to an exhaustive search:

```swift
struct Feature {
    let name: String
    let points: Int
    let value: Int
}

let backlog = [
    Feature(name: "Widgets", points: 5, value: 60),
    Feature(name: "Offline mode", points: 8, value: 90),
    Feature(name: "Dark icons", points: 2, value: 20),
    Feature(name: "Share sheet", points: 4, value: 50),
    Feature(name: "Search filters", points: 6, value: 70),
]
let capacity = 13

func greedyByRatio(_ features: [Feature], capacity: Int) -> (value: Int, names: [String]) {
    let sorted = features.sorted { Double($0.value) / Double($0.points) > Double($1.value) / Double($1.points) }
    var remaining = capacity
    var value = 0
    var names: [String] = []
    for feature in sorted where feature.points <= remaining {
        remaining -= feature.points
        value += feature.value
        names.append(feature.name)
    }
    return (value, names)
}

func bestByBruteForce(_ features: [Feature], capacity: Int) -> (value: Int, calls: Int) {
    var calls = 0
    func best(_ i: Int, _ remaining: Int) -> Int {
        calls += 1
        if i == features.count {
            return 0
        }
        let skip = best(i + 1, remaining)
        if features[i].points > remaining {
            return skip
        }
        let take = features[i].value + best(i + 1, remaining - features[i].points)
        return max(skip, take)
    }
    return (best(0, capacity), calls)
}

print(greedyByRatio(backlog, capacity: capacity))
print(bestByBruteForce(backlog, capacity: capacity))
```

```output
(value: 130, names: ["Share sheet", "Widgets", "Dark icons"])
(value: 150, calls: 44)
```

Greedy takes the two best ratios (Share sheet at 12.5 per point, Widgets at 12), has 4 points left, and can only fit Dark icons: 130, with 2 points unused. Widgets plus Offline mode use exactly 13 for 150. **Indivisible items break the ratio rule**: a great ratio is worthless if the item leaves a gap nothing fills. (If features could be partly built, the fractional knapsack, the ratio greedy would be optimal. 0/1 is the version interviews ask.)

`best(i, remaining)` is the brute force written the DP way on purpose: two transitions, skip or take, and a state of two numbers.

### Memoize

The state is `(i, remaining)`: which feature you're deciding on, and how many points are left. That's all the rest of the decisions need. On 20 generated features with a capacity of 40:

```swift
struct State: Hashable {
    let index: Int
    let remaining: Int
}

func knapsack(points: [Int], values: [Int], capacity: Int, useMemo: Bool) -> (value: Int, calls: Int, stored: Int) {
    var calls = 0
    var memo: [State: Int] = [:]
    func best(_ i: Int, _ remaining: Int) -> Int {
        calls += 1
        if i == points.count {
            return 0
        }
        let state = State(index: i, remaining: remaining)
        if useMemo, let known = memo[state] {
            return known
        }
        var result = best(i + 1, remaining)
        if points[i] <= remaining {
            result = max(result, values[i] + best(i + 1, remaining - points[i]))
        }
        if useMemo {
            memo[state] = result
        }
        return result
    }
    return (best(0, capacity), calls, memo.count)
}

let points = (0..<20).map { ($0 * 7) % 11 + 1 }
let values = (0..<20).map { ($0 * 13) % 17 + 5 }
print(points)
print(values)
print(knapsack(points: points, values: values, capacity: 40, useMemo: false))
print(knapsack(points: points, values: values, capacity: 40, useMemo: true))
```

```output
[1, 8, 4, 11, 7, 3, 10, 6, 2, 9, 5, 1, 8, 4, 11, 7, 3, 10, 6, 2]
[5, 18, 14, 10, 6, 19, 15, 11, 7, 20, 16, 12, 8, 21, 17, 13, 9, 5, 18, 14]
(value: 155, calls: 310356, stored: 0)
(value: 155, calls: 1147, stored: 611)
```

310,356 calls drop to 1,147. There are at most 20 × 41 = 820 states; the recursion reaches 611 of them. Each does O(1) work, so the cost is **O(n × capacity)**, compared with O(2ⁿ) for the brute force.

### Tabulate and reconstruct

Bottom-up, with the prefix form from lesson 5: `best[i][c]` is the most value from **the first i features within c points**. Row 0 is all zeros (no features, no value). Each row reads only the row above, so rows go top to bottom and capacities in any order:

```swift
struct Feature {
    let name: String
    let points: Int
    let value: Int
}

func planSprint(_ features: [Feature], capacity: Int) -> (value: Int, chosen: [String]) {
    let n = features.count
    // best[i][c]: the most value from the first i features within c points.
    var best = Array(repeating: Array(repeating: 0, count: capacity + 1), count: n + 1)
    for i in stride(from: 1, through: n, by: 1) {
        let feature = features[i - 1]
        for c in 0...capacity {
            best[i][c] = best[i - 1][c]
            if feature.points <= c {
                best[i][c] = max(best[i][c], feature.value + best[i - 1][c - feature.points])
            }
        }
    }

    var chosen: [String] = []
    var c = capacity
    for i in stride(from: n, through: 1, by: -1) where best[i][c] != best[i - 1][c] {
        chosen.append(features[i - 1].name)
        c -= features[i - 1].points
    }
    return (best[n][capacity], chosen.reversed())
}

let backlog = [
    Feature(name: "Widgets", points: 5, value: 60),
    Feature(name: "Offline mode", points: 8, value: 90),
    Feature(name: "Dark icons", points: 2, value: 20),
    Feature(name: "Share sheet", points: 4, value: 50),
    Feature(name: "Search filters", points: 6, value: 70),
]
print(planSprint(backlog, capacity: 13))
print(planSprint(backlog, capacity: 12))
print(planSprint(backlog, capacity: 1))
print(planSprint([], capacity: 10))
```

```output
(value: 150, chosen: ["Widgets", "Offline mode"])
(value: 140, chosen: ["Offline mode", "Share sheet"])
(value: 0, chosen: [])
(value: 0, chosen: [])
```

- **Skip:** `best[i - 1][c]`, the same capacity without this feature. **Take:** this feature's value plus the best of the earlier features in the points left.
- **Reconstruction:** walk from the last row up. If `best[i][c]` differs from `best[i - 1][c]`, feature i − 1 had to be taken to reach that value: record it and subtract its points. If they're equal, skipping it was enough. The `where` clause on the `for` loop filters the rows where the value changed; `c` is updated inside the loop, so each check uses the capacity left after the features taken so far.
- With 12 points the best is 140. Two plans tie at 140 (Offline mode + Share sheet, or Share sheet + Search filters + Dark icons); the walk finds one of them.
- The table has (n + 1) × (capacity + 1) entries: 6 × 14 = 84 here. Time and space O(n × capacity), **pseudo-polynomial**: double the capacity's value and the work doubles.

### One row, backward

Each row reads only the row above, at the same capacity or a smaller one. Keep one row and update it in place, **from the largest capacity down**:

```swift
func bestValue(points: [Int], values: [Int], capacity: Int) -> Int {
    var best = Array(repeating: 0, count: capacity + 1)
    for i in 0..<points.count {
        for c in stride(from: capacity, through: points[i], by: -1) {
            best[c] = max(best[c], values[i] + best[c - points[i]])
        }
    }
    return best[capacity]
}

let points = [5, 8, 2, 4, 6]
let values = [60, 90, 20, 50, 70]
print(bestValue(points: points, values: values, capacity: 13))
print(bestValue(points: [3], values: [10], capacity: 9))
```

```output
150
10
```

When `best[c]` is updated, `best[c - points[i]]` is at a **smaller** capacity, which a downward loop hasn't touched yet in this round. It still holds the previous row's value: the best without item i. That's exactly the "take it once" transition. A loop that stops at `points[i]` also skips the capacities where the item doesn't fit, which keep the previous row's value by doing nothing. O(capacity) space. As in lesson 4, the row alone can't be walked back.

## A recipe for interviews

1. **Brute force first, out loud.** "At each feature I either take it or skip it; that's 2ⁿ subsets." It shows you understand the problem and gives you the transitions.
2. **Name the state and say what it means.** "best(i, c) is the most value from features i onward with c points left." Check that it's all the rest of the decisions need.
3. **Write the transitions and the base cases.** Skip, take if it fits; past the last feature, the value is 0.
4. **Memo or table.** Memo is the quickest from the brute force and only computes reachable states. A table avoids recursion depth and makes the fill order and space optimization explicit. Either is accepted; say why you picked yours.
5. **Cost it, then improve.** States × transitions for time; the table size for space; then roll rows or reconstruct if they ask. Test on the smallest cases: empty input, capacity 0, one item that doesn't fit.

## Greedy, DP or backtracking?

| | Greedy | Dynamic programming | Backtracking |
| --- | --- | --- | --- |
| Decides | One choice per step, never revisited | Every choice, but each subproblem once | Every choice, undoing after each |
| Correct when | An exchange argument shows the local choice is safe | Subproblems overlap and the future depends on a small state | Always, if it explores everything (prune to make it fast) |
| Typical cost | O(n log n): a sort and a pass | States × transitions: O(n), O(n × m), O(n × capacity) | Exponential: O(2ⁿ), O(n!) |
| Typical problems | Interval scheduling, meeting rooms, shortest job first, US coins | Fewest coins (any coins), knapsack, LCS, edit distance, decodings | All subsets or permutations, N-Queens, sudoku |
| Output | One answer | One value (and one answer by reconstruction) | All answers, or one found by search |
| Red flag | You can't prove it and a small counterexample exists | The state needs the whole history | n is in the thousands |

When unsure, start with the backtracking recursion: it's correct. If its arguments repeat and fit in a small state, memoize it, and you have DP. If you can prove one branch is always best, drop the others, and you have greedy.

## Common mistakes

> [!error] The one-row knapsack with a forward loop
> `for c in stride(from: points[i], through: capacity, by: 1)` updates small capacities first, so `best[c - points[i]]` may already include item i, and the item gets taken again. That's the unbounded knapsack: for one item of 3 points and value 10 with a capacity of 9, the forward loop returns 30 (three copies) instead of 10. Exercise 4 runs it.

> [!error] Using a greedy ratio for 0/1 items
> Value per weight is optimal only when items can be split. With whole items, the lesson's backlog loses 20 value to it.

> [!error] A state that's secretly the whole history
> "The set of items chosen so far" as a state gives 2ⁿ states, which is backtracking with extra memory. The knapsack only needs the remaining capacity, because the future doesn't care **which** items used the points.

> [!error] Forgetting pseudo-polynomial means "depends on the value"
> O(n × capacity) is fast for a capacity of 1,000 and useless for a capacity of 10¹². If the capacity is huge and n is small (n ≤ 40 or so), meet-in-the-middle backtracking or a different state (indexed by value instead of capacity) can work; neither is covered in this course.

## Exercises

````exercise
id: m20-l06-e1
type: comprehension
prompt: |
  "Given up to 100 song lengths and a road trip of up to 10,000 seconds, decide whether some of the songs, each played at most once, fill the trip exactly." Which approach fits best?
choices:
  - text: "A Bool table indexed by total length, filled item by item with a backward loop."
    correct: true
    why: "\"Is it possible\", \"each at most once\" and a target up to 10,000 alongside n ≤ 100 are the knapsack signals. About 100 × 10,000 = 10⁶ steps."
  - text: "Greedy: add the longest songs first until the trip is full."
    correct: false
    why: "With 6, 5 and 5 for a 10-second trip, greedy takes the 6 and then nothing fits exactly; 5 + 5 works."
  - text: "Backtracking over all subsets."
    correct: false
    why: "2¹⁰⁰ subsets. Pruning helps, but there's no guarantee it helps enough."
  - text: "Sort the songs and use two pointers."
    correct: false
    why: "Two pointers find a pair with a given sum. Here any number of songs can be chosen."
solution: |
  **The Bool table.** `reachable[t]` says whether some songs considered so far sum to exactly t. Start with `reachable[0] = true`; for each song of length s, for t from the target down to s, set `reachable[t] = reachable[t] || reachable[t - s]`. The backward loop keeps each song to one use, as in the one-row knapsack. O(n × target) time, O(target) space. Exercise 5 is the same idea.
````

````exercise
id: m20-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  let points = [1, 3, 4]
  let values = [15, 20, 30]
  let capacity = 4
  var best = Array(repeating: Array(repeating: 0, count: capacity + 1), count: points.count + 1)
  for i in 1...points.count {
      for c in 0...capacity {
          best[i][c] = best[i - 1][c]
          if points[i - 1] <= c {
              best[i][c] = max(best[i][c], values[i - 1] + best[i - 1][c - points[i - 1]])
          }
      }
  }
  for row in best {
      print(row)
  }
output: |
  [0, 0, 0, 0, 0]
  [0, 15, 15, 15, 15]
  [0, 15, 15, 20, 35]
  [0, 15, 15, 20, 35]
hints:
  - "Row 1 is the first item alone: 15 wherever 1 point fits."
  - "Row 2, capacity 4: skip (15) or take the 3-point item, 20 + best[1][1] = 35."
  - "Row 3, capacity 4: the 4-point item alone is 30, which loses to 35."
solution: |
  ```output
  [0, 0, 0, 0, 0]
  [0, 15, 15, 15, 15]
  [0, 15, 15, 20, 35]
  [0, 15, 15, 20, 35]
  ```

  - Row 0: no items, no value.
  - Row 1 (1 point, 15): fits from capacity 1 on, and only once, so 15 everywhere.
  - Row 2 (3 points, 20): at capacity 3, take it alone (20 + best[1][0] = 20) beats 15. At 4, take it with the first item: 20 + best[1][1] = 35.
  - Row 3 (4 points, 30): at 4, taking it gives 30 + best[2][0] = 30, and skipping keeps 35. The row is unchanged.

  The most valuable single item (30) isn't in the best plan, another case where greedy by value fails.
````

````exercise
id: m20-l06-e3
type: fill-in
prompt: Complete the one-row 0/1 knapsack.
code: |
  var best = Array(repeating: 0, count: capacity + 1)
  for i in 0..<points.count {
      for c in stride(from: [[1]], through: [[2]], by: [[3]]) {
          best[c] = max(best[c], values[i] + best[[[4]]])
      }
  }
blanks:
  - id: "1"
    answers: ["capacity"]
  - id: "2"
    answers: ["points[i]"]
  - id: "3"
    answers: ["-1"]
  - id: "4"
    answers: ["c - points[i]", "c-points[i]"]
solution: |
  - `capacity` down to `points[i]`, step `-1`: backward, so `best[c - points[i]]` still holds the value from before item i. Capacities below `points[i]` can't take the item and keep their value.
  - `c - points[i]`: the best with the points left after taking item i.

  ```swift
  func bestValue(points: [Int], values: [Int], capacity: Int) -> Int {
      var best = Array(repeating: 0, count: capacity + 1)
      for i in 0..<points.count {
          for c in stride(from: capacity, through: points[i], by: -1) {
              best[c] = max(best[c], values[i] + best[c - points[i]])
          }
      }
      return best[capacity]
  }

  print(bestValue(points: [1, 3, 4], values: [15, 20, 30], capacity: 4))
  print(bestValue(points: [5], values: [100], capacity: 4))
  ```

  ```output
  35
  0
  ```

  When an item is bigger than the capacity, `stride(from: 4, through: 5, by: -1)` is empty, so nothing changes and nothing crashes. A closed range `5...4` would trap; `stride` doesn't.
````

````exercise
id: m20-l06-e4
type: find-errors
prompt: |
  A colleague shrank the knapsack table to one row. On the sprint backlog with 13 points it returns 160, more than the true best of 150. Which statements are true?
code: |
  func bestValue(points: [Int], values: [Int], capacity: Int) -> Int {
      var best = Array(repeating: 0, count: capacity + 1)
      for i in 0..<points.count {
          for c in stride(from: points[i], through: capacity, by: 1) {
              best[c] = max(best[c], values[i] + best[c - points[i]])
          }
      }
      return best[capacity]
  }
choices:
  - text: "The forward loop lets best[c - points[i]] already include item i, so an item can be taken more than once."
    correct: true
    why: "At c = 8, best[4] already holds the Share sheet taken at c = 4, so 50 + 50 counts it twice."
  - text: "Looping from capacity down to points[i] fixes it."
    correct: true
    why: "Smaller capacities are updated after larger ones, so every read sees the value without item i."
  - text: "This forward version is the correct solution when items can be reused."
    correct: true
    why: "It's the unbounded knapsack, the same shape as coin change in lesson 4."
  - text: "The max should be replaced by addition."
    correct: false
    why: "The entry is the better of skip and take; adding them would count both."
rubric:
  - I explained how the forward loop reuses an item, with a concrete capacity.
  - I gave the backward fix.
  - I recognized the forward loop as the unbounded knapsack.
solution: |
  The direction of the capacity loop decides whether item i can appear in the value you read. Forward, `best[c - points[i]]` may have been updated in this same round, so it can contain item i; backward, it can't.

  ```swift
  func bestValue(points: [Int], values: [Int], capacity: Int, forward: Bool) -> Int {
      var best = Array(repeating: 0, count: capacity + 1)
      for i in 0..<points.count {
          let order = forward
              ? Array(stride(from: points[i], through: capacity, by: 1))
              : Array(stride(from: capacity, through: points[i], by: -1))
          for c in order {
              best[c] = max(best[c], values[i] + best[c - points[i]])
          }
      }
      return best[capacity]
  }

  let points = [5, 8, 2, 4, 6]
  let values = [60, 90, 20, 50, 70]
  print(bestValue(points: points, values: values, capacity: 13, forward: true))
  print(bestValue(points: points, values: values, capacity: 13, forward: false))
  ```

  ```output
  160
  150
  ```

  The 160 is two Share sheets and one Widgets (4 + 4 + 5 points, 50 + 50 + 60), which is only legal if a feature can be built twice.
````

````exercise
id: m20-l06-e5
type: solve
prompt: |
  A team wants to split a list of task durations between two developers so both get exactly the same total. Write `func canSplitEvenly(_ durations: [Int]) -> Bool`. Durations are positive. Aim for O(n × total) time and O(total) space.

  Print:

  ```output
  true
  false
  true
  true
  ```

  for `[1, 5, 11, 5]`, `[1, 2, 3, 5]`, `[3, 1, 1, 2, 2, 1]` and `[]`.
starter: |
  func canSplitEvenly(_ durations: [Int]) -> Bool {
      // An odd total can't be split.
      // Otherwise: can some tasks add up to exactly half?
      return false
  }
hints:
  - "If one developer gets exactly half, the other gets the rest, which is also half. So it's subset sum with target total / 2."
  - "reachable[t]: some of the tasks seen so far add up to t. reachable[0] is true."
  - "Each task is used at most once: loop t from the target down to the duration."
rubric:
  - The function returns false for an odd total.
  - It uses a Bool table of size target + 1 with reachable[0] = true.
  - The inner loop runs backward so each task is used at most once.
  - The four lines match.
solution: |
  ```swift
  func canSplitEvenly(_ durations: [Int]) -> Bool {
      let total = durations.reduce(0, +)
      if total % 2 != 0 {
          return false
      }
      let target = total / 2
      var reachable = Array(repeating: false, count: target + 1)
      reachable[0] = true
      for duration in durations {
          for t in stride(from: target, through: duration, by: -1) {
              if reachable[t - duration] {
                  reachable[t] = true
              }
          }
      }
      return reachable[target]
  }

  print(canSplitEvenly([1, 5, 11, 5]))
  print(canSplitEvenly([1, 2, 3, 5]))
  print(canSplitEvenly([3, 1, 1, 2, 2, 1]))
  print(canSplitEvenly([]))
  ```

  ```output
  true
  false
  true
  true
  ```

  **Signals:** "is it possible", "split", each task used once, totals small. **State:** a total t, after considering some prefix of the tasks. **Transition:** for each task, t becomes reachable if t − duration was reachable before this task. It's the 0/1 knapsack with Bool values and no capacity left over, so the loop goes backward. `[1, 5, 11, 5]` splits as 11 and 1 + 5 + 5; `[1, 2, 3, 5]` has an odd total, 11. An empty list splits into two empty halves. A task longer than the target makes the `stride` empty and is skipped. O(n × total) time, O(total) space.
````

````exercise
id: m20-l06-e6
type: design
prompt: |
  Apply the five-step recipe to a problem you haven't solved in this module: **the longest strictly increasing subsequence** of an array of integers (for `[10, 9, 2, 5, 3, 7, 101, 18]` it's 4, for example 2, 3, 7, 18). Describe the brute force, the state and its meaning, the transitions and base case, memo or table and fill order, and the time and space. Run your table on the example if you write code.
rubric:
  - "Brute force: each element is in or out, 2ⁿ subsets, keep the increasing ones."
  - "State: lis[i] = the length of the longest increasing subsequence that ends at index i (ending at, not within the first i)."
  - "Transition: lis[i] = 1 + max(lis[j]) over j < i with a[j] < a[i], or 1 if there's none. The answer is the max over all i, not lis[n − 1]."
  - "Table filled left to right; O(n²) time, O(n) space."
  - "Mentions that an O(n log n) method exists, without needing to derive it."
solution: |
  1. **Brute force.** Every element is in or out: 2ⁿ subsequences; keep the strictly increasing ones and take the longest.
  2. **State.** The past only matters through the last element taken, since the next one has to be bigger. So `lis[i]` is the length of the longest increasing subsequence **ending at index i**. "Ending at" is the key choice: "within the first i" doesn't tell you the last value, so it can't decide whether the next element extends it.
  3. **Transitions and base case.** `lis[i] = 1 + max(lis[j])` over every `j < i` with `a[j] < a[i]`; if no such j exists, `lis[i] = 1` (the element alone). The answer is the **largest** `lis[i]`, because the best subsequence can end anywhere.
  4. **Table.** Each entry reads entries to its left: fill left to right.
  5. **Cost.** n states, up to n transitions each: O(n²) time, O(n) space. A cleverer O(n log n) method (patience sorting with binary search) exists; it's a good follow-up question to mention.

  ```swift
  func longestIncreasing(_ a: [Int]) -> Int {
      var lis = Array(repeating: 1, count: a.count)
      for i in 0..<a.count {
          for j in 0..<i where a[j] < a[i] {
              lis[i] = max(lis[i], lis[j] + 1)
          }
      }
      return lis.max() ?? 0
  }

  print(longestIncreasing([10, 9, 2, 5, 3, 7, 101, 18]))
  print(longestIncreasing([5, 4, 3]), longestIncreasing([]))
  ```

  ```output
  4
  1 0
  ```

  For the example the table is `[1, 1, 1, 2, 2, 3, 4, 4]`: 7 extends 2, 5 (or 2, 3), and both 101 and 18 extend that. The answer, 4, appears twice; returning `lis[n − 1]` would happen to work here and fail on `[1, 2, 3, 0]`.
````

## Summary

- **Signals:** "how many ways", "min/max", "is it possible", "each at most once", "within a capacity", two strings, plus constraints like n ≤ 1,000 or a target ≤ 10,000. "Return all" means backtracking; unweighted scheduling means try greedy.
- **State:** ask what decision is made at each step and what the rest of the decisions need to know. If the answer is "the whole history", it isn't DP yet.
- **0/1 knapsack:** state (item, capacity left); skip or take. Greedy by ratio failed (130 against 150). The memo cut 310,356 calls to 1,147. The table is O(n × capacity), pseudo-polynomial; walk it back for the chosen items; one row works if the capacity loop runs **backward** (forward means unbounded reuse).
- **Recipe:** brute force out loud, state with its meaning, transitions and base cases, memo or table with fill order, cost and then improve.
- **Choosing:** greedy needs a proof, DP needs overlapping subproblems with a small state, backtracking is the always-correct fallback and the only option when every solution must be listed.
