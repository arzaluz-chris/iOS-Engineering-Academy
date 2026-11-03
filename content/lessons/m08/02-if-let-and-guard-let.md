---
id: m08-l02
title: "Unwrapping with if let and guard let"
description: You get the value out of an optional safely with if let and guard let, use the shorthand if let name, bind several optionals and check conditions in one statement, and learn exactly where each unwrapped name is visible.
module: m08
order: 2
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m08-l01]
objectives:
  - Unwrap an optional with if let, with an else branch for the nil case.
  - Use the shorthand if let name and guard let name.
  - Bind several optionals and add Boolean conditions in one if or guard, separated by commas.
  - Validate input with guard let at the top of a function and inside a loop.
  - Say where an unwrapped name is visible after if let and after guard let.
terms:
  - term: Optional binding
    definition: "Checking whether an optional holds a value and, if it does, putting that value in a new constant of the non-optional type. if let and guard let are optional binding."
  - term: if let
    definition: "Runs its block only when the optional holds a value, with the unwrapped value available inside the block. The else branch handles nil."
  - term: guard let
    definition: "Unwraps an optional or leaves the current scope. After the guard, the unwrapped constant is available until the end of the enclosing scope."
  - term: Shorthand optional binding
    definition: "if let name { … }, which unwraps an optional and gives the unwrapped value the same name. Added in Swift 5.7."
  - term: Condition list
    definition: "Several bindings and Boolean conditions in one if, guard or while, separated by commas. All must succeed, and they're checked left to right."
mastery:
  - Rewrite a "compare with nil, then use ?? anyway" block as if let.
  - Write an if with two bindings and a range check, and say which parts run when the second binding fails.
  - Validate a text parameter with guard let at the top of a function and use the unwrapped value below.
  - Predict whether a name created by if let or guard let is visible on a given line.
  - Fix "initializer for conditional binding must have Optional type".
resources: [swift-book-basics, swift-book-control-flow, swift-book-functions]
cards:
  - id: m08-l02-c1
    front: "What does `if let number = Int(text) { … } else { … }` do?"
    back: "If Int(text) holds a value, it puts that Int in number and runs the first block. If it's nil, it runs the else block, where number doesn't exist."
  - id: m08-l02-c2
    front: "What is `if let age { … }` short for?"
    back: "if let age = age { … }. Inside the braces, age is the unwrapped, non-optional value. Swift 5.7 and later."
  - id: m08-l02-c3
    front: Where is a constant created by `guard let` visible?
    back: "From the line after the guard to the end of the enclosing scope (the function, or the loop body). That's the opposite of if let, whose constant only exists inside its braces."
  - id: m08-l02-c4
    front: "In `if let w = Int(a), let h = Int(b), w > 0 { … }`, when does the block run?"
    back: "Only when both conversions succeed and w > 0. The parts are checked left to right and the first failure skips the block."
  - id: m08-l02-c5
    front: "What does \"initializer for conditional binding must have Optional type\" mean?"
    back: "You wrote if let or guard let on a value that isn't optional. There's nothing to unwrap: use the value directly."
---

## The idea in one sentence

`if let` and `guard let` check whether an optional holds a value and, if it does, hand you that value as a plain, non-optional constant.

## if let

In the last lesson you checked `price == nil` and then still needed `price ?? 0` to get an `Int` out. **Optional binding** does both steps at once:

```swift
let input = "42"

if let number = Int(input) {
    print("Doubled: \(number * 2)")
} else {
    print("\"\(input)\" isn't a number")
}

let badInput = "forty-two"
if let number = Int(badInput) {
    print("Doubled: \(number * 2)")
} else {
    print("\"\(badInput)\" isn't a number")
}
```

```output
Doubled: 84
"forty-two" isn't a number
```

Line by line:

1. `Int(input)` produces an `Int?`.
2. `if let number = …` asks: does that optional hold a value? If it does, Swift creates a new constant `number` of type **`Int`**, not `Int?`, holding the value, and runs the block.
3. Inside the block, `number * 2` compiles, because `number` is a plain `Int`. No `??`, no warning, no `Optional(…)`.
4. If the optional is `nil`, no constant is created and the `else` block runs.

Read `if let number = Int(input)` as "if there's a number in `Int(input)`, call it `number` and…". The `else` is optional, like in any `if`; leave it out when there's nothing to do for `nil`.

You can write `if var` when you want to change the unwrapped copy inside the block. It's rare: the copy is separate from the optional, so changing it doesn't change the original.

### The shorthand: if let name

Very often the optional already has a good name, and you want the unwrapped value to have the same name:

```swift
let age = Int("30")

if let age = age {
    print("Next year: \(age + 1)")
}

if let age {
    print("In ten years: \(age + 10)")
}
```

```output
Next year: 31
In ten years: 40
```

`if let age = age` creates a new constant `age` (an `Int`) inside the braces that hides the outer `age` (an `Int?`). Since Swift 5.7 you can drop the repetition: `if let age { … }` means exactly the same thing. Use the shorthand when the names would match; use the long form when the right side is an expression like `Int(input)` or when a different name reads better.

## Several bindings and conditions at once

An `if` can hold a **condition list**: bindings and Boolean conditions separated by commas.

```swift
func describeRectangle(width widthText: String, height heightText: String) {
    if let width = Int(widthText), let height = Int(heightText), width > 0, height > 0 {
        print("\(width) x \(height), area \(width * height)")
    } else {
        print("Can't use \"\(widthText)\" x \"\(heightText)\"")
    }
}

describeRectangle(width: "4", height: "5")
describeRectangle(width: "4", height: "five")
describeRectangle(width: "-4", height: "5")
```

```output
4 x 5, area 20
Can't use "4" x "five"
Can't use "-4" x "5"
```

The block runs only if **every** part succeeds. Swift checks them left to right and stops at the first failure: with `"five"`, the second binding fails and `width > 0` is never evaluated. A condition can use a name bound earlier in the same list, which is why `width > 0` comes after `let width = …`.

The commas work like `&&`, with one difference: `&&` only joins Booleans, while the comma list can mix bindings and Booleans. You can't write `let width = Int(widthText) && width > 0`.

## Scope of an if let constant

The unwrapped constant exists only inside the braces of the `if`. Outside them, there's only the optional, or nothing:

```swift no-compile cannot find 'number' in scope
let input = "7"
if let number = Int(input) {
    print("Got \(number)")
}
print(number + 1)
```

Swift 6.3 says `error: cannot find 'number' in scope`. That's the safety: outside the `if`, nobody has checked that there's a value, so the unwrapped name doesn't exist there. When you need the value for the rest of a function, `if let` pushes all that code inside the braces, and that's the job of `guard let`.

## guard let

You met `guard` in Module 5 (inside loops) and Module 6 (at the top of functions): check a condition, and if it fails, leave. `guard let` does the same with a binding:

```swift
func ticketPrice(ageText: String) -> String {
    guard let age = Int(ageText) else {
        return "\"\(ageText)\" isn't an age"
    }
    guard age >= 0 && age <= 120 else {
        return "\(age) is out of range"
    }

    if age < 12 {
        return "Child: 5"
    }
    return "Adult: 12"
}

print(ticketPrice(ageText: "8"))
print(ticketPrice(ageText: "40"))
print(ticketPrice(ageText: "abc"))
print(ticketPrice(ageText: "200"))
```

```output
Child: 5
Adult: 12
"abc" isn't an age
200 is out of range
```

1. `guard let age = Int(ageText) else { … }`: if the conversion fails, the `else` block runs and must leave the function.
2. If it succeeds, `age` is an `Int` **from here to the end of the function**. That's the big difference from `if let`.
3. The second `guard` uses `age` directly. So does the rest of the function, at the left margin, with no nesting.

