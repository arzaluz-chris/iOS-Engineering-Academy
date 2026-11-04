---
id: m36-l03
title: The environment
description: "The environment is a set of values that flows down the view tree: the system's color scheme, Dynamic Type size and locale, values you override for a subtree, values you define yourself with @Entry, and @Observable models you inject with .environment(_:) and read with @Environment(Type.self). You model how values propagate, see why custom defaults must be Sendable in Swift 6, and decide when the environment is the right tool and when a plain parameter is better."
module: m36
order: 3
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l02]
objectives:
  - Read built-in environment values with @Environment and a key path, and override them for a subtree.
  - "Explain how environment values propagate: down only, nearest setting wins, with a few combining exceptions such as disabled(_:)."
  - Define a custom environment value with @Entry, or with EnvironmentKey in older code, plus a convenience modifier.
  - Inject an @Observable model with .environment(_:), read it with @Environment(Type.self), and get bindings to it with a local @Bindable.
  - Choose between the environment and an initializer parameter for a given dependency.
terms:
  - term: Environment (SwiftUI)
    definition: "A collection of values (EnvironmentValues) that SwiftUI passes down the view hierarchy. Each view sees the values set by its ancestors, the system's values, or each key's default."
  - term: "@Environment"
    definition: "A property wrapper that reads a value from the view's environment, by key path (@Environment(\\.locale)) or, for an @Observable object, by type (@Environment(Session.self)). It reads; it doesn't set."
  - term: "@Entry"
    definition: "A SwiftUI macro that declares a custom environment value (and transaction, container and focused values) in an extension, generating the key type for you. Apple's page lists it as available from iOS 13."
  - term: EnvironmentKey
    definition: "The protocol behind environment values: a key type with a static defaultValue. Before @Entry you wrote one per custom value, plus a computed property on EnvironmentValues."
  - term: "environment(_:)"
    definition: "The modifier (iOS 17) that places an @Observable object in a subtree's environment, keyed by its type. One object per type per subtree."
mastery:
  - Read colorScheme and dynamicTypeSize in a view and adapt its layout.
  - Predict the value a deeply nested view sees after overrides at several levels.
  - Write an @Entry value with a Sendable type and a View extension that sets it.
  - Inject a session model at the root and read it, with and without a binding, several levels down.
  - Give a reason for passing a value as a parameter instead of through the environment.
resources: [swiftui-environment, swiftui-entry, swiftui-environmentvalues, swiftui-migrating-to-observable, swiftui-scenephase, swift-sendable]
cards:
  - id: m36-l03-c1
    front: How do environment values propagate?
    back: "Down the view tree only. A modifier like .environment(\\.locale, …) or .font(…) affects that view and its descendants, \"but only up to the point where you apply a different environment modifier\" (Apple). Siblings and ancestors are unaffected."
  - id: m36-l03-c2
    front: How do you declare a custom environment value today?
    back: "extension EnvironmentValues { @Entry var cardDensity: CardDensity = .regular }. Read it with @Environment(\\.cardDensity), set it with .environment(\\.cardDensity, .compact) or a View extension that calls that."
  - id: m36-l03-c3
    front: How do you put an @Observable model in the environment and read it?
    back: "Set it with .environment(model) (usually on the root, where the model is in @State). Read it with @Environment(Model.self) private var model. If it might be missing, declare the type as Model? to get nil instead of a crash."
  - id: m36-l03-c4
    front: How do you get a binding to a property of a model read from the environment?
    back: "Inside body, write @Bindable var model = model, then use $model.property. @Environment itself has no $ projection for an object's properties."
  - id: m36-l03-c5
    front: Environment or parameter?
    back: "Parameter when the view needs the value to do its job and the parent has it: explicit and checked by the compiler. Environment for context that many views at different depths use (theme, locale, session, services), where threading a parameter through every level is noise."
---

## The idea in one sentence

The environment is a dictionary of values that flows **down** the view tree, so a view several levels deep can read context (the color scheme, the locale, the signed-in session) without every view in between passing it along.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Behavior comes from Apple's pages for `Environment`, `EnvironmentValues`, `Entry()`, `EnvironmentKey`, `environment(_:)` and "Managing model data in your app", read in November 2026. The propagation model and the Sendable diagnostic are plain Swift, compiled with Swift 6.3; the model shows the rules, not SwiftUI's implementation.

