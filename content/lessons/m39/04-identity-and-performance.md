---
id: m39-l04
title: Identity, dependencies and performance
description: "Module 36 explained what makes a body run. This lesson is about making fewer of them run, and making each one cheap. You run a model of a search screen in three shapes (one big view, split subviews, equatable rows) and count the bodies each event re-evaluates, then apply what Apple's SwiftUI performance article documents: narrow what each body reads, move work out of body, don't store closures, keep ForEach rows constant and their ids stable, and use AnyView and Equatable deliberately. Every claim is labeled as documented, from a WWDC session, or community observation."
module: m39
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l03, m36-l05]
objectives:
  - Predict which bodies re-run after a change, given what each view reads and what it receives from its parent.
  - Narrow a view's dependencies by moving state down and splitting views along what they read.
  - Explain why a computed property returning some View doesn't limit invalidation but a separate View type can.
  - Store a child view's content instead of a closure that builds it, as Apple recommends.
  - Keep List and lazy-stack rows cheap with stable ids, a constant number of views per element and no work in body.
  - Tell documented SwiftUI behavior from WWDC guidance and from community folklore.
terms:
  - term: Dependency
    definition: "Something a body read during its last evaluation: @State, a binding, an @Observable property, an environment value. A change to it invalidates that view. Its inputs from the parent are dependencies too."
  - term: Invalidation boundary
    definition: "A separate View type in the tree. Its body has its own dependencies, so a change that only its parent read can skip it if its inputs didn't change."
  - term: Long view body update
    definition: "Apple's term for a body that takes too long to compute. If updates don't finish before the next frame, the app hitches."
  - term: Update frequency
    definition: "How often a view's body runs. Apple's article treats too-frequent short updates as a separate performance problem from long ones."
  - term: Folklore
    definition: "Performance advice repeated without a source, sometimes true for an old SwiftUI version, sometimes never true. Check it against documentation or a measurement before acting on it."
mastery:
  - Run the dependency model by hand for a new event and list the bodies that run.
  - Refactor a screen so typing in a text field re-evaluates only the field's view.
  - Replace a stored @ViewBuilder closure with its stored result.
  - Move filtering out of a ForEach in a List into the data it iterates.
  - Sort a list of performance claims into documented, WWDC and folklore.
resources: [swiftui-performant-scrollable-stacks, swiftui-migrating-to-observable, swiftui-managing-model-data, swiftui-foreach, xcode-improving-performance]
cards:
  - id: m39-l04-c1
    front: How do you make typing in a TextField stop re-running a whole screen?
    back: "Move the text's @State into the smallest view that needs it (a SearchBar subview), and split the rest into views that don't read it. Each View type has its own dependencies; a computed property returning some View is part of its parent's body and shares its dependencies."
  - id: m39-l04-c2
    front: What does Apple say about storing closures in views?
    back: "Avoid it: a closure can capture state from the parent and make the view update more often. For a closure that builds a child view, call it in the initializer and store the result. Action closures (Button) and closures with parameters (ForEach) are fine, but can still cause extra updates."
  - id: m39-l04-c3
    front: "@Observable vs ObservableObject, for performance?"
    back: "Apple: with @Observable, SwiftUI updates a view only when a property its body read changes. With ObservableObject, any @Published change updates every view observing the object, even if it didn't read that property."
  - id: m39-l04-c4
    front: Why filter data before ForEach in a List instead of using if inside it?
    back: "WWDC23 'Demystify SwiftUI performance': List needs the number of rows; with a constant number of views per element it can get it from the data, while an if inside ForEach forces it to build each element's views to count them. Also simpler code. Not stated in reference docs."
  - id: m39-l04-c5
    front: Should you make every view Equatable?
    back: "No. EquatableView prevents a child from updating when your == says it's equal. Use it for an expensive view whose inputs include values SwiftUI can't compare well (closures), after measuring. A == that ignores an input that matters shows stale data."
---

## The idea in one sentence

SwiftUI re-runs a body when something it depends on changes, so **the fastest body is the one that doesn't depend on the change**, and you control that by deciding which view reads what.

> [!note] About this lesson's code and claims
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run or profiled. Documented behavior is quoted from Apple's articles "Understanding and improving SwiftUI performance", "Migrating from the Observable Object protocol to the Observable macro" and "Creating performant scrollable stacks", and its pages for `AnyView`, `EquatableView` and `equatable()`, read in November 2026. Two WWDC sessions are cited by name, "Demystify SwiftUI" (2021) and "Demystify SwiftUI performance" (2023); what they describe is labeled as such, because it isn't in the reference documentation and can change. The dependency model is plain Swift, compiled and run with Swift 6.3. It encodes the documented triggers plus one community observation (closures compare as different), and it is not SwiftUI's diffing algorithm.

