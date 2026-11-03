---
id: m06-l03
title: "Returning more: tuples and early exits"
description: You return several values at once with a tuple, swap two variables in one line, validate parameters with guard at the top of a function, and signal "no result" with a flag or a sentinel until optionals arrive in Module 8.
module: m06
order: 3
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l02]
objectives:
  - Return several values from a function with a tuple, with named elements.
  - Read a tuple's elements by name, by position and by destructuring.
  - Swap two variables with (a, b) = (b, a).
  - Validate a function's input with guard and return early.
  - Signal that a function has no meaningful result with a flag or a sentinel value, and explain the weaknesses of both.
terms:
  - term: Tuple
    definition: A group of values written between parentheses and separated by commas, like (3, "Ana"). The values can have different types. Its type lists them, like (Int, String).
  - term: Named tuple element
    definition: "A tuple element with a name, like min in (min: 2, max: 9). You read it with .min."
  - term: Destructuring
    definition: Taking a tuple apart into separate constants or variables in one statement, like let (low, high) = range.
  - term: Early exit
    definition: Leaving a function with return before reaching the end of its body, usually because the input isn't valid or the answer is already known.
  - term: Sentinel value
    definition: A special value of the normal return type that means "no result", like -1 for "not found". It only works if that value can never be a real answer.
mastery:
  - Write a function that returns a tuple with named elements and use the result in three ways.
  - Rewrite a three-line swap with a temporary constant as a single tuple assignment.
  - Restructure a function with nested ifs so it validates its input with guard at the top.
  - Explain why returning -1 for "not found" is fragile, and what a flag adds.
resources: [swift-book-functions, swift-book-basics, swift-book-control-flow]
cards:
  - id: m06-l03-c1
    front: How do you return a minimum and a maximum from one function?
    back: "With a tuple: declare -> (min: Int, max: Int) and return (lowest, highest). The caller reads result.min and result.max, or destructures with let (low, high) = …"
  - id: m06-l03-c2
    front: How do you swap a and b in one line?
    back: (a, b) = (b, a). The right side builds a tuple with the current values before anything is assigned, so no value is lost.
  - id: m06-l03-c3
    front: Why does guard fit so well at the top of a function?
    back: "Its else block must leave the function, usually with return. After the guard, the rest of the body can assume the input is valid, without extra nesting."
  - id: m06-l03-c4
    front: What's a sentinel value, and what's its weakness?
    back: A normal-looking value that means "no result", like -1 for "not found". If that value can ever be a real answer, the caller can't tell the cases apart. Optionals (Module 8) fix this.
---

## The idea in one sentence

A function returns exactly one value, but that value can be a **tuple** that holds several, and a function can return **early**, as soon as it knows the answer.

## Tuples

A tuple groups several values into one, between parentheses:

```swift
let order = ("Coffee", 2, 45)
print(order)
print(order.0, order.1, order.2)

let namedOrder = (item: "Coffee", quantity: 2, price: 45)
print(namedOrder.item, namedOrder.quantity * namedOrder.price)
```

```output
("Coffee", 2, 45)
Coffee 2 45
Coffee 90
```

1. `("Coffee", 2, 45)` is a tuple of type `(String, Int, Int)`. The types can differ.
2. `print` shows a tuple with its parentheses.
3. You read elements by **position**, starting at 0: `.0`, `.1`, `.2`.
4. If you name the elements, you read them by **name**: `.item`, `.quantity`. Names make the code say what each value is.

## Returning a tuple

When a calculation naturally produces two values, return both:

```swift
func minMax(_ a: Int, _ b: Int, _ c: Int) -> (min: Int, max: Int) {
    var lowest = a
    var highest = a
    if b < lowest { lowest = b }
    if c < lowest { lowest = c }
    if b > highest { highest = b }
    if c > highest { highest = c }
    return (lowest, highest)
}

let range = minMax(4, 9, 2)
print(range)
print("From \(range.min) to \(range.max)")

let (low, high) = minMax(7, 1, 5)
print(low, high)

let (_, onlyHigh) = minMax(3, 8, 6)
print(onlyHigh)
```

