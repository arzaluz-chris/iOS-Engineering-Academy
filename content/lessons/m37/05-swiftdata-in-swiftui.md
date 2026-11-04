---
id: m37-l05
title: SwiftData in SwiftUI
description: "SwiftData is built to be used straight from views: a container set on the App, @Query properties that stay in sync with the store, and a model context from the environment for writes. You configure the container for the app, UI tests and previews, write static and dynamic queries (rebuilt from an initializer when the parent's filter changes), insert, delete and edit through the context with an editor that doesn't save until Save, and decide where logic goes when the view is reading the database directly."
module: m37
order: 5
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l04, m31-l05]
objectives:
  - Set up a ModelContainer on the App, with in-memory variants for UI tests and previews.
  - Read models with @Query using filters, sort descriptors and dynamic queries built in an initializer.
  - Insert, delete and edit models through the modelContext from the environment.
  - Build an editor that keeps changes in a draft until Save, given that the main context autosaves.
  - Decide where logic lives in a SwiftData app and why @Query belongs in views.
terms:
  - term: "@Query"
    definition: "A SwiftData property wrapper for views that fetches models matching a filter and sort order and keeps the array in sync with the store: inserts, changes and deletes update the view."
  - term: Dynamic query
    definition: "A @Query whose filter or sort depends on input. The view takes the input in its initializer and assigns _items = Query(filter:sort:); when the parent passes new input, SwiftUI calls the initializer again and the query is rebuilt."
  - term: modelContext (environment)
    definition: "The ModelContext that .modelContainer(_:) puts in the environment; for the container set on the App, it's the container's mainContext, which autosaves."
  - term: In-memory container
    definition: "A ModelContainer created with ModelConfiguration(isStoredInMemoryOnly: true): nothing is written to disk. Used for previews, UI tests and unit tests."
mastery:
  - Write an App whose container is on disk normally and in memory with a -ui-testing launch argument.
  - Write a static @Query with a filter and sort, and a child view whose query is rebuilt from the parent's search text and sort choice.
  - Insert a new model and delete rows with onDelete through the environment's context.
  - Write an add/edit sheet whose fields are a draft, so Cancel never leaves changes behind.
  - Create a preview container with sample data and explain why previews should never use the on-disk store.
resources: [swiftdata-query, swiftui-scene-modelcontainer, swiftdata-filtering-sorting, swiftdata-adding-editing, swiftdata, swiftdata-modelcontext, foundation-predicate, swiftui-previews, swiftui-app, swiftui-sheet-item]
cards:
  - id: m37-l05-c1
    front: Where do you set the ModelContainer, and what does it give the views?
    back: "On the App's WindowGroup with .modelContainer(for:) or .modelContainer(container). It puts a model context (the container's mainContext) in the environment, which every @Query below uses and views read with @Environment(\\.modelContext)."
  - id: m37-l05-c2
    front: How do you make a @Query depend on a search string?
    back: "Put the search state in the parent. The child takes it in init and assigns _books = Query(filter: ..., sort: ...). When the parent's state changes, SwiftUI calls the child's init again and the query is rebuilt."
  - id: m37-l05-c3
    front: Why edit a SwiftData model through a draft?
    back: "The main context autosaves. Binding text fields directly to the model writes every keystroke into it, and an autosave can persist them before the user taps Cancel. Apple's sample editor copies values into @State and writes them back only on Save."
  - id: m37-l05-c4
    front: Can a view model use @Query?
    back: "No: @Query is a SwiftUI dynamic property that SwiftUI fills in for views. A class would fetch with context.fetch(FetchDescriptor) and lose automatic updates. In SwiftData apps, reads usually stay in views and logic goes into model methods, predicates and services."
  - id: m37-l05-c5
    front: How should previews get SwiftData?
    back: "From an in-memory container with sample data: .modelContainer(for: Book.self, inMemory: true) for an empty store, or a helper that creates a ModelConfiguration(isStoredInMemoryOnly: true) container and inserts samples. Never the on-disk store."
---

## The idea in one sentence

**SwiftData in SwiftUI is model-view by design**: the App owns the container, views read live data with `@Query`, and writes go through the context in the environment, so most screens need no view model and no repository for reading.

