---
id: m32-l05
title: Dependency injection without a framework
description: "Wire the reading list's object graph by hand. You compare creating, looking up and receiving dependencies, use initializer injection everywhere, build the whole graph in one composition root, hand out factories for objects created later, try an environment-style container with live and test values, see how singletons and service locators break tests and crash at run time, and make shared dependencies safe to use from any isolation domain."
module: m32
order: 5
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l04]
objectives:
  - Inject dependencies through initializers and explain what default arguments and property injection give up.
  - Build an app's object graph in a single composition root and keep shared dependencies there.
  - Use factory closures or methods so objects created at run time get their dependencies without seeing the container.
  - Write an environment-style dependency struct with live and test values, and know when it beats passing dependencies one by one.
  - Explain why singletons and service locators make tests order-dependent and failures late, and replace them.
  - Make shared dependencies Sendable with actors, @MainActor classes, immutable structs and @Sendable closures.
terms:
  - term: Initializer injection
    definition: "Passing every dependency a type needs as a parameter of its initializer and storing it, usually as a let. The type can't exist without them, and its signature lists them."
  - term: Composition root
    definition: "The one place, near the app's entry point, where concrete types are created and connected into the object graph. Everything else receives its dependencies."
  - term: Factory
    definition: "A closure or method that creates an object on demand, such as a detail view model for a book id chosen at run time, supplying the dependencies the caller doesn't have or shouldn't know about."
  - term: Environment-style container
    definition: "A struct holding the app's shared dependencies as properties (a store, analytics, a clock), with a live value and test values, passed down so each feature takes what it needs."
  - term: Service locator
    definition: "A global registry that code asks for dependencies at run time (resolve(BookStore.self)). It hides what a type depends on and turns a missing registration into a crash instead of a compiler error."
mastery:
  - Rewrite a type that creates or looks up its dependencies to receive them in its initializer.
  - Write a composition root with factory methods for every screen, and a test version built from fakes.
  - Give a coordinator a factory closure instead of the whole container.
  - Explain from an example why a shared singleton makes one test's result depend on another.
  - Fix a "non-Sendable type" error in a dependency struct in three different ways and say what each costs.
resources: [swiftui-environmentvalues, swift-sendable, swift-actor, swift-mainactor, swift-book-initialization, swift-book-closures]
cards:
  - id: m32-l05-c1
    front: What is the composition root?
    back: "The single place near the app's entry point (scene delegate, App struct) that creates the concrete dependencies and wires the object graph. No other code creates infrastructure or looks it up."
  - id: m32-l05-c2
    front: Why give a coordinator a factory closure rather than the container?
    back: "The closure states exactly what it can create ((Int) -> BookDetailViewModel) and hides everything else. With the whole container, the coordinator can reach any dependency, and its real needs disappear from its signature."
  - id: m32-l05-c3
    front: What's wrong with a service locator?
    back: "Dependencies are hidden inside the type instead of in its initializer, and a missing registration is a run-time crash rather than a compile error. Tests must also remember to register and reset global state."
  - id: m32-l05-c4
    front: Why do singletons make tests order-dependent?
    back: "Every test shares the same instance. State left by one test (a cached book, a logged-in user) is still there in the next, so results depend on which tests ran before, and parallel tests interfere."
  - id: m32-l05-c5
    front: How do you make a shared dependency safe to put in a Sendable container?
    back: "Make it a Sendable value (immutable struct), an actor (serialized access, await from outside), a @MainActor class (main thread only) or a final class protecting its state with a lock or Mutex. Closures in the container must be @Sendable."
---

## The idea in one sentence

A type should **receive** what it depends on rather than create or look it up, and one place at the top of the app, the composition root, decides which concrete types everyone receives.

## Three ways to get a dependency

A view model that needs a book store can get one in three ways:

```swift illustrative
// 1. Create it.
let store = SwiftDataBookStore()

// 2. Look it up.
let store = BookStore.shared
let store = ServiceLocator.shared.resolve(BookStore.self)

// 3. Receive it.
init(store: any BookStore) { self.store = store }
```

Only the third makes the dependency **visible** (it's in the initializer's signature) and **replaceable** (a test passes a fake). The first ties the view model to SwiftData forever. The second hides the dependency inside the implementation; you find out it exists when a test touches the real database, or crashes because nothing was registered.

