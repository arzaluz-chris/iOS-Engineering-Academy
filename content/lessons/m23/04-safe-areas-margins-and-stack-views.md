---
id: m23-l04
title: Safe areas, layout margins and stack views
description: Three tools that keep content in the right place without counting points. The safe area keeps it clear of bars, the Dynamic Island and the home indicator; layout margins and the readable content guide give it breathing room and a comfortable line length; stack views turn rows and columns into a few properties. You learn what each guide measures, how directionalLayoutMargins and the system minimums interact, and exactly what UIStackView's axis, distribution, alignment and spacing do, including nested stacks.
module: m23
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m23-l03]
objectives:
  - Choose between the view's edges, the safe area, the layout margins and the readable content guide for each element of a screen.
  - Set directionalLayoutMargins and explain the root view's system minimum margins.
  - Extend a child's safe area with additionalSafeAreaInsets.
  - Predict a stack view's fitting size and how each distribution and alignment places its arranged views.
  - Build a form from nested stack views and show or hide rows by toggling isHidden.
terms:
  - term: Safe area
    definition: "The part of a view not covered by bars, the status bar, hardware features like the Dynamic Island, or the home indicator. Read it as safeAreaLayoutGuide (for constraints) or safeAreaInsets (raw values)."
  - term: Layout margins
    definition: "Insets inside a view's bounds that give content breathing room. Set them with directionalLayoutMargins (leading/trailing aware) and constrain to layoutMarginsGuide."
  - term: Readable content guide
    definition: "A layout guide inside the margins whose width never exceeds a comfortable line length for the current text size. Use it for single columns of text."
  - term: Arranged subviews
    definition: "The views a UIStackView lays out, in the order of its arrangedSubviews array. Always a subset of its subviews."
  - term: Distribution
    definition: "How a stack view sizes and spaces its arranged views along its axis: fill, fillEqually, fillProportionally, equalSpacing or equalCentering."
  - term: Alignment
    definition: "How a stack view places its arranged views across its axis: fill, leading/top, center, trailing/bottom, or a baseline."
mastery:
  - Pin a background to the view's edges and its content to the safe area, and explain the difference on screen.
  - Inset a card's content with directionalLayoutMargins and its layoutMarginsGuide.
  - Compute a stack view's fitting size from its arranged views, spacing and margins.
  - Pick the distribution and alignment for a toolbar, a form column and a row of equal buttons.
  - Hide and show a row in a stack view without touching any constraint.
resources: [uikit-safe-area, uikit-layout-margins, uikit-uistackview, hig]
cards:
  - id: m23-l04-c1
    front: Safe area vs layout margins?
    back: "Safe area: what isn't covered by bars, the status bar, hardware features like the Dynamic Island, or the home indicator. Layout margins: breathing room inside a view; by default they're kept inside the safe area (insetsLayoutMarginsFromSafeArea)."
  - id: m23-l04-c2
    front: Why use directionalLayoutMargins instead of layoutMargins?
    back: "It uses leading and trailing, which UIKit maps to left or right based on the layout direction, so right-to-left languages get mirrored margins for free."
  - id: m23-l04-c3
    front: What is a stack view's fitting size if you only pin its position?
    back: "Along its axis: the sum of the arranged views' sizes plus the spacing between them. Across: the size of the largest arranged view. Plus its layout margins if isLayoutMarginsRelativeArrangement is true."
  - id: m23-l04-c4
    front: Difference between removeArrangedSubview(_:) and removeFromSuperview()?
    back: "removeArrangedSubview(_:) stops the stack managing the view but leaves it as a subview, still drawn. removeFromSuperview() removes it from both. To hide a row temporarily, set isHidden = true; the stack relayouts."
  - id: m23-l04-c5
    front: Which distribution makes three buttons the same width?
    back: "fillEqually: it resizes all arranged views to the same size along the axis, filling the stack."
---

## The idea in one sentence

Pin backgrounds to the view's edges, interactive content to the **safe area**, padded content to the **layout margins**, long text to the **readable content guide**, and let **stack views** create the constraints between siblings for you.

> [!note] About this lesson's code
> The rules come from Apple's `UIView`, `UIViewController` and `UIStackView` reference pages and the articles "Positioning content relative to the safe area" and "Positioning content within layout margins", read in November 2026. UIKit blocks are type-checked against the iOS 17 SDK on the CI runner, not run. The stack view model is plain Swift, compiled and run with Swift 6.3; it implements the sizing rules Apple states in words, and leaves out the ones Apple doesn't specify.

