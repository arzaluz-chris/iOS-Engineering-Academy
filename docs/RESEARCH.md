# Research (Phase 2)

Research date: November 2026. Anything marked "unverified" must be confirmed before it's used in a lesson.

## Current versions

| Component | Version | Source |
| --- | --- | --- |
| Swift | 6.4 (15 Sep 2026); patch 6.4.2 (30 Oct 2026) | swift.org blog "Swift 6.4 Released"; Swift Forums "Announcing Swift 6.4.2" |
| Xcode | 27.2 (27B52, 29 Oct 2026); ships Swift 6.4.2; requires macOS Tahoe 26.6 and Apple silicon | Apple Developer Releases; Xcode system requirements |
| iOS SDK | 27.2 (26 Oct 2026) | Apple Developer Releases |
| Deployment targets supported by Xcode 27 | iOS 15 to 27 | Xcode system requirements |
| Current App Store requirement | Build with Xcode 26+ and the iOS 26 SDK | Upcoming Requirements (28 Apr 2026) |
| Announced requirement | From April 2027, build with the iOS 27 SDK | Apple Developer News (9 Sep 2026) |

**Course deployment target:** iOS 17 as the baseline for projects (Observation, SwiftData, NavigationStack); iOS 27 for labs on new APIs with `if #available`.

## Changes that affect the curriculum

- **UIKit:** with the iOS 27 SDK, apps that don't adopt the scene-based life cycle don't launch (UIKit documentation, TN3187). That's why the course teaches scenes from the first UIKit project.
- **Concurrency:** Swift 6 language mode with strict isolation; since Swift 6.2, *approachable concurrency* and default `@MainActor` isolation (SE-0466). The thread model and GCD (still found in existing code) are taught first, then Swift Concurrency.
- **SwiftUI:** `NavigationView` has been deprecated since iOS 16; `ObservableObject` isn't deprecated and is still taught as an important legacy API.
- **Swift Testing:** included in the toolchain; since Swift 6.4 it interoperates with XCTest.
- UIKit automatic observation tracking is now documented by Apple (checked 4 Nov 2026): on iOS 18 it's opt-in with the Info.plist key `UIObservationTrackingEnabled` and runs in methods such as `viewWillLayoutSubviews()`; from iOS 26 it's on by default (the key's page says it isn't required) and `updateProperties()` exists. Module 40 teaches it that way.
- Not verified in official notes: a JSON project format in Xcode 27.2, a *source break* related to SE-0508.

## APIs: current, legacy and deprecated

| Area | Current | Legacy API that's taught | Deprecated |
| --- | --- | --- | --- |
| SwiftUI state | `@Observable`, `@State`, `@Bindable`, `@Environment` | `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` | — |
| SwiftUI navigation | `NavigationStack`, `NavigationSplitView` | — | `NavigationView` |
| UIKit life cycle | Scenes | `UIApplicationDelegate` for process events | Life cycle without scenes (doesn't launch with the iOS 27 SDK) |
| Concurrency | async/await, tasks, actors, `Sendable` | GCD, completion handlers, `OperationQueue` | — |
| UIKit lists | Collection view + compositional layout + diffable | Classic `UITableView` | — |
| Persistence | SwiftData | Core Data, `UserDefaults`, Keychain | — |
| Testing | Swift Testing | XCTest, XCUITest | — |

## Running Swift in the browser

| Option | Status | Compiles user code on the client | Decision |
| --- | --- | --- | --- |
| Swift SDK for Wasm (official) | Active | No: compiles to Wasm from a machine with the toolchain | Useful for precompiled demos, not for exercises |
| carton | Archived (Nov 2025) | No | Ruled out |
| swiftc compiled to Wasm | No maintained project | In theory | Not viable |
| MiniSwift | Personal project, a subset | Yes, approximately | Ruled out: semantics not guaranteed |
| SwiftFiddle and online playgrounds | Active | No (server) | Ruled out: external dependency, no offline use |

**Decision:** an editor in the browser, drafts saved locally, Swift Testing tests to run in Xcode or with `swift test`, and explicit self-assessment. Reference solutions are compiled and tested in CI (macOS).

## Curriculum references (structure, not content)

| Reference | What was taken | Gap the academy fills |
| --- | --- | --- |
| Stanford CS193p (2025) | SwiftUI with MVVM, project-driven progression | UIKit, testing; assumes prior experience |
| Apple Develop in Swift | SwiftUI → Observation → SwiftData sequence | UIKit, advanced concurrency, algorithms |
| Hacking with Swift (100 Days) | Theory–project–consolidation cycles | Recent strict concurrency |
| Kodeco | Topic books with a running project | Older editions still to be checked |
| NeetCode 150 / LeetCode | 18 pattern categories | Implementation in Swift and its quirks |
| Udemy, Coursera | Unverified | — |

Common gaps the academy covers explicitly: deep UIKit, Swift 6 concurrency, testing, accessibility, performance with Instruments, architecture and modularization, algorithms in Swift, mobile system design, distribution, and **secure development** (OWASP MASVS/MASTG). The last one was requested because of how much weight it carries in banking interviews.

## Algorithm patterns (NeetCode order)

Arrays and hashing; two pointers; sliding window; stack; binary search; linked lists; trees; tries; heaps; backtracking; graphs; advanced graphs; 1-D DP; 2-D DP; greedy; intervals; math and geometry; bit manipulation. The NeetCode 150 difficulty breakdown differs across third-party sources and wasn't verified on neetcode.io.

Swift quirks in interviews: indexing a `String` isn't O(1) (convert to an `Array`); the standard library has no heap or deque (implement them by hand); `Dictionary(_:default:)`, `reduce(into:)`.

## Links

The build environment had no network access to developer.apple.com or docs.swift.org. All resources stay `unverified` until `npm run check-links` runs (the weekly `links.yml` workflow). The URL `developer.apple.com/tutorials/instruments` listed in the spec probably doesn't exist; it wasn't included.
