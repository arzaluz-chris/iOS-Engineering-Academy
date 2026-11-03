---
id: m15-l04
title: Analyzing loops and recursion
description: You derive the complexity of real code. Loops in sequence add and nested loops multiply, two inputs get two letters, a triangle of pairs is still O(n²), a doubling index gives O(log n), recursive functions cost their number of calls, naive Fibonacci explodes, and a method call inside a loop can hide a second loop.
module: m15
order: 4
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l03]
objectives:
  - Combine the costs of sequential and nested loops.
  - Express the cost of code with two inputs as O(n + m) or O(n · m) instead of forcing it into one letter.
  - Show that the "every pair once" loop does n(n − 1) / 2 steps and is O(n²).
  - Recognize loops whose index doubles or halves as O(log n).
  - Count the calls of a recursive function and derive its cost, including the exponential cost of naive Fibonacci.
  - Spot O(n) library calls such as contains, firstIndex(of:) and removeFirst() inside loops.
terms:
  - term: O(n + m) and O(n · m)
    definition: Costs for code with two independent inputs of sizes n and m. Separate loops over each add; a loop over one inside a loop over the other multiplies.
  - term: Triangle loop
    definition: A nested loop where the inner loop starts after the outer index, like for j in (i + 1)..<n. It runs n(n − 1) / 2 times, which is O(n²).
  - term: Recursion tree
    definition: A drawing of every call a recursive function makes, with each call's own calls below it. Counting its nodes counts the calls.
  - term: Exponential time
    definition: A step count that multiplies by a constant factor each time n grows by 1, like 2ⁿ. Usable only for very small n.
  - term: Hidden loop
    definition: A loop inside a method you call, like the linear search inside Array's contains. It counts toward your function's cost even though you don't see it.
mastery:
  - Give the Big O of a function with several loops, nested or not, and name the line that decides it.
  - Count the iterations of a triangle loop for a given n with the formula n(n − 1) / 2.
  - Draw the recursion tree of fib(4) and count its calls.
  - Rewrite a loop that calls contains on an array, and say what it cost before and after.
resources: [swift-array, swift-book-collection-types, swift-book-control-flow, swift-book-functions]
cards:
  - id: m15-l04-c1
    front: A loop over orders (n) with a loop over coupons (m) inside. Big O?
    back: O(n · m). Two independent inputs keep two letters. It's O(n²) only if both are the same size.
  - id: m15-l04-c2
    front: How many times does the body of for i in 0..<n { for j in (i + 1)..<n { … } } run?
    back: n(n − 1) / 2 times, once per pair. That's O(n²); the 1/2 is a constant factor.
  - id: m15-l04-c3
    front: What's the cost of var i = 1; while i < n { i *= 2 }?
    back: O(log n). i doubles each pass, so it reaches n after about log₂ n passes.
  - id: m15-l04-c4
    front: How many calls does naive recursive fib(30) make, and why?
    back: 2,692,537. Each call makes two more, and the same values are recomputed over and over. The count grows exponentially, about ×1.6 for each +1 to n.
  - id: m15-l04-c5
    front: Why is a loop that calls array.contains(x) on each pass O(n²)?
    back: contains is a linear search, documented as O(n). n passes, each doing up to n comparisons, is n × n.
---

## The idea in one sentence

The cost of a function is the sum of its parts, and each part costs **how many times it runs times what it does each time**, including the loops you can't see because they're inside a method you called.

## Loops in sequence add up

```swift
func averageAndMax(_ values: [Int]) -> (steps: Int, average: Int, maximum: Int) {
    var steps = 0
    var sum = 0
    for value in values {
        sum += value
        steps += 1
    }
    var maximum = values[0]
    for value in values {
        maximum = max(maximum, value)
        steps += 1
    }
    return (steps, sum / values.count, maximum)
}

print(averageAndMax([4, 8, 15, 16, 23, 42]))
```

```output
(steps: 12, average: 18, maximum: 42)
```

