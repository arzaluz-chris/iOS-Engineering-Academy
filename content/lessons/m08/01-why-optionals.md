---
id: m08-l01
title: "Why optionals exist"
description: You find out what problem optionals solve, read Int? as Optional<Int>, recognize the standard library calls that return optionals and why, and see why the compiler won't let you use an Int? as if it were an Int.
module: m08
order: 1
level: beginner
minutes: 40
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l06]
objectives:
  - Explain the problem optionals solve, compared with sentinels, flags and null references.
  - Read and write optional types, both as Int? and as Optional<Int>.
  - Assign and compare nil, and know that only optional types can hold it.
  - Recognize the common standard library calls that return optionals and say why each one can have no answer.
  - Explain the warning you get when you print an optional, and the error you get when you use an Int? as an Int.
terms:
  - term: Optional
    definition: "A type that holds either a value of some other type or nothing at all. Int? holds either an Int or nothing."
  - term: nil
    definition: "The value of an optional that holds nothing. Only optional types can be nil."
  - term: Wrapped type
    definition: "The type of the value inside an optional. For Int?, the wrapped type is Int."
  - term: Unwrapping
    definition: "Getting the value out of an optional after checking that there is one. The next lessons cover the ways to do it."
  - term: Null reference
    definition: "In many languages, a special value that any reference can hold to mean \"points to nothing\". Using it as if it pointed to something is a common source of crashes."
mastery:
  - Say which of Int("7"), [Int]().first, a dictionary lookup and 3 + 4 produce optionals, and why.
  - Declare an optional variable with and without an initial value and say what it holds.
  - Explain why print(Int("42")) shows Optional(42) and why the compiler warns about it.
  - Read the "must be unwrapped" error and name the two quick fixes the compiler suggests.
  - Explain why an optional is safer than returning -1 for "not found".
resources: [swift-optional, swift-book-basics, swift-book-collection-types]
cards:
  - id: m08-l01-c1
    front: What does the type `Int?` mean, and what's its long form?
    back: "An optional Int: it holds either an Int or nothing (nil). Int? is shorthand for Optional<Int>."
  - id: m08-l01-c2
    front: Name three standard library calls that return optionals.
    back: "Int(\"…\") (the text may not be a number), array.first and array.min() (the array may be empty), and dictionary[key] (the key may not be there)."
  - id: m08-l01-c3
    front: "Why doesn't `let x: Int = nil` compile?"
    back: "Only optional types can hold nil. An Int always holds a number. Write Int? if the value can be missing."
  - id: m08-l01-c4
    front: What does an optional give you that a sentinel like -1 doesn't?
    back: "The compiler knows the value may be missing and won't let you use it as a plain value until you've handled the nil case. Nothing forces the caller to check for -1."
---

## The idea in one sentence

An **optional** is a type that says "there may be a value here, or there may be nothing", and Swift won't let you use it until you've decided what to do about the nothing.

## The problem: values that might not exist

You've already run into this several times:

- `Int("forty-two")` has no number to give back.
- The second largest value in `[7, 7, 7]` doesn't exist (Module 2).
- A function that finds the first vowel in `"rhythm"` has no position to return (Module 6).
- Looking up `"Zoe"` in a dictionary of ages finds no entry (Module 7).

In Module 6 you handled the missing case with a **sentinel**, like `-1` for "not found", or a **flag** in a tuple, like `(isValid: false, age: 0)`. Both work, and both share the same flaw: nothing forces the caller to check. The compiler sees an `Int`, so it lets the caller add `-1` to a total or use it as a position.

Many older languages have a bigger version of the same flaw. In Java or C#, for example, almost any variable that refers to an object can also hold `null`, meaning "refers to nothing". The type doesn't say whether `null` is possible, so every use is a bet, and when the bet fails the program crashes. Tony Hoare, who by his own account introduced the null reference in the language ALGOL W in 1965, is commonly quoted calling them his "billion-dollar mistake" in a 2009 talk, a guess at what the resulting bugs have cost.

