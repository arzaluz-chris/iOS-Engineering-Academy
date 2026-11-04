---
id: m26-l02
title: Closures and callbacks
description: Use closures as the lightweight alternative to a delegate. You store callbacks in properties and initializers, decide what each closure captures, write completion handlers that are called exactly once on every path (and let the compiler check it), report outcomes with Result, recognize callback pyramids, and get a first look at wrapping a callback API with withCheckedThrowingContinuation so it can be awaited.
module: m26
order: 2
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l01]
objectives:
  - Store a callback in an optional property or pass a required one through an initializer, and call it correctly.
  - Choose a capture list for a stored callback, including capturing values instead of self.
  - Write completion handlers that run exactly once on every path, using a let constant the compiler checks.
  - Report success or failure through a Result-based callback and handle it with switch.
  - Recognize nested callbacks and flatten them with named steps.
  - Read a withCheckedThrowingContinuation wrapper and explain the resume-exactly-once rule.
terms:
  - term: Callback
    definition: "A closure one object hands to another so it can be called later, when something happens. A stored callback lives in a property (var onSelect: ((Int) -> Void)?); a completion handler is passed to a single call."
  - term: Completion handler
    definition: "An escaping closure parameter that a function calls when its work finishes, often after it has returned. It must be called exactly once on every path."
  - term: Result-based callback
    definition: "A callback that takes a Result<Success, Failure> value, so one closure handles both outcomes and the caller has to look at the error."
  - term: Callback pyramid
    definition: "Completion handlers nested inside completion handlers, each step indented further, with error handling repeated at every level. Also called callback hell."
  - term: Checked continuation
    definition: "A CheckedContinuation, created by withCheckedContinuation or withCheckedThrowingContinuation, that suspends an async function until a callback resumes it. Resuming twice stops the program; never resuming leaves the task suspended forever."
mastery:
  - Give a reusable view an onSelect callback and wire it from its owner with [weak self].
  - Rewrite a completion-handler function so every path assigns one let result and calls the handler once.
  - Handle a Result callback with switch and print both outcomes.
  - Turn a three-level callback pyramid into named steps.
  - Wrap a Result-based callback API in an async throws function with withCheckedThrowingContinuation.
resources: [swift-book-closures, swift-book-arc, swift-result, swift-book-error-handling]
cards:
  - id: m26-l02-c1
    front: Optional closure property vs closure in the initializer?
    back: "var onChange: ((Int) -> Void)? is optional and can be set or replaced any time; calling it is onChange?(value). let onChange: (Int) -> Void in init is required: the object can't exist without it, and it can't be replaced."
  - id: m26-l02-c2
    front: When does a stored callback need [weak self]?
    back: "When self owns (directly or through other objects) whatever stores the closure: a screen sets a callback on its own view, cell or view model. If you only need values, capture those instead ([id = item.id]) and you may not need self at all."
  - id: m26-l02-c3
    front: How can the compiler help you call a completion handler exactly once?
    back: "Declare let result: Result<…> without a value, assign it in every branch, and call completion(result) once at the end. A missing branch is \"constant 'result' used before being initialized\", and a second assignment is also an error."
  - id: m26-l02-c4
    front: What happens if a checked continuation is resumed twice? Never?
    back: "Twice: the program stops with \"SWIFT TASK CONTINUATION MISUSE: … tried to resume its continuation more than once\". Never: the awaiting task stays suspended forever, and its resources leak (CheckedContinuation logs a message)."
---

## The idea in one sentence

A callback is a function value one object hands to another to say "call this when it happens", which makes it the smallest way to send one event back, as long as you're careful about what it captures and how many times it runs.

> [!note] What you already know
> Module 11, lesson 5 introduced `@escaping` and completion handlers; Module 13, lesson 4 covered `[weak self]` and `[unowned self]`; Module 22, lesson 5 and Module 25 used closure properties to send events from a view or a pushed screen back to its owner. This lesson is about using callbacks across a whole app without surprises. Plain-Swift code was compiled and run with Swift 6.3; the UIKit block is type-checked against the iOS SDK, not run.

