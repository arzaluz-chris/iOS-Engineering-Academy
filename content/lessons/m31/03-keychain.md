---
id: m31-l03
title: The Keychain
description: "Store secrets properly. You see how a generic password item is identified, add, read, update and delete items with the SecItem functions and their status codes, choose an accessibility class from when the secret must be readable, keep the blocking calls off the main actor in an actor, and put a small typed, testable wrapper on top: the full version of the token store you sketched in Module 30."
module: m31
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l02]
objectives:
  - Describe a generic password item by its class, its identifying attributes and its data.
  - Add, read, update and delete items with SecItemAdd, SecItemCopyMatching, SecItemUpdate and SecItemDelete, and handle the status codes each one returns.
  - Save with update-then-add instead of delete-then-add, and explain the difference.
  - Choose an accessibility class from when the secret must be readable and whether it may move to another device.
  - Wrap the Keychain in an actor behind a small protocol, add typed Codable access on top, and test it with an in-memory store.
terms:
  - term: Keychain item
    definition: "One entry in the Keychain: a class (such as a generic password), attributes that describe and identify it, and the secret data, which the system encrypts."
  - term: Generic password
    definition: "The item class (kSecClassGenericPassword) for secrets your app defines: tokens, API keys, passwords not tied to a web server. Identified by its service and account attributes."
  - term: OSStatus
    definition: "The Int32 result code every SecItem function returns. errSecSuccess means success; errSecItemNotFound and errSecDuplicateItem are the ones your code handles routinely."
  - term: Accessibility class
    definition: "The kSecAttrAccessible value of an item. It says when the item can be read (while unlocked, or after the first unlock since boot) and whether it can move to a new device (the ThisDeviceOnly variants can't)."
  - term: Access group
    definition: "The group a Keychain item belongs to. By default it's private to your app; a shared keychain access group or app group lets apps and extensions from the same team share items."
mastery:
  - Write the query dictionary that identifies one generic password by service and account.
  - Implement a save that updates the item when it exists and adds it when SecItemUpdate returns errSecItemNotFound.
  - Treat errSecItemNotFound as "no value" when reading and as success when deleting, and throw on any other non-success status.
  - Pick the accessibility class for a token that a background refresh must read, and for a secret used only in the foreground.
  - Test code that uses secrets against an in-memory store that satisfies the same protocol as the Keychain store.
resources: [keychain-services, apple-platform-security, swift-actor, swift-book-protocols]
cards:
  - id: m31-l03-c1
    front: What identifies a generic password item in the Keychain?
    back: "Its class (kSecClassGenericPassword) plus the service and account attributes. Adding a second item with the same identifying attributes fails with errSecDuplicateItem."
  - id: m31-l03-c2
    front: How should a Keychain save work?
    back: "Call SecItemUpdate with a query for the item and the new data. If it returns errSecItemNotFound, call SecItemAdd with the query plus the data. Apple recommends updating instead of adding duplicates; delete-then-add loses the item's other attributes and has a window with no item at all."
  - id: m31-l03-c3
    front: Which status codes are not errors for a read and a delete?
    back: "errSecItemNotFound. For SecItemCopyMatching it means \"no value stored\" (return nil); for SecItemDelete it means \"already gone\" (success). Everything else other than errSecSuccess is a real failure."
  - id: m31-l03-c4
    front: Which accessibility class for a refresh token used by background refreshes?
    back: "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: readable once the device has been unlocked after boot, even while locked, and not restored onto a different device. The default, WhenUnlocked, fails while the device is locked."
  - id: m31-l03-c5
    front: Why put the SecItem calls in an actor?
    back: "Apple says SecItemAdd, SecItemUpdate, SecItemCopyMatching and SecItemDelete block the calling thread, so calling them on the main actor can hang the UI. An actor runs them off the main actor and serializes read-then-write sequences."
---

## The idea in one sentence

The Keychain is a system-managed, encrypted database of small secrets, and you talk to it through four C functions that take dictionaries and return status codes, so the real work is building the right query, treating "not found" correctly for each call, picking when the item may be read, and hiding all of that behind a small typed API you can test.

