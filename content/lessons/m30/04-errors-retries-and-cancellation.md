---
id: m30-l04
title: Errors, retries and cancellation
description: "Decide what to do when a request fails. You map URLError, HTTP status codes and DecodingError into one app error type with typed throws, decide which failures are worth retrying (and for which methods), retry with capped exponential backoff and jitter, honor the server's Retry-After header, and make sure a cancelled request stops retrying and never shows up as an error."
module: m30
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l03]
objectives:
  - Map transport, HTTP and decoding failures into one app-level error type that the UI can switch over.
  - Classify failures as retryable or not, taking the request method into account.
  - Compute capped exponential backoff with jitter, and explain why jitter matters.
  - Parse Retry-After in both of its forms and let it override the backoff.
  - Write a retry loop that stops on cancellation, never retries a cancelled request, and can be tested without waiting.
terms:
  - term: Transient failure
    definition: "A failure that may not happen again if you try later: a timeout, a dropped connection, a 503. The opposite of a deterministic failure such as a 400 or a decoding error."
  - term: Exponential backoff
    definition: "Waiting longer after each failed attempt, usually doubling: 0.5 s, 1 s, 2 s, 4 s, up to a cap."
  - term: Jitter
    definition: "Randomness added to a backoff delay so that many clients that failed at the same moment don't all retry at the same moment."
  - term: Retry-After
    definition: "A response header (RFC 9110, section 10.2.3) telling the client how long to wait before the next request: either a number of seconds or an HTTP date. Common on 429 and 503."
  - term: Thundering herd
    definition: "Many clients retrying in lockstep after a shared failure, overloading the server again just as it recovers."
mastery:
  - Write a function that turns any error from the networking stack into a case of the app's error type.
  - Say, for a given error and HTTP method, whether the client should retry.
  - Compute the delays of a backoff schedule with a given base, cap and jitter value.
  - Parse a Retry-After header given as seconds or as an HTTP date.
  - Test a retry loop with an injected sleep function and a fake transport, and show that it stops when cancelled.
resources: [foundation-urlerror, rfc-9110, swift-book-error-handling, swift-result, foundation-localizederror, swift-book-enumerations]
cards:
  - id: m30-l04-c1
    front: Which failures are worth retrying?
    back: "Transient ones: timeouts, dropped connections, can't connect, 408, 429, 500, 502, 503, 504. Not 400, 401 (refresh instead), 403, 404, 422, decoding errors or cancellation. And only for idempotent requests, unless the API supports idempotency keys."
  - id: m30-l04-c2
    front: Why add jitter to exponential backoff?
    back: "Without it, every client that failed at the same moment retries at the same moments (1 s, 2 s, 4 s...), hitting the recovering server in synchronized waves. Random delays spread the load."
  - id: m30-l04-c3
    front: What are the two forms of Retry-After?
    back: "A number of seconds (Retry-After: 120) or an HTTP date (Retry-After: Fri, 31 Dec 1999 23:59:59 GMT). Use it instead of your own backoff when present, within a maximum you're willing to wait."
  - id: m30-l04-c4
    front: How should a retry loop handle cancellation?
    back: "Check before each attempt, use a sleep that throws on cancellation (Task.sleep), and treat CancellationError and URLError.cancelled as \"stop\", never as a retryable failure or a message for the user."
  - id: m30-l04-c5
    front: Why map errors into an app error type at the client boundary?
    back: "The UI switches over a few meaningful cases (offline, unauthorized, not found, try later) instead of URLError codes, status numbers and DecodingError, and the mapping is written and tested once."
---

## The idea in one sentence

A networking layer should turn every failure into one of a handful of app-level cases, retry only what's transient and safe to repeat, wait longer (and a little randomly) between attempts, and get out of the way immediately when the task is cancelled.

## Where failures come from

Lesson 3's client can fail in three different places, plus one that isn't a failure at all:

| Source | Type you get | Examples |
| --- | --- | --- |
| Transport | `URLError` | offline, timed out, connection lost, TLS failure |
| HTTP | a status outside `200..<300` | 401, 404, 429, 503 |
| Decoding | `DecodingError` | missing key, wrong type |
| Cancellation | `CancellationError` or `URLError` with code `.cancelled` | the user left the screen |

Views shouldn't know about any of these types. A view needs to know: are we offline, does the user need to sign in again, is the thing gone, should we say "try again later"? So the client maps everything into one enum at its boundary.

## One error type for the app

Module 12 designed error types for a domain. Here's one for networking, with the mapping written once:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum NetworkError: Error, Equatable {
    case cancelled
    case offline
    case timedOut
    case transport(URLError.Code)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case server(status: Int)
    case client(status: Int)
    case decoding(path: String)

    init(_ error: any Error) {
        switch error {
        case let error as NetworkError:
            self = error
        case is CancellationError:
            self = .cancelled
        case let error as URLError:
            switch error.code {
            case .cancelled: self = .cancelled
            case .notConnectedToInternet: self = .offline
            case .timedOut: self = .timedOut
            default: self = .transport(error.code)
            }
        case let error as DecodingError:
            self = .decoding(path: NetworkError.path(of: error))
        default:
            self = .transport(.unknown)
        }
    }

    init?(status: Int) {
        switch status {
        case 200..<300: return nil
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 429: self = .rateLimited
        case 500..<600: self = .server(status: status)
        default: self = .client(status: status)
        }
    }

    static func path(of error: DecodingError) -> String {
        let context: DecodingError.Context? = switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context),
             .keyNotFound(_, let context), .dataCorrupted(let context):
            context
        @unknown default:
            nil
        }
        let keys = context?.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue } ?? []
        return keys.joined(separator: ".")
    }
}