## Stored callbacks

A child that reports one kind of event can expose a closure property instead of a delegate protocol:

```swift
final class QuantityStepper {
    var onChange: ((Int) -> Void)?
    private(set) var value: Int

    init(value: Int) {
        self.value = value
    }

    func increment() {
        value += 1
        onChange?(value)
    }
}

final class CartLine {
    let stepper = QuantityStepper(value: 1)
    private(set) var total = 0
    let unitPrice: Int

    init(unitPrice: Int) {
        self.unitPrice = unitPrice
        total = unitPrice
        stepper.onChange = { [weak self] quantity in
            guard let self else { return }
            total = quantity * unitPrice
            print("total: \(total)")
        }
    }
}

let line = CartLine(unitPrice: 4)
line.stepper.increment()
line.stepper.increment()
```

```output
total: 8
total: 12
```

- `var onChange: ((Int) -> Void)?` is optional because the stepper works without anyone listening. The parentheses around the function type are required before `?`.
- `onChange?(value)` calls it only if it's set. Optional closure properties are already escaping; you don't write `@escaping` on a property.
- `[weak self]` because `CartLine` owns the stepper and the stepper owns the closure. A strong capture would be a cycle (lesson 4 shows it).

Compared with a delegate, there's no protocol, no conformance and no `AnyObject`; the code that reacts sits right where the wiring happens. The costs are the same as a delegate's limits, plus one: **one closure per property**. A second assignment replaces the first, and there's no compiler help to notice. If the child reports five events, five closure properties start to look worse than one protocol.

### Required callbacks in the initializer

When the object is useless without the callback, take it in `init` and store it in a `let`:

```swift
final class ConfirmButton {
    private let onConfirm: (String) -> Void
    let title: String

    init(title: String, onConfirm: @escaping (String) -> Void) {
        self.title = title
        self.onConfirm = onConfirm
    }

    func tap() {
        onConfirm(title)
    }
}

let delete = ConfirmButton(title: "Delete") { title in
    print("confirmed: \(title)")
}
delete.tap()
```

```output
confirmed: Delete
```

Now the parameter needs `@escaping`: it's a non-optional function parameter that gets stored. In exchange, the callback can't be forgotten or replaced, and there's no `?` at the call site.

## What the closure captures

A stored callback lives as long as whatever stores it. Decide what it really needs:

- **`[weak self]`** when it needs the owner's state and the owner (directly or indirectly) holds whatever stores the closure.
- **Values** when it only needs data. `[id = item.id]` copies the value when the closure is created; no reference to `self` at all.
- **Nothing** when the closure is self-contained.

A common case is a list where each row's callback must remember **which** item it belongs to:

```swift
struct Song {
    let id: Int
    let title: String
}

final class Row {
    var onTap: (() -> Void)?
}

final class PlaylistScreen {
    var rows: [Row] = []
    private var played: [Int] = []

    func show(_ songs: [Song]) {
        rows = songs.map { song in
            let row = Row()
            row.onTap = { [weak self, id = song.id] in
                self?.play(id)
            }
            return row
        }
    }

    func play(_ id: Int) {
        played.append(id)
        print("playing \(id); history \(played)")
    }
}

let screen = PlaylistScreen()
screen.show([Song(id: 7, title: "Intro"), Song(id: 9, title: "Outro")])
screen.rows[1].onTap?()
screen.rows[0].onTap?()
```

```output
playing 9; history [9]
playing 7; history [9, 7]
```

Each row's closure captured its own `id` when it was created, so tapping row 1 plays song 9 no matter what happens to the array later. Capturing an index instead (`[index]`) is a classic bug in UIKit lists: after a deletion or a move, the stored index points at a different item.

In UIKit, the same pattern connects a cell's button to the controller. The cell owns the closure, the table owns the cell and the controller owns the table, so the closure captures the controller weakly and the item's identifier by value:

```swift ios
import UIKit

final class FavoriteCell: UITableViewCell {
    var onFavoriteTapped: (() -> Void)?
    private let favoriteButton = UIButton(configuration: .plain())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        favoriteButton.configuration?.image = UIImage(systemName: "star")
        favoriteButton.addAction(UIAction { [weak self] _ in
            self?.onFavoriteTapped?()
        }, for: .primaryActionTriggered)
        favoriteButton.sizeToFit()
        accessoryView = favoriteButton
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteTapped = nil
    }
}

struct Recipe {
    let id: Int
    let name: String
}

final class RecipesViewController: UITableViewController {
    private let recipes = [Recipe(id: 1, name: "Pancakes"), Recipe(id: 2, name: "Ramen")]
    private var favoriteIDs: Set<Int> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(FavoriteCell.self, forCellReuseIdentifier: "recipe")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recipes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recipe", for: indexPath) as! FavoriteCell
        let recipe = recipes[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = recipe.name
        cell.contentConfiguration = content
        cell.onFavoriteTapped = { [weak self] in
            self?.toggleFavorite(recipe.id)
        }
        return cell
    }

    private func toggleFavorite(_ id: Int) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
    }
}
```

- The button's `UIAction` captures the **cell** weakly (the cell owns the button, the button owns the action), and forwards to `onFavoriteTapped`.
- `cellForRowAt` sets the callback on every dequeue, so a reused cell never keeps the previous row's closure. `prepareForReuse()` clears it as a second line of defense (Module 24, lesson 3).
- The closure captures `recipe` (a struct, copied) and `self` weakly. It never captures `indexPath`.

## Completion handlers: exactly once

A completion handler is a promise: "I'll call you back with the outcome." The caller is usually waiting for that call to hide a spinner, enable a button or move to the next step. Two bugs break the promise:

- **Never calling it** on some path, typically an early exit. The spinner spins forever.
- **Calling it twice**, typically a missing `return` after reporting a failure. The next screen is pushed twice, or a value is saved twice.

Both are easy to write and nothing in the type system catches them by default:

```swift
func checkUsername(_ name: String, completion: (String) -> Void) {
    if name.isEmpty {
        completion("empty")
    }
    if name.count < 3 {
        completion("too short")
        return
    }
    if name.contains(" ") {
        return
    }
    completion("ok: \(name)")
}

var calls = 0
checkUsername("") { message in
    calls += 1
    print(message)
}
checkUsername("ana maria") { message in
    calls += 1
    print(message)
}
print("handler calls: \(calls)")
```

```output
empty
too short
handler calls: 2
```

The empty name got **two** calls (the first `if` has no `return`), and `"ana maria"` got **none** (the space check returns without reporting). Two calls for two requests looks right in the total, which is exactly why this kind of bug survives a quick test.

### Let the compiler count

Declare the outcome as a `let` without a value, assign it on every path, and call the handler in one place at the end. Swift's definite-initialization check then does the counting: every path must assign `result` exactly once before it's used.

```swift
enum UsernameError: Error {
    case empty
    case tooShort
    case containsSpace
}

func checkUsername(_ name: String, completion: (Result<String, UsernameError>) -> Void) {
    let result: Result<String, UsernameError>
    if name.isEmpty {
        result = .failure(.empty)
    } else if name.count < 3 {
        result = .failure(.tooShort)
    } else if name.contains(" ") {
        result = .failure(.containsSpace)
    } else {
        result = .success(name)
    }
    completion(result)
}

for name in ["", "al", "ana maria", "ana"] {
    checkUsername(name) { result in
        switch result {
        case .success(let name):
            print("ok: \(name)")
        case .failure(let error):
            print("rejected \"\(name)\": \(error)")
        }
    }
}
```

```output
rejected "": empty
rejected "al": tooShort
rejected "ana maria": containsSpace
ok: ana
```

Forget a branch and it doesn't compile:

```swift no-compile constant 'result' used before being initialized
enum UsernameError: Error {
    case empty
    case tooShort
}

func checkUsername(_ name: String, completion: (Result<String, UsernameError>) -> Void) {
    let result: Result<String, UsernameError>
    if name.isEmpty {
        result = .failure(.empty)
    } else if name.count < 3 {
        print("too short")
    } else {
        result = .success(name)
    }
    completion(result)
}
```

Swift 6.3: `error: constant 'result' used before being initialized`. Assigning it twice is also an error, because it's a `let`. When the handler is called asynchronously, from inside another callback, `defer` can't help in the same way (it runs when the outer function returns, not when the work finishes), so this pattern, or the `async` version at the end of the lesson, is the reliable tool.

### Result as the callback's argument

`(Result<String, UsernameError>) -> Void` beats the older shape `(String?, Error?) -> Void`, which allows four combinations of which only two make sense ("both nil?" "both set?"). With `Result`, there are exactly two cases, and `switch` makes the caller handle both. You met `Result` in Module 12, lesson 4; callbacks are where it's used most.

## Callback pyramids

Real work often has steps that depend on each other: log in, then load the profile with the token, then load the avatar from the profile's URL. With completion handlers, each step goes inside the previous one's callback. This fake API stores each response and delivers it later, like a network would, when `deliverAll()` runs:

```swift
enum APIError: Error {
    case unauthorized
    case missing(String)
}

final class FakeAPI {
    private var pending: [() -> Void] = []

    func logIn(password: String, completion: @escaping (Result<String, APIError>) -> Void) {
        pending.append {
            completion(password == "swift" ? .success("token-1") : .failure(.unauthorized))
        }
    }

    func loadProfile(token: String, completion: @escaping (Result<String, APIError>) -> Void) {
        pending.append { completion(.success("avatars/ana.png")) }
    }

    func loadAvatar(path: String, completion: @escaping (Result<Int, APIError>) -> Void) {
        pending.append { completion(.success(2048)) }
    }

    func deliverAll() {
        while !pending.isEmpty {
            let next = pending.removeFirst()
            next()
        }
    }
}

func showHome(password: String, api: FakeAPI) {
    api.logIn(password: password) { result in
        switch result {
        case .failure(let error):
            print("login failed: \(error)")
        case .success(let token):
            api.loadProfile(token: token) { result in
                switch result {
                case .failure(let error):
                    print("profile failed: \(error)")
                case .success(let path):
                    api.loadAvatar(path: path) { result in
                        switch result {
                        case .failure(let error):
                            print("avatar failed: \(error)")
                        case .success(let bytes):
                            print("home ready, avatar \(bytes) bytes")
                        }
                    }
                }
            }
        }
    }
    print("requested home")
}

let api = FakeAPI()
showHome(password: "swift", api: api)
showHome(password: "java", api: api)
api.deliverAll()
```

```output
requested home
requested home
login failed: unauthorized
home ready, avatar 2048 bytes
```

The shape gives it away: the code drifts right with every step, the same `switch` appears three times, and it's hard to see where a step could forget to report. The output order is a reminder that both `showHome` calls returned before any response arrived, and that the failure for the second login came back before the first chain finished, because the first chain needed two more round trips.

Two ways out:

- **Named steps.** Give each step its own function that receives the previous result and calls the next. The nesting disappears, and each function is small enough to check by eye. Exercise 6 does this.
- **`async`/`await`.** The same chain becomes three lines: `let token = try await logIn(…)`, `let path = try await loadProfile(…)`, `let bytes = try await loadAvatar(…)`, with one `catch`. That's Module 29. Until then, here's how you'll connect the two worlds.

## A preview: from callback to async

Many APIs you'll use only have a callback version. Swift's `withCheckedThrowingContinuation` lets you write an `async` wrapper around one: it suspends the calling task and gives you a **continuation**, which you resume from inside the callback.

