---
id: m39-l01
title: Writing a custom Layout
description: "Module 34 showed the Layout protocol on a small equal-width stack. Here you write a real container: a flow layout that wraps tags onto lines. You model its arithmetic in plain Swift and run it against the three special proposals, then write the SwiftUI version with a cache, a custom layout value set through LayoutValueKey, line alignment and preferred spacing, and switch between it and a VStackLayout with AnyLayout without losing state."
module: m39
order: 1
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l06, m34-l06]
objectives:
  - State the contract between sizeThatFits and placeSubviews, including what bounds and proposal mean in each call.
  - Answer the zero, infinity and unspecified proposals correctly in a container of your own.
  - Write a flow layout that wraps subviews onto lines, with alignment, spacing and line spacing.
  - Decide when a layout cache is worth it, and keep it limited to data derived from the subviews.
  - Pass per-view information to a layout with LayoutValueKey and layoutValue(key:value:).
  - Switch between a custom layout and a built-in one with AnyLayout while keeping subview state.
terms:
  - term: Layout contract
    definition: "The rule that placeSubviews must agree with sizeThatFits: SwiftUI places the container in bounds whose size you returned for one of the proposals, and passes that same proposal to placeSubviews."
  - term: Flow layout
    definition: "A container that places subviews left to right and starts a new line when the next one doesn't fit, like words in a paragraph. SwiftUI has no built-in one; you write it with Layout."
  - term: Layout cache
    definition: "Storage you create in makeCache(subviews:) and receive as an inout parameter in the other Layout methods. SwiftUI calls updateCache(_:subviews:) when the layout or its subviews change; by default that rebuilds the cache with makeCache."
  - term: LayoutValueKey
    definition: "A protocol for a custom per-view value that a layout can read. You declare a key with a defaultValue, set it with layoutValue(key:value:) and read it with subview[Key.self]."
  - term: ViewSpacing
    definition: "A view's preferred spacing on each edge. distance(to:along:) returns the larger of the two preferences on the edges where two views meet."
mastery:
  - Run the flow model by hand for a list of widths and a proposed width, and give the container's size and each item's position.
  - Explain what your layout should return for a proposal of zero, infinity and nil width.
  - Write a Layout that uses bounds.minX and bounds.minY, never zero, as the origin for placement.
  - Add a cache to a layout and say what goes in it and what doesn't.
  - Add a flowLineBreak() modifier backed by a LayoutValueKey.
  - Swap a FlowLayout for a VStackLayout at accessibility text sizes with AnyLayout.
resources: [swiftui-layout, swiftui-layoutvaluekey, swiftui-composing-custom-layouts, swiftui-laying-out-simple-view, swiftui-layoutpriority, swift-book-protocols]
cards:
  - id: m39-l01-c1
    front: What does placeSubviews(in:proposal:subviews:cache:) receive?
    back: "bounds: the region the parent gave the container, in the parent's coordinate space, sized from a value your sizeThatFits returned. proposal: the proposal that produced that size. Place each subview inside bounds, starting at bounds.minX and bounds.minY, never at zero."
  - id: m39-l01-c2
    front: What should a container return for the zero, infinity and unspecified proposals?
    back: "Apple: respond to zero with the layout's minimum size, to infinity with its maximum size, and to unspecified (nil dimensions) with its ideal size. A parent may ask several times, one dimension at a time, before it places the container."
  - id: m39-l01-c3
    front: When should a Layout have a cache?
    back: "Apple: only if profiling shows it helps. SwiftUI already reuses layout results and subview measurements. A cache fits repeated intermediate calculations, many LayoutValueKey reads, or reusable working storage, and must hold only data derived from the layout and its subviews."
  - id: m39-l01-c4
    front: How does a view tell a custom layout something about itself?
    back: "Declare a type conforming to LayoutValueKey with a static defaultValue, set it on the view with layoutValue(key:value:) (usually wrapped in a View extension), and read it in the layout with subview[Key.self]."
  - id: m39-l01-c5
    front: Why use AnyLayout instead of if/else between two containers?
    back: "AnyLayout changes the arrangement while the subviews keep their identity, so their state survives and the change can animate. Two branches of an if are two different positions: the subviews are destroyed and recreated."
---

## The idea in one sentence

A custom `Layout` is two functions over the same arithmetic: **`sizeThatFits` answers "how big would you be for this proposal?"** and **`placeSubviews` puts every subview where that answer assumed it would go**, and almost every layout bug is the two disagreeing.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so no pixel in this lesson was measured on a screen. Behavior is quoted from Apple's pages for `Layout`, `sizeThatFits(proposal:subviews:cache:)`, `placeSubviews(in:proposal:subviews:cache:)`, `makeCache(subviews:)`, `updateCache(_:subviews:)`, `spacing(subviews:cache:)`, `LayoutSubview`, `LayoutValueKey`, `ViewSpacing`, `ProposedViewSize` and `AnyLayout`, read in November 2026. The flow, cache and grid models are plain Swift, compiled and run with Swift 6.3. They model the arithmetic of the container, not SwiftUI's internals.

## The contract, in detail

Module 34, lesson 6 wrote `EqualWidthHStack` and described layout as propose, choose, place. Writing a container of your own means you're now on both sides of that conversation: your parent proposes to you, and you propose to your subviews. Apple's pages for the two required methods spell out what each call means.

**`sizeThatFits(proposal:subviews:cache:)`** can be called several times in one layout pass. Apple: the parent "might call this method more than once with different proposals to learn more about the container's flexibility before deciding which proposal to use for placement." It lists the special proposals and the answer each expects:

| Proposal | Meaning | Your answer |
| --- | --- | --- |
| `.zero` | How small can you get? | The layout's minimum size |
| `.infinity` | How big can you get? | The layout's maximum size |
| `.unspecified` (both dimensions `nil`) | What would you like? | The layout's ideal size |
| A concrete width, `nil` height | You have this width; how tall? | The size for that width |

The parent "might also choose to test flexibility in one dimension at a time," so `proposal.width` and `proposal.height` are independent `CGFloat?` values. Whatever you return is final: "SwiftUI views choose their own size, so the layout engine always uses a value that you return from this method as the actual size of the composite view."

**`placeSubviews(in:proposal:subviews:cache:)`** runs after the parent has decided. Two parameters matter:

- `bounds` is "the region that the container view's parent allocates to the container view, specified in the parent's coordinate space." Its size "matches a size that your container previously returned." Its **origin is generally not zero**: place from `bounds.minX` and `bounds.minY`.
- `proposal` is "the size proposal from which the container generated the size that the parent used to create the `bounds` parameter."

And the rule that ties them together, from the same page: "if you add spacing during placement, make sure your implementation of `sizeThatFits(proposal:subviews:cache:)` accounts for the extra space. Similarly, if the sizing method returns different values for different size proposals, make sure the placement method responds to its `proposal` input in the same way."

Two more facts from `LayoutSubview.place(at:anchor:proposal:)`: call it only from `placeSubviews`, and "if you don't call this method for a subview, the subview appears at the center of its layout container and uses the layout container's size proposal." A forgotten subview doesn't vanish; it lands in the middle.

## A flow layout, modeled first

A flow layout (tags, chips, filter tokens) puts subviews left to right and wraps to a new line when the next one doesn't fit. SwiftUI doesn't ship one. Before writing it against SwiftUI, here is its arithmetic in plain Swift, so you can run it and see what it answers for every kind of proposal.

```swift
/// A model of a flow layout's arithmetic in plain Swift. Not SwiftUI's code.
struct Item {
    let name: String
    let width: Double
    let height: Double
    var breakBefore = false          // stands in for a LayoutValueKey, later in the lesson
}

enum LineAlignment { case leading, center, trailing }

struct FlowModel {
    var alignment = LineAlignment.leading
    var spacing = 8.0                // between items on a line
    var lineSpacing = 8.0            // between lines

    /// Greedy line breaking. maxWidth nil is an unspecified proposal: everything on one line.
    func breakLines(_ items: [Item], maxWidth: Double?) -> [[Int]] {
        var lines: [[Int]] = []
        var current: [Int] = []
        var x = 0.0
        for (index, item) in items.enumerated() {
            let needed = current.isEmpty ? item.width : x + spacing + item.width
            let overflows = maxWidth.map { needed > $0 } ?? false
            if !current.isEmpty && (overflows || item.breakBefore) {
                lines.append(current)
                current = [index]
                x = item.width
            } else {
                current.append(index)
                x = needed
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    func width(of line: [Int], _ items: [Item]) -> Double {
        line.reduce(0) { $0 + items[$1].width } + spacing * Double(line.count - 1)
    }

    func height(of line: [Int], _ items: [Item]) -> Double {
        line.map { items[$0].height }.max() ?? 0
    }

    /// sizeThatFits: the widest line, and the lines' heights plus line spacing.
    func sizeThatFits(_ items: [Item], proposedWidth: Double?) -> (width: Double, height: Double) {
        let lines = breakLines(items, maxWidth: proposedWidth)
        let widest = lines.map { width(of: $0, items) }.max() ?? 0
        let heights = lines.reduce(0) { $0 + height(of: $1, items) }
        return (widest, heights + lineSpacing * Double(max(lines.count - 1, 0)))
    }

    /// placeSubviews: breaks lines with the same proposal, positions inside bounds.
    func place(_ items: [Item], proposedWidth: Double?, boundsX: Double, boundsY: Double, boundsWidth: Double) -> [String] {
        var placements: [String] = []
        var y = boundsY
        for line in breakLines(items, maxWidth: proposedWidth) {
            let free = boundsWidth - width(of: line, items)
            var x: Double
            switch alignment {
            case .leading: x = boundsX
            case .center: x = boundsX + free / 2
            case .trailing: x = boundsX + free
            }
            let lineHeight = height(of: line, items)
            for index in line {
                let item = items[index]
                let top = y + (lineHeight - item.height) / 2      // centered on the line
                placements.append("\(item.name)@\(Int(x)),\(Int(top))")
                x += item.width + spacing
            }
            y += lineHeight + lineSpacing
        }
        return placements
    }
}

let tags = [
    Item(name: "Swift", width: 60, height: 30),
    Item(name: "SwiftUI", width: 80, height: 30),
    Item(name: "Concurrency", width: 120, height: 30),
    Item(name: "Testing", width: 70, height: 30),
    Item(name: "iOS", width: 40, height: 30),
]

let flow = FlowModel()
for proposal in [nil, 0, 250, Double.infinity] as [Double?] {
    let size = flow.sizeThatFits(tags, proposedWidth: proposal)
    let label = proposal.map { $0.isInfinite ? "infinity" : String(Int($0)) } ?? "nil"
    print("proposed \(label): \(Int(size.width)) × \(Int(size.height)), lines \(flow.breakLines(tags, maxWidth: proposal).map { $0.count })")
}

let size = flow.sizeThatFits(tags, proposedWidth: 250)
print(flow.place(tags, proposedWidth: 250, boundsX: 16, boundsY: 100, boundsWidth: size.width).joined(separator: " "))

var centered = flow
centered.alignment = .center
print(centered.place(tags, proposedWidth: 250, boundsX: 16, boundsY: 100, boundsWidth: size.width).joined(separator: " "))
```

