---
id: m44-l04
title: App Intents
description: "App Intents describe your app's actions and data so the system can run them without your UI: from Siri, Spotlight, the Shortcuts app, widgets, controls and the Action button. You write an AppIntent with parameters and a perform() method, validate input the way the system expects, expose your data as AppEntity types with queries, offer App Shortcuts with spoken phrases, and reuse the same intents in interactive widgets, configurable widgets and Control Center controls."
module: m44
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m44-l03]
objectives:
  - Explain what an app intent is, where the system runs it, and why its metadata must be known at build time.
  - Write an AppIntent with a title, description, parameters, a parameter summary and a result with dialog.
  - Validate parameters in perform() and ask for missing or invalid values with needsValueError.
  - Expose app data as an AppEntity with a persistent identifier and an EntityQuery or EntityStringQuery.
  - Offer App Shortcuts with phrases that include the app's name.
  - Reuse intents in interactive widgets, configurable widgets (WidgetConfigurationIntent) and controls (iOS 18).
terms:
  - term: App intent
    definition: "A type conforming to AppIntent that describes one action: a title, optional description and parameters, and an async perform() that does the work and returns a result. The system can run it from Siri, Shortcuts, Spotlight, widgets and controls."
  - term: Intent parameter
    definition: "A property wrapped in @Parameter (IntentParameter). Non-optional parameters are required, and the system resolves them before calling perform(); optional ones aren't requested unless the intent throws needsValueError."
  - term: AppEntity
    definition: "A lightweight representation of one of your data objects that the system can display, store and pass between intents. It needs a persistent id, a display representation, a type display representation and a default query."
  - term: Entity query
    definition: "An EntityQuery that returns entities for identifiers (entities(for:)) and, optionally, suggestions (suggestedEntities()). EntityStringQuery adds entities(matching:) for text search."
  - term: App Shortcut
    definition: "An app intent packaged with spoken phrases, a short title and a symbol in an AppShortcutsProvider. Available as soon as the app is installed, in Siri, Spotlight and the Shortcuts app."
  - term: Control
    definition: "A ControlWidget (iOS 18) in Control Center, the Lock Screen or the Action button: a button running an AppIntent or a toggle running a SetValueIntent, rendered from a template by the widget extension."
mastery:
  - Turn one of the app's actions into an AppIntent with a parameter summary and a spoken result.
  - Resolve a request that may be missing a product, name an unknown one, or exceed a limit, and say which error to throw for each.
  - Write an AppEntity and its query, and explain why the identifier must stay the same across launches and versions.
  - Rank text matches for an entity query.
  - Write an AppShortcutsProvider whose phrases include the app name and a parameter.
  - Reuse one intent in a widget button, a widget configuration and a control, and say which process runs it.
resources: [swift-book-protocols, swift-book-concurrency, swift-actor, swiftui-app]
cards:
  - id: m44-l04-c1
    front: What are the minimum parts of an AppIntent?
    back: "A localized title (static var title), an async throwing perform() that does the action and returns a result (.result(), optionally with a dialog or value), and @Parameter properties for any input. A description and parameterSummary help the Shortcuts app show it."
  - id: m44-l04-c2
    front: What's the difference between an optional and a non-optional intent parameter?
    back: "Non-optional means required: the system resolves it (asks the person if needed) before calling perform(). Optional means the system doesn't ask; if perform() can't proceed without it, throw $param.needsValueError(\"…\")."
  - id: m44-l04-c3
    front: What does an AppEntity need?
    back: "A unique, persistent id (the system may store it in a shortcut), a displayRepresentation, a static typeDisplayRepresentation, and a defaultQuery whose entities(for:) finds entities by id (omitting ones that no longer exist). Apple: entities have a 10 MB total size limit."
  - id: m44-l04-c4
    front: Which process runs an intent from a widget button?
    back: "By default, the widget extension's. Intents with LiveActivityIntent, AudioPlaybackIntent and a few other protocols run in the app's process, as do intents that open the app. Add widget intents to both targets."
  - id: m44-l04-c5
    front: How are App Shortcuts made available?
    back: "Declare them in a type conforming to AppShortcutsProvider. The compiler extracts them, so they're available as soon as the app is installed, without registration, in Siri, Spotlight and the Shortcuts app."
---

## The idea in one sentence