```swift
struct User {
    let id: Int
    let name: String
}

enum LoadError: Error {
    case notFound(Int)
}

final class UserAPI {
    private let users = [1: "Ana", 2: "Ben"]

    func loadUser(id: Int, completion: @escaping (Result<User, LoadError>) -> Void) {
        if let name = users[id] {
            completion(.success(User(id: id, name: name)))
        } else {
            completion(.failure(.notFound(id)))
        }
    }
}

func loadUser(id: Int, from api: UserAPI) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        api.loadUser(id: id) { result in
            continuation.resume(with: result)
        }
    }
}

let api = UserAPI()
do {
    let user = try await loadUser(id: 1, from: api)
    print(user.name)
    let missing = try await loadUser(id: 9, from: api)
    print(missing.name)
} catch {
    print("failed: \(error)")
}
```

```output
Ana
failed: notFound(9)
```

- `withCheckedThrowingContinuation` runs the closure right away and suspends `loadUser` until the continuation is resumed.
- `continuation.resume(with: result)` turns a `Result` into either a return value or a thrown error. There are also `resume(returning:)` and `resume(throwing:)`.
- The caller writes `try await` and a normal `do`/`catch`. No pyramid.

The continuation inherits the completion handler's rule and enforces it. Apple's documentation for `CheckedContinuation`: "You must call a resume method exactly once on every execution path." Never resuming leaves the task suspended forever; resuming twice stops the program:

```swift runtime-error tried to resume its continuation more than once
func loadName(completion: @escaping (String) -> Void) {
    completion("Ana")
    completion("Ana again")
}

func name() async -> String {
    await withCheckedContinuation { continuation in
        loadName { name in
            continuation.resume(returning: name)
        }
    }
}

print(await name())
```

Swift 6.3 stops with `Fatal error: SWIFT TASK CONTINUATION MISUSE: name() tried to resume its continuation more than once, returning Ana again!`. So a callback API that calls its handler twice (some report progress through the same closure) can't be wrapped this way; it needs an `AsyncStream`, which Module 29 covers along with isolation, `Sendable` and what "suspends" really means. For now, the takeaway: **once on every path** is the contract for completion handlers and continuations alike.

## Common mistakes

> [!error] A missing return after reporting a failure
> `if bad { completion(.failure(…)) }` without `return` falls through to the success path and calls the handler again. Use `guard … else { completion(…); return }`, or the single `let result` pattern.

> [!error] An exit path that never calls the handler
> An early `return` inside a validation or a `guard` that doesn't report leaves the caller waiting forever. Every `return` in a function with a completion handler should be right after a call to it.

> [!error] Capturing an index instead of an identifier
> A row callback that captures `indexPath` or a position in an array acts on the wrong item after the list changes. Capture the item's id.

> [!error] Assigning a stored callback twice and expecting both to run
> `stepper.onChange = a` followed by `stepper.onChange = b` keeps only `b`. Closure properties are one-to-one, like delegates.

> [!error] Capturing self strongly in a closure that self ends up storing
> `stepper.onChange = { self.total = … }` inside the stepper's owner creates a cycle. Capture `[weak self]`, or only the values you need. Lesson 4 is about finding these.

## Exercises

````exercise
id: m26-l02-e1
type: prediction
prompt: "A save function has a validation bug. What does it print?"
code: |
  func save(_ title: String, completion: (Bool) -> Void) {
      if title.isEmpty {
          completion(false)
      }
      if title.count > 10 {
          return
      }
      completion(true)
  }

  var results: [Bool] = []
  for title in ["", "Groceries", "Weekend trip plan"] {
      save(title) { ok in
          results.append(ok)
      }
      print("\(title.count): \(results.count) result(s) so far")
  }
  print(results)
output: |
  0: 2 result(s) so far
  9: 3 result(s) so far
  17: 3 result(s) so far
  [false, true, true]
hints:
  - "The first if has no return."
  - "What does the second if do for a long title?"
solution: |
  ```output
  0: 2 result(s) so far
  9: 3 result(s) so far
  17: 3 result(s) so far
  [false, true, true]
  ```

  The empty title calls the handler with `false`, falls through (no `return`), passes the length check and calls it again with `true`: two results for one save. `"Groceries"` adds one `true`. `"Weekend trip plan"` has 17 characters, so the function returns without calling the handler at all. The array ends with three results for three saves, and two of them are wrong. With a single `let result: Bool` assigned in every branch and one `completion(result)` at the end, both bugs become compile errors.
