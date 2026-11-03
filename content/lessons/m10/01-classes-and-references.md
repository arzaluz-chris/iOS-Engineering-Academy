---
id: m10-l01
title: Classes and reference semantics
description: You declare classes, see side by side how a class instance is shared where a struct is copied, tell identity (===) from equality (==), learn what let means for a class, watch deinit run when the last reference goes away, and pick between struct and class.
module: m10
order: 1
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l06]
objectives:
  - Declare a class with stored properties and an initializer.
  - Predict what happens to the original when you change a copy of a struct and a second reference to a class instance.
  - Compare class instances by identity with === and by value with ==.
  - Explain what let does and doesn't freeze when it holds a class instance.
  - Say when deinit runs, and show it with a variable set to nil.
  - Choose between a struct and a class and give the reason.
terms:
  - term: Class
    definition: "A type declared with class. Its instances are reference types: variables hold a reference to one shared instance, not a copy of it."
  - term: Reference type
    definition: "A type whose values are shared when assigned or passed. Two variables can refer to the same instance, and a change made through one is visible through the other. Classes are reference types."
  - term: Value type
    definition: "A type whose values are copied when assigned or passed. Structs, enums, tuples and the standard collections are value types."
  - term: Identity
    definition: "Whether two references point to the same instance. Checked with === and !==, which only work on class instances."
  - term: deinit
    definition: "A block a class can declare that runs just before an instance is destroyed, when the last reference to it goes away."
  - term: Automatic Reference Counting (ARC)
    definition: "The way Swift manages class instances: it counts the strong references to each instance and frees the instance when the count drops to zero."
mastery:
  - Write a class with two stored properties and an init, and explain why the compiler demands the init.
  - Predict the output of a program that copies a struct and shares a class instance, then changes both.
  - Say whether a === b and a == b are true for two separately created instances with the same data.
  - Change a property through a let constant that holds a class instance, and explain why it compiles.
  - Predict on which line deinit prints when two variables share an instance and both are set to nil.
  - Defend "struct by default" and name two situations that call for a class.
resources: [swift-book-structures-classes, swift-book-initialization, swift-book-basics]
cards:
  - id: m10-l01-c1
    front: "a is a struct, b = a, then b.x = 9. What is a.x? What if a is a class instance?"
    back: "With a struct, a.x is unchanged: b is an independent copy. With a class, a.x is 9: a and b refer to the same instance."
  - id: m10-l01-c2
    front: What's the difference between === and ==?
    back: "=== asks whether two references point to the same instance (identity) and only works on classes. == asks whether two values are equal, and needs Equatable."
  - id: m10-l01-c3
    front: "let account = BankAccount(). Can you write account.balance = 10? Can you write account = BankAccount()?"
    back: "If balance is a var, the first compiles: let freezes the reference, not the instance. The second doesn't: you can't point a let at another instance."
  - id: m10-l01-c4
    front: When does a class's deinit run?
    back: "When the last strong reference to the instance goes away, for example when the only variable holding it is set to nil. Two variables sharing it both have to let go."
  - id: m10-l01-c5
    front: Struct or class by default, and when do you switch?
    back: "Struct by default. Use a class when the thing has an identity that several parts of the program must share and see change, when you need inheritance or deinit, or when a framework requires one."
---

## The idea in one sentence

Assigning a struct gives you a **copy**; assigning a class instance gives you **another reference to the same instance**, so a change through one name shows up through every other name.

## Declaring a class

A class looks a lot like the structs you wrote in Module 9:

```swift
class Player {
    var name: String
    var score: Int

    init(name: String, score: Int) {
        self.name = name
        self.score = score
    }

    func addPoints(_ points: Int) {
        score += points
    }
}

let player = Player(name: "Ana", score: 10)
player.addPoints(5)
print("\(player.name): \(player.score)")
```

```output
Ana: 15
```

Two differences from a struct already show up here.