## Two problems, not one

Apple's article "Understanding and improving SwiftUI performance" separates two failures:

1. **Long updates.** "View bodies that take too long to run … reduce overall system efficiency." If updates don't finish before the next frame, "they cause hitches in your app's UI."
2. **Too many updates.** "Sometimes, an app generates a sequence of updates in which each update is short, but the large number of updates in the sequence causes SwiftUI to do a lot of work."

The fixes differ. A long update needs less work inside one body. Too many updates need fewer bodies to depend on the thing that changes. Lesson 5 shows how Instruments tells the two apart; this lesson is about the code.

## A dependency model

Module 36, lesson 5 listed the documented reasons a body runs: state it read, an observable property it read, an environment value it read, or new inputs from its parent. Here those rules are a small program. Each view says what its body reads, what it receives as inputs, and whether one of those inputs is a closure. A change marks the readers; a view that runs re-creates its children, and each child runs if its inputs changed.

```swift
/// A model of which bodies run after a change. Documented rules: a body runs again when state,
/// observable properties or environment values it read change, or when its parent re-creates it
/// with different inputs. How SwiftUI compares inputs isn't documented; this model treats a
/// closure input as always different, which is the common observation, and lets .equatable()
/// replace the comparison.
struct ViewNode {
    let name: String
    var reads: Set<String> = []          // what this body reads: @State, observable properties, environment
    var inputs: Set<String> = []         // values the parent passes in
    var takesClosure = false             // an action closure passed by the parent
    var isEquatable = false              // .equatable(): compares only the values you choose
    var children: [ViewNode] = []
}

func update(_ node: ViewNode, changed: Set<String>, parentRan: Bool = false, log: inout [String]) {
    let readsChange = !node.reads.isDisjoint(with: changed)
    let newInputs = parentRan && (!node.inputs.isDisjoint(with: changed) || (node.takesClosure && !node.isEquatable))
    let runs = readsChange || newInputs
    if runs { log.append(node.name) }
    for child in node.children {
        update(child, changed: changed, parentRan: runs, log: &log)
    }
}

func rows(closure: Bool, equatable: Bool = false) -> [ViewNode] {
    // Each row receives its own product and whether it's a favorite.
    (1...3).map { ViewNode(name: "Row\($0)", inputs: ["product\($0)", "favorite\($0)"], takesClosure: closure, isEquatable: equatable) }
}

// A: one screen owns the query and passes a closure to every row.
let oneBigView = ViewNode(name: "Screen", reads: ["query", "products", "favorites"], children: [
    ViewNode(name: "SearchField", inputs: ["query"]),
] + rows(closure: true))

// B: the query lives in its own subview; the list is a separate view that doesn't read it.
let split = ViewNode(name: "Screen", children: [
    ViewNode(name: "SearchBar", reads: ["query"], children: [ViewNode(name: "SearchField", inputs: ["query"])]),
    ViewNode(name: "ProductList", reads: ["products", "favorites"], children: rows(closure: true)),
])

// C: same as A, but rows are .equatable() on their data.
let equatableRows = ViewNode(name: "Screen", reads: ["query", "products", "favorites"], children: [
    ViewNode(name: "SearchField", inputs: ["query"]),
] + rows(closure: true, equatable: true))

for (label, tree) in [("A one view", oneBigView), ("B split", split), ("C equatable", equatableRows)] {
    for (event, changed) in [("type a letter", ["query"]), ("favorite #2", ["favorites", "favorite2"])] {
        var log: [String] = []
        update(tree, changed: Set(changed), log: &log)
        print("\(label), \(event): \(log.count) bodies \(log)")
    }
}
```

```output
A one view, type a letter: 5 bodies ["Screen", "SearchField", "Row1", "Row2", "Row3"]
A one view, favorite #2: 4 bodies ["Screen", "Row1", "Row2", "Row3"]
B split, type a letter: 2 bodies ["SearchBar", "SearchField"]
B split, favorite #2: 4 bodies ["ProductList", "Row1", "Row2", "Row3"]
C equatable, type a letter: 2 bodies ["Screen", "SearchField"]
C equatable, favorite #2: 2 bodies ["Screen", "Row2"]
```

Read each line as a question: *who read the thing that changed, and who got new inputs from someone who ran?*

