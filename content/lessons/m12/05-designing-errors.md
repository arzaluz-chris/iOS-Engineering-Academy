---
id: m12-l05
title: "Designing errors: validation, domain and infrastructure"
description: You give errors user-facing messages with LocalizedError, report every validation problem at once, guarantee valid values with throwing initializers, keep business-rule errors apart from plumbing errors and translate between them at layer boundaries, and write higher-order functions with rethrows.
module: m12
order: 5
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l04]
objectives:
  - Conform an error to LocalizedError and provide a user-facing errorDescription.
  - Report all validation problems at once instead of only the first.
  - Write a throwing initializer that guarantees every instance is valid.
  - Tell domain errors from infrastructure errors in a given system.
  - Translate infrastructure errors into domain errors at a layer boundary without losing the details for logs.
  - Write a higher-order function with rethrows and explain when callers need try.
terms:
  - term: LocalizedError
    definition: "A Foundation protocol that refines Error with optional user-facing text: errorDescription, failureReason, recoverySuggestion. error.localizedDescription returns errorDescription when it's provided."
  - term: Validation error
    definition: "An error that says input breaks a rule: too short, missing @, a date in the past. The user can fix it, so it needs a clear message."
  - term: Domain error
    definition: "An error that comes from the rules of the problem the app solves: insufficient funds, sold out, coupon expired. It means the same thing whatever technology is underneath."
  - term: Infrastructure error
    definition: "An error from the plumbing: disk full, timeout, server returned 503, data couldn't be decoded. It's about how the app works, not what it does."
  - term: Error translation
    definition: "Catching an error from a lower layer and throwing one that makes sense to the layer above, usually keeping the original for logging."
  - term: rethrows
    definition: "A marker for a function that takes a throwing closure and throws only if that closure throws. Called with a non-throwing closure, it needs no try."
mastery:
  - Add LocalizedError messages to an error enum and show them with localizedDescription.
  - Change a validator that stops at the first problem into one that throws all problems together.
  - Replace an init? with an init that throws a specific error, and say what the caller gains.
  - Sort a list of failures into domain and infrastructure errors.
  - Write a repository method that catches storage errors and throws a domain error with the cause attached.
  - "Write a rethrows function and call it with and without a throwing closure."
resources: [foundation-localizederror, swift-book-error-handling, swift-book-initialization, swift-book-closures, swift-book-protocols]
cards:
  - id: m12-l05-c1
    front: How do you give an error a message for users?
    back: "Conform it to LocalizedError (import Foundation) and implement errorDescription. error.localizedDescription then returns that text."
  - id: m12-l05-c2
    front: Domain error or infrastructure error? "Coupon expired", "Request timed out", "Item sold out", "Couldn't decode JSON".
    back: "Domain: coupon expired, sold out (business rules). Infrastructure: timeout, decoding (plumbing)."
  - id: m12-l05-c3
    front: Why translate infrastructure errors at a layer boundary?
    back: "So upper layers deal with a small, stable set of meaningful errors instead of every library's error types. Keep the original as an associated value or log it, so the detail isn't lost."
  - id: m12-l05-c4
    front: "init? or init() throws?"
    back: "init? when there's one obvious reason creation fails. init() throws when the caller needs to know which rule the input broke."
  - id: m12-l05-c5
    front: "What does rethrows mean?"
    back: "The function throws only if the closure you pass it throws. Pass a non-throwing closure and the call needs no try."
---

## The idea in one sentence

An error has two audiences, code that decides what to do and people who need to understand what happened, and good error design serves both while keeping business failures apart from technical ones.

## Messages for people: LocalizedError

An error enum is for code: you `switch` on it. Users need a sentence. You could write a `message` property, as lesson 2 did, but Foundation has a standard protocol for it: **`LocalizedError`**. Apple's frameworks, and SwiftUI's alerts, know how to read it.

