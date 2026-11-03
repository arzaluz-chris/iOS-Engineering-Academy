---
id: m01-l01
title: What programming is, and what an algorithm is
description: Before you write code, you need to understand what you're asking the computer to do. Here you define an algorithm, see what makes one correct, and design your first.
module: m01
order: 1
level: beginner
minutes: 40
codeStatus: no-code
objectives:
  - Define in your own words what programming is and what an algorithm is.
  - 'Recognize the three properties of a correct algorithm: precision, finiteness and correctness.'
  - Write an algorithm as numbered steps for an everyday problem.
  - Spot ambiguous instructions in an algorithm someone else wrote.
terms:
  - term: Program
    definition: A set of instructions a computer executes to carry out a task.
  - term: Algorithm
    definition: A finite sequence of precise steps that turns an input into an output.
  - term: Input
    definition: The data the algorithm receives to work with.
  - term: Output
    definition: The result the algorithm produces.
  - term: Edge case
    definition: An input that is valid but extreme or unusual, like an empty list or a negative number.
mastery:
  - Write, without looking at the lesson, a numbered-step algorithm that finds the largest number in a list.
  - Point out which step in someone else's algorithm is ambiguous and rewrite it precisely.
  - Explain why an algorithm that works for one example can still be wrong.
resources: [swift-book-tour]
cards:
  - id: m01-l01-c1
    front: What is an algorithm?
    back: A finite sequence of precise steps that turns an input into an output.
  - id: m01-l01-c2
    front: What are the three properties of a correct algorithm?
    back: "Precision (each step has exactly one meaning), finiteness (it stops) and correctness (it produces the right output for every valid input, not just for one example)."
  - id: m01-l01-c3
    front: Why isn't testing an algorithm with a single example enough?
    back: Because one example doesn't cover the edge cases. An algorithm can work with [3, 7, 5] and fail with an empty list or a list of only negative numbers.
---

## The idea in one sentence

Programming is writing instructions so precise that a machine, which doesn't understand intentions, can follow them without getting anything wrong.

A person can follow "sort these papers" even though it's vague: they guess the criterion, ask, or improvise. A computer doesn't guess. It does exactly what the instructions say, in the order they're written, and nothing else. The whole discipline of programming comes from that difference.

## What an algorithm is, precisely

An **algorithm** is a finite sequence of precise steps that turns an input into an output.

Every word in that definition matters:

- **Sequence**: the steps have an order. Changing the order can change the result.
- **Finite**: the algorithm stops. A procedure that repeats forever isn't a useful algorithm.
- **Precise**: each step has only one possible meaning. "Add a little salt" isn't precise; "add 5 grams of salt" is.
- **Input and output**: the algorithm receives data and produces a result. If you can't say what goes in and what comes out, you don't understand the problem yet.

A **program** is an algorithm written in a language the computer can process, like Swift. The algorithm is the idea; the program is its concrete form. You can have a correct algorithm and a buggy program, or the reverse: a program that compiles perfectly and implements the wrong algorithm.

## An analogy, and where it breaks

A recipe looks a lot like an algorithm. It has ingredients (input), ordered steps and a dish (output).

The analogy works for the idea of order, but it breaks on something important: recipes rely on the cook's judgment ("bake until golden"). An algorithm can't rely on anyone's judgment. When you write steps, ask yourself: could a machine with no common sense carry this out?

## Minimal example: the larger of two numbers

Problem: given two numbers, say which one is larger.

```pseudo
Input: two numbers, a and b
Output: the larger of the two

1. If a is greater than b, the answer is a.
2. Otherwise, the answer is b.
```

## The example, step by step

- **Input**: stating what you receive forces you to think about the kind of data. Here it's numbers, not text or lists.
- **Output**: stating what you return defines when you're done.
- **Step 1**: compares and decides. It's precise: "greater than" has only one meaning for numbers.
- **Step 2**: covers every other case. Notice that if `a` and `b` are equal, the answer is `b`, which is also the largest. The algorithm is correct even in that edge case, but only because we checked.

## A practical example: the largest in a list

Now the input is a list of grades, of any size.

```pseudo
Input: a list of grades
Output: the highest grade, or "no data" if the list is empty

1. If the list is empty, the answer is "no data". Stop.
2. Save the first grade as "largest so far".
3. For each remaining grade, in order:
   3.1 If it's greater than "largest so far", replace "largest so far" with it.
4. The answer is "largest so far".
```

Two decisions in this algorithm are what separate someone who programs carefully from someone who doesn't:

- **Step 1** exists because an empty list has no first grade. Without it, step 2 makes no sense.
- **Step 2** starts with the first grade, not with 0. If you started at 0 and every value were negative (think temperatures instead of grades), the algorithm would answer 0, a value that isn't even in the list.

## What makes an algorithm correct

An algorithm is **correct** if it produces the expected output for **every** valid input. Not for the input you tested it with: for all of them.

That's why, before you program, you ask about the **edge cases**: the empty list, a list with one element, repeated values, negative values, very large values. You'll ask this in every exercise and in every technical interview.

## Common mistakes

> [!error] Steps that depend on the reader's judgment
> "Check whether the number is big" isn't a step: big compared to what? Replace it with a concrete comparison: "if the number is greater than 100".

> [!error] Testing only with the example from the problem statement
> If your algorithm works with `[3, 7, 5]`, you still don't know whether it works with `[]`, with `[4]` or with `[-2, -9]`. Always test the edge cases.

> [!error] Starting from a made-up value
> Starting "the largest" at 0 looks harmless and fails with negative numbers. Start with a real element from the input.

````exercise
id: m01-l01-e1
type: comprehension
prompt: Which of these instructions is an **algorithm** by this lesson's definition?
choices:
  - text: "Look over the list and keep the numbers that seem important."
    correct: false
    why: "\"Seem important\" depends on the reader's judgment. It isn't precise."
  - text: "For each number in the list, if it's even, add it to a total that starts at 0. When the list is done, the answer is the total."
    correct: true
    why: Every step has one meaning, it stops when the list runs out, and it defines input and output.
  - text: "Repeat: add 1 to a counter."
    correct: false
    why: It doesn't say when to stop. It isn't finite.
  - text: "Find the best solution to the problem."
    correct: false
    why: It doesn't describe steps; it describes a wish.
solution: |
  Only the second option has all three properties: **precision** ("if it's even" has exactly one meaning), **finiteness** (it stops after going through the list), and it defines an **input** (a list) and an **output** (the total). The others fail on precision or finiteness, or don't describe steps at all.
````

````exercise
id: m01-l01-e2
type: comprehension
prompt: An algorithm for finding the day's highest temperature starts with "largest so far = 0" and then compares each reading. With the readings `[-5, -2, -8]`, what does it answer?
choices:
  - text: "-2"
    correct: false
    why: That would be the right answer, but the algorithm never replaces the 0 because no reading is greater than 0.
  - text: "0"
    correct: true
    why: No reading beats the starting value, so the answer is 0, which isn't even in the list.
  - text: "-8"
    correct: false
    why: The algorithm looks for the largest, not the smallest.
solution: |
  It answers **0**. No reading is greater than the starting value, so the algorithm never replaces it. The algorithm is **wrong**: it works with positive temperatures and fails with negative ones. The fix is to start with the first real reading, after checking that the list isn't empty.
````

````exercise
id: m01-l01-e3
type: design
prompt: |
  Design an algorithm as numbered steps, like the ones in this lesson, for this problem:

  **Input:** a list of product prices in a shopping cart.
  **Output:** the total to pay. If the total is greater than 1000, a 10% discount applies.

  State the input and output, and write down the edge cases your algorithm has to handle.
hints:
  - Start by deciding what you do if the cart is empty.
  - Add everything up first; decide on the discount at the end, once.
  - What happens if the total is exactly 1000? Decide, and write it into your algorithm.
rubric:
  - I stated the input and the output.
  - Every step has only one possible meaning.
  - The algorithm stops.
  - I handled the empty cart.
  - I said explicitly what happens when the total is exactly 1000.
  - I applied the discount once, after adding everything up.
solution: |
  ```pseudo
  Input: a list of prices (may be empty)
  Output: the total to pay

  1. Save 0 as "total".
  2. For each price in the list, in order:
     2.1 Add the price to "total".
  3. If "total" is greater than 1000:
     3.1 Replace "total" with "total" multiplied by 0.9.
  4. The answer is "total".
  ```

  - **Empty cart**: step 2 never runs and the answer is 0, which is correct. Here starting at 0 *is* valid, because 0 really is the total when you buy nothing.
  - **Total equal to 1000**: with "greater than", there's no discount. The problem says "greater than 1000", so that's the right reading. In an interview, this is exactly the question to ask: "Is the limit inclusive?"
  - **Discount at the end**: applying it inside the loop would discount several times, or make the result depend on the order of the products.
````

## Summary

- Programming is writing unambiguous instructions for a machine that doesn't interpret intentions.
- An algorithm is a finite sequence of precise steps that turns an input into an output.
- An algorithm is correct only if it works for every valid input; edge cases are where it usually fails.
- Before you write code, state the input, the output and the edge cases.
