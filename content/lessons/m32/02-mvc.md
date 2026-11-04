---
id: m32-l02
title: MVC and the Massive View Controller
description: "Build the reading list the way UIKit nudges you to, then take it apart. You see what Apple's Model-View-Controller assigns to each role, watch one view controller absorb loading, sorting, formatting, saving and error handling, and pull those jobs out into a data source object, a model that owns the state and talks to the repository, and a child view controller for the error state."
module: m32
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l01]
objectives:
  - Describe the model, view and controller roles in Apple's MVC and what UIKit's UIViewController adds to the controller.
  - Recognize the responsibilities that accumulate in a Massive View Controller.
  - Extract a table view data source into its own object fed by a plain display model, and keep it alive.
  - Move state and repository calls into a model object that notifies the controller of changes.
  - Embed and remove a child view controller with the correct containment calls.
terms:
  - term: MVC (Model-View-Controller)
    definition: "Apple's traditional pattern for Cocoa and UIKit apps. Models hold data and logic, views draw and receive touches, and controllers sit between them: they update views when models change and update models when the user acts."
  - term: Massive View Controller
    definition: "A nickname for a UIViewController that has taken on networking, sorting, formatting, persistence and error handling besides managing its views. It's a symptom of putting everything in the one class UIKit gives every screen."
  - term: Data source object
    definition: "A separate NSObject subclass that conforms to UITableViewDataSource (or a collection view's) and answers row counts and cells from a display model, so the controller doesn't."
  - term: Model controller
    definition: "A plain object that owns a screen's data and the calls that load and change it, and tells its observers when it changed. It's the model side of MVC done properly; it knows nothing about views."
  - term: View controller containment
    definition: "UIKit's API for putting one view controller's view inside another's: addChild(_:), adding the child's view, didMove(toParent:), and the reverse with willMove(toParent: nil) and removeFromParent()."
mastery:
  - List the jobs a given view controller is doing and say which belong elsewhere.
  - Write a UITableViewDataSource object driven by a display struct, and explain why the controller must hold it strongly.
  - Write a model controller with load and mark-as-read, test its state changes with a fake repository, and wire it to a controller with a weak closure.
  - Write embed and remove helpers for a child view controller in the right order.
resources: [uikit-custom-container, uikit-uiviewcontroller, uikit-uitableview, uikit-list-content-configuration, uikit-uialertcontroller, swift-book-closures]
cards:
  - id: m32-l02-c1
    front: What are the three roles in Apple's MVC?
    back: "Model: data and the logic on it. View: drawing and touch handling. Controller: mediates, updating views when the model changes and updating the model when the user acts. Models and views don't know about each other."
  - id: m32-l02-c2
    front: Why do UIKit view controllers tend to become massive?
    back: "Every screen gets one by default, and it already handles the view's lifecycle, is usually the data source and delegate, and is the natural place for a Task that loads data. Without a deliberate split, every new job lands there."
  - id: m32-l02-c3
    front: You set tableView.dataSource = ReadingListDataSource() and the table is empty. Why?
    back: "UITableView holds its dataSource weakly. Nothing else holds the new object, so it's released right away. Keep it in a stored property of the view controller."
  - id: m32-l02-c4
    front: In what order do you add a child view controller?
    back: "addChild(child) (which calls child.willMove(toParent:) for you), then add child.view to your view hierarchy and size it, then child.didMove(toParent: self)."
  - id: m32-l02-c5
    front: In what order do you remove a child view controller?
    back: "child.willMove(toParent: nil), then child.view.removeFromSuperview(), then child.removeFromParent() (which calls didMove(toParent: nil) for you)."
---

## The idea in one sentence

MVC gives every screen a controller that sits between models and views, and in UIKit that controller is the `UIViewController` you already have, so unless you **move jobs out of it on purpose** (into a data source, a model and child controllers) it ends up doing everything.

## Apple's MVC

Model-View-Controller is the pattern UIKit and AppKit were designed around. Each object plays one of three roles:

```text
           user action                     update
   View ──────────────────▶ Controller ──────────────▶ Model
    ▲                          │  ▲                      │
    │        update            │  │      changed         │
    └──────────────────────────┘  └──────────────────────┘
```

