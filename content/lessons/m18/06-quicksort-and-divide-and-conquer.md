---
id: m18-l06
title: Quicksort and divide and conquer
description: You partition an array around a pivot in place, build quicksort on top of it, and measure how pivot choice decides between O(n log n) and O(n²), including the sorted-input and all-equal traps and their fixes. Then you reuse partition to find the k-th smallest element in average O(n) with quickselect, and step back to divide and conquer as a general tool, with fast exponentiation and the recurrences you'll meet most often.
module: m18
order: 6
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l05]
objectives:
  - Write the Lomuto partition and state its invariant; recognize Hoare's scheme and three-way partitioning.
  - Implement quicksort in place and explain why it's O(n log n) on average and O(n²) in the worst case.
  - Choose a pivot strategy (random, median of three) and explain what each protects against.
  - Keep quicksort's stack depth O(log n) by recursing on the smaller side.
  - Find the k-th smallest element with quickselect in average O(n).
  - Recognize divide and conquer and read the cost of the common recurrences.
terms:
  - term: Pivot
    definition: The element a partition step compares everything against. After partitioning, the pivot is in its final sorted position.
  - term: Partition
    definition: Rearranging a range so that elements smaller than the pivot come before it and the rest come after it, in O(n) time and in place.
  - term: Quicksort
    definition: A sort that partitions around a pivot and then sorts the two sides recursively. In place and not stable; O(n log n) on average, O(n²) in the worst case.
  - term: Quickselect
    definition: Finding the element that would be at index k after sorting, by partitioning and recursing only into the side that contains k. Average O(n).
  - term: Recurrence
    definition: An equation that defines a function's cost in terms of its cost on smaller inputs, like T(n) = 2T(n/2) + O(n) for merge sort.
mastery:
  - Trace a Lomuto partition and give the pivot's final index.
  - Name an input that makes last-element-pivot quicksort quadratic, and a fix.
  - Rewrite quicksort so the recursion goes into the smaller side and the larger side is handled by a loop.
  - Write quickselect and use it for a median or a percentile.
  - Give the cost of T(n) = T(n/2) + O(1), 2T(n/2) + O(n), T(n/2) + O(n) and 2T(n/2) + O(1).
resources: [swift-array, swift-book-functions, swift-book-control-flow, swift-book-generics]
cards:
  - id: m18-l06-c1
    front: What does Lomuto's partition guarantee when it returns index p?
    back: The pivot is at p, in its final sorted position; everything before p is smaller than the pivot; everything after p is greater than or equal to it. O(n) time, O(1) extra space.
  - id: m18-l06-c2
    front: Why is quicksort with the last element as pivot O(n²) on sorted input?
    back: The pivot is always the largest element, so each partition peels off one element and leaves n − 1 on one side. The levels add up to n(n − 1) / 2 comparisons, and the recursion is n deep.
  - id: m18-l06-c3
    front: How do you keep quicksort's stack depth O(log n) even in the worst case?
    back: Recurse into the smaller side and handle the larger side with a loop. The smaller side is at most half, so each recursive call halves the size.
  - id: m18-l06-c4
    front: What does quickselect cost, and why is it cheaper than sorting?
    back: Average O(n), worst O(n²). After partitioning, it recurses into only the side that contains index k, so the work is about n + n/2 + n/4 + … ≈ 2n instead of n log n.
  - id: m18-l06-c5
    front: What's the cost of T(n) = 2T(n/2) + O(n)? And T(n) = T(n/2) + O(n)?
    back: O(n log n) (merge sort, balanced quicksort). O(n) (quickselect on average). Halving with one recursive call and linear work adds up to about 2n.
---

## The idea in one sentence

Quicksort does its work **before** recursing: it puts one element, the pivot, in its final place with everything smaller on its left and everything else on its right, and then sorts the two sides, so how well it performs depends entirely on how evenly the pivot splits the array.

Merge sort (lesson 5) splits by position and works hard to combine. Quicksort splits by value and has nothing left to combine. Both are divide and conquer.

## Partition

The **Lomuto partition** takes the last element of a range as the pivot and sweeps once from left to right, keeping a boundary: everything left of `boundary` is smaller than the pivot.

```swift
func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
    let pivot = values[high - 1]
    var boundary = low
    for i in low..<(high - 1) {
        if values[i] < pivot {
            values.swapAt(i, boundary)
            boundary += 1
        }
        print("i = \(i), boundary = \(boundary): \(values)")
    }
    values.swapAt(boundary, high - 1)
    return boundary
}

var values = [7, 2, 9, 4, 3, 8, 5]
let pivotIndex = partition(&values, 0, values.count)
print(pivotIndex, values)
```

