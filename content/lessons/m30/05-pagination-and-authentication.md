---
id: m30-l05
title: Pagination and authentication
description: "Load long lists a page at a time and call APIs that need a signed-in user. You compare page/offset and cursor pagination and see why offsets duplicate items when the list changes, load the next page from an actor so fast scrolling can't fire the same request twice, send bearer tokens, refresh an expired token exactly once even when ten requests hit a 401 together, keep tokens out of logs, and see where tokens are stored (the Keychain)."
module: m30
order: 5
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l04]
objectives:
  - Explain page/offset and cursor pagination and choose between them.
  - Show how offset pagination duplicates or skips items when the list changes between requests.
  - Load the next page from an actor that ignores duplicate triggers, stops at the end and recovers from a failed page.
  - Send a bearer token and explain access and refresh tokens.
  - Refresh an expired access token once for any number of concurrent requests, retry each request once, and sign out when the refresh fails.
  - Redact credentials from logs, and store tokens in the Keychain rather than UserDefaults.
terms:
  - term: Offset pagination
    definition: "The client asks for items by position: offset=40&limit=20, or page=3&per_page=20. Simple, supports jumping to a page, but positions shift when items are added or removed."
  - term: Cursor pagination
    definition: "The server returns an opaque cursor with each page, and the client sends it back to get the next one. The cursor marks a position in the data itself, so inserts and deletes don't shift pages."
  - term: Bearer token
    definition: "A credential sent as Authorization: Bearer <token> (RFC 6750). Whoever holds it can use it, so it must be protected like a password."
  - term: Access token
    definition: "A short-lived bearer token sent with every API request. When it expires, the API answers 401."
  - term: Refresh token
    definition: "A long-lived credential sent only to the auth server to get a new access token. Stored in the Keychain."
  - term: Request coalescing
    definition: "Letting concurrent callers that need the same result share one in-flight operation instead of each starting their own."
mastery:
  - Predict the duplicate that offset pagination produces when an item is inserted at the top between page loads.
  - Write a paginator actor whose loadNextPage() makes one request no matter how many callers trigger it at once.
  - Write a token provider that coalesces refreshes and detects that another request already refreshed.
  - Make a client retry a 401 exactly once with a fresh token, and sign out on a second 401.
  - Write a log line for a request with its Authorization header and token parameters redacted.
resources: [rfc-6750, security-storing-keys-keychain, keychain-services, owasp-masvs, owasp-mastg, swift-book-error-handling]
cards:
  - id: m30-l05-c1
    front: Offset or cursor pagination for a feed where new posts arrive at the top?
    back: "Cursor. With offsets, a post inserted at the top shifts everything down one, so the next page repeats the last item you already have (and deletions skip one). A cursor marks a position in the data, not an index."
  - id: m30-l05-c2
    front: How do you keep fast scrolling from loading the same page twice?
    back: "Keep the pagination state in an actor and store the in-flight Task before the first await. A second call finds it and waits for it (or returns) instead of starting another request."
  - id: m30-l05-c3
    front: Ten requests get a 401 at the same time. How many token refreshes should happen?
    back: "One. A token provider actor stores the refresh Task; the others await it. A request that sends an already-replaced token gets the current one without refreshing."
  - id: m30-l05-c4
    front: The retried request gets a 401 again with the new token. Now what?
    back: "Stop: don't refresh again. The refresh token is probably revoked or the account changed. Clear the tokens and send the user to sign in. Retrying in a loop hammers the auth server."
  - id: m30-l05-c5
    front: Where do tokens go, and where do they never go?
    back: "In the Keychain (not UserDefaults or files), in the Authorization header (not the URL). Never in logs, crash reports or analytics: redact Authorization, cookies and token parameters."
---

## The idea in one sentence

Long lists come back a page at a time and protected APIs need a token that expires, and both turn into the same concurrency problem: when several parts of the app need the same next page or the same fresh token at once, exactly one request should go out and everyone else should wait for it.

## Page/offset and cursor pagination

An API can't return all 40,000 posts at once, so it returns them in pages. Two families of designs:

**Page/offset.** The client says where to start: `GET /v1/posts?offset=40&limit=20`, or `?page=3&per_page=20` (the same thing counted in pages). The server returns the items in positions 40 to 59, often with a total count. It's simple, and it lets a UI jump to page 7.

