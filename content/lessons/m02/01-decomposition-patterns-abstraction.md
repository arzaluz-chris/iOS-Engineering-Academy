---
id: m02-l01
title: "Decomposition, pattern recognition and abstraction"
description: Three tools for attacking a problem you don't know how to solve yet. You split a big problem into subproblems, notice you've already solved something similar, and keep only the data that matters.
module: m02
order: 1
level: beginner
minutes: 45
prerequisites: [m01-l01]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Decompose a problem into small subproblems, each with its own input and output.
  - Recognize when a new problem has the same structure as one you've already solved.
  - Abstract a problem by separating the data that matters from the details that don't.
  - Name reusable subproblems as procedures with an input and an output.
terms:
  - term: Computational thinking
    definition: A way of framing a problem so that a person or a computer can solve it with an algorithm. It includes decomposition, pattern recognition, abstraction and algorithm design.
  - term: Decomposition
    definition: Splitting a problem into smaller subproblems that can be solved and checked separately.
  - term: Subproblem
    definition: A part of a bigger problem with its own input and its own output.
  - term: Pattern
    definition: A structure that repeats across different problems. For example, "walk through a list accumulating a total" shows up when you add prices, count votes or compute an average.
  - term: Abstraction
    definition: Keeping the data and rules that matter for solving the problem and ignoring the details that don't change the result.
  - term: Procedure
    definition: A subproblem with a name, an input and an output that you can use many times. In Swift you write it as a function.
mastery:
  - Decompose an everyday problem in writing into at least three subproblems, stating each one's input and output.
  - Point out what two differently worded problems have in common and reuse the solution of one in the other.
  - Rewrite a long problem statement as input, output and rules, dropping the irrelevant details.
  - Explain why a well-defined subproblem can be tested on its own.
resources: [swift-book-tour]
cards:
  - id: m02-l01-c1
    front: What does it mean to decompose a problem?
    back: To split it into smaller subproblems, each with its own input and output, that can be solved and checked separately.
  - id: m02-l01-c2
    front: What is abstraction in computational thinking?
    back: Keeping the data and rules that change the result and ignoring the details that don't.
  - id: m02-l01-c3
    front: "What pattern do \"add up prices\", \"count votes\" and \"compute an average\" share?"
    back: "Walking through a list accumulating a result: start with an initial value and update it with each element."
  - id: m02-l01-c4
    front: How do you know a subproblem is well defined?
    back: You can say exactly what it receives and what it returns, and check it with an example without looking at the rest of the problem.
---

## The idea in one sentence

A problem you don't know how to solve is usually several problems you do know how to solve, tangled together. The tools in this lesson are for untangling them.

## Computational thinking

**Plain definition:** thinking about a problem so it can be solved with precise steps.

**Precise definition:** computational thinking brings together four practices that you use together:

| Practice | Question it answers |
| --- | --- |
| Decomposition | What smaller parts does the problem split into? |
| Pattern recognition | Have I already solved something with the same structure? |
| Abstraction | Which data matters and which can I ignore? |
| Algorithm design | What precise steps solve each part? |

This lesson works on the first three. Algorithm design, with pseudocode, flowcharts and trace tables, takes up the rest of the module.

You don't need a computer for any of this. An experienced programmer spends a good part of their time here, before opening Xcode.

## Decomposition

**Plain definition:** breaking a big problem into small ones.

**Technical explanation:** each subproblem needs a clear **input** and **output**. If you can't say what it receives and what it hands back, it isn't a subproblem yet; it's a topic. The output of one subproblem is often the input of the next.

### Minimal example: splitting a restaurant bill

Problem: four people eat together, the bill is $200 and they want to leave a 10% tip. How much does each person pay?

```pseudo
Problem: how much each person pays

1. Compute the tip.            Input: bill, percentage.     Output: tip.
2. Compute the total.          Input: bill, tip.            Output: total.
3. Split the total.            Input: total, people.        Output: amount per person.
```

Line by line:

1. The first subproblem only knows about percentages: 10% of 200 is 20. It doesn't care how many people there are.
2. The second only adds: 200 + 20 = 220. It receives the output of step 1.
3. The third only divides: 220 ÷ 4 is 55. It receives the output of step 2.

