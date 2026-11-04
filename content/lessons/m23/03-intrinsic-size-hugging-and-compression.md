---
id: m23-l03
title: Intrinsic content size, hugging and compression resistance
description: Labels, buttons and switches know how big they want to be. You learn what intrinsic content size is, how Auto Layout turns it into two pairs of optional constraints (content hugging and compression resistance), how their priorities decide which view stretches and which one gets cut when space runs out, how to give a custom view an intrinsic size, and the difference between intrinsic size and fitting size.
module: m23
order: 3
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m23-l02]
objectives:
  - Say which standard views have an intrinsic content size, on which axes, and what it depends on.
  - Write hugging and compression resistance as the inequalities Auto Layout generates.
  - Predict which view stretches and which one is compressed from their priorities, and fix ties.
  - Give a custom view an intrinsic content size and invalidate it when its content changes.
  - Tell intrinsic content size (an input to Auto Layout) from fitting size (an output).
terms:
  - term: Intrinsic content size
    definition: "The natural size of a view based only on its own content: a label's text and font, a button's title, an image view's image. Read from intrinsicContentSize; UIView.noIntrinsicMetric means none on that axis."
  - term: Content hugging
    definition: "An optional constraint, size ≤ intrinsic size, whose priority says how strongly a view resists growing beyond its content. Default 250."
  - term: Compression resistance
    definition: "An optional constraint, size ≥ intrinsic size, whose priority says how strongly a view resists shrinking below its content. Default 750."
  - term: CHCR priorities
    definition: "Apple's shorthand for content-hugging and compression-resistance priorities, set per axis with setContentHuggingPriority(_:for:) and setContentCompressionResistancePriority(_:for:)."
  - term: Fitting size
    definition: "The size Auto Layout computes for a view from its constraints and content, for example a stack view's. An output, unlike the intrinsic size, which is an input."
mastery:
  - Explain why a label and a text field in a row with default priorities is ambiguous, and fix it by changing one priority.
  - Decide which of two labels truncates when they don't fit, and set the priority that makes the other one win.
  - Predict whether an optional width constraint beats a view's hugging or compression resistance.
  - Write intrinsicContentSize for a custom view and call invalidateIntrinsicContentSize() when it changes.
  - Explain why setting CHCR priorities on a stack view has no effect.
resources: [apple-documentation]
cards:
  - id: m23-l03-c1
    front: What constraints does Auto Layout create from a view's intrinsic content size?
    back: "Per axis, two optional ones: compression resistance (size ≥ intrinsic, default priority 750) and content hugging (size ≤ intrinsic, default priority 250). So views stretch more easily than they shrink."
  - id: m23-l03-c2
    front: A label and a text field sit in a row with extra space. Which one stretches?
    back: "The one with the lower horizontal hugging priority. With equal priorities (both 250 in code) the layout is ambiguous. Raise the label's to 251, as Interface Builder does for labels."
  - id: m23-l03-c3
    front: Two labels don't fit in a row. Which one is cut?
    back: "The one with the lower horizontal compression resistance. Raise the priority of the one that must stay whole, for example a date to 751 so the title truncates instead."
  - id: m23-l03-c4
    front: What must a custom view do when the content behind its intrinsicContentSize changes?
    back: "Call invalidateIntrinsicContentSize(), so Auto Layout reads the new size in its next layout pass."
  - id: m23-l03-c5
    front: Why shouldn't you make hugging or compression resistance required (1000)?
    back: "Apple's guide: it's usually better for a view to be the wrong size than to create a conflict. If a view should always be its intrinsic size, use a very high optional priority like 999."
---

## The idea in one sentence

A view with content has a size it would like to be, and Auto Layout treats that size as two soft rules per axis, "don't grow past it" and "don't shrink below it", whose priorities decide who gives way when the other constraints disagree.

