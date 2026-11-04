---
id: m23-l02
title: Auto Layout and constraints
description: A constraint is a linear equation between two layout attributes, and Auto Layout solves all of them at once. You learn the equation and its parts, how the anchor API builds it, what activating means, how priorities make some constraints optional, why views created in code need translatesAutoresizingMaskIntoConstraints = false, and how to tell an ambiguous layout from an unsatisfiable one, with a small solver you can run.
module: m23
order: 2
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m23-l01]
objectives:
  - Write any constraint as item1.attribute1 relation multiplier × item2.attribute2 + constant, and invert it.
  - Build equalities, inequalities, size and ratio constraints with layout anchors.
  - Activate and deactivate constraints correctly and keep references to the ones you'll change.
  - Use priorities to make constraints optional and to choose where a layout gives way.
  - Explain what translatesAutoresizingMaskIntoConstraints does and when to set it to false.
  - Tell an ambiguous layout from an unsatisfiable one and predict what Auto Layout does with each.
terms:
  - term: Constraint
    definition: "An NSLayoutConstraint: a linear equation or inequality between two layout attributes, item1.attribute1 = multiplier × item2.attribute2 + constant, with a priority."
  - term: Layout attribute
    definition: "A feature Auto Layout can position or size: leading, trailing, top, bottom, width, height, centerX, centerY, and baselines for text."
  - term: Priority
    definition: "A UILayoutPriority from 1 to 1000. 1000 (required) must be satisfied; anything lower is optional, and Auto Layout satisfies optional constraints from highest to lowest as well as it can."
  - term: Ambiguous layout
    definition: "A set of constraints with more than one solution. Auto Layout silently picks one."
  - term: Unsatisfiable layout
    definition: "A set of required constraints with no solution. At runtime Auto Layout breaks one, logs the conflict and lays out without it."
  - term: translatesAutoresizingMaskIntoConstraints
    definition: "When true (the default for views created in code), UIKit turns the view's frame and autoresizing mask into constraints. Set it to false on views you position with your own constraints."
mastery:
  - Translate a sentence like "the button sits 8 points after the label" into the constraint equation and into anchor code.
  - Invert a constraint equation, adjusting multiplier and constant.
  - Count whether a set of constraints fully determines a view's position and size on each axis.
  - Keep a reference to a constraint and change its constant or activation in response to state.
  - Pick a 999 priority to make a constraint the layout's failure point.
resources: [apple-documentation]
cards:
  - id: m23-l02-c1
    front: What equation does every NSLayoutConstraint represent?
    back: "item1.attribute1 (=, ≤ or ≥) multiplier × item2.attribute2 + constant. It's an equation, not an assignment: Auto Layout may change either side to satisfy it."
  - id: m23-l02-c2
    front: How do you flip the sides of a constraint equation?
    back: "Invert the multiplier and the constant: a = m·b + c becomes b = (1/m)·a − c/m. With multiplier 1: button2.leading = button1.trailing + 8 is the same as button1.trailing = button2.leading − 8."
  - id: m23-l02-c3
    front: Ambiguous vs unsatisfiable layout?
    back: "Ambiguous: more than one solution; Auto Layout picks one silently. Unsatisfiable: required constraints contradict each other; Auto Layout breaks one, logs it to the console and continues."
  - id: m23-l02-c4
    front: What does a priority below 1000 mean?
    back: "The constraint is optional. Required ones are solved first; then optional ones from highest to lowest priority. An optional constraint that can't be met still pulls the layout as close to it as possible."
  - id: m23-l02-c5
    front: Which change to an installed constraint is cheap, and which throws?
    back: "Changing constant is cheap (Apple: much better than replacing the constraint). Changing priority between required (1000) and optional, after the constraint is installed, throws an exception."
---

## The idea in one sentence

You don't place views; you state relationships between their edges, centers and sizes as **linear equations**, and Auto Layout finds the one set of frames that satisfies all of them, which only works if there is exactly one.

> [!note] About this lesson's code
> The rules here come from Apple's `NSLayoutConstraint`, `NSLayoutAnchor` and `UIView` reference pages and from the archived *Auto Layout Guide*, read in November 2026. UIKit blocks are type-checked against the iOS 17 SDK on the CI runner, not run. The solver is a plain-Swift model of the rules for one view on one axis; it was compiled and run with Swift 6.3, and it simplifies what the real engine does in ways the text points out.

## The equation

Apple's `NSLayoutConstraint` page: "Each constraint is a linear equation with the following format":

```plaintext
item1.attribute1 = multiplier × item2.attribute2 + constant
```

