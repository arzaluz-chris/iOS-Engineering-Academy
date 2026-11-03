---
id: m05-l06
title: "guard and validating input"
description: You use guard to reject bad values up front and keep the main path of your code flat, you validate text input before you trust it, and you finish the module with a program that turns a messy list of raw inputs into clean scores and a summary.
module: m05
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l05]
objectives:
  - Write guard statements whose else block always exits the current scope.
  - Use guard with continue and break to reject bad values inside a loop.
  - Explain when guard reads better than if, and where guard is used most (the top of a function, next module).
  - Validate text input in two steps, conversion with Int(text) ?? fallback and a range check, and know the limits of a fallback value.
  - Write a complete program that processes raw inputs, rejects the invalid ones and summarizes the rest.
  - Recognize the common loop mistakes from this module in code you read.
terms:
  - term: guard
    definition: "A statement that checks a condition and, if it's false, runs its else block, which must leave the current scope (with continue, break, return or throw). After the guard, the condition is known to be true."
  - term: Early exit
    definition: Leaving a loop pass, a loop or a function as soon as you know the rest of the work doesn't apply, instead of wrapping that work in more and more ifs.
  - term: Happy path
    definition: The main line of a piece of code, what it does when every value is valid. With guard it stays unindented, at the bottom.
  - term: Input validation
    definition: Checking that a value coming from outside the program (typed, read from a file, received from a server) has the right type and is within the allowed range before using it.
  - term: Fallback value
    definition: The value used when a conversion fails, like the -1 in Int(text) ?? -1. It must be a value the rest of the program can tell apart from real input.
  - term: Sentinel
    definition: A special value that marks something other than normal data, like the text "end" marking the end of a list of inputs.
mastery:
  - Rewrite a loop body that starts with if !condition { continue } as a guard, and the other way around.
  - Fix the "'guard' body must not fall through" error.
  - Predict which raw strings Int(…) accepts, including " 42", "+42", "4.0" and "".
  - Choose a fallback value for ?? that the following range check will reject.
  - Process a list of raw text inputs into valid values, a count of rejected ones and a correct average, without dividing by zero.
resources: [swift-book-control-flow, swift-book-basics, swift-book-basic-operators]
cards:
  - id: m05-l06-c1
    front: What must the else block of a guard do?
    back: "Leave the current scope: continue or break inside a loop, return inside a function, or throw. If it can fall through, the code doesn't compile."
  - id: m05-l06-c2
    front: "How is `guard x > 0 else { continue }` different from `if x <= 0 { continue }`?"
    back: "They behave the same. guard states the condition you want to be true, the compiler guarantees the else exits, and after the guard the reader knows x > 0."
  - id: m05-l06-c3
    front: "What do `Int(\" 42\")`, `Int(\"+42\")` and `Int(\"4.0\")` produce?"
    back: "nil, 42 and nil. Int(…) rejects surrounding spaces and decimals, and accepts a leading + or -."
  - id: m05-l06-c4
    front: Why is `Int(text) ?? -1` a reasonable conversion for a score from 0 to 100?
    back: Because -1 is outside the valid range, so the range check that follows rejects failed conversions and real out-of-range values alike.
  - id: m05-l06-c5
    front: What two steps does validating a typed number take?
    back: First convert the text to a number (it may not be one), then check that the number is in the allowed range. Only then use it.
---

## The idea in one sentence

`guard` says "this must be true to continue", and if it isn't, it forces you to leave.

You've already written this shape twice: the else-if chain that rejects the bad cases first, and the `continue` at the top of a loop body. `guard` is the statement built for it.

## guard

**Plain definition:** "Make sure this is true. Otherwise, get out."

**Precise definition:** `guard condition else { … }` evaluates a `Bool` condition. If it's `true`, execution continues after the guard. If it's `false`, the `else` block runs, and that block **must** leave the current scope. Inside a loop, that means `continue` or `break`.

```swift
for score in [88, -5, 92, 140, 75] {
    guard score >= 0 && score <= 100 else {
        print("Ignoring invalid score \(score)")
        continue
    }
    print("Recorded \(score)")
}
```

