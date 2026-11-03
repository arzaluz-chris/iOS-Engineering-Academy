---
id: m05-l01
title: "Decisions with if, else and else if"
description: Your programs start choosing what to do. You write if, else and else if chains, put the checks in the right order so the boundaries land where they should, and learn when the ternary operator is the better tool.
module: m05
order: 1
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m04-l05, m04-l06]
objectives:
  - Write if, if-else and else-if chains with Bool conditions.
  - Order the checks in an else-if chain so every value lands in the right branch, boundaries included.
  - Flatten nested ifs with && or with an else-if chain when it makes the code clearer.
  - Use the ternary conditional operator to choose between two values, and explain how it differs from an if statement.
  - Declare a constant before an if and assign it in every branch.
terms:
  - term: Control flow
    definition: The order in which a program's statements run. if, switch and loops change it; without them, statements run top to bottom, once each.
  - term: Branch
    definition: One of the blocks of code an if or switch can choose to run.
  - term: else-if chain
    definition: A sequence of if, else if, … , else where Swift checks the conditions top to bottom and runs only the first branch whose condition is true.
  - term: Ternary conditional operator
    definition: "The operator condition ? a : b. It's an expression: its value is a when the condition is true and b when it's false."
  - term: Statement
    definition: A piece of code that does something, like an if or a print call. It doesn't produce a value you can store.
  - term: Scope
    definition: The region of code where a name exists. A constant declared inside an if's braces only exists inside them.
mastery:
  - Predict which branch of an else-if chain runs for any value, including the values right on the boundaries.
  - Spot an else-if chain whose order makes a branch unreachable, and fix it.
  - Rewrite two nested ifs as a single condition with && and say when that's not equivalent.
  - "Write `let label = count == 1 ? \"item\" : \"items\"` and explain why both values must have the same type."
  - Fix the "cannot be used as a boolean", "expected '{'" and "cannot find in scope" errors without help.
resources: [swift-book-control-flow, swift-book-basic-operators, swift-book-basics]
cards:
  - id: m05-l01-c1
    front: In an if / else if / else chain, how many branches run?
    back: At most one, the first whose condition is true, checked top to bottom. With a final else, exactly one runs.
  - id: m05-l01-c2
    front: Why does the order of the checks in an else-if chain matter?
    back: "Because the first true condition wins. If score >= 70 comes before score >= 90, a 95 lands in the 70 branch and the 90 branch can never run."
  - id: m05-l01-c3
    front: "What's the difference between `if` and `condition ? a : b`?"
    back: "if is a statement: it runs one block or another. The ternary operator is an expression: it produces one of two values, which must have the same type."
  - id: m05-l01-c4
    front: "What does `print(isMember ? 0 : 5 + 10)` print when isMember is false?"
    back: "15. The ternary operator has lower precedence than arithmetic, so the false side is 5 + 10."
---

## The idea in one sentence

`if` runs a block of code only when a condition is true, and `else` says what to do when it isn't.

Until now every program you wrote ran each line once, top to bottom. That's fine for a receipt. It's useless for "charge shipping unless the order is over 50 dollars". This module is about **control flow**: choosing which lines run, and how many times.

## if

**Plain definition:** "If this is true, do that."

**Precise definition:** `if` evaluates a condition of type `Bool`. If it's `true`, the statements inside the braces run. If it's `false`, Swift skips them and continues after the closing brace.

```swift
let temperature = 31
if temperature > 30 {
    print("Hot day. Drink water.")
}
print("Done")
```

```output
Hot day. Drink water.
Done
```

Line by line:

1. `temperature` is 31.
2. `temperature > 30` is a comparison, so it produces a `Bool`: `true`.
3. Because it's `true`, the line inside the braces runs.
4. The closing brace ends the `if`.
5. `print("Done")` is outside the `if`, so it runs either way.

Change 31 to 25 and only `Done` is printed.

