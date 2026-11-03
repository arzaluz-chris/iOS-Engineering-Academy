---
id: m14-l06
title: SOLID and separation of concerns
description: You learn the five SOLID principles one at a time, each with a small Swift example and the place it shows up in iOS code, state the Liskov substitution principle correctly as a contract a subtype must honor, separate UI, logic and data, and finish by taking apart a screen class that does everything into focused pieces, with the same output before and after.
module: m14
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l05]
objectives:
  - State each SOLID principle in one sentence and recognize a violation of it in Swift code.
  - Explain the Liskov substitution principle as a contract (what a supertype promises, every subtype must deliver) and spot a conformance that breaks it.
  - Split a large protocol into smaller ones that each client actually needs.
  - Separate UI, logic and data, and say which way the dependencies point.
  - Refactor a type that does everything into focused types without changing its output.
  - Recognize when applying a principle would add complexity without a real benefit.
terms:
  - term: SOLID
    definition: "Five object-oriented design principles collected by Robert C. Martin: Single responsibility, Open/closed, Liskov substitution, Interface segregation, Dependency inversion."
  - term: Single responsibility principle
    definition: "A type should have one reason to change: one job, owned by one part of the requirements."
  - term: Open/closed principle
    definition: "Code should be open for extension and closed for modification: you add behavior by adding new types, not by editing working code."
  - term: Liskov substitution principle
    definition: "Anywhere code uses a supertype (a superclass or a protocol), any subtype must work in its place, keeping every promise the supertype makes. A subtype may do more, never less."
  - term: Interface segregation principle
    definition: "Clients shouldn't be forced to depend on methods they don't use. Prefer several small protocols to one large one."
  - term: Dependency inversion principle
    definition: "High-level code depends on abstractions (protocols) it owns, not on concrete low-level types; the concrete types are plugged in from outside."
  - term: Separation of concerns
    definition: "Keeping different kinds of work, such as showing things, deciding things and storing things, in different parts of the code, so each can change without the others."
mastery:
  - Name the principle each of five short code smells violates, and propose the fix.
  - Write a protocol's contract as a documentation comment and decide whether a given conforming type honors it.
  - Split a five-method protocol into two or three focused ones and make an existing type conform to all of them.
  - Draw the UI, logic and data layers of a small feature and point the arrows the right way.
  - Take a class that parses, computes, stores and displays, and split it so the logic can be tested without any UI.
resources: [swift-book-protocols, swift-book-access-control, swift-api-design-guidelines]
cards:
  - id: m14-l06-c1
    front: What does the S in SOLID say, and how do you test for it?
    back: "Single responsibility: a type should have one reason to change. Ask who would request a change to it; if the answers are several different people or concerns, split it."
  - id: m14-l06-c2
    front: State the Liskov substitution principle precisely.
    back: "Code written against a supertype must keep working, with every promised behavior, when given any subtype. A subtype may require no more and must promise no less than its supertype's contract."
  - id: m14-l06-c3
    front: Where does interface segregation show up in UIKit?
    back: "Table views split their needs into UITableViewDataSource (data and cells) and UITableViewDelegate (selection, headers, heights and other behavior) instead of one big protocol."
  - id: m14-l06-c4
    front: Which way do dependencies point between UI, logic and data?
    back: "UI depends on logic; logic depends on protocols for data that it defines; concrete data code conforms to those protocols. Logic never imports or knows about the UI."
  - id: m14-l06-c5
    front: When should you not apply a SOLID principle?
    back: "When there's no second implementation, no test that needs a seam and no change on the horizon. A protocol with one conforming type and no fake is often just indirection."
---

## The idea in one sentence

SOLID is five ways of keeping code changeable: give each type one job, extend by adding rather than editing, make subtypes keep their supertype's promises, keep protocols small, and depend on abstractions; separation of concerns applies the same idea to whole layers.

> [!note]
> The five principles were collected by Robert C. Martin and are discussed everywhere in industry, with many slightly different wordings. The definitions here follow the common ones, with Liskov stated the way Barbara Liskov's principle is meant: as a contract. They're guidelines that help you make decisions, not laws to apply everywhere.

## S: single responsibility

> A type should have one reason to change.

"One reason to change" is more useful than "does one thing", because everything does one thing at some zoom level. Ask: **who would ask for a change to this type?**

```swift
struct Expense {
    let title: String
    let cents: Int
}

struct ExpenseReport {
    var expenses: [Expense]

    var totalCents: Int {
        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        return total
    }

    func csv() -> String {
        var text = "title,cents\n"
        for expense in expenses {
            text += "\(expense.title),\(expense.cents)\n"
        }
        return text
    }

    func summaryText() -> String {
        "\(expenses.count) expenses, \(totalCents) cents"
    }
}

let report = ExpenseReport(expenses: [Expense(title: "Coffee", cents: 450)])
print(report.summaryText())
print(report.csv(), terminator: "")
```

