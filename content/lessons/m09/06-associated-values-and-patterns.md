---
id: m09-l06
title: "Associated values and pattern matching"
description: You attach data to enum cases with associated values, pull it out with switch, if case and guard case, refine matches with where, build recursive enums with indirect, model a screen's loading state so impossible states can't exist, and close the module with a small library program built from structs and enums.
module: m09
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l05]
objectives:
  - Declare enum cases with associated values, labeled or not, and create values of them.
  - Extract associated values with switch, case let, if case and guard case.
  - Refine a pattern with where and combine patterns that bind the same names.
  - Declare a recursive enum with indirect and process it with a recursive function.
  - Model a state machine with an enum so that invalid combinations of state can't be represented.
  - Combine structs and enums to model a small domain.
terms:
  - term: Associated value
    definition: "Data attached to a particular enum value when it's created, like the 4242 in .card(last4: \"4242\"). Different values of the same case can carry different data."
  - term: Pattern
    definition: "A description of the shape of a value that switch, if case, guard case and for case try to match, optionally binding parts of it to names. .card(let last4) is a pattern."
  - term: if case
    definition: "An if statement that runs its body only when a value matches one pattern, binding any associated values for the body."
  - term: guard case
    definition: "The guard form of if case: it continues only when the value matches the pattern, and its bindings stay available after the guard."
  - term: indirect
    definition: "A keyword that lets an enum case contain a value of the enum's own type, making recursive enums like expression trees possible."
  - term: State machine
    definition: "A model in which something is always in exactly one of a fixed set of states, and events move it from one state to another."
mastery:
  - Choose between raw values and associated values for a given enum.
  - Write a switch that binds associated values and uses where to split a case.
  - Use if case or guard case when only one case matters.
  - Write a recursive function over an indirect enum.
  - Replace a group of flags and optionals that can contradict each other with a single enum.
resources: [swift-book-enumerations, swift-book-control-flow, swift-book-structures-classes, swift-book-functions]
cards:
  - id: m09-l06-c1
    front: What's the difference between a raw value and an associated value?
    back: "A raw value is a constant fixed in the declaration, the same for every use of the case. An associated value is supplied when the value is created, so each .card can carry a different number. An enum can't have both."
  - id: m09-l06-c2
    front: "How do you check for one case and get its associated value, without a full switch?"
    back: "if case .card(let last4) = payment { … } or guard case .card(let last4) = payment else { … }. The value goes on the right of =."
  - id: m09-l06-c3
    front: When does an enum need indirect?
    back: "When a case's associated value contains the enum itself, like case add(Expression, Expression). Swift 6.3: recursive enum 'Expression' is not marked 'indirect'."
  - id: m09-l06-c4
    front: "Why model loading as enum LoadState { case idle, loading, loaded([Item]), failed(String) } instead of isLoading, items and errorMessage?"
    back: "Separate variables allow impossible combinations, like loading with an error and items at once. With the enum, the screen is in exactly one state, and the data exists only in the state where it's valid."
  - id: m09-l06-c5
    front: Can you compare two values of an enum with associated values using ==?
    back: "Only if the enum is declared Equatable (and all associated values are comparable). Otherwise use switch or if case to check the case."
---

## The idea in one sentence

An enum case can carry its own data, so a payment can be "card, ending 4242" or "gift card, code X, balance 20", and pattern matching is how you get that data back out.

## Associated values

Raw values from the last lesson are fixed: every `.dime` is worth 10. But many choices come with data that's different every time. A payment is cash, or a card with its last four digits, or a gift card with a code and a balance. You could use a struct with an optional for every possible detail, but then a "cash" payment with card digits would be representable. An enum with **associated values** expresses it exactly:

```swift
enum Payment {
    case cash
    case card(last4: String)
    case giftCard(code: String, balanceInCents: Int)
}

let payments: [Payment] = [
    .cash,
    .card(last4: "4242"),
    .giftCard(code: "SPRING", balanceInCents: 2000),
    .card(last4: "0005"),
]

for payment in payments {
    switch payment {
    case .cash:
        print("Cash")
    case .card(let last4):
        print("Card ending \(last4)")
    case .giftCard(let code, let balance):
        print("Gift card \(code), $\(balance / 100) left")
    }
}
```

