---
id: m05-l05
title: "break, continue and nested loops"
description: You stop a loop as soon as you have the answer, skip the passes that don't matter, put loops inside loops, and use labels to say exactly which loop a break or continue refers to. Then you hunt the off-by-one errors that loops attract.
module: m05
order: 5
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l04]
objectives:
  - Use break to leave a loop early once the answer is known.
  - Use continue to skip the rest of a pass.
  - Write nested loops and count how many times the inner body runs.
  - Label a loop and use break or continue with that label to control the outer loop.
  - Explain why break inside a switch inside a loop only leaves the switch.
  - Find and fix off-by-one errors with a trace table.
terms:
  - term: break
    definition: A statement that ends the innermost loop or switch immediately. Execution continues after its closing brace.
  - term: continue
    definition: A statement that ends the current pass of a loop and jumps to the next one. In a while loop, the condition is checked again first.
  - term: Nested loop
    definition: A loop inside the body of another loop. The inner loop runs completely on every pass of the outer loop.
  - term: Labeled statement
    definition: A loop or switch with a name in front, like outer for row in 1...3. break outer and continue outer then refer to that loop.
  - term: Off-by-one error
    definition: A bug where a loop runs one time too many or too few, or where a boundary is included when it shouldn't be, or the other way around.
  - term: Fencepost error
    definition: An off-by-one error between items and the gaps between them. Five numbers need four separators, just as a fence with four sections needs five posts.
mastery:
  - Predict the output of a loop that uses both break and continue.
  - Count the iterations of two nested loops, including when the inner range depends on the outer value.
  - Stop two nested loops at once with a labeled break.
  - Fix a loop where break was meant to leave the loop but only left a switch.
  - Print a list with separators between items and none after the last one.
resources: [swift-book-control-flow]
cards:
  - id: m05-l05-c1
    front: What's the difference between break and continue in a loop?
    back: break ends the whole loop. continue ends only the current pass and moves on to the next one.
  - id: m05-l05-c2
    front: If an outer loop runs 3 times and the inner loop runs 4 times per pass, how many times does the inner body run?
    back: "12. The inner loop runs completely on every pass of the outer loop: 3 × 4."
  - id: m05-l05-c3
    front: You write break inside a switch that's inside a for loop. What does it leave?
    back: Only the switch. The loop keeps going. To leave the loop, label it (commandLoop for …) and write break commandLoop.
  - id: m05-l05-c4
    front: How many separators do you print between 5 items?
    back: "4. It's the fencepost problem: print a separator after every item except the last."
---

## The idea in one sentence

`break` leaves a loop as soon as there's no reason to keep going, and `continue` skips straight to the next pass.

The loops you've written so far always run until their sequence or condition is done. Often you know the answer earlier, or some passes have nothing to do. These two statements handle both cases.

## break: stop as soon as you know

Find the first multiple of 7 above 50:

```swift
for number in 51...100 {
    if number % 7 == 0 {
        print("First multiple of 7 above 50: \(number)")
        break
    }
}
print("Search finished")
```

```output
First multiple of 7 above 50: 56
Search finished
```

Line by line:

1. The loop could run 50 times, from 51 to 100.
2. For 51 through 55, `number % 7 == 0` is false and nothing happens.
3. At 56 the condition is true. The message is printed.
4. `break` ends the loop **immediately**. 57 through 100 are never checked.
5. Execution continues after the loop's closing brace.

Without the `break`, the program would print 63, 70, 77 and so on, and "first" would be a lie.

A common use is a search that records whether it found something:

```swift
var hasNegative = false
for reading in [12, 7, -3, 8, -1] {
    if reading < 0 {
        hasNegative = true
        break
    }
}
print(hasNegative ? "Sensor error: negative reading" : "All readings OK")
```

```output
Sensor error: negative reading
```

Once one negative reading is found, the answer can't change, so the loop stops. The `-1` is never looked at.

### Exits in the middle: while true