> [!note] About this lesson's code
> SwiftData and SwiftUI don't build on Linux, so the SwiftData blocks here are type-checked against the iOS 17 SDK in Swift 6 mode on macOS, not run. The model of autosave and drafts is plain Swift and was compiled and run with Swift 6.3; it models the behavior Apple documents, not SwiftData's implementation. Quotes come from Apple's pages for `Query`, `modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)`, `Scene.modelContainer(_:)`, `ModelContext.autosaveEnabled` and the sample "Adding and editing persistent data in your app", read in November 2026.

## Where you are

Module 31, lesson 5 covered SwiftData itself: `@Model` classes, attributes and relationships, `ModelContainer` and `ModelContext`, `FetchDescriptor` and `#Predicate`, a first `@Query`, and model actors for background work. Lesson 6 there covered migrations and the idea of offline sync. This lesson is about wiring SwiftData into an app's screens; lesson 6 here builds the sync layer on top.

## The container belongs to the App

One container for the app, set on the scene. Apple's `Scene.modelContainer(_:)` page shows the shape and says the environment's `modelContext` "will be assigned a new context associated with this container. All implicit model context operations in this scene, such as `Query` properties, will use the environment's context."

Building the container yourself, instead of using `.modelContainer(for: Book.self)`, lets you choose the configuration: an in-memory store for UI tests, a migration plan (Module 31, lesson 6), CloudKit options. Keep that choice in one function:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var isRead: Bool
    var addedAt: Date

    init(title: String, author: String, isRead: Bool = false, addedAt: Date = .now) {
        self.title = title
        self.author = author
        self.isRead = isRead
        self.addedAt = addedAt
    }
}

enum LibraryStore {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Book.self, configurations: configuration)
    }
}
```

The App calls it once, at launch:

```swift illustrative
@main
struct BookshelfApp: App {
    private let container: ModelContainer

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        do {
            container = try LibraryStore.makeContainer(inMemory: isUITesting)
        } catch {
            fatalError("Couldn't open the library store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryScreen()
        }
        .modelContainer(container)
    }
}
```

- **The App is the composition root** (lesson 2), and the container is one more dependency it creates. UI tests launch with `-ui-testing` and get an empty in-memory store every run (Module 33, lesson 5).
- **`fatalError` on failure** is what Apple's samples do. A store that can't open usually means a migration bug you need to see in development. If your app can run without its store, show a recovery screen instead; either way, decide on purpose.
- **The main context autosaves.** Apple's `autosaveEnabled` page: "SwiftData automatically sets this property to `true` for the model container's `mainContext`", and when it's on, "the context calls `save()` after you make changes to any inserted or registered models." That matters for editing, below.

> [!warning] One container, set once
> Apple's view-level `modelContainer(for:inMemory:...)` page: "The container will only be created once. New values that are passed to the `modelType` and `inMemory` parameters after the view is first created will be ignored." Don't try to switch stores by changing those arguments; create the container you need up front.

## Reading with @Query

`@Query` fetches models and, in Apple's words, "manages those models so they remain in sync with the underlying data." Any insert, change or delete that affects the results updates the views that read them. A view that needs a fixed slice of the store declares it directly:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var isRead: Bool
    var addedAt: Date

    init(title: String, author: String, isRead: Bool = false, addedAt: Date = .now) {
        self.title = title
        self.author = author
        self.isRead = isRead
        self.addedAt = addedAt
    }
}

struct RecentlyAddedView: View {
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]

    var body: some View {
        List(books.prefix(5)) { book in
            Text(book.title)
        }
    }
}

struct UnreadBadge: View {
    @Query(filter: #Predicate<Book> { !$0.isRead }) private var unread: [Book]

    var body: some View {
        Text("\(unread.count) unread")
    }
}

struct ShelfView: View {
    @Query(sort: [SortDescriptor(\Book.author), SortDescriptor(\Book.title)])
    private var books: [Book]

    var body: some View {
        List(books) { book in
            LabeledContent(book.title, value: book.author)
        }
    }
}
```

