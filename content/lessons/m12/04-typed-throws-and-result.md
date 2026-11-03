---
id: m12-l04
title: Typed throws and Result
description: You declare exactly which error a function throws with throws(ErrorType), handle it exhaustively without a catch-all, decide when typed throws helps and when plain throws is the better contract, and store or pass around outcomes with Result, converting between Result and throwing code.
module: m12
order: 4
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l03]
objectives:
  - Declare a function with typed throws and throw cases with the shorthand .case syntax.
  - Handle a typed error exhaustively with a switch inside a catch, without a catch-all.
  - Explain what throws(any Error) and throws(Never) mean.
  - Write a generic function that passes through whatever error its closure throws.
  - Choose between typed and untyped throws for a given API, with a reason.
  - Create, switch on and transform a Result, and convert between Result and throwing code.
terms:
  - term: Typed throws
    definition: "A throws clause that names the error type, like throws(ParseError). The function can throw only that type, and callers know it statically. Added in Swift 6.0 (SE-0413)."
  - term: Untyped throws
    definition: "Plain throws, which is the same as throws(any Error): the function can throw any error, and callers see it as any Error."
  - term: "throws(Never)"
    definition: "A throws clause that can't throw anything, because Never has no values. It means the same as not throwing; calls need no try."
  - term: Result
    definition: "A standard library enum, Result<Success, Failure: Error>, with cases success(Success) and failure(Failure). It stores the outcome of an operation as a value."
mastery:
  - "Convert a throws function with one error enum to throws(ThatEnum) and remove the caller's catch-all."
  - "Fix \"thrown expression type 'X' cannot be converted to error type 'Y'\" by translating the error."
  - Write a generic helper whose closure parameter can throw any typed error, and call it with a non-throwing closure without try.
  - Argue for plain throws on an API whose failures may grow.
  - Turn a throwing call into a Result and back with Result(catching:), do-catch and get().
resources: [swift-result, swift-book-error-handling, swift-book-generics, swift-book-closures, swift-book-enumerations]
cards:
  - id: m12-l04-c1
    front: "What does `func parse(_ s: String) throws(ParseError) -> Int` promise?"
    back: "That it either returns an Int or throws a ParseError, never any other error. Inside a catch for it, error has type ParseError."
  - id: m12-l04-c2
    front: How do you handle a typed error exhaustively without a catch-all?
    back: "One plain catch with a switch on error over every case. In Swift 6.3, separate catch clauses per case don't count as exhaustive."
  - id: m12-l04-c3
    front: "What are throws(any Error) and throws(Never)?"
    back: "throws(any Error) is plain throws. throws(Never) can't throw, so it's the same as a non-throwing function."
  - id: m12-l04-c4
    front: When is plain (untyped) throws the better choice?
    back: "For public or evolving APIs, and when a function calls code with other error types. A typed error is a promise: adding a new kind of failure later breaks callers that switch over it."
  - id: m12-l04-c5
    front: "How do you go from a throwing call to a Result and back?"
    back: "Result { try work() } (or do/catch returning .success and .failure) wraps it; result.get() unwraps it, returning the value or throwing the failure."
---

## The idea in one sentence

`throws(ParseError)` tells callers exactly which error to expect, so the compiler can check that they handled every case, and `Result` lets you hold a success or a failure as a value.

## A catch-all that never runs

Here's a parser with one error enum and a caller that handles every case:

```swift
enum ParseError: Error {
    case empty
    case notANumber(String)
}

func parseQuantity(_ text: String) throws -> Int {
    guard !text.isEmpty else {
        throw ParseError.empty
    }
    guard let number = Int(text) else {
        throw ParseError.notANumber(text)
    }
    return number
}

func describe(_ text: String) -> String {
    do {
        return "Quantity \(try parseQuantity(text))"
    } catch ParseError.empty {
        return "Enter a quantity"
    } catch ParseError.notANumber(let input) {
        return "\(input) isn't a number"
    } catch {
        return "Impossible?"
    }
}

print(describe("3"))
print(describe(""))
print(describe("lots"))
```

