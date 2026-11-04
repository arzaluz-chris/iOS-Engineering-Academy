---
id: m43-l06
title: Compatibility across OS versions and legacy code
description: "Most professional iOS work happens in code someone else wrote, for OS versions older than the one on your phone. You choose a deployment target from your own usage data, gate newer APIs with #available, #unavailable and @available, write compatibility shims so call sites stay clean, understand what @backDeployed does and why it's for libraries, find and replace deprecated APIs such as UIScreen.main, map an unfamiliar codebase by entry points and change hotspots, pin current behavior with characterization tests over a grid of inputs, and refactor in small, reversible steps: expand and contract, seams for singletons, and a parallel run that compares old and new before you switch."
module: m43
order: 6
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m43-l05, m14-l05, m40-l06]
objectives:
  - Choose a deployment target from usage data and know which APIs it makes available without checks.
  - Gate newer APIs with #available, #unavailable and @available, and wrap them in shims so call sites don't branch.
  - Explain what @backDeployed does, its requirements, and why apps rarely need it.
  - "Find and replace deprecated APIs, and deprecate your own with renamed: so the compiler guides callers."
  - Map an unfamiliar codebase starting from entry points, the build, and the files that change most.
  - Pin behavior with characterization tests over an input grid, then refactor in small steps and compare old and new with a parallel run.
terms:
  - term: Deployment target
    definition: "The oldest OS version the app runs on. APIs introduced at or before it can be used directly; newer ones need an availability check."
  - term: Availability check
    definition: "#available(iOS 18, *) at run time, #unavailable for the inverse, and @available(iOS 18, *) on declarations. The * means any other platform, at its minimum version."
  - term: "@backDeployed"
    definition: "An attribute (Swift 5.8) that copies a function's implementation into callers running on OS versions before the one where it shipped. It's for ABI-stable libraries such as Apple's SDKs; requirements include public or @usableFromInline and an inlinable body."
  - term: Characterization test
    definition: "A test that records what code does now, including behavior that looks wrong, so a refactoring can be checked against it. Michael Feathers named them in Working Effectively with Legacy Code."
  - term: Expand and contract
    definition: "Changing an API in steps: add the new form alongside the old (expand), move callers over, then remove the old one (contract). Each step ships on its own."
  - term: Parallel run
    definition: "Running the old and new implementation on the same inputs and comparing results before switching, in tests over many inputs or, carefully, in production."
mastery:
  - Pick a deployment target from a usage table and list the API checks it removes.
  - Write a SwiftUI shim that uses an iOS 26 modifier when available and a fallback otherwise.
  - "Deprecate a function with renamed: and read the compiler's warning and fix-it."
  - Rank a repository's files by change frequency and size to decide where to read first.
  - Write characterization checks for a legacy function, including its edge cases, and keep them passing through a refactoring.
  - Compare two implementations over every combination of a small input grid and report mismatches.
resources: [xcode-running-code-specific-version, swift-book, swift-evolution, swift-api-design-guidelines, fowler-test-double, git-commit-reference]
cards:
  - id: m43-l06-c1
    front: What does the * in #available(iOS 18, *) mean?
    back: "Any other platform, at its minimum deployment target. On iOS the check is iOS 18 or later; on macOS, visionOS and others the branch runs on every version. It's required, so adding a platform later doesn't silently skip code."
  - id: m43-l06-c2
    front: What does @backDeployed do, and who uses it?
    back: "It emits a copy of a function's implementation into callers, used when running on OS versions before the one in before:. It's for libraries that ship with the OS (Apple's SDKs); the symbol must be public or @usableFromInline and its body inlinable. Apps write #available shims instead."
  - id: m43-l06-c3
    front: How do you rename your own API without breaking callers?
    back: "Expand and contract: add the new function, mark the old one @available(*, deprecated, renamed: \"new(name:)\", message: …) and forward it; callers get a warning with a fix-it. When none remain, delete it (or mark it unavailable with renamed: for a release, which turns use into an error)."
  - id: m43-l06-c4
    front: Where do you start reading an unfamiliar iOS codebase?
    back: "Build and run it; read the entry points (App or AppDelegate, SceneDelegate, the root coordinator); follow one main task end to end; then use version control to find the files that change most, and read their tests (or note that there are none)."
  - id: m43-l06-c5
    front: What makes characterization tests useful before a refactoring?
    back: "They record current outputs, odd ones included, for inputs that cover each branch and boundary. The refactoring must keep them passing; behavior changes (bug fixes) go in a separate, later change that updates the expected values on purpose."
---

## The idea in one sentence

