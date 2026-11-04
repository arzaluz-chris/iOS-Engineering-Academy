---
id: m26-l03
title: NotificationCenter
description: Broadcast an event to any number of observers that the sender doesn't know. You define notification names, post with and without userInfo, observe with the block-based API and remove the registration, filter by sender with the object parameter, wrap userInfo in typed helpers, handle Swift 6's Sendable observer closures from main-actor code, and meet the typed MainActorMessage and AsyncMessage APIs that iOS 26 added.
module: m26
order: 3
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l02]
objectives:
  - Define a notification name, post a notification and observe it with addObserver(forName:object:queue:using:).
  - Explain that post delivers synchronously to observers registered with a nil queue.
  - Remove a block-based observer, and tie its lifetime to an owner with a token object.
  - Filter notifications by sender with the object parameter.
  - Replace raw userInfo dictionaries with typed helpers.
  - Update main-actor state from a Sendable observer closure in Swift 6.
  - Describe what NotificationCenter.MainActorMessage and AsyncMessage add, and their availability.
terms:
  - term: NotificationCenter
    definition: "A Foundation object that delivers notifications from posters to registered observers inside one program. Each app has a default center (NotificationCenter.default); you can create others."
  - term: Notification
    definition: "A value with a name (Notification.Name), an optional object (usually the sender) and an optional userInfo dictionary of type [AnyHashable: Any]."
  - term: Observer token
    definition: "The opaque object returned by addObserver(forName:object:queue:using:). The center holds it and the block until you pass the token to removeObserver(_:)."
  - term: Object filter
    definition: "The object argument of addObserver. When it isn't nil, the observer only receives notifications posted with that same object."
  - term: MainActorMessage
    definition: "A protocol added in iOS 26 and macOS 26 for typed notifications delivered synchronously on the main actor. Messages carry their data as properties instead of userInfo, and observation ends when the returned ObservationToken is discarded."
mastery:
  - Post a notification with a name, an object and userInfo, and read it in an observer.
  - Predict which observers receive a notification given their name and object filters.
  - Write a typed helper that posts and reads a struct instead of raw userInfo keys.
  - Write a main-actor observer that removes its registration when it's released.
  - Explain why addObserver's closure can't touch a view controller's state directly in Swift 6, and two ways to deal with it.
resources: [foundation-notificationcenter, foundation-notification-messages, swift-mainactor, swift-book-arc, swift-book-closures]
cards:
  - id: m26-l03-c1
    front: With queue nil, when does an observer block run?
    back: "Synchronously, on the posting thread, inside post(…). post doesn't return until every such observer has run."
  - id: m26-l03-c2
    front: Does the notification center keep block-based observers alive?
    back: "Yes. It strongly holds the block and the returned token until you call removeObserver(_:) with the token. Selector-based observers (addObserver(_:selector:name:object:)) are cleaned up automatically since iOS 9; block-based ones aren't."
  - id: m26-l03-c3
    front: "What does object: shop do in addObserver(forName:object:queue:using:)?"
    back: "It filters by sender: the block only runs for notifications posted with that same object. object: nil means \"from anyone\"."
  - id: m26-l03-c4
    front: Do observers run in a guaranteed order?
    back: "Apple's documentation doesn't promise one. Don't write observers that depend on each other's order; if order matters, it's not a broadcast, it's a sequence one object should control."
  - id: m26-l03-c5
    front: What do MainActorMessage and AsyncMessage add over Notification (iOS 26)?
    back: "Typed payloads as properties instead of userInfo, isolation in the type (MainActorMessage observers run on the main actor; AsyncMessage is delivered asynchronously to an async Sendable closure), and an ObservationToken that stops observing when it's discarded."
---

## The idea in one sentence

`NotificationCenter` lets an object announce "this happened" without knowing who's listening, and lets any number of objects listen without knowing who announced it, which is exactly what you want for app-wide events and exactly what makes it easy to abuse.

> [!note] About this lesson's code
> `NotificationCenter` is part of Foundation and works the same way on Linux, so the plain-Swift blocks here were compiled and run with Swift 6.3. UIKit blocks are type-checked against the iOS SDK, not run. API declarations and quotes come from Apple's documentation for `NotificationCenter`, `addObserver(forName:object:queue:using:)` and "Notification center messages", read in November 2026. Module 13, lesson 6 introduced observer tokens and their cleanup; this lesson is about the API itself.

