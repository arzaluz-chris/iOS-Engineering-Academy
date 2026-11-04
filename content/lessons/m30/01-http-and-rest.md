---
id: m30-l01
title: HTTP and REST
description: "What actually travels between your app and a server. You learn the parts of an HTTP request and response, which methods are safe and idempotent and why that decides what you may retry, the five status code classes, the headers an app client sets and reads, how REST APIs name resources, when data goes in the query string and when in the body, and how to build all of it in Swift with URLComponents and URLRequest."
module: m30
order: 1
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l06]
objectives:
  - Name the parts of an HTTP request (method, target, headers, body) and response (status, headers, body).
  - Classify methods as safe and idempotent, and explain why that decides whether a request can be retried.
  - Read a status code by its class and pick the right reaction for the common codes.
  - Set and read the headers an app client uses most (Accept, Content-Type, Authorization, Retry-After), knowing names are case-insensitive.
  - Design REST paths around resources, and choose between the query string and the body.
  - Build requests with URLComponents and URLRequest instead of string concatenation.
terms:
  - term: Safe method
    definition: "A method whose meaning is read-only: the client asks for no change on the server. GET, HEAD, OPTIONS and TRACE (RFC 9110, section 9.2.1)."
  - term: Idempotent method
    definition: "A method where sending the same request several times has the same intended effect as sending it once. PUT, DELETE and every safe method (RFC 9110, section 9.2.2). POST and PATCH aren't."
  - term: Status code class
    definition: "The first digit of the three-digit status code: 1xx informational, 2xx success, 3xx redirection, 4xx client error, 5xx server error. A client must understand the class even when it doesn't know the exact code."
  - term: Resource
    definition: "A thing the API exposes at a URL, such as /books/42. REST APIs name resources with nouns and use the method to say what to do with them."
  - term: Query string
    definition: "The part of the URL after ?, made of name=value pairs. Used to filter, sort and page a GET; it shows up in logs and history, so it never carries secrets."
  - term: URLComponents
    definition: "A Foundation type that builds a URL from its parts (scheme, host, path, query items) and percent-encodes each part correctly."
mastery:
  - Look at a request and say whether it's safe to send twice.
  - Map a list of status codes to their class and to what the app should do.
  - Build a GET with query parameters and a POST with a JSON body using URLComponents and URLRequest.
  - Sketch the endpoints of a small REST API for a feature, with methods, paths and expected status codes.
  - Explain why a header lookup must ignore case and why query strings never carry tokens.
resources: [swift-book-enumerations, apple-documentation]
cards:
  - id: m30-l01-c1
    front: Which HTTP methods are idempotent?
    back: "GET, HEAD, OPTIONS, TRACE (the safe ones), plus PUT and DELETE. Repeating them has the same intended effect as sending once. POST and PATCH aren't idempotent."
  - id: m30-l01-c2
    front: The five status code classes?
    back: "1xx informational, 2xx success, 3xx redirection, 4xx client error (your request is wrong), 5xx server error (the server failed on a valid request)."
  - id: m30-l01-c3
    front: Query string or body?
    back: "Query: filters, sorting and paging for a GET; visible in logs, never secrets. Body: the data you create or change (POST, PUT, PATCH), with a Content-Type header saying its format."
  - id: m30-l01-c4
    front: Are HTTP header names case-sensitive?
    back: "No. Content-Type and content-type are the same field. URLRequest and HTTPURLResponse lookups with value(forHTTPHeaderField:) ignore case; a plain dictionary lookup doesn't."
  - id: m30-l01-c5
    front: Why build URLs with URLComponents?
    back: "It percent-encodes each part for you. Interpolating user input into a URL string breaks on spaces and lets characters like & and # change the URL's structure."
---

## The idea in one sentence

An app talks to a server by sending a request (a method, a URL, some headers and maybe a body) and getting back a response (a status code, headers and maybe a body), and almost every networking decision you'll make later depends on reading those few fields correctly.

