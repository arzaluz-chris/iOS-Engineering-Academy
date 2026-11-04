---
id: m29-l05
title: Sendable and isolation
description: "How Swift 6 decides whether a value may cross from one isolation domain to another. You learn which types are Sendable and why, how @Sendable and sending closures differ, how region-based isolation lets a non-Sendable value move when you stop using it, how to read and fix the diagnostics you'll meet most in a Swift 6 codebase, what @unchecked Sendable really promises, and how isolated parameters and #isolation let a function run on its caller's actor."
module: m29
order: 5
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l04]
objectives:
  - Name the isolation domains in a program and the points where values cross between them.
  - Decide whether a struct, enum, class, actor or closure is Sendable, and make it Sendable honestly.
  - Explain the difference between a @Sendable closure and a sending parameter, and what region-based isolation allows.
  - Read and fix the common Swift 6 Sendable and isolation diagnostics.
  - Explain what @unchecked Sendable and nonisolated(unsafe) promise and when that promise holds.
  - Use an isolated parameter and an #isolation default so a function runs on its caller's actor.
terms:
  - term: Isolation domain
    definition: "A region of code whose mutable state is protected one way: one actor instance, a global actor such as the main actor, or nonisolated code where a value belongs to whichever task holds it."
  - term: Sendable
    definition: "A protocol (with no requirements) that marks a type as safe to share across isolation domains: no shared mutable state, or state protected by an actor or a lock."
  - term: "@Sendable closure"
    definition: "A closure type that can be called concurrently from several domains. It can only capture Sendable values, by value, and can't mutate captured variables."
  - term: sending
    definition: "A parameter or result modifier (SE-0430) saying the value is handed over to another domain. A non-Sendable value can be passed if the caller never uses it again."
  - term: Region-based isolation
    definition: "The Swift 6 analysis (SE-0414) that tracks groups of non-Sendable values that can reach each other, so a whole region can move to another domain safely when nothing left behind still uses it."
  - term: Isolated parameter
    definition: "A parameter declared isolated SomeActor (or isolated (any Actor)?) that makes the function run on that actor, with synchronous access to its state."
mastery:
  - Look at a type and say whether Swift infers Sendable for it, must be told, or can't be Sendable as written.
  - Fix "capture of non-Sendable type in a @Sendable closure" by changing the data, not by silencing the check.
  - Explain why passing a non-Sendable value to an actor compiles in one function and fails in another.
  - Return a Sendable snapshot from an actor instead of a non-Sendable reference.
  - Review an @unchecked Sendable class and say whether its promise holds.
  - "Write a helper that runs on whatever actor calls it, using isolation: isolated (any Actor)? = #isolation."
resources: [swift-sendable, swift-migration-guide, swift-evolution, swift-book, xcode-data-races, synchronization-mutex]
cards:
  - id: m29-l05-c1
    front: Which types are Sendable without you writing anything?
    back: "Non-public structs and enums whose stored properties or associated values are all Sendable, tuples of Sendable values, actors, @MainActor (global-actor) classes, and metatypes. Public structs need an explicit Sendable conformance."
  - id: m29-l05-c2
    front: "@Sendable closure vs sending closure?"
    back: "@Sendable: may run concurrently, possibly several times, so it can only capture Sendable values and can't mutate captures. sending (Task's operation): handed over once, so it may capture non-Sendable values as long as the caller doesn't touch them afterward."
  - id: m29-l05-c3
    front: "What does \"sending 'x' risks causing data races\" mean?"
    back: "You passed a non-Sendable value to another domain (an actor method, a Task, a sending parameter) and then used it again in the original one. Stop using it afterward, pass a copy, or make the type Sendable."
  - id: m29-l05-c4
    front: When is @unchecked Sendable honest?
    back: "When the class is final, every mutable stored property is private, and every access to it is synchronized (a lock, Mutex or serial queue). It turns off checking; it doesn't add safety."
  - id: m29-l05-c5
    front: "What does isolation: isolated (any Actor)? = #isolation do?"
    back: "It makes the function run on the caller's actor (or nonisolated if the caller is), because #isolation evaluates to the caller's isolation. Non-Sendable values from the caller don't cross a boundary."
---

## The idea in one sentence

