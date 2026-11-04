---
id: m33-l05
title: Testing view models and UI tests
description: "Test the Module 32 reading list where most of its logic lives: the view model's states, the full sequence of transitions recorded as readable text, and the presenter's calls on a fake view. Then drive the real app with an XCUITest that finds views by accessibility identifier and runs against an in-memory repository chosen at launch, and decide how many tests of each kind a project needs."
module: m33
order: 5
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l04, m32-l03]
objectives:
  - List a view model's behaviors as input-to-state pairs and test each, including the no-op cases.
  - Record a view model's state transitions as a text transcript and compare the whole sequence in one expectation.
  - Test an MVP presenter through a recording view, including that it holds the view weakly.
  - Add accessibility identifiers to UIKit and SwiftUI views and query them from an XCUITest.
  - Use launch arguments and the composition root to run UI tests against an in-memory repository.
  - Explain the test pyramid and place a given test at the right level.
terms:
  - term: State test
    definition: "A view model test that drives inputs and compares the resulting state with an expected value."
  - term: Transition transcript
    definition: "A list of the states a view model went through, one rendered line per change, compared as a whole so the test checks the order and the in-between states."
  - term: UI test
    definition: "A test that launches the app in a separate process and drives it through the accessibility system, tapping and reading on-screen elements. In Xcode it uses XCTest with XCUIAutomation."
  - term: Accessibility identifier
    definition: "A string attached to a view for UI tests to find it. Unlike the accessibility label, users never see or hear it, so it can stay stable when the text changes."
  - term: Test pyramid
    definition: "Mike Cohn's guideline for the mix of automated tests: many fast unit tests at the base, fewer integration tests, and few slow end-to-end UI tests at the top."
mastery:
  - Write a parameterized state test that covers success, no-op and unknown-input cases of a view model input.
  - Write a transcript recorder for a closure-bound view model and read a failing transcript comparison.
  - Write a presenter test that compares the view's call log and a leak check for the weak view reference.
  - Write an XCUITest that launches with an argument, waits for an element by identifier, taps a cell and checks a label.
  - Decide which checks belong in unit tests and which only a UI test can make.
resources: [xcuiautomation, fowler-test-pyramid, swift-testing-docs, uikit-accessibility-traits, accessibility-inspector, uikit-supporting-voiceover, swift-book-closures]
cards:
  - id: m33-l05-c1
    front: "Final-state test or transition transcript?"
    back: "Final state for most behavior: it survives refactoring. A transcript when the sequence is the requirement: that loading shows before the list, that an alert appears and then clears, that nothing flashes in between."
  - id: m33-l05-c2
    front: How does a UI test find a view reliably?
    back: "By accessibility identifier: cell.accessibilityIdentifier = \"book-3\" in UIKit or .accessibilityIdentifier(\"book-3\") in SwiftUI, then app.cells[\"book-3\"] in the test. Labels change with copy edits and localization; identifiers don't."
  - id: m33-l05-c3
    front: How does a UI test avoid the real network?
    back: "It sets app.launchArguments (for example [\"-ui-testing\"]) before launch(). The app's composition root checks ProcessInfo.processInfo.arguments and builds an in-memory repository with known data instead of the remote one."
  - id: m33-l05-c4
    front: Why should a UI test wait instead of checking immediately?
    back: "The app runs in another process and updates asynchronously. Use waitForExistence(timeout:) or wait(for:toEqual:timeout:), which return as soon as the condition holds. Never sleep for a fixed time."
  - id: m33-l05-c5
    front: What does the test pyramid recommend?
    back: "Many unit tests (fast, precise, cheap), fewer integration tests, few UI tests (slow, broad, more fragile). Each UI test should cover a whole user flow that unit tests can't, not logic a view model test already checks."
---

## The idea in one sentence

Test the presentation logic as plain values, with view model state tests, transition transcripts and presenter call logs that run in milliseconds, and keep a handful of UI tests for what only the running app can show: that the screens are wired together and respond to taps.

