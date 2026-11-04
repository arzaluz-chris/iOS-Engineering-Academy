---
id: m36-l02
title: "@Observable models and @Bindable"
description: "An @Observable class lets SwiftUI update exactly the views whose body read a property that changed. You watch per-property tracking in a run-able model of SwiftUI's update loop, including computed properties, ignored properties and collections; decide when a view owns a model with @State and when it just receives one; and use @Bindable to get bindings to a model's properties."
module: m36
order: 2
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l01, m32-l03]
objectives:
  - Predict which views update when a property of an @Observable model changes.
  - Explain how computed properties and @ObservationIgnored properties interact with tracking.
  - Decide whether a view should own a model (@State) or receive it (a plain property).
  - Explain why a @State default value is created on every view initialization with the Xcode 26 SDK, and how to defer expensive models.
  - Use @Bindable, as a property or as a local variable, to bind controls to a model's properties.
terms:
  - term: "@Observable"
    definition: "A macro from the Observation module (iOS 17) that makes a class observable: every stored var gets accessors that report reads and writes to an observation registrar. SwiftUI uses those reports to know which views depend on which properties."
  - term: Dependency (SwiftUI)
    definition: "A property a view's body read during its last evaluation. When it changes, SwiftUI updates that view. Properties the body didn't read aren't dependencies."
  - term: "@ObservationIgnored"
    definition: "A macro that excludes a stored property of an @Observable class from tracking. Reading it doesn't create a dependency and writing it doesn't notify anyone."
  - term: "@Bindable"
    definition: "A SwiftUI property wrapper (iOS 17) that gives bindings to the mutable properties of an observable object with the $ syntax: $book.title."
mastery:
  - Given a model and three views' bodies, say which views update after each change.
  - Explain why a computed property needs no annotation to be tracked, and why a view that read an ignored property can show stale data.
  - Write a root view that owns a model in @State and children that receive it as let properties.
  - Defer creating an expensive model with an optional @State and .task.
  - Bind a TextField to a model's property with @Bindable, including inside a ForEach.
resources: [swiftui-bindable, swiftui-managing-model-data, observation, observation-tracking, swiftui-migrating-to-observable, swiftui-managing-ui-state, swift-mainactor]
cards:
  - id: m36-l02-c1
    front: When does SwiftUI update a view that uses an @Observable model?
    back: "When a property that the view's body read during its last evaluation changes. Apple: the view \"updates only when an observable property changes and the view's body reads the property directly.\" Properties the body didn't read don't cause an update."
  - id: m36-l02-c2
    front: How are computed properties of an @Observable class tracked?
    back: "Through the stored properties they read. Reading the computed property runs its getter, which reads stored properties, and those reads are tracked. Only the reads made in that evaluation count: a branch that wasn't taken isn't a dependency."
  - id: m36-l02-c3
    front: "@State private var model = Model() vs let model: Model, when?"
    back: "@State when this view creates and owns the model for its lifetime (usually the root of a feature). A plain property (let or var) when the model is created elsewhere and passed in. Observation tracks reads either way; no wrapper is needed to observe."
  - id: m36-l02-c4
    front: What does @Bindable do, and where can you write it?
    back: "It lets you write $model.property to get a Binding to a property of an @Observable object. Use it on a view property (@Bindable var book: Book) or as a local variable in body (@Bindable var book = book), for example inside ForEach or after reading the model from the environment."
  - id: m36-l02-c5
    front: Why can an expensive @State default value be a problem (Xcode 26 SDK)?
    back: "Apple: \"A State property always instantiates its default value when SwiftUI instantiates the view.\" SwiftUI keeps only the first instance, but every re-initialization of the view runs Model() again. Keep model initializers cheap or create the model in .task. Apple's page for the Xcode 27 State() macro says it instantiates the default only the first time."
---

## The idea in one sentence

Mark a model class `@Observable`, and SwiftUI updates **only the views whose `body` read a property that changed**, with no `@Published`, no wrapper on the view side, and no manual notifications.

> [!note] About this lesson's code
> Observation is part of the Swift toolchain, so the Observation blocks here were compiled and run with Swift 6.3 on Linux. They include a small "renderer" that models SwiftUI's update loop with `withObservationTracking`; it's a model of the observable behavior Apple documents, not SwiftUI's implementation. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Quotes come from Apple's pages for `State`, `Bindable`, `ObservedObject` and "Managing model data in your app", read in November 2026.