Sometimes the natural place to decide whether to stop is in the **middle** of the body. Then you can write a loop with no condition of its own, `while true`, and exit it with `break`:

```swift
var value = 96
var halvings = 0
while true {
    if value % 2 != 0 {
        break
    }
    value /= 2
    halvings += 1
}
print("96 = \(value) × 2^\(halvings)")
```

```output
96 = 3 × 2^5
```

This works, but every `while true` needs a `break` you're sure will run, and here the condition could have gone at the top: `while value % 2 == 0`. Use `while true` only when the exit really can't be written as the loop's condition.

## continue: skip this pass

Add the numbers from 1 to 10, except the multiples of 3:

```swift
var total = 0
for number in 1...10 {
    if number % 3 == 0 {
        continue
    }
    total += number
}
print(total)
```

```output
37
```

When `number` is 3, 6 or 9, `continue` jumps to the next pass and `total += number` is skipped. The total is 55 − (3 + 6 + 9) = 37.

`continue` shines when the body is long and several cases should be skipped. Instead of wrapping the whole body in `if`s, you reject the bad cases at the top and keep the main work unindented. You'll see this shape again with `guard` in the next lesson.

> [!warning]
> In a `while` loop, `continue` jumps straight back to the condition. If the update line comes **after** the `continue`, it's skipped too, and the loop can get stuck on the same value forever. Put the update before any `continue`, or use `for-in`, where the next value comes automatically.

## Nested loops

A loop can go inside another loop. The **inner loop runs completely on every pass of the outer loop**:

```swift
for row in 1...3 {
    for column in 1...4 {
        let product = row * column
        let cell = product < 10 ? " \(product)" : "\(product)"
        print(cell, terminator: " ")
    }
    print()
}
```

```output
 1  2  3  4 
 2  4  6  8 
 3  6  9 12 
```

1. The outer loop takes `row = 1`.
2. The inner loop runs `column` from 1 to 4 and prints four cells on the same line.
3. The inner loop ends; `print()` ends the line.
4. The outer loop takes `row = 2` and the inner loop starts again **from 1**.

The inner body runs 3 × 4 = 12 times. That multiplication matters: two nested loops over 1,000 values each run the inner body a million times. You'll study that cost properly in the algorithms stage.

The ternary operator pads one-digit numbers with a space so the columns line up.

### When the inner range depends on the outer value

Every match between four players, each pair once:

```swift
let playerCount = 4
var matches = 0
for first in 1..<playerCount {
    for second in (first + 1)...playerCount {
        print("Player \(first) vs player \(second)")
        matches += 1
    }
}
print("\(matches) matches")
```

```output
Player 1 vs player 2
Player 1 vs player 3
Player 1 vs player 4
Player 2 vs player 3
Player 2 vs player 4
Player 3 vs player 4
6 matches
```

The inner loop starts at `first + 1`, so a player never plays themselves and each pair appears once (1 vs 2, never 2 vs 1). The inner loop gets shorter on each pass: 3, then 2, then 1 matches.

Look at the outer range: `1..<playerCount` stops at 3. If it went up to 4, the inner range would be `5...4`, which goes backward and crashes, as you saw with ranges two lessons ago.

## break and continue only affect the innermost loop

In a nested loop, `break` leaves only the loop it's directly inside:

```swift
let target = 12
for a in 1...9 {
    for b in 1...9 {
        if a * b == target {
            print("\(a) × \(b) = \(target)")
            break
        }
    }
}
```

```output
2 × 6 = 12
3 × 4 = 12
4 × 3 = 12
6 × 2 = 12
```

The goal was the **first** pair. `break` left the inner loop, but the outer loop carried on with the next `a`.

### Labeled statements

Put a name and a colon in front of a loop, and `break` or `continue` can name it:

```swift
let target = 12
search: for a in 1...9 {
    for b in 1...9 {
        if a * b == target {
            print("\(a) × \(b) = \(target)")
            break search
        }
    }
}
print("Done")
```

```output
2 × 6 = 12
Done
```

`break search` ends the loop labeled `search`, the outer one, and with it the inner one too.

