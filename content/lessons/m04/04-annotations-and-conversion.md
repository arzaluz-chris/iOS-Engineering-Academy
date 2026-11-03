---
id: m04-l04
title: "Type annotations and type conversion"
description: You state a name's type explicitly when inference isn't enough, convert between Int, Double and String without surprises, and meet your first optional value when turning text into a number.
module: m04
order: 4
level: beginner
minutes: 50
prerequisites: [m04-l03]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Write type annotations and decide when they're needed.
  - Declare a constant without an initial value and assign it later.
  - Convert between Int and Double and predict the effect of truncation.
  - Turn numbers into text with String(…) and text into numbers with Int(…) and Double(…).
  - Use ?? to provide a default value when a text conversion fails.
terms:
  - term: Type annotation
    definition: "An explicit statement of a name's type, written with a colon after the name, as in let price: Double = 45."
  - term: Explicit conversion
    definition: Creating a value of one type from another by writing it in the code, for example Double(age). Swift never converts between numeric types on its own.
  - term: Truncate
    definition: Drop the decimal part of a number without rounding. Int(3.9) is 3 and Int(-3.9) is -3.
  - term: Optional
    definition: A type that can hold a value or no value (nil). Int("42") returns an Int? because the text might not be a number.
  - term: ?? operator
    definition: The nil-coalescing operator. a ?? b is the contents of a if there is one, or b if a is nil.
mastery:
  - Write the right annotation for a name declared without a value, or whose literal would be inferred as a different type.
  - Predict the result of Int(9.99), Int(-2.7), Double(7) / 2 and Int("twelve") ?? 0.
  - Fix the "binary operator cannot be applied to operands of type 'Int' and 'Double'" error with an explicit conversion and explain what's lost or kept.
  - Explain why Int("42") returns an Int? rather than an Int.
resources: [swift-book-basics]
cards:
  - id: m04-l04-c1
    front: How do you write a type annotation?
    back: "With a colon after the name: let price: Double = 45. Here 45 is stored as 45.0."
  - id: m04-l04-c2
    front: What is `Int(3.9)`, and what is `Int(-3.9)`?
    back: 3 and -3. Converting a Double to an Int truncates toward zero; it doesn't round.
  - id: m04-l04-c3
    front: Why does `Int("42")` return an `Int?`?
    back: Because the conversion can fail; Int("hello") has no number to return. The ? marks an optional, which can be nil.
  - id: m04-l04-c4
    front: What does `Int(text) ?? 0` do?
    back: If the text represents an integer, it gives you that integer; if not, it gives 0. ?? provides a default value when the optional is nil.
  - id: m04-l04-c5
    front: "Why doesn't `let a = 3; let b = 2.5; print(a * b)` compile?"
    back: Because a is an Int and b is a Double, and Swift doesn't mix them. You have to convert one, for example Double(a) * b.
---

## The idea in one sentence

When inference doesn't say what you mean, you say it with an **annotation**; when you need a different type, you ask for it with a **conversion**. Swift never does either behind your back.

## Type annotations

**Plain definition:** writing a name's type yourself instead of letting Swift work it out.

**Syntax:** a colon after the name, then the type.

```swift
let price: Double = 45
let initial: Character = "M"
var attempts: Int = 0
print(price, initial, attempts)
```

```output
45.0 M 0
```

Line by line:

1. Without the annotation, `45` would be an `Int`. With `: Double`, the literal is read as a decimal and prints as `45.0`.
2. Without the annotation, `"M"` would be a `String`.
3. Here the annotation is redundant: `0` would be inferred as `Int` anyway. It's valid, but it adds nothing.
4. `print` shows all three values.

### When to annotate

| Situation | Example |
| --- | --- |
| The literal would be inferred as a different type | `let price: Double = 45` |
| You declare without an initial value | `let message: String` |
| You want a type other than the default | `let initial: Character = "M"` |
| The annotation makes the intent clearer to the reader | Code that's read more often than it's written |

When inference gives the right type and it's obvious, the Swift convention is **not to annotate**. `let name: String = "Ana"` says nothing that `let name = "Ana"` doesn't.