```output
Quantity 3
Enter a quantity
lots isn't a number
```

The last `catch` **never runs**, yet you had to write it. `parseQuantity` is declared plain `throws`, which means it could throw anything, so a non-throwing caller must have a catch-all. You write a branch you know is dead, and if someone later adds a third case to `ParseError`, the compiler won't tell you: the new case silently lands in "Impossible?".

## throws(ErrorType)

**Typed throws**, added in Swift 6.0 (proposal SE-0413), lets you name the error type in the signature:

```swift
enum ParseError: Error {
    case empty
    case notANumber(String)
}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard !text.isEmpty else {
        throw .empty
    }
    guard let number = Int(text) else {
        throw .notANumber(text)
    }
    return number
}

func describe(_ text: String) -> String {
    do {
        return "Quantity \(try parseQuantity(text))"
    } catch {
        switch error {
        case .empty:
            return "Enter a quantity"
        case .notANumber(let input):
            return "\(input) isn't a number"
        }
    }
}

print(describe("3"))
print(describe(""))
print(describe("lots"))
```

```output
Quantity 3
Enter a quantity
lots isn't a number
```

Line by line:

1. `throws(ParseError)` says this function throws **only** `ParseError`. It's part of the function's type, like the return type.
2. Because the type is known, `throw .empty` works without the `ParseError.` prefix, the same shorthand as in a `switch`.
3. In `describe`, everything in the `do` block throws `ParseError`, so the plain `catch` gets `error` **typed as `ParseError`**, not `any Error`.
4. The `switch` covers every case and needs no `default`. No catch-all, no dead branch. Add a third case to `ParseError` and this `switch` stops compiling until you handle it, which is exactly the check you want.

> [!warning] Separate catch clauses aren't exhaustive
> You might expect `catch .empty { } catch .notANumber { }` to count as handling everything. In Swift 6.3 it doesn't: the compiler still reports "errors thrown from here are not handled because the enclosing catch is not exhaustive". Use a single `catch` with a `switch` inside, as above.

### The compiler checks what you throw

A typed function can only throw its type:

```swift no-compile cannot be converted to error type 'ParseError'
enum ParseError: Error {
    case empty
}

struct NetworkError: Error {}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard !text.isEmpty else {
        throw NetworkError()
    }
    return 1
}

print(try parseQuantity("1"))
```

Swift 6.3: `error: thrown expression type 'NetworkError' cannot be converted to error type 'ParseError'`. The same happens when a typed function calls an untyped one with `try`: the call could throw `any Error`, and Swift reports `thrown expression type 'any Error' cannot be converted to error type 'ParseError'`. You have to catch that error and **translate** it into one of your cases. That's the real cost of typed throws, and lesson 5 is about doing that translation well.

If a `do` block calls functions with **different** error types, the typed information is lost: `error` in the `catch` becomes `any Error` again, and a `switch` on `.empty` fails with "type 'any Error' has no member 'empty'".

### throws(any Error) and throws(Never)

Typed throws makes the two extremes explicit:

- `throws(any Error)` is exactly plain `throws`. Any error can come out.
- `throws(Never)` can't throw anything, because `Never` has no values. It means the same as not throwing at all, and calls need no `try`.

You'll rarely write either by hand. They matter in generic code.

### Passing errors through generic code

A helper that runs a closure, like a timer that logs how long something took, shouldn't care what the closure throws. With typed throws it can pass the exact type through:

```swift
enum ParseError: Error {
    case empty
}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard !text.isEmpty else {
        throw .empty
    }
    return Int(text) ?? 0
}

func logged<T, E: Error>(_ label: String, _ work: () throws(E) -> T) throws(E) -> T {
    print("start \(label)")
    defer {
        print("end \(label)")
    }
    return try work()
}

let sum = logged("sum") { 2 + 3 }
print(sum)

func run() {
    do {
        let quantity = try logged("parse") { () throws(ParseError) -> Int in
            try parseQuantity("")
        }
        print(quantity)
    } catch {
        switch error {
        case .empty:
            print("handled .empty")
        }
    }
}
run()
```