## Where you are

Module 32, lesson 3 introduced Observation in plain Swift: `withObservationTracking` records the observable properties a closure reads and calls `onChange` once, just before the first of them changes. SwiftUI wraps that around `body`, and each update re-registers whatever the new evaluation reads. This lesson takes that mechanism to the view level: several views, one model, and the questions you face when writing real screens.

## Per-property tracking across views

Apple's "Managing model data in your app" states the rule: "a view in SwiftUI can form dependencies on observable data models", and "When a tracked property changes, SwiftUI updates the view. If other properties change that body doesn't read, the view is unaffected and avoids unnecessary updates."

To watch that happen, here's a renderer model. Each "view" is a name and a body closure that returns text. Rendering runs the body inside `withObservationTracking`; a change marks the view as invalidated; `flush()` renders the invalidated views again, which re-registers their reads. That's the loop from Module 32, run for several views at once:

```swift
import Observation

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class Book {
    var title: String
    var isAvailable = true
    @ObservationIgnored var lastOpened = "never"

    init(title: String) {
        self.title = title
    }

    var shelfLabel: String {
        isAvailable ? title : "\(title) (checked out)"
    }
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class Library {
    var books: [Book]

    init(books: [Book]) {
        self.books = books
    }

    var availableCount: Int {
        books.filter(\.isAvailable).count
    }
}

/// A model of SwiftUI's update loop, not its implementation.
@available(macOS 14, iOS 17, *)
@MainActor
final class Renderer {
    private var views: [(name: String, body: () -> String)] = []
    private var invalidated: Set<String> = []

    func add(_ name: String, body: @escaping () -> String) {
        views.append((name, body))
        render(name)
    }

    func flush() {
        let names = views.map(\.name).filter(invalidated.contains)
        invalidated = []
        names.forEach(render)
    }

    private func render(_ name: String) {
        guard let view = views.first(where: { $0.name == name }) else { return }
        let text = withObservationTracking {
            view.body()
        } onChange: { [weak self] in
            MainActor.assumeIsolated { _ = self?.invalidated.insert(name) }
        }
        print("\(name) -> \(text)")
    }
}

if #available(macOS 14, iOS 17, *) {
    let kindred = Book(title: "Kindred")
    let piranesi = Book(title: "Piranesi")
    let library = Library(books: [kindred, piranesi])
    let renderer = Renderer()

    renderer.add("Header") { "\(library.availableCount) of \(library.books.count) available" }
    renderer.add("KindredRow") { kindred.shelfLabel }
    renderer.add("PiranesiRow") { piranesi.title }

    print("[check out Kindred]")
    kindred.isAvailable = false
    renderer.flush()

    print("[rename Piranesi]")
    piranesi.title = "Piranesi (2020)"
    renderer.flush()

    print("[open Kindred]")
    kindred.lastOpened = "today"
    renderer.flush()

    print("[add a book]")
    library.books.append(Book(title: "Dune"))
    renderer.flush()
}
```

```output
Header -> 2 of 2 available
KindredRow -> Kindred
PiranesiRow -> Piranesi
[check out Kindred]
Header -> 1 of 2 available
KindredRow -> Kindred (checked out)
[rename Piranesi]
PiranesiRow -> Piranesi (2020)
[open Kindred]
[add a book]
Header -> 2 of 3 available
```

Each step shows one rule:

1. **Check out Kindred.** `isAvailable` changed. The header read it (through `availableCount`) and the Kindred row read it (through `shelfLabel`), so both re-render. The Piranesi row read only `piranesi.title`, so it doesn't.
2. **Rename Piranesi.** Only the Piranesi row read that book's `title`. The header counts books and reads `isAvailable`, never `title`.
3. **Open Kindred.** `lastOpened` is `@ObservationIgnored`. Writing it notifies nobody.
4. **Add a book.** Appending writes `library.books`, which the header read. The rows captured their own books and never read the array.

That last point is Apple's rule for collections: "When a view forms a dependency on a collection of objects, of any collection type, the view tracks changes made to the collection itself", such as inserts, deletions and moves. Changing one book's title updates the views that read that book's title, not every view that holds the array. It's also why splitting a list into row views pays off: each row view reads only its own book, so a change to one book updates one row.

