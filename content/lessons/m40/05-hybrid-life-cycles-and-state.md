---
id: m40-l05
title: Hybrid life cycles and shared state
description: "In a hybrid app, one piece of state must have one owner, and both frameworks must see its changes. You decide who owns a model across the boundary, share one @Observable model between a UIKit controller and a hosted SwiftUI view, and keep UIKit current with the observation tracking Apple documents: automatic in updateProperties() on iOS 26, behind the UIObservationTrackingEnabled key on iOS 18, and by hand with withObservationTracking on iOS 17. Then you put a UIKit app delegate and scene delegate under a SwiftUI App, and see where UIHostingSceneDelegate fits."
module: m40
order: 5
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l04]
objectives:
  - Decide which side owns a piece of state in a hybrid screen and pass it across without copying it.
  - Share one @Observable model between a UIKit view controller and a hosted SwiftUI view.
  - Keep UIKit views current with automatic observation tracking (iOS 26, or iOS 18 with UIObservationTrackingEnabled) and with withObservationTracking on iOS 17.
  - Keep the shared model on the main actor and fix the error when background code mutates it.
  - Add a UIKit app delegate and scene delegate to a SwiftUI App with UIApplicationDelegateAdaptor.
terms:
  - term: Single source of truth
    definition: "Each piece of state has exactly one owner that stores it. Everything else reads it or gets write access to it (a reference, a binding, a closure), never a copy that can drift."
  - term: Automatic observation tracking (UIKit)
    definition: "UIKit records the @Observable properties you read in methods such as updateProperties(), layoutSubviews() and viewWillLayoutSubviews(), and runs the method again when one of them changes. On by default in iOS 26; in iOS 18 it requires the UIObservationTrackingEnabled Info.plist key."
  - term: updateProperties()
    definition: "A UIView and UIViewController method (iOS 26) for configuring content and styling before layout. It supports automatic observation tracking; schedule it with setNeedsUpdateProperties(), never call it directly."
  - term: UIApplicationDelegateAdaptor
    definition: "A property wrapper (iOS 14) you declare once in a SwiftUI App to have SwiftUI create a UIKit app delegate and forward its callbacks to it."
  - term: UIHostingSceneDelegate
    definition: "A protocol (iOS 26) that extends UISceneDelegate to bridge SwiftUI scenes, so a UIKit app can declare SwiftUI scenes in a static rootScene and activate them."
mastery:
  - Say who should own a model in a given hybrid screen and how each side gets to it.
  - Write a UIKit controller and a hosted SwiftUI view that show the same @Observable model and stay in sync.
  - Use updateProperties() on iOS 26, viewWillLayoutSubviews() with the Info.plist key on iOS 18, and withObservationTracking on iOS 17.
  - Predict which model changes trigger an update in an observation-tracking model.
  - Wire UIApplicationDelegateAdaptor and a scene delegate class in a SwiftUI App.
resources: [observation, observation-tracking, swiftui-managing-model-data, swift-mainactor, swiftui-app, swiftui-scenephase, uikit-app-life-cycle, information-property-list]
cards:
  - id: m40-l05-c1
    front: A UIKit screen and a hosted SwiftUI view both show a cart count. How do you keep them in sync?
    back: "One @MainActor @Observable model with one owner (often the UIKit side that creates both). Pass the same reference to the SwiftUI view, which tracks it automatically, and observe it in UIKit. Never copy the count into each side."
  - id: m40-l05-c2
    front: Where does UIKit track @Observable reads automatically, and from which iOS version?
    back: "In methods like updateProperties() (iOS 26), layoutSubviews(), viewWillLayoutSubviews() and cell configurationUpdateHandler. Default in iOS 26. In iOS 18, only with the Info.plist key UIObservationTrackingEnabled set to YES, and updateProperties() doesn't exist there: use viewWillLayoutSubviews()."
  - id: m40-l05-c3
    front: How do you observe an @Observable model in UIKit on iOS 17?
    back: "withObservationTracking { read the properties and update views } onChange: { schedule the same function again on the main actor }. onChange fires once, for the first change, so every update must register again."
  - id: m40-l05-c4
    front: "Swift 6: 'main actor-isolated property can not be mutated from a nonisolated context' on a shared model. Fix?"
    back: "The model is @MainActor (as it should be, since UIKit and SwiftUI read it). Do the background work, then apply the result on the main actor: await a @MainActor method, or run that part of the code in a @MainActor function."
  - id: m40-l05-c5
    front: How does a SwiftUI App get UIKit app delegate and scene delegate callbacks?
    back: "@UIApplicationDelegateAdaptor private var appDelegate: AppDelegate, declared once in the App. For scene callbacks, return a UISceneConfiguration whose delegateClass is your UIWindowSceneDelegate type from application(_:configurationForConnecting:options:)."
