---
id: m31-l06
title: Migrations, caching and sync
description: "Keep persisted data working as the app changes and as it leaves the device. You plan schema changes as lightweight or custom migrations in Core Data (including iOS 17 staged migrations) and SwiftData (VersionedSchema and SchemaMigrationPlan), migrate your own file formats step by step, build a memory-plus-disk cache with expiry and an injected clock, and design offline-first sync with an outbox, server versions and explicit conflict strategies."
module: m31
order: 6
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l05]
objectives:
  - Say which Core Data model changes lightweight migration can infer, and use a staged migration for one it can't.
  - Version a SwiftData schema with VersionedSchema and migrate it with a SchemaMigrationPlan of lightweight and custom stages.
  - Migrate a versioned file format with one tested transform per version step, and refuse versions the app doesn't know.
  - Build a two-level cache (memory and disk) with expiry, tested with explicit times instead of the real clock.
  - Design offline-first sync with a local source of truth for the UI, an outbox, server-assigned versions and a conflict strategy chosen per field.
terms:
  - term: Lightweight migration
    definition: "A migration the framework infers from the difference between two model versions (adding an attribute, renaming one with a renaming identifier or originalName, making a required attribute optional). No migration code."
  - term: Custom migration stage
    definition: "A migration step where your code runs before or after the store moves to the next version, to fix data that an inferred migration can't handle: filling missing values, removing duplicates."
  - term: Outbox
    definition: "A persisted list of local changes not yet accepted by the server. The UI shows local state including them; sync sends them and removes each one only when the server accepts it."
  - term: Optimistic concurrency
    definition: "Writing with the version you based your change on. The server accepts the write only if that's still the current version; otherwise it reports a conflict, and the client merges and retries."
  - term: Three-way merge
    definition: "Resolving a conflict by comparing both edited copies with the common base they started from, so each side's actual changes can be kept field by field."
mastery:
  - Classify a set of Core Data model changes as inferable or not, and write the staged migration for "optional becomes required".
  - Write VersionedSchema enums for two versions and a SchemaMigrationPlan with a custom stage that cleans data before a unique constraint.
  - Write a file loader that reads the version first, applies each step in order and throws for a future version.
  - Predict which reads of a memory-plus-disk cache come from memory, from disk or miss, given the times.
  - Explain why server versions beat device timestamps for ordering writes, and pick a strategy per field for a conflict.
resources: [coredata-staged-migrations, swiftdata-schemamigrationplan, foundation-nscache, swift-actor, swift-testing-docs]
cards:
  - id: m31-l06-c1
    front: Which Core Data changes can lightweight migration infer?
    back: "Per Apple: adding or removing an attribute, making a required attribute optional, making an optional attribute required with a default value, and renaming an entity or property with a renaming identifier. Also adding, removing or renaming relationships and changing to-one to to-many."
  - id: m31-l06-c2
    front: How do you make an optional Core Data attribute required when existing rows have nil?
    back: "A staged migration (iOS 17): an NSCustomMigrationStage whose willMigrateHandler fills the nil values while the store is still on the old model, followed by the lightweight step. Register it with NSStagedMigrationManager under NSPersistentStoreStagedMigrationManagerOptionKey."
  - id: m31-l06-c3
    front: How does SwiftData describe schema versions and migrations?
    back: "Each version is an enum conforming to VersionedSchema (versionIdentifier and models, with the models nested inside). A SchemaMigrationPlan lists the schemas in order and the stages between them: MigrationStage.lightweight or .custom with willMigrate and didMigrate closures. Pass the plan to ModelContainer."
  - id: m31-l06-c4
    front: Why not order sync writes by device timestamps?
    back: "Device clocks are wrong by seconds or minutes, so a later write from a slow clock loses to an earlier one. Let the server order writes: a version number per record, and writes that must name the version they're based on."
  - id: m31-l06-c5
    front: What does a three-way merge need, and what does it give you?
    back: "The base (the last version both sides agreed on), the local edit and the remote edit. Comparing each side with the base shows who changed what, so non-overlapping changes are both kept and only real collisions need a rule."
---

## The idea in one sentence

Data on disk outlives the code that wrote it and copies of it live on other devices, so every store needs a plan for reading old versions (migrations), every cache needs a rule for when a copy is too old (expiry), and every synced record needs a rule for when two copies disagree (conflict resolution).

> [!note] Sources and what was run
> Core Data facts come from Apple's "Migrating your data model automatically", "Staged migrations" and the pages for `NSPersistentStoreDescription`, `NSStagedMigrationManager`, `NSCustomMigrationStage` and `NSManagedObjectModelReference`; SwiftData's from `VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage` and `Attribute(_:originalName:hashModifier:)`. All read in November 2026. The Core Data and SwiftData blocks were type-checked against the iOS SDK, not run. The file migration, cache and sync code is pure Swift, compiled and run with Swift 6.3; the cache writes only to a temporary folder. Xcode menu names weren't checked in Xcode.

## Why migrations exist

Version 1 of the app saved books with a `pages` field. Version 2 calls it `pageCount`. On the day version 2 ships, every device still has version 1's data, and the new code has to read it. A **migration** turns data in the old shape into the new one, once, when the new version first opens the store.

Two kinds, in every framework:

- **Lightweight (inferred).** The framework compares the old and new schema and works out the change itself: a new optional field, a removed field, a rename you've declared. No code from you.
- **Custom.** The change needs a decision only your code can make: what value goes into a new required field, which of two duplicates to keep, how to split one field into two.

## Core Data

### Lightweight migration

Apple's "Migrating your data model automatically" lists what can be inferred:

- adding or removing an attribute,
- a non-optional attribute becoming optional,
- an optional attribute becoming non-optional, "and defining a default value",
- renaming an entity or property, by setting the **renaming identifier** in the new model to the old name,
- adding, removing or renaming relationships, and changing to-one to to-many, or unordered to ordered,
- adding, removing and renaming entities in a hierarchy (but not merging hierarchies).