- **Model** objects hold the app's data and the logic that operates on it: `Book`, the ordering rule, the repository. They don't know any view exists.
- **View** objects draw and receive touches: `UITableView`, `UILabel`, `UIButton`. They're reusable and know nothing about books.
- **Controllers** mediate. When the user acts, the controller updates the model. When the model changes, the controller updates the views.

That's a sound division. The trouble in UIKit is that `UIViewController` is more than a mediator: it owns its view, receives the lifecycle callbacks (Module 22), is the obvious data source and delegate for its table, presents alerts, and is where a `Task` naturally starts. It's also the only class Xcode creates for a new screen. So every job that doesn't obviously belong elsewhere lands there.

## The reading list, all in one controller

Here's the feature from lesson 1 written the way it often is. It works:

```swift ios
import UIKit

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

final class ReadingListViewController: UITableViewController {
    private let repository: any BookRepository
    private var books: [Book] = []
    private let headerLabel = UILabel()

    init(repository: any BookRepository) {
        self.repository = repository
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
        headerLabel.font = .preferredFont(forTextStyle: .subheadline)
        headerLabel.frame.size.height = 44
        tableView.tableHeaderView = headerLabel
        loadBooks()
    }

    private func loadBooks() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        tableView.backgroundView = spinner
        Task {
            do {
                let loaded = try await repository.books()
                books = loaded.sorted { lhs, rhs in
                    lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
                }
                headerLabel.text = "\(books.filter(\.isRead).count) of \(books.count) read"
                tableView.backgroundView = nil
                tableView.reloadData()
            } catch {
                let label = UILabel()
                label.text = "Couldn't load your books."
                let retry = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Retry") { [weak self] _ in
                    self?.loadBooks()
                })
                let stack = UIStackView(arrangedSubviews: [label, retry])
                stack.axis = .vertical
                stack.spacing = 12
                stack.alignment = .center
                stack.translatesAutoresizingMaskIntoConstraints = false
                let container = UIView()
                container.addSubview(stack)
                NSLayoutConstraint.activate([
                    stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                ])
                tableView.backgroundView = container
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        books.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookCell", for: indexPath)
        let book = books[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = book.title
        content.secondaryText = book.author
        cell.contentConfiguration = content
        cell.accessoryType = book.isRead ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let book = books[indexPath.row]
        guard !book.isRead else { return }
        Task {
            do {
                try await repository.markAsRead(id: book.id)
                if let index = books.firstIndex(where: { $0.id == book.id }) {
                    books[index].isRead = true
                }
                books = books.sorted { lhs, rhs in
                    lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
                }
                headerLabel.text = "\(books.filter(\.isRead).count) of \(books.count) read"
                self.tableView.reloadData()
            } catch {
                let alert = UIAlertController(
                    title: "Couldn't save",
                    message: "\"\(book.title)\" is still unread. Check your connection and try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }
}
```

At least it receives its repository instead of creating one. Count its jobs anyway:

1. View setup: registering cells, the header label.
2. Loading data and deciding what "loading" looks like.
3. The ordering rule, **written twice**, once in each `Task`.
4. The header text, also written twice.
5. Building the error UI, layout constraints included.
6. Answering the table's data source questions.
7. Saving through the repository and updating local state afterward.
8. Deciding what a save failure looks like.

At about 110 lines it's readable. The real ones reach 1,500, because each new requirement (pull to refresh, a filter, a swipe to delete, analytics) adds another job here. And none of it can be tested without UIKit: the ordering rule, the header text and the "stays unread on failure" behavior only run inside a `UITableViewController` on the main thread with a window.

MVC doesn't require this. The model side is just too thin: `Book` is a struct with no behavior, so everything else migrated into the controller. The fixes below stay entirely within MVC.

## Extraction 1: a data source object

The table's questions ("how many rows?", "what's in row 3?") can be answered by any object. Give them to one that's fed a **display model**, a plain struct describing what the table shows:

```swift
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    var isRead: Bool
}

/// What the reading list screen shows, computed from books. No UIKit.
struct ReadingListContent: Equatable {
    struct Row: Equatable {
        let id: Int
        let title: String
        let subtitle: String
        let isChecked: Bool
    }

    let header: String
    let rows: [Row]

    init(books: [Book]) {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        header = "\(books.filter(\.isRead).count) of \(books.count) read"
        rows = ordered.map { book in
            Row(id: book.id, title: book.title, subtitle: book.author, isChecked: book.isRead)
        }
    }
}

let content = ReadingListContent(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
print(content.header)
for row in content.rows {
    print(row.isChecked ? "[x]" : "[ ]", row.title, "-", row.subtitle)
}
print(content == ReadingListContent(books: []))
```