> [!note] Sources and what was run
> Quotes and behavior come from Apple's Keychain services documentation: the pages for the four `SecItem` functions, "Adding a password to the keychain", "Updating and deleting keychain items", "Restricting keychain item accessibility", "Sharing access to keychain items among a collection of apps" and each accessibility constant, read in November 2026. The Security framework doesn't exist on Linux, so the Keychain code was type-checked against the iOS SDK but not run. The status-code model and the typed wrapper are pure Swift and were compiled and run with Swift 6.3.

## Where Module 30 left off

Module 30's `RefreshTokenStore` saved a token by deleting any existing item and adding a new one. It works, and it was enough to show the shape. This lesson replaces it with what you'd ship:

- a save that **updates** the item if it exists and adds it otherwise,
- a read and a delete that handle "not found" as a normal answer,
- an accessibility class chosen per store, and changeable on update,
- the blocking calls off the main actor,
- typed `Codable` values instead of raw `Data`,
- a protocol, so code that needs secrets can be tested without the Keychain.

## Items, queries and status codes

A Keychain item has three parts:

- **A class.** For your app's own secrets, `kSecClassGenericPassword`. Apple's "Adding a password" article also uses `kSecClassInternetPassword` for website credentials, and says to use generic passwords when you don't need the extra server-related attributes.
- **Attributes.** For a generic password, `kSecAttrService` (your app or feature, like `"com.example.bookshelf.auth"`) and `kSecAttrAccount` (which secret, like `"refresh-token"`) identify the item. `kSecAttrAccessible` controls when it can be read. Others, like `kSecAttrLabel`, describe it.
- **The data**, under `kSecValueData`, as `Data`. This is the part that's secret.

Every call takes a dictionary. To identify one item, the dictionary holds its class, service and account. The four functions and what they return in normal use:

| Function | Does | Returns besides `errSecSuccess` |
| --- | --- | --- |
| `SecItemAdd` | Adds a new item | `errSecDuplicateItem` if an item with the same identifying attributes exists |
| `SecItemCopyMatching` | Finds items, optionally returning their data or attributes | `errSecItemNotFound` if nothing matches |
| `SecItemUpdate` | Changes **every** item that matches the query | `errSecItemNotFound` if nothing matches |
| `SecItemDelete` | Deletes **every** item that matches the query | `errSecItemNotFound` if nothing matches |

Two details matter. `SecItemUpdate` and `SecItemDelete` act on all matches: Apple warns that a broad query "matches (and also updates) any such passwords that you've stored". Always include service **and** account. And "not found" means different things: for a read it's "no value", for a delete it's "already gone", for an update it's "add it instead".

### Why update instead of delete-then-add

Apple's "Updating and deleting keychain items" makes the case: adding an item whose identifying attributes match an existing one fails, and adding new ones next to old ones leaves "old, abandoned items". The fix is to update. Delete-then-add avoids the duplicate error but has its own problems: between the two calls there's no item at all, so a crash or a failed add leaves the person signed out; and any attributes you set on the old item (a label, a different accessibility class set by an earlier version) are lost.

Here are those rules as a runnable model. `FakeKeychain` follows the status behavior in the table above, and `PasswordStore` contains the logic you'll use with the real Keychain:

```swift
// A stand-in for the Keychain that follows the documented status rules,
// so the store's logic can run anywhere.
enum Status: Equatable {
    case success, duplicateItem, itemNotFound
}

struct ItemKey: Hashable {
    let service: String
    let account: String
}

final class FakeKeychain {
    private var items: [ItemKey: [UInt8]] = [:]

    func add(_ key: ItemKey, data: [UInt8]) -> Status {
        guard items[key] == nil else { return .duplicateItem }
        items[key] = data
        return .success
    }

    func update(_ key: ItemKey, data: [UInt8]) -> Status {
        guard items[key] != nil else { return .itemNotFound }
        items[key] = data
        return .success
    }

    func copyMatching(_ key: ItemKey) -> (Status, [UInt8]?) {
        guard let data = items[key] else { return (.itemNotFound, nil) }
        return (.success, data)
    }

    func delete(_ key: ItemKey) -> Status {
        items.removeValue(forKey: key) == nil ? .itemNotFound : .success
    }
}

struct StoreError: Error {
    let status: Status
}

struct PasswordStore {
    let keychain: FakeKeychain
    let service: String

    func set(_ data: [UInt8], for account: String) throws {
        let key = ItemKey(service: service, account: account)
        var status = keychain.update(key, data: data)
        if status == .itemNotFound {
            status = keychain.add(key, data: data)
        }
        guard status == .success else { throw StoreError(status: status) }
    }

    func data(for account: String) throws -> [UInt8]? {
        let (status, data) = keychain.copyMatching(ItemKey(service: service, account: account))
        switch status {
        case .success: return data
        case .itemNotFound: return nil
        default: throw StoreError(status: status)
        }
    }

    func remove(_ account: String) throws {
        let status = keychain.delete(ItemKey(service: service, account: account))
        guard status == .success || status == .itemNotFound else { throw StoreError(status: status) }
    }
}

let keychain = FakeKeychain()
let store = PasswordStore(keychain: keychain, service: "com.example.bookshelf")

print(keychain.add(ItemKey(service: "com.example.bookshelf", account: "refresh"), data: [1]))
print(keychain.add(ItemKey(service: "com.example.bookshelf", account: "refresh"), data: [2]))

try store.set([3], for: "refresh")
try store.set([4], for: "api-key")
print(try store.data(for: "refresh") ?? [], try store.data(for: "api-key") ?? [])

try store.remove("refresh")
try store.remove("refresh")
print(try store.data(for: "refresh") as Any)
```

```output
success
duplicateItem
[3] [4]
nil
```

- The second raw `add` for the same service and account fails with `duplicateItem`. That's the error a plain add-only save hits on its second run.
- `set` updates the existing `refresh` item to `[3]`, and for `api-key`, where the update finds nothing, it adds.
- Removing twice is fine: the second delete's `itemNotFound` counts as success.
- A read after removal returns `nil`, not an error.

## The real store

The same logic with the Security framework. Apple's pages for all four functions say they block "the calling thread, so it can cause your app's UI to hang if called from the main thread", and recommend calling them "from a background dispatch queue or async function". An actor does that, and also serializes calls, so two saves can't interleave their update and add steps:

```swift ios
import Foundation
import Security

protocol SecretStore: Sendable {
    func data(for account: String) async throws -> Data?
    func setData(_ data: Data, for account: String) async throws
    func removeData(for account: String) async throws
}

enum KeychainError: Error, CustomStringConvertible {
    case unexpectedStatus(OSStatus)
    case unexpectedItemData

    var description: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "no description"
            return "Keychain status \(status): \(message)"
        case .unexpectedItemData:
            return "The Keychain returned something other than Data"
        }
    }
}

enum Accessibility: Sendable {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly

    var attributeValue: CFString {
        switch self {
        case .whenUnlocked: kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}

actor KeychainStore: SecretStore {
    let service: String
    let accessibility: Accessibility

    init(service: String, accessibility: Accessibility) {
        self.service = service
        self.accessibility = accessibility
    }

    private func itemQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func data(for account: String) throws -> Data? {
        var query = itemQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedItemData }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func setData(_ data: Data, for account: String) throws {
        let changes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.attributeValue,
        ]
        var status = SecItemUpdate(itemQuery(for: account) as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            let attributes = itemQuery(for: account).merging(changes) { _, new in new }
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func removeData(for account: String) throws {
        let status = SecItemDelete(itemQuery(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

let tokens = KeychainStore(service: "com.example.bookshelf.auth",
                           accessibility: .afterFirstUnlockThisDeviceOnly)
try await tokens.setData(Data("r-123".utf8), for: "refresh-token")
let stored = try await tokens.data(for: "refresh-token")
print(stored.map { String(decoding: $0, as: UTF8.self) } ?? "none")
try await tokens.removeData(for: "refresh-token")
```

