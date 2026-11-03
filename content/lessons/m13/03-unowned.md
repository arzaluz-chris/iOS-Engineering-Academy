---
id: m13-l03
title: unowned and choosing between weak and unowned
description: You learn the second non-owning reference, unowned, which isn't optional and never becomes nil, see the exact crash Swift 6.3 gives when you read one after its object is gone, and use a single question about lifetimes to pick between strong, weak and unowned.
module: m13
order: 3
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l02]
objectives:
  - Declare an unowned reference and explain how it differs from weak.
  - Recognize the runtime trap when an unowned reference outlives its object.
  - Choose between strong, weak and unowned with a lifetime argument.
  - Explain why unowned(unsafe) is avoided in ordinary app code.
terms:
  - term: Unowned reference
    definition: "A reference declared with unowned that doesn't own the object. Unlike weak, it isn't set to nil when the object is freed; you promise the object will still be alive whenever you read it."
  - term: Lifetime guarantee
    definition: "A fact about your design that one object can never outlive another, for example because the parent creates the child and nothing else ever stores it."
  - term: Trap
    definition: "A deliberate stop of the program by a runtime check, such as reading an unowned reference whose object has been freed, or forcing a nil optional. The process ends with a fatal error message."
  - term: "unowned(unsafe)"
    definition: "A variant of unowned with no runtime check. Reading it after the object is freed is undefined behavior: it may return garbage or crash somewhere unrelated."
mastery:
  - Declare an unowned property and use it without unwrapping.
  - Predict what a program prints before it traps on a dead unowned reference.
  - State the lifetime guarantee that makes a given unowned reference safe, or say that there isn't one and use weak.
  - Explain what weak costs you and what unowned costs you when the guarantee is wrong.
resources: [swift-book-arc, swift-book-initialization]
cards:
  - id: m13-l03-c1
    front: How is unowned different from weak?
    back: "Neither owns the object. weak is optional and becomes nil when the object is freed. unowned isn't optional and never becomes nil: reading it after the object is freed traps."
  - id: m13-l03-c2
    front: "What does Swift 6.3 print when you read an unowned reference to a freed object?"
    back: "Fatal error: Attempted to read an unowned reference but object 0x… was already destroyed. Then the program stops."
  - id: m13-l03-c3
    front: When is unowned the right choice?
    back: "When the referenced object is guaranteed to live at least as long as the one holding the reference, typically a child created and owned only by its parent. If you can't state that guarantee, use weak."
  - id: m13-l03-c4
    front: "What's wrong with unowned(unsafe)?"
    back: "It skips the runtime check. Reading it after the object is freed is undefined behavior instead of a clean trap. Keep it out of app code."
---

## The idea in one sentence

`unowned` is a non-owning reference for when you **know** the other object outlives this one: you get a plain, non-optional value, and if you're wrong, the program stops.

## unowned: no ownership, no optional

A `weak` reference costs you an optional. Every read is `team?.name` or a `guard let`, because the object might be gone. Sometimes that "might" isn't real. A lesson created by a course, stored only in that course, can't exist after the course is gone. Writing `course?.title` everywhere would just be noise.

**Plain definition:** an `unowned` reference points at an object without owning it, and you use it like a normal reference.

**Precise definition:** a property declared `unowned let course: Course` doesn't add to the course's strong count. Its type is not optional, and ARC doesn't set it to `nil` when the course is freed. Instead, Swift checks every read: if the object has already been destroyed, the program **traps**.

```swift
final class Course {
    let title: String
    private(set) var lessons: [Lesson] = []

    init(title: String, lessonNames: [String]) {
        self.title = title
        for name in lessonNames {
            lessons.append(Lesson(name: name, course: self))
        }
    }

    deinit {
        print("Course \(title) freed")
    }
}

final class Lesson {
    let name: String
    unowned let course: Course

    init(name: String, course: Course) {
        self.name = name
        self.course = course
    }

    func heading() -> String {
        "\(course.title) / \(name)"
    }

    deinit {
        print("Lesson \(name) freed")
    }
}

var swiftBasics: Course? = Course(title: "Swift Basics", lessonNames: ["Variables", "Loops"])
for lesson in swiftBasics?.lessons ?? [] {
    print(lesson.heading())
}
swiftBasics = nil
print("Done")
```

