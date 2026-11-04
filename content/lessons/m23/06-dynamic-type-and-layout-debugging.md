---
id: m23-l06
title: Dynamic Type and debugging layout
description: A layout isn't done until it works at the text size the user chose. You learn text styles, preferredFont(forTextStyle:), adjustsFontForContentSizeCategory and UIFontMetrics for custom fonts and non-text sizes, how to switch a row to a column at accessibility sizes, and then how to debug the layouts that break, by reading the unsatisfiable-constraints log, naming constraints, finding ambiguity with hasAmbiguousLayout, and using Xcode's view debugger.
module: m23
order: 6
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m23-l05]
objectives:
  - Use text styles with preferredFont(forTextStyle:) and adjustsFontForContentSizeCategory so text follows the user's setting while the app runs.
  - Scale custom fonts and non-text dimensions with UIFontMetrics.
  - Change a layout at accessibility text sizes with the preferred content size category trait.
  - Read an unsatisfiable-constraints log, find the contradiction and decide which constraint to change.
  - Find ambiguous views with hasAmbiguousLayout and constraintsAffectingLayout(for:), and know what the view debugger shows.
terms:
  - term: Dynamic Type
    definition: "The system feature that lets people choose the size of text. Apps support it by using text styles and letting their layouts grow."
  - term: Text style
    definition: "A UIFont.TextStyle such as .body, .headline or .largeTitle: a semantic role for text whose size the system adjusts for each content size category."
  - term: Content size category
    definition: "The user's chosen text size, a UIContentSizeCategory from extraSmall to extraExtraExtraLarge, plus five larger accessibility categories. The default is large."
  - term: UIFontMetrics
    definition: "A UIKit object that scales a custom font, or any number, the way a given text style scales, for the current content size category."
  - term: Symbolic breakpoint UIViewAlertForUnsatisfiableConstraints
    definition: "A breakpoint on the function UIKit calls when it has to break a constraint, so the debugger stops at the moment of the conflict."
mastery:
  - Configure a label so it follows Dynamic Type while the app runs and wraps instead of truncating.
  - Scale a custom font and an icon size with UIFontMetrics.
  - Switch a stack view's axis when the content size category is an accessibility size.
  - Identify, in a constraint log, your constraints, the system's and the autoresizing-mask ones, and the constraint that was broken.
  - Name constraints with identifier so logs are readable.
resources: [apple-documentation, hig]
cards:
  - id: m23-l06-c1
    front: What two lines make a label follow Dynamic Type while the app is running?
    back: "label.font = UIFont.preferredFont(forTextStyle: .body) and label.adjustsFontForContentSizeCategory = true. Add numberOfLines = 0 so larger text wraps instead of truncating."
  - id: m23-l06-c2
    front: How do you make a custom font scale with Dynamic Type?
    back: "UIFontMetrics(forTextStyle: .body).scaledFont(for: customFont), where customFont is sized for the default (large) category. Don't pass an already scaled font: Apple says that throws an exception."
  - id: m23-l06-c3
    front: How do you tell if the user picked an accessibility text size?
    back: "traitCollection.preferredContentSizeCategory.isAccessibilityCategory. It's true for accessibilityMedium through accessibilityExtraExtraExtraLarge."
  - id: m23-l06-c4
    front: Which constraints in an unsatisfiable-layout log do you not own?
    back: "NSAutoresizingMaskLayoutConstraint entries (a view with translatesAutoresizingMaskIntoConstraints still true) and UIView-Encapsulated-Layout-Width/Height, which the system sets for views like a controller's root view. Fix the conflict on your side."
  - id: m23-l06-c5
    front: Why is an ambiguous layout harder to find than an unsatisfiable one?
    back: "Apple's guide: Auto Layout silently picks one solution; there are no console warnings and no breakpoint. Look for misplaced or jumping views and check hasAmbiguousLayout in the debugger."
---

## The idea in one sentence

Text size is the user's choice, not yours, so every label should use a text style and every layout should have room to grow, and when a layout does break, the console log and the view debugger tell you exactly which constraints disagree, if you know how to read them.

