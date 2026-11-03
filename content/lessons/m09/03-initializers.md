---
id: m09-l03
title: "Initializers"
description: You write your own initializers, see what happens to the memberwise one when you do and how to keep it with an extension, give properties default values, validate input with failable init?, and reuse one initializer from another with self.init.
module: m09
order: 3
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l02]
objectives:
  - State the rule every initializer must follow and read the compiler errors that enforce it.
  - Give stored properties default values and predict the memberwise initializer that results.
  - Write custom initializers and use self to tell properties from parameters.
  - Keep the memberwise initializer next to custom ones by declaring them in an extension.
  - Write a failable init? that validates its input, and delegate between initializers with self.init.
terms:
  - term: Initializer
    definition: "A special function declared with init that prepares a new instance: it gives every stored property a value. You call it with the type's name, as in Book(title: \"Dune\", pages: 412)."
  - term: Default property value
    definition: "An initial value written in the property's declaration, like var score = 0. Initializers don't have to set it, and the memberwise initializer makes its parameter optional."
  - term: Failable initializer
    definition: "An initializer declared with init? that can return nil instead of an instance when its input is invalid. Calling it gives an optional."
  - term: Initializer delegation
    definition: "Calling another initializer of the same type with self.init(…) so the setup logic lives in one place."
  - term: Extension
    definition: "A block that adds members, such as initializers or methods, to an existing type. Covered properly in Module 10; here it's used to keep the memberwise initializer."
mastery:
  - Fix an initializer that leaves a stored property without a value.
  - Predict which arguments the memberwise initializer accepts for a struct with default values.
  - Write a custom initializer with self.property = parameter assignments.
  - Move a custom initializer into an extension so the memberwise one still exists.
  - Write an init? that returns nil for invalid input, and use it with if let or guard let.
resources: [swift-book-initialization, swift-book-structures-classes, swift-book-basics]
cards:
  - id: m09-l03-c1
    front: What must every initializer do before it finishes?
    back: "Give every stored property a value, either directly or through a default value. Otherwise Swift 6.3 reports: return from initializer without initializing all stored properties."
  - id: m09-l03-c2
    front: What happens to the memberwise initializer when you write a custom init inside the struct's body?
    back: "Swift stops generating it. To keep it, declare your custom initializer in an extension of the struct instead."
  - id: m09-l03-c3
    front: "How do you write an initializer that can fail, and what does calling it return?"
    back: "Declare it with init? and write return nil for invalid input. Calling it returns an optional, such as Percentage?, which you unwrap with if let, guard let or ??."
  - id: m09-l03-c4
    front: "Inside init(name: String), why is name = name an error?"
    back: "Both names refer to the parameter, which is a constant. Write self.name = name to assign the parameter to the property."
  - id: m09-l03-c5
    front: What does self.init(…) do inside an initializer?
    back: "It hands the work to another initializer of the same struct, so validation and setup live in one place. Afterward, the instance is fully initialized."
---

## The idea in one sentence

An initializer's job is to give every stored property a valid value, and writing your own lets you decide what "valid" means and what to do when the input isn't.

## The one rule

So far you've created instances with the memberwise initializer that Swift writes for you. Whichever initializer runs, the rule is the same: **when it finishes, every stored property has a value.** Swift checks this at compile time. There's no such thing as a half-built struct.

Here's a custom initializer that breaks the rule:

```swift no-compile return from initializer without initializing all stored properties
struct Point {
    var x: Double
    var y: Double

    init(x: Double) {
        self.x = x
    }
}
```

Swift 6.3 reports `error: return from initializer without initializing all stored properties`, with a note pointing at `'self.y' not initialized`. You'll also see `'self' used before all stored properties are initialized` if you read a property, or call a method, before they all have values.

## Default property values

The simplest way to satisfy the rule is to give a property a value right in its declaration:

```swift
struct Timer {
    var label: String
    var seconds = 60
    var isRunning = false
}

let egg = Timer(label: "Eggs", seconds: 420)
let tea = Timer(label: "Tea")
let quick = Timer(label: "Plank", seconds: 45, isRunning: true)

print(egg)
print(tea)
print(quick)
```

