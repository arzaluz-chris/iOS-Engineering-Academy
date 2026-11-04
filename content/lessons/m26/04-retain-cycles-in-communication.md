---
id: m26-l04
title: Retain cycles in communication
description: Every communication mechanism stores a reference back to the listener, and that back-reference is where leaks come from. You build a leak check with a weak probe, then use it on a strong delegate, a closure stored by the object it captures, a method passed as a callback, a notification observer and a timer, fix each one, and learn which cycles are harmless because they break themselves.
module: m26
order: 4
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l03]
objectives:
  - Write a leak check that creates an object, drops it and reports whether a weak reference became nil.
  - Find the cycle formed by a strong delegate property and fix it.
  - Find the cycle formed when an object stores a closure that captures it, including through a method reference.
  - Explain why notification observers and timers leak when their closures capture self strongly.
  - Tell a permanent cycle from a temporary one that ends when the work finishes.
terms:
  - term: Back-reference
    definition: "The reference a communication mechanism keeps to the listener: a delegate property, a stored closure's captures, an observer block held by a notification center, a timer's target or block."
  - term: Weak probe
    definition: "A weak variable pointed at an object under test. If it's nil after the last strong reference is dropped, the object was released; if not, something still owns it."
  - term: Method reference
    definition: "Using an instance method as a value, such as viewModel.onChange = render. The resulting closure captures the instance strongly, like { self.render() }."
  - term: Temporary cycle
    definition: "A cycle that's broken by the code itself when some work finishes, for example a stored completion handler that's set to nil after it runs. It delays the release; it doesn't leak."
mastery:
  - Write checkReleased and use it to prove a leak and its fix.
  - Spot a method reference used as a callback and rewrite it with [weak self].
  - Explain the ownership chain center → block → screen and run loop → timer → block → screen.
  - Decide whether a completion handler should capture self weakly or strongly, and say what changes for the user.
resources: [swift-book-arc, swift-book-closures, swift-book-deinitialization, xcode-memory-use]
cards:
  - id: m26-l04-c1
    front: How do you check, in code, that an object is released?
    back: "Point a weak variable at it, drop every strong reference (end a do block or set the variable to nil), and check that the weak variable is nil. If it isn't, something still owns the object."
  - id: m26-l04-c2
    front: Why does viewModel.onChange = render leak inside a screen that owns the view model?
    back: "A method reference is a closure that captures self strongly. The screen owns the view model, the view model owns the closure, the closure owns the screen. Write { [weak self] in self?.render() }."
  - id: m26-l04-c3
    front: Ownership chain of a leaked notification observer?
    back: "The notification center owns the block (until removeObserver), and the block owns whatever it captures strongly. If it captures the screen, the screen lives as long as the registration, which is usually removed in the screen's own cleanup that never runs."
  - id: m26-l04-c4
    front: Ownership chain of a scheduled repeating timer?
    back: "The run loop owns the timer until it's invalidated; the timer owns its block (or its target, for the selector API). [weak self] lets the screen go, but the timer keeps firing until you call invalidate()."
  - id: m26-l04-c5
    front: When is a closure that captures self strongly fine?
    back: "When whatever stores it lets go after calling it: a completion handler stored only until the request finishes, a UIView.animate block, a closure you call immediately. The cycle, if any, breaks when the work ends."
---

## The idea in one sentence

Delegates, callbacks, observers and timers all keep a reference back to whoever is listening, and when the listener also owns the thing that holds that reference, the two keep each other alive forever.

> [!note] About this lesson's code
> Module 13 explained cycles, `weak` and `unowned`, deinit logging and the memory graph. This lesson applies them to the four mechanisms of this module. Every block was compiled and run with Swift 6.3, including the `Timer` and `NotificationCenter` ones (Foundation on Linux); the selector-based timer is UIKit code, type-checked against the iOS SDK.

## A leak check

Printing in `deinit` tells you when an object goes away, but you have to notice a line that's **missing**. A check that prints a verdict is easier to read. The idea from Module 13, lesson 5, as a reusable function:

```swift
func checkReleased(_ label: String, _ make: () -> AnyObject) {
    weak var probe: AnyObject?
    do {
        let object = make()
        probe = object
    }
    print("\(label): \(probe == nil ? "released" : "LEAKED")")
}

final class Plain {}

final class SelfOwning {
    var me: SelfOwning?
}

checkReleased("plain object") { Plain() }
checkReleased("self-owning object") {
    let object = SelfOwning()
    object.me = object
    return object
}
```

