---
id: m37-l04
title: Pagination and search
description: "Infinite scrolling and search-as-you-type are where SwiftUI's lifetimes and Swift concurrency meet. You trigger the next page from rows near the end with onAppear, guard against duplicate loads with main-actor state set before the first await, keep loaded pages when a page fails, reset cleanly on refresh, and build a debounced search with searchable, task(id:) and an injected sleep, so typing cancels stale searches and late results never land."
module: m37
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l03, m30-l05, m33-l04]
objectives:
  - Trigger the next page from rows near the end of a list with a threshold.
  - Guard against duplicate page loads with main-actor state set before the first await.
  - Handle page errors, the end of the list and refresh without losing or mixing pages.
  - Build a debounced search with searchable, task(id:) and Task.sleep.
  - Test pagination and debouncing deterministically with fakes and controlled sleeps.
terms:
  - term: Prefetch threshold
    definition: "How many rows before the end of the loaded items a row's appearance starts loading the next page, so the next page usually arrives before the user reaches the bottom."
  - term: Debounce
    definition: "Waiting until input has stopped changing for a set time before acting on it. In SwiftUI, task(id: query) plus a sleep at the start of the task: each change cancels the sleeping task and starts a new one."
  - term: searchable(text:placement:prompt:)
    definition: "A SwiftUI modifier (iOS 15) that adds a search field, usually in the navigation bar, bound to a String."
  - term: Page task
    definition: "The single in-flight Task a paginated model keeps while loading a page. Its presence is the guard against duplicate loads; refresh cancels it."
mastery:
  - Write rowAppeared(_:) that starts at most one page load when a row within the threshold appears.
  - Keep loaded items and show a retry row when a page fails; stop at the end of the list.
  - Make refresh cancel an in-flight page and discard its result.
  - "Wire .searchable and .task(id: query) to a model's search(_:) that sleeps first, checks cancellation after each await and skips empty queries."
  - Test both with a gated source and an injected sleep, without real waiting.
resources: [swift-task, swift-cancellationerror, swiftui-foreach, swiftui-performant-scrollable-stacks, swift-mainactor, testing-async-code]
cards:
  - id: m37-l04-c1
    front: How does a SwiftUI list know when to load the next page?
    back: "Each row's onAppear tells the model which item appeared. If it's within the last few loaded items (the threshold) and no page is loading and the end hasn't been reached, the model starts the next page."
  - id: m37-l04-c2
    front: How does a @MainActor model prevent duplicate page loads?
    back: "It checks and records the in-flight load (a stored page Task, or an isLoading flag) with no await in between. Every call runs on the main actor, so a second trigger sees the first load and returns."
  - id: m37-l04-c3
    front: Why not start the page load with .task on the row that triggers it?
    back: ".task follows that row's lifetime: if the row scrolls off before the page arrives, SwiftUI cancels the load. The page belongs to the list, so the model owns the task."
  - id: m37-l04-c4
    front: How do you debounce search in SwiftUI?
    back: "searchable(text: $query) plus .task(id: query) { await model.search(query) }, where search starts with try await Task.sleep(for: .milliseconds(300)). Each keystroke changes the id, SwiftUI cancels the sleeping task, and only the last query gets past the sleep."
  - id: m37-l04-c5
    front: Why check Task.isCancelled after the search request returns?
    back: "Cancellation is cooperative. A request for an old query can still return after a newer one; checking before assigning results stops stale results from replacing current ones."
---

## The idea in one sentence

**The list asks, the model decides**: rows report that they appeared and the search field reports what was typed, and a main-actor model decides whether a page or a search actually starts, so bursts of triggers turn into one request each.

> [!note] About this lesson's code
> The paginating and searching models, their fakes and their tests are plain Swift with Observation, compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Quotes come from Apple's pages for `task(id:name:priority:file:line:_:)` and `searchable(text:placement:prompt:)`, read in November 2026.

## Where you are

Module 30, lesson 5 covered cursor and offset pagination and built an actor `Paginator` that joined concurrent triggers into one request. Module 33, lesson 4 debounced a search in a view model with an injected `Clock`. Lesson 3 of this module gave you `LoadState` and the rule "check after every `await`". This lesson puts all three in a SwiftUI list: what triggers a page, which object owns the load, and how `task(id:)` makes debouncing almost free.

## Triggering the next page

