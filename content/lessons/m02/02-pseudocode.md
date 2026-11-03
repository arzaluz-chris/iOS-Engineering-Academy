---
id: m02-l02
title: "Pseudocode: writing algorithms precisely"
description: A simple notation for writing algorithms without fighting a language's syntax. You learn the course's conventions, the four structures every algorithm is built from, and how each line will later translate to Swift.
module: m02
order: 2
level: beginner
minutes: 50
prerequisites: [m02-l01]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Write algorithms in pseudocode using the course's conventions.
  - Use the four basic structures, sequence, assignment, decision and repetition.
  - Tell a loop with a known number of steps apart from one that depends on a condition.
  - Spot ambiguous steps, variables with no starting value and loops that never end.
terms:
  - term: Pseudocode
    definition: A description of an algorithm in words, with a structure similar to a programming language's but without its syntax rules. You don't run it; you read it.
  - term: Variable
    definition: A name that holds a value that can change during the algorithm, like "total" or "counter".
  - term: Assignment
    definition: "Storing a value in a variable. In the course's pseudocode it's written with an arrow: total ← 0."
  - term: Condition
    definition: A question that can only be answered with true or false, like "n > 10".
  - term: Decision
    definition: A structure that runs some steps or others depending on a condition. It's written "If … then … Else …".
  - term: Repetition
    definition: A structure that runs the same steps several times. Also called a loop.
  - term: Indentation
    definition: Space at the start of a line that says it belongs to the block of the line above, for example to an "If" or a "For each".
mastery:
  - Write in pseudocode, without looking at the lesson, an algorithm with a decision and a loop.
  - Translate an algorithm written in prose into pseudocode using the course's conventions.
  - Point out in someone else's pseudocode a variable with no starting value or a loop that never ends, and fix it.
  - "Choose between \"For each\" and \"While\" and justify the choice."
resources: [swift-book-control-flow]
cards:
  - id: m02-l02-c1
    front: What does `total ← total + price` mean in pseudocode?
    back: It computes total + price with the current value of total and stores the result back in total. The arrow is an assignment, not a mathematical equality.
  - id: m02-l02-c2
    front: What are the four basic structures of an algorithm?
    back: Sequence (one step after another), assignment (storing a value), decision (If … Else) and repetition (For each, While).
  - id: m02-l02-c3
    front: When do you use "For each" and when "While"?
    back: "\"For each\" when you walk through the elements of a collection or repeat a known number of times. \"While\" when you repeat until a condition stops holding and you don't know in advance how many times that will be."
  - id: m02-l02-c4
    front: What has to change inside a "While" loop for it to end?
    back: Some value that appears in its condition. If nothing in the condition changes inside the loop, the condition never becomes false and the loop never ends.
---

## The idea in one sentence

Pseudocode is an algorithm written with the precision of a program and the freedom of plain English.

## Why not write it in Swift right away

When you're learning to program, every line of Swift asks you for two things at once: **what** you want to do and **how** to write it. Pseudocode separates the two. First you solve the problem without worrying about commas, braces or types; then you translate.

That separation isn't just for beginners. In a technical interview it's common to explain your approach in pseudocode or out loud before writing code, and on a team an algorithm gets discussed on a whiteboard before it's implemented.

Pseudocode has no official standard. Every book and every team uses its own flavor. What matters is that **every line has exactly one meaning**. This course uses the conventions in the next section.

## The course's conventions

