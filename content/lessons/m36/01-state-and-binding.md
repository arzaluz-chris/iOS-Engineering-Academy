---
id: m36-l01
title: "@State and @Binding"
description: "Every value that changes on screen needs exactly one owner. @State makes a view the owner of a small value-type piece of state; @Binding lets a child read and write a value someone else owns. You see why @State is private, how its initial value really works, how to project bindings into struct properties, how to build a binding with Binding(get:set:), and what constant bindings are for."
module: m36
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l06]
objectives:
  - Say which view is the source of truth for a value and give it @State there.
  - Explain why @State should be private and why its initial value is used only once per view lifetime.
  - Pass a binding to a child with $, and declare @Binding in the child.
  - Get a binding to one property of a struct held in @State.
  - Build a derived binding with Binding(get:set:) and use Binding.constant(_:) for previews.
terms:
  - term: Source of truth
    definition: "The one place a value is stored. Every view that shows or changes the value reads and writes that place, directly or through a binding, instead of keeping its own copy."
  - term: "@State"
    definition: "A SwiftUI property wrapper (iOS 13) for a value that a view owns. SwiftUI stores the value outside the view struct, keeps it for as long as the view's identity lasts, and updates the parts of the view that depend on it when it changes."
  - term: "@Binding"
    definition: "A SwiftUI property wrapper for a value the view reads and writes but doesn't own. A Binding has no storage of its own; it refers to a source of truth somewhere else."
  - term: Projected value
    definition: "What the $ prefix gives you on a property wrapper. For @State and @Binding it's a Binding<Value> to the same storage."
  - term: "Binding.constant(_:)"
    definition: "A binding to a fixed value. Writes are ignored. Useful in previews and for controls that should display a value without changing it."
mastery:
  - Move a Bool from a child view's @State to its parent and pass it down as a binding.
  - Explain, with the storage model, why a parent passing a new initial value to a child's @State has no effect after the first appearance.
  - Write $draft.title to bind a text field to one property of a struct in @State.
  - Write a Binding<Bool> that reports and changes whether a set contains an element.
  - Use .constant(true) to preview a view that takes a binding.
resources: [swiftui-state, swiftui-binding, swiftui-managing-ui-state, swiftui-declaring-custom-view, swiftui-previews, swift-book-properties, swift-book-structures-classes]
cards:
  - id: m36-l01-c1
    front: What does @State do, and who should own it?
    back: "It asks SwiftUI to store a value for the view outside the struct and to update the view when it changes. Apple: declare it private \"in the highest view in the view hierarchy that needs access to the value\", then pass it down as a plain value (read-only) or a binding (read-write)."
  - id: m36-l01-c2
    front: Why should @State be private?
    back: "Apple: to prevent setting it in a memberwise initializer, which \"can conflict with the storage management that SwiftUI provides\". The initial value is only used the first time the view appears; after that SwiftUI's stored value wins, so a parent passing a new value would silently do nothing."
  - id: m36-l01-c3
    front: "@State vs @Binding in one line each?"
    back: "@State: this view owns the value and SwiftUI stores it. @Binding: this view reads and writes a value that someone else owns; the binding has no storage of its own."
  - id: m36-l01-c4
    front: How do you get a binding to one field of a struct held in @State?
    back: "Chain the property after the $: $draft.title is a Binding<String> to draft.title. Binding supports dynamic member lookup, so each property of the value becomes a binding to that property."
  - id: m36-l01-c5
    front: What are Binding(get:set:) and Binding.constant(_:) for?
    back: "Binding(get:set:) builds a binding from two closures, for a value that's derived from other state (for example, whether a set contains an element). Binding.constant(_:) wraps a fixed value and ignores writes, which is handy in previews."
---

## The idea in one sentence

Each value that can change on screen has **one owner**; the owner declares it `@State`, and any child that needs to change it gets a `@Binding` to the owner's storage instead of a copy of its own.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. SwiftUI's behavior is quoted from Apple's pages for `State`, `Binding` and "Managing user interface state", read in November 2026. The storage and binding models are plain Swift, compiled and run with Swift 6.3; they're models built to show the rules, not SwiftUI's implementation.

## Where you are

Module 34 used `@State` without much explanation ("SwiftUI stores it outside the struct") and lesson 4 there modeled a binding as a get/set pair passed to a control. This lesson is about your own views: who owns a value, how a child gets write access, and what goes wrong when two views each think they own it.

