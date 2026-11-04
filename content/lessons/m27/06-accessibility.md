---
id: m27-l06
title: Accessibility in UIKit
description: Go beyond labels on single controls. You decide what VoiceOver treats as one element, group a cell into a single readable element, move secondary buttons into custom actions, fix the reading order with accessibilityElements, expose custom-drawn content and an adjustable control, tell VoiceOver when the screen changes, check contrast with the formula the Human Interface Guidelines cite, respond to Reduce Transparency and Increase Contrast, and test it all with Accessibility Inspector.
module: m27
order: 6
level: advanced
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l05]
objectives:
  - Choose label, value, hint and traits for custom elements, building on Module 24's control basics.
  - Group related views into one accessibility element, either by making the container the element or with UIAccessibilityElement.
  - Replace small secondary buttons with UIAccessibilityCustomAction.
  - Control the reading order with accessibilityElements and expose custom-drawn content as elements.
  - Implement an adjustable element with accessibilityIncrement() and accessibilityDecrement().
  - Post layoutChanged, screenChanged and announcement notifications, and mark custom overlays as modal.
  - Check text contrast against the Human Interface Guidelines' minimums and respond to Reduce Transparency and Increase Contrast.
  - Audit a screen with Accessibility Inspector and with VoiceOver on a device.
terms:
  - term: Accessibility element
    definition: "Something VoiceOver can focus on and describe: a view with isAccessibilityElement set to true, or a UIAccessibilityElement that represents part of a view."
  - term: Accessibility container
    definition: "A view that isn't an element itself but provides elements, either its accessible subviews or the array in its accessibilityElements property, in the order VoiceOver should visit them."
  - term: Custom action
    definition: "A UIAccessibilityCustomAction attached to an element. VoiceOver users reach it through the Actions rotor instead of finding a separate small button."
  - term: Adjustable trait
    definition: "UIAccessibilityTraits.adjustable: the element changes value continuously, like a slider. VoiceOver users swipe up or down, which calls accessibilityIncrement() and accessibilityDecrement()."
  - term: Contrast ratio
    definition: "(L1 + 0.05) ÷ (L2 + 0.05), where L1 and L2 are the relative luminances of the lighter and darker colors. It ranges from 1:1 to 21:1; the Human Interface Guidelines ask for at least 4.5:1 for text up to 17 points."
  - term: Accessibility Inspector
    definition: "An Xcode developer tool that shows the accessibility properties of elements in a running app, steps through them in VoiceOver's order, toggles accessibility settings and runs automated audits."
mastery:
  - Turn a cell with five labels and two small buttons into one VoiceOver element with a clear label and two custom actions.
  - Group title and value labels with UIAccessibilityElement and set their frames in container space.
  - Make a custom-drawn chart readable bar by bar.
  - Build a star rating that VoiceOver users adjust by swiping up and down.
  - Compute a contrast ratio and say whether it meets the minimum for a given text size and weight.
  - Plan an accessibility test pass with Accessibility Inspector audits and VoiceOver on a device.
resources: [uikit-supporting-voiceover, accessibility-inspector, uikit-accessibility-traits, hig, uikit-scaling-fonts, uikit-uiview]
cards:
  - id: m27-l06-c1
    front: How do you make VoiceOver read a cell as one element?
    back: "Set isAccessibilityElement = true on the cell (or its container view) and give it an accessibilityLabel that combines the important text, plus a value and traits if needed. Its subviews are then no longer visited separately."
  - id: m27-l06-c2
    front: When do you use UIAccessibilityCustomAction?
    back: "For secondary actions on an element, such as Reply, Archive or Delete on a message cell. VoiceOver users pick them from the Actions rotor instead of hunting for small buttons. Create them with init(name:actionHandler:) and return true if the action succeeded."
  - id: m27-l06-c3
    front: How do you fix VoiceOver's reading order?
    back: "Set the container's accessibilityElements to the elements in the order they should be read, or group related views into one element. VoiceOver otherwise reads from the leading to the trailing edge, which can split a title from its value in multi-column layouts."
  - id: m27-l06-c4
    front: What must an element with the adjustable trait implement?
    back: "accessibilityIncrement() and accessibilityDecrement(). Apple says you must implement them if the element has the adjustable trait. Update accessibilityValue so VoiceOver reads the new value."
  - id: m27-l06-c5
    front: Minimum text contrast in Apple's Human Interface Guidelines?
    back: "From WCAG Level AA: 4.5:1 for text up to 17 points, 3:1 for text of 18 points or more, and 3:1 for bold text of any size. Check both light and dark appearances."
---

## The idea in one sentence

