---
id: m13-l04
title: Closures and capturing self
description: You find the closure cycles that hide across two objects, break them with [weak self] and guard let self, use [unowned self] only where a closure can't outlive its object, recognize the many closures that don't need a capture list at all, and capture other objects or plain values instead of self.
module: m13
order: 4
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l03]
objectives:
  - Trace a closure cycle through an object, a closure it stores (directly or through something it owns) and the self that closure captures.
  - Break it with [weak self] and write the body with guard let self.
  - Decide when [unowned self] is safe.
  - Recognize closures that don't need a capture list, and say why.
  - Use capture lists for other objects and for plain values so a closure doesn't capture self at all.
terms:
  - term: Closure cycle
    definition: "A reference cycle in which one of the strong references is a closure's capture: an object owns a closure (directly or through another object it owns), and the closure captures the object."
  - term: "[weak self]"
    definition: "A capture list entry that captures self as a weak, optional reference. Inside the closure, self is nil once the object has been freed."
  - term: "guard let self"
    definition: "Unwraps a weakly captured self at the top of a closure. After it, the body can use self strongly, and since Swift 5.8 (SE-0365) can call methods and properties without writing self. explicitly."
  - term: "[unowned self]"
    definition: "A capture list entry that captures self without owning it and without making it optional. Calling the closure after the object is freed traps."
  - term: Lifetime extension
    definition: "When a closure that strongly captures an object keeps it alive longer than the code around it expects, without forming a cycle. The object is freed when the closure itself is released."
mastery:
  - Point at the three links of a closure cycle in a piece of code.
  - Rewrite a stored closure with [weak self] and guard let self, and show with deinit that the object is freed.
  - Explain why a closure passed to map, forEach or another non-escaping parameter never needs [weak self].
  - Capture a value or a different object in a capture list so the closure doesn't capture self.
  - Predict what a [weak self] closure does when called after its object is gone.
resources: [swift-book-closures, swift-book-arc]
cards:
  - id: m13-l04-c1
    front: What three links make a closure cycle?
    back: "An object owns a closure (directly or through something it owns), the closure captures the object strongly, and nothing breaks either link."
  - id: m13-l04-c2
    front: "What does guard let self do inside a [weak self] closure?"
    back: "If the object is gone, it returns early. Otherwise it gives the body a strong self for the rest of that call, and since Swift 5.8 lets you omit self. on members."
  - id: m13-l04-c3
    front: "When is [unowned self] safe?"
    back: "When the closure can't be called after the object is freed, typically because only the object itself stores it and never hands it out. Otherwise use [weak self]."
  - id: m13-l04-c4
    front: "Do closures passed to map or forEach need [weak self]?"
    back: "No. They're non-escaping: they run during the call and are released before it returns, so they can't form a cycle."
  - id: m13-l04-c5
    front: How can a closure avoid capturing self at all?
    back: "Capture only what it needs: { [title = self.title] in … } copies the value, and { [service] in … } captures another object. Then self isn't part of the closure."
---

## The idea in one sentence

A closure that an object keeps and that uses `self` makes the object own itself through the closure, and `[weak self]` turns that loop back into a line.

## Closure cycles across two objects

Module 11 showed the simplest case: a `Scoreboard` stores a closure in its own property, and the closure uses `self`. In real code the loop usually goes through a second object. A screen's view model owns a search service, and the view model gives the service a closure to call with results:

```swift
final class SearchService {
    var onResults: (([String]) -> Void)?

    func search(_ text: String) {
        onResults?(["\(text) tutorial", "\(text) reference"])
    }
}

final class SearchViewModel {
    let service = SearchService()
    var results: [String] = []

    init() {
        service.onResults = { found in
            self.results = found
            print("Got \(found.count) results")
        }
    }

    deinit {
        print("SearchViewModel freed")
    }
}

var viewModel: SearchViewModel? = SearchViewModel()
viewModel?.service.search("swift")
viewModel = nil
print("Screen closed")
```

```output
Got 2 results
Screen closed
```

The view model never stores a closure in its own properties, yet it leaks. Follow the arrows:

1. `SearchViewModel` → `service` (strong stored property).
2. `SearchService` → `onResults` (strong stored property, the closure).
3. The closure → `self`, the view model (strong capture).