> [!note] About this lesson's code
> The Dynamic Type APIs come from Apple's `UIFont`, `UIFontMetrics`, `UIContentSizeCategory` and trait pages and the article "Scaling fonts automatically"; the debugging methods from the `UIView` reference and the archived *Auto Layout Guide*; the view debugger from Xcode's documentation ("Diagnosing issues in the appearance of a running app"). All were read in November 2026. Xcode's menus and buttons were **not** checked in Xcode for this lesson. UIKit blocks are type-checked against the iOS 17 SDK on the CI runner, not run. The log sample is Apple's, from the guide; the console text you'll see in Xcode 27 may differ. The plain-Swift models were compiled and run with Swift 6.3.

## Dynamic Type

In Settings, people choose a text size. UIKit calls it the **content size category**. There are seven standard categories, from `extraSmall` to `extraExtraExtraLarge`, with `large` as the default, and five accessibility categories above them, from `accessibilityMedium` to `accessibilityExtraExtraExtraLarge`. Your code reads it from the trait collection, `traitCollection.preferredContentSizeCategory`.

You don't map categories to point sizes yourself. You say what a piece of text **is**, with a **text style** (`.largeTitle`, `.title1`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.body`, `.callout`, `.footnote`, `.caption1`, `.caption2`), and the system picks the size:

```swift ios
import UIKit

let title = UILabel()
title.font = UIFont.preferredFont(forTextStyle: .headline)
title.adjustsFontForContentSizeCategory = true
title.numberOfLines = 0

let detail = UILabel()
detail.font = .preferredFont(forTextStyle: .subheadline)
detail.adjustsFontForContentSizeCategory = true
detail.numberOfLines = 0
detail.textColor = .secondaryLabel
```

- `preferredFont(forTextStyle:)` returns "an instance of the system font for the specified text style with scaling for the user's selected content size category."
- `adjustsFontForContentSizeCategory = true` makes the label update when the setting changes while the app runs. Without it, Apple says, "the font will initially be the right size, but it won't respond to text-size changes the user makes in Settings or Control Center." Fonts are immutable, so the label replaces its font with a new one rather than changing it. This only works if the font came from `preferredFont(forTextStyle:)` or `UIFontMetrics`.
- `numberOfLines = 0` lets the label wrap. The default is 1, which truncates as soon as the text gets bigger.

Text fields and text views adopt the same `adjustsFontForContentSizeCategory` property (it belongs to the `UIContentSizeCategoryAdjusting` protocol).

### Layouts that can grow

A scaled font is only half the job. At the largest accessibility size, body text is several times larger than at the default, and the layout has to make room:

- **No fixed heights on text.** Let labels use their intrinsic height. If a container needs a minimum, use `≥`.
- **Wrap, don't truncate.** `numberOfLines = 0`, and give labels a width to wrap at (lesson 3).
- **Scroll.** A screen that fits at the default size won't fit at the largest. Put it in a scroll view (lesson 5).
- **Space relative to text.** `constraint(equalToSystemSpacingBelow:multiplier:)` on y-axis anchors spaces by system spacing; Apple: "if the anchors represent text baselines, the spacing is determined by the fonts used at those baselines", so the gap grows with the text.
- **Rearrange at accessibility sizes.** A label and a value side by side stop fitting; stack them instead (below).

### Custom fonts and other sizes

A brand font doesn't know about text styles. `UIFontMetrics` scales it the way a text style would:

```swift ios
import UIKit

let brand = UIFont(name: "AvenirNext-DemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)

let price = UILabel()
price.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: brand)
price.adjustsFontForContentSizeCategory = true

let badge = UILabel()
badge.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: brand, maximumPointSize: 28)
badge.adjustsFontForContentSizeCategory = true

// Non-text sizes that should grow with the text, such as an icon next to it.
let iconSide = UIFontMetrics(forTextStyle: .body).scaledValue(for: 24)
```

- Size the base font for the **default** category. Apple: pass the custom font "at a point size suitable for use with `large`", and "Do not specify a font that has already been scaled; doing so results in an exception." That rules out passing a `preferredFont(forTextStyle:)` result.
- `scaledFont(for:maximumPointSize:)` caps the size "when your interface cannot accommodate text that is any larger." Use it sparingly, for text that can't wrap, like a badge; capping body text defeats the point.
- `scaledValue(for:)` "scales an arbitrary layout value based on the current Dynamic Type settings", for icons, button heights or padding that should keep their proportion to the text.
- `UIFont(name:size:)` returns an optional: a misspelled name or a font missing from the bundle gives `nil`, hence the fallback.

