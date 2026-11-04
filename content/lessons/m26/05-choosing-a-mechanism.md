---
id: m26-l05
title: Choosing a communication mechanism
description: Pick the right way for two parts of an app to talk. You compare target-action, delegates, data sources, closures, NotificationCenter and key-value observing by direction, number of listeners, whether an answer comes back, lifetime and isolation, get a first look at async sequences and Observation, and refactor a screen that broadcasts everything into one that uses the narrowest mechanism for each event.
module: m26
order: 5
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l04]
objectives:
  - Choose a mechanism for an event by asking who knows whom, how many listeners there are, whether an answer is needed and how long the connection lives.
  - Explain what each of target-action, delegate, data source, closure, NotificationCenter and KVO is for, and what it costs.
  - Recognize the symptoms of an over-notified screen and refactor it to direct communication.
  - Describe where async sequences and Observation fit, as previews of later modules.
terms:
  - term: Direct communication
    definition: "The sender holds a reference to a specific listener (a target, a delegate, a closure) and calls it. Easy to follow in code, one-to-one, and checked by the compiler."
  - term: Broadcast
    definition: "The sender announces an event to whoever registered for it, without knowing them (NotificationCenter). One-to-many and decoupled, and harder to trace."
  - term: Key-value observing (KVO)
    definition: "An Objective-C runtime mechanism that reports changes to a property of an NSObject subclass marked @objc dynamic. In Swift you call observe(_:options:changeHandler:) and keep the returned NSKeyValueObservation."
  - term: Over-notification
    definition: "Using NotificationCenter for events that have one obvious sender and one obvious receiver. Symptoms: notification names that mention a specific screen, observers that check who posted, and reactions in screens that weren't involved."
mastery:
  - Fill in a decision table for a new screen's events and justify each choice in one sentence.
  - Point at a notification in existing code and say whether it should be a delegate, a closure or stay a notification.
  - Refactor a child-to-parent notification into a delegate or closure and show that unrelated screens stop reacting.
  - Name the limits of each mechanism (one listener, no answer, no compile-time check, no ordering, lifetime management).
resources: [uikit-target-action, swift-book-protocols, swift-book-closures, swift-mainactor]
cards:
  - id: m26-l05-c1
    front: Four questions for choosing a communication mechanism?
    back: "Does the sender know the receiver (direct) or not (broadcast)? One listener or many? Does the sender need an answer back? How long does the connection live, and who ends it? Plus, in Swift 6: on which actor does it run?"
  - id: m26-l05-c2
    front: When is NotificationCenter the right choice?
    back: "When the event is app-wide or comes from the system, there may be any number of listeners, and the sender shouldn't know about them: user logged out, app became active, settings changed. Not for a child telling its parent something."
  - id: m26-l05-c3
    front: Delegate or closure for a child view's events?
    back: "A closure for one or two events, especially when the wiring sits next to the reaction. A delegate when there are several related events or questions (should…), or when the same object serves several senders."
  - id: m26-l05-c4
    front: What does KVO need, and what does observe(_:options:changeHandler:) return?
    back: "An NSObject subclass with the property marked @objc dynamic (or a system property documented as KVO-compliant). It returns an NSKeyValueObservation; observation stops when that object is deinitialized or invalidated, so you store it."
  - id: m26-l05-c5
    front: Symptoms of an over-notified screen?
    back: "Notification names that mention one screen (profileAvatarTapped), observers that check notification.object to see if it's theirs, screens reacting to events from other screens, and nobody able to find the receiver without a project-wide search."
---

## The idea in one sentence

There's no best communication mechanism, only the narrowest one that fits the event: as direct as the relationship allows, with exactly as many listeners as the event really has.

> [!note] About this lesson's code
> The plain-Swift blocks were compiled and run with Swift 6.3. UIKit and KVO code is type-checked against the iOS SDK, not run. The async sequence and Observation snippets are previews of Modules 29 and 31 and are marked illustrative: they aren't checked here.

## Four questions

Before picking a mechanism, answer these about the event:

1. **Does the sender know the receiver?** A view controller knows the view it created; the view shouldn't know the controller's type; a network monitor knows nobody.
2. **How many listeners?** Exactly one (the owner), a few known ones, or any number of unknown ones.
3. **Does the sender need an answer?** "Should I return?" and "how many rows?" need one. "The user tapped Save" doesn't.
4. **How long does the connection live, and who ends it?** For the life of a view, until one request finishes, or until someone explicitly unsubscribes.

In Swift 6 there's a fifth: **on which actor does it run?** A mechanism that delivers on any thread forces you to handle isolation at every receiver (lesson 3).

## The table

| Mechanism | Direction and count | Answer back? | Lifetime | Typical use |
| --- | --- | --- | --- | --- |
| Target-action / `UIAction` | Control → one handler per action | No | While the control lives; the target isn't retained, `UIAction` closures are | A button, switch or slider reporting an interaction |
| Delegate | Object → one known protocol conformer | Yes (`should…`) | Weak reference; ends when the delegate goes away | A view or component that asks questions and reports several related events |
| Data source | Object → one provider of content | Yes, that's the point | Like a delegate | A list asking what to display (or a diffable data source, which you hand the data instead) |
| Closure | Object → one callback per property | Can return a value | As long as it's stored; you choose the captures | One or two events from a child, a completion handler, a cell's button |
| `NotificationCenter` | Anyone → any number of unknown observers | No | Until the observer is removed (or its token discarded, iOS 26 messages) | App-wide or system events: logged out, became active, keyboard, settings changed |
| KVO | Observed object → any number of observers | No | Until the `NSKeyValueObservation` is released or invalidated | Watching a property of an Apple object that documents KVO support |
| Async sequence | Producer → a consuming task | No | Until the task ends or is cancelled | A stream of values consumed in order (Module 29) |
| Observation (`@Observable`) | Model → whatever reads its properties | No | Tracking is per read | Model-to-UI updates, especially in SwiftUI (Module 31) |

Read the table left to right as "how wide does this event really need to go?" Most events in a screen are one-to-one and known: target-action, delegates and closures cover them, and the compiler checks every connection. Broadcasting is for the few events that really are everyone's business.

### Target-action, delegates and data sources

You know these from Module 22, lesson 5, Module 24, and lesson 1. The short version: controls use actions; anything that asks questions uses a delegate; anything that asks for content uses a data source. Their protocols and selectors make the connection visible: "jump to definition" on `delegate` or on the action method leads to the receiver.

### Closures

Closures win when the event is small and the reaction belongs next to the wiring: `cell.onFavoriteTapped = { [weak self] in … }` in `cellForRowAt`, a completion handler for one request, a `UIAction`. They lose when there are many events (five closure properties are a protocol in disguise) or when the sender needs to hand the same object to several owners.

### NotificationCenter

Use it when the sender can't or shouldn't know who cares, and when the number of listeners is open-ended. The system uses it for exactly that: app lifecycle, keyboard frames, locale changes. The price is that nothing connects the post to its observers except a name: no compiler check that anyone listens, no defined order, `userInfo` without types (before iOS 26), and lifetime management on every observer.

### Key-value observing

KVO reports changes to a property of an `NSObject` subclass. Apple's article "Using Key-Value Observing in Swift" lists the requirement: you "can only use key-value observing with classes that inherit from `NSObject`", and your own properties must be marked `@objc dynamic`. You call `observe(_:options:changeHandler:)` and keep the `NSKeyValueObservation` it returns; Apple's documentation for that method says observation stops "when the returned NSKeyValueObservation is deinited or invalidated."

Today you'll mostly meet it for Apple objects that document KVO support (some AVFoundation and WebKit properties, `Progress`), and in older code. For your own Swift types, prefer a delegate, a closure or Observation. Here's the shape, with a progress object you define:

```swift ios
import UIKit

final class ExportProgress: NSObject {
    @objc dynamic var fractionCompleted = 0.0
}

final class ExportViewController: UIViewController {
    private let progress = ExportProgress()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var observation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(progressView)
        observation = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
            let fraction = Float(change.newValue ?? 0)
            MainActor.assumeIsolated {
                self?.progressView.progress = fraction
            }
        }
    }
}
```

