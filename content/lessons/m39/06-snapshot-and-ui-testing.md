---
id: m39-l06
title: Snapshot testing and testing SwiftUI views
description: "A SwiftUI view is a function of its inputs, which makes most of it testable without rendering anything: you test the logic that decides what it shows, and you check what it looks like with previews and, where it pays, snapshot tests. You run a model of how a snapshot assertion records, compares and diffs, and of comparing images with tolerances; render views to images with ImageRenderer and learn what it can't draw; and see how Point-Free's swift-snapshot-testing library works, from its README."
module: m39
order: 6
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l05, m33-l05]
objectives:
  - Move display logic out of a view into a value you can unit test, and say what's left to test visually.
  - Explain how a snapshot assertion records a reference, compares later runs and reports a difference.
  - Say what snapshot tests catch, what they miss, and why they're sensitive to the device, OS and renderer.
  - Render a SwiftUI view to an image with ImageRenderer, and name the views it can't render.
  - Describe swift-snapshot-testing's assertSnapshot, strategies and record modes from its README.
  - Use previews with traits and environment values as fast visual checks, and know they don't fail.
terms:
  - term: Snapshot test
    definition: "A test that renders a value (an image of a view, a text description, JSON) and compares it with a stored reference. The first run records the reference; later runs fail when the output differs."
  - term: Reference
    definition: "The stored, reviewed output a snapshot test compares against, committed to the repository next to the tests."
  - term: Render state
    definition: "A plain value computed from the model that holds exactly what a view displays (texts, flags, accessibility label). It can be unit tested without SwiftUI; the view only lays it out."
  - term: ImageRenderer
    definition: "A SwiftUI class (iOS 16, @MainActor) that rasterizes a view to a CGImage or UIImage, or draws it into a CGContext. It can't draw views composited by Core Animation, such as many controls, web views and UIKit views."
  - term: Snapshot strategy
    definition: "In swift-snapshot-testing, a value describing how to turn something into a snapshot and how to compare it: .image, .recursiveDescription, .json, .dump and others."
mastery:
  - Write a render state for a row and unit test its title, badge and accessibility label.
  - Read a snapshot diff and decide whether the change is a regression or should be re-recorded.
  - Explain why a reference image recorded on one simulator fails on another, and what a tolerance can and can't fix.
  - Render a view in light and dark mode at a large Dynamic Type size to PNG data.
  - Set up a snapshot test with swift-snapshot-testing in a test target, record it, and re-record deliberately.
resources: [swiftui-previews, swift-testing-docs, xctest, fowler-test-pyramid, uikit-uigraphicsimagerenderer]
cards:
  - id: m39-l06-c1
    front: What should you unit test in a SwiftUI screen?
    back: "The logic that decides what it shows: a render state or view model computed from the model (texts, which badge, enabled or not, the accessibility label). Test it with Swift Testing like any value. Leave layout and appearance to previews and a few snapshot tests."
  - id: m39-l06-c2
    front: How does a snapshot assertion behave on its first run?
    back: "There's no reference, so it records the output as the reference and fails, so a person reviews and commits it. Later runs compare with the reference and fail with a diff when the output changes."
  - id: m39-l06-c3
    front: Why do image snapshots fail on another machine?
    back: "Rendering depends on the simulator model, OS version, scale, fonts and GPU. The swift-snapshot-testing README warns snapshots must be compared on the same simulator that recorded them. Tolerances absorb anti-aliasing noise, not real differences."
  - id: m39-l06-c4
    front: What can't ImageRenderer draw?
    back: "Apple: views composited by Core Animation layers, such as more complex controls and containers, web views, media players and most UIKit and AppKit views. It draws a placeholder for those. Text, images, shapes and compositions of them work."
  - id: m39-l06-c5
    front: Are previews tests?
    back: "No. A preview shows a view with chosen inputs and traits while you work, but nothing fails when it looks wrong. Use them for fast visual checks of states (empty, error, dark, large text, long strings); use unit and snapshot tests to catch regressions."
---

## The idea in one sentence

**Test what a view decides with unit tests, and what it looks like with a few snapshots**: most bugs in a SwiftUI screen are in the logic that picks the text, the badge or the state, and that logic doesn't need a view to be tested.

> [!note] About this lesson's code and sources
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so no image in this lesson was rendered. `ImageRenderer` behavior is quoted from Apple's pages for `ImageRenderer`, `scale`, `proposedSize`, `uiImage` and `render(rasterizationScale:renderer:)`; previews from "Previews in Xcode", `Preview(_:body:)`, `Preview(_:traits:_:body:)` and `PreviewTrait`, read in November 2026. swift-snapshot-testing is described **only from its README** on GitHub, read the same month; its code is marked illustrative because the library isn't part of this course's build, and no version of it was installed or run. The render state, the snapshot assertion and the image comparison are plain-Swift models, compiled and run with Swift 6.3; they show the mechanics, not the library's code.