## Four rectangles inside every view

| Guide | What it measures | Use it for |
| --- | --- | --- |
| The view itself (`leadingAnchor`, `topAnchor`…) | The full bounds | Backgrounds, images that should bleed to the edges, maps |
| `safeAreaLayoutGuide` | What isn't covered by bars and system UI | Anything the user must see or tap |
| `layoutMarginsGuide` | Bounds minus the layout margins (kept inside the safe area by default) | Text and controls that need breathing room from the edges |
| `readableContentGuide` | Inside the margins, no wider than a comfortable line length | Paragraphs of text |

Each nests inside the previous one in the normal case. All four are layout guides: rectangles that take part in Auto Layout but don't draw anything.

## The safe area

`safeAreaLayoutGuide` is "the portion of your view that is unobscured by bars and other content." The details from Apple's reference:

- For a view controller's **root view**, the guide accounts for "the status bar, other visible bars, and any additional insets that you specified using the `additionalSafeAreaInsets` property". The Human Interface Guidelines add the hardware side: respecting the safe area makes sure "system UI and hardware features like the Dynamic Island don't obstruct content and controls." On iPhones without a Home button, the home indicator at the bottom is outside the safe area too.
- For **any other view**, it "reflects only the portion of the view that is covered by other content". A card in the middle of the screen has a safe area equal to its bounds.
- If the view isn't in a hierarchy or isn't on screen yet, the guide's edges equal the view's edges and `safeAreaInsets` are all zero. Read the insets after layout, not in `viewDidLoad()`.

Containers adjust it for their children. Apple: "navigation controllers extend the safe area of their child view controllers to account for the navigation bar." A screen inside a navigation controller can pin to its own safe area and never think about the bar.

The common pattern: color behind the bars, content inside them.

```swift ios
import UIKit

final class ReceiptViewController: UIViewController {
    private let header = UIView()
    private let totalLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        header.backgroundColor = .systemIndigo
        totalLabel.text = "Total: $42.10"
        totalLabel.textColor = .white
        totalLabel.font = .preferredFont(forTextStyle: .title2)

        for subview in [header, totalLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            // The color goes all the way up, behind the status bar.
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 16),

            // The text stays where it can be read.
            totalLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            totalLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            totalLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}
```

The header's height isn't a number: its bottom is 16 points below the label, and the label is 16 points below the safe area. On a device with a tall status area the header grows; on one without, it shrinks. No device check anywhere.

### Extending the safe area

If your own container draws something over a child (a custom player bar, a tool palette), tell the child with `additionalSafeAreaInsets`, "custom insets that you specify to modify the view controller's safe area." Apple's example sets it in the container's `viewDidAppear(_:)` "because the safe area insets for a view aren't accurate until the view is added to a view hierarchy":

```swift ios
import UIKit

final class PlayerContainerViewController: UIViewController {
    private let miniPlayer = UIView()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let content = children.first else { return }
        // The mini player covers the bottom of the child's view.
        content.additionalSafeAreaInsets.bottom = miniPlayer.bounds.height
    }
}
```

The child doesn't know about the mini player. It pins to its safe area, and its last row now ends above the player. `children` is the container's array of child view controllers; Module 25 works with UIKit's own containers, navigation and tab bar controllers.

## Layout margins

Layout margins "provide a visual buffer between a view's content and any content outside of the view's bounds." Every view has them.

Set them with **`directionalLayoutMargins`**, an `NSDirectionalEdgeInsets` with `top`, `leading`, `bottom` and `trailing`. "The system applies leading and trailing margins appropriately to the left or right margins based on the current layout direction." The older `layoutMargins` uses left and right and doesn't mirror.

Constrain to them with **`layoutMarginsGuide`**. UIView has no margin anchors of its own.

```swift ios
import UIKit

let card = UIView()
card.backgroundColor = .secondarySystemBackground
card.layer.cornerRadius = 16
card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

let title = UILabel()
title.text = "Weekly summary"
title.translatesAutoresizingMaskIntoConstraints = false
card.addSubview(title)

let inside = card.layoutMarginsGuide
NSLayoutConstraint.activate([
    title.topAnchor.constraint(equalTo: inside.topAnchor),
    title.leadingAnchor.constraint(equalTo: inside.leadingAnchor),
    title.trailingAnchor.constraint(equalTo: inside.trailingAnchor),
    title.bottomAnchor.constraint(equalTo: inside.bottomAnchor),
])
```