```output
i = 0, boundary = 0: [7, 2, 9, 4, 3, 8, 5]
i = 1, boundary = 1: [2, 7, 9, 4, 3, 8, 5]
i = 2, boundary = 1: [2, 7, 9, 4, 3, 8, 5]
i = 3, boundary = 2: [2, 4, 9, 7, 3, 8, 5]
i = 4, boundary = 3: [2, 4, 3, 7, 9, 8, 5]
i = 5, boundary = 3: [2, 4, 3, 7, 9, 8, 5]
3 [2, 4, 3, 5, 9, 8, 7]
```

- The range is half-open, `low..<high`, like Module 16's binary search. The pivot is `values[high - 1]`.
- **Invariant**: at every step, `values[low..<boundary]` holds elements smaller than the pivot, and `values[boundary..<i + 1]` holds elements that are greater or equal.
- When `values[i]` is smaller, it's swapped to the boundary and the boundary moves right. Otherwise, nothing moves: it's already on the "greater or equal" side.
- At the end, the pivot is swapped into `boundary`, between the two groups. It's now **in its final sorted position**: index 3, with 2, 4 and 3 before it and 9, 8 and 7 after. Neither side is sorted yet.

One pass, n − 1 comparisons, O(1) extra memory: **O(n) time, in place**.

## Quicksort

Partition, then sort each side. The pivot is already where it belongs, so it's in neither side:

```swift
func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
    let pivot = values[high - 1]
    var boundary = low
    for i in low..<(high - 1) {
        if values[i] < pivot {
            values.swapAt(i, boundary)
            boundary += 1
        }
    }
    values.swapAt(boundary, high - 1)
    return boundary
}

func quicksort(_ values: inout [Int], _ low: Int, _ high: Int) {
    if high - low <= 1 {
        return
    }
    let p = partition(&values, low, high)
    quicksort(&values, low, p)
    quicksort(&values, p + 1, high)
}

var numbers = [7, 2, 9, 4, 3, 8, 5, 1, 6]
quicksort(&numbers, 0, numbers.count)
print(numbers)

var empty: [Int] = []
quicksort(&empty, 0, empty.count)
print(empty)
```

```output
[1, 2, 3, 4, 5, 6, 7, 8, 9]
[]
```

- **Base case**: a range of 0 or 1 elements is sorted.
- `quicksort(&values, low, p)` sorts the left side, `values[low..<p]`; `quicksort(&values, p + 1, high)` sorts the right side. Both exclude `p`. Each call works on a strictly smaller range, so the recursion ends.
- No merge step and no second array: all the work happens in `partition`, inside the original array. That's quicksort's advantage over merge sort: **in place**, O(1) extra memory apart from the call stack.
- The trade: quicksort is **not stable**. Partition swaps elements across long distances, which can jump an element over another one equal to it. If you need stability, use the standard library's sort, which is documented as stable, or merge sort.

## Pivot choice decides everything

If every pivot lands near the middle, the recursion tree is balanced like merge sort's: about log₂ n levels with O(n) partitioning per level, **O(n log n)**. If every pivot is the smallest or largest element, each partition peels off just the pivot, and the levels cost (n − 1) + (n − 2) + … + 1: **O(n²)**, with n levels of recursion.

With the last element as pivot, an **already sorted** array is exactly that worst case: the last element is always the largest. Measuring comparisons and the deepest recursion on 1,000 elements:

```swift
func partition(_ values: inout [Int], _ low: Int, _ high: Int, comparisons: inout Int) -> Int {
    let pivot = values[high - 1]
    var boundary = low
    for i in low..<(high - 1) {
        comparisons += 1
        if values[i] < pivot {
            values.swapAt(i, boundary)
            boundary += 1
        }
    }
    values.swapAt(boundary, high - 1)
    return boundary
}

func quicksort(_ values: inout [Int], _ low: Int, _ high: Int, depth: Int, comparisons: inout Int, maxDepth: inout Int) {
    if high - low <= 1 {
        return
    }
    maxDepth = max(maxDepth, depth)
    let p = partition(&values, low, high, comparisons: &comparisons)
    quicksort(&values, low, p, depth: depth + 1, comparisons: &comparisons, maxDepth: &maxDepth)
    quicksort(&values, p + 1, high, depth: depth + 1, comparisons: &comparisons, maxDepth: &maxDepth)
}

let inputs = [
    ("shuffled", (0..<1_000).map { ($0 * 7_919) % 1_000 }),
    ("sorted", Array(0..<1_000)),
    ("reversed", Array((0..<1_000).reversed())),
    ("all equal", Array(repeating: 7, count: 1_000)),
]
for (name, input) in inputs {
    var values = input
    var comparisons = 0
    var maxDepth = 0
    quicksort(&values, 0, values.count, depth: 1, comparisons: &comparisons, maxDepth: &maxDepth)
    print(name, comparisons, "comparisons, depth", maxDepth)
}
```