Two rules from the syntax:

- The braces are **required**, even for a single line. Swift has no braceless `if`.
- Parentheses around the condition are **optional**, and Swift style leaves them out: `if temperature > 30`, not `if (temperature > 30)`.

The condition has to be a real `Bool`. Some languages treat 0 as false and any other number as true. Swift doesn't:

```swift no-compile type 'Int' cannot be used as a boolean
let unreadCount = 3
if unreadCount {
    print("You have messages")
}
```

Swift 6.3 says `error: type 'Int' cannot be used as a boolean; test for '!= 0' instead`. Write the question you mean: `if unreadCount != 0` or `if unreadCount > 0`.

## else

`else` adds a second block that runs when the condition is `false`. Exactly one of the two runs.

```swift
let balance = 40
let price = 55
if balance >= price {
    print("Purchase approved")
} else {
    print("Not enough money. You need \(price - balance) more.")
}
```

```output
Not enough money. You need 15 more.
```

`40 >= 55` is `false`, so the first block is skipped and the `else` block runs.

## else if: more than two options

When there are more than two outcomes, chain conditions with `else if`:

```swift
let score = 85
if score >= 90 {
    print("A")
} else if score >= 80 {
    print("B")
} else if score >= 70 {
    print("C")
} else {
    print("F")
}
```

```output
B
```

How Swift reads the chain:

1. `85 >= 90`? No. Move on.
2. `85 >= 80`? Yes. Print `B` and **leave the whole chain**.
3. The `>= 70` check never happens, even though 85 is also greater than 70.

That's the rule: **the first true condition wins**, and at most one branch runs. The final `else` catches everything that didn't match; with it, exactly one branch runs. Without it, possibly none.

### Order matters

Because the first match wins, the order of the checks is part of the logic. Here are the same three checks in the wrong order:

```swift
let score = 95
if score >= 70 {
    print("C")
} else if score >= 80 {
    print("B")
} else if score >= 90 {
    print("A")
}
```

```output
C
```

A 95 gets a C. Every score that's 80 or more is also 70 or more, so the first branch catches all of them, and the `B` and `A` branches can **never** run. The compiler doesn't warn you: the code is valid, just wrong.

When the checks are "at least" thresholds (`>=`), go from the **highest** threshold down. When they're "less than" thresholds (`<`), go from the **lowest** up.

### Boundaries

In Module 2 you learned that bugs live on the edges. An else-if chain is a list of edges. For the grade chain above, the values worth testing are the ones on each side of every threshold:

| score | Expected | Branch that runs |
| --- | --- | --- |
| 90 | A | `score >= 90` |
| 89 | B | `score >= 80` |
| 80 | B | `score >= 80` |
| 79 | C | `score >= 70` |
| 70 | C | `score >= 70` |
| 69 | F | `else` |

If someone had written `score > 90`, the first row would fail: a 90 would get a B. Mixing `>` and `>=` in the same chain is the most common way to get a boundary wrong. Pick one and use it everywhere.

The other boundary bug is a **gap**, a value no branch covers:

```swift
let temperature = 10
if temperature < 10 {
    print("Cold")
} else if temperature > 10 {
    print("Warm")
}
print("Checked")
```

```output
Checked
```

At exactly 10 neither condition is true and there's no `else`, so nothing about the weather is printed. Ending the chain with `else` instead of a last `else if` usually closes the gap.

## Nested and flattened conditions

An `if` can go inside another `if`:

```swift
let age = 20
let hasTicket = true
if age >= 18 {
    if hasTicket {
        print("Come in")
    }
}
```

```output
Come in
```

When the inner `if` has no `else`, the two levels mean "both must be true", and `&&` says it in one line:

```swift
let age = 20
let hasTicket = true
if age >= 18 && hasTicket {
    print("Come in")
}
```

```output
Come in
```

Flattening is **not** equivalent when each level has its own `else`, because then each failure gets a different message:

```swift
let age = 20
let hasTicket = false
if age >= 18 {
    if hasTicket {
        print("Come in")
    } else {
        print("Buy a ticket first")
    }
} else {
    print("Adults only")
}
```

```output
Buy a ticket first
```

That works, but the reader has to track two levels of braces to match each `else` with its `if`. Turn it into a chain that rejects the problem cases first:

```swift
let age = 20
let hasTicket = false
if age < 18 {
    print("Adults only")
} else if !hasTicket {
    print("Buy a ticket first")
} else {
    print("Come in")
}
```

```output
Buy a ticket first
```

Same behavior, one level deep, and the happy path sits at the end. Handling the bad cases first is a shape you'll see again with `guard` at the end of this module.

## Scope: names declared inside braces stay inside

A constant declared inside an `if` block only exists inside that block:

```swift no-compile cannot find 'message' in scope
let isMember = true
if isMember {
    let message = "Welcome back"
}
print(message)
```

When you need the result after the `if`, declare the constant **before** it and assign it in every branch. You saw in Module 4 that a `let` can be declared first and initialized later, exactly once:

```swift
let isMember = false
let message: String
if isMember {
    message = "Welcome back"
} else {
    message = "Sign up today"
}
print(message)
```

```output
Sign up today
```

The compiler checks that every path assigns `message` exactly once. Delete the `else` and there's a path where it never gets a value:

```swift no-compile constant 'message' used before being initialized
let isMember = false
let message: String
if isMember {
    message = "Welcome back"
}
print(message)
```

## The ternary conditional operator

You met this operator at the end of Module 4. Here it is properly.

**Plain definition:** a one-line "this or that" for **values**.

**Precise definition:** `condition ? a : b` is an expression. If `condition` is `true`, its value is `a`; otherwise it's `b`. Only the chosen side is evaluated. It's called *ternary* because it takes three operands.

```swift
let itemCount = 1
let word = itemCount == 1 ? "item" : "items"
print("\(itemCount) \(word)")

let total = 64
print("Shipping: \(total >= 50 ? 0 : 5)")
```

```output
1 item
Shipping: 0
```

### if is a statement, ?: is a value

That's the real difference. An `if` **runs** one block or another; you can't store an `if` statement in a constant or put it inside `print(…)`. The ternary operator **produces a value**, so it fits anywhere a value fits: on the right of `=`, inside interpolation, as an argument.

Because it produces one value, both sides must have the same type:

```swift no-compile result values in '? :' expression have mismatching types 'Int' and 'String'
let isMember = true
let discount = isMember ? 10 : "none"
```

And it has **lower precedence** than arithmetic and comparisons. In `isMember ? 0 : 5 + 10`, the false side is the whole `5 + 10`:

```swift
let isMember = false
print(isMember ? 0 : 5 + 10)
print((isMember ? 0 : 5) + 10)
```

```output
15
15
```

Here both lines happen to print 15. Change `isMember` to `true` and they split: the first prints 0, the second 10. If the reader has to think about it, add parentheses.

**When to use which:** use `?:` when you're choosing between two short **values**. Use `if` when you're choosing between **actions**, or when there are more than two cases. Never nest ternaries (`a ? b : c ? d : e`); write an else-if chain instead.

> [!version]
> Since Swift 5.9, `if` can also be used as an expression when each branch is a single value: `let advice = if temperature < 15 { "Bring a jacket" } else { "T-shirt weather" }`. Every branch must produce the same type and there must be an `else`. It's handy for more than two cases; for two short values most Swift code still uses `?:`.

```swift
let temperature = 12
let advice = if temperature < 15 { "Bring a jacket" } else { "T-shirt weather" }
print(advice)
```

```output
Bring a jacket
```

## A practical example: shipping cost

An online store's rules: members and orders of 50 dollars or more ship free; otherwise international orders pay 15 and domestic ones 4.99.