Swift's answer is to put the "might be missing" into the **type**. A plain `Int` always holds a number. An `Int?` might not. The compiler knows the difference and checks it for you.

## Optional and nil

**Plain definition:** `Int?` is a box that either holds an `Int` or is empty. Empty is written `nil`.

**Precise definition:** `Int?` is shorthand for the standard library type `Optional<Int>`. `Optional` works with any type: `String?`, `Double?`, `[Int]?`. The type inside is called the **wrapped type**. An optional either holds a value of its wrapped type or is `nil`.

```swift
let a: Int? = 42
let b: Optional<Int> = 42
let c: Int? = nil

print(a == b)
print(c == nil)
print(a == 42)

var nickname: String?
print(nickname == nil)
nickname = "Chris"
print(nickname == nil)
```

```output
true
true
true
true
false
```

Line by line:

1. `a` is an `Int?` holding 42. You can put a plain `Int` into an optional without doing anything: Swift wraps it for you.
2. `b` uses the long form, `Optional<Int>`. It's the same type as `Int?`. You'll almost always write the short form.
3. `c` is an `Int?` holding nothing.
4. `==` works between optionals: two optionals are equal if both are `nil` or both hold equal values. So `a == b` is `true`.
5. `c == nil` asks "is `c` empty?". It is.
6. `a == 42` compares an optional with a plain value. Swift wraps the 42 and compares. `true`.
7. `var nickname: String?` declares an optional variable without a value. Optional variables are the one case where Swift fills in a starting value for you: `nil`.
8. After `nickname = "Chris"`, it holds a value, so `nickname == nil` is `false`.

`nil` isn't zero, an empty string or `false`. It means "no value at all". An optional `String` that holds `""` holds a value, the empty string, so it's not `nil`. That difference is the whole point: with `Int?`, 0 can be a real answer and `nil` still means "none".

## Who returns optionals, and why

You don't create most of the optionals you'll handle. The standard library hands them to you whenever an operation can legitimately have no answer:

```swift warning expression implicitly coerced from 'Int?' to 'Any'
let scores = [3, 8, 5]
let noScores: [Int] = []
let ages = ["Ana": 34, "Leo": 29]

print(Int("42"))
print(Int("forty-two"))
print(scores.first)
print(noScores.first)
print(scores.min())
print(ages["Ana"])
print(ages["Zoe"])
print(scores.firstIndex(of: 9))
```

```output
Optional(42)
nil
Optional(3)
nil
Optional(3)
Optional(34)
nil
nil
```

| Call | Returns | Why it can be `nil` |
| --- | --- | --- |
| `Int("42")` | `Int?` | The text might not be a whole number. A failable conversion. |
| `scores.first`, `scores.min()` | `Int?` | The array might be empty. |
| `ages["Ana"]` | `Int?` | The key might not be in the dictionary. |
| `scores.firstIndex(of: 9)` | `Int?` | The value might not be in the array. |

Compare that with `3 + 4` or `scores.count`: those always have an answer, so they return a plain `Int`. An optional return type is the function telling you, in its signature, that "no answer" is one of its normal outcomes.

## Printing an optional

When you print an optional directly, you see `Optional(42)` or `nil`, and the compiler warns. Swift 6.3 says:

```plaintext
warning: expression implicitly coerced from 'Int?' to 'Any'
note: provide a default value to avoid this warning
note: force-unwrap the value to avoid this warning
note: explicitly cast to 'Any' with 'as Any' to silence this warning
```

`print` accepts values of any type (`Any`), and the compiler suspects you meant to print the number, not the box. `Optional(42)` is a debug description: fine while you explore, never something a user should see. You met the same thing in string interpolation in Module 4.

The notes list three ways out. A default value with `??` you already know. Force-unwrapping is lesson 5 of this module, and mostly a bad idea. `as Any` only silences the warning: it says "yes, I really want to print the box". This lesson uses `as Any` in a few places for exactly that reason, to show you what an optional holds. In real code, you unwrap first.