> [!note] Why @MainActor and @available
> `withObservationTracking`'s `onChange` closure is `@Sendable`. Making the model `@MainActor` makes it Sendable, so the closure can capture it. SwiftUI views run on the main actor, so main-actor models are a natural fit in apps too. The `@available` lines let these blocks run as macOS command-line programs in CI, where Observation needs macOS 14; an iOS 17 app doesn't need them.

### Computed properties

`availableCount` and `shelfLabel` have no annotation, and they're tracked anyway. There's nothing to annotate: reading a computed property runs its getter, the getter reads stored properties, and those stored reads are what Observation records. Apple: "Observation also supports tracking of computed properties when the computed property makes use of an observable property."

The consequence is that tracking follows the reads **of that evaluation**. If a getter is `isMuted ? 0 : volume` and `isMuted` is `true`, `volume` isn't read, so it isn't a dependency until a later evaluation reads it. Exercise 1 shows this.

### @ObservationIgnored

`@ObservationIgnored` removes a stored property from tracking. Use it for things views don't display: caches, injected services, bookkeeping. Apple's migration guide: "If you have properties that are accessible to an observer that you don't want to track, apply the `ObservationIgnored()` macro to the property." (`let` properties are never tracked; they can't change.)

The trap is the reverse: a view that **does** display an ignored property. It shows the right value whenever something else makes it re-render and a stale value otherwise. If a view reads it, don't ignore it.

## Who owns the model

Observation doesn't need a property wrapper on the view side. Apple: SwiftUI "establishes this dependency tracking even if the view doesn't store the observable type". What the view-side choice decides is **ownership**: who creates the object and how long it lives.

```swift ios
import SwiftUI

@Observable
final class Book: Identifiable {
    let id = UUID()
    var title: String
    var isAvailable = true

    init(title: String) {
        self.title = title
    }
}

@Observable
final class Library {
    var books = [Book(title: "Kindred"), Book(title: "Piranesi")]

    var availableCount: Int {
        books.filter(\.isAvailable).count
    }
}

struct LibraryScreen: View {
    @State private var library = Library()      // owns it

    var body: some View {
        List {
            Section("\(library.availableCount) available") {
                ForEach(library.books) { book in
                    BookRow(book: book)
                }
            }
        }
    }
}

struct BookRow: View {
    let book: Book                               // receives it

    var body: some View {
        HStack {
            Text(book.title)
            Spacer()
            Button(book.isAvailable ? "Check out" : "Return") {
                book.isAvailable.toggle()
            }
        }
    }
}
```

- **`@State private var library = Library()`** in the screen that creates the model. SwiftUI keeps the instance for the view's lifetime, exactly like a `Bool` in lesson 1. Apple: "By wrapping the book with `State`, you're telling SwiftUI to manage the storage of the instance."
- **`let book: Book`** in the row. The row didn't create the book and doesn't decide how long it lives. It reads `title` and `isAvailable`, so it depends on those two properties of that one book.
- **`book.isAvailable.toggle()`** writes through the reference. No binding needed: Apple's `State` page notes that passing a binding to an object "isn't necessary when you need to change properties of that object."

> [!warning] Don't create a model in a property that isn't @State
> `let library = Library()` as a default value in a view creates a new library every time the view's initializer runs, which happens whenever the parent re-renders. All the data in it starts over. Either the view owns it (`@State`) or someone passes it in.

### The default value runs every time (Xcode 26 SDK)

There's a cost hiding in `@State private var library = Library()`. With the property wrapper, the expression `Library()` is evaluated each time SwiftUI initializes the view, and SwiftUI then keeps the first instance and discards the new one. Apple's `State` page: "A `State` property always instantiates its default value when SwiftUI instantiates the view. For this reason, avoid side effects and performance-intensive work when initializing the default value."

A plain-Swift model shows the effect. `ModelState` is a property wrapper that, like `@State`, receives its default value already built and stores it only if nothing is stored yet:

```swift
/// A model of @State storage for objects, not SwiftUI's implementation.
@MainActor
final class StateStore {
    var values: [String: AnyObject] = [:]
}

let store = StateStore()

@MainActor
@propertyWrapper
struct ModelState<Value: AnyObject> {
    private let identity: String

    init(wrappedValue: Value, identity: String) {
        self.identity = identity
        if store.values[identity] == nil {
            store.values[identity] = wrappedValue
        }
    }

    var wrappedValue: Value {
        store.values[identity] as! Value
    }
}

@MainActor
final class Library {
    static var created = 0
    let number: Int

    init() {
        Library.created += 1
        number = Library.created
        print("Library #\(number) created")
    }
}

@MainActor
struct LibraryScreen {
    @ModelState(identity: "Root/LibraryScreen") var library = Library()

    func body() -> String {
        "showing library #\(library.number)"
    }
}

for _ in 1...3 {                      // the parent re-renders three times
    print(LibraryScreen().body())
}
```

```output
Library #1 created
showing library #1
Library #2 created
showing library #1
Library #3 created
showing library #1
```

The screen always shows library #1, so the data is safe, but three libraries were built. If `Library.init` opened a database or started a request, that work would repeat on every parent update, and the side effects would happen for objects nobody uses.

Two fixes, both from Apple's `State` page:

- **Keep model initializers cheap.** Assign default values; do loading later, in a method.
- **Defer creation** with an optional and `.task`, "which is called only once when the view first appears":

```swift ios
import SwiftUI

@MainActor
@Observable
final class Catalog {
    var titles: [String] = []

    func load() async {
        titles = ["Kindred", "Piranesi"]   // stands in for real loading
    }
}

struct CatalogScreen: View {
    @State private var catalog: Catalog?

    var body: some View {
        Group {
            if let catalog {
                List(catalog.titles, id: \.self) { Text($0) }
            } else {
                ProgressView()
            }
        }
        .task {
            let catalog = Catalog()
            await catalog.load()
            self.catalog = catalog
        }
    }
}
```

> [!version] Xcode 27
> Apple's page for the `State()` macro, which replaces the property wrapper when you build with Xcode 27 or later, says instead: "A `State()` property instantiates its default value the first time SwiftUI instantiates the view." The course's iOS blocks are checked with Xcode 26.6, where the property-wrapper behavior above applies, and you'll maintain code built with both for a while. Cheap initializers are right either way.

When a model needs arguments from the parent, initialize the state in the view's initializer, as Module 32 did: `_viewModel = State(initialValue: ReadingListViewModel(repository: repository))`. The same first-time-only rule applies: if the parent later passes a different repository, the stored model doesn't change. Lesson 5 shows how to force a fresh one with `.id(_:)`.

## @Bindable: bindings to a model's properties

A `Button` can toggle `book.isAvailable` directly. A `TextField` or `Toggle` can't take `book.title`; it needs a `Binding<String>`. `@Bindable` provides it. Apple: "Use this property wrapper to create bindings to mutable properties of a data model object that conforms to the `Observable` protocol."

```swift ios
import SwiftUI

@Observable
final class Book: Identifiable {
    let id = UUID()
    var title: String
    var isAvailable = true

    init(title: String) {
        self.title = title
    }
}

struct BookEditor: View {
    @Bindable var book: Book

    var body: some View {
        Form {
            TextField("Title", text: $book.title)
            Toggle("Available", isOn: $book.isAvailable)
        }
    }
}

struct QuickRenameList: View {
    @State private var books = [Book(title: "Kindred"), Book(title: "Piranesi")]

    var body: some View {
        List(books) { book in
            @Bindable var book = book
            TextField("Title", text: $book.title)
        }
    }
}
```

- **`@Bindable var book: Book`** is still a property that receives the object. `@Bindable` only adds the `$book.property` bindings. The parent passes the book itself: `BookEditor(book: book)`, no `$`.
- **`@Bindable var book = book`** inside the `List` closure is the same wrapper on a local variable. Apple: "You can use the `Bindable` property wrapper on properties and variables to an `Observable` object. This includes global variables, properties that exists outside of SwiftUI types, or even local variables." You'll use the local form again in lesson 3, for a model read from the environment.
- **`@State private var books`** holds an array of objects. `@State` owns the array; each book is observable on its own.

`@Bindable` replaces `@ObservedObject` for `@Observable` types. Apple's `ObservedObject` page: "Don't wrap objects conforming to the `Observable` protocol with `@ObservedObject`. … If the view needs a binding to a property of an `Observable` object in its body, wrap the object with the `Bindable` property wrapper instead."

## Common mistakes

> [!error] error: cannot find '$book' in scope
> `TextField("Title", text: $book.title)` in a view that declares `let book: Book`. A `$` name only exists for a property wrapper's projected value, and a plain property has none. Add `@Bindable` to the property, or write `@Bindable var book = book` inside `body`. The same error in plain Swift, from Swift 6.3:

```swift no-compile cannot find '$book' in scope
struct Book {
    var title = "Kindred"
}

struct EditorView {
    let book: Book

    func titleField() {
        let binding = $book
        _ = binding
    }
}
```

> [!error] error: '@Observable' cannot be applied to struct type
> Observation works with classes: views share one instance and observe changes to it. A struct is copied, so there'd be nothing shared to observe. For value-type state, use `@State` with a struct (lesson 1). Swift 6.3:

```swift no-compile '@Observable' cannot be applied to struct type 'Settings'
import Observation

@available(macOS 14, iOS 17, *)
@Observable
struct Settings {
    var volume = 5
}
```

> [!error] Conforming to Observable without the macro
> `final class Library: Observable` compiles but tracks nothing. Apple: "Don't apply the `Observable` protocol by itself to your data model type, since that alone doesn't add any observation functionality. Instead, always use the `Observable` macro."

> [!error] Ignoring a property the view displays
> `@ObservationIgnored var status = ""` that a view shows in a `Text`. Changes don't update the view, so the text is right only by accident, when something else causes a re-render. Ignore only what views don't read.

> [!error] @ObservedObject or @StateObject with an @Observable type
> These belong to `ObservableObject` (lesson 4). Apple warns that `@ObservedObject` on an `Observable` type "may cause a compiler error". Use `@State` to own, a plain property to receive, `@Bindable` for bindings.

## Exercises

````exercise
id: m36-l02-e1
type: prediction
prompt: "The renderer model with a media player. Watch the computed property closely. What does it print?"
code: |
  import Observation
  
  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Player {
      var volume = 5
      var isMuted = false
      @ObservationIgnored var lastChange = "none"
  
      var effectiveVolume: Int {
          isMuted ? 0 : volume
      }
  }
  
  /// A model of SwiftUI's update loop, not its implementation.
  @available(macOS 14, iOS 17, *)
  @MainActor
  final class Renderer {
      private var views: [(name: String, body: () -> String)] = []
      private var invalidated: Set<String> = []
  
      func add(_ name: String, body: @escaping () -> String) {
          views.append((name, body))
          render(name)
      }
  
      func flush() {
          let names = views.map(\.name).filter(invalidated.contains)
          invalidated = []
          names.forEach(render)
      }
  
      private func render(_ name: String) {
          guard let view = views.first(where: { $0.name == name }) else { return }
          let text = withObservationTracking {
              view.body()
          } onChange: { [weak self] in
              MainActor.assumeIsolated { _ = self?.invalidated.insert(name) }
          }
          print("\(name) -> \(text)")
      }
  }
  
  if #available(macOS 14, iOS 17, *) {
      let player = Player()
      let renderer = Renderer()
      renderer.add("MuteButton") { player.isMuted ? "Unmute" : "Mute" }
      renderer.add("Meter") { "level \(player.effectiveVolume)" }
      renderer.add("Log") { "last change: \(player.lastChange)" }
  
      print("[mute]")
      player.isMuted = true
      player.lastChange = "muted"
      renderer.flush()
  
      print("[volume up while muted]")
      player.volume += 1
      renderer.flush()
  
      print("[unmute]")
      player.isMuted = false
      renderer.flush()
  }