```output
Cash
Card ending 4242
Gift card SPRING, $20 left
Card ending 0005
```

1. `case card(last4: String)` declares a case that carries a `String`. The parentheses list the associated values' types, like a tuple, optionally with labels.
2. `.card(last4: "4242")` creates a value of that case with its data. Two `.card` values can carry different digits: the data belongs to the value, not to the case.
3. In the `switch`, `case .card(let last4)` matches any card and binds its digits to a new constant `last4`, available inside that case. You've seen this shape already: `case .some(let number)` in Module 8 was exactly this, on the `Optional` enum.
4. `case .giftCard(let code, let balance)` binds both values, in order. The names in the pattern are yours to choose; they don't have to match the labels.

A case without data, like `cash`, has nothing to bind. Cases with and without associated values mix freely in one enum.

One restriction: an enum has raw values **or** associated values, not both. `enum Payment: String` with `case card(String)` fails with `enum with raw type cannot have cases with arguments`.

## Pattern matching

A **pattern** describes the shape of a value; Swift checks whether a value has that shape and, if so, binds its parts to names. Patterns appear in `switch`, `if case`, `guard case` and `for case`. Here are the forms you'll use with enums.

### Binding, ignoring and refining

```swift
enum Payment {
    case cash
    case card(last4: String)
    case giftCard(code: String, balanceInCents: Int)
}

func describe(_ payment: Payment, amountInCents: Int) -> String {
    switch payment {
    case .cash:
        return "Pay at the counter"
    case let .giftCard(code, balance) where balance >= amountInCents:
        return "Covered by gift card \(code)"
    case .giftCard(_, let balance):
        return "Gift card covers \(balance) cents, \(amountInCents - balance) more needed"
    case .card:
        return "Charging card"
    }
}

print(describe(.giftCard(code: "SPRING", balanceInCents: 2000), amountInCents: 1500))
print(describe(.giftCard(code: "OLD", balanceInCents: 500), amountInCents: 1500))
print(describe(.card(last4: "4242"), amountInCents: 1500))
```

```output
Covered by gift card SPRING
Gift card covers 500 cents, 1000 more needed
Charging card
```

- **`case let .giftCard(code, balance)`** puts one `let` before the whole pattern instead of one per value. Both spellings mean the same; use whichever reads better.
- **`where balance >= amountInCents`** adds a condition, exactly like `where` in Module 5. If it's false, Swift moves on to the next case, so one enum case can be split into several branches. First match wins, as always.
- **`_`** ignores a value you don't need: `.giftCard(_, let balance)` skips the code.
- **`case .card:`** with no parentheses matches every card and ignores its data.

The switch is exhaustive without `default`: every gift card falls into one of the two `.giftCard` branches, because the second has no `where`.

Several patterns can share a branch, separated by commas, but each one must bind the same names with the same types:

```swift
enum Contact {
    case email(String)
    case phone(String)
    case none
}

for contact in [Contact.email("ana@example.com"), .phone("555-0100"), .none] {
    switch contact {
    case .email(let address), .phone(let address):
        print("Reach at \(address)")
    case .none:
        print("No contact info")
    }
}
```

```output
Reach at ana@example.com
Reach at 555-0100
No contact info
```

If one pattern binds `address` and the other doesn't, Swift 6.3 reports `'address' must be bound in every pattern`.

### if case and guard case

A full `switch` is too much when you only care about one case. **`if case`** tests a single pattern:

```swift
enum Payment {
    case cash
    case card(last4: String)
    case giftCard(code: String, balanceInCents: Int)
}

let payment = Payment.card(last4: "4242")

if case .card(let last4) = payment {
    print("Receipt shows card \(last4)")
}

if case .cash = payment {
    print("Open the cash drawer")
} else {
    print("No cash drawer needed")
}

func refundCode(for payment: Payment) -> String? {
    guard case .giftCard(let code, _) = payment else {
        return nil
    }
    return code
}

print(refundCode(for: payment) ?? "refund to original method")
print(refundCode(for: .giftCard(code: "SPRING", balanceInCents: 0)) ?? "refund to original method")
```

