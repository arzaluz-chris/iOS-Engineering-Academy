---
id: m44-l05
title: Background tasks
description: "iOS suspends apps soon after they leave the screen, and gives background time back only on its own terms. You choose the right strategy for each kind of work, register BGAppRefreshTask and BGProcessingTask identifiers in the Info.plist, schedule requests with an earliest begin date, handle expiration and completion correctly, make scheduling decisions testable with an injected clock, hand long transfers to a background URLSession, and trigger tasks from the debugger the way Apple documents."
module: m44
order: 5
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m44-l04, m43-l02]
objectives:
  - Choose between finishing work with extra time, app refresh, processing tasks, background URL sessions, background pushes and continued processing.
  - Configure Background Modes and BGTaskSchedulerPermittedIdentifiers, and register launch handlers before launch finishes.
  - Schedule refresh and processing requests and explain what earliestBeginDate guarantees and what the pending-request limits are.
  - Handle a task's expiration and always call setTaskCompleted(success:).
  - Make background scheduling decisions testable by injecting the clock.
  - Use a background URLSession for transfers, and start and expire tasks from the debugger during development.
terms:
  - term: BGTaskScheduler
    definition: "The BackgroundTasks framework's scheduler. The app registers a launch handler per task identifier at launch and submits requests; the system decides when to launch the app in the background to run them."
  - term: BGAppRefreshTask
    definition: "A short task for refreshing content. Apple says the system gives the app up to 30 seconds of background runtime. Needs the Background fetch mode."
  - term: BGProcessingTask
    definition: "A task for maintenance or heavy processing that can run for minutes, only while the device is idle; it's terminated when the person starts using the device. Can require external power or network. Needs the Background processing mode."
  - term: earliestBeginDate
    definition: "The earliest time a task request may start. The system doesn't guarantee launching at that date, only that it won't begin sooner."
  - term: Expiration handler
    definition: "A closure on the BGTask that the system calls shortly before the task's background time runs out. It must cancel ongoing work quickly; the task must still call setTaskCompleted(success:)."
  - term: Background URL session
    definition: "A URLSession created with URLSessionConfiguration.background(withIdentifier:). A separate system process performs its transfers, which continue while the app is suspended or terminated, and the system relaunches the app to deliver results."
mastery:
  - Pick the strategy for a given job (finish saving, refresh prices, rebuild an index, download a catalog, react to a server event).
  - Write the Info.plist entries and the registration, scheduling and handling code for a refresh task.
  - Explain why the handler schedules the next request first and why expiration must lead to setTaskCompleted.
  - Trace a refresh planner with a fake clock through successes, failures with backoff, and a skipped launch.
  - Split long maintenance into checkpointed batches that survive expiration.
  - Predict the result of submitting requests against the one-refresh, ten-processing limit.
resources: [foundation-urlsessionconfiguration, foundation-urlsession, information-property-list, swift-task-cancellation-handler, swiftui-scenephase]
cards:
  - id: m44-l05-c1
    front: How much time does a BGAppRefreshTask get, and what must it do?
    back: "Apple: up to 30 seconds of background runtime. Do the work, then call setTaskCompleted(success:), or the system terminates the app. Set an expiration handler that cancels the work."
  - id: m44-l05-c2
    front: What two things does a background task need in the project before the code works?
    back: "The Background Modes capability with Background fetch (refresh) or Background processing (processing) checked, and each identifier in the Info.plist's BGTaskSchedulerPermittedIdentifiers array. register returns false for identifiers not in the list."
  - id: m44-l05-c3
    front: When must you register BGTaskScheduler launch handlers?
    back: "Before the end of the app's launch sequence (applicationDidFinishLaunching), every permitted identifier, each exactly once. The system kills the app on a second registration of the same identifier. An extension can schedule, but the app must register."
  - id: m44-l05-c4
    front: What does earliestBeginDate guarantee, and how many requests can be pending?
    back: "Only that the task won't start sooner; the system decides the actual time. At most 1 refresh task and 10 processing tasks can be pending; more fails with tooManyPendingTaskRequests. Submitting an identifier that's already pending replaces that request."
  - id: m44-l05-c5
    front: How do you start a background task during development?
    back: "On a device, pause in the debugger after submit(_:) and run: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"ID\"]. _simulateExpirationForTaskWithIdentifier: forces expiration. Private, development only."
---

## The idea in one sentence

