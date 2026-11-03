---
id: m11-l04
title: "Closures in depth: capturing values"
description: You go from the full closure syntax to $0 and operator functions, see a closure capture and change variables from the code around it, build a counter factory whose state outlives the function that made it, freeze a value with a capture list, break a reference cycle with [weak self], and learn that closures are reference types.
module: m11
order: 4
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l03]
objectives:
  - Shorten a closure from its full form to shorthand arguments and to an operator function, and choose the clearest form.
  - Explain what it means for a closure to capture a variable, and predict what it prints after the variable changes.
  - Write a function that returns a closure with its own private state.
  - Use a capture list to copy a value at the moment the closure is created.
  - Recognize a closure stored in a class that captures self strongly, and break the cycle with [weak self].
  - Explain why two constants holding the same closure share its captured state.
terms:
  - term: Capture
    definition: "When a closure uses a variable or constant from the scope where it was written, it captures it: the closure keeps it alive and, for a var, sees and makes changes to the same variable."
  - term: Capture list
    definition: "A list in square brackets before a closure's parameters, like { [count] in … } or { [weak self] in … }. Each entry is evaluated when the closure is created; plain names are copied as constants."
  - term: Shorthand argument names
    definition: "$0, $1, $2… stand for a closure's parameters in order, so you can drop the parameter list and the in keyword: { $0 < $1 }."
  - term: Reference cycle (with a closure)
    definition: "An object stores a closure, and the closure captures the object strongly. Each keeps the other alive, so neither is ever freed."
  - term: Closures are reference types
    definition: "Assigning a closure to another constant doesn't copy its captured state. Both names refer to the same closure and the same captured variables."
mastery:
  - "Rewrite { (a: Int, b: Int) -> Bool in return a > b } as { $0 > $1 } and as >."
  - Predict the output of a closure that reads a variable after the variable changed.
  - "Write makeCounter() -> () -> Int and explain why its count survives after makeCounter returns."
  - Use [value] to freeze a value, and read "is an immutable capture".
  - Add [weak self] to a closure stored in a property and show with deinit that the object is freed.
  - "Fix \"reference to property … in closure requires explicit use of 'self'\"."
resources: [swift-book-arc, swift-book-closures, swift-book-functions]
cards:
  - id: m11-l04-c1
    front: "var x = 1; let show = { print(x) }; x = 2; show(). What prints?"
    back: "2. A closure captures the variable itself, not a copy of its value, so it sees later changes."
  - id: m11-l04-c2
    front: "var x = 1; let show = { [x] in print(x) }; x = 2; show(). What prints?"
    back: "1. A capture list copies the value when the closure is created, as an immutable constant."
  - id: m11-l04-c3
    front: "Why does makeCounter()'s count keep going after makeCounter returns?"
    back: "The returned closure captured count, so count lives as long as the closure does. Each call to makeCounter creates a new count."
  - id: m11-l04-c4
    front: "When do you need [weak self] in a closure?"
    back: "When the object stores the closure (directly or through something it owns) and the closure uses self. Otherwise each keeps the other alive forever."
  - id: m11-l04-c5
    front: "let a = makeCounter(); let b = a. Do a and b count separately?"
    back: "No. Closures are reference types: a and b are the same closure with the same captured count."
---

## The idea in one sentence

A closure can use the variables around the place it's written, and it doesn't take a snapshot: it **captures the variable itself**, keeps it alive as long as the closure exists, and sees every change, unless you ask for a copy with a capture list.

Module 6 introduced closures and promised that capturing would get its own lesson. Here it is. First, the rest of the syntax.

## From full form to shorthand

Every form below is the same closure, passed to `sorted(by:)`, which takes a function `(Element, Element) -> Bool` that says whether the first argument goes before the second:

```swift
let prices = [30, 10, 20]

let a = prices.sorted(by: { (left: Int, right: Int) -> Bool in
    return left > right
})
let b = prices.sorted(by: { left, right in left > right })
let c = prices.sorted { left, right in left > right }
let d = prices.sorted { $0 > $1 }
let e = prices.sorted(by: >)

print(a, b, c, d, e)
```