### Declare now, assign later

A constant can be declared without a value as long as it's assigned **exactly once** before it's read. With no initial value there's nothing to infer from, so the annotation is required:

```swift
let greeting: String
greeting = "Hello"
print(greeting)
```

```output
Hello
```

This becomes useful when the value depends on a decision (`if`), which you'll see in the next module. Without the annotation, the compiler responds with `type annotation missing in pattern`.

## Converting between numeric types

Swift doesn't mix `Int` and `Double`:

```swift no-compile binary operator '*' cannot be applied to operands of type 'Int' and 'Double'
let quantity = 3
let unitPrice = 2.5
print(quantity * unitPrice)
```

Other languages convert silently. Swift doesn't, because every conversion can **lose information** and it wants you to make that call. You write a conversion with the type's name, as if it were a function:

```swift
let quantity = 3
let unitPrice = 2.5
print(Double(quantity) * unitPrice)
print(quantity * Int(unitPrice))
```

```output
7.5
6
```

1. `Double(quantity)` creates the `Double` 3.0. The multiplication is between `Double`s: **7.5**. Nothing is lost.
2. `Int(unitPrice)` creates the `Int` 2, because it **truncates** 2.5. The result, **6**, is wrong for a receipt. The conversion you picked changed what the calculation means.

Rule of thumb: convert **toward** the type that keeps the information you need. For money and measurements, that's usually `Double` (or cents as `Int`, as you saw in the previous lesson).

### Truncating isn't rounding

```swift
print(Int(9.99))
print(Int(-2.7))
print(Int((9.99).rounded()))
```

```output
9
-2
10
```

`Int(_:)` with a `Double` drops the decimal part **toward zero**: 9.99 becomes 9 and −2.7 becomes −2. If you want to round, round first with `rounded()`, which by default rounds to the nearest whole number (with .5 cases going away from zero), and then convert.

> [!warning]
> If the `Double` doesn't fit in an `Int` (for example `1e20`), the conversion stops the program with `Fatal error: Double value cannot be converted to Int because the result would be greater than Int.max`. Swift would rather stop than hand you a wrong number.

```swift runtime-error Double value cannot be converted to Int
let huge = 1e20
print(Int(huge))
```

## Numbers and text

### From number to text

`String(…)` turns a number into its text:

```swift
let floor = 5
print(String(floor) + "th floor")
print(String(2.5))
```

```output
5th floor
2.5
```

Now `+` works, because both sides are `String`s. In the last lesson of the module you'll see **interpolation**, which is almost always more convenient.

### From text to number: your first optional

Turning text into a number **can fail**. What number is `"twelve"`? That's why `Int("…")` doesn't return an `Int` but an **`Int?`**: an *optional*, which either contains an integer or contains nothing (`nil`).

```swift no-compile value of optional type 'Int?' must be unwrapped to a value of type 'Int'
let age = Int("30")
print(age + 1)
```

The compiler won't let you add to something that might not exist. The simplest way to get an `Int` is to provide a default value with the `??` operator:

```swift
let age = Int("30") ?? 0
print(age + 1)
print(Int("twelve") ?? 0)
print(Int("3.5") ?? -1)
print(Double("3.5") ?? -1)
```

```output
31
0
-1
3.5
```

1. `"30"` is an integer, so `age` is 30, and its type is now `Int`.
2. You can add to it with no problem: 31.
3. `"twelve"` isn't a number: `Int("twelve")` is `nil`, and `??` gives the default value, 0.
4. `"3.5"` isn't an **integer** either: `Int` rejects it.
5. `Double("3.5")` does work.

Optionals are one of Swift's central ideas, and they get their own module later on. For now, this is enough: **if an operation can fail, Swift makes you decide what happens when it does**.

> [!note]
> If you print the optional directly, `print(Int("42"))`, you'll see `Optional(42)` and the compiler will give you a warning. That's its way of reminding you that you haven't decided what to do about the `nil` case.

## A practical example: splitting liters

Someone types into an app how many liters of water there are (`"7"`) and how many bottles to split them into (`"2"`). The app has to show how much goes in each bottle, with decimals.

