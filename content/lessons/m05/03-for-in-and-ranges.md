---
id: m05-l03
title: "for-in loops and ranges"
description: You repeat work a known number of times with for-in, over ranges, strides, lists of values and the characters of a String, and you turn the Module 2 accumulator pattern into real Swift.
module: m05
order: 3
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l02]
objectives:
  - Write for-in loops over closed and half-open ranges and say how many times each one runs.
  - Use _ when the loop doesn't need the value.
  - Count in steps and backward with stride(from:to:by:) and stride(from:through:by:).
  - Loop over a list of values and over the characters of a String.
  - Write accumulators for a sum, a product, a count and a maximum.
  - Explain why 5...1 crashes and how to write a range that can be empty safely.
terms:
  - term: Loop
    definition: A structure that runs the same block of code several times.
  - term: Iteration
    definition: One pass through the body of a loop. Also used for the process of looping as a whole.
  - term: for-in
    definition: A loop that runs its body once for each value in a sequence, like a range, a list or the characters of a String, giving each value a name.
  - term: Loop constant
    definition: The name after for, like number in for number in 1...5. It's a new let constant on each pass, holding the current value.
  - term: Half-open range
    definition: "A range written a..<b, which includes a but not b. 0..<3 is 0, 1, 2."
  - term: stride
    definition: "A standard library function that produces numbers from a start toward an end in steps of a given size. With to: it stops before the end; with through: it includes the end if a step lands on it."
  - term: Accumulator
    definition: A variable declared before a loop and updated on every pass, like a running total. Its value after the loop is the answer.
mastery:
  - Say how many times a loop over a...b, a..<b or a stride runs, without running it.
  - Write a loop that prints a countdown from 10 to 0 in steps of 2.
  - Sum, multiply, count or find the maximum of a sequence with an accumulator declared in the right place.
  - Count the characters of a String that satisfy a condition.
  - Explain why for i in 1...count crashes when count is 0, and fix it.
resources: [swift-book-control-flow, swift-book-basic-operators]
cards:
  - id: m05-l03-c1
    front: How many times do `for i in 1...5` and `for i in 0..<5` run?
    back: "Both run 5 times. a...b runs b − a + 1 times; a..<b runs b − a times."
  - id: m05-l03-c2
    front: "What does `stride(from: 10, through: 0, by: -5)` produce, and with `to:`?"
    back: "through: gives 10, 5, 0 (the end is included). to: gives 10, 5 (it stops before the end)."
  - id: m05-l03-c3
    front: Where do you declare an accumulator, and why?
    back: Before the loop. Inside the loop it would be created again, with its starting value, on every pass, and it wouldn't exist after the loop.
  - id: m05-l03-c4
    front: What happens with `for i in 5...1`?
    back: "The program crashes at run time: Range requires lowerBound <= upperBound. A closed range can't go backward. Use stride(from: 5, through: 1, by: -1)."
  - id: m05-l03-c5
    front: When do you write `for _ in`?
    back: When you need to repeat something but don't use the current value. Naming a value you never use gets a compiler warning.
---

## The idea in one sentence

`for-in` runs a block of code once for **each value** in a sequence and gives that value a name while it runs.

In Module 2 you wrote `For each x in list` in pseudocode. This is the Swift version, and it's the loop you'll write most often.

## Looping over a range

```swift
for number in 1...5 {
    print(number)
}
print("Done")
```

```output
1
2
3
4
5
Done
```

Line by line:

1. `1...5` is the closed range from the previous lesson: 1, 2, 3, 4 and 5.
2. `for number in` takes the values one at a time. On each pass, `number` is a new **constant** holding the current value.
3. The body, `print(number)`, runs once per value: five times.
4. When the range runs out, the loop ends and execution continues after the closing brace.

Each pass through the body is called an **iteration**. The trace table from Module 2 works exactly the same here: one row per iteration.

### Closed or half-open

```swift
for index in 0..<3 {
    print("Pass \(index)")
}
```

```output
Pass 0
Pass 1
Pass 2
```

`0..<3` stops **before** 3. Counting from 0 with `..<` is very common, because in Module 7 you'll see that positions in a list start at 0, and a list with 3 elements has positions 0, 1 and 2.