## Posting and observing

Three pieces: a **name**, an **observer** registered for that name, and a **post**.

```swift
import Foundation

extension Notification.Name {
    static let userDidLogOut = Notification.Name("UserDidLogOut")
}

let center = NotificationCenter.default

let token = center.addObserver(forName: .userDidLogOut, object: nil, queue: nil) { notification in
    print("observer: \(notification.name.rawValue)")
}

print("before post")
center.post(name: .userDidLogOut, object: nil)
print("after post")

center.removeObserver(token)
center.post(name: .userDidLogOut, object: nil)
print("done")
```

```output
before post
observer: UserDidLogOut
after post
done
```

Line by line:

- **The name** is a `Notification.Name`, a wrapper around a string. Declaring it once as a static constant in an extension gives you autocompletion and stops typos: two different string literals would be two different names, and nothing would warn you.
- **`addObserver(forName:object:queue:using:)`** registers a block. `object: nil` means "from any sender" (more below). `queue: nil` means, in Apple's words, "the block runs synchronously on the posting thread."
- **The return value** is the observer token. Apple: the notification center "strongly holds this return value until you remove the observer registration", and the same for the block.
- **`post(name:object:)`** calls every matching observer **before it returns**. That's why `observer:` prints between `before post` and `after post`. Posting isn't a message dropped in a mailbox; it's a function call that fans out.
- **`removeObserver(token)`** ends the registration. The second post reaches nobody.

The older selector form, `addObserver(_:selector:name:object:)`, needs an `@objc` method (Apple platforms only). Its documentation says that since iOS 9 you don't need to remove an observer registered with it. The block form has no such cleanup: the center keeps your block until you remove it.

## The Sendable closure

Look at the declaration of the block parameter:

```swift illustrative
func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?,
                 using block: @escaping @Sendable (Notification) -> Void) -> any NSObjectProtocol
```

`@Sendable` means the compiler treats the block as if it could run on any thread, because it can: with `queue: nil` it runs on whichever thread posts. In Swift 6 mode the block can't capture a non-`Sendable` object or call a main-actor method directly. That's a problem, because the typical observer is a view controller, which is main-actor isolated.

When you **know** the notification is posted on the main thread (your own code posts it from the UI, or the system documents it), you can tell the compiler so with `MainActor.assumeIsolated`, which checks at run time and stops the program if the assumption is wrong:

```swift
import Foundation

extension Notification.Name {
    static let cartDidChange = Notification.Name("CartDidChange")
}

final class ObserverToken {
    private let center: NotificationCenter
    private let observer: any NSObjectProtocol

    init(center: NotificationCenter, observer: any NSObjectProtocol) {
        self.center = center
        self.observer = observer
    }

    deinit {
        center.removeObserver(observer)
        print("observer removed")
    }
}

@MainActor
final class BadgeView {
    private var token: ObserverToken?

    init(center: NotificationCenter) {
        let observer = center.addObserver(forName: .cartDidChange, object: nil, queue: nil) { [weak self] notification in
            let count = notification.userInfo?["count"] as? Int ?? 0
            MainActor.assumeIsolated {
                self?.show(count)
            }
        }
        token = ObserverToken(center: center, observer: observer)
    }

    func show(_ count: Int) {
        print("badge: \(count)")
    }

    deinit {
        print("badge freed")
    }
}

let center = NotificationCenter()
var badge: BadgeView? = BadgeView(center: center)
center.post(name: .cartDidChange, object: nil, userInfo: ["count": 3])
badge = nil
center.post(name: .cartDidChange, object: nil, userInfo: ["count": 4])
print("done")
```

```output
badge: 3
badge freed
observer removed
done
```

- The block reads what it needs from the notification (an `Int`, which is `Sendable`) **before** entering `MainActor.assumeIsolated`. `Notification` itself isn't `Sendable`, so you don't carry it across.
- `[weak self]`: the center holds the block, and the block must not keep the badge alive. A `@MainActor` class is `Sendable`, so capturing it is allowed.
- `ObserverToken` removes the registration in its own `deinit`. `BadgeView` can't do it in *its* `deinit`: in Swift 6 a main-actor class's `deinit` isn't isolated, and it can't read a stored property of a non-`Sendable` type such as `any NSObjectProtocol`. Swift 6.3 reports `cannot access property 'observer' with a non-Sendable type '(any NSObjectProtocol)?' from nonisolated deinit`. Letting the token clean up after itself sidesteps that, and it's the same design Apple chose for the iOS 26 API at the end of this lesson.
- `NotificationCenter()` creates a private center. Tests and examples use one so they don't receive the system's notifications, and so nothing they post leaks into the rest of the app.

