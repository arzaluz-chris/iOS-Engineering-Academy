---
id: signs-for-a-target-balance
title: Signs for a Target Balance
difficulty: medium
order: 90
patterns: [0/1 knapsack counting, Algebraic reduction]
prerequisites: [m20-l06]
summary: Count the ways to mark each amount as income or expense so the total hits a target. A little algebra turns it into counting subsets with a given sum.
solutionFile: SignsForATargetBalance.swift
testFile: SignsForATargetBalanceTests.swift
starter: |
  func countSignAssignments(_ amounts: [Int], target: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n · P), where P = (total + target) / 2 ≤ total
space: O(P)
edgeCases:
  - No amounts, where only a target of 0 works (one way)
  - Zeros, which double the count because +0 and -0 are different choices
  - A target larger than the total, or smaller than minus the total
  - A target with the wrong parity, which gives 0
  - Negative targets
askInterviewer:
  - Are amounts non-negative? Can they be 0, and does +0 count separately from -0?
  - How large can the total of the amounts be?
  - Do you want the number of ways or one assignment?
  - Can the count overflow? Do you want it modulo something?
hints:
  - Call P the sum of the amounts marked + and T the total. Write the signed sum using only P and T.
  - Once P is fixed, the question is how many subsets add up to exactly P. You've seen that table in Module 20, lesson 6.
  - Each amount can be used at most once. Which direction must the inner loop go if you keep one row?
followUps:
  - What if amounts can be negative?
  - Return one assignment that works, or all of them.
  - "Can you do it without the algebra, with a dictionary from reachable sum to count? What's the cost?"
rubric:
  - I wrote the 2ⁿ brute force and its cost.
  - I derived P = (total + target) / 2 and the conditions for no solution (parity, range).
  - I counted subsets with a one-row table and a backward loop, and explained why backward.
  - I handled zeros and the empty list.
codeStatus: tested
---

A budgeting app imports a list of transaction amounts from a bank export that lost the signs. The bank does report the net balance change. For each amount, the app could mark it `+` (money in) or `-` (money out). Return **how many** sign assignments make the signed amounts add up to `target`, so the app knows whether the reconstruction is unique.

Each amount gets exactly one sign. A zero amount can be `+0` or `-0`, and those count as two different assignments.

```swift
countSignAssignments([2, 3, 5], target: 0)      // 2: +2 +3 -5 and -2 -3 +5
countSignAssignments([1, 2, 3, 4], target: 2)   // 2: -1 +2 -3 +4 and +1 +2 +3 -4
countSignAssignments([4, 6], target: 3)         // 0
```

**Constraints:** `0 ≤ amounts.count ≤ 20`; `0 ≤ amounts[i] ≤ 1,000`; the total of the amounts is at most 1,000; `-1,000 ≤ target ≤ 1,000`.

<!-- reveal -->

## First approach

Every assignment splits the amounts into a `+` group with sum `P` and a `-` group with sum `T - P`, where `T` is the total. The signed sum is `P - (T - P) = 2P - T`. Setting that equal to `target` gives `P = (T + target) / 2`. So the question is how many subsets of the amounts add up to exactly `P`, and there are none if `T + target` is odd or `|target| > T`. Counting subsets with a given sum is the 0/1 knapsack table from Module 20, lesson 6, with counts instead of booleans.

## Naive solution

Try both signs for every amount:

```swift
func countSignAssignments(_ amounts: [Int], target: Int) -> Int {
    func count(from index: Int, sum: Int) -> Int {
        guard index < amounts.count else { return sum == target ? 1 : 0 }
        return count(from: index + 1, sum: sum + amounts[index])
            + count(from: index + 1, sum: sum - amounts[index])
    }
    return count(from: 0, sum: 0)
}
```

## Problems with the naive solution

2ⁿ leaves. For 20 amounts that's about a million, which runs, but the limit is the problem: 40 amounts would be 10^12. Meanwhile the partial sums only take values between `-T` and `T`, so the recursion keeps solving the same `(index, sum)` pairs.

## Optimized solution

Compute `P`. If it isn't a whole number in range, return 0. Otherwise keep `ways[s]`, the number of subsets of the amounts seen so far that add up to `s`, starting with `ways[0] = 1` (the empty subset). For each amount `a`, for every `s` from `P` down to `a`, add `ways[s - a]` to `ways[s]`. The answer is `ways[P]`.

## Line by line

- `let total = amounts.reduce(0, +)`: `T`.
- `guard abs(target) <= total, (total + target) % 2 == 0 else { return 0 }`: no assignment reaches beyond `±T`, and `2P - T = target` needs `T + target` to be even. With `|target| ≤ T`, `T + target` is non-negative, so the remainder check is safe.
- `let positiveSum = (total + target) / 2`: `P`.
- `ways[0] = 1`: before any amount, there's one subset (the empty one) with sum 0.
- `for sum in stride(from: positiveSum, through: amount, by: -1)`: backward, so `ways[sum - amount]` still holds the count from before this amount. A forward loop would let the same amount be used twice. If `amount > positiveSum` the stride is empty.
- `ways[sum] += ways[sum - amount]`: the subsets that reach `sum` either skip this amount (already counted) or include it.
- A zero amount makes `sum - amount == sum`, so every entry doubles, which counts `+0` and `-0` separately.

## Common mistakes

- Forgetting the parity check and computing `P` with integer division anyway, which counts subsets for the wrong sum.
- Looping forward over the sums, which turns it into the unbounded version.
- Treating zeros specially and getting the count off by a factor of two.
- Sizing the table by `target` instead of `P`, which crashes for a negative target.

## Variation

**Last Stone Weight II:** split the amounts into two groups so the difference of their sums is as small as possible. Use the boolean version of the same table to find every reachable sum up to `T / 2`, and take the largest reachable `s`: the answer is `T - 2s`.
