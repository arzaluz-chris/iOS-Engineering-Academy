---
id: interval-list-intersections
title: Interval List Intersections
difficulty: medium
order: 39
patterns: [Intervals, Two pointers]
prerequisites: [m20-l02, m16-l03]
summary: Find the time two people are both free, given each one's sorted free slots. Two pointers walk the lists, and the range that ends first moves on.
solutionFile: IntervalListIntersections.swift
testFile: IntervalListIntersectionsTests.swift
starter: |
  func commonFreeTime(_ first: [Range<Int>], _ second: [Range<Int>]) -> [Range<Int>] {
      // Your solution
      return []
  }
time: O(n + m)
space: O(1) besides the result
edgeCases:
  - One list empty
  - Ranges that only touch, like 9..<10 and 10..<11, which share no time
  - Two ranges that end at the same moment
  - One range that covers several ranges of the other list
  - No overlap at all
askInterviewer:
  - Are the ranges half-open? Does 9..<10 overlap 10..<11?
  - Is each list sorted, and are its own ranges disjoint?
  - Should touching results be merged into one?
hints:
  - "Two half-open ranges overlap when each starts before the other ends. What's their intersection?"
  - Compare the first range of each list. After you've recorded their overlap (if any), one of them can't overlap anything else in the other list. Which one?
  - The range that ends first is done. Move only that pointer.
followUps:
  - How would you intersect k lists at once? (Pairwise, or a sweep over all endpoints with a counter.)
  - What changes with closed intervals, where a shared endpoint counts?
  - How would you compute the union of the two lists instead?
rubric:
  - I used the half-open overlap rule and computed the intersection with max of starts and min of ends.
  - I advanced the pointer whose range ends first and explained why that's safe.
  - I gave O(n + m) time without sorting.
  - I handled ranges that only touch.
codeStatus: tested
---

A scheduling assistant knows two people's free time as sorted lists of half-open ranges of minutes (`540..<600` is 9:00 to 10:00). Within each list, ranges are non-empty, sorted, and don't overlap or touch. Write `commonFreeTime(_:_:)` that returns the ranges when **both** are free, sorted.

```swift
commonFreeTime([9..<11, 13..<17], [10..<14, 16..<18])        // [10..<11, 13..<14, 16..<17]
commonFreeTime([8..<18], [9..<10, 12..<13, 15..<16])         // [9..<10, 12..<13, 15..<16]
commonFreeTime([9..<10], [10..<11])                          // []: they only touch
```

(The examples use hours to keep them short; the function doesn't care about units.)

**Constraints:** `0 ≤ n, m ≤ 10^4`; `0 ≤ lowerBound < upperBound ≤ 10^9`.

<!-- reveal -->

## First approach

Two ranges overlap when each one starts before the other one ends (lesson m20-l02), and then the overlap runs from the later start to the earlier end. Both lists are already sorted, so this looks like merging two sorted arrays: one index per list, and at each step decide which index moves. The range that ends first can't reach any later range of the other list, because those start even later. So it's finished.

## Naive solution

Intersect every pair, keep the non-empty results, and sort them. `Range` has `clamped(to:)`, which returns the part of one range inside another, or an empty range when they don't overlap:

```swift
func commonFreeTime(_ first: [Range<Int>], _ second: [Range<Int>]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    for a in first {
        for b in second {
            let overlap = a.clamped(to: b)
            if !overlap.isEmpty {
                result.append(overlap)
            }
        }
    }
    return result.sorted { $0.lowerBound < $1.lowerBound }
}
```

## Problems with the naive solution

It checks all n · m pairs: with two calendars of 10,000 slots, 10^8 comparisons, nearly all of which are between ranges that are hours apart. It also ignores that the inputs are sorted, and then pays to sort the output. Both inputs being sorted is what makes a linear walk possible.

## Optimized solution

Keep an index into each list. At each step, compute the overlap of the two current ranges: `max` of the lower bounds to `min` of the upper bounds. If that's non-empty, record it. Then advance the index whose range ends first; if both end at the same time, advancing either is fine, since the other one is then checked against the next range and found to be finished one step later. Stop when either list runs out: nothing is left to overlap.

## Line by line

- `while i < first.count && j < second.count`: once one list is used up, no more overlaps are possible.
- `let start = max(first[i].lowerBound, second[j].lowerBound)`: the later start.
- `let end = min(first[i].upperBound, second[j].upperBound)`: the earlier end.
- `if start < end { result.append(start..<end) }`: a non-empty overlap. With half-open ranges, `start == end` means they only touch, and `start..<end` would be empty. If `start > end`, writing `start..<end` would even crash, because a `Range` can't have its lower bound above its upper bound; the check comes first.
- `if first[i].upperBound < second[j].upperBound { i += 1 } else { j += 1 }`: the range that ends first is done. On a tie, `j` moves; `first[i]` is then compared once more with `second[j + 1]`, which starts after `first[i]` ends, so that comparison finds no overlap and moves `i`.

Each step advances one index, so there are at most n + m steps: **O(n + m) time**. Besides the result, **O(1) space**.

## Common mistakes

- Writing `start..<end` before checking `start < end`. Swift traps on a range whose lower bound is greater than its upper bound.
- Advancing both pointers every step, which skips overlaps when one long range covers several short ones.
- Advancing the pointer whose range **starts** first instead of the one that ends first.
- Using `<=` in the overlap test, which records empty ranges for slots that only touch.

## Variation

**Free time for a whole team**: given k people's busy ranges, find the slots when nobody is busy. Merge all busy ranges into one sorted list (lesson m20-l02's merge), then the gaps between consecutive merged ranges are the shared free time. With a min-heap over the k lists you can do it without concatenating them, in O(N log k) for N ranges.
