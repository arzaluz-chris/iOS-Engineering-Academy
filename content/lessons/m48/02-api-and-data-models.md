---
id: m48-l02
title: Client-server API and data models
description: "In a design interview the API is the contract your whole client is built on, so you design it from the screens backward. You compare REST, GraphQL and push channels (APNs, WebSockets, server-sent events) at the level an interview needs, write a pagination contract with a stable keyset cursor, plan for old app versions that live for years, keep transport, domain and view models apart with explicit mapping, and design an error model the client can act on. Decoding, cursor and error-mapping logic is plain Swift, compiled and run."
module: m48
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l01, m30-l05, m30-l02, m32-l04]
objectives:
  - Derive the endpoints a client needs from its screens and their data.
  - Compare REST, GraphQL and push channels (APNs, WebSocket, server-sent events, polling) and choose one per need with a reason.
  - Specify a pagination contract with an opaque cursor, a stable sort key with a tie-breaker, a page-size cap and an end marker.
  - Design for versioning, so app versions released years ago keep working, using additive changes and tolerant decoding.
  - Separate transport (DTO), domain and view models and write the mapping between them.
  - Define an error envelope and map it to actions the UI can take.
terms:
  - term: DTO (data transfer object)
    definition: A type that mirrors the wire format of one endpoint, such as a Decodable struct for a JSON response. It changes when the API changes and should not leak past the networking layer.
  - term: Keyset cursor
    definition: "A cursor that encodes the sort key of the last item returned plus a unique tie-breaker (usually the ID), so the next page means \"items strictly after (key, id)\". It's stable under inserts and handles equal sort keys."
  - term: Tolerant reader
    definition: A client that ignores fields it doesn't know, treats new optional fields as optional, and maps unknown enum values to a fallback instead of failing the whole response.
  - term: Error envelope
    definition: "A consistent JSON body for errors, for example a machine-readable code, a human message, whether retrying can help, and per-field validation errors."
  - term: Push channel
    definition: "Any way for the server to tell the client something changed without being asked: APNs notifications, a WebSocket, server-sent events. Each has different reach (foreground only, or also when the app isn't running) and different guarantees."
mastery:
  - List the endpoints, request parameters and response shapes for a feature from its screens.
  - Justify REST, GraphQL or a push channel for a given requirement, including what each costs.
  - Write a pagination contract and explain why a timestamp-only cursor loses items.
  - Decode a response that gained fields and enum cases without failing.
  - Map an HTTP status and error body to one of a small set of UI actions.
resources: [graphql-spec, rfc-9110, foundation-jsondecoder, foundation-encoding-custom-types, swift-decodingerror, foundation-urlsession, foundation-httpurlresponse]
cards:
  - id: m48-l02-c1
    front: Why is a cursor of only the last item's timestamp unsafe?
    back: "Items with the same timestamp straddle the page boundary: \"strictly older than T\" skips the ones not yet returned, and \"older or equal\" repeats the ones already returned. Use a keyset (timestamp, id) and compare both."
  - id: m48-l02-c2
    front: Where can a WebSocket deliver messages, and what covers the rest?
    back: "Only while the app is running and holding the connection, in practice the foreground. When the app is suspended or not running, APNs notifications (alert or background) carry the signal, and the app syncs when it next runs."
  - id: m48-l02-c3
    front: What does Apple say about background (silent) push frequency?
    back: "They're low priority and delivery isn't guaranteed; the system may throttle them. \"Don't try to send more than two or three per hour.\" Send them with apns-push-type background and apns-priority 5."
  - id: m48-l02-c4
    front: Name three rules that let old app versions survive API changes.
    back: "Only additive changes within a version (new optional fields, new endpoints); clients ignore unknown fields and map unknown enum values to a fallback; breaking changes get a new version and the old one stays up as long as those apps are in use."
  - id: m48-l02-c5
    front: What belongs in an error envelope?
    back: "A stable machine-readable code, a message for logs or display, whether retrying can help, and per-field validation errors. The client maps it to a small set of actions: retry, re-authenticate, fix input, upgrade, or show a message."
---

## The idea in one sentence

**The API is the contract the whole client is built on**, so you derive it from what each screen needs, make it safe to page through and to evolve, and give errors a shape the app can act on.

