---
id: m09-l05
title: "Enums and raw values"
description: You define enumerations, types with a fixed list of cases, switch over them exhaustively without default, give cases String and Int raw values, create cases from raw values with the failable init?(rawValue:), list every case with CaseIterable, and add methods and computed properties to enums.
module: m09
order: 5
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l04]
objectives:
  - Declare an enum and use its cases, with and without the type name.
  - Write a switch over an enum that's exhaustive without default, and explain why that's safer.
  - Give an enum String or Int raw values, explicit or implicit, and read them.
  - Create a case from outside data with init?(rawValue:) and handle the nil.
  - Add CaseIterable, computed properties and mutating methods to an enum.
terms:
  - term: Enumeration (enum)
    definition: "A type whose value is always exactly one of a fixed list of cases that you declare. Direction.north is a value of type Direction."
  - term: Case
    definition: "One of the possible values of an enum, declared with the case keyword."
  - term: Raw value
    definition: "A fixed string, character or number attached to each case of an enum that declares a raw type, as in enum Coin: Int. Read it with .rawValue."
  - term: "init?(rawValue:)"
    definition: "The failable initializer Swift generates for an enum with raw values. It returns the matching case, or nil if no case has that raw value."
  - term: CaseIterable
    definition: "A protocol you add after the enum's name. Swift then generates allCases, an array of every case in declaration order."
  - term: Implicit member expression
    definition: "Writing .north instead of Direction.north when Swift already knows the expected type, as in a switch case or a typed parameter."
mastery:
  - Replace a String or Int that stands for one of a few options with an enum.
  - Write an exhaustive switch over an enum and read the compiler's list of missing cases.
  - Predict implicit raw values for String and Int enums.
  - Convert text to an enum case with init?(rawValue:) and handle the failure.
  - Give an enum a computed property and a mutating method that switch over self.
resources: [swift-book-enumerations, swift-book-control-flow, swift-book-basics]
cards:
  - id: m09-l05-c1
    front: Why can a switch over an enum skip default?
    back: "The compiler knows every case, so it can check you've handled them all. If you add a case later, every switch without default stops compiling until you handle it."
  - id: m09-l05-c2
    front: "What's the implicit raw value of case north in enum Direction: String?"
    back: "\"north\", the case's name. For an Int raw type, the first case is 0 and each next case is the previous one plus 1."
  - id: m09-l05-c3
    front: "What does Coin(rawValue: 7) return?"
    back: "nil, if no case has raw value 7. init?(rawValue:) is failable, so it returns a Coin?."
  - id: m09-l05-c4
    front: What does adding CaseIterable to an enum give you?
    back: "A static property allCases, an array of every case in declaration order. Useful for menus, pickers and loops."
  - id: m09-l05-c5
    front: When is writing .north without the type name allowed?
    back: "When Swift already knows the expected type: a switch case, a parameter of type Direction, a comparison with a Direction, or a variable with a type annotation."
---

## The idea in one sentence

An enum is a type whose value is always one of a list of cases you choose, so "north, south, east or west" stops being a `String` that could be anything.

## Defining an enum

Picture a traffic light modeled with a `String`: `var light = "green"`. Nothing stops `light = "gren"` or `light = "purple"`, and every `switch` over it needs a `default` for values that should never happen. Module 5 pointed at the fix: a type with a fixed list of values.

```swift
enum Direction {
    case north
    case south
    case east
    case west
}

var heading = Direction.north
print(heading)

heading = .west
print(heading)
print(heading == .west)
```

```output
north
west
true
```

1. `enum Direction { … }` declares a new type, like `struct` does. Its name starts with an uppercase letter.
2. Each `case` declares one of its possible values. A `Direction` is always exactly one of these four, never anything else, never "nothing" (that would be `Direction?`).
3. `Direction.north` is a value of type `Direction`. Case names start lowercase.
4. Once Swift knows `heading` is a `Direction`, you can drop the type name: `heading = .west`. That short form is called an **implicit member expression**, and it's what you'll write most of the time.
5. Enum cases without extra data can be compared with `==` with no extra work.