## Reading built-in values

You've already read a few: `@Environment(\.dismiss)` in Module 35, `\.horizontalSizeClass` for adaptive layout, `\.accessibilityReduceMotion` for animation. Apple's `EnvironmentValues` page: "SwiftUI automatically sets or updates many environment values, like `pixelLength`, `scenePhase`, or `locale`, based on device characteristics, system state, or user settings. For others, like `lineLimit`, SwiftUI provides a reasonable default value."

```swift ios
import SwiftUI

struct ProfileHeader: View {
    let name: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())

        layout {
            Image(systemName: "person.crop.circle.fill")
                .font(.largeTitle)
            Text(name)
                .font(.headline)
        }
        .padding()
        .background(colorScheme == .dark ? Color.indigo.opacity(0.3) : Color.orange.opacity(0.15))
    }
}
```

- **`@Environment(\.colorScheme)`** takes a key path into `EnvironmentValues`. The property is read-only from the view's side; Apple: "You can use this property wrapper to read — but not set — an environment value."
- **When the value changes, the view updates.** Apple: "If the value changes, SwiftUI updates any parts of your view that depend on the value", for example when the user switches to Dark Mode or changes the text size.
- **`isAccessibilitySize`** is true for the five largest Dynamic Type sizes. Switching to a vertical layout there is the kind of adaptation Module 23 asked of UIKit screens.

## Setting values for a subtree

You set or override a value with `environment(_:_:)`, or more often with a dedicated modifier:

```swift ios
import SwiftUI

struct SettingsPreview: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Default locale and font")
            VStack(alignment: .leading) {
                Text(Date.now, style: .date)
                Text("Smaller text inside")
                    .font(.footnote)
            }
            .environment(\.locale, Locale(identifier: "es_MX"))
            .font(.title3)
        }
    }
}
```

Apple describes the rule: "The value that you set affects the environment for the view that you modify — including its descendants in the view hierarchy — but only up to the point where you apply a different environment modifier." Modifiers like `.font(_:)` and `.lineLimit(_:)` are environment setters with a nicer name. Apple prefers them: "SwiftUI provides dedicated view modifiers for setting some values, which typically makes your code easier to read."

Here's a model of the propagation: each node gets a **copy** of its parent's environment, applies its own changes, and passes the result to its children.

```swift
/// A model of how environment values flow down a view tree, not SwiftUI's implementation.
protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

struct EnvironmentValues {
    private var values: [ObjectIdentifier: Any] = [:]

    subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
        get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}

struct LocaleKey: EnvironmentKey {
    static let defaultValue = "en_US"
}

extension EnvironmentValues {
    var locale: String {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}

struct Node {
    let name: String
    var modify: (inout EnvironmentValues) -> Void = { _ in }
    var children: [Node] = []
}

func render(_ node: Node, in environment: EnvironmentValues, depth: Int = 0) {
    var environment = environment          // a copy: changes go down, never up or sideways
    node.modify(&environment)
    print(String(repeating: "  ", count: depth) + "\(node.name): \(environment.locale)")
    for child in node.children {
        render(child, in: environment, depth: depth + 1)
    }
}

let app = Node(name: "App", children: [
    Node(name: "Settings", modify: { $0.locale = "es_MX" }, children: [
        Node(name: "LanguageRow"),
        Node(name: "PreviewCard", modify: { $0.locale = "fr_FR" }),
    ]),
    Node(name: "Inbox"),
])

render(app, in: EnvironmentValues())
```

```output
App: en_US
  Settings: es_MX
    LanguageRow: es_MX
    PreviewCard: fr_FR
  Inbox: en_US
```

The copy is the whole rule. `Settings` changes its copy, so its children see `es_MX`. `PreviewCard` changes its own copy again. `Inbox`, a sibling, got `App`'s environment, which `Settings` never touched. Nothing flows up.

> [!note] Not every value is "nearest wins"
> `disabled(_:)` combines instead. Apple: a `.disabled(true)` on a container overrides "any `.disabled(_:)` modifiers you set on views within the container", so a button marked `.disabled(false)` inside a disabled `VStack` is still disabled. Exercise 1 models both behaviors. When in doubt, read the modifier's page.

## Custom values with @Entry

