---
id: m33-l03
title: "Test doubles: dummies, stubs, fakes, spies and mocks"
description: "Replace a view model's dependencies with test doubles, using Gerard Meszaros's five kinds: dummies that fill parameters, stubs with canned answers, spies that record calls, mocks that check calls against expectations, and fakes that really work. You build each one by hand behind the reading list's protocols, and see how tests that check every interaction break on harmless refactors."
module: m33
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l02]
objectives:
  - Define dummy, stub, spy, mock and fake in Meszaros's terms, and classify a given double.
  - Build each kind by hand as a type that conforms to a dependency protocol, with Swift 6 concurrency rules satisfied.
  - Choose the double that matches what a test checks, state or interaction.
  - Recognize over-mocking and rewrite an over-specified test to check outcomes.
terms:
  - term: Test double
    definition: "Meszaros's generic term for any object that replaces a production dependency in a test, like a stunt double replaces an actor."
  - term: Dummy
    definition: "A double passed to satisfy a parameter and never used. If it's called, the test is exercising more than it thinks."
  - term: Stub
    definition: "A double that answers calls with canned values (or errors) chosen by the test, so the code under test takes a particular path."
  - term: Spy
    definition: "A stub that also records how it was called, so the test can check the calls afterward."
  - term: Mock
    definition: "A double programmed in advance with the calls it should receive, which checks the actual calls against them and reports unexpected, wrong or missing ones."
  - term: Fake
    definition: "A double with a working implementation that takes a shortcut unsuitable for production, such as an in-memory repository instead of a server."
  - term: Over-mocking
    definition: "Specifying more interactions than the behavior under test requires, so tests break when the implementation changes even though the behavior didn't."
mastery:
  - Name the kind of double from its code, and say what a test using it can check.
  - Write a dummy, a stub, a spy, a mock and a fake for a Sendable repository protocol and a main-actor analytics protocol.
  - Fix "stored property ... of 'Sendable'-conforming class ... is mutable" in a spy by making it an actor.
  - Rewrite a test that verifies call sequences into one that checks state, and explain what it no longer catches.
resources: [swift-book-protocols, swift-actor, swift-sendable, swift-testing-docs]
cards:
  - id: m33-l03-c1
    front: Dummy, stub, spy, mock, fake?
    back: "Dummy: fills a parameter, never used. Stub: canned answers. Spy: a stub that records calls for the test to check. Mock: expects specific calls up front and checks them itself. Fake: a working shortcut implementation, like an in-memory repository."
  - id: m33-l03-c2
    front: Spy or mock, what's the difference?
    back: "Both check calls. A spy records and the test asserts afterward on what it cares about. A mock is told in advance exactly which calls to expect and verifies all of them, so it fails on any extra, missing or reordered call."
  - id: m33-l03-c3
    front: "Fix: stored property 'calls' of 'Sendable'-conforming class 'SpyRepository' is mutable"
    back: "The protocol is Sendable, so the spy's mutable log needs protection. Make the spy an actor (callers already await the protocol's async methods), or isolate it to the main actor if the protocol is @MainActor."
  - id: m33-l03-c4
    front: What is over-mocking, and what's the alternative?
    back: "Tests that verify every interaction (call counts, order) instead of the outcome. They break on harmless refactors. Prefer checking state through a fake or stubbed dependency, and check interactions only when the interaction is the behavior, like sending an analytics event."
---

## The idea in one sentence

A test double replaces one of the code's dependencies so a test controls what goes in and can see what comes out, and the five kinds (dummy, stub, spy, mock, fake) differ in exactly that: whether the double answers, records, checks or really works.

## Why doubles

Module 32 gave the reading list's view model its dependencies through its initializer, as protocols. That is what makes it testable: a test passes in something other than the real network repository. In this lesson the view model gets a second dependency, an analytics tracker, so there's something besides data to check:

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

@MainActor
final class ReadingListViewModel {
    struct Row: Equatable {
        let id: Int
        let title: String
        let isRead: Bool
    }

    enum State: Equatable {
        case loading
        case loaded(header: String, rows: [Row])
        case failed(message: String)
    }

    private(set) var state = State.loading {
        didSet { onChange?() }
    }
    private(set) var alertMessage: String? {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?

    private let repository: any BookRepository
    private let analytics: any AnalyticsTracker
    private var books: [Book] = []

    init(repository: any BookRepository, analytics: any AnalyticsTracker) {
        self.repository = repository
        self.analytics = analytics
    }

    func load() async {
        state = .loading
        do {
            books = try await repository.books()
            state = Self.loadedState(for: books)
            analytics.track(.listLoaded(count: books.count))
        } catch {
            state = .failed(message: "Couldn't load your books.")
        }
    }

    func didSelect(id: Int) async {
        guard let book = books.first(where: { $0.id == id }), !book.isRead else { return }
        do {
            try await repository.markAsRead(id: id)
            if let index = books.firstIndex(where: { $0.id == id }) {
                books[index].isRead = true
            }
            state = Self.loadedState(for: books)
            analytics.track(.bookFinished(id: id))
        } catch {
            alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
            analytics.track(.saveFailed(id: id))
        }
    }

    func alertDismissed() {
        alertMessage = nil
    }

    private static func loadedState(for books: [Book]) -> State {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        let rows = ordered.map { Row(id: $0.id, title: $0.title, isRead: $0.isRead) }
        return .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
    }
}

struct PreviewRepository: BookRepository {
    func books() async throws -> [Book] {
        [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]
    }

