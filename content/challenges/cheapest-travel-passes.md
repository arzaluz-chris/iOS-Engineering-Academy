---
id: cheapest-travel-passes
title: Cheapest Travel Passes
difficulty: medium
order: 84
patterns: [1-D dynamic programming, Unbounded choices over a timeline]
prerequisites: [m20-l01, m20-l04]
summary: Pick day, week and month passes to cover a set of travel days for the lowest price. Fewest coins, but the coins are time ranges.
solutionFile: CheapestTravelPasses.swift
testFile: CheapestTravelPassesTests.swift
starter: |
  func cheapestPassCost(travelDays: [Int], dayPrice: Int, weekPrice: Int, monthPrice: Int) -> Int {
      // Your solution
      return 0
  }
time: O(D), where D is the last travel day (at most 365)
space: O(D)
edgeCases:
  - No travel days
  - One travel day, where a longer pass may still be the cheapest
  - Prices where a longer pass costs less than a shorter one
  - Travel days near the end of the year, where a pass runs past day 365
  - Long runs of consecutive days, where the month pass wins
askInterviewer:
  - Does a pass start on the day I buy it, and does a 7-day pass cover 7 days including that one?
  - Are the travel days sorted and unique?
  - Can a pass run past the end of the year?
  - Are prices always positive? Can a longer pass be cheaper than a shorter one?
hints:
  - Would "buy whatever is cheapest per day" work? Try 3 travel days with a day pass at 3 and a week pass at 10.
  - Let cost[d] be the cheapest way to cover every travel day up to day d. On a day you don't travel, what is cost[d]?
  - On a travel day d, some pass covers it. If it's a week pass, which earlier cost do you add the week price to?
followUps:
  - Make it O(n) in the number of travel days instead of the number of calendar days.
  - Return which passes to buy and on which days.
  - What if there are k pass types with arbitrary lengths and prices?
rubric:
  - I showed a counterexample to a greedy rule before switching to DP.
  - I defined cost[d] over calendar days and handled non-travel days by carrying the previous value.
  - I wrote the three transitions with max(0, d - length) for passes that reach before day 1.
  - I gave O(D) time and space and mentioned the O(n) alternative.
codeStatus: tested
---

A transit app wants to suggest the cheapest set of passes for a trip plan. You get the days of the year you'll ride (`travelDays`, strictly increasing, from 1 to 365) and the prices of three passes: a **day pass** covers 1 day, a **week pass** 7 consecutive days and a **month pass** 30 consecutive days, each starting on the day you buy it. Return the lowest total price that covers every travel day.

```swift
cheapestPassCost(travelDays: [1, 3, 4, 5, 9, 30], dayPrice: 3, weekPrice: 10, monthPrice: 40)
// 16: a week pass on day 1 (days 1–7), then day passes on days 9 and 30

cheapestPassCost(travelDays: [2, 10, 20], dayPrice: 3, weekPrice: 10, monthPrice: 40)
// 9: three day passes

cheapestPassCost(travelDays: Array(1...20), dayPrice: 3, weekPrice: 10, monthPrice: 25)
// 25: one month pass
```

**Constraints:** `0 ≤ travelDays.count ≤ 365`; `1 ≤ travelDays[i] ≤ 365`; `1 ≤ prices ≤ 1,000`.

<!-- reveal -->

## First approach

Greedy rules break quickly. "Use the pass with the lowest price per day" picks the month pass even for a single trip. "Buy a day pass unless the next week has enough trips" depends on thresholds that change with the prices. What does hold: look at the last travel day `d`. Some pass covers it, and that pass was bought on day `d`, `d - 6` or `d - 29` at the latest. Everything before that pass is a smaller version of the same problem. Small state (a day number), overlapping subproblems: dynamic programming, the same structure as fewest coins in Module 20, lesson 4.

## Naive solution

At the first travel day not yet covered, try all three passes and recurse on the rest:

```swift
func cheapestPassCost(travelDays: [Int], dayPrice: Int, weekPrice: Int, monthPrice: Int) -> Int {
    func cheapest(from index: Int) -> Int {
        guard index < travelDays.count else { return 0 }
        var best = Int.max
        for (length, price) in [(1, dayPrice), (7, weekPrice), (30, monthPrice)] {
            let coveredThrough = travelDays[index] + length - 1
            var next = index
            while next < travelDays.count && travelDays[next] <= coveredThrough {
                next += 1
            }
            best = min(best, price + cheapest(from: next))
        }
        return best
    }
    return cheapest(from: 0)
}
```

## Problems with the naive solution

Three branches per uncovered travel day: up to 3ⁿ calls for n travel days, and n can be 365. The same suffix (`cheapest(from: 40)`) is reached through many different combinations of earlier passes. Memoizing on `index` would fix it, and so does filling a table.

## Optimized solution

Make a table over calendar days. `cost[d]` is the cheapest way to cover every travel day up to and including day `d`, with `cost[0] = 0`. On a day you don't ride, nothing new needs covering: `cost[d] = cost[d - 1]`. On a travel day, the pass that covers it is one of three, and each one leaves an earlier prefix to pay for: `cost[d - 1] + dayPrice`, `cost[d - 7] + weekPrice`, `cost[d - 30] + monthPrice`, clamping indexes below 0 to 0. The answer is `cost[lastDay]`.

## Line by line

- `guard let lastDay = travelDays.last else { return 0 }`: no trips, nothing to pay. The days are sorted, so the last one is the largest.
- `isTravelDay`: a lookup table so the main loop can ask "do I ride today?" in O(1). A `Set` would work too, at the cost of hashing.
- `var cost = Array(repeating: 0, count: lastDay + 1)`: index 0 is "before day 1", which costs nothing.
- `guard isTravelDay[day] else { cost[day] = cost[day - 1]; continue }`: carry the previous total over a day off.
- `cost[max(0, day - 7)] + weekPrice`: a week pass ending on `day` was bought on `day - 6`, so it covers `day - 6 ... day` and leaves everything up to `day - 7` to pay for. When `day - 7` is negative, the pass covers everything since day 1.
- `min(...)`: Swift's `min` takes any number of arguments.
- A pass doesn't have to end exactly on `day`. A week pass bought later than `day - 6` also covers `day`, but its cost shows up in a later day's options. Taking the pass that ends on `day` is never worse, because `cost` never decreases as `d` grows.

## Common mistakes

- Indexing `cost[day - 7]` without clamping, which traps on the first week of the year.
- Off-by-one in pass length: a week pass bought on day 1 covers days 1 to 7, so the earlier prefix is `day - 7`, not `day - 6`.
- Only looking at travel days in the table (`cost` indexed by trip number) but still subtracting 7 and 30 as if they were indexes. That mixes calendar days with positions in the array.
- Assuming a longer pass always costs more. The tests include a month pass cheaper than a day pass.

## Variation

**O(n) over travel days:** index the table by trip number instead of calendar day. For trip `i`, keep two pointers to the first trip at least 7 and at least 30 days earlier; both only move forward, so the whole pass is O(n). It matters when the timeline is long (seconds over a year) and the events are few.
