---
id: m15-l03
title: Logarithmic time and binary search
description: You see why halving the problem at every step makes an algorithm barely notice a bigger input, count how many times a million can be halved, write a binary search on a sorted array with a step counter and check it against every edge case, and read O(n log n) as "n times a halving".
module: m15
order: 3
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l02]
objectives:
  - Explain log₂ n as the number of times you can halve n before reaching 1.
  - Estimate log₂ n for powers of two and for round numbers like a million or a billion.
  - Write a binary search on a sorted array that handles empty arrays, missing targets and the first and last positions.
  - Explain why binary search needs sorted input and what it returns when there are duplicates.
  - Recognize O(n log n) and weigh "sort once, then binary search" against repeated linear searches.
terms:
  - term: Logarithm (log₂ n)
    definition: The power you raise 2 to in order to get n. 2¹⁰ = 1,024, so log₂ 1,024 = 10. For algorithms, read it as "how many times you can halve n before you get to 1".
  - term: Logarithmic time, O(log n)
    definition: The step count grows by about one each time n doubles, because every step halves what's left.
  - term: Binary search
    definition: A search on a sorted array that compares the target with the middle element and throws away the half that can't contain it, until it finds the target or nothing is left.
  - term: Invariant
    definition: A statement that stays true on every pass of a loop. In binary search, "if the target is in the array, it's between low and high".
  - term: Linearithmic time, O(n log n)
    definition: n times log n. Typical of doing an O(log n) operation once per element, and of efficient sorting.
mastery:
  - Write the halving loop and predict how many passes it makes for a given n.
  - Implement binary search with low, high and mid, and trace it with a table.
  - List the edge cases for binary search and show that your version handles each one.
  - Explain why binary search on an unsorted array can miss a value that's there.
  - Decide whether sorting first pays off, given the number of searches.
