---
id: m04-l05
title: "Comparison operators and logical operators"
description: You produce Bool values by comparing numbers and text, and combine them with &&, || and ! to express conditions like "an adult with a ticket". It's the groundwork for every decision in the next module.
module: m04
order: 5
level: beginner
minutes: 45
prerequisites: [m04-l03]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Use the comparison operators ==, !=, <, >, <= and >= with numbers and text.
  - Combine conditions with &&, || and ! and predict the result.
  - Apply the precedence of ! over && and of && over ||, and use parentheses to make it clear.
  - Explain short-circuit evaluation.
  - Avoid the typical mistakes when comparing text and decimals.
terms:
  - term: Comparison operator
    definition: An operator that compares two values of the same type and produces a Bool, like == or <.
  - term: Logical operator
    definition: An operator that combines or inverts Bool values. In Swift, && (and), || (or) and ! (not).
  - term: Condition
    definition: An expression whose result is a Bool. It's what if, while and guard will ask about in the next module.
  - term: Short-circuit evaluation
    definition: The rule by which && doesn't evaluate its right side if the left side is false, and || doesn't evaluate it if the left side is true, because the result is already settled.
  - term: Truth table
    definition: A table that lists the result of a logical operator for every combination of true and false.
  - term: De Morgan's laws
    definition: "Equivalences for negating compound conditions: !(a && b) is the same as !a || !b, and !(a || b) is the same as !a && !b."
mastery:
  - Predict the result of expressions like !(age < 18) && hasPermission for given values.
  - Write the condition "between 18 and 64, inclusive" and the condition "outside that range" without boundary mistakes.
  - Explain why "éclair" < "zebra" is false in Swift.
  - Compare two Doubles with a tolerance instead of ==.
resources: [swift-book-basic-operators]
cards:
  - id: m04-l05-c1
    front: What's the difference between `=` and `==`?
    back: = assigns a value to a name. == compares two values and produces a Bool.
  - id: m04-l05-c2
    front: What's the precedence of `!`, `&&` and `||`?
    back: "! first, then &&, then ||. a || b && c means a || (b && c). When in doubt, use parentheses."
  - id: m04-l05-c3
    front: What is short-circuit evaluation?
    back: If the left side of && is false, the right side isn't evaluated; if the left side of || is true, it isn't either. The result is already settled.
  - id: m04-l05-c4
    front: How do you negate "age >= 18 && hasTicket" using De Morgan?
    back: age < 18 || !hasTicket. Each part is negated and && becomes ||.
  - id: m04-l05-c5
    front: Why shouldn't you compare two Doubles with ==?
    back: Because of binary precision, 0.1 + 0.2 == 0.3 is false. Check whether the absolute difference is below a tolerance, abs(a - b) < 0.000001.
---

## The idea in one sentence

A comparison asks a yes-or-no question and answers with a `Bool`; logical operators combine those answers.

## Comparison operators

| Operator | Question | Example | Result |
| --- | --- | --- | --- |
| `==` | equal? | `5 == 5` | `true` |
| `!=` | different? | `5 != 3` | `true` |
| `<` | less than? | `3 < 5` | `true` |
| `>` | greater than? | `3 > 5` | `false` |
| `<=` | less than or equal? | `5 <= 5` | `true` |
| `>=` | greater than or equal? | `4 >= 5` | `false` |

The result of a comparison is a **value** of type `Bool`. You can print it, store it in a constant and operate on it:

```swift
let age = 20
let isAdult = age >= 18
print(isAdult)
print(age == 21, age != 21)
```

```output
true
false true
```

Line by line:

1. `age` is 20.
2. `age >= 18` evaluates to `true` and is stored in `isAdult`, which is inferred as `Bool`.
3. Prints `true`.
4. `age == 21` is `false` and `age != 21` is `true`.

Naming a condition, like `isAdult`, makes the code read like a sentence. `Bool` names usually start with *is*, *has*, *can* or *should*.

### You can only compare values of the same type

```swift no-compile binary operator '==' cannot be applied to operands of type 'String' and 'Int'
print("5" == 5)
```

Swift doesn't consider the text `"5"` and the number `5` comparable. Convert one of them, as you saw in the previous lesson.

