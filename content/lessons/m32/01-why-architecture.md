---
id: m32-l01
title: Why architecture matters
description: "What app architecture is for and what it costs. You name the three problems it solves (testing, change and team size), sort code into domain, presentation and infrastructure, meet the reading list feature that the rest of the module rebuilds in five styles, and learn to spot structure that costs more than it saves."
module: m32
order: 1
level: advanced
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m31-l06]
objectives:
  - Explain what an app's architecture decides and which three problems it addresses.
  - Sort a feature's code into domain, presentation and infrastructure, and say which way the dependencies point.
  - Predict which layer a given change request touches when the layers are drawn well.
  - Recognize architecture that adds indirection without buying a test, a second implementation or a safer change.
terms:
  - term: Architecture
    definition: "The decisions about where each kind of code lives, what each part may know about the others, and how data and events move between them. In an app, mostly: who holds state, who decides, who talks to the outside world."
  - term: Domain layer
    definition: "The types and rules that describe what the app is about (books, reading progress, what counts as read), written in plain Swift with no UI, networking or storage code."
  - term: Presentation layer
    definition: "The code that turns domain values into what a screen shows and turns user actions into calls: view controllers, views, view models, presenters."
  - term: Infrastructure layer
    definition: "The code that talks to the outside world: network clients, databases, the Keychain, the file system, analytics SDKs. It implements protocols the inner layers define."
  - term: Seam
    definition: "A place where one implementation can be swapped for another without editing the code that uses it, usually a protocol or a closure received in an initializer."
mastery:
  - Given ten lines of a feature, label each as domain, presentation or infrastructure.
  - Draw the reading list feature's layers and point every arrow inward.
  - "For a change request (\"the API renamed a field\", \"show unread books first\"), name the one layer that should change."
  - Point at a protocol with one conforming type and no test double and argue whether it should stay.
resources: [swift-book-protocols, swift-book-access-control, swift-actor]
cards:
  - id: m32-l01-c1
    front: What three problems does app architecture address?
    back: "Testability (can you check the logic without a device, a network or a screen?), change (does a new requirement touch one place or ten?) and team scale (can several people work on the app without editing the same files?)."
  - id: m32-l01-c2
    front: Name the three layers and what goes in each.
    back: "Domain: types and rules of the problem, plain Swift. Presentation: what screens show and how they react to the user. Infrastructure: network, storage, system services, behind protocols."
  - id: m32-l01-c3
    front: Which way do the dependencies between layers point?
    back: "Inward, toward the domain. Presentation uses the domain; infrastructure implements protocols the domain (or the feature) defines. The domain imports neither."
  - id: m32-l01-c4
    front: When is a layer or protocol not worth adding?
    back: "When it has one implementation, no test uses a substitute, and no change it would isolate is on the horizon. Then it's indirection: one more file to read and keep in sync for nothing."
---

## The idea in one sentence

An app's architecture decides **where each kind of code lives and what it's allowed to know**, so that logic can be tested without a screen, a change lands in one place, and several people can work on the app without tripping over each other.

> [!note] About this module's code
> The architectures in this module aren't Apple APIs, and there's no official definition of most of them; the descriptions follow common usage. Plain-Swift code (domain types, view models, presenters, use cases, repositories, composition roots and their tests) was compiled and run with Swift 6.3 on Linux. UIKit and SwiftUI blocks are type-checked against the iOS 17 SDK on the CI runner, not run. Nothing was checked in Xcode or the simulator.

## What architecture is for

Modules 14, 25 and 30 gave you the parts: single responsibility and dependency inversion, coordinators for navigation, repositories behind protocols. This module puts them together and compares the common ways of doing it. First, what are we trying to buy?

**Testability.** A rule like "unread books come first" should be checkable in milliseconds, with fake data, in a unit test. If it lives inside `tableView(_:cellForRowAt:)`, the only way to check it is to launch the app and look.

**Change.** Requirements change constantly: the backend renames a field, design wants a new row layout, product wants a reading goal. In a well-divided app, each of those touches one area. In a tangled one, the field rename shows up in three view controllers because each decodes JSON its own way.