resources: [swift-array, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m15-l03-c1
    front: How many times can you halve 1,000,000 before you reach 1?
    back: "19 times with integer division (2¹⁹ = 524,288 and 2²⁰ = 1,048,576). log₂ 1,000,000 is about 19.9, so people say \"about 20\"."
  - id: m15-l03-c2
    front: What does binary search need from its input?
    back: The array must be sorted. It decides which half to throw away by comparing with the middle element, and that's only valid if smaller values are on the left and larger ones on the right.
  - id: m15-l03-c3
    front: Worst-case comparisons for binary search on 1,000,000 sorted elements?
    back: 20. Each comparison halves the range, so it's about log₂ n. A linear search can take 1,000,000.
  - id: m15-l03-c4
    front: Why write mid = low + (high - low) / 2 instead of (low + high) / 2?
    back: low + high can overflow when both are huge, and Swift traps on overflow. The subtraction version never exceeds high. With real arrays you won't hit it, but it's the standard habit.
  - id: m15-l03-c5
    front: What's O(n log n), and where does it come from?
    back: n times log n. It shows up when you do an O(log n) step for each of n elements, and it's the cost of sorting. Apple's documentation lists sorted() as O(n log n).
---

## The idea in one sentence

If every step throws away half of what's left, a million elements take about 20 steps, and doubling the input adds **one** step.

## Halving

Take a number and keep dividing it by 2 until you get to 1:

```swift
var n = 16
var halvings = 0
while n > 1 {
    n /= 2
    halvings += 1
    print("after \(halvings): \(n)")
}
```

```output
after 1: 8
after 2: 4
after 3: 2
after 4: 1
```

16 → 8 → 4 → 2 → 1: four halvings. Now try bigger numbers:

```swift
for size in [8, 1_024, 2_048, 1_000_000, 1_000_000_000] {
    var n = size
    var halvings = 0
    while n > 1 {
        n /= 2
        halvings += 1
    }
    print("\(size): \(halvings) halvings")
}
```

```output
8: 3 halvings
1024: 10 halvings
2048: 11 halvings
1000000: 19 halvings
1000000000: 29 halvings
```

A million halves down to 1 in 19 steps; a billion in 29. Going from 1,024 to 2,048 added one halving. Multiply the input by 1,000 and you add about 10 steps.

That count has a name. **log₂ n** (logarithm base 2 of n) is the power you raise 2 to in order to get n: 2³ = 8, so log₂ 8 = 3; 2¹⁰ = 1,024, so log₂ 1,024 = 10. For numbers that aren't powers of two the logarithm isn't a whole number: log₂ 1,000,000 is about 19.93. The loop above counts with integer division, so it reports the whole part, 19. For estimates, round: **a thousand is about 2¹⁰, a million about 2²⁰, a billion about 2³⁰.**

An algorithm that halves its problem at each step does about log₂ n steps. That's **O(log n)**. In Big O the base doesn't matter: log₂ n and log₁₀ n differ by a constant factor (about 3.3), and Big O drops constant factors. People write O(log n) and mean base 2.

## Binary search

You already know the algorithm from the number-guessing game. "I'm thinking of a number from 1 to 100." Guess 50. "Higher." Now it's 51 to 100, so guess 75. "Lower." 51 to 74, guess 62. Every answer rules out half of what's left, and you never need more than 7 guesses for 100 numbers.

**Binary search** does the same with a **sorted** array:

1. Keep two indexes, `low` and `high`, around the part that could still contain the target. At the start, that's the whole array.
2. Look at the middle element.
3. If it's the target, you're done. If it's smaller than the target, the target can only be to the right: move `low` past the middle. If it's larger, move `high` before the middle.
4. Stop when you find it or when `low` passes `high`, which means nothing is left to search.

```swift
func binarySearch(for target: Int, in sorted: [Int]) -> (index: Int?, steps: Int) {
    var low = 0
    var high = sorted.count - 1
    var steps = 0
    while low <= high {
        steps += 1
        let mid = low + (high - low) / 2
        if sorted[mid] == target {
            return (mid, steps)
        } else if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return (nil, steps)
}

let sorted = [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
let result = binarySearch(for: 23, in: sorted)
print("index \(result.index ?? -1) in \(result.steps) steps")
```

```output
index 5 in 3 steps
```

Line by line:

1. `low` and `high` are **inclusive**: the target, if it's there, is somewhere in `sorted[low...high]`. That sentence is the loop's **invariant**, and every line below exists to keep it true.
2. `high` starts at `count - 1`, the last valid index. For an empty array that's -1, so the loop never runs.
3. `while low <= high`: there's at least one element left. With `<` instead, a range of one element (`low == high`) would never be checked.
4. `mid = low + (high - low) / 2` is the middle, rounded down. It's written this way instead of `(low + high) / 2` so the addition can't overflow; with arrays that fit in memory you won't hit it, but it's the standard habit.
5. Found: return the index and the count.
6. `sorted[mid] < target`: everything up to and including `mid` is too small, so the new range starts at `mid + 1`.
7. `sorted[mid] > target`: everything from `mid` on is too big, so the new range ends at `mid - 1`.
8. The `+ 1` and `- 1` matter: they guarantee the range shrinks on every pass. Writing `high = mid` here can loop forever.
9. If the loop ends, the range is empty: not found. The function returns an optional, as `firstIndex(of:)` does (Module 8).

Trace it for 23:

| Pass | low | high | mid | sorted[mid] | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | 0 | 9 | 4 | 16 | 16 < 23, so low = 5 |
| 2 | 5 | 9 | 7 | 56 | 56 > 23, so high = 6 |
| 3 | 5 | 6 | 5 | 23 | found at 5 |

Three comparisons for ten elements. A linear search would have needed six.

### Edge cases

A binary search is short, and that makes it easy to get subtly wrong. Test it on every edge case, and check its answers against `firstIndex(of:)`, which you know is right:

```swift
func binarySearch(for target: Int, in sorted: [Int]) -> (index: Int?, steps: Int) {
    var low = 0
    var high = sorted.count - 1
    var steps = 0
    while low <= high {
        steps += 1
        let mid = low + (high - low) / 2
        if sorted[mid] == target {
            return (mid, steps)
        } else if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return (nil, steps)
}

let sorted = [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
let cases = [(2, "first"), (91, "last"), (7, "missing, in the middle"),
             (1, "smaller than all"), (100, "larger than all")]
for (target, label) in cases {
    let result = binarySearch(for: target, in: sorted)
    print("\(label): \(result.index ?? -1) in \(result.steps) steps")
}

let empty = binarySearch(for: 5, in: [])
print("empty array: \(empty.index ?? -1) in \(empty.steps) steps")
let single = binarySearch(for: 4, in: [4])
print("one element: \(single.index ?? -1) in \(single.steps) steps")

var allMatch = true
for target in -1...100 where binarySearch(for: target, in: sorted).index != sorted.firstIndex(of: target) {
    allMatch = false
}
print("matches firstIndex for -1...100: \(allMatch)")
```

```output
first: 0 in 3 steps
last: 9 in 4 steps
missing, in the middle: -1 in 3 steps
smaller than all: -1 in 3 steps
larger than all: -1 in 4 steps
empty array: -1 in 0 steps
one element: 0 in 1 steps
matches firstIndex for -1...100: true
```

The last check runs 102 searches, most for values that aren't there, and compares each answer with the linear search. `!=` works between two `Int?` values: two `nil`s are equal, and two non-nil values are equal when their contents are.

Two more facts about binary search that the tests above don't show:

- **With duplicates, it finds *a* match, not necessarily the first.** On `[1, 3, 3, 3, 5]`, searching for 3 hits index 2 on the first comparison, while `firstIndex(of: 3)` is 1. Module 16 adapts the search to find the first or last occurrence.
- **On an unsorted array, the answer is meaningless.** It can miss values that are there. On `[5, 1, 9, 3, 7]`, searching for 1 compares with 9, goes left, compares with 5, goes left again, and reports "not found":

```swift
func binarySearch(for target: Int, in sorted: [Int]) -> (index: Int?, steps: Int) {
    var low = 0
    var high = sorted.count - 1
    var steps = 0
    while low <= high {
        steps += 1
        let mid = low + (high - low) / 2
        if sorted[mid] == target {
            return (mid, steps)
        } else if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return (nil, steps)
}

let unsorted = [5, 1, 9, 3, 7]
print(binarySearch(for: 1, in: unsorted).index ?? -1)
print(unsorted.firstIndex(of: 1) ?? -1)
```

```output
-1
1
```

No crash, no warning: just a wrong answer. Binary search trusts its input. If you can't be sure the array is sorted, you can't use it.

### Linear versus binary on a million elements

```swift
func binarySearch(for target: Int, in sorted: [Int]) -> (index: Int?, steps: Int) {
    var low = 0
    var high = sorted.count - 1
    var steps = 0
    while low <= high {
        steps += 1
        let mid = low + (high - low) / 2
        if sorted[mid] == target {
            return (mid, steps)
        } else if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return (nil, steps)
}

func linearSearch(for target: Int, in values: [Int]) -> (index: Int?, steps: Int) {
    var steps = 0
    for (index, value) in values.enumerated() {
        steps += 1
        if value == target {
            return (index, steps)
        }
    }
    return (nil, steps)
}

let million = Array(0..<1_000_000)
for target in [999_999, 1_000_000] {
    let linear = linearSearch(for: target, in: million)
    let binary = binarySearch(for: target, in: million)
    print("\(target): linear \(linear.steps) steps, binary \(binary.steps) steps")
}
```

```output
999999: linear 1000000 steps, binary 20 steps
1000000: linear 1000000 steps, binary 20 steps
```

The last element and a missing one are both worst cases for linear search: a million comparisons. Binary search needs 20. Its worst case is the number of halvings plus one for the last remaining element, ⌊log₂ n⌋ + 1, which is 20 for a million. That's **O(log n)**.

> [!note] Binary search in the standard library
> Swift's `Array` doesn't have a binary search method. `firstIndex(of:)` and `contains(_:)` are linear: their documentation lists O(n). Binary search is short enough to write when you need it, and you'll write variations of it in Module 16.

## O(n log n): n times a halving

Do an O(log n) operation once for each of n elements and you get **O(n log n)**. Searching for every element of a 1,024-element sorted array with binary search takes about 10 steps each, so about 10,000 in total:

```swift
func binarySearch(for target: Int, in sorted: [Int]) -> (index: Int?, steps: Int) {
    var low = 0
    var high = sorted.count - 1
    var steps = 0
    while low <= high {
        steps += 1
        let mid = low + (high - low) / 2
        if sorted[mid] == target {
            return (mid, steps)
        } else if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    return (nil, steps)
}

let values = Array(0..<1_024)
var total = 0
for target in values {
    total += binarySearch(for: target, in: values).steps
}
print("binary, all 1024 targets: \(total) steps")
print("linear, all 1024 targets: \(1_024 * 1_025 / 2) steps")
```

```output
binary, all 1024 targets: 9228 steps
linear, all 1024 targets: 524800 steps
```

9,228 is a bit under 1,024 × 10 = 10,240, because some targets are found before the range shrinks to one element. The linear total is 1 + 2 + … + 1,024 = n(n + 1)/2, which is O(n²).

The most important O(n log n) algorithm is **sorting**. Apple's documentation for `sorted()` states its complexity as "O(n log n), where n is the length of the sequence", and the same for `sort()`. The intuition, which Module 18 makes concrete with merge sort: split the array in half, and the halves in half, until each piece has one element. That's log n levels of splitting. At each level, merging the pieces back in order touches every element once: n work per level. n per level, log n levels: n log n.

On the ladder from lesson 2, O(n log n) sits just above O(n). For a million elements it's about 20 million steps against a trillion for O(n²). That's why "sort it first" is so often the first step of a good solution.

## A practical example: sort once, search many times

A contacts app has n phone numbers and needs to answer k lookups ("is this caller in my contacts?"):

- **Linear search every time**: k × n comparisons in the worst case. O(k · n).
- **Sort once, then binary search**: n log n to sort, plus k × log n for the searches. O(n log n + k log n).

With n = 100,000 contacts:

| Lookups (k) | Linear: k × n | Sort, then binary: n log n + k log n (log n ≈ 17) |
| --- | --- | --- |
| 1 | 100,000 | ≈ 1,700,000 |
| 100 | 10,000,000 | ≈ 1,700,000 |
| 100,000 | 10,000,000,000 | ≈ 3,400,000 |

For a single lookup, sorting first is a loss: you pay for the sort and only use it once. The sort pays for itself once k × n passes n log n, which here is around 17 lookups, and for many lookups it wins by orders of magnitude. These are rough counts of comparisons, not times, but the shape is what matters. Lesson 5 shows a third option, a `Set`, that answers each lookup in O(1) on average without sorting.

## Common mistakes

> [!error] Binary search on an unsorted array
> It doesn't crash; it just returns wrong answers, like "not found" for a value that's there. Sort first, or use a linear search or a `Set`.

> [!error] while low < high
> With `<`, a range with one element left (`low == high`) is never checked. Searching for the last element, or for the only element of `[4]`, fails. The inclusive version needs `<=`.

> [!error] high = mid or low = mid
> If the range doesn't shrink on every pass, the loop can run forever. With inclusive bounds, `mid` has just been checked, so it's excluded: `low = mid + 1`, `high = mid - 1`.

> [!error] Forgetting the empty array
> With `high = sorted.count - 1`, an empty array gives `high = -1` and the loop doesn't run. Versions that read `sorted[0]` or `sorted[sorted.count - 1]` before the loop crash with `Index out of range`.

> [!error] Sorting before every search
> Sorting is O(n log n). Sorting and then searching once is slower than one linear search. Sort once, search many times.

## Exercises

````exercise
id: m15-l03-e1
type: comprehension
prompt: When can you use binary search on an array?
choices:
  - text: When the array is sorted in the order the comparisons assume
    correct: true
    why: Binary search discards half the array based on one comparison, which is only valid if the elements are in order.
  - text: When the array has no duplicates
    correct: false
    why: Duplicates are fine. You get one of the matching indexes, not necessarily the first.
  - text: When the array has more than 1,000 elements
    correct: false
    why: Size doesn't matter for correctness. Binary search works on 0, 1 or 10 elements as long as they're sorted.
  - text: Any time, because it's faster than linear search
    correct: false
    why: On unsorted data it returns wrong answers without crashing.
solution: |
  **When it's sorted.** The whole algorithm rests on one step: compare with the middle, and throw away the half that can't contain the target. That's only valid if smaller values are on the left and larger ones on the right. On unsorted data, binary search doesn't fail loudly; it quietly reports "not found" for values that are there.
````

````exercise
id: m15-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  var n = 40
  var halvings = 0
  while n > 1 {
      print(n, terminator: " ")
      n /= 2
      halvings += 1
  }
  print(n)
  print("halvings: \(halvings)")
output: |
  40 20 10 5 2 1
  halvings: 5
hints:
  - "Integer division rounds down: 5 / 2 is 2."
  - The loop stops when n is 1, and the last print shows it.
solution: |
  ```output
  40 20 10 5 2 1
  halvings: 5
  ```

  40 → 20 → 10 → 5 → 2 → 1. Integer division turns 5 into 2. Five halvings, which matches ⌊log₂ 40⌋: 2⁵ = 32 ≤ 40 < 64 = 2⁶. `terminator: " "` keeps the numbers on one line, and the final `print(n)` adds the 1 and the line break.
````

````exercise
id: m15-l03-e3
type: find-errors
prompt: This binary search is supposed to return the index of `target` in a sorted array, or `nil`. Which statements about it are true?
code: |
  func search(_ target: Int, in sorted: [Int]) -> Int? {
      var low = 0
      var high = sorted.count - 1
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] == target {
              return mid
          } else if sorted[mid] < target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return nil
  }