### One comparison at a time

In math you write 1 < x < 10. In Swift you can't:

```swift no-compile adjacent operators are in non-associative precedence group 'ComparisonPrecedence'
let x = 5
print(1 < x < 10)
```

You write it as two comparisons joined by "and": `1 < x && x < 10`.

## Logical operators

| Operator | Name | `true` when… |
| --- | --- | --- |
| `a && b` | and (AND) | both are `true` |
| `a \|\| b` | or (OR) | at least one is `true` |
| `!a` | not (NOT) | `a` is `false` |

The full truth table:

| a | b | `a && b` | `a \|\| b` | `!a` |
| --- | --- | --- | --- | --- |
| true | true | true | true | false |
| true | false | false | true | false |
| false | true | false | true | true |
| false | false | false | false | true |

Swift's "or" is **inclusive**: `true || true` is `true`. In everyday English, "coffee or tea?" is usually exclusive. In programming, it isn't.

```swift
let age = 30
let hasTicket = true
let isStudent = false

print(age >= 18 && hasTicket)
print(isStudent || age < 12)
print(!isStudent)
```

```output
true
false
true
```

1. An adult **and** has a ticket: both are true.
2. A student **or** under 12: neither holds.
3. **Not** a student: `!false` is `true`.

## Precedence and parentheses

When you combine several operators, Swift groups them like this:

1. `!` first.
2. Then the comparisons (`<`, `==`…).
3. Then `&&`.
4. Finally `||`.

That's why `a || b && c` means `a || (b && c)`, not `(a || b) && c`:

```swift
let a = true
let b = false
let c = false
print(a || b && c)
print((a || b) && c)
```

```output
true
false
```

Same rule as with arithmetic: if someone has to think about precedence to understand your condition, **add parentheses**.

## Short-circuit evaluation

In `a && b`, if `a` is `false`, the result will be `false` no matter what `b` is. Swift **doesn't evaluate** `b`. With `||`, if `a` is `true`, it doesn't evaluate `b` either.

That lets you put first the condition that protects the second one:

```swift
let count = 0
let total = 100
print(count != 0 && total / count > 10)
```

```output
false
```

Since `count != 0` is `false`, the division `total / count` never runs. If you swapped the order, the program would try to divide by zero and stop. The order of the conditions matters.

## Negating conditions: De Morgan

Negating a compound condition is a classic source of bugs. **De Morgan's laws** say:

- `!(a && b)` is the same as `!a || !b`
- `!(a || b)` is the same as `!a && !b`

Example: "can enter" is `age >= 18 && hasTicket`. "**Can't** enter" isn't `age < 18 && !hasTicket`, it's `age < 18 || !hasTicket`: missing either one is enough.

## Comparing text

`==` compares text character by character, and it's case-sensitive:

```swift
print("house" == "house", "house" == "House")
print("a" < "b", "Z" < "a", "10" < "9")
print("éclair" < "zebra")
```

```output
true false
true true true
false
```

- `"house"` and `"House"` are different.
- `<` between strings is **not** dictionary alphabetical order. It compares characters by their order in Unicode: every unaccented uppercase letter comes before the lowercase ones (`"Z" < "a"`), digits are compared as characters (`"10" < "9"`, because `"1"` comes before `"9"`) and accented letters come after z (`"éclair" < "zebra"` is `false`).

To sort words the way a person expects, Foundation has language-aware comparisons. You'll see them when you work with collections and text.

## Comparing decimals

Because of the `Double` precision you saw in the types lesson, `==` between calculated decimals isn't reliable. Compare the **difference** against a small tolerance:

```swift
let result = 0.1 + 0.2
print(result == 0.3)
print(abs(result - 0.3) < 0.000001)
```

```output
false
true
```

`abs(_:)` gives the absolute value. The tolerance (one millionth here) depends on your problem.

## A practical example: movie theater rules

```swift
let age = 15
let isWithAdult = true
let isAdultsOnlyMovie = false
let isWednesday = true

let canEnter = !isAdultsOnlyMovie || age >= 18
let needsCompanion = age < 13 && !isWithAdult
let getsDiscount = isWednesday || age < 12 || age >= 60

print("Can enter:", canEnter && !needsCompanion)
print("Discount:", getsDiscount)
```

