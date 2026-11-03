---
id: m15-l02
title: Big O notation
description: You turn a step count like 3n + 2 into O(n) by dropping constants and smaller terms, learn what Big O promises and what it doesn't, recognize O(1), O(n) and O(n²) in code, place them on the ladder of common classes, and use the doubling test to check a guess.
module: m15
order: 2
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l01]
objectives:
  - Simplify a step count to its Big O class by keeping the fastest-growing term and dropping constants.
  - Explain that Big O is an upper bound on growth, and what people usually mean by it in practice.
  - Recognize O(1), O(n) and O(n²) code and give an example of each.
  - Order the common classes from O(1) to O(n!) and estimate how each grows.
  - Use the doubling test to check a complexity from step counts.
terms:
  - term: Big O notation
    definition: A way to describe how a function's step count grows with n, keeping only the fastest-growing term and dropping constant factors. 3n + 2 is O(n).
  - term: Upper bound
    definition: A limit the count never goes above, once n is big enough. Saying a function is O(n²) promises it grows no faster than n², up to a constant factor.
  - term: Tight bound
    definition: A bound that's also the real growth rate, not just a limit. Linear search's worst case is O(n), and that's tight; calling it O(n²) is true but uninformative.
  - term: Constant time, O(1)
    definition: The step count doesn't depend on n. It can be 1 step or 50, as long as it stays the same when n grows.
  - term: Linear time, O(n)
    definition: The step count grows in proportion to n. Double n, and the count roughly doubles.
  - term: Quadratic time, O(n²)
    definition: The step count grows with the square of n, usually from a loop inside a loop over the same data. Double n, and the count roughly quadruples.
mastery:
  - Reduce counts like 5n² + 3n + 100, n(n − 1) / 2 and 2n + 7 to their Big O class.
  - Point to the line or loop in a function that decides its complexity.
  - Predict how a step count changes when n doubles for O(1), O(log n), O(n) and O(n²).
  - Explain why an O(n) function isn't always faster than an O(n²) one for small inputs.
resources: [swift-array, swift-book-collection-types]
cards:
  - id: m15-l02-c1
    front: What's 4n² + 100n + 7 in Big O?
    back: O(n²). Keep the fastest-growing term and drop its constant factor. For large n, the n² term is almost all of the count.
  - id: m15-l02-c2
    front: Does O(1) mean "one step"?
    back: No. It means the count doesn't grow with n. A function that always does 500 steps is O(1).
  - id: m15-l02-c3
    front: What happens to the step count when n doubles, for O(1), O(log n), O(n) and O(n²)?
    back: "O(1): stays the same. O(log n): goes up by about one step. O(n): doubles. O(n²): about four times."
  - id: m15-l02-c4
    front: Big O is an upper bound. What do people usually mean when they say "this is O(n)"?
    back: The tightest bound they can give, usually for the worst case. Linear search is technically also O(n²), but nobody says that, because it hides the real growth.
  - id: m15-l02-c5
    front: "Order these from slowest to fastest growth: O(n log n), O(1), O(2ⁿ), O(n), O(log n), O(n²)."
    back: O(1), O(log n), O(n), O(n log n), O(n²), O(2ⁿ).
---

## The idea in one sentence

Big O keeps only the part of a step count that decides how it grows, so `3n + 2` and `n` get the same name, **O(n)**, and `n(n − 1) / 2` becomes **O(n²)**.

## From an exact count to a growth class

In lesson 1 you counted steps exactly. Exact counts are useful for checking your reasoning, but they're noisy for comparing algorithms. Here's a function that finds the smallest and the largest value with two separate loops:

```swift
func range(of values: [Int]) -> (low: Int, high: Int, steps: Int) {
    var steps = 0
    var low = values[0]
    var high = values[0]
    steps += 2
    for value in values {
        steps += 1
        if value < low {
            low = value
        }
    }
    for value in values {
        steps += 1
        if value > high {
            high = value
        }
    }
    return (low, high, steps)
}

for size in [10, 100, 1_000] {
    let result = range(of: Array(1...size))
    print("n = \(size): \(result.steps) steps")
}
```

