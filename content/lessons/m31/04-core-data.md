---
id: m31-l04
title: Core Data
description: "Read and write Core Data, the framework you'll find in most existing iOS codebases. You build a model, load it with NSPersistentContainer, insert, fetch with predicates and sort descriptors, update, delete and save, follow the rule that every context and its objects belong to one queue, import on a background context with perform and hand results back as object IDs, and see what each merge policy does when two contexts change the same object."
module: m31
order: 4
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l03]
objectives:
  - Name the parts of the Core Data stack and what each one does.
  - Load a persistent container, insert, fetch with NSPredicate and NSSortDescriptor, update, delete and save.
  - Follow Core Data's threading rule, and use object IDs to move references between contexts.
  - Run an import on a background context with perform(schedule:_:) and have the view context pick up the changes.
  - Predict the result of each merge policy when two contexts save conflicting changes to the same object.
terms:
  - term: Managed object model
    definition: "The schema: entities, their attributes and relationships. Usually edited in Xcode's model editor (.xcdatamodeld); an NSManagedObjectModel at runtime."
  - term: NSPersistentContainer
    definition: "The object that sets up the whole stack: it loads the model, creates the persistent store coordinator, loads the stores, and gives you the main-queue viewContext and background contexts."
  - term: Managed object context
    definition: "A scratchpad of model objects. You insert, change and delete objects in a context, and save() writes the changes to the store. Every context is bound to one queue."
  - term: NSManagedObjectID
    definition: "A stable identifier for a managed object. Unlike the object, it's Sendable, so it can cross queues; the receiving context turns it back into an object."
  - term: Merge policy
    definition: "What a context does when it saves an object that another context changed and saved since it was fetched. The default, NSErrorMergePolicy, fails the save."
mastery:
  - Write the code that loads an NSPersistentContainer and fails loudly if the store doesn't load.
  - Fetch with a typed NSFetchRequest, an NSPredicate with format arguments, sort descriptors and a fetch limit.
  - Import data on a background context inside perform, save there, and return object IDs instead of objects.
  - Explain why the compiler rejects capturing a managed object in a perform closure.
  - Choose a merge policy for a background sync and predict which values survive a conflict.
resources: [swift-sendable, swift-book-concurrency]
cards:
  - id: m31-l04-c1
    front: What are the parts of the Core Data stack?
    back: "The managed object model (the schema), the persistent store coordinator (talks to the store files), managed object contexts (where you change objects and save), and NSPersistentContainer, which sets all of them up."
  - id: m31-l04-c2
    front: What's Core Data's threading rule?
    back: "A context is bound to one queue, and so are the objects it fetched. Use viewContext only on the main queue; use a background context only inside its perform. To hand an object to another context, pass its objectID."
  - id: m31-l04-c3
    front: How does Swift 6 help with the threading rule?
    back: "NSManagedObjectContext, NSPersistentContainer and NSManagedObjectID are Sendable; NSManagedObject isn't. perform(schedule:_:) takes a @Sendable closure, so capturing a managed object from another context in it is a compile error."
  - id: m31-l04-c4
    front: What's a context's default merge policy, and what does mergeByPropertyObjectTrump do?
    back: "The default is NSErrorMergePolicy: a save that conflicts with changes saved by another context fails. mergeByPropertyObjectTrump merges property by property, keeping this context's changes and the store's values for everything this context didn't change."
  - id: m31-l04-c5
    front: How do changes saved on a background context reach the UI?
    back: "Set viewContext.automaticallyMergesChangesFromParent = true. After the background context saves, the view context merges the changes, and fetched results controllers or @FetchRequest update."
---

## The idea in one sentence

Core Data keeps an object graph in a store on disk, and you work with it through contexts, each of which is a scratchpad bound to one queue: you change objects in a context, save to write them out, and never let an object leave the queue its context belongs to.

> [!note] Sources and what was run
> Behavior is from Apple's Core Data documentation: "Setting up a Core Data stack", "Using Core Data in the background", the pages for `NSPersistentContainer`, `NSManagedObjectContext`, `NSFetchRequest` and `NSMergePolicy`, and each type's conformance list, read in November 2026. Core Data doesn't exist on Linux, so the Core Data blocks were type-checked against the iOS SDK but not run; their outputs aren't shown. The merge-policy model and the compiler diagnostic come from pure Swift compiled with Swift 6.3.