---

## The idea in one sentence

**State in a hybrid app has one owner and many observers**: put it in one `@Observable` model on the main actor, hand the same reference to both frameworks, and make each side react to changes the way it knows how.

> [!note] About this lesson's code
> Observation is part of the Swift toolchain, so the Observation blocks were compiled and run with Swift 6.3 on Linux. The update-pass model follows what Apple's article "Updating views automatically with observation tracking in UIKit" describes; it is not UIKit's implementation. UIKit and SwiftUI blocks are type-checked, not run, against the iOS SDK in Swift 6 mode, with the deployment target shown on each (iOS 17 unless marked 18 or 26). Behavior is quoted from Apple's pages for that article, "Automatic observation tracking", `updateProperties()`, `viewWillLayoutSubviews()`, `UIObservationTrackingEnabled`, `withObservationTracking(_:onChange:)`, `UIApplicationDelegateAdaptor` and `UIHostingSceneDelegate`, read in November 2026. Nothing was run in the simulator.

## Who owns the state

Lessons 1 to 4 moved values across the boundary one call at a time: a root view built from a struct, a binding into a coordinator, a closure for a result. That's enough for a screen. It stops being enough when **both sides show and change the same data**: a UIKit shop screen with a cart badge in its navigation bar and a SwiftUI cart summary below, both reacting when the user adds an item.

The rule from Module 36, lesson 6 doesn't change at the boundary: **one owner, everyone else gets access**. What changes is that the owner can be on either side:

| Situation | Owner | How the other side gets it |
| --- | --- | --- |
| UIKit screen hosting a SwiftUI part | The UIKit controller, or the coordinator/scene object that creates it | Pass the model reference into the hosted view's initializer |
| SwiftUI screen with a wrapped UIKit view | SwiftUI (`@State` holding the model, or an ancestor) | Pass values or the model into the representable; events come back through the coordinator |
| App-wide data in a UIKit app | The scene delegate, or a dependency container it owns | Injected into each screen, UIKit or SwiftUI |
| App-wide data in a SwiftUI app | The `App` struct's `@State` | Environment or initializer, and from there into hosted or wrapped UIKit |

Pick the **longest-lived** side that needs the state. If the UIKit controller creates the hosting controller, the UIKit controller outlives the hosted view, so it owns the model.

### What a copy does

The bug this rule prevents is two copies drifting apart. Lesson 1 showed it with a root view value. Here's the same thing with two "views" that each copied a count at creation, next to two that share a reference:

```swift
struct CopiedBadge {
    var count: Int
}

final class CartModel {
    var count = 0
}

struct SharedBadge {
    let cart: CartModel
}

var uikitBadge = CopiedBadge(count: 2)
var swiftUISummary = CopiedBadge(count: uikitBadge.count)
uikitBadge.count += 1
print("copies:", uikitBadge.count, swiftUISummary.count)
swiftUISummary.count = 0
print("copies:", uikitBadge.count, swiftUISummary.count)

let cart = CartModel()
cart.count = 2
let uikitView = SharedBadge(cart: cart)
let swiftUIView = SharedBadge(cart: cart)
uikitView.cart.count += 1
print("shared:", uikitView.cart.count, swiftUIView.cart.count)
swiftUIView.cart.count = 0
print("shared:", uikitView.cart.count, swiftUIView.cart.count)
```

```output
copies: 3 2
copies: 3 0
shared: 3 3
shared: 0 0
```

Sharing a reference fixes **what** each side reads. It doesn't make either side **redraw**. That part is observation.

## One @Observable model, two frameworks

The model is an ordinary `@Observable` class, `@MainActor` because both frameworks read it on the main thread:

```swift
import Observation

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class ShopCart {
    var items: [String] = []
    var promoCode = ""

    var itemCount: Int {
        items.count
    }

    func add(_ item: String) {
        items.append(item)
    }
}

if #available(macOS 14, iOS 17, *) {
    let cart = ShopCart()
    cart.add("Tea")
    cart.add("Mug")
    print(cart.itemCount, cart.items)
}
```

```output
2 ["Tea", "Mug"]
```

The `@available` attribute is there because these blocks also compile for macOS, where Observation starts at macOS 14; in an iOS 17 app you don't need it.

**The SwiftUI side** needs nothing special. Module 36, lesson 2: a view that reads `cart.itemCount` in `body` is updated when `items` changes, whether the view got the model through `@State`, the environment or a plain `let`. For bindings to its properties, use `@Bindable`.

