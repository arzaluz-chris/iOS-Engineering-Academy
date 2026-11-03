---
id: m13-l02
title: Reference cycles and weak
description: You build two objects that own each other and watch their deinit never run, break the cycle with a weak reference, see a weak reference turn into nil when its object is freed, and apply the two patterns that use weak every day in iOS code, parent and child, and delegates.
module: m13
order: 2
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l01]
objectives:
  - Explain why two objects that own each other are never freed under ARC.
  - Break a reference cycle by making one side weak.
  - Predict when a weak reference becomes nil and read it safely.
  - Apply the parent-and-child rule, strong down and weak up.
  - Declare a class-bound delegate protocol and a weak delegate property.
terms:
  - term: Reference cycle
    definition: "Two or more objects that hold strong references to each other in a loop. Each keeps the next one's count above zero, so none of them is freed, even when nothing else can reach them. Also called a retain cycle."
  - term: Weak reference
    definition: "A reference declared with weak that doesn't own the object: it doesn't add to the strong count. It must have an optional type, and ARC sets it to nil when the object is freed."
  - term: Parent and child
    definition: "A relationship where one object (the parent) owns others (the children), and each child keeps a pointer back to its parent. The parent holds its children strongly; the back-pointer is weak."
  - term: Delegate
    definition: "An object that another object reports to or asks for decisions, through a protocol. The object that delegates doesn't own its delegate, so the property is weak."
  - term: Class-bound protocol
    definition: "A protocol that only classes can adopt, declared with protocol Name: AnyObject. Required for a weak property whose type is the protocol."
mastery:
  - Build a two-object cycle and show with deinit that neither is freed.
  - Choose which side of a relationship becomes weak and justify it by ownership.
  - Predict the output of code that reads a weak property before and after its object is freed.
  - Fix "'weak' variable should have optional type" and "'weak' must not be applied to non-class-bound" without help.
  - Write a delegate protocol and a weak delegate property for a class that reports progress.
resources: [swift-book-arc, swift-book-structures-classes]
cards:
  - id: m13-l02-c1
    front: Why is a reference cycle never freed under ARC?
    back: "Each object in the loop holds a strong reference to the next, so every count stays at least 1. ARC only frees an object when its count reaches zero, and it never looks at whether the group is reachable."
  - id: m13-l02-c2
    front: What does a weak reference do when its object is freed?
    back: "ARC sets it to nil. That's why a weak property must have an optional type."
  - id: m13-l02-c3
    front: In a parent-child relationship, which side is weak?
    back: "The child's pointer back to the parent. The parent owns its children strongly; children don't own their parent."
  - id: m13-l02-c4
    front: "Why does a delegate protocol often say `: AnyObject`?"
    back: "weak only works on class references. Restricting the protocol to classes lets you declare weak var delegate: SomeDelegate?."
  - id: m13-l02-c5
    front: "What warning do you get for `weak var screen = Screen()`?"
    back: "instance will be immediately deallocated because variable 'screen' is 'weak'. Nothing else owns the new object, so it's freed at once."
---

## The idea in one sentence

If two objects own each other, ARC will never free either one, so one of the two references has to be **weak**: a reference that points at an object without owning it.

## A cycle you can watch

A team has a coach, and the coach knows which team they coach. Both properties are ordinary, strong references:

```swift
final class Team {
    let name: String
    var coach: Coach?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Team \(name) freed")
    }
}

final class Coach {
    let name: String
    var team: Team?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Coach \(name) freed")
    }
}

var team: Team? = Team(name: "Falcons")
var coach: Coach? = Coach(name: "Rivera")
team?.coach = coach
coach?.team = team

team = nil
coach = nil
print("Both variables are nil")
```

```output
Both variables are nil
```

Neither `deinit` runs. Count the owners:

| After | Team owners | Coach owners |
| --- | --- | --- |
| both created | `team` | `coach` |
| `team?.coach = coach` | `team` | `coach`, `Team.coach` |
| `coach?.team = team` | `team`, `Coach.team` | `coach`, `Team.coach` |
| `team = nil` | `Coach.team` | `coach`, `Team.coach` |
| `coach = nil` | `Coach.team` | `Team.coach` |

