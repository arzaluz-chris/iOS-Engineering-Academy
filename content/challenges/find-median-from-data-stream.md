---
id: find-median-from-data-stream
title: Find Median from Data Stream
difficulty: hard
order: 76
patterns: [Heap, Two heaps, Streaming]
prerequisites: [m16-l01, m19-l04]
summary: Report the median after every new value without sorting again. Two heaps, one for each half, keep the middle within reach.
solutionFile: FindMedianFromDataStream.swift
testFile: FindMedianFromDataStreamTests.swift
starter: |
  struct RunningMedian {
      init() {}

      mutating func add(_ value: Int) {
          // Your solution
      }

      func median() -> Double? {
          // Your solution
          return nil
      }
  }
time: add O(log n), median O(1)
space: O(n)
edgeCases:
  - No values yet
  - Duplicates
  - Sorted or reverse-sorted input
  - Two values near Int.max, whose sum overflows Int
askInterviewer:
  - How often is the median requested compared with values being added?
  - What should the median be before any value arrives?
  - For an even count, do you want the average of the two middle values?
  - Is the range of values small? (That allows a counting approach.)
hints:
  - The median only depends on the middle one or two values. What do you need to know about the values below the middle, and above it?
  - Keep the smaller half and the larger half separately. Which value of each half do you need quick access to?
  - The largest of the smaller half and the smallest of the larger half. Which data structures give you those in O(1) and accept inserts in O(log n)? Then decide on a size rule for the two halves.
followUps:
  - If all values are between 0 and 100, how can you do it with O(1) work per call? (Counting array.)
  - Median of a sliding window of the last k values. (Two heaps with lazy deletion, or a balanced tree.)
  - What if 99% of the values are in a small range, and 1% are outliers?
rubric:
  - I split the values into a lower half in a max-heap and an upper half in a min-heap.
  - I kept a size invariant and rebalanced after every insert.
  - I computed the even-count median without integer overflow.
  - I gave O(log n) per add and O(1) per median, and compared with a sorted array.
codeStatus: tested
---

A video app shows the median buffering time of the current session, updated after every measurement. The median, not the average, so one terrible network hiccup doesn't swamp the number. The Module 16 lesson on linear traversal pointed out that a median needs every value you've seen. The question is how to keep them so the middle is cheap to find.

Write a `RunningMedian` struct:

- `add(_:)` records a value.
- `median()` returns the median of everything added so far: the middle value for an odd count, the average of the two middle values for an even count, and `nil` before the first value.

```swift
var stream = RunningMedian()
stream.median()  // nil
stream.add(5)
stream.median()  // 5.0
stream.add(15)
stream.median()  // 10.0
stream.add(1)
stream.median()  // 5.0
stream.add(3)
stream.median()  // 4.0: the middle two are 3 and 5
```

**Constraints:** up to `10^5` calls in total; values fit in `Int`.

<!-- reveal -->

## First approach

Imagine the values sorted and split in two at the middle. The median depends only on the largest value of the lower half and the smallest value of the upper half. You don't need either half to be sorted, only to have those two values at hand. A max-heap gives you the largest of a collection, and a min-heap the smallest.

## Naive solution

Keep a sorted array. Binary search finds where each new value belongs, and the median is read from the middle:

```swift
struct RunningMedian {
    private var sorted: [Int] = []

    mutating func add(_ value: Int) {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if sorted[middle] < value { low = middle + 1 } else { high = middle }
        }
        sorted.insert(value, at: low)
    }

    func median() -> Double? {
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return Double(sorted[middle]) }
        return (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
    }
}
```

## Problems with the naive solution

The median is O(1), and finding the position is O(log n), but `insert(_:at:)` shifts every element after that position: O(n) per add, O(n²) for n adds. For a few thousand values that's fine, and worth saying. For 10^5 values arriving one by one, it's billions of element moves.

## Optimized solution

Two heaps. `lower` is a max-heap with the smaller half; `upper` is a min-heap with the larger half. The rule: `lower` has the same number of values as `upper`, or one more. Then the median is `lower`'s top for an odd count, and the average of both tops for an even count.

To add a value, put it in `lower` if it's not bigger than `lower`'s top, otherwise in `upper`. Then, if a heap is too big, move its top to the other one. Every add is at most three heap operations: O(log n).

## Line by line

- `MedianHeap(by: >)`: one heap type with a comparison passed in. `>` puts the largest value on top (a max-heap); `<` puts the smallest on top.
- `if let lowerTop = lower.top, value > lowerTop { upper.push(value) } else { lower.push(value) }`: the first value, with `lower` empty, goes to `lower`.
- `if lower.count > upper.count + 1 { upper.push(lower.pop()!) }`: `lower` got two ahead, so its largest value moves up. The force unwrap is safe because `lower` isn't empty.
- `else if upper.count > lower.count { lower.push(upper.pop()!) }`: `upper` got ahead, so its smallest value moves down.
- `guard let lowerTop = lower.top else { return nil }`: no values yet.
- `if lower.count > upper.count { return Double(lowerTop) }`: odd count.
- `(Double(lowerTop) + Double(upper.top!)) / 2`: converting before adding avoids overflow when both values are near `Int.max`. `(a + b) / 2` in `Int` would trap.

## Common mistakes

- Putting every new value in `lower` and rebalancing by count only. The counts end up right but the halves get mixed: a large value can stay in `lower` while a smaller one sits in `upper`.
- Averaging in `Int` and losing the `.5`, or overflowing.
- Returning a median from an empty stream with `lower.top!`.

## Variation

**Sliding window median:** the median of the last k values. Values leave the window, and a binary heap can't remove an arbitrary element cheaply. One approach marks departed values in a dictionary and discards them only when they reach a heap's top (lazy deletion), keeping a separate count of each heap's valid size.