```output
plain object: released
self-owning object: LEAKED
```

- `make` builds the object **and wires it up** the way the app would. That's where cycles are created.
- `probe` is weak, so it doesn't keep anything alive. The only strong reference from the check itself is `object`, which ends with the `do` block.
- If `probe` is still pointing at something, another owner exists. In a cycle, that owner is the object's own graph.

In a test target the same check becomes `#expect(probe == nil)` (Module 13, lesson 5). The rest of this lesson runs it against each communication mechanism.

## Delegates: the strong property

You've seen this one twice, so here it is only as a reference point, with a screen that owns a form and is its delegate:

```swift
func checkReleased(_ label: String, _ make: () -> AnyObject) {
    weak var probe: AnyObject?
    do {
        let object = make()
        probe = object
    }
    print("\(label): \(probe == nil ? "released" : "LEAKED")")
}

protocol FormDelegate: AnyObject {
    func formDidSubmit()
}

final class StrongForm {
    var delegate: FormDelegate?
}

final class WeakForm {
    weak var delegate: FormDelegate?
}

final class StrongScreen: FormDelegate {
    let form = StrongForm()
    init() { form.delegate = self }
    func formDidSubmit() {}
}

final class WeakScreen: FormDelegate {
    let form = WeakForm()
    init() { form.delegate = self }
    func formDidSubmit() {}
}

checkReleased("strong delegate") { StrongScreen() }
checkReleased("weak delegate") { WeakScreen() }
```

```output
strong delegate: LEAKED
weak delegate: released
```

The chain is screen → form → screen. One `weak` keyword breaks it. A multicast list (lesson 1) needs the same treatment for each element: a strong `[FormDelegate]` array is the same cycle, once per listener.

## Closures stored by the object they capture

A callback is a cycle when the listener owns, directly or indirectly, the object that stores the closure, and the closure captures the listener strongly. The direct case is easy to spot. The indirect one isn't: passing a **method** as the callback.

```swift
func checkReleased(_ label: String, _ make: () -> AnyObject) {
    weak var probe: AnyObject?
    do {
        let object = make()
        probe = object
    }
    print("\(label): \(probe == nil ? "released" : "LEAKED")")
}

final class ViewModel {
    var onChange: (() -> Void)?
}

final class Screen {
    let viewModel = ViewModel()

    func render() {}

    func bindStrong() {
        viewModel.onChange = { self.render() }
    }

    func bindMethod() {
        viewModel.onChange = render
    }

    func bindWeak() {
        viewModel.onChange = { [weak self] in self?.render() }
    }
}

checkReleased("strong closure") {
    let screen = Screen()
    screen.bindStrong()
    return screen
}
checkReleased("method reference") {
    let screen = Screen()
    screen.bindMethod()
    return screen
}
checkReleased("weak closure") {
    let screen = Screen()
    screen.bindWeak()
    return screen
}
```

```output
strong closure: LEAKED
method reference: LEAKED
weak closure: released
```

`viewModel.onChange = render` reads like "call `render` when it changes", but `render` here means `self.render`: a closure that holds `self` strongly to have something to call `render` on. The compiler doesn't warn about it, because the capture is implicit. Treat any `object.callback = someMethod` inside a class as a strong capture of `self`.

The same goes for `[unowned self]`: it breaks the cycle, but if the view model ever calls `onChange` after the screen is gone (say, from a late network response), the program stops. For callbacks whose timing you don't control, `weak` is the safe default (Module 13, lesson 3).

## Notification observers

The notification center owns every block you register, until you remove it. A block that captures `self` strongly makes the center an owner of the screen:

```swift
import Foundation

func checkReleased(_ label: String, _ make: () -> AnyObject) {
    weak var probe: AnyObject?
    do {
        let object = make()
        probe = object
    }
    print("\(label): \(probe == nil ? "released" : "LEAKED")")
}

extension Notification.Name {
    static let ping = Notification.Name("Ping")
}

@MainActor
final class Listener {
    private var token: (any NSObjectProtocol)?
    let name: String

    init(name: String, center: NotificationCenter, captureStrongly: Bool) {
        self.name = name
        if captureStrongly {
            token = center.addObserver(forName: .ping, object: nil, queue: nil) { _ in
                MainActor.assumeIsolated { self.handle() }
            }
        } else {
            token = center.addObserver(forName: .ping, object: nil, queue: nil) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle() }
            }
        }
    }

    func handle() {
        print("\(name) handles ping")
    }
}

let center = NotificationCenter()
checkReleased("strong observer") {
    Listener(name: "strong", center: center, captureStrongly: true)
}
checkReleased("weak observer") {
    Listener(name: "weak", center: center, captureStrongly: false)
}
center.post(name: .ping, object: nil)
```

```output
strong observer: LEAKED
weak observer: released
strong handles ping
```

The last line is the real cost. A leaked screen isn't just memory: it keeps **reacting**. A leaked editor that saves on "app will resign active" saves a document the user closed; three leaked copies save it three times.

This isn't strictly a cycle (the center isn't owned by the listener), but the effect is the same, because the usual plan, removing the observer in `deinit`, can't run while the block keeps the listener alive. With `[weak self]` the listener is released, but notice that its block is still registered: nothing removed it. It runs on every ping and does nothing. That's why lesson 3 tied the registration to a token object.

## Timers

A scheduled timer has an owner you didn't write: the **run loop** keeps it until it's invalidated. The timer owns its block, and the block owns what it captures. Even an unscheduled timer stored in a property shows the closure half of the problem:

```swift
import Foundation

func checkReleased(_ label: String, _ make: () -> AnyObject) {
    weak var probe: AnyObject?
    do {
        let object = make()
        probe = object
    }
    print("\(label): \(probe == nil ? "released" : "LEAKED")")
}

@MainActor
final class Stopwatch {
    private var timer: Timer?
    private var seconds = 0

    func prepareStrong() {
        timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.seconds += 1 }
        }
    }

    func prepareWeak() {
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.seconds += 1 }
        }
    }
}

checkReleased("timer, strong block") {
    let stopwatch = Stopwatch()
    stopwatch.prepareStrong()
    return stopwatch
}
checkReleased("timer, weak block") {
    let stopwatch = Stopwatch()
    stopwatch.prepareWeak()
    return stopwatch
}
```

```output
timer, strong block: LEAKED
timer, weak block: released
```

(`Timer(timeInterval:repeats:block:)` creates the timer without scheduling it, so nothing fires here; the point is who owns whom.) Once a timer is scheduled with `Timer.scheduledTimer(withTimeInterval:repeats:block:)`, `[weak self]` still lets the screen go, but the **timer keeps firing** every second for the rest of the app's life, doing nothing, until someone calls `invalidate()`.

The selector-based API is worse. Apple's documentation for `scheduledTimer(timeInterval:target:selector:userInfo:repeats:)`: "The timer maintains a strong reference to `target` until it (the timer) is invalidated." There's no `weak` option. Invalidating in the target's `deinit` can't work, because `deinit` can't run while the timer holds the target. Invalidate from a lifecycle method you know will run:

```swift ios
import UIKit

final class CountdownViewController: UIViewController {
    private var timer: Timer?
    private var remaining = 10
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(label)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(tick(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick(_ timer: Timer) {
        remaining -= 1
        label.text = "\(remaining)"
        if remaining == 0 {
            timer.invalidate()
            self.timer = nil
        }
    }
}
```

Start in `viewDidAppear(_:)`, stop in `viewWillDisappear(_:)`: the pair always runs, so the timer never outlives the screen's time on screen. The same pairing works for the block API, and it's the right default for anything that should only run while a screen is visible.

## Cycles that break themselves

Not every strong capture is a bug. A cycle is a leak only if nothing ever breaks it. A completion handler that the worker **drops after calling it** creates, at most, a temporary cycle:

```swift
final class Uploader {
    private var completion: ((Bool) -> Void)?

    func start(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func finish() {
        completion?(true)
        completion = nil
    }
}

final class ComposeScreen {
    let uploader = Uploader()
    var status = "draft"

    func send() {
        uploader.start { ok in
            self.status = ok ? "sent" : "failed"
            print("status: \(self.status)")
        }
    }

    deinit {
        print("compose screen released")
    }
}

var screen: ComposeScreen? = ComposeScreen()
screen?.send()
let uploader = screen?.uploader
screen = nil
print("screen variable cleared")
uploader?.finish()
print("end")
```