**Legacy code is code you need to change but can't yet change safely**; the work is making it safe (know which OS versions you support, pin today's behavior with tests) and then changing it in steps small enough that each one can ship or be undone.

> [!note] Sources and what was checked
> `#available`, `@available` and `#if` usage come from Apple's "Running code on a specific platform or OS version" and the Swift book's Attributes chapter, which also documents `@backDeployed`; deprecations from Apple's pages for `UIScreen.main` and `UIApplication.keyWindow`; `glassEffect(_:in:)` and `background(_:in:fillStyle:)` from their reference pages. All read in November 2026. The Swift compiler diagnostics in this lesson were produced by Swift 6.3. "Characterization test" and "seam" are Michael Feathers' terms from *Working Effectively with Legacy Code* (2004); expand and contract and the parallel run are common industry practice, described here in my own words rather than quoted. The SwiftUI and UIKit blocks are type-checked against the iOS SDK, not run. The usage, hotspot and refactoring examples are plain Swift, compiled and run with Swift 6.3, on invented data.

## Choosing what you support

Apple's article frames the trade-off: "Rather than require the latest system software for each app update, target one or two older operating system versions to give people time to transition gradually." The data that decides it is your own: the OS versions of people who actually use your app, from your analytics or App Store Connect, not industry-wide numbers.

Pantry raises its deployment target once a year, after the new iOS ships. The rule the team agreed on: drop the oldest versions as long as, together, they're used by no more than 3% of active customers.

```swift
struct VersionShare {
    let major: Int
    let perMille: Int        // share of last month's active users, in thousandths
}

/// The lowest version to keep, dropping the oldest ones while their total share stays within the limit.
func deploymentTarget(for shares: [VersionShare], maxDroppedPerMille: Int) -> (target: Int, dropped: Int) {
    let ordered = shares.sorted { $0.major < $1.major }
    var dropped = 0
    for share in ordered.dropLast() {            // the newest version is never dropped
        if dropped + share.perMille > maxDroppedPerMille {
            return (share.major, dropped)
        }
        dropped += share.perMille
    }
    return (ordered.last?.major ?? 0, dropped)
}

let pantryUsers = [
    VersionShare(major: 26, perMille: 703),
    VersionShare(major: 18, perMille: 205),
    VersionShare(major: 17, perMille: 63),
    VersionShare(major: 16, perMille: 21),
    VersionShare(major: 15, perMille: 8),
]
let decision = deploymentTarget(for: pantryUsers, maxDroppedPerMille: 30)
print("deployment target: iOS \(decision.target), dropping \(decision.dropped)‰ of active users")
```

```output
deployment target: iOS 17, dropping 29‰ of active users
```

- **iOS 15 and 16 together are 2.9%**, under the limit; adding iOS 17's 6.3% would exceed it. So the target becomes iOS 17.
- **The shares are Pantry's**, not Apple's. A banking app might keep older versions longer; an app built around a new framework might move faster.
- **`dropLast()`** keeps the newest version whatever the limit, so an absurdly high limit can't drop everything.
- What raising the target buys is concrete: every API introduced in iOS 17 or earlier (Observation, SwiftData, `ContentUnavailableView`, the `scrollPosition` APIs) can be used with no checks, and the `if #available(iOS 17, *)` branches in the codebase become dead code to delete.

People on dropped versions keep the version they have (and the App Store can offer them the last compatible one); they just stop getting updates.

## Using newer APIs on older targets

Above the deployment target, every newer API needs a check. Apple's article shows the three tools:

- **`#if os(iOS)`, `#if targetEnvironment(simulator)`, `#if canImport(UIKit)`** decide what's **compiled**. `canImport` "tests whether it's possible to import a module, but doesn't actually import it."
- **`if #available(iOS 18, *)`** decides what **runs**. "The `*` matches any other operating system." `#unavailable` (Swift 5.6) is the inverse, for the fallback-first case.
- **`@available(iOS 18, *)` on a declaration** moves the requirement to the caller: "you remove the need to check again inside the body."

### Shims keep call sites clean

Pantry's design wants Liquid Glass cards on iOS 26 and the current material on older versions. Writing `if #available` in forty views spreads the version logic everywhere and makes it impossible to delete later. A **shim** puts it in one place:

```swift ios
import SwiftUI

extension View {
    /// Pantry's card background: Liquid Glass on iOS 26, a material on earlier versions.
    @ViewBuilder
    func pantryCardBackground() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }
}

struct PromoCard: View {
    let title: String

    var body: some View {
        Text(title)
            .padding()
            .pantryCardBackground()
    }
}
```