    func markAsRead(id: Int) async throws {}
}

struct PrintingAnalytics: AnalyticsTracker {
    func track(_ event: AnalyticsEvent) {
        print("analytics: \(event)")
    }
}

let viewModel = ReadingListViewModel(repository: PreviewRepository(), analytics: PrintingAnalytics())
await viewModel.load()
await viewModel.didSelect(id: 1)
if case .loaded(let header, let rows) = viewModel.state {
    print(header, rows.map(\.isRead))
}
```

```output
analytics: listLoaded(count: 1)
analytics: bookFinished(id: 1)
1 of 1 read [true]
```

`PreviewRepository` and `PrintingAnalytics` are already test doubles, of a loose kind. The vocabulary below makes the differences precise.

`BookRepository` is `Sendable` because the view model, on the main actor, hands it to async calls that may run elsewhere. `AnalyticsTracker` is `@MainActor`: the view model calls it synchronously from the main actor, and analytics calls are cheap. Those two choices shape the doubles below.

## The vocabulary

The names come from Gerard Meszaros's book *xUnit Test Patterns* (2007). Martin Fowler's [summary](https://martinfowler.com/bliki/TestDouble.html) of the list is the most quoted one:

> **Dummy** objects are passed around but never actually used. **Fake** objects actually have working implementations, but usually take some shortcut which makes them not suitable for production. **Stubs** provide canned answers to calls made during the test. **Spies** are stubs that also record some information based on how they were called. **Mocks** are pre-programmed with expectations which form a specification of the calls they are expected to receive.

The generic term is **test double**. In everyday speech, many people say "mock" for all of them, and many Swift code bases name every double `MockSomething`. Using the precise words helps when you discuss a test: "stub the repository to fail and spy on analytics" says exactly what the test controls and what it checks.

In the rest of the lesson each kind is built by hand. Swift has no built-in mocking library, and you don't need one: a double is a type that conforms to the protocol.

> [!note] Where the code runs
> Each double is shown in a block that runs it directly, and the lesson ends with a block that runs all of them against the view model. The Swift Testing suites that use them were built and run with `swift test` (Swift 6.3, Linux), with the doubles in the test target; in those files each double starts with `@testable import Bookshelf`.

## Dummy

A dummy exists to satisfy a parameter in a test that never uses it. Checking the view model's initial state doesn't touch either dependency, so both can be dummies:

```swift runtime-error DummyRepository.books() was called
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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

/// Dummy: fills a parameter. Any call means the test is wrong about what it exercises.
struct DummyRepository: BookRepository {
    func books() async throws -> [Book] {
        fatalError("DummyRepository.books() was called")
    }

    func markAsRead(id: Int) async throws {
        fatalError("DummyRepository.markAsRead(id:) was called")
    }
}

struct DummyAnalytics: AnalyticsTracker {
    func track(_ event: AnalyticsEvent) {
        fatalError("DummyAnalytics.track(_:) was called with \(event)")
    }
}

let dummy = DummyRepository()
print("created a dummy")
_ = try await dummy.books()
print("never printed")
```

```output
created a dummy
```

The dummy's methods call `fatalError`, so if the test turns out to use the dependency, it stops with a message naming the call: the program above crashes with the fatal error `DummyRepository.books() was called` after its first line. A dummy that silently returned `[]` would let a test pass while exercising code it didn't intend to. The test:

```swift illustrative
@Test func startsInTheLoadingState() {
    let viewModel = ReadingListViewModel(repository: DummyRepository(), analytics: DummyAnalytics())
    #expect(viewModel.state == .loading)
    #expect(viewModel.alertMessage == nil)
}
```

## Stub

A stub returns what the test tells it to, so the code under test takes a specific path. The failure path of `load()` is hard to reach with a real server and trivial with a stub:

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

/// Stub: returns canned answers chosen by the test.
struct StubRepository: BookRepository {
    var booksResult: Result<[Book], any Error> = .success([])
    var markAsReadResult: Result<Void, any Error> = .success(())

    func books() async throws -> [Book] {
        try booksResult.get()
    }

    func markAsRead(id: Int) async throws {
        try markAsReadResult.get()
    }
}

struct OfflineError: Error {}

let failing = StubRepository(booksResult: .failure(OfflineError()))
do {
    _ = try await failing.books()
} catch {
    print("books() threw \(error)")
}

let twoBooks = StubRepository(booksResult: .success([
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
]))
print(try await twoBooks.books().map(\.title))
try await twoBooks.markAsRead(id: 2)
print(try await twoBooks.books().map(\.isRead))
```

```output
books() threw OfflineError()
["Kindred", "Piranesi"]
[true, false]
```

- The canned answers are `Result` values, so one stub type covers success and failure. `any Error` is `Sendable`, so the struct is too.
- The defaults (`.success([])`, `.success(())`) let a test set only the answer it cares about.
- The last line shows what makes it a stub and not a fake: `markAsRead` succeeds but changes nothing. A stub has no behavior beyond its answers.

## Spy

A spy records what it receives. The test acts, then asserts on the record. Analytics is the classic case, because "an event was sent" is the behavior itself:

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

/// Spy: records the calls it receives so the test can check them afterward.
@MainActor
final class SpyAnalytics: AnalyticsTracker {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

/// A spy can stub at the same time: canned answers in, calls recorded.
actor SpyRepository: BookRepository {
    private let stored: [Book]
    private(set) var markedIDs: [Int] = []

    init(books: [Book]) {
        stored = books
    }

    func books() -> [Book] {
        stored
    }

    func markAsRead(id: Int) {
        markedIDs.append(id)
    }
}

let analytics = SpyAnalytics()
analytics.track(.listLoaded(count: 2))
analytics.track(.bookFinished(id: 2))
print(analytics.events.map { "\($0)" })

let repository = SpyRepository(books: [
    Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
await repository.markAsRead(id: 2)
await repository.markAsRead(id: 2)
print(await repository.markedIDs)
```

```output
["listLoaded(count: 2)", "bookFinished(id: 2)"]
[2, 2]
```

The two spies are isolated differently, following their protocols:

- `SpyAnalytics` is a `@MainActor` class, because `AnalyticsTracker` is a main-actor protocol. Its `events` array is protected by the main actor, and a `@MainActor` test reads it without `await`.
- `SpyRepository` is an **actor**, because `BookRepository` is `Sendable` and its methods are `async`. Its `markAsRead` doesn't need to be marked `async` to satisfy the protocol: calls from outside the actor are asynchronous anyway.

The obvious first attempt, a class with a mutable array, doesn't compile, because a `Sendable` class can't have unprotected mutable state:

```swift no-compile stored property 'markedIDs' of 'Sendable'-conforming class 'SpyRepository' is mutable
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    var isRead: Bool
}

protocol BookRepository: Sendable {
    func books() async throws -> [Book]
    func markAsRead(id: Int) async throws
}

final class SpyRepository: BookRepository {
    var markedIDs: [Int] = []

    func books() async throws -> [Book] {
        []
    }

    func markAsRead(id: Int) async throws {
        markedIDs.append(id)
    }
}

let spy = SpyRepository()
try await spy.markAsRead(id: 2)
print(spy.markedIDs)
```

Swift 6.3: `error: stored property 'markedIDs' of 'Sendable'-conforming class 'SpyRepository' is mutable`. The compiler is right: the view model could call the spy from two tasks at once. Making the spy an actor fixes it without locks. `@unchecked Sendable` would silence the error and leave the race.

In the suite, the spies check outcomes the state can't show: which events were sent, which ids were saved.

```swift illustrative
@Test func tracksHowManyBooksLoaded() async {
    let analytics = SpyAnalytics()
    let viewModel = ReadingListViewModel(
        repository: StubRepository(booksResult: .success(books)),
        analytics: analytics
    )

    await viewModel.load()

    #expect(analytics.events == [.listLoaded(count: 2)])
}

@Test func selectingAnUnreadBookSavesIt() async {
    let repository = SpyRepository(books: books)
    let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())

    await viewModel.load()
    await viewModel.didSelect(id: 2)
    await viewModel.didSelect(id: 1)   // already read: nothing to save

    #expect(await repository.markedIDs == [2])
}
```

## Mock

A mock is told in advance what calls to expect, and checks the actual calls itself. The test's assertion becomes "the mock found no problems":

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

/// Mock: told up front which calls to expect, and checks the calls itself.
@MainActor
final class MockAnalytics: AnalyticsTracker {
    private var expected: [AnalyticsEvent] = []
    private var problems: [String] = []

    func expect(_ events: AnalyticsEvent...) {
        expected.append(contentsOf: events)
    }

    func track(_ event: AnalyticsEvent) {
        guard !expected.isEmpty else {
            problems.append("unexpected \(event)")
            return
        }
        let next = expected.removeFirst()
        if next != event {
            problems.append("expected \(next), got \(event)")
        }
    }

    /// Everything that went wrong, including expected calls that never came.
    func verify() -> [String] {
        problems + expected.map { "missing \($0)" }
    }
}

let analytics = MockAnalytics()
analytics.expect(.listLoaded(count: 2), .bookFinished(id: 2))
analytics.track(.listLoaded(count: 2))
analytics.track(.bookFinished(id: 2))
print(analytics.verify())

let strict = MockAnalytics()
strict.expect(.listLoaded(count: 2), .bookFinished(id: 2))
strict.track(.listLoaded(count: 3))
print(strict.verify())
```

```output
[]
["expected listLoaded(count: 2), got listLoaded(count: 3)", "missing bookFinished(id: 2)"]
```

- **`expect(...)`** records the specification before the code runs.
- **`track(_:)`** compares each call with the next expected one and notes mismatches and surprises.
- **`verify()`** returns everything that went wrong, including expected calls that never happened. In the suite, `#expect(analytics.verify() == [])` prints the list when it fails.

Mocking libraries in other languages generate this kind of class for you. In Swift you write it, and it's short. The difference from the spy is **who decides what matters**: the spy test asserts on the parts of the record it cares about, while the mock fails on any deviation from the full script. That strictness is sometimes what you want ("exactly these two events, in this order") and often more than you want, as the section on over-mocking shows.

## Fake

A fake actually works, with a shortcut. An in-memory repository is a fake: it stores books, `markAsRead` changes them, a later `books()` returns the change. It's the same idea as Module 32's `FakeBookRepository`:

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

struct OfflineError: Error {}

/// Fake: a real, working repository that keeps books in memory instead of on a server.
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
        guard !isOffline else { throw OfflineError() }
        return stored
    }