1. **There's no memberwise initializer.** A struct gets `init(name:score:)` for free. A class doesn't, so every stored property needs either a default value or an `init` that sets it. Leave both out and the class doesn't compile.
2. **`addPoints` changes `score` without `mutating`.** In a struct, a method that changes a property must be marked `mutating`. In a class it doesn't, because the method changes the shared instance, not a value that belongs to the variable.

> [!error] error: class 'Player' has no initializers
> A class with stored properties that have no default values needs an `init`. Swift 6.3:

```swift no-compile class 'Player' has no initializers
class Player {
    var name: String
    var score: Int
}
```

If every stored property has a default, Swift gives the class an empty `init()`, but still no memberwise one: `Player(name: "Ana", score: 10)` would fail with "argument passed to call that takes no arguments".

## Copy versus share, side by side

Here's the same type written twice, once as a struct and once as a class:

```swift
struct PointValue {
    var x: Int
}

class PointObject {
    var x: Int
    init(x: Int) {
        self.x = x
    }
}

var valueA = PointValue(x: 1)
var valueB = valueA
valueB.x = 99
print("struct:", valueA.x, valueB.x)

let objectA = PointObject(x: 1)
let objectB = objectA
objectB.x = 99
print("class: ", objectA.x, objectB.x)
```

```output
struct: 1 99
class:  99 99
```

Line by line:

1. `var valueB = valueA` copies the struct. From now on there are two independent points.
2. `valueB.x = 99` changes only the copy. `valueA.x` is still 1.
3. `let objectB = objectA` does **not** create a second point. It creates a second name for the same instance.
4. `objectB.x = 99` changes that one instance, so `objectA.x` reads 99 too.

You saw value semantics with arrays in Module 7. Classes are the other kind: **reference semantics**.

The same thing happens when you pass a class instance to a function. A struct parameter is a constant copy, so the function can't change the caller's value. A class parameter is a constant *reference*: the function can't swap it for another instance, but it can change the instance's properties, and the caller sees the change.

```swift
struct ScoreValue {
    var points = 0
}

class ScoreObject {
    var points = 0
}

func reset(_ score: ScoreObject) {
    score.points = 0
}

let shared = ScoreObject()
shared.points = 40
reset(shared)
print(shared.points)

var local = ScoreValue()
local.points = 40
var copy = local
copy.points = 0
print(local.points)
```

```output
0
40
```

No `inout`, no `&`, and `reset` still changed the caller's object. That's convenient when sharing is what you want, and a source of bugs when it isn't: any code holding a reference can change the object under you.

## A mental model: stack and heap

A picture that helps, as long as you remember it's a picture:

- A **struct** value lives where the variable lives. `var valueB = valueA` copies the bytes into `valueB`'s own space. Think of local variables as living in a fast scratch area called the **stack**, which is cleaned up automatically when the function returns.
- A **class** instance lives in a separate area called the **heap**. The variable holds only a reference (an address) to it. `let objectB = objectA` copies the address, so both point at the same box. Swift also keeps a **reference count** in that box: how many strong references point at it. When the count reaches zero, the instance is destroyed. This is **Automatic Reference Counting**, ARC.

> [!warning] It's a model, not a guarantee
> The language promises the *behavior* (values copy, references share), not where the bytes go. The compiler can keep a class instance on the stack if it can prove no reference escapes, and it can move a value to the heap: an array's elements live in a heap buffer (that's how copy-on-write works), a value captured by a closure that outlives the function may be boxed on the heap, and so on. Use stack and heap to reason about semantics and rough cost, not as a rule about memory addresses.

## Identity and equality

With values, "equal" is the only question. With references there are two:

- **Identity**: are these two references pointing at the same instance? Swift's operator is `===` (and `!==` for "not the same instance").
- **Equality**: do these two instances hold equal data? That's `==`, and the type has to say what equal means by conforming to `Equatable`.

```swift
final class Ticket: Equatable {
    let seat: String

    init(seat: String) {
        self.seat = seat
    }

    static func == (lhs: Ticket, rhs: Ticket) -> Bool {
        lhs.seat == rhs.seat
    }
}

let first = Ticket(seat: "12A")
let second = Ticket(seat: "12A")
let sameAsFirst = first

print(first == second)
print(first === second)
print(first === sameAsFirst)
print(first !== second)
```

