---
id: m43-l01
title: Measuring before optimizing
description: "Performance work on an existing app starts with numbers, not hunches. You write budgets based on Apple's documented thresholds, summarize samples with percentiles instead of averages, follow a launch through the phases Apple describes and decide what leaves didFinishLaunching, lock in launch time, memory and signposted intervals with XCTest metrics, read the same measurements from real devices with MetricKit, and write a small benchmark harness that compares two implementations without printing timings."
module: m43
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l06, m39-l05, m33-l06]
objectives:
  - Write a performance budget for an app's key interactions, tying each number to an Apple threshold or labeling it as the team's choice.
  - Summarize timing samples with nearest-rank percentiles and explain why the mean hides the launches people complain about.
  - Describe the launch phases and activation types Apple documents, and move non-essential work out of the launch path.
  - Measure launch, memory, CPU and signposted intervals in UI tests with XCTest metrics, configured the way Apple recommends.
  - Read launch, hang and memory histograms from MetricKit and compute percentiles from histogram buckets.
  - Benchmark two implementations in plain Swift with ContinuousClock, warm-up runs and a median.
terms:
  - term: Performance budget
    definition: "An agreed limit for a measurable interaction (\"search results appear within 100 ms at p95 on the oldest supported device\"), checked in tests and in field data, so a regression fails a check instead of slipping into a release."
  - term: Nearest-rank percentile
    definition: "The smallest sample such that at least p percent of the samples are less than or equal to it. p50 is the typical experience; p90 and p95 describe the slow tail."
  - term: Time to first frame
    definition: "What Xcode Organizer and MetricKit call launch time: from the tap on the icon to the app drawing its first frame, including the time to draw that frame's views."
  - term: Extended launch
    definition: "Work after the first frame that the person still waits for. You mark it with MXMetricManager.extendLaunchMeasurement(forTaskID:) (iOS 16) so MetricKit and XCTApplicationLaunchMetric include it."
  - term: XCTMetric
    definition: "The protocol behind XCTest's measurement types: XCTClockMetric, XCTCPUMetric, XCTMemoryMetric, XCTStorageMetric, XCTOSSignpostMetric, XCTApplicationLaunchMetric and, from iOS 26, XCTHitchMetric."
mastery:
  - Compute p50, p90 and p95 of a sample by hand and with code, and explain a gap between p50 and p95.
  - Turn Apple's 100 ms and 5 ms guidance into budget rows for a real screen.
  - List what Pantry's app delegate should do at launch and what it should defer.
  - Write a UI test that measures launch until the app is responsive and a signposted interval.
  - Compute p50 and p90 from MetricKit-style histogram buckets.
  - Compare two implementations with a harness whose output doesn't depend on the machine's speed.
resources: [xcode-improving-performance, xcode-performance-tests, understanding-hangs, uikit-app-launch-sequence, os-ossignposter, metrickit, swift-clock, xctest]
cards:
  - id: m43-l01-c1
    front: Which numbers does Apple give for responsiveness budgets?
    back: "A discrete interaction delay over 100 ms becomes noticeable (assume less than half of it is available to your main thread); code that runs during continuous interaction, like data source methods, should stay around 5 ms; a frame is 8.3 ms at 120 Hz and 16.7 ms at 60 Hz. Apple's launch article gives no target number: it tells you to measure and reduce."
  - id: m43-l01-c2
    front: Why report p50 and p90 or p95 instead of the mean?
    back: "Timing distributions have long tails (cold launches, busy devices). A few slow samples move the mean without describing anyone's experience. p50 is the typical case and p90/p95 the slow tail; Xcode Organizer's launch pane shows the 50th and 90th percentiles."
  - id: m43-l01-c3
    front: What ends Apple's launch time measurement?
    back: "The first frame the app draws (time to first frame), including drawing that frame's views. Work after it, like loading the document the person opened, isn't counted unless you mark it as extended launch with MXMetricManager.extendLaunchMeasurement(forTaskID:)."
  - id: m43-l01-c4
    front: How should a performance test scheme be configured, according to Apple?
    back: "Build for testing with the Release configuration, turn off Debug executable, and disable code coverage and sanitizers in the test plan. XCTest runs the block iterationCount + 1 times and ignores the first iteration."
  - id: m43-l01-c5
    front: What makes a benchmark's output safe to check in a test?
    back: "It prints derived facts (the two implementations agree; B is at least 10x faster) rather than durations, uses a monotonic clock (ContinuousClock), warms up first, and takes the median of several runs."
---

## The idea in one sentence

Before you change a line for speed, **decide what "fast enough" means as a number, measure it the same way in the lab and in the field, and keep the measurement as a test** so the fix can't quietly regress.

> [!note] Sources and what was checked
> Thresholds and workflow come from Apple's "Improving app responsiveness", "Understanding hangs in your app", "Reducing your app's launch time", "Writing and running performance tests", "Analyzing responsiveness issues in your shipping app", and the reference pages for `XCTApplicationLaunchMetric`, `XCTClockMetric`, `XCTMemoryMetric`, `XCTOSSignpostMetric`, `XCTMeasureOptions`, `MXAppLaunchMetric`, `MXAppResponsivenessMetric`, `MXHistogram` and `MXMetricManager`, all read in November 2026. Xcode Organizer and Instruments weren't opened for this lesson; what's said about their panes is Apple's description. The UIKit, OSLog and MetricKit blocks are type-checked against the iOS SDK, not run. The XCTest blocks are marked illustrative: they come from Apple's documented API but weren't compiled, because the snippet harness can't build a UI test target. The percentile, budget, histogram and benchmark code is plain Swift, compiled and run with Swift 6.3; its sample numbers are invented.

