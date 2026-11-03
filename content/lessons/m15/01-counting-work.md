---
id: m15-l01
title: Counting the work an algorithm does
description: You stop asking "how many seconds?" and start asking "how many steps, for an input of size n?". You count steps with a counter variable, watch the count grow as the input grows, and separate the best, worst and average case of a linear search.
module: m15
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l06]
objectives:
  - Explain why running time in seconds is a poor way to compare algorithms.
  - Pick the basic operation to count and count it with a counter variable.
  - Describe how a step count changes when the input size doubles or grows tenfold.
  - Find the best, worst and average case of a linear search and say which inputs cause each.
terms:
  - term: Input size (n)
    definition: The number that measures how big the input is, usually the number of elements in an array or the characters in a string. Step counts are written in terms of n.
  - term: Basic operation
    definition: The operation you choose to count, such as a comparison or an addition. Pick the one that runs most often, usually the one inside the innermost loop.
  - term: Step count
    definition: How many times the basic operation runs for a given input.
  - term: Best case
    definition: The input of size n that makes the algorithm do the least work.
  - term: Worst case
    definition: The input of size n that makes the algorithm do the most work. It's a guarantee, so it's the case people quote by default.
  - term: Average case
    definition: The expected work over all inputs of size n, under an assumption about how likely each input is.
mastery:
  - Add a counter to a function, return it alongside the result, and report the count for several input sizes.
  - Predict exactly how many comparisons a linear search makes for a given array and target.
  - Name the inputs that produce the best and worst case of a function with an early exit.
  - Explain why "it ran in 3 ms on my Mac" doesn't tell you how the code behaves on ten times more data.