```output
true
false
true
true
```

`first` and `second` hold the same seat, so `==` says they're equal. But they're two separate instances, two boxes on the heap, so `===` says they're not identical. `sameAsFirst` is another reference to `first`'s box, so `===` is true.

`Equatable` is a **protocol**, and the `static func ==` is how `Ticket` satisfies it. Lesson 3 covers protocols properly; for now, read `: Equatable` as "this type promises to have an `==`", and the `static func` as a type method from Module 9. Structs and enums can get `==` written for them automatically; classes can't, so you write it yourself. (`final` stops anyone from subclassing `Ticket`. Lesson 2 explains why that matters.)

Identity doesn't exist for values. Two struct values with the same data are simply equal; there's no "same box" to ask about:

```swift no-compile expected to be an instance of a class or class-constrained type
struct Seat {
    let code: String
}

let a = Seat(code: "12A")
let b = Seat(code: "12A")
print(a === b)
```

Swift 6.3 reports `error: argument type 'Seat' expected to be an instance of a class or class-constrained type`.

## What let means for a class

With a struct, `let` freezes the whole value: you can't change any property. With a class, `let` freezes the **reference**. You can't point the constant at another instance, but the instance itself is as changeable as its `var` properties allow.

```swift
final class Counter {
    var count = 0
}

let counter = Counter()
counter.count += 1
counter.count += 1
print(counter.count)
```

```output
2
```

That compiles, because `counter` still refers to the same instance; only the instance changed. Reassigning the constant is what's forbidden:

```swift no-compile cannot assign to value: 'counter' is a 'let' constant
final class Counter {
    var count = 0
}

let counter = Counter()
counter = Counter()
```

If you want a class whose instances can't change after creation, make its stored properties `let`, as `Ticket` does with `seat`.

## deinit: when an instance goes away

A class can declare a `deinit` block. It runs once, just before the instance is destroyed, which happens when the last strong reference to it goes away. Structs don't have `deinit`: a value is copied freely, so there's no single instance whose end you could mark.

```swift
final class Session {
    let user: String

    init(user: String) {
        self.user = user
        print("Session for \(user) started")
    }

    deinit {
        print("Session for \(user) ended")
    }
}

var current: Session? = Session(user: "ana")
var backup = current
print("Two references")
current = nil
print("current is nil")
backup = nil
print("backup is nil")
```

```output
Session for ana started
Two references
current is nil
Session for ana ended
backup is nil
```

1. The `init` prints when the instance is created. `current` holds the only reference (count 1).
2. `var backup = current` copies the reference (count 2). Both optionals point at the same session.
3. `current = nil` drops one reference (count 1). The instance is still alive, so nothing prints.
4. `backup = nil` drops the last one (count 0). `deinit` runs **right there**, before the next `print`.

The variables are optionals (Module 8) because setting something to `nil` is the clearest way to drop a reference. A local variable going out of scope at the end of a function drops its reference too.

> [!note] Exactly when is "the last reference goes away"?
> Swift guarantees that an instance lives at least until its last use. It doesn't promise to keep it alive until the closing brace of the scope; an optimized build can end it a little earlier. Don't write code whose correctness depends on `deinit` running on a particular line. Use it for cleanup and, while learning, for watching ARC at work.

Real `deinit` jobs: closing a file or a network connection, removing an observer, logging. The memory module later shows the classic ARC bug, two objects holding strong references to each other so neither count ever reaches zero.

## Struct or class?

Swift's own guidance, and this course's default: **use a struct unless you have a reason not to.** Values are easier to reason about. Nobody else can change your copy, so a function's effects are visible in its signature, and there's no shared state to coordinate.

Reasons to reach for a class:

- **The thing has an identity that several parts of the program share.** A playback session, a download in progress, a cache: when one screen changes it, every other screen holding it should see the change, and "is this the same download?" is a meaningful question.
- **You need inheritance** (next lesson) or **`deinit`**.
- **A framework requires it.** UIKit's view controllers are classes; so are many Apple APIs you'll subclass or pass around.