```output
n = 10: 22 steps
n = 100: 202 steps
n = 1000: 2002 steps
```

The count is **2n + 2**: two setup steps, then n comparisons per loop. Now ask what decides how this grows. Not the `+ 2`: at n = 1,000 it's a rounding error. Not the factor 2 either: it depends on details like whether you count the setup, or whether both comparisons happen in one loop. What doesn't change, however you count, is that the work grows **in proportion to n**. That's O(n).

The two rules:

1. **Keep the fastest-growing term.** In `n² + 3n + 100`, the `n²` term dominates for large n, so drop `3n` and `100`.
2. **Drop constant factors.** `2n`, `n / 2` and `100n` are all O(n). `n² / 2` is O(n²).

Why the smaller terms stop mattering, with the pair count `n(n − 1) / 2` from comparing every pair once:

| n | n(n − 1) / 2 | n² / 2 | Difference |
| --- | --- | --- | --- |
| 10 | 45 | 50 | 10% |
| 100 | 4,950 | 5,000 | 1% |
| 1,000 | 499,500 | 500,000 | 0.1% |

`n(n − 1) / 2 = n²/2 − n/2`. As n grows, the `n/2` part becomes a smaller and smaller share, and what's left is the `n²` shape. So the pair count is O(n²).

## What Big O promises, precisely

**Plain definition:** O(g(n)) is a ceiling on how fast the count grows. Saying a function is O(n) means its count grows no faster than n, give or take a constant factor.

**Precise definition:** a count f(n) is O(g(n)) if there's a constant c and a size n₀ such that f(n) ≤ c · g(n) for every n ≥ n₀. For `2n + 2`, pick c = 3 and n₀ = 2: from n = 2 on, `2n + 2 ≤ 3n`. That's all the math you need. The point is that Big O ignores small inputs (n₀) and constant factors (c).

Two consequences people get wrong:

- **Big O is an upper bound, so it can be loose.** Linear search's worst case is O(n). It's also, technically, O(n²) and O(2ⁿ): its count never grows faster than those either. Those statements are true and useless. In practice, and in every interview, "this is O(n)" means **the tightest bound you can give**. Textbooks have separate symbols for this: Θ (theta) for a tight bound and Ω (omega) for a lower bound. You'll see them in references; in conversation, people say "O" and mean the tight one.
- **Big O and worst case are different things.** Big O describes how *some* count grows. Worst case says *which* count you're describing. "Linear search is O(1) in the best case and O(n) in the worst case" is a correct sentence. When someone says "linear search is O(n)" without a qualifier, they mean the worst case.

Big O also says nothing about seconds. An O(n) function whose loop body does 1,000 operations is slower than an O(n²) function on 10 elements. Big O tells you which one **wins as n grows**, not which one is faster on a given input.

## The three classes you'll see most

### O(1): constant time

The count doesn't depend on n at all.

```swift
func firstAndLast(_ values: [Int]) -> (first: Int, last: Int)? {
    guard !values.isEmpty else {
        return nil
    }
    return (values[0], values[values.count - 1])
}

if let ends = firstAndLast([4, 8, 15, 16, 23, 42]) {
    print(ends.first, ends.last)
}
```

```output
4 42
```

Reading `values[0]` takes the same time for an array of 6 or 6 million elements. Apple's documentation for the `Array` subscript states: "Reading an element from an array is O(1)." `isEmpty` and `count` are O(1) on an array too.

O(1) doesn't mean "one step". A function that checks the first 10 elements of an array, no matter how long the array is, does at most 10 steps for every n. That's O(1).

### O(n): linear time

One pass over the input, with constant work per element:

```swift
func countAbove(_ limit: Int, in values: [Int]) -> Int {
    var count = 0
    for value in values {
        if value > limit {
            count += 1
        }
    }
    return count
}

print(countAbove(10, in: [4, 8, 15, 16, 23, 42]))
```

```output
4
```

Linear search, sum, minimum, maximum, `contains`, `firstIndex(of:)` and `map` are all O(n).

### O(n²): quadratic time

A loop over the input inside another loop over the same input:

```swift
func countEqualPairs(_ values: [Int]) -> Int {
    var pairs = 0
    for i in values.indices {
        for j in values.indices where i < j {
            if values[i] == values[j] {
                pairs += 1
            }
        }
    }
    return pairs
}

print(countEqualPairs([3, 1, 3, 2, 3]))
```

```output
3
```

The inner loop runs n times for each of the n outer passes: n × n checks of `i < j`. The three 3s form three pairs: (0, 2), (0, 4) and (2, 4). Comparing every element with every other is the most common source of O(n²) code.

## The ladder of common classes

From slowest-growing to fastest-growing, with rough counts:

| Class | Name | n = 10 | n = 1,000 | n = 1,000,000 | Typical source |
| --- | --- | --- | --- | --- | --- |
| O(1) | constant | 1 | 1 | 1 | array subscript, `isEmpty` |
| O(log n) | logarithmic | ≈ 3 | ≈ 10 | ≈ 20 | binary search (lesson 3) |
| O(n) | linear | 10 | 1,000 | 1,000,000 | one pass |
| O(n log n) | linearithmic | ≈ 33 | ≈ 10,000 | ≈ 20,000,000 | sorting |
| O(n²) | quadratic | 100 | 1,000,000 | 10¹² | all pairs |
| O(2ⁿ) | exponential | 1,024 | ≈ 10³⁰¹ | unthinkable | all subsets, naive recursion |
| O(n!) | factorial | 3,628,800 | unthinkable | unthinkable | all orderings |

Look down the n = 1,000,000 column. Everything up to O(n log n) is fine for a phone. O(n²) is a trillion steps, far too slow for anything a user is waiting on. Exponential and factorial algorithms only work for tiny inputs: 2⁶⁰ is already more than 10¹⁸.

## Reading complexity from code

You don't need to count exactly every time. Look at the loops:

- **Statements in sequence add up.** A loop then another loop: O(n) + O(n) = O(n). A loop then a nested loop: O(n) + O(n²) = O(n²).
- **Nested loops multiply.** A loop of n passes whose body is O(n) is O(n × n) = O(n²).
- **A loop with a fixed number of passes is O(1)**, whatever is inside, as long as the inside doesn't depend on n. Looping over 26 letters or 7 weekdays is constant.
- **A loop that skips elements is still O(n)** if the number of passes is a fraction of n. `stride(from: 0, to: n, by: 2)` makes n/2 passes: O(n).

### The doubling test

To check a guess, count steps for n and 2n and look at the ratio:

```swift
func constantWork(_ n: Int) -> Int {
    var steps = 0
    for _ in 0..<5 {
        steps += 1
    }
    return steps
}

func linearWork(_ n: Int) -> Int {
    var steps = 0
    for _ in 0..<n {
        steps += 1
    }
    return steps
}

func quadraticWork(_ n: Int) -> Int {
    var steps = 0
    for _ in 0..<n {
        for _ in 0..<n {
            steps += 1
        }
    }
    return steps
}

for n in [100, 200, 400] {
    print(n, constantWork(n), linearWork(n), quadraticWork(n))
}
```

```output
100 5 100 10000
200 5 200 40000
400 5 400 160000
```

Each time n doubles: the constant count stays at 5, the linear count doubles, and the quadratic count goes ×4. If your counts go ×4 when n doubles, you have O(n²), whatever the code looks like.

## A practical example: three ways to check a list of order IDs

An order screen receives a list of order IDs and has to answer three questions. Here's each one with its complexity, where n is the number of IDs:

```swift
let orderIDs = [1042, 1043, 1044, 1043, 1047]

// 1. Is the list empty? O(1): isEmpty doesn't look at the elements.
print(orderIDs.isEmpty)

// 2. Does it contain order 1047? O(n): contains checks the elements one by one.
print(orderIDs.contains(1047))

// 3. Is any ID repeated? O(n²): every ID is compared with every later one.
var hasRepeat = false
for i in orderIDs.indices {
    for j in (i + 1)..<orderIDs.count where orderIDs[i] == orderIDs[j] {
        hasRepeat = true
    }
}
print(hasRepeat)
```

```output
false
true
true
```

