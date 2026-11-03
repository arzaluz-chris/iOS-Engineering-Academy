---
id: m12-l02
title: Handling errors with do-catch
description: You handle thrown errors with do and catch, match specific cases and their associated values with catch patterns, cast with catch let as, order catch clauses correctly, know when a catch has to be exhaustive, and rethrow an error after logging it.
module: m12
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l01]
objectives:
  - Handle errors with a do block and one or more catch clauses.
  - Use the implicit error constant in a catch-all clause.
  - Match specific error cases, bind associated values and add where conditions in catch clauses.
  - Cast a caught error to a concrete type with catch let … as, and test it with catch is.
  - Order catch clauses from specific to general and explain why.
  - Decide when a catch has to cover every error, and rethrow an error after logging it.
terms:
  - term: do-catch
    definition: "A statement that runs the code in do and, if anything in it throws, jumps to the first catch clause whose pattern matches the error."
  - term: catch clause
    definition: "One handler after a do block. It can have a pattern (catch LoginError.locked), a cast (catch let e as LoginError), a where condition, or nothing, in which case it catches everything."
  - term: Implicit error constant
    definition: "Inside a catch clause with no pattern, the thrown value is available as error, of type any Error."
  - term: Exhaustive catch
    definition: "A set of catch clauses that handles every possible error, which in practice means it ends with a catch-all. Required in a function that isn't throws."
  - term: Rethrowing
    definition: "Catching an error, doing something with it (usually logging), and throwing it again, or throwing a different one, so the caller still finds out."
mastery:
  - Write a do-catch with three clauses that react differently to three error cases.
  - Bind an associated value in a catch pattern and use it in the message.
  - "Rewrite a catch-all that uses if/else on error into specific catch clauses."
  - Spot a catch-all placed before specific clauses and explain the warning.
  - Choose between handling an error, propagating it and rethrowing it, for a given function.
resources: [swift-book-error-handling, swift-book-enumerations, swift-book-control-flow]
cards:
  - id: m12-l02-c1
    front: What's the type of `error` in a plain `catch { }`?
    back: "any Error. To use the cases of your own enum, match them in the catch pattern or cast with `catch let e as MyError`."
  - id: m12-l02-c2
    front: Two catch clauses could both match an error. Which one runs?
    back: "The first one, top to bottom. Put specific clauses first and the catch-all last; a catch-all first makes the rest dead code (\"case will never be executed\")."
  - id: m12-l02-c3
    front: When must a do-catch catch everything?
    back: "When the function it's in isn't throws: an unmatched error would have nowhere to go. In a throws function, unmatched errors propagate to the caller."
  - id: m12-l02-c4
    front: "Is `error` available in `catch LoginError.locked { }`?"
    back: "No. The implicit error constant only exists in a catch with no pattern. Bind what you need in the pattern instead."
  - id: m12-l02-c5
    front: How do you log an error and still let the caller handle it?
    back: "In a throws function: `catch { log(error); throw error }`."
---

## The idea in one sentence

`do` runs code that might throw, and the `catch` clauses after it say what to do about each kind of error, from the most specific to the most general.

## do and catch

You've used the simplest form already:

```swift
enum LoginError: Error {
    case wrongPassword
    case locked
}

func logIn(user: String, password: String) throws -> String {
    guard user != "blocked" else {
        throw LoginError.locked
    }
    guard password == "s3cret" else {
        throw LoginError.wrongPassword
    }
    return "token-\(user)"
}

do {
    let token = try logIn(user: "ana", password: "nope")
    print("Logged in with \(token)")
} catch {
    print("Login failed: \(error)")
}
print("Program continues")
```

```output
Login failed: wrongPassword
Program continues
```

1. Everything that might throw goes inside `do { }`. The `try` calls inside are the places where control can jump out.
2. When `logIn` throws, the rest of the `do` block is skipped: "Logged in" never prints.
3. Control jumps to `catch`. A `catch` with no pattern catches **any** error, and gives it to you as a constant named **`error`**.
4. After the `catch` finishes, the program continues after the whole statement. The error was **handled**; it doesn't propagate further.

