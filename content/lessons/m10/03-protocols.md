---
id: m10-l03
title: Protocols
description: You declare protocols with method, property, mutating and initializer requirements, make structs, classes and enums conform, use a protocol as a type with any, and conform to Equatable, Hashable and Comparable, including the strict ordering Comparable needs.
module: m10
order: 3
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l02]
objectives:
  - Declare a protocol with method and property requirements, using { get } and { get set } correctly.
  - Make a struct, a class and an enum conform to the same protocol.
  - Write a mutating requirement and an init requirement, and satisfy them in a struct and in a class.
  - Store values of different conforming types in one array of any Protocol and call requirements on them.
  - Get Equatable and Hashable synthesized for a struct or enum, and write them by hand for a class.
  - Implement Comparable with a strict ordering on two fields.
terms:
  - term: Protocol
    definition: "A named list of requirements (methods, properties, initializers) that a type can promise to meet. It says what a type can do, not how."
  - term: Conformance
    definition: "A type's declaration that it meets a protocol's requirements, written struct Circle: Shape. The compiler checks every requirement."
  - term: Requirement
    definition: "One thing a protocol asks for: a method signature, a property with { get } or { get set }, an initializer, or a static member."
  - term: Existential (any)
    definition: "A value of type any P: a box that can hold a value of any type conforming to P. The concrete type inside can differ from box to box."
  - term: Synthesized conformance
    definition: "Code the compiler writes for you. Structs and enums get == for Equatable and hash(into:) for Hashable when all their stored properties or associated values conform."
  - term: Strict total order
    definition: "What Comparable's < must be: never a < a, if a < b and b < c then a < c, and for any two values that aren't equal, exactly one of a < b or b < a is true."
mastery:
  - Write a protocol with a { get } property, a { get set } property and a method, and say which kinds of property can satisfy each.
  - Satisfy a mutating requirement in a struct and the same requirement in a class.
  - Fix "initializer requirement 'init()' can only be satisfied by a 'required' initializer".
  - Loop over [any Shape] and call a requirement on each element.
  - Make a struct a dictionary key by adding Hashable, and say when synthesis applies.
  - Spot a broken two-field < and rewrite it to compare the second field only when the first is equal.
resources: [swift-book-protocols, swift-book-initialization, swift-book-methods]
cards:
  - id: m10-l03-c1
    front: "A protocol requires var name: String { get }. What can satisfy it? What about { get set }?"
    back: "{ get }: a let, a var or a read-only computed property. { get set }: a var or a computed property with a setter, never a let or a read-only computed property."
  - id: m10-l03-c2
    front: "Why do some protocol methods say mutating?"
    back: "So structs and enums can change self in their implementation. Classes implement the same requirement without writing mutating."
  - id: m10-l03-c3
    front: A protocol requires init(). How does a non-final class satisfy it?
    back: "With required init(). required makes every subclass provide it too, so the conformance holds for subclasses. A final class doesn't need required."
  - id: m10-l03-c4
    front: When does a struct get Equatable and Hashable for free?
    back: "When you declare the conformance and every stored property is Equatable (or Hashable). Enums: every associated value, or no associated values. Classes never get them synthesized."
  - id: m10-l03-c5
    front: "What's wrong with lhs.major < rhs.major && lhs.minor < rhs.minor as <?"
    back: "It isn't a strict total order: 1.5 and 2.0 are neither < nor > each other, yet they aren't equal, so sorted() and min() give wrong answers. Compare minor only when major is equal."
---

## The idea in one sentence

A protocol is a list of requirements; any struct, class or enum can promise to meet it, and then code can work with **anything that meets the requirements** without knowing the concrete type.

## Declaring a protocol

```swift
protocol Shape {
    var name: String { get }
    var area: Double { get }
    func describe() -> String
}

struct Square: Shape {
    let side: Double
    let name = "square"

    var area: Double {
        side * side
    }

    func describe() -> String {
        "\(name) with area \(area)"
    }
}

let square = Square(side: 3)
print(square.describe())
```

```output
square with area 9.0
```

1. `protocol Shape` lists three **requirements**. There are no bodies: a protocol says what, not how.
2. `struct Square: Shape` declares **conformance**. The syntax is the same colon as inheritance; for a class with a superclass, the superclass comes first: `class Dog: Animal, Pet`.
3. `name` is a `let`, `area` is a computed property, `describe()` is a method. All three meet their requirements.