```output
1 of 3 read
[ ] Piranesi - Susanna Clarke
[ ] The Dispossessed - Ursula K. Le Guin
[x] Kindred - Octavia E. Butler
false
```

`ReadingListContent` is the part worth testing (the order, the header, which rows are checked), and it's plain Swift. Being `Equatable` means a test can compare a whole screen's content in one `#expect`. (A real app might keep the ordering rule in the domain's `ReadingList.ordered` from lesson 1 and call it here; it's inlined to keep the block short.)

The UIKit part becomes a thin adapter:

```swift ios
import UIKit

struct ReadingListContent: Equatable {
    struct Row: Equatable {
        let id: Int
        let title: String
        let subtitle: String
        let isChecked: Bool
    }

    let header: String
    let rows: [Row]
}

@MainActor
final class ReadingListDataSource: NSObject, UITableViewDataSource {
    static let cellIdentifier = "BookCell"

    var content = ReadingListContent(header: "", rows: [])

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        content.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = content.rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = row.title
        configuration.secondaryText = row.subtitle
        cell.contentConfiguration = configuration
        cell.accessoryType = row.isChecked ? .checkmark : .none
        return cell
    }
}
```

- It's an `NSObject` subclass because `UITableViewDataSource` is an Objective-C protocol.
- It has no logic: index into `rows`, copy fields into a configuration. Nothing in it needs a test.
- The same `ReadingListContent` could drive a diffable data source (Module 24) or a SwiftUI `List`; the `id` on each row is there for that.

> [!warning] The table doesn't keep its data source alive
> `UITableView` declares `dataSource` and `delegate` as `weak`. `tableView.dataSource = ReadingListDataSource()` compiles, the new object is released at the end of the line, and the table shows nothing. Store the data source in a property of the view controller and assign that.

## Extraction 2: a model that owns the state

The loading, the saving and "what happens on failure" are logic about the reading list, not about views. In MVC they belong to the model side. Since `Book` is a value, put them in a **model controller**: an object that owns the screen's books, talks to the repository and tells whoever's listening that something changed.

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
final class ReadingListModel {
    enum Status: Equatable {
        case idle, loading, loaded, failed
    }

    private let repository: any BookRepository
    private(set) var books: [Book] = []
    private(set) var status = Status.idle

    /// Called after every change to books or status.
    var onChange: (() -> Void)?
    /// Called when saving a book fails; the book is unchanged.
    var onSaveError: ((Book) -> Void)?

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        status = .loading
        onChange?()
        do {
            books = ReadingList.ordered(try await repository.books())
            status = .loaded
        } catch {
            status = .failed
        }
        onChange?()
    }

    func markAsRead(id: Int) async {
        guard let book = books.first(where: { $0.id == id }), !book.isRead else { return }
        do {
            try await repository.markAsRead(id: id)
            var updated = book
            updated.isRead = true
            books = ReadingList.ordered(books.map { $0.id == id ? updated : $0 })
            onChange?()
        } catch {
            onSaveError?(book)
        }
    }
}

// A fake repository with an offline switch, as in lesson 1.
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

// The "test": drive the model and print what a controller would be told.
let repository = FakeBookRepository(books: [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "The Dispossessed", author: "Ursula K. Le Guin", isRead: false),
    Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
])
let model = ReadingListModel(repository: repository)
model.onChange = { [weak model] in
    guard let model else { return }
    let titles = model.books.map { ($0.isRead ? "+" : "-") + $0.title }
    print("changed: \(model.status) \(titles)")
}
model.onSaveError = { book in
    print("save failed: \(book.title) is still unread")
}