```output
Receipt shows card 4242
No cash drawer needed
refund to original method
SPRING
```

The syntax reads backwards at first: the **pattern** goes on the left of `=`, the **value** on the right. It isn't an assignment; read `if case .card(let last4) = payment` as "if `payment` matches `.card(let last4)`". **`guard case`** works the same way, with the binding available after the guard, just like `guard let`. Both accept extra conditions after a comma: `if case .card(let last4) = payment, last4.hasPrefix("4")`.

### for case

A `for`-`in` loop can match a pattern too, and only runs the body for elements that match:

```swift
enum CheckResult {
    case passed
    case failed(reason: String)
}

let results: [CheckResult] = [.passed, .failed(reason: "missing title"), .passed, .failed(reason: "negative price")]

for case .failed(let reason) in results {
    print("Problem: \(reason)")
}
```

```output
Problem: missing title
Problem: negative price
```

### Comparing with ==

An enum with associated values doesn't get `==` automatically. Swift 6.3 says `binary operator '==' cannot be applied to two 'Payment' operands`, with a note that it `cannot be synthesized for enums with associated values`. Two fixes:

- If you want to know **which case** it is, use `if case`. `if case .card = payment` ignores the digits.
- If you want **full equality**, case and data, declare the enum `Equatable`, as with structs in lesson 1. Swift then generates `==` as long as every associated value can be compared.

```swift
enum Payment: Equatable {
    case cash
    case card(last4: String)
}

let saved = Payment.card(last4: "4242")
print(saved == .card(last4: "4242"))
print(saved == .card(last4: "0005"))
print(saved == .cash)
```

```output
true
false
false
```

## Recursive enums with indirect

An associated value can be any type, including the enum itself. That's how you describe something built from smaller pieces of the same kind, like an arithmetic expression: `(2 + 3) × 4` is a multiplication whose left side is an addition.

Try it directly and the compiler refuses:

```swift no-compile recursive enum 'Expression' is not marked 'indirect'
enum Expression {
    case number(Int)
    case add(Expression, Expression)
    case multiply(Expression, Expression)
}
```

Swift 6.3: `error: recursive enum 'Expression' is not marked 'indirect'`. An enum value normally stores its associated values inline, and a value that contains a complete copy of its own type would be infinitely large. **`indirect`** tells Swift to store those cases' data separately and keep only a reference to it inline, which breaks the loop. Write it before `enum` to apply it to every case, or before individual cases:

```swift
indirect enum Expression {
    case number(Int)
    case add(Expression, Expression)
    case multiply(Expression, Expression)
}

func evaluate(_ expression: Expression) -> Int {
    switch expression {
    case .number(let value):
        return value
    case .add(let left, let right):
        return evaluate(left) + evaluate(right)
    case .multiply(let left, let right):
        return evaluate(left) * evaluate(right)
    }
}

func render(_ expression: Expression) -> String {
    switch expression {
    case .number(let value):
        return "\(value)"
    case .add(let left, let right):
        return "(\(render(left)) + \(render(right)))"
    case .multiply(let left, let right):
        return "\(render(left)) x \(render(right))"
    }
}

let sum = Expression.add(.number(2), .number(3))
let product = Expression.multiply(sum, .number(4))
print(render(product), "=", evaluate(product))
```

```output
(2 + 3) x 4 = 20
```

`evaluate` is recursion from Module 6 with the base case built into the type: `.number` is the base case, and every other case calls `evaluate` on smaller expressions. Because the switch is exhaustive, adding `case subtract` later would make the compiler ask how to evaluate and render it.

## Modeling state with an enum

Here's how a screen that loads a list from a server is often modeled at first:

```swift illustrative
var isLoading = false
var items: [String] = []
var errorMessage: String? = nil
```