Several cases can share one `case` line: `case north, south, east, west` means the same.

The short form needs a known type. `let heading = .north` on its own doesn't compile: Swift 6.3 says `reference to member 'north' cannot be resolved without a contextual type`. Write `Direction.north`, or annotate: `let heading: Direction = .north`.

## switch without default

Here's where enums pay off. A switch over an enum can list every case, and then it's exhaustive with no `default`:

```swift
enum TrafficLight {
    case red, yellow, green
}

func instruction(for light: TrafficLight) -> String {
    switch light {
    case .red:
        return "Stop"
    case .yellow:
        return "Slow down"
    case .green:
        return "Go"
    }
}

print(instruction(for: .yellow))
print(instruction(for: .green))
```

```output
Slow down
Go
```

Forget a case and the code doesn't compile. Swift 6.3 even lists what's missing:

```swift no-compile switch must be exhaustive
enum TrafficLight {
    case red, yellow, green
}

func instruction(for light: TrafficLight) -> String {
    switch light {
    case .red:
        return "Stop"
    case .green:
        return "Go"
    }
}
```

The error is `switch must be exhaustive`, with the note `add missing case: '.yellow'`.

This is the most valuable thing about enums. Suppose next month you add `case flashingYellow`. Every `switch` over `TrafficLight` in the project stops compiling, and the compiler takes you to each one. Nothing silently falls into the wrong branch.

That only works if you **don't** write `default` in switches over your own enums. A `default` swallows any future case without a word. If every case is already listed, Swift 6.3 warns `default will never be executed`; take that as the hint to delete it. Use `default` (or a case list like `case .red, .yellow:`) only when several cases really share the same behavior and should keep sharing it for any case added later.

## Raw values

Often each case corresponds to a fixed value from the outside world: a code in a file, a number in a database, a key in JSON. Declare a **raw type** after the enum's name, and each case gets a **raw value**:

```swift
enum Coin: Int {
    case penny = 1
    case nickel = 5
    case dime = 10
    case quarter = 25
}

let coin = Coin.dime
print(coin.rawValue)

let pocket: [Coin] = [.quarter, .quarter, .dime, .penny]
let totalCents = pocket.reduce(0) { total, coin in total + coin.rawValue }
print(totalCents)
```

```output
10
61
```

`enum Coin: Int` says every case has an `Int` raw value, and `.rawValue` reads it. Raw values are constants fixed in the declaration: every `.dime` has raw value 10, always, and two cases can't share one (`raw value for enum case is not unique`). The raw type can be `String`, `Character`, or any integer or floating-point type.

### Implicit raw values

You don't always have to write them. With `String`, each case's raw value defaults to its name. With `Int`, the first case defaults to 0 and each next one is the previous plus 1:

```swift
enum Weekday: String {
    case monday, tuesday, wednesday
    case saturday = "sat"
}

enum Priority: Int {
    case low, medium, high
}

enum HTTPStatus: Int {
    case ok = 200, created
    case notFound = 404
}

print(Weekday.tuesday.rawValue)
print(Weekday.saturday.rawValue)
print(Priority.low.rawValue, Priority.high.rawValue)
print(HTTPStatus.created.rawValue)
```

```output
tuesday
sat
0 2
201
```

`created` follows `ok = 200`, so it's 201. Implicit values are convenient, but if raw values are stored in a file or sent to a server, write them out explicitly. Otherwise, renaming a case or inserting one in the middle silently changes the stored data's meaning.

### From a raw value back to a case

Data from outside arrives as plain text or numbers. Swift generates a **failable initializer** for every enum with raw values, `init?(rawValue:)`, which you met the idea of in lesson 3:

```swift
enum Size: String {
    case small = "S"
    case medium = "M"
    case large = "L"
}

for code in ["M", "L", "XL", "s"] {
    if let size = Size(rawValue: code) {
        print("\(code) -> \(size)")
    } else {
        print("\(code) -> unknown size")
    }
}
```

```output
M -> medium
L -> large
XL -> unknown size
s -> unknown size
```