> [!note] About this lesson's code
> The rules come from Apple's `UIView` and `UIStackView` reference pages and the archived *Auto Layout Guide*, read in November 2026. UIKit blocks are type-checked against the iOS 17 SDK on the CI runner, not run, so the sizes in their comments are what the rules predict, not measured values. The two models are plain Swift, compiled and run with Swift 6.3, and simplify the real engine as the text explains.

## Intrinsic content size

`intrinsicContentSize` is "the natural size for the receiving view, considering only properties of the view itself." The guide's examples:

| View | Intrinsic content size |
| --- | --- |
| `UIView` | None |
| `UISlider` | Width only |
| Labels, buttons, switches, text fields | Width and height |
| Text views, image views | It varies: an empty image view has none; with an image, it's the image's size. A text view has none while scrolling is enabled |

For a label it's "based on the amount of text shown and the font used". Change the text or the font and the intrinsic size changes, and Auto Layout lays out again. This is the main reason Auto Layout screens adapt to translations and to Dynamic Type (lesson 6) without extra code.

A label with `numberOfLines = 0` has a height that depends on its width: the narrower it is, the more lines it needs. Auto Layout handles that when the label's width is determined by other constraints. `preferredMaxLayoutWidth` lets you set the wrapping width explicitly; you rarely need it.

`UIView.noIntrinsicMetric` is the value for "no intrinsic size on this axis". A plain `UIView` returns it for both, which is why an empty `UIView()` with only a top and leading constraint is ambiguous while a `UILabel` isn't.

## Hugging and compression resistance

Auto Layout represents the intrinsic size "using a pair of constraints for each dimension". From the guide, horizontally:

```plaintext
// Compression resistance
view.width ≥ intrinsicWidth
// Content hugging
view.width ≤ intrinsicWidth
```

and the same for the height. Both are **optional** constraints with their own priorities:

- **Content hugging** "pulls the view inward so that it fits snugly around the content." Its priority is how strongly the view refuses to grow.
- **Compression resistance** "pushes the view outward so that it does not clip the content." Its priority is how strongly the view refuses to shrink.

"By default, views use a 250 priority for their content hugging, and a 750 priority for their compression resistance. Therefore, it's easier to stretch a view than it is to shrink it." For a button, stretching is harmless and shrinking cuts its title.

You read and set them per axis:

```swift ios
import UIKit

let nameLabel = UILabel()
nameLabel.text = "Name"

let hugging = nameLabel.contentHuggingPriority(for: .horizontal)
let resistance = nameLabel.contentCompressionResistancePriority(for: .vertical)

nameLabel.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
nameLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
```

Because these are ordinary optional constraints, they compete with yours by priority, like everything else. An optional width constraint at 500 beats hugging at 250; the same constraint at 200 loses to compression resistance at 750.

## Who stretches, who shrinks

In a row of views pinned edge to edge between two fixed edges, there's usually either space left over or not enough. The priorities decide what happens:

- **Space left over:** the view with the **lowest hugging** priority grows.
- **Not enough space:** the view with the **lowest compression resistance** shrinks (a label truncates).
- **A tie at the lowest level:** the layout is ambiguous. The guide: "if all the views have an identical content-hugging priority, the layout is ambiguous. Auto Layout doesn't know which view should be stretched."

This model applies those three rules to one row. It's deliberately simple: one view takes all the extra space or loses width until it reaches zero, and then the next one gives way.