To add your own value, extend `EnvironmentValues` and mark the property `@Entry`. Apple's `Entry()` page shows the form: `@Entry var myCustomValue: String = "Default value"`. Apple's page lists the macro as available from iOS 13, because what it generates is ordinary code that runs on old systems. The macro itself is newer than that: it shipped with Xcode 16 in 2024 (that date isn't on the reference page), so older codebases use `EnvironmentKey`, shown below. This course's checks use Xcode 26.6.

```swift ios
import SwiftUI

enum CardDensity: Sendable {
    case regular, compact
}

extension EnvironmentValues {
    @Entry var cardDensity: CardDensity = .regular
}

extension View {
    func cardDensity(_ density: CardDensity) -> some View {
        environment(\.cardDensity, density)
    }
}

struct TaskCard: View {
    let title: String
    @Environment(\.cardDensity) private var density

    var body: some View {
        Text(title)
            .padding(density == .compact ? 6 : 16)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct TaskBoard: View {
    var body: some View {
        VStack {
            TaskCard(title: "Regular card")
            VStack {
                TaskCard(title: "Compact card")
                TaskCard(title: "Another compact card")
            }
            .cardDensity(.compact)
        }
    }
}
```

- **`@Entry var cardDensity: CardDensity = .regular`** declares the value and its default. The macro generates the key type that older code wrote by hand.
- **`func cardDensity(_:)`** is the convenience modifier. Apple's `EnvironmentKey` page recommends it because it "improves clarity at the call site".
- **`@Environment(\.cardDensity)`** reads it, the same way as a built-in value.

In code written before Xcode 16 you'll see the same value spelled out with `EnvironmentKey`. It's what `@Entry` saves you from:

```swift ios
import SwiftUI

enum CardDensity: Sendable {
    case regular, compact
}

private struct CardDensityKey: EnvironmentKey {
    static let defaultValue: CardDensity = .regular
}

extension EnvironmentValues {
    var cardDensity: CardDensity {
        get { self[CardDensityKey.self] }
        set { self[CardDensityKey.self] = newValue }
    }
}
```

### Defaults must be Sendable

A key's `defaultValue` is a static property, which is global state. In Swift 6 mode, a `static let` of a non-Sendable type is an error. Here it is with a plain-Swift copy of the `EnvironmentKey` protocol, so the diagnostic is pure Swift and doesn't depend on SwiftUI. Swift 6.3:

```swift no-compile static property 'defaultValue' is not concurrency-safe because non-'Sendable' type 'AnalyticsClient' may have shared mutable state
protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

final class AnalyticsClient {
    var sentEvents: [String] = []

    func send(_ event: String) {
        sentEvents.append(event)
    }
}

struct AnalyticsKey: EnvironmentKey {
    static let defaultValue = AnalyticsClient()
}
```

A mutable class shared by every view that reads the default is exactly the kind of shared state Swift 6 refuses. Two fixes:

- **Make the value Sendable.** Enums and structs of Sendable values are the common case for environment values. A service can be a struct of `@Sendable` closures:

```swift
protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

struct AnalyticsClient: Sendable {
    var send: @Sendable (String) -> Void
}

struct AnalyticsKey: EnvironmentKey {
    static let defaultValue = AnalyticsClient(send: { event in print("analytics:", event) })
}

let client = AnalyticsKey.defaultValue
client.send("opened inbox")
```

```output
analytics: opened inbox
```

- **For a mutable, observable model, don't use a key at all.** Inject the object with `.environment(_:)`, next.

## Injecting an @Observable model

Apple: "You can also use `Environment` to get an observable object from a view's environment." Set it with `environment(_:)`, read it with the object's type:

```swift ios
import SwiftUI

@Observable
final class Session {
    var displayName = ""
    var isSignedIn = false

    func signOut() {
        isSignedIn = false
        displayName = ""
    }
}

struct AppRoot: View {
    @State private var session = Session()

    var body: some View {
        TabView {
            NavigationStack { InboxScreen() }
                .tabItem { Label("Inbox", systemImage: "tray") }
            NavigationStack { AccountScreen() }
                .tabItem { Label("Account", systemImage: "person") }
        }
        .environment(session)
    }
}

struct InboxScreen: View {
    var body: some View {
        List {
            GreetingRow()
        }
    }
}

struct GreetingRow: View {
    @Environment(Session.self) private var session

    var body: some View {
        Text(session.isSignedIn ? "Hi, \(session.displayName)" : "Not signed in")
    }
}

struct AccountScreen: View {
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var session = session
        Form {
            TextField("Display name", text: $session.displayName)
            Toggle("Signed in", isOn: $session.isSignedIn)
            Button("Sign out", role: .destructive) {
                session.signOut()
            }
        }
    }
}
```

- **`@State private var session = Session()`** at the root owns the object (lesson 2). The environment doesn't own anything; it only makes the reference reachable.
- **`.environment(session)`** places it in the environment of the whole `TabView`. Apple: "The environment of a given view hierarchy holds only one observable object of a given type."
- **`InboxScreen` never mentions the session.** `GreetingRow`, two levels down, reads it. That's the point of the environment.
- **`@Environment(Session.self) private var session`** reads it by type. Tracking works as in lesson 2: `GreetingRow` depends on `isSignedIn` and `displayName` because its body read them.
- **`@Bindable var session = session`** inside `body` gives `$session.displayName`. Apple's `Bindable` page shows this exact pattern for objects from the environment.

### When the object isn't there

Apple: "If a view attempts to retrieve an object using its type and that object isn't in the environment, SwiftUI throws an exception." The usual cause is a preview or a sheet presented from a part of the tree that never got the object. If a view can legitimately run without it, ask for an optional, and Apple says SwiftUI "returns `nil` instead of throwing an exception":

```swift ios
import SwiftUI

@Observable
final class Session {
    var displayName = ""
}

struct OptionalGreeting: View {
    @Environment(Session.self) private var session: Session?

    var body: some View {
        Text(session.map { "Hi, \($0.displayName)" } ?? "Hi")
    }
}
```

Previews need the object too. This block is illustrative because the iOS check doesn't compile `#Preview`:

```swift illustrative
#Preview {
    GreetingRow()
        .environment(Session())
}
```

> [!tip] By type or by key path?
> `environment(_:)` with the type is simplest. Apple also shows a key-path form: an `@Entry` (or key) whose value is the model, set with `.environment(\.library, library)`. The key needs a default value, so you create an instance only to serve as the default, and a hand-written key with `static let defaultValue` runs into the Sendable rule above for a non-Sendable class. Prefer the type-based form for models.

## Environment or parameter?

The environment is convenient, and it hides dependencies: nothing in `InboxScreen`'s initializer tells you that something inside needs a `Session`, and a missing object is a crash at run time rather than a compile error. Apple's "Managing model data" frames the choice as passing the object to each view, which "is convenient when you have a shallow view hierarchy", versus the environment, for when "you may not know if a subview deep inside the layers of the hierarchy needs the model data."

| Use a parameter when | Use the environment when |
| --- | --- |
| The view can't do its job without the value (a row needs its item) | Many views at different depths read it (theme, session, locale) |
| The parent already has it, one or two levels up | Intermediate views would only pass it along |
| You want the compiler to check it's provided | A sensible default exists, or the root always provides it |
| Different instances get different values (each row its own book) | One value applies to a whole subtree |

A useful default: **data a view displays comes in as parameters; context and services come from the environment.** A `BookRow` takes `book: Book`. It doesn't read "the current book" from the environment.

## Common mistakes

> [!error] Creating the injected object in body
> `.environment(Session())` in a `body` makes a new session every time that body runs, and every reader starts over. Create it once in `@State` (or in the `App`) and inject that.

> [!error] A missing object in a preview or a separate hierarchy
> The view reads `@Environment(Session.self)` and the preview doesn't inject one: SwiftUI throws an exception. Add `.environment(…)` to every root that reaches the view, including previews, or read an optional.

> [!error] @EnvironmentObject with an @Observable type
> `@EnvironmentObject` and `.environmentObject(_:)` are for `ObservableObject` (lesson 4). Apple's `EnvironmentObject` page: "If your observable object conforms to the `Observable` protocol, use `Environment` instead of `EnvironmentObject`."

> [!error] error: static property 'defaultValue' is not concurrency-safe
> A custom key (or an `@Entry` default) whose type is a mutable, non-Sendable class. Make the value a Sendable struct or enum, or inject the object with `.environment(_:)`.

> [!error] Using the environment for everything
> A view that reads five environment values to show one row is hard to reuse and hard to preview. If the parent has the value and the child needs it, pass it.

## Exercises

````exercise
id: m36-l03-e1
type: prediction
prompt: "The propagation model with two values: a font size where the nearest setting wins, and an isEnabled flag that combines like disabled(_:). Leaves print what they see. What's the output?"
code: |
  protocol EnvironmentKey {
      associatedtype Value
      static var defaultValue: Value { get }
  }

  struct EnvironmentValues {
      private var values: [ObjectIdentifier: Any] = [:]

      subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
          get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
          set { values[ObjectIdentifier(key)] = newValue }
      }
  }

  struct FontSizeKey: EnvironmentKey {
      static let defaultValue = 17
  }

  struct IsEnabledKey: EnvironmentKey {
      static let defaultValue = true
  }

  extension EnvironmentValues {
      var fontSize: Int {
          get { self[FontSizeKey.self] }
          set { self[FontSizeKey.self] = newValue }
      }

      var isEnabled: Bool {
          get { self[IsEnabledKey.self] }
          set { self[IsEnabledKey.self] = newValue }
      }
  }

  // Like .font(_:): the nearest value wins.
  func fontSize(_ size: Int) -> (inout EnvironmentValues) -> Void {
      { $0.fontSize = size }
  }

  // Like .disabled(_:): a disabled ancestor can't be overridden.
  func disabled(_ isDisabled: Bool) -> (inout EnvironmentValues) -> Void {
      { $0.isEnabled = $0.isEnabled && !isDisabled }
  }

  struct Node {
      let name: String
      var modify: [(inout EnvironmentValues) -> Void] = []
      var children: [Node] = []
  }

  func render(_ node: Node, in environment: EnvironmentValues) {
      var environment = environment
      for change in node.modify {
          change(&environment)
      }
      if node.children.isEmpty {
          print("\(node.name): size \(environment.fontSize), \(environment.isEnabled ? "enabled" : "disabled")")
      }
      for child in node.children {
          render(child, in: environment)
      }
  }

  let form = Node(name: "Form", modify: [fontSize(15)], children: [
      Node(name: "NameField"),
      Node(name: "Payment", modify: [disabled(true)], children: [
          Node(name: "CardField", modify: [fontSize(13)]),
          Node(name: "PayButton", modify: [disabled(false)]),
      ]),
      Node(name: "Footer", modify: [fontSize(11), disabled(false)]),
  ])

  render(form, in: EnvironmentValues())