A `List` (or a `LazyVStack`) creates rows as they scroll into view, and each row's `onAppear` runs when it does. That's the trigger: when one of the last few loaded rows appears, ask for the next page. Starting a few rows early (the **threshold**) means the page is usually there before the user hits the bottom.

The model keeps the pagination state and makes the decision:

```swift
import Observation

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct Page: Sendable {
    let books: [Book]
    let nextCursor: String?
}

protocol CatalogSource: Sendable {
    func page(after cursor: String?) async throws -> Page
}

/// Pages of 4 books, ids 1...10. Records each request and waits until the test lets it answer.
actor GatedCatalog: CatalogSource {
    private(set) var requests: [String] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var requestWaiter: CheckedContinuation<Void, Never>?
    var failNext = false

    func page(after cursor: String?) async throws -> Page {
        requests.append(cursor ?? "start")
        await withCheckedContinuation { continuation in
            gate = continuation
            requestWaiter?.resume()
            requestWaiter = nil
        }
        if failNext {
            failNext = false
            throw CatalogError.offline
        }
        let start = Int(cursor ?? "0")!
        let ids = Array((start + 1)...min(start + 4, 10))
        return Page(books: ids.map { Book(id: $0, title: "Book \($0)") },
                    nextCursor: ids.last! < 10 ? String(ids.last!) : nil)
    }

    func waitForRequest() async {
        guard gate == nil else { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }

    func answer() {
        gate?.resume()
        gate = nil
    }

    func setFailNext() { failNext = true }
}

enum CatalogError: Error {
    case offline
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class CatalogModel {
    private(set) var books: [Book] = []
    private(set) var reachedEnd = false
    private(set) var pageError: String?
    @ObservationIgnored private(set) var pageTask: Task<Void, Never>?
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private let source: any CatalogSource
    @ObservationIgnored private let threshold: Int

    init(source: any CatalogSource, threshold: Int = 2) {
        self.source = source
        self.threshold = threshold
    }

    var isLoadingPage: Bool { pageTask != nil }

    /// Called from each row's onAppear.
    func rowAppeared(_ book: Book) {
        guard books.suffix(threshold).contains(book) else { return }
        loadNextPage()
    }

    /// Called from .task for the first page, and from the retry row.
    func loadNextPage() {
        guard pageTask == nil, !reachedEnd else { return }   // check...
        pageError = nil
        pageTask = Task {                                     // ...and record, no await in between
            defer { pageTask = nil }
            do {
                let page = try await source.page(after: nextCursor)
                guard !Task.isCancelled else { return }
                let known = Set(books.map(\.id))
                books += page.books.filter { !known.contains($0.id) }
                nextCursor = page.nextCursor
                reachedEnd = page.nextCursor == nil
            } catch {
                if !Task.isCancelled {
                    pageError = "Couldn't load more books."
                }
            }
        }
    }
}

if #available(macOS 14, iOS 17, *) {
    let catalog = GatedCatalog()
    let model = CatalogModel(source: catalog)

    model.loadNextPage()                        // first page, from .task
    await catalog.waitForRequest()
    await catalog.answer()
    await model.pageTask?.value
    print("first page:", model.books.map(\.id))

    // A fast scroll: rows 2, 3, 4 and 3 again appear before the page arrives.
    for id in [2, 3, 4, 3] {
        model.rowAppeared(model.books[id - 1])
    }
    print("loading:", model.isLoadingPage)
    await catalog.waitForRequest()
    print("requests:", await catalog.requests)
    await catalog.answer()
    await model.pageTask?.value
    print("second page:", model.books.map(\.id))

    // The next page fails: the loaded books stay, an error appears.
    await catalog.setFailNext()
    model.rowAppeared(model.books[7])
    await catalog.waitForRequest()
    await catalog.answer()
    await model.pageTask?.value
    print("after failure:", model.books.count, "books,", model.pageError ?? "no error")

    // Retry, then the last page.
    model.loadNextPage()
    await catalog.waitForRequest()
    await catalog.answer()
    await model.pageTask?.value
    model.rowAppeared(model.books[9])           // the end: nothing happens
    print("end:", model.books.map(\.id), "reached end:", model.reachedEnd)
    print("requests:", await catalog.requests)
}
```

```output
first page: [1, 2, 3, 4]
loading: true
requests: ["start", "4"]
second page: [1, 2, 3, 4, 5, 6, 7, 8]
after failure: 8 books, Couldn't load more books.
end: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] reached end: true
requests: ["start", "4", "8", "8"]
```

How it holds together:

- **The threshold check.** `rowAppeared` acts only for the last `threshold` loaded books. Rows 3 and 4 are in the last two of four; row 2 isn't. A real list uses a threshold of 5 to 10 rows, enough to cover the time a page takes at normal scroll speed.
- **One page at a time.** `loadNextPage()` checks `pageTask == nil` and assigns `pageTask` in the same synchronous stretch. The model is `@MainActor`, so nothing else runs between the check and the assignment. Row 3 started the second page; rows 4 and 3 again appeared while it was loading and found it running. One request (`"4"`) went out. This is the main-actor version of Module 30's actor `Paginator`: there, reentrancy forced the check and the record to be adjacent; here, being synchronous does the same job.
- **`defer { pageTask = nil }`** clears the marker however the load ends, so the next trigger can start a new one.
- **Errors keep the pages.** The failed third page left all eight books in place and set `pageError`, which the list shows as a row with a Retry button. Because `nextCursor` didn't advance, Retry asked for `"8"` again; that's the repeated `"8"` in the requests.
- **The end is a state.** A `nil` cursor sets `reachedEnd`, and after that neither row appearances nor Retry make requests. The request log ends at the second `"8"`, which returned the last two books; row 10 appearing afterward asked for nothing.
- **De-duplicate by id** when appending. It costs one `Set`, and it saves you when the API is offset-based and the list shifted (Module 30, lesson 5).

### Why the model owns the page task

The obvious SwiftUI code puts the load on the row:

```swift illustrative
ForEach(model.books) { book in
    BookRow(book: book)
        .task { await model.loadNextPageIfNeeded(after: book) }   // tied to this row
}
```

`.task` follows the row's lifetime. If the user flicks past the threshold rows, those rows disappear before the page arrives, SwiftUI cancels their tasks, and a request that honors cancellation is thrown away. The next trigger starts it over. The page belongs to the list, not to whichever row happened to trigger it, so the model starts the `Task` and keeps it. Rows only report `onAppear`, which is synchronous and cancels nothing.

## The list

```swift ios
import SwiftUI

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

@MainActor
@Observable
final class CatalogModel {
    private(set) var books: [Book] = []
    private(set) var reachedEnd = false
    private(set) var pageError: String?

    func rowAppeared(_ book: Book) {}
    func loadNextPage() {}
    func refresh() async {}
}

struct CatalogList: View {
    let model: CatalogModel

    var body: some View {
        List {
            ForEach(model.books) { book in
                Text(book.title)
                    .onAppear { model.rowAppeared(book) }
            }
            if let message = model.pageError {
                HStack {
                    Text(message)
                    Spacer()
                    Button("Retry") { model.loadNextPage() }
                }
            } else if !model.reachedEnd {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .onAppear { model.loadNextPage() }
            }
        }
        .task { model.loadNextPage() }
        .refreshable { await model.refresh() }
    }
}
```

(The model is stubbed so the block type-checks on its own.) Three triggers feed the same guarded method: the first page from `.task`, rows near the end, and the spinner row at the bottom, which catches the case where the threshold rows were all already visible (a short first page on a tall screen). The error row replaces the spinner, so a failed page doesn't retry in a loop as the spinner reappears.

## Refresh: start over without mixing pages

Pull to refresh reloads from the first page. The trap is a page load that's already in flight: if it lands after the refresh, page 3 of the old list gets appended to page 1 of the new one. Refresh must **cancel the page task and make sure its result is ignored**:

```swift
import Observation

struct Page: Sendable {
    let ids: [Int]
    let nextCursor: String?
}

protocol CatalogSource: Sendable {
    func page(after cursor: String?) async throws -> Page
}

/// Holds every request until the test answers it, in order. Ignores cancellation.
actor GatedCatalog: CatalogSource {
    private var pending: [(cursor: String, continuation: CheckedContinuation<Page, Never>)] = []
    private var requestWaiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    private(set) var requestCount = 0

    func page(after cursor: String?) async -> Page {
        await withCheckedContinuation { continuation in
            pending.append((cursor ?? "start", continuation))
            requestCount += 1
            if let waiter = requestWaiter, requestCount >= waiter.count {
                waiter.continuation.resume()
                requestWaiter = nil
            }
        }
    }

    func waitForRequests(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { requestWaiter = (count, $0) }
    }

    /// Answers the oldest pending request with the given page.
    func answer(with page: Page) {
        pending.removeFirst().continuation.resume(returning: page)
    }
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class CatalogModel {
    private(set) var ids: [Int] = []
    @ObservationIgnored private(set) var pageTask: Task<Void, Never>?
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private let source: any CatalogSource

    init(source: any CatalogSource) {
        self.source = source
    }

    func loadNextPage() {
        guard pageTask == nil else { return }
        let cursor = nextCursor
        pageTask = Task {
            let page = try? await source.page(after: cursor)
            guard !Task.isCancelled else { return }   // refreshed meanwhile: leave everything alone
            pageTask = nil
            guard let page else { return }
            ids += page.ids
            nextCursor = page.nextCursor
        }
    }

    /// Pull to refresh: drop any page in flight and load the first page again.
    func refresh() async {
        pageTask?.cancel()
        pageTask = nil
        guard let first = try? await source.page(after: nil) else { return }
        ids = first.ids
        nextCursor = first.nextCursor
    }
}

if #available(macOS 14, iOS 17, *) {
    let catalog = GatedCatalog()
    let model = CatalogModel(source: catalog)

    model.loadNextPage()
    await catalog.waitForRequests(1)
    await catalog.answer(with: Page(ids: [1, 2], nextCursor: "2"))
    await model.pageTask?.value

    model.loadNextPage()                         // page 2 starts...
    await catalog.waitForRequests(2)
    let staleTask = model.pageTask
    let refresh = Task { await model.refresh() } // ...and the user pulls to refresh
    await catalog.waitForRequests(3)

    await catalog.answer(with: Page(ids: [3, 4], nextCursor: "4"))       // the old page 2, late
    await staleTask?.value
    await catalog.answer(with: Page(ids: [0, 1, 2], nextCursor: "2"))    // the new first page
    await refresh.value
    print(model.ids)
}
```

```output
[0, 1, 2]
```

The old page 2 (`[3, 4]`) arrived while the refresh was waiting, found its task cancelled and dropped itself. Without the `guard !Task.isCancelled` line, the list would briefly be `[1, 2, 3, 4]` and then be replaced, or, if the answers came in the other order, end up as `[0, 1, 2, 3, 4]` with the wrong cursor. The `pageTask = nil` in `refresh()` lets new page loads start right away. That's also why the cancelled task returns *before* clearing `pageTask`: by the time it resumes, `pageTask` may already hold a newer load that it must not erase. The first version's `defer { pageTask = nil }` would erase it, which was fine only because nothing there cancelled a page; once refresh exists, clear the marker after the cancellation check.

## Search: debounce with task(id:)

`searchable(text:placement:prompt:)` adds a search field bound to a `String`. Apple's abstract: it "Marks this view as searchable, which configures the display of a search field." What you do with the text is up to you, and searching on every keystroke sends a request per letter.

`task(id:)` already has the hard part of a debounce built in. Apple: "If the `id` value changes, SwiftUI cancels and restarts the task." Start the task with a short sleep. Each keystroke changes the id, which cancels the sleeping task (`Task.sleep` throws `CancellationError`) and starts a new one. Only the query the user paused on survives the sleep:

```swift ios
import SwiftUI

struct Book: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

@MainActor
@Observable
final class SearchModel {
    private(set) var results: [Book] = []
    private(set) var isSearching = false
    func search(_ query: String) async {}
}

struct SearchScreen: View {
    @State private var query = ""
    let model: SearchModel

    var body: some View {
        List(model.results) { Text($0.title) }
            .overlay {
                if !query.isEmpty && model.results.isEmpty && !model.isSearching {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: Text("Title or author"))
            .task(id: query) {
                await model.search(query)
            }
    }
}
```

`ContentUnavailableView.search(text:)` (iOS 17) is the system's "No Results for …" view. The model does the rest:

```swift
import Observation

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
}

protocol BookSearching: Sendable {
    func books(matching query: String) async throws -> [Book]
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class SearchModel {
    private(set) var results: [Book] = []
    private(set) var isSearching = false
    @ObservationIgnored private let searcher: any BookSearching
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    init(searcher: any BookSearching,
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.searcher = searcher
        self.sleep = sleep
    }

    /// Called from .task(id: query). Cancelled by SwiftUI when the query changes.
    func search(_ query: String) async {
        let query = String(query.drop { $0 == " " }.reversed().drop { $0 == " " }.reversed())
        guard !query.isEmpty else {
            results = []                  // cleared field: no request, no wait
            return
        }
        do {
            try await sleep(.milliseconds(300))             // the debounce
            isSearching = true
            defer { isSearching = false }
            let found = try await searcher.books(matching: query)
            guard !Task.isCancelled else { return }          // a newer query took over
            results = found
        } catch {
            // Cancelled while sleeping or searching, or the search failed: keep the old results.
        }
    }
}

/// Records queries; each search waits until the test releases it. Ignores cancellation.
actor GatedSearcher: BookSearching {
    private(set) var queries: [String] = []
    private var pending: [String: CheckedContinuation<Void, Never>] = [:]
    private var waiter: (query: String, continuation: CheckedContinuation<Void, Never>)?

    func books(matching query: String) async -> [Book] {
        queries.append(query)
        await withCheckedContinuation { continuation in
            pending[query] = continuation
            if waiter?.query == query {
                waiter?.continuation.resume()
                waiter = nil
            }
        }
        return [Book(id: query.count, title: "Result for \(query)")]
    }

    func waitForSearch(_ query: String) async {
        guard pending[query] == nil else { return }
        await withCheckedContinuation { waiter = (query, $0) }
    }

    func release(_ query: String) {
        pending.removeValue(forKey: query)?.resume()
    }
}

/// Does what .task(id:) does when the id changes: cancel the old task, start a new one.
@MainActor
final class TaskByID {
    private(set) var current: Task<Void, Never>?

    func idChanged(_ work: @escaping @MainActor () async -> Void) {
        current?.cancel()
        current = Task { await work() }
    }
}

if #available(macOS 14, iOS 17, *) {
    let searcher = GatedSearcher()
    // In tests the debounce doesn't wait; it only fails if the task was already cancelled.
    let model = SearchModel(searcher: searcher, sleep: { _ in try Task.checkCancellation() })
    let task = TaskByID()

    // Typing "pir" fast: three ids, the first two cancelled before they get past the sleep.
    for query in ["p", "pi", "pir"] {
        task.idChanged { await model.search(query) }
    }
    await searcher.waitForSearch("pir")
    print("searched:", await searcher.queries, "searching:", model.isSearching)

    // While "pir" is in flight, the user types "pira".
    let stale = task.current
    task.idChanged { await model.search("pira") }
    await searcher.waitForSearch("pira")
    await searcher.release("pira")
    await task.current?.value
    await searcher.release("pir")                  // the old search answers late
    await stale?.value
    print("results:", model.results.map(\.title))

    // Clearing the field: no request.
    task.idChanged { await model.search("  ") }
    await task.current?.value
    print("cleared:", model.results.count, "searched:", await searcher.queries)
}
```

```output
searched: ["pir"] searching: true
results: ["Result for pira"]
cleared: 0 searched: ["pir", "pira"]
```

What each piece does:

- **`sleep` is injected.** Production uses `Task.sleep(for:)`; the test passes a sleep that returns at once but throws if the task was cancelled, which is the part of `Task.sleep`'s behavior the debounce depends on. Module 33, lesson 4's `ManualClock` is the tool when a test needs to check the timing itself ("nothing at 299 ms"); here the test checks what gets searched.
- **`TaskByID`** stands in for SwiftUI in the test: cancel the old task, start a new one, as `task(id:)` does when the id changes. The model doesn't own the search task; the view's lifetime does.
- **"p" and "pi" never reached the searcher.** Their tasks were cancelled before they ran, so their sleep threw. In the app, the real sleep would be interrupted partway through; the result is the same.
- **The stale "pir" result was dropped.** "pira" was answered first; when "pir" finally answered, its task was cancelled, so `guard !Task.isCancelled` returned before touching `results`. It's lesson 3's rule again.
- **An empty or all-spaces query** clears the results immediately with no sleep and no request. The trimming here is written without Foundation (it drops leading and trailing spaces); in the app, `query.trimmingCharacters(in: .whitespaces)` is the usual choice.
- **`isSearching`** is true only between the sleep and the response, so the "No results" overlay doesn't flash while the user is still typing.

> [!tip] onSubmit for expensive searches
> If each search is costly (a paid API, a large local index), you can skip search-as-you-type entirely: `.onSubmit(of: .search) { ... }` runs when the user taps Search on the keyboard. The model's `search(_:)` stays the same; only the trigger changes.

## Common mistakes

> [!error] Setting the loading flag inside the task
> `Task { isLoadingPage = true; ... }` leaves a gap between the check and the flag, during which other triggers start their own loads. Check and record the in-flight load synchronously, before any `await` or `Task`.

