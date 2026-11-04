---
id: m34-l06
title: How SwiftUI layout works
description: "SwiftUI layout is a conversation: the parent proposes a size, the child chooses its own, and the parent places it. You run a simplified model of how an HStack splits its width by flexibility and layout priority, checked against what Apple documents, and use it to predict truncation and overflow. Then you apply the same rules to frame, fixedSize and layoutPriority, learn when GeometryReader is the right tool and when containerRelativeFrame or ViewThatFits is better, pin a bar with safeAreaInset, and write a small custom Layout."
module: m34
order: 6
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l05, m23-l03]
objectives:
  - Describe SwiftUI's three layout steps (propose, choose, place) and contrast them with Auto Layout's constraint solving.
  - Predict how an HStack divides width among children with different flexibility and layout priority.
  - Use frame(width:height:), frame(maxWidth:), fixedSize() and layoutPriority(_:) on purpose.
  - Decide when GeometryReader is needed and when containerRelativeFrame, ViewThatFits or a frame does the job.
  - Add a bar above or below scrolling content with safeAreaInset(edge:).
  - Write a simple Layout with sizeThatFits and placeSubviews.
terms:
  - term: Proposed size
    definition: "The size a parent offers a child during layout. A dimension can be a number, zero, infinity, or unspecified (nil), which asks for the child's ideal size."
  - term: Ideal size
    definition: "The size a view wants when nothing constrains it: a text's single-line width, a toggle's standard size. fixedSize() makes a view use it."
  - term: Flexibility
    definition: "How much a view's size can vary between its minimum and maximum. A fixed-size icon has none, a text has some, a Color or Spacer has unlimited."
  - term: Layout priority
    definition: "A Double set with layoutPriority(_:), 0 by default. A stack offers higher-priority children space first, after reserving the minimum size of lower-priority ones."
  - term: Layout protocol
    definition: "A protocol (iOS 16) for writing your own container: sizeThatFits(proposal:subviews:cache:) reports the container's size, placeSubviews(in:proposal:subviews:cache:) positions each subview."
mastery:
  - Walk through the proposals in an HStack of an icon, a title and a price, and say which text truncates at a given width.
  - Fix a truncated price with layoutPriority or fixedSize, and explain the side effect of each.
  - "Make a view fill the available width with frame(maxWidth: .infinity, alignment: .leading)."
  - Replace a GeometryReader used only to size a view with containerRelativeFrame or a frame.
  - Add a pinned bottom bar to a ScrollView with safeAreaInset.
  - Write a Layout that gives all subviews the same width.
resources: [swiftui-laying-out-simple-view, swiftui-layoutpriority, swiftui-composing-custom-layouts, hig, uikit-scaling-fonts, swift-book-protocols]
cards:
  - id: m34-l06-c1
    front: SwiftUI layout in three steps?
    back: "The parent proposes a size to the child. The child chooses its own size, taking the proposal into account (it may ignore it). The parent places the child in its own coordinate space. Then the same happens one level down."
  - id: m34-l06-c2
    front: How does an HStack split its width?
    back: "It subtracts spacing, then offers space to its children in order of priority and, within a priority, from least flexible to most flexible, each getting an even share of what's left. Apple documents the priority rule and that stacks measure flexibility; the exact algorithm isn't documented."
  - id: m34-l06-c3
    front: What does layoutPriority(1) do in a stack?
    back: "Apple: the parent offers the highest-priority children all the space offered to the parent minus the minimum space required by its lower-priority children. The higher-priority view shrinks later and stretches sooner."
  - id: m34-l06-c4
    front: What does fixedSize() do?
    back: "Makes the view use its ideal size, ignoring the proposal, in both dimensions (or the ones you pass to fixedSize(horizontal:vertical:)). A text stops truncating or wrapping, and may overflow its parent."
  - id: m34-l06-c5
    front: When should you avoid GeometryReader?
    back: "When you only need to size a view relative to its container (use containerRelativeFrame, iOS 17, or frame), pick between layouts that fit (ViewThatFits) or react to a size change (onGeometryChange). GeometryReader takes all the space offered, which often breaks the surrounding layout."
---

## The idea in one sentence

SwiftUI layout is a negotiation that runs down the tree: **the parent proposes a size, the child chooses its own size, and the parent places the child**, which is very different from Auto Layout's set of equations solved all at once.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run, so the sizes in the text come from Apple's documentation, not from measuring a screen. The stack model is plain Swift and was run. It's a **simplified model**: the parts it follows are documented by Apple (priorities, even sharing, measuring flexibility), and the exact order of proposals inside SwiftUI's stacks isn't documented, so treat its numbers as an explanation, not a prediction of pixels.

