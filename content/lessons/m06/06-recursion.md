---
id: m06-l06
title: Recursion
description: You write functions that call themselves, with a base case that stops them and a recursive case that shrinks the problem. You rewrite factorial and the digit sum from Module 2 recursively, trace the call stack by hand, and learn when a loop is the better choice.
module: m06
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l05]
objectives:
  - Identify the base case and the recursive case of a recursive function.
  - Write recursive versions of factorial, the digit sum and similar problems.
  - Trace a recursive call by hand with a call-stack table.
  - Explain what happens when the base case is missing or never reached.
  - Choose between recursion and a loop for a given problem.
terms:
  - term: Recursion
    definition: A technique where a function solves a problem by calling itself on a smaller version of the same problem.
  - term: Base case
    definition: The input for which a recursive function returns an answer directly, without calling itself. It's what makes the recursion stop.
  - term: Recursive case
    definition: The part of a recursive function that calls itself on a smaller input and builds the answer from that call's result.
  - term: Call stack
    definition: The list of function calls that have started and not yet returned. Each call has its own frame with its own parameters and local names; the most recent call is on top.
  - term: Stack overflow
    definition: The crash that happens when the call stack runs out of space, typically because a recursion never reaches its base case.
mastery:
  - Point at the base case and the recursive case in any recursive function and say why the input shrinks.
  - Write a recursive function from a definition like "n! = n × (n − 1)!, and 1! = 1".
  - Build the call-stack table of a recursive call and predict its output, including prints before and after the recursive call.
  - Explain why a missing base case crashes the program, and recognize Swift's infinite recursion warning.
resources: [swift-book-functions, swift-book-control-flow]
cards:
  - id: m06-l06-c1
    front: What two parts does every recursive function need?
    back: A base case, which returns an answer directly without recursing, and a recursive case, which calls the function on a smaller input and builds the answer from it.
  - id: m06-l06-c2
    front: Write factorial recursively.
    back: "func factorial(_ n: Int) -> Int { if n <= 1 { return 1 }; return n * factorial(n - 1) }"
  - id: m06-l06-c3
    front: What happens if a recursive function never reaches its base case?
    back: Each call adds a frame to the call stack until it runs out of space, and the program crashes with a stack overflow. Swift warns about the obvious cases at compile time.
  - id: m06-l06-c4
    front: In a recursive function, when does code after the recursive call run?
    back: On the way back, after the deeper call returns. Code before the call runs on the way down, in calling order; code after it runs in reverse order.
  - id: m06-l06-c5
    front: Recursion or loop?
    back: A loop for simple repetition or counting. Recursion when the problem is defined in terms of smaller copies of itself, like trees or divide and conquer. Both can solve the same problems.
---

## The idea in one sentence

A recursive function solves a problem by **calling itself on a smaller version of it**, until the problem is so small that the answer is obvious.

## A definition that refers to itself

In the trace tables lesson you computed the factorial with a loop: `1 × 2 × … × n`. Here's another way to describe the same thing:

- `1!` is 1.
- For larger n, `n!` is `n × (n − 1)!`.

The second line defines factorial **in terms of factorial**. That isn't circular, because it always refers to a **smaller** n, and the first line stops the chain. To compute `4!`: it's `4 × 3!`, and `3!` is `3 × 2!`, and `2!` is `2 × 1!`, and `1!` is 1. Now multiply back up: `2 × 1 = 2`, `3 × 2 = 6`, `4 × 6 = 24`.

Swift lets you write that definition almost word for word:

```swift
func factorial(_ n: Int) -> Int {
    if n <= 1 {
        return 1
    }
    return n * factorial(n - 1)
}

print(factorial(4))
print(factorial(6))
```

```output
24
720
```

Line by line:

1. `if n <= 1 { return 1 }` is the **base case**: an input small enough to answer directly, without another call. Using `<= 1` instead of `== 1` also covers 0, since `0!` is 1 by definition.
2. `return n * factorial(n - 1)` is the **recursive case**: the function calls itself with `n - 1`, waits for that answer, multiplies by `n` and returns.
3. `factorial(6)` gives 720, the same result your trace table showed in Module 2.

Every recursive function needs both parts:

- a **base case** that returns without recursing, and
- a **recursive case** that moves the input **closer to the base case** on every call.

## The call stack, traced by hand

How can `factorial` be "waiting" for itself? Each call to a function gets its own **frame**: its own copy of the parameters and local names. The frames pile up on the **call stack**. A new call goes on top; when a call returns, its frame is removed and execution continues in the frame below it.

