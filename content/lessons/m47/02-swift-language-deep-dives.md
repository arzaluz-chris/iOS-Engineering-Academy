---
id: m47-l02
title: Swift language deep dives
description: "Four language questions taken past the first answer, each with a demonstration you can run: when an array really copies and how to count your own copies, what an existential loses compared with a generic, when a capture list is evaluated and how a cycle forms without self, and what typed throws change for callers. Every claim is backed by code that was compiled and run."
module: m47
order: 2
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l01]
objectives:
  - Show when an array shares its buffer and when it copies, and count the copies a custom copy-on-write type makes.
  - Explain what calling a member through `any P` erases, and recover the type with a primary associated type or existential opening.
  - Predict what a capture list captures and when, and find a retain cycle that doesn't involve self.
  - Explain what typed throws change for exhaustiveness, generic error propagation and composition.
  - Back each answer with a demonstration small enough to describe out loud.
terms:
  - term: Copy-on-write
    definition: "A value type shares its storage between copies and duplicates it only when a copy that isn't the sole owner is about to be mutated. Array, Dictionary, Set and String do it; your own types do it only if you write it."
  - term: Existential
    definition: "A value of type `any P`: a box that can hold any concrete type conforming to P. Members are called through the protocol's witness table, and associated types are erased to their bounds."
  - term: Primary associated type
    definition: "An associated type listed in angle brackets after the protocol name (`protocol Store<Item>`), so you can write constrained types like `any Store<String>` or `some Collection<Int>` (SE-0346)."
  - term: Existential opening
    definition: "Passing an `any P` value to a generic parameter: the compiler unboxes it and binds the generic parameter to the concrete type inside (SE-0352)."
  - term: Capture list
    definition: "The `[a, weak b, unowned c]` list at the start of a closure. Each entry is evaluated once, when the closure is created, and captured as that value."
  - term: Typed throws
    definition: "A function declared `throws(E)` can throw only errors of type E, so callers' `catch` blocks know the type (SE-0413, Swift 6.0)."
mastery:
  - Prove with a short program that an array assignment shares storage and the first mutation copies it.
  - Write a copy-on-write wrapper with `isKnownUniquelyReferenced` and show how many copies a sequence of operations makes.
  - Explain why `store.first()` on an `any Store` has type `Any`, and fix it two ways.
  - Trace a retain cycle between two objects and a closure, and break it with a weak capture.
  - Say when typed throws are worth it and when plain `throws` composes better.
resources: [swift-book-structures-classes, swift-book-opaque-types, swift-book-generics, swift-book-closures, swift-book-arc, swift-book-error-handling]
cards:
  - id: m47-l02-c1
    front: "After `var copy = original` (both arrays), do they share storage? After `copy[0] = 10`?"
    back: "After the assignment, yes: both point to the same buffer. The first mutation of `copy` finds the buffer shared and duplicates it, so after `copy[0] = 10` they don't."
  - id: m47-l02-c2
    front: "Given `protocol Store { associatedtype Item; func first() -> Item }`, what's the type of `store.first()` when `store` is `any Store`?"
    back: "`Any`. The associated type is erased to its upper bound. Declare a primary associated type (`protocol Store<Item>`) and use `any Store<String>`, or pass the existential to a generic function to open it."
  - id: m47-l02-c3
    front: When is a capture list entry evaluated?
    back: "Once, when the closure is created. `[threshold]` captures the value at that moment; a variable used without a capture list is captured by reference and the closure sees later changes."
  - id: m47-l02-c4
    front: Can a retain cycle form without self?
    back: "Yes. A parent owns a child, the child stores a closure, and the closure captures the parent strongly. Capture the parent weakly to break it."
  - id: m47-l02-c5
    front: "A function declared `throws(ParseError)` calls one that `throws(NetworkError)`. What happens?"
    back: "It doesn't compile: \"thrown expression type 'NetworkError' cannot be converted to error type 'ParseError'\". Catch and map the error, widen to an enum that wraps both, or declare plain `throws`."
