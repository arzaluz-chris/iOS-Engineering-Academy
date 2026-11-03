---
id: m05-l04
title: "while and repeat-while"
description: You write loops that repeat until something becomes true, when you can't know the number of passes in advance. You learn the difference between checking before and after the body, and how to make sure a loop ends.
module: m05
order: 4
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l03]
objectives:
  - Write while loops whose number of iterations depends on the data.
  - Write repeat-while loops and explain why their body always runs at least once.
  - Argue that a loop terminates by naming the value that moves toward the exit condition.
  - Recognize the usual causes of infinite loops and stop a running one.
  - Choose between for-in, while and repeat-while for a given problem.
terms:
  - term: while
    definition: A loop that checks its condition before each pass and runs the body as long as the condition is true. It can run zero times.
  - term: repeat-while
    definition: A loop that runs the body first and checks its condition after each pass. It always runs at least once.
  - term: Termination
    definition: A loop ending. A loop terminates when its condition eventually becomes false, which requires the body to change something the condition depends on.
  - term: Infinite loop
    definition: A loop whose condition never becomes false. The program keeps running, usually doing nothing useful, until you stop it.
  - term: Loop condition
    definition: The Bool expression that decides whether a while or repeat-while loop runs another pass.
mastery:
  - Predict how many times a while loop runs, including zero, with a trace table.
  - Explain why counting digits with while gives 0 for the number 0 and with repeat-while gives 1.
  - Point at the line in a loop that guarantees it ends, or explain why there isn't one.
  - Fix a loop that never ends because of a missing update, an update in the wrong direction, or a != condition that skips the target.
  - Pick the right loop for "for each item", "until it's paid off" and "ask until the answer is valid".
resources: [swift-book-control-flow]
cards:
  - id: m05-l04-c1
    front: What's the difference between while and repeat-while?
    back: while checks the condition before each pass and can run zero times. repeat-while runs the body first and checks after, so it always runs at least once.
  - id: m05-l04-c2
    front: What two things does a loop need to end?
    back: A condition that can become false, and a body that changes something the condition depends on, moving it toward false on every pass.
  - id: m05-l04-c3
    front: Why is `while count != 10` with `count += 3` dangerous?
    back: "Starting at 0, count goes 0, 3, 6, 9, 12… and never equals 10, so the loop never ends. Use < or <= in conditions that move toward a limit."
  - id: m05-l04-c4
    front: When do you choose for-in, while or repeat-while?
    back: for-in when you know the sequence (a range, a list). while when the number of passes depends on the data and could be zero. repeat-while when the body must run at least once, like asking for input.
---

## The idea in one sentence

`while` repeats a block **as long as** a condition is true, which is what you need when you can't know in advance how many passes it will take.

With `for-in` you always know the sequence: a range, a list, the characters of a text. But "how many years until my savings double?" isn't a range. You find the number of years by looping until the condition stops being true.

## while

```swift
var balance = 1000
var years = 0
while balance < 2000 {
    balance += balance / 10
    years += 1
}
print("It takes \(years) years to reach \(balance)")
```

```output
It takes 8 years to reach 2142
```

Line by line:

