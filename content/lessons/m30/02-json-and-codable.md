---
id: m30-l02
title: JSON and Codable
description: "Turn the JSON in a response body into Swift values and back. You decode and encode with JSONDecoder and JSONEncoder, rename keys with CodingKeys and convertFromSnakeCase (and catch the acronym trap that silently turns fields into nil), decode ISO 8601 dates, model nested and optional fields, read a DecodingError to find exactly which field broke, and decode a list so one bad item doesn't throw away the whole page."
module: m30
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m30-l01]
objectives:
  - Decode JSON into Decodable types and encode Encodable types to JSON with stable output.
  - Map JSON keys to property names with CodingKeys or a key decoding strategy, and explain where convertFromSnakeCase goes wrong.
  - Decode ISO 8601 dates, with and without fractional seconds.
  - Model nested objects, optional fields, null and missing keys, and defaults.
  - Read a DecodingError by its case and coding path, and report it without relying on its description text.
  - Decode an array leniently so invalid elements are skipped and counted.
terms:
  - term: Codable
    definition: "A type alias for Decodable & Encodable. The compiler can synthesize the conformance when every stored property is itself Codable."
  - term: CodingKeys
    definition: "A nested enum conforming to CodingKey that lists the keys used for a type. Its raw values are the JSON key names; leaving a property out excludes it from coding (it then needs a default value to decode)."
  - term: Key decoding strategy
    definition: "A JSONDecoder setting that transforms every JSON key before matching it to a CodingKey, such as convertFromSnakeCase (published_at becomes publishedAt)."
  - term: DecodingError
    definition: "The error JSONDecoder throws. Four cases: typeMismatch, valueNotFound (null where a value was required), keyNotFound and dataCorrupted, each with a context holding the codingPath to the problem."
  - term: Coding path
    definition: "The list of keys (and array indices) from the top of the JSON down to where decoding failed, such as data, index 3, author, name."
  - term: Lossy decoding
    definition: "Decoding a collection so that elements that fail are skipped (and ideally logged) instead of failing the whole collection."
mastery:
  - Write a Codable model for a JSON payload with renamed keys, nested objects and dates.
  - Predict whether a field decodes as nil, decodes a value, or throws, given missing, null and mistyped JSON.
  - Spot the convertFromSnakeCase acronym trap in a model with properties like imageURL.
  - Turn a DecodingError into a one-line message with the case and the path.
  - Decode a list response where some items are invalid, keeping the valid ones and counting the rest.
resources: [swift-book-protocols, swift-book-error-handling, swift-book-enumerations]
cards:
  - id: m30-l02-c1
    front: Missing key, null, or wrong type for a property declared String?
    back: "Missing: nil. null: nil. Wrong type (a number): typeMismatch error. Optional only covers absent and null, not malformed."
  - id: m30-l02-c2
    front: "convertFromSnakeCase and a property named imageURL?"
    back: "image_url converts to imageUrl, which doesn't match the key imageURL. A non-optional property throws keyNotFound; an optional one silently decodes as nil. Use CodingKeys for acronyms."
  - id: m30-l02-c3
    front: The four DecodingError cases?
    back: "typeMismatch (value of the wrong type), valueNotFound (null where a value is required), keyNotFound (key absent), dataCorrupted (invalid JSON, or a value that can't be converted, like a bad date). Each has a context with codingPath."
  - id: m30-l02-c4
    front: Why use .sortedKeys on a JSONEncoder?
    back: "Key order in encoded JSON isn't guaranteed. Sorted keys make output stable, so tests, snapshots and request signatures that compare bytes don't flake."
  - id: m30-l02-c5
    front: How do you decode a list without one bad item failing the whole list?
    back: "Decode each element into a wrapper whose init(from:) catches the error and stores a Result (or nil); then keep the successes and log or count the failures."
---

## The idea in one sentence

`Codable` lets the compiler write the code that maps JSON to your types, and your job is to tell it where the names differ, how dates look, which fields may be absent, and what to do when the server sends something you didn't expect.

## Decoding and encoding

`Decodable` means "can be created from an external representation", `Encodable` means "can be written to one", and `Codable` is both. When every stored property is itself `Codable` (`Int`, `String`, `Bool`, `Double`, `Date`, `URL`, arrays, dictionaries, optionals and your own `Codable` types), the compiler synthesizes the conformance. `JSONDecoder` and `JSONEncoder` in Foundation do the JSON part.