Its example, "the leading edge of the second button should be 8 points after the trailing edge of the first button":

```plaintext
button2.leading = 1.0 × button1.trailing + 8.0
```

The parts:

| Part | In the example | Notes |
| --- | --- | --- |
| item1 | `button2` | A view or a layout guide |
| attribute1 | `leading` | Edges, center, width, height, baselines |
| relation | `=` | Also `≤` and `≥` |
| multiplier | `1.0` | Mostly 1; used for ratios between sizes |
| item2 | `button1` | Can be empty for a constant size |
| attribute2 | `trailing` | "Not an attribute" when item2 is empty |
| constant | `8.0` | Points |

Three facts about it matter more than the syntax:

1. **It's an equation, not an assignment.** Apple: "Auto Layout does not simply assign the value of the right side of this equation to the left side." It may move `button1` or `button2` or both.
2. **You can swap the sides** if you invert the multiplier and constant: `button1.trailing = 1.0 × button2.leading − 8.0` is the same constraint.
3. **Directions are fixed.** For x-axis attributes, a positive constant means "after" in the reading direction (to the right in English, to the left in Arabic or Hebrew for leading/trailing). For y-axis attributes, "values increase as you move down."

The archived Auto Layout Guide adds rules about what can be combined: you can't constrain a size attribute to a location attribute, you can't give a location attribute a constant value on its own (top = 20 means nothing without "20 below what"), you can't mix vertical with horizontal locations, and you can't mix leading/trailing with left/right.

### How many constraints?

A view needs its position and its size determined on each axis. The guide's rule of thumb: with the superview's size known, a nonambiguous layout needs **two constraints per view per dimension**. Horizontally, any two of these work: leading and trailing (width follows), leading and width (trailing follows), centerX and width. One isn't enough; three that disagree are a conflict.

Views like labels and buttons bring their own width and height ("intrinsic content size", lesson 3), which counts as one constraint per dimension. That's why a label needs only a position: a top and a leading constraint are enough.

## A solver you can run

The model below handles one view on the horizontal axis inside a superview of known width. Each rule becomes an equation in two unknowns, the view's `x` and `width`, written as `a·x + b·width = r`. Required rules must all hold; optional ones are kept only if they fit with the rules already kept, from highest priority to lowest.

```swift
enum Rule: CustomStringConvertible {
    case leading(Double)            // view.leading = superview.leading + c
    case trailing(Double)           // superview.trailing = view.trailing + c
    case width(Double)              // view.width = c
    case centerX(Double)            // view.centerX = superview.centerX + c
    case widthRatio(Double)         // view.width = m × superview.width

    var description: String {
        switch self {
        case .leading(let c): "leading \(c)"
        case .trailing(let c): "trailing \(c)"
        case .width(let c): "width \(c)"
        case .centerX(let c): "centerX \(c)"
        case .widthRatio(let m): "width × \(m)"
        }
    }

    // a·x + b·width = r
    func line(superWidth: Double) -> (a: Double, b: Double, r: Double) {
        switch self {
        case .leading(let c): (1, 0, c)
        case .trailing(let c): (1, 1, superWidth - c)
        case .width(let c): (0, 1, c)
        case .centerX(let c): (1, 0.5, superWidth / 2 + c)
        case .widthRatio(let m): (0, 1, m * superWidth)
        }
    }
}

typealias Line = (a: Double, b: Double, r: Double)

func uniqueSolution(_ lines: [Line]) -> (x: Double, width: Double)? {
    for i in lines.indices {
        for j in lines.indices where j > i {
            let p = lines[i], q = lines[j]
            let d = p.a * q.b - q.a * p.b
            if abs(d) > 1e-9 {
                return ((p.r * q.b - q.r * p.b) / d, (p.a * q.r - q.a * p.r) / d)
            }
        }
    }
    return nil
}

func isConsistent(_ lines: [Line]) -> Bool {
    if let s = uniqueSolution(lines) {
        return lines.allSatisfy { abs($0.a * s.x + $0.b * s.width - $0.r) < 1e-9 }
    }
    // Fewer than two independent lines: they must at least agree with each other.
    guard let first = lines.first else { return true }
    return lines.allSatisfy {
        abs($0.a * first.r - first.a * $0.r) < 1e-9 && abs($0.b * first.r - first.b * $0.r) < 1e-9
    }
}

func layout(_ constraints: [(Rule, Int)], superWidth: Double = 390) -> String {
    var kept: [Line] = []
    var notes: [String] = []
    for (rule, priority) in constraints.sorted(by: { $0.1 > $1.1 }) {
        let line = rule.line(superWidth: superWidth)
        if isConsistent(kept + [line]) {
            kept.append(line)
        } else if priority == 1000 {
            return "unsatisfiable: \(rule) contradicts the others"
        } else {
            notes.append("couldn't satisfy \(rule) @\(priority)")
        }
    }
    guard let s = uniqueSolution(kept) else { return "ambiguous" }
    return (["x = \(s.x), width = \(s.width)"] + notes).joined(separator: "; ")
}

print(layout([(.leading(20), 1000), (.trailing(20), 1000)]))
print(layout([(.centerX(0), 1000), (.width(200), 1000)]))
print(layout([(.leading(20), 1000)]))
print(layout([(.leading(20), 1000), (.trailing(20), 1000), (.width(400), 1000)]))
print(layout([(.leading(20), 1000), (.trailing(20), 1000), (.width(400), 999)]))
print(layout([(.leading(20), 1000), (.width(300), 750), (.widthRatio(0.5), 250)]))
```