"Dependency injection" is just the third option, applied consistently. Lessons 1 to 4 did it everywhere without naming it. You don't need a framework for it: Swift's initializers, protocols and closures are enough for apps of any size. Frameworks exist (Swinject, Factory, swift-dependencies, Needle), and some teams like them; this lesson is about the plain version, which is what they automate.

## Initializer injection

Pass dependencies as initializer parameters and store them in `let`s:

```swift illustrative
@MainActor
final class BookDetailViewModel {
    private let bookID: Int
    private let store: any BookStore
    private let analytics: any Analytics
    private let now: @Sendable () -> Date

    init(bookID: Int, store: any BookStore, analytics: any Analytics, now: @escaping @Sendable () -> Date) {
        self.bookID = bookID
        self.store = store
        self.analytics = analytics
        self.now = now
    }
}
```

The type can't be created without its dependencies, and it can't swap them later by accident. If the parameter list grows past four or five, that's information too: the type probably does too much.

Two variations come up, each with a cost:

- **Default arguments**, such as `store: any BookStore = SwiftDataBookStore()`. Convenient at call sites, but a test that forgets the argument silently uses the real store, and the type is back to knowing the concrete class. Defaults are reasonable for simple values (`now: = { Date() }`) and risky for infrastructure.
- **Property injection**, a `var store: (any BookStore)!` set after creation. UIKit sometimes forces it (view controllers from storyboards before iOS 13's `instantiateViewController(identifier:creator:)`), but it allows a half-built object and a crash if someone forgets. Prefer initializers.

## The composition root

If every type receives its dependencies, something has to create them. That's the **composition root**: one place, run once at launch, that builds the shared infrastructure and wires the graph. In a UIKit app it lives in (or is created by) the scene delegate; in SwiftUI, the `App` struct. Module 25's coordinators and Module 30's networking stack get created here too.

```swift
import Foundation

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    var isRead: Bool
}

protocol BookStore: Sendable {
    func allBooks() async throws -> [Book]
    func save(_ book: Book) async throws
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

// MARK: Features

@MainActor
final class ReadingListViewModel {
    private let store: any BookStore
    private let analytics: any Analytics
    private(set) var rows: [String] = []

    init(store: any BookStore, analytics: any Analytics) {
        self.store = store
        self.analytics = analytics
    }

    func load() async {
        let books = (try? await store.allBooks()) ?? []
        rows = books.map { $0.title + ($0.isRead ? " (read)" : "") }
        await analytics.track("reading_list_viewed")
    }
}

@MainActor
final class BookDetailViewModel {
    let bookID: Int
    private let store: any BookStore
    private let analytics: any Analytics

    init(bookID: Int, store: any BookStore, analytics: any Analytics) {
        self.bookID = bookID
        self.store = store
        self.analytics = analytics
    }

    func markAsRead() async throws {
        guard var book = try await store.allBooks().first(where: { $0.id == bookID }) else { return }
        book.isRead = true
        try await store.save(book)
        await analytics.track("book_finished:\(bookID)")
    }
}

@MainActor
final class ReadingCoordinator {
    private let makeDetail: (Int) -> BookDetailViewModel
    private(set) var openDetails: [BookDetailViewModel] = []

    init(makeDetail: @escaping (Int) -> BookDetailViewModel) {
        self.makeDetail = makeDetail
    }

    func didSelectBook(id: Int) -> BookDetailViewModel {
        let detail = makeDetail(id)
        openDetails.append(detail)
        return detail
    }
}

// MARK: Composition root

@MainActor
final class AppComposition {
    // Shared for the app's lifetime.
    private let store: any BookStore
    private let analytics: any Analytics

    init(store: any BookStore, analytics: any Analytics) {
        self.store = store
        self.analytics = analytics
    }

    func makeReadingListViewModel() -> ReadingListViewModel {
        ReadingListViewModel(store: store, analytics: analytics)
    }

    func makeBookDetailViewModel(bookID: Int) -> BookDetailViewModel {
        BookDetailViewModel(bookID: bookID, store: store, analytics: analytics)
    }

    func makeReadingCoordinator() -> ReadingCoordinator {
        ReadingCoordinator(makeDetail: { [unowned self] id in
            self.makeBookDetailViewModel(bookID: id)
        })
    }
}

// MARK: Fakes, and a test that builds the graph from them

actor InMemoryBookStore: BookStore {
    private var books: [Book]

    init(_ books: [Book]) {
        self.books = books
    }

    func allBooks() -> [Book] { books }

    func save(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        }
    }
}

actor RecordingAnalytics: Analytics {
    private(set) var events: [String] = []
    func track(_ event: String) { events.append(event) }
}

let analytics = RecordingAnalytics()
let app = AppComposition(
    store: InMemoryBookStore([Book(id: 1, title: "Kindred", isRead: true), Book(id: 3, title: "Piranesi", isRead: false)]),
    analytics: analytics
)

let list = app.makeReadingListViewModel()
await list.load()
print("list: \(list.rows)")

let coordinator = app.makeReadingCoordinator()
let detail = coordinator.didSelectBook(id: 3)
try await detail.markAsRead()
print("opened details: \(coordinator.openDetails.map(\.bookID))")

await list.load()
print("list after reload: \(list.rows)")
print("events: \(await analytics.events)")
```

```output
list: ["Kindred (read)", "Piranesi"]
opened details: [3]
list after reload: ["Kindred (read)", "Piranesi (read)"]
events: ["reading_list_viewed", "book_finished:3", "reading_list_viewed"]
```

What the composition root gives you:

- **Shared instances are shared on purpose.** The detail screen's save shows up in the list after reload because both view models got the same `store` from the root. Nothing is shared by accident through a global.
- **One place to read the graph.** To know what the reading list depends on, read `makeReadingListViewModel()`. To swap SwiftData for a server, change the one line that creates the store.
- **Tests build the same graph from fakes.** The run above is a test of the wiring itself: a real coordinator, real view models, fake infrastructure. Every event the user caused reached analytics, in order.

In the app, the root is created once and kept alive by the scene delegate, the same way Module 25 kept the root coordinator:

```swift illustrative
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var composition: AppComposition?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let composition = AppComposition(
            store: SwiftDataBookStore(container: try! ModelContainer(for: BookRecord.self)),
            analytics: TelemetryAnalytics(apiKey: Secrets.analyticsKey)
        )
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(
            rootViewController: ReadingListViewController(viewModel: composition.makeReadingListViewModel())
        )
        window.makeKeyAndVisible()
        self.window = window
        self.composition = composition
    }
}
```

(`SwiftDataBookStore`, `TelemetryAnalytics` and `Secrets` are placeholders for the adapters from Modules 30 and 31.) This is the only file that names concrete infrastructure types.

## Factories for objects created later

Not everything can be built at launch. A detail view model needs a book id that only exists once the user taps. The coordinator creates it, but the coordinator shouldn't know where the store comes from.

The answer above is a **factory**: `ReadingCoordinator` receives `makeDetail: (Int) -> BookDetailViewModel`. It can create detail view models for any id, and that's all it can do. Compare the alternative, passing the whole `AppComposition` to the coordinator:

- The coordinator's initializer no longer says what it needs. It could create anything.
- A test has to build a full composition instead of passing `{ id in BookDetailViewModel(bookID: id, store: fake, analytics: fake) }`.

The closure captures `self` `unowned` because the composition outlives every coordinator it creates; `weak` with a `guard` works too if you're less sure about the lifetimes. A factory can also be a small protocol (`protocol BookDetailFactory { func makeDetail(id: Int) -> ... }`) when there are several related things to create.

## Environment-style containers

Passing four dependencies through every initializer gets tedious as an app grows. A common alternative is one struct holding all the shared dependencies, with a live value and test values:

```swift
import Foundation

protocol BookStore: Sendable {
    func titles() async throws -> [String]
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

struct AppEnvironment: Sendable {
    var bookStore: any BookStore
    var analytics: any Analytics
    var now: @Sendable () -> Date

    /// Everything fake and quiet; tests override what they care about.
    static func test(titles: [String] = []) -> AppEnvironment {
        AppEnvironment(
            bookStore: FixedBookStore(stored: titles),
            analytics: NoAnalytics(),
            now: { Date(timeIntervalSince1970: 0) }
        )
    }
}

struct FixedBookStore: BookStore {
    let stored: [String]
    func titles() async throws -> [String] { stored }
}

struct NoAnalytics: Analytics {
    func track(_ event: String) async {}
}

actor RecordingAnalytics: Analytics {
    private(set) var events: [String] = []
    func track(_ event: String) { events.append(event) }
}

@MainActor
final class ReadingListViewModel {
    private let bookStore: any BookStore
    private let analytics: any Analytics
    private let now: @Sendable () -> Date
    private(set) var summary = ""

    // Takes the environment, keeps only what it uses.
    init(environment: AppEnvironment) {
        bookStore = environment.bookStore
        analytics = environment.analytics
        now = environment.now
    }

    func load() async {
        let titles = (try? await bookStore.titles()) ?? []
        let day = Int(now().timeIntervalSince1970 / 86_400)
        summary = "\(titles.count) books, loaded on day \(day)"
        await analytics.track("list_loaded")
    }
}

// A test that cares about analytics and the date, nothing else.
let recorder = RecordingAnalytics()
var environment = AppEnvironment.test(titles: ["Kindred", "Piranesi"])
environment.analytics = recorder
environment.now = { Date(timeIntervalSince1970: 20_526 * 86_400) }

let viewModel = ReadingListViewModel(environment: environment)
await viewModel.load()
print(viewModel.summary)
print(await recorder.events)
```

```output
2 books, loaded on day 20526
["list_loaded"]
```

- **`static func test(...)`** gives a complete, harmless environment. Each test overrides only the properties it's about, so adding a new dependency to the app doesn't touch every test.
- **`var` properties** make overriding one line. The struct is a value, so overriding in one test can't leak into another.
- **The view model copies out what it uses** in its initializer. Its stored properties still document its real dependencies, even though the initializer takes the whole environment.

The trade-off: the initializer signature no longer lists what the type needs, and any feature can reach any dependency. A reasonable split is to pass the environment to **feature entry points** (a coordinator or a composition method per feature) and inject individual dependencies into the view models, use cases and repositories below them.

SwiftUI has this idea built in. `EnvironmentValues` holds values that flow down the view tree, and you can add your own keys:

```swift ios
import SwiftUI

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
}

protocol BookStore: Sendable {
    func allBooks() async throws -> [Book]
}

struct EmptyBookStore: BookStore {
    func allBooks() async throws -> [Book] { [] }
}

private struct BookStoreKey: EnvironmentKey {
    static let defaultValue: any BookStore = EmptyBookStore()
}

extension EnvironmentValues {
    var bookStore: any BookStore {
        get { self[BookStoreKey.self] }
        set { self[BookStoreKey.self] = newValue }
    }
}

struct ReadingListScreen: View {
    @Environment(\.bookStore) private var bookStore
    @State private var titles: [String] = []

    var body: some View {
        List(titles, id: \.self) { title in
            Text(title)
        }
        .task {
            titles = (try? await bookStore.allBooks())?.map(\.title) ?? []
        }
    }
}

struct RootView: View {
    let store: any BookStore

    var body: some View {
        NavigationStack {
            ReadingListScreen()
        }
        .environment(\.bookStore, store)
    }
}
```

The `App` struct creates the real store and passes it to `RootView`; every view below can read it with `@Environment(\.bookStore)`, and previews pass a fake with `.environment(\.bookStore, ...)`. The default value matters: a view that reads the key without anyone setting it gets `EmptyBookStore`, not a crash, which is safer than a service locator but can also hide a missing `.environment(...)` call. SwiftUI and its environment are covered from Module 34.

## Singletons and service locators

Both are ways of **looking up** dependencies globally. They're tempting because they need no wiring. Here's what they cost.

Swift 6 already objects to the classic singleton, a shared instance of a class with mutable state:

```swift no-compile static property 'shared' is not concurrency-safe because non-'Sendable' type 'BookCache' may have shared mutable state
final class BookCache {
    static let shared = BookCache()
    var titles: [String] = []
}
```

Swift 6.3 reports: `error: static property 'shared' is not concurrency-safe because non-'Sendable' type 'BookCache' may have shared mutable state`. Any thread can reach `BookCache.shared` and mutate `titles`. Marking the class `@MainActor` makes it compile, and makes the concurrency problem go away. The testing problem stays:

```swift
@MainActor
final class BookCache {
    static let shared = BookCache()
    private(set) var titles: [String] = []

    func add(_ title: String) {
        titles.append(title)
    }
}

@MainActor
final class AddBookViewModel {
    func add(_ title: String) {
        BookCache.shared.add(title)
    }
}

@MainActor
final class ReadingListViewModel {
    var count: Int { BookCache.shared.titles.count }
}

// Two tests, run one after the other in the same process.
@MainActor
func testAddingABookShowsItInTheList() -> Bool {
    AddBookViewModel().add("Kindred")
    return ReadingListViewModel().count == 1
}

@MainActor
func testNewListIsEmpty() -> Bool {
    ReadingListViewModel().count == 0
}

print("adding a book shows it:", testAddingABookShowsItInTheList())
print("a new list is empty:", testNewListIsEmpty())
```

```output
adding a book shows it: true
a new list is empty: false
```

Each test is correct on its own. Run the second one first and both pass; run them in this order and the second fails, because the first left a book in the shared cache. With Swift Testing's parallel execution the outcome changes from run to run. Teams add `reset()` methods to singletons to cope, and then every test has to remember to call them. With injection, each test creates its own cache and the problem doesn't exist.

A **service locator** is a registry of dependencies that types query at run time. It looks like injection, but the dependencies are hidden inside the type, and a missing one is discovered late:

```swift runtime-error Fatal error: No registration for
protocol BookStore: Sendable {
    func titles() async -> [String]
}

protocol Analytics: Sendable {
    func track(_ event: String) async
}

actor InMemoryBookStore: BookStore {
    func titles() -> [String] { ["Kindred"] }
}

@MainActor
final class ServiceLocator {
    static let shared = ServiceLocator()
    private var factories: [ObjectIdentifier: () -> Any] = [:]

    func register<Service>(_ type: Service.Type, factory: @escaping () -> Service) {
        factories[ObjectIdentifier(type)] = factory
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let service = factories[ObjectIdentifier(type)]?() as? Service else {
            fatalError("No registration for \(type)")
        }
        return service
    }
}

@MainActor
final class ReadingListViewModel {
    private let store: any BookStore = ServiceLocator.shared.resolve()
    private let analytics: any Analytics = ServiceLocator.shared.resolve()
}

ServiceLocator.shared.register((any BookStore).self) { InMemoryBookStore() }
print("registered the store")
let viewModel = ReadingListViewModel()
print("created the view model")
```

```output
registered the store
```

The program stops with `Fatal error: No registration for Analytics` when the view model is created. Nothing in `ReadingListViewModel`'s interface says it needs analytics; you learn it from a crash, at run time, possibly in a code path only one screen reaches. With initializer injection the same mistake is a compile error: `missing argument for parameter 'analytics' in call`.

> [!note] When a shared instance is fine
> Apple's frameworks have plenty of `shared` and `default` instances (`URLSession.shared`, `FileManager.default`, `NotificationCenter.default`). Using them isn't the problem; **reaching for them from deep inside your types** is. Read them once in the composition root and inject them like anything else.

## Sendable and shared dependencies

The composition root hands the same store to view models on the main actor, to background tasks and to actors. Everything that's shared that way has to be `Sendable`, and Swift 6 checks it. A dependency struct is a common place to hit this:

```swift no-compile stored property 'thumbnails' of 'Sendable'-conforming struct 'AppEnvironment' has non-Sendable type 'ThumbnailCache'
final class ThumbnailCache {
    var images: [Int: [UInt8]] = [:]
}

struct AppEnvironment: Sendable {
    let thumbnails: ThumbnailCache
}
```

Swift 6.3 reports: `error: stored property 'thumbnails' of 'Sendable'-conforming struct 'AppEnvironment' has non-Sendable type 'ThumbnailCache'`. A closure property without `@Sendable` fails the same way (`has non-Sendable type '() -> Date'`), which is why every clock in this module is `@Sendable () -> Date`.

The fixes, and what each costs (Module 29 has the details):

| Make the dependency... | Cost |
| --- | --- |
| An **immutable struct** (configuration, a base URL, feature flags) | None, if it really never changes. |
| An **actor** (stores, caches, clients with state) | Every call from outside is `await`. Usually fine for I/O-bound dependencies. |
| A **`@MainActor` class** (things the UI reads synchronously) | Non-main code must `await`, and work runs on the main thread. |
| A **final class with a lock** (`Mutex` from iOS 18, or `NSLock` with `@unchecked Sendable`) | Synchronous access from anywhere; you're responsible for the locking being right. |

And declare the protocols `Sendable` (`protocol BookStore: Sendable`), so `any BookStore` is `Sendable` no matter which conforming type the root picks. Every repository and store in this module does that.

```swift
actor ThumbnailCache {
    private var images: [Int: [UInt8]] = [:]

    func image(for id: Int) -> [UInt8]? { images[id] }
    func store(_ bytes: [UInt8], for id: Int) { images[id] = bytes }
}

struct AppEnvironment: Sendable {
    let thumbnails: ThumbnailCache
}

let environment = AppEnvironment(thumbnails: ThumbnailCache())

// A background task and the main actor share the same cache.
let task = Task.detached {
    await environment.thumbnails.store([0xFF, 0xD8], for: 42)
}
await task.value
print(await environment.thumbnails.image(for: 42)?.count ?? 0)
```

```output
2
```

## Common mistakes

> [!error] Creating infrastructure inside a feature
> `private let store = SwiftDataBookStore()` in a view model. Tests touch the real database, previews need a real container. Receive it.

> [!error] Default arguments for infrastructure
> `init(store: any BookStore = SwiftDataBookStore())`. A test that forgets the argument quietly uses the real store. Keep defaults for simple values like a clock, if at all.

> [!error] Passing the container everywhere
> Every view model takes `AppComposition` or `AppEnvironment` and pulls what it likes. The signatures stop saying anything. Pass the container to feature entry points, and individual dependencies below them.

> [!error] A composition root that isn't kept alive
> Created in a local variable in `scene(_:willConnectTo:options:)`, its `unowned` factory closures crash later. Store it in a property, as with the root coordinator in Module 25.

> [!error] nonisolated(unsafe) to silence a singleton
> `nonisolated(unsafe) static let shared = BookCache()` compiles, and the data race is still there. Make it an actor or `@MainActor`, or better, stop making it global.

## Exercises

````exercise
id: m32-l05-e1
type: comprehension
prompt: "Where should the line `let store = SwiftDataBookStore(container: container)` appear in a well-structured app?"
choices:
  - text: "Only in the composition root, created at launch from the scene delegate or App struct."
    correct: true
    why: "The root is the one place that names concrete infrastructure; everyone else receives the store."
  - text: "In each view model that needs books, so it has its own store."
    correct: false
    why: "Then features know about SwiftData, can't be tested with fakes, and each holds a separate store."
  - text: "In a static shared property on SwiftDataBookStore, so anything can reach it."
    correct: false
    why: "That's a singleton: hidden dependency, shared state between tests."
  - text: "In the BookStore protocol's extension, as a default."
    correct: false
    why: "That puts the concrete type next to the abstraction and couples them."
solution: |
  Concrete infrastructure is created once, in the composition root, and passed down through initializers and factories. That keeps the knowledge of "we use SwiftData" in one file, lets tests build the same graph with fakes, and makes sharing deliberate: everything that receives the same store sees the same data.
````

````exercise
id: m32-l05-e2
type: prediction
prompt: "A composition root with one shared dependency and one created per call. What does the program print?"
code: |
  @MainActor
  final class Counter {
      private(set) var value = 0
      func increment() { value += 1 }
  }

  @MainActor
  final class ViewModel {
      let shared: Counter
      let own: Counter
      init(shared: Counter, own: Counter) {
          self.shared = shared
          self.own = own
      }
      func tap() {
          shared.increment()
          own.increment()
      }
  }

  @MainActor
  final class Composition {
      private let sharedCounter = Counter()
      private(set) var made = 0

      func makeViewModel() -> ViewModel {
          made += 1
          return ViewModel(shared: sharedCounter, own: Counter())
      }
  }

  let root = Composition()
  let first = root.makeViewModel()
  let second = root.makeViewModel()
  first.tap()
  first.tap()
  second.tap()
  print(first.shared.value, first.own.value)
  print(second.shared.value, second.own.value)
  print(first.shared === second.shared, first.own === second.own)
  print("made: \(root.made)")
output: |
  3 2
  3 1
  true false
  made: 2
solution: |
  The root keeps one `sharedCounter` and passes it to every view model; each call also creates a fresh `own` counter.

  - Three taps in total reach the shared counter: 3 for both view models.
  - `first.own` was incremented twice, `second.own` once.
  - The shared counters are the same object (`===` is `true`); the own counters are different.

  ```output
  3 2
  3 1
  true false
  made: 2
  ```

  That's the decision a composition root makes explicitly for each dependency: one instance for the app's lifetime, or a new one per screen. With singletons it's always "one", and you can't choose per test.
````

````exercise
id: m32-l05-e3
type: solve
prompt: "Remove a singleton. `SettingsViewModel` reads and writes `Preferences.shared`, so its tests leak into each other. Introduce a `PreferencesStore` protocol (Sendable, async get and set of a `showsFinishedBooks` Bool), an actor `InMemoryPreferencesStore`, and inject it into the view model. Then run two independent \"tests\": one toggles the setting and expects `true`, the other expects a fresh view model to show `false`. Run them in that order and print both results."
starter: |
  @MainActor
  final class Preferences {
      static let shared = Preferences()
      var showsFinishedBooks = false
  }

  @MainActor
  final class SettingsViewModel {
      private(set) var showsFinishedBooks = false

      func load() {
          showsFinishedBooks = Preferences.shared.showsFinishedBooks
      }

      func toggle() {
          Preferences.shared.showsFinishedBooks.toggle()
          load()
      }
  }
rubric:
  - The view model receives a PreferencesStore in its initializer and never touches a global.
  - The protocol is Sendable and the in-memory store is an actor.
  - Each test creates its own store, so the order doesn't change the results.
  - Both tests print true.
solution: |
  ```swift
  protocol PreferencesStore: Sendable {
      func showsFinishedBooks() async -> Bool
      func setShowsFinishedBooks(_ value: Bool) async
  }

  actor InMemoryPreferencesStore: PreferencesStore {
      private var value = false
      func showsFinishedBooks() -> Bool { value }
      func setShowsFinishedBooks(_ value: Bool) { self.value = value }
  }

  @MainActor
  final class SettingsViewModel {
      private let store: any PreferencesStore
      private(set) var showsFinishedBooks = false

      init(store: any PreferencesStore) {
          self.store = store
      }

      func load() async {
          showsFinishedBooks = await store.showsFinishedBooks()
      }

      func toggle() async {
          await store.setShowsFinishedBooks(!showsFinishedBooks)
          await load()
      }
  }

  @MainActor
  func testToggleTurnsSettingOn() async -> Bool {
      let viewModel = SettingsViewModel(store: InMemoryPreferencesStore())
      await viewModel.load()
      await viewModel.toggle()
      return viewModel.showsFinishedBooks == true
  }

  @MainActor
  func testFreshSettingIsOff() async -> Bool {
      let viewModel = SettingsViewModel(store: InMemoryPreferencesStore())
      await viewModel.load()
      return viewModel.showsFinishedBooks == false
  }

  print("toggle turns it on:", await testToggleTurnsSettingOn())
  print("fresh setting is off:", await testFreshSettingIsOff())
  ```

  ```output
  toggle turns it on: true
  fresh setting is off: true
  ```

  Each test builds its own `InMemoryPreferencesStore`, so the first test's toggle can't affect the second, in any order or in parallel. The app's composition root passes a `UserDefaults`-backed store (Module 31's typed settings, adapted to the protocol). Making the protocol async lets either an actor or a lock-based store implement it.