- **A, typing.** `Screen` read `query`, so it runs. It re-creates `SearchField` with a new query (runs) and every row with a fresh closure (runs, by the observation the model encodes). Five bodies per keystroke, three of them for rows that show nothing about the query. With 50 rows, it's 52.
- **B, typing.** The query lives in `SearchBar`. `Screen` doesn't read it, so it doesn't run, and neither does `ProductList`. Two bodies, whatever the number of rows. This is the fix that scales: **move state down to the smallest view that needs it.**
- **B, favoriting.** `ProductList` reads `favorites`, so it runs and re-creates all rows with new closures. Splitting didn't help this event.
- **C, favoriting.** With `.equatable()` comparing only the product and the favorite flag, rows 1 and 3 compare equal and skip; only row 2 runs. Equatable helps exactly where inputs include something SwiftUI can't compare.

The 50-row version of this arithmetic is the reason to care. None of these bodies is slow; it's the count that grows.

## Narrowing dependencies

### Move state down

The B shape, in SwiftUI. The search text is a draft the user edits; the list only cares about the submitted term, which lives in the model.

```swift ios
import SwiftUI
import Observation

struct Product: Identifiable, Equatable {
    let id: Int
    var name: String
}

@MainActor
@Observable
final class CatalogModel {
    var products: [Product] = (1...50).map { Product(id: $0, name: "Product \($0)") }
    var favorites: Set<Product.ID> = []
    var searchTerm = ""

    var results: [Product] {
        searchTerm.isEmpty ? products : products.filter { $0.name.localizedStandardContains(searchTerm) }
    }

    func toggleFavorite(_ id: Product.ID) {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
    }
}

struct CatalogScreen: View {
    let model: CatalogModel

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(model: model)
            ProductList(model: model)
        }
    }
}

/// Owns the draft. Typing invalidates only this view.
struct SearchBar: View {
    let model: CatalogModel
    @State private var draft = ""

    var body: some View {
        TextField("Search", text: $draft)
            .textFieldStyle(.roundedBorder)
            .onSubmit { model.searchTerm = draft }
            .padding()
    }
}

/// Reads results and favorites, never the draft.
struct ProductList: View {
    let model: CatalogModel

    var body: some View {
        List(model.results) { product in
            ProductRow(product: product, isFavorite: model.favorites.contains(product.id)) {
                model.toggleFavorite(product.id)
            }
            .equatable()
        }
    }
}

struct ProductRow: View, Equatable {
    let product: Product
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    nonisolated static func == (lhs: ProductRow, rhs: ProductRow) -> Bool {
        lhs.product == rhs.product && lhs.isFavorite == rhs.isFavorite   // the closure is ignored on purpose
    }

    var body: some View {
        HStack {
            Text(product.name)
            Spacer()
            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
            }
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }
}
```

Three documented facts make this work:

- **Per-property tracking.** `CatalogScreen`, `SearchBar` and `ProductList` all hold the same model, and that's fine. Apple's migration article: with `@Observable`, "SwiftUI updates a view only when an observable property changes and the view's `body` reads the property directly." `CatalogScreen`'s body reads nothing from the model, so nothing in the model invalidates it. With `ObservableObject`, by contrast, "a view updates when any published property … changes, even if the view doesn't read the property that changes." Apple's performance article lists migrating to `@Observable` as a fix for too-frequent updates.
- **State lives where it's used.** The draft is `SearchBar`'s `@State`. Only `SearchBar`'s body reads it.
- **Each View type is its own body.** `ProductList` is a separate type with its own dependencies (`results`, which reads `searchTerm` and `products`, and `favorites`).

### Why a computed property isn't a boundary

A common refactor is to split a long body into computed properties:

```swift illustrative
var body: some View {
    VStack {
        header        // var header: some View { … reads model.title … }
        productList   // var productList: some View { … reads model.results … }
    }
}
```

This reads better, but it doesn't change dependencies: `header` and `productList` are evaluated as part of `body`, during the same evaluation, so whatever they read, `body` read. A change to `model.title` re-runs the whole thing, list included. Moving `productList` into `struct ProductList: View` gives it its own body and its own dependencies. Apple's WWDC21 session "Demystify SwiftUI" describes views as having their own dependency graph per view, and WWDC23's "Demystify SwiftUI performance" recommends extracting views for this reason; the reference documentation says only that dependencies are what a view's `body` reads, which leads to the same conclusion.

### Pass what the child needs

