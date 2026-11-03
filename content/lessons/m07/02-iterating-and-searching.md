---
id: m07-l02
title: Iterating and searching
description: You loop over arrays with their elements, their indexes or both, and use contains, first(where:), firstIndex(of:), allSatisfy, min and max to answer questions about them, including what happens when the array is empty.
module: m07
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l01]
objectives:
  - Loop over an array's elements, its indexes, or both with enumerated().
  - Answer yes/no questions with contains, contains(where:) and allSatisfy.
  - Find an element or its position with first(where:) and firstIndex(of:), and handle the "not found" case.
  - Get the smallest and largest values with min() and max().
  - Explain in plain words why a linear search takes up to N steps.
terms:
  - term: Iteration
    definition: Visiting each element of a collection once, usually with a for-in loop.
  - term: enumerated()
    definition: A method that pairs each element with a counter starting at 0, so a loop can use both. For an array, the counter matches the index.
  - term: Predicate
    definition: A function or closure that takes an element and returns a Bool, like { n in n > 30 }. contains(where:), first(where:) and allSatisfy all take one.
  - term: Linear search
    definition: Checking elements one by one, from the start, until you find what you're looking for or run out. On an array of N elements it takes up to N checks.
mastery:
  - Choose between for x in array, for i in array.indices and for (i, x) in array.enumerated() for a given task.
  - Write a linear search by hand and replace it with the matching standard library method.
  - Use ?? to handle the "not found" result of first(where:), firstIndex(of:), min() and max().
  - Predict what contains, allSatisfy, min and max return for an empty array.
resources: [swift-array, swift-book-collection-types, swift-book-control-flow, swift-book-closures]
cards:
  - id: m07-l02-c1
    front: How do you loop over an array's elements and their indexes at the same time?
    back: "for (index, element) in array.enumerated() { … }. For an array, the counter enumerated() gives you is the index."
  - id: m07-l02-c2
    front: What does first(where:) return?
    back: The first element that makes the closure return true, as an optional, because there may be none. Use ?? for a default until Module 8.
  - id: m07-l02-c3
    front: What does allSatisfy return for an empty array?
    back: true. There's no element that fails the test. If an empty array should count as a failure, check isEmpty separately.
  - id: m07-l02-c4
    front: How many checks does contains need on an array of N elements?
    back: Up to N. It looks at the elements one by one until it finds a match, so the worst case (not found, or found last) checks all of them.
---

## The idea in one sentence

Most questions about an array, like "is it there?", "where is it?" or "are they all valid?", are a loop that visits the elements in order, and Swift has a named method for each common one.

## Three ways to loop

You've used the first one since Module 5. It gives you each **element**:

```swift
let guests = ["Ana", "Luis", "Marta"]
for guest in guests {
    print("Welcome, \(guest)")
}
```

```output
Welcome, Ana
Welcome, Luis
Welcome, Marta
```

When you need the **position** as well, loop over `indices`:

```swift
let guests = ["Ana", "Luis", "Marta"]
for index in guests.indices {
    print("\(index + 1). \(guests[index])")
}
```

```output
1. Ana
2. Luis
3. Marta
```

`guests.indices` is the range `0..<3`, so `index` takes the values 0, 1 and 2, all valid. The `+ 1` turns the index into a human position: people count from 1.

`enumerated()` gives you both at once, as a pair you take apart in the `for`, the same way you took apart tuples in Module 6:

```swift
let guests = ["Ana", "Luis", "Marta"]
for (index, guest) in guests.enumerated() {
    print("\(index + 1). \(guest)")
}
```

```output
1. Ana
2. Luis
3. Marta
```

Which one to pick:

| You need | Write |
| --- | --- |
| Only the elements | `for x in array` |
| Elements and positions | `for (i, x) in array.enumerated()` |
| Positions, to read or change `array[i]`, or to compare `array[i]` with `array[i + 1]` | `for i in array.indices` |

Prefer `for x in array` when it's enough. Indexes are where off-by-one mistakes live, so don't bring them in unless you use them.

> [!warning] Don't loop with 0...array.count
> `for i in 0...guests.count` includes `count`, one past the last index, and crashes on the final pass. `0..<guests.count` is correct but easy to get wrong; `guests.indices` can't be.