> [!note] What was checked
> The behavior of `JSONDecoder` (ignoring unknown keys, failing on an unexpected enum value) is shown by the compiled examples below, run with Swift 6.3 on Linux and macOS. Background-push guidance is quoted from Apple's "Pushing background updates to your App" and `URLSessionWebSocketTask` reference pages, read in November 2026. Statements about GraphQL describe the general approach; they weren't checked against any particular server.

## From screens to endpoints

In an interview, list the screens, then the data each one needs, then the calls that provide it. For Mise:

| Screen | Needs | Call |
| --- | --- | --- |
| Feed | A page of recipe summaries: title, thumbnail, time, difficulty, alt text | `GET /v1/feed?cursor=…&limit=20` |
| Recipe | Ingredients, steps, full photo, saved state | `GET /v1/recipes/{id}` |
| Save | Toggle saved | `PUT /v1/me/saved/{recipeID}` and `DELETE` (both idempotent) |
| Shopping list | Items, and changes since the last sync | `GET /v1/lists/{id}/changes?since=…`, `POST /v1/lists/{id}/ops` |

Two things to say out loud:

- **Summaries are not details.** The feed returns small summaries; the full recipe comes from the detail call. A feed that ships every step of every recipe wastes data on recipes nobody opens.
- **Writes are idempotent where possible.** "Save" as `PUT /me/saved/{id}` can be retried after a timeout without creating duplicates; `POST /me/saved` with a body can't, unless it carries an idempotency key. Module 43 covered why this matters on real networks.

## REST, GraphQL and push channels

You don't need to argue protocol theory, just to pick one per need and say what it costs.

| | Good for | Costs |
| --- | --- | --- |
| **REST** (resources and HTTP methods) | Most apps; works with HTTP caching, CDNs and per-endpoint monitoring | Screens that need data from several resources make several calls, or the backend adds screen-shaped endpoints |
| **GraphQL** (one endpoint, the client names the fields it wants) | Many screens with different needs from the same graph of data; avoiding over-fetching | Usually sent as POST to one URL, so URL-based HTTP caching doesn't apply without extra work (persisted queries); a client library and schema tooling; cost control for expensive queries moves to the server |
| **APNs alert** | Telling a person something when the app isn't running | Not a data channel; the payload is small; the person may have notifications off |
| **APNs background** (`content-available: 1`) | A hint to refresh when content changes irregularly | Low priority and not guaranteed; throttled |
| **WebSocket** (`URLSessionWebSocketTask`) | Two-way, low-latency traffic while the app is open: chat, live collaboration | Only while the app runs and holds the connection; reconnects, heartbeats and resync after a gap are your job |
| **Server-sent events** | A one-way stream from server to client over HTTP | No dedicated Foundation type; you read the response's lines yourself; same foreground-only limits |
| **Polling** | Rarely changing data; a fallback | Wasted requests and battery when nothing changed |

Apple is explicit about background pushes: "the system doesn't guarantee their delivery. In addition, the system may throttle the delivery of background notifications if the total number becomes excessive. The number of background notifications allowed by the system depends on current conditions, but don't try to send more than two or three per hour." They're sent with an `aps` dictionary containing only `content-available`, the `apns-push-type` header set to `background` and `apns-priority` set to `5`. So a background push can say "the shopping list changed", but it can't be the only way the list stays fresh.

For Mise: **REST** for everything, an **alert push** when someone in the household adds to the shared list, a **background push** as a refresh hint, and a **foreground refresh** (on launch and when the list screen appears) as the guarantee. No WebSocket: a minute of latency is fine for a shopping list. Chat in lesson 6 is where a socket earns its cost.

## A pagination contract

Module 30 showed why cursors beat offsets when items are inserted while someone scrolls. In a design interview, write the contract itself:

```text
GET /v1/feed?cursor=<opaque>&limit=20

200 OK
{
  "items": [ …recipe summaries… ],
  "nextCursor": "eyJ0IjoxNzAw…"      // null when there are no more items
}

Rules
- Order: publishedAt descending, then id descending (a total order).
- The cursor is opaque: the client stores it and sends it back, never builds it.
- limit is capped by the server (say 50); the client must accept fewer items.
- A page can be empty with a non-null nextCursor (filtered items); keep going.
- Cursors may expire; on 400 "cursor_expired", restart from the top.
```

