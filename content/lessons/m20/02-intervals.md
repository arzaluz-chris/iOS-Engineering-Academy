---
id: m20-l02
title: Interval problems
description: You treat bookings, meetings and busy blocks as intervals, decide whether touching ones overlap, merge overlapping intervals after sorting by start, pick the most non-overlapping intervals by sorting by end (and see the other sort keys fail), and count and assign meeting rooms with a sweep over sorted starts and ends or with a min-heap of end times.
module: m20
order: 2
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l01, m19-l04]
objectives:
  - Represent intervals and state precisely when two of them overlap.
  - Merge overlapping intervals in O(n log n) by sorting by start.
  - Select the largest set of non-overlapping intervals by sorting by end, and justify it with an exchange argument.
  - Compute the minimum number of rooms for a set of meetings with a sweep, and assign rooms with a min-heap.
terms:
  - term: Interval
    definition: A range of values with a start and an end, like a meeting from 9 to 10. This lesson uses half-open intervals, which include the start and exclude the end.
  - term: Half-open interval
    definition: "[start, end): contains start but not end. Two half-open intervals a and b overlap exactly when a.start < b.end and b.start < a.end, so a meeting ending at 10 doesn't clash with one starting at 10."
  - term: Interval scheduling
    definition: Choosing the largest number of intervals that don't overlap. Solved greedily by repeatedly taking the interval that ends earliest.
  - term: Sweep line
    definition: A technique that processes the starts and ends of all intervals in order of position, keeping a running count (or set) of the intervals open at that point.
mastery:
  - Write the overlap test for half-open intervals without looking it up.
  - Merge a list of intervals, including contained and touching ones, and explain why the merge needs max.
  - Choose the sort key for an interval problem and give a counterexample for a wrong one.
  - Compute how many rooms a schedule needs with a sweep, and say what the heap version adds.
resources: [swift-array-sorted-by, swift-array, swift-comparable, swift-book-structures-classes]
cards:
  - id: m20-l02-c1
    front: When do half-open intervals a and b overlap?
    back: When a.start < b.end and b.start < a.end. A meeting ending at 10 and one starting at 10 don't overlap.
  - id: m20-l02-c2
    front: How do you merge overlapping intervals?
    back: Sort by start. Walk them, and either extend the last merged interval to max(last.end, current.end) when current.start ≤ last.end, or append the current one. O(n log n).
  - id: m20-l02-c3
    front: Most non-overlapping intervals (or fewest to remove)?
    back: Sort by end. Take each interval that starts at or after the end of the last one taken. Removals = n − taken. Sorting by start or by length fails.
  - id: m20-l02-c4
    front: Minimum number of meeting rooms, with a sweep?
    back: Sort starts and ends separately. For each start, first release every meeting whose end ≤ this start, then occupy a room. The answer is the most rooms in use at once. O(n log n).
  - id: m20-l02-c5
    front: What does the min-heap version of meeting rooms give you that the sweep doesn't?
    back: Which room each meeting gets. The heap holds (end, room) for rooms in use; if the earliest end is ≤ the next start, that room is reused, otherwise a new room opens.
---

## The idea in one sentence

Most interval problems become a single pass once you **sort by the right end of the interval**: by start to merge, by end to select.

Bookings, meetings, video segments, the ranges a download has already fetched, the hours a store is open: all of them are intervals. The algorithms are short. The thinking is in the sort key and in what "overlap" means.

## What counts as an overlap

This lesson uses **half-open** intervals: a meeting from 9 to 10 includes 9 and excludes 10. That's how calendars work (a 9–10 meeting and a 10–11 meeting don't clash) and how Swift's `9..<10` works.

```swift
struct Interval: CustomStringConvertible {
    let start: Int
    let end: Int
    var description: String { "\(start)-\(end)" }
}

func overlaps(_ a: Interval, _ b: Interval) -> Bool {
    a.start < b.end && b.start < a.end
}

let standup = Interval(start: 9, end: 10)
print(overlaps(standup, Interval(start: 10, end: 11)))
print(overlaps(standup, Interval(start: 9, end: 12)))
print(overlaps(Interval(start: 8, end: 13), standup))
```

```output
false
true
true
```