An app intent is **an action of your app described as data**, with a name, typed inputs and code to run, so the system can offer it in places your UI never appears: Siri, Spotlight, the Shortcuts app, widgets, controls and the Action button.

> [!note] Sources and what was checked
> From Apple's App Intents documentation, read in November 2026: "Getting started with the App Intents framework", "Creating your first app intent", "Adding parameters to an app intent", `AppIntent`, `AppEntity`, `EntityQuery`, `AppEnum`, "App Shortcuts", `AppShortcutsProvider`, `openAppWhenRun` and `supportedModes`, plus WidgetKit's "Adding interactivity to widgets and Live Activities" and "Creating controls to perform actions across the system". No intent was run from Siri, Spotlight or Shortcuts for this lesson. The App Intents, WidgetKit and SwiftUI blocks are type-checked against the iOS SDK, not run; type-checking doesn't run the build step that extracts App Intents metadata, so mistakes that only that step catches can't show up here. The validation and search models are plain Swift, compiled and run with Swift 6.3.

## What an intent is, and why it's a type

In lesson 1 a widget toggle couldn't call a closure, because the widget's code isn't running when someone taps it. The toggle carried an intent instead. That's the general idea: the system needs to know, **without launching your app**, what actions exist, what they're called, what they need and how to describe them. Apple: "The compiler extracts your code and makes it available to the Shortcuts app and the rest of the system."

That's why intents look the way they do:

- **Titles and descriptions are static, literal values**, so the build can read them. Computed values that depend on runtime data can't be extracted.
- **Parameters are typed**, using types the framework understands (strings, numbers, dates, files, measurements) or your own `AppEntity` and `AppEnum` types.
- **`perform()` is `async throws`**, and can run in your app, in an extension, in the foreground or background. Apple: "The system can call your `perform()` method under a variety of conditions, so write your code to be as robust as possible."

A first intent, which Siri can answer without opening Pantry:

```swift ios
import AppIntents

struct NextDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource { "Next Delivery" }
    static var description: IntentDescription? { IntentDescription("Tells you when your next Pantry order arrives.") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await DeliveryStore.shared.nextDeliverySummary()
        return .result(dialog: "Your next delivery is \(summary).")
    }
}

actor DeliveryStore {
    static let shared = DeliveryStore()

    func nextDeliverySummary() -> String {
        "Thursday between 10:00 and 11:00"
    }
}
```

- **`title`** is what Shortcuts and Siri show. It's a `LocalizedStringResource`, so it goes through your string catalog (Module 43).
- **`description`** is optional; the protocol's requirement is `IntentDescription?`, so the implementation uses that type.
- **The result type** `some IntentResult & ProvidesDialog` says this intent returns a dialog: text Siri speaks or shows. Other results: `.result()` with nothing, `ReturnsValue` to feed another action in a shortcut, `ShowsSnippetView` for a custom view, `OpensIntent` to continue in the app. Apple notes that with some Siri experiences "the system might not display `IntentDialog` or `ShowsSnippetView`," so the dialog must make sense alone.
- **The store is an actor** with a shared instance. The intent is `Sendable` (the protocol requires it) and may run on any thread, so the data it touches must be safe to reach from there. Apple's alternative for injecting objects is `AppDependencyManager` with `@Dependency` properties, registered early in the app's launch.

## Parameters

`@Parameter` marks inputs. Required or optional follows the Swift type. Apple: "If you define a variable as a non-optional type, the system knows the parameter is required and, when necessary, requests a value. Conversely, if you define a variable as an optional type, the system assumes the parameter is optional and doesn't request a value." And: "The system calls the method only after resolving all required parameters, so your code can rely on the values being present."

Present isn't the same as valid. Siri may resolve "add 50 eggs" perfectly well, and Pantry still won't put 50 boxes of eggs on a list. Validation belongs in `perform()`, and the framework gives you the right way to push back: `throw $quantity.needsValueError("…")` asks the person again for that parameter, and a thrown error with a `localizedStringResource` is shown as the failure.

Pantry's rules for "add to shopping list", written as a function so they're testable away from Siri:

```swift
struct Product {
    let id: String
    let name: String
    let maxOnList: Int
}

enum Resolution: CustomStringConvertible {
    case ready(productID: String, quantity: Int)
    case needsProduct                     // throw $product.needsValueError(...)
    case needsQuantity(String)            // throw $quantity.needsValueError(...)
    case failure(String)                  // throw an error the system shows

    var description: String {
        switch self {
        case .ready(let id, let quantity): "ready: \(quantity) × \(id)"
        case .needsProduct: "ask: Which product?"
        case .needsQuantity(let message): "ask: \(message)"
        case .failure(let message): "fail: \(message)"
        }
    }
}

func resolveAddToList(productName: String?, quantity: Int?, catalog: [Product], onList: [String: Int]) -> Resolution {
    guard let productName, !productName.isEmpty else { return .needsProduct }
    guard let product = catalog.first(where: { $0.name.lowercased() == productName.lowercased() }) else {
        return .failure("Pantry has no product called \(productName).")
    }
    let requested = quantity ?? 1
    guard requested >= 1 else { return .needsQuantity("How many? At least 1.") }
    let already = onList[product.id, default: 0]
    guard already + requested <= product.maxOnList else {
        return .needsQuantity("The list can hold \(product.maxOnList) \(product.name); it has \(already). How many more?")
    }
    return .ready(productID: product.id, quantity: requested)
}

let catalog = [
    Product(id: "milk-1l", name: "Whole milk", maxOnList: 12),
    Product(id: "eggs-12", name: "Free-range eggs", maxOnList: 4),
]
let list = ["eggs-12": 3]
print(resolveAddToList(productName: "whole MILK", quantity: nil, catalog: catalog, onList: list))
print(resolveAddToList(productName: nil, quantity: 2, catalog: catalog, onList: list))
print(resolveAddToList(productName: "Oat milk", quantity: 1, catalog: catalog, onList: list))
print(resolveAddToList(productName: "Whole milk", quantity: 0, catalog: catalog, onList: list))
print(resolveAddToList(productName: "Free-range eggs", quantity: 2, catalog: catalog, onList: list))
print(resolveAddToList(productName: "Free-range eggs", quantity: 1, catalog: catalog, onList: list))
```

```output
ready: 1 × milk-1l
ask: Which product?
fail: Pantry has no product called Oat milk.
ask: How many? At least 1.
ask: The list can hold 4 Free-range eggs; it has 3. How many more?
ready: 1 × eggs-12
```

- **No quantity means 1**, matching a parameter with a default value. People say "add milk," not "add one milk."
- **No product asks** instead of failing: the person said something like "add to my Pantry list" and Siri can follow up.
- **An unknown product fails** with a sentence that says what went wrong. Asking again would loop if Pantry simply doesn't sell it.
- **A limit asks again with the numbers.** "Invalid quantity" gives the person nothing to work with; "it has 3, how many more?" does.
- In the real intent, `productName` is replaced by an entity parameter (next section), so "unknown product" mostly disappears: the system only offers products the query returns.

## Entities and queries

A product isn't a string. People choose it from a list in Shortcuts, Siri disambiguates "milk" between "Whole milk" and "Oat milk", and a shortcut saved today must still find the same product next year. That's an `AppEntity`. Apple's requirements: "It stores a unique identifier that your app can use to locate the underlying data. It offers a query object to find specific instances of itself. ... It provides descriptive information the system can display to people."

```swift ios
import AppIntents

struct ProductEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Product" }
    static let defaultQuery = ProductQuery()

    let id: String
    let name: String
    let unit: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(unit)")
    }
}

struct ProductQuery: EntityStringQuery {
    /// The system has identifiers (from a saved shortcut, or a previous step) and needs the entities.
    func entities(for identifiers: [ProductEntity.ID]) async throws -> [ProductEntity] {
        Catalog.products.filter { identifiers.contains($0.id) }
    }

    /// The person typed or said something.
    func entities(matching string: String) async throws -> [ProductEntity] {
        Catalog.products.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    /// Shown as options before the person types anything.
    func suggestedEntities() async throws -> [ProductEntity] {
        Array(Catalog.products.prefix(5))
    }
}

enum Catalog {
    static let products = [
        ProductEntity(id: "milk-1l", name: "Whole milk", unit: "1 L"),
        ProductEntity(id: "oat-1l", name: "Oat milk", unit: "1 L"),
        ProductEntity(id: "eggs-12", name: "Free-range eggs", unit: "12 pack"),
    ]
}
```

