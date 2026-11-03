---
id: m07-l05
title: "Transforming collections: map, filter, reduce"
description: You transform arrays with map, filter, reduce, compactMap and flatMap, sort them with sorted and sorted(by:), pair two arrays with zip, chain these steps together, and learn when a plain loop is still the clearer choice.
module: m07
order: 5
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l04]
objectives:
  - Transform every element with map and keep some elements with filter.
  - Combine all elements into one value with reduce.
  - Convert and drop failures in one step with compactMap, and flatten nested arrays with flatMap.
  - Sort with sorted() and sorted(by:), and pair two arrays with zip.
  - Chain transformations, and decide when a for loop is clearer.
terms:
  - term: map
    definition: Returns a new array with the result of applying a closure to every element. Same number of elements, possibly a different type.
  - term: filter
    definition: Returns a new array with only the elements for which a closure returns true, in their original order.
  - term: reduce
    definition: Combines all elements into a single value, starting from an initial value and applying a closure that takes the result so far and the next element.
  - term: compactMap
    definition: Like map, but the closure may produce no result (nil), and those are left out. Typical use is converting strings with Int(…).
  - term: flatMap
    definition: Applies a closure that returns an array to each element and joins all those arrays into one. On an array of arrays, it flattens one level.
  - term: zip
    definition: Pairs up the elements of two sequences by position, stopping at the end of the shorter one.
mastery:
  - Rewrite a loop that builds a new array as a call to map or filter, and back.
  - Write a sum, a product and a maximum with reduce, choosing the right initial value.
  - Parse an array of strings into numbers with compactMap and say what happened to the invalid ones.
  - Sort an array in descending order and by a custom rule with a tie-breaker.
  - Chain filter, map and reduce, and explain when you'd use a loop instead.
resources: [swift-book-closures, swift-book-collection-types]
cards:
  - id: m07-l05-c1
    front: What's the difference between map and filter?
    back: map transforms every element and returns the same number of elements. filter keeps or drops each element unchanged, based on a Bool.
  - id: m07-l05-c2
    front: "What does [1, 2, 3].reduce(0) { total, n in total + n } return?"
    back: "6. reduce starts with 0 and calls the closure with (0, 1), then (1, 2), then (3, 3). Each result becomes the next total."
  - id: m07-l05-c3
    front: "What does [\"4\", \"x\", \"10\"].compactMap { text in Int(text) } return?"
    back: "[4, 10]. Int(\"x\") produces no number, and compactMap leaves it out."
  - id: m07-l05-c4
    front: How do you sort numbers from largest to smallest?
    back: "numbers.sorted(by: >) or numbers.sorted { a, b in a > b }. The closure answers: should a come before b?"
  - id: m07-l05-c5
    front: When is a for loop clearer than a chain of map, filter and reduce?
    back: When you need several results from one pass, want to stop early, or the logic in the closure grows beyond a line or two.
---

## The idea in one sentence

Most loops over an array do one of a few jobs, like transforming each element, keeping some or adding them up, and each job has a method that does the looping for you while you write only the part that differs.

## From loop to map

Here's a loop you could write right now. It builds a new array of prices with tax:

```swift
let prices = [100, 250, 80]
var withTax: [Int] = []
for price in prices {
    withTax.append(price * 116 / 100)
}
print(withTax)
```

```output
[116, 290, 92]
```

Three of those lines are bookkeeping: create an empty array, loop, append. Only `price * 116 / 100` is about this problem. `map` keeps that part and does the bookkeeping:

```swift
let prices = [100, 250, 80]
let withTax = prices.map { price in price * 116 / 100 }
print(withTax)
```

```output
[116, 290, 92]
```

**Plain definition:** `map` applies a closure to every element and gives you back the results, in order.

**Precise definition:** `map` takes a closure from the element type to some result type and returns an array of the results, with the same count as the original. It's a higher-order function, like the ones you wrote in Module 6: it knows *how* to loop; you tell it *what* to do with each element.

