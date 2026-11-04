---
id: number-of-longest-increasing-subsequences
title: Number of Longest Increasing Subsequences
difficulty: medium
order: 85
patterns: [1-D dynamic programming, Counting alongside optimizing]
prerequisites: [m20-l06]
summary: Count how many increasing subsequences reach the maximum length. The LIS table with a second array that counts the ways to reach each best.
solutionFile: NumberOfLongestIncreasingSubsequences.swift
testFile: NumberOfLongestIncreasingSubsequencesTests.swift
starter: |
  func countLongestIncreasing(_ nums: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n²)
space: O(n)
edgeCases:
  - An empty array (0) and a single element (1)
  - All values equal, where every element alone is a longest subsequence
  - A strictly decreasing array
  - A strictly increasing array, with exactly one answer
  - Repeated values, which can't extend each other
askInterviewer:
  - Strictly increasing, or is non-decreasing allowed?
  - Are two subsequences with the same values but different positions different?
  - What should an empty array return?
  - Can the count get huge? Do you want it modulo something?
hints:
  - Start from the longest increasing subsequence table, where length[i] is the best length ending at index i.
  - Next to length[i], keep count[i], the number of subsequences of that length that end at i. When an earlier j gives length[j] + 1, what do you do if that's longer than length[i]? If it's equal?
  - The answer adds up count[i] over every i whose length is the overall maximum, not just the last one.
followUps:
  - Can you do it in O(n log n)? (Yes, with a segment tree or Fenwick tree over values that stores (best length, count) pairs.)
  - Return one of the longest subsequences.
  - What changes if equal values may be adjacent (non-decreasing)?
rubric:
  - I defined length[i] and count[i] for subsequences ending at i.
  - I handled the two cases correctly, a longer length resets the count and an equal length adds to it.
  - I summed the counts over every index with the maximum length.
  - I gave O(n²) time and O(n) space and tested duplicates and a decreasing array.
codeStatus: tested
---

A stock app shows a list of daily closing prices. For a "momentum" badge it needs to know how many ways the prices contain a longest strictly increasing run that skips days (a **subsequence**: elements in their original order, not necessarily next to each other). Given `nums`, return how many strictly increasing subsequences have the maximum possible length. Two subsequences are different if they use different positions, even if the values are the same.

```swift
countLongestIncreasing([3, 1, 4, 2, 5])   // 3: [3, 4, 5], [1, 4, 5] and [1, 2, 5]
countLongestIncreasing([2, 6, 4, 8])      // 2: [2, 6, 8] and [2, 4, 8]
countLongestIncreasing([7, 7, 7])         // 3: each 7 on its own
```

An empty array returns 0.

**Constraints:** `0 ≤ nums.count ≤ 2,000`; `-10^6 ≤ nums[i] ≤ 10^6`. The answer fits in an `Int` for the inputs tested.

<!-- reveal -->

## First approach

Module 20, lesson 6 found the length: `length[i] = 1 + max(length[j])` over `j < i` with `nums[j] < nums[i]`. Counting needs one more fact per index: how many subsequences reach that best length at `i`. Every longest subsequence ending at `i` is a longest subsequence ending at some `j` with one more element, so the count at `i` is the sum of the counts at the `j`s that achieve the best length.

## Naive solution

Check every subset of positions, keep the increasing ones, and count those of the maximum length:

```swift
func countLongestIncreasing(_ nums: [Int]) -> Int {
    var bestLength = 0
    var bestCount = 0
    if nums.isEmpty { return 0 }
    for mask in 1..<(1 << nums.count) {
        var previous: Int?
        var length = 0
        var isIncreasing = true
        for index in nums.indices where mask & (1 << index) != 0 {
            if let previous, nums[index] <= previous {
                isIncreasing = false
                break
            }
            previous = nums[index]
            length += 1
        }
        guard isIncreasing else { continue }
        if length > bestLength {
            bestLength = length
            bestCount = 1
        } else if length == bestLength {
            bestCount += 1
        }
    }
    return bestCount
}
```

## Problems with the naive solution

2ⁿ subsets with an O(n) check each. Twenty elements is a million subsets; 2,000 is impossible. It does count exactly what the problem asks, positions and all, which makes it a good oracle for random tests.

## Optimized solution

Keep two arrays. `length[i]` is the length of the longest increasing subsequence ending at `i`, and `count[i]` how many of that length end there. Both start at 1 (the element alone). For each `i`, look at every earlier `j` with a smaller value. If `length[j] + 1` beats `length[i]`, you found a longer way to end at `i`: take `length[j] + 1` and **replace** the count with `count[j]`. If it ties, you found more ways of the same length: **add** `count[j]`. At the end, add up `count[i]` over every `i` whose `length[i]` is the maximum.

## Line by line

- `guard !nums.isEmpty else { return 0 }`: no subsequences, and `length.max()!` below would trap.
- `var length = Array(repeating: 1, count: nums.count)` and `var count = ...`: every element alone is an increasing subsequence of length 1, and there's one of it.
- `for j in 0..<i where nums[j] < nums[i]`: strictly smaller, so equal values never extend each other.
- `if length[j] + 1 > length[i]`: a longer subsequence ending at `i`. The ways counted so far were for a shorter length, so they're thrown away: `count[i] = count[j]`.
- `else if length[j] + 1 == length[i]`: another set of subsequences of the same best length: `count[i] += count[j]`.
- `let longest = length.max()!`: the overall best length. Safe because the array isn't empty.
- The final loop adds `count[i]` for every `i` that reaches `longest`, because a longest subsequence can end anywhere.

## Common mistakes

- Adding `count[j]` in the "longer" case instead of replacing. The old counts were for a length that's no longer the best.
- Returning `count[n - 1]` or `count` at the index of the first maximum. On `[2, 6, 4, 8]` both longest subsequences end at the last index, but on `[1, 3, 2]` they end at different ones.
- Using `<=` in the comparison and counting `[7, 7]` as increasing.
- Counting distinct value sequences when the problem counts positions, or the other way around. Ask.

## Variation

**Return one longest subsequence:** keep a `previous[i]` index next to `length[i]`, set whenever the length improves. Start from any index with the maximum length and follow `previous` back, then reverse. Same O(n²) time.