- **`id` must be persistent.** Apple's sample notes "the system requires the `AppEntity` identifier to be unique and persistant because the system may save it in a shortcut." Use the product's server id, not an array index or a `UUID()` made at launch. It's the same rule this course applies to lesson and exercise ids.
- **`entities(for:)`**: "If the entity for a provided identifier is no longer available, omit it from the returned array." A discontinued product simply disappears from the result.
- **The display representation** is what Siri says and Shortcuts shows. Keep it short.
- **Entities are copies**, not your model objects. Apple: "it's a good idea to create models specific to app intents that shadow your app data models." Pantry's `Product` stays a SwiftData model (Module 37); `ProductEntity` is a small `Sendable` struct. Apple also sets a size limit: "AppEntity instances have a total size limit of 10 MB."
- **`AppEnum`** is the entity's little sibling for fixed lists (sizes, filters): a `String`-backed enum with display names for each case. You'll see one in the configurable widget below.

`localizedCaseInsensitiveContains` returns matches in catalog order. With hundreds of products, "milk" should put "Milk" before "Buttermilk"; the solve exercise ranks matches.

## The intent with an entity parameter

```swift ios
import AppIntents

struct ProductEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Product" }
    static let defaultQuery = ProductQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ProductQuery: EntityQuery {
    func entities(for identifiers: [ProductEntity.ID]) async throws -> [ProductEntity] {
        Catalog.products.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProductEntity] {
        Catalog.products
    }
}

enum Catalog {
    static let products = [
        ProductEntity(id: "milk-1l", name: "Whole milk"),
        ProductEntity(id: "eggs-12", name: "Free-range eggs"),
    ]
}

actor ShoppingList {
    static let shared = ShoppingList()
    private var quantities: [String: Int] = [:]

    func count(of productID: String) -> Int {
        quantities[productID, default: 0]
    }

    func add(_ productID: String, quantity: Int) {
        quantities[productID, default: 0] += quantity
    }
}

enum ListIntentError: Error, CustomLocalizedStringResourceConvertible {
    case listFull(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .listFull(let name): "Your list already has as many \(name) as Pantry allows."
        }
    }
}

struct AddToListIntent: AppIntent {
    static var title: LocalizedStringResource { "Add to Shopping List" }

    @Parameter(title: "Product")
    var product: ProductEntity

    @Parameter(title: "Quantity", default: 1)
    var quantity: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$quantity) \(\.$product) to the list")
    }

    init() {}

    init(product: ProductEntity, quantity: Int) {
        self.product = product
        self.quantity = quantity
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard quantity >= 1 else {
            throw $quantity.needsValueError("How many? At least 1.")
        }
        let already = await ShoppingList.shared.count(of: product.id)
        guard already < 12 else { throw ListIntentError.listFull(product.name) }
        guard already + quantity <= 12 else {
            throw $quantity.needsValueError("The list has \(already). How many more?")
        }
        await ShoppingList.shared.add(product.id, quantity: quantity)
        return .result(dialog: "Added \(quantity) \(product.name) to your list.")
    }
}

struct PantryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToListIntent(),
            phrases: [
                "Add \(\.$product) to my \(.applicationName) list",
                "Add to my \(.applicationName) list",
            ],
            shortTitle: "Add to List",
            systemImageName: "cart.badge.plus"
        )
    }
}
```

- **`product` is required** (non-optional), so Siri asks "Which product?" before `perform()` runs, offering `suggestedEntities()`. **`quantity` has a default**, so it's never asked for unless invalid.
- **`parameterSummary`** is the sentence the Shortcuts editor shows, with the parameters as tappable placeholders: "Add **1** **Whole milk** to the list."
- **`needsValueError`** pauses and asks for that parameter again with your dialog; **`ListIntentError`** fails with a message, because asking again can't help.
- **`init(product:quantity:)`** lets a widget button or a shortcut pre-fill the parameters. The empty `init()` is what the system uses.
- **The checks run before the write**, and the result is returned only after the `await` finishes, so a widget reloading after the intent (lesson 1) sees the new count.

## App Shortcuts

The `AppShortcutsProvider` at the end of that block turns the intent into an **App Shortcut**: phrases, a short title and an SF Symbol. Apple: "the shortcuts you create are available as soon as someone installs your app, and you don't have to register them yourself." They show up in the Shortcuts app, in Spotlight and with Siri.