```swift
import Foundation

enum SignupError: Error, LocalizedError {
    case emailMissingAt
    case passwordTooShort(minimum: Int)
    case underage(minimumAge: Int)

    var errorDescription: String? {
        switch self {
        case .emailMissingAt:
            return "Enter a valid email address."
        case .passwordTooShort(let minimum):
            return "Your password needs at least \(minimum) characters."
        case .underage(let minimumAge):
            return "You must be \(minimumAge) or older to sign up."
        }
    }
}

func signUp(email: String, password: String, age: Int) throws {
    guard email.contains("@") else {
        throw SignupError.emailMissingAt
    }
    guard password.count >= 8 else {
        throw SignupError.passwordTooShort(minimum: 8)
    }
    guard age >= 16 else {
        throw SignupError.underage(minimumAge: 16)
    }
}

do {
    try signUp(email: "ana@example.com", password: "short", age: 30)
} catch {
    print(error.localizedDescription)
    print(error)
}
```

```output
Your password needs at least 8 characters.
passwordTooShort(minimum: 8)
```

1. `LocalizedError` lives in **Foundation**, so the file needs `import Foundation`. It inherits from `Error`, so listing `Error` too is optional but harmless.
2. All its requirements have defaults; you implement the ones you want. `errorDescription` is the main one. It's a `String?` so that returning `nil` falls back to the default.
3. `error.localizedDescription` is available on **any** error once Foundation is imported. For a `LocalizedError`, it returns your `errorDescription`. Notice it works even though `error` is typed `any Error` in the catch.
4. `print(error)` still shows the case. That's what you want in logs: precise, not pretty.

Without `LocalizedError`, `localizedDescription` exists but returns a generic sentence along the lines of "The operation couldn't be completed", followed by the type name and a number. Not something to show anyone. The exact wording differs between platforms.

`LocalizedError` also has `failureReason` and `recoverySuggestion`, for longer explanations. And the name hints at **localization**: in an app, `errorDescription` would return text translated for the user's language. That's a later module; for now, the important part is that the user-facing text lives with the error, in one `switch`.

> [!tip] Two audiences, two outputs
> Show `localizedDescription` to users. Log `print(error)` (or a logger, later) for developers. Never show raw `print(error)` output in the UI.

## Reporting every problem at once

`signUp` above stops at the first broken rule. A form that tells you about one mistake per submit is irritating: fix the email, submit, now the password; fix it, submit, now the age. Collect all problems and throw them together:

```swift
import Foundation

enum SignupProblem: Equatable {
    case emailMissingAt
    case passwordTooShort(minimum: Int)
    case underage(minimumAge: Int)

    var message: String {
        switch self {
        case .emailMissingAt:
            return "Enter a valid email address."
        case .passwordTooShort(let minimum):
            return "Your password needs at least \(minimum) characters."
        case .underage(let minimumAge):
            return "You must be \(minimumAge) or older."
        }
    }
}

struct SignupValidationError: Error, LocalizedError {
    let problems: [SignupProblem]

    var errorDescription: String? {
        problems.map { $0.message }.joined(separator: "\n")
    }
}

func validateSignup(email: String, password: String, age: Int) throws(SignupValidationError) {
    var problems: [SignupProblem] = []
    if !email.contains("@") {
        problems.append(.emailMissingAt)
    }
    if password.count < 8 {
        problems.append(.passwordTooShort(minimum: 8))
    }
    if age < 16 {
        problems.append(.underage(minimumAge: 16))
    }
    guard problems.isEmpty else {
        throw SignupValidationError(problems: problems)
    }
}

do {
    try validateSignup(email: "ana.example.com", password: "abc", age: 14)
} catch {
    print("\(error.problems.count) problems:")
    print(error.localizedDescription)
    print("Highlight email field: \(error.problems.contains(.emailMissingAt))")
}
```

```output
3 problems:
Enter a valid email address.
Your password needs at least 8 characters.
You must be 16 or older.
Highlight email field: true
```

The design:

- **`SignupProblem`** is a plain enum, not an error. Each case is one broken rule, with a `message`. It's `Equatable` so the screen can ask "is there an email problem?" and highlight that field.
- **`SignupValidationError`** is the one error type, holding **all** problems. Its `errorDescription` joins the messages.
- `validateSignup` uses `if`, not `guard`, so every rule runs. It throws once at the end if anything was found. Typed throws makes `error` a `SignupValidationError` in the catch, so `error.problems` works directly.

## Throwing initializers

Module 9 showed `init?` for values that can't exist with bad input, and promised the throwing version. Use **`init() throws`** when the caller needs to know **which** rule the input broke:

```swift
import Foundation

enum EmailError: Error {
    case empty
    case missingAt
    case missingDomain
}

struct EmailAddress {
    let value: String

    init(_ raw: String) throws(EmailError) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw .empty
        }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else {
            throw .missingAt
        }
        guard parts[1].contains(".") else {
            throw .missingDomain
        }
        value = trimmed.lowercased()
    }
}

for raw in ["  Ana@Example.com ", "", "ana.example.com", "ana@localhost"] {
    do {
        let email = try EmailAddress(raw)
        print("valid: \(email.value)")
    } catch {
        print("invalid (\(error)): \"\(raw)\"")
    }
}
```

```output
valid: ana@example.com
invalid (empty): ""
invalid (missingAt): "ana.example.com"
invalid (missingDomain): "ana@localhost"
```

`trimmingCharacters(in: .whitespaces)` removes leading and trailing spaces; it comes from Foundation, hence the import. `omittingEmptySubsequences: false` makes `split` keep empty pieces, so `"@example.com"` splits into an empty name and a domain instead of just the domain.

What a throwing initializer buys you:

1. **Every `EmailAddress` that exists is valid.** `value` is a `let` and there's no other initializer, so code that receives an `EmailAddress` never checks again. That's the Module 9 idea: the type carries the guarantee.
2. **The caller learns which rule failed**, which `init?` can't say.
3. **Creation reads like any throwing call**: `try EmailAddress(raw)`, with `try?` if you only care whether it worked.

Choose `init?` when there's one obvious reason (`Int("abc")`), and `init() throws` when there are several the caller treats differently.

## Domain errors and infrastructure errors

As an app grows, two very different kinds of failure show up.

**Domain errors** come from the rules of the problem: "insufficient funds", "this seat is taken", "coupon expired". They'd exist even if the app ran on paper. The user can usually understand them, and often fix them.

**Infrastructure errors** come from the plumbing: "the disk is full", "the request timed out", "the server returned 503", "the JSON had no `price` field". They're about **how** the app works. The user can't fix a missing JSON field; at most they can retry later.

The mistake is letting infrastructure errors leak upward. If a screen catches `DatabaseError.constraintViolation(code: 19)`, the screen now depends on the database library, and swapping it breaks the UI. Instead, **translate at the boundary**: the layer that talks to storage catches its errors and throws errors that mean something to the layer above.

```swift
enum StorageError: Error {
    case diskFull
    case corruptRecord(id: Int)
}

protocol OrderStorage {
    func loadBalance(customer: Int) throws -> Int
    func saveOrder(customer: Int, total: Int) throws
}

enum OrderError: Error {
    case insufficientFunds(balance: Int, needed: Int)
    case unavailable(underlying: any Error)
}

struct OrderService {
    let storage: any OrderStorage

    func placeOrder(customer: Int, total: Int) throws(OrderError) {
        let balance: Int
        do {
            balance = try storage.loadBalance(customer: customer)
        } catch {
            throw .unavailable(underlying: error)
        }
        guard balance >= total else {
            throw .insufficientFunds(balance: balance, needed: total)
        }
        do {
            try storage.saveOrder(customer: customer, total: total)
        } catch {
            throw .unavailable(underlying: error)
        }
    }
}

struct FakeStorage: OrderStorage {
    func loadBalance(customer: Int) throws -> Int {
        if customer == 3 {
            throw StorageError.corruptRecord(id: 3)
        }
        return customer == 1 ? 5000 : 800
    }

    func saveOrder(customer: Int, total: Int) throws {
        if total > 4000 {
            throw StorageError.diskFull
        }
    }
}

let service = OrderService(storage: FakeStorage())
for (customer, total) in [(1, 1200), (2, 1200), (3, 100), (1, 4500)] {
    do {
        try service.placeOrder(customer: customer, total: total)
        print("customer \(customer): order placed")
    } catch {
        switch error {
        case .insufficientFunds(let balance, let needed):
            print("customer \(customer): needs \(needed), has \(balance)")
        case .unavailable(let underlying):
            print("customer \(customer): try again later [log: \(underlying)]")
        }
    }
}
```