```output
start sum
end sum
5
start parse
end parse
handled .empty
```

1. `logged` is generic over the result `T` (Module 11) **and** the error `E`. Whatever the closure throws, `logged` throws the same type.
2. `{ 2 + 3 }` doesn't throw, so `E` is inferred as `Never`. `logged` then can't throw either, and the call needs no `try`.
3. For the second call, `E` is `ParseError`, so `run` can `switch` on `error` exhaustively.

Notice the closure in the second call spells out its type: `() throws(ParseError) -> Int in`. In Swift 6.3, a closure whose type isn't written is inferred as plain `throws`, even if everything inside throws `ParseError`. Write `{ try parseQuantity("") }` instead and `E` becomes `any Error`; the `switch` then fails with "type 'any Error' has no member 'empty'".

This is what `rethrows` does for untyped code (lesson 5 shows it), with the error type preserved.

## Typed or untyped?

Typed throws is useful, and also a commitment. The Swift proposal itself says plain `throws` should remain the default for most code. Here's how to decide.

**Typed throws fits when:**

- The function is internal to your module or app, and its failures are a closed set you control, like a parser or a validator.
- You want the compiler to force every caller to handle every case, and to flag them all when a case is added.
- You're writing generic helpers that should pass the caller's error type through, like `logged` above.

**Plain `throws` fits when:**

- The function is part of an API other people call, and the ways it can fail might grow. A typed error is a promise: if version 2 needs a new failure, you either break every caller that switches over the type or squeeze the new failure into an existing case.
- The function calls code with several different error types. Typing it means translating every one of them, often into a vague catch-all case that's no better than `any Error`.
- Callers mostly show a message or log the error, and don't switch over cases anyway.

A good default for this course: plain `throws`, and typed throws for small, internal functions whose error enum you'd want every caller to handle completely.

## Result: an outcome as a value

`throws` hands the error to the caller **right now**. Sometimes you need to keep the outcome for later: collect it in an array, store it in a property, pass it to code that runs afterwards. **`Result`** is a standard library enum for that:

```swift
enum ParseError: Error {
    case empty
    case notANumber(String)
}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard !text.isEmpty else {
        throw .empty
    }
    guard let number = Int(text) else {
        throw .notANumber(text)
    }
    return number
}

func quantityResult(_ text: String) -> Result<Int, ParseError> {
    do {
        return .success(try parseQuantity(text))
    } catch {
        return .failure(error)
    }
}

let inputs = ["3", "", "ten", "5"]
let results = inputs.map { quantityResult($0) }

var total = 0
for (input, result) in zip(inputs, results) {
    switch result {
    case .success(let quantity):
        total += quantity
    case .failure(.empty):
        print("Line \"\(input)\": empty")
    case .failure(.notANumber(let text)):
        print("Line \"\(input)\": \(text) isn't a number")
    }
}
print("Total of valid lines: \(total)")
```

```output
Line "": empty
Line "ten": ten isn't a number
Total of valid lines: 8
```

1. `Result<Int, ParseError>` has two cases: `.success(Int)` and `.failure(ParseError)`. The second generic parameter must conform to `Error`.
2. `quantityResult` converts a throwing call into a `Result` with `do`/`catch`. Because `parseQuantity` is typed, `error` is a `ParseError` and fits `.failure(error)` directly.
3. `map` collects four outcomes into an array. With plain `throws`, the first bad line would have stopped the loop; with `Result`, every line gets an answer.
4. A `switch` handles each outcome, and patterns nest: `.failure(.notANumber(let text))` matches the failure case and the error case inside it at once.

### Converting between Result and throws

The standard library has both directions built in.

```swift
enum ParseError: Error {
    case notANumber(String)
}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard let number = Int(text) else {
        throw .notANumber(text)
    }
    return number
}

let wrapped = Result { try parseQuantity("12") }
print(type(of: wrapped))

let typed: Result<Int, ParseError> = .failure(.notANumber("x"))
do {
    let value = try typed.get()
    print(value)
} catch {
    print("get() threw \(error)")
}

let doubled = Result<Int, ParseError>.success(21).map { $0 * 2 }
if case .success(let value) = doubled {
    print("Doubled: \(value)")
}

struct ImportFailure: Error {
    let line: Int
    let reason: ParseError
}
let located = typed.mapError { ImportFailure(line: 4, reason: $0) }
if case .failure(let failure) = located {
    print("Line \(failure.line): \(failure.reason)")
}
```