The padding lives in one place. Change it and every constraint to the guide follows.

What changes the margins you actually get:

- **The root view has system minimums.** "When the values in the `directionalLayoutMargins` property are less than the minimum values, UIKit uses the minimum values instead." Read them from the controller's `systemMinimumLayoutMargins`; set `viewRespectsSystemMinimumLayoutMargins = false` to opt out (for an edge-to-edge design that sets its own).
- **Margins stay inside the safe area.** With `insetsLayoutMarginsFromSafeArea` true (the default), "any margins that are outside the safe area are automatically modified to fall within the safe area boundary."
- **Margins can inherit.** With `preservesSuperviewLayoutMargins` true, a subview that sits close to its superview's edge gets margins large enough not to overlap the superview's.

Apple doesn't document the numbers (they vary by device, size class and orientation), which is the point: constrain to the guide and let UIKit decide.

## The readable content guide

On an iPad in landscape, a label pinned to the margins can be 1,000 points wide, and lines that long are hard to read. `readableContentGuide` fixes that. Apple's rules for it:

- It "never extends beyond the view's layout margin guide."
- It's "vertically centered inside the layout margin guide."
- Its width "is equal to or less than the readable width defined for the current dynamic text size."

Pin article text to it and the column is the full width on an iPhone and centered with a comfortable measure on an iPad, and it tracks the text size the user chose.

```swift ios
import UIKit

final class ArticleViewController: UIViewController {
    private let body = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true
        body.text = "Long article text…"
        body.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(body)

        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            body.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: readable.trailingAnchor),
        ])
    }
}
```

## Stack views

Module 22 used a vertical `UIStackView` to build a form. Now the details. A stack view "manages the layout of all the views in its `arrangedSubviews` property", creating the constraints between them. You position the stack; it positions its arranged views.

| Property | Default | What it controls |
| --- | --- | --- |
| `axis` | `.horizontal` | Row (`.horizontal`) or column (`.vertical`) |
| `distribution` | `.fill` | Sizes and gaps **along** the axis |
| `alignment` | `.fill` | Placement **across** the axis |
| `spacing` | `0` | Gap between neighbors (exact or minimum, depending on distribution); negative values overlap |
| `isLayoutMarginsRelativeArrangement` | `false` | Lay out inside the stack's own layout margins instead of its edges |

`setCustomSpacing(_:after:)` changes the gap after one view.

### Distribution, along the axis

| Distribution | Apple's description, condensed |
| --- | --- |
| `.fill` | Resize the arranged views to fill the axis. Too much content: shrink "according to their compression resistance priority". Spare space: stretch "according to their hugging priority". A tie is broken by index in `arrangedSubviews` |
| `.fillEqually` | Resize all views to the same size, filling the axis |
| `.fillProportionally` | Resize views proportionally to their intrinsic size to fill the axis |
| `.equalSpacing` | Keep intrinsic sizes; pad the gaps evenly. Too much content: shrink by compression resistance |
| `.equalCentering` | Equal center-to-center distance, never closer than `spacing` |

`.fill` is lesson 3 applied for you: the field with the lower hugging stretches, the label with the lower compression truncates. One difference: where plain constraints would be ambiguous, a stack view breaks the tie by index, in a way Apple doesn't specify further.

### Alignment, across the axis

`.fill` stretches each view to the stack's full cross size. `.leading` and `.trailing` (vertical stacks) or `.top` and `.bottom` (horizontal stacks; Apple says they're the same values as leading and trailing) align one edge. `.center` centers. `.firstBaseline` and `.lastBaseline` align text baselines in a horizontal stack, which is what you want for a label next to a field. Every alignment except `.fill` uses each view's intrinsic size across the axis.

### How big is the stack?

If you pin only a stack's position, its size comes from its content. Apple:

- "Along the stack view's axis, its fitting size is equal to the sum of the sizes of all the arranged views plus the space between views."
- "Perpendicular to the stack view's axis, its fitting size is equal to the size of the largest arranged view."
- With `isLayoutMarginsRelativeArrangement`, "the stack view's fitting size is increased to include space for the margins."