Notice `withTax` is now a `let`. The loop version needed a `var` only so it could be built up step by step.

The result type doesn't have to match the element type:

```swift
let scores = [92, 58, 75]
let labels = scores.map { score in score >= 60 ? "pass" : "fail" }
let lengths = ["Ana", "Sofía", "Luis"].map { name in name.count }
print(labels)
print(lengths)
```

```output
["pass", "fail", "pass"]
[3, 5, 4]
```

`[Int]` in, `[String]` out; `[String]` in, `[Int]` out. The closure's return type decides.

## filter: keep some

`filter` keeps the elements for which the closure returns `true`, unchanged and in their original order:

```swift
let temperatures = [18, 31, 24, 33, 29]
let hot = temperatures.filter { t in t > 30 }
let names = ["Ana", "Bernardo", "Luis", "Maximiliano"]
let shortNames = names.filter { name in name.count <= 4 }
print(hot)
print(shortNames)
print(temperatures.filter { t in t > 40 })
```

```output
[31, 33]
["Ana", "Luis"]
[]
```

The closure is a **predicate**, like the ones `contains(where:)` and `allSatisfy` took in lesson 2. When nothing passes, you get an empty array, not a crash and not an optional.

`map` changes every element and keeps the count. `filter` keeps elements as they are and may change the count. That's the whole difference.

## reduce: combine everything into one value

`reduce` is the **accumulator** from Modules 2 and 5, packaged as a method. You give it the starting value and a closure that takes the result so far and the next element and returns the new result:

```swift
let prices = [45, 28, 35]
let total = prices.reduce(0) { sum, price in sum + price }
print(total)
```

```output
108
```

The trace, one row per call of the closure:

| sum (so far) | price | returns |
| --- | --- | --- |
| 0 (initial) | 45 | 45 |
| 45 | 28 | 73 |
| 73 | 35 | 108 |

Compared with the loop: `0` is the `var total = 0` before the loop, and the closure is the `total = total + price` inside it.

The initial value matters for the same reasons it did in Module 5:

```swift
let factors = [2, 3, 4]
print(factors.reduce(1) { product, n in product * n })
print(factors.reduce(0) { product, n in product * n })
let empty: [Int] = []
print(empty.reduce(0) { sum, n in sum + n })
```

```output
24
0
0
```

A product has to start at 1; starting at 0 makes everything 0. On an empty array, `reduce` never calls the closure and returns the initial value, which is the right answer for a sum.

### Passing + directly

In Swift, operators like `+` are functions too. `+` on two `Int`s has the type `(Int, Int) -> Int`, exactly what `reduce` wants, so you can pass it by name, the way you passed `double` in Module 6:

```swift
let numbers = [4, 8, 15, 16, 23, 42]
print(numbers.reduce(0, +))
print(numbers.reduce(1, *))
print(numbers.sorted(by: >))
```

```output
108
7418880
[42, 23, 16, 15, 8, 4]
```

`>` works the same way as the rule for `sorted(by:)`, coming up next.

## Sorting

`sorted()` returns a new array in ascending order: numbers from smallest to largest, strings alphabetically. The original isn't touched.

```swift
let scores = [75, 92, 58, 81]
let ascending = scores.sorted()
let descending = scores.sorted(by: >)
let byLength = ["Sofía", "Ana", "Luis"].sorted { a, b in a.count < b.count }
print(scores)
print(ascending)
print(descending)
print(byLength)
```

```output
[75, 92, 58, 81]
[58, 75, 81, 92]
[92, 81, 75, 58]
["Ana", "Luis", "Sofía"]
```

`sorted(by:)` takes a closure with **two** elements that answers one question: **should `a` come before `b`?** `>` says "the bigger one first". `a.count < b.count` says "the shorter one first".