```output
customer 1: order placed
customer 2: needs 1200, has 800
customer 3: try again later [log: corruptRecord(id: 3)]
customer 1: try again later [log: diskFull]
```

1. **`StorageError`** is infrastructure. Only the storage layer and `OrderService` know it exists.
2. **`OrderError`** is the domain's vocabulary. `insufficientFunds` is a business rule with the numbers the screen needs. `unavailable` says "the order system couldn't do its job right now", whatever the reason.
3. **`unavailable(underlying:)` keeps the original error.** The screen shows "try again later"; the log gets `corruptRecord(id: 3)`. Translating doesn't mean throwing information away.
4. `OrderService` depends on the `OrderStorage` **protocol**, injected (Module 10), so a fake storage can produce each failure on demand. That's how you test error paths, which otherwise only happen on bad days.
5. `placeOrder` uses typed throws: the screen gets a small, closed set to `switch` over. The storage protocol stays plain `throws`, since real storage could fail in ways nobody has listed yet.

`let balance: Int` declared before the `do` and assigned inside it is how you get a value out of a `do` block when the `catch` always throws: Swift checks that `balance` is assigned on every path that reaches the `guard`.

Not every error needs translating. If a layer would only wrap the error in a case that adds nothing, letting it propagate as plain `throws` is simpler. Translate when the layer above would otherwise depend on details it shouldn't know about.

## rethrows in higher-order functions

Module 11 had you write functions that take functions. When the function you're passed can throw, your function has to decide what happens. **`rethrows`** says: "I throw only if the closure I was given throws."

```swift
enum PriceError: Error {
    case negative(Int)
}

func applyToAll(_ prices: [Int], _ transform: (Int) throws -> Int) rethrows -> [Int] {
    var result: [Int] = []
    for price in prices {
        result.append(try transform(price))
    }
    return result
}

let doubled = applyToAll([100, 250]) { $0 * 2 }
print(doubled)

func checked(_ price: Int) throws -> Int {
    guard price >= 0 else {
        throw PriceError.negative(price)
    }
    return price
}

do {
    print(try applyToAll([100, 250], checked))
    print(try applyToAll([100, -5, 250], checked))
} catch {
    print("Rejected: \(error)")
}
```

```output
[200, 500]
[100, 250]
Rejected: negative(-5)
```

1. `transform` is `(Int) throws -> Int`: it **may** throw. `applyToAll` calls it with `try`.
2. `rethrows` in the signature means: if the closure can't throw, neither can `applyToAll`. The first call passes `{ $0 * 2 }`, which can't throw, so it needs **no `try`**.
3. The second and third calls pass `checked`, a throwing function, so they need `try`, and the error from `-5` propagates out.

The standard library's `map`, `filter`, `contains(where:)` and friends behave the same way, which is why you've been calling them without `try` all along, and why `try numbers.map(checked)` works too.

A `rethrows` function can't throw errors of its own:

```swift no-compile a function declared 'rethrows' may only throw if its parameter does
enum PriceError: Error {
    case empty
}

func applyToAll(_ prices: [Int], _ transform: (Int) throws -> Int) rethrows -> [Int] {
    guard !prices.isEmpty else {
        throw PriceError.empty
    }
    return try prices.map(transform)
}

print(applyToAll([1]) { $0 })
```

Swift 6.3: `error: a function declared 'rethrows' may only throw if its parameter does`. If the function has failures of its own, make it plain `throws`. Lesson 4's `throws(E)` generic helper is the typed alternative to `rethrows`: it passes the closure's exact error type through.