For `factorial(4)`:

| Step | Call stack (top last) | What happens |
| --- | --- | --- |
| 1 | `factorial(4)` | 4 > 1, so it needs `factorial(3)` and waits |
| 2 | `factorial(4)`, `factorial(3)` | 3 > 1, needs `factorial(2)` and waits |
| 3 | `factorial(4)`, `factorial(3)`, `factorial(2)` | 2 > 1, needs `factorial(1)` and waits |
| 4 | `factorial(4)`, `factorial(3)`, `factorial(2)`, `factorial(1)` | base case: returns 1 |
| 5 | `factorial(4)`, `factorial(3)`, `factorial(2)` | gets 1, returns 2 × 1 = 2 |
| 6 | `factorial(4)`, `factorial(3)` | gets 2, returns 3 × 2 = 6 |
| 7 | `factorial(4)` | gets 6, returns 4 × 6 = 24 |

Four frames are alive at the deepest point, each with its **own** `n`: 4, 3, 2 and 1. They don't overwrite each other, because each `n` is local to its own call. That's scope from lesson 4, at work.

The stack goes **down** until the base case, then the answers come back **up**. You can watch it happen by printing on both sides of the recursive call:

```swift
func factorial(_ n: Int, depth: Int = 0) -> Int {
    let indent = String(repeating: "  ", count: depth)
    print("\(indent)factorial(\(n)) starts")
    if n <= 1 {
        print("\(indent)factorial(\(n)) returns 1")
        return 1
    }
    let result = n * factorial(n - 1, depth: depth + 1)
    print("\(indent)factorial(\(n)) returns \(result)")
    return result
}

let answer = factorial(4)
```

```output
factorial(4) starts
  factorial(3) starts
    factorial(2) starts
      factorial(1) starts
      factorial(1) returns 1
    factorial(2) returns 2
  factorial(3) returns 6
factorial(4) returns 24
```

`String(repeating: "  ", count: depth)` builds a string with `depth` copies of two spaces, so deeper calls are indented further. The `depth` parameter with a default of 0 is only there for the indentation; callers never pass it.

Look at the order: every "starts" line prints on the way down, in calling order. Every "returns" line prints on the way back up, in **reverse** order. Code before the recursive call runs going down; code after it runs coming back.

## The digit sum, recursively

In Module 2 you traced this loop with n = 472:

```pseudo
sum ← 0
While n > 0
    sum ← sum + (remainder of n ÷ 10)
    n ← n ÷ 10, integer division
Print sum
```

Think about it recursively instead. The digit sum of 472 is its last digit, 2, plus the digit sum of the rest, 47. And the digit sum of a single-digit number is the number itself.

```swift
func digitSum(_ n: Int) -> Int {
    if n < 10 {
        return n
    }
    return n % 10 + digitSum(n / 10)
}

print(digitSum(472))
print(digitSum(905))
print(digitSum(7))
print(digitSum(0))
```

```output
13
14
7
0
```

- **Base case:** `n < 10`, a single digit. Its digit sum is itself, and that covers 0 too.
- **Recursive case:** `n % 10` is the last digit; `n / 10` drops it. Each call has one digit fewer, so the input always shrinks toward the base case.

The call stack for 472 is `digitSum(472)` → `digitSum(47)` → `digitSum(4)`. The base case returns 4, then `7 + 4 = 11`, then `2 + 11 = 13`.

Compare the two versions. The loop needs a `var` accumulator and a `var n` it keeps changing. The recursive version has **no variables at all**: each call works with its own `n`, which never changes. That's why recursive definitions are often closer to the way a problem is described mathematically.

## When the base case is missing

Remove the base case and nothing stops the calls:

```swift warning function call causes an infinite recursion
func countdown(_ n: Int) {
    print(n)
    countdown(n - 1)
}

// countdown is defined but never called, so this program runs and ends normally.
print("Not calling countdown")
```

```output
Not calling countdown
```

Swift 6.3 catches this one at compile time: `warning: function call causes an infinite recursion`. It's a warning, not an error, so the program still builds. If you **called** `countdown(3)`, it would print 3, 2, 1, 0, -1, -2… with every call adding a frame to the call stack, until the stack ran out of space and the program crashed with a **stack overflow**. In one run on Linux it got through roughly a hundred thousand calls before it stopped with a segmentation fault; the exact count depends on the machine. In Xcode, the debugger stops the program with a crash in one of the thousands of `countdown` frames.

