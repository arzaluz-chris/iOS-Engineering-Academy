---
id: m32-l04
title: Clean Architecture and use cases
description: "Rebuild the reading list with Clean Architecture's rings. You move the rules into entities, express each thing the user can do as a use case that talks to storage through a gateway protocol it owns, keep DTOs and view state in the interface adapters ring, follow the dependency rule so nothing inside knows about anything outside, and decide when the extra types pay for themselves."
module: m32
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l03]
objectives:
  - Name Clean Architecture's four rings and place each type of the reading list in one.
  - State the dependency rule and check a set of imports and references against it.
  - Put business rules in entities and orchestrate them in use cases that depend only on protocols they own.
  - Map between DTOs and entities in an adapter so the inner rings never see the API's format.
  - Tell a use case that carries rules from a pass-through one, and decide when Clean Architecture is worth it.
terms:
  - term: Clean Architecture
    definition: "Robert C. Martin's arrangement of an application as concentric rings (entities, use cases, interface adapters, frameworks and drivers) where source code dependencies only point inward."
  - term: Entity
    definition: "A type that holds enterprise or business rules, the ones that would be true even without this app: a book can only be finished once; a goal counts books finished in a given year."
  - term: Use case
    definition: "A type for one thing a user can do (load the reading list, mark a book as read). It loads entities through gateway protocols, applies their rules, saves the result and returns plain data. Also called an interactor."
  - term: Gateway
    definition: "A protocol the use case ring defines for the data it needs (BookStore), implemented by an adapter in an outer ring. It's how the dependency rule is kept while still reaching a database or a server."
  - term: Dependency rule
    definition: "Source code dependencies point only inward. Nothing in an inner ring names a type, function or module from an outer ring."
  - term: DTO (data transfer object)
    definition: "A type shaped like an external format, such as the API's JSON, used only at the boundary and mapped to and from entities by an adapter."
mastery:
  - Draw the four rings for a feature and put each type in the right one.
  - Point out the line in a use case that breaks the dependency rule and fix it with a gateway protocol.
  - Write an entity method that enforces a rule by throwing, and a use case that calls it and saves through a gateway.
  - Write a DTO-to-entity mapping and explain why the entity isn't Decodable.
  - Argue for or against use cases in a given feature, naming the rules they would hold.
resources: [swift-book-protocols, swift-book-error-handling, swift-book-structures-classes, foundation-jsondecoder]
cards:
  - id: m32-l04-c1
    front: Name Clean Architecture's four rings, from the inside out.
    back: "Entities (business rules), use cases (application actions), interface adapters (view models, presenters, repositories, DTO mapping), frameworks and drivers (UIKit, SwiftUI, URLSession, SwiftData)."
  - id: m32-l04-c2
    front: What's the dependency rule?
    back: "Source code dependencies point only inward. An inner ring never names anything in an outer ring: no UIKit, URLSession, SwiftData or view model types in entities or use cases."
  - id: m32-l04-c3
    front: How does a use case save data without depending on the database?
    back: "It defines a gateway protocol (BookStore) in its own ring and calls that. An adapter in an outer ring implements the protocol with SwiftData, the network or memory, and the composition root passes it in."
  - id: m32-l04-c4
    front: What's a pass-through use case, and why is it a smell?
    back: "A use case whose only line is return try await store.allBooks(). It adds a type and a hop without holding any rule. Either it has rules waiting to move in, or the view model can call the gateway directly."
  - id: m32-l04-c5
    front: Why map DTOs to entities instead of making entities Decodable?
    back: "So the API's shape (key names, date formats, optional fields) stays in the adapter. When the API changes, only the DTO and its mapping change; entities and everything that uses them don't."
---

## The idea in one sentence

Clean Architecture arranges the code in rings, **business rules in the middle and frameworks on the outside**, with every source dependency pointing inward, so the rules can be tested and reused without any UI, database or network attached.

## Four rings

