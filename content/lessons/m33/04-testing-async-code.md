---
id: m33-l04
title: Testing asynchronous code
description: "Test async code without sleeping: await async functions directly, count callback events with confirmation(), hold a dependency's answer open to see in-between states, test actors, inject a clock that only moves when the test says so, and check that cancelled work stops. Every technique ends in a test that gives the same result on every run."
module: m33
order: 4
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l03]
objectives:
  - Write async test functions that await the code under test and check the result.
  - Use confirmation() to check that a callback runs an exact number of times, or a number in a range, and explain why it fails when the event happens after the closure returns.
  - Build a gated test double that suspends until the test answers, to check a view model's state while a request is in flight.
  - Test an actor's methods, including under concurrent calls.
  - Inject a Clock, and control it from tests with a manual clock to test debouncing and timeouts without waiting.
  - Test that cancellation stops pending work, and recognize the patterns that make async tests flaky.
terms:
  - term: Confirmation
    definition: "Swift Testing's object for events that happen through callbacks. confirmation(expectedCount:) passes one to a closure; the code calls it each time the event happens, and the count is checked when the closure returns."
  - term: Gated double
    definition: "A test double whose async method suspends on a continuation until the test explicitly answers, so the test can observe the code under test while it's waiting."
  - term: Manual clock
    definition: "A Clock implementation for tests whose time only advances when the test calls advance(by:), waking any sleepers whose deadline has passed."
  - term: Flaky test
    definition: "A test that passes or fails without any change to the code, usually because it depends on timing, ordering or shared state."
mastery:
  - Turn a test that sleeps for a fixed time into one that awaits the task it started.
  - Write a confirmation with the right expectedCount for an onChange callback, and predict the count.
  - Write a gated repository and use it to check a loading or refreshing state.
  - Inject any Clock<Duration> into a view model and test a 300 ms debounce in milliseconds of real time.
  - Test that cancelling a pending search means the searcher is never called.
resources: [swift-testing-docs, swift-checkedcontinuation, swift-task-cancellation-handler, swift-actor, swift-task, foundation-nslock]
cards:
  - id: m33-l04-c1
    front: When does confirmation() check its count?
    back: "When its closure returns. Events must happen during the closure, typically while it awaits the code under test. An event fired from a Task that's still running afterward isn't counted: \"Confirmation was confirmed 0 times, but expected to be confirmed 2 times\"."
  - id: m33-l04-c2
    front: How do you test a view model's state while a request is in progress?
    back: "Use a gated double: its async method stores a continuation and suspends. Start the view model's method in a Task, wait until the double has a pending request, check the state, then resume the continuation and await the task."
  - id: m33-l04-c3
    front: How do you test a 300 ms debounce without waiting 300 ms?
    back: "Inject the clock (any Clock<Duration>). Production passes ContinuousClock(); the test passes a manual clock and calls advance(by: .milliseconds(300)) once the sleep has started."
  - id: m33-l04-c4
    front: Three common causes of flaky async tests?
    back: "Waiting with Task.sleep for work to finish; starting a Task and never awaiting it; shared mutable state between tests that run in parallel. Fix them by awaiting what you started, controlling time, and giving every test its own state."
  - id: m33-l04-c5
    front: What does Task.checkCancellation() after an await protect against?
    back: "Applying the result of work that was cancelled while it was suspended, such as an old search overwriting a newer one. It throws CancellationError if the current task was cancelled."
---

## The idea in one sentence

An async test must decide when things happen: it awaits what it starts, makes dependencies answer only when told, and moves time itself, so the result never depends on how fast the machine is.

> [!note] How the code was checked
> The code under test and the test doubles run in the blocks below as programs. The Swift Testing suites were built and run with `swift test` (Swift 6.3, Linux), and the deterministic ones were run 20 times in a row with the same result. `confirmation()` and its range overload are described from Apple's [Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code) article; the range form needs Swift 6.1 or later according to Apple's reference.

## Async tests just await

Most async code needs nothing special. A test function can be `async`, and it awaits the code like any other caller. The reading list's view model, trimmed to loading:

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
    var onChange: (() -> Void)?

    private let repository: any BookRepository

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let books = try await repository.books()
            let rows = books
                .sorted { lhs, rhs in lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title }
                .map { Row(id: $0.id, title: $0.title, isRead: $0.isRead) }
            state = .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
        } catch {
            state = .failed(message: "Couldn't load your books.")
        }
    }
}

struct OfflineError: Error {}

struct StubRepository: BookRepository {
    var booksResult: Result<[Book], any Error> = .success([])

    func books() async throws -> [Book] {
        try booksResult.get()
    }

    func markAsRead(id: Int) async throws {}
}

let books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]
let viewModel = ReadingListViewModel(repository: StubRepository(booksResult: .success(books)))
var changes = 0
viewModel.onChange = { changes += 1 }
await viewModel.load()
print("onChange ran \(changes) times")
if case .loaded(let header, _) = viewModel.state {
    print(header)
}
```

```output
onChange ran 2 times
0 of 1 read
```

A test of the result is three lines: build, `await viewModel.load()`, `#expect(viewModel.state == ...)`. When `await` returns, the work is done, so there's nothing to wait for. Lessons 1 and 3 already wrote tests like that.

Two details matter:

- The view model is `@MainActor`, so the test or its suite is `@MainActor` too. Swift Testing runs tests on an arbitrary executor otherwise, and synchronous access to the view model's properties wouldn't compile.
- If the test calls something that starts its own unstructured `Task` and returns, `await` on that call doesn't wait for the task. That's where the rest of this lesson comes in.

## confirmation(): counting callbacks

`onChange` ran twice: once for `.loading` and once for `.loaded`. A view that redraws on `onChange` depends on that, and a test can check it with `confirmation()`:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct ConfirmationTests {
    let books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]

    @Test func loadingNotifiesTheViewTwice() async {
        let viewModel = ReadingListViewModel(repository: StubRepository(booksResult: .success(books)))

        await confirmation("view notified", expectedCount: 2) { changed in
            viewModel.onChange = { changed() }
            await viewModel.load()
        }
    }

    @Test func aFailedLoadStillNotifiesTheView() async {
        let viewModel = ReadingListViewModel(repository: StubRepository(booksResult: .failure(OfflineError())))

        await confirmation(expectedCount: 1...) { changed in
            viewModel.onChange = { changed() }
            await viewModel.load()
        }
        #expect(viewModel.state == .failed(message: "Couldn't load your books."))
    }
}
```

- **`confirmation("view notified", expectedCount: 2) { changed in ... }`** passes a `Confirmation` to the closure. Calling it, `changed()`, counts one event. When the closure returns, Swift Testing compares the count with `expectedCount` and records an issue if they differ. The default count is 1.
- **`expectedCount: 1...`** accepts a range: "at least once". Apple's reference lists this overload from Swift 6.1. `expectedCount: 0` checks that something **never** happens.
- The closure is `async`, so it awaits `load()`. Both `onChange` calls happen before `load()` returns, so both are counted.

That last point is the rule to remember: **a confirmation doesn't wait**. Apple's migration guide puts it this way: confirmations "don't block or suspend the caller while waiting for a condition to be fulfilled". If the event happens later, it isn't counted:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
@Test func loadStartedInATask() async {
    let books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]
    let viewModel = ReadingListViewModel(repository: StubRepository(booksResult: .success(books)))

    await confirmation("view notified", expectedCount: 2) { changed in
        viewModel.onChange = { changed() }
        Task { await viewModel.load() }   // returns before load() runs
    }
}
```

```text
✘ Test loadStartedInATask() recorded an issue at LateConfirmationTests.swift:9:23: Confirmation was confirmed 0 times, but expected to be confirmed 2 times
↳ view notified
```

The `Task` hadn't run yet when the closure returned. The fix is to await the work inside the closure: `await viewModel.load()` directly, or `await task.value` if the code under test hands you the task. Confirmation is for callbacks that happen *during* awaited work. For callbacks with no awaitable end at all, wrap the API in a continuation (Module 29) or use XCTest's expectations, which do wait (lesson 2).

## Seeing in-between states with a gated double

Some behavior only exists while a request is in flight: a spinner on retry, a refresh indicator over old data. A stub answers immediately, so by the time `await load()` returns, the in-between state is gone. You need a double that **doesn't answer until the test says so**:

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
    var onChange: (() -> Void)?

    private let repository: any BookRepository

    init(repository: any BookRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let books = try await repository.books()
            let rows = books
                .sorted { lhs, rhs in lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title }
                .map { Row(id: $0.id, title: $0.title, isRead: $0.isRead) }
            state = .loaded(header: "\(books.filter(\.isRead).count) of \(books.count) read", rows: rows)
        } catch {
            state = .failed(message: "Couldn't load your books.")
        }
    }
}

struct OfflineError: Error {}

struct StubRepository: BookRepository {
    var booksResult: Result<[Book], any Error> = .success([])

    func books() async throws -> [Book] {
        try booksResult.get()
    }

    func markAsRead(id: Int) async throws {}
}