output: |
  NameField: size 15, enabled
  CardField: size 13, disabled
  PayButton: size 15, disabled
  Footer: size 11, enabled
hints:
  - "Each node starts from a copy of its parent's environment."
  - "disabled(false) computes isEnabled && true, so it can't turn a false back into true."
  - "Footer's parent is Form, not Payment."
solution: |
  ```output
  NameField: size 15, enabled
  CardField: size 13, disabled
  PayButton: size 15, disabled
  Footer: size 11, enabled
  ```

  - **NameField** inherits Form's size 15 and the default `isEnabled = true`.
  - **CardField** is inside Payment, which disabled its subtree. Its own size 13 replaces 15.
  - **PayButton** says `disabled(false)`, but the combining rule keeps it disabled: once an ancestor disables a subtree, nothing below can enable it again. That's what Apple documents for `.disabled(_:)` on containers. Its size is Form's 15.
  - **Footer** is Payment's sibling, so Payment's change never reached it. Its own size 11 wins.
````

````exercise
id: m36-l03-e2
type: comprehension
prompt: "A settings sheet's root view reads @Environment(Store.self) private var store, where Store is @Observable. The app injects the store on its main WindowGroup content, but this preview crashes. Why, and what's the cleanest fix?"
code: |
  #Preview {
      SettingsSheet()
  }
