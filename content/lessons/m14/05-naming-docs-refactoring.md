---
id: m14-l05
title: Naming, documentation and refactoring
description: You name types, methods and Booleans the way the Swift API Design Guidelines describe so call sites read clearly, write documentation comments with Parameters, Returns and Throws that Xcode shows in Quick Help, and refactor a cryptic function in small steps (rename, extract function, replace a conditional with polymorphism), proving after every step that the output hasn't changed.
module: m14
order: 5
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l04]
objectives:
  - Apply the main naming rules of the Swift API Design Guidelines (clarity at the point of use, roles over types, no needless words, Booleans as assertions, mutating and nonmutating pairs, case conventions).
  - Write a documentation comment with a summary, a discussion, and Parameters, Returns and Throws sections.
  - Explain what refactoring is and why tests come before it.
  - Refactor in small steps (rename, extract function, replace a conditional with polymorphism), checking behavior after each step.
  - Recognize when a refactoring step accidentally changed behavior.
terms:
  - term: Point of use
    definition: "The place where a name is used, like a call site. The Swift API Design Guidelines judge names by how they read there, not in the declaration."
  - term: Documentation comment
    definition: "A comment starting with /// (or /** */) right before a declaration. Xcode shows it in Quick Help, and DocC turns it into reference pages."
  - term: Quick Help
    definition: "Xcode's pop-over that shows a symbol's declaration and documentation comment when you Option-click it."
  - term: DocC
    definition: "Swift's documentation compiler. It builds reference documentation and tutorials from documentation comments and Markdown files."
  - term: Refactoring
    definition: "Changing the structure of code without changing what it does, in small steps that each keep the program working."
  - term: Characterization test
    definition: "A test that records what existing code does right now, so you can tell if a change alters it. Written before refactoring code that has no tests."
  - term: Replace conditional with polymorphism
    definition: "A refactoring that turns an if/switch on a kind of thing into one type per kind conforming to a protocol, so each type supplies its own behavior."
mastery:
  - Rename a function so its call site reads as a grammatical phrase, with argument labels that clarify roles.
  - Name a Boolean property so it reads as an assertion (isOverLimit, hasReceipt).
  - Name a mutating method and its nonmutating counterpart (record / recording, sort / sorted).
  - Write a documentation comment for a throwing function with all of Parameters, Returns and Throws.
  - Refactor a long function into extracted helpers with the output unchanged, and point at the step where you'd run the tests.
  - Spot a refactoring that changed behavior by comparing outputs before and after.
resources: [swift-api-design-guidelines, swift-book-protocols]
cards:
  - id: m14-l05-c1
    front: What's the most important goal of the Swift API Design Guidelines?
    back: "Clarity at the point of use. Names are judged by how the call site reads, and clarity beats brevity."
  - id: m14-l05-c2
    front: How should Boolean properties read?
    back: "As assertions about the receiver: isEmpty, isOverLimit, hasReceipt, intersects(_:). `if budget.isOverLimit` reads like a sentence."
  - id: m14-l05-c3
    front: How do you name a mutating method and its nonmutating twin?
    back: "Imperative verb for the mutating one (sort, append, record), past participle -ed or present participle -ing for the one that returns a new value (sorted, appending, recording)."
  - id: m14-l05-c4
    front: What sections can a documentation comment have for a function?
    back: "A one-line summary, an optional discussion, and - Parameters: (or - Parameter name:), - Returns: and - Throws:. Xcode shows them in Quick Help."
  - id: m14-l05-c5
    front: What makes a change a refactoring?
    back: "The behavior stays exactly the same; only the structure changes. You prove it by running the same tests before and after every small step."
---

## The idea in one sentence

Code is read far more often than it's written, so name things for the reader, document what the name can't say, and improve structure in small steps that tests prove didn't change behavior.

## Naming: the Swift API Design Guidelines

Swift has an official style guide for names, the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). The standard library and Apple's frameworks follow it, which is why `array.remove(at: 2)` and `name.isEmpty` read the way they do. Its first rule sets the tone: **clarity at the point of use** is the most important goal, and clarity is more important than brevity. You judge a name where it's used, not where it's declared.

