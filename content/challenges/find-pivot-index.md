---
id: find-pivot-index
title: Find Pivot Index
difficulty: easy
order: 22
patterns: [Prefix sums, Running total]
prerequisites: [m07, m15, m16-l06]
summary: Find the position where everything on the left sums to everything on the right. One total, one running sum, no prefix array needed.
solutionFile: FindPivotIndex.swift
testFile: FindPivotIndexTests.swift
starter: |
  func balanceIndex(_ values: [Int]) -> Int? {
      // Your solution
      return nil
  }
time: O(n)
space: O(1)
edgeCases:
  - Empty list
  - A single element, whose two sides are both empty
  - The answer at the first or last index
  - Several balance points, where the first one wins
  - Negative values
askInterviewer:
  - Is the element at the index itself excluded from both sides?
  - What does an empty side sum to?
  - If there are several answers, which one do I return?
  - Can values be negative?
hints:
  - "For each index, the left sum is a prefix sum. What's the right sum, if you know the total?"
  - "The right side of index i sums to total − leftSum − values[i]."
  - "You don't need a prefix array: one running sum for the left side, updated after the check, is enough."
followUps:
  - How would you return every balance point?
  - What if the left side should be twice the right side?
  - "How does this relate to the prefix array formula sum(l..<r) = prefix[r] − prefix[l]?"
rubric:
  - I expressed the right sum in terms of the total and the running left sum.
  - I updated the left sum after the check, so the element at the index belongs to neither side.
  - I handled the empty list and a single element.
  - I stated O(n) time and O(1) space and compared with the O(n²) version.
codeStatus: tested
---

A seesaw game puts weights in a row, and the player picks one position as the pivot. The pivot works when the weights strictly to its left add up to the same total as the weights strictly to its right; the weight at the pivot belongs to neither side, and an empty side weighs 0. Weights can be negative (they're helium balloons).

Write `balanceIndex(_ values: [Int]) -> Int?` that returns the **smallest** index that works, or `nil` if none does.

```swift
balanceIndex([2, 7, 1, 3, 6])  // 2: 2 + 7 = 3 + 6
balanceIndex([1, 2, 3])        // nil
balanceIndex([5, -3, 3])       // 0: the left side is empty, and −3 + 3 = 0
balanceIndex([42])             // 0: both sides are empty
```

**Constraints:** `0 ≤ values.count ≤ 10^4`; `-1000 ≤ values[i] ≤ 1000`.

<!-- reveal -->

## First approach

The left side of index `i` is a prefix sum. The right side is everything else except `values[i]`, so with the total in hand it's `total − leftSum − values[i]`. One pass to compute the total, one pass carrying the left sum, and each index is checked in O(1).

## Naive solution

For each index, add up both sides from scratch:

```swift
func balanceIndex(_ values: [Int]) -> Int? {
    for index in values.indices {
        let leftSum = values[..<index].reduce(0, +)
        let rightSum = values[(index + 1)...].reduce(0, +)
        if leftSum == rightSum {
            return index
        }
    }
    return nil
}
```

## Problems with the naive solution

Each index sums n − 1 elements: **O(n²)**, about 10^8 additions for 10^4 weights. The left sum for index `i + 1` is the left sum for `i` plus one element; recomputing it each time is the waste.

## Optimized solution

Compute the total once. Walk the indices with `leftSum`, the sum of everything before the current index. If `leftSum` equals `total − leftSum − value`, that index is the answer. Otherwise add `value` to `leftSum` and move on. It's the prefix array from the lesson, reduced to the one entry you need at each step.

## Line by line

- `let total = values.reduce(0, +)`: one O(n) pass. For an empty list it's 0, and the loop below doesn't run, so the result is `nil`.
- `for (index, value) in values.enumerated()`: index and value together, as in Two Sum.
- `if leftSum == total - leftSum - value`: the right side is the total minus the left side minus the pivot itself.
- `leftSum += value` **after** the check: at the moment of the check, `leftSum` must exclude the current element.
- Returning on the first match gives the smallest index.
- **O(n) time, O(1) space.** The total is at most 10^7 in absolute value, far from overflow.

## Common mistakes

- Adding `value` to `leftSum` before the check, which puts the pivot on the left side.
- Comparing `leftSum` with `total − leftSum`, which puts the pivot on the right side.
- Building a full prefix array: correct, but O(n) extra space for something one variable does.
- Returning `-1` or `0` for "not found" in a function whose return type can express "no answer". `nil` can't be mistaken for a real index.

## Variation

**Every balance point:** don't return on the first match; append the index to an array and keep going. It's still one pass. With all-zero weights, every index is a balance point.