Each subproblem is small enough to check with a calculator. If the final result is wrong, you know where to look: you check each step separately instead of the whole problem at once.

### A practical example: a shopping list app

A real problem rarely shows up this tidy. "I want an app that tells me how much I'll spend at the grocery store" breaks down like this:

```pseudo
Problem: estimate the grocery bill

1. Record products.            Input: name, price, quantity.   Output: list of products.
2. Compute one item's cost.    Input: price, quantity.         Output: cost of the item.
3. Add up all the costs.       Input: list of costs.           Output: subtotal.
4. Apply discounts.            Input: subtotal, discount.      Output: total.
5. Show the result.            Input: total.                   Output: text on screen.
```

Notice two things. Step 2 is used once **per product**: it's a reusable procedure. And step 5 is the only one that knows a screen exists; the others would work the same in an app, in the terminal or in a spreadsheet. Separating the calculation from the presentation is a decision you'll see again and again in iOS app architecture.

## Named subproblems: procedures

When a subproblem is used several times, give it a **name**. "Compute one item's cost" is a procedure: it receives a price and a quantity and returns a cost. You describe it once and use it as many times as you need.

In Swift, a named procedure is written as a **function**. You'll study functions in Module 6; for now, the skill is spotting them in the problem. A hint: if, while describing your solution, you say "and then I do the same thing again for…", there's a procedure there.

## Pattern recognition

**Plain definition:** noticing that a new problem looks like one you've already solved.

**Technical explanation:** two problems share a pattern when they have the same **structure** of input, process and output, even if the data is different. These three problems are the same problem:

| Problem | Input | Starting accumulator | With each element |
| --- | --- | --- | --- |
| Total of a purchase | list of prices | 0 | add the price |
| "Yes" votes | list of votes | 0 | add 1 if the vote is "yes" |
| Highest grade | list of grades | the first grade | keep the larger one |

All three walk through a list and update a value with each element. That pattern is called an **accumulator**, and it's probably the most used pattern in the whole course. You saw it in the lesson "What programming is" with "largest so far".

Recognizing the pattern has a concrete payoff: you also inherit the **edge cases** you already know. If you know "the largest in a list" fails on an empty list, you'll suspect the same of "the average of a list".

## Abstraction

**Plain definition:** keeping only what matters.

**Technical explanation:** abstracting means deciding which data and which rules change the result. Everything else comes out of the problem statement. Compare:

> Mariana is organizing a meal at an Italian restaurant downtown on Saturday. She's going with her brother and two friends from college. The bill is $200 and they want to leave a 10% tip. How much does each of them pay?

Abstracted, the problem looks like this:

```pseudo
Input: bill = 200, tip percentage = 10, people = 4
Output: amount per person
Rule: (bill + bill × percentage ÷ 100) ÷ people
```

The restaurant, the day and the names don't change the result. The number of people **does**, even though the statement hides it in "she's going with her brother and two friends".

### Where abstraction goes too far

Abstracting too much is also a mistake. If you drop a piece of data that does matter, your solution will be correct for a problem that isn't yours. For example, if the restaurant adds a fixed service charge, "Italian restaurant" still doesn't matter, but "service charge" does. The question for every piece of data is always the same: **if this changes, does the answer change?**

## Common mistakes

> [!error] Subproblems with no input or output
> "Do the discounts part" isn't a subproblem. "Apply a discount: receives a subtotal and a percentage, returns a total" is. If you can't write its input and output, you don't understand it yet.

> [!error] Steps that are too big
> "1. Compute everything. 2. Show it." doesn't help. Keep splitting until each step can be checked with an example in under a minute.

> [!error] Mixing the calculation with the presentation
> If "compute the total" also decides how it looks on screen, you can't reuse the calculation elsewhere or test it on its own.

> [!error] Dropping data that matters
> When you abstract, ask of every piece of data whether it changes the answer. "Four people" hidden in a long problem statement is easy to lose.

````exercise
id: m02-l01-e1
type: comprehension
multiple: true
prompt: |
  Problem: "Laura runs in a park in Denver on Mondays, Wednesdays and Fridays. This week she ran 5, 7 and 6 kilometers. On average, how many kilometers did she run per training day?"

  Which data do you need to solve it? Select all that apply.