/// Holds each books() call open until the test answers it.
actor GatedRepository: BookRepository {
    private var pending: CheckedContinuation<[Book], any Error>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func books() async throws -> [Book] {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            for waiter in requestWaiters {
                waiter.resume()
            }
            requestWaiters = []
        }
    }

    func markAsRead(id: Int) async throws {}

    /// Returns once a books() call is waiting for an answer.
    func waitForRequest() async {
        guard pending == nil else { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func respond(with books: [Book]) {
        pending?.resume(returning: books)
        pending = nil
    }

    func fail(with error: any Error) {
        pending?.resume(throwing: error)
        pending = nil
    }
}

let repository = GatedRepository()
let viewModel = ReadingListViewModel(repository: repository)

let firstLoad = Task { await viewModel.load() }
await repository.waitForRequest()
await repository.fail(with: OfflineError())
await firstLoad.value
print("first load failed:", viewModel.state == .failed(message: "Couldn't load your books."))

let retry = Task { await viewModel.load() }
await repository.waitForRequest()
print("while waiting:", viewModel.state)

await repository.respond(with: [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true)])
await retry.value
if case .loaded(let header, _) = viewModel.state {
    print("after the answer:", header)
}
```

```output
first load failed: true
while waiting: loading
after the answer: 1 of 1 read
```

How the gate works:

1. **`books()` suspends on a continuation** and stores it in `pending`. Nothing resumes it until the test calls `respond(with:)` or `fail(with:)`. The actor protects `pending`, and the continuation's body runs on the actor, which is why it can assign the property.
2. **`Task { await viewModel.load() }`** starts the load without waiting for it, because the test needs to act while it's suspended. The task inherits the main actor from the test.
3. **`waitForRequest()`** returns once `books()` has been called. That's the synchronization point: after it, the view model has set `.loading` and is suspended in `books()`. Without it, the test could check the state before `load()` even started.
4. **`respond(with:)`** resumes the stored continuation, and **`await retry.value`** waits for `load()` to finish. Every step is awaited; nothing depends on timing.

The test version:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct RetryTests {
    @Test func retryShowsLoadingUntilTheBooksArrive() async {
        let repository = GatedRepository()
        let viewModel = ReadingListViewModel(repository: repository)

        // First attempt fails.
        let firstLoad = Task { await viewModel.load() }
        await repository.waitForRequest()
        await repository.fail(with: OfflineError())
        await firstLoad.value
        #expect(viewModel.state == .failed(message: "Couldn't load your books."))

        // Retry: while the request is open, the screen shows loading.
        let retry = Task { await viewModel.load() }
        await repository.waitForRequest()
        #expect(viewModel.state == .loading)

        await repository.respond(with: [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true)])
        await retry.value
        #expect(viewModel.state == .loaded(header: "1 of 1 read", rows: [.init(id: 1, title: "Kindred", isRead: true)]))
    }
}
```

> [!warning] A gate that's never opened hangs the test
> If the code under test never calls `books()`, `waitForRequest()` waits forever. Add `.timeLimit(.minutes(1))` to suites that use gates, so a mistake becomes a failure instead of a stuck CI job. Lesson 1 covered the trait.

## Testing actors

An actor's methods are asynchronous from outside, so tests await them, including inside `#expect`:

```swift
actor ReadingStats {
    private(set) var pagesRead = 0
    private(set) var sessions = 0

    func record(pages: Int) {
        pagesRead += pages
        sessions += 1
    }

    var averagePagesPerSession: Int {
        sessions == 0 ? 0 : pagesRead / sessions
    }
}

let stats = ReadingStats()
await stats.record(pages: 30)
await stats.record(pages: 10)
print(await stats.averagePagesPerSession)

let shared = ReadingStats()
await withTaskGroup(of: Void.self) { group in
    for _ in 1...1_000 {
        group.addTask { await shared.record(pages: 2) }
    }
}
print(await shared.pagesRead, await shared.sessions)
```

```output
20
2000 1000
```

```swift illustrative
import Testing
@testable import Bookshelf

struct ReadingStatsTests {
    @Test func averagesPagesPerSession() async {
        let stats = ReadingStats()
        await stats.record(pages: 30)
        await stats.record(pages: 10)
        #expect(await stats.averagePagesPerSession == 20)
    }

    @Test func concurrentRecordsAreAllCounted() async {
        let stats = ReadingStats()
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...1_000 {
                group.addTask { await stats.record(pages: 2) }
            }
        }
        #expect(await stats.pagesRead == 2_000)
        #expect(await stats.sessions == 1_000)
    }
}
```

The concurrent test checks that no update is lost when a thousand tasks record at once. With an actor that can't happen, because each `record` runs alone on the actor; the test documents the requirement and would catch someone turning `ReadingStats` into a class with an unprotected counter. It can't prove the absence of a race, though: a race may not show up in any particular run. That's what Swift 6's compile-time checking and the Thread Sanitizer (Module 28) are for.

Actors don't make *sequences* of calls atomic. If a method awaits something in the middle, another call can run during the suspension (reentrancy, Module 29). Tests for that need a gate inside the actor's dependency, as above, to hold the first call at its suspension point while the second one runs.

## Controlling time

The search screen waits until the user stops typing for 300 ms, then searches. Every keystroke cancels the previous wait:

```swift illustrative
protocol BookSearching: Sendable {
    func results(for query: String) async throws -> [String]
}

@MainActor
final class BookSearchViewModel {
    private(set) var results: [String] = []
    private(set) var searchTask: Task<Void, Never>?

    private let searcher: any BookSearching
    private let clock: any Clock<Duration>

    init(searcher: any BookSearching, clock: any Clock<Duration> = ContinuousClock()) {
        self.searcher = searcher
        self.clock = clock
    }

    /// Called on every keystroke. Searches once the user pauses for 300 ms.
    func search(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await clock.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                let found = try await searcher.results(for: query)
                try Task.checkCancellation()
                results = found
            } catch {
                // Cancelled by a newer query, or the search failed: keep the old results.
            }
        }
    }

    /// Called when the screen goes away.
    func cancelSearch() {
        searchTask?.cancel()
    }
}
```

The key line is `private let clock: any Clock<Duration>`. `Clock` is the standard library's protocol for things that tell time and sleep. The production default is `ContinuousClock()`, so callers don't notice. A test passes a clock it controls.

First, the test to avoid:

```swift illustrative
import Testing
@testable import Bookshelf

/// The version to avoid: real time, real waiting.
@MainActor
@Test func searchWithRealSleep() async throws {
    let searcher = SpySearcher(titles: ["Piranesi", "Kindred"])
    let viewModel = BookSearchViewModel(searcher: searcher)   // ContinuousClock

    viewModel.search("pi")
    try await Task.sleep(for: .milliseconds(350))   // "long enough", we hope

    #expect(viewModel.results == ["Piranesi"])
}
```