`error` here has type `any Error`. Printing it works, but you can't switch on the cases of `LoginError` directly, because Swift only knows it's *some* error. Catch clauses with patterns fix that.

## Catching specific errors

A `catch` can be followed by a pattern, just like a `case` in a `switch` (Module 9). The first clause whose pattern matches the error runs:

```swift
enum LoginError: Error {
    case wrongPassword(attemptsLeft: Int)
    case locked(minutes: Int)
    case noConnection
}

func logIn(user: String, password: String) throws -> String {
    switch user {
    case "ana": throw LoginError.wrongPassword(attemptsLeft: 2)
    case "leo": throw LoginError.wrongPassword(attemptsLeft: 0)
    case "sam": throw LoginError.locked(minutes: 15)
    case "offline": throw LoginError.noConnection
    default: return "token-\(user)"
    }
}

func loginMessage(user: String) -> String {
    do {
        let token = try logIn(user: user, password: "x")
        return "Welcome back (\(token))"
    } catch LoginError.wrongPassword(let attemptsLeft) where attemptsLeft > 0 {
        return "Wrong password. \(attemptsLeft) attempts left."
    } catch LoginError.wrongPassword {
        return "Wrong password. Your account is now locked."
    } catch LoginError.locked(let minutes) {
        return "Account locked. Try again in \(minutes) minutes."
    } catch LoginError.noConnection {
        return "No connection. Check your network and retry."
    } catch {
        return "Unexpected error: \(error)"
    }
}

for user in ["ana", "leo", "sam", "offline", "zoe"] {
    print(loginMessage(user: user))
}
```

```output
Wrong password. 2 attempts left.
Wrong password. Your account is now locked.
Account locked. Try again in 15 minutes.
No connection. Check your network and retry.
Welcome back (token-zoe)
```

Line by line through the clauses:

1. `catch LoginError.wrongPassword(let attemptsLeft)` matches that case and binds its associated value, exactly like `case .wrongPassword(let attemptsLeft)` in a `switch`. You have to write the type name (`LoginError.`) because the error is `any Error`, so Swift can't infer which enum the case belongs to.
2. `where attemptsLeft > 0` adds a condition. Leo's error matches the case but fails the condition, so Swift moves on.
3. `catch LoginError.wrongPassword` with no binding matches any `wrongPassword`, whatever its value. Leo lands here.
4. The last `catch` has no pattern, so it catches anything the others didn't. It's the only clause where `error` exists.

This is the payoff promised in Module 8: one function, four failures, four different messages.

### Casting with as and testing with is

Sometimes you want the whole error as your own type, not one case. Use **`catch let name as Type`**:

```swift
enum CartError: Error {
    case outOfStock(item: String)
    case limitExceeded(maximum: Int)

    var message: String {
        switch self {
        case .outOfStock(let item):
            return "\(item) is out of stock."
        case .limitExceeded(let maximum):
            return "You can order at most \(maximum)."
        }
    }
}

struct PaymentDeclined: Error {
    let code: Int
}

func checkout(_ step: Int) throws {
    switch step {
    case 1: throw CartError.limitExceeded(maximum: 5)
    case 2: throw PaymentDeclined(code: 51)
    default: print("Order placed")
    }
}

for step in 1...3 {
    do {
        try checkout(step)
    } catch let cartError as CartError {
        print("Cart: \(cartError.message)")
    } catch is PaymentDeclined {
        print("Payment declined. Try another card.")
    } catch {
        print("Other: \(error)")
    }
}
```

```output
Cart: You can order at most 5.
Payment declined. Try another card.
Order placed
```

- `catch let cartError as CartError` matches any `CartError` and gives it to you **typed as `CartError`**, so you can use its `message` property or `switch` on it.
- `catch is PaymentDeclined` matches without binding anything, for when the type alone decides what to do.

Putting a `message` property on the error enum keeps the `switch` in one place. Lesson 5 shows the standard way to do this for messages users see.

### Order matters