The HIG's typography page explains when a custom font is worth it; Apple's article adds that the system font "is designed to look good at any size".

## Changing the layout at accessibility sizes

The common adaptation: rows that put a label and a value side by side become columns when the user picks an accessibility size. `UIContentSizeCategory.isAccessibilityCategory` "is `true` for `accessibilityMedium`, `accessibilityLarge`, `accessibilityExtraLarge`, `accessibilityExtraExtraLarge`, and `accessibilityExtraExtraExtraLarge`." The categories are also `Comparable`, so `category >= .extraExtraLarge` works when you want to switch earlier.

To react when it changes, register for the trait. iOS 17 introduced `registerForTraitChanges(_:handler:)` and deprecated `traitCollectionDidChange(_:)`; this is Apple's pattern, adapted:

```swift ios
import UIKit

final class OrderRowViewController: UIViewController {
    private let row = UIStackView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        nameLabel.text = "Oat milk flat white, extra hot"
        priceLabel.text = "$5.40"
        for label in [nameLabel, priceLabel] {
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            row.addArrangedSubview(label)
        }
        priceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.spacing = 8

        row.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])

        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            self.updateAxis()
        }
    }

    private func updateAxis() {
        let isLarge = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = isLarge ? .vertical : .horizontal
        row.alignment = isLarge ? .leading : .firstBaseline
    }
}
```

- `updateAxis()` runs once at load and again whenever the content size category changes.
- The handler's first parameter is the observed object. Apple's documentation for the handler: naming it `self` with type `Self` means you don't capture `self` from outside, which "avoids strong reference cycles." Registrations live as long as the object and are removed automatically.
- The row's priorities come from lesson 3: horizontally, the name truncates or wraps before the price does.
- A stack view relayouts on its own when `axis` changes, so nothing else needs updating. Wrap the change in an animation block if you want it animated.

From iOS 18, UIKit also tracks traits automatically in methods like `layoutSubviews()` and `viewDidLayoutSubviews()`: read the trait there and UIKit calls the method again when it changes. With the course's iOS 17 deployment target, registration is the approach that works on every supported version.

### A model of the switch

The categories in order, and the rule the controller uses:

```swift
enum SizeCategory: Int, CaseIterable, Comparable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
    case accessibilityMedium, accessibilityLarge, accessibilityExtraLarge
    case accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge

    var isAccessibilityCategory: Bool { self >= .accessibilityMedium }

    static func < (lhs: SizeCategory, rhs: SizeCategory) -> Bool { lhs.rawValue < rhs.rawValue }
}

for category in [SizeCategory.large, .extraExtraExtraLarge, .accessibilityMedium] {
    let axis = category.isAccessibilityCategory ? "vertical" : "horizontal"
    print(category, axis)
}
let standard = SizeCategory.allCases.filter { !$0.isAccessibilityCategory }.count
let accessibility = SizeCategory.allCases.count - standard
print(standard, accessibility)
```

```output
large horizontal
extraExtraExtraLarge horizontal
accessibilityMedium vertical
7 5
```

The real `UIContentSizeCategory` also has an `unspecified` value, left out of the model; the order and the accessibility rule match Apple's lists.

### Testing it

Xcode's documentation describes **Environment Overrides**, a button in the debugging toolbar with a Dynamic Type slider, so you can change the text size of a running app without opening Settings (not checked in Xcode for this lesson). Try every screen at the smallest size, the default, and the largest accessibility size.

## Debugging layout

Lesson 2 named the two failures. Here's how to find them.

### Reading the unsatisfiable-constraints log

When required constraints contradict each other, Auto Layout breaks one and writes the conflict to the console. Apple's guide shows this sample (from 2015; the format in current Xcode may differ in details, and it wasn't reproduced for this lesson):

```plaintext
Unable to simultaneously satisfy constraints.
	Probably at least one of the constraints in the following list is one you don't want. …
(
    "<NSLayoutConstraint:0x7a87b000 H:[UILabel:0x7a8724b0'Name'(>=400)]>",
    "<NSLayoutConstraint:0x7a895e30 UILabel:0x7a8724b0'Name'.leading == UIView:0x7a887ee0.leadingMargin>",
    "<NSLayoutConstraint:0x7a886d20 H:[UILabel:0x7a8724b0'Name']-(NSSpace(8))-[UITextField:0x7a88cff0]>",
    "<NSLayoutConstraint:0x7a87b2e0 UITextField:0x7a88cff0.trailing == UIView:0x7a887ee0.trailingMargin>",
    "<NSLayoutConstraint:0x7ac7c430 'UIView-Encapsulated-Layout-Width' H:[UIView:0x7a887ee0(320)]>"
)

Will attempt to recover by breaking constraint
<NSLayoutConstraint:0x7a87b000 H:[UILabel:0x7a8724b0'Name'(>=400)]>

Make a symbolic breakpoint at UIViewAlertForUnsatisfiableConstraints to catch this in the debugger.
```