> [!error] Clearing the guard only on success
> If `isLoadingPage = false` is only at the end of the `do` block, one failed page blocks pagination forever. Clear the marker on every path: with `defer` when nothing cancels page loads, or right after the cancellation check when refresh can.

> [!error] Searching on every keystroke
> `.onChange(of: query) { Task { await model.search(query) } }` sends a request per letter and never cancels the old ones, so results arrive out of order. Use `.task(id: query)` with a sleep first.

> [!error] Debouncing without a cancellation check after the request
> The sleep stops queries that were replaced while waiting, but not one replaced while its request was in flight. Check `Task.isCancelled` after the `await` too.

> [!error] Appending a page after a refresh
> A page load that was in flight when the user refreshed appends old items to the new list. Cancel the page task on refresh and check cancellation before appending.

## Exercises

````exercise
id: m37-l04-e1
type: prediction
prompt: "A paginator with a threshold of 3 receives row appearances synchronously, with a fake source that answers instantly. What does it print?"
code: |
  @MainActor
  final class Paginator {
      private(set) var items: [Int] = []
      private(set) var requests = 0
      private(set) var isLoading = false
      let threshold = 3
      let pageSize = 5
      let total = 12

      var reachedEnd: Bool { items.count >= total }

      func rowAppeared(_ item: Int) {
          guard items.suffix(threshold).contains(item) else { return }
          loadNextPage()
      }

      func loadNextPage() {
          guard !isLoading, !reachedEnd else { return }
          isLoading = true
          requests += 1
          let start = items.count + 1
          items += Array(start...min(start + pageSize - 1, total))
          isLoading = false
      }
  }

  let paginator = Paginator()
  paginator.loadNextPage()
  for row in [1, 2, 3, 4] {
      paginator.rowAppeared(row)
  }
  print(paginator.items.count, paginator.requests)
  for row in [6, 7, 8, 9, 10, 11, 12] {
      paginator.rowAppeared(row)
  }
  print(paginator.items.count, paginator.requests, paginator.reachedEnd)
output: |
  10 2
  12 3 true
hints:
  - "After the first page, items is [1...5]; the last three are 3, 4, 5."
  - "Each load here finishes immediately, so isLoading is false again by the next row."
  - "Row 3 loads page 2 (items 6...10). Is row 4 then in the last three?"
solution: |
  ```output
  10 2
  12 3 true
  ```

  The first `loadNextPage()` loads 1...5. Rows 1 and 2 aren't among the last three (3, 4, 5). Row 3 is, so page 2 loads 6...10. Now the last three are 8, 9 and 10, so row 4 does nothing: 10 items, 2 requests. In the second loop, rows 6 and 7 do nothing; row 8 is among the last three, so page 3 loads 11 and 12 (capped by `total`) and `reachedEnd` becomes true. Rows 9 to 12 are near the end but hit the `reachedEnd` guard. Notice that moving the window is what stops row 4: the threshold is measured against the items loaded *now*, not when the scroll started.
````

````exercise
id: m37-l04-e2
type: comprehension
prompt: "Why should a paginated list's page load not be started with `.task` on the row that triggers it?"
choices:
  - text: "Because .task is tied to that row's lifetime: if the row scrolls off before the page arrives, SwiftUI cancels the load."
    correct: true
    why: "The page belongs to the list; the model should own the task."
  - text: "Because .task can't call async functions."
    correct: false
    why: ".task's closure is async."
  - text: "Because .task runs only once per app launch."
    correct: false
    why: "It runs each time the view appears."
  - text: "Because onAppear runs on a background thread, which is safer for network calls."
    correct: false
    why: "onAppear runs on the main actor; it's chosen because it's synchronous and starts nothing that a row disappearing would cancel."
solution: |
  **`.task` follows the row.** Apple: SwiftUI "can automatically cancel the task after the view disappears before the action completes." A fast scroll moves the threshold rows off screen within a fraction of a second, so their tasks get cancelled and a cancellation-aware request is discarded. `onAppear` only reports the appearance; the model starts and keeps the page `Task`, whose lifetime is the list's.
````

