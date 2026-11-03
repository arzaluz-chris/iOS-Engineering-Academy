---
id: m04-l02
title: "Constants and variables: let and var"
description: You give values names with let and var, decide which one to use, learn what assignment means, and pick up the rules and conventions for naming. The magic numbers disappear from your programs.
module: m04
order: 2
level: beginner
minutes: 45
prerequisites: [m04-l01]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Declare constants with let and variables with var.
  - Choose between let and var and justify the choice.
  - Use assignment and the compound operators +=, -=, *= and /=.
  - Name constants and variables following the language rules and Swift's conventions.
  - Fix the typical let and var compile errors.
terms:
  - term: Constant
    definition: A name bound to a value that can't change once it's assigned. In Swift you declare it with let.
  - term: Variable
    definition: A name bound to a value that can change. In Swift you declare it with var.
  - term: Declaration
    definition: The statement that creates a new name, for example let price = 45.
  - term: Assignment
    definition: Storing a value in a name with the = operator. In Swift, = assigns; to compare you use ==.
  - term: Initialization
    definition: The first assignment of a value to a constant or variable. Swift doesn't let you read a name before it's initialized.
  - term: Compound assignment operator
    definition: An operator that combines an operation with assignment, like += in total += 5, which is the same as total = total + 5.
  - term: camelCase
    definition: A naming convention that joins words and capitalizes each one except the first, like discountedPrice.
mastery:
  - Rewrite a program full of repeated numbers using named constants, without changing its output.
  - Say, for every name in a program, whether it should be let or var and why.
  - Predict the output of a program that reassigns a variable with =, += and *=.
  - Fix the "is a 'let' constant", "used before being initialized" and "invalid redeclaration" errors without the compiler's help.
resources: [swift-book-basics, swift-book-basic-operators]
cards:
  - id: m04-l02-c1
    front: What's the difference between let and var?
    back: let declares a constant, whose value can't change once it's assigned. var declares a variable, which can be reassigned.
  - id: m04-l02-c2
    front: Which one should you reach for by default, let or var?
    back: let. Use var only if the value really is going to change. The compiler warns you when a var never changes.
  - id: m04-l02-c3
    front: What does `total += 5` mean?
    back: The same as total = total + 5. It computes with the current value of total and stores the result back in total. It only works if total is a var.
  - id: m04-l02-c4
    front: What naming convention does Swift use for constants and variables?
    back: camelCase, starting with a lowercase letter, with descriptive names like discountedPrice. Swift is case-sensitive.
---

## The idea in one sentence

A constant or a variable is a **name** for a value, and the name tells you what that value means.

## The problem: magic numbers

At the end of the previous lesson you wrote:

```swift
print("Coffee:", 45)
print("Bread:", 28)
print("Total:", 45 + 28)
```

```output
Coffee: 45
Bread: 28
Total: 73
```

It works, but `45` shows up twice. If coffee gets more expensive, you have to find and change every 45, and hope no other 45 means something else. A number that appears in the code with no explanation is called a **magic number**.

## Constants: let

**Plain definition:** `let` gives a name to a value that won't change.

**Precise definition:** `let name = value` declares a **constant**: a name bound to a value that can't be reassigned once it's set. The compiler guarantees it.

```swift
let coffeePrice = 45
let breadPrice = 28
print("Coffee:", coffeePrice)
print("Bread:", breadPrice)
print("Total:", coffeePrice + breadPrice)
```

```output
Coffee: 45
Bread: 28
Total: 73
```

Line by line:

1. `let coffeePrice = 45` creates the constant `coffeePrice` with the value 45. The `=` here **assigns**: it stores the value on the right in the name on the left.
2. Same for `breadPrice`.
3. `print` receives the constant's **value**. Writing `coffeePrice` in an expression is the same as writing 45.
4. Same for the bread.
5. `coffeePrice + breadPrice` is evaluated as `45 + 28`.

