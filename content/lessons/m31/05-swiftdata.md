---
id: m31-l05
title: SwiftData
description: "Persist a model with SwiftData, the framework for new apps on iOS 17. You turn classes into models with @Model, shape attributes and relationships with @Attribute and @Relationship, set up a ModelContainer, insert, fetch with FetchDescriptor and #Predicate, save and delete through a ModelContext, show live results in SwiftUI with @Query, and move imports off the main actor with a model actor that hands back persistent identifiers."
module: m31
order: 5
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l04]
objectives:
  - Define models with @Model, and customize them with @Attribute, @Relationship and @Transient.
  - Create a ModelContainer, configure it with ModelConfiguration, and use its main context.
  - Insert, fetch, count, update and delete with ModelContext, FetchDescriptor, #Predicate and SortDescriptor.
  - Explain what a predicate can contain, and what the #Predicate macro rejects at compile time.
  - Display and filter live results in SwiftUI with @Query.
  - Run imports in a @ModelActor and pass PersistentIdentifier values, not model objects, back to the main actor.
terms:
  - term: "@Model"
    definition: "The SwiftData macro that turns a class into a persistent model. It adds PersistentModel and Observable conformance, and every stored property becomes a persisted attribute unless marked @Transient."
  - term: ModelContainer
    definition: "The object that owns the schema and the store. Created once per app with the model types (and optionally a ModelConfiguration and a migration plan)."
  - term: ModelContext
    definition: "The object you insert, fetch, change and delete models through, and that saves changes to the container's store. container.mainContext is bound to the main actor and saves automatically."
  - term: FetchDescriptor
    definition: "A value describing a fetch: a predicate, sort descriptors, a fetch limit and offset. Passed to ModelContext.fetch(_:) or fetchCount(_:)."
  - term: "#Predicate"
    definition: "A Foundation macro that turns a closure into a Predicate value at compile time. SwiftData translates it into a query on its store."
  - term: PersistentIdentifier
    definition: "A model's persistentModelID: a Sendable, Codable identifier you pass between actors and turn back into a model with ModelContext.model(for:)."
mastery:
  - Write two related @Model classes with an inverse relationship and a cascade delete rule.
  - Create an in-memory ModelContainer for tests and previews.
  - Write a FetchDescriptor with a #Predicate that captures local constants, a sort order and a fetch limit.
  - Predict which values a predicate matches, including optional properties.
  - Write a @ModelActor that imports records, saves, and returns persistent identifiers.
resources: [swiftdata, swiftdata-modelcontext, swiftdata-modelactor, foundation-predicate, swift-actor, swift-sendable, swift-book-concurrency]
cards:
  - id: m31-l05-c1
    front: What does @Model add to a class?
    back: "Conformance to PersistentModel (so SwiftData can store it and build a schema from it) and Observable (so SwiftUI updates when it changes). All non-computed stored properties are persisted unless marked @Transient."
  - id: m31-l05-c2
    front: Which context saves automatically?
    back: "container.mainContext (and the one SwiftUI puts in the environment): Apple says it periodically checks for unsaved changes and saves them. Contexts you create yourself, including a model actor's, have autosave off unless you set autosaveEnabled; call save()."
  - id: m31-l05-c3
    front: What may a #Predicate closure contain?
    back: "Comparisons, arithmetic, Boolean logic, optionals (?, ??, if-let), casts, some sequence operations (contains, filter, allSatisfy…), and string checks like contains(_:) and localizedStandardContains(_:). It can read constants from the enclosing scope. Anything else, like calling lowercased(), is a compile error from the macro."
  - id: m31-l05-c4
    front: How do you get a model created in a @ModelActor to the main actor?
    back: "Save in the actor, return the models' persistentModelID values (PersistentIdentifier is Sendable), and on the main actor call mainContext.model(for:) for each ID."
  - id: m31-l05-c5
    front: What does @Attribute(.unique) do when you insert a duplicate?
    back: "Apple's earthquake sample: on save, if a stored model has the same unique value, SwiftData updates that model with the new values instead of adding a second one. That makes insert work as an upsert."