---

## The idea in one sentence

A deep answer about the language is a claim you can demonstrate: each section below takes a question past its textbook answer and shows the program that proves it.

> [!note] What this lesson builds on
> Module 9 (structs), Module 10 (classes, protocols, `some` and `any`), Module 11 (generics and closures), Module 12 (errors) and Module 13 (ARC). The bank already has the first-level questions, such as the difference between structs and classes, `some` versus `any`, and closures that capture `self`. These sections start where those answers stop. Each one follows lesson 1's shape, and every block was compiled and run with Swift 6.3.

## Value semantics and copy-on-write

**The question:** "You say arrays are copied on write. Show me when the copy actually happens."

**Direct answer.** "Assigning an array or passing it to a function shares the buffer. The copy happens on the first mutation through a variable whose buffer is shared."

**Mechanism.** "`Array` stores its elements in a reference-counted heap buffer. Before a mutation, it checks whether it's the buffer's only owner; if not, it allocates a new buffer, copies the elements and mutates that."

**Example.** You can watch it happen by comparing buffer addresses. `withUnsafeBufferPointer` gives temporary access to the buffer, and `baseAddress` is where the elements start:

```swift
func sharesStorage(_ a: [Int], _ b: [Int]) -> Bool {
    a.withUnsafeBufferPointer { first in
        b.withUnsafeBufferPointer { second in first.baseAddress == second.baseAddress }
    }
}

func doubled(_ values: [Int]) -> [Int] {
    var result = values
    for index in result.indices { result[index] *= 2 }
    return result
}

let original = [1, 2, 3]
var copy = original
print("after assignment:", sharesStorage(original, copy))
copy[0] = 10
print("after mutation:", sharesStorage(original, copy))
print(original, copy, doubled(original))
```

```output
after assignment: true
after mutation: false
[1, 2, 3] [10, 2, 3] [2, 4, 6]
```

Passing `original` to `sharesStorage` and to `doubled` copied nothing. Inside `doubled`, `result` shared the buffer until the first `result[index] *= 2`, which copied it once; the remaining iterations mutated the now-unique buffer in place.

That address comparison is a debugging trick, not something to ship: the pointer is only valid inside the closure, and buffer identity is an implementation detail. As evidence in an interview, it's convincing.

**Trade-off.** "Assignment is O(1), but the first mutation of a shared array is O(n). Code that keeps an extra copy around, like a snapshot for undo, pays that copy on every first write after a snapshot."

**When it breaks.** Two places. First, your own types don't get copy-on-write unless you write it. Second, a struct that holds a class reference copies the reference, not the object, so two "independent" values share mutable state, even when both are `let`:

```swift
final class Tags {
    var items: [String] = []
}

struct Article {
    let title: String
    let tags: Tags
}

let original = Article(title: "COW", tags: Tags())
let copy = original
copy.tags.items.append("swift")
print(original.tags.items)
```

```output
["swift"]
```

`let` makes the reference constant, not the object it points to.

### Counting your own copies

The follow-up is usually "how would you give your own type copy-on-write?" The bank's answer shows the `isKnownUniquelyReferenced` pattern. A deeper answer proves how many copies it makes. Here the storage carries a log object so the program can count:

```swift
final class CopyLog {
    var copies = 0
}

final class Storage {
    var values: [Int]
    let log: CopyLog

    init(values: [Int], log: CopyLog) {
        self.values = values
        self.log = log
    }
}

struct Ledger {
    private var storage: Storage

    init(log: CopyLog) {
        storage = Storage(values: [], log: log)
    }

    var values: [Int] { storage.values }

    mutating func append(_ value: Int) {
        if !isKnownUniquelyReferenced(&storage) {
            storage.log.copies += 1
            storage = Storage(values: storage.values, log: storage.log)
        }
        storage.values.append(value)
    }
}

let log = CopyLog()
var ledger = Ledger(log: log)
ledger.append(1)
let snapshot = ledger
ledger.append(2)
ledger.append(3)
print(snapshot.values, ledger.values, "copies:", log.copies)
```

