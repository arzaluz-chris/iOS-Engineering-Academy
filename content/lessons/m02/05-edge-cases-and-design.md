---
id: m02-l05
title: Edge cases and designing an algorithm from start to finish
description: You pull the whole module together into a six-step method for designing an algorithm, and learn to go looking for the inputs that break it before someone else finds them.
module: m02
order: 5
level: beginner
minutes: 50
prerequisites: [m02-l03, m02-l04]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Apply a six-step method for designing an algorithm, from understanding the problem to verifying the solution.
  - List the typical edge cases of a problem involving lists, numbers and text.
  - Ask clarifying questions when the problem statement is ambiguous.
  - Choose a small set of test cases that covers paths and boundaries.
terms:
  - term: Edge case
    definition: An input that is valid but extreme or unusual, like an empty list, a single element, the smallest or largest allowed value, or repeated elements.
  - term: Boundary
    definition: A value exactly at the limit of a condition, like 6 in "pass if the grade is 6 or higher".
  - term: Precondition
    definition: What the algorithm assumes about its input, for example "n ≥ 1". If it doesn't hold, the algorithm promises nothing.
  - term: Test case
    definition: A specific input together with the output you expect for it.
  - term: Clarifying question
    definition: A question you ask whoever requested the program to resolve an ambiguity in the problem statement before you design.
mastery:
  - List, for a new problem involving a list of numbers, at least five different edge cases.
  - Design an algorithm for a problem you haven't seen using the six-step method, and hand in its pseudocode, its trace table and its test cases.
  - Ask two relevant clarifying questions about an ambiguous problem statement.
  - Explain why an algorithm that passes with the example from the problem statement still isn't verified.
resources: [swift-book-control-flow, swift-book-basic-operators]
cards:
  - id: m02-l05-c1
    front: Name five typical edge cases for a problem involving a list of numbers.
    back: Empty list, a single element, all elements equal, negative numbers or zero, and the value you're looking for in the first or the last position.
  - id: m02-l05-c2
    front: What are the six steps of the course's design method?
    back: Understand, examples, edge cases, algorithm, trace and verify.
  - id: m02-l05-c3
    front: What is a precondition?
    back: What the algorithm assumes about its input, like "the list isn't empty". Write it down; if it doesn't hold, the algorithm promises nothing.
  - id: m02-l05-c4
    front: Which years are leap years in the Gregorian calendar?
    back: Those divisible by 4, except those divisible by 100 that aren't divisible by 400. 2000 is, 1900 isn't, 2024 is.
---

## The idea in one sentence

An algorithm isn't finished when it works with the example from the problem statement. It's finished when you know which inputs could break it and you've checked that they don't.

## The six-step method

This module gave you the tools one at a time. Together they make a method you'll use in every coding challenge in the course and in every technical interview:

| Step | What you do | Tool |
| --- | --- | --- |
| 1. Understand | Write down input, output and rules. Ask about anything unclear. | Abstraction |
| 2. Examples | Solve two or three normal examples by hand. | Hand execution |
| 3. Edge cases | Look for the extreme inputs and decide what should happen with each one. | This lesson |
| 4. Algorithm | Write it subproblem by subproblem. | Decomposition, pseudocode, flowcharts |
| 5. Trace | Run the algorithm on your examples and edge cases. | Trace tables |
| 6. Verify | Compare each output with the expected one. If any differs, go back to step 4. | Test cases |

Steps 1 to 3 happen **before** you write the algorithm. It's tempting to skip them. It's also the most common reason a solution ends up rewritten.

## Edge cases

**Plain definition:** inputs that are unusual but valid.

**Technical explanation:** an edge case is an input that follows the rules of the problem but sits at an extreme: the minimum size, the largest value, all elements equal. Algorithms fail disproportionately at those extremes because whoever designed them was thinking about the typical case.

### Checklist

| Kind of input | Edge cases to consider |
| --- | --- |
| List | Empty; one element; two elements; all equal; already sorted; in reverse order; the element you're looking for at the start or the end; duplicates |
| Number | Zero; negative; one; the minimum and maximum allowed; values right at the boundary of each condition |
| Text | Empty; one character; only spaces; uppercase and lowercase; accented letters; emoji |
| Two values | Equal; the first larger; the second larger |

Not all of them apply every time. The checklist is there so you **don't forget** any; then you decide which ones matter for your problem.

### A condition's boundaries

