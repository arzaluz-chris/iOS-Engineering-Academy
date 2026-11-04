---
id: m37-l02
title: Services, repositories and dependency injection in SwiftUI
description: "Screens depend on protocols, a composition root in the App creates the real implementations, and they reach the screens through initializers or the environment. You write Sendable service protocols, choose between initializer and environment injection (including the case where a model needs something from the environment), pick environment defaults that fail loudly, build an AppDependencies value with live, preview and test variants, and drive previews and tests with fakes."
module: m37
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l01, m32-l05, m30-l06, m36-l03]
objectives:
  - Define small Sendable service and repository protocols in domain terms.
  - Inject dependencies into SwiftUI screens and their models through initializers.
  - Inject services through custom environment values and create a model that needs them in .task.
  - Choose environment defaults that make a missing injection obvious.
  - Build a composition root in the App with live, preview and test configurations.
terms:
  - term: Service
    definition: "A type that does one kind of work for the app behind a protocol: talking to a server, reading the clock, sending analytics. Views and models depend on the protocol; the composition root picks the implementation."
  - term: Repository
    definition: "A service that hands out domain data and hides where it comes from (network, cache, local store). View models depend on a repository, not on URLSession or SwiftData directly."
  - term: Composition root
    definition: "The one place, run at launch, that creates the concrete services and wires them together. In a SwiftUI app it's the App struct (or a type it creates)."
  - term: Unimplemented default
    definition: "An environment default that fails clearly when used (throws or reports \"not injected\"), so a missing .environment(...) call shows up in previews and tests instead of silently doing nothing."
mastery:
  - Write a Sendable protocol for a service, a live implementation and a fake.
  - Pass a repository to a screen and its model through initializers, keeping the model's init cheap.
  - Declare a service with @Entry and read it in a view, creating the screen's model in .task.
  - Write an unimplemented default and explain what a no-op default hides.
  - Build AppDependencies with live(), preview() and test() and use it from the App, a preview and a test.
resources: [swiftui-environmentvalues, swiftui-app, swiftui-previews, swift-sendable, swift-actor, swift-book-protocols]
cards:
  - id: m37-l02-c1
    front: What should a SwiftUI screen's model depend on?
    back: "Protocols in domain terms (a BookCatalog, a ReadingListRepository), never URLSession, a ModelContext or a .shared singleton directly. The composition root decides the implementation."
  - id: m37-l02-c2
    front: Initializer or environment injection?
    back: "Initializer when one screen or a short chain needs it: explicit and checked by the compiler. Environment for services used across many screens at different depths, set once near the root. A model can't read @Environment, so the view passes environment values to it."
  - id: m37-l02-c3
    front: How do you build a model that needs an environment value?
    back: "The view reads @Environment, and creates the model in .task (stored in @State as an optional) or passes the value to the model's method calls. The environment isn't available in the view's init."
  - id: m37-l02-c4
    front: Why prefer an unimplemented default for a service in the environment?
    back: "A no-op default (empty results, nothing tracked) hides a missing .environment(...) call: the screen just looks empty. A default that throws \"BookCatalog not injected\" makes the mistake visible in the first preview or test."
  - id: m37-l02-c5
    front: Where do live, preview and test dependencies come from?
    back: "One AppDependencies value with static factories: live() for the App, preview() with canned fakes, test() with quiet fakes that tests override per property. The App's init picks live() (or a UI-testing variant from launch arguments)."
---

## The idea in one sentence

**Screens and their models ask for protocols, the App decides what's behind them**, and every dependency reaches a screen by one of two roads: an initializer or the environment.

> [!note] About this lesson's code
> Services, repositories, fakes and the dependency container are plain Swift, compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. The `@main` App and the previews are shown as illustrative blocks because the checker compiles each block as `main.swift`. Quotes come from Apple's `EnvironmentValues` and `Entry()` pages, read in November 2026.

## Where you are

Module 32, lesson 5 covered dependency injection in general: initializer injection, a composition root, factories, an `AppEnvironment` with test values, and why singletons hurt. Module 30, lesson 6 built a repository over an HTTP client. Module 36, lesson 3 showed `@Entry` and injecting `@Observable` models with `.environment(_:)`. This lesson fits those pieces into a SwiftUI app: which road each dependency takes, what happens when a model needs something only the view can see, and how previews and tests get their fakes.