````

````exercise
id: m32-l05-e4
type: find-errors
prompt: "A pull request adds a dependency container. Which review comments are real problems?"
code: |
  struct Dependencies: Sendable {
      var bookStore: any BookStore
      var imageCache: ImageCache          // final class with a var dictionary, no lock
      var now: () -> Date
      static var current = Dependencies.live
  }

  @MainActor
  final class ReadingListViewModel {
      private let store = Dependencies.current.bookStore
      func load() async { /* ... */ }
  }

  @MainActor
  final class BookDetailViewModel {
      init(dependencies: Dependencies, bookID: Int) { /* uses only bookStore */ }
  }
choices:
  - text: "imageCache is a non-Sendable class in a Sendable struct; it won't compile in Swift 6."
    correct: true
    why: "Make it an actor, @MainActor, or lock-protected and Sendable."
  - text: "now is a non-@Sendable closure in a Sendable struct; it won't compile either."
    correct: true
    why: "Declare it @Sendable () -> Date."
  - text: "static var current is global mutable state, and the view model reads it like a service locator."
    correct: true
    why: "Swift 6 also rejects the static var as unsafe. Pass the dependencies in through init instead."
  - text: "BookDetailViewModel takes the whole container though it only needs the store."
    correct: true
    why: "Inject the store; keep the container for feature entry points."
  - text: "Structs can't hold existential types like any BookStore."
    correct: false
    why: "They can; any BookStore is Sendable as long as BookStore inherits from Sendable."