> [!note] Where this module is going
> This lesson is the protocol. Lesson 2 decodes the JSON in the body, lesson 3 sends requests with `URLSession` and `async`/`await` (Module 29), lesson 4 handles failures and retries, lesson 5 adds pagination and authentication, and lesson 6 puts it behind a repository you can test. None of the runnable code in this module touches the real network: it builds requests and checks them, or feeds canned responses into the code under test. That's also how you'll test networking code at work.

## A request and a response

HTTP is a text protocol over a connection (HTTP/1.1), or a binary framing of the same messages (HTTP/2 and HTTP/3). The framing changes; the **semantics** don't. RFC 9110 defines them, and every version shares them. A request to list a reader's books looks like this on the wire with HTTP/1.1:

```text
GET /v1/books?sort=title&page=2 HTTP/1.1
Host: api.example.com
Accept: application/json
Authorization: Bearer eyJhbGciOi...
```

And the response:

```text
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: max-age=60

{"items": [{"id": 42, "title": "The Dispossessed"}], "page": 2}
```

The request has a **method** (`GET`), a **target** (the path and query), **headers** (name–value pairs) and an optional **body**. The response has a **status code** (`200`) with a reason phrase (`OK`, which clients should ignore), headers and an optional body. A blank line separates the headers from the body.

Everything else in this module is about these fields: which method, which URL, which headers, what to do with which status.

## Methods: safe and idempotent

RFC 9110 sorts methods by two properties that matter far more than their names.

A **safe** method is read-only by meaning: "the client does not request, and does not expect, any state change on the origin server". The server may still write a log line; what matters is that the client didn't ask for a change.

An **idempotent** method can be repeated: "the intended effect on the server of multiple identical requests with that method is the same as the effect for a single such request." The RFC lists them: "PUT, DELETE, and safe request methods are idempotent."

| Method | Typical use | Safe | Idempotent |
| --- | --- | --- | --- |
| GET | Read a resource or a list | yes | yes |
| HEAD | Like GET, headers only | yes | yes |
| POST | Create something, or run an action | no | no |
| PUT | Replace a resource with the body | no | yes |
| PATCH | Change some fields of a resource | no | no |
| DELETE | Remove a resource | no | yes |

Why you care: **the network can fail after the server did the work.** The phone sends `POST /orders`, the server creates the order, and the response is lost when the train goes into a tunnel. Your app sees a timeout. If it retries a `GET` or a `PUT`, nothing bad happens: reading twice is harmless, and replacing a resource with the same data twice leaves it the same. Retrying the `POST` may create a second order. Lesson 4 builds the retry logic on top of this table.

`DELETE` is idempotent even though the second call usually returns `404 Not Found`: the *effect* (the resource is gone) is the same. Idempotency is about the server's state, not about getting the same response.

Making the table executable is a good use of an enum with computed properties (Module 9):

```swift
enum HTTPMethod: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var isSafe: Bool {
        self == .get || self == .head
    }

    var isIdempotent: Bool {
        switch self {
        case .get, .head, .put, .delete:
            return true
        case .post, .patch:
            return false
        }
    }
}

for method in [HTTPMethod.get, .post, .put, .patch, .delete] {
    let retry = method.isIdempotent ? "can retry" : "don't retry blindly"
    print("\(method.rawValue): safe \(method.isSafe), \(retry)")
}
```

```output
GET: safe true, can retry
POST: safe false, don't retry blindly
PUT: safe false, can retry
PATCH: safe false, don't retry blindly
DELETE: safe false, can retry
```

The `switch` in `isIdempotent` lists every case with no `default`, so adding `case options = "OPTIONS"` later makes the compiler point at this property until you decide.

> [!tip] Making a POST safe to retry
> Some APIs accept an idempotency key: the client generates a unique ID for one logical operation (one checkout), sends it in a header such as `Idempotency-Key`, and reuses it on retries. The server stores the first result under that key and returns it again instead of repeating the work. It's a server feature, not part of HTTP, so check whether your API supports it before relying on it.

## Status codes

The status is a three-digit number, and RFC 9110 gives the first digit a fixed meaning: "a client MUST understand the class of any status code, as indicated by the first digit, and treat an unrecognized status code as being equivalent to the x00 status code of that class". If a server invents `299`, you treat it as `200`.

