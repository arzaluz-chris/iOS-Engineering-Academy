---
id: m13-l06
title: Ownership of resources
description: You map who owns what in an app's object graph, decide between cleanup in deinit and an explicit close, tie a subscription's lifetime to the object that holds its token, handle timers and notification observers safely, meet noncopyable types, and finish by finding and fixing four leaks in a small app.
module: m13
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l05]
objectives:
  - Draw an app's object graph with strong references going down and weak references going up.
  - Decide whether a resource is released in deinit, in an explicit close method, or both.
  - Tie a subscription's lifetime to an owner with a cancellation token.
  - Explain why repeating timers and block-based notification observers need explicit cleanup.
  - Describe what a noncopyable type guarantees about ownership.
  - Find and fix several leaks in one object graph and prove the fix with leak checks.
terms:
  - term: Object graph
    definition: "The objects in a running program and the references between them. In a healthy app, strong references form a tree from long-lived roots down to short-lived screens."
  - term: Resource
    definition: "Anything that has to be released besides memory: an open file, a network connection, a subscription, a timer, an observer registration."
  - term: Explicit cleanup
    definition: "A method such as close(), cancel() or stop() that the owner calls at a known point to release a resource, instead of relying on deinit."
  - term: Cancellation token
    definition: "An object returned by a subscribe call that represents the subscription. Cancelling it, or letting it be freed, removes the subscription. Combine's AnyCancellable works this way."
  - term: Noncopyable type
    definition: "A struct or enum declared with ~Copyable (SE-0390, Swift 5.9). It can't be copied, only moved, so there's always exactly one owner, and it can have a deinit."
mastery:
  - Label each reference in a small app diagram as strong, weak or unowned and justify it.
  - Write a close() method that's safe to call twice, with deinit as a safety net.
  - Implement subscribe() returning a token whose deinit unsubscribes.
  - Explain why invalidating a target-based Timer in deinit never runs.
  - Fix a graph with several independent leaks and show every object freed.
resources: [swift-book-arc, swift-book-closures, swift-book-structures-classes, swift-book-initialization]
cards:
  - id: m13-l06-c1
    front: What's the default direction of ownership in an app's object graph?
    back: "Down. Long-lived roots own services and screens; screens own view models; view models own their children. References going back up (to parents, delegates, observers) are weak."
  - id: m13-l06-c2
    front: When should cleanup go in an explicit close() instead of deinit?
    back: "When it has effects outside memory (files, connections, subscriptions), when it can fail, or when timing matters. deinit can't throw, runs whenever the last reference goes, and never runs for a leaked object. Keep deinit as a safety net."
  - id: m13-l06-c3
    front: How does a cancellation token tie a subscription to an owner?
    back: "subscribe() returns a token object. The owner stores it. When the owner is freed, the token is freed, and the token's deinit removes the subscription."
  - id: m13-l06-c4
    front: Why can't a screen invalidate a target-based Timer in its deinit?
    back: "The timer keeps a strong reference to its target until it's invalidated, so the screen is never freed and deinit never runs. Invalidate it from an explicit stop method, or use the block API with [weak self]."
  - id: m13-l06-c5
    front: What does ~Copyable guarantee?
    back: "A value of that type can't be copied, only moved. There's exactly one owner at a time, and using it after it's been consumed is a compile error."
---

## The idea in one sentence

Every object should have one clear owner, and every resource should have a clear moment when it's released; when you can name both, leaks have nowhere to hide.

## Who owns what in an app

Put the rules from this module together and an app's object graph takes a predictable shape:

```plaintext
App (lives for the whole process)
├── owns ─► CartService ◄──────────── strong (injected) ──┐
└── owns ─► window ─► CheckoutScreen                       │
                       └── owns ─► CheckoutViewModel ──────┘
                                    └── owns ─► AddressFormViewModel
                                                 └── weak ─► delegate (CheckoutViewModel)
CartService ── closure with [weak self] ─► CheckoutViewModel
```

Read it as a set of rules:

- **Long-lived roots own services.** Something that lives for the whole app (the app object, a dependency container) creates the shared services.
- **Screens own their view models, and view models own their child view models.** When the screen goes, everything under it goes.
- **A view model may hold a service strongly.** The service was injected; it doesn't own the view model back, so there's no loop. Holding it strongly just means "I need this while I exist".
- **Anything pointing back up is weak**: child to parent, worker to delegate.
- **A long-lived object never owns a short-lived one by accident.** If a service stores a closure from a view model, that closure captures the view model weakly, and the subscription is removed when the view model goes.

Here's that graph in code, with every link labeled:

```swift
final class CartService {
    private(set) var itemCount = 0
    private var listeners: [(Int) -> Void] = []

    func onChange(_ listener: @escaping (Int) -> Void) {
        listeners.append(listener)
    }

    func add() {
        itemCount += 1
        for listener in listeners {
            listener(itemCount)
        }
    }
}

protocol AddressFormDelegate: AnyObject {
    func addressDidChange(_ address: String)
}

final class AddressFormViewModel {
    weak var delegate: AddressFormDelegate?          // up: weak

    func type(_ address: String) {
        delegate?.addressDidChange(address)
    }

    deinit {
        print("AddressFormViewModel freed")
    }
}

final class CheckoutViewModel: AddressFormDelegate {
    let cart: CartService                            // injected service: strong
    let addressForm = AddressFormViewModel()         // child: strong
    var summary = ""

    init(cart: CartService) {
        self.cart = cart
        addressForm.delegate = self
        cart.onChange { [weak self] count in         // long-lived holder: weak
            self?.summary = "\(count) in cart"
        }
    }

    func addressDidChange(_ address: String) {
        print("Ship to \(address), \(summary)")
    }

    deinit {
        print("CheckoutViewModel freed")
    }
}

let cart = CartService()
var checkout: CheckoutViewModel? = CheckoutViewModel(cart: cart)
cart.add()
checkout?.addressForm.type("12 Main St")
checkout = nil
print("Cart still has \(cart.itemCount) item")
```

```output
Ship to 12 Main St, 1 in cart
CheckoutViewModel freed
AddressFormViewModel freed
Cart still has 1 item
```

Closing checkout frees the view model and its child. The cart, owned by the top level, keeps its state for the next screen.

## deinit or an explicit close?

`deinit` looks like the natural place to release a resource: it runs exactly once, when the object goes. It has real limits, though:

- **It can't report failure.** `deinit` can't throw, and nobody is there to handle an error. Closing a file that fails to flush has nowhere to go.
- **Its timing isn't under your control.** It runs when the last reference goes, which may be later than you think (a closure still holds the object) or earlier (last use, lesson 1).
- **It never runs for a leaked object.** If cleanup lives only in `deinit`, a leak also leaks the file handle, the connection or the subscription.
- **It never runs for objects alive at process exit.** You saw this in lesson 1.

So use an **explicit cleanup method** for anything with effects outside memory, and keep `deinit` as a safety net that catches the case where someone forgot:

```swift
enum ConnectionError: Error {
    case notOpen
}

final class Connection {
    let host: String
    private var isOpen = true

    init(host: String) {
        self.host = host
        print("Connected to \(host)")
    }

    func send(_ message: String) throws {
        guard isOpen else { throw ConnectionError.notOpen }
        print("Sent \(message)")
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        print("Closed \(host)")
    }

    deinit {
        if isOpen {
            print("Warning: \(host) was never closed")
            close()
        }
    }
}

func syncNotes() {
    let connection = Connection(host: "notes.example.com")
    defer { connection.close() }
    do {
        try connection.send("hello")
    } catch {
        print("Send failed: \(error)")
    }
}

func forgetfulSync() {
    let connection = Connection(host: "backup.example.com")
    try? connection.send("ping")
}

syncNotes()
forgetfulSync()
```

```output
Connected to notes.example.com
Sent hello
Closed notes.example.com
Connected to backup.example.com
Sent ping
Warning: backup.example.com was never closed
Closed backup.example.com
```