A practical example of the first case: two parts of an app that must agree on a cart.

```swift
final class Cart {
    var items: [String] = []

    func add(_ item: String) {
        items.append(item)
    }
}

struct ProductScreen {
    let cart: Cart

    func buy(_ item: String) {
        cart.add(item)
    }
}

struct CartBadge {
    let cart: Cart

    func text() -> String {
        "Cart (\(cart.items.count))"
    }
}

let cart = Cart()
let productScreen = ProductScreen(cart: cart)
let badge = CartBadge(cart: cart)

print(badge.text())
productScreen.buy("Coffee")
productScreen.buy("Bread")
print(badge.text())
```

```output
Cart (0)
Cart (2)
```

Both screens are structs, but they hold a reference to the same `Cart`, so the badge sees what the product screen added. If `Cart` were a struct, each screen would hold its own copy, `buy` wouldn't even compile (it would need `mutating` and a `var`), and the badge would stay at 0.

> [!note] Classes and Swift 6 concurrency
> In Swift 6, a class with mutable properties isn't safe to share between concurrent tasks, so the compiler won't let you send one across them unless you prove it's safe. Structs made of safe parts get that for free. You'll meet this in the concurrency module. In this module every example runs top to bottom in one place, so it doesn't come up.

## Common mistakes

> [!error] error: class 'Player' has no initializers
> You expected a memberwise init. Classes don't get one. Give each stored property a default or write an `init`.

> [!error] Expecting a copy
> `let backup = settings` followed by changes to `settings` changes `backup` too, when `settings` is a class instance. If you need a snapshot, copy the data into a new instance or make the type a struct.

> [!error] error: argument type 'Seat' expected to be an instance of a class or class-constrained type
> You used `===` on structs. Identity only exists for class instances. Use `==` and make the struct `Equatable`.

> [!error] Thinking let makes an object read-only
> `let` on a class instance only stops reassignment. Anyone holding the reference can still change its `var` properties. Make the properties `let`, or make the type a struct.

> [!error] Using == when you meant ===
> For a class that's `Equatable`, `==` compares data. "Is this the same download object?" is `===`. Two downloads of the same URL can be equal and still be different objects.

````exercise
id: m10-l01-e1
type: comprehension
prompt: |
  `Note` is a class with a `var text: String`. What does this print?

  ```swift
  let original = Note(text: "draft")
  let other = original
  other.text = "final"
  print(original.text)
  ```
choices:
  - text: draft
    correct: false
    why: "That would be true for a struct. other is a second reference to the same instance, not a copy."
  - text: final
    correct: true
    why: original and other refer to one instance, so the change through other is visible through original.
  - text: It doesn't compile, because other is a let.
    correct: false
    why: let freezes the reference, not the instance. Changing a var property through it is allowed.
  - text: It doesn't compile, because classes need mutating to change a property.
    correct: false
    why: mutating is for methods on value types. Classes never use it.
solution: |
  **final.** `let other = original` copies the reference, so both names point at the same `Note`. Setting `other.text` changes that instance, and reading `original.text` reads the same instance. `let` only stops `other` from being pointed at a different note.
````

````exercise
id: m10-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Box {
      var count: Int
  }

  final class Crate {
      var count: Int
      init(count: Int) {
          self.count = count
      }
  }

  var boxes = [Box(count: 1), Box(count: 1)]
  let crate = Crate(count: 1)
  let crates = [crate, crate]

  var firstBox = boxes[0]
  firstBox.count = 5
  crates[0].count = 5

  print(boxes[0].count, boxes[1].count)
  print(crates[0].count, crates[1].count, crate.count)
  boxes[1].count = 7
  print(boxes[0].count, boxes[1].count)
output: |
  1 1
  5 5 5
  1 7
hints:
  - "var firstBox = boxes[0] copies a struct out of the array."
  - "crates holds the same reference twice."
