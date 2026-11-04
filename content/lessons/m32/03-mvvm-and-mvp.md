---
id: m32-l03
title: MVVM and MVP
description: "Rebuild the reading list twice more. With MVVM, a view model holds the screen's display state and exposes inputs, and the view binds to it either through closures (UIKit) or through Observation (SwiftUI). With MVP, a presenter drives a passive view through a protocol. You test both without UIKit and compare what each kind of test checks."
module: m32
order: 3
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l02]
objectives:
  - Write a view model as plain display state plus input methods, with no UIKit or SwiftUI types in it.
  - Bind a UIKit view controller to a view model with a change closure, and a SwiftUI view to an @Observable view model.
  - Explain how Observation tracks the properties a view reads and why tracking is one-shot.
  - Write a presenter that drives a passive view protocol, and a recording fake view to test it.
  - Compare state-based view model tests with call-based presenter tests and choose between MVVM and MVP.
terms:
  - term: View model
    definition: "An object that holds a screen's display state (what to show, already formatted) and exposes methods for the user's actions. The view reads the state and calls the methods; the view model never references the view."
  - term: Binding
    definition: "The mechanism that makes the view update when the view model's state changes: a closure the view model calls, a Combine publisher, or Observation tracking."
  - term: Observation
    definition: "The Swift module behind the @Observable macro (iOS 17). It records which properties of an observable object a piece of code reads, and calls back once when any of them is about to change. SwiftUI uses it to re-render views."
  - term: Presenter
    definition: "In MVP, the object that receives the view's events, does the presentation logic and tells the view exactly what to display through a protocol."
  - term: Passive view
    definition: "A view (usually a view controller) that makes no decisions: it implements a protocol of display commands, like show(rows:) or showError(message:), and forwards user events to its presenter."
mastery:
  - Turn lesson 2's model controller into a view model whose state is an Equatable enum of display values.
  - Write a test that drives a view model with a fake repository and compares its state to an expected value.
  - Predict when withObservationTracking's onChange runs and when it doesn't.
  - Write a passive view protocol, a presenter that drives it, and a recording fake whose log a test compares.
  - Say what breaks a presenter test that a view model test would survive, and the reverse.
resources: [observation, observation-tracking, swiftui-migrating-to-observable, swift-book-protocols, swift-mainactor, swift-book-closures, swift-book-enumerations]
cards:
  - id: m32-l03-c1
    front: What does a view model contain, and what must it never contain?
    back: "Display state (formatted values, an enum for loading/loaded/failed) and input methods for user actions. Never a reference to the view or view controller, and ideally no UIKit or SwiftUI types, so it can be tested as plain Swift."
  - id: m32-l03-c2
    front: How does SwiftUI know to re-render when an @Observable view model changes?
    back: "While body runs, Observation records every observable property it reads. When one of those is about to change, SwiftUI is notified once and schedules a new body evaluation, which records the reads again."
  - id: m32-l03-c3
    front: What's a passive view in MVP?
    back: "A view that implements a protocol of display commands (showLoading(), show(rows:), showError(message:)) and forwards events to the presenter. It makes no decisions; the presenter decides what to show."
  - id: m32-l03-c4
    front: Why does an MVP presenter hold its view weakly?
    back: "The view controller owns the presenter strongly. If the presenter also held the view strongly, the two would keep each other alive. The view protocol is AnyObject so the reference can be weak."
  - id: m32-l03-c5
    front: "MVVM test vs MVP test: what does each assert on?"
    back: "A view model test drives inputs and compares the resulting state value. A presenter test drives events and compares the log of calls made on a fake view. State tests survive reordering calls; call tests check exactly what the view was told."
---

## The idea in one sentence

MVVM and MVP both move the decisions out of the view controller into a plain object: a **view model** exposes the screen's state for the view to read, while a **presenter** tells a passive view what to show, and either one can be tested without UIKit.

## From model controller to view model

Lesson 2 ended with a `ReadingListModel` that exposed domain data (`[Book]` and a status) and a controller whose `render()` still decided what to show for each status. A view model takes the last step: it exposes **exactly what the screen displays**, already formatted, and the view's only job is to copy it onto the screen.

Two kinds of members make up a view model:

- **State:** read-only properties the view renders. Here a single `State` enum, because the screen is in exactly one of three situations, plus an optional alert message.
- **Inputs:** methods for what the user can do: `load()`, `didSelect(id:)`, `alertDismissed()`.

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
    /// The binding: the view sets this and re-renders when it's called.
    var onChange: (() -> Void)?

    private let repository: any BookRepository
    private var books: [Book] = []

    init(repository: any BookRepository) {
        self.repository = repository
    }

    // MARK: Inputs

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

// MARK: Test

enum RepositoryError: Error {
    case offline
}

actor FakeBookRepository: BookRepository {
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

let repository = FakeBookRepository(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
let viewModel = ReadingListViewModel(repository: repository)

await viewModel.load()
await viewModel.didSelect(id: 3)
print(viewModel.state == .loaded(header: "2 of 3 read", rows: [
    .init(id: 2, title: "The Dispossessed", subtitle: "Ursula K. Le Guin", isRead: false),
    .init(id: 1, title: "Kindred", subtitle: "Octavia E. Butler", isRead: true),
    .init(id: 3, title: "Piranesi", subtitle: "Susanna Clarke", isRead: true),
]))

await repository.setOffline(true)
await viewModel.didSelect(id: 2)
print(viewModel.alertMessage ?? "no alert")
viewModel.alertDismissed()

await viewModel.load()
if case .failed(let message) = viewModel.state {
    print("failed: \(message)")
}
```

```output
true
Couldn't save. "The Dispossessed" is still unread.
failed: Couldn't load your books.
```

What changed from lesson 2's model:

- **The state is a display value.** `loaded(header:rows:)` carries the header text and the rows in display order. A test compares the whole screen with one `==`, which is what the first `print` does; in a test target it's `#expect(viewModel.state == ...)`.
- **The alert is state too.** Instead of an `onSaveError` event, `alertMessage` is non-`nil` while an alert should be on screen, and the view calls `alertDismissed()` when the user closes it. That fits SwiftUI's `.alert(isPresented:)`, and it means a test can check "an alert is showing" at any moment.
- **The binding is one closure.** Every change to `state` or `alertMessage` calls `onChange` through `didSet`. That's the simplest binding there is, and it's all UIKit needs.

### Binding a UIKit view controller

The controller sets `onChange`, renders the current state, and forwards events:

```swift ios
import UIKit

@MainActor
final class ReadingListViewController: UITableViewController {
    private let viewModel: ReadingListViewModel
    private var rows: [ReadingListViewModel.Row] = []
    private let headerLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(viewModel: ReadingListViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reading List"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BookCell")
        headerLabel.textAlignment = .center
        headerLabel.frame.size.height = 44
        tableView.tableHeaderView = headerLabel
        viewModel.onChange = { [weak self] in self?.render() }
        render()
        Task { await viewModel.load() }
    }

    private func render() {
        switch viewModel.state {
        case .loading:
            spinner.startAnimating()
            tableView.backgroundView = spinner
            rows = []
        case .loaded(let header, let rows):
            tableView.backgroundView = nil
            headerLabel.text = header
            self.rows = rows
        case .failed(let message):
            let label = UILabel()
            label.text = message
            label.textAlignment = .center
            tableView.backgroundView = label
            rows = []
        }
        tableView.reloadData()

        if let message = viewModel.alertMessage, presentedViewController == nil {
            let alert = UIAlertController(title: "Couldn't save", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.viewModel.alertDismissed()
            })
            present(alert, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.subtitle
        cell.contentConfiguration = content
        cell.accessoryType = row.isRead ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = rows[indexPath.row].id
        Task { await viewModel.didSelect(id: id) }
    }
}

// The view model and its types from above, repeated so this block compiles on its own.

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
            state = loadedState()
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
            state = loadedState()
        } catch {
            alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
        }
    }

    func alertDismissed() {
        alertMessage = nil
    }

    private func loadedState() -> State {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        let rows = ordered.map { Row(id: $0.id, title: $0.title, subtitle: $0.author, isRead: $0.isRead) }
        return .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
    }
}
```

`render()` has a `switch`, but every branch only copies values into views. There's nothing to get wrong that a test of the view model wouldn't catch first. It re-renders everything on every change, which is fine for a screen this size; with a diffable data source (Module 24) the rows would animate instead of reloading.

The closure binding has a limit: there's one `onChange`, so only one observer. That's normally all you need (one view per view model), but it's why larger UIKit codebases often use Combine publishers or, now, Observation.

## Binding with Observation

The `@Observable` macro (the Observation module, iOS 17) does the binding for you. Mark the class, and every stored `var` becomes trackable. SwiftUI reads the properties it needs in `body`, and re-renders when any of them changes. No `didSet`, no closure:

```swift ios
import SwiftUI
import Observation

@MainActor
@Observable
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

    private(set) var state = State.loading
    private(set) var alertMessage: String?

    /// For SwiftUI's alert(isPresented:), which needs a Bool binding.
    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    @ObservationIgnored private let repository: any BookRepository
    @ObservationIgnored private var books: [Book] = []

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            books = try await repository.books()
            state = loadedState()
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
            state = loadedState()
        } catch {
            alertMessage = "Couldn't save. \"\(book.title)\" is still unread."
        }
    }

    private func loadedState() -> State {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        let rows = ordered.map { Row(id: $0.id, title: $0.title, subtitle: $0.author, isRead: $0.isRead) }
        return .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
    }
}

struct ReadingListScreen: View {
    @State private var viewModel: ReadingListViewModel

    init(repository: any BookRepository) {
        _viewModel = State(initialValue: ReadingListViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Reading List")
            .task { await viewModel.load() }
            .alert("Couldn't save", isPresented: $viewModel.isShowingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .loaded(let header, let rows):
            List {
                Section(header) {
                    ForEach(rows, id: \.id) { row in
                        Button {
                            Task { await viewModel.didSelect(id: row.id) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(row.title)
                                    Text(row.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if row.isRead {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label(message, systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
        }
    }
}

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
```

The view model's state and inputs are the same as the closure version. Only the binding changed, and the view model still has no SwiftUI import: `isShowingAlert` is a plain `Bool` property. SwiftUI is covered from Module 34; for now, notice the shape: `@State` owns the view model, `.task` calls the load input, the `switch` renders the state, buttons call inputs.

- **`@ObservationIgnored`** excludes `repository` and `books` from tracking. The view never reads them, so tracking them would be wasted work. (`let` properties are never tracked; the attribute on `repository` is just explicit.)
- **`isShowingAlert`** is a computed property over `alertMessage`. Reading it reads `alertMessage`, so it's tracked through that.

### How Observation tracks

Observation isn't SwiftUI-specific: it's a Swift module that ships with the toolchain, Linux included. `withObservationTracking(_:onChange:)` runs a closure, records which observable properties it read, and calls `onChange` **once**, just before the first of them changes. SwiftUI calls it around `body`. You can call it yourself to see the rules:

```swift
import Observation

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    var isRead: Bool
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class ReadingListViewModel {
    private(set) var header = ""
    private(set) var alertMessage: String?
    @ObservationIgnored private var books: [Book]

    init(books: [Book]) {
        self.books = books
    }

    func load() {
        header = "loading"
        header = "\(books.filter(\.isRead).count) of \(books.count) read"
    }

    func didSelect(id: Int, saveSucceeds: Bool) {
        guard saveSucceeds else {
            alertMessage = "Couldn't save."
            return
        }
        if let index = books.firstIndex(where: { $0.id == id }) {
            books[index].isRead = true
        }
        header = "\(books.filter(\.isRead).count) of \(books.count) read"
    }
}

if #available(macOS 14, iOS 17, *) {
    let viewModel = ReadingListViewModel(books: [
        Book(id: 1, title: "Kindred", isRead: true),
        Book(id: 2, title: "Piranesi", isRead: false),
    ])

    // Like a view that only shows the header.
    withObservationTracking {
        _ = viewModel.header
    } onChange: {
        print("header view: will change")
    }

    print("load")
    viewModel.load()
    print("header is now \(viewModel.header)")

    print("save fails")
    viewModel.didSelect(id: 2, saveSucceeds: false)

    print("save succeeds")
    viewModel.didSelect(id: 2, saveSucceeds: true)
    print("header is now \(viewModel.header)")
}
```

```output
load
header view: will change
header is now 1 of 2 read
save fails
save succeeds
header is now 2 of 2 read
```

Three rules show up in that output:

1. **Only properties that were read are tracked.** The failed save changed `alertMessage`, which the closure never read, so nothing fired. A SwiftUI view that doesn't show the alert isn't re-rendered when it changes.
2. **`onChange` runs before the change**, during the setter, so it fires on the first assignment (`"loading"`), not the last.
3. **Tracking is one-shot.** `load()` assigns `header` twice and the successful save assigns it again, but `onChange` ran once. To keep observing, you call `withObservationTracking` again, reading the properties again. SwiftUI does exactly that: each change schedules a new `body` evaluation, which re-registers whatever that evaluation reads.

> [!note] The @available lines
> They're there because this block also runs as a macOS command-line program in CI, and Observation needs macOS 14. In an iOS app with a deployment target of iOS 17 or later you don't write them.

In UIKit, the closure binding is still the common choice. Recent UIKit releases can also track `@Observable` reads in some view and view controller update methods; check Apple's UIKit documentation for the release you target before relying on it. This course's UIKit examples use closures.

## MVP: a presenter and a passive view

MVP turns the relationship around. Instead of the view reading state, the **presenter tells the view what to show** through a protocol of display commands. The view is passive: it implements those commands and forwards events, nothing more.

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

    // MARK: Events from the view

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
            books = Self.ordered(books)
            showBooks()
        } catch {
            view?.showAlert(message: "Couldn't save. \"\(book.title)\" is still unread.")
        }
    }

    // MARK: Presentation logic

    private func load() async {
        view?.showLoading()
        do {
            books = Self.ordered(try await repository.books())
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

    private static func ordered(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
    }
}

// MARK: Test

enum RepositoryError: Error {
    case offline
}

actor FakeBookRepository: BookRepository {
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

let repository = FakeBookRepository(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
let presenter = ReadingListPresenter(repository: repository)
let view = RecordingView()
presenter.view = view

await presenter.viewDidLoad()
await presenter.didSelectRow(at: 0)
await repository.setOffline(true)
await presenter.didSelectRow(at: 0)
await presenter.didTapRetry()
await repository.setOffline(false)
await presenter.didTapRetry()

for entry in view.log {
    print(entry)
}
```

```output
loading
1 of 3 read: -Piranesi, -The Dispossessed, +Kindred
2 of 3 read: -The Dispossessed, +Kindred, +Piranesi
alert: Couldn't save. "The Dispossessed" is still unread.
loading
error: Couldn't load your books.
loading
2 of 3 read: -The Dispossessed, +Kindred, +Piranesi
```

The differences from MVVM:

- **The view only sends what it knows.** `didSelectRow(at:)` takes an index, because a passive view doesn't know about books or ids. The presenter keeps `books` in display order so the index maps to the right book.
- **The presenter pushes.** Nothing in the view reads the presenter's state; it just receives `show(header:rows:)`. There's no state to bind to, so there's no binding mechanism to choose.
- **`weak var view`.** The view controller owns the presenter (a strong `let`), so the presenter's reference back must be weak. That's why `ReadingListView` is an `AnyObject` protocol: only class types can be referenced weakly.
- **The test records calls.** `RecordingView` is a fake view that logs every command, and the test compares the log. The `retry` sequence shows the whole error path: loading, error, loading, rows.

The real view controller implements the protocol by updating views:

```swift ios
import UIKit

@MainActor
final class ReadingListViewController: UITableViewController, ReadingListView {
    private let presenter: ReadingListPresenter
    private var rows: [ReadingListRow] = []
    private let headerLabel = UILabel()

    init(presenter: ReadingListPresenter) {
        self.presenter = presenter
        super.init(style: .insetGrouped)
        presenter.view = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BookCell")
        headerLabel.textAlignment = .center
        headerLabel.frame.size.height = 44
        tableView.tableHeaderView = headerLabel
        Task { await presenter.viewDidLoad() }
    }

    // MARK: ReadingListView

    func showLoading() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        tableView.backgroundView = spinner
    }

    func show(header: String, rows: [ReadingListRow]) {
        tableView.backgroundView = nil
        headerLabel.text = header
        self.rows = rows
        tableView.reloadData()
    }

    func showError(message: String) {
        rows = []
        tableView.reloadData()
        let retry = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Retry") { [weak self] _ in
            guard let self else { return }
            Task { await self.presenter.didTapRetry() }
        })
        let label = UILabel()
        label.text = message
        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        tableView.backgroundView = stack
    }

    func showAlert(message: String) {
        let alert = UIAlertController(title: "Couldn't save", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = row.subtitle
        cell.contentConfiguration = content
        cell.accessoryType = row.isRead ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let index = indexPath.row
        Task { await presenter.didSelectRow(at: index) }
    }
}

// Declarations from the presenter block, trimmed to what this file needs.

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

    func viewDidLoad() async { await load() }
    func didTapRetry() async { await load() }

    func didSelectRow(at index: Int) async {
        guard books.indices.contains(index), !books[index].isRead else { return }
        let book = books[index]
        do {
            try await repository.markAsRead(id: book.id)
            books[index].isRead = true
            showBooks()
        } catch {
            view?.showAlert(message: "Couldn't save. \"\(book.title)\" is still unread.")
        }
    }

    private func load() async {
        view?.showLoading()
        do {
            books = try await repository.books()
            showBooks()
        } catch {
            view?.showError(message: "Couldn't load your books.")
        }
    }

    private func showBooks() {
        let rows = books.map { ReadingListRow(title: $0.title, subtitle: $0.author, isRead: $0.isRead) }
        view?.show(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
    }
}
```

## MVVM or MVP?

Both remove decisions from the view controller, and both are tested without UIKit. The differences are in direction and in what tests check.

| | MVVM | MVP |
| --- | --- | --- |
| Who drives the view | The view reads state and re-renders | The presenter calls the view's methods |
| Reference to the view | None | `weak var view` through a protocol |
| Binding needed | Yes: closure, Combine or Observation | No |
| Test asserts on | The state value after some inputs | The sequence of calls on a fake view |
| Fits SwiftUI | Naturally: `@Observable` plus `body` | Awkwardly: SwiftUI views aren't objects you call |
| Fits UIKit | Well, with a closure binding | Well; the view controller is the passive view |

The testing difference matters more than it looks. A **state test** says "after loading and marking book 3, the screen shows this". It doesn't care how many times `onChange` fired on the way, so refactoring the view model's internals rarely breaks it. A **call test** says "the view was told exactly these things, in this order". It catches a missing `showLoading()` that a state test can't see (the state was `.loading` at the start anyway), but it breaks when you legitimately reorder or merge calls.

In practice: MVVM with Observation is the default for SwiftUI code and increasingly for new UIKit code. MVP still shows up in UIKit codebases and is a reasonable choice there, especially when a team wants the view's interface written down as a protocol. Whichever you pick, keep the presentation object free of view types, and give it its dependencies through its initializer.

## Common mistakes

> [!error] A view model that references the view
> `weak var viewController: ReadingListViewController?` in the view model. It's now MVP with extra steps, and it needs UIKit to test. The view model exposes state; the view reads it.

> [!error] UIKit types in the view model
> `var headerColor: UIColor` or `var cover: UIImage`. The view model now imports UIKit and can't back a SwiftUI view or a Mac app. Expose an enum (`.complete`, `.inProgress`) or a URL, and let the view map it.

> [!error] Strong self in the binding closure
> `viewModel.onChange = { self.render() }`. The controller owns the view model, which owns the closure, which owns the controller. Use `[weak self]`.

> [!error] A strong reference from presenter to view
> `var view: ReadingListView?` without `weak`. The controller and presenter keep each other alive forever. Make the protocol `AnyObject` and the property `weak`.

> [!error] Expecting withObservationTracking to keep firing
> It calls `onChange` once. Code that registers once and expects updates forever sees only the first change. Re-register after each change, or let SwiftUI do it.

> [!error] One giant state struct with everything optional
> `var books: [Row]?; var error: String?; var isLoading: Bool`. It allows impossible combinations (loading and failed at once) that the view has to guess about. Use an enum for mutually exclusive situations, plus separate properties only for things that really coexist, like an alert over loaded rows.

## Exercises

````exercise
id: m32-l03-e1
type: comprehension
prompt: "Which statement correctly describes the difference between a view model and a presenter?"
choices:
  - text: "A view model exposes state that the view reads; a presenter holds a weak reference to a view protocol and calls its methods."
    correct: true
    why: "That's the direction difference: the view pulls from a view model, a presenter pushes to the view."
  - text: "A view model can be tested without UIKit; a presenter can't."
    correct: false
    why: "Both can. The presenter is tested with a recording fake view."
  - text: "A presenter is only for SwiftUI; a view model is only for UIKit."
    correct: false
    why: "Roughly the reverse in practice: view models fit SwiftUI naturally, and presenters are mostly found in UIKit code. Neither is limited to one."
  - text: "A view model calls the repository; a presenter never does."
    correct: false
    why: "Either can call a repository (or a use case, as in lesson 4)."
solution: |
  The defining difference is direction. A view model has no reference to the view; the view observes its state through a binding. A presenter has a (weak) reference to the view through a protocol and tells it what to show. That also explains the testing difference: view model tests compare state, presenter tests compare calls on a fake view.
````

````exercise
id: m32-l03-e2
type: prediction
prompt: "A view model with a didSet binding. How many times does onChange fire, and what does the program print?"
code: |
  @MainActor
  final class CounterViewModel {
      private(set) var title = "0 books" {
          didSet { onChange?() }
      }
      var onChange: (() -> Void)?
      private var count = 0

      func add(_ n: Int) {
          for _ in 0..<n {
              count += 1
              title = "\(count) books"
          }
      }

      func reset() {
          count = 0
          title = "0 books"
      }
  }

  let viewModel = CounterViewModel()
  var renders = 0
  viewModel.onChange = {
      renders += 1
      print("render \(renders): \(viewModel.title)")
  }
  viewModel.add(2)
  viewModel.reset()
  viewModel.reset()
  print("total renders: \(renders)")
output: |
  render 1: 1 books
  render 2: 2 books
  render 3: 0 books
  render 4: 0 books
  total renders: 4
solution: |
  `didSet` runs on **every** assignment, whether or not the value changed.

  - `add(2)` assigns `title` twice: "1 books", then "2 books". Two renders.
  - The first `reset()` assigns "0 books": a third render.
  - The second `reset()` assigns "0 books" again. The value is the same, but `didSet` still runs: a fourth render.

  ```output
  render 1: 1 books
  render 2: 2 books
  render 3: 0 books
  render 4: 0 books
  total renders: 4
  ```

  Two lessons from this. Intermediate states get rendered (the view briefly shows "1 books"), so compute the final value first and assign once. And if redundant renders matter, guard in `didSet`: `didSet { if title != oldValue { onChange?() } }`. (The "1 books" grammar is a separate bug, for a pluralization rule or a string catalog.)
````

````exercise
id: m32-l03-e3
type: prediction
prompt: "Observation tracking with two reads and a re-registration. What does the program print?"
code: |
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class ScreenModel {
      var title = "Reading List"
      var count = 0
      var alert: String?
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  func track(_ model: ScreenModel, label: String) {
      withObservationTracking {
          _ = model.title
          _ = model.count
      } onChange: {
          print("\(label) fired")
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let model = ScreenModel()
      track(model, label: "first")
      model.alert = "Oops"
      model.count += 1
      model.count += 1
      track(model, label: "second")
      model.title = "Books"
      print("count \(model.count)")
  }
output: |
  first fired
  second fired
  count 2
solution: |
  - `track(model, label: "first")` reads `title` and `count`.
  - Changing `alert` fires nothing: it wasn't read.
  - The first `count += 1` fires "first fired". The second doesn't: tracking is one-shot.
  - `track(model, label: "second")` registers again, reading `title` and `count`.
  - Changing `title` fires "second fired".

  ```output
  first fired
  second fired
  count 2
  ```

  This is SwiftUI's loop in miniature: render (track), change (fire once), render again (track again). Properties a render never reads, like `alert` here, don't cause re-renders.
````

````exercise
id: m32-l03-e4
type: solve
prompt: "Add pull-to-refresh to a view model. Write a `@MainActor` `ReadingListViewModel` with `state: State`, where `State` is `.loading`, `.loaded(titles: [String], isRefreshing: Bool)` or `.failed(String)`, plus `alertMessage: String?`. `load()` shows `.loading` and then the titles (sorted) or `.failed(\"Couldn't load your books.\")`. `refresh()` keeps the current titles visible with `isRefreshing: true`, then shows the new titles; if it fails, it keeps the old titles with `isRefreshing: false` and sets `alertMessage` to `\"Couldn't refresh.\"`. Test it with a fake repository: load, refresh with a new book added, then refresh while offline. Print the state after each step and the alert."
starter: |
  protocol TitleRepository: Sendable {
      func titles() async throws -> [String]
  }

  // Write the view model, a fake repository actor and the test.
rubric:
  - State is an enum; refreshing is part of the loaded case, so loading and refreshing are visibly different states.
  - A failed refresh keeps the old titles on screen and reports the failure through alertMessage instead of replacing the list with an error.
  - A failed initial load produces the failed state.
  - The test uses a fake repository that can add titles and go offline, and prints deterministic output.
solution: |
  ```swift
  protocol TitleRepository: Sendable {
      func titles() async throws -> [String]
  }

  @MainActor
  final class ReadingListViewModel {
      enum State: Equatable {
          case loading
          case loaded(titles: [String], isRefreshing: Bool)
          case failed(String)
      }

      private(set) var state = State.loading
      private(set) var alertMessage: String?
      private let repository: any TitleRepository

      init(repository: any TitleRepository) {
          self.repository = repository
      }

      func load() async {
          state = .loading
          do {
              state = .loaded(titles: try await repository.titles().sorted(), isRefreshing: false)
          } catch {
              state = .failed("Couldn't load your books.")
          }
      }

      func refresh() async {
          guard case .loaded(let current, false) = state else { return }
          state = .loaded(titles: current, isRefreshing: true)
          do {
              state = .loaded(titles: try await repository.titles().sorted(), isRefreshing: false)
          } catch {
              state = .loaded(titles: current, isRefreshing: false)
              alertMessage = "Couldn't refresh."
          }
      }
  }

  struct OfflineError: Error {}

  actor FakeTitleRepository: TitleRepository {
      private var stored: [String]
      private var isOffline = false
      init(_ titles: [String]) { stored = titles }
      func add(_ title: String) { stored.append(title) }
      func setOffline(_ value: Bool) { isOffline = value }
      func titles() throws -> [String] {
          guard !isOffline else { throw OfflineError() }
          return stored
      }
  }

  let repository = FakeTitleRepository(["Piranesi", "Kindred"])
  let viewModel = ReadingListViewModel(repository: repository)

  await viewModel.load()
  print("after load: \(viewModel.state)")

  await repository.add("Beloved")
  await viewModel.refresh()
  print("after refresh: \(viewModel.state)")

  await repository.setOffline(true)
  await viewModel.refresh()
  print("after offline refresh: \(viewModel.state)")
  print("alert: \(viewModel.alertMessage ?? "none")")
  ```

  ```output
  after load: loaded(titles: ["Kindred", "Piranesi"], isRefreshing: false)
  after refresh: loaded(titles: ["Beloved", "Kindred", "Piranesi"], isRefreshing: false)
  after offline refresh: loaded(titles: ["Beloved", "Kindred", "Piranesi"], isRefreshing: false)
  alert: Couldn't refresh.
  ```

  The key decision is that a refresh failure is **not** the `failed` state: the user already has a list, and replacing it with an error screen would throw away good data. The `guard case .loaded(let current, false)` also ignores a second refresh while one is running. A real test would also check the intermediate `isRefreshing: true` state, for example with a repository that suspends until the test lets it continue (Module 33 shows how).
````

````exercise
id: m32-l03-e5
type: fill-in
prompt: "Complete the MVP wiring so the presenter can update the view without a retain cycle and the view protocol only exposes display commands."
code: |
  @MainActor
  protocol BookDetailView: [[1]] {
      func show(title: String, status: String)
      func showError(message: String)
  }

  @MainActor
  final class BookDetailPresenter {
      [[2]] var view: (any BookDetailView)?
      private let repository: any BookRepository

      init(repository: any BookRepository) {
          self.repository = repository
      }
  }

  final class BookDetailViewController: UIViewController, BookDetailView {
      private [[3]] presenter: BookDetailPresenter

      init(presenter: BookDetailPresenter) {
          self.presenter = presenter
          super.init(nibName: nil, bundle: nil)
          presenter.view = [[4]]
      }
      // ...
  }
blanks:
  - id: "1"
    answers: ["AnyObject"]
  - id: "2"
    answers: ["weak"]
  - id: "3"
    answers: ["let"]
  - id: "4"
    answers: ["self"]
solution: |
  The view protocol is `AnyObject` so it can be referenced `weak`ly. The presenter's `view` is `weak`, and the controller owns the presenter with a strong `let`. The controller registers itself with `presenter.view = self` once its stored properties are initialized (after `super.init`). Ownership runs one way: controller → presenter, with a weak reference back.
````

````exercise
id: m32-l03-e6
type: find-errors
prompt: "A view model under review. Which comments point at real problems?"
code: |
  import UIKit

  @MainActor
  final class ProfileViewModel {
      weak var viewController: ProfileViewController?
      var isLoading = false
      var errorMessage: String?
      var name: String?
      var avatarTint: UIColor = .systemGray
      private let repository = RemoteProfileRepository()

      func load() async {
          isLoading = true
          do {
              let profile = try await repository.profile()
              name = profile.name
              avatarTint = profile.isPremium ? .systemYellow : .systemGray
          } catch {
              errorMessage = error.localizedDescription
          }
          viewController?.render()
      }
  }
choices:
  - text: "It holds a reference to the view controller, so it can't be tested without UIKit and only works with one view."
    correct: true
    why: "Expose state and a binding; let the view read it."
  - text: "isLoading is never set back to false."
    correct: true
    why: "After the first load the screen shows a spinner forever. An enum state makes this kind of bug hard to write."
  - text: "Separate optionals and flags allow impossible combinations, such as loading with an error and a name."
    correct: true
    why: "A State enum (loading, loaded(name:), failed(message:)) makes them unrepresentable."
  - text: "avatarTint is a UIColor, which ties the view model to UIKit."
    correct: true
    why: "Expose an enum or a Bool (isPremium) and map it to a color in the view."
  - text: "The repository is created inside the view model instead of injected."
    correct: true
    why: "Tests can't substitute a fake. Take an `any ProfileRepository` in init."
  - text: "async methods aren't allowed on a @MainActor class."
    correct: false
    why: "They are; the method runs on the main actor and suspends at each await."
rubric:
  - Finds the reference to the view controller.
  - Finds the loading flag that never resets.
  - Finds the impossible state combinations.
  - Finds the UIKit type in the view model.
  - Finds the hard-coded repository.
solution: |
  Five real problems. A fixed version takes `repository: any ProfileRepository` in its initializer, exposes `private(set) var state: State` with `case loading`, `case loaded(name: String, isPremium: Bool)` and `case failed(message: String)`, has an `onChange` closure (or `@Observable`), and imports nothing but Foundation if it needs it. The view maps `isPremium` to a color and `state` to views. Note also `error.localizedDescription`: showing a raw system error message is rarely what you want; the view model should choose a message for the screen.
````

````exercise
id: m32-l03-e7
type: design
prompt: "Your team's app is UIKit today, with new screens to be written in SwiftUI over the next year. Some screens will exist in both for a while. Choose MVVM or MVP for the presentation layer and explain how the choice plays out in both frameworks, in tests and during the migration."
rubric:
  - Picks MVVM (or justifies MVP with a concrete plan for SwiftUI).
  - Explains that one view model can back a UIKit controller (closure or Observation binding) and a SwiftUI view during the migration.
  - Describes view model tests as state comparisons that don't change when the view is rewritten.
  - Mentions keeping view types out of the view model so the same type works in both.
solution: |
  MVVM fits this situation best. A view model with display state and inputs, and no UIKit or SwiftUI types, can drive a UIKit controller today and a SwiftUI view tomorrow. Mark it `@Observable`: SwiftUI binds to it directly, and the UIKit controller can still use an explicit closure binding (or Observation tracking where the team has verified UIKit's support on its minimum OS version).

  The tests are the biggest win. They drive inputs and compare `state`, so rewriting a screen from UIKit to SwiftUI doesn't touch them, and they become the safety net for the migration: if the new SwiftUI screen uses the same view model, the logic is already covered. MVP would make the SwiftUI side awkward, since a SwiftUI view isn't an object a presenter can call methods on; you'd end up adding state to the presenter, which turns it into a view model anyway.
````

## Summary

- A **view model** holds display state (an `Equatable` enum for exclusive situations, separate properties for things like an alert that coexist) and input methods. It never references the view and has no view types.
- **Bindings** connect it to the view: a `didSet` closure is enough for UIKit; `@Observable` lets SwiftUI track what `body` reads.
- **Observation** tracks only the properties a closure read, calls `onChange` once just before the first change, and must be re-registered to keep observing. SwiftUI re-registers on every render.
- A **presenter** drives a **passive view** through an `AnyObject` protocol it holds weakly. The view forwards events (often with raw indexes) and implements display commands.
- View model tests compare **state**; presenter tests compare **calls** on a recording fake. State tests survive refactoring better; call tests check exactly what the view was told.
- Default to MVVM, especially with SwiftUI. MVP remains a sound choice in UIKit code.