## Propose, choose, place

Apple's article "Laying out a simple view" describes the process: "The parent view proposes a size to the child views it contains, and the child views respond with a computed size." The parent then positions each child; Apple's words for the last step are "When all child views have reported their size, the parent view renders them."

Three consequences that surprise people coming from UIKit:

1. **A child has the last word on its own size.** A parent can't force a size on a `Text`. It can only offer one. The `frame` modifier doesn't resize its view either: it creates a new view around it that has the size, and offers that size inward.
2. **Different views respond differently.** Apple lists three kinds: views that "expand to fill the space offered by their parent, like `Color`, `LinearGradient`, and `Circle`"; views with "an ideal size that varies according to their contents, like `Text` and the container views"; and views with "an ideal size that never varies, like `Toggle` or `DatePicker`."
3. **Nothing is solved globally.** Module 23's constraints were a system of equations that Auto Layout solved, with priorities, hugging and compression resistance deciding conflicts. SwiftUI makes one pass down (proposals) and one pass up (chosen sizes), container by container. Flexibility plays the role of hugging and compression resistance, and `layoutPriority` the role of constraint priorities.

```swift ios
import SwiftUI

struct ProposalExamples: View {
    var body: some View {
        VStack(spacing: 24) {
            // A text in a 200 × 200 frame: offered 200 wide, it wraps to fit.
            Text("A single line of text, too long to fit in a box.")
                .frame(width: 200, height: 200)
                .border(.gray)

            // fixedSize(): the text uses its ideal size and overflows the frame.
            Text("A single line of text, too long to fit in a box.")
                .fixedSize()
                .frame(width: 200, height: 200)
                .border(.gray)

            // A shape takes whatever it's offered: here 200 × 100.
            Ellipse()
                .fill(.purple)
                .frame(width: 200, height: 100)
        }
    }
}
```

All three come from Apple's pages for `fixedSize()` and `frame(width:height:alignment:)`. The first text "wraps and truncates its string to remain within its parent's bounds." The second, after `fixedSize()`, keeps its ideal one-line width, which "can result in the view exceeding the parent's bounds." The ellipse is 200 × 100 because "a shape always occupies the space offered to it."

## How a stack divides space

A stack's job is to split what it was offered among its children. Apple documents the pieces:

- At equal priority, space is shared evenly. `layoutPriority(_:)`: views "typically have a default priority of `0` which causes space to be apportioned evenly to all sibling views."
- Priority changes the order. Same page: "A parent layout offers the child views with the highest layout priority all the space offered to the parent minus the minimum space required for all its lower-priority children."
- Stacks measure how flexible their children are. `ProposedViewSize`: layouts measure subviews by proposing zero (minimum size), infinity (maximum size) and unspecified (ideal size), and "an `HStack` might measure the flexibility of its subviews' widths."

Here's a model that puts those together: per priority, highest first; reserve the minimum widths of lower-priority children; then offer each child an even share of what's left, least flexible first, so that a child that needs less than its share leaves the rest to the others.

```swift
/// A child of the stack, described by how wide it can be.
struct Child {
    let name: String
    let minWidth: Double
    let idealWidth: Double
    let maxWidth: Double
    var priority = 0.0

    /// The child chooses its width for a proposal; nil asks for its ideal width.
    func width(proposed: Double?) -> Double {
        guard let proposed else { return idealWidth }
        return min(max(proposed, minWidth), maxWidth)
    }

    var flexibility: Double { maxWidth - minWidth }

    static func text(_ name: String, idealWidth: Double) -> Child {
        // A text can truncate down to an ellipsis (20 points here) and never grows past its ideal width.
        Child(name: name, minWidth: 20, idealWidth: idealWidth, maxWidth: idealWidth)
    }

    static func fixed(_ name: String, width: Double) -> Child {
        Child(name: name, minWidth: width, idealWidth: width, maxWidth: width)
    }

    static func color(_ name: String) -> Child {
        Child(name: name, minWidth: 0, idealWidth: 10, maxWidth: .infinity)
    }
}

/// Proposes widths to the children and returns what each one chose.
func layoutHStack(_ children: [Child], proposedWidth: Double, spacing: Double) -> [Double] {
    var widths = Array(repeating: 0.0, count: children.count)
    var remaining = proposedWidth - spacing * Double(children.count - 1)

    // Highest priority first.
    for priority in Set(children.map(\.priority)).sorted(by: >) {
        // Lower-priority children are guaranteed at least their minimum.
        let reserved = children.filter { $0.priority < priority }.reduce(0) { $0 + $1.minWidth }
        // Within a priority, least flexible first.
        let group = children.indices
            .filter { children[$0].priority == priority }
            .sorted { children[$0].flexibility < children[$1].flexibility }
        var available = remaining - reserved
        for (position, index) in group.enumerated() {
            let share = available / Double(group.count - position)   // an even share of what's left
            let width = children[index].width(proposed: max(share, 0))
            widths[index] = width
            available -= width
            remaining -= width
        }
    }
    return widths
}

/// Places the children left to right and prints "name width@x".
func show(_ children: [Child], in width: Double, spacing: Double = 10) {
    let widths = layoutHStack(children, proposedWidth: width, spacing: spacing)
    var x = 0.0
    var parts: [String] = []
    for (child, childWidth) in zip(children, widths) {
        let note = childWidth < child.idealWidth && child.maxWidth == child.idealWidth ? " (truncated)" : ""
        parts.append("\(child.name) \(Int(childWidth.rounded()))@\(Int(x.rounded()))\(note)")
        x += childWidth + spacing
    }
    print(parts.joined(separator: ", "))
}

let icon = Child.fixed("icon", width: 30)
let title = Child.text("title", idealWidth: 200)
let price = Child.text("price", idealWidth: 60)

show([icon, title, price], in: 300)

var importantTitle = title
importantTitle.priority = 1
show([icon, importantTitle, price], in: 300)

show([Child.text("left", idealWidth: 160), Child.text("right", idealWidth: 200)], in: 300)
show([Child.text("label", idealWidth: 100), Child.color("bar")], in: 300)
```