Background time on iOS is **something you request and the system grants when it suits the device**, so background code is written as short, resumable jobs that schedule their successor, react to expiration, and report completion every time.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: "Choosing background strategies for your app", "Using background tasks to update your app", `BGTaskScheduler` and its `register` and `submit` methods, `BGAppRefreshTask`, `BGProcessingTask`, `BGProcessingTaskRequest`, `BGTask.expirationHandler` and `setTaskCompleted(success:)`, `earliestBeginDate`, `BGTaskSchedulerPermittedIdentifiers`, "Starting and terminating tasks during development", "Performing long-running tasks on iOS and iPadOS", SwiftUI's `backgroundTask(_:action:)`, and Foundation's "Downloading files in the background". The Xcode and debugger steps are quoted, not performed; no background task was run on a device. The BackgroundTasks, UIKit, SwiftUI and Foundation blocks are type-checked against the iOS SDK, not run. The planner, batching, pending-request and backoff models are plain Swift, compiled and run with Swift 6.3.

## Choosing a strategy

Module 21 described the life cycle: an app moved to the background is soon suspended, and a suspended app runs no code. Module 43 showed why the system is strict about it: energy. Apple's "Choosing background strategies for your app" lists the ways to get time back, and each fits a different job:

| Job | Strategy | What Apple says about time |
| --- | --- | --- |
| Finish saving or sending when the person leaves | `beginBackgroundTask(withName:expirationHandler:)` | "A limited amount of time"; call `endBackgroundTask(_:)` before it runs out, or the app is terminated |
| Refresh small content periodically | `BGAppRefreshTask` | "Up to 30 seconds of background runtime" |
| Maintenance, indexing, heavy processing | `BGProcessingTask` | "Can run for minutes," only while the device is idle |
| Upload or download files | Background `URLSession` | Transfers run in another process, even after the app is suspended |
| React to a server event | Background push (lesson 3) | "Up to 30 seconds"; rate-limited above about three per hour |
| A job the person started that must finish (an export) | `BGContinuedProcessingTask` (iOS 26) | Shows progress in a system Live Activity; the person can cancel it |

Pantry's jobs map like this: finishing a cart save when the person swipes away uses `beginBackgroundTask`; refreshing prices and the next delivery for the widget is an app refresh; compacting the local database and rebuilding the search index is a processing task; downloading the weekly catalog is a background session; "your order shipped" is a visible push, not background work.

One thing none of these offer is **a schedule**. You can't run every 15 minutes. You say "not before" and the system decides, based on usage, battery, network and how often your tasks run.

## Setting up the project

Two pieces of configuration, both from "Using background tasks to update your app" (quoted, not performed):

1. **Background Modes.** In Signing & Capabilities, add Background Modes and check "Background fetch" for `BGAppRefreshTask` and "Background processing" for `BGProcessingTask`. `BGAppRefreshTask`'s page: "Executing app refresh tasks requires setting the fetch `UIBackgroundModes` capability."
2. **Permitted identifiers.** In the Info.plist, add "Permitted background task scheduler identifiers" (`BGTaskSchedulerPermittedIdentifiers`), "an array of strings containing developer-specified task identifiers in reverse URL notation."

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.example.pantry.refresh</string>
    <string>com.example.pantry.maintenance</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

Apple adds that in iOS 13 and later, adding `BGTaskSchedulerPermittedIdentifiers` "disables the `application(_:performFetchWithCompletionHandler:)` and `setMinimumBackgroundFetchInterval(_:)` methods," the old background fetch API you'll find in older code.

## Registering, scheduling and handling

The rules for `register(forTaskWithIdentifier:using:launchHandler:)`, from its documentation:

- "Every identifier in the `BGTaskSchedulerPermittedIdentifiers` requires a handler. Registration of all launch handlers must be complete before the end of `applicationDidFinishLaunching(_:)`."
- "Register each task identifier only once. The system kills the app on the second registration of the same task identifier."
- It returns `false` "if the identifier isn't included in the `BGTaskSchedulerPermittedIdentifiers` Info.plist."
- "An extension can schedule a task, but your main app must register the task. The system launches the app to run the task."

And for the task itself: `expirationHandler` is "called shortly before the task's background time expires" and "may be called before the background process uses the full amount of its allocated time." Not setting one "results in the system marking your task as complete and unsuccessful." `setTaskCompleted(success:)`: "Not calling `setTaskCompleted(success:)` before the time for the task expires may result in the system killing your app."

Pantry's refresh, UIKit style:

```swift ios
import BackgroundTasks
import UIKit

enum TaskID {
    static let refresh = "com.example.pantry.refresh"
}

/// Asks for the next refresh. Submitting the same identifier replaces the pending request.
func scheduleAppRefresh(afterMinutes minutes: Double = 60) {
    let request = BGAppRefreshTaskRequest(identifier: TaskID.refresh)
    request.earliestBeginDate = Date(timeIntervalSinceNow: minutes * 60)
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule refresh: \(error)")
    }
}

/// Downloads prices and the next delivery into the App Group store. False on failure or cancellation.
func syncCartAndDeliveries() async -> Bool {
    if Task.isCancelled { return false }
    return true
}

/// One run of the refresh task. BGTask isn't Sendable; Apple's own sample uses it from the launch
/// handler, the expiration handler and the completion of the work, and so does this class.
final class RefreshRun: @unchecked Sendable {
    private let task: BGAppRefreshTask

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    func start() {
        let work = Task {
            let succeeded = await syncCartAndDeliveries()
            self.finish(success: succeeded && !Task.isCancelled)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }

    private func finish(success: Bool) {
        task.setTaskCompleted(success: success)
    }
}

func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: TaskID.refresh, using: nil) { task in
        guard let refresh = task as? BGAppRefreshTask else { return }
        scheduleAppRefresh()                // the next one first, whatever happens to this one
        RefreshRun(task: refresh).start()
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        registerBackgroundTasks()           // before launch finishes, once
        return true
    }
}
```

- **The next request is scheduled first.** Apple's sample does the same: if this run expires or crashes, the chain of refreshes doesn't stop. Pantry also calls `scheduleAppRefresh()` when the scene enters the background (Module 21's `sceneDidEnterBackground` or SwiftUI's `scenePhase`).
- **`earliestBeginDate` is a floor.** "The system doesn't guarantee launching the task at the specified date, but only that it won't begin sooner." Apple's own example uses 15 minutes; Pantry uses an hour because prices don't change faster than that.
- **Expiration cancels; completion reports.** The expiration handler only cancels the Swift task. The task notices (`Task.isCancelled`, or a `CancellationError` from `URLSession`), and `finish` still calls `setTaskCompleted(success: false)`. Calling it on every path is what keeps the app from being killed.
- **`@unchecked Sendable`** is a promise you make to the compiler. Here it's justified the same way Apple's sample is: the `BGTask` is touched from the system's queue and from the work's completion, never concurrently in a way that matters. Keep such wrappers tiny and say why in a comment, as Module 29 recommended.
- **`success`** tells the system whether the work did its job. Apple: "You can reschedule an unsuccessful required task." The next section decides how soon.

> [!version] submit(_:) in the iOS 27 SDK
> Apple's documentation marks `submit(_:)` as deprecated in iOS 27 and replaces it with `submitTaskRequest(_:)`, an `async throws` method (and a completion-handler variant) introduced in iOS 27. Apple warns not to call the new method "from the main thread or performance-critical contexts." The code here targets iOS 17 and type-checks with the iOS 26 SDK, where `submit(_:)` is current; when the project moves to iOS 27, adopt the new method behind `if #available(iOS 27, *)`. The iOS 27 method wasn't compiled for this lesson.

### The SwiftUI way

A SwiftUI app can attach the handler to its scene instead of registering it. SwiftUI's `backgroundTask(_:action:)`: "When the system wakes your app or extension for one or more background tasks, it will call any actions associated with matching tasks," and "the system considers the task completed when the action closure that you provide returns. If the action closure has not returned when the task runs out of time to complete, the system cancels the task." So expiration becomes ordinary Swift cancellation:

```swift ios
import BackgroundTasks
import SwiftUI

struct PantryScene: Scene {
    var body: some Scene {
        WindowGroup {
            Text("Pantry")
        }
        .backgroundTask(.appRefresh("com.example.pantry.refresh")) {
            scheduleNextRefresh()
            await refreshCart()
        }
    }
}

func scheduleNextRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.pantry.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

func refreshCart() async {
    await withTaskCancellationHandler {
        // Fetch prices and deliveries with URLSession; it throws CancellationError when cancelled.
    } onCancel: {
        // Runs immediately on expiration, on another thread. Keep it to signaling.
    }
}
```

In the real app `PantryScene`'s content is the app's `WindowGroup` and the struct is the `@main` `App`; it's a separate `Scene` here so the block can be type-checked. The identifier still has to be in `BGTaskSchedulerPermittedIdentifiers`, and the Background fetch mode still has to be on. Apple's documentation for the modifier doesn't spell out how it interacts with your own `register` calls, so pick one approach per identifier.

## Deciding when to sync, with an injected clock

When a refresh launches, the app decides: sync now, or skip because the data is fresh (the person had the app open five minutes ago)? And after a run, what's the next `earliestBeginDate`? Module 43 gave Apple's backoff rule: "if your first refresh task fails, set the `earliestBeginDate` on the first retry 5 minutes later. If that fails, wait 10 minutes before retrying, then 20 minutes, and so on."

These decisions depend on "now", and code that calls `Date()` inside can only be tested by waiting. Pantry passes the time in, the dependency-injection idea from Modules 32 and 37 applied to the clock:

```swift
/// Anything that can tell the time, in minutes. The app uses the real clock; tests use a fake one.
protocol TimeSource: AnyObject {
    var now: Int { get }
}

final class TestTime: TimeSource {
    var now = 0
}

struct RefreshPlanner {
    let time: any TimeSource
    var lastSuccess: Int?
    var consecutiveFailures = 0

    let normalInterval = 60        // Pantry's choice
    let freshEnough = 15           // skip a background sync if the data is this recent
    let maximumDelay = 6 * 60

    /// The system launched the refresh task: is a sync worth doing?
    func shouldSync() -> Bool {
        guard let lastSuccess else { return true }
        return time.now - lastSuccess >= freshEnough
    }

    mutating func record(success: Bool) {
        if success {
            lastSuccess = time.now
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
        }
    }

    /// The earliestBeginDate for the next request: normal interval, or Apple's 5, 10, 20... backoff.
    func nextEarliestBegin() -> Int {
        guard consecutiveFailures > 0 else { return time.now + normalInterval }
        var delay = 5
        for _ in 1..<consecutiveFailures {
            delay *= 2
            if delay >= maximumDelay { return time.now + maximumDelay }
        }
        return time.now + delay
    }
}

let time = TestTime()
var planner = RefreshPlanner(time: time)

// "bg ok" and "bg fail" are background launches; "app" is the person opening Pantry, which syncs
// in the foreground and leaves the pending request alone.
let script: [(Int, String)] = [(0, "bg ok"), (65, "bg fail"), (72, "bg fail"), (85, "bg ok"), (140, "app"), (150, "bg ok"), (215, "bg ok")]
for (minute, event) in script {
    time.now = minute
    if event == "app" {
        planner.record(success: true)
        print(minute, "app synced in foreground")
        continue
    }
    guard planner.shouldSync() else {
        print(minute, "fresh enough, skipped; next ≥", planner.nextEarliestBegin())
        continue
    }
    planner.record(success: event == "bg ok")
    print(minute, (event == "bg ok" ? "synced" : "sync failed") + "; next ≥", planner.nextEarliestBegin())
}
```

```output
0 synced; next ≥ 60
65 sync failed; next ≥ 70
72 sync failed; next ≥ 82
85 synced; next ≥ 145
140 app synced in foreground
150 fresh enough, skipped; next ≥ 210
215 synced; next ≥ 275
```

- **The fake clock is a class** so the test can move time forward and the planner sees it. In the app, a `SystemTime` returns minutes from `Date()`; nothing else changes. Swift's own `Clock` protocol (`ContinuousClock`, Module 29) measures durations for sleeping and timing; this one answers "what time is it", so it gets a different name.
- **Each launch comes at or after the previous "next ≥"**: the system honors the floor and picks its own moment after it.
- **Two failures back off to 5 and then 10 minutes**, and a success resets to the normal hour.
- **The launch at 150 is skipped.** The person opened Pantry at 140 and the foreground sync is ten minutes old. The task still completes promptly (with `success: true`, since there was nothing to do) and schedules the next one. Spending the person's battery and data on a duplicate download is exactly what the system's budget punishes.
- `lastSuccess` and `consecutiveFailures` must be persisted (`UserDefaults` is fine): between background launches the process is usually gone.

## Processing tasks

`BGProcessingTask` is for work that's heavy but not urgent. From its documentation: "Processing tasks run only when the device is idle. The system terminates any background processing tasks running when the user starts using the device." The request can add conditions:

```swift ios
import BackgroundTasks
import Foundation

func scheduleMaintenance() {
    let request = BGProcessingTaskRequest(identifier: "com.example.pantry.maintenance")
    request.requiresExternalPower = true            // compaction is CPU and disk heavy
    request.requiresNetworkConnectivity = false
    request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule maintenance: \(error)")
    }
}
```

Because the person picking up the phone ends the task, maintenance has to be **resumable**: do it in batches, save a checkpoint after each, and stop cleanly when time runs out.

```swift
struct MaintenanceJob {
    let totalBatches: Int
    var checkpoint = 0              // persisted, so the next run resumes here

    /// Runs batches until done or until `isExpired()` says time is up. Returns true when finished.
    mutating func run(isExpired: () -> Bool) -> Bool {
        while checkpoint < totalBatches {
            if isExpired() { return false }
            checkpoint += 1         // process one batch, then save progress
        }
        return true
    }
}

var job = MaintenanceJob(totalBatches: 10)
for (run, budget) in [4, 3, 10].enumerated() {
    var batchesLeft = budget
    let finished = job.run(isExpired: {
        if batchesLeft == 0 { return true }
        batchesLeft -= 1
        return false
    })
    print("run \(run + 1): checkpoint \(job.checkpoint)/\(job.totalBatches)", finished ? "done" : "expired, reschedule")
}
```