## What to test, and where

Module 33, lesson 5 tested view models and drew the test pyramid: many fast unit tests, fewer integration tests, a handful of UI tests. SwiftUI adds a layer that's easy to get wrong in both directions:

| Question | Tool | Fails automatically? |
| --- | --- | --- |
| Does the row show "On the way" for undelivered orders? | Unit test of a render state | Yes |
| Does the screen load, handle errors, save? | Unit tests of the view model (Module 33) | Yes |
| Does the row still look right after a refactor, in dark mode, at large text? | Snapshot test | Yes, when the output changes |
| What does this state look like while I'm building it? | Preview | No |
| Can a person complete checkout? | UI test (XCUITest, Module 33) | Yes |

The first row is where most of the value is. The trick is to make it possible.

## Logic out of the view: a render state

A view that formats prices, picks badges and builds accessibility labels inside `body` can only be checked by looking at it. Move those decisions into a value computed from the model, and the view becomes a layout of that value:

```swift
import Foundation

/// What a row displays, computed from the model outside the view, so it can be tested without SwiftUI.
struct Order {
    let number: Int
    let itemCount: Int
    let totalCents: Int
    let isDelivered: Bool
}

struct OrderRowState: Equatable {
    let title: String
    let detail: String
    let badge: String?
    let accessibilityLabel: String

    init(_ order: Order) {
        title = "Order #\(order.number)"
        let items = order.itemCount == 1 ? "1 item" : "\(order.itemCount) items"
        let total = "$\(order.totalCents / 100).\(order.totalCents % 100 < 10 ? "0" : "")\(order.totalCents % 100)"
        detail = "\(items) · \(total)"
        badge = order.isDelivered ? nil : "On the way"
        accessibilityLabel = "Order \(order.number), \(items), \(total)" + (order.isDelivered ? ", delivered" : ", on the way")
    }

    /// A text rendering for snapshots: one property per line.
    var snapshot: String {
        "title: \(title)\ndetail: \(detail)\nbadge: \(badge ?? "none")\naccessibility: \(accessibilityLabel)"
    }
}

/// A model of a snapshot assertion: record when there's no reference, compare after, show a diff.
enum SnapshotResult {
    case recorded
    case matched
    case failed([String])
}

func assertSnapshot(_ value: String, named name: String, references: inout [String: String]) -> SnapshotResult {
    guard let reference = references[name] else {
        references[name] = value         // like the library: record, and fail so someone looks at it
        return .recorded
    }
    if reference == value { return .matched }
    let old = reference.split(separator: "\n").map(String.init)
    let new = value.split(separator: "\n").map(String.init)
    var diff: [String] = []
    for index in 0..<max(old.count, new.count) {
        let before = index < old.count ? old[index] : nil
        let after = index < new.count ? new[index] : nil
        if before != after {
            if let before { diff.append("- \(before)") }
            if let after { diff.append("+ \(after)") }
        }
    }
    return .failed(diff)
}

var references: [String: String] = [:]
let order = Order(number: 1042, itemCount: 3, totalCents: 2405, isDelivered: false)

for run in 1...2 {
    print("run \(run):", assertSnapshot(OrderRowState(order).snapshot, named: "pendingOrder", references: &references))
}

// Someone changes the badge copy.
let changed = OrderRowState(order).snapshot
    .replacingOccurrences(of: "On the way", with: "Shipped")
if case .failed(let diff) = assertSnapshot(changed, named: "pendingOrder", references: &references) {
    print("run 3: failed")
    diff.forEach { print("  \($0)") }
}
```

```output
run 1: recorded
run 2: matched
run 3: failed
  - badge: On the way
  + badge: Shipped
```

Two things are going on.

**`OrderRowState`** holds what the row shows. Its initializer is the logic: singular and plural items, a price with two decimals, a badge only for undelivered orders, and an accessibility label that says all of it. You test it like any value, with `#expect(OrderRowState(order).badge == "On the way")` in Swift Testing. No SwiftUI, no simulator, milliseconds per test. (In an app you'd format prices with `FormatStyle` and a locale; the hand-written formatting keeps the model's output identical on every platform.)

**`assertSnapshot`** is a model of a snapshot assertion over the state's text rendering:

- **Run 1:** no reference exists, so it records one and reports `recorded`. Real libraries fail the test at this point (see below), because a reference nobody looked at proves nothing.
- **Run 2:** the output matches the reference.
- **Run 3:** someone changed the badge copy. The assertion fails and the diff shows exactly which line changed. Now a person decides: if the new copy is intended, re-record; if not, it's a regression.

A text snapshot of a render state is cheap, readable in code review and identical on every machine. It's often the best snapshot you can take.