The order line is the one people get wrong. Sorting by `publishedAt` alone isn't a total order, because two recipes can share a timestamp. If the cursor carries only the last timestamp, the server can't tell where inside a group of equal timestamps the previous page stopped:

```swift
struct Recipe {
    let id: Int
    let publishedAt: Int        // minutes since some epoch
}

// Newest first. Recipes 6, 5 and 4 share a timestamp.
let feed = [
    Recipe(id: 7, publishedAt: 500), Recipe(id: 6, publishedAt: 400),
    Recipe(id: 5, publishedAt: 400), Recipe(id: 4, publishedAt: 400),
    Recipe(id: 3, publishedAt: 300), Recipe(id: 2, publishedAt: 200),
    Recipe(id: 1, publishedAt: 100),
]

/// Cursor = last timestamp only: "strictly older than".
func pageByTimestamp(after timestamp: Int?, limit: Int) -> [Recipe] {
    let rest = feed.filter { timestamp == nil || $0.publishedAt < timestamp! }
    return Array(rest.prefix(limit))
}

/// Keyset cursor = (timestamp, id) of the last item.
struct Cursor {
    let publishedAt: Int
    let id: Int
}

func pageByKeyset(after cursor: Cursor?, limit: Int) -> [Recipe] {
    let rest = feed.filter { recipe in
        guard let cursor else { return true }
        return recipe.publishedAt < cursor.publishedAt
            || (recipe.publishedAt == cursor.publishedAt && recipe.id < cursor.id)
    }
    return Array(rest.prefix(limit))
}

func ids(_ recipes: [Recipe]) -> [Int] { recipes.map(\.id) }

let first = pageByKeyset(after: nil, limit: 3)
print("page 1:", ids(first))

let byTimestamp = pageByTimestamp(after: first.last!.publishedAt, limit: 3)
print("page 2, timestamp cursor:", ids(byTimestamp))

var cursor = Cursor(publishedAt: first.last!.publishedAt, id: first.last!.id)
let second = pageByKeyset(after: cursor, limit: 3)
print("page 2, keyset cursor:", ids(second))

cursor = Cursor(publishedAt: second.last!.publishedAt, id: second.last!.id)
print("page 3, keyset cursor:", ids(pageByKeyset(after: cursor, limit: 3)))
```

```output
page 1: [7, 6, 5]
page 2, timestamp cursor: [3, 2, 1]
page 2, keyset cursor: [4, 3, 2]
page 3, keyset cursor: [1]
```

Recipe 4 disappears with the timestamp cursor: it shares 400 with recipe 5, and "strictly older than 400" skips it. Switching to "older or equal" would repeat 6 and 5 instead. The keyset compares the timestamp first and the ID only to break ties, which is the same order the feed is sorted in. On the server this is an indexed range query; on the client, you only ever see the opaque string.

> [!tip] Refresh is a different question from "next page"
> Paging goes backward in time. Pull to refresh asks "anything newer than what I have?" Ask the backend for both directions, or for a change feed (`?since=<token>`) that also reports edits and deletions. Lesson 4 merges the two on the client.

## Versioning: the app you shipped two years ago is still calling

A web page updates when you deploy. An iOS app updates when each person installs the update, and some never do. Any API change has to keep every version still in use working. The rules that make that possible:

- **Within a version, only add.** New optional fields, new endpoints, new enum values the old client can survive. Never rename, remove, or change the type or meaning of a field.
- **The client is a tolerant reader.** Ignore unknown fields, treat fields that may be missing as optional, and map unknown enum values to a fallback.
- **Breaking changes get a new version** (`/v2/…` or a version header), and the old one stays up as long as its apps have meaningful use. The server can tell, because every request carries the app version in a header.
- **A minimum supported version** comes from remote configuration, so the server can ask very old apps to update instead of letting them fail in confusing ways.

`JSONDecoder` already ignores keys your type doesn't declare. Enums are where tolerance needs code: a `String` raw-value enum fails the whole decode when the server sends a value it doesn't know. Here a newer server added `"expert"` and a `videoURL` field:

```swift
import Foundation

enum Difficulty: Equatable {
    case easy, medium, hard
    case unknown(String)                     // a value this app version doesn't know
}

extension Difficulty: Decodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "easy": self = .easy
        case "medium": self = .medium
        case "hard": self = .hard
        default: self = .unknown(raw)
        }
    }
}

enum StrictDifficulty: String, Decodable {
    case easy, medium, hard
}

struct RecipeSummaryDTO: Decodable {
    let id: String
    let title: String
    let minutes: Int
    let difficulty: Difficulty
    let photoAltText: String?               // added later: optional, so old payloads decode
}

struct StrictSummaryDTO: Decodable {
    let id: String
    let difficulty: StrictDifficulty
}

let fromOldServer = Data("""
{"id": "r1", "title": "Shakshuka", "minutes": 25, "difficulty": "easy"}
""".utf8)

let fromNewServer = Data("""
{"id": "r2", "title": "Croissants", "minutes": 240, "difficulty": "expert",
 "photoAltText": "Six croissants on a tray", "videoURL": "https://example.com/v.mp4"}
""".utf8)

let decoder = JSONDecoder()
for data in [fromOldServer, fromNewServer] {
    let recipe = try decoder.decode(RecipeSummaryDTO.self, from: data)
    print(recipe.id, recipe.difficulty, recipe.photoAltText ?? "no alt text")
}

do {
    _ = try decoder.decode(StrictSummaryDTO.self, from: fromNewServer)
    print("strict: decoded")
} catch is DecodingError {
    print("strict: the whole response failed")
}
```

```output
r1 easy no alt text
r2 unknown("expert") Six croissants on a tray
strict: the whole response failed
```

- **`videoURL` is ignored** without any code: the type doesn't declare it.
- **`photoAltText` is optional**, so the older payload decodes. If it were `String`, every response from a server that predates the field would fail.
- **`"expert"` becomes `.unknown("expert")`.** The strict enum fails the entire response, which in a feed means one new value on one recipe empties the screen for everyone on that app version.
- The UI decides what `.unknown` shows (here, probably no difficulty badge). That's a product decision, so say it in the interview.

## Three kinds of model, and the mapping between them

A recipe exists in several shapes in the app, each owned by a different layer:

| Model | Owned by | Changes when | Example |
| --- | --- | --- | --- |
| **DTO** | Networking | The API changes | `RecipeSummaryDTO`, mirrors the JSON |
| **Domain** | The app's core | The product's meaning changes | `Recipe` with a `Duration`-like value, a difficulty enum, validated fields |
| **Persistence entity** | The local store | The schema migrates | A SwiftData `@Model` or Core Data entity |
| **View state** | One screen | The design changes | `RecipeRow` with display strings |

Mapping is where you **validate and decide**. A DTO with an empty title shouldn't become a `Recipe`; it's dropped and counted, so one bad record doesn't break a page. Formatting belongs to the view state, not to the DTO.

```swift
import Foundation

struct RecipeSummaryDTO {
    let id: String
    let title: String
    let minutes: Int
    let difficulty: String
}

enum Difficulty {
    case easy, medium, hard, unspecified
}

struct Recipe {                 // domain: validated, app vocabulary
    let id: String
    let title: String
    let minutes: Int
    let difficulty: Difficulty
}

struct RecipeRow {              // view state: what one cell displays
    let title: String
    let detail: String
}

enum Mapping {
    static func recipe(from dto: RecipeSummaryDTO) -> Recipe? {
        let title = dto.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, dto.minutes > 0 else { return nil }
        let difficulty: Difficulty = switch dto.difficulty {
        case "easy": .easy
        case "medium": .medium
        case "hard": .hard
        default: .unspecified
        }
        return Recipe(id: dto.id, title: title, minutes: dto.minutes, difficulty: difficulty)
    }

    static func row(from recipe: Recipe) -> RecipeRow {
        let time = recipe.minutes < 60
            ? "\(recipe.minutes) min"
            : "\(recipe.minutes / 60) h \(recipe.minutes % 60) min"
        let level: String? = switch recipe.difficulty {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .unspecified: nil
        }
        return RecipeRow(title: recipe.title, detail: [level, time].compactMap { $0 }.joined(separator: " · "))
    }
}

let page = [
    RecipeSummaryDTO(id: "r1", title: "Shakshuka", minutes: 25, difficulty: "easy"),
    RecipeSummaryDTO(id: "r2", title: "  ", minutes: 10, difficulty: "easy"),
    RecipeSummaryDTO(id: "r3", title: "Croissants", minutes: 240, difficulty: "expert"),
    RecipeSummaryDTO(id: "r4", title: "Dal", minutes: 0, difficulty: "medium"),
]

let recipes = page.compactMap(Mapping.recipe(from:))
print("kept \(recipes.count) of \(page.count)")
for row in recipes.map(Mapping.row(from:)) {
    print("\(row.title): \(row.detail)")
}
```