```output
run 1: checkpoint 4/10 expired, reschedule
run 2: checkpoint 7/10 expired, reschedule
run 3: checkpoint 10/10 done
```

- **Nothing is redone.** The second run starts at batch 5, because the checkpoint is saved after every batch, not at the end.
- **The check happens between batches**, so a batch must be short: a few hundred rows, one index segment. In the app, `isExpired` reads a flag the expiration handler sets (or `Task.isCancelled`).
- **An expired run reports `success: false`** and resubmits the request; a finished one reports `true` and schedules the next maintenance for days later.

### Pending-request limits

`submit(_:)` documents two rules: "Submitting a task request for an unexecuted task that's already in the queue replaces the previous task request," and "there can be a total of 1 refresh task and 10 processing tasks scheduled at any time. Trying to schedule more tasks returns `tooManyPendingTaskRequests`." With one refresh identifier that you resubmit, you never hit the first limit. The solve exercise models both rules.

## Background URL sessions

For transfers, don't hold a task open: hand the transfer to the system. From "Downloading files in the background": create a session with `URLSessionConfiguration.background(withIdentifier:)`; keep `sessionSendsLaunchEvents` true (the default) so the system wakes the app when a transfer finishes; set `isDiscretionary` for transfers that can wait for Wi-Fi and power; and set `countOfBytesClientExpectsToSend` and `countOfBytesClientExpectsToReceive` "to help the system schedule network activity efficiently."

```swift ios
import Foundation

final class CatalogDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let sessionID = "com.example.pantry.catalog"
    static let shared = CatalogDownloader()

    /// Created once per launch with the same identifier, so a relaunched app reconnects to its transfers.
    private(set) lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func downloadCatalog(from url: URL) {
        let task = session.downloadTask(with: url)
        task.countOfBytesClientExpectsToSend = 200
        task.countOfBytesClientExpectsToReceive = 5 * 1024 * 1024
        task.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The file at `location` is only guaranteed to exist until this method returns: move it now.
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let destination = caches.appendingPathComponent("catalog.json")
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: location, to: destination)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            print("Catalog download failed: \(error)")
        }
    }
}
```

When a transfer finishes while the app is suspended or terminated, the system relaunches it in the background and calls the app delegate's `application(_:handleEventsForBackgroundURLSession:completionHandler:)`. The app recreates the session with the same identifier, stores the completion handler, and calls it on the main queue from `urlSessionDidFinishEvents(forBackgroundURLSession:)` once all events are delivered. Apple's article has the code; as a fragment of an app delegate it's shown, not compiled:

```swift illustrative
func application(_ application: UIApplication,
                 handleEventsForBackgroundURLSession identifier: String,
                 completionHandler: @escaping () -> Void) {
    backgroundCompletionHandler = completionHandler      // stored until the session finishes
    _ = CatalogDownloader.shared.session                 // reconnect to the transfers
}

// In the session delegate:
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
        appDelegate.backgroundCompletionHandler?()
        appDelegate.backgroundCompletionHandler = nil
    }
}
```

SwiftUI offers the same hook as `.backgroundTask(.urlSession(CatalogDownloader.sessionID))`. The limits Apple lists for background sessions: a delegate is required, "only HTTP and HTTPS protocols are supported," redirects are always followed, and "only upload tasks from a file are supported." And a warning about chaining: the system rate-limits relaunches, and the delay "increases each time the system resumes or relaunches your app," so starting one download after another from the background gets slower each time. Start many tasks in one session instead. A session can also download straight into the App Group container with `sharedContainerIdentifier`, so the widget sees the file (lesson 1).

## Testing in the debugger

Waiting for the system is impractical: Apple notes the delay "can be many hours." "Starting and terminating tasks during development" gives two private debugger commands, which "work only on devices" (quoted, not run for this lesson):

1. Set a breakpoint after a successful `submit(_:)` and run the app on a device until it pauses.
2. To launch the task, run in the debugger console:

```text
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.pantry.refresh"]
```

3. Resume. "The system calls the launch handler for the desired task."
4. To test expiration, pause inside the running task and run:

```text
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.example.pantry.refresh"]
```

Apple: "Use private functions only during development. Including a reference to these functions in apps submitted to the App Store is cause for rejection." They live only in the debugger session, never in code. Test with Background App Refresh turned off in Settings too: the app must behave sensibly when refresh never happens, which is why the planner in this lesson treats every background launch as a bonus, not a guarantee.

## Common mistakes

> [!error] Forgetting setTaskCompleted on one path
> An early `return` in the error branch, or a cancelled task that never reports, leaves the task open until the system kills the app. Every path ends in `setTaskCompleted(success:)`, including expiration.