## Services and repositories as protocols

The bookshelf app in this module has three dependencies:

- a **catalog** that searches and pages through books on a server (lesson 4),
- a **reading list repository** that hands out the user's list and saves changes, hiding whether they come from the network or a local store (lesson 6),
- **analytics**.

Each is a small protocol in domain terms:

```swift
struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    var isRead = false
}

protocol BookCatalog: Sendable {
    func books(matching query: String) async throws -> [Book]
}

protocol ReadingListRepository: Sendable {
    func readingList() async throws -> [Book]
    func setRead(_ isRead: Bool, bookID: Int) async throws
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

// Fakes: in-memory, deterministic, inspectable.
struct FixedCatalog: BookCatalog {
    var books: [Book]

    func books(matching query: String) async throws -> [Book] {
        query.isEmpty ? books : books.filter { $0.title.lowercased().contains(query.lowercased()) }
    }
}

actor InMemoryReadingList: ReadingListRepository {
    private var books: [Book]

    init(_ books: [Book]) {
        self.books = books
    }

    func readingList() -> [Book] { books }

    func setRead(_ isRead: Bool, bookID: Int) {
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].isRead = isRead
        }
    }
}

actor RecordingAnalytics: Analytics {
    private(set) var events: [String] = []
    func track(_ event: String) { events.append(event) }
}

let catalog: any BookCatalog = FixedCatalog(books: [Book(id: 1, title: "Kindred"), Book(id: 2, title: "Piranesi")])
print(try await catalog.books(matching: "pir").map(\.title))

let list: any ReadingListRepository = InMemoryReadingList([Book(id: 2, title: "Piranesi")])
try await list.setRead(true, bookID: 2)
print(try await list.readingList().map { "\($0.title), read: \($0.isRead)" })
```

```output
["Piranesi"]
["Piranesi, read: true"]
```

The rules for these protocols:

- **Domain types in, domain types out.** `books(matching:)` returns `[Book]`, not `Data` or a DTO. Decoding, status codes and caching are the implementation's business (Module 30).
- **`Sendable`.** Models on the main actor call them, implementations may be actors, and they're stored in environment values, whose defaults must be `Sendable` (Module 36, lesson 3).
- **`async throws`.** Every real implementation can be slow and can fail; a fake that can't still conforms. In the actor fake, the synchronous `readingList()` satisfies the `async throws` requirement.
- **Small.** A screen that needs one method shouldn't depend on a protocol with twenty. Two protocols implemented by one live type are fine.

A repository is a service that hides *where* data lives. The reading list model calls `readingList()` and doesn't know whether the answer came from SwiftData, a cache or the server. Lesson 6 builds one that reads locally and syncs in the background; the models in lessons 3 and 4 don't change when it arrives.

## Road one: initializers

When a dependency is needed by one screen, or a short chain of them, pass it through initializers. The compiler checks every call site, and the screen's signature says what it needs:

```swift ios
import SwiftUI

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    var isRead = false
}

protocol ReadingListRepository: Sendable {
    func readingList() async throws -> [Book]
    func setRead(_ isRead: Bool, bookID: Int) async throws
}

@MainActor
@Observable
final class ReadingListModel {
    private(set) var books: [Book] = []
    @ObservationIgnored private let repository: any ReadingListRepository

    init(repository: any ReadingListRepository) {
        self.repository = repository                     // cheap: store, don't load
    }

    func load() async {
        books = (try? await repository.readingList()) ?? []
    }

    func toggleRead(_ book: Book) async {
        try? await repository.setRead(!book.isRead, bookID: book.id)
        await load()
    }
}

struct ReadingListScreen: View {
    @State private var model: ReadingListModel

    init(repository: any ReadingListRepository) {
        _model = State(initialValue: ReadingListModel(repository: repository))
    }

    var body: some View {
        List(model.books) { book in
            Button {
                Task { await model.toggleRead(book) }
            } label: {
                Label(book.title, systemImage: book.isRead ? "checkmark.circle.fill" : "circle")
            }
        }
        .task { await model.load() }
    }
}
```

The screen takes the repository and builds its own model. Two details keep that honest:

- **`ReadingListModel.init` only stores.** With the `@State` property wrapper, `State(initialValue:)` runs every time SwiftUI creates the view struct, and SwiftUI keeps only the first instance (Module 36, lesson 2). Storing a reference is free; loading happens once, in `.task`.
- **The model is `@MainActor`**, and so is the view. Its methods update `books` on the main actor; the repository may be an actor that does its work elsewhere.