> [!warning] Uppercase sorts before lowercase
> String comparison follows character codes, where every uppercase letter comes before every lowercase one, so `["banana", "Cherry", "apple"].sorted()` gives `["Cherry", "apple", "banana"]`. If case shouldn't matter, compare lowercased versions: `sorted { a, b in a.lowercased() < b.lowercased() }`.

### Tie-breakers

When two elements are equal by your rule, you should decide which comes first instead of leaving it to chance. Compare a second thing when the first is equal:

```swift
let players = [("Luis", 30), ("Ana", 45), ("Marta", 30), ("Diego", 45)]
let ranking = players.sorted { a, b in
    if a.1 != b.1 {
        return a.1 > b.1
    }
    return a.0 < b.0
}
for (name, points) in ranking {
    print(name, points)
}
```

```output
Ana 45
Diego 45
Luis 30
Marta 30
```

Each player is a tuple, `(String, Int)`; `.0` is the name and `.1` the points (Module 6). Higher points first; equal points, alphabetical. This matters when sorting things that came out of a dictionary or set, whose order isn't stable: without the tie-breaker, players with equal points could swap places between runs.

`sort()`, without the "-ed", sorts a `var` array **in place** instead of returning a new one: `scores.sort()` changes `scores`. On a `let` array it doesn't compile, like `append`.

## compactMap: convert and drop failures

`Int("42")` gives a number; `Int("hello")` gives nothing. You've been handling that with `?? default`. When you're converting a whole array, you usually want the failures **gone**, not replaced by a made-up number. That's `compactMap`:

```swift
let inputs = ["12", "seven", "30", "", "4"]
let numbers = inputs.compactMap { text in Int(text) }
print(numbers)
print("Ignored \(inputs.count - numbers.count) invalid entries")
let withDefaults = inputs.map { text in Int(text) ?? 0 }
print(withDefaults)
```

```output
[12, 30, 4]
Ignored 2 invalid entries
[12, 0, 30, 0, 4]
```

`compactMap` calls the closure on each element. When the closure produces a value, it's kept; when it produces nothing (`nil`, an empty optional, Module 8), the element is skipped. Compare with the `map` version: those zeros look exactly like real zeros, so an average computed from them would be wrong.

## flatMap: flattening nested arrays

An array can hold arrays: `[[Int]]` is an array whose elements are `[Int]`. Lesson 6 covers them in depth. When you want all the inner elements in one flat array, use `flatMap`:

```swift
let weeklySales = [[3, 5], [2], [], [7, 1, 4]]
let allSales = weeklySales.flatMap { week in week }
print(allSales)
print(allSales.count)
let words = ["hi", "yo"]
print(words.flatMap { word in [word, word.uppercased()] })
```

```output
[3, 5, 2, 7, 1, 4]
6
["hi", "HI", "yo", "YO"]
```

The closure returns an array for each element, and `flatMap` joins them all, in order. `{ week in week }` returns each inner array as it is, so the result is just the inner elements laid end to end. The empty week adds nothing.

`map` with the same closure would give you back an array of arrays: `map` keeps one result per element, `flatMap` merges them.

## zip: walking two arrays together

When two arrays line up by position, like names and their scores, `zip` pairs them:

```swift
let names = ["Ana", "Luis", "Marta"]
let scores = [91, 78, 85, 60]
for (name, score) in zip(names, scores) {
    print("\(name): \(score)")
}
```

```output
Ana: 91
Luis: 78
Marta: 85
```

`zip` is a function, not a method: you pass both arrays. It produces pairs `(first, second)` until **either** array runs out. Here `scores` has an extra 60 with no name, and `zip` silently drops it. That's safer than indexing both arrays with the same `i`, which would crash, but it can hide a bug: if the arrays should be the same length, check `names.count == scores.count` first.

## Chaining

Each of these methods returns an array, so you can call the next one on the result. Read a chain from top to bottom, one step per line:

```swift
let rawScores = ["88", "x", "95", "42", "70", "101"]
let passingTotal = rawScores
    .compactMap { text in Int(text) }
    .filter { score in score >= 0 && score <= 100 }
    .filter { score in score >= 60 }
    .reduce(0, +)
print(passingTotal)
```