```output
kept 2 of 4
Shakshuka: Easy · 25 min
Croissants: 4 h 0 min
```

- **Two of four DTOs are dropped**: an all-whitespace title and a zero-minute recipe. In the app you'd log the IDs (no content) and count them, so the backend team hears about bad data.
- **`"expert"` maps to `.unspecified`**, and the row shows only the time. The mapping, not the view, decides this.
- **Formatting lives in `row(from:)`.** The domain keeps minutes as an integer; the persistence layer stores the same; only the screen turns it into "4 h 0 min" (with `Duration.formatted` or a formatter in the real app, so it's localized).

## An error model the client can act on

"Something went wrong" happens when the client can't tell errors apart. Agree with the backend on one envelope for every error response:

```text
{
  "code": "validation_failed",        // stable, machine-readable
  "message": "Quantity must be positive.",
  "retryable": false,
  "fields": { "quantity": "must be positive" }
}
```

Then map status, envelope and headers to a small set of things the app can actually do:

```swift
import Foundation

struct ErrorEnvelope: Decodable {
    let code: String
    let message: String
    let retryable: Bool?
    let fields: [String: String]?
}

enum AppError: Equatable {
    case reauthenticate
    case fixInput([String])
    case retryLater(seconds: Int)
    case upgradeApp
    case retry
    case showMessage(String)
}

func mapError(status: Int, body: Data, retryAfter: String?) -> AppError {
    let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: body)
    if envelope?.code == "app_version_unsupported" { return .upgradeApp }
    switch status {
    case 401:
        return .reauthenticate
    case 422, 400 where envelope?.fields != nil:
        return .fixInput((envelope?.fields ?? [:]).keys.sorted())
    case 429, 503:
        return .retryLater(seconds: retryAfter.flatMap(Int.init) ?? 30)
    case 500...599:
        return envelope?.retryable == false ? .showMessage(envelope!.message) : .retry
    default:
        return .showMessage(envelope?.message ?? "Unexpected response (\(status)).")
    }
}

let cases: [(Int, String, String?)] = [
    (401, #"{"code":"token_expired","message":"Sign in again."}"#, nil),
    (422, #"{"code":"validation_failed","message":"Check the item.","fields":{"quantity":"must be positive","name":"required"}}"#, nil),
    (429, #"{"code":"rate_limited","message":"Slow down."}"#, "12"),
    (503, "<html>Service Unavailable</html>", nil),
    (500, #"{"code":"list_corrupt","message":"This list is damaged.","retryable":false}"#, nil),
    (403, #"{"code":"app_version_unsupported","message":"Please update."}"#, nil),
    (404, #"{"code":"not_found","message":"This recipe was removed."}"#, nil),
]

for (status, body, retryAfter) in cases {
    print(status, mapError(status: status, body: Data(body.utf8), retryAfter: retryAfter))
}
```

```output
401 reauthenticate
422 fixInput(["name", "quantity"])
429 retryLater(seconds: 12)
503 retryLater(seconds: 30)
500 showMessage("This list is damaged.")
403 upgradeApp
404 showMessage("This recipe was removed.")
```

- **The envelope is optional.** A proxy or load balancer can answer with HTML (the 503 here). The mapping uses `try?` and still works from the status alone.
- **`Retry-After` is honored** when it's a number of seconds; HTTP also allows a date there (RFC 9110), which this sketch doesn't parse and treats as the 30-second default.
- **`app_version_unsupported` wins over the status.** The code is the contract; status codes are a coarse hint.
- **Field names are sorted** before they're stored, because a dictionary's order isn't stable, and the UI wants a predictable order anyway.
- **The cases are few on purpose.** Each one is something the UI does differently: show sign-in, highlight fields, wait, show an update screen, retry, or show the message.

## Common mistakes

> [!error] One giant feed response
> Returning every recipe's full content in the feed wastes data and slows the first screen. Summaries in the list, details on demand.

> [!error] A cursor of the last timestamp
> Equal timestamps straddle page boundaries and items vanish or repeat. Use a keyset with a unique tie-breaker, and keep the cursor opaque to the client.

> [!error] Strict enums in DTOs
> A `String` raw-value enum makes one new server value fail the whole response for every installed app version. Decode to a type with an unknown case.

> [!error] DTOs all the way to the view
> When the JSON shape reaches SwiftUI views, every API change touches the UI. Map to domain types at the edge, and format in view state.

> [!error] Background push as the sync mechanism
> Background notifications are low priority, may be throttled and aren't guaranteed. Use them as hints, and refresh on launch and on foreground as the guarantee.

> [!error] Errors as strings
> If the only thing the client gets is a message, it can't decide to re-authenticate, retry or highlight a field. Agree on a code and the retryable flag.

## Exercises

````exercise
id: m48-l02-e1
type: comprehension
prompt: "A collaborative whiteboard app must show other people's strokes within about half a second while the app is open. What's the best primary channel for that?"
choices:
  - text: "A WebSocket while the app is in the foreground, with a resync from the last sequence number after reconnecting."
    correct: true
    why: "Two-way, low latency, and the resync covers gaps after a drop. This is what a socket is for."
  - text: "Background push notifications for every stroke."
    correct: false
    why: "Apple says not to send more than two or three per hour, delivery isn't guaranteed, and they're the wrong tool when the app is already open."
  - text: "Polling every 500 ms."
    correct: false
    why: "Twice a second, mostly empty responses, and the battery cost of keeping the radio busy."
  - text: "GraphQL, because it avoids over-fetching."
    correct: false
    why: "GraphQL is a query style, not a server-to-client channel. It doesn't answer the latency requirement by itself."
solution: |
  A WebSocket (`URLSessionWebSocketTask`) fits low-latency two-way traffic while the app runs. The design work is around it: heartbeats, reconnect with backoff, and a sequence number per board so that after reconnecting the client asks for everything after the last one it saw. When the app isn't running, nobody is drawing in it, so there's nothing to stream; an alert push can say "Ana edited the board" if the product wants that.
````

````exercise
id: m48-l02-e2
type: prediction
prompt: "The same keyset paging over a feed where several items share timestamps. What does it print?"
code: |
  struct Item {
      let id: Int
      let time: Int
  }

  let items = [
      Item(id: 9, time: 50), Item(id: 8, time: 50), Item(id: 7, time: 40),
      Item(id: 6, time: 40), Item(id: 5, time: 40), Item(id: 2, time: 10),
  ]

  func page(after cursor: (time: Int, id: Int)?, limit: Int) -> [Item] {
      let rest = items.filter { item in
          guard let cursor else { return true }
          return item.time < cursor.time || (item.time == cursor.time && item.id < cursor.id)
      }
      return Array(rest.prefix(limit))
  }

  var cursor: (time: Int, id: Int)? = nil
  var pageNumber = 1
  while true {
      let result = page(after: cursor, limit: 2)
      if result.isEmpty { break }
      print(pageNumber, result.map(\.id))
      cursor = (result.last!.time, result.last!.id)
      pageNumber += 1
  }
output: |
  1 [9, 8]
  2 [7, 6]
  3 [5, 2]
hints:
  - "After page 1 the cursor is (50, 8). Which items are strictly after it?"
  - "After page 2 the cursor is (40, 6): item 5 has the same time and a smaller id."
solution: |
  ```output
  1 [9, 8]
  2 [7, 6]
  3 [5, 2]
  ```

  The cursor after page 1 is (50, 8): nothing else has time 50 with a smaller id, so page 2 starts at time 40. After page 2 the cursor is (40, 6); item 5 shares time 40 and has a smaller id, so it comes next, then item 2. A fourth call returns nothing and the loop stops. Every item appears exactly once, even though pages split a group of equal timestamps.
````

````exercise
id: m48-l02-e3
type: fill-in
prompt: "Complete the tolerant enum so an unknown unit from a newer server doesn't fail the response."
code: |
  enum Unit: Equatable {
      case grams, milliliters, pieces
      case [[1]](String)
  }

  extension Unit: Decodable {
      init(from decoder: any Decoder) throws {
          let raw = try decoder.[[2]]().decode(String.self)
          switch raw {
          case "g": self = .grams
          case "ml": self = .milliliters
          case "pc": self = .pieces
          [[3]]: self = .other(raw)
          }
      }
  }
blanks:
  - id: "1"
    answers: ["other"]
  - id: "2"
    answers: ["singleValueContainer"]
  - id: "3"
    answers: ["default"]
solution: |
  ```swift
  import Foundation

  enum Unit: Equatable {
      case grams, milliliters, pieces
      case other(String)
  }

  extension Unit: Decodable {
      init(from decoder: any Decoder) throws {
          let raw = try decoder.singleValueContainer().decode(String.self)
          switch raw {
          case "g": self = .grams
          case "ml": self = .milliliters
          case "pc": self = .pieces
          default: self = .other(raw)
          }
      }
  }

  let units = try JSONDecoder().decode([Unit].self, from: Data(#"["g", "pc", "tbsp"]"#.utf8))
  for unit in units { print(unit) }
  ```

  ```output
  grams
  pieces
  other("tbsp")
  ```

  The value is a bare string, so it's read from a single-value container. Keeping the raw string in `.other` lets the UI show "2 tbsp" as text even though the app has no conversion for it, which is better than dropping the ingredient.
````

````exercise
id: m48-l02-e4
type: find-errors
prompt: "A proposed API for Mise's shopping list. Mark every real problem."
code: |
  GET  /v1/lists/{id}?page=2                → { "items": [...], "total": 312 }
  POST /v1/lists/{id}/items                 → creates an item (no idempotency key)
  PUT  /v1/lists/{id}/items/{itemID}        → replaces the item
  Item: { "id": "...", "name": "...", "qty": 2, "unit": "g" | "ml" | "pc" }
  Errors: plain text bodies, e.g. "Bad quantity"
  Version 1.1: rename "qty" to "quantity" in /v1
choices:
  - text: "Page-number pagination on a list that other people edit while you read it."
    correct: true
  - text: "Creating items with POST and no idempotency key, so a retried request after a timeout can add the item twice."
    correct: true
  - text: "Plain-text errors, so the client can't tell validation from a server failure or know which field is wrong."
    correct: true
  - text: "Renaming a field inside /v1, which breaks every installed app that reads qty."
    correct: true
  - text: "The unit is a closed set of values with no plan for new ones."
    correct: true
  - text: "Using PUT to replace an item is wrong; it should be POST."
    correct: false
    why: "PUT to a known item URL is idempotent and is the right method for replacing it."
rubric:
  - I flagged offset/page pagination on a shared, changing list.
  - I flagged the non-idempotent create.
  - I flagged the error format.
  - I flagged the breaking change inside a version.
  - I flagged the closed enum.
solution: |
  All but the PUT point are real problems.

  - **Pages shift** when another household member adds or removes an item; use a change feed (`?since=`) for sync, or a cursor if the list is long enough to page at all.
  - **Duplicates on retry:** generate the item ID on the device and `PUT /items/{itemID}`, or send an `Idempotency-Key` with the POST.
  - **Errors:** use the envelope with a code, `retryable` and `fields`.
  - **Rename inside v1:** add `quantity` alongside `qty` and keep both until old apps are gone, or make the change in v2.
  - **Units:** document that new values may appear, and have the client decode unknown ones to `.other(raw)`.
````

````exercise
id: m48-l02-e5
type: solve
prompt: |
  Write `action(status:code:retryAfter:)` returning a short string for the UI:

  - code `"app_version_unsupported"` → `"upgrade"` regardless of status
  - 401 → `"sign in"`
  - 422 → `"fix input"`
  - 429 or 503 → `"wait N"`, where N is `retryAfter` if it's a whole number of seconds, otherwise 30
  - other 5xx → `"retry"`
  - anything else → `"message"`

  Expected output:

  ```output
  upgrade
  sign in
  fix input
  wait 5
  wait 30
  retry
  message
  ```
starter: |
  func action(status: Int, code: String?, retryAfter: String?) -> String {
      // your code
      return ""
  }

  print(action(status: 400, code: "app_version_unsupported", retryAfter: nil))
  print(action(status: 401, code: nil, retryAfter: nil))
  print(action(status: 422, code: "validation_failed", retryAfter: nil))
  print(action(status: 429, code: nil, retryAfter: "5"))
  print(action(status: 503, code: nil, retryAfter: "Wed, 21 Oct 2026 07:28:00 GMT"))
  print(action(status: 502, code: nil, retryAfter: nil))
  print(action(status: 404, code: "not_found", retryAfter: nil))
hints:
  - "Check the code before the status."
  - "Int(\"Wed, 21 Oct…\") is nil, so ?? 30 gives the default."
rubric:
  - Checks the version code first.
  - Parses Retry-After seconds with a default.
  - Distinguishes 429/503 from other 5xx.
  - Falls back to a message for anything else.
solution: |
  ```swift
  func action(status: Int, code: String?, retryAfter: String?) -> String {
      if code == "app_version_unsupported" { return "upgrade" }
      switch status {
      case 401: return "sign in"
      case 422: return "fix input"
      case 429, 503: return "wait \(retryAfter.flatMap { Int($0) } ?? 30)"
      case 500...599: return "retry"
      default: return "message"
      }
  }

  print(action(status: 400, code: "app_version_unsupported", retryAfter: nil))
  print(action(status: 401, code: nil, retryAfter: nil))
  print(action(status: 422, code: "validation_failed", retryAfter: nil))
  print(action(status: 429, code: nil, retryAfter: "5"))
  print(action(status: 503, code: nil, retryAfter: "Wed, 21 Oct 2026 07:28:00 GMT"))
  print(action(status: 502, code: nil, retryAfter: nil))
  print(action(status: 404, code: "not_found", retryAfter: nil))
  ```

  ```output
  upgrade
  sign in
  fix input
  wait 5
  wait 30
  retry
  message
  ```

  `case 429, 503` comes before `case 500...599`, so 503 waits rather than retrying at once. `Retry-After` can be an HTTP date; this version uses the default for that, which is acceptable, and parsing the date is a small follow-up if the backend sends dates.
````

````exercise
id: m48-l02-e6
type: design
prompt: "Design the API for Mise's recipe detail screen and the \"save\" action, including what changes when a recipe is edited by its author after a person has saved it for offline use. Cover endpoints, models, caching headers or versions, and errors."
rubric:
  - A detail endpoint separate from the feed summary, with fields the screen needs including alt text.
  - Save and unsave as idempotent operations.
  - A way to detect that a saved copy is stale (an ETag or a version/updatedAt field) and refresh it.
  - Tolerant decoding for new fields and enum values.
  - Error cases mapped to actions (not found after deletion, offline, upgrade).
solution: |
  - **`GET /v1/recipes/{id}`** returns ingredients (name, quantity, unit), steps, a full photo URL with its alt text, `version` and `updatedAt`, and the person's `saved` flag. The response carries an `ETag`; the client stores it with the saved copy.
  - **Save:** `PUT /v1/me/saved/{id}` and `DELETE /v1/me/saved/{id}`, both idempotent, so the outbox can retry them blindly.
  - **Staleness:** when online, revalidate saved recipes with `If-None-Match`; 304 means the offline copy is current, 200 replaces it. The saved-recipes list can also return each recipe's `version` so the client fetches only the changed ones.
  - **Deleted by the author:** 404 or 410 with code `recipe_removed`. Product decision: keep the offline copy with a "No longer available" note, or remove it. Say which and why.
  - **Evolution:** new optional fields only; the unit enum decodes unknown values to `.other(raw)`.
  - **Errors:** the shared envelope; offline shows the saved copy; `app_version_unsupported` shows the update screen.
````

## Summary

- Derive the API from the screens: summaries for lists, details on demand, idempotent writes.
- REST suits most apps; GraphQL trades HTTP caching for flexible field selection; APNs reaches the app when it isn't running but background pushes are low priority, throttled and unguaranteed; a WebSocket is for low-latency traffic while the app is open.
- A pagination contract states a total order, an opaque cursor, a page-size cap and an end marker. Cursor on (sort key, id), never on the timestamp alone.
- Installed apps live for years: only additive changes within a version, tolerant decoding with unknown enum cases, new versions for breaking changes, and a minimum supported version from configuration.
- Keep DTOs, domain models, persistence entities and view state separate; validate when mapping and format only in view state.
- Give errors an envelope with a stable code, a retryable flag and field errors, and map them to the few actions the UI can take.