```output
Recorded 88
Ignoring invalid score -5
Recorded 92
Ignoring invalid score 140
Recorded 75
```

Line by line:

1. The loop takes each score.
2. `guard` states what a valid score looks like: from 0 to 100.
3. For -5 the condition is false, so the `else` block runs: it prints a message and `continue` moves on to the next score.
4. For 88 the condition is true. The `else` is skipped and `print("Recorded …")` runs.

Everything after the guard can assume the score is valid. That's the point: the check happens **once**, at the top, and the rest of the body doesn't need to think about it.

### The else block must exit

If the `else` block could finish without leaving, execution would fall into code that assumes the condition is true. Swift won't allow it:

```swift no-compile 'guard' body must not fall through
for score in [88, -5] {
    guard score >= 0 else {
        print("Negative score")
    }
    print("Recorded \(score)")
}
```

Swift 6.3 says `error: 'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope`. Inside a loop, `continue` or `break` also count as leaving. `return` and `throw` are the ways to leave a function, which come next.

`break` in a guard ends the whole loop. That's how you stop at a sentinel, a special value that means "no more data":

```swift
var total = 0
for entry in ["5", "8", "end", "3"] {
    guard entry != "end" else {
        print("End marker reached")
        break
    }
    total += Int(entry) ?? 0
}
print("Total: \(total)")
```

```output
End marker reached
Total: 13
```

The `"3"` after the marker is never read.

## guard or if?

These two loops behave the same:

```swift
for temperature in [21, -80, 18] {
    if temperature < -50 || temperature > 60 {
        continue
    }
    print("Reading: \(temperature)")
}
for temperature in [21, -80, 18] {
    guard temperature >= -50 && temperature <= 60 else {
        continue
    }
    print("Reading: \(temperature)")
}
```

```output
Reading: 21
Reading: 18
Reading: 21
Reading: 18
```

The differences are in what they tell the reader:

- `guard` states the condition you **want**. The `if` version states the negation, and you saw in Module 4 how easy it is to get De Morgan wrong when you negate a compound condition.
- With `guard`, the compiler **guarantees** the bad case exits. With `if`, forgetting the `continue` compiles fine and lets the bad value through.
- Several guards in a row read like a checklist, and the happy path stays at the bottom with no extra indentation.

Use `guard` for preconditions: "if this isn't true, this pass (or this function) has nothing to do". Use `if` when both outcomes are normal work, like choosing a shipping price.

> [!note]
> `guard` is most at home at the **top of a function**, where its `else` block uses `return` to leave the function early. You'll write functions in Module 6, and from then on most of your guards will look like `guard amount > 0 else { return }`. In Module 8, `guard let` will also unwrap optionals. The shape you're learning here is the same.

## Validating input

Input is any value that comes from outside your program: typed by a person, read from a file, received from a server. Your code doesn't control it, so it can't trust it. Validating a typed number takes two steps:

1. **Convert** the text to a number. It may not be a number at all.
2. **Check the range.** A number can still be invalid: an age of -3 or 400.

### Step 1: converting

You met `Int(text) ?? fallback` in Module 4. `Int(…)` is strict about what it accepts:

```swift
print(Int("42") ?? -1)
print(Int("+42") ?? -1)
print(Int("-5") ?? -1)
print(Int(" 42") ?? -1)
print(Int("42 ") ?? -1)
print(Int("4.0") ?? -1)
print(Int("") ?? -1)
print(Int("forty") ?? -1)
```

```output
42
42
-5
-1
-1
-1
-1
-1
```

A leading `+` or `-` is fine. A space before or after, a decimal point, empty text and words all fail, and `??` gives the fallback. Real input often has stray spaces, so a real app trims them before converting; you'll learn how when you work with text in more depth.

### Step 2: checking the range

```swift
let ageText = "34"
let age = Int(ageText) ?? -1
if age >= 0 && age <= 120 {
    print("Age accepted: \(age)")
} else {
    print("'\(ageText)' is not a valid age")
}
```

```output
Age accepted: 34
```

### Choosing the fallback

