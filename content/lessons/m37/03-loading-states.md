---
id: m37-l03
title: Loading, error, empty and refresh states
description: "Every screen that loads data has the same five situations: not started, loading, loaded, empty and failed, plus refreshing over existing content. You model them with a generic LoadState enum, tie loading to the view's lifetime with .task and .task(id:), treat cancellation as \"not finished\" instead of an error, keep content on screen during pull-to-refresh, add retry, and stop late responses and fast loads from making the screen flicker or go stale."
module: m37
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l02, m36-l05, m33-l04, m30-l04]
objectives:
  - Model a screen's loading lifecycle with a generic LoadState enum instead of loose booleans.
  - Start loads with .task and .task(id:) and handle their cancellation correctly.
  - Implement pull-to-refresh that keeps content visible and reports failures without wiping it.
  - Add retry and distinguish the empty state from loading and failure.
  - Prevent stale results and avoid spinner flicker for fast loads.
terms:
  - term: LoadState
    definition: "An enum with one case per loading situation (idle, loading, loaded with a value, failed with a message), generic over the loaded value. The view switches over it; tests compare it with ==."
  - term: Stale result
    definition: "A response for a request the screen no longer wants (an old filter, a previous item) that arrives late and overwrites newer data."
  - term: Flicker
    definition: "A state shown so briefly it reads as a glitch: a spinner for 50 ms, an empty-state message before the first load finishes, content replaced by a spinner during refresh."
  - term: refreshable(action:)
    definition: "A SwiftUI modifier (iOS 15) that installs an async refresh action; on a List it enables pull to refresh and keeps the indicator visible until the action returns."
mastery:
  - Write LoadState<Value> and a model whose load() moves through its cases.
  - Explain why cancellation should return a screen to idle instead of failed, and implement it.
  - Implement refresh() that keeps loaded content and exposes a separate refresh error.
  - Guard a load against late results with a cancellation check after each await.
  - Render the five situations in SwiftUI with ProgressView, ContentUnavailableView, a retry button and .refreshable.
resources: [swiftui-managing-ui-state, swift-task, swift-cancellationerror, swift-task-cancellation-handler, swift-book-enumerations, testing-async-code]
cards:
  - id: m37-l03-c1
    front: Why a LoadState enum instead of isLoading, error and items?
    back: "Three independent properties allow states the screen can't show (loading with an error, empty items before the first load). An enum (idle, loading, loaded(value), failed(message)) has exactly one case per situation and compares with == in tests."
  - id: m37-l03-c2
    front: What should a load do when it's cancelled?
    back: "Not show an error. Cancellation means the view went away or the input changed. Check Task.isCancelled in the catch (it covers CancellationError and URLError.cancelled) and put the state back to idle so the next .task starts over."
  - id: m37-l03-c3
    front: How does pull-to-refresh differ from the first load?
    back: "It keeps the loaded content on screen (the list's own indicator shows progress), and a failure doesn't replace content with an error screen: it sets a separate refreshError for a banner or alert. The refreshable action must await the refresh so the indicator stays until it's done."
  - id: m37-l03-c4
    front: How do you stop a late response from overwriting newer data?
    back: "After each await, check whether this load is still wanted (guard !Task.isCancelled with .task(id:), or compare a request token) before assigning state. SwiftUI cancels the old task, but a service that ignores cancellation still returns."
  - id: m37-l03-c5
    front: Two ways to avoid loading flicker?
    back: "Don't replace existing content with a spinner (show it only when there's nothing to show), and delay the spinner a few hundred milliseconds so fast loads never show it. Also never show the empty state before the first load has finished."
---

## The idea in one sentence

**A screen that loads data is a small state machine**: give each situation a case, move between them in one place, and the view only has to draw the current case.

> [!note] About this lesson's code
> The load states, models and their tests are plain Swift with Observation, compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Quotes come from Apple's pages for `task(id:name:priority:file:line:_:)` and `refreshable(action:)`, read in November 2026.

## Five situations, one enum

Any screen that loads something can be:

1. **Idle**: nothing requested yet.
2. **Loading**, with nothing to show.
3. **Loaded**, with content.
4. **Loaded but empty**: the request worked and there's nothing.
5. **Failed**, with nothing to show.