### The rules you'll use every day

**Include the words needed to avoid ambiguity.** `employees.remove(x)` could mean "remove the element equal to x". `employees.remove(at: x)` can only mean "remove at position x".

**Omit needless words.** `allViews.removeElement(cancelButton)`: "Element" repeats what the type already says. `allViews.remove(cancelButton)` is clearer.

**Name by role, not by type.** `var string = "Hello"` says nothing; `var greeting = "Hello"` says what it's for. A parameter of type `WidgetFactory` is better called `supplier` than `widgetFactory`.

**Make call sites read as phrases.** `x.insert(y, at: z)` reads "insert y at z". The guidelines also say to begin factory methods with `make`, like `makeIterator()`.

**Side effects decide the grammar.** A method that changes the value is an imperative verb: `sort()`, `append(_:)`. Its counterpart that returns a new value instead uses `-ed` or `-ing`: `sorted()`, `appending(_:)`. Methods without side effects that are naturally nouns read as nouns: `distance(to:)`.

**Booleans read as assertions about the receiver**: `isEmpty`, `intersects(_:)`. Not `empty` (a verb? an adjective?) and not `checkEmpty()`.

**Protocols**: what something **is** reads as a noun (`Collection`); a **capability** ends in `-able`, `-ible` or `-ing` (`Equatable`, `ProgressReporting`).

**Case conventions**: types and protocols in `UpperCamelCase`, everything else in `lowerCamelCase`. Acronyms that are normally all caps stay uniformly cased: `utf8Bytes`, `isRepresentableAsASCII`, `userSMTPServer`, and in your own code, `imageURL` and `URLSession` (not `imageUrl`).

**Avoid abbreviations** unless they're established terms of art (`min`, `sin`). `amt`, `calc` and `tmp` force the reader to guess.

### Before and after

The same budget type, named twice. First, names that make the reader work:

```swift
struct Bdgt {
    var lim: Int
    var spent = 0

    func check() -> Bool {
        spent > lim
    }

    mutating func addAmt(amt: Int) {
        spent += amt
    }
}

var b = Bdgt(lim: 5000)
b.addAmt(amt: 4500)
print(b.check())
```

```output
false
```

What does `check()` check? Is `true` good or bad? `addAmt(amt:)` says "amount" twice and still doesn't say what happens to it. Now the same behavior, named for the call site:

```swift
struct Budget {
    var limitCents: Int
    private(set) var spentCents = 0

    var isOverLimit: Bool {
        spentCents > limitCents
    }

    var remainingCents: Int {
        limitCents - spentCents
    }

    mutating func record(_ cents: Int) {
        spentCents += cents
    }

    func recording(_ cents: Int) -> Budget {
        var copy = self
        copy.record(cents)
        return copy
    }
}

var budget = Budget(limitCents: 5000)
budget.record(4500)
let afterDinner = budget.recording(1200)

print(budget.isOverLimit, budget.remainingCents)
print(afterDinner.isOverLimit, afterDinner.remainingCents)
```

```output
false 500
true -700
```

What changed:

- `Budget`, `limitCents`, `spentCents`: no abbreviations, and the unit is in the name, because "5000 what?" is a real question with money.
- `isOverLimit` is a property that reads as an assertion: `if budget.isOverLimit`.
- `record(_:)` mutates, so it's an imperative verb, and the first argument has no label because "record 4500" already reads well. `recording(_:)` is its nonmutating twin and returns a new budget: "the budget after recording 1200".

## Documentation comments

A good name says what something is. A **documentation comment** says what the name can't: units, edge cases, what's thrown and when. It starts with `///` right before the declaration and uses Markdown.