---

## The idea in one sentence

SwiftData lets your model classes be the schema: mark them `@Model`, give a `ModelContainer` their types, then insert, fetch with Swift predicates and save through a `ModelContext`, with one context per actor and identifiers, never models, crossing between them.

> [!note] Sources and what was run
> API names, signatures and availability come from Apple's SwiftData documentation JSON (`Model()`, `ModelContainer`, `ModelContext`, `FetchDescriptor`, `Query`, `ModelActor`, `Relationship`, `Attribute`), the articles "Preserving your app's model data across launches", "Defining data relationships with enumerations and model classes", "Filtering and sorting persistent data" and "Maintaining a local copy of server data", and Foundation's `Predicate`, all read in November 2026. Every API used here is marked iOS 17.0 or earlier. SwiftData doesn't exist on Linux: its blocks were type-checked against the iOS SDK (iOS 17 deployment target) but not run, so their outputs aren't shown. The predicate blocks use Foundation's `Predicate` on plain structs, which was compiled and run with Swift 6.3.

## Models

A model is a class marked `@Model`. Apple's description: the macro adds conformance to `PersistentModel`, "which SwiftData uses to examine the class and generate an internal schema", and to `Observable`, which "enables change tracking". By default SwiftData stores "all noncomputed properties of a class as long as they use compatible types": basic types like `Bool`, `Int` and `String`, and `Codable` structs and enums.

```swift ios
import Foundation
import SwiftData

@Model
final class Shelf {
    @Attribute(.unique) var name: String
    @Relationship(deleteRule: .cascade, inverse: \Book.shelf)
    var books: [Book] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Book {
    var title: String
    var pages: Int
    var isRead: Bool
    var addedAt: Date
    var shelf: Shelf?
    @Attribute(.externalStorage) var coverImage: Data?
    @Transient var isSelected = false

    init(title: String, pages: Int, isRead: Bool = false, addedAt: Date = .now) {
        self.title = title
        self.pages = pages
        self.isRead = isRead
        self.addedAt = addedAt
    }
}
```

The macros on properties:

- **`@Attribute(.unique)`**: no two shelves can have the same name. Other options include `.externalStorage` (store large data in a separate file; used here for cover images), `.spotlight`, `.allowsCloudEncryption` and `originalName:` for renames (lesson 6).
- **`@Relationship(deleteRule:inverse:)`**: a shelf has many books; each book has one optional shelf. `inverse: \Book.shelf` tells SwiftData the two properties are the two ends of the same relationship, so setting `book.shelf = sciFi` also puts the book in `sciFi.books`. The default delete rule is `.nullify`: deleting a shelf would set its books' `shelf` to `nil`. With `.cascade`, deleting a shelf deletes its books. The other rules are `.deny` and `.noAction`.
- **`@Transient`**: not persisted. Apple's example is the current weather at a trip's destination; here, selection state.

A property whose type is another model (`Shelf?`, `[Book]`) is a relationship even without the macro; you add `@Relationship` to change the delete rule or name the inverse.

## Container and context

```swift ios
import Foundation
import SwiftData

@Model
final class Shelf {
    @Attribute(.unique) var name: String
    @Relationship(deleteRule: .cascade, inverse: \Book.shelf)
    var books: [Book] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class Book {
    var title: String
    var pages: Int
    var isRead: Bool
    var shelf: Shelf?

    init(title: String, pages: Int, isRead: Bool = false) {
        self.title = title
        self.pages = pages
        self.isRead = isRead
    }
}

// Tests and previews: in memory. The app: ModelContainer(for: Shelf.self, Book.self).
let container = try ModelContainer(
    for: Shelf.self, Book.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let context = container.mainContext

// Insert
let sciFi = Shelf(name: "Sci-fi")
context.insert(sciFi)
for (title, pages) in [("Dune", 412), ("Neuromancer", 271), ("The Dispossessed", 387)] {
    let book = Book(title: title, pages: pages)
    context.insert(book)
    book.shelf = sciFi
}
try context.save()

// Fetch with a predicate, a sort order and a limit
let minimumPages = 300
var longUnread = FetchDescriptor<Book>(
    predicate: #Predicate<Book> { book in
        book.pages >= minimumPages && !book.isRead
    },
    sortBy: [SortDescriptor(\Book.title)])
longUnread.fetchLimit = 10
let results = try context.fetch(longUnread)
print(results.map(\.title))

// Follow a relationship inside a predicate
let onSciFi = FetchDescriptor<Book>(predicate: #Predicate<Book> { book in
    book.shelf?.name == "Sci-fi"
})
print(try context.fetchCount(onSciFi))

// Update: change the object; the context tracks it
results.first?.isRead = true

// Delete: the cascade rule removes the shelf's books too
context.delete(sciFi)
try context.save()
print(try context.fetchCount(FetchDescriptor<Book>()))
```