**Team scale.** One person can keep a whole app in their head. Five can't. Clear boundaries let one engineer work on the networking layer while another redesigns a screen, with few merge conflicts, and let a new hire find where things go.

None of these is free. Every boundary is a protocol to define, a file to open, a hop to follow when you read the code. Architecture is a trade: you pay in indirection now to make testing and change cheaper later. The rest of the module is about making that trade on purpose.

## Three layers

Almost every iOS architecture, whatever its name, separates the same three kinds of code. Module 14 called them UI, logic and data; the usual names in app architecture are:

```text
┌──────────────────────────────────────────────┐
│ Presentation                                 │  view controllers, views,
│ shows state, forwards user actions           │  view models, presenters
└──────────────────────┬───────────────────────┘
                       │ uses
┌──────────────────────▼───────────────────────┐
│ Domain                                       │  Book, rules like "unread
│ the app's types and rules, plain Swift       │  first", BookRepository
│ defines the protocols it needs               │  (the protocol)
└──────────────────────▲───────────────────────┘
                       │ implements
┌──────────────────────┴───────────────────────┐
│ Infrastructure                               │  URLSession client, SwiftData
│ network, storage, system services            │  store, Keychain, analytics
└──────────────────────────────────────────────┘
```

- **Domain** knows nothing about UIKit, SwiftUI, `URLSession` or SwiftData. That's what makes it fast to test and stable: it changes only when the rules of the problem change.
- **Presentation** knows the domain. It doesn't know which database or server is behind `BookRepository`.
- **Infrastructure** knows the domain too, but only to implement its protocols and return its types. Nothing in the domain or presentation names a concrete infrastructure type, except the one place that wires the app together (lesson 5).

Both arrows point **toward the domain**. That's the whole trick, and every architecture in this module is a variation on how the presentation layer is split up.

## The feature we'll keep rebuilding

To compare architectures fairly, the module builds one small feature again and again: a **reading list**.

| Behavior | Detail |
| --- | --- |
| Load | Show a loading state, then the books from a repository. |
| Order | Unread books first, then read ones, each group by title. |
| Header | "2 of 4 read". |
| Mark as read | Tapping an unread book marks it read, saves it through the repository and updates the screen. If saving fails, the book stays unread and an error message appears. |
| Error | If loading fails, show "Couldn't load your books." and a Retry button. |

Here are the domain and infrastructure parts, which barely change across the module, plus a few lines of presentation:

```swift
// MARK: Domain

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    var isRead: Bool
}

enum ReadingList {
    /// Unread books first, then read ones; each group sorted by title.
    static func ordered(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            if lhs.isRead != rhs.isRead {
                return !lhs.isRead
            }
            return lhs.title < rhs.title
        }
    }

    static func readCount(_ books: [Book]) -> Int {
        books.filter(\.isRead).count
    }
}

protocol BookRepository: Sendable {
    func books() async throws -> [Book]
    func markAsRead(id: Int) async throws
}

// MARK: Infrastructure (an in-memory stand-in for a real store)

enum RepositoryError: Error {
    case offline
}

actor InMemoryBookRepository: BookRepository {
    private var stored: [Book]
    private var isOffline = false

    init(books: [Book]) {
        stored = books
    }

    func setOffline(_ value: Bool) {
        isOffline = value
    }

    func books() throws -> [Book] {
        guard !isOffline else { throw RepositoryError.offline }
        return stored
    }

    func markAsRead(id: Int) throws {
        guard !isOffline else { throw RepositoryError.offline }
        if let index = stored.firstIndex(where: { $0.id == id }) {
            stored[index].isRead = true
        }
    }
}

// MARK: Presentation (print stands in for a screen)

func header(for books: [Book]) -> String {
    "\(ReadingList.readCount(books)) of \(books.count) read"
}

func row(for book: Book) -> String {
    "\(book.isRead ? "[x]" : "[ ]") \(book.title) by \(book.author)"
}

let repository = InMemoryBookRepository(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    Book(id: 4, title: "Station Eleven", author: "Emily St. John Mandel", isRead: true),
])

let books = ReadingList.ordered(try await repository.books())
print(header(for: books))
for book in books {
    print(row(for: book))
}
```