```output
[1] [1, 2, 3] copies: 1
```

Walkthrough:

- `ledger.append(1)`: the storage has one owner, so no copy.
- `let snapshot = ledger`: two `Ledger` values now reference one `Storage`.
- `ledger.append(2)`: `isKnownUniquelyReferenced` returns `false`, so `ledger` gets its own storage. One copy.
- `ledger.append(3)`: `ledger`'s new storage has one owner, so it mutates in place.

The check needs `&storage` because it's an in-out parameter: the function inspects the reference without adding a retain of its own. Every mutating path must go through the check, which is why `storage` is `private`.

> [!error] A computed property that hands out the class
> If `Ledger` exposed `var storage: Storage { _storage }`, callers could mutate the shared object directly and skip the uniqueness check. Copy-on-write only works if the class never escapes the struct.

## Existentials and generics

**The question:** "You have `protocol Store { associatedtype Item; func first() -> Item }`. What do you lose by storing one as `any Store`?"

**Direct answer.** "The associated type. Through `any Store`, `first()` returns `Any`, because the box could hold a store of any item type."

**Mechanism.** "An existential erases the concrete type. When a member's result uses an associated type, Swift replaces it with that type's upper bound, which for an unconstrained `Item` is `Any`." Try to use the result as a `String`:

```swift no-compile value of type 'Any' has no member 'count'
protocol Store {
    associatedtype Item
    func first() -> Item
}

struct NameStore: Store {
    func first() -> String { "Ada" }
}

let store: any Store = NameStore()
print(store.first().count)
```

Swift 6.3 reports `value of type 'Any' has no member 'count'`. At run time the value is still a `String`; the static type is what was lost.

**Example: two fixes.** Declare `Item` as a **primary associated type** so the existential can carry it, and pass existentials to a generic function so the compiler **opens** them:

```swift
protocol Store<Item> {
    associatedtype Item
    func first() -> Item
}

struct NameStore: Store {
    func first() -> String { "Ada" }
}

struct ScoreStore: Store {
    func first() -> Int { 42 }
}

let names: any Store<String> = NameStore()
print(names.first().count)

func describe(_ store: some Store) -> String {
    "\(type(of: store)) starts with \(store.first())"
}

let stores: [any Store] = [NameStore(), ScoreStore()]
for store in stores {
    print(describe(store))
}
```

```output
3
NameStore starts with Ada
ScoreStore starts with 42
```

- `any Store<String>` fixes `Item` to `String`, so `first()` returns `String`.
- `describe(_:)` is generic (`some Store` in parameter position is an anonymous generic parameter). Passing an `any Store` opens the box and binds the parameter to `NameStore`, then to `ScoreStore`; inside, `store.first()` has the concrete item type.
- The array still needs `[any Store]`: its elements have different types, which a generic `[S]` can't hold.

**Trade-off.** "Generics are resolved per concrete type: calls can be specialized and inlined, and values are stored directly. Existentials give you heterogeneous collections and values whose type changes at run time, at the cost of a box and witness-table calls. Default to generics; reach for `any` when you need the heterogeneity."

**When it breaks.** `some` as a **return** type is the reverse: the function picks one concrete type, so it can't return different types on different paths.

```swift no-compile do not have matching underlying types
protocol Shape {
    func area() -> Int
}

struct Square: Shape {
    let side: Int
    func area() -> Int { side * side }
}

struct Rectangle: Shape {
    let width: Int
    let height: Int
    func area() -> Int { width * height }
}

func makeShape(square: Bool) -> some Shape {
    if square { return Square(side: 2) }
    return Rectangle(width: 2, height: 3)
}
```