It passed when this lesson ran it, in 0.351 seconds. It has two problems. It's slow: every debounce or timeout test adds its real duration to the suite, and suites with dozens of these take minutes. And it's timing-dependent: 350 ms is "300 ms plus some slack", and on a loaded CI machine the slack may not be enough, so it fails once a week for no reason. That's a **flaky test**, and flaky tests teach a team to ignore red builds.

### A manual clock

A clock for tests implements `Clock` with an `Instant` that only moves when the test calls `advance(by:)`. Sleepers park on continuations until their deadline has passed:

```swift
import Foundation

/// A clock whose time only moves when the test calls advance(by:).
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let id: Int
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    // @unchecked Sendable: every stored var below is only touched while holding `lock`.
    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []
    private var sleepCount = 0
    private var sleepCountWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var now: Instant {
        lock.withLock { current }
    }

    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let (id, ready) = lock.withLock {
            sleepCount += 1
            let ready = sleepCountWaiters.filter { $0.count <= sleepCount }
            sleepCountWaiters.removeAll { $0.count <= sleepCount }
            return (sleepCount, ready)
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let wakeNow: Bool? = lock.withLock {
                    if Task.isCancelled { return false }
                    if deadline <= current { return true }
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    return nil
                }
                switch wakeNow {
                case true?: continuation.resume()
                case false?: continuation.resume(throwing: CancellationError())
                case nil: break
                }
                for waiter in ready {
                    waiter.continuation.resume()
                }
            }
        } onCancel: {
            let sleeper: Sleeper? = lock.withLock {
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return sleepers.remove(at: index)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward and wakes every sleeper whose deadline has passed.
    func advance(by duration: Duration) {
        let due: [Sleeper] = lock.withLock {
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.deadline <= current }
            sleepers.removeAll { $0.deadline <= current }
            return due
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Suspends until sleep(until:) has been called `count` times in total.
    /// A sleeper whose deadline has already passed when it registers wakes at once,
    /// so calling advance(by:) right after this never misses it.
    func waitForSleeps(_ count: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let alreadyThere = lock.withLock {
                if sleepCount >= count { return true }
                sleepCountWaiters.append((count, continuation))
                return false
            }
            if alreadyThere {
                continuation.resume()
            }
        }
    }
}

protocol BookSearching: Sendable {
    func results(for query: String) async throws -> [String]
}

@MainActor
final class BookSearchViewModel {
    private(set) var results: [String] = []
    private(set) var searchTask: Task<Void, Never>?

    private let searcher: any BookSearching
    private let clock: any Clock<Duration>

    init(searcher: any BookSearching, clock: any Clock<Duration> = ContinuousClock()) {
        self.searcher = searcher
        self.clock = clock
    }

    /// Called on every keystroke. Searches once the user pauses for 300 ms.
    func search(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await clock.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                let found = try await searcher.results(for: query)
                try Task.checkCancellation()
                results = found
            } catch {
                // Cancelled by a newer query, or the search failed: keep the old results.
            }
        }
    }

    /// Called when the screen goes away.
    func cancelSearch() {
        searchTask?.cancel()
    }
}

actor SpySearcher: BookSearching {
    private let titles: [String]
    private(set) var queries: [String] = []

    init(titles: [String]) {
        self.titles = titles
    }

    func results(for query: String) -> [String] {
        queries.append(query)
        return titles.filter { $0.lowercased().contains(query.lowercased()) }
    }
}

let clock = ManualClock()
let searcher = SpySearcher(titles: ["Piranesi", "Parable of the Sower", "Kindred"])
let viewModel = BookSearchViewModel(searcher: searcher, clock: clock)

viewModel.search("p")
await clock.waitForSleeps(1)
viewModel.search("pi")
await clock.waitForSleeps(2)

clock.advance(by: .milliseconds(299))
print("at 299 ms:", await searcher.queries)

clock.advance(by: .milliseconds(1))
await viewModel.searchTask?.value
print("at 300 ms:", await searcher.queries, viewModel.results)

viewModel.search("kin")
await clock.waitForSleeps(3)
viewModel.cancelSearch()
clock.advance(by: .seconds(1))
await viewModel.searchTask?.value
print("after cancelling:", await searcher.queries, viewModel.results)
```

```output
at 299 ms: []
at 300 ms: ["pi"] ["Piranesi"]
after cancelling: ["pi"] ["Piranesi"]
```

What the pieces do:

- **`Instant`** is a `Duration` offset from the clock's start. `Clock` requires `now`, `minimumResolution` and `sleep(until:tolerance:)`; `InstantProtocol` requires `advanced(by:)`, `duration(to:)` and `<`. The standard library's `sleep(for:)` turns "300 ms from now" into a deadline and calls `sleep(until:)`.
- **`sleep(until:)`** stores a continuation with its deadline. `withTaskCancellationHandler` removes it and throws `CancellationError` if the sleeping task is cancelled, which is what a real clock's sleep does (Module 29).
- **`advance(by:)`** moves `now` and resumes every sleeper whose deadline has passed. Time never moves on its own, so "299 ms" and "300 ms" are exact.
- **`waitForSleeps(_:)`** is the synchronization point, like the gate's `waitForRequest()`. `search(_:)` starts a task and returns at once; the test must not advance the clock until that task has computed its deadline, or the deadline would be computed from the advanced time and never reached.
- **`@unchecked Sendable` with an `NSLock`**: `Clock` requires `Sendable`, and `sleep` is called from many tasks while `advance` is called from the test, so the state needs a lock. Every access goes through `lock.withLock`, which is why the unchecked conformance is justified here. (Swift 6.3 on Linux rejects `lock()` and `unlock()` inside async functions: `instance method 'lock' is unavailable from asynchronous contexts; Use async-safe scoped locking instead`. `withLock` is the scoped form.)

The output shows the two behaviors that matter. Typing "p" then "pi" searched once, for "pi", at exactly 300 ms. And cancelling a pending search meant the searcher was never called for "kin" and the results stayed as they were.

The suite:

```swift illustrative
import Testing
@testable import Bookshelf

@MainActor
struct BookSearchTests {
    let clock = ManualClock()
    let searcher = SpySearcher(titles: ["Piranesi", "Parable of the Sower", "Kindred"])

    @Test func searchesOnlyAfterTheUserStopsTyping() async {
        let viewModel = BookSearchViewModel(searcher: searcher, clock: clock)

        viewModel.search("p")
        await clock.waitForSleeps(1)
        viewModel.search("pi")
        await clock.waitForSleeps(2)

        clock.advance(by: .milliseconds(299))
        #expect(await searcher.queries == [])

        clock.advance(by: .milliseconds(1))
        await viewModel.searchTask?.value
        #expect(await searcher.queries == ["pi"])
        #expect(viewModel.results == ["Piranesi"])
    }

    @Test func leavingTheScreenCancelsThePendingSearch() async {
        let viewModel = BookSearchViewModel(searcher: searcher, clock: clock)

        viewModel.search("kin")
        await clock.waitForSleeps(1)
        viewModel.cancelSearch()
        clock.advance(by: .seconds(1))
        await viewModel.searchTask?.value

        #expect(await searcher.queries == [])
        #expect(viewModel.results == [])
    }
}
```

Both tests ran in about a millisecond each, versus 351 ms for the sleeping version, and they don't depend on the machine's speed.

### Cancellation, checked in the code under test

The cancellation test passes because `search(_:)` checks for cancellation at the right places: the sleep throws when cancelled, and `try Task.checkCancellation()` after each `await` stops a task that was cancelled while it was suspended. Without the check after `searcher.results(for:)`, a slow search for "p" that finished after the user typed "pi" could overwrite the newer results. Tests for that ordering need a gated searcher: hold the "p" search open, let the "pi" search finish, then release "p" and check the results are still "pi"'s.

## Why async tests go flaky, and the fixes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Passes locally, fails on CI sometimes | `Task.sleep` to "wait long enough" | Await the task (`task.value`) or the event; inject a clock |
| A check sees the old state | A `Task { }` was started and never awaited | Keep a handle and `await handle.value`, or make the method `async` |
| Confirmation counts 0 | The event fires after the closure returns | Await the work inside the closure |
| Fails only when run with other tests | Shared static state, a singleton, a shared temp file | Fresh dependencies per test; `.serialized` only as a stopgap |
| Hangs forever | A continuation or gate never resumed | `.timeLimit(.minutes(1))`; make every double resume on every path |
| Fails one run in a hundred | `await Task.yield()` used as "let the other task run" | Wait for a specific signal; `yield` makes no ordering promise |

The common thread: replace "after a while" with "after this specific thing happened". Every synchronization point in this lesson (`waitForRequest`, `waitForSleeps`, `task.value`) is an event, not a duration.

## Common mistakes

> [!error] Confirmation was confirmed 0 times, but expected to be confirmed 2 times
> The event happens in a task that's still running when the confirmation closure returns. `confirmation()` doesn't wait. Await the work inside the closure.

> [!error] error: instance method 'lock' is unavailable from asynchronous contexts
> Calling `NSLock`'s `lock()` and `unlock()` in an `async` function (Swift 6.3, Linux; the message suggests "async-safe scoped locking"). A suspension between them could leave the lock held while the task moves on. Use `lock.withLock { }`, which can't contain an `await`.

> [!error] Advancing the clock before the sleep starts
> `viewModel.search("pi"); clock.advance(by: .milliseconds(300))`. The search task hasn't run yet; when it does, it sleeps until 600 ms, and the test waits forever on `searchTask?.value`. Wait for the sleep to register first.

> [!error] Hard-coded Task.sleep in the code under test
> `try await Task.sleep(for: .milliseconds(300))` inside the view model makes debounce tests wait for real. Inject `any Clock<Duration>` and call `clock.sleep(for:)`.

> [!error] Ignoring cancellation after an await
> A cancelled search that still writes its results. Check `Task.checkCancellation()` (or `Task.isCancelled`) after suspension points whose results you're about to apply.

> [!error] Checking a state that was already true
> `#expect(viewModel.state == .loading)` right after creating the view model proves nothing, because `.loading` is the initial state. Check in-between states after a different state, as the retry test does after a failure.

## Exercises

