---
id: m36-l05
title: View identity, lifetime and invalidation
description: "Three clocks run in every SwiftUI view: the view struct, created and discarded constantly; the view's identity, which decides how long its state, tasks and appear/disappear events last; and body evaluations, triggered by the dependencies body read. You learn exactly when @State is reset, use .id(_:) to reset it on purpose, tie work to lifetime with task(id:), and list what makes a body run again, separating what Apple documents from what the community has worked out."
module: m36
order: 5
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l04, m34-l05]
objectives:
  - Distinguish a view value's lifetime, a view's identity lifetime and a body evaluation.
  - List the situations that reset a view's @State and the ones that don't.
  - Reset a view's state on purpose with .id(_:) and know its costs.
  - Tie asynchronous work to a view's lifetime with task and task(id:).
  - List what makes SwiftUI evaluate a body again, and say which parts are documented.
terms:
  - term: View lifetime
    definition: "The span during which a view's identity stays in the hierarchy. @State, @StateObject, onAppear/onDisappear and task all follow it. It's unrelated to how long any particular view struct exists."
  - term: Invalidation
    definition: "SwiftUI marking a view as needing a new body evaluation because something it depends on changed: state it read, an observable property it read, an environment value it read, or new inputs from its parent."
  - term: "id(_:)"
    definition: "A modifier that binds a view's identity to a Hashable value. Apple: when the value changes, \"the identity of the view — for example, its state — is reset.\""
  - term: "task(id:)"
    definition: "A modifier that starts async work before the view appears, cancels it when the view disappears, and cancels and restarts it when the id value changes."
  - term: "_printChanges()"
    definition: "An underscored, undocumented SwiftUI debugging method. Called inside body, it logs what changed to cause that evaluation. Use it only while debugging."
mastery:
  - Predict, with the lifetime model, when an editor's draft is kept and when it's reset.
  - Add .id(item.id) so a detail editor starts fresh for each selected item, and name two side effects.
  - Replace onAppear plus a manual Task with task(id:) so work restarts when the selection changes.
  - Explain why an assignment of an equal value doesn't invalidate an @Observable reader but an in-place mutation does.
  - Use Self._printChanges() to find why a body ran.
resources: [swiftui-managing-ui-state, swiftui-foreach, observation, swift-task-cancellation-handler]
cards:
  - id: m36-l05-c1
    front: What resets a view's @State?
    back: "Anything that ends its identity: the view leaves the hierarchy (and comes back as a new one), moves to a different branch of an if or switch, its .id(_:) value changes, its ForEach element's id changes, or the type inside an AnyView changes. New inputs from the parent do not reset it."
  - id: m36-l05-c2
    front: What does .id(_:) cost when you use it to reset state?
    back: "Apple: changing identity resets all state the view holds (State, FocusState, GestureState and so on), and SwiftUI doesn't animate changes inside the view if its identity changes at the same time. It also recreates the whole subtree."
  - id: m36-l05-c3
    front: task vs task(id:)?
    back: "task runs before the view appears and is cancelled after it disappears (or its identity changes). task(id:) does the same and also cancels and restarts the work when the id value changes, compared with ==."
  - id: m36-l05-c4
    front: What makes a SwiftUI view's body run again?
    back: "Documented: a @State or binding value it depends on changes, an observable property its body read changes, an environment value it reads changes, or its parent re-creates it with new inputs. How SwiftUI compares old and new inputs isn't documented; EquatableView/.equatable() is the documented way to supply your own comparison."
  - id: m36-l05-c5
    front: Does assigning the same value to an @Observable property update views?
    back: "Since Swift 6.2, the macro-generated setter skips notifying when the type is Equatable and the new value equals the old one. In-place mutations (+=, append, toggle(), subscript writes) go through _modify and always notify."
---

## The idea in one sentence

**Identity decides how long state lives; dependencies decide when `body` runs**, and neither has anything to do with how often SwiftUI creates your view struct.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Documented behavior is quoted from Apple's pages for `id(_:)`, `StateObject`, `task`, `task(id:)`, `AnyView`, `EquatableView` and "Managing model data in your app", read in November 2026. Where this lesson describes behavior Apple doesn't document, it says so and labels it as a WWDC description or a community observation. The lifetime model and the Observation examples are plain Swift, compiled and run with Swift 6.3; the lifetime model shows documented rules, not SwiftUI's implementation.