Swift tries the clauses top to bottom and runs the **first** match. A catch-all placed first swallows everything:

```swift warning case will never be executed
enum LoginError: Error {
    case locked
}

func logIn() throws {
    throw LoginError.locked
}

do {
    try logIn()
} catch {
    print("Something failed")
} catch LoginError.locked {
    print("Account locked")
}
```

```output
Something failed
```

Swift 6.3 warns `warning: case will never be executed` on the second clause. It's only a warning, so the code runs, with the wrong message. Put specific clauses first and the catch-all last. The same goes for two patterns where one includes the other: `wrongPassword(let n) where n > 0` must come before plain `wrongPassword`.

## Does the catch have to cover everything?

It depends on where the `do` is.

**In a function that isn't `throws`**, every error must be handled, because there's nowhere else for it to go. If your clauses could miss one, it doesn't compile:

```swift no-compile errors thrown from here are not handled because the enclosing catch is not exhaustive
enum LoginError: Error {
    case wrongPassword
    case locked
}

func logIn() throws {
    throw LoginError.locked
}

func showLogin() {
    do {
        try logIn()
    } catch LoginError.wrongPassword {
        print("Wrong password")
    } catch LoginError.locked {
        print("Locked")
    }
}

showLogin()
```

Swift 6.3: `error: errors thrown from here are not handled because the enclosing catch is not exhaustive`. You covered both cases of `LoginError`, but `logIn` is declared plain `throws`, so as far as the compiler knows it could throw **any** error. Add a final `catch { }`. (Lesson 4 shows typed throws, which tell the compiler exactly which error type to expect.)

**In a `throws` function**, the clauses don't have to cover everything. Whatever isn't matched propagates to the caller:

```swift
enum LoginError: Error {
    case wrongPassword
    case noConnection
}

func logIn(online: Bool) throws {
    guard online else {
        throw LoginError.noConnection
    }
    throw LoginError.wrongPassword
}

func logInOrShowHint(online: Bool) throws {
    do {
        try logIn(online: online)
    } catch LoginError.wrongPassword {
        print("Hint: passwords are case sensitive")
    }
}

do {
    try logInOrShowHint(online: true)
    try logInOrShowHint(online: false)
} catch {
    print("Caller got: \(error)")
}
```

```output
Hint: passwords are case sensitive
Caller got: noConnection
```

`logInOrShowHint` handles the one error it knows how to handle and lets the rest through. That's a common and healthy shape: each layer handles what it understands.

> [!warning] Top-level code is a throwing context
> In `main.swift`, top-level code behaves like a throwing function: a `do`/`catch` there that doesn't match an error compiles, and the unmatched error crashes the program with "Error raised at top level". Inside functions, the compiler checks for you.

## Rethrowing

Sometimes a function wants to **notice** an error without handling it: log it, count it, clean something up, and then let the caller decide. Catch it and throw it again:

```swift
enum SyncError: Error {
    case serverUnavailable
}

func uploadNotes() throws {
    throw SyncError.serverUnavailable
}

func syncNotes() throws {
    do {
        try uploadNotes()
    } catch {
        print("[log] sync failed: \(error)")
        throw error
    }
    print("Sync finished")
}

do {
    try syncNotes()
} catch {
    print("Showing banner: sync is paused")
}
```

```output
[log] sync failed: serverUnavailable
Showing banner: sync is paused
```

`throw error` inside the `catch` sends the same error on to the caller. The log line is written where the context is (the sync layer); the user-facing decision is made where the UI is.

You can also throw a **different** error from a `catch`, translating a low-level failure into one that makes sense to your caller. Lesson 5 is about when and how to do that.

## Variables declared inside do

`do` is a block like any other. A constant declared inside it doesn't exist after it:

```swift no-compile cannot find 'quantity' in scope
enum QuantityError: Error {
    case invalid
}

func parseQuantity(_ text: String) throws -> Int {
    guard let value = Int(text) else {
        throw QuantityError.invalid
    }
    return value
}

do {
    let quantity = try parseQuantity("3")
} catch {
    print(error)
}
print(quantity)
```