## Image snapshots: what they catch and what they cost

An image snapshot renders the view itself and compares pixels. It catches what no unit test of the state does: a modifier order change that moves the background, a font change, text that now truncates in German, a dark-mode color that disappears, a layout that breaks at an accessibility text size.

It costs something too:

- **Sensitivity to the environment.** Rendering depends on the device model, scale, OS version, fonts and the GPU. The swift-snapshot-testing README warns: "Snapshots must be compared using the exact same simulator that originally took the reference to avoid discrepancies between images." An Xcode update that changes the simulator's OS can fail every image snapshot at once.
- **No meaning.** A failing image tells you something changed, not whether it's wrong. Each failure needs a person.
- **Size.** Reference PNGs live in the repository.

Tolerances help with the first problem but not the second. A model of comparing two images with a per-pixel tolerance and a maximum fraction of differing pixels:

```swift
/// A model of comparing two rendered images with tolerances. Grayscale, one byte per pixel.
struct Bitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8]
}

func compare(_ reference: Bitmap, _ candidate: Bitmap, perPixelTolerance: Int, maxDifferentFraction: Double) -> (matches: Bool, differing: Int) {
    guard reference.width == candidate.width, reference.height == candidate.height else {
        return (false, reference.pixels.count)
    }
    var differing = 0
    for (a, b) in zip(reference.pixels, candidate.pixels) where abs(Int(a) - Int(b)) > perPixelTolerance {
        differing += 1
    }
    let fraction = Double(differing) / Double(reference.pixels.count)
    return (fraction <= maxDifferentFraction, differing)
}

let reference = Bitmap(width: 10, height: 10, pixels: Array(repeating: 200, count: 100))

var antialiasing = reference                      // edge pixels off by a few levels on another GPU
for index in stride(from: 0, to: 100, by: 10) { antialiasing.pixels[index] = 197 }

var realChange = reference                        // a 3 × 4 badge disappeared
for row in 0..<3 { for column in 0..<4 { realChange.pixels[row * 10 + column] = 40 } }

let resized = Bitmap(width: 10, height: 11, pixels: Array(repeating: 200, count: 110))

for (name, candidate) in [("antialiasing", antialiasing), ("real change", realChange), ("resized", resized)] {
    let exact = compare(reference, candidate, perPixelTolerance: 0, maxDifferentFraction: 0)
    let tolerant = compare(reference, candidate, perPixelTolerance: 4, maxDifferentFraction: 0.02)
    print("\(name): exact \(exact.matches) (\(exact.differing) px), tolerant \(tolerant.matches) (\(tolerant.differing) px)")
}
```

```output
antialiasing: exact false (10 px), tolerant true (0 px)
real change: exact false (12 px), tolerant false (12 px)
resized: exact false (100 px), tolerant false (100 px)
```

- **Anti-aliasing noise** (edges off by a few levels on another GPU) fails an exact comparison but passes with a per-pixel tolerance of 4.
- **A real change** (a badge gone, 12 pixels from 200 to 40) fails either way, as it should.
- **A size change** fails before any pixel is compared: a view that grew a point taller is a different image.

So: pin the simulator and OS your references are recorded on (in CI, the same runner image), use a small tolerance for rendering noise, and never raise a tolerance to make a real change pass.

## Rendering a view to an image: ImageRenderer

SwiftUI can rasterize a view itself. `ImageRenderer` (iOS 16) is "an object that creates images from SwiftUI views": initialize it with a view, then read `cgImage` or `uiImage`, or call `render(rasterizationScale:renderer:)` to draw into a `CGContext`, for example a PDF. It's `@MainActor`.

```swift ios
import SwiftUI
import UIKit

struct OrderRow: View {
    let title: String
    let detail: String
    let badge: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2), in: Capsule())
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

/// Renders a view at a fixed width, in a given appearance, to PNG data.
@MainActor
func pngSnapshot(of view: some View, width: CGFloat, colorScheme: ColorScheme, dynamicTypeSize: DynamicTypeSize) -> Data? {
    let renderer = ImageRenderer(content: view
        .environment(\.colorScheme, colorScheme)
        .environment(\.dynamicTypeSize, dynamicTypeSize))
    renderer.proposedSize = ProposedViewSize(width: width, height: nil)
    renderer.scale = 2
    return renderer.uiImage?.pngData()
}

@MainActor
func renderOrderRowVariants() -> [String: Data] {
    let row = OrderRow(title: "Order #1042", detail: "3 items · $24.05", badge: "On the way")
    var images: [String: Data] = [:]
    for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
        for (sizeName, size) in [("default", DynamicTypeSize.large), ("ax3", DynamicTypeSize.accessibility3)] {
            images["orderRow-\(name)-\(sizeName)"] = pngSnapshot(of: row, width: 375, colorScheme: scheme, dynamicTypeSize: size)
        }
    }
    return images
}
```

