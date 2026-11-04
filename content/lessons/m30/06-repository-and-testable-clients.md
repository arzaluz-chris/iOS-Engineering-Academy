---
id: m30-l06
title: The repository pattern and testable clients
description: "Put the networking layer behind seams you can test. You inject dependencies through small protocols, build a repository that combines the API with a cache (fresh data when it can, stale data when the network fails), test it with fake transports and an injected clock, test the real URLSession path with URLProtocol stubs, and pin the API's JSON with contract tests on fixtures."
module: m30
order: 6
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l05]
objectives:
  - Layer a networking feature as view model, repository, API client and transport, each depending on a protocol it receives.
  - Build a repository that serves cached data while fresh, refreshes from the API when stale, and falls back to stale data when the network fails.
  - Test the repository with a fake transport and an injected clock, with no network and no waiting.
  - Test the real URLSession path with a URLProtocol stub registered on an ephemeral session.
  - Write contract tests that decode fixture JSON and check every field, so API changes fail a test instead of a screen.
terms:
  - term: Repository
    definition: "A type that gives the rest of the app domain values (books, orders) and hides where they come from: the network, a cache, a database, or a mix."
  - term: Dependency injection
    definition: "Passing a type the things it depends on (a transport, a cache, a clock) instead of letting it create or look them up, so tests can pass different ones."
  - term: Fake
    definition: "A working, simplified implementation of a dependency, such as an in-memory server actor that answers by path. Module 33 compares fakes, stubs and mocks in depth."
  - term: URLProtocol stub
    definition: "A URLProtocol subclass registered in a session configuration's protocolClasses. URLSession hands it the requests, and it answers with canned responses, so the real URLSession code path runs without a network."
  - term: Fixture
    definition: "A saved sample payload, usually a JSON file in the test target, captured from the real API or written from its specification."
  - term: Contract test
    definition: "A test that decodes a fixture of the real API format and checks each field, so a mismatch between the app's models and the API's JSON shows up in CI."
mastery:
  - Draw the dependency chain of a networking feature and say which protocol each layer depends on.
  - Write a repository with a freshness window and a stale-on-failure fallback, and predict which calls hit the network.
  - Replace Date() with an injected clock to test time-based behavior without sleeping.
  - Register a URLProtocol stub on an ephemeral URLSession and run the real transport against it.
  - Write a contract test that would catch a renamed JSON key, including one behind an optional property.
resources: [foundation-urlprotocol, swift-testing-docs, swift-book-protocols, swift-book-generics, foundation-urlsession-init-delegate]
cards:
  - id: m30-l06-c1
    front: What does a repository give its callers?
    back: "Domain values through a protocol (book(id:), orders()), without saying whether they came from the network, a cache or a database. Callers depend on the protocol; tests use a fake one."
  - id: m30-l06-c2
    front: How do you test code that depends on the current time?
    back: "Inject the clock: a now() function or a clock value. Production passes Date(); tests pass a fake they can move forward, so a 5-minute expiry is tested instantly."
  - id: m30-l06-c3
    front: Fake transport or URLProtocol stub?
    back: "A fake transport replaces everything below the protocol, fast and simple, for testing clients and repositories. A URLProtocol stub keeps the real URLSession and URLSessionTransport in the loop, for testing that layer itself."
  - id: m30-l06-c4
    front: How do you register a URLProtocol stub?
    back: "Create a URLSessionConfiguration (ephemeral), set protocolClasses = [StubURLProtocol.self], and build a URLSession from it. The stub's canInit returns true, and startLoading answers through client?.urlProtocol(...) calls."
  - id: m30-l06-c5
    front: What does a contract test catch that a fake transport test doesn't?
    back: "A mismatch between your models and the API's real JSON: renamed keys, changed types, date formats. Fakes return JSON you wrote to match your models; a fixture comes from the real API."
---

## The idea in one sentence

Every layer of the networking stack depends on a small protocol it's given rather than on a concrete type it creates, so each layer can be tested by itself: the repository with a fake transport, the transport with a `URLProtocol` stub, and the models with real fixture JSON.

## The layers

Lessons 3 to 5 built the pieces. Put together, a feature looks like this, with each arrow meaning "holds a value of this protocol type, received in its initializer":