`Size(rawValue: "XL")` returns `nil` because no case has that raw value, and `"s"` fails because the comparison is exact. It's the Module 8 pattern again: parse at the edge of the program, get an optional, unwrap it once, and from then on you're working with a `Size` that can only be one of three cases.

## CaseIterable

Add **`CaseIterable`** after the name (with a comma if there's a raw type), and Swift generates **`allCases`**, an array of every case in declaration order:

```swift
enum Coffee: String, CaseIterable {
    case espresso, latte, cappuccino, mocha
}

print("We have \(Coffee.allCases.count) drinks:")
for drink in Coffee.allCases {
    print("- \(drink.rawValue)")
}
```

```output
We have 4 drinks:
- espresso
- latte
- cappuccino
- mocha
```

`allCases` is a type property (lesson 4). It's how you build a menu or a picker that stays in sync with the enum: add a drink, and it appears everywhere you looped over `allCases`. `CaseIterable` is a **protocol**, a list of requirements a type can declare it meets; `Equatable` from lesson 1 is another. Module 10 explains protocols. For now, both are switches you flip to get code generated.

## Methods and computed properties on enums

Enums can have computed properties, methods, static members and initializers, just like structs. Inside them, **`self` is the current case**, so the body is usually a `switch self`:

```swift
enum TrafficLight: CaseIterable {
    case red, yellow, green

    var instruction: String {
        switch self {
        case .red:
            return "Stop"
        case .yellow:
            return "Slow down"
        case .green:
            return "Go"
        }
    }

    var secondsToWait: Int {
        switch self {
        case .red:
            return 30
        case .yellow:
            return 3
        case .green:
            return 0
        }
    }

    mutating func advance() {
        switch self {
        case .red:
            self = .green
        case .green:
            self = .yellow
        case .yellow:
            self = .red
        }
    }
}

var light = TrafficLight.red
for _ in 1...4 {
    print("\(light): \(light.instruction), wait \(light.secondsToWait)s")
    light.advance()
}
```

```output
red: Stop, wait 30s
green: Go, wait 0s
yellow: Slow down, wait 3s
red: Stop, wait 30s
```

1. `instruction` and `secondsToWait` are computed properties that switch over `self`. Each is exhaustive, so adding a case later forces you to give it an instruction and a wait time.
2. `advance()` is `mutating` because it changes the value, and an enum's whole value is its case. Assigning `self = .green` switches the light to another case. As with structs, only a `var` can call it.
3. `for _ in 1...4` repeats four times; the `_` says the counter itself isn't needed.

What enums can't have is **stored** instance properties. Each case is the entire value, so there's nowhere to keep extra data per instance; Swift 6.3 reports `enums must not contain stored properties`. When a case needs to carry data, you use associated values, in the next lesson.

## A practical example: parsing commands

Remember the calculator in Module 8 that compared `command.name == "add"` and trusted its `else` to mean subtract? With an enum, the set of operations is a type, and the compiler checks every place that uses it:

```swift
enum Operation: String, CaseIterable {
    case add, subtract, multiply

    var symbol: String {
        switch self {
        case .add:
            return "+"
        case .subtract:
            return "-"
        case .multiply:
            return "x"
        }
    }

    func apply(_ left: Int, _ right: Int) -> Int {
        switch self {
        case .add:
            return left + right
        case .subtract:
            return left - right
        case .multiply:
            return left * right
        }
    }
}

let commands = ["add 5", "multiply 3", "divide 2", "subtract 4"]
var total = 1

for line in commands {
    let parts = line.split(separator: " ")
    guard parts.count == 2,
          let operation = Operation(rawValue: String(parts[0])),
          let amount = Int(parts[1]) else {
        print("Skipping \"\(line)\"")
        continue
    }
    let result = operation.apply(total, amount)
    print("\(total) \(operation.symbol) \(amount) = \(result)")
    total = result
}

let names = Operation.allCases.map { operation in operation.rawValue }
print("Supported: \(names.joined(separator: ", "))")
```

```output
1 + 5 = 6
6 x 3 = 18
Skipping "divide 2"
18 - 4 = 14
Supported: add, subtract, multiply
```

The text becomes an `Operation` in one place, `Operation(rawValue:)`, and an unknown name fails there. After that, `apply` can't be called with an operation that doesn't exist, and adding `case divide` would make the compiler send you to `symbol` and `apply` to finish the job. The "Supported" line comes from `allCases`, so it can't fall out of date.

## Common mistakes

> [!error] error: switch must be exhaustive
> A case is missing. Read the notes: Swift 6.3 names each missing case (`add missing case: '.yellow'`). Handle them rather than reaching for `default`.

> [!warning] Adding default to a switch over your own enum
> It compiles, but the next case you add will silently go to `default` instead of making the compiler point you to this switch. If all cases are listed, Swift 6.3 warns `default will never be executed`.

```swift warning default will never be executed
enum TrafficLight {
    case red, yellow, green
}

let light = TrafficLight.red
switch light {
case .red:
    print("Stop")
case .yellow:
    print("Slow down")
case .green:
    print("Go")
default:
    print("Unknown light")
}
```

```output
Stop
```

> [!error] error: reference to member 'north' cannot be resolved without a contextual type
> `.north` alone needs Swift to know the expected type. Write `Direction.north`, or add a type annotation.

> [!error] error: cannot convert value of type 'String' to specified type 'Size'
> A raw value isn't a case. `let size: Size = "M"` doesn't compile; write `Size(rawValue: "M")` and unwrap the optional, or use the case directly: `.medium`.

```swift no-compile cannot convert value of type 'String' to specified type 'Size'
enum Size: String {
    case small = "S", medium = "M", large = "L"
}

let size: Size = "M"
```

> [!warning] Relying on implicit raw values for stored data
> If raw values end up in a file or on a server, write them explicitly. Reordering or renaming cases otherwise changes what saved data means.

````exercise
id: m09-l05-e1
type: comprehension
prompt: "An app stores a user's subscription as `var plan: String` with values `\"free\"`, `\"pro\"` and `\"team\"`. What's the main benefit of changing it to `enum Plan { case free, pro, team }`?"
choices:
  - text: The enum uses less memory than a String.
    correct: false
    why: "It probably does, but that's not why you'd make the change."
  - text: "Invalid values like \"prp\" become impossible, and switches over the plan can be checked for completeness by the compiler."
    correct: true
    why: "A Plan can only be one of three cases, and a switch without default must handle all of them."
  - text: The enum can be printed, and a String can't.
    correct: false
    why: Both print fine.
  - text: An enum's cases can be changed at runtime.
    correct: false
    why: The list of cases is fixed in the declaration.
solution: |
  **Invalid values become impossible, and switches are checked.** With a `String`, `"prp"`, `"Pro"` and `""` are all valid strings, and every `switch` needs a `default` for them. With `Plan`, the type system rules them out, and when you add `case enterprise`, the compiler lists every switch that needs updating. If the plan has to be saved as text, give it `String` raw values.
````

````exercise
id: m09-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum Floor: Int, CaseIterable {
      case basement = -1
      case ground
      case first
      case second = 5
      case third
  }

  print(Floor.ground.rawValue)
  print(Floor.third.rawValue)
  print(Floor(rawValue: 1) ?? .basement)
  print(Floor(rawValue: 2) ?? .basement)
  print(Floor.allCases.count)
output: |
  0
  6
  first
  basement
  5
hints:
  - "An implicit Int raw value is the previous case's raw value plus 1."
  - No case has raw value 2.
solution: |
  ```output
  0
  6
  first
  basement
  5
  ```

  `basement` is −1, so `ground` is 0 and `first` is 1. `second` is set to 5, so `third` is 6. `Floor(rawValue: 1)` is `.first`, which prints as `first`. `Floor(rawValue: 2)` is `nil`, so `??` gives `.basement`. `allCases` has all five cases.
````

````exercise
id: m09-l05-e3
type: fill-in
prompt: "Complete the enum so the program prints `🌧 Rainy: take an umbrella` and then `3 conditions`."
code: |
  enum Weather: [[1]] {
      case sunny, rainy, snowy

      var advice: String {
          switch [[2]] {
          case .sunny:
              return "wear sunscreen"
          case .rainy:
              return "take an umbrella"
          case [[3]]:
              return "wear boots"
          }
      }
  }

  let today = Weather.rainy
  print("🌧 Rainy: \(today.advice)")
  print("\(Weather.[[4]].count) conditions")
blanks:
  - id: "1"
    answers: [CaseIterable]
  - id: "2"
    answers: [self]
  - id: "3"
    answers: [.snowy, Weather.snowy]
  - id: "4"
    answers: [allCases]
solution: |
  ```swift
  enum Weather: CaseIterable {
      case sunny, rainy, snowy

      var advice: String {
          switch self {
          case .sunny:
              return "wear sunscreen"
          case .rainy:
              return "take an umbrella"
          case .snowy:
              return "wear boots"
          }
      }
  }

  let today = Weather.rainy
  print("🌧 Rainy: \(today.advice)")
  print("\(Weather.allCases.count) conditions")
  ```

  ```output
  🌧 Rainy: take an umbrella
  3 conditions
  ```

  `CaseIterable` generates `allCases`. Inside a computed property of an enum, `self` is the current case, and the switch lists all three, so no `default` is needed.
````

````exercise
id: m09-l05-e4
type: find-errors
prompt: "Which statements about this code are true?"
code: |
  enum Suit: String {
      case hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠"
      var color = "red"

      var isRed: Bool {
          switch self {
          case .hearts, .diamonds:
              return true
          default:
              return false
          }
      }
  }

  let favorite = .spades
  let parsed: Suit = "♣"
choices:
  - text: "var color = \"red\" doesn't compile: enums can't have stored instance properties."
    correct: true
    why: "Swift 6.3: enums must not contain stored properties."
  - text: "let favorite = .spades doesn't compile because Swift can't tell which type .spades belongs to."
    correct: true
    why: "The short form needs a known type. Write Suit.spades or annotate the constant."
  - text: "let parsed: Suit = \"♣\" doesn't compile; a raw value isn't a case."
    correct: true
    why: "Use Suit(rawValue: \"♣\"), which returns a Suit?."
  - text: "The default in isRed doesn't compile because enums can't use default."
    correct: false
    why: "default is allowed. It's legal here, but it means a future suit would silently be treated as black."
rubric:
  - I found the stored property, the missing contextual type and the raw value assignment.
  - I said default is legal but hides future cases.
solution: |
  Three compile errors: the stored property, `.spades` without a type, and assigning a raw value directly. The `default` compiles. Whether it's a good idea is a judgment call: with four suits that will never change, `case .clubs, .spades: return false` is just as short and safer.

  ```swift
  enum Suit: String {
      case hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠"

      var isRed: Bool {
          switch self {
          case .hearts, .diamonds:
              return true
          case .clubs, .spades:
              return false
          }
      }
  }

  let favorite = Suit.spades
  if let parsed = Suit(rawValue: "♣") {
      print(parsed, parsed.isRed)
  }
  print(favorite.rawValue, favorite.isRed)
  ```

  ```output
  clubs false
  ♠ false
  ```
````

````exercise
id: m09-l05-e5
type: solve
prompt: |
  Write `enum Planet: String, CaseIterable` with the cases `mercury`, `venus`, `earth` and `mars`, and a computed property `gravity: Double` with these values (relative to Earth): 0.38, 0.91, 1.0, 0.38.

  Then write `func weight(_ kilograms: Double, on planetName: String) -> String` that converts the name with `init?(rawValue:)` and returns either `"On mars you'd weigh 26.6 kg"` or `"Unknown planet: pluto"`. Round to one decimal with `(value * 10).rounded() / 10`.

  Finally, print every planet's name, and the results for 70 kg on `"mars"` and `"pluto"`:

  ```output
  mercury venus earth mars
  On mars you'd weigh 26.6 kg
  Unknown planet: pluto
  ```
starter: |
  enum Planet: String, CaseIterable {
      // cases and gravity
  }

  func weight(_ kilograms: Double, on planetName: String) -> String {
      // your code
  }
hints:
  - "guard let planet = Planet(rawValue: planetName) else { return \"Unknown planet: \\(planetName)\" }"
  - "Planet.allCases.map { planet in planet.rawValue }.joined(separator: \" \") builds the first line."
rubric:
  - gravity is a computed property with an exhaustive switch and no default.
  - weight converts the name with init?(rawValue:) and handles nil.
  - The planet list comes from allCases.
  - The output matches exactly.
solution: |
  ```swift
  enum Planet: String, CaseIterable {
      case mercury, venus, earth, mars

      var gravity: Double {
          switch self {
          case .mercury, .mars:
              return 0.38
          case .venus:
              return 0.91
          case .earth:
              return 1.0
          }
      }
  }

  func weight(_ kilograms: Double, on planetName: String) -> String {
      guard let planet = Planet(rawValue: planetName) else {
          return "Unknown planet: \(planetName)"
      }
      let result = (kilograms * planet.gravity * 10).rounded() / 10
      return "On \(planet.rawValue) you'd weigh \(result) kg"
  }

  print(Planet.allCases.map { planet in planet.rawValue }.joined(separator: " "))
  print(weight(70, on: "mars"))
  print(weight(70, on: "pluto"))
  ```

  ```output
  mercury venus earth mars
  On mars you'd weigh 26.6 kg
  Unknown planet: pluto
  ```

  70 × 0.38 = 26.6. Grouping `.mercury, .mars` in one case is fine here because they genuinely share a value; it's still exhaustive without `default`, so adding `jupiter` would make the compiler ask for its gravity.
````

````exercise
id: m09-l05-e6
type: refactor
prompt: |
  This function uses an `Int` for the status of an order (0 = placed, 1 = shipped, 2 = delivered) and a `default` to catch everything else. Refactor it to use `enum OrderStatus: Int` with a computed `message` property, keeping the same output for the valid codes and printing `Unknown status 7` for the invalid one.
code: |
  func statusMessage(_ status: Int) -> String {
      switch status {
      case 0:
          return "Order placed"
      case 1:
          return "On its way"
      case 2:
          return "Delivered"
      default:
          return "???"
      }
  }

  for code in [0, 2, 7] {
      print(statusMessage(code))
  }
rubric:
  - OrderStatus has Int raw values matching the old codes, written explicitly.
  - message is a computed property with an exhaustive switch and no default.
  - The Int is converted with init?(rawValue:) and the failure is reported.
  - The output matches.
solution: |
  ```swift
  enum OrderStatus: Int {
      case placed = 0
      case shipped = 1
      case delivered = 2

      var message: String {
          switch self {
          case .placed:
              return "Order placed"
          case .shipped:
              return "On its way"
          case .delivered:
              return "Delivered"
          }
      }
  }

  for code in [0, 2, 7] {
      if let status = OrderStatus(rawValue: code) {
          print(status.message)
      } else {
          print("Unknown status \(code)")
      }
  }
  ```

  ```output
  Order placed
  Delivered
  Unknown status 7
  ```

  The raw values are written out because they come from outside the program (a database or a server); reordering the cases mustn't change them. The `"???"` default is gone: invalid codes are rejected once, at the conversion, and inside the program a status can only be one of three cases.
````

## Summary

- An `enum` declares a type with a fixed list of `case`s. A value is always exactly one of them.
- Write `.case` without the type name when Swift knows the expected type.
- A `switch` over an enum can list every case and skip `default`. Keep it that way: then adding a case makes the compiler find every switch to update.
- `enum Name: String` or `: Int` gives each case a **raw value**, read with `.rawValue`. String raw values default to the case name; Int ones count up from 0 or from the previous value.
- `init?(rawValue:)` turns outside data into a case, or `nil`.
- `CaseIterable` generates `allCases`, every case in declaration order.
- Enums can have computed properties, methods and `mutating` methods that switch over `self` or assign a new case to it, but no stored instance properties.
