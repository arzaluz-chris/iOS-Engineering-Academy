---
id: m26-l01
title: Delegates in depth
description: Design delegate protocols the way UIKit does. You decide which methods ask and which report, split a protocol when it has two jobs, choose between @objc optional requirements and default implementations in an extension (and avoid the dispatch trap that comes with extensions), handle the one-delegate limit with a list of weak references when several objects need to hear, and make delegate protocols work with the main actor in Swift 6.
module: m26
order: 1
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l04, m13-l04]
objectives:
  - Design a delegate protocol with clear will/did/should methods, the sender as the first parameter, and only the values the delegate needs.
  - Explain why delegate protocols are class-bound and when a framework keeps its delegate strongly instead.
  - Make requirements optional with @objc optional or with default implementations, and call each correctly.
  - Predict which implementation runs when a method exists only in a protocol extension.
  - Notify several listeners with a list of weak references when one delegate isn't enough.
  - Make a delegate protocol work with main-actor conformers in Swift 6.
terms:
  - term: Delegate protocol
    definition: "A protocol that lists the questions an object asks and the events it reports to one other object, its delegate. The object holds the delegate as a weak, optional property typed as the protocol."
  - term: Optional requirement
    definition: "A protocol requirement a conformer may skip. In Swift it exists only in @objc protocols (@objc optional func), and the caller has to check whether it's implemented. Pure Swift protocols get the same effect with a default implementation in an extension."
  - term: Default implementation
    definition: "A method body in a protocol extension. It satisfies a requirement for any conformer that doesn't write its own."
  - term: Static dispatch
    definition: "Choosing which method body runs from the type the compiler sees, at compile time. A method declared only in a protocol extension (not in the protocol) is dispatched this way, so conformers can't override it through the protocol type."
  - term: Multicast delegate
    definition: "An object that keeps several delegates, usually as an array of boxes that hold each one weakly, and notifies all of them. Not built into Swift or UIKit; you write it."
  - term: Isolated conformance
    definition: "A conformance limited to one global actor, written extension Screen: @MainActor SomeProtocol (SE-0470, Swift 6.2). The type can satisfy a nonisolated protocol with main-actor methods, and the conformance can only be used on the main actor."
mastery:
  - Turn a vague delegate method like didUpdate() into a set of specific will/did/should methods with the sender first.
  - Write a protocol with default implementations for its optional methods and show that a conformer can implement just one of them.
  - Explain, with a running example, why a method declared only in a protocol extension doesn't call the conformer's version.
  - Write a weak-box list that notifies every live listener and drops released ones.
  - Fix the "crosses into main actor-isolated code" error two different ways.
resources: [swift-book-protocols, swift-book-extensions, swift-book-arc, swift-mainactor, uikit-uitextfielddelegate]
cards:
  - id: m26-l01-c1
    front: Three kinds of delegate method, by name?
    back: "should… asks permission and returns Bool (textFieldShouldReturn). will… reports something about to happen. did… reports something that happened. Data-source-style methods ask for a value (numberOfRows). The sender is always the first parameter."
  - id: m26-l01-c2
    front: "@objc optional requirement vs default implementation in an extension?"
    back: "@objc optional: only in @objc protocols, the caller writes delegate?.method?(…) and can tell whether it's implemented. Default implementation: works in any Swift protocol (and with structs), the call is ordinary, but the caller can't tell whether the conformer wrote its own."
  - id: m26-l01-c3
    front: A method exists only in a protocol extension, and a conformer writes its own. Which runs when you call it through the protocol type?
    back: "The extension's. A method that isn't a requirement is statically dispatched, so the conformer's version runs only when the compiler sees the concrete type. Declare it in the protocol to make it customizable."
  - id: m26-l01-c4
    front: Are delegates always weak?
    back: "No. It's the UIKit convention for objects owned by their delegate. URLSession keeps its delegate strongly until the session is invalidated, and CAAnimation retains its delegate. Read the property's documentation."
  - id: m26-l01-c5
    front: "Your @MainActor view controller can't conform to your delegate protocol in Swift 6. Two fixes?"
    back: "Mark the protocol @MainActor (UIKit's choice for UI protocols), or declare an isolated conformance: extension Screen: @MainActor MyDelegate (Swift 6.2). A third, for methods that don't touch UI state: make them nonisolated."
---

## The idea in one sentence

A delegate protocol is a contract between an object and the one object it reports to, and most of the work is in the design: what it asks, what it reports, which methods are optional, and on which actor it runs.

