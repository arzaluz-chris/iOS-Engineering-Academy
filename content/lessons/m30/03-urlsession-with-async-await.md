---
id: m30-l03
title: URLSession with async/await
description: "Send real requests with URLSession's async API and turn the result into typed values. You call data(for:), cast and check the HTTPURLResponse yourself (URLSession doesn't fail on a 404), put URLSession behind a small transport protocol so the client can be tested without a network, build a typed API client around endpoints, and configure sessions and timeouts on purpose."
module: m30
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l02]
objectives:
  - Load data with URLSession's data(for:) and explain what it throws and what it doesn't.
  - Check the response's type and status code before decoding.
  - Hide URLSession behind a Sendable transport protocol and use a fake transport to run the client without a network.
  - Build a typed API client that turns an endpoint description into a URLRequest and a decoded response.
  - Choose a session configuration and set request and resource timeouts deliberately.
terms:
  - term: URLSession
    definition: "Foundation's HTTP client. A session has a configuration and creates tasks; its async methods data(for:), upload(for:from:), download(for:) and bytes(for:) suspend until the transfer finishes."
  - term: Transport error
    definition: "A failure to get any HTTP response: no connection, timeout, DNS failure, TLS failure, cancellation. URLSession throws these as URLError. An HTTP 404 or 500 is not a transport error."
  - term: Transport protocol
    definition: "A small protocol in your own code (here HTTPTransport) with one method that sends a URLRequest and returns data and an HTTPURLResponse. Production code uses URLSession behind it; tests use a fake."
  - term: Endpoint
    definition: "A value describing one API call (method, path, query, body and the expected response type) that the client turns into a URLRequest."
  - term: timeoutIntervalForRequest
    definition: "How long a task waits for more data before failing with a timeout; the timer resets whenever data arrives. Default 60 seconds."
  - term: timeoutIntervalForResource
    definition: "The maximum time a whole transfer may take, from start to finish. Default 7 days."
mastery:
  - Write a function that loads and decodes a resource with data(for:), checking the response type and status first.
  - Explain why a 404 doesn't throw from URLSession and where your code must catch it.
  - Define a transport protocol and a URLSession-backed implementation, and run an API client against a fake transport.
  - Assert in a test that the client built the request you expected (method, path, query, headers).
  - Pick request and resource timeouts for a screen and explain the difference.
resources: [foundation-urlsession, foundation-urlrequest, foundation-httpurlresponse, foundation-urlcomponents, foundation-urlsessionconfiguration, foundation-urlsession-init-delegate, swift-book-protocols, swift-book-generics, swift-sendable]
cards:
  - id: m30-l03-c1
    front: Does URLSession's data(for:) throw on a 404 or 500?
    back: "No. Any HTTP response counts as success; you get the data and a URLResponse. Cast to HTTPURLResponse and check statusCode yourself. It throws URLError for transport failures (offline, timeout, cancelled)."
  - id: m30-l03-c2
    front: Why put URLSession behind a protocol?
    back: "So the client can be run in tests with a fake that returns canned data and responses: no network, no flakiness, and you can check the requests it built."
  - id: m30-l03-c3
    front: timeoutIntervalForRequest vs timeoutIntervalForResource?
    back: "Request: how long to wait for more data; resets whenever data arrives (default 60 s). Resource: the cap on the whole transfer (default 7 days)."
  - id: m30-l03-c4
    front: "How many URLSessions should an app create?"
    back: "One per configuration, reused for every request (often URLSession.shared). Creating a session per request throws away connection reuse, and a session with a delegate keeps that delegate alive until you invalidate it."
  - id: m30-l03-c5
    front: What does cancelling the task that's awaiting data(for:) do?
    back: "URLSession cancels the underlying request, and data(for:) throws a URLError with code .cancelled. Treat it like CancellationError: not a failure to show."
---

## The idea in one sentence

`URLSession` gets the bytes and a response, and everything that makes those bytes useful to the app (checking the status, decoding, choosing a timeout, being testable) is code you write around it, once, in a small client.

## data(for:)

Since iOS 15, `URLSession` has `async` methods. The one you'll use most:

```swift illustrative
func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)? = nil) async throws -> (Data, URLResponse)
```

A complete load, written the plain way first:

```swift ios
import Foundation

struct Book: Decodable {
    let id: Int
    let title: String
}

enum BookLoadingError: Error {
    case notHTTP
    case status(Int)
}

func loadBook(id: Int) async throws -> Book {
    var components = URLComponents(string: "https://api.example.com/v1/books")!
    components.path += "/\(id)"
    var request = URLRequest(url: components.url!)
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
        throw BookLoadingError.notHTTP
    }
    guard (200..<300).contains(http.statusCode) else {
        throw BookLoadingError.status(http.statusCode)
    }
    return try JSONDecoder().decode(Book.self, from: data)
}
```

This block is type-checked against the iOS SDK but never run: it would need the network. Line by line:

1. The request is built as in lesson 1.
2. `try await URLSession.shared.data(for: request)` suspends the calling task (not a thread, Module 29) until the whole body has arrived. The session does the I/O on its own threads.
3. It **throws only for transport failures**: no connection, a timeout, a DNS or TLS failure, a cancelled task. Those arrive as `URLError`, with a `code` such as `.notConnectedToInternet`, `.timedOut` or `.cancelled`.
4. It returns `(Data, URLResponse)`. `URLResponse` is the general type (for `file:` URLs too); for HTTP it's always an `HTTPURLResponse`, but the type system doesn't know that, so you cast. A `guard let … as?` is better than `as!`: a crash in a networking layer is never the right answer.
5. **A 404 or a 500 doesn't throw.** To `URLSession`, "the server answered 500" is a successful transfer. If you skip the status check, you'll try to decode the server's HTML error page as a `Book` and get a confusing `DecodingError` instead of "server error".
6. Only then decode.

Every request in an app needs steps 4 to 6, and lesson 4 adds error mapping and retries. That's why you write them once, in a client, and not in every view model.

> [!note] Cancellation comes for free
> `data(for:)` respects task cancellation (Module 29, lesson 3): cancel the task that's awaiting it and `URLSession` cancels the request, which then throws `URLError` with code `.cancelled`. A SwiftUI `.task` or a view controller that cancels its task in `viewDidDisappear` stops its downloads without extra code. Lesson 4 makes sure your error handling doesn't show "Something went wrong" for it.

The other async methods follow the same pattern: `upload(for:from:)` sends a body from `Data`, `download(for:)` writes the body to a temporary file and returns its URL (for large files), and `bytes(for:)` gives you an `AsyncSequence` of bytes as they arrive.

## URLRequest settings

Besides method, headers and body, a request carries a timeout and a cache policy:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

var request = URLRequest(url: URL(string: "https://api.example.com/v1/books")!)
print(request.timeoutInterval)
print(request.cachePolicy == .useProtocolCachePolicy)

request.timeoutInterval = 15
request.cachePolicy = .reloadIgnoringLocalCacheData
print(request.timeoutInterval)
print(request.cachePolicy == .reloadIgnoringLocalCacheData)
```

```output
60.0
true
15.0
true
```

- `timeoutInterval` defaults to 60 seconds. It's an idle timeout: how long the request may go without receiving data, not the total duration.
- `.useProtocolCachePolicy` follows the server's caching headers (`Cache-Control`, `ETag`) through the session's `URLCache`. `.reloadIgnoringLocalCacheData` always goes to the server, which you want for a pull-to-refresh.
- `URLRequest` is a struct and `Sendable`, so you can build it anywhere and pass it into async code.

## A transport protocol: the seam for tests

Code that calls `URLSession.shared` directly can only be tested against a real server, which is slow, flaky and can't easily produce a 503 or a malformed body on demand. The fix is a **seam**: a protocol with exactly the one operation the client needs.

```swift illustrative
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

- It returns `HTTPURLResponse`, not `URLResponse`, so the cast happens once, inside the real implementation.
- It's `Sendable` because the client will be shared across tasks (Module 29, lesson 5). `URLRequest`, `Data` and `HTTPURLResponse` are all `Sendable`, so the values can cross into and out of async code.
- It's tiny on purpose. A fake needs to implement one method.

Production uses `URLSession`, tests use a fake. Both fit in one block, and only the fake is used here:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

/// Answers every request with the same status and body.
struct StubTransport: HTTPTransport {
    let statusCode: Int
    let body: String

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(body.utf8), response)
    }
}