```swift
enum ImportError: Error {
    case wrongFieldCount(Int)
    case invalidAmount(String)
}

struct Expense {
    let title: String
    let cents: Int
}

/// Parses one line of an exported expense file.
///
/// The line has two comma-separated fields: a title and an amount in
/// whole cents. Whitespace isn't trimmed.
///
/// - Parameter line: A line such as `Coffee,450`.
/// - Returns: The expense the line describes.
/// - Throws: `ImportError.wrongFieldCount` if the line doesn't have exactly
///   two fields, or `ImportError.invalidAmount` if the amount isn't an integer.
func parseExpense(from line: String) throws(ImportError) -> Expense {
    let fields = line.split(separator: ",")
    guard fields.count == 2 else {
        throw .wrongFieldCount(fields.count)
    }
    guard let cents = Int(fields[1]) else {
        throw .invalidAmount(String(fields[1]))
    }
    return Expense(title: String(fields[0]), cents: cents)
}

for line in ["Coffee,450", "Lunch,12.99", "broken"] {
    do {
        let expense = try parseExpense(from: line)
        print("\(expense.title): \(expense.cents)")
    } catch {
        print("skipped \(line): \(error)")
    }
}
```

```output
Coffee: 450
skipped Lunch,12.99: invalidAmount("12.99")
skipped broken: wrongFieldCount(1)
```

The parts:

1. **Summary**: the first line. Per the guidelines, a sentence fragment ending in a period that says what the function does and returns. Many good doc comments are only this line.
2. **Discussion**: after a blank `///` line, complete sentences with whatever a caller needs to know: the format, the units, what isn't handled.
3. **`- Parameter name:`** for one parameter. For several, write `- Parameters:` followed by an indented list, `  - name: description`.
4. **`- Returns:`** what comes back.
5. **`- Throws:`** which errors, and when. Continuation lines are indented.

In Xcode, **Option-click** a documented symbol to see this in **Quick Help**, formatted, with the summary, discussion, parameters, return value and errors in separate sections. It's also in the Quick Help inspector. Xcode can write the skeleton for you: Control-click the symbol and choose *Add Documentation* from the Code Actions menu. (These Xcode steps come from Apple's [Writing symbol documentation in your source files](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files); they weren't checked in Xcode for this lesson.)