```output
Result<Int, Error>
get() threw notANumber("x")
Doubled: 42
Line 4: notANumber("x")
```

- **`Result { try … }`** (its full name is `Result(catching:)`) runs the closure and wraps the outcome. Notice the type: `Result<Int, Error>`, untyped, for the same closure inference reason as before. When you want a typed `Result`, write the `do`/`catch` version like `quantityResult` above.
- **`.get()`** goes the other way: it returns the success value or throws the failure. On a `Result<Int, ParseError>`, `get()` throws `ParseError`, typed.
- **`.map`** transforms the success value and leaves a failure untouched. **`.mapError`** transforms the failure and leaves a success untouched; here it attaches a line number.

### When to use Result

Prefer a `throws` function when the caller handles the outcome immediately. That's most code, and `try` reads better than unwrapping enums. Reach for `Result` when:

- You need **one outcome per item** in a batch and want to keep going after failures.
- You need to **store** an outcome: the last sync result in a property, shown later by a screen.
- You're handing an outcome to code that runs **later**. Before Swift's `async`/`await`, which you'll meet in the concurrency module, callbacks commonly received a `Result`. You'll still see that style in older code and APIs.

## Common mistakes

> [!error] error: thrown expression type 'NetworkError' cannot be converted to error type 'ParseError'
> A typed function threw, or called with `try`, something of a different error type. Throw the declared type, or catch the other error and translate it into one of your cases.

> [!error] error: errors thrown from here are not handled because the enclosing catch is not exhaustive
> With typed throws, separate `catch .caseA` / `catch .caseB` clauses still don't count as exhaustive in Swift 6.3. Use one `catch` with a `switch error { … }` inside.

> [!error] error: type 'any Error' has no member 'empty'
> The `do` block calls functions with different error types, or a closure whose type wasn't written, so `error` is `any Error` again. Split the `do`, translate errors to one type, or annotate the closure with `throws(YourError)`.

> [!error] Typing every throws in a public API
> It feels precise, but you can never add a failure without breaking callers. Keep plain `throws` where the error set may grow.

> [!error] Returning Result from a function that could just throw
> `func load() -> Result<Data, LoadError>` makes every caller `switch` where a `try` would do. Use `throws` for immediate handling, and `Result` when the outcome must be stored or collected.

````exercise
id: m12-l04-e1
type: comprehension
prompt: "You're writing `parseDate(_:)` for a library that other teams use. Today it can fail with `badFormat` or `outOfRange`. Next quarter you'll probably support time zones, which adds a new way to fail. Which declaration is the better contract?"
choices:
  - text: "`func parseDate(_ text: String) throws(DateError) -> Date`, so callers can switch exhaustively."
    correct: false
    why: "Exhaustive switches in other teams' code would break when you add the time-zone case."
  - text: "`func parseDate(_ text: String) throws -> Date`, documenting the DateError cases it throws today."
    correct: true
    why: "Callers catch the cases they care about and keep a catch-all, so a new case doesn't break them."
  - text: "`func parseDate(_ text: String) throws(Never) -> Date`."
    correct: false
    why: "throws(Never) means it can't throw at all."
  - text: "`func parseDate(_ text: String) -> Result<Date, any Error>`."
    correct: false
    why: "It carries the same information as plain throws and makes every caller switch."
solution: |
  **Plain `throws`.** The failure set is going to grow, and other teams call the function. With a typed error, adding `badTimeZone` would break every caller that switches over `DateError`. With plain `throws`, callers match the cases they handle specially and end with a catch-all, which keeps working when you add a case. Typed throws shines for internal code whose error set you control and want every caller to handle completely.
````