Robert C. Martin described Clean Architecture in 2012, combining ideas from earlier layered styles. Drawn for the reading list:

```text
┌──────────────────────────────────────────────────────────┐
│ Frameworks and drivers                                    │
│ UIKit, SwiftUI, URLSession, SwiftData                     │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Interface adapters                                  │  │
│  │ ReadingListViewModel, RemoteBookStore, BookDTO      │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ Use cases                                     │  │  │
│  │  │ LoadReadingList, MarkBookAsRead, BookStore    │  │  │
│  │  │  ┌────────────────────────────────────────┐  │  │  │
│  │  │  │ Entities                                │  │  │  │
│  │  │  │ Book, ReadingGoal                       │  │  │  │
│  │  │  └────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
          every source dependency points inward
```

- **Entities** hold the rules of the problem itself. "A book can only be finished once." "The yearly goal counts books finished in that calendar year." They'd be true in a web app or a spreadsheet.
- **Use cases** are the things a user does with the app: load the reading list, mark a book as read. Each one loads entities, applies their rules, saves and returns plain data. They define **gateway** protocols for the storage they need.
- **Interface adapters** convert between the use cases' plain data and the outside world's formats: view models and presenters (to views), repositories and DTOs (to the API or database).
- **Frameworks and drivers** are the code you didn't write: UIKit, SwiftUI, `URLSession`, SwiftData. The thinner the glue to them, the better.

It's the three layers of lesson 1 with the domain split in two: entities (rules) and use cases (actions), and with an explicit rule about direction.

## The dependency rule

> Source code dependencies point only inward.

Concretely, for each file in an inner ring:

- It doesn't `import UIKit`, `SwiftUI`, `SwiftData` or a networking library.
- It doesn't mention a type from an outer ring: no `ReadingListViewModel` in a use case, no `BookDTO` in an entity.
- When it needs something from outside (storage, the current time), it **declares a protocol** or a function type in its own ring and receives an implementation. That's dependency inversion from Module 14, applied at the scale of the app.

Data still flows both ways: a tap goes in through the view model to the use case, and books come out of the store to the screen. Only the **source code references** are one-way. The use case calls `store.save(book)` on a `BookStore` it owns; the SwiftData adapter, outside, conforms to it.

## The reading list, in rings

Lessons 1 to 3 had `BookRepository.markAsRead(id:)`, which meant the rule "only unread books can be marked" lived in whatever implemented the repository. In Clean Architecture that rule moves into the entity, the use case orchestrates, and the gateway just stores:

```swift
import Foundation

// MARK: - Entities

struct Book: Equatable, Sendable {
    enum RuleError: Error {
        case alreadyRead
    }

    let id: Int
    let title: String
    let author: String
    private(set) var finishedAt: Date?

    init(id: Int, title: String, author: String, finishedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.finishedAt = finishedAt
    }

    var isRead: Bool { finishedAt != nil }

    mutating func markAsRead(at date: Date) throws {
        guard finishedAt == nil else { throw RuleError.alreadyRead }
        finishedAt = date
    }
}

struct ReadingGoal: Sendable {
    let booksPerYear: Int

    func finishedCount(in books: [Book], year: Int, calendar: Calendar) -> Int {
        books.filter { book in
            guard let finishedAt = book.finishedAt else { return false }
            return calendar.component(.year, from: finishedAt) == year
        }.count
    }
}

// MARK: - Use cases

/// Gateway: declared here, implemented in an outer ring.
protocol BookStore: Sendable {
    func allBooks() async throws -> [Book]
    func book(id: Int) async throws -> Book?
    func save(_ book: Book) async throws
}

struct ReadingListSummary: Equatable, Sendable {
    let books: [Book]
    let finishedThisYear: Int
    let goal: Int
}

struct LoadReadingList: Sendable {
    let store: any BookStore
    let goal: ReadingGoal
    let calendar: Calendar
    let now: @Sendable () -> Date

    func execute() async throws -> ReadingListSummary {
        let books = try await store.allBooks()
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        let year = calendar.component(.year, from: now())
        return ReadingListSummary(
            books: ordered,
            finishedThisYear: goal.finishedCount(in: books, year: year, calendar: calendar),
            goal: goal.booksPerYear
        )
    }
}

enum MarkAsReadError: Error, Equatable {
    case notFound
    case alreadyRead
}

struct MarkBookAsRead: Sendable {
    let store: any BookStore
    let now: @Sendable () -> Date

    func execute(id: Int) async throws -> Book {
        guard var book = try await store.book(id: id) else {
            throw MarkAsReadError.notFound
        }
        do {
            try book.markAsRead(at: now())
        } catch {
            throw MarkAsReadError.alreadyRead
        }
        try await store.save(book)
        return book
    }
}

// MARK: - Interface adapters

@MainActor
final class ReadingListViewModel {
    enum State: Equatable {
        case loading
        case loaded(header: String, rows: [String])
        case failed(String)
    }

    private(set) var state = State.loading
    private(set) var alertMessage: String?
    private let loadReadingList: LoadReadingList
    private let markBookAsRead: MarkBookAsRead

    init(loadReadingList: LoadReadingList, markBookAsRead: MarkBookAsRead) {
        self.loadReadingList = loadReadingList
        self.markBookAsRead = markBookAsRead
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func didSelect(id: Int) async {
        do {
            _ = try await markBookAsRead.execute(id: id)
            await refresh()
        } catch MarkAsReadError.alreadyRead {
            return
        } catch {
            alertMessage = "Couldn't save. Check your connection and try again."
        }
    }

    private func refresh() async {
        do {
            let summary = try await loadReadingList.execute()
            let readCount = summary.books.filter(\.isRead).count
            let header = "\(readCount) of \(summary.books.count) read · \(summary.finishedThisYear) of \(summary.goal) this year"
            let rows = summary.books.map { ($0.isRead ? "[x] " : "[ ] ") + $0.title }
            state = .loaded(header: header, rows: rows)
        } catch {
            state = .failed("Couldn't load your books.")
        }
    }
}

/// A store adapter. In the app this would wrap SwiftData or the API client.
actor InMemoryBookStore: BookStore {
    private var books: [Int: Book]
    private(set) var saves = 0

    init(_ books: [Book]) {
        self.books = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
    }

    func allBooks() -> [Book] { Array(books.values) }
    func book(id: Int) -> Book? { books[id] }
    func save(_ book: Book) {
        books[book.id] = book
        saves += 1
    }
}

// MARK: - Composition and a test run

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "UTC")!
let today = Date(timeIntervalSince1970: 1_773_480_600)  // 2026-03-14 09:30 UTC

let store = InMemoryBookStore([
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", finishedAt: Date(timeIntervalSince1970: 1_762_041_600)),  // 2025-11-02
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin"),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke"),
    Book(id: 4, title: "Station Eleven", author: "Emily St. John Mandel", finishedAt: Date(timeIntervalSince1970: 1_768_867_200)),  // 2026-01-20
])
let viewModel = ReadingListViewModel(
    loadReadingList: LoadReadingList(store: store, goal: ReadingGoal(booksPerYear: 12), calendar: calendar, now: { today }),
    markBookAsRead: MarkBookAsRead(store: store, now: { today })
)

@MainActor
func show() {
    if case .loaded(let header, let rows) = viewModel.state {
        print(header)
        rows.forEach { print("  \($0)") }
    }
}

await viewModel.load()
show()
await viewModel.didSelect(id: 3)
show()
await viewModel.didSelect(id: 1)
await viewModel.didSelect(id: 99)
print("alert: \(viewModel.alertMessage ?? "none")")
print("saves: \(await store.saves)")
```