VoiceOver doesn't see your views, it sees a flat, ordered list of **accessibility elements**, and most of the work in an accessible UIKit screen is shaping that list: what counts as one element, what each one says, in what order they come, and what actions they offer.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run, and nothing here was tested with VoiceOver for this lesson. API behavior comes from Apple's reference pages for the `UIAccessibility` informal protocol, `UIAccessibilityElement`, `UIAccessibilityCustomAction`, `UIAccessibilityTraits` and `UIAccessibility`'s notifications and settings; the articles "Supporting VoiceOver in your app", "Performing accessibility testing for your app" and the Accessibility Inspector pages; the sample "Delivering an exceptional accessibility experience"; and the Human Interface Guidelines' Accessibility page, all read in November 2026. Accessibility Inspector's menus are quoted from Apple's documentation, not checked in Xcode. The contrast formula and the ordering model are plain Swift, compiled and run with Swift 6.3.

## What you already have

Module 24 configured single controls: an icon-only button needs an `accessibilityLabel` ("Delete", not "Delete button"), a slider needs a value with units, decorative images get `isAccessibilityElement = false`, and headers get the `.header` trait. Dynamic Type was Module 23. Standard UIKit views do the rest by default: Apple's `UIAccessibility` page says "Standard UIKit controls and views implement the UIAccessibility methods and are accessible to assistive apps by default."

Problems start with **composition**: a cell with five labels and three buttons reads as eight stops; a two-column layout reads in the wrong order; a chart drawn in `draw(_:)` (lesson 4) is invisible. Apple's VoiceOver guide lists the things to look for: elements VoiceOver can't reach, elements read out of order, and state that's only visible ("VoiceOver doesn't detect if a confirmation button turns from gray to green").

### Label, value, hint, traits

A reminder of the four properties, because custom elements need all of them right:

| Property | Answers | Example |
| --- | --- | --- |
| `accessibilityLabel` | What is it? | "Volume", "Ana Torres" |
| `accessibilityValue` | What's its current value? | "40 percent", "3 of 5 stars" |
| `accessibilityTraits` | What kind of thing is it, what state is it in? | `.button`, `.adjustable`, `.selected`, `.header` |
| `accessibilityHint` | What happens if I activate it? (optional) | "Opens the conversation" |

VoiceOver speaks the label first and the value after it; traits add words such as "button" or "adjustable". On hints, Apple: "Depending on the context, hints aren't always necessary," and "If you feel like you're saying too much in an accessibility label, consider moving that text into a hint." Treat hints as optional extras: nothing the user needs to know should exist only in a hint.

## One element or many

### Making the container the element

A message row: avatar, name, preview, time, unread dot. Five things on screen, one thing to the user. Make the cell the element and give it one label built from the parts:

```swift ios
import UIKit

final class MessageCell: UICollectionViewListCell {
    var onReply: (() -> Void)?
    var onArchive: (() -> Void)?
    var onFlag: (() -> Void)?

    func configure(sender: String, preview: String, minutesAgo: Int, isUnread: Bool, isFlagged: Bool) {
        var content = defaultContentConfiguration()
        content.text = sender
        content.secondaryText = preview
        contentConfiguration = content

        isAccessibilityElement = true
        var parts: [String] = []
        if isUnread { parts.append("Unread") }
        parts.append(sender)
        parts.append(preview)
        parts.append(minutesAgo == 1 ? "1 minute ago" : "\(minutesAgo) minutes ago")
        accessibilityLabel = parts.joined(separator: ", ")
        accessibilityTraits = isFlagged ? [.button, .selected] : .button

        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Reply") { [weak self] _ in
                self?.onReply?()
                return true
            },
            UIAccessibilityCustomAction(name: "Archive") { [weak self] _ in
                self?.onArchive?()
                return true
            },
            UIAccessibilityCustomAction(name: isFlagged ? "Unflag" : "Flag") { [weak self] _ in
                self?.onFlag?()
                return true
            },
        ]
    }
}
```

- **`isAccessibilityElement = true` on the cell** makes it one stop. Its labels stop being separate elements.
- **The label puts the most important information first** and separates parts with commas, the way Apple's own examples join a title and a value. "Unread" comes first because it changes what the user does next. The time is written for listening ("1 minute ago"), not copied from a compact visual "1m".
- **Every part is set for every configuration**, including the traits and actions. Module 24's reuse rule applies to accessibility properties too: a reused cell would otherwise keep "Unread" or "Unflag" from its previous row.
- Strings here are in English for clarity. In an app they're localized like any other text (lesson 7).

### Custom actions

The row also has swipe actions and maybe small buttons. Reaching a small button with VoiceOver means swiping through every element to find it, on every row. **Custom actions** attach those operations to the element itself. Apple: "Assistive technologies, such as VoiceOver, display your custom actions to the user at appropriate times." With VoiceOver, the user focuses the row and picks "Reply", "Archive" or "Flag" from the actions VoiceOver offers for it.

`UIAccessibilityCustomAction(name:actionHandler:)` is iOS 13 (iOS 14 added a variant with an image). The handler returns a `Bool`: whether the action succeeded. Apple's dog-adoption sample uses custom actions for the same reason, for two buttons next to a shelter's name: "With the custom action, VoiceOver users can access the action using the VoiceOver rotor."

