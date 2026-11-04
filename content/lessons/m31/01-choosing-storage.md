---
id: m31-l01
title: Choosing where data lives
description: "Pick a store for each piece of data an app keeps. You sort data by kind, size, sensitivity, how it's read and whether it syncs, see what UserDefaults, files, the Keychain, Core Data, SwiftData and caches are each for, choose between SwiftData and Core Data on an iOS 17 baseline, and split one feature's data across several stores."
module: m31
order: 1
level: advanced
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l06]
objectives:
  - Describe a piece of app data by its kind, size, sensitivity, read pattern and sync needs.
  - Say what UserDefaults, files, the Keychain, Core Data, SwiftData, the iCloud key-value store and a cache are each for, and what each is bad at.
  - Choose between SwiftData and Core Data for a project with an iOS 17 deployment target, and check API availability before relying on it.
  - Split one feature's data across several stores and name the source of truth for each piece.
terms:
  - term: Persistent store
    definition: "Where data survives the app quitting: a file on disk, a SQLite database, the Keychain. Memory is not a persistent store."
  - term: Source of truth
    definition: "The copy of a piece of data that wins when copies disagree. Everything else (caches, view state, a local mirror of a server) is derived from it."
  - term: Object graph
    definition: "Model objects and the relationships between them: books, their notes, the shelves they're on. Core Data and SwiftData manage object graphs; UserDefaults and plain files don't."
  - term: Cache
    definition: "A copy of data that can be recomputed or downloaded again, kept to save time. Losing it costs speed, never data."
  - term: Data Protection
    definition: "iOS's per-file encryption tied to the device passcode. Each file has a protection level that says when it can be read; lesson 2 shows how to set it."
mastery:
  - Given a piece of data, answer the five questions (kind, size, sensitivity, reads, sync) and name the store.
  - Explain why a refresh token belongs in the Keychain and a thumbnail belongs in a cache, using what each store guarantees.
  - Justify SwiftData or Core Data for a given project, citing deployment target, UI framework and existing code.
  - Draw a storage plan for a feature with one store per piece of data and the source of truth marked.
resources: [foundation-userdefaults, swiftdata, keychain-services, apple-platform-security, foundation-nscache]
cards:
  - id: m31-l01-c1
    front: Name the five questions that pick a store.
    back: "What kind of data is it (setting, user content, credential, records, derived)? How big is it and how does it grow? How sensitive is it? How will you read it (all at once, or by query)? Does it need to sync or be shared with an extension? Then ask what happens if it's lost."
  - id: m31-l01-c2
    front: What is UserDefaults for, and what must never go in it?
    back: "Small settings in property-list types (Bool, Int, String, Date, Data, arrays and dictionaries of those). Apple says it stores data unencrypted and includes it in backups, so never personal or sensitive data: that goes in the Keychain."
  - id: m31-l01-c3
    front: SwiftData or Core Data for a new SwiftUI app with an iOS 17 deployment target?
    back: "SwiftData: models are plain Swift classes with @Model, they're Observable, and @Query feeds SwiftUI. Keep Core Data for existing Core Data apps and UIKit code built on NSFetchedResultsController. Check each SwiftData API's availability: some (history, #Unique, #Index) are iOS 18 or later."
  - id: m31-l01-c4
    front: What's the rule for anything in a cache?
    back: "It's never the only copy. The system can purge Library/Caches and NSCache evicts under memory pressure, so every read needs a fallback: recompute it or download it again."
---

## The idea in one sentence

Every piece of data an app keeps has a kind, a size, a sensitivity, a way it gets read and maybe a need to sync, and those answers pick where it lives; a real app ends up using several stores at once, each for what it's good at.

> [!note] Sources and what was run
> Store descriptions come from Apple's documentation for `UserDefaults`, `NSUbiquitousKeyValueStore`, `NSCache`, Keychain services, SwiftData ("Preserving your app's model data across launches") and Core Data ("Setting up a Core Data stack"), plus Apple Platform Security, read in November 2026. Availability comes from the platform data in those pages. The decision function was compiled and run with Swift 6.3.

