---
id: m18-l05
title: Merge sort
description: You build merge sort from its two halves, a recursive split and a two-pointer merge, trace it on a real array, derive O(n log n) from its recursion tree, account for its O(n) extra memory, make it stable on purpose, and use the merge step on its own to combine sorted feeds and to count inversions.
module: m18
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l04]
objectives:
  - Describe divide and conquer as split, solve the parts recursively, combine.
  - Write the merge of two sorted arrays with two pointers in O(n + m).
  - Write top-down merge sort and trace its splits and merges.
  - Derive O(n log n) time from log₂ n levels of O(n) work each, and O(n) extra space.
  - Keep merge sort stable by taking from the left half on ties, and make it generic over a comparator.
  - Reuse the merge step for merging sorted sources and counting inversions.
terms:
  - term: Divide and conquer
    definition: Solving a problem by splitting it into smaller independent subproblems of the same kind, solving those recursively, and combining their answers.
  - term: Merge
    definition: Combining two sorted sequences into one sorted sequence by repeatedly taking the smaller front element. O(n + m) for lengths n and m.
  - term: Merge sort
    definition: A sort that splits the array in half, sorts each half recursively, and merges the two sorted halves. O(n log n) time in every case, O(n) extra space, stable when ties are taken from the left.
  - term: Inversion
    definition: A pair of positions i < j whose elements are out of order, values[i] > values[j]. A sorted array has none; a reversed one has n(n − 1) / 2.
mastery:
  - Write merge and mergeSort from memory, with the correct base case and split.
  - Draw the recursion tree of merge sort for 8 elements and say how much work each level does.
  - Explain where merge sort's O(n) extra memory goes.
  - Show with a test that taking from the right on ties breaks stability.
  - Count inversions in O(n log n) by counting during the merge.
resources: [swift-array, swift-book-functions, swift-book-generics, swift-book-closures]
cards:
  - id: m18-l05-c1
    front: How does the merge step work, and what does it cost?
    back: Two indices, one per sorted input. Compare the fronts, append the smaller, advance that index; when one input runs out, append the rest of the other. O(n + m) time, one comparison per element appended at most.
  - id: m18-l05-c2
    front: Why is merge sort O(n log n) for every input?
    back: The halving gives about log₂ n levels in the recursion tree, and the merges on each level touch all n elements once. The split doesn't depend on the values, so there's no bad input.
  - id: m18-l05-c3
    front: What's merge sort's extra space?
    back: O(n) for the merged arrays (a single buffer of n in a careful implementation) plus O(log n) of call stack. It isn't in place.
  - id: m18-l05-c4
    front: How do you keep merge sort stable?
    back: "On a tie, take from the left half. With <, write if left[i] <= right[j]; with a predicate, take from the right only if areInIncreasingOrder(right[j], left[i])."
  - id: m18-l05-c5
    front: How do you count inversions in O(n log n)?
    back: During the merge, whenever you take right[j] before left[i], every element still waiting in the left half is bigger than right[j], so add left.count − i to the count.
---

## The idea in one sentence

Merge sort splits the array in half, sorts each half by trusting the recursion, and **merges** the two sorted halves in a single pass, and because the split never depends on the values, it's O(n log n) on every input.

## Divide and conquer

Merge sort is the standard example of **divide and conquer**:

1. **Divide** the problem into smaller problems of the same kind: two halves.
2. **Conquer** each one recursively. A piece of size 0 or 1 is already sorted: that's the base case.
3. **Combine** the answers: merge two sorted halves into one sorted whole.

All the real work is in step 3, so start there.

## The merge step

Two sorted arrays, two indices. Compare the elements at the front, take the smaller one, move that index forward:

```swift
func merge(_ left: [Int], _ right: [Int]) -> [Int] {
    var result: [Int] = []
    result.reserveCapacity(left.count + right.count)
    var i = 0
    var j = 0
    while i < left.count && j < right.count {
        if left[i] <= right[j] {
            result.append(left[i])
            i += 1
        } else {
            result.append(right[j])
            j += 1
        }
    }
    result.append(contentsOf: left[i...])
    result.append(contentsOf: right[j...])
    return result
}

print(merge([1, 4, 9], [2, 3, 10, 11]))
print(merge([], [5, 6]))
```