output: |
  MuteButton -> Mute
  Meter -> level 5
  Log -> last change: none
  [mute]
  MuteButton -> Unmute
  Meter -> level 0
  [volume up while muted]
  [unmute]
  MuteButton -> Mute
  Meter -> level 6
hints:
  - "The first render of Meter reads isMuted (false) and then volume."
  - "After muting, Meter re-renders and reads isMuted (true). Does the getter read volume this time?"
  - "Log read lastChange, which is ignored."
solution: |
  ```output
  MuteButton -> Mute
  Meter -> level 5
  Log -> last change: none
  [mute]
  MuteButton -> Unmute
  Meter -> level 0
  [volume up while muted]
  [unmute]
  MuteButton -> Mute
  Meter -> level 6
  ```

  - **First render.** All three views render. `Log` reads only an ignored property, so it has no dependencies at all.
  - **Mute.** `MuteButton` read `isMuted`, and so did `Meter` through `effectiveVolume`; both re-render. `lastChange` is ignored, so `Log` doesn't re-render and still shows "none": stale.
  - **Volume up while muted.** When `Meter` re-rendered after muting, `effectiveVolume` returned `0` without reading `volume`. Its dependencies are now just `isMuted`, so nothing updates.
  - **Unmute.** Both views that read `isMuted` re-render. `Meter` now reads `volume` again and shows 6, the value changed while muted.

  Tracking is per evaluation: a branch that wasn't taken creates no dependency. That's correct here (a muted meter shows 0 whatever the volume is), and it's why you don't need to think about it most of the time. The `Log` view is the real bug: it displays an ignored property.