## The stores you can choose from

You met the container's directories in Module 21 and the Keychain briefly in Module 30. Here's the full set, with what each one is for:

| Store | Good for | Bad for | What you should know |
| --- | --- | --- | --- |
| `UserDefaults` | Small settings and flags: sort order, "has seen onboarding" | Secrets, records, anything that grows | Property-list types only. Apple: it "stores information on disk in an unencrypted format". Backed up. |
| Files (`Codable` → JSON) | Documents, exports, a modest list you always load whole | Querying part of a large collection | You own the format, atomic writes and migrations. |
| Keychain | Passwords, tokens, keys | Anything large or not secret | Encrypted by the system; each item has an accessibility class. |
| Core Data | Large object graphs, queries, relationships, loading part of the data | Three settings | Mature, works with UIKit and SwiftUI; the model lives in an Xcode model file. |
| SwiftData | The same jobs as Core Data, with models written as Swift classes | Apps that must run below iOS 17 | iOS 17+. `@Model`, `@Query`, Swift predicates. |
| Cache (`NSCache` in memory, files in `Library/Caches`) | Data you can recompute or download again: thumbnails, responses | The only copy of anything | `NSCache` evicts under memory pressure; the system purges `Library/Caches`. |
| iCloud key-value store (`NSUbiquitousKeyValueStore`) | A few settings that follow the person across devices | Records, secrets | At most 1024 keys and 1 MB in total, per Apple. Needs an entitlement. |

Two more options sit outside the table. Some data belongs on your server and nowhere on the device, such as a full card number your payment provider tokenizes for you. And some state is fine in memory only: the current scroll position of a list is rarely worth persisting.

## Five questions that pick the store

Ask them about each piece of data separately, not about "the app's data":

1. **What kind of data is it?** A setting (sort order), user content (a document they wrote), a credential (a refresh token), records (hundreds of reading notes), or derived data (a resized cover image).
2. **How big is it, and how does it grow?** Ten bytes forever is a setting. A list that grows with use needs a store that can load part of it.
3. **How sensitive is it?** Credentials go in the Keychain. Personal data in files or a database gets a strong Data Protection level (lesson 2).
4. **How will you read it?** All at once at launch (a file is fine), or "unread notes for this book, newest first" (a database, which can filter and sort without loading everything).
5. **Does it sync or get shared?** With a widget or extension: an app group container. Across the person's devices: CloudKit, the iCloud key-value store or your own server.

Then one more: **what happens if it's lost?** If the answer is "we download it again", it's a cache, and it goes where the system may delete it. If the answer is "the person loses their work", it's a source of truth, and it goes somewhere backed up, with writes that can't leave it half-written.

## The guide as code

Here are the rules as a function. It's a simplification, but writing the rules down makes their order visible: credentials and derived data are decided by kind alone, before size or queries matter.

```swift
enum DataKind {
    case setting, userContent, credential, records, derived
}

enum Store {
    case userDefaults, iCloudKeyValueStore, keychain, file, database, cache
}

struct DataProfile {
    let name: String
    let kind: DataKind
    let approximateBytes: Int
    let isSensitive: Bool
    let needsQueries: Bool
    let syncsAcrossDevices: Bool
}

func recommendedStore(for data: DataProfile) -> Store {
    switch data.kind {
    case .credential:
        return .keychain
    case .derived:
        return .cache
    case .setting:
        if data.isSensitive { return .keychain }
        return data.syncsAcrossDevices ? .iCloudKeyValueStore : .userDefaults
    case .userContent:
        return data.needsQueries ? .database : .file
    case .records:
        return data.needsQueries || data.approximateBytes > 1_000_000 ? .database : .file
    }
}

let examples = [
    DataProfile(name: "refresh token", kind: .credential, approximateBytes: 900,
                isSensitive: true, needsQueries: false, syncsAcrossDevices: false),
    DataProfile(name: "sort order", kind: .setting, approximateBytes: 10,
                isSensitive: false, needsQueries: false, syncsAcrossDevices: false),
    DataProfile(name: "last page read", kind: .setting, approximateBytes: 8,
                isSensitive: false, needsQueries: false, syncsAcrossDevices: true),
    DataProfile(name: "reading notes", kind: .records, approximateBytes: 5_000_000,
                isSensitive: false, needsQueries: true, syncsAcrossDevices: false),
    DataProfile(name: "exported log", kind: .userContent, approximateBytes: 200_000,
                isSensitive: false, needsQueries: false, syncsAcrossDevices: false),
    DataProfile(name: "cover thumbnails", kind: .derived, approximateBytes: 40_000_000,
                isSensitive: false, needsQueries: false, syncsAcrossDevices: false),
]

for data in examples {
    print("\(data.name): \(recommendedStore(for: data))")
}
```

