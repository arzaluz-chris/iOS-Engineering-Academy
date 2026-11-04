---
id: m29-l04
title: Actors
description: "Protect mutable state with the compiler instead of a lock. You write actors, read the isolation errors you get when you reach into one from outside, learn reentrancy (an actor runs one thing at a time but lets other calls in at every await) and fix the check-then-act bug it causes, opt members out with nonisolated, and use global actors, above all @MainActor on types, functions and closures."
module: m29
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l03]
objectives:
  - Explain what actor isolation guarantees and why calls from outside need await.
  - Turn a lock-protected class into an actor and read the isolation diagnostics.
  - Explain actor reentrancy and fix check-then-act bugs that span an await.
  - Deduplicate concurrent requests with a dictionary of in-flight tasks.
  - Use nonisolated for members that don't touch mutable state, including protocol conformances.
  - Apply @MainActor and custom global actors to types, functions and closures, and hop to the main actor from other code.
terms:
  - term: Actor
    definition: "A reference type whose mutable state can only be touched by one task at a time. Code outside the actor reaches its isolated members asynchronously, with await; code inside uses them directly."
  - term: Actor isolation
    definition: "The compiler-checked rule that an actor's mutable state is accessed only from code running on that actor. Each actor is its own isolation domain."
  - term: Actor reentrancy
    definition: "While an actor method is suspended at an await, the actor can run other calls. State can change between the code before an await and the code after it."
  - term: nonisolated
    definition: "A modifier that takes a member out of its actor's (or global actor's) isolation. It can be called synchronously from anywhere, but it can only use immutable or Sendable state."
  - term: Global actor
    definition: "An actor with a single shared instance that you apply as an attribute (@MainActor, or your own @globalActor) to put functions, properties and whole types in the same isolation domain, even across different types."
mastery:
  - Convert a class with an NSLock into an actor and show that 1,000 concurrent increments count 1,000.
  - Point at the await inside an actor method where another call can slip in, and say which state assumption might break.
  - Rewrite an actor method so its check and its update happen with no await between them.
  - Write an image cache actor that starts at most one download per key, however many callers ask.
  - Make an actor conform to CustomStringConvertible with a nonisolated property.
  - Call a @MainActor function from nonisolated async code, and mark a UIKit-facing type @MainActor.
resources: [swift-actor, swift-globalactor, swift-book, swift-mainactor, swift-evolution, xcode-data-races]
cards:
  - id: m29-l04-c1
    front: What does an actor guarantee?
    back: "Only one task at a time runs code that's isolated to it, so its mutable state never has a data race. Outside code must await to reach isolated members, and can't mutate its properties directly at all."
  - id: m29-l04-c2
    front: What is actor reentrancy?
    back: "When an actor method suspends at an await, the actor is free to run other calls. When the method resumes, the actor's state may have changed. Don't assume a check made before an await still holds after it."
  - id: m29-l04-c3
    front: How do you avoid duplicate downloads in a cache actor?
    back: "Keep a dictionary of in-flight Task values keyed by the request. A second caller finds the task and awaits its value instead of starting another download. Store the task before the first await."
  - id: m29-l04-c4
    front: When do you mark an actor member nonisolated?
    back: "When it only reads immutable (let) Sendable state or computes from its parameters, for example a description or an id. It can then be called synchronously and satisfy synchronous protocol requirements."
  - id: m29-l04-c5
    front: "@MainActor on a class means what?"
    back: "Every property and method of the class is isolated to the main actor, so it runs on the main thread and the compiler checks every call. Instances are Sendable. Members can opt out with nonisolated."
---

## The idea in one sentence

An actor is a class-like type that lets only one task at a time touch its state, and the compiler enforces it, so the lock from Module 28 becomes part of the type instead of a promise in a comment.

> [!note] What you already know
> Module 28, lesson 6 protected a counter and a bank account with `NSLock`, marked the classes `@unchecked Sendable`, and found that "thread-safe" getters and setters can still produce a race condition (check-then-act). Lesson 1 here showed that code between two awaits runs without interruption. Actors combine both ideas. The Swift blocks were run with Swift 6.3 on Linux; diagnostics are the ones it printed.

## From a locked class to an actor

The Module 28 counter needed a lock, `private` state, `defer { unlock() }` on every path, and an `@unchecked` promise. As an actor:

```swift
actor DownloadCounter {
    private var finished = 0

    func recordFinished() {
        finished += 1
    }

    var count: Int {
        finished
    }
}

let counter = DownloadCounter()
await withTaskGroup(of: Void.self) { group in
    for _ in 1...1_000 {
        group.addTask {
            await counter.recordFinished()
        }
    }
}
print("finished: \(await counter.count)")
```

```output
finished: 1000
```

1. `actor` instead of `final class`. Actors are reference types like classes, but they can't inherit, and they're implicitly `Sendable`: you can pass one to any task.
2. Inside the actor, `finished += 1` is ordinary synchronous code. No lock: the actor guarantees no other task is running its code at the same time.
3. Outside, every call to an isolated member is `await counter.recordFinished()`. The call may have to wait for its turn, so it's a possible suspension point.
4. 1,000 child tasks call it concurrently and the count is exactly 1,000, every run. The compiler checked this; nothing here relies on a comment saying "only touch this under the lock".

An actor is like a private serial queue (Module 28, lesson 2) that the compiler knows about. The difference in practice: callers **await** instead of blocking, and forgetting to go through the queue is a compile error instead of a data race.

## The isolation rules, as diagnostics

Each actor is its own **isolation domain**. Code outside it, including plain functions, other actors and the main actor, is "nonisolated" relative to it, and the compiler rejects direct access.

Reading a property from synchronous code:

```swift no-compile actor-isolated property 'value' can not be referenced from a nonisolated context
actor Counter {
    var value = 0
}

func show(_ counter: Counter) {
    print(counter.value)
}
```

Swift 6.3: `error: actor-isolated property 'value' can not be referenced from a nonisolated context`. From async code, `await counter.value` reads it.

Mutating a property from outside is rejected **even with await**:

```swift no-compile actor-isolated property 'value' can not be mutated from a nonisolated context
actor Counter {
    var value = 0
}

func bump(_ counter: Counter) async {
    await counter.value += 1
}
```

Swift 6.3: `error: actor-isolated property 'value' can not be mutated from a nonisolated context`. This one's on purpose: `value += 1` from outside would be a read and a write as two separate trips to the actor, which is the check-then-act race again. Only the actor changes its own state. Give it a method (`func increment()`) that does the whole operation inside.

Calling a method without `await` from async code:

```swift no-compile actor-isolated instance method 'increment()' cannot be called from outside of the actor
actor Counter {
    var value = 0

    func increment() {
        value += 1
    }
}

func bump(_ counter: Counter) async {
    counter.increment()
}
```

Swift 6.3: `error: actor-isolated instance method 'increment()' cannot be called from outside of the actor`. The method is synchronous inside the actor, but from outside every call is a trip to the actor: `await counter.increment()`. From a synchronous function, the message is `call to actor-isolated instance method 'increment()' in a synchronous nonisolated context`, and the fix is the one from lesson 1: make the caller async, or start a `Task`.

One exception: `let` properties of a `Sendable` type can't change, so code in the same module may read them without `await`.

## Reentrancy: the actor lets others in at every await

The rule that matters most, and the one that bites experienced developers: **an actor runs one piece of code at a time, but a method that suspends at an `await` gives the actor up**. Other calls can run before it resumes. That's called **reentrancy**, and Swift actors are always reentrant.

Here's a withdrawal that checks the balance, waits for an approval, then subtracts. The `approval` closure stands in for any `await` (a fraud check, a server round trip). To make the interleaving happen on every run, this approval triggers a second withdrawal while the first one is waiting:

```swift
actor Account {
    private(set) var balance = 100

    func withdraw(_ amount: Int, approval: @Sendable () async -> Void) async -> Bool {
        guard balance >= amount else { return false }
        await approval()          // suspension point: the actor is free here
        balance -= amount
        return true
    }
}

let account = Account()
let first = await account.withdraw(80) {
    // While the first withdrawal waits for approval, a second one arrives.
    let second = await account.withdraw(80) {}
    print("second withdrawal approved: \(second)")
}
print("first withdrawal approved: \(first)")
print("balance: \(await account.balance)")
```

```output
second withdrawal approved: true
first withdrawal approved: true
balance: -60
```

Trace it:

1. The first `withdraw(80)` checks `100 >= 80` and suspends at `await approval()`.
2. The actor is free, so the second `withdraw(80)` runs: it sees a balance of 100 (nothing has been subtracted yet), passes the guard, gets approved, and subtracts. Balance 20.
3. The first call resumes after its `await` and subtracts 80 from a balance it checked before the await. Balance −60.

No data race: every access to `balance` happened on the actor, one at a time. It's the **race condition** from Module 28, lesson 6, and the compiler can't see it. Note also what didn't happen: a deadlock. A non-reentrant lock in the same spot (the approval calling back into the account) would have hung forever. Reentrancy is the trade-off: no deadlocks, but state can change across an await.

The fixes all come from one rule: **do the check and the update with no `await` between them.** Here, reserve the money first and refund it if approval fails:

```swift
actor Account {
    private(set) var balance = 100

    func withdraw(_ amount: Int, approval: @Sendable () async -> Bool) async -> Bool {
        guard balance >= amount else { return false }
        balance -= amount         // check and update together, before any await
        let approved = await approval()
        if !approved {
            balance += amount     // give it back
        }
        return approved
    }
}

let account = Account()
let first = await account.withdraw(80) {
    let second = await account.withdraw(80) { true }
    print("second withdrawal approved: \(second)")
    return true
}
print("first withdrawal approved: \(first)")
print("balance: \(await account.balance)")
```

```output
second withdrawal approved: false
first withdrawal approved: true
balance: 20
```

Other ways to apply the same rule:

- **Re-check after the await.** If you must decide after awaiting, check the state again at that point; don't rely on what you saw before.
- **Keep isolated methods synchronous** where possible. A method with no `await` inside can't be interleaved at all; the Swift book recommends this for code that "protects temporary invalid state".
- **Record intent before the await**, as in the next example.

### Deduplicating requests with in-flight tasks

A cache actor with the same bug: two callers ask for the same image, both see a miss, both download. The check (`cache[key] == nil`) is before `await download(key)`, and the update (`cache[key] = image`) is after. The fix is to store a `Task` for the download **before** the first await, so a second caller finds it and awaits the same result:

```swift
actor ThumbnailCache {
    private var images: [String: String] = [:]
    private var inFlight: [String: Task<String, Never>] = [:]
    private(set) var downloads = 0

    func thumbnail(for key: String) async -> String {
        if let image = images[key] {
            return image
        }
        if let task = inFlight[key] {
            return await task.value
        }
        downloads += 1
        let task = Task {
            try? await Task.sleep(for: .milliseconds(50))   // the network
            return "image-\(key)"
        }
        inFlight[key] = task        // recorded before the await
        let image = await task.value
        images[key] = image
        inFlight[key] = nil
        return image
    }
}

let cache = ThumbnailCache()
let results = await withTaskGroup(of: String.self) { group in
    for _ in 1...5 {
        group.addTask { await cache.thumbnail(for: "avatar-7") }
    }
    var all: [String] = []
    for await image in group {
        all.append(image)
    }
    return all
}
print("results: \(Set(results))")
print("downloads: \(await cache.downloads)")
```

```output
results: ["image-avatar-7"]
downloads: 1
```

Five concurrent requests, one download, in any interleaving. Whichever call runs first increments `downloads` and stores the task, all before its first `await`, so every later call finds either the finished image or the in-flight task. (The program prints a `Set` so five identical strings become one line.) The `Task { }` created inside the actor inherits the actor's isolation, but it spends nearly all its time suspended in `Task.sleep`, so it doesn't hold the actor up; in a real cache the work would be a `URLSession` call. Module 27, lesson 5 coalesced in-flight image loads by hand, without actors; compare the two.

## nonisolated

Members that don't touch the actor's mutable state don't need isolation. Mark them `nonisolated` and they can be called synchronously from anywhere. The most common reason is a protocol whose requirements are synchronous:

```swift no-compile conformance of 'Account' to protocol 'CustomStringConvertible' crosses into actor-isolated code and can cause data races
actor Account: CustomStringConvertible {
    let id: String
    private var balance = 0

    init(id: String) {
        self.id = id
    }

    var description: String {
        "Account \(id)"
    }
}
```

Swift 6.3: `error: conformance of 'Account' to protocol 'CustomStringConvertible' crosses into actor-isolated code and can cause data races`, with the note `actor-isolated property 'description' cannot satisfy nonisolated requirement`. Anyone can call `description` synchronously through the protocol, so it can't require a trip to the actor. Since it only uses the immutable `id`, `nonisolated` is the honest fix:

```swift
actor Account: CustomStringConvertible {
    let id: String
    private var balance = 0

    init(id: String) {
        self.id = id
    }

    nonisolated var description: String {
        "Account \(id)"
    }
}

let account = Account(id: "A-17")
print(account)
```

```output
Account A-17
```

A `nonisolated` member that tried to read `balance` would get the "can not be referenced from a nonisolated context" error. `nonisolated` doesn't bypass anything; it only declares that the member doesn't need the actor.

## Global actors and @MainActor

An actor instance protects one object's state. A **global actor** is a single, shared isolation domain you apply as an attribute, so functions and types in different places can share it. `@MainActor` is the one you'll use constantly. In Apple's words it's "a singleton actor whose executor is equivalent to the main dispatch queue": code isolated to it runs on the main thread.

Where the attribute can go:

- **On a type:** `@MainActor final class ProfileViewModel { … }`. Every stored property, method and initializer is main-actor isolated. `UIViewController`, `UIView` and SwiftUI's `View` protocol are already `@MainActor`, and subclasses or conforming types inherit it.
- **On a function or property:** `@MainActor func updateBadge(_:)`, `@MainActor var currentTheme`.
- **On a closure:** `Task { @MainActor in … }`, or a parameter type like `@MainActor @Sendable () -> Void`. This is how a callback promises it runs on the main actor, which Module 28, lesson 5 had to say in a doc comment.
- **Opting out inside an isolated type:** `nonisolated func formattedPrice() -> String`, for members that don't touch main-actor state.

Instances of a `@MainActor` class are `Sendable`: any task can hold a reference, and the compiler makes it await to use one.

From nonisolated async code, you hop to the main actor by awaiting a main-actor function, or by running a closure there with `MainActor.run`:

```swift
func describe(_ isolation: (any Actor)?) -> String {
    switch isolation {
    case nil: "nonisolated"
    case is MainActor: "main actor"
    case let other?: "\(type(of: other))"
    }
}

@MainActor
final class StatusLabel {
    private(set) var text = ""

    func show(_ newText: String) {
        text = newText
        print("show runs on: \(describe(#isolation))")
    }
}

func loadAndShow(on label: StatusLabel) async {
    print("loading runs on: \(describe(#isolation))")
    let status = "3 new messages"          // imagine slow work here
    await label.show(status)               // hop to the main actor
    await MainActor.run {
        print("MainActor.run runs on: \(describe(#isolation))")
    }
}

let label = StatusLabel()
await Task.detached {
    await loadAndShow(on: label)
}.value
print(label.text)
```

```output
loading runs on: nonisolated
show runs on: main actor
MainActor.run runs on: main actor
3 new messages
```

- `#isolation` is a macro that evaluates to the actor the current code is isolated to, or `nil`. The `describe` helper turns it into text. (Lesson 5 uses `#isolation` as a parameter default.)
- `loadAndShow` is a plain nonisolated function, called from a detached task, so it isn't on any actor.
- `await label.show(status)` hops to the main actor because `show` is main-actor isolated (the whole class is). In Module 21, lesson 3, calling a `@MainActor` function from a synchronous nonisolated function was an error; from async code, `await` makes it legal.
- `print(label.text)` at the top level needs no `await`: top-level code is on the main actor too.

### Your own global actor

A custom global actor is an actor with a `static let shared` and the `@globalActor` attribute. Use one when several types must share one serial domain that isn't the main actor, such as everything that touches a database connection:

```swift
@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
}

@DatabaseActor
final class DatabaseConnection {
    private var rows: [String] = []

    func insert(_ row: String) {
        rows.append(row)
    }

    var rowCount: Int {
        rows.count
    }
}

@DatabaseActor
func importDefaults(into connection: DatabaseConnection) {
    connection.insert("settings")
    connection.insert("profile")
}

@DatabaseActor
func setUp() -> Int {
    let connection = DatabaseConnection()
    importDefaults(into: connection)   // same domain: no await
    return connection.rowCount
}

print("rows: \(await setUp())")
```

```output
rows: 2
```

`importDefaults` and `DatabaseConnection` are separate declarations, but both are on `DatabaseActor`, so they call each other synchronously. From the top-level code (the main actor) it takes one `await` to get in. Custom global actors are rarely needed; an ordinary actor that owns the connection is usually simpler. Don't create one per feature "for performance": every crossing between domains is a hop.