Swift 6 checks every point where a value leaves one isolation domain for another, and lets it through only if the value is safe to share (`Sendable`) or provably no longer used by the code it left.

> [!note] What you already know
> Module 28, lessons 5 and 6 met the first Sendable errors: a completion handler that wasn't `@Sendable`, a captured `var` mutated in concurrent code, a non-Sendable class captured in a `@Sendable` closure, global mutable state, and `@unchecked Sendable` with a lock. Lessons 2 and 4 here hit `sending` errors in task groups and saw actors and `@MainActor`. This lesson puts the rules together. Everything was compiled with Swift 6.3 on Linux. Every `no-compile` example uses only types and closures declared in the example itself, so its diagnostic is an error on every platform; the section on Xcode explains when the same message is only a warning.

## Isolation domains and crossings

A Swift 6 program is divided into **isolation domains**:

- each **actor instance** is one;
- each **global actor** (the main actor, your own `@globalActor`) is one;
- **nonisolated** code isn't protected by an actor. A non-Sendable value there belongs to whichever task is running the code, and the compiler makes sure it stays that way.

Values cross between domains at a few kinds of places:

| Crossing | Example |
| --- | --- |
| Arguments to a call into another domain | `await store.add(order)` (into an actor) |
| Results coming back out | `let order = await store.latest()` |
| Captures in a closure that runs elsewhere | `Task { … }`, `group.addTask { … }`, a `@Sendable` callback |
| Global and static variables | reachable from every domain at once |

At each crossing, the compiler asks one question: could the domains on both sides end up touching the same mutable state at the same time? If the value is `Sendable`, the answer is no by construction. If it isn't, Swift 6's **region-based isolation** may still prove the answer is no; otherwise you get a diagnostic.

## Sendable types

Apple's documentation: `Sendable` is "a thread-safe type whose values can be shared across arbitrary concurrent contexts without introducing a risk of data races". The protocol has no methods; its requirements are checked by the compiler.

| Kind | Sendable when | Written how |
| --- | --- | --- |
| Struct, enum | All stored properties / associated values are Sendable | **Inferred** if the type isn't `public`; public types must declare `: Sendable` |
| Tuple | All elements are Sendable | Inferred |
| Class | `final`, only `let` stored properties of Sendable types, no superclass (or `NSObject`) | Declare `: Sendable` |
| Class on a global actor (`@MainActor class`) | Always: the actor guards its state | Inferred |
| Actor | Always | Inferred |
| Function or closure | Marked `@Sendable`, captures only Sendable values by value | `@Sendable` on the type or closure |
| Anything else that synchronizes itself | You promise it | `@unchecked Sendable` |

Value types are the easy case. Each copy is independent, so handing a copy to an actor can't race with the copy you kept:

```swift
struct Order {
    let id: Int
    var items: [String]
}

actor OrderStore {
    private var orders: [Order] = []

    func add(_ order: Order) {
        orders.append(order)
    }

    func allItems() -> [[String]] {
        orders.map(\.items)
    }
}

let store = OrderStore()
var order = Order(id: 1, items: ["tea"])
await store.add(order)
order.items.append("cake")       // changes our copy only

print("store has: \(await store.allItems())")
print("we have: \(order.items)")
```

```output
store has: [["tea"]]
we have: ["tea", "cake"]
```

`Order` never says `Sendable`; Swift infers it because the struct isn't `public` and `Int` and `[String]` are Sendable. Declaring it explicitly is still worth it for types meant to cross domains: the compiler then checks the conformance where the type is defined, instead of failing at some distant call site when someone adds a non-Sendable property.

That's the error you get when a type claims to be Sendable and isn't:

```swift no-compile stored property 'draft' of 'Sendable'-conforming struct 'Message' has non-Sendable type 'Draft'
final class Draft {
    var text = ""
}

struct Message: Sendable {
    let id: Int
    let draft: Draft
}
```

Swift 6.3: `error: stored property 'draft' of 'Sendable'-conforming struct 'Message' has non-Sendable type 'Draft'`. `let` doesn't help: the reference is constant, but the `Draft` it points to is mutable and shared by every copy of `Message`. The usual fix is to store the data instead of the object (`let draftText: String`), or make `Draft` itself Sendable.

