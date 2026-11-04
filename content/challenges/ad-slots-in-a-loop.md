---
id: ad-slots-in-a-loop
title: Ad Slots in a Loop
difficulty: medium
order: 83
patterns: [1-D dynamic programming, Splitting a circular problem]
prerequisites: [m20-l04]
summary: Choose non-adjacent slots on a looping carousel for the most revenue. The trick is turning a circle into two straight lines.
solutionFile: AdSlotsInALoop.swift
testFile: AdSlotsInALoopTests.swift
starter: |
  func bestLoopRevenue(_ revenue: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1) extra
edgeCases:
  - An empty carousel
  - A single slot, which can be used
  - Two slots, which are neighbors on both sides
  - The first and last slots both having the best values
  - All zeros
askInterviewer:
  - Is the last slot really next to the first, or does the carousel stop at the end?
  - Can revenue be negative? (If so, choosing nothing for that slot is always allowed.)
  - With one slot, is it next to itself?
  - Do you want the total only, or also which slots to use?
hints:
  - Solve it for a straight row first. Module 20, lesson 4 did exactly that.
  - In the loop, the only new rule is that slot 0 and slot n - 1 can't both be chosen. In any valid choice, at least one of them is left out.
  - Run the straight-row solution twice, once without the first slot and once without the last, and take the better result.
followUps:
  - Return the chosen slots, not just the total.
  - What if chosen slots must be at least k apart instead of just not adjacent?
  - What if the slots form a tree (a slot's neighbors are its parent and children)?
rubric:
  - I recognized the "no two adjacent" recurrence from the straight-line version.
  - I explained why the circle reduces to two straight lines that skip the first or the last slot.
  - I handled 0, 1 and 2 slots.
  - I used O(1) extra space with two rolling variables.
codeStatus: tested
---

A shopping app's home screen has a carousel that loops: after the last card comes the first one again. Each card slot has an expected revenue if you put a sponsored badge on it. Two badges on neighboring slots look like spam, so no two chosen slots may be next to each other, **and the last slot counts as next to the first**. Return the most revenue you can collect.

A carousel with one slot can use it. With two slots, they're neighbors, so you can use only one.

```swift
bestLoopRevenue([6, 1, 2, 5])     // 8: slots 0 and 2. Slots 0 and 3 would give 11, but they touch.
bestLoopRevenue([3, 6, 3])        // 6: every pair of slots touches in a loop of three
bestLoopRevenue([2, 9, 4, 1, 7])  // 16: slots 1 and 4
```

**Constraints:** `0 ≤ revenue.count ≤ 10^5`; `0 ≤ revenue[i] ≤ 10^4`.

<!-- reveal -->

## First approach

Without the loop, this is the ad-slot problem from Module 20, lesson 4: `best(i) = max(best(i - 1), revenue[i] + best(i - 2))`, either skip slot `i` or take it and skip its left neighbor. The loop adds one constraint between slot 0 and slot n - 1. Any valid choice leaves out at least one of them, so the best loop answer is either the best for slots `0..<n-1` or the best for slots `1..<n`. Both are straight lines.

## Naive solution

Try every subset of slots and keep the valid ones:

```swift
func bestLoopRevenue(_ revenue: [Int]) -> Int {
    let count = revenue.count
    var best = 0
    for mask in 0..<(1 << count) {
        var total = 0
        var isValid = true
        for index in 0..<count where mask & (1 << index) != 0 {
            let next = (index + 1) % count
            if count > 1 && mask & (1 << next) != 0 {
                isValid = false
                break
            }
            total += revenue[index]
        }
        if isValid { best = max(best, total) }
    }
    return best
}
```

## Problems with the naive solution

There are 2ⁿ subsets, each checked in O(n). Twenty slots is already a million subsets; a hundred is out of the question. It's still worth writing in an interview because it pins down the rules, including the `% count` wraparound and the one-slot case, and it makes a good test oracle.

## Optimized solution

Write the straight-line solution as a helper that works on a range of indices, with two rolling variables. Call it on `0..<(n - 1)` and on `1..<n`, and return the larger result. Handle 0 and 1 slots before that, because one of the two ranges would be empty or would drop the only slot.

## Line by line

- `guard revenue.count > 1 else { return revenue.first ?? 0 }`: an empty carousel earns 0 and a single slot is used on its own. With one slot, both ranges below would be empty and the answer would wrongly be 0.
- `bestStraightLineRevenue(revenue, in: 0..<(revenue.count - 1))`: every choice that leaves out the last slot.
- `bestStraightLineRevenue(revenue, in: 1..<revenue.count)`: every choice that leaves out the first slot. A choice that leaves out both appears in both calls, which is harmless with `max`.
- In the helper, `best` is the best total for the slots seen so far and `bestBeforePrevious` is the best total one slot earlier.
- `max(best, bestBeforePrevious + revenue[index])`: skip this slot, or take it, which rules out the previous slot.
- `bestBeforePrevious = best` then `best = current`: shift, oldest first.
- With two slots, the ranges are `0..<1` and `1..<2`, so the answer is the larger single slot, which is right: they touch on both sides.

## Common mistakes

- Running the straight-line solution once on the whole array. On `[6, 1, 2, 5]` it takes slots 0 and 3 for 11, which the loop forbids.
- Splitting into "must take slot 0" and "must not take slot 0" and getting one of the branches wrong. Skipping first or last is simpler and has no forced choices.
- Forgetting the single-slot case, where both ranges are empty.
- Passing subarrays (`Array(revenue.dropLast())`) to a helper. That's correct but copies O(n) elements twice; ranges avoid it.

## Variation

**Tree version:** the slots form a tree and you can't choose a node together with its parent. For each node, return two values from a post-order traversal: the best total if the node is chosen (its value plus the children's "not chosen" totals) and if it isn't (the sum of each child's better total). O(n) time, O(h) stack.
