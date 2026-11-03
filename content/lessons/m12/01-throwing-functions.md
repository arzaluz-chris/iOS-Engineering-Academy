---
id: m12-l01
title: Errors and throwing functions
description: You decide when a function should throw instead of returning nil or a default, model failures as an enum that conforms to Error, write throwing functions with throws and throw, mark calls with try, and follow an error as it propagates up through several functions.
module: m12
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l06]
objectives:
  - Choose between returning an optional, returning a default and throwing an error, and justify the choice.
  - Define an error type as an enum that conforms to Error, with associated values for the details.
  - Write a throwing function with throws and throw.
  - Call a throwing function with try and explain what try marks.
  - Trace how an error propagates through functions that are themselves marked throws.
  - Explain what happens when an error escapes top-level code.
terms:
  - term: Error
    definition: "The standard library protocol for values that describe a failure. It has no requirements: any enum, struct or class can conform. Only Error values can be thrown."
  - term: Throwing function
    definition: "A function marked throws. Besides returning normally, it can exit by throwing an error, and the caller has to deal with that possibility."
  - term: throw
    definition: "The statement that ends the current function immediately and hands an error to the caller, like return hands back a value."
  - term: try
    definition: "The marker you write in front of a call that can throw. It doesn't handle anything by itself; it shows the reader where control might leave."
  - term: Propagation
    definition: "Letting an error pass up to your own caller: a throws function that calls another with try and doesn't catch the error rethrows it automatically."
mastery:
  - "Given a function's failure cases, say whether it should return an optional, a default or throw, with a one-line reason."
  - Write an error enum whose cases carry the data each failure needs.
  - "Write a throws function that uses guard and throw to reject bad input."
  - "Fix \"call can throw but is not marked with 'try'\" and \"errors thrown from here are not handled\"."
  - Predict which lines run when an error is thrown three calls deep.
resources: [swift-book-error-handling, swift-book-functions, swift-optional, swift-book-enumerations]
cards:
  - id: m12-l01-c1
    front: "When should a function throw instead of returning nil?"
    back: "When the caller needs to know why it failed, because there are several reasons that need different handling. If nil has one obvious meaning, an optional is enough."
  - id: m12-l01-c2
    front: What does a type need to be thrown?
    back: "It must conform to Error. The protocol has no requirements, so `enum ParseError: Error { case empty }` is enough."
  - id: m12-l01-c3
    front: "What does `try` do?"
    back: "It marks a call that can throw, so a reader sees where control might leave. It handles nothing: the error still goes to a catch or up to the caller."
  - id: m12-l01-c4
    front: What happens to an error thrown inside a throws function that doesn't catch it?
    back: "It propagates: the function stops at that line and the same error goes to its caller, and so on, until something catches it."
  - id: m12-l01-c5
    front: "What happens if an error escapes top-level code in main.swift?"
    back: "The program stops with \"Fatal error: Error raised at top level:\" followed by the error. Top-level code may use try without do, but nothing is there to catch."
---

## The idea in one sentence

A function that can fail in several meaningful ways says so with `throws`, reports the specific failure with `throw`, and every caller marks the call with `try` and decides what to do about it.

## nil, a default, or an error?

Module 8 gave you three options for a function that can come up empty, and promised the third one for this module. Here's the recap with the third option filled in.

- **Return an optional** when "no result" is ordinary and has **one** obvious meaning. `Int("abc")` returns `nil`; there's nothing more to say than "not a number".
- **Return a plain value** when there's a genuinely correct answer for the empty case: the total of an empty cart is 0.
- **Throw an error** when the caller needs to know **why**, because different reasons need different handling.

Logging in is the example from Module 8. A wrong password should show "try again", a locked account should show when it unlocks, and no network should offer to retry. An optional collapses all three into one `nil`. The caller can't tell them apart, so the app can't react correctly to any of them.

The test from Module 8 still works: finish the sentence "returns nil if…". If you need "or" twice, you probably want an error.

## The Error protocol

Swift throws values, and those values must conform to the **`Error`** protocol. `Error` has no requirements. Conforming is just a declaration that "this type describes a failure".

An enum is the usual shape, because the set of things that can go wrong is usually a fixed list:

```swift
enum PasswordError: Error {
    case tooShort(minimum: Int)
    case missingDigit
    case containsUsername
}

let problem = PasswordError.tooShort(minimum: 8)
print(problem)
```