resources: [swift-array, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m15-l01-c1
    front: Why don't we compare algorithms by their running time in seconds?
    back: Seconds depend on the machine, the build settings (Debug or Release), what else is running and the exact input. A step count depends only on the algorithm and the input, so it says how the work grows.
  - id: m15-l01-c2
    front: Which operation should you count?
    back: The basic operation that runs most often, usually the comparison or update inside the innermost loop. The rest of the code runs fewer times and stops mattering as the input grows.
  - id: m15-l01-c3
    front: Best, worst and average case of a linear search on n elements?
    back: "Best: 1 comparison (the target is first). Worst: n (it's last or missing). Average: (n + 1) / 2 if the target is present and equally likely to be at any position."
  - id: m15-l01-c4
    front: Why is the worst case the default?
    back: It's a promise. Whatever the input, the algorithm never does more than that. The best case promises nothing, and the average case depends on assumptions about the inputs.
---

## The idea in one sentence

To compare algorithms, count how many basic steps each one takes for an input of size n, and look at **how that count grows as n grows**.

## Why not just time it?

The obvious way to find out which of two functions is faster is to run both and look at a clock. It's also the least reliable, for reasons that have nothing to do with the algorithm:

- **The machine.** A newer Mac or iPhone runs the same code faster.
- **The build.** Xcode's Debug configuration builds without optimizations and Release builds with them. The same loop can run many times faster in Release.
- **Everything else.** Other apps, the system, the temperature of the chip. Two runs of the same program rarely take the same time.
- **The input.** A search that finds its target in the first slot finishes instantly, whatever the algorithm.

Timing still matters: when an app is slow, you measure it with Instruments, and you'll do that later in the course. But a time measured on one machine, with one input, can't tell you what happens with ten times more data. A step count can.

**A step** is one run of the operation you decide to count: a comparison, an addition, a lookup. You pick the **basic operation**, the one that runs most often. Everything else in the function runs fewer times and stops mattering once the input gets big.

## Counting with a counter

Add a variable that goes up by one every time the basic operation runs. Here the basic operation is the addition inside the loop:

```swift
func sumWithSteps(_ values: [Int]) -> (sum: Int, steps: Int) {
    var sum = 0
    var steps = 0
    for value in values {
        sum += value
        steps += 1
    }
    return (sum, steps)
}

for size in [10, 100, 1_000] {
    let values = Array(1...size)
    let result = sumWithSteps(values)
    print("n = \(size): sum \(result.sum), \(result.steps) steps")
}
```

```output
n = 10: sum 55, 10 steps
n = 100: sum 5050, 100 steps
n = 1000: sum 500500, 1000 steps
```

1. `steps` starts at 0, like any accumulator.
2. It goes up once per addition, right next to the addition it counts.
3. The function returns a tuple (Module 6), so the caller gets the answer and the count together.
4. `Array(1...size)` builds the array `[1, 2, …, size]`, so each run has a different **input size**.

The count is exactly n. Ten times the input, ten times the steps. That sentence is what you're after in this module: not "1,000 steps", but "**steps grow in proportion to n**".

> [!note] Why the counter lives inside the function
> A global `var steps` that functions update would be simpler, but Swift 6 doesn't allow it in a program like this one. Top-level variables in `main.swift` belong to the main actor, and a plain function can't change them. The concurrency module (Module 29) explains actors. Here, keep the counter local and return it.

```swift no-compile main actor-isolated var 'steps' can not be mutated from a nonisolated context
var steps = 0

func countAdditions(_ values: [Int]) -> Int {
    var sum = 0
    for value in values {
        sum += value
        steps += 1
    }
    return sum
}

print(countAdditions([1, 2, 3]), steps)
```

Swift 6.3 reports `error: main actor-isolated var 'steps' can not be mutated from a nonisolated context`.

## Counts grow in different ways

Three functions over the same array, each counting its comparisons:

```swift
func checkFirst(_ values: [Int]) -> Int {
    var comparisons = 0
    if !values.isEmpty {
        comparisons += 1
        if values[0] < 0 {
            print("first value is negative")
        }
    }
    return comparisons
}

func countNegatives(_ values: [Int]) -> Int {
    var comparisons = 0
    for value in values {
        comparisons += 1
        if value < 0 {
            print("found a negative")
        }
    }
    return comparisons
}

func compareAllPairs(_ values: [Int]) -> Int {
    var comparisons = 0
    for a in values {
        for b in values {
            comparisons += 1
            if a + b == -1 {
                print("found a pair")
            }
        }
    }
    return comparisons
}

print("n", "first", "each", "pairs")
for size in [10, 100, 1_000] {
    let values = Array(1...size)
    print(size, checkFirst(values), countNegatives(values), compareAllPairs(values))
}
```

```output
n first each pairs
10 1 10 100
100 1 100 10000
1000 1 1000 1000000
```

The values are all positive, so none of the `print` calls inside the functions run; they're there so each comparison has a reason to exist.

Read the table by columns, as n goes up by a factor of 10:

| Function | n = 10 | n = 100 | n = 1,000 | When n grows ×10 |
| --- | --- | --- | --- | --- |
| `checkFirst` | 1 | 1 | 1 | stays the same |
| `countNegatives` | 10 | 100 | 1,000 | grows ×10 |
| `compareAllPairs` | 100 | 10,000 | 1,000,000 | grows ×100 |

At n = 10 the difference between 10 and 100 comparisons is invisible. At n = 1,000,000 it's the difference between a million comparisons and a trillion. That's why you care about the **shape** of the growth and not about the count for one small input. The next lesson gives these shapes names.

## Best, worst and average case

The step count doesn't depend only on n. A function that can stop early does different amounts of work on inputs of the same size. Linear search, from Module 7, is the standard example:

```swift
func linearSearch(for target: Int, in values: [Int]) -> (index: Int?, comparisons: Int) {
    var comparisons = 0
    for (index, value) in values.enumerated() {
        comparisons += 1
        if value == target {
            return (index, comparisons)
        }
    }
    return (nil, comparisons)
}

let values = [42, 7, 19, 88, 3]
for target in [42, 19, 3, 50] {
    let result = linearSearch(for: target, in: values)
    print("\(target): index \(result.index ?? -1), \(result.comparisons) comparisons")
}
```

```output
42: index 0, 1 comparisons
19: index 2, 3 comparisons
3: index 4, 5 comparisons
50: index -1, 5 comparisons
```

Same array, n = 5, and the count goes from 1 to 5:

- **Best case**: the target is the first element. 1 comparison, whatever n is.
- **Worst case**: the target is the last element, or isn't there at all. n comparisons.
- **Average case**: depends on what inputs you expect. If the target is always present and equally likely to be at any position, add up the cost of finding each one and divide by n:

```swift
func linearSearch(for target: Int, in values: [Int]) -> (index: Int?, comparisons: Int) {
    var comparisons = 0
    for (index, value) in values.enumerated() {
        comparisons += 1
        if value == target {
            return (index, comparisons)
        }
    }
    return (nil, comparisons)
}

for size in [5, 1_000] {
    let values = Array(1...size)
    var total = 0
    for target in values {
        total += linearSearch(for: target, in: values).comparisons
    }
    print("n = \(size): total \(total), average \(Double(total) / Double(size))")
}
```

```output
n = 5: total 15, average 3.0
n = 1000: total 500500, average 500.5
```

Finding position 1 costs 1, position 2 costs 2, up to n. The total is 1 + 2 + … + n = n(n + 1) / 2, so the average is **(n + 1) / 2**: about half the array. Notice the average still grows in proportion to n. Halving the work doesn't change the shape.

Which one do you quote? **The worst case**, unless someone asks otherwise. It's a guarantee: no input of size n makes the function do more. The best case is almost useless (every search is fast if you're lucky), and the average case is only as good as the assumption behind it. If most searches in your app are for names that aren't in the list, your real average is close to the worst case.