```output
[1, 2, 3, 4, 9, 10, 11]
[5, 6]
```

- It's the two-pointer pattern from Module 16, on two arrays instead of two ends of one.
- Each comparison appends one element, so there are at most n + m − 1 comparisons: **O(n + m)** time.
- When one side runs out, the rest of the other side is already sorted and bigger than everything taken, so it's appended in one go. `left[i...]` is an empty slice when `i == left.count`, so no `if` is needed.
- `reserveCapacity` allocates the result's storage once instead of growing it (Module 15).
- `<=`, not `<`: on a tie, the **left** element goes first. That's what will make the sort stable.

## Merge sort

```swift
func merge(_ left: [Int], _ right: [Int]) -> [Int] {
    var result: [Int] = []
    result.reserveCapacity(left.count + right.count)
    var i = 0
    var j = 0
    while i < left.count && j < right.count {
        if left[i] <= right[j] {
            result.append(left[i])
            i += 1
        } else {
            result.append(right[j])
            j += 1
        }
    }
    result.append(contentsOf: left[i...])
    result.append(contentsOf: right[j...])
    return result
}

func mergeSort(_ values: [Int], depth: Int = 0) -> [Int] {
    if values.count <= 1 {
        return values
    }
    let indent = String(repeating: "  ", count: depth)
    let middle = values.count / 2
    let left = mergeSort(Array(values[..<middle]), depth: depth + 1)
    let right = mergeSort(Array(values[middle...]), depth: depth + 1)
    let merged = merge(left, right)
    print("\(indent)merge \(left) + \(right) -> \(merged)")
    return merged
}

print(mergeSort([38, 27, 43, 3, 9, 82, 10]))
```

```output
    merge [27] + [43] -> [27, 43]
  merge [38] + [27, 43] -> [27, 38, 43]
    merge [3] + [9] -> [3, 9]
    merge [82] + [10] -> [10, 82]
  merge [3, 9] + [10, 82] -> [3, 9, 10, 82]
merge [27, 38, 43] + [3, 9, 10, 82] -> [3, 9, 10, 27, 38, 43, 82]
[3, 9, 10, 27, 38, 43, 82]
```

- **Base case:** 0 or 1 elements are sorted. `<= 1` covers the empty array too.
- **Split:** `middle = values.count / 2`. For 7 elements, the left half gets 3 and the right half 4. Both halves are strictly smaller than the whole as long as the count is at least 2, which is exactly when this line runs.
- **Trust the recursion:** `left` and `right` come back sorted. The function doesn't care how.
- **Combine:** one merge.
- The trace prints each merge after its two halves are done, so the deepest merges come first and the top-level merge last. The indentation is the depth.

`Array(values[..<middle])` copies each half into a new array, which is simple and costs O(n) per level. A version that works on index ranges of one array avoids those copies; the merge itself still needs somewhere to put its output.

## Why it's O(n log n)

Draw the recursion tree for 8 elements:

```text
level 0:            [8 elements]                 merges 8 elements
level 1:      [4]               [4]              merges 4 + 4 = 8
level 2:   [2]    [2]       [2]    [2]           merges 2 + 2 + 2 + 2 = 8
level 3:  [1][1] [1][1]   [1][1] [1][1]          base cases
```

- The size halves at each level, so there are about **log₂ n levels** (3 for 8, 10 for 1,024, 20 for a million).
- At every level, the merges together touch **all n elements** once: O(n) per level.
- log₂ n levels × O(n) each = **O(n log n)**.

The split is by position, never by value, so the tree has the same shape for sorted, reversed or random input. The number of comparisons changes a little (a merge stops comparing as soon as one side runs out), but it's always about n log₂ n or less. Measured on 1,000 elements, against insertion sort's counts from lesson 4:

```swift
func merge(_ left: [Int], _ right: [Int], comparisons: inout Int) -> [Int] {
    var result: [Int] = []
    result.reserveCapacity(left.count + right.count)
    var i = 0
    var j = 0
    while i < left.count && j < right.count {
        comparisons += 1
        if left[i] <= right[j] {
            result.append(left[i])
            i += 1
        } else {
            result.append(right[j])
            j += 1
        }
    }
    result.append(contentsOf: left[i...])
    result.append(contentsOf: right[j...])
    return result
}

func mergeSort(_ values: [Int], comparisons: inout Int) -> [Int] {
    if values.count <= 1 {
        return values
    }
    let middle = values.count / 2
    let left = mergeSort(Array(values[..<middle]), comparisons: &comparisons)
    let right = mergeSort(Array(values[middle...]), comparisons: &comparisons)
    return merge(left, right, comparisons: &comparisons)
}

let inputs = [
    ("sorted", Array(0..<1_000)),
    ("reversed", Array((0..<1_000).reversed())),
    ("shuffled", (0..<1_000).map { ($0 * 7_919) % 1_000 }),
]
for (name, input) in inputs {
    var comparisons = 0
    let result = mergeSort(input, comparisons: &comparisons)
    print(name, comparisons, result == Array(0..<1_000))
}
```

```output
sorted 4932 true
reversed 5044 true
shuffled 8415 true
```

| 1,000 elements | Insertion sort (lesson 4) | Merge sort |
| --- | --- | --- |
| sorted | 999 | 4,932 |
| shuffled | 251,100 | 8,415 |
| reversed | 499,500 | 5,044 |

Merge sort never has a bad day. It also never has a great one: on already sorted input, insertion sort wins. Some library sorts take advantage of both by detecting runs that are already in order and merging them.

### Where the memory goes

Merge sort is **not in place**. The merge writes into a separate array, so at the top level you hold the n-element result alongside the two halves. In this version the copies made on the way down add more, but at any moment the arrays alive are bounded by a constant times n, so it's **O(n) extra space**. The recursion adds O(log n) frames of call stack, because the depth is the number of levels. A careful implementation allocates one n-element buffer once and merges back and forth between it and the original.

## Stability, on purpose

Merge sort is stable **if** the merge takes from the left half on ties. Every element of the left half started before every element of the right half, so taking left first keeps tied elements in their original order. A generic version with a predicate, like `sorted(by:)`:

```swift
func mergeSorted<Element>(_ values: [Element], by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
    if values.count <= 1 {
        return values
    }
    let middle = values.count / 2
    let left = mergeSorted(Array(values[..<middle]), by: areInIncreasingOrder)
    let right = mergeSorted(Array(values[middle...]), by: areInIncreasingOrder)

    var result: [Element] = []
    result.reserveCapacity(values.count)
    var i = 0
    var j = 0
    while i < left.count && j < right.count {
        if areInIncreasingOrder(right[j], left[i]) {
            result.append(right[j])
            j += 1
        } else {
            result.append(left[i])
            i += 1
        }
    }
    result.append(contentsOf: left[i...])
    result.append(contentsOf: right[j...])
    return result
}

let tasks = [("Fix login", 2), ("Update icon", 1), ("Review PR", 2), ("Write tests", 1), ("Ship build", 2)]
let byPriority = mergeSorted(tasks) { $0.1 < $1.1 }
print(byPriority.map { $0.0 })
print(mergeSorted([5, 3, 8, 1]) { $0 > $1 })
```

```output
["Update icon", "Write tests", "Fix login", "Review PR", "Ship build"]
[8, 5, 3, 1]
```

The test `areInIncreasingOrder(right[j], left[i])` asks "does the right element strictly belong first?" Only then does it take from the right. On a tie the predicate returns `false`, and the left element goes first. Same output as Swift's `sorted(by:)` in lesson 4, as a stable sort must give.

The closure parameter isn't `@escaping`: it's only called during the function and passed down to the recursive calls, which is allowed for a non-escaping closure (Module 11).

## A practical example: merging two sorted feeds

The merge step is useful on its own, without the sort. A chat screen shows messages from the local cache and new messages from the server, each list already sorted by time. Merging them is O(n + m), where sorting the concatenation would be O((n + m) log(n + m)):