```output
shuffled 11414 comparisons, depth 22
sorted 499500 comparisons, depth 999
reversed 499500 comparisons, depth 999
all equal 499500 comparisons, depth 999
```

The shuffled input gets about 11,400 comparisons, in the same range as merge sort's 8,415. Sorted and reversed input hit 499,500, the full triangle, and the recursion goes 999 levels deep. On a million sorted elements that's a stack overflow, not just a slow sort, and sorted or nearly sorted input is common in real apps: data that was sorted yesterday and got a few appends today.

The all-equal case is a different problem: with `values[i] < pivot`, no element is smaller than a pivot equal to it, so everything lands on the right side. Pivot choice can't fix that one; it needs a different partition (below).

### Better pivots

Two standard fixes for the sorted-input problem, both done by swapping the chosen pivot into the last position before the same Lomuto partition:

- **Random pivot**: `values.swapAt(Int.random(in: low..<high), high - 1)`. No particular input is bad anymore; a bad run needs bad luck at many levels, and the expected cost is O(n log n) for every input. In ten runs of the code above with a random pivot, sorted input took between 9,756 and 13,335 comparisons and recursed 17 to 25 levels deep. Since the output changes from run to run, it isn't printed here.
- **Median of three**: use the median of the first, middle and last elements. Deterministic, and perfect on sorted input.

```swift
func partition(_ values: inout [Int], _ low: Int, _ high: Int, comparisons: inout Int) -> Int {
    let pivot = values[high - 1]
    var boundary = low
    for i in low..<(high - 1) {
        comparisons += 1
        if values[i] < pivot {
            values.swapAt(i, boundary)
            boundary += 1
        }
    }
    values.swapAt(boundary, high - 1)
    return boundary
}

func medianOfThreeIndex(_ values: [Int], _ low: Int, _ high: Int) -> Int {
    let middle = low + (high - low) / 2
    let a = values[low]
    let b = values[middle]
    let c = values[high - 1]
    if (a <= b) == (b <= c) {
        return middle
    }
    if (b <= a) == (a <= c) {
        return low
    }
    return high - 1
}

func quicksort(_ values: inout [Int], _ low: Int, _ high: Int, comparisons: inout Int) {
    if high - low <= 1 {
        return
    }
    values.swapAt(medianOfThreeIndex(values, low, high), high - 1)
    let p = partition(&values, low, high, comparisons: &comparisons)
    quicksort(&values, low, p, comparisons: &comparisons)
    quicksort(&values, p + 1, high, comparisons: &comparisons)
}

for (name, input) in [("sorted", Array(0..<1_000)), ("reversed", Array((0..<1_000).reversed()))] {
    var values = input
    var comparisons = 0
    quicksort(&values, 0, values.count, comparisons: &comparisons)
    print(name, comparisons, values == input.sorted())
}
```

```output
sorted 7987 true
reversed 13287 true
```

`medianOfThreeIndex` returns the index of the middle value of three: `(a <= b) == (b <= c)` is true exactly when b is between a and c. Sorted input drops from 499,500 comparisons to 7,987. Median of three can still be beaten by inputs built to defeat it, which is why library implementations add other safeguards; a random pivot can't be targeted that way.

### Hoare's partition and duplicates

**Hoare's scheme**, the original one, moves two indices toward each other from both ends and swaps pairs that are on the wrong sides. It usually does fewer swaps than Lomuto, and it handles runs of equal elements better, because both indices stop on elements equal to the pivot. It's also easier to get wrong: it returns a split point rather than the pivot's final position, so the recursion bounds differ. Lomuto is the one to write in an interview unless you know Hoare's cold.

For **many duplicates**, the cleanest fix is a **three-way partition**: smaller, equal and greater, in one pass. Only the smaller and greater parts need sorting.

