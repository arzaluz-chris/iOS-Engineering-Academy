# Project status

Last updated: November 4, 2026 (after Module 48; Module 49 is being checked).

## Done

**Language and design (3 Nov 2026):** the whole academy (content, UI and docs) was moved to English, and the site was redesigned after swift.org's visual language. The owner's original specification (`docs/ESPECIFICACION.md`) stays in Spanish.

- Content: all 19 lessons, 5 challenges, 17 interview questions, 8 projects, the curriculum map and the resources were rewritten in English (not word-for-word translations). Code identifiers and string literals are English now, so outputs changed; every output was re-verified by the snippet tests (17 predictions and 98 Swift blocks pass). Some examples were adapted: amounts in pesos became dollars or unlabeled numbers (the m02-l01 restaurant bill is now $200, the m02-l01-e6 tickets $12/$8), Mexican places became generic ones, "NIP" became "PIN". IDs did not change, so saved progress still lines up.
- Format: frontmatter enums, exercise types, callouts and snippet markers are English (`tested`, `prediction`, `[!note]`, `swift no-compile`…; see `docs/CONTENT.md`). Routes are English (`#/lesson/…`, `#/curriculum`, `#/challenges`…); old Spanish URLs no longer resolve. Values stored in IndexedDB (lesson status, attempt results, card sources) stay in Spanish on purpose, because renaming them would orphan existing progress; they're never shown on screen.
- Design: system font stack (SF Pro on Apple devices), translucent sticky top navigation, a swift.org-style peach hero on the home page with an orange gradient pill button, 22px rounded cards, Xcode-like syntax colors, an indigo footer with a Light/Dark/Auto switch, and a navy dark mode. The IBM Plex and Source Serif fonts were removed. Checked in Chromium at 1440 px and 390 px, light and dark, with no console errors and no horizontal page scroll.

**Platform (Phase 5 complete):** curriculum navigation, lessons, all eight exercise formats, automatic and rubric grading, challenges with progressive reveal and three practice modes, an interview simulator with follow-ups and results by category, projects with milestones, FSRS spaced review, notes, bookmarks, global search, a dashboard with real data, validated export and import, light and dark mode, responsive layout, deployment to GitHub Pages.

**Content:**

| Type | Written | Planning target |
| --- | --- | --- |
| Stages | 15 (full map) | 12–16 |
| Modules | 49 on the map; 48 with lessons (M1 to M48) | — |
| Lessons | 283 (M1: 3, M2: 5, M3: 5, M4–M18, M20–M25, M28–M41, M43 and M46–M48: 6 each, M19, M27 and M42: 7, M26, M44 and M45: 5); 281 `tested`, 2 `no-code` | more than 100 |
| Lesson exercises | 1,680 (prediction 341, comprehension 301, solve 284, find-errors 249, fill-in 211, explain 127, design 123, refactor 44) | at least 100 |
| Review cards | 1,360 | — |
| Coding challenges | 5, with Swift solutions and tests | at least 100 |
| Interview questions | 210 across 14 categories (swift 35, uikit 22, concurrency 20, swiftui 19, architecture 17, system-design 15, security 13, testing 12, networking 11, platform 10, memory 9, performance 9, persistence 9, tooling 9) | a broad bank |
| Projects | 8 specified with milestones | 8 |
| Resources | 377; 21 verified, 356 with `status: unverified` (each returned 200 when added) | — |