And on top of loaded content, **refreshing**, which may fail without taking the content away.

The tempting model is a few independent properties:

```swift illustrative
var isLoading = false
var errorMessage: String?
var books: [Book] = []
```

Those allow eight combinations, and the screen has meaning for about four. What does "loading with an error and three books" look like? And `books == []` means both "not loaded yet" and "loaded, nothing there", so the screen flashes "Your list is empty" before the first response. A generic enum says exactly what's possible:

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }
}

extension LoadState: Equatable where Value: Equatable {}
extension LoadState: Sendable where Value: Sendable {}

let states: [LoadState<[String]>] = [.idle, .loading, .loaded([]), .loaded(["Kindred"]), .failed(message: "Offline")]
for state in states {
    let screen: String
    switch state {
    case .idle, .loading:
        screen = "spinner"
    case .loaded(let titles) where titles.isEmpty:
        screen = "empty message"
    case .loaded(let titles):
        screen = "list of \(titles.count)"
    case .failed(let message):
        screen = "error: \(message), Retry button"
    }
    print(screen)
}
print(LoadState.loaded(["Kindred"]) == .loaded(["Kindred"]), states[3].value ?? [])
```

```output
spinner
spinner
empty message
list of 1
error: Offline, Retry button
true ["Kindred"]
```

- **Generic over `Value`**, so the same type serves a list (`LoadState<[Book]>`), a detail (`LoadState<Book>`) or a profile.
- **Empty isn't a separate case.** It's `.loaded` with an empty collection, decided in the `switch` with a `where` clause. A separate `.empty` case would have to be kept in sync with the value; this can't disagree.
- **Conditional conformances** make `LoadState` `Equatable` and `Sendable` exactly when its value is, so tests can write `#expect(model.state == .loaded([...]))`.
- **`value`** reads the content when there is some, handy in computed properties like a header.

The `switch` is what the SwiftUI view will do. Every case is handled, and the compiler tells you when a new case appears.

## A model that moves through the states

The model owns the state and three inputs: the first load, a retry and a pull-to-refresh. Refresh is different: it starts from content and must keep it.

```swift
import Observation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }
}

extension LoadState: Equatable where Value: Equatable {}

protocol ReadingListRepository: Sendable {
    func titles() async throws -> [String]
}

struct OfflineError: Error {}

/// Answers each call with the next scripted result.
actor ScriptedRepository: ReadingListRepository {
    private var results: [Result<[String], OfflineError>]

    init(_ results: [Result<[String], OfflineError>]) {
        self.results = results
    }

    func titles() throws -> [String] {
        try results.removeFirst().get()
    }
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class ReadingListModel {
    private(set) var state = LoadState<[String]>.idle {
        didSet { history.append(Self.describe(state)) }
    }
    private(set) var refreshError: String?
    @ObservationIgnored private(set) var history: [String] = []
    @ObservationIgnored private let repository: any ReadingListRepository

    init(repository: any ReadingListRepository) {
        self.repository = repository
    }

    /// First load and Retry. Shows the spinner only when there's nothing on screen.
    func load() async {
        if state.value == nil {
            state = .loading
        }
        do {
            state = .loaded(try await repository.titles())
            refreshError = nil
        } catch {
            if state.value == nil {
                state = .failed(message: "Couldn't load your reading list.")
            }
        }
    }

    /// Pull to refresh. Keeps content; a failure goes to refreshError.
    func refresh() async {
        do {
            state = .loaded(try await repository.titles())
            refreshError = nil
        } catch {
            refreshError = "Couldn't refresh. Showing saved results."
        }
    }

    private static func describe(_ state: LoadState<[String]>) -> String {
        switch state {
        case .idle: "idle"
        case .loading: "loading"
        case .loaded(let titles): "loaded(\(titles.count))"
        case .failed: "failed"
        }
    }
}

if #available(macOS 14, iOS 17, *) {
    let repository = ScriptedRepository([
        .failure(OfflineError()),          // first load
        .success(["Kindred", "Piranesi"]), // retry
        .failure(OfflineError()),          // pull to refresh, offline
        .success([]),                      // pull to refresh, list cleared on another device
    ])
    let model = ReadingListModel(repository: repository)

    await model.load()
    await model.load()          // Retry
    await model.refresh()
    print(model.state == .loaded(["Kindred", "Piranesi"]), model.refreshError ?? "no error")
    await model.refresh()
    print(model.history, model.refreshError ?? "no error")
}
```