The alternative is for the parent to create the model and pass it in (`ReadingListScreen(model:)`). Do that when the parent needs to keep the model across the screen's lifetime, as a navigation router might, or to share it with another screen.

## Road two: the environment

Services that many screens need at different depths, like the catalog or analytics, are tedious to pass through every initializer. Put them in the environment once, near the root:

```swift ios
import SwiftUI

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

protocol BookCatalog: Sendable {
    func books(matching query: String) async throws -> [Book]
}

struct ServiceNotInjected: Error, CustomStringConvertible {
    let name: String
    var description: String { "\(name) was not injected. Add .environment(...) above this view." }
}

struct UnimplementedBookCatalog: BookCatalog {
    func books(matching query: String) async throws -> [Book] {
        throw ServiceNotInjected(name: "BookCatalog")
    }
}

extension EnvironmentValues {
    @Entry var bookCatalog: any BookCatalog = UnimplementedBookCatalog()
}

@MainActor
@Observable
final class CatalogModel {
    private(set) var books: [Book] = []
    private(set) var errorMessage: String?
    @ObservationIgnored private let catalog: any BookCatalog

    init(catalog: any BookCatalog) {
        self.catalog = catalog
    }

    func load() async {
        do {
            books = try await catalog.books(matching: "")
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}

struct CatalogScreen: View {
    @Environment(\.bookCatalog) private var catalog
    @State private var model: CatalogModel?

    var body: some View {
        Group {
            if let model {
                List(model.books) { Text($0.title) }
                    .overlay {
                        if let message = model.errorMessage {
                            Text(message)
                        }
                    }
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let model = CatalogModel(catalog: catalog)
            self.model = model
            await model.load()
        }
    }
}
```

The interesting part is the model. **A model can't read `@Environment`**, and neither can the view's `init`: environment values are only available once SwiftUI has placed the view in the hierarchy, from `body` on. So the screen stores an optional model in `@State` and creates it in `.task`, which runs once per identity, after the environment is set. This is the same pattern Apple's `State` page recommends for deferring an expensive model ("you can defer the creation of the object using the `task` modifier, which is called only once when the view first appears").

There are two other ways out, each fine in its place:

- **Pass the value to each call**: `await model.load(using: catalog)`. The model then doesn't store the service at all. Good when only one or two methods need it.
- **Inject the whole model through the environment** with `.environment(model)` and read it with `@Environment(CatalogModel.self)` (Module 36, lesson 3). Good for shared models, like a session or a favorites store, that the root creates.

### Pick a default that fails loudly

Every `@Entry` needs a default. It's tempting to make it harmless: a catalog that returns `[]`, analytics that do nothing. The cost shows up the first time someone forgets the `.environment(\.bookCatalog, ...)` call above a sheet or in a preview: the screen is silently empty, and you go looking for a server bug.

An **unimplemented default** turns that into a clear message. It conforms to the protocol and throws (or reports) the moment it's used:

```swift
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
}

protocol BookCatalog: Sendable {
    func books(matching query: String) async throws -> [Book]
}

struct ServiceNotInjected: Error, CustomStringConvertible {
    let name: String
    var description: String { "\(name) was not injected. Add .environment(...) above this view." }
}

struct UnimplementedBookCatalog: BookCatalog {
    func books(matching query: String) async throws -> [Book] {
        throw ServiceNotInjected(name: "BookCatalog")
    }
}

struct EmptyBookCatalog: BookCatalog {
    func books(matching query: String) async throws -> [Book] { [] }
}

@MainActor
final class CatalogModel {
    private(set) var books: [Book] = []
    private(set) var errorMessage: String?
    private let catalog: any BookCatalog

    init(catalog: any BookCatalog) {
        self.catalog = catalog
    }

    func load() async {
        do {
            books = try await catalog.books(matching: "")
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}

// Someone forgot to inject the catalog. With each kind of default:
for fallback in [EmptyBookCatalog() as any BookCatalog, UnimplementedBookCatalog()] {
    let model = CatalogModel(catalog: fallback)
    await model.load()
    print("\(model.books.count) books, error: \(model.errorMessage ?? "none")")
}
```