```output
(min: 2, max: 9)
From 2 to 9
1 7
8
```

Line by line:

1. The return type `(min: Int, max: Int)` is a tuple with two named elements.
2. `return (lowest, highest)` builds the tuple. The names come from the return type, so you don't repeat them here.
3. `range.min` and `range.max` read the elements by name.
4. `let (low, high) = …` **destructures** the result: it creates two constants at once, one per element.
5. `_` in a destructuring means "I don't need this element".

Without a tuple you'd need two functions, `minimum` and `maximum`, that walk the same values twice. Use a tuple when the values belong together and come out of the same calculation. If you find yourself returning five unrelated values, that's a sign you want a type of your own, which you'll write in Module 9.

## The swap, finally

In Module 4 you swapped two variables with a temporary constant, and the lesson promised a one-line version:

```swift
var a = 3
var b = 8
(a, b) = (b, a)
print(a, b)
```

```output
8 3
```

The right side, `(b, a)`, is evaluated **first**: it builds the tuple `(8, 3)` from the current values. Only then is that tuple destructured into `a` and `b`. Nothing is overwritten before it's read, so no value is lost.

The same trick fixes the Fibonacci step from the trace tables lesson, where you needed a `next` variable so `b ← a + b` wouldn't use an `a` you'd just changed:

```swift
var a = 0
var b = 1
for _ in 1...8 {
    print(a, terminator: " ")
    (a, b) = (b, a + b)
}
print()
```

```output
0 1 1 2 3 5 8 13 
```

`(b, a + b)` is computed with the old `a` and `b`, then both are assigned at once. (The output line ends with a space because each number is printed with `terminator: " "`.)

## Early exits: more than one return

`return` ends the function **immediately**. Nothing after it runs. A function can have several `return` statements, and the first one reached wins:

```swift
func letterGrade(for score: Int) -> String {
    if score >= 90 {
        return "A"
    }
    if score >= 80 {
        return "B"
    }
    if score >= 70 {
        return "C"
    }
    return "F"
}

print(letterGrade(for: 95), letterGrade(for: 83), letterGrade(for: 40))
```

```output
A B F
```

No `else` is needed: if the score is 95, the first `return` ends the function and the other checks never run. If the score is 83, the first `if` is false, so execution continues and the second `return` ends it. The final `return "F"` is the case where nothing matched. That last line is required, because Swift checks that **every path** returns a `String`.

## guard at the top of a function

In Module 5 you used `guard` inside loops and read that it's most at home at the top of a function. This is why. Its `else` block **must leave the current scope**, and in a function that means `return`. So a guard at the top says: *if the input isn't valid, stop here*. Everything after it can assume the input is valid.

```swift
func pricePerPerson(total: Int, people: Int) -> Int {
    guard people > 0 else {
        print("Can't split a bill between \(people) people")
        return 0
    }
    return total / people
}

print(pricePerPerson(total: 300, people: 4))
print(pricePerPerson(total: 300, people: 0))
```

```output
75
Can't split a bill between 0 people
0
```

Without the `guard`, `pricePerPerson(total: 300, people: 0)` would divide by zero and crash the program. With it, the division only happens when `people > 0` is guaranteed.

When there are several conditions, stack the guards:

```swift
func shippingCost(weightKg: Int, distanceKm: Int) -> Int {
    guard weightKg > 0 else { return 0 }
    guard distanceKm > 0 else { return 0 }
    guard weightKg <= 30 else { return 0 }

    let base = 50
    return base + weightKg * 5 + distanceKm / 10
}

print(shippingCost(weightKg: 2, distanceKm: 120))
print(shippingCost(weightKg: 40, distanceKm: 120))
```

```output
72
0
```

Each `guard` handles one invalid case and gets out. The real work sits at the bottom, at the left margin. Written with `if`s instead, it would sit three levels deep, with an `else` for each level. That shape, **checks first, work last**, is what professional Swift code looks like.

In a function that returns `Void`, the guard's `else` ends with a bare `return`:

```swift
func printReceipt(item: String, quantity: Int) {
    guard quantity > 0 else {
        print("Nothing to print for \(item)")
        return
    }
    print("\(quantity) x \(item)")
}

printReceipt(item: "Coffee", quantity: 2)
printReceipt(item: "Tea", quantity: 0)
```