- **`proposedSize`** is "the size proposed to the root view"; the default, `.unspecified`, "produces an image that matches the original view size." Proposing a width and a `nil` height lays the row out like a 375-point-wide screen and lets it choose its height: a row at `accessibility3` comes out taller, which is exactly what you want to see.
- **`scale`** is "a ratio of view points to image pixels"; the default is 1. Set it explicitly so references don't depend on the machine.
- **Environment values** set the appearance: color scheme and Dynamic Type here, `\.locale` and `\.layoutDirection` for localization (Module 38, lesson 6).
- **The background** is set explicitly. Without it, the transparent parts of the image show whatever the comparison tool draws behind them.

In a test target, `renderOrderRowVariants()` would run in a `@MainActor` test and compare each image with a reference file using a comparison like the model above. That's a small snapshot library, and you can write one. The limit is in Apple's documentation: "`ImageRenderer` output only includes views that SwiftUI rasterizes directly using its own drawing primitives, such as text, images, shapes, and composite views of these types. It does not include views whose contents are composited by Core Animation layers, such as more complex controls and containers, web views, media players, and most types of UIKit and AppKit views. In those cases, `ImageRenderer` displays a placeholder image." A `List`, a `TextField` or a `Toggle` may come out as a placeholder. Apple adds that what's supported "may change in future releases," though "any view that is currently supported is guaranteed to remain supported." For whole screens, snapshot libraries host the view in a window instead.

## swift-snapshot-testing

Point-Free's [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) is the most widely used snapshot library for Swift. Everything here is from its README; the code is illustrative and wasn't compiled for this lesson.

**Installation.** Add the package to a **test target**, not the app. The README warns that Xcode "will try to add the SnapshotTesting package to your project's main application/framework target" by default, and to choose the test target instead. For SwiftPM, its example declares the dependency `from: "1.12.0"` and adds `.product(name: "SnapshotTesting", package: "swift-snapshot-testing")` to the test target. That number is the README's minimum, not necessarily the latest release; check the repository's releases before pinning.

**Usage.** One function, `assertSnapshot(of:as:)`, taking a value and a **strategy**. The README's example with Swift Testing:

```swift illustrative
import SnapshotTesting
import Testing

@MainActor
struct MyViewControllerTests {
  @Test func myViewController() {
    let vc = MyViewController()

    assertSnapshot(of: vc, as: .image)
  }
}
```

For a SwiftUI view, host it in a `UIHostingController` (Module 40 covers it) and snapshot the controller, with a device configuration from the README's list:

```swift illustrative
import SnapshotTesting
import SwiftUI
import Testing
@testable import Shop

@MainActor
struct OrderRowSnapshotTests {
    @Test func pendingOrder() {
        let row = OrderRow(title: "Order #1042", detail: "3 items · $24.05", badge: "On the way")
        let controller = UIHostingController(rootView: row)
        assertSnapshot(of: controller, as: .image(on: .iPhoneSe))
    }
}
```

**First run.** From the README: "When an assertion first runs, a snapshot is automatically recorded to disk and the test will fail, printing out the file path of any newly-recorded reference." References go in a `__Snapshots__` folder next to the test file, named after the suite and test. Review the image, commit it, run again.

**Re-recording.** When a change is intended, record new references deliberately rather than deleting files. The README shows three scopes:

```swift illustrative
// Record just this one snapshot
assertSnapshot(of: vc, as: .image, record: .all)

// Record all snapshot failures in a Swift Testing suite
@Suite(.snapshots(record: .failed))
struct FeatureTests {}

// Record all snapshots in a scope
withSnapshotTesting(record: .all) {
  assertSnapshot(of: vc1, as: .image)
  assertSnapshot(of: vc2, as: .image)
}
```

Never commit a `record:` argument: a test that always records always passes.

**Not only images.** The README's point is that a strategy can turn any value into a snapshot: `.recursiveDescription` for a view hierarchy's text, `.json` and `.plist` for `Encodable` values, `.raw` for a `URLRequest`, `.dump` for anything through its mirror. The `OrderRowState` text snapshot from earlier in this lesson is that idea, and `assertSnapshot(of: state, as: .dump)` would do it without writing `snapshot` by hand. The README also lists plug-ins, among them AccessibilitySnapshot, for regression-testing what VoiceOver sees.

## Previews as visual checks

Previews are where you look at states while you build: empty, loading, error, very long names, dark mode, large text, another language. `#Preview` (iOS 17) takes an optional name, and `Preview(_:traits:_:body:)` adds traits such as `.sizeThatFitsLayout` or `.fixedLayout(width:height:)`:

```swift illustrative
#Preview("Pending", traits: .sizeThatFitsLayout) {
    OrderRow(title: "Order #1042", detail: "3 items · $24.05", badge: "On the way")
}

#Preview("Delivered, dark, AX3", traits: .sizeThatFitsLayout) {
    OrderRow(title: "Order #1042", detail: "3 items · $24.05", badge: nil)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Very long title", traits: .fixedLayout(width: 320, height: 120)) {
    OrderRow(title: "Order #1042 for the Riverside Community Garden Association", detail: "12 items · $1,240.00", badge: "On the way")
}
```

(This block is illustrative because `#Preview` needs Xcode's preview support; the course's type-check runs plain `swiftc`.)

A preview is a check you perform with your eyes. Nothing fails when it looks wrong, and nobody looks at the preview for a file they didn't touch. That's the difference from a snapshot test: the snapshot watches the row when someone else changes a shared font or color.

## Common mistakes

> [!error] Testing display logic through images
> If the bug is "the badge says the wrong thing," an image snapshot is a slow, fragile way to catch it. Put the decision in a render state and assert on it.

> [!error] Recording references on one machine and comparing on another
> Different simulators, OS versions or scales produce different pixels. Record and compare on the same configuration, usually the CI image, and treat an Xcode upgrade as a re-record event.

> [!error] Non-deterministic views in snapshots
> `Date()`, random sample data, remote images, animations in progress: each run renders something different. Inject fixed dates and local fixtures.

> [!error] Raising tolerances until tests pass
> A tolerance is for anti-aliasing noise. If you need 5% of pixels to differ to pass, the view changed; look at the diff.

> [!error] Snapshotting whole screens for everything
> One screen snapshot fails for every change on the screen. Snapshot components in their important states, and test screen logic with unit tests.

> [!error] Believing a placeholder
> `ImageRenderer` draws a placeholder for views it can't render. A reference image with a gray box where the `Toggle` should be will pass forever and catch nothing.

## Exercises

````exercise
id: m39-l06-e1
type: prediction
prompt: "The snapshot model, used on a delivered order and then after a change in how item counts are written. What does it print?"
code: |
  struct RowState {
      let title: String
      let badge: String?

      var snapshot: String {
          "title: \(title)\nbadge: \(badge ?? "none")"
      }
  }

  enum SnapshotResult {
      case recorded
      case matched
      case failed([String])
  }

  func assertSnapshot(_ value: String, named name: String, references: inout [String: String]) -> SnapshotResult {
      guard let reference = references[name] else {
          references[name] = value
          return .recorded
      }
      if reference == value { return .matched }
      let old = reference.split(separator: "\n").map(String.init)
      let new = value.split(separator: "\n").map(String.init)
      var diff: [String] = []
      for index in 0..<max(old.count, new.count) {
          let before = index < old.count ? old[index] : nil
          let after = index < new.count ? new[index] : nil
          if before != after {
              if let before { diff.append("- \(before)") }
              if let after { diff.append("+ \(after)") }
          }
      }
      return .failed(diff)
  }

  var references: [String: String] = [:]
  let delivered = RowState(title: "Order #7 (1 items)", badge: nil)
  print(assertSnapshot(delivered.snapshot, named: "delivered", references: &references))
  print(assertSnapshot(delivered.snapshot, named: "delivered", references: &references))

  let fixed = RowState(title: "Order #7 (1 item)", badge: nil)
  print(assertSnapshot(fixed.snapshot, named: "delivered", references: &references))
  print(assertSnapshot(fixed.snapshot, named: "pending", references: &references))
output: |
  recorded
  matched
  failed(["- title: Order #7 (1 items)", "+ title: Order #7 (1 item)"])
  recorded
hints:
  - "The first assertion for a name always records."
  - "The fix changes only the title line; the badge line is the same."
  - "A different name is a different reference."
solution: |
  ```output
  recorded
  matched
  failed(["- title: Order #7 (1 items)", "+ title: Order #7 (1 item)"])
  recorded
  ```

  The first run records "1 items", a bug nobody noticed because the first run of a snapshot test proves nothing. The second matches. The pluralization fix changes the title line, and the diff shows exactly that; here the change is intended, so you'd re-record. Asserting with a new name, `pending`, records a new reference. The lesson: review a reference when it's recorded, as carefully as code, because from then on the test defends whatever it contains, bugs included.
````