```output
true Couldn't refresh. Showing saved results.
["loading", "failed", "loading", "loaded(2)", "loaded(0)"] no error
```

Read the history: the first load shows the spinner and fails; Retry shows the spinner again (there was no content) and succeeds. The failed refresh **doesn't appear in the history at all**: the state stayed `.loaded` with two titles, and only `refreshError` changed, so the list stays on screen with a banner. The last refresh succeeds with an empty list, which the view shows as the empty state.

The rules that came out of it:

- **Show the spinner only when there's nothing to show.** `load()` checks `state.value == nil` before setting `.loading`, so a retry after content (say, from an error banner's Retry) doesn't blank the screen.
- **A failure over content is a message, not a state.** `refreshError` is separate so the view can show it as a banner or alert, and clear it on the next success.
- **One place assigns `state`.** The `didSet` history is for this demonstration, but it's also a cheap way to test transitions (Module 33, lesson 5 recorded them the same way).

## Tying loads to the view's lifetime

In SwiftUI, the first load goes in `.task`. Apple: "SwiftUI can automatically cancel the task after the view disappears before the action completes." When the load depends on an input, use `.task(id:)`: "If the `id` value changes, SwiftUI cancels and restarts the task." (Module 36, lesson 5.)

That means **every load can be cancelled**, and cancellation shows up in your code as an error: `Task.sleep` and your own `checkCancellation()` throw `CancellationError`, and `URLSession` throws `URLError(.cancelled)`. A model that treats every error as a failure shows "Couldn't load" when the user simply navigated away, and worse, leaves `.failed` behind so the next appearance starts from an error screen.

The fix is to ask the task, not the error:

```swift
import Observation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)
}

extension LoadState: Equatable where Value: Equatable {}

protocol ReadingListRepository: Sendable {
    func titles() async throws -> [String]
}

/// A request that takes a very long time, unless cancelled.
struct SlowRepository: ReadingListRepository {
    func titles() async throws -> [String] {
        try await Task.sleep(for: .seconds(3600))
        return ["Kindred"]
    }
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class ReadingListModel {
    private(set) var state = LoadState<[String]>.idle
    @ObservationIgnored private let repository: any ReadingListRepository
    @ObservationIgnored private let handlesCancellation: Bool

    init(repository: any ReadingListRepository, handlesCancellation: Bool) {
        self.repository = repository
        self.handlesCancellation = handlesCancellation
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.titles())
        } catch {
            if handlesCancellation && Task.isCancelled {
                state = .idle            // not an error: nobody wants this result anymore
            } else {
                state = .failed(message: "Load failed. Try again.")
            }
        }
    }
}

if #available(macOS 14, iOS 17, *) {
    for handles in [false, true] {
        let model = ReadingListModel(repository: SlowRepository(), handlesCancellation: handles)
        let task = Task { await model.load() }   // what .task starts
        task.cancel()                            // the user leaves the screen
        await task.value
        print("handles cancellation: \(handles) -> \(model.state)")
    }
}
```

```output
handles cancellation: false -> failed(message: "Load failed. Try again.")
handles cancellation: true -> idle
```

`Task.isCancelled` is true inside the cancelled task whatever error the cancellation produced, so this one check covers `CancellationError`, `URLError(.cancelled)` and anything a library wraps them in. Setting `.idle` means the next `.task` (the view appears again) starts a clean load.

> [!note] When does .task run again?
> `.task` starts when the view appears and is cancelled when it disappears. A screen that disappears and comes back (another tab selected and then this one again, for example) runs it again. If you don't want a reload every time, guard it: `func loadIfNeeded() async { guard case .idle = state else { return }; await load() }`, and let pull-to-refresh handle freshness.

### Late answers: checking after each await

`.task(id: filter)` cancels the previous load when the filter changes. Cancellation is cooperative, though: if the repository doesn't check for it (a cache lookup, a library that ignores it, a request already past the point of no return), the old load still **returns**, possibly after the new one. If the model assigns whatever comes back, the screen shows the old filter's books under the new filter's title.

