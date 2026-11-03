---
id: m10-l04
title: Extensions and protocol extensions
description: You add methods, computed properties, initializers and conformances to your own types and to standard ones with extensions, give protocols default implementations, learn the static-dispatch trap with methods that live only in a protocol extension, and protect a type's data with Swift's access levels.
module: m10
order: 4
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l03]
objectives:
  - Add computed properties, methods, initializers and nested types to a type with an extension.
  - Extend a standard type such as Int or String.
  - Add a protocol conformance in an extension, including to a type you don't own.
  - Give a protocol requirement a default implementation in a protocol extension.
  - Predict which implementation runs for a method declared only in a protocol extension.
  - Choose an access level (private, fileprivate, internal, package, public, open) for a member and explain the choice.
terms:
  - term: Extension
    definition: "A block, extension TypeName { … }, that adds functionality to an existing type: methods, computed properties, initializers, nested types, conformances. It can't add stored properties."
  - term: Protocol extension
    definition: "An extension of a protocol, extension Shape { … }. Its methods and computed properties become available on every conforming type."
  - term: Default implementation
    definition: "An implementation of a protocol requirement written in a protocol extension. Conforming types use it unless they provide their own."
  - term: Retroactive conformance
    definition: "Making a type conform to a protocol in an extension, after the type was declared, possibly in another module."
  - term: Access control
    definition: "Keywords that limit which code can see a declaration: private, fileprivate, internal (the default), package, public and open."
  - term: Encapsulation
    definition: "Hiding a type's internal data behind a small set of operations, so the rest of the program can't put it into an invalid state."
mastery:
  - Add an initializer in an extension of a struct and keep the memberwise initializer.
  - Write an extension on Int or String with a computed property and use it.
  - Move a protocol conformance into its own extension.
  - Write a default implementation and override it in one conforming type.
  - Predict the output when a method exists only in a protocol extension and is called through any P and through the concrete type.
  - Make a balance readable but not writable from outside its type with private(set).
resources: [swift-book-extensions, swift-book-protocols, swift-book-access-control]
cards:
  - id: m10-l04-c1
    front: What can an extension add, and what can't it?
    back: "It can add computed properties, methods, initializers, subscripts, nested types and protocol conformances. It can't add stored properties: \"extensions must not contain stored properties\"."
  - id: m10-l04-c2
    front: Why put a struct's custom init in an extension?
    back: "An init written inside the struct removes the memberwise init. One written in an extension doesn't, so you keep both."
  - id: m10-l04-c3
    front: "A method is in a protocol extension but not in the protocol. A conforming type has its own version. What runs for value.method() when value is any P?"
    back: "The extension's version. Non-requirement methods are dispatched statically, by the declared type. Only requirements go through the witness table to the type's own version."
  - id: m10-l04-c4
    front: "private vs fileprivate vs internal?"
    back: "private: the enclosing declaration and its extensions in the same file. fileprivate: anywhere in the same file. internal (default): anywhere in the same module."
  - id: m10-l04-c5
    front: "package, public and open?"
    back: "package: any module in the same Swift package (Swift 5.9). public: any module that imports yours. open: like public, and other modules can also subclass and override it (classes only)."
---

## The idea in one sentence

An extension adds behavior to a type that already exists, yours or the standard library's, and a protocol extension adds behavior to **every** type that conforms.

## Extending your own types

```swift
struct Temperature {
    var celsius: Double
}

extension Temperature {
    init(fahrenheit: Double) {
        self.celsius = (fahrenheit - 32) * 5 / 9
    }

    var fahrenheit: Double {
        celsius * 9 / 5 + 32
    }

    func isWarmer(than other: Temperature) -> Bool {
        celsius > other.celsius
    }
}

let room = Temperature(celsius: 20)
let boiling = Temperature(fahrenheit: 212)
print(room.fahrenheit)
print(boiling.celsius)
print(boiling.isWarmer(than: room))
```

```output
68.0
100.0
true
```

1. `extension Temperature { … }` reopens the type. Everything inside becomes part of `Temperature`, as if written in the original braces.
2. The extension adds an initializer, a computed property and a method.
3. `Temperature(celsius: 20)` still works. In Module 9 you saw that writing your own `init` inside a struct removes the memberwise initializer. An `init` written **in an extension** doesn't, so you get both.

