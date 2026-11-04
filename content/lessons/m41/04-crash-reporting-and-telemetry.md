---
id: m41-l04
title: Crash reporting, logging and telemetry
description: "Find out how a shipped app behaves on other people's phones. You read crashes in Xcode's Crashes organizer, receive MetricKit diagnostic payloads and symbolicate their call stacks against the right dSYM, group crashes and compute a crash-free rate, understand what third-party crash reporters do, and collect telemetry that respects privacy: an allowlist on the device, honest App Store privacy details and a privacy manifest."
module: m41
order: 4
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m41-l03, m21-l06]
objectives:
  - Say which crashes reach the Crashes organizer, from whom, and which kinds don't.
  - Subscribe to MetricKit with MXMetricManager and handle diagnostic and metric payloads, and know the iOS 27 replacement.
  - Symbolicate a MetricKit call stack by binary UUID and offset, and explain what a missing dSYM looks like.
  - Group crashes by signature and compute a crash-free session rate.
  - Describe how third-party crash reporters work and what they need from your build.
  - Design telemetry that collects only what it needs, and declare it in App Store privacy details and the privacy manifest.
terms:
  - term: Crashes organizer
    definition: "The Crashes section of Xcode's Organizer window. It shows crash reports from TestFlight testers and from App Store users who share diagnostics with developers, symbolicated when you uploaded symbols."
  - term: MetricKit
    definition: "Apple's framework that delivers on-device metrics (launch time, hangs, memory, battery and more) about once a day, and diagnostics (crashes, hangs, CPU and disk-write exceptions) as soon as they're available on iOS 15 and later."
  - term: MXMetricManager
    definition: "The shared MetricKit object you add a subscriber to. Deprecated in Apple's documentation as of iOS 27.3 in favor of MetricManager, an instance with asynchronous sequences of reports, available from iOS 27."
  - term: Crash signature
    definition: "A key used to group crash reports that share a cause, typically the first frame in your own code on the crashed thread."
  - term: Crash-free rate
    definition: "The share of sessions (or users) without a crash in a period: (sessions - crashed sessions) / sessions."
  - term: Privacy manifest
    definition: "A PrivacyInfo.xcprivacy property list in the app or an SDK that records the data types collected, whether they're used for tracking, and the reasons for using required-reason APIs."
mastery:
  - Explain why a TestFlight crash shows up in the organizer but a jetsam termination doesn't, and where to find the latter.
  - Write a MetricKit subscriber that forwards crash diagnostics with the app version and build.
  - Turn a MetricKit call stack into function names with symbol tables keyed by binary UUID, and spot frames with no matching dSYM.
  - Group a list of crash reports by their first app frame and report a crash-free rate without floating-point formatting surprises.
  - Write a telemetry allowlist that drops unknown events and fields and coarsens precise values.
  - Fill in App Store privacy details and a privacy manifest for crash data, performance data and product analytics.
resources: [xcode-symbolicate-crash-report, os-logger, privacy-manifest-files, app-review-guidelines, xcode-improving-performance]
cards:
  - id: m41-l04-c1
    front: Whose crashes appear in Xcode's Crashes organizer?
    back: "TestFlight testers' crashes always (they share automatically, regardless of device settings), and App Store users' crashes when they share diagnostics and usage data. Watchdog, jetsam (memory), thermal and invalid-signature events aren't in the organizer; get them from the device's Analytics Data."
  - id: m41-l04-c2
    front: When does MetricKit deliver metrics and diagnostics?
    back: "Metric reports about the previous 24 hours at most once per day; diagnostic reports immediately on iOS 15 and later. Test on a physical device. On iOS 27, MetricManager delivers both as async sequences; MXMetricManager is deprecated as of 27.3."
  - id: m41-l04-c3
    front: How do you symbolicate a MetricKit call stack frame?
    back: "Each frame has binaryUUID and offsetIntoBinaryTextSegment. Find the dSYM with that UUID (from the archive of that exact build), then the function whose start is the last one at or before the offset. A UUID with no dSYM means you didn't keep or upload the archive."
  - id: m41-l04-c4
    front: Your app sends crash reports and launch times to your own server. What do you declare?
    back: "In App Store Connect privacy details: Diagnostics → Crash Data and Performance Data, whether each is linked to the user, and the purpose (usually App Functionality). In PrivacyInfo.xcprivacy: NSPrivacyCollectedDataTypeCrashData and ...PerformanceData with the same linked, tracking and purpose answers."
  - id: m41-l04-c5
    front: What's the safest default for a telemetry pipeline on the device?
    back: "An allowlist: only known event names and known fields leave the device; everything else is dropped. Coarsen precise values (durations into ranges, no coordinates), use an opaque install or account ID, and never send names, emails or free text."
---

## The idea in one sentence