| Class | Meaning | Codes you'll meet | What the app does |
| --- | --- | --- | --- |
| 1xx | Informational | 100 | Nothing; `URLSession` handles them |
| 2xx | Success | 200 OK, 201 Created, 204 No Content | Use the body (204 has none) |
| 3xx | Redirection | 301, 302, 304 Not Modified | `URLSession` follows redirects; 304 comes from caching |
| 4xx | Client error | 400, 401, 403, 404, 409, 422, 429 | Your request is wrong: fix, re-authenticate, or tell the user |
| 5xx | Server error | 500, 502, 503, 504 | The server failed: maybe retry later |

The 4xx codes worth knowing by heart:

- **400 Bad Request**: malformed request. A bug in your client, usually.
- **401 Unauthorized**: missing or expired credentials. Despite the name, it means *unauthenticated*; lesson 5 refreshes the token and tries once more.
- **403 Forbidden**: you're authenticated but not allowed. Don't retry, don't refresh.
- **404 Not Found**: no resource at this URL.
- **409 Conflict** and **422 Unprocessable Content**: the request is well-formed but conflicts with the server's state or fails validation. Show the message.
- **429 Too Many Requests** (RFC 6585): you're rate-limited. Wait, ideally as long as the `Retry-After` header says.

Classifying by range is a `switch` over `Int`:

```swift
enum StatusClass {
    case informational, success, redirection, clientError, serverError, invalid
}

func statusClass(of code: Int) -> StatusClass {
    switch code {
    case 100..<200: return .informational
    case 200..<300: return .success
    case 300..<400: return .redirection
    case 400..<500: return .clientError
    case 500..<600: return .serverError
    default: return .invalid
    }
}

for code in [200, 204, 299, 304, 401, 404, 429, 503, 42] {
    print(code, statusClass(of: code))
}
```

```output
200 success
204 success
299 success
304 redirection
401 clientError
404 clientError
429 clientError
503 serverError
42 invalid
```

> [!warning] 200 doesn't always mean "it worked"
> Some APIs return `200` with `{"error": "..."}` in the body. And `URLSession` doesn't treat 404 or 500 as an error at all: as far as it's concerned, the request completed and a response arrived. Lesson 3 checks the status explicitly, every time.

## Headers

Headers carry metadata about the message. The ones an app client deals with most:

| Header | Direction | Example | Purpose |
| --- | --- | --- | --- |
| `Accept` | request | `application/json` | The formats you can read |
| `Content-Type` | both | `application/json` | The format of this message's body |
| `Authorization` | request | `Bearer <token>` | Credentials (lesson 5) |
| `User-Agent` | request | `Bookshelf/2.3 iOS/18.0` | Who's calling; `URLSession` sets a default |
| `Cache-Control`, `ETag` | response | `max-age=60` | How long the body may be reused |
| `Retry-After` | response | `120` | How long to wait before trying again (lesson 4) |

**Header names are case-insensitive.** RFC 9110 says so, and Apple's documentation for `value(forHTTPHeaderField:)` repeats it: "In keeping with the HTTP RFC, HTTP header field names are case-insensitive." HTTP/2 even sends them all in lowercase. So always look headers up through `value(forHTTPHeaderField:)`, never by subscripting a `[String: String]` copy, where `"content-type"` and `"Content-Type"` are different keys.

## REST: resources and methods

REST is a style, not a standard, and most "REST APIs" follow a few conventions loosely. The useful core:

- **URLs name resources, with nouns.** `/books`, `/books/42`, `/books/42/reviews`. Not `/getBook?id=42` or `/createReview`.
- **The method says what to do.** `GET /books/42` reads, `PUT /books/42` replaces, `DELETE /books/42` removes, `POST /books/42/reviews` creates a review under that book.
- **Collections and items.** `GET /books` returns a list (usually a page of it, lesson 5). `POST /books` creates one and answers `201 Created`, often with the new resource's URL in a `Location` header.
- **Status codes carry the outcome**, and the body carries the data or an error description.
- **Version the API** in the path (`/v1/`) or a header, so the server can change without breaking shipped apps. Your app will be in people's pockets, unchanged, for years.