Line by line:

- **`ModelContainer(for:configurations:)`** takes the model types. Apple notes you can leave out types reachable through relationships, since SwiftData "automatically traverses a model's relationships". `ModelConfiguration(isStoredInMemoryOnly: true)` is for tests and previews; without a configuration, the store goes in the app's Application Support directory.
- **`mainContext`** is `@MainActor`. Apple says it "periodically checks whether it contains unsaved changes, and if so, implicitly saves those changes". The explicit `save()` calls here make the moment of saving visible; in an app you can rely on autosave for UI edits and call `save()` when you need the data on disk now.
- **`insert(_:)`** starts tracking a model. Each book is inserted, then `book.shelf = sciFi` sets the relationship; because of the inverse, `sciFi.books` now contains it too.
- **`FetchDescriptor`** takes a `Predicate` and an array of `SortDescriptor`; `fetchLimit` and `fetchOffset` page through results. `fetch(_:)` returns `[Book]`; `fetchCount(_:)` counts without loading the models.
- **The predicate** captures `minimumPages`, a local constant. Foundation's documentation: a predicate "can refer to constants that are in scope". The closure isn't run as Swift code; the macro turns it into a description that SwiftData translates into a store query.
- **`book.shelf?.name == "Sci-fi"`** follows a relationship, with optional chaining, inside the query.
- **Update** is assignment. `@Model` tracks the change; the next save writes it.
- **Delete** with `delete(_:)`. Because the relationship's rule is `.cascade`, the shelf's three books go too, and the final count is 0.

By the logic of the code, it prints `["Dune", "The Dispossessed"]`, `3` and `0`; this block was type-checked, not run.

For bulk deletes there's `delete(model:where:includeSubclasses:)`, which takes a predicate, and `transaction(block:)` runs several changes and saves them together.

### Unique attributes make insert an upsert

Apple's "Maintaining a local copy of server data" sample stores earthquakes with `@Attribute(.unique) var code: String` and inserts every downloaded quake, new or not. On save, SwiftData "checks if the specified earthquake's code parameter matches the code of an earthquake that's already in the store. If so, the framework updates the stored earthquake's other parameters using the values in the specified one. Otherwise, the framework adds a new earthquake to the store."

```swift ios
import Foundation
import SwiftData

@Model
final class Quake {
    @Attribute(.unique) var code: String
    var magnitude: Double

    init(code: String, magnitude: Double) {
        self.code = code
        self.magnitude = magnitude
    }
}

let container = try ModelContainer(
    for: Quake.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let context = container.mainContext

context.insert(Quake(code: "ci4021", magnitude: 3.1))
try context.save()

// A later download reports a revised magnitude for the same event.
context.insert(Quake(code: "ci4021", magnitude: 3.4))
try context.save()

print(try context.fetchCount(FetchDescriptor<Quake>()))
```

Per Apple's description, there's one quake afterward, with magnitude 3.4. This relies on the server giving each record a stable unique key; the sample states that assumption too. Lesson 6 covers what to do when the device also edits the records it downloads.

## What a predicate can contain