For a package or framework, **DocC** compiles the same comments into a documentation site, and you can add articles and tutorials alongside. Xcode builds it with *Product > Build Documentation*. The reference is [DocC on swift.org](https://www.swift.org/documentation/docc/), including how to [write symbol documentation](https://www.swift.org/documentation/docc/writing-symbol-documentation-in-your-source-files). In DocC, a symbol name wrapped in double backticks becomes a link to that symbol's page; the comment on `paymentMethod(named:)` later in this lesson does that with `NoFee`.

What to document:

- **Every `public` declaration** of a package. Its users can't read your mind or, often, your source.
- **Internal code when the name isn't enough**: units, preconditions, surprising behavior, why it's done this way.
- **Not the obvious.** `/// Returns the title.` on `var title` is noise that has to be kept in sync for nothing.

> [!tip] Comments vs documentation comments
> `//` comments explain **how** or **why** inside the code, for whoever edits it. `///` comments describe **what** a declaration does, for whoever calls it. A `//` comment that explains what a block does is often a sign the block should be a function with that name.

## Refactoring

**Refactoring** means changing the structure of code without changing what it does. Not adding features, not fixing bugs: the same inputs give the same outputs, and the code is easier to read and change afterwards. It's done in **small steps**, each of which keeps everything working, so that if something breaks you know exactly which step did it.

That requires a way to know "everything still works": **tests**. If the code has none, the first step is to write tests that record what it does today, bugs included. Those are **characterization tests**. Fixing a bug you find is a separate change, in its own commit, after the refactoring.

### The starting point

An importer someone wrote in a hurry. It reads `title,cents,method` lines, computes a fee per payment method, and prints a report:

```swift
func proc(_ d: [String]) {
    var t = 0
    var f = 0
    for l in d {
        let p = l.split(separator: ",")
        if p.count != 3 { continue }
        let n = String(p[0])
        let c = Int(p[1]) ?? 0
        let k = String(p[2])
        var x = 0
        if k == "card" {
            x = c * 3 / 100
        } else if k == "transfer" {
            x = 50
        }
        t += c
        f += x
        print("\(n): \(c) + fee \(x)")
    }
    print("total \(t), fees \(f)")
}

proc(["Coffee,450,card", "Rent,90000,transfer", "Lunch,1299,cash", "Taxi,1800,crypto", "broken line"])
```

```output
Coffee: 450 + fee 13
Rent: 90000 + fee 50
Lunch: 1299 + fee 0
Taxi: 1800 + fee 0
total 93549, fees 63
```

**This output is the safety net.** The input deliberately covers every path: each known method, an unknown one (`crypto`) and a malformed line. Every step below must print exactly these five lines. (In this course, the snippet tests compare each block's output to the text, so each step really is checked. In a package, you'd write the same check as a test and run `swift test` after every step.)

Notice what the output tells you about current behavior: card fees round down (450 × 3 / 100 is 13.5, printed as 13), unknown methods are charged nothing, and malformed lines are silently skipped. You may not like all of that. You keep it anyway, for now.

### Step 1: rename

The cheapest, safest refactoring. Xcode can rename a symbol and every use of it in one action; here it's done by hand:

```swift
func printFeeReport(for lines: [String]) {
    var totalCents = 0
    var totalFees = 0
    for line in lines {
        let fields = line.split(separator: ",")
        if fields.count != 3 { continue }
        let title = String(fields[0])
        let cents = Int(fields[1]) ?? 0
        let method = String(fields[2])
        var fee = 0
        if method == "card" {
            fee = cents * 3 / 100
        } else if method == "transfer" {
            fee = 50
        }
        totalCents += cents
        totalFees += fee
        print("\(title): \(cents) + fee \(fee)")
    }
    print("total \(totalCents), fees \(totalFees)")
}

printFeeReport(for: ["Coffee,450,card", "Rent,90000,transfer", "Lunch,1299,cash", "Taxi,1800,crypto", "broken line"])
```

```output
Coffee: 450 + fee 13
Rent: 90000 + fee 50
Lunch: 1299 + fee 0
Taxi: 1800 + fee 0
total 93549, fees 63
```

Same output. Commit. The function now explains itself, and the next steps are easier to see.

### Step 2: extract function

The loop body does three jobs: parse a line, compute a fee, update totals and print. Pull the first two out into functions with names, and give the parsed line a type:

```swift
struct Payment {
    let title: String
    let cents: Int
    let method: String
}

func parsePayment(from line: String) -> Payment? {
    let fields = line.split(separator: ",")
    guard fields.count == 3 else { return nil }
    return Payment(title: String(fields[0]), cents: Int(fields[1]) ?? 0, method: String(fields[2]))
}

func fee(forCents cents: Int, method: String) -> Int {
    if method == "card" {
        return cents * 3 / 100
    } else if method == "transfer" {
        return 50
    }
    return 0
}

func printFeeReport(for lines: [String]) {
    var totalCents = 0
    var totalFees = 0
    for line in lines {
        guard let payment = parsePayment(from: line) else { continue }
        let paymentFee = fee(forCents: payment.cents, method: payment.method)
        totalCents += payment.cents
        totalFees += paymentFee
        print("\(payment.title): \(payment.cents) + fee \(paymentFee)")
    }
    print("total \(totalCents), fees \(totalFees)")
}

printFeeReport(for: ["Coffee,450,card", "Rent,90000,transfer", "Lunch,1299,cash", "Taxi,1800,crypto", "broken line"])
```

```output
Coffee: 450 + fee 13
Rent: 90000 + fee 50
Lunch: 1299 + fee 0
Taxi: 1800 + fee 0
total 93549, fees 63
```

Same output. The extracted functions return values instead of printing, so they can now be tested directly, which the original never could. In a package, those tests would look like this:

```swift illustrative
import Testing

@Test func cardFeeIsThreePercentRoundedDown() {
    #expect(fee(forCents: 450, method: "card") == 13)
}

@Test func linesWithoutThreeFieldsAreSkipped() {
    #expect(parsePayment(from: "broken line") == nil)
}
```

### Step 3: replace the conditional with polymorphism

`fee(forCents:method:)` is an `if` chain on a string. Every new payment method means editing it, and every other per-method behavior (a display name, an icon, a refund rule) would grow its own chain on the same string. **Replace conditional with polymorphism**: one type per method, all conforming to a protocol, each supplying its own fee.

A first attempt, which also turns unknown names into `nil`:

```swift
protocol PaymentMethod {
    func fee(forCents cents: Int) -> Int
}

struct Card: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        cents * 3 / 100
    }
}

struct BankTransfer: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        50
    }
}

struct Cash: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        0
    }
}

struct Payment {
    let title: String
    let cents: Int
    let method: any PaymentMethod
}

func paymentMethod(named name: String) -> (any PaymentMethod)? {
    switch name {
    case "card": return Card()
    case "transfer": return BankTransfer()
    case "cash": return Cash()
    default: return nil
    }
}

func parsePayment(from line: String) -> Payment? {
    let fields = line.split(separator: ",")
    guard fields.count == 3, let method = paymentMethod(named: String(fields[2])) else {
        return nil
    }
    return Payment(title: String(fields[0]), cents: Int(fields[1]) ?? 0, method: method)
}

func printFeeReport(for lines: [String]) {
    var totalCents = 0
    var totalFees = 0
    for line in lines {
        guard let payment = parsePayment(from: line) else { continue }
        let fee = payment.method.fee(forCents: payment.cents)
        totalCents += payment.cents
        totalFees += fee
        print("\(payment.title): \(payment.cents) + fee \(fee)")
    }
    print("total \(totalCents), fees \(totalFees)")
}

printFeeReport(for: ["Coffee,450,card", "Rent,90000,transfer", "Lunch,1299,cash", "Taxi,1800,crypto", "broken line"])
```

```output
Coffee: 450 + fee 13
Rent: 90000 + fee 50
Lunch: 1299 + fee 0
total 91749, fees 63
```

**The output changed.** The Taxi line is gone and the total dropped by 1800. Returning `nil` for unknown methods felt tidier, and it silently changed behavior: payments with an unrecognized method used to count, and now they vanish from the report. Maybe that's even the right call, but it's a product decision, not a refactoring, and it doesn't belong in the same step. This is exactly what the safety net is for. Undo the step and take it again, preserving the old behavior on purpose:

```swift
/// A way of paying that may charge a fee.
protocol PaymentMethod {
    /// Returns the fee, in cents, for paying the given amount this way.
    ///
    /// - Parameter cents: The amount paid, in cents.
    /// - Returns: The fee in cents. Never negative for a non-negative amount.
    func fee(forCents cents: Int) -> Int
}

/// Card payments: 3% of the amount, rounded down.
struct Card: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        cents * 3 / 100
    }
}

/// Bank transfers: a flat 50 cents.
struct BankTransfer: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        50
    }
}

/// Cash, and any method the importer doesn't recognize: no fee.
struct NoFee: PaymentMethod {
    func fee(forCents cents: Int) -> Int {
        0
    }
}

struct Payment {
    let title: String
    let cents: Int
    let method: any PaymentMethod
}

/// Returns the payment method for a name used in imported files.
///
/// Unknown names get ``NoFee``, which is what the importer did
/// before this refactoring.
func paymentMethod(named name: String) -> any PaymentMethod {
    switch name {
    case "card": return Card()
    case "transfer": return BankTransfer()
    default: return NoFee()
    }
}

/// Parses one `title,cents,method` line.
///
/// - Parameter line: A line such as `Coffee,450,card`.
/// - Returns: The payment, or `nil` if the line doesn't have three fields.
func parsePayment(from line: String) -> Payment? {
    let fields = line.split(separator: ",")
    guard fields.count == 3 else { return nil }
    return Payment(
        title: String(fields[0]),
        cents: Int(fields[1]) ?? 0,
        method: paymentMethod(named: String(fields[2]))
    )
}

func printFeeReport(for lines: [String]) {
    var totalCents = 0
    var totalFees = 0
    for line in lines {
        guard let payment = parsePayment(from: line) else { continue }
        let fee = payment.method.fee(forCents: payment.cents)
        totalCents += payment.cents
        totalFees += fee
        print("\(payment.title): \(payment.cents) + fee \(fee)")
    }
    print("total \(totalCents), fees \(totalFees)")
}

printFeeReport(for: ["Coffee,450,card", "Rent,90000,transfer", "Lunch,1299,cash", "Taxi,1800,crypto", "broken line"])
```

```output
Coffee: 450 + fee 13
Rent: 90000 + fee 50
Lunch: 1299 + fee 0
Taxi: 1800 + fee 0
total 93549, fees 63
```

Identical to the original. What you have now:

- The string-to-type decision happens **once**, in `paymentMethod(named:)`, at the edge where text comes in. Everywhere else, code calls `payment.method.fee(forCents:)` and each type answers for itself.
- Adding a payment method means adding a type and one `case`. The report doesn't change.
- Each fee rule can be tested on its own: `#expect(Card().fee(forCents: 450) == 13)`.
- The behavior choices that were hidden in an `else` are now written down in documentation comments.

> [!note] An enum would also work
> When the set of cases is closed and small, an `enum PaymentMethod { case card, transfer, cash }` with a `fee(forCents:)` method that switches over `self` is good Swift too, and the compiler checks the switch is exhaustive. A protocol pays off when new kinds get added from other modules, or when each kind carries several behaviors and its own data. Both beat a string compared in several places.

### Habits that keep refactoring safe

- **Tests first.** No safety net, no refactoring; write characterization tests.
- **One small step at a time**, running the tests after each. If they fail, the cause is in the last few lines you touched.
- **Commit after each green step.** Undoing a bad step is then `git restore .`.
- **Never mix refactoring with behavior changes** in a commit or pull request. Reviewers can verify "same behavior" quickly only when that's all the change claims.
- **Let the tools help.** Xcode's refactoring actions, such as renaming a symbol, update every reference consistently. (They weren't exercised for this lesson; the steps here were done by hand.)