```swift
import Foundation

struct Book: Codable {
    let id: Int
    let title: String
    let pageCount: Int
    let tags: [String]
}

let json = """
{"id": 42, "title": "The Dispossessed", "pageCount": 387, "tags": ["sf", "classic"], "isbn": "9780061054884"}
"""

let book = try JSONDecoder().decode(Book.self, from: Data(json.utf8))
print(book.title)
print(book.pageCount, book.tags)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let encoded = try encoder.encode(book)
print(String(decoding: encoded, as: UTF8.self))
```

```output
The Dispossessed
387 ["sf", "classic"]
{"id":42,"pageCount":387,"tags":["sf","classic"],"title":"The Dispossessed"}
```

1. `decode(Book.self, from:)` takes the type to build and the bytes. A response body arrives as `Data`; here `Data(json.utf8)` stands in for it.
2. Keys in the JSON that the type doesn't mention (`isbn`) are ignored. That's what you want: servers add fields all the time, and old app versions must keep working.
3. Encoding produces `Data` too. **Key order in encoded JSON isn't guaranteed**, and it can differ between platforms and runs. `.sortedKeys` makes it stable, which matters whenever you compare bytes: tests, snapshot files, request signing.
4. The decoded values are plain Swift values. Nothing about JSON leaks into the rest of the app.

## Renaming keys

### CodingKeys

When the JSON names don't match Swift's conventions, add a nested enum called `CodingKeys`. Its raw values are the JSON names:

```swift
import Foundation

struct Book: Decodable {
    let id: Int
    let title: String
    let coverURL: URL?
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case coverURL = "cover_url"
        case isFavorite = "favorite"
    }
}

let json = """
{"id": 7, "title": "Kindred", "cover_url": "https://img.example.com/7.jpg", "favorite": true}
"""

let book = try JSONDecoder().decode(Book.self, from: Data(json.utf8))
print(book.coverURL?.absoluteString ?? "no cover")
print(book.isFavorite)
```

```output
https://img.example.com/7.jpg
true
```

`URL` decodes from a JSON string. Once you write `CodingKeys`, it has to list every property you want coded; a property left out is skipped, and then it needs a default value (`var isFavorite = false`) or decoding can't build the struct.

### convertFromSnakeCase and its acronym trap

Most APIs use one convention for every key, so instead of renaming each one you can set a strategy on the decoder. `.convertFromSnakeCase` turns `cover_url` into… `coverUrl`. Apple's documentation is explicit: the strategy "can't infer capitalization for acronyms or initialisms such as WYSIWYG or URI". Your property is called `coverURL`, so the key doesn't match. What happens next depends on whether the property is optional:

```swift
import Foundation

struct Book: Decodable {
    let id: Int
    let pageCount: Int
    let coverURL: URL?
}

let json = """
{"id": 7, "page_count": 264, "cover_url": "https://img.example.com/7.jpg"}
"""

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let book = try decoder.decode(Book.self, from: Data(json.utf8))
print(book.pageCount)
print(book.coverURL?.absoluteString ?? "no cover")
```

```output
264
no cover
```

`page_count` became `pageCount` and matched. `cover_url` became `coverUrl`, which matched nothing, and because `coverURL` is optional the decoder treated it as **missing, so `nil`, with no error**. Every book in the app would show a placeholder image and nothing would tell you why. If the property weren't optional, you'd at least get a `keyNotFound` error.

Two fixes: name the property `coverUrl`, or keep the strategy and add `CodingKeys` with `case coverURL = "coverUrl"` (the raw value is matched against the *converted* key). Either way, have a test that decodes a real sample payload and checks every field, which is what lesson 6 sets up.

`JSONEncoder` has the mirror setting, `keyEncodingStrategy = .convertToSnakeCase`, with the same acronym caveat in the other direction.

## Dates

JSON has no date type. Servers send dates as strings (usually ISO 8601, like `2026-03-15T09:30:00Z`) or as numbers of seconds since 1970. `JSONDecoder`'s default strategy expects neither: it expects the number of seconds since January 1, 2001, which no server sends. Always set `dateDecodingStrategy`:

```swift
import Foundation

struct Event: Codable {
    let name: String
    let startsAt: Date
}

let json = """
{"name": "Book club", "starts_at": "2026-03-15T18:30:00Z"}
"""

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601
let event = try decoder.decode(Event.self, from: Data(json.utf8))

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
let parts = utc.dateComponents([.year, .month, .day, .hour, .minute], from: event.startsAt)
print(parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
encoder.keyEncodingStrategy = .convertToSnakeCase
encoder.dateEncodingStrategy = .iso8601
print(String(decoding: try encoder.encode(event), as: UTF8.self))
```

