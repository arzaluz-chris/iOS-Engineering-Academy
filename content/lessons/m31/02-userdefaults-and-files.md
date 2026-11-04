---
id: m31-l02
title: UserDefaults and files
description: "Store settings and small documents correctly. You see what UserDefaults guarantees and what it doesn't, register defaults at every launch, wrap settings in a typed struct you can test with a throwaway suite, share settings with an extension through an app group, write Codable models to files atomically, recover from a damaged file, and choose a Data Protection level for each file."
module: m31
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l01]
objectives:
  - Explain how UserDefaults stores values, which types it accepts, and why it's wrong for secrets and records.
  - Register default values at launch and predict what a read returns for set, registered and missing keys.
  - Wrap settings in a typed struct that takes its UserDefaults instance, and test it with a throwaway suite.
  - Write Codable models to a file atomically, treat a missing file as empty and move a damaged one aside.
  - Choose a Data Protection level for a file and apply it when writing.
terms:
  - term: Defaults domain
    definition: "A named set of key-value pairs in the defaults system. Your app's domain, a suite's domain and the volatile registration domain are searched in order when you read a key."
  - term: Registration domain
    definition: "The domain that register(defaults:) writes to. It isn't saved to disk, so you register again at every launch, and it's searched after the domains you write to, so it supplies fallbacks."
  - term: Suite
    definition: "A UserDefaults instance for a named domain, created with UserDefaults(suiteName:). With an app group identifier, it's shared between an app and its extensions."
  - term: Atomic write
    definition: "Writing to a temporary file and then replacing the original in one step, so a reader sees either the old file or the new one, never half of the new one."
  - term: File protection level
    definition: "The Data Protection class of a file (complete, completeUnlessOpen, completeUntilFirstUserAuthentication, none). It decides whether the file can be read while the device is locked."
mastery:
  - Predict the value of integer(forKey:) for a key that's set, removed, registered or never written.
  - Write a settings type with a typed property per key, clamped or validated values, and an injected UserDefaults.
  - Test a settings type against UserDefaults(suiteName:) and clean up with removePersistentDomain(forName:).
  - Save and load a Codable value with .atomic writes and handle CocoaError.fileReadNoSuchFile.
  - Pick complete, completeUnlessOpen or completeUntilFirstUserAuthentication for a file from when the app needs to read it.
resources: [apple-platform-security, swift-book-properties, swift-book-error-handling]
cards:
  - id: m31-l02-c1
    front: What does register(defaults:) do, and when do you call it?
    back: "It puts fallback values in the registration domain, which is searched after the values you set. Nothing is written to disk, so you call it at every launch, early, before anything reads settings."
  - id: m31-l02-c2
    front: How do you test code that uses UserDefaults without touching the app's real settings?
    back: "Inject the UserDefaults instance. In the test, create UserDefaults(suiteName:) with a unique name, run the code against it, and call removePersistentDomain(forName:) at the end."
  - id: m31-l02-c3
    front: Why write files with the .atomic option?
    back: "The data is written to an auxiliary file that then replaces the original. If the app crashes or the disk fills mid-write, the old file is still intact instead of half-written."
  - id: m31-l02-c4
    front: What's the default file protection level on iOS, and what does it allow?
    back: "Complete until first user authentication: unreadable after a reboot until the person unlocks the device once, then readable even while locked. Use .complete for files the app only touches in the foreground."
  - id: m31-l02-c5
    front: How do an app and its widget share settings?
    back: "Both join the same app group (an entitlement) and use UserDefaults(suiteName: \"group.your.identifier\"). For files, FileManager's containerURL(forSecurityApplicationGroupIdentifier:) gives the shared folder."
---

## The idea in one sentence

`UserDefaults` is a small key-value store for settings that you read through typed accessors and test with a throwaway suite, and anything bigger goes in a file that you write atomically, read defensively and protect according to when the app needs it.

> [!note] Sources and what was run
> `UserDefaults` behavior is quoted from Apple's `UserDefaults`, `register(defaults:)` and `init(suiteName:)` documentation; file protection from Foundation's `FileProtectionType`, `NSData.WritingOptions` and UIKit's "Encrypting your app's files". All read in November 2026. The `UserDefaults` and file blocks were compiled and run with Swift 6.3 on Linux, writing only to a temporary folder or a throwaway suite, and print only values that Apple documents the same way. The file protection block uses iOS-only behavior, so it was type-checked against the iOS SDK, not run.