```output
icon 30@0, title 190@40 (truncated), price 60@240
icon 30@0, title 200@40, price 50@250 (truncated)
left 145@0 (truncated), right 145@155 (truncated)
label 100@0, bar 190@110
```

Line by line through the first case, a 300-point row with 10 points of spacing:

1. Two gaps of 10 leave 280.
2. All three have priority 0. Least flexible first: the icon (0), then the price (it can vary by 40), then the title (180).
3. The icon is offered 280 ÷ 3 ≈ 93 and chooses 30. 250 left.
4. The price is offered 250 ÷ 2 = 125 and chooses its ideal 60. 190 left.
5. The title is offered all 190, less than its 200: it truncates.
6. **Place:** left to right, each child after the previous one plus spacing: x = 0, 40, 240.

With `layoutPriority(1)` on the title, the title goes first and is offered 280 minus the minimums of the others (30 + 20), so 230; it takes its full 200. The icon and price split the 80 left, and now the price is the one that truncates. That's the trade-off `layoutPriority` makes: someone else gives up space.

The third line is Apple's "apportioned evenly": two texts that both want more than half get exactly half each. The fourth shows why the order matters: the less flexible label is offered 145, takes the 100 it needs, and the infinitely flexible `Color` gets everything else.

> [!warning] What the model leaves out
> Real text wraps onto more lines when it gets less width (unless you limit lines), and its minimum width depends on the font and the text. `Spacer` has a minimum length and special treatment along a stack's axis that this model doesn't try to reproduce. Use the model to reason about *who* gets space and *why*; use a preview to see the real result.

## The tools, with the rules in mind

### frame

`frame(width:height:alignment:)` wraps the view in a new one with a fixed size in the dimensions you give. It proposes that size to the view inside, the view chooses, and the frame places it using `alignment` (center by default). In the other dimension, Apple says, "the resulting view assumes this view's sizing behavior."

`frame(minWidth:idealWidth:maxWidth:…)` gives the frame flexible bounds. The most used form by far is `maxWidth: .infinity`:

```swift ios
import SwiftUI

struct Banner: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Offline")
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)   // as wide as offered, text on the left
                .background(.yellow)

            Text("Offline")
                .padding(8)
                .background(.yellow)                               // only as wide as the text
        }
        .padding()
    }
}
```

Apple's rule for this frame: if a maximum is specified "and the size proposed for the frame by the parent is greater than the size of this view," the frame's size is "the proposed size, clamped to that maximum." With an infinite maximum, the frame takes the full proposed width, and the text sits inside it at the leading edge. Order matters as in lesson 2: the background comes after the frame, so it fills the full width.

### fixedSize

`fixedSize()` makes a view use its ideal size, whatever it's offered. Apple calls it "a counter proposal to the view size proposed to a view by its parent." In the model, it's a child whose minimum and maximum both equal its ideal: zero flexibility. Use it for a short value that must never truncate, like a price or a badge, and use `fixedSize(horizontal: false, vertical: true)` for the common case of a text that should wrap to as many lines as it needs instead of truncating vertically in a tight container.

The side effect is that the view can overflow its parent. If everything in a row is fixed, the row is wider than the screen.