```output
tooShort(minimum: 8)
```

1. `: Error` makes `PasswordError` throwable. Without it, Swift won't let you `throw` it.
2. Each case is one way the operation fails. `tooShort` carries an **associated value** (Module 9) because the caller needs the number to show a useful message.
3. Printing an enum error shows its case and associated values, which is handy while you develop.

A struct works too, when every failure has the same fields:

```swift
struct FieldError: Error {
    let field: String
    let reason: String
}

print(FieldError(field: "email", reason: "missing @"))
```

```output
FieldError(field: "email", reason: "missing @")
```

Start with an enum. Reach for a struct when the cases would all carry the same data anyway.

## throws and throw

A function that can fail with an error says so with **`throws`**, written after the parameters and before the return arrow. Inside, **`throw`** reports a failure:

```swift
enum QuantityError: Error {
    case empty
    case notANumber(String)
    case outOfRange(Int)
}

func parseQuantity(_ text: String) throws -> Int {
    guard !text.isEmpty else {
        throw QuantityError.empty
    }
    guard let number = Int(text) else {
        throw QuantityError.notANumber(text)
    }
    guard number >= 1 && number <= 99 else {
        throw QuantityError.outOfRange(number)
    }
    return number
}

do {
    let quantity = try parseQuantity("12")
    print("Quantity: \(quantity)")
    let other = try parseQuantity("120")
    print("Quantity: \(other)")
} catch {
    print("Failed with \(error)")
}
```

```output
Quantity: 12
Failed with outOfRange(120)
```

Line by line:

1. `throws -> Int` says: this function either returns an `Int` or throws an error. Both are normal ways to leave it.
2. Each `guard` checks one rule. `throw QuantityError.empty` ends the function right there, like `return` would, but hands the caller an error instead of a value. No `Int` comes back.
3. `notANumber(text)` and `outOfRange(number)` carry the offending input, so the caller can say exactly what was wrong.
4. At the bottom, `try parseQuantity("12")` succeeds and returns 12. `try parseQuantity("120")` throws, so the next `print` **never runs**. Control jumps straight to `catch`, where the thrown value is available as `error`.

You'll study `do`/`catch` properly in the next lesson. For now read it as "run this; if something throws, go to `catch`".

`guard … else { throw … }` is the shape you'll write most. It's the `guard … else { return nil }` you know from Module 8, with a reason attached.

## try marks the call

Every call to a throwing function must be written with **`try`** in front:

```swift no-compile call can throw but is not marked with 'try'
enum QuantityError: Error {
    case empty
}

func parseQuantity(_ text: String) throws -> Int {
    guard !text.isEmpty else {
        throw QuantityError.empty
    }
    return 1
}

let quantity = parseQuantity("3")
print(quantity)
```

Swift 6.3 says `error: call can throw but is not marked with 'try'`. `try` doesn't catch anything. It's a marker for the reader: "control might leave here". In a long function, the `try`s are the exits you can't see otherwise.

One `try` covers everything to its right in the expression:

```swift
enum PriceError: Error {
    case unknown(String)
}

func price(of item: String) throws -> Int {
    switch item {
    case "espresso": return 220
    case "croissant": return 180
    default: throw PriceError.unknown(item)
    }
}

do {
    let total = try price(of: "espresso") + price(of: "croissant")
    print(total)
} catch {
    print(error)
}
```

```output
400
```

But it must come first. `let total = 2 * try price(of: "espresso")` fails with `error: 'try' cannot appear to the right of a non-assignment operator`. Put `try` at the start of the expression.

## Propagation

A throwing function can call another throwing function with `try` and **not** handle the error. If the inner call throws, the outer function stops at that line and the same error continues up to **its** caller. That's **propagation**:

```swift
enum OrderError: Error {
    case badFormat(String)
    case badQuantity(String)
}

func parseQuantity(_ text: String) throws -> Int {
    guard let number = Int(text), number > 0 else {
        throw OrderError.badQuantity(text)
    }
    return number
}

func parseLine(_ line: String) throws -> (quantity: Int, item: String) {
    let parts = line.split(separator: " x ")
    guard parts.count == 2 else {
        throw OrderError.badFormat(line)
    }
    print("Parsing quantity of \(parts[1])")
    let quantity = try parseQuantity(String(parts[0]))
    print("Quantity OK")
    return (quantity, String(parts[1]))
}

func readOrder(_ lines: [String]) throws -> Int {
    var count = 0
    for line in lines {
        let entry = try parseLine(line)
        count += entry.quantity
    }
    return count
}

do {
    print(try readOrder(["2 x espresso", "1 x muffin"]))
    print(try readOrder(["2 x espresso", "two x tea", "1 x muffin"]))
} catch {
    print("Order rejected: \(error)")
}
```