```swift
func threeWayPartition(_ values: inout [Int], _ low: Int, _ high: Int) -> (lessEnd: Int, greaterStart: Int) {
    let pivot = values[high - 1]
    var lessEnd = low
    var i = low
    var greaterStart = high
    while i < greaterStart {
        if values[i] < pivot {
            values.swapAt(i, lessEnd)
            lessEnd += 1
            i += 1
        } else if values[i] > pivot {
            greaterStart -= 1
            values.swapAt(i, greaterStart)
        } else {
            i += 1
        }
    }
    return (lessEnd, greaterStart)
}

func quicksort3(_ values: inout [Int], _ low: Int, _ high: Int, calls: inout Int) {
    calls += 1
    if high - low <= 1 {
        return
    }
    let (lessEnd, greaterStart) = threeWayPartition(&values, low, high)
    quicksort3(&values, low, lessEnd, calls: &calls)
    quicksort3(&values, greaterStart, high, calls: &calls)
}

var colors = [2, 0, 1, 2, 1, 0, 0, 2, 1]
var calls = 0
quicksort3(&colors, 0, colors.count, calls: &calls)
print(colors, calls)

var same = Array(repeating: 7, count: 1_000)
calls = 0
quicksort3(&same, 0, same.count, calls: &calls)
print(same.count, calls)
```

```output
[0, 0, 0, 1, 1, 1, 2, 2, 2] 7
1000 3
```

Three regions grow as `i` moves: `[low, lessEnd)` smaller, `[lessEnd, i)` equal, `[greaterStart, high)` greater, and `[i, greaterStart)` not yet seen. An element bigger than the pivot is swapped to the end and `i` stays put, because the element swapped in hasn't been examined. On 1,000 equal values, one partition puts everything in the "equal" region, and the two recursive calls are on empty ranges: 3 calls instead of 999 levels. Sorting an array with only three distinct values this way is the classic "Dutch national flag" problem.

### Keeping the stack shallow

Even with good pivots, worst-case depth is O(n). The standard guard: **recurse on the smaller side and loop on the larger one**. The smaller side has at most half the elements, so every recursive call at least halves the size, and the depth is at most log₂ n whatever the pivots do. Exercise 6 asks you to write it.

### Swift's own sort

You don't need any of this to sort in an app: `sort()` is documented as stable and O(n log n) (lesson 4). Quicksort, as written here, is neither stable nor guaranteed O(n log n). The reasons to know it are partition, which shows up far beyond sorting, and quickselect.

## Quickselect: the k-th smallest without sorting

To find the median, or the 90th percentile, or the k-th smallest of anything, you don't need the whole array sorted. Partition once: the pivot lands at its final index p. If p is k, done. If k < p, the answer is on the left; otherwise, on the right. Recurse into **one** side only.

```swift
func partition(_ values: inout [Int], _ low: Int, _ high: Int, comparisons: inout Int) -> Int {
    let pivot = values[high - 1]
    var boundary = low
    for i in low..<(high - 1) {
        comparisons += 1
        if values[i] < pivot {
            values.swapAt(i, boundary)
            boundary += 1
        }
    }
    values.swapAt(boundary, high - 1)
    return boundary
}

func quickselect(_ input: [Int], k: Int, comparisons: inout Int) -> Int {
    var values = input
    var low = 0
    var high = values.count
    while true {
        let middle = low + (high - low) / 2
        values.swapAt(middle, high - 1)
        let p = partition(&values, low, high, comparisons: &comparisons)
        if p == k {
            return values[p]
        } else if k < p {
            high = p
        } else {
            low = p + 1
        }
    }
}

let responseTimes = [120, 85, 300, 95, 110, 2_000, 90, 105, 130, 100]
var comparisons = 0
let median = quickselect(responseTimes, k: responseTimes.count / 2, comparisons: &comparisons)
print("upper median:", median, "after", comparisons, "comparisons")

let samples = (0..<10_000).map { ($0 * 7_919) % 10_000 }
comparisons = 0
let p90 = quickselect(samples, k: 9_000, comparisons: &comparisons)
print("p90:", p90, "after", comparisons, "comparisons")
print(p90 == samples.sorted()[9_000])
```

```output
upper median: 110 after 17 comparisons
p90: 9000 after 21919 comparisons
true
```

- It's binary search's shape (Module 16) with partition as the probe: `low` and `high` close in on k, and only one side survives each round. Because only one side is ever processed, a loop replaces the recursion.
- The middle element is swapped in as the pivot, so sorted input isn't a worst case here.
- **Average O(n)**: n for the first partition, about n/2 for the next, then n/4… which adds up to about 2n. On 10,000 elements it took 21,919 comparisons; sorting them would take on the order of 130,000 (n log₂ n). The worst case is still O(n²), with consistently bad pivots; a random pivot makes that vanishingly unlikely.
- `var values = input` works on a copy, so the caller's array isn't scrambled. Quickselect reorders its input; the copy costs O(n) memory. An in-place version (taking `inout`) avoids it if the caller doesn't care about order.
- For an even count, a true median averages the two middle values; `count / 2` picks the upper one. Fine for a performance dashboard, worth stating in an API.