```text
BookViewModel ──> BookRepository (protocol)
                     │ RemoteBookRepository
                     ├──> APIClient ──> HTTPTransport (protocol)
                     │                     │ URLSessionTransport ──> URLSession
                     └──> BookCache (actor)
```

- The **view model** knows only `BookRepository`. It doesn't know there's a network, a cache, or JSON. In its tests, a fake repository returns books or throws errors directly.
- The **repository** decides where data comes from: the cache, the API, or the cache again when the API fails. It returns domain types and app-level errors.
- The **API client** (lessons 3 and 4) turns endpoints into requests and responses into models, with status checks, error mapping and retries.
- The **transport** is the one line that touches `URLSession`.

Nothing here needs a dependency injection framework. **Initializer injection**, passing dependencies as parameters with production defaults if you like, is enough:

```swift illustrative
let transport = URLSessionTransport(session: NetworkSessions.api)
let repository = RemoteBookRepository(transport: transport, cache: BookCache())
let viewModel = BookViewModel(repository: repository)
```

That wiring happens once, at app start (the composition root: the scene delegate or the `App` struct). Module 32 goes into architecture; here the point is that every arrow can be replaced in a test.

## A repository with a cache

A common policy for data that changes slowly (a book's details, a user's profile):

1. If the cache has the item and it's younger than `maxAge`, return it. No request.
2. Otherwise fetch it, store it with the current time, and return it.
3. If the fetch fails because of the network and there's a cached copy, however old, return that. Stale data beats an error screen.
4. A 404 is not a network failure: the item is gone, so say so.

Time is a dependency too. A repository that calls `Date()` can only be tested by waiting five real minutes, so the clock is injected:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct Book: Decodable, Sendable {
    let id: Int
    let title: String
}

enum RepositoryError: Error {
    case notFound
    case unavailable
}

protocol BookRepository: Sendable {
    func book(id: Int) async throws -> Book
}

actor BookCache {
    private var entries: [Int: (book: Book, storedAt: Date)] = [:]

    func entry(for id: Int) -> (book: Book, storedAt: Date)? {
        entries[id]
    }

    func store(_ book: Book, at date: Date) {
        entries[book.id] = (book, date)
    }
}

struct RemoteBookRepository: BookRepository {
    let transport: any HTTPTransport
    let cache: BookCache
    var maxAge: TimeInterval = 300
    var now: @Sendable () async -> Date = { Date() }

    func book(id: Int) async throws -> Book {
        let cached = await cache.entry(for: id)
        let currentTime = await now()
        if let cached, currentTime.timeIntervalSince(cached.storedAt) < maxAge {
            return cached.book
        }
        do {
            let book = try await fetch(id: id)
            await cache.store(book, at: currentTime)
            return book
        } catch RepositoryError.notFound {
            throw RepositoryError.notFound
        } catch {
            if let cached {
                return cached.book
            }
            throw RepositoryError.unavailable
        }
    }

    private func fetch(id: Int) async throws -> Book {
        let request = URLRequest(url: URL(string: "https://api.example.com/v1/books/\(id)")!)
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            return try JSONDecoder().decode(Book.self, from: data)
        case 404:
            throw RepositoryError.notFound
        default:
            throw URLError(.badServerResponse)
        }
    }
}

