---
id: m28-l05
title: Completion handlers across threads
description: "Module 26 taught the completion handler contract: call it exactly once, report outcomes with Result. This lesson adds the question that contract left out: on which thread? You see callbacks arrive on background queues, hop back to the main queue before touching the UI, design APIs that say (and take) their callback queue, keep exactly-once on every path when work is asynchronous, and meet the @Sendable requirement Swift 6 adds."
module: m28
order: 5
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m28-l04, m26-l02]
objectives:
  - Find out which queue an API calls its completion handler on, and hop to the main queue before touching the UI.
  - Design a callback API that documents its callback queue or lets the caller choose it.
  - Call a completion handler exactly once, always asynchronously, on every path of asynchronous code.
  - Use Result for asynchronous outcomes and route every path through one finish function.
  - Mark completion handlers @Sendable when they cross threads, and read the Swift 6 error when they aren't.
terms:
  - term: Callback queue
    definition: "The queue (and so the thread) on which an API calls your completion handler. Good APIs document it or let you pass it in."
  - term: Hopping to the main queue
    definition: "Wrapping UI work in DispatchQueue.main.async (or OperationQueue.main.addOperation) inside a callback that may run on a background thread."
  - term: Releasing Zalgo
    definition: "Slang for an API that sometimes calls its completion handler synchronously (before returning) and sometimes asynchronously, so callers can't predict the order of their own code."
  - term: "@Sendable closure"
    definition: "A closure type the compiler checks for safe use from other threads: everything it captures must be Sendable. Dispatch's async takes one, so anything it captures, including a completion handler, must be @Sendable too."
mastery:
  - Read an API's documentation and say which thread its callback runs on; when it doesn't say, assume a background thread.
  - Wrap UI updates from a background callback in DispatchQueue.main.async with [weak self].
  - Write a loader that takes a callbackQueue parameter defaulting to .main.
  - Rewrite a function that calls its handler synchronously on one path and asynchronously on another so it's always asynchronous.
  - Fix "capture of 'completion' with non-Sendable type" by marking the parameter @Sendable.
resources: [swift-result, swift-book-closures, swift-mainactor]
cards:
  - id: m28-l05-c1
    front: On which thread does a completion handler run?
    back: "Wherever the API calls it. URLSession uses its delegate queue (a serial background queue by default), CLGeocoder uses the main thread, UNUserNotificationCenter says \"may execute on a background thread\". Undocumented means: assume background."
  - id: m28-l05-c2
    front: How do you update UIKit from a background callback?
    back: "Hop: DispatchQueue.main.async { [weak self] in … } (or capture [weak self] in the callback). In Swift 6 the compiler treats the closure passed to DispatchQueue.main.async as main-actor code."
  - id: m28-l05-c3
    front: Why should a completion handler never be called synchronously on some paths?
    back: "Callers can't predict whether their code after the call runs before or after the callback. Always call it asynchronously, on the documented queue, even for errors detected up front."
  - id: m28-l05-c4
    front: "Swift 6: \"capture of 'completion' with non-Sendable type\". Fix?"
    back: "Mark the parameter @escaping @Sendable. DispatchQueue.async takes a @Sendable closure, so everything it captures, including your completion handler, must be Sendable."
---

## The idea in one sentence

A completion handler runs on whatever thread the API that calls it is on, so every callback API must answer "which queue?", and every caller must hop to the main queue before touching the UI.

> [!note] What you already know, and what was run
> Module 26, lesson 2 covered the contract (call the handler exactly once, report outcomes with `Result`, flatten pyramids). This lesson adds threads. The quotes about real APIs come from Apple's documentation for `URLSession.init(configuration:delegate:delegateQueue:)`, `CLGeocoder.reverseGeocodeLocation(_:completionHandler:)` and `UNUserNotificationCenter.requestAuthorization(options:completionHandler:)`, read November 2026. Plain-Swift blocks were compiled and run with Swift 6.3 on Linux; the UIKit block is type-checked against the iOS SDK, not run.

## The callback runs where the API calls it

Calling a completion handler is just calling a function. It runs on the thread of whoever calls it:

```swift
import Foundation

func loadGreeting(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().async {
        completion("hello")   // called from a background thread
    }
}

/// Keeps the main run loop going until `group` is empty, the way an app's run loop always runs.
func runMainLoop(until group: DispatchGroup) {
    while group.wait(timeout: .now()) == .timedOut {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}

let group = DispatchGroup()
group.enter()
loadGreeting { greeting in
    print("callback on the main thread: \(Thread.isMainThread)")
    DispatchQueue.main.async {
        print("after the hop, on the main thread: \(Thread.isMainThread)")
        print("show \"\(greeting)\"")
        group.leave()
    }
}
runMainLoop(until: group)
```

```output
callback on the main thread: false
after the hop, on the main thread: true
show "hello"
```

1. `loadGreeting` calls `completion` from inside a global-queue closure, so the handler runs on a background thread.
2. The handler can do background-safe work there (parse, filter), but it must not touch the UI.
3. `DispatchQueue.main.async { … }` is the **hop**: the UI part runs later, on the main thread.
4. `runMainLoop(until:)` is test scaffolding: it runs the main run loop until the group is empty. The rest of this lesson reuses it. In an app, `UIApplicationMain` already runs the loop.

Real APIs differ, which is why you check each one:

| API | Where the handler runs, per Apple's documentation |
| --- | --- |
| `URLSession` completion handlers | On the session's delegate queue. If you pass `nil`, "the session creates a serial operation queue for performing all delegate method calls and completion handler calls": a background queue. |
| `CLGeocoder.reverseGeocodeLocation` | "the geocoder executes the provided completion handler on the main thread." |
| `UNUserNotificationCenter.requestAuthorization` | "This block may execute on a background thread." |

When the documentation doesn't say, assume a background thread. Hopping to the main queue when you're already on the main thread costs one run loop turn; touching UIKit from a background thread can corrupt state and crash somewhere unrelated.

## Hopping back to the main thread in UIKit

Here's the shape in a view controller. The loader calls back on a background queue; the UI work hops to the main queue:

```swift ios
import UIKit

enum NameError: Error {
    case offline
}

func loadName(userID: Int, completion: @escaping @Sendable (Result<String, NameError>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        // Pretend this reads from the network or a database.
        completion(.success("Christian"))
    }
}

final class ProfileViewController: UIViewController {
    private let nameLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(nameLabel)
        view.addSubview(spinner)
        spinner.startAnimating()

        loadName(userID: 42) { [weak self] result in
            // Background thread: no UIKit here.
            DispatchQueue.main.async {
                guard let self else { return }
                self.spinner.stopAnimating()
                switch result {
                case .success(let name):
                    self.nameLabel.text = name
                case .failure:
                    self.nameLabel.text = "Couldn't load the name"
                }
            }
        }
    }
}
```

- `[weak self]`: the user may leave the screen before the load finishes. A weak capture lets the view controller go away; `guard let self else { return }` skips the update if it has.
- Everything that touches `spinner` and `nameLabel` is inside `DispatchQueue.main.async`.
- `UIViewController` is `@MainActor` (Module 21, lesson 3). The compiler accepts `self.nameLabel` inside `DispatchQueue.main.async` because Swift 6 treats a closure passed directly to `DispatchQueue.main.async` as main-actor code. Touch `self.nameLabel` directly in the background callback instead, and the compiler rejects it.

Here's that mistake with a stand-in for the view controller (a `@MainActor` class, so it runs on Linux too):

```swift no-compile main actor-isolated property 'nameLabel' can not be mutated from a Sendable closure
import Dispatch

final class Label {
    var text: String?
}

func loadName(completion: @escaping @Sendable (String) -> Void) {
    DispatchQueue.global().async {
        completion("Christian")
    }
}

@MainActor
final class ProfileScreen {
    private let nameLabel = Label()

    func start() {
        loadName { [weak self] name in
            self?.nameLabel.text = name   // background thread
        }
    }
}
```

Swift 6.3: `error: main actor-isolated property 'nameLabel' can not be mutated from a Sendable closure`. The main actor is doing the "UI on the main thread" check for you: wrap the line in `DispatchQueue.main.async { … }` and it compiles.

## Design the callback queue into the API

When you write a callback API, the caller shouldn't have to guess. Two good options:

1. **Document it, and always honor it.** "The completion handler is called on the main queue." Callers can then update the UI directly.
2. **Let the caller choose**, with a sensible default. Callers that want to keep processing in the background pass their own queue; UI callers take the default.

The second, with every path going through one `finish` function:

```swift
import Foundation

enum AvatarError: Error {
    case invalidID(Int)
    case notFound(Int)
}

final class AvatarLoader: Sendable {
    /// Calls `completion` exactly once, asynchronously, on `callbackQueue`.
    func loadAvatar(
        for userID: Int,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<String, AvatarError>) -> Void
    ) {
        @Sendable func finish(_ result: Result<String, AvatarError>) {
            callbackQueue.async { completion(result) }
        }

        guard userID > 0 else {
            finish(.failure(.invalidID(userID)))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if userID == 404 {
                finish(.failure(.notFound(userID)))
            } else {
                finish(.success("avatar-\(userID).png"))
            }
        }
    }
}

func runMainLoop(until group: DispatchGroup) {
    while group.wait(timeout: .now()) == .timedOut {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}

let loader = AvatarLoader()
let group = DispatchGroup()

for id in [7, -1, 404] {
    group.enter()
    loader.loadAvatar(for: id) { result in
        switch result {
        case .success(let file):
            print("id \(id) on main: \(Thread.isMainThread), got \(file)")
        case .failure(let error):
            print("id \(id) on main: \(Thread.isMainThread), failed: \(error)")
        }
        group.leave()
    }
    runMainLoop(until: group)   // one at a time, so the output order is fixed
}
```

```output
id 7 on main: true, got avatar-7.png
id -1 on main: true, failed: invalidID(-1)
id 404 on main: true, failed: notFound(404)
```

- The doc comment states the contract: once, asynchronously, on `callbackQueue`.
- `finish(_:)` is the only place that calls `completion`. Each path calls `finish` once and then ends (`return` after the guard, the end of the closure otherwise). Reviewing "exactly once" means checking each path reaches `finish` exactly once, not hunting for `completion(` calls.
- `finish` is marked `@Sendable` because it's called from inside a `@Sendable` closure. Without it, Swift 6.3 reports `concurrently-executed local function 'finish' must be marked as '@Sendable'`.
- The invalid ID is detected immediately, but its failure is still delivered **asynchronously** through `callbackQueue`. The next section explains why that matters.
- The loop waits for each load before starting the next, only so the three lines always print in the same order.

The `Result` value carries exactly one outcome, as in Module 26: the caller `switch`es over it and can't forget the error case.

## Always asynchronous, even for early errors

It's tempting to report an obviously bad input right away:

```swift illustrative
guard userID > 0 else {
    completion(.failure(.invalidID(userID)))   // synchronous: before loadAvatar returns
    return
}
```

Now the same function calls back **before returning** on one path and **after** on the others. Callers write code like this:

```swift illustrative
spinner.startAnimating()
loader.loadAvatar(for: id) { result in
    spinner.stopAnimating()
    show(result)
}
isLoading = true
```

On the success path: start spinner, `isLoading = true`, later stop spinner. On the invalid-ID path: start spinner, stop spinner, **then** `isLoading = true`, and the screen is stuck "loading" with no spinner. The bug only appears for bad input, which is exactly the case nobody tests. JavaScript developers call this "releasing Zalgo" (a joke name that stuck). The rule: a function that's asynchronous on any path should be asynchronous on every path. Delivering everything through `callbackQueue.async` does that for free.

## Swift 6: completion handlers must be @Sendable

`DispatchQueue.async` takes a `@Sendable` closure, and a `@Sendable` closure can only capture `Sendable` values. A plain function type isn't `Sendable`, because it could capture anything. So a completion handler that you call from inside `async` has to be declared `@Sendable` too:

```swift no-compile capture of 'completion' with non-Sendable type '(String) -> Void' in a '@Sendable' closure
import Dispatch

func loadName(id: Int, completion: @escaping (String) -> Void) {
    DispatchQueue.global().async {
        completion("user \(id)")
    }
}
```

Swift 6.3 reports `error: capture of 'completion' with non-Sendable type '(String) -> Void' in a '@Sendable' closure`, with the note `a function type must be marked '@Sendable' to conform to 'Sendable'`. The fix is in the note: `completion: @escaping @Sendable (String) -> Void`.

That pushes the requirement to the caller: the closure **you** pass must also only capture `Sendable` things. Capturing a `let` string or a `DispatchGroup` is fine; capturing a non-`Sendable` class instance or mutating a captured `var` isn't. In view controllers, `self` is `@MainActor`, which makes it `Sendable`, so `[weak self]` works. Lesson 6 shows how to make your own classes `Sendable` honestly. Module 29 goes further: a callback can be typed `@MainActor`, and then the compiler itself proves it runs on the main thread.

