---
id: m09-l04
title: "mutating methods and type members"
description: You learn why a struct's methods can't change it by default, mark the ones that do with mutating, see why let instances and loop constants can't call them, add static properties and methods that belong to the type itself, group constants in a namespace, and nest types inside other types.
module: m09
order: 4
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l03]
objectives:
  - Explain why a struct method can't change the instance unless it's marked mutating.
  - Write mutating methods, including ones that replace self entirely.
  - Predict where a mutating method can be called and fix the errors where it can't.
  - Declare static properties and methods, and use them from inside and outside the type.
  - Group related constants in a caseless enum, and nest a type inside another when it only makes sense there.
terms:
  - term: mutating method
    definition: "A struct or enum method marked mutating. It's allowed to change the instance's stored properties, or replace self, and can only be called on a variable."
  - term: Type property
    definition: "A property declared with static. It belongs to the type, not to any instance, so there's exactly one, read as TypeName.property."
  - term: Type method
    definition: "A method declared with static. You call it on the type, as in Temperature.fromText(\"21\"), not on an instance."
  - term: Self
    definition: "With a capital S, inside a type: the type itself. Self.maxLength reads a static property from an instance method."
  - term: Namespace
    definition: "A name that groups related declarations, like Layout.padding and Layout.cornerRadius. A caseless enum is the usual way to make one in Swift."
  - term: Nested type
    definition: "A type declared inside another type. Outside, you refer to it with both names, like Order.Line."
mastery:
  - Add mutating to a method that changes a property, and say why the compiler requires it.
  - Fix "cannot use mutating member on immutable value" for a let constant and for a for-in loop constant.
  - Choose between a mutating method and a method that returns a changed copy, and name them accordingly.
  - Write a static let constant and a static factory method, and read them with the type's name or Self.
  - Nest a helper type inside the type that uses it.
resources: [swift-book-methods, swift-book-properties, swift-book-structures-classes, swift-book-enumerations]
cards:
  - id: m09-l04-c1
    front: Why does a struct method need mutating to change a property?
    back: "A struct is a value, and by default a method gets self as a constant. mutating makes self a variable for that method, and tells callers the method changes the value."
  - id: m09-l04-c2
    front: "Why does for player in players { player.addPoints(1) } fail when addPoints is mutating?"
    back: "The loop constant player is a let copy of each element. Loop over players.indices and call players[index].addPoints(1) to change the array's elements."
  - id: m09-l04-c3
    front: What's the difference between a static property and an instance property?
    back: "An instance property has one value per instance. A static property has one value for the whole type, read as TypeName.property (or Self.property inside the type)."
  - id: m09-l04-c4
    front: Why can't you declare static var count = 0 in a struct in Swift 6?
    back: "It's global mutable state that any thread could change. Swift 6.3 rejects it as not concurrency-safe. Use static let for constants; shared mutable state needs the tools in the concurrency module."
  - id: m09-l04-c5
    front: Why use a caseless enum instead of a struct for a group of constants?
    back: "An enum with no cases can't be instantiated, so Layout() is a compile error. The type exists only as a namespace for its static members."
---

## The idea in one sentence

A struct's methods can only change the struct if you mark them `mutating`, and some properties and methods belong to the type as a whole rather than to one instance: those are `static`.

## Methods can't change a struct by default

Here's a counter with a method that tries to add one:

```swift no-compile left side of mutating operator isn't mutable: 'self' is immutable
struct Counter {
    var count = 0

    func increment() {
        count += 1
    }
}
```

Swift 6.3 says `error: left side of mutating operator isn't mutable: 'self' is immutable`, and adds a note: `mark method 'mutating' to make 'self' mutable`.

The reason: a struct is a **value**, like an `Int`. Changing one property changes the whole value. Inside an ordinary method, `self` is a constant, the way a function parameter is a constant (Module 6). Methods that only read, like `area` or `summary()`, are fine with that. A method that changes the value has to say so.

## mutating