> [!note] About this lesson's code
> You already wrote delegates in Module 22, lesson 5 (`AnyObject`, `weak var delegate`, the sender first, `@MainActor` for UI protocols) and saw why they're weak in Module 13, lesson 2. This lesson goes further. The plain-Swift examples were compiled and run with Swift 6.3; the UIKit blocks are type-checked against the iOS SDK, not run. API declarations quoted here come from Apple's documentation, read in November 2026.

## Designing the protocol

UIKit's delegate protocols follow a small set of rules. They're worth copying because anyone who has used `UITextFieldDelegate` can read yours without the docs.

- **Name methods after what happened, from the sender's point of view.** `should…` asks permission and returns `Bool`. `will…` reports something about to happen. `did…` reports something that happened. A method that returns another value (`numberOfRows`, `heightForRow`) is a question too; when the questions are about content, UIKit puts them in a separate data source protocol.
- **The sender is the first parameter.** `uploadQueue(_:didFinish:)`, not `didFinish(_:)`. One object can then be the delegate of several senders and tell them apart.
- **Pass the values the delegate needs, not your internals.** `didFinish fileName: String` is better than handing over a mutable array that the delegate could change.
- **One protocol, one job.** If some methods are about *what to show* and others about *what happened*, split them. That's why `UITableView` has a `dataSource` and a `delegate`.
- **Decide what happens when nobody answers.** The delegate is optional and weak, so it can be `nil` at any time. A `should…` method needs a safe default.

Here's a model of an upload queue that follows those rules. The delegate decides whether each file may start, hears about each finished file, and hears when the queue is empty:

```swift
protocol UploadQueueDelegate: AnyObject {
    func uploadQueue(_ queue: UploadQueue, shouldStart fileName: String) -> Bool
    func uploadQueue(_ queue: UploadQueue, didFinish fileName: String)
    func uploadQueueDidBecomeEmpty(_ queue: UploadQueue)
}

final class UploadQueue {
    weak var delegate: UploadQueueDelegate?
    private var pending: [String]

    init(files: [String]) {
        pending = files
    }

    func run() {
        while !pending.isEmpty {
            let file = pending.removeFirst()
            guard delegate?.uploadQueue(self, shouldStart: file) ?? true else {
                print("skipped \(file)")
                continue
            }
            delegate?.uploadQueue(self, didFinish: file)
        }
        delegate?.uploadQueueDidBecomeEmpty(self)
    }
}

final class RecordingDelegate: UploadQueueDelegate {
    var calls: [String] = []

    func uploadQueue(_ queue: UploadQueue, shouldStart fileName: String) -> Bool {
        calls.append("shouldStart \(fileName)")
        return !fileName.hasSuffix(".tmp")
    }

    func uploadQueue(_ queue: UploadQueue, didFinish fileName: String) {
        calls.append("didFinish \(fileName)")
    }

    func uploadQueueDidBecomeEmpty(_ queue: UploadQueue) {
        calls.append("empty")
    }
}

let recorder = RecordingDelegate()
let queue = UploadQueue(files: ["a.jpg", "cache.tmp", "b.jpg"])
queue.delegate = recorder
queue.run()
for call in recorder.calls {
    print(call)
}
```

```output
skipped cache.tmp
shouldStart a.jpg
didFinish a.jpg
shouldStart cache.tmp
shouldStart b.jpg
didFinish b.jpg
empty
```

Two things to notice:

- `delegate?.uploadQueue(self, shouldStart: file) ?? true` is the "nobody answered" rule written down. With no delegate, every file uploads. You pick the default that's safe for your object; for a "should delete" question it would be `false`.
- `RecordingDelegate` isn't a screen. It records calls, which is how you test an object that talks through a delegate: plug in a fake, run, and check the log. The queue only knows the protocol, so it can't tell the difference.

## Class-bound, weak, and the exceptions

`weak` needs a class instance, so a protocol used for a weak delegate must be limited to classes with `AnyObject`. Without it, Swift 6.3 refuses the property:

```swift no-compile 'weak' must not be applied to non-class-bound
protocol PickerDelegate {
    func pickerDidChange(_ value: Int)
}

final class Picker {
    weak var delegate: PickerDelegate?
}
```

The full message is `error: 'weak' must not be applied to non-class-bound 'any PickerDelegate'; consider adding a protocol conformance that has a class bound`. The fix is `protocol PickerDelegate: AnyObject`.

Weak is a convention for one common shape: the delegate owns the object (a view controller owns its text field). Some Apple APIs don't follow it, because the object isn't owned by its delegate:

- `URLSession` "keeps a strong reference to the delegate until your app exits or explicitly invalidates the session", and the documentation warns that without `invalidateAndCancel()` or `finishTasksAndInvalidate()` your app leaks memory.
- `CAAnimation.delegate` is retained by the animation, which Apple calls "a rare exception".

Before you assign a delegate, check whether the property is `weak` in its declaration. If it isn't, you're responsible for breaking the reference.

## Optional requirements

UIKit's delegate methods are almost all optional: `UITableViewDelegate` has dozens and you implement two. Swift has two ways to get that.

### @objc optional

The Objective-C way, and the one UIKit's own protocols use. It needs an `@objc` protocol, so it works only with classes and only on Apple platforms:

```swift ios
import UIKit

@MainActor
@objc protocol ColorPickerViewDelegate: AnyObject {
    func colorPicker(_ picker: ColorPickerView, didSelect color: UIColor)
    @objc optional func colorPicker(_ picker: ColorPickerView, shouldSelect color: UIColor) -> Bool
}

final class ColorPickerView: UIView {
    weak var delegate: ColorPickerViewDelegate?

    func userTapped(_ color: UIColor) {
        let allowed = delegate?.colorPicker?(self, shouldSelect: color) ?? true
        guard allowed else { return }
        delegate?.colorPicker(self, didSelect: color)
    }
}

final class ThemeViewController: UIViewController, ColorPickerViewDelegate {
    private let picker = ColorPickerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        view.addSubview(picker)
    }

    func colorPicker(_ picker: ColorPickerView, didSelect color: UIColor) {
        view.backgroundColor = color
    }
}
```

The call site is the interesting part: `delegate?.colorPicker?(self, shouldSelect: color)`. The second `?` asks "is this method implemented?" and the whole expression is `nil` when it isn't, so `?? true` supplies the default. `ThemeViewController` skips the optional method and the code still compiles.

The advantage: the caller **knows** whether the delegate implemented the method, and can behave differently (`UITableView` uses its own row height when `tableView(_:heightForRowAt:)` is missing). The costs: `@objc` limits the protocol to classes, the parameter and return types must be representable in Objective-C (no Swift structs with generics, no enums with associated values), and it doesn't exist on Linux.

### Default implementations

The Swift way: every requirement is required, and a protocol extension provides a body for the ones you want to be optional.

```swift
protocol PlayerDelegate: AnyObject {
    func player(_ player: Player, didReach second: Int)
    func playerShouldLoop(_ player: Player) -> Bool
}

extension PlayerDelegate {
    func player(_ player: Player, didReach second: Int) {}
    func playerShouldLoop(_ player: Player) -> Bool { false }
}

final class Player {
    weak var delegate: PlayerDelegate?
    let length: Int

    init(length: Int) {
        self.length = length
    }

    func play() {
        for second in 1...length {
            delegate?.player(self, didReach: second)
        }
        if delegate?.playerShouldLoop(self) == true {
            print("looping")
        } else {
            print("stopped")
        }
    }
}

final class ProgressLabel: PlayerDelegate {
    func player(_ player: Player, didReach second: Int) {
        print("\(second)/\(player.length)")
    }
}

final class Jukebox: PlayerDelegate {
    func playerShouldLoop(_ player: Player) -> Bool { true }
}

let player = Player(length: 2)
let label = ProgressLabel()
player.delegate = label
player.play()
let jukebox = Jukebox()
player.delegate = jukebox
player.play()
```

```output
1/2
2/2
stopped
looping
```

Each conformer wrote only the method it cares about. `ProgressLabel` gets the default `playerShouldLoop`, which says `false`, so the first run stops. `Jukebox` gets the empty default `player(_:didReach:)`, so the second run prints nothing until it loops.

This works with any Swift type and on every platform, and the call site is an ordinary call. What you lose is knowledge: the player can't tell whether `Jukebox` *chose* to return `false` or never thought about it. That's fine when the default is a real answer. When "not implemented" must mean something different from any value, use an `@objc optional` requirement or return an optional (`-> Int?`, where `nil` means "use your own default").

### The extension trap

A default implementation only stands in for a **requirement**, a method declared in the protocol itself. If a method exists only in the extension, it isn't a requirement, and Swift picks its body from the type it sees at compile time. A conformer can write a method with the same name, but a call through the protocol type never reaches it:

```swift
protocol DownloadDelegate: AnyObject {
    func downloadDidFinish(_ name: String)
}

extension DownloadDelegate {
    func downloadDidFinish(_ name: String) {
        print("default: \(name) finished")
    }

    func downloadDidFail(_ name: String) {
        print("default: \(name) failed")
    }
}

final class DownloadsScreen: DownloadDelegate {
    func downloadDidFinish(_ name: String) {
        print("screen: \(name) finished")
    }

    func downloadDidFail(_ name: String) {
        print("screen: \(name) failed")
    }
}

let screen = DownloadsScreen()
let delegate: any DownloadDelegate = screen
delegate.downloadDidFinish("a.zip")
delegate.downloadDidFail("b.zip")
screen.downloadDidFail("b.zip")
```

```output
screen: a.zip finished
default: b.zip failed
screen: b.zip failed
```

- `downloadDidFinish` is declared in the protocol, so the call goes through the conformance and finds the screen's version.
- `downloadDidFail` lives only in the extension. Through `any DownloadDelegate`, the compiler only knows the extension's body, and that's what runs.
- Called on `screen`, whose type is `DownloadsScreen`, the screen's own method wins.

The object holding the delegate always calls through the protocol type, so in practice the screen's `downloadDidFail` is dead code and nothing warns you. The rule: **every method you want conformers to customize goes in the protocol**, even if the extension gives it a body.

## One delegate, or many

A delegate property holds one object. Assigning a second one replaces the first; there's no list. That's on purpose: a `should…` question needs one answer, and a text field can't ask three objects whether to return.

Sometimes a *report* needs several listeners: a theme change that the sidebar, the editor and the toolbar all care about. You have three options, and this module covers each: a list of weak delegates (here), closures with subscription tokens (lesson 2 and Module 13, lesson 6), or `NotificationCenter` (lesson 3). Lesson 5 compares them.

A list of delegates has to hold each one weakly, or the manager would keep every panel alive forever. An array can't hold weak references directly, so each one goes in a small box:

```swift
protocol ThemeObserver: AnyObject {
    func themeDidChange(to theme: String)
}

final class WeakThemeObserver {
    weak var value: ThemeObserver?

    init(_ value: ThemeObserver) {
        self.value = value
    }
}

final class ThemeManager {
    private var observers: [WeakThemeObserver] = []

    func addObserver(_ observer: ThemeObserver) {
        observers.append(WeakThemeObserver(observer))
    }

    func removeObserver(_ observer: ThemeObserver) {
        observers.removeAll { $0.value === observer }
    }

    func setTheme(_ theme: String) {
        observers.removeAll { $0.value == nil }
        for box in observers {
            box.value?.themeDidChange(to: theme)
        }
    }
}

final class Panel: ThemeObserver {
    let name: String

    init(name: String) {
        self.name = name
    }

    func themeDidChange(to theme: String) {
        print("\(name) uses \(theme)")
    }

    deinit {
        print("\(name) released")
    }
}

let manager = ThemeManager()
let sidebar = Panel(name: "sidebar")
var editor: Panel? = Panel(name: "editor")
manager.addObserver(sidebar)
if let editor {
    manager.addObserver(editor)
}
manager.setTheme("dark")
editor = nil
manager.setTheme("light")
```

```output
sidebar uses dark
editor uses dark
editor released
sidebar uses light
```

- `WeakThemeObserver` holds its panel weakly. The array owns the boxes, not the panels.
- `editor = nil` releases the editor even though the manager still has its box. The box's `value` becomes `nil`.
- `setTheme` drops empty boxes first, then notifies the rest in the order they were added. Without the cleanup the array would grow with every panel that ever existed.
- `removeObserver` compares identities with `===`, which works because the protocol is class-bound.

This is the classic "multicast delegate". It keeps the delegate's strengths (a typed protocol, several methods, the sender can pass rich arguments) and adds many listeners. It doesn't answer questions well: if three observers return different `Bool`s, which one wins? Keep multicast for `did…` reports.

## Delegates and the main actor

UIKit's delegate protocols are `@MainActor`, and so are view controllers. If your protocol isn't, a view controller can't conform to it in Swift 6:

```swift no-compile crosses into main actor-isolated code
protocol PickerDelegate: AnyObject {
    func pickerDidChange(_ value: Int)
}

@MainActor
final class SettingsScreen: PickerDelegate {
    var lastValue = 0

    func pickerDidChange(_ value: Int) {
        lastValue = value
    }
}
```

Swift 6.3 says `error: conformance of 'SettingsScreen' to protocol 'PickerDelegate' crosses into main actor-isolated code and can cause data races`. The protocol promises that anyone, on any thread, can call `pickerDidChange`, but the screen's method may only run on the main actor. There are three ways out:

**1. Make the protocol `@MainActor`.** The right choice when the protocol is about UI and the sender is a view or something else that lives on the main actor. Every caller has to be on the main actor too, which a view already is.

