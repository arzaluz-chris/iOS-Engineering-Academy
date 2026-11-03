---
id: m08-l04
title: "switch on optionals and nested optionals"
description: You learn that Optional is an enum with two cases, match it in a switch with .some, .none and the let x? pattern, make sense of Int?? when an array of optionals hands you one, and revisit compactMap and meet Optional.map.
module: m08
order: 4
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m08-l03]
objectives:
  - Explain that Optional is an enum with the cases none and some, and that nil is another way to write none.
  - Switch on an optional with case .some(let x) and case .none, and with the shorter case let x? and case nil.
  - Combine optional patterns with where clauses and ranges.
  - Recognize where Int?? comes from and tell its two kinds of nil apart.
  - Use compactMap to drop nils from a collection and Optional.map to transform a value only if it exists.
terms:
  - term: Enum
    definition: "A type whose value is exactly one of a fixed list of cases. Optional is one: every optional is either none or some(value). You'll write your own enums in Module 9."
  - term: Associated value
    definition: "A value carried by an enum case. Optional's some case carries the wrapped value."
  - term: Optional pattern
    definition: "The pattern let x? in a case. It matches when the optional holds a value and binds that value to x. It's shorthand for .some(let x)."
  - term: Nested optional
    definition: "An optional whose wrapped type is itself optional, like Int??. It can be nil on the outside, or hold an inner optional that's nil, or hold a value."
  - term: Optional.map
    definition: "A method on an optional that applies a closure to the value inside, if there is one, and wraps the result. On nil it returns nil without calling the closure."
mastery:
  - Write a switch over an Int? with a where clause, a range pattern and a nil case, and fix "switch must be exhaustive".
  - Say what [Int?].first returns for an empty array, for an array whose first element is nil, and for one whose first element is 4.
  - Explain why print shows Optional(nil) for one of those cases.
  - Turn an array of text into an array of valid numbers with compactMap.
  - Rewrite a short if let that transforms a value as Optional.map, and say when not to.
resources: [swift-optional-map, swift-book-basics, swift-book-control-flow, swift-book-collection-types, swift-book-closures]
cards:
  - id: m08-l04-c1
    front: What are Optional's two cases?
    back: "none, which is what nil means, and some(Wrapped), which carries the value. Int? is either .none or .some(an Int)."
  - id: m08-l04-c2
    front: "What does `case let n?:` match in a switch over an Int?"
    back: "Any non-nil value, binding the unwrapped Int to n. It's shorthand for case .some(let n)."
  - id: m08-l04-c3
    front: "`let list: [Int?] = [nil, 4]`. What are `list.first` and `[Int?]().first`?"
    back: "list.first is .some(nil): there is a first element, and it's nil. [Int?]().first is nil on the outside: there's no first element at all. Both are Int??."
  - id: m08-l04-c4
    front: "What's the difference between `texts.map { Int($0) }` and `texts.compactMap { Int($0) }`?"
    back: "map keeps every result, so you get [Int?] with nils in it. compactMap drops the nils and unwraps the rest, so you get [Int]."
---

## The idea in one sentence

An optional is an enum with two cases, "nothing" and "something", so you can `switch` over it like any other value, and when the something is itself optional, you get a nested optional with two different kinds of nothing.

## Optional is an enum

An **enum** is a type whose value is always one of a fixed list of cases. You'll write your own in Module 9. `Optional` is one of them, and the standard library declares it roughly like this (simplified):

```swift illustrative
enum Optional<Wrapped> {
    case none
    case some(Wrapped)
}
```

- `none` is the empty case. `nil` is just a nicer way to write it.
- `some(Wrapped)` is the case with a value. The value travels inside the case: that's called an **associated value**.

So `Int?` is either `.none` or `.some(42)`. You can write those forms directly, although you rarely will:

```swift
let found: Int? = .some(42)
let missing: Int? = .none

print(found == 42)
print(missing == nil)
```

```output
true
true
```