## @Sendable closures and sending

Two different promises are written on closure parameters, and they explain most closure diagnostics.

**`@Sendable`** says the closure **may run concurrently**, possibly several times at once, from any domain. So it may only capture Sendable values, by value, and may not mutate a captured `var`. You saw both errors in Module 28, lesson 6 (`capture of 'cache' with non-Sendable type 'Cache' in a '@Sendable' closure` and `mutation of captured var 'finished' in concurrently-executing code`). Dispatch's `async`, `withTaskCancellationHandler`'s `onCancel`, and any callback you declare `@Sendable` work this way.

**`sending`** ([SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md), Swift 6.0) says the value is **handed over** to another domain, once. It may be non-Sendable, as long as the code that handed it over never touches it again. `Task.init`, `Task.detached` and `addTask` take their closure as `sending`. That's why this compiles:

```swift
final class Draft {
    var text = ""
}

func publish() async -> String {
    let draft = Draft()
    draft.text = "hello"
    let task = Task {
        draft.text.uppercased()      // the task now owns draft
    }
    return await task.value
}

print(await publish())
```

```output
HELLO
```

`Draft` isn't Sendable, yet the task captures it. The compiler can see that after the task is created, `publish()` never touches `draft` again, so only one domain ever uses it. Use it afterward and the same code is rejected:

```swift no-compile risks causing data races
final class Draft {
    var text = ""
}

func publish() async -> String {
    let draft = Draft()
    let task = Task {
        draft.text.uppercased()
    }
    draft.text = "changed"           // still used here
    return await task.value
}
```

Swift 6.3: `error: sending value of non-Sendable type '() async -> String' risks causing data races`, with the notes `Passing value of non-Sendable type '() async -> String' as a 'sending' argument to initializer 'init(name:priority:operation:)' risks causing races in between local and caller code` and `access can happen concurrently`. Read it as: the closure holds `draft`, the closure was sent away, and then `draft` was used here, so two domains could touch it at once.

### Region-based isolation

How does the compiler know `draft` isn't used elsewhere? **Region-based isolation** ([SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md), Swift 6.0) groups non-Sendable values that can reach each other into regions. A freshly created object starts in its own **disconnected** region. Sending a value moves its whole region to the other domain; after that, any use of anything in that region on the old side is an error. It works across calls into actors too:

```swift
final class Draft {
    var text = ""
}

actor DraftStore {
    private var drafts: [Draft] = []

    func save(_ draft: Draft) {
        drafts.append(draft)
    }

    var count: Int {
        drafts.count
    }
}

func compose(into store: DraftStore) async {
    let draft = Draft()
    draft.text = "Meeting notes"
    await store.save(draft)          // draft's region moves into the actor
    print("saved, store has \(await store.count)")
}

await compose(into: DraftStore())
```

```output
saved, store has 1
```

Add `draft.text = "edited"` after the `save` call and Swift 6.3 reports `error: sending 'draft' risks causing data races`, with the note `sending 'draft' to actor-isolated instance method 'save' risks causing data races between actor-isolated and local nonisolated uses`. The actor now holds the object; the function would be editing it from outside.

You can use `sending` on your own parameters. Here the function promises callers it takes ownership, so its body may hand the value to a task:

```swift
final class Draft {
    var text = ""
}

func startUppercasing(_ draft: sending Draft) -> Task<String, Never> {
    Task {
        draft.text.uppercased()
    }
}

let draft = Draft()
draft.text = "release notes"
print(await startUppercasing(draft).value)
```

```output
RELEASE NOTES
```

Without `sending` on the parameter, the body is rejected with `passing closure as a 'sending' parameter risks causing data races between code in the current task and concurrent execution of the closure` and the note `closure captures 'draft' which is accessible to code in the current task`: the function can't give away something its caller might still be holding. With it, the check moves to the call site: callers can't use the draft after passing it.

## Reading the common Swift 6 diagnostics

When you move a project to Swift 6, the same handful of messages make up most of the list. Each one names the value, the crossing and, in a note, often the fix.

**Returning a non-Sendable value from an actor.**