Two passes of n each: 2n steps, O(n). Sequential parts add, and then you keep the largest: O(n) + O(n) is O(n); O(n) + O(n²) is O(n²); O(log n) + O(n) is O(n).

## Nested loops multiply

When a loop sits inside another, the inner body runs once for every combination: outer passes **times** inner passes.

### Two inputs, two letters

An online store checks every order against every active coupon:

```swift
let orderTotals = [120, 45, 300]
let couponMinimums = [50, 100, 200, 500]
var checks = 0
var eligible = 0
for total in orderTotals {
    for minimum in couponMinimums {
        checks += 1
        if total >= minimum {
            eligible += 1
        }
    }
}
print("\(checks) checks, \(eligible) eligible order-coupon pairs")
```

```output
12 checks, 5 eligible order-coupon pairs
```

3 orders × 4 coupons = 12 checks. With n orders and m coupons, it's **O(n · m)**. Don't call it O(n²): the two sizes are independent. A store might have a million orders and five coupons, and then O(n · m) is effectively O(n), which "O(n²)" would badly misdescribe. Two loops over two different inputs **one after the other** would be O(n + m).

### The triangle: every pair once

To compare every element with every other one exactly once, the inner loop starts after the outer index:

```swift
let names = ["Ana", "Luis", "Marta", "Sofía"]
var pairs = 0
for i in names.indices {
    for j in (i + 1)..<names.count {
        print(names[i], names[j])
        pairs += 1
    }
}
print("\(pairs) pairs")
```

```output
Ana Luis
Ana Marta
Ana Sofía
Luis Marta
Luis Sofía
Marta Sofía
6 pairs
```

The inner loop runs 3 times, then 2, then 1, then 0: 3 + 2 + 1 + 0 = 6. In general, (n − 1) + (n − 2) + … + 1 + 0 = **n(n − 1) / 2**. For n = 100 that's 4,950; for n = 10,000 it's 49,995,000.

