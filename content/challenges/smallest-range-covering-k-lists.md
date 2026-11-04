---
id: smallest-range-covering-k-lists
title: Smallest Range Covering K Lists
difficulty: hard
order: 77
patterns: [Heap, K-way merge, Sliding window over sorted streams]
prerequisites: [m16-l04, m19-l04]
summary: Find the narrowest range that contains a number from each of k sorted lists. The k-way merge from the heaps lesson, plus a running maximum, turns it into one pass.
solutionFile: SmallestRangeCoveringLists.swift
testFile: SmallestRangeCoveringListsTests.swift
starter: |
  func smallestRangeCoveringLists(_ lists: [[Int]]) -> ClosedRange<Int>? {
      // Your solution
      return nil
  }
time: O(N log k) for N numbers in k lists
space: O(k)
edgeCases:
  - A single list (the range is one number)
  - No lists, or an empty list (no range exists)
  - Two ranges of the same width (take the smaller start)
  - Duplicates and negative numbers
askInterviewer:
  - Is each list sorted? In which direction?
  - What do I return if a list is empty?
  - How do I break ties between two ranges of the same width?
  - How many lists, and how long is each?
hints:
  - Take the first number of every list. The smallest and largest of them form a range that covers every list. Is there any point in keeping the smallest one?
  - To find a narrower range, the start has to move up. Which list's cursor do you advance?
  - You need the smallest current front fast, and the largest current front too. One comes from a min-heap; the other only ever grows, so a variable is enough.
followUps:
  - Why can you stop as soon as one list runs out?
  - Solve it by merging all numbers with their list label and sliding a window that needs all k labels. What does that cost?
  - What if the lists are huge streams that don't fit in memory?
rubric:
  - I kept one cursor per list in a min-heap and tracked the maximum front separately.
  - I explained why advancing the minimum is the only move that can shrink the range.
  - I stopped when a list was exhausted and applied the tie rule.
  - I gave O(N log k) time and O(k) space.
codeStatus: tested
---

A monitoring tool collects timestamps of an event from k servers, each list sorted from earliest to latest. To line the logs up, it looks for the narrowest time window in which **every** server logged at least one event.

Write `smallestRangeCoveringLists(_:)`, which returns the smallest range `a...b` that contains at least one number from each list. Smallest means the smallest `b - a`; if two ranges tie, return the one with the smaller `a`. Return `nil` if there are no lists or any list is empty.

```swift
smallestRangeCoveringLists([[1, 9, 20], [4, 12, 30], [8, 14, 25]])  // 8...12: contains 9, 12 and 8
smallestRangeCoveringLists([[1, 2, 3], [1, 2, 3], [1, 2, 3]])       // 1...1
smallestRangeCoveringLists([[1, 10], [3, 12]])                      // 1...3: ties with 10...12, smaller start wins
smallestRangeCoveringLists([[4, 7], []])                            // nil
```

**Constraints:** `0 ≤ k ≤ 3,500`; each list has up to 50 numbers in non-decreasing order; `-10^5 ≤ number ≤ 10^5`.

<!-- reveal -->

## First approach

Put a cursor at the front of every list. The smallest and largest fronts make a range that covers every list. To find something narrower, the range's start has to go up, and the only way to move the smallest front up is to advance the cursor of the list it belongs to. Advancing any other cursor can only raise the maximum. So: repeatedly record the current range, then advance the list with the smallest front. That's the k-way merge from the heaps lesson in Module 19, with a running maximum added.

## Naive solution

Try every number as the start `a`. For each list, binary search for the first number that is at least `a`; the range must reach the largest of those.

```swift
func smallestRangeCoveringLists(_ lists: [[Int]]) -> ClosedRange<Int>? {
    guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return nil }

    func firstAtLeast(_ target: Int, in values: [Int]) -> Int? {
        var low = 0
        var high = values.count
        while low < high {
            let middle = (low + high) / 2
            if values[middle] < target { low = middle + 1 } else { high = middle }
        }
        return low < values.count ? values[low] : nil
    }

    var best: ClosedRange<Int>?
    for start in lists.joined() {
        var end = start
        var coversAll = true
        for values in lists {
            guard let reach = firstAtLeast(start, in: values) else {
                coversAll = false
                break
            }
            end = max(end, reach)
        }
        guard coversAll else { continue }
        if let current = best {
            let width = end - start
            let bestWidth = current.upperBound - current.lowerBound
            if width < bestWidth || (width == bestWidth && start < current.lowerBound) {
                best = start...end
            }
        } else {
            best = start...end
        }
    }
    return best
}
```

## Problems with the naive solution

For each of the N numbers it binary searches all k lists: O(N · k · log L), where L is the longest list. With 3,500 lists of 50 numbers, that's 175,000 starts times 3,500 binary searches: about 6 · 10^8 searches and several billion steps. It also repeats work: as the start moves up, each list's answer only moves forward, which the heap solution takes advantage of.

## Optimized solution

Keep a min-heap of cursors, one per list, ordered by value, and a variable with the largest current front. Pop the smallest cursor: the range from its value to the largest front covers every list, so compare it with the best so far. Then push that list's next number and update the largest front. When the popped list has nothing left, stop: every later range would have to skip that list. Each number is pushed and popped once, and the heap never holds more than k cursors: O(N log k).

## Line by line

- `guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return nil }`: with an empty list, no range can cover it.
- The first loop pushes every list's first number and records the largest front.
- `var best = heap.top!.value...largestFront`: the first covering range. The heap isn't empty, so the force unwrap is safe.
- `while let smallest = heap.pop()`: the list with the smallest front.
- `if largestFront - smallest.value < best.upperBound - best.lowerBound`: strictly smaller only. The popped values never decrease, so a later range of the same width has a start at least as large; keeping the earlier one applies the tie rule.
- `guard nextIndex < lists[smallest.list].count else { break }`: that list is used up. Any range starting higher would contain none of its numbers.
- `largestFront = max(largestFront, nextValue)`: the maximum only grows, so no second heap is needed.
- `RangeCursor` and `RangeCursorHeap`: the cursor and min-heap from the heaps lesson, specialized to compare by `value`.

## Common mistakes

- Advancing the list with the largest front instead of the smallest. That only widens the range.
- Continuing after a list is exhausted, and reporting a range that doesn't cover that list.
- Using a second heap for the maximum. It works, but the maximum never decreases, so a variable is enough.
- Updating the best range on `<=`, which breaks the tie rule.

## Variation

**Merge k sorted lists:** the same min-heap of cursors without the range bookkeeping. Each pop appends the smallest front to the output and pushes the next element from that list; O(N log k). With linked lists instead of arrays, the cursor is the list node itself.
