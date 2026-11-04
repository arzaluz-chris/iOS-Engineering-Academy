---
id: m29-l06
title: Continuations and migrating to Swift 6
description: "Bring existing code into Swift Concurrency. You wrap callback APIs with checked continuations and resume exactly once on every path, make the wrapper cancellable, turn a callback that fires many times into an AsyncStream, migrate a GCD-based loader to an actor step by step, and learn the Swift 6.2 settings that change what unannotated code means: default MainActor isolation, nonisolated(nonsending) and @concurrent, and Xcode's Approachable Concurrency."
module: m29
order: 6
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m29-l05]
objectives:
  - Wrap a completion-handler API in an async function with withCheckedContinuation or withCheckedThrowingContinuation.
  - Guarantee that a continuation is resumed exactly once, and recognize the runtime messages for resuming twice and never.
  - Make a continuation-based wrapper cancellable with withTaskCancellationHandler.
  - Turn a callback that delivers many values into an AsyncStream.
  - Migrate a module from dispatch queues and completion handlers to actors and async functions in safe steps.
  - Explain default MainActor isolation, nonisolated(nonsending), @concurrent and the Approachable Concurrency setting, with their proposals, flags and versions.
terms:
  - term: Continuation
    definition: "A value representing a suspended task. withCheckedContinuation hands you one; calling resume(returning:), resume(throwing:) or resume(with:) exactly once wakes the task with that result."
  - term: CheckedContinuation
    definition: "The continuation type that checks its own use at runtime: resuming twice stops the program, and never resuming logs a warning when the continuation is destroyed. UnsafeContinuation skips the checks."
  - term: AsyncStream
    definition: "An AsyncSequence you feed from callback code with continuation.yield(_:) and end with finish(), consumed with for await."
  - term: Default actor isolation
    definition: "A per-module setting (SE-0466, Swift 6.2) that makes unannotated declarations @MainActor instead of nonisolated. Compiler flag -default-isolation MainActor; Xcode setting Default Actor Isolation."
  - term: "nonisolated(nonsending)"
    definition: "A Swift 6.2 modifier (SE-0461) for an async function that runs on its caller's actor. With the NonisolatedNonsendingByDefault upcoming feature, every nonisolated async function behaves this way unless marked @concurrent."
  - term: "@concurrent"
    definition: "A Swift 6.2 attribute (SE-0461) that makes an async function always run on the cooperative thread pool, off any actor, whatever the module's settings."
mastery:
  - Wrap a (value, error) callback in an async throws function that resumes once on all four combinations.
  - Point at the path where a wrapper never resumes or resumes twice, and fix it.
  - Wrap a legacy cancellable job so that cancelling the task cancels the job and the continuation resumes with an error.
  - Expose a progress callback as an AsyncStream and stop the producer in onTermination.
  - Plan a migration from a serial-queue class with completion handlers to an actor, keeping callers working at each step.
  - Read a project's build settings and say where an unannotated function or async function will run.
resources: [swift-adopting-swift6, swift-migration-guide, xcode-build-settings-reference, swift-checkedcontinuation, swift-evolution, swift-mainactor, swift-sendable, dispatch-dispatchqueue]
cards:
  - id: m29-l06-c1
    front: What's the one rule for a continuation?
    back: "Resume it exactly once on every path. Twice: \"SWIFT TASK CONTINUATION MISUSE: … tried to resume its continuation more than once\" and the program stops. Never: the task stays suspended forever (a checked continuation logs \"leaked its continuation without resuming it\")."
  - id: m29-l06-c2
    front: Continuation or AsyncStream?
    back: "Continuation: the callback delivers one result. AsyncStream: it delivers many values over time (progress, events). yield each value, finish() at the end, and stop the producer in onTermination."
  - id: m29-l06-c3
    front: How do you make a continuation wrapper cancellable?
    back: "Wrap withCheckedThrowingContinuation in withTaskCancellationHandler; onCancel calls the legacy API's cancel(), which must make the callback fire (once) with a cancellation error."
  - id: m29-l06-c4
    front: What does SE-0466 (Swift 6.2) change?
    back: "It lets a module default to @MainActor: -default-isolation MainActor, .defaultIsolation(MainActor.self) in SwiftPM, or Xcode's Default Actor Isolation (SWIFT_DEFAULT_ACTOR_ISOLATION). Unannotated code becomes main-actor isolated; opt out with nonisolated or @concurrent."
  - id: m29-l06-c5
    front: Where does a nonisolated async function run?
    back: "Without NonisolatedNonsendingByDefault: on the cooperative pool (SE-0338). With it (part of Approachable Concurrency, SE-0461, Swift 6.2): on the caller's actor. @concurrent forces the pool; nonisolated(nonsending) forces the caller's actor, in any mode."
---

## The idea in one sentence

Old asynchronous code doesn't have to be rewritten in one go: a continuation turns any callback into an `await`, actors replace queues one type at a time, and Swift 6.2's settings let a module say "everything is on the main actor unless I say otherwise".

