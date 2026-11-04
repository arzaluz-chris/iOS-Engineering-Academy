---
id: merge-sorted-in-place
title: Merge Sorted Arrays in Place
difficulty: easy
order: 23
patterns: [Two pointers, One pointer per sequence, In place]
prerequisites: [m07, m15, m16-l03]
summary: Merge a sorted array into another one that has room at the end. Filling from the back is what makes it safe without extra memory.
solutionFile: MergeSortedInPlace.swift
testFile: MergeSortedInPlaceTests.swift
starter: |
  func mergeIntoFirst(_ first: inout [Int], count firstCount: Int, _ second: [Int]) {
      // Your solution
  }
time: O(n + m)
space: O(1) extra
edgeCases:
  - One or both arrays empty
  - Every value of second smaller than every value of first
  - Every value of second larger than every value of first
  - Duplicates across the two arrays, and negatives
askInterviewer:
  - What's in the placeholder slots, and can I overwrite them freely?
  - Are both inputs sorted in the same direction?
  - Is a stable order between equal values required?
  - Can I allocate a temporary array?
hints:
  - "Merging from the front means writing over values of first that you haven't read yet. Where is there free space?"
  - "The free slots are at the end, so place the largest values first: compare the last unplaced value of each array."
  - "When second runs out, you're done: the rest of first is already in place. Why isn't the same true when first runs out?"
followUps:
  - Why does the loop only need to run while second has values left?
  - "Which equal value goes last with `>` versus `>=`, and when would that matter?"
  - How does this step appear in merge sort, and why does merge sort usually use a buffer?
rubric:
  - I explained why merging from the front overwrites unread values.
  - I filled from the back with the larger of the two last values.
  - I stopped when second ran out and explained why first needs no copying.
  - I stated O(n + m) time and O(1) extra space.
codeStatus: tested
---

A photo app keeps the timestamps of an album sorted, in an array that already has room at the end for incoming photos. A second, sorted array arrives from the cloud. Merge it in **without allocating another array**.

`first` holds `firstCount` sorted values followed by `second.count` placeholder slots (their contents don't matter). After the call, `first` must hold all the values of both arrays, sorted.

Write `mergeIntoFirst(_ first: inout [Int], count firstCount: Int, _ second: [Int])`.

```swift
var album = [2, 5, 9, 0, 0, 0, 0]
mergeIntoFirst(&album, count: 3, [1, 5, 6, 12])
// album is now [1, 2, 5, 5, 6, 9, 12]

var empty = [0, 0]
mergeIntoFirst(&empty, count: 0, [3, 7])  // no values of its own, only two placeholders
// empty is now [3, 7]
```

**Constraints:** `0 ≤ firstCount, second.count ≤ 200`; `first.count == firstCount + second.count`; values between `-10^9` and `10^9`.

<!-- reveal -->

## First approach

The lesson's merge compared the two front elements and appended the smaller one to a new array. In place, writing the smallest value to `first[0]` would overwrite a value of `first` that hasn't been read. But the free slots are at the **end**. So merge backward: compare the two last unplaced values and write the larger one to the last free slot.

## Naive solution

Copy `second` into the placeholder slots and sort the whole array:

```swift
func mergeIntoFirst(_ first: inout [Int], count firstCount: Int, _ second: [Int]) {
    first.replaceSubrange(firstCount..<first.count, with: second)
    first.sort()
}
```

## Problems with the naive solution

It's correct and short, but it costs **O((n + m) log(n + m))** and throws away the fact that both halves are already sorted. And while `sort()` rearranges the array in place, its documentation doesn't promise O(1) extra memory, so it doesn't clearly meet the "no other array" requirement. In an interview it's a fine first answer to mention, and the expected next step is the linear merge.

## Optimized solution

Three indices: `i` at the last real value of `first`, `j` at the last value of `second`, and `write` at the last slot of `first`. While `second` has values left, write the larger of `first[i]` and `second[j]` to `first[write]`, and move that index and `write` one step left.

## Line by line

- `precondition(first.count == firstCount + second.count, ...)`: the problem's contract. A wrong call traps with a clear message instead of corrupting the array.
- `var i = firstCount - 1`, `var j = second.count - 1`: the last unplaced value of each array; −1 means that array is used up.
- `var write = first.count - 1`: the next slot to fill, from the back.
- `while j >= 0`: once `second` is used up, the values of `first` still unplaced are already sorted and already in their final positions, at the front. If `first` runs out first, the loop keeps copying from `second`.
- `if i >= 0 && first[i] > second[j]`: take from `first` only while it has values and its value is larger. On a tie, `second[j]` goes to the later slot, so equal values from `first` stay before equal values from `second`.
- Why it's safe: `write` is always `i + j + 1`, so `write > i` as long as `j >= 0`, and a write never lands on an unread value of `first`.

## Common mistakes

- Merging from the front into `first`, which overwrites values that haven't been compared yet.
- Looping `while i >= 0 && j >= 0` and then forgetting to copy the rest of `second` when `first` runs out first.
- Copying the rest of `first` after the loop. It's already where it belongs; the copy does nothing useful.

## Variation

**Merge k sorted arrays:** with more than two inputs, comparing every front on each step costs O(k) per element. A min-heap of the current fronts (Module 19) brings it to O(N log k) for N total elements.