```swift no-compile non-Sendable 'Settings'-typed result can not be returned from actor-isolated instance method 'current()' to nonisolated context
final class Settings {
    var theme = "light"
}

actor SettingsStore {
    private var settings = Settings()

    func current() -> Settings {
        settings
    }
}

func readTheme(from store: SettingsStore) async {
    let settings = await store.current()
    print(settings.theme)
}
```

Swift 6.3: `error: non-Sendable 'Settings'-typed result can not be returned from actor-isolated instance method 'current()' to nonisolated context`, with the note `class 'Settings' does not conform to the 'Sendable' protocol`. The caller would get a reference to an object the actor keeps mutating. Fix it by returning a **snapshot** of what the caller needs, as a Sendable value:

```swift
final class Settings {
    var theme = "light"
    var fontSize = 14
}

struct SettingsSnapshot: Sendable {
    let theme: String
    let fontSize: Int
}

actor SettingsStore {
    private let settings = Settings()

    func setTheme(_ theme: String) {
        settings.theme = theme
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(theme: settings.theme, fontSize: settings.fontSize)
    }
}

let store = SettingsStore()
await store.setTheme("dark")
let current = await store.snapshot()
print("\(current.theme), \(current.fontSize) pt")
```

```output
dark, 14 pt
```

**Using main-actor state from nonisolated code.**

```swift no-compile main actor-isolated property 'title' can not be referenced from a nonisolated context
@MainActor
final class ScreenModel {
    var title = "Inbox"
}

func logTitle(of model: ScreenModel) {
    print(model.title)
}
```

Swift 6.3: `error: main actor-isolated property 'title' can not be referenced from a nonisolated context`. Either the function belongs on the main actor (`@MainActor func logTitle`), or it's async and reads `await model.title`. Which one depends on what the function is: UI code goes on the main actor; background work hops.

The rest, in one table:

| Diagnostic (Swift 6.3 wording) | What crossed | Usual fixes |
| --- | --- | --- |
| `capture of 'x' with non-Sendable type 'X' in a '@Sendable' closure` | A non-Sendable value into code that may run concurrently | Capture a Sendable copy of the data; make `X` Sendable (struct, final class with lets, actor, `@MainActor`) |
| `mutation of captured var 'x' in concurrently-executing code` | A local `var` into concurrent code | Return values instead of mutating; collect results in the parent; use an actor |
| `sending 'x' risks causing data races` | A non-Sendable value into another domain, then used again | Don't use it after sending; send a copy; make it Sendable |
| `passing closure as a 'sending' parameter risks causing data races …` | A closure capturing something the current task still uses | Capture copies; mark your own parameter `sending`; restructure so the task owns the value |
| `non-Sendable 'X'-typed result can not be returned from actor-isolated …` | A non-Sendable reference out of an actor | Return a Sendable snapshot |
| `stored property 'x' of 'Sendable'-conforming class 'Y' is mutable` | (A class claiming to be Sendable) | Make it a `let`, use an actor, or protect it and use `@unchecked`/`Mutex` honestly |
| `static property 'x' is not concurrency-safe because it is nonisolated global shared mutable state` | Global or static `var` | Make it `let`, `@MainActor`, or move it into an actor |
| `main actor-isolated … can not be referenced from a nonisolated context` | Main-actor state from elsewhere | Put the caller on the main actor, or `await` it from async code |

The fix is almost never "add an annotation until it compiles". Ask which domain should own the state, and whether the other side needs the object or just a copy of its data.

> [!warning] Errors on Linux, warnings in Xcode
> The examples in this lesson pass values through closures and types the examples declare themselves, so every diagnostic is an error in Swift 6 mode on all platforms. Module 28 found that the same messages for closures passed straight to `DispatchQueue.async` are **warnings** in Xcode (Swift 6.3.3, Swift 6 mode) and errors on Linux, likely because Dispatch is imported as `@preconcurrency` on Apple platforms. The same applies to other Apple APIs declared before concurrency annotations existed: when a declaration comes from a module imported with `@preconcurrency`, or itself carries `@preconcurrency`, Sendable problems at that boundary are reported as warnings. A warning there still describes a real crossing. Treat it as an error.

`@preconcurrency import SomeModule` is also something you can write yourself, for a dependency that hasn't adopted Sendable annotations yet. It downgrades diagnostics about that module's types; it doesn't make them safe. Remove it when the dependency updates.