> [!note] How the code was checked
> The view model, presenter and test helpers run in the blocks below. The Swift Testing suites were built and run with `swift test` (Swift 6.3, Linux). The UIKit and SwiftUI snippets are type-checked against the iOS SDK on the course's macOS CI runner. The XCUITest code follows Apple's [XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation) and [XCUIElement](https://developer.apple.com/documentation/xcuiautomation/xcuielement) reference, read November 2026; UI tests need Xcode and a simulator, so it **wasn't compiled or run** for this lesson.

## What to test in a view model

The view model is Module 32's, unchanged: a `State` enum of display values, an `alertMessage`, the inputs `load()`, `didSelect(id:)` and `alertDismissed()`, and an `onChange` closure binding. Start by listing its behaviors as input → state pairs. That list is the test plan:

| Input | Starting point | Expected state |
| --- | --- | --- |
| `load()` | repository has 3 books | `.loaded`, header "1 of 3 read", unread first |
| `load()` | repository offline | `.failed("Couldn't load your books.")`, no alert |
| `didSelect(id:)` | an unread book | header goes up by one, book moves down |
| `didSelect(id:)` | a read book, or an unknown id | nothing changes |
| `didSelect(id:)` | save fails | state unchanged, alert with the title |
| `alertDismissed()` | alert showing | alert cleared |

The no-op rows are easy to forget and often where bugs hide: a read book that gets "saved" again, an unknown id that crashes on an index.

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct ReadingListViewModelTests {
    let repository = InMemoryBookRepository(books: [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
        Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    ])

    @Test func loadShowsUnreadBooksFirst() async {
        let viewModel = ReadingListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.state == .loaded(header: "1 of 3 read", rows: [
            .init(id: 3, title: "Piranesi", subtitle: "Susanna Clarke", isRead: false),
            .init(id: 2, title: "The Dispossessed", subtitle: "Ursula K. Le Guin", isRead: false),
            .init(id: 1, title: "Kindred", subtitle: "Octavia E. Butler", isRead: true),
        ]))
    }

    @Test func offlineLoadShowsTheError() async {
        await repository.setOffline(true)
        let viewModel = ReadingListViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.state == .failed(message: "Couldn't load your books."))
        #expect(viewModel.alertMessage == nil)
    }

    @Test(arguments: [
        (id: 2, header: "2 of 3 read"),
        (id: 3, header: "2 of 3 read"),
        (id: 1, header: "1 of 3 read"),   // already read: nothing changes
        (id: 99, header: "1 of 3 read"),  // unknown id: nothing changes
    ])
    func selectingABookUpdatesTheHeader(id: Int, header: String) async throws {
        let viewModel = ReadingListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.didSelect(id: id)

        guard case .loaded(let shown, _) = viewModel.state else {
            Issue.record("Expected a loaded list, got \(viewModel.state)")
            return
        }
        #expect(shown == header)
    }
}
```

- The suite is `@MainActor` because the view model is (lessons 2 and 4).
- The repository is a stored property, so each test gets a fresh in-memory fake (lesson 3).
- `selectingABookUpdatesTheHeader` covers four rows of the table as parameterized cases. It only checks the header, because the rows' order is covered by `loadShowsUnreadBooksFirst`; each test checks one thing.
- `guard case .loaded(...) else { Issue.record(...); return }` handles the "wrong case" path with a clear message instead of a confusing comparison.

## Recording state transitions

A final-state test can't see what happened on the way. Sometimes the way is the requirement: the list must show `loading` first, the alert must appear and then clear, nothing should flash. For that, record every change the view would render, as text, and compare the whole transcript:

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

enum ReadingList {
    static func ordered(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
    }
}

@MainActor
final class ReadingListViewModel {
    struct Row: Equatable {
        let id: Int
        let title: String
        let subtitle: String
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
    private var books: [Book] = []

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            books = try await repository.books()
            state = Self.loadedState(for: books)
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
        } catch {
            alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
        }
    }

    func alertDismissed() {
        alertMessage = nil
    }

    private static func loadedState(for books: [Book]) -> State {
        let readCount = books.filter(\.isRead).count
        let rows = ReadingList.ordered(books).map {
            Row(id: $0.id, title: $0.title, subtitle: $0.author, isRead: $0.isRead)
        }
        return .loaded(header: "\(readCount) of \(books.count) read", rows: rows)
    }
}

struct OfflineError: Error {}

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

/// Records one line per change the view would render, as readable text.
@MainActor
final class TransitionRecorder {
    private(set) var lines: [String] = []

    init(_ viewModel: ReadingListViewModel) {
        viewModel.onChange = { [weak self, weak viewModel] in
            guard let self, let viewModel else { return }
            lines.append(Self.render(viewModel))
        }
    }

    var transcript: String {
        lines.joined(separator: "\n")
    }

    private static func render(_ viewModel: ReadingListViewModel) -> String {
        var line: String
        switch viewModel.state {
        case .loading:
            line = "loading"
        case .loaded(let header, let rows):
            let titles = rows.map { ($0.isRead ? "+" : "-") + $0.title }
            line = "\(header): " + titles.joined(separator: ", ")
        case .failed(let message):
            line = "failed: \(message)"
        }
        if let alert = viewModel.alertMessage {
            line += " [alert: \(alert)]"
        }
        return line
    }
}

let repository = InMemoryBookRepository(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
let viewModel = ReadingListViewModel(repository: repository)
let recorder = TransitionRecorder(viewModel)

await viewModel.load()
await repository.setOffline(true)
await viewModel.didSelect(id: 3)
viewModel.alertDismissed()
await repository.setOffline(false)
await viewModel.didSelect(id: 3)

print(recorder.transcript)
```