let transport: any HTTPTransport = StubTransport(statusCode: 200, body: #"{"id": 42, "title": "Kindred"}"#)
let request = URLRequest(url: URL(string: "https://api.example.com/v1/books/42")!)
let (data, response) = try await transport.send(request)
print(response.statusCode)
print(String(decoding: data, as: UTF8.self))
```

```output
200
{"id": 42, "title": "Kindred"}
```

`URLSessionTransport` is three lines of real logic, and the only part of the client that touches `URLSession`. Everything above it can now run against `StubTransport` in a test, in milliseconds, with any status code you want. `URLSessionTransport` is still tested, but by a few integration tests (or by the `URLProtocol` stubs of lesson 6), not by every unit test.

## A typed API client

Now the client. An **endpoint** describes one call and the type it returns; the **client** turns it into a request, sends it through the transport, checks the status and decodes:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct Endpoint<Response: Decodable & Sendable>: Sendable {
    var method = "GET"
    var path: String
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
}

enum APIError: Error {
    case unacceptableStatus(Int)
    case decoding(DecodingError)
}

struct APIClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport

    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try makeRequest(for: endpoint)
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.unacceptableStatus(response.statusCode)
        }
        do {
            return try Self.makeDecoder().decode(Response.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(error)
        }
    }

    func makeRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path += endpoint.path
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// The app's endpoints, in one place.
struct Book: Decodable, Sendable {
    let id: Int
    let title: String
    let pageCount: Int
}

extension Endpoint where Response == Book {
    static func book(id: Int) -> Endpoint {
        Endpoint(path: "/books/\(id)")
    }
}

// A fake server: the response depends on the path.
struct FakeBookServer: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        let (status, body): (Int, String) = switch path {
        case "/v1/books/42": (200, #"{"id": 42, "title": "Kindred", "page_count": 264}"#)
        case "/v1/books/7": (200, #"{"id": 7, "title": "Piranesi"}"#)
        default: (404, #"{"error": "not found"}"#)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

let client = APIClient(baseURL: URL(string: "https://api.example.com/v1")!, transport: FakeBookServer())

for id in [42, 7, 1] {
    do {
        let book = try await client.send(.book(id: id))
        print("\(book.title), \(book.pageCount) pages")
    } catch APIError.unacceptableStatus(let code) {
        print("book \(id): HTTP \(code)")
    } catch APIError.decoding(.keyNotFound(let key, _)) {
        print("book \(id): missing \(key.stringValue)")
    }
}
```

```output
Kindred, 264 pages
book 7: missing pageCount
book 1: HTTP 404
```

The pieces:

- **`Endpoint<Response>`** carries its response type as a generic parameter. `client.send(.book(id: 42))` is inferred to return a `Book`, and you can't decode a book endpoint as a `User` by mistake. The type is never stored; it's a *phantom* parameter that only guides the compiler.
- **Static factory methods** in a constrained extension (`where Response == Book`) keep every path of the API in one file instead of scattered string literals.
- **`makeRequest(for:)`** appends the endpoint's path to the base URL's path (`/v1` + `/books/42`) through `URLComponents`, so query items are encoded. It's a separate method so tests can check it without sending anything.
- **The status check comes before decoding**, so book 1 reports `HTTP 404` rather than a decoding error about the error body.
- **The decoder is created per call.** It's cheap, and it keeps `APIClient` a struct of `Sendable` values with nothing shared and mutable.
- **Decoding errors are wrapped** in `APIError.decoding`, keeping the original `DecodingError` (and its coding path) for logging. Book 7's payload has no `page_count`, and the `catch` pattern reaches all the way into the nested error.
- **`Response: Decodable & Sendable`** because the decoded value is returned from a nonisolated async function to whoever awaited it, which may be on another actor.

> [!tip] Where does the decoding run?
> `send` is a nonisolated async function. In a Swift 6 package with default settings it runs on the cooperative pool, off the main actor. In an app target with Xcode's Approachable Concurrency and default MainActor isolation (Module 29, lesson 6), unannotated code becomes `@MainActor` and nonisolated async functions run on the caller's actor, so a large JSON decode could block the main thread. Mark the client `nonisolated`, and mark `send` `@concurrent` if its payloads are big.

## Checking the request in a test

A fake that **records** what it receives lets you assert that the client built the right request. Its state changes from concurrent calls, so it's an actor:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

actor RecordingTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    let body: String

    init(body: String) {
        self.body = body
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

struct SearchClient: Sendable {
    let transport: any HTTPTransport

    func search(_ text: String, page: Int) async throws -> [String] {
        var components = URLComponents(string: "https://api.example.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "page", value: String(page)),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await transport.send(request)
        return try JSONDecoder().decode([String].self, from: data)
    }
}

let recorder = RecordingTransport(body: #"["Kindred", "Dawn"]"#)
let client = SearchClient(transport: recorder)
let titles = try await client.search("octavia butler", page: 2)
print(titles)

let sent = await recorder.requests
print(sent.count)
print(sent[0].httpMethod ?? "none", sent[0].url?.path ?? "")
let items = URLComponents(url: sent[0].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
for item in items {
    print("\(item.name) = \(item.value ?? "nil")")
}
print(sent[0].value(forHTTPHeaderField: "Accept") ?? "no Accept")
```

```output
["Kindred", "Dawn"]
1
GET /v1/search
q = octavia butler
page = 2
application/json
```

The test reads the query back through `URLComponents` and compares *decoded* values, not the encoded URL string, so it doesn't depend on how a particular Foundation version spells the percent-encoding. A class with a mutable `requests` array couldn't conform to a `Sendable` protocol without a lock; an actor gets that for free, at the cost of `await` when reading it.

> [!error] error: stored property 'requests' of 'Sendable'-conforming class 'RecordingTransport' is mutable
> What you get if you write the recorder as a class. Swift 6.3, with the transport reduced to strings so the example stands alone:

```swift no-compile stored property 'requests' of 'Sendable'-conforming class 'RecordingTransport' is mutable
protocol Transport: Sendable {
    func send(_ path: String) async -> String
}

final class RecordingTransport: Transport {
    var requests: [String] = []

    func send(_ path: String) async -> String {
        requests.append(path)
        return "{}"
    }
}
```

Use an actor, as above, or protect the array with a `Mutex` or a lock (Module 28, lesson 6).

## Sessions and configuration

`URLSession.shared` is fine for simple apps. When you need different timeouts, extra headers on every request, or no disk cache, create your own session from a `URLSessionConfiguration`:

| Configuration | Behavior |
| --- | --- |
| `.default` | Disk cache, cookies and credentials stored persistently |
| `.ephemeral` | Nothing written to disk: cache, cookies and credentials live in memory and disappear with the session |
| `.background(withIdentifier:)` | Transfers continue while the app is suspended; the system relaunches the app to deliver results. Uses delegates, not async/await, for the results |

The two timeouts on the configuration measure different things. From Apple's documentation: `timeoutIntervalForRequest` "controls how long (in seconds) a task should wait for additional data to arrive before giving up. The timer associated with this value is reset whenever new data arrives." `timeoutIntervalForResource` "controls how long (in seconds) to wait for an entire resource to transfer before giving up". The defaults are 60 seconds and 7 days:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let configuration = URLSessionConfiguration.ephemeral
print(configuration.timeoutIntervalForRequest)
print(configuration.timeoutIntervalForResource)

configuration.timeoutIntervalForRequest = 20
configuration.timeoutIntervalForResource = 120
configuration.httpAdditionalHeaders = ["Accept-Language": "en-US"]
let session = URLSession(configuration: configuration)
print(session.configuration.timeoutIntervalForRequest)
print(session.configuration.timeoutIntervalForResource)
```

```output
60.0
604800.0
20.0
120.0
```

A session copies its configuration when it's created, so changing `configuration` afterward doesn't affect `session`. A 60-second idle timeout is long for a screen the user is staring at; 15 to 30 seconds is common for interactive requests, with the resource timeout as an upper bound on the whole thing. A big download wants a generous resource timeout and a normal request timeout: as long as bytes keep arriving, it's fine.

The settings that only exist on Apple platforms go in an app-side factory:

```swift ios
import Foundation

enum NetworkSessions {
    static let api: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.allowsConstrainedNetworkAccess = false
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: configuration)
    }()
}
```

- `waitsForConnectivity = true` makes a request that starts while offline wait for a connection (up to the resource timeout) instead of failing at once with `.notConnectedToInternet`. Good for background syncs, often wrong for a screen where the user wants to know immediately.
- `allowsConstrainedNetworkAccess = false` respects Low Data Mode.
- A `static let` makes one session for the app's lifetime. **Create sessions once and reuse them**: each session keeps its own connection pool, so a session per request loses connection reuse, and a session created with a delegate keeps a strong reference to that delegate until you call `invalidateAndCancel()` or `finishTasksAndInvalidate()`.

## Common mistakes

> [!error] Not checking the status code
> `URLSession` returns 404 and 500 responses as successes. Decode only after checking `200..<300`, or you'll report a decoding error for what was really a server error.

> [!error] response as! HTTPURLResponse
> A force cast in the networking layer turns an unexpected response into a crash. Cast with `guard let … as?` and throw.

> [!error] Calling URLSession.shared from every view model
> You can't test them without a network, and changing a timeout or a header means editing every call site. Put one client behind a transport protocol and inject it.

> [!error] A URLSession per request
> Loses connection reuse and, with delegates, leaks the delegate until the session is invalidated. Create sessions once.

> [!error] Treating the timeout as a total deadline
> `timeoutInterval` and `timeoutIntervalForRequest` are idle timeouts that reset when data arrives. A slow trickle can keep a request alive far longer. Use `timeoutIntervalForResource` for a hard cap.

> [!error] A test fake that's a class with mutable state
> It can't be `Sendable` without a lock, and tests that run requests concurrently will race. Make recorders actors.

## Exercises

````exercise
id: m30-l03-e1
type: prediction
prompt: "A client checks the status before decoding. The fake server returns different answers per path. What does the program print?"
code: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  struct Item: Decodable, Sendable {
      let name: String
  }

  enum LoadError: Error {
      case status(Int)
  }

  func load(_ path: String) async throws -> Item {
      let url = URL(string: "https://api.example.com\(path)")!
      let (status, body): (Int, String) = switch path {
      case "/a": (200, #"{"name": "first"}"#)
      case "/b": (500, "<html>Internal Server Error</html>")
      case "/c": (204, "")
      default: (404, #"{"name": "not really"}"#)
      }
      let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
      guard (200..<300).contains(response.statusCode) else {
          throw LoadError.status(response.statusCode)
      }
      return try JSONDecoder().decode(Item.self, from: Data(body.utf8))
  }

  for path in ["/a", "/b", "/c", "/d"] {
      do {
          print(try await load(path).name)
      } catch LoadError.status(let code) {
          print("status \(code)")
      } catch is DecodingError {
          print("decoding failed")
      }
  }
output: |
  first
  status 500
  decoding failed
  status 404
solution: |
  - `/a`: 200 and valid JSON, so `first`.
  - `/b`: 500. The guard throws before anyone tries to decode the HTML.
  - `/c`: 204 is in `200..<300`, so the guard passes, and decoding an empty body fails. A **204 No Content** has no body by definition; a client that knows an endpoint can answer 204 must handle it before decoding (for example with an `Endpoint` whose response type is an empty struct the client builds without decoding).
  - `/d`: 404. The body happens to be valid JSON for `Item`, but the status check stops it first. Without the guard, the app would happily show "not really".

  ```output
  first
  status 500
  decoding failed
  status 404
  ```
````

````exercise
id: m30-l03-e2
type: comprehension
multiple: true
prompt: "Which of these make `try await URLSession.shared.data(for: request)` throw? Select all that apply."
choices:
  - text: "The device is in airplane mode."
    correct: true
    why: "A transport failure: URLError with code .notConnectedToInternet (unless waitsForConnectivity makes it wait)."
  - text: "The server responds 503 Service Unavailable."
    correct: false
    why: "Any HTTP response is a completed transfer. You get the data and the response, and must check the status yourself."
  - text: "The task awaiting the call is cancelled."
    correct: true
    why: "URLSession cancels the request and throws URLError with code .cancelled."
  - text: "No data arrives for longer than the request's timeout interval."
    correct: true
    why: "URLError with code .timedOut."
  - text: "The body is HTML instead of the JSON you expected."
    correct: false
    why: "URLSession doesn't look at the body's format. Decoding fails later, in your code."
solution: |
  `data(for:)` throws `URLError` when it can't complete an HTTP exchange: offline, timed out, cancelled, DNS or TLS problems. Once a response arrives, whatever its status and body, the call returns normally. Status checking and decoding are your client's job, which is why they live in one place.
````

````exercise
id: m30-l03-e3
type: fill-in
prompt: "Complete the URLSession-backed transport."
code: |
  struct URLSessionTransport: HTTPTransport {
      let session: URLSession

      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
          let (data, response) = [[1]] [[2]] session.[[3]](for: request)
          guard let http = response [[4]] HTTPURLResponse else {
              throw URLError(.badServerResponse)
          }
          return (data, http)
      }
  }
blanks:
  - id: "1"
    answers: ["try"]
  - id: "2"
    answers: ["await"]
  - id: "3"
    answers: ["data"]
  - id: "4"
    answers: ["as?"]
solution: |
  `let (data, response) = try await session.data(for: request)`, then `guard let http = response as? HTTPURLResponse`. `try` comes before `await` (the compiler accepts only that order), `data(for:)` is the async method that returns the whole body, and `as?` is a conditional cast so an unexpected response type becomes a thrown error rather than a crash.
````

````exercise
id: m30-l03-e4
type: solve
prompt: "Write a `ProfileClient` struct with a `transport: any HTTPTransport` and a method `func profile(userID: Int) async throws -> Profile` that sends `GET https://api.example.com/v1/users/<id>` with `Accept: application/json`, throws `ProfileError.status(code)` for non-2xx, and decodes `{\"id\": …, \"display_name\": …}` into `Profile(id:displayName:)`. Test it with an actor that records requests and answers from a dictionary of path → (status, body). Print the result for user 9, the error for user 10 (404), and the method and path of every recorded request."
starter: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  protocol HTTPTransport: Sendable {
      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  }

  // Write Profile, ProfileError, ProfileClient and a recording fake.
rubric:
  - The client builds the URL with the user ID in the path and sets Accept.
  - The status is checked before decoding, and non-2xx throws a typed error with the code.
  - display_name is mapped to displayName (CodingKeys or convertFromSnakeCase).
  - The fake is an actor (or otherwise Sendable) and records every request.
  - The output shows both requests were sent as GET to the right paths.
solution: |
  ```swift
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  protocol HTTPTransport: Sendable {
      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
  }

  struct Profile: Decodable, Sendable {
      let id: Int
      let displayName: String
  }

  enum ProfileError: Error {
      case status(Int)
  }

  struct ProfileClient: Sendable {
      let transport: any HTTPTransport

      func profile(userID: Int) async throws -> Profile {
          var components = URLComponents(string: "https://api.example.com")!
          components.path = "/v1/users/\(userID)"
          var request = URLRequest(url: components.url!)
          request.setValue("application/json", forHTTPHeaderField: "Accept")

          let (data, response) = try await transport.send(request)
          guard (200..<300).contains(response.statusCode) else {
              throw ProfileError.status(response.statusCode)
          }
          let decoder = JSONDecoder()
          decoder.keyDecodingStrategy = .convertFromSnakeCase
          return try decoder.decode(Profile.self, from: data)
      }
  }

  actor FakeServer: HTTPTransport {
      private let routes: [String: (Int, String)]
      private(set) var received: [URLRequest] = []

      init(routes: [String: (Int, String)]) {
          self.routes = routes
      }

      func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
          received.append(request)
          let (status, body) = routes[request.url?.path ?? ""] ?? (404, "")
          let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
          return (Data(body.utf8), response)
      }
  }

  let server = FakeServer(routes: [
      "/v1/users/9": (200, #"{"id": 9, "display_name": "Ana"}"#),
  ])
  let client = ProfileClient(transport: server)

  for id in [9, 10] {
      do {
          let profile = try await client.profile(userID: id)
          print("user \(profile.id): \(profile.displayName)")
      } catch ProfileError.status(let code) {
          print("user \(id): HTTP \(code)")
      }
  }

  for request in await server.received {
      print(request.httpMethod ?? "none", request.url?.path ?? "")
  }
  ```

  ```output
  user 9: Ana
  user 10: HTTP 404
  GET /v1/users/9
  GET /v1/users/10
  ```

  The fake answers by path and defaults to 404, which is also how a real server treats an unknown user. Because it's an actor, `received` is safe to append to from concurrent requests, and reading it needs `await`. The test checks both sides: what the client returned and what it sent.
````

````exercise
id: m30-l03-e5
type: find-errors
prompt: "This view model loads a feed. Which are real problems?"
code: |
  @MainActor
  final class FeedViewModel {
      var posts: [Post] = []
      var errorMessage: String?

      func load() async {
          let session = URLSession(configuration: .default)
          let url = URL(string: "https://api.example.com/v1/feed")!
          do {
              let (data, response) = try await session.data(from: url)
              let http = response as! HTTPURLResponse
              print("status", http.statusCode)
              posts = try JSONDecoder().decode([Post].self, from: data)
          } catch {
              errorMessage = error.localizedDescription
          }
      }
  }
choices:
  - text: "A new URLSession is created on every load, losing connection reuse."
    correct: true
    why: "Create sessions once (or use an injected client) and reuse them."
  - text: "The status code is printed but never checked, so a 500's error body is decoded as posts."
    correct: true
    why: "Check 200..<300 before decoding."
  - text: "as! crashes if the response isn't an HTTPURLResponse."
    correct: true
    why: "Use as? and throw."
  - text: "Calling URLSession directly from the view model makes it impossible to test without a network."
    correct: true
    why: "Inject a client or a transport."
  - text: "A cancelled load shows the cancellation's localizedDescription as an error message."
    correct: true
    why: "URLError.cancelled should be ignored, not shown. Lesson 4 covers this."
  - text: "data(from:) can't be awaited from a @MainActor method."
    correct: false
    why: "It can. The main actor is free while the method is suspended at await."
rubric:
  - Finds the per-call session.
  - Finds the missing status check.
  - Finds the force cast.
  - Finds the lack of injection.
  - Finds that cancellation is shown as an error.
solution: |
  A fixed version takes an `APIClient` (or a `FeedRepository`, lesson 6) in its initializer and calls `posts = try await client.send(.feed)`, where the client checks the status, casts with `as?`, decodes and maps errors. The view model catches the client's error type, ignores cancellation, and sets a message it chose itself instead of `localizedDescription`.
````

````exercise
id: m30-l03-e6
type: design
prompt: "A photo app downloads 40 MB originals over a slow connection, and also loads a small JSON feed on the home screen. With default settings, users on a bad train connection see the feed spinner for about a minute before any error, while some photo downloads fail after hanging for a long time. Explain what the two timeouts measure and propose settings for each kind of request."
rubric:
  - timeoutIntervalForRequest (and URLRequest.timeoutInterval) is an idle timeout that resets whenever data arrives; the default 60 s explains the minute-long spinner.
  - timeoutIntervalForResource caps the whole transfer (default 7 days).
  - The feed needs a short request timeout (around 15-20 s) and a modest resource timeout.
  - Large downloads keep a normal request timeout but a long resource timeout, or a background session.
  - Suggests separate sessions or per-request timeoutInterval rather than one setting for everything.
solution: |
  `timeoutIntervalForRequest` is how long a task may go **without receiving data**; the timer resets with every chunk. Its default of 60 seconds is why the feed spinner runs for a minute when the connection is dead. `timeoutIntervalForResource` is the cap on the **whole** transfer, 7 days by default.

  For the feed, the user is waiting: a request timeout of 15 to 20 seconds and a resource timeout of 30 to 60 seconds, then show an error with a Retry button. For originals, a short idle timeout would kill slow-but-working downloads, so keep the request timeout around 60 seconds and set a long resource timeout (or use a background session with `download(for:)`-style tasks, which survive the app being suspended). The clean way is two sessions with two configurations, or a per-request `timeoutInterval` on the feed request; either way the decision is explicit instead of inherited.
````

## Summary

- `try await session.data(for: request)` returns `(Data, URLResponse)` and throws `URLError` only for transport failures, including cancellation (`.cancelled`).
- A 404 or 500 is not an error to `URLSession`. Cast to `HTTPURLResponse` with `as?`, check `200..<300`, then decode.
- Put `URLSession` behind a one-method `Sendable` transport protocol. The real implementation is three lines; tests use fakes that return canned responses and record requests (as actors).
- A typed client turns `Endpoint<Response>` values into `URLRequest`s, checks the status, decodes with a configured decoder and wraps decoding errors with their coding path.
- `timeoutIntervalForRequest` (and `URLRequest.timeoutInterval`) is an idle timeout, 60 s by default; `timeoutIntervalForResource` caps the whole transfer, 7 days by default.
- Create sessions once per configuration. `.ephemeral` keeps nothing on disk, `waitsForConnectivity` waits instead of failing offline.