You don't have to turn it on with `NSPersistentContainer`: `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically` on `NSPersistentStoreDescription` are both documented as `true` by default. What you do have to do is **keep the old model**. In Xcode, you add a model version to the `.xcdatamodeld` (Editor › Add Model Version), edit the new version and mark it current. Core Data needs both the store's model and the current one to work out the difference. Editing the only version in place leaves existing stores that no longer match any model, and loading them fails.

### Staged migrations (iOS 17)

Apple's example of a change lightweight migration can't do: "if you change an optional attribute to be nonoptional, there's no way for a lightweight migration to infer the default value it needs to assign to any instances of that attribute with a nil value." Staged migrations, new in iOS 17, split such a change into stages and let you run code in between.

Here a rating goes from optional in version 1 to required in version 2, with no default. A custom stage fills the missing ratings while the store is still on version 1; then the lightweight step can run. The models are built in code so the block stands alone; in an app, they're versions of your model file.

```swift ios
import CoreData

func bookModel(ratingIsOptional: Bool) -> NSManagedObjectModel {
    let title = NSAttributeDescription()
    title.name = "title"
    title.type = .string

    let rating = NSAttributeDescription()
    rating.name = "rating"
    rating.type = .integer64
    rating.isOptional = ratingIsOptional

    let book = NSEntityDescription()
    book.name = "Book"
    book.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
    book.properties = [title, rating]

    let model = NSManagedObjectModel()
    model.entities = [book]
    return model
}

nonisolated func makeMigrationManager(from v1: NSManagedObjectModel,
                                      to v2: NSManagedObjectModel) -> NSStagedMigrationManager {
    let stage = NSCustomMigrationStage(
        migratingFrom: NSManagedObjectModelReference(model: v1, versionChecksum: v1.versionChecksum),
        to: NSManagedObjectModelReference(model: v2, versionChecksum: v2.versionChecksum))

    // Runs while the store still uses v1: give every book a rating before it becomes required.
    stage.willMigrateHandler = { manager, _ in
        guard let container = manager.container else { return }
        let context = container.newBackgroundContext()
        try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Book")
            request.predicate = NSPredicate(format: "rating == nil")
            for book in try context.fetch(request) {
                book.setValue(0, forKey: "rating")
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }
    return NSStagedMigrationManager([stage])
}

let v1 = bookModel(ratingIsOptional: true)
let v2 = bookModel(ratingIsOptional: false)

let container = NSPersistentContainer(name: "Library", managedObjectModel: v2)
container.persistentStoreDescriptions.first?.setOption(
    makeMigrationManager(from: v1, to: v2),
    forKey: NSPersistentStoreStagedMigrationManagerOptionKey)
container.loadPersistentStores { _, error in
    if let error { print("Migration failed: \(error)") }
}
```

- `NSManagedObjectModelReference` names a model version by its `versionChecksum` (iOS 17). With model files, you'd use `init(name:in:versionChecksum:)` and copy the checksums Xcode shows for each version.
- `willMigrateHandler` runs before the stage moves the store to the next model; `didMigrateHandler`, after. Apple's description: they give you "opportunities … to prepare the persistent store before each stage runs, and perform any cleanup afterward".
- Inside, `manager.container` gives access to the migrating store. The work goes in a background context, inside `performAndWait`, following lesson 4's rules.
- The stages go into `NSStagedMigrationManager`, which is passed as a store option under `NSPersistentStoreStagedMigrationManagerOptionKey`.
- `makeMigrationManager` is `nonisolated` on purpose. Core Data calls the handler on its own thread, so the closure must not be created in main-actor code, where Swift would consider it main-actor isolated.

Apple adds that staged migrations "require a distinct migration stage for each model version", so a store three versions behind runs three stages in order. Changes that fit no stage model at all (splitting one entity into two, say) need a manual migration with a mapping model; Apple's "Manual migrations" covers it.

## SwiftData

SwiftData expresses the same ideas in Swift types. Each schema version is a type conforming to **`VersionedSchema`**, with its models nested inside; a **`SchemaMigrationPlan`** lists the versions in order and the **`MigrationStage`** between each pair: `.lightweight(fromVersion:toVersion:)` or `.custom(fromVersion:toVersion:willMigrate:didMigrate:)`.

The change here: version 2 renames `pages` to `pageCount` (lightweight, with `originalName`) and makes `isbn` unique, which would fail on a store that already contains two books with the same ISBN. The custom stage removes duplicates first:

```swift ios
import Foundation
import SwiftData

enum LibrarySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Book.self] }

    @Model
    final class Book {
        var isbn: String
        var title: String
        var pages: Int

        init(isbn: String, title: String, pages: Int) {
            self.isbn = isbn
            self.title = title
            self.pages = pages
        }
    }
}

enum LibrarySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Book.self] }

    @Model
    final class Book {
        @Attribute(.unique) var isbn: String
        var title: String
        @Attribute(originalName: "pages") var pageCount: Int

        init(isbn: String, title: String, pageCount: Int) {
            self.isbn = isbn
            self.title = title
            self.pageCount = pageCount
        }
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LibrarySchemaV1.self, LibrarySchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: LibrarySchemaV1.self,
        toVersion: LibrarySchemaV2.self,
        willMigrate: { context in
            // Still on V1: keep the first book for each ISBN, delete the rest.
            let books = try context.fetch(FetchDescriptor<LibrarySchemaV1.Book>(
                sortBy: [SortDescriptor(\LibrarySchemaV1.Book.title)]))
            var seen = Set<String>()
            for book in books where !seen.insert(book.isbn).inserted {
                context.delete(book)
            }
            try context.save()
        },
        didMigrate: nil)
}

// The rest of the app uses the current version's model under a plain name.
typealias Book = LibrarySchemaV2.Book

let container = try ModelContainer(for: Book.self, migrationPlan: LibraryMigrationPlan.self)
```

