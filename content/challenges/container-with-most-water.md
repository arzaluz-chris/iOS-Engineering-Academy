---
id: container-with-most-water
title: Container With Most Water
difficulty: medium
order: 14
patterns: [Two pointers, Converging pointers, Greedy]
prerequisites: [m07, m15, m16-l03]
summary: Pick two boards that hold the most water between them. The hard part isn't the code; it's proving that moving the shorter board is safe.
solutionFile: ContainerWithMostWater.swift
testFile: ContainerWithMostWaterTests.swift
starter: |
  func largestTank(_ heights: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1)
edgeCases:
  - Fewer than two boards
  - Boards of height 0
  - Equal heights at both ends
  - Strictly increasing or decreasing heights
askInterviewer:
  - Do the boards between the two chosen ones block anything? (No; they're ignored.)
  - Can a height be 0?
  - Do I return the amount of water or the two positions?
  - How many boards can there be?
hints:
  - "Start with the two outermost boards: the widest possible tank. Which of the two boards limits it?"
  - "Every other tank that uses the shorter board is narrower, and its water can't be higher than that board. So what can you conclude about the shorter board?"
  - "Move the shorter board inward. If both are equal, you can move either."
followUps:
  - "Prove that moving the shorter board never skips the best pair."
  - What changes if the water level must be the height of the shortest board between the two, inclusive? (That's a different problem; which one?)
  - How would you return the indices of the best pair?
rubric:
  - I started from the O(n²) version and named what it ignores.
  - I used converging pointers and moved the shorter side.
  - I explained why discarding the shorter board is safe.
  - I stated O(n) time and O(1) space.
codeStatus: tested
---

A garden has a row of vertical boards standing one meter apart, with heights given in order. Choosing two boards makes a tank: the water between them can rise to the height of the **shorter** of the two, and its width is the distance between them. The boards in between are thin and don't get in the way.

Write `largestTank(_ heights: [Int]) -> Int` that returns the largest amount of water (height × width) any two boards can hold.

```swift
largestTank([3, 8, 4, 2, 7, 5])  // 21: boards 1 and 4, min(8, 7) × 3
largestTank([1, 2, 3, 4, 5])     // 6
largestTank([4, 4])              // 4
largestTank([9])                 // 0: one board holds nothing
```

**Constraints:** `0 ≤ heights.count ≤ 10^5`; `0 ≤ heights[i] ≤ 10^4`.

<!-- reveal -->

## First approach

The amount for boards `i < j` is `min(heights[i], heights[j]) × (j − i)`. Start with the widest tank, the two ends. The shorter of those two boards is the limit: any other tank that uses it is narrower and can't be higher than it. So it can't be part of a better answer, and you can discard it. Repeat until the pointers meet.

## Naive solution

Try every pair:

```swift
func largestTank(_ heights: [Int]) -> Int {
    var best = 0
    for i in heights.indices {
        for j in (i + 1)..<heights.count {
            best = max(best, min(heights[i], heights[j]) * (j - i))
        }
    }
    return best
}
```

## Problems with the naive solution

It's **O(n²)**: 5·10^9 pairs for 10^5 boards. Most pairs are obviously worse than one you've already seen, and the brute force has no way to skip them.

## Optimized solution

`left` at 0, `right` at the end. Record the tank between them, then move the shorter board inward. Each step discards a board that can't be in any better pair, so after at most n − 1 steps every candidate has been accounted for.

Why it's safe: say `heights[left] <= heights[right]`. Any other tank using `left` pairs it with some `k` between them. That tank is narrower (`k − left < right − left`) and its height is at most `heights[left]`. So it holds less than or the same as the tank you just recorded, and `left` can go.

## Line by line

- `var right = heights.count - 1`: for zero or one board, `left < right` is false and the answer is 0.
- `let height = min(heights[left], heights[right])`: the water level is set by the shorter board.
- `best = max(best, height * (right - left))`: record the current tank before discarding anything. The largest product is 10^4 × 10^5 = 10^9, which fits easily.
- `if heights[left] < heights[right] { left += 1 } else { right -= 1 }`: discard the shorter board. On a tie either one can go: by the same argument, neither can do better with a narrower partner, since the height would still be capped by its own height.

## Common mistakes

- Moving the taller board. That can only shrink the width without raising the cap, so it can skip the answer: for `[1, 10, 10, 2]`, moving the taller side keeps the board of height 1 until the end and never pairs the two 10s, so it returns 3 instead of 10.
- Treating the boards in between as walls. That's Trapping Rain Water, a different problem.
- Computing `(right - left + 1)` as the width. The boards are one meter apart, so two neighbors hold a tank of width 1.

## Variation

**Return the boards themselves:** keep `bestLeft` and `bestRight` next to `best` and update all three when a tank wins. If several pairs tie, the statement has to say which one to return; the loop finds them in a specific order, so the rule decides whether you use `>` or `>=`.