How to read it:

1. **The list is the conflict**, not every constraint on screen: these five can't all hold. Translate each into a sentence. Label width ≥ 400; label leading = superview's leading margin; 8 points between label and field; field trailing = trailing margin; superview width = 320.
2. **Find the contradiction.** 320 points minus margins can't fit a 400-point label plus a field. The fix is in the first constraint.
3. **Identify what you don't own.** `UIView-Encapsulated-Layout-Width` was "created by the system. You cannot change it." It's the size a container gave this view. `NSAutoresizingMaskLayoutConstraint` entries come from a view whose `translatesAutoresizingMaskIntoConstraints` is still `true`; the guide explains the `h=--&` notation: three characters for left margin, width and right margin, `-` fixed and `&` flexible.
4. **Read which one was broken.** "Will attempt to recover by breaking constraint" names it. It's not necessarily the wrong one; it's the one Auto Layout picked. Your fix might be elsewhere.
5. **Decide**: delete the wrong constraint, or make it optional. The guide's fix here: drop the label width's priority to 999, so "the system still tries to provide the selected width—coming as close as it can while still satisfying the other constraints."

Views are identified by class and address, plus their text when they have some (`UILabel:0x7a8724b0'Name'`). Constraints are written in the Visual Format Language: `H:` and `V:` for the axis, `[view(>=400)]` for a size, `-(8)-` for a space. You don't need to write VFL, but you need to read it.

### Naming constraints

Addresses are hard to match to code. Give important constraints an `identifier`; Apple: "A constraint's identifier is available in its description. Identifiers that start with `NS` are reserved by the system."

```swift ios
import UIKit

let container = UIView()
let nameLabel = UILabel()
nameLabel.translatesAutoresizingMaskIntoConstraints = false
container.addSubview(nameLabel)

let minimumWidth = nameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
minimumWidth.identifier = "nameLabel.minimumWidth"
minimumWidth.priority = UILayoutPriority(999)

let leading = nameLabel.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor)
leading.identifier = "nameLabel.leading"

NSLayoutConstraint.activate([minimumWidth, leading])
```

In the guide's second sample, the same conflict lists `'Label Width'`, `'Label Leading'` and so on in quotes after each address. One identifier per constraint you care about turns the log into something you can search your code for.

### The breakpoint

The log's last line suggests a symbolic breakpoint on `UIViewAlertForUnsatisfiableConstraints`. The guide recommends it "to help ensure that you catch nonobvious errors during testing": the debugger stops at the conflict instead of letting the message scroll past in the console.

### Finding ambiguity

Ambiguous layouts don't log anything. The guide: "there are no warnings written to the console, and there is no way to set a breakpoint for ambiguous layouts." Symptoms are views in the wrong place or views that jump between layout passes. `UIView` has three methods for this, all marked by Apple as debugging-only ("No app should ship with" them):

- `hasAmbiguousLayout`: `true` "if the view's location is incompletely specified". Apple warns that "UIKit does not automatically detect every ambiguous layout."
- `exerciseAmbiguityInLayout()`: "randomly changes the frame of a view with an ambiguous layout between the different valid values", so you can see the possible positions.
- `constraintsAffectingLayout(for:)`: the constraints that affect the view on an axis; "a good starting point", with no guarantee it's complete.

You can call them from the debugger console while paused, or from a temporary helper that walks the tree:

```swift ios
import UIKit

@MainActor
func reportAmbiguity(in view: UIView, depth: Int = 0) {
    let indent = String(repeating: "  ", count: depth)
    if view.hasAmbiguousLayout {
        print("\(indent)ambiguous: \(type(of: view))")
        for constraint in view.constraintsAffectingLayout(for: .horizontal) {
            print("\(indent)  H \(constraint)")
        }
        for constraint in view.constraintsAffectingLayout(for: .vertical) {
            print("\(indent)  V \(constraint)")
        }
    }
    for subview in view.subviews {
        reportAmbiguity(in: subview, depth: depth + 1)
    }
}
```