The fallback, -1 here, was chosen on purpose: it's **outside** the valid range, so the range check rejects it. A failed conversion and an out-of-range number both end up in the `else`. Compare a fallback of 0:

```swift
let ageText = "thirty"
let age = Int(ageText) ?? 0
if age >= 0 && age <= 120 {
    print("Age accepted: \(age)")
} else {
    print("'\(ageText)' is not a valid age")
}
```

```output
Age accepted: 0
```

`"thirty"` became a newborn. A fallback must be a value the next check can tell apart from real data. When **every** number could be valid input, no fallback is safe, and you need the tools for optionals in Module 8, which let you ask "did the conversion work?" directly.

> [!note]
> `readLine()`, which you saw in the previous lesson, reads a typed line in a command-line program. The lessons simulate input with string constants and lists of strings so the examples can be run and checked. The validation is identical either way: the text arrives, you convert it, you check it.

## A complete program: processing raw scores

This program receives a list of scores as raw text, the way they'd arrive from a form or a file. It must:

- stop at the `"end"` marker and ignore anything after it;
- reject anything that isn't a whole number from 0 to 100, and say so;
- print each accepted score with its letter grade;
- print a summary with the count, the average, the highest and the lowest score, without dividing by zero.

```swift
let rawScores = ["87", "abc", "105", "", "92", "-3", "70", "100", "end", "55"]

var validCount = 0
var rejectedCount = 0
var total = 0
var highest = Int.min
var lowest = Int.max

for raw in rawScores {
    guard raw != "end" else {
        break
    }
    let score = Int(raw) ?? -1
    guard score >= 0 && score <= 100 else {
        print("Rejected '\(raw)': not a whole number from 0 to 100")
        rejectedCount += 1
        continue
    }

    let grade: String
    switch score {
    case 90...100:
        grade = "A"
    case 80..<90:
        grade = "B"
    case 70..<80:
        grade = "C"
    default:
        grade = "F"
    }
    print("Accepted \(score) (\(grade))")

    validCount += 1
    total += score
    if score > highest {
        highest = score
    }
    if score < lowest {
        lowest = score
    }
}

print("Valid: \(validCount), rejected: \(rejectedCount)")
if validCount == 0 {
    print("No valid scores to summarize")
} else {
    let average = Double(total) / Double(validCount)
    print("Average: \(average)")
    print("Highest: \(highest), lowest: \(lowest)")
}
```

```output
Accepted 87 (B)
Rejected 'abc': not a whole number from 0 to 100
Rejected '105': not a whole number from 0 to 100
Rejected '': not a whole number from 0 to 100
Accepted 92 (A)
Rejected '-3': not a whole number from 0 to 100
Accepted 70 (C)
Accepted 100 (A)
Valid: 4, rejected: 4
Average: 87.25
Highest: 100, lowest: 70
```

Every piece of this module is in there:

1. **Accumulators** declared before the loop: two counts, a total, and a maximum and minimum that start at `Int.min` and `Int.max` so any real score beats them.
2. A **guard with break** stops at the sentinel. `"55"` is never read.
3. **Conversion with a fallback** outside the valid range, then a **guard with continue** for the range check. The rejected count goes up before the `continue`, because nothing after it runs for that pass.
4. A **switch with ranges** for the grade. Because the guard already guaranteed 0...100, `default` only receives 0 to 69.
5. An **if-else** after the loop protects the division: with no valid scores, `total / validCount` would divide by zero. That's the empty-input edge case from Module 2.
6. The average is computed in `Double` so 349 / 4 gives 87.25, not 87.

Try changing the input to `["abc", "end"]` and check the program says there's nothing to summarize instead of crashing.

## Common loop mistakes

These are the mistakes this module has warned you about, in one place. When a loop misbehaves, go down this list.