```swift
let subtotal = 42.5
let isMember = false
let destination = "international"

let shipping: Double
if isMember || subtotal >= 50 {
    shipping = 0
} else if destination == "international" {
    shipping = 15
} else {
    shipping = 4.99
}

print("Subtotal: \(subtotal)")
print("Shipping: \(shipping)")
print("Total: \(subtotal + shipping)")
```

```output
Subtotal: 42.5
Shipping: 15.0
Total: 57.5
```

The order isn't a member's and is under 50, so the first condition is false. The destination is international, so the second branch runs. `shipping` is a `Double` because of its annotation, which is why the `15` prints as `15.0`.

> [!note]
> The order of the branches encodes a business decision: free shipping is checked **first**, so a member shipping internationally pays nothing. If the store decided international orders always pay, the international check would have to move to the top.

## Common mistakes

> [!error] error: type 'Int' cannot be used as a boolean; test for '!= 0' instead
> The condition must be a `Bool`. Write the comparison you mean: `if count > 0`.

> [!error] error: expected '{' after 'if' condition
> Braces are required, even for one statement: `if x > 3 { print("big") }`.

```swift no-compile expected '{' after 'if' condition
let x = 5
if x > 3 print("big")
```

> [!error] error: use of '=' in a boolean context, did you mean '=='?
> `if total = 100` tries to assign. Comparing is `==`.

> [!error] error: cannot find 'message' in scope
> You declared a constant inside the braces and used it outside. Declare it before the `if` and assign it in every branch.

> [!error] A branch that can never run
> In an else-if chain with `>=` checks, the thresholds go from highest to lowest. Otherwise the first check swallows everything. The compiler won't catch this.

> [!error] Mixing > and >= on the boundaries
> Test the exact threshold values (90, 80, 70) and the ones just below. That's where a `>` written instead of `>=` shows up.

> [!error] error: result values in '? :' expression have mismatching types
> Both sides of the ternary operator must have the same type.

````exercise
id: m05-l01-e1
type: comprehension
prompt: |
  What does this program print?

  ```swift
  let score = 90
  if score > 90 {
      print("A")
  } else if score > 80 {
      print("B")
  } else {
      print("C")
  }
  ```
choices:
  - text: "`A`"
    correct: false
    why: "90 isn't greater than 90. `>` excludes the boundary."
  - text: "`B`"
    correct: true
    why: "`90 > 90` is false; `90 > 80` is true, so the B branch runs and the chain ends."
  - text: "`A` and then `B`"
    correct: false
    why: An else-if chain runs at most one branch.
  - text: "`C`"
    correct: false
    why: The else only runs when every condition above it is false.
solution: |
  It prints **B**. `score > 90` is `false` for exactly 90, so the first branch is skipped. `90 > 80` is `true`, that branch runs, and the rest of the chain is ignored.

  If 90 is supposed to be an A, the first check needs `>=`. This is the classic boundary bug: the program works for 95 and 85 and fails on the one value that matters most.
````

````exercise
id: m05-l01-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let stock = 0
  let price = 120
  let isMember = false
  if stock > 0 {
      print("In stock")
  } else {
      print("Sold out")
  }
  if price > 100 {
      print("Premium")
  } else if price > 50 {
      print("Standard")
  }
  if price > 200 {
      print("Luxury")
  }
  print(stock == 0 ? "Restock" : "OK")
  print(isMember ? 0 : 5 + 10)
  print("End")
output: |
  Sold out
  Premium
  Restock
  15
  End
hints:
  - There are three separate if statements here. Each one is decided on its own.
  - "120 > 100 is true, so the else if is never checked."
  - The ternary operator has lower precedence than +.