## Three clocks

Module 34, lesson 1 introduced identity: SwiftUI matches each view in a new `body` result to the one already on screen by its position (structural identity) or by an explicit id. Lesson 3 there showed how `if`/`else` produces `_ConditionalContent`, two different positions, and lesson 5 showed why `ForEach` ids must be stable. Put those together with this module and you get three separate timelines for every view:

| Clock | Starts | Ends | What follows it |
| --- | --- | --- | --- |
| The view **value** (your struct) | Every time a parent's `body` runs and creates it | When SwiftUI is done with it (undocumented, and soon) | `init` and plain `let`/`var` properties: nothing that must persist |
| The view's **identity** (its lifetime) | When that identity first appears | When it leaves the hierarchy or changes | `@State`, `@StateObject`, `onAppear`/`onDisappear`, `task` |
| A **body evaluation** | When the view is invalidated | When `body` returns | Observation tracking for that evaluation |

Much of SwiftUI's surprising behavior comes from confusing two of these: initializing a model in `init` (value clock) and expecting it to persist (identity clock), or expecting `onAppear` to run when an input changes (it follows identity, not inputs).

## When @State is reset

State lives exactly as long as identity. So the question "will this reset my state?" is always "does this change the view's identity?"

**Resets state:**

- **The view leaves the hierarchy and comes back.** An `if showsEditor` that turns false and then true; a row removed from a `ForEach` and re-added; a pushed screen popped and pushed again; a sheet dismissed and presented again. The returning view is a new identity.
- **It moves to a different branch.** The `then` and `else` of an `if`, or two `case`s of a `switch`, are different positions, even when they contain the same view type.
- **Its explicit id changes.** `.id(value)` or the `id` of its `ForEach` element.
- **The type inside an `AnyView` changes.** Apple: "Whenever the type of view used with an `AnyView` changes, the old hierarchy is destroyed and a new hierarchy is created for the new type."

**Doesn't reset state:**

- **New inputs from the parent.** Apple's "Managing user interface state": when a parent's state changes, "SwiftUI detects the state change and recreates the `PlayerView` with a new input". Recreating the value isn't recreating the identity, so the child's `@State` stays, and its `@State` initial values are ignored (lesson 1).
- **Changing modifiers' values.** `.opacity(isFaded ? 0.3 : 1)` keeps one view with a changing value.

Lazy containers are a gray area. When the rows of a `List` or a lazy stack are created, and how long their state is kept while scrolled off screen, is up to SwiftUI and isn't documented in detail. Don't keep anything you can't afford to lose in row-level `@State`; keep it in the model the rows display.

### The draft that follows the wrong item

The case that bites in real apps: a detail editor that keeps a draft in `@State`, initialized from the selected item.

```swift ios
import SwiftUI

struct Item: Identifiable, Hashable {
    let id: Int
    var title: String
}

struct ItemEditor: View {
    let item: Item
    @State private var draft: String

    init(item: Item) {
        self.item = item
        _draft = State(initialValue: item.title)
    }

    var body: some View {
        Form {
            TextField("Title", text: $draft)
            Text("Editing item \(item.id)")
        }
    }
}

struct ShoppingSplitView: View {
    @State private var items = [Item(id: 1, title: "Milk"), Item(id: 2, title: "Eggs")]
    @State private var selection: Item.ID?

    var body: some View {
        NavigationSplitView {
            List(items, selection: $selection) { item in
                Text(item.title)
            }
        } detail: {
            if let selection, let item = items.first(where: { $0.id == selection }) {
                ItemEditor(item: item)
                    .id(item.id)          // a new editor, with a new draft, per item
            } else {
                Text("Select an item")
            }
        }
    }
}
```