```output
2026 3 15 18 30
{"name":"Book club","starts_at":"2026-03-15T18:30:00Z"}
```

A `Date` is a point in time with no time zone. To print its parts you need a calendar and a time zone; this block uses UTC so the output doesn't depend on where the code runs. In an app you'd format dates for the user's time zone with `Date.FormatStyle` and never show the raw value.

Servers that send milliseconds (`2026-03-15T18:30:00.250Z`) are common. Whether the built-in `.iso8601` strategy accepts the fraction has varied by platform and OS version, so don't rely on it. Parse with a format style that expects it:

```swift
import Foundation

struct Reading: Decodable {
    let recordedAt: Date
}

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    if let date = try? withFraction.parse(text) {
        return date
    }
    if let date = try? Date.ISO8601FormatStyle().parse(text) {
        return date
    }
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
}

for text in ["2026-03-15T18:30:00.250Z", "2026-03-15T18:30:00Z", "15/03/2026"] {
    let json = #"{"recordedAt": "\#(text)"}"#
    do {
        let reading = try decoder.decode(Reading.self, from: Data(json.utf8))
        let milliseconds = Int((reading.recordedAt.timeIntervalSince1970 * 1000).rounded()) % 1000
        print("\(text): ok, \(milliseconds) ms")
    } catch DecodingError.dataCorrupted {
        print("\(text): not a date")
    }
}
```

```output
2026-03-15T18:30:00.250Z: ok, 250 ms
2026-03-15T18:30:00Z: ok, 0 ms
15/03/2026: not a date
```

The custom closure gets a decoder positioned at the date value. It tries the format with fractional seconds, then without, and throws `dataCorrupted` with a message you chose. `#"…"#` is a raw string, so the quotes inside don't need escaping; `\#(text)` interpolates inside it.

For timestamps in seconds, `.secondsSince1970` does the job; `.millisecondsSince1970` exists for the other common variant.

## Nested objects, optionals and defaults

APIs often wrap the data you want in an envelope and nest related objects. Model the nesting with nested types, then expose the shape your app wants:

```swift
import Foundation

struct BooksPage: Decodable {
    struct Item: Decodable {
        struct Author: Decodable {
            let name: String
        }
        let id: Int
        let title: String
        let subtitle: String?
        let author: Author
        let rating: Double?
    }
    struct Meta: Decodable {
        let page: Int
        let totalPages: Int
    }
    let data: [Item]
    let meta: Meta
}

let json = """
{
  "data": [
    {"id": 1, "title": "Kindred", "author": {"name": "Octavia E. Butler"}, "rating": 4.5},
    {"id": 2, "title": "Piranesi", "subtitle": null, "author": {"name": "Susanna Clarke"}}
  ],
  "meta": {"page": 1, "total_pages": 3}
}
"""

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let page = try decoder.decode(BooksPage.self, from: Data(json.utf8))
for item in page.data {
    let rating = item.rating.map { "rated \($0)" } ?? "unrated"
    print("\(item.title) by \(item.author.name), subtitle: \(item.subtitle ?? "none"), \(rating)")
}
print("page \(page.meta.page) of \(page.meta.totalPages)")
```

```output
Kindred by Octavia E. Butler, subtitle: none, rated 4.5
Piranesi by Susanna Clarke, subtitle: none, unrated
page 1 of 3
```

For a property declared optional, the synthesized decoder uses `decodeIfPresent`, so **a missing key and an explicit `null` both decode as `nil`**. Kindred has no `subtitle` key, Piranesi has `"subtitle": null`, and both print `none`. A value of the wrong type is still an error: `"subtitle": 5` throws `typeMismatch`. Optional means "may be absent", not "may be garbage".

### Flattening and defaults with init(from:)

When the JSON's shape is awkward for the app (an author name two levels down, a flag that's sometimes missing and should default to `false`), write `init(from:)` yourself instead of mirroring the JSON with throwaway types:

```swift
import Foundation

struct Book: Decodable {
    let id: Int
    let title: String
    let authorName: String
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, author, isFavorite
    }

    enum AuthorKeys: String, CodingKey {
        case name
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let author = try container.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author)
        authorName = try author.decode(String.self, forKey: .name)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

let json = """
[
  {"id": 1, "title": "Kindred", "author": {"name": "Octavia E. Butler"}, "isFavorite": true},
  {"id": 2, "title": "Piranesi", "author": {"name": "Susanna Clarke"}}
]
"""

let books = try JSONDecoder().decode([Book].self, from: Data(json.utf8))
for book in books {
    print(book.title, "-", book.authorName, "-", book.isFavorite ? "favorite" : "not favorite")
}
```

```output
Kindred - Octavia E. Butler - favorite
Piranesi - Susanna Clarke - not favorite
```

- `container(keyedBy:)` gives you a keyed container for the object; `nestedContainer(keyedBy:forKey:)` steps into the `author` object with its own keys.
- `decodeIfPresent(_:forKey:)` returns `nil` for a missing key or `null`, and `?? false` turns that into a default. A plain `decode` would throw `keyNotFound` for Piranesi.
- Writing `init(from:)` only replaces decoding. If you also need `Encodable`, write `encode(to:)` with the same keys, or keep a separate type for what you send.

## When decoding fails: reading DecodingError

Decoding fails all the time in real apps: the backend renames a field, a value comes back `null`, an ID turns from a number into a string. `DecodingError` tells you exactly where, if you read it properly. It has four cases, each with a `Context` that holds a `codingPath` (the keys and indices from the root to the problem) and a `debugDescription`:

| Case | Means |
| --- | --- |
| `typeMismatch(type, context)` | The value exists but has the wrong type, like `"42"` for an `Int` |
| `valueNotFound(type, context)` | `null` where a non-optional value was required |
| `keyNotFound(key, context)` | The key is missing; the path leads to the object that should have had it |
| `dataCorrupted(context)` | Not valid JSON, or a value that can't be converted (a bad date, a bad URL) |

The `description` and `localizedDescription` of these errors are written for debugging, and their wording differs between platforms and OS versions. Don't show them to users or compare them in tests. Switch over the cases and build the message yourself:

```swift
import Foundation

struct Book: Decodable {
    let id: Int
    let title: String
}

struct Shelf: Decodable {
    let name: String
    let books: [Book]
}

func path(_ codingPath: [any CodingKey]) -> String {
    let parts = codingPath.map { key in
        key.intValue.map { "[\($0)]" } ?? key.stringValue
    }
    return parts.isEmpty ? "(root)" : parts.joined(separator: ".")
}

func explain(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(_, let context):
        return "wrong type at \(path(context.codingPath))"
    case .valueNotFound(_, let context):
        return "null at \(path(context.codingPath))"
    case .keyNotFound(let key, let context):
        return "missing '\(key.stringValue)' in \(path(context.codingPath))"
    case .dataCorrupted:
        return "invalid data"
    @unknown default:
        return "unknown decoding error"
    }
}

let payloads = [
    #"{"name": "To read", "books": [{"id": 1, "title": "Kindred"}]}"#,
    #"{"name": "To read", "books": [{"id": 1, "title": "Kindred"}, {"id": "2", "title": "Piranesi"}]}"#,
    #"{"name": "To read", "books": [{"id": 1, "title": null}]}"#,
    #"{"name": "To read", "books": [{"id": 1}]}"#,
    #"{"books": []}"#,
    #"{"name": "To read", "books": [{"id": 1, "title": "Kindred"}"#,
]

for json in payloads {
    do {
        let shelf = try JSONDecoder().decode(Shelf.self, from: Data(json.utf8))
        print("ok: \(shelf.books.count) book(s)")
    } catch let error as DecodingError {
        print(explain(error))
    }
}
```

```output
ok: 1 book(s)
wrong type at books.[1].id
null at books.[0].title
missing 'title' in books.[0]
missing 'name' in (root)
invalid data
```

- The path for the `typeMismatch` reads like an address: the `books` array, element 1, key `id`. That's exactly what you'd put in a bug report to the backend team.
- For `keyNotFound`, the path stops at the object that should contain the key, and the key itself is the case's first value.
- Array indices come back as keys with an `intValue`; the helper prints them as `[1]`. Don't rely on their `stringValue`, which is a debugging label.
- `DecodingError` is an enum from the standard library that could gain cases in a future version, so the `switch` needs `@unknown default`. In Swift 6 mode, leaving it out is an error (see Common mistakes).
- Lesson 4 maps these into the app's own error type, so the UI never sees `DecodingError` at all.