```output
Parsing quantity of espresso
Quantity OK
Parsing quantity of muffin
Quantity OK
3
Parsing quantity of espresso
Quantity OK
Parsing quantity of tea
Order rejected: badQuantity("two")
```

Follow the second order. `parseQuantity("two")` throws. `parseLine` called it with `try` and has no `catch`, so it stops on that line: "Quantity OK" isn't printed for tea. `readOrder` called `parseLine` with `try`, so it stops too: the loop never reaches the muffin. The error arrives, unchanged, at the `catch` at the bottom.

This is why `throws` is part of a function's type. `parseLine` and `readOrder` don't mention `OrderError` anywhere in their bodies, but they're marked `throws` because something they call can throw and they let it through.

A function that isn't marked `throws` can't let an error through. It has to handle it:

```swift no-compile errors thrown from here are not handled
enum OrderError: Error {
    case badQuantity(String)
}

func parseQuantity(_ text: String) throws -> Int {
    guard let number = Int(text) else {
        throw OrderError.badQuantity(text)
    }
    return number
}

func doubled(_ text: String) -> Int {
    try parseQuantity(text) * 2
}

print(doubled("4"))
```

Swift 6.3: `error: errors thrown from here are not handled`. Two fixes: mark `doubled` as `throws` (propagate), or handle the error inside with `do`/`catch` (next lesson). Which one is right depends on whether `doubled` knows what to do about a bad quantity. Usually it doesn't, and propagating is the honest answer.

> [!tip] Throwing initializers
> Initializers can throw too: `init(_ text: String) throws`. Module 9 promised this for when an `init?` that returns `nil` says too little. You'll write them in lesson 5.

## Top-level code and try

In a `main.swift` file, the code at the top level is allowed to use `try` without `do`/`catch`. That compiles, but nothing catches the error. If it throws, the program stops:

```swift runtime-error Error raised at top level
enum QuantityError: Error {
    case notANumber(String)
}

func parseQuantity(_ text: String) throws -> Int {
    guard let number = Int(text) else {
        throw QuantityError.notANumber(text)
    }
    return number
}

print(try parseQuantity("3"))
print(try parseQuantity("three"))
print("Done")
```

```output
3
```

Swift 6.3 reports `Fatal error: Error raised at top level:` followed by the error with its module name in front (something like `MyApp.QuantityError.notANumber("three")`), and the program crashes. "Done" never prints. It's fine for quick experiments, but in an app nothing runs at the top level like this. Real code handles errors on purpose.

## A practical example: a password rule checker

A signup form needs to tell the user exactly which rule their password breaks. That's several reasons with different messages: a job for an error enum.

```swift
enum PasswordError: Error {
    case tooShort(minimum: Int)
    case missingDigit
    case containsUsername
}

func validatePassword(_ password: String, username: String) throws {
    let minimum = 8
    guard password.count >= minimum else {
        throw PasswordError.tooShort(minimum: minimum)
    }
    guard password.contains(where: { $0.isNumber }) else {
        throw PasswordError.missingDigit
    }
    guard !password.lowercased().contains(username.lowercased()) else {
        throw PasswordError.containsUsername
    }
}

func message(for password: String, username: String) -> String {
    do {
        try validatePassword(password, username: username)
        return "OK"
    } catch PasswordError.tooShort(let minimum) {
        return "Use at least \(minimum) characters."
    } catch PasswordError.missingDigit {
        return "Add at least one digit."
    } catch PasswordError.containsUsername {
        return "Don't include your username."
    } catch {
        return "Something unexpected went wrong."
    }
}

print(message(for: "cat", username: "ana"))
print(message(for: "longpassword", username: "ana"))
print(message(for: "ana-1234567", username: "Ana"))
print(message(for: "blue-river-42", username: "ana"))
```

```output
Use at least 8 characters.
Add at least one digit.
Don't include your username.
OK
```