`#Predicate` comes from Foundation, not SwiftData, so you can try predicates on plain structs, without a store. Foundation's documentation lists what the closure may use: arithmetic, comparisons, `&&`, `||` and `!`, the ternary operator, optionals (`?`, `??`, `!`, `flatMap(_:)`, if-let), casts, some sequence operations (`contains`, `filter`, `allSatisfy`, `starts(with:)`, `min`, `max`), member access and subscripts, and four string checks: `contains(_:)`, `localizedStandardContains(_:)`, `caseInsensitiveCompare(_:)` and `localizedCompare(_:)`. No loops, no nested declarations, no changing outside variables.

```swift
import Foundation

struct BookRow {
    let title: String
    let pages: Int
    let isRead: Bool
    let shelf: String?
}

let rows = [
    BookRow(title: "Dune", pages: 412, isRead: true, shelf: "Sci-fi"),
    BookRow(title: "Neuromancer", pages: 271, isRead: false, shelf: "Sci-fi"),
    BookRow(title: "The Dispossessed", pages: 387, isRead: false, shelf: nil),
    BookRow(title: "Middlemarch", pages: 880, isRead: false, shelf: "Classics"),
]

if #available(macOS 14, iOS 17, *) {
    let minimumPages = 300
    let longUnread = #Predicate<BookRow> { book in
        book.pages >= minimumPages && !book.isRead
    }
    let onSciFiShelf = #Predicate<BookRow> { book in
        book.shelf == "Sci-fi"
    }
    let titleMatch = #Predicate<BookRow> { book in
        book.title.contains("Dis")
    }

    print(try rows.filter { try longUnread.evaluate($0) }.map(\.title))
    print(try rows.filter { try onSciFiShelf.evaluate($0) }.map(\.title))
    print(try rows.filter { try titleMatch.evaluate($0) }.map(\.title))
}
```

```output
["The Dispossessed", "Middlemarch"]
["Dune", "Neuromancer"]
["The Dispossessed"]
```

- `evaluate(_:)` runs a predicate against one value. SwiftData doesn't do this; it translates the predicate into a query. Running it here shows you what the predicate means.
- Comparing an optional `String?` with `"Sci-fi"` works without unwrapping, as in Swift: `nil` doesn't match.
- `contains(_:)` is case-sensitive. For a search field, use `localizedStandardContains(_:)`, which ignores case and diacritics the way Finder's search does. It's part of Foundation on Apple platforms, so it isn't used in this block, which also runs on Linux.
- The `#available` check is there because `Predicate` is iOS 17 and macOS 14 API; inside an iOS 17 app, you don't need it.

The macro rejects anything outside the list at compile time:

```swift no-compile is not supported in this predicate
import Foundation

struct BookRow {
    let title: String
}

if #available(macOS 14, iOS 17, *) {
    let search = #Predicate<BookRow> { book in
        book.title.lowercased() == "dune"
    }
    print(search)
}
```

Swift 6.3 reports:

```text
error: The lowercased() function is not supported in this predicate (from macro 'Predicate')
```

The fix is to say what you mean with a supported operation: `book.title.localizedStandardContains("dune")` for a search, or `caseInsensitiveCompare(_:)` for equality ignoring case.

> [!warning] Type-checks isn't the same as works
> A predicate that compiles can still fail when SwiftData runs the fetch, if the store can't express it (a predicate on a `@Transient` property, for instance, has no column to query). `fetch(_:)` throws in that case. Cover every fetch your app makes with a test against an in-memory container.

## @Query in SwiftUI

You'll build SwiftUI screens from Module 34; here's the shape, because it's how most SwiftData apps read data. `@Query` fetches models and "manages those models so they remain in sync with the underlying data": when anything inserts, changes or deletes a matching model, the view updates.