choices:
  - text: The distances 5, 7 and 6.
    correct: true
    why: They're the input to the calculation.
  - text: The number of training days, 3.
    correct: true
    why: The average divides by the number of days. Here it happens to equal the number of distances.
  - text: That the park is in Denver.
    correct: false
    why: If the park were in another city, the average would be the same.
  - text: That the days are Monday, Wednesday and Friday.
    correct: false
    why: The names of the days don't change the result; only how many there are matters.
solution: |
  Only **the distances** and **how many days** matter. The deciding question is: if this data changes, does the answer change? The city and the names of the days don't change it.

  Abstracted, the problem is: input, a list of distances; output, their sum divided by the number of distances. It's the accumulator pattern plus a division: (5 + 7 + 6) ÷ 3 = 6.
````

````exercise
id: m02-l01-e2
type: prediction
lang: pseudo
prompt: Follow the algorithm with the given data and write exactly what it prints, one line per "Print". All arithmetic uses whole numbers.
code: |
  Data: bill = 200, percentage = 10, people = 4

  1. tip ← bill × percentage ÷ 100
  2. total ← bill + tip
  3. perPerson ← total ÷ people
  4. Print tip
  5. Print total
  6. Print perPerson
output: |
  20
  220
  55
hints:
  - "The arrow ← means \"store the result in\"."
  - "Step 1: 200 × 10 = 2000; 2000 ÷ 100 = 20."
solution: |
  ```output
  20
  220
  55
  ```

  1. `tip` = 200 × 10 ÷ 100 = 20.
  2. `total` = 200 + 20 = 220.
  3. `perPerson` = 220 ÷ 4 = 55.
  4. to 6. The three values are printed in that order.

  Each step is one of the subproblems from the lesson. Here's how it looks in Swift; you'll learn it in Module 4, and the course tests run this translation to check the output:

  ```swift
  let bill = 200
  let percentage = 10
  let people = 4

  let tip = bill * percentage / 100
  let total = bill + tip
  let perPerson = total / people
  print(tip)
  print(total)
  print(perPerson)
  ```
````

````exercise
id: m02-l01-e3
type: comprehension
prompt: |
  Which of these problems has **the same structure** as "compute the total of a purchase from a list of prices"?
choices:
  - text: Count how many students passed, from a list of grades.
    correct: true
    why: "Same accumulator pattern: start at 0 and, for each passing grade, add 1."
  - text: Sort a list of names alphabetically.
    correct: false
    why: Sorting rearranges the elements; it doesn't reduce the list to a single value.
  - text: Check whether a password has at least 8 characters.
    correct: false
    why: It's a single comparison; it doesn't walk through a list accumulating a result.
  - text: Convert a temperature from Celsius to Fahrenheit.
    correct: false
    why: It transforms a single value; there's no list to walk through.
solution: |
  **Counting passing students** shares the accumulator pattern: a starting value (0) that gets updated with each element of the list. The only difference is the update rule: for the total you add the price; for the count you add 1 only if the grade is a passing one.

  Recognizing it gets you the solution almost for free, and it also reminds you of the edge case: with an empty list, the count is 0, just like the total.
````

````exercise
id: m02-l01-e4
type: solve
prompt: |
  Decompose this problem into subproblems. For each one, write its name, its input and its output, as in the shopping list example.

  > A gym app records the week's sessions (date, minutes and type of exercise). At the end of the week it has to tell you how many minutes you trained in total, what your longest session was, and whether you hit your weekly minutes goal.

  Then say which subproblem looks like one you already know, and which data in the statement isn't needed for these three answers.
starter: |
  1. Name:        Input:        Output:
hints:
  - The three final questions are three different outputs. Each one can be a subproblem.
  - "\"Longest session\" is the same pattern as \"highest grade\"."
rubric:
  - There are at least three subproblems and each has an explicit input and output.
  - "\"Total minutes\" is solved with an accumulator that starts at 0."
  - "\"Longest session\" is solved with the largest-value pattern and considers what happens if there were no sessions."
  - "\"Goal met\" receives the total minutes and the goal, and returns yes or no."
  - I said that the date and the type of exercise aren't needed for these three answers.