Line by line, the parts that differ from the model:

- `itemQuery(for:)` is the identity of one item: class, service, account. Every call starts from it, so no call can accidentally match more.
- Reading adds `kSecReturnData: true` ("return item data") and `kSecMatchLimit: kSecMatchLimitOne`. The result comes back through an out-parameter as `CFTypeRef?`, which you cast to `Data`.
- Saving puts the accessibility class in `changes`, so it's applied when updating and when adding. An item saved by an older version with a weaker class gets the current class on the next save.
- `merging(changes) { _, new in new }` builds the add dictionary from the query plus the new values.
- `SecCopyErrorMessageString` (iOS 11.3 and later) turns a status into Apple's text for logs. Log the status, never the data.
- The protocol's requirements are `async`; the actor's methods are synchronous, and actor isolation makes them `async` from outside. Callers on the main actor `await` them and the work runs off the main actor.

> [!note] Access groups and queries
> Apple's sharing article says a query without `kSecAttrAccessGroup` "matches any of your app's groups". If your app shares items with an extension through a keychain access group or app group, put the group in `itemQuery(for:)` too, so a save in one place can't update an item in another group with the same service and account.

## Accessibility classes

From Apple's documentation for each constant:

| `kSecAttrAccessible…` | Readable | Moves to a new device |
| --- | --- | --- |
| `WhenPasscodeSetThisDeviceOnly` | Only while unlocked, and only if a passcode is set | Never. Turning off the passcode deletes these items. |
| `WhenUnlockedThisDeviceOnly` | Only while unlocked | No |
| `WhenUnlocked` (the default) | Only while unlocked | Yes, with encrypted backups |
| `AfterFirstUnlockThisDeviceOnly` | After the first unlock since boot, even while locked | No |
| `AfterFirstUnlock` | After the first unlock since boot, even while locked | Yes, with encrypted backups |

`kSecAttrAccessibleAlways` and `kSecAttrAccessibleAlwaysThisDeviceOnly` are deprecated. Apple's rule: "Choose the most restrictive option that meets your app's needs."

How to choose:

1. **Must background work read it?** A background refresh, a notification service extension, a widget timeline that calls your API: those can run while the device is locked, so use an `AfterFirstUnlock` class. Otherwise use a `WhenUnlocked` class.
2. **Should it move to a new phone?** A session token or a device-bound key usually shouldn't: use `ThisDeviceOnly` and sign in again on the new device. A password the person typed may be fine to migrate.
3. **Is it extremely sensitive?** `WhenPasscodeSetThisDeviceOnly` refuses to store anything on a device without a passcode.

When a read is attempted at a time the class doesn't allow (a `WhenUnlocked` item read from a background task while the device is locked), `SecItemCopyMatching` fails. The status is typically `errSecInteractionNotAllowed` ("Interaction with the Security Server is not allowed"); it isn't `errSecItemNotFound`. Don't treat it as "no token" and sign the person out: the token is there, just not readable right now. Retry later.

Two related attributes, briefly:

- **`kSecAttrSynchronizable`** makes an item sync through iCloud Keychain. Apple notes that a synchronizable item can only use a class whose name doesn't end in `ThisDeviceOnly`.
- **`kSecAttrAccessControl`**, with `SecAccessControlCreateWithFlags`, can demand Face ID, Touch ID or the passcode at read time. Module 42 covers it, along with LocalAuthentication.

## Typed values on top

The protocol deals in `Data`. Callers want `OAuthTokens`. A small generic layer turns one into the other with `Codable`, and because it depends only on `SecretStore`, it runs against the real Keychain in the app and against a dictionary in tests:

```swift
import Foundation

protocol SecretStore: Sendable {
    func data(for account: String) async throws -> Data?
    func setData(_ data: Data, for account: String) async throws
    func removeData(for account: String) async throws
}

/// Typed access on top of any SecretStore: Codable in, Codable out.
struct Secrets: Sendable {
    let store: any SecretStore

    func value<Value: Decodable>(_ type: Value.Type, for account: String) async throws -> Value? {
        guard let data = try await store.data(for: account) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func set<Value: Encodable>(_ value: Value, for account: String) async throws {
        try await store.setData(JSONEncoder().encode(value), for: account)
    }

    func remove(_ account: String) async throws {
        try await store.removeData(for: account)
    }
}

/// The test double: same contract, a dictionary instead of the Keychain.
actor InMemorySecretStore: SecretStore {
    private var items: [String: Data] = [:]
    private(set) var writes = 0

    func data(for account: String) -> Data? { items[account] }

    func setData(_ data: Data, for account: String) {
        items[account] = data
        writes += 1
    }

    func removeData(for account: String) { items[account] = nil }
}

struct OAuthTokens: Codable, Equatable {
    var refreshToken: String
    var scope: [String]
}

let memory = InMemorySecretStore()
let secrets = Secrets(store: memory)

let tokens = OAuthTokens(refreshToken: "r-123", scope: ["read", "write"])
try await secrets.set(tokens, for: "oauth")

let loaded = try await secrets.value(OAuthTokens.self, for: "oauth")
print(loaded == tokens, loaded?.scope ?? [])

do {
    _ = try await secrets.value(Int.self, for: "oauth")
} catch is DecodingError {
    print("Stored data isn't an Int")
}

try await secrets.remove("oauth")
print(try await secrets.value(OAuthTokens.self, for: "oauth") == nil)
print("writes: \(await memory.writes)")
```

```output
true ["read", "write"]
Stored data isn't an Int
true
writes: 1
```

- `Secrets` holds `any SecretStore`. In the app: `Secrets(store: KeychainStore(service: …, accessibility: …))`. In tests: `Secrets(store: InMemorySecretStore())`.
- A value is stored as JSON. Storing several related secrets as one item (the refresh token and its scopes) means one read and one write, and they can't get out of step.
- Reading with the wrong type throws a `DecodingError`. That's what happens after an app update changes the stored type; handle it by deleting the item and asking the person to sign in again, rather than crashing.
- The fake counts writes, so a test can assert that loading tokens doesn't rewrite them.

> [!warning] What the fake can't tell you
> `InMemorySecretStore` checks the code that uses secrets, not the Keychain integration. Accessibility classes, access groups and entitlements only behave for real on a device or simulator. Keep one small test, run in the app's test target on a simulator, that saves, reads and deletes through `KeychainStore`.

## Common mistakes

> [!error] Ignoring the status code
> `SecItemAdd(query as CFDictionary, nil)` on a line by itself compiles fine. When it returns `errSecDuplicateItem`, the new token was never saved and the app carries on with the old one. Check every status.

> [!error] Delete, then add
> There's a window with no item, and attributes from the old item are lost. Update, and add only when the update returns `errSecItemNotFound`.

> [!error] A query that matches too much
> `SecItemDelete` with only `kSecClass: kSecClassGenericPassword` deletes every generic password your app can reach, and `SecItemUpdate` with a partial query changes all of them. Include service and account (and the access group, if you share).

> [!error] Treating every read failure as "signed out"
> `errSecItemNotFound` means no token. A read that fails because the device is locked means the token exists but can't be read yet. Signing the person out on the second is a bug that shows up only in background work.

> [!error] Calling SecItem functions on the main actor
> Apple says they block the calling thread. A Keychain read in `viewDidLoad` or a SwiftUI `body` path can hang the UI. Go through an actor.

> [!error] Using the default class for background work
> Items added without `kSecAttrAccessible` get `kSecAttrAccessibleWhenUnlocked`. A background refresh then fails whenever the phone is locked. Choose the class on purpose.

## Exercises

