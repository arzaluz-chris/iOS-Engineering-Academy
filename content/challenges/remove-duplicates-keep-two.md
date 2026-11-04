---
id: remove-duplicates-keep-two
title: Remove Duplicates, Keeping Two
difficulty: easy
order: 11
patterns: [Two pointers, Read and write pointers, In place]
prerequisites: [m07, m15, m16-l03]
summary: Trim a sorted array in place so no value appears more than twice. A reader, a writer, and the right thing to compare against.
solutionFile: KeepTwoCopies.swift
testFile: KeepTwoCopiesTests.swift
starter: |
  func keepAtMostTwoCopies(_ sorted: inout [Int]) {
      // Your solution
  }
time: O(n)
space: O(1) extra
edgeCases:
  - Empty array, and arrays with one or two elements
  - Every value the same
  - Nothing to remove
  - Negative values
askInterviewer:
  - Is the array guaranteed to be sorted?
  - Do I have to work in place, or can I build a new array?
  - Should the array be shortened at the end, or do I return the new length?
  - Does the order of the kept elements have to stay the same?
hints:
  - "The lesson's removeDuplicates kept one copy by comparing with the last kept value. What do you compare with to allow two copies?"
  - "If the value you're reading equals the value two places behind the writer, the array is sorted, so both kept slots in between hold that same value."
  - "The first two elements are always kept. Make sure your comparison never reads index −1 or −2."
followUps:
  - How would you generalize to "at most k copies"?
  - Why does comparing with sorted[read - 2] instead of sorted[write - 2] give wrong answers?
  - What if the array weren't sorted but you still had to keep at most two copies of each value, in order?
rubric:
  - I used a reader and a writer instead of remove(at:) in a loop.
  - I compared with the element two places behind the writer and explained why that works in a sorted array.
  - I handled arrays shorter than three without a special case or a crash.
  - I trimmed the leftover tail and stated O(n) time and O(1) extra space.
codeStatus: tested
---

A fitness tracker stores sorted heart-rate readings, and a sync bug left many copies of some readings. Product decides to keep **at most two** copies of each value. Change the array **in place** so each value appears at most twice, keeping the remaining elements in sorted order, and shorten the array to fit.

Write `keepAtMostTwoCopies(_ sorted: inout [Int])`.

```swift
var readings = [1, 1, 1, 2, 2, 3]
keepAtMostTwoCopies(&readings)  // readings is now [1, 1, 2, 2, 3]

var more = [0, 0, 1, 1, 1, 1, 2, 3, 3]
keepAtMostTwoCopies(&more)      // [0, 0, 1, 1, 2, 3, 3]
```

**Constraints:** `0 ≤ sorted.count ≤ 3·10^4`; the array is sorted in non-decreasing order. Use O(1) extra memory.

<!-- reveal -->

## First approach

This is the read/write shape from the two pointers lesson. A reader visits every element; a writer marks where the next kept element goes. The only question is the rule for keeping an element: in a sorted array, a value already has two kept copies exactly when the element two slots behind the writer equals it.

## Naive solution

Walk the array and remove every third or later copy:

```swift
func keepAtMostTwoCopies(_ sorted: inout [Int]) {
    var index = 2
    while index < sorted.count {
        if sorted[index] == sorted[index - 2] {
            sorted.remove(at: index)
        } else {
            index += 1
        }
    }
}
```

It uses a `while` that only advances when it doesn't remove, so it doesn't crash the way a `for` over the original indices would.

## Problems with the naive solution

`remove(at:)` shifts every later element one place left, so each removal is O(n). With many removals, like an array of 3·10^4 copies of the same value, that's **O(n²)**: about 4.5·10^8 element moves.

## Optimized solution

Keep `write`, the number of elements kept so far. For each element, keep it if fewer than two elements are kept, or if it differs from `sorted[write - 2]`. Keeping means copying it to `sorted[write]` and moving `write` forward. At the end, drop everything from `write` on.

## Line by line

- `var write = 0`: `sorted[0..<write]` is the kept part, and it's always valid and sorted.
- `for read in sorted.indices`: the reader. `sorted.indices` is computed once as a range, which is fine here because the loop never changes the array's length.
- `write < 2 || sorted[read] != sorted[write - 2]`: the first two elements are always kept, and `||` short-circuits, so `write - 2` is never negative when it's evaluated.
- `sorted[read] != sorted[write - 2]`: the kept part is sorted, so if the element two slots back equals the current value, so does the one in between, and the value already has two copies.
- `sorted[write] = sorted[read]`: `write` never passes `read`, so this never overwrites an element that hasn't been read.
- `sorted.removeLast(sorted.count - write)`: drops the leftover tail. When nothing was removed, that's `removeLast(0)`, which does nothing.

## Common mistakes

- Comparing with `sorted[read - 2]` instead of `sorted[write - 2]`. The reader's neighborhood has already been overwritten. For `[1, 1, 1, 2, 2, 3]`, when the reader reaches the second 2 (index 4), the writer has already copied the first 2 over index 2, so `sorted[read - 2]` is 2 and the second 2 gets dropped. You need to compare with what was **kept**.
- Forgetting to trim the tail, which leaves stale values after the kept part.
- Calling `remove(at:)` inside a `for i in sorted.indices` loop: the range was computed for the original length and the loop runs past the end.

## Variation

**At most k copies:** replace 2 with `k` in both places: `write < k || sorted[read] != sorted[write - k]`. With `k = 1` it's the lesson's `removeDuplicates`.