await model.load()
await model.markAsRead(id: 3)
await model.markAsRead(id: 1)
await repository.setOffline(true)
await model.markAsRead(id: 2)
await model.load()
```

```output
changed: loading []
changed: loaded ["-Piranesi", "-The Dispossessed", "+Kindred"]
changed: loaded ["-The Dispossessed", "+Kindred", "+Piranesi"]
save failed: The Dispossessed is still unread
changed: loading ["-The Dispossessed", "+Kindred", "+Piranesi"]
changed: failed ["-The Dispossessed", "+Kindred", "+Piranesi"]
```

Every behavior from lesson 1's table shows up in the output, and none of it needed UIKit:

- **Load** reports `loading`, then `loaded` with the ordered books.
- **Mark as read** saves first and only then updates `books`, so a failure leaves the book unread. Marking book 1, already read, does nothing: no save, no change notification.
- **The save failure** goes through its own callback, because it's an event ("show an alert once"), not a state the screen stays in.
- **The failed reload** keeps the old books. Whether the screen shows them under an error banner or replaces them with an error view is the controller's choice; the model just reports `failed`.

The model is `@MainActor` because the controller reads `books` and `status` on the main thread to update views, and the callbacks run there too. The `await` calls to the repository actor suspend without blocking the main thread.

> [!note] Model controller or view model?
> This object is close to lesson 3's view model. The difference is what it exposes: `ReadingListModel` exposes **domain data** (`[Book]`, a status) and the controller decides how to show it. A view model exposes **display state** (`ReadingListContent`, "2 of 4 read") so the view has nothing left to decide. Both are fine; the line between "MVC with a good model" and "MVVM" is thinner than the names suggest.

## Extraction 3: child view controllers

The error view with its Retry button is a small screen with its own layout and behavior. UIKit lets you make it a separate view controller and **embed** it in the reading list's view. That's view controller containment, the same API `UINavigationController` and `UITabBarController` use to show their children.

The calls must come in a specific order so UIKit can forward appearance callbacks (`viewWillAppear` and friends) and trait changes to the child:

```swift ios
import UIKit

final class ErrorViewController: UIViewController {
    private let message: String
    private let onRetry: () -> Void

    init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        let retry = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Retry") { [weak self] _ in
            self?.onRetry()
        })
        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}

extension UIViewController {
    func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}
```

- **Adding:** `addChild(_:)` creates the parent-child relationship and calls `child.willMove(toParent: self)` for you. Then you put the child's view in your hierarchy and size it (here with autoresizing to fill; constraints work too). Finally `child.didMove(toParent: self)` tells the child the transition is complete; UIKit doesn't call that one for you when adding.
- **Removing** mirrors it: `willMove(toParent: nil)` first (UIKit doesn't call it for you when removing), then remove the view, then `removeFromParent()`, which calls `didMove(toParent: nil)`.
- `ErrorViewController` reports Retry through a closure and knows nothing about books. It can be reused on any screen that loads something.

Child controllers are a good fit for **whole regions with their own lifecycle**: an error or empty state, a header with its own data, a map above a list. They're overkill for a label.

## The controller after the extractions

Put together, the reading list controller only connects things: it renders the model's state into views and forwards taps to the model.

```swift ios
import UIKit

@MainActor
final class ReadingListViewController: UIViewController, UITableViewDelegate {
    private let model: ReadingListModel
    private let dataSource = ReadingListDataSource()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var errorChild: ErrorViewController?

    init(model: ReadingListModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Reading List"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ReadingListDataSource.cellIdentifier)
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        headerLabel.textAlignment = .center
        headerLabel.frame.size.height = 44
        tableView.tableHeaderView = headerLabel
        tableView.backgroundView = spinner
        view.addSubview(tableView)

        model.onChange = { [weak self] in self?.render() }
        model.onSaveError = { [weak self] book in self?.showSaveError(for: book) }
        Task { await model.load() }
    }

    private func render() {
        switch model.status {
        case .idle, .loading:
            spinner.startAnimating()
            hideError()
        case .loaded:
            spinner.stopAnimating()
            hideError()
            dataSource.content = ReadingListContent(books: model.books)
            headerLabel.text = dataSource.content.header
            tableView.reloadData()
        case .failed:
            spinner.stopAnimating()
            showError()
        }
    }

    private func showError() {
        guard errorChild == nil else { return }
        let child = ErrorViewController(message: "Couldn't load your books.") { [weak self] in
            guard let self else { return }
            Task { await self.model.load() }
        }
        embed(child)
        errorChild = child
    }

    private func hideError() {
        guard let errorChild else { return }
        remove(errorChild)
        self.errorChild = nil
    }