## You can't use an Int? as an Int

This is the rule that makes optionals safe:

```swift no-compile value of optional type 'Int?' must be unwrapped to a value of type 'Int'
func double(_ number: Int) -> Int {
    return number * 2
}

let quantity = Int("4")
print(double(quantity))
```

Swift 6.3 says:

```plaintext
error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
note: coalesce using '??' to provide a default when the optional value contains 'nil'
note: force-unwrap using '!' to abort execution if the optional value contains 'nil'
```

`double` needs a number. `quantity` might not be one. The compiler won't guess, so the program doesn't build. You get the same error for `quantity * 2` or `let n: Int = quantity`. The other direction is fine: you can pass a plain `Int` anywhere an `Int?` is expected, because a value is always a valid "maybe a value".

Read the second note carefully: force-unwrapping means "abort execution if the optional value contains nil". That's a crash, and the compiler says so in its own words.

The fix you know from Module 4 is a default:

```swift
func double(_ number: Int) -> Int {
    return number * 2
}

let quantity = Int("4") ?? 0
print(double(quantity))
```

```output
8
```

A default works when there's a sensible one. Often there isn't: if the quantity text is garbage, you want to tell the user, not quietly order zero items. The next lesson gives you `if let` and `guard let`, which let you run one piece of code when there's a value and another when there isn't.

## A practical example: a price lookup

A café's menu lives in a dictionary. Looking up an item gives back an `Int?`, because the item might not be on the menu:

```swift
let menu = ["coffee": 45, "bread": 28, "juice": 50]
let order = ["coffee", "tea", "bread"]

var total = 0
var unknownItems = 0
for item in order {
    let price = menu[item]
    if price == nil {
        print("\(item): not on the menu")
        unknownItems += 1
    } else {
        total += price ?? 0
    }
}
print("Total: \(total), unknown items: \(unknownItems)")
```

```output
tea: not on the menu
Total: 73, unknown items: 1
```

`menu[item]` is an `Int?`. The code checks it against `nil` first, which is honest, but then needs `price ?? 0` anyway, because the compiler doesn't connect the `else` branch to the earlier check. That clumsy double step is exactly what `if let` fixes in the next lesson.

## Common mistakes

> [!error] error: 'nil' cannot initialize specified type 'Int'
> Only optional types can be `nil`. If the value can be missing, declare it as `Int?`. If it can't, give it a real value. Swift 6.3:

```swift no-compile 'nil' cannot initialize specified type 'Int'
var bestScore: Int = nil
```

> [!error] error: 'nil' requires a contextual type
> `let x = nil` gives Swift nothing to infer from: nil of which type? Annotate it, `let x: Int? = nil`.

```swift no-compile 'nil' requires a contextual type
let selectedItem = nil
```

> [!error] error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
> You used an optional where a plain value is needed. Decide what happens when it's `nil`: a default with `??` for now, `if let` or `guard let` from the next lesson.

> [!error] Showing Optional(…) to a user
> `print(Int("42"))` and `"\(Int("42"))"` show `Optional(42)`. The compiler warns about both. Unwrap or give a default before you show a value.

> [!error] Treating nil as zero
> `nil` means "no value", not 0. A score of 0 and a missing score are different things, and keeping them apart is the reason to use `Int?` at all.

````exercise
id: m08-l01-e1
type: comprehension
prompt: "Which of these expressions has type `Int` (not `Int?`)?"
choices:
  - text: "`Int(\"12\")`"
    correct: false
    why: "Converting text to a number can fail, so it returns Int? even when the text is a valid number."
  - text: "`[4, 9].first`"
    correct: false
    why: An array can be empty, so first returns an optional even when this one isn't empty.
  - text: "`[4, 9].count`"
    correct: true
    why: Every array has a count, even an empty one (0). There's no case without an answer.
  - text: "`[\"a\": 1][\"a\"]`"
    correct: false
    why: A dictionary lookup returns an optional because the key might not be there.