The compiler checks every requirement. Leave one out:

```swift no-compile type 'Circle' does not conform to protocol 'Shape'
protocol Shape {
    var area: Double { get }
}

struct Circle: Shape {
    let radius: Double
}
```

Swift 6.3 reports `error: type 'Circle' does not conform to protocol 'Shape'`, plus a note naming the missing `area`. In Xcode, the error offers a fix-it that inserts stubs for what's missing.

### Property requirements: { get } and { get set }

A property requirement always says `var`, and then how it's accessed:

- `{ get }`: readable. A `let`, a `var`, or a read-only computed property all work. A conforming type may also make it settable; the protocol only asks for at least reading.
- `{ get set }`: readable and writable. Only a `var` or a computed property with a setter works.

```swift no-compile type 'Guest' does not conform to protocol 'Renamable'
protocol Renamable {
    var name: String { get set }
}

struct Guest: Renamable {
    let name: String
}
```

A `let` can't be set, so it can't satisfy `{ get set }`.

### mutating requirements

If a requirement's implementation should be able to change the instance, mark it `mutating` in the protocol. That's what lets a struct or an enum implement it, exactly like a `mutating` method in Module 9. Classes ignore the keyword: their methods can always change properties.

```swift
protocol Toggleable {
    mutating func toggle()
}

enum Switch: Toggleable {
    case on, off

    mutating func toggle() {
        self = self == .on ? .off : .on
    }
}

final class Lamp: Toggleable {
    var isLit = false

    func toggle() {
        isLit.toggle()
    }
}

var hallSwitch = Switch.off
hallSwitch.toggle()
print(hallSwitch == .on)

let lamp = Lamp()
lamp.toggle()
print(lamp.isLit)
```

```output
true
true
```

The enum assigns to `self`, so its implementation must be `mutating`. The class writes plain `func`. (`Bool` has its own `toggle()`, which is what `isLit.toggle()` calls.) If you forget `mutating` in the protocol, no struct that changes a property can conform: its implementation would have to be `mutating`, which wouldn't match the non-mutating requirement.

### Initializer requirements

A protocol can require an initializer:

```swift
protocol Resettable {
    init()
}

struct Score: Resettable {
    var points = 0
}

class Stopwatch: Resettable {
    var seconds = 0

    required init() {}
}

let fresh = Score()
let timer = Stopwatch()
print(fresh.points, timer.seconds)
```

```output
0 0
```

`Score` meets it with the `init()` Swift gives any struct whose properties all have defaults. `Stopwatch` needs the word `required`: every subclass of `Stopwatch` must then provide `init()` too, so a subclass can never break the conformance it inherited. A `final` class can't have subclasses, so it doesn't need `required`.

```swift no-compile can only be satisfied by a 'required' initializer in non-final class 'Stopwatch'
protocol Resettable {
    init()
}

class Stopwatch: Resettable {
    var seconds = 0
    init() {}
}
```

## One protocol, many kinds of type

Structs, classes and enums can all conform to the same protocol:

```swift
protocol Priced {
    var price: Int { get }
}

struct Book: Priced {
    let title: String
    let price: Int
}

enum Ticket: Priced {
    case child, adult

    var price: Int {
        switch self {
        case .child: 5
        case .adult: 12
        }
    }
}

final class Subscription: Priced {
    let monthly: Int
    let months: Int

    init(monthly: Int, months: Int) {
        self.monthly = monthly
        self.months = months
    }

    var price: Int {
        monthly * months
    }
}

let basket: [any Priced] = [
    Book(title: "Swift Basics", price: 30),
    Ticket.adult,
    Ticket.child,
    Subscription(monthly: 8, months: 3),
]

var total = 0
for item in basket {
    total += item.price
}
print("Total: \(total)")
```

```output
Total: 71
```

`basket` holds a book, two tickets and a subscription. Its element type is `any Priced`: "a value of some type that conforms to `Priced`". The only thing the loop can use is what the protocol promises, `price`, and that's all it needs.

`any Priced` is called an **existential**: a box that can hold any conforming value, with the concrete type inside free to differ from box to box. Calling `item.price` looks inside the box and runs that type's implementation. Lesson 5 compares this box with the alternative, `some`, and explains its cost.

> [!note] Writing any
> For a protocol like `Priced`, Swift 6 still accepts `[Priced]` without the `any`. Write `any` anyway: it makes the box visible, newer code uses it everywhere, and for protocols with associated types (lesson 5) the compiler already asks for it.