## The stack

From Apple's "Setting up a Core Data stack":

- **`NSManagedObjectModel`** describes your types: entities, attributes, relationships. You usually design it in Xcode's model editor, in a `.xcdatamodeld` file.
- **`NSPersistentStoreCoordinator`** reads and writes the store files (SQLite by default).
- **`NSManagedObjectContext`** "tracks changes to instances of your app's types". You fetch objects into a context, change them, and `save()` writes the changes through the coordinator.
- **`NSPersistentContainer`** "sets up the model, context, and store coordinator all at once". It's the only one you usually create yourself.

The container gives you contexts of two kinds. `viewContext` is "the main queue's managed object context", for the UI. `newBackgroundContext()` returns a context that "executes on a private queue", for imports and other heavy work.

## A complete example

In an app, the model comes from the Xcode model file and `NSPersistentContainer(name: "Library")` finds it by name. To keep this block self-contained, it builds the same model in code: one `Book` entity with a title, a page count and a read flag.

```swift ios
import CoreData

@objc(Book)
final class Book: NSManagedObject {
    @NSManaged var title: String
    @NSManaged var pages: Int64
    @NSManaged var isRead: Bool
}

func makeLibraryModel() -> NSManagedObjectModel {
    let title = NSAttributeDescription()
    title.name = "title"
    title.type = .string
    title.isOptional = false

    let pages = NSAttributeDescription()
    pages.name = "pages"
    pages.type = .integer64
    pages.defaultValue = 0

    let isRead = NSAttributeDescription()
    isRead.name = "isRead"
    isRead.type = .boolean
    isRead.defaultValue = false

    let book = NSEntityDescription()
    book.name = "Book"
    book.managedObjectClassName = NSStringFromClass(Book.self)
    book.properties = [title, pages, isRead]

    let model = NSManagedObjectModel()
    model.entities = [book]
    return model
}

func makeContainer(inMemory: Bool) -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "Library", managedObjectModel: makeLibraryModel())
    if inMemory {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
    }
    container.loadPersistentStores { _, error in
        if let error {
            fatalError("Couldn't load the store: \(error)")
        }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
}

let container = makeContainer(inMemory: true)
let context = container.viewContext

// Insert
for (title, pages) in [("Dune", 412), ("Neuromancer", 271), ("The Dispossessed", 387)] {
    let book = Book(context: context)
    book.title = title
    book.pages = Int64(pages)
}
if context.hasChanges {
    try context.save()
}

// Fetch with a predicate and a sort order
let request = NSFetchRequest<Book>(entityName: "Book")
request.predicate = NSPredicate(format: "pages >= %@ AND isRead == NO", NSNumber(value: 300))
request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
let longUnread = try context.fetch(request)
print(longUnread.map(\.title))

// Update
longUnread.first?.isRead = true
try context.save()

// Count and delete
let all = NSFetchRequest<Book>(entityName: "Book")
print(try context.count(for: all))
if let neuromancer = try context.fetch(all).first(where: { $0.title == "Neuromancer" }) {
    context.delete(neuromancer)
    try context.save()
}
```

Walking through it:

- **The managed object class.** `@NSManaged` tells Swift that Core Data provides the storage for these properties at runtime. `@objc(Book)` gives the class a stable Objective-C name, which `managedObjectClassName` uses to connect entity and class. With a model file, Xcode can generate this class for you.
- **The model in code** mirrors what the model editor would contain. `NSAttributeDescription.type` (iOS 15 and later) takes values like `.string`, `.integer64` and `.boolean`.
- **Loading the store.** `loadPersistentStores` loads each store description and calls the closure once per store. With the default description, that's a SQLite file in the app's container. The in-memory description is for tests and previews: fast, isolated, and gone when the process ends. If the store doesn't load, the app can't work, so Apple's sample calls `fatalError` "during development"; a shipping app might show an error screen or move the damaged store aside, as lesson 2 did with a file.
- **Insert.** `Book(context:)` creates an object already inserted in that context. Nothing touches the disk yet.
- **Save.** `save()` writes every pending insert, update and delete in the context, all or nothing. Apple's sample checks `hasChanges` first to skip saving when nothing changed.
- **Fetch.** `NSFetchRequest<Book>(entityName:)` is typed, so `fetch` returns `[Book]`. The predicate is an `NSPredicate` format string, with `%@` for each argument. Pass values as arguments, never by building the string with interpolation, for the same reason you don't build SQL that way: a title containing a quote would change the meaning of the query.
- **Update** is assigning to a property, then saving.
- **Count** asks the store without loading objects. **Delete** marks the object deleted in the context; `save()` makes it permanent.