| Mistake | What you see | Fix |
| --- | --- | --- |
| `...` where you meant `..<`, or the other way around | One pass too many or too few | Count passes: b − a + 1 for `...`, b − a for `..<` |
| A closed range that can go backward: `1...count` with count 0 | `Fatal error: Range requires lowerBound <= upperBound` | `0..<count`, or check the count first |
| No update in a `while`, or an update in the wrong direction | The program never finishes | Point at the line that moves toward the exit |
| `!=` against a value the loop steps over | The program never finishes | Use `<`, `<=`, `>` or `>=` |
| Accumulator declared inside the loop | Wrong result, or `cannot find in scope` after the loop | Declare it before the loop |
| A flag not reset for each outer pass | Correct for the first item, wrong afterward | Declare the flag inside the outer loop |
| `break` inside a `switch` inside a loop | The loop keeps going | Label the loop: `break label` |
| `continue` before the update in a `while` | The program never finishes | Update first, then decide whether to skip |
| Order of checks in a chain or switch | A branch that never runs | Most specific first; thresholds in order |
| Using a value before validating it | Wrong results from bad input, or a crash | Convert, check the range, then use |

One more, which brings back Module 4's warning about decimals:

```swift
var level = 0.0
var steps = 0
while level != 1.0 && steps < 20 {
    level += 0.1
    steps += 1
}
print("Steps: \(steps), level: \(level)")
```

```output
Steps: 20, level: 2.0000000000000004
```

Ten steps of 0.1 don't add up to exactly 1.0 in `Double`, so `level != 1.0` stays true and only the safety cap stops the loop. A condition like `level < 1.0` wouldn't hang, though it may still run one step more than you expect. When you need an exact number of steps, loop over integers and compute the decimal from them.

## Common mistakes

> [!error] error: 'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope
> The `else` block of a guard has to leave. Inside a loop, end it with `continue` or `break`.

> [!error] Writing the guard condition backward
> `guard score < 0 else { continue }` skips the **valid** scores. A guard states what must be true to go on: `guard score >= 0 else { continue }`.

> [!error] A fallback that looks like valid data
> `Int(text) ?? 0` turns "thirty" into an age of 0. Pick a fallback the range check will reject.

> [!error] Trusting that "42 " is a number
> `Int(…)` rejects spaces around the digits. Real input needs trimming first.

> [!error] Updating a counter after continue
> Once `continue` runs, the rest of the pass is skipped. Count the rejection **before** the `continue`.

> [!error] Dividing by the count without checking it
> An average of zero values is a division by zero. Check the count first.

````exercise
id: m05-l06-e1
type: comprehension
prompt: |
  Which of these compiles inside a `for` loop?
choices:
  - text: "`guard value > 0 else { print(\"skip\") }`"
    correct: false
    why: The else block doesn't leave the scope, so Swift rejects it.
  - text: "`guard value > 0 else { continue }`"
    correct: true
    why: continue leaves the current pass, which satisfies the rule.
  - text: "`guard value > 0 { continue }`"
    correct: false
    why: The else keyword is required.
  - text: "`guard value > 0 else continue`"
    correct: false
    why: The braces are required, just as with if.
solution: |
  **`guard value > 0 else { continue }`.** A guard needs the `else` keyword, braces, and a block that leaves the current scope. Inside a loop, `continue` and `break` do that.
````

````exercise
id: m05-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  var accepted = 0
  var rejected = 0
  for text in ["12", " 7", "x", "-4", "30", "stop", "9"] {
      guard text != "stop" else {
          break
      }
      let value = Int(text) ?? -1
      guard value >= 0 else {
          rejected += 1
          continue
      }
      accepted += value
  }
  print(accepted, rejected)
output: |
  42 3
hints:
  - "Int(\" 7\") fails because of the space."
  - "\"-4\" converts fine. Does it pass the second guard?"
  - Nothing after "stop" is read.
solution: |
  ```output
  42 3
  ```

  - `"12"` → 12, accepted.
  - `" 7"` → the space makes the conversion fail, so -1: rejected.
  - `"x"` → -1: rejected.
  - `"-4"` → -4, a valid conversion but negative: rejected.
  - `"30"` → accepted. 12 + 30 = 42.
  - `"stop"` → break. `"9"` is never read.

  Three rejections, for three different reasons, all caught by the same guard.
````

````exercise
id: m05-l06-e3
type: fill-in
prompt: |
  Complete the loop so it only prints the even numbers from the list, using a guard.