## Common mistakes

> [!error] Touching the UI in a callback without checking which thread it's on
> `URLSession` with its default delegate queue, and many other APIs, call back on a background queue. Hop with `DispatchQueue.main.async` unless the documentation promises the main thread.

> [!error] Calling the completion handler synchronously on the error path
> Callers get two different orderings depending on the input. Deliver every outcome the same way, asynchronously on the documented queue.

> [!error] A path that never calls back
> An early `return` in a background closure, a `guard` without a `finish`, a cancelled job that just stops: the caller's spinner spins forever. Route every exit through one `finish(_:)`.

> [!error] Not documenting the callback queue
> Callers either hop when they don't need to or don't hop when they must. Say it in the doc comment, or take a `callbackQueue` parameter.

> [!error] Silencing Sendable errors with a non-Sendable workaround
> Marking a completion handler `@Sendable` is the fix. Wrapping it in a class to dodge the check moves the problem to runtime.

## Exercises

````exercise
id: m28-l05-e1
type: prediction
prompt: "A cache answers some requests synchronously and some asynchronously. What does the program print?"
code: |
  import Foundation

  func cachedTitle(for id: Int, completion: @escaping @Sendable (String) -> Void) {
      if id == 1 {
          completion("cached title")   // cache hit: answered right away
          return
      }
      DispatchQueue.global().async {
          DispatchQueue.main.async {
              completion("loaded title")
          }
      }
  }

  let group = DispatchGroup()
  for id in [1, 2] {
      group.enter()
      print("request \(id)")
      cachedTitle(for: id) { title in
          print("got \(title)")
          group.leave()
      }
      print("after call \(id)")
  }
  while group.wait(timeout: .now()) == .timedOut {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
  }
output: |
  request 1
  got cached title
  after call 1
  request 2
  after call 2
  got loaded title
hints:
  - "For id 1, the completion handler runs before cachedTitle returns."
  - "For id 2, it runs on the main queue, which can't run anything until the top-level code reaches the run loop."
solution: |
  ```output
  request 1
  got cached title
  after call 1
  request 2
  after call 2
  got loaded title
  ```

  For id 1 the handler is called synchronously, so `got cached title` prints **before** `after call 1`. For id 2 it's delivered through the main queue, so it prints only after the loop is done and the run loop runs: **after** `after call 2`. Same function, two orderings. That's the bug this lesson warns about: deliver the cache hit through `DispatchQueue.main.async` too, and both requests behave the same way.
````

````exercise
id: m28-l05-e2
type: find-errors
prompt: "This loader is called from view controllers. Mark every real problem."
code: |
  final class ReceiptLoader: Sendable {
      // Loads a receipt. Calls completion when done.
      func load(id: String, completion: @escaping @Sendable (Result<Receipt, ReceiptError>) -> Void) {
          guard !id.isEmpty else {
              completion(.failure(.emptyID))
              return
          }
          DispatchQueue.global(qos: .userInitiated).async {
              guard let data = storage.read(id) else {
                  return
              }
              do {
                  let receipt = try decode(data)
                  completion(.success(receipt))
              } catch {
                  completion(.failure(.corrupt))
              }
              completion(.failure(.corrupt))
          }
      }
  }
choices:
  - text: "The empty-ID failure is delivered synchronously while every other outcome is asynchronous."
    correct: true
  - text: "When storage.read returns nil, completion is never called."
    correct: true
  - text: "After the do/catch, completion is called a second time on every path."
    correct: true
  - text: "The doc comment doesn't say which queue completion runs on, and it runs on a background queue."
    correct: true
  - text: "completion must not be @Sendable, because it's called from a background thread."
    correct: false
rubric:
  - Finds the synchronous early failure.
  - Finds the missing callback when read returns nil.
  - Finds the double call after the do/catch.
  - Finds the undocumented (background) callback queue.
solution: |
  1. **Synchronous early failure.** The empty-ID path calls back before `load` returns; the others call back later. Deliver it asynchronously like the rest.
  2. **Silent path.** `guard let data … else { return }` exits the closure without calling `completion`. The caller waits forever. Report a `.notFound` failure.
  3. **Double call.** The `do`/`catch` already called `completion`; the line after it calls it again. Delete it.
  4. **Undocumented background queue.** The callback runs on a global queue, and view controllers will touch UIKit in it. Say so in the doc comment, or better, take `callbackQueue: DispatchQueue = .main` and deliver everything through it.

  A single `finish(_:)` that does `callbackQueue.async { completion(result) }`, called exactly once on each path, fixes 1, 3 and 4 at once and makes 2 easy to spot. `@Sendable` is correct: the closure is captured by `async`, which requires it.