```swift
@MainActor
protocol PickerDelegate: AnyObject {
    func picker(_ picker: Picker, didChangeTo value: Int)
}

@MainActor
final class Picker {
    weak var delegate: PickerDelegate?

    func select(_ value: Int) {
        delegate?.picker(self, didChangeTo: value)
    }
}

@MainActor
final class SettingsScreen: PickerDelegate {
    let picker = Picker()

    init() {
        picker.delegate = self
    }

    func picker(_ picker: Picker, didChangeTo value: Int) {
        print("volume \(value)")
    }
}

let settings = SettingsScreen()
settings.picker.select(7)
```

```output
volume 7
```

Top-level code in `main.swift` runs on the main actor, which is why the last two lines can create a main-actor class and call it directly.

**2. Declare an isolated conformance.** When the protocol isn't yours, or it's used from other places that aren't on the main actor, Swift 6.2 added (SE-0470) a way to say "this type conforms, but only on the main actor":

```swift illustrative
protocol PickerDelegate: AnyObject {
    func pickerDidChange(_ value: Int)
}

@MainActor
final class SettingsScreen {
    var lastValue = 0
}

extension SettingsScreen: @MainActor PickerDelegate {
    func pickerDidChange(_ value: Int) {
        lastValue = value
    }
}
```

The compiler then stops you from using that conformance off the main actor. This block compiled and ran with Swift 6.3 on Linux; it's marked illustrative because the course's macOS runner wasn't used to check it.

**3. Make the methods `nonisolated`.** Only for methods that don't touch the screen's main-actor state, which is rare for a delegate.

What a `@MainActor` protocol means for a sender that runs elsewhere, such as a download on a background thread, is that it must hop to the main actor before calling, with `await`. That's Module 29. For now the rule is the one UIKit follows: views and the protocols they use to talk to view controllers are `@MainActor`.

## Common mistakes

> [!error] error: 'weak' must not be applied to non-class-bound
> The protocol isn't limited to classes. Add `AnyObject` to it (`protocol PickerDelegate: AnyObject`); `weak` can only refer to class instances.

> [!error] A customization point that lives only in the extension
> The conformer writes the method, the sender calls it through the protocol type, and the extension's body runs instead. Declare the method in the protocol; keep the body in the extension as the default.

> [!error] A "should" default that does something dangerous
> `delegate?.shouldDelete(item) ?? true` deletes when nobody is listening. Choose the default that's safe when the delegate is `nil`: usually "no" for destructive actions and "yes" for harmless ones.

> [!error] Expecting two objects to be the delegate
> The second assignment replaces the first, silently. If several objects need the event, use a weak list, closures with tokens or notifications.

> [!error] A strong array of observers
> `var observers: [ThemeObserver] = []` keeps every observer alive as long as the manager lives. For a long-lived manager, that's every screen that ever subscribed. Box each one weakly, or hand out tokens.

> [!error] Assuming every delegate is weak
> `URLSession` keeps its delegate strongly until you invalidate the session. Check the declaration of each framework's delegate property.

## Exercises

````exercise
id: m26-l01-e1
type: prediction
prompt: "A form calls two delegate methods. One is a requirement and one exists only in the extension. What does it print?"
code: |
  protocol FormDelegate: AnyObject {
      func formDidSubmit(_ form: Form)
  }

  extension FormDelegate {
      func formDidSubmit(_ form: Form) { print("default submit") }
      func formDidCancel(_ form: Form) { print("default cancel") }
  }

  final class Form {
      weak var delegate: FormDelegate?
      func submit() { delegate?.formDidSubmit(self) }
      func cancel() { delegate?.formDidCancel(self) }
  }

  final class SignUpScreen: FormDelegate {
      func formDidSubmit(_ form: Form) { print("sign up: submit") }
      func formDidCancel(_ form: Form) { print("sign up: cancel") }
  }

  final class EmptyScreen: FormDelegate {}

  let form = Form()
  let signUp = SignUpScreen()
  let empty = EmptyScreen()
  form.delegate = signUp
  form.submit()
  form.cancel()
  signUp.formDidCancel(form)
  form.delegate = empty
  form.submit()
  form.cancel()
output: |
  sign up: submit
  default cancel
  sign up: cancel
  default submit
  default cancel
hints:
  - "Inside Form, delegate has the type FormDelegate?, not SignUpScreen."
  - "Only formDidSubmit is declared in the protocol."
