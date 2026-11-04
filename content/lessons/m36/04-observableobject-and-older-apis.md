---
id: m36-l04
title: ObservableObject and the older APIs
description: "Before iOS 17, SwiftUI models were ObservableObject classes with @Published properties, held with @StateObject, @ObservedObject or @EnvironmentObject. That code is everywhere, isn't deprecated, and has one classic bug: an @ObservedObject that creates its own model and loses it on every parent update. You learn how these APIs work, model the bug and its fix in plain Swift, compare whole-object invalidation with Observation's per-property tracking, and migrate a screen step by step following Apple's guide."
module: m36
order: 4
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l03]
objectives:
  - Read and write an ObservableObject model with @Published properties and explain when objectWillChange fires.
  - Choose between @StateObject, @ObservedObject and @EnvironmentObject, and spot the @ObservedObject recreation bug.
  - Explain why an ObservableObject invalidates every observing view, and what changes with @Observable.
  - Migrate a screen from ObservableObject to @Observable following Apple's steps.
  - Recognize when you'll still write or maintain these APIs.
terms:
  - term: ObservableObject
    definition: "A Combine protocol (iOS 13) for classes with an objectWillChange publisher that \"emits before the object has changed\". SwiftUI subscribes to it to update views."
  - term: "@Published"
    definition: "A Combine property wrapper that makes a class property publish its changes. Publishing happens in willSet, and the synthesized objectWillChange of an ObservableObject fires before any @Published property changes."
  - term: "@StateObject"
    definition: "A SwiftUI property wrapper (iOS 14) that creates and owns an ObservableObject. Its initializer takes an autoclosure that SwiftUI runs only the first time for a given view identity."
  - term: "@ObservedObject"
    definition: "A SwiftUI property wrapper (iOS 13) for an ObservableObject that the view receives from outside. It subscribes to the object but doesn't own it."
  - term: "@EnvironmentObject"
    definition: "A SwiftUI property wrapper (iOS 13) that reads an ObservableObject an ancestor supplied with environmentObject(_:)."
mastery:
  - Write an ObservableObject view model with @Published state and a binding from $model.property.
  - Explain, with the storage model, why @ObservedObject var model = Model() loses its data and why @StateObject doesn't.
  - Predict which views update after a @Published change, compared with an @Observable model.
  - Convert @StateObject, @ObservedObject, @EnvironmentObject and @Published to their Observation equivalents.
  - Say why a team on iOS 16 or with Combine pipelines on $property keeps ObservableObject.
resources: [swiftui-migrating-to-observable, observation, swiftui-managing-ui-state, swift-mainactor]
cards:
  - id: m36-l04-c1
    front: "@StateObject vs @ObservedObject?"
    back: "@StateObject creates and owns the object: SwiftUI runs its initializer autoclosure only once per view identity. @ObservedObject only watches an object someone else owns and passes in. Apple: don't give @ObservedObject a default or initial value."
  - id: m36-l04-c2
    front: What's the classic @ObservedObject bug?
    back: "@ObservedObject var model = Model() in a view. Every time the parent's body runs, the view struct is recreated, Model() runs again, and the view starts observing a fresh, empty model. Data vanishes on unrelated updates. Use @StateObject (or @State with @Observable)."
  - id: m36-l04-c3
    front: How does ObservableObject invalidation differ from @Observable?
    back: "ObservableObject has one objectWillChange signal, so any @Published change updates every view observing the object, even views that never read that property. @Observable tracks per property: only views whose body read the changed property update."
  - id: m36-l04-c4
    front: What are the steps to migrate from ObservableObject to @Observable?
    back: "Replace ObservableObject with @Observable and delete @Published (add @ObservationIgnored to anything that shouldn't be tracked). Then @StateObject → @State, environmentObject(_:) → environment(_:), @EnvironmentObject → @Environment(Type.self), @ObservedObject → a plain property, or @Bindable where you need bindings."
  - id: m36-l04-c5
    front: When do you still use ObservableObject?
    back: "When the deployment target is below iOS 17, in existing code you aren't migrating yet, and where you rely on Combine publishers from @Published properties ($query.debounce…). It isn't deprecated."
---

## The idea in one sentence