To see it deterministically, here's a repository that holds each request open until the test answers it, and ignores cancellation on purpose:

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)
}

protocol BookRepository: Sendable {
    func titles(filter: String) async throws -> [String]
}

/// Holds each request until the test answers it. Ignores cancellation, like a slow service might.
actor GatedRepository: BookRepository {
    private var pending: [String: CheckedContinuation<[String], any Error>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]

    func titles(filter: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            pending[filter] = continuation
            waiters.removeValue(forKey: filter)?.resume()
        }
    }

    func waitForRequest(_ filter: String) async {
        guard pending[filter] == nil else { return }
        await withCheckedContinuation { waiters[filter] = $0 }
    }

    func respond(_ filter: String, with titles: [String]) {
        pending.removeValue(forKey: filter)?.resume(returning: titles)
    }
}

@MainActor
final class FilteredListModel {
    private(set) var state = LoadState<[String]>.idle
    private let repository: any BookRepository
    private let checksAfterAwait: Bool

    init(repository: any BookRepository, checksAfterAwait: Bool) {
        self.repository = repository
        self.checksAfterAwait = checksAfterAwait
    }

    /// Called from .task(id: filter).
    func load(filter: String) async {
        state = .loading
        do {
            let titles = try await repository.titles(filter: filter)
            if checksAfterAwait {
                guard !Task.isCancelled else { return }   // a newer filter took over
            }
            state = .loaded(titles)
        } catch {
            if !Task.isCancelled {
                state = .failed(message: "Couldn't load.")
            }
        }
    }
}

for checks in [false, true] {
    let repository = GatedRepository()
    let model = FilteredListModel(repository: repository, checksAfterAwait: checks)

    // .task(id: "all") starts.
    let all = Task { await model.load(filter: "all") }
    await repository.waitForRequest("all")

    // The user picks "unread": SwiftUI cancels the old task and starts a new one.
    all.cancel()
    let unread = Task { await model.load(filter: "unread") }
    await repository.waitForRequest("unread")

    await repository.respond("unread", with: ["Piranesi"])
    await unread.value
    await repository.respond("all", with: ["Kindred", "Piranesi"])   // the old answer arrives late
    await all.value

    print("checks after await: \(checks) -> \(model.state)")
}
```

```output
checks after await: false -> loaded(["Kindred", "Piranesi"])
checks after await: true -> loaded(["Piranesi"])
```

Without the check, the screen says "Unread" and shows a book the user has read. With `guard !Task.isCancelled else { return }` after the `await`, the cancelled load drops its result. The rule is mechanical: **after every `await` in a load, before you assign state, check that the load is still wanted.**

`Task.isCancelled` works because `.task(id:)` cancels the old task. When two loads can race *without* a task being cancelled (a refresh and a filter change both calling the model directly), use a request token instead: increment a `loadGeneration` counter at the start of each load, capture it, and assign only if it's still the current one.

## The view

Here's the screen, with the five situations, Retry, pull to refresh and the refresh banner:

```swift ios
import SwiftUI

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }
}

protocol ReadingListRepository: Sendable {
    func titles() async throws -> [String]
}

@MainActor
@Observable
final class ReadingListModel {
    private(set) var state = LoadState<[String]>.idle
    private(set) var refreshError: String?
    @ObservationIgnored private let repository: any ReadingListRepository

    init(repository: any ReadingListRepository) {
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        if state.value == nil { state = .loading }
        do {
            let titles = try await repository.titles()
            guard !Task.isCancelled else { return }
            state = .loaded(titles)
            refreshError = nil
        } catch {
            if Task.isCancelled {
                if state.value == nil { state = .idle }
            } else if state.value == nil {
                state = .failed(message: "Couldn't load your reading list.")
            }
        }
    }

    func refresh() async {
        do {
            let titles = try await repository.titles()
            state = .loaded(titles)
            refreshError = nil
        } catch {
            if !Task.isCancelled {
                refreshError = "Couldn't refresh. Showing saved results."
            }
        }
    }

    func dismissRefreshError() {
        refreshError = nil
    }
}

struct ReadingListScreen: View {
    @State private var model: ReadingListModel