## Divide and conquer, in general

You've now seen the pattern four times: binary search (Module 16), merge sort, quicksort and quickselect. The recipe:

1. **Divide** into subproblems of the same kind, ideally much smaller (half, not "one less").
2. **Conquer** them recursively, with a base case for the trivially small.
3. **Combine** their answers.

A small example outside sorting: computing xⁿ. The naive loop does n multiplications. But x¹⁰ = (x⁵)², and x⁵ = x · (x²)². Halving the exponent each time:

```swift
func power(_ base: Int, _ exponent: Int, multiplications: inout Int) -> Int {
    if exponent == 0 {
        return 1
    }
    let half = power(base, exponent / 2, multiplications: &multiplications)
    multiplications += 1
    var result = half * half
    if exponent % 2 == 1 {
        multiplications += 1
        result *= base
    }
    return result
}

for exponent in [10, 30, 62] {
    var multiplications = 0
    let value = power(2, exponent, multiplications: &multiplications)
    print("2^\(exponent) = \(value), \(multiplications) multiplications")
}
```

```output
2^10 = 1024, 6 multiplications
2^30 = 1073741824, 9 multiplications
2^62 = 4611686018427387904, 11 multiplications
```

One recursive call on half the exponent plus O(1) work: about log₂ n levels, at most 2 multiplications each, so **O(log n)**. The key is computing `half` **once** and squaring it. Writing `power(base, exponent / 2) * power(base, exponent / 2)` makes two identical calls and brings it back to O(n), the trap from Module 15's last exercise. (`2^62` is the largest power of 2 that fits in an `Int`; `2^63` would overflow and crash.)

### Reading the cost from the recurrence

Write the cost as T(n) in terms of the subproblems, and these four cover most of what you'll meet:

| Recurrence | Example | Cost |
| --- | --- | --- |
| T(n) = T(n/2) + O(1) | binary search, `power` | O(log n) |
| T(n) = T(n/2) + O(n) | quickselect, average | O(n) |
| T(n) = 2T(n/2) + O(1) | `split` from Module 15, visiting a balanced tree | O(n) |
| T(n) = 2T(n/2) + O(n) | merge sort, quicksort with good pivots | O(n log n) |
| T(n) = T(n − 1) + O(n) | quicksort with the worst pivots, insertion sort | O(n²) |

The pattern behind them: count the levels (halving gives log₂ n, shrinking by one gives n) and add up the work per level. When the work per level stays at n, multiply: n log n. When it halves each level, the top level dominates: n. Shrinking by a constant instead of a fraction is what turns divide and conquer back into O(n²).

## Common mistakes

> [!error] Including the pivot in a recursive call
> `quicksort(&values, low, p + 1)` keeps the pivot in the left range. When the pivot is the largest element, the range doesn't shrink, and the recursion never ends. Exclude p from both sides.

> [!error] Last-element pivot on data that's often sorted
> It's the textbook version and the textbook worst case. Use a random pivot or median of three, and test with sorted input.

> [!error] Expecting quicksort to be stable
> It isn't. Ties can come out in any order. Use the standard library's sort or merge sort when stability matters.

> [!error] Calling the half twice in divide and conquer
> `f(n / 2) + f(n / 2)` with identical arguments doubles the work at every level. Compute it once and reuse it.

## Exercises

````exercise
id: m18-l06-e1
type: comprehension
prompt: |
  An app keeps a list of timestamps that's sorted, except that a few new entries are appended at the end before each re-sort. It re-sorts with the lesson's first quicksort (last element as pivot). What happens as the list grows?
choices:
  - text: "Close to n(n − 1) / 2 comparisons and recursion about n deep, so it's quadratic and eventually crashes."
    correct: true
    why: "The input is nearly sorted, so most pivots are the maximum of their range. Each partition peels off one element."
  - text: "O(n log n), because the data is nearly sorted and quicksort is fast on sorted data."
    correct: false
    why: "That's insertion sort. For last-element-pivot quicksort, sorted input is the worst case."
  - text: "O(n), because only a few entries are out of place."
    correct: false
    why: "Quicksort doesn't take advantage of existing order. It partitions every range regardless."
  - text: "It depends on the values of the timestamps, not their order."
    correct: false
    why: "Pivot quality depends on the pivot's rank in its range, which is about order."