A small reading-list API in this style:

| Request | Meaning | Success |
| --- | --- | --- |
| `GET /v1/books?author=le-guin&page=2` | Page 2 of the books by an author | 200 |
| `GET /v1/books/42` | One book | 200, or 404 |
| `POST /v1/books/42/reviews` | Add a review | 201 |
| `PATCH /v1/reviews/7` | Change a review's rating | 200 |
| `DELETE /v1/reviews/7` | Delete a review | 204 |

### Query string or body?

- The **query string** narrows down what a `GET` returns: filters, sorting, paging, a search term. A `GET` has no meaningful body, so this is the only place for its parameters. Query strings end up in server logs, proxies and analytics, so they **never carry tokens, passwords or personal data**.
- The **body** carries the data you send: the review you're creating, the fields you're changing. Say what format it's in with `Content-Type`. JSON (`application/json`) is the norm for app APIs; form encoding (`application/x-www-form-urlencoded`) and `multipart/form-data` (file uploads) are the other two you'll meet.

## Building requests in Swift

Foundation gives you three types: `URLComponents` to build the URL, `URL` to hold it, and `URLRequest` to add the method, headers, body and per-request settings.

> [!note] import FoundationNetworking
> On Apple platforms, `URLRequest`, `URLSession`, `HTTPURLResponse` and `URLProtocol` are in Foundation. On Linux, where these lessons' code also runs, they live in a separate module, `FoundationNetworking`. Every block in this module that uses them starts with the same three lines after `import Foundation`: `#if canImport(FoundationNetworking)` / `import FoundationNetworking` / `#endif`. On iOS the condition is false and the lines do nothing; you won't write them in an app.

### A GET with query parameters

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

var components = URLComponents()
components.scheme = "https"
components.host = "api.example.com"
components.path = "/v1/books"
components.queryItems = [
    URLQueryItem(name: "author", value: "Ursula K. Le Guin"),
    URLQueryItem(name: "sort", value: "title"),
    URLQueryItem(name: "page", value: "2"),
]

guard let url = components.url else {
    fatalError("The components above always form a valid URL")
}

var request = URLRequest(url: url)
request.setValue("application/json", forHTTPHeaderField: "Accept")

print(request.httpMethod ?? "no method")
print(url.absoluteString)
print(request.value(forHTTPHeaderField: "accept") ?? "missing")
```

```output
GET
https://api.example.com/v1/books?author=Ursula%20K.%20Le%20Guin&sort=title&page=2
application/json
```

Line by line:

1. `URLComponents()` starts empty; you set the scheme, host and path separately. The path must start with `/` when there's a host.
2. `queryItems` is an array of `URLQueryItem`, so the order is kept and you can repeat a name (`tag=a&tag=b`). The spaces in the author's name are percent-encoded as `%20` when the URL is built.
3. `components.url` is optional: it's `nil` if the parts can't form a URL (a path without a leading `/` next to a host, for example). The `guard` documents that it can't fail here.
4. `URLRequest(url:)` defaults to `GET`; Apple's documentation for `httpMethod` says "The default HTTP method is 'GET'."
5. `setValue(_:forHTTPHeaderField:)` replaces any existing value; `addValue` appends to it.
6. The lookup with `"accept"` in lowercase still finds `Accept`.

### A POST with a JSON body

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct NewReview: Encodable {
    let rating: Int
    let text: String
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

var request = URLRequest(url: URL(string: "https://api.example.com/v1/books/42/reviews")!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.httpBody = try encoder.encode(NewReview(rating: 5, text: "Still holds up"))

print(request.httpMethod ?? "no method")
print(request.url?.path ?? "")
print(String(decoding: request.httpBody ?? Data(), as: UTF8.self))
```

```output
POST
/v1/books/42/reviews
{"rating":5,"text":"Still holds up"}
```

`Encodable` and `JSONEncoder` are lesson 2's subject; here they just turn a struct into JSON bytes. `.sortedKeys` makes the key order predictable, which you want in tests. The force-unwrapped `URL(string:)` is acceptable for a literal you wrote and know is valid; for anything built from input, use `URLComponents`.