```swift
struct Message {
    let time: Int
    let text: String
    let source: String
}

func mergeByTime(_ local: [Message], _ server: [Message]) -> [Message] {
    var result: [Message] = []
    result.reserveCapacity(local.count + server.count)
    var i = 0
    var j = 0
    while i < local.count && j < server.count {
        if server[j].time < local[i].time {
            result.append(server[j])
            j += 1
        } else {
            result.append(local[i])
            i += 1
        }
    }
    result.append(contentsOf: local[i...])
    result.append(contentsOf: server[j...])
    return result
}

let local = [
    Message(time: 900, text: "Morning", source: "local"),
    Message(time: 930, text: "Draft saved", source: "local"),
    Message(time: 1000, text: "On my way", source: "local"),
]
let server = [
    Message(time: 915, text: "Hi!", source: "server"),
    Message(time: 1000, text: "See you", source: "server"),
    Message(time: 1030, text: "Here", source: "server"),
]
for message in mergeByTime(local, server) {
    print(message.time, message.source, message.text)
}
```

```output
900 local Morning
915 server Hi!
930 local Draft saved
1000 local On my way
1000 server See you
1030 server Here
```

Two messages at 1000: the local one comes first because ties take from the first list. Which one should win is a product decision; the code makes it explicit and testable. Merging k sorted lists pairwise, or with a heap (Module 19), is the same idea scaled up.

## Common mistakes

> [!error] Base case of count == 0
> With `if values.count == 0`, a one-element array splits into `[]` and itself, and the call on itself splits the same way forever, until the stack overflows. The base case has to include 1: `values.count <= 1`.

> [!error] Taking from the right on ties
> `if left[i] < right[j]` (instead of `<=`) sends equal elements from the right half first. The numbers still come out sorted, so tests on plain integers pass, and records with equal keys come out reordered. Test stability with records that tie.

> [!error] Forgetting the leftovers
> When the loop ends, one side still has elements. Without the two `append(contentsOf:)` lines, they're silently dropped and the result is shorter than the input. A test that compares `result.count` to the input's count catches it.

> [!error] Claiming merge sort is in place
> It's O(n log n) time with O(n) extra space. When memory is the constraint, that matters; lesson 6's quicksort trades stability for sorting in place.

## Exercises

````exercise
id: m18-l05-e1
type: comprehension
prompt: |
  You merge-sort an array of 1,000,000 `Int`s with a careful implementation that allocates one buffer. Which statement about its cost is right?
choices:
  - text: "O(n log n) time, O(n) extra memory for the buffer, and about 20 levels of recursion."
    correct: true
    why: "log₂ of a million is about 20, each level merges all n elements, and the merge needs a buffer of n."
  - text: "O(n log n) time and O(1) extra memory, because the buffer is reused."
    correct: false
    why: "Reusing one buffer avoids repeated allocations, but the buffer itself is n elements: O(n)."
  - text: "O(n²) time on reversed input."
    correct: false
    why: "The split is by position, so every input gives the same tree. Reversed input is O(n log n) like any other."
  - text: "O(n log n) time and about 1,000,000 levels of recursion."
    correct: false
    why: "That's the depth of a recursion that removes one element per call. Halving gives about 20 levels."
solution: |
  **O(n log n) time, O(n) extra memory, about 20 levels deep.** The depth is log₂ 1,000,000 ≈ 20, so the call stack is never a concern, unlike lesson 1's one-element-per-call `sum`. The memory is: 1,000,000 `Int`s is 8 MB of buffer on a 64-bit device, on top of the array itself.
````

````exercise
id: m18-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  func merge(_ left: [Int], _ right: [Int]) -> (merged: [Int], comparisons: Int) {
      var result: [Int] = []
      var comparisons = 0
      var i = 0
      var j = 0
      while i < left.count && j < right.count {
          comparisons += 1
          if left[i] <= right[j] {
              result.append(left[i])
              i += 1
          } else {
              result.append(right[j])
              j += 1
          }
      }
      result.append(contentsOf: left[i...])
      result.append(contentsOf: right[j...])
      return (result, comparisons)
  }

  print(merge([2, 5, 7], [1, 5, 6, 9]))
  print(merge([1, 2, 3], [10, 20]))