```output
0 books, error: none
0 books, error: BookCatalog was not injected. Add .environment(...) above this view.
```

With the empty default, "forgot to inject" and "the server has no books" look identical. With the unimplemented one, the first preview says what's wrong. Use a no-op default only where doing nothing is genuinely correct, as for analytics in a preview.

## The composition root

All the live implementations are created in one place: the `App`. Collect them in a value so each configuration (the real app, previews, unit tests, UI tests) is one factory:

```swift ios
import SwiftUI

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

protocol BookCatalog: Sendable {
    func books(matching query: String) async throws -> [Book]
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

// Live implementations.
struct RemoteBookCatalog: BookCatalog {
    private struct BookDTO: Decodable {
        let id: Int
        let title: String
    }

    let session: URLSession
    let baseURL: URL

    func books(matching query: String) async throws -> [Book] {
        var components = URLComponents(url: baseURL.appending(path: "books"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([BookDTO].self, from: data).map { Book(id: $0.id, title: $0.title) }
    }
}

struct NoAnalytics: Analytics {
    func track(_ event: String) async {}
}

// Fakes for previews.
struct FixedCatalog: BookCatalog {
    var books: [Book]
    func books(matching query: String) async throws -> [Book] { books }
}

struct AppDependencies: Sendable {
    var catalog: any BookCatalog
    var analytics: any Analytics

    static func live() -> AppDependencies {
        AppDependencies(
            catalog: RemoteBookCatalog(session: .shared, baseURL: URL(string: "https://books.example.com/v1")!),
            analytics: NoAnalytics()   // swap in your analytics client
        )
    }

    static func preview() -> AppDependencies {
        AppDependencies(
            catalog: FixedCatalog(books: [Book(id: 1, title: "Kindred"), Book(id: 2, title: "Piranesi")]),
            analytics: NoAnalytics()
        )
    }
}

extension EnvironmentValues {
    @Entry var bookCatalog: any BookCatalog = FixedCatalog(books: [])
    @Entry var analytics: any Analytics = NoAnalytics()
}

extension View {
    /// Puts every app-wide service in the environment.
    func dependencies(_ dependencies: AppDependencies) -> some View {
        self
            .environment(\.bookCatalog, dependencies.catalog)
            .environment(\.analytics, dependencies.analytics)
    }
}

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            Text("Catalog")   // CatalogScreen() reads the catalog from the environment
        }
        .dependencies(dependencies)
    }
}
```

(The `@Entry` defaults here are fixed catalogs to keep the block short; in the app, use the unimplemented one from above.) The `App` itself is a few lines:

```swift illustrative
@main
struct BookshelfApp: App {
    private let dependencies: AppDependencies

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            dependencies = .uiTesting()     // canned data for UI tests (Module 33, lesson 5)
        } else {
            dependencies = .live()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
```

What this buys you:

- **One file names concrete types.** `RemoteBookCatalog`, `URLSession.shared` and the base URL appear in `live()` and nowhere else. Screens see protocols.
- **The `App`'s `init` runs once per launch**, so `live()` is called once. The services are values or actors that don't need `@State`; if one were an `@Observable` model the views watch, you'd own it with `@State` in the `App` instead.
- **`.dependencies(_:)`** sets every environment value in one call. Use it at the root, and also where the environment doesn't reach on its own, like a separate window, so no screen ends up with the defaults.
- **Initializer-injected dependencies come from the same value.** `RootView` can pass `dependencies.readingList` to `ReadingListScreen(repository:)`; the environment isn't the only road out of the root.

## Previews and tests with fakes

A preview is just another composition root. Give it the preview dependencies, or a fake set up for the state you want to look at:

```swift illustrative
#Preview("Catalog") {
    NavigationStack { CatalogScreen() }
        .dependencies(.preview())
}

#Preview("Catalog, server down") {
    NavigationStack { CatalogScreen() }
        .environment(\.bookCatalog, FailingCatalog(error: URLError(.notConnectedToInternet)))
}

#Preview("Reading list") {
    ReadingListScreen(repository: InMemoryReadingList([Book(id: 1, title: "Kindred")]))
}
```

Fakes that represent a *state* (failing, empty, slow, a thousand books) make previews into a gallery of every screen state, which is where you catch layout bugs in the error and empty states that rarely appear on a real device. Lesson 3 adds a catalog that never answers, for the loading state.