    private func showSaveError(for book: Book) {
        let alert = UIAlertController(
            title: "Couldn't save",
            message: "\"\(book.title)\" is still unread. Check your connection and try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = dataSource.content.rows[indexPath.row].id
        Task { await model.markAsRead(id: id) }
    }
}

// Supporting types from earlier in the lesson, repeated so this block compiles on its own.

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
final class ReadingListModel {
    enum Status: Equatable {
        case idle, loading, loaded, failed
    }

    private let repository: any BookRepository
    private(set) var books: [Book] = []
    private(set) var status = Status.idle
    var onChange: (() -> Void)?
    var onSaveError: ((Book) -> Void)?

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        status = .loading
        onChange?()
        do {
            books = try await repository.books()
            status = .loaded
        } catch {
            status = .failed
        }
        onChange?()
    }

    func markAsRead(id: Int) async {
        guard let book = books.first(where: { $0.id == id }), !book.isRead else { return }
        do {
            try await repository.markAsRead(id: id)
            books = books.map { $0.id == id ? Book(id: $0.id, title: $0.title, author: $0.author, isRead: true) : $0 }
            onChange?()
        } catch {
            onSaveError?(book)
        }
    }
}

struct ReadingListContent: Equatable {
    struct Row: Equatable {
        let id: Int
        let title: String
        let subtitle: String
        let isChecked: Bool
    }

    let header: String
    let rows: [Row]

    init(books: [Book]) {
        let ordered = books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
        header = "\(books.filter(\.isRead).count) of \(books.count) read"
        rows = ordered.map { Row(id: $0.id, title: $0.title, subtitle: $0.author, isChecked: $0.isRead) }
    }
}

@MainActor
final class ReadingListDataSource: NSObject, UITableViewDataSource {
    static let cellIdentifier = "BookCell"
    var content = ReadingListContent(books: [])

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        content.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = content.rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier, for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = row.title
        configuration.secondaryText = row.subtitle
        cell.contentConfiguration = configuration
        cell.accessoryType = row.isChecked ? .checkmark : .none
        return cell
    }
}

final class ErrorViewController: UIViewController {
    private let message: String
    private let onRetry: () -> Void

    init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = message
        let retry = UIButton(configuration: .filled(), primaryAction: UIAction(title: "Retry") { [weak self] _ in
            self?.onRetry()
        })
        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}