````exercise
id: m12-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum VoteError: Error {
      case closed
      case duplicate(voter: String)
  }

  func vote(_ voter: String, seen: [String], open: Bool) throws(VoteError) -> String {
      guard open else { throw .closed }
      guard !seen.contains(voter) else { throw .duplicate(voter: voter) }
      return "\(voter) voted"
  }

  func attempt(_ voter: String, open: Bool) -> Result<String, VoteError> {
      do {
          return .success(try vote(voter, seen: ["ana"], open: open))
      } catch {
          return .failure(error)
      }
  }

  let outcomes = [attempt("leo", open: true), attempt("ana", open: true), attempt("sam", open: false)]
  for outcome in outcomes {
      switch outcome.map({ $0.uppercased() }) {
      case .success(let text):
          print(text)
      case .failure(.duplicate(let voter)):
          print("duplicate: \(voter)")
      case .failure(.closed):
          print("voting closed")
      }
  }
output: |
  LEO VOTED
  duplicate: ana
  voting closed
hints:
  - "map changes only success values."
  - "ana is in seen; the third call has open: false."
solution: |
  ```output
  LEO VOTED
  duplicate: ana
  voting closed
  ```

  Leo succeeds, and `map` uppercases the success text. Ana is in `seen`, so `vote` throws `.duplicate(voter: "ana")`; `map` leaves the failure untouched, so the voter name stays lowercase. Sam's call fails the first guard. The `switch` is exhaustive without a `default` because `VoteError` is a concrete type with two cases.
````

````exercise
id: m12-l04-e3
type: fill-in
prompt: |
  Complete the code so `checkPin` uses typed throws and `pinMessage` handles every case without a catch-all. It must print `Too short (4 required)` and `Digits only`.
code: |
  enum PinError: Error {
      case tooShort(required: Int)
      case notDigits
  }

  func checkPin(_ pin: String) throws([[1]]) {
      guard pin.count >= 4 else {
          throw [[2]]tooShort(required: 4)
      }
      guard Int(pin) != nil else {
          throw .notDigits
      }
  }

  func pinMessage(_ pin: String) -> String {
      do {
          try checkPin(pin)
          return "OK"
      } catch {
          [[3]] error {
          case .tooShort(let required):
              return "Too short (\(required) required)"
          case .notDigits:
              return "Digits only"
          }
      }
  }

  print(pinMessage("12"))
  print(pinMessage("12ab"))
blanks:
  - id: "1"
    answers: ["PinError"]
  - id: "2"
    answers: ["."]
  - id: "3"
    answers: ["switch"]
solution: |
  ```swift
  enum PinError: Error {
      case tooShort(required: Int)
      case notDigits
  }

  func checkPin(_ pin: String) throws(PinError) {
      guard pin.count >= 4 else {
          throw .tooShort(required: 4)
      }
      guard Int(pin) != nil else {
          throw .notDigits
      }
  }

  func pinMessage(_ pin: String) -> String {
      do {
          try checkPin(pin)
          return "OK"
      } catch {
          switch error {
          case .tooShort(let required):
              return "Too short (\(required) required)"
          case .notDigits:
              return "Digits only"
          }
      }
  }

  print(pinMessage("12"))
  print(pinMessage("12ab"))
  ```

  ```output
  Too short (4 required)
  Digits only
  ```

  `throws(PinError)` makes `error` a `PinError` in the catch, so `.tooShort` works as shorthand in both the `throw` and the `switch`. The `switch` covers both cases, so `pinMessage` compiles without a catch-all even though it isn't `throws`.
````

````exercise
id: m12-l04-e4
type: find-errors
prompt: "This code tries to use typed throws. Which statements are true?"
code: |
  enum CartError: Error {
      case empty
      case tooMany(Int)
  }

  struct PaymentError: Error {}

  func pay() throws {
      throw PaymentError()
  }

  func checkout(items: Int) throws(CartError) {
      guard items > 0 else { throw .empty }
      guard items <= 10 else { throw .tooMany(items) }
      try pay()
  }

  func show(items: Int) {
      do {
          try checkout(items: items)
      } catch .empty {
          print("Empty cart")
      } catch .tooMany(let count) {
          print("\(count) is too many")
      }
  }