```output
proposed nil: 402 × 30, lines [5]
proposed 0: 120 × 182, lines [1, 1, 1, 1, 1]
proposed 250: 246 × 68, lines [2, 3]
proposed infinity: 402 × 30, lines [5]
Swift@16,100 SwiftUI@84,100 Concurrency@16,138 Testing@144,138 iOS@222,138
Swift@65,100 SwiftUI@133,100 Concurrency@16,138 Testing@144,138 iOS@222,138
```

Read the four sizes as the answers to Apple's table:

- **`nil` (ideal):** everything on one line, 402 points wide. A flow layout would like to be a single row.
- **`0` (minimum):** each tag on its own line. The width is 120, wider than the proposal, because the widest tag can't shrink in this model. That's allowed: you report what you need, and the parent decides what to do about the overflow.
- **`250`:** two lines, `[2, 3]`. The second line is 120 + 8 + 70 + 8 + 40 = 246, so the container reports 246 wide, not 250. It **hugs** its content, like an `HStack`.
- **`infinity` (maximum):** same as ideal. A flow layout doesn't grow past one line, so its maximum width is its ideal width.

The placement lines use `bounds` at (16, 100), the way a parent with padding would place it. Every x starts at 16, every y at 100. With centered alignment, the first line (148 wide) gets half of the 98 spare points on its left: x = 16 + 49 = 65.

> [!note] Why line breaking uses the proposal and alignment uses bounds
> `place` breaks lines with `proposedWidth`, exactly as `sizeThatFits` did, because Apple asks the placement method to respond to `proposal` "in the same way." It aligns lines within `boundsWidth`, because that's the space the container actually got. Breaking lines with `bounds.width` instead happens to give the same lines for a greedy algorithm, but it relies on floating-point sums matching exactly, and it stops being true as soon as the algorithm gets smarter.

## The SwiftUI version

Now the same container against the real protocol. It adds two things the model only hinted at: a **cache** for measurements, and a **layout value** that forces a line break before a specific view.

```swift ios
import SwiftUI

/// A per-view flag the flow layout reads: start a new line before this view.
private struct FlowLineBreak: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    func flowLineBreak(_ breaks: Bool = true) -> some View {
        layoutValue(key: FlowLineBreak.self, value: breaks)
    }
}

enum LineAlignment {
    case leading, center, trailing
}

struct FlowLayout: Layout {
    var alignment = LineAlignment.leading
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    struct Cache {
        var sizes: [CGSize]
        var breaks: [Bool]
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) },
              breaks: subviews.map { $0[FlowLineBreak.self] })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let lines = breakLines(maxWidth: proposal.width, cache: cache)
        let width = lines.map { lineWidth($0, cache: cache) }.max() ?? 0
        let height = lines.reduce(0) { $0 + lineHeight($1, cache: cache) }
            + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        var y = bounds.minY
        for line in breakLines(maxWidth: proposal.width, cache: cache) {
            let free = bounds.width - lineWidth(line, cache: cache)
            var x: CGFloat
            switch alignment {
            case .leading: x = bounds.minX
            case .center: x = bounds.minX + free / 2
            case .trailing: x = bounds.minX + free
            }
            let height = lineHeight(line, cache: cache)
            for index in line {
                let size = cache.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + height / 2),
                    anchor: .leading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += height + lineSpacing
        }
    }

    // The same arithmetic as the model, in CGFloat.
    private func breakLines(maxWidth: CGFloat?, cache: Cache) -> [[Int]] {
        var lines: [[Int]] = []
        var current: [Int] = []
        var x: CGFloat = 0
        for index in cache.sizes.indices {
            let width = cache.sizes[index].width
            let needed = current.isEmpty ? width : x + spacing + width
            let overflows = maxWidth.map { needed > $0 } ?? false
            if !current.isEmpty && (overflows || cache.breaks[index]) {
                lines.append(current)
                current = [index]
                x = width
            } else {
                current.append(index)
                x = needed
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private func lineWidth(_ line: [Int], cache: Cache) -> CGFloat {
        line.reduce(0) { $0 + cache.sizes[$1].width } + spacing * CGFloat(line.count - 1)
    }

    private func lineHeight(_ line: [Int], cache: Cache) -> CGFloat {
        line.map { cache.sizes[$0].height }.max() ?? 0
    }
}

struct Tag: View {
    let title: String

    var body: some View {
        Text(title)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
    }
}

struct TopicPicker: View {
    let topics: [String]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(FlowLayout(alignment: .leading))

        layout {
            ForEach(topics, id: \.self) { topic in
                Tag(title: topic)
            }
            Tag(title: "More topics…")
                .flowLineBreak()
        }
        .padding()
    }
}
```

Walking through it:

- **`FlowLineBreak`** is a `LayoutValueKey`. Apple: "implement the one required property that returns the default value." Every view that doesn't set it reads `false`. The `flowLineBreak()` extension is the convenience modifier Apple recommends, so call sites read like built-in modifiers.
- **`makeCache(subviews:)`** measures each subview once at its ideal size and reads each one's line-break flag. The `Cache` type is inferred from the return type and the `inout Cache` parameters.
- **`sizeThatFits`** passes `proposal.width`, a `CGFloat?`, straight to `breakLines`. `nil` means "one line", which is the ideal size. No force unwrap, no invented default.
- **`placeSubviews`** starts at `bounds.minX` and `bounds.minY`, breaks lines with the same `proposal.width`, and places each subview with `anchor: .leading` at the vertical middle of its line, so short and tall tags share a centerline. The `proposal` it passes to each subview is the size it measured, so a tag doesn't decide to be a different size at placement time.
- **`AnyLayout`**: at accessibility text sizes the tags become a plain column. Apple's page for `AnyLayout` describes this exact use: "dynamically changing the type of a layout container without destroying the state of the subviews." Module 38, lesson 5 used it with two built-in layouts; any type that conforms to `Layout` works the same way.

> [!warning] What this version leaves out
> A tag wider than the whole container gets its ideal width and overflows, as in the model's zero proposal. A production version would propose `ProposedViewSize(width: maxWidth, height: nil)` to such a subview so its text wraps, and use the resulting height in both methods. It also hasn't been checked in a right-to-left language: the arithmetic goes left to right in `bounds`, and how SwiftUI mirrors a custom layout's placements in a right-to-left environment wasn't verified for this lesson. Run it with a right-to-left pseudolanguage (Module 38, lesson 6) before you rely on it.

## The cache: when it pays

Apple's page for `makeCache(subviews:)` is unusually direct: "Many layout types don't need a cache, because SwiftUI automatically reuses both the results of calls into the layout and the values that the layout reads from its subviews." It lists three cases where one helps: repeated intermediate calculations across `sizeThatFits`, `placeSubviews` and `explicitAlignment`; reading many `LayoutValueKey` values; and keeping working storage to avoid allocations. Then: "Only implement a cache if profiling shows that it improves performance."

What a cache saves is easy to count. This model counts how often your code measures subviews in one layout pass where the parent asks for three sizes and then places:

```swift
/// A model of what a layout cache saves: count how often your code measures subviews.
/// The counts are calls into *your* code; SwiftUI may also reuse results on its side.
struct Subview {
    let idealWidth: Double
}

struct Counter {
    var measurements = 0
}

struct RowWithoutCache {
    func sizeThatFits(_ subviews: [Subview], counter: inout Counter) -> Double {
        var total = 0.0
        for subview in subviews {
            counter.measurements += 1                   // subview.sizeThatFits(.unspecified)
            total += subview.idealWidth
        }
        return total
    }

    func placeSubviews(_ subviews: [Subview], counter: inout Counter) {
        for _ in subviews {
            counter.measurements += 1                   // measure again to know where to put it
        }
    }
}

struct RowWithCache {
    struct Cache {
        var widths: [Double]
    }

    func makeCache(_ subviews: [Subview], counter: inout Counter) -> Cache {
        counter.measurements += subviews.count
        return Cache(widths: subviews.map(\.idealWidth))
    }

    func sizeThatFits(cache: inout Cache) -> Double {
        cache.widths.reduce(0, +)
    }

    func placeSubviews(cache: inout Cache) {
        _ = cache.widths                              // positions come from the cache
    }
}

let subviews = Array(repeating: Subview(idealWidth: 50), count: 6)

// One layout pass: the parent asks for three sizes (minimum, maximum, ideal), then places.
var plain = Counter()
let row = RowWithoutCache()
for _ in 1...3 { _ = row.sizeThatFits(subviews, counter: &plain) }
row.placeSubviews(subviews, counter: &plain)
print("without cache: \(plain.measurements) measurements")

var cached = Counter()
let cachedRow = RowWithCache()
var cache = cachedRow.makeCache(subviews, counter: &cached)
for _ in 1...3 { _ = cachedRow.sizeThatFits(cache: &cache) }
cachedRow.placeSubviews(cache: &cache)
print("with cache: \(cached.measurements) measurements")

// A subview changes: the default updateCache(_:subviews:) calls makeCache again.
cache = cachedRow.makeCache(subviews, counter: &cached)
print("after a change: \(cached.measurements) measurements")
```

```output
without cache: 24 measurements
with cache: 6 measurements
after a change: 12 measurements
```

Four calls times six subviews is 24 without a cache; six with one. The last line is `updateCache(_:subviews:)`: Apple says SwiftUI calls it "when your layout or its subviews change," and "the method's default implementation recreates the cache by calling the `makeCache(subviews:)` method." So a cache doesn't go stale on its own, as long as you follow Apple's other rule: "only store data that you derive from the layout and its subviews," because SwiftUI "needs to be able to call this method to recreate the cache without changing the layout result." No selection, no counters, no state from your model.

The model overstates the win, as its comment says: SwiftUI may answer a repeated `subview.sizeThatFits(.unspecified)` from its own records without running the subview's layout again. That's why Apple's advice is to profile first. A flow layout with a few dozen tags doesn't need one; this lesson's version has one to show the shape.

## Spacing that respects the views

`FlowLayout` uses a fixed 8 points. Built-in stacks with `spacing: nil` use each view's preferred spacing instead, and your layout can too. `LayoutSubview.spacing` is a `ViewSpacing`, and Apple's `distance(to:along:)` "returns the greater of the two values" on the edges where two views meet: if one view wants 2 points below it and the next wants 8 above, the distance is 8. Apple's `placeSubviews` page builds the array of gaps like this:

```swift ios
import SwiftUI

struct NaturalRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let gaps = gaps(subviews)
        return CGSize(width: sizes.reduce(0) { $0 + $1.width } + gaps.reduce(0, +),
                      height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let gaps = gaps(subviews)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: .unspecified)
            x += subview.sizeThatFits(.unspecified).width
            if index < gaps.count { x += gaps[index] }
        }
    }

    /// The preferred distance between each subview and the next.
    private func gaps(_ subviews: Subviews) -> [CGFloat] {
        subviews.indices.dropLast().map { index in
            subviews[index].spacing.distance(to: subviews[index + 1].spacing, along: .horizontal)
        }
    }

    /// The container's own preferred spacing: leading from the first subview, trailing from the last.
    func spacing(subviews: Subviews, cache: inout ()) -> ViewSpacing {
        var spacing = ViewSpacing()
        for index in subviews.indices {
            var edges: Edge.Set = [.top, .bottom]
            if index == 0 { edges.formUnion(.leading) }
            if index == subviews.count - 1 { edges.formUnion(.trailing) }
            spacing.formUnion(subviews[index].spacing, edges: edges)
        }
        return spacing
    }
}
```

The gaps are computed by one function used by both methods, which is the contract again. The optional `spacing(subviews:cache:)` is different: it doesn't change the inside of the container, it tells *the container's* parent how much room this container wants around it. Apple's default "merges the spacing preferences across all subviews on all edges"; the version above, adapted from Apple's vertical example, takes the leading edge only from the first subview and the trailing edge only from the last.

## Other optional pieces

The protocol has two more customization points you'll meet less often. `explicitAlignment(of:in:proposal:subviews:cache:)` lets the container report its own alignment guides, for example a first-text-baseline for a flow of text tags so it lines up with a label beside it. The static `layoutProperties` returns a `LayoutProperties` whose `stackOrientation` names your container's main axis; Apple notes that views like `Spacer` and `Divider` "align their major axis to match that of their container." Both have default implementations; implement them when a real alignment or spacer problem shows up.

## Common mistakes

> [!error] Placing from zero instead of bounds.minX and bounds.minY
> `bounds` is in the parent's coordinate space. Padding, a navigation bar or a sibling above all move its origin. A layout that starts at `CGPoint(x: 0, y: 0)` draws over whatever is above and to the left of it.

> [!error] proposal.width! or proposal.width ?? .infinity
> `nil` is a normal proposal: it asks for the ideal size, and parents send it often. Force-unwrapping crashes; treating it as infinity can make a container that grows into a GeometryReader-like monster. Decide what "ideal" means for your container (one line, here) and return that.

> [!error] sizeThatFits and placeSubviews that compute different things
> Spacing added only in one method, lines broken with `bounds.width` in one and `proposal.width` in the other, a subview measured with one proposal and placed with another. Put the shared arithmetic in one private function and call it from both.

> [!error] Storing app state in the cache or the layout
> The cache can be thrown away and rebuilt at any time; anything you put there that isn't derived from the subviews will vanish. Input belongs in the layout's stored properties (set by the call site), per-view input in a `LayoutValueKey`, and state in a view.

> [!error] Forgetting to place a subview
> It doesn't disappear: Apple says it "appears at the center of its layout container." If a view shows up stacked in the middle, look for an early `return` or a filtered loop in `placeSubviews`.

## Exercises

````exercise
id: m39-l01-e1
type: prediction
prompt: "The flow model with a forced line break and trailing alignment. The container is placed at x = 0, y = 0 with the width it asked for. What does it print?"
code: |
  struct Item {
      let name: String
      let width: Double
      var breakBefore = false
  }

  enum LineAlignment { case leading, center, trailing }

  struct FlowModel {
      var alignment = LineAlignment.leading
      var spacing = 10.0

      func breakLines(_ items: [Item], maxWidth: Double?) -> [[Int]] {
          var lines: [[Int]] = []
          var current: [Int] = []
          var x = 0.0
          for (index, item) in items.enumerated() {
              let needed = current.isEmpty ? item.width : x + spacing + item.width
              let overflows = maxWidth.map { needed > $0 } ?? false
              if !current.isEmpty && (overflows || item.breakBefore) {
                  lines.append(current)
                  current = [index]
                  x = item.width
              } else {
                  current.append(index)
                  x = needed
              }
          }
          if !current.isEmpty { lines.append(current) }
          return lines
      }

      func width(of line: [Int], _ items: [Item]) -> Double {
          line.reduce(0) { $0 + items[$1].width } + spacing * Double(line.count - 1)
      }
  }

  var flow = FlowModel()
  flow.alignment = .trailing
  let items = [
      Item(name: "A", width: 50), Item(name: "B", width: 70), Item(name: "C", width: 40),
      Item(name: "D", width: 30, breakBefore: true), Item(name: "E", width: 90),
  ]
  let lines = flow.breakLines(items, maxWidth: 150)
  let containerWidth = lines.map { flow.width(of: $0, items) }.max() ?? 0
  print("lines:", lines.map { $0.map { items[$0].name }.joined() })
  print("width:", Int(containerWidth))
  for line in lines {
      var x = containerWidth - flow.width(of: line, items)
      var placed: [String] = []
      for index in line {
          placed.append("\(items[index].name)@\(Int(x))")
          x += items[index].width + flow.spacing
      }
      print(placed.joined(separator: " "))
  }