```output
2 of 4 read · 1 of 12 this year
  [ ] Piranesi
  [ ] The Dispossessed
  [x] Kindred
  [x] Station Eleven
3 of 4 read · 2 of 12 this year
  [ ] The Dispossessed
  [x] Kindred
  [x] Piranesi
  [x] Station Eleven
alert: Couldn't save. Check your connection and try again.
saves: 1
```

Read it ring by ring:

- **Entities.** `Book.markAsRead(at:)` enforces "finished once" by throwing, and `finishedAt` is `private(set)`, so nothing outside the entity can set it without going through the rule. `ReadingGoal` counts by calendar year, with the calendar passed in. Kindred was finished in 2025, so it counts as read but not toward this year's goal.
- **Use cases.** `MarkBookAsRead` loads, applies the rule with the injected time, saves, returns. `LoadReadingList` combines the store's books with the goal rule. Neither knows about screens: they return entities and a summary struct, not strings. Both receive their clock, so the test pins "today" to March 14, 2026.
- **Gateway.** `BookStore` is three storage verbs. It has no `markAsRead`; storage doesn't decide what marking means anymore.
- **Interface adapter.** The view model turns the summary into display strings and use case errors into UI behavior: `alreadyRead` is silently ignored (tapping a finished book does nothing), anything else shows an alert. Book 99 doesn't exist, so `notFound` lands in the generic branch here; a real app might choose a different message for it.
- **The output's last line** shows the gateway was asked to save exactly once. The rule rejected book 1 before any write.

> [!note] Calendar and time zone
> The block uses a UTC Gregorian calendar so its output is the same on every machine. An app would usually pass `Calendar.current`, so "this year" follows the user's calendar and time zone: a book finished at 11 p.m. on December 31 in Tokyo is a December book there. That's exactly the kind of rule that's easy to test once it's an entity method with the calendar injected.

### Adapters on the other side: DTOs

The `BookStore` adapter that talks to the API receives JSON shaped by the backend, not by your entities. Decoding straight into `Book` would put the API's key names and date format into the innermost ring. Instead, a **DTO** mirrors the JSON, and the adapter maps it:

```swift
import Foundation

// Entity (inner ring): no Codable, no API names.
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    let finishedAt: Date?
}

// Adapter ring: shaped like the API.
struct BookDTO: Decodable {
    let id: Int
    let title: String
    let authorName: String
    let finishedAt: Date?

    func toEntity() -> Book {
        Book(id: id, title: title, author: authorName, finishedAt: finishedAt)
    }
}

let json = """
[
  {"id": 1, "title": "Kindred", "author_name": "Octavia E. Butler", "finished_at": "2025-11-02T00:00:00Z"},
  {"id": 3, "title": "Piranesi", "author_name": "Susanna Clarke", "finished_at": null}
]
"""

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let books = try decoder.decode([BookDTO].self, from: Data(json.utf8)).map { $0.toEntity() }
for book in books {
    print(book.id, book.title, "by", book.author, book.finishedAt == nil ? "(unread)" : "(read)")
}
print(books[0].finishedAt == Date(timeIntervalSince1970: 1_762_041_600))
```

```output
1 Kindred by Octavia E. Butler (read)
3 Piranesi by Susanna Clarke (unread)
true
```

If the backend renames `author_name` or switches to Unix timestamps, `BookDTO` and its decoder change. `Book`, both use cases and the view model don't. The contract tests from Module 30 pin the DTO, and the mapping is one function you can test with a fixture.

## What it looks like in a project

A typical folder layout for one feature, with the rings as folders:

```text
ReadingList/
├── Domain/
│   ├── Entities/      Book.swift, ReadingGoal.swift
│   └── UseCases/      LoadReadingList.swift, MarkBookAsRead.swift, BookStore.swift
├── Data/              RemoteBookStore.swift, BookDTO.swift, SwiftDataBookStore.swift
└── Presentation/      ReadingListViewModel.swift, ReadingListViewController.swift
```

Folders don't enforce anything: a file in `Domain/` can still `import UIKit` and nothing complains. Lesson 6 turns rings into Swift package targets, where the compiler enforces the dependency rule.

