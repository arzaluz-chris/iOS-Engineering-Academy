---
id: m09-l01
title: "Structs: your own types"
description: You define your own types with struct, give them stored properties and methods, create instances with the memberwise initializer, read and change them with dot syntax, use self, and see that a struct is a value that gets copied, like the arrays in Module 7.
module: m09
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m08-l06]
objectives:
  - Explain why a program defines its own types instead of passing loose values and tuples around.
  - Declare a struct with stored properties and create instances with the memberwise initializer.
  - Read and change properties with dot syntax, and say when a change is allowed.
  - Write methods that use the instance's properties, and use self to tell a property from a parameter.
  - Predict that assigning a struct to another variable copies it.
terms:
  - term: Type
    definition: "A description of a kind of value: what data it holds and what you can do with it. Int, String and [Int] are types from the standard library; struct lets you write your own."
  - term: Struct
    definition: "A type you define with the struct keyword. It groups related values (its properties) and the functions that work on them (its methods). Structs are value types."
  - term: Instance
    definition: "One concrete value of a type. Book is a type; Book(title: \"Dune\", pages: 412) is an instance of it."
  - term: Stored property
    definition: "A constant (let) or variable (var) declared inside a type. Every instance stores its own value for it."
  - term: Memberwise initializer
    definition: "An initializer Swift writes for every struct automatically, with one parameter per stored property, in the order they're declared."
  - term: Method
    definition: "A function declared inside a type. It runs on a particular instance and can read that instance's properties."
  - term: self
    definition: "Inside a method or initializer, the instance the code is running on. self.title is the title property of that instance."
mastery:
  - Turn a tuple or a group of parallel variables into a struct with well-named properties.
  - Create instances with the memberwise initializer, with arguments in declaration order.
  - Explain why changing a property fails on a let instance or on a let property.
  - Write a method that computes an answer from the instance's properties.
  - Predict the values of an original and a copy after one of them is changed.
resources: [swift-book-structures-classes, swift-book-properties, swift-book-methods, swift-book-basics]
cards:
  - id: m09-l01-c1
    front: What does Swift generate for every struct that has no custom initializer?
    back: "A memberwise initializer: one labeled parameter per stored property, in declaration order. For struct Book { var title: String; var pages: Int } that's Book(title:pages:)."
  - id: m09-l01-c2
    front: "Why does p.name = \"Ana\" fail when p was declared with let, even though name is a var?"
    back: "A struct is a value. Changing any property changes the whole value, and a let constant's value can't change."
  - id: m09-l01-c3
    front: When do you have to write self. inside a method?
    back: "When a parameter or local constant has the same name as a property. self.pages is the property; plain pages is the parameter. Otherwise self. is optional."
  - id: m09-l01-c4
    front: "var b = a, where a is a struct. Then b.score = 10. Does a.score change?"
    back: No. Structs are value types, so b is an independent copy, exactly like assigning an array in Module 7.
---

## The idea in one sentence

A `struct` lets you name a group of values that belong together, so a book is a `Book` instead of a string and an integer that you hope stay side by side.

## Why define your own types

In Module 2, **abstraction** meant keeping the details that matter for the problem and naming them, so you can think at a higher level. Until now, Swift only gave you the standard library's types to do that: `Int`, `String`, arrays, dictionaries and tuples.

Here's a reading list built from those:

```swift
let titles = ["Dune", "Hyperion", "Neuromancer"]
let pageCounts = [412, 482, 271]

for index in 0..<titles.count {
    print("\(titles[index]): \(pageCounts[index]) pages")
}
```

```output
Dune: 412 pages
Hyperion: 482 pages
Neuromancer: 271 pages
```

It works, but nothing ties a title to its page count except their position. Sort one array and forget the other, and every book has the wrong length. A tuple like `(title: String, pages: Int)` keeps the pair together, but it has no name you can reuse, and you can't attach behavior to it. "How many hours will this book take to read?" ends up as a free function somewhere.

