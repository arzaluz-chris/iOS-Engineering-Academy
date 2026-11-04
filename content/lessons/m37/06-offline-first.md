---
id: m37-l06
title: Offline-first apps
description: "An offline-first app reads and writes its local store, always, and a sync engine reconciles that store with the server when it can. You build the pieces in plain Swift: a local store with an outbox, a sync engine that pushes then pulls from a cursor, conflict policies injected as a choice, operation IDs that make retries safe, and a status the UI can show. Then you wire it into SwiftUI with SwiftData, tombstones for deletes, sync triggers and a status label, and test every scenario with fakes."
module: m37
order: 6
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l05, m31-l06, m30-l05, m33-l03]
objectives:
  - Make the local store the only source the UI reads, with writes applied locally first and queued in an outbox.
  - Build a sync engine that pushes pending changes, pulls remote changes from a cursor and reports a status.
  - Resolve conflicts with an injected policy and keep retries idempotent with operation IDs.
  - Represent offline deletes with tombstones and coalesce pending changes.
  - Show sync status in SwiftUI, trigger syncs at the right moments, and test sync scenarios with fakes.
terms:
  - term: Offline-first
    definition: "A design where the UI reads and writes a local store, always, and a separate sync process reconciles that store with the server whenever the network allows."
  - term: Outbox
    definition: "The persisted queue of local changes not yet accepted by the server. A change leaves it only when the server confirms it."
  - term: Operation ID
    definition: "A unique identifier the client gives each change it sends. The server remembers which IDs it has applied, so a push retried after a lost response is recognized and not applied twice. Also called an idempotency key."
  - term: Tombstone
    definition: "A local record that marks something as deleted but keeps it until the deletion has been synced. Removing the row immediately would leave nothing to send."
  - term: Sync cursor
    definition: "An opaque position in the server's change feed. The client sends it to get only the changes made after its last pull."
mastery:
  - Write a local store with an outbox where an edit replaces an earlier pending edit of the same item.
  - Write a sync loop that pushes then pulls, ignores remote updates to items with pending edits, and can't run twice at once.
  - Implement server-wins, client-wins and keep-both policies and say which data each suits.
  - Explain and test why a retried push with the same operation ID doesn't apply twice.
  - Build a SwiftUI list over SwiftData that shows per-item pending state and an overall sync status, syncing on launch, on return to the foreground, after edits and on pull to refresh.
resources: [network-nwpathmonitor, swiftdata, swiftui-scenephase, swift-actor, swift-mainactor, fowler-test-double, swift-testing-docs]
cards:
  - id: m37-l06-c1
    front: What does the UI read in an offline-first app?
    back: "Only the local store. Writes go to the local store first and into an outbox; the sync engine pushes the outbox and pulls server changes into the local store. The UI never waits for the network to show or save data."
  - id: m37-l06-c2
    front: Why does a sync pull skip items that have pending local edits?
    back: "Applying the server's copy would overwrite an edit that hasn't been pushed yet. The push handles those items: it's accepted, or it's a conflict and the policy decides."
  - id: m37-l06-c3
    front: How do operation IDs make sync retries safe?
    back: "Each pending change carries a unique ID. If a push is applied but its response is lost, the client retries with the same ID; the server sees it already applied that ID and returns the original result instead of applying the change again."
  - id: m37-l06-c4
    front: "Server wins, client wins, keep both: when?"
    back: "Server wins for data the server owns or that's cheap to redo. Client wins when the device's latest edit should prevail and losing the other is acceptable. Keep both (a conflict copy) for user-written content you must never lose. Field-level merges (Module 31) when fields change independently."
  - id: m37-l06-c5
    front: How does an offline delete reach the server?
    back: "Through a tombstone: mark the item deleted locally (hidden from the UI) and queue the delete. Remove the record only after the server accepts. Deleting the row immediately leaves nothing to sync; deleting an item that was never synced can just drop its pending create."
---

## The idea in one sentence

**The local store is the app's source of truth and the server is a peer it syncs with**, so every screen works the same online and offline, and all the network's uncertainty lives in one component you can test.

> [!note] About this lesson's code
> The store, sync engine, fake server and scenarios are plain Swift, compiled and run with Swift 6.3. The SwiftUI and SwiftData blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. The server here is a fake that follows common versioning rules, not a specific product's API.

## Where you are

Module 31, lesson 6 introduced offline-first sync as a model: an outbox, push with versions, conflicts detected by the server, rebasing operations, and field-level merge strategies. Module 30 gave you cursors and retries; lesson 5 here put SwiftData in the views. This lesson builds the component between them: a sync engine with a status, behind the repository the views already use, and a test for every way the network can let you down.

## The shape of an offline-first app

```text
UI  ──reads/writes──▶  local store (SwiftData)  ◀──applies──  sync engine  ◀──push/pull──▶  server
                              │                                    ▲
                              └──────── outbox of pending changes ─┘
```

Four rules follow from that picture:

1. **The UI reads only the local store.** `@Query` (lesson 5) or a repository's list. Never "show the server's response".
2. **Writes are local first.** Saving updates the store immediately and appends a change to the **outbox**. The user never waits for the network to see their own edit.
3. **Sync is a separate process.** It **pushes** the outbox (oldest first), then **pulls** server changes after its **cursor** and applies them locally.
4. **Sync state is data.** Each item knows whether it has pending changes; the engine knows whether it's syncing, offline or failing. The UI shows both.

## The pieces, in plain Swift

Here's a complete, small version: notes with client-generated IDs, a local store with an outbox, a sync engine, three conflict policies, a fake server and four scenarios. It's long because it's the whole system; the walkthrough after it takes one piece at a time.

```swift
// MARK: Shapes shared by the device and the server

struct RemoteNote: Equatable, Sendable {
    let id: String
    var text: String
    var version: Int
}

struct PendingChange: Equatable, Sendable {
    let operationID: String     // unique per change, so a retried push is recognized
    let noteID: String
    let text: String
    let baseVersion: Int        // the server version this edit started from (0: new note)
}

enum PushResult: Equatable, Sendable {
    case accepted(version: Int)
    case conflict(current: RemoteNote)
}

enum SyncError: Error {
    case offline, timeout
}

protocol NotesAPI: Sendable {
    func push(_ change: PendingChange) async throws -> PushResult
    func changes(after cursor: Int) async throws -> (notes: [RemoteNote], cursor: Int)
}

// MARK: Local store: the UI's source of truth (SwiftData in the app)

struct LocalNote: Equatable {
    let id: String
    var text: String
    var baseVersion: Int
}

@MainActor
final class LocalStore {
    private(set) var notes: [String: LocalNote] = [:]
    private(set) var outbox: [PendingChange] = []
    private var nextOperation = 1

    var sortedTexts: [String] { notes.values.map(\.text).sorted() }

    /// A local edit: applied at once, queued for the server.
    func save(id: String, text: String) {
        let base = notes[id]?.baseVersion ?? 0
        notes[id] = LocalNote(id: id, text: text, baseVersion: base)
        outbox.removeAll { $0.noteID == id }          // only the latest edit of a note needs to go out
        outbox.append(PendingChange(operationID: "op\(nextOperation)", noteID: id, text: text, baseVersion: base))
        nextOperation += 1
    }

    func markSynced(_ change: PendingChange, version: Int) {
        outbox.removeAll { $0.operationID == change.operationID }
        notes[change.noteID]?.baseVersion = version
    }

    /// A note from the server. Notes with pending local edits are left alone; the push handles them.
    func applyRemote(_ note: RemoteNote) {
        guard !outbox.contains(where: { $0.noteID == note.id }) else { return }
        notes[note.id] = LocalNote(id: note.id, text: note.text, baseVersion: note.version)
    }

    func dropPending(_ change: PendingChange) {
        outbox.removeAll { $0.operationID == change.operationID }
    }

    func rebase(_ change: PendingChange, onto version: Int) {
        guard let index = outbox.firstIndex(where: { $0.operationID == change.operationID }) else { return }
        outbox[index] = PendingChange(operationID: change.operationID, noteID: change.noteID,
                                      text: change.text, baseVersion: version)
        notes[change.noteID]?.baseVersion = version
    }
}

// MARK: Sync engine

enum ConflictPolicy: Sendable {
    case serverWins       // drop the local edit
    case clientWins       // re-send the local edit on top of the server's version
    case keepBoth         // take the server's version, keep the local text as a copy
}

enum SyncStatus: Equatable {
    case upToDate
    case pending(Int)
    case syncing
    case offline(pending: Int)
    case failed(pending: Int)
}

@MainActor
final class SyncEngine {
    private let store: LocalStore
    private let api: any NotesAPI
    private let policy: ConflictPolicy
    private var cursor = 0
    private var isSyncing = false
    private(set) var status = SyncStatus.upToDate

    init(store: LocalStore, api: any NotesAPI, policy: ConflictPolicy) {
        self.store = store
        self.api = api
        self.policy = policy
    }

    func localChangeMade() {
        if !isSyncing { status = .pending(store.outbox.count) }
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        status = .syncing
        do {
            try await push()
            let (notes, newCursor) = try await api.changes(after: cursor)
            for note in notes { store.applyRemote(note) }
            cursor = newCursor
            status = store.outbox.isEmpty ? .upToDate : .pending(store.outbox.count)
        } catch SyncError.offline {
            status = .offline(pending: store.outbox.count)
        } catch {
            status = .failed(pending: store.outbox.count)
        }
    }

    private func push() async throws {
        for change in store.outbox {
            switch try await api.push(change) {
            case .accepted(let version):
                store.markSynced(change, version: version)
            case .conflict(let current):
                try await resolve(change, against: current)
            }
        }
    }

    private func resolve(_ change: PendingChange, against current: RemoteNote) async throws {
        switch policy {
        case .serverWins:
            store.dropPending(change)
            store.applyRemote(current)
        case .clientWins:
            store.rebase(change, onto: current.version)
            if case .accepted(let version) = try await api.push(
                PendingChange(operationID: change.operationID + "-r", noteID: change.noteID,
                              text: change.text, baseVersion: current.version)) {
                store.markSynced(change, version: version)
            }
        case .keepBoth:
            store.dropPending(change)
            store.applyRemote(current)
            store.save(id: change.noteID + "-copy", text: change.text + " (conflict copy)")
            if let copy = store.outbox.last, case .accepted(let version) = try await api.push(copy) {
                store.markSynced(copy, version: version)
            }
        }
    }
}

// MARK: A fake server

actor FakeServer: NotesAPI {
    private(set) var notes: [String: RemoteNote] = [:]
    private var feed: [(sequence: Int, id: String)] = []
    private var appliedOperations: [String: Int] = [:]
    var isOnline = true
    var loseNextResponse = false

    func setOnline(_ value: Bool) { isOnline = value }
    func setLoseNextResponse() { loseNextResponse = true }

    /// Another device's edit, already on the server.
    func editFromOtherDevice(id: String, text: String) {
        let version = (notes[id]?.version ?? 0) + 1
        notes[id] = RemoteNote(id: id, text: text, version: version)
        feed.append((feed.count + 1, id))
    }

    func push(_ change: PendingChange) throws -> PushResult {
        guard isOnline else { throw SyncError.offline }
        if let version = appliedOperations[change.operationID] {
            return .accepted(version: version)                 // a retry of something already applied
        }
        let current = notes[change.noteID]
        guard (current?.version ?? 0) == change.baseVersion else {
            return .conflict(current: current!)
        }
        let version = change.baseVersion + 1
        notes[change.noteID] = RemoteNote(id: change.noteID, text: change.text, version: version)
        feed.append((feed.count + 1, change.noteID))
        appliedOperations[change.operationID] = version
        if loseNextResponse {
            loseNextResponse = false
            throw SyncError.timeout                            // applied, but the device never hears back
        }
        return .accepted(version: version)
    }

    func changes(after cursor: Int) throws -> (notes: [RemoteNote], cursor: Int) {
        guard isOnline else { throw SyncError.offline }
        let ids = feed.filter { $0.sequence > cursor }.map(\.id)
        let changed = Set(ids).compactMap { notes[$0] }.sorted { $0.id < $1.id }
        return (changed, feed.count)
    }

    var summary: String {
        notes.values.sorted { $0.id < $1.id }.map { "\($0.id)=\($0.text)@v\($0.version)" }.joined(separator: ", ")
    }
}

let server = FakeServer()
let store = LocalStore()
let engine = SyncEngine(store: store, api: server, policy: .keepBoth)

// 1. Offline: the user writes two notes.
await server.setOnline(false)
store.save(id: "a", text: "Groceries")
store.save(id: "b", text: "Gift ideas")
engine.localChangeMade()
print("1.", engine.status, store.sortedTexts)
await engine.sync()
print("  ", engine.status)

// 2. Back online.
await server.setOnline(true)
await engine.sync()
print("2.", engine.status, "| server:", await server.summary)

// 3. The tablet edits "a"; the phone, which hasn't synced since, edits it too.
await server.editFromOtherDevice(id: "a", text: "Groceries: milk")
store.save(id: "a", text: "Groceries: eggs")
await engine.sync()
print("3.", engine.status, store.sortedTexts)
print("   server:", await server.summary)

// 4. A push is applied but its response is lost; the retry must not apply it twice.
store.save(id: "b", text: "Gift ideas: book")
await server.setLoseNextResponse()
await engine.sync()
print("4.", engine.status)
await engine.sync()
print("  ", engine.status, "| server:", await server.summary)
```