```output
x = 20.0, width = 350.0
x = 95.0, width = 200.0
ambiguous
unsatisfiable: width 400.0 contradicts the others
x = 20.0, width = 350.0; couldn't satisfy width 400.0 @999
x = 20.0, width = 300.0; couldn't satisfy width × 0.5 @250
```

Line by line:

1. Leading and trailing: two equations, two unknowns, one answer.
2. Center and width: also two. x = 195 − 100 = 95.
3. One rule: the width could be anything. **Ambiguous.**
4. A 400-point view with 20-point margins doesn't fit in 390. Three required equations, no solution. **Unsatisfiable.**
5. The same width at priority 999 is optional, so the margins win and the width rule gives way.
6. Two optional widths that disagree: the higher priority wins.

Where the model is simpler than the real engine:

- Real constraints include inequalities, and an optional constraint that can't be met isn't simply dropped. Apple: "If a constraint `a == b` is optional, the constraint-based layout system will attempt to minimize `abs(a-b)`." In row 5 that makes no difference, because the required constraints already fix the width.
- The real engine solves every view and both axes at once, and when required constraints conflict it doesn't stop: it breaks one and carries on (see below).

## Constraints in code: anchors

You rarely create `NSLayoutConstraint` objects directly. Each `UIView` and `UILayoutGuide` has **anchors**, and each anchor creates constraints for its attribute:

| Anchor | Type | Typical methods |
| --- | --- | --- |
| `leadingAnchor`, `trailingAnchor`, `centerXAnchor` (and `leftAnchor`, `rightAnchor`) | `NSLayoutXAxisAnchor` | `constraint(equalTo:constant:)`, `constraint(greaterThanOrEqualTo:constant:)`, `constraint(lessThanOrEqualTo:constant:)` |
| `topAnchor`, `bottomAnchor`, `centerYAnchor`, `firstBaselineAnchor`, `lastBaselineAnchor` | `NSLayoutYAxisAnchor` | the same, plus `constraint(equalToSystemSpacingBelow:multiplier:)` |
| `widthAnchor`, `heightAnchor` | `NSLayoutDimension` | the same, plus `constraint(equalToConstant:)`, `constraint(equalTo:multiplier:)` |

Apple documents the meaning of each method as an equation. `a.constraint(equalTo: b, constant: c)` is `a = b + c`; `constraint(equalToConstant: c)` is `a = c`; `constraint(equalTo: b, multiplier: m)` is `a = m × b`.

The anchor types catch some mistakes at compile time: you can't constrain a `topAnchor` to a `leadingAnchor` or a width to an edge. They don't catch all of them. Apple's `NSLayoutAnchor` page: the compiler lets you constrain `leadingAnchor` to `leftAnchor` because both are x-axis anchors, but "Auto Layout does not allow constraints that mix leading and trailing attributes with left or right attributes. As a result, this constraint crashes at runtime." Use leading and trailing everywhere.

A message bubble shows most of the vocabulary:

```swift ios
import UIKit

final class MessageViewController: UIViewController {
    private let avatar = UIView()
    private let bubble = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        avatar.backgroundColor = .systemGray4
        bubble.text = "Running ten minutes late, save me a seat"
        bubble.numberOfLines = 0
        bubble.backgroundColor = .secondarySystemBackground

        for subview in [avatar, bubble] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        let margins = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            // avatar: fixed 40 × 40, at the top-leading corner of the margins
            avatar.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            avatar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor),

            // bubble: 8 points after the avatar, aligned with its top
            bubble.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 8),
            bubble.topAnchor.constraint(equalTo: avatar.topAnchor),
            // ...and never past the trailing margin: an inequality
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor),
            // ...at least as tall as the avatar
            bubble.heightAnchor.constraint(greaterThanOrEqualTo: avatar.heightAnchor),
        ])
    }
}
```