Now, if coffee costs 50, you change one line and the whole program follows. And anyone reading `coffeePrice + breadPrice` understands the calculation without guessing what 45 was.

## Variables: var

**Plain definition:** `var` gives a name to a value that can change.

**Precise definition:** `var name = value` declares a **variable**. After the declaration you can assign it a new value with `name = otherValue`.

```swift
var points = 0
print(points)
points = 10
print(points)
points = points + 5
print(points)
```

```output
0
10
15
```

1. `var points = 0` declares the variable with an initial value of 0.
2. Prints 0.
3. `points = 10` **reassigns**: the old value is gone and it's now 10. No `var` or `let`, because the name already exists.
4. Prints 10.
5. `points = points + 5` first works out the right side using the **current** value (10 + 5), then stores 15. It's the `←` arrow from the Module 2 pseudocode.
6. Prints 15.

### Compound assignment operators

Updating a variable based on its own value is so common that there are shortcuts:

| You write | Same as |
| --- | --- |
| `x += 3` | `x = x + 3` |
| `x -= 3` | `x = x - 3` |
| `x *= 3` | `x = x * 3` |
| `x /= 3` | `x = x / 3` |

```swift
var balance = 100
balance += 50
balance -= 30
balance *= 2
print(balance)
```

```output
240
```

100 + 50 = 150; 150 − 30 = 120; 120 × 2 = 240.

## let or var?

**Use `let` by default.** Switch to `var` only when the value really has to change.

This isn't a style preference. A constant is a guarantee: on any line of the program, `coffeePrice` has the same value. With a variable, you have to read through the code to know what it holds at any given point. Fewer variables means fewer things that can go wrong.

The compiler helps. If you declare a `var` inside a block and never change it, it warns you:

```swift warning variable 'price' was never mutated; consider changing to 'let' constant
do {
    var price = 45
    print(price)
}
```

```output
45
```

`do { … }` just groups lines into a block. It's used here so the compiler checks the name the way it would inside a function. In code written directly in `main.swift` or in a standalone file, names are global and the compiler doesn't give this warning.

## Naming rules and conventions