## A practical example: is this username taken?

A sign-up screen checks whether a username already exists. The existing names are in an array:

```swift
func isTaken(_ name: String, in existing: [String]) -> (taken: Bool, comparisons: Int) {
    var comparisons = 0
    for candidate in existing {
        comparisons += 1
        if candidate == name {
            return (true, comparisons)
        }
    }
    return (false, comparisons)
}

let existing = (1...50_000).map { number in "user\(number)" }
for name in ["user7", "user50000", "christian"] {
    let result = isTaken(name, in: existing)
    print("\(name): taken \(result.taken), \(result.comparisons) comparisons")
}
```

```output
user7: taken true, 7 comparisons
user50000: taken true, 50000 comparisons
christian: taken false, 50000 comparisons
```

The case that matters most on a sign-up screen is a **new** name, which is the worst case: every existing user gets compared. With 50,000 users that's 50,000 comparisons per check; with 5 million users it's 5 million. On one phone, one check, you might never notice. On a server handling thousands of sign-ups, the cost grows with every user who joins. Lesson 5 shows the fix: a `Set` answers this question without walking the list.

## Common mistakes

> [!error] Timing one run and calling it the speed
> "It took 2 ms" describes one input, on one machine, in one build configuration. It says nothing about 100 times more data. Count steps for several sizes instead, or, when you do need real timings, measure a Release build with Instruments over realistic inputs.

> [!error] error: main actor-isolated var 'steps' can not be mutated from a nonisolated context
> A global counter changed from inside a function. Keep the counter as a local `var` and return it, as the examples above do.

> [!error] Counting the wrong operation
> Counting only the outer loop of two nested loops reports n when the real work is n × n. Put the counter next to the operation that runs most often, which is usually in the innermost loop.

> [!error] Quoting the best case
> "Linear search takes 1 step if the element is first" is true and useless. Say what happens for the worst input of size n, and mention the best case only if it matters.

> [!error] Not saying what n is
> "It takes n steps" means nothing until you say n is the number of users, the length of the string, or the number of orders. When a function has two inputs, they usually need two letters (lesson 4).

## Exercises

````exercise
id: m15-l01-e1
type: comprehension
prompt: Your function took 4 ms on your Mac with a 1,000-element array. Which statement is correct?
choices:
  - text: On an array of 10,000 elements it will take 40 ms.
    correct: false
    why: That's only true if the work grows in proportion to n, and one measurement can't tell you that. If it compares all pairs, it could take about 100 times longer.
  - text: The measurement can't tell you how the work grows. Counting steps for several input sizes can.
    correct: true
    why: A step count for 1,000, 2,000 and 10,000 elements shows the growth directly, on any machine.
  - text: It will take 4 ms on any device, because the code is the same.
    correct: false
    why: The device, the build configuration and the rest of the system all change the time.
  - text: 4 ms is fast, so the algorithm is efficient.
    correct: false
    why: A small input hides the growth. An algorithm that does n × n work is fast at n = 10 and unusable at n = 1,000,000.