`ObservableObject` is the pre-iOS 17 way to make a model drive SwiftUI views: the object announces "I'm about to change" as a whole, and views hold it with `@StateObject` (I own it), `@ObservedObject` (I was given it) or `@EnvironmentObject` (an ancestor supplied it).

> [!note] About this lesson's code
> `ObservableObject` and `@Published` come from Combine, which exists only on Apple platforms, so the SwiftUI and Combine blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. The storage and invalidation models are plain Swift (plus Observation), compiled and run with Swift 6.3; they model documented behavior, not SwiftUI's implementation. Quotes come from Apple's pages for `ObservableObject`, `Published`, `StateObject`, `ObservedObject`, `EnvironmentObject` and the migration guide, read in November 2026.

## Why you still need this

This course targets iOS 17, so new code uses Observation (lessons 2 and 3). But `ObservableObject` isn't deprecated, and you'll meet it constantly:

- **Existing apps.** Anything written between 2019 and 2023, and much written since, uses it.
- **Deployment targets below iOS 17.** Observation in SwiftUI needs iOS 17.
- **Combine pipelines.** `@Published` properties are publishers (`$query`), and some code builds debouncing and validation on them.

Reading it fluently, and knowing its one classic bug, is part of the job.

## How ObservableObject works

```swift ios
import SwiftUI
import Combine

@MainActor
final class SettingsModel: ObservableObject {
    @Published var displayName = "Ana"
    @Published var isPublic = false
    var lastSyncDescription = "never"      // not @Published: changing it doesn't update views
}

struct SettingsScreen: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            TextField("Display name", text: $model.displayName)
            PrivacyRow(model: model)
        }
    }
}

struct PrivacyRow: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Toggle("Public profile", isOn: $model.isPublic)
    }
}
```

- **`ObservableObject`** gives the class an `objectWillChange` publisher. Apple: "By default an `ObservableObject` synthesizes an `objectWillChange` publisher that emits the changed value before any of its `@Published` properties changes."
- **`@Published`** marks the properties that trigger it. Apple's `Published` page: "publishing occurs in the property's `willSet` block". A plain `var` like `lastSyncDescription` doesn't publish, so changing it alone doesn't update any view. That's the opposite default from `@Observable`, where every stored `var` is tracked unless you opt out.
- **`@StateObject private var model = SettingsModel()`** in the screen that creates the model. Apple: "Use a state object as the single source of truth for a reference type that you store in a view hierarchy."
- **`@ObservedObject var model: SettingsModel`** in the child that receives it. Apple: "You typically do this to pass a `StateObject` into a subview." No default value.
- **`$model.displayName`** works with both wrappers: their projected value gives bindings to the object's properties, the job `@Bindable` does for `@Observable`.

### One signal for the whole object

SwiftUI subscribes a view to the object's single `objectWillChange`. It doesn't know which property changed, so every view observing the object updates. Apple's migration guide: "a view updates when any published property of an `ObservableObject` instance changes, even if the view doesn't read the property that changes." With Observation, the same guide says, "SwiftUI updates a view only when an observable property changes and the view's `body` reads the property directly."

A model of both, side by side. The `ObservableObject` stand-in has one `willSet` signal for any property; the `@Observable` version is real Observation:

```swift
import Observation

/// A model of ObservableObject: one "will change" signal for the whole object.
@MainActor
final class ProfileObject {
    var observers: [String] = []
    var name = "Ana" { willSet { objectWillChange() } }
    var bio = "" { willSet { objectWillChange() } }

    private func objectWillChange() {
        print("  ObservableObject invalidates:", observers.joined(separator: ", "))
    }
}

/// The same data with Observation: one signal per property read.
@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class Profile {
    var name = "Ana"
    var bio = ""
}

@available(macOS 14, iOS 17, *)
@MainActor
func track(_ view: String, _ read: @escaping @MainActor () -> Void) {
    withObservationTracking {
        read()
    } onChange: {
        print("  @Observable invalidates:", view)
    }
}

if #available(macOS 14, iOS 17, *) {
    let object = ProfileObject()
    object.observers = ["Header", "BioEditor"]   // both views hold the object

    let profile = Profile()
    track("Header") { _ = profile.name }          // Header reads only name
    track("BioEditor") { _ = profile.bio }        // BioEditor reads only bio

    print("edit bio")
    object.bio = "iOS engineer"
    profile.bio = "iOS engineer"
}
```