### Why not string interpolation?

It's tempting to write `URL(string: "https://api.example.com/v1/search?q=\(query)")`. It works until the user searches for something with a reserved character in it. `&` separates query items, so a search for `salt&pepper` silently becomes two parameters:

```swift
import Foundation

let query = "salt&pepper"

let interpolated = URL(string: "https://api.example.com/v1/search?q=\(query)")!
let parsedBack = URLComponents(url: interpolated, resolvingAgainstBaseURL: false)?.queryItems ?? []
print("interpolated: \(parsedBack.count) items, q = \(parsedBack.first?.value ?? "nil")")

var components = URLComponents(string: "https://api.example.com/v1/search")!
components.queryItems = [URLQueryItem(name: "q", value: query)]
let built = components.url!
let builtBack = URLComponents(url: built, resolvingAgainstBaseURL: false)?.queryItems ?? []
print("components: \(builtBack.count) item, q = \(builtBack.first?.value ?? "nil")")
print(built.absoluteString)
```

```output
interpolated: 2 items, q = salt
components: 1 item, q = salt&pepper
https://api.example.com/v1/search?q=salt%26pepper
```

The server would have searched for `salt` and ignored a parameter called `pepper`. `#` is worse: everything after it becomes a fragment that isn't sent at all. Spaces depend on the OS: Apple's documentation says that for apps linked on or after iOS 17, `URL(string:)` "automatically percent- and IDNA-encodes invalid characters", while older systems return `nil`. `URLComponents` behaves the same everywhere.

> [!warning] A + in a query value
> `URLComponents` leaves `+` unencoded in query values, because `+` is a legal character there. Many servers decode `+` in a query as a space (a convention from HTML forms), so a search for `C++` can arrive as `C  `. If your server does that, encode `+` yourself as `%2B` in `percentEncodedQueryItems`, and test it against the real server.

## Reading a response

The response arrives as an `HTTPURLResponse` (lesson 3 shows where from). You can also make one yourself, which is how this module's tests fake a server:

```swift
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let url = URL(string: "https://api.example.com/v1/books/42")!
let response = HTTPURLResponse(
    url: url,
    statusCode: 503,
    httpVersion: "HTTP/1.1",
    headerFields: ["Content-Type": "application/json", "Retry-After": "120"]
)!

print(response.statusCode)
print(response.value(forHTTPHeaderField: "retry-after") ?? "no Retry-After")
print(response.value(forHTTPHeaderField: "Content-Type") ?? "no Content-Type")
print(response.value(forHTTPHeaderField: "ETag") ?? "no ETag")
```

```output
503
120
application/json
no ETag
```

`HTTPURLResponse(url:statusCode:httpVersion:headerFields:)` is a failable initializer; the force unwrap is fine for literal values in a test. Header values are always strings; turning `"120"` into a delay is lesson 4's job.

## Common mistakes

> [!error] Retrying a POST after a timeout
> A timeout doesn't tell you whether the server did the work. Retry only idempotent methods automatically; for a POST, use an idempotency key or ask the user.

> [!error] Treating every non-2xx the same
> 401 needs a token refresh, 403 needs a message, 404 may mean "show empty state", 429 and 503 mean "wait and retry", 400 means a bug. Classify first, then react.

> [!error] Building URLs by concatenating strings
> Spaces, `&`, `#` and non-ASCII characters break the URL or change its meaning. Use `URLComponents` and `queryItems`.

> [!error] Reading headers from a dictionary with a fixed spelling
> `headers["Content-Type"]` misses `content-type`, which is what HTTP/2 servers send. Use `value(forHTTPHeaderField:)`.

> [!error] Putting a token or email address in the query string
> URLs are logged by servers, proxies and analytics tools. Credentials go in the `Authorization` header, personal data in the body.

> [!error] Verbs in paths
> `/getBooks`, `/deleteReview?id=7`. Name the resource and let the method carry the verb: `GET /books`, `DELETE /reviews/7`.

## Exercises