solution: |
  ```pseudo
  1. Add up minutes.      Input: list of sessions.            Output: total minutes.
  2. Longest session.     Input: list of sessions.            Output: the session with the most minutes, or "no sessions".
  3. Check the goal.      Input: total minutes, goal.         Output: yes if total ≥ goal; no otherwise.
  4. Show results.        Input: the three outputs above.     Output: text on screen.
  ```

  - Subproblem 1 is the **accumulator** from the purchase total: start at 0 and add each session's minutes.
  - Subproblem 2 is the **largest in a list**, with its edge case: if there were no sessions, there's no longest session.
  - Subproblem 3 depends on the output of 1. If 1 is well tested, 3 is a single comparison.
  - The **date** and the **type of exercise** don't change any of the three answers. They're stored because other features of the app might use them, but they don't go into this calculation.
````

````exercise
id: m02-l01-e5
type: explain
prompt: Someone decomposed a problem like this. Explain what's wrong with the decomposition and how you'd improve it.
code: |
  Problem: compute a class's average grade and show it

  1. Do the calculations.
  2. Show the average with two decimal places, in red if it's below 6.
rubric:
  - I pointed out that step 1 is too big and has no input or output.
  - I split the sum, the count and the division into their own subproblems.
  - I pointed out that step 2 mixes a decision (whether the class failed) with presentation (color, decimals).
  - I mentioned the case of a class with no grades.
solution: |
  **Step 1** isn't a subproblem: "do the calculations" doesn't say what it receives or what it hands back, and you can't check it with an example. Split it:

  ```pseudo
  1. Add up grades.          Input: list.               Output: sum.
  2. Count grades.           Input: list.               Output: count.
  3. Compute the average.    Input: sum, count.         Output: average, or "no data" if the count is 0.
  4. Decide if it passes.    Input: average.            Output: yes if the average ≥ 6.
  5. Show.                   Input: average, passes.    Output: text with two decimals and a color.
  ```

  **Step 2** mixes the business rule (is the average a passing one?) with how it looks on screen. Separating them lets you test the rule without an interface and change the color without touching the calculation.

  Step 3 brings out an edge case the original version hid: a class with no grades would mean dividing by 0.
````

````exercise
id: m02-l01-e6
type: design
prompt: |
  Abstract this problem statement: write only the input, the output and the rules, with no detail that doesn't change the result.

  > The Grand movie theater in Springfield sells tickets for $12. On Tuesdays it's buy one, get one free. Students with an ID pay $8 any day, but that can't be combined with the Tuesday deal. Andrea wants to go on Tuesday with three classmates from high school; all of them have a student ID. How much do they pay in total, if they pick the cheapest option?
rubric:
  - The input includes the number of people, whether it's Tuesday and how many have a student ID.
  - I wrote both pricing rules and that they can't be combined.
  - The output is the cheapest total among the valid options.
  - I dropped the name of the theater, the city and the people's names.
  - I computed the answer for the specific case.
solution: |
  ```pseudo
  Input: people, isTuesday, peopleWithID
  Prices: general = 12, student = 8
  Output: the cheapest total

  Option A (buy one get one, Tuesdays only): pay for people ÷ 2 general tickets, rounding up.
  Option B (student ID): peopleWithID × 8 + (people − peopleWithID) × 12.
  The options can't be combined. Total = the smaller of the valid options.
  ```

  Specific case: 4 people, it's Tuesday, 4 with an ID. Option A: 2 tickets × 12 = 24. Option B: 4 × 8 = 32. They pay **$24**.

  The theater, the city, the names and "classmates from high school" don't change the result. "All of them have a student ID" does matter, which is why the input includes it as a number. The "rounding up" in option A is a rule the statement doesn't spell out for odd-sized groups; abstracting surfaces the questions you need to ask whoever requested the program.
````

## Summary

- Computational thinking: decomposition, pattern recognition, abstraction and algorithm design.
- A subproblem has an explicit input and output and can be checked on its own.
- A subproblem you use several times is a named procedure; in Swift, a function.
- The accumulator pattern (a starting value updated with each element) solves totals, counts and maximums.
- Abstracting means keeping what changes the answer. Ask of every piece of data: if it changes, does the result change?
- Separate the calculation from the presentation from the design stage on.