```output
Swift Basics / Variables
Swift Basics / Loops
Course Swift Basics freed
Lesson Variables freed
Lesson Loops freed
Done
```

Line by line:

1. `unowned let course: Course` declares a non-owning reference that's never optional. It can be a `let`, since a lesson never moves to another course.
2. The course's `init` creates each lesson and passes `self`. Using `self` inside a class's own `init` is allowed once every stored property has a value (Module 10's two-phase initialization): `title` is set and `lessons` has its default.
3. `heading()` reads `course.title` directly. No `?`, no `guard`.
4. `swiftBasics = nil` frees the course. The lessons are only owned by the course's array, so they go with it. No lesson ever reads `course` after the course is gone.

The safety argument lives in the design, not in the type: lessons are created by the course and only stored in the course.

## When the promise breaks

Now keep a lesson somewhere else, past the course's life, and read its `course`:

```swift runtime-error Attempted to read an unowned reference but object
final class Course {
    let title: String

    init(title: String) {
        self.title = title
    }

    deinit {
        print("Course \(title) freed")
    }
}

final class Lesson {
    let name: String
    unowned let course: Course

    init(name: String, course: Course) {
        self.name = name
        self.course = course
    }
}

var course: Course? = Course(title: "Swift Basics")
let bookmarked = Lesson(name: "Loops", course: course!)
print(bookmarked.course.title)
course = nil
print("About to read the course")
print(bookmarked.course.title)
print("Never printed")
```

```output
Swift Basics
Course Swift Basics freed
About to read the course
```

The last read stops the program. On Swift 6.3 the error is:

```plaintext
Fatal error: Attempted to read an unowned reference but object 0x55f9a6689300 was already destroyed
```

The address changes from run to run. The message tells you two things: which kind of reference failed (unowned), and that the object it pointed at had already been freed.

A trap is bad, but it's the **good** kind of bad. The program stops at the exact line that broke the rule, with a clear message, every time. The alternative, reading memory that now belongs to something else, produces bugs that show up later and somewhere unrelated.

> [!note] Optional unowned
> Since Swift 5 you can also write `unowned var x: T?`. The optional only means "may not have been set yet" or "may be set to nil by your code". ARC still won't set it to `nil` for you, and reading it after the object is freed still traps. It's rare; if you're reaching for it, `weak` is probably what you want.

## Choosing: strong, weak or unowned

Ask one question about each reference: **can the object I'm pointing at be freed while I'm still around and might read this?**

| Situation | Use | What a mistake costs |
| --- | --- | --- |
| This object should keep the other alive (it owns it) | strong | A cycle, if the other one also owns you back |
| The other object may go away first, and that's normal | `weak` | Nothing: you read `nil` and handle it |
| The other object is guaranteed to outlive this one | `unowned` | A trap at the first read after it's freed |

Typical cases:

- **Strong.** A screen and its view model, a folder and its notes, an array of downloads. Ownership flows downward.
- **weak.** Delegates. Back-pointers to parents when a child can be handed elsewhere (a member who might outlive a chat room, a track that can be added to another playlist). Anything observing something else.
- **unowned.** A child whose existence makes no sense without its parent and that nothing else stores: a credit card that belongs to exactly one customer and is created with it, a lesson created by its course. Also closures that can't outlive their object (next lesson).

When you're unsure, choose `weak`. The `?` it adds costs a little typing. A wrong `unowned` costs a crash in front of a user.

> [!warning] unowned(unsafe)
> There's a third form, `unowned(unsafe)`, which skips the runtime check. Reading it after the object is freed doesn't trap; it's **undefined behavior**: it may print garbage, corrupt another object or crash much later. It exists for rare performance-critical code and for interoperating with C. You shouldn't need it in an app, and if you see it in a code review, ask why.

## A practical example: a game and its players

A `Game` creates its players and owns them. Each player needs the game to compute their rank. Players are never handed to anything else, so `unowned` fits:

```swift
final class Game {
    let name: String
    private(set) var players: [Player] = []

    init(name: String) {
        self.name = name
    }

    func addPlayer(named playerName: String, score: Int) {
        players.append(Player(name: playerName, score: score, game: self))
    }

    func rank(of player: Player) -> Int {
        var better = 0
        for other in players where other.score > player.score {
            better += 1
        }
        return better + 1
    }

    deinit {
        print("Game \(name) ended")
    }
}

final class Player {
    let name: String
    let score: Int
    unowned let game: Game

    init(name: String, score: Int, game: Game) {
        self.name = name
        self.score = score
        self.game = game
    }

    func summary() -> String {
        "\(name): \(score) points, rank \(game.rank(of: self)) in \(game.name)"
    }
}

var game: Game? = Game(name: "Trivia Night")
game?.addPlayer(named: "Iris", score: 40)
game?.addPlayer(named: "Omar", score: 55)
game?.addPlayer(named: "Lu", score: 40)
for player in game?.players ?? [] {
    print(player.summary())
}
game = nil
```

```output
Iris: 40 points, rank 2 in Trivia Night
Omar: 55 points, rank 1 in Trivia Night
Lu: 40 points, rank 2 in Trivia Night
Game Trivia Night ended
```

`addPlayer` is the only way to create a player for a game, and the game's array is the only place players live. That's the lifetime guarantee. If a future feature keeps players around after a game ends (a "hall of fame" screen, say), that guarantee breaks, and `game` must become `weak var game: Game?`. Write the guarantee down in a comment next to the `unowned` when it's not obvious, so the next person knows what they'd be breaking.

## Common mistakes

> [!error] Fatal error: Attempted to read an unowned reference but object 0x… was already destroyed
> An unowned reference outlived its object. Find who else is holding the object that has the `unowned` property (a cache, a global, an array) and either stop them, or switch the reference to `weak` and handle `nil`.

> [!error] error: 'unowned' may only be applied to class and class-bound protocol types, not 'Int'
> Like `weak`, `unowned` only applies to class references. Value types are copied; there's nothing to point at without owning.

```swift no-compile 'unowned' may only be applied to class and class-bound protocol types, not 'Int'
final class Counter {
    unowned var count: Int = 0
}
```

> [!error] Using unowned to avoid optionals
> `unowned` isn't a shortcut around `?`. Use it only when you can state the lifetime guarantee in one sentence. "It's annoying to unwrap" isn't one.

> [!error] Thinking unowned becomes nil
> It doesn't. `if bookmarked.course == nil` doesn't even make sense, because the type isn't optional. Only `weak` is cleared.

````exercise
id: m13-l03-e1
type: comprehension
prompt: Which reference is the best candidate for unowned?
choices:
  - text: "A `CreditCard` pointing to the `Customer` that created it, where cards are only stored in that customer's array and a card can't exist without a customer."
    correct: true
    why: "The card is created by and stored only in its customer, so the customer always outlives it."
  - text: "A `DownloadTask`'s delegate, which is whatever screen started the download."
    correct: false
    why: "The user can close the screen while the download continues. The delegate may go away first: weak."
  - text: "A `Member` pointing to the `ChatRoom` they joined, where rooms can be closed while members stay online."
    correct: false
    why: "The member can outlive the room. With unowned, the next message after the room closes would trap. Use weak."
  - text: "A `Screen` pointing to its `ViewModel`, which only the screen uses."
    correct: false
    why: "The screen owns its view model. That's a strong reference, not unowned."
solution: |
  **The credit card.** unowned is right only when the referenced object is guaranteed to outlive the one holding the reference. A card that only exists inside its customer's array fits. The delegate and the chat room can go away first, so they need weak. The view model is owned, so it's strong.
````

````exercise
id: m13-l03-e2
type: prediction
prompt: This program stops with a runtime error. Predict everything it prints before stopping.
code: |
  final class Store {
      let name: String

      init(name: String) {
          self.name = name
      }

      deinit {
          print("Store closed")
      }
  }

  final class Receipt {
      let total: Int
      unowned let store: Store

      init(total: Int, store: Store) {
          self.total = total
          self.store = store
      }
  }

  var store: Store? = Store(name: "Corner Shop")
  let receipt = Receipt(total: 12, store: store!)
  print("\(receipt.total) at \(receipt.store.name)")
  store = nil
  print("Total: \(receipt.total)")
  print("Store: \(receipt.store.name)")
  print("End")
output: |
  12 at Corner Shop
  Store closed
  Total: 12
hints:
  - "Which reads touch the unowned reference, and which only read the receipt's own property?"
  - "When is the store freed?"
solution: |
  ```output
  12 at Corner Shop
  Store closed
  Total: 12
  ```

  The receipt doesn't own the store, so `store = nil` frees it right away and "Store closed" prints. Reading `receipt.total` is fine: it's the receipt's own property. Reading `receipt.store.name` reads the unowned reference after its object was destroyed, and the program stops with "Fatal error: Attempted to read an unowned reference but object 0x… was already destroyed". "End" never prints.

  The fix depends on intent. A receipt you keep after the store closes shouldn't point at the store at all: copy the name into a `let storeName: String`.
````

````exercise
id: m13-l03-e3
type: find-errors
prompt: "A teammate swapped weak for unowned \"to get rid of the question marks\". Which statements about this code are true?"
code: |
  protocol PlayerDelegate: AnyObject {
      func playerDidFinish()
  }

  final class AudioPlayer {
      unowned var delegate: PlayerDelegate

      init(delegate: PlayerDelegate) {
          self.delegate = delegate
      }

      func finish() {
          delegate.playerDidFinish()
      }
  }
choices:
  - text: "If the delegate (say, a screen) is freed while the player keeps playing, finish() traps."
    correct: true
    why: "Nothing guarantees the delegate outlives the player. A screen can be closed while audio continues."
  - text: "The player now has to be given a delegate at creation and can never be without one."
    correct: true
    why: "A non-optional unowned property must be set in init. That's a design change that doesn't fit a delegate, which is often set later or not at all."
  - text: "The code doesn't compile, because unowned can't be used with protocol types."
    correct: false
    why: "It compiles: PlayerDelegate is class-bound, so unowned is allowed."
  - text: "unowned creates a reference cycle between the player and the delegate."
    correct: false
    why: "unowned doesn't own, so it can't create a cycle. The problem is the opposite: nothing keeps the delegate alive."
rubric:
  - I identified the trap when the delegate goes away first.
  - I noticed the forced init parameter.
  - I restored weak var delegate with an optional type and optional chaining.
solution: |
  Both true statements point the same way: a delegate is the textbook case for **weak**. The player can't promise its delegate stays alive, and a player without a delegate is perfectly valid.

  ```swift
  protocol PlayerDelegate: AnyObject {
      func playerDidFinish()
  }

  final class AudioPlayer {
      weak var delegate: PlayerDelegate?

      func finish() {
          delegate?.playerDidFinish()
      }
  }

  final class NowPlayingScreen: PlayerDelegate {
      func playerDidFinish() {
          print("Show replay button")
      }
  }

  let player = AudioPlayer()
  var screen: NowPlayingScreen? = NowPlayingScreen()
  player.delegate = screen
  player.finish()
  screen = nil
  player.finish()
  print("No crash")
  ```

  ```output
  Show replay button
  No crash
  ```

  After the screen is freed, `delegate?.playerDidFinish()` does nothing instead of trapping.
````

````exercise
id: m13-l03-e4
type: solve
prompt: |
  A `Building` creates its `Elevator`s, and each elevator needs its building's name for status messages. Elevators are never stored anywhere else. Fill in the reference from elevator to building using the most fitting kind, so the program prints exactly:

  ```output
  Elevator A in Tower One at floor 0
  Elevator B in Tower One at floor 0
  Tower One demolished
  ```
starter: |
  final class Building {
      let name: String
      private(set) var elevators: [Elevator] = []

      init(name: String, elevatorIDs: [String]) {
          self.name = name
          for id in elevatorIDs {
              elevators.append(Elevator(id: id, building: self))
          }
      }

      deinit {
          print("\(name) demolished")
      }
  }

  final class Elevator {
      let id: String
      var floor = 0
      // the reference to the building

      init(id: String, building: Building) {
          self.id = id
      }

      func status() -> String {
          ""
      }
  }

  var tower: Building? = Building(name: "Tower One", elevatorIDs: ["A", "B"])
  for elevator in tower?.elevators ?? [] {
      print(elevator.status())
  }
  tower = nil
hints:
  - "Can an elevator outlive its building in this program?"
  - "unowned lets status() read building.name without unwrapping."
rubric:
  - I chose unowned and stated the lifetime guarantee.
  - The init stores the building.
  - status() builds the message without unwrapping.
  - The output matches exactly, including the deinit line.
solution: |
  ```swift
  final class Building {
      let name: String
      private(set) var elevators: [Elevator] = []

      init(name: String, elevatorIDs: [String]) {
          self.name = name
          for id in elevatorIDs {
              elevators.append(Elevator(id: id, building: self))
          }
      }

      deinit {
          print("\(name) demolished")
      }
  }

  final class Elevator {
      let id: String
      var floor = 0
      unowned let building: Building

      init(id: String, building: Building) {
          self.id = id
          self.building = building
      }

      func status() -> String {
          "Elevator \(id) in \(building.name) at floor \(floor)"
      }
  }

  var tower: Building? = Building(name: "Tower One", elevatorIDs: ["A", "B"])
  for elevator in tower?.elevators ?? [] {
      print(elevator.status())
  }
  tower = nil
  ```

  ```output
  Elevator A in Tower One at floor 0
  Elevator B in Tower One at floor 0
  Tower One demolished
  ```

  The guarantee: elevators are created only by the building and stored only in its array, so the building always outlives them. `weak var building: Building?` would also be correct and would print the same thing; it would just add `building?.name ?? "?"` to `status()`. A strong reference would form a cycle, and "Tower One demolished" would never print.
````

````exercise
id: m13-l03-e5
type: explain
prompt: Explain why a trap from a dead unowned reference is better than what unowned(unsafe) does in the same situation, and why weak is still the safer default.
code: |
  unowned let owner: Account
  unowned(unsafe) let fastOwner: Account
  weak var maybeOwner: Account?
rubric:
  - I said unowned checks on every read and traps with a clear message at the faulty line.
  - I said unowned(unsafe) skips the check, so reading a freed object is undefined behavior that may surface later and elsewhere.
  - I said weak turns the same situation into a nil you handle, with no crash at all.
  - I tied the choice to whether a lifetime guarantee exists.
solution: |
  All three point at an `Account` without owning it. They differ in what happens if the account is freed and you read the reference anyway.

  - `unowned` checks every read. If the object is gone, the program stops right there with "Attempted to read an unowned reference but object … was already destroyed". You get a crash report that points at the exact line.
  - `unowned(unsafe)` skips the check. The read uses whatever is now at that memory address: maybe garbage, maybe another object. The symptom shows up later, somewhere unrelated, and might not reproduce. That's why it's for specialized low-level code, not apps.
  - `weak` turns the same situation into `nil`. Nothing crashes; your code takes the "no account" branch.

  So: if you can state a lifetime guarantee, `unowned` is honest and cheap to read. If you can't, `weak` is the right tool, and the optional it adds is the price of not crashing.
````

## Summary

- `unowned` doesn't own the object, isn't optional, and isn't cleared when the object is freed.
- Reading an `unowned` reference after its object is freed traps. Swift 6.3: "Fatal error: Attempted to read an unowned reference but object 0x… was already destroyed".
- Use `unowned` only when you can state the lifetime guarantee: the other object always outlives this one. Typical case: a child created and stored only by its parent.
- When in doubt, use `weak`. A `?` is cheaper than a crash.
- `unowned(unsafe)` skips the check and turns the trap into undefined behavior. Avoid it.