output: |
  (merged: [1, 2, 5, 5, 6, 7, 9], comparisons: 6)
  (merged: [1, 2, 3, 10, 20], comparisons: 3)
hints:
  - "Count one comparison per element appended inside the loop. The loop ends when either side is used up."
  - "In the second call, the left side runs out after three comparisons."
solution: |
  ```output
  (merged: [1, 2, 5, 5, 6, 7, 9], comparisons: 6)
  (merged: [1, 2, 3, 10, 20], comparisons: 3)
  ```

  First call, comparing fronts: 2 vs 1 (take 1), 2 vs 5 (take 2), 5 vs 5 (tie, take the left 5), 7 vs 5 (take the right 5), 7 vs 6 (take 6), 7 vs 9 (take 7). The left side is used up after 6 comparisons, and 9 is appended without one. Second call: 1, 2 and 3 each beat 10, and then the left is empty, so 10 and 20 are appended. 3 comparisons for 5 elements: merging is cheap when one side is entirely smaller.
````

````exercise
id: m18-l05-e3
type: fill-in
prompt: Complete merge sort.
code: |
  func mergeSort(_ values: [Int]) -> [Int] {
      if values.count [[1]] {
          return values
      }
      let middle = [[2]]
      let left = mergeSort(Array(values[..<middle]))
      let right = mergeSort(Array(values[[[3]]]))
      return merge(left, right)
  }
blanks:
  - id: "1"
    answers: ["<= 1", "<=1", "< 2", "<2"]
  - id: "2"
    answers: ["values.count / 2", "values.count/2"]
  - id: "3"
    answers: ["middle...", "middle..<values.count"]
solution: |
  ```swift
  func merge(_ left: [Int], _ right: [Int]) -> [Int] {
      var result: [Int] = []
      var i = 0
      var j = 0
      while i < left.count && j < right.count {
          if left[i] <= right[j] {
              result.append(left[i])
              i += 1
          } else {
              result.append(right[j])
              j += 1
          }
      }
      result.append(contentsOf: left[i...])
      result.append(contentsOf: right[j...])
      return result
  }

  func mergeSort(_ values: [Int]) -> [Int] {
      if values.count <= 1 {
          return values
      }
      let middle = values.count / 2
      let left = mergeSort(Array(values[..<middle]))
      let right = mergeSort(Array(values[middle...]))
      return merge(left, right)
  }

  print(mergeSort([5, 1, 4, 1, 5, 9, 2, 6]))
  print(mergeSort([]))
  ```

  ```output
  [1, 1, 2, 4, 5, 5, 6, 9]
  []
  ```

  - `<= 1`: zero or one element is already sorted. It's also what guarantees both halves are smaller than the input.
  - `values.count / 2`: the left half gets the smaller part when the count is odd.
  - `middle...`: from the middle to the end. `..<middle` and `middle...` split the array with no overlap and no gap.
````

````exercise
id: m18-l05-e4
type: find-errors
prompt: |
  This generic merge sort should be a stable replacement for `sorted(by:)`. Which statements are true?
code: |
  func mergeSorted<T>(_ values: [T], by less: (T, T) -> Bool) -> [T] {
      if values.isEmpty {
          return values
      }
      let middle = values.count / 2
      let left = mergeSorted(Array(values[..<middle]), by: less)
      let right = mergeSorted(Array(values[middle...]), by: less)
      var result: [T] = []
      var i = 0
      var j = 0
      while i < left.count && j < right.count {
          if less(left[i], right[j]) {
              result.append(left[i])
              i += 1
          } else {
              result.append(right[j])
              j += 1
          }
      }
      result.append(contentsOf: left[i...])
      result.append(contentsOf: right[j...])
      return result
  }