```output
loading
1 of 2 read: -Piranesi, +Kindred
1 of 2 read: -Piranesi, +Kindred [alert: Couldn't save. "Piranesi" is still unread.]
1 of 2 read: -Piranesi, +Kindred
2 of 2 read: +Kindred, +Piranesi
```

- **The recorder is the view's stand-in.** It sets `onChange`, exactly as the view controller does, and renders each change to one line. `[weak self, weak viewModel]` keeps it from creating a cycle with the view model it observes.
- **Text, not values.** One line per change, in a format a person can read: `-` for unread, `+` for read, the alert in brackets. When it fails, you see what the screen showed.
- **One assertion covers the whole sequence.** The test compares the transcript with a multi-line string literal:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct TransitionTests {
    let repository = InMemoryBookRepository(books: [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    ])

    @Test func finishingABook() async {
        let viewModel = ReadingListViewModel(repository: repository)
        let recorder = TransitionRecorder(viewModel)

        await viewModel.load()
        await viewModel.didSelect(id: 3)

        #expect(recorder.transcript == """
            loading
            1 of 2 read: -Piranesi, +Kindred
            2 of 2 read: +Kindred, +Piranesi
            """)
    }

    @Test func aFailedSaveThenRetry() async {
        let viewModel = ReadingListViewModel(repository: repository)
        let recorder = TransitionRecorder(viewModel)

        await viewModel.load()
        await repository.setOffline(true)
        await viewModel.didSelect(id: 3)
        viewModel.alertDismissed()
        await repository.setOffline(false)
        await viewModel.didSelect(id: 3)

        #expect(recorder.transcript == """
            loading
            1 of 2 read: -Piranesi, +Kindred
            1 of 2 read: -Piranesi, +Kindred [alert: Couldn't save. "Piranesi" is still unread.]
            1 of 2 read: -Piranesi, +Kindred
            2 of 2 read: +Kindred, +Piranesi
            """)
    }
}
```

When the expected text is wrong (or the code changes), the failure shows both transcripts. With the last line's order swapped in the expectation, `swift test` printed:

```text
✘ Test finishingABookWithAStaleExpectation() recorded an issue at TransitionFailure.swift:16:5: Expectation failed: (recorder.transcript → "loading
1 of 2 read: -Piranesi, +Kindred
2 of 2 read: +Kindred, +Piranesi") == ("""
        loading
        1 of 2 read: -Piranesi, +Kindred
        2 of 2 read: +Piranesi, +Kindred
        """ → "loading
1 of 2 read: -Piranesi, +Kindred
2 of 2 read: +Kindred, +Piranesi")
```

This is a **snapshot** of the transitions: a stored, human-readable rendering compared as a whole. Use it where the sequence matters and keep final-state tests for the rest, because a transcript also breaks when an extra harmless notification appears. (Image snapshot testing, which renders a view to a picture and compares it with a reference image, needs a third-party library; this course doesn't use one.)

## Testing the presenter

The MVP version from Module 32 tells a passive view what to show, so its tests compare the calls made on a recording view:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct ReadingListPresenterTests {
    let repository = InMemoryBookRepository(books: [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    ])
    let view = RecordingView()

    @Test func retryAfterAnOfflineLoad() async {
        let presenter = ReadingListPresenter(repository: repository)
        presenter.view = view

        await repository.setOffline(true)
        await presenter.viewDidLoad()
        await repository.setOffline(false)
        await presenter.didTapRetry()

        #expect(view.log == [
            "loading",
            "error: Couldn't load your books.",
            "loading",
            "1 of 2 read: -Piranesi, +Kindred",
        ])
    }

    @Test func presenterDoesNotKeepTheViewAlive() async {
        let presenter = ReadingListPresenter(repository: repository)
        weak var probe: RecordingView?
        do {
            let temporaryView = RecordingView()
            presenter.view = temporaryView
            probe = temporaryView
            await presenter.viewDidLoad()
        }
        #expect(probe == nil)
    }
}
```

The second test is Module 13's leak check applied to the MVP wiring: the presenter must hold its view `weak`, because the view controller owns the presenter. If someone removes `weak` from `var view`, the probe stays non-`nil` and the test fails. Both tests passed with `swift test`.

> [!tip] XCTest and main-actor view models
> In XCTest, mark the test class or its methods `@MainActor` before touching a `@MainActor` view model. Apple's migration guide says XCTest runs synchronous test methods on the main actor by default, but with Swift 6.3 on Linux, calling a `@MainActor` method from an unannotated synchronous XCTest method didn't compile: `error: call to main actor-isolated instance method 'bump()' in a synchronous nonisolated context`. The annotation works everywhere.

## UI tests

Everything so far tests the view model and presenter without a screen. What they can't catch: a cell that never calls `didSelect`, a header label that isn't connected, a navigation push that crashes. A **UI test** launches the real app and drives it like a user, through the accessibility system.

UI tests live in their own **UI testing target**. The test code runs in a separate process from the app; it can't call the app's functions or read its properties. It can only find elements on screen, interact with them, and read their accessibility attributes. Apple's documentation now groups the UI testing classes (`XCUIApplication`, `XCUIElement`, `XCUIElementQuery`) as the XCUIAutomation framework, used from `XCTestCase` subclasses.

### Make the views findable

UI tests find elements through queries like `app.cells["book-3"]`, which match an element's identifier, label or other attributes. Matching the **accessibility identifier** is the reliable choice: users never see or hear it, so it doesn't change when the copy is edited or the app is localized. UIKit's [`accessibilityIdentifier`](https://developer.apple.com/documentation/uikit/uiaccessibilityidentification/accessibilityidentifier) is a property on every view:

```swift ios
import UIKit

@MainActor
func configure(_ cell: UITableViewCell, id: Int, title: String, author: String, isRead: Bool) {
    var content = cell.defaultContentConfiguration()
    content.text = title
    content.secondaryText = author
    cell.contentConfiguration = content
    cell.accessoryType = isRead ? .checkmark : .none
    cell.accessibilityIdentifier = "book-\(id)"
}

let headerLabel = UILabel()
headerLabel.text = "1 of 3 read"
headerLabel.accessibilityIdentifier = "reading-list.header"

let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "BookCell")
configure(cell, id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false)
```

SwiftUI has the `accessibilityIdentifier(_:)` modifier (Apple: "Use this value for testing. It isn't visible to the user."):

```swift ios
import SwiftUI

struct ReadingListHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .accessibilityIdentifier("reading-list.header")
    }
}

struct BookRow: View {
    let id: Int
    let title: String
    let isRead: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isRead {
                Image(systemName: "checkmark")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("book-\(id)")
    }
}
```

The identifiers use the model's `id`, not the row's position, so a test can find "Piranesi" wherever it sorts. Good accessibility labels (Module 27) and identifiers aren't in tension: labels are for people, identifiers for tests, and every element can have both.

### Control the data at launch

A UI test that loads books from the real server fails whenever the server, the account or the network changes. The test can't inject a fake into another process, but it can pass **launch arguments**, and the app's composition root (Module 32) can read them and choose the dependencies:

```swift
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    var isRead: Bool
}

protocol BookRepository: Sendable {
    func books() async throws -> [Book]
}

struct RemoteBookRepository: BookRepository {
    func books() async throws -> [Book] {
        []   // the real one calls the API (Module 30)
    }
}

actor InMemoryBookRepository: BookRepository {
    private let stored: [Book]

    init(books: [Book]) {
        stored = books
    }

    func books() -> [Book] {
        stored
    }
}

enum CompositionRoot {
    static func makeRepository(arguments: [String]) -> any BookRepository {
        if arguments.contains("-ui-testing") {
            return InMemoryBookRepository(books: [
                Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
                Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
                Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
            ])
        }
        return RemoteBookRepository()
    }
}

// In the app: CompositionRoot.makeRepository(arguments: ProcessInfo.processInfo.arguments)
let normal = CompositionRoot.makeRepository(arguments: ["Bookshelf"])
let uiTesting = CompositionRoot.makeRepository(arguments: ["Bookshelf", "-ui-testing"])
print(normal is RemoteBookRepository)
print(try await uiTesting.books().count)
```

```output
true
3
```

- The decision takes the arguments as a parameter, so it's testable here; the app passes `ProcessInfo.processInfo.arguments`.
- In the app, wrap the `-ui-testing` branch in `#if DEBUG … #endif` so the test data and the switch never ship in a release build. UI tests normally run the Debug configuration, where `#if DEBUG` is true when the configuration lists `DEBUG` in its Active Compilation Conditions (Module 21). (The block above leaves the condition out because the course's snippet runner doesn't define `DEBUG`.)
- More arguments can select more scenarios: `-ui-testing-offline` for the error screen, a seed for an empty list. `launchEnvironment` works the same way for key-value settings.

### The UI test

```swift illustrative
import XCTest

final class ReadingListUITests: XCTestCase {
    @MainActor
    func testMarkingABookAsReadUpdatesTheHeader() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let header = app.staticTexts["reading-list.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "1 of 3 read")

        app.cells["book-3"].tap()

        XCTAssertTrue(header.wait(for: \.label, toEqual: "2 of 3 read", timeout: 2))
    }
}
```

Line by line, with the behavior Apple documents for each call:

- **`XCUIApplication()`** is a proxy for the app under test. `launchArguments` must be set before `launch()`.
- **`launch()`** is synchronous: when it returns, the app has launched and is ready for events. If it's already running, it's terminated first, so every test starts clean.
- **`app.staticTexts["reading-list.header"]`** is a query, not a lookup: it's evaluated when you use it, so it always reflects the current screen.
- **`waitForExistence(timeout:)`** returns `true` as soon as the element exists, or `false` after the timeout. The list loads asynchronously, so check it instead of assuming.
- **`app.cells["book-3"].tap()`** finds the cell by identifier and taps it.
- **`wait(for: \.label, toEqual: "2 of 3 read", timeout: 2)`** waits for a property to reach a value and returns `false` if the timeout expires first. Apple's reference lists it with Xcode 16.3 availability, like the rest of XCUIAutomation's symbols; if your Xcode doesn't offer it, use `waitForExistence(timeout:)` on an element that only appears after the change.
- **`@MainActor`**: Apple declares `XCUIApplication` and `XCUIElement` as `@MainActor` classes.

Xcode can also **record** a UI test: per Apple's article [Recording UI automation for testing](https://developer.apple.com/documentation/xcuiautomation/recording-ui-automation-for-testing), you click the record button in a test method and use the app, and Xcode writes the queries and actions, offering alternative queries for each element. Recorded queries often match by position or visible text, so choose the identifier-based alternative before keeping them.

## The test pyramid

Mike Cohn described the "test automation pyramid" in *Succeeding with Agile* (2009); Martin Fowler's [summary](https://martinfowler.com/bliki/TestPyramid.html) is the common reference. The idea: many fast, focused tests at the bottom, fewer broad ones at the top, because broad tests are slower, more expensive to maintain and more fragile.

For the reading list:

| Level | What | How many | Runs in |
| --- | --- | --- | --- |
| Unit | Ordering, header text, importer, view model states and transitions, presenter calls | Dozens | Milliseconds each |
| Integration | Repository + real `URLSession` with a `URLProtocol` stub; JSON contract tests (Module 30) | A handful per feature | Milliseconds to seconds |
| UI | Launch, see the list, mark a book, see the header change; the offline screen | One or two per user flow | Seconds each |

The table's main lesson is what the UI tests **don't** check: sort order rules, every error message, every no-op. A view model test checks those in a millisecond and points straight at the failing rule. A UI test that fails says "the header didn't change" and leaves you to find out why. Fowler's article notes that some teams argue for more integration tests and fewer unit tests, and that the disagreement is partly about what "unit" means; the constant is to push each check to the lowest level that can make it.

## Common mistakes

> [!error] Only testing the final state when the sequence matters
> An alert that appears and is never cleared, or a screen that briefly shows "0 of 0 read" before the list, passes a final-state test. When the order of what the user sees is part of the requirement, record a transcript.

> [!error] UI tests that find elements by visible text
> `app.staticTexts["1 of 3 read"]` or `app.buttons["Retry"]` break with every copy change and every language. Use identifiers for finding; check text only where the text is the thing under test.

> [!error] Sleeping in UI tests
> `sleep(2)` before checking the header. Too short on a slow simulator, too long everywhere else. Use `waitForExistence(timeout:)` or `wait(for:toEqual:timeout:)`, which return as soon as the condition holds.

> [!error] UI tests against real servers
> They fail when the network, the server or the test account changes. Launch with an argument that selects in-memory data, and test the network layer separately.

> [!error] Testing logic through the UI
> Ten UI tests for ten sort-order rules. Each takes seconds and points vaguely at the screen. Test the rules in the view model; keep one UI test that the list appears in order.

> [!error] Test-only code in release builds
> A `-ui-testing` branch that ships, letting anyone launch the app with fake data. Wrap it in `#if DEBUG`.

## Exercises

````exercise
id: m33-l05-e1
type: comprehension
prompt: "A UI test finds the header with app.staticTexts[\"1 of 3 read\"]. Why is app.staticTexts[\"reading-list.header\"] with an accessibility identifier better?"
choices:
  - text: "The identifier doesn't change when the text changes, so the test can find the header in every state and in every language, and then check its label."
    correct: true
    why: "Finding by identifier and checking the label separates where the element is from what it says."
  - text: "Identifiers are read aloud by VoiceOver, so they double as accessibility labels."
    correct: false
    why: "The reverse: users never see or hear identifiers. Labels are for VoiceOver."
  - text: "Queries by label aren't supported by XCUIElementQuery."
    correct: false
    why: "They are; a subscript matches identifiers and labels. They're just fragile."
  - text: "Identifiers make the test run faster."
    correct: false
    why: "Speed isn't the reason. Stability is."
solution: |
  Matching by visible text ties the query to one state ("1 of 3 read") and one language. After the tap, the header says "2 of 3 read" and the old query no longer finds it. With an identifier, the same element is found before and after, and `header.label` is checked against the expected text.
````

````exercise
id: m33-l05-e2
type: prediction
prompt: "A small view model with a didSet binding and a recorder that appends each state. What does the program print?"
code: |
  @MainActor
  final class GoalViewModel {
      enum State: Equatable {
          case idle
          case saving
          case saved(Int)
          case failed
      }

      private(set) var state = State.idle {
          didSet { onChange?() }
      }
      var onChange: (() -> Void)?

      func save(goal: Int, succeeds: Bool) async {
          guard goal > 0 else { return }
          state = .saving
          state = succeeds ? .saved(goal) : .failed
      }
  }

  let viewModel = GoalViewModel()
  var transcript: [String] = []
  viewModel.onChange = { transcript.append("\(viewModel.state)") }

  await viewModel.save(goal: 12, succeeds: true)
  await viewModel.save(goal: 0, succeeds: true)
  await viewModel.save(goal: 20, succeeds: false)
  print(transcript.joined(separator: " -> "))
  print(transcript.count)
output: |
  saving -> saved(12) -> saving -> failed
  4
solution: |
  - The first save records `saving`, then `saved(12)`.
  - `goal: 0` hits the guard and returns before any assignment: nothing recorded.
  - The third save records `saving`, then `failed`.

  ```output
  saving -> saved(12) -> saving -> failed
  4
  ```

  The initial `idle` isn't in the transcript, because the recorder only sees changes. A final-state test would see only `failed`; the transcript also shows that the zero goal did nothing, and that `saving` appeared before each result.
````

````exercise
id: m33-l05-e3
type: fill-in
prompt: "Complete the UI test so it launches with in-memory data, finds the header by identifier, waits for it, and taps the cell for book 2."
code: |
  @MainActor
  func testFinishingTheDispossessed() throws {
      let app = XCUIApplication()
      app.[[1]] = ["-ui-testing"]
      app.[[2]]()

      let header = app.staticTexts["[[3]]"]
      XCTAssertTrue(header.[[4]](timeout: 5))

      app.cells["book-2"].[[5]]()
      XCTAssertTrue(header.wait(for: \.label, toEqual: "2 of 3 read", timeout: 2))
  }
blanks:
  - id: "1"
    answers: ["launchArguments"]
  - id: "2"
    answers: ["launch"]
  - id: "3"
    answers: ["reading-list.header"]
  - id: "4"
    answers: ["waitForExistence"]
  - id: "5"
    answers: ["tap"]
solution: |
  `launchArguments` must be set before `launch()`, which the app's composition root reads to choose the in-memory repository. The header is found by its identifier, `reading-list.header`, and `waitForExistence(timeout:)` waits for the list to load. `tap()` on the cell queried by `book-2` marks the book.
````

````exercise
id: m33-l05-e4
type: find-errors
prompt: "A UI test suite under review. Which comments point at real problems?"
code: |
  final class ReadingListUITests: XCTestCase {
      @MainActor
      func testSortOrderPutsUnreadFirst() throws {
          let app = XCUIApplication()
          app.launch()
          sleep(3)
          let first = app.cells.element(boundBy: 0)
          XCTAssertTrue(first.staticTexts["Piranesi"].exists)
      }

      @MainActor
      func testHeaderAfterMarking() throws {
          let app = XCUIApplication()
          app.launch()
          app.cells.element(boundBy: 1).tap()
          XCTAssertEqual(app.staticTexts["2 of 3 read"].exists, true)
      }
  }
choices:
  - text: "Neither test sets launch arguments, so they run against whatever the real server returns."
    correct: true
    why: "Pass -ui-testing (or similar) so the app uses known in-memory data."
  - text: "sleep(3) is both slow and not guaranteed to be enough."
    correct: true
    why: "Wait for a specific element with waitForExistence(timeout:)."
  - text: "Sort order is view model logic; a UI test is the slow, vague place to check it."
    correct: true
    why: "Test ordering in a unit test. A UI test may check that the list appears."
  - text: "Cells are found by position and text instead of identifiers."
    correct: true
    why: "Identifiers based on the book's id survive reordering and copy changes."
  - text: "The second test checks immediately after the tap, without waiting for the update."
    correct: true
    why: "The app updates asynchronously; wait for the label."
  - text: "XCUIApplication must be created in setUp, not in the test method."
    correct: false
    why: "Creating it in the test is fine; launch() gives each test a fresh app."
rubric:
  - Flags the missing launch arguments and the real data source.
  - Flags sleep.
  - Moves sort-order checking to a unit test.
  - Flags position- and text-based queries.
  - Flags the missing wait after the tap.
solution: |
  A better suite keeps one flow test: launch with `-ui-testing`, wait for `reading-list.header`, check its label, tap `app.cells["book-3"]`, wait for the label to become "2 of 3 read". The sort order goes to `ReadingListViewModelTests`, where it's already covered by `loadShowsUnreadBooksFirst`.
````

````exercise
id: m33-l05-e5
type: solve
prompt: "Write Swift Testing tests for the MVP presenter's row selection, using the recording view and the in-memory repository from this lesson: selecting the unread row shows both books read; a failed save shows the alert; selecting a read row or an index that doesn't exist (including a negative one) sends nothing to the view. Load the presenter through a helper so each test starts from the loaded list."
starter: |
  @MainActor
  struct PresenterSelectionTests {
      let repository = InMemoryBookRepository(books: [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
          Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
      ])
      let view = RecordingView()

      // Your helper and tests
  }
rubric:
  - A helper creates the presenter, attaches the view and awaits viewDidLoad.
  - The success test checks the last log entry shows both books read in display order.
  - The failure test sets the repository offline after loading and checks the alert entry.
  - "The no-op test is parameterized over a read row and out-of-range indexes, and compares the whole log before and after."
solution: |
  The presenter, driven directly:

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

  enum ReadingList {
      static func ordered(_ books: [Book]) -> [Book] {
          books.sorted { lhs, rhs in
              lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
          }
      }
  }

  @MainActor
  final class ReadingListViewModel {
      struct Row: Equatable {
          let id: Int
          let title: String
          let subtitle: String
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
      private var books: [Book] = []

      init(repository: any BookRepository) {
          self.repository = repository
      }

      func load() async {
          state = .loading
          do {
              books = try await repository.books()
              state = Self.loadedState(for: books)
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
          } catch {
              alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
          }
      }

      func alertDismissed() {
          alertMessage = nil
      }

      private static func loadedState(for books: [Book]) -> State {
          let readCount = books.filter(\.isRead).count
          let rows = ReadingList.ordered(books).map {
              Row(id: $0.id, title: $0.title, subtitle: $0.author, isRead: $0.isRead)
          }
          return .loaded(header: "\(readCount) of \(books.count) read", rows: rows)
      }
  }

  struct ReadingListRow: Equatable {
      let title: String
      let subtitle: String
      let isRead: Bool
  }

  @MainActor
  protocol ReadingListView: AnyObject {
      func showLoading()
      func show(header: String, rows: [ReadingListRow])
      func showError(message: String)
      func showAlert(message: String)
  }

  @MainActor
  final class ReadingListPresenter {
      weak var view: (any ReadingListView)?
      private let repository: any BookRepository
      private var books: [Book] = []

      init(repository: any BookRepository) {
          self.repository = repository
      }

      func viewDidLoad() async {
          await load()
      }

      func didTapRetry() async {
          await load()
      }

      func didSelectRow(at index: Int) async {
          guard books.indices.contains(index), !books[index].isRead else { return }
          let book = books[index]
          do {
              try await repository.markAsRead(id: book.id)
              books[index].isRead = true
              books = ReadingList.ordered(books)
              showBooks()
          } catch {
              view?.showAlert(message: "Couldn't save. \"\(book.title)\" is still unread.")
          }
      }

      private func load() async {
          view?.showLoading()
          do {
              books = ReadingList.ordered(try await repository.books())
              showBooks()
          } catch {
              view?.showError(message: "Couldn't load your books.")
          }
      }

      private func showBooks() {
          let header = "\(books.filter(\.isRead).count) of \(books.count) read"
          let rows = books.map { ReadingListRow(title: $0.title, subtitle: $0.author, isRead: $0.isRead) }
          view?.show(header: header, rows: rows)
      }
  }

  struct OfflineError: Error {}

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

  @MainActor
  final class RecordingView: ReadingListView {
      private(set) var log: [String] = []

      func showLoading() {
          log.append("loading")
      }

      func show(header: String, rows: [ReadingListRow]) {
          log.append("\(header): " + rows.map { ($0.isRead ? "+" : "-") + $0.title }.joined(separator: ", "))
      }

      func showError(message: String) {
          log.append("error: \(message)")
      }

      func showAlert(message: String) {
          log.append("alert: \(message)")
      }
  }

  let repository = InMemoryBookRepository(books: [
      Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
      Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
  ])
  let view = RecordingView()
  let presenter = ReadingListPresenter(repository: repository)
  presenter.view = view
  await presenter.viewDidLoad()

  await presenter.didSelectRow(at: 1)    // Kindred: already read
  await presenter.didSelectRow(at: -1)   // no such row
  print(view.log.count)

  await repository.setOffline(true)
  await presenter.didSelectRow(at: 0)
  await repository.setOffline(false)
  await presenter.didSelectRow(at: 0)
  for entry in view.log {
      print(entry)
  }
  ```

  ```output
  2
  loading
  1 of 2 read: -Piranesi, +Kindred
  alert: Couldn't save. "Piranesi" is still unread.
  2 of 2 read: +Kindred, +Piranesi
  ```

  The suite, built and run with `swift test` (Swift 6.3, Linux), all five cases passing:

  ```swift illustrative
  import Testing
  @testable import Bookshelf

  @MainActor
  struct PresenterSelectionTests {
      let repository = InMemoryBookRepository(books: [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
          Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
      ])
      let view = RecordingView()

      func loadedPresenter() async -> ReadingListPresenter {
          let presenter = ReadingListPresenter(repository: repository)
          presenter.view = view
          await presenter.viewDidLoad()
          return presenter
      }

      @Test func selectingAnUnreadRowShowsItRead() async {
          let presenter = await loadedPresenter()

          await presenter.didSelectRow(at: 0)   // Piranesi, first in display order

          #expect(view.log.last == "2 of 2 read: +Kindred, +Piranesi")
      }

      @Test func aFailedSaveShowsAnAlert() async {
          let presenter = await loadedPresenter()
          await repository.setOffline(true)

          await presenter.didSelectRow(at: 0)

          #expect(view.log.last == "alert: Couldn't save. \"Piranesi\" is still unread.")
      }

      @Test(arguments: [1, 5, -1])
      func selectingAReadOrMissingRowDoesNothing(index: Int) async {
          let presenter = await loadedPresenter()
          let before = view.log

          await presenter.didSelectRow(at: index)

          #expect(view.log == before)
      }
  }
  ```

  Comparing `view.log == before` is stronger than checking the last entry: it proves the presenter sent **nothing**, not even a redundant `show`. Index `-1` matters because the presenter's `books.indices.contains(index)` guard is what keeps it from crashing; a test without it wouldn't notice if someone replaced the guard with `index < books.count`.
````

````exercise
id: m33-l05-e6
type: design
prompt: "Plan the automated tests for a new \"Reading goals\" screen: the user sets a yearly goal (1 to 500 books), sees progress (\"12 of 30, 40%\"), gets a celebration banner when reaching it, and the goal syncs to the server. Say what you'd test at each level of the pyramid, roughly how many tests, and what the UI tests deliberately leave out."
rubric:
  - Unit tests for validation boundaries, progress formatting and rounding, the banner condition, and save failure states, many of them parameterized.
  - A transcript test for the sequence that matters (saving, saved, banner appears once).
  - Integration tests for the sync client with a URLProtocol stub and a contract test.
  - One or two UI tests for the main flow, launched with in-memory data and using identifiers.
  - States explicitly that boundaries and messages aren't re-tested in UI tests.
solution: |
  **Unit (most tests):** a parameterized test for goal validation at 0, 1, 500, 501 and non-numeric input; progress text and percentage at 0, partial, exact and over-goal values, including rounding; the banner condition (shown once when crossing the goal, not again on reload); save failure leaves the old goal and sets an alert. A transcript test for "set goal" records saving → saved → banner, so a regression that shows the banner before the save completes is caught.

  **Integration (a few):** the sync client against a `URLProtocol` stub for success, 4xx and 5xx, and a contract test decoding a fixture of the goals endpoint.

  **UI (one or two):** launch with `-ui-testing` and a seeded reading history, set a goal of 13 when 12 are read, mark one book, and wait for the banner identified as `goals.banner`. Optionally one for the offline alert.

  Deliberately left out of UI tests: every validation boundary, every message, rounding rules. They're in the view model tests, where they run in milliseconds and fail with a precise message.
````

## Summary

- Write the view model's behavior as input → state pairs, including no-op inputs, and test each pair. Parameterize the similar ones.
- When the **sequence** matters, record a transcript of rendered states through the same binding the view uses, and compare it as text. Use final-state tests for everything else.
- Test a presenter by comparing a recording view's log, and check it holds the view weakly.
- In XCTest, annotate tests of `@MainActor` code with `@MainActor`.
- UI tests launch the app in another process and drive it through accessibility. Give views **accessibility identifiers**, select test data with **launch arguments** read by the composition root (inside `#if DEBUG`), and **wait** for elements instead of sleeping.
- Follow the **test pyramid**: many unit tests, some integration tests, few UI tests that cover flows, not rules.