**Cursor.** The server returns each page with a `next_cursor`, an opaque string (often an encoded ID or timestamp). The client sends it back: `GET /v1/posts?cursor=eyJpZCI6...&limit=20`. When there's no next cursor, you've reached the end. You can't jump to page 7, but the cursor points at a place *in the data*, not at a position.

That difference matters as soon as the list changes while someone scrolls. A feed sorted newest first, with a new post published between page 1 and page 2:

```swift
// Post IDs on the server, newest first: 10, 9, 8, ..., 1.
var server = Array((1...10).reversed())

func page(of items: [Int], offset: Int, limit: Int) -> [Int] {
    Array(items.dropFirst(offset).prefix(limit))
}

func page(of items: [Int], after cursor: Int?, limit: Int) -> [Int] {
    guard let cursor else {
        return Array(items.prefix(limit))
    }
    guard let index = items.firstIndex(of: cursor) else {
        return []
    }
    return Array(items[(index + 1)...].prefix(limit))
}

let firstByOffset = page(of: server, offset: 0, limit: 4)
let firstByCursor = page(of: server, after: nil, limit: 4)
print("page 1: \(firstByOffset)")

server.insert(11, at: 0)   // someone publishes a post

let secondByOffset = page(of: server, offset: 4, limit: 4)
let secondByCursor = page(of: server, after: firstByCursor.last, limit: 4)
print("offset page 2: \(secondByOffset)")
print("cursor page 2: \(secondByCursor)")
```

```output
page 1: [10, 9, 8, 7]
offset page 2: [7, 6, 5, 4]
cursor page 2: [6, 5, 4, 3]
```

Post 11 pushed every post down one position, so the item at offset 4 is now post 7, which the user already has: a duplicate in the list (and, with diffable data sources, a crash if IDs must be unique). A deletion does the opposite and silently skips a post. The cursor version asks for "after post 7" and gets the right page regardless.

Here the cursor is just the last ID, to show the idea. Real APIs encode more (sort key plus ID, so ties are stable) and make the cursor **opaque**: you store it and send it back, but never parse or build it.

Which to use is usually the backend's decision. If it's offset-based, de-duplicate by ID when you append a page; if you have a say, ask for cursors for anything sorted by time.

## Loading the next page safely

The trigger for "load more" is usually a cell near the bottom appearing (Module 27's prefetching, or SwiftUI's `.onAppear` on the last row). It fires often: several times in a fast scroll, and again before the first load finishes. Without care you get the same page twice, or two pages applied in the wrong order.