### Grouping some views, not all

Sometimes a container has several things that belong in **pairs**. A profile card with title and value labels ("Name" / "Ana Torres", "Email" / "ana@example.com") should read as two elements, "Name, Ana Torres" and "Email, ana@example.com", not four. `UIAccessibilityElement` represents a piece of a view that isn't a view of its own:

```swift ios
import UIKit

final class ProfileCardView: UIView {
    private let nameTitle = UILabel()
    private let nameValue = UILabel()
    private let emailTitle = UILabel()
    private let emailValue = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        nameTitle.text = "Name"
        emailTitle.text = "Email"
        [nameTitle, nameValue, emailTitle, emailValue].forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    func configure(name: String, email: String) {
        nameValue.text = name
        emailValue.text = email
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let half = bounds.width / 2
        nameTitle.frame = CGRect(x: 16, y: 8, width: half - 24, height: 20)
        nameValue.frame = CGRect(x: 16, y: 30, width: half - 24, height: 22)
        emailTitle.frame = CGRect(x: half + 8, y: 8, width: half - 24, height: 20)
        emailValue.frame = CGRect(x: half + 8, y: 30, width: half - 24, height: 22)

        accessibilityElements = [
            group(nameTitle, nameValue),
            group(emailTitle, emailValue),
        ]
    }

    private func group(_ title: UILabel, _ value: UILabel) -> UIAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: self)
        element.accessibilityLabel = "\(title.text ?? ""), \(value.text ?? "")"
        element.accessibilityFrameInContainerSpace = title.frame.union(value.frame)
        return element
    }
}
```

This is the pattern from Apple's VoiceOver article and sample:

- **`UIAccessibilityElement(accessibilityContainer: self)`** creates an element that belongs to this view. Apple: "a view that contains nonview items ... should ... create an accessibility element to represent each item that should be exposed to an assistive application."
- **`accessibilityFrameInContainerSpace`** says where it is, in the container's coordinates, so VoiceOver draws its focus rectangle around both labels and hit-tests touches on them. Its default is `CGRectNull`. It's set in `layoutSubviews()` because the frames are only known after layout.
- **`accessibilityElements`** lists what the container exposes, **in order**. Since it's set, the four labels aren't visited on their own.

## Reading order

Apple's VoiceOver article: "VoiceOver reads from the leading to the trailing edge." For a two-column layout like the profile card without grouping, that splits each title from its value. A simplified model of that ordering, rows top to bottom and leading to trailing within a row (the real algorithm isn't documented in this detail):

```swift
struct Element {
    let label: String
    let x: Int
    let y: Int
}

func readingOrder(_ elements: [Element], rightToLeft: Bool = false) -> [String] {
    elements.sorted { a, b in
        if a.y != b.y { return a.y < b.y }
        return rightToLeft ? a.x > b.x : a.x < b.x
    }.map(\.label)
}

let card = [
    Element(label: "Name", x: 16, y: 10),
    Element(label: "Ana Torres", x: 16, y: 34),
    Element(label: "Email", x: 200, y: 10),
    Element(label: "ana@example.com", x: 200, y: 34),
]
print(readingOrder(card).joined(separator: " | "))
print(readingOrder(card, rightToLeft: true).joined(separator: " | "))

let grouped = [
    Element(label: "Name, Ana Torres", x: 16, y: 10),
    Element(label: "Email, ana@example.com", x: 200, y: 10),
]
print(readingOrder(grouped).joined(separator: " | "))
```

```output
Name | Email | Ana Torres | ana@example.com
Email | Name | ana@example.com | Ana Torres
Name, Ana Torres | Email, ana@example.com
```

Ungrouped, VoiceOver users hear "Name", "Email", and then two values they have to match up from memory. In a right-to-left language (lesson 7) the leading edge is on the right, so the order changes again. Grouping fixes both: each element carries its own title.

When grouping isn't the answer, for example a product page whose visual layout puts the price above the title, set the order explicitly:

```swift ios
import UIKit

final class ProductHeaderView: UIView {
    let priceLabel = UILabel()
    let titleLabel = UILabel()
    let buyButton = UIButton(configuration: .filled())
    let ratingLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        [priceLabel, titleLabel, buyButton, ratingLabel].forEach { addSubview($0) }
        titleLabel.accessibilityTraits.insert(.header)
        accessibilityElements = [titleLabel, priceLabel, ratingLabel, buyButton]
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }
}
```

The array decides the order: title, price, rating, then the action. Anything left out of the array isn't reachable with VoiceOver, so when you add a subview later, add it here too.

## Custom-drawn content

Lesson 4's bar chart draws everything in `draw(_:)`, so VoiceOver finds one opaque view, or nothing. Apple's `accessibilityElements` page uses exactly this case: "a pie chart that renders using Core Graphics can expose each slice of its chart as a separate accessibility element." One element per bar:

```swift ios
import UIKit

final class BarChartView: UIView {
    var bars: [(month: String, value: Int)] = [] {
        didSet {
            setNeedsDisplay()
            setNeedsLayout()
        }
    }

    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.setFill()
        for frame in barFrames() {
            UIBezierPath(rect: frame).fill()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        accessibilityElements = zip(bars, barFrames()).map { bar, frame in
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = bar.month
            element.accessibilityValue = "\(bar.value) orders"
            element.accessibilityFrameInContainerSpace = frame
            return element
        }
    }

    private func barFrames() -> [CGRect] {
        guard let maximum = bars.map({ $0.value }).max(), maximum > 0 else { return [] }
        let width = bounds.width / CGFloat(bars.count)
        return bars.enumerated().map { index, bar in
            let height = bounds.height * CGFloat(bar.value) / CGFloat(maximum)
            return CGRect(x: CGFloat(index) * width + 4, y: bounds.height - height, width: width - 8, height: height)
        }
    }
}
```

Drawing and accessibility use the **same** `barFrames()`, so the focus rectangle VoiceOver draws always matches the bar on screen. Swiping right moves from month to month and VoiceOver reads "March, 42 orders".

## Adjustable controls

A star rating built from image views is five images to VoiceOver. It's one control with a value. The **adjustable** trait makes it one element that VoiceOver users change by swiping up and down. Apple: "If you specify this trait on an accessibility element, you must also implement the accessibilityIncrement() and accessibilityDecrement() methods":

```swift ios
import UIKit

final class RatingView: UIView {
    private let stars = (0..<5).map { _ in UIImageView(image: UIImage(systemName: "star")) }
    var onChange: ((Int) -> Void)?

    var rating = 0 {
        didSet {
            for (index, star) in stars.enumerated() {
                star.image = UIImage(systemName: index < rating ? "star.fill" : "star")
            }
            accessibilityValue = rating == 1 ? "1 star" : "\(rating) stars"
            onChange?(rating)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: stars)
        stack.frame = bounds
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        stack.distribution = .fillEqually
        addSubview(stack)

        isAccessibilityElement = true
        accessibilityLabel = "Rating"
        accessibilityTraits = .adjustable
        accessibilityValue = "0 stars"
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func accessibilityIncrement() {
        rating = min(rating + 1, stars.count)
    }

    override func accessibilityDecrement() {
        rating = max(rating - 1, 0)
    }
}
```

VoiceOver describes it as a rating with a value of "3 stars" that can be adjusted, and after a swipe up it reads the new value, "4 stars". The value text comes from the same state as the images, so they can't disagree. Apple's dog-adoption sample uses the same trait for a carousel: "The adjustable trait tells VoiceOver that the element behaves like a picker by responding to the accessibilityIncrement() and accessibilityDecrement() callback methods."

## Telling VoiceOver what changed

VoiceOver doesn't notice on its own when part of the screen changes. `UIAccessibility.post(notification:argument:)` tells it; Apple: "Your application might need to post accessibility notifications if you have user interface components that change very frequently or that appear and disappear."

| Notification | When | Argument |
| --- | --- | --- |
| `.layoutChanged` | Part of the screen changed: results loaded, an error appeared | Optionally the element VoiceOver should move to |
| `.screenChanged` | "a new view appears that occupies a major portion of the screen" | Optionally the element to focus |
| `.announcement` | Something to say that doesn't change the UI, or changes it only briefly | The string to speak |

```swift ios
import UIKit

final class SearchViewController: UIViewController {
    private let resultsHeader = UILabel()
    private let errorBanner = UILabel()

    func showResults(count: Int) {
        resultsHeader.text = count == 1 ? "1 result" : "\(count) results"
        UIAccessibility.post(notification: .layoutChanged, argument: resultsHeader)
    }

    func showError(_ message: String) {
        errorBanner.text = message
        errorBanner.isHidden = false
        UIAccessibility.post(notification: .layoutChanged, argument: errorBanner)
    }

    func messageSent() {
        UIAccessibility.post(notification: .announcement, argument: "Message sent")
    }
}
```

### Custom overlays

A popup that's a plain view on top of the screen, not a presented view controller, leaves everything behind it reachable. Apple's sample describes the problem: "Because of the transparent background, parts of the underlying view are still available to VoiceOver". The fix is `accessibilityViewIsModal`, and `accessibilityPerformEscape()` for VoiceOver's dismiss gesture:

```swift ios
import UIKit

final class TipOverlayView: UIView {
    var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityViewIsModal = true
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func accessibilityPerformEscape() -> Bool {
        onDismiss?()
        return true
    }
}
```

When the overlay appears, post `.screenChanged` so VoiceOver moves into it. `accessibilityPerformEscape()` "Dismisses a modal view and returns the success or failure of the action"; Apple: "When a VoiceOver user performs a dismiss action, this method dismisses the view." Without it, a VoiceOver user may have no way out of a custom overlay that lacks a visible close button.