## Common mistakes

> [!error] Names that need a comment to be understood
> `let d = 7 // days until the bill is due` should be `let daysUntilDue = 7`. Fix the name and the comment becomes unnecessary.

> [!error] A Boolean named like an action
> `func check() -> Bool` or `var valid: Bool`. Use `isValid`, `hasReceipt`, `canRetry`, so `if` statements read as sentences.

> [!error] Documentation that repeats the declaration
> `/// The title.` on `let title: String` adds nothing. Document units, ranges, edge cases and errors instead.

> [!error] "Refactoring" that changes behavior
> As in step 3's first attempt. If the outputs or tests change, it wasn't a refactoring. Revert, then make the behavior change separately and deliberately.

> [!error] Refactoring without tests
> You can't know you preserved behavior if nothing checks it. Write characterization tests first, even if they record behavior you think is wrong.

## Exercises

````exercise
id: m14-l05-e1
type: comprehension
prompt: According to the Swift API Design Guidelines, which is the best name for a property that tells whether an expense list contains a refund?
choices:
  - text: "`refund`"
    correct: false
    why: Reads as a noun; is it the refund itself?
  - text: "`checkRefunds()`"
    correct: false
    why: Sounds like an action with side effects, and doesn't say what true means.
  - text: "`hasRefund`"
    correct: true
    why: "A Boolean that reads as an assertion about the receiver: if expenses.hasRefund."
  - text: "`refundBool`"
    correct: false
    why: Repeats the type instead of describing the role.