```output
2 of 4 read
[ ] Piranesi by Susanna Clarke
[ ] The Dispossessed by Ursula K. Le Guin
[x] Kindred by Octavia E. Butler
[x] Station Eleven by Emily St. John Mandel
```

Walk through it by layer:

- **`Book`** is a value type with no behavior that depends on a framework. It's `Sendable` because it crosses from the repository actor to the main actor.
- **`ReadingList.ordered`** is a domain rule. It's a pure function, so testing it is one line: pass books in, compare the result. A caseless enum is just a namespace for the rules.
- **`BookRepository`** is declared with the domain, because the domain decides what it needs ("give me books", "mark one read"), not the database. It's `Sendable` so any isolation domain can hold one (lesson 5 comes back to this).
- **`InMemoryBookRepository`** is infrastructure. In the app it would be the network-and-cache repository from Module 30 or a SwiftData store from Module 31; here it's an actor with an `offline` switch so the error paths can be tested. Its methods are synchronous inside the actor and still satisfy the protocol's `async` requirements, because calls from outside an actor are always awaited.
- **`header` and `row`** are presentation: they turn domain values into text. The domain never builds strings like `"[x]"` or `"2 of 4 read"`; a redesign or a translation shouldn't touch the rules.

In the next lessons, the presentation part grows into view controllers, view models, presenters and use cases. The domain and repository stay as they are, which is the point.

## Where a change lands

A good way to judge an architecture is to take real change requests and see what they touch. With the layers above:

| Change request | Layer that changes |
| --- | --- |
| The API renames `author` to `author_name`. | Infrastructure: the DTO or its coding keys. |
| Show read books first instead. | Domain: `ReadingList.ordered`. |
| Rows show a checkmark image instead of `[x]`. | Presentation: the cell. |
| Store books in SwiftData instead of a JSON file. | Infrastructure: a new `BookRepository` conformance. |
| Translate the screen into Spanish. | Presentation: the strings. |

If the answer to a row is "three layers", one of them knows something it shouldn't. That's the most useful test you can apply to any architecture, including the ones in this module.

## When architecture costs more than it saves

The opposite failure is just as common. Here's a settings toggle, built with every layer someone once read about:

```swift illustrative
protocol NotificationsToggleViewInput: AnyObject { func show(isOn: Bool) }
protocol NotificationsToggleViewOutput { func didToggle(_ isOn: Bool) }
protocol NotificationsToggleInteractorInput { func save(_ isOn: Bool) }
protocol NotificationsToggleInteractorOutput: AnyObject { func didSave(_ isOn: Bool) }
protocol NotificationsToggleRouterInput { func close() }
final class NotificationsToggleInteractor: NotificationsToggleInteractorInput { /* writes one Bool */ }
final class NotificationsTogglePresenter: NotificationsToggleViewOutput, NotificationsToggleInteractorOutput { /* forwards it */ }
final class NotificationsToggleRouter: NotificationsToggleRouterInput { /* never used */ }
enum NotificationsToggleBuilder { /* wires the four together */ }
```

Five protocols and four types to store one `Bool` in `UserDefaults`. Every protocol has exactly one conformance, no test substitutes any of them, and the next developer has to open nine declarations to find the line that saves. The costs are concrete:

- **Reading cost.** Each hop is a file to open and a name to remember. Following "what happens when I tap this?" goes from one method to five.
- **Change cost.** Adding a second toggle means copying the whole set or generalizing it. Abstractions that guessed wrong are harder to remove than duplicated code is to merge.
- **Onboarding cost.** New people learn the ceremony before they can ship anything.

A useful rule: **add a seam when something needs it**. A second implementation (a fake in a test, a different store), a rule worth testing on its own, a part that changes for different reasons than its neighbor. A settings toggle that writes one value gets a view and a typed settings struct from Module 31, and that's enough. The reading list, with loading, ordering, saving and two error paths, has enough behavior to justify the separation.