Tests build the same graph with quiet fakes and override only what they check. This is Module 32's `AppEnvironment.test()`, now holding the services a SwiftUI app injects:

```swift
struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    var isRead = false
}

protocol ReadingListRepository: Sendable {
    func readingList() async throws -> [Book]
    func setRead(_ isRead: Bool, bookID: Int) async throws
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

actor InMemoryReadingList: ReadingListRepository {
    private var books: [Book]
    init(_ books: [Book]) { self.books = books }

    func readingList() -> [Book] { books }

    func setRead(_ isRead: Bool, bookID: Int) {
        if let index = books.firstIndex(where: { $0.id == bookID }) {
            books[index].isRead = isRead
        }
    }
}

struct NoAnalytics: Analytics {
    func track(_ event: String) async {}
}

actor RecordingAnalytics: Analytics {
    private(set) var events: [String] = []
    func track(_ event: String) { events.append(event) }
}

struct AppDependencies: Sendable {
    var readingList: any ReadingListRepository
    var analytics: any Analytics

    static func test(books: [Book] = []) -> AppDependencies {
        AppDependencies(readingList: InMemoryReadingList(books), analytics: NoAnalytics())
    }
}

@MainActor
final class ReadingListModel {
    private(set) var books: [Book] = []
    private let repository: any ReadingListRepository
    private let analytics: any Analytics

    init(dependencies: AppDependencies) {
        repository = dependencies.readingList
        analytics = dependencies.analytics
    }

    var header: String { "\(books.filter(\.isRead).count) of \(books.count) read" }

    func load() async {
        books = (try? await repository.readingList()) ?? []
    }

    func toggleRead(_ book: Book) async {
        try? await repository.setRead(!book.isRead, bookID: book.id)
        await analytics.track(book.isRead ? "unread:\(book.id)" : "read:\(book.id)")
        await load()
    }
}

// A test that cares about analytics: override that one dependency.
let analytics = RecordingAnalytics()
var dependencies = AppDependencies.test(books: [Book(id: 1, title: "Kindred"), Book(id: 2, title: "Piranesi")])
dependencies.analytics = analytics

let model = ReadingListModel(dependencies: dependencies)
await model.load()
print(model.header)
await model.toggleRead(model.books[1])
print(model.header)
await model.toggleRead(model.books[1])
print(model.header, await analytics.events)
```

```output
0 of 2 read
1 of 2 read
0 of 2 read ["read:2", "unread:2"]
```

The model takes the whole `AppDependencies` and keeps only what it uses, as Module 32 recommended for feature entry points. Its stored properties still document its real dependencies, and a test changes one line to swap one of them.

## Sendable all the way down

`AppDependencies` crosses from the `App` into views and models, and its services are called from the main actor and from background tasks. Declaring it `Sendable` makes the compiler check every service in it. A class with mutable state that isn't protected is rejected. Swift 6.3:

```swift no-compile stored property 'analytics' of 'Sendable'-conforming struct 'AppDependencies' has non-Sendable type 'Analytics'
final class Analytics {
    var events: [String] = []

    func track(_ event: String) {
        events.append(event)
    }
}

struct AppDependencies: Sendable {
    var analytics: Analytics
}
```

The error points at the dependency, not at some distant call site. Fix the service, not the container: make it an actor (as `RecordingAnalytics` is), a `@MainActor` class if it's UI-bound, or a struct of `Sendable` values.

## Common mistakes

> [!error] Creating a service inside a view
> `let catalog = RemoteBookCatalog(session: URLSession(configuration: .default), ...)` as a view property creates a new session every time the struct is rebuilt, and no preview or test can replace it. Create services in the composition root and inject them.

> [!error] Reaching for .shared from a model
> `APIClient.shared.books()` inside a view model is a hidden dependency: the initializer says nothing about it and tests can't swap it (Module 32, lesson 5). Take a protocol in the initializer.

> [!error] A no-op default that hides a missing injection
> A catalog default that returns `[]` makes a forgotten `.environment(\.bookCatalog, …)` look like an empty server. Default to something that fails with a clear message.

> [!error] Reading the environment in init
> `init() { model = CatalogModel(catalog: catalog) }` with `@Environment(\.bookCatalog) var catalog` reads the property before SwiftUI has set it. Create the model in `.task`, or pass the value in from a parent's `body`.