The change handler is declared `@Sendable`, like the notification block, so it extracts a `Float` and enters `MainActor.assumeIsolated`; that's only correct if the property changes on the main thread. The `observation` property ties the observation to the controller's lifetime.

### Previews: async sequences and Observation

Two newer mechanisms will replace some of these in later modules. You don't need them yet; recognize them when you see them.

**Async sequences** deliver values one at a time to a task that loops with `for await`. Notifications can be read this way since iOS 15:

```swift illustrative
for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
    refresh()
}
```

The loop is the observer, and it ends when its task is cancelled, so there's no token to remove. Tasks, cancellation and isolation come first, in Module 29.

**Observation** (the `@Observable` macro, iOS 17) makes a model's properties trackable: code that reads them, such as a SwiftUI view's `body`, is updated when they change, with no protocol, closure or notification:

```swift illustrative
@Observable
final class CartModel {
    var itemCount = 0
}
```

UIKit gained support for it too, and it's the standard model-to-view mechanism in SwiftUI (Module 31).

## Refactoring an over-notified screen

Notifications are tempting because they need no wiring: post here, observe there, done. Used for everything, they create bugs that are hard to find. Here's a profile screen whose avatar view posts a notification when tapped, and the screen observes it:

```swift
import Foundation

extension Notification.Name {
    static let avatarTapped = Notification.Name("AvatarTapped")
}

@MainActor
final class Log {
    private var lines: [String] = []

    func add(_ line: String) {
        lines.append(line)
    }

    func flush() {
        for line in lines.sorted() {
            print(line)
        }
        lines = []
    }
}

final class AvatarView {
    private let center: NotificationCenter

    init(center: NotificationCenter) {
        self.center = center
    }

    func tap() {
        center.post(name: .avatarTapped, object: nil)
    }
}

@MainActor
final class ProfileScreen {
    let name: String
    let avatar: AvatarView
    private let log: Log
    private var observer: (any NSObjectProtocol)?

    init(name: String, center: NotificationCenter, log: Log) {
        self.name = name
        self.log = log
        avatar = AvatarView(center: center)
        observer = center.addObserver(forName: .avatarTapped, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showPhotoPicker()
            }
        }
    }

    func showPhotoPicker() {
        log.add("\(name) shows the photo picker")
    }
}

let center = NotificationCenter()
let log = Log()
let mine = ProfileScreen(name: "my profile", center: center, log: log)
let friend = ProfileScreen(name: "friend's profile", center: center, log: log)
mine.avatar.tap()
log.flush()
```

```output
friend's profile shows the photo picker
my profile shows the photo picker
```