Swift 6.3: `function declares an opaque return type 'some Shape', but the return statements in its body do not have matching underlying types`. Return `any Shape` if the type really varies, or make both paths produce the same type. The bank's "some and any in depth" question covers why two `any Equatable` values can't be compared; this is the companion case.

## ARC and capture lists

**The question:** "When is a capture list evaluated, and what does it actually hold?"

**Direct answer.** "Once, when the closure is created. Each entry captures the value it had at that moment. Variables used without a capture list are captured by reference, so the closure sees later changes."

**Example.**

```swift
var threshold = 10
let captured = { [threshold] in print("captured:", threshold) }
let live = { print("live:", threshold) }
threshold = 99
captured()
live()
```

```output
captured: 10
live: 99
```

**Mechanism.** "`[threshold]` declares a new constant inside the closure, initialized when the closure expression is evaluated. For a class reference, that constant is a strong reference to the object, not a copy of the object; `[weak x]` makes it a weak reference and `[unowned x]` an unowned one."

### A cycle without self

The follow-up interviewers like: "Can you get a retain cycle without `self`?" Yes, whenever a closure ends up stored by something the captured object owns:

```swift
final class Parent {
    let name: String
    var child: Child?
    init(name: String) { self.name = name }
    deinit { print("deinit Parent") }
}

final class Child {
    var onTap: (() -> Void)?
    deinit { print("deinit Child") }
}

func makeScreen(fixed: Bool) {
    let parent = Parent(name: "Settings")
    let child = Child()
    parent.child = child
    if fixed {
        child.onTap = { [weak parent] in print(parent?.name ?? "gone") }
    } else {
        child.onTap = { print(parent.name) }
    }
}

print("leaky:")
makeScreen(fixed: false)
print("fixed:")
makeScreen(fixed: true)
print("end")
```

```output
leaky:
fixed:
deinit Parent
deinit Child
end
```

In the leaky version, `parent → child → onTap → parent` is a cycle of strong references, so when the function's local constants go away nothing reaches zero and neither `deinit` runs. In the fixed version, the closure's reference to `parent` is weak: the parent is freed, which releases the child, which releases the closure.

**Trade-off.** "`weak` costs an optional and a check at every use. `unowned` avoids the optional, but it's a promise that the object outlives the closure."

**When it breaks.** Break that promise and the program traps:

```swift runtime-error Attempted to read an unowned reference
final class Session {
    let user: String
    init(user: String) { self.user = user }
    deinit { print("deinit Session") }
}

var session: Session? = Session(user: "ada")
let greet = { [unowned currentSession = session!] in print("hi \(currentSession.user)") }
greet()
session = nil
greet()
```

```output
hi ada
deinit Session
```

The second call stops the program. Swift 6.3 on Linux printed `Fatal error: Attempted to read an unowned reference but object 0x… was already destroyed`, with a different address on every run. It's a deterministic trap, not undefined behavior, which is the one advantage `unowned` has over `unowned(unsafe)`.

## Error handling

**The question:** "What do typed throws change for the caller?"

**Direct answer.** "The caller's `catch` knows the error's type. With `throws(ParseError)`, the error in `catch` is a `ParseError`, so a `switch` over it is exhaustive without a default."

**Example.**

```swift
enum ParseError: Error {
    case empty
    case notANumber(String)
}

func parseQuantity(_ text: String) throws(ParseError) -> Int {
    guard !text.isEmpty else { throw .empty }
    guard let value = Int(text) else { throw .notANumber(text) }
    return value
}

for input in ["3", "", "x"] {
    do {
        print(try parseQuantity(input))
    } catch {
        switch error {
        case .empty: print("empty")
        case .notANumber(let text): print("not a number: \(text)")
        }
    }
}
```

```output
3
empty
not a number: x
```

**Mechanism.** "The `do` block's thrown type is inferred from what it calls. Only `parseQuantity` throws, so `error` is `ParseError`. Plain `throws` is `throws(any Error)`, and a non-throwing function is `throws(Never)`, which is what makes typed throws work in generics."