## @unchecked Sendable and nonisolated(unsafe)

Two escape hatches turn checking **off** for something you synchronize yourself:

- `final class TokenStore: @unchecked Sendable` says "don't check this class; I protect its state."
- `nonisolated(unsafe) var cache: [String: Data] = [:]` says "don't check this variable; I protect it."

Module 28, lesson 6 listed the conditions for an honest `@unchecked Sendable`: `final`, every mutable stored property `private`, every access (reads too) inside the lock or queue, a comment saying what guards what. The Swift migration guide says the same thing more briefly: "The compiler will not perform any checking on an `@unchecked Sendable` type, so this opt-out must be used with caution."

In code that uses Swift Concurrency, reach for these last. In order of preference:

1. A value type, so nothing is shared.
2. An actor or `@MainActor`, so the compiler protects it.
3. `Mutex` (Synchronization, iOS 18), so the class is plainly `Sendable` without `@unchecked`.
4. `@unchecked Sendable` with a lock, when you need synchronous access on older OS versions or you're wrapping thread-safe C or Objective-C code.

`@unchecked` is the right tool for a type that really is thread-safe in a way the compiler can't see. It's the wrong tool for making an error go away.

> [!version] Swift 6.4: ~Sendable
> Swift 6.4 adds `~Sendable` ([SE-0518](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0518-tilde-sendable.md)) to state explicitly that a type isn't Sendable, so it isn't inferred and nobody adds a conformance by accident. This lesson doesn't run it.

## Isolated parameters and #isolation

Normally a function's isolation is fixed where it's declared. An **isolated parameter** makes it depend on an argument instead: the function runs on that actor and can use its state synchronously ([SE-0313](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0313-actor-isolation-control.md)).

```swift
actor BankAccount {
    var balance = 0

    func deposit(_ amount: Int) {
        balance += amount
    }
}

func applyInterest(to account: isolated BankAccount, percent: Int) {
    // Runs on `account`: synchronous access, no await inside.
    account.balance += account.balance * percent / 100
}

let account = BankAccount()
await account.deposit(200)
await applyInterest(to: account, percent: 10)
print(await account.balance)
```

```output
220
```

From outside, calling it is a hop like any actor method (`await`). Inside, the read and the write are on the actor with no await between them, so there's no reentrancy gap. It's a way to write an operation on an actor's state outside the actor's declaration.

The general form is `isolated (any Actor)?`, and with the `#isolation` macro as its default value, a function runs on **whatever actor called it** ([SE-0420](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0420-inheritance-of-actor-isolation.md), Swift 6.0). `#isolation` evaluates to the caller's isolation: the main actor, an actor instance, or `nil`.

```swift
func describe(_ isolation: (any Actor)?) -> String {
    switch isolation {
    case nil: "nonisolated"
    case is MainActor: "main actor"
    case let other?: "\(type(of: other))"
    }
}

final class Formatter {
    var calls = 0
}

func format(
    _ value: Int,
    with formatter: Formatter,
    isolation: isolated (any Actor)? = #isolation
) async -> String {
    formatter.calls += 1
    return "\(value) formatted on \(describe(isolation))"
}

actor ReportBuilder {
    private let formatter = Formatter()

    func build() async -> String {
        await format(42, with: formatter)
    }
}

let formatter = Formatter()
print(await format(7, with: formatter))
print(await ReportBuilder().build())
print("top-level formatter calls: \(formatter.calls)")
```

```output
7 formatted on main actor
42 formatted on ReportBuilder
top-level formatter calls: 1
```

`Formatter` isn't Sendable. If `format` were a plain nonisolated async function, passing the actor's formatter into it would be a crossing out of the actor, and Swift 6.3 (in its default mode) rejects that call with `sending 'self.formatter' risks causing data races`. With the isolated parameter, `format` runs on the caller's actor, so the formatter never leaves its domain. This is how standard library functions such as `withTaskGroup` and `withCheckedContinuation` take an `isolation:` parameter defaulted to `#isolation`, which is why you can call them from actor and main-actor code and still use non-Sendable state inside.

Swift 6.2 adds a shorter way to say "run on the caller's actor" for a whole function, `nonisolated(nonsending)`, and a setting that makes it the default for nonisolated async functions. That's lesson 6.

