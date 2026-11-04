---
id: stairs-with-broken-steps
title: Stairs With Broken Steps
difficulty: easy
order: 82
patterns: [1-D dynamic programming, Rolling variables]
prerequisites: [m20-l03, m20-l04]
summary: Count the ways up a staircase when some steps can't hold you. The smallest DP there is, with one twist that breaks the plain Fibonacci formula.
solutionFile: StairsWithBrokenSteps.swift
testFile: StairsWithBrokenStepsTests.swift
starter: |
  func countClimbs(steps n: Int, broken: Set<Int>) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1) extra
edgeCases:
  - n = 0, where the answer is 1 (you're already at the top)
  - The top step itself is broken
  - Step 1 is broken, so every climb starts with a 2-step move
  - Two broken steps in a row, which nothing can cross
  - Broken numbers outside 1...n, which don't matter
askInterviewer:
  - Is the top step one I have to land on, and can it be broken?
  - What should n = 0 return?
  - How large can n get? Does the count fit in an Int, or do you want it modulo something?
  - Can the broken set contain numbers outside 1...n?
hints:
  - To stand on step i, where was your last move from?
  - The number of ways to reach a broken step is 0. What does that do to the steps above it?
  - Each value only reads the two values below it. How many of them do you need to keep?
followUps:
  - What if each move can be 1, 2 or 3 steps, or any size from a given set?
  - What if n can be 10^6 and the answer is wanted modulo 1,000,000,007?
  - How would you return one actual climb, not just the count?
rubric:
  - I wrote the recurrence ways(i) = ways(i - 1) + ways(i - 2), with 0 for a broken step.
  - I set the base cases correctly (ground = 1, below the ground = 0) and handled n = 0.
  - I explained why the plain recursion is exponential and how storing results fixes it.
  - I reduced the space to two variables.
codeStatus: tested
---

A fitness app shows a staircase of `n` steps, numbered 1 to `n` from the bottom. You start on the ground (step 0) and each move goes up **1 or 2 steps**. Some steps are broken: you can't land on them, though a 2-step move can jump over one. Return how many different sequences of moves take you from the ground to step `n`.

If step `n` is broken, the answer is 0. Numbers in `broken` outside `1...n` are ignored. For `n = 0` there's one way: no moves at all.

```swift
countClimbs(steps: 4, broken: [])     // 5: 1111, 112, 121, 211, 22
countClimbs(steps: 6, broken: [3])    // 4: every climb has to jump from 2 to 4
countClimbs(steps: 5, broken: [2, 3]) // 0: no move gets past two broken steps
```

**Constraints:** `0 ≤ n ≤ 90`, so the answer fits in an `Int`.

<!-- reveal -->

## First approach

Think about the last move. To stand on step `i`, you came from step `i - 1` with a 1-step move or from step `i - 2` with a 2-step move. Those two groups of climbs don't overlap, so `ways(i) = ways(i - 1) + ways(i - 2)`. A broken step breaks the chain: nobody can stand there, so `ways(i) = 0`, and the steps above it only get what flows around it.

## Naive solution

Recurse from the ground and try both moves:

```swift
func countClimbs(steps n: Int, broken: Set<Int>) -> Int {
    func ways(from step: Int) -> Int {
        if step == n { return 1 }
        var total = 0
        for next in [step + 1, step + 2] where next <= n && !broken.contains(next) {
            total += ways(from: next)
        }
        return total
    }
    return ways(from: 0)
}
```

## Problems with the naive solution

It walks every climb one by one, and there are as many climbs as the answer: about 1.618ⁿ, the Fibonacci growth rate. For `n = 90` that's around 4.6 · 10^18 calls. The recursion also asks the same question over and over: `ways(from: 5)` is computed once for every climb that passes through step 5. Overlapping subproblems with a small state (just the step number) is the signal for dynamic programming.

## Optimized solution

Fill the answers bottom-up. Start with the ground, which has one way (do nothing), and the imaginary step below it, which has none. For each step from 1 to `n`, the count is 0 if the step is broken and the sum of the two counts below it otherwise. Only the last two counts are ever read, so keep two variables instead of an array.

## Line by line

- `guard n > 0 else { return 1 }`: zero steps means you're already at the top. This also keeps `1...n` from being an invalid range.
- `var twoBelow = 0`, `var oneBelow = 1`: before the loop they stand for step -1 (no ways) and the ground (one way). With those two values, step 1 gets `1 + 0 = 1`, and step 2 gets `ways(1) + 1`, which counts the direct 2-step move from the ground.
- `let current = broken.contains(step) ? 0 : oneBelow + twoBelow`: the recurrence, with the broken step forced to 0. `Set.contains` is O(1) on average.
- `twoBelow = oneBelow` then `oneBelow = current`: shift the window up one step, oldest first. In the other order you'd overwrite `oneBelow` before copying it.
- `return oneBelow`: after the last iteration it holds `ways(n)`, which is already 0 if step `n` is broken.

## Common mistakes

- Starting with `ways(0) = 0`. The empty climb is one way to stand on the ground; with 0 there, every count comes out 0.
- Skipping broken steps in the loop (`continue`) instead of storing 0 for them. The variables don't shift, and step `i + 1` reads the wrong values.
- Returning `fib(n + 1)` from a formula. It's right only when nothing is broken.
- Forgetting the `n = 0` case and building the range `1...0`, which traps at runtime.

## Variation

**Cheapest climb:** each step has a cost and you want the lowest total instead of the count. The recurrence is the same shape with `min` instead of `+`: `cost(i) = fee(i) + min(cost(i - 1), cost(i - 2))`. Module 20, lesson 4 builds that one.