## Color, contrast and transparency

### Contrast

The Human Interface Guidelines: "Strive to meet color contrast minimum standards." They use values from WCAG Level AA:

| Text size | Text weight | Minimum contrast ratio |
| --- | --- | --- |
| Up to 17 pt | All | 4.5:1 |
| 18 pt | All | 3:1 |
| All | Bold | 3:1 |

The ratio comes from a formula you can compute. Each sRGB component is linearized, the three are weighted into a relative luminance (green counts most, because eyes are most sensitive to it), and the ratio compares the lighter luminance with the darker one, each plus 0.05:

```swift
import Foundation

struct RGB {
    let red: Int
    let green: Int
    let blue: Int

    init(hex: Int) {
        red = (hex >> 16) & 0xFF
        green = (hex >> 8) & 0xFF
        blue = hex & 0xFF
    }

    // WCAG 2 relative luminance of an sRGB color.
    var relativeLuminance: Double {
        func linear(_ component: Int) -> Double {
            let c = Double(component) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let lighter = max(a.relativeLuminance, b.relativeLuminance)
    let darker = min(a.relativeLuminance, b.relativeLuminance)
    return (lighter + 0.05) / (darker + 0.05)
}

func minimumRatio(pointSize: Double, isBold: Bool) -> Double {
    pointSize >= 18 || isBold ? 3 : 4.5
}

func twoDecimals(_ value: Double) -> String {
    let hundredths = Int((value * 100).rounded())
    let fraction = hundredths % 100
    return "\(hundredths / 100)." + (fraction < 10 ? "0" : "") + "\(fraction)"
}

let white = RGB(hex: 0xFFFFFF)
let samples: [(name: String, color: RGB, size: Double, bold: Bool)] = [
    ("black body text", RGB(hex: 0x000000), 17, false),
    ("gray caption", RGB(hex: 0x8E8E93), 13, false),
    ("gray title", RGB(hex: 0x8E8E93), 22, false),
    ("dark gray body", RGB(hex: 0x767676), 17, false),
    ("orange button", RGB(hex: 0xFF9500), 17, true),
]
for sample in samples {
    let ratio = contrastRatio(sample.color, white)
    let required = minimumRatio(pointSize: sample.size, isBold: sample.bold)
    print("\(sample.name): \(twoDecimals(ratio)):1, needs \(twoDecimals(required)):1, \(ratio >= required ? "passes" : "fails")")
}
```

```output
black body text: 21.00:1, needs 4.50:1, passes
gray caption: 3.26:1, needs 4.50:1, fails
gray title: 3.26:1, needs 3.00:1, passes
dark gray body: 4.54:1, needs 4.50:1, passes
orange button: 2.20:1, needs 3.00:1, fails
```

- Black on white is the maximum, 21:1.
- The same medium gray fails as a 13-point caption and passes as a 22-point title: the requirement depends on size and weight, not just color.
- #767676 is the lightest neutral gray that passes 4.5:1 on white: #777777 comes out at 4.48:1.
- White text on a bright orange fill fails even when bold. A light orange button with white text is a common design that doesn't meet the minimum.

The HIG also asks you to check "the minimum contrast in both light and dark appearances", and to "Prefer system-defined colors", because they "have their own accessible variants that automatically adapt when people adjust their color preferences, such as enabling Increase Contrast". Accessibility Inspector has a color contrast calculator for spot checks, and its audit includes a contrast test.

### Increase Contrast and Reduce Transparency

For your own colors, a dynamic color can provide a higher-contrast variant. The trait collection's `accessibilityContrast` reports the setting; `UIAccessibility.isDarkerSystemColorsEnabled` is "A Boolean value that indicates whether the Increase Contrast setting is in an enabled state." Blurs and translucent materials reduce legibility, so Reduce Transparency asks you to replace them with solid backgrounds:

```swift ios
import UIKit

let brandText = UIColor { traits in
    traits.accessibilityContrast == .high
        ? UIColor(red: 0.0, green: 0.25, blue: 0.55, alpha: 1)
        : UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1)
}

final class FrostedHeaderView: UIView {
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    override init(frame: CGRect) {
        super.init(frame: frame)
        blur.frame = bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        updateTransparency()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTransparency),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    @objc private func updateTransparency() {
        let reduce = UIAccessibility.isReduceTransparencyEnabled
        blur.isHidden = reduce
        backgroundColor = reduce ? .systemBackground : .clear
    }
}
```

- **`UIColor { traits in ... }`** is `init(dynamicProvider:)` (iOS 13): the closure is called again whenever the traits change, including the contrast setting, so the label using `brandText` updates without extra code.
- **`isReduceTransparencyEnabled`** plus `reduceTransparencyStatusDidChangeNotification`, which Apple says to observe "using the default notification center", keeps the header correct when the setting changes while the app runs.
- **Don't rely on color alone.** The HIG: "Offer visual indicators, like distinct shapes or icons, in addition to color". The unread dot in the message cell is also announced as "Unread".
- Reduce Motion was lesson 1.

