---
id: m13-l01
title: How ARC works
description: You learn what it means for a reference to own an object, follow an instance from init to deinit, see how arrays, properties and function parameters add owners, learn that an object lives until its last use rather than to the end of its scope, and see where value types fit into reference counting.
module: m13
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l06]
objectives:
  - Explain ownership and strong references in your own words.
  - Describe what ARC does at compile time and what happens at run time.
  - Trace an object's life cycle from allocation to deinit, including owners added by arrays and stored properties.
  - Explain why Swift promises an object lives until its last use, not until the closing brace.
  - Say when value types take part in reference counting and when they don't.
terms:
  - term: Ownership
    definition: "Keeping an object alive. A reference that owns an object counts toward its reference count; while at least one owner exists, the object stays in memory."
  - term: Strong reference
    definition: "The default kind of reference in Swift. A variable, constant, property, array element or captured value that holds a class instance strongly is one of its owners."
  - term: Automatic Reference Counting (ARC)
    definition: "Swift's memory management for class instances. The compiler inserts retain and release operations into your code; at run time they keep a count of strong references per object, and the object is destroyed when the count reaches zero."
  - term: Retain and release
    definition: "The two operations ARC inserts. A retain adds one to an object's strong reference count; a release subtracts one. You never write them yourself in Swift."
  - term: Object life cycle
    definition: "The stages an instance goes through: memory is allocated, init runs, the object is used while it has owners, deinit runs when the last owner lets go, and the memory is returned."
  - term: Last use
    definition: "The last point in the code where an object is read. Swift guarantees the object is alive up to there, not necessarily until the end of the enclosing scope."
mastery:
  - Predict the line on which deinit prints when an object is held by a variable, an array and a stored property.
  - Explain why setting one of two variables to nil doesn't free a shared instance.
  - Say whether copying a struct copies the class instance it holds, and prove it with ===.
  - Explain the difference between ARC and a tracing garbage collector in two sentences.
  - Rewrite code that depends on deinit running at the closing brace so it calls an explicit method instead.
resources: [swift-book-arc, swift-book-structures-classes, swift-book-initialization]
cards:
  - id: m13-l01-c1
    front: What does ARC count?
    back: "Strong references to each class instance. When the count drops to zero, deinit runs and the memory is freed."
  - id: m13-l01-c2
    front: Who inserts retain and release in a Swift program?
    back: "The compiler, at compile time. The counting itself happens at run time. There's no background collector scanning memory."
  - id: m13-l01-c3
    front: How long is an object guaranteed to live inside a function?
    back: "Until its last use. Swift doesn't promise it survives to the closing brace; an optimized build may free it earlier. Use withExtendedLifetime if you truly need it alive longer."
  - id: m13-l01-c4
    front: Does copying a struct that holds a class instance copy the instance?
    back: "No. The struct is copied, but its property is a reference, so both copies point at the same instance and both count as owners."
---

## The idea in one sentence

Every class instance has **owners**, and when the last owner lets go, Swift destroys it on the spot.

## Ownership and strong references

You met this in Module 10: a variable that holds a class instance holds a **reference** to it, and Swift counts those references. This module turns that one paragraph into a working model you can use to reason about any object graph.

**Plain definition:** a reference **owns** an object when it keeps the object alive. As long as an object has at least one owner, it stays in memory.

**Precise definition:** a **strong reference** is the default kind of reference in Swift. Every strong reference to an instance adds one to its **strong reference count**. **ARC**, Automatic Reference Counting, destroys the instance when that count reaches zero.

Owners aren't only variables. Each of these is a strong reference:

- a `let` or `var` holding the instance,
- a stored property of another object or struct,
- an element of an array, a dictionary value, a set member,
- a closure that captured the instance (Module 11, and lesson 4 of this module).

### What "automatic" means

ARC isn't a separate program running alongside yours. When the **compiler** builds your code, it inserts two kinds of operations wherever a reference is created or goes away: a **retain** (count up) and a **release** (count down). At **run time** those operations update the count, and the release that brings it to zero triggers `deinit` and frees the memory.

That makes ARC different from the **tracing garbage collector** in Java, C# or JavaScript, which periodically walks memory looking for objects nothing can reach. Two practical consequences:

1. Objects are freed as soon as they lose their last owner, not at some later collection. `deinit` runs at a predictable point.
2. ARC never looks at the object graph as a whole. If two objects own each other, each count stays at one forever, even when nothing else can reach them. That's the **reference cycle**, the subject of the next lesson.