solution: |
  **`hasRefund`**. Boolean properties should read as assertions about the receiver, like `isEmpty` or `intersects(_:)`. At the call site, `if report.hasRefund { … }` reads as a sentence and makes `true` unambiguous.
````

````exercise
id: m14-l05-e2
type: prediction
prompt: "Mutating and nonmutating twins. What does this print?"
code: |
  struct Budget {
      var limitCents: Int
      private(set) var spentCents = 0

      var isOverLimit: Bool {
          spentCents > limitCents
      }

      mutating func record(_ cents: Int) {
          spentCents += cents
      }

      func recording(_ cents: Int) -> Budget {
          var copy = self
          copy.record(cents)
          return copy
      }
  }

  var budget = Budget(limitCents: 1000)
  let preview = budget.recording(1500)
  print(preview.isOverLimit, budget.isOverLimit)
  budget.record(600)
  budget.record(400)
  print(budget.spentCents, budget.isOverLimit)
output: |
  true false
  1000 false
hints:
  - recording returns a modified copy; it doesn't touch budget.
  - "isOverLimit uses >, not >=."
solution: |
  ```output
  true false
  1000 false
  ```

  `recording(1500)` works on a copy, so `preview` has spent 1500 (over 1000) while `budget` is untouched. Then two `record` calls really mutate `budget`: 600 + 400 = 1000, which is **not** greater than the limit. The names carry that difference: the imperative `record` changes the value, the `-ing` form `recording` returns a new one.