Call it from `viewDidAppear(_:)` while hunting a bug, and wrap the call in `#if DEBUG` so it can't ship. The guide adds that in the console you may need Objective-C syntax for these calls; that wasn't tried for this lesson.

### The view debugger

Xcode's documentation describes the view debugger this way: set a breakpoint after the view appears, or just click **Debug View Hierarchy** in the debug bar while the app runs. It "displays a 3D rendering of the current view on the canvas", which you can rotate to see layers, with the hierarchy in the Debug navigator. Select a view and the Size inspector shows its constraints; "Click a constraint to highlight it in the view debugger." The archived guide also points to its "Show clipped content" option (views placed off screen) and "Show constraints". These descriptions come from Apple's documentation; the menus weren't checked in Xcode 27 for this lesson.

A workflow that ties it together:

1. Something looks wrong. Check the console for an unsatisfiable-constraints log first.
2. If there's a log, translate the listed constraints into sentences, find the contradiction, fix or lower one. Add identifiers if the list is long.
3. If there's no log, open the view debugger, select the misplaced view and read its constraints. Count them per axis (lesson 2). Check `hasAmbiguousLayout`.
4. Check the usual suspects: `translatesAutoresizingMaskIntoConstraints`, equal hugging or compression priorities (lesson 3), a missing bottom constraint in a scroll view (lesson 5).
5. Re-test at the largest text size, in landscape and with a long translation, where hidden conflicts usually appear.

## Common mistakes

> [!error] Fixed font sizes
> `.systemFont(ofSize: 17)` ignores the user's setting. Use `preferredFont(forTextStyle:)`, or `UIFontMetrics` for custom fonts.

> [!error] Forgetting adjustsFontForContentSizeCategory
> The font is right at launch and wrong after the user changes the size in Control Center.

> [!error] Scaling an already scaled font
> `UIFontMetrics(...).scaledFont(for: .preferredFont(forTextStyle: .body))` passes a scaled font; Apple documents that this raises an exception. Start from an unscaled custom font sized for `large`.

> [!error] Ignoring constraint logs because the screen looks fine
> The broken constraint may change with the next SDK or another device. The guide says to always fix them.

> [!error] Shipping hasAmbiguousLayout or exerciseAmbiguityInLayout()
> Apple: debugging only. Keep them behind `#if DEBUG` or in the debugger.

## Exercises