Extensions can add computed properties, methods (including `mutating` ones), initializers, subscripts, nested types and protocol conformances. They **can't add stored properties**, because that would change the size and layout of a type that's already been defined:

```swift no-compile extensions must not contain stored properties
struct Temperature {
    var celsius: Double
}

extension Temperature {
    var label = "room"
}
```

## Extending standard types

You can extend types you didn't write, including `Int`, `String` and `Array`:

```swift
extension Int {
    var isEven: Bool {
        self % 2 == 0
    }

    func repeated(_ text: String) -> String {
        String(repeating: text, count: self)
    }
}

extension String {
    var initials: String {
        var result = ""
        for word in split(separator: " ") {
            if let first = word.first {
                result.append(first)
            }
        }
        return result.uppercased()
    }
}

print(4.isEven, 7.isEven)
print(3.repeated("ab"))
print("christian de la cruz".initials)
```

```output
true false
ababab
CDLC
```

Inside the extension, `self` is the integer or the string the member was called on. `split(separator:)` and `first` are standard `String` members; `split` gives the words.

Extend standard types sparingly, and only with things that are true of **every** value of the type. `isEven` makes sense for any `Int`. A `String.isValidCouponCode` doesn't: most strings aren't coupons, and that logic belongs in a type about coupons.

## Conformances in extensions

You can declare a conformance in an extension instead of on the type itself:

```swift
struct Money {
    let cents: Int
}

extension Money: CustomStringConvertible {
    var description: String {
        let euros = cents / 100
        let rest = cents % 100
        return rest < 10 ? "\(euros).0\(rest) EUR" : "\(euros).\(rest) EUR"
    }
}

extension Money: Comparable {
    static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.cents < rhs.cents
    }
}

let prices = [Money(cents: 1250), Money(cents: 305), Money(cents: 99)]
print(prices.max() ?? Money(cents: 0))
print(Money(cents: 305))
```

```output
12.50 EUR
3.05 EUR
```

`CustomStringConvertible` is the standard protocol `print` and string interpolation use: conform, provide `description`, and your type prints however you like instead of as `Money(cents: 1250)`.

This is the usual way to organize Swift code: the type declaration holds the stored properties and the core init; **each conformance gets its own extension**, so a reader can see at a glance what a type can do, and everything related to `Comparable` sits together. Xcode's `// MARK: - Comparable` comments make those sections show up in the file's jump bar.

### Retroactive conformance

An extension can make a type conform to a protocol even when **you didn't write the type**. That's called retroactive conformance, and it's a big part of why protocols are so flexible: you can make `Int` work with a protocol you designed today.

```swift
protocol Scoreable {
    var points: Int { get }
}

extension Int: Scoreable {
    var points: Int {
        self
    }
}

extension String: Scoreable {
    var points: Int {
        count
    }
}

let entries: [any Scoreable] = [10, "swift", 3]
var total = 0
for entry in entries {
    total += entry.points
}
print(total)
```

```output
18
```

That's fine because `Scoreable` is yours. When **neither** the type nor the protocol is yours, Swift 6 warns:

```swift warning extension declares a conformance of imported type 'Int' to imported protocol 'Identifiable'
extension Int: Identifiable {
    public var id: Int {
        self
    }
}
print(42.id)
```

```output
42
```

`Identifiable` is a standard protocol (a type with a stable `id`; SwiftUI uses it a lot). The full Swift 6.3 warning is "extension declares a conformance of imported type 'Int' to imported protocol 'Identifiable'; this will not behave correctly if the owners of 'Swift' introduce this conformance in the future". If the standard library adds the same conformance one day, there would be two, and which one wins isn't defined. If you've thought about it and accept the risk, write `extension Int: @retroactive Identifiable` to say so and silence the warning. Usually the better fix is a wrapper type of your own.

## Protocol extensions

Extending a **protocol** adds members to every conforming type at once:

```swift
protocol Shape {
    var name: String { get }
    var area: Double { get }
}

extension Shape {
    func summary() -> String {
        "\(name): \(area)"
    }

    func isLarger(than other: any Shape) -> Bool {
        area > other.area
    }
}

struct Square: Shape {
    let side: Double
    var name: String { "square" }
    var area: Double { side * side }
}

struct Rectangle: Shape {
    let width: Double
    let height: Double
    var name: String { "rectangle" }
    var area: Double { width * height }
}

let square = Square(side: 3)
let rectangle = Rectangle(width: 2, height: 5)
print(square.summary())
print(rectangle.summary())
print(square.isLarger(than: rectangle))
```