To know how many times a loop runs without running it:

- `a...b` runs **b − a + 1** times. `1...5` runs 5 times.
- `a..<b` runs **b − a** times. `0..<3` runs 3 times.

### When you don't need the value: _

Sometimes you only want to repeat something:

```swift
for _ in 1...3 {
    print("Hip hip hooray!")
}
```

```output
Hip hip hooray!
Hip hip hooray!
Hip hip hooray!
```

The underscore says "I don't need a name for this". If you write a name and never use it, the compiler warns you:

```swift warning immutable value 'i' was never used
for i in 1...2 {
    print("Hello")
}
```

### The loop constant can't be changed

The name after `for` is a `let`, and a new one each pass. You can't modify it:

```swift no-compile left side of mutating operator isn't mutable: 'number' is a 'let' constant
for number in 1...3 {
    number += 1
    print(number)
}
```

If you want to skip values, change the sequence (with `stride`, below), not the loop constant.

## Counting in steps: stride

`stride` produces numbers from a start toward an end, in steps of whatever size you give it:

```swift
for minute in stride(from: 0, to: 60, by: 15) {
    print(minute, terminator: " ")
}
print()
for minute in stride(from: 0, through: 60, by: 15) {
    print(minute, terminator: " ")
}
print()
for countdown in stride(from: 10, through: 0, by: -2) {
    print(countdown, terminator: " ")
}
print()
```

```output
0 15 30 45 
0 15 30 45 60 
10 8 6 4 2 0 
```

- `to:` stops **before** the end, like `..<`. 60 isn't printed.
- `through:` **includes** the end, like `...`, if a step lands exactly on it.
- A negative step counts **down**. This is how you write a countdown.
- `print()` with nothing inside just ends the line, since the loops used `terminator: " "`.

A step that doesn't land on the end simply stops before it: `stride(from: 0, through: 10, by: 3)` gives 0, 3, 6, 9. `stride` also works with decimals: `stride(from: 0.0, through: 1.0, by: 0.25)` gives 0.0, 0.25, 0.5, 0.75 and 1.0.

## Empty ranges and backward ranges

A half-open range whose two ends are equal is **empty**, and a loop over it runs zero times:

```swift
for number in 3..<3 {
    print(number)
}
print("The loop ran zero times")
```

```output
The loop ran zero times
```

A closed range that goes **backward** is different. `5...1` isn't an empty range; it's not allowed at all, and the program stops when it tries to build it:

```swift runtime-error Range requires lowerBound <= upperBound
print("Counting down")
for number in 5...1 {
    print(number)
}
```

```output
Counting down
```

Swift 6.3 reports `Fatal error: Range requires lowerBound <= upperBound` and the program crashes. Notice it compiles fine; the problem only shows up when the line runs. To count backward, use `stride(from: 5, through: 1, by: -1)`.

The dangerous version of this bug doesn't look backward at all:

```swift runtime-error Range requires lowerBound <= upperBound
let guestCount = 0
print("Printing \(guestCount) name tags")
for guest in 1...guestCount {
    print("Name tag \(guest)")
}
```

```output
Printing 0 name tags
```

With 3 guests this works. With 0 guests, `1...0` goes backward and the program crashes. This is exactly the "empty input" edge case from Module 2. `0..<guestCount` (numbering from 0) or `stride(from: 1, through: guestCount, by: 1)` both run zero times when the count is 0, instead of crashing.

## Looping over a list of values

`for-in` works with any sequence, not just numbers in order. A list of values written in square brackets is an **array literal**. You'll study arrays properly in Module 7; for now, you can already loop over one:

```swift
for city in ["Lima", "Bogotá", "Quito"] {
    print("Weather in \(city)")
}
```

```output
Weather in Lima
Weather in Bogotá
Weather in Quito
```

## Looping over the characters of a String

A `String` is a sequence of characters, so `for-in` walks through it one character at a time. Each one is a value of type `Character`:

```swift
let word = "education"
var vowelCount = 0
for letter in word {
    switch letter {
    case "a", "e", "i", "o", "u":
        vowelCount += 1
    default:
        break
    }
}
print("\(word) has \(vowelCount) vowels")
```

```output
education has 5 vowels
```