````exercise
id: m39-l06-e2
type: prediction
prompt: "The image comparison model with a 4 × 4 reference. What does it print?"
code: |
  struct Bitmap {
      let width: Int
      let height: Int
      var pixels: [UInt8]
  }

  func compare(_ reference: Bitmap, _ candidate: Bitmap, perPixelTolerance: Int, maxDifferentFraction: Double) -> (matches: Bool, differing: Int) {
      guard reference.width == candidate.width, reference.height == candidate.height else {
          return (false, reference.pixels.count)
      }
      var differing = 0
      for (a, b) in zip(reference.pixels, candidate.pixels) where abs(Int(a) - Int(b)) > perPixelTolerance {
          differing += 1
      }
      let fraction = Double(differing) / Double(reference.pixels.count)
      return (fraction <= maxDifferentFraction, differing)
  }

  let reference = Bitmap(width: 4, height: 4, pixels: Array(repeating: 100, count: 16))
  var candidate = reference
  candidate.pixels[0] = 103
  candidate.pixels[5] = 110
  candidate.pixels[15] = 98

  print(compare(reference, candidate, perPixelTolerance: 0, maxDifferentFraction: 0.1))
  print(compare(reference, candidate, perPixelTolerance: 2, maxDifferentFraction: 0.125))
  print(compare(reference, candidate, perPixelTolerance: 5, maxDifferentFraction: 0))
output: |
  (matches: false, differing: 3)
  (matches: true, differing: 2)
  (matches: false, differing: 1)
hints:
  - "The differences are 3, 10 and 2."
  - "A pixel differs when its difference is strictly greater than the tolerance."
  - "Out of 16 pixels, 1 is 6.25% and 2 is 12.5%. The fraction must be at or below the maximum."
solution: |
  ```output
  (matches: false, differing: 3)
  (matches: true, differing: 2)
  (matches: false, differing: 1)
  ```

  The three changed pixels differ by 3, 10 and 2.

  - **Tolerance 0, at most 10%:** all three differ. 3 ÷ 16 = 18.75%, more than 10%: no match.
  - **Tolerance 2, at most 12.5%:** the pixel off by 2 is within tolerance, so two differ. 2 ÷ 16 = 12.5%, exactly the maximum: a match.
  - **Tolerance 5, no differing pixels allowed:** only the pixel off by 10 exceeds 5. One pixel is still more than zero: no match.

  The two knobs do different jobs. The per-pixel tolerance decides what counts as "different" (noise versus change); the fraction decides how many different pixels you'll accept. A pixel that changed by 10 levels on a flat color is a real change, and with a zero fraction it fails the test, as it should.
````

````exercise
id: m39-l06-e3
type: comprehension
multiple: true
prompt: "A design system team adds image snapshot tests for its Button, Badge and Card components in light, dark and three text sizes. Which of these problems will those tests catch? Select all that apply."
choices:
  - text: "A refactor reorders padding and background, so the badge's color no longer reaches its edges."
    correct: true
    why: "A visual change in a rendered state: exactly what image snapshots see."
  - text: "The Card's title truncates at the largest text size after a font change."
    correct: true
    why: "Covered, because the tests render at large text sizes."
  - text: "The Button's action fires twice per tap."
    correct: false
    why: "Behavior isn't in a picture. Unit or UI tests catch it."
  - text: "The Badge reads 'New' to VoiceOver instead of '3 new messages'."
    correct: false
    why: "Not visible in an image. Test the accessibility label in the render state, or use an accessibility snapshot plug-in."
  - text: "The dark-mode Card background becomes the same color as its text."
    correct: true
    why: "Rendered in dark mode, the change shows up."
  - text: "The Badge looks wrong in Arabic, which no test renders."
    correct: false
    why: "Snapshots only cover the configurations you render."
solution: |
  **The padding, truncation and dark-mode problems.** Image snapshots catch visual changes in the configurations they render. They don't see behavior (the double action), what assistive technologies hear (unless you snapshot that separately), or configurations nobody rendered (right-to-left, another locale). That's why snapshots sit next to unit tests of the logic, not instead of them.
````

````exercise
id: m39-l06-e4
type: solve
prompt: |
  A transfers list shows, per row: the counterparty, a signed amount (`+$12.50` for incoming, `-$3.00` for outgoing), a badge (`nil` when completed, `Pending`, `Failed`) and an accessibility label such as "Sent $3.00 to Gym, failed". Write `TransferRowState` so all of that is computed outside the view and can be tested. Then print each row for these transfers and check that two states built from the same transfer are equal:

  ```swift
  let cases = [
      Transfer(counterparty: "Ana", amountCents: 1250, isIncoming: true, status: .completed),
      Transfer(counterparty: "Rent", amountCents: 120_005, isIncoming: false, status: .pending),
      Transfer(counterparty: "Gym", amountCents: 300, isIncoming: false, status: .failed),
  ]
  ```
starter: |
  enum TransferStatus {
      case pending, completed, failed
  }

  struct Transfer {
      let counterparty: String
      let amountCents: Int
      let isIncoming: Bool
      let status: TransferStatus
  }

  struct TransferRowState: Equatable {
      // your code
  }
hints:
  - "Pad cents below 10 with a leading zero."
  - "Build the accessibility label from the same values as the visible text, so they can't disagree."