Three strong links in a loop. To find a closure cycle, start at the closure and ask: **who stores it, and does anything on that chain own the thing it captures?**

## [weak self] and guard let self

The fix is to make link 3 weak:

```swift
final class SearchService {
    var onResults: (([String]) -> Void)?

    func search(_ text: String) {
        onResults?(["\(text) tutorial", "\(text) reference"])
    }
}

final class SearchViewModel {
    let service = SearchService()
    var results: [String] = []

    init() {
        service.onResults = { [weak self] found in
            guard let self else { return }
            results = found
            print("Got \(results.count) results")
        }
    }

    deinit {
        print("SearchViewModel freed")
    }
}

var viewModel: SearchViewModel? = SearchViewModel()
viewModel?.service.search("swift")
viewModel = nil
print("Screen closed")
```

```output
Got 2 results
SearchViewModel freed
Screen closed
```

Line by line, inside the closure:

1. `[weak self]` captures a weak reference to the view model. Inside the closure, `self` has type `SearchViewModel?`.
2. `guard let self else { return }` checks it once. If the view model is gone, the closure does nothing. If it's alive, `self` is a strong, non-optional reference **for the rest of this call**, so the object can't vanish halfway through the body. When the call ends, that strong reference goes away too.
3. `results = found` uses `results` without `self.`. That's allowed after `guard let self` since Swift 5.8 (SE-0365). Before that you had to write `guard let self = self` and keep writing `self.` everywhere; you'll still see that style in older code.

You can also skip the `guard` and use optional chaining, `self?.results = found`. That's fine for one line. With several lines, each `self?.` is a separate check, and if the object is freed between them, the first lines run and the later ones don't. `guard let self` makes it all-or-nothing.

### What happens when the closure runs late

A closure can outlive its object if someone else holds on to it. With `[weak self]`, that's harmless:

```swift
final class Uploader {
    var uploaded = 0
    var onChunk: (() -> Void)?

    init() {
        onChunk = { [weak self] in
            guard let self else {
                print("Uploader is gone, ignoring chunk")
                return
            }
            uploaded += 1
            print("Chunks uploaded: \(uploaded)")
        }
    }

    deinit {
        print("Uploader freed")
    }
}

var uploader: Uploader? = Uploader()
let handler = uploader?.onChunk
handler?()
uploader = nil
handler?()
```

```output
Chunks uploaded: 1
Uploader freed
Uploader is gone, ignoring chunk
```

`handler` keeps the closure alive, but the closure doesn't keep the uploader alive. After `uploader = nil`, the next call finds `self` is `nil` and takes the `else` branch.

## [unowned self]

`[unowned self]` captures `self` without owning it and without making it optional. It reads cleaner, and it's correct when the closure **can't be called after the object is gone**. The usual safe case is a closure that only the object itself stores and never hands out:

```swift
final class PriceTag {
    let amount: Int
    let currency: String

    lazy var formatted: () -> String = { [unowned self] in
        "\(amount) \(currency)"
    }

    init(amount: Int, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    deinit {
        print("PriceTag freed")
    }
}

var tag: PriceTag? = PriceTag(amount: 30, currency: "USD")
print(tag?.formatted() ?? "")
tag = nil
```

```output
30 USD
PriceTag freed
```

A `lazy var` closure is created the first time it's read, after `init` has finished, which is why it can mention `self` at all. Without a capture list it would capture `self` strongly and the tag would never be freed. Here `formatted` is only ever called through the tag itself, so whenever it runs, the tag is alive.

The moment a closure like that is handed out (stored by another object, passed as a callback, saved in a variable that outlives the object), the guarantee is gone. Calling it after the object is freed traps with the same message as in the last lesson:

```swift runtime-error Attempted to read an unowned reference but object
final class Uploader {
    var uploaded = 0
    var onChunk: (() -> Void)?

    init() {
        onChunk = { [unowned self] in
            uploaded += 1
            print("Chunks uploaded: \(uploaded)")
        }
    }

    deinit {
        print("Uploader freed")
    }
}

var uploader: Uploader? = Uploader()
let handler = uploader?.onChunk
handler?()
uploader = nil
handler?()
```

```output
Chunks uploaded: 1
Uploader freed
```