The `switch` from the previous lesson works on a `Character` the same way it works on a `String`. `default: break` says "for anything else, do nothing", since a case can't be empty.

## Accumulators

In Module 2 you found the **accumulator** pattern behind many problems: start with a value, then update it with every element. In Swift, the accumulator is a `var` declared **before** the loop:

```swift
var total = 0
for number in 1...4 {
    total += number
}
print(total)
```

```output
10
```

The trace table, one row per iteration:

| Iteration | number | total after |
| --- | --- | --- |
| start | — | 0 |
| 1 | 1 | 1 |
| 2 | 2 | 3 |
| 3 | 3 | 6 |
| 4 | 4 | 10 |

The starting value depends on the operation. A sum starts at 0. A product starts at **1**, because starting at 0 would make the whole product 0:

```swift
var factorial = 1
for factor in 1...5 {
    factorial *= factor
}
print("5! = \(factorial)")
```

```output
5! = 120
```

A count only adds 1 when a condition holds. A maximum starts with a value every real value beats. `Int.min` is the smallest number an `Int` can hold, so it works for any list of integers:

```swift
var hotDays = 0
var highest = Int.min
for temperature in [18, 31, 24, 33, 29] {
    if temperature > 30 {
        hotDays += 1
    }
    if temperature > highest {
        highest = temperature
    }
}
print("Days over 30: \(hotDays)")
print("Highest: \(highest)")
```

```output
Days over 30: 2
Highest: 33
```

Two accumulators updated in the same loop, each with its own rule. Both are declared before the loop, so they keep their values between iterations and still exist after it ends.

## A practical example: a savings plan

You deposit 200 every month and want to see the balance for the first six months, with a marker on every month whose balance is a multiple of 500.

```swift
let monthlyDeposit = 200
var balance = 0
for month in 1...6 {
    balance += monthlyDeposit
    let marker = balance % 500 == 0 ? " ← milestone" : ""
    print("Month \(month): \(balance)\(marker)")
}
```

```output
Month 1: 200
Month 2: 400
Month 3: 600
Month 4: 800
Month 5: 1000 ← milestone
Month 6: 1200
```

`balance` is the accumulator, declared outside. `marker` is a constant declared **inside** the loop because it belongs to one month only; it's created fresh on every pass and doesn't exist after the loop. The ternary operator from the first lesson chooses its text.

## Common mistakes

> [!error] Fatal error: Range requires lowerBound <= upperBound
> You built a closed range that goes backward, like `5...1` or `1...count` with `count` equal to 0. It compiles and crashes at run time. Count down with `stride`, and use `0..<count` when the count can be 0.

> [!error] Declaring the accumulator inside the loop
> `for n in 1...4 { var total = 0; total += n }` creates a new `total` equal to 0 on every pass, and after the loop `total` doesn't exist: `cannot find 'total' in scope`. Declare it before the loop.

> [!error] error: left side of mutating operator isn't mutable
> You tried to change the loop constant. It's a `let`. Change the sequence instead, for example with `stride`.

> [!error] Off by one with ... and ..<
> `1..<10` doesn't include 10; `0...10` runs 11 times. Count the iterations with b − a + 1 or b − a before you trust a loop.

> [!error] Expecting stride(from:to:by:) to include the end
> `to:` stops before the end. Use `through:` when the end belongs in the sequence.

````exercise
id: m05-l03-e1
type: comprehension
prompt: "Which loop prints exactly the numbers 2, 4, 6 and 8?"
choices:
  - text: "`for n in stride(from: 2, to: 8, by: 2) { print(n) }`"
    correct: false
    why: "to: stops before the end. It prints 2, 4, 6."
  - text: "`for n in stride(from: 2, through: 8, by: 2) { print(n) }`"
    correct: true
    why: "through: includes 8 because a step lands exactly on it."
  - text: "`for n in 2...8 { print(n) }`"
    correct: false
    why: "That prints every number from 2 to 8, seven of them."
  - text: "`for n in 1...4 { n *= 2; print(n) }`"
    correct: false
    why: "It doesn't compile. The loop constant is a let and can't be modified. `print(n * 2)` would have worked."