```output
2 x Coffee
Nothing to print for Tea
```

## Returning "no result"

Look again at `pricePerPerson(total: 300, people: 0)`: it returns `0`. But `0` could also be a real answer, if the total were 0. The caller has no way to tell "the bill is free" from "the input was invalid". A function sometimes has **no meaningful result**, and it needs a way to say so.

Until Module 8, you have two tools.

**A sentinel value**: a value of the normal type that you agree means "nothing". Here, -1 can mean "not found", because a real position is never negative:

```swift
func positionOfFirstVowel(in word: String) -> Int {
    var position = 0
    for letter in word {
        if letter == "a" || letter == "e" || letter == "i" || letter == "o" || letter == "u" {
            return position
        }
        position += 1
    }
    return -1
}

print(positionOfFirstVowel(in: "swift"))
print(positionOfFirstVowel(in: "rhythm"))
```

```output
2
-1
```

The `return position` inside the loop ends the whole function, not just the loop. If the loop finishes without finding a vowel, the function reaches `return -1`. `for letter in word` visits the characters of a `String` one by one, from first to last.

**A flag in a tuple**: return a `Bool` that says whether the other value means anything:

```swift
func parseAge(_ text: String) -> (isValid: Bool, age: Int) {
    let number = Int(text) ?? -1
    guard number >= 0 && number <= 130 else {
        return (false, 0)
    }
    return (true, number)
}

let inputs = ["34", "abc", "200", "0"]
for input in inputs {
    let result = parseAge(input)
    if result.isValid {
        print("\(input): age \(result.age)")
    } else {
        print("\(input): not a valid age")
    }
}
```

```output
34: age 34
abc: not a valid age
200: not a valid age
0: age 0
```

The flag makes the "no result" case explicit, and `0` is now a perfectly good age.

Both tools share a weakness: **nothing forces the caller to check**. A caller can use `-1` as a position, or read `result.age` without looking at `isValid`, and the compiler won't say a word. Swift's real answer is the **optional**, a type that holds either a value or nothing and makes you check before you use it. You've already met one: `Int(text)` returns an optional, which is why you needed `?? -1`. Module 8 covers optionals properly; after that, sentinels and flags like these should mostly disappear from your code.

## Common mistakes

> [!error] error: 'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope
> The `else` block of a `guard` has to leave the function. Printing a message isn't enough: add `return` (with a value, if the function has a return type). Swift 6.3:

```swift no-compile 'guard' body must not fall through
func half(_ n: Int) -> Int {
    guard n >= 0 else {
        print("Negative input")
    }
    return n / 2
}
```

> [!error] Code after return never runs
> Lines after a `return` in the same block are dead code. If you meant them to run, they have to go before the `return`.

> [!error] Using a sentinel that can be a real answer
> Returning `0` for "invalid" from a function where 0 is a valid result, or `-1` from one that can return negative numbers, hides errors. Pick a value that's impossible as a result, or use a flag.

> [!error] Assigning a swap in two steps
> `a = b` followed by `b = a` leaves both variables with `b`'s value. Use `(a, b) = (b, a)`.

````exercise
id: m06-l03-e1
type: comprehension
prompt: |
  What does this function return for `check(-5)`?

  ```swift
  func check(_ n: Int) -> String {
      guard n != 0 else { return "zero" }
      if n > 0 {
          return "positive"
      }
      return "negative"
  }
  ```
choices:
  - text: "\"zero\""
    correct: false
    why: -5 isn't 0, so the guard's condition is true and execution continues past it.
  - text: "\"positive\""
    correct: false
    why: "-5 > 0 is false, so that return doesn't run."
  - text: "\"negative\""
    correct: true
    why: The guard passes, the if is false, and execution reaches the last return.
  - text: It doesn't compile because the function has three returns.
    correct: false
    why: A function can have as many returns as it needs. The first one reached ends it.
solution: |
  **"negative".** The guard's condition `n != 0` is true for -5, so the `else` block is skipped. The `if` is false, so its `return` doesn't run either. Execution reaches `return "negative"`. A function can have any number of `return` statements; Swift only requires that every path ends in one.
