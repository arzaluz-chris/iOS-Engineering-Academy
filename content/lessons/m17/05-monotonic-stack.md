---
id: m17-l05
title: Monotonic stacks
description: You keep a stack whose values only increase or only decrease from bottom to top, and use it to find each element's next greater value, how long each day waits for a warmer one, and the largest rectangle under a bar chart, each in one O(n) pass, with the amortized argument that proves the nested loop isn't O(n²).
module: m17
order: 5
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l04]
objectives:
  - Recognize "next greater", "next smaller", "previous greater" and "how far until" questions as monotonic stack problems.
  - Implement next greater element with a stack of indexes in O(n).
  - Adapt the pattern to compute distances (days until a warmer day) and spans.
  - Solve largest rectangle in a histogram by finding each bar's nearest smaller bars on both sides.
  - Prove the O(n) bound by counting pushes and pops.
terms:
  - term: Monotonic stack
    definition: A stack whose elements stay in sorted order from bottom to top (always decreasing or always increasing). Before pushing, you pop every element that would break the order.
  - term: Next greater element
    definition: For each position, the first value to its right that's strictly bigger, or a sentinel such as -1 if there isn't one.
  - term: Unresolved element
    definition: An element whose answer hasn't been found yet. In a monotonic stack, the stack holds exactly these, and popping one resolves it.
  - term: Histogram
    definition: A row of bars of width 1 and given heights, standing next to each other. The classic hard example asks for the largest rectangle that fits under them.
  - term: Sentinel
    definition: An extra value added to the input, like a bar of height 0 at the end, so the main loop handles the leftovers without a separate cleanup step.
mastery:
  - Choose a decreasing or increasing stack for a given "next greater/smaller" question.
  - Write the push-and-pop loop, storing indexes so you can fill answers and compute distances.
  - Trace the stack's contents for a short input.
  - Compute the width of the rectangle each popped bar can make, using the new top of the stack.
  - "Explain why the inner while loop doesn't make the algorithm O(n²)."
resources: [swift-array, swift-book-control-flow, swift-book-collection-types]
cards:
  - id: m17-l05-c1
    front: What does the stack hold in the next-greater-element algorithm, and in what order?
    back: The indexes of elements that haven't found a greater element yet. Their values decrease from bottom to top (they never increase, since a larger one would have resolved the smaller ones).
  - id: m17-l05-c2
    front: Why is the monotonic stack algorithm O(n) despite a while loop inside a for loop?
    back: Each index is pushed exactly once and popped at most once. So the inner loop's pops add up to at most n over the whole run, and the total work is at most 2n stack operations.
  - id: m17-l05-c3
    front: Why store indexes on the stack instead of values?
    back: "An index lets you write the answer into the right slot of the result, compute distances (current index minus stored index), and still read the value with values[index]. A value alone gives you none of that, and duplicates make it ambiguous."
  - id: m17-l05-c4
    front: In largest rectangle in a histogram, when a bar is popped, what are its left and right limits?
    back: "The right limit is the current index (the first lower bar to the right). The left limit is the new top of the stack (the nearest lower bar to the left), or -1 if the stack is empty. Width = right - left - 1."
  - id: m17-l05-c5
    front: Next greater needs a decreasing stack. What does next smaller need?
    back: An increasing stack. Pop while the top's value is greater than the current value; each pop has found its next smaller element.
---

## The idea in one sentence

When each element is waiting for the first later element that beats it, keep the waiting elements on a stack in sorted order, and each new element resolves the ones it beats in one sweep, so the whole pass is O(n).

## The problem

A fitness app shows a week of step counts: `[4000, 3000, 9000, 5000, 6000, 2000, 7000]`. For each day, it wants to say **"the next day you beat this was ___ steps"**. That's the **next greater element**: for each position, the first value to its right that's strictly bigger, or -1 if none.

The brute force checks every later day for each day:

```swift
func nextGreaterBruteForce(_ values: [Int]) -> [Int] {
    var result = Array(repeating: -1, count: values.count)
    for i in values.indices {
        for j in (i + 1)..<values.count where values[j] > values[i] {
            result[i] = values[j]
            break
        }
    }
    return result
}

print(nextGreaterBruteForce([4000, 3000, 9000, 5000, 6000, 2000, 7000]))
```

```output
[9000, 9000, -1, 6000, 7000, 7000, -1]
```