`continue` with a label jumps to the next pass of the labeled loop. Here each word is checked letter by letter, and any word containing a digit is skipped as soon as the digit appears:

```swift
wordLoop: for word in ["swift", "r2d2", "code", "c3po"] {
    for character in word {
        if character >= "0" && character <= "9" {
            print("Skipping \(word)")
            continue wordLoop
        }
    }
    print("Valid name: \(word)")
}
```

```output
Valid name: swift
Skipping r2d2
Valid name: code
Skipping c3po
```

Without the label, `continue` would only move to the next **character**, and `Valid name: r2d2` would be printed after the inner loop finished.

### The trap: break inside a switch

`break` also ends a `switch`. When a `switch` is inside a loop, a `break` in one of its cases leaves the **switch**, not the loop:

```swift
for command in ["move", "move", "stop", "move"] {
    switch command {
    case "stop":
        print("Stopping")
        break
    default:
        print("Moving")
    }
}
```

```output
Moving
Moving
Stopping
Moving
```

The robot was told to stop and moved again anyway. Label the loop and break out of it by name:

```swift
commandLoop: for command in ["move", "move", "stop", "move"] {
    switch command {
    case "stop":
        print("Stopping")
        break commandLoop
    default:
        print("Moving")
    }
}
```

```output
Moving
Moving
Stopping
```

And `break` outside any loop or switch, for example to "leave" an `if`, doesn't compile:

```swift no-compile unlabeled 'break' is only allowed inside a loop or switch
let x = 1
if x > 0 {
    break
}
```

## Off-by-one errors

Loops attract one specific kind of bug: running one time too many or too few. In Module 2 you caught one with a trace table, a `While m < 15` that never printed 15. Here are the usual Swift forms:

| Symptom | Typical cause |
| --- | --- |
| The last value is missing | `..<` where you meant `...`, or `<` where you meant `<=` |
| One extra value at the end | `...` where you meant `..<`, often with counts starting at 0 |
| The first value is wrong | Starting at 0 instead of 1, or the other way around |
| An extra separator at the end | The fencepost problem |
| The value after a while loop is "one too far" | The loop ends on the first value that fails the condition |

### The fencepost problem

Print the numbers 1 to 5 separated by commas:

```swift
let last = 5
for number in 1...last {
    print(number, terminator: "")
    if number < last {
        print(", ", terminator: "")
    }
}
print()
```

```output
1, 2, 3, 4, 5
```

Five numbers need **four** commas. Printing `", "` after every number would leave a trailing comma; the `if` skips it after the last one. The name comes from fences: four sections of fence need five posts.

### Use a trace table on the boundaries

You don't need to trace every pass. Trace the **first** pass, the **last** pass, and the first value that **doesn't** get in. If those three rows are right, the middle almost always is.

## Common mistakes

> [!error] break inside a switch didn't stop the loop
> In a `switch` inside a loop, `break` only leaves the `switch`. Label the loop and use `break label`.

> [!error] error: unlabeled 'break' is only allowed inside a loop or switch, a labeled break is required to exit an if or do
> You used `break` to leave an `if`. An `if` ends at its closing brace on its own; restructure with `else` instead.

> [!error] error: 'continue' is only allowed inside a loop
> `continue` means "next pass", so it only makes sense inside a loop.

> [!error] Expecting break to leave both loops
> Unlabeled `break` and `continue` refer to the innermost loop. To control the outer one, label it.

> [!error] A stuck while loop after continue
> In a `while`, `continue` skips everything after it, including an update at the bottom of the body. Update first, then decide whether to skip.

> [!error] Off by one
> Trace the first pass, the last pass and the first value that shouldn't get in. Most boundary mistakes show up in one of those three rows.

````exercise
id: m05-l05-e1
type: comprehension
prompt: |
  What does this program print?

  ```swift
  for n in 1...6 {
      if n == 2 {
          continue
      }
      if n == 5 {
          break
      }
      print(n, terminator: " ")
  }
  print()
  ```