Stages 1 and 2 (M1–M8) are complete, Stage 3 has M9 to M13 (data modeling, OOP and protocols, generics and functional programming, error handling, memory management), M14 (Professional Tools: packages, Git, pull requests, naming and SOLID; its Git output comes from real runs of Git 2.43 against throwaway repositories, and its Xcode steps are from Apple's docs, not checked in Xcode), and the algorithms stage has M15 (Algorithmic Complexity), M16 (Arrays, Hashing and Windows) and M17 (Stacks, Queues and Linked Lists; what it says about deep linked-list teardown was measured on Linux only and is labeled that way) and M18 (Recursion, Backtracking and Sorting; claims about Swift's sort quote only Apple's documentation, which guarantees stability and O(n log n) but doesn't name the algorithm) and M19 (Trees, Heaps and Graphs: traversals, BSTs, tries, heaps, BFS and DFS, topological sort, union-find) and M20 (Greedy Algorithms and Dynamic Programming), which completes the algorithms stage. Stage 6 has M21 (How an iOS App Works), and Stage 7 has M22 (UIKit Fundamentals), M23 (Layout in UIKit), M24 (Components and Lists), M25 (Navigation in UIKit), M26 (Events and Communication Between Components) and M27 (Advanced UIKit), which completes the UIKit stage. Stage 8 (concurrency) has M28 (Threads, Queues and GCD) and M29 (Swift Concurrency; the Swift Evolution proposals it cites were checked against the swift-evolution repository, including which are Swift 6.2 and which 6.4). Stage 9 starts with M30 (Networking), whose examples run against an injected transport with canned responses, so no test touches the network, and M31 (Persistence), whose Core Data, SwiftData and Keychain code is type-checked against the iOS SDK, and M32 (App Architecture), which builds the same reading-list feature in MVC, MVVM, MVP and Clean Architecture, and M33 (Testing and Debugging), whose Swift Testing and XCTest suites are shown as `illustrative` blocks because the snippet harness can't run a test suite; each one was built and run with `swift test` in a package (Swift 6.3, Linux), and Linux-specific behavior is labeled. Stage 10 (SwiftUI) starts with M34 (SwiftUI Fundamentals), whose views are type-checked against the iOS SDK and whose result builder and layout model run on Linux, M35 (Layout and Navigation in SwiftUI) and M36 (State Management; Xcode 27 differences such as the State macro are labeled with the version) M37 (Architecture and Data in SwiftUI) M38 (Interaction and User Experience in SwiftUI) and M39 (Advanced SwiftUI), completing the SwiftUI stage. Stage 11 has M40 (UIKit and SwiftUI Interoperability), and Stage 12 starts with M41 (Production Quality and Distribution; App Review guideline numbers and App Store Connect limits come from Apple's current pages, and anything not verified is labeled) and M42 (Secure iOS Development, organized around OWASP MASVS v2 with MASVS/MASTG details checked on mas.owasp.org) and M43 (Performance, Accessibility and Internationalization; every threshold is quoted from Apple's documentation). Stage 13 (optional) has M44 (System Extensions) and M45 (Platform Frameworks; the macOS check caught that `Transaction` is ambiguous when a file imports both SwiftUI and StoreKit, and the lesson now teaches `StoreKit.Transaction`). Stage 14 (interviews) has M46 (A Method for Coding Challenges), written ahead of M45 because it only depends on M20, M47 (iOS Technical Questions, which teaches how to answer and builds on the interview bank without duplicating it) and M48 (Mobile System Design). The snippet tests run 341 predictions and 1926 Swift blocks, and type-check 525 iOS blocks against the iOS SDK on the macOS runner; all pass on Swift 6.3.3 (Linux container) and in CI on macOS.

**Interview bank (3 Nov 2026):** questions were chosen from what real iOS interviews ask (interview write-ups, prep guides, articles) and cover every topic in the table of contents of a popular interview-prep book the owner provided. Nothing was copied from any source: every answer was written for this course and checked against primary sources (Swift Evolution, The Swift Programming Language, Apple documentation); Swift code in answers was compiled and run in the container. A private fact-check of that book (errors, outdated claims, broken code) was given to the owner and is not in the repository.

**Lesson code:** 17 of 19 lessons have `codeStatus: tested`; the other two (m01-l01 and m01-l03) are `no-code`. No lesson is left at `reviewed`. "Tested" means the `swift/Tests/LessonSnippetsTests` target compiles and runs every Swift block in the lesson and in its exercise solutions, and compares the output with what the text claims. Every prediction exercise, in any lesson, is run and its `output` compared exactly; for pseudocode predictions (`lang: pseudo`, Module 2) the Swift translation is what runs. The tests also check the compiler errors (`swift no-compile`), warnings (`swift warning`) and runtime errors (`swift runtime-error`) the lessons quote. What isn't run: blocks marked `swift illustrative` (the `Package.swift` manifest, a package's `@main` template and the declaration of `print` in m03; the `@main` solution in m03-l03-e4), terminal commands, and what's described about the Xcode UI, which was taken from Apple's documentation and couldn't be checked in Xcode from the build environment.

**Tests run in the build environment:** `npm run validate` (no errors), `npm test` (35 tests, all pass), `npm run build` (succeeds), `swift test` in the `swift:6.3` container (Swift 6.3.3, Linux), a visual check in Chromium with no console errors.