    init(repository: any ReadingListRepository) {
        _model = State(initialValue: ReadingListModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Reading List")
            .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            DelayedProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label(message, systemImage: "wifi.exclamationmark")
            } actions: {
                Button("Retry") {
                    Task { await model.load() }
                }
            }
        case .loaded(let titles):
            List(titles, id: \.self) { Text($0) }
                .overlay {
                    if titles.isEmpty {
                        ContentUnavailableView(
                            "Nothing to read",
                            systemImage: "books.vertical",
                            description: Text("Books you add appear here.")
                        )
                    }
                }
                .refreshable { await model.refresh() }
                .safeAreaInset(edge: .top) {
                    if let message = model.refreshError {
                        Button(message) { model.dismissRefreshError() }
                            .font(.footnote)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow.opacity(0.3))
                    }
                }
        }
    }
}

/// Shows a spinner only if loading takes longer than a moment.
struct DelayedProgressView: View {
    @State private var isVisible = false

    var body: some View {
        ProgressView()
            .opacity(isVisible ? 1 : 0)
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isVisible = true
            }
    }
}
```

What each piece is doing:

- **`.task { await model.loadIfNeeded() }`** starts the first load when the screen appears, and doesn't reload on every reappearance.
- **The `switch`** draws one case at a time. `.idle` and `.loading` share the spinner, so there's never an empty-state flash before the first response.
- **`ContentUnavailableView`** (iOS 17) is SwiftUI's standard empty and error presentation, with a label, a description and actions. The empty state stays inside the `List` (as an overlay), so pull to refresh still works when the list is empty.
- **`.refreshable { await model.refresh() }`** gives the list pull to refresh. Apple: "The indicator remains visible for the duration of the refresh, which runs asynchronously." That's why the action **awaits** the refresh: the indicator is your loading state for refreshes, and it disappears exactly when `refresh()` returns.
- **The refresh banner** sits above the list in `safeAreaInset`, so content stays visible and the message is dismissible.
- **`DelayedProgressView`** hides the spinner for the first 300 ms. Most cached or fast loads finish before then and never show it; slow ones show it. Its own `.task` is cancelled with it, so a load that finishes early leaves nothing behind.

> [!warning] Don't wrap the refresh in a Task
> `.refreshable { Task { await model.refresh() } }` returns immediately, so the indicator vanishes while the request is still running, and nothing stops the user from pulling again. Await the work directly in the action.

## Common mistakes

> [!error] Showing the empty state before the first load
> With `var books: [Book] = []` and `if books.isEmpty { Text("No books") }`, the empty message appears for a moment on every launch. Separate "not loaded" from "loaded, empty": `LoadState`'s `.idle` and `.loading` render a spinner.

> [!error] Treating cancellation as failure
> Leaving a screen mid-load shows "Couldn't load" and leaves `.failed` for the next visit. In the `catch`, check `Task.isCancelled` first and go back to `.idle`.

> [!error] Replacing content with a spinner on refresh or retry
> Setting `state = .loading` unconditionally blanks a list the user was reading. Only show the spinner when there's no content; use the refresh indicator or a small inline indicator otherwise.

> [!error] Assigning a result without checking it's still wanted
> A late response for an old filter overwrites the current one. After each `await`, `guard !Task.isCancelled` (or check a request token) before assigning.

> [!error] A refresh error that wipes the list
> `state = .failed(...)` on a refresh failure throws away data that's still useful. Keep `.loaded` and report the failure separately.

## Exercises

````exercise
id: m37-l03-e1
type: prediction
prompt: "A profile screen's model records its states. The repository is scripted: fail, succeed, fail, succeed. What does it print?"
code: |
  enum LoadState: Equatable {
      case idle, loading
      case loaded(String)
      case failed
  }

  struct Offline: Error {}

  actor Scripted {
      private var results: [Result<String, Offline>]
      init(_ results: [Result<String, Offline>]) { self.results = results }
      func next() throws -> String { try results.removeFirst().get() }
  }

  @MainActor
  final class ProfileModel {
      private(set) var log: [String] = []
      private(set) var refreshFailed = false
      private(set) var state = LoadState.idle {
          didSet { log.append("\(state)") }
      }
      let source: Scripted

      init(source: Scripted) { self.source = source }

      var hasContent: Bool {
          if case .loaded = state { true } else { false }
      }

      func load() async {
          if !hasContent { state = .loading }
          do {
              state = .loaded(try await source.next())
          } catch {
              if !hasContent { state = .failed }
          }
      }

      func refresh() async {
          do {
              state = .loaded(try await source.next())
              refreshFailed = false
          } catch {
              refreshFailed = true
          }
      }
  }

  let model = ProfileModel(source: Scripted([.failure(Offline()), .success("Ana"), .failure(Offline()), .success("Ana R.")]))
  await model.load()
  await model.load()
  await model.refresh()
  print(model.refreshFailed)
  await model.refresh()
  print(model.log.joined(separator: " > "))
  print(model.refreshFailed)
output: |
  true
  loading > failed > loading > loaded("Ana") > loaded("Ana R.")
  false
hints:
  - "load() only sets .loading when there's no content."
  - "A failed refresh doesn't assign state, so it doesn't add to the log."
solution: |
  ```output
  true
  loading > failed > loading > loaded("Ana") > loaded("Ana R.")
  false
  ```

  The first load sets `.loading`, fails and sets `.failed`. The second load (Retry) has no content, so it sets `.loading` again, then `.loaded("Ana")`. The first refresh fails: `state` isn't touched, so nothing is logged, and `refreshFailed` becomes `true`, which is the first line printed. The second refresh succeeds with "Ana R." and clears the flag. Enum cases with a `String` payload print the string quoted.
````

````exercise
id: m37-l03-e2
type: comprehension
prompt: "A list uses `.refreshable { Task { await model.refresh() } }`. What does the user see?"
choices:
  - text: "The refresh indicator disappears almost immediately, while the request is still running, and they can pull again to start a second refresh."
    correct: true
    why: "The action returns as soon as it creates the Task, and the indicator only lasts as long as the action."
  - text: "The indicator stays until the refresh finishes, exactly as with `await model.refresh()`."
    correct: false
    why: "The indicator follows the refreshable action, which no longer awaits the work."
  - text: "Nothing: refreshable doesn't accept closures that create tasks."
    correct: false
    why: "It compiles and runs; it just behaves badly."
  - text: "The refresh is cancelled as soon as the indicator hides."
    correct: false
    why: "An unstructured Task isn't tied to the refreshable action; it keeps running."
solution: |
  **The indicator disappears early.** Apple's documentation says the indicator "remains visible for the duration of the refresh", meaning the duration of the async action you pass. Wrapping the work in `Task { }` makes the action return right away, so the indicator vanishes while the request runs, and pulling again starts another refresh in parallel. Write `.refreshable { await model.refresh() }`.
````

````exercise
id: m37-l03-e3
type: find-errors
prompt: "Which of these are real problems in this model?"
code: |
  @MainActor
  @Observable
  final class OrdersModel {
      var isLoading = false
      var errorMessage: String?
      var orders: [Order] = []
      private let service: any OrderService

      init(service: any OrderService) { self.service = service }

      // Called from .task and from pull to refresh.
      func load() async {
          isLoading = true
          orders = []
          do {
              orders = try await service.orders()
          } catch {
              errorMessage = error.localizedDescription
          }
          isLoading = false
      }
  }
choices:
  - text: "Clearing orders at the start of load() blanks the list during every pull to refresh."
    correct: true
    why: "Refresh should keep content on screen."
  - text: "Leaving the screen mid-load shows the cancellation error as errorMessage."
    correct: true
    why: "The catch doesn't check Task.isCancelled."
  - text: "errorMessage is never cleared, so a successful retry can still show the old error next to the orders."
    correct: true
    why: "Independent properties drift: success doesn't reset the error."
  - text: "orders == [] can't distinguish \"not loaded yet\" from \"no orders\", so the empty state can flash first."
    correct: true
    why: "That's the case LoadState separates with .idle/.loading vs .loaded([])."
  - text: "An @Observable model can't have an async method."
    correct: false
    why: "It can; async methods on a @MainActor class are the normal shape."
rubric:
  - Flags clearing content on refresh.
  - Flags cancellation shown as an error.
  - Flags the stale errorMessage.
  - Flags the empty-vs-not-loaded ambiguity.
  - Rejects the async claim.
solution: |
  Four real problems, all fixed by the shape from this lesson. A `LoadState<[Order]>` removes the ambiguity between "not loaded" and "empty" and makes "orders plus an error" impossible to forget to reset. A separate `refresh()` keeps `.loaded` content and reports failures in `refreshError`. And the `catch` checks `Task.isCancelled` first, going back to `.idle` instead of storing a cancellation message. Async methods on an `@Observable` class are fine.
````

````exercise
id: m37-l03-e4
type: solve
prompt: |
  Add a request token so that only the latest load assigns its result. In the starter, `load(filter:)` can be called again before an earlier call returns, with no task cancellation involved. Add a `private var generation = 0`, increment it at the start of each load, capture it, and assign `titles` only if it's still the current generation after the await. Then run:

  ```swift
  let service = DelayedService()
  let model = ListModel(service: service)
  let first = Task { await model.load(filter: "slow") }
  let second = Task { await model.load(filter: "fast") }
  await second.value
  await service.release()
  await first.value
  print(model.titles)
  ```

  ```output
  ["fast result"]
  ```
starter: |
  /// Holds the "slow" request until release() is called.
  actor DelayedService {
      private var waiting: CheckedContinuation<Void, Never>?
      private var released = false

      func titles(filter: String) async -> [String] {
          if filter == "slow" && !released {
              await withCheckedContinuation { waiting = $0 }
          }
          return ["\(filter) result"]
      }

      func release() {
          released = true
          waiting?.resume()
          waiting = nil
      }
  }

  @MainActor
  final class ListModel {
      private(set) var titles: [String] = []
      private let service: DelayedService

      init(service: DelayedService) { self.service = service }

      func load(filter: String) async {
          titles = await service.titles(filter: filter)
      }
  }
hints:
  - "generation += 1, then let current = generation, before the await."
  - "After the await: guard current == generation else { return }."
  - "Both loads run on the main actor, so reading and writing generation needs no lock."
rubric:
  - Increments generation before the await and captures it.
  - Compares after the await before assigning.
  - Output matches exactly.
solution: |
  ```swift
  /// Holds the "slow" request until release() is called.
  actor DelayedService {
      private var waiting: CheckedContinuation<Void, Never>?
      private var released = false

      func titles(filter: String) async -> [String] {
          if filter == "slow" && !released {
              await withCheckedContinuation { waiting = $0 }
          }
          return ["\(filter) result"]
      }

      func release() {
          released = true
          waiting?.resume()
          waiting = nil
      }
  }

  @MainActor
  final class ListModel {
      private(set) var titles: [String] = []
      private let service: DelayedService
      private var generation = 0

      init(service: DelayedService) { self.service = service }

      func load(filter: String) async {
          generation += 1
          let current = generation
          let result = await service.titles(filter: filter)
          guard current == generation else { return }   // a newer load started
          titles = result
      }
  }

  let service = DelayedService()
  let model = ListModel(service: service)
  let first = Task { await model.load(filter: "slow") }
  let second = Task { await model.load(filter: "fast") }
  await second.value
  await service.release()
  await first.value
  print(model.titles)
  ```

  ```output
  ["fast result"]
  ```

  The "slow" load starts first and takes generation 1; the "fast" load takes generation 2 and assigns its result. When the slow request is finally released, its captured generation (1) no longer matches, so it returns without touching `titles`. Unlike `Task.isCancelled`, this works no matter who started the loads or whether anything was cancelled.

  The `released` flag in the fake covers the other ordering: if the slow request reached the service only after `release()`, it returns at once instead of waiting forever, and the generation check still discards it.
````

````exercise
id: m37-l03-e5
type: fill-in
prompt: "Complete the screen: load once when it appears, show pull to refresh, and offer Retry on failure."
code: |
  struct OrdersScreen: View {
      @State private var model: OrdersModel

      var body: some View {
          Group {
              switch model.state {
              case .idle, .loading:
                  ProgressView()
              case .failed(let message):
                  ContentUnavailableView {
                      Label(message, systemImage: "exclamationmark.triangle")
                  } actions: {
                      Button("Retry") {
                          [[1]] { await model.load() }
                      }
                  }
              case .loaded(let orders):
                  List(orders) { Text($0.title) }
                      .[[2]] { await model.refresh() }
              }
          }
          .[[3]] { await model.loadIfNeeded() }
      }
  }
blanks:
  - id: "1"
    answers: ["Task"]
  - id: "2"
    answers: ["refreshable"]
  - id: "3"
    answers: ["task"]
solution: |
  `Task { await model.load() }` because a button's action is synchronous and has to start async work. `.refreshable { await model.refresh() }` awaits the work directly so the indicator lasts as long as the refresh. `.task { await model.loadIfNeeded() }` ties the first load to the screen's lifetime and skips it when the screen reappears with content already loaded.

  ```swift ios
  import SwiftUI

  struct Order: Identifiable, Sendable {
      let id: Int
      let title: String
  }

  enum LoadState<Value> {
      case idle, loading
      case loaded(Value)
      case failed(message: String)
  }

  @MainActor
  @Observable
  final class OrdersModel {
      private(set) var state = LoadState<[Order]>.idle
      func load() async { state = .loaded([Order(id: 1, title: "Order 1")]) }
      func refresh() async { await load() }
      func loadIfNeeded() async {
          guard case .idle = state else { return }
          await load()
      }
  }

  struct OrdersScreen: View {
      @State private var model = OrdersModel()

      var body: some View {
          Group {
              switch model.state {
              case .idle, .loading:
                  ProgressView()
              case .failed(let message):
                  ContentUnavailableView {
                      Label(message, systemImage: "exclamationmark.triangle")
                  } actions: {
                      Button("Retry") {
                          Task { await model.load() }
                      }
                  }
              case .loaded(let orders):
                  List(orders) { Text($0.title) }
                      .refreshable { await model.refresh() }
              }
          }
          .task { await model.loadIfNeeded() }
      }
  }
  ```
````

````exercise
id: m37-l03-e6
type: explain
prompt: "Explain what each part of this view does to avoid flicker, and what the user would see without it."
code: |
  struct DelayedProgressView: View {
      @State private var isVisible = false

      var body: some View {
          ProgressView()
              .opacity(isVisible ? 1 : 0)
              .task {
                  try? await Task.sleep(for: .milliseconds(300))
                  isVisible = true
              }
      }
  }

  // In the screen:
  switch model.state {
  case .idle, .loading: DelayedProgressView()
  case .loaded(let items) where items.isEmpty: EmptyStateView()
  case .loaded(let items): ItemList(items: items)
  case .failed(let message): ErrorView(message: message)
  }
rubric:
  - The delay hides the spinner for loads under 300 ms, so fast loads don't flash it.
  - The task is cancelled when the view is removed, so a load that finishes early never makes the spinner appear.
  - .idle shares the spinner, so the empty state never shows before the first load.
  - Empty is decided from loaded content, not from an initial empty array.
solution: |
  - **The 300 ms delay.** Many loads (cached data, a fast network) finish in well under a third of a second. Without the delay, the spinner flashes for a frame or two, which looks like a glitch. With it, the user sees content appear; only slow loads show the spinner. Some teams also keep a spinner on screen for a minimum time once it's shown, for the same reason.
  - **`.task` instead of a timer.** When the load finishes and the `switch` picks another case, `DelayedProgressView` leaves the hierarchy and its task is cancelled, so `Task.sleep` throws and `isVisible = true` never runs. Nothing to clean up.
  - **`.idle` grouped with `.loading`.** Before the first load starts, the screen shows the (delayed) spinner rather than the empty state, so there's no "Nothing here" flash on launch.
  - **Empty from `.loaded`.** The empty state appears only after a load succeeded with no items, so it always means "there's nothing", never "not loaded yet".
````

## Summary

- Model loading with `LoadState<Value>`: `idle`, `loading`, `loaded(Value)`, `failed(message:)`. Empty is `.loaded` with an empty value, decided in the view.
- Show the spinner only when there's nothing on screen. Refresh keeps `.loaded` content and reports failures separately.
- Loads started by `.task` and `.task(id:)` get cancelled. Check `Task.isCancelled` in the `catch` and return to `.idle` rather than showing an error.
- After every `await`, check the load is still wanted before assigning: `Task.isCancelled` with `.task(id:)`, or a request token when loads can race without cancellation.
- In the view: `.task` for the first load, `ContentUnavailableView` for empty and error, a Retry button, `.refreshable { await ... }` without wrapping in `Task`, and a delayed spinner for fast loads.