````exercise
id: m31-l03-e1
type: prediction
prompt: "An add-only save against the lesson's fake Keychain. What does the program print?"
code: |
  enum Status: Equatable {
      case success, duplicateItem, itemNotFound
  }

  final class FakeKeychain {
      private var items: [String: String] = [:]

      func add(_ account: String, _ value: String) -> Status {
          guard items[account] == nil else { return .duplicateItem }
          items[account] = value
          return .success
      }

      func update(_ account: String, _ value: String) -> Status {
          guard items[account] != nil else { return .itemNotFound }
          items[account] = value
          return .success
      }

      func read(_ account: String) -> String? { items[account] }

      func delete(_ account: String) -> Status {
          items.removeValue(forKey: account) == nil ? .itemNotFound : .success
      }
  }

  let keychain = FakeKeychain()

  func saveAddOnly(_ value: String, in keychain: FakeKeychain) {
      let status = keychain.add("token", value)
      print("save \(value): \(status)")
  }

  saveAddOnly("t1", in: keychain)
  saveAddOnly("t2", in: keychain)
  print("stored: \(keychain.read("token") ?? "none")")

  print("update: \(keychain.update("other", "x"))")
  print("delete: \(keychain.delete("token"))")
  print("delete again: \(keychain.delete("token"))")
  print("stored: \(keychain.read("token") ?? "none")")
output: |
  save t1: success
  save t2: duplicateItem
  stored: t1
  update: itemNotFound
  delete: success
  delete again: itemNotFound
  stored: none
solution: |
  - The first add succeeds. The second add finds an item for `token` and returns `duplicateItem`, so **the old token `t1` is still stored**. An app that ignores this status keeps using a stale token.
  - Updating an account that doesn't exist returns `itemNotFound`: that's the signal to add.
  - The first delete succeeds; the second has nothing to delete. A store should treat that `itemNotFound` as success.

  ```output
  save t1: success
  save t2: duplicateItem
  stored: t1
  update: itemNotFound
  delete: success
  delete again: itemNotFound
  stored: none
  ```
````

````exercise
id: m31-l03-e2
type: comprehension
prompt: "Bookshelf adds a widget whose timeline calls the API every hour, including while the phone is locked in a pocket. The refresh token is shared with the widget through a keychain access group. Which accessibility class should the token item use?"
choices:
  - text: "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"
    correct: true
    why: "Readable while locked once the device has been unlocked since boot, and not restored onto another device."
  - text: "kSecAttrAccessibleWhenUnlocked"
    correct: false
    why: "It's the default, and it's readable only while the device is unlocked. The hourly refresh in a pocket would fail."
  - text: "kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly"
    correct: false
    why: "Readable only while unlocked, so the locked refresh fails, and nothing can be stored on a device without a passcode."
  - text: "kSecAttrAccessibleAlways"
    correct: false
    why: "Deprecated, and weaker than the work needs: there's no reason to read the token before the first unlock after a reboot."
solution: |
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Apple recommends the after-first-unlock classes "for items that need to be accessed by background applications", and the `ThisDeviceOnly` variant keeps a session token from being restored onto a different phone, where the person should sign in again anyway.
````

````exercise
id: m31-l03-e3
type: fill-in
prompt: "Complete the read so it returns the item's data, or nil when there's no item."
code: |
  var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: [[1]],
      kSecMatchLimit as String: [[2]],
  ]
  var result: CFTypeRef?
  let status = SecItemCopyMatching(query as CFDictionary, &result)
  if status == [[3]] { return nil }
  guard status == errSecSuccess, let data = result as? [[4]] else {
      throw KeychainError.unexpectedStatus(status)
  }
  return data
blanks:
  - id: "1"
    answers: ["true"]
  - id: "2"
    answers: ["kSecMatchLimitOne"]
  - id: "3"
    answers: ["errSecItemNotFound"]
  - id: "4"
    answers: ["Data"]
solution: |
  `kSecReturnData: true` asks for the item's data, and `kSecMatchLimitOne` limits the result to one item, so `result` holds a single `Data` rather than an array. `errSecItemNotFound` is the normal "nothing stored" answer and becomes `nil`. Any other status, or a result that isn't `Data`, is a real error.
````