```output
1 expenses, 450 cents
title,cents
Coffee,450
```

Three different people would request changes here: product wants the totals computed differently (refunds excluded), the finance team wants a different CSV format, and the designer wants the summary worded differently. Each change touches the same type, and each risks breaking the others. Split along those lines: `ExpenseReport` computes, a `CSVExporter` exports, the screen (or its view model) writes the text.

**In iOS:** the classic violation is the "massive view controller" that loads data, parses it, applies business rules, formats strings and lays out views. The closing example in this lesson takes one apart.

## O: open/closed

> Open for extension, closed for modification.

You've already done this. In the previous lesson, the `if` chain on a payment-method string became a `PaymentMethod` protocol. Adding a new method now means **adding** a type; the report code that uses `method.fee(forCents:)` is never edited:

```swift
protocol PaymentMethod {
    var name: String { get }
    func fee(forCents cents: Int) -> Int
}

struct Card: PaymentMethod {
    let name = "card"
    func fee(forCents cents: Int) -> Int { cents * 3 / 100 }
}

struct BankTransfer: PaymentMethod {
    let name = "transfer"
    func fee(forCents cents: Int) -> Int { 50 }
}

// Added later, without touching anything above or below.
struct GiftCard: PaymentMethod {
    let name = "gift card"
    func fee(forCents cents: Int) -> Int { 0 }
}

func printFees(forCents cents: Int, methods: [any PaymentMethod]) {
    for method in methods {
        print("\(method.name): \(method.fee(forCents: cents))")
    }
}

printFees(forCents: 2000, methods: [Card(), BankTransfer(), GiftCard()])
```

```output
card: 60
transfer: 50
gift card: 0
```

**In iOS:** frameworks are built this way. You customize a SwiftUI button's look by writing a type that conforms to `ButtonStyle`, and you give a table view its data by conforming to `UITableViewDataSource`; you don't edit `Button` or `UITableView`.

Don't overdo it: a `switch` over an enum you own, in one place, is fine. Open/closed matters where you **expect** new cases, or where other modules must add them.

## L: Liskov substitution

> If code works with a supertype, it must work with every subtype, with every promise kept.

A **supertype** is a superclass or a protocol; a **subtype** is a subclass or a conforming type. The supertype has a **contract**: what callers may assume. The compiler checks the method signatures; it can't check the promises. Liskov's principle says each subtype must keep them: it may **require no more** of its callers and must **promise no less**.

Write the contract down:

```swift
struct Expense {
    let title: String
    let cents: Int
}

/// Stores expenses for the current session.
///
/// Contract: after `add(_:)` returns, `all()` contains every expense
/// added so far, in the order they were added.
protocol ExpenseStore: AnyObject {
    func add(_ expense: Expense)
    func all() -> [Expense]
}

final class InMemoryStore: ExpenseStore {
    private var expenses: [Expense] = []
    func add(_ expense: Expense) { expenses.append(expense) }
    func all() -> [Expense] { expenses }
}

/// Keeps only the two most recent expenses, to save memory.
final class RecentOnlyStore: ExpenseStore {
    private var expenses: [Expense] = []
    func add(_ expense: Expense) {
        expenses.append(expense)
        if expenses.count > 2 {
            expenses.removeFirst()
        }
    }
    func all() -> [Expense] { expenses }
}

func monthTotal(_ amounts: [Int], using store: any ExpenseStore) -> Int {
    for cents in amounts {
        store.add(Expense(title: "Item", cents: cents))
    }
    var total = 0
    for expense in store.all() {
        total += expense.cents
    }
    return total
}

print(monthTotal([450, 1299, 9000], using: InMemoryStore()))
print(monthTotal([450, 1299, 9000], using: RecentOnlyStore()))
```

```output
10749
10299
```

`RecentOnlyStore` compiles, conforms and is wrong. `monthTotal` relied on the contract ("contains every expense added") and silently lost $4.50. Nothing crashed; the bug would show up as a wrong number in a report. That's what a Liskov violation looks like in practice: a subtype that type-checks but **breaks a promise**, so code written against the supertype can't trust it.

The fix isn't in `monthTotal`. Checking "if the store is a RecentOnlyStore…" would defeat the point of the protocol. The fix is to stop pretending: a store that drops expenses doesn't fulfil `ExpenseStore`'s contract, so it shouldn't conform. Give it its own protocol with its own honest contract ("the most recent N"), and use it only where that's what's needed.