```swift ios
import SwiftUI
import SwiftData

@Model
final class Book {
    var title: String
    var isRead: Bool

    init(title: String, isRead: Bool = false) {
        self.title = title
        self.isRead = isRead
    }
}

struct UnreadBooksView: View {
    @Query(filter: #Predicate<Book> { !$0.isRead }, sort: \Book.title)
    private var books: [Book]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(books) { book in
            Text(book.title)
                .swipeActions {
                    Button("Mark read") { book.isRead = true }
                }
        }
        .toolbar {
            Button("Add") { context.insert(Book(title: "Untitled")) }
        }
    }
}

struct SearchResultsView: View {
    @Query private var books: [Book]

    init(searchText: String) {
        _books = Query(
            filter: #Predicate<Book> { book in
                searchText.isEmpty || book.title.localizedStandardContains(searchText)
            },
            sort: \Book.title)
    }

    var body: some View {
        List(books) { book in
            Text(book.title)
        }
    }
}

struct LibraryRoot: View {
    var body: some View {
        UnreadBooksView()
            .modelContainer(for: Book.self)
    }
}
```

- `.modelContainer(for:)` creates the container and puts its main context in the environment, where `@Environment(\.modelContext)` reads it. Apple recommends adding it "at the very top of the view hierarchy".
- `@Query(filter:sort:)` takes a predicate and a key path to sort by. Marking a book read changes it, it no longer matches, and it leaves the list with no extra code.
- For a filter that depends on input, assign `_books = Query(…)` in the initializer, as Apple's earthquake sample does. When the search text changes, SwiftUI calls the initializer again and the query is rebuilt.
- Insertions go through the context; the main context's autosave writes them.

Module 37 goes further with SwiftData and SwiftUI: previews with in-memory containers, editing flows, undo.

## Background work with a model actor

`mainContext` is bound to the main actor, and a large import on it blocks the UI, exactly as with Core Data's `viewContext`. The same rule applies: one context per actor, models stay with their context, identifiers cross.

`ModelContext` isn't `Sendable` (its documentation lists no `Sendable` conformance), while `ModelContainer` and `PersistentIdentifier` are. The `@ModelActor` macro turns an actor into one that owns its own context on the container you give it:

```swift ios
import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var pages: Int

    init(title: String, pages: Int) {
        self.title = title
        self.pages = pages
    }
}

struct BookRecord: Sendable {
    let title: String
    let pages: Int
}

@ModelActor
actor BookImporter {
    func importBooks(_ records: [BookRecord]) throws -> [PersistentIdentifier] {
        var inserted: [Book] = []
        for record in records {
            let book = Book(title: record.title, pages: record.pages)
            modelContext.insert(book)
            inserted.append(book)
        }
        try modelContext.save()
        return inserted.map(\.persistentModelID)
    }

    func totalPages() throws -> Int {
        try modelContext.fetch(FetchDescriptor<Book>()).reduce(0) { $0 + $1.pages }
    }
}

let container = try ModelContainer(
    for: Book.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let importer = BookImporter(modelContainer: container)

let ids = try await importer.importBooks([
    BookRecord(title: "Dune", pages: 412),
    BookRecord(title: "Kindred", pages: 264),
])
print(try await importer.totalPages())

// On the main actor: turn identifiers into models of the main context.
let imported = ids.compactMap { container.mainContext.model(for: $0) as? Book }
print(imported.map(\.title))
```

- `@ModelActor` generates the actor's `modelContainer`, its model executor, and an initializer that takes the container: `BookImporter(modelContainer:)`. Inside, `modelContext` is a context that belongs to this actor.
- The input is `[BookRecord]`, plain `Sendable` structs. The output is `[PersistentIdentifier]` and an `Int`. No `Book` object leaves the actor.
- The actor's context doesn't autosave (Apple: for contexts you create yourself, set `autosaveEnabled` to get that behavior), so `importBooks` calls `save()`. Without it, the main context wouldn't see the books.
- `model(for:)` on the main context returns that context's instance for each identifier.