```output
Can enter: true
Discount: true
```

Each business rule is a named constant. The final condition reads almost like the rulebook: "can enter and doesn't need a companion". If a rule changes, you change one line.

## Common mistakes

> [!error] error: use of '=' in a boolean context, did you mean '=='?
> You wrote `=` where you meant to compare. `=` assigns; `==` compares.

> [!error] error: adjacent operators are in non-associative precedence group 'ComparisonPrecedence'
> You wrote two comparisons in a row, like `1 < x < 10`. Join them with `&&`: `1 < x && x < 10`.

> [!error] Wrong boundaries
> "Between 18 and 64, inclusive" is `age >= 18 && age <= 64`. With `>` or `<` you lose the endpoints. Always test the boundaries, as you learned in Module 2.

> [!error] Negating a compound condition incorrectly
> The negation of `a && b` is `!a || !b`. Flipping only the comparison signs without changing `&&` to `||` produces a different condition.

> [!error] Sorting text with < and expecting alphabetical order
> `"Zebra" < "apple"` is `true` and `"éclair" < "zebra"` is `false`. `<` compares Unicode characters, not dictionary order.

````exercise
id: m04-l05-e1
type: comprehension
prompt: Which is the right condition for "the temperature is between 18 and 25 degrees, inclusive"?
choices:
  - text: "`18 <= temperature <= 25`"
    correct: false
    why: Swift doesn't let you chain comparisons. It doesn't compile.
  - text: "`temperature >= 18 && temperature <= 25`"
    correct: true
    why: Two comparisons that must both hold, including both endpoints.
  - text: "`temperature > 18 && temperature < 25`"
    correct: false
    why: It excludes 18 and 25, which the statement includes.
  - text: "`temperature >= 18 || temperature <= 25`"
    correct: false
    why: With ||, every number satisfies at least one of the two. It's always true.
solution: |
  **`temperature >= 18 && temperature <= 25`.** "Between" requires both conditions at once, so they're joined with `&&`. "Inclusive" calls for `>=` and `<=`. With `||` the condition would always be true: 100 is greater than 18, and −5 is less than 25.
````

````exercise
id: m04-l05-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let age = 17
  let hasPermission = true
  print(age >= 18)
  print(age >= 18 || hasPermission)
  print(!(age < 18) && hasPermission)
  print(age == 17 && !hasPermission || age > 10)
  print("house" == "House", "a" < "b")
output: |
  false
  true
  false
  true
  false true
hints:
  - "Line 5: the parentheses first, then !, then &&."
  - "Line 6: && comes before ||."
solution: |
  ```output
  false
  true
  false
  true
  false true
  ```

  1. 17 isn't greater than or equal to 18: `false`.
  2. `false || true`: `true`.
  3. `age < 18` is `true`; negated, `false`; `false && true` is `false`.
  4. It groups as `(age == 17 && !hasPermission) || age > 10`: `(true && false) || true` is `true`.
  5. Case matters: `false`. `"a"` comes before `"b"`: `true`.
````

````exercise
id: m04-l05-e3
type: fill-in
prompt: |
  Complete the conditions. A user can post if they're logged in **and** their account is **not** suspended. Show a warning if they **can't** post.
code: |
  let isLoggedIn = true
  let isSuspended = false
  let canPost = isLoggedIn [[1]] [[2]]isSuspended
  let showWarning = !isLoggedIn [[3]] isSuspended
  print(canPost, showWarning)
blanks:
  - id: "1"
    answers: ["&&"]
  - id: "2"
    answers: ["!"]
  - id: "3"
    answers: ["||"]
solution: |
  ```swift
  let isLoggedIn = true
  let isSuspended = false
  let canPost = isLoggedIn && !isSuspended
  let showWarning = !isLoggedIn || isSuspended
  print(canPost, showWarning)
  ```

  ```output
  true false
  ```

  `showWarning` is the negation of `canPost`. By De Morgan, `!(isLoggedIn && !isSuspended)` is `!isLoggedIn || isSuspended`: the `&&` becomes `||` and each part is negated (and `!!isSuspended` is `isSuspended`). Writing `let showWarning = !canPost` would also be correct; it's shorter and can't fall out of sync.