````exercise
id: m33-l04-e1
type: comprehension
prompt: "A view model's save() starts `Task { await repository.save(item); onSaved?() }` and returns immediately. A test wraps `viewModel.save()` in `await confirmation { saved in viewModel.onSaved = { saved() }; viewModel.save() }` and fails with \"Confirmation was confirmed 0 times\". What's the best fix?"
choices:
  - text: "Make save() async and await the repository inside it (or return the Task so the test can await its value), then await it inside the confirmation closure."
    correct: true
    why: "Then onSaved runs before the closure returns, and the count is checked after the event."
  - text: "Add try await Task.sleep(for: .milliseconds(100)) at the end of the closure."
    correct: false
    why: "It usually passes and occasionally fails: a flaky test. It also adds 100 ms to every run."
  - text: "Use expectedCount: 0...1 so the test passes either way."
    correct: false
    why: "Then the test can't fail when saving is broken, so it checks nothing."
  - text: "Call await Task.yield() a few times inside the closure."
    correct: false
    why: "Yielding gives other tasks a chance to run but promises nothing about which or how far."
solution: |
  `confirmation()` checks the count when its closure returns and doesn't wait for anything. The event has to happen during awaited work, so the code under test must give the test something to await: an `async` method or the `Task` handle. That change also helps the app; a caller that can await `save()` can show a spinner until it finishes.
````

````exercise
id: m33-l04-e2
type: prediction
prompt: "The view model's state has a didSet that calls onChange. The repository fails from the second call on. How many times has onChange run at each print, and what's the final state?"
code: |
  struct OfflineError: Error {}

  actor FlakyRepository {
      private var calls = 0
      func titles() throws -> [String] {
          calls += 1
          guard calls == 1 else { throw OfflineError() }
          return ["Kindred", "Piranesi"]
      }
  }

  @MainActor
  final class ViewModel {
      enum State: Equatable {
          case loading
          case loaded([String])
          case failed
      }

      private(set) var state = State.loading {
          didSet { onChange?() }
      }
      var onChange: (() -> Void)?
      let repository = FlakyRepository()

      func load() async {
          state = .loading
          do {
              state = .loaded(try await repository.titles())
          } catch {
              state = .failed
          }
      }
  }

  let viewModel = ViewModel()
  var changes = 0
  viewModel.onChange = { changes += 1 }

  await viewModel.load()
  print("after load 1: \(changes)")
  await viewModel.load()
  print("after load 2: \(changes)")
  await viewModel.load()
  print("after load 3: \(changes)")
  print(viewModel.state)
output: |
  after load 1: 2
  after load 2: 4
  after load 3: 6
  failed
solution: |
  Every `load()` assigns `state` twice: `.loading`, then `.loaded` or `.failed`. `didSet` runs on every assignment, even when the value doesn't change (the third load sets `.loading`, then `.failed` again, over a `.failed` state). So the count goes up by two each time.

  ```output
  after load 1: 2
  after load 2: 4
  after load 3: 6
  failed
  ```

  In a test, a confirmation around one `load()` needs `expectedCount: 2`, and around all three, 6. If redundant notifications were a problem, `didSet { if state != oldValue { onChange?() } }` would make the third load notify only once, for `.loading`.
````

````exercise
id: m33-l04-e3
type: fill-in
prompt: "Complete the test that checks a refresh keeps the old titles visible while the request is open. The repository is a gated double with waitForRequest() and respond(with:)."
code: |
  @MainActor
  @Test func refreshShowsOldTitlesWhileLoading() async {
      let repository = GatedTitleRepository()
      let viewModel = await loadedViewModel(repository)   // shows ["Kindred", "Piranesi"]

      let refresh = [[1]] { await viewModel.refresh() }
      await repository.[[2]]()
      #expect(viewModel.state == .loaded(titles: ["Kindred", "Piranesi"], isRefreshing: true))

      await repository.respond(with: ["Beloved"])
      await refresh.[[3]]
      #expect(viewModel.state == .loaded(titles: ["Beloved"], isRefreshing: [[4]]))
  }
blanks:
  - id: "1"
    answers: ["Task"]
  - id: "2"
    answers: ["waitForRequest"]
  - id: "3"
    answers: ["value"]
  - id: "4"
    answers: ["false"]
solution: |
  The refresh runs in a `Task` so the test can act while it's suspended. `waitForRequest()` returns once the view model is inside `titles()`, which is after it set `isRefreshing: true`. After `respond(with:)`, `await refresh.value` waits for the refresh to finish before the final check, where `isRefreshing` is back to `false`.
````

````exercise
id: m33-l04-e4
type: find-errors
prompt: "A test for the search screen that fails on CI about once a week. Which comments point at real problems?"
code: |
  @MainActor
  struct SearchTests {
      static let searcher = SpySearcher(titles: ["Piranesi", "Kindred"])

      @Test func searchesAfterTyping() async throws {
          let viewModel = BookSearchViewModel(searcher: Self.searcher)
          viewModel.search("pi")
          try await Task.sleep(for: .milliseconds(310))
          #expect(viewModel.results == ["Piranesi"])
          #expect(await Self.searcher.queries == ["pi"])
      }

      @Test func cancelling() async throws {
          let viewModel = BookSearchViewModel(searcher: Self.searcher)
          viewModel.search("kin")
          viewModel.cancelSearch()
          for _ in 0..<10 { await Task.yield() }
          #expect(await Self.searcher.queries.isEmpty)
      }
  }