> [!warning] Don't hide decoding errors with try?
> `let books = try? decoder.decode(...)` turns "the backend renamed a field" into "the list is empty", and nobody finds out until users complain. Let the error reach a place that logs the case and path.

## Lossy decoding: one bad item shouldn't empty the list

Decoding `[Book]` is all-or-nothing: one element with a problem makes the whole array throw, and the screen shows an error instead of 49 good books. For lists where a broken item can be skipped, decode each element into a wrapper that catches its own error:

```swift
import Foundation

struct Book: Decodable {
    let id: Int
    let title: String
}

/// Decodes one element, keeping the error instead of throwing it.
struct Failable<Element: Decodable>: Decodable {
    let result: Result<Element, any Error>

    init(from decoder: any Decoder) throws {
        result = Result { try Element(from: decoder) }
    }
}

/// An array that skips elements that fail to decode, and remembers how many it skipped.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]
    let skipped: Int

    init(from decoder: any Decoder) throws {
        let all = try [Failable<Element>](from: decoder)
        var elements: [Element] = []
        var skipped = 0
        for item in all {
            switch item.result {
            case .success(let element):
                elements.append(element)
            case .failure:
                skipped += 1
            }
        }
        self.elements = elements
        self.skipped = skipped
    }
}

struct BooksResponse: Decodable {
    let books: LossyArray<Book>
}

let json = """
{"books": [
  {"id": 1, "title": "Kindred"},
  {"id": 2},
  {"id": 3, "title": "Piranesi"},
  {"id": "four", "title": "Beloved"}
]}
"""

let response = try JSONDecoder().decode(BooksResponse.self, from: Data(json.utf8))
print(response.books.elements.map(\.title))
print("skipped: \(response.books.skipped)")

do {
    _ = try JSONDecoder().decode([String: [Book]].self, from: Data(json.utf8))
} catch {
    print("strict decoding failed")
}
```

```output
["Kindred", "Piranesi"]
skipped: 2
strict decoding failed
```

How it works:

1. `Failable` doesn't decode anything itself. It hands its decoder to `Element(from:)` and stores the outcome in a `Result` (Module 12, lesson 4). Its own `init` can't fail for a bad element, so the array decoding carries on.
2. `[Failable<Element>](from: decoder)` decodes the whole JSON array with that wrapper per element. Each element is consumed whether it succeeded or not, so nothing gets out of step.
3. `LossyArray` keeps the successes and counts the failures. In an app you'd also log each failure's case and path (with the helper from the previous section), so a backend bug shows up in your logs rather than as books quietly missing.
4. The array itself still has to be valid: if `books` were a string, `LossyArray` throws, which is right.

Use this deliberately: for a feed or a search result list, skipping an item is better than an error screen. For a bank statement or an order's line items, a missing element is a wrong answer, and you want the whole decode to fail.

## Common mistakes

> [!error] error: type 'Shelf' does not conform to protocol 'Decodable'
> Synthesis needs every stored property to be `Decodable`. Swift 6.3 reports the type, then explains in a note: `cannot automatically synthesize 'Decodable' because 'Owner' does not conform to 'Decodable'`.

```swift no-compile type 'Shelf' does not conform to protocol 'Decodable'
struct Owner {
    let name: String
}

struct Shelf: Decodable {
    let title: String
    let owner: Owner
}
```

Make `Owner` conform to `Decodable` (or `Codable`), or write `init(from:)` yourself.

> [!error] error: switch covers known cases, but 'DecodingError' may have additional unknown values, possibly added in future versions
> Listing all four cases isn't enough, because `DecodingError` isn't a frozen enum. Swift 6.3 in Swift 6 mode rejects this:

```swift no-compile switch covers known cases, but 'DecodingError' may have additional unknown values
func describe(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch: "wrong type"
    case .valueNotFound: "null"
    case .keyNotFound: "missing key"
    case .dataCorrupted: "invalid data"
    }
}
```

Add `@unknown default:` as the last case. The compiler still warns you if a known case is missing, and the `@unknown default` handles cases added later.

> [!error] An optional property that's always nil
> Usually a key mismatch: `convertFromSnakeCase` with an acronym (`imageURL`), a typo in `CodingKeys`, or a server-side rename. Decoding doesn't complain because optional means "may be missing". Test with a real payload and assert the field's value.

