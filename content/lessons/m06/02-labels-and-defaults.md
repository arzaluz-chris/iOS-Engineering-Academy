---
id: m06-l02
title: Argument labels, parameter names and default values
description: You give each parameter a name for the caller and a name for the body, drop labels with _, finally read print(_:separator:terminator:) with full understanding, and let callers skip arguments that have sensible defaults.
module: m06
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l01]
objectives:
  - Tell an argument label from a parameter name and say where each one is used.
  - Declare parameters with a custom label and with no label (_).
  - Read a function's full name, like print(_:separator:terminator:).
  - Give parameters default values and call the function with and without them.
  - Choose labels so that a call reads clearly.
terms:
  - term: Argument label
    definition: "The name the caller writes before an argument, like to in send(\"Hi\", to: \"Ana\"). It's part of how the call reads."
  - term: Parameter name
    definition: The name the function's body uses for a parameter. It's invisible to the caller.
  - term: Wildcard label (_)
    definition: An underscore in the label position. It means the caller passes that argument without a label.
  - term: Default value
    definition: A value written after the parameter's type with =. If the caller leaves that argument out, the parameter gets the default.
  - term: Full function name
    definition: The base name plus every argument label followed by a colon, with _ for unlabeled ones, like print(_:separator:terminator:).
mastery:
  - Write a declaration whose call reads like a short phrase, choosing labels and parameter names separately.
  - Explain every part of print's declaration, including _, the labels and the default values.
  - Predict the output of calls that skip some arguments with default values.
  - Fix "missing argument label", "extraneous argument label" and "incorrect argument label" errors without the compiler's help.
resources: [swift-api-design-guidelines, swift-book-functions, swift-print]
cards:
  - id: m06-l02-c1
    front: "In `func send(_ message: String, to recipient: String)`, what are the labels and what are the parameter names?"
    back: "The labels are none (_) for the first and to for the second. The parameter names are message and recipient. You call it as send(\"Hi\", to: \"Ana\")."
  - id: m06-l02-c2
    front: What does _ mean before a parameter name?
    back: That the caller passes the argument without a label, like print("Hi") or square(7).
  - id: m06-l02-c3
    front: "What's the full name of print, and what does each part mean?"
    back: "print(_:separator:terminator:). The first argument has no label; the other two have the labels separator and terminator."
  - id: m06-l02-c4
    front: "With `func greet(_ name: String, greeting: String = \"Hello\")`, what do greet(\"Ana\") and greet(\"Ana\", greeting: \"Hi\") do?"
    back: The first uses the default, so greeting is "Hello". The second replaces it with "Hi".
---

## The idea in one sentence

Each parameter can have two names: a **label** that reads well at the call site, and a **parameter name** that reads well inside the body.

## Two names for one parameter

In the previous lesson, `price` was both what the caller wrote (`itemCost(price: 45, …)`) and what the body used (`price * quantity`). That's the default: if you write one name, Swift uses it for both jobs. You can also write two:

```swift
func send(_ message: String, to recipient: String) {
    print("To \(recipient): \(message)")
}

send("See you at 6", to: "Ana")
```

```output
To Ana: See you at 6
```

Line by line:

1. `_ message: String`: the label is `_`, which means **no label**. The parameter name is `message`.
2. `to recipient: String`: the label is `to`, the parameter name is `recipient`.
3. Inside the body you use the parameter names, `recipient` and `message`. The labels don't exist there.
4. At the call you use the labels: no label for the message, `to:` for the recipient.

The call reads like a phrase: *send "See you at 6" to Ana*. The body reads clearly too: `recipient` says what the value is, which `to` wouldn't.

| Declaration | Label (call site) | Parameter name (body) | Call |
| --- | --- | --- | --- |
| `price: Int` | `price` | `price` | `f(price: 45)` |
| `_ n: Int` | none | `n` | `f(45)` |
| `from start: Int` | `from` | `start` | `f(from: 45)` |

## The full name of a function

Swift names a function by its base name and its labels: `send(_:to:)`. Each label ends in a colon, and `_` stands for an unlabeled argument. Documentation and Xcode use this form, so learn to read it.

The labels are part of the name, so two functions can share a base name if their labels differ:

```swift
func distance(from start: Int, to end: Int) -> Int {
    end - start
}

func distance(fromZeroTo end: Int) -> Int {
    end
}

print(distance(from: 3, to: 10))
print(distance(fromZeroTo: 10))
```

```output
7
10
```

Those are `distance(from:to:)` and `distance(fromZeroTo:)`: two different functions.

## print, read again