choices:
  - text: "Sleeping 310 ms races the 300 ms debounce; any delay on a busy machine makes the check run first."
    correct: true
    why: "Inject a manual clock and advance it, then await the search task."
  - text: "Both tests share one static SpySearcher, and they run in parallel, so each sees the other's queries."
    correct: true
    why: "Give each test its own searcher as a stored property."
  - text: "The cancel test passes even if cancellation is broken, because it only waits a few yields while the real debounce needs 300 ms."
    correct: true
    why: "It checks too early to see a search that cancellation failed to stop. Advance a manual clock past 300 ms, then check."
  - text: "Task.yield() doesn't guarantee the search task has run at all."
    correct: true
    why: "Yields aren't a synchronization point. Wait for a specific event."
  - text: "A static let can't hold an actor."
    correct: false
    why: "It can; actors are Sendable. The problem is sharing it between tests."
rubric:
  - Identifies the sleep-based timing race.
  - Identifies the shared static spy between parallel tests.
  - Explains why the cancel test can't fail, not just why it might be slow.
  - Identifies Task.yield as a non-guarantee.
solution: |
  A fixed suite stores `let clock = ManualClock()` and `let searcher = SpySearcher(...)` as instance properties (fresh per test) and passes the clock to the view model. The typing test does `search("pi")`, `await clock.waitForSleeps(1)`, `clock.advance(by: .milliseconds(300))`, `await viewModel.searchTask?.value`, then checks. The cancel test does `search("kin")`, waits for the sleep, cancels, advances by a full second, awaits the task, then checks the searcher was never called. That's the `BookSearchTests` suite in this lesson. Note the cancel test's original flaw: a test that checks "nothing happened" too early always passes, so it has to give the bug every chance to show up.
````

````exercise
id: m33-l04-e5
type: solve
prompt: "Module 32's pull-to-refresh view model (TitleListViewModel) keeps its titles on screen with isRefreshing: true while a refresh runs, and keeps the old titles with an alert if the refresh fails. Module 32 noted that a real test would also check the intermediate isRefreshing state. Write a gated TitleRepository and a suite that checks: the in-flight state of a refresh and its result; a failed refresh; and that a second refresh while one is running is ignored."
starter: |
  protocol TitleRepository: Sendable {
      func titles() async throws -> [String]
  }

  // TitleListViewModel from Module 32 (state, alertMessage, load(), refresh()).

  actor GatedTitleRepository: TitleRepository {
      // Your code
  }

  @MainActor
  struct RefreshTests {
      // Your tests
  }
rubric:
  - The gated repository stores a continuation in titles(), has a waitForRequest() that returns once a call is pending, and respond/fail methods that resume it once.
  - The tests start refresh() in a Task, wait for the request, check isRefreshing is true with the old titles, then answer and await the task.
  - The failure test checks both the kept titles and the alert message.
  - The double-refresh test calls refresh() a second time while the first is suspended and shows only one request was needed.
  - A helper loads the initial titles through the gate, so each test starts from the loaded state.