````

````exercise
id: m04-l05-e4
type: find-errors
prompt: |
  This program decides whether an order ships free: purchases of 500 dollars or more, **or** any purchase if the customer is premium. It also wants to know whether the total matches a 99.9 coupon. It doesn't compile and it has logic errors. Pick out the real problems and write the fixed version.
code: |
  let total = 99.9
  let isPremium = false
  let freeShipping = total > 500 && isPremium
  if total = 99.9 {
      print("Coupon applied")
  }
  print(freeShipping)
choices:
  - text: "The rule uses && but the statement says \"or\"."
    correct: true
    why: With &&, only premium customers with large purchases would get free shipping.
  - text: "The rule uses > but the statement says \"500 or more\"."
    correct: true
    why: A purchase of exactly 500 should ship free; it needs >=.
  - text: "Line 4 uses = instead of ==."
    correct: true
    why: "Compile error: use of '=' in a boolean context."
  - text: "Comparing 99.9 with == is fragile if total is the result of a calculation."
    correct: true
    why: It works here because total is the same literal, but with a calculated total it could fail. A tolerance is safer.
  - text: "isPremium can't be used with && because it's a constant."
    correct: false
    why: Being a constant has nothing to do with whether it can be used in a condition.
rubric:
  - I changed the rule to total >= 500 || isPremium.
  - I replaced = with == or, better, used a comparison with a tolerance.
  - I mentally tested the boundaries 499.99, 500 and a premium customer with a small total.
solution: |
  ```swift
  let total = 99.9
  let isPremium = false
  let freeShipping = total >= 500 || isPremium
  let matchesCoupon = abs(total - 99.9) < 0.000001
  print(freeShipping, matchesCoupon)
  ```

  ```output
  false true
  ```

  You'll study `if` in the next module; here the comparison is stored in a named constant. The fixed rule gives free shipping at exactly 500 and to any premium customer. The coupon comparison uses a tolerance because in a real program `total` would come from adding up decimal prices.
````

````exercise
id: m04-l05-e5
type: solve
prompt: |
  A year is a leap year if it's divisible by 4, except for years divisible by 100 that aren't divisible by 400 (Module 2). Write **a single Boolean expression** using `%`, `==`, `!=`, `&&` and `||` that works it out, store it in `isLeapYear` and test it with 1900, 2000, 2023 and 2024. Print each year with its result.
starter: |
  let year = 2024
hints:
  - "Leap year if: (divisible by 4 and not by 100) or (divisible by 400)."
  - "\"Divisible by n\" is year % n == 0."
  - Since you don't have loops yet, to test several years you can repeat the block with another constant, or change the value and run it again.
rubric:
  - The expression is (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 or an equivalent.
  - I used parentheses to make the grouping clear.
  - "I tested all four years and got: 1900 false, 2000 true, 2023 false, 2024 true."
solution: |
  ```swift
  let years = [1900, 2000, 2023, 2024]
  for year in years {
      let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
      print(year, isLeapYear)
  }
  ```

  ```output
  1900 false
  2000 true
  2023 false
  2024 true
  ```

  The expression says: "divisible by 4 but not by 100, **or** divisible by 400". The parentheses aren't required, because `&&` comes before `||`, but they put the rule in plain view. The `for` loop just repeats the test for each year; you'll study it in the next module. Compare it with the algorithm from the edge cases lesson: it's the same rule, written as a single `Bool` value instead of a series of decisions.
````

## Summary

- `==`, `!=`, `<`, `>`, `<=` and `>=` compare values of the same type and produce a `Bool`.
- `&&` requires both conditions, `||` at least one (inclusive), `!` inverts.
- Precedence: `!`, comparisons, `&&`, `||`. Use parentheses so the intent is obvious.
- `&&` and `||` short-circuit: put first the condition that protects the second.
- Negating `a && b` gives `!a || !b` (De Morgan).
- `<` between strings compares Unicode characters, not alphabetical order; compare `Double`s with a tolerance.