rubric:
  - Formats the amount with a sign and two decimals.
  - Returns nil for completed and the right badge otherwise.
  - Builds an accessibility label that includes direction, amount, counterparty and status.
  - Conforms to Equatable so tests can compare whole states.
  - Prints the expected four lines.
solution: |
  ```swift
  enum TransferStatus {
      case pending, completed, failed
  }

  struct Transfer {
      let counterparty: String
      let amountCents: Int
      let isIncoming: Bool
      let status: TransferStatus
  }

  struct TransferRowState: Equatable {
      let title: String
      let amount: String
      let badge: String?
      let accessibilityLabel: String

      init(_ transfer: Transfer) {
          let dollars = transfer.amountCents / 100
          let cents = transfer.amountCents % 100
          let value = "$\(dollars).\(cents < 10 ? "0" : "")\(cents)"
          title = transfer.counterparty
          amount = (transfer.isIncoming ? "+" : "-") + value

          switch transfer.status {
          case .completed: badge = nil
          case .pending: badge = "Pending"
          case .failed: badge = "Failed"
          }

          let direction = transfer.isIncoming ? "Received \(value) from" : "Sent \(value) to"
          let status = badge.map { ", \($0.lowercased())" } ?? ""
          accessibilityLabel = "\(direction) \(transfer.counterparty)\(status)"
      }
  }

  let cases = [
      Transfer(counterparty: "Ana", amountCents: 1250, isIncoming: true, status: .completed),
      Transfer(counterparty: "Rent", amountCents: 120_005, isIncoming: false, status: .pending),
      Transfer(counterparty: "Gym", amountCents: 300, isIncoming: false, status: .failed),
  ]
  for transfer in cases {
      let state = TransferRowState(transfer)
      print(state.title, state.amount, state.badge ?? "-", "|", state.accessibilityLabel)
  }
  print(TransferRowState(cases[0]) == TransferRowState(cases[0]))
  ```

  ```output
  Ana +$12.50 - | Received $12.50 from Ana
  Rent -$1200.05 Pending | Sent $1200.05 to Rent, pending
  Gym -$3.00 Failed | Sent $3.00 to Gym, failed
  true
  ```

  Everything the row decides is now a value: you can write `#expect(TransferRowState(gym).badge == "Failed")` and `#expect(TransferRowState(gym).accessibilityLabel == "Sent $3.00 to Gym, failed")` in Swift Testing, and they run in milliseconds. The view becomes `Text(state.title)`, `Text(state.amount)` and an optional badge, with `.accessibilityElement(children: .ignore)` and `.accessibilityLabel(state.accessibilityLabel)`. A real app would format money with `FormatStyle` and the user's locale (Module 38, lesson 6), and the tests would pass a fixed locale. `Equatable` lets one assertion compare a whole state, and it's what makes `assertSnapshot(of: state, as: .dump)` readable.
````

````exercise
id: m39-l06-e5
type: find-errors
prompt: "A team's snapshot setup. Which of these are real problems?"
code: |
  // Package.swift: SnapshotTesting added to the "Shop" app target.
  // CI: macos runner, "latest" Xcode, whichever iPhone simulator is first in the list.

  @MainActor
  struct ReceiptSnapshotTests {
      @Test func receipt() {
          let view = ReceiptView(date: Date(), items: Item.randomSamples(count: 5))
          let controller = UIHostingController(rootView: view)
          assertSnapshot(of: controller, as: .image, record: .all)
      }
  }
choices:
  - text: "The library is linked into the app target instead of a test target."
    correct: true
    why: "The README warns about this; it should only be in the test target."
  - text: "References recorded on one simulator are compared on whichever simulator CI picks, with 'latest' Xcode."
    correct: true
    why: "The README: compare on the exact same simulator that took the reference."
  - text: "Date() and random samples make every render different."
    correct: true
    why: "Snapshots need deterministic input: a fixed date and fixed fixtures."
  - text: "record: .all is committed, so the test always records and never fails."
    correct: true
    why: "Record deliberately, locally, then remove the argument."
  - text: "Snapshot tests must be in an XCTestCase subclass."
    correct: false
    why: "The README's first example uses Swift Testing."
rubric:
  - Flags the app-target dependency.
  - Flags the unpinned simulator and Xcode.
  - Flags the non-deterministic inputs.
  - Flags the committed record argument.
solution: |
  Four real problems, each from the README or from what a snapshot needs:

  1. **App target.** The library belongs to the test target only.
  2. **Unpinned environment.** Pin the Xcode version and a specific simulator (model and OS) in CI, and record on the same configuration.
  3. **Non-deterministic data.** Pass a fixed `Date` (for example `Date(timeIntervalSince1970: 1_700_000_000)` with a fixed time zone) and fixed items.
  4. **`record: .all` committed.** The test records every run and passes regardless. Use it, or `withSnapshotTesting(record: .failed)`, locally to re-record, review the new images, then remove it.

  Swift Testing is fine; the README shows it first.