`guard let` has the shorthand too: `guard let age else { return … }`.

**Which one?** Use `guard let` when the function can't do its job without the value: validate at the top, then work. Use `if let` when the value is a detail and the code after the `if` makes sense either way.

## guard let inside a loop

In Module 5 you processed raw scores with `Int(raw) ?? -1` and a range check, picking -1 because the range check would reject it. With `guard let` there's no made-up value at all:

```swift
let rawScores = ["90", "abc", "75", "", "101", "60"]

var total = 0
var validCount = 0
var rejected = 0

for raw in rawScores {
    guard let score = Int(raw), score >= 0 && score <= 100 else {
        rejected += 1
        continue
    }
    total += score
    validCount += 1
}

if validCount > 0 {
    print("Average: \(total / validCount) from \(validCount) scores")
}
print("Rejected: \(rejected)")
```

```output
Average: 75 from 3 scores
Rejected: 3
```

Inside a loop, the `else` leaves with `continue` (skip to the next pass). `score` is visible from the line after the guard to the end of **that pass** of the loop body. The condition list works in `guard` exactly as in `if`: the binding and the range check in one statement.

## Common mistakes

> [!error] error: cannot find 'number' in scope
> You used an `if let` constant after the `if` closed. Move the code into the braces, or switch to `guard let` so the name lives until the end of the function.

> [!error] error: initializer for conditional binding must have Optional type, not 'Int'
> You unwrapped something that isn't optional. There's nothing to check: use the value directly. Swift 6.3:

```swift no-compile initializer for conditional binding must have Optional type, not 'Int'
let count = 5
if let count {
    print(count)
}
```

> [!error] error: 'guard' body must not fall through, consider using a 'return' or 'throw' to exit the scope
> The `else` of a `guard let` must leave: `return` in a function, `continue` or `break` in a loop.

```swift no-compile 'guard' body must not fall through
func parse(_ text: String) -> Int {
    guard let number = Int(text) else {
        print("Not a number")
    }
    return number
}
```

> [!error] Checking for nil and then unwrapping anyway
> `if value != nil { use(value ?? 0) }` checks twice and still leaves a made-up default in the code. `if let value { use(value) }` says the same thing once.

> [!error] Nesting if let pyramids
> Three `if let`s inside each other push the real work three levels deep. Put them in one condition list, or use `guard let` for each at the top.

````exercise
id: m08-l02-e1
type: comprehension
prompt: |
  Which line makes this function fail to compile?

  ```swift
  func greet(_ nameText: String?) -> String {
      if let name = nameText {
          print("Found \(name)")          // line A
      }
      guard let saved = nameText else {
          return "Hello, guest"
      }
      print("Saved \(saved)")             // line B
      return "Hello, \(name)"             // line C
  }
  ```
choices:
  - text: Line A
    correct: false
    why: name exists inside the if let braces.
  - text: Line B
    correct: false
    why: saved was bound by guard let, so it's visible until the end of the function.
  - text: Line C
    correct: true
    why: name only existed inside the if let braces. Here it's out of scope.
  - text: None, it compiles.
    correct: false
    why: "Line C refers to a name that doesn't exist at that point: cannot find 'name' in scope."
solution: |
  **Line C.** A constant bound with `if let` only lives inside that `if`'s braces. A constant bound with `guard let` lives from the guard to the end of the enclosing scope. The fix is `return "Hello, \(saved)"`. The `if let` at the top is then pointless and can go.
````

````exercise
id: m08-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  let pairs = [("3", "4"), ("3", "x"), ("0", "4"), ("y", "z")]

  for (a, b) in pairs {
      if let first = Int(a), let second = Int(b), first > 0 {
          print("\(a),\(b): \(first * second)")
      } else if let first = Int(a) {
          print("\(a),\(b): only \(first)")
      } else {
          print("\(a),\(b): nothing")
      }
  }