(The log is sorted because the center doesn't define delivery order.) Tapping **my** avatar opened a photo picker on the friend's profile too, which is pushed underneath in the navigation stack. The usual "fix" is to pass `object: avatar` on both sides, and that works, but look at what the code has become: a broadcast system used to connect two objects that already know each other, since the screen created the avatar view.

The symptoms to look for in a real codebase:

- Notification names that mention a specific screen or view (`profileAvatarTapped`, `checkoutSaveButtonPressed`).
- Observers that check `notification.object` or a `userInfo` field to decide whether the event is "theirs".
- Bugs where an event in one screen changes another.
- To find out who reacts to something, you have to search the whole project for a string.

The fix is to use the narrowest mechanism for each event. The avatar's owner is known and unique, so a delegate (or a closure) is enough:

```swift
@MainActor
protocol AvatarViewDelegate: AnyObject {
    func avatarViewDidTap(_ avatarView: AvatarView)
}

@MainActor
final class AvatarView {
    weak var delegate: AvatarViewDelegate?

    func tap() {
        delegate?.avatarViewDidTap(self)
    }
}

@MainActor
final class ProfileScreen: AvatarViewDelegate {
    let name: String
    let avatar = AvatarView()

    init(name: String) {
        self.name = name
        avatar.delegate = self
    }

    func avatarViewDidTap(_ avatarView: AvatarView) {
        print("\(name) shows the photo picker")
    }
}

let mine = ProfileScreen(name: "my profile")
let friend = ProfileScreen(name: "friend's profile")
mine.avatar.tap()
```

```output
my profile shows the photo picker
```

Only the screen that owns the avatar reacts. The connection is visible (`avatar.delegate = self`), there's no observer to remove, and no ordering question, because there's one listener. "Jump to definition" on `avatarViewDidTap` lists exactly who implements it.

What **should** stay a notification in the same app? Saving the profile changes the user's name, and the home screen header, the settings screen and the chat list all show it. Those screens don't know about the profile screen, there are several of them, and more may come. That's a broadcast: one `profileDidChange` notification (or, on iOS 26, a `MainActorMessage`), posted by whatever owns the user's data, not by a view.

A useful default for a screen:

- **Controls → screen:** `UIAction` or target-action.
- **Child views and child screens → owner:** a delegate if it asks questions or has several events, a closure otherwise.
- **Lists → their content:** a data source (or a diffable data source fed by the screen).
- **Model or service → the screens that display it:** a delegate or closure when there's one consumer; notifications (later, Observation) when there are many.
- **The system → anyone:** the notifications the system defines.

## Common mistakes

> [!error] A notification for a child-to-parent event
> The parent already knows the child. A delegate or closure is typed, one-to-one and visible; a notification can be heard by every other instance of the parent.

> [!error] A delegate for an app-wide event
> A session manager with a single `delegate` can tell only one screen that the user logged out. When there are several unknown listeners, broadcast.

> [!error] Five closure properties on one view
> `onTap`, `onLongPress`, `onDelete`, `onShare`, `onEdit`… When a child has several related events, a protocol groups them, documents them and lets one object handle them all.

> [!error] KVO on your own Swift types
> It forces `NSObject` and `@objc dynamic`, its handler is `@Sendable`, and it can't observe plain Swift properties. Use a delegate, a closure, or Observation.

> [!error] Choosing by convenience instead of by relationship
> "A notification is easier to add" is true for the first hour. Ask the four questions; the mechanism usually follows from the answers.

## Exercises

````exercise
id: m26-l05-e1
type: comprehension
prompt: "A reusable DatePickerView needs to ask its owner whether a given date can be selected, and to report the selected date. Which mechanism fits best?"
choices:
  - text: "A delegate protocol with a should… method and a did… method."
    correct: true
    why: "It asks a question that needs an answer and reports a related event, to one known owner."
  - text: "A notification posted for each date the view wants to check."
    correct: false
    why: "Notifications can't return an answer, and every observer in the app would hear the question."
  - text: "Key-value observing of a selectedDate property."
    correct: false
    why: "KVO reports changes; it can't ask whether a date is allowed, and it needs NSObject and @objc dynamic."
  - text: "Target-action on .valueChanged only."
    correct: false
    why: "It can report that the value changed, but it can't ask the owner a question before the selection happens."
solution: |
  **A delegate.** The view needs an answer (`datePicker(_:shouldSelect:) -> Bool`) and reports an event (`datePicker(_:didSelect:)`) to one owner it doesn't know the type of. That's what delegates are for. A closure property could do the question too (`var canSelect: ((Date) -> Bool)?`), but with two related members a protocol keeps them together.
````

````exercise
id: m26-l05-e2
type: prediction
prompt: "Two document screens observe a notification posted by their own toolbar, one of them with an object filter. What does it print?"
code: |
  import Foundation

  extension Notification.Name {
      static let saveTapped = Notification.Name("SaveTapped")
  }

  final class Toolbar {
      let center: NotificationCenter
      init(center: NotificationCenter) { self.center = center }
      func tapSave() { center.post(name: .saveTapped, object: self) }
  }

  final class DocumentScreen {
      let toolbar: Toolbar
      var token: (any NSObjectProtocol)?
      init(name: String, center: NotificationCenter, filtered: Bool) {
          toolbar = Toolbar(center: center)
          token = center.addObserver(forName: .saveTapped, object: filtered ? toolbar : nil, queue: nil) { _ in
              print("\(name) saves")
          }
      }
  }

  let center = NotificationCenter()
  let notes = DocumentScreen(name: "notes", center: center, filtered: true)
  notes.toolbar.tapSave()
  let todo = DocumentScreen(name: "todo", center: center, filtered: false)
  todo.toolbar.tapSave()
  center.removeObserver(todo.token!)
  notes.toolbar.tapSave()
  center.removeObserver(notes.token!)
output: |
  notes saves
  todo saves
  notes saves
hints:
  - "notes only hears its own toolbar. todo hears every toolbar."
  - "When todo's toolbar posts, does notes' filter match?"
solution: |
  ```output
  notes saves
  todo saves
  notes saves
  ```

  When notes taps Save, todo doesn't exist yet. When todo's toolbar posts, notes' filter (its own toolbar) doesn't match, and todo, which observes with `object: nil`, hears it. After todo's observer is removed, notes' second tap reaches only notes. Each post reaches at most one observer here, so the order is well defined. The bug is waiting: while todo is still registered, a tap in notes would also make todo save. A delegate or closure from each toolbar to its own screen can't have that bug.
````

````exercise
id: m26-l05-e3
type: design
prompt: |
  Choose a mechanism for each event in a music app and justify it in one sentence each.

  1. The Play button on the now-playing screen.
  2. A track cell's "more" button, which needs to tell the list screen which track it belongs to.
  3. The playback engine reports the current time every half second to the now-playing screen, the mini player at the bottom of every tab, and the lock-screen controller.
  4. The user signs out; every tab must reset.
  5. A custom equalizer view asks its owner whether a preset can be applied (some require a subscription) and reports the applied preset.
  6. The app returns to the foreground and the library should refresh.
rubric:
  - Play button uses UIAction or target-action.
  - The cell uses a closure capturing the track id (or a delegate with the cell as sender), not an index.
  - Playback time goes to several listeners with a broadcast or a multicast, and the answer mentions lifetime or isolation.
  - Sign-out is a notification (or iOS 26 message) posted by the session owner.
  - The equalizer uses a delegate because it asks and reports.
  - Foreground uses the system notification (or its iOS 26 message).
solution: |
  1. **`UIAction`** on `.primaryActionTriggered`: one control, one interaction.
  2. **A closure** set in `cellForRowAt`: `cell.onMore = { [weak self] in self?.showMenu(for: track.id) }`, capturing the track's identifier, not the index path.
  3. **Several known listeners, high frequency:** a multicast delegate with weak boxes, or a notification posted on the main actor. With a notification, each listener must remove its registration and handle isolation; a multicast list on a `@MainActor` engine keeps it typed. (Later: an async sequence or an `@Observable` playback model.)
  4. **A notification**, such as `sessionDidEnd`, posted by the session manager. The tabs don't know the session manager's internals and new tabs can subscribe.
  5. **A delegate** with `equalizer(_:shouldApply:) -> Bool` and `equalizer(_:didApply:)`: a question with an answer plus a related event, to one owner.
  6. **The system's `UIApplication.didBecomeActiveNotification`** (or `DidBecomeActiveMessage` on iOS 26), observed by the library screen with `[weak self]` and removed when the screen goes away.
````

````exercise
id: m26-l05-e4
type: refactor
prompt: "This checkout screen uses notifications for everything. Refactor it: keep notifications only where they belong, and say which mechanism replaces each of the others."
code: |
  extension Notification.Name {
      static let couponFieldDidChange = Notification.Name("CouponFieldDidChange")
      static let payButtonTapped = Notification.Name("PayButtonTapped")
      static let addressFormShouldValidate = Notification.Name("AddressFormShouldValidate")
      static let orderDidComplete = Notification.Name("OrderDidComplete")
  }

  // CouponView posts couponFieldDidChange with userInfo["text"] on every keystroke.
  // PayButtonView posts payButtonTapped.
  // CheckoutViewController posts addressFormShouldValidate and waits for AddressFormView
  //   to post back "addressFormDidValidate" with userInfo["isValid"].
  // CheckoutViewController posts orderDidComplete; the cart badge, the order history
  //   screen and the analytics service observe it.
rubric:
  - Coupon text changes become UIAction on .editingChanged or a closure/delegate from CouponView to its owner.
  - The pay button becomes UIAction or target-action.
  - The validation round trip becomes a direct call or a delegate/data-source-style question that returns a value.
  - orderDidComplete stays a notification (or iOS 26 message) because it has several unrelated listeners.
  - Explains at least one concrete bug the original design allows (another checkout instance reacting, a typo in a key, no answer if nobody observes).
solution: |
  - **`couponFieldDidChange` → a closure or `UIAction`.** The controller owns the coupon view. Either the view exposes `var onTextChange: ((String) -> Void)?` (fed by `UIAction` on `.editingChanged` inside the view), or the controller attaches a `UIAction` to the field directly. Typed, no `userInfo["text"]`.
  - **`payButtonTapped` → `UIAction`** on `.primaryActionTriggered`. A button reporting a tap is what target-action is for.
  - **The validation round trip → a direct call.** The controller wants an answer, and notifications can't return one; the post-and-wait dance fails silently if the form isn't listening. The controller owns the form, so `let isValid = addressForm.validate()` is enough. If the form must ask the controller something instead, that's a delegate method returning `Bool`.
  - **`orderDidComplete` stays a notification.** The badge, history and analytics don't know the checkout screen, there are several of them, and more may come. Post it from whatever completes the order (a service, not a view), with a typed payload helper, or as a `MainActorMessage` on iOS 26.

  Bugs the original allows: with two checkout screens alive (one under a modal, say), a keystroke or a tap in one triggers the other; a misspelled `userInfo` key turns the coupon into `nil`; if the address form isn't loaded, the controller waits for a validation answer that never comes.
````

````exercise
id: m26-l05-e5
type: solve
prompt: |
  Rewrite this over-notified player so the play button talks to its own screen directly, while "now playing changed" stays a broadcast that a mini player hears.

  Requirements:

  - `PlayButton` gets a closure property `onTap: (() -> Void)?` and calls it in `tap()`; no notification.
  - `PlayerScreen(trackName:center:)` owns a button, sets `onTap` with `[weak self]`, and in `play()` prints `playing <track>` and posts `.nowPlayingDidChange` on its center with the track name in `userInfo["track"]`.
  - `MiniPlayer(center:)` observes `.nowPlayingDidChange` and prints `mini player: <track>`. Its observer block doesn't capture anything that isn't `Sendable` (it can just print).

  This code:

  ```swift
  let center = NotificationCenter()
  let mini = MiniPlayer(center: center)
  let jazz = PlayerScreen(trackName: "So What", center: center)
  let rock = PlayerScreen(trackName: "Paranoid", center: center)
  jazz.button.tap()
  rock.button.tap()
  mini.stop()
  jazz.button.tap()
  ```

  should print:

  ```plaintext
  playing So What
  mini player: So What
  playing Paranoid
  mini player: Paranoid
  playing So What
  ```
starter: |
  import Foundation

  extension Notification.Name {
      static let nowPlayingDidChange = Notification.Name("NowPlayingDidChange")
  }

  // your code
hints:
  - "final class PlayButton { var onTap: (() -> Void)?; func tap() { onTap?() } }"
  - "PlayerScreen's init: button.onTap = { [weak self] in self?.play() } after storing the other properties."
  - "MiniPlayer stores the token and has a stop() that removes it."
rubric:
  - The button reaches only its own screen, through a closure captured weakly.
  - nowPlayingDidChange is posted by the screen when it plays and observed by the mini player.
  - The mini player's registration is removed in stop().
  - The output matches.
solution: |
  ```swift
  import Foundation

  extension Notification.Name {
      static let nowPlayingDidChange = Notification.Name("NowPlayingDidChange")
  }

  final class PlayButton {
      var onTap: (() -> Void)?

      func tap() {
          onTap?()
      }
  }

  final class PlayerScreen {
      let trackName: String
      let button = PlayButton()
      private let center: NotificationCenter

      init(trackName: String, center: NotificationCenter) {
          self.trackName = trackName
          self.center = center
          button.onTap = { [weak self] in
              self?.play()
          }
      }

      func play() {
          print("playing \(trackName)")
          center.post(name: .nowPlayingDidChange, object: self, userInfo: ["track": trackName])
      }
  }

  final class MiniPlayer {
      private let center: NotificationCenter
      private var token: (any NSObjectProtocol)?

      init(center: NotificationCenter) {
          self.center = center
          token = center.addObserver(forName: .nowPlayingDidChange, object: nil, queue: nil) { notification in
              let track = notification.userInfo?["track"] as? String ?? "?"
              print("mini player: \(track)")
          }
      }

      func stop() {
          if let token {
              center.removeObserver(token)
          }
          token = nil
      }
  }

  let center = NotificationCenter()
  let mini = MiniPlayer(center: center)
  let jazz = PlayerScreen(trackName: "So What", center: center)
  let rock = PlayerScreen(trackName: "Paranoid", center: center)
  jazz.button.tap()
  rock.button.tap()
  mini.stop()
  jazz.button.tap()
  ```

  ```output
  playing So What
  mini player: So What
  playing Paranoid
  mini player: Paranoid
  playing So What
  ```

  Tapping jazz's button can only play jazz: the closure is the only connection, and it points at one screen. "Now playing changed" is genuinely app-wide (a mini player, a lock-screen controller, maybe analytics), so it stays a notification, posted with the screen as `object` in case an observer wants to filter. The mini player's block only prints, so it captures nothing; once `stop()` removes it, the third tap isn't broadcast to anyone.
````

````exercise
id: m26-l05-e6
type: explain
prompt: "Explain to a teammate why a KVO observation like the one below needs the observation stored in a property, why the handler uses MainActor.assumeIsolated, and when you'd use KVO at all in new code."
code: |
  observation = progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
      let fraction = Float(change.newValue ?? 0)
      MainActor.assumeIsolated {
          self?.progressView.progress = fraction
      }
  }