A child that receives the whole model reads only what its body touches (that's Observation). A child that receives a plain value, such as `isFavorite: Bool` in `ProductRow`, has an input that SwiftUI can compare when the parent re-runs. Pass values to leaf views that display them, and the model (or a closure) to views that need to change it.

## Keep each body cheap

### No real work in body, init or onAppear

Apple's article is specific: "A common cause of long view body updates is performing expensive calculations in the view's `body` property. Instead, perform the calculation asynchronously, and cache the result." And: "avoid performing complex, long-running tasks in your `View` initializer," in `body`, in `onAppear(perform:)`, "and any other modifiers that can modify view state." Sorting thousands of items, parsing, building a `DateFormatter`, decoding an image: put them in the model, compute them when the input changes, and let `body` read the result. `task(id:)` from Module 36 is the tool when the work is asynchronous.

`CatalogModel.results` above is a computed property that filters on every read. With 50 products that's free; with 50,000 it's the long body update Apple describes, and it would be stored and recomputed when `searchTerm` or `products` changes (Module 36, lesson 6 covered when derived state should be stored).

### Don't store closures that build views

This one is easy to miss, and Apple documents it: "Avoid storing closures in views. Closures can capture additional state from your parent view that make the view update more often." The fix for content closures: "call the closure in the initializer so you only store its return value. Don't mark the closure escaping."

```swift ios
import SwiftUI

/// Stores the built content, not the closure that builds it.
struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct AccountSummary: View {
    let balance: String

    var body: some View {
        Card(title: "Balance") {
            Text(balance)
                .font(.largeTitle.bold())
        }
    }
}
```

The `content` parameter isn't `@escaping`, so it can't be stored by mistake; `Card` keeps a `Text`, a value SwiftUI can work with. Apple adds that this isn't needed "for action closures, like the closure you pass to `Button`, or closures that require a parameter, like the closure you pass to `ForEach`," while noting such closures "could still cause excessive updates." `ProductRow`'s `onToggleFavorite` is such an action closure, which is why the model treats it as an input that changes, and why `.equatable()` was worth it there.

### AnyView

Module 34, lesson 3 showed `AnyView`'s documented cost: "Whenever the type of view used with an `AnyView` changes, the old hierarchy is destroyed and a new hierarchy is created for the new type." That's a state cost and a performance cost (rebuilding a subtree is work). The other cost is less visible: `some View` and `@ViewBuilder` conditionals give SwiftUI the full type, `_ConditionalContent<A, B>`, so it knows the structure in advance; `AnyView` hides it. "Demystify SwiftUI" (WWDC21) recommends avoiding `AnyView` where a builder works. For a view chosen at run time from a registry, `AnyView` is the honest tool; for "make both branches the same type," use `@ViewBuilder`.

## Lists and lazy stacks

**Start with a plain stack.** Apple's "Creating performant scrollable stacks": lazy stacks "load and render their subviews on-demand," but "trade some degree of layout correctness for performance," so "always start with a standard stack view and only switch to a lazy stack if profiling your code shows a worthwhile performance improvement." Its example profiles 1,000 rows in an `HStack` and sees all 1,000 load at once; in a `LazyHStack`, only the four on screen.

**Stable ids.** A row's identity is its `ForEach` id (Module 34, lesson 5; Module 36, lesson 5). An unstable id makes SwiftUI treat an updated row as a removed one plus a new one: state lost, insert and remove animations, work redone. `id: \.self` on strings that can repeat, indices that shift on insert, and ids generated in `body` all cause it.

**A constant number of views per element.** In "Demystify SwiftUI performance" (WWDC23), Apple explains that `List` needs to know how many rows it has, and that it can get that from the data cheaply only when each `ForEach` element produces a fixed number of views. An `if` inside the `ForEach` makes the count depend on running each element's content. Filter the data instead:

```swift ios
import SwiftUI

struct TaskItem: Identifiable {
    let id: Int
    var title: String
    var isDone: Bool
}

struct TaskListView: View {
    let tasks: [TaskItem]
    @State private var showsCompleted = false

    private var visibleTasks: [TaskItem] {
        showsCompleted ? tasks : tasks.filter { !$0.isDone }
    }

    var body: some View {
        List {
            Toggle("Show completed", isOn: $showsCompleted)
            // Not: ForEach(tasks) { task in if showsCompleted || !task.isDone { Text(task.title) } }
            ForEach(visibleTasks) { task in
                Text(task.title)
                    .strikethrough(task.isDone)
            }
        }
    }
}
```

This guidance isn't in the `List` or `ForEach` reference pages; it comes from that session. The code is clearer either way, which makes it an easy rule to follow.

## Documented, WWDC, or folklore

Performance advice travels without sources. Before acting on a claim, place it in one of these columns:

| Claim | Status |
| --- | --- |
| A body re-runs when state, observable properties or environment values it read change, or its inputs change | **Documented** (Apple's pages for `State`, `Environment`, "Managing model data", "Managing user interface state") |
| `@Observable` updates only views whose body read the changed property; `ObservableObject` updates all observers | **Documented** (migration article) |
| Expensive work in `body`, `init` or `onAppear` causes long updates | **Documented** (performance article) |
| Storing a closure in a view can cause extra updates; store the built content | **Documented** (performance article) |
| `AnyView` destroys its subtree when the wrapped type changes | **Documented** (`AnyView`) |
| Start with a standard stack; switch to a lazy one after profiling | **Documented** ("Creating performant scrollable stacks") |
| Extracting a subview creates a separate dependency scope; a computed property doesn't | **WWDC** ("Demystify SwiftUI", "Demystify SwiftUI performance"), consistent with the docs |
| Keep a constant number of views per `ForEach` element in a `List` | **WWDC** ("Demystify SwiftUI performance") |
| Closures in a view's inputs always compare as changed | **Community observation**, not documented |
| "Make every view `Equatable`" | **Folklore.** `EquatableView` is a targeted tool; a wrong `==` shows stale data |
| "Always use `LazyVStack`" | **Folklore**, contradicted by Apple's article |
| "View structs are expensive, avoid creating them" | **Folklore.** Creating them is cheap; work *in* `init` is the documented problem |
| "`GeometryReader` is always slow" | **Overstated.** Apple's article notes layout readers recalculate on layout changes and suggests moving unrelated state out of their subtree, not avoiding them |

The last word goes to a measurement. Lesson 5 shows how to get one.

## Common mistakes

> [!error] The text field's @State on the screen
> Every keystroke re-runs the screen's body and everything it re-creates. Move the text into a subview, or keep a draft there and commit it on submit.

> [!error] Splitting body into computed properties and expecting fewer updates
> `var header: some View` is part of `body`. To get a separate dependency scope, make it a `struct Header: View`.

> [!error] Sorting or formatting inside body
> It runs on every evaluation. Compute it in the model when the inputs change, or in `task(id:)` if it's asynchronous.

> [!error] @escaping content closures stored in a container view
> Apple: call the closure in the initializer and store its result. A non-escaping `@ViewBuilder` parameter makes it impossible to store by accident.

> [!error] .equatable() with a == that ignores a displayed value
> The view stops updating when that value changes. Compare everything the body shows; ignore only what it doesn't display, such as action closures.

> [!error] if inside ForEach in a List
> Filter the collection the `ForEach` iterates. Each element should produce the same number of views.

## Exercises

````exercise
id: m39-l04-e1
type: prediction
prompt: "The dependency model for a settings screen. The user toggles 'Notifications'. Which bodies run?"
code: |
  struct ViewNode {
      let name: String
      var reads: Set<String> = []
      var inputs: Set<String> = []
      var takesClosure = false
      var isEquatable = false
      var children: [ViewNode] = []
  }

  func update(_ node: ViewNode, changed: Set<String>, parentRan: Bool = false, log: inout [String]) {
      let readsChange = !node.reads.isDisjoint(with: changed)
      let newInputs = parentRan && (!node.inputs.isDisjoint(with: changed) || (node.takesClosure && !node.isEquatable))
      let runs = readsChange || newInputs
      if runs { log.append(node.name) }
      for child in node.children {
          update(child, changed: changed, parentRan: runs, log: &log)
      }
  }

  let settings = ViewNode(name: "Settings", reads: ["notifications", "theme"], children: [
      ViewNode(name: "NotificationsRow", inputs: ["notifications"]),
      ViewNode(name: "ThemeRow", inputs: ["theme"]),
      ViewNode(name: "AccountSection", reads: ["userName"], children: [
          ViewNode(name: "AvatarView", inputs: ["userName"]),
      ]),
      ViewNode(name: "SignOutButton", takesClosure: true),
      ViewNode(name: "AboutRow", takesClosure: true, isEquatable: true),
  ])

  var log: [String] = []
  update(settings, changed: ["notifications"], log: &log)
  print(log)
output: |
  ["Settings", "NotificationsRow", "SignOutButton"]
hints:
  - "Settings reads notifications, so it runs and re-creates its direct children."
  - "AccountSection gets no inputs from Settings that changed, and doesn't read notifications."
  - "AboutRow takes a closure but is equatable."
solution: |
  ```output
  ["Settings", "NotificationsRow", "SignOutButton"]
  ```

  `Settings` read `notifications`, so it runs. Its children: `NotificationsRow` gets a changed input (runs); `ThemeRow` doesn't; `AccountSection` has no changed input and doesn't read `notifications`, so neither it nor `AvatarView` runs; `SignOutButton` gets a new closure (runs, by the model's closure rule); `AboutRow` also gets a closure, but its `==` ignores it, so it's skipped. Moving the toggle's state into `NotificationsRow` would leave one body: the row's.
````

````exercise
id: m39-l04-e2
type: prediction
prompt: "Same screen as e1, but the user's name changes. What does it print?"
code: |
  struct ViewNode {
      let name: String
      var reads: Set<String> = []
      var inputs: Set<String> = []
      var takesClosure = false
      var isEquatable = false
      var children: [ViewNode] = []
  }

  func update(_ node: ViewNode, changed: Set<String>, parentRan: Bool = false, log: inout [String]) {
      let readsChange = !node.reads.isDisjoint(with: changed)
      let newInputs = parentRan && (!node.inputs.isDisjoint(with: changed) || (node.takesClosure && !node.isEquatable))
      let runs = readsChange || newInputs
      if runs { log.append(node.name) }
      for child in node.children {
          update(child, changed: changed, parentRan: runs, log: &log)
      }
  }

  let settings = ViewNode(name: "Settings", reads: ["notifications", "theme"], children: [
      ViewNode(name: "NotificationsRow", inputs: ["notifications"]),
      ViewNode(name: "ThemeRow", inputs: ["theme"]),
      ViewNode(name: "AccountSection", reads: ["userName"], children: [
          ViewNode(name: "AvatarView", inputs: ["userName"]),
      ]),
      ViewNode(name: "SignOutButton", takesClosure: true),
      ViewNode(name: "AboutRow", takesClosure: true, isEquatable: true),
  ])

  var log: [String] = []
  update(settings, changed: ["userName"], log: &log)
  print(log.count, log)
output: |
  2 ["AccountSection", "AvatarView"]
hints:
  - "Settings doesn't read userName."
  - "AccountSection reads it directly, even though its parent didn't run."
solution: |
  ```output
  2 ["AccountSection", "AvatarView"]
  ```

  `Settings` doesn't read `userName`, so it doesn't run, and none of its other children are re-created. `AccountSection` reads `userName` itself, so it's invalidated directly, without its parent. That's what a dependency scope buys: the change goes straight to the view that read it. `AvatarView` runs because `AccountSection` re-created it with a new name.
````

````exercise
id: m39-l04-e3
type: comprehension
multiple: true
prompt: "Which of these are stated in Apple's documentation (not only in WWDC sessions or blog posts)? Select all that apply."
choices:
  - text: "With @Observable, a view updates only when a property its body read changes."
    correct: true
    why: "The migration article says so explicitly."
  - text: "Storing closures in views can make them update more often; call a content closure in init and store the result."
    correct: true
    why: "Understanding and improving SwiftUI performance, 'Adopt efficient SwiftUI design patterns'."
  - text: "Always use LazyVStack inside a ScrollView."
    correct: false
    why: "Apple says to start with a standard stack and switch after profiling."
  - text: "Closures passed as view inputs always compare as different."
    correct: false
    why: "How SwiftUI compares inputs isn't documented; this is a community observation."
  - text: "In a List, each ForEach element should produce a constant number of views."
    correct: false
    why: "That guidance is from WWDC23's 'Demystify SwiftUI performance', not the reference docs."
  - text: "Expensive calculations in body cause long view body updates; do them asynchronously and cache the result."
    correct: true
    why: "Same performance article, 'Improve long-running view body computations'."
solution: |
  **The @Observable tracking rule, the closure advice and the expensive-body advice** are documented. The lazy-stack claim contradicts Apple's own advice. The closure comparison is an observation from people who've measured it, useful but not a guarantee. The constant-rows rule is real Apple guidance, but from a WWDC session rather than the docs; it's worth following, and worth knowing where it comes from.
````

````exercise
id: m39-l04-e4
type: solve
prompt: |
  This screen re-runs everything on each keystroke in the note field, including a chart that's slow to compute. Refactor it so typing only re-runs the view that owns the note, and the chart's data is computed once per change of `samples`, not on every body evaluation. Keep the behavior the same.
starter: |
  import SwiftUI

  struct WorkoutScreen: View {
      let samples: [Double]
      @State private var note = ""

      var body: some View {
          VStack {
              TextField("Note", text: $note)
              let smoothed = samples.indices.map { index in
                  let window = samples[max(0, index - 4)...index]
                  return window.reduce(0, +) / Double(window.count)
              }
              HStack(alignment: .bottom, spacing: 2) {
                  ForEach(smoothed.indices, id: \.self) { index in
                      Rectangle().frame(width: 4, height: smoothed[index])
                  }
              }
          }
      }
  }
hints:
  - "Move the TextField and its @State into a NoteField view."
  - "Move the chart into its own view that takes the smoothed values, computed in its initializer from samples."
rubric:
  - The note's @State lives in a separate view; WorkoutScreen no longer reads it.
  - The smoothing runs outside body (in an initializer or the model), once per samples value.
  - The chart is a separate View type with value inputs.
  - Type-checks.
solution: |
  ```swift ios
  import SwiftUI

  struct WorkoutScreen: View {
      let samples: [Double]

      var body: some View {
          VStack {
              NoteField()
              SmoothedChart(samples: samples)
          }
      }
  }

  struct NoteField: View {
      @State private var note = ""

      var body: some View {
          TextField("Note", text: $note)
      }
  }

  struct SmoothedChart: View {
      private let smoothed: [Double]

      init(samples: [Double]) {
          smoothed = samples.indices.map { index in
              let window = samples[max(0, index - 4)...index]
              return window.reduce(0, +) / Double(window.count)
          }
      }

      var body: some View {
          HStack(alignment: .bottom, spacing: 2) {
              ForEach(smoothed.indices, id: \.self) { index in
                  Rectangle()
                      .frame(width: 4, height: smoothed[index])
              }
          }
          .accessibilityElement()
          .accessibilityLabel("Smoothed heart rate chart")
      }
  }
  ```

  Typing now invalidates only `NoteField`: `WorkoutScreen` no longer reads `note`, so it doesn't run, and neither does the chart. The smoothing moved from `body` to `SmoothedChart.init`, which runs when `WorkoutScreen` re-creates the chart, that is, when `samples` changes. For a few hundred samples that's enough. For thousands, Apple's advice is to compute it asynchronously and cache it, for example in the model that owns `samples`. (Using `indices` as ids is acceptable here because the bars have no state and the array is replaced as a whole.)
````

````exercise
id: m39-l04-e5
type: find-errors
prompt: "A transactions list that scrolls poorly with a few thousand items. Which of these are real problems?"
code: |
  struct TransactionsView: View {
      let transactions: [Transaction]
      @State private var showsPending = true

      var body: some View {
          List {
              ForEach(transactions.sorted { $0.date > $1.date }, id: \.merchant) { transaction in
                  if showsPending || !transaction.isPending {
                      AnyView(TransactionRow(transaction: transaction,
                                             formatter: makeCurrencyFormatter()))
                  }
              }
          }
      }
  }
choices:
  - text: "The list is sorted inside body, so it's re-sorted on every evaluation."
    correct: true
    why: "Apple: expensive calculations in body cause long updates; sort once when the data changes."
  - text: "id: \\.merchant isn't unique: two purchases at the same store share an id."
    correct: true
    why: "Duplicate ids confuse identity: rows get the wrong state and animations misbehave."
  - text: "The if inside ForEach makes the number of rows per element vary."
    correct: true
    why: "Filter the data first (WWDC23 guidance), which is also clearer."
  - text: "A new formatter is created for every row on every evaluation."
    correct: true
    why: "Formatters are relatively expensive; create one and reuse it, or use FormatStyle."
  - text: "AnyView wraps each row although the type never changes."
    correct: true
    why: "It hides the row's type for no benefit; return TransactionRow directly."
  - text: "List can't contain ForEach."
    correct: false
    why: "List with ForEach is the normal way to mix static and dynamic rows."
rubric:
  - Flags sorting in body.
  - Flags the non-unique id.
  - Flags the if inside ForEach.
  - Flags per-row formatter creation.
  - Flags the unnecessary AnyView.
solution: |
  Five problems, each documented or widely measured. A fixed version:

  ```swift ios
  import SwiftUI

  struct Transaction: Identifiable {
      let id: UUID
      let merchant: String
      let amount: Decimal
      let date: Date
      let isPending: Bool
  }

  struct TransactionRow: View {
      let transaction: Transaction

      var body: some View {
          HStack {
              Text(transaction.merchant)
              Spacer()
              Text(transaction.amount, format: .currency(code: "USD"))
          }
      }
  }

  struct TransactionsView: View {
      private let sorted: [Transaction]
      @State private var showsPending = true

      init(transactions: [Transaction]) {
          sorted = transactions.sorted { $0.date > $1.date }
      }

      private var visible: [Transaction] {
          showsPending ? sorted : sorted.filter { !$0.isPending }
      }

      var body: some View {
          List {
              Toggle("Show pending", isOn: $showsPending)
              ForEach(visible) { transaction in
                  TransactionRow(transaction: transaction)
              }
          }
      }
  }
  ```

  Sorting happens once per new array, in `init`. Ids come from `Identifiable` (a stable `UUID` from the data), so two coffees at the same café are two rows. The filter runs on the data, so each element produces one row. The row formats with `.currency(code:)`, a `FormatStyle` value, instead of a new formatter per row. And `AnyView` is gone, so SwiftUI sees `TransactionRow` directly. In a real app the sorted array would live in the model, sorted when it loads.
````

````exercise
id: m39-l04-e6
type: refactor
prompt: "Refactor this container so it follows Apple's advice on closures in views. Explain what changes for SwiftUI."
code: |
  struct Section<Content: View>: View {
      let title: String
      let content: () -> Content

      init(title: String, @ViewBuilder content: @escaping () -> Content) {
          self.title = title
          self.content = content
      }

      var body: some View {
          VStack(alignment: .leading) {
              Text(title).font(.headline)
              content()
          }
      }
  }
rubric:
  - Stores Content, not () -> Content.
  - Calls the closure in init and removes @escaping.
  - Explains that the stored closure could capture parent state and cause extra updates, per Apple's article.
  - Renames the type or notes the clash with SwiftUI's Section.
solution: |
  ```swift ios
  import SwiftUI

  struct TitledSection<Content: View>: View {
      let title: String
      let content: Content

      init(title: String, @ViewBuilder content: () -> Content) {
          self.title = title
          self.content = content()
      }

      var body: some View {
          VStack(alignment: .leading) {
              Text(title)
                  .font(.headline)
              content
          }
      }
  }
  ```

  The view now stores the content it builds, not the closure. Apple's performance article explains why: a stored closure "can capture additional state from your parent view that make the view update more often," and recommends calling it "in the initializer so you only store its return value" without marking it escaping. Removing `@escaping` also makes the compiler enforce it. The type is renamed because `Section` is already a SwiftUI type, and shadowing it makes every `Section` in the module ambiguous to readers.
````

````exercise
id: m39-l04-e7
type: explain
prompt: "A teammate split a 200-line body into five computed properties (var header: some View, var filters: some View, and so on) and says the screen now updates less. Explain whether that's true, what would actually reduce updates, and how you'd check."
rubric:
  - Computed properties are evaluated as part of body and share its dependencies; nothing changes for SwiftUI.
  - Separate View types (structs) get their own dependency scope; state moved into them invalidates only them.
  - Mentions passing narrow inputs and @Observable per-property tracking.
  - Suggests measuring with _printChanges or the SwiftUI instrument (lesson 5) before and after.
solution: |
  A sample answer: "It's more readable, but SwiftUI sees the same thing: a computed property is evaluated during `body`, so whatever it reads, `body` read, and any of those changes re-runs all five pieces. To reduce updates, turn the pieces that depend on different things into separate `View` structs, move each piece of `@State` into the struct that uses it, and pass leaf views plain values. With `@Observable` models, each struct then depends only on the properties its own body reads. To check, add `let _ = Self._printChanges()` to the views temporarily, or record the screen with the SwiftUI template in Instruments, and compare body counts for the same interaction before and after."
````

## Summary

- Two performance problems: long body updates (too much work in one body) and too many updates (too many bodies depend on a change). They have different fixes.
- A body re-runs when something it read changes or its parent gives it new inputs. Move state down to the smallest view that reads it, and split views along what they read.
- A computed `some View` property shares its parent's dependencies; a separate `View` type has its own.
- With `@Observable`, views depend only on the properties their bodies read; passing the model around is fine. `ObservableObject` updates every observer.
- No expensive work in `body`, `init` or `onAppear`. Store built content, not content closures. Use `AnyView` only for types truly chosen at run time.
- Start with plain stacks; go lazy after profiling. Keep ids stable and one row per element; filter data before `ForEach`.
- Use `.equatable()` for expensive views whose inputs include closures, comparing everything they display.
- Label every performance claim: documented, WWDC, observation or folklore. Then measure.