choices:
  - text: "`1 3 4 `"
    correct: true
    why: 2 is skipped by continue; at 5 the loop ends, so 5 and 6 are never printed.
  - text: "`1 3 4 6 `"
    correct: false
    why: That would be the output if break worked like continue. break ends the whole loop.
  - text: "`1 `"
    correct: false
    why: That would be the output if continue ended the loop. It only skips the current pass.
  - text: "`1 2 3 4 5 `"
    correct: false
    why: continue skips the print for 2, and break comes before the print for 5.
solution: |
  It prints **`1 3 4 `**. On the pass for 2, `continue` skips the `print` and moves to 3. On the pass for 5, `break` ends the loop before the `print`, so neither 5 nor 6 appears.
````

````exercise
id: m05-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  var count = 0
  for outer in 1...3 {
      for inner in 1...outer {
          count += 1
          print("\(outer)\(inner)", terminator: " ")
      }
  }
  print()
  print(count)
  var sum = 0
  for n in 1...20 {
      if n % 2 == 1 {
          continue
      }
      if sum > 20 {
          break
      }
      sum += n
  }
  print(sum)
output: |
  11 21 22 31 32 33 
  6
  30
hints:
  - The inner loop runs 1 time, then 2, then 3.
  - In the second loop, only even numbers get past the continue. When is sum checked?
solution: |
  ```output
  11 21 22 31 32 33 
  6
  30
  ```

  1. The inner range is `1...outer`, so it grows: one pair for 1, two for 2, three for 3. Six in total.
  2. Odd numbers are skipped. The evens are added: 2, 4, 6, 8, 10 make 30. On the pass for 12, `sum > 20` is true and the loop breaks before adding. The check comes **before** the addition, so the sum overshoots 20 before the loop notices.
````

````exercise
id: m05-l05-e3
type: fill-in
prompt: |
  The program looks for the first number between 1 and 10 whose square plus a number between 1 and 10 equals 50, and it must stop both loops as soon as it finds one. Complete it, naming the outer loop `finder`.
code: |
  [[1]]: for a in 1...10 {
      for b in 1...10 {
          if a * a + b == 50 {
              print("\(a)² + \(b) = 50")
              [[2]] [[3]]
          }
      }
  }
blanks:
  - id: "1"
    answers: ["finder"]
  - id: "2"
    answers: ["break"]
  - id: "3"
    answers: ["finder"]
solution: |
  ```swift
  finder: for a in 1...10 {
      for b in 1...10 {
          if a * a + b == 50 {
              print("\(a)² + \(b) = 50")
              break finder
          }
      }
  }
  ```

  ```output
  7² + 1 = 50
  ```

  Any label name would work as long as the two match. For a from 1 to 6, `a * a` is at most 36, so even with b = 10 the sum doesn't reach 50. At a = 7, 49 + 1 = 50. Without the label, `break` would only leave the inner loop and the outer loop would keep going, though here no other pair happens to match.
````

````exercise
id: m05-l05-e4
type: find-errors
prompt: |
  This program processes a list of orders. It should stop completely at the first `"cancelled"` order and print the total of the orders before it, separated by commas. Pick out the real problems.
code: |
  var total = 0
  for order in ["12", "30", "cancelled", "8"] {
      switch order {
      case "cancelled":
          print("Stopped at a cancelled order")
          break
      default:
          let amount = Int(order) ?? 0
          total += amount
          print(amount, terminator: ", ")
      }
  }
  print()
  print("Total: \(total)")
choices:
  - text: The break only leaves the switch, so the order after the cancelled one is still added.
    correct: true
    why: The total comes out as 50 instead of 42.
  - text: A comma is printed after the last amount as well.
    correct: true
    why: "It's a fencepost problem: every amount is followed by \", \"."
  - text: "`Int(order) ?? 0` doesn't compile inside a switch."
    correct: false
    why: Any statement can go inside a case. It compiles.
  - text: The default case needs a break at the end.
    correct: false
    why: Swift cases don't fall through, so no break is needed.