````exercise
id: m23-l06-e1
type: prediction
prompt: "This version of the lesson's model switches earlier, at `extraExtraLarge` and above, and also picks a maximum number of lines for a caption. What does it print?"
code: |
  enum SizeCategory: Int, Comparable {
      case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge
      case accessibilityMedium, accessibilityLarge, accessibilityExtraLarge
      case accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge

      static func < (lhs: SizeCategory, rhs: SizeCategory) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  func layout(for category: SizeCategory) -> String {
      let axis = category >= .extraExtraLarge ? "column" : "row"
      let lines = category >= .accessibilityMedium ? 0 : 2
      return "\(axis), \(lines) lines"
  }

  for category in [SizeCategory.medium, .extraExtraLarge, .accessibilityLarge] {
      print(category, "→", layout(for: category))
  }
output: |
  medium → row, 2 lines
  extraExtraLarge → column, 2 lines
  accessibilityLarge → column, 0 lines
hints:
  - "Comparison uses the declaration order through rawValue."
  - "print with several arguments separates them with spaces."
solution: |
  ```output
  medium → row, 2 lines
  extraExtraLarge → column, 2 lines
  accessibilityLarge → column, 0 lines
  ```

  `medium` is below `extraExtraLarge`, so it stays a row with a 2-line caption. `extraExtraLarge` is the threshold itself (`>=`), so it becomes a column, but it isn't an accessibility size, so the caption keeps its 2-line limit. `accessibilityLarge` passes both thresholds: column, and `numberOfLines = 0` (no limit). `UIContentSizeCategory` is `Comparable` in UIKit too, so the same `>=` works on the real type.
````

````exercise
id: m23-l06-e2
type: comprehension
prompt: "The marketing team wants the app's headings in a custom font, and they must follow Dynamic Type while the app is running. Which code does that?"
choices:
  - text: "`label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: customFont)` with `customFont` at its default-size point size, plus `label.adjustsFontForContentSizeCategory = true`."
    correct: true
    why: UIFontMetrics produces a font that scales like the headline style, and adjustsFontForContentSizeCategory keeps it updated.
  - text: "`label.font = customFont.withSize(UIFont.preferredFont(forTextStyle: .headline).pointSize)`"
    correct: false
    why: It reads the right size once, at that moment. The label won't update when the setting changes, because the font didn't come from preferredFont or UIFontMetrics.
  - text: "`label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .preferredFont(forTextStyle: .headline))`"
    correct: false
    why: That's the system font, not the custom one, and it's already scaled, which Apple says raises an exception.
  - text: "`label.font = customFont` and `label.adjustsFontForContentSizeCategory = true`."
    correct: false
    why: adjustsFontForContentSizeCategory only works for fonts vended by preferredFont or UIFontMetrics.
solution: |
  **`UIFontMetrics(forTextStyle: .headline).scaledFont(for:)` plus `adjustsFontForContentSizeCategory`.** Apple's documentation for `adjustsFontForContentSizeCategory` lists exactly two kinds of fonts it works with: those from `preferredFont(forTextStyle:)` and those from `UIFontMetrics`' scaling methods. The base custom font should be sized for the default category (`large`), and it must not be a font that's already scaled.
````

````exercise
id: m23-l06-e3
type: fill-in
prompt: "Complete the code. The caption follows Dynamic Type and wraps; the icon next to it scales with body text; the row becomes a column at accessibility sizes."
code: |
  caption.font = UIFont.[[1]](forTextStyle: .footnote)
  caption.[[2]] = true
  caption.numberOfLines = [[3]]

  let iconSide = UIFontMetrics(forTextStyle: .body).[[4]](for: 20)

  let isLarge = traitCollection.preferredContentSizeCategory.[[5]]
  row.axis = isLarge ? .vertical : .horizontal
blanks:
  - id: "1"
    answers: ["preferredFont"]
  - id: "2"
    answers: ["adjustsFontForContentSizeCategory"]
  - id: "3"
    answers: ["0"]
  - id: "4"
    answers: ["scaledValue"]
  - id: "5"
    answers: ["isAccessibilityCategory"]
solution: |
  ```swift ios
  import UIKit

  final class CaptionRowViewController: UIViewController {
      private let caption = UILabel()
      private let icon = UIImageView(image: UIImage(systemName: "leaf"))
      private let row = UIStackView()

      override func viewDidLoad() {
          super.viewDidLoad()
          caption.font = UIFont.preferredFont(forTextStyle: .footnote)
          caption.adjustsFontForContentSizeCategory = true
          caption.numberOfLines = 0

          let iconSide = UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)
          icon.widthAnchor.constraint(equalToConstant: iconSide).isActive = true
          icon.heightAnchor.constraint(equalTo: icon.widthAnchor).isActive = true

          row.addArrangedSubview(icon)
          row.addArrangedSubview(caption)
          row.spacing = 8
          let isLarge = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
          row.axis = isLarge ? .vertical : .horizontal
      }
  }
  ```

  `scaledValue(for:)` turns 20 points at the default size into the equivalent at the current size. The value is computed once here; for a complete screen, recompute it (and the axis) in a trait-change handler as the lesson shows. Constraining an arranged subview's own size is fine; it's position constraints that fight the stack.
````

````exercise
id: m23-l06-e4
type: find-errors
prompt: "This card looks right at the default text size and breaks at larger ones. Mark every real problem."
code: |
  titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
  bodyLabel.font = .preferredFont(forTextStyle: .body)
  bodyLabel.adjustsFontForContentSizeCategory = true
  // bodyLabel.numberOfLines left at its default

  NSLayoutConstraint.activate([
      card.heightAnchor.constraint(equalToConstant: 120),
      titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
      bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
  ])

  let brandFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: bodyLabel.font)
choices:
  - text: "The title uses a fixed-size system font, so it ignores the user's text size."
    correct: true
  - text: "bodyLabel.numberOfLines is 1 by default, so larger text truncates instead of wrapping."
    correct: true
  - text: "The card has a fixed height of 120, so larger text can't fit."
    correct: true
  - text: "scaledFont(for:) receives a font that's already scaled, which Apple says raises an exception."
    correct: true
  - text: "preferredFont(forTextStyle:) needs adjustsFontForContentSizeCategory to return the right size at launch."
    correct: false
    why: "It returns the font for the current setting either way. The property is about updating when the setting changes later."