This should look familiar: it's polymorphism again, like the `[Shape]` array in lesson 2, but with no superclass. A struct and an enum can't share a superclass; they can share a protocol. Under the hood, a call to a protocol requirement goes through a **witness table**: for each conformance, a table that maps each requirement to the conforming type's implementation. It's the protocol counterpart of a class's vtable.

## Equatable, Hashable and Comparable

Three standard-library protocols you'll conform to constantly.

### Equatable: ==

`Equatable` requires one thing, `static func ==`. For a struct or an enum, if every stored property (or associated value) is already `Equatable`, you just declare the conformance and the compiler **synthesizes** `==`, comparing all of them:

```swift
struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

enum Status: Equatable {
    case active
    case suspended(reason: String)
}

print(Coordinate(latitude: 40.4, longitude: -3.7) == Coordinate(latitude: 40.4, longitude: -3.7))
print(Status.suspended(reason: "fraud") == .suspended(reason: "late"))
```

```output
true
false
```

`!=` comes for free once `==` exists. If "equal" should mean something else (say, two users are equal when their ids match, whatever their names), write `==` yourself, as you did for `Ticket` in lesson 1. Classes never get synthesis, because for an object it's not obvious whether equal should mean identical (`===`) or same data.

### Hashable: dictionary keys and set elements

`Set` elements and `Dictionary` keys (Module 7) must be `Hashable`: the type must be able to produce a hash value, a number that equal values always share. Synthesis works the same way as for `Equatable`:

```swift
struct Seat: Hashable {
    let row: Int
    let letter: String
}

var reserved: Set<Seat> = []
reserved.insert(Seat(row: 12, letter: "A"))
reserved.insert(Seat(row: 12, letter: "A"))
reserved.insert(Seat(row: 3, letter: "C"))

let prices: [Seat: Int] = [Seat(row: 1, letter: "A"): 90]

print(reserved.count)
print(reserved.contains(Seat(row: 3, letter: "C")))
print(prices[Seat(row: 1, letter: "A"), default: 0])
```

```output
2
true
90
```

`Hashable` includes `Equatable`, so `Seat` gets both. For a class, write both by hand: `==` and `hash(into:)`, feeding the hasher the same properties `==` compares.

```swift
final class User: Hashable {
    let id: Int
    var name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

let online: Set<User> = [User(id: 1, name: "Ana"), User(id: 1, name: "Ana B."), User(id: 2, name: "Leo")]
print(online.count)
```

```output
2
```

The rule that matters: if `a == b`, then `a` and `b` must produce the same hash. Hash exactly the properties that `==` compares and you can't break it.

### Comparable: <

`Comparable` requires `static func <`, and builds `<=`, `>`, `>=`, `min()`, `max()` and `sorted()` on top of it. Structs don't get `<` synthesized. Enums do, when they have no associated values or all their associated values are `Comparable`; cases are ordered the way you declared them.

Here's the trap. A version has two parts, major and minor. This looks reasonable:

```swift
struct Version: Comparable {
    let major: Int
    let minor: Int

    static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.major < rhs.major && lhs.minor < rhs.minor
    }
}

let v15 = Version(major: 1, minor: 5)
let v20 = Version(major: 2, minor: 0)
print(v15 < v20, v20 < v15, v15 == v20)

let versions = [
    Version(major: 2, minor: 0),
    Version(major: 1, minor: 5),
    Version(major: 1, minor: 2),
    Version(major: 3, minor: 1),
]
let oldest = versions.min() ?? v15
print("Oldest: \(oldest.major).\(oldest.minor)")
```

```output
false false false
Oldest: 2.0
```

1.5 is not less than 2.0 because 5 isn't less than 0. And 2.0 isn't less than 1.5 because 2 isn't less than 1. So neither is smaller, yet they're not equal. `min()` trusts `<` and reports 2.0 as the oldest version.

`Comparable` requires a **strict total order**: for any two values that aren't equal, exactly one of `a < b` and `b < a` must be true. (Also: `a < a` is never true, and if `a < b` and `b < c` then `a < c`.) The `&&` version breaks that. Exactly which wrong answer you get from `min()` or `sorted()` depends on the algorithm and the input; the output above is what Swift 6.3 produces for this array, and the point is that it's wrong.

The fix compares the second field **only when the first is equal**:

```swift
struct Version: Comparable {
    let major: Int
    let minor: Int

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }
}

let versions = [
    Version(major: 2, minor: 0),
    Version(major: 1, minor: 5),
    Version(major: 1, minor: 2),
    Version(major: 3, minor: 1),
]
for version in versions.sorted() {
    print("\(version.major).\(version.minor)")
}
```

```output
1.2
1.5
2.0
3.1
```

A shorter version that does the same: `(lhs.major, lhs.minor) < (rhs.major, rhs.minor)`. Swift compares tuples of comparable values left to right, field by field, which is exactly the rule.

## Common mistakes

> [!error] error: type 'Circle' does not conform to protocol 'Shape'
> A requirement is missing or its signature doesn't match: wrong name, wrong type, a `let` for a `{ get set }` property, or a non-`mutating` requirement that a struct implements by changing `self`. Read the note under the error; it names the requirement.

> [!error] error: initializer requirement 'init()' can only be satisfied by a 'required' initializer in non-final class
> Add `required` to the class's initializer, or make the class `final`.

> [!error] Forgetting mutating in the protocol
> If the protocol says `func reset()` without `mutating`, a struct can't conform with an implementation that changes its properties. Decide up front whether value types should be able to change themselves.

> [!error] A < that compares fields with &&
> It isn't a strict total order. Compare the first field; only if it's equal, compare the next. Or compare tuples.

> [!error] Hashing different properties than == compares
> If `==` compares only `id` but `hash(into:)` also combines `name`, two equal users can have different hashes and a `Set` will treat them as different. Hash what `==` compares.

````exercise
id: m10-l03-e1
type: comprehension
prompt: |
  ```swift
  protocol Labeled {
      var label: String { get set }
  }
  ```

  Which of these types conforms to `Labeled`?
choices:
  - text: "struct A: Labeled { let label: String }"
    correct: false
    why: A let can't be set, and the requirement says { get set }.
  - text: "struct B: Labeled { var label: String { \"B\" } }"
    correct: false
    why: A read-only computed property has no setter.
  - text: "struct C: Labeled { var label = \"C\" }"
    correct: true
    why: A stored var can be read and written, which is exactly what { get set } asks for.
  - text: None; structs can't conform to protocols with settable properties.
    correct: false
    why: Structs conform to such protocols all the time. The property just has to be settable.
solution: |
  **C.** `{ get set }` asks for a property you can read and write. A stored `var` is the usual answer, and a computed property with both `get` and `set` would work too. Had the protocol said `{ get }`, all three structs would conform.
````

````exercise
id: m10-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  protocol Greeter {
      var name: String { get }
      func greet() -> String
  }

  struct Friend: Greeter {
      let name: String
      func greet() -> String {
          "Hey \(name)"
      }
  }

  enum Robot: Greeter {
      case r2, c3
      var name: String {
          self == .r2 ? "R2" : "C3"
      }
      func greet() -> String {
          "Beep. Unit \(name) online"
      }
  }

  final class Host: Greeter {
      var name = "Sam"
      func greet() -> String {
          "Welcome, I'm \(name)"
      }
  }

  let host = Host()
  let greeters: [any Greeter] = [Friend(name: "Ana"), Robot.c3, host]
  host.name = "Max"
  for greeter in greeters {
      print(greeter.greet())
  }
output: |
  Hey Ana
  Beep. Unit C3 online
  Welcome, I'm Max
hints:
  - Each element runs its own type's greet().
  - "The array holds a reference to host, not a copy. Lesson 1."
solution: |
  ```output
  Hey Ana
  Beep. Unit C3 online
  Welcome, I'm Max
  ```

  Each call goes to the conforming type's implementation. The surprise is the last line: `Host` is a class, so the `any Greeter` box holds a reference to the same instance as `host`. Changing `host.name` after building the array changes what the array sees. Had `Host` been a struct, the array would hold a copy made before the change, and it would print `Sam`.
````

````exercise
id: m10-l03-e3
type: fill-in
prompt: |
  Complete the code so it compiles and prints `3 0`.
code: |
  protocol Counter {
      var count: Int { get }
      [[1]] func increment()
      [[2]] func reset()
  }

  struct TapCounter: Counter {
      private(set) var count = 0
      mutating func increment() {
          count += 1
      }
      mutating func reset() {
          count = 0
      }
  }

  var taps = TapCounter()
  taps.increment()
  taps.increment()
  taps.increment()
  let before = taps.count
  taps.reset()
  print(before, taps.[[3]])