````exercise
id: m30-l01-e1
type: prediction
prompt: "This function decides what an app should do with a status code. What does the program print?"
code: |
  func reaction(to status: Int) -> String {
      switch status {
      case 200..<300:
          return "use the body"
      case 401:
          return "refresh the token"
      case 429, 503:
          return "wait and retry"
      case 400..<500:
          return "show an error"
      case 500..<600:
          return "retry later"
      default:
          return "unexpected"
      }
  }

  for status in [204, 401, 403, 429, 500, 302] {
      print("\(status): \(reaction(to: status))")
  }
output: |
  204: use the body
  401: refresh the token
  403: show an error
  429: wait and retry
  500: retry later
  302: unexpected
solution: |
  A `switch` takes the **first** matching case, so the specific codes (`401`, `429`, `503`) have to come before the ranges that contain them:

  - `204` is in `200..<300`. (A real client would know a 204 has no body to use.)
  - `401` hits its own case before `400..<500`.
  - `403` isn't listed, so it falls into `400..<500`: show an error. That's right; refreshing a token doesn't help with "forbidden".
  - `429` matches the `429, 503` case.
  - `500` is in `500..<600`.
  - `302` matches nothing, so `default`. `URLSession` follows redirects itself, so you rarely see a 3xx in app code.

  ```output
  204: use the body
  401: refresh the token
  403: show an error
  429: wait and retry
  500: retry later
  302: unexpected
  ```

  If the `400..<500` case were first, `401` and `429` would never reach their own cases.
````

````exercise
id: m30-l01-e2
type: comprehension
multiple: true
prompt: "The connection drops before your app gets a response. Which of these requests can the app safely send again automatically, without any help from the server? Select all that apply."
choices:
  - text: "GET /v1/books/42"
    correct: true
    why: "Safe and idempotent: reading twice changes nothing."
  - text: "PUT /v1/books/42/progress with body {\"page\": 120}"
    correct: true
    why: "PUT replaces the resource with the body; doing it twice leaves the same state."
  - text: "DELETE /v1/reviews/7"
    correct: true
    why: "Idempotent. A second call may answer 404, but the effect (the review is gone) is the same."
  - text: "POST /v1/orders with the cart contents"
    correct: false
    why: "Not idempotent. If the first request reached the server, a retry can create a second order. Needs an idempotency key the server honors."
  - text: "PATCH /v1/accounts/me with body {\"credits\": \"+10\"}"
    correct: false
    why: "PATCH isn't idempotent in general, and this one is an increment: applying it twice adds 20."
solution: |
  Idempotent methods (GET, HEAD, OPTIONS, PUT, DELETE) have the same intended effect whether they arrive once or several times, so retrying after a lost response is harmless. POST and PATCH carry no such promise: the order could be created twice, the credits added twice. RFC 9110 defines idempotency by the effect on the server, not by the response, which is why DELETE qualifies even though the second answer may differ.
````

````exercise
id: m30-l01-e3
type: fill-in
prompt: "Complete the code so it builds `https://api.example.com/v1/books?q=swift%20concurrency&limit=20` and sends it as a GET that accepts JSON."
code: |
  var components = URLComponents(string: "https://api.example.com/v1/books")!
  components.[[1]] = [
      URLQueryItem(name: "q", value: "swift concurrency"),
      URLQueryItem(name: "limit", value: "20"),
  ]
  var request = URLRequest(url: components.[[2]]!)
  request.[[3]] = "GET"
  request.setValue("application/json", forHTTPHeaderField: "[[4]]")
blanks:
  - id: "1"
    answers: ["queryItems"]
  - id: "2"
    answers: ["url"]
  - id: "3"
    answers: ["httpMethod"]
  - id: "4"
    answers: ["Accept", "accept"]
solution: |
  ```swift
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  var components = URLComponents(string: "https://api.example.com/v1/books")!
  components.queryItems = [
      URLQueryItem(name: "q", value: "swift concurrency"),
      URLQueryItem(name: "limit", value: "20"),
  ]
  var request = URLRequest(url: components.url!)
  request.httpMethod = "GET"
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  print(request.url!.absoluteString)
  ```

  ```output
  https://api.example.com/v1/books?q=swift%20concurrency&limit=20
  ```

  `queryItems` takes the parameters, `url` builds the URL (optional, because some combinations of parts are invalid), `httpMethod` sets the method (`GET` is already the default, so that line only makes it explicit), and `Accept` says what format you want back. `Content-Type` would be wrong here: it describes the body you send, and a GET has none.
