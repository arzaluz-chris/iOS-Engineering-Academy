---
id: m48-l06
title: Case studies
description: "Three complete designs worked the way you'd present them in 45 minutes: a photo feed driven by its estimates, a chat with offline messaging and a deep dive on the client's message timeline, and a live order-tracking screen fed by pushes, polling and a socket that arrive out of order. Each goes from requirements to API, models, layers, a deep dive, failure modes, metrics and trade-offs, and the logic at the heart of each (estimates, timeline merging, a versioned state reducer with an injected clock) is plain Swift, compiled and run."
module: m48
order: 6
level: advanced
minutes: 90
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l05]
objectives:
  - Present a complete mobile design in the five-phase structure, with requirements that drive the decisions.
  - Use estimates to choose image variants, cache budgets and data limits for a photo feed.
  - Design a chat client's timeline that shows pending messages, deduplicates acknowledgments and echoes, and detects gaps by sequence number.
  - Design a live-status screen that merges updates from several channels with versions, never moves backward, and marks stale data using an injected clock.
  - Name the failure modes, metrics and trade-offs of each design.
terms:
  - term: Optimistic UI
    definition: Showing the result of a person's action immediately, before the server confirms it, and reconciling (or rolling back) when the response arrives.
  - term: Echo
    definition: "In chat, the copy of your own message that the server broadcasts back to all participants, including you. The client must recognize it (by client ID) and not show it twice."
  - term: Server sequence number
    definition: "A per-conversation counter the server assigns as it accepts messages. It defines the order everyone sees and reveals gaps: if you have 3 and receive 5, message 4 is missing."
  - term: Monotonic state
    definition: State that only moves forward (an order's status, a version number). Updates that would move it backward are stale and are ignored.
mastery:
  - Present any of the three designs in 45 minutes from memory, adapting to the interviewer's questions.
  - Compute the per-session data and cache numbers for a photo feed from stated assumptions.
  - Trace a chat timeline through sends, acknowledgments, echoes and a gap.
  - Write a reducer that applies versioned updates from several channels and ignores stale ones.
  - Adapt one of the designs when a requirement changes.
resources: [foundation-urlsession, foundation-nscache, uikit-prefetching, backgroundtasks-strategies, activitykit-live-activities, activitykit-push-updates, usernotifications-asking-permission, metrickit]
cards:
  - id: m48-l06-c1
    front: "Photo feed: what should each post's payload carry for images?"
    back: "Several image variants (width and URL) so the client picks the size it displays, the aspect ratio so the cell is sized before the image loads, a placeholder color, and alt text."
  - id: m48-l06-c2
    front: "Chat: how does the client avoid showing your message twice?"
    back: "Every message has a client-generated ID. The acknowledgment and the server's broadcast echo both carry it; the first one moves the pending message to its sequence slot, and the second is recognized and ignored."
  - id: m48-l06-c3
    front: "Chat: how do you detect missed messages?"
    back: "Sequence numbers are contiguous per conversation. If the highest contiguous sequence is 3 and 5 arrives, 4 is missing: fetch the range after reconnecting, and don't advance the read marker past the gap."
  - id: m48-l06-c4
    front: "Order tracking: updates come from push, polling and a socket. How do you merge them?"
    back: "Each update carries a server version. Apply only versions newer than the one you have; once the order is delivered or cancelled, ignore everything else. The channel doesn't matter, the version does."
  - id: m48-l06-c5
    front: "Order tracking: when should the courier's location be shown as stale?"
    back: "When the newest location's timestamp is older than a threshold (say 60 seconds), computed with an injected clock so it's testable. Show the last position with \"updated 2 min ago\", never an animated dot pretending to be live."
---

## The idea in one sentence

**A good design answer is the five phases from lesson 1 applied to one concrete product**, where the requirements choose the decisions, one deep dive shows real mechanism, and the trade-offs are stated rather than hidden.

> [!note] How to use this lesson
> Read one case, close the lesson, and present it out loud in 45 minutes with a timer. Then compare. The interview bank's `system-design` questions (news feed, chat, banking transactions, notes, uploads) are different prompts from these; they make good practice afterwards. Product details here are invented for the exercise and describe no real company's app. The Swift models were compiled and run with Swift 6.3; nothing here was measured on a device.

## Case 1: a photo feed

**Prompt:** "Design the home feed for a photo-sharing app. People follow friends and see their posts, one to four photos each, newest first. They can like posts."

### Requirements and scope

| Functional | Non-functional |
| --- | --- |
| See posts from people you follow, newest first | First content within about a second of launch, from cache |
| Swipe through a post's photos | Smooth scrolling on older supported devices |
| Like and unlike | Reasonable data use; much less on Low Data Mode |
| Pull to refresh; scroll for older posts | Last session's feed readable offline |
| | Photos have alt text; works with VoiceOver and large text |

**Out:** posting, comments, stories, ranking, notifications. **Assume:** chronological order computed by the server; the numbers below.

### Estimates

```swift
func megabytes(_ bytes: Int) -> String {
    let tenths = (bytes + 50_000) / 100_000
    return "\(tenths / 10).\(tenths % 10) MB"
}

// Assumptions, stated before any arithmetic.
let postsPerSession = 60
let firstPhotoBytes = 180_000          // 1,080-pixel-wide JPEG variant
let lowDataPhotoBytes = 50_000         // 540-pixel-wide variant
let swipedSharePercent = 30            // posts where people swipe to see more photos
let extraPhotosWhenSwiped = 2
let diskCacheBudget = 200_000_000
let cellWidthPixels = 1_170            // 390 points at 3x
let cellHeightPixels = 1_463           // 4:5 portrait photo
let postsVisibleAtOnce = 2
let screensKeptDecoded = 3

let swipedPosts = postsPerSession * swipedSharePercent / 100
let photos = postsPerSession + swipedPosts * extraPhotosWhenSwiped
print("Photos per session: \(photos)")
print("Data per session: \(megabytes(photos * firstPhotoBytes)), Low Data Mode: \(megabytes(photos * lowDataPhotoBytes))")
print("Disk cache holds about \(diskCacheBudget / firstPhotoBytes) photos, \(diskCacheBudget / (photos * firstPhotoBytes)) sessions")

let decoded = cellWidthPixels * cellHeightPixels * 4
print("One decoded photo: \(megabytes(decoded)); memory cache budget: \(megabytes(decoded * postsVisibleAtOnce * screensKeptDecoded))")
```

```output
Photos per session: 96
Data per session: 17.3 MB, Low Data Mode: 4.8 MB
Disk cache holds about 1111 photos, 11 sessions
One decoded photo: 6.8 MB; memory cache budget: 41.1 MB
```

Decisions from these numbers:

- **Images are the whole cost**, so the payload offers **several variants per photo** and the client picks by cell size and network (Low Data Mode cuts the session from about 17 MB to about 5 MB).
- **Only the first photo of each post is prefetched.** The other photos load when the person starts swiping, since only 30% of posts get swiped.
- **The disk cache holds about eleven sessions**, enough for the "last session offline" requirement with room to spare, so 200 MB is a defensible budget. It could be smaller.
- **Decoded photos are almost 7 MB each.** The memory cache keeps about six (three screens), and decoding happens at display size off the main actor (lesson 4).

### API and models

```text
GET /v1/home?cursor=<opaque>&limit=20
{
  "posts": [{
    "id": "p_812", "author": { "id": "u_3", "name": "Lena", "avatar": [variants] },
    "createdAt": "2026-11-03T18:22:05Z",
    "photos": [{
      "aspectRatio": "4:5", "placeholderColor": "#8A6F5C", "altText": "…",
      "variants": [{ "width": 540, "url": "…" }, { "width": 1080, "url": "…" }, { "width": 2160, "url": "…" }]
    }],
    "likeCount": 41, "likedByMe": false, "version": 7
  }],
  "nextCursor": "…"
}

GET /v1/home/changes?since=<token>   → updated or deleted posts among those the client has
PUT /v1/posts/{id}/like              → idempotent; DELETE to unlike
```

- **Aspect ratio and placeholder color** let a cell size itself and paint before the image arrives, so nothing jumps.
- **Variants** let the client choose the smallest width at least as wide as the cell in pixels.
- **`version`** lets a post edited or with a new like count replace the cached copy; the changes endpoint carries deletions (a post the author removed must disappear from caches).

### Layers and the main flow

```text
FeedView ─► FeedModel ─► FeedRepository ─┬─► FeedStore (last ~200 posts, SwiftData)
                              ▲          ├─► API client (cursor pages, changes, likes)
                              │          └─► Like outbox (PUT/DELETE, coalesced per post)
                              │
              ImagePipeline (memory: decoded by URL+size; disk: 200 MB LRU; in-flight table)
```

Launch: render the store's posts at once (stale-while-revalidate); fetch page one; merge by ID (lesson 4), inserting new posts above with a "New posts" pill rather than moving the person's scroll position. Scrolling near the end loads the next page; the prefetch window requests first photos ahead.

### Deep dive: likes

A like must feel instant, survive bad networks and never double-count.

- **Optimistic:** the heart fills and the count goes up immediately; the store records `likedByMe = true` and a pending operation.
- **Coalesced per post:** like, unlike, like in two seconds is one pending state ("liked"), not three requests. The outbox keeps the latest desired state per post.
- **Idempotent:** `PUT /like` and `DELETE /like` set state; retries are harmless.
- **Reconciled:** when the server responds or the post's next version arrives, its `likeCount` replaces the local one. The local `+1` was a display estimate.
- **Rolled back** only on a permanent failure (the post was deleted), with a quiet message.

### Failure modes, metrics, trade-offs

- **Offline:** cached feed with "Updated 2 hours ago"; likes queue; no page loads past the cache.
- **A page fails:** a retry row at the bottom, not an alert.
- **A deleted post:** removed via the changes feed; a tap on a stale one shows "This post was removed."
- **Metrics:** time to first content (cached vs fresh), next-page failure rate, bytes per session by network type, image cache hit rate, hitches and memory from MetricKit.
- **Trade-offs:** chronological order with a server cursor is simple; ranked feeds make "new posts" and gaps harder. A WebSocket for live like counts isn't worth it; refresh counts when posts reappear. A 200 MB cache trades disk for data and offline reading.

## Case 2: chat with offline messaging

**Prompt:** "Design a messaging app for one-to-one and small group conversations. Messages must never be lost, even when sent offline."

### Requirements and scope

| Functional | Non-functional |
| --- | --- |
| Send and receive text messages | Messages written offline are sent when possible, in order, exactly once |
| See conversation history | Same order for every participant |
| Delivery and read status | New messages appear within about a second while the app is open |
| Notifications when the app isn't open | History readable offline; message content never in logs or analytics |

**Out:** media, calls, end-to-end encryption, search. **Assume:** groups up to 50 people; a few hundred messages per conversation per day at most.

### API and channels

- **Foreground:** a WebSocket (`URLSessionWebSocketTask`) carries new messages, acknowledgments and typing indicators.
- **Background:** alert pushes for new messages ("Lena: …", subject to the person's settings); tapping one opens the conversation, which syncs.
- **Sending:** over the socket when connected, otherwise over HTTPS: `PUT /v1/conversations/{id}/messages/{clientID}`. The client ID makes it idempotent on both paths.
- **Sync:** `GET /v1/conversations/{id}/messages?after=<seq>&limit=200` after reconnecting or on launch.
- **Read status:** `PUT /v1/conversations/{id}/read` with `{ "upTo": <seq> }`, debounced.

The server assigns each accepted message the next **sequence number** in its conversation. Sequence numbers order the conversation for everyone and make gaps visible. Timestamps are displayed, never used for ordering.

### Deep dive: the client's timeline

The screen shows confirmed messages in sequence order, followed by the person's own pending messages in the order they were written. Four events change it: sending locally, an acknowledgment of your message, the server's echo of your message (it broadcasts every message to every participant, you included), and other people's messages. The model:

```swift
struct Message {
    let clientID: String
    let author: String
    let text: String
}

struct Timeline {
    private(set) var confirmed: [Int: Message] = [:]       // by server sequence number
    private(set) var pending: [Message] = []                // mine, not yet acknowledged, in send order

    mutating func send(_ clientID: String, _ text: String) {
        pending.append(Message(clientID: clientID, author: "me", text: text))
    }

    /// An acknowledgment, an echo, another person's message or a synced one: all carry a sequence number.
    /// Returns what happened, for the trace.
    @discardableResult
    mutating func receive(seq: Int, _ message: Message) -> String {
        if let existing = confirmed[seq] {
            return existing.clientID == message.clientID ? "duplicate of \(seq), ignored" : "conflicting \(seq)!"
        }
        pending.removeAll { $0.clientID == message.clientID }   // my message, now confirmed
        confirmed[seq] = message
        return "stored at \(seq)"
    }

    /// Highest sequence number with nothing missing below it.
    var contiguousUpTo: Int {
        var seq = 0
        while confirmed[seq + 1] != nil { seq += 1 }
        return seq
    }

    var missing: [Int] {
        guard let highest = confirmed.keys.max() else { return [] }
        return (1...highest).filter { confirmed[$0] == nil }
    }

    func render() -> String {
        let shown = confirmed.keys.sorted().map { "\($0):\(confirmed[$0]!.text)" }
            + pending.map { "…\($0.text)" }
        return shown.joined(separator: " ")
    }
}

var chat = Timeline()
@MainActor                              // reads the top-level `chat`, which lives on the main actor
func step(_ label: String, _ result: String = "") {
    let suffix = result.isEmpty ? "" : " [\(result)]"
    print("\(label)\(suffix)\n   \(chat.render())   contiguous \(chat.contiguousUpTo), missing \(chat.missing)")
}

chat.send("c1", "on my way")
chat.send("c2", "5 min")
step("offline, two sent")
step("sync: Lena 1", chat.receive(seq: 1, Message(clientID: "l1", author: "Lena", text: "where are you?")))
step("sync: Lena 2", chat.receive(seq: 2, Message(clientID: "l2", author: "Lena", text: "hello?")))
step("ack c1", chat.receive(seq: 3, Message(clientID: "c1", author: "me", text: "on my way")))
step("echo c1", chat.receive(seq: 3, Message(clientID: "c1", author: "me", text: "on my way")))
step("socket: Lena 5", chat.receive(seq: 5, Message(clientID: "l3", author: "Lena", text: "ok!")))
step("ack c2", chat.receive(seq: 4, Message(clientID: "c2", author: "me", text: "5 min")))
```

```output
offline, two sent
   …on my way …5 min   contiguous 0, missing []
sync: Lena 1 [stored at 1]
   1:where are you? …on my way …5 min   contiguous 1, missing []
sync: Lena 2 [stored at 2]
   1:where are you? 2:hello? …on my way …5 min   contiguous 2, missing []
ack c1 [stored at 3]
   1:where are you? 2:hello? 3:on my way …5 min   contiguous 3, missing []
echo c1 [duplicate of 3, ignored]
   1:where are you? 2:hello? 3:on my way …5 min   contiguous 3, missing []
socket: Lena 5 [stored at 5]
   1:where are you? 2:hello? 3:on my way 5:ok! …5 min   contiguous 3, missing [4]
ack c2 [stored at 4]
   1:where are you? 2:hello? 3:on my way 4:5 min 5:ok!   contiguous 5, missing []
```

What the trace shows, and what you'd say about it:

- **Pending messages stay at the bottom** while Lena's messages from before the reconnect slot in above them. That's honest: the server hadn't accepted them yet, so they really come after whatever it had.
- **The echo is ignored** because sequence 3 already holds a message with the same client ID. A different client ID at an existing sequence would be a server bug; the model flags it instead of overwriting.
- **The gap at 4** is visible the moment 5 arrives. Here it fills itself (our own ack for "5 min"); if it doesn't within a moment, the client asks for `after=3`. The read marker sent to the server stays at `contiguousUpTo`, never past a gap.
- **Order is by sequence, not by time.** "5 min" was written before Lena's "ok!" but accepted after; everyone sees 4 before 5.
- In the app, the timeline lives in the local store (pending messages included), so a message written offline survives the app being terminated, and the outbox sends pending messages in order: message `c2` doesn't go before `c1` is acknowledged, or the server would number them the other way round.

### Failure modes, metrics, trade-offs

- **Socket drops:** reconnect with backoff and jitter; on reconnect, sync from `contiguousUpTo`, then resend pending messages in order.
- **App terminated with pending messages:** they're in the store and the outbox; on next launch they send. A background `URLSession` upload isn't needed for small text.
- **Send fails permanently** (blocked by the recipient, conversation deleted): mark the message "Not delivered" with a reason; never retry silently forever.
- **Privacy:** message text never goes into logs, analytics or crash breadcrumbs; notification previews follow the person's settings.
- **Metrics:** send-to-acknowledged latency (p50, p90), messages pending at launch, gap fetches per session, reconnects per hour, delivery failures by reason.
- **Trade-offs:** sending in strict order means one stuck message holds the rest; that's the price of a single agreed order, and it's why a permanent failure must leave the queue. A socket costs a connection per active user on the backend; for a support chat with a few messages an hour, HTTPS plus pushes might be enough.

## Case 3: live order tracking

**Prompt:** "Design the order-tracking screen of a food delivery app: the order's status, an estimated arrival time, and the courier on a map once the food is picked up."

### Requirements and scope

| Functional | Non-functional |
| --- | --- |
| See the order's current status and ETA | Status changes appear within a few seconds while the screen is open |
| See the courier's position after pickup | The status never goes backward on screen |
| Get notified of key changes when the app isn't open | Stale data is labeled as stale, never shown as live |
| | Location of the courier is shown only during the delivery; the customer's own location isn't tracked |
| | Works with VoiceOver: status changes are announced |

**Out:** ordering, payment, the courier's app, dispatch. **Assume:** a delivery lasts 20 to 60 minutes; the courier app reports location every few seconds while moving.

### Channels, and why there are several

- **While the screen is open:** a WebSocket or server-sent events stream for status, ETA and location. Polling every 10 to 15 seconds is a reasonable fallback if the backend doesn't have a stream; at a few requests a minute for under an hour, the cost is acceptable. Say which and why.
- **When the app isn't open:** alert pushes for the changes a person cares about (accepted, picked up, arriving, delivered). A Live Activity on the Lock Screen, updated with ActivityKit push notifications, can show status and ETA without opening the app (Module 44 covers Live Activities).
- **On open:** `GET /v1/orders/{id}` for the full current state.

Because updates arrive on three paths, they arrive **out of order and duplicated**: a push that was delayed, a poll response that crossed a socket message. The server includes a **version** in every update, and the client applies only newer ones.

### Deep dive: a versioned reducer with an injected clock

```swift
enum Status: Int, Comparable {
    case placed, accepted, preparing, pickedUp, delivered, cancelled

    static func < (lhs: Status, rhs: Status) -> Bool { lhs.rawValue < rhs.rawValue }
    var isFinal: Bool { self == .delivered || self == .cancelled }
}

struct Update {
    let version: Int
    let status: Status
    let etaMinutes: Int?
    let via: String
}

final class TestClock {
    var now = 0                     // seconds
}

struct TrackingState {
    private(set) var version = 0
    private(set) var status = Status.placed
    private(set) var etaMinutes: Int?
    private(set) var locationAt: Int?

    mutating func apply(_ update: Update) -> String {
        if status.isFinal { return "ignored (order is \(status))" }
        guard update.version > version else { return "ignored (v\(update.version) ≤ v\(version))" }
        version = update.version
        status = update.status
        etaMinutes = update.etaMinutes
        return "applied"
    }

    mutating func courierMoved(at time: Int) {
        if status == .pickedUp { locationAt = time }
    }

    func describe(now: Int) -> String {
        var text = "v\(version) \(status)"
        if let etaMinutes, !status.isFinal { text += ", ETA \(etaMinutes) min" }
        if status == .pickedUp, let locationAt {
            let age = now - locationAt
            text += age > 60 ? ", courier location \(age / 60) min old" : ", courier live"
        }
        return text
    }
}

let clock = TestClock()
var order = TrackingState()
enum Event {
    case update(Update)
    case courierLocation
}

let events: [(Int, Event)] = [
    (0, .update(Update(version: 1, status: .accepted, etaMinutes: 35, via: "socket"))),
    (5, .update(Update(version: 3, status: .pickedUp, etaMinutes: 18, via: "socket"))),
    (6, .update(Update(version: 2, status: .preparing, etaMinutes: 30, via: "delayed push"))),
    (8, .courierLocation),
    (10, .update(Update(version: 3, status: .pickedUp, etaMinutes: 18, via: "poll"))),
    (400, .update(Update(version: 4, status: .pickedUp, etaMinutes: 9, via: "poll"))),
    (900, .update(Update(version: 6, status: .delivered, etaMinutes: nil, via: "push"))),
    (905, .update(Update(version: 5, status: .pickedUp, etaMinutes: 2, via: "socket"))),
]

for (time, event) in events {
    clock.now = time
    switch event {
    case .courierLocation:
        order.courierMoved(at: time)
        print("t=\(time) courier location → \(order.describe(now: clock.now))")
    case .update(let update):
        let result = order.apply(update)
        print("t=\(time) \(update.via) v\(update.version): \(result) → \(order.describe(now: clock.now))")
    }
}
```

```output
t=0 socket v1: applied → v1 accepted, ETA 35 min
t=5 socket v3: applied → v3 pickedUp, ETA 18 min
t=6 delayed push v2: ignored (v2 ≤ v3) → v3 pickedUp, ETA 18 min
t=8 courier location → v3 pickedUp, ETA 18 min, courier live
t=10 poll v3: ignored (v3 ≤ v3) → v3 pickedUp, ETA 18 min, courier live
t=400 poll v4: applied → v4 pickedUp, ETA 9 min, courier location 6 min old
t=900 push v6: applied → v6 delivered
t=905 socket v5: ignored (order is delivered) → v6 delivered
```

- **The delayed push (v2) can't move the status back** to "preparing". Comparing versions, not channels or arrival times, is what keeps the screen monotonic.
- **The poll repeating v3 is a no-op.** Duplicates are normal with several channels.
- **Location only counts after pickup.** `courierMoved(at:)` ignores samples in any other status, so a stray location message can't put a map on a screen for an order that's still being prepared.
- **At t=400 the last location is from t=8**: 392 seconds old, shown as "6 min old" instead of a dot that pretends to be live. The clock is injected, so this case is one line in a test rather than a six-minute wait.
- **Final states absorb everything.** After "delivered", a late socket message for v5 changes nothing.
- **VoiceOver:** when `status` changes, post an announcement ("Your order was picked up"), not on every ETA tick.

### Failure modes, metrics, trade-offs

- **Stream drops:** fall back to polling until it reconnects; show the last update's age if it's more than a minute old.
- **Push disabled:** the Live Activity and the screen still update when the app runs; the design never depends on alerts for correctness.
- **ETA jumps:** smooth what's displayed (don't jump from 18 to 9 and back); the server's value is still the truth.
- **Privacy:** the courier's location is shown only between pickup and delivery and isn't stored on the device after the order ends; the customer's location isn't collected by this screen.
- **Metrics:** delay from server status change to screen (per channel), share of time the screen shows stale data, stream reconnects, Live Activity update failures.
- **Trade-offs:** a stream is the best experience but costs backend connections for every open screen; polling is simpler and adequate for a few updates per minute. Live Activities give glanceable status, but their updates have system budgets, so send the ones that matter, not every location fix.

## Common mistakes

> [!error] A generic design with the product's name on it
> If the same boxes would fit any prompt, the requirements didn't drive anything. Each case above has one or two decisions that only make sense for its product.

> [!error] Ordering by device time
> Chat and status updates arrive out of order. Order by server sequence numbers and versions.

> [!error] Trusting the channel
> "The push said preparing" isn't a reason to show preparing. Every update carries a version; apply only newer ones.

> [!error] Hiding staleness
> An old courier location shown as live is worse than no location. Compute the age and say it.

> [!error] No numbers for a media design
> A photo feed without data and memory estimates can't justify its cache sizes or image variants.

## Exercises

````exercise
id: m48-l06-e1
type: prediction
prompt: "A smaller chat timeline. Pending messages show with … and confirmed ones with their sequence number. What does it print?"
code: |
  struct Chat {
      var confirmed: [Int: String] = [:]     // seq → clientID
      var pending: [String] = []

      mutating func receive(_ seq: Int, _ clientID: String) {
          if confirmed[seq] != nil { return }
          pending.removeAll { $0 == clientID }
          confirmed[seq] = clientID
      }

      func render() -> String {
          (confirmed.keys.sorted().map { "\($0):\(confirmed[$0]!)" } + pending.map { "…\($0)" })
              .joined(separator: " ")
      }
  }

  var chat = Chat(pending: ["m1", "m2", "m3"])
  chat.receive(1, "x1")
  chat.receive(2, "m1")
  print(chat.render())
  chat.receive(2, "m1")
  chat.receive(4, "m3")
  print(chat.render())
  chat.receive(3, "m2")
  print(chat.render())
output: |
  1:x1 2:m1 …m2 …m3
  1:x1 2:m1 4:m3 …m2
  1:x1 2:m1 3:m2 4:m3
hints:
  - "The second chat.receive(2, \"m1\") finds sequence 2 already filled and returns."
  - "When m3 is confirmed at 4, it leaves pending, so only m2 is still shown with …"
solution: |
  ```output
  1:x1 2:m1 …m2 …m3
  1:x1 2:m1 4:m3 …m2
  1:x1 2:m1 3:m2 4:m3
  ```

  The duplicate acknowledgment for m1 is ignored. m3 confirmed at 4 before m2 was confirmed, which in a real app means the outbox didn't send in order (or the server reordered); the timeline still shows the server's order, with m2 pending at the bottom until 3 arrives. Lesson takeaway: the outbox should wait for m2's acknowledgment before sending m3, so this state shouldn't occur.
````

````exercise
id: m48-l06-e2
type: solve
prompt: |
  Write `apply(_:to:)` for a parcel-tracking screen. The state has `version` and `status` (a string). Apply an update only if its version is newer and the current status isn't `"delivered"` or `"returned"`. Return `"applied"` or `"ignored"`.

  Expected output:

  ```output
  applied v1 inTransit
  applied v3 outForDelivery
  ignored v3 outForDelivery
  applied v5 delivered
  ignored v5 delivered
  ```
starter: |
  struct ParcelState {
      var version = 0
      var status = "created"
  }

  func apply(_ update: (version: Int, status: String), to state: inout ParcelState) -> String {
      // your code
      return ""
  }

  var state = ParcelState()
  for update in [(1, "inTransit"), (3, "outForDelivery"), (2, "inTransit"), (5, "delivered"), (6, "returned")] {
      let result = apply((version: update.0, status: update.1), to: &state)
      print(result, "v\(state.version)", state.status)
  }
hints:
  - "Check the final states first, then compare versions."
rubric:
  - Ignores updates once the state is final.
  - Ignores versions that aren't newer.
  - Applies both fields together otherwise.
solution: |
  ```swift
  struct ParcelState {
      var version = 0
      var status = "created"
  }

  func apply(_ update: (version: Int, status: String), to state: inout ParcelState) -> String {
      guard !["delivered", "returned"].contains(state.status), update.version > state.version else {
          return "ignored"
      }
      state.version = update.version
      state.status = update.status
      return "applied"
  }

  var state = ParcelState()
  for update in [(1, "inTransit"), (3, "outForDelivery"), (2, "inTransit"), (5, "delivered"), (6, "returned")] {
      let result = apply((version: update.0, status: update.1), to: &state)
      print(result, "v\(state.version)", state.status)
  }
  ```

  ```output
  applied v1 inTransit
  applied v3 outForDelivery
  ignored v3 outForDelivery
  applied v5 delivered
  ignored v5 delivered
  ```

  Version 2 is older than 3 and is ignored, so the parcel never appears to go back in transit. Version 6 ("returned") is newer, but the parcel was already delivered, and the final state absorbs it. Whether "delivered then returned" can really happen is a question for the product team; if it can, "delivered" isn't final, and the rule changes. Say that out loud in an interview.
````

````exercise
id: m48-l06-e3
type: comprehension
prompt: "In the photo feed, why does each photo in the payload carry an aspect ratio and a placeholder color?"
choices:
  - text: "So the cell can be sized and painted before the image loads, avoiding layout jumps and blank boxes while scrolling."
    correct: true
    why: "Self-sizing cells that change height when the image arrives make the list jump under the person's finger."
  - text: "So the client can compute the JPEG's file size."
    correct: false
    why: "Neither tells you the file size; the variants' widths and the network do."
  - text: "Because UIKit can't display images without a known aspect ratio."
    correct: false
    why: "It can; the problem is the layout changing after the image loads."
  - text: "To let the server skip sending alt text."
    correct: false
    why: "Alt text is separate and still required for accessibility."
solution: |
  Known geometry before the bytes arrive is a scrolling-performance decision as much as a visual one. With the aspect ratio, the collection view computes every cell's height up front; with a placeholder color, there's something meaningful to show for the few hundred milliseconds before the image decodes.
````

````exercise
id: m48-l06-e4
type: find-errors
prompt: "A candidate's chat design. Mark every real problem."
code: |
  - Messages are ordered by the sender's device timestamp.
  - A message gets its ID from the server when it's accepted; until then it has none.
  - While offline, sending is disabled.
  - The client marks "read up to" the highest sequence it has received.
  - Message text is logged at the info level to debug delivery problems.
choices:
  - text: "Device timestamps give different orders on different devices and break with skewed clocks."
    correct: true
  - text: "Without a client-generated ID, a retried send can't be deduplicated and the echo can't be matched to the pending message."
    correct: true
  - text: "Disabling sending offline breaks the main non-functional requirement; queue messages instead."
    correct: true
  - text: "Marking read past a gap claims the person read messages they never received."
    correct: true
  - text: "Logging message text exposes private content in logs."
    correct: true
  - text: "Using sequence numbers per conversation instead of globally is a mistake."
    correct: false
    why: "Per-conversation sequences are what you want: order and gaps only matter within a conversation."
rubric:
  - I flagged ordering by device time.
  - I flagged the missing client ID.
  - I flagged disabled offline sending.
  - I flagged the read marker past gaps.
  - I flagged logging content.
solution: |
  All but the last choice are real problems. The fixes are this lesson's chat design: order by the server's per-conversation sequence; generate a client ID when the message is written; queue offline messages in the store and outbox; send `upTo: contiguousUpTo`; log IDs and outcomes, never content.
````

````exercise
id: m48-l06-e5
type: explain
prompt: "In the order-tracking trace, explain why the delayed push at t=6 is ignored and what would go wrong if the client applied updates in arrival order instead."
code: |
  t=5 socket v3: applied → v3 pickedUp, ETA 18 min
  t=6 delayed push v2: ignored (v2 ≤ v3) → v3 pickedUp, ETA 18 min
rubric:
  - Explains that the version, not the arrival time or channel, decides freshness.
  - Describes the visible regression (status back to preparing, map disappearing, ETA jumping up).
  - Mentions that pushes can be delayed and channels race.
solution: |
  The push carries version 2, older than the version 3 already applied from the socket, so it describes an earlier state of the order. Pushes can be delayed, and three channels race each other, so arrival order says nothing about which update is newer. Applying it would move the status back to "preparing", hide the courier's map and raise the ETA from 18 to 30 minutes, and the next socket or poll message would flip it all back: a screen that flickers between states and that nobody trusts.
````

````exercise
id: m48-l06-e6
type: design
prompt: "Design a shared family calendar app end to end in the five-phase structure: events with title, time, location and attendees; everyone in the family can edit; works offline; reminders. Include an estimate, the API with pagination or sync, the layers, a deep dive on concurrent edits, failure modes, metrics and trade-offs."
rubric:
  - Requirements separate actions from qualities, including offline edits, reminders when the app isn't running, privacy of family data and accessibility.
  - An estimate that drives a decision (for example, years of events fit in a few MB, so sync everything rather than paging).
  - A delta sync with change tokens and tombstones, idempotent writes with client IDs.
  - A conflict strategy per field (field-level merge with a rule for time changes; deletes win or not, stated).
  - Local notifications scheduled from the synced data and rescheduled after sync.
  - Failure modes, metrics and trade-offs named.
solution: |
  - **Requirements.** Functional: see a month and a day, add and edit events, invite family members, get reminders. Non-functional: full offline use with edits syncing later; reminders fire without the app running; edits by two people don't silently overwrite each other; family data never in analytics; VoiceOver and large text in the month view.
  - **Estimate.** A family creates maybe 20 events a week; 10 years is about 10,000 events at roughly 500 bytes each, about 5 MB. So the client syncs the whole calendar, no paging by date; that simplifies offline completely.
  - **API.** `GET /v1/calendars/{id}/changes?since=<token>` with tombstones; `PUT /v1/events/{clientID}` with the base version for writes; the error envelope from lesson 2.
  - **Layers.** Views → screen models → repository → local store (source of truth) with outbox → sync engine; a reminder scheduler that reads the store.
  - **Deep dive: concurrent edits.** Field-level three-way merge: title and location merge independently; if both people changed the time, keep the server's and show the other as a notice ("Dad also moved this to 18:00"). A deletion wins over edits, because resurrecting a cancelled event is worse than losing an edit to it.
  - **Reminders.** Local notifications scheduled from the store after every sync, so they fire offline; the scheduler reconciles its pending requests with stable identifiers per event (Module 44) and schedules only the next few weeks, nearest first, rather than every future event.
  - **Failure modes.** Offline: everything works, edits queue. Token too old: full resync. Permanent write failure: show it on the event.
  - **Metrics.** Sync lag, conflicts per week by field, outbox depth at launch, reminder scheduling errors.
  - **Trade-offs.** Full sync is simple and fits the data size; it wouldn't for a company calendar with thousands of people. Field merge needs base versions stored with each pending edit.
````

## Summary

- Each case follows the same five phases, but the requirements make the decisions different: estimates drive the photo feed, ordering and exactly-once delivery drive chat, and out-of-order updates drive order tracking.
- Photo feed: image variants, aspect ratio and placeholder in the payload; prefetch first photos only; cache budgets from the arithmetic; optimistic, coalesced, idempotent likes.
- Chat: client IDs for idempotency and echo matching, server sequence numbers for order and gap detection, pending messages at the bottom, in-order sending from a persistent outbox, read markers that never pass a gap.
- Order tracking: several channels for freshness and reach, a version on every update, a reducer that only moves forward and treats final states as final, and staleness computed with an injected clock and shown to the person.
- Close every design with its failure modes, the metrics that would tell you it works, and the trade-offs you chose.