```output
Timer(label: "Eggs", seconds: 420, isRunning: false)
Timer(label: "Tea", seconds: 60, isRunning: false)
Timer(label: "Plank", seconds: 45, isRunning: true)
```

`seconds` and `isRunning` have defaults, and their types are inferred from them, as with any variable. The memberwise initializer turns each default into a default argument (Module 6), so you can leave those arguments out, but the ones you pass still go in declaration order.

A `let` property with a default value is different: it can never be anything else, so it isn't in the memberwise initializer at all.

## Writing your own initializer

An initializer looks like a function named `init`, without `func` and without a return type:

```swift
struct Rectangle {
    var width: Double
    var height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    init(side: Double) {
        width = side
        height = side
    }
}

let banner = Rectangle(width: 6, height: 1.5)
let tile = Rectangle(side: 2)
print(banner.width, banner.height)
print(tile.width, tile.height)
```

```output
6.0 1.5
2.0 2.0
```

1. You call an initializer through the type's name, `Rectangle(…)`. The labels pick which one runs: `Rectangle(side:)` runs the second.
2. In `init(width:height:)`, the parameters have the same names as the properties. Inside the body, plain `width` is the parameter, so `self.width = width` means "store the parameter in the property". This is the most common use of `self` in Swift.
3. In `init(side:)` there's no clash, so `width = side` is enough.

Forget the `self.` and both sides of `name = name` are the parameter. Parameters are constants, so Swift 6.3 rejects it with `cannot assign to value: 'name' is a 'let' constant` and a note suggesting `self.`.

### Where the memberwise initializer goes

Write any initializer inside the struct's braces, and Swift **stops generating the memberwise one**. That's why `Rectangle` above had to write `init(width:height:)` by hand. Without it:

```swift no-compile incorrect argument label in call (have 'celsius:', expected 'fahrenheit:')
struct Temperature {
    var celsius: Double

    init(fahrenheit: Double) {
        celsius = (fahrenheit - 32) * 5 / 9
    }
}

let room = Temperature(celsius: 21)
```

Swift's reasoning: once you write your own initializer, you might be enforcing something, and a generated initializer would let callers skip it.

When you want both, declare your initializers in an **extension**. An extension adds members to a type that's already declared; Module 10 covers them properly. For now, one fact matters: initializers declared in an extension don't remove the memberwise one.

```swift
struct Temperature {
    var celsius: Double
}

extension Temperature {
    init(fahrenheit: Double) {
        self.init(celsius: (fahrenheit - 32) * 5 / 9)
    }
}

let room = Temperature(celsius: 21)
let oven = Temperature(fahrenheit: 356)
print(room.celsius)
print(oven.celsius)
```

```output
21.0
180.0
```

Notice `self.init(celsius: …)` inside the extension: one initializer calling another. That's next.

## Delegating with self.init

When initializers share logic, have the specific ones call a general one with **`self.init(…)`**. Every path then goes through the same code:

```swift
struct Duration {
    var totalSeconds: Int

    init(totalSeconds: Int) {
        self.totalSeconds = max(totalSeconds, 0)
    }

    init(minutes: Int, seconds: Int) {
        self.init(totalSeconds: minutes * 60 + seconds)
    }

    init(hours: Int) {
        self.init(minutes: hours * 60, seconds: 0)
    }

    var text: String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds < 10 ? "\(minutes):0\(seconds)" : "\(minutes):\(seconds)"
    }
}

print(Duration(minutes: 3, seconds: 5).text)
print(Duration(hours: 1).text)
print(Duration(totalSeconds: -40).text)
```

```output
3:05
60:00
0:00
```

`init(hours:)` calls `init(minutes:seconds:)`, which calls `init(totalSeconds:)`, the only place that stores anything. The rule "never negative" lives there, once, and no path can skip it.

## Failable initializers

Some input can't make a valid instance at all. A percentage of 140, a time of "25:99", an email without `@`. You've already used initializers that handle this by returning `nil`: `Int("abc")` is an initializer of `Int`, and it's **failable**. In Module 8 you learned to return an optional when "no result" has one clear meaning. A failable initializer applies the same idea to creating an instance.

Declare it with **`init?`** and write `return nil` where the input is invalid:

```swift
struct Percentage {
    let value: Int

    init?(_ value: Int) {
        guard value >= 0 && value <= 100 else {
            return nil
        }
        self.value = value
    }
}

let battery = Percentage(85)
let impossible = Percentage(140)
print(battery?.value ?? -1)
print(impossible == nil)

if let progress = Percentage(40) {
    print("Progress: \(progress.value)%")
}
```

```output
85
true
Progress: 40%
```

1. `init?` makes the initializer failable. Calling it gives a `Percentage?`, not a `Percentage`, so everything from Module 8 applies: `?.`, `??`, `if let`, `guard let`.
2. `return nil` is allowed only in a failable initializer. An initializer never returns an instance with `return`: it succeeds by reaching the end with every property set.
3. `value` is a `let`, and there's no other initializer, so **every `Percentage` that exists is between 0 and 100**. Code that receives one never has to check again. That's the real payoff: the type itself carries the guarantee.

Using the result as a plain value is the familiar Module 8 error: `value of optional type 'Percentage?' must be unwrapped to a value of type 'Percentage'`.

A failable initializer can delegate too. It can call a non-failable initializer, or another failable one, and if that one fails, the whole initialization fails. (The opposite isn't allowed: a plain `init` can't call an `init?`, because it has no way to fail.)

### Fail, fix, or crash?

When the input is out of range, an initializer has three options:

- **Fail** with `init?` when the caller sent something meaningless and should find out: parsing user input, reading a file.
- **Fix** the value, like `Duration` clamping negatives to 0, when there's an obvious correction and the caller wouldn't care. Be honest with yourself here: silently changing data hides bugs.
- **Throw an error** when the caller needs to know which of several things went wrong. That's `init(...) throws`, in Module 12.

A crash isn't on the list. You'll meet `precondition` later for programmer mistakes, but invalid input from the outside world isn't a programmer mistake.

### Validating where observers can't

Lesson 2 showed that `didSet` doesn't run in the initializer, so a clamp in `didSet` can be bypassed with `Speaker(volume: 99)`. An initializer closes that hole:

```swift
struct Speaker {
    var volume: Int {
        didSet {
            volume = Speaker.clamped(volume)
        }
    }

    init(volume: Int) {
        self.volume = Speaker.clamped(volume)
    }

    static func clamped(_ value: Int) -> Int {
        return min(max(value, 0), 10)
    }
}

var speaker = Speaker(volume: 99)
print(speaker.volume)
speaker.volume = -5
print(speaker.volume)
```

```output
10
0
```

`static func` declares a function that belongs to the type itself rather than to one instance, so both the initializer and `didSet` can share it before `volume` has a value. Lesson 4 covers `static` properly.

## A practical example: a time of day

In Module 8 you wrote `parseTime(_:)`, returning `(hour: Int, minute: Int)?`. A type is a better home for it: the parsing becomes a failable initializer, and the result is a real `TimeOfDay` that's valid by construction.

```swift
struct TimeOfDay {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard hour >= 0 && hour <= 23, minute >= 0 && minute <= 59 else {
            return nil
        }
        self.hour = hour
        self.minute = minute
    }

    init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        self.init(hour: hour, minute: minute)
    }

    var text: String {
        let hourText = hour < 10 ? "0\(hour)" : "\(hour)"
        let minuteText = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hourText):\(minuteText)"
    }

    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }
}

let inputs = ["9:05", "23:59", "24:00", "noon", "7:30"]
var times: [TimeOfDay] = []
for input in inputs {
    guard let time = TimeOfDay(input) else {
        print("Skipping \"\(input)\"")
        continue
    }
    times.append(time)
}

let sorted = times.sorted { a, b in a.minutesSinceMidnight < b.minutesSinceMidnight }
print(sorted.map { time in time.text })
```

```output
Skipping "24:00"
Skipping "noon"
["07:30", "09:05", "23:59"]
```

The text initializer only splits and converts. The range check lives in `init?(hour:minute:)`, and the text initializer delegates to it, so `"24:00"` fails there. Because `hour` and `minute` are `let` and every initializer validates, there's no way to build a `TimeOfDay` of 24:00, from text or from numbers.