choices:
  - text: "No Store is in the preview's environment, so SwiftUI throws an exception; add .environment(Store()) to the preview."
    correct: true
    why: "Apple: if the object isn't in the environment, SwiftUI throws an exception. Each root, previews included, must inject it."
  - text: "@Environment can only read built-in values; Store needs @EnvironmentObject."
    correct: false
    why: "@Environment reads @Observable objects by type. @EnvironmentObject is for ObservableObject."
  - text: "Store needs a default value through an EnvironmentKey."
    correct: false
    why: "Objects injected by type don't have keys or defaults. Declaring the property as Store? gives nil instead of a crash, if the view can work without one."
  - text: "Previews can't use the environment."
    correct: false
    why: "Previews are views; modifiers like .environment(_:) work on them."
solution: |
  **The preview never injected a `Store`.** The app's `WindowGroup` content has one, but a preview is a separate root. Reading a non-optional object by type that isn't there makes SwiftUI throw an exception. Add `.environment(Store())` in the preview (or a preconfigured sample store). If the sheet could reasonably run without a store, declare `@Environment(Store.self) private var store: Store?` and handle `nil`.
````

````exercise
id: m36-l03-e3
type: fill-in
prompt: "Declare a custom environment value for whether prices include tax, add a convenience modifier, and read it."
code: |
  import SwiftUI

  extension EnvironmentValues {
      [[1]] var showsPricesWithTax: Bool = false
  }

  extension View {
      func showsPricesWithTax(_ value: Bool) -> some View {
          environment([[2]], value)
      }
  }

  struct PriceLabel: View {
      let net: Double
      [[3]](\.showsPricesWithTax) private var withTax

      var body: some View {
          Text(withTax ? net * 1.16 : net, format: .currency(code: "MXN"))
      }
  }
