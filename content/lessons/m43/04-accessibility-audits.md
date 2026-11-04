---
id: m43-l04
title: Accessibility audits across an app
description: "Modules 27 and 38 made single screens accessible. An existing app has fifty screens and nobody knows which ones work with VoiceOver. You plan an audit the way Apple's testing guide describes (main tasks per screen, a matrix of settings and assistive technologies), run Accessibility Inspector's audits and export the report, automate the same audits per screen with XCUIApplication.performAccessibilityAudit, triage findings against a reviewed baseline so only new issues fail the build, fix the findings that show up most (missing labels, small hit regions, clipped and fixed-size text, labels Voice Control can't match), and test tasks end to end with VoiceOver, Voice Control and Switch Control."
module: m43
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m43-l03, m27-l06, m38-l05, m33-l05]
objectives:
  - Plan an accessibility audit of an existing app as a list of main tasks per screen and a testing matrix.
  - Run Accessibility Inspector audits, read the issue categories per platform, and know what an audit can't find.
  - Automate audits in UI tests with performAccessibilityAudit(for:_:) and keep a reviewed baseline of accepted issues.
  - Fix the common findings in UIKit and SwiftUI, including hit regions, Dynamic Type and Voice Control names.
  - Test main tasks with VoiceOver, Voice Control and Switch Control using the setup and commands Apple describes.
terms:
  - term: Accessibility audit
    definition: "An automated check of one screen for common issues. Accessibility Inspector's audits on iOS cover element description, hit region, contrast, element detection, clipped text, traits and Dynamic Type; the same checks run in UI tests with performAccessibilityAudit(for:_:) (iOS 17)."
  - term: Testing matrix
    definition: "The combination of devices, accessibility settings and assistive technologies with which each main task in the app is tested, as Apple's testing guide recommends."
  - term: Input label
    definition: "A name Voice Control and Full Keyboard Access accept for an element: accessibilityInputLabels(_:) in SwiftUI, accessibilityUserInputLabels in UIKit. Without one, the accessibility label is used."
  - term: Hit region
    definition: "The area that responds to a touch. Apple's HIG gives 44×44 pt as the default control size on iOS and 28×28 pt as the minimum."
  - term: Audit baseline
    definition: "A reviewed list of known audit findings, each with a reason, an owner and an expiry, so automated audits fail only on new issues while old ones are fixed on a schedule."
mastery:
  - Write the main tasks and the testing matrix for three screens of an app.
  - Turn an Accessibility Inspector finding into a code fix in UIKit and in SwiftUI.
  - Write a UI test that audits each main screen and filters only reviewed issues.
  - Check that every control's spoken label contains its visible text, and add input labels for icon-only controls.
  - Complete a main task with Screen Curtain on, and with Voice Control's "Show numbers."
resources: [accessibility-performing-audits, accessibility-inspector, xcuiautomation, uikit-supporting-voiceover, swiftui-accessibility-fundamentals, uikit-accessibility-traits, uikit-scaling-fonts, swiftui-scaledmetric, hig]
cards:
  - id: m43-l04-c1
    front: Which audits does Accessibility Inspector run for iOS?
    back: "On all platforms: element description, hit region, contrast, element detection. On iOS, watchOS and tvOS also: clipped text, traits and Dynamic Type. (Parent/child and action are macOS.) Apple: eliminating all audit issues doesn't guarantee a fully accessible app."
  - id: m43-l04-c2
    front: How do you run the same audits in a UI test?
    back: "Navigate to the screen and call try app.performAccessibilityAudit() (iOS 17), optionally for a subset like [.contrast, .dynamicType] and with an issue handler. Apple: if the UI test finds any audit issues, it automatically fails."
  - id: m43-l04-c3
    front: What does Apple's testing guide ask you to prepare before testing?
    back: "A list of the main tasks a person can perform on each screen, and a testing matrix of devices, accessibility settings (Bold Text, Larger Accessibility Sizes, Increase Contrast, Reduce Motion…) and assistive technologies (VoiceOver, Voice Control, Switch Control). VoiceOver, Voice Control and Switch Control need a physical device."
  - id: m43-l04-c4
    front: Why should an accessibility label contain the visible text?
    back: "Voice Control users say what they see (\"Tap Add to cart\"). If the label is \"Purchase item\", the command doesn't match. Keep the visible words in the label (WCAG's Label in Name criterion) and add input labels for icon-only controls."
  - id: m43-l04-c5
    front: HIG control sizes on iOS?
    back: "Default 44×44 pt, minimum 28×28 pt. Grow the hit region (contentShape, frame, or point(inside:with:)) rather than the drawn icon when the design needs a small glyph."
---

## The idea in one sentence

**An accessibility audit of a whole app is a plan (main tasks, screens, settings, assistive technologies), an automated check that runs on every build, and people completing real tasks with VoiceOver, Voice Control and Switch Control**, because the automated part, by Apple's own statement, can't tell you the app is accessible.