blanks:
  - id: "1"
    answers: ["mutating"]
  - id: "2"
    answers: ["mutating"]
  - id: "3"
    answers: ["count"]
solution: |
  ```swift
  protocol Counter {
      var count: Int { get }
      mutating func increment()
      mutating func reset()
  }

  struct TapCounter: Counter {
      private(set) var count = 0
      mutating func increment() {
          count += 1
      }
      mutating func reset() {
          count = 0
      }
  }

  var taps = TapCounter()
  taps.increment()
  taps.increment()
  taps.increment()
  let before = taps.count
  taps.reset()
  print(before, taps.count)
  ```

  ```output
  3 0
  ```

  Both requirements must be `mutating`, or the struct's `mutating` implementations wouldn't satisfy them. `count` is `{ get }` in the protocol, and the struct makes it `private(set)`: readable by everyone, writable only by the struct's own code. Lesson 4 covers `private(set)` and the other access levels.
````

````exercise
id: m10-l03-e4
type: find-errors
prompt: "This `Comparable` conformance is meant to sort players by score, highest first, and by name when scores tie. Pick out the real problems."
code: |
  struct Player: Comparable {
      let name: String
      let score: Int

      static func < (lhs: Player, rhs: Player) -> Bool {
          lhs.score > rhs.score && lhs.name < rhs.name
      }
  }
choices:
  - text: "Joining the two fields with && means some unequal players are neither < nor > each other."
    correct: true
    why: "Ben with 90 and Ana with 80: the score says Ben comes first, the name says Ana does. Each < fails one of its two parts, so neither player comes before the other."
  - text: Using > on score inside < is never allowed.
    correct: false
    why: "Reversing a field is a legitimate way to sort descending. The problem is how the fields are combined."
  - text: "The struct needs to write == because Comparable requires it."
    correct: false
    why: "Comparable includes Equatable, but for this struct == is synthesized from name and score."
  - text: "Names should only be compared when the scores are equal."
    correct: true
    why: That's the strict-total-order rule. The tiebreaker only applies to a tie.
rubric:
  - The score is compared first, descending.
  - The name is compared only when scores are equal.
  - A test shows a pair that the original got wrong.
solution: |
  ```swift
  struct Player: Comparable {
      let name: String
      let score: Int

      static func < (lhs: Player, rhs: Player) -> Bool {
          if lhs.score != rhs.score {
              return lhs.score > rhs.score
          }
          return lhs.name < rhs.name
      }
  }

  let ben = Player(name: "Ben", score: 90)
  let ana = Player(name: "Ana", score: 80)
  let cleo = Player(name: "Cleo", score: 90)
  print(ben < ana, ana < ben)
  for player in [ana, cleo, ben].sorted() {
      print(player.name, player.score)
  }
  ```

  ```output
  true false
  Ben 90
  Cleo 90
  Ana 80
  ```

  With the original, `ben < ana` was false (the names are in the wrong order) and `ana < ben` was false too (the scores are). Two different players, neither before the other: not a strict total order. Comparing the name only on a tie fixes it. Here "less than" means "comes first in the ranking", which is why the score uses `>`.
````

````exercise
id: m10-l03-e5
type: solve
prompt: |
  Write a protocol `Discountable` with:

  - a `{ get }` property `basePrice: Int`,
  - a method `func price(for quantity: Int) -> Int`.

  Then two conforming types:

  - `struct Coffee` with `let basePrice: Int`. Price is `basePrice * quantity`, but every 5th cup is free (5 cups cost 4, 10 cost 8).
  - `enum Pass` with cases `day` and `week`. `basePrice` is 10 for `day` and 50 for `week`. Price is `basePrice * quantity` with no discount.

  Finally, write `func total(_ items: [any Discountable], quantity: Int) -> Int` that adds up every item's price for that quantity. This must print `126`:

  ```swift
  print(total([Coffee(basePrice: 3), Pass.day, Pass.week], quantity: 2))
  ```

  And `print(Coffee(basePrice: 3).price(for: 10))` must print `24`.
starter: |
  protocol Discountable {
      // your code
  }
hints:
  - "The free cups are quantity / 5 (integer division)."
  - "The enum's basePrice is a computed property with a switch on self."
  - "total needs a loop over items with a var sum."