solution: |
  ```output
  Sold out
  Premium
  Restock
  15
  End
  ```

  1. `stock > 0` is false, so the else runs: `Sold out`.
  2. `120 > 100` is true: `Premium`. The `> 50` check never happens, even though it would also be true.
  3. `120 > 200` is false and there's no else: that `if` prints nothing.
  4. `stock == 0` is true, so the ternary's value is `"Restock"`.
  5. `isMember` is false, so the value is the whole right side, `5 + 10`, which is 15.
  6. `End` runs no matter what.
````

````exercise
id: m05-l01-e3
type: fill-in
prompt: |
  Complete the program. `status` must be `"pass"` when the score is 60 or more and `"fail"` otherwise, using the ternary operator. Then the chain prints a comment, starting with the highest threshold.
code: |
  let score = 74
  let status = score >= 60 [[1]] "pass" [[2]] "fail"
  print(status)
  if score >= 90 {
      print("Excellent")
  } [[3]] score >= 60 {
      print("Good enough")
  } [[4]] {
      print("Try again")
  }
blanks:
  - id: "1"
    answers: ["?"]
  - id: "2"
    answers: [":"]
  - id: "3"
    answers: ["else if"]
  - id: "4"
    answers: ["else"]
solution: |
  ```swift
  let score = 74
  let status = score >= 60 ? "pass" : "fail"
  print(status)
  if score >= 90 {
      print("Excellent")
  } else if score >= 60 {
      print("Good enough")
  } else {
      print("Try again")
  }
  ```

  ```output
  pass
  Good enough
  ```

  `?` separates the condition from the value for true, and `:` separates that from the value for false. The chain checks 90 first, then 60, then falls through to `else` for anything below 60.
````

````exercise
id: m05-l01-e4
type: find-errors
prompt: |
  This program should print a battery warning: "Critical" below 10 percent, "Low" from 10 up to (but not including) 30, and "OK" otherwise. Pick out the real problems.
code: |
  let battery = 25
  let isCharging = 0
  if isCharging {
      print("Charging")
  }
  if battery < 30 {
      print("Low")
  } else if battery < 10 {
      print("Critical")
  } else {
      let status = "OK"
  }
  print(status)
choices:
  - text: "`isCharging` is an Int, and an Int can't be used as an if condition."
    correct: true
    why: "Swift 6.3 reports `type 'Int' cannot be used as a boolean`. It should be a Bool, or the condition should be `isCharging != 0`."
  - text: "The `< 30` check comes before `< 10`, so \"Critical\" can never print."
    correct: true
    why: Every value below 10 is also below 30, so the first branch catches it. With < checks, go from lowest to highest.
  - text: "`status` is declared inside the else block and used outside it."
    correct: true
    why: "It doesn't exist after the closing brace: `cannot find 'status' in scope`."
  - text: The condition `battery < 30` needs parentheses.
    correct: false
    why: Parentheses around an if condition are optional in Swift, and the usual style leaves them out.
rubric:
  - isCharging is a Bool (or the condition compares it explicitly).
  - The chain checks < 10 before < 30.
  - Every branch prints its message, or a constant declared before the chain is assigned in every branch.
  - I tested 9, 10, 29 and 30 and got Critical, Low, Low and OK.
solution: |
  ```swift
  let battery = 25
  let isCharging = false
  if isCharging {
      print("Charging")
  }
  let status: String
  if battery < 10 {
      status = "Critical"
  } else if battery < 30 {
      status = "Low"
  } else {
      status = "OK"
  }
  print(status)
  ```

  ```output
  Low
  ```

  Three problems: an `Int` used as a condition, a chain in the wrong order (with `<` thresholds you start from the lowest), and a constant that dies at the closing brace. Declaring `status` before the chain and assigning it in every branch fixes the last one, and the compiler checks that no branch forgets.
````

````exercise
id: m05-l01-e5
type: solve
prompt: |
  A movie theater charges by age:

  - under 3: free (0)
  - 3 to 12: 6
  - 13 to 64: 12
  - 65 and over: 8

  Write a program that starts with `let age = 70` and prints `Age 70: $8`. It must give the right price for any age; check at least 2, 3, 12, 13, 64 and 65 by changing the constant.