## What UserDefaults is

From Apple's documentation, the parts that matter:

- It stores "nonsensitive information, such as app-specific configuration details". It "stores information on disk in an unencrypted format", and backups include it.
- Values are property-list types: `Bool`, `Int`, `Double`, `String`, `Date`, `Data`, `URL`, and arrays and dictionaries of those. Anything else must be encoded to `Data` first.
- A write "updates its in-memory version of that information right away, and writes the value to disk asynchronously". You read your own write immediately. `synchronize()` is documented as "unnecessary and shouldn't be used".
- It's thread-safe: "you can use the same object in multiple threads or tasks simultaneously".

Reads search several **domains** in order. The two you use are your app's domain (where `set(_:forKey:)` writes) and the **registration domain**, searched near the end, which holds fallbacks:

```swift
import Foundation

let suiteName = "academy.m31.defaults-demo.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!

print(defaults.integer(forKey: "fontSize"))
print(defaults.object(forKey: "fontSize") == nil)

defaults.register(defaults: ["fontSize": 17, "showsCovers": true])
print(defaults.integer(forKey: "fontSize"))
print(defaults.bool(forKey: "showsCovers"))

defaults.set(20, forKey: "fontSize")
print(defaults.integer(forKey: "fontSize"))

defaults.removeObject(forKey: "fontSize")
print(defaults.integer(forKey: "fontSize"))

defaults.removePersistentDomain(forName: suiteName)
```

```output
0
true
17
true
20
17
```

Line by line:

- The block uses a suite with a unique name so it doesn't touch any real settings, and deletes it at the end with `removePersistentDomain(forName:)`. You'll do the same in tests.
- `integer(forKey:)` returns `0` for a key that was never written. `bool(forKey:)` returns `false`. So you can't tell "the person chose 0" from "nothing is stored"; `object(forKey:) == nil` can.
- `register(defaults:)` supplies 17 and `true` without writing anything to disk.
- `set(20, …)` writes to the app's domain, which is searched first, so it wins.
- `removeObject(forKey:)` deletes the stored 20, and the read falls through to the registered 17 again.

Apple says the registration domain "is volatile, so you must register the set of default values each time your app launches". Call it early, before anything reads settings: in `application(_:didFinishLaunchingWithOptions:)` or your `App`'s initializer.

> [!note] One registration domain for everyone
> `init(suiteName:)`'s documentation says "every instance of UserDefaults shares the contents of the argument and registration domains". Registering a default on a suite also makes it visible through `.standard`. Use distinct key prefixes so registrations from different features can't collide.

## Typed settings

String keys scattered through view controllers are typos waiting to happen, and every reader has to repeat the fallback and validation logic. Put each setting behind a typed property, in one type that receives its `UserDefaults`:

```swift
import Foundation

enum SortOrder: String, CaseIterable {
    case title, author, recentlyAdded
}

struct ReadingSettings {
    private enum Key {
        static let sortOrder = "reading.sortOrder"
        static let fontSize = "reading.fontSize"
        static let showsCovers = "reading.showsCovers"
    }

    let defaults: UserDefaults

    static func registerDefaults(in defaults: UserDefaults) {
        defaults.register(defaults: [
            Key.sortOrder: SortOrder.title.rawValue,
            Key.fontSize: 17,
            Key.showsCovers: true,
        ])
    }

    var sortOrder: SortOrder {
        get { SortOrder(rawValue: defaults.string(forKey: Key.sortOrder) ?? "") ?? .title }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.sortOrder) }
    }

    var fontSize: Int {
        get { defaults.integer(forKey: Key.fontSize) }
        nonmutating set { defaults.set(min(max(newValue, 12), 32), forKey: Key.fontSize) }
    }

    var showsCovers: Bool {
        get { defaults.bool(forKey: Key.showsCovers) }
        nonmutating set { defaults.set(newValue, forKey: Key.showsCovers) }
    }
}

// In a test, use a throwaway suite instead of .standard.
let suiteName = "academy.m31.settings.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
ReadingSettings.registerDefaults(in: defaults)

let settings = ReadingSettings(defaults: defaults)
print(settings.sortOrder, settings.fontSize, settings.showsCovers)

settings.sortOrder = .author
settings.fontSize = 40
settings.showsCovers = false
print(settings.sortOrder, settings.fontSize, settings.showsCovers)

defaults.set("byColor", forKey: "reading.sortOrder")   // a value from a newer app version
print(settings.sortOrder)

defaults.removePersistentDomain(forName: suiteName)
```