rubric:
  - I found the fixed font size.
  - I found the single-line label.
  - I found the fixed card height.
  - I found the already-scaled font passed to UIFontMetrics.
solution: |
  1. `.systemFont(ofSize: 20, weight: .bold)` doesn't scale. Use `.preferredFont(forTextStyle: .headline)` (or `.title3`) with `adjustsFontForContentSizeCategory = true`.
  2. `numberOfLines` defaults to 1: at larger sizes the body truncates. Set it to 0.
  3. A fixed height of 120 can't hold large text. Remove it and tie the card's bottom to the body label's bottom (`≥` if you need a minimum).
  4. `bodyLabel.font` came from `preferredFont(forTextStyle:)`, so it's already scaled. Apple: passing a scaled font "results in an exception." Scale an unscaled custom font instead.

  The spacing constant of 4 points stays fixed while the text grows; `constraint(equalToSystemSpacingBelow:multiplier:)` would scale with the fonts. That's a refinement, not a bug.
````

````exercise
id: m23-l06-e5
type: solve
prompt: |
  Write `summarize(_:)` for a constraint log. Given the log's lines (as in Apple's sample), it returns a short report:

  - how many constraints are in the conflict list (lines that contain `<NSLayoutConstraint` or `<NSAutoresizingMaskLayoutConstraint` before the "Will attempt to recover" line),
  - whether any is an autoresizing-mask constraint,
  - whether any is a system `UIView-Encapsulated-Layout` constraint,
  - and the line right after "Will attempt to recover by breaking constraint" (the broken one).

  ```swift
  let log = [
      "Unable to simultaneously satisfy constraints.",
      "(",
      "    \"<NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>\",",
      "    \"<NSAutoresizingMaskLayoutConstraint:0x3 h=--& v=--& H:[UITextField:0x4(0)]>\",",
      "    \"<NSLayoutConstraint:0x5 'UIView-Encapsulated-Layout-Width' H:[UIView:0x6(320)]>\"",
      ")",
      "Will attempt to recover by breaking constraint",
      "<NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>",
      "Make a symbolic breakpoint at UIViewAlertForUnsatisfiableConstraints to catch this in the debugger.",
  ]
  print(summarize(log))
  ```

  should print `3 constraints; autoresizing: true; system size: true; broke <NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>`.
starter: |
  func summarize(_ lines: [String]) -> String {
      // your code
      return ""
  }
hints:
  - "Walk the lines once, with a flag that flips when you reach the 'Will attempt to recover' line."
  - "String has contains(_:) for substrings."
  - "The broken constraint is the first line after the 'recover' line."
rubric:
  - Counts only constraint lines before the recover line.
  - Detects NSAutoresizingMaskLayoutConstraint and UIView-Encapsulated-Layout.
  - Extracts the line after "Will attempt to recover by breaking constraint".
  - Produces the exact format.
solution: |
  ```swift
  func summarize(_ lines: [String]) -> String {
      var count = 0
      var autoresizing = false
      var systemSize = false
      var broken = "?"
      var afterRecover = false
      for line in lines {
          if afterRecover {
              broken = line
              break
          }
          if line.contains("Will attempt to recover by breaking constraint") {
              afterRecover = true
              continue
          }
          if line.contains("<NSLayoutConstraint") || line.contains("<NSAutoresizingMaskLayoutConstraint") {
              count += 1
              if line.contains("NSAutoresizingMaskLayoutConstraint") { autoresizing = true }
              if line.contains("UIView-Encapsulated-Layout") { systemSize = true }
          }
      }
      return "\(count) constraints; autoresizing: \(autoresizing); system size: \(systemSize); broke \(broken)"
  }

  let log = [
      "Unable to simultaneously satisfy constraints.",
      "(",
      "    \"<NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>\",",
      "    \"<NSAutoresizingMaskLayoutConstraint:0x3 h=--& v=--& H:[UITextField:0x4(0)]>\",",
      "    \"<NSLayoutConstraint:0x5 'UIView-Encapsulated-Layout-Width' H:[UIView:0x6(320)]>\"",
      ")",
      "Will attempt to recover by breaking constraint",
      "<NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>",
      "Make a symbolic breakpoint at UIViewAlertForUnsatisfiableConstraints to catch this in the debugger.",
  ]
  print(summarize(log))
  ```

  ```output
  3 constraints; autoresizing: true; system size: true; broke <NSLayoutConstraint:0x1 H:[UILabel:0x2'Name'(>=400)]>
  ```

  The function reads the log the way you should: count what's in the conflict, look for the two kinds of constraints you didn't write, and note which one was broken. Here the autoresizing-mask entry says the text field still has `translatesAutoresizingMaskIntoConstraints = true` and a width of 0 (`H:[UITextField(0)]`), which is probably the real bug; the label width that was broken is just Auto Layout's pick. The log lines are shortened from Apple's sample format, with made-up addresses.