````

````exercise
id: m36-l02-e2
type: comprehension
prompt: "ProfileScreen owns a Profile model in @State and passes it to HeaderView, whose body reads profile.name, and to StatsView, whose body reads profile.followers.count. The user edits their bio (profile.bio). Which views update?"
choices:
  - text: "Neither HeaderView nor StatsView, and ProfileScreen only if its own body read bio."
    correct: true
    why: "Views update for properties their body read. Nobody listed reads bio, and holding the object doesn't create a dependency."
  - text: "Both, because they hold a reference to the profile that changed."
    correct: false
    why: "That's ObservableObject's behavior (lesson 4). With Observation, Apple: views that don't read a property aren't updated when it changes."
  - text: "Only ProfileScreen, because it owns the model in @State."
    correct: false
    why: "@State on an object stores the reference. It doesn't make the owner depend on every property; only the reads in its body count."
  - text: "Both, but only because followers is an array."
    correct: false
    why: "StatsView depends on followers (it read count). Editing bio doesn't touch followers."
solution: |
  **Neither child.** Dependencies come from reads in `body`. `HeaderView` depends on `name`, `StatsView` on `followers`. Editing `bio` notifies only views that read `bio`. `ProfileScreen` updates only if its own `body` read `bio`; storing the object in `@State` isn't a read of its properties. Apple: "If a view doesn't have any dependencies, SwiftUI doesn't update the view when data changes."