Pin both edges along the axis instead and the stack has a fixed length; the distribution decides how the views fill it. This model applies the documented rules for fitting size, `.fillEqually` and `.equalSpacing`:

```swift
enum Axis { case horizontal, vertical }

struct Arranged {
    let width: Double
    let height: Double
}

func fittingSize(_ views: [Arranged], axis: Axis, spacing: Double,
                 margins: Double = 0) -> (width: Double, height: Double) {
    let gaps = spacing * Double(max(views.count - 1, 0))
    let along = views.map { axis == .horizontal ? $0.width : $0.height }.reduce(0, +) + gaps
    let across = views.map { axis == .horizontal ? $0.height : $0.width }.max() ?? 0
    let width = (axis == .horizontal ? along : across) + 2 * margins
    let height = (axis == .horizontal ? across : along) + 2 * margins
    return (width, height)
}

func fillEqually(count: Int, length: Double, spacing: Double) -> Double {
    (length - spacing * Double(count - 1)) / Double(count)
}

func equalSpacingGap(sizes: [Double], length: Double, spacing: Double) -> Double {
    let gap = (length - sizes.reduce(0, +)) / Double(sizes.count - 1)
    return max(gap, spacing)
}

// A column: title 30 tall, two fields 34 tall, a button 50 tall; 300 wide at most.
let column = [Arranged(width: 180, height: 30), Arranged(width: 300, height: 34),
              Arranged(width: 300, height: 34), Arranged(width: 120, height: 50)]
print(fittingSize(column, axis: .vertical, spacing: 12))
print(fittingSize(column, axis: .vertical, spacing: 12, margins: 16))

// Three buttons in a 358-point row.
print(fillEqually(count: 3, length: 358, spacing: 8))
print(equalSpacingGap(sizes: [60, 90, 60], length: 358, spacing: 8))
```

```output
(width: 300.0, height: 184.0)
(width: 332.0, height: 216.0)
114.0
74.0
```

- The column is 30 + 34 + 34 + 50 = 148 tall plus three 12-point gaps = 184, and as wide as its widest view, 300.
- With 16 points of margin on each side, 32 more each way. (The model uses one value for all four margins.)
- `.fillEqually`: three buttons share 358 − 16 = 342 points, 114 each.
- `.equalSpacing`: the buttons keep their sizes (210 points total), and the 148 remaining points split into two gaps of 74. If the gaps came out below `spacing`, the stack would keep the minimum and compress views instead; the model only reports the minimum.

`.fillProportionally` and `.equalCentering` aren't modeled: Apple describes them in words without enough detail to compute them exactly.

### Nested stacks: a form

"You can build more complex view hierarchies by nesting stack views inside other stack views." A form is a vertical stack of horizontal rows:

```swift ios
import UIKit

final class ProfileFormViewController: UIViewController {
    private let nameField = UITextField()
    private let emailField = UITextField()
    private let newsletterSwitch = UISwitch()
    private let frequencyRow = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        nameField.placeholder = "Name"
        emailField.placeholder = "Email"
        for field in [nameField, emailField] {
            field.borderStyle = .roundedRect
        }

        let newsletterRow = row("Newsletter", newsletterSwitch)
        configure(frequencyRow, label: "Weekly digest", control: UISwitch())
        frequencyRow.isHidden = true

        newsletterSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIView.animate(withDuration: 0.25) {
                self.frequencyRow.isHidden = !self.newsletterSwitch.isOn
            }
        }, for: .valueChanged)

        let form = UIStackView(arrangedSubviews: [nameField, emailField, newsletterRow, frequencyRow])
        form.axis = .vertical
        form.spacing = 12
        form.setCustomSpacing(24, after: emailField)
        form.isLayoutMarginsRelativeArrangement = true
        form.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)

        form.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(form)
        let margins = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            form.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            form.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
    }

    private func row(_ text: String, _ control: UIView) -> UIStackView {
        let stack = UIStackView()
        configure(stack, label: text, control: control)
        return stack
    }

    private func configure(_ stack: UIStackView, label text: String, control: UIView) {
        let label = UILabel()
        label.text = text
        // The label takes the spare width; the control keeps its size.
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(control)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
    }
}
```

What each piece does:

- The outer stack is a column with `.fill` alignment, so each row spans the form's width. Its only constraints are top, leading and trailing; its height is its fitting size.
- Each row is a horizontal stack with `.fill` distribution and `.center` alignment. The label's hugging is lower than the control's, so the label takes the spare width and the switch keeps its size. Without that, a tie would be broken "based on their index in the `arrangedSubviews` array", and the documentation doesn't say which way; set the priorities and don't depend on it.
- `frequencyRow.isHidden = true` removes it from the layout. Apple: the stack "automatically updates its layout whenever views are added, removed, or inserted into the `arrangedSubviews` array, or whenever one of the arranged subviews's `isHidden` property changes", and you can animate it "by placing these changes inside an animation block." No constraint changes at all.
- The arranged subviews get no `translatesAutoresizingMaskIntoConstraints` change and no constraints of their own: the stacks manage them.
- `isLayoutMarginsRelativeArrangement` with vertical margins adds padding above and below the column without spacer views.

### Removing vs hiding

The stack keeps `arrangedSubviews` a subset of `subviews`, with two asymmetries Apple spells out:

- `addArrangedSubview(_:)` also adds the view as a subview.
- `removeArrangedSubview(_:)` does **not** remove it as a subview: "the view is still displayed as part of the view hierarchy." It's still drawn, just no longer positioned. Call `removeFromSuperview()` to really remove it.

To toggle a row, use `isHidden`. To delete one for good, `removeFromSuperview()`, which also removes it from `arrangedSubviews`.

### Constraints on arranged views

You can add size constraints to arranged views (a fixed button height, an aspect ratio for an image). Apple's warning: "Be careful to avoid introducing conflicts when adding constraints to views inside a stack view. As a general rule, if a view's size defaults back to its intrinsic content size for a given dimension, you can safely add a constraint for that dimension." Position constraints between arranged views fight the stack's own, and so does a width constraint on a view in a `.fillEqually` stack.

## Common mistakes

> [!error] Pinning content to view.topAnchor
> It slides under the status bar and the Dynamic Island. Pin backgrounds to the view's edges and content to `safeAreaLayoutGuide`.

> [!error] Reading safeAreaInsets in viewDidLoad()
> They're zero until the view is in a hierarchy and laid out. Use the guide in constraints, or read the insets in `viewDidLayoutSubviews()` or `viewSafeAreaInsetsDidChange()`.

> [!error] Using layoutMargins with left and right
> Use `directionalLayoutMargins`, so right-to-left languages get mirrored padding.

> [!error] Expecting removeArrangedSubview(_:) to remove the view from the screen
> It stays as a subview and keeps drawing, usually at the top-left of the stack. Use `isHidden` or `removeFromSuperview()`.

> [!error] Constraining arranged subviews to each other
> The stack already does. Give arranged views only size constraints, and only on an axis where they'd otherwise use their intrinsic size.

## Exercises

````exercise
id: m23-l04-e1
type: prediction
prompt: "This applies Apple's fitting-size rules for a stack view whose position is pinned but whose size isn't. What does it print?"
code: |
  func stackSize(heights: [Double], widths: [Double], spacing: Double,
                 vertical: Bool, margin: Double) -> (Double, Double) {
      let along = (vertical ? heights : widths).reduce(0, +) + spacing * Double(heights.count - 1)
      let across = (vertical ? widths : heights).max() ?? 0
      let w = (vertical ? across : along) + 2 * margin
      let h = (vertical ? along : across) + 2 * margin
      return (w, h)
  }

  let widths = [40.0, 120.0, 40.0]
  let heights = [40.0, 22.0, 40.0]
  print(stackSize(heights: heights, widths: widths, spacing: 8, vertical: false, margin: 0))
  print(stackSize(heights: heights, widths: widths, spacing: 8, vertical: true, margin: 0))
  print(stackSize(heights: heights, widths: widths, spacing: 8, vertical: false, margin: 10))
output: |
  (216.0, 40.0)
  (120.0, 118.0)
  (236.0, 60.0)
hints:
  - "Horizontal: widths add up, plus two gaps; the height is the tallest view."
  - "Vertical: heights add up, plus two gaps; the width is the widest view."
solution: |
  ```output
  (216.0, 40.0)
  (120.0, 118.0)
  (236.0, 60.0)
  ```

  1. A row: 40 + 120 + 40 = 200, plus two 8-point gaps = 216 wide; as tall as the tallest view, 40.
  2. A column: 40 + 22 + 40 = 102, plus 16 = 118 tall; as wide as the widest, 120.
  3. The row again with 10 points of margin on every side (what `isLayoutMarginsRelativeArrangement` adds): 236 by 60.

  This is the stack view's **fitting size**, an output of Auto Layout. Pin both ends along the axis and the stack gets a fixed length instead; then the distribution decides what happens to the difference.