output: |
  lines: ["AB", "C", "DE"]
  width: 130
  A@0 B@60
  C@90
  D@0 E@40
hints:
  - "A and B need 50 + 10 + 70 = 130. Adding C would need 180."
  - "C starts a line. D has breakBefore, so it starts the next one even though it would fit after C."
  - "The container is as wide as its widest line. Trailing alignment pushes each line to the right edge."
solution: |
  ```output
  lines: ["AB", "C", "DE"]
  width: 130
  A@0 B@60
  C@90
  D@0 E@40
  ```

  - **Line 1:** A (50), then B needs 50 + 10 + 70 = 130 ≤ 150, it fits. C would need 130 + 10 + 40 = 180 > 150, so it wraps.
  - **Line 2:** C alone. D would fit (40 + 10 + 30 = 80), but `breakBefore` forces a new line. That's what a `LayoutValueKey` like `flowLineBreak()` is for.
  - **Line 3:** D, then E needs 30 + 10 + 90 = 130, it fits.
  - The widest line is 130, so the container hugs to 130, not 150.
  - **Trailing:** each line starts at 130 minus its width. Lines 1 and 3 are exactly 130, so they start at 0; line 2 (40 wide) starts at 90.
````

````exercise
id: m39-l01-e2
type: prediction
prompt: "The cache-counting model, with a parent that measures twice and a subview that changes between two layout passes. What does it print?"
code: |
  struct Counter {
      var measurements = 0
  }

  struct RowWithCache {
      struct Cache {
          var widths: [Double]
      }

      func makeCache(_ widths: [Double], counter: inout Counter) -> Cache {
          counter.measurements += widths.count
          return Cache(widths: widths)
      }

      func sizeThatFits(cache: inout Cache) -> Double {
          cache.widths.reduce(0, +)
      }
  }

  var counter = Counter()
  let row = RowWithCache()
  var widths = [40.0, 60, 30, 70]

  var cache = row.makeCache(widths, counter: &counter)
  print("pass 1:", Int(row.sizeThatFits(cache: &cache)), Int(row.sizeThatFits(cache: &cache)), counter.measurements)

  widths.append(50)
  cache = row.makeCache(widths, counter: &counter)     // default updateCache
  print("pass 2:", Int(row.sizeThatFits(cache: &cache)), counter.measurements)
output: |
  pass 1: 200 200 4
  pass 2: 250 9
hints:
  - "Only makeCache measures. sizeThatFits reads the cache."
  - "The second makeCache measures all five subviews, not just the new one."
solution: |
  ```output
  pass 1: 200 200 4
  pass 2: 250 9
  ```

  The first `makeCache` measures four subviews (4). Both `sizeThatFits` calls sum the cached widths, 200, without measuring. A subview is added: the default `updateCache(_:subviews:)` calls `makeCache` again, which measures all five (4 + 5 = 9) and the size becomes 250. If rebuilding were expensive, you'd override `updateCache` to update incrementally; Apple allows that, but the default rebuild is what keeps a cache from going stale.
````

````exercise
id: m39-l01-e3
type: comprehension
prompt: "A custom layout works in a preview, but in the app, inside a VStack with a header above it and padding around it, its first subview draws over the header. What's the most likely cause?"
choices:
  - text: "placeSubviews starts placing at CGPoint(x: 0, y: 0) instead of bounds.minX and bounds.minY."
    correct: true
    why: "bounds is in the parent's coordinate space; its origin moves with padding and siblings."
  - text: "sizeThatFits returned a size that's too small."
    correct: false
    why: "That would make the container overlap what's below it or clip, not draw from the top-left corner of the parent."
  - text: "The layout needs a cache."
    correct: false
    why: "A cache changes how often you compute, not where things go."
  - text: "Subviews must be placed with anchor: .center."
    correct: false
    why: "Any anchor works if the position is computed consistently with it."
solution: |
  **Placing from zero.** Apple describes `bounds` as the region the parent allocates "specified in the parent's coordinate space." In a preview the container often sits at the origin, so (0, 0) happens to be right. In the app, padding and the header move the origin down and right, and a layout that ignores it draws on top of them. Start every placement at `bounds.minX` and `bounds.minY`.
````

````exercise
id: m39-l01-e4
type: solve
prompt: |
  Model a container with a fixed number of equal-width columns, like a two- or three-column card grid. Write `ColumnsModel` with:

  - `columnWidth(containerWidth:)`: subtract `spacing × (columns − 1)` and divide by `columns`.
  - `sizeThatFits(_:proposedWidth:)`: the width is the proposed width (this container fills it); the height is each row's tallest cell, plus `spacing` between rows.
  - `place(_:boundsX:boundsY:boundsWidth:)`: returns one string per cell, `"name x,y wWidth"`, starting at the bounds origin.

  Then run it for five cells in three columns, a proposed width of 320 and bounds at x = 20, y = 0.
starter: |
  struct Cell {
      let name: String
      let height: Double
  }

  struct ColumnsModel {
      let columns: Int
      var spacing = 10.0

      // your code
  }

  let grid = ColumnsModel(columns: 3)
  let cells = [
      Cell(name: "A", height: 40), Cell(name: "B", height: 60), Cell(name: "C", height: 40),
      Cell(name: "D", height: 30), Cell(name: "E", height: 50),
  ]
hints:
  - "Split the cells into rows with stride(from: 0, to: cells.count, by: columns)."
  - "Column width for 320 and 3 columns: (320 − 20) ÷ 3 = 100."
  - "Use the bounds width, not the proposal, for the column width at placement; here they're the same because the container reported the proposed width."