If you can't say who calls the closure and prove the object is alive at that moment, use `[weak self]`.

## When you don't need a capture list

A cycle needs the closure to be **stored** by something the captured object owns. Plenty of closures never are.

**Non-escaping closures.** A closure passed to a non-escaping parameter, like the ones `map`, `filter`, `forEach` and `sorted(by:)` take, runs during the call and is released before the call returns. Swift even lets you use properties without `self.` there, because there's nothing to warn about:

```swift
final class Classroom {
    let teacher = "Ms. Park"
    let students = ["Ali", "Bea"]

    func rollCall() {
        students.forEach { student in
            print("\(teacher): \(student)?")
        }
    }

    deinit {
        print("Classroom freed")
    }
}

var room: Classroom? = Classroom()
room?.rollCall()
room = nil
```

```output
Ms. Park: Ali?
Ms. Park: Bea?
Classroom freed
```

**Escaping closures that aren't stored by anything self owns.** An escaping closure that captures `self` strongly doesn't form a cycle if the object holding the closure isn't owned by `self` and lets go of the closure once it's done. The strong capture only **extends** the object's life until the closure is released:

```swift
final class Loader {
    private var pending: (() -> Void)?

    func load(then completion: @escaping () -> Void) {
        pending = completion
    }

    func finish() {
        pending?()
        pending = nil
    }
}

final class ProfileScreen {
    var name = "?"

    func appear(using loader: Loader) {
        loader.load {
            self.name = "Ana"
            print("Profile shows \(self.name)")
        }
    }

    deinit {
        print("ProfileScreen freed")
    }
}

let loader = Loader()
var screen: ProfileScreen? = ProfileScreen()
screen?.appear(using: loader)
screen = nil
print("Screen dismissed")
loader.finish()
print("Load finished")
```

```output
Screen dismissed
Profile shows Ana
ProfileScreen freed
Load finished
```

There's no cycle: the screen doesn't own the loader. But look at the order. The screen was dismissed and still did work afterwards, because the pending closure kept it alive until `finish()` ran and released it. Sometimes that's what you want (finish saving a draft before going away). For UI that updates a screen nobody can see, it's wasted work at best. If the work only matters while the screen exists, `[weak self]` expresses that.

So "do I need `[weak self]`?" has two questions behind it:

1. **Would a strong capture form a cycle?** Does `self`, directly or through what it owns, store this closure? If yes, you need `weak` or `unowned`.
2. **If not, should this closure keep `self` alive until it runs?** If not, use `weak` anyway.

## Capturing other things instead of self

A capture list can hold anything, not only `self`. Two uses come up constantly.

**Capture just the values you need.** If the closure only needs data, copy the data. Then `self` isn't captured at all:

```swift
final class ReceiptPrinter {
    let storeName = "Corner Shop"
    var onPrint: ((Int) -> Void)?

    init() {
        onPrint = { [storeName] total in
            print("\(storeName): \(total) USD")
        }
    }

    deinit {
        print("ReceiptPrinter freed")
    }
}

var printer: ReceiptPrinter? = ReceiptPrinter()
printer?.onPrint?(25)
printer = nil
```

```output
Corner Shop: 25 USD
ReceiptPrinter freed
```

`[storeName]` evaluates `self.storeName` once, when the closure is created, and keeps the copy (Module 11). You can also rename: `[name = self.storeName]`. The trade-off is that the copy won't see later changes to the property. For a `let`, that's no trade-off at all.

**Capture another object directly.** If the closure needs a collaborator, capture that object rather than reaching it through `self`:

```swift
final class Logger {
    func log(_ message: String) {
        print("LOG \(message)")
    }
}

final class Button {
    var onTap: (() -> Void)?
}

final class CheckoutScreen {
    let logger = Logger()
    let payButton = Button()

    init() {
        payButton.onTap = { [logger] in
            logger.log("Pay tapped")
        }
    }

    deinit {
        print("CheckoutScreen freed")
    }
}

var checkout: CheckoutScreen? = CheckoutScreen()
checkout?.payButton.onTap?()
checkout = nil
```

```output
LOG Pay tapped
CheckoutScreen freed
```

