---
id: car-fleet
title: Car Fleet
difficulty: medium
order: 29
patterns: [Sorting, Monotonic stack]
prerequisites: [m17-l05, m18-l04]
summary: Count how many groups of scooters arrive at a depot when nobody can pass on the path. Sort by position, then each scooter only has to look at the group right ahead of it.
solutionFile: CarFleet.swift
testFile: CarFleetTests.swift
starter: |
  func carFleets(target: Int, positions: [Int], speeds: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n log n)
space: O(n)
edgeCases:
  - No scooters, and a single scooter
  - Two scooters that meet exactly at the depot, which count as one group
  - Faster scooters already ahead, so nobody catches anybody
  - Arrival times that are fractions very close to each other
askInterviewer:
  - If two scooters meet exactly at the depot, are they one group or two?
  - Can two scooters start at the same position?
  - Are all positions strictly before the depot, and all speeds positive?
  - Do you need the groups themselves, or only how many there are?
hints:
  - Which scooter can a given scooter possibly catch? Does it matter what happens behind it?
  - Imagine no scooter could block another. Compute each one's arrival time. How does a slower scooter ahead change the arrival time of the ones behind it?
  - "Walk from the scooter closest to the depot backward. Keep the arrival time of the group just ahead. A scooter that would arrive no later than that group joins it; otherwise it starts a new one."
  - "Times are fractions: (target - position) / speed. Compare them without dividing."
followUps:
  - How would you return the members of each group instead of the count?
  - What changes if scooters can pass each other on a two-lane path?
  - How would you answer "when does each scooter arrive?" (Each scooter arrives at the time of the group it belongs to.)
rubric:
  - I sorted by position, closest to the depot first, and explained why the scooters behind don't matter.
  - I compared each scooter only with the slowest group ahead of it, and joined it when its own time was less than or equal.
  - I avoided floating point by cross-multiplying, or explained the risk of comparing Doubles for equality.
  - I gave O(n log n) time, dominated by the sort.
codeStatus: tested
---

Delivery scooters ride along a one-lane bike path toward a depot at mile `target`. Scooter `i` starts at mile `positions[i]` and rides at `speeds[i]` miles per hour. Nobody can pass: when a faster scooter catches a slower one, it slows down and rides right behind it, and from then on they move as one **group**. A scooter that catches a group exactly at the depot also counts as part of that group.

Write `carFleets(target:positions:speeds:)` that returns how many groups reach the depot.

```swift
carFleets(target: 20, positions: [16, 12, 1, 9, 5], speeds: [2, 4, 1, 1, 3])   // 3
// 16 and 12 both arrive at hour 2: one group.
// 9 arrives at hour 11 on its own; 5 would arrive at hour 5, so it's stuck behind 9.
// 1 arrives at hour 19, alone.

carFleets(target: 10, positions: [0, 4], speeds: [3, 1])          // 1
carFleets(target: 100, positions: [0, 2, 4], speeds: [4, 2, 1])   // 1
```

**Constraints:** `0 ≤ n ≤ 10^5`; `0 < target ≤ 10^6`; positions are distinct and `0 ≤ positions[i] < target`; `1 ≤ speeds[i] ≤ 10^6`.

<!-- reveal -->

## First approach

A scooter can only be slowed down by what's ahead of it, so process the scooters from the depot backward. If nothing blocked anybody, scooter i would arrive at time `(target - position) / speed`. A scooter behind a slower group can't arrive before that group, so it joins it. A scooter that would arrive strictly later than the group ahead never catches it and starts a new group. Groups ahead form a stack whose arrival times grow as you move back down the path, and each scooter only compares itself with the top.

## Naive solution

A scooter leads its own group exactly when every scooter ahead of it would arrive strictly earlier on its own. Check that for every scooter against every other:

```swift
func carFleets(target: Int, positions: [Int], speeds: [Int]) -> Int {
    var fleets = 0
    for i in positions.indices {
        let distance = target - positions[i]
        var blocked = false
        for j in positions.indices where positions[j] > positions[i] {
            let distanceAhead = target - positions[j]
            if distance * speeds[j] <= distanceAhead * speeds[i] {
                blocked = true
                break
            }
        }
        if !blocked {
            fleets += 1
        }
    }
    return fleets
}
```

`distance * speeds[j] <= distanceAhead * speeds[i]` is "my time ≤ their time" with both sides multiplied by `speeds[i] * speeds[j]`, which is positive, so the inequality keeps its direction.

## Problems with the naive solution

For each scooter it scans all the others: **O(n²)**. With 10^5 scooters that's 10^10 comparisons. The scan repeats work: the scooters ahead of scooter i are the same ones that were ahead of the scooter just before it, plus one.

## Optimized solution

Sort the scooters by position, closest to the depot first. Walk that order keeping the slowest group ahead, described by its leader's distance and speed. For each scooter, compare its time with the group's: if it's less than or equal, it joins and nothing changes. If it's greater, it starts a new group, which becomes the one every later scooter compares against.

That variable is the top of a monotonic stack of group arrival times. A scooter that joins doesn't change the top, and a scooter that starts a new group has a strictly later time than the old top, so the old top can never matter again: nobody behind can reach the old group without first running into the new, slower one. That's why you never need anything below the top, and one variable is enough.

## Line by line

- `zip(positions, speeds).sorted { $0.0 > $1.0 }`: pairs each position with its speed and sorts by position, descending. The sort is O(n log n).
- `var slowestAhead: (distance: Int, speed: Int)? = nil`: the group just ahead. `nil` before the first scooter, which always starts a group.
- `let distance = target - position`: miles left for this scooter.
- `if let ahead = slowestAhead, distance * ahead.speed <= ahead.distance * speed`: this scooter's time, `distance / speed`, is at most the group's time, `ahead.distance / ahead.speed`. Multiplying both sides by `speed * ahead.speed` turns it into integers. With the constraints, each product is at most 10^12, far below `Int.max`.
- `continue`: it catches the group (possibly exactly at the depot) and becomes part of it.
- `fleets += 1` and `slowestAhead = (distance: distance, speed: speed)`: a new, slower group that the scooters behind will compare against.

**O(n log n) time** for the sort plus an O(n) walk; **O(n) space** for the sorted pairs.

## Common mistakes

- Sorting by position ascending and walking forward. A scooter's fate depends on the ones **ahead**, so you have to know them first.
- Comparing `Double` times with `==` or `<=`. Two times that are mathematically equal can differ in the last bit after division. Cross-multiplying keeps everything exact.
- Updating `slowestAhead` when a scooter joins a group. The group's arrival time is its leader's, not the faster scooter's.
- Using `<` instead of `<=`, which counts scooters that meet at the depot as separate groups.
- Simulating the ride hour by hour. Catch-ups can happen at fractional times, and the number of steps depends on the distances, not on n.

## Variation

**Car Fleet II**: return, for each car, the time at which it collides with the car ahead of it (or -1). Now the car ahead can itself merge into something slower before it's caught, so you keep a real stack of candidates ahead and pop the ones that will have merged away before this car could reach them.