In Module 3 you opened the documentation for `print` and found this declaration:

```swift illustrative
func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
)
```

Now every part has a name:

- `_ items: Any...`: no label, which is why you write `print("Hello")` and not `print(items: "Hello")`. The parameter name inside the standard library's code is `items`. The `...` makes it **variadic**: it accepts any number of values, separated by commas. `Any` means they can be of any type.
- `separator: String = " "`: label and parameter name are both `separator`. The `= " "` is a **default value**.
- `terminator: String = "\n"`: same idea, with a newline as the default.
- No `->`: `print` returns `Void`.

The full name is `print(_:separator:terminator:)`, exactly the title of its documentation page. In Module 4 you used `separator:` and `terminator:` as "names that go with certain values". Now you know they're argument labels, and why you could leave them out: they have defaults.

## Default values

Write `= value` after a parameter's type, and callers can skip that argument:

```swift
func greet(_ name: String, greeting: String = "Hello", punctuation: String = "!") -> String {
    "\(greeting), \(name)\(punctuation)"
}

print(greet("Ana"))
print(greet("Ana", greeting: "Hi"))
print(greet("Ana", punctuation: "?"))
print(greet("Ana", greeting: "Good morning", punctuation: "."))
```

```output
Hello, Ana!
Hi, Ana!
Hello, Ana?
Good morning, Ana.
```

1. Only the name: both defaults apply.
2. `greeting` is replaced; `punctuation` keeps its default.
3. You can skip `greeting` and still pass `punctuation`, because the label tells Swift which parameter you mean.
4. Both replaced.

Two rules:

- **Arguments still go in the declared order.** You can skip a defaulted one, but you can't swap two you do pass.
- **Put parameters with defaults at the end.** Swift allows them anywhere, but parameters without defaults usually carry the most important information, and putting them first keeps calls consistent. The Swift book recommends the same.

Use a default when one value covers most calls, like a space for `separator`. Don't use one to hide a value the caller should think about, like a price.

## Naming: making the call read well

Swift's naming conventions, published as the *API Design Guidelines* on swift.org, come down to one rule of thumb: **design for the call site**, because a function is called many more times than it's declared. In practice:

- Drop the first label when the base name already says what the first argument is: `square(7)`, `print("Hi")`, `send("Hi", to: "Ana")`.
- Use a preposition as the label when it explains the argument's role: `move(from: 2, to: 5)`, `distance(from:to:)`.
- Keep labels when the arguments would be ambiguous without them: `rectangleArea(width: 4, height: 3)` is clearer than `rectangleArea(4, 3)`.
- Pick parameter names for the body: `recipient`, not `to`; `start`, not `from`.

Read the call out loud. If it sounds like a clear phrase, the labels are right.

## A practical example: formatting a price

```swift
func formatPrice(_ amount: Int, currency symbol: String = "$", withCents showCents: Bool = false) -> String {
    if showCents {
        return "\(symbol)\(amount).00"
    }
    return "\(symbol)\(amount)"
}

print(formatPrice(45))
print(formatPrice(45, currency: "€"))
print(formatPrice(45, withCents: true))
print(formatPrice(1200, currency: "MX$", withCents: true))
```

```output
$45
€45
$45.00
MX$1200.00
```

The amount is the main argument: no label, no default. The currency and the cents option have defaults, so most calls are just `formatPrice(45)`. Inside the body, `symbol` and `showCents` say what the values are. At the call site, `currency:` and `withCents:` say what the arguments do.

## Common mistakes

> [!error] error: missing argument label 'name:' in call
> The declaration has a label and the call left it out. Either add the label to the call or, if a label really doesn't help, change the declaration to `_ name: String`. Swift 6.3:

```swift no-compile missing argument label 'name:' in call
func greet(name: String) {
    print("Hello, \(name)")
}
greet("Ana")
```

> [!error] error: extraneous argument label 'name:' in call
> The reverse: the declaration says `_`, so the call must not use a label.

```swift no-compile extraneous argument label 'name:' in call
func greet(_ name: String) {
    print("Hello, \(name)")
}
greet(name: "Ana")
```

> [!error] error: incorrect argument label in call (have 'name:', expected 'to:')
> You used the **parameter name** where the **label** goes. At the call site only labels exist.

```swift no-compile incorrect argument label in call (have 'name:', expected 'to:')
func greet(to name: String) {
    print("Hello, \(name)")
}
greet(name: "Ana")
```

> [!error] error: argument 'width' must precede argument 'height'
> Labels don't let you reorder arguments. Pass them in the order of the declaration.