solution: |
  ```output
  1 1
  5 5 5
  1 7
  ```

  1. `firstBox` is a copy of `boxes[0]`. Changing it leaves the array alone, so both boxes still have 1.
  2. The array `crates` holds two references to the **same** `Crate`. `crates[0].count = 5` changes that one instance, so all three reads see 5. Notice `crates` is a `let` array and the line still compiles: the array of references didn't change, the instance did.
  3. `boxes[1].count = 7` changes the element in place, because `boxes` is a `var` and you're writing through the subscript. Only that element changes.
````

````exercise
id: m10-l01-e3
type: prediction
prompt: Predict the exact output, including where the deinit line appears.
code: |
  final class Lamp {
      let room: String
      init(room: String) {
          self.room = room
      }
      deinit {
          print("\(room) lamp removed")
      }
  }

  var kitchen: Lamp? = Lamp(room: "Kitchen")
  var hall: Lamp? = Lamp(room: "Hall")
  var spare = hall
  print("A")
  hall = nil
  print("B")
  kitchen = nil
  print("C")
  spare = nil
  print("D")
output: |
  A
  B
  Kitchen lamp removed
  C
  Hall lamp removed
  D
hints:
  - Count the references to each lamp.
  - "spare = hall copies a reference."
solution: |
  ```output
  A
  B
  Kitchen lamp removed
  C
  Hall lamp removed
  D
  ```

  The hall lamp has two references (`hall` and `spare`), so `hall = nil` leaves it alive and nothing prints between A and B. The kitchen lamp has one, so `kitchen = nil` destroys it right away. The hall lamp goes when `spare`, its last reference, is set to `nil`.
````

````exercise
id: m10-l01-e4
type: fill-in
prompt: |
  Complete the code so it prints `true false`: the first comparison checks the data, the second checks whether both names refer to the same instance.
code: |
  final class Badge: Equatable {
      let number: Int
      [[1]](number: Int) {
          self.number = number
      }
      static func == (lhs: Badge, rhs: Badge) -> Bool {
          lhs.number == rhs.number
      }
  }

  let mine = Badge(number: 7)
  let yours = Badge(number: 7)
  print(mine [[2]] yours, mine [[3]] yours)
blanks:
  - id: "1"
    answers: ["init"]
  - id: "2"
    answers: ["=="]
  - id: "3"
    answers: ["==="]
solution: |
  ```swift
  final class Badge: Equatable {
      let number: Int
      init(number: Int) {
          self.number = number
      }
      static func == (lhs: Badge, rhs: Badge) -> Bool {
          lhs.number == rhs.number
      }
  }

  let mine = Badge(number: 7)
  let yours = Badge(number: 7)
  print(mine == yours, mine === yours)
  ```

  ```output
  true false
  ```

  The class needs its own `init`: there's no memberwise one. `==` uses the `static func ==` you wrote, which compares numbers. `===` compares identity, and `mine` and `yours` were created separately, so they're two instances.
````

````exercise
id: m10-l01-e5
type: solve
prompt: |
  Write a class `BankAccount` with:

  - a `let owner: String`,
  - a `var balance: Int`, starting at 0,
  - `func deposit(_ amount: Int)` that adds the amount,
  - `func withdraw(_ amount: Int) -> Bool` that subtracts the amount and returns `true` only if the balance is enough; otherwise it changes nothing and returns `false`.

  Then write a struct `ATM` with a `let account: BankAccount` and a method `func takeCash(_ amount: Int) -> String` that returns `"Dispensed X"` or `"Insufficient funds"`.

  This code must print the output below:

  ```swift
  let account = BankAccount(owner: "Christian")
  account.deposit(100)
  let atm = ATM(account: account)
  print(atm.takeCash(30))
  print(atm.takeCash(80))
  print(account.balance)
  ```

  ```output
  Dispensed 30
  Insufficient funds
  70
  ```
starter: |
  class BankAccount {
      // your code
  }

  struct ATM {
      // your code
  }
hints:
  - "The class needs init(owner:) because there's no memberwise init. balance can have a default of 0."
  - "In withdraw, guard amount <= balance else { return false }."
  - "takeCash doesn't need mutating: it changes the account instance, not the ATM struct."