The compiler can't always see the problem. A base case that's present but **unreachable** is just as bad, and usually gets no warning:

```swift illustrative
func countdown(_ n: Int) {
    if n == 0 {
        print("Liftoff")
        return
    }
    print(n)
    countdown(n - 2)   // from an odd number, n skips 0 and never stops
}

countdown(5)  // 5, 3, 1, -1, -3, … until the stack overflows
```

This block isn't run by the tests, because it really would crash. `countdown(4)` works: 4, 2, then 0 hits the base case. `countdown(5)` goes 5, 3, 1, -1 and skips past 0 forever. The fix is a base case that catches every way the input can end: `if n <= 0`.

> [!warning] Two questions for every recursive function
> 1. Is there a base case that returns without recursing?
> 2. Does **every** recursive call move the input closer to that base case, for **every** valid input?
>
> If you can't answer yes to both, the function can recurse forever.

## Recursion or a loop?

Anything you can write with recursion you can also write with a loop, and the other way around. Factorial and the digit sum are both fine either way. Which one to choose:

| | Loop | Recursion |
| --- | --- | --- |
| Reads best when | You're repeating a step or counting | The problem is defined in terms of smaller copies of itself |
| Memory | One frame, no matter how many passes | One frame per pending call |
| Risk | An infinite loop hangs the program | A missing base case crashes it with a stack overflow |
| Typical uses | Running totals, walking a range or a list | Trees, nested structures, divide and conquer, backtracking |

For a factorial or a digit sum, a loop is the everyday choice in Swift: it's simple and uses constant memory. Recursion starts to win when the data itself is recursive, like folders that contain folders, or when the algorithm splits a problem into halves. You'll meet those in Module 18 (sorting and backtracking) and Module 19 (trees and graphs). This lesson is about getting the mechanics right so those modules can focus on the algorithms.

> [!note]
> Large inputs hit a different limit first. `factorial(20)` is 2432902008176640000, which still fits in an `Int` on 64-bit platforms. `factorial(21)` doesn't, and Swift stops the program with an overflow error instead of returning a wrong number. That's an `Int` limit, not a recursion problem: the loop version has the same one.

## Common mistakes

> [!warning] warning: function call causes an infinite recursion
> The function calls itself on every path, so there's no way out. Add a base case that returns without recursing.

> [!error] The recursive call doesn't shrink the input
> `return n * factorial(n)` calls itself with the same `n` forever. The recursive case has to move toward the base case: `n - 1`, `n / 10`, half the range, one fewer item.

> [!error] Forgetting to use the recursive call's result
> `factorial(n - 1)` on its own line computes a value and throws it away (Swift warns that the result is unused). The recursive call is part of the answer: `return n * factorial(n - 1)`.

> [!error] A base case that misses some inputs
> `if n == 1` as the factorial's base case works for 1, 2, 3… but `factorial(0)` would skip past 1 and never stop. `if n <= 1` covers both.

````exercise
id: m06-l06-e1
type: comprehension
prompt: |
  In this function, which line is the base case?

  ```swift
  func power(_ base: Int, _ exponent: Int) -> Int {
      if exponent == 0 {
          return 1
      }
      return base * power(base, exponent - 1)
  }
  ```
choices:
  - text: "`func power(_ base: Int, _ exponent: Int) -> Int`"
    correct: false
    why: That's the declaration, not a case.
  - text: "`if exponent == 0 { return 1 }`"
    correct: true
    why: It returns directly, without calling power again. Anything to the power of 0 is 1.
  - text: "`return base * power(base, exponent - 1)`"
    correct: false
    why: That's the recursive case. It calls power with a smaller exponent.
  - text: There's no base case, so the recursion never ends.
    correct: false
    why: "exponent == 0 stops it, and every call subtracts 1 from the exponent, so a non-negative exponent always reaches 0."
solution: |
  **`if exponent == 0 { return 1 }`.** It's the only path that returns without calling `power` again. The recursive case multiplies `base` by `power(base, exponent - 1)`, so each call lowers the exponent by 1 until it reaches 0. `power(2, 3)` unfolds to `2 × 2 × 2 × 1 = 8`. A negative exponent would never reach 0, so this function assumes the exponent is 0 or more; a `guard` would make that explicit.
````

