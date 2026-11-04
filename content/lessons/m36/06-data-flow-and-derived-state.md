---
id: m36-l06
title: Data flow and derived state
description: "The rules from this module in one place. Store each fact once, in the owner whose lifetime matches it; compute everything else from it. You see the stale-copy bug in its usual disguises (a stored count, a copied name, a filtered array kept in @State), learn when a copy is the right design (an edit draft), add @AppStorage and @SceneStorage to the toolbox, and finish with a decision table for where each piece of state belongs."
module: m36
order: 6
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l05]
objectives:
  - Tell stored state from derived state and compute derived values instead of storing them.
  - Recognize the stale-copy bug in a stored count, a copied @State value and a cached filtered list.
  - Design an edit draft as a deliberate copy with clear start, save and cancel points.
  - Use @AppStorage for small user preferences and @SceneStorage for per-window restoration, and know their limits.
  - Choose the right home for a piece of state with a decision table.
terms:
  - term: Derived state
    definition: "A value that can be computed from other state, such as a count, a total, a filtered list or a validation result. It belongs in a computed property or in body, not in storage."
  - term: Stale copy
    definition: "A stored duplicate of data that lives elsewhere. It's correct when made and wrong as soon as the original changes through a path that doesn't update the copy."
  - term: Draft
    definition: "A deliberate copy of data for an edit session: created when editing starts, changed freely, written back on save and discarded on cancel."
  - term: "@AppStorage"
    definition: "A SwiftUI property wrapper (iOS 14) that reads and writes a value in UserDefaults and updates the view when that default changes. For small, non-sensitive preferences."
  - term: "@SceneStorage"
    definition: "A SwiftUI property wrapper (iOS 14) for small per-scene values that the system saves and restores, such as the selected tab or a navigation path."
mastery:
  - Replace a stored count or total with a computed property and show the bug it removes.
  - Spot @State initialized from an input that should have been derived or bound.
  - Build an edit sheet with a draft, a derived hasChanges and canSave, and Save and Cancel.
  - Store a units preference with @AppStorage and an enum backed by a String.
  - For a new screen, place each piece of state in @State, @Binding, an @Observable model, the environment, a parameter, @AppStorage or @SceneStorage, and justify it.
resources: [swiftui-managing-ui-state, swiftui-migrating-to-observable, foundation-userdefaults, swift-book-properties]
cards:
  - id: m36-l06-c1
    front: Stored or derived?
    back: "If a value can be computed from state you already have (a count, a total, a filtered list, whether a form is valid), derive it: a computed property or an expression in body. Store only facts that can't be recomputed."
  - id: m36-l06-c2
    front: Why is @State initialized from an input a smell?
    back: "It's a copy. @State uses its initial value only on first appearance, so when the input changes the copy doesn't follow. Use the input directly (derive), take a @Binding (share), or make it an explicit draft with a defined lifetime."
  - id: m36-l06-c3
    front: When is a copy the right design?
    back: "For an edit draft: the user changes a copy, Save writes it back, Cancel discards it. Give it a clear lifetime (a sheet presentation, an .id per item) and derive hasChanges and canSave from draft vs original."
  - id: m36-l06-c4
    front: "@AppStorage vs @SceneStorage?"
    back: "@AppStorage: a UserDefaults value shared by the whole app and kept across launches, for small preferences (units, a toggle). @SceneStorage: per window, restored by the system, for UI restoration (selected tab, path). Neither for large or sensitive data."
  - id: m36-l06-c5
    front: Where does each kind of state go?
    back: "View-local UI state: @State. Shared with a child: @State in the owner plus @Binding. Feature data and logic: an @Observable model in @State, passed down or in the environment. App-wide context: environment. Data a view just shows: a parameter. Preferences: @AppStorage. Per-window restoration: @SceneStorage."
---

## The idea in one sentence