That last point is the deep part. A generic function can throw exactly what its closure throws:

```swift
func withRetry<E: Error>(attempts: Int, _ body: () throws(E) -> Int) throws(E) -> Int {
    for _ in 1..<attempts {
        if let value = try? body() { return value }
    }
    return try body()
}

let plain = withRetry(attempts: 3) { 7 }
print(plain)
```

```output
7
```

The closure doesn't throw, so `E` is `Never` and the call needs no `try`. That's what `rethrows` did, but `rethrows` always rethrows `any Error`; the typed version preserves the concrete type when the closure throws one.

**Trade-off and when it breaks.** Typed throws don't compose by themselves. A function that calls two different typed-throwing functions can't simply declare one of the types:

```swift no-compile thrown expression type 'NetworkError' cannot be converted to error type 'ParseError'
enum ParseError: Error { case empty }
enum NetworkError: Error { case offline }

func parse(_ text: String) throws(ParseError) -> Int {
    guard let value = Int(text) else { throw .empty }
    return value
}

func fetch() throws(NetworkError) -> String { "12" }

func loadQuantity() throws(ParseError) -> Int {
    let text = try fetch()
    return try parse(text)
}
```

You either catch and convert, define an error enum with a case for each source, or declare plain `throws`. That's why the Swift Evolution proposal (SE-0413) recommends plain `throws` for most code, and typed throws where the error set is closed and the caller really handles each case: a parser, a validator, a module's internal code, or generic code that passes errors through.

> [!tip] One more detail people get wrong
> `try?` on a function that returns an optional doesn't produce a double optional. Since Swift 5 (SE-0230), `try? lookup()` where `lookup()` returns `Int?` has type `Int?`: a thrown error and a returned `nil` look the same. If you need to tell them apart, use `do`/`catch`.

## Exercises

````exercise
id: m47-l02-e1
type: prediction
prompt: "A struct holds an array and a class instance. What does the program print?"
code: |
  final class Counter {
      var value = 0
  }

  struct Snapshot {
      var numbers: [Int]
      let counter: Counter
  }

  var first = Snapshot(numbers: [1], counter: Counter())
  var second = first
  second.numbers.append(2)
  second.counter.value += 1
  print(first.numbers, first.counter.value)
  print(second.numbers, second.counter.value)
output: |
  [1] 1
  [1, 2] 1
solution: |
  `var second = first` copies the struct: the array is shared until `second.numbers.append(2)` copies it, so `first.numbers` stays `[1]`. The `counter` property copies the reference, so both snapshots point to one `Counter`, and `second.counter.value += 1` is visible through `first`. (`let counter` compiles because `let` fixes the reference, not the object.)

  ```output
  [1] 1
  [1, 2] 1
  ```
````

````exercise
id: m47-l02-e2
type: prediction
prompt: "Closures are created in a loop, some with a capture list. What does the program print?"
code: |
  var count = 1
  var handlers: [() -> Void] = []
  for label in ["a", "b"] {
      handlers.append { [count] in print(label, count) }
      count += 1
  }
  handlers.append { print("live", count) }
  count = 100
  for handler in handlers {
      handler()
  }
output: |
  a 1
  b 2
  live 100
solution: |
  Each `[count]` is evaluated when its closure is created: 1 for "a", 2 for "b". The last closure has no capture list, so it reads `count` when it runs, after `count = 100`. (`label` is a new constant on every iteration, so each closure has its own.)

  ```output
  a 1
  b 2
  live 100
  ```
````