```output
square: 9.0
rectangle: 10.0
false
```

`summary()` is written once, using only what the protocol guarantees (`name` and `area`), and both shapes have it. Any future shape gets it too. That's the core of **protocol-oriented programming**: put the shared behavior on the protocol instead of in a base class.

### Default implementations

If a protocol extension implements one of the protocol's **requirements**, that implementation becomes a **default**. Conforming types can skip it or provide their own:

```swift
protocol Greeter {
    var name: String { get }
    func greet() -> String
}

extension Greeter {
    func greet() -> String {
        "Hello, I'm \(name)"
    }
}

struct Neighbor: Greeter {
    let name: String
}

struct Butler: Greeter {
    let name: String
    func greet() -> String {
        "Good evening. \(name), at your service."
    }
}

let greeters: [any Greeter] = [Neighbor(name: "Ana"), Butler(name: "Alfred")]
for greeter in greeters {
    print(greeter.greet())
}
```

```output
Hello, I'm Ana
Good evening. Alfred, at your service.
```

`Neighbor` uses the default. `Butler` replaces it, with no `override` keyword: `override` is for classes. And through `any Greeter`, each value runs its own version. So far, so good.

## The static-dispatch trap

Now add a method to the protocol extension that **isn't a requirement**, and give one conforming type its own method with the same name:

```swift
protocol Greeter {
    var name: String { get }
    func greet() -> String
}

extension Greeter {
    func greet() -> String {
        "Hello, I'm \(name)"
    }

    func farewell() -> String {
        "Goodbye from \(name)"
    }
}

struct Butler: Greeter {
    let name: String

    func greet() -> String {
        "Good evening. \(name), at your service."
    }

    func farewell() -> String {
        "Will that be all? \(name) withdraws."
    }
}

let butler = Butler(name: "Alfred")
let someone: any Greeter = butler

print(butler.greet())
print(someone.greet())
print(butler.farewell())
print(someone.farewell())
```

```output
Good evening. Alfred, at your service.
Good evening. Alfred, at your service.
Will that be all? Alfred withdraws.
Goodbye from Alfred
```

The same instance, the same method name, two different results. Why?

- `greet()` is a **requirement**: it's declared in `protocol Greeter`. Every conformance has a witness table entry for it, pointing at the type's own implementation (or the default if the type has none). A call through `any Greeter` looks in that table and finds `Butler.greet()`. Dynamic dispatch.
- `farewell()` is **not** a requirement. It exists only in the extension, so the witness table has no entry for it. A call is resolved **at compile time, by the declared type**. Through `butler` (declared as `Butler`), the compiler sees `Butler.farewell()`. Through `someone` (declared as `any Greeter`), all it knows is the extension's `farewell()`, and that's what it calls. Static dispatch.

`Butler.farewell()` doesn't replace the extension's method; it just **hides** it when you're looking at a `Butler`. That's different from overriding a class method, and it's a classic source of "my method isn't being called" bugs.

**The fix:** if conforming types should be able to customize a method, declare it in the protocol. Add `func farewell() -> String` to `protocol Greeter`, keep the extension's body as the default, and both calls print the butler's line. Keep extension-only methods for helpers that are built from requirements and that no type should need to change, like `summary()` above.

## Encapsulation and access control

Encapsulation means a type keeps its data to itself and offers operations that keep that data valid. A bank account shouldn't let anyone set its balance to whatever they like; it should offer `deposit` and `withdraw` and enforce the rules there. Swift's tool for that is **access control**.

```swift
struct Account {
    let owner: String
    private(set) var balance = 0
    private var log: [String] = []

    init(owner: String) {
        self.owner = owner
    }

    mutating func deposit(_ amount: Int) {
        guard amount > 0 else {
            return
        }
        balance += amount
        record("+\(amount)")
    }

    mutating func withdraw(_ amount: Int) -> Bool {
        guard amount > 0 && amount <= balance else {
            return false
        }
        balance -= amount
        record("-\(amount)")
        return true
    }
}

extension Account {
    private mutating func record(_ entry: String) {
        log.append(entry)
    }

    var history: String {
        log.joined(separator: " ")
    }
}

var account = Account(owner: "Christian")
account.deposit(100)
print(account.withdraw(30))
print(account.withdraw(500))
print(account.balance)
print(account.history)
```