Swift 6.3: `error: cannot find 'quantity' in scope`. Either do the work that needs `quantity` inside the `do`, or move the whole thing into a function that returns or throws. The next lesson shows `try?`, which often fits this situation better.

## A practical example: a checkout screen

A checkout step that knows how to recover from some errors and reports the rest:

```swift
enum CheckoutError: Error {
    case emptyCart
    case outOfStock(item: String)
    case cardDeclined(reason: String)
    case serviceUnavailable
}

struct Inventory {
    let stock: [String: Int]

    func reserve(_ items: [String]) throws {
        guard !items.isEmpty else {
            throw CheckoutError.emptyCart
        }
        for item in items {
            guard let available = stock[item], available > 0 else {
                throw CheckoutError.outOfStock(item: item)
            }
        }
    }
}

func charge(card: String) throws {
    if card == "expired" {
        throw CheckoutError.cardDeclined(reason: "card expired")
    }
    if card == "down" {
        throw CheckoutError.serviceUnavailable
    }
}

func placeOrder(_ items: [String], card: String, inventory: Inventory) -> String {
    do {
        try inventory.reserve(items)
        try charge(card: card)
        return "Order placed: \(items.joined(separator: ", "))"
    } catch CheckoutError.emptyCart {
        return "Your cart is empty."
    } catch CheckoutError.outOfStock(let item) {
        return "Sorry, \(item) just sold out. Remove it to continue."
    } catch CheckoutError.cardDeclined(let reason) {
        return "Payment declined (\(reason)). Try another card."
    } catch {
        print("[log] checkout failed: \(error)")
        return "Something went wrong. You haven't been charged."
    }
}

let inventory = Inventory(stock: ["mug": 3, "beans": 0])
print(placeOrder(["mug"], card: "4242", inventory: inventory))
print(placeOrder([], card: "4242", inventory: inventory))
print(placeOrder(["mug", "beans"], card: "4242", inventory: inventory))
print(placeOrder(["mug"], card: "expired", inventory: inventory))
print(placeOrder(["mug"], card: "down", inventory: inventory))
```

```output
Order placed: mug
Your cart is empty.
Sorry, beans just sold out. Remove it to continue.
Payment declined (card expired). Try another card.
[log] checkout failed: serviceUnavailable
Something went wrong. You haven't been charged.
```

`placeOrder` isn't `throws`: it's the layer that turns every error into a message for the screen, so it must handle everything and ends with a catch-all. The specific clauses produce specific advice. The catch-all logs the detail for the developers and shows the user something honest without the internals. The order of the `try` lines matters too: if reserving fails, the card is never charged.

## Common mistakes

> [!error] warning: case will never be executed
> A catch-all, or a broader pattern, sits above a more specific clause. Move specific clauses up and the plain `catch` to the bottom.

> [!error] error: errors thrown from here are not handled because the enclosing catch is not exhaustive
> The `do` is in a non-throwing function and the clauses don't catch everything. Covering every case of your enum isn't enough when the function is declared plain `throws`. Add a final `catch`, or make the enclosing function `throws`.

> [!error] error: expansion of macro 'error' requires leading '#'
> You used `error` inside a catch clause that has a pattern, like `catch LoginError.locked { print(error) }`. The implicit `error` only exists in a plain `catch`. Swift 6.3 then finds the unrelated `#error` macro and gives this confusing message. Bind what you need in the pattern (`catch let e as LoginError`) or use a plain `catch`.

> [!error] An empty catch
> `catch { }` makes the error vanish. The app looks like it worked, and nobody finds out why the data is missing. At minimum, log what you swallow (lesson 6).

> [!error] Catching too early
> A low-level function that catches an error and prints "failed" leaves its caller no way to react. If a function doesn't know what to do about an error, let it propagate.