- **One `#available` for the whole app.** When the deployment target reaches iOS 26, the shim's body becomes one line and the call sites don't change.
- **`@ViewBuilder`** lets the two branches return different view types.
- **Don't check the version to decide behavior that isn't about API availability.** "If iOS 18, use the new checkout" is a feature flag pretending to be an availability check; it can't be turned off when the new checkout has a bug.

### @backDeployed is for libraries

You'll see `@backDeployed` in Apple's SDK interfaces and in Module 35, where SwiftUI's `topBarLeading` is `@backDeployed(before: iOS 17.0)`. The Swift book explains it: the attribute includes "a copy of the symbol's implementation in programs that call or access the symbol," so a function that shipped in iOS 17 also works on iOS 16 through the copy, while iOS 17 and later use the system's version. The requirements: the declaration is `public` or `@usableFromInline`, class methods are `final` and not `@objc`, and "the implementation satisfies the requirements for an inlinable function."

It exists because Apple's frameworks ship with the OS. Your app ships its own code, so the same function is available on every OS version you support already. Apps need `@backDeployed` only when they publish an ABI-stable binary framework, which almost none do. What apps do instead is the shim above.

## Deprecations

A deprecated API still works, but its documentation tells you it's going away or has a better replacement. In an older codebase you'll meet a lot of them. Two Pantry still had:

- **`UIApplication.keyWindow`**, deprecated in iOS 13: "Should not be used for applications that support multiple scenes as it returns a key window across all connected scenes."
- **`UIScreen.main`**, deprecated in iOS 26: "Use a UIScreen instance found through context instead (i.e, view.window.windowScene.screen), or for properties like UIScreen.scale with trait equivalents, use a traitCollection found through context."

Whether the compiler warns about a deprecated API in your build depends on your deployment target and SDK; that wasn't checked for this lesson, so don't rely on the warning list alone. Search the codebase for the names Apple's documentation marks deprecated, and replace each with what the page recommends:

```swift ios
import UIKit

@MainActor
final class ProductImageView: UIView {
    /// Before: UIScreen.main.scale, which assumes one screen and is deprecated.
    func pixelSize(forPoints points: CGSize) -> CGSize {
        let scale = traitCollection.displayScale        // the screen this view is actually on
        return CGSize(width: points.width * scale, height: points.height * scale)
    }

    /// Before: UIApplication.shared.keyWindow.
    var hostingScreenBounds: CGRect? {
        window?.windowScene?.screen.bounds
    }
}
```

The replacements answer the question for **this view**, which matters on iPad with multiple windows and on external displays, where "the main screen" is the wrong one.

### Deprecating your own APIs

The same mechanism helps when you change your own code. Pantry's `PriceFormatter.format(_:)` assumed dollars; the replacement takes a currency. Instead of renaming it in one giant change, the old method stays, forwards to the new one, and is marked deprecated with `renamed:`:

```swift warning 'format' is deprecated
struct PriceFormatter {
    @available(*, deprecated, renamed: "string(fromCents:currencyCode:)", message: "Pass the order's currency.")
    func format(_ cents: Int) -> String {
        string(fromCents: cents, currencyCode: "USD")
    }

    func string(fromCents cents: Int, currencyCode: String) -> String {
        "\(currencyCode) \(cents / 100).\(cents % 100 < 10 ? "0" : "")\(cents % 100)"
    }
}

let formatter = PriceFormatter()
print(formatter.format(1999))
print(formatter.string(fromCents: 505, currencyCode: "EUR"))
```

```output
USD 19.99
EUR 5.05
```

Swift 6.3 reports the old call as `warning: 'format' is deprecated: Pass the order's currency.` with a note, `use 'string(fromCents:currencyCode:)' instead`, which Xcode shows as a fix-it. Every caller still compiles, and the warning list is now the migration's to-do list. When it's empty, delete the old method. If other teams depend on it, there's an intermediate step: `unavailable` with `renamed:` turns any remaining use into an error that still names the replacement:

```swift no-compile has been renamed to 'removeAll(keepingCapacity:)'
struct CartStore {
    @available(*, unavailable, renamed: "removeAll(keepingCapacity:)")
    func clear() {}

    func removeAll(keepingCapacity: Bool) {}
}

CartStore().clear()
```

Swift 6.3: `error: 'clear()' has been renamed to 'removeAll(keepingCapacity:)'`. This is **expand and contract**: add the new API (expand), migrate callers while both exist, remove the old one (contract). Each step is a separate, shippable change.

## Reading an unfamiliar codebase

On your first week with Pantry's code, there's too much to read. A route that works:

1. **Build and run it**, on a device and in the simulator. Note every warning count, every setup step that isn't documented, every crash. That's your first contribution: write them down.
2. **Read the entry points**: the `@main` type (an `App` or an `AppDelegate`), the scene delegate, the root view controller or coordinator. Module 21's launch sequence tells you what runs in which order.
3. **Follow one main task end to end.** For Pantry, "add a product to the cart": from the tap, through the view controller, the view model, the cart service, the network client and back. You'll meet most of the architecture on one path.
4. **Find where change happens.** Files that change often are where your work will be, and where bugs cluster. Version control already knows:

   ```sh
   git log --since="12 months ago" --name-only --format="" -- '*.swift' | sort | uniq -c | sort -rn | head -20
   ```

5. **Read the tests**, or note their absence. A file that changes every sprint and has no tests is the riskiest thing in the repository.

Change frequency alone puts tiny configuration files at the top. Weighting it by size (a stand-in for complexity) gives a better reading list:

```swift
struct FileHistory {
    let path: String
    let commitsLastYear: Int
    let lines: Int
}

let history = [
    FileHistory(path: "Checkout/CheckoutViewController.swift", commitsLastYear: 48, lines: 1_850),
    FileHistory(path: "Config/FeatureFlags.swift", commitsLastYear: 61, lines: 120),
    FileHistory(path: "Catalog/CatalogViewModel.swift", commitsLastYear: 22, lines: 640),
    FileHistory(path: "Networking/APIClient.swift", commitsLastYear: 9, lines: 900),
    FileHistory(path: "Cart/CartService.swift", commitsLastYear: 35, lines: 410),
    FileHistory(path: "Legacy/OrderParser.m", commitsLastYear: 1, lines: 2_400),
]

let ranked = history.sorted { $0.commitsLastYear * $0.lines > $1.commitsLastYear * $1.lines }
for file in ranked.prefix(4) {
    print("\(file.commitsLastYear * file.lines)\t\(file.path)")
}
```

```output
88800	Checkout/CheckoutViewController.swift
14350	Cart/CartService.swift
14080	Catalog/CatalogViewModel.swift
8100	Networking/APIClient.swift
```

- **The checkout controller dominates**: changed 48 times, nearly 2,000 lines. That's where Pantry's next refactoring should go, and where characterization tests come first.
- **Feature flags change most often** but are small and simple; they drop to fifth.
- **The 2,400-line Objective-C parser** is big but nobody touches it. Leave it alone until a change requires it.
- This "change frequency times size" ranking is a heuristic popularized by Adam Tornhill (*Your Code as a Crime Scene*), not a measurement of quality. It tells you where to look, not what you'll find.

## Pinning behavior: characterization tests

Module 14 introduced characterization tests on a small importer. In an app, the targets are functions that are risky to touch: money, dates, rules with many branches. Pantry's delivery fee function, six years old:

```swift
func legacyDeliveryFee(subtotalCents: Int, distanceMeters: Int, isMember: Bool, hour: Int) -> Int {
    var fee = 499
    if subtotalCents > 5_000 { fee = 0 }
    if distanceMeters > 10_000 { fee += 200 }
    if isMember { fee = fee / 2 }
    if hour >= 18 && hour < 21 { fee += 100 }
    return fee
}

/// Characterization cases: what the function returns today, odd results included.
let cases: [(subtotal: Int, meters: Int, member: Bool, hour: Int, expected: Int, note: String)] = [
    (4_000, 2_000, false, 12, 499, "base fee"),
    (5_000, 2_000, false, 12, 499, "exactly $50 is NOT free (> not >=)"),
    (5_001, 2_000, false, 12, 0, "free above $50"),
    (6_000, 12_000, false, 12, 200, "free delivery still pays the distance surcharge"),
    (4_000, 10_000, false, 12, 499, "exactly 10 km has no surcharge"),
    (4_000, 2_000, true, 12, 249, "member half fee rounds down"),
    (4_000, 12_000, true, 12, 349, "member halves the surcharge too"),
    (4_000, 2_000, true, 19, 349, "evening surcharge is not halved"),
    (4_000, 2_000, false, 21, 499, "21:00 is no longer evening"),
]

var failures = 0
for c in cases {
    let actual = legacyDeliveryFee(subtotalCents: c.subtotal, distanceMeters: c.meters, isMember: c.member, hour: c.hour)
    if actual != c.expected {
        failures += 1
        print("CHANGED \(c.note): expected \(c.expected), got \(actual)")
    }
}
print("\(cases.count - failures)/\(cases.count) characterization cases hold")
```

```output
9/9 characterization cases hold
```