```output
edit bio
  ObservableObject invalidates: Header, BioEditor
  @Observable invalidates: BioEditor
```

Editing the bio invalidates the header too in the `ObservableObject` model, though the header shows only the name. In a large screen that's a lot of wasted `body` evaluations, and the usual workaround was splitting one model into several objects. With Observation the split happens per property, automatically.

## @StateObject vs @ObservedObject: the classic bug

Apple's `ObservedObject` page is direct: "Don't specify a default or initial value for the observed object. Use the attribute only for a property that acts as an input for a view." Here's what happens when you do:

```swift ios
import SwiftUI
import Combine

@MainActor
final class StopwatchModel: ObservableObject {
    @Published var seconds = 0
}

struct StopwatchView: View {
    @ObservedObject var model = StopwatchModel()   // the bug

    var body: some View {
        VStack {
            Text("\(model.seconds) s")
            Button("Add a second") { model.seconds += 1 }
        }
    }
}

struct WorkoutScreen: View {
    @State private var heartRate = 72

    var body: some View {
        VStack {
            Text("\(heartRate) bpm")
            StopwatchView()
            Button("Heart rate +1") { heartRate += 1 }
        }
    }
}
```

Tap "Add a second" a few times, then "Heart rate +1": the stopwatch drops back to 0. Changing `heartRate` runs `WorkoutScreen.body`, which creates a new `StopwatchView` struct, whose property initializer runs `StopwatchModel()` again. `@ObservedObject` just holds whatever it's given, so the view now observes a brand-new model. Nothing crashes, and the bug only shows when an unrelated parent state changes, which is why it survives code review.

`@StateObject` fixes it because its initializer takes an **autoclosure**: `init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType)`. Apple: "SwiftUI creates only one instance of the state object for each container instance that you declare." The closure that builds the model runs once per view identity.

A plain-Swift model of both wrappers. `ObservedModel` keeps what it's given; `StateModel` takes an autoclosure and calls it only if nothing is stored for its identity:

```swift
/// Models of @ObservedObject and @StateObject storage, not SwiftUI's implementation.
@MainActor
final class ObjectStorage {
    var objects: [String: AnyObject] = [:]
}

let storage = ObjectStorage()

/// Like @ObservedObject: holds whatever the initializer gives it.
@MainActor
@propertyWrapper
struct ObservedModel<Value: AnyObject> {
    let wrappedValue: Value
}

/// Like @StateObject: runs the autoclosure only the first time for this identity.
@MainActor
@propertyWrapper
struct StateModel<Value: AnyObject> {
    private let identity: String

    init(wrappedValue make: @autoclosure () -> Value, identity: String) {
        self.identity = identity
        if storage.objects[identity] == nil {
            storage.objects[identity] = make()
        }
    }

    var wrappedValue: Value {
        storage.objects[identity] as! Value
    }
}

@MainActor
final class StopwatchModel {
    static var created = 0
    let number: Int
    var seconds = 0

    init() {
        StopwatchModel.created += 1
        number = StopwatchModel.created
        print("StopwatchModel #\(number) created")
    }
}

@MainActor
struct BuggyStopwatch {
    @ObservedModel var model = StopwatchModel()

    func body() -> String {
        "buggy: model #\(model.number), \(model.seconds)s"
    }
}

@MainActor
struct FixedStopwatch {
    @StateModel(identity: "Root/FixedStopwatch") var model = StopwatchModel()

    func body() -> String {
        "fixed: model #\(model.number), \(model.seconds)s"
    }
}

var buggy = BuggyStopwatch()
var fixed = FixedStopwatch()
buggy.model.seconds = 42
fixed.model.seconds = 42
print(buggy.body())
print(fixed.body())

print("-- the parent's body runs again")
buggy = BuggyStopwatch()
fixed = FixedStopwatch()
print(buggy.body())
print(fixed.body())
```

```output
StopwatchModel #1 created
StopwatchModel #2 created
buggy: model #1, 42s
fixed: model #2, 42s
-- the parent's body runs again
StopwatchModel #3 created
buggy: model #3, 0s
fixed: model #2, 42s
```