- **Each version is a separate type.** Version 1's `Book` stays in the code, frozen, after version 2 ships. The migration plan needs both to know what the store looks like and what it should become. `Schema.Version(1, 0, 0)` is a major, minor, patch triple.
- **`@Attribute(originalName: "pages")`** tells SwiftData that `pageCount` is the old `pages`, so the rename is inferred and values carry over. Without it, SwiftData sees a removed attribute and a new one, and every page count is lost.
- **`willMigrate`** receives a context on the **old** schema, so it fetches `LibrarySchemaV1.Book`. `didMigrate` (unused here) receives a context on the new one. Both closures are `@Sendable`.
- **The `typealias`** keeps the rest of the app writing `Book`; the next version changes one line.
- **Ordering:** `schemas` lists every version oldest first, and `stages` has one stage per adjacent pair. A store on version 1 opened by an app on version 4 runs stages 1→2, 2→3 and 3→4 in order.

A plan with only additions of optional attributes and renames can use `.lightweight(fromVersion:toVersion:)` stages throughout. You still need the versioned schemas, so start with `VersionedSchema` from version 1: retrofitting it after shipping means reconstructing what version 1 looked like.

## Your own file formats

Lesson 2's JSON file put `schemaVersion` in from the start. Here's what it's for. Each version has its own `Codable` type, each step is a function from one version to the next, and the loader reads the version first, decodes that version's type and applies the remaining steps in order:

```swift
import Foundation

// Version 1: {"schemaVersion": 1, "books": [{"title": "...", "pages": 412, "isRead": true}]}
struct LibraryV1: Codable {
    struct Book: Codable { let title: String; let pages: Int; let isRead: Bool }
    let books: [Book]
}

// Version 2 renamed pages to pageCount.
struct LibraryV2: Codable {
    struct Book: Codable { let title: String; let pageCount: Int; let isRead: Bool }
    let books: [Book]
}

// Version 3 (current) replaced isRead with a status and added an id.
struct Library: Codable {
    enum Status: String, Codable { case unread, reading, finished }
    struct Book: Codable { let id: Int; let title: String; let pageCount: Int; let status: Status }
    static let currentVersion = 3
    var schemaVersion = Library.currentVersion
    let books: [Book]
}

enum MigrationError: Error, Equatable {
    case unsupportedVersion(Int)
}

private struct VersionProbe: Decodable {
    let schemaVersion: Int
}

func migrate(_ v1: LibraryV1) -> LibraryV2 {
    LibraryV2(books: v1.books.map { .init(title: $0.title, pageCount: $0.pages, isRead: $0.isRead) })
}

func migrate(_ v2: LibraryV2) -> Library {
    Library(books: v2.books.enumerated().map { index, book in
        .init(id: index + 1, title: book.title, pageCount: book.pageCount,
              status: book.isRead ? .finished : .unread)
    })
}

func loadLibrary(from data: Data) throws -> Library {
    let decoder = JSONDecoder()
    let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
    switch version {
    case 1: return migrate(migrate(try decoder.decode(LibraryV1.self, from: data)))
    case 2: return migrate(try decoder.decode(LibraryV2.self, from: data))
    case 3: return try decoder.decode(Library.self, from: data)
    default: throw MigrationError.unsupportedVersion(version)
    }
}

let files = [
    #"{"schemaVersion": 1, "books": [{"title": "Dune", "pages": 412, "isRead": true}]}"#,
    #"{"schemaVersion": 2, "books": [{"title": "Kindred", "pageCount": 264, "isRead": false}]}"#,
    #"{"schemaVersion": 3, "books": [{"id": 7, "title": "Beloved", "pageCount": 324, "status": "reading"}]}"#,
    #"{"schemaVersion": 4, "books": []}"#,
]

for file in files {
    do {
        let library = try loadLibrary(from: Data(file.utf8))
        for book in library.books {
            print("v\(library.schemaVersion): #\(book.id) \(book.title), \(book.pageCount) pages, \(book.status)")
        }
    } catch {
        print("Can't open: \(error)")
    }
}
```

```output
v3: #1 Dune, 412 pages, finished
v3: #1 Kindred, 264 pages, unread
v3: #7 Beloved, 324 pages, reading
Can't open: unsupportedVersion(4)
```

The design decisions:

- **Old types are frozen.** `LibraryV1` never changes again, even when `Library` does. Each step function is small and testable on its own: feed it a V1 fixture, check the V2 result.
- **Steps chain.** A version 1 file goes through both steps. When version 4 arrives, you add `LibraryV3` (the current `Library`, renamed and frozen), one function from V3 to the new `Library`, and one `case` per version; no older step changes.
- **Missing information gets an explicit decision.** Version 3 needs an `id`, which version 2 never had. The step numbers books by position. That's a product decision, written in one place and covered by a test.
- **A newer version than the app knows is an error, not a guess.** It happens when someone restores a backup from a newer app version onto an older one, or when a file syncs from a device with a newer version. Throw, and don't save over the file (lesson 2): the newer app can still read it.
- After a successful load, save in the current format so the steps run only once.

## Caching with expiry

Module 30's repository kept API responses in an in-memory actor with a freshness window. Two things change when you want the cache to survive a relaunch: there's a disk level, and entries carry the time they were stored, so a copy read back days later can be recognized as old.