```output
1. pending(2) ["Gift ideas", "Groceries"]
   offline(pending: 2)
2. upToDate | server: a=Groceries@v1, b=Gift ideas@v1
3. upToDate ["Gift ideas", "Groceries: eggs (conflict copy)", "Groceries: milk"]
   server: a=Groceries: milk@v2, a-copy=Groceries: eggs (conflict copy)@v1, b=Gift ideas@v1
4. failed(pending: 1)
   upToDate | server: a=Groceries: milk@v2, a-copy=Groceries: eggs (conflict copy)@v1, b=Gift ideas: book@v2
```

### The local store and its outbox

`LocalStore` stands in for SwiftData. Its `save(id:text:)` is what the UI calls: the note changes **immediately** (scenario 1 shows both notes while offline), and a `PendingChange` goes into the outbox. Each change records:

- **`noteID`**, generated on the device. Because the client picks the ID (in the app, a `UUID`), a note created offline has its final identity from the start: the UI can show it, link to it and edit it again before the server has ever heard of it. Server-assigned IDs force a temporary-ID-then-remap step that's easy to get wrong.
- **`baseVersion`**, the server version the edit started from, `0` for a note the server doesn't have yet. That's how the server detects conflicts (Module 31, lesson 6).
- **`operationID`**, unique per change, for safe retries (below).

`save` also **coalesces**: a second edit of the same note replaces the first pending one. The server only needs the latest text, and sending ten keystrokes' worth of edits after a subway ride is ten chances to conflict.