In UIKit code you often pass `queue: .main` instead, so the block is scheduled on the main queue even when the poster is on another thread. The closure is still `@Sendable` to the compiler, so you still need `MainActor.assumeIsolated` (or a `Task { @MainActor in … }`, Module 29) to touch the view controller:

```swift ios
import UIKit

final class ArticleViewController: UIViewController {
    private var activeObserver: (any NSObjectProtocol)?

    override func viewDidLoad() {
        super.viewDidLoad()
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    private func refresh() {
        print("reload the article")
    }
}
```

Here the registration is removed in `viewDidDisappear(_:)`, an explicit point on the main actor. (This controller registers once, in `viewDidLoad()`, so once it's been removed it stays removed; register in `viewWillAppear(_:)` instead if the screen should listen every time it's shown.)

## userInfo and typed payloads

A notification carries data in `userInfo`, a `[AnyHashable: Any]` dictionary. It's flexible and completely unchecked: the key is a string both sides must spell the same way, and the value must be cast back to the right type. A typo isn't an error, just a missing value:

```swift
import Foundation

extension Notification.Name {
    static let downloadDidFinish = Notification.Name("DownloadDidFinish")
}

let center = NotificationCenter()
let token = center.addObserver(forName: .downloadDidFinish, object: nil, queue: nil) { notification in
    let bytes = notification.userInfo?["bytes"] as? Int
    let file = notification.userInfo?["fileName"] as? String
    print("\(file ?? "unknown file"): \(bytes ?? 0) bytes")
}
center.post(name: .downloadDidFinish, object: nil, userInfo: ["bytes": 2048, "filename": "a.zip"])
center.post(name: .downloadDidFinish, object: nil, userInfo: ["bytes": "2048", "fileName": "b.zip"])
center.removeObserver(token)
```

```output
unknown file: 2048 bytes
b.zip: 0 bytes
```

The first post spelled the key `filename`; the second sent the byte count as a `String`. Both compile, and both lose data.

The fix is to define the payload as a type and keep the dictionary in one place, behind two small helpers that are the only code allowed to touch the key:

```swift
import Foundation

struct DownloadResult {
    let fileName: String
    let bytes: Int
}

extension Notification.Name {
    static let downloadDidFinish = Notification.Name("DownloadDidFinish")
}

extension NotificationCenter {
    func postDownloadDidFinish(_ result: DownloadResult, from sender: AnyObject? = nil) {
        post(name: .downloadDidFinish, object: sender, userInfo: ["result": result])
    }
}

extension Notification {
    var downloadResult: DownloadResult? {
        userInfo?["result"] as? DownloadResult
    }
}

let center = NotificationCenter()
let token = center.addObserver(forName: .downloadDidFinish, object: nil, queue: nil) { notification in
    guard let result = notification.downloadResult else { return }
    print("\(result.fileName): \(result.bytes) bytes")
}
center.postDownloadDidFinish(DownloadResult(fileName: "a.zip", bytes: 2048))
center.removeObserver(token)
```

```output
a.zip: 2048 bytes
```

Now the poster can't forget a field (the struct's initializer requires both), and the observer can't cast to the wrong type. The key `"result"` appears twice, both in this file.

## The object filter

The `object` argument does two jobs. When **posting**, it's the sender, available to observers as `notification.object`. When **observing**, a non-`nil` object is a filter: only notifications posted with that same object are delivered.

```swift
import Foundation

extension Notification.Name {
    static let cartDidChange = Notification.Name("CartDidChange")
}

final class Cart {
    let name: String
    init(name: String) {
        self.name = name
    }
}

let center = NotificationCenter()
let shop = Cart(name: "shop")
let wishlist = Cart(name: "wishlist")

let token = center.addObserver(forName: .cartDidChange, object: shop, queue: nil) { notification in
    let name = (notification.object as? Cart)?.name ?? "nobody"
    print("shop observer heard \(name)")
}
center.post(name: .cartDidChange, object: wishlist)
center.post(name: .cartDidChange, object: shop)
center.post(name: .cartDidChange, object: nil)
center.removeObserver(token)
```

