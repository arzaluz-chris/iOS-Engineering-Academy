---
id: m02-l03
title: Flowcharts
description: You draw an algorithm so you can see all its paths at a glance. You learn the symbols, how decisions and loops are drawn, and how to go from a flowchart to pseudocode and back.
module: m02
order: 3
level: beginner
minutes: 40
prerequisites: [m02-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Recognize the basic flowchart symbols and what they mean.
  - Draw the flowchart of an algorithm with decisions and loops.
  - Turn a flowchart into pseudocode and pseudocode into a flowchart.
  - Count an algorithm's possible paths from its flowchart.
terms:
  - term: Flowchart
    definition: A graphical representation of an algorithm in which each step is a shape and arrows show the order of execution.
  - term: Terminal
    definition: An oval that marks the start or the end of the algorithm.
  - term: Process
    definition: A rectangle that represents an operation or an assignment, like "total ← total + p".
  - term: Decision
    definition: A diamond with a condition; two arrows come out of it, one for "yes" and one for "no".
  - term: Input/output
    definition: A parallelogram that represents reading a value or printing a result.
  - term: Path
    definition: A specific sequence of shapes followed from start to end for a given input.
mastery:
  - Draw, without looking at the lesson, the flowchart of an algorithm with a decision and a loop.
  - Translate a one-page flowchart into pseudocode using the course's conventions.
  - Point out which arrow in a flowchart forms a loop and which condition ends it.
  - Propose an input that follows each path of a flowchart with one or two decisions.
resources: [swift-book-control-flow]
cards:
  - id: m02-l03-c1
    front: Which shape represents a decision in a flowchart, and how many exits does it have?
    back: A diamond. It has two exits, one for "yes" (true) and one for "no" (false).
  - id: m02-l03-c2
    front: What does a loop look like in a flowchart?
    back: An arrow that goes back to an earlier shape, usually to the decision that asks whether to repeat.
  - id: m02-l03-c3
    front: Why count the paths in a flowchart?
    back: To choose test cases. Each path needs at least one input that follows it; if a path is never tested, its bugs go unnoticed.
---

## The idea in one sentence

A flowchart is a map of the algorithm: it shows all its paths at once, which text tends to hide.

## When a flowchart is worth it

Pseudocode reads top to bottom. When an algorithm has several decisions, or a loop with several exits, following the text means holding a lot in your head. A flowchart shows the paths at a glance.

Not everything deserves a flowchart. For three steps in a row, drawing is slower than writing. A flowchart pays for itself when there are nested decisions or loops, or when you need to explain the algorithm to someone who doesn't program.

## The symbols

There's an international standard for these symbols (ISO 5807), but in practice almost everyone uses just these five:

| Shape | Name | Meaning |
| --- | --- | --- |
| Oval | Terminal | Start or end |
| Rectangle | Process | An operation or assignment |
| Diamond | Decision | A condition with a "yes" exit and a "no" exit |
| Parallelogram | Input/output | Read a value or print a result |
| Arrow | Flow | Which shape comes next |

In this course, flowcharts are written as text so you can copy and edit them. The shapes look like this:

```plaintext
( Start )          oval: terminal
[ total ← 0 ]      rectangle: process
< n > 0? >         diamond: decision
/ Print n /        parallelogram: input/output
```

On paper or a whiteboard, draw the real shapes.

## Minimal example: even or odd

The algorithm from the previous lesson, as a flowchart:

```plaintext
        ( Start )
            |
            v
        / Read n /
            |
            v
  < remainder of n ÷ 2 = 0? >
       |yes           |no
       v              v
  / Print      /  / Print      /
  / "even"     /  / "odd"      /
       |              |
       +------+-------+
              |
              v
          ( End )
```

Line by line:

1. **Start**: every flowchart has exactly one start.
2. **Read n**: the algorithm's input, a parallelogram.
3. **The diamond** asks a yes-or-no question. Exactly two arrows come out of it, each with its label.
4. **Each branch** prints a different text.
5. **The branches join** before the end. A flowchart can have several end shapes, but joining the branches makes it clear that whichever path it takes, the algorithm ends.

This flowchart has **two paths**: one for even numbers and one for odd ones. Two inputs are enough to test it, for example 4 and 7.

## Loops: an arrow that goes back

A loop shows up as an arrow that **goes back** to an earlier shape. This flowchart corresponds to a `While`:

```plaintext
        ( Start )
            |
            v
       [ n ← 10 ]
            |
            v
   +--> < n > 0? > --no--> ( End )
   |        |yes
   |        v
   |   / Print n /
   |        |
   |        v
   |   [ n ← n − 4 ]
   |        |
   +--------+
```

The condition comes **before** the body: if `n` started at 0, the algorithm would end without printing anything. That's exactly how a `While` works. The arrow that goes back leaves from the last process in the body, `n ← n − 4`, which is what moves the condition toward false.

## A practical example: three PIN attempts

An ATM asks for your PIN and allows at most three attempts.

```plaintext
           ( Start )
               |
               v
       [ attempts ← 0 ]
               |
               v
  +-----> / Read pin /
  |            |
  |            v
  |    [ attempts ← attempts + 1 ]
  |            |
  |            v
  |     < pin correct? > --yes--> / Print "Welcome" / --> ( End )
  |            |no
  |            v
  |     < attempts < 3? > --no--> / Print "Card retained" / --> ( End )
  |            |yes
  +------------+
```

The same algorithm in pseudocode:

```pseudo
attempts ← 0
Repeat
    Read pin
    attempts ← attempts + 1
    If pin is correct then
        Print "Welcome"
        Stop
    If attempts = 3 then
        Print "Card retained"
        Stop
```

Notice things in the flowchart that take more effort to see in the text:

- There are **two exits** from the loop, one for success and one for running out of attempts.
- The loop has a **guaranteed limit**: `attempts` goes up on every pass and the second decision cuts it off at 3. Even if the person never gets it right, the algorithm ends.
- There are **four** different paths: getting it right on the first, second or third attempt, or failing three times. A good set of tests covers all four.

> [!tip]
> In a real app, the attempt counter can't live only on the phone: someone could restart the app to get more attempts. Security rules are enforced on the server or in a protected component. You'll study this in the secure development module.

## Common mistakes

> [!error] A diamond with only one exit, or without labels
> Every decision has two exits, "yes" and "no", and both must be labeled. An unlabeled arrow forces the reader to guess.

> [!error] Loops with no way out
> Follow the arrow that goes back: if no process along that path changes something in the condition, the loop never ends.

> [!error] Arrows that cross for no reason
> If the flowchart turns into a tangle, rearrange the shapes or split the algorithm into named procedures, each with its own flowchart.

> [!error] Drawing every line of code
> A flowchart with a hundred shapes helps nobody. Group consecutive steps into a single rectangle and leave the detail for the pseudocode.

````exercise
id: m02-l03-e1
type: comprehension
prompt: In a flowchart, which shape would you use for "is the balance enough for the withdrawal?"
choices:
  - text: Rectangle
    correct: false
    why: The rectangle is for processes, like subtracting the withdrawal from the balance.
  - text: Diamond
    correct: true
    why: It's a yes-or-no question; it will have two exits.
  - text: Parallelogram
    correct: false
    why: The parallelogram is for reading values or printing results.
  - text: Oval
    correct: false
    why: The oval marks the start or the end.
solution: |
  A **diamond**, because it's a decision: the answer is yes or no and the algorithm continues along different paths depending on it. Two arrows come out of the diamond, "yes" toward the withdrawal and "no" toward an insufficient-balance message.
````

````exercise
id: m02-l03-e2
type: prediction
lang: pseudo
prompt: Follow the loop flowchart from the lesson and write exactly what it prints.
code: |
  ( Start ) --> [ n ← 10 ]
                    |
                    v
           +--> < n > 0? > --no--> ( End )
           |        |yes
           |        v
           |   / Print n /
           |        |
           |        v
           |   [ n ← n − 4 ]
           |        |
           +--------+
output: |
  10
  6
  2
hints:
  - After printing 2, n is −2. Is n > 0 true?
solution: |
  ```output
  10
  6
  2
  ```

  | Pass | n when checked | n > 0? | Prints | n after |
  | --- | --- | --- | --- | --- |
  | 1 | 10 | yes | 10 | 6 |
  | 2 | 6 | yes | 6 | 2 |
  | 3 | 2 | yes | 2 | −2 |
  | 4 | −2 | no | — | — |

  The loop doesn't stop at exactly 0: it stops the first time the condition is false, and that happens at −2. Here's the Swift version:

  ```swift
  var n = 10
  while n > 0 {
      print(n)
      n = n - 4
  }
  ```
````

````exercise
id: m02-l03-e3
type: explain
prompt: Translate this flowchart into pseudocode using the course's conventions, and explain what it computes.
code: |
  ( Start ) --> / Read age /
                     |
                     v
              < age ≥ 18? > --yes--> / Print "General" / ----+
                     |no                                     |
                     v                                       |
              < age ≥ 12? > --yes--> / Print "Teen" / -------+
                     |no                                     |
                     v                                       |
              / Print "Child" / -----------------------------+
                                                             |
                                                             v
                                                         ( End )
rubric:
  - My pseudocode has a decision nested inside the "Else" of the first one.
  - The conditions are in the same order as in the flowchart.
  - I explained that it sorts an age into three categories.
  - I said which category exactly 12 and exactly 18 fall into.
solution: |
  ```pseudo
  Input: age
  Output: the ticket category

  If age ≥ 18 then
      Print "General"
  Else
      If age ≥ 12 then
          Print "Teen"
      Else
          Print "Child"
  ```

  It sorts an age into three categories: 18 or older is General; 12 to 17, Teen; under 12, Child. Exactly 12 prints "Teen" and exactly 18 prints "General", because the conditions use `≥`.

  The order matters: the second question is only asked if the first answered "no", so "age ≥ 12" really means "12 to 17". If you swapped the order, a 30-year-old would get "Teen". The flowchart has three paths; three ages are enough to test it, and it pays to pick the boundaries: 11, 12, 17 and 18.
````

````exercise
id: m02-l03-e4
type: solve
prompt: |
  Draw, as text and using the course's notation, the flowchart of this algorithm:

  Read grades one at a time. If the grade is outside the range 0 to 10, print "invalid" and ask for it again. Once it's valid, print "pass" if it's 6 or higher and "fail" otherwise.

  Then say how many paths it has and propose an input for each one.
starter: |
  ( Start )
      |
      v
hints:
  - The validation is a loop; the arrow from "invalid" goes back to reading.
  - "Out of range means less than 0 or greater than 10. You can use two diamonds or one with \"or\"."
rubric:
  - It has a single start, and the exits reach an end.
  - Every diamond has two exits labeled yes and no.
  - The arrow from "invalid" goes back to reading the grade.
  - The pass/fail decision is only reached with a valid grade.
  - I proposed inputs that follow each path, including the boundaries 0, 6 and 10.
solution: |
  ```plaintext
            ( Start )
                |
                v
     +--> / Read g /
     |          |
     |          v
     |   < g < 0 or g > 10? > --no--> < g ≥ 6? > --yes--> / Print "pass" / --+
     |          |yes                       |no                               |
     |          v                          v                                 |
     +-- / Print "invalid" /       / Print "fail" / -------------------------+
                                                                             |
                                                                             v
                                                                         ( End )
  ```

  Paths and test inputs:

  1. Valid and passing: `8`. Boundaries: `6` and `10`.
  2. Valid and failing: `3`. Boundaries: `0` and `5`.
  3. Invalid, then valid: `11` and then `7`; `-1` and then `4`.

  The third path is a loop: it can go around several times. Test at least one invalid input on each side of the range.
````

````exercise
id: m02-l03-e5
type: design
prompt: |
  Design the flowchart of a vending machine that sells one product for 15 and accepts coins worth 1, 2, 5 and 10. It has to ask for coins until it has at least 15, reject any other coin, and at the end print the change. Also write a list of the paths you'd test.
rubric:
  - There's an accumulator for the money inserted, starting at 0.
  - Invalid coins are rejected without being added, and the loop continues.
  - The loop ends when the accumulated amount is greater than or equal to 15.
  - The change is computed as accumulated − 15 and printed.
  - The test cases include exact payment, payment with change and a rejected coin.
solution: |
  ```plaintext
          ( Start )
              |
              v
        [ paid ← 0 ]
              |
              v
  +--> < paid < 15? > --no--> [ change ← paid − 15 ] --> / Print change / --> ( End )
  |           |yes
  |           v
  |     / Read coin /
  |           |
  |           v
  |   < coin is 1, 2, 5 or 10? > --no--> / Print "Coin rejected" / ---+
  |           |yes                                                    |
  |           v                                                       |
  |   [ paid ← paid + coin ]                                          |
  |           |                                                       |
  +-----------+-------------------------------------------------------+
  ```

  Test cases:

  - Exact payment: 10 and 5. Change 0.
  - Payment with change: 10, 2 and 5. Paid 17, change 2.
  - Rejected coin: 20 (rejected), then 10 and 5. Change 0.
  - Lots of small coins: fifteen coins of 1. The loop goes around fifteen times.

  The loop always ends as long as the person keeps inserting valid coins, because each one increases `paid`. What if they stop inserting coins? That case isn't in the flowchart: a real machine needs a cancel button that returns what was paid. Finding gaps like this is exactly what designing before programming is for.
````

## Summary

- Oval for start and end, rectangle for processes, diamond for decisions, parallelogram for input and output, arrows for the order.
- A diamond always has two labeled exits.
- A loop is an arrow that goes back; somewhere along that path, something has to move the condition toward false.
- Every path in the flowchart needs at least one test case; pick inputs at the boundaries of each condition.
- Use flowcharts when there are nested decisions or loops with several exits; for simple sequences, pseudocode is enough.