`applyRemote(_:)` is the pull side, and it has one rule that matters: **a note with a pending local edit isn't overwritten by the server's copy.** Without that guard, scenario 3 would pull the tablet's "Groceries: milk" over the phone's unsent "Groceries: eggs", and the phone's edit would vanish before it was ever pushed. The push handles those notes instead.

### The sync engine

`SyncEngine.sync()` is the whole reconciliation:

1. **Guard against overlap.** `isSyncing` is checked and set with no `await` in between, on the main actor, exactly like lesson 4's page task. A pull to refresh during a launch sync doesn't start a second one.
2. **Push first, oldest first.** Each pending change is sent; `accepted` marks it synced with the new version, `conflict` goes to the policy.
3. **Then pull** everything after the cursor and apply it. Pushing first means the pull already includes the server's view of your own changes, and you don't pull a note just to find your pending edit conflicts with it.
4. **Report a status.** `upToDate`, `pending(n)` (local changes waiting), `syncing`, `offline(pending:)` or `failed(pending:)`. The pending count comes from the outbox, so it's never a separate number to keep in sync.

A failed push stops the loop by throwing, and the changes stay in the outbox in order. Nothing is lost by failing; the next sync starts where this one stopped.

### Conflict policies

The engine takes a `ConflictPolicy` in its initializer, so the rule is a decision you make per data type and test, not something buried in the loop:

| Policy | What happens | Fits |
| --- | --- | --- |
| `serverWins` | Drop the local edit, take the server's copy | Data the server owns (prices, permissions), or edits that are cheap to redo |
| `clientWins` | Re-send the local edit based on the server's current version, overwriting it | Single-user settings where the latest device should prevail |
| `keepBoth` | Take the server's copy and save the local text as a new "conflict copy" | User-written content nobody may lose: notes, documents |

Scenario 3 used `keepBoth`: the tablet's "Groceries: milk" stays as note `a`, and the phone's "Groceries: eggs" becomes `a-copy` on both the device and the server. Nobody's typing is lost, and the user merges by hand. For structured data where fields change independently, Module 31's field-level merge (with the base version) is the better tool; it slots in as a fourth case.