choices:
  - text: "Any non-empty input recurses forever, because a one-element array splits into an empty half and itself."
    correct: true
    why: "For count 1, middle is 0, the right half is the whole array again, and the base case only catches empty arrays."
  - text: "On a tie, less(left[i], right[j]) is false, so the right element goes first and the sort isn't stable."
    correct: true
    why: "Ties must take from the left. The test should be less(right[j], left[i]), taking from the right only when it strictly belongs first."
  - text: "The leftovers are appended in the wrong order: the right side should go first."
    correct: false
    why: "At most one side has leftovers when the loop ends, so the order of the two appends doesn't matter."
  - text: "Swift requires the closure parameter to be @escaping because it's passed to a recursive call."
    correct: false
    why: "Passing a non-escaping closure as a non-escaping argument is allowed. It only needs @escaping if it's stored or outlives the call."
rubric:
  - I found the base case bug and explained the infinite recursion on one element.
  - I found the tie-handling bug and wrote the stable test.
  - I rejected the leftovers and @escaping distractors with a reason.
solution: |
  Two bugs. The base case must be `values.count <= 1`. And the merge must take from the left unless the right element strictly belongs first:

  ```swift
  func mergeSorted<T>(_ values: [T], by less: (T, T) -> Bool) -> [T] {
      if values.count <= 1 {
          return values
      }
      let middle = values.count / 2
      let left = mergeSorted(Array(values[..<middle]), by: less)
      let right = mergeSorted(Array(values[middle...]), by: less)
      var result: [T] = []
      var i = 0
      var j = 0
      while i < left.count && j < right.count {
          if less(right[j], left[i]) {
              result.append(right[j])
              j += 1
          } else {
              result.append(left[i])
              i += 1
          }
      }
      result.append(contentsOf: left[i...])
      result.append(contentsOf: right[j...])
      return result
  }

  let words = ["kiwi", "fig", "pear", "plum", "date"]
  print(mergeSorted(words) { $0.count < $1.count })
  print(words.sorted { $0.count < $1.count })
  ```

  ```output
  ["fig", "kiwi", "pear", "plum", "date"]
  ["fig", "kiwi", "pear", "plum", "date"]
  ```

  The four-letter words keep their input order, matching Swift's stable `sorted(by:)`. Comparing against the standard library on inputs with ties is a cheap test for any hand-written sort.
````

````exercise
id: m18-l05-e5
type: solve
prompt: |
  Write `func countInversions(_ values: [Int]) -> Int` that counts the pairs i < j with `values[i] > values[j]`, in O(n log n), by counting during a merge sort. Then check it against a simple O(n²) count on a scrambled array of 1,000 elements.

  ```output
  3
  10
  0
  true
  ```

  Print the counts for `[2, 4, 1, 3, 5]`, `[5, 4, 3, 2, 1]` and `[1, 2, 3]`, then whether the fast and slow counts agree for `(0..<1_000).map { ($0 * 7_919) % 1_000 }`.
starter: |
  func sortAndCount(_ values: [Int]) -> (sorted: [Int], inversions: Int) {
      if values.count <= 1 {
          return (values, 0)
      }
      // Split, recurse, then merge while counting
      return (values, 0)
  }

  func countInversions(_ values: [Int]) -> Int {
      sortAndCount(values).inversions
  }
hints:
  - "Inversions = those inside the left half + those inside the right half + those with one element in each half."
  - "The cross pairs are counted during the merge: when right[j] is taken before left[i], it's smaller than left[i] and everything after it in the left half."
  - "So add left.count - i at that moment."
rubric:
  - The function counts inversions within each half recursively and cross inversions during the merge.
  - The cross count uses left.count − i when a right element is taken.
  - The four lines match, including agreement with the O(n²) check.