```swift
struct Counter {
    var count = 0

    mutating func increment() {
        count += 1
    }

    mutating func increment(by amount: Int) {
        count += amount
    }

    mutating func reset() {
        self = Counter()
    }
}

var taps = Counter()
taps.increment()
taps.increment()
taps.increment(by: 10)
print(taps.count)

taps.reset()
print(taps.count)
```

```output
12
0
```

1. `mutating func increment()` makes `self` a variable inside that method, so `count += 1` compiles.
2. `increment(by:)` is a second method with the same base name and a different label, exactly like overloaded functions.
3. `reset()` assigns a brand-new value to `self`. Only a `mutating` method can do that. It's the clearest way to say "go back to the starting state", and it keeps working if you add properties later.

The keyword isn't bureaucracy. It's documentation the compiler enforces: reading a type's declarations tells you exactly which methods can change it.

### Only variables can call mutating methods

A `mutating` method changes the value it's called on, so that value must be a variable:

```swift no-compile cannot use mutating member on immutable value: 'taps' is a 'let' constant
struct Counter {
    var count = 0

    mutating func increment() {
        count += 1
    }
}

let taps = Counter()
taps.increment()
```

Swift 6.3: `error: cannot use mutating member on immutable value: 'taps' is a 'let' constant`. It's the same rule as lesson 1's "a `let` instance can't change its properties", applied to methods.

The trap that catches everyone is the `for`-`in` loop. The loop constant is a `let` **copy** of each element:

```swift no-compile cannot use mutating member on immutable value: 'counter' is a 'let' constant
struct Counter {
    var count = 0

    mutating func increment() {
        count += 1
    }
}

var counters = [Counter(), Counter()]
for counter in counters {
    counter.increment()
}
```

Even if Swift allowed it, you'd only be changing the copy, and the array wouldn't change. To change the elements, go through the array with an index:

```swift
struct Counter {
    var count = 0

    mutating func increment() {
        count += 1
    }
}

var counters = [Counter(), Counter(count: 5)]
for index in counters.indices {
    counters[index].increment()
}
counters[0].increment()

print(counters[0].count)
print(counters[1].count)
```

```output
2
6
```

`counters[index].increment()` calls the method on the element stored in the array, not on a copy. That works because `counters` is a `var`.

### Mutate in place or return a copy?

Module 7 showed `sort()` and `sorted()`: one changes the array, the other returns a new one. Your own types should offer the same choice where it makes sense, with the same naming convention: an imperative verb for the mutating version, a past participle or noun phrase for the one that returns a copy.

```swift
struct Point {
    var x: Double
    var y: Double

    mutating func move(byX deltaX: Double, y deltaY: Double) {
        x += deltaX
        y += deltaY
    }

    func moved(byX deltaX: Double, y deltaY: Double) -> Point {
        var copy = self
        copy.move(byX: deltaX, y: deltaY)
        return copy
    }
}

let start = Point(x: 0, y: 0)
let next = start.moved(byX: 3, y: 4)
print(start.x, start.y)
print(next.x, next.y)

var cursor = Point(x: 10, y: 10)
cursor.move(byX: -2, y: 5)
print(cursor.x, cursor.y)
```

```output
0.0 0.0
3.0 4.0
8.0 15.0
```

`moved(byX:y:)` isn't `mutating`, so it works on a `let` constant like `start`. Inside, `var copy = self` makes a copy (value semantics again), changes the copy with the mutating method, and returns it. The original is untouched.

## Type properties and type methods

Every property so far has belonged to an instance: each `Counter` has its own `count`. Sometimes a value belongs to the **type** as a whole: the maximum length of any username, the conversion factor between units. Declare it with **`static`**:

```swift
struct Username {
    static let minLength = 3
    static let maxLength = 15

    let text: String

    init?(_ text: String) {
        guard text.count >= Self.minLength && text.count <= Self.maxLength else {
            return nil
        }
        self.text = text
    }

    static func rules() -> String {
        return "Between \(minLength) and \(maxLength) characters."
    }
}

print(Username.maxLength)
print(Username.rules())
print(Username("al")?.text ?? "too short")
print(Username("christian")?.text ?? "invalid")
```

```output
15
Between 3 and 15 characters.
too short
christian
```