## Common mistakes

> [!error] Adding @unchecked Sendable to make an error go away
> If the class has no lock, queue or `Mutex`, the error was right and you've turned it into undefined behavior.

> [!error] Using a value after sending it
> `await store.save(draft)` followed by `draft.text = …` is rejected. Finish editing first, send a copy, or let the actor do the edit.

> [!error] Returning live objects from an actor
> Return Sendable snapshots. A reference to the actor's internal object would let callers mutate it outside the actor.

> [!error] A public struct that "is obviously Sendable"
> Inference only applies to non-public types. A public type used across modules needs `: Sendable` written out (Swift 6.3: `type 'PublicOrder' does not conform to the 'Sendable' protocol` at the use site).

> [!error] Treating Xcode's Sendable warnings as noise
> Warnings at `@preconcurrency` boundaries describe the same crossings that are errors elsewhere. Fix them.

> [!error] Making everything an actor to satisfy the checker
> Many errors disappear more cleanly by passing values (structs) instead of objects, or by putting UI-facing types on the main actor.

## Exercises

````exercise
id: m29-l05-e1
type: prediction
prompt: "A struct is passed to an actor and then modified. What does the program print?"
code: |
  struct Cart {
      var items: [String]
  }

  actor CheckoutQueue {
      private var carts: [Cart] = []

      func enqueue(_ cart: Cart) {
          carts.append(cart)
      }

      var firstCartSize: Int {
          carts.first?.items.count ?? 0
      }
  }

  let queue = CheckoutQueue()
  var cart = Cart(items: ["book"])
  await queue.enqueue(cart)
  cart.items.append("pen")
  cart.items.append("lamp")
  await queue.enqueue(cart)
  print("queued first: \(await queue.firstCartSize)")
  print("local: \(cart.items.count)")
output: |
  queued first: 1
  local: 3
solution: |
  `Cart` is a struct of Sendable values, so Swift infers `Sendable` and every `enqueue` hands the actor an independent copy. The first copy had one item; later changes to the local `cart` don't affect it. That's also why there's no `sending` error for using `cart` after passing it: Sendable values are never "used up".

  ```output
  queued first: 1
  local: 3
  ```
````

````exercise
id: m29-l05-e2
type: comprehension
multiple: true
prompt: "Which of these types are Sendable as written, with no @unchecked? Select all that apply."
choices:
  - text: "struct Point { var x: Double; var y: Double } (not public)"
    correct: true
    why: "Non-public struct with Sendable stored properties: inferred."
  - text: "final class Config: Sendable { let name: String; let retries: Int }"
    correct: true
    why: "Final, immutable, Sendable stored properties."
  - text: "final class Session: Sendable { var token: String }"
    correct: false
    why: "Swift 6.3: stored property 'token' of 'Sendable'-conforming class 'Session' is mutable."
  - text: "@MainActor final class ProfileViewModel { var name = \"\" }"
    correct: true
    why: "Global-actor-isolated classes are Sendable: the main actor guards their state."
  - text: "struct Row: Sendable { let id: Int; let cell: SomeNonSendableClass }"
    correct: false
    why: "A stored property of non-Sendable type; let doesn't help because the object is shared and mutable."
  - text: "actor ImageCache { var images: [String: Int] = [:] }"
    correct: true
    why: "All actors are Sendable."
solution: |
  Sendable: the non-public struct of Doubles, the final class with only `let` Sendable properties, the `@MainActor` class, and the actor. Not Sendable: a class with a mutable stored property (needs an actor, `Mutex`, or an honest `@unchecked`), and a struct holding a reference to a non-Sendable class.
````

````exercise
id: m29-l05-e3
type: find-errors
prompt: "Which lines are rejected by Swift 6, and why?"
code: |
  final class Photo {
      var caption = ""
  }

  actor Album {
      private var photos: [Photo] = []
      func add(_ photo: Photo) { photos.append(photo) }
      func first() -> Photo? { photos.first }
  }

  func importPhoto(into album: Album) async {
      let photo = Photo()
      photo.caption = "Beach"            // line A
      await album.add(photo)             // line B
      photo.caption = "Beach, day 2"     // line C
      let cover = await album.first()    // line D
      print(cover?.caption ?? "none")
  }