```output
[30, 20, 10] [30, 20, 10] [30, 20, 10] [30, 20, 10] [30, 20, 10]
```

1. **Full form**: parameter names and types, return type, `in`, `return`.
2. **Inferred types**: `sorted(by:)` already says the parameters are `Int` and the result is `Bool`, so the types go. A single-expression body returns its value without `return`.
3. **Trailing closure** (Module 6): the closure moves after the call and the `by:` label disappears.
4. **Shorthand argument names**: `$0` is the first parameter, `$1` the second. With them, the parameter list and `in` go too.
5. **Operator function**: `>` is itself a function of type `(Int, Int) -> Bool`, so you can pass it by name, as you passed `double` in Module 6.

Which one to write? Use `$0` when the closure is short and the meaning is obvious from the call: `map { $0 * 2 }`, `filter { $0 > 0 }`. Name the parameters when the closure has several lines, when there are two or more parameters whose roles matter, or when `$0` would be a struct whose properties you read several times. `{ order in order.total > 100 }` tells the reader what `$0` would make them work out.

A closure with several statements needs `return`, as a function does:

```swift
let orders = [120, 40, 75]
let labels = orders.map { total in
    let tier = total >= 100 ? "large" : "small"
    return "\(total): \(tier)"
}
print(labels)
```

```output
["120: large", "40: small", "75: small"]
```

## Capturing a variable

A closure can read and change variables that exist where it was written:

```swift
var total = 0
let add = { (amount: Int) in
    total += amount
}

add(5)
add(3)
print(total)
```

```output
8
```

`add` has no parameter called `total` and doesn't return anything. It reaches out to the `total` declared above it and changes that variable. This is **capturing**: the closure holds on to `total` itself, not to a copy of its value at the moment `add` was created.

The consequence: a closure that runs later sees the value **at the time it runs**.

```swift
var greeting = "Hello"
let greet = { print("\(greeting), Ana") }

greeting = "Goodbye"
greet()
```

```output
Goodbye, Ana
```

`greet` was created while `greeting` was `"Hello"`, but it captured the variable, and when it runs the variable says `"Goodbye"`.

## A closure that outlives its function: the counter factory

Capturing matters most when the closure leaves the function that created it:

```swift
func makeCounter() -> () -> Int {
    var count = 0
    return {
        count += 1
        return count
    }
}

let tapCounter = makeCounter()
print(tapCounter())
print(tapCounter())
print(tapCounter())

let viewCounter = makeCounter()
print(viewCounter())
print(tapCounter())
```

```output
1
2
3
1
4
```

Line by line:

1. `makeCounter` returns a value of type `() -> Int`: a function with no parameters that returns an `Int`.
2. Inside, `var count = 0` is a local variable. Normally it would disappear when `makeCounter` returns.
3. The returned closure captures `count`. As long as the closure exists, so does `count`. Nothing outside can reach it except through the closure: it's **private state**.
4. Each call to `tapCounter()` adds one to the same `count`: 1, 2, 3.
5. `makeCounter()` called again creates a **new** `count` and a new closure. `viewCounter` starts at 1, and `tapCounter` is unaffected, going on to 4.

A closure that captures state is a lot like a tiny object with one method. That's not a coincidence; many problems you'd solve with a small class can be solved with a closure, and the reverse.

## Closures are reference types

What happens when you assign a closure to another constant?

```swift
func makeCounter() -> () -> Int {
    var count = 0
    return {
        count += 1
        return count
    }
}

let first = makeCounter()
let second = first

print(first())
print(second())
print(first())
```

```output
1
2
3
```

`second` isn't a copy of the closure with a copy of `count`. It's **the same closure**, the way two constants can hold the same class instance (Module 10). Both names share one `count`. Structs, enums and arrays are copied on assignment; closures, like classes, are shared.