**Language rules** (break them and it doesn't compile):

- A name can't start with a digit: `2nd` isn't valid; `second` is.
- It can't contain spaces: `my name` isn't valid.
- Swift is case-sensitive: `age` and `Age` are different names.
- It can contain accented letters and other Unicode characters: `café` is valid.

```swift
let café = "Espresso"
print(café)
```

```output
Espresso
```

**Conventions** (it compiles either way, but the code gets hard to read if you ignore them):

- **camelCase** starting with a lowercase letter: `discountedPrice`, `itemCount`.
- Names that say **what the value is**, not what type it has: `age`, not `number`; `coffeePrice`, not `p`.
- A single letter is fine only in very short, conventional contexts, like `i` for a loop counter.

> [!note]
> Being allowed to use Unicode in names doesn't mean you should. Most professional teams name things in plain English, and that's what this course does. Whatever you pick, be consistent within a project.

## A practical example: a receipt with a discount

```swift
let coffeePrice = 45
let breadPrice = 28
let coffeeCount = 2
let discount = 10

var total = coffeePrice * coffeeCount
total += breadPrice
total -= discount

print("Subtotal before discount:", coffeePrice * coffeeCount + breadPrice)
print("Discount:", discount)
print("Total:", total)
```

```output
Subtotal before discount: 118
Discount: 10
Total: 108
```

The prices, the count and the discount are `let`: they're the givens of the problem and they don't change. Only `total` is `var`, because it's built up step by step. Every number appears **once**, with a name that explains it.

## Common mistakes

> [!error] error: cannot assign to value: 'price' is a 'let' constant
> You tried to reassign a constant. If the value really should change, declare it with `var`. If not, the error just saved you from an accidental change.

> [!error] error: left side of mutating operator isn't mutable: 'price' is a 'let' constant
> Same thing, with `+=`, `-=`, `*=` or `/=`: they only work on a `var`.

> [!error] error: variable 'x' used before being initialized
> You declared a name without a value (`var x: Int`) and read it before assigning one. Swift never lets you read garbage: assign a value before you use it.

> [!error] error: invalid redeclaration of 'total'
> You wrote `let total` or `var total` twice. To change the value of a variable that already exists, assign to it without `var`: `total = 5`.

> [!error] Mixing up = and ==
> `=` assigns. To ask whether two values are equal you use `==`, which you'll see in the lesson on comparison operators.

````exercise
id: m04-l02-e1
type: comprehension
prompt: A program stores a product's price (fixed), the quantity the customer keeps adding to the cart, and the total, which is recalculated with each product. Which declarations fit best?
choices:
  - text: "`let price`, `var quantity`, `var total`"
    correct: true
    why: The price doesn't change; quantity and total do.
  - text: "`var price`, `var quantity`, `var total`"
    correct: false
    why: It works, but price doesn't change and should be let. Swift would warn you.
  - text: "`let price`, `let quantity`, `let total`"
    correct: false
    why: Quantity and total change. With let, reassigning them wouldn't compile.
  - text: "`var price`, `let quantity`, `let total`"
    correct: false
    why: It's exactly backwards from what the problem needs.
solution: |
  **`let price`, `var quantity`, `var total`.** The rule is `let` by default and `var` only for what changes. The price is a fixed fact; the quantity and the total get updated. Declaring everything with `var` would compile, but you'd lose the guarantee that the price can't be changed by accident.
````

````exercise
id: m04-l02-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  var points = 10
  let bonus = 5
  points = points + bonus
  print(points)
  points += 2
  points *= 2
  print(points)
  let level = points / 10
  print(level, points % 10)
output: |
  15
  34
  3 4
hints:
  - "Each assignment uses the current value of points."
  - "points / 10 is integer division."
solution: |
  ```output
  15
  34
  3 4
  ```

  | Line | points | Prints |
  | --- | --- | --- |
  | `var points = 10` | 10 | |
  | `points = points + bonus` | 15 | |
  | `print(points)` | 15 | 15 |
  | `points += 2` | 17 | |
  | `points *= 2` | 34 | |
  | `print(points)` | 34 | 34 |

  `level` is `34 / 10`, integer division: **3**. `34 % 10` is the remainder: **4**. `print` separates them with a space.
````

````exercise
id: m04-l02-e3
type: fill-in
prompt: |
  Complete the program so it compiles and prints exactly:

  ```output
  Balance: 150
  ```
code: |
  [[1]] deposit = 50
  [[2]] balance = 100
  balance [[3]] deposit
  print("Balance:", balance)
blanks:
  - id: "1"
    answers: ["let"]
  - id: "2"
    answers: ["var"]
  - id: "3"
    answers: ["+="]
solution: |
  ```swift
  let deposit = 50
  var balance = 100
  balance += deposit
  print("Balance:", balance)
  ```

  `deposit` doesn't change: `let`. `balance` is modified on the third line, so it has to be `var`, or `+=` won't compile. `balance += deposit` is the same as `balance = balance + deposit`.
````

````exercise
id: m04-l02-e4
type: find-errors
prompt: This program doesn't compile. Pick out the real problems and write the fixed version.
code: |
  let limit = 3
  var attempts
  attempts = 0
  attempts += 1
  limit = 5
  var attempts = 2
  print(Attempts, limit)
choices:
  - text: "Line 2 declares a var with no value and no type, so the compiler doesn't know its type."
    correct: true
    why: "The message is type annotation missing in pattern. The simplest fix is var attempts = 0."
  - text: "Line 5 reassigns a constant."
    correct: true
    why: "limit is a let: cannot assign to value: 'limit' is a 'let' constant."
  - text: "Line 6 declares attempts a second time."
    correct: true
    why: "invalid redeclaration of 'attempts'. To change its value, attempts = 2 is enough."
  - text: "On line 7, Attempts with a capital A isn't the same name as attempts."
    correct: true
    why: Swift is case-sensitive.
  - text: "Line 4 is wrong: += only works with decimal numbers."
    correct: false
    why: "+= works with integers. The problem with attempts is in its declaration."
rubric:
  - I declared attempts with an initial value on a single line.
  - I decided whether limit should change and used let or var accordingly.
  - I removed the second declaration of attempts.
  - I used the same name, with the same capitalization, throughout the program.
  - My version compiles and prints two numbers.
solution: |
  A fixed version, assuming the limit really was supposed to change to 5:

  ```swift
  var limit = 3
  var attempts = 0
  attempts += 1
  limit = 5
  attempts = 2
  print(attempts, limit)
  ```

  ```output
  2 5
  ```

  If the limit wasn't supposed to change, the fix goes the other way: keep `let limit = 3` and delete `limit = 5`. The compiler can't know which one you meant; you can. Notice also that the two-step declaration (`var attempts` and then `attempts = 0`) would need a type annotation, which you'll see in the annotations lesson. Declaring and initializing on the same line is simpler.
````

````exercise
id: m04-l02-e5
type: refactor
prompt: |
  This program works out what a year of gym membership costs, including the sign-up fee. Rewrite it without magic numbers, using constants with clear names, and without changing the output.
code: |
  print("Monthly fees:", 450 * 12)
  print("Sign-up fee:", 300)
  print("First-year total:", 450 * 12 + 300)
rubric:
  - Each number appears only once, in a named constant.
  - The names use camelCase and explain what they mean.
  - I used let for every value that doesn't change.
  - The output is identical to the original.
solution: |
  ```swift
  let monthlyFee = 450
  let monthsPerYear = 12
  let signUpFee = 300

  let yearOfMonthlyFees = monthlyFee * monthsPerYear
  print("Monthly fees:", yearOfMonthlyFees)
  print("Sign-up fee:", signUpFee)
  print("First-year total:", yearOfMonthlyFees + signUpFee)
  ```

  ```output
  Monthly fees: 5400
  Sign-up fee: 300
  First-year total: 5700
  ```

  Everything is `let`: no value changes after it's calculated. The intermediate constant `yearOfMonthlyFees` avoids repeating `monthlyFee * monthsPerYear` and gives a name to a concept from the problem. If the monthly fee goes up, you change one line.
````

````exercise
id: m04-l02-e6
type: solve
prompt: |
  Write a program that **swaps** the values of two variables, `a = 3` and `b = 8`, and prints:

  ```output
  Before: 3 8
  After: 8 3
  ```

  You can't write the numbers 3 and 8 anywhere except in the initial declaration.
starter: |
  var a = 3
  var b = 8
  print("Before:", a, b)
hints:
  - "If you do a = b first, the 3 is lost."
  - Store one of the values in a temporary constant before you overwrite it.
rubric:
  - The program prints exactly the two lines.
  - I used a temporary constant so I wouldn't lose a value.
  - I didn't write 3 or 8 outside the declaration.
  - I explained why a = b followed by b = a doesn't work.
solution: |
  ```swift
  var a = 3
  var b = 8
  print("Before:", a, b)
  let temp = a
  a = b
  b = temp
  print("After:", a, b)
  ```

  ```output
  Before: 3 8
  After: 8 3
  ```

  With `a = b` and then `b = a`, both would end up as 8: the first assignment wipes out the 3 before you can copy it. The `temp` constant holds on to it. It's the same assignment-order problem you saw with Fibonacci in the trace tables lesson. (Swift also lets you write `(a, b) = (b, a)` with tuples, which you'll study in the functions module.)
````

## Summary

- `let` declares a constant; `var` declares a variable. Use `let` by default.
- `=` assigns: it works out the right side with the current values and stores the result.
- `+=`, `-=`, `*=` and `/=` update a `var` based on its own value.
- Swift won't let you read a name before it's initialized or reassign a constant.
- Names in camelCase, starting lowercase, that say what the value means. No magic numbers.