- **The cases were chosen from the code**, not from the spec: one per branch, plus each boundary (`5_000` vs `5_001`, `10_000`, hour `21`) and each interaction between rules (member and surcharge, member and evening).
- **The notes record surprises** without fixing them. "Exactly $50 is NOT free" might be a bug, or what marketing promised. That's a product question; the refactoring keeps it.
- **The expected values are what the function returned** when the cases were written. If one is ever wrong, the test is updated in a separate change that says "behavior change," never as part of a refactoring.

### Refactoring in small steps, then a parallel run

The goal is to turn the function into named rules that the product team can read, with each step keeping all nine cases green. After several small commits:

```swift
func legacyDeliveryFee(subtotalCents: Int, distanceMeters: Int, isMember: Bool, hour: Int) -> Int {
    var fee = 499
    if subtotalCents > 5_000 { fee = 0 }
    if distanceMeters > 10_000 { fee += 200 }
    if isMember { fee = fee / 2 }
    if hour >= 18 && hour < 21 { fee += 100 }
    return fee
}

struct DeliveryRequest {
    let subtotalCents: Int
    let distanceMeters: Int
    let isMember: Bool
    let hour: Int
}

enum DeliveryFee {
    static let baseCents = 499
    static let freeAboveCents = 5_000
    static let longDistanceMeters = 10_000
    static let longDistanceSurchargeCents = 200
    static let eveningHours = 18..<21
    static let eveningSurchargeCents = 100

    static func cents(for request: DeliveryRequest) -> Int {
        var fee = request.subtotalCents > freeAboveCents ? 0 : baseCents
        if request.distanceMeters > longDistanceMeters { fee += longDistanceSurchargeCents }
        if request.isMember { fee /= 2 }                       // halves base and distance, not evening
        if eveningHours.contains(request.hour) { fee += eveningSurchargeCents }
        return fee
    }
}

// Parallel run: every combination of the values each rule cares about.
let subtotals = [0, 4_999, 5_000, 5_001, 20_000]
let distances = [0, 9_999, 10_000, 10_001, 30_000]
let hours = Array(0..<24)
var compared = 0
var mismatches: [String] = []
for subtotal in subtotals {
    for meters in distances {
        for member in [false, true] {
            for hour in hours {
                compared += 1
                let old = legacyDeliveryFee(subtotalCents: subtotal, distanceMeters: meters, isMember: member, hour: hour)
                let new = DeliveryFee.cents(for: DeliveryRequest(subtotalCents: subtotal, distanceMeters: meters, isMember: member, hour: hour))
                if old != new { mismatches.append("\(subtotal) \(meters) \(member) \(hour): \(old) vs \(new)") }
            }
        }
    }
}
print("compared \(compared) inputs, \(mismatches.count) mismatches")
for mismatch in mismatches.prefix(5) { print(mismatch) }
```

```output
compared 1200 inputs, 0 mismatches
```

- **The input grid** uses, for each parameter, the values on both sides of every boundary in the code (4,999, 5,000, 5,001; 9,999 to 10,001; all 24 hours), and every combination of them: 5 × 5 × 2 × 24 = 1,200 cases. For a function with a few integer thresholds, that's close to exhaustive where it matters.
- **Zero mismatches** is the evidence the refactoring preserved behavior. If it weren't zero, the first five mismatches would point at the rule that changed.
- **The constants have names** now, so "should exactly $50 be free?" becomes a one-character change to `>=` that the product team can request, in its own pull request, with the characterization case updated on purpose.
- In production, a riskier change can run both implementations, use the old result, and log disagreements for a while before switching. That's only safe when both are free of side effects, as these are.

### Seams for code that touches the world

`legacyDeliveryFee` is a pure function, the easy case. Most legacy iOS code reaches out: `Date()`, `UserDefaults.standard`, `URLSession.shared`, `CartService.shared`. Feathers calls the place where you can substitute behavior without editing the code a **seam**. In Swift the usual seams are a default parameter or an initializer argument with a protocol type:

```swift illustrative
// Before: impossible to test without the real singleton and the real clock.
final class CheckoutViewModel {
    func canPlaceOrder() -> Bool {
        CartService.shared.items.isEmpty == false && Calendar.current.component(.hour, from: Date()) < 23
    }
}

// After: the same default behavior, with seams for tests.
final class CheckoutViewModel {
    private let cart: CartProviding
    private let now: () -> Date

    init(cart: CartProviding = CartService.shared, now: @escaping () -> Date = Date.init) {
        self.cart = cart
        self.now = now
    }

    func canPlaceOrder() -> Bool {
        !cart.items.isEmpty && Calendar.current.component(.hour, from: now()) < 23
    }
}
```