```output
true
false
70
+100 -30
```

- `private(set) var balance`: anyone can **read** it; only `Account`'s own code can **write** it. The rules in `deposit` and `withdraw` can't be bypassed.
- `private var log`: nobody outside the type can see it at all. The extension below can, because `private` covers the type's declaration **and its extensions in the same file**.
- `private mutating func record`: a helper that's nobody else's business.

From outside, the compiler holds the line:

```swift no-compile cannot assign to property: 'balance' setter is inaccessible
struct Account {
    private(set) var balance = 0
}

var account = Account()
account.balance = 1_000_000
```

```swift no-compile 'log' is inaccessible due to 'private' protection level
struct Account {
    private var log: [String] = []
}

let account = Account()
print(account.log)
```

### The six access levels

From most restrictive to most open:

| Level | Visible from |
| --- | --- |
| `private` | The enclosing declaration, and extensions of it in the same file |
| `fileprivate` | Anywhere in the same source file |
| `internal` | Anywhere in the same module (your app target, or one framework). **The default** when you write nothing |
| `package` | Any module in the same Swift package (Swift 5.9, SE-0386) |
| `public` | Any module that imports yours |
| `open` | Like `public`, and classes and members can also be subclassed and overridden from other modules |

A **module** is a unit of code that's built together: your app target is one, each framework or Swift package library is another. In a single-file program like the examples here, `fileprivate`, `internal` and everything above it all mean "visible everywhere", so only `private` makes a visible difference. The others start to matter when your app is split into several files and modules, which every real app is.

Practical defaults:

- Stored properties that hold internal state: `private`, or `private(set)` if others should read them.
- Helpers that only one type uses: `private`.
- Everything else in an app: leave it `internal`.
- In a library or package that other modules use: `public` for the API you promise to keep stable, `package` for things shared between your own modules but not with outsiders. `open` only for classes you've actually designed for subclassing.

## Common mistakes

> [!error] error: extensions must not contain stored properties
> Extensions can only add computed properties. Put the stored property in the type's declaration, or compute the value from existing properties.

> [!error] A "default" that's not a requirement
> You wrote a method in a protocol extension, gave a conforming type its own version, and the type's version doesn't run when called through `any P` (or from inside other protocol-extension code). Declare the method in the protocol.

> [!error] error: cannot assign to property: 'balance' setter is inaccessible
> The property is `private(set)`. Go through the type's methods, which exist to keep the value valid.

> [!error] Extending a standard type with app-specific logic
> `extension String { var isValidOrderID: Bool }` puts order rules on every string in the program. Make an `OrderID` type and put the rule there.

> [!warning] warning: extension declares a conformance of imported type … to imported protocol …
> Neither the type nor the protocol is yours. Prefer a wrapper type; use `@retroactive` only when you've accepted the risk.

````exercise
id: m10-l04-e1
type: comprehension
prompt: |
  ```swift
  struct Point {
      var x: Int
      var y: Int
  }

  extension Point {
      init(both value: Int) {
          self.init(x: value, y: value)
      }
  }
  ```

  Which of these lines compile?
multiple: true
choices:
  - text: "let a = Point(x: 1, y: 2)"
    correct: true
    why: An init written in an extension doesn't remove the memberwise init.
  - text: "let b = Point(both: 5)"
    correct: true
    why: That's the extension's init, which delegates to the memberwise one.
  - text: "extension Point { var z = 0 }"
    correct: false
    why: "Extensions can't add stored properties."
  - text: "extension Point { var sum: Int { x + y } }"
    correct: true
    why: Computed properties are fine in extensions.
solution: |
  **The first, second and fourth.** Putting extra initializers in an extension is the standard way to keep the memberwise init. Stored properties can't be added in an extension; computed ones can.
````

````exercise
id: m10-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  protocol Animal {
      var name: String { get }
      func sound() -> String
  }

  extension Animal {
      func sound() -> String {
          "..."
      }
      func introduce() -> String {
          "I am \(name) and I say \(sound())"
      }
      func emoji() -> String {
          "(animal)"
      }
  }

  struct Cat: Animal {
      let name = "Cat"
      func sound() -> String {
          "Meow"
      }
      func emoji() -> String {
          "(cat)"
      }
  }

  struct Fish: Animal {
      let name = "Fish"
  }

  let cat = Cat()
  let animals: [any Animal] = [cat, Fish()]
  for animal in animals {
      print(animal.introduce(), animal.emoji())
  }
  print(cat.emoji())