solution: |
  **`stride(from: 2, through: 8, by: 2)`**. `through:` includes the end when a step lands on it, so you get 2, 4, 6 and 8. With `to:` the 8 is left out.

  The last option has the right idea and a fatal detail: you can't assign to the loop constant. Computing a new value, `print(n * 2)`, is fine.
````

````exercise
id: m05-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  for n in 0..<3 {
      print(n, terminator: " ")
  }
  print()
  for n in stride(from: 9, through: 1, by: -4) {
      print(n, terminator: " ")
  }
  print()
  var stars = ""
  for _ in 1...4 {
      stars += "*"
  }
  print(stars)
  var count = 0
  for character in "banana" {
      if character == "a" {
          count += 1
      }
  }
  print(count)
  for n in 4..<4 {
      print("inside", n)
  }
  print("end")
output: |
  0 1 2 
  9 5 1 
  ****
  3
  end
hints:
  - "0..<3 doesn't include 3."
  - "9, then 9 − 4, then 9 − 8. Does a step land exactly on 1?"
  - "4..<4 is empty."
solution: |
  ```output
  0 1 2 
  9 5 1 
  ****
  3
  end
  ```

  1. `0..<3` is 0, 1, 2. Each one is followed by a space, and `print()` ends the line.
  2. The stride goes 9, 5, 1. The next step would be -3, past the end. 1 is included because of `through:`.
  3. `stars` is an accumulator of text: four passes, four stars.
  4. "banana" has three `a` characters.
  5. `4..<4` is empty, so `inside` is never printed. Unlike `5...1`, it doesn't crash.
````

````exercise
id: m05-l03-e3
type: prediction
lang: pseudo
prompt: This is pseudocode in the Module 2 style. Predict what it prints, then translate it to Swift.
code: |
  total ← 0
  For each price in [12, 5, 8, 3, 20]
      If price > 6 then
          total ← total + price
  Print total
output: |
  40
hints:
  - Only prices greater than 6 are added.
solution: |
  ```output
  40
  ```

  The prices greater than 6 are 12, 8 and 20, and 12 + 8 + 20 = 40.

  ```swift
  var total = 0
  for price in [12, 5, 8, 3, 20] {
      if price > 6 {
          total += price
      }
  }
  print(total)
  ```

  Each line of pseudocode has a direct translation: `total ← 0` is `var total = 0`, `For each … in` is `for … in`, and the `If` inside becomes an `if` inside the loop body.
````

````exercise
id: m05-l03-e4
type: fill-in
prompt: |
  Complete the program so it adds up the even numbers from 2 to 20, inclusive, and prints `Sum: 110`.
code: |
  var sum = [[1]]
  for even in stride(from: 2, [[2]]: 20, by: [[3]]) {
      sum += even
  }
  print("Sum: \(sum)")
blanks:
  - id: "1"
    answers: ["0"]
  - id: "2"
    answers: ["through"]
  - id: "3"
    answers: ["2"]
solution: |
  ```swift
  var sum = 0
  for even in stride(from: 2, through: 20, by: 2) {
      sum += even
  }
  print("Sum: \(sum)")
  ```

  ```output
  Sum: 110
  ```

  A sum starts at 0. `through:` is needed because 20 belongs in the sum; with `to:` you'd get 90. Stepping by 2 from 2 visits only even numbers, so the loop doesn't need an `if`.
````

````exercise
id: m05-l03-e5
type: find-errors
prompt: |
  This program should print the average of the scores for however many students took the test. With `studentCount` set to 0 it should print `No students`. Pick out the real problems.
code: |
  let studentCount = 0
  for student in 1...studentCount {
      var total = 0
      total += 80
  }
  if studentCount == 0 {
      print("No students")
  } else {
      print("Average: \(total / studentCount)")
  }
choices:
  - text: "With studentCount equal to 0, `1...studentCount` is `1...0` and the program crashes."
    correct: true
    why: A closed range can't go backward. The crash happens before the if that was meant to handle zero.
  - text: "`total` is declared inside the loop, so it restarts at 0 each pass and doesn't exist after the loop."
    correct: true
    why: "The last print can't see it: `cannot find 'total' in scope`."
  - text: "`student` is never used, so it should be `_`."
    correct: true
    why: The compiler warns about it. It's not a crash, but the warning is right.
  - text: Dividing by studentCount is always a division by zero.
    correct: false
    why: The division is in the else branch, which only runs when studentCount isn't 0.