choices:
  - text: "Line A: you can't mutate a non-Sendable object in an async function."
    correct: false
    why: "Before sending, the photo belongs only to this task. Mutating it is fine."
  - text: "Line B with line C: the photo is sent to the actor and then used again; Swift 6.3 reports \"sending 'photo' risks causing data races\"."
    correct: true
    why: "Region-based isolation allows the send only if the photo is never used afterward."
  - text: "Line D: a non-Sendable Photo can't be returned from the actor to nonisolated code."
    correct: true
    why: "Swift 6.3: non-Sendable 'Photo?'-typed result can not be returned from actor-isolated instance method 'first()' to nonisolated context."
  - text: "Line B alone: you can never pass a non-Sendable value to an actor."
    correct: false
    why: "You can, if it's in a disconnected region and you don't use it again."
rubric:
  - Identifies use-after-send (lines B and C).
  - Identifies the non-Sendable return (line D).
  - Explains why line A and line B on their own are fine.
solution: |
  Line C uses `photo` after it was sent to the actor at line B, and line D returns a non-Sendable object out of the actor. A fixed design keeps the actor's objects inside and returns data:

  ```swift
  final class Photo {
      var caption = ""
  }

  actor Album {
      private var photos: [Photo] = []

      func add(_ photo: Photo) {
          photos.append(photo)
      }

      func renameFirst(to caption: String) {
          photos.first?.caption = caption
      }

      func firstCaption() -> String? {
          photos.first?.caption
      }
  }

  func importPhoto(into album: Album) async {
      let photo = Photo()
      photo.caption = "Beach"
      await album.add(photo)
      await album.renameFirst(to: "Beach, day 2")
      let cover = await album.firstCaption()
      print(cover ?? "none")
  }

  await importPhoto(into: Album())
  ```

  ```output
  Beach, day 2
  ```

  Edits happen inside the actor, and only a `String` (Sendable) comes back out.
````

````exercise
id: m29-l05-e4
type: solve
prompt: "A `ContactBook` class (non-Sendable, with `var contacts: [String]`) is shared between a sync task and the UI. Replace it with an actor `ContactBook` that has `add(_:)` and `snapshot() -> ContactsSnapshot`, where `ContactsSnapshot` is a Sendable struct with `count` and the names sorted. Add 4 names from concurrent child tasks, then print the snapshot's count and names."
starter: |
  // Before:
  // final class ContactBook {
  //     var contacts: [String] = []
  // }

  // Write the actor, the snapshot and the concurrent adds.
rubric:
  - ContactBook is an actor with private mutable state.
  - ContactsSnapshot is a struct declared Sendable with let properties.
  - Names are added from child tasks in a task group, not by mutating shared state.
  - The printed names are sorted, so output doesn't depend on completion order.
solution: |
  ```swift
  struct ContactsSnapshot: Sendable {
      let count: Int
      let names: [String]
  }

  actor ContactBook {
      private var contacts: [String] = []

      func add(_ name: String) {
          contacts.append(name)
      }

      func snapshot() -> ContactsSnapshot {
          ContactsSnapshot(count: contacts.count, names: contacts.sorted())
      }
  }

  let book = ContactBook()
  await withTaskGroup(of: Void.self) { group in
      for name in ["Lucia", "Ana", "Omar", "Ben"] {
          group.addTask { await book.add(name) }
      }
  }
  let snapshot = await book.snapshot()
  print("\(snapshot.count) contacts: \(snapshot.names.joined(separator: ", "))")
  ```

  ```output
  4 contacts: Ana, Ben, Lucia, Omar
  ```

  The actor owns the mutable array; children call `add` concurrently and the actor serializes them. The snapshot is an immutable value, so the UI can keep it as long as it wants. Sorting inside `snapshot()` makes the order independent of which child ran first.
````

````exercise
id: m29-l05-e5
type: explain
prompt: "Explain why `Task { draft.text.uppercased() }` compiles when `draft` is a non-Sendable class instance created just before, but `DispatchQueue.global().async { draft.text.uppercased() }` is diagnosed. Use the words @Sendable, sending and region."
code: |
  import Dispatch

  final class Draft {
      var text = "hello"
  }

  func compare() {
      let draft = Draft()
      Task { print(draft.text.uppercased()) }                         // accepted

      let other = Draft()
      DispatchQueue.global().async { print(other.text.uppercased()) }  // diagnosed
  }