rubric:
  - Finds the non-Sendable class.
  - Finds the non-Sendable closure.
  - Finds the global mutable container read from inside a type.
  - Finds the over-broad dependency.
solution: |
  Four real problems. Two are compile errors in Swift 6 (the class and the closure in a `Sendable` struct; a `static var` is rejected too). The other two are design issues: `Dependencies.current` turns the container back into a global service locator, with the same test leaks as a singleton, and `BookDetailViewModel`'s initializer hides its one real dependency. The fix: make `ImageCache` an actor, write `var now: @Sendable () -> Date`, delete `current` and create the container in the composition root, and give `BookDetailViewModel` an `init(bookID:store:)`.
````

````exercise
id: m32-l05-e5
type: fill-in
prompt: "Complete the custom SwiftUI environment key so views can read a BookStore and previews can replace it."
code: |
  private struct BookStoreKey: [[1]] {
      static let [[2]]: any BookStore = EmptyBookStore()
  }

  extension [[3]] {
      var bookStore: any BookStore {
          get { self[BookStoreKey.self] }
          set { self[BookStoreKey.self] = newValue }
      }
  }

  struct ReadingListScreen: View {
      [[4]](\.bookStore) private var bookStore
      var body: some View { Text("…") }
  }

  // At the root:
  // ReadingListScreen().[[5]](\.bookStore, liveStore)