### layoutPriority

`layoutPriority(1)` on the view that matters most lets it take space first, at the expense of its lower-priority siblings, which still get their minimum. Apple's example on the `layoutPriority(_:)` page puts two long texts in an `HStack` and gives the second priority 1: the first "shrink[s] dramatically due to the higher priority of the second."

```swift ios
import SwiftUI

struct OrderRow: View {
    let product: String
    let price: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(product)
                .lineLimit(2)
            Spacer()
            Text(price)
                .bold()
                .layoutPriority(1)
        }
    }
}
```

The price gets its full width first; the product name shrinks, and with `lineLimit(2)` it wraps to two lines before it truncates. `fixedSize()` on the price would also work; the difference is that `fixedSize()` never lets the price shrink even if the row can't fit it, while priority still lets the stack squeeze it as a last resort.

## GeometryReader, and what to use instead

`GeometryReader` gives its content closure a `GeometryProxy` with the reader's `size` (and its frame in other coordinate spaces), so you can compute layout from it. Apple's page has one sentence about its own sizing: "This view returns a flexible preferred size to its parent layout." In practice it takes all the space offered, like a `Color`. Inside a `VStack` or a `ScrollView` row, that means it expands and pushes everything else around, which is the usual surprise.

It's the right tool when you really need a number to compute with, such as drawing a chart or a custom progress bar:

```swift ios
import SwiftUI

struct BudgetBar: View {
    let spent: Double     // 0...1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(spent > 0.9 ? Color.red : Color.green)
                    .frame(width: proxy.size.width * min(max(spent, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue("\(Int((spent * 100).rounded())) percent")
    }
}
```

The `.frame(height: 8)` on the reader is what keeps it from taking all the vertical space too. (For a plain progress indicator, `ProgressView(value:)` already exists; this is a custom one.)

Often you don't need the number:

| You want | Use |
| --- | --- |
| A view filling the width | `frame(maxWidth: .infinity)` |
| A view sized relative to its scroll view, screen or column | `containerRelativeFrame` (iOS 17) |
| One layout when there's room, another when there isn't | `ViewThatFits` (iOS 16) |
| To react when a view's size changes | `onGeometryChange(for:of:action:)` |
| A custom arrangement of several views | A `Layout` |

```swift ios
import SwiftUI

struct CardCarousel: View {
    let titles: [String]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
                        .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 12)
                }
            }
            .padding(.horizontal)
        }
    }
}
```

`containerRelativeFrame(_:count:span:spacing:)` sizes each card from the size of "the nearest container" (here the scroll view), minus safe area insets. Apple gives the formula: the width is divided into `count` columns after subtracting spacing, and the view takes `span` of them. With 5 and 4, each card takes four fifths of the width, so the next card peeks in. No `GeometryReader`, and no layout pass that depends on reading a size and writing it back.

`ViewThatFits` "evaluates its child views in the order you provide them" and "selects the first child whose ideal size on the constrained axes fits within the proposed size." Give it a horizontal arrangement first and a vertical one second, and it switches at large text sizes on its own, which is what Module 23 did by hand with trait collections.

## safeAreaInset

A bar pinned below scrolling content needs two things: to stay at the bottom, and to make the content scrollable *past* it so the last row isn't hidden underneath. `safeAreaInset(edge:)` does both:

```swift ios
import SwiftUI

struct CartScreen: View {
    let items: [String]

    var body: some View {
        List(items, id: \.self) { item in
            Text(item)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Check out") {}
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
        }
    }
}
```

Apple's description: the content view "is anchored to the specified vertical edge," and the modified view "is inset by the height of `content`, from `edge`, with its safe area increased by the same amount." Because the list's safe area grows, its last row can scroll above the button. Compare Module 23, where you changed `additionalSafeAreaInsets` or content insets yourself. (`ignoresSafeArea()` is the opposite tool: it lets a background extend under the status bar or home indicator.)

## The Layout protocol, briefly

When no combination of stacks, grids and frames gives the arrangement you need, write a container. `Layout` (iOS 16) has two required methods: `sizeThatFits(proposal:subviews:cache:)` answers "how big are you for this proposal?", and `placeSubviews(in:proposal:subviews:cache:)` positions each subview. They're the "choose" and "place" steps, written by you. This is a trimmed version of the equal-width stack from Apple's sample "Composing custom layouts with SwiftUI":