rubric:
  - Computes the column width from the container width, spacing and column count.
  - Reports the proposed width and the sum of row heights plus spacing.
  - Places cells starting at boundsX and boundsY, advancing by column width plus spacing.
  - Prints the expected six lines.
solution: |
  ```swift
  struct Cell {
      let name: String
      let height: Double
  }

  struct ColumnsModel {
      let columns: Int
      var spacing = 10.0

      func columnWidth(containerWidth: Double) -> Double {
          (containerWidth - spacing * Double(columns - 1)) / Double(columns)
      }

      func rows(_ cells: [Cell]) -> [[Cell]] {
          stride(from: 0, to: cells.count, by: columns).map { start in
              Array(cells[start..<min(start + columns, cells.count)])
          }
      }

      func sizeThatFits(_ cells: [Cell], proposedWidth: Double) -> (width: Double, height: Double) {
          let rows = rows(cells)
          let heights = rows.reduce(0) { $0 + ($1.map(\.height).max() ?? 0) }
          return (proposedWidth, heights + spacing * Double(max(rows.count - 1, 0)))
      }

      func place(_ cells: [Cell], boundsX: Double, boundsY: Double, boundsWidth: Double) -> [String] {
          let width = columnWidth(containerWidth: boundsWidth)
          var result: [String] = []
          var y = boundsY
          for row in rows(cells) {
              for (column, cell) in row.enumerated() {
                  let x = boundsX + Double(column) * (width + spacing)
                  result.append("\(cell.name) \(Int(x)),\(Int(y)) w\(Int(width))")
              }
              y += (row.map(\.height).max() ?? 0) + spacing
          }
          return result
      }
  }

  let grid = ColumnsModel(columns: 3)
  let cells = [
      Cell(name: "A", height: 40), Cell(name: "B", height: 60), Cell(name: "C", height: 40),
      Cell(name: "D", height: 30), Cell(name: "E", height: 50),
  ]
  let size = grid.sizeThatFits(cells, proposedWidth: 320)
  print("size:", Int(size.width), Int(size.height))
  for line in grid.place(cells, boundsX: 20, boundsY: 0, boundsWidth: size.width) {
      print(line)
  }
  ```

  ```output
  size: 320 120
  A 20,0 w100
  B 130,0 w100
  C 240,0 w100
  D 20,70 w100
  E 130,70 w100
  ```

  Each column is (320 − 2 × 10) ÷ 3 = 100. Row 1's tallest cell is 60, row 2's is 50, plus 10 between them: 120. The second row starts at 0 + 60 + 10 = 70. Note what this container answers for the special proposals: it fills whatever width it's offered, so for `nil` you'd need to pick an ideal width (for example, the widest cell's ideal width times the column count), which is the decision Apple's `EqualWidthHStack` sample makes. In SwiftUI you'd propose `ProposedViewSize(width: width, height: nil)` to each cell, so its text wraps to the column.
````

````exercise
id: m39-l01-e5
type: fill-in
prompt: "Complete a custom layout value that marks a view as highlighted, and the layout code that reads it."
code: |
  private struct Highlighted: [[1]] {
      static let [[2]] = false
  }

  extension View {
      func highlighted() -> some View {
          [[3]](key: Highlighted.self, value: true)
      }
  }

  // Inside placeSubviews(in:proposal:subviews:cache:)
  for subview in subviews {
      let isHighlighted = subview[[[4]]]
      let size = subview.sizeThatFits(.unspecified)
      subview.[[5]](at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(size))
  }
blanks:
  - id: "1"
    answers: ["LayoutValueKey"]
  - id: "2"
    answers: ["defaultValue"]
  - id: "3"
    answers: ["layoutValue"]
  - id: "4"
    answers: ["Highlighted.self"]
  - id: "5"
    answers: ["place"]
hints:
  - "The protocol has one requirement, a static default."
  - "The subview proxy is indexed with the key's type."
solution: |
  ```swift ios
  import SwiftUI

  private struct Highlighted: LayoutValueKey {
      static let defaultValue = false
  }

  extension View {
      func highlighted() -> some View {
          layoutValue(key: Highlighted.self, value: true)
      }
  }

  struct HighlightStack: Layout {
      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          subviews.reduce(CGSize.zero) { result, subview in
              let size = subview.sizeThatFits(.unspecified)
              let extra: CGFloat = subview[Highlighted.self] ? 8 : 0
              return CGSize(width: max(result.width, size.width + extra), height: result.height + size.height)
          }
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          var y = bounds.minY
          for subview in subviews {
              let isHighlighted = subview[Highlighted.self]
              let size = subview.sizeThatFits(.unspecified)
              // Highlighted subviews are indented by 8 points; sizeThatFits accounts for it.
              subview.place(at: CGPoint(x: bounds.minX + (isHighlighted ? 8 : 0), y: y),
                            anchor: .topLeading, proposal: ProposedViewSize(size))
              y += size.height
          }
      }
  }
  ```

  `LayoutValueKey` needs only `defaultValue`; its type sets the key's `Value`. `layoutValue(key:value:)` sets it on a view, and `subview[Highlighted.self]` reads it inside the layout. The full version also shows the contract: the 8-point indent that `placeSubviews` adds is counted in `sizeThatFits`.
````

````exercise
id: m39-l01-e6
type: find-errors
prompt: "A teammate's horizontal layout. Which of these are real problems?"
code: |
  struct SpacedRow: Layout {
      var spacing: CGFloat = 12

      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
          let width = sizes.reduce(0) { $0 + $1.width }
          let height = sizes.map(\.height).max() ?? 0
          return CGSize(width: min(width, proposal.width!), height: height)
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          var x: CGFloat = 0
          for subview in subviews where subview.priority >= 0 {
              let size = subview.sizeThatFits(.unspecified)
              subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: .unspecified)
              x += size.width + spacing
          }
      }
  }