`validatePassword` returns nothing (`Void`); its whole job is to throw or not. The rules run in order and the first broken one wins. The `catch` clauses that match specific cases are a preview of lesson 2. The point here is that `message(for:username:)` **can** react differently to each failure, which a `Bool` or an optional would never allow.

## Common mistakes

> [!error] error: call can throw but is not marked with 'try'
> You called a `throws` function without `try`. Add `try`, and then make sure something handles the error: an enclosing `throws` function or a `do`/`catch`.

> [!error] error: errors thrown from here are not handled
> You wrote `try` inside a function that isn't `throws` and isn't inside a `do`/`catch` that handles everything. Either add `throws` to the function so the error propagates, or catch it.

> [!error] error: thrown expression type 'String' does not conform to 'Error'
> `throw "Invalid quantity"` doesn't work: only `Error` values can be thrown. Define an error type and throw one of its cases.

> [!error] error: 'try' cannot appear to the right of a non-assignment operator
> `let total = 2 * try price(of: item)` puts `try` in the middle. Write `let total = try 2 * price(of: item)`; one `try` covers the whole expression.

> [!error] Throwing when nil says everything
> A `throws` function with a single error case `notFound` is an optional in disguise, and harder to use. If there's one obvious reason, return `nil`. Throw when the caller needs to tell reasons apart.

````exercise
id: m12-l01-e1
type: comprehension
prompt: "Which function should throw an error instead of returning an optional or a default?"
choices:
  - text: "`func firstVowel(in text: String) -> Character?`, which finds the first vowel in some text."
    correct: false
    why: "No vowel has one obvious meaning. An optional says it fully."
  - text: "`func unreadCount(in inbox: [Message]) -> Int`, which counts unread messages."
    correct: false
    why: "0 is the correct answer for an inbox with nothing unread. A plain value fits."
  - text: "`func transfer(amount: Int, from: Account, to: Account)`, which can fail because of insufficient funds, a frozen account or a daily limit."
    correct: true
    why: "Three reasons, each needing a different reaction from the app. That's what errors are for."
  - text: "`func price(of item: String) -> Int?`, which looks up an item on a menu."
    correct: false
    why: "Not on the menu is the only way a lookup can fail. nil says it."
solution: |
  **`transfer`.** It fails for three different reasons, and the app has to react differently to each: offer a top-up, tell the user to contact the bank, or show when the limit resets. An optional or a `Bool` can only say "it didn't work". The other three have either one obvious reason for "no result" (optional) or a correct value for the empty case (0).
````

````exercise
id: m12-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum StockError: Error {
      case soldOut(String)
  }

  func reserve(_ item: String, available: Int) throws -> Int {
      print("Checking \(item)")
      guard available > 0 else {
          throw StockError.soldOut(item)
      }
      print("Reserved \(item)")
      return available - 1
  }

  func reserveAll() throws {
      let left = try reserve("bagel", available: 3)
      print("Bagels left: \(left)")
      _ = try reserve("scone", available: 0)
      print("All reserved")
  }

  do {
      try reserveAll()
  } catch {
      print("Error: \(error)")
  }
output: |
  Checking bagel
  Reserved bagel
  Bagels left: 2
  Checking scone
  Error: soldOut("scone")
hints:
  - "throw ends reserve immediately. Which print comes after it?"
  - "reserveAll calls reserve with try and has no catch. What happens to it when the scone reservation throws?"
solution: |
  ```output
  Checking bagel
  Reserved bagel
  Bagels left: 2
  Checking scone
  Error: soldOut("scone")
  ```

  The bagel goes through normally. For the scone, `reserve` prints "Checking scone", then the `guard` fails and `throw` ends it, so "Reserved scone" never prints. `reserveAll` called it with `try` and doesn't catch, so it stops too: "All reserved" never prints. The error propagates to the `catch`, which prints the case with its associated value.
````

````exercise
id: m12-l01-e3
type: fill-in
prompt: |
  Complete the code so `parseAge` rejects text that isn't a number and ages over 130, and the program prints `outOfRange(200)`.
code: |
  enum AgeError: [[1]] {
      case notANumber
      case outOfRange(Int)
  }

  func parseAge(_ text: String) [[2]] -> Int {
      guard let age = Int(text) else {
          [[3]] AgeError.notANumber
      }
      guard age <= 130 else {
          throw AgeError.outOfRange(age)
      }
      return age
  }

  do {
      print([[4]] parseAge("200"))
  } catch {
      print(error)
  }