```output
shop observer heard shop
```

Only the post from `shop` gets through. A post with `object: nil` doesn't match a filtered observer either: the filter means "from this sender", and a `nil` sender isn't that sender. Use the filter when there are several instances of the same kind of object, such as two carts, two players or two documents, and an observer cares about one.

## One post, many observers

The reason to use a notification center at all is that the sender doesn't know or care how many observers there are. A cart posts once; a badge, a total label and an analytics logger can all react, and you can add a fourth without touching the cart.

What the center doesn't promise is **order**. Apple's documentation for the block API says that if a notification triggers several observer blocks, they "can all execute concurrently (but on their queue or on the current thread)", and it says nothing about which runs first. In fact, on Linux's Foundation, while writing this lesson, the observer registered last ran first. So the next example collects what each observer did and prints it sorted:

```swift
import Foundation

extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

@MainActor
final class Log {
    private var lines: [String] = []

    func add(_ line: String) {
        lines.append(line)
    }

    func flush() {
        print(lines.sorted().joined(separator: ", "))
        lines = []
    }
}

let center = NotificationCenter()
let log = Log()
var tokens: [any NSObjectProtocol] = []

for screen in ["editor", "sidebar", "toolbar"] {
    let token = center.addObserver(forName: .themeDidChange, object: nil, queue: nil) { notification in
        let theme = notification.userInfo?["theme"] as? String ?? "?"
        MainActor.assumeIsolated {
            log.add("\(screen)=\(theme)")
        }
    }
    tokens.append(token)
}

center.post(name: .themeDidChange, object: nil, userInfo: ["theme": "dark"])
log.flush()
center.removeObserver(tokens[1])
center.post(name: .themeDidChange, object: nil, userInfo: ["theme": "light"])
log.flush()
for token in tokens {
    center.removeObserver(token)
}
```

```output
editor=dark, sidebar=dark, toolbar=dark
editor=light, toolbar=light
```

If your observers need to run in a particular order (save first, then refresh the list), that's not a broadcast. It's a sequence, and one object should call the steps in order.

## Typed messages (iOS 26)

iOS 26 and macOS 26 added a Swift-first layer on top of the notification center. Apple's "Notification center messages" article explains why: "the `Notification` type is `nonisolated`, even in cases where it's posted on a known isolation." The new API puts the isolation and the payload in the type:

- **`NotificationCenter.MainActorMessage`**: a protocol for messages posted and observed on the main actor. Apple: the center "delivers `MainActorMessage` types synchronously when posted." The observer closure is `@MainActor (Message) -> Void`, so it can update UI directly, without `assumeIsolated`.
- **`NotificationCenter.AsyncMessage`**: for messages posted from any isolation. They're delivered asynchronously to an `@Sendable … async` closure, which Apple notes isn't suitable when observers must run "before a certain action takes place."
- **Payloads are properties.** A message is your own struct with stored properties, not a `userInfo` dictionary. Each message type names a `Subject`, the type of object it's about.
- **`addObserver(of:for:using:)`** returns a `NotificationCenter.ObservationToken`. Apple: "observation ends when the token goes out of scope." You store the token for as long as you want to observe; `removeObserver(_:)` also ends it.
- UIKit adopts it for its own notifications, such as `UIApplication.DidBecomeActiveMessage` and `UIResponder.KeyboardWillShowMessage` (with typed properties like `endFrame` and `animationDuration` instead of `userInfo` keys).

Here are a custom main-actor message and a system one in a view controller. Everything in this block requires iOS 26:

```swift ios 26.0
import UIKit

@MainActor
final class Cart {
    private(set) var itemCount = 0

    func add() {
        itemCount += 1
        NotificationCenter.default.post(CartDidChange(itemCount: itemCount), subject: self)
    }
}

struct CartDidChange: NotificationCenter.MainActorMessage {
    typealias Subject = Cart
    let itemCount: Int
}

extension NotificationCenter.MessageIdentifier where Self == NotificationCenter.BaseMessageIdentifier<CartDidChange> {
    static var cartDidChange: Self { .init() }
}

final class CartBadgeViewController: UIViewController {
    private let cart: Cart
    private let badgeLabel = UILabel()
    private var cartToken: NotificationCenter.ObservationToken?
    private var activeToken: NotificationCenter.ObservationToken?

    init(cart: Cart) {
        self.cart = cart
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(badgeLabel)
        cartToken = NotificationCenter.default.addObserver(of: cart, for: .cartDidChange) { [weak self] message in
            self?.badgeLabel.text = "\(message.itemCount)"
        }
        activeToken = NotificationCenter.default.addObserver(for: UIApplication.DidBecomeActiveMessage.self) { [weak self] _ in
            self?.badgeLabel.text = "\(self?.cart.itemCount ?? 0)"
        }
    }
}
```