    func markAsRead(id: Int) throws {
        guard !isOffline else { throw OfflineError() }
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        stored[index].isRead = true
    }
}

let repository = InMemoryBookRepository(books: [
    Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
try await repository.markAsRead(id: 2)
print(try await repository.books().map(\.isRead))
await repository.setOffline(true)
do {
    _ = try await repository.books()
} catch {
    print("offline: \(error)")
}
```

```output
[true]
offline: OfflineError()
```

Fakes are the most useful double for multi-step tests, because the steps interact the way they do in the app: save, reload, see the change. The cost is that a fake has logic, so it can have bugs, and it must keep behaving like the real implementation. Some teams run the same contract tests against the fake and the real repository to keep them honest.

```swift illustrative
@Test func aFailedSaveKeepsTheBookUnread() async {
    let repository = InMemoryBookRepository(books: books)
    let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())
    await viewModel.load()

    await repository.setOffline(true)
    await viewModel.didSelect(id: 2)
    #expect(viewModel.alertMessage == "Couldn't save. \"Piranesi\" is still unread.")

    await repository.setOffline(false)
    await viewModel.load()
    #expect(viewModel.state == .loaded(header: "1 of 2 read", rows: [
        .init(id: 2, title: "Piranesi", isRead: false),
        .init(id: 1, title: "Kindred", isRead: true),
    ]))
}
```

## The whole suite

All six tests together, in one `@MainActor` suite because the view model is main-actor isolated (lesson 2 explained why the annotation is needed):

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct ReadingListViewModelTests {
    let books = [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    ]

    @Test func startsInTheLoadingState() {
        let viewModel = ReadingListViewModel(repository: DummyRepository(), analytics: DummyAnalytics())
        #expect(viewModel.state == .loading)
        #expect(viewModel.alertMessage == nil)
    }

    @Test func showsAnErrorWhenLoadingFails() async {
        let repository = StubRepository(booksResult: .failure(OfflineError()))
        let viewModel = ReadingListViewModel(repository: repository, analytics: DummyAnalytics())

        await viewModel.load()

        #expect(viewModel.state == .failed(message: "Couldn't load your books."))
    }

    @Test func tracksHowManyBooksLoaded() async {
        let analytics = SpyAnalytics()
        let viewModel = ReadingListViewModel(
            repository: StubRepository(booksResult: .success(books)),
            analytics: analytics
        )

        await viewModel.load()

        #expect(analytics.events == [.listLoaded(count: 2)])
    }

    @Test func selectingAnUnreadBookSavesIt() async {
        let repository = SpyRepository(books: books)
        let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())

        await viewModel.load()
        await viewModel.didSelect(id: 2)
        await viewModel.didSelect(id: 1)   // already read: nothing to save

        #expect(await repository.markedIDs == [2])
    }

    @Test func finishingABookReportsBothEvents() async {
        let analytics = MockAnalytics()
        analytics.expect(.listLoaded(count: 2), .bookFinished(id: 2))
        let viewModel = ReadingListViewModel(
            repository: StubRepository(booksResult: .success(books)),
            analytics: analytics
        )

        await viewModel.load()
        await viewModel.didSelect(id: 2)

        #expect(analytics.verify() == [])
    }

    @Test func aFailedSaveKeepsTheBookUnread() async {
        let repository = InMemoryBookRepository(books: books)
        let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())
        await viewModel.load()

        await repository.setOffline(true)
        await viewModel.didSelect(id: 2)
        #expect(viewModel.alertMessage == "Couldn't save. \"Piranesi\" is still unread.")

        await repository.setOffline(false)
        await viewModel.load()
        #expect(viewModel.state == .loaded(header: "1 of 2 read", rows: [
            .init(id: 2, title: "Piranesi", isRead: false),
            .init(id: 1, title: "Kindred", isRead: true),
        ]))
    }
}
```

