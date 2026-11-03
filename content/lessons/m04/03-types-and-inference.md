---
id: m04-l03
title: "Data types and type inference"
description: Every value in Swift has a type, and a name's type never changes. You meet Int, Double, Bool, String and Character, see how Swift works out types for you, and find out why 0.1 + 0.2 isn't exactly 0.3.
module: m04
order: 3
level: beginner
minutes: 45
prerequisites: [m04-l02]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Explain what a type is and what it decides about a value.
  - Recognize the basic types Int, Double, Bool, String and Character.
  - Predict which type Swift infers for a constant or variable from its initial value.
  - Check a value's type with type(of:).
  - Explain the limits of Int and Double, finite range and decimal precision.
terms:
  - term: Type
    definition: The kind of value a name holds. It decides which values are valid and which operations you can perform on it.
  - term: Int
    definition: A signed whole number. On current iPhones and Macs it's 64 bits, from −9223372036854775808 to 9223372036854775807.
  - term: Double
    definition: A 64-bit floating-point decimal number. It has about 15 or 16 significant digits of precision.
  - term: Bool
    definition: A logical value, true or false.
  - term: String
    definition: Text, a sequence of characters.
  - term: Character
    definition: A single character as a person sees it, for example "a", "é" or an emoji.
  - term: Type inference
    definition: The mechanism by which the compiler works out a name's type from the value it's initialized with.
  - term: Type safety
    definition: The guarantee that the compiler won't let you use a value as if it were another type without an explicit conversion.
mastery:
  - Say, without running it, which type Swift infers for let a = 7, let b = 7.0, let c = "7" and let d = 7 > 2.
  - Explain why var x = 5 followed by x = 2.5 doesn't compile.
  - Explain why 0.1 + 0.2 == 0.3 is false and what that means for money calculations.
  - Pick the right type for an age, a price, a name, an initial and "is it active?".
resources: [swift-book-basics, swift-book-basic-operators]
cards:
  - id: m04-l03-c1
    front: Which type does Swift infer for `let x = 3.0`, and for `let y = 3`?
    back: x is a Double, because the literal has a decimal point. y is an Int.
  - id: m04-l03-c2
    front: Can a variable's type change after it's declared?
    back: No. The type is fixed at declaration. var x = 5 is an Int forever; x = 2.5 doesn't compile.
  - id: m04-l03-c3
    front: Why is `0.1 + 0.2 == 0.3` false in Swift?
    back: Double stores numbers in binary, and 0.1, 0.2 and 0.3 have no exact binary representation. The sum comes out as 0.30000000000000004.
  - id: m04-l03-c4
    front: What is `type(of:)` for?
    back: "It returns a value's type while the program is running. print(type(of: 42)) prints Int."
  - id: m04-l03-c5
    front: What's the difference between String and Character?
    back: A String is text of any length. A Character is exactly one perceived character, like "a" or "é".
---

## The idea in one sentence

Swift has no such thing as just "a value": there's an **integer**, a **decimal**, a piece of **text**, and each one has its own rules that the compiler enforces.

## What a type is

**Plain definition:** the type says what kind of data a value is.

**Precise definition:** a type defines the set of possible values and the operations allowed on them. An `Int` can be 42 or −7, but not 3.5 or "hello". You can use `%` with an `Int`, but not with a `String`.

You first saw types with literals in the `print` lesson. Now you connect them to names: when you declare a constant or a variable, its type is fixed.

## The basic types

| Type | What it holds | Literals | Typical use |
| --- | --- | --- | --- |
| `Int` | Whole numbers | `42`, `-7`, `1_000` | Age, quantity, position |
| `Double` | Decimals | `3.5`, `0.1`, `2.0` | Distance, temperature, average |
| `Bool` | True or false | `true`, `false` | Is it active? Did they pass? |
| `String` | Text | `"Hello"`, `""` | Name, message |
| `Character` | One character | `"a"`, `"é"` | An initial |