rubric:
  - The total is declared before the loop.
  - The loop doesn't crash with 0 students (the check comes first, or the range can be empty).
  - The unused loop constant is _.
  - With 0 students it prints No students.
solution: |
  ```swift
  let studentCount = 0
  var total = 0
  for _ in 0..<studentCount {
      total += 80
  }
  if studentCount == 0 {
      print("No students")
  } else {
      print("Average: \(total / studentCount)")
  }
  ```

  ```output
  No students
  ```

  `0..<0` is empty, so the loop runs zero times instead of crashing. Moving `var total = 0` above the loop makes it an accumulator that survives every pass and is still there for the final `print`. The `if` for zero students now gets a chance to run.
````

````exercise
id: m05-l03-e6
type: solve
prompt: |
  The classic FizzBuzz. Print the numbers from 1 to 15, one per line, but:

  - for multiples of both 3 and 5, print `FizzBuzz`
  - for other multiples of 3, print `Fizz`
  - for other multiples of 5, print `Buzz`
starter: |
  for number in 1...15 {

  }
hints:
  - "A multiple of 3 is a number where number % 3 == 0."
  - Which check has to come first, and why?
rubric:
  - It prints 15 lines.
  - 3, 6, 9 and 12 print Fizz; 5 and 10 print Buzz; 15 prints FizzBuzz.
  - The FizzBuzz check comes before the separate Fizz and Buzz checks.
solution: |
  ```swift
  for number in 1...15 {
      if number % 15 == 0 {
          print("FizzBuzz")
      } else if number % 3 == 0 {
          print("Fizz")
      } else if number % 5 == 0 {
          print("Buzz")
      } else {
          print(number)
      }
  }
  ```

  ```output
  1
  2
  Fizz
  4
  Buzz
  Fizz
  7
  8
  Fizz
  Buzz
  11
  Fizz
  13
  14
  FizzBuzz
  ```

  The order is the whole exercise: 15 is a multiple of 3, so if `% 3` came first, 15 would print `Fizz`. The most specific check goes first, the same lesson as `case 404` before `case 400...499`. `number % 15 == 0` works because a multiple of both 3 and 5 is a multiple of 15; `number % 3 == 0 && number % 5 == 0` says the same thing more literally.
````

````exercise
id: m05-l03-e7
type: explain
prompt: A teammate's program prints one line per item in an order with `for line in 1...itemCount`. It worked in every test, then crashed in production. Explain what probably happened and how you'd fix it.
rubric:
  - I identified an order with 0 items as the likely cause.
  - I explained that 1...0 is a backward closed range and crashes at run time.
  - I proposed a fix, like 0..<itemCount, stride(from:through:by:), or checking for 0 first.
  - I connected it to testing the empty case.
code: |
  for line in 1...itemCount {
      print("Line \(line)")
  }
solution: |
  Almost certainly an order with **zero items**. `1...itemCount` becomes `1...0`, a closed range that goes backward, and Swift stops the program with `Range requires lowerBound <= upperBound`. It compiles fine, which is why the tests didn't catch it: none of them tried an empty order.

  Fixes: `for line in 0..<itemCount` (and print `line + 1` if you need numbering from 1), `stride(from: 1, through: itemCount, by: 1)`, or check `itemCount > 0` before the loop. The lasting fix is a test for the empty case, the first edge case on the Module 2 list.
````

## Summary

- `for name in sequence { }` runs the body once per value. The name is a new `let` on each pass; use `_` when you don't need it.
- `a...b` includes both ends and runs b − a + 1 times. `a..<b` excludes the end and runs b − a times, and it can be empty.
- `stride(from:to:by:)` excludes the end; `stride(from:through:by:)` includes it if a step lands on it. A negative step counts down.
- A backward closed range like `5...1` crashes at run time. Watch for `1...count` when count can be 0.
- `for-in` also walks through array literals and the characters of a `String`.
- Accumulators are declared before the loop: 0 for sums, 1 for products, `Int.min` as a starting maximum.