The block prints `["Dune", "The Dispossessed"]` and then `3`, by the logic of the code. Those values weren't produced by a run.

### Fetching less

A fetch request has more knobs than the predicate:

- `fetchLimit` and `fetchOffset` for pages of results.
- `fetchBatchSize`: Apple says that with a nonzero batch size, the fetch records the identities of all matches, but "only data for objects up to the batchSize will be fetched from the persistent store at a time". Use it for long lists.
- `returnsObjectsAsFaults` (default `true`): fetched objects are **faults**, placeholders whose values are filled in from a row cache when you first touch a property. That's why fetching 10,000 objects and reading one property from each is slower than you'd expect.

For UI, two adapters keep results on screen up to date: `NSFetchedResultsController` for UIKit table and collection views, and SwiftUI's `@FetchRequest` property wrapper, which takes sort descriptors and a predicate.

## Contexts and threads

Apple's "Using Core Data in the background" states the rule in two lines:

- "Bind managed object contexts to the thread (queue) that they're initialization on."
- "Bind managed objects that you retrieve from a context to the same queue as the context."

So:

- `viewContext` and its objects: main queue only. In Swift terms, from `@MainActor` code.
- A background context and its objects: only inside that context's `perform`. Apple: "you can only access it through the `perform(_:)` and the `performAndWait(_:)` methods".
- To refer to an object from another queue, pass its **`objectID`** and look it up in the receiving context. Apple: "Don't pass managed object instances between queues. Doing so can result in corruption of the data and termination of the app."

Swift 6 turns most of that into compile errors. Apple's documentation lists `NSManagedObjectContext`, `NSPersistentContainer` and `NSManagedObjectID` as `Sendable`, and doesn't list `NSManagedObject` as `Sendable`. The async `perform(schedule:_:)` (iOS 15 and later) takes a `@Sendable` closure. Here's the same shape with plain Swift stand-ins, so you can see the diagnostic without Core Data:

```swift no-compile capture of 'book' with non-Sendable type 'Book' in a '@Sendable' closure
final class Book {
    var title = ""
}

final class Context: Sendable {
    func perform(_ work: @escaping @Sendable () -> Void) {
        work()
    }
}

func markRead(_ book: Book, using background: Context) {
    background.perform {
        book.title += " (read)"
    }
}
```

Swift 6.3 says:

```text
error: capture of 'book' with non-Sendable type 'Book' in a '@Sendable' closure
```

The context can go into the closure because it's `Sendable`; the book can't, because it isn't. With Core Data, that's exactly the mistake of handing a `viewContext` object to a background context. Pass the `objectID` instead, and fetch the object inside `perform`.

> [!note] What the compiler doesn't catch
> `NSManagedObjectContext` is `Sendable`, so nothing stops you from calling `viewContext.fetch(…)` from a background task. It compiles; it breaks the queue rule. Touch `viewContext` only from `@MainActor` code, and background contexts only inside `perform`.

### Importing on a background context