1. `static let minLength = 3` is a **type property**. There's one, shared by the whole type, and you read it through the type's name: `Username.maxLength`. It isn't stored in each instance and isn't part of any initializer.
2. Inside the type's instance methods and initializers, write **`Self.minLength`**: capital-S `Self` means "this type". `Username.minLength` works too, but `Self` survives renaming the type.
3. `static func rules()` is a **type method**. You call it on the type, `Username.rules()`, with no instance needed. Inside a static method, other static members can be used by their bare names, because there `self` is the type itself.

If you try to read a static property from an instance method without `Self.`, Swift 6.3 says `static member 'maxLength' cannot be used on instance of type 'Username'`.

### static let, not static var

In Swift 6, a stored `static var` is rejected:

```swift no-compile is not concurrency-safe because it is nonisolated global shared mutable state
struct Settings {
    static var maxItems = 10
}
```

The full message is `static property 'maxItems' is not concurrency-safe because it is nonisolated global shared mutable state`. A static stored property is a single value that any part of the program, on any thread, could change at the same moment, and Swift 6 refuses to compile code that could do that unchecked. The concurrency module covers the safe ways to share mutable state. For data-modeling purposes, the answer is almost always `static let`: constants are safe to share. A static **computed** property (`static var zero: Point { Point(x: 0, y: 0) }`) is fine, because it stores nothing.

### Factory methods and shared values

Two common uses of `static`: named values of the type, and alternative ways to create one.

```swift
struct Temperature {
    var celsius: Double

    static let freezing = Temperature(celsius: 0)
    static let boiling = Temperature(celsius: 100)

    static func fromText(_ text: String) -> Temperature? {
        guard let value = Double(text) else {
            return nil
        }
        return Temperature(celsius: value)
    }
}

let target = Temperature.boiling
print(target.celsius)
print(Temperature.fromText("21.5")?.celsius ?? -273)
print(Temperature.fromText("warm") == nil)
```

```output
100.0
21.5
true
```

`Temperature.boiling` reads like a value from the domain. The standard library does the same: `Int.max`, `Double.pi`. A static factory like `fromText` and a failable `init?(_ text:)` do the same job; prefer the initializer when it's simply "make one from this", and a static method when a name adds information.

## A namespace for constants

Apps have constants that don't belong to any instance: spacing, limits, keys. Group them as static properties of a type created only for that purpose. The idiomatic choice is an **enum with no cases**:

```swift
enum Layout {
    static let padding = 16
    static let cornerRadius = 22
    static let maxColumns = 3
}

print("Padding: \(Layout.padding), corners: \(Layout.cornerRadius)")
```

```output
Padding: 16, corners: 22
```

Enums are the next lesson. What matters here: an enum with no cases has no values at all, so nobody can create a pointless `Layout()`. Swift 6.3 says `'Layout' cannot be constructed because it has no accessible initializers`. With a struct, `Layout()` would compile and mean nothing.

## Nested types

A type can be declared inside another type. Do it when the inner type only makes sense as part of the outer one: a line of an order, a setting of a player.

```swift
struct Order {
    struct Line {
        let product: String
        let priceInCents: Int
        var quantity: Int

        var subtotal: Int {
            priceInCents * quantity
        }
    }

    var lines: [Line] = []

    var totalInCents: Int {
        lines.reduce(0) { total, line in total + line.subtotal }
    }

    mutating func add(_ product: String, priceInCents: Int) {
        for index in lines.indices {
            if lines[index].product == product {
                lines[index].quantity += 1
                return
            }
        }
        lines.append(Line(product: product, priceInCents: priceInCents, quantity: 1))
    }
}

var order = Order()
order.add("Coffee", priceInCents: 450)
order.add("Bagel", priceInCents: 305)
order.add("Coffee", priceInCents: 450)

for line in order.lines {
    print("\(line.quantity) x \(line.product)")
}
print("Total: \(order.totalInCents) cents")

let extra = Order.Line(product: "Juice", priceInCents: 600, quantity: 2)
print(extra.subtotal)
```

```output
2 x Coffee
1 x Bagel
Total: 1205 cents
1200
```