Without `.id(item.id)`, selecting Eggs after typing "Oat milk" for Milk shows "Editing item 2" above a text field that still says "Oat milk": the editor kept its identity (same position in the detail column), so it kept its draft, and `State(initialValue:)` was ignored. With `.id(item.id)`, each item's editor is a different identity with its own state.

Here is that sequence in the lifetime model: identities map to stored drafts, a draft is created only for a new identity, and identities that leave lose theirs.

```swift
/// A model of identity-based lifetime, not SwiftUI's implementation.
struct EditorView {
    let title: String

    init(title: String) {
        self.title = title
        print("init EditorView(\(title))")
    }
}

final class Host {
    private var drafts: [String: String] = [:]   // each editor's @State draft, by identity

    func update(_ views: [(identity: String, view: EditorView)]) {
        let identities = views.map(\.identity)
        for identity in drafts.keys.sorted() where !identities.contains(identity) {
            print("onDisappear \(identity)")
            drafts[identity] = nil
        }
        for (identity, view) in views {
            if drafts[identity] == nil {
                drafts[identity] = view.title          // @State private var draft = title
                print("onAppear \(identity)")
            }
            print("body \(identity): draft = \(drafts[identity]!)")
        }
    }

    func type(_ text: String, at identity: String) {
        drafts[identity] = text
    }
}

print("[without .id]")
let plain = Host()
plain.update([("Detail/Editor", EditorView(title: "Milk"))])
plain.type("Oat milk", at: "Detail/Editor")
plain.update([("Detail/Editor", EditorView(title: "Eggs"))])

print("[with .id(item.id)]")
let keyed = Host()
keyed.update([("Detail/Editor#1", EditorView(title: "Milk"))])
keyed.type("Oat milk", at: "Detail/Editor#1")
keyed.update([("Detail/Editor#2", EditorView(title: "Eggs"))])
```

```output
[without .id]
init EditorView(Milk)
onAppear Detail/Editor
body Detail/Editor: draft = Milk
init EditorView(Eggs)
body Detail/Editor: draft = Oat milk
[with .id(item.id)]
init EditorView(Milk)
onAppear Detail/Editor#1
body Detail/Editor#1: draft = Milk
init EditorView(Eggs)
onDisappear Detail/Editor#1
onAppear Detail/Editor#2
body Detail/Editor#2: draft = Eggs
```

Notice `init EditorView(Eggs)` in both runs: the struct is always rebuilt with the new input. What differs is the identity. The model prints `onDisappear` before the new `onAppear`; that order is the model's, and Apple doesn't document the relative order of the two events.

### Costs of .id(_:)

Apple's `StateObject` page lists them under "Force reinitialization by changing view identity": "SwiftUI doesn't automatically animate changes inside the view if the view's identity changes at the same time. Also, changing the identity resets all state held by the view, including values that you manage as `State`, `FocusState`, `GestureState`, and so on." Scroll position, focus and text selection inside the subtree go too. That's usually right for "a different item"; it's wrong for "the same item, updated". If only one value should follow the input, update it instead of resetting everything:

```swift ios
import SwiftUI

struct Item: Identifiable, Hashable {
    let id: Int
    var title: String
}

struct ItemEditor: View {
    let item: Item
    @State private var draft = ""

    var body: some View {
        Form {
            TextField("Title", text: $draft)
        }
        .onChange(of: item.id, initial: true) {
            draft = item.title
        }
    }
}
```

`onChange(of:initial:_:)` (iOS 17) runs when `item.id` changes, and with `initial: true` also when the view first appears. The editor keeps its identity, so focus and other state survive. Which one to use is a design decision: `.id` when the whole subtree is about one item; `onChange` when only some state depends on the input.

## Work tied to lifetime: task and task(id:)

`init` and `body` follow the value clock and can run any number of times, so they're the wrong place to start work (Module 34, lesson 1). `task` follows identity. Apple: "Use this modifier to perform an asynchronous task with a lifetime that matches that of the modified view. If the task doesn't finish before SwiftUI removes the view or the view changes identity, SwiftUI cancels the task."

When the work depends on an input, use `task(id:)`. Apple: "If the `id` value changes, SwiftUI cancels and restarts the task."