## The app

This module works on **Pantry**, a grocery app that's been in the App Store for six years: a UIKit shell with a product catalog, image grid, cart and checkout, a few SwiftUI screens added during the migration from Module 40, three Swift packages, and a team that ships every two weeks. Nobody wrote it with performance, accessibility or a third language in mind. That's the normal case, and the reason this module exists.

The product manager's complaint is "the app feels slow." That sentence can't be fixed. The rest of this lesson turns it into numbers that can.

## Budgets you can defend

A **performance budget** is a limit for one measurable interaction, on a named device class, at a named percentile. Apple's documentation gives a few thresholds to anchor them:

| Apple's guidance | Source |
| --- | --- |
| "If a delay in discrete user interaction becomes longer than 100 ms, it starts to become noticeable and causes a hang." Assume "less than half that time is available for your app's main thread." | Improving app responsiveness |
| Code that runs during continuous interaction, "like table and collection view data source methods, must finish much more quickly. Consider using a limit of 5 ms for such code." | Improving app responsiveness |
| A new frame "as often as 120 times per second, or every 8.3 ms," or every 16.7 ms at 60 Hz. | Improving app responsiveness |
| "Most of Apple's developer tools start reporting issues when the period of unresponsiveness for the main run loop exceeds 250 ms." | Understanding hangs in your app |

There's one number Apple's launch article doesn't give: a target launch time. It says a slow launch frustrates people, that "on iOS, the watchdog will terminate it if it takes too long," and that you should measure and reduce. Any launch budget is therefore **the team's choice**, and the budget table should say so. Pantry's:

| Interaction | Percentile | Budget | Where the number comes from |
| --- | --- | --- | --- |
| Launch, time to first frame | p90 | 500 ms | Team choice, from today's field data |
| Search results after a keystroke | p95 | 100 ms | Apple's discrete-interaction threshold |
| Configuring a catalog cell | p95 | 5 ms | Apple's continuous-interaction guidance |
| Checkout "Place order" to spinner | p95 | 100 ms | Apple's discrete-interaction threshold |

Each budget names a **device**, too: Pantry measures on the oldest iPhone its deployment target supports, because Apple's hitch guidance recommends "older devices that your app supports to make it easier to find issues."

## Percentiles, not averages

Twenty launches of Pantry on that device, in milliseconds:

```swift
/// Nearest-rank percentile: the smallest sample that at least p percent of samples don't exceed.
func percentile(_ p: Int, of samples: [Int]) -> Int? {
    guard !samples.isEmpty, (1...100).contains(p) else { return nil }
    let sorted = samples.sorted()
    let rank = (p * sorted.count + 99) / 100      // ceil(p / 100 × n) in integer math
    return sorted[rank - 1]
}

// Time to first frame from 20 launches on the oldest supported device, in milliseconds.
let launches = [412, 398, 405, 1_240, 401, 395, 420, 408, 399, 2_310,
                404, 410, 396, 403, 415, 407, 1_180, 402, 400, 409]

print("mean:", launches.reduce(0, +) / launches.count)
print("p50:", percentile(50, of: launches)!)
print("p90:", percentile(90, of: launches)!)
print("p95:", percentile(95, of: launches)!)
print("max:", launches.max()!)
```

```output
mean: 580
p50: 405
p90: 1180
p95: 1240
max: 2310
```

- **The mean, 580 ms, describes no launch at all.** Seventeen launches took about 400 ms and three took more than a second. The average blends them into a number nobody experienced.
- **p50 is the typical launch; p90 and p95 are the slow tail.** Those three slow launches are the cold ones Apple's launch article describes: after a reboot, or after a memory-hungry app pushed Pantry and its frameworks out of memory. They're real users, not noise.
- **Nearest rank** picks an actual sample: with 20 samples, p90 is the 18th smallest. Other definitions interpolate between samples; pick one and use it everywhere, so a change in the number means a change in the app.
- Integer math keeps the example portable. `(p * n + 99) / 100` is the ceiling of `p × n / 100` for positive values.

This is also how Apple reports field data: the Organizer's launch pane shows "the typical (50th percentile) and longest (90th percentile) times," and the hang rate is shown as "the median hang rate of a typical user experience, and the extreme 90th percentile."

### Checking budgets in code

Once the budget is data, checking it is a loop. In Pantry's CI, a script collects samples from performance tests and runs a check like this:

```swift
struct Budget {
    let metric: String
    let percentile: Int
    let limitMilliseconds: Int
}

func percentile(_ p: Int, of samples: [Int]) -> Int? {
    guard !samples.isEmpty, (1...100).contains(p) else { return nil }
    let sorted = samples.sorted()
    return sorted[(p * sorted.count + 99) / 100 - 1]
}

func check(_ budgets: [Budget], against samples: [String: [Int]]) -> [String] {
    budgets.map { budget in
        guard let values = samples[budget.metric],
              let value = percentile(budget.percentile, of: values) else {
            return "MISSING \(budget.metric)"
        }
        let verdict = value <= budget.limitMilliseconds ? "PASS" : "FAIL"
        return "\(verdict) \(budget.metric): p\(budget.percentile) = \(value) ms, budget \(budget.limitMilliseconds) ms"
    }
}

let budgets = [
    Budget(metric: "launch.firstFrame", percentile: 90, limitMilliseconds: 500),
    Budget(metric: "search.results", percentile: 95, limitMilliseconds: 100),
    Budget(metric: "cell.configure", percentile: 95, limitMilliseconds: 5),
    Budget(metric: "checkout.submit", percentile: 95, limitMilliseconds: 100),
]
let samples: [String: [Int]] = [
    "launch.firstFrame": [430, 410, 455, 610, 420, 440, 415, 425, 435, 450],
    "search.results": [38, 41, 44, 39, 120, 40, 42, 43, 37, 45],
    "cell.configure": [1, 2, 1, 1, 3, 1, 2, 1, 1, 2],
]
for line in check(budgets, against: samples) { print(line) }
```

```output
PASS launch.firstFrame: p90 = 455 ms, budget 500 ms
FAIL search.results: p95 = 120 ms, budget 100 ms
PASS cell.configure: p95 = 3 ms, budget 5 ms
MISSING checkout.submit
```

- **Search fails on one sample out of ten.** With ten samples, p95 is the largest one. That's harsh, and deliberate: if one search in ten takes 120 ms on the reference device, someone will see it. Collect more samples before you relax a budget, not after.
- **A missing metric is reported, not skipped.** A budget nobody measures is a wish. Treating "no data" as a failure keeps the test that feeds it from being deleted quietly.

## Launch: what's measured and what you control

Apple's launch article separates a few ideas you need before reading any launch number:

- **Activation** is when someone taps the icon or returns to the app. On iOS it's either a **launch** (the process has to start) or a **resume** (a process already existed, even suspended). Resumes are "generally much faster," and MetricKit reports them separately.
- **Warm and cold** are ends of a spectrum. Returning right after leaving is warm. After a reboot, or after "a memory-intensive game," the app and the frameworks it uses may need "re-launching and paging in from disk." That's the p90 tail above.
- **What's measured:** "Xcode Organizer and MetricKit both use the time to first frame as the measurement of launch time, including the time required to draw the views that are displayed on that first frame." The launch screen storyboard doesn't stop the clock.

Where the time goes, in the order the system spends it:

1. **Before `main()`.** The dynamic loader loads your executable and every framework it links; "each additional third-party framework that your app loads adds to the launch time." Static initializers (C++ constructors, Objective-C `+load`, `__attribute__((constructor))`) run here too. Apple suggests fewer embedded frameworks, mergeable libraries (Xcode 15), and moving initializer work later.
2. **App delegate.** `application(_:willFinishLaunchingWithOptions:)` and `application(_:didFinishLaunchingWithOptions:)` "execute synchronously on the main thread, and the launch cycle doesn't finish until both methods return."
3. **First scene and first frame.** The Time Profiler's App Life Cycle timeline divides launch into "process initialization, UIKit initialization, UIKit initial scene rendering, and initial frame rendering." A complex initial view hierarchy costs here.

Pantry's app delegate is typical of a six-year-old app: analytics, crash reporting, a database migration check, a feature-flag fetch, appearance setup, a location manager, and a full sync. Apple's advice is to do "only the work necessary to prepare your app's initial display," initialize things like "persistent storage and location services, on first use rather than on app launch," and defer network sync "if it makes sense to show stale content." After triage:

```swift ios
import UIKit
import os

@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let signposter = OSSignposter(subsystem: "com.example.pantry", category: .pointsOfInterest)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let state = signposter.beginInterval("Essential launch setup")
        configureAppearance()          // needed for the first frame
        configureCrashReporting()      // must run before anything else can crash
        signposter.endInterval("Essential launch setup", state)
        return true
    }

    private func configureAppearance() { /* colors and fonts from the design system */ }
    private func configureCrashReporting() { /* the reporter's documented setup call */ }
}

@MainActor
final class StartupWork {
    private var hasStarted = false

    /// Called from sceneDidBecomeActive: after the first frame, never before it.
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        Task {
            await refreshFeatureFlags()   // cached flags are fine for this launch
            await syncCatalog()           // the cached catalog is shown meanwhile
        }
    }

    private func refreshFeatureFlags() async { }
    private func syncCatalog() async { }
}
```

- **Two jobs stay** in `didFinishLaunching`: appearance, because the first frame needs it, and crash reporting, because it has to be installed before anything can crash. Everything else moved.
- **The signpost interval** wraps what remains, so a trace or a test can measure it by name (the next sections do both).
- **`StartupWork` runs once, after activation.** The location manager isn't here at all: it's created by the store-finder screen when someone opens it.
- **The `Task` is main-actor isolated**, inherited from the class. That's fine for `async` work that awaits the network or a database actor, but CPU-heavy work inside those functions would still block the main thread. Lesson 2 covers that trap.

### Work after the first frame

Pantry restores the cart after launch, and people wait for it before they can do anything. That time isn't in time to first frame. Apple's article: "If your app still has to run code after it has drawn its first frame, but before the user can begin using the app, that time doesn't contribute to the launch-time metric. Extra startup activities still contribute to the user's perception of the app's responsiveness."