A **struct** fixes all three: it keeps the values together, gives the combination a name, and holds the functions that belong to it.

## Declaring a struct

```swift
struct Book {
    var title: String
    var pages: Int
}

let dune = Book(title: "Dune", pages: 412)
print(dune.title)
print(dune.pages)
print(dune)
```

```output
Dune
412
Book(title: "Dune", pages: 412)
```

Line by line:

1. `struct Book { … }` declares a new **type** called `Book`. Type names start with an uppercase letter (`Book`, `String`); everything else starts lowercase.
2. `var title: String` and `var pages: Int` are **stored properties**: every `Book` value holds its own title and page count. They're declared exactly like variables, with a type annotation.
3. `Book(title: "Dune", pages: 412)` creates an **instance**, one concrete book. It calls the **memberwise initializer**, which Swift writes for you: one labeled parameter per stored property, in the order you declared them.
4. `dune.title` reads a property with **dot syntax**, the same dot you've used for `scores.count` and `name.isEmpty`. Those were properties of standard library types.
5. `print(dune)` shows the type name and every property. Handy for debugging.

The struct's declaration is a blueprint. It doesn't create anything by itself; each `Book(…)` call creates a new, independent value.

## Changing properties

A property declared with `var` can change, **if the instance is in a `var` too**:

```swift
struct Player {
    let name: String
    var score: Int
}

var player = Player(name: "Christian", score: 0)
player.score += 10
player.score += 5
print("\(player.name): \(player.score)")
```

```output
Christian: 15
```

`player.score += 10` works like any other `+=`; the target just happens to be a property. Two rules decide whether a change is allowed:

- **A `let` property never changes after the instance is created.** `name` is `let` because a player's name is fixed in this game.
- **A `let` instance never changes at all.** A struct is a single value, like an `Int`. Changing any property changes the value, so a `let` instance rejects even its `var` properties:

```swift no-compile cannot assign to property: 'player' is a 'let' constant
struct Player {
    let name: String
    var score: Int
}

let player = Player(name: "Christian", score: 0)
player.score = 10
```

Swift 6.3 reports `error: cannot assign to property: 'player' is a 'let' constant`, with a note suggesting you change `let` to `var`. Do that only if the value really should change. (With `player.score += 10` the wording is different, `left side of mutating operator isn't mutable: 'player' is a 'let' constant`, but the cause is the same.)

## Methods

A **method** is a function declared inside a type. It runs on one instance and can read that instance's properties directly:

```swift
struct Book {
    var title: String
    var pages: Int

    func hoursToRead(pagesPerHour: Int) -> Int {
        return (pages + pagesPerHour - 1) / pagesPerHour
    }

    func isLongerThan(_ other: Book) -> Bool {
        return pages > other.pages
    }
}

let dune = Book(title: "Dune", pages: 412)
let neuromancer = Book(title: "Neuromancer", pages: 271)

print(dune.hoursToRead(pagesPerHour: 40))
print(neuromancer.hoursToRead(pagesPerHour: 40))
print(dune.isLongerThan(neuromancer))
```

```output
11
7
true
```

1. `hoursToRead(pagesPerHour:)` uses `pages` without saying whose pages. Inside a method, a bare property name means "this instance's property". `(pages + pagesPerHour - 1) / pagesPerHour` is integer division rounded up, so a 412-page book at 40 pages an hour takes 11 hours, not 10.
2. You call a method with dot syntax on an instance: `dune.hoursToRead(pagesPerHour: 40)`. Labels work exactly as they do for functions (Module 6).
3. `isLongerThan(_:)` takes another `Book`. Inside it, `pages` is this book's and `other.pages` is the other one's.

### self

Inside a method, **`self`** is the instance the method is running on. `self.pages` and `pages` mean the same thing, and usually you leave `self.` out. You need it when a parameter or local constant has the same name as a property, because the closer name wins:

```swift
struct Book {
    var title: String
    var pages: Int

    func hasMorePages(than pages: Int) -> Bool {
        return self.pages > pages
    }
}

let hyperion = Book(title: "Hyperion", pages: 482)
print(hyperion.hasMorePages(than: 400))
print(hyperion.hasMorePages(than: 500))
```

```output
true
false
```

Inside `hasMorePages(than:)`, plain `pages` is the parameter, and `self.pages` is the book's property. You'll write `self.` most often in initializers, in lesson 3.

## A struct is a value

In Module 7 you saw that assigning an array gives the receiver its own copy. Structs behave the same way: they're **value types**. `var copy = original` copies every property, and from then on the two are unrelated:

```swift
struct Player {
    let name: String
    var score: Int
}

let original = Player(name: "Ana", score: 10)
var copy = original
copy.score = 99

print(original.score)
print(copy.score)
```

```output
10
99
```

The same happens when you pass a struct to a function or put it in an array. Nobody else can change your copy behind your back. Module 10 looks at value types against reference types (classes) in depth; for now, treat a struct like an `Int` that happens to have named parts.

## A practical example: a reading list

Structs and collections work together. An array of `Book` keeps each title with its own page count, and the Module 7 tools, `filter`, `map`, `sorted(by:)` and `reduce`, work on it with closures that read properties:

```swift
struct Book {
    var title: String
    var author: String
    var pages: Int

    func summary() -> String {
        return "\(title) by \(author), \(pages) pages"
    }
}

let readingList = [
    Book(title: "Dune", author: "Frank Herbert", pages: 412),
    Book(title: "Neuromancer", author: "William Gibson", pages: 271),
    Book(title: "Hyperion", author: "Dan Simmons", pages: 482),
    Book(title: "The Hobbit", author: "J. R. R. Tolkien", pages: 310),
]

let shortBooks = readingList.filter { book in book.pages < 400 }
print("Short books: \(shortBooks.map { book in book.title })")

let longestFirst = readingList.sorted { a, b in a.pages > b.pages }
for book in longestFirst {
    print(book.summary())
}

let totalPages = readingList.reduce(0) { total, book in total + book.pages }
print("Total: \(totalPages) pages")
```

```output
Short books: ["Neuromancer", "The Hobbit"]
Hyperion by Dan Simmons, 482 pages
Dune by Frank Herbert, 412 pages
The Hobbit by J. R. R. Tolkien, 310 pages
Neuromancer by William Gibson, 271 pages
Total: 1475 pages
```

Sorting `readingList` moves whole books, so a title can never end up with another book's page count. That's the bug the parallel arrays invited, and it can't happen here.

## Common mistakes

> [!error] error: cannot assign to property: 'book' is a 'let' constant
> You declared the instance with `let` and then changed one of its properties. A struct is one value, so a `let` instance can't change at all. Use `var` if it must change; otherwise build a new instance.

> [!error] error: missing argument for parameter 'pages' in call
> The memberwise initializer needs a value for every stored property that doesn't have a default (defaults come in lesson 3). Pass all of them.

```swift no-compile missing argument for parameter 'pages' in call
struct Book {
    var title: String
    var pages: Int
}

let book = Book(title: "Dune")
```

> [!error] error: argument 'title' must precede argument 'pages'
> The memberwise initializer's parameters follow the order of the property declarations. `Book(pages: 412, title: "Dune")` is rejected; Swift doesn't reorder labeled arguments.

```swift no-compile argument 'title' must precede argument 'pages'
struct Book {
    var title: String
    var pages: Int
}

let book = Book(pages: 412, title: "Dune")
```

> [!error] error: binary operator '==' cannot be applied to two 'Book' operands
> Your own struct can't be compared with `==` until you ask for it. Write `struct Book: Equatable { … }` and Swift generates the comparison for you, property by property, as long as every property can itself be compared. What that `: Equatable` means is Module 10's topic.