> [!note] Sources and what was checked
> The audit categories, export, fix suggestions and UI test integration are from Apple's "Performing accessibility audits for your app"; the main tasks, testing matrix, settings and assistive technology setup from "Performing accessibility testing for your app"; control sizes and contrast values from the Human Interface Guidelines' Accessibility page; `performAccessibilityAudit(for:_:)`, `XCUIAccessibilityAuditType` and `XCUIAccessibilityAuditIssue` from their reference pages (which list signatures without discussion); `accessibilityInputLabels(_:)`, `UIAccessibilityCustomAction`, `preferredFont(forTextStyle:)` and `adjustsFontForContentSizeCategory` from theirs. All read in November 2026. Accessibility Inspector, VoiceOver, Voice Control and Switch Control weren't used for this lesson. UIKit and SwiftUI blocks are type-checked against the iOS SDK, not run; the UI test is illustrative (not compiled). The size, label and triage checks are plain Swift, compiled and run with Swift 6.3.

## Where Pantry starts

Pantry has never had an accessibility pass. A VoiceOver user wrote to support: they can browse the catalog but can't add anything to the cart. The team's first instinct is to fix that button. The second, better one is to find out what else is broken before customers do, and keep it from breaking again.

Modules 27 and 38 taught the techniques: labels, values and traits, grouping cells into one element, custom actions, reading order, adjustable controls, Dynamic Type layouts, contrast. This lesson is about applying them to an app at scale.

## Plan: tasks, screens, matrix

Apple's testing guide starts before any tool: "compile a list of the main tasks that a person can perform on each screen in your app." For Pantry:

| Screen | Main tasks |
| --- | --- |
| Onboarding | Complete or skip onboarding; allow or decline location |
| Sign in | Choose Sign in with Apple or email; enter email and password; reset password |
| Catalog | Search; filter by category; open a product; add a product to the cart |
| Product detail | Read price, stock and description; change quantity; add to cart; view photos |
| Cart | Change quantities; remove an item; apply a promo code; go to checkout |
| Checkout | Choose delivery time; choose payment; place the order; read errors |
| Order tracking | Read status and arrival time; contact the courier |

Then a **testing matrix**: which devices, settings and assistive technologies each task is tested with. Apple's starting categories are visual accessibility (color, text, motion), media accessibility (captions, audio descriptions) and assistive technologies. The settings it lists include Bold Text, Larger Accessibility Sizes, Button Shapes, On/Off Labels, Reduce Transparency, Increase Contrast, Differentiate Without Color, Color Filters, Reduce Motion and Dim Flashing Lights.

The plan is data, so its coverage can be tracked like anything else:

```swift
enum Check: String, CaseIterable {
    case audit = "audit"
    case voiceOver = "VoiceOver"
    case voiceControl = "Voice Control"
    case switchControl = "Switch Control"
    case largestText = "largest text"
}

struct ScreenStatus {
    let screen: String
    let passed: Set<Check>
    let failing: [Check: String]          // check → issue tracker reference
}

let statuses = [
    ScreenStatus(screen: "Catalog", passed: [.audit, .voiceOver, .largestText], failing: [.voiceControl: "PAN-412"]),
    ScreenStatus(screen: "Product detail", passed: [.audit], failing: [.voiceOver: "PAN-398", .largestText: "PAN-415"]),
    ScreenStatus(screen: "Cart", passed: Set(Check.allCases), failing: [:]),
    ScreenStatus(screen: "Checkout", passed: [], failing: [:]),
]

for status in statuses {
    let untested = Check.allCases.filter { !status.passed.contains($0) && status.failing[$0] == nil }
    var line = "\(status.screen): \(status.passed.count)/\(Check.allCases.count) passed"
    let failures = Check.allCases.compactMap { check in status.failing[check].map { "\(check.rawValue) (\($0))" } }
    if !failures.isEmpty { line += "; failing: " + failures.joined(separator: ", ") }
    if !untested.isEmpty { line += "; not tested: " + untested.map(\.rawValue).joined(separator: ", ") }
    print(line)
}
```

```output
Catalog: 3/5 passed; failing: Voice Control (PAN-412); not tested: Switch Control
Product detail: 1/5 passed; failing: VoiceOver (PAN-398), largest text (PAN-415); not tested: Voice Control, Switch Control
Cart: 5/5 passed
Checkout: 0/5 passed; not tested: audit, VoiceOver, Voice Control, Switch Control, largest text
```

- **Three states, not two.** "Not tested" is different from "failing." A screen with no failures and no tests (Checkout) is the riskiest line in the report, and it's the screen where people pay.
- **Every failure has a ticket.** A finding without an owner is a finding nobody fixes.
- Iterating `Check.allCases` keeps the output in a fixed order; iterating the `Set` or the dictionary wouldn't.

## Automated audits

### Accessibility Inspector