1. `balance` starts at 1000 and `years` at 0. Both are `var` because the loop changes them.
2. `while balance < 2000` checks the condition **before** each pass. 1000 < 2000 is `true`, so the body runs.
3. `balance += balance / 10` adds 10% interest (integer division, so it's rounded down).
4. `years += 1` counts the pass.
5. Back to step 2. After eight passes `balance` is 2142, `2142 < 2000` is `false`, and the loop ends.
6. The `print` after the loop runs once, with the final values.

The trace table:

| Pass | balance before | balance < 2000? | balance after | years |
| --- | --- | --- | --- | --- |
| 1 | 1000 | yes | 1100 | 1 |
| 2 | 1100 | yes | 1210 | 2 |
| 3 | 1210 | yes | 1331 | 3 |
| 4 | 1331 | yes | 1464 | 4 |
| 5 | 1464 | yes | 1610 | 5 |
| 6 | 1610 | yes | 1771 | 6 |
| 7 | 1771 | yes | 1948 | 7 |
| 8 | 1948 | yes | 2142 | 8 |
| — | 2142 | **no** | — | — |

The last row is the one that ends the loop. As you learned with trace tables, always write it.

### A while loop can run zero times

The condition comes first, so if it's false from the start, the body never runs:

```swift
var balance = 2500
var years = 0
while balance < 2000 {
    balance += balance / 10
    years += 1
}
print("It takes \(years) years to reach \(balance)")
```

```output
It takes 0 years to reach 2500
```

That's correct: someone who already has 2500 needs zero years.

## repeat-while

`repeat-while` puts the condition at the **end**. The body runs first, then the condition decides whether to go again:

```swift
var countdown = 3
repeat {
    print(countdown)
    countdown -= 1
} while countdown > 0
print("Liftoff")
```

```output
3
2
1
Liftoff
```

With a starting value of 3 it behaves like a `while`. The difference shows up when the condition is false from the start: `repeat-while` still runs the body **once**.

### When "at least once" is the right answer

Count the digits of a number by chopping off the last digit with integer division until nothing's left. With `while`:

```swift
var number = 4096
var digitCount = 0
while number > 0 {
    number /= 10
    digitCount += 1
}
print(digitCount)
```

```output
4
```

4096 → 409 → 40 → 4 → 0: four passes. Now try the number 0, which has one digit:

```swift
var number = 0
var digitCount = 0
while number > 0 {
    number /= 10
    digitCount += 1
}
print(digitCount)
```

```output
0
```

Wrong. `0 > 0` is false, so the loop never runs. Every number has at least one digit, so the body should run at least once. That's exactly what `repeat-while` guarantees:

```swift
var number = 0
var digitCount = 0
repeat {
    number /= 10
    digitCount += 1
} while number > 0
print(digitCount)
```

```output
1
```

The same code with the check moved from the top to the bottom fixes the edge case. For 4096 it still gives 4.

### Names declared in the body don't reach the condition

The condition of `repeat-while` is outside the braces, so it can't see constants declared inside them:

```swift no-compile cannot find 'next' in scope
var current = 0
repeat {
    let next = current + 1
    current = next
} while next < 3
```

Declare the value before the loop if the condition needs it.

## Asking until the answer is valid

The textbook use of `repeat-while` is input: ask once, and ask again while the answer is unusable. In a command-line program, `readLine()` reads one line the user types in the console:

```swift illustrative
var answer = ""
repeat {
    print("Continue? (yes/no)")
    answer = readLine() ?? ""
} while answer != "yes" && answer != "no"
print("You said \(answer)")
```

This block isn't run by the lesson tests, because nobody is there to type. In a command-line project in Xcode, or with `swift file.swift` in the terminal, `readLine()` waits for a line of text. It returns an optional (`nil` when there's no more input), which is why it's followed by `?? ""`; Module 8 covers optionals properly. A playground has no console to type into, so use a command-line project or the terminal for this.

For the rest of this module, input will be **simulated** with text constants, so the examples can be run and checked.

## Making sure a loop ends

A `for-in` loop ends when its sequence runs out. A `while` loop ends only when its condition becomes false, and nothing guarantees that except you. For every `while` you write, you should be able to point at two things:

1. **The condition** that can become false: `balance < 2000`.
2. **The line that moves toward it** on every pass: `balance += balance / 10`, which makes `balance` larger every time.

If you can't point at the second one, the loop might never end.

### How infinite loops happen

**Forgetting the update.** The condition depends on `attempts`, and nothing changes it:

```swift illustrative
var attempts = 0
while attempts < 3 {
    print("Trying...")
    // attempts += 1 is missing
}
```

This prints `Trying...` forever. It's marked illustrative because running it would never finish.

**Updating in the wrong direction.** `while level > 0 { level += 1 }` moves away from the exit.

**A `!=` condition that skips the target.** This one looks right:

```swift
var value = 1
var passes = 0
while value != 10 && passes < 20 {
    value += 2
    passes += 1
}
print("value: \(value), passes: \(passes)")
```

```output
value: 41, passes: 20
```

`value` goes 1, 3, 5, 7, 9, 11… and never **equals** 10. Without the `passes < 20` safety cap, the loop would never end. The real fix is the condition: `while value < 10` stops as soon as the value reaches or passes the limit. When a value moves toward a limit, prefer `<`, `<=`, `>` or `>=` over `!=`.

