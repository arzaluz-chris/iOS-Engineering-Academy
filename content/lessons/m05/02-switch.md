---
id: m05-l02
title: "switch: matching values and ranges"
description: You compare one value against a list of possible values and ranges with switch, learn why Swift insists that every case be covered, and use where clauses for the cases a plain value can't describe.
module: m05
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l01]
objectives:
  - Write a switch with several cases and a default.
  - Explain why a switch must be exhaustive and when default is needed.
  - Match several values in one case and match closed, half-open and one-sided ranges.
  - Add a where clause to a case and bind the matched value with let.
  - Explain why Swift has no implicit fallthrough and what the fallthrough keyword does.
  - Choose between switch and an else-if chain.
terms:
  - term: switch
    definition: A statement that compares one value against a list of patterns, top to bottom, and runs the code of the first case that matches.
  - term: case
    definition: One branch of a switch. It lists one or more patterns and the code to run when the value matches one of them.
  - term: Pattern
    definition: The thing a case compares against. It can be a single value, a range, or a binding like let n, optionally with a where clause.
  - term: Exhaustive
    definition: Covering every possible value. A Swift switch must be exhaustive, so it usually ends with default.
  - term: default
    definition: The case that matches anything not matched by an earlier case. It goes last.
  - term: where clause
    definition: An extra Bool condition attached to a case. The case only matches if the pattern matches and the condition is true.
  - term: Fallthrough
    definition: Continuing from one case into the next. Swift never does it implicitly; the fallthrough keyword asks for it explicitly.
mastery:
  - Predict which case of a switch runs for a given value, including overlapping ranges and fallthrough.
  - Fix the "switch must be exhaustive" and "must have at least one executable statement" errors.
  - Write a switch over an Int that classifies values with ranges and rejects invalid values in default.
  - Write a switch over a String with several values per case.
  - Say whether a given decision reads better as a switch or as an else-if chain.
resources: [swift-book-control-flow, swift-book-basic-operators]
cards:
  - id: m05-l02-c1
    front: Why does a switch over an Int need a default even if your cases look complete?
    back: A switch must be exhaustive. Int has billions of values and the compiler doesn't reason about whether your ranges cover all of them, so you need default.
  - id: m05-l02-c2
    front: When the value matches more than one case, which one runs?
    back: The first one, top to bottom. Only that case runs.
  - id: m05-l02-c3
    front: Does Swift fall through from one case to the next?
    back: "No. When a case's code ends, the switch ends. To continue into the next case you write fallthrough, which runs the next case's code without checking its pattern."
  - id: m05-l02-c4
    front: "What does `case let n where n % 2 == 0:` do?"
    back: "It matches any value, binds it to the constant n, and only accepts the match if the where condition is true, here if n is even."
  - id: m05-l02-c5
    front: How do you match "any number from 80 up to but not including 90" in a case?
    back: "case 80..<90: (a half-open range). 80...89 also works for integers."
---

## The idea in one sentence

`switch` takes **one** value and runs the code of the first case that matches it.

An else-if chain can ask a different question on every line. A `switch` asks the same question every time: "is the value this?". When that's your problem, `switch` says it more clearly, and the compiler checks that you didn't forget a case.

## The basic shape

```swift
let trafficLight = "yellow"
switch trafficLight {
case "green":
    print("Go")
case "yellow":
    print("Slow down")
case "red":
    print("Stop")
default:
    print("Unknown signal")
}
```

```output
Slow down
```

Line by line:

1. `trafficLight` is `"yellow"`.
2. `switch trafficLight` names the value to compare.
3. `case "green":` doesn't match, so its code is skipped.
4. `case "yellow":` matches. `Slow down` is printed.
5. When that case's code ends, **the whole switch ends**. Swift doesn't look at `"red"` or `default`.
6. `default:` would have run for any other text, like `"blue"`.

Comparisons on `String` are case-sensitive, just like `==`: `"Yellow"` with a capital Y would land in `default`.

## Every switch must be exhaustive

A Swift `switch` must handle **every possible value** of its type. A `String` can hold infinitely many values, so a switch over text without `default` doesn't compile:

```swift no-compile switch must be exhaustive
let trafficLight = "yellow"
switch trafficLight {
case "green":
    print("Go")
case "yellow":
    print("Slow down")
case "red":
    print("Stop")
}
```

The same happens with `Int`. Even when your ranges cover every integer, the compiler doesn't work that out:

```swift no-compile switch must be exhaustive
let balance = 5
switch balance {
case ...0:
    print("Nothing left")
case 1...:
    print("Still positive")
}
```

So a switch over numbers or text ends with `default`. That's a feature, not paperwork: `default` is where unexpected values go, and you decide what happens to them instead of letting them slip through silently. In Module 9 you'll meet **enumerations**, types with a fixed list of values, where a switch can list every case and skip `default`.

## Several values in one case

Separate them with commas. The case matches if the value equals any of them:

```swift
let dayNumber = 6
switch dayNumber {
case 1, 2, 3, 4, 5:
    print("Weekday")
case 6, 7:
    print("Weekend")
default:
    print("Not a day number")
}
```

```output
Weekend
```

## Ranges

A case can match a range of values. These are the range operators, which you'll also use with loops in the next lesson:

| Write | Name | Contains |
| --- | --- | --- |
| `1...5` | closed range | 1, 2, 3, 4, 5 |
| `1..<5` | half-open range | 1, 2, 3, 4 (not 5) |
| `...0` | one-sided, up to and including | 0 and everything below |
| `..<0` | one-sided, up to but not including | everything below 0 |
| `100...` | one-sided, from | 100 and everything above |

```swift
let score = 85
switch score {
case 90...100:
    print("A")
case 80..<90:
    print("B")
case 70..<80:
    print("C")
case 0..<70:
    print("F")
default:
    print("Invalid score: \(score)")
}
```

```output
B
```

Compare this with the grade chain from the previous lesson. Here each case states its full range, so the cases don't depend on each other's order, and `default` rejects -5 and 120 for free. The if version would have given 120 an A.

`80..<90` and `80...89` mean the same thing for integers. Half-open ranges make adjacent ranges easy to check: each one starts where the previous one stopped (`80..<90`, `90..<100`), so there are no gaps and no overlaps.

### When cases overlap, the first one wins

Swift doesn't complain if two cases can match the same value. It checks them in order and runs the first match:

```swift
let age = 65
switch age {
case 18...65:
    print("Adult fare")
case 65...:
    print("Senior fare")
default:
    print("Child fare")
}
```

```output
Adult fare
```

65 is in both ranges. Whether that's right depends on the rule, but it's almost always an accident. If seniors start at 65, the first range should be `18..<65`.

## where: cases a value can't describe

Sometimes the condition isn't "equal to" or "inside this range". "Even" is an example. A `where` clause adds a `Bool` condition to a case:

```swift
let number = 14
switch number {
case let n where n < 0:
    print("\(n) is negative")
case let n where n % 2 == 0:
    print("\(n) is even")
default:
    print("\(number) is odd")
}
```

```output
14 is even
```

`case let n` is a pattern that matches **any** value and binds it to a new constant `n` that only exists inside that case. The `where` clause then decides whether the match counts. Here 14 isn't negative, so the first case is rejected; it is even, so the second one runs.

A `where` clause can follow any pattern, including a value:

```swift
let a = 12
let b = 0
let operation = "/"
switch operation {
case "+":
    print(a + b)
case "-":
    print(a - b)
case "*", "x":
    print(a * b)
case "/" where b != 0:
    print(a / b)
case "/":
    print("Can't divide by zero")
default:
    print("Unknown operation: \(operation)")
}
```

```output
Can't divide by zero
```

`"/"` with `b` equal to 0 fails the `where` condition, so Swift keeps going and the next case, plain `"/"`, matches. The safe division comes first and the fallback second: the same "first match wins" rule, used on purpose.

## No implicit fallthrough

In C and JavaScript, once a case matches, execution keeps going into the cases below it until something stops it, which is why those languages need a `break` at the end of every case. Swift **doesn't** do that. Each case ends at the next `case` label, so you never write `break` there.