Read the test as "each one starts before the other one ends." It covers partial overlap, containment (8–13 contains 9–10) and identical intervals, and it says no for touching ones. Testing the four ways intervals can be arranged separately is a classic source of bugs; this one line replaces all of them.

> [!warning] Settle the convention first
> With closed intervals (both ends included), 9–10 and 10–11 share the moment 10, and the test becomes `<=`. Interviewers often leave this open on purpose. Ask "do touching intervals overlap?" before you write anything.

## Merging intervals

A calendar shows busy blocks, not individual meetings. Overlapping meetings become one block:

```swift
struct Interval: CustomStringConvertible {
    let start: Int
    let end: Int
    var description: String { "\(start)-\(end)" }
}

func merge(_ intervals: [Interval]) -> [Interval] {
    let sorted = intervals.sorted { $0.start < $1.start }
    var merged: [Interval] = []
    for interval in sorted {
        if let last = merged.last, interval.start <= last.end {
            merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
        } else {
            merged.append(interval)
        }
    }
    return merged
}

let meetings = [
    Interval(start: 13, end: 14),
    Interval(start: 9, end: 10),
    Interval(start: 15, end: 17),
    Interval(start: 9, end: 11),
    Interval(start: 14, end: 15),
    Interval(start: 10, end: 12),
]
print(merge(meetings))
print(merge([]))
```

```output
[9-12, 13-17]
[]
```

- **Sorting by start** means that once the walk moves past a merged block, no later interval can reach back into it: every later interval starts at or after the current one.
- `interval.start <= last.end` decides whether the current interval joins the last block. It's `<=`, not `<`: 13–14 and 14–15 don't overlap, but for a busy-time display you want them shown as one continuous block. Merging touching intervals is a choice about the output, separate from the overlap test.
- `max(last.end, interval.end)` handles an interval contained in the block. Without `max`, a short meeting inside a long one would shrink the block.
- The sort is O(n log n) and the walk is O(n). `merged` is O(n) extra space.

## Selecting the most non-overlapping intervals

A single meeting room gets more requests than it can host. Accept as many as possible. This is the greedy problem from lesson 1 with a sort key to choose, and the obvious keys are wrong:

```swift
struct Interval: CustomStringConvertible {
    let start: Int
    let end: Int
    var description: String { "\(start)-\(end)" }
}

func mostBookings(_ requests: [Interval]) -> [Interval] {
    let byEnd = requests.sorted { $0.end < $1.end }
    var accepted: [Interval] = []
    for request in byEnd {
        if let last = accepted.last, request.start < last.end {
            continue
        }
        accepted.append(request)
    }
    return accepted
}

func greedyBy(_ requests: [Interval], _ areInOrder: (Interval, Interval) -> Bool) -> [Interval] {
    var accepted: [Interval] = []
    for request in requests.sorted(by: areInOrder) {
        let clashes = accepted.contains { request.start < $0.end && $0.start < request.end }
        if !clashes {
            accepted.append(request)
        }
    }
    return accepted
}

// Exhaustive: every subset, include or skip each request.
func mostBookingsByBruteForce(_ requests: [Interval]) -> Int {
    var best = 0
    var chosen: [Interval] = []
    func explore(_ i: Int) {
        if i == requests.count {
            best = max(best, chosen.count)
            return
        }
        explore(i + 1)
        let fits = !chosen.contains { requests[i].start < $0.end && $0.start < requests[i].end }
        if fits {
            chosen.append(requests[i])
            explore(i + 1)
            chosen.removeLast()
        }
    }
    explore(0)
    return best
}

let requests = [
    Interval(start: 9, end: 17),
    Interval(start: 9, end: 11),
    Interval(start: 10, end: 13),
    Interval(start: 11, end: 12),
    Interval(start: 12, end: 14),
    Interval(start: 13, end: 15),
    Interval(start: 14, end: 16),
]
print("earliest end:  ", mostBookings(requests))
print("earliest start:", greedyBy(requests) { $0.start < $1.start })
print("shortest first:", greedyBy(requests) { ($0.end - $0.start) < ($1.end - $1.start) })
print("best possible: ", mostBookingsByBruteForce(requests))

let tricky = [
    Interval(start: 9, end: 12),
    Interval(start: 11, end: 13),
    Interval(start: 12, end: 15),
]
print("shortest first:", greedyBy(tricky) { ($0.end - $0.start) < ($1.end - $1.start) })
print("earliest end:  ", mostBookings(tricky))
```