````exercise
id: m12-l02-e1
type: comprehension
prompt: "Inside `catch let e as LoginError { … }`, what is `e`?"
choices:
  - text: "A LoginError, so you can switch on its cases."
    correct: true
    why: "The cast succeeded, and e has the concrete type."
  - text: "An any Error that you still have to cast."
    correct: false
    why: "That's the implicit error constant in a plain catch, not a bound cast."
  - text: "An optional LoginError?, nil if the error was another type."
    correct: false
    why: "If the error isn't a LoginError, this clause doesn't match at all and Swift tries the next one."
  - text: "The same as error; both names are available in this clause."
    correct: false
    why: "error only exists in a catch with no pattern."
solution: |
  **A `LoginError`.** `catch let e as LoginError` matches only when the thrown error is a `LoginError`, and then binds it with that type. Errors of other types skip this clause and go to the next one. The implicit `error` isn't defined here.
````

````exercise
id: m12-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum UploadError: Error {
      case tooLarge(megabytes: Int)
      case offline
      case quotaExceeded
  }

  func upload(_ size: Int) throws {
      if size > 100 { throw UploadError.tooLarge(megabytes: size) }
      if size == 0 { throw UploadError.offline }
      if size == 42 { throw UploadError.quotaExceeded }
      print("Uploaded \(size) MB")
  }

  func tryUpload(_ size: Int) throws {
      do {
          try upload(size)
      } catch UploadError.tooLarge(let megabytes) where megabytes > 500 {
          print("Way too large")
      } catch UploadError.tooLarge {
          print("Too large")
      } catch UploadError.offline {
          print("Offline")
      }
  }

  for size in [10, 200, 900, 0, 42] {
      do {
          try tryUpload(size)
      } catch {
          print("Caller: \(error)")
      }
  }
output: |
  Uploaded 10 MB
  Too large
  Way too large
  Offline
  Caller: quotaExceeded
hints:
  - "The first matching clause wins, and where adds a condition."
  - "tryUpload is throws and has no catch-all. Where does quotaExceeded go?"
solution: |
  ```output
  Uploaded 10 MB
  Too large
  Way too large
  Offline
  Caller: quotaExceeded
  ```

  10 succeeds. 200 is `tooLarge`, but 200 isn't over 500, so the first clause doesn't match and the second does. 900 matches the first clause. 0 is `offline`. 42 throws `quotaExceeded`, which no clause in `tryUpload` matches; because `tryUpload` is `throws`, the error propagates to the loop's `catch`.
````

````exercise
id: m12-l02-e3
type: find-errors
prompt: "This function should show a message for every possible failure. Which statements are true?"
code: |
  enum ImportError: Error {
      case fileMissing(name: String)
      case corrupted
  }

  func importFile(_ name: String) throws {
      throw ImportError.fileMissing(name: name)
  }

  func showImport(_ name: String) {
      do {
          try importFile(name)
      } catch {
          print("Import failed")
      } catch ImportError.fileMissing(let name) {
          print("\(name) not found")
      } catch ImportError.corrupted {
          print("File is damaged: \(error)")
      }
  }
choices:
  - text: "The plain catch comes first, so the two specific clauses can never run."
    correct: true
    why: "Swift warns \"case will never be executed\". Move the plain catch to the end."
  - text: "`error` isn't available in the corrupted clause, because that clause has a pattern."
    correct: true
    why: "The implicit error constant exists only in a plain catch."
  - text: "showImport must be marked throws because it calls a throwing function."
    correct: false
    why: "It handles the error with do-catch, so it doesn't need to throw, as long as the catch is exhaustive."
  - text: "Binding `let name` in the catch pattern clashes with the parameter `name`."
    correct: false
    why: "The binding shadows the parameter inside that clause, which is allowed. It's the same value here anyway."
rubric:
  - I found the misplaced catch-all.
  - I noticed error isn't defined in a clause with a pattern.
  - I rewrote the clauses in the right order.