That also means a case can't be empty:

```swift no-compile 'case' label in a 'switch' must have at least one executable statement
let dayNumber = 6
switch dayNumber {
case 6:
case 7:
    print("Weekend")
default:
    print("Weekday")
}
```

Someone coming from C wrote that hoping 6 would fall into 7's code. In Swift you write `case 6, 7:`. If a case should do nothing on purpose, write `break` as its only statement, for example `default: break`.

When you really want to continue into the next case, there's the `fallthrough` keyword:

```swift
let accessLevel = 2
switch accessLevel {
case 3:
    print("Admin tools")
    fallthrough
case 2:
    print("Editor tools")
    fallthrough
case 1:
    print("Reader tools")
default:
    print("No access")
}
```

```output
Editor tools
Reader tools
```

Level 2 matches `case 2`, prints, and `fallthrough` jumps into `case 1`'s code **without checking its pattern**. `case 1` has no `fallthrough`, so the switch ends there. You'll rarely need `fallthrough`; know it exists so it doesn't surprise you.

## switch or if?

Use `switch` when you're comparing **one value** against fixed values or ranges. Use an else-if chain when the conditions involve **different values** or combine several with `&&` and `||`.

| Decision | Better as |
| --- | --- |
| Which planet name was typed | `switch` on the text |
| Grade from a score | `switch` with ranges |
| Free shipping if member or total ≥ 50 | `if` |
| Entry allowed if adult and has a ticket | `if` |

Both can express anything the other can. Pick the one that reads like the rule.

> [!version]
> Since Swift 5.9, `switch` can be used as an expression when each case is a single value, just like `if`: `let meaning = switch code { case 200: "OK"; case 404: "Not Found"; default: "Other" }`. It must still be exhaustive.

```swift
let code = 404
let meaning = switch code {
case 200: "OK"
case 404: "Not Found"
default: "Other"
}
print(meaning)
```

```output
Not Found
```

## Common mistakes

> [!error] error: switch must be exhaustive
> A switch over `Int` or `String` can't list every value. Add `default` and decide what unexpected values should do.

> [!error] error: 'case' label in a 'switch' must have at least one executable statement
> Swift doesn't fall through, so an empty case would do nothing. List the values together (`case 6, 7:`) or write `break` if doing nothing is intentional.

> [!error] Overlapping ranges
> `18...65` and `65...` both contain 65, and the first one wins. The compiler doesn't warn you. Use half-open ranges, `18..<65` and `65...`, so adjacent ranges meet without overlapping.

> [!error] A specific case after a general one
> `case 400..<500:` before `case 404:` means 404 never reaches its own case. Put the specific values first.

> [!error] Expecting "Yes" to match "yes"
> Matching text is case-sensitive. List both spellings or, later in the course, normalize the text before you switch on it.

````exercise
id: m05-l02-e1
type: comprehension
prompt: |
  This program doesn't compile. Why?

  ```swift
  let month = 4
  switch month {
  case 12, 1, 2:
      print("Winter")
  case 3...5:
      print("Spring")
  case 6...8:
      print("Summer")
  case 9...11:
      print("Fall")
  }
  ```
choices:
  - text: The cases are in the wrong order; 12 should come last.
    correct: false
    why: Values in a case can go in any order. The order of the cases matters only when they overlap.
  - text: "`month` is an Int, which has many more values than 1 through 12, so the switch isn't exhaustive."
    correct: true
    why: "The compiler only sees an Int. What should happen with 0 or 13? Without a default, Swift 6.3 reports `switch must be exhaustive`."
  - text: Each case needs a break at the end.
    correct: false
    why: Swift doesn't fall through, so it never needs break at the end of a case.
  - text: You can't mix single values and ranges in the same switch.
    correct: false
    why: You can mix values, ranges and where clauses freely.
solution: |
  The switch isn't **exhaustive**. You know a month is between 1 and 12, but the compiler only knows `month` is an `Int`, and an `Int` can be 0, 13 or -400. Add a `default` that handles those values, for example `default: print("Not a month")`. Now an invalid month gets a clear message instead of being ignored.