solution: |
  The double and the view model, driven as a program:

  ```swift
  protocol TitleRepository: Sendable {
      func titles() async throws -> [String]
  }

  /// Module 32's pull-to-refresh view model.
  @MainActor
  final class TitleListViewModel {
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

  /// Holds each titles() call open until the test answers it.
  actor GatedTitleRepository: TitleRepository {
      private var pending: CheckedContinuation<[String], any Error>?
      private var requestWaiters: [CheckedContinuation<Void, Never>] = []

      func titles() async throws -> [String] {
          try await withCheckedThrowingContinuation { continuation in
              pending = continuation
              for waiter in requestWaiters {
                  waiter.resume()
              }
              requestWaiters = []
          }
      }

      func waitForRequest() async {
          guard pending == nil else { return }
          await withCheckedContinuation { requestWaiters.append($0) }
      }

      func respond(with titles: [String]) {
          pending?.resume(returning: titles)
          pending = nil
      }

      func fail(with error: any Error) {
          pending?.resume(throwing: error)
          pending = nil
      }
  }

  struct OfflineError: Error {}

  let repository = GatedTitleRepository()
  let viewModel = TitleListViewModel(repository: repository)

  let load = Task { await viewModel.load() }
  await repository.waitForRequest()
  await repository.respond(with: ["Piranesi", "Kindred"])
  await load.value
  print("loaded:", viewModel.state)

  let refresh = Task { await viewModel.refresh() }
  await repository.waitForRequest()
  print("refreshing:", viewModel.state)
  await viewModel.refresh()
  print("second refresh ignored:", viewModel.state)
  await repository.fail(with: OfflineError())
  await refresh.value
  print("after failure:", viewModel.state, viewModel.alertMessage ?? "no alert")
  ```

  ```output
  loaded: loaded(titles: ["Kindred", "Piranesi"], isRefreshing: false)
  refreshing: loaded(titles: ["Kindred", "Piranesi"], isRefreshing: true)
  second refresh ignored: loaded(titles: ["Kindred", "Piranesi"], isRefreshing: true)
  after failure: loaded(titles: ["Kindred", "Piranesi"], isRefreshing: false) Couldn't refresh.
  ```

  The suite, built and run with `swift test` (Swift 6.3, Linux), all three tests passing on 20 consecutive runs:

  ```swift illustrative
  import Testing
  @testable import Bookshelf

  @MainActor
  struct RefreshTests {
      let repository = GatedTitleRepository()

      /// Loads ["Kindred", "Piranesi"] through the gate.
      func loadedViewModel() async -> TitleListViewModel {
          let viewModel = TitleListViewModel(repository: repository)
          let load = Task { await viewModel.load() }
          await repository.waitForRequest()
          await repository.respond(with: ["Piranesi", "Kindred"])
          await load.value
          return viewModel
      }

      @Test func refreshKeepsTheListVisibleWhileLoading() async {
          let viewModel = await loadedViewModel()

          let refresh = Task { await viewModel.refresh() }
          await repository.waitForRequest()
          #expect(viewModel.state == .loaded(titles: ["Kindred", "Piranesi"], isRefreshing: true))

          await repository.respond(with: ["Piranesi", "Kindred", "Beloved"])
          await refresh.value
          #expect(viewModel.state == .loaded(titles: ["Beloved", "Kindred", "Piranesi"], isRefreshing: false))
      }

      @Test func aFailedRefreshKeepsTheOldTitles() async {
          let viewModel = await loadedViewModel()

          let refresh = Task { await viewModel.refresh() }
          await repository.waitForRequest()
          await repository.fail(with: OfflineError())
          await refresh.value

          #expect(viewModel.state == .loaded(titles: ["Kindred", "Piranesi"], isRefreshing: false))
          #expect(viewModel.alertMessage == "Couldn't refresh.")
      }

      @Test func aSecondRefreshWhileRefreshingIsIgnored() async {
          let viewModel = await loadedViewModel()

          let first = Task { await viewModel.refresh() }
          await repository.waitForRequest()
          await viewModel.refresh()   // returns at once: already refreshing

          await repository.respond(with: ["Kindred"])
          await first.value
          #expect(viewModel.state == .loaded(titles: ["Kindred"], isRefreshing: false))
      }
  }
  ```

  `loadedViewModel()` goes through the gate too, so every test starts from a known loaded state without a second double. The second refresh returns immediately because of the view model's `guard case .loaded(let current, false) = state`; the test proves it by answering only one request and finishing. If the guard were missing, the second `refresh()` would suspend in `titles()`, replace `pending`, and the test would hang, which `.timeLimit` on the suite would turn into a failure.
````

````exercise
id: m33-l04-e6
type: explain
prompt: "This test hangs forever. Explain exactly why, in terms of when the search task computes its deadline, and how waitForSleeps(_:) prevents it."
code: |
  @MainActor
  @Test func searchesAfterTyping() async {
      let clock = ManualClock()
      let searcher = SpySearcher(titles: ["Piranesi"])
      let viewModel = BookSearchViewModel(searcher: searcher, clock: clock)

      viewModel.search("pi")
      clock.advance(by: .milliseconds(300))
      await viewModel.searchTask?.value
      #expect(viewModel.results == ["Piranesi"])
  }
rubric:
  - Notes that search(_:) only creates a Task, which hasn't run when advance is called.
  - Explains that sleep(for:) computes the deadline from now when the task runs, which is after the advance, so the deadline is 600 ms.
  - Notes nothing advances the clock again, so the sleeper never wakes and searchTask.value never returns.
  - Explains that waitForSleeps(1) waits until the sleep has started, so the deadline is computed from 0 and the advance reaches it.
solution: |
  `search("pi")` creates a `Task` and returns; the task is scheduled but hasn't run. `advance(by: .milliseconds(300))` moves `now` to 300 ms while there are no sleepers, so it wakes nobody. Then the test suspends on `searchTask?.value`, which lets the task run. It calls `clock.sleep(for: .milliseconds(300))`, which reads `now` (300 ms) and sleeps until 600 ms. Nothing advances the clock again, so the sleeper never wakes, the task never finishes, and the test waits forever.

  With `await clock.waitForSleeps(1)` between `search` and `advance`, the test suspends until the task has entered `sleep(until:)`, which means its deadline was computed from 0 and is 300 ms. The advance then reaches it. The general lesson: with a manual clock, "advance" must come after "the code started waiting", and the test needs an explicit signal for that.
````

## Summary

- Async test functions `await` the code under test; when `await` returns, the work is done. Tests of `@MainActor` code are `@MainActor`.
- `confirmation(expectedCount:)` counts callback events that happen **during** its closure; it doesn't wait. Use ranges for "at least" and 0 for "never".
- A **gated double** suspends on a continuation until the test answers. Start the code in a `Task`, wait for the request, check the in-between state, answer, `await task.value`.
- Test actors by awaiting their methods; concurrent tests document the requirement but can't prove the absence of races.
- Inject `any Clock<Duration>`. A **manual clock** moves only on `advance(by:)`; wait for the sleep to start before advancing. A 300 ms debounce test then runs in about a millisecond.
- Check cancellation after awaits in the code under test, and test that cancelled work never reaches its dependency.
- Flaky tests come from waiting for time instead of events, unawaited tasks, and shared state. Replace every "after a while" with "after this happened".
