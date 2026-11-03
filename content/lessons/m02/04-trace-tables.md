---
id: m02-l04
title: Trace tables and running code by hand
description: You run an algorithm by hand, step by step, writing down every variable in a table. It's the most reliable way to predict what a program will do and to find the exact step where it goes wrong.
module: m02
order: 4
level: beginner
minutes: 45
prerequisites: [m02-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Build a trace table with one column per variable, condition and output.
  - Run an algorithm with loops and decisions by hand without skipping steps.
  - Count how many times a loop runs from its trace table.
  - Use a trace table to find the exact step where an algorithm goes wrong.
terms:
  - term: Trace table
    definition: A table in which each row is a moment in the execution and each column is the value of a variable, a condition or the output.
  - term: Hand execution
    definition: Following an algorithm with pencil and paper, the way the computer would, without assuming results.
  - term: State
    definition: The values of all the variables at a given moment in the execution.
  - term: Iteration
    definition: One pass through a loop.
  - term: Off-by-one error
    definition: A bug in which a loop runs one time too many or too few, usually from using < instead of ≤ or the other way around.
mastery:
  - Fill in, without mistakes, the trace table of an algorithm with a loop and a decision, and write its exact output.
  - Say how many iterations a loop runs and what value each variable ends with.
  - Use a table to find the row where an algorithm with an off-by-one error starts to drift from the expected result.
  - Explain why you fill in the table line by line and not "from memory".
resources: [swift-book-control-flow]
cards:
  - id: m02-l04-c1
    front: What columns does a trace table have?
    back: One for each variable, one for each condition that gets evaluated and one for the output. Each row is a moment in the execution.
  - id: m02-l04-c2
    front: What is an off-by-one error?
    back: A loop that runs one time too many or too few, typically from mixing up < and ≤ or from starting to count at 0 instead of 1.
  - id: m02-l04-c3
    front: Why not fill in the table "from memory"?
    back: Because the goal is to run what the algorithm says, not what you think it says. Bugs hide right in the gap between the two.
---

## The idea in one sentence

A trace table turns you into the computer: you run each step exactly as written and write down what changes.

## Why run it by hand

Reading an algorithm and "seeing" what it does works until there's a loop. That's where memory fails you: what was `sum` on the third pass? Did the `If` run on the last one? The table takes the guessing out.

It's the same skill you'll use in two work situations:

- **Debugging**: when a program gives a wrong result, you compare the table you expected with the real values in Xcode's debugger. The first place they differ is where the bug is. You'll practice this in Module 3.
- **Technical interviews**: after you write a solution, you're expected to run it by hand on a small example to show that it works.

## How to build a table

1. Write one column for each **variable**, one for each **condition** that gets evaluated and one for the **output**.
2. Write a row with the **starting** values.
3. Run the algorithm line by line. Every time something changes, add a row or update the matching column.
4. Don't write down a value you didn't compute from the line that produces it.

### Minimal example: sum of the digits

```pseudo
Input: an integer n ≥ 0
Output: the sum of its digits

sum ← 0
While n > 0
    sum ← sum + (remainder of n ÷ 10)
    n ← n ÷ 10, integer division
Print sum
```

With n = 472:

| Moment | n | n > 0? | remainder of n ÷ 10 | sum | Output |
| --- | --- | --- | --- | --- | --- |
| Start | 472 | — | — | 0 | |
| Pass 1 | 472 → 47 | yes | 2 | 2 | |
| Pass 2 | 47 → 4 | yes | 7 | 9 | |
| Pass 3 | 4 → 0 | yes | 4 | 13 | |
| Loop ends | 0 | no | — | 13 | |
| Print | 0 | — | — | 13 | 13 |

Line by line:

1. `sum ← 0` is the accumulator's starting value.
2. The condition `n > 0` is evaluated **before** each pass. Always write it down: the last evaluation, the one that says "no", is the one that ends the loop.
3. `remainder of n ÷ 10` takes the last digit: the remainder of 472 divided by 10 is 2.
4. `n ÷ 10` with integer division drops the last digit: 472 becomes 47.
5. After three passes `n` is 0 and the condition is false.
6. 13 is printed, which is 4 + 7 + 2.

Two things only the table shows you: the loop runs **as many times as n has digits**, and with n = 0 it doesn't run at all and prints 0, which is correct.

## A practical example: finding an off-by-one error

This algorithm is supposed to print the multiples of 3 from 3 to 15, inclusive:

```pseudo
m ← 3
While m < 15
    Print m
    m ← m + 3
```

The table:

| Pass | m when checked | m < 15? | Prints | m after |
| --- | --- | --- | --- | --- |
| 1 | 3 | yes | 3 | 6 |
| 2 | 6 | yes | 6 | 9 |
| 3 | 9 | yes | 9 | 12 |
| 4 | 12 | yes | 12 | 15 |
| 5 | 15 | **no** | — | — |

The fifth row is the evidence: when `m` is exactly 15, the condition `m < 15` is false and 15 never gets printed. It's an **off-by-one error**: the loop runs one time fewer than it should. The fix is `m ≤ 15`.

Without the table, the bug is easy to miss, because the algorithm "almost" works: it prints four of the five numbers.

> [!tip]
> When a loop has a limit, always write the row for the **last value**: the one that should get in and the first one that shouldn't. That's where off-by-one errors live.

## Common mistakes

> [!error] Filling in the table with what "should" happen
> If you write the value you expect instead of the one the line produces, the table will confirm your mistake instead of revealing it. Compute each cell from its line.

> [!error] Forgetting the last evaluation of the condition
> The row where the condition is false is the one that explains why the loop ends and with what values. Without it you can't catch off-by-one errors.

> [!error] Updating two variables in the wrong order
> If two consecutive lines each use a variable the other one changes, the order matters. Run and write down one line at a time.

> [!error] Testing only with large data
> Nobody fills in a 50-row table carefully. Pick the smallest input that exercises every path.

````exercise
id: m02-l04-e1
type: comprehension
prompt: |
  How many times does the body of this loop run?

  ```pseudo
  i ← 1
  While i ≤ 10
      i ← i × 2
  ```
choices:
  - text: "3"
    correct: false
    why: "After 3 passes i is 8, and 8 ≤ 10 is still true."
  - text: "4"
    correct: true
    why: "i goes in as 1, 2, 4 and 8; after that it's 16 and the condition is false."
  - text: "5"
    correct: false
    why: "With i = 16 the condition is already false; there's no fifth pass."
  - text: "10"
    correct: false
    why: "The loop doesn't add 1; it multiplies by 2."
solution: |
  **4 passes.**

  | Pass | i when checked | i ≤ 10? | i after |
  | --- | --- | --- | --- |
  | 1 | 1 | yes | 2 |
  | 2 | 2 | yes | 4 |
  | 3 | 4 | yes | 8 |
  | 4 | 8 | yes | 16 |
  | — | 16 | no | — |
````

````exercise
id: m02-l04-e2
type: prediction
lang: pseudo
prompt: Build the trace table and write exactly what the algorithm prints.
code: |
  a ← 0
  b ← 1
  Repeat 6 times
      Print a
      next ← a + b
      a ← b
      b ← next
output: |
  0
  1
  1
  2
  3
  5
hints:
  - Columns a, b, next and Output. a is printed before it's updated.
  - "Pass 3: a = 1, b = 2."
solution: |
  ```output
  0
  1
  1
  2
  3
  5
  ```

  | Pass | Prints a | next | a after | b after |
  | --- | --- | --- | --- | --- |
  | 1 | 0 | 1 | 1 | 1 |
  | 2 | 1 | 2 | 1 | 2 |
  | 3 | 1 | 3 | 2 | 3 |
  | 4 | 2 | 5 | 3 | 5 |
  | 5 | 3 | 8 | 5 | 8 |
  | 6 | 5 | 13 | 8 | 13 |

  These are the first numbers of the **Fibonacci sequence**: each one is the sum of the two before it. The `next` variable exists because if you wrote `a ← b` and then `b ← a + b`, the second calculation would use the `a` you just changed. The order of the assignments matters.

  In Swift:

  ```swift
  var a = 0
  var b = 1
  for _ in 1...6 {
      print(a)
      let next = a + b
      a = b
      b = next
  }
  ```
````

````exercise
id: m02-l04-e3
type: fill-in
prompt: |
  Fill in the trace table for the digit-sum algorithm with n = 905.

  ```pseudo
  sum ← 0
  While n > 0
      sum ← sum + (remainder of n ÷ 10)
      n ← n ÷ 10, integer division
  ```
code: |
  Moment     n      sum
  Start      905    0
  Pass 1     90     5
  Pass 2     [[1]]  [[2]]
  Pass 3     0      [[3]]
blanks:
  - id: "1"
    answers: ["9"]
  - id: "2"
    answers: ["5"]
  - id: "3"
    answers: ["14"]
solution: |
  | Moment | n | sum |
  | --- | --- | --- |
  | Start | 905 | 0 |
  | Pass 1 | 90 | 0 + 5 = 5 |
  | Pass 2 | 9 | 5 + 0 = 5 |
  | Pass 3 | 0 | 5 + 9 = 14 |

  On pass 2 the remainder of 90 ÷ 10 is **0**, so `sum` doesn't change. The zero in the middle of the number is a good test case: it confirms that the algorithm doesn't stop when it hits a 0 digit, only when `n` reaches 0.
````

````exercise
id: m02-l04-e4
type: find-errors
prompt: |
  This algorithm is supposed to print the average of a list of grades. With the list [8, 6, 10] it prints 3 instead of 8. All division is integer division. Build its trace table and select the real problems. Then write the corrected version.
code: |
  sum ← 0
  count ← 0
  For each g in grades
      sum ← g
      count ← count + 1
  Print sum ÷ count
choices:
  - text: "`sum ← g` replaces the sum instead of accumulating; it should be `sum ← sum + g`."
    correct: true
    why: "The table shows sum = 8, then 6, then 10: it never accumulates."
  - text: "`count` should start at 1."
    correct: false
    why: "With 3 grades, count ends at 3, which is correct."
  - text: "The division isn't guarded against an empty list."
    correct: true
    why: "It doesn't explain the 3 in this example, but with an empty list it would divide 0 ÷ 0. It's a real problem too."
  - text: "The loop should be a \"While\" instead of a \"For each\"."
    correct: false
    why: "\"For each\" is the right structure for walking through a list."
rubric:
  - I built the table and saw that sum takes the values 8, 6 and 10 instead of accumulating.
  - "I changed the line to `sum ← sum + g`."
  - I added the guard for the empty list.
  - I checked that with [8, 6, 10] the result is 8.
solution: |
  Trace table of the original algorithm:

  | Pass | g | sum | count |
  | --- | --- | --- | --- |
  | Start | — | 0 | 0 |
  | 1 | 8 | 8 | 1 |
  | 2 | 6 | 6 | 2 |
  | 3 | 10 | 10 | 3 |

  At the end `sum` is 10, the last grade, and `10 ÷ 3` with integer division is **3**. The table shows the cause: `sum` never accumulates; it only holds the current grade.

  ```pseudo
  sum ← 0
  count ← 0
  For each g in grades
      sum ← sum + g
      count ← count + 1
  If count = 0 then
      Print "no data"
  Else
      Print sum ÷ count
  ```

  With [8, 6, 10]: sum = 24, count = 3, average = 8.
````

````exercise
id: m02-l04-e5
type: solve
prompt: |
  Build the complete trace table of this algorithm with n = 6 and write what it prints. Then explain in one sentence what it computes for any n ≥ 1.

  ```pseudo
  result ← 1
  i ← 1
  While i ≤ n
      result ← result × i
      i ← i + 1
  Print result
  ```
starter: |
  Pass | i when checked | i ≤ n? | result after | i after
hints:
  - There are 6 passes and one final evaluation of the condition.
rubric:
  - The table has one row per pass and a final row where the condition is false.
  - The values of result are 1, 2, 6, 24, 120 and 720.
  - The output is 720.
  - "I identified that it computes the factorial of n: 1 × 2 × … × n."
solution: |
  | Pass | i when checked | i ≤ 6? | result after | i after |
  | --- | --- | --- | --- | --- |
  | 1 | 1 | yes | 1 | 2 |
  | 2 | 2 | yes | 2 | 3 |
  | 3 | 3 | yes | 6 | 4 |
  | 4 | 4 | yes | 24 | 5 |
  | 5 | 5 | yes | 120 | 6 |
  | 6 | 6 | yes | 720 | 7 |
  | — | 7 | no | — | — |

  It prints **720**. It computes the **factorial** of n, the product 1 × 2 × … × n, written n!. The accumulator starts at 1, not 0, because it's a multiplication: starting at 0 would make the whole product 0.
````

## Summary

- A trace table has one column per variable, condition and output, and one row per moment in the execution.
- Each cell is computed from the line that produces it, never from memory.
- Always write down the evaluation of the condition that ends the loop; that's where off-by-one errors show up.
- The order of assignments matters when one variable depends on another that changes.
- It's the same technique you'll use with the debugger and in interviews: compare what you expected with what really happened until you find the first difference.