> [!note] Don't print retain counts
> You may find code online that prints an object's retain count with `CFGetRetainCount`. Don't use it to learn or debug ARC. The compiler and optimizer add and remove retains as they see fit, so the number doesn't match the owners you can see in your code. Reason about owners, and use `deinit` and weak references (next lesson) to observe what actually happens.

## The life cycle of an object

An instance goes through five stages:

1. **Allocation.** Swift reserves memory for the instance on the heap.
2. **Initialization.** `init` runs and gives every stored property a value.
3. **In use.** The instance has one or more owners and the program works with it.
4. **Deinitialization.** The last owner lets go, the count hits zero, and `deinit` runs.
5. **Deallocation.** The memory is returned. Any objects this instance owned lose an owner.

`init` and `deinit` prints make stages 2 and 4 visible:

```swift
final class Ticket {
    let number: Int

    init(number: Int) {
        self.number = number
        print("Ticket \(number) created")
    }

    deinit {
        print("Ticket \(number) destroyed")
    }
}

func serveCustomer() {
    let ticket = Ticket(number: 7)
    print("Serving ticket \(ticket.number)")
}

print("Start")
serveCustomer()
print("End")
```

```output
Start
Ticket 7 created
Serving ticket 7
Ticket 7 destroyed
End
```

Line by line:

1. `print("Start")` runs first; nothing has been allocated yet.
2. `serveCustomer()` creates a `Ticket`. `init` prints. The local constant `ticket` is its only owner.
3. The ticket is used in the `print`.
4. The function returns. `ticket` was the only owner, so the count drops to zero and `deinit` prints **before** control comes back to the caller.
5. `print("End")` runs with the ticket already gone.

### More owners, longer life

An object lives as long as its **longest-lived** owner. Here an array and a stored property join in:

```swift
final class Ticket {
    let number: Int

    init(number: Int) {
        self.number = number
    }

    deinit {
        print("Ticket \(number) destroyed")
    }
}

final class Counter {
    var current: Ticket?
}

var waiting: [Ticket] = []
let counter = Counter()

var ticket: Ticket? = Ticket(number: 1)
waiting.append(ticket!)
counter.current = ticket
print("Three owners")

ticket = nil
print("Variable cleared")
waiting.removeAll()
print("Queue cleared")
counter.current = nil
print("Counter cleared")
```

```output
Three owners
Variable cleared
Queue cleared
Ticket 1 destroyed
Counter cleared
```

After `counter.current = ticket` the instance has three owners: the variable, the array element and the property. Clearing the variable and emptying the array each remove one; nothing prints. Only `counter.current = nil` removes the last one, and `deinit` runs right there.

The `!` in `waiting.append(ticket!)` is safe here because `ticket` was assigned on the line above. In real code you'd append the instance before storing it in an optional.

## Alive until the last use

Module 10 told you not to rely on `deinit` running on a particular line. Here's the precise rule.

Swift guarantees that an instance is alive **until its last use**. It doesn't guarantee that a local constant keeps it alive until the closing brace of the scope. In a debug build, which is what the examples in this course run as, objects usually do live to the end of the scope. With optimizations on (a Release build in Xcode), the compiler is allowed to release an object right after the last line that reads it.

For almost all code this makes no difference. It matters when an object's **existence** has a side effect you depend on, for example an object whose `deinit` stops a recording or removes an observer, and you create it and never read it again. If you need an object alive until a specific point, say so in code:

```swift
final class RecordingSession {
    deinit {
        print("Recording stopped")
    }
}

func recordClip() {
    let session = RecordingSession()
    withExtendedLifetime(session) {
        print("Capturing frames")
        print("Clip saved")
    }
}

recordClip()
print("Back in the caller")
```

```output
Capturing frames
Clip saved
Recording stopped
Back in the caller
```

`withExtendedLifetime(_:_:)` is a standard library function that guarantees its first argument stays alive **at least** until the closure finishes. Nothing inside the closure reads `session`, but the recording can't stop in the middle of it, whatever the optimizer does. After the closure the ordinary rules apply again: here the session goes when the function returns. A debug build would print the same thing without `withExtendedLifetime`; the difference is that the guarantee no longer depends on build settings.

The better fix, usually, is not to tie behavior to `deinit` at all. Give the type an explicit `stop()` method and call it. Lesson 6 comes back to that.

## Value types and memory