````

````exercise
id: m06-l03-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  func divide(_ dividend: Int, by divisor: Int) -> (quotient: Int, remainder: Int) {
      guard divisor != 0 else {
          return (0, -1)
      }
      return (dividend / divisor, dividend % divisor)
  }

  let result = divide(17, by: 5)
  print(result.quotient, result.remainder)

  let (q, r) = divide(9, by: 3)
  print(q + r)

  print(divide(4, by: 0))

  var x = 1
  var y = 2
  (x, y) = (y, x + y)
  print(x, y)
output: |
  3 2
  3
  (quotient: 0, remainder: -1)
  2 3
hints:
  - "17 / 5 is integer division."
  - "print shows a whole tuple with its element names."
  - "In the last swap, x + y uses the old x."
solution: |
  ```output
  3 2
  3
  (quotient: 0, remainder: -1)
  2 3
  ```

  1. 5 goes into 17 three times, with 2 left over.
  2. `9 / 3 = 3` with remainder 0; `3 + 0 = 3`.
  3. The divisor is 0, so the guard returns `(0, -1)`. `print` shows the tuple with its element names. A remainder of -1 is impossible for these inputs, which is what makes it work as a sentinel here.
  4. The right side `(y, x + y)` is `(2, 1 + 2) = (2, 3)`, computed before anything is assigned.
````

````exercise
id: m06-l03-e3
type: fill-in
prompt: |
  Complete the function so it returns the sum and the average of three scores, and the program prints `Sum 240, average 80`.
code: |
  func stats(_ a: Int, _ b: Int, _ c: Int) -> ([[1]]: Int, average: Int) {
      let sum = a + b + c
      return (sum, sum / 3)
  }
  let [[2]] = stats(80, 90, 70)
  print("Sum \(total), average \(mean)")
blanks:
  - id: "1"
    answers: ["sum"]
  - id: "2"
    answers: ["(total, mean)"]
solution: |
  ```swift
  func stats(_ a: Int, _ b: Int, _ c: Int) -> (sum: Int, average: Int) {
      let sum = a + b + c
      return (sum, sum / 3)
  }
  let (total, mean) = stats(80, 90, 70)
  print("Sum \(total), average \(mean)")
  ```

  ```output
  Sum 240, average 80
  ```

  The first blank names the tuple's first element. Any valid name compiles, but `sum` matches the second element's style. The second blank destructures the tuple into two constants, `total` and `mean`, which is what the `print` uses. Destructuring names don't have to match the tuple's element names.
````

````exercise
id: m06-l03-e4
type: refactor
prompt: |
  This function works, but its real calculation is buried three levels deep. Rewrite it with `guard` statements at the top so the main calculation sits at the left margin. The results must stay the same.
code: |
  func ticketPrice(age: Int, isMember: Bool) -> Int {
      if age >= 0 {
          if age <= 120 {
              if age < 12 {
                  return 5
              } else {
                  if isMember {
                      return 8
                  } else {
                      return 12
                  }
              }
          } else {
              return -1
          }
      } else {
          return -1
      }
  }
rubric:
  - Invalid ages are rejected with guard at the top, returning -1.
  - After the guards there's no nesting deeper than one if.
  - The function returns the same values as the original for every input.
  - I checked it with at least a child, a member, a non-member and an invalid age.
solution: |
  ```swift
  func ticketPrice(age: Int, isMember: Bool) -> Int {
      guard age >= 0 && age <= 120 else { return -1 }

      if age < 12 {
          return 5
      }
      return isMember ? 8 : 12
  }

  print(ticketPrice(age: 8, isMember: false))
  print(ticketPrice(age: 30, isMember: true))
  print(ticketPrice(age: 30, isMember: false))
  print(ticketPrice(age: -3, isMember: true))
  ```

  ```output
  5
  8
  12
  -1
  ```

  The two outer `if`s only existed to reject bad ages, so they collapse into one guard. After it, an early `return` for children removes the `else`, and the member decision fits in a ternary. Since a ticket can never cost -1, -1 works as a sentinel for "invalid age". In Module 8 you'd return an optional instead.