struct Book: Decodable {
    let title: String
}

var errors: [any Error] = [
    URLError(.notConnectedToInternet),
    URLError(.timedOut),
    URLError(.cancelled),
    CancellationError(),
    URLError(.secureConnectionFailed),
]
do {
    _ = try JSONDecoder().decode([Book].self, from: Data(#"[{"title": "Kindred"}, {"title": 7}]"#.utf8))
} catch {
    errors.append(error)
}

for error in errors {
    switch NetworkError(error) {
    case .transport(let code):
        print("transport, code \(code.rawValue)")
    case let mapped:
        print(mapped)
    }
}
for status in [200, 401, 404, 409, 429, 503] {
    print(status, NetworkError(status: status).map { "\($0)" } ?? "ok")
}
```

```output
offline
timedOut
cancelled
cancelled
transport, code -1200
decoding(path: "[1].title")
200 ok
401 unauthorized
404 notFound
409 client(status: 409)
429 rateLimited
503 server(status: 503)
```

- Both kinds of cancellation become `.cancelled`. `URLSession` reports cancellation as `URLError.cancelled`; your own code and `Task.sleep` report it as `CancellationError` (Module 29, lesson 3). The UI only has to ignore one case.
- `.offline` and `.timedOut` get their own cases because the UI shows different messages for them. Other `URLError` codes keep their code for logging.
- A decoding failure keeps only its path, which is what you'd log or send to the backend team. The `DecodingError` itself doesn't need to travel up to the view.
- `init?(status:)` returns `nil` for success, so the client can write `if let error = NetworkError(status: code) { throw error }`.
- The first `case let error as NetworkError` makes the mapping idempotent: mapping an already-mapped error returns it unchanged, which matters once retries and wrappers nest.

The program prints the `URLError` code's raw value rather than the case itself because the description of a `URLError.Code` isn't something to rely on: it's a debugging aid, it can change between platforms, and it's never text for a user. What the user sees should be a message you chose:

```swift
enum NetworkError: Error {
    case cancelled, offline, timedOut, unauthorized, forbidden, notFound, rateLimited
    case server(status: Int)
    case client(status: Int)
    case decoding(path: String)

    /// nil means "show nothing".
    var userMessage: String? {
        switch self {
        case .cancelled: nil
        case .offline: "You're offline. Check your connection and try again."
        case .timedOut, .server, .rateLimited: "The server is busy. Try again in a moment."
        case .unauthorized: "Your session expired. Sign in again."
        case .forbidden: "You don't have access to this."
        case .notFound: "This item no longer exists."
        case .client, .decoding: "Something went wrong. We've been notified."
        }
    }
}

for error in [NetworkError.cancelled, .offline, .server(status: 502), .decoding(path: "items.[3].price")] {
    print(error.userMessage ?? "(nothing shown)")
}
```

```output
(nothing shown)
You're offline. Check your connection and try again.
The server is busy. Try again in a moment.
Something went wrong. We've been notified.
```

`.client` and `.decoding` get the same vague message because they're bugs (in your app or in the server), and the user can't do anything about them. They're the ones to log.

## What to retry

A retry helps only when the next attempt has a real chance of a different answer, and only when repeating the request can't do harm. Two questions:

**Is the failure transient?**

| Retry | Don't retry |
| --- | --- |
| `URLError` `.timedOut`, `.networkConnectionLost`, `.cannotConnectToHost`, `.dnsLookupFailed` | `.cancelled` (the user is gone), `.badURL`, TLS failures like `.secureConnectionFailed` |
| 408 Request Timeout, 429 Too Many Requests | 400, 403, 404, 409, 422: the same request gets the same answer |
| 500, 502, 503, 504 | 401: refresh the token instead (lesson 5) |
| | Decoding errors: the bytes won't change |

`.notConnectedToInternet` is a special case: retrying in a tight loop while the radio is off is pointless. Fail fast and let the user retry, or wait for connectivity (`waitsForConnectivity`, lesson 3).

**Is the request safe to repeat?** Lesson 1: GET, HEAD, PUT and DELETE are idempotent; POST and PATCH aren't. A timeout on a `POST /orders` might mean the order was created. Retry it only if the API supports an idempotency key and you send the same key every time.

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum NetworkError: Error {
    case cancelled, offline, timedOut
    case transport(URLError.Code)
    case unauthorized, forbidden, notFound, rateLimited
    case server(status: Int)
    case client(status: Int)
    case decoding(path: String)

    var isTransient: Bool {
        switch self {
        case .timedOut, .rateLimited:
            return true
        case .transport(let code):
            return [.networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed].contains(code)
        case .server(let status):
            return [500, 502, 503, 504].contains(status)
        case .client(let status):
            return status == 408
        case .cancelled, .offline, .unauthorized, .forbidden, .notFound, .decoding:
            return false
        }
    }
}

func shouldRetry(_ error: NetworkError, method: String) -> Bool {
    let idempotent = ["GET", "HEAD", "PUT", "DELETE", "OPTIONS"].contains(method)
    return idempotent && error.isTransient
}

let cases: [(NetworkError, String)] = [
    (.timedOut, "GET"),
    (.timedOut, "POST"),
    (.server(status: 503), "PUT"),
    (.server(status: 501), "GET"),
    (.notFound, "GET"),
    (.cancelled, "GET"),
    (.transport(.networkConnectionLost), "DELETE"),
]
for (error, method) in cases {
    let name = if case .transport(let code) = error { "transport \(code.rawValue)" } else { "\(error)" }
    print("\(method) after \(name): \(shouldRetry(error, method: method) ? "retry" : "give up")")
}
```

```output
GET after timedOut: retry
POST after timedOut: give up
PUT after server(status: 503): retry
GET after server(status: 501): give up
GET after notFound: give up
GET after cancelled: give up
DELETE after transport -1005: retry
```

`501 Not Implemented` is a 5xx, but it means the server doesn't support the method at all; retrying won't change that. That's why the list is explicit rather than "any 5xx".

## Backoff with jitter

Retrying immediately after a failure usually fails again: the server that answered 503 is still overloaded a millisecond later. Wait, and wait longer each time: **exponential backoff**. With a base of 0.5 seconds the delays are 0.5, 1, 2, 4 seconds, and a cap stops them from growing past what a user will tolerate.

Exponential backoff alone has a problem. When a server goes down, thousands of phones fail within the same second. With identical delays they all retry at +0.5 s, again at +1.5 s, again at +3.5 s, in synchronized waves that knock the server over each time it gets back up: a **thundering herd**. **Jitter** fixes it by randomizing each delay. A common form, "full jitter", picks a random delay between zero and the exponential value.

Randomness makes tests impossible to pin down, so the random part is a parameter:

```swift
struct Backoff {
    var baseMilliseconds = 500
    var capMilliseconds = 8_000

    /// The ceiling for an attempt: base × 2^(attempt − 1), capped.
    func ceiling(forAttempt attempt: Int) -> Int {
        let exponential = baseMilliseconds << min(attempt - 1, 20)
        return min(exponential, capMilliseconds)
    }

    /// Full jitter: a delay between 0 and the ceiling. `random` returns a value in 0...1.
    func delay(forAttempt attempt: Int, random: () -> Double) -> Int {
        Int(Double(ceiling(forAttempt: attempt)) * random())
    }
}

let backoff = Backoff()
for attempt in 1...6 {
    let ceiling = backoff.ceiling(forAttempt: attempt)
    let jittered = backoff.delay(forAttempt: attempt) { 0.25 }
    print("attempt \(attempt): ceiling \(ceiling) ms, with jitter 0.25: \(jittered) ms")
}

var generator = SystemRandomNumberGenerator()
let real = backoff.delay(forAttempt: 3) { Double.random(in: 0...1, using: &generator) }
print("a real delay for attempt 3 is between 0 and 2000 ms: \((0...2_000).contains(real))")
```


```output
attempt 1: ceiling 500 ms, with jitter 0.25: 125 ms
attempt 2: ceiling 1000 ms, with jitter 0.25: 250 ms
attempt 3: ceiling 2000 ms, with jitter 0.25: 500 ms
attempt 4: ceiling 4000 ms, with jitter 0.25: 1000 ms
attempt 5: ceiling 8000 ms, with jitter 0.25: 2000 ms
attempt 6: ceiling 8000 ms, with jitter 0.25: 2000 ms
a real delay for attempt 3 is between 0 and 2000 ms: true
```

- `baseMilliseconds << (attempt - 1)` doubles per attempt: shifting left by one bit multiplies by two. The `min(…, 20)` keeps a large attempt number from overflowing the shift before the cap applies.
- The cap (8 seconds here) is what stops attempt 6 from waiting 16 seconds, attempt 7 from waiting 32, and so on. For a screen someone is looking at, a total of more than 10 to 20 seconds across all attempts is too long; show an error with a Retry button instead.
- In production `random` is `Double.random(in: 0...1)`. In a test it's a constant, so the delays are exact.
- Full jitter can produce a delay near zero. That's fine: on average it waits half the ceiling, and the spread is what protects the server.

## Retry-After

When a server knows how long you should wait, it says so. RFC 9110, section 10.2.3: "Servers send the 'Retry-After' header field to indicate how long the user agent ought to wait before making a follow-up request." The value has two forms:

```text
Retry-After: 120
Retry-After: Fri, 31 Dec 1999 23:59:59 GMT
```

The first is a number of seconds; the second is an HTTP date. RFC 6585 says a 429 response "MAY include a Retry-After header", and it's common with 503. If it's present, it beats your own backoff, within a limit you choose: a server asking you to wait an hour shouldn't keep a spinner running for an hour.

```swift
import Foundation

func retryAfterSeconds(_ value: String?, now: Date) -> Int? {
    guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
        return nil
    }
    if let seconds = Int(value) {
        return seconds >= 0 ? seconds : nil
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    guard let date = formatter.date(from: value) else {
        return nil
    }
    return max(0, Int(date.timeIntervalSince(now).rounded(.up)))
}

let now = ISO8601DateFormatter().date(from: "2026-03-15T12:00:00Z")!
let values: [String?] = ["120", "Sun, 15 Mar 2026 12:01:30 GMT", "Sun, 15 Mar 2026 11:00:00 GMT", "-5", "soon", nil]
for value in values {
    let seconds = retryAfterSeconds(value, now: now)
    print("\(value ?? "(no header)") -> \(seconds.map { "\($0) s" } ?? "ignore")")
}
```

```output
120 -> 120 s
Sun, 15 Mar 2026 12:01:30 GMT -> 90 s
Sun, 15 Mar 2026 11:00:00 GMT -> 0 s
-5 -> ignore
soon -> ignore
(no header) -> ignore
```

- The number form is tried first because it's by far the most common.
- An HTTP date is parsed with a fixed format, the POSIX locale (so the user's language settings don't change how `Sun` and `Mar` are read) and the GMT time zone. A `DateFormatter` is expensive to create; in an app, keep one in a `static let`.
- A date in the past means "you can retry now": `0`.
- `now` is a parameter so the function can be tested; in the client it's `Date()`.
- Anything unparseable is ignored, and the client falls back to its own backoff.

## The retry loop

Now the pieces go together. The loop needs to:

1. Check for cancellation before every attempt.
2. Send the request; map any failure to a `NetworkError`.
3. Stop if the error isn't retryable, the method isn't idempotent, or it's out of attempts.
4. Wait for `Retry-After` if present (giving up if it's longer than the policy allows), otherwise for the jittered backoff.
5. Treat a cancelled wait as cancellation, not as one more failure.

Waiting is done through an injected `sleep` function. Production passes `Task.sleep`; the test passes a function that records the delay and returns immediately, so a test of five retries doesn't take ten seconds.

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum NetworkError: Error, Equatable {
    case cancelled, offline, timedOut, notFound, rateLimited
    case transport(Int)
    case server(status: Int)
    case client(status: Int)

    init(_ error: any Error) {
        switch error {
        case let error as NetworkError: self = error
        case is CancellationError: self = .cancelled
        case let error as URLError where error.code == .cancelled: self = .cancelled
        case let error as URLError where error.code == .notConnectedToInternet: self = .offline
        case let error as URLError where error.code == .timedOut: self = .timedOut
        case let error as URLError: self = .transport(error.code.rawValue)
        default: self = .transport(0)
        }
    }

    init?(status: Int) {
        switch status {
        case 200..<300: return nil
        case 404: self = .notFound
        case 429: self = .rateLimited
        case 500..<600: self = .server(status: status)
        default: self = .client(status: status)
        }
    }

    var isTransient: Bool {
        switch self {
        case .timedOut, .rateLimited: true
        case .server(let status): [500, 502, 503, 504].contains(status)
        case .client(let status): status == 408
        case .transport(let code): [URLError.networkConnectionLost, .cannotConnectToHost].map(\.rawValue).contains(code)
        case .cancelled, .offline, .notFound: false
        }
    }
}

struct Backoff: Sendable {
    var baseMilliseconds = 500
    var capMilliseconds = 8_000

    func delay(forAttempt attempt: Int, random: Double) -> Int {
        let ceiling = min(baseMilliseconds << min(attempt - 1, 20), capMilliseconds)
        return Int(Double(ceiling) * random)
    }
}

struct RetryingClient: Sendable {
    let transport: any HTTPTransport
    var maxAttempts = 4
    var maxRetryAfterSeconds = 30
    var backoff = Backoff()
    var random: @Sendable () -> Double = { Double.random(in: 0...1) }
    var sleep: @Sendable (_ milliseconds: Int) async throws -> Void = { try await Task.sleep(for: .milliseconds($0)) }

    func data(for request: URLRequest) async throws(NetworkError) -> Data {
        let idempotent = ["GET", "HEAD", "PUT", "DELETE", "OPTIONS"].contains(request.httpMethod ?? "GET")
        var attempt = 0
        while true {
            attempt += 1
            let failure: NetworkError
            var retryAfter: Int? = nil
            do {
                try Task.checkCancellation()
                let (data, response) = try await transport.send(request)
                guard let error = NetworkError(status: response.statusCode) else {
                    return data
                }
                failure = error
                retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            } catch {
                failure = NetworkError(error)
            }

            guard idempotent, failure.isTransient, attempt < maxAttempts else {
                throw failure
            }
            let delay: Int
            if let retryAfter {
                guard retryAfter <= maxRetryAfterSeconds else { throw failure }
                delay = retryAfter * 1_000
            } else {
                delay = backoff.delay(forAttempt: attempt, random: random())
            }
            print("  attempt \(attempt): \(failure), waiting \(delay) ms")
            do {
                try await sleep(delay)
            } catch {
                throw .cancelled
            }
        }
    }
}

/// Plays back a script of responses, one per call.
actor ScriptedServer: HTTPTransport {
    enum Step {
        case status(Int, retryAfter: String? = nil)
        case failure(URLError.Code)
    }
    private var script: [Step]
    private(set) var calls = 0

    init(_ script: [Step]) {
        self.script = script
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls += 1
        let step = script.isEmpty ? .status(503) : script.removeFirst()
        switch step {
        case .failure(let code):
            throw URLError(code)
        case .status(let status, let retryAfter):
            let headers = retryAfter.map { ["Retry-After": $0] }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (Data("ok".utf8), response)
        }
    }
}

func run(_ name: String, method: String = "GET", _ script: [ScriptedServer.Step]) async {
    print(name)
    let server = ScriptedServer(script)
    let client = RetryingClient(transport: server, random: { 0.5 }, sleep: { _ in })
    var request = URLRequest(url: URL(string: "https://api.example.com/v1/books")!)
    request.httpMethod = method
    do {
        let data = try await client.data(for: request)
        print("  success: \(String(decoding: data, as: UTF8.self)) after \(await server.calls) calls")
    } catch {
        print("  gave up: \(error) after \(await server.calls) calls")
    }
}

await run("busy, then a timeout, then fine", [.status(503, retryAfter: "2"), .failure(.timedOut), .status(200)])
await run("not found", [.status(404)])
await run("POST that timed out", method: "POST", [.failure(.timedOut)])
await run("down for good", [])
await run("rate limited for two minutes", [.status(429, retryAfter: "120")])
```

```output
busy, then a timeout, then fine
  attempt 1: server(status: 503), waiting 2000 ms
  attempt 2: timedOut, waiting 500 ms
  success: ok after 3 calls
not found
  gave up: notFound after 1 calls
POST that timed out
  gave up: timedOut after 1 calls
down for good
  attempt 1: server(status: 503), waiting 250 ms
  attempt 2: server(status: 503), waiting 500 ms
  attempt 3: server(status: 503), waiting 1000 ms
  gave up: server(status: 503) after 4 calls
rate limited for two minutes
  gave up: rateLimited after 1 calls
```

What to notice:

- **`throws(NetworkError)`** (typed throws, Module 12, lesson 4) promises callers they'll only ever see the app's error type. The `do`/`catch` inside maps everything else, and `throw .cancelled` can use the short form because the type is known. In `run`, the untyped `catch` still receives a `NetworkError`.
- **One `failure` variable for both paths.** A thrown error and a bad status end up in the same place, so the decision logic is written once.
- **`Retry-After: 2` overrode the backoff** for the first retry. The second retry, after a timeout with no header, used the backoff: attempt 2's ceiling is 1,000 ms, times the test's fixed random value of 0.5.
- **The POST gave up after one call** even though a timeout is transient: the server may have done the work.
- **Two minutes is longer than the 30-second limit**, so the client gave up right away with `.rateLimited`, and the UI can tell the user to come back later.
- This loop parses only the number form of `Retry-After` to keep the example short. A production client would use `retryAfterSeconds(_:now:)` from the previous section.
- The `print` calls inside the client are there to show the schedule. A real client would log through `Logger` (Module 21), without the request's headers (lesson 5).

## Cancellation stops everything

Cancellation has to win over retrying. If the user leaves the screen during the 4-second wait before attempt 3, the loop must stop, not make attempt 3. Three things in the loop make that happen:

- `try Task.checkCancellation()` at the top of each attempt, so a cancelled task never sends another request.
- The default `sleep` is `Task.sleep`, which throws `CancellationError` as soon as the task is cancelled (Module 29, lesson 3), instead of finishing the wait.
- `NetworkError(error)` maps both `CancellationError` and `URLError.cancelled` to `.cancelled`, and `.cancelled` isn't transient, so it's never retried.

The classic bug is `try? await Task.sleep(...)` inside the loop: the sleep throws on cancellation, `try?` swallows it, and the loop makes its next attempt anyway. Here's the real `Task.sleep` with the task cancelled during the wait:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

actor AlwaysBusy: HTTPTransport {
    private(set) var calls = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls += 1
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
    }
}

enum LoadError: Error {
    case cancelled
    case gaveUp(status: Int)
}

func loadWithRetries(_ transport: any HTTPTransport, swallowCancellation: Bool) async throws(LoadError) -> Data {
    let request = URLRequest(url: URL(string: "https://api.example.com/v1/feed")!)
    var lastStatus = 0
    for _ in 1...3 {
        if !swallowCancellation && Task.isCancelled {
            throw .cancelled
        }
        guard let (data, response) = try? await transport.send(request) else {
            continue
        }
        if response.statusCode == 200 {
            return data
        }
        lastStatus = response.statusCode
        if swallowCancellation {
            try? await Task.sleep(for: .seconds(10))
        } else {
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                throw .cancelled
            }
        }
    }
    throw .gaveUp(status: lastStatus)
}

for swallow in [false, true] {
    let server = AlwaysBusy()
    let task = Task {
        try await loadWithRetries(server, swallowCancellation: swallow)
    }
    try await Task.sleep(for: .milliseconds(200))
    task.cancel()
    let outcome: String
    do {
        _ = try await task.value
        outcome = "loaded"
    } catch LoadError.cancelled {
        outcome = "stopped: cancelled"
    } catch {
        outcome = "finished: \(error)"
    }
    print("swallowCancellation \(swallow): \(outcome) after \(await server.calls) call(s)")
}
```

```output
swallowCancellation false: stopped: cancelled after 1 call(s)
swallowCancellation true: finished: gaveUp(status: 503) after 3 call(s)
```

With proper handling, the cancel arrives during the first 10-second wait, the sleep throws, and the loop stops after one call. With `try?`, the cancelled sleep returns immediately (it doesn't wait, it just reports cancellation into the void), so the loop fires the remaining two attempts back to back and reports a failure for a screen that no longer exists. The program finishes in about 0.4 seconds, not 20, because a cancelled `Task.sleep` never waits.

In the view, `.cancelled` maps to "show nothing", via `userMessage` from earlier. A SwiftUI `.task` or a view controller that cancels its task in `viewDidDisappear` (Module 29, lesson 3) then cleans up every in-flight request and pending retry for free.

## Common mistakes

> [!error] Retrying everything
> A 400, 403, 404 or a decoding error gives the same answer every time. Retrying them adds load and delay and hides the bug. Keep an explicit list of transient failures.

> [!error] Retrying a POST after a timeout
> The server may have done the work, and a retry creates a duplicate. Retry only idempotent methods, or use an idempotency key the API supports.

> [!error] Backoff without jitter or without a cap
> Without jitter, clients retry in synchronized waves. Without a cap, the sixth attempt waits 16 seconds and the tenth over four minutes.

> [!error] Ignoring Retry-After
> The server told you when it can take the request. Retrying earlier just gets you another 429, and some APIs extend the penalty.

> [!error] try? await Task.sleep in a retry loop
> Cancellation is swallowed, and the loop keeps going without waiting. Use `try` and treat the error as cancellation.

> [!error] Showing an alert for a cancelled request
> `URLError.cancelled` and `CancellationError` mean "nobody wants this anymore". Map them to a case the UI ignores.

> [!error] Showing error.localizedDescription
> The text comes from the system, may be vague or technical, and differs by OS version and language. Map to your own cases and messages.

## Exercises

````exercise
id: m30-l04-e1
type: prediction
prompt: "A mapping function and a retry decision. What does the program print?"
code: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  enum Failure {
      case cancelled, offline, timedOut, other
  }

  func map(_ error: any Error) -> Failure {
      if error is CancellationError { return .cancelled }
      guard let urlError = error as? URLError else { return .other }
      switch urlError.code {
      case .cancelled: return .cancelled
      case .notConnectedToInternet: return .offline
      case .timedOut: return .timedOut
      default: return .other
      }
  }

  func decision(for error: any Error, method: String) -> String {
      switch (map(error), method) {
      case (.cancelled, _): return "stop silently"
      case (.offline, _): return "show offline"
      case (.timedOut, "GET"), (.timedOut, "PUT"): return "retry"
      case (.timedOut, _): return "ask the user"
      case (.other, _): return "show error"
      }
  }

  print(decision(for: URLError(.timedOut), method: "GET"))
  print(decision(for: URLError(.timedOut), method: "POST"))
  print(decision(for: URLError(.cancelled), method: "POST"))
  print(decision(for: CancellationError(), method: "GET"))
  print(decision(for: URLError(.notConnectedToInternet), method: "PUT"))
  print(decision(for: URLError(.badURL), method: "GET"))
output: |
  retry
  ask the user
  stop silently
  stop silently
  show offline
  show error
solution: |
  The `switch` over a tuple matches the mapped failure and the method together, top to bottom:

  - A timed-out `GET` matches `(.timedOut, "GET")`: retry.
  - A timed-out `POST` falls to `(.timedOut, _)`. The order may have been placed, so the app asks instead of retrying.
  - `URLError(.cancelled)` and `CancellationError()` both map to `.cancelled`, whatever the method.
  - Offline is shown as such, for any method.
  - `.badURL` maps to `.other`: a bug, not something to retry.

  ```output
  retry
  ask the user
  stop silently
  stop silently
  show offline
  show error
  ```
````

````exercise
id: m30-l04-e2
type: prediction
prompt: "A backoff with a base of 300 ms and a cap of 2,000 ms, with the random value fixed at 1.0 (no jitter) and then at 0.5. What does the program print?"
code: |
  func delay(attempt: Int, base: Int, cap: Int, random: Double) -> Int {
      let ceiling = min(base << (attempt - 1), cap)
      return Int(Double(ceiling) * random)
  }

  for attempt in 1...5 {
      let full = delay(attempt: attempt, base: 300, cap: 2_000, random: 1.0)
      let half = delay(attempt: attempt, base: 300, cap: 2_000, random: 0.5)
      print("\(attempt): \(full) / \(half)")
  }
output: |
  1: 300 / 150
  2: 600 / 300
  3: 1200 / 600
  4: 2000 / 1000
  5: 2000 / 1000
solution: |
  The ceiling doubles from the base: 300, 600, 1200, 2400, 4800. The cap of 2000 cuts attempts 4 and 5 to 2000. With `random` at 1.0 the delay is the ceiling; at 0.5 it's half of it.

  ```output
  1: 300 / 150
  2: 600 / 300
  3: 1200 / 600
  4: 2000 / 1000
  5: 2000 / 1000
  ```

  The sum of the full delays for four retries is 300 + 600 + 1200 + 2000 = 4.1 seconds, a reasonable budget for an interactive screen. With full jitter in production, the expected total is about half that.
````

````exercise
id: m30-l04-e3
type: comprehension
multiple: true
prompt: "A GET request fails. In which of these cases should the client retry automatically? Select all that apply."
choices:
  - text: "503 Service Unavailable with Retry-After: 3"
    correct: true
    why: "Transient, and the server said when to come back. Wait 3 seconds."
  - text: "URLError with code .networkConnectionLost"
    correct: true
    why: "The connection dropped mid-request; a new attempt may succeed."
  - text: "422 Unprocessable Content"
    correct: false
    why: "The server understood the request and rejected its content. The same request gets the same answer."
  - text: "A DecodingError: keyNotFound for price"
    correct: false
    why: "The server sent the bytes successfully; they'll be the same next time. This is a bug to log."
  - text: "URLError with code .cancelled"
    correct: false
    why: "Someone cancelled it. Stop."
  - text: "429 Too Many Requests with Retry-After: 3600"
    correct: false
    why: "Transient, but an hour is far past what an interactive client should wait. Give up and tell the user to try later."
solution: |
  Retry when the failure is transient **and** the wait is reasonable: the 503 with a 3-second Retry-After and the dropped connection. Content errors (422), decoding errors and cancellation are deterministic or deliberate. The 429 is transient in principle, but the client's maximum wait should turn a one-hour Retry-After into an immediate "try again later".
````

````exercise
id: m30-l04-e4
type: solve
prompt: "Write `func withRetries<T: Sendable>(maxAttempts: Int, delays: [Int], sleep: @Sendable (Int) async throws -> Void, isRetryable: @Sendable (any Error) -> Bool, operation: @Sendable () async throws -> T) async throws -> T`. It calls `operation`; on a retryable error it sleeps `delays[attempt - 1]` milliseconds (or the last delay if the array is shorter) and tries again, up to `maxAttempts` calls in total. A non-retryable error, or the last failure, is rethrown. It checks for cancellation before every attempt and must never retry `CancellationError`. Test it with an actor that fails a given number of times with `URLError(.timedOut)` and an actor that records the sleeps; print the result, the number of calls and the recorded delays for two failures, and for five failures with `maxAttempts: 3`."
starter: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  // Write withRetries and the two test actors here.
rubric:
  - The loop makes at most maxAttempts calls and rethrows the last error.
  - The delay uses the attempt index, falling back to the last delay.
  - Task.checkCancellation() runs before every attempt, and CancellationError is never retried.
  - Sleeping goes through the injected function, so the test doesn't wait.
  - The test actors make the call count and delays observable.
solution: |
  ```swift
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  func withRetries<T: Sendable>(
      maxAttempts: Int,
      delays: [Int],
      sleep: @Sendable (Int) async throws -> Void,
      isRetryable: @Sendable (any Error) -> Bool,
      operation: @Sendable () async throws -> T
  ) async throws -> T {
      precondition(maxAttempts >= 1 && !delays.isEmpty)
      var attempt = 1
      while true {
          try Task.checkCancellation()
          do {
              return try await operation()
          } catch is CancellationError {
              throw CancellationError()
          } catch where attempt < maxAttempts && isRetryable(error) {
              try await sleep(delays[min(attempt, delays.count) - 1])
              attempt += 1
          }
      }
  }

  actor FlakyService {
      private var failuresLeft: Int
      private(set) var calls = 0

      init(failures: Int) {
          failuresLeft = failures
      }

      func fetch() throws -> String {
          calls += 1
          if failuresLeft > 0 {
              failuresLeft -= 1
              throw URLError(.timedOut)
          }
          return "data"
      }
  }

  actor SleepLog {
      private(set) var delays: [Int] = []
      func record(_ milliseconds: Int) {
          delays.append(milliseconds)
      }
  }

  for (failures, maxAttempts) in [(2, 4), (5, 3)] {
      let service = FlakyService(failures: failures)
      let log = SleepLog()
      let result: String
      do {
          result = try await withRetries(
              maxAttempts: maxAttempts,
              delays: [100, 200, 400],
              sleep: { await log.record($0) },
              isRetryable: { ($0 as? URLError)?.code == .timedOut },
              operation: { try await service.fetch() }
          )
      } catch let error as URLError where error.code == .timedOut {
          result = "timed out"
      }
      print("\(failures) failures, \(maxAttempts) attempts: \(result), calls \(await service.calls), sleeps \(await log.delays)")
  }
  ```

  ```output
  2 failures, 4 attempts: data, calls 3, sleeps [100, 200]
  5 failures, 3 attempts: timed out, calls 3, sleeps [100, 200]
  ```

  `catch where attempt < maxAttempts && isRetryable(error)` catches only errors you intend to retry while attempts remain; everything else, including the final failure, propagates unchanged (the same shape as Module 12's `retry`). The `catch is CancellationError` clause comes first so cancellation can never be retried, even if a careless `isRetryable` returned `true` for everything. In production, `sleep` is `{ try await Task.sleep(for: .milliseconds($0)) }`, which throws when the task is cancelled and ends the loop.
````

````exercise
id: m30-l04-e5
type: find-errors
prompt: "A teammate's retry helper for the checkout screen. Which are real problems?"
code: |
  func submitOrder(_ request: URLRequest, session: URLSession) async -> Data? {
      for attempt in 0..<10 {
          do {
              let (data, response) = try await session.data(for: request)
              if (response as? HTTPURLResponse)?.statusCode == 200 {
                  return data
              }
          } catch {
              print("attempt \(attempt) failed: \(error.localizedDescription)")
          }
          try? await Task.sleep(for: .seconds(1 << attempt))
      }
      return nil
  }
choices:
  - text: "It retries a POST (submitting an order) without an idempotency key, which can create duplicate orders."
    correct: true
    why: "A timeout doesn't mean the order wasn't created."
  - text: "It retries every failure, including 400, 404 and cancellation."
    correct: true
    why: "Only transient failures should be retried."
  - text: "try? on Task.sleep swallows cancellation, so a cancelled checkout keeps retrying with no wait."
    correct: true
    why: "Use try and stop on CancellationError."
  - text: "The delay has no cap and no jitter: the last wait is 512 seconds, and every client waits the same."
    correct: true
    why: "Cap it and randomize it."
  - text: "Returning nil throws away the reason for the failure, so the UI can't show the right message."
    correct: true
    why: "Throw a NetworkError instead."
  - text: "1 << attempt is the wrong way to compute powers of two."
    correct: false
    why: "Shifting left by n multiplies by 2^n; it's a standard way to compute it."
rubric:
  - Finds retrying a non-idempotent POST.
  - Finds retrying every failure.
  - Finds swallowed cancellation.
  - Finds the missing cap and jitter.
  - Finds the lost error information.
solution: |
  Rewritten: send the order once (or with an idempotency key the API honors, reused on each retry), retry only transient failures, use `try await Task.sleep` with capped, jittered delays, check `Task.checkCancellation()` before each attempt, honor `Retry-After`, and `throw` a `NetworkError` so the checkout screen can say "You're offline" or "Your order may have gone through; check your orders" instead of a generic failure. Ten attempts is also far too many for a screen the user is looking at; three or four is typical.
````

````exercise
id: m30-l04-e6
type: fill-in
prompt: "Complete the view model so a cancelled load shows nothing and other failures show the mapped message."
code: |
  @MainActor
  final class ArticleViewModel {
      var article: Article?
      var message: String?

      func load(using client: ArticleClient) async {
          do {
              article = try await client.article()
          } catch NetworkError.[[1]] {
              return
          } catch let error [[2]] NetworkError {
              message = error.[[3]]
          } catch {
              message = "Something went wrong."
          }
      }
  }
blanks:
  - id: "1"
    answers: ["cancelled"]
  - id: "2"
    answers: ["as"]
  - id: "3"
    answers: ["userMessage"]
solution: |
  `catch NetworkError.cancelled { return }` matches the one case to ignore, `catch let error as NetworkError` binds the app's error type, and `error.userMessage` is the message chosen in the lesson. The catch-all at the end is needed because `client.article()` uses untyped `throws`; if it were declared `throws(NetworkError)`, the compiler would know the second clause is exhaustive and the last `catch` could go.
````

## Summary

- Map every failure at the client boundary into one app error type: `URLError` codes, HTTP statuses and `DecodingError` paths go in, a few meaningful cases come out. Cancellation (both `CancellationError` and `URLError.cancelled`) becomes one case the UI ignores.
- Retry only transient failures (timeouts, dropped connections, 408, 429, 500, 502, 503, 504) and only idempotent requests. Never retry 4xx content errors, decoding errors or cancellation.
- Wait with capped exponential backoff and jitter; inject the random value and the sleep so tests are exact and instant.
- Honor `Retry-After` (seconds or an HTTP date) within a maximum you're willing to wait.
- Check cancellation before each attempt, sleep with `try await Task.sleep`, and never `try?` the sleep.
- Show users messages you wrote, not `localizedDescription`.