> [!error] Loading in the model's initializer
> `init(repository:) { Task { await load() } }` starts a request every time the view struct is created, because `State(initialValue:)` builds a new model each time. Keep `init` to storing dependencies and load from `.task`.

## Exercises

````exercise
id: m37-l02-e1
type: prediction
prompt: "Two models are built from the same dependency container: one before a test overrides the clock, one after. What does it print?"
code: |
  protocol Clock: Sendable {
      func today() -> String
  }

  struct FixedClock: Clock {
      let day: String
      func today() -> String { day }
  }

  struct AppDependencies: Sendable {
      var clock: any Clock

      static func test() -> AppDependencies {
          AppDependencies(clock: FixedClock(day: "Monday"))
      }
  }

  @MainActor
  final class GreetingModel {
      private let clock: any Clock

      init(dependencies: AppDependencies) {
          clock = dependencies.clock
      }

      var greeting: String { "Happy \(clock.today())" }
  }

  var dependencies = AppDependencies.test()
  let first = GreetingModel(dependencies: dependencies)
  dependencies.clock = FixedClock(day: "Friday")
  let second = GreetingModel(dependencies: dependencies)
  print(first.greeting)
  print(second.greeting)
  print(AppDependencies.test().clock.today())
output: |
  Happy Monday
  Happy Friday
  Monday
hints:
  - "AppDependencies is a struct. What does the first model hold after it's created?"
  - "test() builds a new value each call."
solution: |
  ```output
  Happy Monday
  Happy Friday
  Monday
  ```

  The first model copied the clock out of the container in its initializer, so changing `dependencies.clock` afterward doesn't affect it. The second model was built after the change and got Friday. `AppDependencies.test()` returns a fresh value, untouched by the override, which is why overriding a property in one test can't leak into another.
````

````exercise
id: m37-l02-e2
type: comprehension
prompt: "An app has an image loader used by rows in five different screens, and a checkout screen that needs a payment service no other screen uses. How should each be injected?"
choices:
  - text: "The image loader through a custom environment value set at the root; the payment service through the checkout screen's initializer."
    correct: true
    why: "Widely used, deep in the tree: environment. Needed by one screen: initializer, so its signature says so."
  - text: "Both through the environment, so every screen can reach everything."
    correct: false
    why: "It works, but hides the checkout screen's real dependency and lets any screen reach the payment service."
  - text: "Both as .shared singletons, since there's only one of each."
    correct: false
    why: "Singletons can't be swapped for previews or tests."
  - text: "Both through initializers of every view between the root and their users."
    correct: false
    why: "Threading the image loader through five screens' initializers just to reach rows is the tedium the environment exists to avoid."
solution: |
  **Environment for the image loader, initializer for the payment service.** The loader is used by many leaf views at different depths, so passing it down every initializer would touch dozens of types that don't use it. The payment service is used by one screen: an initializer parameter makes that dependency visible, is checked by the compiler, and keeps every other screen from reaching it.
````

````exercise
id: m37-l02-e3
type: fill-in
prompt: "Complete the environment value for an image loader, its default, and the view that reads it."
code: |
  protocol ImageLoader: Sendable {
      func image(at url: URL) async throws -> Data
  }

  struct UnimplementedImageLoader: ImageLoader {
      func image(at url: URL) async throws -> Data {
          throw ServiceNotInjected(name: "ImageLoader")
      }
  }

  extension EnvironmentValues {
      [[1]] var imageLoader: any ImageLoader = [[2]]()
  }

  struct CoverView: View {
      let url: URL
      @Environment([[3]]) private var loader
      @State private var data: Data?

      var body: some View {
          Color.gray
              .[[4]](id: url) {
                  data = try? await loader.image(at: url)
              }
      }
  }
blanks:
  - id: "1"
    answers: ["@Entry"]
  - id: "2"
    answers: ["UnimplementedImageLoader"]
  - id: "3"
    answers: ["\\.imageLoader"]
  - id: "4"
    answers: ["task"]