> [!note] What you already know
> Module 26, lesson 2 previewed `withCheckedThrowingContinuation` with a `Result` callback and showed the double-resume crash. Module 28 built the GCD code you're about to migrate. Lesson 3 here introduced `withTaskCancellationHandler`, and lesson 5 the `sending` and Sendable rules the migrated code must satisfy. Plain-Swift blocks were compiled and run with Swift 6.3 on Linux. The section on Swift 6.2 settings also compiled examples with `-default-isolation MainActor` and `-enable-upcoming-feature NonisolatedNonsendingByDefault`; the course's tests can't pass extra compiler flags, so those blocks are marked as not run by the tests, and the text says what the compiler printed.

## Wrapping a callback API

Many APIs you'll call, from your own older code to third-party SDKs, still look like Module 28's: a function with a completion handler, often in the pre-`Result` style `(Value?, Error?)`. A continuation bridges it:

```swift
enum LookupError: Error {
    case missingData
}

/// Pre-concurrency style: exactly one of the two arguments is non-nil (in theory).
func lookUpCity(zip: String, completion: @escaping @Sendable (String?, Error?) -> Void) {
    switch zip {
    case "10001": completion("New York", nil)
    case "": completion(nil, LookupError.missingData)
    default: completion(nil, nil)          // the case people forget
    }
}

func city(forZip zip: String) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
        lookUpCity(zip: zip) { city, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: city)
            }
        }
    }
}

for zip in ["10001", "99999", ""] {
    do {
        let name = try await city(forZip: zip)
        print("\(zip): \(name ?? "no match")")
    } catch {
        print("\(zip.isEmpty ? "(empty)" : zip): \(error)")
    }
}
```

```output
10001: New York
99999: no match
(empty): missingData
```

1. `withCheckedThrowingContinuation` calls its closure immediately, passing a continuation, and suspends the current task until the continuation is resumed.
2. The closure starts the legacy call and returns. The task is now suspended; no thread waits.
3. When the callback runs, it resumes the continuation **once**: `resume(throwing:)` makes the `await` throw, `resume(returning:)` makes it return. `resume(with: result)` does either from a `Result`.
4. Every combination of the two optionals ends in exactly one resume. The `if let error … else …` shape makes that easy to see. The `(nil, nil)` case is a real one: the API found nothing, so the wrapper returns `nil`.

`withCheckedContinuation` (no "Throwing") is the version for callbacks that can't fail. Both take an `isolation:` parameter defaulted to `#isolation` (lesson 5), so you can call them from main-actor or actor code and the closure runs right there, synchronously, before the task suspends.

### Exactly once, checked

Apple's `CheckedContinuation` documentation: "You must call a resume method exactly once on every execution path throughout the program." The checked continuation enforces both halves at runtime.

Resuming twice stops the program. A common way to get there is a "stale-while-revalidate" API that calls back first with a cached value and then with a fresh one:

```swift runtime-error tried to resume its continuation more than once
func loadPrice(symbol: String, completion: @escaping @Sendable (Int) -> Void) {
    completion(100)     // cached value, right away
    completion(104)     // fresh value from the server
}

func price(symbol: String) async -> Int {
    await withCheckedContinuation { continuation in
        loadPrice(symbol: symbol) { value in
            continuation.resume(returning: value)
        }
    }
}

print("loading price")
print(await price(symbol: "ACME"))
```

```output
loading price
```

Swift 6.3 stops with `Fatal error: SWIFT TASK CONTINUATION MISUSE: price(symbol:) tried to resume its continuation more than once, returning 104!`. Nothing after `loading price` is printed: the crash happens inside the second `completion` call, before the first `await` can deliver its value. A callback that legitimately fires more than once needs an `AsyncStream` (below) or an explicit decision to take only the first value.

Never resuming is quieter and worse. If a path in the legacy API returns without calling back, the awaiting task stays suspended forever: a spinner that never stops, a screen that never loads. When a checked continuation is destroyed without having been resumed, the runtime prints a message; in a test with Swift 6.3 it was `SWIFT TASK CONTINUATION MISUSE: value(for:) leaked its continuation without resuming it. This may cause tasks waiting on it to remain suspended forever.` The program doesn't stop, so read your console. (The leak case isn't run by the course's tests, because a task that waits forever never ends.)

`withUnsafeContinuation` and `withUnsafeThrowingContinuation` have the same API without the runtime checks. Apple describes `UnsafeContinuation` as "a low-overhead mechanism" and adds that "during development, the ability to verify that the invariants are being upheld in testing is important", and since both have the same interface you can swap one for the other. Start with the checked versions; switch only if profiling shows the checks matter.

> [!version] Swift 6.4: a noncopyable Continuation
> Swift 6.4 adds a `Continuation` type that's noncopyable ([SE-0528](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0528-noncopyable-continuation.md)), so the compiler, not the runtime, rejects many double-resume mistakes. This lesson uses `CheckedContinuation`, which is what existing code uses and what Swift 6.3 has.

## Making the wrapper cancellable

A continuation doesn't know about task cancellation. If the task awaiting a 10-second legacy download is cancelled, the continuation keeps waiting for the callback. Combine it with lesson 3's cancellation handler, so cancelling the task cancels the legacy job, and the job's callback resumes the continuation with an error:

```swift
import Dispatch

enum DownloadError: Error {
    case cancelled
}

/// A pre-concurrency downloader: callbacks on a private serial queue, its own cancel().
final class LegacyDownloader: @unchecked Sendable {
    // `isCancelled` and `completion` are only accessed on `queue`.
    private let queue = DispatchQueue(label: "legacy.downloader")
    private var isCancelled = false
    private var completion: (@Sendable (Result<String, DownloadError>) -> Void)?

    func start(_ name: String, seconds: Int, completion: @escaping @Sendable (Result<String, DownloadError>) -> Void) {
        queue.async {
            guard !self.isCancelled else {
                completion(.failure(.cancelled))
                return
            }
            self.completion = completion
            self.queue.asyncAfter(deadline: .now() + .seconds(seconds)) {
                self.finish(.success("\(name).zip"))
            }
        }
    }

    func cancel() {
        queue.async {
            self.isCancelled = true
            self.finish(.failure(.cancelled))
        }
    }

    /// Calls the stored completion at most once.
    private func finish(_ result: Result<String, DownloadError>) {
        guard let completion else { return }
        self.completion = nil
        completion(result)
    }
}

func download(_ name: String, seconds: Int) async throws -> String {
    let downloader = LegacyDownloader()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            downloader.start(name, seconds: seconds) { result in
                continuation.resume(with: result)
            }
        }
    } onCancel: {
        downloader.cancel()
    }
}

let quick = Task { try await download("notes", seconds: 0) }
print(try await quick.value)

let slow = Task { try await download("backup", seconds: 10) }
try await Task.sleep(for: .milliseconds(100))
slow.cancel()
do {
    print(try await slow.value)
} catch {
    print("backup: \(error)")
}
```

```output
notes.zip
backup: cancelled
```

The parts that make it correct:

- **The legacy object is thread-safe and Sendable.** `onCancel` is `@Sendable` and can run concurrently with the operation (lesson 3), so it can only capture Sendable things. The downloader keeps its state on one serial queue, Module 28 style, and the comment says so, which is what makes `@unchecked Sendable` honest here.
- **Every outcome calls the completion once.** `finish(_:)` clears the stored completion before calling it, so a cancel that races with a normal finish can't produce a second call, and the continuation can't be resumed twice.
- **Cancel before start is handled.** If the task is already cancelled when the wrapper runs, `onCancel` runs first (lesson 3), so `cancel()` is queued before `start`, and `start` finds `isCancelled` and fails at once.
- The slow download would take 10 seconds; it ends about 100 ms in, with `DownloadError.cancelled`. The program prints the error instead of timing.

## Callbacks that fire many times: AsyncStream

A continuation is for one result. Progress updates, location fixes or socket messages arrive many times. `AsyncStream` turns them into an async sequence you read with `for await`:

```swift
import Dispatch

/// A pre-concurrency uploader that reports progress several times, then finishes.
final class LegacyUploader: @unchecked Sendable {
    // `cancelled` is only accessed on `queue`.
    private let queue = DispatchQueue(label: "legacy.uploader")
    private var cancelled = false

    func upload(
        _ file: String,
        progress: @escaping @Sendable (Int) -> Void,
        completion: @escaping @Sendable () -> Void
    ) {
        queue.async {
            for percent in stride(from: 25, through: 100, by: 25) {
                if self.cancelled { break }
                progress(percent)
            }
            completion()
        }
    }

    func cancel() {
        queue.async { self.cancelled = true }
    }
}

func uploadProgress(_ file: String, using uploader: LegacyUploader) -> AsyncStream<Int> {
    AsyncStream { continuation in
        continuation.onTermination = { _ in
            uploader.cancel()
        }
        uploader.upload(file) { percent in
            continuation.yield(percent)
        } completion: {
            continuation.finish()
        }
    }
}

for await percent in uploadProgress("photo.heic", using: LegacyUploader()) {
    print("uploaded \(percent)%")
}
print("upload finished")
```

```output
uploaded 25%
uploaded 50%
uploaded 75%
uploaded 100%
upload finished
```

- `AsyncStream { continuation in … }` gives you an `AsyncStream.Continuation`. Unlike a checked continuation, you call `yield(_:)` as many times as you like, then `finish()` once to end the sequence. It's Sendable, so `@Sendable` callbacks may capture it.
- `for await percent in …` suspends between values and ends when the stream finishes.
- `onTermination` runs when the stream ends for any reason: finished, or the consuming task was cancelled, or the loop stopped early. That's where you stop the producer, so cancelling the task that's iterating cancels the upload.
- The values come out in order because the uploader calls `progress` on one serial queue and the stream buffers values in the order they're yielded (by default it keeps all of them; `bufferingPolicy:` can keep only the newest).

Apple's frameworks already expose many such sequences. Module 26, lesson 3 mentioned `NotificationCenter.default.notifications(named:)`; with tasks and cancellation in hand, this is how you use it. The loop is the observer and ends when its task is cancelled:

```swift illustrative
import UIKit

final class KeyboardAwareViewController: UIViewController {
    private var observationTask: Task<Void, Never>?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observationTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: UIResponder.keyboardWillShowNotification
            )
            for await _ in notifications {
                self?.view.setNeedsLayout()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observationTask?.cancel()
    }
}
```