- **Phrases include `\(.applicationName)`**, so "Add milk to my Pantry list" is unambiguous among the person's apps. A phrase can include an entity or enum parameter (`\(\.$product)`); the system builds the spoken variants from your query's entities.
- **Keep it to the actions people repeat.** "Add to list" and "next delivery" are worth a phrase; "change the app icon" isn't.
- In the app, `SiriTipView` shows the phrase for an intent at the right moment (after someone adds to the list by hand), and `ShortcutsLink` opens Pantry's page in the Shortcuts app.

## One intent, many surfaces

The point of describing actions as data is reuse. The same intents power:

**Interactive widgets** (lesson 1): `Button(intent: AddToListIntent(product: milk, quantity: 1))`. Apple: for a widget, add the intent "to your widget extension target and your app target." By default the system runs it "in the same process as the widget extension"; if the intent conforms to `LiveActivityIntent`, `AudioPlaybackIntent` and a few others, or opens the app, it runs in the app's process.

**Configurable widgets**: a `WidgetConfigurationIntent` holds the widget's settings, and the widget uses `AppIntentConfiguration` with an `AppIntentTimelineProvider`, whose methods are `async` and receive the configuration (iOS 17):

```swift ios
import AppIntents
import SwiftUI
import WidgetKit

enum ListFilter: String, AppEnum {
    case all, unchecked

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Filter" }
    static var caseDisplayRepresentations: [ListFilter: DisplayRepresentation] {
        [.all: "All items", .unchecked: "Still to buy"]
    }
}

struct ListWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Shopping List" }

    @Parameter(title: "Show", default: .unchecked)
    var filter: ListFilter
}

struct ListEntry: TimelineEntry {
    let date: Date
    let items: [String]
}

struct ListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: .now, items: ["Milk", "Eggs"])
    }

    func snapshot(for configuration: ListWidgetConfiguration, in context: Context) async -> ListEntry {
        ListEntry(date: .now, items: ["Milk", "Eggs"])
    }

    func timeline(for configuration: ListWidgetConfiguration, in context: Context) async -> Timeline<ListEntry> {
        let items = configuration.filter == .all ? ["Milk", "Eggs", "Bread"] : ["Milk"]
        return Timeline(entries: [ListEntry(date: .now, items: items)], policy: .never)
    }
}

struct ShoppingListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ShoppingList", intent: ListWidgetConfiguration.self, provider: ListProvider()) { (entry: ListEntry) in
            Text(entry.items.joined(separator: ", "))
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Shopping list")
    }
}
```

When the person edits the widget, the system shows the "Show" parameter with your enum's display names, and each widget instance gets its own configuration (and, per lesson 1, its own reload budget).

**Controls** (iOS 18): buttons and toggles in Control Center, on the Lock Screen and on the Action button. Apple: "Use `AppIntent` or `OpenIntent` for control buttons and `SetValueIntent` for control toggles," and "the system queries for the state of a control when `perform()` returns; finish all actions and save all state data before it returns."

```swift ios 18.0
import AppIntents
import SwiftUI
import WidgetKit

struct AddMilkIntent: AppIntent {
    static var title: LocalizedStringResource { "Add Milk" }

    func perform() async throws -> some IntentResult {
        // Add one "milk-1l" to the shared shopping list, then return.
        return .result()
    }
}

struct AddMilkControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.example.pantry.add-milk") {
            ControlWidgetButton(action: AddMilkIntent()) {
                Label("Add Milk", systemImage: "cart.badge.plus")
            }
        }
        .displayName("Add Milk")
    }
}
```

Controls live in the widget extension next to widgets and Live Activities, and appear in the `WidgetBundle` like them.

**Live Activities** (lesson 2): buttons in a Live Activity use intents conforming to `LiveActivityIntent`, which run in the app's process and can also start a Live Activity while the app is in the background.

### Foreground or background

Some actions need the app on screen: "open this order." Before iOS 26, intents set `openAppWhenRun`; that property is deprecated in iOS 26, and Apple's replacement is `supportedModes`:

```swift ios 26.0
import AppIntents

struct OpenCartIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Cart" }
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Navigate to the cart in the app's UI.
        return .result()
    }
}
```

Apple's guidance is to "design app intents to run in the background whenever possible, but add foreground modes to facilitate interactions or update your app's interface." For an app that supports iOS 17, `OpenIntent` (with an entity `target`) is the other documented way to say "this intent opens the app to show something." Setting `openAppWhenRun` to true also "generates an error if the app intent runs in an app extension."