```swift
let litersText = "7"
let bottlesText = "2"

let liters = Int(litersText) ?? 0
let bottles = Int(bottlesText) ?? 1

let litersPerBottle = Double(liters) / Double(bottles)
print("Liters per bottle:", litersPerBottle)
print("With integers only:", liters / bottles)
```

```output
Liters per bottle: 3.5
With integers only: 3
```

Three deliberate decisions:

- If the liters text isn't a number, it uses 0 liters.
- If the bottles text isn't a number, it uses **1** bottle, not 0, so it never divides by zero.
- It converts to `Double` **before** dividing. `Double(liters / bottles)` would give 3.0: integer division would already have thrown away the .5.

## Common mistakes

> [!error] error: binary operator '*' cannot be applied to operands of type 'Int' and 'Double'
> You're mixing numeric types. Convert one of them explicitly, and pick the target type based on what you need to keep.

> [!error] Converting after dividing
> `Double(7 / 2)` is 3.0, not 3.5: the integer division happens first. Convert the operands, not the result.

> [!error] Expecting Int(…) to round
> `Int(9.99)` is 9. To round, use `Int(x.rounded())`.

> [!error] error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
> `Int("…")` and `Double("…")` return optionals. Use `?? defaultValue` until you study optionals properly.

> [!error] error: type annotation missing in pattern
> You declared a name with no initial value and no type. Add the annotation: `let message: String`.

````exercise
id: m04-l04-e1
type: comprehension
prompt: "What is the value of `x` after `let x = Int(Double(17) / 5)`?"
choices:
  - text: "3.4"
    correct: false
    why: An Int can't hold decimals.
  - text: "3"
    correct: true
    why: "Double(17) / 5 is 3.4, and converting to Int truncates: 3."
  - text: "4"
    correct: false
    why: The conversion doesn't round. It truncates.
  - text: It doesn't compile.
    correct: false
    why: Every conversion is explicit and valid.
solution: |
  **3.** `Double(17) / 5` is decimal division, 3.4. `Int(3.4)` drops the decimal part toward zero: 3. If you just wanted 3 without going through decimals, `17 / 5` gives it directly. If you wanted to round, `Int((Double(17) / 5).rounded())` also gives 3, because 3.4 is closer to 3.
````

````exercise
id: m04-l04-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let liters = 7
  let people = 2
  print(liters / people)
  print(Double(liters) / Double(people))
  print(Double(liters / people))
  print(Int(9.99), Int(-2.7))
  print(String(5) + String(5))
  print(Int("12") ?? 0, Int("twelve") ?? 0)
output: |
  3
  3.5
  3.0
  9 -2
  55
  12 0
hints:
  - "On line 5, the division happens before the conversion."
  - "Int(_:) truncates toward zero."
  - "String(5) is the text \"5\"."
solution: |
  ```output
  3
  3.5
  3.0
  9 -2
  55
  12 0
  ```

  1. Integer division: 3.
  2. Both converted to `Double` before dividing: 3.5.
  3. `liters / people` is already 3 (an integer); converting it afterward gives 3.0. The .5 was lost earlier.
  4. Truncating toward zero: 9 and −2.
  5. `"5" + "5"` concatenates text: `55`.
  6. `"12"` converts; `"twelve"` doesn't, and `??` gives 0.
````

````exercise
id: m04-l04-e3
type: fill-in
prompt: |
  Complete the program so it calculates the average, with decimals, of three whole-number grades and prints exactly:

  ```output
  Average: 8.0
  ```
code: |
  let sum = 9 + 7 + 8
  let count = 3
  let average = [[1]](sum) / [[2]](count)
  print("Average:", average)
blanks:
  - id: "1"
    answers: ["Double"]
  - id: "2"
    answers: ["Double"]
solution: |
  ```swift
  let sum = 9 + 7 + 8
  let count = 3
  let average = Double(sum) / Double(count)
  print("Average:", average)
  ```

  ```output
  Average: 8.0
  ```

  `sum` is 24 and it's an `Int`. To get an average with decimals you have to convert both operands to `Double` before dividing. Since 24 / 3 is exact, the result is 8.0; with other grades it would keep the decimals.