> [!tip] VIPER
> VIPER (View, Interactor, Presenter, Entity, Router) is Clean Architecture applied per screen in UIKit apps: the interactor is a use case, the presenter is MVP's presenter, and the router is a coordinator for one screen. You'll meet it in older codebases. It carries all the costs from lesson 1's settings-toggle example when applied to simple screens.

## When it's worth it

Clean Architecture's cost is real: more types, more mapping, more files per feature. It pays off when there are **rules to protect**:

- **Rule-heavy domains.** Finance, health, scheduling, anything with calculations or state machines that must be right. Entities and use cases are where those rules get thorough tests.
- **Several delivery mechanisms.** The same "mark as read" from the app, a widget, an App Intent for Siri and Shortcuts, and a watch app. One use case, four thin adapters.
- **Long-lived apps and large teams.** Swapping the networking stack or the database touches one ring. New people know where a rule must go.

It's overhead when the feature is mostly moving data between a form and a server. A use case that only forwards one call is the tell:

```swift illustrative
struct LoadBooks {
    let store: any BookStore

    func execute() async throws -> [Book] {
        try await store.allBooks()   // no rule, no orchestration
    }
}
```

That's a type and a hop with nothing in it. Either let the view model call the gateway directly, or move a rule in (ordering, filtering, combining two sources) so the use case earns its place. A reasonable middle ground many teams use: entities and gateways everywhere, use cases only where there's something to orchestrate.

## Common mistakes

> [!error] Framework imports in inner rings
> `import SwiftData` in a use case so it can take a `ModelContext`. The use case now depends on the outermost ring and can't be tested without SwiftData. Define a gateway protocol and adapt `ModelContext` to it outside.

> [!error] Use cases returning display strings
> `func execute() -> String // "2 of 4 read"`. Formatting is an adapter's job. Return data (counts, entities); the view model makes it text.

> [!error] Entities that are DTOs
> `struct Book: Codable` with `CodingKeys` matching the API. Now an API rename is an entity change that ripples through every ring. Decode into a DTO and map.

> [!error] Rules in the gateway
> `BookStore.markAsRead(id:)` that checks "already read" inside the SwiftData adapter. Each adapter (memory, SwiftData, network) has to repeat it, and the rule is tested only through storage. Put it in the entity.

> [!error] A protocol for every use case
> `protocol MarkBookAsReadUseCase` with one conformance, "for testing". You can test the view model with the real use case and a fake gateway; add the protocol when a view model test truly needs to control the use case's output directly.

## Exercises

````exercise
id: m32-l04-e1
type: comprehension
multiple: true
prompt: "Which of these lines break the dependency rule? Select all that apply."
choices:
  - text: "In MarkBookAsRead.swift (use cases ring): import SwiftData"
    correct: true
    why: "SwiftData is a framework, the outermost ring."
  - text: "In Book.swift (entities ring): let cover: UIImage?"
    correct: true
    why: "UIKit in an entity. Store a URL or an identifier; the presentation adapter loads the image."
  - text: "In ReadingListViewModel.swift (adapters ring): private let markBookAsRead: MarkBookAsRead"
    correct: false
    why: "An adapter depending on a use case is an inward dependency. That's allowed."
  - text: "In LoadReadingList.swift (use cases ring): func execute() async throws -> [BookDTO]"
    correct: true
    why: "BookDTO lives in the adapters ring. The use case should return entities or its own output types."
  - text: "In RemoteBookStore.swift (adapters ring): extension RemoteBookStore: BookStore"
    correct: false
    why: "Conforming to an inner ring's gateway protocol is exactly how outer rings plug in."
solution: |
  Dependencies may point inward only. A use case importing SwiftData, an entity holding a `UIImage`, and a use case returning `BookDTO` all name something from an outer ring. A view model holding a use case and a store adapter conforming to the use cases' gateway both point inward, which is the intended direction.