Look at when models are created:

- **First appearance.** Each view creates its model: #1 for the buggy view, #2 for the fixed one. Both reach 42 seconds.
- **The parent re-renders.** The buggy view's initializer builds model #3, and the view now shows 0 seconds. The fixed view's autoclosure isn't called again, so it keeps #2 and its 42 seconds.

Compare lesson 2: the `@State` property wrapper (Xcode 26 SDK) evaluates its default value every time and keeps the first, so the data survives but the extra objects are built. `@StateObject`'s autoclosure avoids even building them.

> [!warning] The same rule for passed-in values
> Apple's `StateObject` page shows `_model = StateObject(wrappedValue: DataModel(name: name))` in a view's `init`, and warns that "SwiftUI only initializes a state object the first time you call its initializer in a given view", so a later change to `name` has no effect. If the model must be rebuilt when an input changes, change the view's identity with `.id(name)`, which lesson 5 covers.

## @EnvironmentObject

The `ObservableObject` version of lesson 3's environment injection:

```swift ios
import SwiftUI
import Combine

@MainActor
final class CartModel: ObservableObject {
    @Published var items: [String] = []
}

struct ShopRoot: View {
    @StateObject private var cart = CartModel()

    var body: some View {
        NavigationStack {
            ProductList()
        }
        .environmentObject(cart)
    }
}

struct ProductList: View {
    var body: some View {
        List(["Mug", "Poster"], id: \.self) { product in
            AddToCartRow(product: product)
        }
    }
}

struct AddToCartRow: View {
    let product: String
    @EnvironmentObject private var cart: CartModel

    var body: some View {
        Button("Add \(product) (\(cart.items.count) in cart)") {
            cart.items.append(product)
        }
    }
}
```

`environmentObject(_:)` supplies the object by type and `@EnvironmentObject` reads it, with no default. Apple's page says to "be sure to set a corresponding model object on an ancestor view". If no ancestor did, the app traps at run time when the view reads the property; that's the widely reported behavior, and the reference page doesn't describe the failure itself. The fix is the same as in lesson 3: inject on every root, previews included.

> [!error] An ObservableObject in @State
> `@State private var model = SettingsModel()` with an `ObservableObject` compiles and keeps the instance, but Apple's `State` page notes that "the view will only update when the reference to the object changes", not when its published properties change. Use `@StateObject` for `ObservableObject`, `@State` for `@Observable`.

## Migrating to @Observable

Apple's guide, "Migrating from the Observable Object protocol to the Observable macro", walks through it in order. Applied to the settings screen from the start of the lesson:

| Before | After |
| --- | --- |
| `final class SettingsModel: ObservableObject` | `@Observable final class SettingsModel` |
| `@Published var displayName` | `var displayName` |
| A plain `var` that shouldn't trigger updates | `@ObservationIgnored var …` |
| `@StateObject private var model = SettingsModel()` | `@State private var model = SettingsModel()` |
| `@ObservedObject var model: SettingsModel` | `var model: SettingsModel`, or `@Bindable var model: SettingsModel` if the view needs `$model.property` |
| `.environmentObject(model)` | `.environment(model)` |
| `@EnvironmentObject var model: SettingsModel` | `@Environment(SettingsModel.self) private var model` |

```swift ios
import SwiftUI

@MainActor
@Observable
final class SettingsModel {
    var displayName = "Ana"
    var isPublic = false
    @ObservationIgnored var lastSyncDescription = "never"
}

struct SettingsScreen: View {
    @State private var model = SettingsModel()

    var body: some View {
        Form {
            TextField("Display name", text: $model.displayName)
            PrivacyRow(model: model)
        }
    }
}

struct PrivacyRow: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Toggle("Public profile", isOn: $model.isPublic)
    }
}
```

Three things to check after migrating:

1. **Formerly unpublished properties are now tracked.** `lastSyncDescription` didn't trigger updates before. Without `@ObservationIgnored` it would now. Usually that's a fix (a view showing it was stale before), but decide on purpose.
2. **Views update less.** Apple: "You may notice slight behavioral differences in your app based on the tracking method." A view that only looked right because an unrelated `@Published` change refreshed it will now show its real dependencies.
3. **`$model.property` publishers are gone.** Combine code that subscribed to `$query` needs another approach. On iOS 26 and later, Observation's `Observations` type is "an asynchronous sequence generated from a closure that tracks the transactional changes of `@Observable` types" (Apple's page); on iOS 17, a `didSet` or an explicit method call is often enough.

