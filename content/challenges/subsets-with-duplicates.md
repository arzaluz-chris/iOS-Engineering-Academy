---
id: subsets-with-duplicates
title: Subsets with Duplicates
difficulty: medium
order: 52
patterns: [Backtracking, Subsets, Skipping duplicates]
prerequisites: [m18-l02]
summary: Generate every distinct subset of a list that contains repeated values, without producing any subset twice and without a Set to filter them.
solutionFile: UniqueSubsets.swift
testFile: UniqueSubsetsTests.swift
starter: |
  func uniqueSubsets(_ nums: [Int]) -> [[Int]] {
      // Your solution
      return []
  }
time: O(n · 2^n) in the worst case
space: O(n) besides the output
edgeCases:
  - Empty list, which has exactly one subset
  - All values equal, which gives n + 1 subsets
  - No repeats at all, which gives 2^n
  - Negative values and zero
askInterviewer:
  - Is the order of the subsets in the answer important? And the order inside a subset?
  - Are [1, 2] and [2, 1] the same subset? (Yes.)
  - Can I sort the input, or a copy of it?
hints:
  - Start from the subsets generator in the backtracking lesson. Which subsets come out twice for [2, 1, 2]?
  - Sort first. Then all copies of a value sit next to each other.
  - At one level of the recursion, choosing the first 2 or the second 2 as the next element leads to the same subsets. Skip the second one, but only at the same level.
followUps:
  - How many distinct subsets are there when value v appears c_v times? (The product of c_v + 1.)
  - Write it without recursion, by extending the previous results.
  - How does the same skip rule show up in combination sum and permutations with duplicates?
rubric:
  - I sorted the input so equal values are adjacent.
  - I skipped a repeated value only when it's not the first choice at the current level (i > start).
  - I avoided a Set for deduplication and explained why the skip rule is enough.
  - I gave O(n · 2^n) as the worst case and said when it's reached.
codeStatus: tested
---

A shopping cart can hold several units of the same item, identified by item number. Write `uniqueSubsets(_:)` that returns every distinct bundle you can take from the cart: every distinct subset of `nums`. Two subsets are the same if they contain the same values the same number of times. Return each subset in ascending order; the subsets themselves can come in any order.

```swift
uniqueSubsets([2, 1, 2])
// [[], [1], [1, 2], [1, 2, 2], [2], [2, 2]]   in any order
uniqueSubsets([5])  // [[], [5]]
uniqueSubsets([])   // [[]]
```

**Constraints:** `0 ≤ nums.count ≤ 12`; `-10 ≤ nums[i] ≤ 10`.

<!-- reveal -->

## First approach

The lesson's subsets generator on `[2, 1, 2]` produces `[2]` twice (from either 2) and `[1, 2]` twice. The duplicates come from treating equal values at different positions as different choices. If equal values sit next to each other and you agree to always use them **from left to right**, each distinct subset has only one way to be built.

## Naive solution

Generate every subset by position and let a `Set` keep one copy of each:

```swift
func uniqueSubsets(_ nums: [Int]) -> [[Int]] {
    let sorted = nums.sorted()
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    for selection in 0..<(1 << sorted.count) {
        var subset: [Int] = []
        for index in sorted.indices where selection & (1 << index) != 0 {
            subset.append(sorted[index])
        }
        if seen.insert(subset).inserted {
            results.append(subset)
        }
    }
    return results
}
```

Sorting first matters even here: it makes `[1, 2]` and `[2, 1]` the same array, so the `Set` recognizes them.

## Problems with the naive solution

It always does 2ⁿ iterations, even when the answer is tiny: twelve copies of the same value have 13 distinct subsets, and this still builds 4,096. The `Set` stores a second copy of every result and hashes whole arrays. The output is right, but the work is proportional to the positions, not to the answer.

## Optimized solution

Sort, then run the backtracking generator. At each level, the loop picks the next element to add. If `sorted[i]` equals `sorted[i - 1]` and `i` isn't the first option at this level (`i > start`), skip it: choosing it would build exactly what choosing `sorted[i - 1]` already built. Deeper levels can still pick it, which is how `[2, 2]` gets made.

## Line by line

- `let sorted = nums.sorted()`: equal values become neighbors, and each subset comes out in ascending order.
- `results.append(current)`: every node of the search is a subset, including the empty one at the root.
- `for i in start..<sorted.count`: only elements after the last one chosen, as in the lesson.
- `if i > start && sorted[i] == sorted[i - 1] { continue }`: the skip rule. `i > start` is the important half: at `i == start` this is the first time this level sees the value, so it's allowed even if the previous element (chosen at the level above) is equal.
- `current.append(sorted[i])`, `explore(from: i + 1)`, `current.removeLast()`: choose, explore, unchoose.

## Common mistakes

- Writing the condition as `i > 0` instead of `i > start`. That forbids `[2, 2]`, because the second 2 is always skipped, even when the first 2 was chosen one level up.
- Forgetting to sort. Without it, equal values aren't adjacent, and comparing with `sorted[i - 1]` misses them.
- Deduplicating with a `Set<[Int]>` at the end. It works, but it hides the real fix and still does all 2ⁿ work.

## Variation

**Iterative:** start with `[[]]`. For each value, extend every existing subset by it. When the value repeats the previous one, extend only the subsets added in the previous round, because extending the older ones would recreate subsets that already exist.