code: |
  for number in [3, 8, 11, 14] {
      [[1]] number % 2 == 0 [[2]] {
          [[3]]
      }
      print(number)
  }
blanks:
  - id: "1"
    answers: ["guard"]
  - id: "2"
    answers: ["else"]
  - id: "3"
    answers: ["continue"]
solution: |
  ```swift
  for number in [3, 8, 11, 14] {
      guard number % 2 == 0 else {
          continue
      }
      print(number)
  }
  ```

  ```output
  8
  14
  ```

  The guard states the condition for printing: the number is even. Odd numbers go into the `else` and `continue` skips the `print`. `break` would have stopped the whole loop at 3 and printed nothing.
````

````exercise
id: m05-l06-e4
type: find-errors
prompt: |
  This program should add up the valid ages (0 to 120) from a list of typed values and count the invalid ones. Pick out the real problems.
code: |
  var total = 0
  var invalid = 0
  for text in ["25", "abc", "40", "300"] {
      let age = Int(text) ?? 0
      guard age < 0 || age > 120 else {
          invalid += 1
          continue
      }
      total += age
  }
  print(total, invalid)
choices:
  - text: The guard condition is backward. It describes an invalid age, so valid ages are the ones that get skipped.
    correct: true
    why: A guard states what must be true to continue.
  - text: The fallback 0 is a valid age, so "abc" would be accepted as 0.
    correct: true
    why: A fallback must be something the range check rejects, like -1.
  - text: The guard's else block doesn't exit.
    correct: false
    why: It ends with continue, which leaves the current pass.
  - text: "`invalid += 1` never runs because it's before the continue."
    correct: false
    why: Statements before continue run normally. Only what comes after it is skipped.
rubric:
  - The guard states the valid range, age >= 0 && age <= 120.
  - The fallback is outside the range, like -1.
  - The program prints 65 2.
solution: |
  ```swift
  var total = 0
  var invalid = 0
  for text in ["25", "abc", "40", "300"] {
      let age = Int(text) ?? -1
      guard age >= 0 && age <= 120 else {
          invalid += 1
          continue
      }
      total += age
  }
  print(total, invalid)
  ```

  ```output
  65 2
  ```

  Two bugs, and they partly hide each other: with the backward guard, "abc" (converted to 0) counted as invalid for the wrong reason. Fixing only the guard would make "abc" a valid age of 0. Both need fixing.
````

````exercise
id: m05-l06-e5
type: refactor
prompt: Rewrite the loop body with guards so the happy path isn't nested. It must print the same thing.
code: |
  for text in ["5", "x", "0", "12"] {
      let quantity = Int(text) ?? -1
      if quantity >= 0 {
          if quantity != 0 {
              print("Ordering \(quantity)")
          } else {
              print("Nothing to order")
          }
      } else {
          print("Invalid quantity '\(text)'")
      }
  }
rubric:
  - Each invalid case is rejected by its own guard with continue.
  - The print for a valid order is at the bottom, not nested.
  - The output is the same as the original for all four inputs.
solution: |
  ```swift
  for text in ["5", "x", "0", "12"] {
      let quantity = Int(text) ?? -1
      guard quantity >= 0 else {
          print("Invalid quantity '\(text)'")
          continue
      }
      guard quantity != 0 else {
          print("Nothing to order")
          continue
      }
      print("Ordering \(quantity)")
  }
  ```

  ```output
  Ordering 5
  Invalid quantity 'x'
  Nothing to order
  Ordering 12
  ```

  Each guard handles one problem and leaves. By the last line, both checks have passed, and the code says so by its position. In the original, the reader had to match the inner `else` and the outer `else` to their `if`s to know which message belongs to which case.
````

````exercise
id: m05-l06-e6
type: solve
prompt: |
  A weather station sends temperature readings as text. Valid readings are whole numbers from -50 to 60. Write a program that starts with the list below and prints:

  ```output
  Rejected: '', '999', 'n/a'
  Valid readings: 4
  Average: 13.5
  ```

  The rejected readings must be printed on one line, in order, each in single quotes, separated by comma and space. The average uses `Double`. If no reading is valid, it should print `No valid readings` instead of the last two lines.