A large import (thousands of records from Module 30's API) on `viewContext` blocks the main thread for its whole duration. Do it on a background context and send back IDs:

```swift ios
import CoreData

@objc(Book)
final class Book: NSManagedObject {
    @NSManaged var title: String
    @NSManaged var pages: Int64
    @NSManaged var isRead: Bool
}

func makeLibraryModel() -> NSManagedObjectModel {
    let title = NSAttributeDescription()
    title.name = "title"
    title.type = .string

    let pages = NSAttributeDescription()
    pages.name = "pages"
    pages.type = .integer64
    pages.defaultValue = 0

    let isRead = NSAttributeDescription()
    isRead.name = "isRead"
    isRead.type = .boolean
    isRead.defaultValue = false

    let book = NSEntityDescription()
    book.name = "Book"
    book.managedObjectClassName = NSStringFromClass(Book.self)
    book.properties = [title, pages, isRead]

    let model = NSManagedObjectModel()
    model.entities = [book]
    return model
}

struct BookRecord: Sendable {
    let title: String
    let pages: Int
}

func importBooks(_ records: [BookRecord], into container: NSPersistentContainer) async throws -> [NSManagedObjectID] {
    let context = container.newBackgroundContext()
    context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    return try await context.perform {
        var inserted: [Book] = []
        for record in records {
            let book = Book(context: context)
            book.title = record.title
            book.pages = Int64(record.pages)
            inserted.append(book)
        }
        try context.save()
        return inserted.map(\.objectID)
    }
}

let container = NSPersistentContainer(name: "Library", managedObjectModel: makeLibraryModel())
let description = NSPersistentStoreDescription()
description.type = NSInMemoryStoreType
container.persistentStoreDescriptions = [description]
container.loadPersistentStores { _, error in
    if let error { fatalError("Couldn't load the store: \(error)") }
}
container.viewContext.automaticallyMergesChangesFromParent = true

let ids = try await importBooks(
    [BookRecord(title: "Dune", pages: 412), BookRecord(title: "Kindred", pages: 264)],
    into: container)

// Back on the main actor: turn IDs into viewContext objects.
let viewContext = container.viewContext
let imported = ids.compactMap { try? viewContext.existingObject(with: $0) as? Book }
print(imported.map(\.title))
```

- `newBackgroundContext()` creates a private-queue context. Make one per job, not one per app: a context accumulates every object it touches.
- `perform` runs the closure on the context's queue and returns its value to the caller. Everything that touches `Book` objects happens inside. The input arrives as `BookRecord` values, which are `Sendable` structs.
- After `save()`, the objects have permanent IDs, and the closure returns `[NSManagedObjectID]`, which can cross back to the main actor.
- `existingObject(with:)` returns the object for that ID in `viewContext`, or throws if it no longer exists.
- `automaticallyMergesChangesFromParent` on `viewContext` makes it pick up the background context's save, so lists showing books update without a refetch.

`NSPersistentContainer.performBackgroundTask(_:)` is the shortcut: it creates a background context and runs your closure on its queue. For bulk inserts of thousands of rows, `NSBatchInsertRequest` (iOS 13 and later) writes directly to the store without creating managed objects, which is much faster but bypasses the contexts, so views don't see the rows until they refetch or merge them.

## When two contexts change the same object

An import saves on a background context while the person edits the same book on `viewContext`. When `viewContext` saves, its copy is older than the store's. What happens depends on the context's `mergePolicy`, and Apple's documentation says the default is `NSErrorMergePolicy`: the save fails.

The documented policies, as a model you can run. It compares, property by property, the values the context fetched (`original`), its edits (`inMemory`) and what another context saved since (`inStore`):

```swift
typealias Record = [String: String]

enum MergePolicy: CaseIterable {
    case error, mergeByPropertyObjectTrump, mergeByPropertyStoreTrump, overwrite, rollback
}

struct MergeConflict: Error {}

/// A model of the documented behavior, property by property.
/// original: the values this context fetched. inMemory: this context's edited copy.
/// inStore: what another context has saved since.
func resolve(original: Record, inMemory: Record, inStore: Record,
             policy: MergePolicy) throws -> Record {
    guard inStore != original else { return inMemory }   // nobody else changed it: no conflict
    var result: Record = [:]
    for key in original.keys {
        let mine = inMemory[key] != original[key]
        let theirs = inStore[key] != original[key]
        switch policy {
        case .error:
            throw MergeConflict()
        case .mergeByPropertyObjectTrump:
            result[key] = mine ? inMemory[key] : inStore[key]
        case .mergeByPropertyStoreTrump:
            result[key] = theirs ? inStore[key] : inMemory[key]
        case .overwrite:
            result[key] = inMemory[key]
        case .rollback:
            result[key] = inStore[key]
        }
    }
    return result
}

func describe(_ record: Record) -> String {
    record.keys.sorted().map { "\($0)=\(record[$0]!)" }.joined(separator: " ")
}

let original: Record = ["title": "Dune", "rating": "3", "isRead": "false"]
var inMemory = original
inMemory["rating"] = "5"                 // this context: the person rates the book
var inStore = original
inStore["rating"] = "4"                  // a background sync saved a rating...
inStore["isRead"] = "true"               // ...and marked it read

for policy in MergePolicy.allCases {
    do {
        let saved = try resolve(original: original, inMemory: inMemory, inStore: inStore, policy: policy)
        print("\(policy): \(describe(saved))")
    } catch {
        print("\(policy): save fails with a merge conflict")
    }
}
```

```output
error: save fails with a merge conflict
mergeByPropertyObjectTrump: isRead=true rating=5 title=Dune
mergeByPropertyStoreTrump: isRead=true rating=4 title=Dune
overwrite: isRead=false rating=5 title=Dune
rollback: isRead=true rating=4 title=Dune
```

How each line follows from Apple's description:

- **`error`** (the default): the save fails. Apple says the conflicting object IDs are in the error's `userInfo`.
- **`mergeByPropertyObjectTrump`**: merges "by individual property, with in-memory changes trumping external changes". The person's rating of 5 wins; the sync's `isRead = true` is kept because this context didn't touch it.
- **`mergeByPropertyStoreTrump`**: the same merge with "external changes trumping in-memory changes". The sync's rating wins.
- **`overwrite`**: "saving the entire in-memory object". The rating is 5, but `isRead` goes back to `false`: the sync's change is silently lost. That's why `overwrite` is rarely what you want.
- **`rollback`**: "discarding unsaved changes". The person's rating disappears.

This is a model of the documented behavior, not Core Data's implementation; it ignores relationships and the cases where the store's copy was deleted. The choice it illustrates is real: for a background sync, `mergeByPropertyObjectTrump` on the context that holds the person's edits is a common starting point, because their edits win only on the properties they actually changed. Lesson 6 looks at conflicts between devices, where the same choices come back.

## Common mistakes

> [!error] Passing a managed object to another queue
> Apple: "Don't pass managed object instances between queues." Pass `objectID` and look it up with `existingObject(with:)` in the receiving context. Swift 6 rejects the capture inside `perform`, but not every path goes through `perform`.

> [!error] Using a background context outside perform
> `let context = container.newBackgroundContext()` followed by `context.fetch(request)` on whatever thread you happen to be on breaks the queue rule. Every use of a private-queue context goes inside `perform` or `performAndWait`.

> [!error] Large imports on viewContext
> Inserting 5,000 objects on the main queue freezes the UI. Import on a background context, save there, and let `automaticallyMergesChangesFromParent` bring the result to `viewContext`.

> [!error] Leaving the default merge policy with concurrent writers
> With two contexts writing the same objects, `NSErrorMergePolicy` makes saves fail at random-looking moments. Choose a policy on purpose, per context, and test the conflict.

> [!error] Building predicates with string interpolation
> `NSPredicate(format: "title == '\(title)'")` breaks on a title with a quote and can change the query's meaning. Use `%@` placeholders and pass the values as arguments.

> [!error] Ignoring the loadPersistentStores error
> A store that failed to load leaves every fetch and save failing later, far from the cause. Check the error in the completion handler.

## Exercises

````exercise
id: m31-l04-e1
type: prediction
prompt: "The lesson's merge-policy model with a different conflict: both contexts changed the title. What does the program print?"
code: |
  typealias Record = [String: String]

  enum MergePolicy: CaseIterable {
      case mergeByPropertyObjectTrump, mergeByPropertyStoreTrump, overwrite, rollback
  }

  func resolve(original: Record, inMemory: Record, inStore: Record, policy: MergePolicy) -> Record {
      guard inStore != original else { return inMemory }
      var result: Record = [:]
      for key in original.keys {
          let mine = inMemory[key] != original[key]
          let theirs = inStore[key] != original[key]
          switch policy {
          case .mergeByPropertyObjectTrump: result[key] = mine ? inMemory[key] : inStore[key]
          case .mergeByPropertyStoreTrump: result[key] = theirs ? inStore[key] : inMemory[key]
          case .overwrite: result[key] = inMemory[key]
          case .rollback: result[key] = inStore[key]
          }
      }
      return result
  }

  let original: Record = ["title": "Dune", "note": ""]
  var inMemory = original
  inMemory["title"] = "Dune (1965)"
  inMemory["note"] = "Reread"
  var inStore = original
  inStore["title"] = "Dune: Deluxe Edition"

  for policy in MergePolicy.allCases {
      let saved = resolve(original: original, inMemory: inMemory, inStore: inStore, policy: policy)
      print("\(policy): \(saved["title"]!) [\(saved["note"]!)]")
  }
output: |
  mergeByPropertyObjectTrump: Dune (1965) [Reread]
  mergeByPropertyStoreTrump: Dune: Deluxe Edition [Reread]
  overwrite: Dune (1965) [Reread]
  rollback: Dune: Deluxe Edition []
solution: |
  Both sides changed `title`; only this context changed `note`.

  - **Object trump**: this context's changes win where it made them: its title and its note.
  - **Store trump**: the store wins where it changed something (the title); this context's note survives because the store didn't touch it.
  - **Overwrite**: the in-memory object is saved whole. Here that gives the same result as object trump, because the store changed nothing that this context didn't also change.
  - **Rollback**: this context's changes are discarded, so the note goes back to empty: `[]`.

  ```output
  mergeByPropertyObjectTrump: Dune (1965) [Reread]
  mergeByPropertyStoreTrump: Dune: Deluxe Edition [Reread]
  overwrite: Dune (1965) [Reread]
  rollback: Dune: Deluxe Edition []
  ```
````

````exercise
id: m31-l04-e2
type: comprehension
prompt: "A background import finishes and wants to tell the main actor which books it created, so the UI can scroll to the first one. What should it hand over?"
choices:
  - text: "The books' NSManagedObjectID values, which the main actor resolves in viewContext."
    correct: true
    why: "Object IDs are Sendable and valid in any context of the same container once saved."
  - text: "The Book objects themselves, since the import already saved them."
    correct: false
    why: "Saving doesn't change which queue an object belongs to. They still belong to the background context."
  - text: "The background context, so the UI can read the books from it."
    correct: false
    why: "The context is Sendable, but using a private-queue context outside its perform breaks the threading rule."
  - text: "Nothing: the UI should refetch everything from scratch."
    correct: false
    why: "It works, but it's slower and loses the information about which books are new."
solution: |
  The IDs. Apple's guidance is to "use NSManagedObjectID instances" when a reference must move between queues. After the background save, the IDs are permanent; the main actor calls `viewContext.existingObject(with:)` to get its own `Book` objects for them.
````

````exercise
id: m31-l04-e3
type: fill-in
prompt: "Complete the fetch: the 20 most recently added unread books whose title contains the search text, ignoring case and diacritics."
code: |
  let request = NSFetchRequest<Book>(entityName: "Book")
  request.predicate = NSPredicate(format: "isRead == NO AND title CONTAINS[cd] %@", [[1]])
  request.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: [[2]])]
  request.[[3]] = 20
  let results = try context.[[4]](request)