> [!error] Registering late
> Registering in the first view's `onAppear` or after an `await` misses the end of launch. The system launched the app for the task, and no handler is there for it.

> [!error] Expecting a schedule
> `earliestBeginDate = now + 15 minutes` doesn't mean every 15 minutes. It means "not before". Design for runs hours apart, or not at all with Background App Refresh off.

> [!error] Tight retry loops
> Rescheduling a failed refresh for "now" asks the system to wake the device repeatedly. Back off: 5, 10, 20 minutes, as Apple describes.

> [!error] Long work in a refresh task
> A catalog download or database compaction in a 30-second refresh task gets expired every time. Use a background session or a processing task, and make the work resumable.

> [!error] Shipping the debugger commands
> The `_simulateLaunchForTaskWithIdentifier:` selector in code is a private API reference and grounds for rejection. Type it in the debugger only.

## Exercises

````exercise
id: m44-l05-e1
type: prediction
prompt: "A loop that adds each run's delay to a running clock. What does it print?"
code: |
  func delay(afterFailures failures: Int) -> Int {
      guard failures > 0 else { return 60 }
      var minutes = 5
      for _ in 1..<failures {
          minutes *= 2
          if minutes >= 360 { return 360 }
      }
      return minutes
  }

  var now = 0
  var failures = 0
  for succeeded in [false, false, true, false] {
      failures = succeeded ? 0 : failures + 1
      now += delay(afterFailures: failures)
      print(now)
  }
  print(delay(afterFailures: 7))
output: |
  5
  15
  75
  80
  320
hints:
  - "The first failure waits 5 minutes, the second 10."
  - "A success resets the count, so the next delay is the normal 60."
solution: |
  ```output
  5
  15
  75
  80
  320
  ```

  - Fail: 1 failure, +5 → 5. Fail: 2 failures, +10 → 15.
  - Success: count resets, +60 → 75.
  - Fail: back to 1 failure, +5 → 80. The backoff starts over after a success.
  - Seven failures: 5 × 2⁶ = 320, still under the 360 cap. An eighth would hit the cap.
````

````exercise
id: m44-l05-e2
type: comprehension
prompt: "Pantry needs to rebuild its local search index after a catalog update. It takes about 3 minutes of CPU on an older phone and isn't urgent. Which strategy fits?"
choices:
  - text: "A BGProcessingTask, with requiresExternalPower and work split into checkpointed batches."
    correct: true
    why: "Processing tasks can run for minutes while the device is idle, and can wait for power. Batches survive the person picking up the phone."
  - text: "A BGAppRefreshTask scheduled every 15 minutes until it finishes."
    correct: false
    why: "Refresh tasks get up to 30 seconds, and rescheduling every 15 minutes doesn't make them run more often."
  - text: "beginBackgroundTask when the app goes to the background."
    correct: false
    why: "That's for finishing work in progress, with a limited amount of time; 3 minutes of indexing isn't that."
  - text: "A background push every few minutes to wake the app."
    correct: false
    why: "Background pushes give 30 seconds, aren't guaranteed, and Apple says two or three per hour at most."
solution: |
  Heavy, deferrable work is what `BGProcessingTask` is for: "long data updates, processing data, and app maintenance." It runs only while the device is idle, and is terminated when the person starts using it, so the index rebuild must save progress between batches and resume. Requiring external power keeps a 3-minute CPU job off the battery.
````

````exercise
id: m44-l05-e3
type: fill-in
prompt: "Complete the registration and the handler."
code: |
  // In the Info.plist array [[1]]: "com.example.pantry.refresh"

  BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.pantry.refresh", using: nil) { task in
      guard let refresh = task as? BGAppRefreshTask else { return }
      scheduleAppRefresh()
      let work = Task {
          let ok = await syncCartAndDeliveries()
          refresh.[[2]](success: ok)
      }
      refresh.[[3]] = { work.cancel() }
  }

  let request = BGAppRefreshTaskRequest(identifier: "com.example.pantry.refresh")
  request.[[4]] = Date(timeIntervalSinceNow: 60 * 60)
blanks:
  - id: "1"
    answers: ["BGTaskSchedulerPermittedIdentifiers"]
  - id: "2"
    answers: ["setTaskCompleted"]
  - id: "3"
    answers: ["expirationHandler"]
  - id: "4"
    answers: ["earliestBeginDate"]
solution: |
  - `BGTaskSchedulerPermittedIdentifiers` lists every identifier; `register` returns false for others.
  - `setTaskCompleted(success:)` on every path.
  - `expirationHandler` cancels the work when time runs out; the cancelled work still reaches `setTaskCompleted`.
  - `earliestBeginDate` is "not before", not "at".

  This compact version captures `refresh` in the `Task` closure. `BGAppRefreshTask` isn't documented as `Sendable`, and Swift 6 checks what a `Task` closure captures, so the lesson's `RefreshRun` wrapper keeps the task out of that closure. The blanks are the same either way.