- `CartDidChange` is a struct with an `itemCount` property, not a key in a dictionary. `Subject = Cart` ties it to the object that posts it.
- The `MessageIdentifier` extension is what makes `.cartDidChange` work at the call site. Apple's documentation shows this same pattern.
- `addObserver(of: cart, for: .cartDidChange)` observes **one** cart, the typed version of the object filter.
- The closures set a label directly: they're `@MainActor`, so there's no `assumeIsolated`. `[weak self]` is still needed, because the center holds the closure for as long as the token lives, and the controller holds the token.
- The tokens are stored properties. When the controller is released, the tokens go with it and observation ends.

If your app supports iOS versions before 26, you keep using `Notification.Name` and `addObserver(forName:object:queue:using:)`, or wrap both behind an availability check. Apple's article also suggests defining a `Notification` alongside the message when Objective-C code needs to observe it.

There's also `notifications(named:object:)`, available since iOS 15, which turns notifications into an asynchronous sequence you read with `for await`. You'll use it in Module 29, once `Task` and cancellation are on the table.

## Common mistakes

> [!error] Typing the name as a string literal in two places
> `Notification.Name("CartChanged")` in the poster and `Notification.Name("CartDidChange")` in the observer are two different notifications. Declare each name once as a static constant.

> [!error] Never removing a block-based observer
> The center keeps the block (and anything it captures) until you call `removeObserver(_:)` with the token. Store the token and remove it at a known point, or wrap it in an object whose `deinit` removes it.

> [!error] Capturing self strongly in the observer block
> The center holds the block, so `{ _ in self.refresh() }` keeps the screen alive as long as the registration exists, and the registration is usually removed in that same screen's cleanup. Use `[weak self]`. Lesson 4 shows the leak.

> [!error] error: cannot access property … from nonisolated deinit
> A main-actor class's `deinit` can't read a non-`Sendable` stored property such as the observer token. Remove the observer from an explicit method on the main actor, or store it in a small token object that removes itself in its own `deinit`.

> [!error] Using assumeIsolated when the post can come from another thread
> `MainActor.assumeIsolated` doesn't move work to the main actor; it checks that you're already there and stops the program if you aren't. If a notification can be posted from a background thread, register with `queue: .main` or hop with a `Task` (Module 29).

> [!error] Observers that depend on each other's order
> The documentation doesn't define an order. If one reaction has to happen before another, call them in sequence from one place.

> [!error] Broadcasting what should be a direct call
> A child screen posting "user picked a color" so its parent can hear it is a delegate or a closure in disguise, with none of the type checking and none of the visibility. Lesson 5 is about choosing.

## Exercises

````exercise
id: m26-l03-e1
type: prediction
prompt: "Posting is synchronous. In what order do these lines print?"
code: |
  import Foundation

  extension Notification.Name {
      static let didSave = Notification.Name("DidSave")
  }

  let center = NotificationCenter()
  let token = center.addObserver(forName: .didSave, object: nil, queue: nil) { notification in
      let id = notification.userInfo?["id"] as? Int ?? -1
      print("saved \(id)")
  }

  func save(_ id: Int) {
      print("saving \(id)")
      center.post(name: .didSave, object: nil, userInfo: ["id": id])
      print("save(\(id)) returns")
  }

  save(1)
  center.removeObserver(token)
  save(2)
  center.post(name: .didSave, object: nil, userInfo: ["ID": 3])
  print("end")
output: |
  saving 1
  saved 1
  save(1) returns
  saving 2
  save(2) returns
  end
hints:
  - "With queue nil, the block runs inside post."
  - "After removeObserver, nobody is registered."