Once the app is on other people's phones you only know what they experience through what you prepared in advance: Apple's crash reports and MetricKit diagnostics, symbolicated with the dSYMs you kept, plus whatever telemetry you chose to collect, which must be the minimum, declared honestly and free of personal data.

> [!note] Sources and what was checked
> Crash collection comes from Apple's "Acquiring crash reports and diagnostic logs" and "Distributing your app for beta testing and releases"; MetricKit from the MetricKit, `MXMetricManager`, `MXMetricManagerSubscriber`, `MXCallStackTree.jsonRepresentation()`, `MetricManager` and `DiagnosticReport` reference pages; privacy from "App privacy details on the App Store", App Store Connect Help ("Manage app privacy"), "Privacy manifest files", "Describing use of required reason API" and the App Review Guidelines (section 5.1). All read in November 2026. Xcode's Organizer wasn't opened. The `MXMetricManager` block was type-checked against the iOS SDK, not run (MetricKit only delivers on a device); the iOS 27 `MetricManager` block wasn't type-checked, because the CI runner's SDK is iOS 26. The other Swift blocks are models, compiled and run with Swift 6.3.

## Where crashes show up

Module 21 covered what a crash report is and how symbolication works. In production the question is how reports reach you.

**Xcode's Crashes organizer.** Apple's "Acquiring crash reports and diagnostic logs":