What a subtype **may** do: be faster, log, cache, accept a wider range of inputs, return results that satisfy the promise in more detail. What it may **not** do: demand more (a precondition the supertype didn't have, like "call `open()` first"), deliver less (dropping data, returning a value outside the promised range), or fail where the supertype promised success (`fatalError("not supported")` in a required method).

**In iOS:** you meet contracts every time you subclass a UIKit class. Apple's documentation for `UIViewController.viewWillAppear(_:)` says that if you override it, you must call `super` at some point. A subclass that skips it breaks the contract UIKit relies on. And the `Penguin` that overrode `fly()` to not fly, back in Module 10, was the same violation with a superclass.

## I: interface segregation

> Clients shouldn't depend on methods they don't use.

A protocol that collects everything a store can do forces every conforming type to implement all of it, and every client to depend on all of it:

```swift illustrative
protocol ExpenseRepository {
    func all() -> [Expense]
    func add(_ expense: Expense)
    func delete(at index: Int)
    func exportCSV() -> String
    func syncWithServer() async throws
}
```

The summary screen only reads. A test fake for it would have to implement deletion, export and network sync with dummy bodies. Split by what clients actually need:

```swift
struct Expense {
    let title: String
    let cents: Int
}

protocol ExpenseReading {
    func all() -> [Expense]
}

protocol ExpenseWriting {
    func add(_ expense: Expense)
}

typealias ExpenseStorage = ExpenseReading & ExpenseWriting

final class InMemoryStorage: ExpenseStorage {
    private var expenses: [Expense] = []
    func all() -> [Expense] { expenses }
    func add(_ expense: Expense) { expenses.append(expense) }
}

struct SummaryScreen {
    let source: any ExpenseReading

    func render() {
        print("\(source.all().count) expenses")
    }
}

struct FixedExpenses: ExpenseReading {
    func all() -> [Expense] {
        [Expense(title: "Coffee", cents: 450), Expense(title: "Lunch", cents: 1299)]
    }
}

let storage = InMemoryStorage()
storage.add(Expense(title: "Taxi", cents: 1800))
SummaryScreen(source: storage).render()
SummaryScreen(source: FixedExpenses()).render()
```

```output
1 expenses
2 expenses
```

`SummaryScreen` asks only for `ExpenseReading`, so it can't accidentally write, and its test stand-in `FixedExpenses` is three lines. The real storage conforms to both protocols, named together as `ExpenseStorage` with the `&` composition from Module 10.

**In iOS:** `UITableView` doesn't have one giant protocol. `UITableViewDataSource` provides the data and cells; `UITableViewDelegate` handles selection, headers, heights and actions. A type can adopt one without the other.

## D: dependency inversion

> High-level code depends on abstractions it owns; details plug in from outside.

You built this in "Composition and protocol-oriented design": the high-level type declares a protocol for what it needs, and receives a concrete value through its initializer.

```swift
protocol AlertSender {
    func send(_ message: String)
}

struct BudgetWatcher {
    let limitCents: Int
    let sender: any AlertSender

    func check(totalCents: Int) {
        if totalCents > limitCents {
            sender.send("Over budget by \(totalCents - limitCents) cents")
        }
    }
}

struct ConsoleSender: AlertSender {
    func send(_ message: String) {
        print("ALERT:", message)
    }
}

final class RecordingSender: AlertSender {
    private(set) var messages: [String] = []
    func send(_ message: String) {
        messages.append(message)
    }
}

BudgetWatcher(limitCents: 5000, sender: ConsoleSender()).check(totalCents: 6200)

let recorder = RecordingSender()
let watcher = BudgetWatcher(limitCents: 5000, sender: recorder)
watcher.check(totalCents: 4000)
watcher.check(totalCents: 5001)
print(recorder.messages)
```

```output
ALERT: Over budget by 1200 cents
["Over budget by 1 cents"]
```

`BudgetWatcher` (the policy) doesn't know whether alerts go to the console, a push notification or a test. The "inversion": the protocol belongs with the high-level code, and the low-level senders depend on it, not the other way around.

**In iOS:** a view model that takes `any ExpensesService` in its initializer instead of creating `URLSession` requests itself. The app passes the real network service; tests and SwiftUI previews pass a fake with fixed data.

## Separation of concerns: UI, logic, data

SOLID works at the level of types. **Separation of concerns** is the same thinking at the level of a feature. Most app code does one of three kinds of work:

```plaintext
┌────────────────────────────┐
│ UI                         │  shows things, receives taps
│ views, view controllers    │
└─────────────┬──────────────┘
              │ calls
┌─────────────▼──────────────┐
│ Logic                      │  decides things: rules, validation,
│ parsing, calculations      │  calculations, formatting for display
│ protocols for data it needs│
└─────────────▲──────────────┘
              │ conforms to
┌─────────────┴──────────────┐
│ Data                       │  stores and fetches things:
│ in-memory, files, network  │  disk, database, server
└────────────────────────────┘
```

- **UI** knows about logic. Logic never knows about the UI: no `UIView`, no `print("[label]…")`, no SwiftUI types in it.
- **Logic** defines the protocols for the data it needs. **Data** conforms to them. That's dependency inversion between layers.
- Then the logic can be tested with plain values and fakes, the data layer can change from memory to a database without touching rules, and a redesign of the screen doesn't risk the math.

Later modules give these layers names (view models, MVVM, repositories). The idea is already all here.

## Closing refactor: a screen that does everything

Here's a screen class of the kind that grows in real apps. `print` stands in for UI: `[label]` is a text label, `[alert]` an alert, `[banner]` a warning banner.

```swift
final class ExpenseScreen {
    var expenses: [(title: String, cents: Int)] = []
    let limitCents = 5000

    func userTappedAdd(text: String) {
        let parts = text.split(separator: ",")
        guard parts.count == 2, let cents = Int(parts[1]), cents > 0 else {
            print("[alert] Enter a title and an amount, like Coffee,450")
            return
        }
        expenses.append((title: String(parts[0]), cents: cents))

        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        let rest = total % 100
        let totalText = "$\(total / 100)." + (rest < 10 ? "0\(rest)" : "\(rest)")
        print("[label] Count: \(expenses.count), total: \(totalText)")

        if total > limitCents {
            let over = total - limitCents
            let overRest = over % 100
            print("[banner] Over budget by $\(over / 100)." + (overRest < 10 ? "0\(overRest)" : "\(overRest)"))
        }
    }
}

let screen = ExpenseScreen()
screen.userTappedAdd(text: "Coffee,450")
screen.userTappedAdd(text: "Lunch,abc")
screen.userTappedAdd(text: "Hotel,9000")
```

```output
[label] Count: 1, total: $4.50
[alert] Enter a title and an amount, like Coffee,450
[label] Count: 2, total: $94.50
[banner] Over budget by $44.50
```

One method parses input, validates it, stores data, computes a total, formats money twice (copy-pasted), applies the budget rule and drives three kinds of UI. To test "over budget by $44.50" you have to go through a tap handler and read printed text. Every concern has a different reason to change.

The output above is the safety net. The refactored version must print exactly the same four lines.

```swift
// MARK: Data

struct Expense {
    let title: String
    let cents: Int
}

/// Contract: after `add(_:)`, `all()` contains every expense added, in order.
protocol ExpenseStore: AnyObject {
    func add(_ expense: Expense)
    func all() -> [Expense]
}

final class InMemoryExpenseStore: ExpenseStore {
    private var expenses: [Expense] = []

    func add(_ expense: Expense) {
        expenses.append(expense)
    }

    func all() -> [Expense] {
        expenses
    }
}

// MARK: Logic

enum InputError: Error {
    case badFormat
}

struct ExpenseParser {
    func parse(_ text: String) throws(InputError) -> Expense {
        let parts = text.split(separator: ",")
        guard parts.count == 2, let cents = Int(parts[1]), cents > 0 else {
            throw .badFormat
        }
        return Expense(title: String(parts[0]), cents: cents)
    }
}

struct BudgetSummary {
    let count: Int
    let totalCents: Int
    let overByCents: Int?

    init(expenses: [Expense], limitCents: Int) {
        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        count = expenses.count
        totalCents = total
        overByCents = total > limitCents ? total - limitCents : nil
    }
}

func formatCents(_ cents: Int) -> String {
    let rest = cents % 100
    return "$\(cents / 100)." + (rest < 10 ? "0\(rest)" : "\(rest)")
}

// MARK: UI

final class ExpenseScreen {
    private let parser = ExpenseParser()
    private let store: any ExpenseStore
    private let limitCents: Int

    init(store: any ExpenseStore, limitCents: Int) {
        self.store = store
        self.limitCents = limitCents
    }

    func userTappedAdd(text: String) {
        do {
            store.add(try parser.parse(text))
        } catch {
            show(alert: "Enter a title and an amount, like Coffee,450")
            return
        }
        render(BudgetSummary(expenses: store.all(), limitCents: limitCents))
    }

    private func render(_ summary: BudgetSummary) {
        print("[label] Count: \(summary.count), total: \(formatCents(summary.totalCents))")
        if let over = summary.overByCents {
            print("[banner] Over budget by \(formatCents(over))")
        }
    }

    private func show(alert message: String) {
        print("[alert] \(message)")
    }
}

let screen = ExpenseScreen(store: InMemoryExpenseStore(), limitCents: 5000)
screen.userTappedAdd(text: "Coffee,450")
screen.userTappedAdd(text: "Lunch,abc")
screen.userTappedAdd(text: "Hotel,9000")
```

```output
[label] Count: 1, total: $4.50
[alert] Enter a title and an amount, like Coffee,450
[label] Count: 2, total: $94.50
[banner] Over budget by $44.50
```

Same output. Where each principle landed:

- **Single responsibility.** `ExpenseParser` changes if the input format changes; `BudgetSummary` if the budget rule changes; `formatCents` if the money format changes; `ExpenseScreen` if the design changes; the store if persistence changes. The duplicated money formatting is now one function.
- **Separation of concerns.** The logic (`ExpenseParser`, `BudgetSummary`, `formatCents`) has no UI in it. Only `ExpenseScreen` prints.
- **Dependency inversion.** The screen receives `any ExpenseStore` in its initializer. Moving to a file or a database means writing one new conforming type.
- **Liskov.** `ExpenseStore`'s contract is written down, so whoever writes the database version knows what they must keep.
- `MARK:` comments label the sections; Xcode shows them in the file's jump bar.

And the payoff: the rules can be checked directly, with no screen and no taps.

```swift
struct Expense {
    let title: String
    let cents: Int
}

enum InputError: Error {
    case badFormat
}

struct ExpenseParser {
    func parse(_ text: String) throws(InputError) -> Expense {
        let parts = text.split(separator: ",")
        guard parts.count == 2, let cents = Int(parts[1]), cents > 0 else {
            throw .badFormat
        }
        return Expense(title: String(parts[0]), cents: cents)
    }
}

struct BudgetSummary {
    let count: Int
    let totalCents: Int
    let overByCents: Int?

    init(expenses: [Expense], limitCents: Int) {
        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        count = expenses.count
        totalCents = total
        overByCents = total > limitCents ? total - limitCents : nil
    }
}

let atLimit = BudgetSummary(expenses: [Expense(title: "Rent", cents: 5000)], limitCents: 5000)
let overLimit = BudgetSummary(expenses: [Expense(title: "Rent", cents: 5001)], limitCents: 5000)
print(atLimit.overByCents == nil, overLimit.overByCents == 1)

let parser = ExpenseParser()
for text in ["Coffee,450", "Coffee,-450", "Coffee", "Coffee,4.50"] {
    do {
        let expense = try parser.parse(text)
        print("accepted", expense.title, expense.cents)
    } catch {
        print("rejected", text)
    }
}
```

```output
true true
accepted Coffee 450
rejected Coffee,-450
rejected Coffee
rejected Coffee,4.50
```

Exactly at the limit isn't "over"; one cent more is. Negative and decimal amounts are rejected. In a package, those would be `@Test` functions run by `swift test` and by CI on every pull request.

## When not to

Every principle adds a seam: a protocol, an extra type, an initializer parameter. Seams cost reading time. Add one when it pays:

- A **second implementation exists or is planned** (a fake for tests counts).
- **Different reasons to change** are actually pulling on one type.
- A **test** needs to replace something slow, random or external (network, clock, disk).

A protocol with exactly one conforming type, no fake and no planned second one is usually indirection without benefit. Start simple; when a second reason to change shows up, refactor in small steps, with tests, as in the previous lesson.

## Common mistakes

> [!error] A conformance that compiles but breaks the contract
> Like `RecentOnlyStore`, or a method that calls `fatalError("not supported")`. Code written against the protocol can't trust it. Don't conform; give the type an honest protocol of its own.

> [!error] "Liskov means a subclass can't override methods"
> Overriding is fine. Liskov is about keeping promises: an override may do things differently or better, but it must not demand more of callers or deliver less than the supertype promises.

> [!error] Logic that knows about the UI
> A `BudgetSummary` that returns a `UIColor` or calls `print("[banner]…")` can't be tested or reused without the screen. Return data (`overByCents`), and let the UI decide how to show it.

> [!error] One protocol per type, everywhere
> `ExpenseParserProtocol` with one conforming `ExpenseParser` and no fake adds a file and a jump for every reader. Introduce the protocol when the second implementation arrives.

> [!error] Splitting by layer and calling it done
> A `Helpers.swift` or `Manager` type that collects unrelated functions has many reasons to change. Split by responsibility, not just by folder.

## Exercises

````exercise
id: m14-l06-e1
type: comprehension
prompt: Which statement of the Liskov substitution principle is correct?
choices:
  - text: A subclass must not override any method of its superclass.
    correct: false
    why: Overriding is allowed. What matters is whether the override keeps the superclass's promises.
  - text: Code that works with a supertype must keep working, with every promised behavior, when given any of its subtypes; a subtype may require no more and promise no less.
    correct: true
    why: "That's the principle: substitutability based on the supertype's contract, not just its method signatures."
  - text: Every protocol must have at least two conforming types.
    correct: false
    why: Unrelated to Liskov; that's closer to a rule of thumb about when to introduce a protocol.
  - text: If a type conforms to a protocol and compiles, it satisfies Liskov.
    correct: false
    why: The compiler checks signatures, not promises. RecentOnlyStore compiles and still violates the contract.
solution: |
  The second option. Liskov is about **behavior**: the supertype's contract (documented or implied) must hold for every subtype, so code written against the supertype never needs to know which subtype it got. The compiler can only check that the methods exist with the right types.
````

````exercise
id: m14-l06-e2
type: prediction
prompt: "A `DeduplicatingStore` skips an expense if one with the same title already exists. What does the program print, and does it honor `ExpenseStore`'s contract (\"`all()` contains every expense added, in order\")?"
code: |
  struct Expense {
      let title: String
      let cents: Int
  }

  protocol ExpenseStore: AnyObject {
      func add(_ expense: Expense)
      func all() -> [Expense]
  }

  final class DeduplicatingStore: ExpenseStore {
      private var expenses: [Expense] = []
      func add(_ expense: Expense) {
          for existing in expenses where existing.title == expense.title {
              return
          }
          expenses.append(expense)
      }
      func all() -> [Expense] { expenses }
  }

  func total(of store: any ExpenseStore) -> Int {
      var sum = 0
      for expense in store.all() {
          sum += expense.cents
      }
      return sum
  }

  let store = DeduplicatingStore()
  store.add(Expense(title: "Coffee", cents: 450))
  store.add(Expense(title: "Coffee", cents: 380))
  store.add(Expense(title: "Lunch", cents: 1299))
  print(store.all().count)
  print(total(of: store))
output: |
  2
  1749
hints:
  - The second Coffee has the same title as the first.
  - "The return inside the loop leaves add(_:) without appending."
solution: |
  ```output
  2
  1749
  ```

  The second "Coffee" is dropped, so only two expenses are stored and the total is 450 + 1299 = 1749 instead of 2129. It **violates the contract**: `all()` doesn't contain every expense added. Two coffees on the same day are two real expenses. Any code written against `ExpenseStore`, like `total(of:)`, now gives a wrong answer without any error. Deduplication may be a valid feature, but it needs its own, honestly named type and contract.
````

````exercise
id: m14-l06-e3
type: find-errors
prompt: "Match the code to the principle it violates. Mark every statement that's correct."
code: |
  // 1
  protocol MediaPlayer {
      func play()
      func pause()
      func record()
      func editSubtitles()
  }
  struct AudioPreview: MediaPlayer { /* record and editSubtitles call fatalError */ }

  // 2
  final class ProfileViewController {
      // fetches JSON, decodes it, validates the email, saves to disk,
      // formats dates, and lays out 14 views
  }

  // 3
  final class OrderService {
      private let api = LiveHTTPClient()   // created inside, can't be replaced
  }

  // 4
  func shippingCost(for country: String) -> Int {
      // a switch with 40 country cases, edited every time a country is added
  }
choices:
  - text: "1 violates interface segregation (and Liskov, because the fatalError methods break the protocol's promise)."
    correct: true
  - text: 2 violates single responsibility.
    correct: true
  - text: 3 violates dependency inversion.
    correct: true
  - text: 4 is a candidate for open/closed (or simply data, like a table of rates), since it's edited for every new country.
    correct: true
  - text: 3 violates Liskov because OrderService is final.
    correct: false
    why: "final only forbids subclassing; it says nothing about substitutability. The problem is the hard-wired dependency."
rubric:
  - I matched each snippet to the right principle.
  - I explained why fatalError in a required method is also a Liskov problem.
  - I proposed a fix for at least two of them.
solution: |
  - **1**: `AudioPreview` is forced to implement recording and subtitles it can't do. Split into `Playable`, `Recordable`, `SubtitleEditable`. The `fatalError` bodies also break Liskov: code holding `any MediaPlayer` may call `record()` and crash.
  - **2**: networking, decoding, validation, storage, formatting and layout are six reasons to change. Move each into its own type; the view controller keeps layout and wiring.
  - **3**: `OrderService` creates its own client. Declare a protocol for what it needs and inject the client in `init`, so tests can pass a fake.
  - **4**: a growing `switch` that's edited for every country. Here the better fix may be data rather than types: a dictionary or a file of rates. Not every open/closed fix is a protocol.
````

````exercise
id: m14-l06-e4
type: solve
prompt: |
  This protocol forces every conforming type to do everything. Split it so that `HistoryScreen` depends only on what it uses, make `NoteStore` conform to all the pieces, and write a tiny `FixedNotes` stand-in for `HistoryScreen`. The program must print:

  ```output
  2 notes, latest: Call bank
  1 notes, latest: Sample
  ```
starter: |
  protocol NoteRepository {
      func all() -> [String]
      func add(_ note: String)
      func deleteAll()
  }

  final class NoteStore: NoteRepository {
      private var notes: [String] = []
      func all() -> [String] { notes }
      func add(_ note: String) { notes.append(note) }
      func deleteAll() { notes.removeAll() }
  }

  struct HistoryScreen {
      let repository: any NoteRepository
      func render() {
          let notes = repository.all()
          print("\(notes.count) notes, latest: \(notes.last ?? "none")")
      }
  }
hints:
  - "HistoryScreen only calls all()."
  - "Make a NoteReading protocol with all(), and a NoteWriting protocol with add and deleteAll."
  - "NoteStore can conform to both: final class NoteStore: NoteReading, NoteWriting."
rubric:
  - HistoryScreen's property is typed with the reading protocol only.
  - NoteStore conforms to every new protocol and keeps its behavior.
  - FixedNotes implements only the reading protocol.
  - The program prints exactly the two expected lines.
solution: |
  ```swift
  protocol NoteReading {
      func all() -> [String]
  }

  protocol NoteWriting {
      func add(_ note: String)
      func deleteAll()
  }

  final class NoteStore: NoteReading, NoteWriting {
      private var notes: [String] = []
      func all() -> [String] { notes }
      func add(_ note: String) { notes.append(note) }
      func deleteAll() { notes.removeAll() }
  }

  struct HistoryScreen {
      let source: any NoteReading
      func render() {
          let notes = source.all()
          print("\(notes.count) notes, latest: \(notes.last ?? "none")")
      }
  }

  struct FixedNotes: NoteReading {
      func all() -> [String] { ["Sample"] }
  }

  let store = NoteStore()
  store.add("Buy milk")
  store.add("Call bank")
  HistoryScreen(source: store).render()
  HistoryScreen(source: FixedNotes()).render()
  ```

  ```output
  2 notes, latest: Call bank
  1 notes, latest: Sample
  ```

  `HistoryScreen` can no longer delete notes by accident, and its stand-in is one line of behavior. Splitting writing further (add vs delete) would be possible but isn't needed by any client yet, so it isn't done.
````

````exercise
id: m14-l06-e5
type: refactor
prompt: Separate UI, logic and data in this function. The logic must be testable without printing anything. Keep the output identical.
code: |
  var savedScores: [Int] = []

  func submit(score text: String) {
      guard let score = Int(text), score >= 0, score <= 100 else {
          print("[alert] Score must be 0-100")
          return
      }
      savedScores.append(score)
      var sum = 0
      for s in savedScores { sum += s }
      print("[label] Average: \(sum / savedScores.count)")
  }

  submit(score: "80")
  submit(score: "abc")
  submit(score: "91")
rubric:
  - Validation lives in a function or type that returns a value or throws, without printing.
  - The average calculation lives in logic code that takes scores as input.
  - Storage is a separate type, ideally behind a small protocol the screen receives.
  - Only the UI part prints, and the output is unchanged.
solution: |
  ```swift
  // Data
  protocol ScoreStore: AnyObject {
      func add(_ score: Int)
      func all() -> [Int]
  }

  final class InMemoryScores: ScoreStore {
      private var scores: [Int] = []
      func add(_ score: Int) { scores.append(score) }
      func all() -> [Int] { scores }
  }

  // Logic
  func validatedScore(from text: String) -> Int? {
      guard let score = Int(text), score >= 0, score <= 100 else {
          return nil
      }
      return score
  }

  func average(of scores: [Int]) -> Int {
      var sum = 0
      for score in scores {
          sum += score
      }
      return scores.isEmpty ? 0 : sum / scores.count
  }

  // UI
  struct ScoreScreen {
      let store: any ScoreStore

      func submit(score text: String) {
          guard let score = validatedScore(from: text) else {
              print("[alert] Score must be 0-100")
              return
          }
          store.add(score)
          print("[label] Average: \(average(of: store.all()))")
      }
  }

  let screen = ScoreScreen(store: InMemoryScores())
  screen.submit(score: "80")
  screen.submit(score: "abc")
  screen.submit(score: "91")
  ```

  ```output
  [label] Average: 80
  [alert] Score must be 0-100
  [label] Average: 85
  ```

  `validatedScore(from:)` and `average(of:)` take values and return values, so they can be tested directly (`average(of: [80, 91]) == 85`). `average(of:)` also handles the empty array, which the original never had to because it always appended first; as a reusable function, it shouldn't divide by zero. The global `savedScores` is gone: the screen receives its store.
````

````exercise
id: m14-l06-e6
type: design
prompt: "Design the pieces of a \"Split the bill\" iOS feature: the user types a total and the number of people, picks a tip percentage, and sees each person's share; the last ten splits are saved. Name the types in each layer, the protocols, and say which principle each decision applies. Don't write the code."
rubric:
  - The UI layer only collects input and displays results.
  - Calculation and validation are in logic types that don't know about the UI.
  - History storage is behind a protocol owned by the logic layer, with an honest contract (the last ten).
  - Dependencies point from UI to logic and from data to logic's protocols.
  - At least one place explains why it does not add an abstraction.
solution: |
  One reasonable design:

  - **UI**: `SplitScreen` (a view or view controller) reads the text fields and the tip picker, calls the logic, shows the result or an error. It receives its dependencies in `init`. *(Single responsibility, separation of concerns.)*
  - **Logic**:
    - `BillInputParser` turns text into cents and a people count, throwing `BillInputError` for empty, non-numeric or zero people. *(Single responsibility.)*
    - `BillSplitter` takes cents, people and tip percentage and returns the shares, with leftover cents assigned deterministically. Pure value in, value out. *(Testable logic.)*
    - `protocol SplitHistory { func record(_ split: Split); func recent() -> [Split] }` with the contract "`recent()` returns at most the ten latest splits, newest first". *(Dependency inversion; Liskov, because the contract is written down and any implementation must keep it.)*
  - **Data**: `UserDefaultsSplitHistory` (or a file-based one) conforms to `SplitHistory`; tests use `InMemorySplitHistory`.
  - **Not abstracted**: `BillSplitter` is a concrete struct with no protocol. It has no side effects, so tests call it directly, and there's no second implementation in sight. *(Avoiding needless seams.)*

  Arrows: `SplitScreen` → `BillInputParser`, `BillSplitter`, `SplitHistory`; `UserDefaultsSplitHistory` → `SplitHistory`. The logic imports nothing from UIKit or SwiftUI.
````

````exercise
id: m14-l06-e7
type: explain
prompt: "A teammate proposes a rule: \"Every type must have a protocol, so we follow dependency inversion.\" Explain what you'd agree with and what you'd push back on."
code: |
  protocol BudgetSummaryProtocol {
      var totalCents: Int { get }
      var overByCents: Int? { get }
  }

  struct BudgetSummary: BudgetSummaryProtocol {
      let totalCents: Int
      let overByCents: Int?
  }

  protocol ExpenseParserProtocol {
      func parse(_ text: String) throws -> Expense
  }

  struct ExpenseParser: ExpenseParserProtocol { /* ... */ }
rubric:
  - I acknowledged the benefit where there's a real seam (network, storage, clock, tests).
  - I explained the cost of a protocol with a single implementation and no fake.
  - I said dependency inversion is about which way dependencies point, not about counting protocols.
  - I proposed a more useful rule (introduce a protocol when there's a second implementation or a test needs a fake).
solution: |
  Agree: things that are slow, external or nondeterministic (network, disk, the current date, notifications) should sit behind a protocol the logic owns, so the logic can be tested with fakes and the real thing can change. That's dependency inversion doing real work.

  Push back: a protocol for every type doubles the declarations and makes "jump to definition" land on an interface instead of the code, for no benefit when there's one implementation and no test that needs to replace it. Dependency inversion is about **direction**: the high-level policy shouldn't depend on low-level details. Pure logic like `BudgetSummary` isn't a detail anyone needs to swap.

  A better rule: introduce a protocol when there's a second implementation, when a test needs a fake, or at a boundary with the outside world. Refactoring a concrete type into a protocol later, in small steps with tests, is cheap.
````

## Summary

- **S**ingle responsibility: one reason to change. Split types along the lines of who asks for changes.
- **O**pen/closed: add behavior by adding types (like `PaymentMethod` conformers), not by editing working code, where new cases are expected.
- **L**iskov substitution: code written for a supertype must work with every subtype, with every promise kept. Subtypes may require no more and promise no less. A conformance that compiles can still violate it.
- **I**nterface segregation: small protocols matched to what each client uses, like `UITableViewDataSource` and `UITableViewDelegate`.
- **D**ependency inversion: high-level code owns the protocol, details conform and are injected.
- Separation of concerns: UI shows, logic decides, data stores. Logic knows nothing about the UI and can be tested with plain values.
- Add seams when they pay: a second implementation, a fake for tests, an external boundary.
