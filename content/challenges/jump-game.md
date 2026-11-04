---
id: jump-game
title: Jump Game
difficulty: medium
order: 92
patterns: [Greedy, Reachability]
prerequisites: [m20-l01]
summary: Decide whether you can hop from the first platform to the last. One pass that keeps the farthest reachable index replaces a quadratic table.
solutionFile: JumpGame.swift
testFile: JumpGameTests.swift
starter: |
  func canReachLastPlatform(_ maxJump: [Int]) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(1) extra
edgeCases:
  - A single platform, which is already the last one
  - An empty array
  - A 0 on the first platform with more platforms after it
  - A 0 you can jump over
  - A 0 that every path lands on
askInterviewer:
  - Can I jump any distance up to maxJump[i], or exactly maxJump[i]?
  - Can values be 0? Negative?
  - Do you want a yes or no, or the fewest jumps?
  - What should an empty array return?
hints:
  - Start with a table, reachable[i]. How do you fill it, and what does it cost?
  - If platform 7 is reachable, is platform 5 reachable too? Why?
  - So the reachable platforms always form a prefix. You only need to know where it ends.
followUps:
  - Return the fewest jumps needed. (Greedy by levels, like BFS on an implicit graph, still O(n).)
  - What if each platform allows a jump of exactly maxJump[i] forward or backward?
  - Prove the greedy rule correct.
rubric:
  - I described the O(n²) reachability table.
  - I explained why the reachable set is a prefix, because short jumps are allowed.
  - I kept the farthest reachable index and stopped when the walk passed it.
  - I handled a single platform and a leading 0.
codeStatus: tested
---

In a platform game, each platform has a spring. From platform `i` you can jump forward **any distance from 1 to `maxJump[i]`** (a 0 means you can't jump from there at all). You start on platform 0. Return `true` if you can reach the last platform.

```swift
canReachLastPlatform([1, 2, 0, 1])      // true: 0 → 1 → 3
canReachLastPlatform([3, 1, 0, 0, 2])   // false: platforms 1 to 3 are reachable, but none gets past 3
canReachLastPlatform([4, 0, 0, 0, 1])   // true: one jump from 0 to 4
```

A single platform is already the last one. An empty array has nothing to reach and returns `true`.

**Constraints:** `0 ≤ maxJump.count ≤ 10^5`; `0 ≤ maxJump[i] ≤ 10^5`.

<!-- reveal -->

## First approach

Platform 0 is reachable. From any reachable platform, every platform within its spring range is reachable. Filling that in gives a table. The key observation for doing better: because you can always jump **shorter**, if platform `k` is reachable then so is every platform before it. The reachable platforms form a prefix, and the only number that matters is where the prefix ends.

## Naive solution

Mark everything reachable from each reachable platform:

```swift
func canReachLastPlatform(_ maxJump: [Int]) -> Bool {
    guard !maxJump.isEmpty else { return true }
    var reachable = Array(repeating: false, count: maxJump.count)
    reachable[0] = true
    for index in maxJump.indices where reachable[index] {
        for next in stride(from: index + 1, through: min(maxJump.count - 1, index + maxJump[index]), by: 1) {
            reachable[next] = true
        }
    }
    return reachable[maxJump.count - 1]
}
```

## Problems with the naive solution

Each reachable platform marks up to `maxJump[i]` others, so with large springs it's O(n²): 10^10 steps for 10^5 platforms. It also stores a whole array to answer a question that, as the prefix argument shows, needs one integer.

## Optimized solution

Walk the platforms in order, keeping `farthest`, the largest index reached so far. If the current index is beyond `farthest`, nothing reachable can get here, so return `false`. Otherwise extend `farthest` with this platform's jump. If the walk gets through every platform, the last one was reachable.

## Line by line

- `var farthest = 0`: before looking at anything, only platform 0 is known to be reachable.
- `for (index, jump) in maxJump.enumerated()`: index and spring together.
- `guard index <= farthest else { return false }`: this platform is past the end of the reachable prefix, and so is everything after it.
- `farthest = max(farthest, index + jump)`: from a reachable platform, everything up to `index + jump` is reachable. It can exceed the last index; that's fine.
- `return true`: the loop checked every index, including the last, against `farthest`. For an empty array the loop doesn't run, which gives the `true` the statement asks for.

## Common mistakes

- Always jumping the full distance (`index += maxJump[index]`). On `[2, 3, 0, 0, 1]`, jumping 2 lands on a 0; jumping 1 and then 3 reaches the end.
- Searching all paths with recursion and no memo: exponential.
- Checking `index < farthest` instead of `<=`, which rejects the platform at the very edge of the prefix.
- Returning `false` for a single platform with a 0 on it.

## Variation

**Fewest jumps:** walk the platforms in "levels". Everything reachable with `k` jumps is a range `[start, end]`. The next level ends at the largest `i + maxJump[i]` over that range. Count levels until the range includes the last platform. Each platform is read once: O(n) time, O(1) space.