**The UIKit side** is what this lesson adds. UIKit doesn't re-run your code when a model changes unless something tracks what you read. What tracks it depends on the deployment target.

## UIKit observation on iOS 26: updateProperties()

Apple's article "Updating views automatically with observation tracking in UIKit" describes it: "When you combine `Observable` models with UIKit, the system automatically watches for property changes and updates your views." The methods where that happens: "In a view subclass, `updateProperties()` and `layoutSubviews()` are examples of two methods where your updates receive automatic observation tracking." The "Automatic observation tracking" page lists the full set: for views `updateProperties()`, `layoutSubviews()`, `updateConstraints()` and `draw(_:)`; for view controllers `updateProperties()`, `viewWillLayoutSubviews()`, `viewDidLayoutSubviews()`, `updateViewConstraints()` and `updateContentUnavailableConfiguration(using:)`; plus buttons, cells, presentation controllers and compositional layout section providers.

`updateProperties()` is new in iOS 26: "Configures the view controller's content and styling properties." Put text, colors and visibility there; keep geometry in layout methods. The shop screen:

```swift ios 26.0
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ShopCart {
    var items: [String] = []

    var itemCount: Int {
        items.count
    }

    func add(_ item: String) {
        items.append(item)
    }
}

struct CartSummary: View {
    let cart: ShopCart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(cart.itemCount) items in your cart")
                .font(.headline)
            Button("Add a sample mug", action: addMug)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func addMug() {
        cart.add("Mug")
    }
}

final class ShopViewController: UIViewController {
    private let cart: ShopCart
    private let summaryHost: UIHostingController<CartSummary>

    init(cart: ShopCart) {
        self.cart = cart
        summaryHost = UIHostingController(rootView: CartSummary(cart: cart))
        super.init(nibName: nil, bundle: nil)
        title = "Shop"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cart", primaryAction: UIAction { _ in })
    }

    required init?(coder: NSCoder) {
        fatalError("ShopViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        summaryHost.sizingOptions = [.intrinsicContentSize]
        addChild(summaryHost)
        summaryHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryHost.view)
        NSLayoutConstraint.activate([
            summaryHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            summaryHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            summaryHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        summaryHost.didMove(toParent: self)
    }

    override func updateProperties() {
        super.updateProperties()
        let count = cart.itemCount
        navigationItem.rightBarButtonItem?.title = count == 0 ? "Cart" : "Cart (\(count))"
        navigationItem.rightBarButtonItem?.isEnabled = count > 0
    }
}
```

What happens when the user taps "Add a sample mug" in the SwiftUI part:

1. `addMug()` calls `cart.add("Mug")`, which changes `items`.
2. SwiftUI re-evaluates `CartSummary.body`, because it read `itemCount` (and through it, `items`).
3. UIKit runs `ShopViewController.updateProperties()` again, because the last run read `cart.itemCount`. Apple's description of the same pattern: "When the view first appears, UIKit runs `updateProperties()` and tracks that you read `showStatus` and `statusText`. If either property changes later, UIKit automatically runs `updateProperties()` again to update the label."

No delegate, no notification, no closure from SwiftUI to UIKit. Each side observes the model.

Two rules from Apple's page for the method: "Don't call this method directly; instead, call `setNeedsUpdateProperties()` to schedule an update." And call `super`, as the article's samples do.

### The order of an update pass

The article lists the steps of UIKit's update pass: the trait collection updates; "UIKit runs `updateProperties()` if necessary"; "UIKit runs `layoutSubviews()` if necessary"; the display pass renders; the frame is presented. "If any step causes other views to need updates, UIKit repeats the process until all views are current." Two consequences: traits are already current inside `updateProperties()`, and several model changes before the next pass lead to one run, not one per change. A model of that, with `withObservationTracking` standing in for UIKit's tracking:

```swift
import Observation

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class ShopCart {
    var items: [String] = []
    var promoCode = ""

    var itemCount: Int {
        items.count
    }
}

/// A model of UIKit's update pass, not its implementation.
@available(macOS 14, iOS 17, *)
@MainActor
final class FakeShopViewController {
    let cart: ShopCart
    private var needsUpdateProperties = true
    private(set) var updateCount = 0

    init(cart: ShopCart) {
        self.cart = cart
    }

    func updateProperties() {
        updateCount += 1
        print("update \(updateCount): badge \(cart.itemCount)")
    }

    func runUpdatePass() {
        guard needsUpdateProperties else {
            print("update pass: nothing to do")
            return
        }
        needsUpdateProperties = false
        withObservationTracking {
            updateProperties()
        } onChange: { [weak self] in
            MainActor.assumeIsolated {
                self?.needsUpdateProperties = true
            }
        }
    }
}

if #available(macOS 14, iOS 17, *) {
    let cart = ShopCart()
    let controller = FakeShopViewController(cart: cart)
    controller.runUpdatePass()

    cart.items.append("Tea")
    cart.items.append("Mug")
    controller.runUpdatePass()

    cart.promoCode = "SPRING"
    controller.runUpdatePass()

    cart.items.removeAll()
    controller.runUpdatePass()
}
```