// Test doubles.
actor FakeBookServer: HTTPTransport {
    var online = true
    var titles: [Int: String] = [42: "Kindred"]
    private(set) var calls = 0

    func set(online: Bool) { self.online = online }
    func set(title: String, for id: Int) { titles[id] = title }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls += 1
        guard online else {
            throw URLError(.notConnectedToInternet)
        }
        let id = Int(request.url?.lastPathComponent ?? "") ?? 0
        let (status, body) = titles[id].map { (200, #"{"id": \#(id), "title": "\#($0)"}"#) } ?? (404, "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

actor TestClock {
    private var current = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { current }
    func advance(minutes: Double) { current += minutes * 60 }
}

let server = FakeBookServer()
let clock = TestClock()
let repository = RemoteBookRepository(transport: server, cache: BookCache(), now: { await clock.now() })

func show(_ step: String, id: Int = 42) async {
    let outcome: String
    do {
        outcome = try await repository.book(id: id).title
    } catch {
        outcome = "\(error)"
    }
    print("\(step): \(outcome) (network calls: \(await server.calls))")
}

await show("first load")
await clock.advance(minutes: 4)
await show("4 minutes later")
await server.set(title: "Kindred (25th anniversary edition)", for: 42)
await clock.advance(minutes: 2)
await show("6 minutes later")
await server.set(online: false)
await clock.advance(minutes: 60)
await show("an hour later, offline")
await show("unknown book, offline", id: 7)
await server.set(online: true)
await show("unknown book, online", id: 7)
```

```output
first load: Kindred (network calls: 1)
4 minutes later: Kindred (network calls: 1)
6 minutes later: Kindred (25th anniversary edition) (network calls: 2)
an hour later, offline: Kindred (25th anniversary edition) (network calls: 3)
unknown book, offline: unavailable (network calls: 4)
unknown book, online: notFound (network calls: 5)
```

Each line is a scenario a test would assert on:

- **4 minutes later** the cached copy is fresh: no request.
- **6 minutes later** it's stale, so the repository fetches and gets the new edition.
- **An hour later, offline**, the fetch fails and the repository returns the stale copy instead of an error. The call count shows it did try.
- **Offline with nothing cached**, the repository can only report `unavailable`, its own error, not a `URLError`.
- **Online, unknown book**, the 404 becomes `notFound`, which the screen shows differently from "you're offline".

The test advanced 67 minutes of clock time in a few milliseconds. `now` is an async closure because the fake clock is an actor; production passes `{ Date() }`. A `Clock` protocol or Swift's `Clock` types work too; the point is that the repository never reads the time on its own.

> [!note] Why the cache is an actor
> Two screens can ask for book 42 at the same moment, so the cache is shared mutable state. This repository can still fetch the same book twice in that case; if that matters, store an in-flight `Task` per ID, as the paginator in lesson 5 and the thumbnail cache in Module 29 do.

## Testing at each layer

The fake server above replaces the transport, so it tests everything **above** `HTTPTransport`: the repository's policy, the client's status handling, decoding and error mapping. That's where most of the logic is, and these tests are fast and deterministic.

It doesn't test `URLSessionTransport` or the `URLSession` configuration: the cast to `HTTPURLResponse`, how a `URLError` comes out of the session, whether the headers you set survive. For that layer, keep the real `URLSession` and replace only the network underneath it.

## URLProtocol stubs

`URLSession` routes every request through a `URLProtocol` subclass that knows how to load it. The system ships ones for HTTP, HTTPS, files and so on. If you add your own class to a configuration's `protocolClasses`, the session asks it first, and it can answer with whatever you like without opening a connection:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class StubURLProtocol: URLProtocol {
    enum Reply {
        case response(status: Int, body: String)
        case failure(URLError.Code)
    }

    /// Set by the test before making requests. Only safe because the tests that use it run one at a time.
    nonisolated(unsafe) static var reply: (URLRequest) -> Reply = { _ in .failure(.unsupportedURL) }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch Self.reply(request) {
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .response(let status, let body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [StubURLProtocol.self]
let transport = URLSessionTransport(session: URLSession(configuration: configuration))

StubURLProtocol.reply = { request in
    print("stub received \(request.httpMethod ?? "?") \(request.url?.path ?? "") with Accept: \(request.value(forHTTPHeaderField: "Accept") ?? "none")")
    switch request.url?.path {
    case "/v1/books/42": return .response(status: 200, body: #"{"id": 42, "title": "Kindred"}"#)
    case "/v1/books/500": return .response(status: 503, body: "")
    default: return .failure(.timedOut)
    }
}

for id in [42, 500, 1] {
    var request = URLRequest(url: URL(string: "https://api.example.com/v1/books/\(id)")!)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    do {
        let (data, response) = try await transport.send(request)
        print("  -> \(response.statusCode), \(data.count) bytes, Content-Type: \(response.value(forHTTPHeaderField: "content-type") ?? "none")")
    } catch let error as URLError {
        print("  -> URLError, timed out: \(error.code == .timedOut)")
    }
}
```

```output
stub received GET /v1/books/42 with Accept: application/json
  -> 200, 30 bytes, Content-Type: application/json
stub received GET /v1/books/500 with Accept: application/json
  -> 503, 0 bytes, Content-Type: application/json
stub received GET /v1/books/1 with Accept: application/json
  -> URLError, timed out: true
```

What's real and what's stubbed:

- **Real:** `URLSession`, its configuration, `data(for:)`, the cast in `URLSessionTransport`, the way an error reported by the protocol comes out of `data(for:)` as a `URLError`. A bug in any of those shows up here.
- **Stubbed:** the bytes on the wire. `startLoading()` reports a response, the body and completion (or a failure) to `client`, which is how any protocol, including Apple's HTTP one, talks to the session.
- `canInit(with:)` returning `true` claims every request in this session. `canonicalRequest(for:)` is required; returning the request unchanged is the usual implementation.
- The stub is registered on **one ephemeral session**, not globally with `URLProtocol.registerClass(_:)`, so it can't intercept anything else in the process and nothing is cached on disk between tests.

> [!warning] Static state in a stub
> `URLSession` creates the protocol instance itself, so the canned replies have to live somewhere static. `nonisolated(unsafe)` tells Swift 6 you're taking responsibility for that, and the responsibility is real: Swift Testing runs tests in parallel by default, so two tests that set `reply` at once will see each other's replies. Put the tests that use the stub in a suite marked `.serialized`, or key the replies by something unique per test (a host name per test, for example) behind a lock.

> [!note] Request bodies in a stub
> By the time a `URLProtocol` sees a request, `URLSession` may have moved its body from `httpBody` to `httpBodyStream`, so `request.httpBody` can be `nil` even for a POST. Read the stream if your stub needs to check the body. Checking bodies is usually easier one layer up, with a recording fake transport (lesson 3).

## Contract tests with fixtures

Fakes return JSON *you* wrote, shaped like your models, so they can't catch the bug that hurts most: your models and the real API disagree. Lesson 2's `convertFromSnakeCase` trap is the classic case, an optional `coverURL` that's always `nil`, and no test notices because the fake returns `"coverURL"` too.

A **fixture** is a real response, captured from the server (or the staging server) or copied from the API's specification, saved as a file in the test target. A **contract test** decodes it and checks **every field**, including the optional ones:

```swift
import Foundation

struct BookDTO: Decodable {
    let id: Int
    let title: String
    let coverURL: URL?
    let publishedAt: Date
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, publishedAt, tags
        case coverURL = "coverUrl"
    }
}

func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

/// Returns the problems found; empty means the contract holds.
func checkBookContract(_ fixture: String) -> [String] {
    let book: BookDTO
    do {
        book = try makeDecoder().decode(BookDTO.self, from: Data(fixture.utf8))
    } catch {
        return ["does not decode"]
    }
    var problems: [String] = []
    if book.id != 42 { problems.append("id") }
    if book.title != "Kindred" { problems.append("title") }
    if book.coverURL?.absoluteString != "https://img.example.com/42.jpg" { problems.append("coverURL") }
    if book.publishedAt != Date(timeIntervalSince1970: 296_784_000) { problems.append("publishedAt") }
    if book.tags != ["sf", "classic"] { problems.append("tags") }
    return problems
}

// Fixture captured from GET /v1/books/42 (normally Fixtures/book-42.json in the test target).
let fixture = """
{"id": 42, "title": "Kindred", "cover_url": "https://img.example.com/42.jpg",
 "published_at": "1979-05-29T00:00:00Z", "tags": ["sf", "classic"], "isbn": "9780807083697"}
"""

// The same response after a backend change renamed one key.
let changed = fixture.replacingOccurrences(of: "cover_url", with: "cover_image_url")

for (name, json) in [("current API", fixture), ("after the rename", changed)] {
    let problems = checkBookContract(json)
    print("\(name): \(problems.isEmpty ? "contract holds" : "broken: \(problems.joined(separator: ", "))")")
}
```

```output
current API: contract holds
after the rename: broken: coverURL
```

The rename would have decoded without an error, because `coverURL` is optional. Only the explicit check on that field catches it. That's the rule for contract tests: **assert on every field**, not just "it decodes".

Other things that make fixtures useful:

- **Decode into DTOs** (data transfer objects) shaped like the API, and map them into your domain types in one place. The domain model can stay clean (`Book` with a `Cover` enum, say) while the DTO mirrors the JSON, and the contract test pins the DTO.
- **Keep fixtures as files** in the test target (`Fixtures/book-42.json`), loaded with `Bundle.module` in a Swift package. Real payloads are long; they don't belong in Swift strings.
- **Include the awkward cases** the API really produces: an empty list, a `null` optional, the error body format, the last page with no cursor.
- **When the backend changes**, update the fixture on purpose. The diff in the pull request is the record of what changed in the contract.
- Fixtures go stale if nobody refreshes them. Teams that own both sides often generate them from the API specification (OpenAPI) or from recorded staging responses in CI.

## The tests, in Swift Testing

The blocks in this lesson print their results so they can run as plain programs. In the app's test target the same checks become Swift Testing tests (Module 33 covers the framework). A sketch, assuming the types above live in a module called `Bookshelf`:

```swift illustrative
import Foundation
import Testing
@testable import Bookshelf

@Suite struct RemoteBookRepositoryTests {
    let server = FakeBookServer()
    let clock = TestClock()

    func makeRepository() -> RemoteBookRepository {
        RemoteBookRepository(transport: server, cache: BookCache(), now: { await clock.now() })
    }

    @Test func freshCacheSkipsTheNetwork() async throws {
        let repository = makeRepository()
        _ = try await repository.book(id: 42)
        await clock.advance(minutes: 4)
        _ = try await repository.book(id: 42)
        #expect(await server.calls == 1)
    }

    @Test func staleCopyIsReturnedWhenOffline() async throws {
        let repository = makeRepository()
        _ = try await repository.book(id: 42)
        await server.set(online: false)
        await clock.advance(minutes: 60)
        #expect(try await repository.book(id: 42).title == "Kindred")
    }

    @Test func missingBookIsNotFound() async {
        await #expect(throws: RepositoryError.notFound) {
            try await makeRepository().book(id: 7)
        }
    }
}

@Suite(.serialized) struct URLSessionTransportTests {
    // Tests that set StubURLProtocol.reply go here, one at a time.
}

@Test func bookFixtureMatchesTheContract() throws {
    let url = try #require(Bundle.module.url(forResource: "book-42", withExtension: "json"))
    let json = try String(contentsOf: url, encoding: .utf8)
    #expect(checkBookContract(json).isEmpty)
}
```

Each test builds its own fakes (a fresh `FakeBookServer` per test, because Swift Testing creates a new suite instance for each test), so tests can run in parallel. `#expect(throws: RepositoryError.notFound)` needs `RepositoryError` to be `Equatable`, which an enum without associated values is automatically. Only the `URLProtocol` tests, which share static state, are serialized.

## Common mistakes

> [!error] Tests that hit the real network
> They're slow, fail when the server or the Wi-Fi is down, can't produce a 503 on demand, and may change real data. Fake the transport, or stub `URLProtocol`.

> [!error] Calling Date() or Task.sleep inside the code under test
> Time-based behavior then needs real waiting to test. Inject the clock and the sleep.

> [!error] A repository that leaks URLError and DecodingError
> Callers end up switching over transport details. Return domain values and the repository's own errors.

> [!error] Registering a URLProtocol stub globally
> `URLProtocol.registerClass` affects `URLSession.shared`, and with it every other piece of code in the process that uses the shared session. Register it on an ephemeral session's `protocolClasses`.

> [!error] Shared static stub state in parallel tests
> Two tests overwrite each other's canned replies and fail randomly. Serialize those tests or key the replies per test.

> [!error] Contract tests that only check "it decodes"
> A renamed optional key decodes fine as `nil`. Assert on every field.

## Exercises

````exercise
id: m30-l06-e1
type: prediction
prompt: "A repository with a 10-minute cache and stale fallback, a fake clock and a server you can switch off. What does the program print?"
code: |
  actor Server {
      var online = true
      private(set) var calls = 0
      func setOnline(_ value: Bool) { online = value }
      func fetch() throws -> String {
          calls += 1
          guard online else { throw CancellationError() }
          return "v\(calls)"
      }
  }

  actor Repository {
      let server: Server
      private var cached: (value: String, at: Int)?
      init(server: Server) { self.server = server }

      func value(at minute: Int) async -> String {
          if let cached, minute - cached.at < 10 {
              return cached.value + " (cache)"
          }
          do {
              let value = try await server.fetch()
              cached = (value, minute)
              return value
          } catch {
              return cached.map { $0.value + " (stale)" } ?? "error"
          }
      }
  }

  let server = Server()
  let repository = Repository(server: server)
  print(await repository.value(at: 0))
  print(await repository.value(at: 9))
  print(await repository.value(at: 10))
  await server.setOnline(false)
  print(await repository.value(at: 25))
  print(await repository.value(at: 26))
  print("calls: \(await server.calls)")
output: |
  v1
  v1 (cache)
  v2
  v2 (stale)
  v2 (stale)
  calls: 4
solution: |
  - Minute 0: nothing cached, fetch: `v1` (call 1), cached at 0.
  - Minute 9: 9 − 0 < 10, fresh: `v1 (cache)`, no call.
  - Minute 10: 10 − 0 isn't < 10, so fetch: `v2` (call 2), cached at 10.
  - Minute 25: stale (15 minutes), fetch fails (call 3), fall back: `v2 (stale)`. The failed fetch doesn't update `cached`, so it's still from minute 10.
  - Minute 26: still stale, so it tries again (call 4) and falls back again.

  ```output
  v1
  v1 (cache)
  v2
  v2 (stale)
  v2 (stale)
  calls: 4
  ```

  The last line points at a real design question: while offline, every call tries the network first. That's usually fine (a failed request is quick when the radio is off), but a repository can also remember the failure and back off, using lesson 4's ideas. (`CancellationError` only stands in for "a failure" here to keep the example free of Foundation.)
````

````exercise
id: m30-l06-e2
type: comprehension
multiple: true
prompt: "Which of these bugs would a test using a URLProtocol stub catch, but a test using a fake HTTPTransport would not? Select all that apply."
choices:
  - text: "URLSessionTransport force-casts the response with as! and the session returns a non-HTTP response."
    correct: true
    why: "Only the URLProtocol test runs URLSessionTransport and the real session."
  - text: "The session configuration's httpAdditionalHeaders overwrite an Accept header the client sets."
    correct: true
    why: "Configuration behavior happens inside URLSession, which a fake transport skips."
  - text: "The repository returns stale data when it should throw notFound."
    correct: false
    why: "That's repository logic, above the transport. A fake transport test catches it, faster."
  - text: "The model uses convertFromSnakeCase with coverURL and covers are always nil."
    correct: false
    why: "Neither catches it if the canned JSON was written to match the model. A contract test on a real fixture does."
solution: |
  The URLProtocol stub keeps `URLSession`, its configuration and `URLSessionTransport` in the loop, so it catches bugs in that layer. Logic above the transport is better tested with a fake transport. And model/API mismatches need real JSON, which is the contract tests' job. Each kind of test covers a layer; together they cover the stack without a network.
````

````exercise
id: m30-l06-e3
type: fill-in
prompt: "Complete the setup so the session sends every request to the stub instead of the network, without affecting other sessions."
code: |
  let configuration = URLSessionConfiguration.[[1]]
  configuration.[[2]] = [StubURLProtocol.self]
  let session = URLSession([[3]]: configuration)

  final class StubURLProtocol: URLProtocol {
      override class func [[4]](with request: URLRequest) -> Bool { true }
      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
      override func startLoading() { /* report a response to client */ }
      override func stopLoading() {}
  }
blanks:
  - id: "1"
    answers: ["ephemeral"]
  - id: "2"
    answers: ["protocolClasses"]
  - id: "3"
    answers: ["configuration"]
  - id: "4"
    answers: ["canInit"]
solution: |
  An `ephemeral` configuration keeps nothing on disk between tests, `protocolClasses` puts the stub first in line for this configuration only, `URLSession(configuration:)` builds the session (copying the configuration), and `canInit(with:)` returning `true` claims every request. `URLProtocol.registerClass(_:)` would also work but affects `URLSession.shared`, which other code in the process uses too.
````

````exercise
id: m30-l06-e4
type: solve
prompt: "Write a `ProfileRepository` protocol with `func profile() async throws -> String`, and a `RemoteProfileRepository` that takes an `any HTTPTransport` and an injected `now: @Sendable () async -> Date`. It caches the last profile for 60 seconds, returns the cached copy if the network fails (any thrown error), and throws `ProfileError.unavailable` if there's nothing cached. The profile endpoint returns `{\"name\": ...}`. Test it with a fake transport actor (switchable online/offline, counting calls) and a fake clock actor: load at second 0, again at second 30, go offline, load at second 90, and print each result and the call count."
starter: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  protocol HTTPTransport: Sendable {
      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  }

  // Write the repository, the fakes and the test.
rubric:
  - The repository depends on HTTPTransport and an injected clock, not on URLSession or Date().
  - A fresh cached profile is returned without a request.
  - A failed fetch falls back to the cached profile, and throws the repository's own error when there's none.
  - The fakes are actors, and the output shows the call count.
solution: |
  ```swift
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  protocol HTTPTransport: Sendable {
      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  }

  protocol ProfileRepository: Sendable {
      func profile() async throws -> String
  }

  enum ProfileError: Error {
      case unavailable
  }

  actor ProfileCache {
      var entry: (name: String, at: Date)?
      func store(_ name: String, at date: Date) { entry = (name, date) }
  }

  struct RemoteProfileRepository: ProfileRepository {
      struct Payload: Decodable { let name: String }

      let transport: any HTTPTransport
      let now: @Sendable () async -> Date
      let cache = ProfileCache()

      func profile() async throws -> String {
          let cached = await cache.entry
          let time = await now()
          if let cached, time.timeIntervalSince(cached.at) < 60 {
              return cached.name
          }
          do {
              let request = URLRequest(url: URL(string: "https://api.example.com/v1/me")!)
              let (data, response) = try await transport.send(request)
              guard (200..<300).contains(response.statusCode) else {
                  throw URLError(.badServerResponse)
              }
              let name = try JSONDecoder().decode(Payload.self, from: data).name
              await cache.store(name, at: time)
              return name
          } catch {
              guard let cached else { throw ProfileError.unavailable }
              return cached.name
          }
      }
  }

  actor FakeProfileServer: HTTPTransport {
      private var online = true
      private(set) var calls = 0
      func setOnline(_ value: Bool) { online = value }

      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
          calls += 1
          guard online else { throw URLError(.notConnectedToInternet) }
          let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
          return (Data(#"{"name": "Ana"}"#.utf8), response)
      }
  }

  actor FakeClock {
      private var seconds: Double = 0
      func now() -> Date { Date(timeIntervalSince1970: seconds) }
      func set(seconds: Double) { self.seconds = seconds }
  }

  let server = FakeProfileServer()
  let clock = FakeClock()
  let repository = RemoteProfileRepository(transport: server, now: { await clock.now() })

  for (second, online) in [(0.0, true), (30.0, true), (90.0, false)] {
      await clock.set(seconds: second)
      await server.setOnline(online)
      let result = (try? await repository.profile()) ?? "unavailable"
      print("second \(Int(second)), online \(online): \(result), calls \(await server.calls)")
  }

  let empty = RemoteProfileRepository(transport: server, now: { await clock.now() })
  do {
      _ = try await empty.profile()
  } catch ProfileError.unavailable {
      print("offline with nothing cached: unavailable")
  }
  ```

  ```output
  second 0, online true: Ana, calls 1
  second 30, online true: Ana, calls 1
  second 90, online false: Ana, calls 2
  offline with nothing cached: unavailable
  ```

  At second 30 the cache is fresh, so there's no call. At second 90 it's stale, the fetch fails (call 2) and the cached name is returned. A new repository with an empty cache can only throw `unavailable`. Note that `let cache = ProfileCache()` gives each repository value its own cache, which is what makes the last check independent. In an app you'd inject the cache too, so the composition root decides whether it's shared.
````

````exercise
id: m30-l06-e5
type: find-errors
prompt: "A test file for the networking layer. Which are real problems?"
code: |
  @Suite struct BookClientTests {
      @Test func loadsBook() async throws {
          let client = APIClient(transport: URLSessionTransport(session: .shared))
          let book = try await client.send(.book(id: 42))
          #expect(book.title == "Kindred")
      }

      @Test func cacheExpires() async throws {
          let repository = RemoteBookRepository(transport: FakeBookServer(), cache: BookCache())
          _ = try await repository.book(id: 42)
          try await Task.sleep(for: .seconds(301))
          _ = try await repository.book(id: 42)
      }

      @Test func stubReturns503() async throws {
          StubURLProtocol.reply = { _ in .response(status: 503, body: "") }
          // ...
      }

      @Test func stubReturnsBook() async throws {
          StubURLProtocol.reply = { _ in .response(status: 200, body: bookJSON) }
          // ...
      }

      @Test func decodingErrorMessage() async throws {
          do {
              _ = try JSONDecoder().decode(Book.self, from: Data("{}".utf8))
          } catch {
              #expect(error.localizedDescription == "The data couldn't be read because it is missing.")
          }
      }
  }
choices:
  - text: "loadsBook goes through URLSession.shared to the real server."
    correct: true
    why: "Slow, flaky, and depends on live data. Use a fake transport."
  - text: "cacheExpires waits five real minutes and doesn't assert anything."
    correct: true
    why: "Inject a clock and advance it; then expect a second network call."
  - text: "stubReturns503 and stubReturnsBook set the same static reply and can run in parallel."
    correct: true
    why: "Mark the suite .serialized or key replies per test."
  - text: "decodingErrorMessage compares localizedDescription, which differs across platforms and OS versions."
    correct: true
    why: "Match the DecodingError case and coding path instead."
  - text: "Async test functions aren't supported in Swift Testing."
    correct: false
    why: "@Test functions can be async and throwing."
rubric:
  - Finds the real network access.
  - Finds the real sleep and the missing assertion.
  - Finds the shared static state in parallel tests.
  - Finds the assertion on localizedDescription.
solution: |
  Each fix uses a seam from the lesson: a `FakeBookServer` instead of `URLSessionTransport(session: .shared)`; a `TestClock` passed as `now`, advanced by 6 minutes, followed by `#expect(await server.calls == 2)`; `@Suite(.serialized)` for the URLProtocol tests; and `#expect(throws: DecodingError.self)` plus a check of the case (`keyNotFound` with the expected key) rather than the message text.
````

````exercise
id: m30-l06-e6
type: design
prompt: "You own the networking layer of an app with 30 endpoints. Plan its tests: which kinds of tests you write, how many of each roughly, what each one fakes, where fixtures come from and how they stay current, and what runs on every pull request versus nightly."
rubric:
  - Many fast unit tests of view models and repositories with fake repositories or fake transports.
  - A small number of URLProtocol-stub tests for URLSessionTransport and the session configuration, serialized.
  - A contract test per endpoint (or per model) on fixtures, checking every field and the error format.
  - Fixtures come from the real API or its specification and are updated deliberately; optionally refreshed by a scheduled job against staging.
  - Few or no tests against a live server on every PR; any live checks run separately (nightly, against staging) and don't block merges on flakiness.
solution: |
  A reasonable plan:

  - **Unit tests (hundreds, every PR):** view models against fake repositories; repositories and the API client against fake transports with injected clocks and sleeps. They cover caching, error mapping, retries, pagination and token refresh. Milliseconds each, no network.
  - **Transport tests (a handful, every PR, serialized):** `URLSessionTransport` with a `URLProtocol` stub on an ephemeral session: success, non-HTTP status codes, a `URLError` coming through, headers set by the configuration.
  - **Contract tests (one per model or endpoint, every PR):** decode fixtures and assert every field, including optional ones, plus the API's error body and edge cases (empty list, last page, null optionals). Also encode request bodies and compare decoded values with what the API expects.
  - **Fixtures:** captured from staging or generated from the OpenAPI specification, stored as JSON files in the test target. They change only in pull requests that say why, so the diff documents API changes.
  - **Live checks (nightly, non-blocking):** a small job that calls staging, re-captures the fixtures and opens a pull request or alert if they changed. It catches backend changes early without making every merge depend on a server being up.
````

## Summary

- Layer networking as view model → repository → API client → transport, each depending on a protocol it receives in its initializer. Wire the real types once, at the composition root.
- A repository returns domain values and its own errors. A cache policy of "fresh within `maxAge`, refetch when stale, stale on network failure, 404 is not a network failure" covers most read-mostly data.
- Inject everything a test needs to control: the transport, the cache, the clock, the sleep. Then time-based behavior is tested in milliseconds.
- Fake transports test everything above the transport. A `URLProtocol` stub on an ephemeral session tests the real `URLSession` path; its static state needs serialized tests.
- Contract tests decode real fixture JSON and assert every field, so model/API mismatches fail in CI, including optional fields that would silently become `nil`.