- **`sort:` with a key path and `order:`**, or an array of `SortDescriptor`s for ties (author, then title).
- **`filter:`** takes a `#Predicate`. Marking a book read makes it stop matching, and the badge's count drops with no code.
- **Each view asks for what it shows.** Three views, three queries, no shared array to keep in sync. That's the "store facts once" rule from Module 36, with the store as the source of truth.

`RecentlyAddedView` fetches every book and shows five. For a large store, a `FetchDescriptor` with `fetchLimit` does the limiting in the database: `@Query(descriptor)` with a static descriptor whose `fetchLimit` is 5.

### Dynamic queries: build the query in init

A filter that depends on user input (search text, a sort choice, a toggle) can't be written in the `@Query` attribute, because the attribute's arguments are fixed. Apple's earthquake sample shows the pattern: the view takes the inputs in its initializer and builds the query there. The input lives in the **parent**:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var isRead: Bool
    var addedAt: Date

    init(title: String, author: String, isRead: Bool = false, addedAt: Date = .now) {
        self.title = title
        self.author = author
        self.isRead = isRead
        self.addedAt = addedAt
    }
}

extension Book {
    /// One place for the filter, so every list that shows "the library" agrees.
    static func predicate(searchText: String, showsRead: Bool) -> Predicate<Book> {
        #Predicate<Book> { book in
            (searchText.isEmpty || book.title.localizedStandardContains(searchText))
                && (showsRead || !book.isRead)
        }
    }
}

enum BookSort: String, CaseIterable, Identifiable {
    case title, author, recent

    var id: Self { self }

    var descriptors: [SortDescriptor<Book>] {
        switch self {
        case .title: [SortDescriptor(\Book.title)]
        case .author: [SortDescriptor(\Book.author), SortDescriptor(\Book.title)]
        case .recent: [SortDescriptor(\Book.addedAt, order: .reverse)]
        }
    }
}

struct LibraryScreen: View {
    @State private var searchText = ""
    @State private var sort = BookSort.title
    @State private var showsRead = true

    var body: some View {
        NavigationStack {
            BookList(searchText: searchText, sort: sort, showsRead: showsRead)
                .navigationTitle("Library")
                .searchable(text: $searchText)
                .toolbar {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(BookSort.allCases) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }
                        Toggle("Show read books", isOn: $showsRead)
                    } label: {
                        Label("Options", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
        }
    }
}

struct BookList: View {
    @Query private var books: [Book]
    @Environment(\.modelContext) private var context

    init(searchText: String, sort: BookSort, showsRead: Bool) {
        _books = Query(
            filter: Book.predicate(searchText: searchText, showsRead: showsRead),
            sort: sort.descriptors
        )
    }