## Common mistakes

> [!error] Showing print(error) to the user
> `passwordTooShort(minimum: 8)` is for logs. Users get `localizedDescription` from a `LocalizedError` with a real sentence.

> [!error] error: cannot find type 'LocalizedError' in scope
> `LocalizedError` is in Foundation. Add `import Foundation` at the top of the file.

> [!error] Leaking infrastructure errors into the UI
> A screen that catches `URLError` or a database error type is tied to those libraries and tends to show messages like "Error 503". Translate at the boundary into domain errors, and keep the original attached for logs.

> [!error] Translating and losing the cause
> `catch { throw OrderError.unavailable }` with no associated value throws the diagnosis away. Attach the underlying error, or log it before you translate.

> [!error] error: a function declared 'rethrows' may only throw if its parameter does
> A `rethrows` function threw an error of its own. Make it `throws`, or move that check out.

````exercise
id: m12-l05-e1
type: comprehension
prompt: "Which of these is an infrastructure error rather than a domain error?"
choices:
  - text: "The seat the user picked was booked by someone else a moment ago."
    correct: false
    why: "A business rule of a booking system. It would exist on paper too."
  - text: "The gift card's balance is lower than the order total."
    correct: false
    why: "A rule of the payment domain, which the user can act on."
  - text: "The response from the server couldn't be decoded because a field was missing."
    correct: true
    why: "It's about how the app talks to its backend, not about what the user is trying to do."
  - text: "The promotion code expired yesterday."
    correct: false
    why: "A business rule with a clear meaning for the user."
solution: |
  **The decoding failure.** It's plumbing: the user can't fix a missing JSON field, and the screen shouldn't know JSON exists. The repository that decodes the response should translate it into something like `.unavailable(underlying: error)`. The other three are domain errors, with specific messages the user can act on.
````

````exercise
id: m12-l05-e2
type: find-errors
prompt: "This payment layer translates errors for the checkout screen. Which statements are true?"
code: |
  enum GatewayError: Error {
      case timeout
      case invalidResponse(statusCode: Int)
  }

  enum PaymentError: Error {
      case declined(reason: String)
      case unavailable
  }

  struct PaymentService {
      let gateway: any PaymentGateway

      func pay(cents: Int) throws(PaymentError) {
          do {
              try gateway.charge(cents: cents)
          } catch {
              throw .unavailable
          }
      }
  }

  // In the checkout screen:
  // catch GatewayError.timeout { showRetryButton() }
choices:
  - text: "The original gateway error is thrown away, so nobody can find out later whether it was a timeout or a 500."
    correct: true
    why: "unavailable has no associated value and nothing is logged. Attach the underlying error or log it."
  - text: "A card the bank declines also becomes unavailable, so the user is told to try later instead of using another card."
    correct: true
    why: "Every gateway error is mapped to the same case. A decline is a domain failure and deserves its own translation."
  - text: "The screen's catch GatewayError.timeout will never match, because pay only throws PaymentError."
    correct: true
    why: "The translation hides GatewayError from the screen. Retry logic should look at PaymentError, or live in the service."
  - text: "A function with throws(PaymentError) can't contain a do-catch."
    correct: false
    why: "It can. Every error that leaves it must be a PaymentError, which is what the catch ensures."
rubric:
  - I noticed the underlying error is lost.
  - I noticed declines are mapped to unavailable.
  - I noticed the screen still depends on GatewayError, which it can no longer see.