````

````exercise
id: m30-l01-e4
type: solve
prompt: "Write `func makeRatingRequest(bookID: Int, rating: Int) -> URLRequest` that builds a `PUT` to `https://api.example.com/v1/books/<bookID>/rating` with a JSON body `{\"rating\":<rating>}` and the headers `Content-Type: application/json` and `Accept: application/json`. Build the URL with URLComponents and the body with JSONEncoder. Call it with book 42 and rating 4 and print the method, the URL, the Content-Type header (looked up as `content-type`) and the body as a string."
starter: |
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  // Write makeRatingRequest(bookID:rating:) here.
rubric:
  - "The URL is built with URLComponents and the path includes the book ID."
  - "The method is PUT, which suits setting a value (idempotent)."
  - "Content-Type and Accept are both set."
  - "The body is encoded from a struct with JSONEncoder, not concatenated by hand."
  - "The printed header lookup uses a lowercase name and still finds the value."
solution: |
  ```swift
  import Foundation
  #if canImport(FoundationNetworking)
  import FoundationNetworking
  #endif

  struct RatingBody: Encodable {
      let rating: Int
  }

  func makeRatingRequest(bookID: Int, rating: Int) -> URLRequest {
      var components = URLComponents()
      components.scheme = "https"
      components.host = "api.example.com"
      components.path = "/v1/books/\(bookID)/rating"

      var request = URLRequest(url: components.url!)
      request.httpMethod = "PUT"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      request.httpBody = try? JSONEncoder().encode(RatingBody(rating: rating))
      return request
  }

  let request = makeRatingRequest(bookID: 42, rating: 4)
  print(request.httpMethod ?? "no method")
  print(request.url?.absoluteString ?? "no URL")
  print(request.value(forHTTPHeaderField: "content-type") ?? "missing")
  print(String(decoding: request.httpBody ?? Data(), as: UTF8.self))
  ```

  ```output
  PUT
  https://api.example.com/v1/books/42/rating
  application/json
  {"rating":4}
  ```

  `PUT` fits because "set my rating to 4" has the same result no matter how many times it arrives, so a lesson-4 retry is safe. A `POST /ratings` would create a new rating each time.

  The `try?` on encoding is acceptable here: encoding a struct with one `Int` can't fail. In a general-purpose builder you'd make the function `throws` instead, and the force unwrap of `components.url` is safe only because the path always starts with `/`.
````

````exercise
id: m30-l01-e5
type: find-errors
prompt: "A teammate wrote this endpoint list for a notes feature and the client code that searches notes. Which are real problems?"
code: |
  // Endpoints
  // GET    /v1/getNotes
  // POST   /v1/notes/42/delete
  // GET    /v1/notes?search=<text>&token=<access token>
  // PATCH  /v1/notes/42          body: {"title": "Groceries"}

  func searchURL(for text: String) -> URL? {
      URL(string: "https://api.example.com/v1/notes?search=\(text)")
  }

  func isSuccess(_ headers: [String: String]) -> Bool {
      headers["Content-Type"] == "application/json"
  }
choices:
  - text: "/v1/getNotes puts a verb in the path; GET /v1/notes already means \"get the notes\"."
    correct: true
    why: "Resources are nouns; the method is the verb."
  - text: "Deleting with POST /notes/42/delete hides an idempotent operation behind a non-idempotent method."
    correct: true
    why: "DELETE /v1/notes/42 is the conventional form and tells clients and proxies a retry is safe."
  - text: "The access token in the query string will end up in server and proxy logs."
    correct: true
    why: "Send it in the Authorization header."
  - text: "Interpolating the search text into the URL string breaks on &, # and (on older systems) spaces."
    correct: true
    why: "Use URLComponents with a URLQueryItem."
  - text: "isSuccess checks a header with a fixed spelling instead of the status code."
    correct: true
    why: "Success is in the status code. And a dictionary lookup is case-sensitive, so content-type would be missed."
  - text: "PATCH can't have a body."
    correct: false
    why: "PATCH sends the fields to change in its body; that's its purpose."