Structs, enums and tuples are **value types**. Assigning one copies it, so there's no shared instance to count, and a value type has no strong reference count of its own. That's also why a regular struct can't have a `deinit`.

That doesn't mean value types live outside ARC. If a struct **contains** a class reference, copying the struct copies the reference, and each copy is an owner:

```swift
final class Photo {
    let name: String

    init(name: String) {
        self.name = name
    }

    deinit {
        print("Photo \(name) freed")
    }
}

struct Album {
    var cover: Photo
}

var first: Album? = Album(cover: Photo(name: "beach"))
var second = first
print(first?.cover === second?.cover)
first = nil
print("first is nil")
second = nil
print("second is nil")
```

```output
true
first is nil
Photo beach freed
second is nil
```

1. `second = first` copies the `Album`. The copy's `cover` is the same reference, which `===` confirms with `true`. The photo now has two owners.
2. `first = nil` destroys the first album value, which releases one reference to the photo. The photo survives.
3. `second = nil` releases the last one, and the photo is freed.

The standard library's collections work the same way under the hood. An `Array` or a `String` keeps its contents in a heap buffer that is reference counted. That's how the copy-on-write you saw in Module 7 works: copies share the buffer until one of them changes. You never see that buffer's count, but it explains why copying a big array is cheap.

The practical rule: a struct made only of numbers, `Bool`s and other plain values costs ARC nothing. A struct full of class references makes ARC traffic every time you copy it, and it extends the life of every object it holds.

## A practical example: a download queue

A download manager owns its active downloads. A finished download is removed from the queue, and if no one else holds it, it's freed immediately.

```swift
final class Download {
    let fileName: String

    init(fileName: String) {
        self.fileName = fileName
        print("Queued \(fileName)")
    }

    deinit {
        print("Released \(fileName)")
    }
}

final class DownloadManager {
    private var active: [Download] = []
    var lastFinished: Download?

    func start(_ fileName: String) {
        active.append(Download(fileName: fileName))
    }

    func finishFirst() {
        guard !active.isEmpty else { return }
        let done = active.removeFirst()
        print("Finished \(done.fileName)")
        lastFinished = done
    }
}

let manager = DownloadManager()
manager.start("song.mp3")
manager.start("photo.jpg")
manager.finishFirst()
manager.finishFirst()
print("Both finished")
```

```output
Queued song.mp3
Queued photo.jpg
Finished song.mp3
Finished photo.jpg
Released song.mp3
Both finished
```

`finishFirst()` moves a download from the array to `lastFinished`. The first time, `song.mp3` becomes the last finished one. The second time, the method prints "Finished photo.jpg" and then `lastFinished = done` replaces the song with the photo. That assignment releases `song.mp3`'s last owner, so it's freed right there, after the print. `photo.jpg` is still owned by `lastFinished` when the program reaches its last line.

Notice that "Released photo.jpg" never prints. `manager` is a global constant in `main.swift`, and the program ends without tearing down globals. That's normal: when a process exits, the operating system reclaims all its memory at once, and `deinit` doesn't run for objects still alive at that point.

## Common mistakes

> [!error] Expecting deinit when only one owner lets go
> Setting one variable to `nil` removes one owner. If the instance is also in an array, a property or another variable, it stays alive. Before expecting `deinit`, list every owner.

> [!error] error: deinitializer cannot be declared in struct 'Ticket' that conforms to 'Copyable'
> Swift 6.3 rejects `deinit` in an ordinary struct. Copies of a value have no single moment of death to mark. If you need cleanup when something goes away, you either want a class or, for advanced cases, a noncopyable struct (lesson 6).

```swift no-compile deinitializer cannot be declared in struct 'Ticket' that conforms to 'Copyable'
struct Ticket {
    deinit {
        print("gone")
    }
}
```

> [!error] error: 'nil' cannot be assigned to type 'Ticket'
> Only an optional can be set to `nil`. To drop a reference explicitly, the variable must be `Ticket?`. For local constants you usually don't need to: the reference goes away when it's no longer used.

```swift no-compile 'nil' cannot be assigned to type 'Ticket'
final class Ticket {}
var ticket = Ticket()
ticket = nil
```

> [!error] Thinking ARC is a garbage collector
> ARC never scans memory. It can't notice that two objects only own each other. Cycles are your job, which is why the next three lessons exist.

> [!error] Relying on deinit at the closing brace
> In an optimized build an object can be freed right after its last use. If a side effect must happen at a specific point, call a method that does it, or use `withExtendedLifetime`.