solution: |
  Three real problems, all about translating carelessly.

  1. **The cause is lost.** `throw .unavailable` drops the gateway error. Make it `unavailable(underlying: any Error)`, or log before translating.
  2. **Domain failures get flattened.** If the gateway reports a declined card, the user should hear "declined, try another card", not "try again later". Map the decline to `.declined(reason:)` and only plumbing failures to `.unavailable`.
  3. **The screen still talks infrastructure.** It catches `GatewayError.timeout`, which can't arrive anymore. The screen should switch over `PaymentError`; if retrying a timeout is worth doing, the service can do it, or expose it as a domain idea like `.unavailable(canRetry: true)`.

  A version with the first two fixed:

  ```swift
  enum GatewayError: Error {
      case timeout
      case cardDeclined(String)
  }

  protocol PaymentGateway {
      func charge(cents: Int) throws
  }

  enum PaymentError: Error {
      case declined(reason: String)
      case unavailable(underlying: any Error)
  }

  struct PaymentService {
      let gateway: any PaymentGateway

      func pay(cents: Int) throws(PaymentError) {
          do {
              try gateway.charge(cents: cents)
          } catch GatewayError.cardDeclined(let reason) {
              throw .declined(reason: reason)
          } catch {
              throw .unavailable(underlying: error)
          }
      }
  }

  struct FakeGateway: PaymentGateway {
      func charge(cents: Int) throws {
          if cents > 1000 { throw GatewayError.cardDeclined("limit") }
          if cents == 0 { throw GatewayError.timeout }
      }
  }

  let service = PaymentService(gateway: FakeGateway())
  for cents in [500, 5000, 0] {
      do {
          try service.pay(cents: cents)
          print("paid \(cents)")
      } catch {
          switch error {
          case .declined(let reason):
              print("declined: \(reason)")
          case .unavailable(let underlying):
              print("unavailable [log: \(underlying)]")
          }
      }
  }
  ```

  ```output
  paid 500
  declined: limit
  unavailable [log: timeout]
  ```
````

````exercise
id: m12-l05-e3
type: prediction
prompt: Predict the exact output.
code: |
  import Foundation

  enum TransferError: Error, LocalizedError {
      case insufficientFunds(missing: Int)
      case accountFrozen

      var errorDescription: String? {
          switch self {
          case .insufficientFunds(let missing):
              return "You need \(missing) more."
          case .accountFrozen:
              return nil
          }
      }
  }

  enum NetworkError: Error {
      case timeout
  }

  func transfer(_ step: Int) throws {
      switch step {
      case 1: throw TransferError.insufficientFunds(missing: 40)
      case 2: throw NetworkError.timeout
      default: throw TransferError.accountFrozen
      }
  }

  for step in 1...3 {
      do {
          try transfer(step)
      } catch let error as TransferError {
          print(error.errorDescription ?? "Contact support.")
      } catch {
          print("Log: \(error)")
      }
  }
output: |
  You need 40 more.
  Log: timeout
  Contact support.
hints:
  - "errorDescription is a String?, and ?? supplies a fallback."
  - "NetworkError isn't a TransferError."
solution: |
  ```output
  You need 40 more.
  Log: timeout
  Contact support.
  ```

  Step 1 matches `catch let error as TransferError` and has a description. Step 2 is a `NetworkError`, so it falls to the plain `catch` and is printed for the log. Step 3 is a `TransferError` whose `errorDescription` returns `nil`, so `??` supplies "Contact support.". The code reads `errorDescription` directly instead of `localizedDescription` so the fallback is under its control.
````

````exercise
id: m12-l05-e4
type: refactor
prompt: |
  `Percentage` uses `init?`, so callers can't tell "not a number" from "out of range". Rewrite it with a throwing initializer, typed with a `PercentageError` enum, and make the loop print the reason. Expected output:

  ```output
  45%
  "abc" is not a number
  140 is out of range
  ```
code: |
  struct Percentage {
      let value: Int

      init?(_ text: String) {
          guard let number = Int(text), number >= 0, number <= 100 else {
              return nil
          }
          value = number
      }
  }

  for text in ["45", "abc", "140"] {
      if let percentage = Percentage(text) {
          print("\(percentage.value)%")
      } else {
          print("invalid")
      }
  }
rubric:
  - PercentageError has cases for not a number and out of range, with the offending input.
  - The initializer is init(_:) throws(PercentageError) and keeps value a let.
  - The loop uses do-catch and switches over the error exhaustively.
  - The output matches exactly.