````exercise
id: m37-l04-e3
type: prediction
prompt: "The debounced search model from the lesson, driven like task(id:). The sleep throws if the task is cancelled and otherwise returns at once; the searcher answers immediately. What does it print?"
code: |
  protocol BookSearching: Sendable {
      func titles(matching query: String) async -> [String]
  }

  actor SpySearcher: BookSearching {
      private(set) var queries: [String] = []
      func titles(matching query: String) -> [String] {
          queries.append(query)
          return ["\(query)!"]
      }
  }

  @MainActor
  final class SearchModel {
      private(set) var results: [String] = []
      let searcher: SpySearcher
      init(searcher: SpySearcher) { self.searcher = searcher }

      func search(_ query: String) async {
          guard !query.isEmpty else {
              results = []
              return
          }
          do {
              try Task.checkCancellation()          // the debounce's sleep, in a test
              let found = await searcher.titles(matching: query)
              guard !Task.isCancelled else { return }
              results = found
          } catch {}
      }
  }

  @MainActor
  final class TaskByID {
      private(set) var current: Task<Void, Never>?
      func idChanged(_ work: @escaping @MainActor () async -> Void) {
          current?.cancel()
          current = Task { await work() }
      }
  }

  let searcher = SpySearcher()
  let model = SearchModel(searcher: searcher)
  let task = TaskByID()

  task.idChanged { await model.search("d") }
  task.idChanged { await model.search("du") }
  task.idChanged { await model.search("dun") }
  await task.current?.value
  print(model.results, await searcher.queries)

  task.idChanged { await model.search("dune") }
  await task.current?.value
  task.idChanged { await model.search("") }
  await task.current?.value
  print(model.results, await searcher.queries)
output: |
  ["dun!"] ["dun"]
  [] ["dun", "dune"]
hints:
  - "The first two tasks are cancelled before they run."
  - "\"dune\" runs to completion before the empty query starts."
  - "An empty query makes no request."
solution: |
  ```output
  ["dun!"] ["dun"]
  [] ["dun", "dune"]
  ```

  All three tasks are created synchronously; each `idChanged` cancels the previous one before it gets a chance to run. When "d" and "du" do run, `checkCancellation()` throws, so only "dun" reaches the searcher. Then "dune" runs alone and completes (the searcher records it, results become `["dune!"]`), and the empty query clears the results without a request.
````

````exercise
id: m37-l04-e4
type: find-errors
prompt: "Which of these are real problems in this search screen?"
code: |
  struct SearchScreen: View {
      @State private var query = ""
      @State private var results: [Book] = []
      let searcher: any BookSearching

      var body: some View {
          List(results) { Text($0.title) }
              .searchable(text: $query)
              .onChange(of: query) {
                  Task {
                      results = (try? await searcher.books(matching: query)) ?? []
                  }
              }
      }
  }
choices:
  - text: "It sends a request on every keystroke, with no debounce."
    correct: true
    why: "Nothing waits for the user to pause."
  - text: "Earlier searches are never cancelled, so a slow answer for an old query can overwrite the latest results."
    correct: true
    why: "Each Task is independent and assigns whatever it gets, whenever it gets it."
  - text: "A failed search clears the results, so a brief network error wipes the list."
    correct: true
    why: "try? ... ?? [] turns every failure (including cancellation) into an empty list."
  - text: "searchable requires the text to be stored in an @Observable model."
    correct: false
    why: "A @State String binding is the normal choice."
rubric:
  - Flags the missing debounce.
  - Flags the uncancelled, unordered searches.
  - Flags failures turning into an empty list.
  - Rejects the @Observable claim.
solution: |
  Three real problems. **No debounce**: each letter sends a request. **No cancellation**: the tasks race, and whichever answers last wins, which may be "du" after "dune". **Errors become empty results**: `try? … ?? []` shows "no results" for a network blip.

  The fix is the lesson's shape: `.task(id: query) { await model.search(query) }`, where `search` sleeps first, checks `Task.isCancelled` after the request, and keeps the old results on failure. `@State` for the query text is fine.
````

````exercise
id: m37-l04-e5
type: solve
prompt: |
  Write the decision a paginated list makes when a row appears, as a pure function so it can be tested without a model:

  `func shouldLoadMore(appearedIndex: Int, loadedCount: Int, threshold: Int, isLoading: Bool, reachedEnd: Bool) -> Bool`

  It returns `true` only when no load is running, the end hasn't been reached, and the row is within the last `threshold` loaded rows (indexes count from 0). Then run:

  ```swift
  print(shouldLoadMore(appearedIndex: 14, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 15, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 19, loadedCount: 20, threshold: 5, isLoading: true, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 19, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: true))
  print(shouldLoadMore(appearedIndex: 0, loadedCount: 3, threshold: 5, isLoading: false, reachedEnd: false))
  ```

  ```output
  false
  true
  false
  false
  true
  ```