1. Inside `Order`, the nested type is just `Line`. Outside, its full name is `Order.Line`. The name `Line` alone would be too vague at the top level; nested, it's clear.
2. `add(_:priceInCents:)` is `mutating` because it changes `lines`. It increases the quantity if the product is already there, or appends a new line.
3. Changing `lines[index].quantity` goes through the array, not a copy, which is why the loop uses indexes instead of `for line in lines`.
4. `return` inside the loop ends the method early once the product is found, so the `append` only runs for new products.

## Common mistakes

> [!error] error: left side of mutating operator isn't mutable: 'self' is immutable
> A method changes a property but isn't marked `mutating`. Add the keyword. If you get `cannot assign to property: 'self' is immutable` instead, it's the same problem with `=`.

> [!error] error: cannot use mutating member on immutable value: '…' is a 'let' constant
> You called a `mutating` method on a `let` constant, or on the constant of a `for`-`in` loop. Use a `var`, or loop over `indices` and call the method through the array.

> [!error] error: static member '…' cannot be used on instance of type '…'
> Inside an instance method or initializer, write `Self.maxLength` (or the type's name), not plain `maxLength`.

> [!error] error: static property '…' is not concurrency-safe
> A stored `static var` is shared mutable state. Make it `static let`, or keep the changing value in an instance.

> [!warning] Mutating where a copy would be clearer
> If callers mostly need a new value and want to keep the old one, offer a non-mutating method that returns a copy (`moved`, `sorted`, `adding`). Don't force them to write `var copy = x` everywhere.

````exercise
id: m09-l04-e1
type: comprehension
prompt: "`struct Stopwatch` has `var elapsed = 0` and `mutating func tick() { elapsed += 1 }`. Which call compiles?"
choices:
  - text: "`let watch = Stopwatch(); watch.tick()`"
    correct: false
    why: A let constant can't call a mutating method.
  - text: "`var watches = [Stopwatch()]; for watch in watches { watch.tick() }`"
    correct: false
    why: The loop constant is a let copy of each element.
  - text: "`var watches = [Stopwatch()]; watches[0].tick()`"
    correct: true
    why: "watches is a var, and watches[0] refers to the element inside it, not a copy."
  - text: "`Stopwatch.tick()`"
    correct: false
    why: "tick is an instance method; you call it on a Stopwatch, not on the type."
solution: |
  **`watches[0].tick()`**. A mutating method needs something mutable to change: a `var`, or an element reached through a `var` array. A `let` constant and a loop constant are both immutable.
````

````exercise
id: m09-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Score {
      static let maximum = 10
      var points = 0

      mutating func add(_ amount: Int) {
          points = min(points + amount, Self.maximum)
      }

      func adding(_ amount: Int) -> Score {
          var copy = self
          copy.add(amount)
          return copy
      }
  }

  var home = Score()
  home.add(4)
  let preview = home.adding(9)
  home.add(3)

  print(home.points)
  print(preview.points)
  print(Score.maximum - home.points)
output: |
  7
  10
  3
hints:
  - adding returns a changed copy and leaves home alone.
  - "min caps the result at Score.maximum."
solution: |
  ```output
  7
  10
  3
  ```

  `home.add(4)` gives 4. `home.adding(9)` copies `home` (4), adds 9, caps at 10, and returns that copy as `preview`; `home` is still 4. Then `home.add(3)` makes it 7. Finally `Score.maximum - home.points` is 10 − 7 = 3.
````

````exercise
id: m09-l04-e3
type: fill-in
prompt: "Complete the program so it prints `Lights: on` and then `Lights: off`."
code: |
  struct Light {
      [[1]] let labelPrefix = "Lights: "
      var isOn = false

      [[2]] func toggle() {
          isOn.toggle()
      }

      var label: String {
          [[3]].labelPrefix + (isOn ? "on" : "off")
      }
  }

  [[4]] light = Light()
  light.toggle()
  print(light.label)
  light.toggle()
  print(light.label)
blanks:
  - id: "1"
    answers: [static]
  - id: "2"
    answers: [mutating]
  - id: "3"
    answers: [Self, Light]
  - id: "4"
    answers: [var]
solution: |
  ```swift
  struct Light {
      static let labelPrefix = "Lights: "
      var isOn = false

      mutating func toggle() {
          isOn.toggle()
      }

      var label: String {
          Self.labelPrefix + (isOn ? "on" : "off")
      }
  }

  var light = Light()
  light.toggle()
  print(light.label)
  light.toggle()
  print(light.label)
  ```

  ```output
  Lights: on
  Lights: off
  ```

  `isOn.toggle()` is a mutating method of `Bool` that flips it, so `toggle()` on `Light` must be `mutating` too, and `light` must be a `var`. `labelPrefix` is the same for every light, so it's `static`, and the computed property reaches it through `Self` (or `Light`).
````

````exercise
id: m09-l04-e4
type: find-errors
prompt: "This inventory should restock every product below 5 units to 20. Which statements are true?"
code: |
  struct Product {
      static var restockLevel = 20
      let name: String
      var stock: Int

      func restock() {
          if stock < 5 {
              stock = restockLevel
          }
      }
  }

  var products = [Product(name: "Pens", stock: 2), Product(name: "Paper", stock: 40)]
  for product in products {
      product.restock()
  }
choices:
  - text: "restock() must be mutating because it assigns to stock."
    correct: true
    why: "Without mutating, self is immutable inside the method."
  - text: "Inside restock(), restockLevel must be written Self.restockLevel."
    correct: true
    why: "A static member can't be read by its bare name from an instance method."
  - text: "static var restockLevel doesn't compile in Swift 6; it should be static let."
    correct: true
    why: "A stored static var is global mutable state, which Swift 6 rejects."
  - text: "The for-in loop can't call a mutating method on product, and wouldn't change the array if it could."
    correct: true
    why: The loop constant is a let copy. Loop over indices instead.
  - text: "Product needs a custom initializer because it has a static property."
    correct: false
    why: "Static properties aren't part of the memberwise initializer, which still takes name and stock."
rubric:
  - I found all four real problems.
  - I fixed the loop by going through products.indices.
solution: |
  Four real problems. Fixed:

  ```swift
  struct Product {
      static let restockLevel = 20
      let name: String
      var stock: Int

      mutating func restock() {
          if stock < 5 {
              stock = Self.restockLevel
          }
      }
  }

  var products = [Product(name: "Pens", stock: 2), Product(name: "Paper", stock: 40)]
  for index in products.indices {
      products[index].restock()
  }
  for product in products {
      print("\(product.name): \(product.stock)")
  }
  ```

  ```output
  Pens: 20
  Paper: 40
  ```

  The second loop is fine as a plain `for product in products`, because it only reads.
````

````exercise
id: m09-l04-e5
type: solve
prompt: |
  Write a `struct Inventory` with a nested `struct Item` (`name: String`, `quantity: Int`) and:

  - `var items: [Item] = []`,
  - `static let lowStockThreshold = 3`,
  - `mutating func receive(_ name: String, quantity: Int)`, which adds to an existing item's quantity or appends a new item,
  - `mutating func sell(_ name: String) -> Bool`, which removes one unit and returns `true`, or returns `false` if the item doesn't exist or has 0 units,
  - a computed `lowStock: [String]`, the names of items whose quantity is below the threshold.

  Then run:

  ```swift illustrative
  var shop = Inventory()
  shop.receive("Apples", quantity: 5)
  shop.receive("Pears", quantity: 2)
  shop.receive("Apples", quantity: 1)
  print(shop.sell("Apples"), shop.sell("Kiwis"), shop.sell("Pears"))
  print(shop.lowStock)
  for item in shop.items {
      print(item.name, item.quantity)
  }
  ```

  Expected output:

  ```output
  true false true
  ["Pears"]
  Apples 5
  Pears 1
  ```
starter: |
  struct Inventory {
      struct Item {
          // properties
      }

      // items, threshold, receive, sell, lowStock
  }
hints:
  - "Find an existing item by looping over items.indices and checking items[index].name == name."
  - Return early from the loop once you've found the item.
  - "lowStock: items.filter { … }.map { … }"
rubric:
  - Item is nested inside Inventory.
  - receive and sell are mutating; sell returns false in both failure cases.
  - The threshold is a static let read with Self.
  - lowStock is computed, not stored.
  - The output matches exactly.
solution: |
  ```swift
  struct Inventory {
      struct Item {
          let name: String
          var quantity: Int
      }

      static let lowStockThreshold = 3
      var items: [Item] = []

      mutating func receive(_ name: String, quantity: Int) {
          for index in items.indices {
              if items[index].name == name {
                  items[index].quantity += quantity
                  return
              }
          }
          items.append(Item(name: name, quantity: quantity))
      }

      mutating func sell(_ name: String) -> Bool {
          for index in items.indices {
              if items[index].name == name {
                  guard items[index].quantity > 0 else {
                      return false
                  }
                  items[index].quantity -= 1
                  return true
              }
          }
          return false
      }

      var lowStock: [String] {
          items.filter { item in item.quantity < Self.lowStockThreshold }.map { item in item.name }
      }
  }

  var shop = Inventory()
  shop.receive("Apples", quantity: 5)
  shop.receive("Pears", quantity: 2)
  shop.receive("Apples", quantity: 1)
  print(shop.sell("Apples"), shop.sell("Kiwis"), shop.sell("Pears"))
  print(shop.lowStock)
  for item in shop.items {
      print(item.name, item.quantity)
  }
  ```

  ```output
  true false true
  ["Pears"]
  Apples 5
  Pears 1
  ```

  Apples: 5 + 1 = 6, minus one sold = 5. Pears: 2, minus one = 1, which is below 3. Kiwis were never received, so `sell` falls out of the loop and returns `false`. `sell` returns a `Bool` instead of crashing or silently doing nothing, so the caller knows whether the sale happened.
````

````exercise
id: m09-l04-e6
type: explain
code: |
  struct Counter {
      var count = 0

      mutating func increment() {
          count += 1
      }
  }

  let taps = Counter()
  taps.increment()  // error
prompt: |
  Explain why Swift makes you write `mutating` on a struct method that changes a property, when other languages let any method change its object. What does the keyword tell a reader of the code, and what does it let the compiler check?
rubric:
  - I said that a struct is a value and that changing a property changes the whole value.
  - I said that self is a constant inside a non-mutating method, like a parameter.
  - I said the keyword marks which methods change the value, visible in the declaration.
  - I said the compiler uses it to forbid calling those methods on let constants (and loop constants).
solution: |
  A struct is a value, like an `Int`. Changing one of its properties creates a different value, so "this method changes the struct" means "this method replaces the value stored in the caller's variable". Swift makes that explicit. In a normal method, `self` is a constant, just as a function's parameters are, and `mutating` turns it into a variable for that one method.

  For a reader, the keyword splits a type's methods into the ones that only read and the ones that change it, without reading any bodies. For the compiler, it's what makes `let` meaningful: it can reject `taps.increment()` when `taps` is a `let`, or when it's a loop constant, because it knows `increment()` would change it. Without the marker, the compiler couldn't promise that a `let` struct never changes.

  In languages where objects are references (and in Swift's classes, Module 10), a method changes the shared object, not a value in your variable, so there's no equivalent keyword.
````

## Summary

- Inside a struct method, `self` is a constant. A method that changes a property, or assigns `self`, must be marked **`mutating`**.
- Only variables can call mutating methods: not `let` constants, not `for`-`in` loop constants. Loop over `indices` to change array elements.
- Offer a non-mutating version that returns a copy when callers need it, named like `sorted`/`sort`: `moved` and `move`.
- **`static`** properties and methods belong to the type: `Username.maxLength`, `Temperature.fromText("21")`. Inside the type, use `Self.`.
- Stored statics should be `static let`. Swift 6 rejects a stored `static var` as unsafe shared mutable state.
- A caseless `enum` with static constants is a namespace that can't be instantiated.
- Nest a type inside another when it only makes sense there. Outside, its name is `Outer.Inner`.