````

````exercise
id: m32-l04-e2
type: prediction
prompt: "An entity rule, a use case and a store that counts writes. What does the program print?"
code: |
  struct Book: Sendable {
      enum RuleError: Error { case alreadyRead }
      let id: Int
      private(set) var finishedDay: Int?

      init(id: Int, finishedDay: Int? = nil) {
          self.id = id
          self.finishedDay = finishedDay
      }

      mutating func markAsRead(day: Int) throws {
          guard finishedDay == nil else { throw RuleError.alreadyRead }
          finishedDay = day
      }
  }

  protocol BookStore: Sendable {
      func book(id: Int) async -> Book?
      func save(_ book: Book) async
  }

  actor MemoryStore: BookStore {
      var books = [1: Book(id: 1), 2: Book(id: 2, finishedDay: 5)]
      var writes = 0
      func book(id: Int) -> Book? { books[id] }
      func save(_ book: Book) {
          books[book.id] = book
          writes += 1
      }
  }

  struct MarkBookAsRead {
      let store: any BookStore
      let today: Int

      func execute(id: Int) async -> String {
          guard var book = await store.book(id: id) else { return "\(id): not found" }
          do {
              try book.markAsRead(day: today)
          } catch {
              return "\(id): already read on day \(book.finishedDay!)"
          }
          await store.save(book)
          return "\(id): finished on day \(book.finishedDay!)"
      }
  }

  let store = MemoryStore()
  let markOnDay9 = MarkBookAsRead(store: store, today: 9)
  print(await markOnDay9.execute(id: 1))
  print(await markOnDay9.execute(id: 2))
  print(await MarkBookAsRead(store: store, today: 12).execute(id: 1))
  print(await markOnDay9.execute(id: 3))
  print("writes: \(await store.writes)")
output: |
  1: finished on day 9
  2: already read on day 5
  1: already read on day 9
  3: not found
  writes: 1