```output
refresh token: keychain
sort order: userDefaults
last page read: iCloudKeyValueStore
reading notes: database
exported log: file
cover thumbnails: cache
```

Line by line:

- `.credential` returns `.keychain` without looking at anything else. A token is small, but size isn't why it goes there: the Keychain is the only store here that's encrypted for you and has accessibility rules.
- `.derived` returns `.cache` even for 40 MB, because losing it costs only time.
- A setting that must follow the person across devices goes to the iCloud key-value store; otherwise `UserDefaults`. A "sensitive setting" (a PIN, say) is really a credential, so it goes to the Keychain.
- Records go to a database when you need to query them, or once they're too big to load whole. The 1 MB threshold is a judgment call, not an Apple limit.

The function also shows what it can't answer: a sensitive 5 MB medical history goes to `.database`, which is right, but the decision isn't finished until you also set its file protection level. Real decisions have more than one output.

## SwiftData or Core Data?

The course's deployment target is iOS 17, so both are available. SwiftData's documentation lists `@Model`, `ModelContainer`, `ModelContext`, `FetchDescriptor` and `@Query` as available from iOS 17.0.

- **Choose SwiftData** for a new app, especially a SwiftUI one. Models are Swift classes marked `@Model`, they're `Observable`, `@Query` keeps a view's results up to date, and schema versions are Swift types. You'll build with it in lesson 5.
- **Keep Core Data** in an app that already has a Core Data model and a lot of code around it, or UIKit screens built on `NSFetchedResultsController`. Lesson 4 covers it, because you'll meet it in existing codebases.
- **Both at once** is possible: Apple's "Adopting SwiftData for a Core Data app" sample has a Core Data app and a SwiftData widget writing the same store file. That lets a team move one feature at a time.

> [!version] Check availability per API
> SwiftData has grown every year. Its documentation marks persistent history (`HistoryDescriptor`, `fetchHistory(_:)`), custom data stores (`DataStore`), and the `#Unique` and `#Index` macros as iOS 18.0 and later, and sectioned `@Query` results as iOS 27.0. On an iOS 17 baseline, you need `if #available` around those or a different approach. Check the platform list on each symbol's page before using it.

## One feature, several stores

Here's where the data of a reading app ends up. The app is "Bookshelf", the same one whose API client you built in Module 30.

| Data | Store | Source of truth |
| --- | --- | --- |
| Refresh token | Keychain, `AfterFirstUnlockThisDeviceOnly` | The auth server (it can revoke it) |
| Sort order, "show covers" | `UserDefaults` | The device |
| Last page read, per book | iCloud key-value store | Whichever device wrote last |
| Books, shelves, reading notes | SwiftData | The server for books; the device for notes until they sync |
| Cover thumbnails | Memory cache + `Library/Caches` | The image server |
| Exported reading log (PDF) | A file in `Documents` | The device |

Two things to notice. Each row is decided independently: there's no single "Bookshelf database". And the source of truth isn't always the device: a cached book list is a copy of the server's, so the app must expect it to be stale and refresh it (lesson 6).

## Common mistakes