> [!error] Leaving dateDecodingStrategy at its default
> The default reads a number of seconds since 2001, not 1970, and fails on strings. Set `.iso8601`, `.secondsSince1970` or a custom strategy that matches your API.

> [!error] Comparing encoded JSON as a string without .sortedKeys
> Key order isn't guaranteed. Compare decoded values, or encode with `.sortedKeys`.

> [!error] Showing error.localizedDescription for a decoding failure
> The text is meant for developers, and it varies by platform. Map the error to your own message (lesson 4), and log the case and path.

> [!error] try? on the whole response
> Turns every decoding bug into an empty screen. Catch `DecodingError`, log it, and show an error state.

## Exercises

````exercise
id: m30-l02-e1
type: prediction
prompt: "Four profiles, one optional field, one non-optional field. What does the program print?"
code: |
  import Foundation

  struct Profile: Decodable {
      let name: String
      let bio: String?
  }

  let payloads = [
      #"{"name": "Ana", "bio": "Reads on the train"}"#,
      #"{"name": "Ben"}"#,
      #"{"name": "Caro", "bio": null}"#,
      #"{"name": "Dev", "bio": 42}"#,
      #"{"bio": "No name"}"#,
  ]

  for json in payloads {
      do {
          let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
          print("\(profile.name): \(profile.bio ?? "-")")
      } catch DecodingError.typeMismatch {
          print("type mismatch")
      } catch DecodingError.keyNotFound(let key, _) {
          print("missing \(key.stringValue)")
      }
  }
output: |
  Ana: Reads on the train
  Ben: -
  Caro: -
  type mismatch
  missing name
solution: |
  - Ana has a bio, so it's printed.
  - Ben has no `bio` key. `bio` is optional, so the synthesized decoder uses `decodeIfPresent` and gets `nil`.
  - Caro's `bio` is `null`. Same result: `nil`.
  - Dev's `bio` is a number. Optional doesn't cover the wrong type, so decoding throws `typeMismatch`.
  - The last one has no `name`, and `name` isn't optional, so it throws `keyNotFound` with the key `name`.

  ```output
  Ana: Reads on the train
  Ben: -
  Caro: -
  type mismatch
  missing name
  ```
````

````exercise
id: m30-l02-e2
type: fill-in
prompt: "The API sends `{\"user_id\": 9, \"display_name\": \"Ana\", \"avatar_url\": \"https://img.example.com/9.png\"}`. Complete the CodingKeys so this model decodes it with a plain JSONDecoder (no key strategy)."
code: |
  struct User: Decodable {
      let id: Int
      let displayName: String
      let avatarURL: URL

      enum CodingKeys: [[1]], CodingKey {
          case id = "[[2]]"
          case displayName = "[[3]]"
          case avatarURL = "[[4]]"
      }
  }
blanks:
  - id: "1"
    answers: ["String"]
  - id: "2"
    answers: ["user_id"]
  - id: "3"
    answers: ["display_name"]
  - id: "4"
    answers: ["avatar_url"]
solution: |
  ```swift
  import Foundation

  struct User: Decodable {
      let id: Int
      let displayName: String
      let avatarURL: URL

      enum CodingKeys: String, CodingKey {
          case id = "user_id"
          case displayName = "display_name"
          case avatarURL = "avatar_url"
      }
  }

  let json = #"{"user_id": 9, "display_name": "Ana", "avatar_url": "https://img.example.com/9.png"}"#
  let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))
  print(user.id, user.displayName, user.avatarURL.absoluteString)
  ```

  ```output
  9 Ana https://img.example.com/9.png
  ```

  The enum's raw type is `String`, and each raw value is the JSON key. The case names must match the property names. With explicit keys, `avatarURL` works fine; it's only `convertFromSnakeCase` that would turn `avatar_url` into `avatarUrl`. Don't combine the two: with a key strategy, raw values are matched against the *converted* keys, so `"avatar_url"` would never match.
````

````exercise
id: m30-l02-e3
type: comprehension
prompt: "Decoding `{\"items\": [{\"id\": 1, \"price\": 9.5}, {\"id\": 2, \"price\": null}]}` into a type whose items have `let price: Double` throws. Which error, and which coding path?"
choices:
  - text: "valueNotFound, with the path items, index 1, price."
    correct: true
    why: "null where a non-optional Double is required is valueNotFound, and the path leads to the exact value."
  - text: "keyNotFound for price, with the path items, index 1."
    correct: false
    why: "The key is present; its value is null. keyNotFound is for a missing key."
  - text: "typeMismatch, because null isn't a Double."
    correct: false
    why: "JSONDecoder reports null for a required value as valueNotFound, not typeMismatch."
  - text: "dataCorrupted, because the JSON is invalid."
    correct: false
    why: "The JSON is valid; null is a legal JSON value."