````

````exercise
id: m23-l04-e2
type: comprehension
prompt: "A checkout screen has a colored bottom bar with a Pay button. On devices with a home indicator, the button sits behind the indicator, but if you pin the bar's bottom to the safe area, a white strip shows under the bar. What's the right set of constraints?"
choices:
  - text: "Bar bottom to view.bottomAnchor; the button's bottom to view.safeAreaLayoutGuide.bottomAnchor (minus some padding); the bar's top above the button."
    correct: true
    why: The color reaches the screen edge while the tappable content stays inside the safe area.
  - text: "Bar and button both to view.bottomAnchor, with a constant of −34."
    correct: false
    why: Hard-coding the inset breaks on devices with a different (or no) home indicator area.
  - text: "Bar and button both to view.safeAreaLayoutGuide.bottomAnchor."
    correct: false
    why: That leaves the strip under the bar uncovered, the problem described.
  - text: "Set additionalSafeAreaInsets.bottom = 0 to remove the home indicator area."
    correct: false
    why: additionalSafeAreaInsets adds to the safe area; it can't remove the system's part.
solution: |
  **Background to the edge, content to the safe area.** The bar's background is decoration, so it extends to `view.bottomAnchor` and fills the area behind the indicator. The button must be tappable, so its bottom is tied to `safeAreaLayoutGuide.bottomAnchor`. The bar's top is then defined relative to the button (say, 12 points above it), so the bar is taller on devices with a home indicator and shorter on devices without, with no device checks.
````

````exercise
id: m23-l04-e3
type: fill-in
prompt: "Build a toolbar row of three equally wide buttons with 8 points between them, vertically centered, with 12 points of internal padding on every side."
code: |
  let toolbar = UIStackView(arrangedSubviews: [shareButton, editButton, deleteButton])
  toolbar.axis = .[[1]]
  toolbar.distribution = .[[2]]
  toolbar.alignment = .[[3]]
  toolbar.spacing = 8
  toolbar.[[4]] = true
  toolbar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
blanks:
  - id: "1"
    answers: ["horizontal"]
  - id: "2"
    answers: ["fillEqually"]
  - id: "3"
    answers: ["center"]
  - id: "4"
    answers: ["isLayoutMarginsRelativeArrangement"]
solution: |
  ```swift ios
  import UIKit

  let shareButton = UIButton(configuration: .gray())
  let editButton = UIButton(configuration: .gray())
  let deleteButton = UIButton(configuration: .gray())

  let toolbar = UIStackView(arrangedSubviews: [shareButton, editButton, deleteButton])
  toolbar.axis = .horizontal
  toolbar.distribution = .fillEqually
  toolbar.alignment = .center
  toolbar.spacing = 8
  toolbar.isLayoutMarginsRelativeArrangement = true
  toolbar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
  ```

  `.horizontal` is a row (and the default). `.fillEqually` gives the three buttons the same width, whatever their titles. `.center` places them in the middle across the axis at their intrinsic heights; `.fill` would stretch them to the stack's height. The margins only take effect with `isLayoutMarginsRelativeArrangement = true`; without it, the stack lays out from its edges and ignores them.
````

````exercise
id: m23-l04-e4
type: find-errors
prompt: "This code manages a list of tags in a horizontal stack view. Mark every real problem."
code: |
  func showTags(_ names: [String]) {
      for old in tagStack.arrangedSubviews {
          tagStack.removeArrangedSubview(old)
      }
      var previous: UIView?
      for name in names {
          let tag = UILabel()
          tag.text = name
          tag.translatesAutoresizingMaskIntoConstraints = false
          tagStack.addArrangedSubview(tag)
          if let previous {
              tag.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: 6).isActive = true
          }
          previous = tag
      }
      tagStack.setContentHuggingPriority(.required, for: .horizontal)
  }
