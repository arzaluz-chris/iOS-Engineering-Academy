---
id: three-sum
title: Three Sum
difficulty: medium
order: 13
patterns: [Two pointers, Sorting, Skipping duplicates]
prerequisites: [m07, m15, m16-l03]
summary: Every distinct triple that adds up to zero. Sort once, fix one value, and the rest is Two Sum on a sorted list, plus careful duplicate handling.
solutionFile: ThreeSum.swift
testFile: ThreeSumTests.swift
starter: |
  func threeSum(_ nums: [Int]) -> [[Int]] {
      // Your solution
      return []
  }
time: O(n²)
space: O(n) for the sorted copy
edgeCases:
  - Fewer than three elements
  - Many copies of the same value, like [0, 0, 0, 0]
  - All values positive, or all negative
  - Triples that use two copies of the same value, like [-2, -2, 4]
askInterviewer:
  - Do I return values or indices?
  - Should duplicate triples be removed? What makes two triples the same?
  - In what order should the triples come out?
  - Can I sort the input, or a copy of it?
hints:
  - "If you fix the smallest value of the triple, what problem is left for the other two?"
  - "Sort first. Then, for each fixed value, the other two are a Two Sum on the sorted part to its right, with converging pointers."
  - "Duplicates appear when the fixed value repeats, or when the left pointer lands on a value it just used. Skip both."
followUps:
  - How would you count the triples instead of listing them?
  - What about four values (Four Sum)? What's the cost?
  - "\"Three Sum Closest\": the triple whose sum is nearest to a target. What changes in the loop?"
rubric:
  - I proposed the O(n³) version and explained why it's too slow.
  - I sorted and reduced the problem to a sorted Two Sum for each fixed value.
  - I skipped duplicates at the fixed position and at the left pointer, without a Set.
  - I stated O(n²) time and mentioned the sorting cost and the copy.
codeStatus: tested
---

A banking app flags groups of three transactions that cancel out exactly. Given a list of integers `nums`, return every **distinct** triple of values `[a, b, c]` taken from three different positions with `a + b + c == 0`. Write each triple in ascending order, and return the list sorted (compare the first values, then the second, then the third). Two triples with the same values count once.

Write `threeSum(_ nums: [Int]) -> [[Int]]`.

```swift
threeSum([3, -1, -2, 0, 1, -1])  // [[-2, -1, 3], [-1, 0, 1]]
threeSum([1, 2, -4])             // []
threeSum([0, 0, 0, 0])           // [[0, 0, 0]]
```

**Constraints:** `0 ≤ nums.count ≤ 3000`; `-10^5 ≤ nums[i] ≤ 10^5`.

<!-- reveal -->

## First approach

Three nested loops would find everything, but you can do better by fixing one value. If the triple is written in ascending order and its first value is `a`, the other two must add up to `-a`, and they come from the values after `a` in sorted order. That's a sorted Two Sum, which converging pointers solve in O(n). Doing it for each `a` gives O(n²).

## Naive solution

Try every triple of positions and let a `Set` remove repeats:

```swift
func threeSum(_ nums: [Int]) -> [[Int]] {
    var found = Set<[Int]>()
    for i in nums.indices {
        for j in (i + 1)..<nums.count {
            for k in (j + 1)..<nums.count where nums[i] + nums[j] + nums[k] == 0 {
                found.insert([nums[i], nums[j], nums[k]].sorted())
            }
        }
    }
    return found.sorted { $0.lexicographicallyPrecedes($1) }
}
```

## Problems with the naive solution

It checks n·(n − 1)·(n − 2)/6 triples: **O(n³)**, about 4.5·10^9 for 3000 elements. The `Set` hides the duplicate problem rather than solving it, and on an input like 3000 zeros it does billions of inserts of the same triple.

## Optimized solution

Sort a copy. For each index `first`, skip it if its value repeats the previous one (that value's triples were already found), and stop once the value is positive (three positives can't sum to 0). Run converging pointers on the part after `first`. When a triple matches, record it, move both pointers, and push `left` past any copies of the value it just used.

Because `first` only increases, and for each `first` the left value only increases, the triples come out already sorted.

## Line by line

- `let sorted = nums.sorted()`: O(n log n), dominated by the O(n²) loop. It also makes each triple come out in ascending order.
- `if first > 0 && sorted[first] == sorted[first - 1] { continue }`: the same fixed value would find the same triples again. The `first > 0` check comes first so index −1 is never read.
- `if sorted[first] > 0 { break }`: everything to the right is at least as big, so no sum can reach 0. It's an optimization, not needed for correctness.
- `var left = first + 1`, `var right = sorted.count - 1`: Two Sum on `sorted[(first + 1)...]` with target `-sorted[first]`, written as "sum of all three compared with 0".
- `sum < 0` moves `left` up; `sum > 0` moves `right` down. Same reasoning as in Two Sum II: the discarded element can't be in any remaining triple with this `first`.
- On a match: append, move both pointers, then `while left < right && sorted[left] == sorted[left - 1] { left += 1 }` skips copies of the value just used. `right` doesn't need its own skip: with `first` fixed and a bigger left value, a matching right value has to be smaller, so it can't repeat the triple.

## Common mistakes

- Skipping duplicates with `sorted[first] == sorted[first + 1]` instead of comparing with the previous element. That skips the first copy of a value, and loses triples like `[-2, -2, 4]` that need two copies.
- Not moving the pointers after a match, which loops forever.
- Deduplicating with a `Set<[Int]>` and then sorting the output. It works, but it costs extra memory and doesn't show that you understand where the duplicates come from.

## Variation

**Three Sum Closest:** return the sum of the triple closest to a target. Same loops, no duplicate skipping needed; track the sum with the smallest `abs(sum - target)` and move the pointers by comparing `sum` with `target`.
