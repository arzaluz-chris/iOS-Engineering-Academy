---
id: combination-sum-without-reuse
title: Combination Sum Without Reuse
difficulty: medium
order: 54
patterns: [Backtracking, Pruning, Skipping duplicates]
prerequisites: [m18-l02, m18-l03]
summary: Find every distinct way to reach a target with values you can each use once, when some values repeat. Sort, cut on overshoot, and skip equal values at the same level.
solutionFile: CombinationSumNoReuse.swift
testFile: CombinationSumNoReuseTests.swift
starter: |
  func combinationSumNoReuse(_ candidates: [Int], target: Int) -> [[Int]] {
      // Your solution
      return []
  }
time: O(n · 2^n) in the worst case
space: O(n) besides the output
edgeCases:
  - No candidates, or no combination that works
  - A value needed twice but present only once
  - Many copies of one value
  - Target equal to a single candidate, or to the sum of all of them
askInterviewer:
  - Can a value be used more than once? (Only as many times as it appears.)
  - Are all values positive? Zero or negatives would break the pruning.
  - Are [5, 10] and [10, 5] the same combination?
  - Does the order of the results matter?
hints:
  - The lesson's exactSums finds every selection that adds up to a target. What goes wrong when the input has repeated values?
  - After sorting, once a value is bigger than what's left, every later value is too.
  - The duplicates come from choosing different copies of the same value at the same level. The subsets-with-duplicates rule applies unchanged.
followUps:
  - What changes if each value can be used any number of times? (Recurse from i instead of i + 1, as in the lesson's waysToPay.)
  - How would you only count the combinations? (Dynamic programming over the target, Module 20.)
  - What if the combination must have exactly k values?
rubric:
  - I sorted and used break when a value exceeds the remaining amount.
  - I skipped equal values at the same level with i > start.
  - I recursed with i + 1 so each position is used once.
  - I explained why both cuts are safe and what the input must guarantee (positive values).
codeStatus: tested
---

A store lets customers pay with gift cards from a wallet. Each card has a fixed value, each card can be used at most once, and the wallet may hold several cards of the same value. Write `combinationSumNoReuse(_:target:)` that returns every distinct combination of card values that adds up exactly to `target`. Each combination is in ascending order; two combinations with the same values count once; the list can be in any order.

```swift
combinationSumNoReuse([10, 5, 20, 5, 15, 25], target: 30)
// [[5, 5, 20], [5, 10, 15], [5, 25], [10, 20]]   in any order
combinationSumNoReuse([4, 4, 4], target: 8)  // [[4, 4]]
combinationSumNoReuse([6, 9], target: 5)     // []
```

**Constraints:** `0 ≤ candidates.count ≤ 30`; `1 ≤ candidates[i] ≤ 50`; `1 ≤ target ≤ 100`.

<!-- reveal -->

## First approach

This is the lesson's `exactSums` with one new problem: repeated values. With two 5s, `[5, 25]` can be built from the first 5 or the second, and `exactSums` returns it twice. It's the same issue as subsets with duplicates, and the same fix works: sort, and at each level try each value only once.

## Naive solution

Try every subset of positions, keep the ones that add up to the target, and filter repeats with a `Set`:

```swift
func combinationSumNoReuse(_ candidates: [Int], target: Int) -> [[Int]] {
    let sorted = candidates.sorted()
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    for selection in 0..<(1 << sorted.count) {
        var combination: [Int] = []
        var sum = 0
        for index in sorted.indices where selection & (1 << index) != 0 {
            combination.append(sorted[index])
            sum += sorted[index]
        }
        if sum == target && seen.insert(combination).inserted {
            results.append(combination)
        }
    }
    return results
}
```

## Problems with the naive solution

With 30 candidates, 2³⁰ is about a billion subsets, and nearly all of them overshoot a target of 100 early. Nothing stops a subset once its sum is already too big, and nothing stops equal values from producing the same combination many times before the `Set` throws them away.

## Optimized solution

Sort, then backtrack with the remaining amount. At each level the loop picks the next card. Two cuts keep the search small: `break` when a card is bigger than what's left (sorted order means every later card is too), and `continue` when a card equals the one before it at this level, because that branch was already explored. Recurse with `i + 1` so a position is never used twice.

## Line by line

- `let sorted = candidates.sorted()`: needed by both cuts.
- `if remaining == 0 { results.append(current); return }`: exact match. With positive values nothing deeper can also hit 0, so stopping is safe.
- `for i in start..<sorted.count`: only positions after the last chosen one, so each combination comes out in ascending order once.
- `if sorted[i] > remaining { break }`: overshoot. Not `continue`: the later values are at least as big.
- `if i > start && sorted[i] == sorted[i - 1] { continue }`: the duplicate rule from subsets with duplicates. The first copy at this level already produced every combination this one would.
- `explore(from: i + 1, remaining: remaining - sorted[i])`: `i + 1` means this card is used; the next level starts after it. The lesson's `waysToPay` used `i` because coins could repeat.
- `current.append` before and `current.removeLast()` after: choose and unchoose.

## Common mistakes

- Recursing with `i` instead of `i + 1`, which reuses the same card and returns `[3, 3]` from a single 3.
- Using `i > 0` instead of `i > start`, which loses `[5, 5, 20]`: the second 5 could never follow the first.
- Sorting a copy but looping over the original array. Both cuts assume sorted order, and on unsorted input `break` silently drops answers.

## Variation

**Combination Sum III:** choose exactly k distinct digits from 1 to 9 that add up to n. The candidates are fixed and distinct, so there's no duplicate rule, but a second cut appears: stop when the combination already has k digits. The lesson's `digitSets` exercise is this problem.