```output
earliest end:   [9-11, 11-12, 12-14, 14-16]
earliest start: [9-17]
shortest first: [11-12, 9-11, 12-14, 14-16]
best possible:  4
shortest first: [11-13]
earliest end:   [9-12, 12-15]
```

- **Earliest start** grabs the all-day 9–17 request because it starts first, and everything else clashes with it. One booking.
- **Shortest first** does fine on the first input, but on `tricky` it takes the short 11–13, which clashes with both of the others. One booking where two fit.
- **Earliest end** gets 4 on the first input, which the exhaustive search confirms is the best, and 2 on `tricky`.

In `mostBookings`, because requests come in order of end, comparing with the last accepted booking is enough: it's the one that ends latest. `greedyBy` has to check every accepted booking, since other orders give no such guarantee.

**Why earliest end is right**, as an exchange argument: let e be the request that ends first. Take any optimal schedule, and let f be its first booking. f ends no earlier than e, so every other booking in that schedule starts after f ends, hence after e ends. Replace f with e: nothing clashes, and the count is the same. So some optimal schedule starts with e. Remove e and everything that clashes with it, and what's left is the same problem, smaller. Ending earliest leaves the most room for everything else.

The "fewest requests to reject so the rest don't overlap" problem is the same one: reject `requests.count - mostBookings(requests).count`.

## How many rooms

Now every meeting must happen, and you want the fewest rooms. The answer is the largest number of meetings in progress at the same moment. To find it, you don't need to know which meeting ends when, only **how many** meetings have started and how many have ended at each point. Sort the starts and the ends separately and sweep:

```swift
struct Interval {
    let start: Int
    let end: Int
}

func roomsNeeded(_ meetings: [Interval]) -> Int {
    let starts = meetings.map { $0.start }.sorted()
    let ends = meetings.map { $0.end }.sorted()
    var inUse = 0
    var most = 0
    var e = 0
    for start in starts {
        while e < ends.count && ends[e] <= start {
            inUse -= 1
            e += 1
        }
        inUse += 1
        most = max(most, inUse)
    }
    return most
}

let meetings = [
    Interval(start: 9, end: 10),
    Interval(start: 9, end: 12),
    Interval(start: 10, end: 11),
    Interval(start: 11, end: 13),
    Interval(start: 11, end: 12),
    Interval(start: 12, end: 14),
]
print(roomsNeeded(meetings))
print(roomsNeeded([]))
```

```output
3
0
```

- Before a meeting takes a room, every meeting that has ended by its start gives one back. `ends[e] <= start` is the half-open convention: a room freed at 11 can host a meeting starting at 11.
- `inUse` is the number of meetings open right now; `most` is the peak. At 11, the 9–12, 11–13 and 11–12 meetings are all open: 3.
- Two sorts and one pass: O(n log n) time, O(n) space for the two arrays.

### Assigning rooms with a heap

The sweep gives the number, not the plan. To tell each meeting which room to use, keep the rooms in use in a **min-heap keyed by end time**, the priority queue from Module 19. Going through meetings by start, the room that frees up first is on top. If it's free by the time this meeting starts, reuse it; if not, no room is, so open a new one.