The macro-generated initializer isn't listed as a separate symbol in Apple's documentation (the macro's declaration only says it generates an `init`), so the iOS type-check of this block is what verifies the `modelContainer:` label.

> [!note] Why identifiers, even if models compile across actors
> Recent SDKs declare `@Model` classes `Sendable`, so passing a `Book` between actors may compile. The reason not to is the same as Core Data's: a model object belongs to the context that loaded it, and reading or changing it from another actor bypasses that context. An identifier is valid in every context of the container.

## Common mistakes

> [!error] Forgetting save() in a context you created
> `mainContext` autosaves; a `@ModelActor`'s context and `ModelContext(container)` don't, unless you set `autosaveEnabled`. Inserts that are never saved vanish when the actor goes away, and the UI never sees them.

> [!error] Returning models from a model actor
> Return `persistentModelID` values or plain `Sendable` structs. A model returned from the actor still belongs to the actor's context.

> [!error] Doing an import on mainContext
> Decoding and inserting thousands of records on the main actor freezes scrolling. Use a `@ModelActor`.

> [!error] Expecting a relationship without an inverse to stay consistent
> Name the inverse with `@Relationship(inverse:)` on one side, so assigning `book.shelf` and appending to `shelf.books` describe the same link.

> [!error] Assuming the default delete rule removes children
> The default is `.nullify`: deleting a shelf leaves its books with `shelf == nil`. If the books can't exist without the shelf, say `.cascade`.

> [!error] Using iOS 18 SwiftData APIs on an iOS 17 target
> `#Unique`, `#Index`, history (`fetchHistory(_:)`) and custom `DataStore`s are iOS 18.0 and later. Without `if #available`, the build fails or, worse, you design around a feature that doesn't exist on part of your audience's devices.

## Exercises

````exercise
id: m31-l05-e1
type: prediction
prompt: "Predicates over a struct with an optional property. What does the program print?"
code: |
  import Foundation

  struct Note {
      let text: String
      let pageNumber: Int?
  }

  let notes = [
      Note(text: "Opening", pageNumber: 1),
      Note(text: "Spice", pageNumber: 120),
      Note(text: "General thought", pageNumber: nil),
  ]

  if #available(macOS 14, iOS 17, *) {
      let firstHundred = #Predicate<Note> { note in
          (note.pageNumber ?? 0) > 0 && (note.pageNumber ?? 0) <= 100
      }
      let withPage = #Predicate<Note> { note in
          note.pageNumber != nil
      }
      let hasLowercaseO = #Predicate<Note> { note in
          note.text.contains("o")
      }
      print(try notes.filter { try firstHundred.evaluate($0) }.map(\.text))
      print(try notes.filter { try withPage.evaluate($0) }.count)
      print(try notes.filter { try hasLowercaseO.evaluate($0) }.map(\.text))
  }
output: |
  ["Opening"]
  2
  ["General thought"]
solution: |
  - `firstHundred`: a missing page becomes 0 through `??`, which fails `> 0`. Page 1 passes, page 120 fails `<= 100`. Only `Opening`.
  - `withPage`: two notes have a page number.
  - `hasLowercaseO`: `contains(_:)` is case-sensitive. "Opening" has a capital O and no lowercase one; "Spice" has none; "General thought" has one in "thought".

  ```output
  ["Opening"]
  2
  ["General thought"]
  ```

  For a search field, that case-sensitivity is a bug; `localizedStandardContains(_:)` is the predicate-safe fix.
````

````exercise
id: m31-l05-e2
type: comprehension
prompt: "A Shelf model has `@Relationship(inverse: \\Book.shelf) var books: [Book] = []` with no delete rule. You delete a shelf that holds three books and save. What happens to the books?"
choices:
  - text: "They stay in the store, with shelf set to nil."
    correct: true
    why: "The default delete rule is .nullify."
  - text: "They're deleted with the shelf."
    correct: false
    why: "That's .cascade, which you have to ask for."
  - text: "The delete fails because books still refer to the shelf."
    correct: false
    why: "That's .deny."
  - text: "The books keep pointing at the deleted shelf."
    correct: false
    why: "Nullify exists to prevent exactly that: references to the deleted model are cleared."
solution: |
  Apple's relationships article: "Because the default value for the deleteRule parameter is nullify, you can create the relationship without explicitly specifying the delete rule." Nullify sets each book's `shelf` to `nil`. Choose `.cascade` when the children can't exist without the parent (a book's notes), and keep `.nullify` when they can (books outliving a shelf).
````