solution: |
  **The second one.** A time is one data point: one machine, one build, one input. To know how the function behaves on more data, you need to know how its work grows with n, and a step count measured for several sizes shows exactly that. The 40 ms guess assumes the answer before you've checked it.
````

````exercise
id: m15-l01-e2
type: prediction
prompt: Predict the exact output. Count carefully when the loop stops.
code: |
  func stepsUntilZero(_ values: [Int]) -> Int {
      var steps = 0
      for value in values {
          steps += 1
          if value == 0 {
              break
          }
      }
      return steps
  }

  print(stepsUntilZero([4, 0, 9, 9]))
  print(stepsUntilZero([4, 5, 9]))
  print(stepsUntilZero([]))
  print(stepsUntilZero([0, 0, 0]))
output: |
  2
  3
  0
  1
hints:
  - The counter goes up before the check, so the element that triggers the break is counted.
  - An empty array runs the loop body zero times.
solution: |
  ```output
  2
  3
  0
  1
  ```

  - `[4, 0, 9, 9]`: 4 is counted (1), 0 is counted (2) and the loop breaks. The two 9s are never checked.
  - `[4, 5, 9]`: no zero, so every element is checked: 3. This is the worst case for n = 3.
  - `[]`: nothing to check, 0 steps.
  - `[0, 0, 0]`: the first element stops it, 1 step. This is the best case.
````

````exercise
id: m15-l01-e3
type: fill-in
prompt: |
  Complete the function so it returns the largest value and how many comparisons it made. For `[3, 9, 4, 1]` it should print `9 3`: with n elements, finding the largest takes n − 1 comparisons, because the first element isn't compared with anything.
code: |
  func largest(_ values: [Int]) -> (value: Int, comparisons: Int) {
      var best = values[0]
      var comparisons = [[1]]
      for index in 1..<values.count {
          comparisons [[2]] 1
          if values[index] [[3]] best {
              best = values[index]
          }
      }
      return (best, comparisons)
  }

  let result = largest([3, 9, 4, 1])
  print(result.value, result.comparisons)
blanks:
  - id: "1"
    answers: ["0"]
  - id: "2"
    answers: ["+="]
  - id: "3"
    answers: [">"]
solution: |
  ```swift
  func largest(_ values: [Int]) -> (value: Int, comparisons: Int) {
      var best = values[0]
      var comparisons = 0
      for index in 1..<values.count {
          comparisons += 1
          if values[index] > best {
              best = values[index]
          }
      }
      return (best, comparisons)
  }

  let result = largest([3, 9, 4, 1])
  print(result.value, result.comparisons)
  ```

  ```output
  9 3
  ```

  The counter starts at 0 and goes up once per comparison, right next to the `if` it counts. The loop starts at index 1, so it runs n − 1 times: 3 for four elements. This function has no early exit, so best, worst and average case are all the same, n − 1. It does assume a non-empty array: `values[0]` crashes on `[]`.
````

````exercise
id: m15-l01-e4
type: solve
prompt: |
  Write `func isSorted(_ values: [Int]) -> (sorted: Bool, comparisons: Int)` that checks whether each element is less than or equal to the next one. It must stop at the first pair that's out of order and count every comparison of neighbors.

  Print the result for `[1, 2, 2, 5, 8, 9]`, `[5, 1, 2, 3, 4, 6]`, `[1, 2, 3, 4, 6, 5]` and `[]`. Then write down which of the two six-element inputs is the best case and which is the worst case, and how many comparisons each takes for n elements.
starter: |
  func isSorted(_ values: [Int]) -> (sorted: Bool, comparisons: Int) {
      var comparisons = 0
      // Your loop
      return (true, comparisons)
  }
hints:
  - Compare values[index] with values[index + 1]. Which indexes have a next element?
  - "For an empty array, values.count - 1 is -1, and a range like 0..<(-1) crashes. Handle the short arrays first."
rubric:
  - The function stops at the first pair out of order.
  - It doesn't crash on an empty array or a one-element array.
  - The output matches, line by line.
  - I identified the best case (first pair out of order, 1 comparison) and the worst case (sorted, or the last pair out of order, n − 1 comparisons).