```swift ios
import SwiftUI

struct ReviewsView: View {
    let productID: Int
    @State private var reviews: [String] = []

    var body: some View {
        List(reviews, id: \.self) { Text($0) }
            .task(id: productID) {
                reviews = []
                do {
                    try await Task.sleep(for: .milliseconds(300))   // stands in for a request
                    reviews = ["Great for product \(productID)"]
                } catch {
                    // Cancelled: the view went away or productID changed.
                }
            }
    }
}
```

With plain `.task`, changing `productID` without changing identity would keep showing the first product's reviews: the task already ran for this identity. With `.onAppear { Task { … } }`, you'd also have to cancel the old request yourself. `task(id:)` gives you both: one running load per value, cancelled when it's no longer needed. Cancellation is cooperative (Module 29): `Task.sleep` throws on cancellation; your own loops should check `Task.isCancelled`.

## What makes body run again

Here's what Apple documents, one source each:

1. **State it depends on changes.** `State`: "When the value changes, SwiftUI updates the parts of the view hierarchy that depend on the value." The same goes for a binding's source.
2. **An observable property it read changes.** "Managing model data": a view "forms a dependency on an observable data model object … when the view's `body` property reads a property of the object" (lesson 2).
3. **An environment value it reads changes.** `Environment`: "If the value changes, SwiftUI updates any parts of your view that depend on the value."
4. **Its parent recreates it with different inputs.** "Managing user interface state": SwiftUI "recreates the `PlayerView` with a new input."

What Apple **doesn't** document is how SwiftUI decides, in case 4, whether the new inputs differ from the old ones. Apple's WWDC 2021 session "Demystify SwiftUI" describes views as depending on their inputs and on dynamic properties like `@State`, and community write-ups describe a comparison of the view's stored properties, with closures often counting as "different". Treat those details as observations that can change between releases. The documented tool for taking control is `EquatableView`, or `.equatable()`, which Apple describes as preventing "the view from updating its child view when its new value is the same as its old value":

```swift ios
import SwiftUI

struct PriceTag: View, Equatable {
    let amountInCents: Int
    let onTap: () -> Void

    nonisolated static func == (lhs: PriceTag, rhs: PriceTag) -> Bool {
        lhs.amountInCents == rhs.amountInCents       // ignore the closure on purpose
    }

    var body: some View {
        Button("$\(amountInCents / 100).\(String(format: "%02d", amountInCents % 100))", action: onTap)
    }
}

struct CheckoutRow: View {
    let amountInCents: Int
    @State private var taps = 0

    var body: some View {
        VStack {
            PriceTag(amountInCents: amountInCents) { taps += 1 }
                .equatable()
            Text("Tapped \(taps) times")
        }
    }
}
```

Reach for this only after measuring (Module 39 covers Instruments). Most views are cheap, and a wrong `==` (one that ignores an input that matters) makes a view show stale data.

### Equal values and in-place mutations

Case 2 has a detail that comes from the `@Observable` macro rather than from SwiftUI. Since Swift 6.2, the setter the macro generates checks whether the new value equals the old one, for `Equatable` types, and skips the notification if so. In-place mutations go through a different accessor (`_modify`) that always notifies. This was confirmed by expanding the macro with Swift 6.3 and in the Swift 6.2 source; Swift 6.1's macro had no such check. Running it:

```swift
import Observation

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class Counter {
    var value = 0
    var tags: [String] = []
}

@available(macOS 14, iOS 17, *)
@MainActor
func watch(_ counter: Counter) {
    withObservationTracking {
        _ = counter.value
        _ = counter.tags
    } onChange: {
        print("  will change")
    }
}

if #available(macOS 14, iOS 17, *) {
    let counter = Counter()

    watch(counter)
    print("value = 0")
    counter.value = 0
    print("tags = []")
    counter.tags = []
    print("value += 0")
    counter.value += 0

    watch(counter)
    print("tags.append(\"new\")")
    counter.tags.append("new")

    watch(counter)
    print("value = 5")
    counter.value = 5
}
```

```output
value = 0
tags = []
value += 0
  will change
tags.append("new")
  will change
value = 5
  will change
```