You can migrate one type at a time; Apple: "Your app can mix data model types that use different observation systems." The guide also says that during the migration "data flow property wrappers such as `StateObject` and `EnvironmentObject` support types that use the `Observable()` macro", but the declarations on Apple's current `StateObject` and `EnvironmentObject` pages constrain them to `ObservableObject`. This lesson didn't verify how that mixing compiles, so migrate a type and its wrappers together.

## When you'll still write ObservableObject

- **Your deployment target is iOS 16 or earlier.** Then it's the only option.
- **The team relies on `@Published` publishers.** A search field that debounces through Combine is short and readable:

```swift ios
import SwiftUI
import Combine

@MainActor
final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [String] = []

    private let allTitles = ["Kindred", "Piranesi", "Klara and the Sun"]

    init() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { [allTitles] query in
                query.isEmpty ? [] : allTitles.filter { $0.localizedCaseInsensitiveContains(query) }
            }
            .assign(to: &$results)
    }
}
```

- **You're changing existing code.** Fix the bug you came for. Migrating the whole model layer at the same time makes the change hard to review; do it as its own change, one type at a time.

## Common mistakes

> [!error] @ObservedObject with a default value
> `@ObservedObject var model = Model()` creates a new model whenever the parent's body runs. If the view creates the model, use `@StateObject private var model = Model()`. If the parent owns it, remove the default and pass it in.

> [!error] Forgetting @Published
> A property without `@Published` never triggers `objectWillChange`. Views showing it update only when something else does. (After migrating to `@Observable`, the opposite: everything is tracked unless ignored.)

> [!error] Mixing the two families
> `@StateObject` or `@ObservedObject` with an `@Observable` class, or `@Bindable` and `@Environment(Type.self)` with an `ObservableObject`. Each family has its own wrappers: `@StateObject`/`@ObservedObject`/`@EnvironmentObject` for `ObservableObject`; `@State`/plain property/`@Bindable`/`@Environment` for `@Observable`.

> [!error] Expecting a passed-in value to rebuild a @StateObject
> `StateObject(wrappedValue: Model(id: id))` in `init` uses the first `id` forever. Rebuild on purpose with `.id(id)` on the view.

## Exercises

````exercise
id: m36-l04-e1
type: prediction
prompt: "The storage models from the lesson: a screen that owns a cart with StateModel and passes it to a badge with ObservedModel, and a banner that creates its own cart with an ObservedModel default. The screen and banner are recreated once, like a parent re-render. What does it print?"
code: |
  @MainActor
  final class ObjectStorage {
      var objects: [String: AnyObject] = [:]
  }

  let storage = ObjectStorage()

  /// Like @ObservedObject: holds whatever the initializer gives it.
  @MainActor
  @propertyWrapper
  struct ObservedModel<Value: AnyObject> {
      let wrappedValue: Value
  }

  /// Like @StateObject: runs the autoclosure only the first time for this identity.
  @MainActor
  @propertyWrapper
  struct StateModel<Value: AnyObject> {
      private let identity: String

      init(wrappedValue make: @autoclosure () -> Value, identity: String) {
          self.identity = identity
          if storage.objects[identity] == nil {
              storage.objects[identity] = make()
          }
      }

      var wrappedValue: Value {
          storage.objects[identity] as! Value
      }
  }

  @MainActor
  final class CartModel {
      static var created = 0
      let number: Int
      var items = 0

      init() {
          CartModel.created += 1
          number = CartModel.created
      }
  }

  @MainActor
  struct CartScreen {
      @StateModel(identity: "CartScreen") var cart = CartModel()

      var badge: CartBadge { CartBadge(cart: cart) }
  }

  @MainActor
  struct CartBadge {
      @ObservedModel var cart: CartModel

      func body() -> String { "badge: cart #\(cart.number), items \(cart.items)" }
  }

  @MainActor
  struct PromoBanner {
      @ObservedModel var cart = CartModel()

      func body() -> String { "banner: cart #\(cart.number), items \(cart.items)" }
  }

  var screen = CartScreen()
  var banner = PromoBanner()
  screen.cart.items += 2
  banner.cart.items += 1
  print(screen.badge.body())
  print(banner.body())

  screen = CartScreen()
  banner = PromoBanner()
  screen.badge.cart.items += 1
  print(screen.badge.body())
  print(banner.body())