solution: |
  - Book 1 is unread; the rule sets day 9 and the use case saves it (write 1).
  - Book 2 was finished on day 5; `markAsRead` throws before changing anything, and nothing is saved.
  - Book 1 again, with a use case whose "today" is 12: the stored copy now has day 9, so the rule throws and reports day 9.
  - Book 3 doesn't exist.

  ```output
  1: finished on day 9
  2: already read on day 5
  1: already read on day 9
  3: not found
  writes: 1
  ```

  Because the rule lives in the entity and runs before `save`, a rejected change never reaches storage. Any `BookStore` implementation gets that guarantee for free. (Returning strings from a use case is only for the exercise's output; a real use case returns the book or throws.)
````

````exercise
id: m32-l04-e3
type: solve
prompt: "Add rating to the reading list, Clean-style. In the entity, add `private(set) var rating: Int?` to `Book` and `mutating func rate(_ stars: Int) throws`, which throws `.notRead` if the book isn't read and `.outOfRange` unless 1...5. Write a `RateBook` use case with `execute(id:stars:)` that loads through `BookStore`, applies the rule, saves and returns the book; it throws `RateBookError.notFound` for a missing id and passes the entity's errors through. Test it with an in-memory store: rate a read book 4, rate an unread book, rate with 6 stars, rate a missing book. Print each outcome and the number of saves."
starter: |
  protocol BookStore: Sendable {
      func book(id: Int) async throws -> Book?
      func save(_ book: Book) async throws
  }

  struct Book: Sendable {
      let id: Int
      let title: String
      let isRead: Bool
      // Add rating and rate(_:).
  }

  // Write RateBook, an in-memory store and the test.
rubric:
  - The 1...5 and must-be-read rules live in the entity, and rating can't be set from outside without them.
  - The use case depends only on the BookStore protocol and saves only after the rule passes.
  - Missing books produce the use case's own error.
  - The output shows exactly one save.
solution: |
  ```swift
  protocol BookStore: Sendable {
      func book(id: Int) async throws -> Book?
      func save(_ book: Book) async throws
  }

  struct Book: Sendable {
      enum RatingError: Error {
          case notRead
          case outOfRange
      }

      let id: Int
      let title: String
      let isRead: Bool
      private(set) var rating: Int?

      init(id: Int, title: String, isRead: Bool) {
          self.id = id
          self.title = title
          self.isRead = isRead
      }

      mutating func rate(_ stars: Int) throws {
          guard isRead else { throw RatingError.notRead }
          guard (1...5).contains(stars) else { throw RatingError.outOfRange }
          rating = stars
      }
  }

  enum RateBookError: Error {
      case notFound
  }

  struct RateBook: Sendable {
      let store: any BookStore

      func execute(id: Int, stars: Int) async throws -> Book {
          guard var book = try await store.book(id: id) else {
              throw RateBookError.notFound
          }
          try book.rate(stars)
          try await store.save(book)
          return book
      }
  }

  actor InMemoryBookStore: BookStore {
      private var books: [Int: Book]
      private(set) var saves = 0

      init(_ books: [Book]) {
          self.books = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
      }

      func book(id: Int) -> Book? { books[id] }

      func save(_ book: Book) {
          books[book.id] = book
          saves += 1
      }
  }

  let store = InMemoryBookStore([
      Book(id: 1, title: "Kindred", isRead: true),
      Book(id: 2, title: "Piranesi", isRead: false),
  ])
  let rateBook = RateBook(store: store)

  for (id, stars) in [(1, 4), (2, 5), (1, 6), (9, 3)] {
      do {
          let book = try await rateBook.execute(id: id, stars: stars)
          print("\(book.title): \(book.rating ?? 0) stars")
      } catch {
          print("book \(id), \(stars) stars: \(error)")
      }
  }
  print("saves: \(await store.saves)")
  ```

  ```output
  Kindred: 4 stars
  book 2, 5 stars: notRead
  book 1, 6 stars: outOfRange
  book 9, 3 stars: notFound
  saves: 1
  ```

  `rating` is `private(set)`, so the only way to change it is `rate(_:)`, and the rules can't be skipped. The use case is short but not a pass-through: it orchestrates load, rule and save, and maps "missing" to its own error. The view model would turn `notRead` into "Finish the book before rating it" and `outOfRange` into nothing at all, since its star control can't produce a 6.
````

````exercise
id: m32-l04-e4
type: find-errors
prompt: "A use case from a code review. Which comments are real problems?"
code: |
  import Foundation
  import SwiftData

  struct ArchiveFinishedBooks {
      let context: ModelContext

      func execute() throws -> String {
          let finished = try context.fetch(FetchDescriptor<BookRecord>(
              predicate: #Predicate { $0.finishedAt != nil }
          ))
          for record in finished where record.finishedAt! < Date().addingTimeInterval(-365 * 86_400) {
              record.isArchived = true
          }
          try context.save()
          return "Archived \(finished.count) books"
      }
  }
choices:
  - text: "It imports SwiftData and takes a ModelContext, so it depends on the outermost ring."
    correct: true
    why: "Define a BookStore gateway; a SwiftData adapter implements it."
  - text: "It reads Date() directly, so the one-year rule can't be tested at a fixed time."
    correct: true
    why: "Inject now, as in the lesson's use cases."
  - text: "It returns a display string."
    correct: true
    why: "Return the archived books or a count; the view model formats it."
  - text: "The message counts every finished book, not just the ones it archived."
    correct: true
    why: "A real bug, and one that a test against the returned count would catch once the count is data."
  - text: "Use cases can't throw."
    correct: false
    why: "They can and usually do; the adapter maps errors to UI."
rubric:
  - Finds the framework dependency.
  - Finds the hidden clock.
  - Finds the formatting in the use case.
  - Finds the wrong count.
solution: |
  All four are real. A cleaned-up version: `struct ArchiveFinishedBooks { let store: any BookStore; let now: @Sendable () -> Date }` with `execute() async throws -> [Book]`, where the "older than a year" check is an entity method (`book.isArchivable(now:)`) and archiving is `book.archive()`. The use case loads, filters with the rule, saves each changed book and returns them; the view model shows "Archived 3 books". Also note the year as `365 * 86_400` seconds ignores leap years; with the calendar injected, `calendar.date(byAdding: .year, value: -1, to: now)` is the precise version.
````

````exercise
id: m32-l04-e5
type: comprehension
prompt: "For which of these features does Clean Architecture's full structure (entities, use cases with gateways, adapters) pay off most clearly?"
choices:
  - text: "A budgeting feature that splits shared expenses between people, with rounding rules, currencies, and the same actions available from the app, a widget and Shortcuts."
    correct: true
    why: "Many rules to test thoroughly, and several delivery mechanisms that can share the use cases."
  - text: "A feedback form that sends three text fields to an endpoint."
    correct: false
    why: "There's almost no rule; a view model calling an API client is enough."
  - text: "A static About screen."
    correct: false
    why: "No data flow at all."
  - text: "A settings screen with four toggles stored in UserDefaults."
    correct: false
    why: "A typed settings struct (Module 31) and a view are enough."
solution: |
  The budgeting feature has what makes the rings worth their cost: real rules (splitting, rounding, currency conversion) that need many fast tests, and three entry points that should behave identically. The other three have little or no logic, so use cases would be pass-throughs.
````

````exercise
id: m32-l04-e6
type: explain
prompt: "A teammate argues: \"Our LoadBooks use case just calls store.allBooks(). It's pointless; let's delete all our use cases and have view models call the stores.\" Explain how you'd respond, using the reading list as an example."
code: |
  struct LoadBooks {
      let store: any BookStore
      func execute() async throws -> [Book] { try await store.allBooks() }
  }

  struct MarkBookAsRead {
      let store: any BookStore
      let now: @Sendable () -> Date
      func execute(id: Int) async throws -> Book {
          guard var book = try await store.book(id: id) else { throw MarkAsReadError.notFound }
          try book.markAsRead(at: now())
          try await store.save(book)
          return book
      }
  }
rubric:
  - Agrees that LoadBooks is a pass-through and can go (or gain a rule).
  - Points out that MarkBookAsRead orchestrates load, rule and save, and holds the injected clock.
  - Explains what moves into view models if all use cases are deleted (orchestration duplicated across screens, widget and intents).
  - Proposes a rule for when a use case exists.
solution: |
  They're right about `LoadBooks`: it has no rule and no orchestration, so the view model can call `store.allBooks()` directly, unless ordering and goal counting move in, as in the lesson's `LoadReadingList`.

  `MarkBookAsRead` is different. It loads, applies the entity's rule with an injected time, and saves only if the rule passed. Delete it and that sequence moves into the reading list view model, and then gets copied into the book detail view model, the widget's intent and the Shortcuts action. Each copy can drift: one forgets to inject the clock, another saves before checking.

  A workable team rule: a use case exists when it orchestrates (more than one gateway call, a rule between them, or a side effect like analytics) or is shared by more than one entry point. Otherwise the view model talks to the gateway directly. That keeps the rings without the empty types.
````

## Summary

- Clean Architecture arranges code in rings: **entities**, **use cases**, **interface adapters**, **frameworks and drivers**.
- **The dependency rule:** source code dependencies point only inward. Inner rings declare protocols (gateways) for what they need; outer rings implement them.
- Entities enforce rules (`markAsRead` throws if already read, with `private(set)` state); use cases orchestrate load, rule and save, with time and calendar injected; gateways only store.
- Adapters convert in both directions: view models turn use case output into display state; DTOs and their mapping keep the API's shape out of the entities.
- It pays off with rule-heavy domains, several entry points and long-lived codebases. A use case that only forwards one call is a sign the structure is ahead of the problem.