solution: |
  `valueNotFound(Double.self, context)` with `context.codingPath` = `items`, index 1, `price`. Run it through the `explain` helper from the lesson and you'd get `null at items.[1].price`. If `price` should be allowed to be absent, declare it `Double?`; if `null` means "free", decode it with `decodeIfPresent` and a default in `init(from:)`.
````

````exercise
id: m30-l02-e4
type: solve
prompt: "Decode this search response. Model `SearchResponse` with `results` (a lossy array, so the broken item is skipped) and `nextCursor` (optional), where each result has `id: Int`, `title: String`, `publishedAt: Date` and `coverURL: URL?`. Use `convertFromSnakeCase` and `.iso8601`, and make sure `coverURL` really decodes. Print each title with its publication year (UTC), whether it has a cover, the number of skipped results, and the cursor."
starter: |
  import Foundation

  let json = """
  {
    "results": [
      {"id": 1, "title": "Kindred", "published_at": "1979-06-01T00:00:00Z", "cover_url": "https://img.example.com/1.jpg"},
      {"id": 2, "title": "Piranesi", "published_at": "2020-09-15T00:00:00Z"},
      {"id": 3, "title": "Broken", "published_at": "yesterday"}
    ],
    "next_cursor": "c2VhcmNoOjM="
  }
  """
rubric:
  - "coverURL is mapped explicitly (CodingKeys with coverURL = \"coverUrl\", or the property is named coverUrl), so the first result has a cover."
  - The lossy wrapper keeps the two valid results and counts one skipped.
  - nextCursor is optional and decoded through the snake case strategy.
  - The year is computed with a calendar in UTC, not from the system time zone.
solution: |
  ```swift
  import Foundation

  struct Failable<Element: Decodable>: Decodable {
      let result: Result<Element, any Error>
      init(from decoder: any Decoder) throws {
          result = Result { try Element(from: decoder) }
      }
  }

  struct LossyArray<Element: Decodable>: Decodable {
      let elements: [Element]
      let skipped: Int
      init(from decoder: any Decoder) throws {
          let all = try [Failable<Element>](from: decoder)
          elements = all.compactMap { try? $0.result.get() }
          skipped = all.count - elements.count
      }
  }

  struct SearchResult: Decodable {
      let id: Int
      let title: String
      let publishedAt: Date
      let coverURL: URL?

      enum CodingKeys: String, CodingKey {
          case id, title, publishedAt
          case coverURL = "coverUrl"   // the key after convertFromSnakeCase
      }
  }

  struct SearchResponse: Decodable {
      let results: LossyArray<SearchResult>
      let nextCursor: String?
  }

  let json = """
  {
    "results": [
      {"id": 1, "title": "Kindred", "published_at": "1979-06-01T00:00:00Z", "cover_url": "https://img.example.com/1.jpg"},
      {"id": 2, "title": "Piranesi", "published_at": "2020-09-15T00:00:00Z"},
      {"id": 3, "title": "Broken", "published_at": "yesterday"}
    ],
    "next_cursor": "c2VhcmNoOjM="
  }
  """

  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  decoder.dateDecodingStrategy = .iso8601
  let response = try decoder.decode(SearchResponse.self, from: Data(json.utf8))

  var utc = Calendar(identifier: .gregorian)
  utc.timeZone = TimeZone(identifier: "UTC")!
  for result in response.results.elements {
      let year = utc.component(.year, from: result.publishedAt)
      print("\(result.title) (\(year)), cover: \(result.coverURL != nil)")
  }
  print("skipped: \(response.results.skipped)")
  print("next: \(response.nextCursor ?? "none")")
  ```

  ```output
  Kindred (1979), cover: true
  Piranesi (2020), cover: false
  skipped: 1
  next: c2VhcmNoOjM=
  ```

  The key detail is `case coverURL = "coverUrl"`. With the strategy on, `cover_url` is converted to `coverUrl` before matching, so that's the raw value to use. Without it, both results would print `cover: false` and nothing would fail. "Broken" has an invalid date, which fails only that element (`dataCorrupted`), and the lossy array counts it. This version of `LossyArray` uses `compactMap` with `try? result.get()`; in an app, also log each failure.