`Optional.some(42)` and the plain `42` you usually write produce the same value. Everything in the last two lessons, `if let`, `??`, `?.`, is a convenient way of asking "which case is this, and if it's `some`, what's inside?".

## switch on an optional

Because an optional is an enum, a `switch` can match its cases:

```swift
let input = "17"

switch Int(input) {
case .some(let number):
    print("Got \(number)")
case .none:
    print("Not a number")
}
```

```output
Got 17
```

`case .some(let number)` matches the `some` case and binds its associated value to `number`, a plain `Int`. `case .none` matches `nil`. Swift knows those are the only two cases, so the switch is exhaustive without a `default`.

Swift has shorter spellings for both, and they're what you'll see in real code:

| Long form | Short form |
| --- | --- |
| `case .some(let number):` | `case let number?:` |
| `case .none:` | `case nil:` |

The `?` after `let number` is the **optional pattern**: "matches a non-`nil` value, and binds what's inside".

### When switch beats if let

For a single "is there a value?" question, `if let` is shorter. `switch` earns its place when you need to sort the value into several buckets **and** handle `nil`, in one statement. The `where` clauses and ranges from Module 5 work with the optional pattern:

```swift
func ageGroup(_ text: String) -> String {
    switch Int(text) {
    case nil:
        return "not a number"
    case let age? where age < 0:
        return "invalid"
    case (0...12)?:
        return "child"
    case (13...19)?:
        return "teen"
    case let age?:
        return "adult, \(age)"
    }
}

for text in ["8", "15", "42", "-3", "old"] {
    print(text, "->", ageGroup(text))
}
```

```output
8 -> child
15 -> teen
42 -> adult, 42
-3 -> invalid
old -> not a number
```

1. `case nil` handles the failed conversion.
2. `case let age? where age < 0` matches a value, binds it, and then checks the `where` condition.
3. `case (0...12)?` matches a value that falls in the range. The `?` after the parentheses applies the optional pattern to the range pattern.
4. `case let age?` catches every remaining value, so together with `case nil` the switch is exhaustive.

Cases are tried from top to bottom, as in any switch. If you leave out `case nil`, Swift 6.3 reports:

```swift no-compile switch must be exhaustive
let score = Int("90")
switch score {
case let value?:
    print(value)
}
```

The note that comes with it suggests adding `case .none:`. Add it, or `case nil:`.

## Nested optionals: Int??

An optional can wrap any type, including another optional. You rarely create an `Int??` on purpose, but collections hand them to you. Take an array of readings where some sensors failed:

```swift
let readings: [Int?] = [nil, 21, 19]
let backwards: [Int?] = [21, nil]
let noReadings: [Int?] = []

print(readings.first as Any)
print(backwards.first as Any)
print(noReadings.first as Any)
```

```output
Optional(nil)
Optional(Optional(21))
nil
```

The element type is `Int?`, and `first` wraps the element in one more optional, in case the array is empty. So `first` is an `Int??`, and there are **two different kinds of nothing**:

- `noReadings.first` is `nil` on the **outside**: there's no first element.
- `readings.first` is `Optional(nil)`, which is `.some(nil)`: there **is** a first element, and that element is `nil` (a failed sensor).
- `backwards.first` is `.some(.some(21))`: a first element that holds 21.

(`as Any` silences the warning, as in lesson 1. Here you really do want to see the box.)

Those two `nil`s mean different things, and a switch can tell them apart:

```swift
func describeFirst(_ readings: [Int?]) -> String {
    switch readings.first {
    case nil:
        return "no readings at all"
    case .some(nil):
        return "first sensor failed"
    case let value??:
        return "first reading \(value)"
    }
}

print(describeFirst([nil, 21, 19]))
print(describeFirst([21, nil]))
print(describeFirst([]))
```

```output
first sensor failed
first reading 21
no readings at all
```

`let value??` peels off both layers. `if let` only peels one: `if let first = readings.first` gives you an `Int?`, the element itself. To get to the number you bind again, which you can do in one condition list:

```swift
let readings: [Int?] = [21, nil]

if let firstElement = readings.first, let value = firstElement {
    print("First reading: \(value)")
}
```

```output
First reading: 21
```

When you hit a nested optional in your own code, ask whether both layers mean something. Often they don't, and the fix is upstream: clean the data so it's `[Int]` before you search it. That's what `compactMap` is for.

## compactMap, revisited

In Module 7 you used `compactMap` to transform a collection and drop the `nil` results. Now you can see exactly what it does with optionals:

```swift
let rawValues = ["4", "x", "7", ""]

let maybeNumbers = rawValues.map { text in Int(text) }
let numbers = rawValues.compactMap { text in Int(text) }
print(maybeNumbers)
print(numbers)

let readings: [Int?] = [nil, 21, 19, nil]
let working = readings.compactMap { reading in reading }
print(working)
print(working.first ?? 0)
```

```output
[Optional(4), nil, Optional(7), nil]
[4, 7]
[21, 19]
21
```

- `map` keeps one result per element, so `Int(text)` gives an `[Int?]`, `nil`s included.
- `compactMap` drops the `nil` results and unwraps the rest: `[Int]`.
- `compactMap { reading in reading }` returns each element unchanged, so it just removes the `nil`s from an `[Int?]`. After that, `first` is an ordinary `Int?` again, not an `Int??`.

(Printing an array of optionals doesn't warn, because the array itself isn't optional. It still shows the `Optional(…)` debug form, which is a hint you probably want `compactMap`.)

## Optional.map

Arrays have `map`; so do optionals. `optional.map { … }` runs the closure on the value inside, if there is one, and wraps the result. On `nil` it returns `nil` without calling the closure:

```swift
let quantity = Int("3")
let missingQuantity = Int("three")

let doubled = quantity.map { value in value * 2 }
let doubledMissing = missingQuantity.map { value in value * 2 }

print(doubled ?? 0)
print(doubledMissing ?? 0)
```

```output
6
0
```

It's a compact version of:

```swift
let quantity = Int("3")

var doubled: Int? = nil
if let quantity {
    doubled = quantity * 2
}
print(doubled ?? 0)
```

```output
6
```

Think of an optional as a collection of zero or one elements: `map` transforms the element if it's there. If your closure itself returns an optional, `map` gives you a nested optional; `flatMap` is the version that flattens it:

```swift
let text: String? = "12"

let nested = text.map { value in Int(value) }
let flat = text.flatMap { value in Int(value) }

print(nested as Any)
print(flat as Any)
```

```output
Optional(Optional(12))
Optional(12)
```

Use `Optional.map` for short, obvious transformations. If the closure is more than a line, or a teammate would have to stop and think, `if let` or `guard let` reads better.

## Common mistakes

> [!error] error: switch must be exhaustive
> A switch over an optional needs a `case nil` (or `.none`) as well as cases for the values. Don't reach for `default`: an explicit `case nil` says what you're handling.

> [!error] Forgetting the ? in the pattern
> `case let age where age < 13` binds the **optional** itself, an `Int?`, and the comparison fails with "value of optional type 'Int?' must be unwrapped". Write `case let age? where age < 13`.

> [!error] Unwrapping only one layer of an Int??
> `if let first = readings.first` gives you an `Int?`, not an `Int`. Bind again (`let value = first`), use `let value??` in a switch, or `compactMap` the array first.

> [!error] Using map where you meant compactMap
> `texts.map { text in Int(text) }` is an `[Int?]`. If you wanted only the valid numbers, that's `compactMap`.

````exercise
id: m08-l04-e1
type: comprehension
prompt: "`let values: [Int?] = [nil, 5]`. Which statement about `values.first` is true?"
choices:
  - text: "It's `nil`, because the first element is nil."
    correct: false
    why: "That's the inner value. The outer optional holds something: there is a first element."
  - text: "It's `.some(nil)`: there is a first element, and it's nil."
    correct: true
    why: first wraps the element (an Int?) in one more optional, and the array isn't empty.
  - text: "It's `5`, because first skips nil elements."
    correct: false
    why: first returns the element at the front, whatever it is. compactMap is what removes nils.
  - text: "It doesn't compile: arrays can't hold nil."
    correct: false
    why: "An array whose element type is Int? can hold nil elements."