Three variables allow 2 × 2 × 2 = 8 combinations (counting `items` as empty or not), and most of them are nonsense. Loading **and** showing an error? Showing items **and** an error? Every piece of code that reads these must decide what those combinations mean, and every piece that writes them must remember to reset the others. That's how a spinner ends up spinning over an error message.

The screen is really in exactly one of four states, and some states come with data. That's an enum with associated values:

```swift
enum LoadState {
    case idle
    case loading
    case loaded([String])
    case failed(message: String)
}

enum LoadEvent {
    case start
    case succeed([String])
    case fail(String)
    case reset
}

struct ListScreen {
    private(set) var state = LoadState.idle

    mutating func handle(_ event: LoadEvent) {
        switch (state, event) {
        case (.idle, .start), (.failed, .start), (.loaded, .start):
            state = .loading
        case (.loading, .succeed(let items)):
            state = .loaded(items)
        case (.loading, .fail(let message)):
            state = .failed(message: message)
        case (_, .reset):
            state = .idle
        default:
            print("Ignored an event that doesn't apply right now")
        }
    }

    var display: String {
        switch state {
        case .idle:
            return "Pull to refresh"
        case .loading:
            return "Loading..."
        case .loaded(let items) where items.isEmpty:
            return "Nothing here yet"
        case .loaded(let items):
            return "\(items.count) items: \(items.joined(separator: ", "))"
        case .failed(let message):
            return "Error: \(message). Tap to retry."
        }
    }
}

var screen = ListScreen()
let events: [LoadEvent] = [.start, .fail("offline"), .succeed(["late"]), .start, .succeed(["Milk", "Eggs"]), .reset]
print(screen.display)
for event in events {
    screen.handle(event)
    print(screen.display)
}
```

```output
Pull to refresh
Loading...
Error: offline. Tap to retry.
Ignored an event that doesn't apply right now
Error: offline. Tap to retry.
Loading...
2 items: Milk, Eggs
Pull to refresh
```

Walk through it:

1. **Impossible states are gone.** The items exist only inside `.loaded`, and the message only inside `.failed`. There's no way to write "loading with an error", so no code has to handle it.
2. **`switch (state, event)`** matches a tuple of two values at once, with one pattern per element. `(.loading, .succeed(let items))` means "currently loading, and the event is a success", and binds the items. `_` in `(_, .reset)` matches any state. Tuples of two enums have too many combinations to list, so this switch ends with `default`, and here that's the right design: every other combination is an event that doesn't apply, such as a late success arriving after a failure. That's what the fourth line of output shows.
3. **`private(set) var state`** lets other code read the state but only `ListScreen`'s own methods change it, so every change goes through `handle(_:)`. Access control is a Module 10 topic; this is the one piece you need for now.
4. **`display`** has no `default`. It's a switch over `LoadState` alone, and adding a fifth state would make the compiler ask what to show for it.

This pattern, state as an enum and changes as events, is how most iOS screens should handle loading. You'll use it again with SwiftUI.

## Putting it together: a small library

To close the module, here's a program that models a lending library with everything from Module 9: structs with stored and computed properties, a failable initializer, an enum with raw values and `CaseIterable`, an enum with associated values, mutating methods, a static constant and a nested type.