```swift ios
import SwiftUI

struct EqualWidthHStack: Layout {
    private var spacing: CGFloat { 8 }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let largest = largestIdealSize(of: subviews)
        let totalSpacing = spacing * CGFloat(subviews.count - 1)
        return CGSize(width: largest.width * CGFloat(subviews.count) + totalSpacing,
                      height: largest.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let largest = largestIdealSize(of: subviews)
        let itemProposal = ProposedViewSize(width: largest.width, height: largest.height)
        var x = bounds.minX + largest.width / 2
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .center, proposal: itemProposal)
            x += largest.width + spacing
        }
    }

    private func largestIdealSize(of subviews: Subviews) -> CGSize {
        subviews
            .map { $0.sizeThatFits(.unspecified) }
            .reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
    }
}

struct VoteButtons: View {
    var body: some View {
        ViewThatFits {
            EqualWidthHStack {
                Button("Cat") {}
                Button("Goldfish") {}
                Button("Dog") {}
            }
            VStack {
                Button("Cat") {}
                Button("Goldfish") {}
                Button("Dog") {}
            }
        }
        .buttonStyle(.bordered)
    }
}
```

- **Measuring.** `sizeThatFits(.unspecified)` asks each subview for its ideal size, the "unspecified" proposal from `ProposedViewSize`. The widest one sets everybody's width.
- **Choosing.** `sizeThatFits` returns the container's size: the widest width times the count, plus spacing.
- **Placing.** `placeSubviews` calls `place(at:anchor:proposal:)` on each subview proxy, centered in its slot, with the widest size as its proposal so every button is equally wide.
- **`cache: inout ()`** means no cache. Apple's sample adds one to the vertical version to avoid measuring twice.

You'll rarely need this. When you do, the propose-choose-place model is the whole API.

## Common mistakes

> [!error] Trying to force a child's size from outside
> `Text(name).frame(width: 50)` doesn't make the text 50 wide in every sense: it puts the text in a 50-point frame, and the text wraps or truncates to fit, or overflows if it's fixed. Know which of the two views you're sizing.

> [!error] GeometryReader to make something fill the width
> It takes all the space offered in *both* directions and changes the layout around it. `frame(maxWidth: .infinity)` or `containerRelativeFrame` is what you want.

> [!error] fixedSize on everything that truncates
> Each `fixedSize()` removes flexibility. With two or three in a row, the row is wider than the screen on a small phone or at large text sizes. Use `layoutPriority` or `lineLimit` first, and test at the largest Dynamic Type size.

> [!error] A bottom bar in a ZStack over a list
> The bar covers the last rows, which can't scroll out from under it. `safeAreaInset(edge: .bottom)` moves the list's safe area so they can.

> [!error] Thinking in constraints
> There's no "pin the leading edge to…" in SwiftUI. Ask: what does the parent offer, what does this view choose, and where does the parent put it?

## Exercises

````exercise
id: m34-l06-e1
type: prediction
prompt: "The stack model from the lesson, with a fixed-size title in a narrow row. What does it print?"
code: |
  struct Child {
      let name: String
      let minWidth: Double
      let idealWidth: Double
      let maxWidth: Double
      var priority = 0.0

      func width(proposed: Double?) -> Double {
          guard let proposed else { return idealWidth }
          return min(max(proposed, minWidth), maxWidth)
      }

      var flexibility: Double { maxWidth - minWidth }

      static func text(_ name: String, idealWidth: Double) -> Child {
          Child(name: name, minWidth: 20, idealWidth: idealWidth, maxWidth: idealWidth)
      }

      /// fixedSize(): the child keeps its ideal width whatever it's offered.
      func fixedSize() -> Child {
          Child(name: name, minWidth: idealWidth, idealWidth: idealWidth, maxWidth: idealWidth, priority: priority)
      }
  }

  func layoutHStack(_ children: [Child], proposedWidth: Double, spacing: Double) -> [Double] {
      var widths = Array(repeating: 0.0, count: children.count)
      var remaining = proposedWidth - spacing * Double(children.count - 1)
      for priority in Set(children.map(\.priority)).sorted(by: >) {
          let reserved = children.filter { $0.priority < priority }.reduce(0) { $0 + $1.minWidth }
          let group = children.indices
              .filter { children[$0].priority == priority }
              .sorted { children[$0].flexibility < children[$1].flexibility }
          var available = remaining - reserved
          for (position, index) in group.enumerated() {
              let share = available / Double(group.count - position)
              let width = children[index].width(proposed: max(share, 0))
              widths[index] = width
              available -= width
              remaining -= width
          }
      }
      return widths
  }

  let row = [Child.text("title", idealWidth: 200).fixedSize(), Child.text("price", idealWidth: 60)]
  let widths = layoutHStack(row, proposedWidth: 200, spacing: 10)
  print(widths.map { Int($0) })
  print("row width:", Int(widths.reduce(0, +) + 10))