solution: |
  Two real problems: the catch-all is first, so it catches everything and the other clauses are dead code; and the `corrupted` clause uses `error`, which doesn't exist in a clause with a pattern. Fixed:

  ```swift
  enum ImportError: Error {
      case fileMissing(name: String)
      case corrupted
  }

  func importFile(_ name: String) throws {
      throw ImportError.fileMissing(name: name)
  }

  func showImport(_ name: String) {
      do {
          try importFile(name)
      } catch ImportError.fileMissing(let name) {
          print("\(name) not found")
      } catch ImportError.corrupted {
          print("File is damaged")
      } catch {
          print("Import failed: \(error)")
      }
  }

  showImport("notes.txt")
  ```

  ```output
  notes.txt not found
  ```

  The catch-all stays, now last: `importFile` is plain `throws`, so `showImport`, which isn't `throws`, must still handle errors of any type.
````

````exercise
id: m12-l02-e4
type: refactor
prompt: |
  This handler uses one catch-all and casts by hand. Rewrite it with specific catch clauses so each case is handled in its own clause and the output stays the same.
code: |
  enum TicketError: Error {
      case soldOut
      case tooMany(limit: Int)
  }

  func buyTickets(_ count: Int) throws {
      if count > 4 { throw TicketError.tooMany(limit: 4) }
      if count == 3 { throw TicketError.soldOut }
      print("Bought \(count)")
  }

  for count in [2, 3, 6] {
      do {
          try buyTickets(count)
      } catch {
          if let ticketError = error as? TicketError {
              switch ticketError {
              case .soldOut:
                  print("Sold out")
              case .tooMany(let limit):
                  print("Limit is \(limit)")
              }
          } else {
              print("Unknown error")
          }
      }
  }
rubric:
  - Uses one catch clause per TicketError case.
  - Binds the limit in the tooMany pattern.
  - Keeps a final catch-all for other errors.
  - The output is unchanged.
solution: |
  ```swift
  enum TicketError: Error {
      case soldOut
      case tooMany(limit: Int)
  }

  func buyTickets(_ count: Int) throws {
      if count > 4 { throw TicketError.tooMany(limit: 4) }
      if count == 3 { throw TicketError.soldOut }
      print("Bought \(count)")
  }

  for count in [2, 3, 6] {
      do {
          try buyTickets(count)
      } catch TicketError.soldOut {
          print("Sold out")
      } catch TicketError.tooMany(let limit) {
          print("Limit is \(limit)")
      } catch {
          print("Unknown error")
      }
  }
  ```

  ```output
  Bought 2
  Sold out
  Limit is 4
  ```

  Catch patterns do the cast, the switch and the binding in one step. The catch-all stays because `buyTickets` is plain `throws`, and the loop is at the top level where an unmatched error would crash the program.
````

````exercise
id: m12-l02-e5
type: solve
prompt: |
  Write the error handling for a file-sharing feature.

  - `enum ShareError: Error` with cases `notFound(name: String)`, `permissionDenied`, and `tooLarge(megabytes: Int, limit: Int)`.
  - `func share(_ name: String, sizeInMB: Int) throws -> String` that throws `notFound` when `name` doesn't end with `".pdf"`, `permissionDenied` when the name starts with `"private"`, and `tooLarge` when `sizeInMB > 25` (limit 25). Otherwise it returns `"Shared \(name)"`. Check in that order.
  - `func shareMessage(_ name: String, sizeInMB: Int) -> String` (not throws) that returns the result of `share` or one of these messages: `"<name> doesn't exist"`, `"You can't share this file"`, `"<n> MB is over the <limit> MB limit"`, and `"Unknown problem"` for anything else.

  This must print:

  ```output
  Shared report.pdf
  photo.jpg doesn't exist
  You can't share this file
  40 MB is over the 25 MB limit
  ```

  from:

  ```swift
  print(shareMessage("report.pdf", sizeInMB: 3))
  print(shareMessage("photo.jpg", sizeInMB: 3))
  print(shareMessage("private-notes.pdf", sizeInMB: 1))
  print(shareMessage("scan.pdf", sizeInMB: 40))
  ```
starter: |
  enum ShareError: Error {
      // your cases
  }
hints:
  - "Use name.hasSuffix(\".pdf\") and name.hasPrefix(\"private\")."
  - "In shareMessage, bind associated values in the catch patterns."
  - "shareMessage isn't throws, so it needs a final plain catch."