````

````exercise
id: m26-l02-e2
type: prediction
prompt: "Responses are delivered later by a queue. What's the order of the prints?"
code: |
  final class Network {
      private var pending: [() -> Void] = []
      func request(_ path: String, completion: @escaping (String) -> Void) {
          print("send \(path)")
          pending.append { completion("body of \(path)") }
      }
      func deliverAll() {
          while !pending.isEmpty {
              pending.removeFirst()()
          }
      }
  }

  let network = Network()
  network.request("/user") { body in
      print("got \(body)")
      network.request("/orders") { body in
          print("got \(body)")
      }
  }
  network.request("/news") { body in
      print("got \(body)")
  }
  print("all sent")
  network.deliverAll()
output: |
  send /user
  send /news
  all sent
  got body of /user
  send /orders
  got body of /news
  got body of /orders
hints:
  - "request prints and stores a job; it doesn't call completion."
  - "/orders is only requested once /user's response arrives, and its job goes to the end of the queue."
solution: |
  ```output
  send /user
  send /news
  all sent
  got body of /user
  send /orders
  got body of /news
  got body of /orders
  ```

  Both top-level requests are sent before anything is delivered, so `all sent` comes third. `deliverAll` runs the queue in order: `/user`'s completion prints and **sends** `/orders`, whose job joins the end of the queue, behind `/news`. That's the dependency a callback chain encodes: the second request can't start until the first callback runs.
````

````exercise
id: m26-l02-e3
type: fill-in
prompt: "Complete the async wrapper around a Result-based callback API."
code: |
  func fetchScore(for player: String, completion: @escaping (Result<Int, ScoreError>) -> Void) {
      // calls completion exactly once
  }

  func score(for player: String) async throws -> Int {
      try await [[1]] { continuation in
          fetchScore(for: player) { result in
              continuation.[[2]](with: result)
          }
      }
  }

  // Caller:
  do {
      let points = [[3]] score(for: "ana")
      print(points)
  } catch {
      print(error)
  }
blanks:
  - id: "1"
    answers: ["withCheckedThrowingContinuation"]
  - id: "2"
    answers: ["resume"]
  - id: "3"
    answers: ["try await"]
hints:
  - "The wrapper can throw, so it needs the throwing variant."
  - "resume(with:) takes a Result."
solution: |
  ```swift illustrative
  func score(for player: String) async throws -> Int {
      try await withCheckedThrowingContinuation { continuation in
          fetchScore(for: player) { result in
              continuation.resume(with: result)
          }
      }
  }

  let points = try await score(for: "ana")
  ```

  `withCheckedThrowingContinuation` because the result can be a failure; `withCheckedContinuation` is for callbacks that can't fail. `resume(with:)` returns the success value or throws the failure. The caller marks both possibilities: `try` for the error, `await` for the suspension.
````

````exercise
id: m26-l02-e4
type: find-errors
prompt: "A view model loads a profile with a callback API and exposes a callback to its screen. Mark every real problem."
code: |
  final class ProfileViewModel {
      var onUpdate: ((String) -> Void)?
      private let api: ProfileAPI

      init(api: ProfileAPI) {
          self.api = api
      }

      func load(userID: Int, completion: @escaping (Result<String, ProfileError>) -> Void) {
          guard userID > 0 else { return }
          api.fetchName(userID) { result in
              switch result {
              case .success(let name):
                  self.onUpdate?(name)
                  completion(.success(name))
              case .failure(let error):
                  completion(.failure(error))
              }
              completion(result)
          }
      }
  }

  final class ProfileScreen {
      let viewModel: ProfileViewModel
      var title = ""

      init(viewModel: ProfileViewModel) {
          self.viewModel = viewModel
          viewModel.onUpdate = { name in
              self.title = name
          }
      }
  }