blanks:
  - id: "1"
    answers: ["EnvironmentKey"]
  - id: "2"
    answers: ["defaultValue"]
  - id: "3"
    answers: ["EnvironmentValues"]
  - id: "4"
    answers: ["@Environment"]
  - id: "5"
    answers: ["environment"]
solution: |
  A key type conforms to `EnvironmentKey` and supplies a `defaultValue`. An extension on `EnvironmentValues` adds a property that reads and writes through the key. Views read it with `@Environment(\.bookStore)`, and an ancestor sets it with `.environment(\.bookStore, liveStore)`. The default is used when no ancestor sets a value, so pick a harmless one (an empty store), not a live one.
````

````exercise
id: m32-l05-e6
type: design
prompt: "The reading list app gets a home screen widget that shows the next unread book, and an App Intent to mark a book as read from Shortcuts. Both run in a different process from the app. Plan the dependency setup: what's shared code, where each composition root lives, and how tests stay fast."
rubric:
  - Puts entities, use cases and the store protocol in shared code (a package or shared target) used by the app, widget and intent.
  - Gives each process its own composition root (the app's scene delegate or App, the widget's timeline provider, the intent's perform method) that builds only what it needs.
  - Shares data through an app group store adapter, not through in-memory singletons, since processes don't share memory.
  - Keeps tests on use cases and view models with fakes, independent of which process will run them.
solution: |
  A workable plan:

  - **Shared code:** `Book`, `ReadingGoal`, the `LoadReadingList` and `MarkBookAsRead` use cases and the `BookStore` protocol go in a Swift package (lesson 6) that all three targets depend on. The SwiftData or file-based store adapter goes there too, configured with the app group's container URL so all processes read the same data (Module 31).
  - **Three composition roots:** the app's (scene delegate), the widget's (its timeline provider creates the store and a `LoadReadingList`), and the intent's (its `perform()` creates the store and a `MarkBookAsRead`). Each is small and builds only what that process uses. There's no shared in-memory singleton to rely on: each process has its own memory, so a `shared` instance in the app is invisible to the widget anyway.
  - **Tests:** the use cases are tested once with an in-memory store and a fixed clock, which covers the widget's and intent's logic too. Each composition root gets a thin wiring test at most. After marking a book read from the intent, the app asks WidgetKit to reload timelines so the widget picks up the change.
````

## Summary

- Prefer **receiving** dependencies to creating or looking them up. Initializer injection makes them visible and replaceable; avoid default arguments and property injection for infrastructure.
- The **composition root** builds the graph once at launch, names the concrete types, and decides what's shared. Tests build the same graph from fakes.
- Give objects that create other objects at run time a **factory** (a closure or small protocol), not the container.
- An **environment-style struct** with `live` and `test` values reduces initializer noise; pass it to feature entry points and inject individual dependencies below. SwiftUI's `EnvironmentValues` is the same idea for views.
- **Singletons** leak state between tests; **service locators** hide dependencies and crash at run time when one is missing. Swift 6 rejects shared mutable singletons outright.
- Shared dependencies must be **Sendable**: immutable structs, actors, `@MainActor` classes or lock-protected classes, protocols that inherit `Sendable`, and `@Sendable` closures.