output: |
  3,4: 12
  3,x: only 3
  0,4: only 0
  y,z: nothing
hints:
  - "for (a, b) in pairs destructures each tuple, like let (a, b) = … in Module 6."
  - "The first if needs all three parts to succeed."
  - "\"0\" converts, but 0 > 0 is false."
solution: |
  ```output
  3,4: 12
  3,x: only 3
  0,4: only 0
  y,z: nothing
  ```

  1. Both convert and 3 > 0, so the first block runs: 3 × 4.
  2. `"x"` fails the second binding. The `else if` only needs `a`, which converts.
  3. Both convert, but `first > 0` fails, so the whole first condition fails. The `else if` binds `first` again (a new constant in a new scope) and prints it.
  4. `"y"` doesn't convert, so both conditions fail.
````

````exercise
id: m08-l02-e3
type: fill-in
prompt: |
  Complete the function so it returns the number of minutes in a duration written as hours, or 0 when the text isn't a whole number of hours. It should print `120 0`.
code: |
  func minutes(fromHours text: String) -> Int {
      [[1]] hours = Int(text) [[2]] {
          return 0
      }
      return hours * 60
  }
  print(minutes(fromHours: "2"), minutes(fromHours: "two"))
blanks:
  - id: "1"
    answers: ["guard let"]
  - id: "2"
    answers: ["else"]
solution: |
  ```swift
  func minutes(fromHours text: String) -> Int {
      guard let hours = Int(text) else {
          return 0
      }
      return hours * 60
  }
  print(minutes(fromHours: "2"), minutes(fromHours: "two"))
  ```

  ```output
  120 0
  ```

  `guard let … else` unwraps or leaves. After it, `hours` is an `Int` until the end of the function, so `hours * 60` compiles. `if let` wouldn't work here as written: `hours` would only exist inside its braces. (Returning 0 for bad input has the sentinel problem from Module 6; lesson 6 of this module fixes that by returning `Int?`.)
````

````exercise
id: m08-l02-e4
type: refactor
prompt: |
  This loop uses the Module 5 technique: a made-up fallback of -1 that the range check then rejects. Rewrite it with `guard let` so no made-up value appears. The output must stay the same.
code: |
  let rawTemperatures = ["21", "hot", "-5", "19", "60"]
  var accepted = 0
  for raw in rawTemperatures {
      let value = Int(raw) ?? -1000
      if value < -50 || value > 50 {
          print("Skipping \(raw)")
          continue
      }
      accepted += 1
  }
  print("Accepted: \(accepted)")
rubric:
  - There's no fallback value like -1000 anywhere.
  - The binding and the range check are in one guard.
  - The else block prints the skip message and leaves with continue.
  - The output is the same as the original.
solution: |
  ```swift
  let rawTemperatures = ["21", "hot", "-5", "19", "60"]
  var accepted = 0
  for raw in rawTemperatures {
      guard let value = Int(raw), value >= -50 && value <= 50 else {
          print("Skipping \(raw)")
          continue
      }
      accepted += 1
  }
  print("Accepted: \(accepted)")
  ```

  ```output
  Skipping hot
  Skipping 60
  Accepted: 3
  ```

  The original only worked because -1000 happened to fall outside the range. If someone later widened the range to "any temperature", `"hot"` would quietly become -1000 degrees. With `guard let`, a failed conversion and an out-of-range value are rejected by the same statement, and there's no fake number to leak.
````

````exercise
id: m08-l02-e5
type: solve
prompt: |
  Write `func splitBill(totalText: String, peopleText: String) -> String` that:

  - returns `"Invalid total"` if `totalText` isn't a whole number or is negative,
  - returns `"Invalid number of people"` if `peopleText` isn't a whole number or is less than 1,
  - otherwise returns `"Each pays X"`, where X is the total divided by the people (integer division).

  Use `guard let`. Then check it:

  ```swift
  print(splitBill(totalText: "300", peopleText: "4"))
  print(splitBill(totalText: "abc", peopleText: "4"))
  print(splitBill(totalText: "300", peopleText: "0"))
  ```

  ```output
  Each pays 75
  Invalid total
  Invalid number of people
  ```
