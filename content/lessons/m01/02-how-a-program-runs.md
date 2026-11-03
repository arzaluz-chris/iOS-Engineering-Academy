---
id: m01-l02
title: From source code to a running program
description: What happens between writing a line of Swift and the computer executing it. Source code, compiler, machine code and runtime, and why Swift catches so many errors before anything runs.
module: m01
order: 2
level: beginner
minutes: 40
prerequisites: [m01-l01]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Tell source code apart from machine code.
  - Explain what a compiler does and how it differs from an interpreter.
  - Classify an error as a compile-time error or a runtime error.
  - Describe what a language's runtime is.
terms:
  - term: Source code
    definition: The text you write in a programming language, readable by people.
  - term: Machine code
    definition: Binary instructions the processor executes directly. They depend on the architecture, for example arm64 on iPhones and on Macs with Apple silicon.
  - term: Compiler
    definition: A program that translates source code into executable code and, along the way, checks language rules such as types.
  - term: Interpreter
    definition: A program that reads source code and executes it as it reads, without first producing a complete executable.
  - term: Runtime
    definition: Support code that runs alongside the program while it executes, for example to manage memory.
  - term: Compile-time error
    definition: A problem the compiler catches before the program exists. No program is produced.
  - term: Runtime error
    definition: A problem that happens while the program runs, like dividing by a computed value that turned out to be zero or reading a position that doesn't exist in a list.
mastery:
  - Explain out loud, in under a minute, the path from a .swift file to the processor.
  - Classify common errors as compile-time or runtime errors and justify the classification.
  - Say what concrete advantage you get from the compiler checking types before the program runs.
resources: [swift-book, swift-book-basics, swift-org]
cards:
  - id: m01-l02-c1
    front: What does a compiler do?
    back: It translates source code into executable code and checks the language rules (types, names, syntax) before the program exists.
  - id: m01-l02-c2
    front: Difference between a compile-time error and a runtime error.
    back: A compile-time error is caught by the compiler and no program is produced. A runtime error happens while the program runs, with concrete data.
  - id: m01-l02-c3
    front: What is the Swift runtime?
    back: Support code that runs alongside the program; among other things, it takes part in managing memory through reference counting (ARC).
---

## The idea in one sentence

You write text; the processor only understands numbers. Between the two sits a translator, the **compiler**, which also checks your work before the program exists.

## Source code and machine code

**Source code** is what you write:

```swift
print("Hello")
```

An iPhone's processor doesn't know what `print` is, or what a word in quotes is. It executes **machine code**: very basic binary instructions like "load this value into a register" or "jump to this address". Each processor family has its own machine code. Current iPhones and Macs with Apple silicon use the **arm64** architecture.

Writing machine code directly is possible, and almost nobody does it: it's slow, error-prone and can't be moved to another architecture. Programming languages exist so you can write at a level people understand and let a tool do the translation.

## Compiling or interpreting

There are two general strategies for running source code:

| Strategy | What it does | Consequence |
| --- | --- | --- |
| Ahead-of-time compilation | Translates the whole program into an executable before running it. | Many errors are caught before anything runs; the resulting program starts fast. |
| Interpretation | A program reads the source code and executes it as it goes. | You can try something right away, but some errors only show up when execution reaches that line. |

Swift is a **compiled** language. When you press Run in Xcode, the Swift compiler (`swiftc`, built on LLVM) translates your code into machine code for the target device, and then the result runs. The `swift` tool also lets you run a file straight from the terminal (`swift file.swift`); even then, the code goes through the compiler before it runs.

Compiled versus interpreted describes implementations, not languages in any absolute sense: some languages have both. What matters for Swift is the practical consequence: **the compiler checks a lot before the program runs.**

## The compiler as your first reviewer

Besides translating, the Swift compiler checks rules. If you write a name that doesn't exist, mix incompatible types or forget to close a quote, you don't get a program: you get a **compile-time error** with the line number and an explanation.

That's a huge advantage. An error the compiler catches never reaches a user. That's why reading and understanding compiler messages is a core skill in Swift, and Module 3 practices it in depth.