```swift
struct PriorityQueue<Element> {
    private var storage: [Element] = []
    private let comesFirst: (Element, Element) -> Bool

    init(by comesFirst: @escaping (Element, Element) -> Bool) {
        self.comesFirst = comesFirst
    }

    var peek: Element? { storage.first }

    mutating func push(_ element: Element) {
        storage.append(element)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard comesFirst(storage[child], storage[parent]) else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Element? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let top = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var first = parent
            if left < storage.count && comesFirst(storage[left], storage[first]) { first = left }
            if right < storage.count && comesFirst(storage[right], storage[first]) { first = right }
            if first == parent { break }
            storage.swapAt(parent, first)
            parent = first
        }
        return top
    }
}

struct Meeting {
    let title: String
    let start: Int
    let end: Int
}

func assignRooms(_ meetings: [Meeting]) -> [(title: String, room: Int)] {
    var roomsInUse = PriorityQueue<(end: Int, room: Int)>(by: { $0.end < $1.end })
    var roomCount = 0
    var plan: [(title: String, room: Int)] = []
    for meeting in meetings.sorted(by: { $0.start < $1.start }) {
        let room: Int
        if let earliest = roomsInUse.peek, earliest.end <= meeting.start {
            _ = roomsInUse.pop()
            room = earliest.room
        } else {
            roomCount += 1
            room = roomCount
        }
        roomsInUse.push((end: meeting.end, room: room))
        plan.append((meeting.title, room))
    }
    return plan
}

let meetings = [
    Meeting(title: "Standup", start: 9, end: 10),
    Meeting(title: "Design review", start: 9, end: 12),
    Meeting(title: "1:1", start: 10, end: 11),
    Meeting(title: "Planning", start: 11, end: 13),
    Meeting(title: "Interview", start: 11, end: 12),
    Meeting(title: "Lunch talk", start: 12, end: 14),
]
for entry in assignRooms(meetings) {
    print("Room \(entry.room): \(entry.title)")
}
```

```output
Room 1: Standup
Room 2: Design review
Room 1: 1:1
Room 1: Planning
Room 3: Interview
Room 2: Lunch talk
```

- The heap holds one `(end, room)` pair per room in use. `peek` shows the room that frees up first.
- When it's free by `meeting.start`, it's popped and reused; the new pair goes back in with this meeting's end.
- Otherwise even the earliest-ending room is busy, so every room is busy, and `roomCount` grows. It ends at 3, the same number the sweep found.
- Standup and Design review both start at 9 and stay in input order because Swift's sort is stable (Module 18). A heap isn't stable, which doesn't matter here: any free room is as good as another.
- Each meeting does at most one pop and one push: O(n log n) total, O(n) for the heap.

> [!tip] Which one in an interview
> Asked only for the number, write the sweep: no data structure to build, and it's easy to get right. Asked who goes where, or for a stream of meetings arriving in start order, use the heap. Both are O(n log n), dominated by the sort.

## Common mistakes

> [!error] Replacing the end instead of taking the max
> `Interval(start: last.start, end: interval.end)` works until an interval sits inside another. Merging 1–10 and 2–3 would give 1–3 and lose seven hours of busy time. Always `max(last.end, interval.end)`.

> [!error] Forgetting to sort
> The merge and the sweep both assume sorted input. Unsorted, the merge compares each interval with whatever happened to come before it, and the result depends on input order. If the input is "already sorted", say so in a comment, and say by what.

> [!error] Picking the sort key by intuition
> Sorting by start feels natural and is right for merging, and wrong for selecting. Sorting by length feels clever and is wrong for both. Run the counterexamples in this lesson against any key you're tempted by: one long interval, and one short interval straddling two others.

> [!error] Off-by-one on touching intervals
> Using `<` where you meant `<=` in the sweep (`ends[e] < start`) makes a meeting starting at 10 wait for a room that frees at 10. The result is one room too many whenever meetings are back to back. Decide the convention and use it in every comparison.

## Exercises

````exercise
id: m20-l02-e1
type: comprehension
prompt: To accept the most non-overlapping bookings for one room, why sort by end time instead of start time?
choices:
  - text: "The booking that ends first leaves the most time for the rest, and swapping it into any optimal schedule keeps that schedule valid."
    correct: true
    why: "That's the exchange argument: replace the first booking of an optimal schedule with the earliest-ending one, and nothing clashes."
  - text: "Sorting by end is faster than sorting by start."
    correct: false
    why: "Both are the same O(n log n) sort with a different key."
  - text: "Sorting by start would also be correct; end is just a convention."
    correct: false
    why: "Sorting by start takes a 9–17 booking first and blocks everything else. The lesson's input gives 1 booking instead of 4."
  - text: "Bookings that end first are the shortest ones."
    correct: false
    why: "Not necessarily, and sorting by length is itself wrong: the short 11–13 in the lesson blocks two others."