````exercise
id: m31-l05-e3
type: fill-in
prompt: "Complete the fetch: the 20 most recently added unread books, newest first."
code: |
  var descriptor = FetchDescriptor<Book>(
      predicate: [[1]]<Book> { book in
          !book.isRead
      },
      sortBy: [SortDescriptor(\Book.addedAt, order: .[[2]])])
  descriptor.[[3]] = 20
  let recent = try context.[[4]](descriptor)
blanks:
  - id: "1"
    answers: ["#Predicate"]
  - id: "2"
    answers: ["reverse"]
  - id: "3"
    answers: ["fetchLimit"]
  - id: "4"
    answers: ["fetch"]
solution: |
  `#Predicate<Book>` builds the predicate, `.reverse` sorts newest first (`SortOrder` has `.forward` and `.reverse`), `fetchLimit` caps the results, and `fetch(_:)` returns `[Book]`. `descriptor` is a `var` because `fetchLimit` is set after initialization; `FetchDescriptor` is a struct.
````

````exercise
id: m31-l05-e4
type: find-errors
prompt: "A model actor that imports books and reports them to the UI. Which are real problems?"
code: |
  @ModelActor
  actor Importer {
      func run(_ records: [BookRecord]) throws -> [Book] {
          var books: [Book] = []
          for record in records {
              let book = Book(title: record.title, pages: record.pages)
              modelContext.insert(book)
              books.append(book)
          }
          return books
      }
  }

  @MainActor
  func refresh(container: ModelContainer, records: [BookRecord]) async throws {
      let importer = Importer(modelContainer: container)
      let books = try await importer.run(records)
      for book in books {
          container.mainContext.insert(book)
      }
  }
choices:
  - text: "run returns Book models instead of persistent identifiers."
    correct: true
    why: "The models belong to the actor's context. Return persistentModelID values and look them up on the main context."
  - text: "run never calls save(), and the actor's context doesn't autosave."
    correct: true
    why: "The inserts stay pending in the actor's context and never reach the store."
  - text: "Inserting the actor's models into mainContext."
    correct: true
    why: "A model already belongs to another context. The main context should look up the saved models by identifier."
  - text: "Creating Book objects inside the actor."
    correct: false
    why: "That's the point of the actor: it creates and inserts models in its own context, off the main actor."
rubric:
  - Flags returning model objects across the actor boundary.
  - Flags the missing save.
  - Flags inserting another context's models into the main context.
solution: |
  Fix all three together: call `try modelContext.save()` at the end of `run`, return `books.map(\.persistentModelID)`, and on the main actor use `container.mainContext.model(for:)` for each identifier. Nothing needs to be inserted on the main side; the models are already in the store.
````

````exercise
id: m31-l05-e5
type: solve
prompt: "Write `bookFilter(searchText:unreadOnly:) -> Predicate<BookRow>` for a search screen: an empty search matches every title; otherwise the title must contain the text (case-sensitive `contains` is fine here, so it runs on Linux); when `unreadOnly` is true, read books are excluded. Test it on three rows (Dune, read; Dune Messiah, unread; Neuromancer, unread) with these inputs: (\"\", false), (\"Dune\", false), (\"Dune\", true), (\"\", true), (\"Kindred\", false)."
starter: |
  import Foundation

  struct BookRow {
      let title: String
      let pages: Int
      let isRead: Bool
  }

  @available(macOS 14, iOS 17, *)
  func bookFilter(searchText: String, unreadOnly: Bool) -> Predicate<BookRow> {
      // ...
  }
rubric:
  - Builds one predicate that captures both parameters as constants.
  - Expresses "empty search matches all" and "unread only when asked" with Boolean logic inside the predicate, not with if statements outside choosing between predicates.
  - Uses only operations the predicate macro supports.
  - Prints the five results.