rubric:
  - share throws the three cases in the specified order.
  - shareMessage has one specific catch clause per case, binding associated values.
  - shareMessage ends with a catch-all and isn't throws.
  - The output matches exactly.
solution: |
  ```swift
  enum ShareError: Error {
      case notFound(name: String)
      case permissionDenied
      case tooLarge(megabytes: Int, limit: Int)
  }

  func share(_ name: String, sizeInMB: Int) throws -> String {
      guard name.hasSuffix(".pdf") else {
          throw ShareError.notFound(name: name)
      }
      guard !name.hasPrefix("private") else {
          throw ShareError.permissionDenied
      }
      guard sizeInMB <= 25 else {
          throw ShareError.tooLarge(megabytes: sizeInMB, limit: 25)
      }
      return "Shared \(name)"
  }

  func shareMessage(_ name: String, sizeInMB: Int) -> String {
      do {
          return try share(name, sizeInMB: sizeInMB)
      } catch ShareError.notFound(let missing) {
          return "\(missing) doesn't exist"
      } catch ShareError.permissionDenied {
          return "You can't share this file"
      } catch ShareError.tooLarge(let megabytes, let limit) {
          return "\(megabytes) MB is over the \(limit) MB limit"
      } catch {
          return "Unknown problem"
      }
  }

  print(shareMessage("report.pdf", sizeInMB: 3))
  print(shareMessage("photo.jpg", sizeInMB: 3))
  print(shareMessage("private-notes.pdf", sizeInMB: 1))
  print(shareMessage("scan.pdf", sizeInMB: 40))
  ```

  ```output
  Shared report.pdf
  photo.jpg doesn't exist
  You can't share this file
  40 MB is over the 25 MB limit
  ```

  `return try share(…)` returns the success value directly from inside `do`. Each clause binds exactly the values its message needs; `tooLarge(let megabytes, let limit)` binds both. The final `catch` is required because `shareMessage` isn't `throws` and `share` is declared plain `throws`.
````

````exercise
id: m12-l02-e6
type: explain
prompt: |
  A teammate wrote this and says "the error is handled, so we're fine". Explain what the user experiences when the server is down, and what you'd change. Consider who should decide what to show.
code: |
  func loadMessages() -> [String] {
      do {
          return try fetchMessagesFromServer()
      } catch {
          return []
      }
  }
rubric:
  - I said the user sees an empty inbox, which looks like "no messages", not "couldn't load".
  - I said nothing is logged, so the failure is invisible to developers too.
  - I proposed propagating (throws) so the screen can show an error state, or at least logging and returning something that distinguishes failure from emptiness.
solution: |
  When the server is down, `loadMessages` returns `[]`, and the screen shows an empty inbox. The user believes they have no messages, which is false. An empty array has a correct meaning ("no messages") and this code reuses it to mean "failed", the sentinel problem from Module 6 in a new form. Nothing is logged either, so developers never see that it's happening.

  `loadMessages` doesn't know how the screen wants to present a failure, so it shouldn't decide. Make it `throws` and let the screen's code catch the error, show "Couldn't load messages" with a retry button, and keep the old messages if it has them. If some caller really wants "empty on failure", it can write `(try? loadMessages()) ?? []` itself (next lesson), and that choice is then visible at the call site.
````

## Summary

- `do { … } catch { … }` runs code that can throw. When something throws, the rest of `do` is skipped and the first matching `catch` runs.
- A plain `catch` catches everything and provides `error`, typed `any Error`. Clauses with patterns don't have `error`.
- Catch clauses can match a case (`catch LoginError.locked`), bind associated values, add `where`, cast (`catch let e as LoginError`) or test (`catch is LoginError`).
- Order clauses from specific to general. A catch-all above other clauses makes them dead code.
- In a non-throwing function, the clauses must handle every error, so end with a plain `catch`. In a `throws` function, unmatched errors propagate.
- Rethrow with `throw error` after logging when the caller should still decide. Handle an error only where you know what to do about it.