## Testing

Two complementary tools, both from Apple's documentation (not walked through in Xcode for this lesson):

**Accessibility Inspector** ("Xcode > Open Developer Tool > Accessibility Inspector"):

- **Inspection.** Pick the device and app from the target menu, then point at an element to see its label, value, traits and actions. The navigation controls step through elements "in the same order that accessibility features like VoiceOver use", and a speak button reads the current element "similar to how VoiceOver would".
- **Audits.** The Audits pane checks a screen for, among others, missing element descriptions, hit regions too small, insufficient contrast, clipped text at large Dynamic Type sizes, traits without the methods they require, and Dynamic Type support. Each issue has an explanation and a fix suggestion. The same audits run in UI tests with `performAccessibilityAudit(for:_:)` on `XCUIApplication` (Module 33 covers UI testing).
- **Settings.** The Settings pane toggles Increase Contrast, Reduce Transparency, Reduce Motion, Bold Text, Dynamic Type sizes, Differentiate Without Color and others on the target device.

Apple's own warning about audits: "eliminating all audit issues that Accessibility Inspector reports doesn't guarantee a fully accessible app. Always test your app with various assistive apps, such as VoiceOver".

**VoiceOver on a device.** Apple's article lists the gestures to test with: swipe left or right to move between elements, double-tap to activate, two-finger swipe up to read everything, and three-finger triple-tap for Screen Curtain, which blacks out the screen so you can't cheat by looking. For each main task on each screen, check that you can reach every element, that the order makes sense, and that state ("selected", "unread", an error) is spoken, not just shown.

## Common mistakes

> [!error] Every label in a cell as its own element
> A row with five labels takes five swipes and loses its meaning. Make the cell the element with a combined label, or group pairs with `UIAccessibilityElement`.

> [!error] Small buttons with no custom actions
> Reply and Archive buttons inside each row multiply the number of stops. Expose them as custom actions on the row.

> [!error] accessibilityElements that miss a view
> Anything not in the array can't be reached with VoiceOver. Update the array when the view's content changes.

> [!error] Grouped frames computed before layout
> `accessibilityFrameInContainerSpace` set in `init` uses zero frames, so VoiceOver's focus rectangle and touch exploration are wrong. Set it in `layoutSubviews()`.

> [!error] The adjustable trait without increment and decrement
> Apple requires both methods for adjustable elements. Without them, swiping up or down does nothing.

> [!error] State only in color or position
> A green checkmark tint or a filled dot means nothing to VoiceOver. Add `.selected` to the traits or put the state in the label or value.

> [!error] Stale accessibility values on reused cells
> A reused cell keeps "Unread" or "Unflag" from its previous row. Set label, value, traits and actions for every row.

> [!error] Treating a clean audit as done
> Audits catch a few common issues. Test the main tasks with VoiceOver, Screen Curtain on.

## Exercises

````exercise
id: m27-l06-e1
type: prediction
prompt: "Using the lesson's contrast formula, what does this print?"
code: |
  import Foundation

  func linear(_ component: Int) -> Double {
      let c = Double(component) / 255
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
  }

  func luminance(_ hex: Int) -> Double {
      0.2126 * linear((hex >> 16) & 0xFF) + 0.7152 * linear((hex >> 8) & 0xFF) + 0.0722 * linear(hex & 0xFF)
  }

  func ratio(_ a: Int, _ b: Int) -> Double {
      let la = luminance(a), lb = luminance(b)
      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
  }

  let pairs = [(0xFFFFFF, 0x000000), (0x000000, 0xFFFFFF), (0x777777, 0x777777)]
  for (foreground, background) in pairs {
      let value = ratio(foreground, background)
      print(Int((value * 10).rounded()), value >= 4.5)
  }
output: |
  210 true
  210 true
  10 false
hints:
  - "Pure white has luminance 1 and pure black 0."
  - "The formula always divides the lighter by the darker, so order doesn't matter."
  - "What's the ratio of a color with itself?"
solution: |
  ```output
  210 true
  210 true
  10 false
  ```

  White on black and black on white are both (1 + 0.05) ÷ (0 + 0.05) = 21, printed as 210 because the code multiplies by 10 before rounding. The formula takes the lighter and darker luminance, so swapping foreground and background gives the same ratio. A color against itself is always 1:1, the minimum; text in the same gray as its background is invisible, and the formula says so.
````

