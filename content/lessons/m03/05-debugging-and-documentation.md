---
id: m03-l05
title: "Debugging with breakpoints and finding answers in the documentation"
description: You pause a program with breakpoints, step through it line by line, inspect values in the variables view and the LLDB console, and learn to read a page of the official documentation.
module: m03
order: 5
level: beginner
minutes: 50
prerequisites: [m03-l04, m02-l04]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Set, disable and remove breakpoints in Xcode.
  - Move through code with Continue, Step Over, Step Into and Step Out.
  - Inspect values with the variables view and with the console commands v, p and po.
  - Open a symbol's documentation from Xcode and read its declaration, description and parameters.
terms:
  - term: Debugger
    definition: A tool that runs a program under control, lets you pause it and shows you its values. Xcode uses LLDB.
  - term: Breakpoint
    definition: A marker on a line where the debugger pauses the program before running that line.
  - term: Step Over
    definition: Runs the whole current line and stops at the next one, without going into any functions it calls.
  - term: Step Into
    definition: If the current line calls a function, goes into it and stops at its first line.
  - term: Step Out
    definition: Finishes the current function and stops at the line that called it.
  - term: Variables view
    definition: The part of the debug area that shows the values of variables at the point where the program is paused.
  - term: Declaration
    definition: A symbol's signature in the documentation, for example the parameters a function takes and their default values.
mastery:
  - Use a breakpoint and Step Over to find the line where an accumulator stops holding the expected value.
  - Use v to look at a variable and p to evaluate an expression in the LLDB console.
  - Open the documentation for print from Xcode and explain what its default values mean.
  - Explain how debugging is like filling in a trace table.
resources: [xcode-breakpoints, xcode-stepping, lldb-tutorial, apple-documentation, swift-print]
cards:
  - id: m03-l05-c1
    front: When does the program stop at a breakpoint?
    back: Before running the marked line. The values you see are the ones from just before that line.
  - id: m03-l05-c2
    front: What's the difference between Step Over and Step Into?
    back: Step Over runs the whole line and stops at the next one. Step Into goes into the function if the line calls one.
  - id: m03-l05-c3
    front: What do `v`, `p` and `po` do in the LLDB console?
    back: v (frame variable) shows variables as they are in memory. p evaluates an expression and shows the result. po evaluates and shows the object's description.
  - id: m03-l05-c4
    front: How do you see a symbol's documentation without leaving the Xcode editor?
    back: "Option-click (⌥) the symbol to get Quick Help. The full documentation opens from Help › Developer Documentation."
---

## The idea in one sentence

The debugger is an automatic trace table: it pauses the program wherever you tell it to and shows you the real values, so you can compare them with the ones you expected.

## Why debug instead of guessing

In the trace tables lesson, you found bugs by comparing, row by row, the values you expected with the ones the algorithm produced. The debugger does the same thing with the real program: instead of working out each value by hand, you pause it and read them.

Sprinkling `print` everywhere also works, and sometimes it's the fastest option. But the debugger doesn't make you change the code, it lets you see all the values at once, and it lets you move from one line to the next.

## A program with a bug

This program should add up three prices. You haven't seen `var` or `for` yet; they come in Modules 4 and 5. For this lesson, all you need to know is that `total` holds a number that changes, and that the block between braces repeats once for each price.

```swift
var total = 0
for price in [120, 80, 45] {
    total = price
}
print("Total:", total)
```

```output
Total: 45
```

We expected 245. Let's find where the value gets lost, without guessing.

## Breakpoints

1. Paste the program into `main.swift` in your `Practice` project.
2. Click the **line number of line 3**, `total = price`, in the editor's left margin. A blue arrow appears: that's the **breakpoint**. With the cursor on the line, ⌘\ does the same thing.
3. Run with ⌘R.

The program pauses **before** running line 3. Xcode highlights the line and opens the debug area in two parts: the **variables view** on the left and the **console** on the right.

To manage breakpoints, according to Apple's documentation:

- Drag a breakpoint out of the margin to remove it.
- Click it to disable it without removing it; it turns dimmer.
- The breakpoints button in the debug bar turns all of them on or off.
- The Breakpoint navigator, on the left, lists them all.

## Stepping line by line

The debug bar, above the console, has the control buttons. Their default shortcuts appear when you hover over each button.

| Button | What it does |
| --- | --- |
| Continue | Keeps going until the next breakpoint or the end |
| Step Over | Runs the current line and stops at the next one |
| Step Into | If the line calls a function, goes into it |
| Step Out | Finishes the current function and returns to the caller |

With the program paused on line 3, watch the variables view:

| Pause | price | total before line 3 |
| --- | --- | --- |
| 1 | 120 | 0 |
| 2 | 80 | 120 |
| 3 | 45 | 80 |