````exercise
id: m31-l03-e4
type: find-errors
prompt: "Review this Keychain helper. Which are real problems?"
code: |
  @MainActor
  enum TokenKeychain {
      static func save(_ token: String) {
          let query: [String: Any] = [
              kSecClass as String: kSecClassGenericPassword,
              kSecValueData as String: Data(token.utf8),
          ]
          SecItemDelete(query as CFDictionary)
          SecItemAdd(query as CFDictionary, nil)
      }

      static func load() -> String? {
          let query: [String: Any] = [
              kSecClass as String: kSecClassGenericPassword,
              kSecReturnData as String: true,
          ]
          var result: CFTypeRef?
          SecItemCopyMatching(query as CFDictionary, &result)
          return (result as? Data).map { String(decoding: $0, as: UTF8.self) }
      }
  }
choices:
  - text: "The queries have no service or account, so they match any generic password the app can reach."
    correct: true
    why: "The delete removes every generic password, and the read returns whichever one it finds first."
  - text: "Status codes are ignored."
    correct: true
    why: "A failed add or a locked-device read looks the same as success or \"no token\"."
  - text: "It deletes and then adds instead of updating."
    correct: true
    why: "There's a moment with no token, and attributes of the old item are lost. Update, and add on errSecItemNotFound."
  - text: "The SecItem calls run on the main actor."
    correct: true
    why: "Apple says they block the calling thread, which can hang the UI."
  - text: "No accessibility class is set."
    correct: true
    why: "The item gets the default, WhenUnlocked, which fails for any background refresh while the phone is locked."
  - text: "The token is converted to Data before storing."
    correct: false
    why: "That's required: kSecValueData takes Data."
rubric:
  - Identifies the missing service and account.
  - Identifies the ignored statuses.
  - Identifies delete-then-add.
  - Identifies the main-actor isolation of blocking calls.
  - Identifies the missing accessibility class.
solution: |
  Five real problems, and the lesson's `KeychainStore` fixes each one: an item query with class, service and account; every status checked, with `errSecItemNotFound` handled per call; update-then-add; an actor instead of `@MainActor`; and an explicit `kSecAttrAccessible` chosen for how the token is used. Converting the token to `Data` is correct.
````

````exercise
id: m31-l03-e5
type: solve
prompt: "Keychain items aren't stored in the app's container, and Apple doesn't document that deleting the app removes them, so a reinstalled app can find an old session. UserDefaults lives in the container and is removed with the app. Write `func resetSecretsIfFirstLaunch(defaults: UserDefaults, secrets: Secrets, accounts: [String]) async throws -> Bool` that, when a `hasLaunchedBefore` flag isn't set, removes the given accounts from the secret store, sets the flag and returns true; otherwise it returns false and touches nothing. Test it with the lesson's `Secrets` and `InMemorySecretStore` and a throwaway suite: store a token, run it twice, and print the results and whether the token is still there after each run."
starter: |
  import Foundation

  // Copy SecretStore, Secrets and InMemorySecretStore from the lesson.

  func resetSecretsIfFirstLaunch(defaults: UserDefaults, secrets: Secrets,
                                 accounts: [String]) async throws -> Bool {
      // ...
  }
rubric:
  - Checks the flag first and returns false without touching the store when it's set.
  - Removes every listed account, and sets the flag only after the removals succeed.
  - The test uses a unique suite and cleans it up.
  - The output shows the token removed on the first run and the second run doing nothing.