## Capture lists: taking a copy on purpose

Sometimes you want the value as it was when the closure was created. Put the name in a **capture list**, in square brackets before the parameters (or before `in` if there are none):

```swift
var price = 100
let live = { print("live: \(price)") }
let frozen = { [price] in print("frozen: \(price)") }

price = 120
live()
frozen()
```

```output
live: 120
frozen: 100
```

`[price]` evaluates `price` once, when the closure is created, and stores the value in a new **constant** with the same name, visible only inside the closure. Later changes to the outer variable don't reach it.

Because it's a constant, you can't change it inside:

```swift no-compile 'price' is an immutable capture
var price = 100
let bump = { [price] in
    price += 1
}
```

Swift 6.3: `error: left side of mutating operator isn't mutable: 'price' is an immutable capture`. If you need mutable private state, capture a `var` without the list, as `makeCounter` does.

A capture list entry can also have a new name and any expression: `{ [start = total] in … }` stores the current value of `total` as `start`.

### Loops create a fresh constant each time

A `for` loop's constant is a new constant on every iteration, so closures created in the loop each capture their own:

```swift
var actions: [() -> String] = []
for number in 1...3 {
    actions.append { "item \(number)" }
}

var step = 0
var steps: [() -> String] = []
while step < 3 {
    step += 1
    steps.append { "step \(step)" }
}

print(actions.map { action in action() })
print(steps.map { action in action() })
```

```output
["item 1", "item 2", "item 3"]
["step 3", "step 3", "step 3"]
```

The `while` loop has one `step` variable shared by all three closures. By the time they run, it's 3. Write `{ [step] in "step \(step)" }` and you'd get 1, 2, 3.

## Capturing self, and [weak self]

When a class stores a closure in a property and that closure uses the instance's own properties, Swift makes you write `self` explicitly:

```swift no-compile requires explicit use of 'self' to make capture semantics explicit
final class Scoreboard {
    var score = 0
    var onGoal: (() -> Void)?

    func start() {
        onGoal = { score += 1 }
    }
}
```

Swift 6.3: `error: reference to property 'score' in closure requires explicit use of 'self' to make capture semantics explicit`. The message is a warning about memory dressed as a syntax rule. The closure captures `self`, the `Scoreboard`. The `Scoreboard` stores the closure in `onGoal`. Each now keeps the other alive: a **reference cycle**. When the rest of the program lets go of the scoreboard, its `deinit` never runs.

```swift
final class Scoreboard {
    var score = 0
    var onGoal: (() -> Void)?

    func start() {
        onGoal = { self.score += 1 }
    }

    deinit {
        print("Scoreboard freed")
    }
}

var board: Scoreboard? = Scoreboard()
board?.start()
board?.onGoal?()
print(board?.score ?? -1)
board = nil
print("end")
```

```output
1
end
```

`board = nil` drops the last outside reference, yet "Scoreboard freed" never prints. The fix is to capture `self` **weakly**:

```swift
final class Scoreboard {
    var score = 0
    var onGoal: (() -> Void)?

    func start() {
        onGoal = { [weak self] in
            self?.score += 1
        }
    }

    deinit {
        print("Scoreboard freed")
    }
}

var board: Scoreboard? = Scoreboard()
board?.start()
board?.onGoal?()
print(board?.score ?? -1)
board = nil
print("end")
```

```output
1
Scoreboard freed
end
```

`[weak self]` is a capture list entry. It captures a weak reference, one that doesn't keep the object alive, and turns `self` into an optional inside the closure: `nil` once the object is gone. That's why the body says `self?.score`. You'll often see it written with `guard let self else { return }` as the first line, which unwraps it once for the rest of the closure.

You don't need `[weak self]` everywhere. The cycle needs both halves: the object (directly or through something it owns) **stores** the closure, and the closure captures the object. A closure you pass to `map` runs and is gone before the call returns, so it can't form a cycle. Module 13 (Memory and ARC) covers `weak`, `unowned` and how to find cycles with Xcode's Memory Graph Debugger.