For five orders, all three are instant. For 100,000 orders, the first is still one step, the second is up to 100,000 comparisons, and the third is about 5 billion. The repeat check is the one that needs a better algorithm, and lesson 5 gives you one. (It's also the [Contains Duplicate](#/challenge/contains-duplicate) challenge, if you want to try it now.)

## Common mistakes

> [!error] Writing O(2n) or O(n² + n)
> Constant factors and smaller terms go. O(2n) is O(n); O(n² + n) is O(n²). Writing them out isn't wrong, but it tells the listener you're not sure what Big O drops.

> [!error] Reading O(1) as "one step" or "instant"
> O(1) means the count doesn't grow with n. A constant-time operation can still be slow; it's just equally slow for every n.

> [!error] "O(n) is always faster than O(n²)"
> Only for large enough n. For small inputs, constant factors win: an O(n) algorithm with heavy work per element can lose to a simple nested loop over 20 items. Big O ranks growth, not speed on one input.

> [!error] Counting loops without looking at what's inside them
> A single loop is O(n) only if its body is O(1). A loop that calls `contains` on an array inside its body is O(n²), because `contains` is a loop too. Lesson 4 is about these hidden loops.

> [!error] Leaving n undefined
> "O(n)" with no n is half an answer. Say "where n is the number of orders". When there are two inputs, use two letters.

## Exercises

````exercise
id: m15-l02-e1
type: comprehension
prompt: A function's exact step count is 4n² + 100n + 7. What's its Big O?
choices:
  - text: O(4n² + 100n + 7)
    correct: false
    why: That's the exact count. Big O keeps only the growth shape.
  - text: O(n²)
    correct: true
    why: Keep the fastest-growing term (4n²) and drop its constant factor (4).
  - text: O(n), because 100n is the biggest term for small n
    correct: false
    why: Big O is about large n. At n = 1,000, 4n² is 4,000,000 and 100n is 100,000.
  - text: O(100n²)
    correct: false
    why: Constant factors are dropped, and 100 isn't the factor on n² anyway.
solution: |
  **O(n²).** For small n the `100n` term is bigger (at n = 10, it's 1,000 against 400), but Big O describes growth as n gets large. Above n = 25, `4n²` is the larger term, and it pulls further ahead every time n grows. Drop the smaller terms, drop the factor 4, and you're left with n².
````

````exercise
id: m15-l02-e2
type: prediction
prompt: Predict the exact output. Then write the step count as a formula in n and give its Big O.
code: |
  func work(_ n: Int) -> Int {
      var steps = 0
      for _ in 0..<n {
          steps += 1
      }
      for _ in 0..<n {
          for _ in 0..<n {
              steps += 1
          }
      }
      for _ in 0..<5 {
          steps += 1
      }
      return steps
  }

  print(work(2))
  print(work(4))
  print(work(8))
output: |
  11
  25
  77
hints:
  - Count each of the three loops separately and add them.
  - The nested loop runs n times n.
solution: |
  ```output
  11
  25
  77
  ```

  The count is **n² + n + 5**: n for the first loop, n × n for the nested loops, and 5 for the fixed loop.
  - n = 2: 4 + 2 + 5 = 11
  - n = 4: 16 + 4 + 5 = 25
  - n = 8: 64 + 8 + 5 = 77

  Big O: **O(n²)**. Sequential parts add, and the largest one wins. You can see it in the numbers: from n = 4 to n = 8 the count goes from 25 to 77, about ×3, and the ratio keeps moving toward ×4 as n grows and the n² term takes over.
````

````exercise
id: m15-l02-e3
type: fill-in
prompt: Write the Big O of each function's worst case, where n is `values.count`. Use the forms `O(1)`, `O(n)` or `O(n²)`.
code: |
  // [[1]]
  func middle(_ values: [Int]) -> Int {
      values[values.count / 2]
  }

  // [[2]]
  func hasZero(_ values: [Int]) -> Bool {
      for value in values where value == 0 {
          return true
      }
      return false
  }

  // [[3]]
  func countSmallerPairs(_ values: [Int]) -> Int {
      var count = 0
      for a in values {
          for b in values where a < b {
              count += 1
          }
      }
      return count
  }

  // [[4]]
  func sumOfFirstTen(_ values: [Int]) -> Int {
      var sum = 0
      for value in values.prefix(10) {
          sum += value
      }
      return sum
  }
blanks:
  - id: "1"
    answers: ["O(1)"]
  - id: "2"
    answers: ["O(n)"]
  - id: "3"
    answers: ["O(n²)", "O(n^2)", "O(n*n)", "O(n * n)"]
  - id: "4"
    answers: ["O(1)"]
solution: |
  1. **O(1)**: one subscript read, whatever the length.
  2. **O(n)**: in the worst case (no zero) it checks every element. The early `return` only helps the best case.
  3. **O(n²)**: for each of the n values, the inner loop visits all n values.
  4. **O(1)**: `prefix(10)` gives at most 10 elements, so the loop makes at most 10 passes for any n. A bounded loop is constant time.

  ```swift
  func middle(_ values: [Int]) -> Int {
      values[values.count / 2]
  }

  func hasZero(_ values: [Int]) -> Bool {
      for value in values where value == 0 {
          return true
      }
      return false
  }

  func countSmallerPairs(_ values: [Int]) -> Int {
      var count = 0
      for a in values {
          for b in values where a < b {
              count += 1
          }
      }
      return count
  }

  func sumOfFirstTen(_ values: [Int]) -> Int {
      var sum = 0
      for value in values.prefix(10) {
          sum += value
      }
      return sum
  }

  let sample = Array(1...20)
  print(middle(sample), hasZero(sample), countSmallerPairs([3, 1, 2]), sumOfFirstTen(sample))
  ```

  ```output
  11 false 3 55
  ```
````

````exercise
id: m15-l02-e4
type: find-errors
prompt: A teammate wrote this review comment about the function below. Which statements in it are wrong?
code: |
  // Review comment:
  // "This is O(2n) because there are two loops. If the first element
  //  is the target it returns right away, so it's O(1). And since it's
  //  O(n) it'll always be faster than the O(n²) version we had before."
  func indexOfMinimumThenFind(_ target: Int, in values: [Int]) -> (Int, Int) {
      var minIndex = 0
      for index in values.indices where values[index] < values[minIndex] {
          minIndex = index
      }
      for index in values.indices where values[index] == target {
          return (minIndex, index)
      }
      return (minIndex, -1)
  }
choices:
  - text: "\"O(2n)\" should be written O(n)."
    correct: true
    why: Constant factors are dropped. Two sequential O(n) loops are O(n).
  - text: "\"It's O(1)\" is wrong: the first loop always visits every element, so even the best case is O(n)."
    correct: true
    why: The early return is in the second loop. The first loop runs to the end on every input.
  - text: "\"It'll always be faster than the O(n²) version\" is wrong: Big O compares growth, not speed on every input."
    correct: true
    why: For small arrays, constant factors decide. The O(n) version wins once n is large enough.
  - text: The function is O(n²) because there are two loops.
    correct: false
    why: The loops are one after the other, not nested. Sequential loops add; nested loops multiply.
rubric:
  - I found all three wrong statements.
  - I explained why the early return doesn't make the function O(1).
  - I didn't confuse sequential loops with nested loops.
solution: |
  Three of the four claims in the comment are wrong:

  - **"O(2n)"**: say O(n). Two loops in sequence add up to 2n, and the 2 goes.
  - **"It's O(1)"**: the early `return` only shortens the second loop. The first loop, which finds the minimum, always visits all n elements. Best case and worst case are both O(n).
  - **"Always faster than O(n²)"**: only for large enough n. Big O says the O(n) version **eventually** wins, not that it wins on a 5-element array.

  The distractor gets the loop structure wrong: two loops one after the other are O(n) + O(n), not O(n²).
````

````exercise
id: m15-l02-e5
type: solve
prompt: |
  Write `func countPairsSummingToZero(_ values: [Int]) -> (pairs: Int, comparisons: Int)` that counts the pairs of positions `i < j` with `values[i] + values[j] == 0`, and counts every sum it checks. Run it on `Array(-5..<5)`, `Array(-10..<10)` and `Array(-20..<20)` (10, 20 and 40 elements) and print the results. Then use the doubling test on the comparison counts to state the Big O.
starter: |
  func countPairsSummingToZero(_ values: [Int]) -> (pairs: Int, comparisons: Int) {
      var pairs = 0
      var comparisons = 0
      // Your loops
      return (pairs, comparisons)
  }
hints:
  - "Start the inner loop at i + 1 so each pair is checked once and no element is paired with itself."
  - "The comparison count should be n(n − 1) / 2."
rubric:
  - Each pair of positions is checked exactly once.
  - The output matches.
  - I used the ratio between consecutive comparison counts (about ×4) to conclude O(n²).
solution: |
  ```swift
  func countPairsSummingToZero(_ values: [Int]) -> (pairs: Int, comparisons: Int) {
      var pairs = 0
      var comparisons = 0
      for i in values.indices {
          for j in (i + 1)..<values.count {
              comparisons += 1
              if values[i] + values[j] == 0 {
                  pairs += 1
              }
          }
      }
      return (pairs, comparisons)
  }

  for values in [Array(-5..<5), Array(-10..<10), Array(-20..<20)] {
      let result = countPairsSummingToZero(values)
      print(values.count, result.pairs, result.comparisons)
  }
  ```

  ```output
  10 4 45
  20 9 190
  40 19 780
  ```

  `Array(-5..<5)` is -5 through 4. The pairs that sum to zero are (-4, 4), (-3, 3), (-2, 2) and (-1, 1); -5 has no partner because 5 isn't in the range. The comparison count is n(n − 1) / 2: 45, 190, 780. Each time n doubles, the count goes ×4.2 and then ×4.1, closing in on ×4. That's **O(n²)**.

  `(i + 1)..<values.count` is never a backwards range here: on the last pass `i + 1` equals `count`, which gives an empty range, not a crash.
````

````exercise
id: m15-l02-e6
type: explain
prompt: |
  A teammate rewrote this 10-line nested loop over the 7 days of the week into a 60-line version with a dictionary, saying "nested loops are O(n²), so this is faster now." Explain whether the rewrite was worth it, using what Big O does and doesn't say.
code: |
  let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  let busyDays = ["Tue", "Thu", "Sat"]
  var freeDays: [String] = []
  for day in days {
      var isBusy = false
      for busy in busyDays where busy == day {
          isBusy = true
      }
      if !isBusy {
          freeDays.append(day)
      }
  }
rubric:
  - I pointed out that n is fixed at 7, so both versions are effectively constant time.
  - I explained that Big O describes growth as n gets large, not speed on a small fixed input.
  - I mentioned that constant factors (like hashing) can make the "better" version slower for tiny inputs.
  - I weighed readability against a speedup nobody will measure.
solution: |
  Probably not. Big O describes how the work grows **as n grows**, and here n can't grow: a week has 7 days. The nested loop does at most 7 × 7 = 49 checks, every time. Both versions are bounded by a constant, so for this input both are effectively O(1).

  At this size, constant factors decide which version is faster, and they may favor the loop: a dictionary has to hash each key, and the nested loop over a small array does simple comparisons. Neither difference will show up in a profile.

  What did change is that the code got six times longer. The right question is "how big can n get here?" If the answer is "7, always", the simpler code wins. If the data could grow to thousands of items, the rewrite would be worth it, and that's lesson 6's topic.
````

## Summary

- Big O keeps the fastest-growing term of a step count and drops constant factors: `2n + 2` is O(n), `n(n − 1) / 2` is O(n²).
- Formally, Big O is an **upper bound**. In practice "this is O(n)" means the tightest bound you can give, usually for the worst case. Big O and worst case are separate ideas; say "best case" or "average case" when you mean them.
- **O(1)**: the count doesn't depend on n. **O(n)**: one pass. **O(n²)**: a loop over the data inside another loop over the same data.
- The ladder: O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) < O(n!).
- Sequential parts add, nested loops multiply, bounded loops are constant. Check a guess with the doubling test: same, +1, ×2 or ×4.
- Big O ranks growth, not seconds. For small, fixed inputs, the simpler code is usually the right choice.