rubric:
  - Observation stops when the NSKeyValueObservation is deinitialized or invalidated, so it must be stored for as long as you want updates.
  - The change handler is @Sendable, so main-actor state is reached through assumeIsolated (only valid if the change happens on the main thread) or another hop.
  - "[weak self] because the observation (owned by self) owns the handler."
  - KVO requires NSObject and @objc dynamic; in new code it's for Apple objects documented as KVO-compliant, while your own types use delegates, closures or Observation.
solution: |
  `observe(_:options:changeHandler:)` returns an `NSKeyValueObservation`, and Apple's documentation says observation stops "when the returned NSKeyValueObservation is deinited or invalidated." Without the property, the token would be released at the end of the statement and you'd never get an update. Storing it in the controller also gives the observation the controller's lifetime, which is why the handler captures `[weak self]`: the controller owns the observation, the observation owns the handler.

  The handler is declared `@Sendable`, so like a notification block it can't touch the main-actor progress view directly. It pulls out a `Float` and uses `MainActor.assumeIsolated`, which is correct only if `fractionCompleted` changes on the main thread; if it can change elsewhere, hop with a `Task { @MainActor in … }` instead (Module 29).

  KVO needs an `NSObject` subclass and `@objc dynamic` properties, so in new code you use it for Apple objects that document KVO support, such as `Progress` or some AVFoundation and WebKit properties. For your own types, a delegate, a closure or an `@Observable` model is simpler and fully typed.
````

## Summary

- Choose by the shape of the event: does the sender know the receiver, how many listeners, does it need an answer, how long does the connection live, and on which actor does it run.
- Controls use target-action or `UIAction`. Components that ask questions or report several related events use delegates; components that need content use data sources. One or two events from a child use closures.
- `NotificationCenter` is for app-wide and system events with open-ended listeners. It costs type safety (before iOS 26 messages), ordering and lifetime management.
- KVO watches `@objc dynamic` properties of `NSObject` subclasses; keep the `NSKeyValueObservation`. Use it for Apple objects that support it, not for your own types.
- Async sequences (Module 29) and Observation (Module 31) are the newer tools for streams of values and model-to-view updates.
- An over-notified screen shows itself through screen-specific notification names, observers that check who posted, and events that leak into other screens. Replace those notifications with the narrowest direct mechanism, and keep broadcasts for events that really are everyone's.