## Actors, locks or the main actor?

| Situation | Use |
| --- | --- |
| State the UI reads and writes (view models, screen state) | `@MainActor` on the type |
| Shared mutable state used from many tasks, async access acceptable (caches, session stores) | An actor |
| Tiny critical sections that must be synchronous, very hot paths | `Mutex` or `OSAllocatedUnfairLock` (Module 28, lesson 6) |
| Immutable data passed around | A `Sendable` struct, no isolation needed (lesson 5) |

A common mistake is turning every class into an actor. Each call into an actor from outside is an `await`, which spreads `async` through every caller and can introduce reentrancy bugs. Most app code belongs on the main actor; actors are for state that genuinely needs to be shared off it.

## Common mistakes

> [!error] Check-then-act across an await inside an actor
> An actor prevents data races, not race conditions. If a method checks state, awaits, then acts on what it checked, another call can run in between. Update state before the await, re-check after it, or store an in-flight task.

> [!error] error: actor-isolated property 'value' can not be mutated from a nonisolated context
> You can't assign to an actor's property from outside, even with `await`. Add a method that performs the whole change inside the actor.

> [!error] Making a type an actor when it belongs on the main actor
> If the UI reads it, `@MainActor` is simpler: synchronous access from views and view controllers, no hops.

> [!error] Slow synchronous work inside an actor method
> An actor runs one call at a time, so a method that computes for a second blocks every other caller for a second, and on the main actor freezes the UI. Move heavy work into a `@concurrent` or nonisolated function and only store results on the actor.

> [!error] Using nonisolated to silence an error
> `nonisolated` on a member that reads mutable state doesn't compile, and `nonisolated(unsafe)` on stored state turns the error into a data race. Use it only for members that truly don't need isolation.

## Exercises

````exercise
id: m29-l04-e1
type: prediction
prompt: "A seat-booking actor has a suspension point between its check and its update, and the confirmation step books another seat. What does the program print?"
code: |
  actor Flight {
      private(set) var freeSeats = 1
      private(set) var bookings: [String] = []

      func book(_ name: String, confirm: @Sendable () async -> Void) async {
          guard freeSeats > 0 else {
              bookings.append("\(name): sold out")
              return
          }
          await confirm()
          freeSeats -= 1
          bookings.append("\(name): booked")
      }
  }

  let flight = Flight()
  await flight.book("Ana") {
      await flight.book("Ben") {}
  }
  for line in await flight.bookings {
      print(line)
  }
  print("free seats: \(await flight.freeSeats)")
output: |
  Ben: booked
  Ana: booked
  free seats: -1