```swift
import Foundation

struct CacheEntry<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let storedAt: Date
}

enum CacheLookup<Value: Sendable>: Sendable {
    case memory(Value)
    case disk(Value)
    case miss
}

actor TwoLevelCache<Value: Codable & Sendable> {
    private var memory: [String: CacheEntry<Value>] = [:]
    private let directory: URL
    private let maxAge: TimeInterval

    init(directory: URL, maxAge: TimeInterval) {
        self.directory = directory
        self.maxAge = maxAge
    }

    func value(for key: String, now: Date) -> CacheLookup<Value> {
        if let entry = memory[key] {
            if isFresh(entry, now: now) { return .memory(entry.value) }
            remove(key)
            return .miss
        }
        guard let data = try? Data(contentsOf: fileURL(for: key)),
              let entry = try? JSONDecoder().decode(CacheEntry<Value>.self, from: data) else {
            return .miss
        }
        guard isFresh(entry, now: now) else {
            remove(key)
            return .miss
        }
        memory[key] = entry          // promote, so the next read skips the disk
        return .disk(entry.value)
    }

    func insert(_ value: Value, for key: String, now: Date) throws {
        let entry = CacheEntry(value: value, storedAt: now)
        memory[key] = entry
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(entry).write(to: fileURL(for: key), options: .atomic)
    }

    func remove(_ key: String) {
        memory[key] = nil
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    private func isFresh(_ entry: CacheEntry<Value>, now: Date) -> Bool {
        now.timeIntervalSince(entry.storedAt) < maxAge
    }

    private func fileURL(for key: String) -> URL {
        let safeName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "_"
        return directory.appending(path: safeName + ".json")
    }
}

func describe(_ lookup: CacheLookup<[String]>) -> String {
    switch lookup {
    case .memory(let value): return "memory \(value)"
    case .disk(let value): return "disk \(value)"
    case .miss: return "miss"
    }
}

// A throwaway folder standing in for Library/Caches.
let folder = FileManager.default.temporaryDirectory.appending(path: "m31-cache-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: folder) }

let start = Date(timeIntervalSince1970: 1_700_000_000)
func minute(_ n: Double) -> Date { start.addingTimeInterval(n * 60) }

let cache = TwoLevelCache<[String]>(directory: folder, maxAge: 10 * 60)
print(describe(await cache.value(for: "shelf/sci-fi", now: minute(0))))
try await cache.insert(["Dune", "Kindred"], for: "shelf/sci-fi", now: minute(0))
print(describe(await cache.value(for: "shelf/sci-fi", now: minute(5))))

// The app relaunches: a new cache instance, same folder, empty memory.
let relaunched = TwoLevelCache<[String]>(directory: folder, maxAge: 10 * 60)
print(describe(await relaunched.value(for: "shelf/sci-fi", now: minute(6))))
print(describe(await relaunched.value(for: "shelf/sci-fi", now: minute(7))))
print(describe(await relaunched.value(for: "shelf/sci-fi", now: minute(10))))
print(describe(await relaunched.value(for: "shelf/sci-fi", now: minute(11))))
```

```output
miss
memory ["Dune", "Kindred"]
disk ["Dune", "Kindred"]
memory ["Dune", "Kindred"]
miss
miss
```

Line by line through the output:

- Minute 0: nothing stored, `miss`. Then the value is inserted in memory and on disk.
- Minute 5: fresh, from memory.
- Minute 6, new instance: memory is empty, the disk copy is 6 minutes old, so it's fresh. It's returned and **promoted** to memory.
- Minute 7: from memory, thanks to the promotion.
- Minute 10: exactly 10 minutes old; `< maxAge` fails, so it's expired. The entry is removed from both levels.
- Minute 11: gone, `miss`.

What to notice:

- **Time is a parameter.** The cache never calls `Date()`. The app passes `Date()`; the demo passes fixed minutes, so expiry is tested without waiting. Module 30 injected a clock function instead; either way, the code under test doesn't read the real clock.
- **The disk copy carries its own timestamp.** Without `storedAt` in the file, a copy read after a week offline would look as fresh as one written a minute ago.
- **Failures read as misses.** A missing, unreadable or undecodable file returns `.miss`, because a cache is never the only copy (lesson 1). In the app, `directory` is under `URL.cachesDirectory`, where the system may delete files anyway.
- **Keys become safe file names.** Percent-encoding keeps `/` in `"shelf/sci-fi"` from creating folders.

