---
id: m11-l05
title: "@escaping and @autoclosure"
description: You learn why Swift assumes closure parameters don't outlive the call, mark the ones that do with @escaping, read the errors you get when you try to store a non-escaping closure, see that optional closures are already escaping, write and call completion handlers, and use @autoclosure the way &&, ?? and assert do.
module: m11
order: 5
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l04]
objectives:
  - Explain the difference between an escaping and a non-escaping closure parameter.
  - Mark a parameter @escaping when the function stores the closure or calls it after returning.
  - Read the compiler errors for storing or forwarding a non-escaping closure.
  - Explain why an optional closure parameter is already escaping.
  - Write a function with a completion handler and trace the order in which its code runs.
  - Write an @autoclosure parameter and explain how &&, ?? and assert use the same feature.
terms:
  - term: Non-escaping closure
    definition: "The default for closure parameters: the closure can only be called while the function runs. The function can't store it or hand it to anything that might keep it."
  - term: Escaping closure
    definition: "A closure parameter marked @escaping. The function may store it or call it after the function has returned."
  - term: Completion handler
    definition: "An escaping closure a function calls when slow work finishes, passing the result. The classic pattern for asynchronous APIs before async/await."
  - term: "@autoclosure"
    definition: "An attribute on a parameter of type () -> T that lets the caller pass a plain expression. Swift wraps it in a closure, so the function decides whether and when to evaluate it."
mastery:
  - Fix "assigning non-escaping parameter … to an '@escaping' closure" by adding @escaping.
  - "Say why func onTap(_ handler: (() -> Void)?) can store handler without @escaping."
  - Write a function with an @escaping completion handler and predict the order of the prints around it.
  - "Fix \"escaping closure captures mutating 'self' parameter\" by moving the state into a class or restructuring."
  - Write a logging function with an @autoclosure message that isn't built when logging is off.
  - Explain why the right side of && and ?? may never run.
resources: [swift-book-closures, swift-book-functions]
cards:
  - id: m11-l05-c1
    front: "When does a closure parameter need @escaping?"
    back: "When the function stores it (in a property, an array, a dictionary) or passes it to something that might call it after the function returns."
  - id: m11-l05-c2
    front: "Is a parameter of type (() -> Void)? escaping?"
    back: "Yes, implicitly. The closure is wrapped in an Optional, and Swift treats it as escaping. Writing @escaping on it is an error: \"closure is already escaping in optional type argument\"."
  - id: m11-l05-c3
    front: "What does @autoclosure do?"
    back: "It lets the caller write a plain expression where a () -> T is expected. The function decides whether and when to evaluate it, as the right side of && and ?? do."
  - id: m11-l05-c4
    front: "Why can a non-escaping closure in a class method use properties without self.?"
    back: "It can't outlive the call, so it can't create a reference cycle. Swift only demands explicit self in escaping closures, where the capture matters."
---

## The idea in one sentence

By default Swift assumes a closure you pass in is used **during** the call and then forgotten; `@escaping` says the function will keep it and may call it later, and `@autoclosure` turns an argument expression into a closure so the function decides whether to evaluate it at all.

## Non-escaping by default

Every closure parameter you've written so far was **non-escaping**: the function could call it, but only while the function itself was running. `map`, `filter` and `sorted(by:)` all work that way: they call your closure for each element, and by the time they return, they're done with it.

```swift
func repeatTwice(_ action: () -> Void) {
    action()
    action()
}

var greetings = 0
repeatTwice {
    greetings += 1
}
print(greetings)
```

```output
2
```