choices:
  - text: "`try pay()` doesn't compile inside checkout: pay can throw any error, and checkout only throws CartError."
    correct: true
    why: "Swift reports that 'any Error' cannot be converted to error type 'CartError'. Catch and translate it."
  - text: "show doesn't compile: two separate catch clauses aren't treated as exhaustive."
    correct: true
    why: "Use one catch with a switch error inside."
  - text: "`throw .empty` needs to be `throw CartError.empty`."
    correct: false
    why: "In a function typed throws(CartError), the shorthand works."
  - text: "A function with typed throws can't call any other throwing function."
    correct: false
    why: "It can, as long as what they throw is its own error type, or it catches and translates the rest."
rubric:
  - I found the untyped pay() call.
  - I found the non-exhaustive catch clauses.
  - My fix translates the payment error into a CartError case and uses a switch in show.
solution: |
  Two real problems. `checkout` promises to throw only `CartError`, but `try pay()` could throw anything. And `show` uses separate catch clauses, which Swift 6.3 doesn't count as exhaustive. Fix the first by adding a case and translating; fix the second with a `switch`:

  ```swift
  enum CartError: Error {
      case empty
      case tooMany(Int)
      case paymentFailed
  }

  struct PaymentError: Error {}

  func pay() throws {
      throw PaymentError()
  }

  func checkout(items: Int) throws(CartError) {
      guard items > 0 else { throw .empty }
      guard items <= 10 else { throw .tooMany(items) }
      do {
          try pay()
      } catch {
          throw .paymentFailed
      }
  }

  func show(items: Int) {
      do {
          try checkout(items: items)
      } catch {
          switch error {
          case .empty:
              print("Empty cart")
          case .tooMany(let count):
              print("\(count) is too many")
          case .paymentFailed:
              print("Payment failed")
          }
      }
  }

  show(items: 0)
  show(items: 12)
  show(items: 2)
  ```

  ```output
  Empty cart
  12 is too many
  Payment failed
  ```

  Notice the cost: `paymentFailed` loses the payment error's details. If they matter, give the case an associated value. That trade-off is what lesson 5 is about.
````

````exercise
id: m12-l04-e5
type: solve
prompt: |
  Process a batch of temperature readings and keep going after bad ones.

  - `enum ReadingError: Error` with `case notANumber(String)` and `case outOfRange(Int)`.
  - `func parseReading(_ text: String) throws(ReadingError) -> Int` that throws `notANumber` if `Int(text)` fails and `outOfRange` if the value is below -50 or above 60.
  - `func readingResult(_ text: String) -> Result<Int, ReadingError>` that wraps it.
  - A loop over `["21", "abc", "75", "18"]` that prints each failure as below and finally the average of the valid readings (integer division).

  Expected output:

  ```output
  skip abc: not a number
  skip 75: out of range
  average: 19
  ```
starter: |
  enum ReadingError: Error {
      // your cases
  }
hints:
  - "readingResult: do { return .success(try parseReading(text)) } catch { return .failure(error) }"
  - "In the loop, keep a sum and a count of successes."
  - "Switch on .success, .failure(.notANumber) and .failure(.outOfRange)."
rubric:
  - parseReading uses throws(ReadingError) and the .case shorthand.
  - readingResult converts the throwing call into a Result without a catch-all type cast.
  - The loop handles every case of the Result exhaustively and continues after failures.
  - The output matches exactly.
solution: |
  ```swift
  enum ReadingError: Error {
      case notANumber(String)
      case outOfRange(Int)
  }

  func parseReading(_ text: String) throws(ReadingError) -> Int {
      guard let value = Int(text) else {
          throw .notANumber(text)
      }
      guard value >= -50 && value <= 60 else {
          throw .outOfRange(value)
      }
      return value
  }

  func readingResult(_ text: String) -> Result<Int, ReadingError> {
      do {
          return .success(try parseReading(text))
      } catch {
          return .failure(error)
      }
  }

  var sum = 0
  var count = 0
  for text in ["21", "abc", "75", "18"] {
      switch readingResult(text) {
      case .success(let value):
          sum += value
          count += 1
      case .failure(.notANumber(let input)):
          print("skip \(input): not a number")
      case .failure(.outOfRange(let value)):
          print("skip \(value): out of range")
      }
  }
  print("average: \(sum / count)")
  ```

  ```output
  skip abc: not a number
  skip 75: out of range
  average: 19
  ```

  21 + 18 = 39, divided by 2 is 19 in integer division. Because `ReadingError` is the declared type, `.failure(error)` needs no cast and the `switch` needs no `default`. (If every reading failed, `count` would be 0 and the division would crash; a real version would check for that.)