output: |
  I am Cat and I say Meow (animal)
  I am Fish and I say ... (animal)
  (cat)
hints:
  - "sound() is a requirement. emoji() isn't."
  - "Inside introduce(), sound() is called on self, and the call goes through the requirement."
solution: |
  ```output
  I am Cat and I say Meow (animal)
  I am Fish and I say ... (animal)
  (cat)
  ```

  `introduce()` lives only in the extension, but that's fine, because no type tries to replace it. Inside it, `sound()` is a requirement, so it dispatches to `Cat.sound()` for the cat and to the default for the fish. `emoji()` isn't a requirement: through `any Animal` the compiler picks the extension's version for both. Only the last line, where `cat` is declared as `Cat`, runs `Cat.emoji()`.
````

````exercise
id: m10-l04-e3
type: fill-in
prompt: |
  Complete the code so `Inventory`'s count can be read but not set from outside, and the conformance lives in its own extension. It should print `2 items`.
code: |
  struct Inventory {
      [[1]] var count = 0

      mutating func add() {
          count += 1
      }
  }

  [[2]] Inventory: CustomStringConvertible {
      var [[3]]: String {
          "\(count) items"
      }
  }

  var stock = Inventory()
  stock.add()
  stock.add()
  print(stock)
blanks:
  - id: "1"
    answers: ["private(set)"]
  - id: "2"
    answers: ["extension"]
  - id: "3"
    answers: ["description"]
solution: |
  ```swift
  struct Inventory {
      private(set) var count = 0

      mutating func add() {
          count += 1
      }
  }

  extension Inventory: CustomStringConvertible {
      var description: String {
          "\(count) items"
      }
  }

  var stock = Inventory()
  stock.add()
  stock.add()
  print(stock)
  ```

  ```output
  2 items
  ```

  `private(set)` keeps reads public and writes inside the type. `CustomStringConvertible` requires a `description` property, which `print` uses. Declaring the conformance in an extension keeps the type's core short.
````

````exercise
id: m10-l04-e4
type: solve
prompt: |
  Write a protocol `Describable` with a requirement `var title: String { get }`, and a protocol extension with:

  - a **default implementation** of a second requirement, `func headline() -> String`, that returns the title in uppercase,
  - a helper (not a requirement) `func banner() -> String` that returns `"*** "` + `headline()` + `" ***"`.

  Then `struct Article: Describable` that uses the default headline, and `struct Ad: Describable` that provides its own `headline()` returning `"Sponsored: "` + title.

  This must print:

  ```output
  *** SWIFT 6 IS HERE ***
  *** Sponsored: Learn iOS ***
  ```

  when you loop over `[Article(title: "Swift 6 is here"), Ad(title: "Learn iOS")]` as `[any Describable]` and print each `banner()`.
starter: |
  protocol Describable {
      // your code
  }
hints:
  - "headline() must be declared in the protocol too, or Ad's version won't run through any Describable."
  - "title.uppercased() gives the uppercase version."
rubric:
  - headline() is a protocol requirement with a default in the extension.
  - banner() is an extension-only helper built from headline().
  - Ad's headline() runs even when called through any Describable.
  - The output matches exactly.
solution: |
  ```swift
  protocol Describable {
      var title: String { get }
      func headline() -> String
  }

  extension Describable {
      func headline() -> String {
          title.uppercased()
      }

      func banner() -> String {
          "*** " + headline() + " ***"
      }
  }

  struct Article: Describable {
      let title: String
  }

  struct Ad: Describable {
      let title: String

      func headline() -> String {
          "Sponsored: " + title
      }
  }

  let items: [any Describable] = [Article(title: "Swift 6 is here"), Ad(title: "Learn iOS")]
  for item in items {
      print(item.banner())
  }
  ```

  ```output
  *** SWIFT 6 IS HERE ***
  *** Sponsored: Learn iOS ***
  ```

  The design point is which method is a requirement. `headline()` must be customizable, so it's declared in the protocol and the extension only provides a default. `banner()` is the same for everyone and is built from `headline()`, so it can live only in the extension. Had you left `headline()` out of the protocol, `banner()` would call the extension's version for the ad too, and print `*** LEARN IOS ***`.