## The accumulator, on arrays

The **accumulator** from Modules 2 and 5 works on arrays the same way it did on ranges: a `var` before the loop, updated with each element.

```swift
let temperatures = [18, 31, 24, 33, 29]
var sum = 0
var hotDays = 0
for temperature in temperatures {
    sum += temperature
    if temperature > 30 {
        hotDays += 1
    }
}
print("Average: \(sum / temperatures.count)")
print("Days over 30: \(hotDays)")
```

```output
Average: 27
Days over 30: 2
```

The sum is 135, and `135 / 5` is 27 with integer division. Now think about the edge case from Module 2: **what if the array is empty?** The loop runs zero times, `sum` is 0, and `0 / 0` crashes the program with a division by zero. Any calculation that divides by `count` needs a `guard !temperatures.isEmpty` (or an `if`) first.

## Searching

### contains: is it there?

`contains(_:)` answers whether an element is in the array:

```swift
let guests = ["Ana", "Luis", "Marta"]
print(guests.contains("Luis"))
print(guests.contains("luis"))
```

```output
true
false
```

The comparison is exact, so `"luis"` with a lowercase L isn't found. Strings are compared character by character.

Here's what `contains` does, written by hand. This is a **linear search**:

```swift
func containsName(_ target: String, in names: [String]) -> Bool {
    for name in names {
        if name == target {
            return true
        }
    }
    return false
}

let guests = ["Ana", "Luis", "Marta"]
print(containsName("Marta", in: guests))
print(containsName("Sofía", in: guests))
```

```output
true
false
```

It checks the elements in order and stops at the first match (`return` ends the function, loop and all). If it gets through the whole array without a match, the answer is `false`.

**How long does that take?** If the array has N elements, the search does at most N comparisons: the worst case is when the element is last, or not there at all, because then it has to check every one. Double the array, and the worst case doubles too. For 3 guests that's nothing. For a million records checked a million times, it's a trillion comparisons, and that's when you reach for a `Set` (lesson 4) or a `Dictionary` (lesson 3). Module 15 puts a name and a notation to this; for now, "up to N steps" is the idea.

### contains(where:): is there one that…?

To ask about a **condition** rather than an exact value, pass a closure that returns a `Bool`. A closure like that is called a **predicate**. You wrote functions that take predicates in Module 6, like `count(from:to:where:)`; this is the same idea, already built into the array:

```swift
let temperatures = [18, 31, 24, 33, 29]
print(temperatures.contains(where: { t in t > 32 }))
print(temperatures.contains { t in t < 0 })
```

```output
true
false
```

The second call uses a **trailing closure** (Module 6): the closure moves outside the parentheses and the `where:` label goes away. You'll see both forms. The rest of this module mostly uses trailing closures, because that's how most Swift code is written.

### allSatisfy: do they all…?

`allSatisfy` is the opposite question: does **every** element pass?

```swift
let scores = [72, 88, 95, 64]
print(scores.allSatisfy { score in score >= 60 })
print(scores.allSatisfy { score in score >= 70 })
let noScores: [Int] = []
print(noScores.allSatisfy { score in score >= 70 })
```

```output
true
false
true
```

The last line surprises people. An empty array has no element that fails the test, so `allSatisfy` returns `true`. Logicians call it a "vacuous truth". It's the right answer for the question as asked, but it might not be the right answer for your program: if "every student passed" shouldn't be true when there are no students, check `isEmpty` too.

### first(where:): which one?

`first(where:)` returns the first element that passes the test. There might not be one, so it returns an **optional**. Module 8 covers optionals properly; for now, use `??` to give a default:

```swift
let temperatures = [18, 31, 24, 33, 29]
let firstHot = temperatures.first { t in t > 30 } ?? -1
let firstFreezing = temperatures.first { t in t < 0 } ?? -1
print(firstHot)
print(firstFreezing)
```

```output
31
-1
```

`first(where:)` also stops at the first match: it never looks at 33.

### firstIndex(of:): where is it?

`firstIndex(of:)` returns the **index** of the first element equal to the one you give it. Also an optional, since the element might not be there:

```swift
let queue = ["Ana", "Luis", "Marta", "Luis"]
let position = queue.firstIndex(of: "Luis") ?? -1
let missing = queue.firstIndex(of: "Sofía") ?? -1
print(position)
print(missing)
```

```output
1
-1
```

`"Luis"` appears twice; you get the first. The `-1` default is the **sentinel** from Module 6: a value that can't be a real index. `firstIndex(where:)` exists too, and takes a predicate instead of a value.

### min() and max()

`min()` and `max()` find the smallest and largest elements. An empty array has neither, so they return optionals:

```swift
let temperatures = [18, 31, 24, 33, 29]
print(temperatures.min() ?? 0)
print(temperatures.max() ?? 0)
let none: [Int] = []
print(none.max() ?? 0)
```

```output
18
33
0
```

Compare that with the hand-written maximum from Module 5, which started at `Int.min`. On an empty list, that loop would report `Int.min` as the highest temperature, a number that looks like data and isn't. The optional makes you decide what an empty array means.

| Method | Returns | Empty array |
| --- | --- | --- |
| `contains(x)`, `contains(where:)` | `Bool` | `false` |
| `allSatisfy` | `Bool` | `true` |
| `first(where:)` | optional element | nothing (use `??`) |
| `firstIndex(of:)` | optional index | nothing (use `??`) |
| `min()`, `max()` | optional element | nothing (use `??`) |

All of them are linear searches inside: up to N steps on an array of N elements.

## A practical example: checking a week of orders

```swift
let orderTotals = [120, 45, 300, 80, 45, 510]
let limit = 500

if orderTotals.isEmpty {
    print("No orders this week")
} else {
    var revenue = 0
    for total in orderTotals {
        revenue += total
    }
    print("Orders: \(orderTotals.count), revenue: \(revenue)")
    print("Smallest: \(orderTotals.min() ?? 0), largest: \(orderTotals.max() ?? 0)")
    print("All under \(limit): \(orderTotals.allSatisfy { total in total < limit })")

    let bigOrder = orderTotals.firstIndex { total in total >= limit } ?? -1
    if bigOrder >= 0 {
        print("Order #\(bigOrder + 1) needs approval: \(orderTotals[bigOrder])")
    }
}
```

```output
Orders: 6, revenue: 1100
Smallest: 45, largest: 510
All under 500: false
Order #6 needs approval: 510
```

The empty case is handled first, so everything after it can assume at least one order. `firstIndex { … }` is `firstIndex(where:)` with a trailing closure. The `bigOrder >= 0` check turns the sentinel back into a decision before the index is used.

## Common mistakes

> [!error] Fatal error: Index out of range in a loop
> `for i in 0...array.count` goes one step too far. Use `for i in array.indices`, or loop over the elements and skip the index entirely.

```swift runtime-error Index out of range
let names = ["Ana", "Luis"]
for i in 0...names.count {
    print(names[i])
}
```

```output
Ana
Luis
```

> [!error] error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
> You used the result of `first(where:)`, `firstIndex(of:)`, `min()` or `max()` as if it were a plain value. They return optionals. Add `?? default` for now; Module 8 shows the other ways. Swift 6.3:

```swift no-compile value of optional type 'Int?' must be unwrapped to a value of type 'Int'
let scores = [70, 85, 90]
let best = scores.max()
print(best + 5)
```

> [!error] Dividing by count without checking for empty
> An average computed as `sum / values.count` crashes when `values` is empty. Check `isEmpty` first and decide what an empty input should print.

> [!error] Trusting allSatisfy on an empty array
> `[].allSatisfy { … }` is `true`. If "all passed" requires at least one element, write `!values.isEmpty && values.allSatisfy { … }`.

> [!error] Using a sentinel as an index
> `firstIndex(of:) ?? -1` gives -1 when nothing is found. Using that -1 as an index crashes. Check it before you subscript.