Production additions, not shown: a size limit (the memory level could be an `NSCache`, which evicts under memory pressure, as Module 27's image cache did), periodic cleanup of expired files, and a "stale but usable" result, so that Module 30's repository can show old data while it refreshes or when the network fails.

## Offline-first sync

**Offline-first** means the UI reads and writes the local store, always, and a sync engine reconciles the local store with the server in the background. The person can edit on the subway; the edits wait in an **outbox** and go out when the network returns.

The parts:

1. **Local store** (SwiftData or Core Data): what the UI shows, including unsynced edits.
2. **Outbox**: each local change, persisted, in order. A change leaves the outbox only when the server accepts it.
3. **Push**: send the outbox. Each write says which server version it's based on.
4. **Pull**: fetch changes since the last sync cursor (Module 30's cursor pagination) and apply them locally.
5. **Conflict resolution**: when the server says "that's not the current version", merge and retry.

### Who wrote last? Don't ask the device clock

"Last writer wins" sounds simple until you ask who was last. Device clocks drift and can be set by hand. If the tablet's clock is 5 minutes slow, its write made 2 minutes after the phone's carries an earlier timestamp, and loses. Exercise 1 makes that concrete. The fix is to let the **server** order writes: it keeps a version number per record, and a write must name the version it was based on. A write based on an old version is a conflict, reported to the client, never silently applied. That's **optimistic concurrency**, and it's the same idea as Core Data's merge conflicts in lesson 4, across devices instead of contexts.

### The push loop

The model below has a server with versioned records and two devices with outboxes. The phone edits offline; the tablet syncs first; then the phone comes back online:

```swift
struct Note: Equatable {
    var text: String
    var pagesRead: Int
}

struct Versioned {
    var note: Note
    var version: Int
}

enum PushResult {
    case accepted(version: Int)
    case conflict(current: Versioned)
}

/// The server keeps a version number per record and rejects writes based on an old one.
final class Server {
    private(set) var record: Versioned

    init(_ note: Note) { record = Versioned(note: note, version: 1) }

    func push(_ note: Note, basedOn version: Int) -> PushResult {
        guard version == record.version else { return .conflict(current: record) }
        record = Versioned(note: note, version: record.version + 1)
        return .accepted(version: record.version)
    }
}

enum Change {
    case setText(String)
    case setPagesRead(Int)
}

/// The device's side: what it last synced, plus an outbox of local changes not yet accepted.
struct Replica {
    var synced: Versioned
    var outbox: [Change] = []

    var current: Note {
        outbox.reduce(synced.note) { note, change in apply(change, to: note) }
    }

    mutating func edit(_ change: Change) { outbox.append(change) }
}

func apply(_ change: Change, to note: Note) -> Note {
    var note = note
    switch change {
    case .setText(let text): note.text = text
    case .setPagesRead(let pages): note.pagesRead = max(note.pagesRead, pages)
    }
    return note
}

func sync(_ replica: inout Replica, with server: Server) {
    guard !replica.outbox.isEmpty else { return }
    for attempt in 1...3 {
        switch server.push(replica.current, basedOn: replica.synced.version) {
        case .accepted(let version):
            replica.synced = Versioned(note: replica.current, version: version)
            replica.outbox.removeAll()
            print("attempt \(attempt): accepted as v\(version)")
            return
        case .conflict(let current):
            print("attempt \(attempt): conflict, server is at v\(current.version)")
            replica.synced = current   // rebase: replay the outbox on top of the server's copy
        }
    }
}

let server = Server(Note(text: "Great opening", pagesRead: 40))
var phone = Replica(synced: server.record)
var tablet = Replica(synced: server.record)

phone.edit(.setText("Great opening chapter"))   // offline on the phone
phone.edit(.setPagesRead(90))

tablet.edit(.setPagesRead(120))                  // the tablet syncs first
sync(&tablet, with: server)

sync(&phone, with: server)                       // the phone comes back online
print("server: \"\(server.record.note.text)\", \(server.record.note.pagesRead) pages, v\(server.record.version)")
```

```output
attempt 1: accepted as v2
attempt 1: conflict, server is at v2
attempt 2: accepted as v3
server: "Great opening chapter", 120 pages, v3
```

- The tablet's push is based on v1, the current version, so it's accepted as v2.
- The phone's push is also based on v1, which is no longer current: conflict. The server returns its current copy.
- The phone **rebases**: it takes the server's v2 as its new base and replays its outbox on top. Its text change applies; its "read up to page 90" doesn't lower the 120 the tablet reported, because `setPagesRead` only moves forward.
- The second push is based on v2 and is accepted as v3. Both devices' intentions survive.
- The retry is bounded. A loop that retries forever against a server that keeps changing turns a conflict into a hang.

Recording **operations** ("set the text", "read up to page 90") rather than whole snapshots is what makes the replay work: each operation says what the person meant, so it can be applied to a newer base. The rule inside each operation (here, `max`) is the conflict policy for that field.

### Conflict strategies

When operations aren't available (the server sends a whole record, or the edits are snapshots), you compare copies. With the **base** (the last version both sides agreed on), you can tell which side changed which field:

```swift
struct Note: Equatable {
    var text: String
    var tags: Set<String>
    var pagesRead: Int
}

enum ConflictStrategy: CaseIterable {
    case serverWins, clientWins, fieldMerge
}

/// base: the last version both sides agreed on. local: this device's edit. remote: the server's current copy.
func resolve(base: Note, local: Note, remote: Note, strategy: ConflictStrategy) -> Note {
    switch strategy {
    case .serverWins:
        return remote
    case .clientWins:
        return local
    case .fieldMerge:
        var merged = remote
        // Text: take the side that changed it; if both did, keep the server's.
        if local.text != base.text && remote.text == base.text {
            merged.text = local.text
        }
        // Tags: keep additions from both sides, apply removals from both sides.
        let added = local.tags.subtracting(base.tags).union(remote.tags.subtracting(base.tags))
        let removed = base.tags.subtracting(local.tags).union(base.tags.subtracting(remote.tags))
        merged.tags = base.tags.union(added).subtracting(removed)
        // Progress only moves forward.
        merged.pagesRead = max(local.pagesRead, remote.pagesRead)
        return merged
    }
}

func describe(_ note: Note) -> String {
    "\"\(note.text)\" tags=\(note.tags.sorted()) pages=\(note.pagesRead)"
}

let base = Note(text: "Great opening", tags: ["sci-fi", "classic"], pagesRead: 40)

var phone = base                     // edited offline on the phone
phone.text = "Great opening chapter"
phone.tags.insert("reread")
phone.pagesRead = 90

var tablet = base                    // edited on the tablet and already synced
tablet.tags.remove("classic")
tablet.pagesRead = 60

for strategy in ConflictStrategy.allCases {
    print("\(strategy): \(describe(resolve(base: base, local: phone, remote: tablet, strategy: strategy)))")
}
```

```output
serverWins: "Great opening" tags=["sci-fi"] pages=60
clientWins: "Great opening chapter" tags=["classic", "reread", "sci-fi"] pages=90
fieldMerge: "Great opening chapter" tags=["reread", "sci-fi"] pages=90
```

- **Server wins** loses everything the phone did offline: the new text, the new tag, the progress.
- **Client wins** undoes the tablet's removal of `classic`. The phone's progress happens to be higher here; had the tablet read further, its progress would be lost too. Whoever syncs last silently erases the other device's work.
- **Field merge** keeps both: the phone's text (the tablet didn't touch it), the phone's added tag and the tablet's removed one, and the furthest progress. Only a field changed on **both** sides needs a tie-breaker, and that's where you choose per field: keep the server's text and save the other as a conflict copy, ask the person, or concatenate.

Choosing per field is the real design work, and it's a product decision as much as an engineering one: progress takes the maximum, tags merge as sets, a title probably takes the newest server version and keeps the other as a visible conflict. Write the rules down, as functions, with tests like this one.

> [!note] CloudKit and SwiftData
> SwiftData can sync a store to iCloud through CloudKit (`ModelConfiguration`'s `cloudKitDatabase`), and Core Data has `NSPersistentCloudKitContainer`. They handle transport and merging for you, within the person's own devices, with constraints on how you model data. Apple's "Syncing model data across a person's devices" lists them. Your own server, shared data between people, or custom conflict rules still lead you to the design above.

## Common mistakes

> [!error] Editing the only version of the model
> Core Data needs the old model version to migrate from, and SwiftData needs the old `VersionedSchema`. Change the model in place and existing stores no longer match anything. Add a new version; freeze the old one.

> [!error] Renaming without telling the framework
> Without a renaming identifier (Core Data) or `@Attribute(originalName:)` (SwiftData), a rename looks like "remove `pages`, add `pageCount`", and every value is lost without an error.

> [!error] Adding a unique constraint to data that has duplicates
> The migration fails on devices whose data has duplicates, which your test data probably doesn't. Remove duplicates in a custom stage before the constraint applies.

> [!error] Cache entries without a timestamp
> A disk cache that stores only the value can't tell yesterday's copy from last month's. Store when each entry was written, and check it on every read.

> [!error] Device timestamps as the order of writes
> Clocks drift and can be set by hand. Let the server assign versions and reject writes based on old ones.

> [!error] Server wins (or client wins) for everything
> One side's offline work disappears without a trace. Merge field by field against the base, and use a tie-breaker only where both sides changed the same field.

## Exercises

````exercise
id: m31-l06-e1
type: prediction
prompt: "Two devices update the same bookmark. The tablet's clock runs 5 minutes slow, and it writes 2 real minutes after the phone. What does the program print?"
code: |
  struct Write {
      let device: String
      let value: String
      let deviceClock: Int      // minutes past 10:00, as the device's clock reports
      let arrivalOrder: Int     // the order the server received the writes
  }

  // The tablet's clock runs 5 minutes slow. It writes 2 real minutes after the phone.
  let writes = [
      Write(device: "phone", value: "Chapter 3", deviceClock: 0, arrivalOrder: 1),
      Write(device: "tablet", value: "Chapter 4", deviceClock: -3, arrivalOrder: 2),
  ]

  let byDeviceClock = writes.max { $0.deviceClock < $1.deviceClock }!
  let byArrival = writes.max { $0.arrivalOrder < $1.arrivalOrder }!

  print("last writer by device clock: \(byDeviceClock.device), \(byDeviceClock.value)")
  print("last writer by arrival: \(byArrival.device), \(byArrival.value)")
output: |
  last writer by device clock: phone, Chapter 3
  last writer by arrival: tablet, Chapter 4
solution: |
  The phone writes at 10:00 by a correct clock. The tablet writes at 10:02 real time, but its clock says 9:57 (2 − 5 = −3). Ordered by device clocks, the phone's write looks newer, so "Chapter 3" wins, even though the person moved on to chapter 4. Ordered by arrival at the server, the tablet's write is last.

  ```output
  last writer by device clock: phone, Chapter 3
  last writer by arrival: tablet, Chapter 4
  ```

  Arrival order isn't perfect either (a write queued offline arrives late), which is why the lesson's server uses versions: a write must say which version it was based on, and anything based on an old version is a conflict to merge, not a race to win.
````

````exercise
id: m31-l06-e2
type: comprehension
multiple: true
prompt: "Which of these Core Data model changes can lightweight migration infer, according to Apple's list? Select all that apply."
choices:
  - text: "Adding an optional attribute notes to Book."
    correct: true
    why: "Addition of an attribute is on the list."
  - text: "Renaming the attribute pages to pageCount, with pageCount's renaming identifier set to pages."
    correct: true
    why: "Renaming with a renaming identifier is on the list."
  - text: "Making an optional rating attribute non-optional, with no default value."
    correct: false
    why: "Apple's list requires a default value for this change. Without one, there's nothing to put in rows where rating is nil; that's the staged-migration example."
  - text: "Changing a to-one relationship author into a to-many authors."
    correct: true
    why: "Changing a relationship from to-one to to-many is on the list."
  - text: "Splitting a fullName attribute into firstName and lastName, filled from the old value."
    correct: false
    why: "Computing new values from old ones needs your code: a custom stage or a manual migration."
solution: |
  Inferable: adding an attribute, renaming with a renaming identifier, and to-one becoming to-many. Not inferable: optional to required without a default (Core Data can't invent the missing values, so a staged migration fills them first) and splitting a field (the split rule is your logic). Note that a rename without the renaming identifier is also "inferable", just not as a rename: it's a removal plus an addition, and the data is lost.
````

````exercise
id: m31-l06-e3
type: prediction
prompt: "A loader with a 15-minute in-memory cache. What does the program print?"
code: |
  struct Cache {
      var entries: [String: (value: String, storedAt: Int)] = [:]
      let maxAge: Int

      mutating func value(for key: String, at minute: Int) -> String? {
          guard let entry = entries[key] else { return nil }
          guard minute - entry.storedAt < maxAge else {
              entries[key] = nil
              return nil
          }
          return entry.value
      }

      mutating func insert(_ value: String, for key: String, at minute: Int) {
          entries[key] = (value, minute)
      }
  }

  struct Loader {
      var cache = Cache(maxAge: 15)
      var fetches = 0

      mutating func load(_ key: String, at minute: Int) -> String {
          if let cached = cache.value(for: key, at: minute) {
              return "\(cached) (cached)"
          }
          fetches += 1
          let fresh = "\(key) v\(fetches)"
          cache.insert(fresh, for: key, at: minute)
          return fresh
      }
  }

  var loader = Loader()
  print(loader.load("feed", at: 0))
  print(loader.load("feed", at: 14))
  print(loader.load("feed", at: 15))
  print(loader.load("profile", at: 16))
  print(loader.load("feed", at: 29))
  print(loader.load("feed", at: 31))
  print("fetches: \(loader.fetches)")
output: |
  feed v1
  feed v1 (cached)
  feed v2
  profile v3
  feed v2 (cached)
  feed v4
  fetches: 4
solution: |
  - Minute 0: miss, fetch 1, stored at 0.
  - Minute 14: 14 − 0 < 15, cached.
  - Minute 15: 15 − 0 isn't < 15, expired: fetch 2, stored at 15.
  - Minute 16: a different key, a miss: fetch 3. The fetch counter is shared, so it's `profile v3`.
  - Minute 29: 29 − 15 = 14, cached `feed v2`.
  - Minute 31: 31 − 15 = 16, expired: fetch 4.

  ```output
  feed v1
  feed v1 (cached)
  feed v2
  profile v3
  feed v2 (cached)
  feed v4
  fetches: 4
  ```

  The boundary is the usual trap: with `<`, an entry exactly `maxAge` old is already expired.
````

````exercise
id: m31-l06-e4
type: solve
prompt: "Version 4 of the library file splits each title at the first \": \" into `title` and `subtitle` (\"Dune: Deluxe Edition\" becomes \"Dune\" and \"Deluxe Edition\"; a title without \": \" gets a nil subtitle). Freeze version 3 as `LibraryV3`, write the new current `Library` and one step from V3, and update the loader so versions 1 to 4 all load. Test with a version 1 file containing \"Dune: Deluxe Edition\" and a version 3 file containing \"Kindred\"."
starter: |
  import Foundation

  // LibraryV1, LibraryV2 and their steps from the lesson.
  // Rename the lesson's Library to LibraryV3, then write the new Library and migrate(_ v3:).
rubric:
  - Version 3's type is kept unchanged under a new name; older steps don't change.
  - "The new step splits only at the first \": \" and leaves subtitle nil otherwise."
  - The loader chains steps so a version 1 file passes through every step.
  - Versions newer than 4 still throw.
solution: |
  One frozen type, one new step, one more `case`. Splitting with `range(of:)` finds the first separator only, so "A: B: C" becomes "A" and "B: C".

  ```swift
  import Foundation

  struct LibraryV1: Codable {
      struct Book: Codable { let title: String; let pages: Int; let isRead: Bool }
      let books: [Book]
  }

  struct LibraryV2: Codable {
      struct Book: Codable { let title: String; let pageCount: Int; let isRead: Bool }
      let books: [Book]
  }

  enum Status: String, Codable { case unread, reading, finished }

  struct LibraryV3: Codable {
      struct Book: Codable { let id: Int; let title: String; let pageCount: Int; let status: Status }
      let books: [Book]
  }

  struct Library: Codable {
      struct Book: Codable {
          let id: Int
          let title: String
          let subtitle: String?
          let pageCount: Int
          let status: Status
      }
      static let currentVersion = 4
      var schemaVersion = Library.currentVersion
      let books: [Book]
  }

  enum MigrationError: Error {
      case unsupportedVersion(Int)
  }

  private struct VersionProbe: Decodable {
      let schemaVersion: Int
  }

  func migrate(_ v1: LibraryV1) -> LibraryV2 {
      LibraryV2(books: v1.books.map { .init(title: $0.title, pageCount: $0.pages, isRead: $0.isRead) })
  }

  func migrate(_ v2: LibraryV2) -> LibraryV3 {
      LibraryV3(books: v2.books.enumerated().map { index, book in
          .init(id: index + 1, title: book.title, pageCount: book.pageCount,
                status: book.isRead ? .finished : .unread)
      })
  }

  func migrate(_ v3: LibraryV3) -> Library {
      Library(books: v3.books.map { book in
          var title = book.title
          var subtitle: String?
          if let separator = book.title.range(of: ": ") {
              title = String(book.title[..<separator.lowerBound])
              subtitle = String(book.title[separator.upperBound...])
          }
          return .init(id: book.id, title: title, subtitle: subtitle,
                       pageCount: book.pageCount, status: book.status)
      })
  }

  func loadLibrary(from data: Data) throws -> Library {
      let decoder = JSONDecoder()
      let version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
      switch version {
      case 1: return migrate(migrate(migrate(try decoder.decode(LibraryV1.self, from: data))))
      case 2: return migrate(migrate(try decoder.decode(LibraryV2.self, from: data)))
      case 3: return migrate(try decoder.decode(LibraryV3.self, from: data))
      case 4: return try decoder.decode(Library.self, from: data)
      default: throw MigrationError.unsupportedVersion(version)
      }
  }

  let files = [
      #"{"schemaVersion": 1, "books": [{"title": "Dune: Deluxe Edition", "pages": 412, "isRead": true}]}"#,
      #"{"schemaVersion": 3, "books": [{"id": 7, "title": "Kindred", "pageCount": 264, "status": "reading"}]}"#,
  ]

  for file in files {
      let library = try loadLibrary(from: Data(file.utf8))
      for book in library.books {
          print("v\(library.schemaVersion): #\(book.id) \(book.title) / \(book.subtitle ?? "no subtitle"), \(book.status)")
      }
  }
  ```

  ```output
  v4: #1 Dune / Deluxe Edition, finished
  v4: #7 Kindred / no subtitle, reading
  ```

  `Status` moved out of the library type so V3 and V4 share it. That's fine while it doesn't change; the day it does, V3 gets its own frozen copy too.
````

````exercise
id: m31-l06-e5
type: find-errors
prompt: "A teammate's SwiftData migration for version 2, which renames `pages` to `pageCount`. Which are real problems?"
code: |
  enum LibrarySchemaV1: VersionedSchema {
      static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
      static var models: [any PersistentModel.Type] { [Book.self] }

      @Model final class Book {
          var title: String
          var pageCount: Int          // was "pages"; updated to match the app
          init(title: String, pageCount: Int) { self.title = title; self.pageCount = pageCount }
      }
  }

  enum LibrarySchemaV2: VersionedSchema {
      static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
      static var models: [any PersistentModel.Type] { [Book.self] }

      @Model final class Book {
          var title: String
          var pageCount: Int
          init(title: String, pageCount: Int) { self.title = title; self.pageCount = pageCount }
      }
  }

  enum LibraryMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV2.self, LibrarySchemaV1.self] }
      static var stages: [MigrationStage] {
          [.lightweight(fromVersion: LibrarySchemaV1.self, toVersion: LibrarySchemaV2.self)]
      }
  }