> [!tip] Consistency matters too
> In a team app, the same shape everywhere has value on its own: people know where to look. A small screen can follow the team's pattern even if it would be fine without it, as long as the pattern itself is light. What hurts is a pattern so heavy that small screens become expensive.

## Common mistakes

> [!error] Rules inside the view
> "Unread first" written as a `sort` inside `cellForRowAt` or a SwiftUI `body`. It works, and it can only be tested by running the UI. Move it into a domain function the view calls.

> [!error] The domain imports UIKit
> A `Book` with a `UIImage` cover or a `UIColor` status ties the domain to one UI framework and to the main actor. Keep a URL or an enum in the domain; the presentation layer turns it into an image or a color.

> [!error] Infrastructure types leaking upward
> A view model that catches `URLError` or holds a `ModelContext` knows which infrastructure is behind it. The repository should return domain values and its own errors (Module 30).

> [!error] Layers for their own sake
> A protocol per type, a use case that only forwards one call, a router that never routes. If nothing substitutes it and no test needs it, it's indirection, not architecture.

## Exercises

````exercise
id: m32-l01-e1
type: comprehension
prompt: "In the reading list, where does the rule \"a book counts toward the yearly goal only if it was finished this calendar year\" belong?"
choices:
  - text: "In the domain, as a function on books and dates."
    correct: true
    why: "It's a rule of the problem, independent of how it's shown or stored. A pure function makes it testable with fixed dates."
  - text: "In the view controller, where the header label is set."
    correct: false
    why: "Then it's only testable through the UI, and a SwiftUI version of the screen would need its own copy."
  - text: "In the repository, which can filter the books before returning them."
    correct: false
    why: "The repository decides where data comes from, not what it means. Another screen showing all books would get a filtered list."
  - text: "In the JSON decoder, so books outside the year never reach the app."
    correct: false
    why: "That throws data away at the edge and mixes a business rule into parsing."
solution: |
  It's a domain rule. Write it as a plain function, something like `ReadingGoal.countsTowardGoal(_ book: Book, year: Int) -> Bool`, and pass the year in rather than reading the current date inside, so a test can check December 31 and January 1 without changing the device clock. The view shows the result; the repository only supplies the books and their finish dates.
````

````exercise
id: m32-l01-e2
type: comprehension
multiple: true
prompt: "The reading list uses the three layers from this lesson. Which of these changes should touch only the infrastructure layer? Select all that apply."
choices:
  - text: "The server starts returning dates as Unix timestamps instead of ISO 8601 strings."
    correct: true
    why: "Decoding is infrastructure. The domain still receives Date values."
  - text: "Books move from a JSON file to SwiftData."
    correct: true
    why: "A new BookRepository conformance. Nothing above the protocol changes."
  - text: "Read books should be hidden instead of listed at the end."
    correct: false
    why: "That's a rule about the list, so it's domain (or presentation, if it's only a display choice), not infrastructure."
  - text: "The header should say \"Halfway there!\" when exactly half the books are read."
    correct: false
    why: "That's presentation text, possibly backed by a domain rule for \"half\"."
  - text: "Requests need a new authentication header."
    correct: true
    why: "The API client changes; no caller knows how requests are authenticated."
solution: |
  The date format, the storage technology and authentication are all details of how data gets in and out, so they belong to infrastructure. Hiding read books and new header text are about what the user sees and what the list means, which live above the repository protocol. If one of the first three changes ever requires editing a view model, something from infrastructure has leaked upward.
````

````exercise
id: m32-l01-e3
type: prediction
prompt: "The ordering rule from the lesson, applied to a different list. What does the program print?"
code: |
  struct Book {
      let title: String
      var isRead: Bool
  }

  func ordered(_ books: [Book]) -> [Book] {
      books.sorted { lhs, rhs in
          if lhs.isRead != rhs.isRead {
              return !lhs.isRead
          }
          return lhs.title < rhs.title
      }
  }

  var books = [
      Book(title: "Middlemarch", isRead: true),
      Book(title: "Beloved", isRead: false),
      Book(title: "Dune", isRead: true),
      Book(title: "Anathem", isRead: false),
  ]
  print(ordered(books).map(\.title))
  books[1].isRead = true
  print(ordered(books).map(\.title))
  print(ordered(books).filter(\.isRead).count)