    var body: some View {
        List {
            ForEach(books) { book in
                BookRow(book: book)
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(books[index])
                }
            }
        }
        .overlay {
            if books.isEmpty {
                ContentUnavailableView("No books", systemImage: "books.vertical")
            }
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(book.title)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                book.isRead.toggle()
            } label: {
                Image(systemName: book.isRead ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless)
        }
    }
}
```

How the pieces fit:

- **`LibraryScreen` owns the inputs** in `@State`. Typing in the search field changes `searchText`, `LibraryScreen.body` runs again and creates a new `BookList` value with the new text.
- **`BookList.init` rebuilds the query.** `_books` is the `Query` wrapper itself (the underscore names the property wrapper, as with `_model = State(...)`). SwiftUI keeps `BookList`'s identity and uses the new query description.
- **The filter state can't live in `BookList`.** A `@State var searchText` inside `BookList` would only be readable in `body`, not in `init`, where the query is built. That's why Apple's sample, and this one, keep it one level up.
- **`Book.predicate(searchText:showsRead:)`** is a static function, as in Apple's sample, so any other list (a widget, a picker) filters the same way. `localizedStandardContains` is, in Apple's words, "the most appropriate method for doing user-level string searches": locale-aware, case and diacritic insensitive.
- **`BookRow` takes the book as a `let`.** `@Model` classes are `Observable`, so the row tracks `title`, `author` and `isRead` like any `@Observable` model (Module 36, lesson 2), and `book.isRead.toggle()` writes through to the context, which autosaves.
- **`onDelete` deletes through the context.** The query notices and the row disappears.

Rebuilding a query per keystroke is fine for a local store of hundreds or a few thousand rows. For a very large store, debounce the way lesson 4 did: keep a separate `appliedSearch` in the parent, set it from `.task(id: searchText)` after a short sleep, and pass `appliedSearch` to `BookList`.

## Writing through the context

The environment's context is the one the queries use, so writes show up everywhere at once:

- **Insert:** `context.insert(Book(title: "Kindred", author: "Octavia E. Butler"))`.
- **Delete:** `context.delete(book)`.
- **Change:** assign to the model's properties.
- **Save:** happens automatically on the main context. Call `try context.save()` yourself when the data must be on disk *now*: before handing the store to a background model actor, before sharing a file, before a sync push (lesson 6).

### Editing: a draft, not a live binding

`@Bindable var book: Book` with `TextField("Title", text: $book.title)` works, and it's right for edits that apply immediately (a "read" toggle, a rating). For an editor with **Cancel**, it's wrong: every keystroke goes into the model, other screens show the half-typed title, and autosave can write it to disk before the user cancels. Then `context.rollback()` can't help, because it restores models "to their most recent committed state", and the half-typed title is already committed.

A small model shows the timing. `PretendContext` follows the documented behavior: changes go into the model object right away, `autosave()` commits them, and `rollback()` restores the last committed values:

```swift
/// Stands in for a @Model: a reference type whose properties views change directly.
final class Book {
    var title: String
    init(title: String) { self.title = title }
}

/// A model of the main context's documented behavior, not SwiftData's implementation.
final class PretendContext {
    let book: Book
    private(set) var committedTitle: String

    init(book: Book) {
        self.book = book
        committedTitle = book.title
    }

    func autosave() { committedTitle = book.title }
    func rollback() { book.title = committedTitle }
}

// Editor A: text field bound straight to the model.
let liveContext = PretendContext(book: Book(title: "Dune"))
liveContext.book.title = "Dune Mess"        // typing
liveContext.autosave()                      // the context saves while the sheet is open
liveContext.book.title = "Dune Messiah"     // more typing
liveContext.rollback()                      // Cancel
print("live edit after Cancel:", liveContext.book.title)

// Editor B: text field bound to a draft in @State.
let draftContext = PretendContext(book: Book(title: "Dune"))
var draft = draftContext.book.title         // copied when the editor appears
draft = "Dune Mess"
draftContext.autosave()
draft = "Dune Messiah"
// Cancel: the draft is thrown away.
print("draft edit after Cancel:", draftContext.book.title)

// Editor B again, this time Save copies the draft into the model.
draftContext.book.title = draft
draftContext.autosave()
print("draft edit after Save:", draftContext.book.title, "/ committed:", draftContext.committedTitle)
```

```output
live edit after Cancel: Dune Mess
draft edit after Cancel: Dune
draft edit after Save: Dune Messiah / committed: Dune Messiah
```

The live edit's Cancel leaves "Dune Mess" behind: neither what the book was nor what the user typed. The draft can't leak, because nothing touches the model until Save. This is the reason Apple gives in its "Adding and editing persistent data in your app" sample: the editor's state variables separate "what they enter from the data stored in `animal`. This separation ensures that SwiftData doesn't save changes that a person makes until they're ready to save those changes."

The editor, for both adding and editing:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var author: String

    init(title: String, author: String) {
        self.title = title
        self.author = author
    }
}

struct BookEditor: View {
    let book: Book?                          // nil: adding a new book

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
            }
            .navigationTitle(book == nil ? "Add Book" : "Edit Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let book {
                    title = book.title
                    author = book.author
                }
            }
        }
    }

    private func save() {
        let title = title.trimmingCharacters(in: .whitespaces)
        if let book {
            book.title = title
            book.author = author
        } else {
            context.insert(Book(title: title, author: author))
        }
    }
}

struct LibraryToolbar: View {
    @State private var isAdding = false
    @State private var editing: Book?

    var body: some View {
        Button("Add Book", systemImage: "plus") { isAdding = true }
            .sheet(isPresented: $isAdding) {
                BookEditor(book: nil)
            }
            .sheet(item: $editing) { book in
                BookEditor(book: book)
            }
    }
}
```