solution: |
  ```swift
  func isSorted(_ values: [Int]) -> (sorted: Bool, comparisons: Int) {
      var comparisons = 0
      guard values.count > 1 else {
          return (true, comparisons)
      }
      for index in 0..<(values.count - 1) {
          comparisons += 1
          if values[index] > values[index + 1] {
              return (false, comparisons)
          }
      }
      return (true, comparisons)
  }

  for sample in [[1, 2, 2, 5, 8, 9], [5, 1, 2, 3, 4, 6], [1, 2, 3, 4, 6, 5], []] {
      let result = isSorted(sample)
      print(result.sorted, result.comparisons)
  }
  ```

  ```output
  true 5
  false 1
  false 5
  true 0
  ```

  The `guard` handles arrays of 0 or 1 elements, which are sorted by definition and have no neighbors to compare. Without it, `0..<(values.count - 1)` would be `0..<(-1)` for an empty array, and Swift traps when a range's upper bound is below its lower bound.

  - **Best case**: the first pair is out of order, like `[5, 1, …]`. 1 comparison, whatever n is.
  - **Worst case**: the array is sorted, or only the last pair is out of order. n − 1 comparisons: 5 for six elements.

  A sorted array being the worst case is common for "check every pair" functions: proving something is true for all elements means looking at all of them.
````

````exercise
id: m15-l01-e5
type: explain
prompt: |
  A teammate says: "My search is fast. I tested it with the name at the start of the list and it found it in one step." Explain what's missing from that test, which inputs you'd test instead, and what you'd report.
code: |
  func findUser(named name: String, in users: [String]) -> Int? {
      for (index, user) in users.enumerated() {
          if user == name {
              return index
          }
      }
      return nil
  }
rubric:
  - I identified the test as the best case.
  - I named the worst case inputs (last element, and a name that isn't there) and their cost, n comparisons.
  - I mentioned that the average when the name is present is about n / 2, and that it still grows with n.
  - I said the result should be stated in terms of n, with n defined as the number of users.
solution: |
  The test only covers the **best case**: the name is first, so the loop stops after one comparison. Every search is fast when you're lucky.

  The inputs that matter:
  - **The last name in the list**: n comparisons.
  - **A name that isn't there**: also n comparisons, and on a sign-up or search screen it's a common case.
  - For a feel of typical cost, the **average** when the name is present and equally likely anywhere is (n + 1) / 2 comparisons, about half the list. That still grows in proportion to n.

  What to report: "In the worst case it compares the name with every user, so the work grows in proportion to n, the number of users." A count for n = 1,000 and n = 10,000 would show it.
````

````exercise
id: m15-l01-e6
type: comprehension
multiple: true
prompt: For the `linearSearch(for:in:)` function in this lesson, which of these change the number of comparisons it makes? Select all that apply.
choices:
  - text: The number of elements in the array
    correct: true
    why: The worst case is n comparisons, so a bigger array means more comparisons when the target is late or missing.
  - text: The position of the target in the array
    correct: true
    why: The search stops at the first match. A target at index 0 costs 1; at the end it costs n.
  - text: Whether the target is in the array at all
    correct: true
    why: A missing target forces the search to check every element.
  - text: The speed of the device it runs on
    correct: false
    why: A faster device makes each comparison take less time, but it does exactly the same comparisons.
  - text: Whether you build in Debug or Release
    correct: false
    why: Optimizations change how long each step takes, not how many comparisons the algorithm describes.
solution: |
  **The first three.** The step count depends only on the algorithm and its input: how big the input is (n), and what's in it (where the target is, or whether it's there). The device and the build configuration change the time per step, not the number of steps. That's exactly why counting steps is a fairer way to compare algorithms than timing them.
````

## Summary

- Running time depends on the machine, the build, the system load and the input. To compare algorithms, count steps instead.
- Choose the **basic operation**, the one that runs most often, and count it with a local `var` that goes up right next to it. Return the count with the result.
- What matters is how the count **grows** with the input size n: staying the same, growing ×10 when n grows ×10, or growing ×100.
- A function that can stop early has a **best case**, a **worst case** and an **average case**. Linear search: 1, n and (n + 1) / 2 comparisons.
- Quote the worst case by default. It's the only one that's a guarantee.