```output
screen variable cleared
status: sent
compose screen released
end
```

While the upload is in flight, screen → uploader → completion → screen is a real cycle, and that's what keeps the screen alive after `screen = nil`. When `finish()` runs the completion and sets it to `nil`, the cycle breaks and the screen is released. Nothing leaked; the release was delayed until the work ended.

Whether that's what you **want** is a product decision:

- **Strong capture:** the work finishes and updates the object even if the user closed the screen. Right for "save my changes", wrong for "update a label nobody can see".
- **`[weak self]`:** if the screen is gone, the result is dropped. Right for UI updates.

What turns a temporary cycle into a leak is a worker that **never** lets go: a callback stored for the object's whole life (`onChange`), a repeating timer, an observer nobody removes. Those are the ones that need `weak`.

## Finding them in a real app

The leak check proves a fix; it doesn't find the leak. In an app, the workflow from Module 13, lesson 5 applies: open and close the suspicious screen a few times, then use Xcode's **Debug Memory Graph** and look for several instances of a view controller that should have one or none. The graph shows the path that keeps each one alive. Because of this lesson, you know what to look for on that path: a delegate property without `weak`, a closure property on a child, a block owned by `NSNotificationCenter`, an `NSTimer`. Adding a `deinit` that logs to every view controller during development is cheap and catches most of these the first time you close the screen.

## Common mistakes

> [!error] A method passed as a callback
> `button.onTap = save` or `viewModel.onChange = render` captures `self` strongly. Write `{ [weak self] in self?.save() }`.

> [!error] Weak self in the observer, but the registration is never removed
> The screen is freed, but its block stays in the center and runs on every post. Remove the registration (store the token) as well as capturing weakly.

> [!error] Invalidating a selector-based timer in deinit
> The timer holds its target strongly, so the target's `deinit` never runs. Invalidate from a lifecycle method such as `viewWillDisappear(_:)` or an explicit `stop()`.

> [!error] Assuming [weak self] stops a timer
> It lets the owner go, but a scheduled repeating timer keeps firing until `invalidate()`.

> [!error] [weak self] everywhere by reflex
> For a save that must complete, a weak capture silently drops the result if the user leaves the screen. Decide whether the work should outlive the screen, and capture accordingly.

> [!error] A strong array of listeners
> A manager with `var listeners: [Listener]` owns every listener for as long as it lives. Box them weakly or hand out tokens.

## Exercises

````exercise
id: m26-l04-e1
type: prediction
prompt: "A player screen binds three callbacks in different ways. Which screens are released?"
code: |
  func checkReleased(_ label: String, _ make: () -> AnyObject) {
      weak var probe: AnyObject?
      do {
          let object = make()
          probe = object
      }
      print("\(label): \(probe == nil ? "released" : "LEAKED")")
  }

  final class Controls {
      var onPlay: (() -> Void)?
  }

  final class PlayerScreen {
      let controls = Controls()
      var plays = 0

      func play() { plays += 1 }

      func bind(_ style: Int) {
          switch style {
          case 1: controls.onPlay = play
          case 2: controls.onPlay = { [weak self] in self?.play() }
          default:
              let counter = Controls()
              counter.onPlay = { self.play() }
              counter.onPlay?()
          }
      }
  }

  for style in 1...3 {
      checkReleased("style \(style)") {
          let screen = PlayerScreen()
          screen.bind(style)
          return screen
      }
  }
output: |
  style 1: LEAKED
  style 2: released
  style 3: released
hints:
  - "A method reference captures self strongly."
  - "In style 3, who owns counter after bind returns?"
solution: |
  ```output
  style 1: LEAKED
  style 2: released
  style 3: released
  ```

  Style 1 stores `play`, a closure that holds the screen, in `controls`, which the screen owns: a cycle. Style 2 captures weakly. Style 3 captures `self` strongly too, but the closure is stored in `counter`, a local object nobody keeps after `bind` returns. The closure is freed with it, so there's no cycle. A strong capture is only a problem when something the screen owns (or something long-lived) keeps the closure.
````