You can make MetricKit count it. `extendLaunchMeasurement(forTaskID:)` (iOS 16) starts an **extended launch task**; Apple says to start the first one "before or during `scene(_:restoreInteractionStateWith:)`, or before the system calls `sceneDidBecomeActive(_:)` on the first scene to connect," with at most 16 tasks, and "the extended launch measurement finishes when all running tasks finish."

```swift ios
import UIKit
import MetricKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let restoreCartTask = MXLaunchTaskID("com.example.pantry.restore-cart")

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        do {
            try MXMetricManager.extendLaunchMeasurement(forTaskID: restoreCartTask)
        } catch {
            // Measurement only; never let it block the launch.
        }
        Task {
            await restoreCart()
            try? MXMetricManager.finishExtendedLaunchMeasurement(forTaskID: restoreCartTask)
        }
    }

    private func restoreCart() async { }
}
```

The result shows up in `MXAppLaunchMetric.histogrammedExtendedLaunch` next to `histogrammedTimeToFirstDraw`. Apple's documentation marks these `MXMetricManager` APIs deprecated as of iOS 27.3 in favor of `MetricManager.trackLaunchTask(id:onTrackingError:_:)` (iOS 27); with Pantry's iOS 17 deployment target, the `MXMetricManager` form is the one that runs everywhere (Module 41, lesson 4 covers the iOS 27 API).

## Measuring in the lab: XCTest metrics

Module 33 locked in a unit-level fix with `measure { }`. For an app, `measure(metrics:block:)` takes the metrics you choose. The ones Apple's "Performance tests" collection lists:

| Metric | Measures |
| --- | --- |
| `XCTClockMetric` | Elapsed wall-clock time, "monotonically, regardless of changes to the system clock," including idle time |
| `XCTCPUMetric` | CPU activity (`init(application:)` for the app under test) |
| `XCTMemoryMetric` | Physical memory, compared before and after the block |
| `XCTStorageMetric` | Storage writes |
| `XCTOSSignpostMetric` | Time between the begin and end of a named signpost interval |
| `XCTApplicationLaunchMetric` | Launch duration (iOS 13); `init(waitUntilResponsive:)` (iOS 14) |
| `XCTHitchMetric` | Hitches in a UI test (iOS 26) |

Pantry's launch and catalog tests, in the UI test target:

```swift illustrative
import XCTest

final class PantryPerformanceTests: XCTestCase {
    func testLaunchUntilResponsive() throws {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            XCUIApplication().launch()
        }
    }

    func testOpeningTheCatalog() throws {
        let app = XCUIApplication()
        app.launch()

        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]

        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(application: app),
            XCTOSSignpostMetric(subsystem: "com.example.pantry", category: "Catalog", name: "Load catalog"),
        ], options: options) {
            app.tabBars.buttons["Catalog"].tap()
            _ = app.collectionViews.firstMatch.waitForExistence(timeout: 5)
            stopMeasuring()
            app.tabBars.buttons["Home"].tap()      // reset for the next iteration, unmeasured
        }
    }
}
```

- **`waitUntilResponsive: true`** measures until "the main thread is responsive after displaying the first frame." With `false`, the metric tracks the first frame plus "all extended launch tasks" started with `extendLaunchMeasurement(forTaskID:)`, which is why the previous section's cart task matters in the lab too.
- **`XCTOSSignpostMetric`** measures one named interval, the same `Load catalog` interval the catalog's model emits with `OSSignposter` (the Swift API for os_signpost). It "doesn't record any results when there isn't a matching pair of begin and end events," so a renamed signpost turns into a silent empty test. Keep the names in one shared constant.
- **`.manuallyStop` and `stopMeasuring()`** keep the navigation back to Home out of the measurement, so every iteration starts from the same state.
- **Iterations.** "A performance test runs its block `iterationCount+1` times, ignoring the first iteration," to discard first-run effects such as cold caches.

Apple's setup for numbers you can trust: build for testing "using the Release build configuration, and turn off the 'Debug executable' setting," and "disable code coverage and the runtime sanitization options" in the performance test plan. Then set a baseline and a maximum standard deviation in the result overlay; the test fails "if the recorded metric is worse than the baseline value by more than the maximum standard deviation." Baselines are stored per device, so CI should run on the same reference hardware every time.

> [!tip] One plan for correctness, another for speed
> Code coverage and the Address Sanitizer belong in the test plan that runs on every pull request. Performance tests go in a separate plan, scheme and device. Mixing them makes both slower and the performance numbers meaningless.

## Measuring in the field: MetricKit

Lab numbers come from your device on your Wi-Fi. MetricKit delivers what happened on customers' devices: "metric reports about the previous 24 hours to your app at most once per day." Module 41 subscribed to MetricKit for crash diagnostics; the same subscriber receives `MXMetricPayload`, which Pantry mines for its budgets:

```swift ios
import Foundation
import MetricKit

struct BucketSummary: Sendable {
    let startMilliseconds: Int
    let endMilliseconds: Int
    let count: Int
}

final class PerformanceMetricsCollector: NSObject, MXMetricManagerSubscriber, Sendable {
    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                upload("launch.firstFrame", buckets(of: launch.histogrammedTimeToFirstDraw))
                upload("launch.extended", buckets(of: launch.histogrammedExtendedLaunch))
            }
            if let responsiveness = payload.applicationResponsivenessMetrics {
                upload("hangs", buckets(of: responsiveness.histogrammedApplicationHangTime))
            }
            if let memory = payload.memoryMetrics {
                let peakMegabytes = memory.peakMemoryUsage.converted(to: .megabytes).value
                uploadValue("memory.peak", peakMegabytes)
            }
        }
    }

    private func buckets(of histogram: MXHistogram<UnitDuration>) -> [BucketSummary] {
        histogram.bucketEnumerator.allObjects.compactMap { object in
            guard let bucket = object as? MXHistogramBucket<UnitDuration> else { return nil }
            return BucketSummary(
                startMilliseconds: Int(bucket.bucketStart.converted(to: .milliseconds).value),
                endMilliseconds: Int(bucket.bucketEnd.converted(to: .milliseconds).value),
                count: bucket.bucketCount
            )
        }
    }

    private func upload(_ metric: String, _ buckets: [BucketSummary]) { /* queue for the metrics endpoint */ }
    private func uploadValue(_ metric: String, _ value: Double) { }
}
```

- **Histograms, not samples.** MetricKit reports launch and hang times as `MXHistogram` buckets: a start, an end and a count. Your backend aggregates buckets from many devices.
- **The hang histogram** is "the different durations of time in which the app is too busy to handle user interaction responsively." Organizer's hang rate is derived from the same data, counting only periods over 250 ms (lesson 2).
- **The same deprecation note applies:** these `MX…` types are deprecated as of iOS 27.3; on iOS 27, `MetricManager.metricReports` delivers `MetricReport` values with `TimeToFirstDrawMetric`, `HangTimeMetric` and `PeakMemoryMetric`.

From buckets you can still compute percentiles, with one honest limitation: you only know which bucket the rank falls in. Report the bucket's upper edge, which never understates:

```swift
struct Bucket {
    let startMilliseconds: Int
    let endMilliseconds: Int
    let count: Int
}

/// The upper edge of the bucket that contains the nearest-rank percentile.
func percentileUpperBound(_ p: Int, of buckets: [Bucket]) -> Int? {
    let total = buckets.reduce(0) { $0 + $1.count }
    guard total > 0, (1...100).contains(p) else { return nil }
    let rank = (p * total + 99) / 100
    var seen = 0
    for bucket in buckets.sorted(by: { $0.startMilliseconds < $1.startMilliseconds }) {
        seen += bucket.count
        if seen >= rank { return bucket.endMilliseconds }
    }
    return nil
}

// One day of time-to-first-draw buckets, merged from many devices.
let firstDraw = [
    Bucket(startMilliseconds: 0, endMilliseconds: 250, count: 120),
    Bucket(startMilliseconds: 250, endMilliseconds: 500, count: 610),
    Bucket(startMilliseconds: 500, endMilliseconds: 1_000, count: 190),
    Bucket(startMilliseconds: 1_000, endMilliseconds: 2_000, count: 65),
    Bucket(startMilliseconds: 2_000, endMilliseconds: 5_000, count: 15),
]

for p in [50, 90, 95, 99] {
    print("p\(p) ≤ \(percentileUpperBound(p, of: firstDraw)!) ms")
}
```

```output
p50 ≤ 500 ms
p90 ≤ 1000 ms
p95 ≤ 2000 ms
p99 ≤ 5000 ms
```

- **1,000 launches** in total. Rank 500 lands in the second bucket (cumulative 730), rank 900 in the third (920), rank 950 in the fourth (985), and rank 990 in the last one: only 15 launches took more than 2 seconds, but that's enough to put p99 in the 2–5 second bucket.
- **Read "p90 ≤ 1000 ms" literally.** It might be 510 ms or 990 ms. Field percentiles are for trends across releases and devices; lab tests are for precise before-and-after comparisons.
- Pantry's field p90 is above its 500 ms budget even though the lab passed. That's normal, and it's why the field number is the one the budget should eventually be judged on.

## Benchmarks in plain Swift

Some questions are smaller than a UI test: is the new lookup faster than the old one? A harness for that needs a **monotonic clock** (one that never jumps when the wall clock is adjusted), a few warm-up runs, several measured runs and a robust summary. `ContinuousClock` is monotonic and keeps counting while the system sleeps; `SuspendingClock` doesn't count sleep. For a benchmark either works; `ContinuousClock` is the common choice.

Pantry's catalog checks whether each product in a promotion exists, using an array of IDs. The proposed fix is a `Set`:

```swift
/// Runs `body` several times after a warm-up and returns the median duration.
func medianDuration(warmUp: Int = 2, runs: Int = 7, _ body: () -> Void) -> Duration {
    let clock = ContinuousClock()
    for _ in 0..<warmUp { body() }
    var durations: [Duration] = []
    for _ in 0..<runs {
        durations.append(clock.measure(body))
    }
    return durations.sorted()[runs / 2]
}

let productIDs = Array(0..<4_000)
let lookups = Array(stride(from: 0, to: 8_000, by: 8))     // 1,000 IDs, half of them missing
let idSet = Set(productIDs)

var arrayHits = 0
var setHits = 0
let arrayTime = medianDuration {
    arrayHits = lookups.filter { productIDs.contains($0) }.count
}
let setTime = medianDuration {
    setHits = lookups.filter { idSet.contains($0) }.count
}

print("same answer:", arrayHits == setHits, "(\(setHits) hits)")
print("set at least 10x faster:", setTime * 10 < arrayTime)
```