solution: |
  ```swift ios
  import SwiftUI

  struct ServiceNotInjected: Error {
      let name: String
  }

  protocol ImageLoader: Sendable {
      func image(at url: URL) async throws -> Data
  }

  struct UnimplementedImageLoader: ImageLoader {
      func image(at url: URL) async throws -> Data {
          throw ServiceNotInjected(name: "ImageLoader")
      }
  }

  extension EnvironmentValues {
      @Entry var imageLoader: any ImageLoader = UnimplementedImageLoader()
  }

  struct CoverView: View {
      let url: URL
      @Environment(\.imageLoader) private var loader
      @State private var data: Data?

      var body: some View {
          Color.gray
              .task(id: url) {
                  data = try? await loader.image(at: url)
              }
      }
  }
  ```

  `@Entry` declares the value and generates its key. The default is the unimplemented loader, so a missing injection throws a named error instead of silently showing gray squares. The view reads it with the key path `\.imageLoader`, and `task(id: url)` loads once per URL and cancels if the row goes away or gets a different URL (Module 36, lesson 5).
````

````exercise
id: m37-l02-e4
type: find-errors
prompt: "Which of these are real problems in this screen?"
code: |
  import SwiftUI

  @MainActor
  @Observable
  final class ProfileModel {
      var name = ""
      private let api = APIClient.shared

      init() {
          Task { name = try await api.profile().name }
      }
  }

  struct ProfileScreen: View {
      @Environment(\.analytics) private var analytics
      @State private var model = ProfileModel()

      var body: some View {
          Text(model.name)
              .task { await analytics.track("profile_viewed") }
      }
  }
choices:
  - text: "The model reaches APIClient.shared, so previews and tests can't replace the API."
    correct: true
    why: "A hidden dependency. Take a protocol in the initializer."
  - text: "The initializer starts a request, and ProfileModel() runs every time the view struct is created."
    correct: true
    why: "@State's default is evaluated on every view init. Load from .task instead."
  - text: "Reading analytics from the environment inside .task is a problem: the environment isn't available there."
    correct: false
    why: ".task runs after the view is in the hierarchy; environment values are set by then."
  - text: "An @Observable model can't have an initializer."
    correct: false
    why: "It can; this one just does too much in it."
rubric:
  - Flags APIClient.shared as a hidden dependency.
  - Flags the request in init combined with @State's repeated default.
  - Rejects the environment-in-task and initializer claims.
solution: |
  Two real problems. **`APIClient.shared`** hides the dependency: `ProfileModel()` looks dependency-free, and nothing can substitute a fake. **The `Task` in `init`** starts a profile request each time SwiftUI rebuilds `ProfileScreen`, since `@State`'s default expression runs on every view initialization. The fix for both: `init(api: any ProfileService)` that only stores, and `func load() async` called from `.task`. Reading `analytics` in `.task` is fine; that's after the environment is set.
````

````exercise
id: m37-l02-e5
type: solve
prompt: |
  Write a fake and use it to check a model. Given the protocol and model in the starter, write `actor FakeWeather: WeatherService` that returns a stored temperature for each city in a dictionary, throws `WeatherError.unknownCity` for others, and records every city it was asked for in `requests`. Then run:

  ```swift
  let weather = FakeWeather(temperatures: ["Lima": 19, "Oslo": -3])
  let model = WeatherModel(service: weather)
  await model.load(city: "Lima")
  print(model.text)
  await model.load(city: "Oslo")
  print(model.text)
  await model.load(city: "Atlantis")
  print(model.text)
  print(await weather.requests)
  ```

  ```output
  Lima: 19°
  Oslo: -3°
  No weather for Atlantis
  ["Lima", "Oslo", "Atlantis"]
  ```
starter: |
  protocol WeatherService: Sendable {
      func temperature(in city: String) async throws -> Int
  }

  enum WeatherError: Error {
      case unknownCity
  }

  @MainActor
  final class WeatherModel {
      private(set) var text = ""
      private let service: any WeatherService

      init(service: any WeatherService) {
          self.service = service
      }

      func load(city: String) async {
          do {
              text = "\(city): \(try await service.temperature(in: city))°"
          } catch {
              text = "No weather for \(city)"
          }
      }
  }

  // actor FakeWeather: WeatherService { ... }
hints:
  - "The actor stores the dictionary and a requests array."
  - "Append to requests before looking the city up, so failed lookups are recorded too."
rubric:
  - FakeWeather is an actor conforming to WeatherService.
  - Records every request, including the failing one.
  - Throws WeatherError.unknownCity for missing cities.
  - Output matches exactly.