blanks:
  - id: "1"
    answers: ["searchText"]
  - id: "2"
    answers: ["false"]
  - id: "3"
    answers: ["fetchLimit"]
  - id: "4"
    answers: ["fetch"]
solution: |
  The search text is passed as an argument to `%@`, never interpolated into the format string. `[cd]` makes `CONTAINS` case- and diacritic-insensitive. "Most recently added" is a descending sort, so `ascending: false`. `fetchLimit` caps the result at 20, and `fetch(_:)` with a typed request returns `[Book]`.
````

````exercise
id: m31-l04-e4
type: find-errors
prompt: "A sync service written for Core Data. Which lines break the rules from the lesson?"
code: |
  final class SyncService {
      let container: NSPersistentContainer

      init(container: NSPersistentContainer) { self.container = container }

      func sync(_ records: [BookRecord], selected: Book) async throws {
          let background = container.newBackgroundContext()
          let existing = try background.fetch(NSFetchRequest<Book>(entityName: "Book"))   // (a)

          try await background.perform {
              for record in records {
                  let book = Book(context: background)
                  book.title = record.title
              }
              try background.save()
          }

          selected.isRead = true                                   // (b)
          try container.viewContext.save()                         // (c)
          print(existing.count)
      }
  }
choices:
  - text: "(a) fetches on the background context outside perform."
    correct: true
    why: "A private-queue context may only be used inside perform or performAndWait."
  - text: "(b) and (c) change a viewContext object and save viewContext from a nonisolated async function."
    correct: true
    why: "viewContext belongs to the main queue. This function isn't main-actor isolated, so it may run anywhere."
  - text: "Inserting with Book(context: background) inside perform."
    correct: false
    why: "That's correct: the object is created on the background context's queue, inside perform."
  - text: "Calling save() inside perform."
    correct: false
    why: "Also correct: the save happens on the context's own queue."