solution: |
  Setting the flag only after the removals succeed means a failure (an error from the store) leaves the flag unset, so the cleanup runs again on the next launch.

  ```swift
  import Foundation

  protocol SecretStore: Sendable {
      func data(for account: String) async throws -> Data?
      func setData(_ data: Data, for account: String) async throws
      func removeData(for account: String) async throws
  }

  struct Secrets: Sendable {
      let store: any SecretStore

      func value<Value: Decodable>(_ type: Value.Type, for account: String) async throws -> Value? {
          guard let data = try await store.data(for: account) else { return nil }
          return try JSONDecoder().decode(Value.self, from: data)
      }

      func set<Value: Encodable>(_ value: Value, for account: String) async throws {
          try await store.setData(JSONEncoder().encode(value), for: account)
      }

      func remove(_ account: String) async throws {
          try await store.removeData(for: account)
      }
  }

  actor InMemorySecretStore: SecretStore {
      private var items: [String: Data] = [:]
      func data(for account: String) -> Data? { items[account] }
      func setData(_ data: Data, for account: String) { items[account] = data }
      func removeData(for account: String) { items[account] = nil }
  }

  func resetSecretsIfFirstLaunch(defaults: UserDefaults, secrets: Secrets,
                                 accounts: [String]) async throws -> Bool {
      let flag = "app.hasLaunchedBefore"
      guard !defaults.bool(forKey: flag) else { return false }
      for account in accounts {
          try await secrets.remove(account)
      }
      defaults.set(true, forKey: flag)
      return true
  }

  let suiteName = "academy.m31.first-launch.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  let secrets = Secrets(store: InMemorySecretStore())

  // Left over from a previous install.
  try await secrets.set("r-old", for: "refresh-token")

  for run in 1...2 {
      let didReset = try await resetSecretsIfFirstLaunch(
          defaults: defaults, secrets: secrets, accounts: ["refresh-token", "api-key"])
      let token = try await secrets.value(String.self, for: "refresh-token")
      print("run \(run): reset \(didReset), token \(token ?? "none")")
      if run == 1 {
          try await secrets.set("r-new", for: "refresh-token")   // the person signs in
      }
  }

  defaults.removePersistentDomain(forName: suiteName)
  ```

  ```output
  run 1: reset true, token none
  run 2: reset false, token r-new
  ```

  Run 1 is a fresh container: no flag, so the leftover token is removed. The person then signs in. Run 2 sees the flag and leaves the new token alone. Removing `api-key`, which was never stored, is fine because the store treats "not found" as success. If the app shares Keychain items with other apps from the same team, think twice: deleting a shared item on one app's reinstall signs the person out of the others too.
````

````exercise
id: m31-l03-e6
type: explain
prompt: "A background refresh reads the refresh token and gets a failure status that isn't errSecItemNotFound. The current code signs the person out on any read failure. Explain why that's wrong and what the code should do instead."
rubric:
  - Distinguishes "no item" (errSecItemNotFound) from "item exists but isn't readable now".
  - Connects the failure to the accessibility class and the device being locked.
  - Proposes treating it as a temporary failure (skip or retry later) rather than signing out.
  - Mentions fixing the accessibility class if background reads are a requirement.
solution: |
  Only `errSecItemNotFound` means the token isn't there. Other failures mean the read couldn't happen: most often, the item's accessibility class doesn't allow reads in the device's current state, such as a `WhenUnlocked` item read while the phone is locked (typically reported as `errSecInteractionNotAllowed`). The token still exists. Signing out deletes a perfectly good session and forces the person to sign in again for no reason.

  The background task should treat that as a temporary failure: skip this refresh, log the status, and try again on the next opportunity. And if background reads are a real requirement, the item should be saved with an `AfterFirstUnlock` class; the lesson's store applies its class on every save, so the next save fixes items written with the old one.
````

## Summary

- A generic password item is its class plus service and account, and the secret in `kSecValueData`. Include all three in every query, plus the access group if you share items.
- `SecItemAdd` fails with `errSecDuplicateItem` for an existing item. Save by updating, and add only when `SecItemUpdate` returns `errSecItemNotFound`.
- `errSecItemNotFound` is "no value" for a read and success for a delete. Any other non-success status is a real failure; a read that fails while the device is locked doesn't mean the token is gone.
- Choose the accessibility class on purpose: `AfterFirstUnlock` for anything background work reads, `ThisDeviceOnly` for secrets that shouldn't move to a new device, the most restrictive class that works.
- The `SecItem` functions block their thread. Call them from an actor.
- Hide the Keychain behind a small protocol, add typed `Codable` access on top, and test the code that uses secrets with an in-memory store.