````exercise
id: m27-l06-e2
type: solve
prompt: |
  Write the model behind an adjustable volume control. `AdjustableLevel` holds a level from `0` to `maximum` that moves by `step`, clamped at both ends. `increment()` and `decrement()` change it; `accessibilityValue` returns what VoiceOver should read: `"muted"` at 0, `"maximum"` at the top, and otherwise the level as a percentage of the maximum, rounded to a whole number, followed by `" percent"`.

  ```swift
  var volume = AdjustableLevel(level: 0, maximum: 12, step: 4)
  print(volume.accessibilityValue)
  volume.increment()
  print(volume.accessibilityValue)
  volume.increment()
  volume.increment()
  volume.increment()
  print(volume.accessibilityValue)
  volume.decrement()
  print(volume.level, volume.accessibilityValue)
  ```

  should print:

  ```plaintext
  muted
  33 percent
  maximum
  8 67 percent
  ```
starter: |
  struct AdjustableLevel {
      private(set) var level: Int
      let maximum: Int
      let step: Int

      mutating func increment() {
          // your code
      }

      mutating func decrement() {
          // your code
      }

      var accessibilityValue: String {
          // your code
          ""
      }
  }
hints:
  - "min(level + step, maximum) and max(level - step, 0) do the clamping."
  - "Compute the percentage as a Double and round it."
rubric:
  - Increment and decrement move by step and clamp at 0 and maximum.
  - The value reads muted at 0 and maximum at the top.
  - Percentages are rounded to whole numbers.
  - The output matches exactly.
solution: |
  ```swift
  struct AdjustableLevel {
      private(set) var level: Int
      let maximum: Int
      let step: Int

      mutating func increment() {
          level = min(level + step, maximum)
      }

      mutating func decrement() {
          level = max(level - step, 0)
      }

      var accessibilityValue: String {
          if level == 0 { return "muted" }
          if level == maximum { return "maximum" }
          let percent = Int((Double(level) / Double(maximum) * 100).rounded())
          return "\(percent) percent"
      }
  }

  var volume = AdjustableLevel(level: 0, maximum: 12, step: 4)
  print(volume.accessibilityValue)
  volume.increment()
  print(volume.accessibilityValue)
  volume.increment()
  volume.increment()
  volume.increment()
  print(volume.accessibilityValue)
  volume.decrement()
  print(volume.level, volume.accessibilityValue)
  ```

  ```output
  muted
  33 percent
  maximum
  8 67 percent
  ```

  The fourth increment would go to 16 and is clamped to 12. In a `UIView` with the `.adjustable` trait, `accessibilityIncrement()` and `accessibilityDecrement()` call these methods and then set `accessibilityValue` from the model, so VoiceOver reads the new value after each swipe. Words like "muted" and "maximum" tell the user they've reached an end, which a bare number doesn't.
````

````exercise
id: m27-l06-e3
type: find-errors
prompt: "This order row has a product name label, a price label, a status dot colored green or red, and two small buttons, Track and Cancel. Mark every real accessibility problem."
code: |
  func configure(_ order: Order) {
      nameLabel.text = order.productName
      priceLabel.text = order.formattedPrice
      statusDot.backgroundColor = order.isShipped ? .systemGreen : .systemRed
      trackButton.setImage(UIImage(systemName: "shippingbox"), for: .normal)
      cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
      if order.isShipped {
          isAccessibilityElement = true
          accessibilityLabel = "\(order.productName), \(order.formattedPrice), shipped"
      }
  }
choices:
  - text: "The shipped state is only shown by the dot's color; unshipped orders never say their state."
    correct: true
  - text: "isAccessibilityElement and the label are set only for shipped orders, so a reused cell keeps the previous row's values."
    correct: true
  - text: "When the row is one element, Track and Cancel are unreachable unless they're custom actions."
    correct: true
  - text: "The icon-only buttons have no accessibility labels for when the row isn't grouped."
    correct: true
  - text: "accessibilityLabel can't contain commas."
    correct: false
    why: "Commas are fine and make VoiceOver pause briefly between parts."
  - text: "SF Symbol images can never be read by VoiceOver."
    correct: false
    why: "VoiceOver can't know what an icon means in your app; an icon-only button needs a label that describes its action."
rubric:
  - I found state conveyed only by color.
  - I found the branch-only accessibility configuration.
  - I found the buttons hidden inside a grouped element.
  - I found the unlabeled icon buttons.
solution: |
  Four problems:

  1. **Color-only state.** Unshipped orders are red to sighted users and silent to VoiceOver. Put the state in the label (or value) for every order.
  2. **Configured in one branch.** Shipped rows become one element; unshipped rows keep whatever a reused cell had. Set `isAccessibilityElement`, label and actions for every row.
  3. **Buttons swallowed by the group.** Once the row is the element, its subviews aren't visited. Add custom actions for Track and Cancel.
  4. **Icon-only buttons.** When they're reachable, they need labels such as "Track package" and "Cancel order".

  ```swift ios
  import UIKit

  struct Order {
      let productName: String
      let formattedPrice: String
      let isShipped: Bool
  }

  final class OrderCell: UICollectionViewListCell {
      var onTrack: (() -> Void)?
      var onCancel: (() -> Void)?

      func configure(_ order: Order) {
          var content = defaultContentConfiguration()
          content.text = order.productName
          content.secondaryText = order.formattedPrice
          contentConfiguration = content

          isAccessibilityElement = true
          let status = order.isShipped ? "shipped" : "not shipped yet"
          accessibilityLabel = "\(order.productName), \(order.formattedPrice), \(status)"
          accessibilityCustomActions = [
              UIAccessibilityCustomAction(name: "Track package") { [weak self] _ in
                  self?.onTrack?()
                  return true
              },
              UIAccessibilityCustomAction(name: "Cancel order") { [weak self] _ in
                  self?.onCancel?()
                  return true
              },
          ]
      }
  }
  ```