starter: |
  let readings = ["12", "", "18", "999", "-3", "n/a", "27"]
hints:
  - Accumulate the valid count and the total. Build the rejected text as a String accumulator.
  - "The fencepost problem: add \", \" before each rejected item except the first. Check whether the String is still empty."
  - "`text == \"\"` checks whether a String is empty."
rubric:
  - The output matches exactly.
  - Invalid readings are rejected with a guard and continue.
  - The fallback for a failed conversion is outside -50...60.
  - The average is only computed when there's at least one valid reading.
solution: |
  ```swift
  let readings = ["12", "", "18", "999", "-3", "n/a", "27"]
  var validCount = 0
  var total = 0
  var rejectedList = ""

  for raw in readings {
      let temperature = Int(raw) ?? Int.min
      guard temperature >= -50 && temperature <= 60 else {
          if rejectedList != "" {
              rejectedList += ", "
          }
          rejectedList += "'\(raw)'"
          continue
      }
      validCount += 1
      total += temperature
  }

  print("Rejected: \(rejectedList)")
  if validCount == 0 {
      print("No valid readings")
  } else {
      print("Valid readings: \(validCount)")
      print("Average: \(Double(total) / Double(validCount))")
  }
  ```

  ```output
  Rejected: '', '999', 'n/a'
  Valid readings: 4
  Average: 13.5
  ```

  -1 can't be the fallback here, because -1 °C is a valid reading. `Int.min` is far below -50, so the range check rejects it. The rejected list uses the fencepost fix from the previous lesson: a separator goes **before** every item except the first, and "the list is still empty" tells you which one is first. The valid readings are 12, 18, -3 and 27: 54 / 4 = 13.5.
````

````exercise
id: m05-l06-e7
type: design
prompt: |
  You're designing the validation for a "number of guests" field in a restaurant booking form. The field is typed as text. Write, in plain words or pseudocode, every rule you'd check, in order, and what message the user sees for each failure. Then list at least five inputs you'd test.
rubric:
  - The rules convert first and check the range second.
  - I chose concrete limits (for example 1 to 12) and justified them.
  - I said what happens with surrounding spaces, decimals and empty text.
  - My fallback for a failed conversion can't be confused with a valid number of guests.
  - My test inputs include both sides of each boundary and at least one non-number.
solution: |
  One reasonable design:

  1. **Empty text** → "Enter the number of guests." Checked first so the user gets a specific message.
  2. **Conversion** with `Int(text) ?? 0`. Zero is safe as a fallback here because zero guests isn't a valid booking. Failure → "Enter a whole number, like 4." (Trim spaces first in a real app, so " 4" works.)
  3. **Range 1...12**. Below 1 → "At least one guest." Above 12 → "For more than 12 guests, call the restaurant." The limit comes from the restaurant's largest table; it's a business rule, so ask, don't guess.

  Tests: `""`, `"abc"`, `"2.5"`, `"0"`, `"1"`, `"12"`, `"13"`, `"-3"`, `" 4"`. The boundary pairs (0 and 1, 12 and 13) come from Module 2: test both sides of every edge.

  Notice the order: the more specific the problem, the more useful the message. A single "Invalid input" for every failure is valid code and a bad experience.
````

## Summary

- `guard condition else { … }` continues only if the condition is true. The `else` block must leave: `continue` or `break` in a loop, `return` in a function (Module 6).
- Use `guard` for preconditions. It states the condition you want, the compiler enforces the exit, and the happy path stays flat at the bottom.
- Validating a typed number is two steps: convert, then check the range. `Int(…)` rejects spaces, decimals and empty text.
- Choose a fallback for `??` that the range check rejects. When every number is valid input, you need optionals (Module 8).
- Protect averages and divisions against an empty set of valid values.
- When a loop misbehaves, go through the common loop mistakes table: boundaries, backward ranges, missing updates, `!=` limits, misplaced accumulators and flags, `break` inside `switch`, `continue` before the update.
