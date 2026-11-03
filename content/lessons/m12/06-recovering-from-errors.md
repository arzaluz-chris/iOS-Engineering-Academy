---
id: m12-l06
title: Recovering from errors
description: You separate recoverable errors from programmer mistakes that should stop the program, retry transient failures a limited number of times, fall back to a cache or default, log every error you swallow, and build an order-processing pipeline that validates, transforms and reports errors per item.
module: m12
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l05]
objectives:
  - Decide whether a failure should be thrown or should stop the program with precondition or fatalError.
  - Retry an operation a limited number of times, and only for errors that are worth retrying.
  - Fall back to a cached or default value when the primary source fails, and log that it happened.
  - Make sure every catch that doesn't rethrow either shows the error or logs it.
  - Process a batch of items so one failure doesn't stop the rest, and report each outcome.
  - Undo partial work with defer when a later step fails.
terms:
  - term: Recoverable error
    definition: "A failure caused by the outside world (input, network, disk, other services) that a correct program should expect and handle. Swift models these with throws."
  - term: Programmer error
    definition: "A failure that can only happen if the code is wrong: a broken invariant, an impossible state. Continuing would make things worse, so the program should stop."
  - term: precondition
    definition: "A check that stops the program with \"Precondition failed\" and a message if its condition is false. Use it for assumptions a caller must satisfy."
  - term: Transient error
    definition: "A failure that may go away if you try again: a timeout, a busy server. Validation and business-rule errors aren't transient."
  - term: Fallback
    definition: "A second source used when the first fails: a cache when the network is down, a default when a setting is unreadable."
mastery:
  - Classify failures as recoverable (throw) or programmer errors (precondition or fatalError), with a reason.
  - "Write a retry helper that takes a limit and a shouldRetry check, and predict how many attempts it makes."
  - Write a primary-then-cache-then-default chain that logs each fallback.
  - Find a catch that swallows an error silently and fix it.
  - Explain how the order pipeline keeps going after a bad line and how it releases stock when payment fails.
resources: [swift-precondition, swift-book-error-handling, swift-fatalerror, swift-book-closures, swift-book-functions]
cards:
  - id: m12-l06-c1
    front: "throw or precondition?"
    back: "throw when the outside world caused it (input, network, files) and a correct program must handle it. precondition (or fatalError) when it can only happen if the code is wrong."
  - id: m12-l06-c2
    front: Which errors should you retry?
    back: "Only transient ones, like timeouts or a busy server, and only a limited number of times. Retrying a validation error or a declined card gives the same answer."
  - id: m12-l06-c3
    front: What's the minimum a catch that doesn't rethrow must do?
    back: "Show the error to the user or log it, ideally both when it matters. A silent catch hides bugs and data loss."
  - id: m12-l06-c4
    front: How do you keep a batch going when one item fails?
    back: "Handle errors per item inside the loop (do-catch or a Result per item) instead of letting one error propagate out of the loop."
  - id: m12-l06-c5
    front: "How can defer undo partial work?"
    back: "Set a flag like `var committed = false`, add `defer { if !committed { undo() } }`, and set the flag only after the last step succeeds. Every early return or throw triggers the undo."
---

## The idea in one sentence

Throw what the outside world can cause and handle it on purpose (retry what's temporary, fall back where there's an alternative, log what you swallow), and stop the program only when the code itself is wrong.

## Recoverable or not?

Everything in this module so far has been about **recoverable** errors: a user typed "three", a server timed out, a card was declined. A correct program expects these. They're thrown, and someone handles them.

There's a second kind. A function that requires a positive page size receives -1. An array that should never be empty, by construction, is empty. A `switch` reaches a state your design says is impossible. These are **programmer errors**: they only happen if the code is wrong. Throwing doesn't help, because no caller can do anything sensible about a bug. Swift's answer is to stop the program, loudly, at the spot where the assumption broke:

```swift runtime-error Precondition failed: pageSize must be positive
func pages(forItems items: Int, pageSize: Int) -> Int {
    precondition(pageSize > 0, "pageSize must be positive")
    return (items + pageSize - 1) / pageSize
}

print(pages(forItems: 45, pageSize: 20))
print(pages(forItems: 45, pageSize: 0))
print("never printed")
```

```output
3
```

Swift 6.3 prints `Precondition failed: pageSize must be positive` and stops. Without the check, the second call would have crashed anyway on a division by zero, with a message that says nothing about why.

- **`precondition(condition, "message")`** checks an assumption, typically about a function's arguments. It stays active in release builds, the ones you ship.
- **`fatalError("message")`** stops unconditionally. Use it for a code path that must be unreachable:

```swift runtime-error Fatal error: Unknown theme: neon
enum Theme: String {
    case light
    case dark
}

func theme(named name: String) -> Theme {
    guard let theme = Theme(rawValue: name) else {
        fatalError("Unknown theme: \(name)")
    }
    return theme
}

print(theme(named: "dark"))
print(theme(named: "neon"))
```

```output
dark
```

This is only right if `name` always comes from your own code, say a constant in the app. If it came from a settings file a user can edit, an unknown theme is a recoverable error: throw, or fall back to `.light`.

There's also `assert`, which works like `precondition` but is checked only in debug builds. It's for expensive sanity checks during development.

The decision, in one table:

| The failure is caused by… | Example | Use |
| --- | --- | --- |
| Input from a person | "three" in a quantity field | `throw` a validation error |
| The environment | timeout, disk full, server down | `throw`, then retry or fall back |
| A business rule | sold out, insufficient funds | `throw` a domain error |
| Your own code being wrong | page size 0 from your own call, an impossible enum state | `precondition` / `fatalError` |

When you're unsure which row you're in, throw. A crash is the right answer only when you can say "this can't happen unless I wrote a bug".

## Retrying, with a limit

Some failures go away if you try again. A **transient** error, like a timeout, might succeed on the second attempt. A validation error or a declined card won't: retrying just repeats the same answer, slower.

A retry helper needs three things: an operation, a limit, and a way to decide which errors are worth retrying.

```swift
enum FetchError: Error {
    case timeout
    case notFound
}

final class FlakyServer {
    private var timeoutsLeft: Int
    private(set) var calls = 0

    init(timeoutsLeft: Int) {
        self.timeoutsLeft = timeoutsLeft
    }

    func fetchProfile(id: Int) throws -> String {
        calls += 1
        guard id > 0 else {
            throw FetchError.notFound
        }
        if timeoutsLeft > 0 {
            timeoutsLeft -= 1
            throw FetchError.timeout
        }
        return "profile \(id)"
    }
}

func retry<T>(
    attempts: Int,
    shouldRetry: (any Error) -> Bool,
    _ operation: () throws -> T
) rethrows -> T {
    precondition(attempts >= 1, "attempts must be at least 1")
    for attempt in 1..<attempts {
        do {
            return try operation()
        } catch where shouldRetry(error) {
            print("  attempt \(attempt) failed: \(error), retrying")
        }
    }
    return try operation()
}

func isTimeout(_ error: any Error) -> Bool {
    if case FetchError.timeout = error {
        return true
    }
    return false
}

let scenarios = [("two timeouts", 2, 7), ("five timeouts", 5, 7), ("not found", 0, -1)]
for (name, timeouts, id) in scenarios {
    let server = FlakyServer(timeoutsLeft: timeouts)
    print(name)
    do {
        let profile = try retry(attempts: 3, shouldRetry: isTimeout) {
            try server.fetchProfile(id: id)
        }
        print("  got \(profile) after \(server.calls) calls")
    } catch {
        print("  gave up: \(error) after \(server.calls) calls")
    }
}
```

```output
two timeouts
  attempt 1 failed: timeout, retrying
  attempt 2 failed: timeout, retrying
  got profile 7 after 3 calls
five timeouts
  attempt 1 failed: timeout, retrying
  attempt 2 failed: timeout, retrying
  gave up: timeout after 3 calls
not found
  gave up: notFound after 1 calls
```

Line by line through `retry`:

1. `precondition(attempts >= 1, …)`: asking for zero attempts is a programmer error, not something to throw.
2. The loop runs `attempts - 1` times. Each time, a success returns immediately.
3. **`catch where shouldRetry(error)`** is a catch clause with only a `where` condition. It catches the error **only if** it's worth retrying. Any other error isn't caught here, so it propagates out of `retry` right away. That's why "not found" gives up after one call.
4. The last attempt is outside the loop, with plain `try`. If it fails, its error goes to the caller. No error is invented or lost, and there's no "last error" variable to unwrap.
5. `retry` is `rethrows` (lesson 5): it only throws what the operation throws.

The limit matters. A retry loop without one turns a server outage into an app that hangs forever and hammers the server while it's down. Real apps also **wait** between attempts, longer each time, which needs `async`/`await` from the concurrency module.

## Falling back

When the primary source fails and there's a reasonable alternative, use it, and record that you did:

```swift
enum RatesError: Error {
    case offline
    case malformed(String)
}

final class EventLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

struct RatesService {
    let online: Bool
    let cachedRate: Double?
    let log: EventLog

    func fetchLiveRate() throws -> Double {
        guard online else {
            throw RatesError.offline
        }
        return 1.09
    }

    func euroToDollar() -> (rate: Double, isLive: Bool) {
        do {
            return (try fetchLiveRate(), true)
        } catch {
            log.record("live rate failed: \(error)")
        }
        if let cachedRate {
            log.record("using cached rate")
            return (cachedRate, false)
        }
        log.record("no cache, using default rate")
        return (1.0, false)
    }
}

let log = EventLog()
for service in [
    RatesService(online: true, cachedRate: 1.05, log: log),
    RatesService(online: false, cachedRate: 1.05, log: log),
    RatesService(online: false, cachedRate: nil, log: log),
] {
    let result = service.euroToDollar()
    print("rate \(result.rate)\(result.isLive ? "" : " (not live)")")
}
print(log.entries)
```

```output
rate 1.09
rate 1.05 (not live)
rate 1.0 (not live)
["live rate failed: offline", "using cached rate", "live rate failed: offline", "no cache, using default rate"]
```

Three details make this a good fallback rather than a hidden failure:

1. **The caller knows.** `isLive` is returned with the rate, so the screen can say "rates from yesterday". A fallback that pretends to be live data is lying to the user.
2. **The log knows.** Each step down the chain is recorded with the reason.
3. **The default is honest about what it is.** A rate of 1.0 is a guess. For money, you might decide there **is** no acceptable default and throw instead. That's a product decision, not a coding one: make it on purpose.

## Logging what you swallow

Every `catch` that doesn't rethrow is **the end of the line** for that error. If it doesn't show the error to the user or write it to a log, nobody will ever know it happened. Compare:

```swift
enum SaveError: Error {
    case diskFull
}

final class EventLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

func saveDraft(_ text: String) throws {
    throw SaveError.diskFull
}

let log = EventLog()

// Silent: the draft is lost and there's no trace.
do {
    try saveDraft("Dear Ana,")
} catch {
}

// Recorded: same behavior for the user, but there's evidence.
do {
    try saveDraft("Dear Leo,")
} catch {
    log.record("autosave failed for draft of 9 characters: \(error)")
}

print(log.entries)
```

```output
["autosave failed for draft of 9 characters: diskFull"]
```