In the worst case (a decreasing week, where no day is ever beaten), the inner loop runs to the end every time: **O(n²)**. For a year of daily data that's about 66,000 comparisons; for a dataset of a million readings it's about 500 billion.

## The observation

Walk left to right and keep a list of the days that **haven't been beaten yet**. Two facts about that list:

1. When a new value arrives, it beats some of the waiting days, and those are exactly the ones with smaller values. Their answer is the new value.
2. The waiting days always have **decreasing** values from oldest to newest. If an older waiting day were smaller than a newer one, the newer one would have beaten it when it arrived, and it wouldn't be waiting.

Fact 2 means the smallest waiting values are always the most recent. So the days the new value beats are all at the **end** of the list, and you can pop them off one by one until you reach one it doesn't beat. That's a stack, kept in sorted order: a **monotonic stack**.

## Next greater element in O(n)

```swift
func nextGreater(_ values: [Int]) -> [Int] {
    var result = Array(repeating: -1, count: values.count)
    var waiting: [Int] = []
    for (index, value) in values.enumerated() {
        while let last = waiting.last, values[last] < value {
            result[last] = value
            waiting.removeLast()
        }
        waiting.append(index)
    }
    return result
}

print(nextGreater([4000, 3000, 9000, 5000, 6000, 2000, 7000]))
print(nextGreater([5, 4, 3]))
print(nextGreater([1, 2, 2, 3]))
print(nextGreater([]))
```

```output
[9000, 9000, -1, 6000, 7000, 7000, -1]
[-1, -1, -1]
[2, 3, 3, -1]
[]
```

1. `result` starts at -1 everywhere. Any element still waiting at the end never found a bigger one, so -1 is already its answer.
2. `waiting` holds **indexes**, not values. An index tells you which slot of `result` to fill, and `values[index]` still gives you the value.
3. For each new value, `while let last = waiting.last, values[last] < value` pops every waiting element smaller than it, and records the new value as their answer.
4. Then the new index is pushed. It's waiting for its own answer.
5. `<` is strict, so an equal value doesn't count as greater: in `[1, 2, 2, 3]` the first 2 waits for the 3.

Trace the week, showing the waiting values instead of indexes:

| Value | Pops (and their answer) | Waiting after push |
| --- | --- | --- |
| 4000 | | 4000 |
| 3000 | | 4000 3000 |
| 9000 | 3000 → 9000, 4000 → 9000 | 9000 |
| 5000 | | 9000 5000 |
| 6000 | 5000 → 6000 | 9000 6000 |
| 2000 | | 9000 6000 2000 |
| 7000 | 2000 → 7000, 6000 → 7000 | 9000 7000 |

The waiting column always decreases from left to right. 9000 and the final 7000 are still waiting at the end, so their answer stays -1.

## Why it's O(n)

There's a `while` inside a `for`, which usually suggests O(n²). Count operations instead of loops: every index is **pushed exactly once** (at the end of its own iteration) and **popped at most once** (an index that's gone can't be popped again). So over the entire run there are at most n pushes and n pops, and each pass of the `while` does one pop. Total: at most 2n stack operations plus n comparisons that stop the `while`, which is **O(n) time**. The stack and the result are **O(n) space**.

This is the same amortized argument as the sliding window in Module 16 and the queues in lesson 2: one iteration can do a lot of work, but only by using up pops that can never happen again.

## Distances: days until a warmer day

Often the question isn't "what's the next bigger value" but **"how long until"**. A weather app shows, for each day, how many days you'd wait for a warmer one. Since the stack holds indexes, the distance is just the current index minus the popped one:

```swift
func daysUntilWarmer(_ temperatures: [Int]) -> [Int] {
    var waits = Array(repeating: 0, count: temperatures.count)
    var waiting: [Int] = []
    for (day, temperature) in temperatures.enumerated() {
        while let last = waiting.last, temperatures[last] < temperature {
            waits[last] = day - last
            waiting.removeLast()
        }
        waiting.append(day)
    }
    return waits
}

print(daysUntilWarmer([18, 17, 16, 19, 21, 20, 15, 22]))
print(daysUntilWarmer([25, 25, 25]))
```

```output
[3, 2, 1, 1, 3, 2, 1, 0]
[0, 0, 0]
```

Same loop, different thing written into the result. Days that never get a warmer one keep 0. Day 4 (21°) waits 3 days: 20 and 15 are colder, and 22 on day 7 is the first warmer day.

## Which direction?