````

````exercise
id: m10-l04-e5
type: find-errors
prompt: "A `Thermostat` must keep its target between 10 and 30. Pick out the real problems with this design."
code: |
  struct Thermostat {
      var target = 20
      var lastChange = ""

      mutating func set(_ value: Int) {
          guard value >= 10 && value <= 30 else {
              return
          }
          target = value
          lastChange = "set to \(value)"
      }
  }

  extension Thermostat {
      var history: [String] = []
  }

  var thermostat = Thermostat()
  thermostat.target = 99
choices:
  - text: "target is writable from outside, so set(_:)'s range check can be bypassed."
    correct: true
    why: "thermostat.target = 99 compiles and breaks the rule. It should be private(set)."
  - text: The extension adds a stored property.
    correct: true
    why: "extensions must not contain stored properties. Move history into the struct."
  - text: "lastChange should be private(set) too, so only set(_:) can write it."
    correct: true
    why: It's a record of what the type did; outside code shouldn't fake it.
  - text: "set(_:) needs to be public to be called from outside."
    correct: false
    why: "The default, internal, is visible to the whole module. public matters only for other modules."
rubric:
  - target and lastChange are private(set).
  - history moved into the struct declaration, or became computed.
  - The out-of-range assignment no longer compiles, and set(99) is ignored.
solution: |
  ```swift
  struct Thermostat {
      private(set) var target = 20
      private(set) var lastChange = ""
      private(set) var history: [String] = []

      mutating func set(_ value: Int) {
          guard value >= 10 && value <= 30 else {
              return
          }
          target = value
          lastChange = "set to \(value)"
          history.append(lastChange)
      }
  }

  var thermostat = Thermostat()
  thermostat.set(99)
  thermostat.set(22)
  print(thermostat.target, thermostat.history)
  ```

  ```output
  22 ["set to 22"]
  ```

  The type had the right rule in the wrong place: a check in `set(_:)` protects nothing if `target` can be assigned directly. `private(set)` makes the method the only way in. The stored property moved into the declaration, where stored properties have to live.
````

````exercise
id: m10-l04-e6
type: explain
prompt: |
  Explain, in your own words, why the two `print` lines output different text even though `report` holds the same value in both.
code: |
  protocol Report {
      var body: String { get }
  }

  extension Report {
      func export() -> String {
          "TXT: \(body)"
      }
  }

  struct PDFReport: Report {
      let body: String
      func export() -> String {
          "PDF: \(body)"
      }
  }

  let report = PDFReport(body: "Q3")
  let anyReport: any Report = report
  print(report.export())
  print(anyReport.export())
rubric:
  - Says export() isn't a protocol requirement, so it has no witness table entry.
  - Says the call is resolved at compile time from the declared type.
  - "Explains that PDFReport's export() hides the extension's method rather than overriding it."
  - Gives the fix, declaring export() in the protocol, and the resulting output.
solution: |
  `export()` isn't declared in `protocol Report`; it only exists in the extension. Calls to such methods are bound at compile time, using the declared type of the expression. `report` is declared as `PDFReport`, so the compiler picks `PDFReport.export()` and prints `PDF: Q3`. `anyReport` is declared as `any Report`, and all the compiler knows about `any Report` is the extension's method, so it prints `TXT: Q3`. `PDFReport`'s method hides the extension's one when you look at a `PDFReport`; it doesn't override it.

  Adding `func export() -> String` to the protocol makes it a requirement. Then each conformance has a witness table entry pointing at its own `export()`, the call through `any Report` finds `PDFReport`'s, and both lines print `PDF: Q3`.
````

## Summary

- An extension adds computed properties, methods, initializers, nested types and conformances to an existing type. It can't add stored properties.
- An `init` in a struct's extension keeps the memberwise initializer.
- Extend standard types only with things true of every value. Retroactive conformance of a type you don't own to a protocol you don't own triggers a warning; `@retroactive` acknowledges it.
- A protocol extension gives every conforming type its methods. An implementation of a requirement there is a default that types can replace.
- Methods that exist only in a protocol extension are dispatched statically, by the declared type. If types should customize a method, make it a requirement.
- Encapsulation: `private` and `private(set)` keep a type's data valid. The levels, from narrow to wide: `private`, `fileprivate`, `internal` (default), `package`, `public`, `open`.