solution: |
  ```output
  sign up: submit
  default cancel
  sign up: cancel
  default submit
  default cancel
  ```

  `formDidSubmit` is a requirement, so a call through `FormDelegate` finds `SignUpScreen`'s version. `formDidCancel` is only in the extension: through the protocol type the compiler calls the extension's body, so `form.cancel()` prints `default cancel` even though the screen has its own method. Calling `signUp.formDidCancel(form)` directly uses the concrete type, so the screen's method runs. `EmptyScreen` implements nothing, so both calls use the defaults. Moving `func formDidCancel(_ form: Form)` into the protocol would make the second line `sign up: cancel`.
````

````exercise
id: m26-l01-e2
type: prediction
prompt: "A game reports score changes to its delegate. What does it print?"
code: |
  protocol ScoreDelegate: AnyObject {
      func scoreDidChange(to score: Int)
  }

  final class Game {
      weak var delegate: ScoreDelegate?
      var score = 0 {
          didSet { delegate?.scoreDidChange(to: score) }
      }
  }

  final class Display: ScoreDelegate {
      let name: String
      init(_ name: String) { self.name = name }
      func scoreDidChange(to score: Int) { print("\(name): \(score)") }
  }

  let game = Game()
  let hud = Display("hud")
  let scoreboard = Display("scoreboard")
  game.delegate = hud
  game.score += 1
  game.delegate = scoreboard
  game.score += 2
  game.delegate = nil
  game.score += 3
  print(game.score)
output: |
  hud: 1
  scoreboard: 3
  6
hints:
  - "A delegate property holds one object at a time."
  - "The score keeps changing even when nobody is listening."
solution: |
  ```output
  hud: 1
  scoreboard: 3
  6
  ```

  Assigning `scoreboard` replaces `hud`; the game never had two delegates. With `delegate` set to `nil`, `delegate?.scoreDidChange(to:)` does nothing, but the score still becomes 6. If both displays needed every change, the game would need a list of weak observers, closures with tokens, or notifications.
````

````exercise
id: m26-l01-e3
type: comprehension
multiple: true
prompt: "A custom list view needs a row height from its delegate. When the delegate doesn't provide one, the view must measure the row itself, and that's different from any specific height. Which designs let the view tell \"not provided\" apart from a real answer? Select all that apply."
choices:
  - text: "An @objc optional requirement, called as delegate?.listView?(self, heightForRow: row)."
    correct: true
    why: "The optional call returns nil when the method isn't implemented, so the view knows to measure."
  - text: "A requirement that returns Int?, with a default implementation in an extension that returns nil."
    correct: true
    why: "nil means \"use your own\"; any number is a real answer. Works in pure Swift and on every platform."
  - text: "A requirement that returns Int, with a default implementation that returns 44."
    correct: false
    why: "The view can't distinguish the default 44 from a delegate that deliberately returns 44."
  - text: "A method that returns Int, declared only in a protocol extension."
    correct: false
    why: "Calls through the protocol type always run the extension's body, so conformers can't even provide a height."
solution: |
  **The `@objc optional` requirement and the `Int?` requirement.** Both give the view a way to receive "no answer" that no real height can be confused with. The first is what UIKit does (`tableView(_:heightForRowAt:)` is optional), at the price of an `@objc` class-only protocol. The second stays in pure Swift. A plain default value is only right when the default is a real answer you're happy to treat as one.
````

````exercise
id: m26-l01-e4
type: find-errors
prompt: "This delegate design for a photo editor compiles after one fix, but has several problems. Mark every real one."
code: |
  protocol EditorDelegate {
      func didUpdate()
      func shouldDiscardChanges() -> Bool
  }

  extension EditorDelegate {
      func shouldDiscardChanges() -> Bool { true }
      func editorDidExport(_ fileName: String) {}
  }

  final class PhotoEditor {
      weak var delegate: EditorDelegate?
      var layers: [String] = []

      func close() {
          if delegate?.shouldDiscardChanges() ?? true {
              layers.removeAll()
          }
      }

      func export() {
          delegate?.editorDidExport("photo.png")
      }
  }
choices:
  - text: "EditorDelegate isn't class-bound, so weak var delegate doesn't compile."
    correct: true
  - text: "didUpdate() doesn't say what changed or which editor sent it; it should be something like editor(_:didChangeLayerCount:) with the sender first."
    correct: true
  - text: "Discarding changes is the default both when the delegate doesn't implement the method and when there's no delegate; for a destructive action the safe default is false."
    correct: true
  - text: "editorDidExport is only in the extension, so a conformer's version is never called through the protocol."
    correct: true
  - text: "Delegate methods can't return values; shouldDiscardChanges must be a closure."
    correct: false
  - text: "A protocol extension can't contain default implementations for a class-bound protocol."
    correct: false