It's Module 36's draft pattern with SwiftData's two cases: editing writes the draft back into the existing model, adding inserts a new one. Each sheet presentation is a new identity, so `onAppear` copies fresh values every time (Module 36, lesson 5). `sheet(item:)` works with the book directly because `@Model` classes are `Identifiable`.

## Where the logic goes

With `@Query` in views, a SwiftData screen often has no view model. That's the MV style from lesson 1, and SwiftData pushes you toward it:

- **`@Query` only works in views.** It's a SwiftUI dynamic property, filled in by SwiftUI for the view that declares it. An `@Observable` class can't use it; it would call `context.fetch(FetchDescriptor(...))` and lose the automatic updates. If a screen needs a view model for something else (an async import, a multi-step flow), keep the `@Query` in the view and pass results or IDs to the model.
- **Rules go on the models or beside them.** `book.markRead()` as a method on the `@Model`, a static `predicate(...)` shared by lists, a plain struct for calculations (lesson 1). They're testable with an in-memory container on macOS or iOS.
- **Workflows go in services.** Importing a file, syncing with a server, bulk edits: a type that takes a `ModelContainer` or a `ModelContext` (or a `@ModelActor` for background work, Module 31, lesson 5), behind a protocol so screens and tests can swap it. Lesson 6 builds one.

## Previews with an in-memory container

A preview needs a container in its environment, or `@Query` has nothing to read. **Never point previews at the on-disk store**: preview runs would write into the same database your development builds use. For an empty store, the view modifier does it in one line; for sample data, build the container yourself:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var isRead: Bool

    init(title: String, author: String, isRead: Bool = false) {
        self.title = title
        self.author = author
        self.isRead = isRead
    }
}

@MainActor
enum PreviewLibrary {
    static func makeContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: Book.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let samples = [
            Book(title: "Kindred", author: "Octavia E. Butler", isRead: true),
            Book(title: "Piranesi", author: "Susanna Clarke"),
            Book(title: "The Dispossessed", author: "Ursula K. Le Guin"),
        ]
        for book in samples {
            container.mainContext.insert(book)
        }
        return container
    }
}
```

```swift illustrative
#Preview("Library with books") {
    LibraryScreen()
        .modelContainer(PreviewLibrary.makeContainer())
}

#Preview("Empty library") {
    LibraryScreen()
        .modelContainer(for: Book.self, inMemory: true)
}