```swift no-compile argument 'width' must precede argument 'height'
func area(width: Int, height: Int) -> Int {
    width * height
}
print(area(height: 2, width: 3))
```

````exercise
id: m06-l02-e1
type: comprehension
prompt: |
  Given this declaration, which call compiles?

  ```swift
  func move(_ piece: String, from start: Int, to end: Int) {
      print(piece, start, end)
  }
  ```
choices:
  - text: "`move(piece: \"Rook\", from: 1, to: 8)`"
    correct: false
    why: "The first parameter's label is _, so piece: is an extraneous label."
  - text: "`move(\"Rook\", start: 1, end: 8)`"
    correct: false
    why: start and end are parameter names, used inside the body. The labels are from and to.
  - text: "`move(\"Rook\", from: 1, to: 8)`"
    correct: true
    why: No label for the first argument, then the labels from and to, in the declared order.
  - text: "`move(\"Rook\", to: 8, from: 1)`"
    correct: false
    why: The labels are right, but the order isn't. Arguments go in the declared order.
solution: |
  **`move("Rook", from: 1, to: 8)`.** The full name is `move(_:from:to:)`: no label, then `from`, then `to`. The parameter names `piece`, `start` and `end` only exist inside the body. Labels don't let you reorder arguments.
````

````exercise
id: m06-l02-e2
type: prediction
prompt: Predict the exact output. Keep track of which arguments use their defaults.
code: |
  func repeatText(_ text: String, times: Int = 2, separator: String = "-") -> String {
      var result = text
      for _ in 1..<times {
          result += separator + text
      }
      return result
  }

  print(repeatText("ha"))
  print(repeatText("ha", times: 4))
  print(repeatText("ho", separator: " "))
  print(repeatText("go", times: 3, separator: "! "))
  print(repeatText("solo", times: 1))
output: |
  ha-ha
  ha-ha-ha-ha
  ho ho
  go! go! go
  solo
hints:
  - "With times: 2 the loop body runs once: 1..<2 contains only 1."
  - "With times: 1, the range 1..<1 is empty."
solution: |
  ```output
  ha-ha
  ha-ha-ha-ha
  ho ho
  go! go! go
  solo
  ```

  `result` starts with one copy, and the loop adds `times - 1` more, each preceded by the separator.

  1. Both defaults: 2 copies joined by `-`.
  2. 4 copies, default separator.
  3. Default `times` (2), separator `" "`.
  4. 3 copies joined by `"! "`. There's no `!` after the last one, because the separator only goes *between* copies.
  5. `1..<1` is empty, so the loop doesn't run and the result is just `"solo"`.
````

````exercise
id: m06-l02-e3
type: fill-in
prompt: |
  Complete the declaration so the calls below compile and print what's shown. Inside the body, the parameters are called `amount` and `percent`.

  ```output
  90
  80
  ```
code: |
  func applyDiscount([[1]] amount: Int, [[2]] percent: Int = [[3]]) -> Int {
      amount - amount * percent / 100
  }
  print(applyDiscount(100))
  print(applyDiscount(100, of: 20))
blanks:
  - id: "1"
    answers: ["_"]
  - id: "2"
    answers: ["of"]
  - id: "3"
    answers: ["10"]
solution: |
  ```swift
  func applyDiscount(_ amount: Int, of percent: Int = 10) -> Int {
      amount - amount * percent / 100
  }
  print(applyDiscount(100))
  print(applyDiscount(100, of: 20))
  ```

  ```output
  90
  80
  ```

  The first call passes the amount without a label, so its label is `_`. The second call uses `of:`, so that's the label of the second parameter; inside the body it's `percent`. The first call gives 90 without passing a percentage, so the default must be 10.
````

````exercise
id: m06-l02-e4
type: find-errors
prompt: This program doesn't compile. Pick out the real problems, then write the fixed version.
code: |
  func rectangleArea(width w: Int, height h: Int) -> Int {
      width * height
  }

  func describe(_ name: String, area: Int) {
      print("\(name): \(area) m²")
  }

  describe(name: "Kitchen", area: rectangleArea(w: 4, h: 3))
choices:
  - text: "The body of rectangleArea uses the labels width and height instead of the parameter names w and h."
    correct: true
    why: "Inside the body only parameter names exist. Swift reports cannot find 'width' in scope."
  - text: "The call to rectangleArea uses the parameter names w: and h: instead of the labels."
    correct: true
    why: "At the call site only labels exist. It should be rectangleArea(width: 4, height: 3)."
  - text: "describe's first parameter has no label, so name: is extraneous."
    correct: true
    why: "The declaration says _ name, so the call is describe(\"Kitchen\", area: …)."
  - text: "A function's call can't be passed as the argument of another function."
    correct: false
    why: A call is replaced by its value. Passing rectangleArea(…) to describe is fine.