Every existing call site (`CheckoutViewModel()`) compiles unchanged, which is what makes this a safe first step in a codebase with hundreds of them; tests pass a fake cart and a fixed date. The fragment is illustrative because it depends on Pantry's `CartService` and `CartProviding`.

### Habits for changing legacy code safely

- **Never mix refactoring and behavior changes** in one pull request (Module 14). Reviewers can check "same behavior" only when that's all the change claims.
- **Keep each step shippable.** Expand and contract, shims, flags around new implementations. If you can't stop halfway, the steps are too big.
- **Leave stable code alone.** The Objective-C parser that nobody touches doesn't need a rewrite this quarter.
- **Write down what you learn**: the surprising notes from the characterization cases are documentation nobody else has.

## Common mistakes

> [!error] Raising the deployment target by habit
> Decide from your own users' OS versions and say how many people you're leaving on the last compatible version. The decision should be explicit and recorded.

> [!error] #available checks scattered across call sites
> They're hard to find and impossible to clean up when the target rises. Wrap the newer API in one shim.

> [!error] Using a version check as a feature flag
> "iOS 18 gets the new checkout" can't be rolled back without an app update. Use a real flag; use `#available` only when the API requires it.

> [!error] Expecting @backDeployed to work in an app's own code
> It's for symbols that ship with the OS or another ABI-stable library. Your app already carries its own implementation to every OS version it supports.

> [!error] Renaming an API in one sweeping change
> Hundreds of edited files are hard to review and impossible to revert cleanly. Deprecate with `renamed:`, migrate callers in small changes, then delete.

> [!error] "Fixing" bugs while refactoring
> If a characterization case changes, the refactoring changed behavior. Revert, finish the refactoring, then make the fix as its own change.

## Exercises

````exercise
id: m43-l06-e1
type: prediction
prompt: "A smaller version of the hotspot ranking. What does it print?"
code: |
  struct FileHistory {
      let path: String
      let commits: Int
      let lines: Int
  }

  let files = [
      FileHistory(path: "A.swift", commits: 22, lines: 640),
      FileHistory(path: "B.swift", commits: 35, lines: 410),
      FileHistory(path: "C.swift", commits: 2, lines: 5_000),
  ]
  for file in files {
      print(file.path, file.commits * file.lines)
  }
  let ranked = files.sorted { $0.commits * $0.lines > $1.commits * $1.lines }
  print(ranked.map(\.path))
output: |
  A.swift 14080
  B.swift 14350
  C.swift 10000
  ["B.swift", "A.swift", "C.swift"]
hints:
  - "Multiply each pair before sorting."
  - "22 × 640 and 35 × 410 are close. Which is larger?"
solution: |
  ```output
  A.swift 14080
  B.swift 14350
  C.swift 10000
  ["B.swift", "A.swift", "C.swift"]
  ```

  35 × 410 = 14,350 is a little larger than 22 × 640 = 14,080, so B ranks above A even though A is bigger: B changes more often. C is the largest file by far but changed twice in a year, so it ranks last. The ranking is a reading list, and C's place on it says "probably stable," not "probably fine."
````

````exercise
id: m43-l06-e2
type: comprehension
prompt: "Pantry's deployment target is iOS 17. A view uses `.presentationSizing(.form)`, introduced in iOS 18. Which approach does this lesson recommend?"
choices:
  - text: "A View extension shim with if #available(iOS 18, *) inside, used everywhere the sizing is needed."
    correct: true
    why: "One check in one place; call sites stay clean, and raising the target later simplifies the shim only."
  - text: "Mark Pantry's own wrapper @backDeployed(before: iOS 18)."
    correct: false
    why: "@backDeployed copies an implementation for callers of a library symbol; it can't make an iOS 18 SDK function exist on iOS 17."
  - text: "Raise the deployment target to iOS 18 so the check isn't needed."
    correct: false
    why: "Maybe eventually, but the target is a decision about users, not about one modifier."
  - text: "Write if #available(iOS 18, *) around every sheet in the app."
    correct: false
    why: "It works, but scatters version logic across call sites that are hard to find and clean up."
solution: |
  ```swift ios
  import SwiftUI

  extension View {
      @ViewBuilder
      func pantryFormSheetSizing() -> some View {
          if #available(iOS 18, *) {
              presentationSizing(.form)
          } else {
              self
          }
      }
  }
  ```

  On iOS 17 the sheet keeps its default size; on iOS 18 and later it uses form sizing. When Pantry's target reaches iOS 18, the shim becomes one line, and nothing else changes.
````