Count them. The avatar has leading + width horizontally and top + height vertically: complete. The bubble has a leading edge and an inequality on its trailing edge; its width comes from its text (a label's intrinsic size), limited by the inequality. Vertically it has a top and a minimum height; its height comes from its text, wrapped to as many lines as it needs.

`layoutMarginsGuide` is a layout guide for the view's margins (lesson 4). Apple notes that `UIView` "does not provide anchor properties for the layout margin attributes"; you use the guide's anchors.

### The old form

Code written before iOS 9 creates constraints with the full initializer. You'll see it in older projects, and it maps one to one onto the equation:

```swift ios
import UIKit

let container = UIView()
let label = UILabel()
label.translatesAutoresizingMaskIntoConstraints = false
container.addSubview(label)

let leading = NSLayoutConstraint(item: label, attribute: .leading,
                                 relatedBy: .equal,
                                 toItem: container, attribute: .leading,
                                 multiplier: 1, constant: 16)
// Same constraint with an anchor:
// label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16)
leading.isActive = true
```

Apple: "In general, you should use the layout anchor API". The initializer throws an exception for invalid combinations that anchors would have rejected at compile time.

## Activating

A new constraint does nothing until it's **active**. "For newly created constraints, the `isActive` property is `false` by default." Activating it installs it on the closest common ancestor of the two items, which is why both views must already be in the same hierarchy: "If you try to activate a constraint whose items have no common ancestor, an exception is thrown."

- `NSLayoutConstraint.activate(_:)` and `deactivate(_:)` take arrays and are "typically more efficient" than flipping each one.
- Removing a view from its superview removes the constraints that reference it.
- To change a layout later, **keep a reference** to the constraint. Changing `constant` is the cheapest change there is; Apple says it "performs much better than removing the constraint and adding a new one". To switch between two layouts, deactivate one set and activate the other, deactivating first so the two sets never conflict.

```swift ios
import UIKit

final class FiltersViewController: UIViewController {
    private let panel = UIView()
    private var panelHeight: NSLayoutConstraint!
    private var isExpanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        panel.backgroundColor = .secondarySystemBackground
        panel.clipsToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        panelHeight = panel.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelHeight,
        ])
    }

    func toggleFilters() {
        isExpanded.toggle()
        panelHeight.constant = isExpanded ? 220 : 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
}
```

Changing the constant doesn't move anything immediately. The guide: Auto Layout "schedules a layout pass for the near future". `layoutIfNeeded()` "lays out the subviews immediately, if layout updates are pending", and calling it inside an animation block means the frames it computes change inside the animation. That's the standard way to animate constraint changes: change constraints first, then lay out inside the block. Call it on a view high enough to include everything that moves; the root view is the usual choice.

`panelHeight` is an implicitly unwrapped optional because it can't be created before `view` exists. Module 8's rules apply: it's acceptable only because `viewDidLoad()` always runs before anything uses it.

## translatesAutoresizingMaskIntoConstraints

Before Auto Layout, views were positioned with frames and an **autoresizing mask** (flexible width, fixed left margin, and so on). For compatibility, UIKit can turn a view's frame and mask into constraints. Apple's reference:

- If it's `true`, "the system creates a set of constraints that duplicate the behavior specified by the view's autoresizing mask". Those constraints fix the view's size and position, so "you can't add constraints to modify this size or position without introducing conflicts."
- "By default, the system sets this property to true for any view you programmatically create. If you add views in Interface Builder, the system automatically sets this property to false."

So, for every view you create in code and position with constraints: set it to `false`. Two more rules from the same page:

- **Set it from outside.** "Set this property on a subview from a containing superview or view controller, not from within the view itself." A custom view that sets it on `self` in its initializer takes the choice away from whoever uses it.
- **Leave it alone on views UIKit manages**, "such as `UITableViewCell`, `arrangedSubviews`, and `view`." A view controller's root view is sized by its container; a stack view's arranged subviews are positioned by the stack.

Forgetting it doesn't crash. You get an unsatisfiable layout: your constraints say one thing, the generated ones (which appear in the log as `NSAutoresizingMaskLayoutConstraint`) say another. Lesson 6 reads those logs.

## Priorities

Every constraint has a `priority` from 1 to 1000. Apple: "Constraints with a priority of 1,000 are required. All priorities less than 1,000 are optional. By default, all constraints are required." After solving the required ones, "Auto Layout tries to solve all the optional constraints in priority order from highest to lowest."

`UILayoutPriority` names a few levels. The Swift reference describes them without numbers; the archived guide lists the system-defined levels as low (250), medium (500), high (750) and required (1000), which is what `.defaultLow`, `.defaultHigh` and `.required` stand for, and advises clustering priorities around them, a point or two above or below to break ties. `UILayoutPriority(999)` creates any other value.

Two practical uses:

- **Preferences.** "Prefer 300 points wide, but never wider than the screen": a required `≤` constraint plus an optional `=` constraint.
- **Failure points.** The guide recommends choosing where a layout gives way when content doesn't fit: "give your failure point a priority of 999. Under most circumstances, this high-priority constraint acts as if it were required; however, when a conflict occurs, the high-priority constraint breaks, protecting the rest of your layout." Row 5 of the solver is exactly this.

```swift ios
import UIKit

let screen = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
let card = UIView()
card.translatesAutoresizingMaskIntoConstraints = false
screen.addSubview(card)

let preferredWidth = card.widthAnchor.constraint(equalToConstant: 500)
preferredWidth.priority = UILayoutPriority(999)      // set before activating

NSLayoutConstraint.activate([
    card.centerXAnchor.constraint(equalTo: screen.centerXAnchor),
    card.leadingAnchor.constraint(greaterThanOrEqualTo: screen.leadingAnchor, constant: 16),
    card.topAnchor.constraint(equalTo: screen.topAnchor, constant: 100),
    card.heightAnchor.constraint(equalToConstant: 200),
    preferredWidth,
])
// On a 390-point screen: 358 wide (as close to 500 as the margins allow). On an iPad: 500.
```

The comment is the arithmetic, not observed output: centered, at least 16 points from the leading edge (and therefore from the trailing edge too), so at most 358 wide; the optional width pulls it as close to 500 as it can.

Set the priority **before** activating. Apple: "Priorities may not change from nonrequired to required, or from required to nonrequired. An exception will be thrown" if you do it after the constraint is added. Changing from one optional priority to another is allowed.

## Ambiguous and unsatisfiable layouts

Apple's definition: "A valid layout is defined as a set of constraints with one and only one possible solution." The two ways to fail:

| | Ambiguous | Unsatisfiable |
| --- | --- | --- |
| Means | More than one solution | No solution for the required constraints |
| Typical cause | A missing constraint; two optional constraints with the same priority pulling in different directions | Contradicting constraints; frame-based constraints from `translatesAutoresizingMaskIntoConstraints`; content too big for a required size |
| At runtime | Auto Layout picks one of the solutions. The guide: "there are no warnings written to the console" | Auto Layout breaks one constraint, logs the conflict to the console and lays out without it |
| Symptom | Views in the wrong place, or jumping between places from one layout pass to the next | Often nothing visible; sometimes a view is missized or gone |

The guide says to fix unsatisfiable constraints even when the screen looks right, because "any change to the view hierarchy or SDK could also alter the set of broken constraints, suddenly producing an obviously broken layout." Lesson 6 covers how to find both kinds.

## Common mistakes

> [!error] Activating constraints before adding the views
> Constraints between views without a common ancestor throw an exception when activated. Call `addSubview(_:)` first.

> [!error] Forgetting translatesAutoresizingMaskIntoConstraints = false
> The generated constraints pin the view to its current frame (often zero) and conflict with yours. The console shows `NSAutoresizingMaskLayoutConstraint` entries.

> [!error] Mixing leading/trailing with left/right
> It compiles, because they're all x-axis anchors, and crashes at runtime. Use leading and trailing.

> [!error] Writing a positive constant for a trailing or bottom inset
> `view.trailing = superview.trailing + 16` puts the view 16 points **outside** the superview. Use `-16`, or flip the items: `superview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 16)`.

> [!error] Changing a priority to or from required after activation
> It throws. Decide the priority first, or move between optional values like 999 and 250.

> [!error] Creating a new constraint every time something changes
> Old constraints stay active and conflict with the new ones. Keep a reference and change its `constant`, or deactivate the old set before activating the new one.

## Exercises

````exercise
id: m23-l02-e1
type: prediction
prompt: "Apple's Auto Layout Guide lays out two views side by side: `Red.leading = Superview.leading + 20`, `Blue.leading = Red.trailing + 8`, `Superview.trailing = Blue.trailing + 20` and `Red.width = Blue.width`. This code computes what Auto Layout solves for a 390-point superview. What does it print?"
code: |
  let superWidth = 390.0
  let margin = 20.0
  let gap = 8.0

  let width = (superWidth - margin - gap - margin) / 2
  let redX = margin
  let blueX = redX + width + gap
  print(redX, width)
  print(blueX, width)
  print(blueX + width + margin == superWidth)
output: |
  20.0 171.0
  199.0 171.0
  true
hints:
  - "The four horizontal constraints say: 20 + width + 8 + width + 20 = 390."
solution: |
  ```output
  20.0 171.0
  199.0 171.0
  true
  ```

  The four equations have two unknowns that matter (the shared width and the positions follow from it): 20 + w + 8 + w + 20 = 390, so w = 171. Red starts at 20; blue starts at 20 + 171 + 8 = 199 and ends at 370, which leaves the 20-point margin. Two views, four horizontal constraints: the guide's "two per view per dimension" rule. Remove any one and the layout becomes ambiguous; that's the point of counting.
````

````exercise
id: m23-l02-e2
type: comprehension
prompt: "Which constraint is identical to `image.height = 0.5 × image.width + 10`?"
choices:
  - text: "`image.width = 2 × image.height − 20`"
    correct: true
    why: "Solve for width: width = (height − 10) / 0.5 = 2 × height − 20."
  - text: "`image.width = 2 × image.height − 10`"
    correct: false
    why: "The constant must be divided by the multiplier too: −10 / 0.5 = −20."
  - text: "`image.width = 0.5 × image.height + 10`"
    correct: false
    why: That's a different ratio. Swapping sides inverts the multiplier.
  - text: "`image.width = 2 × image.height + 20`"
    correct: false
    why: The sign of the constant flips when it moves to the other side.
solution: |
  **`image.width = 2 × image.height − 20`.** From `a = m·b + c`, solving for `b` gives `b = (1/m)·a − c/m`. Here `m = 0.5` and `c = 10`, so the multiplier becomes 2 and the constant −20. Apple's note says the same thing for the simple cases: "if you switch the order, you must also invert the multiplier and constant". The general form is the rule to remember.
````

````exercise
id: m23-l02-e3
type: fill-in
prompt: "A save button should sit 12 points below a text field, be at least 44 points tall, stay inside the trailing margin, and prefer (but not require) a width of 280 points."
code: |
  let preferred = saveButton.widthAnchor.constraint([[1]]: 280)
  preferred.priority = .[[2]]
  NSLayoutConstraint.activate([
      saveButton.topAnchor.constraint(equalTo: field.[[3]], constant: 12),
      saveButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
      saveButton.trailingAnchor.constraint([[4]]: margins.trailingAnchor),
      saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      preferred,
  ])
blanks:
  - id: "1"
    answers: ["equalToConstant"]
  - id: "2"
    answers: ["defaultHigh", "defaultLow"]
  - id: "3"
    answers: ["bottomAnchor"]
  - id: "4"
    answers: ["lessThanOrEqualTo"]
solution: |
  ```swift ios
  import UIKit

  final class SaveViewController: UIViewController {
      private let field = UITextField()
      private let saveButton = UIButton(configuration: .filled())

      override func viewDidLoad() {
          super.viewDidLoad()
          for subview in [field, saveButton] as [UIView] {
              subview.translatesAutoresizingMaskIntoConstraints = false
              view.addSubview(subview)
          }
          let margins = view.layoutMarginsGuide
          let preferred = saveButton.widthAnchor.constraint(equalToConstant: 280)
          preferred.priority = .defaultHigh
          NSLayoutConstraint.activate([
              field.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
              field.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
              field.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
              saveButton.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 12),
              saveButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
              saveButton.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor),
              saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
              preferred,
          ])
      }
  }
  ```

  "12 points below" is `top = field.bottom + 12`. "Stay inside the trailing margin" is an inequality, `trailing ≤ margins.trailing`. "Prefer 280" is an equality with a priority below 1000; `.defaultHigh` (750) is a reasonable choice, and any optional priority works for the exercise. On a narrow screen the required inequality wins and the button gets narrower; on a wide one it's exactly 280.
````

````exercise
id: m23-l02-e4
type: find-errors
prompt: "Mark every real problem in this code. It runs in a view controller's viewDidLoad()."
code: |
  let badge = UILabel()
  let icon = UIImageView()
  NSLayoutConstraint.activate([
      badge.topAnchor.constraint(equalTo: icon.topAnchor),
      badge.leadingAnchor.constraint(equalTo: icon.rightAnchor, constant: 4),
  ])
  icon.translatesAutoresizingMaskIntoConstraints = false
  view.addSubview(icon)
  view.addSubview(badge)

  let iconWidth = icon.widthAnchor.constraint(equalToConstant: 24)
  iconWidth.isActive = true
  iconWidth.priority = .defaultHigh
choices:
  - text: "The constraints are activated before badge and icon are in the hierarchy, so they have no common ancestor."
    correct: true
  - text: "badge.leadingAnchor is constrained to icon.rightAnchor, mixing leading with right."
    correct: true
  - text: "badge never gets translatesAutoresizingMaskIntoConstraints = false."
    correct: true
  - text: "iconWidth's priority changes from required to optional after it was activated."
    correct: true
  - text: "A UILabel can't be constrained without a width constraint."
    correct: false
    why: A label has an intrinsic content size, which supplies its width and height.
  - text: "widthAnchor.constraint(equalToConstant:) needs a second item."
    correct: false
    why: Size anchors can be constrained to a constant; only location attributes can't.
rubric:
  - I found the activation before addSubview.
  - I found the leading/right mix.
  - I found the missing translatesAutoresizingMaskIntoConstraints on badge.
  - I found the priority change after activation.
solution: |
  Four problems:

  1. **Order.** `activate` runs while neither view has a superview. Apple: activating constraints whose items have no common ancestor throws. Add both views first.
  2. **Leading with right.** It compiles (both are x-axis anchors) and "crashes at runtime". Use `icon.trailingAnchor`.
  3. **`badge` keeps `translatesAutoresizingMaskIntoConstraints = true`**, so its zero frame becomes constraints that conflict with the two you add.
  4. **Required to optional after activation** throws. Set `priority` before `isActive = true`.

  Fixed:

  ```swift ios
  import UIKit

  final class BadgeViewController: UIViewController {
      override func viewDidLoad() {
          super.viewDidLoad()
          let badge = UILabel()
          let icon = UIImageView()
          for subview in [icon, badge] as [UIView] {
              subview.translatesAutoresizingMaskIntoConstraints = false
              view.addSubview(subview)
          }
          let iconWidth = icon.widthAnchor.constraint(equalToConstant: 24)
          iconWidth.priority = .defaultHigh
          NSLayoutConstraint.activate([
              icon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
              icon.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
              icon.heightAnchor.constraint(equalTo: icon.widthAnchor),
              iconWidth,
              badge.topAnchor.constraint(equalTo: icon.topAnchor),
              badge.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
          ])
      }
  }
  ```
````

````exercise
id: m23-l02-e5
type: solve
prompt: |
  Write `inverted(_:)`, which returns the same constraint with its sides swapped. The constraint `first = multiplier × second + constant` becomes `second = (1 / multiplier) × first − constant / multiplier`. For inequalities, swapping sides also flips the relation when the multiplier is positive (`≤` becomes `≥`); this exercise only uses positive multipliers.

  ```swift
  print(describe(inverted(Equation(first: "button2.leading", relation: "=", multiplier: 1, second: "button1.trailing", constant: 8))))
  print(describe(inverted(Equation(first: "image.height", relation: "=", multiplier: 0.5, second: "image.width", constant: 10))))
  print(describe(inverted(Equation(first: "label.trailing", relation: "<=", multiplier: 1, second: "margins.trailing", constant: 0))))
  ```

  should print:

  ```plaintext
  button1.trailing = 1.0 × button2.leading + -8.0
  image.width = 2.0 × image.height + -20.0
  margins.trailing >= 1.0 × label.trailing + -0.0
  ```
starter: |
  struct Equation {
      var first: String
      var relation: String     // "=", "<=" or ">="
      var multiplier: Double
      var second: String
      var constant: Double
  }

  func describe(_ e: Equation) -> String {
      "\(e.first) \(e.relation) \(e.multiplier) × \(e.second) + \(e.constant)"
  }

  func inverted(_ e: Equation) -> Equation {
      // your code
      return e
  }
hints:
  - "From first = m·second + c, subtract c and divide by m."
  - "first ≤ second means second ≥ first."
  - "-0.0 is what Swift prints for the negation of 0.0. The expected output includes it."
rubric:
  - Swaps first and second.
  - Inverts the multiplier.
  - Divides the negated constant by the original multiplier.
  - Flips <= and >=, keeps =.
solution: |
  ```swift
  struct Equation {
      var first: String
      var relation: String
      var multiplier: Double
      var second: String
      var constant: Double
  }

  func describe(_ e: Equation) -> String {
      "\(e.first) \(e.relation) \(e.multiplier) × \(e.second) + \(e.constant)"
  }

  func inverted(_ e: Equation) -> Equation {
      let relation = switch e.relation {
      case "<=": ">="
      case ">=": "<="
      default: e.relation
      }
      return Equation(first: e.second, relation: relation,
                      multiplier: 1 / e.multiplier,
                      second: e.first,
                      constant: -e.constant / e.multiplier)
  }

  print(describe(inverted(Equation(first: "button2.leading", relation: "=", multiplier: 1, second: "button1.trailing", constant: 8))))
  print(describe(inverted(Equation(first: "image.height", relation: "=", multiplier: 0.5, second: "image.width", constant: 10))))
  print(describe(inverted(Equation(first: "label.trailing", relation: "<=", multiplier: 1, second: "margins.trailing", constant: 0))))
  ```

  ```output
  button1.trailing = 1.0 × button2.leading + -8.0
  image.width = 2.0 × image.height + -20.0
  margins.trailing >= 1.0 × label.trailing + -0.0
  ```

  From `a = m·b + c`: `a − c = m·b`, so `b = a/m − c/m`. The first example is Apple's own pair; the second is the aspect-ratio case, where both multiplier and constant change. The third shows why the relation flips: "the label's trailing edge is at most the margin" is the same as "the margin is at least the label's trailing edge". The `-0.0` is Swift negating 0.0; a real tool would normalize it. Apple's guide also states its rules of thumb for choosing a side: prefer whole-number multipliers and positive constants, and write views in layout order. Being able to invert is how you get there.
````

````exercise
id: m23-l02-e6
type: design
prompt: |
  A login screen has, from top to bottom: a logo (fixed 80 × 80, centered), an email field, a password field and a sign-in button. The fields and button are as wide as the layout margins allow but never wider than 400 points, and stay centered on an iPad. Gaps: 32 points under the logo, 12 between fields, 24 above the button.

  List every constraint (in equation form or as anchor calls), with priorities where they matter, and show that each view is fully determined on both axes. Say which constraint is your failure point if the screen is too short.
rubric:
  - The logo has centerX, top, width and height (two per axis).
  - Each field and the button have a top constraint relative to the view above; height comes from intrinsic size or a constant.
  - Width uses a required ≤ 400 plus an optional "equal to the margins" (or required ≥ margins inequalities plus an optional width), and centerX keeps it centered.
  - No horizontal constraint is both required and conflicting on a 390-point phone or a wide iPad.
  - A failure point is named (for example, the gap under the logo at 999, or putting the column in a scroll view).
solution: |
  One solution, per view:

  - **Logo:** `logo.centerX = view.centerX`, `logo.top = safeArea.top + 40`, `logo.width = 80`, `logo.height = 80`. Two per axis.
  - **Email field:** `email.top = logo.bottom + 32` (priority 999, the failure point), `email.centerX = view.centerX`, `email.width ≤ 400` (required), `email.leading ≥ margins.leading` (required), `email.width = margins.width` (priority 750). Height: the field's intrinsic height. Horizontally the required constraints keep it inside the margins and under 400 wide; the optional width pulls it to the full margin width, and centerX places it, so there's one solution on every screen.
  - **Password field and button:** the same horizontal set (or `leading = email.leading` and `trailing = email.trailing`, which is shorter); `password.top = email.bottom + 12`, `button.top = password.bottom + 24`; heights from content, or `button.height ≥ 44`.

  Vertically each view has a top and a height, so nothing is ambiguous. On a very short screen (landscape iPhone, large text), the column doesn't fit; marking the logo gap as 999 lets it shrink before anything else breaks. The better fix is to put the column in a scroll view, which lesson 5 does. In code, a vertical stack view (lesson 4) creates the vertical constraints for you.
````

## Summary

- A constraint is `item1.attribute1 (=, ≤, ≥) multiplier × item2.attribute2 + constant`, with a priority. It's an equation; swapping sides inverts the multiplier and constant.
- A valid layout has exactly one solution: roughly two constraints per view per axis, counting intrinsic sizes.
- Build constraints with anchors; use leading/trailing, never mixed with left/right. Activate with `NSLayoutConstraint.activate(_:)` after the views share an ancestor.
- Keep references to constraints you'll change. Changing `constant` is cheap; animate with `layoutIfNeeded()` inside an animation block.
- Views created in code need `translatesAutoresizingMaskIntoConstraints = false`, set from outside the view. Don't touch it on views UIKit manages.
- Priorities below 1000 are optional and resolved from highest to lowest. Use 999 for a failure point. Don't switch between required and optional after activation.
- Ambiguous: several solutions, silent. Unsatisfiable: no solution, Auto Layout breaks a constraint and logs it.