`[logger]` captures the logger strongly. That's fine, because the logger doesn't own the screen or the button. The closure no longer mentions `self`, so no cycle. You can mark other objects weak too, `[weak delegate]`, with the same rules as `self`.

## Common mistakes

> [!error] error: value of optional type 'SearchViewModel?' must be unwrapped to refer to member 'results' of wrapped base type 'SearchViewModel'
> After `[weak self]`, `self` is optional. Use `guard let self else { return }` at the top, or `self?.` on each access.

```swift no-compile must be unwrapped to refer to member 'results'
final class SearchViewModel {
    var results: [String] = []
    var onResults: (([String]) -> Void)?

    init() {
        onResults = { [weak self] found in
            self.results = found
        }
    }
}
```

> [!error] error: 'weak' may only be applied to class and class-bound protocol types, not 'Counter'
> In a struct, `self` is a value, so there's nothing to capture weakly, and no cycle to break: a struct can't own itself through a closure the way an object can. Drop the capture list.

```swift no-compile 'weak' may only be applied to class and class-bound protocol types, not 'Counter'
struct Counter {
    var count = 0

    func makeReporter() -> () -> Void {
        return { [weak self] in
            print(self?.count ?? 0)
        }
    }
}
```

> [!error] A lazy var closure that uses self with no capture list
> `lazy var describe: () -> String = { "\(self.name)" }` stores the closure in a property of `self` and captures `self` strongly. The object can never be freed. Add `[unowned self]` if the closure never leaves the object, or `[weak self]` otherwise.

> [!error] Adding [weak self] everywhere
> `scores.map { [weak self] in … }` compiles, but it's noise and forces you to unwrap for nothing. Readers learn to ignore capture lists that don't mean anything, and then miss the ones that do.

> [!error] Using [unowned self] in a callback you hand to someone else
> A network completion, a handler registered with a shared service, a callback another object keeps: any of those can be called after your object is gone, and `[unowned self]` then traps. Use `[weak self]`.

````exercise
id: m13-l04-e1
type: comprehension
prompt: Inside a class SettingsScreen, which closure needs [weak self] (or unowned) to avoid a reference cycle?
choices:
  - text: "`toggleSwitch.onChange = { self.save() }`, where `toggleSwitch` is a stored property of SettingsScreen."
    correct: true
    why: "The screen owns the switch, the switch stores the closure, the closure captures the screen. That's a cycle."
  - text: "`let names = options.map { self.label(for: $0) }`"
    correct: false
    why: "map's closure is non-escaping. It runs during the call and is gone before map returns."
  - text: "`options.forEach { option in print(option) }`"
    correct: false
    why: "It doesn't even capture self, and it's non-escaping."
  - text: "`let total = prices.reduce(0) { $0 + $1 * self.taxRate }`"
    correct: false
    why: "reduce's closure is non-escaping too. Capturing self strongly for the duration of the call is fine."
solution: |
  **The onChange closure.** It's the only one stored by something the screen owns. Trace the loop: screen → toggleSwitch → onChange → screen. The other three closures are non-escaping; they can't be stored, so they can't form a cycle, and you don't need a capture list.
````

````exercise
id: m13-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Player {
      let name: String
      var lives = 3
      var onHit: (() -> Void)?

      init(name: String) {
          self.name = name
          onHit = { [weak self] in
              guard let self else {
                  print("No player")
                  return
              }
              lives -= 1
              print("\(name) has \(lives) lives")
          }
      }

      deinit {
          print("\(name) left the game")
      }
  }

  var player: Player? = Player(name: "Zoe")
  let hit = player?.onHit
  hit?()
  hit?()
  player = nil
  hit?()
output: |
  Zoe has 2 lives
  Zoe has 1 lives
  Zoe left the game
  No player
hints:
  - "hit keeps the closure alive. Does the closure keep the player alive?"
  - "After guard let self, name and lives refer to the player's properties."
solution: |
  ```output
  Zoe has 2 lives
  Zoe has 1 lives
  Zoe left the game
  No player
  ```

  The closure captures the player weakly, so `player` is the only owner. The first two calls find the player alive and take a life each. `player = nil` frees it and `deinit` prints. The third call is still possible because `hit` holds the closure, but `self` is now `nil`, so the `else` branch prints "No player".
````