> [!error] Tokens and passwords in UserDefaults
> Apple's own documentation says the defaults system stores data unencrypted and is included in backups, and tells you to put sensitive information in the Keychain. That includes "small" secrets like API keys and PINs.

> [!error] Records in UserDefaults
> An array of 2,000 notes in `UserDefaults` works in a demo. It has no queries, no partial loading and no migrations, and every read gets the whole array back. Records go in a file you load whole while they're small, or a database once you query them.

> [!error] A database for three settings
> Core Data or SwiftData for "dark mode on" and "sort by title" adds a model, a container and migrations for data that `UserDefaults` handles in one line each.

> [!error] The only copy in a cache
> Anything in `Library/Caches` can be purged and anything in `NSCache` can be evicted. A user's draft saved there is a draft that disappears. Caches hold copies; sources of truth go in `Application Support` or `Documents`.

> [!error] Large blobs inside database rows
> Storing full-size photos as `Data` attributes makes every fetch that touches them slow. Both frameworks have a switch for this: `@Attribute(.externalStorage)` in SwiftData and "Allows External Storage" (`allowsExternalBinaryDataStorage`) in Core Data let the framework keep big values in separate files.

## Exercises

````exercise
id: m31-l01-e1
type: comprehension
prompt: "Bookshelf's sign-in returns a refresh token that must survive app restarts and be readable by a background refresh after the person has unlocked the phone once. Where should it go?"
choices:
  - text: "The Keychain, with an accessibility class that allows reads after first unlock and doesn't migrate to other devices."
    correct: true
    why: "The Keychain is encrypted by the system, and the accessibility class matches the background requirement. The ThisDeviceOnly variant keeps it out of backups restored to other devices."
  - text: "UserDefaults, under a key that isn't obvious, like \"k1\"."
    correct: false
    why: "A strange key name hides nothing. Apple says UserDefaults is stored unencrypted and backed up."
  - text: "A JSON file in Application Support with complete file protection."
    correct: false
    why: "Complete protection makes the file unreadable while the device is locked, which breaks background refreshes, and the file is still included in backups. The Keychain exists for credentials."
  - text: "In memory only; sign in again at every launch."
    correct: false
    why: "That's an option for the short-lived access token, not for the refresh token, whose whole job is to survive restarts."
solution: |
  The Keychain. It's the store built for credentials, and its accessibility classes let you say exactly when the item can be read. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` allows background reads once the device has been unlocked since boot and keeps the token from being restored onto a different device. Lesson 3 covers the classes in detail.
````

````exercise
id: m31-l01-e2
type: prediction
prompt: "The same decision function with four new profiles. What does the program print?"
code: |
  enum DataKind {
      case setting, userContent, credential, records, derived
  }

  enum Store {
      case userDefaults, iCloudKeyValueStore, keychain, file, database, cache
  }

  struct DataProfile {
      let name: String
      let kind: DataKind
      let approximateBytes: Int
      let isSensitive: Bool
      let needsQueries: Bool
      let syncsAcrossDevices: Bool
  }

  func recommendedStore(for data: DataProfile) -> Store {
      switch data.kind {
      case .credential:
          return .keychain
      case .derived:
          return .cache
      case .setting:
          if data.isSensitive { return .keychain }
          return data.syncsAcrossDevices ? .iCloudKeyValueStore : .userDefaults
      case .userContent:
          return data.needsQueries ? .database : .file
      case .records:
          return data.needsQueries || data.approximateBytes > 1_000_000 ? .database : .file
      }
  }

  let profiles = [
      DataProfile(name: "app PIN", kind: .setting, approximateBytes: 4,
                  isSensitive: true, needsQueries: false, syncsAcrossDevices: true),
      DataProfile(name: "500 bookmarks", kind: .records, approximateBytes: 60_000,
                  isSensitive: false, needsQueries: false, syncsAcrossDevices: false),
      DataProfile(name: "search index", kind: .derived, approximateBytes: 8_000_000,
                  isSensitive: false, needsQueries: true, syncsAcrossDevices: false),
      DataProfile(name: "journal entries", kind: .userContent, approximateBytes: 300_000,
                  isSensitive: true, needsQueries: true, syncsAcrossDevices: false),
  ]

  for profile in profiles {
      print("\(profile.name) -> \(recommendedStore(for: profile))")
  }