rubric:
  - Flags the fetch outside perform.
  - Flags the viewContext object change and save from a nonisolated function.
  - Accepts the insert and save inside perform.
solution: |
  (a) uses the background context outside `perform`; move the fetch inside it. (b) and (c) touch `viewContext` and its object from a function that isn't on the main actor; mark that part `@MainActor` (or hop with `await MainActor.run`), or better, pass the selected book's `objectID` and set `isRead` in the background context too. The insert and save inside `perform` are exactly right.
````

````exercise
id: m31-l04-e5
type: solve
prompt: "Write `func markAllRead(in container: NSPersistentContainer) async throws -> Int` that marks every unread book as read on a background context and returns how many it changed. Use the lesson's `Book` class and model. The function must not touch viewContext or pass a managed object out of perform."
starter: |
  import CoreData

  // Book and makeLibraryModel() from the lesson.

  func markAllRead(in container: NSPersistentContainer) async throws -> Int {
      // ...
  }
rubric:
  - Creates a background context and does all work inside perform.
  - Fetches only unread books with a predicate.
  - Saves only when something changed and returns the count, an Int.
  - Doesn't touch viewContext or return managed objects.
solution: |
  Everything that touches `Book` happens inside `perform`, and only an `Int` comes out. This block was type-checked against the iOS SDK, not run.

  ```swift ios
  import CoreData

  @objc(Book)
  final class Book: NSManagedObject {
      @NSManaged var title: String
      @NSManaged var isRead: Bool
  }

  func markAllRead(in container: NSPersistentContainer) async throws -> Int {
      let context = container.newBackgroundContext()
      return try await context.perform {
          let request = NSFetchRequest<Book>(entityName: "Book")
          request.predicate = NSPredicate(format: "isRead == NO")
          let unread = try context.fetch(request)
          for book in unread {
              book.isRead = true
          }
          if context.hasChanges {
              try context.save()
          }
          return unread.count
      }
  }
  ```

  If `viewContext` has `automaticallyMergesChangesFromParent` set, the UI picks up the change after the save. For hundreds of thousands of rows, `NSBatchUpdateRequest` updates the store directly without loading objects, at the cost of having to merge the changes into contexts yourself.