```swift
struct Item {
    let name: String
    let intrinsic: Double
    var hugging = 250
    var compression = 750
}

func layoutRow(_ items: [Item], available: Double, spacing: Double = 8) -> String {
    var widths = items.map { $0.intrinsic }
    let needed = widths.reduce(0, +) + spacing * Double(items.count - 1)
    let extra = available - needed

    if extra > 0 {
        let lowest = items.map { $0.hugging }.min() ?? 0
        let growers = items.indices.filter { items[$0].hugging == lowest }
        if growers.count > 1 { return "ambiguous: equal hugging \(lowest)" }
        widths[growers[0]] += extra
    } else if extra < 0 {
        var missing = -extra
        for level in Set(items.map { $0.compression }).sorted() where missing > 0 {
            let shrinkers = items.indices.filter { items[$0].compression == level }
            if shrinkers.count > 1 { return "ambiguous: equal compression resistance \(level)" }
            let cut = min(missing, widths[shrinkers[0]])
            widths[shrinkers[0]] -= cut
            missing -= cut
        }
    }
    var parts: [String] = []
    for (item, width) in zip(items, widths) {
        parts.append("\(item.name) \(width)")
    }
    return parts.joined(separator: ", ")
}

// A form row: "Name" label and a text field, 358 points available.
print(layoutRow([Item(name: "label", intrinsic: 44), Item(name: "field", intrinsic: 120)], available: 358))
print(layoutRow([Item(name: "label", intrinsic: 44, hugging: 251), Item(name: "field", intrinsic: 120)], available: 358))

// A list row: a long title and a date that don't both fit in 350 points.
print(layoutRow([Item(name: "title", intrinsic: 250), Item(name: "date", intrinsic: 120)], available: 350))
print(layoutRow([Item(name: "title", intrinsic: 250), Item(name: "date", intrinsic: 120, compression: 751)], available: 350))
```

```output
ambiguous: equal hugging 250
label 44.0, field 306.0
ambiguous: equal compression resistance 750
title 222.0, date 120.0
```

1. Label and field both hug at 250: there are 186 spare points and no reason to give them to one rather than the other. Ambiguous; the real engine picks one, and you may get a stretched label with the field squeezed next to it.
2. With the label at 251, the field has the lowest hugging and takes all 186 extra points.
3. Title and date need 378 points and get 350. Both resist at 750: ambiguous.
4. With the date at 751, the title gives up the 28 points and truncates; the date stays whole.

The guide calls the form-row case "so common that Interface Builder automatically handles it for you, setting the content-hugging priority for all labels to 251. If you are programmatically creating the layout, you need to modify the content-hugging priority yourself." In code, labels start at 250 like every other view.

The same two fixes in UIKit:

```swift ios
import UIKit

final class ContactRowViewController: UIViewController {
    private let nameLabel = UILabel()
    private let nameField = UITextField()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        nameLabel.text = "Name"
        nameField.placeholder = "Jane Appleseed"
        nameField.borderStyle = .roundedRect
        titleLabel.text = "Quarterly planning notes and action items"
        dateLabel.text = "Yesterday"

        // The label keeps its size; the field takes the extra width.
        nameLabel.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
        // The date never truncates; the title does.
        dateLabel.setContentCompressionResistancePriority(UILayoutPriority(751), for: .horizontal)

        for subview in [nameLabel, nameField, titleLabel, dateLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let margins = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameField.firstBaselineAnchor.constraint(equalTo: nameLabel.firstBaselineAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 24),
            dateLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
        ])
    }
}
```

Each row is pinned leading and trailing with a fixed gap; the widths come from the intrinsic sizes and the priorities. Vertically each view has a position (a top or a baseline) and its intrinsic height. Aligning baselines lines up the text of a label and a field even when their heights differ. The guide warns that "baseline constraints work only with views that are at their intrinsic content height."

### Guidelines from Apple's guide

- Don't make CHCR priorities required. "It's usually better for a view to be the wrong size than for it to accidentally create a conflict. If a view should always be its intrinsic content size, consider using a very high priority (999) instead."
- Views with invisible backgrounds (labels, plain buttons) that get stretched produce "odd and unexpected layouts", because the text simply appears in the wrong place. Increase their hugging.
- Some views, like switches, should always be their intrinsic size. Raise both priorities.

## Optional constraints against intrinsic size

The rule "higher priority wins" also settles fights between your own optional constraints and a view's content. This model handles one view, one axis, and one optional size constraint:

```swift
func resolvedWidth(intrinsic: Double, hugging: Int, compression: Int,
                   requested: Double, priority: Int) -> String {
    if requested > intrinsic {
        if priority > hugging { return "\(requested) (constraint beats hugging)" }
        if priority < hugging { return "\(intrinsic) (hugging wins)" }
    } else if requested < intrinsic {
        if priority > compression { return "\(requested) (constraint beats compression resistance)" }
        if priority < compression { return "\(intrinsic) (compression resistance wins)" }
    } else {
        return "\(intrinsic) (no conflict)"
    }
    return "ambiguous (equal priorities)"
}

// A button whose title needs 90 points.
print(resolvedWidth(intrinsic: 90, hugging: 250, compression: 750, requested: 200, priority: 500))
print(resolvedWidth(intrinsic: 90, hugging: 250, compression: 750, requested: 200, priority: 200))
print(resolvedWidth(intrinsic: 90, hugging: 250, compression: 750, requested: 60, priority: 500))
print(resolvedWidth(intrinsic: 90, hugging: 250, compression: 750, requested: 60, priority: 999))
```

```output
200.0 (constraint beats hugging)
90.0 (hugging wins)
90.0 (compression resistance wins)
60.0 (constraint beats compression resistance)
```

The real engine doesn't jump to one value or the other when the losing side is optional too: an unsatisfied optional constraint still pulls ("tries to come as close as possible"). With nothing else involved, the losing optional constraint's pull doesn't change the result, so this model and the engine agree on these four cases.

## A custom view with an intrinsic size

Views that draw their own content (a rating control, a chart, a badge) know their natural size and Auto Layout doesn't. Override `intrinsicContentSize` and call `invalidateIntrinsicContentSize()` whenever the content behind it changes. Apple: invalidating "allows the constraint-based layout system to take the new intrinsic content size into account in its next layout pass."

```swift ios
import UIKit

final class RatingView: UIView {
    private let starSize: CGFloat = 20
    private let spacing: CGFloat = 4

    var maximum = 5 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override var intrinsicContentSize: CGSize {
        let count = CGFloat(maximum)
        return CGSize(width: count * starSize + (count - 1) * spacing, height: starSize)
    }
}

final class ProgressLine: UIView {
    // As wide as the layout makes it, always 4 points tall.
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 4)
    }
}

let rating = RatingView()
let size = rating.intrinsicContentSize   // 5 × 20 + 4 × 4 = 116 by 20
rating.maximum = 10                      // 236 by 20 after the next layout pass
```

With an intrinsic size, `RatingView` needs only a position: a leading and a top constraint. `ProgressLine` has an intrinsic height only, so it needs a position and a width (leading and trailing).

Apple's `intrinsicContentSize` page adds a restriction: the size "must be independent of the content frame, because there's no way to dynamically communicate a changed width to the layout system based on a changed height." If your view's height depends on its width the way a wrapping label's does, build it from subviews with constraints instead and let Auto Layout compute it.

## Intrinsic size vs fitting size

The guide draws a line between the two:

- **Intrinsic content size** is an **input**: the view states it, and Auto Layout turns it into hugging and compression constraints.
- **Fitting size** is an **output**: the size Auto Layout computes for a view from its constraints and subviews.

A stack view is the standard example. It sizes itself from its arranged subviews, so you can position it with just two constraints, as if it had an intrinsic size. But "setting the stack view's CHCR priorities has no effect, because the stack view does not have an intrinsic content size." To make a stack view win or lose against something outside it, change the priorities of the views **inside** it, or add explicit constraints.

To ask for a fitting size directly, `systemLayoutSizeFitting(_:)` "returns the optimal size of the view based on its current constraints" without changing the view. Pass `UIView.layoutFittingCompressedSize` for the smallest size or `layoutFittingExpandedSize` for the largest.

## Common mistakes

> [!error] Leaving equal hugging priorities in a row with spare space
> Two views at 250 in a row that's wider than their content is ambiguous; Auto Layout picks which one stretches. Lower the hugging of the one that should grow, or raise the other's.

> [!error] Fixing truncation with a required width
> A fixed width on a label clips it at the next language or text size. Let the label keep its intrinsic width and give compression priority to whatever must stay whole.