````exercise
id: m13-l04-e3
type: prediction
prompt: "No capture list this time, and no cycle either. Predict the output."
code: |
  final class Queue {
      private var jobs: [() -> Void] = []

      func add(_ job: @escaping () -> Void) {
          jobs.append(job)
      }

      func runAll() {
          for job in jobs {
              job()
          }
          jobs = []
      }
  }

  final class Report {
      let title: String

      init(title: String) {
          self.title = title
      }

      func schedule(on queue: Queue) {
          queue.add {
              print("Exporting \(self.title)")
          }
      }

      deinit {
          print("\(title) freed")
      }
  }

  let queue = Queue()
  var report: Report? = Report(title: "Q3")
  report?.schedule(on: queue)
  report = nil
  print("Report closed")
  queue.runAll()
  print("Queue empty")
output: |
  Report closed
  Exporting Q3
  Q3 freed
  Queue empty
hints:
  - "Does the report own the queue?"
  - "Who owns the report after report = nil?"
solution: |
  ```output
  Report closed
  Exporting Q3
  Q3 freed
  Queue empty
  ```

  The closure captures the report strongly, and the queue owns the closure. The report doesn't own the queue, so this isn't a cycle. It's a **lifetime extension**: after `report = nil`, the queue's job is still an owner. `runAll()` runs the job, then `jobs = []` releases it, and with it the last reference to the report. If exporting a closed report is wrong for your app, capture `[weak self]` and skip the work when `self` is `nil`.
````

````exercise
id: m13-l04-e4
type: find-errors
prompt: "A timer-like ticker owned by a screen. Which statements are true?"
code: |
  final class Ticker {
      var onTick: (() -> Void)?

      func tick() {
          onTick?()
      }
  }

  final class StopwatchScreen {
      let ticker = Ticker()
      var seconds = 0
      let laps = [12, 15, 11]

      func start() {
          ticker.onTick = {
              self.seconds += 1
              self.render()
          }
      }

      func render() {
          let text = laps.map { lap in "\(lap)s" }
          print(seconds, text)
      }
  }
choices:
  - text: "onTick forms a cycle: screen → ticker → closure → screen."
    correct: true
    why: "The screen owns the ticker and the ticker stores the closure that captures the screen strongly."
  - text: "The map closure in render() also needs [weak self]."
    correct: false
    why: "map's closure is non-escaping and doesn't even use self. No capture list needed."
  - text: "[unowned self] would be safe for onTick as long as nobody else ever copies or calls ticker.onTick."
    correct: true
    why: "The ticker is owned by the screen, so if only the screen's own ticker calls the closure, the screen is alive whenever it runs. [weak self] is still the safer default."
  - text: "Writing self. explicitly already prevents the cycle."
    correct: false
    why: "Explicit self only makes the capture visible. It's still a strong capture."
rubric:
  - I identified the cycle through ticker.
  - I fixed it with [weak self] and guard let self.
  - I left render() alone.
  - I showed with deinit that the screen is freed.
solution: |
  ```swift
  final class Ticker {
      var onTick: (() -> Void)?

      func tick() {
          onTick?()
      }
  }

  final class StopwatchScreen {
      let ticker = Ticker()
      var seconds = 0
      let laps = [12, 15, 11]

      func start() {
          ticker.onTick = { [weak self] in
              guard let self else { return }
              seconds += 1
              render()
          }
      }

      func render() {
          let text = laps.map { lap in "\(lap)s" }
          print(seconds, text)
      }

      deinit {
          print("Stopwatch freed")
      }
  }

  var stopwatch: StopwatchScreen? = StopwatchScreen()
  stopwatch?.start()
  stopwatch?.ticker.tick()
  stopwatch = nil
  ```

  ```output
  1 ["12s", "15s", "11s"]
  Stopwatch freed
  ```

  Only `onTick` needed changing. The closure in `render()` is non-escaping, so it can use `laps` without `self.` and without a capture list.
````

````exercise
id: m13-l04-e5
type: solve
prompt: |
  This chat screen leaks: "ChatScreen freed" never prints. Fix it **without** using `[weak self]`: the closure only needs the room name and the sound player, so capture those instead. The program must print exactly:

  ```output
  [general] new message (ding)
  ChatScreen freed
  ```