output: |
  badge: cart #1, items 2
  banner: cart #2, items 1
  badge: cart #1, items 3
  banner: cart #3, items 0
hints:
  - "CartBadge doesn't create anything; it holds the cart CartScreen gives it."
  - "PromoBanner's default value runs every time a PromoBanner is created."
  - "CartScreen's autoclosure runs only the first time for its identity."
solution: |
  ```output
  badge: cart #1, items 2
  banner: cart #2, items 1
  badge: cart #1, items 3
  banner: cart #3, items 0
  ```

  - The first `CartScreen` creates cart #1 through its `StateModel`; the first `PromoBanner` creates #2 through its default. They get 2 and 1 items.
  - Recreating `CartScreen` doesn't call its autoclosure again: the badge still shows cart #1, which now gets its third item.
  - Recreating `PromoBanner` runs `CartModel()` again: cart #3, empty. The banner lost its data, which is the `@ObservedObject` default-value bug.

  The badge is the correct use of `@ObservedObject`: it receives a model owned elsewhere. The banner should either own its cart with `@StateObject` or receive the screen's cart.
````

````exercise
id: m36-l04-e2
type: comprehension
prompt: "An ObservableObject has @Published var title and @Published var progress, which changes ten times a second during a download. HeaderView observes the object and reads only title. How often does HeaderView's body run during the download, and what would change after migrating to @Observable?"
choices:
  - text: "About ten times a second, because any @Published change fires objectWillChange for every observing view; after migrating, it runs only when title changes."
    correct: true
    why: "ObservableObject has one signal for the whole object. Observation tracks per property read."
  - text: "Only when title changes, because SwiftUI compares the values HeaderView reads."
    correct: false
    why: "That's Observation's behavior. With ObservableObject, Apple says a view updates when any published property changes, even ones it doesn't read."
  - text: "Never, because @ObservedObject only updates on reference changes."
    correct: false
    why: "That describes an ObservableObject stored in @State. @ObservedObject subscribes to objectWillChange."
  - text: "Ten times a second both before and after migrating."
    correct: false
    why: "After migrating, HeaderView depends only on title."
solution: |
  **Ten times a second, then only on title changes.** Every assignment to `progress` fires the object's single `objectWillChange`, and SwiftUI invalidates every view subscribed to the object, `HeaderView` included. The classic fix was to move `progress` into a separate object. With `@Observable`, `HeaderView`'s body read only `title`, so `progress` changes don't affect it.
````

````exercise
id: m36-l04-e3
type: fill-in
prompt: "Complete the pre-iOS 17 version: the screen owns the model, the row receives it, and a deep view reads it from the environment."
code: |
  import SwiftUI
  import Combine

  @MainActor
  final class PlayerModel: [[1]] {
      [[2]] var isPlaying = false
  }

  struct PlayerScreen: View {
      [[3]] private var player = PlayerModel()

      var body: some View {
          VStack {
              PlayButtonRow(player: player)
              NowPlayingFooter()
          }
          .[[4]](player)
      }
  }

  struct PlayButtonRow: View {
      [[5]] var player: PlayerModel

      var body: some View {
          Toggle("Playing", isOn: $player.isPlaying)
      }
  }

  struct NowPlayingFooter: View {
      @EnvironmentObject private var player: PlayerModel

      var body: some View {
          Text(player.isPlaying ? "Playing" : "Paused")
      }
  }
blanks:
  - id: "1"
    answers: ["ObservableObject"]
  - id: "2"
    answers: ["@Published"]
  - id: "3"
    answers: ["@StateObject"]
  - id: "4"
    answers: ["environmentObject"]
  - id: "5"
    answers: ["@ObservedObject"]
hints:
  - "Owning an ObservableObject and receiving one use different wrappers."
  - "The environment modifier for ObservableObject has Object in its name."