solution: |
  **`[4, 9].count`**. The type depends on whether the operation **can** have no answer, not on whether it has one this time. `Int("12")` succeeds here, but `Int` of other text can fail, so the return type is `Int?` every time. The same goes for `first` and dictionary lookups. A count always exists, so it's a plain `Int`.
````

````exercise
id: m08-l01-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let empty: String? = ""
  let missing: String? = nil
  print(empty == nil)
  print(missing == nil)

  var level: Int?
  print(level == nil)
  level = 0
  print(level == nil)
  print(level == 0)

  let ages = ["Ana": 34]
  print(ages["Ana"] == 34)
  print(ages["Leo"] ?? -1)
output: |
  false
  true
  true
  false
  true
  true
  -1
hints:
  - The empty string is a value.
  - An optional variable with no initial value starts as nil.
  - 0 is a value too.
solution: |
  ```output
  false
  true
  true
  false
  true
  true
  -1
  ```

  1. `empty` holds a value, the empty string, so it isn't `nil`.
  2. `missing` holds nothing.
  3. `var level: Int?` starts as `nil`.
  4. After `level = 0` it holds 0, which is a value, so it's no longer `nil`.
  5. `level == 0` compares the optional with a plain 0: equal.
  6. `ages["Ana"]` is `Optional(34)`, which equals 34.
  7. `"Leo"` isn't in the dictionary, so the lookup is `nil` and `??` gives the default.
````

````exercise
id: m08-l01-e3
type: fill-in
prompt: |
  Complete the declarations so the program compiles and prints `true true`. `middleName` can be missing; `retries` always has a value.
code: |
  var middleName: [[1]] = nil
  var retries: [[2]] = 3
  print(middleName == nil, retries == 3)
blanks:
  - id: "1"
    answers: ["String?", "Optional<String>"]
  - id: "2"
    answers: ["Int"]
solution: |
  ```swift
  var middleName: String? = nil
  var retries: Int = 3
  print(middleName == nil, retries == 3)
  ```

  ```output
  true true
  ```

  A middle name can be missing, so it's a `String?`, and only an optional can hold `nil`. `retries` always has a value, so it's a plain `Int`. Making it `Int?` would compile, but it would force every use of it to deal with a `nil` that can never happen. Use an optional only when "no value" is a real possibility.
````

````exercise
id: m08-l01-e4
type: find-errors
prompt: This program doesn't compile. Pick out the real problems, then fix it so it prints the price of three coffees.
code: |
  let menu = ["coffee": 45, "bread": 28]
  let coffeePrice: Int = menu["coffee"]
  let discount = nil
  print(coffeePrice * 3)
choices:
  - text: "Line 2: a dictionary lookup returns `Int?`, which can't be stored in an `Int`."
    correct: true
    why: The key might not exist, so the lookup is optional.
  - text: "Line 3: `nil` needs a type; Swift can't infer one from it."
    correct: true
    why: "The error is 'nil' requires a contextual type."
  - text: "Line 1: dictionaries can't hold Int values."
    correct: false
    why: "[String: Int] is a perfectly normal dictionary."
  - text: "Line 4: `print` can't print the result of a multiplication."
    correct: false
    why: print takes any expression. Once coffeePrice is an Int, this line is fine.
rubric:
  - I handled the optional on line 2, for example with ?? and a default.
  - I gave discount an optional type, or removed it since it isn't used.
  - My version prints 135.
solution: |
  ```swift
  let menu = ["coffee": 45, "bread": 28]
  let coffeePrice: Int = menu["coffee"] ?? 0
  let discount: Int? = nil
  print(coffeePrice * 3)
  print(discount == nil)
  ```

  ```output
  135
  true
  ```

  `menu["coffee"]` is an `Int?` even though the key is right there: the type is decided by what a lookup **can** return. `?? 0` turns it into an `Int`. `nil` alone has no type, so `discount` needs an annotation. (A price of 0 for a missing item is a questionable default; the next lesson shows how to treat that case on its own.)