````

````exercise
id: m06-l03-e5
type: solve
prompt: |
  Write a function `countDigits(in text: String)` that walks a piece of text character by character and returns **two** values in a tuple with named elements: how many characters are digits and how many aren't. Then print the result for `"Room 101B"` like this:

  ```output
  Digits: 3, other: 6
  ```

  A character is a digit if it's between `"0"` and `"9"`: `letter >= "0" && letter <= "9"` works for that.
starter: |
  func countDigits(in text: String) -> (digits: Int, other: Int) {
      // your code
  }
hints:
  - "for character in text walks the String one character at a time."
  - Keep two counters as var and return them together at the end.
  - The space counts as "other".
rubric:
  - The return type is a tuple with two named elements.
  - The function doesn't print; the caller does.
  - The output line matches exactly.
  - I read the result by name or by destructuring, not by position.
solution: |
  ```swift
  func countDigits(in text: String) -> (digits: Int, other: Int) {
      var digits = 0
      var other = 0
      for character in text {
          if character >= "0" && character <= "9" {
              digits += 1
          } else {
              other += 1
          }
      }
      return (digits, other)
  }

  let counts = countDigits(in: "Room 101B")
  print("Digits: \(counts.digits), other: \(counts.other)")
  ```

  ```output
  Digits: 3, other: 6
  ```

  "Room 101B" has 9 characters: `1`, `0`, `1` are digits; `R`, `o`, `o`, `m`, the space and `B` aren't. Both counters come out of the same pass over the text, which is exactly when a tuple is the right return type. The comparison works because Swift compares characters by their Unicode order, where `"0"` to `"9"` are consecutive.
````

````exercise
id: m06-l03-e6
type: explain
prompt: |
  A teammate wrote this function to find the position of the first negative temperature in a week of readings, and uses -1 to mean "none". Explain why -1 is a bad sentinel **here** but was fine in `positionOfFirstVowel`, and propose a fix with the tools from this lesson.
code: |
  func firstNegative(_ a: Int, _ b: Int, _ c: Int) -> Int {
      if a < 0 { return a }
      if b < 0 { return b }
      if c < 0 { return c }
      return -1
  }
rubric:
  - I noticed that this function returns the temperature itself, not a position.
  - I explained that -1 can be a real reading, so the caller can't tell "found -1" from "none".
  - I proposed a tuple with a Bool flag (or a sentinel that's impossible as a reading).
  - I mentioned that optionals in Module 8 are the proper solution.
solution: |
  The function returns the **temperature**, not its position, and -1 is a perfectly possible temperature. `firstNegative(5, -1, 3)` and `firstNegative(5, 6, 7)` both return -1: one means "found -1 degrees", the other means "nothing found". The caller can't tell them apart.

  In `positionOfFirstVowel`, -1 worked because a position can never be negative: the sentinel was impossible as a real answer.

  A fix with a flag:

  ```swift
  func firstNegative(_ a: Int, _ b: Int, _ c: Int) -> (found: Bool, value: Int) {
      if a < 0 { return (true, a) }
      if b < 0 { return (true, b) }
      if c < 0 { return (true, c) }
      return (false, 0)
  }

  print(firstNegative(5, -1, 3))
  print(firstNegative(5, 6, 7))
  ```

  ```output
  (found: true, value: -1)
  (found: false, value: 0)
  ```

  The caller still has to remember to check `found`. With an optional return type (Module 8), the compiler makes them check.
````

## Summary

- A tuple groups values: `(min: 2, max: 9)`. Read it by name (`.min`), by position (`.0`) or by destructuring (`let (low, high) = …`).
- A function that returns a tuple returns several related values from one calculation.
- `(a, b) = (b, a)` swaps two variables: the right side is built before anything is assigned.
- `return` ends the function at once. A function can have several; every path must reach one.
- `guard … else { return }` at the top of a function rejects bad input and keeps the real work unindented.
- Until optionals (Module 8), "no result" is a sentinel that can't be a real answer, or a `Bool` flag in a tuple. Neither forces the caller to check.