choices:
  - text: "sizeThatFits doesn't include the spacing that placeSubviews adds between subviews."
    correct: true
    why: "The container reports a width smaller than what it draws."
  - text: "proposal.width! crashes when the parent proposes an unspecified width."
    correct: true
    why: "nil is a normal proposal; it asks for the ideal size."
  - text: "Placement starts at x = 0 instead of bounds.minX."
    correct: true
    why: "bounds is in the parent's coordinate space."
  - text: "Subviews with a negative layoutPriority are never placed, so they end up centered in the container."
    correct: true
    why: "Apple: a subview you don't place appears at the center of the container."
  - text: "The layout must declare a Cache type because it measures subviews."
    correct: false
    why: "cache: inout () is fine. Apple recommends a cache only when profiling shows it helps."
rubric:
  - Flags the missing spacing in sizeThatFits.
  - Flags the force unwrap of proposal.width.
  - Flags x starting at 0.
  - Flags the filtered loop that leaves some subviews unplaced.
  - Doesn't require a cache.
solution: |
  Four real problems:

  1. **Spacing only in placement.** `sizeThatFits` sums widths without the `12 × (count − 1)` points that `placeSubviews` inserts, breaking Apple's rule that sizing must account for spacing added during placement.
  2. **`proposal.width!`** crashes on the unspecified proposal, which parents use to ask for the ideal size. Return the ideal width when it's `nil`.
  3. **`x = 0`** ignores `bounds.minX`, so the row draws at the parent's left edge.
  4. **`where subview.priority >= 0`** skips subviews, which then appear "at the center of its layout container." If a subview shouldn't show, don't put it in the container.

  A fixed version:

  ```swift ios
  import SwiftUI

  struct SpacedRow: Layout {
      var spacing: CGFloat = 12

      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
          let width = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(subviews.count - 1, 0))
          let height = sizes.map(\.height).max() ?? 0
          return CGSize(width: width, height: height)
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          var x = bounds.minX
          for subview in subviews {
              let size = subview.sizeThatFits(.unspecified)
              subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(size))
              x += size.width + spacing
          }
      }
  }
  ```
````

````exercise
id: m39-l01-e7
type: design
prompt: "A settings screen shows a person's interests as tags. Product wants: tags wrap onto lines; the 'Add interest' tag always starts its own line; at accessibility text sizes everything becomes a single column; adding a tag shouldn't reset the selection highlight on the others. Describe the views, layouts and modifiers you'd use, and say which part of this lesson each requirement maps to."
rubric:
  - Uses a custom FlowLayout for wrapping, with sizeThatFits and placeSubviews sharing the line-breaking code.
  - Uses a LayoutValueKey (flowLineBreak) for the 'Add interest' tag.
  - Uses AnyLayout to switch to VStackLayout at isAccessibilitySize, keeping subview identity and state.
  - Keeps selection in the model or a view's state keyed by tag id, not in the layout or its cache, and uses stable ForEach ids.
solution: |
  A sample answer:

  - **Wrapping:** the lesson's `FlowLayout`, with line breaking in one function that both `sizeThatFits` and `placeSubviews` call with `proposal.width`.
  - **"Add interest" on its own line:** a `LayoutValueKey` (`FlowLineBreak`) set through a `flowLineBreak()` modifier on that one tag. The layout reads `subview[FlowLineBreak.self]` and starts a new line.
  - **Single column at large sizes:** read `@Environment(\.dynamicTypeSize)` and choose `AnyLayout(VStackLayout(alignment: .leading))` when `isAccessibilitySize`, `AnyLayout(FlowLayout())` otherwise. Because it's `AnyLayout` and not two `if` branches, the tags keep their identity when the setting changes.
  - **Selection survives additions:** the selection lives in the screen's state or model as a set of interest ids, never in the layout (layouts are values rebuilt with the view) or the cache (which SwiftUI may rebuild at any time). `ForEach` uses each interest's stable id, so inserting one doesn't change the identity of the others (Module 36, lesson 5).
````

## Summary

- `sizeThatFits` may be called several times with different proposals; answer zero with your minimum, infinity with your maximum, `nil` dimensions with your ideal size. Whatever you return is your size.
- `placeSubviews` gets `bounds` in the parent's coordinate space (start at `minX`/`minY`) and the proposal that produced its size. Respond to that proposal exactly as `sizeThatFits` did; share the arithmetic in one function.
- Place every subview: an unplaced one appears at the container's center.
- A flow layout breaks lines greedily with the proposed width, reports its widest line and total height, and aligns lines within bounds.
- Add a cache only when profiling says so. Fill it in `makeCache`, only with data derived from the subviews; the default `updateCache` rebuilds it when anything changes.
- Per-view input goes through `LayoutValueKey` and `layoutValue(key:value:)`, read with `subview[Key.self]`. Preferred spacing comes from `ViewSpacing.distance(to:along:)`.
- `AnyLayout` swaps a custom layout for a built-in one without destroying subview state.