```output
title 17 true
author 32 false
title
```

What the design buys you:

- **Keys live in one place.** A private `Key` namespace means no other file can misspell `"reading.fontSize"`.
- **Values are validated on the way in and out.** The font size is clamped to 12–32. An enum is stored as its raw value, and a raw value this version doesn't know (written by a newer version, or by a bug) falls back to `.title` instead of crashing.
- **`nonmutating set`** works because the struct doesn't change: it only holds a reference to `UserDefaults`, which changes. So `let settings` can still assign.
- **The `UserDefaults` is injected.** The app passes `.standard`; tests pass a suite. That's the same dependency injection as Module 30's repository.

In SwiftUI, `@AppStorage` reads and writes one `UserDefaults` key and refreshes the view when it changes; you'll use it in Module 36. Observing changes elsewhere uses `UserDefaults.didChangeNotification` or key-value observing.

> [!tip] Codable values in UserDefaults
> Apple: to store other types, "archive them to a Data object first". A small `Codable` value (the last three searches, say) can go in as `try JSONEncoder().encode(value)` and come back with `data(forKey:)`. Keep it small. If it grows with use, it's records, and it belongs in a file.

### Sharing with an extension: suites and app groups

A widget or share extension is a separate process with its own container. To share settings, both targets join an **app group** (the `com.apple.security.application-groups` entitlement) and use the group's suite:

- `UserDefaults(suiteName: "group.com.example.bookshelf")` in both the app and the widget.
- Files go in the group's container: `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` returns its URL, or `nil` if the entitlement is missing.

Apple's notes: a sandboxed app can modify settings "for an app group to which it belongs", and an app that uses a suite "must also have" the app groups entitlement. Using another app's identifier doesn't give you its settings; your writes just go to your own app's settings.

## Files: Codable models on disk

When data outgrows a setting but you still load it whole (a reading list of a few hundred books, a draft document, a downloaded configuration), a JSON file in `Application Support` is the simplest store. Three rules:

1. **Write atomically.** `Data.write(to:options:)` with `.atomic` writes "to an auxiliary file first and then replace[s] the original file with the auxiliary file when the write completes". A crash or a full disk mid-write leaves the old file untouched.
2. **A missing file means "empty", not "error".** On first launch, there's nothing to read.
3. **A damaged file is not a reason to overwrite it.** Move it aside, start empty, and report it.

```swift
import Foundation

struct SavedBook: Codable, Equatable {
    let id: Int
    var title: String
}

struct Library: Codable, Equatable {
    var schemaVersion = 1
    var books: [SavedBook] = []
}

struct JSONFile<Value: Codable> {
    let url: URL

    func load() throws -> Value? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

// A throwaway folder standing in for Application Support.
let root = FileManager.default.temporaryDirectory.appending(path: "m31-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: root) }

let file = JSONFile<Library>(url: root.appending(path: "Bookshelf/library.json"))

print(try file.load() == nil)

var library = try file.load() ?? Library()
library.books.append(SavedBook(id: 1, title: "Dune"))
library.books.append(SavedBook(id: 2, title: "Neuromancer"))
try file.save(library)

let reloaded = try file.load()
print(reloaded == library)
print(reloaded?.books.map(\.title) ?? [])
```

```output
true
true
["Dune", "Neuromancer"]
```

Line by line:

- `load()` reads the bytes and lets one specific error through as "nothing here": `CocoaError.fileReadNoSuchFile`. Every other error (no permission, a damaged file) is thrown, because the caller must decide what to do. Checking `fileExists` first and then reading would race with anything that deletes the file in between; just read and handle the error.
- `save(_:)` creates the folder (no error if it exists), encodes, and writes with `.atomic`.
- `.sortedKeys` makes the file's bytes stable for the same value, which keeps diffs and tests readable. `.prettyPrinted` is for humans reading the file; drop it for large files.
- `schemaVersion` is in the file from day one. When version 2 renames a field, the loader can tell old files from new ones. Lesson 6 builds the migration.
- In the app, the folder is `URL.applicationSupportDirectory`, not a temporary one. Module 21 explained why: it's backed up and not purged.