solution: |
  ```swift
  enum PercentageError: Error {
      case notANumber(String)
      case outOfRange(Int)
  }

  struct Percentage {
      let value: Int

      init(_ text: String) throws(PercentageError) {
          guard let number = Int(text) else {
              throw .notANumber(text)
          }
          guard number >= 0 && number <= 100 else {
              throw .outOfRange(number)
          }
          value = number
      }
  }

  func describe(_ text: String) -> String {
      do {
          let percentage = try Percentage(text)
          return "\(percentage.value)%"
      } catch {
          switch error {
          case .notANumber(let input):
              return "\"\(input)\" is not a number"
          case .outOfRange(let number):
              return "\(number) is out of range"
          }
      }
  }

  for text in ["45", "abc", "140"] {
      print(describe(text))
  }
  ```

  ```output
  45%
  "abc" is not a number
  140 is out of range
  ```

  The single `guard` with three conditions became two, one per reason, so each can throw its own case. The guarantee is unchanged: every `Percentage` holds 0 to 100. Moving the handling into a function that isn't `throws` lets the typed `switch` prove it's exhaustive.
````

````exercise
id: m12-l05-e5
type: solve
prompt: |
  Write a repository that translates storage errors into domain errors.

  - `enum DiskError: Error { case fileMissing(String), permissionDenied }` (infrastructure).
  - `protocol NoteStore { func read(_ name: String) throws -> String }`.
  - `struct FakeNoteStore: NoteStore` that throws `DiskError.fileMissing(name)` for `"lost.txt"`, `DiskError.permissionDenied` for `"secret.txt"`, and returns `"note: " + name` otherwise.
  - `enum NoteError: Error { case notFound(name: String), unavailable(underlying: any Error) }` (domain).
  - `struct NoteRepository` with `let store: any NoteStore` and `func note(named name: String) throws(NoteError) -> String` that maps `fileMissing` to `notFound(name:)` and any other error to `unavailable(underlying:)`.

  This must print:

  ```output
  note: todo.txt
  No note called lost.txt
  Can't open notes right now (permissionDenied)
  ```

  from a loop over `["todo.txt", "lost.txt", "secret.txt"]` that switches over `NoteError`.
starter: |
  enum DiskError: Error {
      case fileMissing(String)
      case permissionDenied
  }
hints:
  - "In note(named:), wrap the read in do { return try store.read(name) }."
  - "catch DiskError.fileMissing { throw .notFound(name: name) } and then a plain catch { throw .unavailable(underlying: error) }."
  - "Do the switch in a non-throwing function or inside the loop's catch."
rubric:
  - DiskError never reaches the loop; it only sees NoteError.
  - fileMissing becomes notFound; everything else becomes unavailable with the original attached.
  - The repository depends on the NoteStore protocol and receives the fake.
  - The output matches exactly.