starter: |
  final class SoundPlayer {
      func play() -> String {
          "(ding)"
      }
  }

  final class MessageStream {
      var onMessage: (() -> Void)?
  }

  final class ChatScreen {
      let roomName = "general"
      let sounds = SoundPlayer()
      let stream = MessageStream()

      init() {
          stream.onMessage = {
              print("[\(self.roomName)] new message \(self.sounds.play())")
          }
      }

      deinit {
          print("ChatScreen freed")
      }
  }

  var chat: ChatScreen? = ChatScreen()
  chat?.stream.onMessage?()
  chat = nil
hints:
  - "A capture list can name properties: [roomName, sounds]."
  - "Inside the closure, use the captured names without self."
rubric:
  - The capture list holds roomName and sounds, not self.
  - The closure body doesn't mention self.
  - I explained why capturing sounds strongly doesn't form a cycle.
  - The output matches exactly.
solution: |
  ```swift
  final class SoundPlayer {
      func play() -> String {
          "(ding)"
      }
  }

  final class MessageStream {
      var onMessage: (() -> Void)?
  }

  final class ChatScreen {
      let roomName = "general"
      let sounds = SoundPlayer()
      let stream = MessageStream()

      init() {
          stream.onMessage = { [roomName, sounds] in
              print("[\(roomName)] new message \(sounds.play())")
          }
      }

      deinit {
          print("ChatScreen freed")
      }
  }

  var chat: ChatScreen? = ChatScreen()
  chat?.stream.onMessage?()
  chat = nil
  ```

  ```output
  [general] new message (ding)
  ChatScreen freed
  ```

  `[roomName, sounds]` evaluates both properties once, when the closure is created. `roomName` is a copied `String`; `sounds` is a strong reference to the sound player. Neither one owns the screen, so the loop is gone: screen → stream → closure → sound player, and the player points at nothing. Both are `let`, so capturing their current values loses nothing.
````

````exercise
id: m13-l04-e6
type: refactor
prompt: Rewrite the closure so it checks self once with guard let self and uses implicit self. Behavior must not change, and the profile must still be freed.
code: |
  final class ProfileViewModel {
      var name = ""
      var bio = ""
      var onLoad: ((String, String) -> Void)?

      init() {
          onLoad = { [weak self] newName, newBio in
              self?.name = newName
              self?.bio = newBio
              print("\(self?.name ?? ""): \(self?.bio ?? "")")
          }
      }
  }
rubric:
  - The closure still captures [weak self].
  - The first line is guard let self else { return }.
  - The body uses name and bio without self? or self.
  - I explained the all-or-nothing difference from optional chaining.
solution: |
  ```swift
  final class ProfileViewModel {
      var name = ""
      var bio = ""
      var onLoad: ((String, String) -> Void)?

      init() {
          onLoad = { [weak self] newName, newBio in
              guard let self else { return }
              name = newName
              bio = newBio
              print("\(name): \(bio)")
          }
      }

      deinit {
          print("ProfileViewModel freed")
      }
  }

  var profile: ProfileViewModel? = ProfileViewModel()
  profile?.onLoad?("Ana", "iOS developer")
  profile = nil
  ```

  ```output
  Ana: iOS developer
  ProfileViewModel freed
  ```

  Shorter, and the `?? ""` defaults disappear because `self` is non-optional after the `guard`. It also changes one subtle thing for the better: with three separate `self?.` accesses, the object could in principle go away between them and leave a half-applied update. After `guard let self`, the body holds a strong reference for the whole call, so either everything runs or nothing does.
````

## Summary

- A closure cycle: an object owns a closure (directly or through something it owns), and the closure captures the object strongly. Trace it from the closure: who stores it, and does that chain lead back to what it captures?
- `[weak self]` breaks the cycle. Start the body with `guard let self else { return }`; since Swift 5.8 you can then drop `self.`.
- `[unowned self]` only when the closure can't run after the object is gone, such as a `lazy var` closure that never leaves the object. Otherwise it traps.
- Non-escaping closures (`map`, `forEach`, `sorted`) never need a capture list.
- An escaping closure stored elsewhere may not form a cycle, but a strong capture still extends the object's life until the closure is released.
- Capture values (`[title]`) or other objects (`[logger]`) instead of `self` when that's all the closure needs.