The file looks like this:

```json
{
  "books" : [
    {
      "id" : 1,
      "title" : "Dune"
    },
    {
      "id" : 2,
      "title" : "Neuromancer"
    }
  ],
  "schemaVersion" : 1
}
```

### When the file is damaged

A non-atomic write that was interrupted, a bug in an old version's encoder, or a manual edit can all leave a file that doesn't decode. The worst response is to start with an empty `Library` and save it over the damaged file: whatever was recoverable is gone. Move it aside instead:

```swift
import Foundation

struct Library: Codable {
    var books: [String] = []
}

let root = FileManager.default.temporaryDirectory.appending(path: "m31-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let url = root.appending(path: "library.json")

// A file cut short by a crash during a non-atomic write.
try Data(#"{"books":["Dune","Neuro"#.utf8).write(to: url)

func loadLibrary(from url: URL) -> Library {
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Library.self, from: data)
    } catch CocoaError.fileReadNoSuchFile {
        return Library()
    } catch {
        // Keep the damaged file for diagnosis instead of overwriting it.
        let quarantine = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: quarantine)
        try? FileManager.default.moveItem(at: url, to: quarantine)
        print("Moved aside a damaged library: \(type(of: error))")
        return Library()
    }
}

let library = loadLibrary(from: url)
print(library.books.count)
print(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted())
```

```output
Moved aside a damaged library: DecodingError
0
["library.json.corrupt"]
```