Autosave failing quietly might be acceptable for the user in the moment, since they'll save manually. But when a support ticket says "my drafts disappear", the second version leaves something to find. In an app you'd use a real logger instead of an array (Apple's `Logger`, from the `os` framework); the rule is the same. Include enough context to act on: which operation, which item, and the error.

> [!tip] A quick audit
> Search a project for `catch {` and `try?`. Each one should either show the problem, log it, or carry a comment saying why ignoring it is correct.

## Putting it together: an order pipeline

A program that uses the whole module. A shop receives orders as text lines, `SKU,quantity,card`. Each line goes through three steps:

1. **Validate** the line: three fields, quantity a whole number from 1 to 20. Validation errors, typed.
2. **Reserve** stock and compute the total. Domain errors: unknown product, not enough stock.
3. **Charge** the card through a payment gateway that sometimes times out. Infrastructure errors: retry timeouts up to 3 attempts; a decline isn't retried.

One bad line must not stop the batch. Every line gets an outcome, and if payment fails after stock was reserved, the stock goes back.

```swift
enum LineError: Error {
    case wrongFieldCount(Int)
    case badQuantity(String)
}

enum OrderProblem: Error {
    case unknownProduct(String)
    case outOfStock(sku: String, available: Int)
}

enum GatewayError: Error {
    case timeout
    case declined
}

enum PipelineError: Error {
    case invalidLine(LineError)
    case rejected(OrderProblem)
    case paymentFailed(GatewayError)

    var message: String {
        switch self {
        case .invalidLine(.wrongFieldCount(let count)):
            return "invalid line: expected 3 fields, found \(count)"
        case .invalidLine(.badQuantity(let text)):
            return "invalid line: quantity \"\(text)\" must be a whole number from 1 to 20"
        case .rejected(.unknownProduct(let sku)):
            return "rejected: no product \(sku)"
        case .rejected(.outOfStock(let sku, let available)):
            return "rejected: only \(available) \(sku) left"
        case .paymentFailed(.declined):
            return "payment declined"
        case .paymentFailed(.timeout):
            return "payment service unavailable, try again later"
        }
    }
}

struct OrderLine {
    let sku: String
    let quantity: Int
    let card: String
}

func parseLine(_ line: String) throws(LineError) -> OrderLine {
    let fields = line.split(separator: ",").map { String($0) }
    guard fields.count == 3 else {
        throw .wrongFieldCount(fields.count)
    }
    guard let quantity = Int(fields[1]), quantity >= 1, quantity <= 20 else {
        throw .badQuantity(fields[1])
    }
    return OrderLine(sku: fields[0], quantity: quantity, card: fields[2])
}

final class EventLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

final class Warehouse {
    private let prices: [String: Int]
    private var stock: [String: Int]

    init(prices: [String: Int], stock: [String: Int]) {
        self.prices = prices
        self.stock = stock
    }

    func reserve(_ sku: String, quantity: Int) throws(OrderProblem) -> Int {
        guard let price = prices[sku] else {
            throw .unknownProduct(sku)
        }
        let available = stock[sku, default: 0]
        guard available >= quantity else {
            throw .outOfStock(sku: sku, available: available)
        }
        stock[sku] = available - quantity
        return price * quantity
    }

    func release(_ sku: String, quantity: Int) {
        stock[sku, default: 0] += quantity
    }

    func available(_ sku: String) -> Int {
        stock[sku, default: 0]
    }
}

final class FlakyGateway {
    private var timeoutsLeft: [String: Int]
    private var receipts = 0

    init(timeoutsLeft: [String: Int]) {
        self.timeoutsLeft = timeoutsLeft
    }

    func charge(card: String, cents: Int) throws(GatewayError) -> String {
        if card == "0000" {
            throw .declined
        }
        if timeoutsLeft[card, default: 0] > 0 {
            timeoutsLeft[card, default: 0] -= 1
            throw .timeout
        }
        receipts += 1
        return "R\(receipts)-\(cents)"
    }
}

func retry<T>(
    attempts: Int,
    log: EventLog,
    shouldRetry: (any Error) -> Bool,
    _ operation: () throws -> T
) rethrows -> T {
    precondition(attempts >= 1, "attempts must be at least 1")
    for attempt in 1..<attempts {
        do {
            return try operation()
        } catch where shouldRetry(error) {
            log.record("attempt \(attempt) failed (\(error)), retrying")
        }
    }
    return try operation()
}

struct OrderPipeline {
    let warehouse: Warehouse
    let gateway: FlakyGateway
    let log: EventLog

    func process(_ line: String) -> Result<String, PipelineError> {
        let order: OrderLine
        do {
            order = try parseLine(line)
        } catch {
            return .failure(.invalidLine(error))
        }

        let total: Int
        do {
            total = try warehouse.reserve(order.sku, quantity: order.quantity)
        } catch {
            return .failure(.rejected(error))
        }

        var paid = false
        defer {
            if !paid {
                warehouse.release(order.sku, quantity: order.quantity)
                log.record("released \(order.quantity) \(order.sku)")
            }
        }

        do {
            let receipt = try retry(attempts: 3, log: log, shouldRetry: isTransient) {
                try gateway.charge(card: order.card, cents: total)
            }
            paid = true
            return .success(receipt)
        } catch let error as GatewayError {
            return .failure(.paymentFailed(error))
        } catch {
            log.record("unexpected error: \(error)")
            return .failure(.paymentFailed(.timeout))
        }
    }
}

func isTransient(_ error: any Error) -> Bool {
    if case GatewayError.timeout = error {
        return true
    }
    return false
}

let pipeline = OrderPipeline(
    warehouse: Warehouse(
        prices: ["MUG": 1200, "BEANS": 950],
        stock: ["MUG": 5, "BEANS": 2]
    ),
    gateway: FlakyGateway(timeoutsLeft: ["4242": 1, "5555": 5]),
    log: EventLog()
)

let lines = [
    "MUG,2,4242",
    "BEANS,three,4242",
    "TEA,1,4242",
    "BEANS,4,4242",
    "MUG,1,0000",
    "BEANS,2,5555",
    "MUG,1",
    "BEANS,2,4242",
]

var processed = 0
for (index, line) in lines.enumerated() {
    switch pipeline.process(line) {
    case .success(let receipt):
        processed += 1
        print("line \(index + 1): ok, receipt \(receipt)")
    case .failure(let error):
        print("line \(index + 1): \(error.message)")
    }
}

print("--- \(processed) of \(lines.count) processed")
print("stock: MUG \(pipeline.warehouse.available("MUG")), BEANS \(pipeline.warehouse.available("BEANS"))")
print("--- log")
for entry in pipeline.log.entries {
    print(entry)
}
```

```output
line 1: ok, receipt R1-2400
line 2: invalid line: quantity "three" must be a whole number from 1 to 20
line 3: rejected: no product TEA
line 4: rejected: only 2 BEANS left
line 5: payment declined
line 6: payment service unavailable, try again later
line 7: invalid line: expected 3 fields, found 2
line 8: ok, receipt R2-1900
--- 2 of 8 processed
stock: MUG 3, BEANS 0
--- log
attempt 1 failed (timeout), retrying
released 1 MUG
attempt 1 failed (timeout), retrying
attempt 2 failed (timeout), retrying
released 2 BEANS
```

Walk through the design:

1. **Three error types for three layers.** `LineError` is validation, `OrderProblem` is the shop's rules, `GatewayError` is plumbing. Each step throws only its own type, typed, so each step's caller can switch exhaustively.
2. **One error type for the report.** `PipelineError` wraps the three, so the loop at the bottom deals with one type. Its `message` switches over **nested** patterns, `.invalidLine(.badQuantity(let text))`, covering every combination without a `default`. Add a case anywhere and this switch stops compiling.
3. **`process` returns a `Result`** instead of throwing. Every line gets an outcome and the loop never stops early: the batch keeps going after line 2's bad quantity (lesson 4).
4. **Each step's `do` block holds one call.** That keeps `error` typed in each `catch` (one error type per `do`), so `.invalidLine(error)` and `.rejected(error)` need no casts. `let order: OrderLine` declared before the `do` is assigned inside it; the `catch` always returns, so Swift knows `order` has a value afterwards.
5. **`defer` rolls back.** After stock is reserved, `var paid = false` and a `defer` that releases the stock unless `paid` became true. The `defer` runs on every exit from `process`: the declined card on line 5 and the repeated timeouts on line 6 both release their stock, and the log shows it. Without the rollback, line 8 would find no beans left.
6. **Retry only what's transient.** `isTransient` says yes to `.timeout` only. Line 1 succeeds on its second attempt; line 6 gives up after three; line 5's decline is never retried.
7. **The last `catch` that "can't happen" logs.** `retry` takes an untyped closure (closures are inferred as plain `throws`, lesson 4), so the compiler can't know only `GatewayError` comes out. The final catch-all handles that case honestly: it logs, and reports the payment as unavailable instead of crashing.
8. **Classes where state is shared**, structs elsewhere (Module 10). `Warehouse`, `FlakyGateway` and `EventLog` change over the run and are shared with the pipeline, so they're `final class`es with `private` state. `OrderLine` and `OrderPipeline` are plain values.

Notice what's **not** in the program: no `try!`, no empty `catch`, no `try?` that hides a failure the shop owner would care about. Every error ends up either in the report, in the log, or both.

## Common mistakes

> [!error] Crashing on recoverable errors
> `fatalError("Network down")` or a `precondition` on user input turns a bad moment into a crash. Those are recoverable: throw and handle.

> [!error] Throwing for programmer errors
> A function that throws `.invalidPageSize` when your own code passes 0 makes every caller write a `catch` for a bug. Use `precondition` and fix the caller.

> [!error] Retrying everything, forever
> Retrying validation errors or declined cards wastes time and can cause duplicates; retrying without a limit hangs the app. Retry only transient errors, a fixed number of times.

> [!error] Silent fallbacks
> Returning cached data as if it were live, without telling the caller or the log, hides outages. Return whether the value is fresh, and record the fallback.

> [!error] One error stopping a whole batch
> A `try` inside a loop in a `throws` function stops at the first bad item. Handle errors per item in the loop, or collect a `Result` per item.

> [!error] Forgetting to undo partial work
> If step 2 succeeds and step 3 fails, step 2's effects may need undoing. A flag plus `defer` makes every exit path do it.

````exercise
id: m12-l06-e1
type: comprehension
prompt: "Which of these failures should stop the program with precondition or fatalError instead of being thrown?"
choices:
  - text: "The JSON from the server is missing the price field."
    correct: false
    why: "The server is outside your code. That's a recoverable infrastructure error."
  - text: "The user types a birth date in the future."
    correct: false
    why: "Input from a person: a validation error with a clear message."
  - text: "A private helper receives a negative index, and every caller in the module computes that index from count - 1 of a non-empty array the helper itself created."
    correct: true
    why: "It can only happen if the code is wrong. Stopping at the broken assumption is the most useful thing to do."
  - text: "The disk is full when saving a photo."
    correct: false
    why: "The environment caused it. Throw, tell the user, maybe offer to free space."
solution: |
  **The negative index from your own code.** Every source of that value is code you wrote and control, so a negative index means there's a bug. A `precondition` stops the program where the assumption broke, with a message, which is much easier to debug than wrong data later. The other three are caused by the outside world (a server, a person, the disk), and a correct program has to expect them.
````

````exercise
id: m12-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum UploadError: Error {
      case busy
      case tooLarge
  }

  final class Uploader {
      var outcomes: [UploadError?]
      private(set) var calls = 0

      init(outcomes: [UploadError?]) {
          self.outcomes = outcomes
      }

      func upload() throws -> String {
          calls += 1
          let outcome = outcomes.removeFirst()
          if let outcome {
              throw outcome
          }
          return "done"
      }
  }

  func retry<T>(attempts: Int, _ operation: () throws -> T) rethrows -> T {
      for _ in 1..<attempts {
          do {
              return try operation()
          } catch UploadError.busy {
              print("busy, retrying")
          }
      }
      return try operation()
  }

  let first = Uploader(outcomes: [.busy, nil])
  let second = Uploader(outcomes: [.busy, .tooLarge, nil])

  for uploader in [first, second] {
      do {
          print(try retry(attempts: 4) { try uploader.upload() }, uploader.calls)
      } catch {
          print("failed: \(error)", uploader.calls)
      }
  }
output: |
  busy, retrying
  done 2
  busy, retrying
  failed: tooLarge 2
hints:
  - "Which errors does the catch clause in retry match?"
  - "An error the clause doesn't match propagates out of retry immediately."
solution: |
  ```output
  busy, retrying
  done 2
  busy, retrying
  failed: tooLarge 2
  ```

  The first uploader is busy once, then succeeds on the second call. The second uploader is busy, then throws `tooLarge`. The catch clause only matches `UploadError.busy`, so `tooLarge` isn't caught inside the loop; it propagates out of `retry` straight away, after 2 calls, even though 4 attempts were allowed. That's the behavior you want: a file that's too large won't get smaller on the third try.
````

````exercise
id: m12-l06-e3
type: find-errors
prompt: "This sync code runs every few minutes. Which statements are true?"
code: |
  func syncContacts() {
      var attempt = 0
      while true {
          do {
              try uploadContacts()
              break
          } catch {
              attempt += 1
          }
      }
      let photos = try? downloadPhotos()
      for photo in photos ?? [] {
          save(photo)
      }
      if contacts.isEmpty {
          fatalError("No contacts to sync")
      }
  }
choices:
  - text: "The retry loop has no limit, so a server outage makes it loop forever."
    correct: true
    why: "while true with no exit except success. Add a maximum number of attempts."
  - text: "It retries every error, including ones retrying can't fix, like an invalid record."
    correct: true
    why: "The catch matches everything. Retry only transient errors."
  - text: "A failed photo download is silently ignored: no log and no signal to the user."
    correct: true
    why: "try? discards the reason and ?? [] makes failure look like 'no photos'."
  - text: "fatalError is wrong here: having no contacts is a normal situation, not a bug."
    correct: true
    why: "A new user has no contacts. That's an ordinary state; return early instead."
  - text: "break can't be used inside a do block."
    correct: false
    why: "break inside do exits the enclosing while loop, as intended."
rubric:
  - I found the unbounded loop and the retry-everything catch.
  - I found the silent try? on photos.
  - I found the fatalError on a normal state.
solution: |
  Four real problems. The loop retries **forever** and retries **every** error: a server outage or a malformed contact turns into an endless loop. Limit the attempts and only retry transient errors, with a helper like the lesson's `retry`. The photo download failure disappears: `try? … ?? []` makes "couldn't download" look like "no photos". Catch it and log it at least. And `fatalError` on an empty contact list crashes the app for every new user; an empty list is a normal state, so return early.
````

````exercise
id: m12-l06-e4
type: solve
prompt: |
  Write a weather lookup with a fallback chain and a log.

  - `enum WeatherError: Error { case offline, unknownCity(String) }`.
  - `func liveTemperature(in city: String, online: Bool) throws -> Int` that throws `offline` when `online` is false, `unknownCity(city)` when the city isn't `"Madrid"` or `"Oslo"`, and otherwise returns 31 for Madrid and 4 for Oslo.
  - `func temperatureText(in city: String, online: Bool, cache: [String: Int], log: inout [String]) -> String` that:
    - returns `"\(t)°C"` from the live source when it works,
    - on `offline`, logs `"offline, using cache for \(city)"` and returns `"\(t)°C (cached)"` if the cache has the city, otherwise logs `"no cache for \(city)"` and returns `"unavailable"`,
    - on `unknownCity`, logs nothing and returns `"unknown city"` (retrying or caching can't fix a typo).

  This must print:

  ```output
  31°C
  4°C (cached)
  unavailable
  unknown city
  ["offline, using cache for Oslo", "no cache for Madrid"]
  ```

  from:

  ```swift
  var log: [String] = []
  let cache = ["Oslo": 4]
  print(temperatureText(in: "Madrid", online: true, cache: cache, log: &log))
  print(temperatureText(in: "Oslo", online: false, cache: cache, log: &log))
  print(temperatureText(in: "Madrid", online: false, cache: cache, log: &log))
  print(temperatureText(in: "Atlantis", online: true, cache: cache, log: &log))
  print(log)
  ```
starter: |
  enum WeatherError: Error {
      case offline
      case unknownCity(String)
  }
hints:
  - "Use do { return \"\\(try liveTemperature(…))°C\" } with catch WeatherError.offline and catch WeatherError.unknownCity."
  - "Inside the offline clause, if let cached = cache[city] { … }."
  - "temperatureText isn't throws, so it needs a final plain catch too."
rubric:
  - The live source is tried first.
  - Only offline falls back to the cache, and each fallback step is logged.
  - unknownCity isn't retried or cached.
  - The function isn't throws and ends with a catch-all.
  - The output matches exactly.
solution: |
  ```swift
  enum WeatherError: Error {
      case offline
      case unknownCity(String)
  }

  func liveTemperature(in city: String, online: Bool) throws -> Int {
      guard online else {
          throw WeatherError.offline
      }
      switch city {
      case "Madrid": return 31
      case "Oslo": return 4
      default: throw WeatherError.unknownCity(city)
      }
  }

  func temperatureText(in city: String, online: Bool, cache: [String: Int], log: inout [String]) -> String {
      do {
          return "\(try liveTemperature(in: city, online: online))°C"
      } catch WeatherError.offline {
          if let cached = cache[city] {
              log.append("offline, using cache for \(city)")
              return "\(cached)°C (cached)"
          }
          log.append("no cache for \(city)")
          return "unavailable"
      } catch WeatherError.unknownCity {
          return "unknown city"
      } catch {
          log.append("unexpected: \(error)")
          return "unavailable"
      }
  }

  var log: [String] = []
  let cache = ["Oslo": 4]
  print(temperatureText(in: "Madrid", online: true, cache: cache, log: &log))
  print(temperatureText(in: "Oslo", online: false, cache: cache, log: &log))
  print(temperatureText(in: "Madrid", online: false, cache: cache, log: &log))
  print(temperatureText(in: "Atlantis", online: true, cache: cache, log: &log))
  print(log)
  ```

  ```output
  31°C
  4°C (cached)
  unavailable
  unknown city
  ["offline, using cache for Oslo", "no cache for Madrid"]
  ```

  The live value is preferred. Only `offline` triggers the fallback, since the cache helps with connectivity, not with a misspelled city. "(cached)" tells the user the value may be old, and the log records each time the fallback was needed. The final catch-all is required because `liveTemperature` is plain `throws`; it logs instead of hiding. `log` is an `inout` parameter (Module 6), so the function appends to the caller's array.
````

````exercise
id: m12-l06-e5
type: solve
prompt: |
  Write a batch processor for signup rows that keeps going after bad rows and rolls back a counter when a later step fails.

  - `enum RowError: Error { case missingEmail(row: Int), duplicate(String) }`.
  - `final class Registry` with `private(set) var emails: Set<String> = []`, `private(set) var reserved = 0`, `func reserveSeat()` (adds 1 to `reserved`), `func releaseSeat()` (subtracts 1), and `func add(_ email: String) throws` that throws `RowError.duplicate(email)` if the email is already in `emails`, otherwise inserts it.
  - `func register(_ email: String, row: Int, in registry: Registry) throws` that throws `missingEmail(row:)` for an empty email; otherwise reserves a seat, uses `defer` to release it if adding fails, and adds the email.
  - A loop over `["ana@x.com", "", "leo@x.com", "ana@x.com"]` (rows numbered from 1) that prints `"row N: ok"` or `"row N: <error>"`, then prints `reserved` and the number of emails.

  Expected output:

  ```output
  row 1: ok
  row 2: missingEmail(row: 2)
  row 3: ok
  row 4: duplicate("ana@x.com")
  reserved 2, emails 2
  ```
starter: |
  enum RowError: Error {
      case missingEmail(row: Int)
      case duplicate(String)
  }
hints:
  - "In register: guard !email.isEmpty else { throw … }, then registry.reserveSeat(), then var added = false and defer { if !added { registry.releaseSeat() } }."
  - "try registry.add(email), then added = true."
  - "In the loop, use for (index, email) in rows.enumerated() and a do-catch per row."
rubric:
  - Each row is handled in its own do-catch, so the batch continues.
  - The seat reservation is undone with defer when add throws.
  - The empty-email check happens before any seat is reserved.
  - The output matches exactly, with reserved equal to the number of emails.
solution: |
  ```swift
  enum RowError: Error {
      case missingEmail(row: Int)
      case duplicate(String)
  }

  final class Registry {
      private(set) var emails: Set<String> = []
      private(set) var reserved = 0

      func reserveSeat() {
          reserved += 1
      }

      func releaseSeat() {
          reserved -= 1
      }

      func add(_ email: String) throws {
          guard !emails.contains(email) else {
              throw RowError.duplicate(email)
          }
          emails.insert(email)
      }
  }

  func register(_ email: String, row: Int, in registry: Registry) throws {
      guard !email.isEmpty else {
          throw RowError.missingEmail(row: row)
      }
      registry.reserveSeat()
      var added = false
      defer {
          if !added {
              registry.releaseSeat()
          }
      }
      try registry.add(email)
      added = true
  }

  let registry = Registry()
  let rows = ["ana@x.com", "", "leo@x.com", "ana@x.com"]
  for (index, email) in rows.enumerated() {
      do {
          try register(email, row: index + 1, in: registry)
          print("row \(index + 1): ok")
      } catch {
          print("row \(index + 1): \(error)")
      }
  }
  print("reserved \(registry.reserved), emails \(registry.emails.count)")
  ```

  ```output
  row 1: ok
  row 2: missingEmail(row: 2)
  row 3: ok
  row 4: duplicate("ana@x.com")
  reserved 2, emails 2
  ```

  Row 4 reserves a seat, then `add` throws. The `defer` sees `added == false` and releases the seat, so `reserved` matches the real number of registrations. Row 2 fails before reserving anything, so there's nothing to undo. The loop handles each row in its own `do`/`catch`, which is what keeps one bad row from stopping the rest.
````

````exercise
id: m12-l06-e6
type: design
prompt: |
  Design the error handling for a "send money" feature in a banking app. The flow: validate the form (amount, recipient IBAN), check the balance and daily limit, call the bank's transfer API (which can time out, return "rejected by recipient bank", or return a malformed response), then save a receipt locally (which can fail if the disk is full). For each failure, say: which kind it is (validation, domain, infrastructure, programmer error), whether to retry, what the user sees, and what gets logged. Pay special attention to the timeout: is it safe to retry a money transfer?
rubric:
  - Classifies form problems as validation errors shown next to the fields, all at once.
  - Classifies balance and limit as domain errors with specific messages.
  - Classifies timeout, malformed response and disk full as infrastructure errors, logged with details.
  - Recognizes that blindly retrying a transfer after a timeout could send money twice, and proposes checking the transfer status (or an idempotency key) before retrying.
  - Treats a failed receipt save as not undoing the transfer, and logs it.
solution: |
  **Validation** (amount empty, not a number, zero or negative; IBAN malformed): collect all problems and show them next to the fields, using `LocalizedError` messages. No retry, nothing to log beyond normal analytics.

  **Domain** (insufficient balance, daily limit reached, rejected by recipient bank): specific messages, such as "You can send up to €500 more today". No retry: the answer won't change. Log at a low level.

  **Infrastructure:**

  - *Malformed response:* the app doesn't know whether the transfer happened. Show "We couldn't confirm the transfer. Check your activity before trying again." Log the response details.
  - *Timeout:* the dangerous one. A timeout means "no answer", not "didn't happen". The bank may have executed the transfer and the reply got lost. **Blindly retrying could send the money twice.** Before retrying, ask the API for the status of this transfer (using an ID the app generated before the first attempt, often called an idempotency key, which lets the bank recognize a repeat). Retry only if the bank confirms it never received it, and only a limited number of times. Otherwise treat it like the malformed response.
  - *Disk full when saving the receipt:* the money **has** moved, so this must not be reported as a failed transfer. Show success, log the save failure, and fetch the receipt from the server later.

  **Programmer errors:** for example, the transfer function receiving an amount that the validation step should already have rejected. Use a `precondition` in the internal function, since validation is supposed to guarantee it.

  The structure: `TransferFormError` (validation, collected), `TransferError` (domain plus `.unconfirmed(underlying:)` and `.unavailable(underlying:)` translated from the API layer), and a `send` function that only retries after a status check confirms the transfer didn't happen.
````

## Summary

- Throw for failures the outside world causes: input, environment, business rules. Stop with `precondition` or `fatalError` only for programmer errors, which can't happen unless the code is wrong. When unsure, throw.
- Retry only transient errors, with a limit. `catch where shouldRetry(error)` retries the right errors and lets the rest propagate at once.
- Fall back to a cache or default when there's a reasonable one, tell the caller it's not the real thing, and log it.
- Every `catch` that doesn't rethrow must show or log the error. Audit `catch {` and `try?`.
- Handle errors per item in batches, with a `do`/`catch` or a `Result` per item, so one failure doesn't stop the rest.
- Use a flag and `defer` to undo partial work when a later step fails.
- Translate errors into one report type at the top, and switch over it exhaustively with nested patterns.