solution: |
  **`.some(nil)`**. The type of `values.first` is `Int??`. The array has a first element, so the outer layer is `.some`. That element is `nil`, so the inner layer is `.none`. `print(values.first as Any)` shows it as `Optional(nil)`. Only an empty array gives an outer `nil`.
````

````exercise
id: m08-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  func label(_ value: Int?) -> String {
      switch value {
      case nil:
          return "none"
      case 0?:
          return "zero"
      case let n? where n % 2 == 0:
          return "even \(n)"
      case let n?:
          return "odd \(n)"
      }
  }

  let raw = ["4", "0", "x", "7"]
  for text in raw {
      print(label(Int(text)))
  }
  let valid = raw.compactMap { text in Int(text) }
  print(valid.count)
output: |
  even 4
  zero
  none
  odd 7
  3
hints:
  - "case 0? matches an optional holding exactly 0."
  - Cases are tried top to bottom.
  - compactMap drops the failed conversion.
solution: |
  ```output
  even 4
  zero
  none
  odd 7
  3
  ```

  1. `Int("4")` is 4: not `nil`, not 0, and even.
  2. `Int("0")` is 0, which matches `case 0?` before the even case gets a chance (0 is even too, so order matters).
  3. `Int("x")` is `nil`.
  4. 7 falls through to the last case.
  5. `compactMap` keeps the three values that convert, `[4, 0, 7]`, and drops the `nil` from `"x"`. A valid 0 is kept: `compactMap` removes `nil`, not zeros.
````

````exercise
id: m08-l04-e3
type: fill-in
prompt: |
  Complete the switch so it prints `big`, `small` and `missing` for the three values.
code: |
  for value in [Int("500"), Int("3"), Int("?")] {
      switch value {
      case let n[[1]] where n >= 100:
          print("big")
      case [[2]]:
          print("small")
      case [[3]]:
          print("missing")
      }
  }
blanks:
  - id: "1"
    answers: ["?"]
  - id: "2"
    answers: ["let n?", ".some", ".some(let n)", "let _?", ".some(_)"]
  - id: "3"
    answers: ["nil", ".none"]
solution: |
  ```swift
  for value in [Int("500"), Int("3"), Int("?")] {
      switch value {
      case let n? where n >= 100:
          print("big")
      case .some:
          print("small")
      case nil:
          print("missing")
      }
  }
  ```

  ```output
  big
  small
  missing
  ```

  `let n?` binds the value so the `where` clause can test it. The second case only needs to know there **is** a value; `.some` without a binding does that (`let n?` also works, though Swift will warn that `n` is unused). `nil` handles the failed conversion and makes the switch exhaustive.
````

````exercise
id: m08-l04-e4
type: solve
prompt: |
  A form sends optional answers to a survey as an array of `String?`, where `nil` means the person skipped the question. Write a program that, for this array:

  ```swift
  let answers: [String?] = ["yes", nil, "no", "yes", nil]
  ```

  prints how many questions were skipped, how many were answered, and what the first answer was. A `switch` on the first element of `answers` must handle "no questions", "first question skipped" and "first answer is X". Expected output:

  ```output
  Skipped: 2, answered: 3
  First answer: yes
  ```
starter: |
  let answers: [String?] = ["yes", nil, "no", "yes", nil]
hints:
  - "compactMap { answer in answer } keeps only the answered questions."
  - "answers.count minus the answered count is the skipped count."
  - "answers.first is a String??: case nil, case .some(nil), case let text??."
rubric:
  - The answered count comes from compactMap, not from a manual nil check.
  - The switch has three cases, one for each kind of first element.
  - The output matches exactly.