In a real app, the `print` becomes a log line and an analytics event (without the file's contents), and the screen can tell the person their library couldn't be loaded. You can inspect the `.corrupt` file from a sysdiagnose or a support build.

> [!warning] Big files and the main thread
> `Data(contentsOf:)` and `write(to:options:)` block the calling thread. A 50 KB settings file is fine anywhere; a 20 MB file read on the main actor freezes the UI. Put file I/O for anything large in an actor or a detached task, and don't save on every keystroke: save when the person pauses, leaves the screen or the app moves to the background.

## File protection

On iOS, every file has a **Data Protection** level. Apple's "Encrypting your app's files" lists four, and says that if you don't choose, "iOS applies the default protection level automatically":

| Level | Readable while locked? | Use for |
| --- | --- | --- |
| `complete` | No | Personal data the app only uses in the foreground |
| `completeUnlessOpen` | Only if it was open before locking; new files can be created while locked | Files written in the background, such as a log of location events |
| `completeUntilFirstUserAuthentication` (the default) | Yes, after the first unlock since boot | Data that background work needs |
| `none` | Always | Rarely right |

Protection is enabled "automatically when the user sets an active passcode". Apple's guidance is to give "files containing personal information about the user, or files created directly by the user" the strongest level, and to choose a weaker one only for files that background work must read.

You set the level when writing, or change it afterward:

```swift ios
import Foundation

struct Journal: Codable {
    var entries: [String]
}

func saveJournal(_ journal: Journal) throws -> URL {
    let folder = URL.applicationSupportDirectory.appending(path: "Journal")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "journal.json")
    let data = try JSONEncoder().encode(journal)
    try data.write(to: file, options: [.atomic, .completeFileProtection])
    return file
}

func protectionLevel(of file: URL) throws -> URLFileProtection? {
    try file.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
}

func allowBackgroundReads(of file: URL) throws {
    try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: file.path(percentEncoded: false))
}

let file = try saveJournal(Journal(entries: ["Started Dune."]))
print(try protectionLevel(of: file) == .complete)
```

- `.completeFileProtection` is an option like `.atomic`, so you pass both in one set.
- Reading the level back uses the `fileProtectionKey` resource value.
- `setAttributes(_:ofItemAtPath:)` with `.protectionKey` changes the level of an existing file.
- Pass the option on **every** write. An atomic write replaces the file, so don't rely on a level you set on the old file once.

With `.complete`, reading the file while the device is locked fails with an error, so code that might run in the background (a background refresh, a notification extension) must handle that or use a weaker level for the data it needs. The **Data Protection** capability in Xcode sets the default level for all of the app's files, and a level passed when writing overrides it.

## Common mistakes

> [!error] Forgetting to register defaults at launch
> The registration domain isn't saved. Register once and you get your defaults on that run only; on the next launch, `bool(forKey:)` returns `false` for a setting you meant to default to `true`.

> [!error] Treating 0, false or nil as "the person chose this"
> `integer(forKey:)` returns `0` when nothing is stored. If 0 is a valid choice, register a default or check `object(forKey:) == nil`.

> [!error] Tests that write to UserDefaults.standard
> They leave values behind that change the next test's result and the developer's own app state. Inject the instance and use a throwaway suite.

> [!error] Writing a file without .atomic
> A crash or a full disk during the write leaves a truncated file, and the next launch can't decode it. Atomic writes keep the old file until the new one is complete.

> [!error] Overwriting a file that failed to decode
> Starting empty is fine; saving the empty value over the damaged file destroys whatever was recoverable. Move it aside first.

> [!error] Saving a full path
> The container's path can change between installs and restores. Save a path relative to a standard directory and rebuild the URL at launch (Module 21).

## Exercises

````exercise
id: m31-l02-e1
type: prediction
prompt: "Registered defaults, set values and removed keys on a throwaway suite. What does the program print?"
code: |
  import Foundation

  let suiteName = "academy.m31.prediction.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!

  defaults.register(defaults: ["volume": 5])
  print(defaults.integer(forKey: "volume"))

  defaults.set(8, forKey: "volume")
  defaults.register(defaults: ["volume": 3])
  print(defaults.integer(forKey: "volume"))

  defaults.removeObject(forKey: "volume")
  print(defaults.integer(forKey: "volume"))

  print(defaults.integer(forKey: "brightness"))
  print(defaults.object(forKey: "brightness") == nil)

  defaults.removePersistentDomain(forName: suiteName)
output: |
  5
  8
  3
  0
  true
solution: |
  - Nothing is set, so the registered `5` is returned.
  - `set(8, …)` writes to the suite's own domain. Registering `3` replaces the registered value, but the registration domain is searched after the written one, so `8` still wins.
  - After `removeObject`, the read falls through to the registration domain, which now holds `3`.
  - `brightness` was never set or registered: `integer(forKey:)` returns `0`.
  - …and `object(forKey:)` returns `nil`, which is how you tell "missing" from "0".

  ```output
  5
  8
  3
  0
  true
  ```
````

````exercise
id: m31-l02-e2
type: comprehension
prompt: "You want to remember the last three search queries, as an array of a small Codable struct with the query text and a date. What's the right way to store them in UserDefaults?"
choices:
  - text: "Encode the array with JSONEncoder and store the resulting Data; decode it after data(forKey:)."
    correct: true
    why: "Apple says other types must be archived to Data first, and three small items are well within what a setting should hold."
  - text: "Pass the array of structs directly to set(_:forKey:)."
    correct: false
    why: "A custom struct isn't a property-list type. Apple's documentation says to archive such values to Data first."
  - text: "Store each struct under its own key: search0, search1, search2."
    correct: false
    why: "Each value is still a struct, and keeping three keys in step (and deleting the extras) is more fragile than one encoded array."
  - text: "Don't use UserDefaults; recent searches always need a database."
    correct: false
    why: "Three short strings with dates are a perfectly sized setting. A database earns its place when you query many records."
solution: |
  Encode to `Data`. `UserDefaults` accepts property-list types only, and Apple's guidance for anything else is to "archive them to a Data object first and store that object instead". Keep the array capped at three so it stays a setting and doesn't turn into records.
````

````exercise
id: m31-l02-e3
type: fill-in
prompt: "Complete the save function so it creates the folder if needed and replaces the file in one step, with complete file protection."
code: |
  func save(_ library: Library, to url: URL) throws {
      let data = try JSONEncoder().encode(library)
      try FileManager.default.createDirectory(
          at: url.[[1]](),
          withIntermediateDirectories: [[2]])
      try data.write(to: url, options: [.[[3]], .[[4]]])
  }
blanks:
  - id: "1"
    answers: ["deletingLastPathComponent"]
  - id: "2"
    answers: ["true"]
  - id: "3"
    answers: ["atomic"]
  - id: "4"
    answers: ["completeFileProtection"]
solution: |
  `url.deletingLastPathComponent()` is the folder that contains the file. `withIntermediateDirectories: true` creates any missing parent folders and doesn't fail if the folder already exists. `.atomic` writes to an auxiliary file and swaps it in, and `.completeFileProtection` makes the file unreadable while the device is locked. Blanks 3 and 4 can appear in either order in the set; the order doesn't matter to an option set.
````

````exercise
id: m31-l02-e4
type: solve
prompt: "Write a `GoalSettings` struct like the lesson's `ReadingSettings` with two settings: `dailyGoalMinutes: Int` (registered default 20, clamped to 5...240 when set) and `lastOpenedBookID: Int?` (no default; `nil` when nothing is stored; setting `nil` removes the key). Test it against a throwaway suite: print both values at the start, after setting 1 and 42, and after setting 300 and nil. Print `none` for a nil book ID."
starter: |
  import Foundation

  struct GoalSettings {
      let defaults: UserDefaults
      // Keys, registerDefaults(in:), and the two properties.
  }
rubric:
  - Keys are private constants in one place.
  - dailyGoalMinutes is clamped on write and falls back to the registered default.
  - lastOpenedBookID distinguishes "nothing stored" from a value, using object(forKey:), and setting nil removes the key.
  - The test uses a unique suite and removes its persistent domain at the end.
solution: |
  The optional setting can't use `integer(forKey:)`, which would turn "nothing stored" into 0. `object(forKey:) as? Int` gives `nil` when the key is missing.

  ```swift
  import Foundation

  struct GoalSettings {
      private enum Key {
          static let dailyGoalMinutes = "goals.dailyGoalMinutes"
          static let lastOpenedBookID = "goals.lastOpenedBookID"
      }

      let defaults: UserDefaults

      static func registerDefaults(in defaults: UserDefaults) {
          defaults.register(defaults: [Key.dailyGoalMinutes: 20])
      }

      var dailyGoalMinutes: Int {
          get { defaults.integer(forKey: Key.dailyGoalMinutes) }
          nonmutating set { defaults.set(min(max(newValue, 5), 240), forKey: Key.dailyGoalMinutes) }
      }

      var lastOpenedBookID: Int? {
          get { defaults.object(forKey: Key.lastOpenedBookID) as? Int }
          nonmutating set {
              if let newValue {
                  defaults.set(newValue, forKey: Key.lastOpenedBookID)
              } else {
                  defaults.removeObject(forKey: Key.lastOpenedBookID)
              }
          }
      }
  }

  let suiteName = "academy.m31.goals.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  GoalSettings.registerDefaults(in: defaults)
  let settings = GoalSettings(defaults: defaults)

  func describe(_ settings: GoalSettings) -> String {
      "\(settings.dailyGoalMinutes) min, book \(settings.lastOpenedBookID.map(String.init) ?? "none")"
  }

  print(describe(settings))
  settings.dailyGoalMinutes = 1
  settings.lastOpenedBookID = 42
  print(describe(settings))
  settings.dailyGoalMinutes = 300
  settings.lastOpenedBookID = nil
  print(describe(settings))

  defaults.removePersistentDomain(forName: suiteName)
  ```

  ```output
  20 min, book none
  5 min, book 42
  240 min, book none
  ```

  Setting `nil` removes the key rather than storing a placeholder, so the next read is `nil` again. There's no registered default for the book ID on purpose: a registered value would make "nothing opened yet" impossible to represent.
````

````exercise
id: m31-l02-e5
type: find-errors
prompt: "A drafts feature saves the person's text to disk. Which of these are real problems?"
code: |
  final class DraftStore {
      let fileURL = URL(fileURLWithPath: UserDefaults.standard.string(forKey: "draftPath")!)

      func textDidChange(_ text: String) {
          try? Data(text.utf8).write(to: fileURL)
      }

      func loadDraft() -> String {
          guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
          let data = try! Data(contentsOf: fileURL)
          return String(decoding: data, as: UTF8.self)
      }
  }
choices:
  - text: "The full file path is saved in UserDefaults and reused."
    correct: true
    why: "The container path isn't stable across reinstalls and restores. Store a relative path and rebuild it from a standard directory."
  - text: "The write isn't atomic and its error is thrown away."
    correct: true
    why: "A crash mid-write truncates the only copy of the draft, and try? hides a failed save from everyone."
  - text: "It writes the whole file on every keystroke."
    correct: true
    why: "Each change rewrites the file, on the caller's thread. Save when typing pauses or the screen goes away."
  - text: "fileExists followed by try! Data(contentsOf:) can crash."
    correct: true
    why: "The file can disappear or become unreadable between the check and the read (for example, a protected file while locked), and try! turns that into a crash."
  - text: "Drafts should be in the Keychain."
    correct: false
    why: "Drafts are user content, not credentials. A protected file is right; the Keychain is for small secrets."
rubric:
  - Identifies the saved absolute path.
  - Identifies the non-atomic write with a swallowed error.
  - Identifies the per-keystroke write.
  - Identifies the check-then-read race and the try!.
solution: |
  Four real problems:

  - **Absolute path in defaults.** Save `"Drafts/current.txt"` and build the URL from `URL.applicationSupportDirectory` each launch.
  - **Non-atomic, silent write.** Use `.atomic` (and a protection level), and surface failures so the screen can say "couldn't save".
  - **Write per keystroke.** Debounce: save after a short pause in typing, and when the screen disappears or the app moves to the background.
  - **Check, then `try!`.** Read directly and handle `CocoaError.fileReadNoSuchFile` as "no draft"; any other error is reported, not crashed on.

  The Keychain option is a distractor: it's for credentials, not documents.
````

````exercise
id: m31-l02-e6
type: comprehension
prompt: "A podcast app downloads episodes in the background while the phone is locked and writes each episode to a new file. The files aren't personal data, but you want them encrypted at rest. Which protection level fits?"
choices:
  - text: "completeUnlessOpen"
    correct: true
    why: "Apple says files with this level can be created while the device is locked, and are encrypted once closed. It's the strongest level that allows writing new files while locked."
  - text: "complete"
    correct: false
    why: "Files can't be read or written while the device is locked, so background downloads would fail."
  - text: "none"
    correct: false
    why: "It works, but gives up encryption at rest that you can have for free."
  - text: "Store the episodes in the Keychain instead."
    correct: false
    why: "The Keychain is for small secrets, not media files."
solution: |
  `completeUnlessOpen`. Apple's description: files with this protection "can be created while the device is locked, but once closed, cannot be opened again until the device is unlocked", and a file opened while unlocked stays accessible after locking. That fits a background download. `completeUntilFirstUserAuthentication`, the default, would also work and is a reasonable choice if the app must also read the episodes while locked (to play them from the lock screen, say). `complete` would break the download.
````

````exercise
id: m31-l02-e7
type: explain
prompt: "Explain why `JSONFile.load()` from the lesson catches only `CocoaError.fileReadNoSuchFile` and lets every other error through, instead of returning nil for any failure."
code: |
  func load() throws -> Value? {
      let data: Data
      do {
          data = try Data(contentsOf: url)
      } catch CocoaError.fileReadNoSuchFile {
          return nil
      }
      return try JSONDecoder().decode(Value.self, from: data)
  }
rubric:
  - A missing file is an expected state (first launch) and means "no data yet".
  - Other errors (damaged content, permissions, locked protected file) mean data exists but can't be read.
  - Returning nil for those would make the caller start empty and probably save over the real data.
  - "The caller is in a better position to choose: retry later, move the file aside, or tell the person."
solution: |
  A missing file is normal: on first launch, or after the person deletes everything, there's nothing to read, and "empty" is the right answer. Every other failure means the data exists but can't be read right now: it's damaged, the app lacks permission, or it's a `.complete` file and the device is locked. If `load()` returned `nil` for those, the caller would start with an empty library and the next `save` would overwrite the real one. Throwing hands the decision to code that knows the context: a background task can retry after unlock, the launch path can move a damaged file aside and tell the person, and nothing silently destroys data.
````

## Summary

- `UserDefaults` holds small, non-sensitive settings in property-list types. Apple says it's unencrypted and backed up, and `synchronize()` is unnecessary.
- Register defaults at every launch. A read checks the values you set first, then the registered fallbacks. A missing key reads as `0` or `false`, so use `object(forKey:)` when that matters.
- Put settings behind a typed struct that receives its `UserDefaults`, and test it with a unique suite you remove afterward.
- Share settings and files with extensions through an app group: a suite with the group's name, and the group container for files.
- Write files with `.atomic`, treat "no such file" as empty, and move a damaged file aside instead of overwriting it.
- Choose a protection level per file from when it must be readable: `complete` for foreground-only personal data, weaker levels only for what background work needs.
