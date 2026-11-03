---
id: p01
number: 1
title: Command-Line Expense Tracker
summary: A command-line app for logging expenses, sorting them into categories and getting summaries. You practice variables, conditionals, functions, collections and optionals with no graphical interface.
prerequisites: [m04, m05, m06, m07, m08]
objectives:
  - Break a program into small functions with clear inputs and outputs.
  - Choose between Array, Set and Dictionary based on the operation.
  - Validate text the user types and handle invalid input without stopping the program.
requirements:
  - "Commands: add, list, total, by-category, quit."
  - Each expense has a description, an amount in cents (Int) and a category.
  - "Invalid amounts (text, negative numbers, zero) are rejected with a clear message."
  - "The per-category summary shows each category's total, sorted from highest to lowest."
acceptance:
  - Typing "abc" as an amount shows an error and the program keeps running.
  - The total matches the sum of the listed expenses.
  - No line in the program uses force unwrapping.
  - The calculation functions have Swift Testing tests that pass with `swift test`.
milestones:
  - id: p01-h1
    title: Create the executable package
    tasks: ["Run `swift package init --type executable` and build the sample.", "Move the logic you're going to test into a library target."]
    concepts: [Swift Package Manager, swift run]
  - id: p01-h2
    title: Model an expense and the expense list
    tasks: ["Define an expense with a description, an amount in cents and a category.", "Write a function that returns the total."]
    concepts: [Collections, Functions]
  - id: p01-h3
    title: Read and validate commands
    tasks: ["Read lines with readLine() and handle its optional result.", "Convert the amount with Int(_:) and reject invalid values."]
    concepts: [Optionals, guard let, Validation]
  - id: p01-h4
    title: Per-category summary
    tasks: ["Group with a Dictionary from category to total.", "Sort by total, descending."]
    concepts: [Dictionary, sorted(by:)]
  - id: p01-h5
    title: Tests
    tasks: ["Write tests for the total, amount validation and the summary.", "Include edge cases: an empty list, a single category."]
    concepts: [Swift Testing, Edge cases]
---

## Why amounts are in cents

Binary floating-point numbers (`Double`) can't represent values like 0.1 exactly. Adding up money with `Double` piles up rounding errors. Storing cents in an `Int` avoids the problem; to display an amount, you divide by 100 when you format it. Real apps use `Decimal`, which you'll see later.

## How to work through this project

Go milestone by milestone. When you finish one, run the tests and make a commit. There's no complete solution to copy: if you get stuck on a milestone, go back to the lesson for the concept it lists.
