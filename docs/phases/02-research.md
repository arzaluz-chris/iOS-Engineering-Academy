# Phase 2. Verified research report (November 2026)

The full report from the initial research. The working summary is in `docs/RESEARCH.md`.

The current technical baseline for designing the academy is Swift 6.4 (6.4.2 on swift.org's install page), Xcode 27.2 and iOS 27.2. The finding with the biggest impact on the curriculum is that, starting with the iOS 27 SDK, UIKit apps that don't adopt the scene-based life cycle (UIScene) don't launch. For running code, the sensible choice is not to compile real Swift in the browser: pair an editor with exercises checked locally through Swift packages (`swift test` and Xcode), and leave in-browser execution as an optional experimental layer.

> **Note added after the research (3 Nov 2026):** the 20 resources registered in `content/resources.yaml` were verified with the `links.yml` workflow (20/20 respond). Candidate URLs marked "unverified" in section 1.2 that aren't in `resources.yaml` yet remain unverified.

## Summary

- **Current versions:** Swift 6.4 was released on September 15, 2026, and its latest patch is 6.4.2, announced on the Swift Forums on October 30, 2026 and included in Xcode 27.2. Xcode 27.2 (27B52) was released on October 29, 2026, runs only on Apple silicon and requires macOS Tahoe 26.6. iOS 27.2 is from October 26, 2026. Xcode 27 supports deployment targets from iOS 15 to 27. Recommendation: iOS 17 as the course's baseline minimum and iOS 27 for labs on new APIs.
- **Running Swift in the browser:** the official compiler doesn't run in the browser. The Swift SDK for Wasm compiles *to* Wasm from a machine with the toolchain. carton was archived on November 29, 2025. Online playgrounds compile on a server. MiniSwift runs on the client but is an independent compiler and isn't 100% compatible. Recommendation: an editor + exercises as a Swift package with tests, run in Xcode or with `swift test`.
- **Stack recommended by the research:** Astro 6 with React islands, CodeMirror 6, Shiki, Dexie/IndexedDB, local search and ts-fsrs 6 with FSRS pinned explicitly. (The final implementation chose Vite + React; see `04-technical-design.md`.)

## 1. Checking official sources

Methodological caveat: during the research most `developer.apple.com/documentation/...` and `docs.swift.org` URLs couldn't be loaded directly. The report separates what was **loaded**, what was **confirmed indirectly** and what is **unverified**.

### 1.1 Requested URLs

| URL | Status during research | Type | Notes |
| --- | --- | --- | --- |
| docs.swift.org/swift-book/…/the-swift-programming-language/ | Confirmed indirectly | Official documentation | Possibly merged into docs.swift.org/latest/documentation as of Swift 6.4. Verified 200 on 3 Nov 2026. |
| www.swift.org | Loaded | Official site | Navigation shows "Install (6.4.2)". |
| developer.apple.com/documentation/ | Confirmed indirectly | Official documentation | Current. |
| developer.apple.com/tutorials/develop-in-swift | Confirmed indirectly | Official tutorial | Covers SwiftUI, observable models, SwiftData, ML, Apple Intelligence and visionOS. |
| developer.apple.com/documentation/uikit | Confirmed indirectly | Official documentation | Scene documentation updated for iOS 27. |
| developer.apple.com/documentation/swiftui | Confirmed indirectly | Official documentation | Current. |
| developer.apple.com/documentation/foundation | Unverified | Official documentation | — |
| docs.swift.org/…/concurrency/ | Confirmed indirectly | Official documentation | Pair with the Migration Guide. |
| developer.apple.com/design/human-interface-guidelines/ | Confirmed indirectly | Official guide | Verified 200 on 3 Nov 2026. |
| developer.apple.com/documentation/testing | Unverified | Official documentation | Swift 6.4 added XCTest interoperability (ST-0021). Verified 200 on 3 Nov 2026. |
| developer.apple.com/documentation/foundation/urlsession | Unverified | Official documentation | — |
| developer.apple.com/documentation/swiftdata | Unverified | Official documentation | — |
| developer.apple.com/documentation/observation | Unverified | Official documentation | — |
| developer.apple.com/tutorials/instruments | **Probably doesn't exist** | — | Replace with Xcode's text documentation on performance. |
| developer.apple.com/app-store/review/guidelines/ | Confirmed indirectly | Official guide | Verified 200 on 3 Nov 2026. |

### 1.2 Candidate URLs by topic

| Topic | Candidate URL | Status |
| --- | --- | --- |
| UITableView | developer.apple.com/documentation/uikit/uitableview | Unverified |
| Diffable data source | developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource | Unverified |
| Compositional layout | developer.apple.com/documentation/uikit/uicollectionviewcompositionallayout | Unverified |
| Scene-based life cycle | developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle and TN3187 | Confirmed; TN3187 verified 200 |
| NavigationStack | developer.apple.com/documentation/swiftui/navigationstack | Unverified |
| NavigationView (legacy) | developer.apple.com/documentation/swiftui/navigationview | Confirmed; availability "iOS 13.0–27.2" (deprecated) |
| @Observable | developer.apple.com/documentation/observation/observable() | Unverified |
| ObservableObject | developer.apple.com/documentation/combine/observableobject | Confirmed; open-ended availability (not deprecated) |
| Swift 6 migration guide | www.swift.org/migration/documentation/migrationguide/ | Unverified |
| Sendable | developer.apple.com/documentation/swift/sendable | Unverified |
| Keychain Services | developer.apple.com/documentation/security/keychain-services | Verified 200 on 3 Nov 2026 |
| Core Data | developer.apple.com/documentation/coredata | Unverified |
| WidgetKit, ActivityKit, App Intents | developer.apple.com/documentation/widgetkit, /activitykit, /appintents | App Intents confirmed indirectly; the rest unverified |
| UIViewRepresentable | developer.apple.com/documentation/swiftui/uiviewrepresentable | Unverified |
| XCTest | developer.apple.com/documentation/xctest | Unverified |
| TestFlight, App Store Connect | developer.apple.com/testflight/, developer.apple.com/help/app-store-connect/ | Confirmed indirectly |
| Upload requirements | developer.apple.com/news/upcoming-requirements/ | Confirmed |
| Xcode requirements | developer.apple.com/xcode/system-requirements/ | Confirmed; verified 200 |
| Swift on Wasm | www.swift.org/documentation/articles/wasm-getting-started.html | Confirmed (uses 6.4.2) |

Design recommendation adopted: every resource stores `status` and `verifiedAt`, and a workflow checks the links.

## 2. Technology update

### 2.1 Versions

| Component | Version | Date | Source |
| --- | --- | --- | --- |
| Swift | 6.4; 6.4.1; 6.4.2 | 15 Sep, 13 Oct, 30 Oct 2026 | swift.org blog; Swift Forums |
| Previous Swift | 6.3 (24 Mar 2026); 6.3.3 (30 Jun 2026, in Xcode 26.6) | — | Swift Forums |
| Xcode | 27.2 (27B52); Xcode 27 (27A266a) from 14 Sep 2026 | 29 Oct 2026 | Apple Developer Releases |
| iOS SDK | 27.2 | 26 Oct 2026 | Apple Developer Releases |
| Xcode 27 deployment targets | iOS 15–27, macOS 12–27, watchOS 9–27, visionOS 1–27 | — | Xcode system requirements |
| Current App Store requirement | Xcode 26+ with the iOS 26 SDK | Since 28 Apr 2026 | Upcoming Requirements |
| Announced requirement | iOS 27 SDK | From April 2027 | Apple Developer News (9 Sep 2026) |
| Swift Testing | In the 6.4 toolchain | — | XCTest interop (ST-0021), `CustomTestReflectable` (ST-0022), per-case repetition (ST-0024) |

Observation from Phase 7: GitHub Actions' `macos-latest` runner was using Xcode 26.6 with Swift 6.3.3 on November 3, 2026.

### 2.2 Changes in Swift 6.x

- **6.0 (Sep 2024):** strict concurrency by default in Swift 6 mode; Swift Testing; typed throws (SE-0413, to be reconfirmed against the changelog).
- **6.2 (Sep 2025):** Approachable Concurrency and default `@MainActor` isolation (SE-0466).
- **6.3 (Mar 2026):** `@c`, module selectors, official Android SDK, Swift Build preview in SwiftPM.
- **6.4 (Sep 2026):** `some P?` without parentheses (SE-0521); `@diagnose` (SE-0522); `::` selector (SE-0491); `await` in `defer` (SE-0493); `withTaskCancellationShield` (SE-0504); continuous observation of `@Observable` (SE-0506); `~Sendable` (SE-0518); `UniqueArray`, `UniqueBox`, `Iterable`; Subprocess 1.0; Swift Build as the default in SwiftPM.
- Xcode 27 *source break* related to SE-0508: reported by third parties, unverified.

### 2.3 WWDC26 (iOS 27)

- **SwiftUI:** document API (`WritableDocument`, `DocumentWriter`); reordering in any container; `swipeActions` outside `List`; new toolbar APIs; `.crossFade` transition; `Tab(role: .prominent)`; HTTP caching in `AsyncImage`; `@ContentBuilder`; `@State` as a macro with lazy initialization; updated Liquid Glass. Most of it isn't backward compatible.
- **UIKit:** scene-based life cycle required with the latest SDK. Automatic observation tracking (not verified in official notes).
- **SwiftData:** sectioned fetch requests and `ResultsObserver`.
- **Xcode 27:** agent skills; JSON project format in 27.2 beta (unverified).

### 2.4 Current, legacy and deprecated APIs

| Area | Current | Legacy API that's taught | Deprecated | Availability |
| --- | --- | --- | --- | --- |
| State | `@Observable`, `@State`, `@Bindable`, `@Environment` | `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` | — | Observation: iOS 17+ |
| SwiftUI navigation | `NavigationStack`, `NavigationSplitView`, `NavigationLink(value:)` | — | `NavigationView` and `NavigationLink(destination:tag:selection:)` since iOS 16 | iOS 16+ |
| UIKit life cycle | `UIScene` / `UIWindowSceneDelegate` | `UIApplicationDelegate` | Without scenes: doesn't launch with the iOS 27 SDK | Scenes since iOS 13 |
| Concurrency | async/await, tasks, actors, `Sendable`, `@MainActor`, AsyncSequence | GCD, completion handlers, `OperationQueue`, continuations | — | iOS 13+ with back-deployment |
| UIKit lists | Collection view + compositional + diffable + cell registration | Classic `UITableView` | — | iOS 13/14+ |
| Persistence | SwiftData | Core Data, `UserDefaults`, Keychain | — | SwiftData: iOS 17+ |
| UI | SwiftUI; programmatic UIKit | Storyboards, XIB | — | — |
| Testing | Swift Testing | XCTest, XCUITest | — | Interoperable since 6.4 |
| Reactivity | Observation + AsyncSequence | Combine | — | — |
| Experimental | Embedded Swift, Wasm in the browser, `UniqueArray` | — | — | Outside the core |

## 3. External curricula

| Reference | Sequence | Projects | Gaps |
| --- | --- | --- | --- |
| Stanford CS193p (spring 2025) | SwiftUI from day 1, MVVM, enums, layout, animation, persistence | Memorize and multi-screen apps | Predates iOS 26; little UIKit and testing; assumes experience |
| Apple Develop in Swift | Hello SwiftUI → containers → observable models → SwiftData → ML → visionOS | Chat Prototype, Alphabetizer, GratefulMoments | No UIKit, little concurrency, no algorithms |
| Hacking with Swift | Theory + project + consolidation; *Concurrency by Example* | Many small projects | Whether 100 Days of Swift (UIKit) was updated is unverified |
| Kodeco | Topic books with a running project | Real-time stock apps | Editions tied to Swift 5.5 |
| Udemy, Coursera | Unverified | — | — |
| Swift.org, Forums, Evolution | SE-xxxx proposals | — | Documents for experts |

Common gaps: deep UIKit; strict concurrency and migrating from GCD; testing; accessibility; Instruments; architecture and SPM; algorithms in Swift; mobile system design; distribution.

The proposed curriculum matrix (M0–M20) became the 15-stage, 49-module map in `content/curriculum.yaml` (see `03-curriculum-design.md`).

## 4. Algorithms and interviews

### 4.1 NeetCode 150 patterns

150 problems in 18 categories (a superset of Blind 75). The difficulty breakdown differs across third parties: 28/97/25 (crackr.dev), 28/101/21 (copilotinterview.com, crackedprep.com, thita.ai), 28/100/22 (leetcode-py); unverified on neetcode.io.

| # | Category | Representative problems |
| --- | --- | --- |
| 1 | Arrays & Hashing | Contains Duplicate, Valid Anagram, Two Sum, Group Anagrams, Top K Frequent, Product of Array Except Self |
| 2 | Two Pointers | Valid Palindrome, Two Sum II, 3Sum, Container With Most Water, Trapping Rain Water |
| 3 | Sliding Window | Best Time to Buy/Sell Stock, Longest Substring Without Repeating, Minimum Window Substring |
| 4 | Stack | Valid Parentheses, Min Stack, Daily Temperatures, Generate Parentheses |
| 5 | Binary Search | Binary Search, Search in Rotated Sorted Array, Koko Eating Bananas |
| 6 | Linked List | Reverse Linked List, Linked List Cycle, Reorder List, LRU Cache |
| 7 | Trees | Invert Tree, Max Depth, LCA of BST, Level Order, Validate BST |
| 8 | Tries | Implement Trie, Word Search II |
| 9 | Heap | Kth Largest, Find Median from Data Stream |
| 10 | Backtracking | Subsets, Permutations, Combination Sum, Word Search |
| 11 | Graphs | Number of Islands, Max Area of Island, Pacific Atlantic, Course Schedule |
| 12 | Advanced Graphs | Network Delay Time, Min Cost to Connect Points |
| 13 | 1-D DP | Climbing Stairs, House Robber, Coin Change, LIS |
| 14 | 2-D DP | Unique Paths, LCS, Edit Distance |
| 15 | Greedy | Jump Game, Maximum Subarray |
| 16 | Intervals | Merge Intervals, Insert Interval, Meeting Rooms |
| 17 | Math & Geometry | Rotate Image, Spiral Matrix |
| 18 | Bit Manipulation | Single Number, Number of 1 Bits |

Swift quirks: indexing a `String` is expensive (convert to an `Array`); no heap or deque in the standard library (`swift-collections` has them, but they're usually not allowed in interviews); `Dictionary(default:)`, `reduce(into:)`, `inout`.

### 4.2 iOS engineer interviews

Based on third-party guides (a trend, not a guarantee):

- **Coding:** medium-level LeetCode; mobile variants like an LRU cache, an image loader with cancellation, debounce/throttle, pagination.
- **Swift/platform:** ARC and cycles; value vs. reference; GCD vs. async/await; actors and data races (where most candidates lose points on follow-ups); the UIKit life cycle; `@State`, `@Observable`, `ObservableObject`; diffable.
- **Mobile system design:** feed, chat with images, image cache, App Store, stock ticker, offline-first sync. Framework: requirements → API and communication → models → layers → offline, sync and conflicts → performance, accessibility, privacy and observability. At Apple it's described as "on-device first".
- **Text resources:** *Cracking the Mobile System Design Interview* (themobileinterview.com), mobiledesignrounds.com, the weeeBox/mobile-system-design repository (unverified), *App Architecture* (objc.io), *33 Engineering Challenges of Building Mobile Apps at Scale*.

## 5. Running Swift in the browser

| Option | Maintenance | Compiles user code on the client | Limitations |
| --- | --- | --- | --- |
| Swift SDK for Wasm | Active; JavaScriptKit bridge up to 40 times faster in 6.4 according to swift.org | No | No UIKit/SwiftUI; partial Foundation |
| JavaScriptKit + PackageToJS | Active | No | Same |
| carton | Archived (29 Nov 2025) | No | Don't use |
| swiftc/LLVM to Wasm | No maintained project | In theory | Hundreds of MB (estimate) |
| MiniSwift | Personal project (2026) | Yes, a subset | Semantics not guaranteed |
| SwiftFiddle | Active | No (server) | External dependency, no offline use |
| pad.swiftwasm.org | Community | No | Same |
| Godbolt | Unverified | No | Geared toward assembly |
| Runner on localhost | Our own | Compiles on the Mac | Strictly speaking, breaks "no backend" |

Recommendation adopted: exercises with Swift Testing tests run in Xcode or with `swift test`; no porting the compiler and no relying on third-party playgrounds.

## 6. Stack recommendations (research)

| Decision | Research recommendation | Final decision |
| --- | --- | --- |
| Framework | Astro 6 + React islands | Vite 8 + React 19 (npm showed Astro 7.x; we avoided depending on unverified APIs, and the app is almost entirely client-side) |
| Validation | Content collections + Zod 4 | Zod 4 with a custom validator shared by the browser, the script and the tests |
| Editor | CodeMirror 6 (`@codemirror/legacy-modes`, Swift mode) | Same, loaded on demand |
| Highlighting | Shiki at build time | highlight.js on the client (Swift, bash, JSON) |
| Search | Pagefind or MiniSearch | MiniSearch |
| Persistence | IndexedDB with Dexie + JSON export | Same |
| Review | ts-fsrs 6, pin FSRS-6 or FSRS-7, keep the full log | ts-fsrs 6 with FSRS-7 and a `revlog` table |

## Risks and caveats

- URL verification was incomplete during the research (resolved later for the registered resources).
- Several WWDC26 details come from blogs or aggregators.
- Not researched: Udemy and Coursera syllabi, Godbolt, and the maintenance status of MiniSearch, FlexSearch, Pagefind, Fuse, Dexie and Shiki.
- Performance figures for MiniSwift and JavaScriptKit are as stated by their authors, not independently measured.

## Main sources

- Apple Developer Releases: https://developer.apple.com/news/releases/
- Swift 6.4 Released: https://www.swift.org/blog/swift-6.4-released/
- Transitioning to the UIKit scene-based life cycle: https://developer.apple.com/tutorials/data/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle.md
- TN3187: https://developer.apple.com/tutorials/data/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle.md
- NavigationView: https://developer.apple.com/tutorials/data/documentation/swiftui/navigationview.md
- ObservableObject: https://developer.apple.com/tutorials/data/documentation/combine/observableobject.md
- Upcoming requirements: https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- Xcode system requirements: https://developer.apple.com/xcode/system-requirements
- Swift and Wasm: https://www.swift.org/documentation/articles/wasm-getting-started.html
- Announcing Swift 6.3.3: https://forums.swift.org/t/announcing-swift-6-3-3/87888
- What's new in Swift, March 2026: https://www.swift.org/blog/whats-new-in-swift-march-2026/
- Xcode 27.2: https://developer.apple.com/news/releases/?id=10292026a
- Xcode 27: https://developer.apple.com/news/releases/?id=09142026h
- Submitting: https://developer.apple.com/app-store/submitting/
- Implementation status update: https://forums.swift.org/t/implementation-status-update-for-recent-language-and-library-proposals/89295
- WWDC26 SwiftUI guide: https://developer.apple.com/wwdc26/guides/swiftui/
- What is new in SwiftUI after WWDC26: https://swiftwithmajid.com/2026/06/08/what-is-new-in-swiftui-after-wwdc26/
- Develop in Swift: https://developer.apple.com/tutorials/develop-in-swift/welcome-to-develop-in-swift-tutorials
- CS193p 2025: https://9to5mac.com/2025/12/19/watch-stanford-university-2025-cs193p-ios-development-course/
- Hacking with Swift, Concurrency: https://www.hackingwithswift.com/quick-start/concurrency
- Kodeco, Modern Concurrency in Swift: https://www.kodeco.com/books/modern-concurrency-in-swift/v1.0/chapters/1-why-modern-swift-concurrency
- Swift Evolution: https://github.com/swiftlang/swift-evolution
- NeetCode 150: https://acehired.com/coding-interview/neetcode-150
- Apple mobile engineer interview: https://spacecomplexity.ai/blog/apple-mobile-engineer-interview
- Mobile design rounds: https://mobiledesignrounds.com/
- Cracking the Mobile System Design Interview: https://themobileinterview.com/cracking-the-mobile-system-design-interview/
- LiveCodes issue on Swift in Wasm: https://github.com/live-codes/livecodes/issues/351
- Swift SDKs for WebAssembly: https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405
- carton releases: https://github.com/swiftwasm/carton/releases
- MiniSwift: https://forums.swift.org/t/miniswift-swift-compiler-that-runs-in-the-browser-via-webassembly/85808
- SwiftFiddle: https://swiftfiddle.com/
- Astro 6: https://astro.build/blog/astro-6/
- CodeMirror legacy modes: https://github.com/codemirror/legacy-modes
- Swift and Kotlin languages for CodeMirror 6: https://discuss.codemirror.net/t/new-codemirror-6-language-packages-for-kotlin-and-swift/9882