All six passed with `swift test`. The same scenarios, run as a program with the doubles above:

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

enum AnalyticsEvent: Equatable, Sendable {
    case listLoaded(count: Int)
    case bookFinished(id: Int)
    case saveFailed(id: Int)
}

@MainActor
protocol AnalyticsTracker {
    func track(_ event: AnalyticsEvent)
}

@MainActor
final class ReadingListViewModel {
    struct Row: Equatable {
        let id: Int
        let title: String
        let isRead: Bool
    }

    enum State: Equatable {
        case loading
        case loaded(header: String, rows: [Row])
        case failed(message: String)
    }

    private(set) var state = State.loading {
        didSet { onChange?() }
    }
    private(set) var alertMessage: String? {
        didSet { onChange?() }
    }
    var onChange: (() -> Void)?

    private let repository: any BookRepository
    private let analytics: any AnalyticsTracker
    private var books: [Book] = []

    init(repository: any BookRepository, analytics: any AnalyticsTracker) {
        self.repository = repository
        self.analytics = analytics
    }

    func load() async {
        state = .loading
        do {
            books = try await repository.books()
            state = Self.loadedState(for: books)
            analytics.track(.listLoaded(count: books.count))
        } catch {
            state = .failed(message: "Couldn't load your books.")
        }
    }

    func didSelect(id: Int) async {
        guard let book = books.first(where: { $0.id == id }), !book.isRead else { return }
        do {
            try await repository.markAsRead(id: id)
            if let index = books.firstIndex(where: { $0.id == id }) {
                books[index].isRead = true
            }
            state = Self.loadedState(for: books)
            analytics.track(.bookFinished(id: id))
        } catch {
            alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
            analytics.track(.saveFailed(id: id))
        }
    }

    func alertDismissed() {
        alertMessage = nil
    }

    private static func loadedState(for books: [Book]) -> State {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        let rows = ordered.map { Row(id: $0.id, title: $0.title, isRead: $0.isRead) }
        return .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
    }
}

/// Dummy: fills a parameter. Any call means the test is wrong about what it exercises.
struct DummyRepository: BookRepository {
    func books() async throws -> [Book] {
        fatalError("DummyRepository.books() was called")
    }

    func markAsRead(id: Int) async throws {
        fatalError("DummyRepository.markAsRead(id:) was called")
    }
}

struct DummyAnalytics: AnalyticsTracker {
    func track(_ event: AnalyticsEvent) {
        fatalError("DummyAnalytics.track(_:) was called with \(event)")
    }
}

/// Stub: returns canned answers chosen by the test.
struct StubRepository: BookRepository {
    var booksResult: Result<[Book], any Error> = .success([])
    var markAsReadResult: Result<Void, any Error> = .success(())

    func books() async throws -> [Book] {
        try booksResult.get()
    }

    func markAsRead(id: Int) async throws {
        try markAsReadResult.get()
    }
}

/// Spy: records the calls it receives so the test can check them afterward.
@MainActor
final class SpyAnalytics: AnalyticsTracker {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

/// A spy can stub at the same time: canned answers in, calls recorded.
actor SpyRepository: BookRepository {
    private let stored: [Book]
    private(set) var markedIDs: [Int] = []

    init(books: [Book]) {
        stored = books
    }

    func books() -> [Book] {
        stored
    }

    func markAsRead(id: Int) {
        markedIDs.append(id)
    }
}

/// Mock: told up front which calls to expect, and checks the calls itself.
@MainActor
final class MockAnalytics: AnalyticsTracker {
    private var expected: [AnalyticsEvent] = []
    private var problems: [String] = []

    func expect(_ events: AnalyticsEvent...) {
        expected.append(contentsOf: events)
    }

    func track(_ event: AnalyticsEvent) {
        guard !expected.isEmpty else {
            problems.append("unexpected \(event)")
            return
        }
        let next = expected.removeFirst()
        if next != event {
            problems.append("expected \(next), got \(event)")
        }
    }

    /// Everything that went wrong, including expected calls that never came.
    func verify() -> [String] {
        problems + expected.map { "missing \($0)" }
    }
}

struct OfflineError: Error {}

/// Fake: a real, working repository that keeps books in memory instead of on a server.
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
        guard !isOffline else { throw OfflineError() }
        return stored
    }

    func markAsRead(id: Int) throws {
        guard !isOffline else { throw OfflineError() }
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        stored[index].isRead = true
    }
}