**Swift in CI:** the `swift.yml` workflow ("Swift · challenge tests") runs `swift test` on macOS (Xcode 26.6, Swift 6.3.3) on every push that touches `swift/` or `content/lessons/`. It passed for every batch in this increment. The runner doesn't use Xcode 27 / Swift 6.4 yet; the code uses nothing specific to 6.4.

**Published:** https://arzaluz-chris.github.io/iOS-Engineering-Academy/

**Links:** the `links.yml` workflow checks that links exist (for Apple's documentation it queries the JSON data). It checks that a link responds, not that the content matches the topic; that was reviewed when each resource was written.

## Platform changes in this increment

- Prediction exercises with `lang: pseudo` (schema, component and validator, with tests in `tests/content.test.ts` and `tests/ui.test.tsx`): they're shown as pseudocode, and the validator requires a Swift translation in the solution.
- The `LessonSnippetsTests` Swift target and the code block markers `no-compile`, `warning`, `runtime-error` and `illustrative`, documented in `docs/CONTENT.md`.
- The `swift ios` marker (4 Nov 2026): Apple-framework blocks are type-checked against the iOS simulator SDK when Xcode is present (the macOS runner; skipped on Linux). A self-test proves it rejects broken UIKit code. Modules 21–48's 525 iOS blocks passed it with Xcode 26.6. The macOS run also caught a portability bug the Linux container can't: plain-Swift code that builds `CGRect` with only `import Foundation` compiles on Linux but not on macOS, where those initializers come from CoreGraphics. Such blocks import CoreGraphics when it's available. It also showed that in Swift 6 mode, Sendable violations in closures passed straight to `DispatchQueue.async` are errors on Linux but warnings with Apple's SDK; Module 28's examples use a closure parameter the lesson declares `@Sendable`, so they fail on both, and the text tells Xcode users to treat those warnings as errors. In M38 one SwiftUI `body` made the type checker time out ("unable to type-check this expression in reasonable time"); splitting the chain and typing literals didn't help, moving inline `sensoryFeedback`/`onChange` closures into named functions with explicit types did, and the lesson explains that.

## Acceptance criteria not yet met

- 100 challenges: only 5 exist. (More than 100 lessons and 100 exercises: met, with 283 lessons and 1,680 exercises; module 49 are still missing.)
- Swift taught in depth, UIKit and SwiftUI with full stages: today only their plan exists.
- Automated accessibility tests: not implemented.
- The Xcode UI instructions in Module 3 (menus, shortcuts, *Settings › Components*, the debugger) haven't been checked in a real Xcode.

## Next step

1. Module 49 (Professional Work), the last one, is written and being checked on macOS of the UIKit stage in curriculum order. Apple-framework code is written as ```` ```swift ios ```` blocks, type-checked (not run) against the iOS simulator SDK on the macOS CI runner; a module with such blocks is checked on a branch with a manual workflow run before it goes to `main` in curriculum order.
2. After all modules are done (the owner's instruction, 4 Nov 2026): the coding challenges, up to the 100 the specification asks for, each with a Swift solution, Swift Testing tests and a card, following the patterns of M15–M20.
3. Check Module 3's Xcode UI instructions in Xcode 27 and, if they match, note it here.
4. When the links workflow confirms the 356 unverified resources, change their `status` to `verified` with a date.

How a module is produced: one agent per module with a fixed list of lesson ids and titles, following `docs/CONTENT.md`; every code block and prediction must pass `LessonSnippetsTests` before the module is accepted. Each module is then verified on a clean checkout of `main` containing only that module (`npm run validate`, `tsc`, `vitest`, `vite build`, `swift test`) and committed on its own.

For each batch: write the lessons, run `cd swift && swift test` (or the `swift:6.3` container), set `codeStatus` according to what the tests ran, `npm run validate && npm test && npm run build`, check in the browser, commit and push, and check the Swift workflow.

## Picking this up in another session

Read `CLAUDE.md` at the root, then this file and `docs/CONTENT.md`. The schema is in `src/content/schema.ts`; lesson m04-l01 is the reference model of a lesson (it uses seven of the eight exercise formats; it has no `design` exercise). To run Swift without Xcode: `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test` (if the Docker daemon isn't running, start it with `dockerd`).
