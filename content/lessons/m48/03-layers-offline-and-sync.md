---
id: m48-l03
title: Layers, offline support and sync
description: "The deep dive most mobile design interviews end up in: where data lives, who is the source of truth, and how edits made offline reach the server and other devices. You lay out the client's layers around a repository and a local store, compare read strategies, design a delta-sync protocol with change tokens and tombstones, compare conflict strategies on the same scenarios to see what each one loses, build a sync queue with per-item ordering and backoff driven by an injected clock, and decide what background refresh and push can and can't promise. The models are plain Swift, compiled and run."
module: m48
order: 3
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l02, m30-l06, m31-l06, m37-l06, m44-l05]
objectives:
  - Draw the client's layers (view, screen model, repository, local store, API client, sync engine) and say which one is the source of truth for the UI.
  - Choose between cache-first, network-first and stale-while-revalidate reads for a screen, and predict the states each one shows.
  - Design a delta-sync protocol with a change token, paging and tombstones, and explain why "updated since" without tombstones misses deletions.
  - Compare conflict strategies (reject, last writer wins, field-level merge, domain merge) on the same edits and state what each loses.
  - Design a persistent sync queue with idempotent operations, per-item ordering, backoff with jitter and a retry limit, tested with an injected clock.
  - State what background app refresh, background pushes and alert pushes guarantee, and design freshness that doesn't depend on them.
terms:
  - term: Source of truth
    definition: The one place a piece of data is read from. In an offline-capable app, the UI reads the local store; the network only updates the store.
  - term: Stale-while-revalidate
    definition: Show cached data at once, fetch fresh data in the background, then update the screen. The person sees content immediately and the freshest version shortly after.
  - term: Change token
    definition: "An opaque value from the server that marks a point in its change log. The client sends it back to ask for \"everything that changed since\", and stores the new token only after applying the changes."
  - term: Tombstone
    definition: A record that says an item was deleted, kept in the change log so clients that were offline during the deletion learn about it.
  - term: Head-of-line blocking (per item)
    definition: In a sync queue, holding later operations for an item until its earlier ones succeed, so the server applies them in order. Operations for other items keep flowing.
mastery:
  - Sketch the layers for a feature and point to where offline reads and writes go.
  - Predict the screen states for each read strategy with and without a cache and a network.
  - Write a change-feed contract and trace a client applying two pages of changes including a deletion.
  - For a given pair of concurrent edits, say what last writer wins and a field-level merge produce.
  - Trace a sync queue's retries over time with a scripted server and a fixed clock.
  - Explain why a background push can't be the only freshness mechanism.
resources: [usernotifications-background-updates, foundation-urlsessionwebsockettask, backgroundtasks-strategies, backgroundtasks-bgtaskscheduler, foundation-background-downloads, swiftdata, network-nwpathmonitor, rfc-9110]
cards:
  - id: m48-l03-c1
    front: In an offline-capable app, what does the UI read from?
    back: "The local store, always. The network's job is to update the store; the repository exposes the store's data (and sync status) to screens. That gives one path for online, offline and partly synced."
  - id: m48-l03-c2
    front: Why does "give me items updated since T" miss deletions?
    back: "A deleted row isn't in the table to be returned. The server needs tombstones (deletion records in the change log), and the client must apply them."
  - id: m48-l03-c3
    front: Concurrent edits on one list item, A changes quantity, B checks it off. What do LWW and field-level merge give?
    back: "Whole-record last writer wins keeps only the later push, so one edit is lost. A field-level three-way merge against the common base keeps both, because they touched different fields."
  - id: m48-l03-c4
    front: Name four properties of a good sync queue.
    back: "Persisted (survives termination); operations are idempotent (client IDs or keys); ordered per item, so a later edit never overtakes an earlier one; retries with capped exponential backoff plus jitter and a limit, separating retryable from permanent failures."
  - id: m48-l03-c5
    front: What do background refresh and background pushes promise?
    back: "Neither promises timing. earliestBeginDate only says the task won't start sooner; background pushes are low priority, may be throttled and aren't guaranteed. Refresh on launch and foreground is the guarantee; the others are opportunities."
---

## The idea in one sentence

**The UI reads one local source of truth, every write goes through a persistent queue, and sync is a protocol of tokens, tombstones and conflict rules**, designed so that being offline is just a slower version of being online.

> [!note] What was checked
> Quotes about background tasks and background notifications are from Apple's `BGTaskRequest.earliestBeginDate`, "Choosing Background Strategies for Your App" and "Pushing background updates to your App" pages, read in November 2026. Everything else here is design reasoning and plain Swift models, compiled and run with Swift 6.3; nothing was run against a real server.

## The layers