choices:
  - text: "removeArrangedSubview(_:) leaves the old labels as subviews, so they keep drawing on top of the new ones."
    correct: true
  - text: "The leading-to-trailing constraints between arranged subviews duplicate (and can conflict with) what the stack already creates; use spacing."
    correct: true
  - text: "Hugging priority on a stack view has no effect, because it has no intrinsic content size."
    correct: true
  - text: "Setting translatesAutoresizingMaskIntoConstraints on arranged subviews is something Apple says not to do."
    correct: true
  - text: "addArrangedSubview(_:) requires calling addSubview(_:) first."
    correct: false
    why: "Apple: it automatically adds the view as a subview if it isn't one already."
rubric:
  - I found the leftover subviews.
  - I found the manual constraints between arranged subviews.
  - I found the hugging priority on the stack.
  - I found the translatesAutoresizingMaskIntoConstraints change on arranged subviews.
solution: |
  Four problems:

  1. **Leftovers.** `removeArrangedSubview(_:)` only stops managing the view; Apple: "the view is still displayed as part of the view hierarchy." Use `old.removeFromSuperview()`, which removes it from both arrays.
  2. **Manual spacing constraints.** The stack pins neighbors itself; adding your own between them conflicts. Set `tagStack.spacing = 6`.
  3. **Hugging on the stack** does nothing (lesson 3): set priorities on the labels inside.
  4. **`translatesAutoresizingMaskIntoConstraints`** on arranged subviews: Apple's reference says not to modify it "for views that UIKit classes manage, such as … `arrangedSubviews`". The stack handles it.

  ```swift ios
  import UIKit

  let tagStack = UIStackView()

  @MainActor
  func showTags(_ names: [String]) {
      for old in tagStack.arrangedSubviews {
          old.removeFromSuperview()
      }
      tagStack.spacing = 6
      for name in names {
          let tag = UILabel()
          tag.text = name
          tag.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
          tagStack.addArrangedSubview(tag)
      }
  }
  ```

  `@MainActor` is needed because `showTags` is a free function that touches UIKit; inside a view controller it would be implied.
````

````exercise
id: m23-l04-e5
type: solve
prompt: |
  Write `positions(sizes:length:spacing:distribution:)` for a horizontal stack with a fixed length. It returns the x position of each arranged view's leading edge, for two distributions:

  - `"fillEqually"`: every view gets `(length − spacing × (n − 1)) / n`, ignoring `sizes`.
  - `"equalSpacing"`: views keep their `sizes`, and the leftover space is split evenly between the gaps, but no gap is smaller than `spacing`.

  ```swift
  print(positions(sizes: [50, 80, 50], length: 300, spacing: 10, distribution: "fillEqually"))
  print(positions(sizes: [50, 80, 50], length: 300, spacing: 10, distribution: "equalSpacing"))
  print(positions(sizes: [120, 120, 120], length: 300, spacing: 10, distribution: "equalSpacing"))
  ```

  should print `[0.0, 103.33333333333333, 206.66666666666666]`, `[0.0, 110.0, 250.0]` and `[0.0, 130.0, 260.0]`.
starter: |
  func positions(sizes: [Double], length: Double, spacing: Double, distribution: String) -> [Double] {
      // your code
      return []
  }
hints:
  - "Both cases walk from x = 0: each view starts where the previous one ended plus the gap."
  - "For equalSpacing: gap = max((length − total of sizes) / (n − 1), spacing)."
  - "The third call doesn't fit: the gap stays at the minimum and the views run past 300. A real stack view would then compress views by compression resistance; the exercise doesn't model that."
rubric:
  - fillEqually computes one shared size and walks the positions with the spacing.
  - equalSpacing keeps the sizes and computes an even gap with the minimum.
  - Positions accumulate size plus gap.
  - Handles the case where the views don't fit by keeping the minimum spacing.
