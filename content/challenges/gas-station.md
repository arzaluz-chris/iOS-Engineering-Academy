---
id: gas-station
title: Gas Station
difficulty: medium
order: 93
patterns: [Greedy, Prefix sums on a circle]
prerequisites: [m20-l01]
summary: Find where a scooter can start a loop of charging stops without running out. Two facts about running totals turn an O(n²) simulation into one pass.
solutionFile: GasStation.swift
testFile: GasStationTests.swift
starter: |
  func startingChargerIndex(charge: [Int], cost: [Int]) -> Int? {
      // Your solution
      return nil
  }
time: O(n)
space: O(1) extra
edgeCases:
  - No stops
  - A single stop, with enough or not enough charge
  - Several stops that all work (return the smallest index)
  - Exactly enough energy in total
  - The answer at the last stop
askInterviewer:
  - Does the battery start empty? Does it have a maximum capacity?
  - Can the battery reach exactly 0 in the middle of a leg, or must it stay positive?
  - If several stops work, which one should I return?
  - Are the two arrays always the same length?
hints:
  - If the total charge is less than the total cost, can any start work? And if it's at least the total cost?
  - Suppose you start at s and run out right after stop i. Could any stop between s and i be a valid start?
  - Then after a failure at i, the next start to try is i + 1, and you never need to go back.
followUps:
  - Prove that if the total is non-negative, the start the greedy finds always completes the loop.
  - What if the battery has a maximum capacity?
  - What if you may ride the loop in either direction?
rubric:
  - I wrote the O(n²) simulation.
  - I explained why the total decides whether any answer exists.
  - I explained why a failure at i rules out every start from s to i.
  - I wrote the one-pass solution and handled empty input.
codeStatus: tested
---

A delivery scooter rides a fixed loop of stops. At stop `i` it can pick up `charge[i]` units of energy, and riding from stop `i` to the next stop (stop 0 after the last one) uses `cost[i]` units. The battery starts empty, has no upper limit, and must never go below zero. Return the index of a stop where the scooter can start and ride the whole loop once, or `nil` if there isn't one. If several stops work, return the smallest index.

```swift
startingChargerIndex(charge: [1, 5, 2, 3], cost: [2, 2, 4, 1])  // 1
startingChargerIndex(charge: [2, 2], cost: [3, 2])              // nil: 4 units picked up, 5 needed
startingChargerIndex(charge: [0, 4, 0], cost: [1, 1, 2])        // 1
```

From stop 1 in the first example, the battery reads 3, then 1, then 3, then 2 after each leg.

**Constraints:** `0 ≤ charge.count == cost.count ≤ 10^5`; `0 ≤ charge[i], cost[i] ≤ 10^4`.

<!-- reveal -->

## First approach

Work with the net change at each stop, `charge[i] - cost[i]`. Two facts do all the work. First, if the nets add up to less than zero, no start can work, since every start collects and spends the same totals. Second, if a ride that started at `s` fails right after stop `i`, then no stop between `s` and `i` works either: starting at one of them means arriving there with an empty battery instead of a non-negative one, which can only be worse. So after a failure, the next candidate is `i + 1`. That's a greedy rule you can justify, as Module 20, lesson 1 asks.

## Naive solution

Simulate the loop from every stop:

```swift
func startingChargerIndex(charge: [Int], cost: [Int]) -> Int? {
    for start in charge.indices {
        var battery = 0
        var completed = true
        for step in 0..<charge.count {
            let index = (start + step) % charge.count
            battery += charge[index] - cost[index]
            if battery < 0 {
                completed = false
                break
            }
        }
        if completed { return start }
    }
    return nil
}
```

## Problems with the naive solution

n starts with up to n legs each: O(n²), about 10^10 steps for 10^5 stops. Most of that work is repeated: the simulation from `s + 1` re-adds the same nets that the one from `s` already added.

## Optimized solution

Walk the stops once, keeping two running totals: `totalNet`, over all stops, and `battery`, since the current candidate start. When `battery` drops below zero after stop `i`, move the candidate to `i + 1` and reset `battery`. At the end, if `totalNet` is non-negative, the candidate is the answer; otherwise there is none.

Why the candidate works when the total is non-negative: the ride from the candidate to the end never went negative (that's why it's still the candidate), and it ends with some surplus. The part before the candidate is made of failed segments, each negative, but the total covers them, so the surplus is enough to ride through them.

## Line by line

- `guard !charge.isEmpty else { return nil }`: no stops, no loop to ride.
- `let net = charge[index] - cost[index]`: what this stop and the leg after it do to the battery.
- `totalNet += net`: decides at the end whether any start works.
- `battery += net`: the battery for a ride that began at `start`.
- `if battery < 0 { start = index + 1; battery = 0 }`: the ride failed, and so would any ride starting between `start` and `index`.
- `return totalNet >= 0 ? start : nil`: if the last leg failed, `start` would be `n`, but then every segment was negative and `totalNet < 0`, so `nil` is returned before an invalid index can escape.
- The candidate is also the smallest valid start: a ride that passes through a valid start `a` can't fail at or after `a`, because everything from `a` on is non-negative, so the candidate never moves past `a`.

## Common mistakes

- Checking only `totalNet >= 0` and returning 0.
- Resetting the candidate to `index` instead of `index + 1`. Stop `index` is where the battery went negative, so it can't be the start either.
- Forgetting the modulo in the simulation and reading past the end of the arrays.
- Treating "battery reaches exactly 0" as a failure, which the statement allows.

## Variation

**Minimum starting charge:** if you must start at stop 0, how much energy do you need in the battery at the start? Walk the prefix sums of the nets and take the most negative one: the answer is its absolute value (or 0). Same one pass.