output: |
  app PIN -> keychain
  500 bookmarks -> file
  search index -> cache
  journal entries -> database
solution: |
  - **app PIN**: a setting, but `isSensitive` is checked first in that case, so `keychain`. `syncsAcrossDevices` is never read.
  - **500 bookmarks**: records, no queries, 60 KB is under the 1 MB threshold, so `file`.
  - **search index**: `.derived` returns `cache` before anything else, even though it needs queries. That's correct: an index you can rebuild is still a cache, even if it's a SQLite file.
  - **journal entries**: user content that needs queries, so `database`. `isSensitive` is ignored in this case, which is the gap the lesson pointed out: the function picks the store but not the file protection level.

  ```output
  app PIN -> keychain
  500 bookmarks -> file
  search index -> cache
  journal entries -> database
  ```
````

````exercise
id: m31-l01-e3
type: comprehension
multiple: true
prompt: "Which of these can safely live only in a cache (memory or Library/Caches)? Select all that apply."
choices:
  - text: "Thumbnails generated from photos the app also stores in full size."
    correct: true
    why: "They can be regenerated from the originals."
  - text: "The last API response for the book list, when the app always refreshes from the server."
    correct: true
    why: "It's a copy of the server's data. Losing it means one more request."
  - text: "A note the person typed while offline that hasn't been uploaded yet."
    correct: false
    why: "This is the only copy anywhere. It needs a persistent store until the server confirms it."
  - text: "Downloaded audiobook files the person explicitly saved for a flight."
    correct: false
    why: "They can be downloaded again, but not on the plane. The person asked for them to stay, so they go in Application Support, excluded from backup, as Module 21 showed."
solution: |
  The test is "if this disappears right now, what's lost?" Thumbnails and cached responses cost time to rebuild and nothing else. The unsent note is a source of truth. The saved audiobooks are re-downloadable in principle, but the person relied on them being there, so the system mustn't purge them.
````

````exercise
id: m31-l01-e4
type: find-errors
prompt: "A teammate's storage code for a journaling app. Which choices are real problems?"
code: |
  let defaults = UserDefaults.standard

  // After sign-in
  defaults.set(session.accessToken, forKey: "accessToken")
  defaults.set(session.refreshToken, forKey: "refreshToken")

  // Every time an entry is saved
  var entries = defaults.array(forKey: "entries") as? [Data] ?? []
  entries.append(try JSONEncoder().encode(entry))
  defaults.set(entries, forKey: "entries")

  // Settings
  defaults.set(true, forKey: "remindersEnabled")

  // Downloaded mood icons, re-downloadable
  let iconURL = URL.cachesDirectory.appending(path: "icons/happy.png")
choices:
  - text: "The tokens are stored in UserDefaults."
    correct: true
    why: "UserDefaults is unencrypted and backed up. Tokens go in the Keychain."
  - text: "Journal entries are appended to an array in UserDefaults."
    correct: true
    why: "Records that grow without limit, read whole on every save, with no queries or migrations. They belong in a file while small, or a database."
  - text: "remindersEnabled is stored in UserDefaults."
    correct: false
    why: "A Bool setting is exactly what UserDefaults is for."
  - text: "The icons are saved in the Caches directory."
    correct: false
    why: "They're re-downloadable, so Caches is right, as long as the code handles them being purged."
rubric:
  - Flags the tokens in UserDefaults and names the Keychain as the fix.
  - Flags the growing array of entries and proposes a file or a database.
  - Accepts the Bool setting and the cached icons as correct.
solution: |
  Two real problems. The tokens are credentials in an unencrypted, backed-up store; they go in the Keychain (lesson 3). The entries are user content that grows forever; they belong in a database (SwiftData, lesson 5), especially since a journal gets searched by date and mood. The setting and the cached icons are fine where they are.