`clientWins` is "last writer wins", decided by the order pushes reach the server, not by device clocks (Module 31, lesson 6 explains why clocks can't decide).

### Idempotent pushes

The nastiest network failure isn't "no connection". It's **the request arrived and was applied, and the response was lost**: a timeout, the app suspended, a dropped connection on the way back. The device can't tell that from a request that never arrived, so it retries.

Scenario 4 does exactly that. `loseNextResponse` makes the server apply the edit to `b` (version 2) and then throw `timeout`. The engine reports `failed(pending: 1)` and keeps the change. On the next sync it pushes **the same change with the same `operationID`**; the server finds that operation ID in `appliedOperations` and returns the original `accepted(version: 2)` instead of applying it again. The final state shows `b` at v2, not v3, and no conflict with itself.

Without operation IDs, the retry would be based on version 1 while the server is at 2: a conflict with your own edit, and under `keepBoth`, a conflict copy of a note nobody else touched. Sending an idempotency key with every mutating request is the fix, and it's a server feature you need to ask for when designing the API.

## Deletes are tombstones

Deleting offline has a trap: if `delete` removes the record from the local store, there's nothing left to tell the server about. Offline-first deletes are two steps:

1. **Mark** the item deleted (a tombstone): the UI filters it out, and a delete change goes into the outbox.
2. **Remove** the record after the server accepts the delete.

Coalescing applies here too. Deleting a note that was created offline and never synced (`baseVersion == 0`) just drops its pending create: the server never needs to hear about it. Exercise 4 writes these rules.

## In SwiftUI, with SwiftData

In the app, the local store is SwiftData. The sync bookkeeping becomes properties on the model, and the UI reads them like anything else:

```swift ios
import SwiftUI
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var noteID: String
    var text: String
    var baseVersion: Int           // 0: never synced
    var needsUpload: Bool          // has a change the server hasn't accepted
    var isDeletedLocally: Bool     // tombstone; PersistentModel already has isDeleted

    init(noteID: String = UUID().uuidString, text: String) {
        self.noteID = noteID
        self.text = text
        baseVersion = 0
        needsUpload = true
        isDeletedLocally = false
    }
}

enum SyncStatus: Equatable {
    case upToDate
    case pending(Int)
    case syncing
    case offline(pending: Int)
    case failed(pending: Int)
}

/// Owns the sync engine from this lesson and exposes its status to views.
@MainActor
@Observable
final class SyncCoordinator {
    private(set) var status = SyncStatus.upToDate

    func sync() async {
        // Runs SyncEngine.sync() against the main context and updates status.
    }
}

struct NotesScreen: View {
    @Query(filter: #Predicate<Note> { !$0.isDeletedLocally }, sort: \Note.text)
    private var notes: [Note]
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            ForEach(notes) { note in
                HStack {
                    Text(note.text)
                    Spacer()
                    if note.needsUpload {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Not synced yet")
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let note = notes[index]
                    if note.baseVersion == 0 {
                        context.delete(note)          // never synced: nothing to tell the server
                    } else {
                        note.isDeletedLocally = true  // tombstone until the server accepts
                        note.needsUpload = true
                    }
                }
                Task { await syncCoordinator.sync() }
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .status) {
                SyncStatusLabel(status: syncCoordinator.status)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Note", systemImage: "square.and.pencil") {
                    context.insert(Note(text: "New note"))
                    Task { await syncCoordinator.sync() }
                }
            }
        }
        .refreshable { await syncCoordinator.sync() }
        .task { await syncCoordinator.sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await syncCoordinator.sync() }
            }
        }
    }
}

struct SyncStatusLabel: View {
    let status: SyncStatus

    var body: some View {
        switch status {
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.icloud")
        case .pending(let count):
            Label("\(count) to sync", systemImage: "icloud.and.arrow.up")
        case .syncing:
            Label("Syncing…", systemImage: "arrow.triangle.2.circlepath.icloud")
        case .offline(let count):
            Label(count == 0 ? "Offline" : "Offline, \(count) waiting", systemImage: "icloud.slash")
        case .failed(let count):
            Label("Sync failed, \(count) waiting", systemImage: "exclamationmark.icloud")
        }
    }
}
```

What the screen does:

- **The query hides tombstones** with `!$0.isDeletedLocally`, so a deleted note disappears at once, while its record waits for the server. The property can't be called `isDeleted`: `PersistentModel` already has an `isDeleted` property.
- **Per-item state** comes from `needsUpload`: the row shows a small "not synced yet" icon, with an accessibility label so VoiceOver users get it too.
- **Overall state** comes from the coordinator, injected through the environment (lesson 2) because the status shows on several screens. Offline is a normal, calm state: "Offline, 2 waiting", not an error alert.
- **Triggers:** `.task` syncs when the screen appears, the `scenePhase` change syncs when the app returns to the foreground, writes trigger a sync, and `.refreshable` lets the user ask. All of them call the same `sync()`, whose guard turns overlapping triggers into one run. Apps also commonly sync when connectivity returns (the Network framework's `NWPathMonitor` reports path changes) and in the background (Module 44 covers background tasks).
- **The engine runs on the main context**, like `SyncEngine` above on the main actor. For large pulls, move the apply step to a `@ModelActor` (Module 31, lesson 5) and save, so the main context sees the changes; the engine's logic doesn't change.

## Testing sync logic

The scenario run above is the test suite, printed. In a test target, each numbered scenario becomes a test with the same fakes:

```swift illustrative
import Testing
@testable import Notes

@MainActor
struct SyncEngineTests {
    let server = FakeServer()
    let store = LocalStore()

    @Test func editsMadeOfflineAreKeptAndSentLater() async {
        let engine = SyncEngine(store: store, api: server, policy: .keepBoth)
        await server.setOnline(false)
        store.save(id: "a", text: "Groceries")
        await engine.sync()
        #expect(engine.status == .offline(pending: 1))
        #expect(store.sortedTexts == ["Groceries"])

        await server.setOnline(true)
        await engine.sync()
        #expect(engine.status == .upToDate)
        #expect(await server.summary == "a=Groceries@v1")
    }

    @Test func conflictKeepsBothVersions() async { /* scenario 3 */ }

    @Test func retriedPushIsAppliedOnce() async { /* scenario 4 */ }

    @Test(arguments: [ConflictPolicy.serverWins, .clientWins, .keepBoth])
    func noChangeIsLostWhenTheServerIsDown(policy: ConflictPolicy) async { /* ... */ }
}
```

The fakes are what make this possible (Module 33, lesson 3): `FakeServer` is an actor with switches for the failures you care about (offline, lost response, another device's edit), and `LocalStore` is an in-memory store with the same rules as the SwiftData one. Every scenario that's hard to reproduce on a device (a response lost after the server applied it, two devices editing within a second) is one line in a test.

> [!tip] Test the rules, not the transport
> These tests never touch `URLSession`. The HTTP client is tested on its own (Module 30, lesson 6); the sync engine is tested against the `NotesAPI` protocol. When a sync bug appears in production, reproduce it as a scenario with the fake server first, then fix it.

## Common mistakes

> [!error] Showing the server's response instead of the local store
> A screen that displays what `POST /notes` returned shows nothing offline and can disagree with the store. Write locally, read locally, sync in the background.

> [!error] Pulling over pending edits
> Applying every pulled record unconditionally overwrites unsent local edits. Skip records with pending changes; the push resolves them.

> [!error] Retrying without an operation ID
> A push that was applied but whose response was lost gets applied again, or conflicts with itself. Send a unique ID per change and have the server remember it.

> [!error] Deleting the row on delete
> Removing a synced record locally leaves nothing to send, and the next pull brings it back. Keep a tombstone until the server accepts the delete.

> [!error] Treating offline as an error
> An alert every time the network drops punishes the user for being on a train. Offline is a status: show what's waiting, keep working, sync later.

## Exercises

````exercise
id: m37-l06-e1
type: prediction
prompt: "A simplified conflict resolver, run once per policy with the same conflict, then once without a conflict. What does it print?"
code: |
  enum Policy: CaseIterable {
      case serverWins, clientWins, keepBoth
  }

  struct ServerNote {
      var text: String
      var version: Int
  }

  /// Returns the texts the device ends up showing.
  func push(local: String, baseVersion: Int, to server: inout ServerNote, policy: Policy) -> [String] {
      guard baseVersion != server.version else {
          server.text = local
          server.version += 1
          return [local]
      }
      switch policy {
      case .serverWins:
          return [server.text]
      case .clientWins:
          server.text = local
          server.version += 1
          return [local]
      case .keepBoth:
          return [server.text, local + " (copy)"]
      }
  }

  for policy in Policy.allCases {
      var server = ServerNote(text: "Milk", version: 2)
      let device = push(local: "Eggs", baseVersion: 1, to: &server, policy: policy)
      print(policy, device, "server:", server.text, "v\(server.version)")
  }
  var server = ServerNote(text: "Milk", version: 2)
  print(push(local: "Eggs", baseVersion: 2, to: &server, policy: .serverWins), server.version)
output: |
  serverWins ["Milk"] server: Milk v2
  clientWins ["Eggs"] server: Eggs v3
  keepBoth ["Milk", "Eggs (copy)"] server: Milk v2
  ["Eggs"] 3
hints:
  - "A base version that matches the server's isn't a conflict, whatever the policy."
  - "Only clientWins changes the server during a conflict here."
solution: |
  ```output
  serverWins ["Milk"] server: Milk v2
  clientWins ["Eggs"] server: Eggs v3
  keepBoth ["Milk", "Eggs (copy)"] server: Milk v2
  ["Eggs"] 3
  ```

  The device's edit is based on version 1 and the server is at 2, so all three runs are conflicts. Server wins discards "Eggs". Client wins overwrites the server and bumps it to v3. Keep both leaves the server alone in this simplified version and shows both texts on the device (the lesson's engine also pushes the copy as a new note). The last call is based on version 2, the current one, so it's accepted whatever the policy: policies only matter when there's a conflict.
````

````exercise
id: m37-l06-e2
type: comprehension
prompt: "A user taps Save on a note; the push reaches the server and is applied, but the response is lost when the phone switches from Wi-Fi to cellular. What makes the next sync safe?"
choices:
  - text: "The pending change keeps its operation ID; the server recognizes the ID on the retry and returns the original result without applying the change again."
    correct: true
    why: "That's idempotency: the same request, recognized, has the same effect once."
  - text: "The client removes the change from the outbox when the request times out, since it was probably applied."
    correct: false
    why: "If it wasn't applied, the edit is lost. A timeout tells you nothing about whether it arrived."
  - text: "The client pushes again with a new operation ID and the current time, so the newest write wins."
    correct: false
    why: "A new ID makes the server treat it as a new change: based on an old version, it's a conflict with itself. And device clocks can't order writes."
  - text: "The server rejects all retries; the client must pull first and recreate the edit."
    correct: false
    why: "That would turn every lost response into a conflict or lost work."
solution: |
  **The operation ID.** From the device's side, "applied but the response was lost" and "never arrived" look the same, so the only safe move is to retry the same change. The server keeps the IDs it has applied (for a while) and answers a repeat with the result it gave the first time. The edit lands once, the outbox empties, and no conflict copy appears.
````

````exercise
id: m37-l06-e3
type: find-errors
prompt: "A team describes their \"offline support\". Which statements describe real problems?"
code: |
  // 1. NotesScreen calls api.fetchNotes() in .task and shows the result.
  //    When the request fails, it shows the notes cached from the last success.
  // 2. Saving calls api.save(note); if that throws, the note goes into an outbox.
  // 3. The pull applies every note the server returns to the local store.
  // 4. Deleting a note calls context.delete(note) and queues the note's ID for deletion.
  // 5. Conflicts are resolved by comparing each device's modifiedAt timestamp.
  // 6. A sync runs on launch, on returning to the foreground and on pull to refresh,
  //    guarded so only one runs at a time.
choices:
  - text: "1: the screen shows the server's response, so it's online-first with a cache, and the cache and screen can disagree."
    correct: true
    why: "The UI should read the local store always."
  - text: "2: the edit isn't local first; online saves wait for the network and only failures go to the outbox."
    correct: true
    why: "Every save should write locally and enqueue; the engine sends it."
  - text: "3: pulling every note overwrites notes with unsent local edits."
    correct: true
    why: "Skip notes with pending changes."
  - text: "5: device clocks can't order writes across devices."
    correct: true
    why: "Use server versions (Module 31, lesson 6)."
  - text: "4: deleting the record right away is fine as long as the ID is queued."
    correct: false
    why: "This one works for the delete itself, though a tombstone is still better: a pull before the delete is pushed would bring the note back."
  - text: "6: syncing on all three triggers will send duplicate requests."
    correct: false
    why: "The guard makes overlapping triggers one run; these are the right triggers."
rubric:
  - Flags 1, 2, 3 and 5.
  - Treats 4 as workable but notes the resurrection risk a tombstone avoids.
  - Accepts 6 as correct.
solution: |
  Four real problems: **1** reads the network instead of the store; **2** isn't local-first, so the user waits on every save while online; **3** overwrites unsent edits; **5** trusts device clocks. Statement **4** gets the delete to the server because the ID is queued, but until it's pushed, a pull that returns the note would recreate it locally; a tombstone (`isDeletedLocally` plus a pending delete) avoids that and keeps the record for the push. Statement **6** is the right set of triggers, and the guard handles overlaps.
````

````exercise
id: m37-l06-e4
type: solve
prompt: |
  Write the outbox's coalescing rules. `enqueue(_:into:)` adds a change unless an earlier pending change for the same id makes it redundant:

  - a `create` or `update` for an id with a pending `create` → that pending entry becomes `create` with the new text (still a create, same position);
  - an `update` for an id with a pending `update` → the pending update is replaced in place;
  - a `delete` for an id with a pending `create` → the create is removed and nothing is added (the server never knew about it);
  - a `delete` for an id with a pending `update` → the update is replaced in place by the delete;
  - anything else is appended.

  Then run:

  ```swift
  var outbox: [Change] = []
  enqueue(.create(id: "a", text: "Milk"), into: &outbox)
  enqueue(.update(id: "a", text: "Oat milk"), into: &outbox)
  enqueue(.update(id: "b", text: "Bread"), into: &outbox)
  enqueue(.update(id: "b", text: "Rye bread"), into: &outbox)
  print(outbox.map(\.label))
  enqueue(.create(id: "c", text: "Eggs"), into: &outbox)
  enqueue(.delete(id: "c"), into: &outbox)
  enqueue(.delete(id: "b"), into: &outbox)
  print(outbox.map(\.label))
  ```

  ```output
  ["create a Oat milk", "update b Rye bread"]
  ["create a Oat milk", "delete b"]
  ```
starter: |
  enum Change: Equatable {
      case create(id: String, text: String)
      case update(id: String, text: String)
      case delete(id: String)

      var id: String {
          switch self {
          case .create(let id, _), .update(let id, _), .delete(let id): id
          }
      }

      var label: String {
          switch self {
          case .create(let id, let text): "create \(id) \(text)"
          case .update(let id, let text): "update \(id) \(text)"
          case .delete(let id): "delete \(id)"
          }
      }
  }

  func enqueue(_ change: Change, into outbox: inout [Change]) {
      // ...
  }
hints:
  - "Find the index of a pending change with the same id first: outbox.firstIndex { $0.id == change.id }."
  - "Switch over (outbox[index], change) as a tuple to handle each pair."
  - "A pending delete followed by anything is a case the rules don't cover; append."
rubric:
  - Handles all five rules, preserving positions where required.
  - Delete after an offline create leaves nothing for that id.
  - Uses the id helper rather than repeating the matching.
  - Output matches exactly.
solution: |
  ```swift
  enum Change: Equatable {
      case create(id: String, text: String)
      case update(id: String, text: String)
      case delete(id: String)

      var id: String {
          switch self {
          case .create(let id, _), .update(let id, _), .delete(let id): id
          }
      }

      var label: String {
          switch self {
          case .create(let id, let text): "create \(id) \(text)"
          case .update(let id, let text): "update \(id) \(text)"
          case .delete(let id): "delete \(id)"
          }
      }
  }

  func enqueue(_ change: Change, into outbox: inout [Change]) {
      guard let index = outbox.firstIndex(where: { $0.id == change.id }) else {
          outbox.append(change)
          return
      }
      switch (outbox[index], change) {
      case (.create, .create(let id, let text)), (.create, .update(let id, let text)):
          outbox[index] = .create(id: id, text: text)
      case (.update, .update):
          outbox[index] = change
      case (.create, .delete):
          outbox.remove(at: index)
      case (.update, .delete):
          outbox[index] = change
      default:
          outbox.append(change)
      }
  }

  var outbox: [Change] = []
  enqueue(.create(id: "a", text: "Milk"), into: &outbox)
  enqueue(.update(id: "a", text: "Oat milk"), into: &outbox)
  enqueue(.update(id: "b", text: "Bread"), into: &outbox)
  enqueue(.update(id: "b", text: "Rye bread"), into: &outbox)
  print(outbox.map(\.label))
  enqueue(.create(id: "c", text: "Eggs"), into: &outbox)
  enqueue(.delete(id: "c"), into: &outbox)
  enqueue(.delete(id: "b"), into: &outbox)
  print(outbox.map(\.label))
  ```

  ```output
  ["create a Oat milk", "update b Rye bread"]
  ["create a Oat milk", "delete b"]
  ```

  Each rule removes work the server doesn't need: two edits become one, a create plus edits stays one create with the final text, and an item created and deleted while offline never reaches the server at all. Keeping positions matters when changes depend on each other (a note and the folder it's in): the create stays ahead of anything that refers to it. A real outbox also keeps each entry's operation ID and base version; when an entry is replaced, it gets a new operation ID, because it's a different request.
````

````exercise
id: m37-l06-e5
type: design
prompt: "Design offline-first sync for a family grocery list: several people on their own phones add items, check them off and delete them, often in a store with poor reception. Cover the local model, the outbox, the conflict policy per field, deletes, the sync triggers, the status the UI shows, and the scenarios you'd test with fakes."
rubric:
  - Local store (SwiftData) as source of truth with client-generated IDs, base versions, a pending flag and tombstones.
  - An outbox of coalesced changes with operation IDs.
  - Per-field policies, e.g. checked state merges toward done or last server order, name edits keep both or server wins, quantities chosen deliberately.
  - Sync triggers (launch, foreground, after edits, pull to refresh, connectivity) guarded against overlap.
  - UI shows per-item pending and an overall calm offline status.
  - Tests for offline edits, concurrent check-offs, delete vs edit, lost responses and retries.
solution: |
  - **Local model:** `GroceryItem` (`@Model`) with a client `itemID` (UUID), `name`, `quantity`, `isChecked`, `baseVersion`, `needsUpload` and `isDeletedLocally`. Views read it with `@Query` and never wait on the network.
  - **Outbox:** coalesced changes per item (the exercise 4 rules), each with an operation ID and base version, pushed oldest first by a main-actor `SyncEngine` with an `isSyncing` guard.
  - **Conflicts, per field** (with the base, Module 31's field merge): `isChecked` merges toward checked (if anyone bought it, it's bought), unless one side explicitly unchecked it after the base; `name` changed on both sides keeps the server's and adds a "conflict" note, or keeps both as two items; `quantity` takes the larger, since it's safer to buy one too many. An edit on one side and a delete on the other: the delete wins for a checked item, the edit wins (the item is restored) for an unchecked one; write the rule down and test it.
  - **Deletes:** tombstones until accepted; deleting an item that was never synced drops its pending create.
  - **Triggers:** `.task` on launch, `scenePhase == .active`, a short debounce after edits (people check off several items in a row), pull to refresh, and connectivity returning. One guarded `sync()`.
  - **UI:** a small "not synced" mark per item; a status label with "Offline, 3 waiting" in the toolbar, never an alert.
  - **Tests with fakes:** offline add and check-off then sync; two devices checking the same item; one deletes while another renames; a lost response retried with the same operation ID; a pull that must not overwrite a pending check-off; a long offline session with dozens of coalesced edits.
````

````exercise
id: m37-l06-e6
type: explain
prompt: "Explain why this sync loop pushes before it pulls, and what would go wrong for a note with an unsent local edit if applyRemote didn't skip notes with pending changes."
code: |
  func sync() async {
      guard !isSyncing else { return }
      isSyncing = true
      defer { isSyncing = false }
      do {
          try await push()                                  // 1
          let (notes, cursor) = try await api.changes(after: self.cursor)
          for note in notes { store.applyRemote(note) }     // 2: skips notes with pending edits
          self.cursor = cursor
      } catch {
          // status = .offline or .failed; the outbox keeps everything
      }
  }
rubric:
  - Pushing first means pending edits are either accepted or resolved before the pull, and the pull includes the server's view of them.
  - Pulling first would bring in remote versions of notes the device has pending edits for.
  - Without the skip, a pulled copy overwrites the local edit in the store before it's pushed, so the edit is lost or pushed with the wrong text.
  - The cursor only advances after a successful pull.
solution: |
  **Push first** so the device's own changes reach the server before it asks what changed. Accepted edits come back in the pull as the server's view of them (with their new versions), and conflicted ones have been resolved by the policy. If it pulled first, it would receive the tablet's version of notes the phone has unsent edits for, at a moment when nothing has decided which wins.

  **The skip in `applyRemote`** protects edits that are still pending, which can happen even with push-first: the push may have stopped early (a failure throws out of the loop with changes left), or the user may edit during the sync. If the pulled copy were applied, the store would show the server's text and the user's edit would disappear from the screen; worse, the outbox would still hold the change, so the next push would resurrect it unexpectedly, or, if the outbox were rebuilt from the store, lose it for good. Skipping leaves those notes for the next push, where the version check and the policy decide.

  The cursor is assigned only after the pull is applied, so a sync that fails partway asks for the same changes next time.
````

## Summary

- The UI reads and writes the local store only. Writes are applied locally and queued in an outbox; a sync engine pushes, then pulls from a cursor.
- Use client-generated IDs, record each change's base version, coalesce pending changes, and never let a pull overwrite an item with a pending edit.
- Inject the conflict policy (server wins, client wins, keep both, field merge) per data type, and give every change an operation ID so retries after lost responses apply once.
- Deletes are tombstones until the server accepts them; an item created and deleted offline never needs to be sent.
- In SwiftUI, keep sync state on the SwiftData models and in an observable coordinator, show it calmly, sync on launch, foreground, edits and pull to refresh through one guarded `sync()`, and test every failure scenario with fakes.