````

````exercise
id: m44-l05-e4
type: find-errors
prompt: "An old Pantry branch. Mark every real problem."
code: |
  struct ContentView: View {
      var body: some View {
          List { /* ... */ }
              .onAppear {
                  BGTaskScheduler.shared.register(forTaskWithIdentifier: "refresh", using: nil) { task in
                      Task {
                          guard let data = try? await downloadCatalog() else { return }
                          save(data)
                          task.setTaskCompleted(success: true)
                      }
                  }
                  let request = BGAppRefreshTaskRequest(identifier: "refresh")
                  request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
                  try? BGTaskScheduler.shared.submit(request)
              }
      }
  }
choices:
  - text: "Registering in onAppear is after launch finishes, and onAppear can run more than once, registering the same identifier twice."
    correct: true
  - text: "The failure path returns without calling setTaskCompleted, and there's no expiration handler."
    correct: true
  - text: "A full catalog download is too long for a refresh task's up to 30 seconds."
    correct: true
  - text: "The handler doesn't schedule the next refresh, so the chain stops after one run."
    correct: true
  - text: "earliestBeginDate of 60 seconds is rejected by the system."
    correct: false
    why: "It's allowed; it's just a floor, and the system will choose a later time anyway."
rubric:
  - I flagged the late and repeated registration.
  - I flagged the missing completion and expiration handling.
  - I flagged the long work in a refresh task.
  - I flagged the missing reschedule.