```output
update 1: badge 0
update 2: badge 2
update pass: nothing to do
update 3: badge 0
```

- **Two appends, one update.** `onChange` fires on the first change and only marks the controller as needing an update. The pass runs once and reads the latest state.
- **`promoCode` changes nothing.** `updateProperties()` never read it, so it isn't tracked.
- **Every run registers again.** `withObservationTracking` calls `onChange` once; tracking continues only because each pass wraps `updateProperties()` again. UIKit does that for you on iOS 26. On iOS 17 you do it yourself, below.
- `MainActor.assumeIsolated` is there because `onChange` is a `@Sendable` closure the compiler can't prove runs on the main actor. Here it does: the mutations happen on the main actor and `onChange` runs synchronously as part of them (it runs before the new value is stored, which is why it only sets a flag and reads nothing).

## iOS 18: opt in with UIObservationTrackingEnabled

Apple's article has a note: "In iOS 18, the system doesn't enable automatic observation tracking by default. To enable it, add the `UIObservationTrackingEnabled` key to your app's information property list and set the key's value to `true`." The key's own page: "In iOS 18, add this key to your information property list and set the value to `YES` to tell the system to automatically track changes to observable objects. In iOS 26 and later, this key isn't required."

`updateProperties()` doesn't exist on iOS 18. The article's answer: "To get automatic observation tracking in iOS 18, use `viewWillLayoutSubviews()`", which its page confirms "supports automatic observation tracking":

```swift ios 18.0
import Observation
import UIKit

@MainActor
@Observable
final class ShopCart {
    var items: [String] = []

    var itemCount: Int {
        items.count
    }
}

final class CartBadgeViewController: UIViewController {
    private let cart: ShopCart
    private let badgeLabel = UILabel()

    init(cart: ShopCart) {
        self.cart = cart
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("CartBadgeViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        badgeLabel.font = .preferredFont(forTextStyle: .headline)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // Tracked automatically on iOS 18 with UIObservationTrackingEnabled = YES,
    // and on iOS 26 without the key.
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        badgeLabel.text = "\(cart.itemCount) items"
    }
}
```

Without the key on iOS 18, this compiles and shows the right count whenever layout happens to run, but a model change alone doesn't trigger it, so the label lags behind the model. If your app supports iOS 18, add the key.

> [!version] What's documented, exactly
> - **iOS 26 and later**: automatic tracking is on; `updateProperties()` exists and is the recommended place for content and styling.
> - **iOS 18**: automatic tracking in the supported methods (such as `viewWillLayoutSubviews()` and `layoutSubviews()`) only with `UIObservationTrackingEnabled` set to `YES`.
> - **iOS 17**: Apple's pages for the feature don't mention it. Observation itself is available (iOS 17), so track by hand.

## iOS 17: withObservationTracking by hand

With an iOS 17 deployment target, UIKit tracks nothing for you. `withObservationTracking(_:onChange:)` (iOS 17) "tracks access to any property within the `apply` closure, and informs the caller of value changes made to participating properties by way of the `onChange` closure." Module 32, lesson 3 showed its two traits: `onChange` fires once, and it fires before the new value is stored. So the UIKit pattern is: read and apply in the tracked closure, and in `onChange` schedule the same method again on the main actor:

```swift ios
import Observation
import UIKit

@MainActor
@Observable
final class ShopCart {
    var items: [String] = []

    var itemCount: Int {
        items.count
    }
}

final class LegacyCartBadgeViewController: UIViewController {
    private let cart: ShopCart
    private let badgeLabel = UILabel()

    init(cart: ShopCart) {
        self.cart = cart
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("LegacyCartBadgeViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        observeCart()
    }

    private func observeCart() {
        withObservationTracking {
            badgeLabel.text = "\(cart.itemCount) items"
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeCart()
            }
        }
    }
}
```

- The `apply` closure reads `cart.itemCount` and sets the label. That read is what gets tracked.
- `onChange` doesn't touch the label (the new value isn't stored yet). It schedules `observeCart()` on the main actor, which reads the new value and registers again.
- `[weak self]` keeps the pending task from keeping a dismissed screen alive. When the controller is gone, `self?` does nothing and tracking stops.
- Several changes before the task runs lead to one `observeCart()` call, the same coalescing as the update-pass model.