solution: |
  **Quadratic, and deep.** With the last element as pivot on nearly sorted data, the pivot is almost always the largest in its range, so partitions are as unbalanced as they can be: about n(n − 1) / 2 comparisons and about n levels of recursion. With tens of thousands of timestamps, that's both slow and a stack overflow risk. Fixes: a random pivot, median of three, or just `sort()`, which is documented as O(n log n). Insertion sort would also do well here, since only a few elements are out of place.
````

````exercise
id: m18-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
      let pivot = values[high - 1]
      var boundary = low
      for i in low..<(high - 1) {
          if values[i] < pivot {
              values.swapAt(i, boundary)
              boundary += 1
          }
      }
      values.swapAt(boundary, high - 1)
      return boundary
  }

  var a = [4, 8, 1, 6, 3, 5]
  print(partition(&a, 0, a.count), a)
  var b = [9, 7, 8]
  print(partition(&b, 0, b.count), b)
output: |
  3 [4, 1, 3, 5, 8, 6]
  1 [7, 8, 9]
hints:
  - "The pivot is the last element. Walk i from left to right; every element smaller than the pivot is swapped to the boundary."
  - "In the second array, only 7 is smaller than 8."
solution: |
  ```output
  3 [4, 1, 3, 5, 8, 6]
  1 [7, 8, 9]
  ```

  First array, pivot 5:
  - i = 0: 4 < 5, swap with itself, boundary 1.
  - i = 1: 8, no.
  - i = 2: 1 < 5, swap with index 1: `[4, 1, 8, 6, 3, 5]`, boundary 2.
  - i = 3: 6, no.
  - i = 4: 3 < 5, swap with index 2: `[4, 1, 3, 6, 8, 5]`, boundary 3.
  - Finally swap the pivot into index 3: `[4, 1, 3, 5, 8, 6]`.

  Second array, pivot 8: 9 isn't smaller; 7 is, and swaps to index 0: `[7, 9, 8]`, boundary 1. The pivot swaps into index 1: `[7, 8, 9]`. In both, the pivot ends at its sorted position, and the sides are grouped but not sorted (8, 6).
````

````exercise
id: m18-l06-e3
type: fill-in
prompt: Complete the recursive quickselect, which returns the element that would be at index `k` if `values[low..<high]` were sorted.
code: |
  func select(_ values: inout [Int], _ low: Int, _ high: Int, k: Int) -> Int {
      let p = partition(&values, low, high)
      if p == k {
          return [[1]]
      } else if k < p {
          return select(&values, low, [[2]], k: k)
      } else {
          return select(&values, [[3]], high, k: k)
      }
  }
blanks:
  - id: "1"
    answers: ["values[p]", "values[k]"]
  - id: "2"
    answers: ["p"]
  - id: "3"
    answers: ["p + 1", "p+1"]
solution: |
  ```swift
  func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
      let pivot = values[high - 1]
      var boundary = low
      for i in low..<(high - 1) {
          if values[i] < pivot {
              values.swapAt(i, boundary)
              boundary += 1
          }
      }
      values.swapAt(boundary, high - 1)
      return boundary
  }

  func select(_ values: inout [Int], _ low: Int, _ high: Int, k: Int) -> Int {
      let p = partition(&values, low, high)
      if p == k {
          return values[p]
      } else if k < p {
          return select(&values, low, p, k: k)
      } else {
          return select(&values, p + 1, high, k: k)
      }
  }

  var scores = [70, 95, 60, 85, 75, 90, 80]
  print(select(&scores, 0, scores.count, k: 0))
  print(select(&scores, 0, scores.count, k: 3))
  print(select(&scores, 0, scores.count, k: 6))
  ```

  ```output
  60
  80
  95
  ```

  - `values[p]`: the pivot is at its sorted index, and that index is k.
  - `p`: k is to the left, so search `low..<p`, excluding the pivot.
  - `p + 1`: k is to the right, so search `p + 1..<high`.

  There's no explicit base case: when the range has one element, partition returns that index, and it must be k, because k always stays inside the range. Index 3 of 7 sorted scores is the median, 80.
````

````exercise
id: m18-l06-e4
type: find-errors
prompt: |
  This quicksort uses the partition from the lesson. Which statements are true?
code: |
  func quicksort(_ values: inout [Int], _ low: Int, _ high: Int) {
      if high - low <= 1 {
          return
      }
      let p = partition(&values, low, high)
      quicksort(&values, low, p + 1)
      quicksort(&values, p + 1, high)
  }