output: |
  ["Anathem", "Beloved", "Dune", "Middlemarch"]
  ["Anathem", "Beloved", "Dune", "Middlemarch"]
  3
solution: |
  - First call: the unread books are "Beloved" and "Anathem", sorted by title: `"Anathem" < "Beloved"`. Then the read ones: "Dune", "Middlemarch". The comparison only looks at titles when both books have the same `isRead`.
  - `books[1]` is "Beloved" (index 1 in the original array, not in the sorted one). Marking it read moves it to the read group, where it sorts before "Dune". The printed order happens to be the same, but for a different reason: "Beloved" is now the first read book, not the last unread one.
  - Three books are read: Beloved, Dune, Middlemarch.

  ```output
  ["Anathem", "Beloved", "Dune", "Middlemarch"]
  ["Anathem", "Beloved", "Dune", "Middlemarch"]
  3
  ```

  The second line is a reminder that comparing printed output can hide a change in meaning. A unit test that checks which group each book is in would catch a broken rule here; one that compares only the title order wouldn't.
````

````exercise
id: m32-l01-e4
type: solve
prompt: "Add a \"next up\" feature, keeping the layers apart. In the domain, write `ReadingList.nextUp(_ books: [Book]) -> Book?`: the unread book with the lowest `id`, or `nil` when everything is read. In presentation, write `nextUpText(for books: [Book]) -> String` that returns `\"Next up: <title>\"` or `\"All caught up\"`. Load the books from `InMemoryBookRepository`, print the text, mark the next book as read through the repository, reload, and repeat until it prints \"All caught up\"."
starter: |
  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
      var isRead: Bool
  }

  protocol BookRepository: Sendable {
      func books() async throws -> [Book]
      func markAsRead(id: Int) async throws
  }

  actor InMemoryBookRepository: BookRepository {
      private var stored: [Book]
      init(books: [Book]) { stored = books }
      func books() -> [Book] { stored }
      func markAsRead(id: Int) {
          if let index = stored.firstIndex(where: { $0.id == id }) {
              stored[index].isRead = true
          }
      }
  }

  // Write ReadingList.nextUp, nextUpText and the loop.
rubric:
  - nextUp is a pure domain function that returns a Book? and contains no display text.
  - nextUpText is the only place that builds the strings.
  - The loop goes through the repository protocol to read and to mark books, not by editing an array directly.
  - The output ends with "All caught up".
solution: |
  ```swift
  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
      var isRead: Bool
  }

  protocol BookRepository: Sendable {
      func books() async throws -> [Book]
      func markAsRead(id: Int) async throws
  }

  actor InMemoryBookRepository: BookRepository {
      private var stored: [Book]
      init(books: [Book]) { stored = books }
      func books() -> [Book] { stored }
      func markAsRead(id: Int) {
          if let index = stored.firstIndex(where: { $0.id == id }) {
              stored[index].isRead = true
          }
      }
  }

  // Domain
  enum ReadingList {
      static func nextUp(_ books: [Book]) -> Book? {
          books.filter { !$0.isRead }.min { $0.id < $1.id }
      }
  }

  // Presentation
  func nextUpText(for books: [Book]) -> String {
      if let book = ReadingList.nextUp(books) {
          return "Next up: \(book.title)"
      }
      return "All caught up"
  }

  let repository: any BookRepository = InMemoryBookRepository(books: [
      Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
      Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
      Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
  ])

  var books = try await repository.books()
  print(nextUpText(for: books))
  while let next = ReadingList.nextUp(books) {
      try await repository.markAsRead(id: next.id)
      books = try await repository.books()
      print(nextUpText(for: books))
  }
  ```

  ```output
  Next up: The Dispossessed
  Next up: Piranesi
  All caught up
  ```

  `nextUp` returns a `Book?`, not a string, so another screen (a widget, say) can show it differently, and a test can check `nextUp(books)?.id == 2`. The loop uses `nextUp` itself as its condition, so the rule lives in one place. Declaring `repository` as `any BookRepository` makes the loop use only what the protocol offers, which is what a view model would see.