**Store each fact once, in the owner whose lifetime matches it, and compute everything else**, because every stored duplicate is a chance for two parts of the screen to disagree.

> [!note] About this lesson's code
> The models of stored and derived state are plain Swift (with Observation), compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Quotes come from Apple's pages for `AppStorage`, `SceneStorage`, "Managing user interface state" and "Managing model data in your app", read in November 2026.

## One source of truth, again

Every lesson in this module has been about the same rule from a different side. Lesson 1: a value has one owner, and children get a binding, not a copy. Lesson 2: a model object is the single source of truth for its data, and views read it. Lesson 3: the environment makes the source reachable, but doesn't duplicate it. Lesson 5: state lives as long as identity, so a copy made at the start of a lifetime doesn't follow later inputs.

This lesson is about the most common way the rule gets broken: storing something that should have been computed.

## Derived vs stored state

Module 34, lesson 1 rendered "2 expenses" after removing one, because an imperative update forgot a label. Moving to SwiftUI removes the labels, but the same bug comes back if you **store** a value that depends on other state:

```swift
import Observation

struct Todo {
    let title: String
    var isDone = false
}

/// Stores a derived value and keeps it in sync by hand.
@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class StoredCountList {
    private(set) var todos: [Todo] = []
    private(set) var remainingCount = 0

    func add(_ title: String) {
        todos.append(Todo(title: title))
        remainingCount += 1
    }

    func toggle(at index: Int) {
        todos[index].isDone.toggle()
        // Forgot remainingCount.
    }

    func removeDone() {
        todos.removeAll(where: \.isDone)
    }
}

/// Derives it every time it's read.
@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class DerivedCountList {
    private(set) var todos: [Todo] = []

    var remainingCount: Int {
        todos.filter { !$0.isDone }.count
    }

    func add(_ title: String) {
        todos.append(Todo(title: title))
    }

    func toggle(at index: Int) {
        todos[index].isDone.toggle()
    }

    func removeDone() {
        todos.removeAll(where: \.isDone)
    }
}

if #available(macOS 14, iOS 17, *) {
    let stored = StoredCountList()
    let derived = DerivedCountList()
    for title in ["Milk", "Eggs", "Bread"] {
        stored.add(title)
        derived.add(title)
    }
    stored.toggle(at: 0)
    derived.toggle(at: 0)
    print("stored: \(stored.todos.count) todos, \(stored.remainingCount) remaining")
    print("derived: \(derived.todos.count) todos, \(derived.remainingCount) remaining")
    stored.removeDone()
    derived.removeDone()
    print("stored: \(stored.todos.count) todos, \(stored.remainingCount) remaining")
    print("derived: \(derived.todos.count) todos, \(derived.remainingCount) remaining")
}
```

```output
stored: 3 todos, 3 remaining
derived: 3 todos, 2 remaining
stored: 2 todos, 3 remaining
derived: 2 todos, 2 remaining
```

`StoredCountList` is right after the adds, wrong after a toggle (the method forgot to decrement), and still wrong after removing done items. Each new method is another place to remember the count. `DerivedCountList` can't get it wrong: there's no count to update, only a question asked of `todos` every time. And because `remainingCount` reads `todos`, Observation tracks it (lesson 2), so a view showing it updates whenever `todos` changes.

Typical derived values:

- **Counts, totals, averages.** `items.count`, `items.reduce(0) { $0 + $1.price }`.
- **Filtered and sorted lists.** `items.filter { $0.matches(query) }.sorted(by: order)`.
- **Validation.** `isValid`, `canSave`, `errorMessage` computed from the fields.
- **Display strings.** "3 of 5 done", a formatted date.

**What about cost?** A computed property runs every time it's read. For tens or hundreds of items, filtering and sorting in a computed property is cheap, and SwiftUI only re-reads it when a body that uses it runs. When it's genuinely expensive (thousands of items, an expensive sort, measured in Instruments), cache it in the model, and recompute the cache **in the one place that changes the source**: make the source `private(set)` and have every mutating method call the same `recompute()`. That's still one source of truth, with a cache that has a single writer.