````exercise
id: m06-l06-e2
type: prediction
prompt: Predict the exact output. Pay attention to which print runs before the recursive call and which runs after.
code: |
  func echo(_ n: Int) {
      if n == 0 {
          print("bottom")
          return
      }
      print("down \(n)")
      echo(n - 1)
      print("up \(n)")
  }

  echo(3)
output: |
  down 3
  down 2
  down 1
  bottom
  up 1
  up 2
  up 3
hints:
  - "echo(3) prints down 3 and then waits for echo(2) to finish before printing up 3."
  - The prints after the call come out in reverse order.
solution: |
  ```output
  down 3
  down 2
  down 1
  bottom
  up 1
  up 2
  up 3
  ```

  | Step | Call stack (top last) | Prints |
  | --- | --- | --- |
  | 1 | echo(3) | down 3 |
  | 2 | echo(3), echo(2) | down 2 |
  | 3 | echo(3), echo(2), echo(1) | down 1 |
  | 4 | echo(3), echo(2), echo(1), echo(0) | bottom |
  | 5 | echo(3), echo(2), echo(1) | up 1 |
  | 6 | echo(3), echo(2) | up 2 |
  | 7 | echo(3) | up 3 |

  The "down" lines print on the way in. Each call then waits for the deeper one, and its "up" line only prints once that call has returned, so the innermost call (n = 1) finishes first.
````

````exercise
id: m06-l06-e3
type: fill-in
prompt: |
  Complete the recursive function that adds up all the numbers from 1 to n, so the program prints `15` and `0`.
code: |
  func sumUpTo(_ n: Int) -> Int {
      if n [[1]] 0 {
          return [[2]]
      }
      return n + sumUpTo([[3]])
  }
  print(sumUpTo(5))
  print(sumUpTo(0))
blanks:
  - id: "1"
    answers: ["<=", "=="]
  - id: "2"
    answers: ["0"]
  - id: "3"
    answers: ["n - 1", "n-1"]
solution: |
  ```swift
  func sumUpTo(_ n: Int) -> Int {
      if n <= 0 {
          return 0
      }
      return n + sumUpTo(n - 1)
  }
  print(sumUpTo(5))
  print(sumUpTo(0))
  ```

  ```output
  15
  0
  ```

  The sum of the numbers up to 0 is 0: that's the base case. For anything larger, it's n plus the sum up to n − 1. `sumUpTo(5)` is `5 + 4 + 3 + 2 + 1 + 0 = 15`. `<=` is safer than `==` because it also stops if someone passes a negative number.
````

````exercise
id: m06-l06-e4
type: find-errors
prompt: |
  This function should count how many digits a number has (`digitCount(4071)` should be 4, and `digitCount(0)` should be 1). Pick out the real problems.
code: |
  func digitCount(_ n: Int) -> Int {
      digitCount(n / 10)
      if n < 10 {
          return 1
      }
      return 1
  }
choices:
  - text: The recursive call comes before the base case, so the function always recurses and never reaches the check.
    correct: true
    why: "Every call starts by calling digitCount again. Swift warns: function call causes an infinite recursion."
  - text: The result of the recursive call is thrown away instead of being used in the answer.
    correct: true
    why: "The recursive case should return 1 + digitCount(n / 10). As written, the call's value is unused."
  - text: "n / 10 doesn't shrink the input."
    correct: false
    why: Integer division by 10 drops the last digit, so it does shrink toward a single digit.
  - text: "A function can't call itself in Swift."
    correct: false
    why: Recursion is fully supported.
rubric:
  - The base case comes first and returns 1 for a single digit, including 0.
  - The recursive case returns 1 plus the count of n / 10.
  - My version gives 4 for 4071 and 1 for 0.
solution: |
  ```swift
  func digitCount(_ n: Int) -> Int {
      if n < 10 {
          return 1
      }
      return 1 + digitCount(n / 10)
  }

  print(digitCount(4071), digitCount(0), digitCount(9), digitCount(10))
  ```

  ```output
  4 1 1 2
  ```

  Order matters: the base case has to be checked **before** recursing, or it's never reached. And the recursive call's result has to be part of the answer: a number has one digit more than the number without its last digit. The test values include the edge cases 0, 9 and 10, right on the boundary between one and two digits.
````

````exercise
id: m06-l06-e5
type: solve
prompt: |
  Write a recursive function `countDown(from:)` that prints the numbers from n down to 1 and then `Liftoff!`, **without any loop**. Then call it so the program prints:

  ```output
  3
  2
  1
  Liftoff!
  ```

  Make sure your function stops for any starting number, including 0 and negative numbers (those should print only `Liftoff!`).