```swift
enum Genre: String, CaseIterable {
    case fiction, science, history
}

struct Book {
    enum Availability {
        case available
        case onLoan(member: String, dueDay: Int)
        case lost
    }

    let isbn: String
    let title: String
    let genre: Genre
    var availability = Availability.available

    var isAvailable: Bool {
        if case .available = availability {
            return true
        }
        return false
    }
}

enum BorrowResult {
    case borrowed(dueDay: Int)
    case notFound
    case alreadyOnLoan(dueDay: Int)
    case lost
}

struct Library {
    static let loanDays = 14
    private(set) var books: [Book] = []

    mutating func add(_ book: Book) {
        books.append(book)
    }

    mutating func borrow(isbn: String, member: String, today: Int) -> BorrowResult {
        for index in books.indices {
            guard books[index].isbn == isbn else { continue }
            switch books[index].availability {
            case .available:
                let due = today + Self.loanDays
                books[index].availability = .onLoan(member: member, dueDay: due)
                return .borrowed(dueDay: due)
            case .onLoan(_, let dueDay):
                return .alreadyOnLoan(dueDay: dueDay)
            case .lost:
                return .lost
            }
        }
        return .notFound
    }

    func overdue(on day: Int) -> [String] {
        var lines: [String] = []
        for book in books {
            if case let .onLoan(member, dueDay) = book.availability, dueDay < day {
                lines.append("\(book.title) (\(member), \(day - dueDay) days late)")
            }
        }
        return lines
    }
}

var library = Library()
library.add(Book(isbn: "111", title: "Dune", genre: .fiction))
library.add(Book(isbn: "222", title: "Cosmos", genre: .science))
library.add(Book(isbn: "333", title: "SPQR", genre: .history, availability: .lost))
library.add(Book(isbn: "444", title: "Hyperion", genre: .fiction))

let requests = [("111", "Ana", 1), ("111", "Ben", 3), ("333", "Ana", 3), ("999", "Ben", 4), ("222", "Ben", 10)]
for (isbn, member, day) in requests {
    switch library.borrow(isbn: isbn, member: member, today: day) {
    case .borrowed(let dueDay):
        print("Day \(day): \(member) borrows \(isbn), due day \(dueDay)")
    case .alreadyOnLoan(let dueDay):
        print("Day \(day): \(isbn) is out until day \(dueDay)")
    case .lost:
        print("Day \(day): \(isbn) is lost")
    case .notFound:
        print("Day \(day): no book \(isbn)")
    }
}

print("Overdue on day 20: \(library.overdue(on: 20))")
for genre in Genre.allCases {
    let available = library.books.filter { book in book.genre == genre && book.isAvailable }
    print("\(genre.rawValue): \(available.count) available")
}
```

```output
Day 1: Ana borrows 111, due day 15
Day 3: 111 is out until day 15
Day 3: 333 is lost
Day 4: no book 999
Day 10: Ben borrows 222, due day 24
Overdue on day 20: ["Dune (Ana, 5 days late)"]
fiction: 1 available
science: 0 available
history: 0 available
```

The design decisions worth noticing:

1. **`Availability` is nested in `Book`**, because it only describes a book. The borrower and due day exist only in `.onLoan`, so an available book can't have a stale due date.
2. **`BorrowResult` replaces an optional.** In Module 8 you saw that `nil` can only say "it didn't work", and that a failure with several reasons needs more. An enum with associated values says which reason, and carries the data each reason needs (the due day for a book that's out). Module 12's errors build on the same idea.
3. **`borrow` is `mutating`** because it changes a book's availability, through `books[index]`, not through a loop copy.
4. **`overdue(on:)` uses `if case let … , dueDay < day`**: pattern and condition in one `if`.
5. **`for (isbn, member, day) in requests`** takes apart each tuple in the array into three constants. That's a tuple pattern too.
6. **`Genre.allCases`** drives the summary, so a new genre shows up there automatically.

## Common mistakes

> [!error] error: enum with raw type cannot have cases with arguments
> An enum has raw values or associated values, not both. If you need a fixed code per case and data per value, keep the raw values and add a computed property for the code, or move the data into a struct.

> [!error] error: binary operator '==' cannot be applied to two '…' operands
> Enums with associated values aren't comparable by default. Use `if case .card = payment` to check the case, or declare the enum `Equatable` for full comparison.

```swift no-compile binary operator '==' cannot be applied to two 'Payment' operands
enum Payment {
    case cash
    case card(last4: String)
}

let payment = Payment.card(last4: "4242")
if payment == .cash {
    print("cash")
}
```

> [!error] error: recursive enum '…' is not marked 'indirect'
> A case contains the enum itself. Add `indirect` before `enum` or before the recursive cases.

> [!error] error: '…' must be bound in every pattern
> In a case with several patterns separated by commas, every pattern has to bind the same names, with the same types.

> [!warning] Writing if payment = .cash
> A pattern match needs `case`: `if case .cash = payment`. Without `case`, Swift reads `=` as an assignment, and Swift 6.3 rejects it with `use of '=' in a boolean context, did you mean '=='?`. Don't take that suggestion literally for an enum with associated values: `==` won't compile either unless the enum is `Equatable`.

> [!warning] Flags and optionals that can contradict each other
> `isLoading`, `items` and `errorMessage` side by side allow states your UI doesn't handle. If something is in exactly one of several states, make it an enum with the data inside the cases.

````exercise
id: m09-l06-e1
type: comprehension
prompt: "Which enum should use **associated values** rather than raw values?"
choices:
  - text: "The days of the week, saved to a file as \"mon\", \"tue\"…"
    correct: false
    why: "Each case has one fixed code: raw values."
  - text: "Coin denominations with their value in cents."
    correct: false
    why: "Every dime is worth 10: a fixed value per case, so raw values."
  - text: "A notification that's either a new message (with sender and text), a friend request (with the requester's name) or a system update."
    correct: true
    why: "Each notification carries its own data, and different cases carry different kinds of data."
  - text: "The four suits of a deck of cards, each with a symbol."
    correct: false
    why: "The symbol is fixed per suit: raw values."
solution: |
  **The notification.** Raw values are constants that belong to the case, the same every time. Associated values are supplied each time a value is created: every new-message notification has a different sender and text.

  ```swift
  enum Notification {
      case message(from: String, text: String)
      case friendRequest(from: String)
      case systemUpdate
  }

  let latest = Notification.message(from: "Ana", text: "Lunch?")
  if case .message(let sender, let text) = latest {
      print("\(sender): \(text)")
  }
  ```

  ```output
  Ana: Lunch?
  ```
````

````exercise
id: m09-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum Reading {
      case temperature(Double)
      case humidity(percent: Int)
      case offline
  }

  let readings: [Reading] = [.temperature(31.5), .humidity(percent: 80), .offline, .temperature(18), .humidity(percent: 30)]

  for reading in readings {
      switch reading {
      case .temperature(let degrees) where degrees > 30:
          print("hot: \(degrees)")
      case .temperature(let degrees):
          print("temp: \(degrees)")
      case .humidity(let percent) where percent >= 70:
          print("humid")
      case .humidity:
          print("dry")
      case .offline:
          print("no data")
      }
  }

  var count = 0
  for case .temperature in readings {
      count += 1
  }
  print(count)
output: |
  hot: 31.5
  humid
  no data
  temp: 18.0
  dry
  2
hints:
  - Cases are tried top to bottom; a where clause that's false moves on to the next case.
  - "18 is a Double here, so it prints with a decimal point."
  - "for case .temperature in readings runs only for temperature readings."
solution: |
  ```output
  hot: 31.5
  humid
  no data
  temp: 18.0
  dry
  2
  ```

  31.5 passes `where degrees > 30`. 80 passes `percent >= 70`. 18 fails the first `where` and lands in the plain `.temperature` case; it was written `18` but the associated value is a `Double`, so it prints `18.0`. 30 is below 70, so it's `dry`. The `for case` loop counts the two temperature readings and ignores their values.
````

````exercise
id: m09-l06-e3
type: fill-in
prompt: "Complete the function so it returns the tracking number of a shipped order, or `nil` otherwise. The program prints `1Z999` and then `none`."
code: |
  enum OrderStatus {
      case placed
      case shipped(trackingNumber: String)
      case delivered
  }

  func trackingNumber(of status: OrderStatus) -> String? {
      [[1]] [[2]] .shipped([[3]] number) = status else {
          return nil
      }
      return number
  }

  print(trackingNumber(of: .shipped(trackingNumber: "1Z999")) ?? "none")
  print(trackingNumber(of: .[[4]]) ?? "none")
blanks:
  - id: "1"
    answers: [guard]
  - id: "2"
    answers: [case]
  - id: "3"
    answers: [let]
  - id: "4"
    answers: [placed, delivered]
solution: |
  ```swift
  enum OrderStatus {
      case placed
      case shipped(trackingNumber: String)
      case delivered
  }

  func trackingNumber(of status: OrderStatus) -> String? {
      guard case .shipped(let number) = status else {
          return nil
      }
      return number
  }

  print(trackingNumber(of: .shipped(trackingNumber: "1Z999")) ?? "none")
  print(trackingNumber(of: .placed) ?? "none")
  ```

  ```output
  1Z999
  none
  ```

  `guard case` continues only when `status` matches the pattern, and `number` stays available after it, like `guard let`. Either `.placed` or `.delivered` fails the match, so the function returns `nil`.
````

````exercise
id: m09-l06-e4
type: find-errors
prompt: "This code models a media player. Which statements are true?"
code: |
  enum PlayerState {
      case stopped
      case playing(track: String, second: Int)
      case paused(track: String, second: Int)
  }

  let state = PlayerState.playing(track: "Intro", second: 42)

  if state == .stopped {
      print("Nothing playing")
  }

  switch state {
  case .playing(let track, let second), .paused(let track):
      print("\(track) at \(second)s")
  case .stopped:
      print("Stopped")
  }

  if state = .stopped {
      print("Stopped")
  }
choices:
  - text: "state == .stopped doesn't compile, because PlayerState has associated values and isn't Equatable."
    correct: true
    why: "Use if case .stopped = state, or declare the enum Equatable."
  - text: "The combined case doesn't compile because .paused(let track) doesn't bind second."
    correct: true
    why: "Every pattern in a combined case must bind the same names."
  - text: "if state = .stopped is missing the word case."
    correct: true
    why: "A pattern match is written if case .stopped = state."
  - text: "The switch needs a default because playing and paused have associated values."
    correct: false
    why: "The three cases cover every PlayerState; associated values don't change that."
rubric:
  - I found the == comparison, the unbound name and the missing case.
  - I said the switch is exhaustive without default.
solution: |
  Three real problems. Fixed:

  ```swift
  enum PlayerState {
      case stopped
      case playing(track: String, second: Int)
      case paused(track: String, second: Int)
  }

  let state = PlayerState.playing(track: "Intro", second: 42)

  if case .stopped = state {
      print("Nothing playing")
  }

  switch state {
  case .playing(let track, let second), .paused(let track, let second):
      print("\(track) at \(second)s")
  case .stopped:
      print("Stopped")
  }
  ```

  ```output
  Intro at 42s
  ```

  The last `if` was a duplicate of the first check once fixed, so it's gone. `playing` and `paused` share their data's shape, which is why one branch can handle both.
````

````exercise
id: m09-l06-e5
type: solve
prompt: |
  Extend the expression enum with a case `negate(Expression)` and write `evaluate` for it. Then write `func countNumbers(in expression: Expression) -> Int` that counts the `.number` leaves.

  For `-(2 + 3) x 4`, built as `.multiply(.negate(.add(.number(2), .number(3))), .number(4))`, the program must print:

  ```output
  -20
  3
  ```
starter: |
  indirect enum Expression {
      case number(Int)
      case add(Expression, Expression)
      case multiply(Expression, Expression)
      // add negate
  }

  func evaluate(_ expression: Expression) -> Int {
      // your code
  }

  func countNumbers(in expression: Expression) -> Int {
      // your code
  }

  let expression = Expression.multiply(.negate(.add(.number(2), .number(3))), .number(4))
  print(evaluate(expression))
  print(countNumbers(in: expression))
hints:
  - "case .negate(let inner): return -evaluate(inner)"
  - countNumbers returns 1 for a number and the sum of its parts for everything else.
  - "add and multiply can share one branch in countNumbers: case .add(let l, let r), .multiply(let l, let r)."
rubric:
  - negate is a new case with one associated Expression, and the enum is indirect.
  - Both functions are recursive, with .number as the base case.
  - Both switches are exhaustive without default.
  - The output matches exactly.
solution: |
  ```swift
  indirect enum Expression {
      case number(Int)
      case add(Expression, Expression)
      case multiply(Expression, Expression)
      case negate(Expression)
  }

  func evaluate(_ expression: Expression) -> Int {
      switch expression {
      case .number(let value):
          return value
      case .add(let left, let right):
          return evaluate(left) + evaluate(right)
      case .multiply(let left, let right):
          return evaluate(left) * evaluate(right)
      case .negate(let inner):
          return -evaluate(inner)
      }
  }

  func countNumbers(in expression: Expression) -> Int {
      switch expression {
      case .number:
          return 1
      case .add(let left, let right), .multiply(let left, let right):
          return countNumbers(in: left) + countNumbers(in: right)
      case .negate(let inner):
          return countNumbers(in: inner)
      }
  }

  let expression = Expression.multiply(.negate(.add(.number(2), .number(3))), .number(4))
  print(evaluate(expression))
  print(countNumbers(in: expression))
  ```

  ```output
  -20
  3
  ```

  −(2 + 3) = −5, times 4 is −20. The leaves are 2, 3 and 4. Adding `negate` to the enum made both switches stop compiling until they handled it: that's the exhaustiveness check doing its job.
````

````exercise
id: m09-l06-e6
type: design
prompt: |
  A login screen currently keeps `var isSubmitting: Bool`, `var errorText: String?`, `var loggedInUser: String?` and `var attemptsLeft: Int`. Design an enum (or an enum plus a struct) that makes the impossible combinations unrepresentable. Name the states, say which data lives in which state, and list the events that move between them. Point out at least two combinations the current design allows that make no sense.
rubric:
  - The design has a state for editing (with an optional error), submitting, logged in (with the user) and locked out (or equivalent).
  - Data appears only in the states where it's meaningful.
  - The events are listed with the transitions they cause.
  - At least two impossible combinations of the old variables are named.
solution: |
  One reasonable design:

  ```swift
  enum LoginState {
      case editing(error: String?, attemptsLeft: Int)
      case submitting(attemptsLeft: Int)
      case loggedIn(user: String)
      case lockedOut
  }

  enum LoginEvent {
      case submit
      case succeeded(user: String)
      case failed(reason: String)
  }

  func next(_ state: LoginState, _ event: LoginEvent) -> LoginState {
      switch (state, event) {
      case (.editing(_, let attempts), .submit):
          return .submitting(attemptsLeft: attempts)
      case (.submitting, .succeeded(let user)):
          return .loggedIn(user: user)
      case (.submitting(let attempts), .failed(let reason)):
          return attempts > 1 ? .editing(error: reason, attemptsLeft: attempts - 1) : .lockedOut
      default:
          return state
      }
  }

  var state = LoginState.editing(error: nil, attemptsLeft: 2)
  for event in [LoginEvent.submit, .failed(reason: "Wrong password"), .submit, .failed(reason: "Wrong password")] {
      state = next(state, event)
  }
  if case .lockedOut = state {
      print("Locked out")
  }
  ```

  ```output
  Locked out
  ```

  The old variables allow, for example, `isSubmitting == true` with an `errorText` (spinner over an error), a `loggedInUser` together with an `errorText`, or a logged-in user who still has `attemptsLeft` that mean nothing. In the enum, the error exists only while editing, the user only once logged in, and the attempts only while they matter. `default` in `next` keeps the current state for events that don't apply, such as `submit` while already submitting.
````

## Summary

- **Associated values** attach data to an enum value when it's created: `.card(last4: "4242")`. Raw values are fixed per case; an enum has one kind or the other.
- `switch` extracts associated values with `case .card(let last4)` or `case let .giftCard(code, balance)`. `_` ignores a value; a case name alone ignores all of them.
- `where` splits a case by a condition. Combined patterns must bind the same names.
- `if case pattern = value` and `guard case pattern = value` test a single case; `for case` loops over only the matching elements.
- Enums with associated values get `==` only when declared `Equatable`.
- A recursive enum needs `indirect`, and functions over it are naturally recursive.
- Model "exactly one of these states" as an enum with the data inside the cases. Impossible combinations then can't be written, and a switch over the state has to handle every real one.
- Structs model things with several properties; enums model choices. Most domains need both.
