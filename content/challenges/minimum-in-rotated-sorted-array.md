---
id: minimum-in-rotated-sorted-array
title: Minimum in a Rotated Sorted Array
difficulty: medium
order: 47
patterns: [Binary search, Boundary search]
prerequisites: [m16-l02]
summary: A sorted list got rotated by an unknown amount. Find its smallest value in O(log n) by comparing against the last element.
solutionFile: MinimumInRotatedArray.swift
testFile: MinimumInRotatedArrayTests.swift
starter: |
  func minimumInRotatedArray(_ nums: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(log n)
space: O(1)
edgeCases:
  - Not rotated at all (or rotated by its full length)
  - A single element, and two elements in either order
  - Minimum in the last position
  - Negative values
askInterviewer:
  - Are the values distinct? (With duplicates the worst case becomes O(n).)
  - Is the list guaranteed to be non-empty?
  - Do I return the value or its index?
hints:
  - Draw the values as a line chart. What shape does a rotated sorted list have?
  - Compare an element with the last one. What does "bigger than the last element" tell you about which part it's in?
  - '"nums[i] <= nums.last" is false for the first part and true for the second. Find where it switches.'
followUps:
  - What if values can repeat? Why can't binary search always decide which half to drop?
  - How do you return the number of positions the list was rotated by? (It's the index of the minimum.)
  - Why compare with the last element and not the first?
rubric:
  - I described the two sorted runs and why the minimum starts the second one.
  - I phrased the search as a boundary over a monotonic condition.
  - I handled the case where the list isn't rotated.
  - I stated O(log n) time, O(1) space, and the distinct-values assumption.
codeStatus: tested
---

A music app keeps a playlist's song IDs sorted, but a sync bug moved the first few to the end: some prefix was cut off and appended. Write `minimumInRotatedArray(_:)` that returns the smallest value. The values are distinct, and the list may also not have been rotated at all.

```swift
minimumInRotatedArray([40, 55, 70, 5, 12, 33])  // 5
minimumInRotatedArray([8, 1, 3, 4])             // 1
minimumInRotatedArray([2, 4, 6, 9])             // 2, not rotated
```

**Constraints:** `1 ≤ nums.count ≤ 10^5`; values are distinct.

<!-- reveal -->

## First approach

A rotated sorted list is two sorted runs: a left run of big values, then a right run of small values that starts with the minimum. Every value in the left run is greater than the last element of the list, and every value in the right run is less than or equal to it. So "is `nums[i] <= nums.last`?" is false and then true, and the minimum sits exactly at the switch.

## Naive solution

```swift
func minimumInRotatedArray(_ nums: [Int]) -> Int {
    nums.min()!
}
```

## Problems with the naive solution

`min()` looks at all n elements: **O(n)**. It throws away the fact that the list is almost sorted. In an interview this is the answer to mention in one sentence and move past, because "rotated sorted" is a strong hint that O(log n) is expected.

## Optimized solution

Binary search for the first index whose value is `<= nums.last`. When `nums[mid]` is bigger than the last element, `mid` is in the left run and the minimum is to its right. Otherwise `mid` is in the right run, and the minimum is at `mid` or before it.

## Line by line

- `precondition(!nums.isEmpty, ...)`: there's no minimum of an empty list.
- `let last = nums[nums.count - 1]`: the reference point. It always belongs to the right run.
- `var high = nums.count - 1`: the last index always satisfies the condition, so it can be the fallback answer. The search is over `low..<high` plus that guaranteed answer.
- `if nums[mid] > last { low = mid + 1 }`: `mid` is in the left run; the minimum is strictly after it.
- `else { high = mid }`: `mid` is in the right run, so it might be the minimum.
- `return nums[low]`: `low` is the first index of the right run. If the list wasn't rotated, every element is `<= last`, and `low` ends at 0.

## Common mistakes

- Comparing with `nums[0]` instead of the last element. For an unrotated list, every element is `>= nums[0]`, so you can't tell "unrotated" from "minimum is far right" without a special case.
- Writing `high = mid - 1` in the else branch, which can skip the minimum when it's at `mid`.
- Assuming the values are distinct without asking. With `[3, 3, 1, 3]`, `nums[mid] == last` says nothing about which side the minimum is on.

## Variation

**Find Minimum in Rotated Sorted Array II** (duplicates allowed): when `nums[mid] == nums[high]`, you can't drop either half, but you can drop `high` itself, because `nums[mid]` holds the same value. Do `high -= 1` in that case. Worst case O(n), for a list of all-equal values with one smaller one hidden somewhere.