> [!note] Swift 6 and captured state
> When a closure is handed to code that might run it on another thread, Swift 6 checks that what it captures is safe to share, and you may see errors that mention `Sendable`. None of the closures in this lesson leave the main thread, so they don't trigger it. Module 29 (Swift Concurrency) explains those rules properly.

## A practical example: a debounced search counter

Search fields often wait until the user stops typing before sending a request. Here's the bookkeeping part of that idea, built only from captured state: every keystroke gets a ticket number, and only the newest ticket is allowed to search.

```swift
func makeSearchGate() -> (keystroke: () -> Int, isLatest: (Int) -> Bool) {
    var latestTicket = 0
    let keystroke = {
        latestTicket += 1
        return latestTicket
    }
    let isLatest = { (ticket: Int) in
        ticket == latestTicket
    }
    return (keystroke, isLatest)
}

let gate = makeSearchGate()
let ticketS = gate.keystroke()
let ticketW = gate.keystroke()
let ticketI = gate.keystroke()

for (letter, ticket) in [("s", ticketS), ("w", ticketW), ("i", ticketI)] {
    print(letter, gate.isLatest(ticket) ? "search" : "skip")
}
```

```output
s skip
w skip
i search
```

Both closures capture the **same** `latestTicket`. `keystroke` changes it; `isLatest` reads it. Neither can be called without the other's state being up to date, and no other code can touch `latestTicket` at all. (A real debounce also needs a timer; that part comes with concurrency in Modules 28 and 29.)

## Common mistakes

> [!error] Expecting a snapshot
> `let show = { print(score) }` prints the value `score` has when `show()` runs, not when it was written. If you need the value at creation time, write `{ [score] in print(score) }`.

> [!error] error: left side of mutating operator isn't mutable: 'x' is an immutable capture
> Names in a capture list are copied into constants. To keep mutable state, capture the variable itself (leave it out of the list).

> [!error] error: reference to property … in closure requires explicit use of 'self'
> A closure that may be stored (here, in a property) uses the instance's properties. Writing `self.` makes the capture visible. Then ask whether it creates a cycle, and if so use `[weak self]`.

> [!error] Thinking let second = first copies a closure's state
> Closures are reference types. Two constants holding the same closure share its captured variables. Call the factory again to get independent state.

> [!error] $0 soup
> `{ $0.items.filter { $0.price > $1 } }` doesn't even compile: the inner `$0` and `$1` belong to the inner closure. Name the parameters as soon as the closure is longer than a line or nests another closure.

````exercise
id: m11-l04-e1
type: comprehension
prompt: "What does `{ [limit] in count < limit }` capture, if both `limit` and `count` are `var`s declared above it?"
choices:
  - text: "Copies of both values, taken when the closure is created."
    correct: false
    why: "Only names in the capture list are copied. count isn't in it."
  - text: "A copy of limit taken when the closure is created, and the variable count itself."
    correct: true
    why: "limit is in the capture list, so it's copied into a constant. count is captured as the variable, so later changes are visible."
  - text: "Both variables themselves; the capture list only makes limit read-only."
    correct: false
    why: "The capture list evaluates limit once and stores the value. Later changes to the outer limit don't reach the closure."
  - text: "Nothing until the closure is called."
    correct: false
    why: "The capture list is evaluated when the closure is created, not when it's called."
solution: |
  **A copy of `limit` from creation time, and the live variable `count`.** A capture list affects exactly the names it lists. Everything else the closure uses is captured by reference to the variable, so it sees changes made after the closure was created.
````

````exercise
id: m11-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  func makeAccumulator(start: Int) -> (Int) -> Int {
      var total = start
      return { amount in
          total += amount
          return total
      }
  }

  let wallet = makeAccumulator(start: 10)
  let alias = wallet
  let savings = makeAccumulator(start: 100)

  print(wallet(5))
  print(alias(5))
  print(savings(1))
  print(wallet(0))