rubric:
  - Finds the verb paths (getNotes, /delete).
  - Finds the token in the query string.
  - Finds the interpolated search text.
  - Finds the header-based success check and its case sensitivity.
  - Doesn't flag the PATCH body.
solution: |
  Fixed endpoint list: `GET /v1/notes`, `DELETE /v1/notes/42`, `GET /v1/notes?search=<text>` with `Authorization: Bearer <token>`, and the `PATCH` unchanged. `searchURL` should use `URLComponents` with `queryItems = [URLQueryItem(name: "search", value: text)]`. Success comes from `HTTPURLResponse.statusCode` being in `200..<300`, and when you do need a header, read it with `value(forHTTPHeaderField:)`, which ignores case.
````

````exercise
id: m30-l01-e6
type: design
prompt: "Design the REST endpoints for a book club feature: a club has members and a reading schedule (a list of books with dates). Members can join and leave a club, the organizer can add and remove books from the schedule, and anyone can list clubs filtered by city. For each endpoint give the method, the path, what goes in the query or body, and the success status code. Mark which requests the app may retry automatically."
rubric:
  - Paths are nouns for resources and sub-resources (/clubs, /clubs/{id}/members, /clubs/{id}/schedule).
  - Methods match the operation, and the design uses PUT or DELETE where an idempotent form exists (joining as PUT /clubs/{id}/members/me, leaving as DELETE).
  - Filtering by city is a query parameter on a GET.
  - Success codes are plausible (200, 201 for creation, 204 for deletion without body).
  - Retryable requests are exactly the idempotent ones, and the answer says why POST isn't.
solution: |
  One reasonable design:

  | Request | Body or query | Success | Auto-retry |
  | --- | --- | --- | --- |
  | `GET /v1/clubs?city=lisbon&page=1` | query: city, page | 200 | yes |
  | `GET /v1/clubs/{clubID}` | | 200 | yes |
  | `PUT /v1/clubs/{clubID}/members/me` | | 200 or 204 | yes |
  | `DELETE /v1/clubs/{clubID}/members/me` | | 204 | yes |
  | `GET /v1/clubs/{clubID}/schedule` | | 200 | yes |
  | `POST /v1/clubs/{clubID}/schedule` | body: `{"bookID": 42, "startsOn": "2026-12-01"}` | 201, with `Location` | no |
  | `DELETE /v1/clubs/{clubID}/schedule/{entryID}` | | 204 | yes |

  Joining is modeled as putting yourself into the members collection (`PUT .../members/me`), which makes it idempotent: joining twice leaves you a member once. A `POST /clubs/{id}/join` would work but tells the client nothing about whether a retry is safe. Adding a schedule entry is a `POST` because the server assigns the new entry's ID, so a blind retry could add the book twice; a client-generated entry ID with `PUT .../schedule/{entryID}` would make it idempotent too. The city filter is a query parameter because it narrows a `GET`; the new entry's data goes in a JSON body with `Content-Type: application/json`.
````

## Summary

- A request is a method, a target URL, headers and an optional body; a response is a status code, headers and an optional body.
- Safe methods (GET, HEAD) don't ask for changes. Idempotent methods (safe ones plus PUT and DELETE) can be repeated with the same effect, so they're the ones you may retry automatically. POST and PATCH aren't.
- The first digit of a status code is its class: 2xx success, 3xx redirection, 4xx your request, 5xx the server. React to 401, 403, 404, 429 and 503 differently.
- Header names are case-insensitive; read them with `value(forHTTPHeaderField:)`. `Content-Type` describes the body you're sending, `Accept` what you want back.
- REST paths name resources with nouns, the method carries the verb, the query filters a GET, and the body carries the data you create or change. Secrets never go in the URL.
- Build URLs with `URLComponents` and `queryItems`, and requests with `URLRequest`. On Linux these types need `import FoundationNetworking`.