````

````exercise
id: m28-l05-e3
type: solve
prompt: |
  Write `func fetchScore(for player: String, callbackQueue: DispatchQueue = .main, completion: @escaping @Sendable (Result<Int, ScoreError>) -> Void)` with this error type:

  ```swift
  enum ScoreError: Error {
      case emptyName
      case unknownPlayer(String)
  }
  ```

  - An empty name fails with `.emptyName`.
  - The lookup runs on `DispatchQueue.global()`, using `let scores = ["ana": 120, "leo": 95]`. A missing player fails with `.unknownPlayer(name)`.
  - Every outcome, including the empty name, is delivered **asynchronously** on `callbackQueue`, through one `@Sendable` local function `finish`.

  This code, with the `runMainLoop(until:)` helper from the lesson:

  ```swift
  let group = DispatchGroup()
  for name in ["ana", "", "zoe"] {
      group.enter()
      fetchScore(for: name) { result in
          let label = name.isEmpty ? "(empty)" : name
          switch result {
          case .success(let score):
              print("\(label): \(score), main: \(Thread.isMainThread)")
          case .failure(let error):
              print("\(label): \(error), main: \(Thread.isMainThread)")
          }
          group.leave()
      }
      runMainLoop(until: group)
  }
  ```

  should print:

  ```plaintext
  ana: 120, main: true
  (empty): emptyName, main: true
  zoe: unknownPlayer("zoe"), main: true
  ```
starter: |
  import Foundation

  enum ScoreError: Error {
      case emptyName
      case unknownPlayer(String)
  }

  func fetchScore(for player: String, callbackQueue: DispatchQueue = .main, completion: @escaping @Sendable (Result<Int, ScoreError>) -> Void) {
      // your code
  }

  func runMainLoop(until group: DispatchGroup) {
      while group.wait(timeout: .now()) == .timedOut {
          RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      }
  }

  let group = DispatchGroup()
  for name in ["ana", "", "zoe"] {
      group.enter()
      fetchScore(for: name) { result in
          let label = name.isEmpty ? "(empty)" : name
          switch result {
          case .success(let score):
              print("\(label): \(score), main: \(Thread.isMainThread)")
          case .failure(let error):
              print("\(label): \(error), main: \(Thread.isMainThread)")
          }
          group.leave()
      }
      runMainLoop(until: group)
  }
hints:
  - "@Sendable func finish(_ result: Result<Int, ScoreError>) { callbackQueue.async { completion(result) } }"
  - "guard !player.isEmpty else { finish(.failure(.emptyName)); return }"
  - "Inside the global closure: if let score = scores[player] { finish(.success(score)) } else { finish(.failure(.unknownPlayer(player))) }"
rubric:
  - Every path calls finish exactly once.
  - finish delivers through callbackQueue.async, including the empty-name failure.
  - The lookup runs on a global queue.
  - The output matches.
solution: |
  ```swift
  import Foundation

  enum ScoreError: Error {
      case emptyName
      case unknownPlayer(String)
  }

  /// Calls `completion` exactly once, asynchronously, on `callbackQueue`.
  func fetchScore(for player: String, callbackQueue: DispatchQueue = .main, completion: @escaping @Sendable (Result<Int, ScoreError>) -> Void) {
      @Sendable func finish(_ result: Result<Int, ScoreError>) {
          callbackQueue.async { completion(result) }
      }

      guard !player.isEmpty else {
          finish(.failure(.emptyName))
          return
      }
      DispatchQueue.global().async {
          let scores = ["ana": 120, "leo": 95]
          if let score = scores[player] {
              finish(.success(score))
          } else {
              finish(.failure(.unknownPlayer(player)))
          }
      }
  }

  func runMainLoop(until group: DispatchGroup) {
      while group.wait(timeout: .now()) == .timedOut {
          RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      }
  }

  let group = DispatchGroup()
  for name in ["ana", "", "zoe"] {
      group.enter()
      fetchScore(for: name) { result in
          let label = name.isEmpty ? "(empty)" : name
          switch result {
          case .success(let score):
              print("\(label): \(score), main: \(Thread.isMainThread)")
          case .failure(let error):
              print("\(label): \(error), main: \(Thread.isMainThread)")
          }
          group.leave()
      }
      runMainLoop(until: group)
  }
  ```

  ```output
  ana: 120, main: true
  (empty): emptyName, main: true
  zoe: unknownPlayer("zoe"), main: true
  ```

  Every path reaches `finish` exactly once, and `finish` always goes through `callbackQueue.async`, so even the empty name is reported on the main queue after `fetchScore` has returned. The `main: true` on every line confirms the callback queue was honored.