choices:
  - text: "load never calls completion when userID isn't positive."
    correct: true
  - text: "completion is called twice on every response: once in the switch and again after it."
    correct: true
  - text: "ProfileScreen owns the view model and the view model's onUpdate closure captures the screen strongly: a cycle."
    correct: true
  - text: "onUpdate must be declared @escaping."
    correct: false
  - text: "A Result-based completion can't be used with switch."
    correct: false
rubric:
  - Finds the guard that returns without calling completion.
  - Finds the double call.
  - Finds the strong capture of self in onUpdate.
solution: |
  1. **Silent exit.** `guard userID > 0 else { return }` leaves the caller waiting. Report it: `else { completion(.failure(.invalidID)); return }`.
  2. **Double call.** Each branch of the `switch` calls `completion`, and then `completion(result)` runs again. Keep one: the `switch` is only needed for the `onUpdate` side effect, so `if case .success(let name) = result { onUpdate?(name) }` followed by a single `completion(result)` is enough.
  3. **Cycle.** The screen owns the view model, the view model owns `onUpdate`, and the closure owns the screen. Use `{ [weak self] name in self?.title = name }`.

  Optional closure properties are already escaping (`@escaping` is only for parameters), and `switch` over a `Result` is the normal way to handle it. The `self.onUpdate` capture in `load` is fine: the API holds that closure only until it responds.
````

````exercise
id: m26-l02-e5
type: solve
prompt: |
  Write `func parseAge(_ text: String, completion: (Result<Int, AgeError>) -> Void)` with this enum:

  ```swift
  enum AgeError: Error {
      case empty
      case notANumber(String)
      case outOfRange(Int)
  }
  ```

  - Empty text (after trimming nothing, just `text.isEmpty`) is `.empty`.
  - Text that isn't an integer is `.notANumber(text)`.
  - A number outside `0...130` is `.outOfRange(number)`.
  - Otherwise `.success(number)`.

  The handler must be called exactly once on every path, and the compiler should be able to prove it: use a single `let result` and one call at the end.

  This code:

  ```swift
  for text in ["", "abc", "200", "42"] {
      parseAge(text) { result in
          switch result {
          case .success(let age): print("age \(age)")
          case .failure(let error): print("error: \(error)")
          }
      }
  }
  ```

  should print:

  ```plaintext
  error: empty
  error: notANumber("abc")
  error: outOfRange(200)
  age 42
  ```
starter: |
  enum AgeError: Error {
      case empty
      case notANumber(String)
      case outOfRange(Int)
  }

  func parseAge(_ text: String, completion: (Result<Int, AgeError>) -> Void) {
      // your code
  }
hints:
  - "let result: Result<Int, AgeError> with no value, then if / else if / else."
  - "Int(text) returns nil for text that isn't an integer."
  - "if let number = Int(text) can sit inside an else branch."
rubric:
  - Declares let result without a value and assigns it in every branch.
  - Calls completion exactly once, after the branches.
  - Handles all four cases in the right order.
  - The output matches.
solution: |
  ```swift
  enum AgeError: Error {
      case empty
      case notANumber(String)
      case outOfRange(Int)
  }

  func parseAge(_ text: String, completion: (Result<Int, AgeError>) -> Void) {
      let result: Result<Int, AgeError>
      if text.isEmpty {
          result = .failure(.empty)
      } else if let number = Int(text) {
          if (0...130).contains(number) {
              result = .success(number)
          } else {
              result = .failure(.outOfRange(number))
          }
      } else {
          result = .failure(.notANumber(text))
      }
      completion(result)
  }

  for text in ["", "abc", "200", "42"] {
      parseAge(text) { result in
          switch result {
          case .success(let age): print("age \(age)")
          case .failure(let error): print("error: \(error)")
          }
      }
  }
  ```

  ```output
  error: empty
  error: notANumber("abc")
  error: outOfRange(200)
  age 42
  ```

  Every branch assigns `result` once, and there's exactly one call to `completion`. If you delete any assignment, Swift reports `constant 'result' used before being initialized`; if you add a second one, it reports that the constant was already initialized. `completion` isn't `@escaping` here because it's called before the function returns. The day this function becomes asynchronous, the same structure moves inside the callback.
