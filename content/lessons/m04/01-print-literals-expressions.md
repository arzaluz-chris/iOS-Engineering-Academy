---
id: m04-l01
title: "Your first lines: print, comments, literals and expressions"
description: You write and run your first Swift programs, learn to predict exactly what they print, and find out why 7 / 2 is 3.
module: m04
order: 1
level: beginner
minutes: 50
prerequisites: [m01-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Use print with one or more values, separator and terminator.
  - Write single-line and multi-line comments.
  - Recognize integer, decimal and text literals.
  - Evaluate arithmetic expressions using precedence and associativity.
  - Explain the difference between integer division and decimal division.
terms:
  - term: Literal
    definition: A value written directly in the code, like 42, 3.5 or "Hello".
  - term: Expression
    definition: A combination of values and operators that produces a new value, like 2 + 3.
  - term: Operator
    definition: A symbol that performs an operation on one or more values, like +, -, * or /.
  - term: Precedence
    definition: The rule that decides which operation runs first when an expression has several. Multiplication comes before addition.
  - term: Associativity
    definition: The rule that decides the order between operators with the same precedence. Subtraction groups from left to right.
  - term: Comment
    definition: Text in the code that the compiler ignores. You use it to explain to other people, or to your future self, why the code is the way it is.
mastery:
  - Predict, without running it, the exact output of a program with several print calls, including separator and terminator.
  - Work out by hand the result of expressions like 2 + 3 * 4, (2 + 3) * 4 and 10 - 4 - 3.
  - Explain why 7 / 2 gives 3 and 7.0 / 2 gives 3.5.
  - Fix typical print compile errors without the compiler's help.
resources: [swift-book-basics, swift-book-basic-operators, swift-print]
cards:
  - id: m04-l01-c1
    front: What does `print(7 / 2)` print in Swift, and why?
    back: "It prints 3. Both operands are integers (Int), so the division is integer division and the decimal part is dropped."
  - id: m04-l01-c2
    front: 'What does `print(1, 2, 3, separator: "-")` print?'
    back: "1-2-3. By default print separates its values with a space; separator changes that separator."
  - id: m04-l01-c3
    front: What is `2 + 3 * 4`, and what is `10 - 4 - 3`?
    back: "14, because multiplication has higher precedence. 3, because subtraction groups from left to right: (10 - 4) - 3."
  - id: m04-l01-c4
    front: What are comments for, and what does the compiler do with them?
    back: The compiler ignores them. They explain why the code is the way it is, not repeat what the code already says.
---

## Where to run these examples

Until you reach the module on the development environment, you have two options:

- **Xcode**: *File → New → Playground*, *Blank* template. Type the code and press the run button.
- **Terminal** (with Xcode installed): save the code in a file named `hello.swift` and run `swift hello.swift`.

```bash
swift hello.swift
```

Every example in this lesson prints to the console. Before you run any of them, **predict what it will print**. That habit is the most important exercise in the lesson.

## print: your first function

**Plain definition:** `print` shows values in the console.

**Precise definition:** `print` is a function from the Swift standard library. It takes zero or more values, turns them into text, writes them separated by a `separator` (a space, unless you say otherwise) and then writes a `terminator` at the end (a line break, unless you say otherwise).

```swift
print("Hello")
print("Hello", "Swift")
print(1, 2, 3, separator: "-")
print("No line break", terminator: "")
print("!")
```

Line by line:

1. `print("Hello")` prints `Hello` and a line break.
2. `print("Hello", "Swift")` takes two values and separates them with the default separator: `Hello Swift`.
3. `separator: "-"` changes the separator: `1-2-3`.
4. `terminator: ""` replaces the final line break with nothing, so whatever comes next is written on the same line.
5. `print("!")` prints `!` right after it, so lines four and five together produce `No line break!`.

```output
Hello
Hello Swift
1-2-3
No line break!
```

`separator:` and `terminator:` are **argument labels**: names that go with certain values when you call a function. You'll study them properly in the functions module. For now, just know they're written like this, with a colon.

## Comments

A comment is text the compiler ignores.

```swift
// Single-line comment: everything after // is ignored.
print("Visible") // it can also go at the end of a line

/*
 Multi-line comment.
 /* In Swift, multi-line comments can be nested. */
*/
```

A good comment explains **why**, not **what**. `// prints 5` above `print(5)` adds nothing. `// The bank rounds to two decimal places by regulation` does.

## Literals

A **literal** is a value written as-is in the code:

| Literal | Type Swift gives it by default | Example |
| --- | --- | --- |
| Integer | `Int` | `42`, `-7`, `1_000_000` |
| Decimal | `Double` | `3.5`, `0.1`, `-2.0` |
| Text | `String` | `"Hello"`, `"42"` |
| Boolean | `Bool` | `true`, `false` |

The underscore in `1_000_000` is only there to make it easier to read. It's the same value as `1000000`.

Watch out for `"42"`: with quotes, it's **text** containing the characters 4 and 2, not the number 42. That's why `print("1" + "2")` prints `12`: `+` between two pieces of text **joins** them (concatenation), it doesn't add them.

## Expressions and arithmetic operators

An **expression** produces a value. The basic arithmetic operators are:

| Operator | Meaning | Example | Result |
| --- | --- | --- | --- |
| `+` | addition | `7 + 2` | `9` |
| `-` | subtraction | `7 - 2` | `5` |
| `*` | multiplication | `7 * 2` | `14` |
| `/` | division | `7 / 2` | `3` |
| `%` | remainder | `7 % 2` | `1` |

### Why 7 / 2 is 3

If both operands are integers (`Int`), the result is an integer too: Swift **drops the decimal part**. It doesn't round. It truncates toward zero.

```swift
print(7 / 2)
print(7.0 / 2)
print(7 % 2)
```

```output
3
3.5
1
```

In `7.0 / 2`, the `7.0` is a decimal, so Swift reads the `2` as a decimal too. The division is decimal division and gives `3.5`. The `%` operator returns the **remainder** of integer division: 2 goes into 7 three times, with 1 left over.

### Precedence and associativity

Just like in school arithmetic, `*`, `/` and `%` are evaluated before `+` and `-`. Between operators at the same level, Swift groups from **left to right**.

```swift
print(2 + 3 * 4)
print((2 + 3) * 4)
print(10 - 4 - 3)
```

```output
14
20
3
```

- `2 + 3 * 4`: first `3 * 4 = 12`, then `2 + 12 = 14`.
- Parentheses change the order: `(2 + 3) * 4 = 20`.
- `10 - 4 - 3` groups as `(10 - 4) - 3 = 3`, not as `10 - (4 - 3) = 9`.

A rule working engineers follow: if someone has to think about precedence to understand your expression, **add parentheses**. They cost nothing and prevent bugs.

## Swift doesn't quietly mix types

This doesn't compile:

```swift no-compile binary operator '+' cannot be applied to operands of type 'String' and 'Int'
print("Total: " + 5)
```

`+` isn't defined between a `String` and an `Int`. Other languages turn the number into text for you. Swift doesn't, because silent conversions like that cause bugs. At the end of this module you'll learn the right way to combine text and numbers: **interpolation**. For now, `print` with several values does the job:

```swift
print("Total:", 5)
```

```output
Total: 5
```

## Common mistakes

> [!error] error: cannot find 'Print' in scope
> Swift is case-sensitive. `Print` and `print` are different names, and `Print` doesn't exist.

> [!error] error: unterminated string literal
> A piece of text is missing its closing quote. The compiler points at the line where the unclosed text starts.

> [!error] Expecting decimals from dividing two integers
> `7 / 2` is `3`. If you need `3.5`, at least one of the values has to be a decimal.

> [!error] Mixing up the text "5" and the number 5
> `"5" + "5"` is `"55"`. `5 + 5` is `10`.

````exercise
id: m04-l01-e1
type: comprehension
prompt: What does `print(9 / 4)` print?
choices:
  - text: "`2.25`"
    correct: false
    why: That would be the result of decimal division. Here both operands are integers.
  - text: "`2`"
    correct: true
    why: Integer division between Ints. The decimal part is dropped.
  - text: "`3`"
    correct: false
    why: Swift doesn't round in integer division. It truncates.
  - text: A compile error
    correct: false
    why: Dividing two integers is valid. The result is another integer.
solution: |
  It prints **2**. `9` and `4` are integer literals, so Swift treats them as `Int` and does integer division: 4 goes into 9 twice, and the leftover (1) is dropped. If you wanted `2.25`, you'd write `9.0 / 4`.
````

````exercise
id: m04-l01-e2
type: prediction
prompt: Predict the exact output, line by line. Then, if you like, check it by running it.
code: |
  print("A", "B", "C")
  print("A", "B", "C", separator: "")
  print(10 - 4 - 3)
  print(2 * 3 + 4 * 5)
  print("1" + "2")
  // print("Can you see me?")
  print(17 % 5)
output: |
  A B C
  ABC
  3
  26
  12
  2
hints:
  - The default separator is a space.
  - The line that starts with // doesn't run.
  - "2 * 3 + 4 * 5: do the multiplications first."
solution: |
  ```output
  A B C
  ABC
  3
  26
  12
  2
  ```

  1. Three values with the default separator, a space.
  2. `separator: ""` joins them with no space.
  3. `(10 - 4) - 3 = 3`, because of left-to-right associativity.
  4. `6 + 20 = 26`: multiplications first.
  5. Text concatenation: `"12"`.
  6. The commented-out line doesn't exist as far as the compiler is concerned.
  7. 5 goes into 17 three times (15), with **2** left over.
````

````exercise
id: m04-l01-e3
type: fill-in
prompt: |
  Complete the program so it prints exactly:

  ```output
  Area: 12
  ```

  The first blank must turn the first line into a single-line comment.
code: |
  [[1]] Area of a 3 by 4 rectangle
  print("Area:", 3 [[2]] 4)
blanks:
  - id: "1"
    answers: ["//"]
  - id: "2"
    answers: ["*"]
solution: |
  ```swift
  // Area of a 3 by 4 rectangle
  print("Area:", 3 * 4)
  ```

  `//` turns the line into a comment. `3 * 4` is the multiplication. `print` separates its two values with a space, which is why you see `Area: 12`.
````

````exercise
id: m04-l01-e4
type: find-errors
prompt: This program doesn't compile. Pick out the real problems, then write the fixed version in the editor.
code: |
  print("Welcome to the course)
  Print("Lesson 1")
  print("Total:" + 3)
choices:
  - text: "Line 1 is missing its closing quote."
    correct: true
    why: "The text starts at `\"Welcome` and is never closed."
  - text: "On line 2, `Print` with a capital P doesn't exist."
    correct: true
    why: Swift is case-sensitive.
  - text: "On line 3, you can't use `+` between a String and an Int."
    correct: true
    why: Swift doesn't quietly turn the number into text.
  - text: "Each line is missing a semicolon at the end."
    correct: false
    why: In Swift, a semicolon at the end of a line is optional.
rubric:
  - I closed the quotes on line 1.
  - I used lowercase `print`.
  - "I fixed line 3 without adding text and a number, for example with `print(\"Total:\", 3)`."
  - My version prints three lines.
solution: |
  ```swift
  print("Welcome to the course")
  print("Lesson 1")
  print("Total:", 3)
  ```

  All three problems are compile errors: the program doesn't exist until you fix them. Semicolons aren't required in Swift. You only need one if you write two statements on the same line.
````

````exercise
id: m04-l01-e5
type: solve
prompt: |
  Write a program that prints a receipt with these three lines:

  ```output
  Coffee: 45
  Bread: 28
  Total: 73
  ```

  The total has to be **calculated** with an expression in the code, not typed in by hand.
starter: |
  // Receipt
hints:
  - "`print` accepts several values separated by commas."
  - "For the total, the expression is `45 + 28`."
rubric:
  - The program prints exactly the three lines asked for.
  - The total is calculated with an expression, not written as 73.
  - I don't use `+` between text and a number.
  - I ran it in Xcode or in the terminal and checked the output.
solution: |
  ```swift
  // Receipt
  print("Coffee:", 45)
  print("Bread:", 28)
  print("Total:", 45 + 28)
  ```

  The problem with this solution is that each price appears twice: if coffee gets more expensive, you have to change it in two places. **Constants**, in the next lesson, solve exactly that.
````

````exercise
id: m04-l01-e6
type: explain
prompt: Explain in your own words what this line calculates, in what order it's evaluated, and what it prints.
code: |
  print(60 * 60 * 24)
rubric:
  - I gave the correct result, 86400.
  - I explained the order of evaluation, left to right.
  - I said what it means, the number of seconds in a day.
  - I suggested a way to make it clearer for whoever reads it.
solution: |
  It prints **86400**. Both operators are `*`, with the same precedence, so it groups from left to right: `(60 * 60) * 24 = 3600 * 24 = 86400`.

  It's the number of **seconds in a day**: 60 seconds per minute, 60 minutes per hour, 24 hours per day. Since the number doesn't explain itself, a comment helps: `// seconds in a day`. Named constants, which you'll see in the next lesson, are even better.
````

````exercise
id: m04-l01-e7
type: refactor
prompt: |
  This program prints the cost of three identical breakfasts (coffee at 45 and bread at 28). It works, but it's hard to read and to maintain. Rewrite it so the intent is obvious and the result stays the same.
code: |
  print(45 + 28 + 45 + 28 + 45 + 28)
rubric:
  - My version prints the same result, 219.
  - It's clear that these are three identical breakfasts.
  - I used parentheses to make the order of operations clear.
  - I added a comment that explains why, not what.
solution: |
  ```swift
  // Three identical breakfasts: coffee (45) + bread (28)
  print((45 + 28) * 3)
  ```

  `(45 + 28) * 3 = 73 * 3 = 219`, the same as the original sum. The parentheses are required: without them, `45 + 28 * 3` would give `129`, because multiplication goes first. The result matches, the structure of the calculation is now visible, and a price change happens in one place.
````

## Summary

- `print` turns values into text, separates them with a space and ends with a line break. `separator:` and `terminator:` change that.
- Comments explain why. The compiler ignores them.
- Literals have types: `42` is an `Int`, `3.5` is a `Double`, `"Hello"` is a `String`.
- Division between integers drops the decimal part. `%` gives the remainder.
- Multiplication and division come before addition and subtraction. Between equals, left to right. When in doubt, use parentheses.
- Swift doesn't quietly mix text and numbers.