Press **Continue** to get to each pause. By the second one the problem is already visible: `total` is 120, but at the third pause it's 80, not 200. Line 3 **replaces** the total instead of **adding** the price to it. It's the same accumulator bug you found by hand in the trace tables lesson.

The fix is to accumulate:

```swift
var total = 0
for price in [120, 80, 45] {
    total = total + price
}
print("Total:", total)
```

```output
Total: 245
```

## The LLDB console

While the program is paused, the console accepts debugger commands. The three most useful ones, according to Xcode's documentation:

```plaintext
(lldb) v total
(lldb) p total + price
(lldb) po total
```

1. `v total` (short for `frame variable`) shows the variable as it is in memory. It's fast and doesn't run any code.
2. `p total + price` (short for `expression`) **evaluates** an expression. Use it to test a hypothesis, like "what would it be if it added?", without changing the program.
3. `po total` evaluates and shows the value's description. For complex objects it's often easier to read than `p`.

If `p` or `po` gives you an error with some variable, try `v`: it doesn't compile any code, it just reads memory.

## Practical example: a conditional breakpoint

If the bug shows up on iteration 500 of a loop, pressing Continue 499 times isn't an option. Secondary-click the breakpoint, choose *Edit Breakpoint* and type a **condition**, for example `price == 45`. The debugger will only pause when the condition is true. You can also say how many times to ignore it before pausing.

## The official documentation

When you don't know what a function does or which parameters it takes, the answer is in the documentation. From Xcode:

- **Quick Help**: hold down the Option key (⌥) and click a symbol, for example `print`. A popover appears with its declaration and a summary.
- **Quick Help inspector**: in the inspectors panel on the right, it shows the same thing for the symbol under the cursor.
- **Full documentation**: *Help → Developer Documentation*. It's the same documentation as on developer.apple.com, with search.

### How to read a page

The `print` page in Apple's documentation has this declaration:

```swift illustrative
func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
)
```

Piece by piece:

1. `func print` is a function called `print`.
2. `_ items: Any...` is the first parameter. The `_` means it has no label when you call it; `Any...` means it accepts **any number** of values of **any type**.
3. `separator: String = " "` has the label `separator`, takes text and, if you don't pass it, is a space.
4. `terminator: String = "\n"` defaults to `"\n"`, the newline. That's why every `print` ends on a new line.

Below the declaration, a typical page has an overview (*Overview*), an explanation of each parameter, examples and, for Apple frameworks, the **availability**: which version of each operating system it first appeared in.

> [!tip]
> Before you look for a tutorial, read the symbol's documentation. It's more precise, it's current for your version and it tells you exactly what goes in and what comes out.

## Common mistakes

> [!error] The program doesn't stop at the breakpoint
> The breakpoint may be disabled (it looks dim), all breakpoints may be turned off from the debug bar, or that line never runs. Check all three.

> [!error] Reading the values as if the line had already run
> The program pauses **before** the marked line. To see that line's effect, press Step Over and look again.

> [!error] Using Step Into on every line
> Step Into goes into every function that gets called, including standard library ones when debug information is available. If you only care about your own code, use Step Over.

> [!error] Forgetting old breakpoints
> A forgotten breakpoint pauses the program at the worst moment. Check the Breakpoint navigator now and then.

````exercise
id: m03-l05-e1
type: comprehension
prompt: |
  The program is paused at a breakpoint on the line `total = total + price`. The variables view shows `total = 120` and `price = 80`. You press **Step Over** once. What value does the view now show for `total`?
choices:
  - text: "120"
    correct: false
    why: That's the value before the line runs.
  - text: "200"
    correct: true
    why: Step Over runs the line, 120 + 80, and stops at the next one.
  - text: "80"
    correct: false
    why: That's what would happen with the buggy version, total = price.
  - text: The program ends.
    correct: false
    why: Step Over only moves one line.
solution: |
  **200.** At a breakpoint the program pauses **before** the marked line, so at first `total` is still 120. Step Over runs `total = total + price` (120 + 80) and stops at the next line, with `total` at 200.
````

````exercise
id: m03-l05-e2
type: prediction
prompt: This program has the same accumulator bug as the lesson, now with four prices. Write exactly what it prints.
code: |
  var total = 0
  for price in [30, 15, 50, 5] {
      total = price
  }
  print("Total:", total)
  print("Expected:", 30 + 15 + 50 + 5)
output: |
  Total: 5
  Expected: 100
hints:
  - The line inside the braces replaces the total on every pass.
  - "print with two values separates them with a space."