For Mise's shopping list, here's the shape you'd draw and narrate:

```text
 SwiftUI view  ──reads──►  ListModel (@Observable, main actor)
                              │ observes                ▲ intents: add, check, rename
                              ▼                         │
                     ShoppingListRepository ────────────┘
                     │ read: local store only     │ write: store + outbox, in one transaction
                     ▼                            ▼
              Local store (SwiftData)       Outbox (same store, persisted)
                     ▲                            │
                     │ apply changes              │ drain
                     └──────── Sync engine ◄──────┘
                                 │     ▲
                     POST /ops   │     │ GET /changes?since=token
                                 ▼     │
                               API client ── retry, auth, error mapping (lesson 2)
     triggers: launch, foreground, list screen appears, pull to refresh,
               connectivity returns, push received, background refresh
```

What each box owns:

- **The view and screen model** know nothing about the network. The model turns store data into view state and sends intents to the repository.
- **The repository** is the screen's only door to data. Reads come from the store; writes go to the store and the outbox in one transaction, so a crash can't leave one without the other.
- **The local store is the source of truth for the UI.** Online, offline and "sent but not acknowledged" all look the same to the screen: data, plus a sync status.
- **The sync engine** is the only thing that talks to the server about this data. It drains the outbox, pulls changes, resolves conflicts and updates the store.
- **Triggers** are many and cheap. None of them is guaranteed to fire at a particular time, so the engine is safe to run at any moment and does nothing when there's nothing to do.

Module 37 built these pieces in code; this lesson is about the decisions you'd defend in an interview.

## Read strategies

Not every screen needs the same policy. Three common ones, run against the same three situations:

```swift
enum Network {
    case ok([String])
    case offline
}

enum Strategy: String, CaseIterable {
    case cacheFirst, networkFirst, staleWhileRevalidate
}

/// The sequence of states a screen shows for one load.
func states(_ strategy: Strategy, cache: [String]?, network: Network) -> [String] {
    func show(_ items: [String], _ label: String) -> String { "\(label) \(items)" }
    switch strategy {
    case .cacheFirst:
        if let cache { return [show(cache, "cached")] }
        if case .ok(let fresh) = network { return ["spinner", show(fresh, "fresh")] }
        return ["spinner", "error: offline"]
    case .networkFirst:
        if case .ok(let fresh) = network { return ["spinner", show(fresh, "fresh")] }
        if let cache { return ["spinner", show(cache, "cached + offline banner")] }
        return ["spinner", "error: offline"]
    case .staleWhileRevalidate:
        var result = cache.map { [show($0, "cached")] } ?? ["spinner"]
        switch network {
        case .ok(let fresh): result.append(show(fresh, "fresh"))
        case .offline: result.append(cache == nil ? "error: offline" : "offline banner")
        }
        return result
    }
}

let situations: [(String, [String]?, Network)] = [
    ("cache, online", ["eggs"], .ok(["eggs", "milk"])),
    ("cache, offline", ["eggs"], .offline),
    ("no cache, offline", nil, .offline),
]

for strategy in Strategy.allCases {
    print(strategy.rawValue)
    for (name, cache, network) in situations {
        print("  \(name): \(states(strategy, cache: cache, network: network).joined(separator: " → "))")
    }
}
```

```output
cacheFirst
  cache, online: cached ["eggs"]
  cache, offline: cached ["eggs"]
  no cache, offline: spinner → error: offline
networkFirst
  cache, online: spinner → fresh ["eggs", "milk"]
  cache, offline: spinner → cached + offline banner ["eggs"]
  no cache, offline: spinner → error: offline
staleWhileRevalidate
  cache, online: cached ["eggs"] → fresh ["eggs", "milk"]
  cache, offline: cached ["eggs"] → offline banner
  no cache, offline: spinner → error: offline
```

How to pick, said as decisions:

- **Cache-first** never shows "milk" until the cache expires. Good for data that rarely changes (a recipe's steps, with an ETag revalidation once a day), bad for a shared list.
- **Network-first** shows a spinner every time, even when the cache would do, and on a slow network that spinner lasts until the timeout before falling back. Use it where stale data is harmful: a balance, a price at checkout.
- **Stale-while-revalidate** shows content at once and updates it. That's Mise's feed and shopping list. The cost is a visible change after a moment, so the UI must update rows in place without jumping the scroll position.
- **No cache and offline** is an error in every strategy. The design answer is to make that case rare (keep the last list, prefetch saved recipes), and when it happens, show an empty state that says why.

## A sync protocol: change tokens and tombstones

Downloading the whole list on every sync works for twenty items and stops working when lists are long or devices sync often. A delta protocol:

```text
GET /v1/lists/{id}/changes?since=<token>&limit=100
200 OK
{
  "changes": [
    { "id": "item-1", "deleted": false, "item": { …full item… }, "version": 7 },
    { "id": "item-2", "deleted": true, "version": 9 }
  ],
  "nextToken": "c-9",
  "hasMore": false
}
```

Rules worth stating:

- **The token is opaque** and comes from the server's change log (a sequence number, not a device timestamp: device clocks are wrong often enough to lose changes).
- **Apply, then store the token**, in the same transaction. If the app dies in between, the next sync repeats the page, so **applying a change must be idempotent**: setting an item to version 7 twice is the same as once.
- **Deletions are tombstones** in the log, kept long enough for devices that were offline. If a token is older than the server keeps tombstones, the server answers with a "resync required" error and the client downloads everything.
- **Pages** (`hasMore`) let a device that was offline for a month catch up in bounded requests.

The difference tombstones make, shown with a client that asks "what was updated since" instead:

```swift
struct Change {
    let sequence: Int
    let id: String
    let value: String?          // nil is a tombstone
}

// The server's change log for one shopping list.
let log = [
    Change(sequence: 1, id: "eggs", value: "Eggs ×6"),
    Change(sequence: 2, id: "milk", value: "Milk ×1"),
    Change(sequence: 3, id: "eggs", value: "Eggs ×12"),
    Change(sequence: 4, id: "milk", value: nil),
    Change(sequence: 5, id: "bread", value: "Bread ×1"),
]

/// The server's current rows, for the "updated since" approach.
let rows: [String: (value: String, updatedAt: Int)] = {
    var current: [String: (value: String, updatedAt: Int)] = [:]
    for change in log {
        current[change.id] = change.value.map { ($0, change.sequence) }   // a deletion removes the row
    }
    return current
}()

/// Delta sync with tokens and tombstones, two changes per page.
func syncWithTokens(_ items: inout [String: String], token: inout Int) {
    var page = 1
    while true {
        let batch = log.filter { $0.sequence > token }.prefix(2)
        if batch.isEmpty { break }
        for change in batch { items[change.id] = change.value }   // nil removes the item
        token = batch.last!.sequence
        print("  page \(page): applied \(batch.map(\.sequence)), token \(token)")
        page += 1
    }
}

/// "Give me rows updated after T": deleted rows are simply not there.
func syncUpdatedSince(_ items: inout [String: String], since: Int) {
    for (id, row) in rows where row.updatedAt > since { items[id] = row.value }
}

func describe(_ items: [String: String]) -> String {
    items.keys.sorted().map { items[$0]! }.joined(separator: ", ")
}

// Both devices synced once after sequence 2, then went offline.
var phone = ["eggs": "Eggs ×6", "milk": "Milk ×1"]
var token = 2
print("tokens and tombstones")
syncWithTokens(&phone, token: &token)
print("  result: \(describe(phone))")

var tablet = ["eggs": "Eggs ×6", "milk": "Milk ×1"]
syncUpdatedSince(&tablet, since: 2)
print("updated since")
print("  result: \(describe(tablet))")

token = 2
syncWithTokens(&phone, token: &token)
print("replaying from token 2: \(describe(phone))")
```

```output
tokens and tombstones
  page 1: applied [3, 4], token 4
  page 2: applied [5], token 5
  result: Bread ×1, Eggs ×12
updated since
  result: Bread ×1, Eggs ×12, Milk ×1
  page 1: applied [3, 4], token 4
  page 2: applied [5], token 5
replaying from token 2: Bread ×1, Eggs ×12
```

- **The tablet still has milk.** The deleted row isn't in `rows`, so "updated since" has nothing to return for it. That's the bug to name in an interview.
- **Replaying from an old token** (what happens when the app dies after applying a page but before saving the token) gives the same result, because applying a change sets a value rather than incrementing anything.
- `describe` sorts the keys because a dictionary's order isn't stable between runs.

## Conflicts: what each strategy loses

Two people in a household edit the same list item while one of them is offline. Base: "Eggs", quantity 6, not checked. The phone (offline) changes the quantity to 12; the tablet checks the item off and syncs first. Then the phone syncs. A second scenario has both change the quantity, to 12 and 10.

```swift
struct Item: Equatable, CustomStringConvertible {
    var name: String
    var quantity: Int
    var checked: Bool
    var description: String { "\(name) ×\(quantity)\(checked ? " ✓" : "")" }
}

enum Strategy: String, CaseIterable {
    case reject, lastWriterWins, fieldMerge
}

/// local: the phone's edit; remote: what the server has now (the tablet's edit); base: their common ancestor.
func resolve(_ strategy: Strategy, base: Item, local: Item, remote: Item) -> String {
    switch strategy {
    case .reject:
        return "409 Conflict: the phone must decide (server keeps \(remote))"
    case .lastWriterWins:
        return "\(local) (the phone's push arrived last)"
    case .fieldMerge:
        var merged = remote
        var conflicts: [String] = []
        func pick<T: Equatable>(_ path: WritableKeyPath<Item, T>, _ name: String) {
            let b = base[keyPath: path], l = local[keyPath: path], r = remote[keyPath: path]
            if l != b && r != b && l != r { conflicts.append(name) }    // both changed it differently
            else if l != b { merged[keyPath: path] = l }                 // only the phone changed it
        }
        pick(\.name, "name")
        pick(\.quantity, "quantity")
        pick(\.checked, "checked")
        return conflicts.isEmpty ? "\(merged)" : "\(merged), conflict on \(conflicts.joined(separator: ", ")) (server value kept)"
    }
}

let base = Item(name: "Eggs", quantity: 6, checked: false)
let scenarios: [(String, Item, Item)] = [
    ("different fields", Item(name: "Eggs", quantity: 12, checked: false), Item(name: "Eggs", quantity: 6, checked: true)),
    ("same field", Item(name: "Eggs", quantity: 12, checked: false), Item(name: "Eggs", quantity: 10, checked: false)),
]

for (name, local, remote) in scenarios {
    print("\(name): phone \(local), tablet \(remote)")
    for strategy in Strategy.allCases {
        print("  \(strategy.rawValue): \(resolve(strategy, base: base, local: local, remote: remote))")
    }
}
```

```output
different fields: phone Eggs ×12, tablet Eggs ×6 ✓
  reject: 409 Conflict: the phone must decide (server keeps Eggs ×6 ✓)
  lastWriterWins: Eggs ×12 (the phone's push arrived last)
  fieldMerge: Eggs ×12 ✓
same field: phone Eggs ×12, tablet Eggs ×10
  reject: 409 Conflict: the phone must decide (server keeps Eggs ×10)
  lastWriterWins: Eggs ×12 (the phone's push arrived last)
  fieldMerge: Eggs ×10, conflict on quantity (server value kept)
```

| Strategy | Loses | Costs | Fits |
| --- | --- | --- | --- |
| **Reject** (optimistic concurrency: the write carries its base version, the server returns 409 if it's stale) | Nothing silently | The client needs a resolution path, sometimes a person | Anything where a silent overwrite is unacceptable; also the building block for the others |
| **Last writer wins** (whole record) | The tablet's check mark, silently | Nothing to build | Single-user data, settings, data where the newest really is best |
| **Field-level merge** (three-way, against the base) | Only true same-field conflicts, by a stated rule | Storing the base per pending edit; field-level operations in the API | Structured records where people usually change different fields: list items, profiles |
| **Domain rules** | Depends on the rule | Thinking per field | Sets (union of tags), counters (sum of increments), "checked" in a shopping list (whoever checked most recently) |
| **Keep both** | Nothing | The person merges by hand | Free text: notes, documents (Module 37) |

For Mise's list: field-level merge, with "server value kept" for same-field conflicts on quantity (it's cheap to fix and nobody's typing is lost), and deletions winning over edits (an item someone deleted shouldn't come back because someone else changed its quantity). Say both rules out loud; they're product decisions.

> [!tip] "Who wrote last" is decided by the server
> "Last writer" means the push the server applied last, never the device's timestamp. Module 31 showed why device clocks can't decide.

## The sync queue

Writes made offline wait in an outbox. The queue that drains it needs these properties:

- **Persisted**, in the same store as the data, written in the same transaction as the edit.
- **Idempotent operations**: each has a client-generated ID the server uses to recognize a retry (lesson 2, Module 37).
- **Ordered per item**: "set quantity to 12" must not overtake an earlier "rename to Free-range eggs" for the same item, but a failing item shouldn't block every other item.
- **Retryable versus permanent failures**: a timeout or 503 retries; a validation error never will succeed and goes to the person.
- **Backoff with a cap, jitter and a limit**, driven by a clock you can control in tests.

```swift
enum SendResult {
    case success
    case retryable
    case permanent(String)
}

protocol TimeSource: AnyObject {
    var now: Int { get }            // seconds
}

final class ManualTime: TimeSource {
    var now = 0
}

struct PendingOperation {
    let id: String
    let itemID: String
    var attempts = 0
    var notBefore = 0
}

final class SyncQueue {
    private(set) var pending: [PendingOperation] = []
    private let time: any TimeSource
    private let maxAttempts: Int
    private let jitter: (Int) -> Int
    private let send: (PendingOperation) -> SendResult

    init(time: any TimeSource, maxAttempts: Int, jitter: @escaping (Int) -> Int,
         send: @escaping (PendingOperation) -> SendResult) {
        self.time = time
        self.maxAttempts = maxAttempts
        self.jitter = jitter
        self.send = send
    }

    func enqueue(_ id: String, item: String) {
        pending.append(PendingOperation(id: id, itemID: item))
    }

    /// Exponential backoff: 2, 4, 8… seconds, capped at 60, then jittered.
    private func delay(afterAttempt attempt: Int) -> Int {
        jitter(min(60, 2 << (attempt - 1)))
    }

    /// One pass over the queue in order. Returns the next time something becomes due, or nil when empty.
    func drain() -> Int? {
        var blockedItems: Set<String> = []
        var index = 0
        while index < pending.count {
            var operation = pending[index]
            let t = time.now
            if blockedItems.contains(operation.itemID) {
                print("t=\(t) \(operation.id): waits behind an earlier \(operation.itemID) operation")
                index += 1
                continue
            }
            if operation.notBefore > t {
                blockedItems.insert(operation.itemID)
                index += 1
                continue
            }
            operation.attempts += 1
            switch send(operation) {
            case .success:
                print("t=\(t) \(operation.id): sent")
                pending.remove(at: index)
            case .permanent(let reason):
                print("t=\(t) \(operation.id): rejected (\(reason)), shown to the person")
                pending.remove(at: index)
            case .retryable where operation.attempts >= maxAttempts:
                print("t=\(t) \(operation.id): gave up after \(operation.attempts) attempts, kept as failed")
                pending.remove(at: index)
            case .retryable:
                operation.notBefore = t + delay(afterAttempt: operation.attempts)
                print("t=\(t) \(operation.id): failed, retry at t=\(operation.notBefore)")
                pending[index] = operation
                blockedItems.insert(operation.itemID)
                index += 1
            }
        }
        return pending.map(\.notBefore).filter { $0 > time.now }.min()
    }
}

// A scripted server: each operation's results, in order.
var script: [String: [SendResult]] = [
    "op1": [.retryable, .retryable, .success],
    "op2": [.success],
    "op3": [.success],
    "op4": [.permanent("quantity must be positive")],
    "op5": [.retryable, .retryable, .retryable, .retryable],
]

let time = ManualTime()
let queue = SyncQueue(time: time, maxAttempts: 4, jitter: { $0 }, send: { operation in
    script[operation.id]!.removeFirst()
})
queue.enqueue("op1", item: "eggs")
queue.enqueue("op2", item: "milk")
queue.enqueue("op3", item: "eggs")
queue.enqueue("op4", item: "bread")
queue.enqueue("op5", item: "flour")

while let next = queue.drain() {
    time.now = next
}
print("left in queue: \(queue.pending.count)")
```

```output
t=0 op1: failed, retry at t=2
t=0 op2: sent
t=0 op3: waits behind an earlier eggs operation
t=0 op4: rejected (quantity must be positive), shown to the person
t=0 op5: failed, retry at t=2
t=2 op1: failed, retry at t=6
t=2 op3: waits behind an earlier eggs operation
t=2 op5: failed, retry at t=6
t=6 op1: sent
t=6 op3: sent
t=6 op5: failed, retry at t=14
t=14 op5: gave up after 4 attempts, kept as failed
left in queue: 0
```

- **op3 waits for op1** because both touch "eggs"; op2 (milk) goes through at once. Strict FIFO across all items would have held milk behind eggs for six seconds.
- **op4 is permanent** and leaves the queue immediately with a message for the person, instead of retrying forever.
- **op5 gives up** after four attempts. "Kept as failed" means the item shows "Not synced, tap to retry", not that the edit disappears.
- **The clock is injected.** The test runs in microseconds and the timeline is exact. The app's `TimeSource` reads the real clock, and the engine schedules its next `drain()` at the returned time (or when connectivity returns, which should also reset backoff for `notConnected` failures, as Module 43 discussed).
- **Jitter is injected too.** `{ $0 }` keeps the output reproducible; the app passes something like `{ Int.random(in: $0 / 2 ... $0) }` so a thousand phones that lost the network together don't all retry at the same second.

## Background refresh and push: opportunities, not guarantees

You'll be asked "how does the list stay fresh when the app isn't open?" The honest answer has three parts:

- **Background app refresh** (`BGAppRefreshTaskRequest`, Module 44): Apple's documentation for `earliestBeginDate` says the system "doesn't guarantee launching the task at the specified date, but only that it won't begin sooner." The system decides based on how the person uses the app, and a refresh task gets up to 30 seconds.
- **Background pushes**: low priority, may be throttled, "don't try to send more than two or three per hour", and the system keeps only the newest one if several are held. Good as a hint: "the list changed, sync when you can."
- **Alert pushes** reach the person, not your sync engine. "Ana added flour" is useful in itself; tapping it opens the app, which syncs.

So the design is: **sync on launch, on foreground, when the list screen appears, on pull to refresh and when connectivity returns**; use background refresh and background pushes to make that first sync usually unnecessary. Large transfers (photos for saved recipes) go to a background `URLSession`, which continues while the app is suspended (Module 44).

## Common mistakes

> [!error] The network as the UI's source of truth
> When screens render the network response and only write it to a cache on the side, offline becomes a separate code path with its own bugs. Render the store; let the network update the store.

> [!error] Sync by device timestamp
> "Changes since my last sync time" misses anything the server committed with an earlier timestamp, and device clocks drift. Use the server's change token.

> [!error] No tombstones
> Without deletion records, clients that were offline never learn an item was deleted. Keep tombstones, and define what happens when a token is older than they are.

> [!error] Whole-record last writer wins for shared, structured data
> Two people changing different fields of one item lose one edit silently. Merge per field against the base, or reject and resolve.

> [!error] A global FIFO queue
> One failing operation blocks every other item's edits. Order per item, not globally.

> [!error] Retrying permanent failures
> A validation error won't pass on the tenth try. Classify failures and surface the permanent ones.

> [!error] Relying on background push for freshness
> It's throttled and not guaranteed. Refresh on launch and foreground.

## Exercises

````exercise
id: m48-l03-e1
type: comprehension
prompt: "A banking app's \"available balance\" on the payment confirmation screen. Which read strategy fits?"
choices:
  - text: "Network-first, falling back to the cached value only with a clear \"as of\" time and the payment disabled."
    correct: true
    why: "A stale balance at the moment of paying is harmful; when the network is down, showing the last value with its age is honest, and blocking the payment avoids acting on it."
  - text: "Cache-first, refreshing once a day."
    correct: false
    why: "The balance can change minutes before a payment; a day-old value at confirmation is wrong."
  - text: "Stale-while-revalidate with no indication of which value is shown."
    correct: false
    why: "The person could confirm a payment while the stale value is on screen."
  - text: "No cache at all: always show a spinner until the network answers."
    correct: false
    why: "Close, but offline it shows nothing useful. A cached value with its age and a disabled payment is better."
solution: |
  Network-first fits data where staleness causes harm at the moment of action. The fallback matters too: the cached balance with "as of 10:42" tells the person what they're looking at, and disabling the confirm button keeps them from acting on it. The transaction history on the same app can still be stale-while-revalidate; strategies are per screen.
````

````exercise
id: m48-l03-e2
type: prediction
prompt: "A smaller sync queue with the same rules: backoff 2, 4, 8… with no jitter, ordered per item, at most 3 attempts. What does it print?"
code: |
  enum Result { case ok, retry, fail }

  struct Op {
      let id: String
      let item: String
      var attempts = 0
      var notBefore = 0
  }

  var script: [String: [Result]] = ["a1": [.retry, .ok], "b1": [.retry, .retry, .retry], "a2": [.ok]]
  var queue = [Op(id: "a1", item: "a"), Op(id: "b1", item: "b"), Op(id: "a2", item: "a")]
  var now = 0

  while !queue.isEmpty {
      var blocked: Set<String> = []
      var index = 0
      while index < queue.count {
          if blocked.contains(queue[index].item) || queue[index].notBefore > now {
              blocked.insert(queue[index].item)
              index += 1
              continue
          }
          queue[index].attempts += 1
          let result = script[queue[index].id]!.removeFirst()
          if result == .ok {
              print("t=\(now) \(queue[index].id) ok")
              queue.remove(at: index)
          } else if result == .fail || queue[index].attempts == 3 {
              print("t=\(now) \(queue[index].id) dropped")
              queue.remove(at: index)
          } else {
              queue[index].notBefore = now + (2 << (queue[index].attempts - 1))
              print("t=\(now) \(queue[index].id) retry at \(queue[index].notBefore)")
              blocked.insert(queue[index].item)
              index += 1
          }
      }
      if let next = queue.map(\.notBefore).filter({ $0 > now }).min() { now = next }
  }
output: |
  t=0 a1 retry at 2
  t=0 b1 retry at 2
  t=2 a1 ok
  t=2 b1 retry at 6
  t=2 a2 ok
  t=6 b1 dropped
hints:
  - "a2 can't go at t=0: a1 for the same item is waiting."
  - "At t=2 the pass goes in order: a1 succeeds and is removed, so a2 is no longer blocked when the pass reaches it."
  - "b1's third attempt is at t=6 and it has used its 3 attempts."
solution: |
  ```output
  t=0 a1 retry at 2
  t=0 b1 retry at 2
  t=2 a1 ok
  t=2 b1 retry at 6
  t=2 a2 ok
  t=6 b1 dropped
  ```

  At t=0, a1 fails and blocks item a, b1 fails, and a2 is skipped because item a is blocked. At t=2, a1 succeeds and leaves the queue, b1 fails again (second attempt, backoff 4, due at 6), and a2 is now unblocked and succeeds in the same pass. At t=6, b1's third attempt fails and it reaches the limit. The order within a pass is the queue order, which is why a2 goes after b1 at t=2.
````

````exercise
id: m48-l03-e3
type: fill-in
prompt: "Complete the change-feed contract and the client rule that make deletions and replays safe."
code: |
  GET /v1/lists/{id}/changes?since=<[[1]]>&limit=100
  → { "changes": [...], "nextToken": "...", "hasMore": true }

  Deleted items appear in "changes" as [[2]].
  The client applies a page and saves nextToken in the same [[3]].
  Applying a change twice has the same effect as once: it is [[4]].
blanks:
  - id: "1"
    answers: ["token", "change token", "changeToken"]
  - id: "2"
    answers: ["tombstones", "tombstone"]
  - id: "3"
    answers: ["transaction"]
  - id: "4"
    answers: ["idempotent"]
solution: |
  The client sends back the opaque **token** it last saved. Deletions are **tombstones** in the change log. Applying a page and saving the next token happen in one **transaction**, and because a crash between the two is still possible on some paths (or the server may resend), applying changes must be **idempotent**: set the item to the version in the change, delete if it's a tombstone, never increment.
````

````exercise
id: m48-l03-e4
type: solve
prompt: |
  Write `merge(base:local:remote:)` for a profile with three fields (`name`, `city`, `newsletter`). For each field: if only the local side changed it, take local; otherwise take remote. Collect the names of fields both sides changed to different values. Return the merged profile and the conflicting field names.

  Expected output:

  ```output
  Ana Ruiz, Lisbon, true, conflicts: []
  Ana, Porto, false, conflicts: ["city"]
  Ana R., Madrid, true, conflicts: []
  ```
starter: |
  struct Profile {
      var name: String
      var city: String
      var newsletter: Bool
  }

  func merge(base: Profile, local: Profile, remote: Profile) -> (Profile, [String]) {
      // your code
      return (remote, [])
  }

  let base = Profile(name: "Ana", city: "Madrid", newsletter: false)
  for (local, remote) in [
      (Profile(name: "Ana Ruiz", city: "Madrid", newsletter: false), Profile(name: "Ana", city: "Lisbon", newsletter: true)),
      (Profile(name: "Ana", city: "Lisbon", newsletter: false), Profile(name: "Ana", city: "Porto", newsletter: false)),
      (Profile(name: "Ana R.", city: "Madrid", newsletter: true), Profile(name: "Ana R.", city: "Madrid", newsletter: true)),
  ] {
      let (merged, conflicts) = merge(base: base, local: local, remote: remote)
      print("\(merged.name), \(merged.city), \(merged.newsletter), conflicts: \(conflicts)")
  }
hints:
  - "A field is in conflict only if local ≠ base, remote ≠ base and local ≠ remote."
  - "Both sides making the same change isn't a conflict (the third case)."
rubric:
  - Takes the local value only when local changed and remote didn't, or both made the same change.
  - Keeps remote for same-field conflicts and reports them.
  - Doesn't report identical changes as conflicts.
solution: |
  ```swift
  struct Profile {
      var name: String
      var city: String
      var newsletter: Bool
  }

  func merge(base: Profile, local: Profile, remote: Profile) -> (Profile, [String]) {
      var merged = remote
      var conflicts: [String] = []
      func field<T: Equatable>(_ path: WritableKeyPath<Profile, T>, _ name: String) {
          let b = base[keyPath: path], l = local[keyPath: path], r = remote[keyPath: path]
          if l != b && r != b && l != r {
              conflicts.append(name)
          } else if l != b {
              merged[keyPath: path] = l
          }
      }
      field(\.name, "name")
      field(\.city, "city")
      field(\.newsletter, "newsletter")
      return (merged, conflicts)
  }

  let base = Profile(name: "Ana", city: "Madrid", newsletter: false)
  for (local, remote) in [
      (Profile(name: "Ana Ruiz", city: "Madrid", newsletter: false), Profile(name: "Ana", city: "Lisbon", newsletter: true)),
      (Profile(name: "Ana", city: "Lisbon", newsletter: false), Profile(name: "Ana", city: "Porto", newsletter: false)),
      (Profile(name: "Ana R.", city: "Madrid", newsletter: true), Profile(name: "Ana R.", city: "Madrid", newsletter: true)),
  ] {
      let (merged, conflicts) = merge(base: base, local: local, remote: remote)
      print("\(merged.name), \(merged.city), \(merged.newsletter), conflicts: \(conflicts)")
  }
  ```

  ```output
  Ana Ruiz, Lisbon, true, conflicts: []
  Ana, Porto, false, conflicts: ["city"]
  Ana R., Madrid, true, conflicts: []
  ```

  Starting from `remote` means "remote wins unless only local changed it". Key paths let one generic helper handle every field; a real app would add fields as it adds them to the model, and a test that fails when a field is missing from the merge (compare the list of handled fields to the model's) keeps that honest.
````

````exercise
id: m48-l03-e5
type: find-errors
prompt: "A proposed sync design for Mise's shopping list. Mark every real problem."
code: |
  - Screens render the API response; it's also saved to a cache for offline.
  - Sync asks GET /items?updatedAfter=<device time of last sync>.
  - Edits are sent immediately; if offline, they're kept in memory and retried every 5 s.
  - Conflicts: the server keeps whichever full item arrives last.
  - A background push is sent on every change; that keeps all devices fresh.
choices:
  - text: "The UI reads the network response, so offline is a separate path."
    correct: true
  - text: "updatedAfter with the device's clock misses deletions and is wrong when the clock is off."
    correct: true
  - text: "Pending edits in memory are lost if the app is terminated."
    correct: true
  - text: "Fixed 5-second retries while offline waste battery and don't back off."
    correct: true
  - text: "Whole-item last writer wins silently loses concurrent edits to different fields."
    correct: true
  - text: "Background pushes are throttled and not guaranteed, so they can't be what keeps devices fresh."
    correct: true
  - text: "Sending edits immediately when online is wrong; they should always wait for a batch."
    correct: false
    why: "Sending promptly is fine (through the queue); batching is an optimization, not a requirement."
rubric:
  - I flagged each of the six real problems.
  - I didn't flag sending promptly as a problem.
solution: |
  Every point except the last choice is a real problem. The fixes are this lesson's design: the store is the source of truth; a change token with tombstones replaces `updatedAfter`; the outbox is persisted with the edit, in one transaction; retries back off with jitter and wait for connectivity when offline; merge per field against the base; and refresh on launch and foreground, with pushes as hints.
````

````exercise
id: m48-l03-e6
type: design
prompt: "Mise adds \"cook mode\": while cooking, a person checks off steps and the timer state should continue on their iPad if they switch devices. Design the data, sync and conflict handling. What's the source of truth, what gets synced, how fresh it must be, and what happens offline?"
rubric:
  - Keeps per-device UI state separate from what's synced; syncs only a small session record.
  - Chooses a conflict rule that fits (for example, newest session wins by server order, steps as a set union).
  - Uses timer end time from the server or an absolute time, not a running countdown.
  - Explains freshness (foreground sync on device switch, maybe a push) and offline behavior.
solution: |
  - **What's synced:** a small `CookSession` record: recipe ID, completed step IDs, and each timer as an absolute end time plus a paused remaining duration. The scroll position and screen state stay per device.
  - **Source of truth:** the local store on each device; the session syncs through the same queue and change feed as the list.
  - **Conflicts:** completed steps are a set, so merge by union (unchecking is rare; treat it as an explicit "remove" operation). Timers: the most recent change applied by the server wins, since a person controls one device at a time.
  - **Timers:** store the end time, not a countdown, so a device that opens the session later computes the remaining time itself. Device clock skew is a few seconds at most for most people; acceptable for cooking, and the server's time can correct it.
  - **Freshness:** when the iPad opens the recipe it syncs first (stale-while-revalidate); an alert push isn't needed. A background push as a hint is optional.
  - **Offline:** cook mode works fully; edits queue and merge later.
````

## Summary

- The UI reads the local store; the repository writes the store and the outbox together; only the sync engine talks to the server.
- Choose read strategies per screen: cache-first for rarely changing data, network-first where staleness harms, stale-while-revalidate for most feeds and lists.
- Delta sync uses an opaque server token, pages, tombstones and idempotent application, with the token saved in the same transaction as the changes.
- Compare conflict strategies by what they lose: whole-record last writer wins drops concurrent edits; a three-way field merge keeps them and leaves only true same-field conflicts to a stated rule.
- A sync queue is persisted, idempotent, ordered per item, separates permanent from retryable failures, backs off with a cap, jitter and a limit, and takes its clock as a dependency.
- Background refresh and pushes don't promise timing. Sync on launch and foreground; treat the rest as opportunities.