````

````exercise
id: m31-l04-e6
type: explain
prompt: "Explain why Core Data gives you a main-queue viewContext and separate background contexts, instead of one context you can use from anywhere. Refer to the lines below."
code: |
  let viewContext = container.viewContext                 // main queue
  viewContext.automaticallyMergesChangesFromParent = true

  let importContext = container.newBackgroundContext()    // private queue
  try await importContext.perform {
      // insert thousands of books
      try importContext.save()
  }
rubric:
  - A context and its objects aren't thread-safe; each is bound to one queue.
  - The UI needs a context on the main queue so views can read objects directly.
  - Heavy work (imports, batch changes) on the main queue blocks the UI, so it needs its own private-queue context.
  - Changes reach the view context by merging after the background save; object IDs carry references across.
solution: |
  A context and the objects it holds aren't safe to use from several threads at once, so Core Data binds each context to one queue. The UI reads objects constantly from the main thread, so it needs a context bound to the main queue: `viewContext`, whose objects views can use directly. Heavy work on that same context would run on the main queue and freeze the UI, so imports and batch changes get their own private-queue contexts, each running its work inside `perform`. The two meet through the store: the background context saves, the view context merges the saved changes (`automaticallyMergesChangesFromParent`), and when one needs to point at a specific object in the other, it passes the object's ID. One shared context would need a lock around every property access, which is exactly what the queue rule avoids.
````

## Summary

- `NSPersistentContainer` sets up the model, the store coordinator and the stores, and gives you `viewContext` plus background contexts.
- Insert with `Entity(context:)`, change properties, delete with `delete(_:)`, and `save()` to write all of it at once. Fetch with a typed `NSFetchRequest`, an `NSPredicate` with `%@` arguments and sort descriptors.
- A context and its objects belong to one queue. Use `viewContext` from the main actor, background contexts inside `perform`, and pass `objectID` across.
- Swift 6 helps: contexts and object IDs are `Sendable`, managed objects aren't, and `perform`'s closure is `@Sendable`.
- Import on a background context, save there, and set `automaticallyMergesChangesFromParent` on `viewContext` so the UI sees the result.
- The default merge policy fails conflicting saves. `mergeByPropertyObjectTrump` keeps this context's changed properties and the store's values for the rest; `overwrite` silently discards the other side's changes.
