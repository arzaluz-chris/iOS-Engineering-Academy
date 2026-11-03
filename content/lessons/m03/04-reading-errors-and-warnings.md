---
id: m03-l04
title: "Reading the compiler: errors, warnings and runtime errors"
description: You learn to read a Swift compiler message piece by piece, to tell a compile error from a warning and from a runtime error, and to fix problems without guessing.
module: m03
order: 4
level: beginner
minutes: 45
prerequisites: [m03-l02, m01-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Read a compiler diagnostic and pick out the file, line, column, kind and message.
  - Tell compile errors, warnings and runtime errors apart by when they show up and what they cause.
  - Fix syntax and naming errors from the message, without changing code at random.
  - Explain why the compiler sometimes points at a different line from the one with the problem.
terms:
  - term: Diagnostic
    definition: A message the compiler produces about your code. It can be an error, a warning or a note.
  - term: Compile error
    definition: A diagnostic that stops the program from being built. Until you fix it, there's nothing to run.
  - term: Warning
    definition: A diagnostic that doesn't stop the build but flags something suspicious, such as a value that's never used.
  - term: Runtime error
    definition: A failure that happens while the program runs, with specific data. In Swift it usually stops the program with a Fatal error message.
  - term: Fix-it
    definition: An automatic correction Xcode offers alongside some diagnostics. Read it before you accept it.
  - term: Scope
    definition: The region of code where a name exists. "cannot find 'x' in scope" means that nothing called x exists at that point.
mastery:
  - Point out the file, line, column, kind and message in a one-line diagnostic.
  - Classify five given problems as compile error, warning or runtime error and justify each one.
  - Fix a program with three compile errors by reading only the messages.
  - Find the real problem when the compiler points at the next line.
resources: [swift-book-basics, xcode-overview]
cards:
  - id: m03-l04-c1
    front: "What does each part of `p.swift:2:15: error: expected ',' separator` mean?"
    back: "File p.swift, line 2, column 15, kind error, and the message: the compiler expected a separating comma at that point."
  - id: m03-l04-c2
    front: What's the difference between a compile error and a warning?
    back: An error stops the program from being built. A warning lets it build, but flags something suspicious that you almost always want to fix.
  - id: m03-l04-c3
    front: "What does `cannot find 'price' in scope` mean?"
    back: That nothing called price exists at that point in the code. It's usually a typo, a capitalization mistake or a name that hasn't been declared yet.
  - id: m03-l04-c4
    front: What does a typical runtime error look like in Swift?
    back: "The program compiles, starts running and stops with a message like \"Fatal error: Index out of range\". In Xcode, execution pauses on the line that caused it."
---

## The idea in one sentence

The compiler is your first reviewer, and it writes in a fixed format: once you can read it, half your errors take seconds to fix.

> [!note]
> The messages in this lesson are the ones the Swift 6.3 compiler produces, and the course's automated tests check that they still appear this way. Other versions may word some messages differently; you read them the same way.

## Three kinds of problems

| Kind | When it shows up | Is there a program? | Example |
| --- | --- | --- | --- |
| Compile error | When you compile | No | Unclosed quotes |
| Warning | When you compile | Yes | A value that's never used |
| Runtime error | While it runs | Yes, and it stops | Asking for item 4 of a 3-item list |

The lesson "From source code to a running program" introduced the difference between compiling and running. Here you learn to recognize each kind by its message.

## Anatomy of a diagnostic

```swift no-compile cannot find 'price' in scope
print(price)
```

Compiling this file, saved as `r7.swift`, from the terminal gives you:

```output
r7.swift:1:7: error: cannot find 'price' in scope
1 | print(price)
  |       `- error: cannot find 'price' in scope
2 |
```

Piece by piece:

1. `r7.swift` is the **file**.
2. `1` is the **line**.
3. `7` is the **column**: the character where the problem starts, counting from 1. The `p` in `price` is in column 7.
4. `error` is the **kind**. It can also be `warning` or `note`.
5. `cannot find 'price' in scope` is the **message**: nothing called `price` exists at that point.
6. The lines after it repeat the code with a marker under the exact column.

In Xcode, the same diagnostic shows up as a red icon next to the line and in the **Issue navigator** on the left. Click it and Xcode takes you to the line.

### The most common messages when you're starting out

```swift no-compile cannot find 'Print' in scope
Print("Hello")
```

Swift is case-sensitive. `Print` doesn't exist; `print` does.

```swift no-compile unterminated string literal
print("Hello)
```

The closing quote is missing. The text "swallows" the closing parenthesis.

```swift no-compile binary operator '+' cannot be applied to operands of type 'String' and 'Int'
print("Total: " + 5)
```

`+` isn't defined between text (`String`) and an integer (`Int`). In Module 4 you'll learn the right way to combine text and numbers.

### When the compiler points at the next line

```swift no-compile expected ',' separator
print("Start")
print("Middle"
print("End")
```

```output
p.swift:2:15: error: expected ',' separator
```

The problem is a missing parenthesis at the end of line 2. The compiler can't know you forgot the parenthesis: it sees that `"Middle"` is followed by something else (the `print` on line 3) and assumes a comma was missing so you could pass another value. That's why the message talks about a comma.

Rule of thumb: **the error is at the marked position or before it, never after**. If the marked line looks fine, check the end of the line before it.

### An error the compiler catches by doing the math

```swift no-compile results in an overflow
print(Int.max + 1)
```

`Int.max` is the largest integer that fits in an `Int`. Since both values are known at compile time, the compiler does the addition, sees that the result doesn't fit and reports it: `arithmetic operation '9223372036854775807 + 1' (on type 'Int') results in an overflow`. If the value were only known while the program runs, the same problem would be a runtime error.

## Warnings

```swift warning initialization of immutable value 'unused' was never used
do {
    let unused = 10
    print("Hello")
}
```

```output
Hello
```

The program compiles and runs, but the compiler warns you:

```plaintext
warning: initialization of immutable value 'unused' was never used; consider replacing with assignment to '_' or removing it
```

`let unused = 10` stores a named value (you'll study this in Module 4) that nothing uses afterward. It doesn't break anything, but it's almost always a slip: either the line isn't needed or you forgot to use the value. In Xcode, warnings are marked with a yellow triangle.

> [!tip]
> Keep your projects at **zero warnings**. If you ignore ten harmless warnings, you won't notice the eleventh one that matters.

## Runtime errors

```swift runtime-error Index out of range
let numbers = [10, 20, 30]
print("before")
print(numbers[3])
print("after")
```

```output
before
```

This program **compiles without errors**. When you run it, it prints `before` and then stops with a message like this on standard error:

```plaintext
Fatal error: Index out of range
```

The list has 3 items, at positions 0, 1 and 2 (you'll see this in the collections module). Asking for position 3 makes no sense. Swift **stops the program** instead of reading memory that doesn't belong to it, and `after` is never printed.

In Xcode, execution pauses on the offending line, highlighted in red, with the message next to it. The console shows the same `Fatal error`.

## A method for fixing compile errors

1. **Start with the first error.** One error can cause several more further down; once you fix it, the others sometimes disappear.
2. **Read the whole message**, not just the first word.
3. **Go to the exact line and column.** If they look fine, check what comes right before.
4. **Make one change and compile again.** If you change five things at once, you can't tell which one worked.
5. **Read fix-its before accepting them.** Xcode sometimes offers a correction with a *Fix* button. It's usually right about typos, but it doesn't know what you meant.

## Common mistakes

> [!error] Fixing the last error first
> Errors cascade. Always start with the first one in the list.

> [!error] Changing code at random until it compiles
> If you don't understand the message, you can't tell whether your change fixed the problem or just hid it. Read, form a hypothesis, change one thing, compile.

> [!error] Ignoring warnings
> Warnings are small bugs that haven't cost you anything yet. Fix them as soon as they appear.

> [!error] Assuming that if it compiles, it works
> A program with no errors and no warnings can still stop at runtime or, worse, give a wrong result without stopping.

````exercise
id: m03-l04-e1
type: comprehension
prompt: |
  What does the number `15` mean in this diagnostic?

  ```plaintext
  p.swift:2:15: error: expected ',' separator
  ```
choices:
  - text: The number of errors in the file.
    correct: false
    why: The format is file:line:column; it doesn't count errors.
  - text: The column where the compiler found the problem.
    correct: true
    why: The third number is the column, counting characters from 1.
  - text: The line of the error.
    correct: false
    why: The line is the second number, 2.
  - text: The error's internal code.
    correct: false
    why: The Swift compiler doesn't use code numbers in this format.
solution: |
  It's the **column**. The format is `file:line:column: kind: message`, so the problem is in `p.swift`, line 2, column 15. In Xcode you don't have to count: the diagnostic appears next to the line, and clicking it takes you to the exact position.
````

````exercise
id: m03-l04-e2
type: prediction
prompt: This program compiles without errors but has a runtime error on the third line. Write exactly what it prints **before** it stops; don't include the error message.
code: |
  print("Start")
  print(3 + 4)
  print([1, 2][5])
  print("End")
output: |
  Start
  7
hints:
  - The program runs from top to bottom until something stops it.
  - "The list [1, 2] has two items; position 5 doesn't exist."
solution: |
  ```output
  Start
  7
  ```

  The first two lines run normally. The third asks for position 5 in a two-item list: the program stops with `Fatal error: Index out of range`, and `End` is never printed. Whatever was printed before the error stays in the console, which is useful for seeing how far the program got.
````

````exercise
id: m03-l04-e3
type: find-errors
prompt: |
  This program doesn't compile. The compiler only shows one error, `expected ',' separator`, at the end of line 2. Find all the real problems in the program and write the fixed version.
code: |
  print("Shopping list")
  print("Milk"
  print("Bread")
  print(Eggs)
  Print("Total items:", 3)
choices:
  - text: "Line 2 is missing its closing parenthesis."
    correct: true
    why: "That's why the compiler complains at the end of line 2 that it expected a comma: it sees another print where it expected ) or a comma."
  - text: "On line 4, Eggs has no quotes and nothing called Eggs exists."
    correct: true
    why: "The message would be cannot find 'Eggs' in scope."
  - text: "On line 5, Print with a capital P doesn't exist."
    correct: true
    why: Swift is case-sensitive.
  - text: "Line 2 is missing a comma at the end, as the message says."
    correct: false
    why: "The message mentions a comma because the compiler sees another print where it expected more values. What's actually missing is the closing parenthesis."
rubric:
  - I added the missing parenthesis on line 2.
  - I put quotes around Eggs.
  - I changed Print to print.
  - I compiled again after each fix, starting with the first error.
solution: |
  ```swift
  print("Shopping list")
  print("Milk")
  print("Bread")
  print("Eggs")
  print("Total items:", 3)
  ```

  With Swift 6.3, the compiler reports a single error, `expected ',' separator` at the end of line 2: the parenthesis is missing. Once you fix it, the other two show up: `cannot find 'Eggs' in scope` and `cannot find 'Print' in scope`. That's why it pays to fix one at a time and compile again.
````

````exercise
id: m03-l04-e4
type: comprehension
multiple: true
prompt: Which of these situations are **runtime errors**? Select all that apply.
choices:
  - text: The program stops with "Fatal error" when it reads a position that doesn't exist in a list.
    correct: true
    why: It compiles fine and fails on specific data while running.
  - text: Xcode marks a value that's never used with a yellow triangle.
    correct: false
    why: That's a warning, found at compile time.
  - text: The compiler says "unterminated string literal".
    correct: false
    why: That's a compile error; there's no program to run.
  - text: "The program divides by a number the user typed, the user types 0 and the program stops."
    correct: true
    why: The compiler can't know what the user will type; it happens while the program runs.
solution: |
  The runtime errors are **reading a position that doesn't exist** and **dividing by a 0 that came in as data**. In both cases the program compiles, and the failure depends on values that only exist while it runs. The unclosed quotes are a compile error, and the unused value is a warning.
````

````exercise
id: m03-l04-e5
type: solve
prompt: |
  In your `Practice` project or in a single file, trigger these four diagnostics on purpose, one at a time. For each one, copy the exact message your compiler gives you and write one sentence about what it means:

  1. `cannot find '…' in scope`
  2. `unterminated string literal`
  3. An unused-value warning
  4. A `Fatal error` at runtime
starter: |
  // 1.
hints:
  - For the warning you can copy the do block example from the lesson.
  - "For the runtime error, the example with the list [10, 20, 30] works."
rubric:
  - I triggered all four diagnostics and copied the text my compiler showed.
  - My notes say which ones prevented running and which one let the program run with a warning.
  - For the runtime error, I wrote down what was printed before it stopped.
  - I explained each message in my own words.
solution: |
  One way to trigger them:

  ```swift no-compile cannot find 'greeting' in scope
  print(greeting)
  ```

  ```swift no-compile unterminated string literal
  print("Hello)
  ```

  ```swift warning initialization of immutable value 'age' was never used
  do {
      let age = 30
  }
  print("Done")
  ```

  ```swift runtime-error Index out of range
  print([10, 20, 30][3])
  ```

  1. `cannot find 'greeting' in scope`: nothing called `greeting` exists; either the quotes are missing or the name hasn't been declared.
  2. `unterminated string literal`: a piece of text starts with a quote and never closes.
  3. `initialization of immutable value 'age' was never used`: it compiles and runs, but a value was stored and never used.
  4. `Fatal error: Index out of range`: it compiles, but when it runs it asks for a position that doesn't exist and the program stops.

  The first two prevent running; the third lets the program run with a warning; the fourth only shows up when you run it. If you have a different version, your compiler may word some messages differently.
````

## Summary

- A diagnostic's format: `file:line:column: kind: message`.
- Compile error: no program. Warning: there's a program, but something looks wrong. Runtime error: the program stops on specific data.
- The problem is at the marked position or before it; check the end of the previous line.
- Fix one at a time, starting with the first error, and compile again.
- Keep zero warnings.