starter: |
  func shouldLoadMore(appearedIndex: Int, loadedCount: Int, threshold: Int, isLoading: Bool, reachedEnd: Bool) -> Bool {
      // ...
  }
hints:
  - "The last threshold rows have indexes loadedCount - threshold through loadedCount - 1."
  - "With fewer rows than the threshold, every row qualifies."
rubric:
  - Returns false while loading or at the end.
  - Uses appearedIndex >= loadedCount - threshold.
  - Handles a short list (every row qualifies).
  - Output matches exactly.
solution: |
  ```swift
  func shouldLoadMore(appearedIndex: Int, loadedCount: Int, threshold: Int, isLoading: Bool, reachedEnd: Bool) -> Bool {
      guard !isLoading, !reachedEnd else { return false }
      return appearedIndex >= loadedCount - threshold
  }

  print(shouldLoadMore(appearedIndex: 14, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 15, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 19, loadedCount: 20, threshold: 5, isLoading: true, reachedEnd: false))
  print(shouldLoadMore(appearedIndex: 19, loadedCount: 20, threshold: 5, isLoading: false, reachedEnd: true))
  print(shouldLoadMore(appearedIndex: 0, loadedCount: 3, threshold: 5, isLoading: false, reachedEnd: false))
  ```

  ```output
  false
  true
  false
  false
  true
  ```

  With 20 rows and a threshold of 5, rows 15 through 19 trigger; row 14 doesn't. A load in progress or the end of the list wins over position. When the list is shorter than the threshold, `loadedCount - threshold` is negative, so every row triggers, which is what you want for a first page that doesn't fill the screen. In the model, `rowAppeared` finds the index and calls this, and the guard on `pageTask` still prevents a duplicate if two rows qualify at once.
````

````exercise
id: m37-l04-e6
type: design
prompt: "Combine search and pagination: a catalog screen with a search field, where results are paginated by cursor. Describe the model's state, what happens when the query changes mid-page, how refresh works, what is cancelled when, and how you'd test it."
rubric:
  - Results, cursor, reachedEnd and page error are per query; a new query resets them.
  - The query change cancels both the debounced search and any in-flight page load, and their results are ignored after cancellation.
  - The first page of a query comes from the search; later pages from row appearances, guarded by the page task.
  - Refresh reloads the current query's first page and cancels the page task.
  - Tests use a gated source and an injected sleep, and cover a page arriving after the query changed.
solution: |
  - **State:** `query`, `results: [Book]`, `nextCursor`, `reachedEnd`, `pageError`, `pageTask`, plus a `LoadState`-style status for the first page. All of it belongs to the current query.
  - **Query change:** `.task(id: query)` cancels the previous search task. `search(_:)` starts by cancelling `pageTask`, sleeps for the debounce, fetches page 1 for the new query, checks `Task.isCancelled`, and replaces `results`, `nextCursor` and `reachedEnd`. A page that was loading for the old query is cancelled and drops its result in its own cancellation check, so old-query items never get appended.
  - **Next pages:** rows call `rowAppeared`; `loadNextPage()` captures the current query and cursor, guards on `pageTask`, and also checks before appending that the query hasn't changed (a token, in case the page task wasn't cancelled in time).
  - **Refresh:** cancels `pageTask` and reloads page 1 for the current query, keeping results on screen until it returns.
  - **Tests:** a gated source keyed by (query, cursor), the injected sleep from this lesson, and a `TaskByID` driver. Cases: typing fast searches once; a page for "du" arriving after the query became "dune" is ignored; a failed page keeps results and Retry asks for the same cursor; refresh during a page load leaves only the new first page.
````

## Summary

- Rows report `onAppear`; the model decides. Load the next page when a row within the last few (the threshold) appears, plus a spinner row at the bottom as a backstop.
- The model owns the page `Task`. Check and record it synchronously on the main actor, clear it with `defer`, and don't start page loads with a row's `.task`.
- Failed pages keep the loaded items and show a retry row; a `nil` cursor ends pagination; append with de-duplication.
- Refresh cancels the page task and every load checks `Task.isCancelled` before applying its result.
- Debounce search with `.searchable` plus `.task(id: query)` and a sleep at the start of `search(_:)`. Inject the sleep for tests, skip empty queries, and check cancellation after the request.