Each object is held by the other. Nothing in the program can reach either of them anymore, but both counts are 1, so ARC keeps both. This is a **reference cycle** (Apple's docs and Xcode also call it a **strong reference cycle** or retain cycle), and the memory is **leaked**: allocated and unusable until the process ends.

A tracing garbage collector would notice that the pair is unreachable. ARC doesn't look at reachability. It only reacts to counts.

## weak: pointing without owning

**Plain definition:** a `weak` reference lets you reach an object without keeping it alive.

**Precise definition:** a property or variable declared with `weak` holds a reference that doesn't add to the object's strong count. Its type must be an **optional**, because ARC sets it to `nil` automatically when the object is freed.

Make the coach's reference to the team weak and run the same steps:

```swift
final class Team {
    let name: String
    var coach: Coach?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Team \(name) freed")
    }
}

final class Coach {
    let name: String
    weak var team: Team?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Coach \(name) freed")
    }
}

var team: Team? = Team(name: "Falcons")
var coach: Coach? = Coach(name: "Rivera")
team?.coach = coach
coach?.team = team

team = nil
coach = nil
print("Both variables are nil")
```

```output
Team Falcons freed
Coach Rivera freed
Both variables are nil
```

Walk through it:

1. `coach?.team = team` no longer adds an owner. The team's only owner is the variable `team`.
2. `team = nil` drops it to zero. The team's `deinit` runs, and as the team is destroyed it releases its own properties, including `coach`. The coach still has the variable `coach`, so it survives.
3. `coach = nil` frees the coach.

One word fixed the leak. Which side gets the word is the real decision, and it comes from ownership, below.

## A weak reference becomes nil

When the object behind a weak reference is freed, the reference doesn't dangle. ARC sets it to `nil`, and the next read sees that:

```swift
final class Team {
    let name: String

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Team \(name) freed")
    }
}

final class Coach {
    weak var team: Team?
}

var team: Team? = Team(name: "Falcons")
let coach = Coach()
coach.team = team
print(coach.team?.name ?? "no team")
team = nil
print(coach.team?.name ?? "no team")
```

```output
Falcons
Team Falcons freed
no team
```

Because the value can vanish at any moment, you always read a weak reference as an optional: optional chaining, `??`, `if let` or `guard let`. When you need to use it for several lines, unwrap it once:

```swift
final class Team {
    let name: String

    init(name: String) {
        self.name = name
    }
}

final class Coach {
    let name: String
    weak var team: Team?

    init(name: String) {
        self.name = name
    }

    func introduce() {
        guard let team else {
            print("\(name) is between jobs")
            return
        }
        print("\(name) coaches the \(team.name)")
    }
}

let coach = Coach(name: "Rivera")
var falcons: Team? = Team(name: "Falcons")
coach.team = falcons
coach.introduce()
falcons = nil
coach.introduce()
```

```output
Rivera coaches the Falcons
Rivera is between jobs
```

Inside `introduce()`, `guard let team` creates a local strong reference, so the team can't disappear halfway through the method.

> [!version] weak let
> Older Swift required `weak var`, and most code you'll read still uses it. Since Swift 6.2 (SE-0481) you can also write `weak let` for a weak reference that's set once in `init` and never reassigned. It still becomes `nil` when the object is freed; `let` only means your code can't point it somewhere else. This course uses `weak var`, which works in every Swift version.

## Who owns whom

To pick the weak side, ask: **which object should be able to keep the other alive?** That one holds a strong reference. The other one points back weakly.

### Parent and child

When one object contains or manages others, the container is the parent. The parent owns its children; a child only needs a way back. **Strong down, weak up.**

```swift
final class Folder {
    let name: String
    private(set) var notes: [Note] = []

    init(name: String) {
        self.name = name
    }

    func add(_ note: Note) {
        notes.append(note)
        note.folder = self
    }

    deinit {
        print("Folder \(name) freed")
    }
}

final class Note {
    let title: String
    weak var folder: Folder?

    init(title: String) {
        self.title = title
    }

    func path() -> String {
        "\(folder?.name ?? "?")/\(title)"
    }

    deinit {
        print("Note \(title) freed")
    }
}

var work: Folder? = Folder(name: "Work")
work?.add(Note(title: "Standup"))
work?.add(Note(title: "Retro"))
print(work?.notes[0].path() ?? "")
work = nil
print("Folder dropped")
```

```output
Work/Standup
Folder Work freed
Note Standup freed
Note Retro freed
Folder dropped
```

The folder's `deinit` prints first. Then, as the folder's memory is torn down, its `notes` array is released, and each note loses its only owner. One `nil` frees the whole tree. If `Note.folder` were strong, every note would keep the folder alive and the folder would keep every note alive.

### Delegates

The **delegate** pattern is everywhere in UIKit: a table view tells its delegate when a row is tapped, a text field asks its delegate whether to allow an edit. The object doing the work defines a protocol and keeps a property of that protocol type. Whatever object conforms gets the callbacks.

The screen usually **owns** the worker and is also its delegate. If the worker held the delegate strongly, screen and worker would form a cycle. So the delegate property is weak. To make a protocol-typed property weak, the protocol has to be limited to classes with `: AnyObject`:

```swift
protocol DownloadDelegate: AnyObject {
    func downloadDidProgress(_ percent: Int)
    func downloadDidFinish()
}

final class Download {
    weak var delegate: DownloadDelegate?

    func run() {
        for percent in [50, 100] {
            delegate?.downloadDidProgress(percent)
        }
        delegate?.downloadDidFinish()
    }

    deinit {
        print("Download freed")
    }
}

final class DownloadScreen: DownloadDelegate {
    let download = Download()

    init() {
        download.delegate = self
    }

    func downloadDidProgress(_ percent: Int) {
        print("Progress: \(percent)%")
    }

    func downloadDidFinish() {
        print("Finished")
    }

    deinit {
        print("Screen freed")
    }
}

var screen: DownloadScreen? = DownloadScreen()
screen?.download.run()
screen = nil
```

```output
Progress: 50%
Progress: 100%
Finished
Screen freed
Download freed
```

`AnyObject` is a protocol that every class conforms to automatically. Writing `protocol DownloadDelegate: AnyObject` makes it a **class-bound protocol**: only classes can adopt it, so Swift knows any value of type `DownloadDelegate` is a reference and can be held weakly.

The screen owns the download (strong, down). The download reports to the screen (weak, up). Dropping the screen frees both.

## A practical example: a chat room and its members

A chat room owns its members. Each member can post to the room they're in. A member who leaves a room that's already been closed should find out, not crash or keep the room alive:

```swift
final class ChatRoom {
    let topic: String
    private(set) var members: [Member] = []

    init(topic: String) {
        self.topic = topic
    }

    func join(_ member: Member) {
        members.append(member)
        member.room = self
    }

    func broadcast(_ text: String, from sender: String) {
        print("[\(topic)] \(sender): \(text)")
    }

    deinit {
        print("Room \(topic) closed")
    }
}

final class Member {
    let name: String
    weak var room: ChatRoom?

    init(name: String) {
        self.name = name
    }

    func say(_ text: String) {
        guard let room else {
            print("\(name) isn't in a room")
            return
        }
        room.broadcast(text, from: name)
    }
}

let lena = Member(name: "Lena")
var room: ChatRoom? = ChatRoom(topic: "swift")
room?.join(lena)
lena.say("Hi all")
room = nil
lena.say("Anyone here?")
```

```output
[swift] Lena: Hi all
Room swift closed
Lena isn't in a room
```

`lena` is owned by the top-level constant and by the room's array. When the room goes, `lena.room` becomes `nil` on its own, and `say` handles that case. Nobody had to remember to clear the back-pointer.

## Common mistakes

> [!error] error: 'weak' variable should have optional type 'Team?'
> A weak reference can become `nil` at any time, so its type must be optional. Write `weak var team: Team?`.

```swift no-compile 'weak' variable should have optional type 'Team?'
final class Team {}
final class Coach {
    weak var team: Team
    init(team: Team) {
        self.team = team
    }
}
```

> [!error] error: 'weak' must not be applied to non-class-bound 'any DownloadDelegate'; consider adding a protocol conformance that has a class bound
> A struct could conform to the protocol, and a struct can't be referenced weakly. Add `: AnyObject` to the protocol.

```swift no-compile 'weak' must not be applied to non-class-bound
protocol DownloadDelegate {
    func downloadDidFinish()
}

final class Download {
    weak var delegate: DownloadDelegate?
}
```

> [!error] error: 'weak' may only be applied to class and class-bound protocol types, not 'Int'
> `weak` is about ARC, and ARC only counts class instances. A value type has nothing to point at weakly.

> [!warning] warning: instance will be immediately deallocated because variable 'screen' is 'weak'
> `weak var screen = Screen()` creates an object whose only reference is weak. Nothing owns it, so it's freed on the spot and `screen` is `nil`. Assign to a strong reference first, then point the weak one at it.

```swift warning instance will be immediately deallocated because variable 'screen' is 'weak'
final class Screen {}

do {
    weak var screen: Screen? = Screen()
    print(screen == nil)
}
```

```output
true
```

> [!error] Making both sides weak
> If neither side is strong, nothing owns either object, and they vanish as soon as your local variables do. Exactly one direction owns: the parent, the screen, the room.

> [!error] Making the wrong side weak
> If the folder held its notes weakly, a note created with `folder.add(Note(title: "x"))` would be freed right after the call, because nothing else owns it. Weak goes on the reference that points **back up** toward the owner.

````exercise
id: m13-l02-e1
type: comprehension
prompt: "An `Owner` holds a strong reference to a `Pet`, and the `Pet` holds a strong reference back to the `Owner`. The program sets both of its variables to nil. Why does neither deinit run?"
choices:
  - text: "Each object still has one owner, the other object, so neither strong count reaches zero."
    correct: true
    why: "ARC frees an object only when its count reaches zero. The two internal references keep both counts at 1."
  - text: "ARC only frees objects at the end of the program."
    correct: false
    why: "ARC frees an object as soon as its count reaches zero, in the middle of the program."
  - text: "deinit doesn't run for objects stored in optional variables."
    correct: false
    why: "Optionals are how the examples drop references. deinit runs normally when the count reaches zero."
  - text: "ARC detects the cycle but waits for memory pressure before freeing it."
    correct: false
    why: "ARC never detects cycles. Without a weak or unowned reference, the pair stays allocated until the process ends."
solution: |
  **Each object still has one owner.** Setting the variables to nil removes the outside owners, but the two properties still hold strong references to each other. ARC acts only on counts, and both counts are 1. The fix is to make one of the two properties weak, the one that points from the pet back to its owner.
````

````exercise
id: m13-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Owner {
      let name: String

      init(name: String) {
          self.name = name
      }

      deinit {
          print("\(name) freed")
      }
  }

  final class Dog {
      weak var owner: Owner?
  }

  let dog = Dog()
  var owner: Owner? = Owner(name: "Kim")
  var walker = owner
  dog.owner = owner
  owner = nil
  print(dog.owner?.name ?? "stray")
  walker = nil
  print(dog.owner?.name ?? "stray")
output: |
  Kim
  Kim freed
  stray
hints:
  - "Count only the strong owners. dog.owner isn't one."
  - "After owner = nil, is there still a strong reference?"
solution: |
  ```output
  Kim
  Kim freed
  stray
  ```

  The strong owners are `owner` and `walker`. `dog.owner` points at Kim without owning her. After `owner = nil`, `walker` still owns Kim, so the weak reference still reads "Kim". `walker = nil` removes the last strong owner: `deinit` prints, and ARC sets `dog.owner` to `nil`, so the last line prints "stray".
````

````exercise
id: m13-l02-e3
type: find-errors
prompt: "A progress reporter and its delegate. Which of these are real problems?"
code: |
  protocol UploadDelegate {
      func uploadDidFinish()
  }

  final class Uploader {
      weak var delegate: UploadDelegate
      var screen: UploadScreen?
  }

  final class UploadScreen: UploadDelegate {
      var uploader = Uploader()

      init() {
          uploader.delegate = self
          uploader.screen = self
      }

      func uploadDidFinish() {
          print("Done")
      }
  }
choices:
  - text: "The protocol isn't class-bound, so weak can't be applied to a property of that type."
    correct: true
    why: "Add : AnyObject to UploadDelegate."
  - text: "The delegate property isn't optional; weak requires an optional type."
    correct: true
    why: "weak var delegate: UploadDelegate?"
  - text: "Uploader.screen is a strong reference back to the screen that owns the uploader, a cycle even after the delegate is fixed."
    correct: true
    why: "The screen owns the uploader, and the uploader owns the screen. The screen property is redundant with the delegate and should go (or be weak)."
  - text: "UploadScreen must be a struct for the delegate pattern to work."
    correct: false
    why: "It must be a class: a weak reference can only point at a class instance."
  - text: "uploader should be weak in UploadScreen."
    correct: false
    why: "The screen owns its uploader. If it were weak, the new Uploader would be freed immediately."
rubric:
  - I made the protocol class-bound with AnyObject.
  - I made the delegate property optional.
  - I removed the strong screen back-reference or made it weak.
  - I kept the screen's reference to the uploader strong and explained why.
solution: |
  Three real problems, and one of them hides behind the other two: once the compile errors are fixed, `Uploader.screen` would still leak both objects.

  ```swift
  protocol UploadDelegate: AnyObject {
      func uploadDidFinish()
  }

  final class Uploader {
      weak var delegate: UploadDelegate?

      func finish() {
          delegate?.uploadDidFinish()
      }

      deinit {
          print("Uploader freed")
      }
  }

  final class UploadScreen: UploadDelegate {
      let uploader = Uploader()

      init() {
          uploader.delegate = self
      }

      func uploadDidFinish() {
          print("Done")
      }

      deinit {
          print("Screen freed")
      }
  }

  var screen: UploadScreen? = UploadScreen()
  screen?.uploader.finish()
  screen = nil
  ```

  ```output
  Done
  Screen freed
  Uploader freed
  ```

  The `screen` property did nothing the delegate didn't already do, so it's gone. `uploader` became a `let`: the screen creates it once and owns it for life.
````

````exercise
id: m13-l02-e4
type: solve
prompt: |
  A customer has orders, and each order knows its customer. As written, dropping the customer frees nothing. Fix it so this program prints exactly:

  ```output
  Order 1 for Ana
  Order 2 for Ana
  Customer Ana freed
  Order 1 freed
  Order 2 freed
  ```
starter: |
  final class Customer {
      let name: String
      var orders: [Order] = []

      init(name: String) {
          self.name = name
      }

      func place(_ order: Order) {
          orders.append(order)
          order.customer = self
      }

      deinit {
          print("Customer \(name) freed")
      }
  }

  final class Order {
      let number: Int
      var customer: Customer?

      init(number: Int) {
          self.number = number
      }

      func label() -> String {
          "Order \(number) for \(customer?.name ?? "?")"
      }

      deinit {
          print("Order \(number) freed")
      }
  }

  var ana: Customer? = Customer(name: "Ana")
  ana?.place(Order(number: 1))
  ana?.place(Order(number: 2))
  for order in ana?.orders ?? [] {
      print(order.label())
  }
  ana = nil
hints:
  - "Which object should keep the other alive: the customer or the order?"
  - "Strong down, weak up."
rubric:
  - I changed exactly one declaration.
  - "Order.customer is weak var customer: Customer?."
  - I can explain why making Customer.orders weak wouldn't work.
  - The output matches exactly.
solution: |
  ```swift
  final class Customer {
      let name: String
      var orders: [Order] = []

      init(name: String) {
          self.name = name
      }

      func place(_ order: Order) {
          orders.append(order)
          order.customer = self
      }

      deinit {
          print("Customer \(name) freed")
      }
  }

  final class Order {
      let number: Int
      weak var customer: Customer?

      init(number: Int) {
          self.number = number
      }

      func label() -> String {
          "Order \(number) for \(customer?.name ?? "?")"
      }

      deinit {
          print("Order \(number) freed")
      }
  }

  var ana: Customer? = Customer(name: "Ana")
  ana?.place(Order(number: 1))
  ana?.place(Order(number: 2))
  for order in ana?.orders ?? [] {
      print(order.label())
  }
  ana = nil
  ```

  ```output
  Order 1 for Ana
  Order 2 for Ana
  Customer Ana freed
  Order 1 freed
  Order 2 freed
  ```

  The customer is the parent: it owns the orders. Each order's `customer` points back up, so it's weak. You can't put `weak` on the array (an array of weak references isn't something `weak var` can express), and even if you could, `ana?.place(Order(number: 1))` would create orders that nothing owns. The `for` loop's `order` constants are released at the end of each iteration, so they don't keep anything alive when `ana = nil` runs.