````

````exercise
id: m05-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  let level = 3
  switch level {
  case 1...3:
      print("Beginner")
  case 3...5:
      print("Intermediate")
  default:
      print("Expert")
  }
  let command = "Stop"
  switch command {
  case "start", "go":
      print("Starting")
  case "stop":
      print("Stopping")
  default:
      print("Unknown: \(command)")
  }
  let stars = 4
  switch stars {
  case 5:
      print("Perfect")
      fallthrough
  case 4:
      print("Great")
      fallthrough
  case 3:
      print("Good")
  default:
      print("Needs work")
  }
output: |
  Beginner
  Unknown: Stop
  Great
  Good
hints:
  - 3 is in both of the first two ranges.
  - Matching text is case-sensitive.
  - fallthrough enters the next case without checking it.
solution: |
  ```output
  Beginner
  Unknown: Stop
  Great
  Good
  ```

  1. 3 matches `1...3` and `3...5`. The first match wins: `Beginner`.
  2. `"Stop"` with a capital S isn't `"stop"`, so it lands in `default`.
  3. 4 matches `case 4`, which prints `Great` and falls through into `case 3`, which prints `Good`. `case 3` has no `fallthrough`, so the switch ends and `default` doesn't run.
````

````exercise
id: m05-l02-e3
type: fill-in
prompt: |
  Complete the switch that labels a temperature in degrees Celsius. Below 0 is "Freezing", 0 up to but not including 15 is "Cold", 15 up to but not including 25 is "Mild", and 25 or more is "Hot". Use one-sided ranges at both ends.
code: |
  let celsius = 15
  switch celsius {
  case [[1]]0:
      print("Freezing")
  case 0[[2]]15:
      print("Cold")
  case 15..<25:
      print("Mild")
  case 25[[3]]:
      print("Hot")
  [[4]]:
      print("Unreachable, but required")
  }
blanks:
  - id: "1"
    answers: ["..<"]
  - id: "2"
    answers: ["..<"]
  - id: "3"
    answers: ["..."]
  - id: "4"
    answers: ["default"]
solution: |
  ```swift
  let celsius = 15
  switch celsius {
  case ..<0:
      print("Freezing")
  case 0..<15:
      print("Cold")
  case 15..<25:
      print("Mild")
  case 25...:
      print("Hot")
  default:
      print("Unreachable, but required")
  }
  ```

  ```output
  Mild
  ```

  `..<0` is everything below 0. `0..<15` stops just before 15, and the next range starts exactly at 15, so 15 is "Mild". `25...` is 25 and above. The four ranges together cover every Int, but the compiler doesn't work that out, so `default` is still required.
````

````exercise
id: m05-l02-e4
type: find-errors
prompt: |
  This switch should name the type of an HTTP status code: 200 to 299 "Success", 404 "Not found", any other 400 to 499 "Client error", 500 to 599 "Server error". Pick out the real problems.
code: |
  let status = 404
  switch status {
  case 200...299:
      print("Success")
  case 400...499:
      print("Client error")
  case 404:
      print("Not found")
  case 500...599:
      print("Server error")
      break
  }
choices:
  - text: The switch has no default, so it doesn't compile.
    correct: true
    why: Over an Int, a switch needs default.
  - text: "`case 404` comes after `case 400...499`, so it can never run."
    correct: true
    why: 404 is inside 400...499 and the first match wins. The specific case has to go first.
  - text: The break at the end of the last case is required.
    correct: false
    why: "It's allowed but pointless: a Swift case ends on its own."
  - text: "`case 200...299` should be written `case 200..<299`."
    correct: false
    why: "That would exclude 299. `200...299` and `200..<300` are both correct."
rubric:
  - I added a default that handles unexpected codes.
  - 404 is checked before the 400 range.
  - I removed the unnecessary break.
  - 404 prints "Not found" and 403 prints "Client error".
