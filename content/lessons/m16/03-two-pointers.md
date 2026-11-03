---
id: m16-l03
title: Two pointers
description: You walk one array with two indexes instead of one, in the three shapes that come up again and again (from both ends inward, a reader and a writer moving the same way, and one index per array), state what each pointer guarantees, and turn O(n²) or O(n log n) solutions into O(n) passes with no extra memory.
module: m16
order: 3
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l02]
objectives:
  - "Recognize the signals for two pointers in a problem statement: sorted input, in place, pairs, merging."
  - Write the converging, read/write and two-sequence shapes, and say what each pointer guarantees.
  - Explain why a converging loop is correct by showing each step settles one element for good.
  - Compact an array in place in O(n) instead of calling remove(at:) in a loop.
  - Merge two sorted arrays in O(n + m) without losing the leftovers.
terms:
  - term: Two pointers
    definition: A technique that moves two indexes through one or two sequences, each step moving at least one of them, so the whole walk is O(n).
  - term: Converging pointers
    definition: One index starts at the beginning and one at the end, and they move toward each other until they meet.
  - term: Read/write pointers
    definition: Two indexes moving in the same direction through one array. The reader visits every element; the writer marks where the next kept element goes. Used to filter or compact in place.
  - term: In place
    definition: Changing the input array itself instead of building a new one, with O(1) extra space.
  - term: Merge
    definition: Combining two sorted sequences into one sorted sequence by repeatedly taking the smaller front element. O(n + m).
mastery:
  - Name the right shape (converging, read/write, two sequences) for a given problem.
  - Write the loop condition (< or <=) by deciding whether the last remaining element still needs handling.
  - State the invariant of a read/write compaction and implement it with inout.
  - Merge two sorted arrays and handle the leftovers of the longer one.
  - Give time and extra space for each shape and compare with the naive version.
resources: [swift-array, swift-book-control-flow, swift-book-functions, swift-book-collection-types]
cards:
  - id: m16-l03-c1
    front: What are the three common shapes of two pointers?
    back: "Converging (one at each end, moving inward), read/write (same direction: the reader visits everything, the writer marks where the next kept element goes), and two sequences (one index per array, as in merge)."
  - id: m16-l03-c2
    front: Why is a two-pointer walk O(n) even though it's a while loop with two indexes?
    back: Every pass moves at least one pointer forward (or inward), and neither ever moves back. Each can move at most n times, so the total number of passes is at most 2n.
  - id: m16-l03-c3
    front: What's the invariant of read/write compaction?
    back: "values[0..<write] holds exactly the kept elements from values[0..<read], in their original order. At the end, read == count, so the first write elements are the answer."
  - id: m16-l03-c4
    front: What's the classic bug in a merge of two sorted arrays?
    back: Stopping when one array runs out and forgetting to append the rest of the other. Elements disappear without any crash.
  - id: m16-l03-c5
    front: Why is calling remove(at:) in a loop to filter an array slow?
    back: Each remove(at:) shifts every later element left, O(n). Done for up to n elements, that's O(n²). A read/write pass, or removeAll(where:), is O(n).
---

## The idea in one sentence

Two indexes that each only move in one direction can scan pairs, filter in place or merge in **O(n)**, because together they make at most 2n moves.

## When to think "two pointers"

Signals in a problem statement:

- **"Sorted"**. Order tells you which way to move: if the current pair is too big, the big end has to move.
- **"In place", "without extra memory", "O(1) space"**. You can't build a new array, so you overwrite the old one as you go.
- **"Pairs" or "both ends"**: the first and the last, the smallest and the largest.
- **Two sorted inputs** to combine, compare or intersect.