## @State: a value the view owns

Apple's `State` page: "Use state as the single source of truth for a given value type that you store in a view hierarchy." Three parts of that sentence matter.

- **Source of truth.** The value lives in exactly one place. Nobody else keeps a copy that has to be synchronized.
- **Value type.** `Bool`, `String`, `Int`, an enum, an array, a small struct. `@State` can also hold an `@Observable` object, which is lesson 2.
- **Stored in a view hierarchy.** The value belongs to one view and lives as long as that view's identity does (Module 34, lesson 1). Apple's "Managing user interface state" spells out what that means: "Don't use state properties for persistent storage because the life cycle of state variables mirrors the view life cycle." Good uses are transient UI state: "the highlight state of a button, filter settings, or the currently selected list item."

```swift ios
import SwiftUI

struct TaskRow: View {
    let title: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading) {
            Button(title) {
                isExpanded.toggle()
            }
            if isExpanded {
                Text("Due tomorrow. Tap again to collapse.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- `let title` is an **input**. The parent passes it and can pass a different one next time.
- `@State private var isExpanded = false` is **state**. Only this row reads or changes it, so the row owns it.
- `isExpanded.toggle()` writes the state. Apple: "When the value changes, SwiftUI updates the parts of the view hierarchy that depend on the value."

### Why private, and what the initial value really does

Apple, on the same page: "Declare state as private to prevent setting it in a memberwise initializer, which can conflict with the storage management that SwiftUI provides." To see the conflict, you need one fact about the initial value: the `= false` only takes effect **the first time** a view with that identity appears. After that, SwiftUI hands the view its stored value, whatever the struct's initializer said.

Here's that rule as a plain-Swift model. A dictionary keyed by identity plays the role of SwiftUI's storage; `value(at:initial:)` uses the initial value only when nothing is stored yet:

```swift
/// A model of how SwiftUI keeps @State values, not its implementation.
final class StateStorage {
    private var values: [String: Int] = [:]

    func value(at identity: String, initial: Int) -> Int {
        if let stored = values[identity] {
            return stored
        }
        values[identity] = initial
        return initial
    }

    func set(_ value: Int, at identity: String) {
        values[identity] = value
    }
}

// Like `@State var count: Int` with no `private`, so the parent can pass a start value.
struct CounterView {
    let start: Int

    func body(_ storage: StateStorage) -> String {
        "count: \(storage.value(at: "Root/Counter", initial: start))"
    }
}

let storage = StateStorage()
print(CounterView(start: 0).body(storage))
storage.set(3, at: "Root/Counter")              // the user taps three times
print(CounterView(start: 10).body(storage))     // the parent re-renders with start 10
print(CounterView(start: 10).body(storage))
```

```output
count: 0
count: 3
count: 3
```

The parent re-created `CounterView` with `start: 10`, and nothing happened. That's the behavior Apple warns about. If `count` weren't private, `CounterView(count: 10)` would compile, look like it sets the count, and be ignored after the first appearance. Making it `private` also makes the memberwise initializer private, so a parent in another file can't call it, and the only way to change the count from outside is a binding, which actually writes the stored value.

If a child really does need a starting value from its parent, either make it a plain `let` input (if the child never changes it) or move the state up to the parent and pass a binding. Lesson 5 covers the third option, resetting state on purpose with `.id(_:)`.

> [!version] Xcode 27
> Apple's `State` page says "When you build with Xcode 27 or later, the system uses the `State()` macro instead" of the property wrapper. You still write `@State private var`. This course's iOS blocks are checked with Xcode 26.6, where `@State` is the property wrapper. Lesson 2 points out the one documented difference that matters day to day.

## @Binding: write access to someone else's value

Suppose the expanded state has to be controlled from outside: an "Expand all" button in the parent, say. Then the row can't own it any more. Apple's advice is to move the state up: "Declare state as private in the highest view in the view hierarchy that needs access to the value. Then share the state with any subviews that also need access, either directly for read-only access, or as a binding for read-write access."

```swift ios
import SwiftUI

struct FilterBar: View {
    @Binding var showsCompleted: Bool

    var body: some View {
        Toggle("Show completed", isOn: $showsCompleted)
    }
}