Other errors can only be discovered with concrete data while the program runs: dividing by a number that turned out to be zero, asking for element 10 of a list that has 3. Those are **runtime errors**. In Swift they usually stop the program immediately, with a message, instead of carrying on with corrupted data.

## The runtime

A compiled program doesn't travel alone. It comes with a **runtime**: support code that runs alongside your program. Among other things, the Swift runtime takes part in managing object memory through reference counting (you'll study it as ARC in Module 13). You don't write the runtime or call it directly, but it helps to know it exists: it explains why certain work happens "on its own" while your program runs.

## Minimal example, line by line

```swift
print("Hello")
print(2 + 3)
```

- Line 1: calls the `print` function with the text `"Hello"`. It prints `Hello` and a line break.
- Line 2: the compiler sees that `2 + 3` adds two integers and gets it ready; when it runs, `5` is printed.

The program runs from top to bottom: first `Hello`, then `5`.

## Common mistakes

> [!error] Thinking that if it compiles, it works
> The compiler guarantees that the program follows the rules of the language, not that it does what you meant. A wrong algorithm compiles just fine.

> [!error] Ignoring warnings
> A warning doesn't stop compilation, but it almost always points at something real: a variable you never use, code that never runs. Treat warnings as small errors.

> [!error] Reading only the first word of the message
> Swift compiler messages usually say what was expected and what was found. Read the whole message and the line it points to before you change anything.

````exercise
id: m01-l02-e1
type: comprehension
multiple: true
prompt: Which of these problems does the Swift compiler catch **before** the program runs? Select all that apply.
choices:
  - text: "Writing `prnt(\"Hello\")` instead of `print(\"Hello\")`."
    correct: true
    why: The compiler can't find any function named `prnt` and refuses to produce the program.
  - text: "Forgetting to close the quotes around a piece of text."
    correct: true
    why: It's a syntax error; the code can't be translated.
  - text: "The user typing their age as \"twenty\" when the program expects a number."
    correct: false
    why: The compiler doesn't know what the user will type. That problem is handled at runtime, by validating the input.
  - text: "The algorithm computing a discount wrong."
    correct: false
    why: A wrong algorithm can follow every rule of the language. Only testing reveals it.
solution: |
  The compiler catches what breaks the **rules of the language**: names that don't exist and broken syntax. It can't catch what depends on **runtime data** (what the user types) or on **your intent** (whether the discount was supposed to be 10% or 15%). That's what input validation and tests are for.
````

````exercise
id: m01-l02-e2
type: prediction
prompt: This program compiles without errors. Write exactly what it prints.
code: |
  print("Hello")
  print(2 + 3)
  print("2 + 3")
output: |
  Hello
  5
  2 + 3
solution: |
  ```output
  Hello
  5
  2 + 3
  ```

  The second line prints **5** because `2 + 3` is a numeric expression, and it gets evaluated. The third prints **2 + 3** literally, because it's in quotes: it's text, not addition. The difference between a value and its text representation will come up constantly.
````

````exercise
id: m01-l02-e3
type: comprehension
prompt: An app compiles without errors and, while you use it, crashes when it tries to read element number 10 of a list that only has 3. What kind of error is it?
choices:
  - text: Compile-time error
    correct: false
    why: The compiler doesn't know how many elements the list will have while the app runs.
  - text: Runtime error
    correct: true
    why: It happens with concrete data while the program runs.
  - text: Warning
    correct: false
    why: A warning doesn't crash the app; it shows up when you compile.
solution: |
  It's a **runtime error**. The size of the list is only known when the app runs. Swift stops the program instead of reading memory that doesn't belong to it, which is a deliberate safety decision. In later modules you'll learn to access collections safely so this doesn't happen.
````

## Summary

- The processor executes machine code; you write source code.
- Swift is compiled: the compiler translates your code and, before that, checks the rules of the language.
- Compile-time errors keep the program from existing; runtime errors happen with concrete data.
- The runtime runs alongside the program and handles work such as memory management.