solution: |
  ```swift
  protocol WeatherService: Sendable {
      func temperature(in city: String) async throws -> Int
  }

  enum WeatherError: Error {
      case unknownCity
  }

  @MainActor
  final class WeatherModel {
      private(set) var text = ""
      private let service: any WeatherService

      init(service: any WeatherService) {
          self.service = service
      }

      func load(city: String) async {
          do {
              text = "\(city): \(try await service.temperature(in: city))°"
          } catch {
              text = "No weather for \(city)"
          }
      }
  }

  actor FakeWeather: WeatherService {
      private let temperatures: [String: Int]
      private(set) var requests: [String] = []

      init(temperatures: [String: Int]) {
          self.temperatures = temperatures
      }

      func temperature(in city: String) throws -> Int {
          requests.append(city)
          guard let value = temperatures[city] else {
              throw WeatherError.unknownCity
          }
          return value
      }
  }

  let weather = FakeWeather(temperatures: ["Lima": 19, "Oslo": -3])
  let model = WeatherModel(service: weather)
  await model.load(city: "Lima")
  print(model.text)
  await model.load(city: "Oslo")
  print(model.text)
  await model.load(city: "Atlantis")
  print(model.text)
  print(await weather.requests)
  ```

  ```output
  Lima: 19°
  Oslo: -3°
  No weather for Atlantis
  ["Lima", "Oslo", "Atlantis"]
  ```

  The fake is an actor because the model calls it from the main actor while the test reads `requests` afterward; the actor makes that `Sendable` without locks. It's both a stub (canned answers) and a spy (recorded requests), the combination Module 33, lesson 3 called common in practice. The same fake drives a preview: `WeatherScreen(model: WeatherModel(service: FakeWeather(temperatures: ["Lima": 19])))`.
````

````exercise
id: m37-l02-e6
type: design
prompt: "Design the dependency setup for a podcast app with: a feed service (server), a downloads manager that writes files and reports progress to several screens, a player that the mini player bar and the full player both control, and analytics. Say what each protocol or model is, how it reaches the screens that use it, what AppDependencies holds, and what the preview and test variants contain."
rubric:
  - Feed service as a Sendable protocol, injected into the screens or models that load feeds (initializer or environment, justified).
  - Downloads manager and player as shared @Observable models owned at the root and injected with .environment(_:), since several views observe them.
  - Analytics in the environment with a no-op default only if that is acceptable, or an unimplemented one.
  - AppDependencies with live(), preview() and test(); fakes for feed (fixed episodes, failing), player (no audio), downloads (instant).
  - Composition root in the App; UI tests select a variant through launch arguments.
solution: |
  A sound design:

  - **`FeedService`** (`Sendable` protocol): `episodes(for:)`, `search(_:)`. Live: an HTTP client from Module 30. Injected through the environment (`@Entry var feedService`, unimplemented default), because the library, search and show screens all use it.
  - **`DownloadsManager`** (`@MainActor @Observable` class) owning download state and progress. It wraps a `FileStore` protocol and a transfer protocol for testability. Owned in `@State` at the `App` (or root view) and injected with `.environment(downloads)`, because several screens observe its progress.
  - **`Player`** (`@MainActor @Observable`), wrapping an `AudioEngine` protocol (live: AVFoundation). Shared by the mini bar and the full player through `.environment(player)`.
  - **`Analytics`** (`Sendable` protocol) in the environment. A no-op default is acceptable here because nothing user-visible depends on it, but tests that care inject a recording fake.
  - **`AppDependencies`**: `feed`, `analytics`, `audioEngine`, `fileStore`. `live()` builds the real ones; `preview()` uses fixed episodes, an `InstantFileStore` and a silent engine; `test()` uses quiet fakes each test overrides. The `App`'s `init` picks `live()` or, with a `-ui-testing` launch argument, a variant with canned data. The two shared models are created from these dependencies at the root.
````

## Summary

- Models depend on small, `Sendable`, domain-level protocols: services for work, repositories for data whose source they hide.
- Initializers carry dependencies one screen needs; the environment carries services many screens need. Keep model initializers to storing dependencies and load from `.task`.
- Models can't read `@Environment`: create the model in `.task` from environment values, pass the values to calls, or inject the whole model with `.environment(_:)`.
- Prefer environment defaults that fail with a clear message over no-ops that hide a missing injection.
- The `App` is the composition root: one `AppDependencies` with `live()`, `preview()` and `test()` factories, one modifier that installs it, and fakes that model states for previews and tests.