output: |
  15
  20
  101
  20
hints:
  - "alias is the same closure as wallet, not a new one."
  - "savings came from a separate call to makeAccumulator."
solution: |
  ```output
  15
  20
  101
  20
  ```

  1. `wallet` captured its own `total`, starting at 10. Adding 5 gives 15.
  2. `alias` is the same closure (closures are reference types), so it adds to the same `total`: 20.
  3. `savings` came from a second call, so it has a separate `total` starting at 100.
  4. `wallet(0)` reads the shared `total`, still 20 after `alias` changed it.
````

````exercise
id: m11-l04-e3
type: prediction
prompt: Predict the exact output.
code: |
  var discount = 10
  let current = { (price: Int) in price - discount }
  let launch = { [discount] (price: Int) in price - discount }

  discount = 25
  print(current(100), launch(100))

  var messages: [() -> String] = []
  var attempt = 0
  for name in ["Ana", "Bo"] {
      attempt += 1
      messages.append { [attempt] in "\(name) #\(attempt)" }
      messages.append { "\(name) last #\(attempt)" }
  }
  for message in messages {
      print(message())
  }
output: |
  75 90
  Ana #1
  Ana last #2
  Bo #2
  Bo last #2
hints:
  - "A capture list comes before the closure's parameters: [discount] (price: Int) in …"
  - "name is a new constant on each iteration; attempt is one variable shared by all closures."
solution: |
  ```output
  75 90
  Ana #1
  Ana last #2
  Bo #2
  Bo last #2
  ```

  1. `current` captured the variable `discount`, which is 25 when it runs: 75. `launch` copied 10 at creation: 90.
  2. In the loop, `name` is a fresh constant each iteration, so every closure sees its own name.
  3. `[attempt]` copies the counter at that moment: 1 in the first iteration, 2 in the second.
  4. The closures without the capture list share the one `attempt` variable, which is 2 by the time anything runs.
````

````exercise
id: m11-l04-e4
type: fill-in
prompt: |
  Fill in the blanks with the shortest forms so the program prints `[9, 4, 1]` and then `[2, 4]`.
code: |
  let numbers = [1, 4, 9]
  print(numbers.sorted(by: [[1]]))
  print([1, 2, 3, 4].filter { [[2]] % 2 == 0 })
blanks:
  - id: "1"
    answers: [">"]
  - id: "2"
    answers: ["$0"]
solution: |
  ```swift
  let numbers = [1, 4, 9]
  print(numbers.sorted(by: >))
  print([1, 2, 3, 4].filter { $0 % 2 == 0 })
  ```

  ```output
  [9, 4, 1]
  [2, 4]
  ```

  `sorted(by:)` needs a function `(Int, Int) -> Bool`, and the operator `>` is exactly that, so you can pass it by name. In `filter`, `$0` is the closure's only parameter, the current element. Both are fine here because the meaning is obvious from the call; the full forms would be `{ a, b in a > b }` and `{ n in n % 2 == 0 }`.
````

````exercise
id: m11-l04-e5
type: find-errors
prompt: Which choices describe real problems in this code?
code: |
  final class Player {
      var name = "Ana"
      var health = 100
      var onHit: (() -> Void)?

      func setUp() {
          onHit = {
              self.health -= 10
          }
      }

      func snapshot() -> () -> String {
          return { [health] in
              health -= 1
              return "\(self.name): \(health)"
          }
      }
  }

  let scores = [3, 1, 2]
  let ordered = scores.sorted { [weak self] in $0 < $1 }
choices:
  - text: "onHit captures self strongly while self stores onHit: a reference cycle."
    correct: true
    why: "The Player owns the closure and the closure owns the Player. Use [weak self]."
  - text: "In snapshot, health is an immutable capture and can't be decremented."
    correct: true
    why: "Capture list names are constants inside the closure."
  - text: "[weak self] at the bottom is used outside any class, where there's no self to capture."
    correct: true
    why: "Top-level code has no self. And a closure passed to sorted runs immediately, so it couldn't form a cycle anyway."
  - text: "sorted's closure must name its parameters; $0 and $1 aren't allowed with a trailing closure."
    correct: false
    why: "Shorthand names work in any closure, trailing or not."