````

````exercise
id: m39-l06-e6
type: fill-in
prompt: "Complete a helper that renders a SwiftUI view at a 390-point width, at 3× scale, to a UIImage."
code: |
  @MainActor
  func renderImage(of view: some View) -> UIImage? {
      let renderer = [[1]](content: view)
      renderer.[[2]] = ProposedViewSize(width: 390, height: nil)
      renderer.[[3]] = 3
      return renderer.[[4]]
  }
blanks:
  - id: "1"
    answers: ["ImageRenderer"]
  - id: "2"
    answers: ["proposedSize"]
  - id: "3"
    answers: ["scale"]
  - id: "4"
    answers: ["uiImage"]
hints:
  - "The renderer's properties are main-actor isolated, which is why the function is @MainActor."
  - "A nil height lets the view choose its own height for that width."
solution: |
  ```swift ios
  import SwiftUI
  import UIKit

  @MainActor
  func renderImage(of view: some View) -> UIImage? {
      let renderer = ImageRenderer(content: view)
      renderer.proposedSize = ProposedViewSize(width: 390, height: nil)
      renderer.scale = 3
      return renderer.uiImage
  }
  ```

  `ImageRenderer(content:)` wraps the view. `proposedSize` is "the size proposed to the root view," so a fixed width and a `nil` height lay it out like a 390-point screen. `scale` is points to pixels (default 1). `uiImage` is "the current contents of the view, rasterized as a UIKit image," or `nil` if it can't render. All of them are `@MainActor`, so the helper is too.
````

````exercise
id: m39-l06-e7
type: design
prompt: "You maintain a shared SwiftUI component library used by three apps. Propose a testing strategy for it: what you'd unit test, what you'd snapshot (and in which configurations), how you'd keep snapshots stable in CI, how you'd handle intended visual changes, and where previews fit."
rubric:
  - Unit tests for component logic through render states or small pure functions (formatting, which variant, accessibility labels).
  - Snapshots of each component's important states in light/dark and a few Dynamic Type sizes, plus right-to-left or a long-string locale where relevant.
  - Pinned Xcode and simulator in CI, deterministic inputs, a small tolerance only for rendering noise.
  - A deliberate re-record flow with review of the new references in the pull request.
  - Previews for every state while developing, noting they don't fail.
solution: |
  A sample strategy:

  - **Unit tests:** each component that decides something (a `Badge` that caps counts at "99+", a `PriceLabel` that formats and signs amounts, a `StatusChip` that maps a status to a color name and label) gets a render state or pure function tested with Swift Testing, including accessibility labels.
  - **Snapshots:** each component in its meaningful states (default, disabled, error, very long text) × light and dark × default and `accessibility3` text size, plus one right-to-left pass for components with directional layout. Component-sized, not screen-sized, so a failure points at one thing. Text snapshots (`.dump` of render states) for logic-heavy components.
  - **Stability:** CI pins one Xcode version and one simulator model and OS; references are recorded on that configuration (a CI job can record and upload them). Inputs are fixed: no `Date()`, no remote images. A small per-pixel tolerance for anti-aliasing only. Upgrading Xcode is a planned re-record.
  - **Intended changes:** the author re-records locally or in CI with a record mode, and the pull request shows old and new images side by side; reviewers approve the visual change like code. `record:` arguments never get merged.
  - **Previews:** every component has named previews for its states and traits, for development. They're the fastest way to see a change, and nothing relies on them to catch one.
````

## Summary

- Most bugs in a view are in what it decides. Put those decisions in a render state computed from the model, and unit test it.
- A snapshot test records a reference on the first run (and fails so someone reviews it), then fails with a diff when output changes. A reviewed reference is a test; an unreviewed one is a recording of whatever was there.
- Text snapshots of state are cheap and stable. Image snapshots catch visual regressions but depend on the simulator, OS, scale and GPU; pin them, use small tolerances for noise only, and expect re-records on Xcode upgrades.
- `ImageRenderer` (iOS 16, `@MainActor`) rasterizes SwiftUI views; set `proposedSize`, `scale` and environment values. It draws placeholders for views composited by Core Animation, such as many controls, web views and UIKit views.
- swift-snapshot-testing (from its README): add it to the test target; `assertSnapshot(of:as:)` with strategies like `.image`, `.image(on:)`, `.recursiveDescription`, `.json` and `.dump`; record with `record:`, `withSnapshotTesting(record:)` or `@Suite(.snapshots(record:))`, and never commit a record mode.
- Previews with traits and environment values are fast visual checks for many states. They don't fail; tests do.