```output
253
```

1. `compactMap` parses the strings and drops `"x"`: `[88, 95, 42, 70, 101]`.
2. The first `filter` drops the out-of-range 101: `[88, 95, 42, 70]`.
3. The second `filter` keeps passing scores: `[88, 95, 70]`.
4. `reduce` adds them: 253.

Each step has one job, and you can check each intermediate result by stopping the chain there and printing it.

## When a loop is clearer

These methods aren't always the better choice. Prefer a plain `for` loop when:

- **You need several results from one pass.** Counting the passing scores, summing them and finding the maximum is one loop with three accumulators, or three separate chains that each walk the whole array.
- **You want to stop early.** `map` and `filter` always visit every element. A loop can `break` or `return` when it has its answer. (For "find the first", `first(where:)` and `contains(where:)` already stop early.)
- **The closure grows.** If the closure needs several lines, `if`s and temporary constants, the chain hides the logic instead of showing it. Pull it into a named function (`.filter(isValidScore)`) or write the loop.
- **You're doing it for the side effect.** If the point is to `print`, use `for`. `map` is for building a new array.

```swift
let scores = [88, 95, 42, 70]
var passed = 0
var best = 0
var sum = 0
for score in scores {
    sum += score
    if score >= 60 {
        passed += 1
    }
    if score > best {
        best = score
    }
}
print("Passed: \(passed), best: \(best), average: \(sum / scores.count)")
```

```output
Passed: 3, best: 95, average: 73
```

One pass, three results. The chained version would be three chains, each easy to read, walking the array three times. For four scores either is fine; pick the one that reads more clearly.

## Common mistakes

> [!error] warning: result of call to 'map' is unused
> You called `map` and didn't use what it returned, often because you meant it as a loop. `map` builds a new array; it doesn't change the original. Either use the result (`let doubled = numbers.map { … }`) or, if you only wanted to do something with each element, write a `for` loop. Swift 6.3:

```swift warning result of call to 'map' is unused
let numbers = [1, 2, 3]
numbers.map { n in n * 2 }
print(numbers)
```

```output
[1, 2, 3]
```

> [!error] error: cannot use mutating member on immutable value
> `scores.sort()` on a `let` array. `sort()` changes the array in place; `sorted()` returns a new one and works on a `let`. Swift 6.3:

```swift no-compile cannot use mutating member on immutable value: 'scores' is a 'let' constant
let scores = [75, 92, 58]
scores.sort()
print(scores)
```

> [!error] Using map when you need filter
> `scores.map { s in s >= 60 }` doesn't keep the passing scores; it returns `[true, false, …]`, one `Bool` per score. If the closure returns a `Bool` and you want to **keep** elements, that's `filter`.

> [!error] The wrong initial value for reduce
> `reduce(0, *)` is always 0. Products start at 1, sums at 0. Ask what the answer should be for an empty array; that's your initial value.

> [!error] Using map with ?? 0 when bad input should be dropped
> `map { text in Int(text) ?? 0 }` turns every invalid entry into a 0 that looks like data. If invalid entries should disappear, use `compactMap`.

````exercise
id: m07-l05-e1
type: comprehension
prompt: You have an array of 50 orders' totals. You want an array with only the orders over 1,000. Which call does that?
choices:
  - text: "`totals.map { t in t > 1000 }`"
    correct: false
    why: That's an array of 50 Bools, one per order, not the orders themselves.
  - text: "`totals.filter { t in t > 1000 }`"
    correct: true
    why: filter keeps the elements for which the closure is true, unchanged.
  - text: "`totals.reduce(0) { sum, t in t > 1000 ? sum + t : sum }`"
    correct: false
    why: That's the sum of the big orders, one Int, not an array of them.
  - text: "`totals.first { t in t > 1000 } ?? 0`"
    correct: false
    why: That's only the first big order.