## The stale copy in a view

The view-side version of the bug is `@State` initialized from an input:

```swift ios
import SwiftUI

@Observable
final class Contact {
    var firstName = "Ana"
    var lastName = "Ruiz"
}

// Stale: copies the name when the header first appears.
struct CopyingHeader: View {
    let contact: Contact
    @State private var fullName: String

    init(contact: Contact) {
        self.contact = contact
        _fullName = State(initialValue: "\(contact.firstName) \(contact.lastName)")
    }

    var body: some View {
        Text(fullName)
    }
}

// Correct: derives the name in body, so it reads (and tracks) the contact.
struct DerivingHeader: View {
    let contact: Contact

    var body: some View {
        Text("\(contact.firstName) \(contact.lastName)")
    }
}
```

`CopyingHeader` breaks twice. Its body reads `fullName`, its own state, never `contact.lastName`, so Observation has no dependency on the contact and a rename doesn't update it. And if the parent passes a different contact to the same identity, `@State` ignores the new initial value (lesson 1). Exercise 1 runs both failures in a model. `DerivingHeader` reads the contact in `body`, so it's always current.

The same smell in other forms:

- **A filtered list in `@State`**, recomputed in `.onChange(of: query)`. When the items change, nothing refilters. Compute it in a property instead (exercise 6).
- **A `Bool` mirroring a model property**, kept in sync with `onChange` in both directions. Bind to the model with `@Bindable` instead.
- **A count stored in the model next to the array it counts**, as above.

The question to ask of every `@State` and every stored model property: **"Could I compute this from something I already have?"** If yes, compute it.

## When a copy is the design: drafts

There's one copy that's correct by design: an **edit draft**. The user opens an editor, changes things, and either saves or cancels. During the edit, the original must not change (other screens are still showing it, and Cancel must restore it). So the editor works on a copy, with three defined moments:

1. **Start**: copy the original into the draft.
2. **Save**: write the draft back to the source of truth.
3. **Cancel**: throw the draft away.

Everything else about the draft is derived: whether there are changes, whether it can be saved, what error to show.

```swift ios
import SwiftUI

struct ContactInfo: Identifiable, Equatable {
    let id: Int
    var name: String
    var phone: String
}

struct ContactEditSheet: View {
    let original: ContactInfo
    let onSave: (ContactInfo) -> Void
    @State private var draft: ContactInfo
    @Environment(\.dismiss) private var dismiss

    init(original: ContactInfo, onSave: @escaping (ContactInfo) -> Void) {
        self.original = original
        self.onSave = onSave
        _draft = State(initialValue: original)
    }

    private var hasChanges: Bool { draft != original }
    private var canSave: Bool { hasChanges && !draft.name.allSatisfy(\.isWhitespace) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                TextField("Phone", text: $draft.phone)
            }
            .navigationTitle("Edit contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }
}

struct ContactsScreen: View {
    @State private var contacts = [ContactInfo(id: 1, name: "Ana", phone: "555-0100")]
    @State private var editing: ContactInfo?

    var body: some View {
        List(contacts) { contact in
            Button(contact.name) { editing = contact }
        }
        .sheet(item: $editing) { contact in
            ContactEditSheet(original: contact) { updated in
                if let index = contacts.firstIndex(where: { $0.id == updated.id }) {
                    contacts[index] = updated
                }
            }
        }
    }
}
```

This is `@State` initialized from an input, which the previous section called a smell. What makes it right here:

- **The copy is the point.** The list must keep showing "Ana" until Save. A binding would change it on every keystroke.
- **Its lifetime is the edit session.** `sheet(item:)` presents a new sheet for each item, so each presentation is a new identity, and `State(initialValue:)` runs fresh each time. If the editor lived in a split view's detail column instead, you'd add `.id(item.id)` for the same effect (lesson 5).
- **The sync points are explicit.** Save writes back through `onSave`; Cancel and swipe-down discard. `interactiveDismissDisabled(hasChanges)` stops a swipe from silently discarding edits.
- **Everything else is derived.** `hasChanges` and `canSave` are computed from `draft` and `original`.

## Preferences and restoration: @AppStorage and @SceneStorage

Two more places state can live, both with `@State`-like syntax.

**`@AppStorage`** reads and writes `UserDefaults` (Module 31). Apple's abstract: "A property wrapper type that reflects a value from `UserDefaults` and invalidates a view on a change in value in that user default." It works with `Bool`, `Int`, `Double`, `String`, `URL`, `Data`, and enums whose raw value is `Int` or `String`, per the initializers on Apple's page (a `Date` initializer is iOS 18 and later).

```swift ios
import SwiftUI

enum MeasurementUnits: String, CaseIterable, Identifiable {
    case metric, imperial
    var id: Self { self }
}

struct PreferencesView: View {
    @AppStorage("measurementUnits") private var units = MeasurementUnits.metric
    @AppStorage("showsTips") private var showsTips = true

    var body: some View {
        Form {
            Picker("Units", selection: $units) {
                ForEach(MeasurementUnits.allCases) { unit in
                    Text(unit.rawValue.capitalized).tag(unit)
                }
            }
            Toggle("Show tips", isOn: $showsTips)
        }
    }
}

struct RecipeQuantity: View {
    let grams: Int
    @AppStorage("measurementUnits") private var units = MeasurementUnits.metric

    var body: some View {
        Text(units == .metric ? "\(grams) g" : "\(grams * 100 / 2835) oz")
    }
}
```

Both views name the same key, so they read the same stored value; changing the picker updates every `RecipeQuantity`. The `= .metric` is only the default when nothing is stored yet. Keep the key strings in one place in a real app (a constant, or a small wrapper view or environment value) so a typo doesn't create a second preference. And keep `UserDefaults` for small, non-sensitive values: tokens and passwords go in the Keychain (Module 31).

**`@SceneStorage`** you've used already for navigation in Module 35. Apple: it "works very similar to `State`, except its initial value is restored by the system if it was previously saved", "Each `Scene` has its own notion of `SceneStorage`, so data is not shared between scenes", "Data of a large size, such as model data, should not be stored in `SceneStorage`", and "Do not use `SceneStorage` with sensitive data." Use it for UI restoration: the selected tab, a scroll anchor id, an encoded navigation path, a half-typed search query.

## Where each piece of state belongs

| The state is… | Put it in | Example |
| --- | --- | --- |
| Transient UI state used by one view | `@State private var` | Is a section expanded, the current text of a search field |
| Owned by a view and changed by a child | `@State` in the owner, `@Binding` in the child | A filter toggle in a child bar |
| A feature's data and logic, shared by several views | An `@Observable` class in `@State` at the feature's root | A library, a cart, a router |
| …that many views at different depths need | That model, injected with `.environment(_:)` and read with `@Environment(Type.self)` | A session, a favorites store |
| Context or a service for a subtree | A custom `@Entry` value (Sendable) | Theme, density, an analytics client |
| Data a view displays but doesn't own | A plain `let` parameter (or `@Bindable` if it needs bindings) | A row's book |
| Something computable from the above | Nothing: a computed property or an expression in `body` | Counts, totals, filtered lists, `canSave` |
| A small user preference that survives relaunch | `@AppStorage` | Units, "show tips" |
| UI state to restore per window | `@SceneStorage` | Selected tab, navigation path |
| An edit session's working copy | `@State` draft initialized from the original, in a view whose identity is the session | An edit sheet |
| User data that must persist | A persistence layer (Module 31; SwiftData in SwiftUI in Module 37) behind a model | Notes, contacts |