```output
same answer: true (500 hits)
set at least 10x faster: true
```

- **Correctness first.** A faster function that returns a different answer isn't an optimization. The harness checks agreement before it compares speed.
- **The output prints no durations**, only facts derived from them. Durations change with the machine, the load and the compiler flags; "at least 10x faster" doesn't, for a change from O(n) to O(1) per lookup on 4,000 elements. That's what makes this block safe to keep as a test, and what makes a benchmark result worth writing in a pull request.
- **The median** of seven runs ignores the one run where the system did something else. `Duration` is `Comparable` and supports `* Int`, so the comparison needs no conversion.
- **Lookups half missing** is deliberate: a missing ID is the worst case for `contains` on an array, because it scans every element.

> [!warning] Debug builds lie about speed
> This harness ran in a debug build. Optimized builds can change the ratio a lot, and occasionally remove the work entirely if the result is unused (which is why the closures store their counts). For decisions, run benchmarks with optimization, the way Apple's performance test scheme uses the Release configuration, and keep debug-build results as a sanity check only.

## Common mistakes

> [!error] Optimizing before measuring
> Pantry's team once spent a sprint on image decoding because "images are slow." The trace showed the launch was waiting on a synchronous feature-flag fetch. Measure, find the biggest cost, fix that, measure again.

> [!error] Reporting the mean
> A few cold launches move the mean without describing anyone. Use p50 for the typical case and p90 or p95 for the tail, with the same percentile definition everywhere.

> [!error] Budgets without a device or a percentile
> "Search must take under 100 ms" passes on the newest iPhone and fails on the oldest. Name the device class and the percentile in every budget.

> [!error] Performance tests in a Debug, sanitized build
> Apple's guidance is a Release build with the debugger detached, and coverage and sanitizers off. Numbers from any other setup can't be compared with the field.

> [!error] Signpost names that drift
> `XCTOSSignpostMetric` records nothing if the begin and end events don't match the subsystem, category and name it expects. Define the names once and use the constants in both the app and the test.

> [!error] Printing timings in a test
> A test that compares printed milliseconds fails on a busy CI machine. Compare derived facts, or use XCTest's baselines with a standard deviation.

## Exercises

````exercise
id: m43-l01-e1
type: prediction
prompt: "Ten search timings from a performance run. What does this print?"
code: |
  func percentile(_ p: Int, of samples: [Int]) -> Int? {
      guard !samples.isEmpty, (1...100).contains(p) else { return nil }
      let sorted = samples.sorted()
      return sorted[(p * sorted.count + 99) / 100 - 1]
  }

  let searches = [52, 48, 95, 50, 47, 310, 49, 51, 53, 46]
  print(searches.reduce(0, +) / searches.count)
  print(percentile(50, of: searches)!)
  print(percentile(80, of: searches)!)
  print(percentile(90, of: searches)!)
  print(percentile(91, of: searches)!)
output: |
  80
  50
  53
  95
  310
hints:
  - "Sort first: 46, 47, 48, 49, 50, 51, 52, 53, 95, 310."
  - "The rank is the ceiling of p × 10 / 100. For p91 that's 9.1 rounded up."
solution: |
  ```output
  80
  50
  53
  95
  310
  ```

  - **Mean:** the sum is 801; integer division by 10 gives 80. One 310 ms search pulls the mean far above every other sample.
  - **p50:** rank 5 → 50. **p80:** rank 8 → 53. **p90:** rank 9 → 95.
  - **p91:** 91 × 10 / 100 = 9.1, rounded up to rank 10 → 310. With ten samples, any percentile above 90 is the maximum. Small samples can't tell you much about the tail; collect more before you trust p95 or p99.
````

````exercise
id: m43-l01-e2
type: comprehension
prompt: "Pantry's lead proposes a launch budget: \"Apple requires time to first frame under 400 ms.\" What's wrong with that sentence?"
choices:
  - text: "Apple's launch documentation gives no target number; a launch budget is the team's choice and should be labeled that way."
    correct: true
    why: "\"Reducing your app's launch time\" explains what's measured and how to reduce it, and that the watchdog terminates apps that take too long, but sets no target."
  - text: "Apple's documented launch target is 100 ms."
    correct: false
    why: "100 ms is Apple's threshold for a discrete interaction becoming noticeable, not a launch target."
  - text: "Launch time is measured until the launch screen appears, so first frame is the wrong metric."
    correct: false
    why: "Organizer and MetricKit measure to the first frame the app draws; the launch screen doesn't stop the clock."
  - text: "Launch time can't be measured in tests, so a budget is pointless."
    correct: false
    why: "XCTApplicationLaunchMetric measures it in UI tests, and MetricKit and Organizer report it from the field."
solution: |
  Apple's article says "on iOS, the watchdog will terminate it if it takes too long" and that launch time is measured to the first frame, but gives no number to aim for. A budget like 400 ms or 500 ms is reasonable, but it's Pantry's decision, based on its own field data and competitors, and the budget table should say "team choice" next to it. Attributing it to Apple invites someone to look it up, fail to find it, and stop trusting the rest of the table.
````