rubric:
  - Finds the missing AnyObject.
  - Finds the vague didUpdate without a sender.
  - Finds the dangerous true defaults for a destructive question.
  - Finds the extension-only method.
solution: |
  1. **Not class-bound.** `weak` needs `protocol EditorDelegate: AnyObject`.
  2. **`didUpdate()` says nothing.** The delegate has to go and look at the editor to find out what happened. Name the event and pass the sender and the value: `func editor(_ editor: PhotoEditor, didChangeLayerCount count: Int)`.
  3. **Dangerous defaults.** `shouldDiscardChanges` defaults to `true` in the extension, and `?? true` repeats it when there's no delegate. Losing the user's work should require a delegate that says yes: default to `false` in both places, and pass the sender (`editorShouldDiscardChanges(_:)`).
  4. **`editorDidExport` isn't a requirement.** Declare it in the protocol and keep the empty body in the extension; otherwise the view controller's version is dead code.

  Delegate methods returning values is normal (`should…`, data-source questions), and extensions work the same for class-bound protocols.
````

````exercise
id: m26-l01-e5
type: solve
prompt: |
  Write a connectivity monitor that notifies several listeners through a weak list.

  - A class-bound protocol `ConnectivityListener` with `connectivityDidChange(isOnline:)`.
  - A class `ConnectivityMonitor` with `addListener(_:)`, `removeListener(_:)` and `setOnline(_:)`. `setOnline` notifies only when the value actually changes, drops released listeners first, and notifies the rest in the order they were added.
  - A property `listenerCount` that returns how many listeners are still alive.
  - The monitor must never keep a listener alive.

  With this listener class:

  ```swift
  final class Banner: ConnectivityListener {
      let name: String
      init(name: String) { self.name = name }
      func connectivityDidChange(isOnline: Bool) {
          print("\(name): \(isOnline ? "online" : "offline")")
      }
  }
  ```

  this code:

  ```swift
  let monitor = ConnectivityMonitor()
  let feed = Banner(name: "feed")
  var chat: Banner? = Banner(name: "chat")
  monitor.addListener(feed)
  if let chat { monitor.addListener(chat) }
  monitor.setOnline(false)
  monitor.setOnline(false)
  chat = nil
  print(monitor.listenerCount)
  monitor.setOnline(true)
  monitor.removeListener(feed)
  monitor.setOnline(false)
  print(monitor.listenerCount)
  ```

  should print:

  ```plaintext
  feed: offline
  chat: offline
  1
  feed: online
  0
  ```
starter: |
  protocol ConnectivityListener: AnyObject {
      func connectivityDidChange(isOnline: Bool)
  }

  final class ConnectivityMonitor {
      // your code
  }
hints:
  - "Store boxes: final class WeakListener { weak var value: ConnectivityListener? }."
  - "Start with isOnline = true and return early from setOnline when the value is the same."
  - "listenerCount can count the boxes whose value isn't nil."
rubric:
  - Listeners are held weakly through a box; the array never holds them strongly.
  - Released listeners are dropped and not counted.
  - setOnline ignores repeated values.
  - removeListener compares identity with ===.
  - The output matches.
solution: |
  ```swift
  protocol ConnectivityListener: AnyObject {
      func connectivityDidChange(isOnline: Bool)
  }

  final class WeakListener {
      weak var value: ConnectivityListener?

      init(_ value: ConnectivityListener) {
          self.value = value
      }
  }

  final class ConnectivityMonitor {
      private var listeners: [WeakListener] = []
      private var isOnline = true

      var listenerCount: Int {
          listeners.filter { $0.value != nil }.count
      }

      func addListener(_ listener: ConnectivityListener) {
          listeners.append(WeakListener(listener))
      }

      func removeListener(_ listener: ConnectivityListener) {
          listeners.removeAll { $0.value === listener }
      }

      func setOnline(_ online: Bool) {
          guard online != isOnline else { return }
          isOnline = online
          listeners.removeAll { $0.value == nil }
          for box in listeners {
              box.value?.connectivityDidChange(isOnline: online)
          }
      }
  }

  final class Banner: ConnectivityListener {
      let name: String
      init(name: String) { self.name = name }
      func connectivityDidChange(isOnline: Bool) {
          print("\(name): \(isOnline ? "online" : "offline")")
      }
  }

  let monitor = ConnectivityMonitor()
  let feed = Banner(name: "feed")
  var chat: Banner? = Banner(name: "chat")
  monitor.addListener(feed)
  if let chat { monitor.addListener(chat) }
  monitor.setOnline(false)
  monitor.setOnline(false)
  chat = nil
  print(monitor.listenerCount)
  monitor.setOnline(true)
  monitor.removeListener(feed)
  monitor.setOnline(false)
  print(monitor.listenerCount)
  ```

  ```output
  feed: offline
  chat: offline
  1
  feed: online
  0
  ```

  The second `setOnline(false)` returns early, so nobody hears a change that didn't happen. After `chat = nil`, chat's box is empty: `listenerCount` doesn't count it, and the next `setOnline` removes it. `removeListener(feed)` leaves no listeners, so the last change reaches nobody. In an app this monitor would also be `@MainActor` if its listeners are screens.