````

````exercise
id: m31-l01-e5
type: solve
prompt: "Extend the decision function so it returns a plan instead of a bare store: `struct StoragePlan { let store: Store; let note: String? }`. Add `sharedWithExtension: Bool` to `DataProfile`. Rules: everything from the lesson still applies; sensitive data that lands in `.file` or `.database` gets the note \"complete file protection\"; data shared with an extension that lands in `.userDefaults`, `.file` or `.database` gets the note \"app group container\" (if both apply, join them with \", \"). Print the plan for a sensitive journal (user content, queries, shared with a widget), the sort-order setting shared with a widget, and the refresh token."
starter: |
  enum DataKind {
      case setting, userContent, credential, records, derived
  }

  enum Store {
      case userDefaults, iCloudKeyValueStore, keychain, file, database, cache
  }

  // Add sharedWithExtension to DataProfile, write StoragePlan and plan(for:).
rubric:
  - The store choice reuses the lesson's rules unchanged.
  - Notes are added only for the stores where they make sense.
  - Both notes can appear together, in a stable order.
  - The output shows all three plans.
solution: |
  Keep the store decision as it was and compute the notes afterward from the chosen store, so the two concerns stay separate.

  ```swift
  enum DataKind {
      case setting, userContent, credential, records, derived
  }

  enum Store {
      case userDefaults, iCloudKeyValueStore, keychain, file, database, cache
  }

  struct DataProfile {
      let name: String
      let kind: DataKind
      let approximateBytes: Int
      let isSensitive: Bool
      let needsQueries: Bool
      let syncsAcrossDevices: Bool
      let sharedWithExtension: Bool
  }

  struct StoragePlan {
      let store: Store
      let note: String?
  }

  func recommendedStore(for data: DataProfile) -> Store {
      switch data.kind {
      case .credential:
          return .keychain
      case .derived:
          return .cache
      case .setting:
          if data.isSensitive { return .keychain }
          return data.syncsAcrossDevices ? .iCloudKeyValueStore : .userDefaults
      case .userContent:
          return data.needsQueries ? .database : .file
      case .records:
          return data.needsQueries || data.approximateBytes > 1_000_000 ? .database : .file
      }
  }

  func plan(for data: DataProfile) -> StoragePlan {
      let store = recommendedStore(for: data)
      var notes: [String] = []
      if data.isSensitive && (store == .file || store == .database) {
          notes.append("complete file protection")
      }
      if data.sharedWithExtension && [Store.userDefaults, .file, .database].contains(store) {
          notes.append("app group container")
      }
      return StoragePlan(store: store, note: notes.isEmpty ? nil : notes.joined(separator: ", "))
  }

  let profiles = [
      DataProfile(name: "journal", kind: .userContent, approximateBytes: 300_000, isSensitive: true,
                  needsQueries: true, syncsAcrossDevices: false, sharedWithExtension: true),
      DataProfile(name: "sort order", kind: .setting, approximateBytes: 10, isSensitive: false,
                  needsQueries: false, syncsAcrossDevices: false, sharedWithExtension: true),
      DataProfile(name: "refresh token", kind: .credential, approximateBytes: 900, isSensitive: true,
                  needsQueries: false, syncsAcrossDevices: false, sharedWithExtension: false),
  ]

  for profile in profiles {
      let result = plan(for: profile)
      print("\(profile.name): \(result.store)" + (result.note.map { " (\($0))" } ?? ""))
  }
  ```

  ```output
  journal: database (complete file protection, app group container)
  sort order: userDefaults (app group container)
  refresh token: keychain
  ```

  The refresh token gets no note: the Keychain has its own protection (accessibility classes) and its own sharing mechanism (access groups), which lesson 3 covers. A widget that needs complete protection has a catch, too: it can't read the journal while the device is locked, so a real design might give the widget a smaller, less sensitive summary.
````