extension UIViewController {
    func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    func remove(_ child: UIViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}
```

`ReadingListViewController` is now about 100 lines of wiring, and the parts with decisions in them (`ReadingListModel` and `ReadingListContent`) are plain Swift with tests. Notice what's left: `render()` still has a `switch` that decides which views to show for each status. That's presentation logic, small enough here to leave in the controller. When it grows (empty states, partial errors, a banner over stale data), it's a sign to move it out, which is exactly what the next lesson's view model and presenter do.

## Common mistakes

> [!error] A data source nobody owns
> `tableView.dataSource = ReadingListDataSource()` leaves the table empty, because the table's reference is weak. Keep the data source in a stored property.

> [!error] Forgetting didMove(toParent:)
> `addChild(child)` and `view.addSubview(child.view)` without `child.didMove(toParent: self)`. The child shows up, but any work it does in `didMove(toParent:)` never runs, and Apple's documentation requires the call to complete the transition. A helper like `embed(_:)` makes it impossible to forget.

> [!error] Adding only the view
> `view.addSubview(child.view)` without `addChild`. The child's view appears but the child isn't in the controller hierarchy, so it doesn't get appearance callbacks or trait changes forwarded, and its `parent` and `navigationController` are `nil`.

> [!error] The model calling the controller
> A `ReadingListModel` with a `weak var viewController: ReadingListViewController?`. Now the model can't be tested without UIKit and only works with one screen. Report changes through a closure or protocol the model defines.

> [!error] Strong self in the model's callbacks
> `model.onChange = { self.render() }`. The controller holds the model, the model holds the closure, the closure holds the controller: a cycle (Module 13). Capture `[weak self]`.

## Exercises

````exercise
id: m32-l02-e1
type: comprehension
prompt: "A view controller has this in viewDidLoad, and the table appears empty. The data source's methods are correct. What's wrong?"
code: |
  override func viewDidLoad() {
      super.viewDidLoad()
      tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BookCell")
      let dataSource = ReadingListDataSource()
      dataSource.content = ReadingListContent(books: books)
      tableView.dataSource = dataSource
      tableView.reloadData()
  }
choices:
  - text: "The table holds its data source weakly, and the local variable is the only strong reference, so the data source is released when viewDidLoad returns."
    correct: true
    why: "UITableView declares dataSource as weak. Store the data source in a property."
  - text: "reloadData() must be called before setting dataSource."
    correct: false
    why: "The order is fine; reloadData asks the current data source."
  - text: "A data source must be the view controller itself."
    correct: false
    why: "Any object conforming to UITableViewDataSource works."
  - text: "register(_:forCellReuseIdentifier:) must come after setting dataSource."
    correct: false
    why: "Registration only has to happen before cells are dequeued."
solution: |
  `UITableView` keeps a `weak` reference to its `dataSource` (and `delegate`), to avoid a cycle in the common case where the view controller is the data source. When a separate object is the data source, something else has to own it. Make it a stored property: `private let dataSource = ReadingListDataSource()`, and assign `tableView.dataSource = dataSource` in `viewDidLoad`.
````

````exercise
id: m32-l02-e2
type: prediction
prompt: "A trimmed model controller and a fake repository that fails on one specific book. What does the program print?"
code: |
  struct Book: Sendable {
      let id: Int
      var isRead: Bool
  }

  struct SaveError: Error {}

  actor FlakyRepository {
      private var stored = [Book(id: 1, isRead: false), Book(id: 2, isRead: false)]
      func books() -> [Book] { stored }
      func markAsRead(id: Int) throws {
          guard id != 2 else { throw SaveError() }
          stored[stored.firstIndex { $0.id == id }!].isRead = true
      }
  }

  @MainActor
  final class Model {
      let repository = FlakyRepository()
      private(set) var books: [Book] = []
      var onChange: (() -> Void)?

      func load() async {
          books = await repository.books()
          onChange?()
      }

      func markAsRead(id: Int) async {
          guard let index = books.firstIndex(where: { $0.id == id }), !books[index].isRead else { return }
          books[index].isRead = true
          onChange?()
          do {
              try await repository.markAsRead(id: id)
          } catch {
              books[index].isRead = false
              onChange?()
          }
      }
  }

  let model = Model()
  var changes = 0
  model.onChange = {
      changes += 1
      print(changes, model.books.map { $0.isRead ? "read" : "unread" })
  }
  await model.load()
  await model.markAsRead(id: 1)
  await model.markAsRead(id: 1)
  await model.markAsRead(id: 2)
output: |
  1 ["unread", "unread"]
  2 ["read", "unread"]
  3 ["read", "read"]
  4 ["read", "unread"]
solution: |
  This model is **optimistic**: it updates `books` and notifies before saving, and rolls back if the save fails.

  1. `load()` stores two unread books and notifies once.
  2. `markAsRead(id: 1)`: book 1 becomes read, notify (change 2). The save succeeds, nothing else happens.
  3. `markAsRead(id: 1)` again: the guard sees it's already read and returns. No notification.
  4. `markAsRead(id: 2)`: book 2 becomes read, notify (change 3, both read). The save throws, so it's set back to unread and the model notifies again (change 4).

  ```output
  1 ["unread", "unread"]
  2 ["read", "unread"]
  3 ["read", "read"]
  4 ["read", "unread"]
  ```

  The lesson's model saves first and updates afterward, which is simpler but makes the checkmark wait for the network. Optimistic updates feel faster, at the cost of a visible rollback on failure. Either is fine, as long as the model's tests pin down which one you chose. (Holding `index` across the `await` is safe here only because nothing else changes `books` in between; with a reload running concurrently you'd look the book up again by id.)
````

````exercise
id: m32-l02-e3
type: fill-in
prompt: "Complete the helpers that add and remove a child view controller."
code: |
  extension UIViewController {
      func embed(_ child: UIViewController) {
          [[1]](child)
          child.view.frame = view.bounds
          view.addSubview(child.view)
          child.[[2]](toParent: self)
      }

      func remove(_ child: UIViewController) {
          child.[[3]](toParent: nil)
          child.view.[[4]]()
          child.[[5]]()
      }
  }
blanks:
  - id: "1"
    answers: ["addChild"]
  - id: "2"
    answers: ["didMove"]
  - id: "3"
    answers: ["willMove"]
  - id: "4"
    answers: ["removeFromSuperview"]
  - id: "5"
    answers: ["removeFromParent"]
solution: |
  Adding: `addChild(child)` (which calls `willMove(toParent: self)` for you), add the view, then `child.didMove(toParent: self)`. Removing: `child.willMove(toParent: nil)`, `child.view.removeFromSuperview()`, then `child.removeFromParent()` (which calls `didMove(toParent: nil)` for you). Each direction has exactly one call you must make yourself: `didMove` when adding, `willMove` when removing.
````

````exercise
id: m32-l02-e4
type: find-errors
prompt: "A reviewer is looking at this profile screen. Which comments are real problems?"
code: |
  final class ProfileViewController: UIViewController {
      private let session = URLSession.shared
      private var user: User?
      private let avatarView = UIImageView()
      private let statsChild = StatsViewController()

      override func viewDidLoad() {
          super.viewDidLoad()
          view.addSubview(statsChild.view)
          Task {
              let url = URL(string: "https://api.example.com/v1/me")!
              let (data, _) = try await session.data(from: url)
              let decoder = JSONDecoder()
              decoder.keyDecodingStrategy = .convertFromSnakeCase
              user = try decoder.decode(User.self, from: data)
              let followers = user!.followers
              title = followers > 999 ? "\(followers / 1000)k followers" : "\(followers) followers"
          }
      }
  }
choices:
  - text: "The child's view is added without addChild and didMove(toParent:)."
    correct: true
    why: "StatsViewController won't get appearance callbacks or trait changes. Use the full containment sequence."
  - text: "The controller builds requests and decodes JSON itself, so the screen can't be tested without the network."
    correct: true
    why: "Inject a repository that returns a User, as in Module 30."
  - text: "The follower-count formatting rule is inside the Task, untestable."
    correct: true
    why: "Move it into a plain function or display model and test 999, 1000 and 1500."
  - text: "Errors from data(from:) and decode are silently dropped, with no error state."
    correct: true
    why: "The Task's thrown error goes nowhere. A model with a failed status would make that visible and testable."
  - text: "A Task can't be started in viewDidLoad."
    correct: false
    why: "It can. The problem is what's inside it, not where it starts."
rubric:
  - Finds the incomplete child containment.
  - Finds networking and decoding inside the controller.
  - Finds the untested formatting rule.
  - Finds the swallowed errors.
solution: |
  Four real problems. The fix follows the lesson: a `ProfileModel` (or the view model of the next lesson) that receives a `UserRepository`, owns `user` and a status, and reports changes; a pure `followersText(_:)` function or display struct with tests for the boundary; the controller embedding `StatsViewController` with `addChild`/`didMove(toParent:)`; and an error state the controller renders instead of a `Task` whose errors vanish.
````

````exercise
id: m32-l02-e5
type: solve
prompt: "Design wants the reading list split into two sections: \"To read\" and \"Finished\", each with a count in its title (\"To read (2)\"), and an empty section left out entirely. Write a `ReadingListSections` display struct in plain Swift: `init(books: [Book])`, a `sections` array where each section has a `title` and `rows` (titles sorted alphabetically). Print the sections for a list with two unread and one read book, and for a list where everything is read."
starter: |
  struct Book {
      let id: Int
      let title: String
      var isRead: Bool
  }

  struct ReadingListSections {
      // Write the nested Section type, the sections property and the initializer.
  }
rubric:
  - Plain Swift, no UIKit; the struct is all a data source would need for numberOfSections, titleForHeaderInSection and cells.
  - Section titles include the count.
  - Empty sections are omitted rather than shown with zero rows.
  - Rows within each section are sorted by title.
solution: |
  ```swift
  struct Book {
      let id: Int
      let title: String
      var isRead: Bool
  }