A safety cap like `passes < 20` is a reasonable guard in code where a mistake is expensive, but it hides the bug instead of fixing it. Fix the condition first.

> [!tip]
> If a program seems frozen, it's probably stuck in a loop. In Xcode, press the Stop button (or ⌘.); in the terminal, press Ctrl-C. Then add a `print` inside the loop to watch the values that are supposed to change.

## Choosing a loop

| Situation | Loop | Why |
| --- | --- | --- |
| Do something for each number from 1 to 10 | `for-in` | The sequence is known. |
| Do something for each item in a list | `for-in` | The sequence is the list. |
| Until a balance reaches a target | `while` | Unknown number of passes, possibly zero. |
| Until a number has no digits left | `repeat-while` | Must run at least once. |
| Ask until the answer is valid | `repeat-while` | You have to ask at least once. |

When both `for-in` and `while` would work, use `for-in`: it can't forget the update, and it can't run forever.

## A practical example: paying off a debt

A debt of 1000 grows 2% a month, and you pay 150 every month. How many months until it's paid?

```swift
var debt = 1000
let payment = 150
var month = 0
while debt > 0 {
    month += 1
    debt += debt * 2 / 100
    debt -= payment
    if debt < 0 {
        debt = 0
    }
    print("Month \(month): \(debt) left")
}
print("Paid off in \(month) months")
```

```output
Month 1: 870 left
Month 2: 737 left
Month 3: 601 left
Month 4: 463 left
Month 5: 322 left
Month 6: 178 left
Month 7: 31 left
Month 8: 0 left
Paid off in 8 months
```

Does it terminate? The interest (2% of at most 1000, so at most 20) is always smaller than the payment, so `debt` goes down every month and eventually reaches 0. Now imagine a payment of 15. The interest on 1000 is 20, so the debt **grows** every month and the loop never ends. A real program would check `payment > debt * 2 / 100` before the loop and print a warning instead of entering it. That check is the termination argument written as code.

## Common mistakes

> [!error] A loop that never ends
> The body doesn't change what the condition reads, changes it in the wrong direction, or uses `!=` against a value it steps over. Point at the line that moves toward the exit; if there isn't one, that's the bug.

> [!error] Using while when the body must run once
> The digit counter said 0 has 0 digits. If the body has to run at least once, use `repeat-while`.

> [!error] error: cannot find 'next' in scope
> The `while` of a `repeat-while` can't see constants declared inside the body. Declare them before the loop.

> [!error] Off by one after the loop
> After `while count < 5 { count += 1 }`, `count` is 5, not 4. The loop stops on the first value that fails the condition. A trace table's last row shows the final values.

> [!error] Using while where for-in fits
> A manual counter with `while` (start, condition, increment) is three places to make a mistake. If you know the range, `for-in` has none.

````exercise
id: m05-l04-e1
type: comprehension
prompt: A program has to ask for a PIN and keep asking while the PIN is wrong. Which loop fits best?
choices:
  - text: "`for attempt in 1...3`"
    correct: false
    why: It fits "at most three attempts", but not "keep asking while it's wrong". The number of passes isn't known.
  - text: "`while`, with the condition checked before asking"
    correct: false
    why: It works with an extra first read before the loop, but the body has to run at least once anyway, and repeat-while says that directly.
  - text: "`repeat-while`, with the check after each attempt"
    correct: true
    why: You always ask at least once, and you keep going while the answer is wrong.
  - text: No loop; an if is enough.
    correct: false
    why: An if asks once. A second wrong PIN would go unchecked.
solution: |
  **`repeat-while`.** The body (ask for the PIN) must run at least once, and the decision to go again depends on the answer just given. That's exactly a condition checked **after** the body. A real PIN screen would also limit the attempts; you'd add that to the condition with `&&`.
````

````exercise
id: m05-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  var a = 10
  while a < 10 {
      print("while", a)
      a += 1
  }
  var b = 10
  repeat {
      print("repeat", b)
      b += 1
  } while b < 10
  var c = 1
  while c < 20 {
      c *= 3
  }
  print(a, b, c)
output: |
  repeat 10
  10 11 27