solution: |
  ```output
  Total: 5
  Expected: 100
  ```

  `total = price` replaces the value on every pass, so when the loop ends `total` is the **last** price, 5. The second line calculates the real sum, 100. With a breakpoint on `total = price` you'd see `total` at 0, 30, 15 and 50 before each pass: it never builds up.
````

````exercise
id: m03-l05-e3
type: solve
prompt: |
  This program should print the **largest** number, 42, but it prints something else. Paste it into your project, put a breakpoint on the `if` line, watch `largest` and `n` at each pause and find the bug. Write down a table of what you saw and the fix.

  ```swift
  var largest = 0
  for n in [17, 42, 8, 23] {
      if n < largest {
          largest = n
      }
  }
  print("Largest:", largest)
  ```
starter: |
  Pause | n | largest before the if
hints:
  - Check whether the line largest = n ever runs. Use Step Over to see.
  - "Check the direction of the comparison: do we want to keep n when it's smaller or when it's larger?"
  - Check the starting value, 0, too. Would it work with negative numbers?
rubric:
  - I wrote down a table with the values of n and largest at each pause.
  - I identified that the comparison should be n > largest.
  - I mentioned that starting at 0 fails if all the numbers are negative.
  - My fixed version prints Largest, 42.
solution: |
  What the debugger shows at each pause on the `if`:

  | Pause | n | largest before the if |
  | --- | --- | --- |
  | 1 | 17 | 0 |
  | 2 | 42 | 0 |
  | 3 | 8 | 0 |
  | 4 | 23 | 0 |

  `largest` never changes: no number is less than 0, so `largest = n` never runs and the program prints `Largest: 0`. The comparison is backwards. On top of that, starting at 0 is the "made-up value" mistake from Module 2: with `[-5, -2]` the result would be 0. Starting with the first element avoids it; for now, since the list is fixed, it's enough to start at its first value:

  ```swift
  var largest = 17
  for n in [17, 42, 8, 23] {
      if n > largest {
          largest = n
      }
  }
  print("Largest:", largest)
  ```

  ```output
  Largest: 42
  ```

  In the collections module you'll see how to safely take the first element of any list.
````

````exercise
id: m03-l05-e4
type: explain
prompt: |
  Open Quick Help for `print` in Xcode (Option-click the word) or its documentation page. Based on this declaration, explain why `print("a", "b")` prints `a b` on one line and ends with a newline, and how you'd make it print `a-b` with no newline.
code: |
  func print(
      _ items: Any...,
      separator: String = " ",
      terminator: String = "\n"
  )
rubric:
  - I explained that Any... accepts several values.
  - I connected the space between a and b to the default value of separator.
  - I connected the newline to the default value of terminator.
  - "I wrote the call print(\"a\", \"b\", separator: \"-\", terminator: \"\")."
solution: |
  - `_ items: Any...` lets you pass several values without a label: `"a"` and `"b"`.
  - Since you don't pass `separator`, it takes its default `" "`: a space is written between `a` and `b`.
  - Since you don't pass `terminator`, it's `"\n"`: a newline is written at the end.

  To get `a-b` with no newline, change both:

  ```swift
  print("a", "b", separator: "-", terminator: "")
  ```

  It prints `a-b` and nothing else: whatever gets printed next continues on the same line.

  Reading the declaration answers the question without hunting for a tutorial. You'll come back to `separator` and `terminator` in the first lesson of Module 4.
````

````exercise
id: m03-l05-e5
type: comprehension
prompt: The program is paused. You want to know what `total + price` would be without changing the code. What do you type in the LLDB console?
choices:
  - text: "`v total + price`"
    correct: false
    why: v only reads variables from memory; it doesn't evaluate expressions.
  - text: "`p total + price`"
    correct: true
    why: p (expression) compiles and evaluates the expression with the current values.
  - text: "`print(total + price)`"
    correct: false
    why: The LLDB console takes debugger commands, not program statements.
  - text: "You can't; you have to add a print and run again."
    correct: false
    why: The debugger console lets you evaluate expressions without changing the program.
solution: |
  **`p total + price`**. `p` is short for `expression`: it compiles the expression and evaluates it with the current values. `v` (frame variable) is faster and safer, but it only shows variables as they are in memory, without evaluating operations.
````

## Summary

- A breakpoint pauses the program **before** the marked line.
- Continue goes to the next breakpoint; Step Over runs one line; Step Into goes into a function; Step Out leaves it.
- The variables view and the console (`v`, `p`, `po`) show the real values; compare them with the expected ones, as in a trace table.
- A conditional breakpoint saves you from pressing Continue hundreds of times.
- Option-click shows Quick Help; *Help → Developer Documentation* opens the full documentation. Read the declaration: it tells you what a function takes and what its defaults are.