rubric:
  - The loop is labeled and the cancelled case uses a labeled break.
  - The total is 42.
  - No comma is printed after the last amount before the stop.
solution: |
  ```swift
  var total = 0
  var printedAny = false
  orderLoop: for order in ["12", "30", "cancelled", "8"] {
      switch order {
      case "cancelled":
          print()
          print("Stopped at a cancelled order")
          break orderLoop
      default:
          let amount = Int(order) ?? 0
          total += amount
          if printedAny {
              print(", ", terminator: "")
          }
          print(amount, terminator: "")
          printedAny = true
      }
  }
  print("Total: \(total)")
  ```

  ```output
  12, 30
  Stopped at a cancelled order
  Total: 42
  ```

  The labeled `break orderLoop` leaves the loop, not just the switch, so 8 is never added. For the commas, you can't use "is this the last one?" because the loop doesn't know where the cancellation will happen. Flip it: print the separator **before** every amount except the first. A `Bool` that records whether something was printed yet does that.
````

````exercise
id: m05-l05-e5
type: solve
prompt: |
  Print every prime number from 2 to 30 on one line, separated by spaces. A prime is a number greater than 1 that has no divisors other than 1 and itself. Use a nested loop: for each candidate, try the divisors from 2 up to (but not including) the candidate, and stop trying as soon as one divides it.
starter: |
  for candidate in 2...30 {

  }
  print()
hints:
  - "Use a Bool, like `isPrime`, that starts as true for every candidate."
  - "`candidate % divisor == 0` means divisor divides candidate."
  - "Once you find one divisor, the answer for that candidate is settled: break."
  - "For 2, the range 2..<2 is empty. That's fine: 2 is prime."
rubric:
  - It prints 2 3 5 7 11 13 17 19 23 29.
  - The isPrime flag is declared inside the outer loop, so it resets for each candidate.
  - The inner loop breaks at the first divisor.
solution: |
  ```swift
  for candidate in 2...30 {
      var isPrime = true
      for divisor in 2..<candidate {
          if candidate % divisor == 0 {
              isPrime = false
              break
          }
      }
      if isPrime {
          print(candidate, terminator: " ")
      }
  }
  print()
  ```

  ```output
  2 3 5 7 11 13 17 19 23 29 
  ```

  `isPrime` lives **inside** the outer loop on purpose: each candidate starts out presumed prime. If it were declared before the outer loop, the first non-prime (4) would set it to false forever. The inner `break` only leaves the divisor loop, which is exactly what you want here: the outer loop moves on to the next candidate. Checking divisors only up to the square root would be faster; you'll get to that kind of optimization in the algorithms stage.
````

````exercise
id: m05-l05-e6
type: explain
prompt: Without running it, say how many times `print` runs and explain how you counted.
code: |
  for hour in 0..<24 {
      for minute in stride(from: 0, to: 60, by: 15) {
          print(hour, minute)
      }
  }
rubric:
  - I counted 24 passes for the outer loop and 4 for the inner one.
  - I multiplied them and got 96.
  - I explained that the inner loop restarts on every outer pass.
solution: |
  **96 times.** The outer loop runs 24 times: `0..<24` is 24 − 0. The inner stride gives 0, 15, 30 and 45 (`to:` excludes 60): 4 values. The inner loop runs completely on every outer pass, so the total is 24 × 4 = 96, one line for every quarter hour of a day.
````

## Summary

- `break` ends the innermost loop (or switch) right away. Use it when the answer is known.
- `continue` ends the current pass and moves to the next. Use it to skip cases without nesting the rest of the body.
- In nested loops the inner loop runs completely on every outer pass. Multiply the pass counts to know how much work it is.
- A label (`search: for …`) lets `break search` and `continue search` control an outer loop. Inside a `switch` in a loop, an unlabeled `break` only leaves the `switch`.
- Off-by-one errors live on the boundaries: trace the first pass, the last pass and the first value that shouldn't get in. Five items need four separators.