choices:
  - text: "Version 1's model was edited to the new property name."
    correct: true
    why: "V1 must describe what's actually on disk. Freeze it with pages."
  - text: "Version 2 has no @Attribute(originalName: \"pages\") on pageCount."
    correct: true
    why: "Without it, the rename is a removal plus an addition, and page counts are lost."
  - text: "Both versions use Schema.Version(1, 0, 0)."
    correct: true
    why: "Each schema version needs its own identifier."
  - text: "schemas lists the versions newest first."
    correct: true
    why: "The plan lists versions in order, oldest first."
  - text: "Using a lightweight stage for a rename."
    correct: false
    why: "A rename declared with originalName is exactly what a lightweight stage handles."
rubric:
  - Flags the edited V1 model.
  - Flags the missing originalName.
  - Flags the duplicated version identifier.
  - Flags the reversed schema order.
  - Accepts the lightweight stage.
solution: |
  Four real problems. Version 1 must stay exactly as it shipped (`pages`), version 2 declares the rename with `@Attribute(originalName: "pages") var pageCount: Int`, the identifiers must differ (`Schema.Version(2, 0, 0)` for V2), and `schemas` goes oldest first. With those fixed, the lightweight stage is right; no custom code is needed for a declared rename.
````

````exercise
id: m31-l06-e6
type: design
prompt: "Design sync for a reading-notes app used on a phone and a tablet, with your own server. Notes have text, a page number, tags and a \"favorite\" flag; people edit offline for days at a time. Describe the local store, the outbox, what a push and a pull send, how the server detects conflicts, and the conflict rule for each field. Then describe what the person sees when a conflict can't be merged."
rubric:
  - The UI reads only the local store (SwiftData or Core Data), which includes unsynced edits.
  - The outbox is persisted, records operations in order, and removes an entry only when the server accepts it.
  - Pushes carry the base version; the server rejects stale versions; pulls use a cursor or token for changes since the last sync.
  - A per-field rule is given (for example text needs a tie-breaker, page number takes a defined rule, tags merge as sets, favorite needs a decision) with a reason for each.
  - Unmergeable conflicts are made visible (a conflict copy or a choice), never silently dropped.
  - Deletions are handled (a deleted note edited elsewhere).