output: |
  [200, 20]
  row width: 230
hints:
  - "The fixed title has zero flexibility, so it's offered space first."
  - "It's offered 190 ÷ 2 = 95, but its minimum is 200."
  - "Nothing is left for the price, which falls back to its minimum."
solution: |
  ```output
  [200, 20]
  row width: 230
  ```

  The row has 200 − 10 = 190 to share. The fixed title is least flexible, so it goes first; it's offered 95 and takes 200 anyway, because `fixedSize()` made its minimum its ideal. That leaves −10, so the price is offered 0 and takes its minimum of 20, truncated to an ellipsis. The children need 230 points in a 200-point row: the row overflows by 30. That's the side effect of `fixedSize()` the lesson warns about.
````

````exercise
id: m34-l06-e2
type: prediction
prompt: "Three texts with three different priorities, in the lesson's model. Predict the widths."
code: |
  struct Child {
      let name: String
      let minWidth: Double
      let idealWidth: Double
      let maxWidth: Double
      var priority = 0.0

      func width(proposed: Double?) -> Double {
          guard let proposed else { return idealWidth }
          return min(max(proposed, minWidth), maxWidth)
      }

      var flexibility: Double { maxWidth - minWidth }

      static func text(_ name: String, idealWidth: Double, priority: Double) -> Child {
          Child(name: name, minWidth: 20, idealWidth: idealWidth, maxWidth: idealWidth, priority: priority)
      }
  }

  func layoutHStack(_ children: [Child], proposedWidth: Double, spacing: Double) -> [Double] {
      var widths = Array(repeating: 0.0, count: children.count)
      var remaining = proposedWidth - spacing * Double(children.count - 1)
      for priority in Set(children.map(\.priority)).sorted(by: >) {
          let reserved = children.filter { $0.priority < priority }.reduce(0) { $0 + $1.minWidth }
          let group = children.indices
              .filter { children[$0].priority == priority }
              .sorted { children[$0].flexibility < children[$1].flexibility }
          var available = remaining - reserved
          for (position, index) in group.enumerated() {
              let share = available / Double(group.count - position)
              let width = children[index].width(proposed: max(share, 0))
              widths[index] = width
              available -= width
              remaining -= width
          }
      }
      return widths
  }

  let children = [
      Child.text("subtitle", idealWidth: 150, priority: 0),
      Child.text("name", idealWidth: 180, priority: 2),
      Child.text("date", idealWidth: 90, priority: 1),
  ]
  for (child, width) in zip(children, layoutHStack(children, proposedWidth: 300, spacing: 10)) {
      print(child.name, Int(width))
  }
output: |
  subtitle 20
  name 180
  date 80
hints:
  - "After spacing, 280 is left. Priority 2 goes first, reserving 20 + 20 for the other two."
  - "Then priority 1: 100 is left, minus 20 reserved for the subtitle."
  - "The subtitle gets whatever is left, but never less than its minimum."
solution: |
  ```output
  subtitle 20
  name 180
  date 80
  ```

  280 points after spacing. The name (priority 2) is offered 280 − 40 = 240 and takes its 180. 100 left. The date (priority 1) is offered 100 − 20 = 80, less than its 90: it truncates to 80. 20 left, and the subtitle (priority 0) is offered 20, its minimum: an ellipsis. Priority decides who gives way: the subtitle almost disappears, the date loses 10 points, and the name is untouched. The order in the code (subtitle first) doesn't matter; only priority and flexibility do.
````

````exercise
id: m34-l06-e3
type: comprehension
prompt: "You want a hero image to be exactly half as wide as the scroll view it's in, on any device, with a 16:9 aspect ratio. Which approach fits best on iOS 17?"
choices:
  - text: "containerRelativeFrame(.horizontal) { width, _ in width / 2 } followed by aspectRatio(16 / 9, contentMode: .fit)."
    correct: true
    why: "It sizes from the nearest container directly, without a GeometryReader taking over the layout."
  - text: "Wrap the image in a GeometryReader and set frame(width: proxy.size.width / 2)."
    correct: false
    why: "It works for the width, but the reader takes all the space it's offered, including vertically in a scroll view, and you then have to fix the layout around it."
  - text: "frame(width: UIScreen.main.bounds.width / 2)."
    correct: false
    why: "The screen isn't the container: it ignores split view, the scroll view's insets and other windows."
  - text: "fixedSize() on the image."
    correct: false
    why: "fixedSize() makes it use its ideal size, which is the image's natural pixel size."