starter: |
  let age = 70
hints:
  - Decide the order first. With < thresholds, start from the youngest group.
  - "Declare `let price: Int` before the chain and assign it in each branch."
  - "Use interpolation for the output: `\"Age \\(age): $\\(price)\"`."
rubric:
  - "The program prints exactly `Age 70: $8` for 70."
  - Ages 2, 3, 12, 13, 64 and 65 give 0, 6, 6, 12, 12 and 8.
  - It uses an else-if chain in a consistent order, with no gaps and no overlaps.
  - The price is computed once and printed once.
solution: |
  ```swift
  let age = 70
  let price: Int
  if age < 3 {
      price = 0
  } else if age <= 12 {
      price = 6
  } else if age <= 64 {
      price = 12
  } else {
      price = 8
  }
  print("Age \(age): $\(price)")
  ```

  ```output
  Age 70: $8
  ```

  The checks go from the youngest group up. Each `else if` only runs when every check above it failed, so `age <= 12` already knows the age is at least 3; you don't need `age >= 3 && age <= 12`. The final `else` covers 65 and over with no gap.

  The boundary table is what proves it: 2 → 0, 3 → 6, 12 → 6, 13 → 12, 64 → 12, 65 → 8.
````

````exercise
id: m05-l01-e6
type: refactor
prompt: Rewrite this code so it has no nested ifs and prints the same thing for every combination of values.
code: |
  let isLoggedIn = true
  let isAdmin = false
  if isLoggedIn {
      if isAdmin {
          print("Admin panel")
      } else {
          print("Your dashboard")
      }
  } else {
      print("Please log in")
  }
rubric:
  - My version has a single level of if / else if / else.
  - All four combinations of isLoggedIn and isAdmin print the same as the original.
  - The "not logged in" case is handled first.
solution: |
  ```swift
  let isLoggedIn = true
  let isAdmin = false
  if !isLoggedIn {
      print("Please log in")
  } else if isAdmin {
      print("Admin panel")
  } else {
      print("Your dashboard")
  }
  ```

  ```output
  Your dashboard
  ```

  Handling the "not logged in" case first means the next checks already know the user is logged in, so `isAdmin` doesn't need `isLoggedIn &&` in front of it. Check the four combinations: logged out with or without admin prints "Please log in" in both versions, which is why the order matters.
````

````exercise
id: m05-l01-e7
type: explain
prompt: Explain what this program prints for speeds of 30, 50 and 70, and what's wrong with it.
code: |
  let speed = 50
  if speed < 50 {
      print("Under the limit")
  } else if speed > 50 {
      print("Speeding")
  }
rubric:
  - I said 30 prints "Under the limit" and 70 prints "Speeding".
  - I said 50 prints nothing, and why.
  - I proposed a fix, such as replacing the else if with else or using <= in the first check.
solution: |
  30 prints `Under the limit` and 70 prints `Speeding`. At exactly **50** neither condition is true and there's no `else`, so the program prints **nothing**: a gap in the boundaries.

  The fix depends on the rule. If driving at exactly the limit is fine, change the first check to `speed <= 50` and replace `else if speed > 50` with plain `else`. Ending with `else` guarantees that every value lands somewhere.
````

## Summary

- `if` runs its block only when a `Bool` condition is true. Braces are required; parentheses aren't.
- `else` runs when the condition is false. In an else-if chain, the **first** true condition wins and the rest are skipped.
- Order the checks so no branch swallows the next one, and test the values on each side of every threshold.
- Two nested ifs without elses are the same as one `&&`. With elses, an else-if chain that handles the bad cases first is usually clearer.
- Names declared inside braces stay inside. Declare first, then assign in every branch.
- `condition ? a : b` is an expression that picks one of two values of the same type. Use it for short values, not for actions or for more than two cases.