````

````exercise
id: m26-l02-e6
type: refactor
prompt: |
  Flatten this checkout pyramid without `async`/`await`. Each step should be its own method that handles one result and starts the next step, and every failure should end in the same `finish(_:)` method. Keep the behavior: reserve stock, then charge the card, then create the order.
code: |
  final class Checkout {
      let api: ShopAPI
      init(api: ShopAPI) { self.api = api }

      func start(cart: Cart, completion: @escaping (Result<String, ShopError>) -> Void) {
          api.reserve(cart) { result in
              switch result {
              case .failure(let error):
                  completion(.failure(error))
              case .success(let reservation):
                  self.api.charge(cart.total) { result in
                      switch result {
                      case .failure(let error):
                          completion(.failure(error))
                      case .success(let payment):
                          self.api.createOrder(reservation, payment) { result in
                              switch result {
                              case .failure(let error):
                                  completion(.failure(error))
                              case .success(let orderID):
                                  completion(.success(orderID))
                              }
                          }
                      }
                  }
              }
          }
      }
  }
rubric:
  - Each step (reserve, charge, create order) is a separate method with one level of nesting.
  - Failures from any step go through one place that calls completion.
  - completion is called exactly once on every path.
  - The order of the steps and the values passed between them are unchanged.
  - Mentions that async/await (Module 29) would make this a straight sequence.
solution: |
  ```swift illustrative
  final class Checkout {
      let api: ShopAPI
      private var completion: ((Result<String, ShopError>) -> Void)?

      init(api: ShopAPI) { self.api = api }

      func start(cart: Cart, completion: @escaping (Result<String, ShopError>) -> Void) {
          self.completion = completion
          api.reserve(cart) { result in
              switch result {
              case .failure(let error): self.finish(.failure(error))
              case .success(let reservation): self.charge(cart, reservation: reservation)
              }
          }
      }

      private func charge(_ cart: Cart, reservation: Reservation) {
          api.charge(cart.total) { result in
              switch result {
              case .failure(let error): self.finish(.failure(error))
              case .success(let payment): self.createOrder(reservation, payment: payment)
              }
          }
      }

      private func createOrder(_ reservation: Reservation, payment: Payment) {
          api.createOrder(reservation, payment) { result in
              self.finish(result)
          }
      }

      private func finish(_ result: Result<String, ShopError>) {
          let completion = self.completion
          self.completion = nil
          completion?(result)
      }
  }
  ```

  Each method does one step and knows only the next one. `finish(_:)` is the single exit: it clears the stored handler before calling it, so even a buggy step that reports twice can't call the original handler a second time. The `self` captures here are deliberate: a checkout in progress should stay alive until it finishes, and the API drops each closure once it responds, so no cycle remains. With `async`/`await` the whole thing becomes `let reservation = try await api.reserve(cart)`, `let payment = try await api.charge(cart.total)`, `return try await api.createOrder(reservation, payment)`.
````

## Summary

- A closure property (`var onChange: ((Int) -> Void)?`) is the lightest way for a child to report one event to its owner. A required callback goes in `init` as an `@escaping` parameter stored in a `let`. Either way it's one-to-one: a second assignment replaces the first.
- Capture what the closure needs: `[weak self]` when self owns whatever stores the closure, values such as `[id = item.id]` for data, nothing if it's self-contained. Capture identifiers, never indexes.
- A completion handler must run exactly once on every path. Declare `let result` without a value, assign it in every branch and call the handler once: the compiler then rejects a missing or second assignment.
- `Result<Success, Failure>` makes a callback carry exactly one outcome, and `switch` makes the caller handle both.
- Nested completion handlers drift right and repeat error handling. Split them into named steps with one exit, or use `async`/`await`.
- `withCheckedThrowingContinuation` wraps a callback API in an `async` function; `resume(with:)` bridges a `Result`. Resume exactly once: twice stops the program, never leaves the task suspended.