struct TaskListScreen: View {
    @State private var showsCompleted = false
    let tasks: [(title: String, isDone: Bool)]

    var body: some View {
        VStack {
            FilterBar(showsCompleted: $showsCompleted)
            ForEach(visibleTitles, id: \.self) { title in
                Text(title)
            }
            Button("Reset filters") {
                showsCompleted = false
            }
        }
    }

    private var visibleTitles: [String] {
        tasks.filter { showsCompleted || !$0.isDone }.map(\.title)
    }
}
```

Line by line:

- **`@Binding var showsCompleted: Bool`** in `FilterBar`. No initial value, no `private`: the parent must pass it. Inside the child you read and write `showsCompleted` like any property.
- **`$showsCompleted`** inside `FilterBar` passes the binding on to the `Toggle`. Apple: "you can get a binding from a binding using the `$` prefix, allowing you to pass a binding through an arbitrary number of levels of view hierarchy."
- **`FilterBar(showsCompleted: $showsCompleted)`** in the parent. `$` on a `@State` property gives its projected value, a `Binding<Bool>` to the state's storage.
- **`Button("Reset filters")`** writes the same storage. The toggle shows the new value on the next update because it never had its own copy.
- **`visibleTitles`** is computed from the state every time `body` runs. Nothing stores the filtered list, so nothing can get out of date. Lesson 6 makes this a rule.

Apple's "Managing user interface state" says what a binding is in one sentence: "unlike a state property, the binding doesn't have its own storage. Instead, it references a state property stored somewhere else, and provides a two-way connection to that storage."

### Read-only children don't need a binding

If a child only displays the value, pass it as a plain property. Apple: "If you pass a state property to a subview, SwiftUI updates the subview any time the value changes in the container view, but the subview can't modify the value." A badge that shows the number of completed tasks takes `let count: Int`, not `@Binding var count: Int`. A binding in a view that never writes it is misleading: it says "I might change this" when it won't.

## Bindings into a struct's properties

When the state is a struct, you often want a control bound to one field. `Binding` supports dynamic member lookup, so `$draft.title` is a `Binding<String>` to `draft.title`:

```swift ios
import SwiftUI

struct TaskDraft {
    var title = ""
    var notes = ""
    var isUrgent = false
}

struct NewTaskForm: View {
    @State private var draft = TaskDraft()

    var body: some View {
        Form {
            TextField("Title", text: $draft.title)
            TextField("Notes", text: $draft.notes, axis: .vertical)
            Toggle("Urgent", isOn: $draft.isUrgent)
            Text(draft.title.isEmpty ? "Untitled" : draft.title)
        }
    }
}
```

One `@State` for the whole draft, three bindings into it. Typing in the title field writes `draft.title`, which is a write to `draft`, so the preview text updates.

How does `$draft.title` work? The model from Module 34, lesson 4, with one addition: a dynamic-member subscript that turns a key path into a binding to that member.

```swift
final class Storage<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