Apple: "In Accessibility Inspector, the Audits pane provides the ability to audit your app for a few of the most common accessibility issues." Choose the app from the target menu, pick which tests to run in Options, and click Run Audit for **each screen**. The tests by platform:

| Platform | Audit | What it checks (Apple's wording) |
| --- | --- | --- |
| All | Element description | "Each element's accessibility label. All accessible elements must provide some context-specific, descriptive label." |
| All | Hit region | "Whether the size of an element is too small for a person to interact with." |
| All | Contrast | "Sufficient color contrast between overlapping elements." |
| All | Element detection | "Whether any elements contain inaccessible content that your app might need to expose as separate accessibility children." |
| iOS, watchOS, tvOS | Clipped text | "Whether clipping might occur for any text labels at larger Dynamic Type sizes." |
| iOS, watchOS, tvOS | Traits | That an object "implements all the properties and methods required for the accessibility traits it possesses." |
| iOS, watchOS, tvOS | Dynamic Type | "Whether the text in your app supports Dynamic Type." |
| macOS | Parent/child, Action | Hierarchy integrity and valid actions |

Each issue can be expanded for an explanation, highlighted on screen, captured as a screenshot, and opened with **fix suggestions** ("guidance for specific colors, font sizes, or APIs"). File > Save Audit Report As… exports "a single HTML file that contains a summary of every audit result," which is how Pantry's first audit reached the designers.

For contrast, the HIG says Accessibility Inspector uses WCAG Level AA values: 4.5:1 for text up to 17 pt, 3:1 for 18 pt and for bold text. Module 27 computed the ratio itself.

And Apple's warning, worth putting at the top of the report: "eliminating all audit issues that Accessibility Inspector reports doesn't guarantee a fully accessible app. Always test your app with various assistive apps, such as VoiceOver."

### The same audits in UI tests

`performAccessibilityAudit(for:_:)` (iOS 17) on `XCUIApplication` "audits the current screen for accessibility issues the same way that running an audit in Accessibility Inspector does. If the UI test finds any audit issues, it automatically fails." Its declaration:

```swift illustrative
@MainActor func performAccessibilityAudit(
    for auditTypes: XCUIAccessibilityAuditType = .all,
    _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil
) throws
```

`XCUIAccessibilityAuditType` is an option set with `.sufficientElementDescription`, `.hitRegion`, `.contrast`, `.elementDetection`, `.textClipped`, `.trait`, `.dynamicType` (and the macOS-only `.parentChild` and `.action`), plus `.all`. Each `XCUIAccessibilityAuditIssue` has an `auditType`, a `compactDescription`, a `detailedDescription` and the `element`, if there is one.

Pantry adds one audit per main screen to its UI tests:

```swift illustrative
import XCTest

final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]      // stubbed backend, signed-in test account
        app.launch()
        return app
    }

    @MainActor
    func testCatalogAudit() throws {
        let app = launchedApp()
        app.tabBars.buttons["Catalog"].tap()
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testProductDetailAudit() throws {
        let app = launchedApp()
        app.tabBars.buttons["Catalog"].tap()
        app.collectionViews.cells.firstMatch.tap()
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .textClipped, .dynamicType]) { issue in
            // true means "handled": this known issue won't fail the test.
            AuditBaseline.isAccepted(screen: "Product detail", issue: issue)
        }
    }
}
```

- **Navigate, then audit.** An audit only sees the current screen, so each main screen gets its own test. Screens behind sign-in or a network call need a launch argument and a stubbed backend, as in Module 33.
- **The issue handler** returns a `Bool`. Apple's reference page lists the signature without a discussion; in Apple's WWDC23 session "Perform accessibility audits for your app" (which the audits article links to), returning `true` marks an issue as handled so it doesn't fail the test, and `false` lets it fail. That behavior comes from the session, not the reference page.
- **Filtering by type** (the second test) is how to stage adoption: start with the categories you've already fixed and add the rest as you go.
- `AuditBaseline` is Pantry's own code, the subject of the next section.

### A baseline, not a mute button

The first audit of Pantry found 137 issues. Fixing all of them before turning on the tests would mean the tests never get turned on; ignoring them all would mean new ones slip in unnoticed. The middle path is a reviewed **baseline**: each accepted issue has a reason, a ticket and an expiry. New issues fail; expired acceptances fail; and entries for issues that no longer occur are flagged for removal, so the baseline only shrinks.

```swift
struct Finding: Hashable {
    let screen: String
    let type: String
    let element: String
}

struct Accepted {
    let finding: Finding
    let ticket: String
    let expiresOnDay: Int       // days since the project's epoch, to keep the example free of dates
}

func triage(found: [Finding], baseline: [Accepted], today: Int) -> [String] {
    var report: [String] = []
    let accepted = Dictionary(uniqueKeysWithValues: baseline.map { ($0.finding, $0) })
    for finding in found {
        let where_ = "\(finding.screen) / \(finding.type) / \(finding.element)"
        guard let entry = accepted[finding] else {
            report.append("FAIL new: \(where_)")
            continue
        }
        if entry.expiresOnDay < today {
            report.append("FAIL expired \(entry.ticket): \(where_)")
        } else {
            report.append("ok accepted \(entry.ticket) until day \(entry.expiresOnDay): \(where_)")
        }
    }
    let stillFound = Set(found)
    for entry in baseline where !stillFound.contains(entry.finding) {
        report.append("REMOVE fixed \(entry.ticket) from baseline: \(entry.finding.screen) / \(entry.finding.element)")
    }
    return report
}

let baseline = [
    Accepted(finding: Finding(screen: "Catalog", type: "contrast", element: "promoBadge"), ticket: "PAN-401", expiresOnDay: 120),
    Accepted(finding: Finding(screen: "Product detail", type: "textClipped", element: "nutritionTable"), ticket: "PAN-415", expiresOnDay: 90),
    Accepted(finding: Finding(screen: "Cart", type: "hitRegion", element: "removeButton"), ticket: "PAN-388", expiresOnDay: 150),
]
let found = [
    Finding(screen: "Catalog", type: "contrast", element: "promoBadge"),
    Finding(screen: "Product detail", type: "textClipped", element: "nutritionTable"),
    Finding(screen: "Product detail", type: "sufficientElementDescription", element: "favoriteButton"),
]
for line in triage(found: found, baseline: baseline, today: 100) { print(line) }
```

```output
ok accepted PAN-401 until day 120: Catalog / contrast / promoBadge
FAIL expired PAN-415: Product detail / textClipped / nutritionTable
FAIL new: Product detail / sufficientElementDescription / favoriteButton
REMOVE fixed PAN-388 from baseline: Cart / removeButton
```

- **Findings are keyed by screen, type and element**, using the accessibility identifier where there is one. Matching on the free-text description would break whenever Apple rewords it.
- **Expiry turns "later" into a date.** PAN-415 was accepted until day 90; on day 100 the build fails until someone fixes it or a reviewer explicitly extends it.
- **The fixed entry** must be removed, otherwise the remove button could regress later and still be "accepted."
- In the UI test, `AuditBaseline.isAccepted(screen:issue:)` does the lookup and records what it saw, and a final step produces this report.

## Fixing the common findings

Pantry's 137 issues fell into a handful of kinds. The fixes are the techniques from Modules 27 and 38, applied systematically.

**Missing descriptions** were mostly icon-only buttons: favorite, share, filter, the cart's minus and plus. **Clipped text and Dynamic Type** came from fixed font sizes and fixed-height rows. **Hit regions** came from 20-point icons with no padding. In UIKit:

```swift ios
import UIKit

/// A small glyph with a hit region at least as large as the HIG's default control size.
final class CompactIconButton: UIButton {
    private let minimumSide: CGFloat = 44

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let dx = max(0, (minimumSide - bounds.width) / 2)
        let dy = max(0, (minimumSide - bounds.height) / 2)
        return bounds.insetBy(dx: -dx, dy: -dy).contains(point)
    }
}

@MainActor
func configureProductRow(title: UILabel, price: UILabel, favorite: CompactIconButton, isFavorite: Bool) {
    // Dynamic Type: text styles that scale, updated automatically when the setting changes.
    title.font = UIFont.preferredFont(forTextStyle: .body)
    title.adjustsFontForContentSizeCategory = true
    title.numberOfLines = 0
    price.font = UIFont.preferredFont(forTextStyle: .headline)
    price.adjustsFontForContentSizeCategory = true

    // Element description and state for an icon-only button.
    favorite.setImage(UIImage(systemName: isFavorite ? "heart.fill" : "heart"), for: .normal)
    favorite.accessibilityLabel = "Favorite"
    favorite.accessibilityTraits = isFavorite ? [.button, .selected] : [.button]
    favorite.accessibilityUserInputLabels = ["Favorite", "Heart", "Save"]
}
```

- **`point(inside:with:)`** grows the touch area to 44 × 44 pt without changing the drawing. The HIG lists 44 × 44 pt as the default control size on iOS and 28 × 28 pt as the minimum.
- **`preferredFont(forTextStyle:)` plus `adjustsFontForContentSizeCategory`** is what makes a label follow the setting; Apple says the property only takes effect for fonts "vended using the `preferredFont(forTextStyle:)` … method" or `UIFontMetrics`. `numberOfLines = 0` and a self-sizing row fix the clipping.
- **`accessibilityUserInputLabels`** gives Voice Control and Full Keyboard Access extra names. Apple's SwiftUI page for the equivalent modifier: "Provide labels in descending order of importance. Voice Control and Full Keyboard Access use the input labels."
- **State in traits**: `.selected` tells VoiceOver it's on, instead of relying on a filled heart.

The same fixes in a SwiftUI screen:

```swift ios
import SwiftUI

struct ProductRow: View {
    let name: String
    let price: String
    @Binding var isFavorite: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(name).font(.body)
                Text(price).font(.headline)
            }
            Spacer()
            Button {
                isFavorite.toggle()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Favorite")
            .accessibilityInputLabels(["Favorite", "Heart", "Save"])
            .accessibilityAddTraits(isFavorite ? .isSelected : [])
        }
    }
}
```

`.frame(minWidth:minHeight:)` with `.contentShape(Rectangle())` makes the whole 44-point area tappable, not just the glyph's pixels. Text styles (`.body`, `.headline`) scale with Dynamic Type; a fixed `.system(size: 14)` doesn't.

### Labels Voice Control can match

Voice Control users act by speaking what they see: Apple's command table includes "Tap item name or number." If a button shows "Add to cart" but its accessibility label is "Purchase this item," saying "Tap Add to cart" doesn't match. WCAG 2.2 calls this criterion **Label in Name**: the accessible name should contain the visible text. Audits don't check it, so Pantry wrote its own check over the label data its UI tests collect:

```swift
struct Control {
    let identifier: String
    let visibleText: String?        // nil for icon-only controls
    let label: String
    let inputLabels: [String]
}

func words(_ text: String) -> String {
    text.lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .joined(separator: " ")
}

func voiceControlFindings(_ controls: [Control]) -> [String] {
    controls.compactMap { control in
        if let visible = control.visibleText {
            return words(control.label).contains(words(visible))
                ? nil
                : "\(control.identifier): label \"\(control.label)\" doesn't contain visible \"\(visible)\""
        }
        return control.inputLabels.isEmpty
            ? "\(control.identifier): icon-only, no input labels besides \"\(control.label)\""
            : nil
    }
}

let controls = [
    Control(identifier: "addToCart", visibleText: "Add to cart", label: "Purchase this item", inputLabels: []),
    Control(identifier: "checkout", visibleText: "Checkout", label: "Checkout, 3 items", inputLabels: []),
    Control(identifier: "promo", visibleText: "Apply code!", label: "Apply code", inputLabels: []),
    Control(identifier: "favorite", visibleText: nil, label: "Favorite", inputLabels: ["Favorite", "Heart"]),
    Control(identifier: "filter", visibleText: nil, label: "Filter", inputLabels: []),
]
for finding in voiceControlFindings(controls) { print(finding) }
```

```output
addToCart: label "Purchase this item" doesn't contain visible "Add to cart"
filter: icon-only, no input labels besides "Filter"
```

- **"Checkout, 3 items" passes**: it starts with the visible word and adds context for VoiceOver, which is fine.
- **Punctuation and case are ignored**, so "Apply code!" matches "Apply code."
- **The filter icon** passes VoiceOver (it has a label) but someone looking at a funnel might say "Tap funnel" or "Tap sort." The check only asks that someone decided; whether "Filter" alone is enough is a judgment call. Apple notes that without input labels, "the user can still refer to the view using the accessibility label."
- The data comes from the UI test target, which can read each element's `label` and `identifier` with `XCUIElement`; visible text comes from the design system's button component, which records what it renders.

## Testing with assistive technologies

Apple's guide is clear that this is the part automation can't replace: "Work through your testing matrix by completing the main tasks in your app using only that assistive technology." VoiceOver, Voice Control, Switch Control and Assistive Access all need a physical device, since none is available in Simulator.

**VoiceOver.** Set up the Accessibility Shortcut first so you can turn it off, set a speaking rate you can follow, and turn on Speak Hints if the app provides hints. Apple's key gestures: tap to select and speak, swipe right or left for next or previous, double tap to activate, two-finger tap to pause, two-finger swipe up to read the whole screen, and three-finger triple tap for **Screen Curtain**. Apple: "turn on the screen curtain to replicate the experience of someone who is solely relying on VoiceOver." Pantry's VoiceOver user couldn't add to cart because the button was inside a cell grouped with `.ignore` and had no custom action (Module 38's mistake); with Screen Curtain on, the team found it in a minute.