solution: |
  Both conditions are expressed as "either the filter is off, or the row passes it", which keeps it one predicate. That matters with SwiftData: one predicate means one `@Query` or `FetchDescriptor`, whatever the inputs.

  ```swift
  import Foundation

  struct BookRow {
      let title: String
      let pages: Int
      let isRead: Bool
  }

  @available(macOS 14, iOS 17, *)
  func bookFilter(searchText: String, unreadOnly: Bool) -> Predicate<BookRow> {
      #Predicate<BookRow> { book in
          (searchText.isEmpty || book.title.contains(searchText))
              && (!unreadOnly || !book.isRead)
      }
  }

  let rows = [
      BookRow(title: "Dune", pages: 412, isRead: true),
      BookRow(title: "Dune Messiah", pages: 256, isRead: false),
      BookRow(title: "Neuromancer", pages: 271, isRead: false),
  ]

  if #available(macOS 14, iOS 17, *) {
      for (text, unread) in [("", false), ("Dune", false), ("Dune", true), ("", true), ("Kindred", false)] {
          let filter = bookFilter(searchText: text, unreadOnly: unread)
          let titles = try rows.filter { try filter.evaluate($0) }.map(\.title)
          print("\"\(text)\" unread=\(unread): \(titles)")
      }
  }
  ```

  ```output
  "" unread=false: ["Dune", "Dune Messiah", "Neuromancer"]
  "Dune" unread=false: ["Dune", "Dune Messiah"]
  "Dune" unread=true: ["Dune Messiah"]
  "" unread=true: ["Dune Messiah", "Neuromancer"]
  "Kindred" unread=false: []
  ```

  `searchText.isEmpty` refers only to a captured constant, which predicates allow. In the app, swap `contains` for `localizedStandardContains` and pass the result to `Query(filter:sort:)` in the view's initializer, as the lesson's `SearchResultsView` does.
````

````exercise
id: m31-l05-e6
type: explain
prompt: "In a SwiftUI app with SwiftData, a teammate asks why the list below updates by itself after a background import, but only if the importer calls save(). Explain the path a change takes from the model actor to the screen."
code: |
  @ModelActor
  actor BookImporter {
      func importBooks(_ records: [BookRecord]) throws {
          for record in records {
              modelContext.insert(Book(title: record.title, pages: record.pages))
          }
          try modelContext.save()      // remove this line and the list never changes
      }
  }

  struct AllBooksView: View {
      @Query(sort: \Book.title) private var books: [Book]
      var body: some View {
          List(books) { Text($0.title) }
      }
  }
rubric:
  - The actor's context holds inserted models in memory until save() writes them to the container's store.
  - Without save(), nothing reaches the store, so other contexts can't see the models.
  - After the save, the main context sees the change in the store, and @Query, which keeps its results in sync with the store, refetches or updates.
  - The view re-renders because its @Query results changed.
solution: |
  Each context is a scratchpad. When the model actor inserts books, they exist only in the actor's context. `save()` writes them to the container's store, which is shared by every context of that container. Until then, the main context has nothing to see.

  After the save, the change is in the store. `@Query` in the view is documented to keep its models "in sync with the underlying data", so it picks up the new books, its results change, and SwiftUI re-renders the list. The actor never talks to the view, and no model object crosses from the actor to the main actor: the store is the meeting point, which is the same design as Core Data's background context plus `automaticallyMergesChangesFromParent`.
````

## Summary

- `@Model` turns a class into a persistent, observable model. `@Attribute` adjusts one property (`.unique`, `.externalStorage`, `originalName:`), `@Relationship` sets the delete rule and the inverse, `@Transient` opts out of storage.
- A `ModelContainer` gets the model types and an optional `ModelConfiguration` (in memory for tests). `mainContext` belongs to the main actor and autosaves; contexts you create don't.
- Insert with `insert(_:)`, fetch with a `FetchDescriptor` (predicate, sort, limit), count with `fetchCount(_:)`, delete with `delete(_:)`, and `save()`. With `@Attribute(.unique)`, inserting a duplicate key updates the stored model.
- `#Predicate` accepts a documented set of operations and captured constants, and rejects the rest at compile time. A predicate can still fail at fetch time if the store can't express it, so test your fetches.
- `@Query` keeps a SwiftUI view's results in sync with the store; rebuild it in the initializer for filters that depend on input.
- Do imports in a `@ModelActor`, save there, and pass `PersistentIdentifier` values back. The main context turns them into its own models.