````exercise
id: m31-l01-e6
type: design
prompt: "Design the storage for a habit tracker. It has: the person's habits and every check-in (years of daily records); a home-screen widget that shows today's habits; a setting for the reminder time; an account token for an optional sync server; avatar images downloaded from that server; and a \"streak\" number computed from check-ins. Give each piece a store and a source of truth, and say what changes if the widget must show data while the phone is locked."
rubric:
  - Habits and check-ins go in a database (SwiftData on iOS 17), in an app group container so the widget can read them.
  - The reminder time goes in UserDefaults (a suite in the app group if the widget needs it).
  - The token goes in the Keychain, shared through an access group only if the widget truly needs it.
  - Avatars go in a cache; the streak is derived and either computed on read or cached, never treated as a source of truth.
  - Notes that complete file protection makes the store unreadable while locked, so the widget needs a weaker protection class on a smaller dataset, or must show placeholder content.
solution: |
  A good plan:

  - **Habits and check-ins**: SwiftData (lesson 5), store in the app group container so the app and the widget open the same store. Source of truth: the device, until synced; then the server and the device reconcile (lesson 6).
  - **Reminder time**: `UserDefaults`. If the widget shows it, use `UserDefaults(suiteName:)` with the app group identifier (lesson 2).
  - **Account token**: Keychain. The widget probably doesn't need it at all; if it does, share it through a keychain access group rather than copying it somewhere weaker.
  - **Avatars**: cache, memory plus `Library/Caches`. Source of truth: the server.
  - **Streak**: derived from check-ins. Compute it when needed, or cache it with the check-in count it was computed from, so you can tell when it's stale. Never store it as the truth; when the two disagree, recompute from check-ins.

  **Locked phone**: with complete file protection, the database can't be opened while the device is locked, so the widget would fail. Options: give the store `completeUntilFirstUserAuthentication` (the default protection level) if the data isn't very sensitive, or have the app write a small, separate summary file for the widget with a weaker class, keeping the full history strongly protected. The choice is a trade-off the product owner should hear about.
````

````exercise
id: m31-l01-e7
type: explain
prompt: "A colleague says: \"Our cached book list is always up to date, because we save it every time we fetch.\" Here's their code. Explain what \"source of truth\" means for that list and two situations in which the cached copy is wrong."
code: |
  func refreshBooks() async throws -> [Book] {
      let books = try await api.books()
      try cache.save(books)          // "always up to date"
      return books
  }

  func booksAtLaunch() -> [Book] {
      (try? cache.load()) ?? []      // shown before any refresh
  }
rubric:
  - States that the server's list is the source of truth and the cache is a derived copy.
  - Gives a case where the server changed after the last fetch (another device, an admin, another user).
  - Gives a case where the app shows the cache without having fetched (offline launch, a failed refresh).
  - Concludes that the app must treat the cache as possibly stale and refresh or show its age.
solution: |
  The source of truth for the book list is the server: it's the copy that wins when the two disagree. The cache is a copy made at the moment of the last fetch, so it's exactly as current as that fetch.

  It's wrong whenever the server changes after the fetch: the person adds a book on their iPad, an admin removes a title, a price changes. And it's wrong whenever the app shows it without fetching first: launching offline, or a refresh that fails with the stale-data fallback from Module 30. "We save it every time we fetch" keeps the cache in step with the fetches, not with the server. That's why lesson 6 attaches a time to every cached entry and decides, by age, whether to use it, refresh it, or show it with a warning.
````

## Summary

- Decide per piece of data, not per app. Ask its kind, size, sensitivity, how it's read and whether it syncs, then what happens if it's lost.
- `UserDefaults` is for small, non-sensitive settings. Apple says it's unencrypted and backed up.
- Files suit documents and small collections you load whole. The Keychain is for credentials. Core Data and SwiftData are for object graphs you query.
- Caches hold copies you can rebuild. They're never the only copy, because the system can purge them.
- On an iOS 17 baseline, choose SwiftData for new work and keep Core Data where it already exists. Check each SwiftData API's availability, because several are iOS 18 or later.
- Mark the source of truth for every piece. A local copy of server data is a cache, however carefully you save it.