````exercise
id: m47-l02-e3
type: comprehension
multiple: true
prompt: "Which statements about `some`, `any` and generics are true? Select all that apply."
choices:
  - text: "`func f(_ x: some Store)` is equivalent to `func f<S: Store>(_ x: S)`."
    correct: true
    why: "In parameter position, `some` is an anonymous generic parameter (SE-0341)."
  - text: "Passing an `any Store` to `f` doesn't compile, because `f` needs a concrete type."
    correct: false
    why: "Since Swift 5.7 (SE-0352), the existential is opened and the generic parameter is bound to the type inside."
  - text: "Through `any Store`, a method returning `Item` gives you `Any` unless the existential constrains `Item`."
    correct: true
    why: "Associated types in results are erased to their upper bound. `any Store<String>` constrains it."
  - text: "A function returning `some Shape` can return a `Square` on one path and a `Rectangle` on another."
    correct: false
    why: "An opaque result has one underlying type. Different types need `any Shape`."
  - text: "`[any Store]` can hold a `NameStore` and a `ScoreStore`; a generic `[S]` can't."
    correct: true
    why: "A generic array has one element type. Heterogeneity is what existentials are for."
solution: |
  True: the first, third and fifth. Existential opening means you can pass `any Store` to a generic function, and an opaque return type always has exactly one underlying type.
````

````exercise
id: m47-l02-e4
type: find-errors
prompt: "This code is meant to give `Polyline` copy-on-write behavior. Which statements describe real problems?"
code: |
  final class PointStorage {
      var points: [Int] = []
  }

  struct Polyline {
      var storage = PointStorage()                         // line A

      mutating func add(_ point: Int) {
          if isKnownUniquelyReferenced(&storage) {         // line B
              let copy = PointStorage()
              copy.points = storage.points
              storage = copy
          }
          storage.points.append(point)
      }

      mutating func removeAll() {
          storage.points.removeAll()                       // line C
      }
  }
choices:
  - text: "Line A: `storage` isn't private, so callers can mutate the shared object directly and skip the check."
    correct: true
    why: "The class must never escape the struct, or the copy-on-write guarantee doesn't hold."
  - text: "Line B: the condition is inverted. It copies when the storage is unique and mutates in place when it's shared."
    correct: true
    why: "It should copy when `!isKnownUniquelyReferenced(&storage)`."
  - text: "Line C: `removeAll()` mutates the storage without the uniqueness check, so it also empties every copy."
    correct: true
    why: "Every mutating path has to go through the check."
  - text: "`isKnownUniquelyReferenced` needs `&` because it copies the storage."
    correct: false
    why: "It takes the reference in-out so it can inspect it without retaining it. It never copies."
rubric:
  - Finds the inverted condition.
  - Finds the mutating path that skips the check.
  - Notes that exposed storage defeats the pattern.
solution: |
  Three real problems: the storage is visible from outside, the uniqueness test is inverted, and `removeAll()` bypasses it. A fixed version, with a check that copies are independent:

  ```swift
  final class PointStorage {
      var points: [Int] = []
  }

  struct Polyline {
      private var storage = PointStorage()

      var points: [Int] { storage.points }

      private mutating func makeUnique() {
          if !isKnownUniquelyReferenced(&storage) {
              let copy = PointStorage()
              copy.points = storage.points
              storage = copy
          }
      }

      mutating func add(_ point: Int) {
          makeUnique()
          storage.points.append(point)
      }

      mutating func removeAll() {
          makeUnique()
          storage.points.removeAll()
      }
  }

  var route = Polyline()
  route.add(1)
  route.add(2)
  var draft = route
  draft.removeAll()
  print(route.points, draft.points)
  ```

  ```output
  [1, 2] []
  ```
````

````exercise
id: m47-l02-e5
type: solve
prompt: "Write `func parseAll(_ inputs: [String]) -> (values: [Int], errors: [String])` that uses the typed-throwing `parseQuantity` below, collects successful values in order and describes each failure with an exhaustive `switch` (no `default`). Print the result for `[\"4\", \"\", \"seven\", \"10\"]`."
starter: |
  enum ParseError: Error {
      case empty
      case notANumber(String)
  }

  func parseQuantity(_ text: String) throws(ParseError) -> Int {
      guard !text.isEmpty else { throw .empty }
      guard let value = Int(text) else { throw .notANumber(text) }
      return value
  }
