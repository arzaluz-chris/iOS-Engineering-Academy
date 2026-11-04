---
id: remove-covered-intervals
title: Remove Covered Intervals
difficulty: medium
order: 41
patterns: [Intervals, Sort key choice, Running maximum]
prerequisites: [m20-l02, m16-l01]
summary: Count the do-not-disturb rules that aren't fully inside another rule. The right two-part sort key turns it into a running maximum.
solutionFile: RemoveCoveredIntervals.swift
testFile: RemoveCoveredIntervalsTests.swift
starter: |
  func uncoveredRangeCount(_ ranges: [Range<Int>]) -> Int {
      // Your solution
      return 0
  }
time: O(n log n)
space: O(n)
edgeCases:
  - An empty list and a single range
  - Two ranges with the same start, where the longer one covers the shorter
  - Two ranges with the same end, where the earlier start covers the later
  - Partial overlaps, which don't count as covering
  - A chain of ranges each nested in the next
askInterviewer:
  - Does a range cover itself? Can the list contain the same range twice?
  - Is a range that touches another, like 0..<10 and 10..<20, covered? (No, neither contains the other.)
  - Do you want the count or the surviving ranges?
hints:
  - "a is covered by b when b starts no later and ends no earlier. If you sorted by start, which ranges could cover a given range?"
  - "Sorted by start, every earlier range starts no later. So a range is covered exactly when some earlier range ends at or after its end. What single number tracks that?"
  - "Two ranges with the same start break that rule unless the longer one comes first. Sort by start ascending, then by end descending."
followUps:
  - Return the surviving ranges instead of the count.
  - What if duplicates are allowed and identical ranges should both be kept, or both removed?
  - How would you answer "how many ranges cover each range"? (Harder. It needs a sorted structure or a Fenwick tree over the ends.)
rubric:
  - I stated the covering condition precisely, with the equal-start and equal-end cases.
  - I sorted by start ascending and end descending, and explained why the tie-break matters.
  - I tracked the furthest end seen so far and counted ranges that extend past it.
  - I gave O(n log n) time and tested against the O(n²) pairwise check.
codeStatus: tested
---

A phone's Focus settings let users add do-not-disturb rules, each a half-open range of minutes in the day. A rule that's completely inside another rule adds nothing. Range `a` is **covered** by a different range `b` when `b.lowerBound <= a.lowerBound` and `a.upperBound <= b.upperBound`. Write `uncoveredRangeCount(_:)` that returns how many ranges are left after removing every covered range. All ranges are distinct.

```swift
uncoveredRangeCount([0..<30, 10..<20, 25..<40])   // 2: 10..<20 is inside 0..<30
uncoveredRangeCount([0..<10, 10..<20])            // 2: touching isn't covering
uncoveredRangeCount([5..<15, 5..<9, 2..<15])      // 1: 2..<15 covers both others
```

**Constraints:** `0 ≤ n ≤ 10^4`; ranges are non-empty and distinct; `0 ≤ lowerBound < upperBound ≤ 10^5`.

<!-- reveal -->

## First approach

Lesson m20-l02's lesson is that the sort key decides everything. If the ranges are sorted by start, any range that can cover range r comes before it, because a cover has to start no later. Then "is r covered?" becomes "does any earlier range end at or after r's end?", and the answer to that is a running maximum (lesson m16-l01). The only catch is ranges with the same start: the longer one must come first, or the shorter one won't see it.

## Naive solution

For each range, check every other range:

```swift
func uncoveredRangeCount(_ ranges: [Range<Int>]) -> Int {
    var kept = 0
    for (i, a) in ranges.enumerated() {
        let covered = ranges.indices.contains { j in
            j != i && ranges[j].lowerBound <= a.lowerBound && a.upperBound <= ranges[j].upperBound
        }
        if !covered {
            kept += 1
        }
    }
    return kept
}
```

## Problems with the naive solution

**O(n²)**: 10,000 rules mean 10^8 pair checks. It also makes you think about every arrangement of two ranges at once. The sorted version only ever asks one question per range.

## Optimized solution

Sort by start ascending and, for equal starts, by end descending. Walk the sorted list keeping `furthestEnd`, the largest end seen so far. A range whose end is at most `furthestEnd` is covered by the range that reached that end: that range came earlier, so it starts no later. A range whose end is beyond `furthestEnd` isn't covered by anything, so count it and raise `furthestEnd`.

## Line by line

- The sort's comparator: `$0.lowerBound != $1.lowerBound ? $0.lowerBound < $1.lowerBound : $0.upperBound > $1.upperBound`. Different starts: earlier first. Same start: longer first, so `5..<15` comes before `5..<9` and covers it.
- `var furthestEnd = Int.min`: smaller than any real end, so the first range always counts.
- `for range in sorted where range.upperBound > furthestEnd`: only ranges that reach past every earlier range. The others are covered and are skipped.
- `kept += 1` and `furthestEnd = range.upperBound`: this range survives, and it's now the one that reaches furthest. Covered ranges never raise `furthestEnd`, since their ends are at most its value.

The sort is O(n log n) and the walk O(n): **O(n log n) time, O(n) space** for the sorted copy.

## Common mistakes

- Sorting by start only. With `[5..<9, 5..<15]` in that order, `5..<9` is counted before `5..<15` is seen.
- Using `>=` in the `where` clause, which counts a range ending exactly at `furthestEnd` as uncovered even though the earlier range covers it.
- Comparing only with the previous range instead of the furthest end so far. In `[0..<30, 10..<20, 25..<28]`, `25..<28` isn't inside `10..<20` but is inside `0..<30`.
- Treating touching ranges as covered.

## Variation

**Minimum arrows**: each range is a balloon along a line; one arrow at position x bursts every balloon whose range contains x. Find the fewest arrows. Sort by end, shoot as far right as the first balloon allows, skip every balloon that arrow hits, and repeat. It's the earliest-end greedy from lesson m20-l02 with a different overlap condition.