solution: |
  **`containerRelativeFrame`.** Its closure receives the container's length on the axis (minus safe area insets) and returns the size to use, so `width / 2` is exactly "half the container". `aspectRatio` then derives the height. A `GeometryReader` can compute the same width but changes how the image participates in layout, and screen bounds are the wrong measure on iPad.

  ```swift ios
  import SwiftUI

  struct Hero: View {
      var body: some View {
          ScrollView {
              Image(systemName: "photo")
                  .resizable()
                  .scaledToFill()
                  .containerRelativeFrame(.horizontal) { width, _ in width / 2 }
                  .aspectRatio(16 / 9, contentMode: .fit)
                  .clipped()
          }
      }
  }
  ```
````

````exercise
id: m34-l06-e4
type: solve
prompt: |
  Model `frame(width:alignment:)` for one dimension in plain Swift. The frame always reports the width you give it (Apple: "a view with fixed dimensions"). It proposes that width to its child, the child chooses its own width (use the `Child.width(proposed:)` rule from the lesson), and the frame places the child according to alignment.

  Write `fixedFrame(_ child: Child, width: Double, alignment: Alignment) -> (frameWidth: Double, childWidth: Double, childX: Double)` where `childX` is the child's left edge inside the frame. A child wider than the frame (a fixed-size one) gets a negative `childX` when centered, because it overflows on both sides.

  Then run:

  ```swift
  let label = Child(minWidth: 20, idealWidth: 80, maxWidth: 80)
  let long = Child(minWidth: 20, idealWidth: 300, maxWidth: 300)
  let fixedLong = Child(minWidth: 300, idealWidth: 300, maxWidth: 300)
  for (name, child) in [("label", label), ("long", long), ("fixedLong", fixedLong)] {
      for alignment in [Alignment.leading, .center, .trailing] {
          let result = fixedFrame(child, width: 200, alignment: alignment)
          print(name, alignment, Int(result.frameWidth), Int(result.childWidth), Int(result.childX))
      }
  }
  ```
starter: |
  struct Child {
      let minWidth: Double
      let idealWidth: Double
      let maxWidth: Double

      func width(proposed: Double?) -> Double {
          guard let proposed else { return idealWidth }
          return min(max(proposed, minWidth), maxWidth)
      }
  }

  enum Alignment {
      case leading, center, trailing
  }

  func fixedFrame(_ child: Child, width: Double, alignment: Alignment) -> (frameWidth: Double, childWidth: Double, childX: Double) {
      // your code
      (width, 0, 0)
  }
hints:
  - "childWidth = child.width(proposed: width)."
  - "leading: x = 0; trailing: x = width − childWidth; center: x = (width − childWidth) / 2."
rubric:
  - Proposes the frame's width to the child and uses the child's choice.
  - Always returns the frame's own width as frameWidth.
  - Computes x for the three alignments, including a negative x for an overflowing child.
  - Prints nine lines that match the expected output.
solution: |
  ```swift
  struct Child {
      let minWidth: Double
      let idealWidth: Double
      let maxWidth: Double

      func width(proposed: Double?) -> Double {
          guard let proposed else { return idealWidth }
          return min(max(proposed, minWidth), maxWidth)
      }
  }

  enum Alignment {
      case leading, center, trailing
  }

  func fixedFrame(_ child: Child, width: Double, alignment: Alignment) -> (frameWidth: Double, childWidth: Double, childX: Double) {
      let childWidth = child.width(proposed: width)          // propose; the child chooses
      let x: Double
      switch alignment {                                      // place
      case .leading: x = 0
      case .center: x = (width - childWidth) / 2
      case .trailing: x = width - childWidth
      }
      return (width, childWidth, x)                           // the frame's own size is fixed
  }

  let label = Child(minWidth: 20, idealWidth: 80, maxWidth: 80)
  let long = Child(minWidth: 20, idealWidth: 300, maxWidth: 300)
  let fixedLong = Child(minWidth: 300, idealWidth: 300, maxWidth: 300)
  for (name, child) in [("label", label), ("long", long), ("fixedLong", fixedLong)] {
      for alignment in [Alignment.leading, .center, .trailing] {
          let result = fixedFrame(child, width: 200, alignment: alignment)
          print(name, alignment, Int(result.frameWidth), Int(result.childWidth), Int(result.childX))
      }
  }
  ```

  ```output
  label leading 200 80 0
  label center 200 80 60
  label trailing 200 80 120
  long leading 200 200 0
  long center 200 200 0
  long trailing 200 200 0
  fixedLong leading 200 300 0
  fixedLong center 200 300 -50
  fixedLong trailing 200 300 -100
  ```

  The frame is 200 wide in every case: that's what `frame(width:)` promises its parent. A short label keeps its 80 points and alignment decides where it sits, which is Apple's note that alignment has "no apparent effect when the size of the frame happens to match that of this view." A long text accepts 200 and wraps or truncates, so alignment doesn't move it. A fixed-size text insists on 300 and spills out of the frame, 50 points on each side when centered: the overflow in Apple's `fixedSize()` example.