solution: |
  ```swift
  let status = 404
  switch status {
  case 200...299:
      print("Success")
  case 404:
      print("Not found")
  case 400...499:
      print("Client error")
  case 500...599:
      print("Server error")
  default:
      print("Unknown status \(status)")
  }
  ```

  ```output
  Not found
  ```

  Two real problems: the missing `default` (a compile error) and the order (a logic error the compiler doesn't catch). The trailing `break` isn't wrong, just noise.
````

````exercise
id: m05-l02-e5
type: solve
prompt: |
  Write a switch that turns a 24-hour clock hour into a greeting:

  - 5 to 11: `Good morning`
  - 12 to 17: `Good afternoon`
  - 18 to 21: `Good evening`
  - 22 and 23, and 0 to 4: `Good night`
  - anything else: `Invalid hour: <hour>`

  Start with `let hour = 19`.
starter: |
  let hour = 19
hints:
  - "Night is two ranges. A case can list several patterns separated by commas: `case 22...23, 0...4:`."
  - default handles 24, 99 and negative numbers.
rubric:
  - For 19 it prints `Good evening`.
  - 5, 11, 12, 17, 18, 21, 22 and 4 land in the right case.
  - 24 and -1 print the invalid message with the hour.
  - The ranges don't overlap.
solution: |
  ```swift
  let hour = 19
  switch hour {
  case 5...11:
      print("Good morning")
  case 12...17:
      print("Good afternoon")
  case 18...21:
      print("Good evening")
  case 22...23, 0...4:
      print("Good night")
  default:
      print("Invalid hour: \(hour)")
  }
  ```

  ```output
  Good evening
  ```

  The night wraps around midnight, so it's two ranges in one case. Because each case states its exact range, the order of the cases doesn't matter here, and `default` turns any impossible hour into a clear message.
````

````exercise
id: m05-l02-e6
type: refactor
prompt: Rewrite this else-if chain as a switch. It must print the same thing for every input.
code: |
  let answer = "y"
  if answer == "y" || answer == "yes" || answer == "Y" {
      print("Confirmed")
  } else if answer == "n" || answer == "no" || answer == "N" {
      print("Cancelled")
  } else {
      print("Please answer yes or no")
  }
rubric:
  - My version uses a single switch on answer.
  - Each group of answers is one case with comma-separated values.
  - Unknown answers go to default.
solution: |
  ```swift
  let answer = "y"
  switch answer {
  case "y", "yes", "Y":
      print("Confirmed")
  case "n", "no", "N":
      print("Cancelled")
  default:
      print("Please answer yes or no")
  }
  ```

  ```output
  Confirmed
  ```

  Every condition in the original compares the **same** value, `answer`, with `==`. That's exactly what `switch` is for. The list of accepted answers is now easy to scan and to extend, and `answer ==` isn't repeated six times.
````

````exercise
id: m05-l02-e7
type: comprehension
prompt: Which of these decisions reads better as an else-if chain than as a switch?
choices:
  - text: Turning a month number into its name.
    correct: false
    why: One value compared against twelve fixed values. That's a switch.
  - text: Classifying a score into A, B, C or F.
    correct: false
    why: One value compared against ranges. A switch with ranges reads well.
  - text: Granting a discount if the customer is a student or the order is over 100.
    correct: true
    why: The condition combines two different values with ||. There's no single value to switch on.
  - text: Reacting to a command typed as text, like "start" or "stop".
    correct: false
    why: One text value against a list of commands. A switch.
solution: |
  **The discount.** `isStudent || total > 100` involves two different values joined by `||`, so there's no single value to switch on. The other three all compare one value against fixed values or ranges, which is what `switch` describes best.
````

## Summary

- `switch` compares one value against its cases, top to bottom, and runs only the first match.
- It must be exhaustive. Over `Int` and `String` that means ending with `default`, which is also where invalid values get handled.
- A case can list several values (`case 6, 7:`), ranges (`80..<90`, `...0`, `100...`) and a `where` condition. `case let n` binds the value to a name.
- Swift never falls through. A case can't be empty, and `fallthrough` continues into the next case without checking it.
- Use `switch` for one value against many options and `if` for conditions that combine several values.