rubric:
  - Flags the strong self capture in onHit and fixes it with [weak self].
  - Flags the mutation of an immutable capture.
  - Flags [weak self] where there's no self.
  - Doesn't flag $0 and $1 in a trailing closure.
solution: |
  ```swift
  final class Player {
      var name = "Ana"
      var health = 100
      var onHit: (() -> Void)?

      func setUp() {
          onHit = { [weak self] in
              self?.health -= 10
          }
      }

      func snapshot() -> () -> String {
          return { [name, health] in
              "\(name): \(health)"
          }
      }

      deinit {
          print("Player freed")
      }
  }

  var player: Player? = Player()
  player?.setUp()
  player?.onHit?()
  let report = player?.snapshot()
  player?.onHit?()
  print(report?() ?? "none")
  print(player?.health ?? 0)
  player = nil

  let ordered = [3, 1, 2].sorted { $0 < $1 }
  print(ordered)
  ```

  ```output
  Ana: 90
  80
  Player freed
  [1, 2, 3]
  ```

  `onHit` gets `[weak self]`, so `player = nil` frees the object and `deinit` runs. The snapshot copies both `name` and `health` when it's taken, which is the point of a snapshot: it reports 90 even after the second hit. Copying `name` too means the snapshot doesn't hold the player alive. The `sorted` closure just loses its capture list.
````

````exercise
id: m11-l04-e6
type: solve
prompt: |
  Write `func makeIDGenerator(prefix: String) -> () -> String`. Each generator returns `"<prefix>-1"`, then `"<prefix>-2"`, and so on. Two generators must count independently.

  ```swift
  let userID = makeIDGenerator(prefix: "user")
  let orderID = makeIDGenerator(prefix: "order")
  print(userID())
  print(userID())
  print(orderID())
  print(userID())
  ```

  ```output
  user-1
  user-2
  order-1
  user-3
  ```
starter: |
  func makeIDGenerator(prefix: String) -> () -> String {
      // your code
  }
hints:
  - "Declare a var counter inside makeIDGenerator, before the closure."
  - "The closure adds one to the counter and returns the interpolated string."
rubric:
  - The counter is a local var captured by the returned closure.
  - Each call to makeIDGenerator has its own counter.
  - No global variables.
  - The output matches exactly.
solution: |
  ```swift
  func makeIDGenerator(prefix: String) -> () -> String {
      var next = 0
      return {
          next += 1
          return "\(prefix)-\(next)"
      }
  }

  let userID = makeIDGenerator(prefix: "user")
  let orderID = makeIDGenerator(prefix: "order")
  print(userID())
  print(userID())
  print(orderID())
  print(userID())
  ```

  ```output
  user-1
  user-2
  order-1
  user-3
  ```

  The closure captures two things: `prefix`, a parameter (a constant), and `next`, a local variable. Both live as long as the closure. Each call to `makeIDGenerator` runs the function body again, so it creates a fresh `next`, which is why `orderID` starts at 1. A global counter would have made `orderID()` print `order-3`.
````

## Summary

- Closure syntax shortens step by step: inferred types, implicit `return` for one expression, trailing closures, `$0`/`$1`, and passing an operator like `>` directly. Name parameters when the closure is long or nested.
- A closure captures the **variables** it uses, not their values. It sees later changes and can make its own.
- Captured variables live as long as the closure. A function can return a closure with private state, like `makeCounter`.
- Closures are reference types: two names for one closure share its captured state.
- A capture list `[x]` copies `x` into a constant when the closure is created. `for` loops give each iteration a fresh constant.
- A closure stored by an object that captures that object strongly creates a cycle. `[weak self]` breaks it; `self` becomes optional inside. Module 13 goes deeper.