````

````exercise
id: m30-l02-e5
type: find-errors
prompt: "This code loads a user's orders. Which are real problems?"
code: |
  struct Order: Codable {
      let id: Int
      let totalCents: Int
      let createdAt: Date
      let trackingURL: URL?
  }

  func decodeOrders(_ data: Data) -> [Order] {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return (try? decoder.decode([Order].self, from: data)) ?? []
  }

  func cacheKey(for order: Order) throws -> String {
      String(decoding: try JSONEncoder().encode(order), as: UTF8.self)
  }
choices:
  - text: "No dateDecodingStrategy is set, so ISO 8601 date strings fail to decode."
    correct: true
    why: "The default expects a number (seconds since 2001)."
  - text: "trackingURL won't match tracking_url under convertFromSnakeCase, and being optional it silently decodes as nil."
    correct: true
    why: "The converted key is trackingUrl."
  - text: "try? turns every decoding failure into an empty list, hiding the error."
    correct: true
    why: "Combined with the date bug, every user sees \"no orders\" and nothing is logged."
  - text: "Encoding without .sortedKeys makes the cache key unstable."
    correct: true
    why: "Key order isn't guaranteed, so the same order could produce different keys."
  - text: "Order can't be Codable because Date isn't Codable."
    correct: false
    why: "Date, URL and their optionals are all Codable."
rubric:
  - Finds the missing date strategy.
  - Finds the acronym key mismatch and why it's silent.
  - Finds the swallowed error.
  - Finds the unstable encoded key.
solution: |
  Set `decoder.dateDecodingStrategy = .iso8601` (or whatever the API sends), map `trackingURL` explicitly (`CodingKeys` with `case trackingURL = "trackingUrl"`), make `decodeOrders` `throws` so the caller can log the `DecodingError` and show an error state, and either encode with `outputFormatting = [.sortedKeys]` or, better, build the cache key from `id` alone. The bugs compound: the date bug makes every decode fail, and `try?` makes that look like a user with no orders.
````

````exercise
id: m30-l02-e6
type: explain
prompt: "Your feed screen decodes `[Post]` with the code below. The backend ships a change and one post in fifty now has `\"author\": null`. With this code, what does the user see? With a lossy array? Which would you choose for the feed, and which for the items of an invoice, and why?"
code: |
  struct Post: Decodable {
      struct Author: Decodable {
          let name: String
      }
      let id: Int
      let text: String
      let author: Author
  }

  let posts = try decoder.decode([Post].self, from: data)
rubric:
  - Plain decoding fails the whole array (valueNotFound), so the user sees an error or empty state for the entire feed.
  - Lossy decoding drops the broken post and shows the other 49.
  - For a feed, skipping (and logging) is the better trade-off; for an invoice, a missing line makes the total wrong, so the whole decode should fail.
  - Mentions logging the skipped items' errors so the backend bug is noticed.
solution: |
  Plain `[Post]` decoding is all-or-nothing: one `valueNotFound` at `[n].author` throws for the whole array, and the screen shows an error (or, worse, an empty feed if someone used `try?`). A lossy array decodes each post independently, drops the broken one and shows the rest. For a feed that's the right call: a missing post is barely noticeable, a broken feed is not. Log each skipped item's case and path so the regression is visible. For an invoice, each line contributes to a total the user will pay; silently dropping one would show a wrong amount, so fail the whole decode and show an error. The choice depends on whether a partial answer is still a correct answer.
````

## Summary

- `Codable` is `Decodable & Encodable`; the compiler synthesizes it when every stored property is `Codable`. `JSONDecoder` ignores keys your type doesn't mention.
- Rename keys with `CodingKeys` or a key strategy. `convertFromSnakeCase` turns `image_url` into `imageUrl`, so acronym properties don't match, and optional ones silently become `nil`.
- Always set `dateDecodingStrategy`. Use `.iso8601` for plain ISO dates and a custom strategy for fractional seconds.
- An optional property decodes missing keys and `null` as `nil`; a wrong type still throws. Use `init(from:)` with `nestedContainer` and `decodeIfPresent(...) ?? default` to flatten and default.
- `DecodingError` has four cases; switch over them and print the coding path. Never show or compare its description text.
- Encode with `.sortedKeys` whenever bytes are compared.
- A lossy array decodes each element into a `Result`, keeps the successes and counts the failures. Use it where a partial list is still a correct answer.
