---
id: car-pooling
title: Car Pooling
difficulty: medium
order: 42
patterns: [Intervals, Sweep line, Event sorting]
prerequisites: [m20-l02, m16-l06]
summary: Decide whether a shuttle has enough seats for every booking. Turn each booking into a pickup event and a drop-off event and sweep along the route.
solutionFile: CarPooling.swift
testFile: CarPoolingTests.swift
starter: |
  struct ShuttleBooking {
      let passengers: Int
      let pickup: Int
      let dropoff: Int
  }

  func canServeAllBookings(_ bookings: [ShuttleBooking], seats: Int) -> Bool {
      // Your solution
      return false
  }
time: O(n log n)
space: O(n)
edgeCases:
  - No bookings
  - One group dropped off at the same mile another is picked up
  - A single booking larger than the shuttle
  - The peak load in the middle of a long ride, not at a pickup of the longest booking
askInterviewer:
  - At a mile where some passengers get off and others get on, who goes first?
  - Is the route one-way, with pickup always before drop-off?
  - How large can the mile markers get? (Small markers allow a counting array instead of a sort.)
hints:
  - The shuttle is full at some moment if the passengers on board at that moment exceed the seats. When can that number go up?
  - Lesson m20-l02 counts rooms by sweeping starts and ends in order. Here each booking adds or removes several people at once. What would you sort?
  - "Make an event (mile, +passengers) for each pickup and (mile, -passengers) for each drop-off. Sort by mile, drop-offs first on ties, and keep a running total."
followUps:
  - The mile markers are at most 1,000. How would you do it in O(n + 1000) without sorting? (A difference array, lesson m16-l06.)
  - How would you report the first mile where the shuttle overflows?
  - What if bookings arrive one at a time and each must be accepted or rejected immediately?
rubric:
  - I turned bookings into signed events and sorted them by position.
  - I processed drop-offs before pickups at the same mile, matching the half-open convention.
  - I kept a running load and stopped as soon as it exceeded the seats.
  - I mentioned the difference-array alternative when positions are small.
codeStatus: tested
---

An airport shuttle drives one way along a road with mile markers. Each booking is a group of `passengers` that gets on at mile `pickup` and off at mile `dropoff`, so they occupy seats for the half-open stretch `pickup..<dropoff`. At any mile, passengers getting off leave before new ones get on. Write `canServeAllBookings(_:seats:)` that returns `true` if a shuttle with `seats` seats can carry every booking.

```swift
let bookings = [
    ShuttleBooking(passengers: 3, pickup: 2, dropoff: 7),
    ShuttleBooking(passengers: 2, pickup: 5, dropoff: 9),
    ShuttleBooking(passengers: 4, pickup: 8, dropoff: 12),
]
canServeAllBookings(bookings, seats: 5)   // false: at mile 8, 2 + 4 = 6 people are on board
canServeAllBookings(bookings, seats: 6)   // true

canServeAllBookings([
    ShuttleBooking(passengers: 4, pickup: 0, dropoff: 5),
    ShuttleBooking(passengers: 4, pickup: 5, dropoff: 9),
], seats: 4)                              // true: the first group is off before the second gets on
```

**Constraints:** `0 ≤ n ≤ 10^4`; `1 ≤ passengers ≤ 100`; `0 ≤ pickup < dropoff ≤ 10^6`; `0 ≤ seats ≤ 10^6`.

<!-- reveal -->

## First approach

This is the "how many rooms" sweep from lesson m20-l02, with weights. There, every meeting used one room, so sorting the starts and the ends separately was enough. Here a pickup adds a whole group and a drop-off removes one, so each booking becomes two events with signed sizes. Walk the events in order of mile, keep the number of people on board, and check it against the seats.

## Naive solution

The load only increases at a pickup, so its maximum happens at some pickup mile. For each booking's pickup mile, add up every booking on board there:

```swift
func canServeAllBookings(_ bookings: [ShuttleBooking], seats: Int) -> Bool {
    for booking in bookings {
        var onBoard = 0
        for other in bookings where other.pickup <= booking.pickup && booking.pickup < other.dropoff {
            onBoard += other.passengers
        }
        if onBoard > seats {
            return false
        }
    }
    return true
}
```

`other.pickup <= booking.pickup && booking.pickup < other.dropoff` is the half-open test "the mile is inside `other`'s stretch".

## Problems with the naive solution

**O(n²)**: 10,000 bookings mean 10^8 checks. Each pickup recounts everyone from scratch, even though the load at the next event differs by one group. A running total updated event by event avoids the recount.

## Optimized solution

Build 2n events: `(pickup, +passengers)` and `(dropoff, -passengers)`. Sort them by mile, and for the same mile put negative changes first, so drop-offs happen before pickups. Walk the events adding each change to `onBoard`; as soon as it exceeds `seats`, the answer is `false`. If the walk finishes, it's `true`.

## Line by line

- `events.append((mile: booking.pickup, change: booking.passengers))` and `events.append((mile: booking.dropoff, change: -booking.passengers))`: two events per booking.
- `events.sort { $0.mile != $1.mile ? $0.mile < $1.mile : $0.change < $1.change }`: by mile; on a tie, smaller change first. Every drop-off is negative and every pickup positive, so all drop-offs at a mile come before all pickups there. That's the half-open convention: a seat freed at mile 5 can be used by someone boarding at mile 5.
- `onBoard += event.change`: the load right after this event.
- `if onBoard > seats { return false }`: checking after every event includes the moment after the last pickup at each mile, which is the highest load at that mile. Earlier pickups at the same mile give smaller intermediate loads, so they can't cause a false alarm.
- `return true`: the load never went over.

Sorting 2n events is O(n log n), and the walk is O(n): **O(n log n) time, O(n) space** for the events.

## Common mistakes

- Processing pickups before drop-offs at the same mile, which reports an overflow when one group gets off exactly where another gets on.
- Sorting starts and ends as two separate arrays of miles, as in the unweighted sweep, and forgetting the passenger counts.
- Using `>=` against `seats`. A full shuttle is fine; only going over is a problem.
- Allocating a counting array of size `max(dropoff)` when markers can be 10^6 and bookings few. It works, but sorting the events is the safer default; say which one you'd pick and why.

## Variation

**Difference array**: if mile markers are small (say at most 1,000), skip the sort. Add `passengers` at `diff[pickup]` and subtract it at `diff[dropoff]`, then take a running sum along the road and compare each value with `seats` (lesson m16-l06). That's O(n + M) time for M mile markers, which beats O(n log n) when M is small.