rubric:
  - The protocol has exactly the two requirements.
  - A struct and an enum both conform.
  - total works only through the protocol, with no casts.
  - Both outputs match.
solution: |
  ```swift
  protocol Discountable {
      var basePrice: Int { get }
      func price(for quantity: Int) -> Int
  }

  struct Coffee: Discountable {
      let basePrice: Int

      func price(for quantity: Int) -> Int {
          let freeCups = quantity / 5
          return basePrice * (quantity - freeCups)
      }
  }

  enum Pass: Discountable {
      case day, week

      var basePrice: Int {
          switch self {
          case .day: 10
          case .week: 50
          }
      }

      func price(for quantity: Int) -> Int {
          basePrice * quantity
      }
  }

  func total(_ items: [any Discountable], quantity: Int) -> Int {
      var sum = 0
      for item in items {
          sum += item.price(for: quantity)
      }
      return sum
  }

  print(total([Coffee(basePrice: 3), Pass.day, Pass.week], quantity: 2))
  print(Coffee(basePrice: 3).price(for: 10))
  ```

  ```output
  126
  24
  ```

  For a quantity of 2: two coffees are 6 (no free cup below 5), two day passes are 20, two week passes are 100, so 126. For 10 coffees, 2 are free and 8 cost 3 each: 24. `total` never asks what kind of item it has. Adding a third conforming type later needs no change to it.
````

````exercise
id: m10-l03-e6
type: design
prompt: |
  You're modeling a music app's library. There are `Song` (a struct), `Podcast` (a struct) and `Audiobook` (a class, because chapters download in the background and several screens show progress). All three need to show a title and a duration in a single list, and the list must be sortable by duration. Sketch the protocol, which types conform, and how you'd sort the list. Say which standard protocols you'd add to which types and why.
rubric:
  - Defines a protocol with title and duration as { get } properties.
  - "Uses [any Playable] (or similar) for the mixed list."
  - "Sorts with sorted(by:) on duration, or explains why the protocol itself shouldn't be Comparable for a mixed list."
  - Adds Hashable or Equatable to the structs where it's useful, and explains the class needs hand-written conformances.
solution: |
  ```swift
  protocol Playable {
      var title: String { get }
      var durationInSeconds: Int { get }
  }

  struct Song: Playable, Hashable {
      let title: String
      let durationInSeconds: Int
  }

  struct Podcast: Playable, Hashable {
      let title: String
      let durationInSeconds: Int
      let episode: Int
  }

  final class Audiobook: Playable {
      let title: String
      let durationInSeconds: Int
      var downloadedChapters = 0

      init(title: String, durationInSeconds: Int) {
          self.title = title
          self.durationInSeconds = durationInSeconds
      }
  }

  let library: [any Playable] = [
      Song(title: "Intro", durationInSeconds: 200),
      Audiobook(title: "Swift Stories", durationInSeconds: 36_000),
      Podcast(title: "Weekly", durationInSeconds: 1_800, episode: 12),
  ]

  for item in library.sorted(by: { $0.durationInSeconds < $1.durationInSeconds }) {
      print(item.title)
  }
  ```

  ```output
  Intro
  Weekly
  Swift Stories
  ```

  The protocol holds only what the list needs. Sorting a mixed list works best with `sorted(by:)` and a closure on `durationInSeconds` (Module 7): making `Playable` itself `Comparable` would bring in `Equatable`'s `Self` requirement, which the next two lessons explain, and "less than" for unrelated types is a strange idea anyway. The structs get `Hashable` synthesized almost for free, useful for sets of favorites. `Audiobook` is a class, so if it needed `Hashable` you'd write `==` and `hash(into:)` yourself, probably on a stable id rather than the title.
````

## Summary

- A protocol lists requirements; a type conforms by declaring it and meeting each one. Structs, classes and enums can all conform.
- `{ get }` is satisfied by `let`, `var` or a computed property; `{ get set }` needs something settable.
- Mark requirements `mutating` if value types should be able to change themselves. Classes implement them without the keyword.
- An init requirement needs `required` in a non-final class.
- `any P` is a box that can hold any conforming value, so one array can mix types. Calls to requirements go through the conformance's witness table.
- Structs and enums get `Equatable` and `Hashable` synthesized when all their parts conform; classes write `==` and `hash(into:)` by hand. Hash what `==` compares.
- `Comparable`'s `<` must be a strict total order: compare the next field only when the previous ones are equal, or compare tuples.