| Write | Meaning | In Swift (you'll see it in Modules 4 to 6) |
| --- | --- | --- |
| `Input:` and `Output:` | What the algorithm receives and hands back | A function's parameters and return value |
| `total ← 0` | Store 0 in the variable `total` | `var total = 0` |
| `Print total` | Write the value to the output | `print(total)` |
| `If condition then` … `Else` | Decision | `if condition { … } else { … }` |
| `For each x in list` | Repeat once per element | `for x in list { … }` |
| `While condition` | Repeat while the condition is true | `while condition { … }` |
| `Return value` | Stop and hand back the output | `return value` |
| Indentation | Indented lines belong to the block above | Braces `{ }` |

For arithmetic use the usual symbols: `+`, `−`, `×`, `÷`, and for comparisons `=`, `≠`, `<`, `≤`, `>`, `≥`. When division has to be integer division, say so.

### The arrow isn't an equals sign

`counter ← counter + 1` would be nonsense as an equation: no number equals itself plus one. As an assignment it makes sense: **compute** `counter + 1` with the current value and **store** the result in `counter`. If `counter` was 4, it's now 5. That's why the course uses an arrow and saves `=` for comparisons.

## The four structures

Every algorithm in this course is built from four pieces.

1. **Sequence**: the steps run in order, top to bottom.
2. **Assignment**: storing a value in a variable.
3. **Decision**: doing one thing or another depending on a condition.
4. **Repetition**: doing the same thing several times.

### Minimal example: even or odd

```pseudo
Input: an integer n
Output: the text "even" or "odd"

If the remainder of n ÷ 2 is 0 then
    Return "even"
Else
    Return "odd"
```

Line by line:

1. `Input` states what it receives: an integer, not a decimal or a piece of text.
2. `Output` states what it hands back: one of two texts, nothing else.
3. The condition uses the **remainder**: a number is even if nothing is left over when you divide it by 2. In Swift it's the `%` operator, which you'll see in Module 4.
4. The indented line belongs to the `If`: it only runs when the condition is true.
5. `Else` covers every other case. Since the remainder of dividing a positive number by 2 can only be 0 or 1, there's no third case.
6. `Return` ends the algorithm with the answer.

> [!note]
> With negative numbers, Swift's remainder keeps the sign: `-3 % 2` is `-1`, not `1`. That's why the condition asks whether the remainder **is 0**, which works for negatives, instead of asking whether it's 1.

### Two kinds of repetition

**For each** walks through a collection or a known range. You know how many times it'll run before it starts.

```pseudo
For each grade in grades
    Print grade
```

**While** repeats until a condition becomes false. You don't always know how many times it'll run.

```pseudo
balance ← 1000
months ← 0
While balance < 2000
    balance ← balance × 2
    months ← months + 1
Print months
```

In a `While` loop, something in the condition **has to change** inside the loop. Here `balance` grows on every pass; if the line `balance ← balance × 2` weren't there, the loop would never end.

## A practical example: average of passing grades

Problem: from a list of grades, print how many are passing (6 or higher) and their average.

```pseudo
Input: a list of whole-number grades from 0 to 10
Output: how many passed and the average of the passing grades

sum ← 0
passed ← 0
For each g in grades
    If g ≥ 6 then
        sum ← sum + g
        passed ← passed + 1
Print passed
If passed = 0 then
    Print "no passing grades"
Else
    Print sum ÷ passed
```

This pseudocode combines all four structures and two accumulator patterns, one for the sum and one for the count. Look at the last decision: it guards the division against the "nobody passed" case. Without it, with the list `[4, 5]` the algorithm would divide 0 ÷ 0.

Before going on: should the average be a whole number or a decimal? The problem doesn't say. With `[6, 7]` the average is 6.5; with integer division it would be 6. A question like that is exactly what pseudocode brings to the surface before you write a line of Swift.

## Common mistakes

> [!error] A variable with no starting value
> `sum ← sum + g` inside a loop makes no sense if you never wrote `sum ← 0` first. What's `sum` the first time through? Swift won't let you use a variable with no value either.

> [!error] A "While" loop that never ends
> If nothing in the condition changes inside the loop, the condition never becomes false. Always check which line in the loop moves the condition toward false.

> [!error] Ambiguous indentation
> If it isn't clear which lines belong to an `If` or a `For each`, the algorithm has two possible readings. Indent consistently: four spaces per level.

> [!error] Pseudocode that's too vague
> "Process the list" isn't pseudocode; it's a wish. Every line has to be something you could carry out by hand without asking the author anything.

````exercise
id: m02-l02-e1
type: comprehension
prompt: |
  What is the value of `x` after these three lines?

  ```pseudo
  x ← 5
  x ← x + 3
  x ← x × 2
  ```
choices:
  - text: "5"
    correct: false
    why: The first line assigns 5, but the following lines change the value.
  - text: "16"
    correct: true
    why: "5, then 5 + 3 = 8, then 8 × 2 = 16."
  - text: "13"
    correct: false
    why: "That's 5 + 3 + 5: it confuses assignment with a running sum."
  - text: "None: x ← x + 3 is a contradiction."
    correct: false
    why: The arrow is an assignment, not an equation. It computes the right side and stores it on the left.
solution: |
  **16.** The assignments run in order and each one uses the current value of `x`:

  | Step | Calculation | x |
  | --- | --- | --- |
  | `x ← 5` | — | 5 |
  | `x ← x + 3` | 5 + 3 | 8 |
  | `x ← x × 2` | 8 × 2 | 16 |
````

````exercise
id: m02-l02-e2
type: prediction
lang: pseudo
prompt: Write exactly what this algorithm prints, one line per "Print".
code: |
  numbers ← [3, 8, 5, 10]
  For each n in numbers
      If n > 4 then
          Print n × 2

  x ← 1
  While x < 20
      Print x
      x ← x × 3
output: |
  16
  10
  20
  1
  3
  9
hints:
  - 3 doesn't meet the condition n > 4.
  - "In the \"While\" loop, x goes through 1, 3, 9 and 27. At which of those values does it stop going in?"
solution: |
  ```output
  16
  10
  20
  1
  3
  9
  ```

  **First loop.** 3 isn't greater than 4, so nothing is printed. 8, 5 and 10 are: 16, 10 and 20 are printed.

  **Second loop.** x is printed and then tripled:

  | Pass | x < 20? | Prints | x after |
  | --- | --- | --- | --- |
  | 1 | 1 < 20, yes | 1 | 3 |
  | 2 | 3 < 20, yes | 3 | 9 |
  | 3 | 9 < 20, yes | 9 | 27 |
  | 4 | 27 < 20, no | — | — |

  Here's the Swift version. The course tests run this translation to check the output:

  ```swift
  let numbers = [3, 8, 5, 10]
  for n in numbers {
      if n > 4 {
          print(n * 2)
      }
  }

  var x = 1
  while x < 20 {
      print(x)
      x = x * 3
  }
  ```
````

````exercise
id: m02-l02-e3
type: solve
prompt: |
  Write in pseudocode, using the course's conventions, an algorithm that receives a list of whole-number temperatures and prints:

  1. How many temperatures are below zero.
  2. The lowest temperature, or "no data" if the list is empty.
starter: |
  Input:
  Output:
hints:
  - It's two accumulators over the same list, a count and a minimum.
  - The minimum has to start with a real element from the list, not with 0.
rubric:
  - I stated Input and Output.
  - Every variable has a starting value before it's used.
  - The count only counts temperatures less than 0.
  - The minimum starts with the first temperature, not with a made-up value.
  - I handled the empty list before reading the first element.
  - The indentation makes clear what belongs to each If and each For each.
solution: |
  ```pseudo
  Input: a list of whole-number temperatures
  Output: how many are below zero and the lowest one

  belowZero ← 0
  For each t in temperatures
      If t < 0 then
          belowZero ← belowZero + 1
  Print belowZero

  If temperatures is empty then
      Print "no data"
  Else
      lowest ← the first temperature
      For each t in temperatures
          If t < lowest then
              lowest ← t
      Print lowest
  ```

  - The count on an empty list gives 0, which is correct; that's why it needs no guard.
  - The minimum does need one: an empty list has no first temperature.
  - Starting with `lowest ← 0` would be a bug: with `[5, 12, 8]` the algorithm would answer 0, a temperature that isn't in the list.

  You could do it all in one pass. Two passes are easier to read and, for lists this size, the difference doesn't matter.
````

````exercise
id: m02-l02-e4
type: find-errors
prompt: |
  This pseudocode is supposed to print the sum of the numbers from 1 to n. It has real problems. Select them and write the corrected version.
code: |
  Input: an integer n ≥ 1
  Output: 1 + 2 + … + n

  i ← 1
  While i ≤ n
      sum ← sum + i
  Print sum
choices:
  - text: "`sum` is used before it has a starting value."
    correct: true
    why: The first time `sum ← sum + i` runs, `sum` has no value.
  - text: "The loop never ends because `i` doesn't change inside it."
    correct: true
    why: "The condition is i ≤ n and nothing inside the loop changes i or n."
  - text: "It should use `=` instead of `←`."
    correct: false
    why: "In the course's pseudocode, `←` assigns and `=` compares. Here you want to assign."
  - text: "The condition should be `i < n`."
    correct: false
    why: "With `i < n`, the value n wouldn't be added. `i ≤ n` is correct."
rubric:
  - "I initialized `sum ← 0` before the loop."
  - "I added `i ← i + 1` inside the loop."
  - "I checked by hand with n = 3 that the result is 6."
solution: |
  ```pseudo
  Input: an integer n ≥ 1
  Output: 1 + 2 + … + n

  sum ← 0
  i ← 1
  While i ≤ n
      sum ← sum + i
      i ← i + 1
  Print sum
  ```

  With n = 3: sum goes through 1, 3 and 6; i goes through 2, 3 and 4; when i is 4 the condition is false and **6** is printed.

  Since you know in advance how many passes there are, `For each i in 1…n` would be clearer and removes the risk of forgetting the increment.
````

````exercise
id: m02-l02-e5
type: refactor
prompt: Rewrite this algorithm as precise pseudocode, using the course's conventions. It should do what it describes, with no ambiguity.
code: |
  Go through the prices in the cart. If any of them is expensive, warn about it.
  At the end say how much everything costs and apply the discount if it applies.
rubric:
  - "I defined \"expensive\" with a concrete number."
  - "I defined when the discount \"applies\" and how big it is."
  - I stated Input and Output.
  - I used an accumulator with a starting value for the total.
  - Every line can be carried out by hand without asking anything.
solution: |
  The original has three ambiguities: what "expensive" means, when the discount "applies", and how big it is. You have to decide them (or ask). A precise version, with the decisions written down:

  ```pseudo
  Input: a list of whole-number prices
  Output: warnings about high prices and the total to pay

  Expensive price threshold: 1000
  Discount: 10% if the total is 2000 or more

  total ← 0
  For each p in prices
      If p > 1000 then
          Print "High price:" and p
      total ← total + p
  If total ≥ 2000 then
      total ← total − total × 10 ÷ 100
  Print total
  ```

  The concrete numbers (1000, 2000, 10%) are decisions; in a real project, whoever asks for the app defines them. What matters is that they no longer depend on how the reader interprets them.
````

## Summary

- Pseudocode separates **what** an algorithm does from **how** you write it in a language.
- In this course: `←` assigns, `=` compares, `Print` writes, `Return` ends with the answer, and indentation marks blocks.
- Four structures: sequence, assignment, decision and repetition.
- `For each` walks through something known; `While` repeats until its condition is false, and something in that condition has to change inside the loop.
- Every variable needs a starting value before it's used.