## Common mistakes

> [!error] Computed titles or descriptions from runtime data
> Titles, descriptions, phrases and display representations for types are read at build time. A title built from the signed-in user's name can't be extracted. Keep them literal and localized.

> [!error] Identifiers that change
> An entity whose `id` is an array index or a `UUID()` created at launch breaks every saved shortcut on the next launch. Use the stable server or database id.

> [!error] Trusting resolved parameters
> The system guarantees a required parameter is present, not that it's sensible. Validate in `perform()` and use `needsValueError` to ask again with a helpful message.

> [!error] Returning before the work is saved
> Widgets reload their timeline when the intent returns, and controls read their state then. If `perform()` returns before the write finishes, they show stale data.

> [!error] Adding the intent to only one target
> An intent used in a widget button but compiled only into the app isn't in the extension that runs it by default. Apple: add it to both targets, or share it through a package.

> [!error] Main-actor work from an intent without saying so
> `perform()` may run off the main thread. Touching the app's UI state needs `@MainActor` on `perform()` or a hop to the main actor, and a foreground mode if the UI must be visible.

## Exercises

````exercise
id: m44-l04-e1
type: prediction
prompt: "A short version of the quantity rule: nil means 1, below 1 asks again, and the list is capped. What does it print?"
code: |
  func quantityToAdd(requested: Int?, onList: Int, cap: Int) -> String {
      let wanted = requested ?? 1
      if wanted < 1 { return "ask" }
      if onList >= cap { return "full" }
      return "add \(min(wanted, cap - onList))"
  }

  print(quantityToAdd(requested: nil, onList: 0, cap: 4))
  print(quantityToAdd(requested: 3, onList: 2, cap: 4))
  print(quantityToAdd(requested: 0, onList: 4, cap: 4))
  print(quantityToAdd(requested: 5, onList: 4, cap: 4))
output: |
  add 1
  add 2
  ask
  full
hints:
  - "The checks run in order: the quantity first, then the cap."
  - "min(wanted, cap - onList) quietly trims the request."
solution: |
  ```output
  add 1
  add 2
  ask
  full
  ```

  - No quantity becomes 1.
  - 3 requested with 2 already and a cap of 4: only 2 fit, so it adds 2. That silent trim is a design choice worth questioning: the lesson's intent asks instead ("The list has 2. How many more?"), because adding less than the person said without telling them is surprising.
  - 0 asks, even though the list is also full: the quantity check comes first.
  - 5 with a full list: "full".
````

````exercise
id: m44-l04-e2
type: comprehension
prompt: "Pantry's `ProductEntity` used `id = UUID().uuidString`, generated when the catalog loads. What breaks?"
choices:
  - text: "Saved shortcuts and configured widgets store the id; on the next launch no entity has that id, so entities(for:) returns nothing and they stop working."
    correct: true
    why: "Apple requires a unique and persistent identifier because the system may save it in a shortcut."
  - text: "Nothing; the system matches entities by their display name."
    correct: false
    why: "Resolution by identifier goes through entities(for:), which compares ids."
  - text: "The app fails to compile because AppEntity ids must be Int."
    correct: false
    why: "Any EntityIdentifierConvertible type works; String is common."
  - text: "Siri can't show the product's name."
    correct: false
    why: "The display representation still works for the current launch; the problem is next time."
solution: |
  The system stores entity identifiers in shortcuts, in widget configurations and between steps of a shortcut. `entities(for:)` must find the entity again from that id, on any later launch and after updates. Derive the id from the product's stable identifier (`"milk-1l"` or the server's id).
````

````exercise
id: m44-l04-e3
type: fill-in
prompt: "Complete Pantry's reorder intent."
code: |
  struct ReorderIntent: AppIntent {
      static var title: LocalizedStringResource { "Reorder" }

      [[1]](title: "Order")
      var order: OrderEntity

      static var parameterSummary: some ParameterSummary {
          Summary("Reorder \(\.[[2]])")
      }

      func perform() async throws -> some IntentResult & [[3]] {
          guard await Cart.shared.isEmpty else {
              throw ReorderError.cartNotEmpty
          }
          await Cart.shared.add(order.items)
          return .result(dialog: "Added \(order.items.count) items to your cart.")
      }
  }
blanks:
  - id: "1"
    answers: ["@Parameter"]
  - id: "2"
    answers: ["$order"]
  - id: "3"
    answers: ["ProvidesDialog"]