@dynamicMemberLookup
struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void

    var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }

    subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Binding<Member> {
        Binding<Member>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

struct TaskDraft {
    var title = ""
    var isUrgent = false
}

let draftStorage = Storage(TaskDraft())
let draft = Binding(get: { draftStorage.value }, set: { draftStorage.value = $0 })

let title = draft.title          // like $draft.title
let isUrgent = draft.isUrgent    // like $draft.isUrgent

title.wrappedValue = "Pay rent"
isUrgent.wrappedValue = true
print(draftStorage.value.title, draftStorage.value.isUrgent)
```

```output
Pay rent true
```

`draft.title` reads the whole draft, takes its `title`, and on write reads the whole draft, changes `title`, and writes the whole draft back. Both child bindings end at the same storage. SwiftUI's real `Binding` does more (it carries transactions and animations, and its closures are `@Sendable`), but the shape is the same.

## Binding(get:set:): a binding to a derived value

Sometimes the value a control needs isn't stored anywhere. A list of tag toggles needs a `Bool` per tag, but the state is a `Set<String>` of selected tags. `Binding(get:set:)` builds the `Bool` from two closures. Apple's current reference page declares it like this:

```swift illustrative
@preconcurrency init(get: @escaping @isolated(any) @Sendable () -> Value,
                     set: @escaping @isolated(any) @Sendable (Value) -> Void)
```

The closures are `@Sendable`, so they should capture only Sendable things. A clean way to satisfy that is an extension on `Binding` itself: the closures capture the outer binding (Apple: "A binding conforms to `Sendable` only if its wrapped value type also conforms to `Sendable`", and `Set<String>` does) and the element.

```swift ios
import SwiftUI

extension Binding {
    func contains<Element: Hashable & Sendable>(_ element: Element) -> Binding<Bool>
    where Value == Set<Element> {
        Binding<Bool>(
            get: { self.wrappedValue.contains(element) },
            set: { isOn in
                if isOn {
                    self.wrappedValue.insert(element)
                } else {
                    self.wrappedValue.remove(element)
                }
            }
        )
    }
}

struct TagPicker: View {
    let allTags = ["Home", "Work", "Errands"]
    @State private var selectedTags: Set<String> = ["Work"]

    var body: some View {
        Form {
            ForEach(allTags, id: \.self) { tag in
                Toggle(tag, isOn: $selectedTags.contains(tag))
            }
            Text("\(selectedTags.count) selected")
        }
    }
}
```

- **`get`** answers "is this tag in the set?", computed from the source of truth every time.
- **`set`** turns the toggle's new `Bool` into an insert or a remove on the set.
- **`$selectedTags.contains(tag)`** reads well at the call site, and there's still one source of truth: the set.

Use `Binding(get:set:)` for a real derivation like this, and for small adaptations (a `Bool` for "this optional isn't nil", a `Double` for a slider over an `Int`). Don't use it to wrap a plain stored property; `$property` already does that.

## Constant bindings in previews

A view that takes `@Binding` needs a binding to be created, including in a preview. `Binding.constant(_:)` gives one with a fixed value. Apple: "Use this method to create a binding to a value that cannot change. This can be useful when using a `PreviewProvider` to see how a view represents different values."

```swift illustrative
#Preview("Completed shown") {
    FilterBar(showsCompleted: .constant(true))
}

#Preview("Interactive") {
    @Previewable @State var showsCompleted = false
    FilterBar(showsCompleted: $showsCompleted)
}
```

The first preview always shows the toggle on; tapping it does nothing, because writes to a constant binding are ignored. When you want to try the interaction in the canvas, `@Previewable` (iOS 17 and later, per Apple's page) lets you declare real `@State` inside `#Preview` and pass its binding. The block is illustrative because the course's iOS check doesn't compile `#Preview`. The same constant works outside previews, too:

```swift ios
import SwiftUI

struct FilterBar: View {
    @Binding var showsCompleted: Bool

    var body: some View {
        Toggle("Show completed", isOn: $showsCompleted)
    }
}

struct FilterBarGallery: View {
    var body: some View {
        VStack {
            FilterBar(showsCompleted: .constant(false))
            FilterBar(showsCompleted: .constant(true))
        }
    }
}
```

## Common mistakes

> [!error] Two sources of truth
> The parent has `@State private var showsCompleted`, and the child has its own `@State private var showsCompleted` that it initializes from a parameter. They start equal and drift apart as soon as either one changes: the parent's "Reset filters" no longer moves the toggle. Delete the child's state and take a `@Binding`.

> [!error] error: cannot use mutating member on immutable value: 'isOn' is a 'let' constant
> A child declared `let isOn: Bool` and tried to toggle it. A plain property is a read-only input. If the child must change the value, declare `@Binding var isOn: Bool` and have the parent pass `$isOn`. The same error in a plain-Swift model, from Swift 6.3:

```swift no-compile cannot use mutating member on immutable value: 'isOn' is a 'let' constant
struct ToggleRow {
    let isOn: Bool

    func tap() {
        isOn.toggle()
    }
}
```

> [!error] A non-private @State that the parent "sets"
> `@State var count = 0` without `private` lets a parent write `CounterView(count: 5)`. It compiles, works on first appearance, and is then ignored, as the storage model showed. Keep `@State` private; take a `let` input or a `@Binding` instead.

> [!error] Passing the value where a binding is expected
> `FilterBar(showsCompleted: showsCompleted)` without the `$` is a type error: the initializer wants a `Binding<Bool>`, and you passed a `Bool`. Add the `$`. The opposite mistake, a `@Binding` in a view that only reads it, compiles fine and is just misleading.