````

````exercise
id: m13-l02-e5
type: design
prompt: |
  For each relationship, say which reference is strong and which is weak (or whether there's no back-reference at all), and justify it by ownership:

  1. A `Playlist` with an array of `Track`s, where each track can show the playlist name.
  2. A `LoginForm` class that uses a `PasswordValidator` class and reports results to a `LoginFormDelegate`.
  3. A `Library` that holds `Book`s, and a `Book` that holds a `Library` so it can be returned.
rubric:
  - I made Playlist → Track strong and Track → Playlist weak.
  - I made LoginForm → PasswordValidator strong (it owns its helper) and the delegate weak, with a class-bound protocol.
  - "I recognized Library/Book as parent and child: library strong, book's library weak."
  - Each answer names which object should be able to keep the other alive.
solution: |
  1. **Playlist strong to tracks, track weak to playlist.** The playlist contains the tracks. A track showing its playlist's name doesn't make it responsible for keeping the playlist around.
  2. **LoginForm strong to validator; delegate weak.** The form creates and uses the validator: nobody else needs it, so the form owns it. The delegate is usually the screen that owns the form, so `weak var delegate: LoginFormDelegate?` with `protocol LoginFormDelegate: AnyObject`.
  3. **Library strong to books, book weak to library.** It's the same parent-child shape as the playlist. If a book owned its library, any book you kept around (say, in a "recently viewed" list) would keep the whole library and every other book alive.

  The question is always the same: if this reference were the only one left, should the object stay alive? If yes, strong. If no, weak.
````

````exercise
id: m13-l02-e6
type: fill-in
prompt: |
  Complete the delegate so the program prints exactly:

  ```output
  Saved 3 items
  Editor freed
  ```
code: |
  protocol SaveDelegate: [[1]] {
      func didSave(count: Int)
  }

  final class Saver {
      [[2]] var delegate: SaveDelegate[[3]]

      func save(count: Int) {
          delegate?.didSave(count: count)
      }
  }

  final class Editor: SaveDelegate {
      let saver = Saver()

      init() {
          saver.delegate = self
      }

      func didSave(count: Int) {
          print("Saved \(count) items")
      }

      deinit {
          print("Editor freed")
      }
  }

  var editor: Editor? = Editor()
  editor?.saver.save(count: 3)
  editor = nil
blanks:
  - id: "1"
    answers: ["AnyObject"]
  - id: "2"
    answers: ["weak"]
  - id: "3"
    answers: ["?"]
solution: |
  ```swift
  protocol SaveDelegate: AnyObject {
      func didSave(count: Int)
  }

  final class Saver {
      weak var delegate: SaveDelegate?

      func save(count: Int) {
          delegate?.didSave(count: count)
      }
  }

  final class Editor: SaveDelegate {
      let saver = Saver()

      init() {
          saver.delegate = self
      }

      func didSave(count: Int) {
          print("Saved \(count) items")
      }

      deinit {
          print("Editor freed")
      }
  }

  var editor: Editor? = Editor()
  editor?.saver.save(count: 3)
  editor = nil
  ```

  ```output
  Saved 3 items
  Editor freed
  ```

  `AnyObject` makes the protocol class-bound, `weak` keeps the saver from owning its editor, and `?` is required because a weak reference can become `nil`. Without `weak`, the editor and the saver would own each other and "Editor freed" would never print.
````

## Summary

- Two objects that hold strong references to each other form a **reference cycle**. ARC never frees them, because their counts never reach zero.
- `weak var name: Type?` points at an object without owning it. ARC sets it to `nil` when the object is freed, so you read it as an optional.
- Pick the weak side by ownership: the reference that points **back up** to the owner is weak. Strong down, weak up.
- Delegates are weak. The protocol needs `: AnyObject` so a property of its type can be weak.
- A new object whose only reference is weak is freed immediately; the compiler warns you.
