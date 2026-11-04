---
id: sliding-window-maximum
title: Sliding Window Maximum
difficulty: hard
order: 43
patterns: [Monotonic deque, Sliding window]
prerequisites: [m16-l04, m17-l02, m17-l05]
summary: Report the highest price in every window of k days in O(n). A running maximum can't forget the day that leaves; a deque of candidates can.
solutionFile: SlidingWindowMaximum.swift
testFile: SlidingWindowMaximumTests.swift
starter: |
  func slidingWindowMaximum(_ values: [Int], _ k: Int) -> [Int] {
      // Your solution
      return []
  }
time: O(n)
space: O(n)
edgeCases:
  - k equal to 1, which returns the input
  - k equal to the count, which returns one value
  - Strictly increasing and strictly decreasing input
  - Equal values, and negative values
  - k less than 1 or greater than the count, which returns []
askInterviewer:
  - What should happen if k is 0 or larger than the array?
  - Do you want the maximum's value or its index?
  - Is the data all available up front, or does it arrive as a stream?
hints:
  - Lesson m16-l04 explained why a running maximum can't be undone when the maximum leaves the window. Which earlier days could still become the maximum later?
  - If a later day has a price at least as high as an earlier day, can the earlier day ever be a window's maximum again?
  - "Keep the indexes of days that could still be a maximum, with decreasing prices from front to back. New days remove weaker ones from the back; expired days leave from the front."
  - The front of that structure is the current maximum. Removing from the front of an Array is O(n), so how do you remove it without shifting?
followUps:
  - How would you compute the window minimum at the same time?
  - "Why is this O(n) even though there's a loop inside the loop?"
  - How would you handle a stream where you only keep the last k values in memory? (A ring-buffer deque, lesson m17-l02.)
rubric:
  - I explained why the naive version is O(n · k) and why a running maximum fails.
  - I kept a deque of indexes with decreasing values and removed dominated indexes from the back.
  - I removed the front index when it left the window, without O(n) removeFirst.
  - I argued O(n) by counting each index's single entry and single exit.
codeStatus: tested
---

A stocks screen shows, for every window of `k` consecutive trading days, the highest closing price in that window. Write `slidingWindowMaximum(_:_:)` that returns the maximum of each window of `k` consecutive values, from left to right: `values.count - k + 1` results. If `k` is less than 1 or greater than `values.count`, return `[]`.

```swift
slidingWindowMaximum([4, 2, 12, 3, 8, 7, 1, 5], 3)   // [12, 12, 12, 8, 8, 7]
slidingWindowMaximum([9, 8, 7, 6], 2)                // [9, 8, 7]
slidingWindowMaximum([5], 1)                         // [5]
```

**Constraints:** `0 ≤ values.count ≤ 10^5`; `-10^4 ≤ values[i] ≤ 10^4`; `k` is any `Int`.

<!-- reveal -->

## First approach

The sliding window from lesson m16-l04 works when you can update the answer as one value joins and one leaves. A sum can; a maximum can't, because when the maximum leaves you don't know the runner-up. So keep the runners-up, but not all of them: if a later day's price is at least as high as an earlier day's, the earlier day will leave the window first and never be the maximum again. The days worth keeping have strictly decreasing prices from oldest to newest. New days remove weaker days from the newest end, like the monotonic stack in lesson m17-l05, and expired days leave from the oldest end, like a queue. A structure with both ends is a **deque**.

## Naive solution

Compute each window's maximum from scratch:

```swift
func slidingWindowMaximum(_ values: [Int], _ k: Int) -> [Int] {
    guard k >= 1, k <= values.count else { return [] }
    var maximums: [Int] = []
    for start in 0...(values.count - k) {
        maximums.append(values[start..<(start + k)].max() ?? 0)
    }
    return maximums
}
```

`values[start..<(start + k)]` is an `ArraySlice`, which doesn't copy. `max()` returns an optional; the window is never empty, so `?? 0` never applies.

## Problems with the naive solution

Each window costs k comparisons, and there are n − k + 1 windows: **O(n · k)**. With 100,000 days and k = 50,000 that's about 2.5 · 10^9 comparisons. Consecutive windows share k − 1 values, and the naive version recompares them all.

## Optimized solution

Keep a deque of **indexes** whose values decrease from front to back. For each new index:

1. Pop from the back every index whose value is less than or equal to the new value. They're dominated: the new value is at least as big and stays in the window longer.
2. Push the new index at the back.
3. If the front index has slid out of the window (it's `index - k` or earlier), drop it from the front.
4. Once the first window is complete, the front index holds the window's maximum.

Swift has no built-in deque, so this one is an Array plus a `head` index: the live part is `deque[head...]`. Dropping the front is `head += 1`, which is O(1) and moves nothing (lesson m17-l02). Removing from the back is `removeLast()`, as long as the live part isn't empty.

## Line by line

- `guard k >= 1, k <= values.count else { return [] }`: no valid windows. This also covers the empty array.
- `var deque: [Int] = []` and `var head = 0`: the live candidates are `deque[head..<deque.count]`.
- `maximums.reserveCapacity(values.count - k + 1)`: the result's final size is known, so it's allocated once.
- `while deque.count > head, let last = deque.last, values[last] <= value`: while the live part isn't empty and its newest candidate is dominated. `<=` also removes equal values, which is safe because the new one is newer and lasts longer.
- `deque.removeLast()`: O(1).
- `deque.append(index)`: the new index is always a candidate. After this, the live part isn't empty, so `deque[head]` is safe.
- `if deque[head] <= index - k { head += 1 }`: the window is `index - k + 1 ... index`. Indexes in the deque increase from front to back, and the previous step left the front at `index - k` or later, so at most one index expires per step and an `if` is enough.
- `if index >= k - 1 { maximums.append(values[deque[head]]) }`: from the k-th value on, every step completes a window, and the front holds its maximum because every live value behind it is smaller.

Each index is appended once and leaves at most once, from the back or by moving `head`: **O(n) time**. The array keeps every index it was given, including the ones `head` has passed, so it's **O(n) space**; the live part never holds more than k.

## Common mistakes

- Storing values instead of indexes. Then you can't tell when the front has left the window.
- Using `removeFirst()` to drop the front, which shifts the array and brings back O(n · k) in the worst case.
- Popping from the back while the value is strictly less, and keeping equal values. It still gives the right answer, but it keeps extra entries; with all-equal input the deque grows to k.
- Checking for expiry before pushing and forgetting that `deque[head]` can be read on an empty live part. Push first, then check the front.
- Reading `deque[head]` before the first window is complete and appending too many results.

## Variation

**Longest subarray where max − min ≤ limit**: a sliding window whose size varies. Keep two monotonic deques, one for the maximum and one for the minimum. Grow the window on the right; while `values[maxFront] - values[minFront] > limit`, move the left edge forward and drop deque fronts that fall behind it. Still O(n), because every index enters and leaves each deque once.