There are more numeric types, like `Float` (a 32-bit decimal, less precise) and fixed-size integers like `Int8` or `UInt8`. To start with, use `Int` for whole numbers and `Double` for decimals: they're what the standard library and Apple's frameworks use by default.

## Type inference

**Plain definition:** Swift figures out the type for you, and doesn't guess wrong.

**Technical explanation:** when you write `let age = 30`, you didn't say that `age` is an `Int`. The compiler **infers** it from the initial value: `30` is an integer literal, and the default type for an integer literal is `Int`. Nothing magic or dynamic is going on. It happens at compile time, and from then on `age` is an `Int` forever.

```swift
let age = 30
let height = 1.72
let name = "Ana"
let isActive = true
print(type(of: age), type(of: height), type(of: name), type(of: isActive))
```

```output
Int Double String Bool
```

Line by line:

1. `30` is an integer literal, so `age` is an `Int`.
2. `1.72` has a decimal point, so `height` is a `Double`.
3. `"Ana"` is in quotes, so `name` is a `String`.
4. `true` is a Boolean literal, so `isActive` is a `Bool`.
5. `type(of:)` returns a value's type while the program runs. Use it to check what you think was inferred.

### The type of an expression

Inference applies to expressions too:

```swift
let a = 5
let b = 2.0
print(type(of: a * 2), type(of: b * 2), type(of: 3 + 0.5))
```

```output
Int Double Double
```

- `a * 2`: `Int` times `Int` gives `Int`.
- `b * 2`: the literal `2` adapts to `Double` because `b` is a `Double`.
- `3 + 0.5`: **literals** don't have a fixed type until they're used. Here both are read as `Double`.

That flexibility belongs to literals only. A **name** already has its type, and Swift won't change it: `a * b` doesn't compile, because `a` is an `Int` and `b` is a `Double`. You'll solve that with explicit conversions in the next lesson.

## A name's type doesn't change

```swift no-compile cannot assign value of type 'Double' to type 'Int'
var x = 5
x = 2.5
```

`x` was inferred as `Int`. Assigning `2.5` to it would mean changing its type, and Swift doesn't allow that. This is called **type safety**: the compiler guarantees that on every line, `x` is an integer. If you want it to hold decimals, declare it that way from the start, with a decimal value, `var x = 5.0`, or with an annotation, as you'll see in the next lesson.

## The limits of numbers

### Int has a range

```swift
print(Int.max)
print(Int.min)
```

```output
9223372036854775807
-9223372036854775808
```

On current iPhones and Macs, `Int` is 64 bits. If an operation goes past that range, Swift doesn't quietly give you a wrong result: if it can tell at compile time, it's a compile error, and if it happens while the program runs, the program stops. You saw this in the errors lesson in Module 3.

### Double is precise, but not exact

```swift
print(0.1 + 0.2)
print(0.1 + 0.2 == 0.3)
```

```output
0.30000000000000004
false
```