solution: |
  - `@Parameter` declares the input; non-optional, so the system resolves it first.
  - `\.$order` is the key path to the parameter itself (the wrapper's projected value), which the summary turns into a placeholder.
  - `ProvidesDialog` matches the `.result(dialog:)` returned. The cart check throws an error the system shows, because asking for a different order wouldn't fix a full cart.
````

````exercise
id: m44-l04-e4
type: find-errors
prompt: "A teammate's intents. Mark every real problem."
code: |
  struct StartShoppingIntent: AppIntent {
      static var title: LocalizedStringResource { "Start Shopping for \(UserSession.current.name)" }

      @Parameter(title: "Store")
      var store: StoreEntity?

      func perform() async throws -> some IntentResult {
          Task { await Cart.shared.prepare(for: store!) }
          return .result()
      }
  }

  struct StoreEntity: AppEntity {
      let id = UUID()
      // ...
  }
choices:
  - text: "The title depends on runtime data and can't be extracted at build time."
    correct: true
  - text: "The optional store is force-unwrapped; the system doesn't ask for optional parameters, so it can be nil."
    correct: true
  - text: "perform() returns before the work finishes, because it starts an unstructured Task."
    correct: true
  - text: "The entity's id is regenerated every time, so saved shortcuts can't find the store again."
    correct: true
  - text: "AppIntent types must be classes."
    correct: false
    why: "They're usually structs; the protocol requires Sendable."
rubric:
  - I flagged the dynamic title.
  - I flagged the force-unwrapped optional parameter.
  - I flagged the fire-and-forget Task.
  - I flagged the unstable id.
solution: |
  - **Title:** `"Start Shopping"`, literal and localized.
  - **Optional parameter:** either make `store` non-optional (the system asks), or `guard let store else { throw $store.needsValueError("Which store?") }`.
  - **Task:** `await Cart.shared.prepare(for: store)` directly; widgets and controls read state when `perform()` returns, and the system may suspend the process right after.
  - **Id:** the store's server id.
````

````exercise
id: m44-l04-e5
type: solve
prompt: |
  Write `rank(_:in:limit:)` for the product query's text search. Compare case-insensitively. Score 0 for an exact name match, 1 when any word of the name starts with the query, 2 when the name merely contains it; drop the rest. Sort by score, then by name, and return at most `limit` names. An empty query returns nothing.

  Expected output:

  ```output
  ["Milk", "Milk chocolate", "Oat milk", "Whole milk", "Buttermilk"]
  ["Milk", "Milk chocolate"]
  ["Buttermilk", "Milk", "Milk chocolate", "Oat milk", "Whole milk"]
  []
  []
  ```
starter: |
  struct Item {
      let id: String
      let name: String
  }

  func rank(_ query: String, in items: [Item], limit: Int = 5) -> [String] {
      // your code
      return []
  }

  let items = [
      Item(id: "milk-1l", name: "Whole milk"),
      Item(id: "oat-1l", name: "Oat milk"),
      Item(id: "milk", name: "Milk"),
      Item(id: "choc", name: "Milk chocolate"),
      Item(id: "butter", name: "Buttermilk"),
      Item(id: "bread", name: "Rye bread"),
  ]
  print(rank("milk", in: items))
  print(rank("MIL", in: items, limit: 2))
  print(rank("ilk", in: items))
  print(rank("tea", in: items))
  print(rank("", in: items))
hints:
  - "Lowercase both sides once, then compute an optional score per item."
  - "split(separator: \" \") gives the words; hasPrefix checks each."
rubric:
  - Exact matches first, then word-prefix matches, then substring matches.
  - Ties sorted by name; the limit applied after sorting.
  - Empty query and no matches both return an empty array.
solution: |
  ```swift
  struct Item {
      let id: String
      let name: String
  }

  func rank(_ query: String, in items: [Item], limit: Int = 5) -> [String] {
      let needle = query.lowercased()
      guard !needle.isEmpty else { return [] }
      func score(_ item: Item) -> Int? {
          let name = item.name.lowercased()
          if name == needle { return 0 }
          if name.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) { return 1 }
          if name.contains(needle) { return 2 }
          return nil
      }
      let scored = items.compactMap { item in score(item).map { (item, $0) } }
      let sorted = scored.sorted { a, b in
          a.1 != b.1 ? a.1 < b.1 : a.0.name < b.0.name
      }
      return sorted.prefix(limit).map { $0.0.name }
  }

  let items = [
      Item(id: "milk-1l", name: "Whole milk"),
      Item(id: "oat-1l", name: "Oat milk"),
      Item(id: "milk", name: "Milk"),
      Item(id: "choc", name: "Milk chocolate"),
      Item(id: "butter", name: "Buttermilk"),
      Item(id: "bread", name: "Rye bread"),
  ]
  print(rank("milk", in: items))
  print(rank("MIL", in: items, limit: 2))
  print(rank("ilk", in: items))
  print(rank("tea", in: items))
  print(rank("", in: items))
  ```

  ```output
  ["Milk", "Milk chocolate", "Oat milk", "Whole milk", "Buttermilk"]
  ["Milk", "Milk chocolate"]
  ["Buttermilk", "Milk", "Milk chocolate", "Oat milk", "Whole milk"]
  []
  []
  ```

  "Milk" is exact; "Milk chocolate", "Oat milk" and "Whole milk" each have a word starting with "milk"; "Buttermilk" only contains it. With "ilk" nothing starts a word, so all five tie at 2 and sort by name. In `entities(matching:)`, the names map back to entities. Sorting compares names with `<`, which is fine for this ASCII data; for display to people, the app would use localized comparison (Module 43).
````

````exercise
id: m44-l04-e6
type: design
prompt: "Pick three Pantry actions to expose as App Intents, and for each say: parameters (and whether entities or enums), where it appears (Siri phrase, Spotlight, widget, control, Live Activity), which process runs it, and how it reports success and failure."
rubric:
  - Chooses actions people repeat outside the app, and doesn't expose rare or risky ones without confirmation.
  - Uses entities with persistent ids and queries for app data, and an AppEnum for fixed choices.
  - Matches each surface to the right intent type (AppIntent, SetValueIntent, LiveActivityIntent, foreground mode) and process.
  - Validates in perform(), uses needsValueError or a thrown error appropriately, and saves before returning.
solution: |
  - **Add to shopping list:** `product: ProductEntity` (required), `quantity: Int` (default 1). App Shortcut "Add \(product) to my \(.applicationName) list"; a widget button pre-filled with frequent products; a control "Add Milk". Runs in the widget extension or the app, writing to the App Group store and the server. Over the limit: `needsValueError` with the count; unknown product can't happen with an entity.
  - **Next delivery:** no parameters, dialog result. App Shortcut "When is my \(.applicationName) delivery". Background; reads the shared store.
  - **Reorder last order:** `order: OrderEntity` with `suggestedEntities()` returning recent orders. Spends money, so it uses `requestConfirmation` before placing the order, or adds to the cart and opens the app with a foreground mode (`supportedModes` on iOS 26, `OpenIntent` before). Not a control: one accidental press shouldn't order groceries.
  - **Not exposed:** account deletion, payment changes.
  - All three return only after the write completes, so widgets reloading after the intent and controls reading their value are correct.
````

## Summary

- An app intent describes one action as data: a literal, localized `title`, optional `description`, `@Parameter` inputs and an `async throws` `perform()` that returns a result, such as a dialog. Metadata is extracted at build time, so keep it static.
- Required parameters are non-optional and resolved before `perform()`; optional ones aren't asked for unless you throw `needsValueError`. Validate values in `perform()`: ask again when the person can fix it, throw a localized error when they can't.
- An `AppEntity` exposes app data with a persistent `id`, display representations and a default query. `entities(for:)` finds by id and omits missing ones; `suggestedEntities()` and `EntityStringQuery.entities(matching:)` help people choose. `AppEnum` covers fixed lists.
- An `AppShortcutsProvider` packages intents with phrases containing `\(.applicationName)`, available at install in Siri, Spotlight and Shortcuts.
- The same intents drive interactive widgets (in the extension's process by default; add the intent to both targets), configurable widgets with `WidgetConfigurationIntent` and `AppIntentTimelineProvider`, controls with `ControlWidgetButton` and `SetValueIntent` (iOS 18), and Live Activity buttons with `LiveActivityIntent`.
- Prefer background intents. For foreground ones, `supportedModes` replaces `openAppWhenRun` (deprecated in iOS 26); `OpenIntent` works on earlier versions. Save before returning from `perform()`.