That's a promise the compiler checks. Because the closure can't outlive `repeatTwice`, Swift knows that whatever it captures only needs to stay alive for the duration of the call. That allows optimizations (the captured context doesn't have to go on the heap) and rules out a whole class of reference cycles.

The promise breaks the moment the function tries to keep the closure:

```swift no-compile assigning non-escaping parameter 'handler' to an '@escaping' closure
final class Button {
    var action: () -> Void = {}

    func onTap(_ handler: () -> Void) {
        action = handler
    }
}
```

Swift 6.3: `error: assigning non-escaping parameter 'handler' to an '@escaping' closure`, with a note: "parameter 'handler' is implicitly non-escaping". Storing it in a property means it lives as long as the button does, long after `onTap` returns.

Putting it in an array is the same thing, with a stranger message:

```swift no-compile may allow it to escape
var listeners: [() -> Void] = []

func addListener(_ listener: () -> Void) {
    listeners.append(listener)
}
```

Swift 6.3: `error: converting non-escaping parameter 'listener' to generic parameter 'Element' may allow it to escape`. `append` is generic over the array's `Element` (lesson 2), and a generic parameter could be stored anywhere, so a non-escaping closure isn't allowed into it.

## @escaping

Mark the parameter `@escaping` and both work:

```swift
final class Button {
    let title: String
    private var handlers: [() -> Void] = []

    init(title: String) {
        self.title = title
    }

    func onTap(_ handler: @escaping () -> Void) {
        handlers.append(handler)
    }

    func simulateTap() {
        print("Tapped \(title)")
        for handler in handlers {
            handler()
        }
    }
}

var saves = 0
let save = Button(title: "Save")
save.onTap { saves += 1 }
save.onTap { print("Saved \(saves) time(s)") }

save.simulateTap()
save.simulateTap()
```

```output
Tapped Save
Saved 1 time(s)
Tapped Save
Saved 2 time(s)
```

1. `@escaping` goes before the function type: `_ handler: @escaping () -> Void`. It's part of the parameter's type, not a modifier on the function.
2. `onTap` stores the closure and returns. Nothing runs yet.
3. `simulateTap` calls every stored handler, possibly long after `onTap` returned. That's the "escape": the closure outlived the call that received it.
4. The first closure captures `saves` (lesson 4) and changes it; the second reads it. Handlers run in the order they were added.

This is how UIKit buttons, notifications and timers work: you hand over a closure now, and the system calls it when something happens.

### Forwarding a closure needs the same promise

A non-escaping closure can't be passed on to a parameter that's `@escaping`:

```swift no-compile passing non-escaping parameter 'action' to function expecting an '@escaping' closure
final class Button {
    private var handlers: [() -> Void] = []

    func onTap(_ handler: @escaping () -> Void) {
        handlers.append(handler)
    }
}

func wire(_ button: Button, to action: () -> Void) {
    button.onTap(action)
}
```

`wire` promised its callers it wouldn't keep `action`, but `onTap` will. The fix is to make `wire`'s parameter `@escaping` too, so the promise is honest all the way up.

### Optional closures are already escaping

A closure parameter wrapped in an optional is treated as escaping, with no attribute:

```swift
final class Alert {
    private var onDismiss: (() -> Void)?

    func show(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        print("Alert shown")
    }

    func dismiss() {
        print("Alert dismissed")
        onDismiss?()
    }
}

let alert = Alert()
alert.show { print("Back to the list") }
alert.dismiss()

let quiet = Alert()
quiet.show()
quiet.dismiss()
```

```output
Alert shown
Alert dismissed
Back to the list
Alert shown
Alert dismissed
```

The closure is stored inside an `Optional` value, and the non-escaping rule only applies to a closure that's directly a parameter. If you add `@escaping` to it anyway, Swift 6.3 refuses: `error: closure is already escaping in optional type argument`. Optional closures are common for "maybe tell me when you're done" parameters, often with a `nil` default, as here.

## Escaping closures and self

Lesson 4 showed that a closure stored in a class must write `self.` explicitly. That rule only applies to **escaping** closures. A non-escaping one can't outlive the call, so it can't form a cycle, and Swift lets you skip `self`:

```swift
final class Game {
    var score = 0

    func perform(_ body: () -> Void) {
        body()
    }

    func play() {
        perform { score += 10 }
    }
}

let game = Game()
game.play()
print(game.score)
```

```output
10
```

That's the real reason for the explicit-`self` error: it shows up exactly where a cycle is possible, so you look twice and decide whether you need `[weak self]`.

For **structs**, an escaping closure can't capture `self` inside a `mutating` method at all:

```swift no-compile escaping closure captures mutating 'self' parameter
struct Counter {
    var count = 0
    var handlers: [() -> Void] = []

    mutating func registerIncrement() {
        handlers.append { self.count += 1 }
    }
}
```

Inside a `mutating` method, `self` is like an `inout` parameter: it only exists for the duration of the call. A closure that runs later would be changing a struct that may have been copied or moved since. When something needs to be changed later by a stored closure, it usually belongs in a class, which has one shared identity.

## Completion handlers

The classic use of `@escaping` is the **completion handler**. A function starts slow work (a network request, reading a big file), returns right away so the app doesn't freeze, and calls the handler with the result when the work finishes.

Real networking needs frameworks and concurrency you haven't met. This fake client keeps pending requests in an array and finishes them when you call `deliverPending()`, which is enough to see the shape and the order of events:

```swift
struct User {
    let id: Int
    let name: String
}

final class FakeUserClient {
    private var pending: [() -> Void] = []
    private let names = [1: "Ana", 2: "Bo"]

    func loadUser(id: Int, completion: @escaping (User?) -> Void) {
        print("Requested user \(id)")
        pending.append {
            let user = self.names[id].map { name in User(id: id, name: name) }
            completion(user)
        }
    }

    func deliverPending() {
        let work = pending
        pending = []
        for job in work {
            job()
        }
    }
}

let client = FakeUserClient()
client.loadUser(id: 1) { user in
    print("Loaded: \(user?.name ?? "nobody")")
}
client.loadUser(id: 7) { user in
    print("Loaded: \(user?.name ?? "nobody")")
}
print("Both requests sent")
client.deliverPending()
```

```output
Requested user 1
Requested user 7
Both requests sent
Loaded: Ana
Loaded: nobody
```

Follow the order, because it's the thing that trips people up:

1. `loadUser` prints, stores a job, and **returns immediately**. The completion hasn't run.
2. The second request does the same.
3. `"Both requests sent"` prints before any user is loaded. Code after the call doesn't wait for the result.
4. Later, `deliverPending()` runs the jobs, and each job calls its `completion` with a `User?`. `nil` means there was no such user. (Reporting *why* it failed is the job of errors, Module 12.)

`completion` must be `@escaping` because it's captured by the job closure, which is stored in `pending` and called after `loadUser` has returned. The job captures `self` strongly; that's fine here because the client drops each job once it runs, so no cycle survives.

> [!note] async/await replaces many completion handlers
> Since Swift 5.5, many APIs that took a completion handler have an `async` version: `let user = await client.loadUser(id: 1)`. The code reads top to bottom, and the compiler checks that you handle the result. You'll still meet completion handlers in older code and in some Apple APIs, and you'll learn `async`/`await` in Module 29.

## @autoclosure

Here's a logger with a problem:

```swift
struct Logger {
    var isDebugEnabled = false

    func debug(_ message: String) {
        if isDebugEnabled {
            print("DEBUG: \(message)")
        }
    }
}

func buildReport() -> String {
    print("(building an expensive report)")
    return "42 items in cache"
}

let logger = Logger()
logger.debug(buildReport())
print("done")
```

```output
(building an expensive report)
done
```

Debug logging is off, so nothing is logged, yet the report is still built. Arguments are evaluated before the function is called. You could make the parameter a closure, `() -> String`, but then every caller writes `logger.debug({ buildReport() })`.

`@autoclosure` gets you both: the caller writes a normal expression, and Swift wraps it in a closure for you.

```swift
struct Logger {
    var isDebugEnabled = false

    func debug(_ message: @autoclosure () -> String) {
        if isDebugEnabled {
            print("DEBUG: \(message())")
        }
    }
}

func buildReport() -> String {
    print("(building an expensive report)")
    return "42 items in cache"
}

var logger = Logger()
logger.debug(buildReport())
logger.isDebugEnabled = true
logger.debug(buildReport())
print("done")
```

```output
(building an expensive report)
DEBUG: 42 items in cache
done
```

1. The parameter type is `@autoclosure () -> String`: a closure, but callers pass a `String` expression.
2. Inside, `message()` calls the closure, which evaluates `buildReport()` at that moment.
3. With debug logging off, `message()` is never called, so the report is never built. The first call prints nothing at all.

You've been using this all along. These are the real declarations from the Swift 6.3 standard library (`??` slightly simplified):

```swift illustrative
static func && (lhs: Bool, rhs: @autoclosure () throws -> Bool) rethrows -> Bool
func ?? <T>(optional: T?, defaultValue: @autoclosure () throws -> T) rethrows -> T
func assert(_ condition: @autoclosure () -> Bool,
            _ message: @autoclosure () -> String = String(),
            file: StaticString = #file, line: UInt = #line)
```

- `&&` only evaluates its right side when the left side is `true`. That's **short-circuit evaluation**, and it's not compiler magic: the right side is an autoclosure.
- `??` only evaluates its default when the optional is `nil`, which Module 8 pointed out without saying how.
- `assert` checks a condition in debug builds. In optimized release builds, it doesn't evaluate the condition at all, and the message is only built if the assertion fails.
- `throws` and `rethrows` let these accept expressions that can throw errors, which you'll learn in Module 12.

```swift
func isValidEmail(_ text: String) -> Bool {
    print("checking \(text)")
    return text.contains("@")
}

let input = ""
let fallbackName: String? = "guest"

if !input.isEmpty && isValidEmail(input) {
    print("valid")
}
print(fallbackName ?? "computed default")
assert(fallbackName != nil, "never built unless the assertion fails")
print("end")
```

```output
guest
end
```

`isValidEmail` never runs, because `!input.isEmpty` is `false` and `&&` never calls its right side.

Use `@autoclosure` sparingly in your own code. It hides the fact that an argument might not run, which is surprising for anyone reading the call. It's right when the function is about **deferring** work, like logging and assertions. If the parameter needs `@escaping` too (the function stores the expression to evaluate later), write both: `@autoclosure @escaping () -> String`.

## Common mistakes

> [!error] error: assigning non-escaping parameter 'handler' to an '@escaping' closure
> The function stores a closure parameter. Mark it `@escaping`, and check whether the stored closure creates a cycle with `self`.

> [!error] error: converting non-escaping parameter … to generic parameter 'Element' may allow it to escape
> The same problem when the closure goes into an array or any other generic storage. Same fix.

> [!error] error: passing non-escaping parameter … to function expecting an '@escaping' closure
> You forwarded a closure to an escaping parameter. Make the outer parameter `@escaping` too.

> [!error] error: closure is already escaping in optional type argument
> Remove `@escaping` from an optional closure parameter. It's implicit.

> [!error] error: escaping closure captures mutating 'self' parameter
> A mutating struct method tried to store a closure that changes `self`. Move the state into a class, or return a new value instead of mutating later.

> [!error] Expecting code after a completion-handler call to wait
> Lines after `loadUser(id:completion:)` run before the completion. Put anything that needs the result inside the completion.

````exercise
id: m11-l05-e1
type: comprehension
prompt: "Which of these functions needs `@escaping` on its closure parameter?"
choices:
  - text: "func measure(_ work: () -> Void) that records the time, calls work(), and prints the elapsed time."
    correct: false
    why: "work is called during the function and never stored."
  - text: "func everyItem(_ items: [Int], _ body: (Int) -> Void) that loops and calls body for each item."
    correct: false
    why: "Same as map or filter: the closure is done when the function returns."
  - text: "func schedule(_ job: () -> Void) that appends job to a queue run later by another method."
    correct: true
    why: "Storing it in a queue lets it outlive the call. It must be @escaping."
  - text: "func onFinish(_ handler: (() -> Void)?) that stores handler in a property."
    correct: false
    why: "It does escape, but an optional closure is already escaping. Adding @escaping is an error."
solution: |
  **`schedule`.** The question is always "can the closure be called after the function returns?" `measure` and `everyItem` use their closures and are done. `schedule` stores its job for later, so it needs `@escaping`. `onFinish` escapes too, but because the closure is optional, Swift already treats it as escaping and rejects the attribute.
````

````exercise
id: m11-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Downloader {
      private var finished: [() -> Void] = []

      func download(_ file: String, completion: @escaping (String) -> Void) {
          print("start \(file)")
          finished.append { completion("\(file) done") }
      }

      func finishAll() {
          for job in finished.reversed() {
              job()
          }
          finished = []
      }
  }

  let downloader = Downloader()
  var log: [String] = []
  downloader.download("a.png") { message in log.append(message) }
  downloader.download("b.png") { message in log.append(message) }
  print("log so far: \(log.count)")
  downloader.finishAll()
  print(log)
  downloader.finishAll()
  print(log.count)
output: |
  start a.png
  start b.png
  log so far: 0
  ["b.png done", "a.png done"]
  2
hints:
  - "download stores a job and returns. The completion runs only in finishAll."
  - "Each stored job captured its own file and completion."
  - "finishAll walks the jobs in reverse and then empties the list."
solution: |
  ```output
  start a.png
  start b.png
  log so far: 0
  ["b.png done", "a.png done"]
  2
  ```

  1. Each `download` prints and stores a job. No completion has run, so `log` is empty.
  2. `finishAll` runs the jobs newest first, because of `reversed()`. Each job calls the `completion` it captured, with a message built from the file it captured.
  3. The list is cleared, so the second `finishAll` does nothing and `log` still has 2 entries.
````

````exercise
id: m11-l05-e3
type: fill-in
prompt: |
  Complete the declarations so this compiles and prints the output: an event center that stores handlers by name, and a `check` function whose message is only built when the check fails.
code: |
  final class EventCenter {
      private var handlers: [String: () -> Void] = [:]

      func on(_ name: String, run handler: [[1]] () -> Void) {
          handlers[name] = handler
      }

      func send(_ name: String) {
          handlers[name]?()
      }
  }

  func check(_ condition: Bool, _ message: [[2]] () -> String) {
      if !condition {
          print("Check failed: \(message())")
      }
  }

  let center = EventCenter()
  center.on("login") { print("Welcome back") }
  center.send("login")
  center.send("logout")
  check(1 + 1 == 2, "math is broken")
  check([Int]().isEmpty == false, "expected items")
blanks:
  - id: "1"
    answers: ["@escaping"]
  - id: "2"
    answers: ["@autoclosure"]
solution: |
  ```swift
  final class EventCenter {
      private var handlers: [String: () -> Void] = [:]

      func on(_ name: String, run handler: @escaping () -> Void) {
          handlers[name] = handler
      }

      func send(_ name: String) {
          handlers[name]?()
      }
  }

  func check(_ condition: Bool, _ message: @autoclosure () -> String) {
      if !condition {
          print("Check failed: \(message())")
      }
  }

  let center = EventCenter()
  center.on("login") { print("Welcome back") }
  center.send("login")
  center.send("logout")
  check(1 + 1 == 2, "math is broken")
  check([Int]().isEmpty == false, "expected items")
  ```

  ```output
  Welcome back
  Check failed: expected items
  ```

  `on` stores the handler in a dictionary, so it must be `@escaping`. `handlers[name]?()` looks up an optional closure and calls it only if it exists, which is why `"logout"` does nothing. `check` takes an `@autoclosure` so callers write a plain string and the message is only evaluated when the check fails.
````

````exercise
id: m11-l05-e4
type: find-errors
prompt: Which choices describe real compile errors in this code?
code: |
  final class Timer {
      var onTick: (() -> Void)?
      var ticks = 0

      func start(_ tick: () -> Void) {
          onTick = tick
      }

      func whenDone(_ done: @escaping (() -> Void)?) {
          done?()
      }

      func reset() {
          start { ticks = 0 }
      }
  }

  struct Score {
      var points = 0
      var actions: [() -> Void] = []

      mutating func bonusLater() {
          actions.append { self.points += 5 }
      }
  }
choices:
  - text: "start stores a non-escaping closure in onTick."
    correct: true
    why: "assigning non-escaping parameter 'tick' to an '@escaping' closure."
  - text: "whenDone marks an optional closure @escaping."
    correct: true
    why: "closure is already escaping in optional type argument."
  - text: "bonusLater stores an escaping closure that captures mutating self."
    correct: true
    why: "escaping closure captures mutating 'self' parameter."
  - text: "reset uses ticks without self. inside a closure."
    correct: false
    why: "start's parameter is non-escaping as written, so implicit self is allowed there. (Once you fix start with @escaping, this line does need self., and [weak self] would be wise.)"
rubric:
  - Flags the stored non-escaping closure in start.
  - Flags @escaping on an optional closure.
  - Flags the mutating self capture in the struct.
  - Explains why reset compiles as written but changes once start is fixed.
solution: |
  Three real errors. Fixed, with the consequences followed through:

  ```swift
  final class Timer {
      var onTick: (() -> Void)?
      var ticks = 0

      func start(_ tick: @escaping () -> Void) {
          onTick = tick
      }

      func whenDone(_ done: (() -> Void)?) {
          done?()
      }

      func reset() {
          start { [weak self] in
              self?.ticks = 0
          }
      }
  }

  final class Score {
      var points = 0
      var actions: [() -> Void] = []

      func bonusLater() {
          actions.append { [weak self] in
              self?.points += 5
          }
      }
  }

  let timer = Timer()
  timer.ticks = 3
  timer.reset()
  timer.onTick?()
  timer.whenDone { print("ticks: \(timer.ticks)") }

  let score = Score()
  score.bonusLater()
  score.actions.forEach { action in action() }
  print(score.points)
  ```

  ```output
  ticks: 0
  5
  ```

  Making `start` escaping changes `reset`: now its closure is stored in `onTick`, a property of the same timer, so `self` must be explicit, and `[weak self]` avoids the cycle. `Score` became a class so a stored closure can change it later; with a struct there's no single instance for the closure to change.
````

````exercise
id: m11-l05-e5
type: solve
prompt: |
  Write a `final class TaskQueue` that collects work to run later:

  - `func add(_ name: String, work: @escaping () -> Int)` stores a named job that returns a number.
  - `func runAll(completion: (Int) -> Void)` runs every job in the order added, prints `"<name>: <result>"` for each, empties the queue, and then calls `completion` once with the sum of the results.

  Decide which closure parameters need `@escaping`. Then make this print the output below:

  ```swift
  let queue = TaskQueue()
  var base = 10
  queue.add("double") { base * 2 }
  queue.add("square") { base * base }
  base = 3
  queue.runAll { total in print("total: \(total)") }
  queue.runAll { total in print("total: \(total)") }
  ```

  ```output
  double: 6
  square: 9
  total: 15
  total: 0
  ```
starter: |
  final class TaskQueue {
      // your code
  }
hints:
  - "Store jobs as an array of tuples: [(name: String, work: () -> Int)]."
  - "work is stored, so it's @escaping. completion is called before runAll returns, so it isn't."
  - "The closures capture base itself, so they see 3, not 10."
rubric:
  - "work is @escaping; completion is not."
  - Jobs run in insertion order and the queue is emptied.
  - completion is called once with the sum, including 0 for an empty queue.
  - The output matches exactly.
solution: |
  ```swift
  final class TaskQueue {
      private var jobs: [(name: String, work: () -> Int)] = []

      func add(_ name: String, work: @escaping () -> Int) {
          jobs.append((name: name, work: work))
      }

      func runAll(completion: (Int) -> Void) {
          var total = 0
          for job in jobs {
              let result = job.work()
              print("\(job.name): \(result)")
              total += result
          }
          jobs = []
          completion(total)
      }
  }

  let queue = TaskQueue()
  var base = 10
  queue.add("double") { base * 2 }
  queue.add("square") { base * base }
  base = 3
  queue.runAll { total in print("total: \(total)") }
  queue.runAll { total in print("total: \(total)") }
  ```

  ```output
  double: 6
  square: 9
  total: 15
  total: 0
  ```

  `work` is stored in `jobs`, so it escapes. `completion` is called before `runAll` returns, so it stays non-escaping, which is the better default: it tells callers the closure won't be kept. The jobs captured the variable `base` (lesson 4), so they compute with 3, the value when they run. The second `runAll` finds an empty queue and reports 0.
````

````exercise
id: m11-l05-e6
type: explain
prompt: |
  Explain, in your own words, why the first line never calls `hasPermission` when `isLoggedIn` is `false`, and why that's the same mechanism that stops the second line from loading when the value is cached.
code: |
  print(isLoggedIn && hasPermission(for: "admin"))
  let page = cache[key] ?? expensiveLoad(key)
rubric:
  - Says the right-hand side of && and the default of ?? are @autoclosure parameters.
  - Says the expression is wrapped in a closure instead of being evaluated before the call.
  - Says the operator only calls the closure when it needs the value (left side true, optional nil).
solution: |
  Both operators are ordinary functions in the standard library, and their second parameter is declared `@autoclosure`. When you write `isLoggedIn && hasPermission(for: "admin")`, Swift doesn't evaluate `hasPermission(…)` before calling `&&`; it wraps the expression in a closure and passes that. `&&` looks at its left side first, and only calls the closure if the left side is `true`, since `false && anything` is `false`.

  `??` works the same way: its default value is an autoclosure, called only when the optional is `nil`. If `cache[key]` has a value, `expensiveLoad(key)` is never run.

  ```swift
  final class Permissions {
      var checks = 0

      func has(_ role: String) -> Bool {
          checks += 1
          return role == "admin"
      }
  }

  let permissions = Permissions()
  let isLoggedIn = false
  print(isLoggedIn && permissions.has("admin"))
  let cache = ["home": "cached page"]
  print(cache["home"] ?? "loaded page \(permissions.has("x"))")
  print(permissions.checks)
  ```

  ```output
  false
  cached page
  0
  ```
````

## Summary

- Closure parameters are non-escaping by default: the function can only call them during the call. That lets the compiler optimize and rules out cycles.
- Mark a parameter `@escaping` when the function stores the closure or passes it to something that will call it later. Storing a non-escaping one is a compile error.
- Optional closure parameters are already escaping; writing `@escaping` on them is an error.
- Escaping closures in classes must write `self.` explicitly, which is your cue to think about `[weak self]`. A mutating struct method can't store a closure that captures `self`.
- A completion handler is an escaping closure called when slow work finishes. Code after the call runs first. `async`/`await` replaces many of them; that's Module 29.
- `@autoclosure` lets callers pass an expression that the function evaluates only if and when it calls it. `&&`, `??` and `assert` all use it. Use it for deferring work, and sparingly.