````

````exercise
id: m36-l02-e3
type: fill-in
prompt: "Complete the code so the settings screen owns the model and the editor can bind a text field and a toggle to it."
code: |
  import SwiftUI

  [[1]]
  final class AccountSettings {
      var displayName = ""
      var isPublic = false
  }

  struct SettingsScreen: View {
      [[2]] private var settings = AccountSettings()

      var body: some View {
          AccountEditor(settings: [[3]])
      }
  }

  struct AccountEditor: View {
      [[4]] var settings: AccountSettings

      var body: some View {
          Form {
              TextField("Display name", text: [[5]])
              Toggle("Public profile", isOn: $settings.isPublic)
          }
      }
  }
blanks:
  - id: "1"
    answers: ["@Observable"]
  - id: "2"
    answers: ["@State"]
  - id: "3"
    answers: ["settings"]
  - id: "4"
    answers: ["@Bindable"]
  - id: "5"
    answers: ["$settings.displayName"]
hints:
  - "The parent passes the object itself, not a binding to it."
  - "The child needs $settings.property bindings, which a plain property doesn't have."
solution: |
  ```swift ios
  import SwiftUI

  @Observable
  final class AccountSettings {
      var displayName = ""
      var isPublic = false
  }

  struct SettingsScreen: View {
      @State private var settings = AccountSettings()

      var body: some View {
          AccountEditor(settings: settings)
      }
  }

  struct AccountEditor: View {
      @Bindable var settings: AccountSettings

      var body: some View {
          Form {
              TextField("Display name", text: $settings.displayName)
              Toggle("Public profile", isOn: $settings.isPublic)
          }
      }
  }
  ```

  `@Observable` makes the class trackable. The screen creates and owns it with `@State`. The editor receives the object (no `$` at the call site) and marks it `@Bindable` so `$settings.displayName` and `$settings.isPublic` exist.
````

````exercise
id: m36-l02-e4
type: find-errors
prompt: "Which of these are real problems in this code?"
code: |
  import SwiftUI

  @Observable
  final class Inbox {
      var messages: [String] = []
      @ObservationIgnored var unreadCount = 0

      init() {
          messages = MessageStore.loadAllFromDisk()
      }
  }

  struct InboxScreen: View {
      @State private var inbox = Inbox()

      var body: some View {
          VStack {
              Text("\(inbox.unreadCount) unread")
              ComposeView()
          }
      }
  }

  struct ComposeView: View {
      let draft = Draft()

      var body: some View {
          TextField("Message", text: $draft.text)
      }
  }

  @Observable
  final class Draft {
      var text = ""
  }