> [!error] Storing persistent data in @State
> A user's saved tasks in `@State` disappear when the view goes away, and all of them when the app quits. State is for UI state with the view's lifetime. Model data goes in a model (lesson 2), settings in `@AppStorage`, and anything bigger in persistence (Module 31, and SwiftData in SwiftUI in Module 37).

## Exercises

````exercise
id: m36-l01-e1
type: prediction
prompt: "The @State storage model, with two counters at different identities and a parent that keeps passing new start values. What does it print?"
code: |
  final class StateStorage {
      private var values: [String: Int] = [:]

      func value(at identity: String, initial: Int) -> Int {
          if let stored = values[identity] {
              return stored
          }
          values[identity] = initial
          return initial
      }

      func set(_ value: Int, at identity: String) {
          values[identity] = value
      }
  }

  struct CounterView {
      let identity: String
      let start: Int

      func body(_ storage: StateStorage) -> String {
          "\(identity)=\(storage.value(at: identity, initial: start))"
      }
  }

  let storage = StateStorage()
  print(CounterView(identity: "A", start: 1).body(storage), CounterView(identity: "B", start: 2).body(storage))
  storage.set(7, at: "A")
  print(CounterView(identity: "A", start: 100).body(storage), CounterView(identity: "B", start: 200).body(storage))
  print(CounterView(identity: "C", start: 300).body(storage))
output: |
  A=1 B=2
  A=7 B=2
  C=300
hints:
  - "The start value is only used when nothing is stored for that identity yet."
  - "C has never appeared before."
solution: |
  ```output
  A=1 B=2
  A=7 B=2
  C=300
  ```

  On first appearance each identity stores its start value: A gets 1, B gets 2. Then A's stored value is set to 7, like three taps. On the second render the parent passes 100 and 200, but both identities already have stored values, so A shows 7 and B keeps 2. C is a new identity, so its start value, 300, is used. That's why passing a start value into `@State` is misleading, and why Apple says to make it private.
````

````exercise
id: m36-l01-e2
type: comprehension
prompt: "A settings screen has a \"Notifications\" toggle in a child view, NotificationRow. The parent screen also shows a summary line, \"Notifications: on\", and has a \"Restore defaults\" button that turns notifications off. Where should the Bool live?"
choices:
  - text: "In the parent, as @State private var; NotificationRow takes @Binding var isOn: Bool."
    correct: true
    why: "The parent reads it (summary) and writes it (restore), and the child writes it (toggle). The highest view that needs it owns it, and the child gets write access through a binding."
  - text: "In NotificationRow as @State private var, and the parent reads it from the row."
    correct: false
    why: "A parent can't reach into a child's @State. There's no reference to the row and no way to read its storage."
  - text: "In both, as @State in each, kept in sync with onChange."
    correct: false
    why: "Two sources of truth. Synchronizing them by hand is the stale-copy bug that bindings exist to avoid."
  - text: "In NotificationRow as @Binding, with an initial value of false."
    correct: false
    why: "A @Binding has no storage, so it has no initial value. Someone has to own the Bool and pass a binding to it."
solution: |
  **The parent owns it.** Three places touch the value: the summary (reads), the restore button (writes) and the toggle (writes). The lowest view that contains all three is the parent, so `@State private var notificationsOn = true` goes there, and `NotificationRow(isOn: $notificationsOn)` passes a binding. The summary just reads `notificationsOn`.
````

````exercise
id: m36-l01-e3
type: fill-in
prompt: "Complete the child and the call site so the stepper changes the parent's quantity."
code: |
  import SwiftUI

  struct QuantityStepper: View {
      [[1]] var quantity: Int

      var body: some View {
          Stepper("Quantity: \(quantity)", value: [[2]], in: 1...10)
      }
  }

  struct CartLine: View {
      @State [[3]] var quantity = 1

      var body: some View {
          QuantityStepper(quantity: [[4]])
      }
  }
blanks:
  - id: "1"
    answers: ["@Binding"]
  - id: "2"
    answers: ["$quantity"]
  - id: "3"
    answers: ["private"]
  - id: "4"
    answers: ["$quantity"]
hints:
  - "The child doesn't own the quantity."
  - "Both the Stepper and the child need a Binding<Int>, which you get from $."