solution: |
  - **Registration** belongs in `didFinishLaunching` (or the scene's `backgroundTask` modifier), exactly once. A second registration of the same identifier kills the app.
  - **Completion:** every path calls `setTaskCompleted`; set `expirationHandler` to cancel the download.
  - **Work size:** download the catalog with a background `URLSession`; the refresh task only checks whether a new catalog exists and starts that download.
  - **Chain:** call `scheduleAppRefresh()` at the start of the handler. The identifier should also be reverse-DNS (`com.example.pantry.refresh`) and listed in the Info.plist.
````

````exercise
id: m44-l05-e5
type: solve
prompt: |
  Model `BGTaskScheduler`'s documented pending-request rules. Write `submit(_:kind:)`: if the identifier is already pending, replace it and return `.replaced`; otherwise, if there are already 1 pending refresh requests (for `.refresh`) or 10 pending processing requests (for `.processing`), return `.tooManyPendingTaskRequests`; otherwise store it and return `.scheduled`. `run(_:)` removes a request, as if the system ran it.

  Expected output:

  ```output
  scheduled
  replaced
  tooManyPendingTaskRequests
  tooManyPendingTaskRequests
  scheduled
  11
  ```
starter: |
  enum Kind {
      case refresh, processing
  }

  enum SubmitResult: Equatable {
      case scheduled
      case replaced
      case tooManyPendingTaskRequests
  }

  struct PendingRequests {
      private(set) var pending: [String: Kind] = [:]

      mutating func submit(_ identifier: String, kind: Kind) -> SubmitResult {
          // your code
          return .scheduled
      }

      mutating func run(_ identifier: String) {
          pending[identifier] = nil
      }
  }

  var scheduler = PendingRequests()
  print(scheduler.submit("refresh", kind: .refresh))
  print(scheduler.submit("refresh", kind: .refresh))
  print(scheduler.submit("refresh-images", kind: .refresh))
  for index in 1...10 {
      _ = scheduler.submit("cleanup-\(index)", kind: .processing)
  }
  print(scheduler.submit("cleanup-11", kind: .processing))
  scheduler.run("cleanup-3")
  print(scheduler.submit("cleanup-11", kind: .processing))
  print(scheduler.pending.count)
hints:
  - "Check for replacement before checking the limit: replacing doesn't add a request."
  - "Count pending requests of the same kind only."
rubric:
  - Resubmitting a pending identifier replaces it even when the limit is reached.
  - Applies 1 for refresh and 10 for processing, per kind.
  - A request that ran frees a slot.
solution: |
  ```swift
  enum Kind {
      case refresh, processing
  }

  enum SubmitResult: Equatable {
      case scheduled
      case replaced
      case tooManyPendingTaskRequests
  }

  struct PendingRequests {
      private(set) var pending: [String: Kind] = [:]

      mutating func submit(_ identifier: String, kind: Kind) -> SubmitResult {
          if pending[identifier] != nil {
              pending[identifier] = kind
              return .replaced
          }
          let limit = kind == .refresh ? 1 : 10
          let sameKind = pending.values.filter { $0 == kind }.count
          guard sameKind < limit else { return .tooManyPendingTaskRequests }
          pending[identifier] = kind
          return .scheduled
      }

      mutating func run(_ identifier: String) {
          pending[identifier] = nil
      }
  }

  var scheduler = PendingRequests()
  print(scheduler.submit("refresh", kind: .refresh))
  print(scheduler.submit("refresh", kind: .refresh))
  print(scheduler.submit("refresh-images", kind: .refresh))
  for index in 1...10 {
      _ = scheduler.submit("cleanup-\(index)", kind: .processing)
  }
  print(scheduler.submit("cleanup-11", kind: .processing))
  scheduler.run("cleanup-3")
  print(scheduler.submit("cleanup-11", kind: .processing))
  print(scheduler.pending.count)
  ```

  ```output
  scheduled
  replaced
  tooManyPendingTaskRequests
  tooManyPendingTaskRequests
  scheduled
  11
  ```

  The second refresh replaces the first; a different refresh identifier fails because only one refresh can be pending. That's the practical lesson: use **one** refresh identifier and do everything periodic in it. Processing requests fill up at 10, and a run frees a slot. 11 = 1 refresh + 10 processing.
````

````exercise
id: m44-l05-e6
type: design
prompt: "Design Pantry's background work for the features in this module: the next-delivery widget (lesson 1), the delivery Live Activity (lesson 2), restock reminders (lesson 3), and an offline catalog of 20 MB updated weekly. For each, say which mechanism keeps it current, what triggers it, and what happens if background time never comes."
rubric:
  - Uses one app refresh task (with backoff and a freshness check) for small data like deliveries and widget content, and reloads widgets only when content changes.
  - Uses pushes for the Live Activity rather than background tasks, and visible pushes for what must arrive.
  - Schedules reminders as local notifications, reconciled whenever the app runs, rather than computing them in background tasks.
  - Uses a discretionary background URLSession (into the App Group if the widget needs it) for the catalog, and a processing task for indexing; everything degrades gracefully with background refresh off.
solution: |
  - **Widget and deliveries:** one `BGAppRefreshTask` (`com.example.pantry.refresh`), hourly with the planner's freshness check and backoff. It writes to the App Group store and calls `reloadTimelines(ofKind:)` only for kinds whose content changed. The app also refreshes in the foreground. If refresh never runs, the widget's timeline still covers the known windows, and `.never` waits for the app.
  - **Live Activity:** ActivityKit pushes with the activity's token, priority 5 for progress and 10 for important changes. No background task can update it reliably during a delivery. Without push, the app updates it when opened.
  - **Restock reminders:** local notifications scheduled in advance, reconciled (lesson 3) on every launch and data change. They fire whether or not the app ever runs in the background.
  - **Catalog:** a discretionary background `URLSession` download, started from the refresh task when the server says a new catalog exists, written to Caches. A `BGProcessingTask` with external power rebuilds the search index in checkpointed batches. Without background time, the download starts the next time the app is opened and the index rebuilds then, with a progress state in the UI.
  - **Testing:** the planner and the reconciliation with a fake clock; the handlers on a device with the debugger's simulate-launch and simulate-expiration commands; a day with Background App Refresh off.
````

## Summary

- Choose by job: `beginBackgroundTask` to finish what's in progress, `BGAppRefreshTask` for small periodic updates (up to 30 seconds), `BGProcessingTask` for heavy idle-time work (minutes, ended when the person uses the device), a background `URLSession` for transfers, pushes for server events, and `BGContinuedProcessingTask` (iOS 26) for jobs the person started.
- Configure Background Modes (fetch, processing) and list every identifier in `BGTaskSchedulerPermittedIdentifiers`. Register each handler once, before launch finishes; the app registers even if an extension schedules.
- `earliestBeginDate` is a floor, not a schedule. At most 1 refresh and 10 processing requests can be pending; resubmitting an identifier replaces it. `submit(_:)` is deprecated in the iOS 27 SDK in favor of `submitTaskRequest(_:)`.
- In the handler, schedule the next request first, set an expiration handler that cancels the work, and call `setTaskCompleted(success:)` on every path. SwiftUI's `backgroundTask(_:action:)` turns expiration into task cancellation.
- Inject the clock to test scheduling decisions: skip syncs when data is fresh, back off 5, 10, 20 minutes on failure, and reset on success. Make long work resumable with checkpoints.
- Background sessions need a delegate, HTTP(S), file-based uploads, and the app's completion handler after relaunch; avoid chaining single downloads. Test on a device with the debugger's `_simulateLaunchForTaskWithIdentifier:` and `_simulateExpirationForTaskWithIdentifier:` commands, which must never ship in code.