rubric:
  - The body of rectangleArea uses w and h, or I renamed the parameters so the body reads well.
  - Calls use labels, not parameter names.
  - My version prints Kitchen 12 m².
solution: |
  ```swift
  func rectangleArea(width: Int, height: Int) -> Int {
      width * height
  }

  func describe(_ name: String, area: Int) {
      print("\(name): \(area) m²")
  }

  describe("Kitchen", area: rectangleArea(width: 4, height: 3))
  ```

  ```output
  Kitchen: 12 m²
  ```

  The simplest fix for `rectangleArea` is to stop using two names: `width` and `height` work fine as both the label and the parameter name. The original mixed them up in both directions: labels in the body and parameter names in the call. Short parameter names like `w` and `h` save nothing and make the body harder to read.
````

````exercise
id: m06-l02-e5
type: solve
prompt: |
  Write a function that builds a progress bar as text. It receives how many steps are done and, optionally, the total number of steps (10 by default). Done steps are `#` and the rest are `.`, between brackets. Choose the labels so these calls work:

  ```swift illustrative
  print(progressBar(3))
  print(progressBar(2, outOf: 4))
  print(progressBar(5, outOf: 5))
  ```

  and print:

  ```output
  [###.......]
  [##..]
  [#####]
  ```
starter: |
  func progressBar(/* parameters */) -> String {
      // your code
  }
hints:
  - "The first parameter has no label: _ done: Int."
  - "The second one has the label outOf, a parameter name such as total, and = 10."
  - "Build the text in a var with two loops, or one loop and an if."
rubric:
  - The function returns a String and doesn't print.
  - The total has a default of 10 and the label outOf.
  - The body uses clear parameter names, not the labels.
  - The three calls print exactly the three lines.
solution: |
  ```swift
  func progressBar(_ done: Int, outOf total: Int = 10) -> String {
      var bar = "["
      for step in 1...total {
          if step <= done {
              bar += "#"
          } else {
              bar += "."
          }
      }
      return bar + "]"
  }

  print(progressBar(3))
  print(progressBar(2, outOf: 4))
  print(progressBar(5, outOf: 5))
  ```

  ```output
  [###.......]
  [##..]
  [#####]
  ```

  The call `progressBar(2, outOf: 4)` reads as a phrase, and the body talks about `done` and `total`. Each pass of the loop decides one character: steps up to `done` are `#`, the rest are `.`. One edge case to think about: with `outOf: 0`, the range `1...0` is invalid and the program would stop with a runtime error. A `guard` at the top of the function would handle that; it's in the next lesson.
````

````exercise
id: m06-l02-e6
type: design
prompt: |
  You're writing a function that books a table at a restaurant. It needs the customer's name, the number of people (almost always 2), and the time (an Int from 0 to 23, no usual value). Write **only the declaration** (no body is needed, but you can add one), with labels, parameter names, types and defaults, and write two example calls. Explain each choice.
rubric:
  - The calls read like a short phrase.
  - Only the number of people has a default, and it's 2.
  - Parameters without defaults come first.
  - The parameter names inside the body are clear nouns.
  - I explained why the time has no default.
solution: |
  One reasonable design:

  ```swift
  func bookTable(for name: String, at hour: Int, people: Int = 2) {
      print("Table for \(people) at \(hour):00, name: \(name)")
  }

  bookTable(for: "Ana", at: 20)
  bookTable(for: "Luis", at: 14, people: 6)
  ```

  ```output
  Table for 2 at 20:00, name: Ana
  Table for 6 at 14:00, name: Luis
  ```

  - `for name`: the call reads *book table for Ana*; the body uses `name`.
  - `at hour`: *at 20*; the body uses `hour`, which says what the number is.
  - `people: Int = 2` goes last because it has a default. Most calls skip it.
  - The time has no default because there's no "usual" time: a default would book people at an hour they never chose.

  Other labels are fine if the call reads clearly and you can defend them, for example `bookTable(name: "Ana", hour: 20)`.
````

## Summary

- Each parameter has an argument label (for the caller) and a parameter name (for the body). One name means both.
- `_` as the label means the caller passes the argument without a label.
- A function's full name includes its labels: `print(_:separator:terminator:)`.
- `= value` after the type gives a parameter a default; callers can skip it. Arguments still go in the declared order.
- Choose labels so the call reads like a phrase, and parameter names so the body reads clearly.