## Common mistakes

> [!error] error: return from initializer without initializing all stored properties
> A path through your initializer leaves a stored property without a value. Assign it, or give it a default value in its declaration.

> [!error] error: cannot assign to value: 'name' is a 'let' constant
> You wrote `name = name` in an initializer whose parameter is also called `name`. Both sides are the parameter. Write `self.name = name`.

```swift no-compile cannot assign to value: 'name' is a 'let' constant
struct User {
    let name: String

    init(name: String) {
        name = name
    }
}
```

> [!error] error: incorrect argument label in call
> You added a custom initializer inside the struct and the memberwise call stopped compiling. Move the custom initializer into an extension, or write the memberwise one by hand.

> [!error] error: value of optional type 'Percentage?' must be unwrapped
> A failable initializer returns an optional. Unwrap it with `if let`, `guard let` or `??` like any other optional.

```swift no-compile value of optional type 'Percentage?' must be unwrapped to a value of type 'Percentage'
struct Percentage {
    let value: Int

    init?(_ value: Int) {
        guard value >= 0 && value <= 100 else {
            return nil
        }
        self.value = value
    }
}

let progress: Percentage = Percentage(40)
```

> [!warning] Validating in didSet only
> Observers don't run during initialization. If a property must always be valid, check it in every initializer too, or make it a `let` set by a validating `init?`.

````exercise
id: m09-l03-e1
type: comprehension
prompt: |
  Which calls compile for this struct? Select all that apply.

  ```swift illustrative
  struct Alarm {
      var label: String
      var hour = 7
      var isOn = true
  }
  ```
multiple: true
choices:
  - text: "`Alarm(label: \"Gym\")`"
    correct: true
    why: hour and isOn have defaults, so they can be left out.
  - text: "`Alarm(label: \"Gym\", isOn: false)`"
    correct: true
    why: "Arguments with defaults can be skipped individually, as long as the ones you pass stay in declaration order."
  - text: "`Alarm(hour: 6, label: \"Gym\")`"
    correct: false
    why: "label is declared before hour, so it must come first."
  - text: "`Alarm()`"
    correct: false
    why: label has no default value, so it's required.
solution: |
  The first two. The memberwise initializer is `init(label: String, hour: Int = 7, isOn: Bool = true)`: `label` is required, the other two are optional, and the order is fixed by the declarations.
````

````exercise
id: m09-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Username {
      let text: String

      init?(_ raw: String) {
          let trimmed = raw.lowercased()
          guard trimmed.count >= 3, !trimmed.contains(" ") else {
              return nil
          }
          text = trimmed
      }
  }

  for raw in ["Christian", "al", "ada lovelace", "SWIFT"] {
      if let name = Username(raw) {
          print("ok: \(name.text)")
      } else {
          print("rejected: \(raw)")
      }
  }
  print(Username("x")?.text ?? "none")
output: |
  ok: christian
  rejected: al
  rejected: ada lovelace
  ok: swift
  none
hints:
  - "lowercased() runs before the checks."
  - "contains(\" \") is true when the text has a space."
solution: |
  ```output
  ok: christian
  rejected: al
  rejected: ada lovelace
  ok: swift
  none
  ```

  `"Christian"` passes and is stored lowercased. `"al"` is too short. `"ada lovelace"` contains a space. `"SWIFT"` becomes `"swift"`. `Username("x")` is `nil`, so `?.text` is `nil` and `??` gives `"none"`. (The constant is called `trimmed`, but nothing trims it; a better name would be `lowercase`. Names that lie are a bug waiting to happen.)
````

````exercise
id: m09-l03-e3
type: fill-in
prompt: "Complete `Money` so that `Money(dollars: 4, cents: 50)` delegates to the general initializer, and the program prints `450` and `199`."
code: |
  struct Money {
      var cents: Int
  }

  [[1]] Money {
      init(dollars: Int, cents: Int) {
          [[2]].init(cents: dollars * 100 + [[3]])
      }
  }

  let coffee = Money(dollars: 4, cents: 50)
  let snack = Money([[4]]: 199)
  print(coffee.cents)
  print(snack.cents)