choices:
  - text: "It returns nil for a one-element array that contains the target, like search(4, in: [4])."
    correct: true
    why: "low and high are both 0, so low < high is false and the loop never runs."
  - text: "It can miss the target when it's the last element left in the range."
    correct: true
    why: "When the range narrows to one element, the loop stops before checking it. search(91, in: [2, 5, 91]) returns nil."
  - text: "high = mid is a problem: with inclusive bounds it should be mid - 1."
    correct: true
    why: "mid was just checked, so keeping it in the range is wasted work. Together with <=, high = mid can make the loop never end."
  - text: "It crashes on an empty array."
    correct: false
    why: "high is -1, the condition is false, and it returns nil. No subscript runs."
  - text: "mid = low + (high - low) / 2 can produce an index outside low...high."
    correct: false
    why: "(high - low) / 2 is between 0 and high - low, so mid is always in range."
rubric:
  - I found that the loop condition skips the last remaining element.
  - I gave an input that shows it.
  - I explained why the bounds should be updated with mid + 1 and mid - 1.
  - I wrote a fixed version and tested it on edge cases.
solution: |
  The bug is the combination of `while low < high` and `high = mid`. The `<` stops the loop while one element is still unchecked, so `search(4, in: [4])` and `search(91, in: [2, 5, 91])` both return `nil`. Changing only the condition to `<=` isn't enough: with `high = mid`, a range like `low = 0, high = 0` where the value is too big sets `high` to 0 again, and the loop never ends. The fix is both changes:

  ```swift
  func search(_ target: Int, in sorted: [Int]) -> Int? {
      var low = 0
      var high = sorted.count - 1
      while low <= high {
          let mid = low + (high - low) / 2
          if sorted[mid] == target {
              return mid
          } else if sorted[mid] < target {
              low = mid + 1
          } else {
              high = mid - 1
          }
      }
      return nil
  }

  print(search(4, in: [4]) ?? -1)
  print(search(91, in: [2, 5, 91]) ?? -1)
  print(search(3, in: [4]) ?? -1)
  print(search(1, in: []) ?? -1)
  ```

  ```output
  0
  2
  -1
  -1
  ```

  The empty array was never a problem, and the `mid` formula is correct. Those two choices are distractors.