```swift no-compile binary operator '==' cannot be applied to two 'Book' operands
struct Book {
    var title: String
    var pages: Int
}

let a = Book(title: "Dune", pages: 412)
let b = Book(title: "Dune", pages: 412)
print(a == b)
```

```swift
struct Book: Equatable {
    var title: String
    var pages: Int
}

let a = Book(title: "Dune", pages: 412)
let b = Book(title: "Dune", pages: 412)
print(a == b)
```

```output
true
```

> [!warning] Forgetting self when a parameter shadows a property
> In `func hasMorePages(than pages: Int) -> Bool { return pages > pages }`, both `pages` are the parameter, so the function always returns `false`. It compiles, which makes it worse. Write `self.pages` for the property.

````exercise
id: m09-l01-e1
type: comprehension
prompt: |
  Given this struct, which line does **not** compile?

  ```swift illustrative
  struct Ticket {
      let seat: String
      var price: Int
  }
  var a = Ticket(seat: "12B", price: 80)
  let b = Ticket(seat: "3A", price: 120)
  ```
choices:
  - text: "`a.price = 60`"
    correct: false
    why: "a is a var and price is a var property, so this is fine."
  - text: "`print(b.price)`"
    correct: false
    why: Reading a property is always allowed, even on a let instance.
  - text: "`b.price = 100`"
    correct: true
    why: "b is a let constant. A struct is a single value, so none of its properties can change, even var ones."
  - text: "`a = Ticket(seat: \"1C\", price: 50)`"
    correct: false
    why: a is a var, so you can replace the whole value with a new instance.
solution: |
  **`b.price = 100`**. Swift 6.3 reports `cannot assign to property: 'b' is a 'let' constant`. Note the last option: `a.seat` is a `let` property, so `a.seat = "1C"` wouldn't compile, but replacing all of `a` with a new `Ticket` is allowed because `a` itself is a `var`.
````

````exercise
id: m09-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Counter {
      var name: String
      var count: Int
  }

  var first = Counter(name: "steps", count: 100)
  var second = first
  second.count += 50
  first.name = "laps"

  print(first.name, first.count)
  print(second.name, second.count)
output: |
  laps 100
  steps 150
hints:
  - "var second = first copies every property at that moment."
  - After the copy, changes to one don't reach the other.
solution: |
  ```output
  laps 100
  steps 150
  ```

  `var second = first` makes an independent copy: `steps`, `100`. Then `second.count` becomes 150 and only `second` sees it, and `first.name` becomes `"laps"` and only `first` sees that. Structs are value types, so each variable owns its own value.
````

````exercise
id: m09-l01-e3
type: fill-in
prompt: Complete the struct so the program prints `Lisbon is 2.5 hours ahead of New York`.
code: |
  struct City {
      var name: String
      var utcOffset: Double

      func hoursAhead(of [[1]]: City) -> Double {
          return [[2]].utcOffset - other.utcOffset
      }
  }

  let lisbon = [[3]](name: "Lisbon", utcOffset: 0)
  let newYork = City(name: "New York", utcOffset: -2.5)
  print("\(lisbon.name) is \(lisbon.[[4]](of: newYork)) hours ahead of \(newYork.name)")
blanks:
  - id: "1"
    answers: [other]
  - id: "2"
    answers: [self]
  - id: "3"
    answers: [City]
  - id: "4"
    answers: [hoursAhead]
solution: |
  ```swift
  struct City {
      var name: String
      var utcOffset: Double

      func hoursAhead(of other: City) -> Double {
          return self.utcOffset - other.utcOffset
      }
  }

  let lisbon = City(name: "Lisbon", utcOffset: 0)
  let newYork = City(name: "New York", utcOffset: -2.5)
  print("\(lisbon.name) is \(lisbon.hoursAhead(of: newYork)) hours ahead of \(newYork.name)")
  ```

  ```output
  Lisbon is 2.5 hours ahead of New York
  ```

  The parameter's internal name has to be `other`, because the body uses `other.utcOffset`. `self.utcOffset` is the offset of the city the method was called on; plain `utcOffset` would also work, since nothing shadows it. (New York's real offset isn't -2.5; the made-up value just keeps the output short.)