solution: |
  A solid design:

  - **Local store:** SwiftData models for notes, plus a `syncedVersion` per note. The UI reads only this store.
  - **Outbox:** a persisted, ordered list of operations (`setText`, `setPage`, `addTag`, `removeTag`, `setFavorite`, `delete`), each with the note's ID and the base version it was made against. An entry is removed only when the server accepts it, so a crash or a dead battery loses nothing.
  - **Push:** operations for each note, with the base version. The server applies them if the version matches and returns the new version; otherwise it returns 409 with its current copy.
  - **Pull:** "changes since cursor X", paged (Module 30), applied in a background model actor (lesson 5). The cursor is saved after each page is applied, not before.
  - **Per field:** text, if both sides changed it, keeps the server's and saves the local text as a "conflicted copy" note next to it; page number takes the latest by server order, since it marks where the note applies, not progress; tags merge as sets (additions and removals from both); favorite takes "true wins" (losing a favorite is more annoying than gaining one); delete versus edit: the edit wins and the note is restored, because deleting someone's newer text is worse than keeping an old note.
  - **Visible conflicts:** a conflicted copy appears with a badge, "Edited on two devices", and actions to keep one or both. Nothing is dropped silently.
  - **Tests:** each rule as a pure function, with base/local/remote fixtures like the lesson's, plus a simulated two-device run like the push loop.