**Voice Control.** Turn it on in Settings > Accessibility > Voice Control, in a quiet place. Apple's commands: "Open *app name*," "Show names" or "Show numbers" to overlay labels, "Tap *item name or number*," "Scroll down" or "Scroll up," "Stop listening" and "Start listening," "Show commands." With "Show names," every label is on screen at once, which makes mismatches like "Purchase this item" obvious.

**Switch Control.** In Settings > Accessibility > Switch Control > Switches, choose Add New Switch, pick a type of switch (or a Bluetooth device) and assign it an action, then turn Switch Control on. Switch Control highlights items in turn and the person acts with the switch (Apple's testing guide points to the platform user guides for the details), so long unstructured lists and screens with many small controls take many steps. Custom actions help, because assistive technologies "display your custom actions to the user at appropriate times"; so does a sensible grouping of each cell into one element.

For each, Apple's pass criteria have the same three lines: a person "can perform all tasks within your app using only" that technology, it "can output all information in the app," and "for each item in the UI," it "reports the UI element name and status correctly."

**Settings.** Repeat the main tasks with each setting on, one at a time: the largest accessibility text size, Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion, Differentiate Without Color, Button Shapes. Apple's checklist: the app "responds to Dynamic Type accessibility text sizes by reflowing its layout, avoiding text truncation, and making sure UI elements don't overlap," "doesn't use color alone to convey information," and responds to Increase Contrast, Button Shapes, Reduce Motion and Dim Flashing Lights.

## Keeping it fixed

- **Audits per screen in UI tests**, with the baseline, on every pull request.
- **The label check** from this lesson in the same run.
- **A VoiceOver, Voice Control and Switch Control pass** on the main tasks before each release, recorded in the coverage table, and whenever a screen is redesigned.
- **New components** in the design system ship with labels, input labels, traits, scaling fonts and a 44-point hit region, so every screen that uses them starts accessible.
- **People who use these technologies daily**, when you can recruit them, find what the team's tests don't.

## Common mistakes

> [!error] Treating a clean audit as "accessible"
> Audits find missing labels, small targets, clipping and contrast. They can't tell you that a task is impossible with VoiceOver, that a label is meaningless, or that focus jumps somewhere unexpected. Apple says as much.

> [!error] Auditing only the first screen
> An audit sees one screen. Run it on every main screen, including empty, error and loading states, which are where the worst issues hide.

> [!error] An issue handler that returns true for everything
> It silences the test. Accept issues individually, with a ticket and an expiry, and fail on everything else.

> [!error] Labels that don't contain the visible text
> VoiceOver users hear the label; Voice Control users say what they see. "Purchase this item" on an "Add to cart" button breaks Voice Control.

> [!error] Growing the icon instead of the hit region
> Designers rightly resist 44-point glyphs. Keep the glyph and extend the touchable area with `contentShape` and a frame, or `point(inside:with:)`.

> [!error] Testing VoiceOver while looking at the screen
> You'll navigate by sight without noticing. Turn on Screen Curtain.

## Exercises

````exercise
id: m43-l04-e1
type: prediction
prompt: "The Voice Control label check from the lesson on another set of controls. What does it print?"
code: |
  struct Control {
      let identifier: String
      let visibleText: String?
      let label: String
      let inputLabels: [String]
  }

  func words(_ text: String) -> String {
      text.lowercased()
          .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
          .joined(separator: " ")
  }

  func findings(_ controls: [Control]) -> [String] {
      controls.compactMap { control in
          if let visible = control.visibleText {
              return words(control.label).contains(words(visible)) ? nil : control.identifier
          }
          return control.inputLabels.isEmpty ? "\(control.identifier) (icon)" : nil
      }
  }

  let controls = [
      Control(identifier: "save", visibleText: "Save", label: "Save changes", inputLabels: []),
      Control(identifier: "next", visibleText: "Next step", label: "Continue", inputLabels: []),
      Control(identifier: "share", visibleText: nil, label: "Share", inputLabels: []),
      Control(identifier: "qty", visibleText: "Qty: 2", label: "Quantity, 2", inputLabels: []),
      Control(identifier: "close", visibleText: nil, label: "Close", inputLabels: ["Close", "Dismiss"]),
  ]
  print(findings(controls))
output: |
  ["next", "share (icon)", "qty"]
hints:
  - "words(\"Qty: 2\") is \"qty 2\". Is that inside \"quantity 2\"?"
  - "The close button has input labels, so it passes."
solution: |
  ```output
  ["next", "share (icon)", "qty"]
  ```

  - **save** passes: "save changes" contains "save."
  - **next** fails: "continue" doesn't contain "next step."
  - **share** is icon-only with no input labels.
  - **qty** fails: "qty 2" isn't a substring of "quantity 2." VoiceOver users hear "Quantity, 2," which is good, but someone saying "Tap Qty" won't match. Add "Qty" as an input label, or show "Quantity" on screen.
  - **close** passes because it has input labels.
````

````exercise
id: m43-l04-e2
type: comprehension
prompt: "Pantry's UI tests run performAccessibilityAudit() on every main screen and all pass. Which statement is correct?"
choices:
  - text: "The app still needs task-based testing with VoiceOver, Voice Control and Switch Control; Apple says passing audits doesn't guarantee a fully accessible app."
    correct: true
    why: "Apple: \"eliminating all audit issues that Accessibility Inspector reports doesn't guarantee a fully accessible app.\""
  - text: "The app is accessible on iOS; manual testing is only needed for macOS."
    correct: false
    why: "Audits check a few common issues per screen; they can't complete tasks or judge whether labels make sense."
  - text: "The audits also verified that reading order is logical."
    correct: false
    why: "Reading order isn't one of the audit types. You check it with VoiceOver."
  - text: "VoiceOver testing can now be done in the simulator, since the audits passed there."
    correct: false
    why: "Apple: VoiceOver isn't available on Simulator; install the app on a physical device."
solution: |
  Audits cover element descriptions, hit regions, contrast, element detection, clipped text, traits and Dynamic Type. They don't know your tasks. A screen can pass every audit and still trap focus in a sheet, read a price before its product name, or hide the only "Add to cart" inside a grouped cell. Apple's testing guide makes task completion with each assistive technology the criterion.
````

````exercise
id: m43-l04-e3
type: fill-in
prompt: "Complete Pantry's audit test for the cart, which checks only descriptions, hit regions and clipping, and accepts issues from the baseline."
code: |
  @MainActor
  func testCartAudit() throws {
      app.tabBars.buttons["Cart"].tap()
      try app.[[1]](for: [.[[2]], .hitRegion, .[[3]]]) { issue in
          AuditBaseline.isAccepted(screen: "Cart", issue: issue)
      }
  }
blanks:
  - id: "1"
    answers: ["performAccessibilityAudit"]
  - id: "2"
    answers: ["sufficientElementDescription"]
  - id: "3"
    answers: ["textClipped"]
solution: |
  ```swift illustrative
  @MainActor
  func testCartAudit() throws {
      app.tabBars.buttons["Cart"].tap()
      try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .textClipped]) { issue in
          AuditBaseline.isAccepted(screen: "Cart", issue: issue)
      }
  }
  ```

  The audit types are options of `XCUIAccessibilityAuditType`. The closure returns whether the issue is handled (per Apple's WWDC23 session): `true` for a reviewed, unexpired baseline entry, `false` otherwise, so new issues still fail.
````

````exercise
id: m43-l04-e4
type: find-errors
prompt: "A pull request \"fixes accessibility\" on Pantry's promo banner. Mark every real problem."
code: |
  struct PromoBanner: View {
      var body: some View {
          HStack {
              Text("20% off fruit").font(.system(size: 13))
              Spacer()
              Button { claim() } label: {
                  Image(systemName: "gift").frame(width: 20, height: 20)
              }
              .accessibilityLabel("Button to redeem the current promotion")
          }
          .frame(height: 32)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Promotion")
      }
  }
choices:
  - text: "A fixed 13-point font doesn't scale with Dynamic Type."
    correct: true
  - text: "The fixed 32-point height will clip text at larger sizes."
    correct: true
  - text: "The button's hit region is 20 × 20 pt, below the HIG's 28 × 28 pt minimum."
    correct: true
  - text: "Grouping with .ignore hides the button from VoiceOver, and the group's label drops the offer itself."
    correct: true
  - text: "The button's label says \"Button\" and describes rather than names the action."
    correct: true
  - text: "SF Symbols can't be used in buttons that need accessibility labels."
    correct: false
    why: "They can; the label just has to be set, as here."
rubric:
  - I flagged the fixed font and the fixed height.
  - I flagged the hit region.
  - I flagged the .ignore grouping that hides the button and the offer.
  - I flagged the wordy label that includes the trait.
solution: |
  - **Font and height:** use `.font(.subheadline)` (a text style) and drop the fixed height, or use `minHeight`. Audits report these as Dynamic Type and clipped text.
  - **Hit region:** `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` around the image.
  - **`.ignore`** makes the HStack one element labeled "Promotion": VoiceOver can't reach the button and never hears "20% off fruit." Use `.combine` or `.contain`, or keep `.ignore` with a full label ("20% off fruit") and an `accessibilityAction(named: "Redeem")`.
  - **Label:** VoiceOver already says "button" from the trait. "Redeem" is short, names the action, and is something a Voice Control user could guess; add input labels like "Gift" for the icon.
````

````exercise
id: m43-l04-e5
type: solve
prompt: |
  Write `hitRegionFindings(_:)` for elements measured in a UI test. Each has an identifier, a width and height in points, and an optional extra margin added on every side by `point(inside:with:)` or `contentShape`. Using the HIG's iOS sizes, report `"below minimum"` when the effective width or height is under 28, `"below default"` when either is under 44, and nothing otherwise. Keep the input order.

  Expected output:

  ```output
  cartMinus: 20×20 below minimum
  cartPlus: 36×36 below default
  ```
starter: |
  struct Element {
      let identifier: String
      let width: Int
      let height: Int
      let extraMargin: Int
  }

  func hitRegionFindings(_ elements: [Element]) -> [String] {
      // your code
      return []
  }

  let elements = [
      Element(identifier: "cartMinus", width: 20, height: 20, extraMargin: 0),
      Element(identifier: "cartPlus", width: 20, height: 20, extraMargin: 8),
      Element(identifier: "favorite", width: 20, height: 20, extraMargin: 12),
      Element(identifier: "checkout", width: 320, height: 50, extraMargin: 0),
  ]
  for finding in hitRegionFindings(elements) { print(finding) }
hints:
  - "The effective size adds the margin on both sides: width + 2 × margin."
  - "Check the minimum first; an element below 28 is also below 44, but should be reported once, with the worse finding."
rubric:
  - Computes effective width and height including margins on both sides.
  - Uses 28 and 44 as thresholds and reports the worse one once.
  - Reports nothing for elements that meet the default size.
solution: |
  ```swift
  struct Element {
      let identifier: String
      let width: Int
      let height: Int
      let extraMargin: Int
  }

  func hitRegionFindings(_ elements: [Element]) -> [String] {
      elements.compactMap { element in
          let width = element.width + 2 * element.extraMargin
          let height = element.height + 2 * element.extraMargin
          let smallest = min(width, height)
          let size = "\(width)×\(height)"
          if smallest < 28 { return "\(element.identifier): \(size) below minimum" }
          if smallest < 44 { return "\(element.identifier): \(size) below default" }
          return nil
      }
  }

  let elements = [
      Element(identifier: "cartMinus", width: 20, height: 20, extraMargin: 0),
      Element(identifier: "cartPlus", width: 20, height: 20, extraMargin: 8),
      Element(identifier: "favorite", width: 20, height: 20, extraMargin: 12),
      Element(identifier: "checkout", width: 320, height: 50, extraMargin: 0),
  ]
  for finding in hitRegionFindings(elements) { print(finding) }
  ```

  ```output
  cartMinus: 20×20 below minimum
  cartPlus: 36×36 below default
  ```

  The plus button's 8-point margin brings it to 36 × 36: tappable, but under the HIG's default. The favorite button's 12-point margin reaches exactly 44 × 44 and passes. The same 20-point glyph is in all three; only the touchable area changes, which is the point.
````

````exercise
id: m43-l04-e6
type: design
prompt: "Write the accessibility test plan for Pantry's checkout screen (delivery time picker, payment method list, promo code field, order summary, \"Place order\" button, inline error messages). Include main tasks, the matrix, the automated checks, and what you'll look for with each assistive technology."
rubric:
  - Lists the main tasks, including recovering from an error.
  - Defines a matrix with at least the largest text size, Increase Contrast, Reduce Motion, VoiceOver, Voice Control and Switch Control, on a physical device.
  - Adds an audit test for the screen in its normal, error and loading states, with baseline handling.
  - Names specific things to verify per technology (error announcement, label-in-name, reachable picker, grouping).
solution: |
  **Main tasks:** choose a delivery time; choose or add a payment method; apply a promo code (valid and invalid); read the total; place the order; recover from a declined payment.

  **Matrix:** oldest supported iPhone and an iPad; settings one at a time: largest accessibility text size, Bold Text, Increase Contrast, Differentiate Without Color, Reduce Motion; assistive technologies: VoiceOver with Screen Curtain, Voice Control, Switch Control.

  **Automated:** `performAccessibilityAudit()` on the screen in three states (normal, promo error shown, placing order), launched with a stubbed backend; the label-in-name check; baseline entries only with tickets and expiry.

  **VoiceOver:** the total is read with its currency; errors are announced when they appear (a notification as in Module 27) and focus moves to them; the time picker is adjustable or a list, not a grid of unlabeled cells; "Place order" is reachable without scrolling past every summary line (group the summary into one element).

  **Voice Control:** "Show names" over the screen; every button's label contains its visible text ("Place order," "Apply"); the promo field can be dictated into by name.

  **Switch Control:** reaching "Place order" takes a reasonable number of steps; the payment list's per-row buttons are custom actions rather than separate stops.

  **Settings:** at the largest text size, the summary reflows instead of truncating prices; the error isn't shown only in red (icon and text); Reduce Motion removes the confetti after ordering.
````

## Summary

- Start with Apple's plan: main tasks per screen, and a testing matrix of devices, accessibility settings and assistive technologies. Track coverage per screen as passed, failing (with a ticket) or not tested.
- Accessibility Inspector's audits on iOS check element descriptions, hit regions, contrast, element detection, clipped text, traits and Dynamic Type, with explanations, fix suggestions and an HTML export. Passing them doesn't make an app accessible.
- `performAccessibilityAudit(for:_:)` (iOS 17) runs the same audits in UI tests and fails on any issue. Audit each main screen and state, and accept known issues only through a reviewed baseline with tickets and expiry dates that only shrinks.
- The common fixes: labels for icon-only controls, text styles with `adjustsFontForContentSizeCategory` and no fixed heights, 44-point hit regions via `contentShape` or `point(inside:with:)`, state in traits, and labels that contain the visible text plus input labels for Voice Control.
- Test main tasks on a device with VoiceOver (Screen Curtain on), Voice Control ("Show names," "Tap …") and Switch Control, and repeat them with each display and motion setting.