Two questions settle most cases: **who needs to read and write it** (that's the owner: the lowest view or model that covers all of them) and **how long must it live** (a view's identity, an edit session, a scene, the app's lifetime, forever).

## Common mistakes

> [!error] Storing what you can compute
> A `total`, `count` or `filteredItems` stored next to its source. Every code path that changes the source has to remember it. Make it a computed property.

> [!error] @State initialized from an input, by accident
> `_name = State(initialValue: user.name)` for a view that only displays the name. It never updates. Read `user.name` in `body`. If the view edits it, decide: a `@Binding`/`@Bindable` (edits go live) or a draft (edits wait for Save).

> [!error] A draft without a defined lifetime
> An editor whose draft lives in a long-lived view keeps the previous item's edits when the selection changes. Give each edit session its own identity: `sheet(item:)`, `navigationDestination`, or `.id(item.id)`.

> [!error] Sensitive or large data in AppStorage or SceneStorage
> `@AppStorage("authToken")` writes the token to a plain preferences file. Apple says not to use `SceneStorage` with sensitive data either, and not for "model data". Use the Keychain for secrets and real persistence for data.

> [!error] Two-way onChange synchronization
> Two pieces of state kept equal with an `onChange` on each. It works until an update order or an animation makes them disagree. Remove one and derive or bind.

## Exercises

````exercise
id: m36-l06-e1
type: prediction
prompt: "A model of two headers: one copies the contact's full name into state when it first appears, the other derives it on every body. The contact is renamed, then the same identity is given a different contact. What does it print?"
code: |
  final class StateStorage {
      private var values: [String: String] = [:]

      func value(at identity: String, initial: String) -> String {
          if let stored = values[identity] {
              return stored
          }
          values[identity] = initial
          return initial
      }
  }

  final class Contact {
      var firstName: String
      var lastName: String

      init(firstName: String, lastName: String) {
          self.firstName = firstName
          self.lastName = lastName
      }
  }

  // Copies the full name into "@State" when it first appears.
  struct CopyingHeader {
      let contact: Contact

      func body(_ storage: StateStorage) -> String {
          "copy: " + storage.value(at: "CopyingHeader", initial: "\(contact.firstName) \(contact.lastName)")
      }
  }

  // Derives the full name from the contact on every body.
  struct DerivingHeader {
      let contact: Contact

      var fullName: String { "\(contact.firstName) \(contact.lastName)" }

      func body() -> String {
          "derived: " + fullName
      }
  }

  let storage = StateStorage()
  let contact = Contact(firstName: "Ana", lastName: "Ruiz")
  print(CopyingHeader(contact: contact).body(storage), "|", DerivingHeader(contact: contact).body())
  contact.lastName = "López"
  print(CopyingHeader(contact: contact).body(storage), "|", DerivingHeader(contact: contact).body())
  let other = Contact(firstName: "Ben", lastName: "Ito")
  print(CopyingHeader(contact: other).body(storage), "|", DerivingHeader(contact: other).body())
output: |
  copy: Ana Ruiz | derived: Ana Ruiz
  copy: Ana Ruiz | derived: Ana López
  copy: Ana Ruiz | derived: Ben Ito
hints:
  - "The copying header stores a value only the first time its identity appears."
  - "The deriving header reads the contact it's given, every time."
solution: |
  ```output
  copy: Ana Ruiz | derived: Ana Ruiz
  copy: Ana Ruiz | derived: Ana López
  copy: Ana Ruiz | derived: Ben Ito
  ```

  The copying header stores "Ana Ruiz" on first appearance and returns it forever after: the rename doesn't reach it, and neither does the completely different contact passed to the same identity. The deriving header has nothing to go stale. In SwiftUI there's a second reason the copy is stale: its body reads its own state, not `contact.lastName`, so Observation doesn't even schedule an update when the name changes.
````

````exercise
id: m36-l06-e2
type: comprehension
prompt: "A workout app's timer screen shows elapsed time and has a Pause button; a summary screen pushed later shows the same workout's total time. The user can also pick, once, whether distances are shown in kilometers or miles, and that choice should survive relaunching the app. Which placement is right?"
choices:
  - text: "The workout (elapsed time, paused state) in an @Observable model owned by the flow's root and passed to both screens; the units choice in @AppStorage."
    correct: true
    why: "Two screens share the workout data, so it lives in a model above both. A small preference that survives relaunch is what AppStorage is for."
  - text: "Elapsed time in @State on the timer screen, copied into the summary screen's @State when it's pushed; units in @State on the root."
    correct: false
    why: "A copy goes stale if the workout keeps running, and @State on the root doesn't survive relaunch."
  - text: "Everything in @SceneStorage, so it's restored."
    correct: false
    why: "SceneStorage is for small per-window UI restoration, not model data, and a preference should be app-wide, not per scene."
  - text: "Elapsed time in @AppStorage so every screen can read it; units in the environment."
    correct: false
    why: "UserDefaults isn't a place for rapidly changing model data, and an environment value set at the root doesn't persist across launches by itself."
solution: |
  **A shared model plus `@AppStorage`.** The workout's data is read and changed by two screens, so it belongs in one `@Observable` model owned above both (the root of the workout flow, in `@State`) and passed down or put in the environment. The units choice is a small, app-wide preference that must survive relaunch: `@AppStorage("distanceUnits")`. You might also expose the units through an `@Entry` environment value set from that preference at the root, but the storage is `UserDefaults`.
````

````exercise
id: m36-l06-e3
type: design
prompt: "Design the state for a recipe screen. It shows a recipe (title, ingredients with quantities), a servings stepper that scales the quantities, a \"cook mode\" toggle that keeps the screen awake while it's on, a favorites heart shared with the favorites tab, and the user's units preference (metric or imperial). Ingredient quantities in the selected units must always match the servings. For each piece of state, say where it lives and why, and list what you will not store."
rubric:
  - Recipe passed in as a parameter (data the screen displays).
  - Servings as @State on the screen (view-local, transient), or in a per-screen model.
  - Scaled quantities and converted units derived, not stored.
  - Cook mode as @State on the screen (UI state for this screen's lifetime).
  - Favorites in a shared @Observable store owned near the root, read through the environment or passed in.
  - Units in @AppStorage (or an environment value backed by it).
solution: |
  A sound design:

  - **Recipe:** a `let recipe: Recipe` parameter. The screen shows it; something else loaded it.
  - **Servings:** `@State private var servings: Int`, starting from `recipe.baseServings`. It's this screen's UI state; a new visit can start from the default. (If it should be remembered per recipe, it moves into a model or `@SceneStorage`.)
  - **Cook mode:** `@State private var isCookMode = false`, used to turn the idle timer off while on. It only matters while this screen is visible.
  - **Favorite:** a `FavoritesStore`, `@Observable`, owned in `@State` at the app root and injected with `.environment(_:)`. The heart reads and toggles `favorites.contains(recipe.id)`; the favorites tab reads the same store.
  - **Units:** `@AppStorage("measurementUnits")` with a `String`-backed enum, read where quantities are formatted.

  **Not stored:** scaled quantities (`ingredient.amount * servings / recipe.baseServings`), unit conversions, the formatted strings and whether the recipe is a favorite. All are computed from the stored facts in the ingredient row's body or a helper, so they can't disagree with the stepper or the units setting.
````

````exercise
id: m36-l06-e4
type: find-errors
prompt: "Which of these are real problems?"
code: |
  import SwiftUI

  @Observable
  final class Cart {
      var items: [Int] = []          // prices in cents
      var total = 0

      func add(_ price: Int) {
          items.append(price)
          total += price
      }

      func removeAll() {
          items.removeAll()
      }
  }

  struct CartScreen: View {
      @State private var cart = Cart()
      @AppStorage("authToken") private var authToken = ""
      @SceneStorage("cartItems") private var savedItems = ""

      var body: some View {
          VStack {
              Text("Total: \(cart.total)")
              Text("\(cart.items.count) items")
              Button("Clear") { cart.removeAll() }
          }
      }
  }
choices:
  - text: "total is stored and removeAll() forgets to reset it; it should be computed from items."
    correct: true
    why: "Stored derived state with a forgotten update path: after Clear the screen shows 0 items and the old total."
  - text: "The auth token is stored with @AppStorage, which writes it to UserDefaults."
    correct: true
    why: "Secrets belong in the Keychain, not in preferences."
  - text: "The cart's contents are being saved in @SceneStorage, which Apple says isn't for model data."
    correct: true
    why: "SceneStorage is for small per-scene UI restoration. Persist cart data with a persistence layer."
  - text: "Text(\"\\(cart.items.count) items\") should be a stored itemCount property for performance."
    correct: false
    why: "count on an array is O(1). Storing it would add another value to keep in sync."
  - text: "CartScreen must use @Bindable to call cart.removeAll()."
    correct: false
    why: "Calling methods on the reference needs no binding."
rubric:
  - Flags the stored total with the missing reset.
  - Flags the token in AppStorage.
  - Flags model data in SceneStorage.
  - Doesn't recommend storing the item count or adding @Bindable.
solution: |
  Three real problems:

  1. **Stored `total`.** `removeAll()` empties `items` but leaves `total`. Replace it with `var total: Int { items.reduce(0, +) }`; then `add` is just an append.
  2. **`@AppStorage("authToken")`.** `UserDefaults` isn't protected storage. Keep tokens in the Keychain (Module 31, lesson 3; Module 42 goes further).
  3. **Cart contents in `@SceneStorage`.** Apple: data "such as model data, should not be stored in `SceneStorage`," and it disappears when the scene is destroyed. If the cart must persist, persist it properly; scene storage could hold, at most, which tab was open.

  The item count is cheap and already derived, and calling a method needs no binding.
````

````exercise
id: m36-l06-e5
type: solve
prompt: |
  Model an edit sheet's state in plain Swift. Write `struct Contact: Equatable` with `name` and `phone`, and `struct ContactEditor` with:

  - `let original: Contact` and `var draft: Contact`, both set from `init(contact:)`;
  - computed `hasChanges` (the draft differs from the original);
  - computed `canSave` (there are changes and the name isn't empty or only whitespace; use `allSatisfy(\.isWhitespace)`, no Foundation);
  - `func save() -> Contact?`, which returns the draft when it can be saved and `nil` otherwise.

  Then run:

  ```swift
  var editor = ContactEditor(contact: Contact(name: "Ana", phone: "555-0100"))
  print(editor.hasChanges, editor.canSave)
  editor.draft.name = "  "
  print(editor.hasChanges, editor.canSave)
  editor.draft.name = "Ana López"
  print(editor.hasChanges, editor.canSave)
  if let saved = editor.save() {
      print("saved:", saved.name, saved.phone)
  }
  editor.draft = editor.original
  print(editor.hasChanges, editor.canSave, editor.save() == nil)
  ```

  ```output
  false false
  true false
  true true
  saved: Ana López 555-0100
  false false true
  ```
starter: |
  struct Contact: Equatable {
      var name: String
      var phone: String
  }

  struct ContactEditor {
      // original, draft, init(contact:), hasChanges, canSave, save()
  }
hints:
  - "Only original and draft are stored. Everything else is a computed property."
  - "allSatisfy on an empty string returns true, so !name.allSatisfy(\\.isWhitespace) also rejects \"\"."
rubric:
  - Stores only original and draft.
  - hasChanges and canSave are computed, and canSave builds on hasChanges.
  - save() returns nil when canSave is false.
  - Output matches exactly.
solution: |
  ```swift
  struct Contact: Equatable {
      var name: String
      var phone: String
  }

  struct ContactEditor {
      let original: Contact
      var draft: Contact

      init(contact: Contact) {
          original = contact
          draft = contact
      }

      var hasChanges: Bool {
          draft != original
      }

      var canSave: Bool {
          hasChanges && !draft.name.allSatisfy(\.isWhitespace)
      }

      func save() -> Contact? {
          canSave ? draft : nil
      }
  }

  var editor = ContactEditor(contact: Contact(name: "Ana", phone: "555-0100"))
  print(editor.hasChanges, editor.canSave)
  editor.draft.name = "  "
  print(editor.hasChanges, editor.canSave)
  editor.draft.name = "Ana López"
  print(editor.hasChanges, editor.canSave)
  if let saved = editor.save() {
      print("saved:", saved.name, saved.phone)
  }
  editor.draft = editor.original
  print(editor.hasChanges, editor.canSave, editor.save() == nil)
  ```

  ```output
  false false
  true false
  true true
  saved: Ana López 555-0100
  false false true
  ```

  The editor stores the two facts that can't be computed: what the contact was and what the user has typed. Whether there are changes, whether saving is allowed and what gets saved are all questions asked of those two values, so they can't contradict each other. Setting the draft back to the original makes `hasChanges` false with no extra bookkeeping. This struct is exactly what the SwiftUI edit sheet's `@State` draft plus its computed properties do; it's also easy to unit-test without a view.
````

````exercise
id: m36-l06-e6
type: refactor
prompt: "This view keeps a filtered copy of the items in @State and updates it when the query changes. Refactor it so the filtered list is derived. Explain which bug disappears."
code: |
  import SwiftUI

  struct SearchableList: View {
      let items: [String]
      @State private var query = ""
      @State private var filtered: [String] = []

      var body: some View {
          List(filtered, id: \.self) { Text($0) }
              .searchable(text: $query)
              .onAppear { filtered = items }
              .onChange(of: query) {
                  filtered = query.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(query) }
              }
      }
  }
rubric:
  - Removes the filtered @State and the onAppear/onChange that maintain it.
  - Adds a computed property (or inline expression) that filters items by query.
  - Explains that the old version goes stale when items changes (the parent passes new items) because only query triggered refiltering.
  - Keeps query as @State.
solution: |
  ```swift ios
  import SwiftUI

  struct SearchableList: View {
      let items: [String]
      @State private var query = ""

      private var filtered: [String] {
          query.isEmpty ? items : items.filter { $0.localizedCaseInsensitiveContains(query) }
      }

      var body: some View {
          List(filtered, id: \.self) { Text($0) }
              .searchable(text: $query)
      }
  }
  ```

  The old version had two inputs, `items` and `query`, but refiltered only when `query` changed (and once on appear). If the parent passed new items, say after a refresh, the list kept showing the old filtered copy until the user typed. The computed property reads both inputs every time `body` runs, and `body` runs when either changes, so the list is always right. It's also shorter: two pieces of state and two modifiers whose only job was synchronization are gone.
````

## Summary

- Store facts; derive everything else. Counts, totals, filtered lists, validation and display strings belong in computed properties or `body`.
- `@State` initialized from an input is a copy that won't follow the input. Derive it, bind to it, or make it an explicit draft.
- A draft is a deliberate copy with three moments (start, save, cancel), a lifetime tied to an identity (a sheet, an `.id`), and derived `hasChanges`/`canSave`.
- `@AppStorage` keeps small, non-sensitive preferences in `UserDefaults`; `@SceneStorage` restores small per-window UI state. Neither holds model data or secrets.
- To place any state, ask who reads and writes it (that's the owner) and how long it must live. The table above maps the answers to `@State`, `@Binding`, an `@Observable` model, the environment, parameters, `@AppStorage` and `@SceneStorage`.