  struct ReadingListSections {
      struct Section {
          let title: String
          let rows: [String]
      }

      let sections: [Section]

      init(books: [Book]) {
          let toRead = books.filter { !$0.isRead }.map(\.title).sorted()
          let finished = books.filter(\.isRead).map(\.title).sorted()
          var sections: [Section] = []
          if !toRead.isEmpty {
              sections.append(Section(title: "To read (\(toRead.count))", rows: toRead))
          }
          if !finished.isEmpty {
              sections.append(Section(title: "Finished (\(finished.count))", rows: finished))
          }
          self.sections = sections
      }
  }

  func show(_ content: ReadingListSections) {
      for section in content.sections {
          print(section.title)
          for row in section.rows {
              print("  \(row)")
          }
      }
  }

  show(ReadingListSections(books: [
      Book(id: 1, title: "Kindred", isRead: true),
      Book(id: 2, title: "The Dispossessed", isRead: false),
      Book(id: 3, title: "Piranesi", isRead: false),
  ]))
  print("---")
  show(ReadingListSections(books: [
      Book(id: 1, title: "Kindred", isRead: true),
      Book(id: 4, title: "Station Eleven", isRead: true),
  ]))
  ```

  ```output
  To read (2)
    Piranesi
    The Dispossessed
  Finished (1)
    Kindred
  ---
  Finished (2)
    Kindred
    Station Eleven
  ```

  The data source would answer `numberOfSections` with `sections.count`, `titleForHeaderInSection` with `sections[section].title`, and cells from `sections[indexPath.section].rows[indexPath.row]`. Because the empty-section rule lives here, a test can check it without a table. In the app, rows would carry ids and subtitles as in the lesson's `Row`; strings keep this exercise short.
````

````exercise
id: m32-l02-e6
type: refactor
prompt: "Refactor this controller method so the decision-making is testable without UIKit. Say which new types you'd create, what moves into each, and what stays in the controller."
code: |
  @objc private func refreshTapped() {
      refreshButton.isEnabled = false
      Task {
          defer { refreshButton.isEnabled = true }
          do {
              let books = try await repository.books()
              let unread = books.filter { !$0.isRead }
              if unread.isEmpty {
                  emptyLabel.text = "All caught up"
                  emptyLabel.isHidden = false
                  tableView.isHidden = true
              } else {
                  self.books = unread.sorted { $0.title < $1.title }
                  emptyLabel.isHidden = true
                  tableView.isHidden = false
                  tableView.reloadData()
              }
          } catch {
              showAlert("Couldn't refresh")
          }
      }
  }
rubric:
  - Moves loading, filtering, sorting and the empty decision into a model (or view model) with a status that includes an empty case.
  - Keeps the "refreshing" flag in the model so a second tap can be ignored or disabled based on state.
  - Leaves only rendering (hiding views, reloading, enabling the button, presenting the alert) in the controller.
  - Describes a test with a fake repository for the empty, non-empty and failure cases.
solution: |
  Create a `ReadingListModel` (as in the lesson) with a status such as `idle`, `refreshing`, `loaded`, `empty`, `failed`, a `books` array with only unread books sorted by title, an `onChange` callback and an `onRefreshError` event. `refresh()` sets `refreshing`, calls the repository, filters and sorts (or calls a domain function that does), and sets `empty` or `loaded`. If it's already refreshing, it returns immediately.

  The controller keeps a `render()` that maps status to views: the button is disabled while `refreshing`, the empty label shows for `empty`, the table for `loaded`; and an alert for the error event. `refreshTapped` becomes `Task { await model.refresh() }`.

  Tests drive the model with a fake repository: all-read books produce `empty`, mixed books produce `loaded` with the right order, a throwing repository produces the error event and leaves the previous books in place, and two overlapping calls to `refresh()` hit the repository once.
````

## Summary

- Apple's MVC splits code into models (data and logic), views (drawing, touches) and controllers (mediation). It's a sound split.
- In UIKit the controller is a `UIViewController`, which already owns the view, its lifecycle and usually the table's data source and delegate, so new jobs collect there: the **Massive View Controller**.
- Three extractions keep MVC healthy: a **data source object** fed by a plain display struct (hold it strongly; the table's reference is weak), a **model controller** that owns state and repository calls and reports changes through closures, and **child view controllers** for self-contained regions.
- Containment order: `addChild`, add the view, `didMove(toParent: self)`; to remove, `willMove(toParent: nil)`, remove the view, `removeFromParent()`.
- After the extractions the controller only renders state and forwards events. The rendering decisions it still makes are what MVVM and MVP move out next.