On iOS 26 you'd delete `observeCart()` and move the label line into `updateProperties()`. That's a good reason to keep the UIKit side's "apply the model" code in one method from the start.

## The model stays on the main actor

Both frameworks read the model on the main thread, so the model is `@MainActor`. Background work then can't write to it directly. The error, with no framework involved:

```swift no-compile main actor-isolated property 'itemCount' can not be mutated from a nonisolated context
@MainActor
final class CartModel {
    var itemCount = 0
}

func applyServerCount(_ count: Int, to cart: CartModel) async {
    cart.itemCount = count
}
```

Swift 6.3: `error: main actor-isolated property 'itemCount' can not be mutated from a nonisolated context`, with the note "consider declaring an isolated method on 'MainActor' to perform the mutation". Do the network call off the main actor, then apply the result on it:

```swift
@MainActor
final class CartModel {
    var itemCount = 0

    func applyServerCount(_ count: Int) {
        itemCount = count
    }
}

func fetchServerCount() async -> Int {
    3
}

func refresh(_ cart: CartModel) async {
    let count = await fetchServerCount()
    await cart.applyServerCount(count)
}

let cart = CartModel()
await refresh(cart)
print(cart.itemCount)
```

```output
3
```

`await cart.applyServerCount(count)` hops to the main actor for the mutation. Module 29 covered the mechanics; the point here is that a model shared by UIKit and SwiftUI is UI state, and UI state lives on the main actor.

## Life cycles: a SwiftUI App with UIKit delegates

Module 21, lesson 2 described two life cycles: UIKit's app delegate plus scene delegate, and SwiftUI's `App` with `ScenePhase`. A hybrid app usually starts on one and needs a piece of the other.

### SwiftUI App, UIKit callbacks

Some callbacks only exist on `UIApplicationDelegate` or `UIWindowSceneDelegate`: remote notification registration, Home Screen quick actions, some third-party SDK setup. `UIApplicationDelegateAdaptor` gives a SwiftUI app a UIKit app delegate, and the app delegate can name a scene delegate class:

```swift ios
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ShopCart {
    var items: [String] = []

    func saveDraft() {}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneDelegate.self
        }
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem
    ) async -> Bool {
        shortcutItem.type == "com.example.shop.new-order"
    }
}

struct CartScreen: View {
    let cart: ShopCart

    var body: some View {
        Text("\(cart.items.count) items")
    }
}

// In the app target this struct has @main.
struct ShopApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var cart = ShopCart()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CartScreen(cart: cart)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        cart.saveDraft()
                    }
                }
        }
    }
}
```

What Apple's `UIApplicationDelegateAdaptor` page says about each piece:

- "SwiftUI instantiates the delegate and calls the delegate's methods in response to life cycle events. Define the delegate adaptor only in your `App` declaration, and only once for a given app. If you declare it more than once, SwiftUI generates a runtime error."
- For scene callbacks, return the scene delegate's type from `application(_:configurationForConnecting:options:)`: "you only need to indicate the delegate class, and not a scene class or storyboard. SwiftUI creates and manages the delegate instance."
- And the advice that keeps the adaptor small: "Manage an app's life cycle events without using an app delegate whenever possible. For example, prefer to handle changes in `ScenePhase` instead of relying on delegate callbacks, like `application(_:didFinishLaunchingWithOptions:)`." That's why saving the draft uses `scenePhase`, not `applicationDidEnterBackground`.

The page also notes that if the delegate conforms to `ObservableObject`, SwiftUI puts it in the environment. This lesson doesn't use that: the cart is owned by the `App` with `@State`, the same owner rule as above, and the delegates only forward system events.

### UIKit app, SwiftUI scenes

The other direction is the common starting point: a UIKit app with a scene delegate whose screens are gradually becoming SwiftUI. Lesson 1 already covers most of it: the scene delegate owns the app-wide models (Module 25 kept the root coordinator there), and its window's root can be a `UIHostingController` as easily as a navigation controller.

iOS 26 adds `UIHostingSceneDelegate`, which Apple describes as extending `UISceneDelegate` "to bridge SwiftUI scenes". A class conforming to it declares SwiftUI scenes in a static `rootScene` property (a `WindowGroup`, for example), and UIKit can activate them by id or value with `UISceneSessionActivationRequest`; the class can also be returned as a `delegateClass` from `application(_:configurationForConnecting:options:)`. It's how a UIKit app opens a whole SwiftUI scene, such as a new window on iPad. With an iOS 26 deployment target, read its page before building multi-window support; it isn't covered further here.

## Common mistakes