rubric:
  - BankAccount is a class with an init that sets owner.
  - withdraw refuses without changing anything when the balance is too low.
  - ATM holds the same instance the caller created, so the caller sees the new balance.
  - The output matches exactly.
solution: |
  ```swift
  final class BankAccount {
      let owner: String
      var balance = 0

      init(owner: String) {
          self.owner = owner
      }

      func deposit(_ amount: Int) {
          balance += amount
      }

      func withdraw(_ amount: Int) -> Bool {
          guard amount <= balance else {
              return false
          }
          balance -= amount
          return true
      }
  }

  struct ATM {
      let account: BankAccount

      func takeCash(_ amount: Int) -> String {
          if account.withdraw(amount) {
              return "Dispensed \(amount)"
          }
          return "Insufficient funds"
      }
  }

  let account = BankAccount(owner: "Christian")
  account.deposit(100)
  let atm = ATM(account: account)
  print(atm.takeCash(30))
  print(atm.takeCash(80))
  print(account.balance)
  ```

  ```output
  Dispensed 30
  Insufficient funds
  70
  ```

  `ATM` stores a reference to the caller's account, so the withdrawal it makes is visible through `account`. `takeCash` isn't `mutating` even though money moves, because the struct's own stored property (the reference) never changes. If `BankAccount` were a struct, the ATM would hold its own copy and the last line would print 100. A bank account is a reasonable class: it has an identity ("this account"), and everyone who touches it must see the same balance. `final` is optional here; it says no subclass is planned.
````

````exercise
id: m10-l01-e6
type: find-errors
prompt: Pick out the real problems in this code.
code: |
  class Thermostat {
      var target: Int
      var history: [Int]

      mutating func set(_ value: Int) {
          history.append(target)
          target = value
      }
  }

  let hallway = Thermostat()
  hallway.set(21)
  let office = hallway
  office.set(19)
  print(hallway.target)
choices:
  - text: "The class has no initializer, and target and history have no default values."
    correct: true
    why: "Classes get no memberwise init. Swift reports \"class 'Thermostat' has no initializers\"."
  - text: "mutating isn't allowed on a class method."
    correct: true
    why: "Methods of a class can change properties without it. The compiler rejects mutating here: \"'mutating' is not valid on instance methods in classes\"."
  - text: "hallway is a let, so hallway.set(21) can't change it."
    correct: false
    why: let freezes the reference. Changing the instance's var properties through it is fine.
  - text: "Once it compiles, office.set(19) also changes hallway, so the program prints 19, not 21."
    correct: true
    why: "office = hallway shares the instance. If two rooms need separate thermostats, create two instances."
rubric:
  - I added an init or default values.
  - I removed mutating.
  - I created a separate instance for the office if the rooms are meant to be independent.
solution: |
  ```swift
  final class Thermostat {
      var target = 20
      var history: [Int] = []

      func set(_ value: Int) {
          history.append(target)
          target = value
      }
  }

  let hallway = Thermostat()
  hallway.set(21)
  let office = Thermostat()
  office.set(19)
  print(hallway.target, office.target, hallway.history)
  ```

  ```output
  21 19 [20]
  ```

  Two compile errors and one logic bug. With defaults on both properties, the class gets an empty `init()`. `mutating` goes away because class methods change the shared instance directly. And `let office = hallway` gave the office the hallway's thermostat; two rooms need two instances.
````

## Summary

- A class instance is shared: assigning it or passing it hands out another reference to the same instance. A struct is copied.
- Classes get no memberwise initializer, and their methods change properties without `mutating`.
- `===` and `!==` check identity (same instance) and only work on classes. `==` checks equality and needs `Equatable`, which you write yourself for a class.
- `let` on a class instance freezes the reference, not the instance's `var` properties.
- `deinit` runs when the last strong reference goes away. ARC counts the references.
- Stack and heap are a useful model of value versus reference, not a promise about where memory lives.
- Struct by default. Use a class for shared identity, inheritance, `deinit`, or when a framework requires it.