choices:
  - text: "unreadCount is ignored but shown in a Text, so the badge doesn't update when it changes."
    correct: true
    why: "@ObservationIgnored removes it from tracking. A displayed property must be tracked."
  - text: "Inbox's initializer loads from disk, and with the Xcode 26 property wrapper the default value is built every time InboxScreen is initialized."
    correct: true
    why: "Apple: State always instantiates its default value when SwiftUI instantiates the view. Load in a method called from .task."
  - text: "ComposeView creates its Draft in a plain let, so every parent re-render makes a new, empty draft."
    correct: true
    why: "Only @State storage survives re-initialization. A default value in a plain property is rebuilt with the struct."
  - text: "$draft.text doesn't compile: draft is a plain property, so there's no $draft."
    correct: true
    why: "Swift: cannot find '$draft' in scope. It needs @Bindable (or @State, if the view owns it)."
  - text: "InboxScreen needs @ObservedObject to see changes in inbox."
    correct: false
    why: "Observation tracks reads in body without any wrapper. @ObservedObject is for ObservableObject types."
rubric:
  - Flags the ignored but displayed property.
  - Flags the disk load in the initializer of a @State default.
  - Flags the non-state let draft and the missing $draft.
  - Doesn't recommend @ObservedObject.
solution: |
  Four real problems:

  1. **`@ObservationIgnored var unreadCount`** is displayed. Remove the attribute.
  2. **Disk I/O in `Inbox.init`.** `@State private var inbox = Inbox()` evaluates `Inbox()` on every initialization of `InboxScreen` (Xcode 26 SDK), so the file is read again and again, and the extra instances are thrown away. Give `Inbox` a `load()` method and call it from `.task`, or create the inbox in `.task` as an optional.
  3. **`let draft = Draft()`** is rebuilt whenever `ComposeView` is initialized, which happens every time `InboxScreen`'s body runs. The user's text vanishes. `ComposeView` owns the draft, so make it `@State private var draft = Draft()`.
  4. **`$draft.text`** doesn't compile with a plain `let`. With `@State`, `$draft.text` works, because `$draft` is a `Binding<Draft>` and dynamic member lookup gives `Binding<String>`. If the draft were passed in instead, you'd use `@Bindable`.

  `@ObservedObject` would be wrong: it requires `ObservableObject`.
````

````exercise
id: m36-l02-e5
type: solve
prompt: |
  Write an `@Observable` `Cart` (main-actor, with the `@available(macOS 14, iOS 17, *)` line so it runs in CI) with:

  - `items: [LineItem]`, where `LineItem` is a struct with `let name: String`, `let price: Int` (cents) and `var quantity: Int`;
  - `couponCode: String?`;
  - `lastSaved: String`, which no view displays, so it must not be tracked;
  - a computed `total: Int`: the sum of `price * quantity`, minus 10% (integer `* 9 / 10`) when `couponCode == "SAVE10"`.

  Then write `watchTotal(_:)`, which reads `total` inside `withObservationTracking`, prints `"total will change"` in `onChange`, and prints `"total is <value>"`. Run this sequence and match the output exactly:

  ```swift
  let cart = Cart()
  watchTotal(cart)
  cart.items.append(LineItem(name: "Notebook", price: 400, quantity: 1))
  watchTotal(cart)
  cart.lastSaved = "now"
  cart.couponCode = "SAVE10"
  watchTotal(cart)
  cart.items[0].quantity += 1
  watchTotal(cart)
  ```

  ```output
  total is 0
  total will change
  total is 400
  total will change
  total is 360
  total will change
  total is 720
  ```
starter: |
  import Observation

  struct LineItem {
      let name: String
      let price: Int
      var quantity: Int
  }

  // Cart and watchTotal(_:) here.

  if #available(macOS 14, iOS 17, *) {
      // The sequence from the prompt.
  }
hints:
  - "total needs no annotation: it reads items and couponCode, which are tracked."
  - "lastSaved gets @ObservationIgnored. total never reads it, so the output would be the same without the attribute; it's there because no view displays lastSaved."
  - "Changing a quantity inside the array writes the items property, so it notifies."
rubric:
  - Cart is @Observable, @MainActor and marked available for macOS 14 / iOS 17.
  - total is a computed property; nothing derived is stored.
  - lastSaved is @ObservationIgnored.
  - watchTotal re-registers on each call and the output matches exactly.