solution: |
  ```output
  saving 1
  saved 1
  save(1) returns
  saving 2
  save(2) returns
  end
  ```

  `post` calls the observer before returning, so `saved 1` appears between the two lines of `save(1)`. The token is removed before `save(2)`, so that post and the last one reach nobody. (Had the observer still been registered, the last post would have printed `saved -1`, because the key `"ID"` isn't `"id"`.)
````

````exercise
id: m26-l03-e2
type: prediction
prompt: "Two observers with different object filters. What does it print?"
code: |
  import Foundation

  extension Notification.Name {
      static let scoreDidChange = Notification.Name("ScoreDidChange")
  }

  final class Player {
      let name: String
      init(_ name: String) { self.name = name }
  }

  let center = NotificationCenter()
  let ana = Player("Ana")
  let ben = Player("Ben")

  let anaToken = center.addObserver(forName: .scoreDidChange, object: ana, queue: nil) { _ in
      print("Ana's card updates")
  }

  center.post(name: .scoreDidChange, object: ben)
  center.post(name: .scoreDidChange, object: ana)
  center.post(name: .scoreDidChange, object: nil)
  center.removeObserver(anaToken)

  let allToken = center.addObserver(forName: .scoreDidChange, object: nil, queue: nil) { notification in
      let name = (notification.object as? Player)?.name ?? "no player"
      print("leaderboard hears \(name)")
  }
  center.post(name: .scoreDidChange, object: ben)
  center.post(name: .scoreDidChange, object: nil)
  center.removeObserver(allToken)
output: |
  Ana's card updates
  leaderboard hears Ben
  leaderboard hears no player
hints:
  - "A non-nil object filter only lets through posts with that same object."
  - "object: nil in addObserver means \"from anyone\", including posts without an object."
solution: |
  ```output
  Ana's card updates
  leaderboard hears Ben
  leaderboard hears no player
  ```

  Ana's observer filters by `ana`, so it ignores Ben's post and the post with no object. After it's removed, the leaderboard observes with `object: nil` and hears everything, reading the sender from `notification.object`. Only one observer is registered at a time here, so the output doesn't depend on delivery order.
````

````exercise
id: m26-l03-e3
type: comprehension
prompt: "A view controller registers with addObserver(forName:object:queue: .main) and the block calls self?.reload(). In Swift 6 mode it doesn't compile. Why?"
choices:
  - text: "The block parameter is @Sendable and not main-actor isolated, so it can't call the controller's main-actor method directly, even with queue .main."
    correct: true
    why: "The compiler goes by the closure's type, not by the queue you pass at run time. Wrap the call in MainActor.assumeIsolated or hop with a Task."
  - text: "queue: .main isn't allowed in Swift 6; you must pass nil."
    correct: false
    why: "Both are allowed. The queue changes where the block runs, not its type."
  - text: "[weak self] isn't allowed in a notification block."
    correct: false
    why: "It's allowed, and recommended. A main-actor class is Sendable, so capturing it weakly is fine."
  - text: "Notification observers must be selector-based in Swift 6."
    correct: false
    why: "The block API is fine; it just needs the isolation handled."
solution: |
  **The block is `@Sendable` and nonisolated.** `addObserver(forName:object:queue:using:)` declares `using block: @escaping @Sendable (Notification) -> Void`. Passing `.main` makes it run on the main queue at run time, but the compiler can't see that. `MainActor.assumeIsolated { self?.reload() }` states the fact and checks it. The iOS 26 `MainActorMessage` API removes the problem by declaring its observer closures `@MainActor`.
````

````exercise
id: m26-l03-e4
type: find-errors
prompt: "This settings screen observes a logout notification. Mark every real problem."
code: |
  final class SettingsViewController: UIViewController {
      override func viewDidLoad() {
          super.viewDidLoad()
          NotificationCenter.default.addObserver(
              forName: Notification.Name("userLoggedOut"),
              object: nil,
              queue: .main
          ) { notification in
              let reason = notification.userInfo?["reson"] as? String
              MainActor.assumeIsolated {
                  self.showLoggedOut(reason ?? "")
              }
          }
      }

      private func showLoggedOut(_ reason: String) {}
  }

  // Elsewhere:
  NotificationCenter.default.post(
      name: Notification.Name("UserDidLogOut"),
      object: nil,
      userInfo: ["reason": "expired"]
  )
choices:
  - text: "The poster and the observer use different string names, so the observer never runs."
    correct: true
  - text: "The token returned by addObserver is discarded, so the registration can never be removed."
    correct: true
  - text: "The block captures self strongly; the center keeps the screen alive."
    correct: true
  - text: "The userInfo key is misspelled (\"reson\"), so reason is always nil."
    correct: true
  - text: "MainActor.assumeIsolated can't be used inside a notification block."
    correct: false
  - text: "userInfo can't contain String values."
    correct: false
rubric:
  - Finds the mismatched names and suggests a static Notification.Name constant.
  - Finds the discarded token.
  - Finds the strong self capture.
  - Finds the misspelled key and suggests a typed helper.
solution: |
  1. **Two different names.** `"userLoggedOut"` and `"UserDidLogOut"` don't match. Declare `static let userDidLogOut = Notification.Name("UserDidLogOut")` once and use it on both sides.
  2. **Discarded token.** The center holds the block until `removeObserver(_:)` gets the token, which nobody kept. Store it in a property (or a self-removing token object).
  3. **Strong `self`.** The center owns the block, so the block owning the screen keeps it alive forever. Use `[weak self]` and `self?.showLoggedOut(…)`.
  4. **`"reson"`.** A typo in a `userInfo` key is silent. Put the key behind a typed helper (`notification.logoutReason`) so it's written once.

  `assumeIsolated` inside the block is the right tool when the block runs on the main queue, and `userInfo` accepts any values.
````

````exercise
id: m26-l03-e5
type: solve
prompt: |
  Write typed helpers for a "profile did change" notification, and a main-actor observer that removes its registration when released.

  - `struct ProfileChange { let userName: String; let photoChanged: Bool }`.
  - `Notification.Name.profileDidChange`.
  - `NotificationCenter.postProfileChange(_:)` that posts it with the change in `userInfo`, and `Notification.profileChange` that reads it back (or returns `nil`).
  - An `ObserverToken` class that removes the observer from its center in `deinit`.
  - A `@MainActor final class HeaderView` with `init(center:)` that observes the notification with `queue: nil`, captures itself weakly, and prints `header: <name>` plus ` (new photo)` when the photo changed. It prints `header freed` in `deinit`.

  This code:

  ```swift
  let center = NotificationCenter()
  var header: HeaderView? = HeaderView(center: center)
  center.postProfileChange(ProfileChange(userName: "ana", photoChanged: false))
  center.postProfileChange(ProfileChange(userName: "ana.r", photoChanged: true))
  header = nil
  center.postProfileChange(ProfileChange(userName: "ignored", photoChanged: false))
  print("end")
  ```

  should print:

  ```plaintext
  header: ana
  header: ana.r (new photo)
  header freed
  end
  ```
starter: |
  import Foundation

  struct ProfileChange {
      let userName: String
      let photoChanged: Bool
  }

  // your code
hints:
  - "Read the change inside the block (notification.profileChange), then pass its fields into MainActor.assumeIsolated."
  - "ObserverToken stores the center and the any NSObjectProtocol returned by addObserver."
  - "Keep the token in an optional property of HeaderView and assign it at the end of init."
rubric:
  - The userInfo key appears only inside the two helpers.
  - The observer block captures self weakly and uses MainActor.assumeIsolated with Sendable values.
  - The registration is removed when the header is released, through the token's deinit.
  - The output matches.
solution: |
  ```swift
  import Foundation

  struct ProfileChange {
      let userName: String
      let photoChanged: Bool
  }

  extension Notification.Name {
      static let profileDidChange = Notification.Name("ProfileDidChange")
  }

  extension NotificationCenter {
      func postProfileChange(_ change: ProfileChange) {
          post(name: .profileDidChange, object: nil, userInfo: ["change": change])
      }
  }

  extension Notification {
      var profileChange: ProfileChange? {
          userInfo?["change"] as? ProfileChange
      }
  }

  final class ObserverToken {
      private let center: NotificationCenter
      private let observer: any NSObjectProtocol

      init(center: NotificationCenter, observer: any NSObjectProtocol) {
          self.center = center
          self.observer = observer
      }

      deinit {
          center.removeObserver(observer)
      }
  }

  @MainActor
  final class HeaderView {
      private var token: ObserverToken?

      init(center: NotificationCenter) {
          let observer = center.addObserver(forName: .profileDidChange, object: nil, queue: nil) { [weak self] notification in
              guard let change = notification.profileChange else { return }
              let name = change.userName
              let newPhoto = change.photoChanged
              MainActor.assumeIsolated {
                  self?.update(name: name, newPhoto: newPhoto)
              }
          }
          token = ObserverToken(center: center, observer: observer)
      }

      func update(name: String, newPhoto: Bool) {
          print("header: \(name)\(newPhoto ? " (new photo)" : "")")
      }

      deinit {
          print("header freed")
      }
  }

  let center = NotificationCenter()
  var header: HeaderView? = HeaderView(center: center)
  center.postProfileChange(ProfileChange(userName: "ana", photoChanged: false))
  center.postProfileChange(ProfileChange(userName: "ana.r", photoChanged: true))
  header = nil
  center.postProfileChange(ProfileChange(userName: "ignored", photoChanged: false))
  print("end")
  ```

  ```output
  header: ana
  header: ana.r (new photo)
  header freed
  end
  ```

  The block extracts a `String` and a `Bool` (both `Sendable`) before entering `assumeIsolated`; `ProfileChange` would also work if you declared it `Sendable`. When `header` becomes `nil`, the header is freed, its `token` property goes with it, and the token's `deinit` removes the registration, so the third post reaches nobody. Even without the token, `[weak self]` would keep the header from leaking, but the dead block would stay registered forever.
````

````exercise
id: m26-l03-e6
type: explain
prompt: "Your team is adding a feature that requires iOS 26 as the minimum version. A colleague proposes moving the app's custom notifications to NotificationCenter.MainActorMessage. Explain what changes for posters and observers, what you gain, and one case where you'd choose AsyncMessage instead."
code: |
  // Today
  NotificationCenter.default.post(name: .cartDidChange, object: cart, userInfo: ["count": 3])

  token = NotificationCenter.default.addObserver(forName: .cartDidChange, object: cart, queue: .main) { [weak self] notification in
      let count = notification.userInfo?["count"] as? Int ?? 0
      MainActor.assumeIsolated { self?.badge.text = "\(count)" }
  }
rubric:
  - Payloads become stored properties of a message struct instead of userInfo keys and casts.
  - The observer closure is @MainActor, so assumeIsolated goes away; posting with post(_:subject:) is itself main-actor only.
  - Observation is tied to the ObservationToken, which ends observation when discarded.
  - Delivery for MainActorMessage is synchronous; AsyncMessage is for posting from any isolation, delivered asynchronously to an async Sendable closure, and not for time-critical ordering.
  - Mentions keeping [weak self] and storing the token.
solution: |
  With `MainActorMessage`, the cart change becomes `struct CartDidChange: NotificationCenter.MainActorMessage { typealias Subject = Cart; let itemCount: Int }`. The poster calls `NotificationCenter.default.post(CartDidChange(itemCount: 3), subject: cart)`, which is a `@MainActor` method, so posting from a background thread is now a compile-time error rather than a run-time surprise. The observer calls `addObserver(of: cart, for: .cartDidChange) { [weak self] message in self?.badge.text = "\(message.itemCount)" }`: no key, no cast, no default value for a missing field, and no `assumeIsolated`, because the closure is `@MainActor`. Delivery is still synchronous.

  Lifetime changes too: the returned `ObservationToken` ends the observation when it's discarded, so storing it in a property ties observation to the controller automatically. `[weak self]` is still needed, because the center holds the closure while the token lives.

  `AsyncMessage` is for events produced off the main actor, say a sync engine finishing a batch on a background task. Observers get an `async` `@Sendable` closure and the message arrives asynchronously, so it can't be used when observers must finish before the poster continues.
````

## Summary

- Declare names once as `static let` constants on `Notification.Name`. Post with `post(name:object:userInfo:)`; observe with `addObserver(forName:object:queue:using:)`, which returns a token.
- With `queue: nil`, observers run synchronously on the posting thread, inside `post`.
- The center strongly holds block-based observers and their tokens until `removeObserver(_:)`. Store the token, remove it at a known point or let a token object remove it in `deinit`, and capture `self` weakly.
- `object` is the sender when posting and a filter when observing; a filtered observer ignores posts from anyone else, including posts with no object.
- Several observers can react to one post, in no documented order. Don't make them depend on each other.
- `userInfo` is unchecked. Hide each key behind typed helpers that post and read a struct.
- In Swift 6 the observer block is `@Sendable`. Extract `Sendable` values first, then use `MainActor.assumeIsolated` when you know you're on the main thread.
- iOS 26 adds `MainActorMessage` and `AsyncMessage`: typed payloads, isolation in the type, `@MainActor` observer closures, and an `ObservationToken` that ends observation when it's discarded.