choices:
  - text: "The first call includes the pivot, so when the pivot is the largest element of its range, the range doesn't shrink and the recursion never ends."
    correct: true
    why: "If p == high − 1, the call quicksort(low, p + 1) is quicksort(low, high) again, and the partition returns the same p."
  - text: "Even on inputs where it finishes, it re-sorts the pivot for nothing."
    correct: true
    why: "The pivot is already in its final place; including it only adds work, and in the worst case, the infinite loop above."
  - text: "The second call should start at p, not p + 1."
    correct: false
    why: "p + 1 correctly excludes the pivot from the right side. The bug is in the first call."
  - text: "The base case should be high == low."
    correct: false
    why: "high − low <= 1 covers both empty and one-element ranges, which is right."
rubric:
  - I identified quicksort(low, p + 1) as including the pivot.
  - I gave an input that loops forever, like any range whose last element is its largest (sorted input).
  - I fixed the call to quicksort(low, p).
solution: |
  The left call must be `quicksort(&values, low, p)`. With `p + 1`, a range whose last element is its maximum, like `[1, 2, 3]`, partitions with p = 2 and then calls itself on the same `0..<3`, forever, until the stack overflows. The fixed version:

  ```swift
  func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
      let pivot = values[high - 1]
      var boundary = low
      for i in low..<(high - 1) {
          if values[i] < pivot {
              values.swapAt(i, boundary)
              boundary += 1
          }
      }
      values.swapAt(boundary, high - 1)
      return boundary
  }

  func quicksort(_ values: inout [Int], _ low: Int, _ high: Int) {
      if high - low <= 1 {
          return
      }
      let p = partition(&values, low, high)
      quicksort(&values, low, p)
      quicksort(&values, p + 1, high)
  }

  var values = [1, 2, 3]
  quicksort(&values, 0, values.count)
  print(values)
  ```

  ```output
  [1, 2, 3]
  ```

  The rule that makes quicksort terminate: the pivot is excluded from both recursive calls, so every call is on a strictly smaller range.
````

````exercise
id: m18-l06-e5
type: solve
prompt: |
  The lesson's `power` computes xⁿ by halving. Write an iterative version, `func powerLoop(_ base: Int, _ exponent: Int) -> (value: Int, multiplications: Int)`, that also does O(log n) multiplications, using the binary digits of the exponent: square the base each round, and multiply it into the result when the current lowest bit of the exponent is 1.

  Print the results for `(2, 10)`, `(3, 0)`, `(3, 13)` and `(2, 62)`:

  ```output
  (value: 1024, multiplications: 5)
  (value: 1, multiplications: 0)
  (value: 1594323, multiplications: 6)
  (value: 4611686018427387904, multiplications: 10)
  ```
starter: |
  func powerLoop(_ base: Int, _ exponent: Int) -> (value: Int, multiplications: Int) {
      var result = 1
      var square = base
      var remaining = exponent
      var multiplications = 0
      while remaining > 0 {
          // If the lowest bit is 1, multiply result by square
          // Halve remaining; if there's more to do, square the square
      }
      return (result, multiplications)
  }
hints:
  - "remaining % 2 == 1 tests the lowest bit; remaining /= 2 drops it."
  - "Square only when remaining is still > 0 after halving. Otherwise the last squaring is wasted, and for 2^62 it would overflow."
  - "13 is 1101 in binary: 3^13 = 3^8 × 3^4 × 3^1."
rubric:
  - The loop runs once per binary digit of the exponent, so O(log n) iterations.
  - It multiplies into the result only for 1 bits and avoids the final unnecessary squaring.
  - The four lines match, including no overflow for 2^62.
solution: |
  ```swift
  func powerLoop(_ base: Int, _ exponent: Int) -> (value: Int, multiplications: Int) {
      var result = 1
      var square = base
      var remaining = exponent
      var multiplications = 0
      while remaining > 0 {
          if remaining % 2 == 1 {
              result *= square
              multiplications += 1
          }
          remaining /= 2
          if remaining > 0 {
              square *= square
              multiplications += 1
          }
      }
      return (result, multiplications)
  }

  print(powerLoop(2, 10))
  print(powerLoop(3, 0))
  print(powerLoop(3, 13))
  print(powerLoop(2, 62))
  ```

  ```output
  (value: 1024, multiplications: 5)
  (value: 1, multiplications: 0)
  (value: 1594323, multiplications: 6)
  (value: 4611686018427387904, multiplications: 10)
  ```

  `square` takes the values base, base², base⁴, base⁸… and each 1 bit of the exponent multiplies one of them into the result. 13 = 8 + 4 + 1, so 3¹³ = 3⁸ · 3⁴ · 3¹. The loop runs once per binary digit, about log₂ n times, with at most two multiplications each: **O(log n)**. The `if remaining > 0` guard matters for 2⁶²: without it, the loop would square 2³² after the last bit, and 2⁶⁴ doesn't fit in an `Int`, so the program would crash with an overflow even though that value is never used.