````

````exercise
id: m27-l06-e4
type: comprehension
prompt: "After a search finishes, new results appear below the search field, but VoiceOver stays silent on the field and the user doesn't know anything happened. What's the best fix?"
choices:
  - text: "Post UIAccessibility.Notification.layoutChanged with the results header as the argument."
    correct: true
    why: "layoutChanged tells VoiceOver part of the screen changed and can move focus to the element you pass."
  - text: "Post .screenChanged with nil."
    correct: false
    why: "screenChanged is for a new view covering a major portion of the screen, and with nil VoiceOver picks where to go."
  - text: "Set accessibilityHint on the search field to \"Results appear below\"."
    correct: false
    why: "Hints are read when the field is focused, not when results arrive, and some users turn hints off."
  - text: "Call becomeFirstResponder() on the results list."
    correct: false
    why: "First responder is about keyboard input, not VoiceOver focus."
solution: |
  **`UIAccessibility.post(notification: .layoutChanged, argument: resultsHeader)`.** Apple: it's posted "when the layout of a screen changes", with an optional parameter "that contains the accessibility element for VoiceOver to move to". Moving focus to a header that says "12 results" both announces the change and puts the user at the start of the results. If the results don't appear (zero results, or the search failed), focus the message that says so instead.
````

````exercise
id: m27-l06-e5
type: design
prompt: "Plan the accessibility of a photo feed card: author avatar and name, a photo, a caption that can be long, like and comment counts, and Like, Comment, Share and More buttons. Say what the elements are, what each says, how actions work, and how you'll test it."
rubric:
  - Groups the header (avatar, name, time) into one element and hides the decorative avatar.
  - Gives the photo a meaningful label (alt text) or treats it as part of the card's label.
  - Puts counts in a value or the label in listening-friendly form.
  - Moves Like, Comment, Share and More into custom actions on the card, with Like's name reflecting state.
  - Decides how long captions are handled (truncated in the label, full text elsewhere).
  - Tests with Accessibility Inspector audits and VoiceOver with Screen Curtain, in both appearances and at large text sizes.
solution: |
  One reasonable plan:

  - **One element per card**, with the card's container as the element: VoiceOver users scroll a feed card by card, as sighted users do.
  - **Label**: "Ana Torres, 2 hours ago, photo: sunset over the harbor, caption: First evening in Lisbon". The avatar is decorative (the name is already there). The photo's description comes from alt text the author provided or, if none, a short generic "photo". Long captions are cut to their first sentence in the label; the full caption is on the detail screen.
  - **Value**: "124 likes, 8 comments", rebuilt from the model on every configuration.
  - **Custom actions**: "Like" or "Unlike" depending on state, "Comment", "Share", "More options". Double-tap (the default activation) opens the post. After Like, the label or value updates, and an `.announcement` isn't needed because the user hears the new action name next time.
  - **Traits**: `.button` for the card since it opens the post; `.selected` isn't needed because the Like state is in the action name and value.
  - **Testing**: Accessibility Inspector inspection to check each card is one element with its actions, and an audit for contrast, hit regions and clipped text at large Dynamic Type sizes; then VoiceOver on a device with Screen Curtain, liking a post and opening comments using only gestures, in light and dark appearance.
````

## Summary

- VoiceOver works on an ordered list of accessibility elements. Shape it: decide what's one element, what it says (label, value, traits, optional hint) and in what order.
- Make a cell or card one element with a combined, listening-friendly label; group pairs with `UIAccessibilityElement` and frames in container space; set everything for every configuration.
- Move secondary buttons into `UIAccessibilityCustomAction`s.
- `accessibilityElements` sets the reading order and exposes custom-drawn content; anything missing from it is unreachable.
- Adjustable elements implement `accessibilityIncrement()` and `accessibilityDecrement()` and keep `accessibilityValue` current.
- Post `.layoutChanged`, `.screenChanged` or `.announcement` when content changes; mark custom overlays with `accessibilityViewIsModal` and support `accessibilityPerformEscape()`.
- Text contrast: at least 4.5:1 up to 17 points, 3:1 from 18 points or bold, in both appearances. Prefer system colors, provide high-contrast variants, replace blur when Reduce Transparency is on, and never use color alone.
- Audit with Accessibility Inspector, then test the main tasks with VoiceOver and Screen Curtain.