solution: |
  ```swift
  let answers: [String?] = ["yes", nil, "no", "yes", nil]

  let answered = answers.compactMap { answer in answer }
  let skipped = answers.count - answered.count
  print("Skipped: \(skipped), answered: \(answered.count)")

  switch answers.first {
  case nil:
      print("No questions")
  case .some(nil):
      print("First question skipped")
  case let text??:
      print("First answer: \(text)")
  }
  ```

  ```output
  Skipped: 2, answered: 3
  First answer: yes
  ```

  `compactMap` turns the `[String?]` into a `[String]` of real answers, and the difference in counts is the number of `nil`s. `answers.first` is a `String??`, and the three cases cover its three shapes: no element, a `nil` element, an element with text.
````

````exercise
id: m08-l04-e5
type: refactor
prompt: |
  Rewrite this function with `Optional.map` and `??` so its body is a single line. The output must stay the same.
code: |
  func priceLabel(_ cents: Int?) -> String {
      if let cents {
          return "$\(cents / 100).\(cents % 100)"
      } else {
          return "Price unavailable"
      }
  }
  print(priceLabel(1250))
  print(priceLabel(nil))
rubric:
  - The body is one expression with .map and ??.
  - The output is the same.
  - I can say when the if let version would be the better choice.
solution: |
  ```swift
  func priceLabel(_ cents: Int?) -> String {
      return cents.map { value in "$\(value / 100).\(value % 100)" } ?? "Price unavailable"
  }
  print(priceLabel(1250))
  print(priceLabel(nil))
  ```

  ```output
  $12.50
  Price unavailable
  ```

  `cents.map { … }` builds the label only when there's a value, giving a `String?`, and `??` supplies the text for `nil`. For a transformation this short it reads well. Notice the formatting bug both versions share: 1205 cents would print `$12.5`, not `$12.05`. Once the closure has to fix that, it grows past one line, and the `if let` version becomes the easier one to read.
````

````exercise
id: m08-l04-e6
type: explain
prompt: |
  A dictionary of user settings has type `[String: Int?]`, where `nil` means "the user cleared this setting". Explain what `settings["volume"]` returns, why its type is `Int??`, and what the two kinds of `nil` mean here.
code: |
  let settings: [String: Int?] = ["volume": 7, "brightness": nil]
  let volume = settings["volume"]
rubric:
  - I said a dictionary lookup wraps the value type in an optional, so Int? becomes Int??.
  - I said an outer nil means the key isn't in the dictionary.
  - I said .some(nil) means the key is there and its value was cleared.
  - I suggested a way to handle all three cases, such as a switch.
solution: |
  A lookup returns the value type wrapped in an optional, because the key might be missing. The value type is already `Int?`, so the lookup is an `Int??`.

  - Outer `nil`: there's no `"volume"` key at all. The user never set it.
  - `.some(nil)`: the key exists, and its value is `nil`. The user set it and then cleared it.
  - `.some(.some(7))`: the volume is 7.

  A `switch settings["volume"]` with `case nil`, `case .some(nil)` and `case let level??` handles the three cases. If the app doesn't need to distinguish "never set" from "cleared", that's a sign the dictionary should just be `[String: Int]`, with a removed key meaning "no value", and a single `if let`.
````

## Summary

- `Optional` is an enum with two cases: `.none` (written `nil`) and `.some(value)`.
- `switch` over an optional with `case let x?` and `case nil`, the short forms of `.some(let x)` and `.none`. A `where` clause or a range like `(0...12)?` refines a case.
- A switch over an optional must cover `nil` to be exhaustive.
- `[Int?].first` is an `Int??`: outer `nil` means no element, `.some(nil)` means a `nil` element. `let x??` unwraps both layers.
- `compactMap` drops `nil`s and unwraps the rest, which often removes the nested optional before it appears.
- `optional.map { … }` transforms the value if there is one. `flatMap` does the same when the closure returns an optional.