rubric:
  - The catch block switches over ParseError without a default case.
  - Successful values and errors are both collected, in input order.
  - No force unwrapping or casting of the error.
solution: |
  ```swift
  enum ParseError: Error {
      case empty
      case notANumber(String)
  }

  func parseQuantity(_ text: String) throws(ParseError) -> Int {
      guard !text.isEmpty else { throw .empty }
      guard let value = Int(text) else { throw .notANumber(text) }
      return value
  }

  func parseAll(_ inputs: [String]) -> (values: [Int], errors: [String]) {
      var values: [Int] = []
      var errors: [String] = []
      for (index, input) in inputs.enumerated() {
          do {
              values.append(try parseQuantity(input))
          } catch {
              switch error {
              case .empty:
                  errors.append("#\(index): empty")
              case .notANumber(let text):
                  errors.append("#\(index): not a number (\(text))")
              }
          }
      }
      return (values, errors)
  }

  let result = parseAll(["4", "", "seven", "10"])
  print(result.values)
  for error in result.errors {
      print(error)
  }
  ```

  ```output
  [4, 10]
  #1: empty
  #2: not a number (seven)
  ```

  Because only `parseQuantity` throws inside `do`, the compiler infers `error` as `ParseError`; adding a new case to the enum would make this `switch` fail to compile, which is the point of typed throws here. If you called a second function that `throws(any Error)` inside the same `do`, `error` would become `any Error` and you'd need `default`.
````

````exercise
id: m47-l02-e6
type: explain
prompt: "An interviewer shows this and asks why `deinit` never prints, even though `self` appears nowhere. Explain the cycle and give the smallest fix."
code: |
  final class Player {
      var controls: Controls?
      deinit { print("deinit Player") }
      func pause() {}
  }

  final class Controls {
      var onPause: (() -> Void)?
  }

  func setUp() {
      let player = Player()
      let controls = Controls()
      player.controls = controls
      controls.onPause = { player.pause() }
  }
rubric:
  - Names the three strong references that form the cycle (player → controls → onPause closure → player).
  - Explains that the closure captures the local constant player strongly by default.
  - "Fixes it with [weak player] (and optional chaining), or by not storing the closure in something player owns."
solution: |
  `player` holds `controls` strongly, `controls` holds the `onPause` closure strongly, and the closure captures the local `player` strongly. When `setUp()` returns, its local constants go away, but each object in the loop still has one strong reference, so neither is freed. `self` isn't required: any capture of an object that (directly or indirectly) owns the closure closes the loop.

  ```swift
  final class Player {
      var controls: Controls?
      deinit { print("deinit Player") }
      func pause() {}
  }

  final class Controls {
      var onPause: (() -> Void)?
  }

  func setUp() {
      let player = Player()
      let controls = Controls()
      player.controls = controls
      controls.onPause = { [weak player] in player?.pause() }
  }

  setUp()
  print("after setUp")
  ```

  ```output
  deinit Player
  after setUp
  ```
````

## Summary

- Array assignment and argument passing share the buffer; the first mutation through a shared variable copies it once. Your own types need `isKnownUniquelyReferenced` on every mutating path, with the class kept private.
- A struct holding a class shares that object between copies, even through `let`.
- Through `any P`, results that use an associated type are erased to their bound. A primary associated type (`any Store<String>`) or existential opening (passing to `some Store`) gets the type back. Heterogeneous collections need `any`; an opaque return type has one underlying type.
- Capture lists are evaluated when the closure is created. A cycle needs only an object that owns, directly or not, a closure that captures it strongly; `self` is just the common case. Reading a deallocated `unowned` reference traps.
- Typed throws give callers a known error type and exhaustive `catch` switches, and let generic code pass through exactly what a closure throws (`Never` when it throws nothing). They don't compose across different error types without conversion, which is why plain `throws` is the default.