solution: |
  ```swift
  import Observation

  struct LineItem {
      let name: String
      let price: Int
      var quantity: Int
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Cart {
      var items: [LineItem] = []
      var couponCode: String?
      @ObservationIgnored var lastSaved = "never"

      var total: Int {
          let sum = items.reduce(0) { $0 + $1.price * $1.quantity }
          return couponCode == "SAVE10" ? sum * 9 / 10 : sum
      }
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  func watchTotal(_ cart: Cart) {
      let total = withObservationTracking {
          cart.total
      } onChange: {
          print("total will change")
      }
      print("total is \(total)")
  }

  if #available(macOS 14, iOS 17, *) {
      let cart = Cart()
      watchTotal(cart)
      cart.items.append(LineItem(name: "Notebook", price: 400, quantity: 1))
      watchTotal(cart)
      cart.lastSaved = "now"
      cart.couponCode = "SAVE10"
      watchTotal(cart)
      cart.items[0].quantity += 1
      watchTotal(cart)
  }
  ```

  ```output
  total is 0
  total will change
  total is 400
  total will change
  total is 360
  total will change
  total is 720
  ```

  - `total` is computed, so it can't go stale. Reading it inside the tracking closure reads `items` and `couponCode`, and those are the dependencies.
  - Each `watchTotal` call registers again; tracking is one-shot, as in Module 32.
  - `cart.lastSaved = "now"` notifies nobody because it's ignored. `total` doesn't read it either, so this output can't show the attribute at work; it's there so that bookkeeping no view displays costs no tracking and can never trigger an update.
  - `cart.items[0].quantity += 1` modifies the array in place. That's a write to `items`, so views that read `items` (or `total`) update. Struct elements behave this way; with class elements, the array wouldn't change, and only views reading that element's properties would update.
````

````exercise
id: m36-l02-e6
type: explain
prompt: "A teammate says: \"I put my API client's setup in the view model's init and hold it with @State private var model = FeedModel(). Logging shows FeedModel.init running every time I type in the parent's search field. Is SwiftUI recreating my model?\" Explain what's happening and what to change."
code: |
  struct SearchScreen: View {
      @State private var query = ""

      var body: some View {
          VStack {
              TextField("Search", text: $query)
              FeedScreen()
          }
      }
  }

  struct FeedScreen: View {
      @State private var model = FeedModel()   // FeedModel.init sets up the API client

      var body: some View {
          List(model.posts) { post in Text(post.title) }
      }
  }
rubric:
  - Says the parent's state change re-initializes the child view struct, which evaluates the @State default value again.
  - Says SwiftUI keeps the first instance, so the model in use isn't replaced, but the extra instances are built and discarded.
  - Recommends a cheap initializer with loading moved to a method called from .task, or creating the model in .task.
  - Optionally mentions that Apple's page for the Xcode 27 State() macro says the default is created only the first time.
solution: |
  Typing changes the parent's state, so the parent's body runs again and creates a new `FeedScreen` struct. With the `@State` property wrapper (Xcode 26 SDK and earlier), Apple says "A `State` property always instantiates its default value when SwiftUI instantiates the view", so `FeedModel()` runs each time. SwiftUI then connects the property to the instance it stored the first time, so the screen keeps using the original model, and the new one is thrown away. The logs are real work done for nothing, plus any side effects of that init.

  Make `FeedModel.init` cheap (just store dependencies) and move the setup and loading into a method that `.task` calls, or keep `@State private var model: FeedModel?` and create it in `.task`. Apple's page for the `State()` macro used with Xcode 27 says the default is instantiated only the first time, but code built with Xcode 26 behaves as above, and a cheap initializer is right for both.
````

## Summary

- `@Observable` classes notify per property. A view updates when a property its `body` read changes, and only then.
- Computed properties are tracked through the stored properties they read in that evaluation. `@ObservationIgnored` removes a stored property from tracking; never ignore something a view displays.
- A view that reads a collection tracks inserts, removals and replacements. Changes inside an element object update the views that read that element.
- Ownership decides the wrapper: `@State private var model` where the model is created and owned, a plain `let` or `var` where it's passed in. Never a bare default value in a non-state property.
- With the Xcode 26 `@State` wrapper, the default value is built on every view initialization; keep initializers cheap or create the model in `.task`.
- `@Bindable` gives `$model.property` bindings, on a property or a local variable in `body`. It replaces `@ObservedObject` for `@Observable` types.