````

````exercise
id: m15-l03-e4
type: fill-in
prompt: Complete the loop of this binary search on sorted names. It should print `2 -1`.
code: |
  func position(of name: String, in sorted: [String]) -> Int {
      var low = 0
      var high = sorted.count - 1
      while low [[1]] high {
          let mid = low + (high - low) / 2
          if sorted[mid] == name {
              return mid
          } else if sorted[mid] < name {
              low = [[2]]
          } else {
              high = [[3]]
          }
      }
      return -1
  }

  let names = ["Ana", "Luis", "Marta", "Sofía"]
  print(position(of: "Marta", in: names), position(of: "Pablo", in: names))
blanks:
  - id: "1"
    answers: ["<="]
  - id: "2"
    answers: ["mid + 1", "mid+1"]
  - id: "3"
    answers: ["mid - 1", "mid-1"]
solution: |
  ```swift
  func position(of name: String, in sorted: [String]) -> Int {
      var low = 0
      var high = sorted.count - 1
      while low <= high {
          let mid = low + (high - low) / 2
          if sorted[mid] == name {
              return mid
          } else if sorted[mid] < name {
              low = mid + 1
          } else {
              high = mid - 1
          }
      }
      return -1
  }

  let names = ["Ana", "Luis", "Marta", "Sofía"]
  print(position(of: "Marta", in: names), position(of: "Pablo", in: names))
  ```

  ```output
  2 -1
  ```

  Binary search works on anything that can be compared with `<`, not just numbers. Strings compare alphabetically here because all the names start with a capital letter; mixing upper and lowercase would change the order (`"a" > "Z"`), and the array would have to be sorted with the same rule the search uses. "Pablo" falls between "Marta" and "Sofía", the range closes, and the function returns -1.