````

````exercise
id: m23-l06-e6
type: explain
prompt: |
  A teammate shows you this log (from Apple's guide, shortened) and says "Auto Layout broke my label's width, so the bug is the width." Explain what the five constraints say, why they conflict, why the broken one isn't necessarily the culprit, and what fix the guide suggests.
code: |
  "<NSLayoutConstraint H:[UILabel'Name'(>=400)]>",
  "<NSLayoutConstraint UILabel'Name'.leading == UIView.leadingMargin>",
  "<NSLayoutConstraint H:[UILabel'Name']-(NSSpace(8))-[UITextField]>",
  "<NSLayoutConstraint UITextField.trailing == UIView.trailingMargin>",
  "<NSLayoutConstraint 'UIView-Encapsulated-Layout-Width' H:[UIView(320)]>"
  Will attempt to recover by breaking constraint
  <NSLayoutConstraint H:[UILabel'Name'(>=400)]>
rubric:
  - Translates each constraint into a sentence.
  - Shows the arithmetic contradiction (a 320-point view can't hold a 400-point label plus margins, gap and field).
  - Explains that the system-provided width can't be changed, and that the broken constraint is Auto Layout's choice, not proof of the bug.
  - Proposes making the width optional (999) or removing it, or another fix that removes the contradiction.
solution: |
  In sentences: the label is at least 400 points wide; it starts at the superview's leading margin; there's a standard 8-point space between it and the text field; the field ends at the trailing margin; and the superview is 320 points wide, a size set by the system (`UIView-Encapsulated-Layout-Width`), which you can't change.

  They conflict because 400 points of label, plus 8 points of space, plus a field, plus two margins can't fit in 320. Any one of the five could be removed to make the rest solvable; Auto Layout picked the label width and logged that choice. That tells you which constraint it dropped, not which one is wrong. Here the width really is the odd one out, because everything else describes a normal form row.

  The guide's fix: keep the constraint but make it optional with priority 999. The system then "tries to provide the selected width—coming as close as it can while still satisfying the other constraints." On a wide iPad the label gets its 400 points; on a phone it gets what's left. Adding an `identifier` to each constraint makes the next log readable without guessing.
````

## Summary

- Use text styles: `preferredFont(forTextStyle:)` plus `adjustsFontForContentSizeCategory = true`, and `numberOfLines = 0`. Layouts need room: no fixed text heights, scroll views, spacing that scales.
- `UIFontMetrics` scales custom fonts (`scaledFont(for:)`, optionally with `maximumPointSize`) and numbers (`scaledValue(for:)`). Start from an unscaled font sized for `large`.
- `preferredContentSizeCategory.isAccessibilityCategory` tells you the user picked one of the five largest sizes; switch rows to columns with `registerForTraitChanges([UITraitPreferredContentSizeCategory.self])` (iOS 17). From iOS 18, traits read in layout methods are tracked automatically.
- An unsatisfiable-constraints log lists the conflicting constraints and the one Auto Layout broke. Translate each into a sentence, spot `NSAutoresizingMaskLayoutConstraint` and `UIView-Encapsulated-Layout-*`, fix or lower the wrong one. Name constraints with `identifier`; break on `UIViewAlertForUnsatisfiableConstraints`.
- Ambiguity is silent. Use `hasAmbiguousLayout`, `exerciseAmbiguityInLayout()` and `constraintsAffectingLayout(for:)` while debugging only, and the view debugger's 3D hierarchy and Size inspector to read a view's constraints.