````exercise
id: m26-l04-e2
type: prediction
prompt: "A temporary cycle. In what order do these lines print?"
code: |
  final class Loader {
      private var pending: [(String) -> Void] = []
      func load(_ completion: @escaping (String) -> Void) {
          pending.append(completion)
      }
      func deliver() {
          let callbacks = pending
          pending = []
          for callback in callbacks {
              callback("data")
          }
      }
  }

  final class Screen {
      let name: String
      let loader: Loader
      init(name: String, loader: Loader) {
          self.name = name
          self.loader = loader
      }
      func refresh(weakly: Bool) {
          if weakly {
              loader.load { [weak self] data in
                  print("\(self?.name ?? "nobody") got \(data)")
              }
          } else {
              loader.load { data in
                  print("\(self.name) got \(data)")
              }
          }
      }
      deinit { print("\(name) released") }
  }

  let loader = Loader()
  var a: Screen? = Screen(name: "A", loader: loader)
  var b: Screen? = Screen(name: "B", loader: loader)
  a?.refresh(weakly: true)
  b?.refresh(weakly: false)
  a = nil
  b = nil
  print("both variables cleared")
  loader.deliver()
  print("end")
output: |
  A released
  both variables cleared
  nobody got data
  B got data
  B released
  end
hints:
  - "The loader is a global; it outlives both screens. Does it own them?"
  - "B's callback holds B strongly until the loader drops it."
solution: |
  ```output
  A released
  both variables cleared
  nobody got data
  B got data
  B released
  end
  ```

  A's callback captured A weakly, so `a = nil` releases A immediately, and its callback later finds `nil`. B's callback holds B strongly, and the loader holds the callback, so B outlives `b = nil`. `deliver()` copies the callbacks, empties `pending` and runs them: B prints its result, and when the loop finishes and `callbacks` goes away, nothing owns B any more. It's released, late but not leaked. (The screens own the loader too, but the loader is also a global, so it's never freed here.)
````

````exercise
id: m26-l04-e3
type: comprehension
prompt: "A view controller starts Timer.scheduledTimer(timeInterval:target: self, selector:…, repeats: true) in viewDidLoad() and calls timer.invalidate() in deinit. What happens when the user closes the screen?"
choices:
  - text: "The controller is never released: the timer holds its target strongly until invalidated, and invalidation is in a deinit that can't run."
    correct: true
    why: "That's the documented behavior of the target-selector API. Invalidate from viewWillDisappear(_:) or an explicit stop() instead."
  - text: "The controller is released and deinit invalidates the timer, so everything is cleaned up."
    correct: false
    why: "deinit only runs when nothing owns the object, and the timer does."
  - text: "The timer holds the target weakly, so the controller is released and the timer stops on its own."
    correct: false
    why: "Apple documents a strong reference to the target until the timer is invalidated."
  - text: "The run loop releases the timer when the controller's view leaves the window."
    correct: false
    why: "The run loop keeps a scheduled timer until it's invalidated, regardless of any view."
solution: |
  **It leaks.** Run loop → timer → target (the controller). The controller's `deinit` would invalidate the timer, but `deinit` can't run while the timer owns the controller. Move `invalidate()` to `viewWillDisappear(_:)` (and start the timer in `viewDidAppear(_:)`), or use the block API with `[weak self]` plus an explicit invalidation.
````

````exercise
id: m26-l04-e4
type: find-errors
prompt: "After opening and closing this chat screen five times, the memory graph shows five ChatViewController instances. Mark every reason."
code: |
  final class ChatViewController: UIViewController, ComposerViewDelegate {
      private let composer = ComposerView()
      private let viewModel = ChatViewModel()
      private var typingTimer: Timer?
      private var keyboardToken: (any NSObjectProtocol)?

      override func viewDidLoad() {
          super.viewDidLoad()
          composer.delegate = self
          viewModel.onNewMessage = showMessage
          keyboardToken = NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
          ) { [weak self] _ in
              MainActor.assumeIsolated { self?.scrollToBottom() }
          }
          typingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
              MainActor.assumeIsolated { self.viewModel.sendTypingStatus() }
          }
      }

      func showMessage(_ text: String) {}
      func scrollToBottom() {}
  }

  final class ComposerView: UIView {
      weak var delegate: ComposerViewDelegate?
  }