`Double` stores numbers in **binary**. Just as 1/3 has no exact decimal representation (0.3333…), 0.1 has no exact binary representation. The error is tiny, but it's there, and that's why comparing decimals with `==` is risky. (`==` checks whether two values are equal. You'll cover it properly in the lesson on comparison operators.)

> [!warning]
> Don't use `Double` for money when you need to be exact to the cent. A common approach is to work in cents with `Int` (4550 instead of 45.50). Foundation also has the `Decimal` type, which you'll study later.

## String and Character

A `String` is text of any length, even empty (`""`). A `Character` is **a single** character. Since both are written with double quotes, a literal like `"a"` is inferred as a `String` unless you say otherwise with an annotation:

```swift
let initial: Character = "A"
print(initial, type(of: initial))
```

```output
A Character
```

```swift no-compile cannot convert value of type 'String' to specified type 'Character'
let initial: Character = "AB"
```

`"AB"` is two characters and doesn't fit in a `Character`. The `: Character` syntax is a **type annotation**, the topic of the next lesson.

## A practical example: a product listing

```swift
let name = "Headphones"
let priceInCents = 89_900
let unitsInStock = 12
let rating = 4.6
let isAvailable = true

print(name, type(of: name))
print(priceInCents, type(of: priceInCents))
print(unitsInStock, type(of: unitsInStock))
print(rating, type(of: rating))
print(isAvailable, type(of: isAvailable))
```

```output
Headphones String
89900 Int
12 Int
4.6 Double
true Bool
```

Every type choice has a reason: the price is in **whole cents** so it stays exact; the units are whole numbers because nobody sells half a unit; the rating is an average and needs decimals; `isAvailable` can only be yes or no. Notice that `print` shows `89_900` as `89900`: the underscore only exists in the source code.

## Common mistakes

> [!error] error: cannot assign value of type 'Double' to type 'Int'
> The variable was inferred as `Int` from its initial value. If it needs to hold decimals, initialize it with a decimal (`0.0`) or annotate its type.

> [!error] error: cannot assign value of type 'Int' to type 'String'
> You tried to store a number in a name of type `String`. If you wanted text, use quotes or an explicit conversion.

> [!error] Comparing decimals with ==
> `0.1 + 0.2 == 0.3` is `false`. Compare decimals with a tolerance, or work with integers (cents, for example).

> [!error] Initializing something that should be a decimal with 0
> `var average = 0` creates an `Int`. Later, `average = 7.5` doesn't compile. Write `var average = 0.0`.

````exercise
id: m04-l03-e1
type: comprehension
multiple: true
prompt: Which of these declarations create a `Double`? Select all that apply.
choices:
  - text: "`let a = 10.0`"
    correct: true
    why: The literal has a decimal point.
  - text: "`let b = 10`"
    correct: false
    why: Integer literal, inferred as Int.
  - text: "`let c = 10 / 4`"
    correct: false
    why: Two integer literals. Integer division, an Int with the value 2.
  - text: "`let d = 10 / 4.0`"
    correct: true
    why: One decimal literal makes both be read as Double. The value is 2.5.
  - text: "`let e = \"10.0\"`"
    correct: false
    why: In quotes, it's a String.
solution: |
  **`a`** and **`d`** are `Double`. In `10 / 4.0`, since literals have no fixed type, Swift reads both as `Double` and the result is 2.5. `10 / 4` is integer division (2, an `Int`). `"10.0"` is text.
````

````exercise
id: m04-l03-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let pieces = 7
  let boxes = 2
  let weightPerPiece = 1.5
  print(pieces / boxes)
  print(type(of: pieces / boxes))
  print(weightPerPiece * 4)
  print(type(of: weightPerPiece * 4))
  print(type(of: "7"), type(of: 7 > 2))
output: |
  3
  Int
  6.0
  Double
  String Bool
hints:
  - "pieces / boxes: both are Int."
  - "A Double always prints with a decimal point, even when it's a whole number: 6.0."
  - "7 > 2 is a comparison. Its result is true or false."
solution: |
  ```output
  3
  Int
  6.0
  Double
  String Bool
  ```

  1. `7 / 2` between `Int`s is integer division: **3**.
  2. Operating on two `Int`s gives an `Int`.
  3. `1.5 * 4`: the literal `4` adapts to `Double`, so the result is **6.0**. A `Double` prints with a decimal point.
  4. That's why the type is `Double`.
  5. `"7"` is a `String`; `7 > 2` is a comparison and produces a `Bool`.
````

````exercise
id: m04-l03-e3
type: find-errors
prompt: This program tracks a student's average, but it doesn't compile. Pick out the real problems and write a fixed version.
code: |
  var average = 0
  let name = "Luis"
  average = 8.5
  name = 10
  print(name, average)
choices:
  - text: "average is inferred as Int from its initial value 0, so it won't accept 8.5."
    correct: true
    why: "cannot assign value of type 'Double' to type 'Int'."
  - text: "name is a String and a constant, so it can't take 10."
    correct: true
    why: There are two problems on that line, the type and the fact that it's a let.
  - text: "print can't take a String and a number at the same time."
    correct: false
    why: print accepts values of any type, separated by commas.
  - text: "Variable names can't start with a."
    correct: false
    why: There's no such rule.
rubric:
  - I initialized average with a decimal, 0.0.
  - I removed or fixed the assignment to name.
  - My version compiles and prints the name and the average.
solution: |
  ```swift
  var average = 0.0
  let name = "Luis"
  average = 8.5
  print(name, average)
  ```

  ```output
  Luis 8.5
  ```

  `var average = 0` fixes the type as `Int` forever; `0.0` fixes it as `Double`. The line `name = 10` had two errors at once: `name` is a constant, and it's a `String`. If the goal was to store a grade, it needed a different name with a numeric type.
````

````exercise
id: m04-l03-e4
type: solve
prompt: |
  Pick the right type for each piece of data in a user profile, and write a program that declares them using inference (no annotations, except where you can't avoid one) and prints each one along with its type using `type(of:)`:

  - username
  - birth year
  - height in meters
  - whether they accepted the terms
  - initial of their last name

  Then explain in one sentence why you chose each type.
starter: |
  let username = "chris"
hints:
  - For the initial you need a type annotation. Without one, "A" is inferred as a String.
  - "Height needs decimals: 1.75."
rubric:
  - Every piece of data has a suitable type and a reason for it.
  - I used inference everywhere except the initial.
  - The program prints each value with its type.
  - I used let because none of them change.
solution: |
  ```swift
  let username = "chris"
  let birthYear = 1998
  let height = 1.75
  let acceptedTerms = true
  let lastNameInitial: Character = "A"

  print(username, type(of: username))
  print(birthYear, type(of: birthYear))
  print(height, type(of: height))
  print(acceptedTerms, type(of: acceptedTerms))
  print(lastNameInitial, type(of: lastNameInitial))
  ```

  ```output
  chris String
  1998 Int
  1.75 Double
  true Bool
  A Character
  ```

  Username: text, `String`. Year: a whole number, `Int`. Height: needs decimals, `Double`. Terms: only yes or no, `Bool`. Initial: exactly one character, `Character`, which you have to annotate because a literal in quotes is inferred as `String`.
````

````exercise
id: m04-l03-e5
type: explain
prompt: Explain what this program prints, why, and what you'd do in a payments app to avoid the problem.
code: |
  let price = 0.1
  let tax = 0.2
  print(price + tax == 0.3)
rubric:
  - I said it prints false.
  - I explained that Double uses a binary representation in which 0.1 and 0.2 aren't exact.
  - I mentioned that the sum comes out as 0.30000000000000004.
  - I suggested working with integers (cents) or another exact type for money.
solution: |
  It prints **false**. `Double` represents numbers in binary, and 0.1 and 0.2 have no exact binary representation, just as 1/3 has none in decimal. The sum is `0.30000000000000004`, which isn't equal to the `Double` closest to 0.3.

  In a payments app, store amounts in **cents as `Int`** (10 cents and 20 cents add up to exactly 30) or use an exact decimal type like Foundation's `Decimal`. Convert to dollars with decimals only when you display the value.
````

## Summary

- Every value has a type, and a name's type is fixed when it's declared.
- Basic types: `Int`, `Double`, `Bool`, `String` and `Character`.
- Swift **infers** the type from the initial value: whole number → `Int`, with a decimal point → `Double`, in quotes → `String`.
- Literals adapt to their context; names don't. `Int` and `Double` don't mix without a conversion.
- `Int` has a finite range and `Double` isn't exact: `0.1 + 0.2 == 0.3` is `false`.
- `type(of:)` shows a value's type.