````exercise
id: m13-l01-e1
type: comprehension
prompt: Which statement about ARC is correct?
choices:
  - text: "The compiler inserts retain and release operations; at run time they keep a count per object, and the object is freed when the count reaches zero."
    correct: true
    why: "That's the whole mechanism: compile-time insertion, run-time counting."
  - text: "A background thread periodically scans memory and frees objects that nothing can reach."
    correct: false
    why: That describes a tracing garbage collector. ARC never scans memory, which is exactly why it can't clean up cycles.
  - text: "ARC counts references to structs and classes alike."
    correct: false
    why: "A value type has no reference count of its own. Only class instances (and heap buffers inside types like Array) are counted."
  - text: "You call retain and release yourself when you need fine control."
    correct: false
    why: "In Swift you never write them. That was manual memory management in older Objective-C code."
solution: |
  **The first option.** ARC is automatic because the compiler writes the bookkeeping for you, and it's reference *counting* because the decision to free an object comes from a count reaching zero, not from a scan of memory. That second part is why a cycle (two objects owning each other) is never freed: neither count reaches zero.
````

````exercise
id: m13-l01-e2
type: prediction
prompt: Predict the exact output. Count the owners of each lamp after every line.
code: |
  final class Lamp {
      let room: String

      init(room: String) {
          self.room = room
      }

      deinit {
          print("\(room) lamp off")
      }
  }

  var lamps: [Lamp] = [Lamp(room: "Hall"), Lamp(room: "Desk")]
  var favorite: Lamp? = lamps[1]
  print("A")
  lamps.removeAll()
  print("B")
  favorite = nil
  print("C")
output: |
  A
  Hall lamp off
  B
  Desk lamp off
  C
hints:
  - "The array owns both lamps. favorite is a second owner of one of them."
  - "lamps[1] is the second element."
solution: |
  ```output
  A
  Hall lamp off
  B
  Desk lamp off
  C
  ```

  | After | Hall owners | Desk owners |
  | --- | --- | --- |
  | `var lamps = [...]` | array | array |
  | `var favorite = lamps[1]` | array | array, favorite |
  | `lamps.removeAll()` | none: freed | favorite |
  | `favorite = nil` | | none: freed |

  `removeAll()` releases both elements, but only the hall lamp loses its last owner. The desk lamp survives until `favorite` lets go.
````

````exercise
id: m13-l01-e3
type: prediction
prompt: "`Badge` is a class and `Employee` is a struct that holds one. Predict the output."
code: |
  final class Badge {
      let code: Int

      init(code: Int) {
          self.code = code
      }

      deinit {
          print("Badge \(code) revoked")
      }
  }

  struct Employee {
      var name: String
      var badge: Badge
  }

  var original: Employee? = Employee(name: "Ana", badge: Badge(code: 42))
  var copy = original
  copy?.name = "Ana M."
  print(original?.name ?? "-", copy?.name ?? "-")
  print(original?.badge === copy?.badge)
  original = nil
  print("original gone")
  copy = nil
  print("copy gone")
output: |
  Ana Ana M.
  true
  original gone
  Badge 42 revoked
  copy gone
hints:
  - "Copying the struct copies name (a value) and badge (a reference)."
  - "How many owners does the badge have after var copy = original?"
solution: |
  ```output
  Ana Ana M.
  true
  original gone
  Badge 42 revoked
  copy gone
  ```

  `var copy = original` copies the struct. `name` is a value, so changing the copy's name leaves the original alone. `badge` is a reference, so both copies point at the same `Badge` (`===` is `true`) and both own it. Destroying the first struct removes one owner; the badge is revoked only when the second goes too.
````

````exercise
id: m13-l01-e4
type: fill-in
prompt: |
  Complete the program so it prints exactly:

  ```output
  Socket open
  Sending
  Socket closed
  Done
  ```
code: |
  final class Socket {
      [[1]]() {
          print("Socket open")
      }

      [[2]] {
          print("Socket closed")
      }
  }

  func send() {
      let socket = Socket()
      print("Sending")
      [[3]](socket) {
      }
  }

  send()
  print("Done")
blanks:
  - id: "1"
    answers: ["init"]
  - id: "2"
    answers: ["deinit"]
  - id: "3"
    answers: ["withExtendedLifetime"]