rubric:
  - DispatchQueue.async takes a @Sendable closure, which may only capture Sendable values.
  - Task's operation is a sending parameter, which may capture non-Sendable values if the caller doesn't use them afterward.
  - The freshly created draft is in a disconnected region that moves into the task.
  - Mentions that using draft after creating the task would make the Task version an error too.
  - Optionally notes that in Xcode the Dispatch version is a warning because Dispatch is imported @preconcurrency.
solution: |
  `DispatchQueue.async` declares its closure `@Sendable`: the closure might run concurrently with anything, so everything it captures must be Sendable, and a mutable class isn't. `Task.init` declares its operation `sending`: the closure is handed over once. Region-based isolation sees that `draft` was just created, so it sits in a disconnected region nobody else can reach; capturing it moves that region into the task, and as long as the function doesn't touch `draft` again, only the task ever uses it. Add `draft.text = "x"` after creating the task and the `Task` version fails too (`sending value of non-Sendable type … risks causing data races`). On Linux the Dispatch version is an error; in Xcode it's a warning because Dispatch is imported `@preconcurrency`, but it describes the same problem.
````

````exercise
id: m29-l05-e6
type: refactor
prompt: "This logger is used from many tasks. Refactor it so it's Sendable without @unchecked, keeping a synchronous `log(_:)` API. Explain your choice."
code: |
  final class Logger: @unchecked Sendable {
      var lines: [String] = []

      func log(_ line: String) {
          lines.append(line)
      }
  }
rubric:
  - Recognizes the original @unchecked promise is false (no synchronization).
  - Chooses a synchronization mechanism that keeps log synchronous (Mutex, or a lock with an honest @unchecked) or explains why an actor changes the API.
  - Keeps the mutable state private.
  - Explains availability (Mutex needs iOS 18) or the trade-off of an actor making log async.
solution: |
  The original is a data race with a false promise: `@unchecked Sendable` and no synchronization. A synchronous API rules out an actor (every call would need `await`). `Mutex` from the Synchronization module keeps `log(_:)` synchronous and makes the class plainly `Sendable`, because `Mutex` itself is Sendable:

  ```swift
  import Synchronization

  final class Logger: Sendable {
      private let lines = Mutex<[String]>([])

      func log(_ line: String) {
          lines.withLock { $0.append(line) }
      }

      var count: Int {
          lines.withLock { $0.count }
      }
  }

  let logger = Logger()
  await withTaskGroup(of: Void.self) { group in
      for index in 1...100 {
          group.addTask { logger.log("event \(index)") }
      }
  }
  print("logged: \(logger.count)")
  ```

  ```output
  logged: 100
  ```

  `Mutex` needs iOS 18 or later. On older targets, use `NSLock` with `private var lines` and keep `@unchecked Sendable`, now honest because every access holds the lock (Module 28, lesson 6). If callers can await, an actor is the simplest of all.
````

## Summary

- Isolation domains: each actor, each global actor, and nonisolated code. Values cross at actor calls and returns, task and child closures, `@Sendable` callbacks and globals.
- `Sendable` types: non-public structs and enums of Sendable values (inferred), final classes with only `let` Sendable properties (declared), actors and global-actor classes (inferred), `@Sendable` functions.
- `@Sendable` closures may run concurrently: only Sendable captures, no mutation. `sending` parameters hand a value over once: non-Sendable is fine if the sender never uses it again.
- Region-based isolation tracks which non-Sendable values can reach each other and allows a region to move when nothing left behind uses it. "sending 'x' risks causing data races" means you used it afterward.
- Fix diagnostics by deciding who owns the state: pass values, return snapshots, put UI state on the main actor, use actors for shared state. `@unchecked Sendable` and `nonisolated(unsafe)` turn checking off and must be backed by real synchronization.
- In Xcode, crossings into `@preconcurrency` APIs can show as warnings; they're still real.
- `isolated` parameters run a function on a given actor; `isolation: isolated (any Actor)? = #isolation` runs it on the caller's actor, so non-Sendable state never crosses.