solution: |
  **`filter`.** The tell is that you want *some of the same elements back*. `map` would give you one transformed value per order, here a `Bool`. `reduce` boils everything down to one value. `first(where:)` stops at the first match. `filter` keeps every match, in order, as an array.
````

````exercise
id: m07-l05-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let values = [5, 2, 8, 3]
  print(values.map { v in v * 10 })
  print(values.filter { v in v % 2 == 1 })
  print(values.reduce(100) { result, v in result - v })
  print(values.sorted(by: >))
  print(["3", "a", "7"].compactMap { t in Int(t) })
  print([[1, 2], [3], []].flatMap { group in group })
  print(values)
output: |
  [50, 20, 80, 30]
  [5, 3]
  82
  [8, 5, 3, 2]
  [3, 7]
  [1, 2, 3]
  [5, 2, 8, 3]
hints:
  - "reduce starts at 100 and subtracts each value in turn."
  - None of these methods change values.
solution: |
  ```output
  [50, 20, 80, 30]
  [5, 3]
  82
  [8, 5, 3, 2]
  [3, 7]
  [1, 2, 3]
  [5, 2, 8, 3]
  ```

  - `map` multiplies each by 10.
  - `filter` keeps the odd values, 5 and 3, in their original order.
  - `reduce(100)`: 100 − 5 = 95, − 2 = 93, − 8 = 85, − 3 = **82**.
  - `sorted(by: >)`: largest first.
  - `compactMap` drops `"a"`, which isn't a number.
  - `flatMap` joins `[1, 2]`, `[3]` and `[]`.
  - The last line is the trap: every one of these returns a **new** array. `values` was never changed.
````

````exercise
id: m07-l05-e3
type: fill-in
prompt: |
  Complete the chain so it prints the total of the valid, positive amounts:

  ```output
  175
  ```
code: |
  let amounts = ["50", "-20", "abc", "125"]
  let total = amounts
      .[[1]] { text in Int(text) }
      .[[2]] { amount in amount > 0 }
      .reduce([[3]], +)
  print(total)
blanks:
  - id: "1"
    answers: ["compactMap"]
  - id: "2"
    answers: ["filter"]
  - id: "3"
    answers: ["0"]
solution: |
  ```swift
  let amounts = ["50", "-20", "abc", "125"]
  let total = amounts
      .compactMap { text in Int(text) }
      .filter { amount in amount > 0 }
      .reduce(0, +)
  print(total)
  ```

  ```output
  175
  ```

  `compactMap` parses and drops `"abc"`: `[50, -20, 125]`. `filter` drops the negative: `[50, 125]`. `reduce(0, +)` adds them, starting from 0. `Int("-20")` is a valid number, -20, which is why it takes the `filter` step to remove it.
````

````exercise
id: m07-l05-e4
type: refactor
prompt: Rewrite this code with map, filter and reduce. The output must be identical.
code: |
  let words = ["swift", "is", "a", "language", "for", "apps"]
  var longWords: [String] = []
  for word in words {
      if word.count > 3 {
          longWords.append(word.uppercased())
      }
  }
  var totalLetters = 0
  for word in longWords {
      totalLetters += word.count
  }
  print(longWords)
  print(totalLetters)
rubric:
  - I used filter for the length check and map for the uppercasing.
  - I computed the total with reduce or with map followed by reduce.
  - Both results are let constants.
  - The output is the same as the original.
solution: |
  ```swift
  let words = ["swift", "is", "a", "language", "for", "apps"]
  let longWords = words
      .filter { word in word.count > 3 }
      .map { word in word.uppercased() }
  let totalLetters = longWords.reduce(0) { sum, word in sum + word.count }
  print(longWords)
  print(totalLetters)
  ```

  ```output
  ["SWIFT", "LANGUAGE", "APPS"]
  17
  ```

  The `if` inside the first loop becomes a `filter`, and the transformation inside it becomes a `map`. Filtering first means `uppercased()` only runs on the words you keep. The second loop is a sum, so it's `reduce(0)`, where the closure adds each word's length to the running total. `longWords.map { word in word.count }.reduce(0, +)` is an equally good answer.