> [!error] Forgetting invalidateIntrinsicContentSize()
> A custom view that changes its content without invalidating keeps its old size until something else triggers a layout of that view.

> [!error] Setting CHCR priorities on a stack view
> It has no intrinsic size, so they do nothing. Set them on its arranged subviews.

> [!error] Making hugging or compression resistance 1000
> Required CHCR turns any squeeze into an unsatisfiable layout. Use 999 when a view must keep its size.

## Exercises

````exercise
id: m23-l03-e1
type: prediction
prompt: "This uses a shorter version of the lesson's row model: the view with the lowest hugging takes the extra space, or the one with the lowest compression resistance gives up the missing space. What does it print?"
code: |
  func row(available: Double, widths: [Double], hugging: [Int], compression: [Int]) -> [Double] {
      var result = widths
      let extra = available - widths.reduce(0, +)
      if extra > 0 {
          let index = hugging.firstIndex(of: hugging.min()!)!
          result[index] += extra
      } else if extra < 0 {
          let index = compression.firstIndex(of: compression.min()!)!
          result[index] += extra
      }
      return result
  }

  print(row(available: 300, widths: [80, 100, 60], hugging: [251, 250, 252], compression: [750, 750, 750]))
  print(row(available: 200, widths: [80, 100, 60], hugging: [250, 250, 250], compression: [750, 749, 760]))
  print(row(available: 240, widths: [80, 100, 60], hugging: [250, 250, 250], compression: [750, 750, 750]))
output: |
  [80.0, 160.0, 60.0]
  [80.0, 60.0, 60.0]
  [80.0, 100.0, 60.0]
hints:
  - "First call: 60 spare points. Who hugs least?"
  - "Second call: 40 points missing. Who resists least?"
  - "Third call: they fit exactly, so the priorities don't matter."
solution: |
  ```output
  [80.0, 160.0, 60.0]
  [80.0, 60.0, 60.0]
  [80.0, 100.0, 60.0]
  ```

  1. 300 − 240 = 60 spare points. The middle view has the lowest hugging (250), so it grows from 100 to 160.
  2. 200 − 240 = −40. The middle view has the lowest compression resistance (749), so it shrinks from 100 to 60.
  3. 240 points for 240 points of content: nothing stretches or shrinks, so the priorities are irrelevant, even though all three are tied. A tie only matters when there's a conflict to resolve.

  Note that `firstIndex(of:)` silently picks the first view on a tie. The real engine doesn't promise anything that predictable; a tie there is ambiguity.
````

````exercise
id: m23-l03-e2
type: comprehension
prompt: "A settings row created in code has a label (\"Notifications\") pinned to the leading margin, a switch pinned to the trailing margin, and a fixed 8-point gap between them. On an iPad, the view debugger shows the switch's frame is far wider than the control it draws, while the label keeps its natural width. What do you change?"
choices:
  - text: "Raise the switch's horizontal hugging priority above the label's."
    correct: true
    why: The view with the lowest hugging stretches. The switch should never stretch, so it must hug harder than the label.
  - text: "Raise the switch's horizontal compression resistance."
    correct: false
    why: Compression resistance matters when there isn't enough space. Here there's too much.
  - text: "Give the label a fixed width."
    correct: false
    why: That fixes one language and one text size. With longer text it truncates.
  - text: "Make the switch's hugging priority 1000."
    correct: false
    why: "Required CHCR can create conflicts. Apple's guide suggests 999 at most when a view must keep its intrinsic size."
solution: |
  **Raise the switch's hugging priority.** With spare space, the view with the lowest hugging priority grows. Both start at 250 in code, so Auto Layout had to pick, and it picked the switch. Setting the switch to, say, 750 (or the label to 249) makes the label take the extra width. Apple's guide singles out switches as views that "should always be displayed at their intrinsic content size" and suggests raising their CHCR priorities, but not to required.
````