blanks:
  - id: "1"
    answers: ["@Entry"]
  - id: "2"
    answers: ["\\.showsPricesWithTax"]
  - id: "3"
    answers: ["@Environment"]
hints:
  - "The macro that declares an environment value goes on the property."
  - "environment(_:_:) takes a key path into EnvironmentValues, then the value."
solution: |
  ```swift ios
  import SwiftUI

  extension EnvironmentValues {
      @Entry var showsPricesWithTax: Bool = false
  }

  extension View {
      func showsPricesWithTax(_ value: Bool) -> some View {
          environment(\.showsPricesWithTax, value)
      }
  }

  struct PriceLabel: View {
      let net: Double
      @Environment(\.showsPricesWithTax) private var withTax

      var body: some View {
          Text(withTax ? net * 1.16 : net, format: .currency(code: "MXN"))
      }
  }
  ```

  `@Entry` declares the value and its default. The modifier sets it with the key path `\.showsPricesWithTax`. `@Environment` reads it by the same key path. A checkout screen can now write `.showsPricesWithTax(true)` once, and every `PriceLabel` inside follows.
````

````exercise
id: m36-l03-e4
type: find-errors
prompt: "Which of these are real problems?"
code: |
  import SwiftUI

  @Observable
  final class Cart {
      var items: [String] = []
  }

  struct ShopRoot: View {
      var body: some View {
          NavigationStack {
              CatalogScreen()
          }
          .environment(Cart())
      }
  }

  struct CatalogScreen: View {
      @EnvironmentObject var cart: Cart

      var body: some View {
          List(["Mug", "Poster"], id: \.self) { product in
              ProductRow(product: product)
          }
      }
  }

  struct ProductRow: View {
      @Environment(\.self) private var product: String
      @Environment(Cart.self) private var cart

      var body: some View {
          Button("Add \(product)") { cart.items.append(product) }
      }
  }
choices:
  - text: "The Cart is created inside ShopRoot's body, so each re-render injects a new, empty cart."
    correct: true
    why: "The root must own the object in @State and inject that instance."
  - text: "CatalogScreen uses @EnvironmentObject with an @Observable class."
    correct: true
    why: "@EnvironmentObject requires ObservableObject. Use @Environment(Cart.self), or drop it here: CatalogScreen doesn't use the cart."
  - text: "ProductRow tries to get its product from the environment; it should be a parameter, since each row has a different one."
    correct: true
    why: "Per-instance data the view displays comes in as a parameter. The call site already passes product:, which doesn't even match a stored property."
  - text: "ProductRow can't call cart.items.append without @Bindable."
    correct: false
    why: "Calling methods or mutating properties through the reference needs no binding. @Bindable is only for $cart.property bindings."
  - text: "ProductRow is too deep to read the cart; the environment only reaches direct children."
    correct: false
    why: "The environment reaches every descendant of the view you set it on."
rubric:
  - Flags the cart created in body.
  - Flags @EnvironmentObject with an @Observable type.
  - Flags the product read from the environment instead of passed in.
  - Doesn't claim @Bindable is needed to mutate, or that depth matters.