It's tempting to think the triangle is "half of n², so better than O(n²)". It's better by a constant factor of 2, and Big O drops constant factors: n(n − 1) / 2 = n²/2 − n/2, which is **O(n²)**. Doubling n still multiplies the work by about 4. The brute-force solutions to [Contains Duplicate](#/challenge/contains-duplicate) and [Two Sum](#/challenge/two-sum) are triangle loops.

### A loop whose index doubles

Not every loop runs n times. If the index doubles each pass, it reaches n after about log₂ n passes:

```swift
func doublingPasses(upTo n: Int) -> Int {
    var passes = 0
    var i = 1
    while i < n {
        i *= 2
        passes += 1
    }
    return passes
}

func nestedPasses(_ n: Int) -> Int {
    var passes = 0
    for _ in 0..<n {
        passes += doublingPasses(upTo: n)
    }
    return passes
}

print(doublingPasses(upTo: 1_000))
print(nestedPasses(8), nestedPasses(16), nestedPasses(1_024))
```

```output
10
24 64 10240
```

`i` takes the values 1, 2, 4, …, 512 and stops at 1,024, so 10 passes for n = 1,000: **O(log n)**, the same halving from lesson 3, run backwards. Put that loop inside a loop of n passes and you get n × log n: 8 × 3 = 24, 16 × 4 = 64, 1,024 × 10 = 10,240. That's **O(n log n)**.

### A loop with a fixed bound

```swift
let words = ["swift", "array", "set"]
var checks = 0
for word in words {
    for letter in "aeiou" {
        checks += 1
        if word.contains(letter) {
            print("\(word) has \(letter)")
        }
    }
}
print("\(checks) checks")
```

```output
swift has i
array has a
set has e
15 checks
```

The inner loop always runs 5 times, so the outer loop does 5n checks: O(n), not O(n²). A nested loop is only quadratic when **both** loops grow with the input. (Each `word.contains(letter)` is itself a scan of the word's characters; with short words that's a small constant too. If the words could be long, you'd write O(n · L), with L the length of the longest word.)

## Recursion: count the calls

For a recursive function, the cost is **the number of calls times the work done in each call** (not counting the recursive calls themselves). Pass a counter with `inout` (Module 6) to see the number of calls:

```swift
func factorial(_ n: Int, calls: inout Int) -> Int {
    calls += 1
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1, calls: &calls)
}

for n in [5, 10, 20] {
    var calls = 0
    let result = factorial(n, calls: &calls)
    print("factorial(\(n)) = \(result), \(calls) calls")
}
```

```output
factorial(5) = 120, 5 calls
factorial(10) = 3628800, 10 calls
factorial(20) = 2432902008176640000, 20 calls
```

One call per value from n down to 1, and each call does one multiplication and one comparison: **O(n)** time. The recursion tree is a straight line.

### Naive Fibonacci

The Fibonacci numbers start 0, 1, and each one after that is the sum of the two before: 0, 1, 1, 2, 3, 5, 8, 13… The definition translates straight into code:

```swift
func fib(_ n: Int, calls: inout Int) -> Int {
    calls += 1
    if n <= 1 {
        return n
    }
    return fib(n - 1, calls: &calls) + fib(n - 2, calls: &calls)
}

for n in [5, 10, 20, 25, 30] {
    var calls = 0
    let value = fib(n, calls: &calls)
    print("fib(\(n)) = \(value), \(calls) calls")
}
```

```output
fib(5) = 5, 15 calls
fib(10) = 55, 177 calls
fib(20) = 6765, 21891 calls
fib(25) = 75025, 242785 calls
fib(30) = 832040, 2692537 calls
```

Short code, and nearly 2.7 million calls to compute fib(30). Here's why. The recursion tree of `fib(4)`:

```text
                 fib(4)
              /          \
         fib(3)            fib(2)
        /      \           /     \
    fib(2)    fib(1)   fib(1)   fib(0)
    /    \
fib(1)  fib(0)
```

Nine calls, and `fib(2)` is computed twice. In `fib(30)`, `fib(2)` is computed more than 500,000 times. Every call that isn't a base case makes **two** more, so the tree roughly doubles in size with each level, and it's about n levels deep.

The counts show the growth: each time n goes up by 5, the calls go up about ×11. That's about ×1.6 per step, which is exponential. The standard upper bound is **O(2ⁿ)**: at most two calls per call, at most n levels. The tight bound is closer to 1.618ⁿ (the golden ratio, if you're curious), but in an interview "exponential, O(2ⁿ) as an upper bound" is the expected answer.

Compare a loop that keeps the last two values:

```swift
func fibLoop(_ n: Int) -> (value: Int, steps: Int) {
    if n <= 1 {
        return (n, 0)
    }
    var previous = 0
    var current = 1
    var steps = 0
    for _ in 2...n {
        (previous, current) = (current, previous + current)
        steps += 1
    }
    return (current, steps)
}

for n in [10, 30, 90] {
    let result = fibLoop(n)
    print("fib(\(n)) = \(result.value), \(result.steps) steps")
}
```

```output
fib(10) = 55, 9 steps
fib(30) = 832040, 29 steps
fib(90) = 2880067194370816120, 89 steps
```

n − 1 steps: **O(n)**. fib(90) in 89 steps, a number the recursive version would need nearly 10¹⁹ calls to reach. The line `(previous, current) = (current, previous + current)` is the tuple swap from Module 6. Lesson 6 shows a third version that keeps the recursive shape and remembers results instead; Module 20 calls that memoization.

> [!warning] Two recursive calls don't always mean exponential
> What matters is how much each call shrinks the problem. A function that calls itself twice on **n − 1** doubles the work at each of n levels: exponential. A function that calls itself twice on **n / 2** has only log₂ n levels, and the calls add up to about 2n: O(n). Count the calls instead of guessing from the shape of the code (exercise 6 does this).

## Hidden loops inside method calls

A loop is O(n) only if its body is O(1). Many array methods are loops themselves, and Apple's documentation says so: `contains(_:)` and `firstIndex(of:)` are listed as "O(n), where n is the length of the sequence" (or "collection"), and so are `min()` and `removeFirst()`. Call one inside a loop and you've written a nested loop.

Here's a common one: removing duplicates while keeping order, by checking `result.contains` before appending. To see the hidden work, count the comparisons `contains(where:)` makes with a closure that bumps a counter (closures can change variables they capture, as you saw in Module 11):

```swift
func removingDuplicates(_ values: [Int]) -> (result: [Int], comparisons: Int) {
    var result: [Int] = []
    var comparisons = 0
    for value in values {
        let alreadyThere = result.contains { existing in
            comparisons += 1
            return existing == value
        }
        if !alreadyThere {
            result.append(value)
        }
    }
    return (result, comparisons)
}

print(removingDuplicates([3, 1, 3, 2, 1]))
for size in [1_000, 2_000] {
    let unique = Array(0..<size)
    print("\(size) unique values: \(removingDuplicates(unique).comparisons) comparisons")
}
```

```output
(result: [3, 1, 2], comparisons: 6)
1000 unique values: 499500 comparisons
2000 unique values: 1999000 comparisons
```

One visible loop, and yet 499,500 comparisons for 1,000 values: the triangle number n(n − 1) / 2. Doubling n multiplies it by 4. This function is **O(n²)**, even though it reads like a single pass. Lesson 5 makes it O(n) with a `Set`.

The usual suspects, all O(n) per call according to their documentation:

| Inside a loop over n elements | Hidden cost per call | Total |
| --- | --- | --- |
| `array.contains(x)` | O(n) | O(n²) |
| `array.firstIndex(of: x)` | O(n) | O(n²) |
| `array.min()`, `array.max()` | O(n) | O(n²) |
| `array.removeFirst()`, `array.remove(at: 0)` | O(n): the remaining elements shift | O(n²) |
| `array.insert(x, at: 0)` | O(n): every element shifts | O(n²) |
| `string.count` | O(n), where n is the length of the string | O(n²) |

`String.count` surprises people: a `String` has to walk its characters to count them, because characters take different amounts of storage: `"a"` and an emoji are one `Character` each (Module 4), but the emoji takes several bytes. Its documentation lists it as "O(n), where n is the length of the string". Reading it once before a loop is fine; calling it in a `while` condition on every pass adds a hidden loop.

## A practical example: a queue processed from the front

An app keeps pending uploads in an array and processes them in order:

```swift
var pending = ["a.jpg", "b.jpg", "c.jpg", "d.jpg"]
while !pending.isEmpty {
    let next = pending.removeFirst()
    print("uploading \(next)")
}
```

```output
uploading a.jpg
uploading b.jpg
uploading c.jpg
uploading d.jpg
```

It reads like O(n), but `removeFirst()` is O(n), because every remaining element moves one place to the left. Processing n uploads this way does (n − 1) + (n − 2) + … + 0 element moves: the triangle again, O(n²). For four uploads, irrelevant. For a queue of 100,000 jobs, it's about 5 billion moves.

The fix doesn't need a new data structure. Walk the array with an index instead of removing from the front, or reverse the array once and take elements from the end with `popLast()` or `removeLast()`, which Apple's documentation lists as O(1):

```swift
var pending = ["a.jpg", "b.jpg", "c.jpg", "d.jpg"]
pending.reverse()
while let next = pending.popLast() {
    print("uploading \(next)")
}
```

```output
uploading a.jpg
uploading b.jpg
uploading c.jpg
uploading d.jpg
```

`reverse()` is O(n), once. `popLast()` is O(1), and it returns `nil` when the array is empty, so `while let` (Module 8) ends the loop. Total: O(n). Module 17 builds a proper queue.

## Common mistakes

> [!error] Calling O(n · m) "O(n²)"
> When two inputs can have very different sizes, one letter hides the real cost. Name both: "n orders and m coupons, O(n · m)".

> [!error] "The triangle loop is O(n²/2), so it's better than O(n²)"
> It does half the work of the full square, which is worth saying, but it's the same class. Doubling n still multiplies its work by 4.

> [!error] Treating every nested loop as O(n²)
> An inner loop over 5 vowels or 7 weekdays is constant. Ask, for each loop, "does this one grow with the input?"

> [!error] Ignoring the cost of a call inside a loop
> `contains`, `firstIndex(of:)`, `min()`, `removeFirst()`, `insert(_:at: 0)` and `String.count` are loops. Check the "Complexity" line in a method's documentation when you're not sure.

> [!error] Judging recursion by its line count
> Naive Fibonacci is four lines and exponential. Count the calls, or draw the tree for a small n, before you state a cost.

## Exercises

````exercise
id: m15-l04-e1
type: comprehension
prompt: |
  A function loops over `users` (n elements). Inside, it loops over `bannedWords` (m elements) and checks whether each user's name equals the word. After both loops it sorts `users`. What's the time complexity?
choices:
  - text: O(n · m + n log n)
    correct: true
    why: The nested loops do n · m checks, and sorting n users is O(n log n). Neither term dominates the other in general, so both stay.
  - text: O(n²)
    correct: false
    why: The inner loop runs m times, not n. The two sizes are independent.
  - text: O(n · m)
    correct: false
    why: That leaves out the sort. If m is small, say 3, the O(n log n) sort is the bigger cost.
  - text: O(n + m)
    correct: false
    why: The loops are nested, so they multiply.
solution: |
  **O(n · m + n log n).** Sequential parts add; nested loops multiply. You keep both terms because which one is larger depends on m: with 3 banned words, the sort dominates; with 10,000, the nested loop does. When one term clearly dominates for the inputs you expect, you can say so ("with a handful of banned words, this is O(n log n)"), but the full answer keeps both.
````

````exercise
id: m15-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  func fib(_ n: Int, calls: inout Int) -> Int {
      calls += 1
      if n <= 1 {
          return n
      }
      return fib(n - 1, calls: &calls) + fib(n - 2, calls: &calls)
  }

  for n in [1, 3, 4, 6] {
      var calls = 0
      let value = fib(n, calls: &calls)
      print(n, value, calls)
  }
output: |
  1 1 1
  3 2 5
  4 3 9
  6 8 25
hints:
  - "calls(n) = 1 + calls(n − 1) + calls(n − 2), and calls(0) = calls(1) = 1."
  - fib(4) is the tree drawn in the lesson.
solution: |
  ```output
  1 1 1
  3 2 5
  4 3 9
  6 8 25
  ```

  A base case costs 1 call. Every other call costs itself plus its two subtrees:
  - calls(2) = 1 + 1 + 1 = 3
  - calls(3) = 1 + 3 + 1 = 5
  - calls(4) = 1 + 5 + 3 = 9
  - calls(5) = 1 + 9 + 5 = 15
  - calls(6) = 1 + 15 + 9 = 25

  The call count follows almost the same rule as Fibonacci itself, which is why it grows exponentially, just like the numbers do.
````

````exercise
id: m15-l04-e3
type: fill-in
prompt: Fill in the number of times the `steps += 1` line runs in each case, for n = 10.
code: |
  // A: [[1]]
  for i in 0..<n {
      for j in 0..<n {
          steps += 1
      }
  }

  // B: [[2]]
  for i in 0..<n {
      for j in (i + 1)..<n {
          steps += 1
      }
  }

  // C: [[3]]
  for i in 0..<n {
      steps += 1
  }
  for j in 0..<n {
      steps += 1
  }

  // D: [[4]]
  var k = 1
  while k < n {
      k *= 2
      steps += 1
  }
blanks:
  - id: "1"
    answers: ["100"]
  - id: "2"
    answers: ["45"]
  - id: "3"
    answers: ["20"]
  - id: "4"
    answers: ["4"]
solution: |
  - **A: 100.** n × n. O(n²).
  - **B: 45.** 9 + 8 + … + 1 + 0 = n(n − 1) / 2. Still O(n²).
  - **C: 20.** n + n, two loops one after the other. O(n).
  - **D: 4.** k goes 1, 2, 4, 8, 16 and stops when it reaches 16, so the loop makes 4 passes. O(log n).

  ```swift
  let n = 10
  var a = 0
  for _ in 0..<n {
      for _ in 0..<n {
          a += 1
      }
  }
  var b = 0
  for i in 0..<n {
      for _ in (i + 1)..<n {
          b += 1
      }
  }
  var c = 0
  for _ in 0..<n {
      c += 1
  }
  for _ in 0..<n {
      c += 1
  }
  var d = 0
  var k = 1
  while k < n {
      k *= 2
      d += 1
  }
  print(a, b, c, d)
  ```

  ```output
  100 45 20 4
  ```

  The exercise code uses `i` and `j` to make the shapes easy to read; in a real program Swift would warn that the unused ones should be `_`, as in the version above.
````

````exercise
id: m15-l04-e4
type: find-errors
prompt: |
  A teammate says this function is O(n) "because there's only one loop". `names` has n elements. Which statements are true?
code: |
  func firstRepeatedName(_ names: [String]) -> String? {
      for (index, name) in names.enumerated() {
          let firstPosition = names.firstIndex(of: name) ?? index
          if firstPosition < index {
              return name
          }
      }
      return nil
  }
choices:
  - text: "firstIndex(of:) is a linear search, so the function is O(n²) in the worst case."
    correct: true
    why: "Each call can scan up to n elements, and it runs once per element."
  - text: "The worst case is a list with no repeated names."
    correct: true
    why: "Then the loop never returns early and every firstIndex call runs."
  - text: "It's O(n) because firstIndex stops as soon as it finds the name."
    correct: false
    why: "For the element at position i with no earlier copy, firstIndex scans i + 1 elements. Summed over all positions that's a triangle, O(n²)."
  - text: "It's O(n log n) because firstIndex uses binary search."
    correct: false
    why: "Array's firstIndex(of:) is documented as O(n). It can't use binary search: the array isn't sorted."
rubric:
  - I identified firstIndex(of:) as a hidden loop.
  - I described the worst-case input.
  - I computed or estimated the total as a triangle sum, O(n²).
solution: |
  The function has one visible loop and one hidden one. For the name at position i, `firstIndex(of:)` scans from the start until it finds that name, which, if there's no earlier copy, is at position i itself: i + 1 comparisons. With no repeats at all, the total is 1 + 2 + … + n = n(n + 1) / 2: **O(n²)**.

  ```swift
  func firstRepeatedName(_ names: [String]) -> String? {
      for (index, name) in names.enumerated() {
          let firstPosition = names.firstIndex(of: name) ?? index
          if firstPosition < index {
              return name
          }
      }
      return nil
  }

  print(firstRepeatedName(["Ana", "Luis", "Ana", "Marta"]) ?? "none")
  print(firstRepeatedName(["Ana", "Luis", "Marta"]) ?? "none")
  ```

  ```output
  Ana
  none
  ```

  The early return helps when there's a repeat near the start; the worst case is no repeats at all. A `Set` of names seen so far would make each check O(1) on average (lesson 5).
````

````exercise
id: m15-l04-e5
type: solve
prompt: |
  Write `func commonCount(_ a: [Int], _ b: [Int]) -> (count: Int, comparisons: Int)` that counts how many values of `a` also appear in `b`, using a nested loop that stops scanning `b` as soon as it finds a match. Count every comparison.

  Print the results for these inputs, then state the worst-case complexity in terms of n = `a.count` and m = `b.count`, and describe the input that produces it.

  ```output
  2 7
  0 12
  3 3
  ```

  Inputs: `([1, 2, 3], [3, 4, 1])`, `([5, 6, 7], [1, 2, 3, 4])`, `([9, 9, 9], [9])`.
starter: |
  func commonCount(_ a: [Int], _ b: [Int]) -> (count: Int, comparisons: Int) {
      var count = 0
      var comparisons = 0
      // Your loops
      return (count, comparisons)
  }
hints:
  - "A labeled loop or a break inside the inner loop stops scanning b after a match."
  - "Count before the if, so the comparison that finds the match is counted."
rubric:
  - The inner loop stops after the first match.
  - The output matches line by line.
  - I stated O(n · m) and that the worst case is when no value of a is in b.
solution: |
  ```swift
  func commonCount(_ a: [Int], _ b: [Int]) -> (count: Int, comparisons: Int) {
      var count = 0
      var comparisons = 0
      for x in a {
          for y in b {
              comparisons += 1
              if x == y {
                  count += 1
                  break
              }
          }
      }
      return (count, comparisons)
  }

  let inputs = [([1, 2, 3], [3, 4, 1]), ([5, 6, 7], [1, 2, 3, 4]), ([9, 9, 9], [9])]
  for (a, b) in inputs {
      let result = commonCount(a, b)
      print(result.count, result.comparisons)
  }
  ```

  ```output
  2 7
  0 12
  3 3
  ```

  - First input: 1 is found at b's third position (3 comparisons), 2 isn't found (3), 3 is found first (1). Total 7, and two matches.
  - Second input: nothing matches, so every pair is compared: 3 × 4 = 12. This is the **worst case**.
  - Third input: each 9 matches immediately: 3 comparisons. Duplicates in `a` count each time.

  Worst case **O(n · m)**, when no value of `a` appears in `b`. Putting `b` in a `Set` first would make it O(n + m) on average: you'll do that in lesson 5.
````

````exercise
id: m15-l04-e6
type: explain
prompt: |
  This function calls itself twice, like naive Fibonacci. Without running it, a teammate guesses "exponential". Count the calls for n = 8 and n = 16 (by drawing the tree or reasoning about levels), and explain why the guess is wrong.
code: |
  func split(_ n: Int, calls: inout Int) {
      calls += 1
      if n <= 1 {
          return
      }
      split(n / 2, calls: &calls)
      split(n / 2, calls: &calls)
  }
rubric:
  - I counted 15 calls for n = 8 and 31 for n = 16.
  - I explained that the problem halves, so the tree has about log₂ n levels.
  - I concluded the total is about 2n calls, O(n).
  - I contrasted it with Fibonacci, where the problem shrinks by only 1 or 2.
solution: |
  Level by level for n = 8: one call with 8, two with 4, four with 2, eight with 1. That's 1 + 2 + 4 + 8 = **15** calls. For 16, add a level of sixteen calls: **31**.

  ```swift
  func split(_ n: Int, calls: inout Int) {
      calls += 1
      if n <= 1 {
          return
      }
      split(n / 2, calls: &calls)
      split(n / 2, calls: &calls)
  }

  for n in [8, 16, 1_024] {
      var calls = 0
      split(n, calls: &calls)
      print(n, calls)
  }
  ```

  ```output
  8 15
  16 31
  1024 2047
  ```

  The number of calls doubles at each level, which looks exponential, but the problem **halves** at each level, so there are only about log₂ n levels. Doubling log₂ n times gives about n calls at the bottom level, and 2n − 1 in total: **O(n)**. Naive Fibonacci also makes two calls per call, but each one shrinks n by only 1 or 2, so the tree is about n levels deep, and doubling n times gives exponential growth. The shape of the code is the same; what decides the cost is how fast the problem shrinks.
````

## Summary

- Sequential parts add and the largest wins. Nested loops multiply.
- Two independent inputs get two letters: O(n + m) for loops in sequence, O(n · m) for nested ones.
- The triangle loop (`j` from `i + 1`) runs n(n − 1) / 2 times: still O(n²).
- A loop whose index doubles or halves is O(log n). Inside a loop of n passes, it's O(n log n). A loop with a fixed bound is O(1).
- For recursion, count the calls (with an `inout` counter or a tree). Factorial is O(n). Naive Fibonacci is exponential: 2,692,537 calls for fib(30). How fast the problem shrinks decides the cost, not how many calls each call makes.
- `contains`, `firstIndex(of:)`, `min()`, `removeFirst()`, `insert(_:at: 0)` and `String.count` are O(n). Inside a loop, they make it O(n²).