The pattern has four variants. Two questions decide which one you need:

| You want for each element… | Stack order (bottom → top) | Pop while the top is… |
| --- | --- | --- |
| the next **greater** element to the right | decreasing | smaller than the current value |
| the next **smaller** element to the right | increasing | greater than the current value |
| the previous greater element to the left | decreasing | smaller than or equal to the current value; then the top (if any) is the answer |
| the previous smaller element to the left | increasing | greater than or equal to the current value; then the top is the answer |

For "next" questions, the answer is found **when an element is popped**: the current element is what popped it. For "previous" questions, the answer is found **when an element is pushed**: after popping, whatever is left on top is the nearest earlier element that survived. The hard example below uses both at once.

## The hard example: largest rectangle in a histogram

A dashboard draws a bar chart of hourly active users, with bars of width 1: `[2, 1, 5, 6, 2, 3]`. You want the largest rectangle that fits entirely under the bars, for example to place a label. This is a well-known hard interview problem, and the monotonic stack is its standard solution.

```text
          █
       █  █
       █  █
       █  █     █
 █     █  █  █  █
 █  █  █  █  █  █
 2  1  5  6  2  3   ← heights
 0  1  2  3  4  5   ← indexes
```

**The key observation**: the best rectangle has some bar as its **shortest** bar, and given that bar, the rectangle should stretch as far as possible left and right, until it hits a strictly lower bar on each side. So for every bar, you want its nearest lower bar on the left and on the right. The width is the gap between them.

- Bar 2 (height 5): the nearest lower bars are bar 1 (height 1) and bar 4 (height 2). The rectangle spans bars 2 and 3: width 2, area 10.
- Bar 1 (height 1): no lower bar on either side. It spans all 6 bars: area 6.