````

````exercise
id: m15-l03-e5
type: solve
prompt: |
  Write `func guesses(toFind secret: Int, from low: Int, to high: Int) -> Int` that plays the number-guessing game with the binary search strategy: guess the middle of the remaining range, and narrow the range after each "higher" or "lower". Return how many guesses it took.

  Then find the worst case over every secret from 1 to 100, and from 1 to 1,000. Print:

  ```output
  secret 50: 1 guesses
  secret 1: 6 guesses
  worst for 1...100: 7
  worst for 1...1000: 10
  ```
starter: |
  func guesses(toFind secret: Int, from low: Int, to high: Int) -> Int {
      var count = 0
      // Your loop
      return count
  }
hints:
  - Copy the shape of binarySearch, with the range of numbers instead of array indexes.
  - "For the worst case, loop over every secret and keep the largest count with max."
rubric:
  - The function narrows the range with guess + 1 and guess - 1.
  - The output matches.
  - I connected the worst cases (7 and 10) to log₂ of 100 and 1,000.
solution: |
  ```swift
  func guesses(toFind secret: Int, from low: Int, to high: Int) -> Int {
      var low = low
      var high = high
      var count = 0
      while low <= high {
          count += 1
          let guess = low + (high - low) / 2
          if guess == secret {
              return count
          } else if guess < secret {
              low = guess + 1
          } else {
              high = guess - 1
          }
      }
      return count
  }

  print("secret 50: \(guesses(toFind: 50, from: 1, to: 100)) guesses")
  print("secret 1: \(guesses(toFind: 1, from: 1, to: 100)) guesses")

  for limit in [100, 1_000] {
      var worst = 0
      for secret in 1...limit {
          worst = max(worst, guesses(toFind: secret, from: 1, to: limit))
      }
      print("worst for 1...\(limit): \(worst)")
  }
  ```

  ```output
  secret 50: 1 guesses
  secret 1: 6 guesses
  worst for 1...100: 7
  worst for 1...1000: 10
  ```

  `var low = low` makes a local, changeable copy of the parameter, which can't be reassigned (Module 6). The first guess for 1...100 is 1 + 99 / 2 = 50, so 50 takes one guess. The worst case is ⌊log₂ n⌋ + 1: ⌊log₂ 100⌋ = 6, so 7; ⌊log₂ 1,000⌋ = 9, so 10. Ten times the numbers, three more guesses.