> [!error] Copying shared state into each side
> A count copied into the hosted view and kept in the UIKit controller drifts as soon as one side changes. One `@Observable` model, one owner, the same reference on both sides.

> [!error] Using updateProperties() with an iOS 18 deployment target
> It's iOS 26 only. On iOS 18 use `viewWillLayoutSubviews()` or `layoutSubviews()` with `UIObservationTrackingEnabled` set to `YES`, and guard any `updateProperties()` override with availability.

> [!error] Expecting automatic tracking on iOS 18 without the Info.plist key
> The code compiles and the label is right whenever layout runs for some other reason, which makes the bug intermittent. Add `UIObservationTrackingEnabled`.

> [!error] Registering withObservationTracking once
> `onChange` fires once. Without registering again on every update, UIKit sees the first change and none after it.

> [!error] error: main actor-isolated property 'itemCount' can not be mutated from a nonisolated context
> Background code is writing a `@MainActor` model. Compute off the main actor, then `await` a main-actor method that applies the result.

> [!error] Declaring UIApplicationDelegateAdaptor in more than one place
> Apple: declare it "only in your `App` declaration, and only once for a given app. If you declare it more than once, SwiftUI generates a runtime error."

## Exercises

````exercise
id: m40-l05-e1
type: comprehension
prompt: "Your hybrid app's deployment target is iOS 18. A UIKit controller shows a value from an @Observable model in a label. Which setup keeps the label current on iOS 18 and iOS 26 according to Apple's documentation?"
choices:
  - text: "Set the label in viewWillLayoutSubviews() and add UIObservationTrackingEnabled = YES to Info.plist."
    correct: true
    why: "viewWillLayoutSubviews() supports automatic tracking; the key enables it on iOS 18 and isn't required on iOS 26."
  - text: "Set the label in updateProperties(); no Info.plist change needed."
    correct: false
    why: "updateProperties() is iOS 26 only, so it never runs on iOS 18."
  - text: "Set the label in viewDidLoad(); UIKit tracks reads there automatically."
    correct: false
    why: "viewDidLoad() isn't in Apple's list of tracked methods, and it runs once anyway."
  - text: "Set the label in viewWillLayoutSubviews(); iOS 18 tracks it by default."
    correct: false
    why: "Apple: 'In iOS 18, the system doesn't enable automatic observation tracking by default.'"
solution: |
  **`viewWillLayoutSubviews()` plus the key.** The article: "To get automatic observation tracking in iOS 18, use `viewWillLayoutSubviews()`," and "In iOS 18, the system doesn't enable automatic observation tracking by default. To enable it, add the `UIObservationTrackingEnabled` key." The key's page adds that in iOS 26 and later it isn't required. When you later raise the deployment target to iOS 26, move content and styling into `updateProperties()` and keep layout methods for geometry.
````