````

````exercise
id: m31-l06-e7
type: explain
prompt: "The lesson's push loop records operations in the outbox instead of a snapshot of the whole note. Explain what that buys during a conflict, using the phone and tablet example."
code: |
  enum Change {
      case setText(String)
      case setPagesRead(Int)
  }

  func apply(_ change: Change, to note: Note) -> Note {
      var note = note
      switch change {
      case .setText(let text): note.text = text
      case .setPagesRead(let pages): note.pagesRead = max(note.pagesRead, pages)
      }
      return note
  }
rubric:
  - On conflict, the client can take the server's current copy as the new base and replay its operations.
  - Operations carry intent, so non-overlapping changes from both devices survive.
  - The rule inside an operation (max for progress) resolves that field without a separate merge step.
  - A snapshot would overwrite the other device's changes or require a three-way merge with a stored base.
solution: |
  An operation says what the person did, not what the whole note looked like afterward. When the phone's push hit a conflict, it took the server's v2 (with the tablet's 120 pages) as its new base and replayed "set the text" and "read up to page 90" on top. The text change applied; "read up to 90" didn't lower 120, because the operation's own rule is "only move forward". Both devices' intentions survived with no special merge code.

  With a snapshot, the phone would push `{text: "Great opening chapter", pagesRead: 90}`. Applied blindly, it erases the tablet's 120; refused, it needs a three-way merge against a stored base to work out which fields the phone actually changed. Operations make the base implicit: whatever the server has now.
````

## Summary

- A migration turns data written by an old version into the current shape, once. Lightweight migrations are inferred; custom ones run your code for changes the framework can't decide.
- Core Data infers additions, removals, optionality changes with a default, declared renames and several relationship changes. iOS 17's staged migrations add custom stages (`willMigrateHandler`, `didMigrateHandler`) for the rest. Keep every model version.
- SwiftData versions are `VersionedSchema` types with nested models; a `SchemaMigrationPlan` lists them oldest first with one `MigrationStage` per step. Use `@Attribute(originalName:)` for renames, and clean data in `willMigrate` before adding constraints.
- Your own formats: read the version first, decode that version's frozen type, apply each step, and throw for versions newer than the app.
- A disk cache stores each entry's timestamp, checks freshness on every read, promotes disk hits to memory, and treats any failure as a miss. Pass time in; don't read the clock inside.
- Offline-first: the UI reads the local store, an outbox holds operations until the server accepts them, the server orders writes with versions, and conflicts are resolved per field against the base, with unmergeable ones shown to the person.