This block isn't checked by the course's tests. `notifications(named:)` doesn't exist in Foundation on Linux, and `Notification` isn't `Sendable` (Apple's page lists no such conformance), so whether Swift 6 accepts iterating it from main-actor code depends on your SDK and deployment target. Build it in your project and read the diagnostics. The shape (a task that owns the loop, cancelled when the screen goes away) is the part to keep.

## Migrating a GCD module, step by step

Apple's advice in "Adopting strict concurrency in Swift 6 apps" is to migrate gradually: "If your app is organized into multiple modules, you can migrate your code one module at a time", and "You don't have to fix all of the reported data races at once." Here's the order that works in practice, applied to a thumbnail loader written the Module 28 way.

**Step 1: turn on the checks before the language mode.** In a Swift 5 target, set **Strict Concurrency Checking** (`SWIFT_STRICT_CONCURRENCY`) to Complete. You get the Swift 6 diagnostics as warnings while the code still builds. Fix the cheap ones: mark completion handlers `@Sendable`, make value types `Sendable`, put UI types on `@MainActor`.

**Step 2: add async entry points next to the old API.** Callers can move over one at a time. The legacy class keeps its serial queue for now:

```swift
import Dispatch

final class ThumbnailLoader: @unchecked Sendable {
    // `cache` and `downloads` are only accessed on `queue`.
    private let queue = DispatchQueue(label: "thumbnail.loader")
    private var cache: [Int: String] = [:]
    private var downloads = 0

    func thumbnail(for id: Int, completion: @escaping @Sendable (String) -> Void) {
        queue.async {
            if let cached = self.cache[id] {
                completion(cached)
                return
            }
            self.downloads += 1
            let image = "thumb-\(id)"       // stands in for a download
            self.cache[id] = image
            completion(image)
        }
    }

    func downloadCount(completion: @escaping @Sendable (Int) -> Void) {
        queue.async { completion(self.downloads) }
    }
}

extension ThumbnailLoader {
    func thumbnail(for id: Int) async -> String {
        await withCheckedContinuation { continuation in
            thumbnail(for: id) { continuation.resume(returning: $0) }
        }
    }

    var downloadCount: Int {
        get async {
            await withCheckedContinuation { continuation in
                downloadCount { continuation.resume(returning: $0) }
            }
        }
    }
}

let loader = ThumbnailLoader()
for id in [3, 7, 3] {
    print(await loader.thumbnail(for: id))
}
print("downloads: \(await loader.downloadCount)")
```

```output
thumb-3
thumb-7
thumb-3
downloads: 2
```

`get async` makes a read-only computed property asynchronous, so callers write `await loader.downloadCount`. Both wrappers resume once on their only path.

**Step 3: replace the queue and the lock with an actor**, once callers use the async API. The `@unchecked` promise, the queue and the completion handlers all go away, and the compiler takes over the checking:

```swift
actor ThumbnailLoader {
    private var cache: [Int: String] = [:]
    private var inFlight: [Int: Task<String, Never>] = [:]
    private(set) var downloads = 0

    func thumbnail(for id: Int) async -> String {
        if let cached = cache[id] {
            return cached
        }
        if let task = inFlight[id] {
            return await task.value
        }
        downloads += 1
        let task = Task { await Self.download(id) }
        inFlight[id] = task
        let image = await task.value
        cache[id] = image
        inFlight[id] = nil
        return image
    }

    @concurrent
    private static func download(_ id: Int) async -> String {
        try? await Task.sleep(for: .milliseconds(20))   // the network
        return "thumb-\(id)"
    }
}

let loader = ThumbnailLoader()
let images = await withTaskGroup(of: (Int, String).self) { group in
    for id in [3, 7, 3, 3, 7] {
        group.addTask { (id, await loader.thumbnail(for: id)) }
    }
    var byID: [Int: String] = [:]
    for await (id, image) in group {
        byID[id] = image
    }
    return byID
}
for id in images.keys.sorted() {
    print("\(id): \(images[id]!)")
}
print("downloads: \(await loader.downloads)")
```

```output
3: thumb-3
7: thumb-7
downloads: 2
```

The migration also fixed a bug the GCD version had. With a real network call, the serial queue would have to release the queue while downloading; two requests for the same id would then both miss the cache and both download. The actor version records the in-flight task before its first `await` (lesson 4), so five concurrent requests for two ids make exactly two downloads. `@concurrent` keeps the simulated download off the actor whatever the module's settings (next section).

**Step 4: delete the hops in UI code.** Screens and view models become (or already are) `@MainActor`. Where they used to write `loader.thumbnail(for:) { image in DispatchQueue.main.async { … } }`, they now write `let image = await loader.thumbnail(for: id)` inside a task that inherited the main actor, and assign directly.

**Step 5: switch the target to the Swift 6 language mode** (Swift Language Version in Build Settings). Warnings from step 1 become errors; fix the rest. Remove the old completion-handler API when nobody calls it.

At each step the app builds and runs. That's the point: you never have a branch where half the module is converted and nothing compiles.

## Swift 6.2: settings that change the defaults

Two Swift 6.2 features change what unannotated code means. They matter for reading any project made since then, because a function's isolation now depends on the target's settings as well as on its declaration.

### Default MainActor isolation (SE-0466)

[SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md), implemented in Swift 6.2, lets a module choose its default isolation. With the main actor as the default, every declaration that doesn't say otherwise is inferred `@MainActor`. The proposal's goal is to let code "opt in to being 'single-threaded' by default, on a module-by-module basis". Where you set it:

| Where | Setting |
| --- | --- |
| Compiler flag | `-default-isolation MainActor` (the other value is `nonisolated`, the default) |
| Swift package (tools version 6.2) | `swiftSettings: [.defaultIsolation(MainActor.self)]` (`nil` means nonisolated) |
| Xcode build setting | **Default Actor Isolation**, `SWIFT_DEFAULT_ACTOR_ISOLATION`: "When set to 'MainActor', `@MainActor` isolation will be inferred by default to mitigate false-positive data-race safety errors in sequential code." |

This program is rejected in Swift 6 mode with the default (nonisolated) setting and compiles with `-default-isolation MainActor` (both checked with Swift 6.3):

```swift illustrative
// Built with -default-isolation MainActor. Not run by the course's tests (they can't pass the flag).

final class SessionStore {                 // inferred @MainActor
    static var shared = SessionStore()     // no "not concurrency-safe" error: it's main-actor state
    var token: String?
}

nonisolated struct Parser {                // explicitly opts out of the default
    func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }
}

@concurrent
func decode(_ text: String) async -> Int { // runs on the cooperative pool
    Parser().wordCount(text)
}

SessionStore.shared.token = "abc"
print(SessionStore.shared.token ?? "none")
print(await decode("three short words"))
```

Without the flag, Swift 6.3 reports `static property 'shared' is not concurrency-safe because it is nonisolated global shared mutable state`. With it, the program compiled and printed `abc` and `3`. Under this setting, `nonisolated` (on a type or a member) and `@concurrent` (on an async function) are how you mark code that should run off the main actor, the reverse of the usual habit.

Good fits: app targets and UI modules, where most code touches the UI anyway. Poor fits: networking, persistence or algorithm packages that other modules call from background work; keep those `nonisolated` by default and annotate.

### nonisolated(nonsending) and @concurrent (SE-0461)

Lessons 1 and 3 warned that where a plain nonisolated async function runs depends on a setting. Here's the setting. Since [SE-0338](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md) (Swift 5.7), a nonisolated async function always ran on the cooperative pool, so calling one from the main actor meant a hop, and passing it a non-Sendable value meant a crossing. [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) (Swift 6.2) adds two explicit spellings and an upcoming feature that flips the default:

- `nonisolated(nonsending) func f() async`: runs on the **caller's** actor. Calling it from the main actor stays on the main actor; non-Sendable arguments never cross.
- `@concurrent func f() async`: always runs on the **cooperative pool**. Use it for CPU-heavy work you want off the main actor.
- With the upcoming feature **`NonisolatedNonsendingByDefault`** enabled, a plain `nonisolated` async function means `nonisolated(nonsending)`. Without it (the Swift 6.3 default this course's tests use), it means `@concurrent`.

The explicit spellings work in either mode, so this runs in the course's tests:

```swift
func describe(_ isolation: (any Actor)?) -> String {
    switch isolation {
    case nil: "nonisolated"
    case is MainActor: "main actor"
    case let other?: "\(type(of: other))"
    }
}

func plainAsync() async -> String {
    describe(#isolation)
}

nonisolated(nonsending) func callersActor() async -> String {
    describe(#isolation)
}

@concurrent func onThePool() async -> String {
    describe(#isolation)
}

// Top-level code is on the main actor.
print("plain:", await plainAsync())
print("nonisolated(nonsending):", await callersActor())
print("@concurrent:", await onThePool())
```

```output
plain: nonisolated
nonisolated(nonsending): main actor
@concurrent: nonisolated
```

Compiled again with `-enable-upcoming-feature NonisolatedNonsendingByDefault`, the first line printed `plain: main actor`; the other two didn't change. That one line is the behavior change, and it's why lesson 3 marked its prime counter `@concurrent`: under the new default, an unmarked version would have run on the main actor and blocked it.

### Approachable Concurrency in Xcode

Xcode groups these changes in one build setting. From Apple's build settings reference: **Approachable Concurrency** (`SWIFT_APPROACHABLE_CONCURRENCY`) "Enables upcoming features that aim to provide a more approachable path to Swift Concurrency: DisableOutwardActorInference, GlobalActorIsolatedTypesUsability, InferIsolatedConformances, InferSendableFromCaptures, and NonisolatedNonsendingByDefault."

In a target already in the Swift 6 language mode, three of those are already on (Swift 6.3 warns "upcoming feature … is already enabled as of Swift version 6" for DisableOutwardActorInference, GlobalActorIsolatedTypesUsability and InferSendableFromCaptures). The two that change behavior there are:

- **NonisolatedNonsendingByDefault** (SE-0461): nonisolated async functions run on the caller's actor, as above.
- **InferIsolatedConformances** ([SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md), Swift 6.2): a `@MainActor` type's protocol conformances are inferred to be main-actor isolated, so a main-actor type can conform to a nonisolated protocol like `Equatable` without marking every witness `nonisolated`. SE-0470 recommends it for modules that use main-actor default isolation.

In a Swift package, the equivalent is `.enableUpcomingFeature("NonisolatedNonsendingByDefault")` and `.enableUpcomingFeature("InferIsolatedConformances")` in `swiftSettings`. (A package with `.defaultIsolation(MainActor.self)` and both features was built with Swift 6.3 for this lesson.)

> [!warning] Check the settings of the project you're in
> Swift 6.2 shipped with Xcode 26, which added both build settings. New app projects created from Xcode 26's templates are widely reported to turn on Default Actor Isolation = MainActor and Approachable Concurrency; this lesson didn't verify the template defaults against Apple documentation, and existing projects keep their old values. Before reasoning about where code runs, look at the target's Build Settings for **Swift Language Version**, **Default Actor Isolation** and **Approachable Concurrency**. Two targets in the same app can legitimately differ.

How to choose for a target:

| Target | Default Actor Isolation | Approachable Concurrency |
| --- | --- | --- |
| App or UI feature module | MainActor | Yes |
| Networking, persistence, domain logic packages | nonisolated | Yes (async functions stay on the caller's actor; mark heavy work `@concurrent`) |
| Existing large module mid-migration | Keep as is | Turn on after the Swift 6 migration, then audit async functions that must stay off the main actor |

## Common mistakes

> [!error] A path that never resumes
> An early `return` in the legacy callback, an unhandled `(nil, nil)`, a delegate method that's never called. The task waits forever. Make every branch end in exactly one resume, and read the console for "leaked its continuation".

> [!error] Resuming from a callback that fires more than once
> Progress callbacks, stale-while-revalidate APIs and retries crash a continuation. Use `AsyncStream`, or ignore later calls on purpose.

> [!error] A continuation wrapper that ignores cancellation
> Cancelling the task doesn't stop the legacy work or resume the continuation. Add `withTaskCancellationHandler` and make the legacy cancel call back exactly once.

> [!error] Forgetting onTermination on an AsyncStream
> The consumer stops iterating, but the producer keeps running and yielding into nothing. Stop it in `onTermination`.

> [!error] Flipping the language mode first
> Switching a large module to Swift 6 in one step produces hundreds of errors and a branch that doesn't build. Turn on complete checking as warnings, add async APIs, convert types, then switch.

> [!error] Assuming a nonisolated async function runs off the main actor
> With Approachable Concurrency on, it runs on the caller's actor. Mark CPU-heavy async functions `@concurrent`.

## Exercises

````exercise
id: m29-l06-e1
type: prediction
prompt: "A legacy API reports through a (value, error) callback. The wrapper resumes once per path. What does the program print?"
code: |
  enum QuotaError: Error {
      case exceeded
  }

  func checkQuota(user: String, completion: @escaping @Sendable (Int?, Error?) -> Void) {
      if user == "ana" {
          completion(3, nil)
      } else if user == "ben" {
          completion(nil, QuotaError.exceeded)
      } else {
          completion(nil, nil)
      }
  }

  func remainingQuota(for user: String) async throws -> Int {
      try await withCheckedThrowingContinuation { continuation in
          checkQuota(user: user) { remaining, error in
              if let error {
                  continuation.resume(throwing: error)
              } else {
                  continuation.resume(returning: remaining ?? 0)
              }
          }
      }
  }

  for user in ["ana", "ben", "cy"] {
      do {
          print("\(user): \(try await remainingQuota(for: user)) left")
      } catch {
          print("\(user): \(error)")
      }
  }
output: |
  ana: 3 left
  ben: exceeded
  cy: 0 left
solution: |
  - `ana`: the callback gets `(3, nil)`, so the continuation returns 3.
  - `ben`: `(nil, exceeded)`, so the `await` throws and the `catch` prints the error.
  - `cy`: `(nil, nil)`, no error, so it returns `remaining ?? 0`, which is 0.

  Each path resumes exactly once, so there's no crash and no hang.

  ```output
  ana: 3 left
  ben: exceeded
  cy: 0 left
  ```
````

````exercise
id: m29-l06-e2
type: find-errors
prompt: "Which are real problems with this wrapper?"
code: |
  func fetchAvatar(id: Int, completion: @escaping @Sendable (Data?, Error?) -> Void) { … }

  func avatar(id: Int) async throws -> Data {
      try await withCheckedThrowingContinuation { continuation in
          fetchAvatar(id: id) { data, error in
              if let error {
                  continuation.resume(throwing: error)
              }
              if let data {
                  continuation.resume(returning: data)
              }
          }
      }
  }
choices:
  - text: "If the callback gets (nil, nil), the continuation is never resumed and the task hangs."
    correct: true
    why: "Neither if runs. A checked continuation logs \"leaked its continuation\" and the caller waits forever."
  - text: "If the callback gets both data and an error, the continuation is resumed twice and the program stops."
    correct: true
    why: "Two independent ifs both run. Use if/else if/else so exactly one resume happens."
  - text: "Cancelling the awaiting task doesn't stop fetchAvatar or resume the continuation."
    correct: true
    why: "Continuations don't know about cancellation. Add withTaskCancellationHandler if the API can be cancelled."
  - text: "withCheckedThrowingContinuation can't be used with a closure that has two parameters."
    correct: false
    why: "The continuation's closure has one parameter (the continuation); the legacy callback can have any shape."
rubric:
  - Finds the missing resume for (nil, nil).
  - Finds the double resume when both are non-nil.
  - Notes the lack of cancellation support.
solution: |
  The two independent `if`s give zero resumes for `(nil, nil)` and two for `(data, error)`. A fixed version uses one chain with a final `else`:

  ```swift
  enum AvatarError: Error {
      case noData
      case server
  }

  func fetchAvatar(id: Int, completion: @escaping @Sendable ([UInt8]?, Error?) -> Void) {
      switch id {
      case 1: completion([1, 2, 3], nil)
      case 2: completion([9], AvatarError.server)   // both: trust the error
      default: completion(nil, nil)
      }
  }

  func avatar(id: Int) async throws -> [UInt8] {
      try await withCheckedThrowingContinuation { continuation in
          fetchAvatar(id: id) { data, error in
              if let error {
                  continuation.resume(throwing: error)
              } else if let data {
                  continuation.resume(returning: data)
              } else {
                  continuation.resume(throwing: AvatarError.noData)
              }
          }
      }
  }

  for id in 1...3 {
      do {
          print("avatar \(id): \(try await avatar(id: id).count) bytes")
      } catch {
          print("avatar \(id): \(error)")
      }
  }
  ```

  ```output
  avatar 1: 3 bytes
  avatar 2: server
  avatar 3: noData
  ```

  (The example uses `[UInt8]` instead of `Data` so it runs without Foundation.) For cancellation, wrap it in `withTaskCancellationHandler` as shown in the lesson.
````

````exercise
id: m29-l06-e3
type: solve
prompt: "A legacy `TemperatureSensor` calls `onReading` with a reading every time it measures and `onStop` once when it stops. Write `func readings(from sensor: TemperatureSensor) -> AsyncStream<Int>` that yields each reading, finishes on stop, and calls `sensor.stop()` when the stream terminates. Then print readings until one is 25 or above, break, and print \"stopped\". The sensor provided measures 18, 21, 26, 30."
starter: |
  import Dispatch

  final class TemperatureSensor: @unchecked Sendable {
      // `stopped` is only accessed on `queue`.
      private let queue = DispatchQueue(label: "sensor")
      private var stopped = false

      func start(onReading: @escaping @Sendable (Int) -> Void, onStop: @escaping @Sendable () -> Void) {
          queue.async {
              for value in [18, 21, 26, 30] {
                  if self.stopped { break }
                  onReading(value)
              }
              onStop()
          }
      }

      func stop() {
          queue.async { self.stopped = true }
      }
  }

  // Write readings(from:) and the loop.
rubric:
  - Uses AsyncStream with yield for each reading and finish() on stop.
  - Sets onTermination to call sensor.stop().
  - Consumes with for await and breaks at 25 or above.
  - Output is deterministic (values come from one serial queue and the loop stops at a fixed value).
solution: |
  ```swift
  import Dispatch

  final class TemperatureSensor: @unchecked Sendable {
      // `stopped` is only accessed on `queue`.
      private let queue = DispatchQueue(label: "sensor")
      private var stopped = false

      func start(onReading: @escaping @Sendable (Int) -> Void, onStop: @escaping @Sendable () -> Void) {
          queue.async {
              for value in [18, 21, 26, 30] {
                  if self.stopped { break }
                  onReading(value)
              }
              onStop()
          }
      }

      func stop() {
          queue.async { self.stopped = true }
      }
  }

  func readings(from sensor: TemperatureSensor) -> AsyncStream<Int> {
      AsyncStream { continuation in
          continuation.onTermination = { _ in
              sensor.stop()
          }
          sensor.start { value in
              continuation.yield(value)
          } onStop: {
              continuation.finish()
          }
      }
  }

  for await reading in readings(from: TemperatureSensor()) {
      print("reading: \(reading)")
      if reading >= 25 {
          break
      }
  }
  print("stopped")
  ```

  ```output
  reading: 18
  reading: 21
  reading: 26
  stopped
  ```

  `break` ends the `for await` loop, which terminates the stream and runs `onTermination`, so the sensor is told to stop. (By then this tiny sensor may already have produced 30; the stream simply drops it, because nobody is iterating anymore.) A continuation couldn't do this: it would crash on the second reading.
````

````exercise
id: m29-l06-e4
type: comprehension
prompt: "A target has Default Actor Isolation = MainActor and Approachable Concurrency = Yes. It declares `func resize(_ image: Image) async -> Image` with no attributes, and a view model calls `await resize(photo)`. Where does resize run, and what should you do if it's slow?"
choices:
  - text: "On the main actor: it's inferred @MainActor by the default isolation. Mark it @concurrent (or nonisolated and @concurrent) so the heavy work runs on the pool."
    correct: true
    why: "Under MainActor default isolation, unannotated functions are @MainActor. @concurrent moves an async function to the cooperative pool."
  - text: "On the cooperative pool, because async functions always leave the main actor."
    correct: false
    why: "That was the SE-0338 rule for nonisolated async functions, and this function isn't even nonisolated here."
  - text: "On a new thread created for the call."
    correct: false
    why: "Swift Concurrency never creates a thread per call."
  - text: "It depends on the caller: if called from a background task, on that task's thread."
    correct: false
    why: "It's @MainActor, so it always runs on the main actor; callers off the main actor hop to it."
solution: |
  With main-actor default isolation, an unannotated function is `@MainActor`, so `resize` runs on the main actor and a slow resize freezes the UI. Mark it `@concurrent` so it runs on the cooperative pool (with `Image` Sendable so it can cross). If it were `nonisolated` without `@concurrent`, Approachable Concurrency's `NonisolatedNonsendingByDefault` would still run it on the caller's actor, which is the main actor here.
````

````exercise
id: m29-l06-e5
type: fill-in
prompt: "Complete the Package.swift target so it defaults to the main actor and turns on the two behavior-changing Approachable Concurrency features."
code: |
  .executableTarget(
      name: "PhotoApp",
      swiftSettings: [
          .defaultIsolation([[1]]),
          .enableUpcomingFeature("[[2]]"),
          .enableUpcomingFeature("[[3]]"),
      ]
  )
blanks:
  - id: "1"
    answers: ["MainActor.self"]
  - id: "2"
    answers: ["NonisolatedNonsendingByDefault", "InferIsolatedConformances"]
  - id: "3"
    answers: ["InferIsolatedConformances", "NonisolatedNonsendingByDefault"]
solution: |
  ```
  .executableTarget(
      name: "PhotoApp",
      swiftSettings: [
          .defaultIsolation(MainActor.self),
          .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
          .enableUpcomingFeature("InferIsolatedConformances"),
      ]
  )
  ```

  `.defaultIsolation(MainActor.self)` is SE-0466's SwiftPM setting (tools version 6.2; `nil` means nonisolated). The other three features in Xcode's Approachable Concurrency setting are already on in the Swift 6 language mode, so these two are the ones that change behavior. The order of the two feature lines doesn't matter.
````

````exercise
id: m29-l06-e6
type: design
prompt: "Plan the migration of a networking module that uses a serial DispatchQueue to guard a token cache, completion handlers delivered on the main queue, and two view controllers that call it. The app must ship every two weeks during the migration."
rubric:
  - Starts with complete strict-concurrency checking as warnings, not the language mode.
  - Adds async APIs (continuation wrappers) next to the completion-handler APIs so callers migrate one by one.
  - Converts the token cache to an actor (or Mutex) once callers are async, and handles reentrancy around token refresh (in-flight task).
  - Removes main-queue hops in the view controllers, relying on @MainActor and task inheritance.
  - Chooses module settings deliberately (nonisolated default for networking, @concurrent for heavy work) and switches to Swift 6 mode last.
solution: |
  1. **Warnings first.** Set Strict Concurrency Checking to Complete on the networking target (still Swift 5 mode). Mark completion handlers `@Sendable`, make request and response types `Sendable` structs. Ship.
  2. **Async alongside.** Add `func send(_ request: Request) async throws -> Response` wrappers using `withCheckedThrowingContinuation` (plus `withTaskCancellationHandler` around the URLSession task's `cancel()`). Mark the old methods `@available(*, deprecated, message: "Use the async version")`. Ship.
  3. **Callers move.** Each view controller replaces `client.send(…) { result in DispatchQueue.main.async { … } }` with `Task { let response = try await client.send(…); label.text = … }`, keeping the task in a property and cancelling it on disappear. Ship after each screen.
  4. **Actor inside.** When no callers use the old API, replace the queue-guarded token cache with an `actor TokenStore` that keeps an in-flight refresh `Task`, so ten requests that all find an expired token trigger one refresh (lesson 4's reentrancy pattern). Delete the completion-handler API.
  5. **Settings and mode.** Keep the networking module's Default Actor Isolation as nonisolated; turn on Approachable Concurrency and mark any heavy decoding `@concurrent`. Switch to the Swift 6 language mode and fix what's left. Ship.
````

## Summary

- `withCheckedContinuation` / `withCheckedThrowingContinuation` wrap a single-result callback: start the legacy call in the closure and resume exactly once in the callback with `resume(returning:)`, `resume(throwing:)` or `resume(with:)`.
- Resuming twice stops the program ("tried to resume its continuation more than once"); never resuming hangs the task (checked continuations log "leaked its continuation without resuming it"). Handle every combination, including `(nil, nil)`.
- Wrap the continuation in `withTaskCancellationHandler` and make the legacy cancel call back exactly once to make the wrapper cancellable.
- Callbacks that fire many times become an `AsyncStream`: `yield` each value, `finish()` at the end, stop the producer in `onTermination`.
- Migrate gradually: complete checking as warnings, async wrappers next to old APIs, actors in place of queues and locks, `@MainActor` instead of main-queue hops, Swift 6 mode last.
- Swift 6.2: SE-0466 default isolation (`-default-isolation MainActor`, `.defaultIsolation(MainActor.self)`, Xcode's Default Actor Isolation); SE-0461 `nonisolated(nonsending)` and `@concurrent`, with `NonisolatedNonsendingByDefault` making nonisolated async functions run on the caller's actor; Xcode's Approachable Concurrency turns on that and four other features, two of which (SE-0461 and SE-0470) change behavior in Swift 6 mode.
- Always check a target's Swift Language Version, Default Actor Isolation and Approachable Concurrency before deciding where code runs.