- "TestFlight and the App Store collect crash reports for every submitted version of your app. Crash reports automatically contain identifiable symbol information if you include symbol information when submitting a build."
- "TestFlight users of your app automatically share crash reports with you, regardless of the device settings for sharing diagnostic and use data." App Store users' crashes appear only from "customers who share diagnostic and usage information."
- Some reports **aren't** in the organizer: "watchdog events, such as those from slow app launch times," "invalid code-signature crashes," "thermal events" and "jetsam events, where an app has high memory use." For those, connect the device and use Xcode's Devices window, or ask the person to send the report from the Analytics & Improvements section of Settings, under Analytics Data (Apple's article lists the steps; log names start with your binary name, or `JetsamEvent_` for memory terminations).

The organizer is the place to start because it costs nothing: no SDK, no data leaving the device that you have to declare. Its limits are coverage (only opted-in App Store users) and delay.

**Symbolication in production** depends entirely on Module 21's rules: each build has a UUID, only that build's dSYM matches it, and "you must retain the Xcode archive for each build of your app you distribute." Lesson 2's release workflow uploads symbols (`uploadSymbols` in the export options) and keeps the archive as an artifact. Two gaps catch teams out:

- **Third-party binary frameworks** ship their own dSYMs (or don't). If a vendor's XCFramework has no dSYM, its frames stay as addresses.
- **CI artifacts expire.** Lesson 1: Xcode Cloud keeps artifacts 30 days. Copy every release archive to storage that outlives that.

## MetricKit

MetricKit is the API version of the same data, delivered to your app on the device so you can send it where you want. From Apple's overview: "The system delivers metric reports about the previous 24 hours to your app at most once per day. Diagnostic reports arrive immediately in iOS 15 and later."

On the course's iOS 17 baseline you subscribe with `MXMetricManager`:

```swift ios
import Foundation
import MetricKit
import os

final class DiagnosticsCollector: NSObject, MXMetricManagerSubscriber, Sendable {
    private let log = Logger(subsystem: "com.example.Weather", category: "diagnostics")

    func start() {
        MXMetricManager.shared.add(self)
    }

    // Diagnostics: crashes, hangs, CPU and disk-write exceptions.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let version = crash.applicationVersion
                let build = crash.metaData.applicationBuildVersion
                let signal = crash.signal?.intValue ?? -1
                log.error("Crash in \(version, privacy: .public) (\(build, privacy: .public)), signal \(signal)")
                send(crash.callStackTree.jsonRepresentation())
            }
        }
    }

    // Daily metrics: launch time, hang rate, memory, battery.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            send(payload.jsonRepresentation())
        }
    }

    private func send(_ json: Data) {
        // Queue for upload to your diagnostics endpoint.
    }
}

let collector = DiagnosticsCollector()
collector.start()
```

- `MXMetricManager.shared` "starts accumulating reports for your app after calling `shared` for the first time." Add the subscriber early in launch; Apple says the calls "are safe to use in performance-sensitive code, such as during app launch."
- Both `didReceive(_:)` methods are optional protocol requirements; implement the ones you want. Apple notes "it's safe to process the payload on a separate thread."
- `applicationVersion` is your `CFBundleShortVersionString` and `metaData.applicationBuildVersion` your `CFBundleVersion` (lesson 3). That's how a report finds its dSYM: version and build give you the archive, the call stack gives you UUIDs and offsets.
- `jsonRepresentation()` gives you the payload as JSON to store or upload as-is.
- "To test MetricKit in your app, run your app on a physical device."

### The iOS 27 API

Apple's documentation marks `MXMetricManager` and its related types deprecated as of iOS 27.3 with the message "Use MetricManager instead." `MetricManager` (iOS 27 and later) is an instance you create and keep, with reports as asynchronous sequences. Apple's example, adapted:

```swift illustrative
import MetricKit

@available(iOS 27, *)
func watchDiagnostics(with manager: MetricManager) async {
    for await report in manager.diagnosticReports {
        switch report.result {
        case .crash(let crash):
            print("crash", crash.terminationCategory as Any)
        case .hang:
            print("hang")
        default:
            break
        }
    }
}
```

Apple's notes: create one `MetricManager` and share it ("if you create more than one ..., two tasks concurrently iterating the same sequence both receive a non-deterministic subset of reports"), and `DiagnosticReport` "conforms to `Codable`, you can serialize it directly with `JSONEncoder`." This block is marked illustrative: it wasn't type-checked, because the CI runner's SDK is iOS 26. With an iOS 17 deployment target you'd keep the `MXMetricManager` subscriber and add the new path behind `if #available(iOS 27, *)` once you build with the iOS 27 SDK.

### Symbolicating a MetricKit call stack

A call stack from `MXCallStackTree.jsonRepresentation()` has, per frame, the binary's name, its UUID and the offset into its text segment. That's exactly what symbolication needs: the UUID picks the dSYM, the offset picks the function. Here's that as a model, using the JSON layout from Apple's documentation (a real tool would read symbol tables out of the dSYMs; this one has them typed in):

```swift
import Foundation

// The shape of MXCallStackTree.jsonRepresentation(), from Apple's example.
struct CallStackTree: Decodable {
    let callStackTree: Tree
    struct Tree: Decodable {
        let callStackPerThread: Bool
        let callStacks: [CallStack]
    }
    struct CallStack: Decodable {
        let threadAttributed: Bool
        let callStackRootFrames: [Frame]
    }
    struct Frame: Decodable {
        let binaryUUID: String
        let offsetIntoBinaryTextSegment: Int
        let binaryName: String
        let subFrames: [Frame]?
    }
}

// What you extracted from each archived dSYM: functions sorted by start offset.
let symbolTables: [String: [(start: Int, name: String)]] = [
    "70B89F27-1634-3580-A695-57CDB41D7743": [
        (160_000, "ForecastStore.decode(_:)"),
        (165_200, "ForecastStore.refresh()"),
        (171_000, "RadarView.body.getter"),
    ],
]

func symbolicate(_ frame: CallStackTree.Frame) -> String {
    guard let table = symbolTables[frame.binaryUUID] else {
        return "\(frame.binaryName) + \(frame.offsetIntoBinaryTextSegment)  (no dSYM for \(frame.binaryUUID.prefix(8)))"
    }
    var match: (start: Int, name: String)? = nil
    for symbol in table where symbol.start <= frame.offsetIntoBinaryTextSegment {
        match = symbol
    }
    guard let match else { return "\(frame.binaryName) + \(frame.offsetIntoBinaryTextSegment)  (before first symbol)" }
    return "\(frame.binaryName)  \(match.name) + \(frame.offsetIntoBinaryTextSegment - match.start)"
}

func flatten(_ frames: [CallStackTree.Frame]) -> [CallStackTree.Frame] {
    var result: [CallStackTree.Frame] = []
    for frame in frames {
        result.append(frame)
        result += flatten(frame.subFrames ?? [])
    }
    return result
}

let json = """
{
  "callStackTree": {
    "callStackPerThread": true,
    "callStacks": [
      {
        "threadAttributed": true,
        "callStackRootFrames": [
          {
            "binaryUUID": "70B89F27-1634-3580-A695-57CDB41D7743",
            "offsetIntoBinaryTextSegment": 165304,
            "sampleCount": 1,
            "binaryName": "Weather",
            "address": 7170766264,
            "subFrames": [
              {
                "binaryUUID": "70B89F27-1634-3580-A695-57CDB41D7743",
                "offsetIntoBinaryTextSegment": 160412,
                "sampleCount": 1,
                "binaryName": "Weather",
                "address": 7170761372,
                "subFrames": [
                  {
                    "binaryUUID": "77A62F2E-8212-30F3-84C1-E8497440ACF8",
                    "offsetIntoBinaryTextSegment": 6948,
                    "sampleCount": 1,
                    "binaryName": "libdyld.dylib",
                    "address": 7170808612
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"""

do {
    let tree = try JSONDecoder().decode(CallStackTree.self, from: Data(json.utf8))
    for stack in tree.callStackTree.callStacks where stack.threadAttributed {
        for (index, frame) in flatten(stack.callStackRootFrames).enumerated() {
            print(index, symbolicate(frame))
        }
    }
} catch {
    print("couldn't decode:", error)
}
```

```output
0 Weather  ForecastStore.refresh() + 104
1 Weather  ForecastStore.decode(_:) + 412
2 libdyld.dylib + 6948  (no dSYM for 77A62F2E)
```

- `threadAttributed` marks the thread the diagnostic is attributed to (the crashed thread, for a crash), so the model prints only that one.
- Frames nest through `subFrames`; the model flattens them in the order they appear.
- The `libdyld.dylib` frame has no table because it's Apple's binary, not yours. Xcode symbolicates system frames with the device's OS symbols; in your own pipeline they stay as offsets unless you have those symbols. The frames that matter, yours, resolve only if you kept the dSYM with UUID `70B89F27...`.

The JSON's keys and nesting come from Apple's example; the UUIDs and offsets are copied from it too, and the app frame and symbol names are made up for the model.

## Grouping crashes and a crash-free rate

A thousand crash reports are rarely a thousand bugs. Tools group them by a **signature**, typically the first frame in your own code on the crashed thread: frames above it are system code that crashed *because* of yours (`swift_unexpectedError` after a `try!`, `__pthread_kill` after an `abort`). Exercise 5 builds that grouping.

The number that summarizes stability is the **crash-free rate**: sessions (or users) without a crash, divided by all of them. Small differences matter: 99.9% means one crash per thousand sessions; 99.35% means about six and a half. Teams set a release bar ("don't go beyond 20% of the phased release if crash-free sessions drop below 99.8%") and watch the new version's rate against the previous one.

## Third-party crash reporters

Many teams add a crash-reporting SDK for faster, more complete reports than the organizer gives. They're all built on the same mechanism, described here generically (no specific product was tested):

1. **At launch**, the SDK installs handlers for fatal signals and uncaught exceptions.
2. **At the crash**, the handler records the stack of each thread and the loaded binary images (names, UUIDs, load addresses) to a file, using only operations that are safe in a crashing process.
3. **At the next launch**, the SDK finds the file and uploads it with the app version and build.
4. **On the server**, frames are symbolicated with dSYMs you uploaded from your build pipeline, then grouped by signature.

What that means for you:

- **Upload dSYMs from CI** for every build, including third-party frameworks' dSYMs. A missing dSYM is the most common reason a reporter shows addresses.
- **Only one crash handler gets a reliable chance.** Two SDKs that both install signal handlers can interfere; pick one.
- **It's data you collect.** Unlike the organizer, the report leaves the device through your code, so it must appear in your App Store privacy details and privacy manifest (below), and the SDK should ship its own privacy manifest.
- **Crashes it can't see:** a jetsam or watchdog termination isn't a signal your process gets to handle. MetricKit's diagnostics and the organizer still cover some of those.

## Logs in production

Module 21's `Logger` is still the right tool, with one limit to keep in mind: unified logs stay **on the device**. You see them in Xcode's console or the Console app for a device connected to your Mac, or when a user shares a sysdiagnose. For "what happened before the crash" on a stranger's phone, logs won't help unless you build something that sends them, and then they're telemetry with all the rules below. Module 21's privacy rules apply twice over: a log line you upload is personal data if it contains any.

## Telemetry that respects privacy

**Telemetry** is data your app sends to you about how it's used and how it performs: screen views, feature usage, timings, errors. It's the most useful and the most dangerous data you collect.

The rules come from three places:

- **App Review Guidelines 5.1.1(ii)**: "Apps that collect user or usage data must secure user consent for the collection, even if such data is considered to be anonymous at the time of or immediately following collection." **5.1.1(iii)**: apps "should only collect and use data that is required to accomplish the relevant task." **5.1.2(i)**: tracking across apps requires App Tracking Transparency permission.
- **App privacy details** in App Store Connect. Apple's definition: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time." You declare every data type you or your SDKs collect (with narrow exceptions), whether it's **linked to the user**, whether it's used for **tracking**, and its **purposes**.
- **The privacy manifest**, `PrivacyInfo.xcprivacy`, which records the same data types plus required-reason API use, in the app and in each SDK.

The engineering answer is to decide on the device what's allowed out. An **allowlist** of events and fields, with precise values coarsened, means a developer adding `"email": user.email` to an event by mistake sends nothing:

```swift
enum Field {
    case keep
    case bucketed([Int])     // report the range, not the exact value
}

struct TelemetryEvent {
    let name: String
    let properties: [String: String]
}

let schema: [String: [String: Field]] = [
    "forecast_loaded": ["duration_ms": .bucketed([100, 500, 2_000]), "source": .keep],
    "radar_opened": ["zoom": .keep],
]

func bucketLabel(_ value: Int, edges: [Int]) -> String {
    var lower = 0
    for edge in edges {
        if value < edge { return "\(lower)-\(edge - 1)" }
        lower = edge
    }
    return "\(lower)+"
}

/// Only events and fields in the schema leave the device; everything else is dropped.
func sanitize(_ event: TelemetryEvent) -> TelemetryEvent? {
    guard let fields = schema[event.name] else { return nil }
    var kept: [String: String] = [:]
    for (key, value) in event.properties {
        switch fields[key] {
        case .keep?:
            kept[key] = value
        case .bucketed(let edges)?:
            if let number = Int(value) { kept[key] = bucketLabel(number, edges: edges) }
        case nil:
            continue
        }
    }
    return TelemetryEvent(name: event.name, properties: kept)
}

let raw = [
    TelemetryEvent(name: "forecast_loaded", properties: ["duration_ms": "734", "source": "network", "city": "Oslo", "email": "ana@example.com"]),
    TelemetryEvent(name: "radar_opened", properties: ["zoom": "7", "lat": "59.9139", "lon": "10.7522"]),
    TelemetryEvent(name: "contacts_imported", properties: ["count": "212"]),
]
for event in raw {
    if let clean = sanitize(event) {
        let fields = clean.properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        print(clean.name, fields.joined(separator: " "))
    } else {
        print("dropped", event.name)
    }
}
```

```output
forecast_loaded duration_ms=500-1999 source=network
radar_opened zoom=7
dropped contacts_imported
```

The email and the city never leave; the coordinates are dropped (Apple's privacy details treat a latitude and longitude "with three or more decimal places" as **precise location**); an event nobody put in the schema is dropped whole; and an exact 734 ms becomes `500-1999`, which is enough to see a regression and useless for fingerprinting. The schema is also your documentation for the privacy questions: everything that can leave the device is listed in one place, so filling in App Store Connect is a matter of reading it.

Two more habits:

- **Identify installs, not people.** A random UUID created on first launch and stored on the device lets you count sessions without an account ID. If telemetry must be tied to an account, it's "linked to the user" and must be declared that way.
- **Ask, and honor the answer.** Guideline 5.1.1(ii) requires consent and "an easily accessible and understandable way to withdraw consent." A Settings toggle that actually stops the uploads, and deletes the queue, is the minimum.

### Declaring it

For the app above, which sends crash call stacks, MetricKit performance payloads and the two product events to its own server, the App Store Connect answers come from Apple's data type list ("App privacy details on the App Store"):

| Data type (Diagnostics / Usage Data) | Apple's description | Linked to user? | Purpose |
| --- | --- | --- | --- |
| Crash Data | "Such as crash logs" | No (install ID only) | App Functionality |
| Performance Data | "Such as launch time, hang rate, or energy use" | No | App Functionality |
| Product Interaction | "Such as app launches, taps, clicks, scrolling information..." | No | Analytics |

Apple's purpose definitions: **App Functionality** includes "minimize app crashes, improve scalability and performance"; **Analytics** is "using data to evaluate user behavior, including to understand the effectiveness of existing product features." Your answers cover third-party SDKs too: "You must include information about your app's privacy practices and those of third-party partners whose code you integrate into your app."

The same answers go into the app's privacy manifest, `PrivacyInfo.xcprivacy`, with the keys Apple documents (`NSPrivacyTracking`, `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes`, `NSPrivacyAccessedAPITypes`). If the app also stores its own settings in `UserDefaults`, that's a required-reason API: reason `CA92.1` is "to access user defaults to read and write information that is only accessible to the app itself." Since May 1, 2024, Apple says, "apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect."

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeCrashData</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePerformanceData</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeProductInteraction</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Module 42 returns to privacy manifests and third-party SDK signatures from the security side. Keep the manifest, the App Store answers and the telemetry schema in sync: when one changes in a pull request, the other two should change in the same one. Apple says you can update the App Store answers "at any time, and you do not need to submit an app update"; the manifest ships with the binary.

## Common mistakes

> [!error] Relying on the organizer alone and calling it complete
> It only has opted-in App Store users, and it never shows jetsam, watchdog or thermal terminations. Add MetricKit (or a crash SDK) for coverage, and the device's Analytics Data for the terminations.

> [!error] Shipping a crash SDK without uploading dSYMs
> The reports arrive as addresses. Upload dSYMs for every build from CI, including third-party frameworks', and keep the archives after the CI artifacts expire.

> [!error] A blocklist instead of an allowlist
> "Remove email and name" misses the field someone adds next month. Only send events and fields that are in a reviewed schema.

> [!error] Treating "anonymous" as "doesn't need consent"
> Guideline 5.1.1(ii) requires consent for user or usage data "even if such data is considered to be anonymous." Ask, and make withdrawing consent stop the uploads.

> [!error] Privacy answers that don't match the binary
> Adding an analytics SDK without updating App Store Connect and the privacy manifest makes your product page wrong. Guideline 2.3 counts privacy information as metadata that must be accurate.

## Exercises

````exercise
id: m41-l04-e1
type: prediction
prompt: "Using the lesson's bucketing for telemetry values, what does this program print?"
code: |
  func bucketLabel(_ value: Int, edges: [Int]) -> String {
      var lower = 0
      for edge in edges {
          if value < edge { return "\(lower)-\(edge - 1)" }
          lower = edge
      }
      return "\(lower)+"
  }

  let edges = [100, 500, 2_000]
  for duration in [0, 99, 100, 734, 2_000, 15_000] {
      print(duration, bucketLabel(duration, edges: edges))
  }
  print(bucketLabel(3, edges: []))
output: |
  0 0-99
  99 0-99
  100 100-499
  734 500-1999
  2000 2000+
  15000 2000+
  0+
hints:
  - "Each edge is the first value of the next range."
  - "With no edges, the loop doesn't run."
solution: |
  ```output
  0 0-99
  99 0-99
  100 100-499
  734 500-1999
  2000 2000+
  15000 2000+
  0+
  ```

  The function returns the first range whose upper edge the value is below. 100 is not `< 100`, so it falls into `100-499`; 2000 isn't below any edge, so it's in the open-ended `2000+`. The last line prints only the label, because that `print` has no value in front of it: with no edges every value is `0+`, which tells you nothing. That's a schema bug, not a privacy feature.

  The point of the ranges: a regression from about 300 ms to about 900 ms is still obvious in aggregated buckets, but an exact value such as 734 can't be used to tell devices apart.
````

````exercise
id: m41-l04-e2
type: comprehension
multiple: true
prompt: "Which of these crashes or terminations appear in Xcode's Crashes organizer, according to Apple's documentation?"
choices:
  - text: "A crash on a TestFlight tester's phone that has \"Share with App Developers\" turned off."
    correct: true
    why: "TestFlight users share crash reports automatically, regardless of the device settings."
  - text: "A crash on an App Store user's phone that shares diagnostics with developers."
    correct: true
    why: "The organizer shows crash reports from customers who share diagnostic and usage information."
  - text: "A jetsam termination because the app used too much memory."
    correct: false
    why: "Apple lists jetsam events among the reports that aren't available through the Crashes organizer."
  - text: "A watchdog termination because launch took too long."
    correct: false
    why: "Watchdog events aren't in the organizer either; get them from the device."
solution: |
  **The TestFlight crash and the opted-in App Store crash.** Apple: "TestFlight users of your app automatically share crash reports with you, regardless of the device settings for sharing diagnostic and use data," and the organizer shows reports "from customers who share diagnostic and usage information."

  Watchdog, invalid code-signature, thermal and jetsam events "aren't available through the Crashes organizer." Find them in the device's Analytics Data (the log name starts with `JetsamEvent_` for memory terminations) or through Xcode's Devices window with the device connected. MetricKit's memory and launch metrics show the trend across users.
````

````exercise
id: m41-l04-e3
type: fill-in
prompt: "Complete the privacy manifest entry for crash reports that your app sends to your own server, not linked to the user, for app functionality."
code: |
  <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataType[[1]]</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <[[2]]/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
          <string>NSPrivacyCollectedDataTypePurpose[[3]]</string>
      </array>
  </dict>
blanks:
  - id: "1"
    answers: ["CrashData"]
  - id: "2"
    answers: ["false"]
  - id: "3"
    answers: ["AppFunctionality"]
solution: |
  ```xml
  <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeCrashData</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
          <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
  </dict>
  ```

  Crash Data is in Apple's Diagnostics category ("such as crash logs"). It's not linked only if you send no account ID and don't tie it back to one; an opaque install ID that you never join with account data keeps it unlinked. App Functionality covers "minimize app crashes." The same three answers go into App Store Connect's privacy details.
````

````exercise
id: m41-l04-e4
type: find-errors
prompt: "A pull request adds crash and analytics reporting. Mark every real problem."
code: |
  // AppDelegate
  CrashSDK.start(apiKey: "pk_live_8812")
  OtherCrashSDK.start()                       // "for redundancy"
  Analytics.track("screen_view", ["screen": name, "user_email": session.email])

  // ci/release.yml: unchanged; no dSYM upload step
  // PrivacyInfo.xcprivacy: unchanged (declares no collected data)
  // App Store Connect privacy answers: "Data Not Collected"
choices:
  - text: "Two crash SDKs both install crash handlers; they can interfere, so pick one."
    correct: true
  - text: "The email address is sent with a screen-view event, which makes analytics linked to the user and leaks personal data to a third party."
    correct: true
  - text: "No dSYM upload in CI, so the crash reports will show addresses for the app's frames."
    correct: true
  - text: "The privacy manifest and the App Store answers still say no data is collected."
    correct: true
  - text: "There's no consent check before analytics starts sending."
    correct: true
  - text: "A public SDK key compiled into the app is a leaked secret that must be rotated."
    correct: false
    why: "Client keys that only identify the app to an ingestion endpoint are designed to ship in the binary (Module 21: treat it as public). It's a problem only if the key grants read or admin access."
rubric:
  - I flagged two crash handlers.
  - I flagged the email in analytics.
  - I flagged the missing dSYM upload.
  - I flagged the privacy manifest and App Store answers.
  - I flagged the missing consent.
solution: |
  Five problems:

  1. **Two crash reporters.** Each installs signal and exception handlers; only one gets a reliable chance at a crash. Choose one.
  2. **`user_email` in an analytics event.** It's personal data sent to a third party for analytics, and it makes every event linked to the user. Send an opaque install ID and an allowlisted screen name.
  3. **No dSYM upload.** The SDK can only symbolicate with the dSYMs of each build; add the upload to the release workflow next to `uploadSymbols`.
  4. **Privacy declarations unchanged.** The app now collects Crash Data and Product Interaction (and, as written, Email Address). App Store Connect's answers and `PrivacyInfo.xcprivacy` must say so; the SDKs should also ship their own manifests.
  5. **No consent.** Guideline 5.1.1(ii) requires consent for user or usage data, with a way to withdraw it.

  The `pk_live` client key is meant to be public (it identifies the app to the vendor's ingest endpoint). Check what it can do; if it can only submit events, shipping it is normal.
````

````exercise
id: m41-l04-e5
type: solve
prompt: |
  Write `signature(_:appModule:)`, which returns the first frame that belongs to the app module (frames are `"Module function"`, crashing frame first), or the first frame if none does; and `crashFreeBasisPoints(sessions:crashedSessions:)` with integer math (10,000 basis points = 100%), plus a `percent(_:)` formatter that always shows two decimals. Then group the build 7342 reports by signature, most frequent first (ties alphabetically), and print the crash-free rates.

  ```swift
  let reports = [
      CrashReport(build: "7342", frames: ["libswiftCore swift_unexpectedError", "Weather ForecastStore.decode(_:)", "Weather ForecastStore.refresh()"]),
      CrashReport(build: "7342", frames: ["Weather RadarView.body.getter", "SwiftUICore ViewGraph.update"]),
      CrashReport(build: "7342", frames: ["libsystem_kernel __pthread_kill", "libswiftCore swift_unexpectedError", "Weather ForecastStore.decode(_:)"]),
      CrashReport(build: "7340", frames: ["Weather ForecastStore.decode(_:)"]),
  ]
  ```

  Expected output:

  ```output
  2 Weather ForecastStore.decode(_:)
  1 Weather RadarView.body.getter
  99.35% 99.90%
  ```

  The last line is for 312 crashed sessions out of 48,210, and 1 out of 1,000.
starter: |
  struct CrashReport {
      let build: String
      let frames: [String]
  }

  func signature(_ report: CrashReport, appModule: String) -> String {
      // your code
      return ""
  }

  func crashFreeBasisPoints(sessions: Int, crashedSessions: Int) -> Int {
      // your code
      return 0
  }

  func percent(_ basisPoints: Int) -> String {
      // your code
      return ""
  }
hints:
  - "Match the module with hasPrefix(appModule + \" \"), so \"WeatherKit\" frames don't count as \"Weather\"."
  - "(sessions - crashed) * 10_000 / sessions gives basis points with integer division."
  - "For two decimals, print basisPoints / 100, a period, and basisPoints % 100 padded to two digits."
rubric:
  - Picks the first app frame, skipping system frames, and falls back to the first frame.
  - Filters by build, counts per signature and sorts by count then name.
  - Computes the rate with integer math and formats 9990 as 99.90%.
  - Prints the expected three lines.
solution: |
  ```swift
  struct CrashReport {
      let build: String
      let frames: [String]     // symbolicated, crashing frame first
  }

  /// Group by the first frame in our own code: system frames on top say little about whose bug it is.
  func signature(_ report: CrashReport, appModule: String) -> String {
      for frame in report.frames where frame.hasPrefix(appModule + " ") {
          return frame
      }
      return report.frames.first ?? "unknown"
  }

  /// Crash-free sessions in basis points (1 bp = 0.01%), with integer math so it prints the same everywhere.
  func crashFreeBasisPoints(sessions: Int, crashedSessions: Int) -> Int {
      guard sessions > 0 else { return 10_000 }
      return (sessions - crashedSessions) * 10_000 / sessions
  }

  func percent(_ basisPoints: Int) -> String {
      let fraction = basisPoints % 100
      return "\(basisPoints / 100).\(fraction < 10 ? "0" : "")\(fraction)%"
  }

  let reports = [
      CrashReport(build: "7342", frames: ["libswiftCore swift_unexpectedError", "Weather ForecastStore.decode(_:)", "Weather ForecastStore.refresh()"]),
      CrashReport(build: "7342", frames: ["Weather RadarView.body.getter", "SwiftUICore ViewGraph.update"]),
      CrashReport(build: "7342", frames: ["libsystem_kernel __pthread_kill", "libswiftCore swift_unexpectedError", "Weather ForecastStore.decode(_:)"]),
      CrashReport(build: "7340", frames: ["Weather ForecastStore.decode(_:)"]),
  ]

  var groups: [String: Int] = [:]
  for report in reports where report.build == "7342" {
      groups[signature(report, appModule: "Weather"), default: 0] += 1
  }
  for (name, count) in groups.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }) {
      print(count, name)
  }

  let rate = crashFreeBasisPoints(sessions: 48_210, crashedSessions: 312)
  print(percent(rate), percent(crashFreeBasisPoints(sessions: 1_000, crashedSessions: 1)))
  ```

  ```output
  2 Weather ForecastStore.decode(_:)
  1 Weather RadarView.body.getter
  99.35% 99.90%
  ```

  The first and third reports have different top frames (`swift_unexpectedError` vs `__pthread_kill`) but the same first app frame, so they're one bug: probably a `try!` in `decode(_:)`. Grouping by the very top frame would have split it in two and hidden that it's the biggest problem. The build 7340 report is excluded because you compare one build at a time.

  Integer basis points avoid printing `99.35271...` or a platform-dependent rounding; 47,898 × 10,000 / 48,210 is 9,935 with integer division. The `percent` padding turns 9,990 into `99.90%` instead of `99.9%`.
````

````exercise
id: m41-l04-e6
type: explain
prompt: "A product manager asks for \"full session replays and every tap with its coordinates, linked to the account, so we can debug anything.\" Explain to them, with Apple's rules, what you'd build instead and why."
code: |
  Requested: every tap (x, y), every screen, every text field value, account ID, kept forever
rubric:
  - Cites data minimization (5.1.1(iii)) and consent (5.1.1(ii)), including for "anonymous" data.
  - Explains that linked data must be declared as linked in App Store privacy details and the privacy manifest, and that text fields can contain anything.
  - Proposes an allowlisted event schema, coarsened values and an install ID, plus crash and MetricKit diagnostics for debugging.
  - Mentions retention, a consent toggle that stops uploads, and keeping declarations in sync.
solution: |
  Apple's rules push hard against this, and so does good engineering.

  - **Minimization.** Guideline 5.1.1(iii): apps "should only collect and use data that is required to accomplish the relevant task." Every tap with coordinates and every text field's value isn't required to debug; it's required to reconstruct everything a person did, including what they typed (passwords, card numbers, messages).
  - **Consent.** 5.1.1(ii) requires consent for user or usage data "even if such data is considered to be anonymous," and a way to withdraw it.
  - **Declarations.** Linked to the account, all of it must be declared as linked in App Store Connect and the privacy manifest: Product Interaction, Other User Content, and possibly more. The product page will say so, and users read it.

  What I'd build: crash reports and MetricKit diagnostics for the "debug anything" part, since most bugs show up as crashes, hangs or errors with a stack. An allowlisted event schema for the product questions ("Do people use the radar? How long does the forecast take?") with coarsened values and an install ID, not linked to the account. A consent toggle that stops the uploads and clears the queue. A retention limit on the server. For a specific hard bug, a temporary, opt-in diagnostic mode a support agent can ask one user to enable, with clear wording about what it sends.

  That gives the team 90% of the debugging value, keeps the privacy label honest and short, and doesn't create a database of everything users typed that would be a liability the day it leaks.
````

## Summary

- The Crashes organizer has TestFlight crashes always and App Store crashes from users who share diagnostics; jetsam, watchdog, thermal and signature terminations come from the device instead. Upload symbols and keep every archive.
- MetricKit delivers daily metrics and immediate diagnostics to your app. On iOS 17–26 subscribe with `MXMetricManager`; on iOS 27 `MetricManager` exposes async sequences, and `MXMetricManager` is documented as deprecated from 27.3.
- A MetricKit call stack gives each frame's binary UUID and offset: the UUID picks the dSYM, the offset picks the function. Group crashes by the first frame in your code and track a crash-free rate per build.
- Third-party crash reporters install handlers, save a report at the crash, upload it on the next launch and symbolicate with dSYMs you upload. Use one, and declare what it collects.
- Telemetry is collection: get consent, send only allowlisted events and fields with coarsened values and an install ID, and keep App Store privacy details, the privacy manifest and your schema in sync.