````exercise
id: m23-l03-e3
type: fill-in
prompt: "A custom badge view draws its count in a capsule. Give it an intrinsic size and make sure Auto Layout notices when the count changes. Then make sure a title next to it truncates before the badge does."
code: |
  final class CountBadge: UIView {
      var count = 0 {
          didSet { [[1]]() }
      }

      override var [[2]]: CGSize {
          CGSize(width: count > 99 ? 36 : 24, height: 20)
      }
  }

  badge.setContentCompressionResistancePriority(.[[3]], for: .[[4]])
blanks:
  - id: "1"
    answers: ["invalidateIntrinsicContentSize"]
  - id: "2"
    answers: ["intrinsicContentSize"]
  - id: "3"
    answers: ["defaultHigh", "required"]
  - id: "4"
    answers: ["horizontal"]
solution: |
  ```swift ios
  import UIKit

  final class CountBadge: UIView {
      var count = 0 {
          didSet { invalidateIntrinsicContentSize() }
      }

      override var intrinsicContentSize: CGSize {
          CGSize(width: count > 99 ? 36 : 24, height: 20)
      }
  }

  let badge = CountBadge()
  let title = UILabel()
  badge.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
  title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  ```

  `invalidateIntrinsicContentSize()` tells Auto Layout to read the size again in the next layout pass. For the third blank, the badge only needs a **higher** compression resistance than the title. `.defaultHigh` (750) on the badge with the title lowered to `.defaultLow`, as above, does that without a required priority. `.required` is accepted because it works, but the guide prefers 999 or less. The axis is horizontal: they compete for width.
````

````exercise
id: m23-l03-e4
type: find-errors
prompt: "A teammate's chat header shows a contact name, a status label and a call button in a horizontal stack view. Mark every real problem in their reasoning and code."
code: |
  // "The stack keeps getting squeezed by the title next to it, so make it resist."
  headerStack.setContentCompressionResistancePriority(.required, for: .horizontal)

  // "The button must never shrink or grow."
  callButton.setContentHuggingPriority(.required, for: .horizontal)
  callButton.setContentCompressionResistancePriority(.required, for: .horizontal)

  // "Status text changes, so update it."
  final class StatusDot: UIView {
      var isOnline = false { didSet { setNeedsDisplay() } }
      override var intrinsicContentSize: CGSize {
          isOnline ? CGSize(width: 12, height: 12) : CGSize(width: 0, height: 12)
      }
  }
choices:
  - text: "CHCR priorities on a stack view have no effect, because it has no intrinsic content size."
    correct: true
  - text: "Required hugging and compression on the button turn any squeeze into an unsatisfiable layout; 999 would do the job."
    correct: true
  - text: "StatusDot changes its intrinsic size without calling invalidateIntrinsicContentSize()."
    correct: true
  - text: "intrinsicContentSize can't return a width of 0."
    correct: false
    why: Zero is a valid size. noIntrinsicMetric is for "no intrinsic size", which is different.
  - text: "setNeedsDisplay() also invalidates the intrinsic size."
    correct: false
    why: It only schedules a redraw. Layout is a separate system.
rubric:
  - I found the priorities set on the stack view.
  - I found the required CHCR priorities.
  - I found the missing invalidateIntrinsicContentSize().
solution: |
  1. **Priorities on the stack view do nothing.** Apple's guide: "Setting the stack view's CHCR priorities has no effect, because the stack view does not have an intrinsic content size." Raise the compression resistance of the views inside the stack, or lower the title's.
  2. **Required CHCR** means that on a narrow screen with a long name there's no valid solution; Auto Layout breaks a constraint you didn't choose. 999 keeps the button at its size in every normal case and gives way only in a real conflict.
  3. **`StatusDot`** must call `invalidateIntrinsicContentSize()` when `isOnline` changes. `setNeedsDisplay()` asks for a redraw, not a new layout, so the dot would draw at its old size.
````