If a rule says "pass with 6 or higher", the values that matter are **5 and 6**: the last one that fails and the first one that passes. Testing with 3 and 9 wouldn't tell `≥ 6` apart from `> 6`, which is exactly the bug you want to catch.

### Numbers that are too big

On a computer, integers have a maximum size. In Swift, if an integer addition or multiplication goes past that maximum, the program **stops with a runtime error** instead of giving a wrong result. You'll study this in Module 4. For now, just ask yourself: how big can the numbers in my input get?

## Minimal example: leap years

Step 1, **understand**. In the Gregorian calendar, a year is a leap year if it's divisible by 4, except years divisible by 100, which are only leap years if they're also divisible by 400.

Step 2, **examples**: 2024 is a leap year; 2023 isn't.

Step 3, **edge cases**. The rule has three conditions; each one needs a year that triggers it:

| Year | ÷ 4? | ÷ 100? | ÷ 400? | Leap year? |
| --- | --- | --- | --- | --- |
| 2023 | no | — | — | no |
| 2024 | yes | no | — | yes |
| 1900 | yes | yes | no | no |
| 2000 | yes | yes | yes | yes |

Step 4, **algorithm**:

```pseudo
Input: a year, a positive integer
Output: yes or no

If the remainder of year ÷ 400 is 0 then
    Return yes
If the remainder of year ÷ 100 is 0 then
    Return no
If the remainder of year ÷ 4 is 0 then
    Return yes
Return no
```

Line by line:

1. It checks the **most specific** rule first, 400. A year divisible by 400 is also divisible by 100 and by 4; if you checked 4 first, 1900 would come out as a leap year.
2. If it got here, it isn't divisible by 400. If it's divisible by 100, it isn't a leap year.
3. If it got here, it isn't divisible by 100. Being divisible by 4 is enough.
4. In every other case, it isn't a leap year.

Steps 5 and 6: this lesson's prediction exercise runs this algorithm with the four years in the table.

## A practical example: the second largest

Problem: "Given a list of scores, return the second highest."

**Step 1 and clarifying questions.** The statement looks clear until you think about the edge cases:

- With `[9, 9, 4]`, is the second highest 9 or 4? It depends on whether you count **positions** or **distinct values**.
- With `[7]` or `[]`, there's no second. What do you return?
- Can scores be negative?

Suppose the answers are: distinct values; if there isn't one, return "doesn't exist"; and yes, scores can be negative.

**Step 3, edge cases and expected outputs:**

| Input | Expected output | Why |
| --- | --- | --- |
| `[5, 9, 4]` | 5 | Normal case |
| `[9, 9, 4]` | 4 | Repeated maximum |
| `[7, 7, 7]` | doesn't exist | All equal |
| `[7]` | doesn't exist | One element |
| `[]` | doesn't exist | Empty |
| `[-3, -8]` | −8 | Negatives |
| `[4, 9]` | 4 | Largest at the end |

**Step 4, algorithm**, using the largest-value pattern twice:

```pseudo
Input: a list of integers
Output: the second highest distinct value, or "doesn't exist"

If the list is empty then
    Return "doesn't exist"
largest ← the largest in the list
second ← none
For each p in the list
    If p ≠ largest then
        If second is none or p > second then
            second ← p
If second is none then
    Return "doesn't exist"
Return second
```

Notice that `second` starts as **none**, not 0. If it started at 0, with `[-3, -8]` it would answer 0, a number that isn't even in the list. Swift has a precise way of representing "none", **optionals**, which you'll study in the Swift stage.

**Step 5, trace** with `[9, 9, 4]`: `largest` = 9. Both 9s are skipped because they equal `largest`. With 4, `second` is none, so `second ← 4`. It returns 4, as expected.

## Common mistakes

> [!error] Designing only for the example in the problem statement
> The example in the statement almost never includes the edge cases. If your algorithm was only tested with it, it isn't verified.

> [!error] Starting from a value that could be a valid answer
> Starting a minimum, a maximum or a "second largest" at 0 fails as soon as the input has negatives. Use a real element or "none".

> [!error] Testing far from the boundaries
> For "greater than or equal to 6", test with 5 and 6. With 3 and 9 you can't tell `≥` from `>`.

> [!error] Resolving an ambiguity silently
> If the statement can be read two ways, ask, or write down your assumption. In an interview, asking is part of what's being evaluated.