````exercise
id: m07-l02-e1
type: comprehension
prompt: You want to print each player's name next to their rank, starting at 1 ("1. Ana"). Which loop fits best?
choices:
  - text: "`for (index, player) in players.enumerated()`, printing `index + 1` and `player`"
    correct: true
    why: You get both the position and the element without subscripting.
  - text: "`for player in players`, printing `players.count` and `player`"
    correct: false
    why: count is the same on every pass, so every line would show the same number.
  - text: "`for i in 1...players.count`, printing `i` and `players[i]`"
    correct: false
    why: "The numbers would be right, but players[i] is shifted by one: it skips index 0 and crashes on the last pass."
  - text: "`for i in 0...players.count`, printing `i + 1` and `players[i]`"
    correct: false
    why: "The closed range includes count, one past the last index, so the last pass crashes."
solution: |
  **`enumerated()`.** It hands you the index and the element together, so you never subscript and can't go out of range. The `1...players.count` version is a classic off-by-one: the numbers printed are right, but they're used as indexes, which start at 0. `0...players.count` has the same crash at the other end. If you prefer indexes, `for i in players.indices` with `i + 1` and `players[i]` is also correct.
````

````exercise
id: m07-l02-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let values = [4, 9, 2, 9, 7]
  print(values.contains(2))
  print(values.firstIndex(of: 9) ?? -1)
  print(values.first { v in v > 5 } ?? 0)
  print(values.allSatisfy { v in v > 1 })
  print(values.max() ?? 0, values.min() ?? 0)
  let none: [Int] = []
  print(none.contains(2), none.allSatisfy { v in v > 100 }, none.min() ?? -1)
output: |
  true
  1
  9
  true
  9 2
  false true -1
hints:
  - firstIndex and first(where:) stop at the first match.
  - Think about what an empty array has to say to each question.
solution: |
  ```output
  true
  1
  9
  true
  9 2
  false true -1
  ```

  - `contains(2)`: 2 is at index 2, so `true`.
  - `firstIndex(of: 9)`: 9 appears at 1 and 3; the first is **1**.
  - `first { v in v > 5 }`: 4 fails, 9 passes. Result **9**.
  - `allSatisfy { v in v > 1 }`: every value is at least 2. `true`.
  - `max` is 9 and `min` is 2.
  - On the empty array, `contains` is `false` (nothing to find), `allSatisfy` is `true` (nothing fails), and `min()` has no answer, so `??` gives -1.
````

````exercise
id: m07-l02-e3
type: fill-in
prompt: |
  Complete the program so it prints exactly:

  ```output
  0: Lima
  1: Quito
  Has Quito: true
  ```
code: |
  let cities = ["Lima", "Quito"]
  for ([[1]], city) in cities.[[2]]() {
      print("\(index): \(city)")
  }
  print("Has Quito: \(cities.[[3]]("Quito"))")
blanks:
  - id: "1"
    answers: ["index"]
  - id: "2"
    answers: ["enumerated"]
  - id: "3"
    answers: ["contains"]
solution: |
  ```swift
  let cities = ["Lima", "Quito"]
  for (index, city) in cities.enumerated() {
      print("\(index): \(city)")
  }
  print("Has Quito: \(cities.contains("Quito"))")
  ```

  ```output
  0: Lima
  1: Quito
  Has Quito: true
  ```

  `enumerated()` gives pairs of (counter, element). The first name in the parentheses has to be `index`, since that's what the body uses. `contains` returns a `Bool`, and interpolation prints it as `true`.
````

````exercise
id: m07-l02-e4
type: find-errors
prompt: This function should return the average of an array of scores, and 0 for an empty array. Pick out the real problems.
code: |
  func average(of scores: [Int]) -> Int {
      var sum = 0
      for i in 0...scores.count {
          sum += scores[i]
      }
      return sum / scores.count
  }
choices:
  - text: "The loop goes one index too far and crashes on the last pass."
    correct: true
    why: "0...scores.count includes count. It should be scores.indices, or loop over the elements directly."
  - text: "An empty array makes it divide by zero."
    correct: true
    why: "With no scores, count is 0. It needs a guard that returns 0 first."
  - text: "sum has to be declared with let."
    correct: false
    why: sum changes inside the loop, so var is correct.
  - text: "Integer division can't be used for averages at all."
    correct: false
    why: "It truncates (87.5 becomes 87), which may or may not be acceptable, but it isn't an error. The spec says Int."
rubric:
  - I loop without going past the last index.
  - The function returns 0 for an empty array without crashing.
  - I explained which problem crashes and on which input.