choices:
  - text: "viewModel.onNewMessage = showMessage stores a method reference, which captures the controller strongly; the controller owns the view model."
    correct: true
  - text: "The scheduled timer's block captures self strongly; the run loop owns the timer, which is never invalidated."
    correct: true
  - text: "The keyboard observer block captures self weakly, so it doesn't keep the controller alive (though the registration is never removed)."
    correct: false
  - text: "composer.delegate = self is a cycle because the controller owns the composer."
    correct: false
  - text: "Storing keyboardToken in a property is a cycle."
    correct: false
rubric:
  - Identifies the method reference as a strong capture.
  - Identifies the timer chain run loop → timer → block → controller and the missing invalidate.
  - Recognizes the weak delegate and the weak observer as non-causes, while noting the observer should still be removed.
solution: |
  Two things keep each controller alive:

  1. **`viewModel.onNewMessage = showMessage`.** Controller → view model → closure → controller. Write `viewModel.onNewMessage = { [weak self] text in self?.showMessage(text) }`.
  2. **The timer.** The run loop owns the scheduled timer, the timer owns its block, and the block captures `self` strongly. Capture `[weak self]`, and invalidate the timer in `viewWillDisappear(_:)`; with only `[weak self]` the controller would be freed but a timer per visit would keep firing.

  The composer's delegate is `weak`, so it's fine. The keyboard observer captures weakly, so it doesn't retain the controller, but its registration is never removed: after five visits there are five dead blocks in the default center. Remove it in `viewWillDisappear(_:)` or wrap it in a token object. Storing the token in a property is how you're supposed to do it; the token doesn't own the controller.
````

````exercise
id: m26-l04-e5
type: solve
prompt: |
  This search screen leaks. Fix it so both checks print `released`, without changing what the screen does when it's alive. Keep `checkReleased` as it is.

  ```swift
  func checkReleased(_ label: String, _ make: () -> AnyObject) {
      weak var probe: AnyObject?
      do {
          let object = make()
          probe = object
      }
      print("\(label): \(probe == nil ? "released" : "LEAKED")")
  }

  protocol SearchBoxDelegate: AnyObject {
      func searchBox(_ box: SearchBox, didType text: String)
  }

  final class SearchBox {
      var delegate: SearchBoxDelegate?
      func type(_ text: String) { delegate?.searchBox(self, didType: text) }
  }

  final class ResultsList {
      var onSelect: ((String) -> Void)?
      func select(_ item: String) { onSelect?(item) }
  }

  final class SearchScreen: SearchBoxDelegate {
      let box = SearchBox()
      let results = ResultsList()
      var log: [String] = []

      init() {
          box.delegate = self
          results.onSelect = open
      }

      func searchBox(_ box: SearchBox, didType text: String) { log.append("typed \(text)") }
      func open(_ item: String) { log.append("opened \(item)") }
  }

  let screen = SearchScreen()
  screen.box.type("swift")
  screen.results.select("Swift.org")
  print(screen.log)
  checkReleased("search screen") { SearchScreen() }
  checkReleased("used search screen") {
      let screen = SearchScreen()
      screen.box.type("ios")
      return screen
  }
  ```

  Expected output after the fix:

  ```plaintext
  ["typed swift", "opened Swift.org"]
  search screen: released
  used search screen: released
  ```
starter: |
  // Paste the code above and fix it.
hints:
  - "There are two cycles, one per communication mechanism."
  - "results.onSelect = open is a method reference."
rubric:
  - The delegate property is weak.
  - onSelect captures self weakly.
  - The live behavior (the log) is unchanged.
  - The output matches.
solution: |
  ```swift
  func checkReleased(_ label: String, _ make: () -> AnyObject) {
      weak var probe: AnyObject?
      do {
          let object = make()
          probe = object
      }
      print("\(label): \(probe == nil ? "released" : "LEAKED")")
  }

  protocol SearchBoxDelegate: AnyObject {
      func searchBox(_ box: SearchBox, didType text: String)
  }

  final class SearchBox {
      weak var delegate: SearchBoxDelegate?
      func type(_ text: String) { delegate?.searchBox(self, didType: text) }
  }

  final class ResultsList {
      var onSelect: ((String) -> Void)?
      func select(_ item: String) { onSelect?(item) }
  }

  final class SearchScreen: SearchBoxDelegate {
      let box = SearchBox()
      let results = ResultsList()
      var log: [String] = []

      init() {
          box.delegate = self
          results.onSelect = { [weak self] item in
              self?.open(item)
          }
      }

      func searchBox(_ box: SearchBox, didType text: String) { log.append("typed \(text)") }
      func open(_ item: String) { log.append("opened \(item)") }
  }

  let screen = SearchScreen()
  screen.box.type("swift")
  screen.results.select("Swift.org")
  print(screen.log)
  checkReleased("search screen") { SearchScreen() }
  checkReleased("used search screen") {
      let screen = SearchScreen()
      screen.box.type("ios")
      return screen
  }
  ```

  ```output
  ["typed swift", "opened Swift.org"]
  search screen: released
  used search screen: released
  ```

  `weak var delegate` breaks screen → box → screen. The closure with `[weak self]` breaks screen → results → closure → screen, which `results.onSelect = open` had created through the method reference. Fixing only one of the two still leaks: the check would keep printing `LEAKED` until both are gone, which is why a verdict per object is more useful than reading code.