solution: |
  ```swift
  final class Socket {
      init() {
          print("Socket open")
      }

      deinit {
          print("Socket closed")
      }
  }

  func send() {
      let socket = Socket()
      print("Sending")
      withExtendedLifetime(socket) {
      }
  }

  send()
  print("Done")
  ```

  ```output
  Socket open
  Sending
  Socket closed
  Done
  ```

  `init` runs when the socket is created and `deinit` when its last owner, the local constant, goes away. `withExtendedLifetime` guarantees the socket is alive until the closure finishes, which here is the end of the function, so "Socket closed" comes before "Done" in any build.
````

````exercise
id: m13-l01-e5
type: solve
prompt: |
  Write a class `Session` with a `user` property whose `init` prints `"<user> logged in"` and whose `deinit` prints `"<user> logged out"`. Then write a class `App` with a `var current: Session?` property and a method `switchUser(to name: String)` that replaces the current session with a new one.

  Running this:

  ```swift illustrative
  let app = App()
  app.switchUser(to: "ana")
  app.switchUser(to: "ben")
  app.current = nil
  print("No one logged in")
  ```

  must print:

  ```output
  ana logged in
  ben logged in
  ana logged out
  ben logged out
  No one logged in
  ```
starter: |
  final class Session {
      // user, init, deinit
  }

  final class App {
      var current: Session?

      func switchUser(to name: String) {
      }
  }
hints:
  - "The new session must exist before it replaces the old one. Which line creates it?"
  - "Assigning to current releases whatever was there before."
rubric:
  - Session's init and deinit print the exact messages.
  - switchUser creates the new session and assigns it to current in one statement.
  - I can explain why "ben logged in" prints before "ana logged out".
  - The output matches exactly.
solution: |
  ```swift
  final class Session {
      let user: String

      init(user: String) {
          self.user = user
          print("\(user) logged in")
      }

      deinit {
          print("\(user) logged out")
      }
  }

  final class App {
      var current: Session?

      func switchUser(to name: String) {
          current = Session(user: name)
      }
  }

  let app = App()
  app.switchUser(to: "ana")
  app.switchUser(to: "ben")
  app.current = nil
  print("No one logged in")
  ```

  ```output
  ana logged in
  ben logged in
  ana logged out
  ben logged out
  No one logged in
  ```

  In `current = Session(user: name)`, the right side runs first: the new session is created and its `init` prints. Only then does the assignment replace the old value, which releases ana's session, its last owner. So "ben logged in" comes before "ana logged out". `app.current = nil` releases ben's.
````

````exercise
id: m13-l01-e6
type: explain
prompt: |
  A teammate wrote this and says "it works on my machine". Explain the risk, and how you'd make the behavior not depend on the build configuration.
code: |
  final class ScreenRecorder {
      init() { print("Recording started") }
      deinit { print("Recording stopped") }
  }

  func recordTutorial() {
      let recorder = ScreenRecorder()
      runTutorialSteps()   // never touches recorder
      uploadVideo()        // expects recording to have stopped
  }
rubric:
  - I said Swift only guarantees the recorder lives until its last use, not until the closing brace.
  - I pointed out that the last use here is the initialization itself, so an optimized build may stop recording before the tutorial steps run.
  - I proposed an explicit stop() method, or withExtendedLifetime around the steps.
  - I explained that a debug build usually hides the problem.
solution: |
  The code assumes `recorder` stays alive until the end of `recordTutorial()`. Swift doesn't promise that. It promises the object lives until its **last use**, and `recorder` is never used after it's created. An optimized build can release it right away, so "Recording stopped" could happen before `runTutorialSteps()`. In a debug build the object usually lives to the closing brace, which is why it "works on my machine".

  The clearest fix is to stop relying on `deinit` for behavior: give `ScreenRecorder` a `stop()` method and call it after the steps, before `uploadVideo()`. Then the call to `stop()` is the last use and also does the work. If you must keep the `deinit` design, wrap the steps in `withExtendedLifetime(recorder) { runTutorialSteps() }`, which guarantees the object is alive until the closure ends.
````

## Summary

- An object stays alive while it has at least one **strong reference**, its owners. Variables, properties, collection elements and captured values all count.
- ARC: the compiler inserts retains and releases; at run time they maintain a count, and the instance is destroyed as soon as it reaches zero. There's no scanning collector.
- Life cycle: allocate, `init`, use, `deinit` when the last owner lets go, free.
- Swift guarantees an object lives until its **last use**. Use an explicit method or `withExtendedLifetime` when timing matters.
- Value types have no reference count, but a struct that holds class references makes each copy an owner of those objects.
- Don't print retain counts. Reason about owners, and observe with `deinit`.