1. `close()` is **idempotent**: calling it twice is harmless, because the `guard` returns early the second time. That makes it safe to call from both a `defer` and `deinit`.
2. `syncNotes()` uses `defer` (Module 12), so the connection is closed on every way out of the function, including a thrown error.
3. `forgetfulSync()` forgets. The safety net in `deinit` notices, logs it, and closes. In a real app the log line is how you find the bug; the safety net only limits the damage.

## Subscriptions that clean up after themselves

In the last lesson, the inbox screen captured `[weak self]` so it could be freed, but its dead handler stayed in the event center forever. The fix is to make the subscription itself an object with an owner. `subscribe` returns a **token**; whoever holds the token keeps the subscription alive, and when the token is freed, it unsubscribes:

```swift
final class Subscription {
    private var cancelAction: (() -> Void)?

    init(cancel: @escaping () -> Void) {
        cancelAction = cancel
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }

    deinit {
        cancel()
    }
}

final class EventCenter {
    private var handlers: [Int: (String) -> Void] = [:]
    private var nextID = 0

    var handlerCount: Int {
        handlers.count
    }

    func subscribe(_ handler: @escaping (String) -> Void) -> Subscription {
        let id = nextID
        nextID += 1
        handlers[id] = handler
        return Subscription { [weak self] in
            self?.handlers[id] = nil
        }
    }

    func post(_ event: String) {
        for handler in handlers.values {
            handler(event)
        }
    }
}

final class InboxScreen {
    private var subscription: Subscription?

    init(center: EventCenter) {
        subscription = center.subscribe { [weak self] event in
            self?.show(event)
        }
    }

    func show(_ event: String) {
        print("Inbox shows \(event)")
    }

    deinit {
        print("Inbox freed")
    }
}

let center = EventCenter()
var inbox: InboxScreen? = InboxScreen(center: center)
center.post("new mail")
print("Handlers: \(center.handlerCount)")
inbox = nil
print("Handlers: \(center.handlerCount)")
```

```output
Inbox shows new mail
Handlers: 1
Inbox freed
Handlers: 0
```

Follow the ownership:

1. The center owns the handler closure; the closure captures the inbox weakly.
2. The inbox owns the `Subscription` token. The token's cancel closure captures the center weakly, so the token doesn't keep the center alive either.
3. `inbox = nil` frees the inbox. Its `subscription` property is released, the token's `deinit` runs `cancel()`, and the handler is removed from the center.

The subscription now lives exactly as long as the screen, and nobody has to remember to unsubscribe. Apple's Combine framework uses the same design: its `AnyCancellable` cancels automatically when it's deinitialized, which is why you'll see view models store their subscriptions in a property.

## Timers and notification observers

Two Foundation APIs cause a large share of real-world leaks. Both need an Apple-platform run loop to fire, so these blocks are illustrative and not run by the course's tests. In a Swift 6 project you'll also see concurrency annotations around them, which Module 29 explains.

**Repeating timers.** A scheduled timer is kept alive by the run loop until you call `invalidate()`. With the block-based API, the timer owns the block, and the block owns whatever it captures:

```swift illustrative
import Foundation

final class StopwatchScreen {
    private var timer: Timer?
    private var seconds = 0

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            seconds += 1
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
```

Without `[weak self]`, the run loop owns the timer, the timer owns the block, and the block owns the screen: the screen can never be freed, and its `deinit` can't invalidate anything. With `[weak self]`, the screen can be freed and `deinit` stops the timer.

The older target-and-selector API, `Timer.scheduledTimer(timeInterval:target:selector:userInfo:repeats:)`, is worse: Apple's documentation states that the timer keeps a strong reference to its **target** until the timer is invalidated. Invalidating it in the target's `deinit` can never work, because `deinit` can't run while the timer holds the target. Call `invalidate()` from an explicit `stop()`, for example when the screen disappears.

**Block-based notification observers.** `NotificationCenter.default.addObserver(forName:object:queue:using:)` returns an observer token, and the notification center keeps the block until you remove that token:

```swift illustrative
import UIKit

final class SettingsScreen {
    private var observer: NSObjectProtocol?

    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {}

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

The same two rules apply: capture `self` weakly so the screen can be freed, and remove the registration so the center doesn't keep calling a dead block. It's the token pattern from the previous section, with the cleanup written by hand.

## Noncopyable types

Everything so far relies on discipline: owners call `close()`, tokens are stored. Swift can also enforce **unique ownership** at compile time. A struct or enum marked `~Copyable` (SE-0390, Swift 5.9) can't be copied, only moved, so at any moment exactly one variable owns the value. Unlike a regular struct, it can have a `deinit`:

```swift
struct TempFile: ~Copyable {
    let id: Int

    init(id: Int) {
        self.id = id
        print("Opened file \(id)")
    }

    consuming func close() {
        print("Closing file \(id)")
    }

    deinit {
        print("Released file \(id)")
    }
}

func export() {
    let report = TempFile(id: 1)
    print("Writing to \(report.id)")
    report.close()
    print("After close")
    let scratch = TempFile(id: 2)
    print("Writing to \(scratch.id)")
}

export()
```

```output
Opened file 1
Writing to 1
Closing file 1
Released file 1
After close
Opened file 2
Writing to 2
Released file 2
```

A `consuming` method takes ownership of `self`. After `report.close()`, the value has been moved into `close()`, and its `deinit` runs when `close()` ends. Using `report` again is a compile error, not a runtime check:

```swift no-compile 'report' used after consume
struct TempFile: ~Copyable {
    let id: Int

    consuming func close() {}
}