blanks:
  - id: "1"
    answers: ["Error"]
  - id: "2"
    answers: ["throws"]
  - id: "3"
    answers: ["throw"]
  - id: "4"
    answers: ["try"]
solution: |
  ```swift
  enum AgeError: Error {
      case notANumber
      case outOfRange(Int)
  }

  func parseAge(_ text: String) throws -> Int {
      guard let age = Int(text) else {
          throw AgeError.notANumber
      }
      guard age <= 130 else {
          throw AgeError.outOfRange(age)
      }
      return age
  }

  do {
      print(try parseAge("200"))
  } catch {
      print(error)
  }
  ```

  ```output
  outOfRange(200)
  ```

  `Error` makes the enum throwable, `throws` declares that the function can fail, `throw` reports the failure, and `try` marks the call. "200" is a number, so the first guard passes; it's over 130, so the second throws `outOfRange(200)` and `print(try …)` never prints a value.
````

````exercise
id: m12-l01-e4
type: find-errors
prompt: "This code should load a user's display name. Which statements are true?"
code: |
  enum ProfileError: Error {
      case missing
      case banned(reason: String)
  }

  func loadName(id: Int) throws -> String {
      guard id > 0 else {
          throw "Invalid id"
      }
      guard id != 13 else {
          throw ProfileError.banned(reason: "spam")
      }
      return "User \(id)"
  }

  func header(id: Int) -> String {
      let name = try loadName(id: id)
      return "Hello, \(name)"
  }
choices:
  - text: "`throw \"Invalid id\"` doesn't compile, because String doesn't conform to Error."
    correct: true
    why: "Only Error values can be thrown. Add a case such as invalidID to ProfileError."
  - text: "`header` doesn't compile: it uses try but isn't marked throws and doesn't catch."
    correct: true
    why: "Swift reports \"errors thrown from here are not handled\". Mark header throws or handle the error."
  - text: "`loadName` must return an optional because it can fail."
    correct: false
    why: "A throwing function returns a plain String when it succeeds. Failure goes through throw."
  - text: "The `missing` case can't exist because it's never thrown."
    correct: false
    why: "Unused cases compile fine. It's a design question, not an error."
  - text: "`banned(reason:)` is invalid because error cases can't have associated values."
    correct: false
    why: "Associated values on error cases are normal and useful."
rubric:
  - I found the String being thrown.
  - I found the unhandled try in header.
  - I proposed fixes for both.
solution: |
  Two real problems. `throw "Invalid id"` fails with "thrown expression type 'String' does not conform to 'Error'". And `header` uses `try` without being `throws` or catching, which fails with "errors thrown from here are not handled". Here `header` can't do anything useful about a bad id, so propagating is the right fix:

  ```swift
  enum ProfileError: Error {
      case invalidID
      case missing
      case banned(reason: String)
  }

  func loadName(id: Int) throws -> String {
      guard id > 0 else {
          throw ProfileError.invalidID
      }
      guard id != 13 else {
          throw ProfileError.banned(reason: "spam")
      }
      return "User \(id)"
  }

  func header(id: Int) throws -> String {
      let name = try loadName(id: id)
      return "Hello, \(name)"
  }

  do {
      print(try header(id: 7))
      print(try header(id: 13))
  } catch {
      print(error)
  }
  ```

  ```output
  Hello, User 7
  banned(reason: "spam")
  ```
````

````exercise
id: m12-l01-e5
type: solve
prompt: |
  Write a throwing function that validates a username for a signup form.

  - `enum UsernameError: Error` with cases `tooShort(minimum: Int)`, `tooLong(maximum: Int)` and `invalidCharacter(Character)`.
  - `func validateUsername(_ name: String) throws -> String` that checks, in this order: at least 3 characters, at most 12, and only letters, digits or `_`. It returns the name lowercased when it's valid. Use `character.isLetter` and `character.isNumber`.

  This program must print the output below:

  ```swift
  for candidate in ["Ana_92", "al", "a_very_long_name", "ana!"] {
      do {
          print(try validateUsername(candidate))
      } catch {
          print(error)
      }
  }
  ```

  ```output
  ana_92
  tooShort(minimum: 3)
  tooLong(maximum: 12)
  invalidCharacter("!")
  ```