solution: |
  ```swift
  func positions(sizes: [Double], length: Double, spacing: Double, distribution: String) -> [Double] {
      let count = Double(sizes.count)
      var widths = sizes
      var gap = spacing
      if distribution == "fillEqually" {
          let each = (length - spacing * (count - 1)) / count
          widths = Array(repeating: each, count: sizes.count)
      } else if distribution == "equalSpacing", sizes.count > 1 {
          gap = max((length - sizes.reduce(0, +)) / (count - 1), spacing)
      }
      var result: [Double] = []
      var x = 0.0
      for width in widths {
          result.append(x)
          x += width + gap
      }
      return result
  }

  print(positions(sizes: [50, 80, 50], length: 300, spacing: 10, distribution: "fillEqually"))
  print(positions(sizes: [50, 80, 50], length: 300, spacing: 10, distribution: "equalSpacing"))
  print(positions(sizes: [120, 120, 120], length: 300, spacing: 10, distribution: "equalSpacing"))
  ```

  ```output
  [0.0, 103.33333333333333, 206.66666666666666]
  [0.0, 110.0, 250.0]
  [0.0, 130.0, 260.0]
  ```

  `fillEqually`: (300 − 20) / 3 = 93.33…, so the views start at 0, 103.33… and 206.66…. `equalSpacing`: the views take 180 points, leaving 120 for two gaps of 60, so 0, 50 + 60 = 110, and 110 + 80 + 60 = 250. In the third call the views need 360 points; the gap would be negative, so it stays at 10 and the last view ends at 380, past the stack's end. That's the case where the real stack view starts compressing views by their compression resistance, as the `UIStackView.Distribution.equalSpacing` documentation says.
````

````exercise
id: m23-l04-e6
type: design
prompt: |
  Design the layout of a "Book a table" screen for iPhone and iPad: a title, a restaurant photo that should fill the width, a row with a date picker label and value, a row with a party-size label and a stepper, a notes paragraph, and a full-width Book button that stays at the bottom of the screen. Say which guide each element is pinned to (view edges, safe area, margins, readable content), which stacks you'd use with which axis, distribution and alignment, and which priorities you'd change.
rubric:
  - The photo is pinned to the view's leading and trailing edges (or the safe area's in landscape), not to the margins.
  - Text and rows use the layout margins; the notes paragraph uses the readable content guide.
  - Uses a vertical stack for the column and horizontal stacks for the rows, with baseline or center alignment in rows.
  - The Book button's background reaches the bottom edge while the button stays in the safe area, or the button is pinned to the safe area bottom.
  - Mentions hugging or compression priorities for the row labels or values, or explains why the stack's index tie-break is acceptable.
solution: |
  One reasonable design:

  - **Photo:** leading and trailing to `safeAreaLayoutGuide` (so it isn't cut off by the Dynamic Island in landscape), top to the safe area, height as a multiple of its width (`heightAnchor.constraint(equalTo: widthAnchor, multiplier: 9.0 / 16.0)`).
  - **Content column:** a vertical `UIStackView` with spacing 12 and `.fill` alignment, under the photo, leading and trailing to `layoutMarginsGuide`. It holds the title, the two rows and the notes.
  - **Rows:** horizontal stacks with `.fill` distribution and `.firstBaseline` alignment for label + value (the texts line up), or `.center` for label + stepper. Raise the stepper's and value's hugging to 251+ so the label takes the spare width, and raise the value's compression resistance so the label truncates first.
  - **Notes:** a multi-line label constrained to `readableContentGuide` (outside the column stack, or by giving the column itself the readable guide's leading and trailing on iPad). On iPhone it's the full margin width; on iPad it stays a comfortable width.
  - **Book button:** a bottom bar pinned to `view.bottomAnchor`, leading and trailing, with the button inside pinned to the safe area's bottom and the margins, and the bar's top 12 points above the button. On short screens the column above should be in a scroll view (lesson 5).
````

## Summary

- Four rectangles: the view's edges (backgrounds), `safeAreaLayoutGuide` (content clear of bars and system UI), `layoutMarginsGuide` (padding) and `readableContentGuide` (text columns).
- The root view's safe area includes the status bar, bars and `additionalSafeAreaInsets`; other views' safe area only covers real overlap. Insets are zero until the view is in a hierarchy.
- Set padding with `directionalLayoutMargins`. The root view enforces system minimums unless `viewRespectsSystemMinimumLayoutMargins` is false; margins stay inside the safe area by default.
- Stack views: `axis`, `distribution` (along), `alignment` (across), `spacing`, `setCustomSpacing(_:after:)`, `isLayoutMarginsRelativeArrangement`. Their fitting size is the sum along the axis plus spacing, and the maximum across.
- `.fill` uses hugging and compression resistance; set priorities rather than relying on its tie-break by index. `.fillEqually` makes views the same size. `.equalSpacing` keeps sizes and spreads the gaps.
- Hide rows with `isHidden` (animatable). `removeArrangedSubview(_:)` leaves the view on screen; `removeFromSuperview()` really removes it. Don't constrain arranged views to each other.