````

````exercise
id: m07-l05-e5
type: solve
prompt: |
  A store has two arrays that line up by position: product names and units sold. Print the products sorted by units sold, highest first, with ties broken alphabetically, numbered from 1:

  ```output
  1. mugs: 40
  2. pens: 25
  3. tape: 25
  4. glue: 10
  ```
starter: |
  let products = ["pens", "glue", "mugs", "tape"]
  let unitsSold = [25, 10, 40, 25]
hints:
  - "zip(products, unitsSold) gives you pairs. Array(zip(…)) turns them into an array you can sort."
  - "In sorted { a, b in … }, compare the units first; if they're equal, compare the names."
  - enumerated() gives you the position for the numbering.
rubric:
  - I paired the arrays with zip instead of indexing both by hand.
  - The sort has a tie-breaker, so pens comes before tape every time.
  - The numbering starts at 1.
  - The output matches exactly.
solution: |
  ```swift
  let products = ["pens", "glue", "mugs", "tape"]
  let unitsSold = [25, 10, 40, 25]

  let ranking = zip(products, unitsSold).sorted { a, b in
      if a.1 != b.1 {
          return a.1 > b.1
      }
      return a.0 < b.0
  }
  for (index, entry) in ranking.enumerated() {
      print("\(index + 1). \(entry.0): \(entry.1)")
  }
  ```

  ```output
  1. mugs: 40
  2. pens: 25
  3. tape: 25
  4. glue: 10
  ```

  `zip` pairs each name with its units, as `(String, Int)` tuples. `sorted` works directly on what `zip` produces and returns an array of those tuples. The closure answers "should `a` come before `b`?": more units first, and for equal units, the alphabetically smaller name. Pens and tape both sold 25, and the tie-breaker puts pens first. `enumerated()` supplies the position for the numbering.
````

````exercise
id: m07-l05-e6
type: explain
prompt: "A teammate writes `let results = scores.map { score in print(score) }` to print every score. It compiles. Explain what's wrong with it and what to write instead."
code: |
  let scores = [88, 95, 42]
  let results = scores.map { score in print(score) }
rubric:
  - I explained that map builds a new array from the closure's return values.
  - I noticed print returns nothing, so results is an array of empty values.
  - I recommended a for loop for side effects like printing.
solution: |
  It does print the scores, but it uses `map` for the wrong job. `map` exists to build a new array from what the closure **returns**. `print` returns nothing (its return type is `Void`, written `()`), so `results` is an array of three empty `()` values that nobody will ever use. Swift 6.3 even hints at it with a warning: `constant 'results' inferred to have type '[()]', which may be unexpected`. Anyone reading the code expects `results` to mean something.

  When the goal is to *do* something with each element, like printing, saving or sending, write a loop:

  ```swift
  let scores = [88, 95, 42]
  for score in scores {
      print(score)
  }
  ```

  ```output
  88
  95
  42
  ```

  Rule of thumb: `map`, `filter` and `reduce` are for computing values. `for` is for actions.
````

## Summary

- `map` transforms every element; same count, possibly a different type.
- `filter` keeps the elements whose predicate is `true`, unchanged and in order.
- `reduce(initial) { soFar, element in … }` is the accumulator in one call. Sums start at 0, products at 1. `reduce(0, +)` passes the `+` function directly.
- `compactMap` converts and drops failures; `flatMap` joins the arrays the closure returns into one.
- `sorted()` ascending, `sorted(by: >)` descending, `sorted { a, b in … }` for your own rule, with a tie-breaker when equal elements must come out the same every time.
- `zip(a, b)` pairs by position and stops at the shorter array.
- None of them change the original array. Use a loop when you need several results in one pass, an early exit, or a side effect.