solution: |
  **The first.** The greedy rule needs a justification, and for earliest end there's a clean one: any optimal schedule can swap its first booking for the earliest-ending booking without creating a clash, because everything else in that schedule starts after its first booking ends, which is no earlier than the earliest end. Start time and length have counterexamples in the lesson.
````

````exercise
id: m20-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Interval: CustomStringConvertible {
      let start: Int
      let end: Int
      var description: String { "\(start)-\(end)" }
  }

  func merge(_ intervals: [Interval]) -> [Interval] {
      let sorted = intervals.sorted { $0.start < $1.start }
      var merged: [Interval] = []
      for interval in sorted {
          if let last = merged.last, interval.start <= last.end {
              merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
          } else {
              merged.append(interval)
          }
      }
      return merged
  }

  print(merge([
      Interval(start: 5, end: 8),
      Interval(start: 1, end: 4),
      Interval(start: 2, end: 3),
      Interval(start: 4, end: 5),
      Interval(start: 10, end: 12),
      Interval(start: 11, end: 15),
  ]))
output: |
  [1-8, 10-15]
hints:
  - "Sort by start first: 1-4, 2-3, 4-5, 5-8, 10-12, 11-15."
  - "2-3 is inside 1-4. 4-5 starts exactly where the block ends."
solution: |
  ```output
  [1-8, 10-15]
  ```

  Sorted: 1–4, 2–3, 4–5, 5–8, 10–12, 11–15.

  - 1–4 starts the first block.
  - 2–3 starts at 2 ≤ 4: joins, and `max(4, 3)` keeps the end at 4.
  - 4–5 starts at 4 ≤ 4: touching, joins. Block 1–5.
  - 5–8: touching again. Block 1–8.
  - 10–12 starts after 8: new block.
  - 11–15 starts at 11 ≤ 12: joins. Block 10–15.
````

````exercise
id: m20-l02-e3
type: fill-in
prompt: Complete the sweep that counts the rooms a set of meetings needs. Intervals are half-open.
code: |
  func roomsNeeded(_ meetings: [Interval]) -> Int {
      let starts = meetings.map { $0.start }.sorted()
      let ends = meetings.map { $0.end }.sorted()
      var inUse = 0
      var most = 0
      var e = 0
      for start in starts {
          while e < ends.count && ends[e] [[1]] start {
              inUse [[2]] 1
              e += 1
          }
          inUse += 1
          most = [[3]](most, inUse)
      }
      return most
  }
blanks:
  - id: "1"
    answers: ["<="]
  - id: "2"
    answers: ["-="]
  - id: "3"
    answers: ["max"]
solution: |
  - `<=`: a meeting that ends at 11 frees its room for one that starts at 11.
  - `-=`: each ended meeting gives a room back.
  - `max`: the answer is the peak number of rooms in use.

  ```swift
  struct Interval {
      let start: Int
      let end: Int
  }

  func roomsNeeded(_ meetings: [Interval]) -> Int {
      let starts = meetings.map { $0.start }.sorted()
      let ends = meetings.map { $0.end }.sorted()
      var inUse = 0
      var most = 0
      var e = 0
      for start in starts {
          while e < ends.count && ends[e] <= start {
              inUse -= 1
              e += 1
          }
          inUse += 1
          most = max(most, inUse)
      }
      return most
  }

  let backToBack = [Interval(start: 9, end: 10), Interval(start: 10, end: 11), Interval(start: 11, end: 12)]
  let allAtOnce = [Interval(start: 9, end: 12), Interval(start: 10, end: 11), Interval(start: 10, end: 12)]
  print(roomsNeeded(backToBack), roomsNeeded(allAtOnce))
  ```

  ```output
  1 3
  ```

  With `<` in blank 1, `backToBack` would need 2 rooms: at 10, the 9–10 meeting wouldn't have released its room yet.
````

````exercise
id: m20-l02-e4
type: find-errors
prompt: |
  This merge is supposed to combine overlapping or touching busy blocks. Which statements are true?
code: |
  func merge(_ intervals: [Interval]) -> [Interval] {
      var merged: [Interval] = []
      for interval in intervals {
          if let last = merged.last, interval.start <= last.end {
              merged[merged.count - 1] = Interval(start: last.start, end: interval.end)
          } else {
              merged.append(interval)
          }
      }
      return merged
  }