````

````exercise
id: m34-l06-e5
type: fill-in
prompt: "Complete the screen so the Send bar stays at the bottom and the last message can scroll above it, and the bar spans the full width."
code: |
  struct ChatScreen: View {
      let messages: [String]
      @State private var draft = ""

      var body: some View {
          ScrollView {
              LazyVStack(alignment: .leading) {
                  ForEach(messages, id: \.self) { Text($0) }
              }
          }
          .[[1]](edge: .[[2]], spacing: 0) {
              HStack {
                  TextField("Message", text: $draft)
                  Button("Send") {}
              }
              .padding()
              .frame([[3]]: .infinity)
              .background(.bar)
          }
      }
  }
blanks:
  - id: "1"
    answers: ["safeAreaInset"]
  - id: "2"
    answers: ["bottom"]
  - id: "3"
    answers: ["maxWidth"]
hints:
  - "The modifier that adds content at an edge and grows the safe area by its height."
  - "A frame with an infinite maximum takes the full width it's offered."
solution: |
  ```swift ios
  import SwiftUI

  struct ChatScreen: View {
      let messages: [String]
      @State private var draft = ""

      var body: some View {
          ScrollView {
              LazyVStack(alignment: .leading) {
                  ForEach(messages, id: \.self) { Text($0) }
              }
          }
          .safeAreaInset(edge: .bottom, spacing: 0) {
              HStack {
                  TextField("Message", text: $draft)
                  Button("Send") {}
              }
              .padding()
              .frame(maxWidth: .infinity)
              .background(.bar)
          }
      }
  }
  ```

  `safeAreaInset(edge: .bottom)` anchors the bar to the bottom and enlarges the scroll view's safe area by the bar's height, so the last message can scroll above it. `frame(maxWidth: .infinity)` before `.background(.bar)` makes the bar's background span the width. (Real chat messages would be `Identifiable`, not identified by their text: lesson 5.)
````

````exercise
id: m34-l06-e6
type: explain
prompt: "Explain to a UIKit developer, in four or five sentences, how SwiftUI decides the width of each view in this row, and what layoutPriority(1) changes. Compare with hugging and compression resistance from Module 23."
code: |
  HStack {
      Image(systemName: "doc")
      Text(fileName)
      Spacer()
      Text(fileSize)
          .layoutPriority(1)
  }
rubric:
  - Describes the parent proposing, the child choosing and the parent placing.
  - Says the stack shares space among children, less flexible ones first, and that the Spacer takes what's left.
  - Says layoutPriority(1) makes the stack offer the size text space before the others, after reserving their minimums.
  - Maps flexibility and priority to hugging/compression resistance and constraint priorities.
solution: |
  A sample answer: "The `HStack` is offered a width by its parent. It subtracts spacing and offers each child a share of what's left; each child chooses its own width and the stack places them left to right. The icon has a fixed size, the texts can be anywhere between an ellipsis and their full width, and the `Spacer` is infinitely flexible, so it ends up with whatever is left over. `layoutPriority(1)` on the size text makes the stack offer it space first, keeping only the minimum widths for the others, so when the row is tight the file name truncates instead of the size. In Auto Layout terms, a view's flexibility plays the role of hugging and compression resistance, and `layoutPriority` is like raising the size label's compression resistance above the name's, except that nothing is solved as a system: it's one proposal pass down and one size answer back up."
````

## Summary

- Layout runs top-down: the parent proposes a size, the child chooses its own, the parent places it. A child can't be forced to a size; `frame` adds a new view that has the size.
- Views respond differently: shapes and colors take what they're offered, text and containers fit their content, some controls have a fixed ideal size.
- A stack splits its width by priority (highest first, after reserving lower priorities' minimums) and shares evenly, least flexible first. Apple documents the priority rule and even sharing; the stack model here is a simplified explanation.
- `frame(maxWidth: .infinity)` fills the width; `fixedSize()` uses the ideal size and may overflow; `layoutPriority(_:)` decides who gives way.
- Use `GeometryReader` when you need a size to compute with. Otherwise prefer `frame`, `containerRelativeFrame` (iOS 17), `ViewThatFits` or `onGeometryChange`.
- `safeAreaInset(edge:)` pins a bar and grows the content's safe area so nothing hides behind it.
- A custom `Layout` implements the same two steps: `sizeThatFits` chooses the container's size, `placeSubviews` positions each subview.