````exercise
id: m40-l05-e2
type: prediction
prompt: "The update-pass model with a controller that reads two properties, one of them only sometimes. What does it print?"
code: |
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Inbox {
      var unread = 0
      var isMuted = false
      var signature = "Sent from my iPhone"
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  final class FakeInboxViewController {
      let inbox: Inbox
      private var needsUpdate = true
      private(set) var updates = 0

      init(inbox: Inbox) {
          self.inbox = inbox
      }

      func updateProperties() {
          updates += 1
          if inbox.isMuted {
              print("update \(updates): muted")
          } else {
              print("update \(updates): \(inbox.unread) unread")
          }
      }

      func runUpdatePass() {
          guard needsUpdate else { return }
          needsUpdate = false
          withObservationTracking {
              updateProperties()
          } onChange: { [weak self] in
              MainActor.assumeIsolated { self?.needsUpdate = true }
          }
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let inbox = Inbox()
      let controller = FakeInboxViewController(inbox: inbox)
      controller.runUpdatePass()

      inbox.isMuted = true
      controller.runUpdatePass()

      inbox.unread = 5
      controller.runUpdatePass()

      inbox.signature = "—C"
      inbox.isMuted = false
      controller.runUpdatePass()

      print("total updates:", controller.updates)
  }
output: |
  update 1: 0 unread
  update 2: muted
  update 3: 5 unread
  total updates: 3
hints:
  - "Tracking records what the last run actually read."
  - "While muted, updateProperties() never reads unread."
solution: |
  ```output
  update 1: 0 unread
  update 2: muted
  update 3: 5 unread
  total updates: 3
  ```

  - Update 1 reads `isMuted` (false) and `unread`: both tracked.
  - Muting changes a tracked property: update 2 runs, and this time reads **only** `isMuted`.
  - `unread = 5` changes a property the last run didn't read: no update. The pass does nothing.
  - `signature` was never read. `isMuted = false` is tracked, so update 3 runs and reads the current `unread`, 5.

  Tracking is per run, by what the code read on that run. A branch that skips a property stops tracking it until a run reads it again, which is correct: while muted, the unread count doesn't affect what's shown.
````

````exercise
id: m40-l05-e3
type: prediction
prompt: "A UIKit screen and a hosted view in a hybrid app, modeled without frameworks. One shares the model, one was given a copy of a value. What does it print?"
code: |
  final class Profile {
      var displayName: String

      init(displayName: String) {
          self.displayName = displayName
      }
  }

  struct HeaderView {
      let profile: Profile
      func render() -> String { "Header: \(profile.displayName)" }
  }

  struct SettingsView {
      let displayName: String
      func render() -> String { "Settings: \(displayName)" }
  }

  let profile = Profile(displayName: "Christian")
  let header = HeaderView(profile: profile)
  var settings = SettingsView(displayName: profile.displayName)

  profile.displayName = "Chris"
  print(header.render())
  print(settings.render())

  settings = SettingsView(displayName: profile.displayName)
  let renamed = Profile(displayName: "C.")
  print(header.render(), "|", settings.render(), "|", renamed.displayName)
output: |
  Header: Chris
  Settings: Christian
  Header: Chris | Settings: Chris | C.
hints:
  - "HeaderView holds a reference; SettingsView holds a String."
  - "renamed is a different Profile object."
solution: |
  ```output
  Header: Chris
  Settings: Christian
  Header: Chris | Settings: Chris | C.
  ```

  - `HeaderView` reads the shared `Profile`, so it sees "Chris".
  - `SettingsView` copied the string when it was created and still says "Christian".
  - Recreating `SettingsView` copies the current name, "Chris". Creating another `Profile` doesn't affect either view; they don't point at it.

  In the app, the fix is to give `SettingsView` the `Profile` (an `@Observable` model) instead of a copied string. Recreating the view on every change, the second print's approach, is what assigning a new `rootView` does in lesson 1: it works, but someone has to remember to do it.
````

````exercise
id: m40-l05-e4
type: solve
prompt: |
  Write the iOS 17 pattern in plain Swift so it runs without UIKit. Use a synchronous scheduler instead of `Task` so the output is deterministic:

  - A `@MainActor @Observable final class Player` with `var title = ""` and `var isPlaying = false`.
  - A `@MainActor final class NowPlayingLabel` that keeps a `text` string, an `observe()` method that sets `text` inside `withObservationTracking` (for example "▶ Title" or "❚❚ Title") and in `onChange` appends a re-observe job to a `pendingJobs` array, and a `runPendingJobs()` method.

  Drive it: observe, change the title, run pending jobs, toggle play twice without running jobs in between, run pending jobs, and print `text` and the number of times `observe()` ran after each step. Mark the types `@available(macOS 14, iOS 17, *)` and wrap the driver in `if #available`.
starter: |
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Player {
      var title = ""
      var isPlaying = false
  }

  // your NowPlayingLabel
hints:
  - "onChange is @Sendable. Use MainActor.assumeIsolated to append to pendingJobs, as the lesson's model does."
  - "Run the jobs from a copy of the array and clear it first, so a job that registers again doesn't run in the same loop."
rubric:
  - observe() reads the model inside withObservationTracking and registers again only through a scheduled job.
  - onChange doesn't read the model.
  - Two changes before the jobs run lead to one extra observe() call.
  - The output is deterministic.
solution: |
  ```swift
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Player {
      var title = ""
      var isPlaying = false
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  final class NowPlayingLabel {
      let player: Player
      private(set) var text = ""
      private(set) var observeCount = 0
      private var pendingJobs: [() -> Void] = []

      init(player: Player) {
          self.player = player
      }

      func observe() {
          observeCount += 1
          withObservationTracking {
              text = (player.isPlaying ? "▶ " : "❚❚ ") + player.title
          } onChange: { [weak self] in
              MainActor.assumeIsolated {
                  self?.pendingJobs.append { self?.observe() }
              }
          }
      }

      func runPendingJobs() {
          let jobs = pendingJobs
          pendingJobs = []
          jobs.forEach { $0() }
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let player = Player()
      player.title = "Blue in Green"
      let label = NowPlayingLabel(player: player)

      label.observe()
      print(label.text, label.observeCount)

      player.title = "So What"
      print(label.text, label.observeCount)
      label.runPendingJobs()
      print(label.text, label.observeCount)

      player.isPlaying = true
      player.isPlaying = false
      player.isPlaying = true
      label.runPendingJobs()
      print(label.text, label.observeCount)
  }
  ```

  ```output
  ❚❚ Blue in Green 1
  ❚❚ Blue in Green 1
  ❚❚ So What 2
  ▶ So What 3
  ```

  - Changing the title doesn't update the label by itself: `onChange` only scheduled a job. That's the deferral the UIKit version gets from `Task { @MainActor in … }`.
  - Three play toggles produce **one** job, because `onChange` fires once per registration. The job reads the final state.
  - In the UIKit controller, `pendingJobs` and `runPendingJobs()` are replaced by `Task { @MainActor in self?.observe() }`, and `text` by the label.
````

````exercise
id: m40-l05-e5
type: find-errors
prompt: "A SwiftUI App that needs a UIKit app delegate for push notifications and shares a session model with a hosted UIKit settings screen. Which of these are real problems?"
code: |
  final class AppDelegate: NSObject, UIApplicationDelegate {
      func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
          // send the token to the server
      }
  }

  @Observable
  final class Session {
      var userName = ""
  }

  @main
  struct BankApp: App {
      @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
      @State private var session = Session()

      var body: some Scene {
          WindowGroup {
              RootView(session: session)
          }
      }
  }

  struct RootView: View {
      @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
      let session: Session
      var body: some View { SettingsScreen(userName: session.userName) }
  }

  // SettingsScreen wraps a UIKit SettingsViewController that stores userName in a label in viewDidLoad.

  func signIn(session: Session) async {
      let name = await api.fetchUserName()
      session.userName = name
  }
choices:
  - text: "UIApplicationDelegateAdaptor is declared twice, once in a View."
    correct: true
    why: "Apple: only in the App declaration, only once; more than once is a runtime error."
  - text: "SettingsScreen gets a copy of userName and sets it once in viewDidLoad, so the UIKit screen won't follow sign-in."
    correct: true
    why: "Pass the Session and observe it in UIKit (updateProperties, a tracked layout method, or withObservationTracking), or update the representable's controller in updateUIViewController."
  - text: "Session isn't @MainActor, so signIn mutates UI state from whatever executor runs it."
    correct: true
    why: "Make Session @MainActor; then signIn has to apply the name on the main actor, and the compiler enforces it."
  - text: "A SwiftUI App can't have a UIKit app delegate."
    correct: false
    why: "That's exactly what UIApplicationDelegateAdaptor is for."
  - text: "Session should be owned by the AppDelegate instead of the App's @State."
    correct: false
    why: "Either can own it, but Apple advises keeping the delegate for system callbacks; the App's @State is a fine owner."
rubric:
  - Flags the second adaptor.
  - Flags the copied userName in the UIKit screen.
  - Flags the missing @MainActor on Session.
  - Doesn't flag the adaptor's existence or the App owning the session.
solution: |
  Three real problems:

  1. **Two adaptors.** Remove the one in `RootView`. Apple: declare it "only in your `App` declaration, and only once for a given app. If you declare it more than once, SwiftUI generates a runtime error."
  2. **A copied value in a UIKit screen.** `SettingsScreen(userName:)` hands over a `String`, and the controller uses it once. Pass the `Session` through the representable and have the controller observe it, or at least write the new value in `updateUIViewController`.
  3. **Isolation.** `Session` is UI state read by SwiftUI and UIKit. Mark it `@MainActor`. Then `session.userName = name` in a nonisolated async function becomes a compile error, and the fix is a `@MainActor` method that applies the name, awaited from `signIn`.

  A SwiftUI app with a UIKit app delegate is supported, and the `App` owning the session with `@State` is the owner rule working as intended.
````

## Summary

- Shared state gets one owner, the longest-lived side that needs it, and both frameworks get the same reference. Copies drift.
- Make the shared model `@MainActor @Observable`. SwiftUI tracks it automatically. Background code computes off the main actor and applies results through a main-actor method.
- UIKit tracking, by deployment target, as Apple documents it: iOS 26, automatic in `updateProperties()` (content and styling) and layout methods; iOS 18, the same layout methods such as `viewWillLayoutSubviews()` only with `UIObservationTrackingEnabled = YES`; iOS 17, `withObservationTracking` with re-registration scheduled from `onChange`.
- Observation tracks what the last run read and coalesces several changes into one update.
- In a SwiftUI `App`, `@UIApplicationDelegateAdaptor` (declared once) brings in a UIKit app delegate, which can name a scene delegate class. Prefer `ScenePhase` for life-cycle events when it covers them.
- In a UIKit app, the scene delegate owns app-wide models and can host SwiftUI at any level. On iOS 26, `UIHostingSceneDelegate` lets UIKit activate whole SwiftUI scenes.