````exercise
id: m43-l01-e3
type: fill-in
prompt: "Complete the UI test that measures launch until the app is responsive, then a signposted interval with manual stopping."
code: |
  func testLaunch() throws {
      measure(metrics: [XCTApplicationLaunchMetric([[1]]: true)]) {
          XCUIApplication().launch()
      }
  }

  func testCheckout() throws {
      let app = XCUIApplication()
      app.launch()
      let options = XCTMeasureOptions()
      options.invocationOptions = [.[[2]]]
      measure(metrics: [XCT[[3]]Metric(subsystem: "com.example.pantry", category: "Checkout", name: "Submit order")], options: options) {
          app.buttons["Place order"].tap()
          _ = app.staticTexts["Order placed"].waitForExistence(timeout: 10)
          [[4]]()
          app.buttons["Done"].tap()
      }
  }
blanks:
  - id: "1"
    answers: ["waitUntilResponsive"]
  - id: "2"
    answers: ["manuallyStop"]
  - id: "3"
    answers: ["OSSignpost"]
  - id: "4"
    answers: ["stopMeasuring"]
solution: |
  ```swift illustrative
  func testLaunch() throws {
      measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
          XCUIApplication().launch()
      }
  }

  func testCheckout() throws {
      let app = XCUIApplication()
      app.launch()
      let options = XCTMeasureOptions()
      options.invocationOptions = [.manuallyStop]
      measure(metrics: [XCTOSSignpostMetric(subsystem: "com.example.pantry", category: "Checkout", name: "Submit order")], options: options) {
          app.buttons["Place order"].tap()
          _ = app.staticTexts["Order placed"].waitForExistence(timeout: 10)
          stopMeasuring()
          app.buttons["Done"].tap()
      }
  }
  ```

  `waitUntilResponsive: true` extends the launch measurement until the main thread responds after the first frame. `.manuallyStop` with `stopMeasuring()` leaves the "Done" tap, which only resets the screen, out of the numbers. The signpost metric measures the `Submit order` interval the app emits; its subsystem, category and name must match the app's exactly, or the metric records nothing.
````

````exercise
id: m43-l01-e4
type: find-errors
prompt: "A pull request adds a benchmark to Pantry's test suite. Mark every real problem."
code: |
  import Foundation

  func benchmark(_ body: () -> Void) -> Double {
      let start = Date()
      body()
      return Date().timeIntervalSince(start) * 1000
  }

  let old = benchmark { _ = oldPriceCalculation(cart) }
  let new = benchmark { _ = newPriceCalculation(cart) }
  print("old: \(old) ms, new: \(new) ms")
  // Expected output checked in CI:
  // old: 12.4 ms, new: 3.1 ms
choices:
  - text: "Date isn't a monotonic clock; a wall-clock adjustment during the run corrupts the result."
    correct: true
  - text: "Each implementation runs once, with no warm-up and no median."
    correct: true
  - text: "The output prints durations, so the CI comparison fails whenever the machine is faster or busier."
    correct: true
  - text: "Nothing checks that the old and new calculations return the same price."
    correct: true
  - text: "Multiplying by 1000 converts seconds to microseconds."
    correct: false
    why: "timeIntervalSince returns seconds; × 1000 gives milliseconds, as the label says."
rubric:
  - I flagged the non-monotonic clock.
  - I flagged the single, cold run.
  - I flagged printing durations in a checked output.
  - I flagged the missing correctness comparison.
solution: |
  Four problems:

  1. **`Date` is wall-clock time.** Use `ContinuousClock` (or `SuspendingClock`), which is monotonic.
  2. **One cold run.** The first run pays for caches, lazy initialization and page faults. Warm up, run several times, take the median.
  3. **Printed durations in CI.** They change with every machine. Print derived facts such as `new at least 2x faster: true`, or use an XCTest performance test with a baseline and standard deviation.
  4. **No correctness check.** Compare the two results before comparing their speed; a faster function that rounds differently is a bug.

  The lesson's `medianDuration` harness fixes the first three; the `same answer:` line fixes the fourth.
````

````exercise
id: m43-l01-e5
type: solve
prompt: |
  Write `percentileUpperBound(_:of:)` for MetricKit-style hang buckets. The buckets may arrive in any order and some may have a count of 0. Return the upper edge of the bucket containing the nearest-rank percentile, or `nil` if there are no samples or `p` isn't between 1 and 100.

  Expected output:

  ```output
  p50 ≤ 500 ms
  p90 ≤ 1000 ms
  p99 ≤ 8000 ms
  nil
  ```
starter: |
  struct Bucket {
      let startMilliseconds: Int
      let endMilliseconds: Int
      let count: Int
  }

  func percentileUpperBound(_ p: Int, of buckets: [Bucket]) -> Int? {
      // your code
      return nil
  }

  let hangs = [
      Bucket(startMilliseconds: 2_000, endMilliseconds: 8_000, count: 4),
      Bucket(startMilliseconds: 250, endMilliseconds: 500, count: 70),
      Bucket(startMilliseconds: 1_000, endMilliseconds: 2_000, count: 6),
      Bucket(startMilliseconds: 500, endMilliseconds: 1_000, count: 20),
      Bucket(startMilliseconds: 8_000, endMilliseconds: 20_000, count: 0),
  ]
  for p in [50, 90, 99] {
      print("p\(p) ≤ \(percentileUpperBound(p, of: hangs)!) ms")
  }
  print(percentileUpperBound(50, of: []) as Any)
hints:
  - "Sort the buckets by their start before accumulating counts."
  - "The rank is (p × total + 99) / 100, as in the lesson."
  - "An empty bucket list has a total of 0; return nil before dividing anything."