blanks:
  - id: "1"
    answers: [extension]
  - id: "2"
    answers: [self]
  - id: "3"
    answers: [cents]
  - id: "4"
    answers: [cents]
solution: |
  ```swift
  struct Money {
      var cents: Int
  }

  extension Money {
      init(dollars: Int, cents: Int) {
          self.init(cents: dollars * 100 + cents)
      }
  }

  let coffee = Money(dollars: 4, cents: 50)
  let snack = Money(cents: 199)
  print(coffee.cents)
  print(snack.cents)
  ```

  ```output
  450
  199
  ```

  Because `init(dollars:cents:)` is declared in an extension, the memberwise `init(cents:)` still exists, and `self.init(cents:)` can call it. Inside the new initializer, `cents` on its own is the parameter; the property is only reached through `self.init`.
````

````exercise
id: m09-l03-e4
type: find-errors
prompt: "This struct should only ever hold a valid RGB color (each channel 0 to 255). Which statements are true?"
code: |
  struct Color {
      var red: Int
      var green: Int
      var blue: Int

      init?(red: Int, green: Int, blue: Int) {
          guard red >= 0 && red <= 255, green >= 0 && green <= 255 else {
              return nil
          }
          self.red = red
          self.green = green
      }
  }

  var teal = Color(red: 0, green: 128, blue: 128)
  teal.red = 300
choices:
  - text: The initializer doesn't compile because blue is never assigned.
    correct: true
    why: "Every path that doesn't return nil must give every stored property a value."
  - text: blue isn't validated, so a color with blue 999 could be created even after fixing the assignment.
    correct: true
    why: The guard checks only red and green.
  - text: "`teal.red = 300` doesn't compile, because `teal` is a `Color?`."
    correct: true
    why: "A failable initializer returns an optional. teal must be unwrapped first."
  - text: "Even with every check in place, the var properties let callers break the 0...255 rule after creation."
    correct: true
    why: "Validation in the initializer only guarantees the first value. With let properties, a Color can't be changed into an invalid one."
  - text: A failable initializer can't use guard.
    correct: false
    why: guard with return nil is the usual way to write one.
rubric:
  - I found the missing blue assignment and the missing blue check.
  - I noticed that teal is optional.
  - I explained that var properties let callers break the 0...255 rule after creation.
solution: |
  Four real problems. `blue` is never assigned, and never checked. `teal` is a `Color?`, so `teal.red` doesn't compile. And even after unwrapping, `var` properties let anyone store 300 later, so validating in the initializer guarantees nothing about later values. Make the channels `let`:

  ```swift
  struct Color {
      let red: Int
      let green: Int
      let blue: Int

      init?(red: Int, green: Int, blue: Int) {
          guard red >= 0 && red <= 255,
                green >= 0 && green <= 255,
                blue >= 0 && blue <= 255 else {
              return nil
          }
          self.red = red
          self.green = green
          self.blue = blue
      }
  }

  if let teal = Color(red: 0, green: 128, blue: 128) {
      print(teal.red, teal.green, teal.blue)
  }
  print(Color(red: 0, green: 0, blue: 999) == nil)
  ```

  ```output
  0 128 128
  true
  ```

  To change a color now, you create a new one, which goes through the validation again.
````

````exercise
id: m09-l03-e5
type: solve
prompt: |
  Write a `struct Grade` with a `let score: Int` and two initializers:

  - `init?(score: Int)` that fails unless the score is from 0 to 100,
  - `init?(_ text: String)` that converts the text with `Int(…)` and delegates to the first one.

  Add a computed `letter: String`: `"A"` for 90 and up, `"B"` for 80–89, `"C"` for 70–79, `"F"` below 70.

  Run it on `["95", "82", "abc", "101", "70", "12"]` and match:

  ```output
  95 -> A
  82 -> B
  abc -> invalid
  101 -> invalid
  70 -> C
  12 -> F
  ```
starter: |
  struct Grade {
      let score: Int

      // init?(score:), init?(_:), letter
  }

  for input in ["95", "82", "abc", "101", "70", "12"] {
      // print one line per input
  }
hints:
  - "In init?(_ text: String), guard let number = Int(text) else { return nil }."
  - "Then call self.init(score: number). If it fails, so does this initializer."
  - "A switch over score with ranges like 90...100 fits letter."