solution: |
  ```swift ios
  import SwiftUI
  import Combine

  @MainActor
  final class PlayerModel: ObservableObject {
      @Published var isPlaying = false
  }

  struct PlayerScreen: View {
      @StateObject private var player = PlayerModel()

      var body: some View {
          VStack {
              PlayButtonRow(player: player)
              NowPlayingFooter()
          }
          .environmentObject(player)
      }
  }

  struct PlayButtonRow: View {
      @ObservedObject var player: PlayerModel

      var body: some View {
          Toggle("Playing", isOn: $player.isPlaying)
      }
  }

  struct NowPlayingFooter: View {
      @EnvironmentObject private var player: PlayerModel

      var body: some View {
          Text(player.isPlaying ? "Playing" : "Paused")
      }
  }
  ```

  `ObservableObject` plus `@Published` makes the model publish. The screen creates it, so `@StateObject`. The row receives it and needs `$player.isPlaying`, so `@ObservedObject`. `.environmentObject(player)` lets the footer read it with `@EnvironmentObject`.
````

````exercise
id: m36-l04-e4
type: solve
prompt: "Migrate the solution of the previous exercise to Observation for an iOS 17 target, following Apple's migration steps. Keep the same behavior: the screen owns the model, the row binds a toggle to it, and the footer reads it from the environment."
starter: |
  // Start from the PlayerModel / PlayerScreen / PlayButtonRow / NowPlayingFooter
  // code in exercise 3's solution.
hints:
  - "Model: @Observable instead of ObservableObject, and no @Published."
  - "@StateObject → @State, .environmentObject → .environment, @EnvironmentObject → @Environment(PlayerModel.self)."
  - "The row needs a binding, so @ObservedObject becomes @Bindable."
rubric:
  - PlayerModel uses @Observable and has no @Published or ObservableObject.
  - The screen uses @State and .environment(player).
  - The row uses @Bindable (not a plain property, because it needs $player.isPlaying).
  - The footer uses @Environment(PlayerModel.self).
  - No Combine import is needed.
solution: |
  ```swift ios
  import SwiftUI

  @MainActor
  @Observable
  final class PlayerModel {
      var isPlaying = false
  }

  struct PlayerScreen: View {
      @State private var player = PlayerModel()

      var body: some View {
          VStack {
              PlayButtonRow(player: player)
              NowPlayingFooter()
          }
          .environment(player)
      }
  }

  struct PlayButtonRow: View {
      @Bindable var player: PlayerModel

      var body: some View {
          Toggle("Playing", isOn: $player.isPlaying)
      }
  }

  struct NowPlayingFooter: View {
      @Environment(PlayerModel.self) private var player

      var body: some View {
          Text(player.isPlaying ? "Playing" : "Paused")
      }
  }
  ```

  Each line follows a row of the migration table. Two choices to notice: the row becomes `@Bindable`, not a plain `let`, because it passes `$player.isPlaying` to the toggle; and `import Combine` goes away because nothing uses Combine any more. Behavior is the same here, except that a view now updates only for the properties it reads, which with one property makes no visible difference.
````

````exercise
id: m36-l04-e5
type: find-errors
prompt: "This code targets iOS 16. Which of these are real problems?"
code: |
  import SwiftUI
  import Combine

  final class FeedModel: ObservableObject {
      @Published var posts: [String] = []
      var isRefreshing = false

      func refresh() {
          isRefreshing = true
          posts = ["New post"] + posts
          isRefreshing = false
      }
  }

  struct FeedScreen: View {
      @ObservedObject var model = FeedModel()
      @State private var filter = ""

      var body: some View {
          VStack {
              TextField("Filter", text: $filter)
              if model.isRefreshing { ProgressView() }
              List(model.posts.filter { filter.isEmpty || $0.contains(filter) }, id: \.self) { Text($0) }
              Button("Refresh") { model.refresh() }
          }
      }
  }