let books = [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
]

// Dummies: the initial state uses neither dependency.
let fresh = ReadingListViewModel(repository: DummyRepository(), analytics: DummyAnalytics())
print("dummy:", fresh.state)

// Stub: force the failure path.
let failing = ReadingListViewModel(
    repository: StubRepository(booksResult: .failure(OfflineError())),
    analytics: DummyAnalytics()
)
await failing.load()
if case .failed(let message) = failing.state {
    print("stub:", message)
}

// Spies: record what was sent and saved.
let analytics = SpyAnalytics()
let spyRepository = SpyRepository(books: books)
let spied = ReadingListViewModel(repository: spyRepository, analytics: analytics)
await spied.load()
await spied.didSelect(id: 2)
await spied.didSelect(id: 1)
print("spy:", analytics.events.count, "events, saved", await spyRepository.markedIDs)

// Mock: the full script of expected events.
let mock = MockAnalytics()
mock.expect(.listLoaded(count: 2), .bookFinished(id: 2))
let mocked = ReadingListViewModel(repository: StubRepository(booksResult: .success(books)), analytics: mock)
await mocked.load()
await mocked.didSelect(id: 2)
print("mock problems:", mock.verify())

// Fake: a save that fails, then a reload that shows the truth.
let fake = InMemoryBookRepository(books: books)
let faked = ReadingListViewModel(repository: fake, analytics: SpyAnalytics())
await faked.load()
await fake.setOffline(true)
await faked.didSelect(id: 2)
print("fake alert:", faked.alertMessage ?? "none")
await fake.setOffline(false)
await faked.load()
if case .loaded(let header, _) = faked.state {
    print("fake reload:", header)
}
```

```output
dummy: loading
stub: Couldn't load your books.
spy: 2 events, saved [2]
mock problems: []
fake alert: Couldn't save. "Piranesi" is still unread.
fake reload: 1 of 2 read
```

## Over-mocking

A mock can stand in for anything, including the repository. This test checks that selecting a book makes exactly the calls `books()` then `markAsRead(id: 2)`, next to a test that checks the outcome through a fake:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct SelectingABookTests {
    let books = [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    ]
    let allRead = ReadingListViewModel.State.loaded(header: "2 of 2 read", rows: [
        .init(id: 1, title: "Kindred", isRead: true),
        .init(id: 2, title: "Piranesi", isRead: true),
    ])

    /// Checks how the view model talks to the repository.
    @Test func callsTheRepositoryInOrder() async {
        let repository = MockRepository(books: books, expecting: "books()", "markAsRead(id: 2)")
        let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())

        await viewModel.load()
        await viewModel.didSelect(id: 2)

        let problems = await repository.verify()
        #expect(problems == [])
    }

    /// Checks what the user sees and what was saved.
    @Test func marksTheBookAsRead() async throws {
        let repository = InMemoryBookRepository(books: books)
        let viewModel = ReadingListViewModel(repository: repository, analytics: SpyAnalytics())

        await viewModel.load()
        await viewModel.didSelect(id: 2)

        #expect(viewModel.state == allRead)
        #expect(try await repository.books().allSatisfy(\.isRead))
    }
}
```

`MockRepository` works like `MockAnalytics`, with strings for the calls. Both tests pass. Now a harmless refactor: after saving, the view model reloads the list from the repository instead of patching its local copy, so it picks up changes made elsewhere:

```swift illustrative
try await repository.markAsRead(id: id)
books = try await repository.books()   // refactor: reload instead of patching locally
state = Self.loadedState(for: books)
```

The behavior the user sees is the same. Running both tests again against the refactored view model:

```text
✔ Test marksTheBookAsRead() passed after 0.001 seconds.
✘ Test callsTheRepositoryInOrder() recorded an issue at OverMockingTests.swift:24:9: Expectation failed: (problems → ["unexpected books()"]) == []
✘ Test callsTheRepositoryInOrder() failed after 0.001 seconds with 1 issue.
```

The mock test failed because it specified **how** the view model talks to its repository, which the refactor changed, not **what** the user gets. That's over-mocking: tests coupled to the implementation, which fail on refactors and so stop being a safety net for them. Teams that over-mock learn to update tests mechanically every time they change code, at which point the tests check nothing.

Guidelines that keep doubles useful:

- **Check state when you can, interactions when you must.** "The screen shows 2 of 2 read" and "the repository now has the book as read" are outcomes. "An analytics event was sent" is also an outcome, but one only an interaction can show, so a spy is right there.
- **Prefer stubs and fakes for queries, spies for commands.** A call that only reads (`books()`) needn't be verified: if the code didn't call it, the state would be wrong. A call whose effect is the point (`markAsRead`, `track`) is worth checking.
- **Assert on what matters to the test.** `analytics.events.contains(.bookFinished(id: 2))` survives a new screen-view event; a strict mock script doesn't. Use a strict mock only when the exact sequence is the requirement.
- **Only mock types you own.** That's a heading in Freeman, Pryce, Mackinnon and Walnes's paper [Mock Roles, not Objects](http://jmock.org/oopsla2004.pdf) (2004). Don't double `URLSession` or `FileManager` directly; put them behind your own small protocol (Module 30's transport) and double that. When Apple changes the framework's behavior, your adapter's tests catch it, and your doubles still describe your design.

## Doubles without protocols

Some Swift code bases describe a dependency as a struct of closures instead of a protocol. A double is then just a value with different closures:

```swift
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    var isRead: Bool
}

struct BookClient: Sendable {
    var books: @Sendable () async throws -> [Book]
    var markAsRead: @Sendable (Int) async throws -> Void
}

extension BookClient {
    static func stub(_ books: [Book]) -> BookClient {
        BookClient(books: { books }, markAsRead: { _ in })
    }

    static let unimplemented = BookClient(
        books: { fatalError("books() was called") },
        markAsRead: { _ in fatalError("markAsRead(_:) was called") }
    )
}

let client = BookClient.stub([Book(id: 1, title: "Kindred", isRead: false)])
print(try await client.books().map(\.title))
_ = BookClient.unimplemented
print("a dummy client, unused")
```

```output
["Kindred"]
a dummy client, unused
```

The same vocabulary applies: `stub(_:)` is a stub, `unimplemented` is a dummy. Closures make one-off doubles shorter; protocols make the dependency's shape explicit and let a type implement several related methods with shared state. Either works; the course uses protocols.

## Common mistakes

> [!error] error: stored property 'markedIDs' of 'Sendable'-conforming class 'SpyRepository' is mutable
> A spy for a `Sendable` protocol written as a plain class. Make it an actor, or isolate it to the main actor if the protocol is `@MainActor`. Don't reach for `@unchecked Sendable`: the race it hides can make the spy's record wrong.

> [!error] A dummy that quietly returns values
> `func books() async throws -> [Book] { [] }` named `DummyRepository`. If the test does use it, nothing tells you. Make dummies fail loudly with `fatalError`, or call the type a stub.

> [!error] Verifying every call
> Strict mocks of queries like `books()`. The test breaks when the code adds caching or a reload, though nothing the user sees changed. Check the outcome; spy only on commands whose effect is the point.

> [!error] A fake that drifts from the real thing
> The in-memory repository allows marking a book that doesn't exist, while the server returns 404. Tests pass, the app fails. Keep fakes small, and run shared contract tests against both implementations.

> [!error] Doubling framework types directly
> Subclassing `URLSession` or `UserDefaults` to override a method. The framework's other behavior still runs, and its contract isn't yours to specify. Wrap it in your own protocol and double that.

> [!error] One giant double for every test
> A `MockEverything` with a flag for each scenario. Each test should build the smallest double that drives its path; the double's name should say what it does (`SaveFailingRepository`).

## Exercises

````exercise
id: m33-l03-e1
type: comprehension
prompt: "A test passes this to the view model, loads the list, and then asserts `#expect(await repository.loadCount == 1)`. In Meszaros's terms, what is it?"
code: |
  actor CountingRepository: BookRepository {
      private(set) var loadCount = 0
      func books() -> [Book] {
          loadCount += 1
          return [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]
      }
      func markAsRead(id: Int) {}
  }
choices:
  - text: "A spy: it returns canned answers and records calls for the test to check afterward."
    correct: true
    why: "Canned books plus a record (loadCount) that the test asserts on after acting."
  - text: "A mock, because the test checks how it was called."
    correct: false
    why: "A mock is given its expectations up front and verifies them itself. Here the test inspects a record afterward."
  - text: "A fake, because markAsRead has an implementation."
    correct: false
    why: "An empty markAsRead isn't a working implementation; a fake would actually mark the book."
  - text: "A dummy, because markAsRead does nothing."
    correct: false
    why: "A dummy isn't used at all. This one is called and answers."
solution: |
  It's a spy. The distinction from a mock is where the expectation lives: in the test's assertion after the fact (spy), or programmed into the double before the code runs (mock). Note also that the test is checking a query's call count, which is the kind of interaction test that breaks when someone adds a cache; ask whether "loaded once" is really a requirement.
````

````exercise
id: m33-l03-e2
type: prediction
prompt: "The mock from this lesson, given a script and then some calls. What does the program print?"
code: |
  enum AnalyticsEvent: Equatable, Sendable {
      case listLoaded(count: Int)
      case bookFinished(id: Int)
      case saveFailed(id: Int)
  }

  final class MockAnalytics {
      private var expected: [AnalyticsEvent] = []
      private var problems: [String] = []

      func expect(_ events: AnalyticsEvent...) {
          expected.append(contentsOf: events)
      }

      func track(_ event: AnalyticsEvent) {
          guard !expected.isEmpty else {
              problems.append("unexpected \(event)")
              return
          }
          let next = expected.removeFirst()
          if next != event {
              problems.append("expected \(next), got \(event)")
          }
      }

      func verify() -> [String] {
          problems + expected.map { "missing \($0)" }
      }
  }

  let mock = MockAnalytics()
  mock.expect(.listLoaded(count: 3), .bookFinished(id: 2))
  mock.track(.listLoaded(count: 3))
  mock.track(.saveFailed(id: 2))
  mock.track(.bookFinished(id: 2))
  for problem in mock.verify() {
      print(problem)
  }
  print("\(mock.verify().count) problems")
output: |
  expected bookFinished(id: 2), got saveFailed(id: 2)
  unexpected bookFinished(id: 2)
  2 problems
solution: |
  - `listLoaded(count: 3)` matches the first expectation.
  - `saveFailed(id: 2)` is compared with the next expectation, `bookFinished(id: 2)`, and doesn't match. That expectation is used up anyway.
  - `bookFinished(id: 2)` arrives when nothing is expected any more: "unexpected".
  - Nothing is left in `expected`, so there are no "missing" entries.

  ```output
  expected bookFinished(id: 2), got saveFailed(id: 2)
  unexpected bookFinished(id: 2)
  2 problems
  ```

  One extra event in the middle produced two problems, because a strict sequence mock reports the shift on every later call. That's typical of mocks: precise about order, noisy when the order changes. A spy test that asserted `events.contains(.bookFinished(id: 2))` would have passed, and one that asserted `!events.contains(.saveFailed(id: 2))` would have pointed straight at the real issue.
````

````exercise
id: m33-l03-e3
type: fill-in
prompt: "Complete a spy for the Sendable repository protocol so it compiles in Swift 6 and the test can read what was saved."
code: |
  [[1]] SpyRepository: BookRepository {
      private let stored: [Book]
      [[2]] var markedIDs: [Int] = []

      init(books: [Book]) {
          stored = books
      }

      func books() -> [Book] {
          stored
      }

      func markAsRead(id: Int) {
          markedIDs.[[3]](id)
      }
  }

  // In a test:
  #expect([[4]] repository.markedIDs == [2])
blanks:
  - id: "1"
    answers: ["actor"]
  - id: "2"
    answers: ["private(set)"]
  - id: "3"
    answers: ["append"]
  - id: "4"
    answers: ["await"]
solution: |
  An `actor` protects `markedIDs`, which satisfies `Sendable` without locks. `private(set)` lets tests read the record but not edit it. Reading an actor's property from outside is asynchronous, so the test needs `await` inside `#expect`.
````

````exercise
id: m33-l03-e4
type: find-errors
prompt: "A test file under review. Which comments point at real problems?"
code: |
  final class MockRepository: BookRepository, @unchecked Sendable {
      var booksCallCount = 0
      var markAsReadCallCount = 0
      var savedIDs: [Int] = []
      func books() async throws -> [Book] {
          booksCallCount += 1
          return sampleBooks
      }
      func markAsRead(id: Int) async throws {
          markAsReadCallCount += 1
          savedIDs.append(id)
      }
  }

  struct DummyAnalytics: AnalyticsTracker {
      func track(_ event: AnalyticsEvent) {}
  }

  @MainActor
  struct ReadingListTests {
      @Test func selectingABook() async {
          let repository = MockRepository()
          let viewModel = ReadingListViewModel(repository: repository, analytics: DummyAnalytics())
          await viewModel.load()
          await viewModel.didSelect(id: 2)
          #expect(repository.booksCallCount == 1)
          #expect(repository.markAsReadCallCount == 1)
          #expect(repository.savedIDs == [2])
      }
  }
choices:
  - text: "@unchecked Sendable hides a data race on the counters instead of fixing it."
    correct: true
    why: "Make the double an actor."
  - text: "It's named a mock but is a spy: it records, and the test asserts afterward."
    correct: true
    why: "Naming matters when discussing tests; SpyRepository is accurate."
  - text: "Asserting booksCallCount == 1 checks a query's call count, which breaks when the view model adds a reload or a cache."
    correct: true
    why: "The state after selecting already proves the books were loaded."
  - text: "The test never checks what the user sees after selecting a book."
    correct: true
    why: "It should check viewModel.state; that's the behavior."
  - text: "DummyAnalytics is used by the view model, so it isn't a dummy, and it hides that events are sent."
    correct: true
    why: "load() and didSelect(id:) both track events. A real dummy would crash here; this is a silent stub."
  - text: "markAsReadCallCount and savedIDs say the same thing twice."
    correct: true
    why: "savedIDs == [2] already implies one call. Keep the more specific check."
  - text: "A @MainActor suite can't call async methods."
    correct: false
    why: "It can; the test awaits them on the main actor."
rubric:
  - Finds the unchecked Sendable conformance.
  - Recognizes the double as a spy.
  - Flags the query call-count assertion as over-specification.
  - Notices the missing state assertion.
  - Notices the misnamed dummy that is actually used.
  - Notices the redundant counter.
solution: |
  A better version: `actor SpyRepository` with only `savedIDs`; a `SpyAnalytics` (or a stub, if analytics aren't under test); and assertions on what matters: `#expect(viewModel.state == expectedState)`, `#expect(await repository.savedIDs == [2])`, and if analytics are part of the requirement, `#expect(analytics.events.contains(.bookFinished(id: 2)))`. The call counts go.
````

````exercise
id: m33-l03-e5
type: solve
prompt: "Write the doubles and the tests for the failed-save path of this lesson's view model. You need one repository double that serves two books, fails every markAsRead, and records the ids it was asked to save. Check that after selecting the unread book the alert message is set, the state didn't change, analytics received listLoaded then saveFailed, and the repository saw the attempt. Add a second test for dismissing the alert. Then say which kinds of double you used."
starter: |
  struct SaveError: Error {}

  actor SaveFailingRepository: BookRepository {
      // Your code
  }

  @MainActor
  struct FailedSaveTests {
      // Your tests
  }
rubric:
  - The repository is an actor that returns canned books, throws from markAsRead, and records attempted ids.
  - The test captures the state before selecting and compares after, instead of hard-coding it twice.
  - Analytics are checked with a spy, as the exact list of events.
  - The alert test calls alertDismissed() and checks alertMessage is nil.
  - Names the repository as a stub and a spy combined, and the analytics double as a spy.
solution: |
  The double, run directly against the view model:

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

  enum AnalyticsEvent: Equatable, Sendable {
      case listLoaded(count: Int)
      case bookFinished(id: Int)
      case saveFailed(id: Int)
  }

  @MainActor
  protocol AnalyticsTracker {
      func track(_ event: AnalyticsEvent)
  }

  @MainActor
  final class ReadingListViewModel {
      struct Row: Equatable {
          let id: Int
          let title: String
          let isRead: Bool
      }

      enum State: Equatable {
          case loading
          case loaded(header: String, rows: [Row])
          case failed(message: String)
      }

      private(set) var state = State.loading {
          didSet { onChange?() }
      }
      private(set) var alertMessage: String? {
          didSet { onChange?() }
      }
      var onChange: (() -> Void)?

      private let repository: any BookRepository
      private let analytics: any AnalyticsTracker
      private var books: [Book] = []

      init(repository: any BookRepository, analytics: any AnalyticsTracker) {
          self.repository = repository
          self.analytics = analytics
      }

      func load() async {
          state = .loading
          do {
              books = try await repository.books()
              state = Self.loadedState(for: books)
              analytics.track(.listLoaded(count: books.count))
          } catch {
              state = .failed(message: "Couldn't load your books.")
          }
      }

      func didSelect(id: Int) async {
          guard let book = books.first(where: { $0.id == id }), !book.isRead else { return }
          do {
              try await repository.markAsRead(id: id)
              if let index = books.firstIndex(where: { $0.id == id }) {
                  books[index].isRead = true
              }
              state = Self.loadedState(for: books)
              analytics.track(.bookFinished(id: id))
          } catch {
              alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
              analytics.track(.saveFailed(id: id))
          }
      }

      func alertDismissed() {
          alertMessage = nil
      }

      private static func loadedState(for books: [Book]) -> State {
          let ordered = books.sorted { lhs, rhs in
              lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
          }
          let rows = ordered.map { Row(id: $0.id, title: $0.title, isRead: $0.isRead) }
          return .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
      }
  }

  /// Spy: records the calls it receives so the test can check them afterward.
  @MainActor
  final class SpyAnalytics: AnalyticsTracker {
      private(set) var events: [AnalyticsEvent] = []

      func track(_ event: AnalyticsEvent) {
          events.append(event)
      }
  }

  /// A spy can stub at the same time: canned answers in, calls recorded.
  actor SpyRepository: BookRepository {
      private let stored: [Book]
      private(set) var markedIDs: [Int] = []

      init(books: [Book]) {
          stored = books
      }

      func books() -> [Book] {
          stored
      }

      func markAsRead(id: Int) {
          markedIDs.append(id)
      }
  }

  struct SaveError: Error {}

  /// Stub and spy at once: serves canned books, fails every save, records the attempts.
  actor SaveFailingRepository: BookRepository {
      private let stored: [Book]
      private(set) var attemptedIDs: [Int] = []

      init(books: [Book]) {
          stored = books
      }

      func books() -> [Book] {
          stored
      }

      func markAsRead(id: Int) throws {
          attemptedIDs.append(id)
          throw SaveError()
      }
  }

  let repository = SaveFailingRepository(books: [
      Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
      Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
  ])
  let analytics = SpyAnalytics()
  let viewModel = ReadingListViewModel(repository: repository, analytics: analytics)
  await viewModel.load()
  let before = viewModel.state
  await viewModel.didSelect(id: 2)
  print(viewModel.alertMessage ?? "no alert")
  print(viewModel.state == before)
  print(analytics.events.map { "\($0)" })
  print(await repository.attemptedIDs)
  viewModel.alertDismissed()
  print(viewModel.alertMessage ?? "no alert")
  ```

  ```output
  Couldn't save. "Piranesi" is still unread.
  true
  ["listLoaded(count: 2)", "saveFailed(id: 2)"]
  [2]
  no alert
  ```

  The suite, built and run with `swift test` (Swift 6.3, Linux); both tests pass:

  ```swift illustrative
  import Testing
  @testable import Bookshelf

  @MainActor
  struct FailedSaveTests {
      let books = [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
          Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
      ]

      @Test func failedSaveShowsAnAlertAndKeepsTheList() async {
          let repository = SaveFailingRepository(books: books)
          let analytics = SpyAnalytics()
          let viewModel = ReadingListViewModel(repository: repository, analytics: analytics)
          await viewModel.load()
          let before = viewModel.state

          await viewModel.didSelect(id: 2)

          #expect(viewModel.alertMessage == "Couldn't save. \"Piranesi\" is still unread.")
          #expect(viewModel.state == before)
          #expect(analytics.events == [.listLoaded(count: 2), .saveFailed(id: 2)])
          #expect(await repository.attemptedIDs == [2])
      }

      @Test func dismissingTheAlertClearsIt() async {
          let viewModel = ReadingListViewModel(
              repository: SaveFailingRepository(books: books),
              analytics: SpyAnalytics()
          )
          await viewModel.load()
          await viewModel.didSelect(id: 2)

          viewModel.alertDismissed()

          #expect(viewModel.alertMessage == nil)
      }
  }
  ```

  `SaveFailingRepository` is a stub (canned books, a canned failure) and a spy (it records `attemptedIDs`). `SpyAnalytics` is a spy. Comparing with `before` states the requirement directly, "the list didn't change", without repeating the expected rows. Checking analytics as the exact list is reasonable here because the two events are the requirement for this path; if more events get added later, `contains(.saveFailed(id: 2))` would be the more tolerant check.
````

````exercise
id: m33-l03-e6
type: design
prompt: "A new feature: when the user finishes a book, the app asks a RecommendationService for three similar titles (a network call) and shows them in a banner; it also logs a bookFinished analytics event. For the view model's tests, choose a double for each dependency (BookRepository, RecommendationService, AnalyticsTracker) in three tests: recommendations shown after finishing a book; recommendation failure doesn't block marking as read; analytics event sent. Justify each choice and say what you would not assert."
rubric:
  - Uses a fake or a stub repository for state-based checks.
  - Stubs RecommendationService with canned titles and with a failure.
  - Uses a spy for analytics only in the test where the event is the requirement, and a dummy or quiet stub elsewhere, explaining the trade-off.
  - Avoids asserting call counts or order of the repository and recommendation calls.
  - Mentions keeping RecommendationService behind the app's own protocol instead of doubling URLSession.
solution: |
  - **Recommendations shown:** an in-memory fake repository (finishing a book should really mark it), a stub recommendation service returning three titles, and a no-op stub for analytics (it's called, so a crashing dummy won't do). Assert on the state: the book is read and the banner shows the three titles.
  - **Recommendation failure:** the same fake repository and a stub service that throws. Assert the book is read and the banner is absent (or shows a fallback). Don't assert whether or when the service was called; the outcome covers it.
  - **Analytics:** a stub repository and a stub service with any answer, and a spy tracker. Assert `events.contains(.bookFinished(id:))`, not the full list, so adding a recommendations-shown event later doesn't break this test.

  Not asserted anywhere: how many times `books()` ran, whether recommendations were requested before or after saving (unless product requires it), or the exact URL. `RecommendationService` is the app's own protocol, so it's ours to double; the real implementation's networking gets its own tests with a URLProtocol stub, as in Module 30.
````

## Summary

- **Test double** is the umbrella term (Meszaros). A **dummy** fills a parameter and should fail loudly if used. A **stub** returns canned answers. A **spy** is a stub that records calls for the test to check. A **mock** is scripted in advance and verifies the calls itself. A **fake** really works, with a shortcut like in-memory storage.
- In Swift, a double is just a type conforming to the dependency's protocol (or a struct of closures). Concurrency rules apply: spies with mutable records for `Sendable` protocols are actors; doubles of `@MainActor` protocols are `@MainActor` classes.
- Check **state** when possible; check **interactions** when the interaction is the behavior (analytics, saving). Prefer stubs and fakes for queries, spies for commands.
- **Over-mocking** couples tests to the implementation: a harmless refactor made the strict mock test fail while the state test passed. Mock only types you own, and assert only on what the test is about.