Computing both limits for each bar naively is O(n²). An **increasing** stack gives both in one pass. When the current bar is lower than the bar on top of the stack, that top bar has found its **right** limit (the current bar), and the element below it on the stack is its **left** limit (the nearest earlier bar that's lower). So you can compute its area right when you pop it.

```swift
func largestRectangle(_ heights: [Int]) -> Int {
    var stack: [Int] = []
    var best = 0
    for index in 0...heights.count {
        let height = index < heights.count ? heights[index] : 0
        while let top = stack.last, heights[top] >= height {
            stack.removeLast()
            let left = stack.last ?? -1
            let width = index - left - 1
            best = max(best, heights[top] * width)
        }
        stack.append(index)
    }
    return best
}

print(largestRectangle([2, 1, 5, 6, 2, 3]))
print(largestRectangle([2, 4]))
print(largestRectangle([3, 3, 3]))
print(largestRectangle([]))
```

```output
10
4
9
0
```

1. The loop runs one step past the end, with a **sentinel** height of 0. A bar of height 0 is lower than everything, so it pops every bar still on the stack and computes their areas. Without it, you'd need a second loop after the first to empty the stack.
2. The stack holds indexes of bars with increasing heights.
3. When the current bar is lower than or equal to the top, the top bar can't extend to the right past here. Pop it.
4. Its left limit is the new top of the stack, the nearest earlier bar that's lower than it, or -1 if none (it extends to the start). Every bar strictly between `left` and `index` is at least as tall as the popped bar; a lower one would still be on the stack between them. So the rectangle covers all of them: width is `index - left - 1`.
5. Popping on `>=` handles equal heights: the earlier of two equal bars is popped with a shorter width than it really has, but the later one, which stays, computes the full width when it's popped. The best area is still found.
6. `0...heights.count` is a valid closed range even for an empty array (`0...0`), so the empty case returns 0 without a special branch.

Trace `[2, 1, 5, 6, 2, 3]` (stack shown as heights):

| index (height) | Pops: height × width = area | Stack after push |
| --- | --- | --- |
| 0 (2) | | 2 |
| 1 (1) | 2 × 1 = 2 | 1 |
| 2 (5) | | 1 5 |
| 3 (6) | | 1 5 6 |
| 4 (2) | 6 × 1 = 6, 5 × 2 = **10** | 1 2 |
| 5 (3) | | 1 2 3 |
| 6 (0, sentinel) | 3 × 1 = 3, 2 × 4 = 8, 1 × 6 = 6 | 0 |

When height 5 is popped at index 4, the new top is index 1 (height 1), so the width is 4 − 1 − 1 = 2. When height 2 (index 4) is popped by the sentinel, the new top is index 1 again, so its width is 6 − 1 − 1 = 4: it stretches over the bars of height 5, 6, 2 and 3.

Same cost argument: each index is pushed once and popped once, so **O(n) time and O(n) space**.

## Common mistakes

> [!error] if instead of while
> One new element can resolve several waiting ones at once (9000 resolved both 3000 and 4000). With `if`, only the top is popped, and older waiting elements get the wrong answer.

> [!error] Pushing values instead of indexes
> With values on the stack, you can't tell which slot of the result to fill, and you can't compute distances or widths. Push indexes; read values with `values[index]`.

> [!error] Strict versus non-strict comparison
> "Greater" means `<` in the pop condition; "greater or equal" means `<=`. With duplicates, the wrong choice gives an equal value as the answer, or makes an element wait past its equal. Decide which one the problem wants and test with a run of equal values.

> [!error] Forgetting the elements left on the stack
> At the end, the stack holds elements that never found an answer. Either initialize the result with the "not found" value, or flush the stack with a sentinel, as the histogram does. Forgetting both leaves their areas (or answers) uncomputed.

> [!error] Calling it O(n²) because of the nested loop
> Count pushes and pops, not loops. Each index is pushed once and popped at most once, so the whole run is O(n).

## Exercises

````exercise
id: m17-l05-e1
type: comprehension
prompt: For each price in a list, you want the next price to its right that's strictly **lower** (a "next smaller element"). Which stack should you keep while scanning left to right?
choices:
  - text: Indexes whose values increase from bottom to top; pop while the top's value is greater than the current value.
    correct: true
    why: Every popped element has just met its first lower value to the right. Survivors stay in increasing order.
  - text: Indexes whose values decrease from bottom to top; pop while the top's value is smaller than the current value.
    correct: false
    why: That's next greater. Popped elements would get a bigger value as their answer.
  - text: A queue of indexes, dequeuing from the front while the front is greater.
    correct: false
    why: The candidates the new value resolves are the most recent ones, so they're at the back. That needs a stack.
  - text: No stack; sort the prices and binary search each one.
    correct: false
    why: Sorting loses positions, and "the next one to the right" depends on position.
solution: |
  **An increasing stack.** The waiting elements are the ones that haven't seen a lower price yet. If an older waiting price were bigger than a newer one, the newer one would have resolved it, so the waiting prices increase from bottom to top. A new price resolves every waiting price above it, and those are at the top, so you pop while `values[top] > current`, record `current` as their answer, and push the new index. O(n), for the same push-once, pop-once reason as next greater.
````

````exercise
id: m17-l05-e2
type: prediction
prompt: Predict the exact output. The loop prints the stack's values after each push.
code: |
  let values = [2, 7, 3, 5, 4, 6, 1]
  var stack: [Int] = []
  var answers = Array(repeating: -1, count: values.count)
  for (index, value) in values.enumerated() {
      while let top = stack.last, values[top] < value {
          answers[top] = value
          stack.removeLast()
      }
      stack.append(index)
      print(stack.map { values[$0] })
  }
  print(answers)
output: |
  [2]
  [7]
  [7, 3]
  [7, 5]
  [7, 5, 4]
  [7, 6]
  [7, 6, 1]
  [7, -1, 5, 6, 6, -1, -1]
hints:
  - The stack always decreases from bottom to top. Each new value pops everything smaller than it.
  - 6 pops both 4 and 5. Elements left on the stack at the end keep -1.
solution: |
  ```output
  [2]
  [7]
  [7, 3]
  [7, 5]
  [7, 5, 4]
  [7, 6]
  [7, 6, 1]
  [7, -1, 5, 6, 6, -1, -1]
  ```

  7 pops 2 (answer 7). 3 is smaller, so it's pushed. 5 pops 3 (answer 5). 4 is pushed. 6 pops 4 and then 5 (both answer 6), but not 7. 1 is pushed. At the end, 7, 6 and 1 are still waiting, so they keep -1. Each printed stack is decreasing, which is the invariant that makes "pop from the top" the right move.
````

````exercise
id: m17-l05-e3
type: fill-in
prompt: Complete this "days until a warmer day" function so it prints `[1, 1, 4, 2, 1, 1, 0, 0]`.
code: |
  func daysUntilWarmer(_ temperatures: [Int]) -> [Int] {
      var waits = Array(repeating: 0, count: temperatures.count)
      var waiting: [Int] = []
      for (day, temperature) in temperatures.enumerated() {
          [[1]] let last = waiting.last, temperatures[last] [[2]] temperature {
              waits[last] = [[3]]
              waiting.removeLast()
          }
          waiting.append([[4]])
      }
      return waits
  }

  print(daysUntilWarmer([13, 14, 25, 21, 19, 22, 26, 23]))
blanks:
  - id: "1"
    answers: ["while"]
  - id: "2"
    answers: ["<"]
  - id: "3"
    answers: ["day - last"]
  - id: "4"
    answers: ["day"]
solution: |
  ```swift
  func daysUntilWarmer(_ temperatures: [Int]) -> [Int] {
      var waits = Array(repeating: 0, count: temperatures.count)
      var waiting: [Int] = []
      for (day, temperature) in temperatures.enumerated() {
          while let last = waiting.last, temperatures[last] < temperature {
              waits[last] = day - last
              waiting.removeLast()
          }
          waiting.append(day)
      }
      return waits
  }

  print(daysUntilWarmer([13, 14, 25, 21, 19, 22, 26, 23]))
  ```

  ```output
  [1, 1, 4, 2, 1, 1, 0, 0]
  ```

  `while`, not `if`: day 6 (26°) resolves 22 and 25 at once. `<` because only a strictly warmer day counts. The wait is the distance between indexes, which is why the stack holds days, not temperatures. The last two days never see a warmer one and keep 0.
````

````exercise
id: m17-l05-e4
type: find-errors
prompt: This next-greater-element function is supposed to return, for each element, the first strictly greater value to its right, or -1. Which statements are true?
code: |
  func nextGreater(_ values: [Int]) -> [Int] {
      var result = Array(repeating: -1, count: values.count)
      var waiting: [Int] = []
      for (index, value) in values.enumerated() {
          if let last = waiting.last, values[last] <= value {
              result[last] = value
              waiting.removeLast()
          }
          waiting.append(index)
      }
      return result
  }
choices:
  - text: "For [3, 1, 5] it returns [-1, 5, -1]; the 3 should get 5."
    correct: true
    why: When 5 arrives, the if pops only the 1. The 3 below it is never compared again.
  - text: "For [2, 2] it returns [2, -1]; an equal value is treated as greater."
    correct: true
    why: "With <=, the second 2 resolves the first one."
  - text: The function is O(n²) because it may compare each element with all earlier ones.
    correct: false
    why: "With if, each iteration does at most one pop, so it's O(n). It's fast and wrong."
  - text: It crashes on an empty array.
    correct: false
    why: "Array(repeating: -1, count: 0) is empty, the loop doesn't run, and it returns []."
rubric:
  - I identified that if pops at most one element per step.
  - I identified that <= treats equal values as greater.
  - "I fixed both: while, and a strict <."
  - I explained that the fixed version is still O(n) by counting pushes and pops.
solution: |
  Two one-character-sized bugs with big effects:

  ```swift
  func nextGreater(_ values: [Int]) -> [Int] {
      var result = Array(repeating: -1, count: values.count)
      var waiting: [Int] = []
      for (index, value) in values.enumerated() {
          while let last = waiting.last, values[last] < value {
              result[last] = value
              waiting.removeLast()
          }
          waiting.append(index)
      }
      return result
  }

  print(nextGreater([3, 1, 5]))
  print(nextGreater([2, 2]))
  ```

  ```output
  [5, 5, -1]
  [-1, -1]
  ```

  `while` lets one value resolve every smaller element waiting on the stack. `<` makes "greater" strict. The fixed version is still O(n): every index is pushed once and popped at most once, so the `while` loop's total work over the whole run is at most n pops.
````

````exercise
id: m17-l05-e5
type: solve
prompt: |
  A stock app shows each day's **span**: the number of consecutive days, ending today and going backward, on which the price was less than or equal to today's price. Today always counts, so the span is at least 1. Write `func spans(_ prices: [Int]) -> [Int]` in O(n).

  Expected output for the starter's calls:

  ```output
  [1, 1, 1, 2, 1, 4, 6]
  [1, 2, 3]
  []
  ```
starter: |
  func spans(_ prices: [Int]) -> [Int] {
      var result: [Int] = []
      // A stack of indexes of earlier days
      return result
  }

  print(spans([100, 80, 60, 70, 60, 75, 85]))
  print(spans([5, 5, 5]))
  print(spans([]))
hints:
  - "The span ends at the previous day with a strictly greater price. That's a \"previous greater element\" question."
  - Pop while the top's price is less than or equal to today's. Whatever is left on top is the previous greater day, or there's none.
  - "The span is today's index minus that day's index, or today's index + 1 if the stack is empty."
rubric:
  - Uses a stack of indexes with decreasing prices.
  - Pops with <= so equal prices are included in the span.
  - Computes the span from the remaining top, or from the start when the stack is empty.
  - Output matches, and the answer states O(n) time with the push/pop argument.
solution: |
  ```swift
  func spans(_ prices: [Int]) -> [Int] {
      var result: [Int] = []
      var stack: [Int] = []
      for (day, price) in prices.enumerated() {
          while let top = stack.last, prices[top] <= price {
              stack.removeLast()
          }
          let previousGreater = stack.last ?? -1
          result.append(day - previousGreater)
          stack.append(day)
      }
      return result
  }

  print(spans([100, 80, 60, 70, 60, 75, 85]))
  print(spans([5, 5, 5]))
  print(spans([]))
  ```

  ```output
  [1, 1, 1, 2, 1, 4, 6]
  [1, 2, 3]
  []
  ```

  This is the "previous greater" variant: the answer for each day is found **when it's pushed**. Popping every day with a price `<=` today's leaves, on top, the nearest earlier day with a strictly greater price. The span covers everything after it, so it's `day - previousGreater`, and with an empty stack, `-1` stands for "before the first day". Popped days are safe to forget: today's price is at least theirs, so for any later day, today blocks or covers them. On day 6 (85), the stack holds 100 and 75; 75 is popped, 100 stays, and the span is 6 − 0 = 6. Each index is pushed once and popped at most once: **O(n) time, O(n) space**.
````

````exercise
id: m17-l05-e6
type: explain
prompt: |
  A reviewer looks at this function and says: "Nested loops, and the inner one can pop the whole stack. That's O(n²) in the worst case." Explain why it's O(n), and give an input where a single iteration of the `for` loop does a lot of work, showing that the total is still linear.
code: |
  func largestRectangle(_ heights: [Int]) -> Int {
      var stack: [Int] = []
      var best = 0
      for index in 0...heights.count {
          let height = index < heights.count ? heights[index] : 0
          while let top = stack.last, heights[top] >= height {
              stack.removeLast()
              let left = stack.last ?? -1
              best = max(best, heights[top] * (index - left - 1))
          }
          stack.append(index)
      }
      return best
  }
rubric:
  - States that each index is pushed exactly once.
  - States that each index is popped at most once, so the inner loop's iterations total at most n + 1 over the whole run.
  - Gives an example like an increasing input where the sentinel pops everything in one iteration, and shows the total is still about 2n.
  - Concludes O(n) time, O(n) space.
solution: |
  The bound comes from counting stack operations, not loops. Every index from 0 to n is **pushed exactly once**, at the end of its own iteration. Each pass of the inner `while` **pops** one index, and an index can only be popped once, since it's gone afterward. So across the entire run, the `while` body executes at most n + 1 times in total, not per iteration. Add the n + 1 checks that end each `while` and the n + 1 pushes: O(n) overall.

  For a concrete case, take an increasing input like `[1, 2, 3, 4, 5]`. No bar is ever popped during the first five iterations, because each one is taller than the top. Then the sentinel (height 0) pops all five in a single iteration. That one iteration is expensive, but the five earlier ones did no pops at all: the total is still five pushes, five pops and one sentinel push. Expensive iterations can only spend pops that cheaper iterations saved up. That's an amortized argument, the same as Array's `append` and the head-index queue. Space is O(n) for the stack.
````

## Summary

- A **monotonic stack** keeps the unresolved elements in sorted order. Before pushing a new element, pop everything it resolves.
- **Next greater**: keep a decreasing stack of indexes; pop while the top is smaller than the current value, and the current value is their answer. **Next smaller**: an increasing stack.
- **Previous greater/smaller**: the answer is whatever is on top after popping, at push time.
- Store **indexes**: they locate the result slot, give distances (`day - last`) and widths (`index - left - 1`).
- **Largest rectangle**: an increasing stack; when a bar is popped, the current index is its right limit and the new top its left limit. A sentinel 0 at the end flushes the stack.
- Every index is pushed once and popped at most once, so a `while` inside a `for` is still **O(n)**: amortized, like `append`.