solution: |
  ```swift ios
  import SwiftUI

  struct QuantityStepper: View {
      @Binding var quantity: Int

      var body: some View {
          Stepper("Quantity: \(quantity)", value: $quantity, in: 1...10)
      }
  }

  struct CartLine: View {
      @State private var quantity = 1

      var body: some View {
          QuantityStepper(quantity: $quantity)
      }
  }
  ```

  `CartLine` owns the quantity, privately. It passes `$quantity`, a `Binding<Int>`, to the child. The child declares `@Binding` and passes its own `$quantity` on to `Stepper`, which is a binding derived from a binding, ending at the same storage.
````

````exercise
id: m36-l01-e4
type: solve
prompt: |
  Using the plain-Swift `Storage` and `Binding` model from the lesson (copy it), add a method to `Binding` for an optional value: `isPresent(default:)` returns a `Binding<Bool>` that reads `true` when the value isn't `nil`. Writing `false` sets the value to `nil`; writing `true` when it's `nil` sets it to `default`, and when it already has a value leaves it alone. This is the shape SwiftUI code uses to drive a sheet from an optional.

  Test it with this code:

  ```swift
  let selection = Storage<String?>(nil)
  let binding = Binding(get: { selection.value }, set: { selection.value = $0 })
  let isShowing = binding.isPresent(default: "New task")
  print(isShowing.wrappedValue, selection.value ?? "nil")
  isShowing.wrappedValue = true
  print(isShowing.wrappedValue, selection.value ?? "nil")
  selection.value = "Pay rent"
  isShowing.wrappedValue = true
  print(isShowing.wrappedValue, selection.value ?? "nil")
  isShowing.wrappedValue = false
  print(isShowing.wrappedValue, selection.value ?? "nil")
  ```

  Expected output:

  ```output
  false nil
  true New task
  true Pay rent
  false nil
  ```
starter: |
  final class Storage<Value> {
      var value: Value
      init(_ value: Value) { self.value = value }
  }

  struct Binding<Value> {
      let get: () -> Value
      let set: (Value) -> Void

      var wrappedValue: Value {
          get { get() }
          nonmutating set { set(newValue) }
      }
  }

  // Add isPresent(default:) for Binding where Value is an optional.
hints:
  - "Constrain an extension with a generic method: func isPresent<Wrapped>(default: Wrapped) -> Binding<Bool> where Value == Wrapped?"
  - "get compares the wrapped value to nil. set checks the new Bool and the current value."
rubric:
  - The extension or method is constrained so it only exists for optional values.
  - get is computed from the underlying value every time (nothing is cached).
  - Writing false sets nil; writing true sets the default only when the value is nil.
  - The printed output matches exactly.
solution: |
  ```swift
  final class Storage<Value> {
      var value: Value
      init(_ value: Value) { self.value = value }
  }

  struct Binding<Value> {
      let get: () -> Value
      let set: (Value) -> Void

      var wrappedValue: Value {
          get { get() }
          nonmutating set { set(newValue) }
      }
  }

  extension Binding {
      func isPresent<Wrapped>(default defaultValue: Wrapped) -> Binding<Bool> where Value == Wrapped? {
          Binding<Bool>(
              get: { self.wrappedValue != nil },
              set: { isOn in
                  if !isOn {
                      self.wrappedValue = nil
                  } else if self.wrappedValue == nil {
                      self.wrappedValue = defaultValue
                  }
              }
          )
      }
  }

  let selection = Storage<String?>(nil)
  let binding = Binding(get: { selection.value }, set: { selection.value = $0 })
  let isShowing = binding.isPresent(default: "New task")
  print(isShowing.wrappedValue, selection.value ?? "nil")
  isShowing.wrappedValue = true
  print(isShowing.wrappedValue, selection.value ?? "nil")
  selection.value = "Pay rent"
  isShowing.wrappedValue = true
  print(isShowing.wrappedValue, selection.value ?? "nil")
  isShowing.wrappedValue = false
  print(isShowing.wrappedValue, selection.value ?? "nil")
  ```

  ```output
  false nil
  true New task
  true Pay rent
  false nil
  ```

  The `Bool` isn't stored anywhere; it's derived from the optional on every read, so it can't disagree with it. The setter translates the `Bool` back into a change to the one source of truth. `where Value == Wrapped?` keeps the method from appearing on bindings to non-optional values. SwiftUI's own `sheet(item:)` takes the optional binding directly; you'd write a `Bool` adapter like this for APIs that only take `isPresented:`.
