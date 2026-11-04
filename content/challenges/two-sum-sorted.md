---
id: two-sum-sorted
title: Two Sum II (Sorted Input)
difficulty: easy
order: 12
patterns: [Two pointers, Converging pointers]
prerequisites: [m07, m15, m16-l03]
summary: Find two values that add up to a target when the list is sorted. Sorting is the information that lets you skip memory entirely.
solutionFile: TwoSumSorted.swift
testFile: TwoSumSortedTests.swift
starter: |
  func twoSumSorted(_ sorted: [Int], _ target: Int) -> (first: Int, second: Int)? {
      // Your solution
      return nil
  }
time: O(n)
space: O(1)
edgeCases:
  - Two equal values that form the pair, like [5, 5] with 10
  - A value that's half the target but appears only once
  - Empty and one-element lists
  - The pair at the very ends of the list
  - No pair at all
askInterviewer:
  - Is the list sorted ascending, and can values repeat?
  - Are indices 0-based?
  - If several pairs work, does it matter which one I return?
  - Is there a memory limit?
hints:
  - "Look at the smallest and the largest value. If their sum is too small, can the smallest value be part of any pair that works?"
  - "Each comparison lets you throw away one end of the list for good. Which end, in each case?"
  - "Stop when the two indices meet: an element can't pair with itself."
followUps:
  - How would you return every distinct pair of values instead of one?
  - Why is this O(n) and not O(n log n), given that the input is sorted?
  - "How does this become the inner loop of Three Sum?"
rubric:
  - I used the sorted order instead of extra memory.
  - I explained why moving each pointer can't skip a valid pair.
  - The loop condition was left < right, so an element never pairs with itself.
  - I handled the no-solution case.
codeStatus: tested
---

A gift-card screen lists prices sorted from cheapest to most expensive. Find two **different** items whose prices add up to exactly the card's value.

Write `twoSumSorted(_ sorted: [Int], _ target: Int) -> (first: Int, second: Int)?` that returns the 0-based indices of two elements, with `first < second`, whose values add up to `target`, or `nil` if there aren't any. If several pairs work, return any one of them. Use **O(1) extra memory**.

```swift
twoSumSorted([1, 4, 6, 9, 12], 15)  // (2, 3): 6 + 9
twoSumSorted([-5, -2, 0, 3], -7)    // (0, 1)
twoSumSorted([1, 5, 5, 7], 10)      // (1, 2): the two 5s are different items
twoSumSorted([2, 3, 8], 4)          // nil
```

**Constraints:** `0 ≤ sorted.count ≤ 3·10^4`; `sorted` is in non-decreasing order; `-10^9 ≤ sorted[i], target ≤ 10^9`.

<!-- reveal -->

## First approach

The memory limit rules out remembering what you've seen, so the sorted order has to do the work. Put one index at each end. The sum of the two ends tells you which one can't be part of any answer: too small means the left value is too small even with the biggest partner available; too big means the right value is too big even with the smallest.

## Naive solution

Try every pair:

```swift
func twoSumSorted(_ sorted: [Int], _ target: Int) -> (first: Int, second: Int)? {
    for i in sorted.indices {
        for j in (i + 1)..<sorted.count where sorted[i] + sorted[j] == target {
            return (i, j)
        }
    }
    return nil
}
```

## Problems with the naive solution

It's **O(n²)**: 3·10^4 elements means about 4.5·10^8 pairs. It ignores the one piece of information the problem gives you, the order. A binary search for each element's partner uses the order and gets to O(n log n) with O(1) memory, which is a reasonable middle step to mention.

## Optimized solution

Start with `left` at 0 and `right` at the last index. While `left < right`, compare the sum with the target: equal means done; smaller means move `left` forward; bigger means move `right` back. Each step discards one element for good, so there are at most n − 1 steps.

## Line by line

- `var right = sorted.count - 1`: for an empty list this is −1, `left < right` is false, and the function returns `nil` without reading anything.
- `while left < right`: the two indices must be different positions. When they meet, every pair has been ruled out.
- `if sum == target { return (left, right) }`: `left < right` holds inside the loop, so the order in the result is right.
- `else if sum < target { left += 1 }`: `sorted[right]` is the largest value still available. If even it isn't enough for `sorted[left]`, no partner of `sorted[left]` is, so `left` can be discarded.
- `else { right -= 1 }`: the mirror case. `sorted[left]` is the smallest value available, and even it makes the sum too big for `sorted[right]`.
- The sum of two values within ±10^9 is at most 2·10^9 in absolute value, far from `Int`'s limits on 64-bit platforms.

## Common mistakes

- Writing `while left <= right`, which can pair an element with itself: `[5]` with target 10 would return `(0, 0)`.
- Moving both pointers after a mismatch, which can skip the answer.
- Reaching for a dictionary out of habit. It works, but it spends O(n) memory the problem asked you not to use.

## Variation

**Two Sum, sorted, count all pairs:** return how many pairs `i < j` add up to the target. When the sum matches, you can't just move one pointer: if values repeat, count the run of equal values at each end (or, when `sorted[left] == sorted[right]`, every pair inside the run, k·(k − 1)/2) before moving on.