````exercise
id: m43-l06-e3
type: fill-in
prompt: "Deprecate the old cart method so callers get a warning with a fix-it, while it keeps working."
code: |
  struct Cart {
      @available([[1]], [[2]], renamed: "[[3]]", message: "Quantities are now explicit.")
      mutating func add(_ productID: Int) {
          add(productID, quantity: 1)
      }

      mutating func add(_ productID: Int, quantity: Int) { /* … */ }
  }
blanks:
  - id: "1"
    answers: ["*"]
  - id: "2"
    answers: ["deprecated"]
  - id: "3"
    answers: ["add(_:quantity:)"]
solution: |
  ```swift warning 'add' is deprecated
  struct Cart {
      var lines: [Int: Int] = [:]

      @available(*, deprecated, renamed: "add(_:quantity:)", message: "Quantities are now explicit.")
      mutating func add(_ productID: Int) {
          add(productID, quantity: 1)
      }

      mutating func add(_ productID: Int, quantity: Int) {
          lines[productID, default: 0] += quantity
      }
  }

  var cart = Cart()
  cart.add(42)
  cart.add(7, quantity: 3)
  print(cart.lines[42, default: 0], cart.lines[7, default: 0])
  ```

  ```output
  1 3
  ```

  `*` applies the deprecation on every platform, `deprecated` without a version means "deprecated now," and `renamed:` uses the full name of the replacement, including argument labels, so the fix-it can rewrite calls. The old method forwards to the new one, so existing callers keep their behavior while they migrate.
````

````exercise
id: m43-l06-e4
type: find-errors
prompt: "A pull request titled \"Refactor delivery fee\" in Pantry. Mark every real problem."
code: |
  // Characterization cases updated to match the new implementation.
  // Also fixed: exactly $50 is now free (>= instead of >).
  // Also moved the evening surcharge before the member discount (more consistent).
  // Deleted legacyDeliveryFee and its 9 cases; DeliveryFee has 3 new tests.
  // 27 files changed: switched every caller to DeliveryFee.cents(for:).
choices:
  - text: "It mixes a refactoring with two behavior changes in one pull request."
    correct: true
  - text: "Characterization cases were changed to match the new code, so they no longer check that behavior was preserved."
    correct: true
  - text: "The old implementation and its cases were deleted, leaving no way to compare old and new."
    correct: true
  - text: "Switching all 27 callers in the same change makes it hard to review and to revert."
    correct: true
  - text: "Names like DeliveryFee.cents(for:) are too long for Swift."
    correct: false
    why: "The name is fine and follows the API Design Guidelines."
rubric:
  - I flagged the mixed refactoring and behavior changes.
  - I flagged editing characterization cases to fit the new code.
  - I flagged deleting the old implementation before a parallel run.
  - I flagged the all-at-once caller migration.
solution: |
  - **Three things in one PR:** the refactoring, the `>=` change and the reordered surcharge (which changes fees for members in the evening). Split them: refactoring first, with all cases unchanged; each behavior change afterwards, with the affected cases updated and the product decision cited.
  - **Cases adjusted to the new code** defeat their purpose. If a case fails during a refactoring, the refactoring is wrong.
  - **Deleting the old function** removes the parallel run. Keep it (or a copy in tests) until the comparison over the input grid shows zero mismatches.
  - **27 files at once:** add the new API, deprecate the old one with `renamed:`, and migrate callers in small changes.
````

````exercise
id: m43-l06-e5
type: solve
prompt: |
  Pantry's loyalty discount is legacy code. Write characterization checks for it: complete `cases` with the values the function returns **today** for the inputs given (run it in your head or in a playground), so that the program prints `8/8 hold`. Then explain which results look like bugs.
starter: |
  func legacyLoyaltyDiscount(points: Int, subtotalCents: Int) -> Int {
      if points < 100 { return 0 }
      var discount = (points / 100) * 50
      if discount > subtotalCents / 2 { discount = subtotalCents / 2 }
      if subtotalCents < 1_000 { discount = 0 }
      return discount
  }

  let cases: [(points: Int, subtotal: Int, expected: Int)] = [
      (99, 5_000, 0),
      (100, 5_000, 0),      // fill in
      (250, 5_000, 0),      // fill in
      (1_000, 5_000, 0),    // fill in
      (1_000, 999, 0),      // fill in
      (1_000, 1_000, 0),    // fill in
      (-500, 5_000, 0),     // fill in
      (100, 1_001, 0),      // fill in
  ]

  var holding = 0
  for c in cases where legacyLoyaltyDiscount(points: c.points, subtotalCents: c.subtotal) == c.expected {
      holding += 1
  }
  print("\(holding)/\(cases.count) hold")
hints:
  - "points / 100 is integer division: 250 / 100 is 2."
  - "The cap is half the subtotal, computed with integer division too."
  - "Negative points are less than 100."