func export() {
    let report = TempFile(id: 1)
    report.close()
    print(report.id)
}
```

Swift 6.3 says `error: 'report' used after consume`, with notes pointing at the line that consumed it and the line that used it. Noncopyable types have more rules than this (borrowing parameters, generics, `discard self`); you don't need them yet. Know that the tool exists when you want "exactly one owner, and the compiler checks it".

## Common mistakes

> [!error] Cleanup only in deinit
> If the object leaks, the cleanup leaks with it, and you can't handle errors there. Put cleanup in an explicit method; let `deinit` log and call it as a safety net.

> [!error] A service that keeps view models alive
> A long-lived service storing closures that capture view models strongly keeps every view model ever created. Capture weakly, and return a token so the subscription ends with its owner.

> [!error] Invalidating a target-based timer in deinit
> The timer owns its target until it's invalidated, so the target's `deinit` never runs. Stop the timer from an explicit method, or use the block API with `[weak self]`.

> [!error] Making the service weak in the view model
> `weak var cart: CartService?` in a view model works only as long as something else owns the cart. If the view model is the one that needs it, and the cart doesn't point back, a strong reference is correct.

````exercise
id: m13-l06-e1
type: comprehension
prompt: "An app has a long-lived `LocationService`. A `MapViewModel` gets the service injected and subscribes to location updates with a closure. Which set of references is right?"
choices:
  - text: "View model → service strong; service → closure strong; closure → view model weak; the view model keeps a token that unsubscribes when it's freed."
    correct: true
    why: "The view model needs the service while it exists. The long-lived service must not own the view model, and the token cleans up the handler."
  - text: "View model → service weak; closure → view model strong."
    correct: false
    why: "Backwards. The service would keep the view model alive forever, and the view model would lose the service if nothing else owned it."
  - text: "View model → service unowned; closure → view model unowned."
    correct: false
    why: "unowned in the closure traps if the service delivers an update after the view model is gone, which a long-lived service can easily do."
  - text: "Everything strong, and the view model sets the service to nil in deinit."
    correct: false
    why: "deinit never runs: the service's stored closure owns the view model."
solution: |
  **The first option.** Ownership flows down from the long-lived root: the service exists independently, the view model holds it to use it. The service holds the view model's closure, so the closure must capture the view model weakly. The token makes sure the closure itself is removed when the view model goes, so the service doesn't accumulate dead handlers.
````

````exercise
id: m13-l06-e2
type: prediction
prompt: "Using the `Subscription` token from the lesson, predict the exact output."
code: |
  final class Subscription {
      private var cancelAction: (() -> Void)?

      init(cancel: @escaping () -> Void) {
          cancelAction = cancel
      }

      func cancel() {
          cancelAction?()
          cancelAction = nil
      }

      deinit {
          cancel()
      }
  }

  final class Ticker {
      private var handlers: [Int: () -> Void] = [:]
      private var nextID = 0

      func subscribe(_ handler: @escaping () -> Void) -> Subscription {
          let id = nextID
          nextID += 1
          handlers[id] = handler
          return Subscription { [weak self] in
              self?.handlers[id] = nil
              print("Unsubscribed \(id)")
          }
      }

      func tick() {
          print("Tick for \(handlers.count)")
      }
  }

  let ticker = Ticker()
  var first: Subscription? = ticker.subscribe {}
  let second = ticker.subscribe {}
  ticker.tick()
  second.cancel()
  ticker.tick()
  first = nil
  ticker.tick()
  second.cancel()
  print("Done")
output: |
  Tick for 2
  Unsubscribed 1
  Tick for 1
  Unsubscribed 0
  Tick for 0
  Done
hints:
  - "The first subscription gets id 0, the second id 1."
  - "cancel() clears cancelAction, so a second cancel does nothing."
solution: |
  ```output
  Tick for 2
  Unsubscribed 1
  Tick for 1
  Unsubscribed 0
  Tick for 0
  Done
  ```

  `second.cancel()` removes handler 1 explicitly. `first = nil` frees the first token, and its `deinit` calls `cancel()`, removing handler 0. The final `second.cancel()` finds `cancelAction` already `nil`, so nothing prints. When the program ends, `second` is a global that is never torn down, so its `deinit` doesn't run, and it wouldn't print anything anyway.
````

````exercise
id: m13-l06-e3
type: find-errors
prompt: "A video player screen manages a recorder and a timer. Which statements are true?"
code: |
  final class VideoScreen: NSObject {
      var recorder = Recorder()
      var timer: Timer?

      func start() {
          recorder.open()
          timer = Timer.scheduledTimer(timeInterval: 1, target: self,
                                       selector: #selector(update),
                                       userInfo: nil, repeats: true)
      }

      @objc func update() {}

      deinit {
          timer?.invalidate()
          try recorder.saveAndClose()
      }
  }
choices:
  - text: "deinit never runs while the timer is scheduled, because the timer keeps a strong reference to its target until it's invalidated."
    correct: true
    why: "So the invalidate() in deinit is unreachable. The screen leaks."
  - text: "saveAndClose() can fail, but deinit can't throw and has no caller to report to."
    correct: true
    why: "Saving belongs in an explicit stop method that can throw or report the error."
  - text: "The recorder should be weak, because the screen and the recorder form a cycle."
    correct: false
    why: "The screen owns its recorder and nothing shows the recorder pointing back. Strong is right."
  - text: "Timer should be declared with unowned to avoid the leak."
    correct: false
    why: "The leak is the timer's reference to the screen, which you don't declare. You fix it by invalidating from an explicit method or using the block API with [weak self]."
rubric:
  - I explained why invalidate() in deinit never runs with a target-based timer.
  - I moved the cleanup to an explicit stop() that can report errors.
  - I kept a non-throwing safety net in deinit, or explained why not.
solution: |
  Both cleanup steps belong in an explicit method the screen's owner calls when the screen goes away:

  ```swift illustrative
  func stop() throws {
      timer?.invalidate()
      timer = nil
      try recorder.saveAndClose()
  }

  deinit {
      timer?.invalidate()   // safety net; only reachable if stop() already ran
  }
  ```

  With the target API, the timer owns the screen until `invalidate()` is called, so `stop()` is the only place that can break the loop. Alternatively, switch to `Timer.scheduledTimer(withTimeInterval:repeats:block:)` with `[weak self]`; then the screen can be freed and `deinit` can invalidate. Either way, saving the recording is work that can fail, so it goes in a throwing method, never in `deinit`.
````

````exercise
id: m13-l06-e4
type: design
prompt: |
  Design the ownership for a "Now Playing" feature: an `AudioEngine` that lives for the whole app, a `NowPlayingViewModel` created when the screen opens, a `QueueViewModel` child that shows upcoming tracks and tells the parent when the user skips, and progress updates the engine sends several times per second. For each relationship, say strong, weak or unowned (or "token"), and how the progress subscription ends.
rubric:
  - The app root owns AudioEngine; the view model holds it strongly (injected).
  - NowPlayingViewModel owns QueueViewModel strongly.
  - QueueViewModel reaches its parent through a weak delegate or a closure that captures weakly.
  - The engine's progress closure captures the view model weakly.
  - The subscription is ended by a token the view model stores (or an explicit unsubscribe), not left in the engine.
  - I explained why unowned is risky for the progress callback.
solution: |
  - **App root → AudioEngine: strong.** The engine outlives every screen.
  - **NowPlayingViewModel → AudioEngine: strong.** It's injected. The engine doesn't own the view model, so this can't form a loop.
  - **NowPlayingViewModel → QueueViewModel: strong.** The child exists only for this screen.
  - **QueueViewModel → NowPlayingViewModel: weak.** Either `weak var delegate: QueueDelegate?` with `protocol QueueDelegate: AnyObject`, or an `onSkip` closure set by the parent with `[weak self]`.
  - **Engine → progress closure: strong; closure → view model: weak.** The engine fires several times a second for as long as it lives. `[unowned self]` would trap on the first update after the screen closes.
  - **Ending the subscription: a token.** `engine.observeProgress { … }` returns a `Subscription`. The view model stores it in a property. When the screen closes and the view model is freed, the token's `deinit` removes the handler, so the engine stops calling a dead closure several times a second.

  A leak check for `NowPlayingViewModel` that calls the subscribe method should then print `freed`.
````

````exercise
id: m13-l06-e5
type: fill-in
prompt: |
  Complete `close()` and `deinit` so the program prints exactly:

  ```output
  Opened log
  Closed log
  Opened cache
  Warning: cache not closed
  Closed cache
  ```
code: |
  final class Resource {
      let name: String
      private var isOpen = true

      init(name: String) {
          self.name = name
          print("Opened \(name)")
      }

      func close() {
          [[1]] isOpen else { return }
          isOpen = [[2]]
          print("Closed \(name)")
      }

      [[3]] {
          if isOpen {
              print("Warning: \(name) not closed")
              [[4]]()
          }
      }
  }

  func useLog() {
      let log = Resource(name: "log")
      defer { log.close() }
  }

  func useCache() {
      _ = Resource(name: "cache")
  }

  useLog()
  useCache()
blanks:
  - id: "1"
    answers: ["guard"]
  - id: "2"
    answers: ["false"]
  - id: "3"
    answers: ["deinit"]
  - id: "4"
    answers: ["close", "self.close"]
solution: |
  ```swift
  final class Resource {
      let name: String
      private var isOpen = true

      init(name: String) {
          self.name = name
          print("Opened \(name)")
      }

      func close() {
          guard isOpen else { return }
          isOpen = false
          print("Closed \(name)")
      }

      deinit {
          if isOpen {
              print("Warning: \(name) not closed")
              close()
          }
      }
  }

  func useLog() {
      let log = Resource(name: "log")
      defer { log.close() }
  }

  func useCache() {
      _ = Resource(name: "cache")
  }

  useLog()
  useCache()
  ```

  ```output
  Opened log
  Closed log
  Opened cache
  Warning: cache not closed
  Closed cache
  ```

  `guard isOpen` makes `close()` idempotent. The log is closed by `defer`, so its `deinit` finds it closed and stays quiet. The cache is never closed: `_ =` discards the new object right away, `deinit` runs, sees it still open, warns and closes it.
````

````exercise
id: m13-l06-e6
type: solve
prompt: |
  The closing exercise. This small podcast app has **four** leaks. Find each one, fix it with the smallest change that matches the ownership rules from this module, and make the program print exactly:

  ```output
  Episode 1 of Swift Talk
  Episode 2 of Swift Talk
  Swift Talk: 2 episodes
  Downloading 50%
  EpisodeList: freed
  Show: freed
  Downloads still running: true
  ```

  Don't change the `checkFreed` function or the code at the bottom.
starter: |
  func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
      weak var probe: T?
      do {
          let object = make()
          probe = object
      }
      print(probe == nil ? "\(label): freed" : "\(label): LEAK")
  }

  final class DownloadService {
      private var listeners: [(Int) -> Void] = []
      var isRunning = true

      func onProgress(_ listener: @escaping (Int) -> Void) {
          listeners.append(listener)
      }

      func report(_ percent: Int) {
          for listener in listeners {
              listener(percent)
          }
      }
  }

  protocol EpisodeListDelegate {
      func didLoad(count: Int)
  }

  final class Show {
      let title: String
      var episodes: [Episode] = []

      init(title: String) {
          self.title = title
      }
  }

  final class Episode {
      let number: Int
      var show: Show

      init(number: Int, show: Show) {
          self.number = number
          self.show = show
      }
  }

  final class EpisodeList {
      let show: Show
      let downloads: DownloadService
      var delegate: EpisodeListDelegate?
      var status = ""

      lazy var header: () -> String = {
          "\(self.show.title): \(self.show.episodes.count) episodes"
      }

      init(show: Show, downloads: DownloadService) {
          self.show = show
          self.downloads = downloads
          downloads.onProgress { percent in
              self.status = "Downloading \(percent)%"
          }
      }

      func load() {
          for number in 1...2 {
              show.episodes.append(Episode(number: number, show: show))
          }
          for episode in show.episodes {
              print("Episode \(episode.number) of \(episode.show.title)")
          }
          delegate?.didLoad(count: show.episodes.count)
          print(header())
      }
  }

  final class EpisodeScreen: EpisodeListDelegate {
      let list: EpisodeList

      init(list: EpisodeList) {
          self.list = list
          list.delegate = self
      }

      func didLoad(count: Int) {}
  }

  let downloads = DownloadService()

  checkFreed("EpisodeList") {
      let list = EpisodeList(show: Show(title: "Swift Talk"), downloads: downloads)
      let screen = EpisodeScreen(list: list)
      screen.list.load()
      downloads.report(50)
      print(list.status)
      return list
  }

  checkFreed("Show") {
      let show = Show(title: "Swift Talk")
      show.episodes.append(Episode(number: 1, show: show))
      return show
  }

  print("Downloads still running: \(downloads.isRunning)")
hints:
  - "Draw the graph. For each reference, ask: should this keep the other object alive?"
  - "Two leaks are in EpisodeList itself, one is between Show and Episode, one is between EpisodeList and EpisodeScreen."
  - "The delegate fix needs a change to the protocol too."
  - "The lazy closure is only ever called by the list itself."
rubric:
  - Episode.show is weak (or unowned with a stated guarantee), so a show and its episodes don't own each other.
  - EpisodeListDelegate is class-bound and EpisodeList.delegate is weak.
  - The DownloadService closure captures the list weakly.
  - The lazy header closure captures self weakly or unowned.
  - DownloadService stays strong in EpisodeList.
  - Both checks print freed and the output matches exactly.
solution: |
  ```swift
  func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
      weak var probe: T?
      do {
          let object = make()
          probe = object
      }
      print(probe == nil ? "\(label): freed" : "\(label): LEAK")
  }

  final class DownloadService {
      private var listeners: [(Int) -> Void] = []
      var isRunning = true

      func onProgress(_ listener: @escaping (Int) -> Void) {
          listeners.append(listener)
      }

      func report(_ percent: Int) {
          for listener in listeners {
              listener(percent)
          }
      }
  }

  protocol EpisodeListDelegate: AnyObject {
      func didLoad(count: Int)
  }

  final class Show {
      let title: String
      var episodes: [Episode] = []

      init(title: String) {
          self.title = title
      }
  }

  final class Episode {
      let number: Int
      weak var show: Show?

      init(number: Int, show: Show) {
          self.number = number
          self.show = show
      }
  }

  final class EpisodeList {
      let show: Show
      let downloads: DownloadService
      weak var delegate: EpisodeListDelegate?
      var status = ""

      lazy var header: () -> String = { [unowned self] in
          "\(show.title): \(show.episodes.count) episodes"
      }

      init(show: Show, downloads: DownloadService) {
          self.show = show
          self.downloads = downloads
          downloads.onProgress { [weak self] percent in
              self?.status = "Downloading \(percent)%"
          }
      }

      func load() {
          for number in 1...2 {
              show.episodes.append(Episode(number: number, show: show))
          }
          for episode in show.episodes {
              print("Episode \(episode.number) of \(episode.show?.title ?? "?")")
          }
          delegate?.didLoad(count: show.episodes.count)
          print(header())
      }
  }

  final class EpisodeScreen: EpisodeListDelegate {
      let list: EpisodeList

      init(list: EpisodeList) {
          self.list = list
          list.delegate = self
      }

      func didLoad(count: Int) {}
  }

  let downloads = DownloadService()

  checkFreed("EpisodeList") {
      let list = EpisodeList(show: Show(title: "Swift Talk"), downloads: downloads)
      let screen = EpisodeScreen(list: list)
      screen.list.load()
      downloads.report(50)
      print(list.status)
      return list
  }

  checkFreed("Show") {
      let show = Show(title: "Swift Talk")
      show.episodes.append(Episode(number: 1, show: show))
      return show
  }

  print("Downloads still running: \(downloads.isRunning)")
  ```

  ```output
  Episode 1 of Swift Talk
  Episode 2 of Swift Talk
  Swift Talk: 2 episodes
  Downloading 50%
  EpisodeList: freed
  Show: freed
  Downloads still running: true
  ```

  The four leaks, and why each fix fits:

  1. **Show ⇄ Episode.** The show owns its episodes; each episode pointed back strongly. Strong down, weak up: `weak var show: Show?`. (`unowned let` would also be defensible if episodes are never stored outside their show, but nothing in this code enforces that.)
  2. **EpisodeList ⇄ EpisodeScreen.** The screen owns the list, and the list held its delegate strongly. The delegate becomes `weak`, which requires `protocol EpisodeListDelegate: AnyObject`.
  3. **EpisodeList → DownloadService → closure → EpisodeList.** The list holds the service, the service stores the progress closure, and the closure captured the list strongly. Even without the list's property it would leak, because the service lives for the whole program and would keep every list alive. `[weak self]` fixes both problems. The list's strong reference to the service stays: once the closure is weak, nothing leads from the service back to the list.
  4. **The lazy `header` closure.** It's stored in the list's own property and captured `self` strongly. It's only called from `load()`, by the list itself, so `[unowned self]` is safe; `[weak self]` would work too.

  The service still has a dead listener after the list is freed. To remove it, `onProgress` should return a `Subscription` token, as in the lesson, and the list should store it.
````

## Summary

- Ownership flows down: roots own services and screens, screens own view models, view models own children. References back up are weak.
- A view model can hold an injected service strongly. A long-lived service must never own a view model, directly or through a stored closure.
- Put cleanup with outside effects in an explicit, idempotent `close()` or `stop()`. Use `deinit` as a safety net that logs and cleans up what someone forgot.
- Return a token from `subscribe`. The owner stores it; when the owner goes, the token's `deinit` unsubscribes.
- Repeating timers and block-based notification observers need weak captures and explicit invalidation or removal. A target-based timer owns its target until it's invalidated.
- `~Copyable` types have exactly one owner at a time, enforced by the compiler, and can have a `deinit`.
