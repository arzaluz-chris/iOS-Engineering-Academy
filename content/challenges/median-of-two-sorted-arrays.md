---
id: median-of-two-sorted-arrays
title: Median of Two Sorted Arrays
difficulty: hard
order: 50
patterns: [Binary search on a partition, Boundary search]
prerequisites: [m16-l02, m18-l05]
summary: Find the median of two sorted arrays without merging them. Binary search on how many elements the shorter array puts in the left half.
solutionFile: MedianOfSortedArrays.swift
testFile: MedianOfSortedArraysTests.swift
starter: |
  func medianOfSortedArrays(_ first: [Int], _ second: [Int]) -> Double {
      // Your solution
      return 0
  }
time: O(log min(m, n))
space: O(1)
edgeCases:
  - One array empty
  - Every value of one array smaller than every value of the other
  - Odd and even total counts
  - Repeated values, inside an array and across both
askInterviewer:
  - Can one of the arrays be empty? Can both?
  - For an even count, is the median the average of the two middle values, and as a Double?
  - Can values repeat?
  - How large can the arrays get? Is O(m + n) good enough, or do you want logarithmic?
hints:
  - The median splits all the values into a left half and a right half of equal size (or one more on the left). How many values go on the left?
  - If the left half takes i values from the first array, how many does it take from the second?
  - A split is right when the largest value on the left is no bigger than the smallest on the right. Which comparison tells you whether i is too small or too large?
followUps:
  - Generalize to the k-th smallest value of two sorted arrays.
  - Why search the shorter array? What breaks if you search the longer one?
  - What would you do with k sorted arrays? (A heap gives the k-th smallest in O(k log k).)
rubric:
  - I explained the O(m + n) merge first and why it isn't the expected answer.
  - I described the partition (i from one array, leftSize - i from the other) and the condition for a correct split.
  - I searched the shorter array and handled the edges of the arrays with sentinels.
  - I computed the median for both odd and even totals and gave O(log min(m, n)).
codeStatus: tested
---

Two servers each report a sorted list of response times in milliseconds. Write `medianOfSortedArrays(_:_:)` that returns the median of all the values together, as a `Double`. With an odd total, the median is the middle value; with an even total, it's the average of the two middle values.

```swift
medianOfSortedArrays([1, 4, 9], [2, 3])  // 3.0: all values are 1, 2, 3, 4, 9
medianOfSortedArrays([10, 20], [15, 40]) // 17.5: the middle two are 15 and 20
medianOfSortedArrays([], [6])            // 6.0
```

**Constraints:** `0 ≤ m, n ≤ 10^5` with `m + n ≥ 1`; `-10^6 ≤` values `≤ 10^6`; both arrays are sorted ascending. Aim for better than O(m + n).

<!-- reveal -->

## First approach

The median doesn't need the merged array, only the place where it would be cut in two. Say the left half has `leftSize = (m + n + 1) / 2` values. If it takes `i` of them from the shorter array `a`, it takes `j = leftSize - i` from `b`. That cut is correct when nothing on the left is bigger than anything on the right: `a[i - 1] <= b[j]` and `b[j - 1] <= a[i]`. Only one number is unknown, `i`, and you can binary search for it.

## Naive solution

Merge, as in merge sort, and read the middle:

```swift
func medianOfSortedArrays(_ first: [Int], _ second: [Int]) -> Double {
    var merged: [Int] = []
    var i = 0
    var j = 0
    while i < first.count || j < second.count {
        if j == second.count || (i < first.count && first[i] <= second[j]) {
            merged.append(first[i])
            i += 1
        } else {
            merged.append(second[j])
            j += 1
        }
    }
    let middle = merged.count / 2
    if merged.count % 2 == 1 {
        return Double(merged[middle])
    }
    return (Double(merged[middle - 1]) + Double(merged[middle])) / 2
}
```

## Problems with the naive solution

It's **O(m + n)** time and memory. You can drop the memory to O(1) by only counting up to the middle instead of storing the merge, but the time stays linear. That's a perfectly good answer for most real code. In an interview for this problem, though, logarithmic time is the explicit goal.

## Optimized solution

Search over `i` in `0...a.count`, where `a` is the shorter array. The condition `a[i] >= b[j - 1]` ("taking `i` from `a` is already enough") is false for small `i` and true from some `i` on: as `i` grows, `a[i]` grows and `b[j - 1]` shrinks. The first `i` where it's true is the correct split. Then the median comes from the largest value on the left and, for an even total, the smallest on the right.

## Line by line

- `let (a, b) = first.count <= second.count ? (first, second) : (second, first)`: search the shorter one. That keeps `j` between 0 and `b.count` for every `i` in `0...a.count`, so no index goes out of range, and the search takes log of the shorter length.
- `let leftSize = (total + 1) / 2`: for an odd total, the left half gets the extra value, so the median is simply the left half's maximum.
- `var low = 0` and `var high = a.count`: `i = a.count` (take all of `a`) always satisfies the condition, so it's the fallback.
- `if a[mid] >= b[leftSize - mid - 1]`: inside the loop `mid < a.count`, so `a[mid]` exists, and `j = leftSize - mid >= 1`, so `b[j - 1]` exists. True means `mid` might be the split: `high = mid`. False means the left half needs more of `a`: `low = mid + 1`.
- After the loop, `i = low`: the first `i` for which `a[i] >= b[j - 1]`. Because `i - 1` failed the condition, `a[i - 1] < b[j]`, so both halves of the correctness check hold.
- `let leftMax = max(i > 0 ? a[i - 1] : Int.min, j > 0 ? b[j - 1] : Int.min)`: when one side contributes nothing to the left half, `Int.min` stands in for "no value" and never wins the `max`.
- `if total % 2 == 1 { return Double(leftMax) }`: odd total, the left half's largest value is the median.
- `let rightMin = min(...)` with `Int.max` as the sentinel, and `return (Double(leftMax) + Double(rightMin)) / 2`: even total, average the two middle values. Converting before adding avoids overflow even for extreme values.

## Common mistakes

- Searching the longer array. Then `j = leftSize - i` can be negative or larger than `b.count`, and the code reads out of bounds.
- Averaging with integer division, `(leftMax + rightMin) / 2`, which turns 17.5 into 17.
- Forgetting the empty sides: `a[i - 1]` when `i == 0`, or `b[j]` when `j == b.count`. The sentinels handle all four edges.
- Using `leftSize = total / 2` and then forgetting that for an odd total the median is on the **right** side. Either choice works; the code has to agree with it.

## Variation

**K-th smallest of two sorted arrays:** the same partition idea with `leftSize = k`. The search range for `i` becomes `max(0, k - b.count)...min(k, a.count)`, because neither array can contribute more than it has. The median is the special case `k = (m + n + 1) / 2`, plus the next value for an even total.