The state (items so far, next cursor, whether a load is running, whether you're at the end) belongs in an actor. And because actors are reentrant (Module 29, lesson 4), "check whether a load is running" and "mark a load as running" must happen with no `await` between them. The in-flight `Task` is stored before the first suspension, exactly like the deduplicating cache in Module 29:

```swift
struct Page: Sendable {
    let ids: [Int]
    let nextCursor: String?
}

protocol PageSource: Sendable {
    func fetchPage(cursor: String?) async throws -> Page
}

actor Paginator {
    private let source: any PageSource
    private(set) var ids: [Int] = []
    private var nextCursor: String?
    private(set) var reachedEnd = false
    private var inFlight: Task<Void, any Error>?

    init(source: any PageSource) {
        self.source = source
    }

    func loadNextPage() async throws {
        if let inFlight {
            return try await inFlight.value   // join the load that's already running
        }
        guard !reachedEnd else {
            return
        }
        let cursor = nextCursor
        let task = Task {
            defer { self.inFlight = nil }
            let page = try await self.source.fetchPage(cursor: cursor)
            self.append(page)
        }
        inFlight = task                      // recorded before any await
        try await task.value
    }

    private func append(_ page: Page) {
        let known = Set(ids)
        ids += page.ids.filter { !known.contains($0) }
        nextCursor = page.nextCursor
        reachedEnd = page.nextCursor == nil
    }
}

actor FakeFeed: PageSource {
    private let pages: [String: Page] = [
        "start": Page(ids: [1, 2, 3], nextCursor: "c3"),
        "c3": Page(ids: [4, 5, 6], nextCursor: "c6"),
        "c6": Page(ids: [7], nextCursor: nil),
    ]
    private(set) var requests: [String] = []

    func fetchPage(cursor: String?) async throws -> Page {
        let key = cursor ?? "start"
        requests.append(key)
        try await Task.sleep(for: .milliseconds(20))   // the network
        return pages[key]!
    }
}

let feed = FakeFeed()
let paginator = Paginator(source: feed)

// Three "load more" triggers at once, as from a fast scroll.
async let a: Void = paginator.loadNextPage()
async let b: Void = paginator.loadNextPage()
async let c: Void = paginator.loadNextPage()
_ = try await (a, b, c)
print("after the burst: \(await paginator.ids), requests \(await feed.requests)")

try await paginator.loadNextPage()
try await paginator.loadNextPage()
try await paginator.loadNextPage()   // already at the end: no request
print("at the end: \(await paginator.ids), requests \(await feed.requests)")
print("reached end: \(await paginator.reachedEnd)")
```

```output
after the burst: [1, 2, 3], requests ["start"]
at the end: [1, 2, 3, 4, 5, 6, 7], requests ["start", "c3", "c6"]
reached end: true
```

How it holds together:

- **Check and record with no `await` in between.** Whichever call runs first sees `inFlight == nil`, creates the task and stores it before reaching `try await task.value`. Any call that runs during that wait finds the task and awaits the same one. Three triggers, one request.
- **The task applies the page itself.** A `Task { }` created inside an actor method inherits the actor's isolation, so `self.append(page)` runs on the actor, and it runs before `task.value` returns to anyone. Every caller that awaited the load sees the new items.
- **`defer { self.inFlight = nil }`** clears the marker whether the fetch succeeded or threw. After a failure, `nextCursor` is unchanged, so the next trigger retries the same page.
- **The end is a state.** `nextCursor == nil` sets `reachedEnd`, and later triggers return immediately without a request. For offset APIs, "fewer items than the limit" is the usual end signal.
- **`append` de-duplicates by ID**, which costs nothing and saves you when the API is offset-based after all.

> [!note] Joining or ignoring?
> Joining (`return try await inFlight.value`) means every caller returns only once the page is in. For a scroll trigger nobody awaits the result, so returning immediately when a load is running is just as good. Joining is the safer default: a pull-to-refresh spinner that awaits `loadNextPage()` stops at the right moment either way.

## Authentication with bearer tokens

Most app APIs authenticate with **bearer tokens** (RFC 6750). After the user signs in, the auth server returns two credentials:

- An **access token**, short-lived (minutes to an hour). Every API request carries it: `Authorization: Bearer eyJhbGciOi...`.
- A **refresh token**, long-lived (days to months). It's sent only to the auth server, only to get a new access token.

"Bearer" means possession is enough: whoever has the token is you, until it expires. So tokens are handled like passwords. They go in the `Authorization` header, never in the URL (lesson 1: URLs are logged); they're stored in the Keychain; and they never appear in logs.

When the access token expires, the API answers **401 Unauthorized**. The client then uses the refresh token to get a new access token, and sends the original request again. Once.

### Refreshing once for many requests

Here's where it goes wrong in real apps. The app comes back from the background after two hours; the home screen fires five requests at once; all five get 401. A naive client starts five refreshes. Depending on the auth server, that's five round trips, or worse: many servers **rotate** refresh tokens (each refresh invalidates the old refresh token), so refresh number two fails and logs the user out.

The fix is the same shape as the paginator: a token provider actor that stores the refresh `Task` before awaiting it. One more detail makes it complete: a request that started with the old token can come back with its 401 *after* the refresh has already finished. It shouldn't trigger a second refresh, so it tells the provider which token was rejected, and if that's no longer the current one, it just gets the new one.

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum AuthError: Error {
    case signedOut
}

actor TokenProvider {
    private var accessToken: String
    private var refreshTask: Task<String, any Error>?
    private var isSignedOut = false
    private let refresh: @Sendable () async throws -> String

    init(accessToken: String, refresh: @escaping @Sendable () async throws -> String) {
        self.accessToken = accessToken
        self.refresh = refresh
    }

    func currentToken() async throws -> String {
        if isSignedOut {
            throw AuthError.signedOut
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        return accessToken
    }

    /// Called after a 401. `rejected` is the token that request was sent with.
    func token(replacing rejected: String) async throws -> String {
        if isSignedOut {
            throw AuthError.signedOut
        }
        if let refreshTask {
            return try await refreshTask.value       // a refresh is running: share it
        }
        if rejected != accessToken {
            return accessToken                       // someone already refreshed
        }
        let task = Task { try await refresh() }
        refreshTask = task                           // recorded before any await
        defer { refreshTask = nil }
        do {
            accessToken = try await task.value
            return accessToken
        } catch AuthError.signedOut {
            isSignedOut = true                       // the refresh token was rejected
            throw AuthError.signedOut
        }
    }
}

struct AuthenticatedClient: Sendable {
    let transport: any HTTPTransport
    let tokens: TokenProvider

    func data(for request: URLRequest) async throws -> Data {
        let token = try await tokens.currentToken()
        let (data, response) = try await send(request, token: token)
        guard response.statusCode == 401 else {
            return data
        }
        let freshToken = try await tokens.token(replacing: token)
        let (retryData, retryResponse) = try await send(request, token: freshToken)
        guard retryResponse.statusCode != 401 else {
            throw AuthError.signedOut               // a second 401: stop, don't loop
        }
        return retryData
    }

    private func send(_ request: URLRequest, token: String) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await transport.send(request)
    }
}

/// Accepts only "token-2". Its refresh endpoint either issues "token-2" or rejects the refresh token.
actor FakeAuthServer: HTTPTransport {
    let refreshSucceeds: Bool
    private(set) var refreshes = 0

    init(refreshSucceeds: Bool) {
        self.refreshSucceeds = refreshSucceeds
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let ok = request.value(forHTTPHeaderField: "Authorization") == "Bearer token-2"
        let response = HTTPURLResponse(url: request.url!, statusCode: ok ? 200 : 401, httpVersion: nil, headerFields: nil)!
        return (Data((request.url?.lastPathComponent ?? "").utf8), response)
    }

    func refresh() async throws -> String {
        refreshes += 1
        try await Task.sleep(for: .milliseconds(30))
        guard refreshSucceeds else {
            throw AuthError.signedOut
        }
        return "token-2"
    }
}

for refreshSucceeds in [true, false] {
    let server = FakeAuthServer(refreshSucceeds: refreshSucceeds)
    let tokens = TokenProvider(accessToken: "token-1") { try await server.refresh() }
    let client = AuthenticatedClient(transport: server, tokens: tokens)

    let results = await withTaskGroup(of: String.self) { group in
        for path in ["profile", "feed", "notifications", "settings", "badges"] {
            group.addTask {
                let request = URLRequest(url: URL(string: "https://api.example.com/v1/\(path)")!)
                do {
                    return String(decoding: try await client.data(for: request), as: UTF8.self)
                } catch {
                    return "\(path): \(error)"
                }
            }
        }
        var all: [String] = []
        for await result in group {
            all.append(result)
        }
        return all.sorted()
    }
    print("refresh succeeds \(refreshSucceeds): \(results)")
    print("  refreshes: \(await server.refreshes)")
}
```

```output
refresh succeeds true: ["badges", "feed", "notifications", "profile", "settings"]
  refreshes: 1
refresh succeeds false: ["badges: signedOut", "feed: signedOut", "notifications: signedOut", "profile: signedOut", "settings: signedOut"]
  refreshes: 1
```

Five concurrent requests, all sent with the expired `token-1`, all answered 401, **one refresh** in both runs. The order in which the five tasks run varies from run to run; the result doesn't:

- The first 401 to reach the provider finds no refresh running and `token-1` still current, so it starts the refresh and stores the task before awaiting it.
- Any 401 that arrives while the refresh runs finds `refreshTask` and awaits the same task.
- A 401 that arrives after a successful refresh carries `token-1`, which is no longer current, so it gets `token-2` without refreshing again. A request that starts after the refresh gets `token-2` from `currentToken()` and never sees a 401.
- Each request retries **once**. If the retry gets another 401, the client throws `signedOut` instead of refreshing again.
- In the second run the auth server rejects the refresh token. The provider remembers that (`isSignedOut`), so the requests waiting on the refresh, the late ones and any new ones all fail with `signedOut` without another refresh. Remembering it is what keeps the count at one: without it, a request arriving after the failed refresh would see `token-1` still current and try again.
- Only a *rejected* refresh signs the user out. If the refresh fails because the device is offline, the error propagates as it is and the session survives; signing someone out because the train went into a tunnel is a bug.

What to do on `signedOut` is an app decision, made in one place: clear the stored tokens, cancel in-flight work, and show the sign-in screen. Don't show five alerts.

> [!tip] Refresh proactively, too
> Access tokens usually come with their lifetime (`expires_in` in the sign-in response). A provider that remembers the expiry can refresh a minute before it, so most requests never see a 401. Keep the 401 path anyway: clocks drift, and servers revoke tokens early.

## Keeping secrets out of logs

Network logging is invaluable while debugging, and it's the most common way tokens leak: into the console, crash reports, analytics, a screenshot in a bug report. OWASP's mobile security standard (MASVS) has a whole category on this. Two rules:

1. Log requests through one function that **redacts** sensitive headers and parameters, rather than printing `URLRequest`s and response bodies directly.
2. On Apple platforms, `Logger` redacts interpolated strings by default when logs are collected from the device; don't mark a token `privacy: .public` to make debugging easier.

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let sensitiveHeaders: Set<String> = ["authorization", "cookie", "x-api-key"]
let sensitiveParameters: Set<String> = ["token", "access_token", "password", "code"]

func logLine(for request: URLRequest) -> String {
    var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
    components.queryItems = components.queryItems?.map { item in
        sensitiveParameters.contains(item.name.lowercased())
            ? URLQueryItem(name: item.name, value: "REDACTED")
            : item
    }
    let headers = (request.allHTTPHeaderFields ?? [:])
        .map { name, value in
            let lowercased = name.lowercased()
            return "\(lowercased): \(sensitiveHeaders.contains(lowercased) ? "REDACTED" : value)"
        }
        .sorted()
    let target = components.percentEncodedPath + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
    return "\(request.httpMethod ?? "GET") \(target) [\(headers.joined(separator: ", "))]"
}

var components = URLComponents(string: "https://api.example.com/v1/oauth/callback")!
components.queryItems = [URLQueryItem(name: "code", value: "a1b2c3"), URLQueryItem(name: "state", value: "xyz")]
var request = URLRequest(url: components.url!)
request.setValue("Bearer eyJhbGciOiJIUzI1NiJ9.secret", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Accept")

print(logLine(for: request))
```

```output
GET /v1/oauth/callback?code=REDACTED&state=xyz [accept: application/json, authorization: REDACTED]
```

Header names are lowercased (they're case-insensitive anyway) and sorted so the line is stable. The redaction lists are allow-by-default, which is a trade-off: a new secret header that nobody adds to the list will leak. Stricter teams log only an allow-list of known-safe headers.

Response bodies need the same care: the sign-in response *contains* the tokens. Don't log bodies of auth endpoints at all.

## Storing tokens: the Keychain

Tokens must survive app restarts, so they have to be stored somewhere. Not `UserDefaults`: it's a plain property list in the app's container, included in unencrypted backups and readable on a compromised device. The place for credentials on Apple platforms is the **Keychain**, an encrypted store managed by the system, where each item has an accessibility class that says when it can be read.

Module 31 covers the Keychain properly. Here's the shape of storing and reading the refresh token, type-checked against the iOS SDK:

```swift ios
import Foundation
import Security

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
}

struct RefreshTokenStore {
    private let service = "com.example.bookshelf.auth"
    private let account = "refresh-token"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ token: String) throws {
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unexpectedStatus(status)
        }
        return String(decoding: data, as: UTF8.self)
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
```

- An item is identified by its class (`kSecClassGenericPassword`), service and account.
- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` lets background refreshes read the token after the device has been unlocked once since boot, and keeps it out of backups restored to other devices.
- `SecItem` functions return an `OSStatus`, not a Swift error; wrap it in your own error.
- `delete()` is what "sign out" calls, along with dropping the in-memory access token.

The access token can live only in memory (in the `TokenProvider`): when the app restarts, it refreshes once with the stored refresh token.

## Common mistakes

> [!error] Offset pagination for a live feed, without de-duplication
> New items at the top shift the offsets, so the next page repeats items (and deletions skip some). Prefer cursors; at least de-duplicate by ID.

> [!error] A Bool isLoading checked after an await
> `guard !isLoading` followed by an `await` before `isLoading = true` lets two loads through, because the actor is reentrant. Set the marker, or store the task, before the first await.

> [!error] One refresh per failed request
> Five 401s start five refreshes, and with rotating refresh tokens all but the first fail and sign the user out. Coalesce refreshes in an actor and compare the rejected token with the current one.

> [!error] Retrying a 401 forever
> Refresh and retry once. A second 401 means the session is over: sign out.

> [!error] Tokens in URLs, logs or UserDefaults
> URLs and logs are copied everywhere; `UserDefaults` isn't encrypted storage. Use the `Authorization` header, redact logs, store in the Keychain.

## Exercises

````exercise
id: m30-l05-e1
type: prediction
prompt: "The newest-first list loses its top item (it's deleted) between page 1 and page 2. What does offset pagination return for page 2, and which post does the user never see?"
code: |
  var server = [50, 49, 48, 47, 46, 45, 44, 43]

  func page(of items: [Int], offset: Int, limit: Int) -> [Int] {
      Array(items.dropFirst(offset).prefix(limit))
  }

  var shown = page(of: server, offset: 0, limit: 3)
  server.removeFirst()          // post 50 is deleted
  shown += page(of: server, offset: 3, limit: 3)

  print(shown)
  let missing = server.filter { !shown.contains($0) && $0 > shown.last! }
  print("never shown: \(missing)")
output: |
  [50, 49, 48, 46, 45, 44]
  never shown: [47]
solution: |
  Page 1 is positions 0 to 2: `[50, 49, 48]`. Deleting 50 moves every post up one position, so position 3 is now post 46 (post 47 moved to position 2, which the client already "has"). Page 2 is `[46, 45, 44]`, and post 47 is skipped.

  ```output
  [50, 49, 48, 46, 45, 44]
  never shown: [47]
  ```

  Inserts cause duplicates, deletions cause gaps. The user still sees the deleted post 50 too, which is a separate problem (refreshing the first page fixes it). A cursor of "after post 48" would have returned `[47, 46, 45]`.
````

````exercise
id: m30-l05-e2
type: comprehension
prompt: "A paginator actor has `var isLoading = false`. Its `loadNextPage()` does `guard !isLoading else { return }`, then `let page = try await source.fetchPage(cursor: nextCursor)`, then sets `isLoading = true` before appending and `isLoading = false` at the end. Three triggers arrive together. What happens?"
choices:
  - text: "All three calls pass the guard and three identical requests go out, because isLoading is set only after the await."
    correct: true
    why: "Each call suspends at the await before setting the flag; the actor runs the next call meanwhile, which also sees false."
  - text: "Only one request goes out, because an actor runs one method call at a time."
    correct: false
    why: "Actors are reentrant: a call that suspends at await lets the others run before it finishes."
  - text: "The compiler rejects the code because isLoading is checked and set in different places."
    correct: false
    why: "It's valid Swift. The bug is a logic race, which the compiler can't see."
  - text: "The second and third calls wait for the first to finish, then each load the next page."
    correct: false
    why: "Nothing makes them wait; they return or proceed right away."
solution: |
  The check and the update must happen with no `await` between them. Move `isLoading = true` right after the guard (and reset it in a `defer`), or store the in-flight `Task` before awaiting it, as the lesson's `Paginator` does. Storing the task has the added benefit that later callers can await the same load.
````

````exercise
id: m30-l05-e3
type: fill-in
prompt: "Complete the request so it sends the access token the standard way."
code: |
  var request = URLRequest(url: url)
  request.setValue("[[1]] \(accessToken)", forHTTPHeaderField: "[[2]]")
blanks:
  - id: "1"
    answers: ["Bearer"]
  - id: "2"
    answers: ["Authorization", "authorization"]
solution: |
  `request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")`. RFC 6750 defines the `Bearer` scheme in the `Authorization` header. The scheme name is followed by one space and the token. Sending the token as a query parameter (`?access_token=...`) is also described by the RFC, but discouraged there for the reason in lesson 1: URLs end up in logs.
````

````exercise
id: m30-l05-e4
type: solve
prompt: "Write a `TokenProvider` actor with `func token(replacing rejected: String) async throws -> String` that refreshes at most once at a time, shares a running refresh, and returns the current token without refreshing if `rejected` is no longer current. Test it: start with `\"t1\"`, call `token(replacing: \"t1\")` from four concurrent tasks (the refresh closure sleeps 20 ms and returns `\"t2\"`), then call `token(replacing: \"t1\")` once more after they finish, then `token(replacing: \"t2\")`. Print the sorted results of the four, the result of each later call, and the number of refreshes."
starter: |
  // Write TokenProvider and the test here.
rubric:
  - The refresh Task is stored before the first await, so concurrent callers share it.
  - A call with a token that's no longer current returns the current token without refreshing.
  - The refresh task is cleared after it finishes (success or failure).
  - The output shows two refreshes in total, one for the burst and one for the explicit t2 rejection.
solution: |
  ```swift
  actor TokenProvider {
      private var accessToken: String
      private var refreshTask: Task<String, any Error>?
      private let refresh: @Sendable () async throws -> String
      private(set) var refreshCount = 0

      init(accessToken: String, refresh: @escaping @Sendable () async throws -> String) {
          self.accessToken = accessToken
          self.refresh = refresh
      }

      func token(replacing rejected: String) async throws -> String {
          if let refreshTask {
              return try await refreshTask.value
          }
          if rejected != accessToken {
              return accessToken
          }
          refreshCount += 1
          let task = Task { try await refresh() }
          refreshTask = task
          defer { refreshTask = nil }
          accessToken = try await task.value
          return accessToken
      }
  }

  actor Counter {
      private var value = 1
      func next() -> Int {
          value += 1
          return value
      }
  }

  let counter = Counter()
  let provider = TokenProvider(accessToken: "t1") {
      try await Task.sleep(for: .milliseconds(20))
      return "t\(await counter.next())"
  }

  let burst = try await withThrowingTaskGroup(of: String.self) { group in
      for _ in 1...4 {
          group.addTask { try await provider.token(replacing: "t1") }
      }
      var tokens: [String] = []
      for try await token in group {
          tokens.append(token)
      }
      return tokens.sorted()
  }
  print("burst: \(burst)")
  print("late t1 rejection: \(try await provider.token(replacing: "t1"))")
  print("t2 rejected: \(try await provider.token(replacing: "t2"))")
  print("refreshes: \(await provider.refreshCount)")
  ```

  ```output
  burst: ["t2", "t2", "t2", "t2"]
  late t1 rejection: t2
  t2 rejected: t3
  refreshes: 2
  ```

  The four concurrent calls produce one refresh: the first stores the task before awaiting it, the others find it and await the same value (or, if they run after it finished, see that `t1` isn't current anymore). The late `t1` rejection is a request that started before the refresh and came back after; it gets `t2` for free. Rejecting `t2` is a genuine new expiry, so it refreshes again. Each refresh returns a new token from `Counter`, which is how the output proves how many happened.
````

````exercise
id: m30-l05-e5
type: find-errors
prompt: "An authenticated client from a code review. Which are real problems?"
code: |
  final class SessionClient {
      var accessToken = UserDefaults.standard.string(forKey: "accessToken") ?? ""
      let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""

      func get(_ path: String) async throws -> Data {
          let url = URL(string: "https://api.example.com\(path)?access_token=\(accessToken)")!
          print("GET \(url)")
          let (data, response) = try await URLSession.shared.data(from: url)
          if (response as? HTTPURLResponse)?.statusCode == 401 {
              accessToken = try await refresh()
              return try await get(path)
          }
          return data
      }

      func refresh() async throws -> String { /* POST /oauth/token with refreshToken */ "" }
  }
choices:
  - text: "Tokens are stored in UserDefaults instead of the Keychain."
    correct: true
    why: "UserDefaults isn't meant for secrets."
  - text: "The access token is sent in the URL, and the URL is printed to the log."
    correct: true
    why: "Use the Authorization header, and redact logs."
  - text: "Every request that gets a 401 starts its own refresh."
    correct: true
    why: "Concurrent 401s cause concurrent refreshes, which fail with rotating refresh tokens."
  - text: "After refreshing, it calls get recursively with no limit, so a persistent 401 loops forever."
    correct: true
    why: "Retry once; a second 401 means sign out."
  - text: "A mutable accessToken in a non-Sendable class used from concurrent tasks is a data race."
    correct: true
    why: "Make the token state an actor."
  - text: "URLSession can't send authenticated requests; you need a custom delegate."
    correct: false
    why: "Setting the Authorization header on the request is enough for bearer tokens."
rubric:
  - Finds UserDefaults storage.
  - Finds the token in the URL and in the log.
  - Finds the uncoordinated refresh.
  - Finds the unbounded recursion.
  - Finds the data race on accessToken.
solution: |
  Rebuild it from the lesson's pieces: a `RefreshTokenStore` backed by the Keychain, a `TokenProvider` actor that holds the access token and coalesces refreshes, and an `AuthenticatedClient` that sets `Authorization: Bearer …`, retries a 401 exactly once with the refreshed token, and throws `signedOut` otherwise. Log through a redacting function. The class becomes a `Sendable` struct, because all mutable state lives in the actor.
````

````exercise
id: m30-l05-e6
type: design
prompt: "Design the sign-in lifecycle for an app with access and refresh tokens: what happens at launch, on a 401, when the refresh fails, when the user signs out, and when the app returns from the background after a week. Name the types involved (from this lesson or your own), where each token lives, and which events the UI observes."
rubric:
  - At launch, the refresh token is read from the Keychain; with none, show sign-in; the access token is obtained by refreshing (or restored from memory only).
  - On 401, a coalesced refresh and a single retry.
  - When the refresh fails with an auth error, tokens are deleted from the Keychain and memory, in-flight work is cancelled, and the UI moves to sign-in once.
  - A network failure during refresh is distinguished from a rejected refresh token (don't sign out because the user is offline).
  - Sign-out revokes the refresh token on the server if the API supports it, then deletes local tokens.
solution: |
  One reasonable design:

  - **Types:** `RefreshTokenStore` (Keychain), `TokenProvider` (actor, holds the access token in memory and coalesces refreshes), `AuthenticatedClient` (adds the header, retries a 401 once), and a `@MainActor` `SessionModel` the UI observes with a state of `.signedOut`, `.signedIn(User)`.
  - **Launch:** read the refresh token. None: `.signedOut`, show sign-in. Present: `.signedIn`, and let the first request's 401 (or a proactive refresh) get an access token.
  - **401:** the client asks the provider for a token replacing the rejected one; one refresh for all concurrent requests; each request retries once.
  - **Refresh fails:** if the auth server rejected the refresh token (400 `invalid_grant` or 401), the session is over: delete the Keychain item, drop the access token, cancel in-flight tasks, set `.signedOut` once. If the refresh failed because the device is offline or timed out, keep the tokens and report `.offline` to the screen; signing someone out because the train entered a tunnel is a bug.
  - **After a week in the background:** the access token is long expired, so the first requests get 401s and share one refresh. If the refresh token has also expired, the user signs in again.
  - **Sign-out:** call the server's revoke endpoint if it has one (best effort), delete local tokens, reset caches that hold user data, set `.signedOut`.
````

## Summary

- Offset pagination (`offset`/`limit`, `page`/`per_page`) is simple and allows jumping, but inserts duplicate items and deletions skip them. Cursor pagination follows an opaque position in the data and doesn't.
- Keep pagination state in an actor and store the in-flight `Task` before awaiting it, so concurrent "load more" triggers make one request. Track the end, and de-duplicate by ID.
- Bearer tokens go in `Authorization: Bearer <token>`. Access tokens are short-lived; refresh tokens get new ones and live in the Keychain.
- On a 401, refresh through an actor that shares one refresh among all callers and skips refreshing when the rejected token was already replaced. Retry each request once; a second 401 or a rejected refresh means sign out.
- Never put tokens in URLs, logs or `UserDefaults`. Log through a function that redacts credentials.