````

````exercise
id: m14-l05-e3
type: refactor
prompt: Rename everything in this function so the call site and the body read clearly, following the guidelines. Keep the behavior identical.
code: |
  func calc(a: [Int], b: Int) -> Int {
      var r = 0
      for x in a {
          if x > b {
              r += 1
          }
      }
      return r
  }

  print(calc(a: [450, 1299, 9000, 300], b: 1000))
rubric:
  - The function name says what it computes, and the call site reads as a phrase.
  - Argument labels describe roles (the limit), not types or letters.
  - Local names describe their role (count, amount).
  - The output is still 2.
solution: |
  ```swift
  func countOfAmounts(_ amounts: [Int], over limit: Int) -> Int {
      var count = 0
      for amount in amounts {
          if amount > limit {
              count += 1
          }
      }
      return count
  }

  print(countOfAmounts([450, 1299, 9000, 300], over: 1000))
  ```

  ```output
  2
  ```

  The call site now reads "count of amounts … over 1000". The first argument needs no label because the base name already says what it is; `over` explains the role of the second argument. Inside, `count`, `amount` and `limit` say what each value is for. Behavior is unchanged: two amounts (1299 and 9000) are above 1000.
````

````exercise
id: m14-l05-e4
type: fill-in
prompt: Complete the documentation comment so Quick Help shows a parameter, the return value and the error.
code: |
  /// Splits a bill evenly between people, in whole cents.
  ///
  /// Any leftover cents go to the first person.
  ///
  /// - [[1]] people: How many people share the bill. Must be at least 1.
  /// - [[2]]: Each person's share, first person first.
  /// - [[3]]: `SplitError.noPeople` if `people` is less than 1.
  func split(_ cents: Int, between people: Int) throws(SplitError) -> [Int]
blanks:
  - id: "1"
    answers: ["Parameter"]
  - id: "2"
    answers: ["Returns"]
  - id: "3"
    answers: ["Throws"]
solution: |
  ```swift illustrative
  /// Splits a bill evenly between people, in whole cents.
  ///
  /// Any leftover cents go to the first person.
  ///
  /// - Parameter people: How many people share the bill. Must be at least 1.
  /// - Returns: Each person's share, first person first.
  /// - Throws: `SplitError.noPeople` if `people` is less than 1.
  func split(_ cents: Int, between people: Int) throws(SplitError) -> [Int]
  ```

  `- Parameter name:` documents one parameter (use `- Parameters:` with an indented list for several). `- Returns:` and `- Throws:` describe the result and the errors. Note that the comment documents `people` by its parameter name, not by its argument label `between`.
````

````exercise
id: m14-l05-e5
type: solve
prompt: |
  Implement `split(_:between:)` as documented in the previous exercise, with `enum SplitError: Error { case noPeople }`. Then print the result of splitting 1000 cents between 3 people, and handle the error for 0 people by printing `can't split between nobody`.

  Expected output:

  ```output
  [334, 333, 333]
  can't split between nobody
  ```
starter: |
  enum SplitError: Error {
      case noPeople
  }

  /// Splits a bill evenly between people, in whole cents.
  ///
  /// Any leftover cents go to the first person.
  ///
  /// - Parameter people: How many people share the bill. Must be at least 1.
  /// - Returns: Each person's share, first person first.
  /// - Throws: `SplitError.noPeople` if `people` is less than 1.
  func split(_ cents: Int, between people: Int) throws(SplitError) -> [Int] {
      // your code
  }
