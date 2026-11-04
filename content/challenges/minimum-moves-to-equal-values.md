---
id: minimum-moves-to-equal-values
title: Minimum Moves to Equal Values
difficulty: medium
order: 60
patterns: [Quickselect, Median]
prerequisites: [m18-l06]
summary: Make every value equal with as few +1 and -1 steps as possible. The target is the median, and quickselect finds it without sorting.
solutionFile: MinimumMovesToEqual.swift
testFile: MinimumMovesToEqualTests.swift
starter: |
  func minimumMovesToEqual(_ nums: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n) expected, O(n²) worst case
space: O(n) for the working copy
edgeCases:
  - Empty list and a single value
  - All values already equal, including a very long list of them
  - Even length, where any value between the two middle ones works
  - Negative values and wide ranges
askInterviewer:
  - Does a move change one value by exactly 1?
  - Does the final value have to be one of the original values? (It doesn't, but a median always is.)
  - Can I modify the input?
  - How large can the values and the list get? Can the total overflow?
hints:
  - Try a few final values by hand on [1, 2, 9]. Where is the cost lowest?
  - If more values sit above your target than below it, which way should the target move?
  - You only need the middle value, not a fully sorted list. Which algorithm from the quicksort lesson finds the k-th smallest?
followUps:
  - What if each move adds 1 to every value except one? (Then the answer is the sum minus n times the minimum.)
  - What if moving a value costs a different weight per element? (The weighted median.)
  - How do you make quickselect's worst case O(n)? (Median of medians.)
rubric:
  - I argued why the median minimizes the sum of distances, and why the mean doesn't.
  - I used quickselect to find the median in expected O(n).
  - I used a random pivot and a three-way partition, and explained what each protects against.
  - I didn't modify the caller's array.
codeStatus: tested
---

A smart thermostat system has a list of rooms with their current target temperatures, in whole degrees. Facilities want every room set to the same temperature, and each button press changes one room by one degree, up or down. Write `minimumMovesToEqual(_:)` that returns the fewest presses needed.

```swift
minimumMovesToEqual([70, 72, 68, 75])  // 9: set every room to 70 or 72 (2 + 0 + 4 + 3 at 72)
minimumMovesToEqual([1, 10, 2, 9])     // 16
minimumMovesToEqual([4])               // 0
```

**Constraints:** `0 ≤ nums.count ≤ 10^5`; `-10^9 ≤ nums[i] ≤ 10^9`. Don't modify the input.

<!-- reveal -->

## First approach

The cost of a final value `x` is the sum of `|v − x|` over every value. Move `x` one degree up: it gets 1 closer to every value above it and 1 farther from every value at or below it. So while more values are above `x` than below, moving up helps, and it stops helping at the middle. The best `x` is a **median**. You don't need the list sorted, only its middle element, which is what quickselect finds.

## Naive solution

Try every value in the list as the target:

```swift
func minimumMovesToEqual(_ nums: [Int]) -> Int {
    var best: Int?
    for candidate in nums {
        var moves = 0
        for value in nums {
            moves += abs(value - candidate)
        }
        best = min(best ?? moves, moves)
    }
    return best ?? 0
}
```

## Problems with the naive solution

It's **O(n²)**: 10^10 operations for 10^5 rooms. Once you see that the answer is the median, the obvious improvement is to sort and read the middle, O(n log n), which is a fine answer. Quickselect goes one step further, to expected O(n), and it's the point of the exercise.

## Optimized solution

Copy the list, then run quickselect for index `n / 2`: partition around a random pivot into smaller, equal and greater regions, and keep only the region that contains the index. When the index lands in the equal region, that pivot is the median. Then add up the distances from every value to it.

## Line by line

- `var values = nums`: quickselect rearranges the array, and the caller's list must not change.
- `let k = values.count / 2`: for odd n the middle element; for even n the upper of the two middle ones. Any value between the two middle ones gives the same total, so either works.
- `let pivot = values[Int.random(in: low..<high)]`: a random pivot makes the bad case (always picking the smallest value) extremely unlikely, whatever the input order.
- The `while i < greaterStart` loop is the lesson's three-way partition: `[low, lessEnd)` smaller, `[lessEnd, greaterStart)` equal, `[greaterStart, high)` greater.
- `if k < lessEnd { high = lessEnd }` and `else if k >= greaterStart { low = greaterStart }`: keep only the side that holds index k. Only one side is kept, which is why the expected cost is n + n/2 + n/4 + … ≈ 2n, not n log n.
- `else { break }`: k is in the equal region, so `values[k]` is the pivot, the median.
- `moves += abs(value - median)`: the total. With values within ±10^9 and n ≤ 10^5, it stays below 2 · 10^14, well inside `Int`.

## Common mistakes

- Using the mean. For `[1, 1, 1, 97]` the mean is 25 and costs 144 moves; the median, 1, costs 96.
- A two-way partition with many equal values. On a list of 10^5 equal values, Lomuto's partition only peels off one element per pass: O(n²). The three-way partition finishes in one pass.
- Sorting the input in place, which changes the caller's data.

## Variation

**Kth largest element:** the same quickselect with `k = n − k` on the ascending order, or with the comparisons flipped. **Best meeting point on a grid:** people at grid cells want to meet where the total Manhattan distance is smallest. Rows and columns are independent, so the answer is the median row and the median column.