starter: |
  enum UsernameError: Error {
      // your cases
  }

  func validateUsername(_ name: String) throws -> String {
      // your code
  }
hints:
  - "Two guards with throw for the length checks."
  - "Loop over the characters; throw invalidCharacter(character) on the first one that isn't a letter, a number or \"_\"."
  - "After the loop, return name.lowercased()."
rubric:
  - The error enum has the three cases with associated values.
  - The checks run in the specified order and each throws the right case.
  - The function returns the lowercased name on success.
  - The output matches exactly.
solution: |
  ```swift
  enum UsernameError: Error {
      case tooShort(minimum: Int)
      case tooLong(maximum: Int)
      case invalidCharacter(Character)
  }

  func validateUsername(_ name: String) throws -> String {
      guard name.count >= 3 else {
          throw UsernameError.tooShort(minimum: 3)
      }
      guard name.count <= 12 else {
          throw UsernameError.tooLong(maximum: 12)
      }
      for character in name {
          guard character.isLetter || character.isNumber || character == "_" else {
              throw UsernameError.invalidCharacter(character)
          }
      }
      return name.lowercased()
  }

  for candidate in ["Ana_92", "al", "a_very_long_name", "ana!"] {
      do {
          print(try validateUsername(candidate))
      } catch {
          print(error)
      }
  }
  ```

  ```output
  ana_92
  tooShort(minimum: 3)
  tooLong(maximum: 12)
  invalidCharacter("!")
  ```

  Each rule is a `guard … else { throw … }`, so the happy path reads straight down. The character check throws on the **first** bad character and carries it, so the form can say "! isn't allowed". `"a_very_long_name"` has 16 characters, so the length check catches it before the character loop runs.
````

````exercise
id: m12-l01-e6
type: design
prompt: |
  You're writing `func bookTable(for people: Int, at hour: Int) …` for a restaurant app. A booking can fail because the party is larger than 8, because the restaurant is closed at that hour (open 12 to 23), or because no table is free. The app shows a different message for each, and for "no table free" it suggests the next free hour. Write the error type and the function's signature, and explain why an optional return would be the wrong choice.
rubric:
  - Defines an enum conforming to Error with one case per failure.
  - The "no table" case carries the suggested hour as an associated value.
  - The function is marked throws and returns the booking (or a confirmation) on success.
  - Explains that an optional can't tell the three failures apart.
solution: |
  ```swift
  enum BookingError: Error {
      case partyTooLarge(maximum: Int)
      case closed(opens: Int, closes: Int)
      case noTableFree(nextFreeHour: Int)
  }

  struct Booking {
      let people: Int
      let hour: Int
  }

  func bookTable(for people: Int, at hour: Int) throws -> Booking {
      guard people <= 8 else {
          throw BookingError.partyTooLarge(maximum: 8)
      }
      guard hour >= 12 && hour <= 23 else {
          throw BookingError.closed(opens: 12, closes: 23)
      }
      guard hour != 21 else {
          throw BookingError.noTableFree(nextFreeHour: 22)
      }
      return Booking(people: people, hour: hour)
  }

  do {
      let booking = try bookTable(for: 4, at: 20)
      print("Booked for \(booking.people) at \(booking.hour)")
      _ = try bookTable(for: 2, at: 21)
  } catch {
      print(error)
  }
  ```

  ```output
  Booked for 4 at 20
  noTableFree(nextFreeHour: 22)
  ```

  Each case carries what the app needs to build its message: the maximum party size, the opening hours, the next free hour. A `Booking?` would return `nil` for all three, and the app couldn't suggest 22:00 because it wouldn't even know that was the problem. (The "hour 21 is full" rule stands in for a real availability check.)
````

## Summary

- Return an optional when failure has one obvious meaning, a plain value when the empty case has a correct answer, and **throw** when the caller needs to know why.
- Errors are values of types that conform to `Error`, a protocol with no requirements. An enum with associated values is the usual shape.
- `throws` in the signature says a function can fail. `throw` ends it immediately and hands an error to the caller.
- Every call to a throwing function needs `try`. It marks the exit; it doesn't handle anything. One `try` at the start covers the whole expression.
- An error propagates through every `throws` function that calls with `try` and doesn't catch. A function that isn't `throws` must handle it.
- Top-level code may use `try` without `do`; if an error escapes, the program crashes with "Error raised at top level".