#Preview("Row") {
    let container = PreviewLibrary.makeContainer()
    let book = try! container.mainContext.fetch(FetchDescriptor<Book>()).first!
    return List { BookRow(book: book) }
        .modelContainer(container)
}
```

The last preview fetches one model from the sample container, so the row gets a book that lives in a context, as it does in the app. From iOS 18, the `PreviewModifier` protocol lets you share an expensive preview setup like this container across previews; with an iOS 17 deployment target, a helper function like `PreviewLibrary` is the portable choice.

## Common mistakes

> [!error] Creating a ModelContainer in a view
> `let container = try! ModelContainer(for: Book.self)` in a view property creates a new container, with its own main context, every time the view struct is created. Create it once in the `App`.

> [!error] Keeping filter state where the query can't see it
> `@State private var searchText` inside the view that declares `@Query`. The query is built in `init`, before `@State` is readable. Keep the inputs in the parent and pass them to the initializer.

> [!error] @Query in a view model
> It never gets a context and never updates. Keep `@Query` in views; give the model fetched results, IDs or a context-backed service.

> [!error] Binding an editor with Cancel straight to the model
> Autosave can persist the half-edited values before the user cancels. Edit a draft in `@State` and copy it back on Save.

> [!error] Previews on the real store
> A preview with `.modelContainer(for: Book.self)` (no `inMemory`) writes into the simulator's on-disk store. Use `inMemory: true` or an in-memory configuration.

## Exercises

````exercise
id: m37-l05-e1
type: prediction
prompt: "Using the lesson's model of the main context, an editor bound live to the model goes through these steps. What does it print?"
code: |
  final class Note {
      var text: String
      init(text: String) { self.text = text }
  }

  final class PretendContext {
      let note: Note
      private(set) var committed: String
      private(set) var saves = 0

      init(note: Note) {
          self.note = note
          committed = note.text
      }

      func autosave() {
          guard note.text != committed else { return }
          committed = note.text
          saves += 1
      }

      func rollback() { note.text = committed }
  }

  let context = PretendContext(note: Note(text: "Buy milk"))
  context.note.text = "Buy oat milk"
  context.rollback()
  print(context.note.text, context.saves)

  context.note.text = "Buy oat"
  context.autosave()
  context.autosave()
  context.note.text = "Buy oat milk and eggs"
  context.rollback()
  print(context.note.text, context.saves)
output: |
  Buy milk 0
  Buy oat 1
hints:
  - "rollback restores the last committed value."
  - "The second autosave has nothing new to save."
solution: |
  ```output
  Buy milk 0
  Buy oat 1
  ```

  The first edit was never committed, so rollback restores "Buy milk" and no save happened. The second time, an autosave committed "Buy oat" in the middle of the edit (the second call found no changes and did nothing), so rollback goes back to "Buy oat", a value the user never meant to keep. That's the case a draft in `@State` avoids.
````

````exercise
id: m37-l05-e2
type: comprehension
prompt: "A BookList view declares `@Query private var books: [Book]` and `@State private var searchText = \"\"`, and builds `_books = Query(filter: Book.predicate(searchText: searchText, showsRead: true))` in its init. The search field is bound to $searchText. What happens when the user types?"
choices:
  - text: "The list never filters: the query was built in init from searchText's initial value, and typing doesn't call init again."
    correct: true
    why: "@State changes re-run body, not init, and in init the property only has its initial value."
  - text: "The list filters on every keystroke, because @Query observes @State properties."
    correct: false
    why: "A query only knows the predicate it was built with."
  - text: "It doesn't compile: @Query and @State can't be in the same view."
    correct: false
    why: "They can. The design just doesn't work for this purpose."
  - text: "SwiftData crashes because the predicate captures a property wrapper."
    correct: false
    why: "Nothing crashes; the captured value is a plain String at the time init ran."
solution: |
  **It never filters.** The query is built in `init`, where the view's `@State` only has its initial value. Typing changes `searchText`, which makes SwiftUI re-run `BookList.body`, but `body` doesn't rebuild the query and `init` doesn't run again for a change in the view's own state. Move `searchText` to the parent and pass it into `BookList(searchText:)`, so a change re-creates the child and its initializer rebuilds the query.
````

````exercise
id: m37-l05-e3
type: fill-in
prompt: "Complete a view whose query depends on a minimum rating passed in by its parent, newest first."
code: |
  struct RatedBooksList: View {
      [[1]] private var books: [Book]

      init(minimumRating: Int) {
          [[2]] = Query(
              filter: #Predicate<Book> { $0.rating >= minimumRating },
              sort: \Book.addedAt,
              order: [[3]]
          )
      }

      var body: some View {
          List(books) { Text($0.title) }
      }
  }
blanks:
  - id: "1"
    answers: ["@Query"]
  - id: "2"
    answers: ["_books"]
  - id: "3"
    answers: [".reverse"]
solution: |
  ```swift ios
  import SwiftUI
  import SwiftData

  @Model
  final class Book {
      var title: String
      var rating: Int
      var addedAt: Date

      init(title: String, rating: Int, addedAt: Date = .now) {
          self.title = title
          self.rating = rating
          self.addedAt = addedAt
      }
  }

  struct RatedBooksList: View {
      @Query private var books: [Book]

      init(minimumRating: Int) {
          _books = Query(
              filter: #Predicate<Book> { $0.rating >= minimumRating },
              sort: \Book.addedAt,
              order: .reverse
          )
      }

      var body: some View {
          List(books) { Text($0.title) }
      }
  }
  ```

  The property is declared with `@Query` and no arguments; the initializer assigns the wrapper itself through `_books`. The predicate captures `minimumRating`, a constant in scope, which `#Predicate` allows. `order: .reverse` puts the newest first. When the parent passes a different rating, SwiftUI calls this initializer again and the list refetches.