````

````exercise
id: m09-l01-e4
type: find-errors
prompt: This program should print the area of a room in square meters. Which of these are real problems?
code: |
  struct Room {
      let name: String
      var width: Double
      var length: Double

      func area() -> Double {
          return width * length
      }
  }

  let kitchen = Room(name: "Kitchen", length: 4.0, width: 3.5)
  kitchen.width = 3.8
  print("\(kitchen.name): \(kitchen.area) m²")
choices:
  - text: The memberwise initializer's arguments are in the wrong order.
    correct: true
    why: "width is declared before length, so the call must be Room(name:width:length:)."
  - text: "kitchen is a let constant, so kitchen.width = 3.8 doesn't compile."
    correct: true
    why: "A let instance can't change any of its properties."
  - text: "kitchen.area is missing the parentheses that call the method."
    correct: true
    why: "Without (), the interpolation refers to the method itself instead of calling it. Swift 6.3 compiles it but prints \"(Function)\" and warns that the string interpolation produces a debug description for a function value."
  - text: "area() must write self.width and self.length."
    correct: false
    why: Nothing shadows those names inside area(), so self. is optional.
rubric:
  - I found the argument order, the let instance and the missing call parentheses.
  - I explained why self. isn't required in area().
solution: |
  Three real problems: the arguments must follow declaration order (`width:` before `length:`), `kitchen` must be a `var` if its width is going to change, and `kitchen.area` must be `kitchen.area()` to call the method.

  ```swift
  struct Room {
      let name: String
      var width: Double
      var length: Double

      func area() -> Double {
          return width * length
      }
  }

  var kitchen = Room(name: "Kitchen", width: 3.5, length: 4.0)
  kitchen.width = 3.8
  print("\(kitchen.name): \(kitchen.area()) m²")
  ```

  ```output
  Kitchen: 15.2 m²
  ```

  In the next lesson you'll turn `area()` into a computed property, so that `kitchen.area` without parentheses is correct.
````

````exercise
id: m09-l01-e5
type: solve
prompt: |
  Write a `struct Item` with a `name` (`String`), a `priceInCents` (`Int`) and a `quantity` (`Int`), and a method `subtotal()` that returns `priceInCents * quantity`.

  Then, for this cart, print one line per item and the total, exactly like the expected output. Format cents as dollars with a function `dollars(_ cents: Int) -> String` that returns, for example, `"$4.50"` for 450 and `"$12.05"` for 1205.

  ```swift illustrative
  let cart = [
      Item(name: "Coffee", priceInCents: 450, quantity: 2),
      Item(name: "Bagel", priceInCents: 305, quantity: 1),
      Item(name: "Juice", priceInCents: 600, quantity: 3),
  ]
  ```

  Expected output:

  ```output
  2 x Coffee: $9.00
  1 x Bagel: $3.05
  3 x Juice: $18.00
  Total: $30.05
  ```
starter: |
  struct Item {
      // properties and subtotal()
  }

  func dollars(_ cents: Int) -> String {
      // your code
  }

  let cart = [
      Item(name: "Coffee", priceInCents: 450, quantity: 2),
      Item(name: "Bagel", priceInCents: 305, quantity: 1),
      Item(name: "Juice", priceInCents: 600, quantity: 3),
  ]
hints:
  - "cents / 100 gives the dollars and cents % 100 the remaining cents."
  - "A remaining cents value below 10 needs a leading zero: 5 must print as 05."
  - "reduce(0) { total, item in total + item.subtotal() } adds up the subtotals."
rubric:
  - Item has the three stored properties and a subtotal() method that uses them.
  - dollars(_:) pads the cents to two digits.
  - The total is computed from the items, not typed in.
  - The output matches exactly.