solution: |
  ```swift
  enum DiskError: Error {
      case fileMissing(String)
      case permissionDenied
  }

  protocol NoteStore {
      func read(_ name: String) throws -> String
  }

  struct FakeNoteStore: NoteStore {
      func read(_ name: String) throws -> String {
          switch name {
          case "lost.txt": throw DiskError.fileMissing(name)
          case "secret.txt": throw DiskError.permissionDenied
          default: return "note: " + name
          }
      }
  }

  enum NoteError: Error {
      case notFound(name: String)
      case unavailable(underlying: any Error)
  }

  struct NoteRepository {
      let store: any NoteStore

      func note(named name: String) throws(NoteError) -> String {
          do {
              return try store.read(name)
          } catch DiskError.fileMissing {
              throw .notFound(name: name)
          } catch {
              throw .unavailable(underlying: error)
          }
      }
  }

  let repository = NoteRepository(store: FakeNoteStore())
  for name in ["todo.txt", "lost.txt", "secret.txt"] {
      do {
          print(try repository.note(named: name))
      } catch {
          switch error {
          case .notFound(let missing):
              print("No note called \(missing)")
          case .unavailable(let underlying):
              print("Can't open notes right now (\(underlying))")
          }
      }
  }
  ```

  ```output
  note: todo.txt
  No note called lost.txt
  Can't open notes right now (permissionDenied)
  ```

  Inside a function typed `throws(NoteError)`, every catch clause either returns or throws a `NoteError`, which is exactly what the compiler checks. "File missing" has a domain meaning (there's no such note), so it gets its own case. "Permission denied" doesn't mean anything to the user, so it becomes `unavailable`, with the original attached for the log. In a real screen you'd show only "Can't open notes right now" and send the underlying error to the log.
````

````exercise
id: m12-l05-e6
type: solve
prompt: |
  Write `func firstIndex(in values: [Int], where predicate: (Int) throws -> Bool) rethrows -> Int?` that returns the index of the first value for which `predicate` returns `true`, or `nil`.

  Then show both kinds of call: one with a non-throwing closure (no `try`), and one with a throwing function `isLargeOrder(_:)` that throws `OrderCheckError.negative(value)` for negative values. Expected output:

  ```output
  Optional(2)
  Found at 1
  Rejected: negative(-3)
  ```

  from:

  ```swift
  print(firstIndex(in: [3, 8, 12, 5], where: { $0 > 10 }) as Any)
  do {
      if let index = try firstIndex(in: [50, 200, 30], where: isLargeOrder) {
          print("Found at \(index)")
      }
      _ = try firstIndex(in: [50, -3, 300], where: isLargeOrder)
  } catch {
      print("Rejected: \(error)")
  }
  ```

  `isLargeOrder` returns `true` for values over 100.
starter: |
  enum OrderCheckError: Error {
      case negative(Int)
  }
hints:
  - "Loop with for (index, value) in values.enumerated()."
  - "if try predicate(value) { return index }"
  - "isLargeOrder: guard value >= 0 else { throw … }; return value > 100"
rubric:
  - The function is marked rethrows and calls predicate with try.
  - The non-throwing call has no try.
  - The throwing call propagates negative(-3).
  - The output matches exactly.
solution: |
  ```swift
  enum OrderCheckError: Error {
      case negative(Int)
  }

  func firstIndex(in values: [Int], where predicate: (Int) throws -> Bool) rethrows -> Int? {
      for (index, value) in values.enumerated() {
          if try predicate(value) {
              return index
          }
      }
      return nil
  }

  func isLargeOrder(_ value: Int) throws -> Bool {
      guard value >= 0 else {
          throw OrderCheckError.negative(value)
      }
      return value > 100
  }

  print(firstIndex(in: [3, 8, 12, 5], where: { $0 > 10 }) as Any)
  do {
      if let index = try firstIndex(in: [50, 200, 30], where: isLargeOrder) {
          print("Found at \(index)")
      }
      _ = try firstIndex(in: [50, -3, 300], where: isLargeOrder)
  } catch {
      print("Rejected: \(error)")
  }
  ```

  ```output
  Optional(2)
  Found at 1
  Rejected: negative(-3)
  ```

  `rethrows` lets the first call skip `try`, because `{ $0 > 10 }` can't throw. The third call stops at `-3`: `isLargeOrder` throws, `firstIndex` doesn't catch, and the error propagates. 300 is never checked. That's the same contract as the standard library's `firstIndex(where:)`.
````

## Summary

- Conform errors users will see to `LocalizedError` (Foundation) and implement `errorDescription`. Show `localizedDescription` to users; log `print(error)` for developers.
- For forms, collect every problem and throw one error that holds them all, so the user fixes everything in one pass.
- `init() throws` guarantees valid instances and tells the caller which rule failed. Use `init?` when one reason is enough.
- Domain errors are business rules the user can understand. Infrastructure errors are plumbing. Translate infrastructure errors into domain errors at the layer boundary, and keep the original attached or logged.
- Inject storage and network dependencies behind protocols so fakes can trigger each error path.
- `rethrows` marks a higher-order function that throws only when its closure does; with a non-throwing closure, no `try` is needed. It can't throw errors of its own.