````exercise
id: m23-l03-e5
type: solve
prompt: |
  A view has an intrinsic height, a hugging priority and a compression-resistance priority (vertical axis), and there's one optional height constraint competing with them. Write `finalHeight(intrinsic:hugging:compression:requested:priority:)` that returns the height Auto Layout ends up with, using the rule from the lesson: the higher priority wins, and an exact tie returns `nil` (ambiguous). If the requested height equals the intrinsic one, return it.

  ```swift
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 60, priority: 300) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 30, priority: 700) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 30, priority: 750) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 44, priority: 1) ?? -1)
  ```

  should print `60.0`, `44.0`, `-1.0` and `44.0`.
starter: |
  func finalHeight(intrinsic: Double, hugging: Int, compression: Int,
                   requested: Double, priority: Int) -> Double? {
      // your code
      return nil
  }
hints:
  - "Growing beyond the intrinsic height fights hugging; shrinking below it fights compression resistance."
  - "Compare the constraint's priority with the one priority it fights."
rubric:
  - Uses hugging only when the request is larger, compression resistance only when smaller.
  - Higher priority wins in each case.
  - Returns nil on an exact tie.
  - Returns the intrinsic height when there's no conflict.
solution: |
  ```swift
  func finalHeight(intrinsic: Double, hugging: Int, compression: Int,
                   requested: Double, priority: Int) -> Double? {
      if requested == intrinsic { return intrinsic }
      let opponent = requested > intrinsic ? hugging : compression
      if priority == opponent { return nil }
      return priority > opponent ? requested : intrinsic
  }

  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 60, priority: 300) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 30, priority: 700) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 30, priority: 750) ?? -1)
  print(finalHeight(intrinsic: 44, hugging: 250, compression: 750, requested: 44, priority: 1) ?? -1)
  ```

  ```output
  60.0
  44.0
  -1.0
  44.0
  ```

  A request above the intrinsic size is `height ≥ …` against hugging's `height ≤ intrinsic`; below, it's against compression's `height ≥ intrinsic`. Picking the right opponent first keeps the function to one comparison. Case 2 is the common surprise: a 700-priority height constraint looks strong but still loses to compression resistance at 750. Case 3 is a real ambiguity, which is why the guide suggests nudging priorities a point above or below the standard values.
````

````exercise
id: m23-l03-e6
type: explain
prompt: "Explain why Apple chose 250 for hugging and 750 for compression resistance by default, instead of equal values. Use a button as the example, and say what would go wrong with the defaults swapped."
rubric:
  - Hugging low means views stretch easily; compression high means they resist shrinking.
  - A stretched button still shows its whole title; a compressed one clips it.
  - With the values swapped, layouts would prefer clipping content over adding space around it.
  - Mentions that equal values would make many layouts ambiguous or arbitrary.
solution: |
  The defaults encode "growing is cheap, shrinking is expensive". A button with extra width around its title still works and still reads correctly; a button narrower than its title cuts it to "Sub…". So when a layout must give way, Auto Layout should prefer stretching (hugging gives way at 250) over compressing (resistance holds until 750). Apple's guide: "it's easier to stretch a view than it is to shrink it. For most controls, this is the desired behavior."

  Swapped, the same layout would rather clip a title than add a few points of space, and every row with spare room would fight to keep views at their natural size while happily truncating them when space ran short. Equal values would make every stretch-or-shrink decision a tie between the two rules, which is exactly the ambiguity you want to avoid.
````

## Summary

- `intrinsicContentSize` is a view's natural size from its own content. Labels, buttons, switches and fields have one on both axes; plain views have none (`noIntrinsicMetric`).
- Auto Layout turns it into two optional constraints per axis: compression resistance (size ≥ intrinsic, 750 by default) and hugging (size ≤ intrinsic, 250).
- With spare space, the lowest hugging grows; with too little, the lowest compression resistance shrinks; a tie is ambiguous. In code, labels start at 250; raise them to 251 next to a field.
- Your optional constraints compete with CHCR by priority like any others.
- Custom views override `intrinsicContentSize` and call `invalidateIntrinsicContentSize()` when it changes.
- Stack views have a fitting size, not an intrinsic one; their CHCR priorities do nothing. Don't make CHCR required; 999 is the strongest sensible value.