````

````exercise
id: m37-l05-e4
type: find-errors
prompt: "Which of these are real problems?"
code: |
  @MainActor
  @Observable
  final class LibraryViewModel {
      @Query var books: [Book]
  }

  struct LibraryView: View {
      @State private var viewModel = LibraryViewModel()
      let container = try! ModelContainer(for: Book.self)

      var body: some View {
          List(viewModel.books) { Text($0.title) }
              .modelContainer(container)
      }
  }

  #Preview {
      LibraryView()
  }
choices:
  - text: "@Query in an @Observable class doesn't work: it's a dynamic property SwiftUI only fills in for views."
    correct: true
    why: "The class never gets a context or updates."
  - text: "The view creates a ModelContainer in a stored property, so a new container is created whenever the view struct is."
    correct: true
    why: "Create the container once, in the App."
  - text: "The preview uses the view's on-disk container, so previews write to the real store."
    correct: true
    why: "Previews should use an in-memory container."
  - text: "List can't display @Model objects because they're classes."
    correct: false
    why: "@Model classes are Identifiable and Observable; List shows them directly."
rubric:
  - Flags @Query in the class.
  - Flags the container created per view instance.
  - Flags the preview using the on-disk store.
  - Rejects the List claim.
solution: |
  Three real problems. **`@Query` in a class** never runs: move it into the view (`@Query(sort: \Book.title) private var books: [Book]`) and drop the view model, which has nothing else to do. **A container per view instance**: `try! ModelContainer(for:)` runs every time SwiftUI creates `LibraryView`; create it in the `App` and set it on the `WindowGroup`. **The preview** inherits that on-disk container; give it `.modelContainer(for: Book.self, inMemory: true)` or a sample-data container instead.
````

````exercise
id: m37-l05-e5
type: solve
prompt: |
  Pull the editor's rules into a plain struct so they can be tested without SwiftData. Given `final class BookRecord` (standing in for the `@Model`), write `struct BookDraft` with:

  - `var title: String` and `var author: String`;
  - `init(editing book: BookRecord?)`, copying the book's values or starting empty;
  - `let isNew: Bool` (true when no book was given);
  - computed `canSave`: the title has at least one non-space character;
  - `func apply(to book: BookRecord)`, which copies the draft into the book with leading and trailing spaces removed from the title (no Foundation: drop spaces from both ends yourself).

  Then run:

  ```swift
  let book = BookRecord(title: "Dune", author: "Frank Herbert")
  var draft = BookDraft(editing: book)
  print(draft.isNew, draft.title, draft.canSave)
  draft.title = "   "
  print(draft.canSave, book.title)
  draft.title = "  Dune Messiah "
  draft.apply(to: book)
  print("[\(book.title)]", book.author)
  let newDraft = BookDraft(editing: nil)
  print(newDraft.isNew, newDraft.canSave)
  ```

  ```output
  false Dune true
  false Dune
  [Dune Messiah] Frank Herbert
  true false
  ```
starter: |
  final class BookRecord {
      var title: String
      var author: String

      init(title: String, author: String) {
          self.title = title
          self.author = author
      }
  }

  struct BookDraft {
      // title, author, isNew, init(editing:), canSave, apply(to:)
  }
hints:
  - "isNew = (book == nil); title = book?.title ?? \"\"."
  - "canSave: title.contains { $0 != \" \" }."
  - "Trim with drop(while:) on the string and on its reversed() form, then reverse back."
rubric:
  - Copies values in init and sets isNew.
  - canSave rejects empty and all-space titles.
  - apply(to:) trims the title and copies both fields.
  - The book doesn't change until apply(to:).
  - Output matches exactly.