hints:
  - "cents / people is each share; cents % people is what's left over."
  - "Array(repeating:count:) builds the list of equal shares; then add the leftover to index 0."
rubric:
  - The function throws SplitError.noPeople when people is less than 1.
  - The shares add up to the original amount, and the leftover goes to the first person.
  - The call sites use try inside do/catch and print the requested lines.
  - The documentation comment still matches what the code does.
solution: |
  ```swift
  enum SplitError: Error {
      case noPeople
  }

  /// Splits a bill evenly between people, in whole cents.
  ///
  /// Any leftover cents go to the first person.
  ///
  /// - Parameter people: How many people share the bill. Must be at least 1.
  /// - Returns: Each person's share, first person first.
  /// - Throws: `SplitError.noPeople` if `people` is less than 1.
  func split(_ cents: Int, between people: Int) throws(SplitError) -> [Int] {
      guard people >= 1 else {
          throw .noPeople
      }
      var shares = Array(repeating: cents / people, count: people)
      shares[0] += cents % people
      return shares
  }

  do {
      print(try split(1000, between: 3))
      print(try split(1000, between: 0))
  } catch {
      print("can't split between nobody")
  }
  ```

  ```output
  [334, 333, 333]
  can't split between nobody
  ```

  1000 / 3 is 333 with 1 left over, which goes to the first share. The `guard` comes first so the division never sees 0. Because the function uses typed throws, the `catch` knows `error` is a `SplitError`; with one case, there's nothing more to match.
````

````exercise
id: m14-l05-e6
type: find-errors
prompt: "A teammate says this commit is \"just a refactoring\". Compare the two versions and mark every real problem."
code: |
  // Before
  func shippingCents(forWeightGrams grams: Int) -> Int {
      if grams <= 500 { return 499 }
      return 499 + (grams - 500) / 100 * 50
  }

  // After
  func shippingCents(forWeightGrams grams: Int) -> Int {
      let extraBlocks = (grams - 500 + 99) / 100
      return grams <= 500 ? 499 : 499 + extraBlocks * 50
  }
choices:
  - text: "The new version rounds partial 100 g blocks up (+ 99), the old one rounds down. For 650 g, the old version returns 549, the new one 599."
    correct: true
  - text: "Because it changes results, it isn't a refactoring; it should be a separate, deliberate change with its own tests."
    correct: true
  - text: The ternary operator can't be used in a return statement.
    correct: false
    why: return with a ternary expression is fine.
  - text: The function should have been renamed to shipping.
    correct: false
    why: The original name is clear, with the unit and the parameter's role in it.
rubric:
  - I computed both versions for a weight that isn't a multiple of 100 above 500.
  - I said a behavior change isn't a refactoring and belongs in its own commit.
solution: |
  For 650 g: before, `(650 - 500) / 100` is `1`, so `499 + 50 = 549`. After, `(150 + 99) / 100` is `2`, so `499 + 100 = 599`. The change rounds partial blocks **up**. That might be what the business wants, but then it's a pricing change: it needs its own commit, its own tests for the new rule, and a description that says prices go up for some parcels. Calling it a refactoring hides it from the reviewer.
````

## Summary

- Name for the point of use: include words that remove ambiguity, omit words that repeat the type, name by role, make calls read as phrases.
- Booleans read as assertions (`isOverLimit`); mutating methods are verbs (`record`), their nonmutating twins use `-ed`/`-ing` (`recording`); types are `UpperCamelCase`, everything else `lowerCamelCase`; avoid abbreviations.
- `///` documentation comments: a summary line, an optional discussion, then `- Parameter(s):`, `- Returns:` and `- Throws:`. Xcode shows them in Quick Help; DocC builds documentation from them.
- Refactoring changes structure, never behavior. Get tests (or characterization tests) first, take small steps, run the tests after each, commit each green step.
- Rename, extract function and replace conditional with polymorphism are everyday refactorings. If the output changes, it wasn't a refactoring.