solution: |
  ```swift
  struct Item {
      var name: String
      var priceInCents: Int
      var quantity: Int

      func subtotal() -> Int {
          return priceInCents * quantity
      }
  }

  func dollars(_ cents: Int) -> String {
      let remainder = cents % 100
      let padded = remainder < 10 ? "0\(remainder)" : "\(remainder)"
      return "$\(cents / 100).\(padded)"
  }

  let cart = [
      Item(name: "Coffee", priceInCents: 450, quantity: 2),
      Item(name: "Bagel", priceInCents: 305, quantity: 1),
      Item(name: "Juice", priceInCents: 600, quantity: 3),
  ]

  for item in cart {
      print("\(item.quantity) x \(item.name): \(dollars(item.subtotal()))")
  }
  let total = cart.reduce(0) { total, item in total + item.subtotal() }
  print("Total: \(dollars(total))")
  ```

  ```output
  2 x Coffee: $9.00
  1 x Bagel: $3.05
  3 x Juice: $18.00
  Total: $30.05
  ```

  Money is stored as whole cents, so there's no `Double` rounding. `subtotal()` belongs to `Item` because it only needs the item's own properties. `dollars(_:)` stays a free function for now: it works on any amount, not on an item. (Negative amounts would need more care; this cart doesn't have any.)
````

````exercise
id: m09-l01-e6
type: design
prompt: |
  A habit-tracking app keeps, for each habit, its name, how many days in a row it's been done (the streak), the longest streak ever, and whether it's been done today. Right now the code keeps four separate arrays. Design a struct to replace them: list its properties with their types and `let`/`var`, and name two methods it should have, with their signatures. Explain each `let`/`var` choice.
rubric:
  - The struct has a property for each of the four pieces of data, with sensible types (String, Int, Int, Bool).
  - The let/var choices are justified (for example, the name could be let if habits can't be renamed).
  - The methods only need the habit's own data, which is why they belong to the struct.
  - The explanation mentions why one array of structs beats four parallel arrays.
solution: |
  One reasonable design:

  ```swift
  struct Habit {
      let name: String
      var currentStreak: Int
      var longestStreak: Int
      var doneToday: Bool

      func isPersonalBest() -> Bool {
          return currentStreak > 0 && currentStreak == longestStreak
      }

      func statusLine() -> String {
          let mark = doneToday ? "done" : "pending"
          return "\(name): \(currentStreak) days (\(mark))"
      }
  }

  let reading = Habit(name: "Read", currentStreak: 12, longestStreak: 12, doneToday: true)
  print(reading.statusLine())
  print(reading.isPersonalBest())
  ```

  ```output
  Read: 12 days (done)
  true
  ```

  `name` is `let` if the app doesn't allow renaming; if it does, make it `var`. The streaks and the done flag change every day, so they're `var`. Both methods answer a question using only the habit's own properties, which is the sign they belong on the type. A method that marks the habit as done would have to change the instance, and that needs the keyword `mutating` from lesson 4.

  The main gain over four arrays: one `[Habit]` can be sorted, filtered or have an element removed without any risk of the arrays drifting out of step.
````

## Summary

- A `struct` defines your own type: a name, stored properties and methods. Type names start with an uppercase letter.
- Swift writes a **memberwise initializer** for every struct: one labeled argument per stored property, in declaration order.
- Dot syntax reads and writes properties and calls methods: `book.pages`, `book.hoursToRead(pagesPerHour: 40)`.
- A `let` property never changes. A `let` instance never changes at all, not even its `var` properties.
- Inside a method, `self` is the instance. Write `self.` when a parameter has the same name as a property.
- Structs are value types: assigning or passing one gives the receiver an independent copy, exactly like arrays.
- An array of structs replaces parallel arrays and keeps related values together through sorting and filtering.
- `struct Name: Equatable` gives you `==` for free when every property is comparable.
