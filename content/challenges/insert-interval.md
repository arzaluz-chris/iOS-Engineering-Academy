---
id: insert-interval
title: Insert Interval
difficulty: medium
order: 40
patterns: [Intervals, Linear scan]
prerequisites: [m20-l02]
summary: Add one new range to a sorted list of disjoint ranges, merging whatever it overlaps. The list is already sorted, so one pass in three phases is enough.
solutionFile: InsertInterval.swift
testFile: InsertIntervalTests.swift
starter: |
  func insertRange(_ ranges: [Range<Int>], _ newRange: Range<Int>) -> [Range<Int>] {
      // Your solution
      return ranges
  }
time: O(n)
space: O(n) for the result
edgeCases:
  - An empty list
  - The new range before every range, or after every range
  - The new range covering every range
  - The new range inside an existing one
  - The new range touching a neighbor on either side, which merges
askInterviewer:
  - Are the ranges half-open? Do touching ranges merge?
  - Is the list sorted and free of overlaps before the insert?
  - Should I return a new array or modify the input in place?
hints:
  - Sorting everything again would work. What does the input already being sorted give you for free?
  - "The ranges fall into three groups: entirely before the new one, overlapping or touching it, and entirely after it. Where does each group go in the result?"
  - "While a range starts at or before the merged range's end, absorb it with min of the starts and max of the ends."
followUps:
  - How would you find the first affected range with binary search? Does it change the overall cost?
  - How would you remove a range instead (subtract it from the list)?
  - What structure would you use if inserts happened thousands of times per second? (A balanced tree keyed by start.)
rubric:
  - I used the existing order instead of sorting again.
  - I split the scan into before, overlapping and after, with the right comparisons for touching ranges.
  - I widened the merged range with min and max, so a new range inside an existing one is handled.
  - I gave O(n) time, and noted that binary search can find the position but copying still costs O(n).
codeStatus: tested
---

A video player tracks which parts of a file it has already downloaded, as a sorted list of half-open byte ranges with no overlaps and no touching neighbors (touching ones were already merged). When a new chunk arrives, its range has to be added. Write `insertRange(_:_:)` that returns the list with `newRange` included: still sorted, and with every range that overlaps or touches the new one merged into it.

```swift
insertRange([0..<100, 200..<300, 500..<600], 250..<520)   // [0..<100, 200..<600]
insertRange([0..<100, 500..<600], 300..<400)              // [0..<100, 300..<400, 500..<600]
insertRange([0..<100, 200..<300], 100..<200)              // [0..<300]: touching on both sides
```

**Constraints:** `0 ≤ ranges.count ≤ 10^4`; every range, including `newRange`, is non-empty; `0 ≤ lowerBound < upperBound ≤ 10^9`.

<!-- reveal -->

## First approach

Lesson m20-l02 merges an unsorted list by sorting by start and then walking. Here the list is already sorted and merged, and only one range is new. So the old ranges split into three groups, in order: those that end before the new range starts (untouched), those that overlap or touch it (merged into one), and those that start after it ends (untouched). One pass over the list visits them in exactly that order.

## Naive solution

Append the new range and redo the whole merge:

```swift
func insertRange(_ ranges: [Range<Int>], _ newRange: Range<Int>) -> [Range<Int>] {
    let sorted = (ranges + [newRange]).sorted { $0.lowerBound < $1.lowerBound }
    var merged: [Range<Int>] = []
    for range in sorted {
        if let last = merged.last, range.lowerBound <= last.upperBound {
            merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
        } else {
            merged.append(range)
        }
    }
    return merged
}
```

## Problems with the naive solution

It's correct, which makes it a good reference, but it sorts n + 1 ranges that were already in order except for one: **O(n log n)** where O(n) is possible. A player that receives a chunk every few milliseconds re-sorts its whole download map each time.

## Optimized solution

Walk the list once with one index. Phase 1 copies every range whose end is before the new range's start: `upperBound < newRange.lowerBound`. Strict, because a range ending exactly at the new start touches it and must merge. Phase 2 starts a merged range equal to `newRange`, and while the next range starts at or before the merged end, absorbs it: the start becomes the smaller start and the end the larger end. Then the merged range is appended. Phase 3 copies the rest.

## Line by line

- `while index < ranges.count && ranges[index].upperBound < newRange.lowerBound`: ranges that end strictly before the new one starts. `0..<100` and `100..<200` touch (100 isn't less than 100), so `0..<100` stops this phase.
- `var lower = newRange.lowerBound` and `var upper = newRange.upperBound`: the merged range so far, kept as two numbers because a `Range` is immutable.
- `while index < ranges.count && ranges[index].lowerBound <= upper`: the next range starts at or before the merged end, so it overlaps or touches. Phase 1 already guarantees it doesn't end before the new range starts.
- `lower = min(lower, ranges[index].lowerBound)`: only the first absorbed range can start earlier than the new one, but `min` handles it without a special case.
- `upper = max(upper, ranges[index].upperBound)`: the `max` matters when the new range is inside an existing one, like `20..<30` inside `10..<50`.
- `result.append(lower..<upper)`: exactly one merged range, even when nothing was absorbed.
- The last loop copies everything after it, already sorted and disjoint.

Each range is looked at once: **O(n) time**, and the result is **O(n) space**.

## Common mistakes

- Using `<=` in phase 1, which skips merging a range that touches the new one on the left.
- Replacing the end with the absorbed range's end instead of taking the `max`, which shrinks the merged range when the new one is larger.
- Appending the merged range inside the phase 2 loop, once per absorbed range.
- Forgetting the case where the new range goes at the very end: phase 2 absorbs nothing, and the merged range must still be appended.
- Binary searching for the insertion point and calling the whole thing O(log n). Building the result array still copies n ranges.

## Variation

**Remove a range** (the user deletes part of the cache): ranges that don't overlap it stay, a range that contains it splits into up to two pieces (`lower..<removed.lowerBound` and `removed.upperBound..<upper`), and a range inside it disappears. Same three-phase walk, with `clamped(to:)` or explicit bounds for the pieces.