starter: |
  func countDown(from n: Int) {
      // your code, no loops
  }

  countDown(from: 3)
hints:
  - "The base case is when there's nothing left to count: n <= 0."
  - "In the recursive case, print n first, then call countDown(from: n - 1)."
rubric:
  - There's no for or while in the function.
  - The base case uses <= 0, so 0 and negative inputs stop immediately.
  - The recursive call moves toward the base case.
  - The output matches exactly.
solution: |
  ```swift
  func countDown(from n: Int) {
      if n <= 0 {
          print("Liftoff!")
          return
      }
      print(n)
      countDown(from: n - 1)
  }

  countDown(from: 3)
  ```

  ```output
  3
  2
  1
  Liftoff!
  ```

  The base case is "nothing left to count", and it's `n <= 0` rather than `n == 0` so a negative start doesn't recurse forever. The `print(n)` comes **before** the recursive call, so the numbers come out on the way down, in decreasing order. If you swapped those two lines, you'd get `Liftoff!` first and then 1, 2, 3 on the way back up.
````

````exercise
id: m06-l06-e6
type: explain
prompt: |
  Here are two versions of the same function. Explain what each one computes, trace `version(4)` through the recursive one, and say which one you'd use in production code and why.
code: |
  func loopVersion(_ n: Int) -> Int {
      var result = 0
      var value = n
      while value > 0 {
          result += value % 2
          value /= 2
      }
      return result
  }

  func recursiveVersion(_ n: Int) -> Int {
      if n == 0 {
          return 0
      }
      return n % 2 + recursiveVersion(n / 2)
  }
rubric:
  - I recognized that both count the 1 bits in n's binary form (or described it as adding up the remainders of repeated division by 2).
  - I traced recursiveVersion(4) through 4, 2, 1 and 0 and got 1.
  - I named the base case and the recursive case.
  - I gave a reasoned preference, mentioning memory or readability.
solution: |
  Both add up the remainders of repeatedly dividing n by 2, which counts how many 1s n has in binary. 4 is `100` in binary, so the answer is 1; 7 is `111`, so it's 3.

  Tracing `recursiveVersion(4)`:

  | Call | n % 2 | waits for |
  | --- | --- | --- |
  | recursiveVersion(4) | 0 | recursiveVersion(2) |
  | recursiveVersion(2) | 0 | recursiveVersion(1) |
  | recursiveVersion(1) | 1 | recursiveVersion(0) |
  | recursiveVersion(0) | — | base case: returns 0 |

  On the way back: `1 + 0 = 1`, `0 + 1 = 1`, `0 + 1 = 1`. The base case is `n == 0`; the recursive case is `n % 2 + recursiveVersion(n / 2)`, and halving guarantees n reaches 0.

  ```swift
  func loopVersion(_ n: Int) -> Int {
      var result = 0
      var value = n
      while value > 0 {
          result += value % 2
          value /= 2
      }
      return result
  }

  func recursiveVersion(_ n: Int) -> Int {
      if n == 0 {
          return 0
      }
      return n % 2 + recursiveVersion(n / 2)
  }

  print(loopVersion(4), recursiveVersion(4), loopVersion(7), recursiveVersion(7))
  ```

  ```output
  1 1 3 3
  ```

  Either is fine here. The recursion depth is only the number of binary digits, at most 64 for an `Int`, so there's no risk of a stack overflow. The recursive version reads like the definition and has no mutable variables; the loop uses a single frame and is what most Swift code would do. A reasonable choice is the recursive one for clarity, or the loop for consistency with the rest of a codebase. Watch out for one difference: with a negative n, the loop returns 0 immediately, while the recursive version keeps going (integer division moves n toward 0) and returns a negative total, -2 for -3. Neither answer means anything, so real code would add a `guard n >= 0`.
````

## Summary

- A recursive function calls itself on a smaller input. It needs a **base case** that returns directly and a **recursive case** that moves toward it.
- Each call gets its own frame on the call stack, with its own parameters. The stack grows until the base case, then the answers come back in reverse order.
- Code before the recursive call runs on the way down; code after it runs on the way back up.
- A missing or unreachable base case recurses until the stack overflows and the program crashes. Swift warns about the obvious cases.
- Loops and recursion can solve the same problems. Use a loop for simple repetition; recursion pays off with recursive data and divide-and-conquer algorithms, coming in Modules 18 and 19.