hints:
  - 10 < 10 is false.
  - repeat-while runs the body before checking.
  - "c goes 1, 3, 9, 27. Which value fails c < 20?"
solution: |
  ```output
  repeat 10
  10 11 27
  ```

  1. `a < 10` is false from the start, so the `while` body never runs and `a` stays 10.
  2. The `repeat` body runs once: prints `repeat 10` and makes `b` 11. Then `11 < 10` is false and the loop ends.
  3. `c` goes 1 → 3 → 9 → 27. At 9 the condition is still true, so it multiplies once more; 27 fails `c < 20`. The loop ends on the first value that **fails** the condition, which is past 20.
````

````exercise
id: m05-l04-e3
type: prediction
prompt: |
  The Collatz sequence: if a number is even, halve it; if it's odd, multiply it by 3 and add 1. Repeat until you reach 1. Predict how many steps it takes from 6.
code: |
  var n = 6
  var steps = 0
  while n != 1 {
      if n % 2 == 0 {
          n /= 2
      } else {
          n = n * 3 + 1
      }
      steps += 1
  }
  print("Steps: \(steps)")
output: |
  Steps: 8
hints:
  - "Write the sequence: 6, 3, …"
  - Count the arrows, not the numbers.
solution: |
  ```output
  Steps: 8
  ```

  The sequence is 6 → 3 → 10 → 5 → 16 → 8 → 4 → 2 → 1: eight steps.

  A curious fact: this loop has ended for every starting number anyone has tried, but no one has ever **proved** that it ends for every number. It's an open problem in mathematics, the Collatz conjecture. Most of your loops won't be that mysterious, but it shows why "how do I know this ends?" is a real question.
````

````exercise
id: m05-l04-e4
type: find-errors
prompt: Each of these three loops is meant to end. Pick out the ones that never do.
code: |
  // Loop A: print 5, 4, 3, 2, 1
  var a = 5
  while a > 0 {
      print(a)
      a += 1
  }

  // Loop B: print 0, 5, 10, ... up to 100
  var b = 0
  while b != 100 {
      print(b)
      b += 5
  }

  // Loop C: print 1, 2, 4, 8, 16
  var c = 1
  while c != 20 {
      print(c)
      c *= 2
  }
choices:
  - text: "Loop A never ends: a moves away from the exit."
    correct: true
    why: a should go down toward 0, but a += 1 makes it grow forever.
  - text: Loop B never ends.
    correct: false
    why: "b goes 0, 5, …, 95, 100, and 100 is a multiple of 5, so b != 100 becomes false. It ends, though < would be safer."
  - text: "Loop C never ends: c skips over 20."
    correct: true
    why: c goes 1, 2, 4, 8, 16, 32… and never equals 20.
rubric:
  - Loop A decreases a.
  - Loop C uses a condition like c < 20 or c <= 16 instead of !=.
  - "I changed Loop B to b <= 95 or b < 100 so it stays correct if the step changes."
solution: |
  ```swift
  var a = 5
  while a > 0 {
      print(a)
      a -= 1
  }
  var b = 0
  while b < 100 {
      print(b)
      b += 5
  }
  var c = 1
  while c < 20 {
      print(c)
      c *= 2
  }
  ```

  **A** updates in the wrong direction. **C** uses `!=` against a value it never hits. **B** does end, by luck: change the step to 3 and it would run forever too. `<` ends no matter the step. Note that `b < 100` doesn't print 100; the original `b != 100` didn't either, and the comment's "up to 100" is ambiguous. Settle that with whoever wrote the requirement.
````

````exercise
id: m05-l04-e5
type: fill-in
prompt: |
  Complete the loop that rolls a die until it shows a 6. The formula `roll * 5 % 7` stands in for a random roll so the run is predictable: starting from 2, it gives 3, 1, 5, 4 and then 6.
code: |
  var roll = 2
  var rolls = 0
  [[1]] {
      roll = roll * 5 % 7
      rolls += 1
      print("Rolled \(roll)")
  } [[2]] roll [[3]] 6
  print("Got a 6 after \(rolls) rolls")
blanks:
  - id: "1"
    answers: ["repeat"]
  - id: "2"
    answers: ["while"]
  - id: "3"
    answers: ["!="]