solution: |
  Three real problems:

  1. **`.environment(Cart())` in `body`.** Each evaluation of `ShopRoot.body` makes a new cart. Add `@State private var cart = Cart()` and inject `.environment(cart)`.
  2. **`@EnvironmentObject var cart: Cart`.** That wrapper is for `ObservableObject` types and won't accept this class. `CatalogScreen` doesn't use the cart anyway, so delete the property; if it needed it, `@Environment(Cart.self)`.
  3. **The product in the environment.** Each row shows a different product, so it's a parameter: `let product: String`, which also makes the existing call `ProductRow(product: product)` compile.

  Mutating `cart.items` through the reference needs no binding, and the environment reaches all descendants.
````

````exercise
id: m36-l03-e5
type: solve
prompt: |
  Extend the plain-Swift propagation model with a theme. Write:

  - `struct Theme: Sendable` with `var accent: String` and `var cornerRadius: Int`;
  - a `ThemeKey` with default `Theme(accent: "orange", cornerRadius: 22)` and a `theme` property on `EnvironmentValues`;
  - two modifier functions: `theme(_:)`, which replaces the whole theme, and `squareCorners()`, which sets only `cornerRadius` to 0 and keeps whatever accent the subtree already had.

  With this tree:

  ```swift
  let screen = Node(name: "Screen", children: [
      Node(name: "Banner"),
      Node(name: "Promo", modify: [theme(Theme(accent: "indigo", cornerRadius: 12))], children: [
          Node(name: "PromoCard"),
          Node(name: "PromoTable", modify: [squareCorners()]),
      ]),
      Node(name: "Toolbar", modify: [squareCorners()]),
  ])

  render(screen, in: EnvironmentValues())
  ```

  the output must be:

  ```output
  Banner: orange, radius 22
  PromoCard: indigo, radius 12
  PromoTable: indigo, radius 0
  Toolbar: orange, radius 0
  ```
starter: |
  protocol EnvironmentKey {
      associatedtype Value
      static var defaultValue: Value { get }
  }

  struct EnvironmentValues {
      private var values: [ObjectIdentifier: Any] = [:]

      subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
          get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
          set { values[ObjectIdentifier(key)] = newValue }
      }
  }

  struct Node {
      let name: String
      var modify: [(inout EnvironmentValues) -> Void] = []
      var children: [Node] = []
  }

  func render(_ node: Node, in environment: EnvironmentValues) {
      var environment = environment
      for change in node.modify {
          change(&environment)
      }
      if node.children.isEmpty {
          print("\(node.name): \(environment.theme.accent), radius \(environment.theme.cornerRadius)")
      }
      for child in node.children {
          render(child, in: environment)
      }
  }

  // Theme, ThemeKey, the theme property and the two modifiers here.
hints:
  - "A static let default is fine here because Theme is Sendable."
  - "squareCorners() mutates environment.theme.cornerRadius on the copy it's given; that reads the inherited theme first."
rubric:
  - Theme is a Sendable struct and the key's default is a static let.
  - The theme property on EnvironmentValues has a getter and setter through the key.
  - squareCorners() changes only cornerRadius and keeps the inherited accent.
  - The output matches exactly.