````exercise
id: m02-l05-e1
type: comprehension
multiple: true
prompt: An algorithm computes the **average** of a list of grades from 0 to 10. Which of these inputs are edge cases worth testing? Select all that apply.
choices:
  - text: "The empty list, `[]`."
    correct: true
    why: It causes a division by 0 if it isn't guarded.
  - text: "A single grade, `[7]`."
    correct: true
    why: The average should be that grade itself; it checks the minimum count.
  - text: "Grades at the ends of the range, `[0, 10]`."
    correct: true
    why: It checks that 0 counts as data and not as "empty".
  - text: "A normal list, `[7, 8, 9]`."
    correct: false
    why: It's a typical example, and useful, but it isn't an edge case.
  - text: "Grades whose average has decimals, `[7, 8]`, which averages 7.5."
    correct: true
    why: It reveals whether the algorithm uses integer division and loses the .5.
solution: |
  The edge cases are **the empty list** (division by 0), **a single element** (minimum size), **the extremes 0 and 10** (0 sometimes gets confused with "no data") and **a non-whole average** (integer versus decimal division). `[7, 8, 9]` is a good normal example for step 2, but it isn't at any extreme.
````

````exercise
id: m02-l05-e2
type: prediction
lang: pseudo
prompt: Run the lesson's leap-year algorithm on each year and write exactly what gets printed.
code: |
  For each year in [1900, 2000, 2023, 2024]
      If the remainder of year ÷ 400 is 0 then
          Print year, "yes"
      Else if the remainder of year ÷ 100 is 0 then
          Print year, "no"
      Else if the remainder of year ÷ 4 is 0 then
          Print year, "yes"
      Else
          Print year, "no"
output: |
  1900 no
  2000 yes
  2023 no
  2024 yes
hints:
  - "`Print year, \"yes\"` writes the year, a space and the text."
  - 1900 is divisible by 100 but not by 400.
solution: |
  ```output
  1900 no
  2000 yes
  2023 no
  2024 yes
  ```

  - **1900**: not divisible by 400; divisible by 100, so it isn't a leap year.
  - **2000**: divisible by 400; it's a leap year.
  - **2023**: not divisible by 400, 100 or 4.
  - **2024**: not divisible by 400 or 100, but divisible by 4.

  The four years follow the algorithm's four paths; that's how they were chosen. In Swift, `print` with two values separates them with a space:

  ```swift
  for year in [1900, 2000, 2023, 2024] {
      if year % 400 == 0 {
          print(year, "yes")
      } else if year % 100 == 0 {
          print(year, "no")
      } else if year % 4 == 0 {
          print(year, "yes")
      } else {
          print(year, "no")
      }
  }
  ```
````

````exercise
id: m02-l05-e3
type: explain
prompt: |
  A teammate writes this algorithm for "the smallest in a list of integers" and says it works because he tested it with [5, 3, 8] and got 3. Explain why his test isn't enough, which input it fails on and how you'd fix it.
code: |
  smallest ← 0
  For each n in numbers
      If n < smallest then
          smallest ← n
  Print smallest
rubric:
  - "I explained that with [5, 3, 8] the correct result is 3, but the algorithm prints 0."
  - I gave a specific input it fails on and the wrong output it produces.
  - I proposed starting with the first element and handling the empty list.
  - I mentioned that a single example doesn't cover the edge cases.
solution: |
  Your teammate's test **already fails**, actually: with `[5, 3, 8]`, `smallest` starts at 0 and no number is less than 0, so the algorithm prints **0**, not 3. If he thought he saw a 3, he didn't run it by hand. It fails with any list of positive numbers, and with an empty list it prints 0 as if it were real data.

  The cause is starting from a made-up value. The fix:

  ```pseudo
  If numbers is empty then
      Print "no data"
  Else
      smallest ← the first number
      For each n in numbers
          If n < smallest then
              smallest ← n
      Print smallest
  ```

  The general lesson: a test only counts if you compare the real output with the expected one, and one example isn't enough; you need edge cases (empty, one element, all positive, all negative).
````

````exercise
id: m02-l05-e4
type: solve
prompt: |
  Apply steps 1 to 5 of the method to this problem and write out each step:

  > Given a positive integer, decide whether it's a **palindrome**, meaning it reads the same left to right as right to left. For example, 121 and 7 are palindromes; 123 isn't.

  You can reuse the technique from the trace tables lesson for splitting a number into its digits.
starter: |
  1. Understand:
  2. Examples:
  3. Edge cases:
  4. Algorithm:
  5. Trace:
hints:
  - "One idea: build the number backwards digit by digit and compare it with the original."
  - "To add a digit d to the end of a number r: r ← r × 10 + d."
  - Useful edge cases are a single digit, a number that ends in 0 like 120, and a number with an even number of digits like 1221.
rubric:
  - I wrote the input, the output and the precondition (a positive integer).
  - I included at least two examples that are palindromes and one that isn't.
  - My edge cases include a single digit, a number that ends in 0 and one with an even number of digits.
  - The algorithm saves the original number before changing it.
  - I built the trace table for at least one example and the output matches the expected one.
solution: |
  **1. Understand.** Input: an integer n ≥ 1. Output: yes or no. Rule: n is a palindrome if it equals n with its digits reversed.

  **2. Examples.** 121 → yes. 123 → no. 4554 → yes.

  **3. Edge cases.** 7 (one digit) → yes. 120 → no, because reversed it's 021, that is, 21. 1221 (even number of digits) → yes. 10 → no.

  **4. Algorithm.**

  ```pseudo
  Input: an integer n ≥ 1
  Output: yes or no

  original ← n
  reversed ← 0
  While n > 0
      digit ← remainder of n ÷ 10
      reversed ← reversed × 10 + digit
      n ← n ÷ 10, integer division
  If reversed = original then
      Return yes
  Else
      Return no
  ```

  **5. Trace** with 120:

  | Pass | n when checked | digit | reversed | n after |
  | --- | --- | --- | --- | --- |
  | 1 | 120 | 0 | 0 | 12 |
  | 2 | 12 | 2 | 2 | 1 |
  | 3 | 1 | 1 | 21 | 0 |

  `reversed` is 21 ≠ 120: it isn't a palindrome, as expected. Saving `original` is a must: when the loop ends, `n` is 0.
````

````exercise
id: m02-l05-e5
type: design
prompt: |
  A store wants an algorithm that gives change using **as few coins as possible**, with coins worth 10, 5, 2 and 1. Before you write the algorithm, hand in: your clarifying questions, your table of test cases with the expected output, and a two- or three-sentence idea of the algorithm. Then write the pseudocode.
rubric:
  - I asked at least two relevant clarifying questions, for example what happens if the change is 0 or if a kind of coin runs out.
  - My test cases include change of 0, an amount that needs just one coin and one that needs every denomination.
  - The algorithm starts with the largest coin.
  - The pseudocode uses integer division and remainder, or a loop that subtracts, correctly.
  - I checked at least one case with a trace table.
solution: |
  **Clarifying questions**

  - Can the change be 0? I'll assume yes, and the answer is "no coins".
  - Is there an unlimited supply of each coin? I'll assume yes. If not, the problem changes completely.
  - Is the change always a whole number? I'll assume yes.

  **Test cases**

  | Change | Expected coins |
  | --- | --- |
  | 0 | none |
  | 10 | 10 |
  | 18 | 10, 5, 2, 1 |
  | 4 | 2, 2 |
  | 27 | 10, 10, 5, 2 |

  **Idea.** Use as many of the largest coin as fit, and repeat with the next coin on whatever is left. With these denominations, this strategy gives the minimum number of coins.

  ```pseudo
  Input: change, an integer ≥ 0
  Output: how many coins of each kind

  remaining ← change
  For each coin in [10, 5, 2, 1]
      count ← remaining ÷ coin, integer division
      remaining ← remainder of remaining ÷ coin
      If count > 0 then
          Print count, "of", coin
  ```

  Trace with 18: with 10, count 1, remaining 8; with 5, count 1, remaining 3; with 2, count 1, remaining 1; with 1, count 1, remaining 0. Four coins, as expected.

  > [!warning]
  > This strategy, called **greedy**, doesn't give the minimum with every set of coins. With coins of 1, 3 and 4 and change of 6, the greedy strategy gives 4 + 1 + 1 (three coins), but 3 + 3 is two. You'll study when a greedy strategy is correct in the algorithms stage.
````

## Summary

- The six-step method: understand, examples, edge cases, algorithm, trace and verify.
- You look for edge cases on purpose, with a checklist: empty, one, all equal, negatives, boundaries, duplicates.
- Test each condition's boundaries: the last value that fails and the first one that passes.
- Don't start from a made-up value; use a real element or "none".
- When something is ambiguous, ask or write down your assumption before you design.