starter: |
  func splitBill(totalText: String, peopleText: String) -> String {
      // your code
  }
hints:
  - "One guard per input: guard let total = Int(totalText), total >= 0 else { … }"
  - After both guards, total and people are plain Ints.
rubric:
  - Each input is validated with guard let and a condition.
  - Each guard returns its own message.
  - The division happens only after both guards, so it can never divide by zero.
  - The output matches exactly.
solution: |
  ```swift
  func splitBill(totalText: String, peopleText: String) -> String {
      guard let total = Int(totalText), total >= 0 else {
          return "Invalid total"
      }
      guard let people = Int(peopleText), people >= 1 else {
          return "Invalid number of people"
      }
      return "Each pays \(total / people)"
  }

  print(splitBill(totalText: "300", peopleText: "4"))
  print(splitBill(totalText: "abc", peopleText: "4"))
  print(splitBill(totalText: "300", peopleText: "0"))
  ```

  ```output
  Each pays 75
  Invalid total
  Invalid number of people
  ```

  Two guards, because each failure has its own message. If both inputs shared one message, a single guard with both bindings would do: `guard let total = Int(totalText), let people = Int(peopleText), total >= 0, people >= 1 else { … }`. Either way, by the last line the compiler and the reader both know `people` is at least 1.
````

````exercise
id: m08-l02-e6
type: find-errors
prompt: "This code is meant to print the length of a nickname if there is one. Pick out the real problems."
code: |
  let nickname: String? = "Chris"
  let letters = 5
  if let nickname {
      print("Nickname has \(letters) letters")
  }
  if let letters {
      print(letters)
  }
  print(nickname.count)
choices:
  - text: "`if let letters` unwraps a value that isn't optional."
    correct: true
    why: "letters is an Int. The error is \"initializer for conditional binding must have Optional type, not 'Int'\"."
  - text: "The last line uses `nickname` outside the `if let`, where it's still a `String?`."
    correct: true
    why: "Outside the braces, nickname is the original optional. .count needs the unwrapped String."
  - text: "`if let nickname` is missing `= nickname`."
    correct: false
    why: The shorthand form is valid since Swift 5.7.
  - text: "The program prints 5 instead of the real length."
    correct: true
    why: It prints the unrelated constant letters, not nickname.count. A logic bug, not a compile error.
rubric:
  - I removed the if let around the non-optional value.
  - I moved the use of nickname.count inside the if let.
  - My version prints the real length.
solution: |
  ```swift
  let nickname: String? = "Chris"
  if let nickname {
      print("Nickname has \(nickname.count) letters")
  }
  ```

  ```output
  Nickname has 5 letters
  ```

  Two compile errors and one logic bug. `if let` only works on optionals. Outside the braces, `nickname` is still a `String?`, and `.count` on it fails with "value of optional type 'String?' must be unwrapped". And printing `letters` was never the length of anything; `nickname.count` inside the `if let` is.
````

## Summary

- `if let x = optional { … } else { … }` runs the first block with `x` unwrapped, or the `else` when the optional is `nil`.
- `if let x { … }` and `guard let x else { … }` are shorthand for binding a value to the same name (Swift 5.7+).
- A condition list mixes bindings and Booleans with commas. Everything must succeed, left to right, and later parts can use earlier names.
- An `if let` constant lives inside the braces. A `guard let` constant lives until the end of the enclosing scope.
- Use `guard let` to validate at the top of a function or a loop pass; use `if let` when the code after it works either way.
- Optional binding replaces made-up fallback values: no more `?? -1` just to reject something later.