choices:
  - text: "It doesn't sort by start, so blocks that overlap but aren't adjacent in the input stay separate."
    correct: true
    why: "With 1-3, 8-10, 2-6, the 2-6 is compared only with 8-10. Since 2 <= 10, it's merged into it, producing the block 8-6. The result depends on input order."
  - text: "Taking interval.end instead of max(last.end, interval.end) shrinks a block when an interval lies inside it."
    correct: true
    why: "Sorted 1-10 then 2-3 would become 1-3."
  - text: "interval.start <= last.end should be < to merge touching blocks."
    correct: false
    why: "It's the other way round: <= merges touching blocks, which is what the prompt asks for."
  - text: "merged.last can't be used inside if let."
    correct: false
    why: "merged.last is an optional, and if let with a following condition is valid Swift."
rubric:
  - I identified the missing sort and showed an input where it matters.
  - I identified the missing max with a contained interval.
  - I rejected both distractors with a reason.
solution: |
  Two bugs. Without sorting, an interval is only compared with the last merged block, which may be anywhere on the timeline; with 1–3, 8–10, 2–6, the 2–6 gets "merged" into 8–10, producing the nonsense block 8–6. Without `max`, a contained interval cuts its block short. The fixed version:

  ```swift
  struct Interval: CustomStringConvertible {
      let start: Int
      let end: Int
      var description: String { "\(start)-\(end)" }
  }

  func merge(_ intervals: [Interval]) -> [Interval] {
      var merged: [Interval] = []
      for interval in intervals.sorted(by: { $0.start < $1.start }) {
          if let last = merged.last, interval.start <= last.end {
              merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
          } else {
              merged.append(interval)
          }
      }
      return merged
  }

  print(merge([Interval(start: 1, end: 3), Interval(start: 8, end: 10), Interval(start: 2, end: 6)]))
  print(merge([Interval(start: 1, end: 10), Interval(start: 2, end: 3)]))
  ```

  ```output
  [1-6, 8-10]
  [1-10]
  ```
````