rubric:
  - Both initializers are failable and the text one delegates with self.init.
  - The range check exists in one place only.
  - letter is a computed property that covers every valid score.
  - The output matches exactly.
solution: |
  ```swift
  struct Grade {
      let score: Int

      init?(score: Int) {
          guard score >= 0 && score <= 100 else {
              return nil
          }
          self.score = score
      }

      init?(_ text: String) {
          guard let number = Int(text) else {
              return nil
          }
          self.init(score: number)
      }

      var letter: String {
          switch score {
          case 90...:
              return "A"
          case 80..<90:
              return "B"
          case 70..<80:
              return "C"
          default:
              return "F"
          }
      }
  }

  for input in ["95", "82", "abc", "101", "70", "12"] {
      if let grade = Grade(input) {
          print("\(input) -> \(grade.letter)")
      } else {
          print("\(input) -> invalid")
      }
  }
  ```

  ```output
  95 -> A
  82 -> B
  abc -> invalid
  101 -> invalid
  70 -> C
  12 -> F
  ```

  `"abc"` fails in the text initializer; `"101"` converts fine and fails in `init?(score:)`, the single place where the range lives. `letter` can use `90...` and `default` safely because no `Grade` outside 0...100 can exist.
````

````exercise
id: m09-l03-e6
type: refactor
prompt: |
  This code validates a seat code like `"14C"` (row 1–30, seat letter A–F) with a free function and keeps passing the raw `String` around. Refactor it into a `struct Seat` with `let row: Int`, `let letter: String` and a failable `init?(_ code: String)`, plus a computed `isWindow: Bool` (A and F are windows). Keep the output identical.
code: |
  func isValidSeat(_ code: String) -> Bool {
      guard let letter = code.last, let row = Int(code.dropLast()) else {
          return false
      }
      return row >= 1 && row <= 30 && "ABCDEF".contains(letter)
  }

  for code in ["14C", "1A", "31B", "7F", "X"] {
      if isValidSeat(code) {
          let letter = code.last!
          print("\(code): valid, window: \(letter == "A" || letter == "F")")
      } else {
          print("\(code): invalid")
      }
  }
rubric:
  - Seat has let properties and a failable initializer that does all the validation.
  - The force unwrap is gone; the caller uses if let on the initializer.
  - isWindow is a computed property.
  - The output is unchanged.
solution: |
  ```swift
  struct Seat {
      let row: Int
      let letter: String

      init?(_ code: String) {
          guard let last = code.last, let row = Int(code.dropLast()),
                row >= 1 && row <= 30, "ABCDEF".contains(last) else {
              return nil
          }
          self.row = row
          self.letter = String(last)
      }

      var isWindow: Bool {
          letter == "A" || letter == "F"
      }
  }

  for code in ["14C", "1A", "31B", "7F", "X"] {
      if let seat = Seat(code) {
          print("\(code): valid, window: \(seat.isWindow)")
      } else {
          print("\(code): invalid")
      }
  }
  ```

  ```output
  14C: valid, window: false
  1A: valid, window: true
  31B: invalid
  7F: valid, window: true
  X: invalid
  ```

  The original checked the code in one place and then picked it apart again with `code.last!` in another, trusting that the check had happened. Now the parsing happens once, the result is a `Seat` that can't be invalid, and the force unwrap disappears. (`code.last` is the last `Character` or `nil` for an empty string; `code.dropLast()` is everything except it.)
````

## Summary

- Every initializer must give every stored property a value before it ends. The compiler checks every path.
- Default property values are the easiest way to do that, and they become optional arguments of the memberwise initializer.
- A custom `init` has no `func` and no return type. Use `self.property = parameter` when the names match.
- Writing an initializer inside the struct removes the memberwise one. Declare custom initializers in an `extension` to keep it.
- `self.init(…)` delegates to another initializer, so shared setup and validation live in one place.
- `init?` makes an initializer failable: `return nil` for invalid input, and callers get an optional.
- Validate in the initializer and use `let` properties, and every instance that exists is valid. `didSet` alone can't guarantee that, because it doesn't run during initialization.