````

````exercise
id: m04-l04-e4
type: find-errors
prompt: This program should calculate the price, with 16% sales tax, of a product whose price arrives as text. It doesn't compile. Pick out the real problems and fix it.
code: |
  let priceText = "250"
  let price = Int(priceText)
  let rate = 0.16
  let tax = price * rate
  let total: Int = price + tax
  print("Total:", total)
choices:
  - text: "price is an Int?, not an Int; you need to provide a default value with ??."
    correct: true
    why: Int(priceText) can fail.
  - text: "price * rate mixes Int and Double."
    correct: true
    why: You have to convert price to Double.
  - text: "Annotating total as Int forces you to lose the cents."
    correct: true
    why: 250 × 1.16 = 290.0, but other prices would have decimals that an Int would truncate.
  - text: "0.16 isn't a valid literal; it should be written .16."
    correct: false
    why: The other way around. In Swift, .16 isn't valid; you write 0.16.
rubric:
  - I converted the text with Int(…) ?? 0 or Double(…) ?? 0.
  - I did every operation in Double.
  - I removed the Int annotation from total or changed it to Double.
  - The output is Total, 290.0.
solution: |
  ```swift
  let priceText = "250"
  let price = Double(priceText) ?? 0
  let rate = 0.16
  let tax = price * rate
  let total = price + tax
  print("Total:", total)
  ```

  ```output
  Total: 290.0
  ```

  Converting the text straight to `Double` solves two problems at once: the optional (with `??`) and the mixed types. `total` is inferred as `Double`. In a real app that handles money you'd work in cents or with `Decimal`, as you saw in the types lesson; this exercise is about conversions.
````

````exercise
id: m04-l04-e5
type: solve
prompt: |
  An app receives a temperature in degrees Celsius as text, `"36.6"`, and has to show:

  ```output
  Celsius: 36.6
  Fahrenheit: 97.88000000000001
  Fahrenheit rounded: 98
  ```

  The formula is F = C × 9 / 5 + 32. If the text isn't a valid number, use 0.
starter: |
  let text = "36.6"
hints:
  - "Double(text) ?? 0 converts the text."
  - "Write 9.0 / 5 so the division is decimal."
  - For rounding, Int(f.rounded()).
rubric:
  - I converted the text with Double(…) ?? 0.
  - The formula uses decimal division.
  - The rounded value uses rounded() before converting to Int.
  - The program prints exactly the three lines.
solution: |
  ```swift
  let text = "36.6"
  let celsius = Double(text) ?? 0
  let fahrenheit = celsius * 9 / 5 + 32
  print("Celsius:", celsius)
  print("Fahrenheit:", fahrenheit)
  print("Fahrenheit rounded:", Int(fahrenheit.rounded()))
  ```

  ```output
  Celsius: 36.6
  Fahrenheit: 97.88000000000001
  Fahrenheit rounded: 98
  ```

  Since `celsius` is a `Double`, the literals `9`, `5` and `32` are read as `Double` and the whole formula is decimal. `Int(fahrenheit)` would give 97 because it truncates; `rounded()` gives 98.0 first, and then the conversion gives 98.

  Look at the second line: on paper, 36.6 × 9 / 5 + 32 is exactly 97.88, but Swift prints `97.88000000000001`. That's the binary precision of `Double` you saw in the previous lesson: 36.6 has no exact binary representation, and the tiny error shows up when you print it. The rounded value isn't affected. To show a fixed number of decimal places there are formatting tools you'll see later.
````

## Summary

- A type annotation is written `name: Type`. Use it when there's no initial value or when the literal would be inferred as a different type.
- Swift never mixes or converts numeric types on its own: `Double(n)`, `Int(x)`, `String(n)`.
- `Int(x)` with a `Double` truncates toward zero; to round, use `Int(x.rounded())`.
- Convert the operands before dividing if you want decimals.
- `Int("…")` and `Double("…")` return optionals; `?? value` provides a default if the conversion fails.