````

````exercise
id: m26-l01-e6
type: design
prompt: |
  You're writing a reusable `CodeEntryView`: six boxes where the user types a one-time code. Design its delegate protocol (or protocols). Decide:

  1. Which events it reports and which questions it asks, with method names.
  2. Which methods are optional, and how you make them optional.
  3. Whether anything belongs in a separate data source.
  4. Its actor isolation and how the view stores the delegate.
rubric:
  - Methods follow should/will/did naming with the view as the first parameter.
  - Reports at least "did complete with code" and a change event; asks at least one sensible question (should accept a character, or similar) with a safe default.
  - Optional methods are made optional with default implementations (or @objc optional), and the choice is justified.
  - The protocol is @MainActor and AnyObject; the property is weak and optional.
  - Explains whether a data source is needed (it usually isn't: the view's content is what the user typed).
solution: |
  A good answer:

  ```swift ios
  import UIKit

  @MainActor
  protocol CodeEntryViewDelegate: AnyObject {
      func codeEntryView(_ view: CodeEntryView, didComplete code: String)
      func codeEntryView(_ view: CodeEntryView, didChangeText text: String)
      func codeEntryView(_ view: CodeEntryView, shouldAccept character: Character) -> Bool
  }

  extension CodeEntryViewDelegate {
      func codeEntryView(_ view: CodeEntryView, didChangeText text: String) {}
      func codeEntryView(_ view: CodeEntryView, shouldAccept character: Character) -> Bool {
          character.isNumber
      }
  }

  final class CodeEntryView: UIView {
      weak var delegate: CodeEntryViewDelegate?
      private(set) var text = ""

      func insert(_ character: Character) {
          guard text.count < 6 else { return }
          guard delegate?.codeEntryView(self, shouldAccept: character) ?? character.isNumber else { return }
          text.append(character)
          delegate?.codeEntryView(self, didChangeText: text)
          if text.count == 6 {
              delegate?.codeEntryView(self, didComplete: text)
          }
      }
  }
  ```

  - **Reports:** `didComplete` is the one every screen needs, so it's required. `didChangeText` lets a screen enable a button or clear an error, and is optional.
  - **Asks:** `shouldAccept` filters input; the default (digits only) is a real answer, so a default implementation is the right kind of optional, and it's declared in the protocol so conformers can override it.
  - **No data source:** the content is what the user typed, not something the view has to ask for. A data source would make sense if the view showed content it doesn't own (a variable number of boxes from a server config, say), and even then a property is simpler.
  - **Isolation and storage:** `@MainActor` because a view and its controller live there; `AnyObject` and `weak var delegate` because the controller owns the view.
````

## Summary

- Design delegate methods like UIKit's: `should…` asks, `will…`/`did…` report, data questions go in a data source, the sender comes first, and the arguments are values, not your internals. Decide what happens when the delegate is `nil`, and make that default safe.
- `weak` requires a class-bound protocol (`AnyObject`). Weak is UIKit's convention, not a law: `URLSession` and `CAAnimation` keep their delegates strongly.
- Optional requirements: `@objc optional` lets the caller detect "not implemented" (`delegate?.method?(…)`) but needs an `@objc`, class-only protocol. Default implementations in an extension work everywhere but hide whether the conformer wrote its own.
- A method that exists only in a protocol extension is statically dispatched: conformers can't override it through the protocol type. Declare every customization point in the protocol.
- A delegate is one-to-one. For several listeners of a `did…` event, keep a list of weak boxes and drop the empty ones, or use closures with tokens or notifications.
- In Swift 6, a main-actor view controller can't satisfy a nonisolated protocol. Make UI delegate protocols `@MainActor`; for a protocol you don't own, an isolated conformance (`extension Screen: @MainActor P`, Swift 6.2) or `nonisolated` methods are the alternatives.