solution: |
  ```swift
  func sortAndCount(_ values: [Int]) -> (sorted: [Int], inversions: Int) {
      if values.count <= 1 {
          return (values, 0)
      }
      let middle = values.count / 2
      let (left, leftCount) = sortAndCount(Array(values[..<middle]))
      let (right, rightCount) = sortAndCount(Array(values[middle...]))
      var merged: [Int] = []
      merged.reserveCapacity(values.count)
      var crossCount = 0
      var i = 0
      var j = 0
      while i < left.count && j < right.count {
          if left[i] <= right[j] {
              merged.append(left[i])
              i += 1
          } else {
              merged.append(right[j])
              crossCount += left.count - i
              j += 1
          }
      }
      merged.append(contentsOf: left[i...])
      merged.append(contentsOf: right[j...])
      return (merged, leftCount + rightCount + crossCount)
  }

  func countInversions(_ values: [Int]) -> Int {
      sortAndCount(values).inversions
  }

  func countInversionsSlowly(_ values: [Int]) -> Int {
      var count = 0
      for i in values.indices {
          for j in (i + 1)..<values.count where values[i] > values[j] {
              count += 1
          }
      }
      return count
  }

  print(countInversions([2, 4, 1, 3, 5]))
  print(countInversions([5, 4, 3, 2, 1]))
  print(countInversions([1, 2, 3]))
  let scrambled = (0..<1_000).map { ($0 * 7_919) % 1_000 }
  print(countInversions(scrambled) == countInversionsSlowly(scrambled))
  ```

  ```output
  3
  10
  0
  true
  ```

  Both halves are sorted when the merge runs, so when `right[j]` is smaller than `left[i]`, it's also smaller than `left[i + 1]`, …, `left[left.count - 1]`. All `left.count - i` of those pairs are inversions, and each was in the original order "left before right". Counting them in one addition is what makes it O(n log n) instead of O(n²). Ties use `<=`, so equal values aren't counted, matching the strict `>` in the definition.

  The inversion count also measures how far an array is from sorted: it's exactly the number of shifts insertion sort does (lesson 4). For the shuffled array it's 250,101, the shift count from that lesson.
````

````exercise
id: m18-l05-e6
type: design
prompt: |
  A diagnostics feature has to sort 4 GB of log lines by timestamp on a Mac with far less free memory than that. You can read and write files freely. Design the approach using merge sort's ideas: what you do in memory, what you write to disk, how you combine, and what each phase costs.
rubric:
  - "Phase 1: read chunks that fit in memory, sort each in memory (Swift's sort is fine), write each sorted chunk to its own file."
  - "Phase 2: merge the sorted files by repeatedly taking the earliest line among the current front lines, reading each file sequentially."
  - I explained that only one line (or a small buffer) per file needs to be in memory during the merge.
  - "I estimated the cost: O(N log N) comparisons overall, and each line read and written a small constant number of times; with many chunks, a heap (Module 19) or merging in rounds picks the minimum efficiently."
solution: |
  This is an **external merge sort**.

  1. **Split and sort runs.** Read as many lines as comfortably fit in memory, say 200 MB worth. Sort that chunk in memory by timestamp, with `sort(by:)`: stable, O(m log m). Write it to a temporary file. Repeat until the input is consumed: about 20 sorted files.
  2. **Merge.** Open all 20 files and read the first line of each. Repeatedly write out the line with the earliest timestamp and read the next line from that file. That's the merge step from this lesson, with k inputs instead of 2. Picking the minimum of 20 fronts by scanning is O(k) per line; a heap (Module 19) makes it O(log k).
  3. **Memory.** The merge only holds one line (or one read buffer) per file, so memory is O(k · buffer), independent of the 4 GB.
  4. **Cost.** Every line is read twice and written twice (once per phase), which dominates on disk. Comparisons total O(N log N): the in-memory sorts plus O(N log k) for the merge. If there were too many files to open at once, merge in rounds: groups of files into bigger sorted files, then those.

  Ties on timestamp: if the original order of equal timestamps matters, make the merge prefer the file that came from earlier in the input. That's the "take from the left on ties" rule, applied to k inputs.
````

## Summary

- **Divide and conquer**: split into smaller problems of the same kind, solve them recursively, combine.
- **Merge**: two indices over two sorted arrays, take the smaller front, append the leftovers. O(n + m).
- **Merge sort**: base case `count <= 1`, split at `count / 2`, sort both halves, merge. About log₂ n levels of O(n) merging each: **O(n log n) on every input**.
- **O(n) extra space** for merged output plus O(log n) stack. Not in place.
- **Stable** when ties take from the left: `left[i] <= right[j]`, or with a predicate, take right only if `areInIncreasingOrder(right[j], left[i])`.
- The merge step works on its own: combining sorted feeds in O(n + m), counting inversions in O(n log n), and sorting data that doesn't fit in memory.