solution: |
  ```swift
  final class BookRecord {
      var title: String
      var author: String

      init(title: String, author: String) {
          self.title = title
          self.author = author
      }
  }

  struct BookDraft {
      var title: String
      var author: String
      let isNew: Bool

      init(editing book: BookRecord?) {
          title = book?.title ?? ""
          author = book?.author ?? ""
          isNew = book == nil
      }

      var canSave: Bool {
          title.contains { $0 != " " }
      }

      func apply(to book: BookRecord) {
          let trimmedStart = title.drop(while: { $0 == " " })
          let trimmed = String(trimmedStart.reversed().drop(while: { $0 == " " }).reversed())
          book.title = trimmed
          book.author = author
      }
  }

  let book = BookRecord(title: "Dune", author: "Frank Herbert")
  var draft = BookDraft(editing: book)
  print(draft.isNew, draft.title, draft.canSave)
  draft.title = "   "
  print(draft.canSave, book.title)
  draft.title = "  Dune Messiah "
  draft.apply(to: book)
  print("[\(book.title)]", book.author)
  let newDraft = BookDraft(editing: nil)
  print(newDraft.isNew, newDraft.canSave)
  ```

  ```output
  false Dune true
  false Dune
  [Dune Messiah] Frank Herbert
  true false
  ```

  Changing the draft never touches the book: after setting the title to spaces, the book is still "Dune". Only `apply(to:)` writes, which in the SwiftUI editor is the Save button. The editor view then holds `@State private var draft: BookDraft`, binds its fields to `$draft.title` and `$draft.author`, and on Save either calls `draft.apply(to: book)` or inserts a new `Book` from the draft. The rules (what counts as savable, how the title is cleaned up) are tested here, with no container at all.
````

````exercise
id: m37-l05-e6
type: design
prompt: "Design the SwiftData side of a journaling app: entries with a date, text, a mood and optional photos; a timeline screen with a search field and a mood filter; an entry editor; a \"this day in past years\" widget-like section on the timeline; and UI tests that need a predictable store. Cover the container, the queries (static and dynamic), editing, where rules live, and previews."
rubric:
  - Container created once in the App, in memory for UI tests via a launch argument; photos stored with external storage.
  - Timeline uses a child view with a dynamic query built in init from the parent's search text and mood filter, via a shared static predicate.
  - The past-years section uses its own query or a FetchDescriptor-based query with a date predicate.
  - The editor works on a draft and inserts or writes back on Save.
  - Rules (mood options, date ranges, draft validation) in model methods, static functions or structs, tested without views; previews use an in-memory container with samples.
solution: |
  - **Container:** `LibraryStore`-style factory in the `App`'s `init`, on disk normally, `isStoredInMemoryOnly: true` with `-ui-testing`, and the UI test inserts its fixtures at launch. `Entry` is `@Model` with `date`, `text`, `mood` (a `Codable` enum) and `@Attribute(.externalStorage) var photo: Data?` (Module 31).
  - **Timeline:** `TimelineScreen` owns `@State searchText` and `@State moodFilter: Mood?`; `EntryList(searchText:mood:)` builds `_entries = Query(filter: Entry.predicate(searchText:mood:), sort: \Entry.date, order: .reverse)` in its initializer.
  - **This day in past years:** a separate view with its own `@Query`, built in `init` from today's month and day, or a date-range predicate per past year. It's independent of the search, so it's its own query, not a filter of the timeline's array.
  - **Editor:** an `EntryDraft` struct (date, text, mood, photo) in `@State`; Save inserts a new `Entry` or applies the draft to the existing one; Cancel discards. Autosave persists Save's changes.
  - **Rules:** `Entry.predicate(...)` and date-range helpers as static functions; draft validation in `EntryDraft`; all testable without SwiftUI, and the predicates with an in-memory container on Apple platforms.
  - **Previews:** a `PreviewJournal.makeContainer()` with a dozen entries across moods and years, and `inMemory: true` for the empty state.
````

## Summary

- Create the `ModelContainer` once in the `App` and set it on the scene; use in-memory configurations for UI tests and previews. The main context autosaves.
- `@Query(filter:sort:)` reads live data in views. Each view queries what it shows; changes anywhere update it.
- For queries that depend on input, keep the input in the parent and build `_items = Query(...)` in the child's initializer. Share predicates as static functions.
- Write through `@Environment(\.modelContext)`: insert, delete, assign. Edit with Cancel through a draft, because autosave can commit live edits before the user cancels.
- `@Query` only works in views; put rules on models or in structs, workflows in services, and give previews an in-memory container with sample data.