````

````exercise
id: m18-l06-e6
type: refactor
prompt: |
  Rewrite this quicksort so that its recursion depth is O(log n) even with bad pivots: recurse into the smaller side and handle the larger side with a loop. Keep the same partition. Show that on 1,000 sorted elements the deepest recursion is small while the comparison count is still quadratic.
code: |
  func quicksort(_ values: inout [Int], _ low: Int, _ high: Int) {
      if high - low <= 1 {
          return
      }
      let p = partition(&values, low, high)
      quicksort(&values, low, p)
      quicksort(&values, p + 1, high)
  }
rubric:
  - The function loops while the range has more than one element.
  - After partitioning, it recurses into the smaller side and updates low or high to continue with the larger side.
  - I explained that the recursive side has at most half the elements, so depth is at most log₂ n.
  - I noted that this fixes the stack, not the O(n²) time, which needs a better pivot.
solution: |
  ```swift
  func partition(_ values: inout [Int], _ low: Int, _ high: Int) -> Int {
      let pivot = values[high - 1]
      var boundary = low
      for i in low..<(high - 1) {
          if values[i] < pivot {
              values.swapAt(i, boundary)
              boundary += 1
          }
      }
      values.swapAt(boundary, high - 1)
      return boundary
  }

  func quicksort(_ values: inout [Int], _ low: Int, _ high: Int, depth: Int, maxDepth: inout Int) {
      var low = low
      var high = high
      maxDepth = max(maxDepth, depth)
      while high - low > 1 {
          let p = partition(&values, low, high)
          if p - low < high - (p + 1) {
              quicksort(&values, low, p, depth: depth + 1, maxDepth: &maxDepth)
              low = p + 1
          } else {
              quicksort(&values, p + 1, high, depth: depth + 1, maxDepth: &maxDepth)
              high = p
          }
      }
  }

  var sorted = Array(0..<1_000)
  var maxDepth = 0
  quicksort(&sorted, 0, sorted.count, depth: 1, maxDepth: &maxDepth)
  print(sorted == Array(0..<1_000), maxDepth)

  var shuffled = (0..<1_000).map { ($0 * 7_919) % 1_000 }
  maxDepth = 0
  quicksort(&shuffled, 0, shuffled.count, depth: 1, maxDepth: &maxDepth)
  print(shuffled == Array(0..<1_000), maxDepth)
  ```

  ```output
  true 2
  true 7
  ```

  On sorted input, every partition leaves an empty left side and everything else on the right. The empty side gets the recursive call (depth 2, returning immediately), and the loop continues with the big side. The depth is 2 instead of 999, but the loop still runs about 1,000 partitions of shrinking size: the time is still n(n − 1) / 2 comparisons. This fixes the **stack**; a random pivot or median of three fixes the **time**. Production quicksorts do both.

  Why log₂ n: the recursive call always gets the smaller side, which has at most half the elements of the current range, so each level of recursion at least halves the size. The parameters `low` and `high` are copied into `var`s because function parameters are constants in Swift.
````

## Summary

- **Partition** (Lomuto): pivot = last element, one sweep, smaller elements swapped to a growing boundary, pivot swapped into place. O(n), in place. The pivot ends at its final sorted index.
- **Quicksort**: partition, then sort `low..<p` and `p + 1..<high`. In place, not stable. O(n log n) with balanced pivots, **O(n²)** with consistently extreme ones, which last-element pivots hit on sorted input.
- Fixes: a **random pivot** or **median of three** for sorted input; a **three-way partition** for many duplicates; **recursing on the smaller side** keeps depth at O(log n).
- **Quickselect**: partition and continue into the side that holds k. Average O(n), worst O(n²). Medians and percentiles without sorting.
- **Divide and conquer**: split into smaller same-kind problems, solve recursively, combine. Halving with one call and O(1) work is O(log n) (binary search, fast power); with O(n) work, O(n) (quickselect); two halves with O(n) work, O(n log n) (merge sort). Shrinking by one instead of by half is what gives O(n²).