rubric:
  - All eight expected values match the function's current behavior.
  - The program prints 8/8 hold.
  - The explanation separates current behavior from intended behavior without changing the function.
solution: |
  ```swift
  func legacyLoyaltyDiscount(points: Int, subtotalCents: Int) -> Int {
      if points < 100 { return 0 }
      var discount = (points / 100) * 50
      if discount > subtotalCents / 2 { discount = subtotalCents / 2 }
      if subtotalCents < 1_000 { discount = 0 }
      return discount
  }

  let cases: [(points: Int, subtotal: Int, expected: Int)] = [
      (99, 5_000, 0),
      (100, 5_000, 50),
      (250, 5_000, 100),
      (1_000, 5_000, 500),
      (1_000, 999, 0),
      (1_000, 1_000, 500),
      (-500, 5_000, 0),
      (100, 1_001, 50),
  ]

  var holding = 0
  for c in cases where legacyLoyaltyDiscount(points: c.points, subtotalCents: c.subtotal) == c.expected {
      holding += 1
  }
  print("\(holding)/\(cases.count) hold")
  ```

  ```output
  8/8 hold
  ```

  - **250 points give 100, not 125**: the integer division drops the remainder. Maybe intended ("50 cents per full 100 points"), maybe not.
  - **1,000 points on a $10.00 order give $5.00**: the cap is exactly half. On $9.99 the discount drops to 0, a cliff of $5 for one cent. That looks like a bug, or at least a surprise worth asking about.
  - **Negative points** return 0 rather than crashing, which is fine, but the app probably shouldn't allow them.

  None of these get fixed in the refactoring. They go in the case notes and in a ticket for the product owner.
````

````exercise
id: m43-l06-e6
type: design
prompt: "Pantry's 1,850-line CheckoutViewController (UIKit, singletons, direct URLSession.shared calls, no tests) needs a new payment method next quarter. Plan the work from today until the feature ships, in steps that each could ship on their own."
rubric:
  - Starts by mapping the controller and pinning behavior (characterization tests for the pure logic, a UI test for the main checkout task).
  - Introduces seams for singletons and networking without changing call sites.
  - Extracts logic in small steps (for example to a view model) with tests green after each, keeping refactoring separate from behavior changes.
  - Adds the payment method behind a flag, with a parallel or staged rollout, and plans what to do with the old code.
solution: |
  1. **Map it.** Read the controller with the "add to cart → place order" path; list its responsibilities (validation, fee calculation, payment, networking, navigation). Note what's pure logic and what touches the world.
  2. **Pin it.** Characterization tests for the pure parts (fees, totals, validation messages) over boundary grids; one UI test for "place an order" against a stubbed backend (Module 33), plus the accessibility audit from lesson 4.
  3. **Seams.** Initializer parameters with defaults for `CartService.shared`, `URLSession.shared` (behind the transport protocol from Module 30) and the clock. No call site changes.
  4. **Extract.** Move logic into a `CheckoutViewModel` one responsibility per pull request: totals, then validation, then the order submission (with an idempotency key, lesson 3). Tests green after each, no behavior changes.
  5. **Feature.** Add the new payment method in the view model behind a feature flag, with its own tests. The UI is either a new SwiftUI section hosted in the UIKit screen (Module 40) or a UIKit row; the flag lets it ship dark.
  6. **Roll out.** Enable for staff, then a percentage of customers; watch payment errors and hang rate (lesson 2). Remove the flag when it's at 100%.
  7. **Contract.** Delete code paths the extraction left behind, and the characterization cases that only described them; keep the ones that describe behavior the view model still owns.
````

## Summary

- Pick the deployment target from your own users' OS versions and record the decision. Everything at or below it needs no checks; raising it turns old `#available` branches into dead code.
- `#if` decides what compiles, `#available`/`#unavailable` what runs, `@available` what callers must check. Wrap newer APIs in one shim so call sites never branch on versions. Don't use version checks as feature flags.
- `@backDeployed` copies an implementation into callers for OS versions before a symbol shipped; it's for libraries that ship with the OS, with `public` or `@usableFromInline` inlinable bodies. Apps write shims.
- Replace deprecated APIs with what their documentation recommends (`traitCollection.displayScale` and `window?.windowScene?.screen` instead of `UIScreen.main`). Deprecate your own with `renamed:` and contract later, optionally via `unavailable`.
- Learn a codebase by building it, reading entry points, following one task end to end, and ranking files by change frequency and size.
- Pin behavior with characterization tests at every branch and boundary, refactor in small green steps, compare old and new over an input grid, add seams with defaulted parameters, and keep behavior changes in separate, explicit changes.