solution: |
  Ana's call sees one free seat and suspends at `await confirm()`. The actor is free, so Ben's call (made from inside Ana's confirmation) runs: it also sees one free seat, confirms immediately, decrements to 0 and records "Ben: booked". Then Ana's call resumes and decrements again, to −1.

  ```output
  Ben: booked
  Ana: booked
  free seats: -1
  ```

  The fix: decrement `freeSeats` before `await confirm()` (and give the seat back if confirmation fails).
````

````exercise
id: m29-l04-e2
type: comprehension
multiple: true
prompt: "Which statements about actors are true? Select all that apply."
choices:
  - text: "Two tasks can never run code isolated to the same actor at the same moment."
    correct: true
    why: "That's the actor guarantee, and why its state can't have data races."
  - text: "While an actor method is suspended at an await, another call to the same actor can run."
    correct: true
    why: "Reentrancy. The suspended method's assumptions about state may be stale when it resumes."
  - text: "Code outside an actor can mutate its var properties if it uses await."
    correct: false
    why: "Mutation from outside is rejected even with await. Use a method."
  - text: "Actors prevent all race conditions, so check-then-act inside an actor is always safe."
    correct: false
    why: "Only if there's no await between the check and the act."
  - text: "An actor is a reference type and is implicitly Sendable."
    correct: true
    why: "That's why you can share one across tasks freely."
solution: |
  Actors serialize access (no data races), are reentrant at awaits (state can change across one), forbid outside mutation even with `await`, and are `Sendable` reference types. They don't prevent race conditions that span a suspension point.
````

````exercise
id: m29-l04-e3
type: solve
prompt: "Write an actor `RateLimiter` that allows at most `limit` requests per user. It has `init(limit: Int)` and `func allow(_ user: String) -> Bool`, which records the request and returns true if the user is under the limit, false otherwise. Then fire 10 concurrent requests for \"ana\" and 2 for \"ben\" with a limit of 3, and print how many were allowed for each."
starter: |
  // Write RateLimiter, then the concurrent requests.
rubric:
  - RateLimiter is an actor with private mutable state (a dictionary of counts).
  - allow(_:) is synchronous inside the actor, so the check and the increment can't be interleaved.
  - The requests run concurrently in a task group and the counts are collected from return values.
  - Output is deterministic (allowed counts, not order).
solution: |
  ```swift
  actor RateLimiter {
      private let limit: Int
      private var counts: [String: Int] = [:]

      init(limit: Int) {
          self.limit = limit
      }

      func allow(_ user: String) -> Bool {
          let used = counts[user, default: 0]
          guard used < limit else { return false }
          counts[user] = used + 1
          return true
      }
  }

  let limiter = RateLimiter(limit: 3)
  let requests = Array(repeating: "ana", count: 10) + ["ben", "ben"]

  let allowed = await withTaskGroup(of: (String, Bool).self) { group in
      for user in requests {
          group.addTask { (user, await limiter.allow(user)) }
      }
      var allowedCounts: [String: Int] = [:]
      for await (user, ok) in group where ok {
          allowedCounts[user, default: 0] += 1
      }
      return allowedCounts
  }
  for user in allowed.keys.sorted() {
      print("\(user): \(allowed[user]!) allowed")
  }
  ```

  ```output
  ana: 3 allowed
  ben: 2 allowed
  ```

  `allow(_:)` has no `await` inside, so between reading `used` and writing `used + 1` nothing else can run on the actor. Twelve concurrent calls, exactly three allowed for Ana every time. If the method awaited something (say, logging to a server) between the check and the increment, you'd be back to the reentrancy bug.
````

````exercise
id: m29-l04-e4
type: find-errors
prompt: "Which lines in this actor don't compile, and why?"
code: |
  actor Playlist: CustomStringConvertible {
      let name: String
      private var songs: [String] = []

      init(name: String) { self.name = name }

      func add(_ song: String) { songs.append(song) }

      var description: String { "\(name) (\(songs.count) songs)" }   // line A

      nonisolated var title: String { name.uppercased() }            // line B
  }

  func fill(_ playlist: Playlist) async {
      await playlist.add("Intro")                                    // line C
      playlist.add("Outro")                                          // line D
      print(playlist.title)                                          // line E
  }
choices:
  - text: "Line A: an actor-isolated description can't satisfy CustomStringConvertible's synchronous requirement, and it reads mutable songs so it can't simply be nonisolated."
    correct: true
    why: "Either drop the song count from description and make it nonisolated, or don't conform."
  - text: "Line B: nonisolated members can't read any property."
    correct: false
    why: "name is an immutable let of a Sendable type, which nonisolated members may read."
  - text: "Line C: you can't await an actor method that is synchronous."
    correct: false
    why: "From outside, every isolated method needs await, whether or not it's async inside."
  - text: "Line D: calling an isolated method from outside without await."
    correct: true
    why: "Swift 6.3: actor-isolated instance method 'add' cannot be called from outside of the actor."
  - text: "Line E: reading title needs await because Playlist is an actor."
    correct: false
    why: "title is nonisolated and only reads the immutable name, so it's called synchronously."
rubric:
  - Identifies line A's conformance problem and why nonisolated alone doesn't fix it.
  - Identifies line D's missing await.
  - Accepts lines B, C and E.
solution: |
  Line A is rejected (`conformance of 'Playlist' to protocol 'CustomStringConvertible' crosses into actor-isolated code`), and marking it `nonisolated` wouldn't help because it reads `songs`. Line D needs `await`. The rest compiles. A fixed version:

  ```swift
  actor Playlist: CustomStringConvertible {
      let name: String
      private var songs: [String] = []

      init(name: String) { self.name = name }

      func add(_ song: String) { songs.append(song) }

      var songCount: Int { songs.count }

      nonisolated var description: String { "Playlist \(name)" }

      nonisolated var title: String { name.uppercased() }
  }

  func fill(_ playlist: Playlist) async {
      await playlist.add("Intro")
      await playlist.add("Outro")
      print(playlist.title)
      print(playlist, "has", await playlist.songCount, "songs")
  }

  await fill(Playlist(name: "Focus"))
  ```

  ```output
  FOCUS
  Playlist Focus has 2 songs
  ```
````

````exercise
id: m29-l04-e5
type: fill-in
prompt: "Complete the code so the view model runs on the main actor, the formatter helper can be called from anywhere, and a background function can update the view model."
code: |
  [[1]]
  final class InboxViewModel {
      private(set) var unread = 0

      func setUnread(_ count: Int) {
          unread = count
      }

      [[2]] func badgeText(for count: Int) -> String {
          count > 99 ? "99+" : "\(count)"
      }
  }

  func syncInbox(_ model: InboxViewModel) async {
      let count = 120
      [[3]] model.setUnread(count)
  }
blanks:
  - id: "1"
    answers: ["@MainActor"]
  - id: "2"
    answers: ["nonisolated"]
  - id: "3"
    answers: ["await"]
solution: |
  - `@MainActor` on the class isolates every member to the main actor.
  - `nonisolated` on `badgeText(for:)`: it only uses its parameter, so it doesn't need the main actor and can be called synchronously from any context.
  - `await`: `syncInbox` is nonisolated, so calling a main-actor method is a hop.

  ```swift
  @MainActor
  final class InboxViewModel {
      private(set) var unread = 0

      func setUnread(_ count: Int) {
          unread = count
      }

      nonisolated func badgeText(for count: Int) -> String {
          count > 99 ? "99+" : "\(count)"
      }
  }

  func syncInbox(_ model: InboxViewModel) async {
      let count = 120
      await model.setUnread(count)
      print(model.badgeText(for: count))
  }

  let model = InboxViewModel()
  await syncInbox(model)
  print(model.unread)
  ```

  ```output
  99+
  120
  ```
````

````exercise
id: m29-l04-e6
type: design
prompt: "Design the concurrency for a chat app's message store: messages arrive from a socket on a background task, the conversation screen displays them, and an image downloader fetches attachments. Say what goes on the main actor, what's an actor, and how you avoid duplicate attachment downloads."
rubric:
  - The screen's state (the visible messages, view model) is @MainActor.
  - Shared non-UI state (the attachment cache/downloader, possibly the message database) is an actor.
  - The socket task hops to the main actor (await) to publish new messages, or the view model pulls from the store.
  - Attachment downloads are deduplicated with in-flight tasks stored before the first await.
  - Mentions keeping heavy work (decoding, image processing) off the main actor and off actors that many callers wait on.
solution: |
  - **`@MainActor` view model** for the conversation screen: the message list it shows, loading flags, errors. Views read it synchronously.
  - **An actor `MessageStore`** that owns the persisted messages, if several features (notifications, search, the screen) read and write them. The socket task calls `await store.append(message)`, then `await viewModel.didReceive(message)` hops to the main actor to update the screen.
  - **An actor `AttachmentCache`** with `images` and `inFlight: [URL: Task<Image, Error>]`. The first caller for a URL stores the task before awaiting, so every other cell asking for it awaits the same task. Remove the task when it finishes, success or failure.
  - **Heavy work off the main actor**: decoding message payloads and resizing images happen in `@concurrent` functions (lesson 6), and only the results go onto the actors. An actor method that resizes an image would make every other caller wait.
````

## Summary

- An actor serializes access to its state: only one task runs its isolated code at a time, and the compiler enforces it. It replaces the lock, the `private` discipline and the `@unchecked` promise.
- From outside, isolated members need `await`; properties can't be mutated from outside at all. Swift 6.3's messages: "can not be referenced from a nonisolated context", "can not be mutated from a nonisolated context", "cannot be called from outside of the actor".
- Actors are **reentrant**: at every `await` inside an actor method, other calls can run. Put checks and updates together before any await, re-check after one, or store in-flight tasks to deduplicate work.
- `nonisolated` marks members that don't need the actor, typically for synchronous protocol requirements and immutable data.
- `@MainActor` (a global actor) can go on types, functions, properties and closures. UIKit and SwiftUI types are already on it. Nonisolated async code hops there with `await` or `MainActor.run`.
- Custom `@globalActor`s share one domain across types; they're rarely needed. Most app state is `@MainActor`; actors are for state shared off the main actor.