````

````exercise
id: m36-l01-e5
type: find-errors
prompt: "A profile editor and its parent. Which of these are real problems?"
code: |
  import SwiftUI

  struct ProfileEditor: View {
      @State var name: String
      @Binding var isSaved: Bool

      var body: some View {
          Form {
              TextField("Name", text: $name)
              Button("Save") { isSaved = true }
          }
      }
  }

  struct ProfileScreen: View {
      @State private var name = "Ana"
      @State private var isSaved = false

      var body: some View {
          VStack {
              Text("Hello, \(name)")
              ProfileEditor(name: name, isSaved: $isSaved)
          }
      }
  }
choices:
  - text: "ProfileEditor keeps its own copy of name in @State, so typing never updates the parent's greeting."
    correct: true
    why: "Two sources of truth. The child's state starts as a copy and then diverges. The editor should take @Binding var name and the parent should pass $name."
  - text: "The child's @State isn't private, so the parent can pass an initial value that's ignored on later updates."
    correct: true
    why: "If the parent's name changes later, ProfileEditor(name: name, …) passes a new value into the child's initializer, but SwiftUI keeps the stored one."
  - text: "isSaved should be @State in ProfileEditor because the button there writes it."
    correct: false
    why: "Who writes it doesn't decide ownership by itself. If the parent needs to know (to show a confirmation, say), it owns it and passes a binding, as here."
  - text: "A @Binding property can't be set from a Button's action."
    correct: false
    why: "Writing a binding's wrapped value from an action is exactly what bindings are for."
  - text: "TextField needs a Binding<String>, and $name in ProfileEditor gives one."
    correct: false
    why: "That's correct code, not a problem: $ on @State (or on @Binding) gives a Binding."
rubric:
  - Identifies the duplicated name state.
  - Identifies the non-private @State initialized from the parent.
  - Doesn't flag the isSaved binding or the TextField.
solution: |
  Two real problems, both about `name`:

  1. **A second source of truth.** `ProfileEditor` copies `name` into its own `@State`. Typing changes the copy, and the parent's "Hello, Ana" never updates. Change the child to `@Binding var name: String` and call it with `ProfileEditor(name: $name, isSaved: $isSaved)`.
  2. **A non-private `@State` with a parameter.** Even if you wanted a copy (a draft, see lesson 6), passing it through the memberwise initializer only works on first appearance. Keep `@State` private.

  `isSaved` is fine as a binding from the parent, and `TextField("Name", text: $name)` is correct once `name` is a binding.
````

````exercise
id: m36-l01-e6
type: explain
prompt: "Explain to a teammate why this preview's toggle doesn't move when tapped, and give two ways to make it interactive."
code: |
  #Preview {
      NotificationRow(isOn: .constant(false))
  }
rubric:
  - Says .constant creates a binding whose writes are ignored.
  - Says the toggle reads the binding, so it keeps showing false.
  - Suggests @Previewable @State in the preview, or a small wrapper view that owns @State and passes $value.
solution: |
  `.constant(false)` is a binding to a fixed value: reads return `false` and writes are discarded. The toggle doesn't store anything itself; it shows whatever the binding returns, so after a tap it still shows off. That's useful for previewing each state side by side, not for trying the interaction.

  To make it interactive, give the preview a real source of truth: `@Previewable @State var isOn = false` at the top of the `#Preview` body, then `NotificationRow(isOn: $isOn)`. Or write a tiny wrapper view with `@State private var isOn = false` whose body is `NotificationRow(isOn: $isOn)`, and preview the wrapper.
````

## Summary

- One owner per value. `@State private var` declares that this view owns a value; put it in the highest view that needs it.
- `@State` is for transient, value-type UI state that lives as long as the view's identity. Not for persistent data.
- The initial value of `@State` is used only on first appearance. That's why it's private: a parent "setting" it would be silently ignored.
- `@Binding var` gives a child read-write access without storage of its own. Pass one with `$`, and pass it further down with `$` again.
- `$draft.title` binds to one property of a struct in state.
- `Binding(get:set:)` builds a binding to a derived value, such as membership in a set. Its closures are `@Sendable` in Swift 6.
- `.constant(value)` is a binding that ignores writes, for previews and fixed displays. Use `@Previewable @State` for an interactive preview.