````

````exercise
id: m15-l03-e6
type: explain
prompt: |
  A screen shows a list of 2,000 products and has a search box. Each time the user types, the app checks whether a product ID is in the list. A teammate proposes sorting the list with `sorted()` inside the search function, right before a binary search, "because binary search is O(log n)". Explain what the search really costs now and what you'd do instead.
code: |
  func isListed(_ id: Int, in products: [Int]) -> Bool {
      let sortedIDs = products.sorted()
      var low = 0
      var high = sortedIDs.count - 1
      while low <= high {
          let mid = low + (high - low) / 2
          if sortedIDs[mid] == id {
              return true
          } else if sortedIDs[mid] < id {
              low = mid + 1
          } else {
              high = mid - 1
          }
      }
      return false
  }
rubric:
  - I identified that sorting on every search costs O(n log n) per search, which is worse than a linear search's O(n).
  - I proposed sorting once (when the list loads or changes) and binary searching after that.
  - I mentioned that the list must be re-sorted, or kept sorted, when products are added.
  - I mentioned a Set (lesson 5) as an alternative for pure membership checks.
solution: |
  Sorting inside the search makes every search cost O(n log n) for the sort plus O(log n) for the binary search: O(n log n) per search. A plain linear search is O(n), so the "optimization" made each search slower. For 2,000 products that's on the order of 2,000 × 11 = 22,000 comparisons per keystroke instead of at most 2,000.

  Binary search pays off when you **sort once and search many times**. Sort the list when it loads (or keep it sorted as products are added) and store the sorted array. After that, each search is O(log n), about 11 comparisons for 2,000 products.

  If the only question is "is this ID in the list?", a `Set` of IDs, built once, answers it in O(1) on average and doesn't need sorting at all. Lesson 5 covers what that costs.
````

## Summary

- **log₂ n** is how many times you can halve n before reaching 1: 10 for a thousand, about 20 for a million, about 30 for a billion. In Big O the base doesn't matter.
- An algorithm that halves its problem each step is **O(log n)**: doubling the input adds one step.
- **Binary search** keeps an inclusive range `low...high`, compares with the middle, and moves `low = mid + 1` or `high = mid - 1`. It needs **sorted** input, returns any matching index when there are duplicates, and handles empty arrays with `high = -1`.
- Test a binary search on the first, last, missing, smaller-than-all, larger-than-all, empty and one-element cases, and compare it with `firstIndex(of:)`.
- **O(n log n)** is n times a halving. Sorting with `sorted()` or `sort()` is O(n log n), according to Apple's documentation.
- Sort once and search many times. Sorting before every search is slower than a linear search.