solution: |
  ```swift
  var roll = 2
  var rolls = 0
  repeat {
      roll = roll * 5 % 7
      rolls += 1
      print("Rolled \(roll)")
  } while roll != 6
  print("Got a 6 after \(rolls) rolls")
  ```

  ```output
  Rolled 3
  Rolled 1
  Rolled 5
  Rolled 4
  Rolled 6
  Got a 6 after 5 rolls
  ```

  You have to roll before you can know whether you got a 6, so the body runs at least once: `repeat-while`. The loop continues **while** the roll is not 6. Here `!=` is safe because the value doesn't move toward a limit; it jumps around, and the formula is known to reach 6. In a real app you'd use `Int.random(in: 1...6)`, and the loop would end with probability 1 rather than with certainty, which is fine for a die.
````

````exercise
id: m05-l04-e6
type: solve
prompt: |
  Write a program that adds up the digits of a number. Start with `var number = 472`; it should print `Digit sum: 13`. It must also print `Digit sum: 0` for 0. This is the algorithm you traced by hand in Module 2's trace tables lesson.
starter: |
  var number = 472
hints:
  - "`number % 10` is the last digit. `number /= 10` removes it."
  - Is there any number for which this loop has to run at least once?
rubric:
  - For 472 it prints Digit sum 13.
  - For 0 it prints Digit sum 0 without crashing or looping forever.
  - I can point at the line that makes the loop end.
solution: |
  ```swift
  var number = 472
  var digitSum = 0
  while number > 0 {
      digitSum += number % 10
      number /= 10
  }
  print("Digit sum: \(digitSum)")
  ```

  ```output
  Digit sum: 13
  ```

  `number /= 10` is the line that guarantees termination: every pass removes a digit, so `number` reaches 0. For 0 the loop runs zero times and the sum is 0, which is correct, so plain `while` is fine here. Unlike counting digits, a digit **sum** doesn't need the body to run at least once. (Negative numbers would need extra care: `-472 > 0` is false.)
````

````exercise
id: m05-l04-e7
type: explain
prompt: |
  This program finds a secret number between 1 and 100 by always guessing the middle of what's left. It prints `Found 37 in 3 attempts`. Explain why the loop ends for 37, and what happens if `secret` is 150.
code: |
  let secret = 37
  var low = 1
  var high = 100
  var guess = 0
  var attempts = 0
  repeat {
      guess = (low + high) / 2
      attempts += 1
      if guess < secret {
          low = guess + 1
      } else if guess > secret {
          high = guess - 1
      }
  } while guess != secret
  print("Found \(secret) in \(attempts) attempts")
rubric:
  - I explained that every wrong guess shrinks the range between low and high.
  - I traced the guesses for 37 (50, 25, 37).
  - I explained that with 150 the guess can never equal the secret, so the loop never ends.
  - I proposed a fix, such as adding low <= high to the condition.
solution: |
  Every wrong guess moves `low` up or `high` down, so the range of candidates shrinks on every pass. For 37: guess 50 is too high (high becomes 49), guess 25 is too low (low becomes 26), guess (26 + 49) / 2 = 37 is right. Three attempts. As long as the secret is between 1 and 100, the range eventually closes in on it, which is the termination argument.

  With 150 the guesses climb (50, 75, 88, 94, 97, 99, 100) and then `low` becomes 101 while `high` stays 100. From then on the guess is always 100, always too low, and `guess != secret` is true forever: an **infinite loop**. The fix is to stop when the range is empty: `} while guess != secret && low <= high`, and after the loop check whether the guess actually matches. Better still, validate that the secret is in 1...100 before the loop starts, which is the subject of the last lesson in this module.
````

## Summary

- `while` checks its condition **before** each pass and can run zero times. Use it when the number of passes depends on the data.
- `repeat-while` checks **after** each pass and always runs at least once. Use it when the body must happen before you can decide, like asking for input.
- A loop ends only if its body moves something toward making the condition false. Be able to point at that line.
- Infinite loops come from a missing update, an update in the wrong direction, or a `!=` that steps over its target. Prefer `<` and `>` against limits.
- When the sequence is known, `for-in` is the safer choice.