````

````exercise
id: m08-l01-e5
type: solve
prompt: |
  You receive quantities as text. Write a program that walks this array, prints which entries aren't numbers, and prints the sum of the ones that are:

  ```swift
  let rawQuantities = ["3", "two", "5", "", "4"]
  ```

  Expected output:

  ```output
  "two" isn't a number
  "" isn't a number
  Valid total: 12
  ```

  Use only what this lesson and Module 4 covered: comparing with `nil` and `??`.
starter: |
  let rawQuantities = ["3", "two", "5", "", "4"]
hints:
  - "Int(raw) == nil tells you the conversion failed."
  - "To print quotes inside a string, escape them: \\\"."
  - In the valid case you still need ?? to get an Int out.
rubric:
  - The output matches exactly.
  - I didn't use -1 or 0 as a sentinel to decide whether the text was valid.
  - I converted each piece of text with Int(…).
solution: |
  ```swift
  let rawQuantities = ["3", "two", "5", "", "4"]

  var total = 0
  for raw in rawQuantities {
      let quantity = Int(raw)
      if quantity == nil {
          print("\"\(raw)\" isn't a number")
      } else {
          total += quantity ?? 0
      }
  }
  print("Valid total: \(total)")
  ```

  ```output
  "two" isn't a number
  "" isn't a number
  Valid total: 12
  ```

  The decision uses `quantity == nil`, not a made-up value, so a real quantity of 0 would still count as valid. The `?? 0` in the `else` branch never actually uses its default, since you already know the value is there, but the compiler doesn't, so it's needed. `if let` in the next lesson removes that redundancy.
````

````exercise
id: m08-l01-e6
type: explain
prompt: |
  In Module 6 you wrote `positionOfFirstVowel(in:) -> Int`, returning -1 when there's no vowel. Imagine it returned `Int?` instead, with `nil` for "no vowel". Explain what changes for a caller who writes `let position = positionOfFirstVowel(in: word)` and then `position + 1`.
code: |
  // Module 6 version: -1 means "no vowel"
  func positionOfFirstVowel(in word: String) -> Int
  // Proposed version: nil means "no vowel"
  func positionOfFirstVowel(in word: String) -> Int?

  let position = positionOfFirstVowel(in: word)
  print(position + 1)
rubric:
  - I said that with -1 the code compiles and quietly computes 0 when there's no vowel.
  - I said that with Int? the code doesn't compile until the nil case is handled.
  - I connected that to the "must be unwrapped" error.
  - I explained why the second behavior is safer.
solution: |
  With `-> Int`, `position + 1` compiles and runs. When the word has no vowel, it computes `-1 + 1 = 0`, a valid-looking position that's wrong. The bug shows up later, somewhere else, if at all.

  With `-> Int?`, `position + 1` doesn't compile: "value of optional type 'Int?' must be unwrapped to a value of type 'Int'". The caller is forced, at the moment of writing the code, to decide what happens when there's no vowel. The "no answer" case moved from a convention in a comment to the type itself, where the compiler can check it.
````

## Summary

- An optional holds a value or nothing. `Int?` is shorthand for `Optional<Int>`; `nil` is the "nothing".
- Only optional types can be `nil`. An optional `var` without a value starts as `nil`.
- `nil` isn't 0, `""` or `false`. It's the absence of a value.
- Failable conversions (`Int("…")`), `first`, `min()`, `firstIndex(of:)` and dictionary lookups return optionals because "no answer" is one of their normal outcomes.
- Printing an optional shows `Optional(…)` and triggers a warning. Unwrap before showing a value to anyone.
- You can't use an `Int?` where an `Int` is required. That compile error is the feature: it makes you handle the missing case.