````

````exercise
id: m12-l04-e6
type: design
prompt: |
  You're building a small expense-tracking app. Decide, for each function, whether it should be typed throws, plain throws, or return a Result, and give a one-line reason:

  1. `parseAmount(_ text: String)`, internal, fails with `.empty`, `.notANumber`, `.negative`.
  2. `syncExpenses()`, which calls a networking library and a database library, each with its own errors.
  3. `importCSV(lines:)`, which should report which lines failed and still import the good ones.
  4. A public `ExpenseKit` framework function `categorize(_:)` that other apps will call, and whose failures you expect to grow.
rubric:
  - 1 is typed throws, because the error set is small, closed and internal.
  - 2 is plain throws, because it mixes several libraries' errors.
  - 3 returns an array of Result (or a Result per line), because it continues after failures.
  - 4 is plain throws, because typed errors in an evolving public API break callers.
solution: |
  1. **`throws(AmountError)`**. A closed set of three failures, internal to the app; the form code should handle all three, and the compiler should flag it if a fourth appears.
  2. **Plain `throws`**. It forwards errors from two libraries. Typing it would force translating everything into one enum. If the UI only shows "sync failed, retry", that translation buys nothing. (Lesson 5 discusses when to translate anyway.)
  3. **`[Result<Expense, LineError>]`**, or a struct that holds the good expenses and the failures. Throwing would stop at the first bad line.
  4. **Plain `throws`**. Other apps would switch over a typed error, and the first new failure would break them.

  A sketch of the first and third:

  ```swift
  enum AmountError: Error {
      case empty
      case notANumber(String)
      case negative(Int)
  }

  func parseAmount(_ text: String) throws(AmountError) -> Int {
      guard !text.isEmpty else { throw .empty }
      guard let cents = Int(text) else { throw .notANumber(text) }
      guard cents >= 0 else { throw .negative(cents) }
      return cents
  }

  func amountResult(_ line: String) -> Result<Int, AmountError> {
      do {
          return .success(try parseAmount(line))
      } catch {
          return .failure(error)
      }
  }

  func importAmounts(lines: [String]) -> [Result<Int, AmountError>] {
      lines.map(amountResult)
  }

  for result in importAmounts(lines: ["1250", "", "-3"]) {
      switch result {
      case .success(let cents):
          print("imported \(cents)")
      case .failure(let error):
          print("rejected: \(error)")
      }
  }
  ```

  ```output
  imported 1250
  rejected: empty
  rejected: negative(-3)
  ```
````

## Summary

- `throws(ErrorType)` (Swift 6.0, SE-0413) names the only error a function can throw. Inside it, `throw .case` works as shorthand.
- When a `do` block throws one concrete type, `error` in a plain `catch` has that type, and a `switch` over it is exhaustive with no catch-all. Separate `catch .case` clauses don't count as exhaustive in Swift 6.3.
- `throws(any Error)` is plain `throws`; `throws(Never)` doesn't throw. Generic helpers with `throws(E)` pass the closure's error type through, and need no `try` when `E` is `Never`.
- Closures whose type isn't written are inferred as plain `throws` in Swift 6.3, so typed information can get lost.
- Typed throws suits small, internal, closed error sets. Plain `throws` suits public, evolving APIs and code that mixes error types.
- `Result<Success, Failure>` holds an outcome as a value. Build one with `do`/`catch` or `Result { try … }`, get back to throwing with `.get()`, and transform with `.map` and `.mapError`.