solution: |
  ```swift
  func average(of scores: [Int]) -> Int {
      guard !scores.isEmpty else {
          return 0
      }
      var sum = 0
      for score in scores {
          sum += score
      }
      return sum / scores.count
  }

  print(average(of: [80, 95, 88]))
  print(average(of: []))
  ```

  ```output
  87
  0
  ```

  The loop crashes on any input, on the pass where `i` equals `count`. The division crashes on the empty array. Looping over the elements removes the index entirely, and the `guard` handles the empty case up front. `263 / 3` is 87 with integer division.
````

````exercise
id: m07-l02-e5
type: solve
prompt: |
  Write `func positionOfFirstNegative(in values: [Int]) -> Int` as a **linear search by hand** (a loop, no `firstIndex`). It returns the index of the first negative number, or -1 if there isn't one. Then check it against `firstIndex(where:)`:

  ```output
  2 2
  -1 -1
  -1 -1
  ```

  Use `[5, 3, -2, 8, -7]`, `[1, 2, 3]` and an empty array.
starter: |
  func positionOfFirstNegative(in values: [Int]) -> Int {
      // Your loop
      return -1
  }
hints:
  - "You need the index, so loop over values.indices or use enumerated()."
  - Return as soon as you find one. If the loop finishes, nothing was found.
rubric:
  - The search is a loop that stops at the first match.
  - It returns -1 for an array with no negatives and for an empty array.
  - Each line compares my function with firstIndex(where:) ?? -1.
  - I can say how many checks it does in the worst case.
solution: |
  ```swift
  func positionOfFirstNegative(in values: [Int]) -> Int {
      for (index, value) in values.enumerated() {
          if value < 0 {
              return index
          }
      }
      return -1
  }

  let samples = [[5, 3, -2, 8, -7], [1, 2, 3], []]
  for sample in samples {
      let mine = positionOfFirstNegative(in: sample)
      let library = sample.firstIndex { value in value < 0 } ?? -1
      print(mine, library)
  }
  ```

  ```output
  2 2
  -1 -1
  -1 -1
  ```

  The `return index` inside the loop ends the function at the first negative, so -7 is never reached. If the loop ends without a match, including when there's nothing to loop over, the function falls through to `return -1`. In the worst case (no negatives) it checks all N elements; that's the same work `firstIndex(where:)` does.

  `samples` is an array of arrays, `[[Int]]`. Lesson 6 covers nested arrays; here it just saves writing the three calls by hand.
````

````exercise
id: m07-l02-e6
type: refactor
prompt: Rewrite this code using standard library methods instead of hand-written loops. The output must stay the same.
code: |
  let ages = [34, 17, 52, 29]
  var hasMinor = false
  for age in ages {
      if age < 18 {
          hasMinor = true
      }
  }
  var oldest = 0
  for age in ages {
      if age > oldest {
          oldest = age
      }
  }
  print(hasMinor, oldest)
rubric:
  - I replaced the first loop with contains(where:).
  - I replaced the second loop with max() and a default.
  - The output is still "true 52".
  - I noticed that the original keeps looping after it finds a minor.
solution: |
  ```swift
  let ages = [34, 17, 52, 29]
  let hasMinor = ages.contains { age in age < 18 }
  let oldest = ages.max() ?? 0
  print(hasMinor, oldest)
  ```

  ```output
  true 52
  ```

  Each method's name says what the loop was for, and both results are now `let`. There's a small behavior difference in your favor: the original first loop kept checking after it found 17, while `contains(where:)` stops at the first match. `oldest` started at 0 in the original, which would have reported 0 for an empty array; `?? 0` keeps that behavior, but now the choice is visible.
````

## Summary

- `for x in array` for elements, `for (i, x) in array.enumerated()` for both, `for i in array.indices` when you need positions. Never `0...array.count`.
- `contains`, `contains(where:)` and `allSatisfy` answer yes/no questions. `allSatisfy` is `true` for an empty array.
- `first(where:)`, `firstIndex(of:)`, `min()` and `max()` return optionals, because there might be no answer. Use `??` until Module 8.
- They're all linear searches: up to N checks on N elements.
- Always ask what your code does with an empty array, especially before dividing by `count`.