rubric:
  - Sorts buckets by start.
  - Computes the nearest rank with integer math.
  - Returns the upper edge of the bucket where the cumulative count reaches the rank.
  - Returns nil for no samples or an out-of-range percentile.
solution: |
  ```swift
  struct Bucket {
      let startMilliseconds: Int
      let endMilliseconds: Int
      let count: Int
  }

  func percentileUpperBound(_ p: Int, of buckets: [Bucket]) -> Int? {
      let total = buckets.reduce(0) { $0 + $1.count }
      guard total > 0, (1...100).contains(p) else { return nil }
      let rank = (p * total + 99) / 100
      var seen = 0
      for bucket in buckets.sorted(by: { $0.startMilliseconds < $1.startMilliseconds }) {
          seen += bucket.count
          if seen >= rank { return bucket.endMilliseconds }
      }
      return nil
  }

  let hangs = [
      Bucket(startMilliseconds: 2_000, endMilliseconds: 8_000, count: 4),
      Bucket(startMilliseconds: 250, endMilliseconds: 500, count: 70),
      Bucket(startMilliseconds: 1_000, endMilliseconds: 2_000, count: 6),
      Bucket(startMilliseconds: 500, endMilliseconds: 1_000, count: 20),
      Bucket(startMilliseconds: 8_000, endMilliseconds: 20_000, count: 0),
  ]
  for p in [50, 90, 99] {
      print("p\(p) ≤ \(percentileUpperBound(p, of: hangs)!) ms")
  }
  print(percentileUpperBound(50, of: []) as Any)
  ```

  ```output
  p50 ≤ 500 ms
  p90 ≤ 1000 ms
  p99 ≤ 8000 ms
  nil
  ```

  100 hangs in total. Sorted by start, the cumulative counts are 70, 90, 96, 100 and 100. Rank 50 is reached in the 250–500 bucket, rank 90 exactly at the end of the 500–1000 bucket (so 1000, not 2000: "at least p percent at or below"), and rank 99 in the 2000–8000 bucket. The empty 8000–20000 bucket never matters, and the input order doesn't either, because the function sorts.

  Without the sort, the first bucket in the list (2000–8000) would be counted first and every percentile would come out wrong. MetricKit doesn't promise an order, so don't assume one.
````

````exercise
id: m43-l01-e6
type: design
prompt: "Write Pantry's performance budget for the product detail screen (opened from a catalog cell; shows a large image, price, stock and a \"Add to cart\" button). Give at least four rows with interaction, device, percentile, limit, the source of each number, and how each row is measured in the lab and in the field."
rubric:
  - Every row names a device class and a percentile.
  - Limits tied to Apple's thresholds are attributed; the others are labeled as team choices.
  - Each row has a lab measurement (XCTest metric or signpost) and a field source (MetricKit or Organizer) where one exists.
  - At least one row covers memory or hitches, not only time.
solution: |
  One reasonable budget, on the oldest supported iPhone:

  | Interaction | Percentile | Limit | Source | Lab | Field |
  | --- | --- | --- | --- | --- | --- |
  | Tap cell → detail visible | p95 | 100 ms | Apple's discrete-interaction threshold | `XCTOSSignpostMetric` on a `Open product` interval | Signpost metrics via MetricKit (`mxSignpost` with a MetricKit log handle) |
  | "Add to cart" → badge updates | p95 | 100 ms | Apple's discrete-interaction threshold | `XCTClockMetric` with `.manuallyStop` | Hang rate for the release; no per-button field metric |
  | Scrolling the image gallery | — | no hitches | Apple's frame interval (8.3 ms at 120 Hz) | `XCTHitchMetric` on iOS 26 runners, Animation Hitches in Instruments | Organizer hitch rate, MetricKit `animationMetrics` |
  | Memory growth after opening and closing 20 products | — | under 10 MB | Team choice | `XCTMemoryMetric(application:)` | `peakMemoryUsage` trend per release |

  What matters isn't these exact numbers but that each row can fail a check, that Apple's numbers are attributed and the team's aren't disguised as Apple's, and that someone owns each row. The memory row in particular catches image caches that never shrink (lesson 2).
````

## Summary

- A budget is a limit for one interaction, on a named device, at a named percentile. Apple documents 100 ms for discrete interactions (less than half for your main thread), about 5 ms for code during continuous interaction, 8.3 ms or 16.7 ms frames, and 250 ms as where its tools start reporting hangs. Apple gives no launch target; label yours as the team's.
- Summarize timings with nearest-rank percentiles. p50 is typical, p90 and p95 the tail; the mean describes nobody.
- Launch time is time to first frame. Before `main()`, the loader and static initializers run; then the app delegate methods, synchronously on the main thread; then the first scene and frame. Keep only what the first frame needs, initialize the rest on first use or after activation, and mark waiting work after the first frame as extended launch.
- XCTest metrics measure launch, wall time, CPU, memory, storage, signposted intervals and (iOS 26) hitches. Use a Release build without the debugger, coverage or sanitizers; the first iteration is discarded.
- MetricKit reports launch, hang and memory data from real devices as daily histograms; percentiles from buckets are upper bounds, good for trends.
- A plain-Swift benchmark uses `ContinuousClock`, warm-up runs and a median, checks that both versions agree, and prints derived facts, not durations.