solution: |
  ```swift
  protocol EnvironmentKey {
      associatedtype Value
      static var defaultValue: Value { get }
  }

  struct EnvironmentValues {
      private var values: [ObjectIdentifier: Any] = [:]

      subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
          get { values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
          set { values[ObjectIdentifier(key)] = newValue }
      }
  }

  struct Theme: Sendable {
      var accent: String
      var cornerRadius: Int
  }

  struct ThemeKey: EnvironmentKey {
      static let defaultValue = Theme(accent: "orange", cornerRadius: 22)
  }

  extension EnvironmentValues {
      var theme: Theme {
          get { self[ThemeKey.self] }
          set { self[ThemeKey.self] = newValue }
      }
  }

  func theme(_ theme: Theme) -> (inout EnvironmentValues) -> Void {
      { $0.theme = theme }
  }

  func squareCorners() -> (inout EnvironmentValues) -> Void {
      { $0.theme.cornerRadius = 0 }
  }

  struct Node {
      let name: String
      var modify: [(inout EnvironmentValues) -> Void] = []
      var children: [Node] = []
  }

  func render(_ node: Node, in environment: EnvironmentValues) {
      var environment = environment
      for change in node.modify {
          change(&environment)
      }
      if node.children.isEmpty {
          print("\(node.name): \(environment.theme.accent), radius \(environment.theme.cornerRadius)")
      }
      for child in node.children {
          render(child, in: environment)
      }
  }

  let screen = Node(name: "Screen", children: [
      Node(name: "Banner"),
      Node(name: "Promo", modify: [theme(Theme(accent: "indigo", cornerRadius: 12))], children: [
          Node(name: "PromoCard"),
          Node(name: "PromoTable", modify: [squareCorners()]),
      ]),
      Node(name: "Toolbar", modify: [squareCorners()]),
  ])

  render(screen, in: EnvironmentValues())
  ```

  ```output
  Banner: orange, radius 22
  PromoCard: indigo, radius 12
  PromoTable: indigo, radius 0
  Toolbar: orange, radius 0
  ```

  `theme(_:)` replaces the value for its subtree. `squareCorners()` is a transforming modifier: it reads the theme it inherited and changes one field, so inside Promo it keeps indigo and outside it keeps orange. SwiftUI has the same split: `.environment(\.font, …)` replaces, while some modifiers adjust what's already there (`.bold()` on a `Text`, for instance, changes the text's font rather than choosing a new one). `Theme` being a Sendable struct is what makes the `static let` default legal in Swift 6.
````

````exercise
id: m36-l03-e6
type: design
prompt: "A recipes app has these dependencies. For each, say whether you'd pass it as an initializer parameter or provide it through the environment (and how), with a one-line reason: (1) the Recipe a RecipeDetail screen shows; (2) a FavoritesStore, @Observable, used by the list rows, the detail screen and a widget-like summary on the home tab; (3) the user's preferred measurement system (metric or US), shown in ingredient rows across the app; (4) an ImageLoader service used by every thumbnail; (5) a Bool that tells one IngredientRow whether to show a checkbox."
rubric:
  - Recipe as a parameter (per-instance data the screen displays).
  - FavoritesStore in @State at the root, injected with .environment(_:) and read with @Environment(FavoritesStore.self).
  - Measurement system as a custom @Entry value (Sendable enum), possibly backed by a setting.
  - ImageLoader through the environment as a Sendable value (struct of @Sendable closures or an actor), or an injected object.
  - The checkbox Bool as a parameter.
solution: |
  A sound answer:

  1. **Recipe: parameter.** `RecipeDetail(recipe:)`. Each screen shows a different one, and it can't work without it.
  2. **FavoritesStore: environment by type.** Own it with `@State` in the `App` or root view, `.environment(favorites)`, read `@Environment(FavoritesStore.self)` in rows, the detail and the summary. Views at several depths use it.
  3. **Measurement system: custom value.** `enum MeasurementSystem: Sendable { case metric, us }` and `@Entry var measurementSystem: MeasurementSystem = .metric`, set once near the root from the user's setting (lesson 6 covers `@AppStorage`). It's context that changes how many views render.
  4. **ImageLoader: environment.** A service used everywhere is the classic environment case. Make it Sendable (a struct of `@Sendable` closures, or an actor) so it can be an `@Entry` with a default, which also lets previews swap in a fake.
  5. **Checkbox flag: parameter.** It's specific to one row and set by its parent. An environment value would make every row below follow it, which isn't what's asked.
````

## Summary

- `@Environment(\.keyPath)` reads a value; it never sets one. Views update when a value they read changes.
- Values flow down: a modifier sets a value for its subtree, a nearer setting replaces it, and siblings and ancestors don't see it. A few modifiers, like `disabled(_:)`, combine instead.
- Declare custom values with `@Entry` in an `EnvironmentValues` extension and add a convenience modifier. `EnvironmentKey` is the older, longer spelling.
- Default values are static, so in Swift 6 they must be Sendable: enums, structs, `@Sendable` closures.
- Inject an `@Observable` model with `.environment(model)` from the view that owns it in `@State`; read it with `@Environment(Model.self)`, as an optional when it may be missing; use a local `@Bindable` for bindings.
- Pass data a view displays as parameters. Use the environment for context and services that many views at different depths need.