The [Valid Palindrome](#/challenge/valid-palindrome) challenge is a two-pointer problem. This lesson uses different problems, so that one is still yours to solve.

There are three shapes, and most two-pointer solutions are one of them.

## Shape 1: converging pointers

A sensor app stores temperature differences from a baseline, sorted: `[-7, -3, -1, 2, 4, 6]`. You need their squares, sorted, for a chart.

**Naive version**: square everything, then sort.

```swift
let differences = [-7, -3, -1, 2, 4, 6]
let squares = differences.map { $0 * $0 }.sorted()
print(squares)
```

```output
[1, 4, 9, 16, 36, 49]
```

`map` is O(n), and `sorted()` is O(n log n) according to Apple's documentation, so this is **O(n log n)**. Correct, but it throws away the fact that the input was already sorted.

**The observation**: the squares are smallest in the middle (near zero) and largest at the **ends**, because the biggest absolute values are either the most negative number or the most positive one. So the largest remaining square is always at one of the two ends. Take it, and fill the result from the back:

```swift
func sortedSquares(_ sorted: [Int]) -> [Int] {
    var result = Array(repeating: 0, count: sorted.count)
    var left = 0
    var right = sorted.count - 1
    var write = sorted.count - 1
    while left <= right {
        let leftSquare = sorted[left] * sorted[left]
        let rightSquare = sorted[right] * sorted[right]
        if leftSquare > rightSquare {
            result[write] = leftSquare
            left += 1
        } else {
            result[write] = rightSquare
            right -= 1
        }
        write -= 1
    }
    return result
}

print(sortedSquares([-7, -3, -1, 2, 4, 6]))
print(sortedSquares([1, 2, 3]))
print(sortedSquares([-3, -2]))
print(sortedSquares([]))
```

```output
[1, 4, 9, 16, 36, 49]
[1, 4, 9]
[4, 9]
[]
```

Line by line:

1. `result` is allocated at full size so you can write into any position; you fill it from the end.
2. `left` and `right` mark the elements not yet placed: everything in `sorted[left...right]`.
3. `while left <= right`: as long as one element is unplaced. With `<`, the last element (when `left == right`) would never be written, and `result` would keep a 0 at the front.
4. Compare the two end squares, write the bigger one at `write`, and move the pointer that supplied it inward.
5. Each pass places exactly one element and moves `write` down by one.

The invariant: **`result[(write + 1)...]` holds the largest squares, sorted, and they came from the elements outside `sorted[left...right]`.** Each pass extends it by one, and when `left > right`, every element has been placed.

Why it's correct: every square still unplaced comes from `sorted[left...right]`, and the largest of those is at one of the two ends. So the bigger end square is the largest unplaced square, and it belongs at `write`. Each step settles one element for good, which is the argument behind every converging loop: **show that the element you drop can't be part of a better answer.**

Cost: n passes, O(1) each: **O(n) time**. The result is O(n) space, but that's the output; besides it, O(1).

The simplest converging loop is reversing an array in place, swapping the ends and moving inward. There the condition is `left < right`: when the pointers meet, the middle element is already where it belongs. Choosing between `<` and `<=` comes down to one question: **does the last remaining element still need handling?**

## Shape 2: read and write pointers

A reading app keeps a sorted list of page numbers the user bookmarked, and syncing from two devices left duplicates: `[3, 3, 8, 12, 12, 12, 40]`. Remove them in place.

**Naive version**: walk the array and call `remove(at:)` on each duplicate. Two problems. First, removing while looping over indices crashes, because the indices were computed for the original length:

```swift runtime-error Index out of range
var pages = [3, 3, 8, 12, 12, 12, 40]
for i in pages.indices.dropFirst() {
    if pages[i] == pages[i - 1] {
        pages.remove(at: i)
    }
}
print(pages)
```

`pages.indices` was evaluated once, as `0..<7`. After three removals the array has 4 elements, and the loop still asks for index 4. A `while` loop that only advances when it doesn't remove avoids the crash, but the second problem remains: **`remove(at:)` is O(n)**, because it shifts every later element one place left. Up to n removals of O(n) each is **O(n²)**.

**The pattern**: a **reader** visits every element; a **writer** marks where the next element to keep goes. Kept elements are copied down to the writer; the rest are skipped. Nothing shifts.

```swift
func removeDuplicates(from sorted: inout [Int]) {
    guard !sorted.isEmpty else { return }
    var write = 1
    for read in sorted.indices.dropFirst() where sorted[read] != sorted[write - 1] {
        sorted[write] = sorted[read]
        write += 1
    }
    sorted.removeLast(sorted.count - write)
}

var pages = [3, 3, 8, 12, 12, 12, 40]
removeDuplicates(from: &pages)
print(pages)

var single = [5]
removeDuplicates(from: &single)
print(single)

var none: [Int] = []
removeDuplicates(from: &none)
print(none)
```

```output
[3, 8, 12, 40]
[5]
[]
```

1. `inout` (Module 6) lets the function change the caller's array; the caller marks it with `&`.
2. The first element is always kept, so `write` starts at 1.
3. `sorted[write - 1]` is the last **kept** value. In a sorted array, a value is new exactly when it differs from it.
4. A new value is copied to `write`, and `write` moves on. Duplicates are skipped: only `read` moves.
5. At the end, the first `write` elements are the answer, and `removeLast(_:)` drops the leftover tail.

The invariant: **`sorted[0..<write]` holds the distinct values of `sorted[0..<read]`, in order.** The reader is always at or ahead of the writer, so copying down never overwrites an element that hasn't been read.

Cost: one pass, O(1) per element, plus one `removeLast(_:)` at the end: **O(n) time, O(1) extra space.**

> [!tip] When the standard library already does it
> For "remove every element that matches a condition", use `removeAll(where:)`. Its documentation lists O(n), so you get this pattern's cost without writing it. It doesn't help here, because "is a duplicate" depends on the previous kept element, not on the element alone.

## Shape 3: one pointer per sequence

A chat app has two lists of messages, each sorted by timestamp: the ones cached on the phone and new ones from the server. You need one list, sorted.

**Naive version**: `(local + remote).sorted { … }`, O((n + m) log(n + m)). It ignores that both halves are already sorted.

**The pattern**: compare the two front elements, take the smaller, and move that pointer. Each comparison places one message.

```swift
struct Message {
    let timestamp: Int
    let text: String
}

func merged(_ first: [Message], _ second: [Message]) -> [Message] {
    var result: [Message] = []
    result.reserveCapacity(first.count + second.count)
    var i = 0
    var j = 0
    while i < first.count && j < second.count {
        if first[i].timestamp <= second[j].timestamp {
            result.append(first[i])
            i += 1
        } else {
            result.append(second[j])
            j += 1
        }
    }
    result.append(contentsOf: first[i...])
    result.append(contentsOf: second[j...])
    return result
}

let local = [Message(timestamp: 10, text: "hi"), Message(timestamp: 30, text: "lunch?"),
             Message(timestamp: 70, text: "ok")]
let remote = [Message(timestamp: 20, text: "hey"), Message(timestamp: 30, text: "sure"),
              Message(timestamp: 50, text: "12:30"), Message(timestamp: 90, text: "see you")]
for message in merged(local, remote) {
    print(message.timestamp, message.text)
}
```

```output
10 hi
20 hey
30 lunch?
30 sure
50 12:30
70 ok
90 see you
```

1. `reserveCapacity` allocates room for every message once, so `append` never has to grow the array. It doesn't change the Big O; it saves reallocations.
2. The loop runs while **both** lists have messages left. Each pass appends one message and advances one pointer.
3. `<=` takes from `first` on a tie, so equal timestamps keep "local before remote". With `<`, the tie at 30 would put "sure" first. That property, keeping the original order among equals, is called **stability**.
4. When one list runs out, the other's remaining messages are all later than everything placed, and they're already sorted. `first[i...]` is the slice from `i` to the end, empty if `i == first.count`. Both lines run; at most one of them adds anything.

Cost: each message is appended exactly once, **O(n + m) time**, and O(n + m) for the result. Merging is also the core step of merge sort, in Module 18.

## Common mistakes

> [!error] Forgetting the leftovers after a merge
> The loop stops when **either** list runs out. Without the two `append(contentsOf:)` lines, the rest of the longer list silently disappears. No crash, just missing data.

> [!error] < versus <= in a converging loop
> Decide whether the element where the pointers meet still needs handling. Sorted squares must place it (`<=`); reversing in place must not swap it with itself (`<` is enough). Getting it wrong drops an element or handles one twice.

> [!error] A pass that moves no pointer
> If some branch doesn't advance `left`, `right`, `read` or a merge index, the loop repeats the same state forever. Check that every branch moves at least one pointer.

> [!error] Removing elements while looping over indices
> `for i in values.indices` evaluates the range once. After a `remove(at:)`, later indexes are past the end, and the loop crashes with `Index out of range`. Use read/write pointers or `removeAll(where:)`.

> [!error] Two pointers on unsorted input
> Converging and merging both rely on order to decide which pointer moves. On unsorted input they return wrong answers without crashing. Sort first (O(n log n)), or use a hash-based approach (lesson 5).

## Exercises

````exercise
id: m16-l03-e1
type: comprehension
prompt: "A problem says: \"Given an array of task IDs, move all tasks marked as done to the end, keeping the order of the others, without allocating a new array.\" Which shape fits best?"
choices:
  - text: Read/write pointers moving in the same direction
    correct: true
    why: "\"In place\" and \"keep the order\" are the signals. The reader visits every task and the writer packs the unfinished ones at the front, in order."
  - text: Converging pointers from both ends
    correct: false
    why: Swapping from the ends moves done tasks to the back, but it scrambles the order of the others.
  - text: One pointer per sequence, as in merge
    correct: false
    why: There's only one sequence, and nothing to merge.
  - text: Binary search
    correct: false
    why: There's no sorted order or monotonic condition to search.
solution: |
  **Read/write pointers.** The writer marks where the next unfinished task goes; the reader walks every task. Unfinished tasks are copied to the writer, preserving their order, and afterward the done tasks fill the rest. O(n) time, O(1) extra space. Converging swaps also put done tasks at the end in O(n), but a swap moves a task from the back to the front, past the others, so the order isn't kept. When order doesn't matter, converging is a fine choice.
````

````exercise
id: m16-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  var readings = [4, 0, 7, 0, 0, 3]
  var write = 0
  for read in readings.indices where readings[read] != 0 {
      readings[write] = readings[read]
      write += 1
  }
  print(readings, write)
  for index in write..<readings.count {
      readings[index] = 0
  }
  print(readings)
output: |
  [4, 7, 3, 0, 0, 3] 3
  [4, 7, 3, 0, 0, 0]
hints:
  - Only the nonzero readings are copied to write, and write only moves when one is copied.
  - The first loop never touches positions at or after the final write, so they keep their old values.
solution: |
  ```output
  [4, 7, 3, 0, 0, 3] 3
  [4, 7, 3, 0, 0, 0]
  ```

  The reader finds 4, 7 and 3 and copies them to positions 0, 1 and 2. After the loop, `write` is 3, and positions 3 to 5 still hold whatever was there: 0, 0 and the original 3. That stale tail is why the first print looks odd, and why every read/write pass needs a cleanup step: here, writing zeros to `write..<count` (which is an empty range if nothing was removed). The result moves the zeros to the end, keeping the other readings in order, in O(n) time and O(1) extra space.
````

````exercise
id: m16-l03-e3
type: find-errors
prompt: This merge of two sorted arrays loses data. Which statements are true?
code: |
  func merge(_ a: [Int], _ b: [Int]) -> [Int] {
      var result: [Int] = []
      var i = 0
      var j = 0
      while i < a.count && j < b.count {
          if a[i] < b[j] {
              result.append(a[i])
              i += 1
          } else {
              result.append(b[j])
              j += 1
          }
      }
      return result
  }

  print(merge([1, 4, 9], [2, 3]))
choices:
  - text: "It prints [1, 2, 3, 4] and drops the 9."
    correct: true
    why: When b runs out, the loop stops, and the rest of a is never appended.
  - text: "merge([], [5, 6]) returns an empty array."
    correct: true
    why: The loop condition is false from the start, and nothing appends b.
  - text: "It crashes with Index out of range when one array is longer."
    correct: false
    why: The condition checks both indexes before any subscript runs. It loses data; it doesn't crash.
  - text: "Using < instead of <= makes the result unsorted when there are equal values."
    correct: false
    why: "Equal values are taken from b first, but they're still in sorted order. For plain Ints the difference is invisible; for records it changes which equal one comes first (stability)."
rubric:
  - I identified the missing leftovers as the bug.
  - I showed an input where elements disappear.
  - I fixed it by appending the remaining slice of each array after the loop.
  - I noted that < versus <= only affects the order of equal elements.
solution: |
  The loop is right; what follows it is missing. When one array runs out, the other's remaining elements are larger than everything placed and already sorted, so they go on the end as they are:

  ```swift
  func merge(_ a: [Int], _ b: [Int]) -> [Int] {
      var result: [Int] = []
      var i = 0
      var j = 0
      while i < a.count && j < b.count {
          if a[i] <= b[j] {
              result.append(a[i])
              i += 1
          } else {
              result.append(b[j])
              j += 1
          }
      }
      result.append(contentsOf: a[i...])
      result.append(contentsOf: b[j...])
      return result
  }

  print(merge([1, 4, 9], [2, 3]))
  print(merge([], [5, 6]))
  print(merge([2, 2], [2]))
  ```

  ```output
  [1, 2, 3, 4, 9]
  [5, 6]
  [2, 2, 2]
  ```

  Changing `<` to `<=` isn't needed for correctness with integers. It makes the merge **stable**: on a tie, the element from the first array goes first, which matters when merging records.
````

````exercise
id: m16-l03-e4
type: fill-in
prompt: Complete this in-place reverse with converging pointers. It should print `["d", "c", "b", "a"] ["c", "b", "a"]`.
code: |
  func reverse(_ values: inout [String]) {
      var left = 0
      var right = values.count - 1
      while left [[1]] right {
          values.swapAt(left, right)
          left [[2]] 1
          right [[3]] 1
      }
  }

  var even = ["a", "b", "c", "d"]
  var odd = ["a", "b", "c"]
  reverse(&even)
  reverse(&odd)
  print(even, odd)
blanks:
  - id: "1"
    answers: ["<"]
  - id: "2"
    answers: ["+="]
  - id: "3"
    answers: ["-="]
solution: |
  ```swift
  func reverse(_ values: inout [String]) {
      var left = 0
      var right = values.count - 1
      while left < right {
          values.swapAt(left, right)
          left += 1
          right -= 1
      }
  }

  var even = ["a", "b", "c", "d"]
  var odd = ["a", "b", "c"]
  reverse(&even)
  reverse(&odd)
  print(even, odd)
  ```

  ```output
  ["d", "c", "b", "a"] ["c", "b", "a"]
  ```

  `swapAt(_:_:)` exchanges two elements of an array. `<` is enough: with an odd count, the pointers meet on the middle element, which is already in place. `<=` would also work here (swapping an element with itself does nothing), but it does one useless pass. For an empty array, `right` is -1 and the loop never runs. n / 2 swaps: O(n) time, O(1) extra space. The standard library's `reverse()` does the same job.
````

````exercise
id: m16-l03-e5
type: solve
prompt: |
  Two users each have a sorted list of the IDs of events they're attending, with no duplicates within a list. Write `func commonEvents(_ a: [Int], _ b: [Int]) -> [Int]` that returns the IDs in both lists, sorted, in O(n + m) time and without building a `Set`.

  Expected output for the starter's calls:

  ```output
  [4, 9]
  []
  []
  ```
starter: |
  func commonEvents(_ a: [Int], _ b: [Int]) -> [Int] {
      var result: [Int] = []
      // One index per list
      return result
  }

  print(commonEvents([1, 4, 6, 9, 12], [2, 4, 9, 15]))
  print(commonEvents([1, 2], [3, 4]))
  print(commonEvents([], [1]))
hints:
  - If a[i] < b[j], a[i] can't be in b (everything left in b is bigger). Move i.
  - On a match, append it and move both pointers.
rubric:
  - Moves the pointer at the smaller value, and both on a match.
  - Stops when either list runs out (no leftovers are needed here).
  - The output matches.
  - States O(n + m) time and O(1) extra space besides the result, and compares with the O(n · m) nested loop.
solution: |
  ```swift
  func commonEvents(_ a: [Int], _ b: [Int]) -> [Int] {
      var result: [Int] = []
      var i = 0
      var j = 0
      while i < a.count && j < b.count {
          if a[i] == b[j] {
              result.append(a[i])
              i += 1
              j += 1
          } else if a[i] < b[j] {
              i += 1
          } else {
              j += 1
          }
      }
      return result
  }

  print(commonEvents([1, 4, 6, 9, 12], [2, 4, 9, 15]))
  print(commonEvents([1, 2], [3, 4]))
  print(commonEvents([], [1]))
  ```

  ```output
  [4, 9]
  []
  []
  ```

  The smaller front value can't appear in the other list: everything left there is at least as big as its front, which is bigger. So it's safe to drop it. Unlike a merge, the leftovers don't matter: once one list is exhausted, nothing else can be common. Every pass moves at least one pointer, so there are at most n + m passes: **O(n + m) time, O(1) extra space** besides the result. Checking `b.contains` for each element of `a` would be O(n · m); a `Set` would be O(n + m) on average but with O(m) extra space and without needing sorted input.
````

````exercise
id: m16-l03-e6
type: explain
prompt: |
  In `sortedSquares`, the result is filled from the **back**, starting with the largest square. A teammate tries to fill it from the front, starting with the smallest, using the same two pointers at the ends. Explain why that can't work with this loop, and what you'd need instead to fill from the front.
code: |
  func sortedSquares(_ sorted: [Int]) -> [Int] {
      var result = Array(repeating: 0, count: sorted.count)
      var left = 0
      var right = sorted.count - 1
      var write = sorted.count - 1
      while left <= right {
          let leftSquare = sorted[left] * sorted[left]
          let rightSquare = sorted[right] * sorted[right]
          if leftSquare > rightSquare {
              result[write] = leftSquare
              left += 1
          } else {
              result[write] = rightSquare
              right -= 1
          }
          write -= 1
      }
      return result
  }
rubric:
  - I explained that the largest remaining square is always at one of the ends, but the smallest is near zero, in the middle.
  - I explained that the converging pointers can only see the two ends.
  - "I described the alternative: find the boundary between negatives and non-negatives (for example with a lower bound for 0) and walk two pointers outward from there."
  - I noted that the alternative is still O(n) (or O(log n) plus O(n)).
solution: |
  The loop works because of one fact: **the largest remaining square is always at one of the two ends.** The ends hold the most negative and the most positive remaining values, the ones with the biggest absolute value. Converging pointers only ever look at the ends, so they can find the largest, and the result has to be built from largest to smallest, back to front.

  The smallest square is where the values are closest to zero, which is in the **middle** of the array, where negatives turn into non-negatives. The end pointers can't see it, so filling from the front with this loop would write the wrong values.

  To fill from the front, start in the middle and move **outward**: find the first non-negative index (a lower bound for 0, O(log n), or a linear scan), set `left` just before it and `right` at it, and repeatedly take the smaller of the two squares, moving that pointer away from the center. Stop when both have gone past the ends, then append what's left on one side. That's a merge of two sorted sequences (the negatives read backward and the non-negatives read forward), and it's also O(n). It's more code for the same cost, which is why filling from the back is the usual answer.
````

## Summary

- Two pointers is O(n) because every pass moves at least one index and none moves back: at most 2n moves in total.
- Signals: **sorted**, **in place / O(1) space**, **pairs or both ends**, **two sorted inputs**.
- **Converging**: one pointer at each end, moving inward. Correct when you can show that the element you drop can't be part of a better answer. Sorted squares: O(n) instead of O(n log n).
- **Read/write**: the reader visits everything, the writer packs the kept elements at the front. Invariant: `values[0..<write]` holds the kept elements of `values[0..<read]`, in order. O(n) instead of the O(n²) of `remove(at:)` in a loop. Clean up the tail at the end.
- **One pointer per sequence**: merge and intersection of sorted inputs in O(n + m). After a merge loop, append the leftovers. Use `<=` on ties for a stable merge.
- Decide `<` versus `<=` by asking whether the last remaining element still needs handling, and check that every branch moves a pointer.