````exercise
id: m20-l02-e5
type: solve
prompt: |
  A scheduling screen offers free slots for a new meeting. Write `func freeSlots(busy: [Interval], dayStart: Int, dayEnd: Int, minimum: Int) -> [Interval]` that returns the gaps of at least `minimum` minutes between `dayStart` and `dayEnd`, in order. `busy` is unsorted, may overlap and may extend past the day. Times are minutes after midnight; intervals are half-open.

  Use this `Interval` and print:

  ```output
  [540-570, 690-780, 960-1080]
  [540-1080]
  []
  ```

  for the busy list in the starter with `minimum: 30`, for an empty busy list, and for `[Interval(start: 480, end: 1200)]`, all with a day from 540 to 1080. (That's 9:00 to 18:00, with gaps at 9:00–9:30, 11:30–13:00 and 16:00–18:00.)
starter: |
  struct Interval: CustomStringConvertible {
      let start: Int
      let end: Int
      var description: String { "\(start)-\(end)" }
  }

  func freeSlots(busy: [Interval], dayStart: Int, dayEnd: Int, minimum: Int) -> [Interval] {
      // 1. Sort busy by start.
      // 2. Walk it with a cursor that starts at dayStart.
      // 3. A gap is cursor..<next.start when it's long enough.
      return []
  }

  let busy = [
      Interval(start: 600, end: 660),
      Interval(start: 780, end: 900),
      Interval(start: 570, end: 615),
      Interval(start: 900, end: 960),
      Interval(start: 660, end: 690),
  ]
hints:
  - "You don't need a separate merge. Keep `cursor`, the time up to which the day is known to be busy, and move it to max(cursor, block.end)."
  - "Clamp to the day: a gap ends at min(block.start, dayEnd), and the last gap runs from the cursor to dayEnd."
rubric:
  - The function sorts by start and walks once with a cursor, using max to handle overlaps and containment.
  - Gaps are clamped to the day and filtered by minimum.
  - The empty list and the all-day block give the expected lines.
  - O(n log n) time.
solution: |
  ```swift
  struct Interval: CustomStringConvertible {
      let start: Int
      let end: Int
      var description: String { "\(start)-\(end)" }
  }

  func freeSlots(busy: [Interval], dayStart: Int, dayEnd: Int, minimum: Int) -> [Interval] {
      var slots: [Interval] = []
      var cursor = dayStart
      for block in busy.sorted(by: { $0.start < $1.start }) {
          let gapEnd = min(block.start, dayEnd)
          if gapEnd - cursor >= minimum {
              slots.append(Interval(start: cursor, end: gapEnd))
          }
          cursor = max(cursor, block.end)
      }
      if dayEnd - cursor >= minimum {
          slots.append(Interval(start: cursor, end: dayEnd))
      }
      return slots
  }

  let busy = [
      Interval(start: 600, end: 660),
      Interval(start: 780, end: 900),
      Interval(start: 570, end: 615),
      Interval(start: 900, end: 960),
      Interval(start: 660, end: 690),
  ]
  print(freeSlots(busy: busy, dayStart: 540, dayEnd: 1080, minimum: 30))
  print(freeSlots(busy: [], dayStart: 540, dayEnd: 1080, minimum: 30))
  print(freeSlots(busy: [Interval(start: 480, end: 1200)], dayStart: 540, dayEnd: 1080, minimum: 30))
  ```

  ```output
  [540-570, 690-780, 960-1080]
  [540-1080]
  []
  ```

  `cursor` is the end of the merged busy time so far, which is the merge from the lesson without storing the merged blocks. Sorted by start, a gap can only appear between the cursor and the next block's start. `max` keeps a contained block (or an overlapping one) from moving the cursor backward. A block that starts before `dayStart` gives a negative gap, which the `>= minimum` check rejects; one that ends after `dayEnd` pushes the cursor past it, so the final gap is negative too. Sorting is O(n log n), the walk O(n).
````

````exercise
id: m20-l02-e6
type: explain
prompt: |
  The sweep below never knows which meeting ends at `ends[e]`; it might not even be a meeting that has started yet. Explain why it still returns the right number of rooms.
code: |
  func roomsNeeded(_ meetings: [Interval]) -> Int {
      let starts = meetings.map { $0.start }.sorted()
      let ends = meetings.map { $0.end }.sorted()
      var inUse = 0
      var most = 0
      var e = 0
      for start in starts {
          while e < ends.count && ends[e] <= start {
              inUse -= 1
              e += 1
          }
          inUse += 1
          most = max(most, inUse)
      }
      return most
  }
rubric:
  - I said the number of rooms in use at time t is (meetings started by t) minus (meetings ended by t), whatever their identities.
  - I explained that an end ≤ start belongs to a meeting that started earlier, since every meeting ends after it starts, so inUse never counts a release before its start.
  - I said the peak is reached right after some start, which is when the code samples it.
solution: |
  At any time t, the meetings in progress are those that started at or before t minus those that ended at or before t. That's a difference of two **counts**, and counts don't care which meeting is which. Sorting starts and ends separately preserves both counts at every t.

  Could the sweep release an end that belongs to a meeting that hasn't started? An end at or before the current start belongs to a meeting whose start is earlier still (each meeting's end is after its start), and every start earlier than the current one has already been counted. So `inUse` is exactly the number of open meetings right after each start. The peak can only rise when a meeting starts, so checking `most` after each start finds it.

  That's why the sweep can skip the heap: it answers "how many", and the counts are enough for that. Assigning rooms needs identities, which is what the heap version tracks.
````

## Summary

- Use **half-open** intervals and one overlap test: `a.start < b.end && b.start < a.end`. Ask whether touching intervals overlap before you code.
- **Merge**: sort by start, extend the last block with `max(last.end, current.end)` when `current.start <= last.end`, otherwise start a new block. O(n log n).
- **Most non-overlapping** (or fewest removals): sort by **end**, take each one that starts at or after the last taken one's end. Earliest start and shortest first both have counterexamples; the exchange argument backs earliest end.
- **Rooms needed**: sweep sorted starts and sorted ends, releasing every end ≤ the current start before occupying a room; the peak is the answer.
- **Room assignment**: a min-heap of `(end, room)`; reuse the top room when it's free, otherwise open one. Both are O(n log n).