choices:
  - text: "@ObservedObject with a default value: the screen loses its posts whenever its parent re-renders."
    correct: true
    why: "The view creates the model, so it should own it with @StateObject."
  - text: "isRefreshing isn't @Published, so changing it doesn't trigger an update by itself."
    correct: true
    why: "Only @Published properties fire objectWillChange. Here the spinner is also wrong for another reason: refresh() is synchronous, so the flag is true only inside one call."
  - text: "The code should use @Observable instead."
    correct: false
    why: "Observation in SwiftUI needs iOS 17. On an iOS 16 target, ObservableObject is the right API."
  - text: "Typing in the filter field rebuilds FeedModel, because filter is @State in the same view."
    correct: false
    why: "Changing the view's own @State re-runs its body but doesn't recreate the view struct or its property initializers. The parent re-rendering does."
  - text: "TextField can't bind to @State in a view that also has an @ObservedObject."
    correct: false
    why: "Views can mix any wrappers. $filter is an ordinary binding."
rubric:
  - Flags the @ObservedObject default value and proposes @StateObject.
  - Flags the unpublished isRefreshing (and ideally notes the synchronous refresh).
  - Doesn't propose @Observable for an iOS 16 target.
  - Doesn't blame the filter state for recreating the model.
solution: |
  Two real problems:

  1. **`@ObservedObject var model = FeedModel()`.** `FeedScreen` creates the model, so it must own it: `@StateObject private var model = FeedModel()`. Otherwise every update of the parent produces a new, empty feed.
  2. **`isRefreshing` isn't `@Published`.** Changing it alone doesn't notify views; it only shows correctly when `posts` changes in the same moment. Mark it `@Published`. (And since `refresh()` sets it to true and back to false synchronously, no frame ever shows the spinner; a real refresh is `async`, covered in Module 37.)

  On iOS 16, `@Observable` isn't available to SwiftUI, so `ObservableObject` is correct here. Typing in the filter re-runs `FeedScreen.body` but doesn't re-create `FeedScreen` itself; it's the parent's updates that trigger the bug.
````

````exercise
id: m36-l04-e6
type: explain
prompt: "A teammate migrated a model to @Observable, and now a status label that used to update is stuck. Before the migration, InboxModel was an ObservableObject with @Published var items and a plain, unpublished var statusText, which sync() set right before appending to items. This is the code after the migration. Explain why the label worked before, why it's stuck now, and what the right fix is."
code: |
  @Observable
  final class InboxModel {
      var items: [String] = []
      @ObservationIgnored var statusText = ""   // added "to keep the old behavior"

      func sync() {
          statusText = "Synced just now"
          items.append("New message")
      }
  }

  struct StatusLabel: View {
      let model: InboxModel

      var body: some View {
          Text(model.statusText)
      }
  }
rubric:
  - Explains that with ObservableObject the label updated only because the items change invalidated every view observing the object.
  - Explains that with @Observable the label depends only on what its body read, and statusText is ignored, so nothing invalidates it.
  - Recommends removing @ObservationIgnored so statusText is tracked.
  - Notes that the old code had a latent bug (changing statusText alone never updated anything).
solution: |
  **Before:** `statusText` wasn't `@Published`, so setting it notified no one. The label still looked right because `sync()` also appended to `items`, and with `ObservableObject` any `@Published` change invalidates every view observing the object, including the label. It worked by accident; setting `statusText` without touching `items` would have left the label stale.

  **Now:** `StatusLabel`'s body reads only `statusText`, and `@ObservationIgnored` removed it from tracking. The label has no dependencies, so no change ever updates it. Ignoring it didn't "keep the old behavior"; it kept the old bug and removed the accident that hid it.

  **Fix:** delete `@ObservationIgnored`. A property a view displays should be tracked. Now the label updates whenever `statusText` changes, whether or not `items` does.
````

## Summary

- `ObservableObject` classes publish one `objectWillChange` signal, fired in `willSet` of any `@Published` property. Unpublished properties notify no one.
- `@StateObject` owns: its autoclosure runs once per view identity. `@ObservedObject` receives: never give it a default value, or the model is rebuilt on every parent update. `@EnvironmentObject` reads what `environmentObject(_:)` supplied.
- Every view observing an `ObservableObject` updates on any published change. `@Observable` narrows that to properties each body read.
- Migrate per Apple's guide: `@Observable` and no `@Published`, then `@State`, `.environment`, `@Environment(Type.self)`, and a plain property or `@Bindable`. Check for newly tracked properties and Combine code that used `$property`.
- Keep `ObservableObject` for targets below iOS 17, for Combine-based code, and in existing code until you migrate on purpose.
