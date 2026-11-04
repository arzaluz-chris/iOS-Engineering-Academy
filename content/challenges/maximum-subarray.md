---
id: maximum-subarray
title: Maximum Subarray
difficulty: medium
order: 94
patterns: [Kadane's algorithm, 1-D dynamic programming]
prerequisites: [m20-l01, m20-l04]
summary: Find the best run of consecutive days in a list of gains and losses. Kadane's algorithm, where each step decides to extend the run or start over.
solutionFile: MaximumSubarray.swift
testFile: MaximumSubarrayTests.swift
starter: |
  func maximumSubarraySum(_ nums: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1) extra
edgeCases:
  - A single element, positive or negative
  - All negative values, where the answer is the largest single value
  - All positive values, where the answer is the whole array
  - Zeros
  - A deep dip between two good runs
askInterviewer:
  - Must the run be non-empty? (If empty runs are allowed, the answer is never below 0.)
  - Do you want the sum, or the start and end of the run as well?
  - How large can values and the array get? Can the sum overflow?
hints:
  - Fix the end of the run at index i. What's the best sum of a run that ends exactly there?
  - The best run ending at i either is just nums[i], or extends the best run ending at i - 1. When is starting over better?
  - The answer is the best over all ends, so keep a second variable for that.
followUps:
  - Return the start and end indices of the best run.
  - What if the array is circular, so a run can wrap from the end to the start?
  - What about the maximum product of a run? (Track both the largest and smallest product ending at i.)
rubric:
  - I wrote the O(n²) brute force with running sums.
  - I defined the best sum ending at i and its recurrence max(nums[i], previous + nums[i]).
  - I initialized with the first element so all-negative arrays work.
  - I gave O(n) time and O(1) space.
codeStatus: tested
---

A creator dashboard shows the net change in followers for each day. To highlight the best stretch, it needs the largest sum of a run of **consecutive** days. Given a non-empty array `nums`, return the largest sum of any non-empty run of consecutive elements.

```swift
maximumSubarraySum([-3, 5, -1, 4, -10, 2])  // 8: 5, -1, 4
maximumSubarraySum([-4, -2, -7])            // -2: a single day, the least bad
maximumSubarraySum([2, -1, 2])              // 3: the whole array
```

**Constraints:** `1 ≤ nums.count ≤ 10^5`; `-10^4 ≤ nums[i] ≤ 10^4`.

<!-- reveal -->

## First approach

Every run ends somewhere. Fix the end at `i` and ask for the best run that ends exactly there. That run either is `nums[i]` alone or is the best run ending at `i - 1` with `nums[i]` added. Extending only helps if the earlier run's sum is positive; a negative prefix is dead weight. That one-variable recurrence is a tiny DP (Module 20, lesson 4), and the "drop a negative prefix" rule is a greedy choice with a clean argument (lesson 1).

## Naive solution

Try every start and extend the run one element at a time, keeping a running sum:

```swift
func maximumSubarraySum(_ nums: [Int]) -> Int {
    var best = nums[0]
    for start in nums.indices {
        var sum = 0
        for end in start..<nums.count {
            sum += nums[end]
            best = max(best, sum)
        }
    }
    return best
}
```

## Problems with the naive solution

n starts and up to n ends: O(n²), around 5 · 10^9 additions for 10^5 elements. (The version that re-adds each run from scratch is O(n³).) The waste: the inner loop for `start + 1` recomputes sums that only differ from the previous loop's by one element.

## Optimized solution

Keep `bestEndingHere`, the best sum of a run ending at the current element, and `best`, the best seen anywhere. Start both at `nums[0]`. For each later value, `bestEndingHere = max(value, bestEndingHere + value)`, then update `best`. This is **Kadane's algorithm**.

## Line by line

- `precondition(!nums.isEmpty, ...)`: the problem guarantees at least one element; the precondition documents it and fails loudly instead of returning a made-up value.
- `var bestEndingHere = nums[0]` and `var best = nums[0]`: the only run ending at index 0 is the element itself. Starting at 0 instead would return 0 for `[-4, -2, -7]`.
- `for value in nums.dropFirst()`: `dropFirst()` returns a slice without copying.
- `bestEndingHere = max(value, bestEndingHere + value)`: start a new run here, or extend the previous one. The new run wins exactly when `bestEndingHere` was negative.
- `best = max(best, bestEndingHere)`: the best run can end anywhere.

## Common mistakes

- Initializing `best` to 0, which is wrong for all-negative arrays when the run must be non-empty.
- Resetting the running sum to 0 when it goes negative and only then updating `best`. On an all-negative array that returns 0. Writing the step as the `max` above avoids the ordering question.
- Using sliding-window logic (shrink while the sum is negative) on a problem where values are negative and there's no fixed target.

## Variation

**Circular array:** a run may wrap from the end to the start. The best wrapping run is the total minus the worst (minimum-sum) non-wrapping run, which Kadane finds with `min` instead of `max`. Take the larger of the two answers, except when every value is negative, where the wrapping candidate would be the empty run.