````

````exercise
id: m28-l05-e4
type: comprehension
prompt: "Swift 6 rejects your function with \"capture of 'completion' with non-Sendable type '(Data) -> Void' in a '@Sendable' closure\". What's the right fix?"
choices:
  - text: "Declare the parameter as completion: @escaping @Sendable (Data) -> Void."
    correct: true
    why: "That's what the note suggests: the handler is captured by DispatchQueue.async's @Sendable closure, so it must be Sendable itself."
  - text: "Remove @escaping so the closure isn't captured."
    correct: false
    why: "The handler is called after the function returns, so it has to escape. The compiler would reject that too."
  - text: "Call completion before DispatchQueue.global().async so it isn't captured."
    correct: false
    why: "Then it runs before the work is done, with no result to report."
  - text: "Store completion in a global variable and call it from there."
    correct: false
    why: "Swift 6 rejects unprotected global mutable state too, and even if it didn't, you'd have a data race instead of a compiler error."
solution: |
  Mark the parameter `@Sendable`: `completion: @escaping @Sendable (Data) -> Void`. The compiler's note says it directly: "a function type must be marked '@Sendable' to conform to 'Sendable'". The requirement then moves to callers: the closures they pass may only capture `Sendable` values, which is exactly what makes calling them from a background thread safe.
````

````exercise
id: m28-l05-e5
type: explain
prompt: "A reviewer asks you to change a loader's completion handler from \"called on a background queue\" to \"called on the main queue\". Another reviewer objects: \"then callers that do more background work have to hop back off main.\" Explain the trade-off and propose an API that satisfies both."
code: |
  /// Loads and decodes the user's orders.
  /// Calls completion on a background queue.
  func loadOrders(completion: @escaping @Sendable (Result<[Order], OrderError>) -> Void)
rubric:
  - Explains that main-queue delivery is convenient for UI callers and prevents forgotten hops.
  - Explains that background delivery avoids a pointless hop for callers that keep processing (and keeps work off the main thread).
  - Proposes a callbackQueue parameter defaulting to .main (or two clear variants).
  - Mentions documenting the choice in the doc comment.
solution: |
  Main-queue delivery makes the common case safe: most callers update the UI, and none of them can forget to hop. But a caller that wants to filter or save the orders afterwards now starts on the main thread and must hop back to a background queue, and if it forgets, that work runs on the main thread.

  Background delivery is the reverse: efficient for processing callers, a trap for UI callers.

  Let the caller decide, with the safe default:

  ```swift illustrative
  /// Loads and decodes the user's orders.
  /// Calls `completion` exactly once, asynchronously, on `callbackQueue` (main by default).
  func loadOrders(
      callbackQueue: DispatchQueue = .main,
      completion: @escaping @Sendable (Result<[Order], OrderError>) -> Void
  )
  ```

  UI code calls `loadOrders { … }` and updates views directly; a sync job calls `loadOrders(callbackQueue: syncQueue) { … }`. `URLSession` takes the same approach with its `delegateQueue` parameter.
````

## Summary

- A completion handler runs on the thread of whoever calls it. Check each API's documentation (`URLSession`: its delegate queue, background by default; `CLGeocoder`: main thread; `UNUserNotificationCenter`: "may execute on a background thread"), and when it's silent, assume background.
- Hop to the main queue with `DispatchQueue.main.async` before touching UIKit, with `[weak self]` if the screen might go away. Swift 6 treats that closure as main-actor code, so the compiler checks the UI half for you.
- When you write a callback API, document the callback queue or take a `callbackQueue` parameter that defaults to `.main`.
- Exactly once still applies, and now also **always asynchronously**: route every path through one `finish(_:)` that dispatches to the callback queue, including errors you detect before starting any work.
- In Swift 6, a completion handler captured by `DispatchQueue.async` must be `@escaping @Sendable`, and so must a local `finish` function called from there.