- **`value = 0` and `tags = []`** assign values equal to the current ones: no notification, so a view reading them wouldn't update.
- **`value += 0`** changes nothing, but `+=` is an in-place mutation, and it notifies.
- **`append` and `value = 5`** really change the values and notify, as expected.

You rarely need to think about this. It matters when you profile a screen and find updates you didn't expect: `items[i] = items[i]`, `isOn.toggle()` twice, or `count += 0` all notify.

## Debugging: why did this body run?

SwiftUI has an underscored method, `_printChanges()`, that logs what changed before the current `body` evaluation. It isn't in Apple's reference documentation (Apple engineers showed it in WWDC sessions), so treat its output format as unstable and remove it before committing:

```swift ios
import SwiftUI

struct DebugCounter: View {
    @State private var count = 0

    var body: some View {
        let _ = Self._printChanges()
        Button("Count: \(count)") {
            count += 1
        }
    }
}
```

When a view updates more than you expect, the usual causes, in order: it reads more than it needs (a whole model object's properties for one label; split the view so each part reads less), its parent re-renders it with inputs that compare as different (closures, freshly built arrays), or it's inside a view whose identity keeps changing (`.id(UUID())`, computed ids).

## Common mistakes

> [!error] .id(UUID()) or any id computed in body
> A new id on every evaluation gives the view a new identity on every evaluation: its state resets, `task` restarts and `onAppear` fires each time. Use a stable value from your data.

> [!error] Expecting init or onAppear to see new inputs
> `onAppear` runs once per identity, not per input. Work that depends on an input belongs in `task(id: input)` or `onChange(of: input)`.

> [!error] Resetting state with if/else
> `if isEditing { Editor() } else { Editor() }` resets the editor every time `isEditing` flips, and SwiftUI can't animate between the branches. If you want a fresh editor, say so with `.id`; if not, keep one view and vary a value.

> [!error] Using .id(_:) to force a refresh
> Changing an id to "make the view update" throws away all its state and the subtree. A view that doesn't update usually has a dependency problem: it doesn't read the value (an ignored property, a copy in `@State`). Fix the dependency.

## Exercises

````exercise
id: m36-l05-e1
type: prediction
prompt: "The lifetime model with one keyed editor: the user edits it, the parent passes a new title, the editor is hidden, then shown again next to a second editor. What does it print?"
code: |
  struct EditorView {
      let title: String

      init(title: String) {
          self.title = title
          print("init EditorView(\(title))")
      }
  }

  final class Host {
      private var drafts: [String: String] = [:]   // each editor's @State draft, by identity

      func update(_ views: [(identity: String, view: EditorView)]) {
          let identities = views.map(\.identity)
          for identity in drafts.keys.sorted() where !identities.contains(identity) {
              print("onDisappear \(identity)")
              drafts[identity] = nil
          }
          for (identity, view) in views {
              if drafts[identity] == nil {
                  drafts[identity] = view.title          // @State private var draft = title
                  print("onAppear \(identity)")
              }
              print("body \(identity): draft = \(drafts[identity]!)")
          }
      }

      func type(_ text: String, at identity: String) {
          drafts[identity] = text
      }
  }

  let host = Host()
  host.update([("Editor#1", EditorView(title: "Milk"))])
  host.type("Oat milk", at: "Editor#1")
  host.update([("Editor#1", EditorView(title: "Milk (2 L)"))])
  host.update([])
  host.update([("Editor#1", EditorView(title: "Milk (2 L)")), ("Editor#2", EditorView(title: "Eggs"))])
output: |
  init EditorView(Milk)
  onAppear Editor#1
  body Editor#1: draft = Milk
  init EditorView(Milk (2 L))
  body Editor#1: draft = Oat milk
  onDisappear Editor#1
  init EditorView(Milk (2 L))
  init EditorView(Eggs)
  onAppear Editor#1
  body Editor#1: draft = Milk (2 L)
  onAppear Editor#2
  body Editor#2: draft = Eggs
hints:
  - "init runs on every update, whatever the identity does."
  - "Editor#1 keeps its identity when only the title input changes."
  - "After update([]) Editor#1 has no stored draft."
solution: |
  ```output
  init EditorView(Milk)
  onAppear Editor#1
  body Editor#1: draft = Milk
  init EditorView(Milk (2 L))
  body Editor#1: draft = Oat milk
  onDisappear Editor#1
  init EditorView(Milk (2 L))
  init EditorView(Eggs)
  onAppear Editor#1
  body Editor#1: draft = Milk (2 L)
  onAppear Editor#2
  body Editor#2: draft = Eggs
  ```

  - The first update creates `Editor#1` with draft "Milk"; the user changes it to "Oat milk".
  - The parent passes "Milk (2 L)". The struct is rebuilt (`init`), but the identity is the same, so the draft stays "Oat milk". That's `@State` ignoring a new initial value.
  - `update([])` removes the editor: its draft is dropped.
  - Showing it again creates a new identity with the same name: a fresh draft from the current input. `Editor#2` is new too.

  State follows identity. The only way the parent's new title reached the draft was by ending the old identity.
````

````exercise
id: m36-l05-e2
type: prediction
prompt: "Equal assignments and in-place mutations on an @Observable model (Swift 6.2 or later). What does it print?"
code: |
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Filters {
      var showsDone = true
      var query = "milk"
      var pinned = ["Home", "Work"]
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  func watch(_ filters: Filters, _ label: String) {
      withObservationTracking {
          _ = filters.showsDone
          _ = filters.query
          _ = filters.pinned
      } onChange: {
          print("\(label): will change")
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let filters = Filters()

      watch(filters, "A")
      filters.showsDone = true
      filters.query = "milk"
      filters.pinned = ["Home", "Work"]
      print("after equal assignments")

      filters.pinned[0] = "Home"
      print("after subscript write")

      watch(filters, "B")
      filters.query = "Milk"
      filters.showsDone.toggle()
      print("done")
  }
output: |
  after equal assignments
  A: will change
  after subscript write
  B: will change
  done
hints:
  - "A plain assignment of an equal Equatable value doesn't notify."
  - "A subscript write is an in-place mutation of pinned."
  - "Tracking is one-shot: B fires at most once."
solution: |
  ```output
  after equal assignments
  A: will change
  after subscript write
  B: will change
  done
  ```

  - The three assignments under A set values equal to the current ones, so A isn't notified.
  - `filters.pinned[0] = "Home"` writes through the array in place, which always notifies, even though the element didn't change.
  - Under B, `query = "Milk"` is a different string (capital M), so B fires. `toggle()` changes the value too, but B already fired; tracking is one-shot.
````

````exercise
id: m36-l05-e3
type: comprehension
multiple: true
prompt: "CounterView has @State private var count = 0. Which of these reset count to 0? Select all that apply."
choices:
  - text: "The parent's body runs again and creates CounterView(title: \"New title\")."
    correct: false
    why: "A new input on the same identity. The struct is rebuilt; its state is kept."
  - text: "The parent wraps it in if isCompact { CounterView() } else { CounterView() } and isCompact flips."
    correct: true
    why: "The two branches are different structural positions, so it's a different view."
  - text: "The parent applies .id(selectedDay) and selectedDay changes."
    correct: true
    why: "Apple: when the id value changes, the view's identity, including its state, is reset."
  - text: "The parent changes .opacity(isDimmed ? 0.5 : 1) on it."
    correct: false
    why: "A modifier's value changes; the view and its identity stay."
  - text: "The view is in a ForEach and its element is removed and inserted again with a new id."
    correct: true
    why: "The row's identity comes from the element's id; a new id is a new row."
solution: |
  **Branch change, id change, and a new ForEach id** reset it. Each ends the old identity and starts a new one, which starts from `count = 0`. A new input or a changed modifier value keeps the identity, so `count` survives. That's the rule: state lives exactly as long as identity.
````

````exercise
id: m36-l05-e4
type: find-errors
prompt: "A product screen. Which of these are real problems?"
code: |
  import SwiftUI

  struct ProductScreen: View {
      let productID: Int
      @State private var details = "Loading…"
      @State private var quantity = 1

      var body: some View {
          VStack {
              Text(details)
              Stepper("Quantity: \(quantity)", value: $quantity, in: 1...5)
              RecommendationsView(productID: productID)
                  .id(UUID())
          }
          .onAppear {
              Task { details = await loadDetails(for: productID) }
          }
      }
  }
choices:
  - text: ".id(UUID()) gives RecommendationsView a new identity on every body evaluation, so its state and tasks restart each time quantity changes."
    correct: true
    why: "A new id each evaluation is a new view each evaluation."
  - text: "onAppear runs once per identity, so when productID changes on the same screen the details stay for the old product."
    correct: true
    why: "Use .task(id: productID), which restarts the work when the id changes."
  - text: "The Task started in onAppear isn't cancelled when the view disappears."
    correct: true
    why: "An unstructured Task isn't tied to the view. .task cancels its work when the view disappears or its identity changes."
  - text: "quantity resets to 1 whenever productID changes."
    correct: false
    why: "Not with this code: the screen's identity doesn't depend on productID, so its state is kept. (Whether it should reset is a design question; .id(productID) on the screen would do it.)"
  - text: "Stepper can't bind to @State."
    correct: false
    why: "$quantity is an ordinary Binding<Int>."
rubric:
  - Flags .id(UUID()).
  - Flags onAppear for input-dependent work and recommends task(id:).
  - Flags the uncancelled unstructured Task.
  - Doesn't claim quantity resets.
solution: |
  Three real problems:

  1. **`.id(UUID())`** creates a new identity on every evaluation. Each tap on the stepper re-runs `body`, so `RecommendationsView` is destroyed and recreated: its state is lost and its loading starts over. Remove it, or use `.id(productID)` if recommendations should reset per product.
  2. **`onAppear` for work that depends on `productID`.** If the screen is reused for another product (same identity, new input), `onAppear` doesn't run again.
  3. **An unstructured `Task`** keeps running after the view goes away.

  Problems 2 and 3 share a fix:

  ```swift ios
  import SwiftUI

  func loadDetails(for productID: Int) async -> String {
      "Details for \(productID)"
  }

  struct ProductScreen: View {
      let productID: Int
      @State private var details = "Loading…"
      @State private var quantity = 1

      var body: some View {
          VStack {
              Text(details)
              Stepper("Quantity: \(quantity)", value: $quantity, in: 1...5)
          }
          .task(id: productID) {
              details = "Loading…"
              details = await loadDetails(for: productID)
          }
      }
  }
  ```

  `quantity` doesn't reset when `productID` changes, because the screen keeps its identity; add `.id(productID)` where the screen is used if it should.
````

````exercise
id: m36-l05-e5
type: solve
prompt: |
  A notes app shows the selected note in `NoteEditor`, which keeps an unsaved `draft` in `@State` and a `@FocusState` for the text editor. Selecting a different note must show that note's text, not the previous draft. Fix it in two ways and say which you'd ship:

  1. Reset the whole editor per note with `.id(_:)` at the call site.
  2. Keep the editor's identity and update only the draft with `onChange(of:initial:_:)`.
starter: |
  import SwiftUI

  struct Note: Identifiable {
      let id: Int
      var text: String
  }

  struct NoteEditor: View {
      let note: Note
      @State private var draft = ""
      @FocusState private var isFocused: Bool

      var body: some View {
          TextEditor(text: $draft)
              .focused($isFocused)
      }
  }

  struct NotesDetail: View {
      let selected: Note

      var body: some View {
          NoteEditor(note: selected)
      }
  }
hints:
  - "For version 1, the id should be the note's id, not the note's text."
  - "For version 2, initial: true covers the first appearance."
rubric:
  - Version 1 applies .id(selected.id) where NoteEditor is used and initializes the draft from the note.
  - "Version 2 uses onChange(of: note.id, initial: true) to set draft."
  - The answer names a trade-off (focus and other state reset with .id; onChange keeps them).
  - Both versions type-check.
solution: |
  Version 1, a new editor per note:

  ```swift ios
  import SwiftUI

  struct Note: Identifiable {
      let id: Int
      var text: String
  }

  struct NoteEditor: View {
      let note: Note
      @State private var draft: String
      @FocusState private var isFocused: Bool

      init(note: Note) {
          self.note = note
          _draft = State(initialValue: note.text)
      }

      var body: some View {
          TextEditor(text: $draft)
              .focused($isFocused)
      }
  }

  struct NotesDetail: View {
      let selected: Note

      var body: some View {
          NoteEditor(note: selected)
              .id(selected.id)
      }
  }
  ```

  Version 2, one editor that follows the selection:

  ```swift ios
  import SwiftUI

  struct Note: Identifiable {
      let id: Int
      var text: String
  }

  struct NoteEditor: View {
      let note: Note
      @State private var draft = ""
      @FocusState private var isFocused: Bool

      var body: some View {
          TextEditor(text: $draft)
              .focused($isFocused)
              .onChange(of: note.id, initial: true) {
                  draft = note.text
              }
      }
  }

  struct NotesDetail: View {
      let selected: Note

      var body: some View {
          NoteEditor(note: selected)
      }
  }
  ```

  Version 1 makes "one editor per note" structural: every piece of state, including focus, undo history and scroll position, starts fresh with each note, and the initializer finally means something because each identity sees it once. Version 2 keeps the editor alive, so focus survives switching notes, but you must remember to update every piece of per-note state in the `onChange`. For a notes app where each note is a separate document, version 1 is the safer default; version 2 suits a case where focus continuity matters. Neither saves the draft, which you'd handle before switching (lesson 6 discusses drafts).
````

````exercise
id: m36-l05-e6
type: explain
prompt: "A teammate added let _ = Self._printChanges() to a row view and sees it logs on every keystroke in a search field elsewhere on the screen, though the row doesn't show the query. Explain what to look for and how you'd fix the likely cause without .equatable()."
code: |
  struct SearchScreen: View {
      @State private var query = ""
      let model: CatalogModel

      var body: some View {
          VStack {
              TextField("Search", text: $query)
              ForEach(model.products) { product in
                  ProductRow(product: product, onFavorite: { model.toggleFavorite(product) })
              }
          }
      }
  }
rubric:
  - Notes that SearchScreen's body re-runs on every keystroke because it reads query.
  - Notes that each run re-creates every ProductRow, including a new closure, which can make SwiftUI treat the inputs as changed (an observation, not documented).
  - Suggests moving the TextField and its state into a smaller subview, or moving the list into its own view that doesn't read query, so typing doesn't re-run the list's parent.
  - Mentions _printChanges is undocumented and for debugging only.
solution: |
  `SearchScreen` reads `query` (through `$query` and the text field), so every keystroke invalidates it and its `body` runs again. That body re-creates every `ProductRow` with a new `onFavorite` closure. How SwiftUI compares a row's old and new inputs isn't documented; the common observation is that closures can't be compared, so the row is treated as changed and its body runs. `_printChanges()`, an undocumented debugging aid, is telling you it happened.

  The fix is structural: make the view that reads `query` not be the parent of the rows. Move the list into its own `ProductList(model:)` view whose body never reads `query`, or move the search field and its `@State` into a `SearchField` subview. Then typing invalidates only the small view that owns the query. Remove `_printChanges()` once you're done.
````

## Summary

- Three clocks: the view value (rebuilt constantly), the identity (state, `task`, appear and disappear), and body evaluations (driven by dependencies).
- `@State` resets when identity ends: leaving the hierarchy, a different `if`/`switch` branch, a changed `.id` or `ForEach` id, a new type inside `AnyView`. New inputs don't reset it.
- `.id(_:)` resets everything in the subtree on purpose and disables animation across the change. `onChange(of:initial:_:)` updates only what you choose.
- `task` follows identity and cancels on disappearance; `task(id:)` also restarts when the value changes.
- Documented reasons for a new body: state, observable properties it read, environment values it read, new inputs. How inputs are compared isn't documented; `.equatable()` is the documented override.
- With the Swift 6.2+ `@Observable` macro, assigning an equal value doesn't notify; in-place mutations always do.