````

````exercise
id: m32-l01-e5
type: explain
prompt: "A teammate proposes this for every new screen: a protocol for the view, one for the presenter, one for the interactor and one for the router, plus a builder, \"so the codebase is consistent\". The next screen is an About page with the app version and two links. Explain what you'd say."
code: |
  protocol AboutViewInput: AnyObject { func show(version: String) }
  protocol AboutViewOutput { func viewDidLoad(); func didTapLink(_ index: Int) }
  protocol AboutInteractorInput { func loadVersion() }
  protocol AboutInteractorOutput: AnyObject { func didLoadVersion(_ version: String) }
  protocol AboutRouterInput { func open(_ url: URL) }
rubric:
  - Acknowledges that consistency has real value in a team.
  - Points out that the About page has no logic to test and no second implementation of any protocol.
  - Names concrete costs (files to read, hops to follow, protocols to keep in sync).
  - Proposes something lighter that stays recognizable, such as a view controller plus a small view model, and a rule for when the full set is warranted.
solution: |
  Consistency is a fair goal: people should know where to look. But this pattern makes the About page cost the same as the checkout flow. Of the five protocols, none will ever have a second conforming type, and there's no rule worth a unit test: the version comes from the bundle, and the links are constants. Reading "what happens when I tap the privacy link?" means following `AboutViewOutput` to the presenter, to `AboutRouterInput`, to the router.

  A better team rule is a light default that scales up: a view controller (or SwiftUI view) with a small view model for any screen with state, and a presenter, use case or coordinator added when the screen has logic to test or navigation that branches. The About page gets a view and, if you like, a struct with the version string and URLs. The structure stays recognizable, and the cost matches the screen.
````

````exercise
id: m32-l01-e6
type: design
prompt: "You're starting a small app alone: a habit tracker with a list of habits, a check-in button per habit, a streak count, local storage now and maybe sync later. Describe the layers you'd set up on day one, which protocols you'd create and which you'd deliberately not create yet."
rubric:
  - Puts Habit, check-ins and the streak calculation in a domain layer with no framework imports.
  - Puts storage behind one repository protocol, because sync later is a known second implementation and tests need a fake.
  - Keeps presentation light (a view model or controller per screen) and doesn't add use cases or routers without a reason.
  - Says what would trigger adding more structure later (sync, a second screen editing the same data, a second developer).
solution: |
  A reasonable day-one plan:

  - **Domain:** `Habit`, `CheckIn` and a pure `Streak.current(checkIns:today:)` function. The streak rule has real edge cases (time zones, missed days, two check-ins on one day), so it gets unit tests from the start, with `today` passed in.
  - **One protocol:** `HabitRepository` with load, add and check in. It has a second implementation immediately (an in-memory fake for tests and previews) and a likely third (a syncing one), so it pays for itself.
  - **Presentation:** one view model per screen holding state and inputs, with the repository injected.
  - **Not yet:** use case types (the view model can call the repository and the streak function directly), coordinators (two screens), modules (one developer, one target), a container for dependencies (the app's entry point creates the repository and passes it down).

  What would change the plan: sync arriving (the repository grows a remote side, and conflict rules may deserve use cases), several screens editing habits (shared logic moves out of view models), or a second developer (feature folders and maybe a package for the domain).
````

## Summary

- Architecture decides where code lives and what each part may know. It buys testability, contained change and room for a team, and it costs indirection.
- Most iOS architectures share three layers: **domain** (plain Swift types and rules), **presentation** (what screens show and how they react) and **infrastructure** (network, storage, system services). Dependencies point toward the domain.
- The domain defines the protocols it needs, such as `BookRepository`; infrastructure implements them.
- Judge a structure by where real change requests land. One request, one layer.
- Add a seam when a test, a second implementation or a different reason to change needs it. Protocols with one conformance and no test double are usually just cost.
- The reading list feature (load, order, mark as read, error state) is rebuilt in each of the next lessons, with the domain and repository unchanged.