````

````exercise
id: m26-l04-e6
type: explain
prompt: "A colleague says: \"I put [weak self] in every closure so I never get leaks.\" Using this code, explain what that rule gets right, what it misses, and what you'd do instead."
code: |
  final class EditorViewController: UIViewController {
      private let document: Document
      private var autosaveTimer: Timer?

      init(document: Document) {
          self.document = document
          super.init(nibName: nil, bundle: nil)
      }

      required init?(coder: NSCoder) { fatalError() }

      override func viewDidAppear(_ animated: Bool) {
          super.viewDidAppear(animated)
          autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
              MainActor.assumeIsolated { self?.autosave() }
          }
      }

      func close() {
          document.save { [weak self] success in
              self?.showSavedBanner(success)
          }
          dismiss(animated: true)
      }

      private func autosave() {}
      private func showSavedBanner(_ success: Bool) {}
  }
rubric:
  - Agrees that [weak self] prevents the controller from being retained by the timer block and the save callback.
  - Points out the scheduled timer is never invalidated and keeps firing after the controller is gone.
  - Distinguishes the save callback (stored until the save finishes, a temporary cycle at most) from long-lived stored callbacks.
  - Notes that weak capture drops the banner if the screen closes first, and says whether that's acceptable here.
  - Recommends deciding per closure by asking who stores it and for how long, plus explicit cleanup for timers and observers.
solution: |
  The rule prevents the classic leak: neither the timer's block nor the save callback can keep the editor alive, so closing it frees it.

  It misses two things. First, **releasing isn't stopping.** The run loop still owns the autosave timer, which fires every 30 seconds forever, finding `self` nil each time. One dead timer per editor opened. The fix is lifecycle cleanup: `autosaveTimer?.invalidate()` in `viewWillDisappear(_:)`.

  Second, **weak changes behavior.** `document.save` stores its callback only until the save finishes, so a strong capture would at most delay the editor's release by the length of the save, a temporary cycle. With `[weak self]`, closing the editor (which `close()` does right away) usually means the banner never appears. Here that's arguably right (the banner belongs to a screen that's gone), but it's a choice, not a free safety net. For "the work must finish", the important part is that `document.save` itself completes, which it does whether or not the editor is alive.

  The better rule: for each closure, ask who stores it and for how long. Stored for the object's whole life (`onChange`, observers, repeating timers): capture weakly **and** clean up the registration. Stored until some work finishes: decide whether the result matters if the user has left. Not stored at all (`map`, `UIView.animate`): no capture list needed.
````

## Summary

- Every mechanism keeps a back-reference to its listener: delegate properties, stored closures, observer blocks held by the notification center, timers held by the run loop. A cycle forms when the listener owns, directly or indirectly, whatever keeps that reference.
- Prove a fix with a weak probe: build and wire the object, drop it, and check that the weak reference is `nil`.
- Delegates: `weak var delegate`, and weak boxes in multicast lists.
- Closures: `[weak self]` when the closure is stored by something self owns. A method reference (`onChange = render`) is a strong capture of `self`.
- Notification observers: capture weakly **and** remove the registration; a leaked observer keeps reacting.
- Timers: the run loop owns scheduled timers until `invalidate()`. The selector API holds its target strongly, so invalidate from a lifecycle method, never from the target's `deinit`.
- A cycle that's broken when work finishes (a completion handler dropped after it runs) delays release; it doesn't leak. Whether to capture weakly there is a decision about what should happen if the user leaves.
