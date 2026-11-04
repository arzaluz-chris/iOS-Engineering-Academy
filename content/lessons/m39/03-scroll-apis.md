---
id: m39-l03
title: Modern scrolling APIs
description: "ScrollViewReader scrolls on command but can't tell you where you are. Since iOS 17 a scroll view's position is state you bind to, and since iOS 18 ScrollPosition adds edges and offsets. You build a paged carousel with containerRelativeFrame and scrollTargetBehavior, keep a chat pinned to its latest message, react to scrolling with onScrollGeometryChange without updating on every point, and run plain-Swift models of the sizing formula, the snapping and the change filtering."
module: m39
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l02]
objectives:
  - Choose between ScrollViewReader, scrollPosition(id:anchor:) and ScrollPosition by deployment target and need.
  - Bind a scroll view's position to state with scrollTargetLayout, and scroll to an item or an edge.
  - Build a carousel with containerRelativeFrame, scrollTargetBehavior(.viewAligned) and a page indicator.
  - Compute an item's size from containerRelativeFrame's count, span and spacing.
  - React to scroll geometry with onScrollGeometryChange, transforming it to the smallest value that drives the UI.
  - Use iOS 18 scroll APIs from an iOS 17 app behind an availability check.
terms:
  - term: "ScrollViewReader"
    definition: "A view (iOS 14) whose content receives a ScrollViewProxy. proxy.scrollTo(_:anchor:) scrolls to a view with a given id. It can't report the current position."
  - term: "scrollPosition(id:anchor:)"
    definition: "A modifier (iOS 17) that binds an optional id to a scroll view. SwiftUI updates it with the top-most or leading-most view in the scrollTargetLayout as the user scrolls, and scrolls when you write it."
  - term: ScrollPosition
    definition: "A type (iOS 18) describing where a scroll view is: a view id, an edge, or a point. Bound with scrollPosition(_:anchor:); it has scrollTo(id:), scrollTo(edge:), scrollTo(point:), viewID(type:) and isPositionedByUser."
  - term: Scroll target behavior
    definition: "Decides where a scroll gesture is allowed to end. .paging settles on container-sized boundaries; .viewAligned settles on the views of the scrollTargetLayout."
  - term: "onScrollGeometryChange(for:of:action:)"
    definition: "A modifier (iOS 18) that transforms the scroll view's ScrollGeometry into an Equatable value and calls the action only when that value changes."
mastery:
  - Replace a ScrollViewReader that only scrolls to the newest message with defaultScrollAnchor and ScrollPosition.
  - Build a horizontal carousel where the next card peeks in and a dot indicator follows the visible card.
  - Give the width of a card for count 4, span 3 and spacing 8 in a 360-point container.
  - Show a compact title when the user scrolls past a header, with an action that runs twice per scroll, not on every point.
  - Mark which scroll APIs need iOS 18 and gate them with if #available.
resources: [swiftui-scrollposition, swiftui-scrolltargetbehavior, swiftui-containerrelativeframe, swiftui-performant-scrollable-stacks, swiftui-foreach, swiftui-state, swiftui-onchange]
cards:
  - id: m39-l03-c1
    front: ScrollViewReader, scrollPosition(id:) or ScrollPosition?
    back: "ScrollViewReader (iOS 14): imperative scrollTo, no reading the position. scrollPosition(id:anchor:) (iOS 17): a two-way binding to the top-most view's id. ScrollPosition with scrollPosition(_:anchor:) (iOS 18): ids plus edges and points, and isPositionedByUser."
  - id: m39-l03-c2
    front: What does scrollTargetLayout() do?
    back: "Marks the layout (usually the LazyHStack or LazyVStack inside the ScrollView) whose views are the scroll targets: the ones .viewAligned settles on and the ones scrollPosition reports and scrolls to. Without it, scrollPosition(id:) has nothing to track."
  - id: m39-l03-c3
    front: How does containerRelativeFrame(count:span:spacing:) compute a length?
    back: "Apple: available = container − spacing × (count − 1); column = available ÷ count; item = column × span + (span − 1) × spacing. The container is the nearest scroll view, navigation stack, column or window, minus safe area insets."
  - id: m39-l03-c4
    front: .paging vs .viewAligned?
    back: ".paging settles on boundaries the size of the scroll view (container-aligned), good for full-width pages. .viewAligned settles on the views of the scrollTargetLayout, good for cards narrower than the screen; in compact size classes it limits how many views one gesture scrolls by default."
  - id: m39-l03-c5
    front: How should you use onScrollGeometryChange efficiently?
    back: "Transform ScrollGeometry into the smallest Equatable value that changes your UI (a Bool, a bucket), not the raw offset. The action runs only when that value changes, so a header toggle runs twice per scroll instead of on every frame."
---

## The idea in one sentence

Since iOS 17, **where a scroll view is scrolled is state you bind to**, like a text field's text, and the scroll view keeps that state and the screen in sync in both directions.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked, not run: blocks using iOS 18 APIs (`ScrollPosition`, `scrollPosition(_:anchor:)`, `onScrollGeometryChange`, `onScrollVisibilityChange`) against an iOS 18 deployment target, the rest against iOS 17. Behavior and availability are quoted from Apple's pages for `ScrollViewReader`, `ScrollViewProxy.scrollTo(_:anchor:)`, `scrollPosition(id:anchor:)`, `ScrollPosition`, `scrollPosition(_:anchor:)`, `scrollTargetLayout(isEnabled:)`, `scrollTargetBehavior(_:)`, `PagingScrollTargetBehavior`, `ViewAlignedScrollTargetBehavior`, `containerRelativeFrame(_:count:span:spacing:alignment:)`, `defaultScrollAnchor(_:)`, `safeAreaPadding(_:_:)`, `ScrollGeometry`, `onScrollGeometryChange(for:of:action:)`, `onScrollPhaseChange(_:)` and `onScrollVisibilityChange(threshold:_:)`, read in November 2026. Nothing was scrolled on a device. The sizing formula, snapping and change-filtering models are plain Swift, compiled and run with Swift 6.3; the snapping model explains the documented behaviors and is not SwiftUI's algorithm.

## Three generations

| API | Since | Scroll on command | Read the position | Targets |
| --- | --- | --- | --- | --- |
| `ScrollViewReader` + `proxy.scrollTo(_:anchor:)` | iOS 14 | Yes, by id | No | Any view with `.id(_:)` |
| `scrollPosition(id:anchor:)` | iOS 17 | Write the binding | Yes, the top/leading view's id | Views in the `scrollTargetLayout()` |
| `ScrollPosition` + `scrollPosition(_:anchor:)` | iOS 18 | `scrollTo(id:)`, `scrollTo(edge:)`, `scrollTo(point:)` | `viewID(type:)`, `edge`, `point`, `isPositionedByUser` | Views in the `scrollTargetLayout()`, edges, offsets |

### ScrollViewReader: imperative, one way

`ScrollViewReader` gives its content a proxy, and you call `scrollTo` from an action. Apple's page has one hard rule: "You may not use the `ScrollViewProxy` during execution of the `content` content builder; doing so results in a runtime error." Call it from button actions, `onChange`, or `task`.

```swift ios
import SwiftUI

struct BuildLogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index])
                            .font(.caption.monospaced())
                            .id(index)
                    }
                }
                .padding()
            }
            .onChange(of: lines.count) {
                withAnimation {
                    proxy.scrollTo(lines.count - 1, anchor: .bottom)
                }
            }
        }
    }
}
```

`scrollTo(_:anchor:)` with a `nil` anchor "scrolls the minimum amount to make the identified view wholly visible"; with `.bottom` it "aligns the bottom of the identified view to the bottom of the scroll view." What the reader can't do is tell you whether the user has scrolled up to read an earlier line, so this log jumps to the bottom on every new line even if the user is reading something else. That's the gap the newer APIs fill.

### scrollPosition(id:anchor:): a binding

From iOS 17, bind an optional id. Apple: "As the scroll view scrolls, the binding will be updated with the identity of the leading-most / top-most view," and "you can write to the binding to scroll to the view with the provided identity." It only sees views inside a layout marked with `scrollTargetLayout()`, so that modifier isn't optional here.

### ScrollPosition: ids, edges and points

iOS 18 generalizes the binding into a type. A chat that opens at the newest message and lets you jump around:

```swift ios 18.0
import SwiftUI

struct Message: Identifiable {
    let id: Int
    let text: String
}

struct ConversationView: View {
    @State private var messages = (1...60).map { Message(id: $0, text: "Message \($0)") }
    @State private var position = ScrollPosition(idType: Message.ID.self)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(messages) { message in
                    Text(message.text)
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition($position)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("First") {
                    withAnimation { position.scrollTo(id: messages[0].id) }
                }
                Spacer()
                if let topID = position.viewID(type: Message.ID.self) {
                    Text("Reading #\(topID)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Latest") {
                    withAnimation { position.scrollTo(edge: .bottom) }
                }
            }
            .padding()
            .background(.bar)
        }
        .toolbar {
            Button("Add") {
                messages.append(Message(id: messages.count + 1, text: "Message \(messages.count + 1)"))
            }
        }
    }
}
```

- **`ScrollPosition(idType: Message.ID.self)`** creates an "automatic" position whose ids are `Int`. Apple: SwiftUI uses that type "along with the views in the scroll view's scroll target layout to programmatically scroll to those views and to update the `viewID` property as the user scrolls."
- **`defaultScrollAnchor(.bottom)`** (iOS 17) makes the scroll view start at the bottom, the usual chat behavior. Apple says the anchor also controls "how the scroll view handles content size changes."
- **`viewID(type:)`** reads the id of the top-most visible message, the same thing `scrollPosition(id:)` would write into its binding.
- **`scrollTo(edge: .bottom)`** jumps to the end without knowing the last id. Apple: "SwiftUI will attempt to keep that position stable. For an edge, that means keeping a top aligned scroll view scrolled to the top if the content size changes." Whether a bottom edge keeps up with new messages the same way wasn't checked for this lesson; try it with your content.
- **`isPositionedByUser`**, not used above, tells you whether the user has scrolled; Apple notes that setting it to `true` clears an edge or point position. It's how you'd decide whether a new message should pull the view down or leave the user where they are reading.

## Carousels: containerRelativeFrame and scroll targets

A horizontal carousel needs three things: cards sized from the screen, not hard-coded; scrolling that settles on a card instead of halfway between two; and some indication of which card is showing.

```swift ios
import SwiftUI

struct Offer: Identifiable {
    let id: Int
    let title: String
}

struct OfferCarousel: View {
    let offers: [Offer]
    @State private var visibleID: Offer.ID?

    private var visiblePosition: Int {
        (offers.firstIndex { $0.id == visibleID } ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(offers) { offer in
                        Text(offer.title)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 22))
                            .containerRelativeFrame(.horizontal, count: 4, span: 3, spacing: 8)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleID)
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, 16)

            HStack(spacing: 6) {
                ForEach(offers) { offer in
                    Circle()
                        .fill(offer.id == (visibleID ?? offers.first?.id) ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Offer \(visiblePosition) of \(offers.count)")
        }
    }
}

struct OnboardingPager: View {
    let pages: [String]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages, id: \.self) { page in
                    Text(page)
                        .font(.largeTitle)
                        .containerRelativeFrame(.horizontal)
                }
            }
        }
        .scrollTargetBehavior(.paging)
    }
}
```

**Sizing.** `containerRelativeFrame` sizes each card from "the nearest container," which here is the scroll view, "subtracting any safe area insets that might be applied to that container." Module 34 introduced it; this is the formula Apple gives, run in plain Swift so you can see the numbers:

```swift
/// Apple's formula for containerRelativeFrame(_:count:span:spacing:), in plain Swift.
func itemLength(container: Double, count: Int, span: Int, spacing: Double) -> Double {
    let available = container - spacing * Double(count - 1)
    let column = available / Double(count)
    return column * Double(span) + Double(span - 1) * spacing
}

func oneDecimal(_ value: Double) -> Double { (value * 10).rounded() / 10 }

for (device, width) in [("iPhone", 360.0), ("iPad", 744.0)] {
    let cards = itemLength(container: width, count: 4, span: 3, spacing: 8)
    let full = itemLength(container: width, count: 1, span: 1, spacing: 8)
    let thirds = itemLength(container: width, count: 3, span: 1, spacing: 8)
    print("\(device) \(Int(width)): span 3 of 4 = \(oneDecimal(cards)), full = \(oneDecimal(full)), a third = \(oneDecimal(thirds))")
}
```

```output
iPhone 360: span 3 of 4 = 268.0, full = 360.0, a third = 114.7
iPad 744: span 3 of 4 = 556.0, full = 744.0, a third = 242.7
```

On a 360-point container (a 390-point phone minus the 16-point `safeAreaPadding` on each side, rounded for the example), four columns of 84 points with 8 between them; a card spans three columns plus the two gaps inside it: 268. The fourth column's worth is the next card peeking in, which tells the user there's more. The same code gives 556-point cards on an iPad, with no size classes and no `GeometryReader`.

**Settling.** `scrollTargetBehavior(_:)` decides where a gesture is allowed to stop. Apple documents two built-in behaviors: `.paging`, which "uses the geometry of the scroll view to decide where to allow scrolls to end" ("container aligned boundaries"), and `.viewAligned`, which "will always settle on the geometry of individual views," the views of the `scrollTargetLayout()`. Apple doesn't document the exact rule for choosing the target, so here is a model that captures the difference: the gesture predicts where it would stop, and the behavior moves that to the nearest allowed offset.

```swift
/// A model of where a scroll gesture settles. SwiftUI computes a predicted end offset from the
/// gesture's velocity; a scroll target behavior moves it to an allowed target. Apple documents
/// what each behavior aligns to, not this exact rule, so treat the model as an explanation.
func settle(predicted: Double, targets: [Double]) -> Double {
    targets.min { abs($0 - predicted) < abs($1 - predicted) } ?? predicted
}

let containerWidth = 360.0
let cardWidth = 268.0, spacing = 8.0, cardCount = 5
let contentWidth = Double(cardCount) * cardWidth + Double(cardCount - 1) * spacing
let maxOffset = contentWidth - containerWidth

// .paging: targets every container width ("container-aligned boundaries").
let pages = stride(from: 0.0, through: maxOffset, by: containerWidth).map { $0 } + [maxOffset]
// .viewAligned: targets each card's leading edge, clamped to what can actually be scrolled.
let cards = (0..<cardCount).map { min(Double($0) * (cardWidth + spacing), maxOffset) }

print("content:", Int(contentWidth), "max offset:", Int(maxOffset))
print("paging targets:", pages.map { Int($0) })
print("card targets:", cards.map { Int($0) })
for predicted in [120.0, 150, 700, 1100] {
    print("predicted \(Int(predicted)) → paging \(Int(settle(predicted: predicted, targets: pages))), viewAligned \(Int(settle(predicted: predicted, targets: cards)))")
}
```

```output
content: 1372 max offset: 1012
paging targets: [0, 360, 720, 1012]
card targets: [0, 276, 552, 828, 1012]
predicted 120 → paging 0, viewAligned 0
predicted 150 → paging 0, viewAligned 276
predicted 700 → paging 720, viewAligned 828
predicted 1100 → paging 1012, viewAligned 1012
```

With 268-point cards, paging by 360 points would stop with cards cut in half (720 is in the middle of the third card). View-aligned stops at a card's edge every time. That's why the carousel uses `.viewAligned` and the onboarding pager, whose pages are exactly one container wide (`containerRelativeFrame(.horizontal)` with no count), uses `.paging`. One more documented detail: by default the view-aligned behavior "limits the number of views it scrolls when in a compact horizontal size class," so a hard flick on an iPhone doesn't fly past five offers. `ViewAlignedScrollTargetBehavior(limitBehavior: .always)` or `.never` overrides that.

**The indicator.** `scrollPosition(id: $visibleID)` writes the leading-most card's id as the user scrolls. It starts as `nil`, so the dots treat `nil` as the first card. The dots are one accessibility element with a label like "Offer 2 of 5," because six unlabeled circles mean nothing to VoiceOver (Module 38, lesson 5).

## Reacting to scrolling without updating every frame

iOS 18's `onScrollGeometryChange(for:of:action:)` gives you the scroll view's `ScrollGeometry` (`contentOffset`, `contentSize`, `contentInsets`, `containerSize`, `visibleRect`) through two closures. Apple explains why there are two: "The geometry of a scroll view changes frequently while scrolling. You should avoid updating large parts of your app whenever the scroll geometry changes." The first closure transforms the geometry into your own `Equatable` type; the action "is called whenever the data type changes."

So the transform is where you make it cheap. A model with the offsets of one slow scroll down and back up:

```swift
/// A model of onScrollGeometryChange: the action runs only when the transformed value changes.
func actionCalls<T: Equatable>(offsets: [Double], transform: (Double) -> T) -> [T] {
    var calls: [T] = []
    var previous = transform(offsets[0])
    for offset in offsets.dropFirst() {
        let value = transform(offset)
        if value != previous {
            calls.append(value)
            previous = value
        }
    }
    return calls
}

// Offsets reported during one slow scroll down and back up.
let offsets: [Double] = [0, 12, 31, 48, 59, 66, 80, 95, 70, 52, 30, 8, 0]

let raw = actionCalls(offsets: offsets) { $0 }
let pastHeader = actionCalls(offsets: offsets) { $0 > 60 }
let bucket = actionCalls(offsets: offsets) { Int($0 / 50) }
print("raw offset:", raw.count, "calls")
print("past header:", pastHeader.count, "calls", pastHeader)
print("50-point buckets:", bucket.count, "calls", bucket)
```

```output
raw offset: 12 calls
past header: 2 calls [true, false]
50-point buckets: 2 calls [1, 0]
```

Transforming to the raw offset calls the action for every change: 12 times for 13 samples, and a real scroll reports far more. Transforming to "is the header scrolled away?" calls it twice. Each call that sets state invalidates every view that reads that state, so the transform decides how much work scrolling causes. The SwiftUI version:

```swift ios 18.0
import SwiftUI

struct ArticleView: View {
    let title: String
    let paragraphs: [String]
    @State private var showsCompactTitle = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.largeTitle.bold())
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
            }
            .padding()
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 60
        } action: { _, isPastTitle in
            showsCompactTitle = isPastTitle
        }
        .overlay(alignment: .top) {
            if showsCompactTitle {
                Text(title)
                    .font(.headline)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: showsCompactTitle)
    }
}
```

`contentOffset` "may extend before zero … when the content insets of the scroll view are non-zero," as in UIKit, where a scroll view at rest under a navigation bar has a negative offset. Adding `contentInsets.top` measures how far the user has scrolled from the resting position. If several scroll views are inside the modified view, Apple says "only the first one will invoke the closure you provide and a runtime issue will be logged," so attach it to the scroll view itself.

Two relatives, also iOS 18:

- **`onScrollVisibilityChange(threshold:_:)`**, on a view inside a scroll view, calls its action with `true` or `false` when the view crosses the threshold (half visible by default). Apple's example plays a video while it's on screen.
- **`onScrollPhaseChange(_:)`** reports phases like `.idle`, `.interacting`, `.decelerating` and `.animating`. Use it for "do this when scrolling stops," for example loading full-resolution images only once the user lets go.

## Supporting iOS 17 and 18 together

An app that targets iOS 17 can use these iOS 18 modifiers behind an availability check. Wrapping the check in a `ViewModifier` keeps it out of your screens:

```swift ios
import SwiftUI

struct TracksScrolling: ViewModifier {
    @Binding var isScrolled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 20
            } action: { _, scrolled in
                isScrolled = scrolled
            }
        } else {
            content
        }
    }
}

struct FeedView: View {
    @State private var isScrolled = false

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<100, id: \.self) { index in
                    Text("Post \(index)")
                }
            }
        }
        .modifier(TracksScrolling(isScrolled: $isScrolled))
        .overlay(alignment: .bottomTrailing) {
            if isScrolled {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.largeTitle)
                    .padding()
                    .accessibilityLabel("Scrolled down")
            }
        }
    }
}
```

On iOS 17 the indicator never appears; on iOS 18 it does. `if #available` in a `ViewModifier` body produces two branches (two identities), but since the OS version doesn't change while the app runs, only one branch ever exists. Don't use the same trick with a condition that changes at runtime: that's the `if`/`else` identity reset from Module 36, lesson 5.

## Common mistakes

> [!error] scrollPosition(id:) that never updates
> The binding stays `nil` and writing it does nothing. Almost always the `scrollTargetLayout()` is missing, or it's on the `ScrollView` instead of the `LazyVStack`/`LazyHStack` inside it.

> [!error] Calling proxy.scrollTo inside the reader's content builder
> Apple: using the proxy "during execution of the `content` content builder … results in a runtime error." Call it from an action, `onChange` or `task`.

> [!error] .paging with cards narrower than the screen
> Paging settles on container-sized boundaries, so narrower cards stop cut in half. Use `.viewAligned` with `scrollTargetLayout()`, or make each page `containerRelativeFrame(.horizontal)`.

> [!error] Storing the raw offset from onScrollGeometryChange in state
> The action runs on nearly every frame and every view reading that state re-evaluates its body. Transform to the smallest value that changes what's on screen.

> [!error] Hard-coded card widths
> `frame(width: 300)` looks right on one phone. `containerRelativeFrame` with count and span adapts to every width, split view and orientation.

> [!error] Unstable ids in a scroll target layout
> `ForEach(items.indices, id: \.self)` or ids made in `body` make the position point at a different item after an insert. Use the model's stable ids (Module 34, lesson 5).

## Exercises

````exercise
id: m39-l03-e1
type: prediction
prompt: "Apple's containerRelativeFrame formula for a few layouts in a 600-point-wide container. What does it print?"
code: |
  func itemLength(container: Double, count: Int, span: Int, spacing: Double) -> Double {
      let available = container - spacing * Double(count - 1)
      let column = available / Double(count)
      return column * Double(span) + Double(span - 1) * spacing
  }

  let container = 600.0
  print(Int(itemLength(container: container, count: 2, span: 1, spacing: 20)))
  print(Int(itemLength(container: container, count: 5, span: 2, spacing: 0)))
  print(Int(itemLength(container: container, count: 6, span: 4, spacing: 12)))
  print(Int(itemLength(container: container, count: 3, span: 3, spacing: 30)))
output: |
  290
  240
  396
  600
hints:
  - "Subtract spacing × (count − 1) first, then divide by count."
  - "A span of more than one column adds back the gaps inside it."
solution: |
  ```output
  290
  240
  396
  600
  ```

  - count 2, spacing 20: (600 − 20) ÷ 2 = 290.
  - count 5, span 2, no spacing: 600 ÷ 5 × 2 = 240.
  - count 6, span 4, spacing 12: (600 − 60) ÷ 6 = 90 per column; 90 × 4 + 3 × 12 = 396.
  - count 3, span 3, spacing 30: (600 − 60) ÷ 3 = 180; 180 × 3 + 2 × 30 = 600. Spanning every column gives the whole container, gaps included.
````

````exercise
id: m39-l03-e2
type: prediction
prompt: "The change-filtering model of onScrollGeometryChange, for a reading-progress indicator. What does it print?"
code: |
  func actionCalls<T: Equatable>(offsets: [Double], transform: (Double) -> T) -> [T] {
      var calls: [T] = []
      var previous = transform(offsets[0])
      for offset in offsets.dropFirst() {
          let value = transform(offset)
          if value != previous {
              calls.append(value)
              previous = value
          }
      }
      return calls
  }

  let contentHeight = 1000.0
  let offsets: [Double] = [0, 90, 180, 240, 260, 410, 520, 760, 1000]
  let percent = actionCalls(offsets: offsets) { Int($0 / contentHeight * 100) }
  let quarters = actionCalls(offsets: offsets) { Int($0 / contentHeight * 4) }
  print(percent.count, quarters)
output: |
  8 [1, 2, 3, 4]
hints:
  - "Every sample here gives a different whole percentage."
  - "Quarters: 0–249 is 0, 250–499 is 1, and so on."
solution: |
  ```output
  8 [1, 2, 3, 4]
  ```

  As percentages, every one of the eight samples after the first is a new value (9, 18, 24, 26, 41, 52, 76, 100), so the action runs eight times. As quarters, the values are 0, 0, 0, 0, 1, 1, 2, 3, 4: the action runs only when the quarter changes, four times. If the indicator shows four segments, transforming to quarters gives the same screen with half the updates here, and far fewer in a real scroll that reports many more offsets.
````

````exercise
id: m39-l03-e3
type: comprehension
prompt: "An app's minimum deployment target is iOS 17. It needs a carousel whose dot indicator follows the visible card, and a button that scrolls back to the first card. Which API fits without an availability check?"
choices:
  - text: "scrollPosition(id:anchor:) with scrollTargetLayout() and an optional id in @State."
    correct: true
    why: "iOS 17. The binding reports the leading card and scrolls when you write it."
  - text: "ScrollPosition with scrollPosition(_:anchor:)."
    correct: false
    why: "Both are iOS 18; you'd need if #available."
  - text: "ScrollViewReader with proxy.scrollTo."
    correct: false
    why: "It can scroll to the first card but can't tell you which card is visible, so the dots can't follow."
  - text: "onScrollGeometryChange reading contentOffset.x."
    correct: false
    why: "iOS 18, and you'd have to turn offsets into card indexes yourself."
solution: |
  **`scrollPosition(id:anchor:)`.** Available from iOS 17, it's a two-way binding: SwiftUI writes the leading-most card's id as the user scrolls (the dots read it), and the button writes `visibleID = offers.first?.id` to scroll back. It needs `scrollTargetLayout()` on the `LazyHStack`. `ScrollPosition` would add edges and offsets, but it's iOS 18.
````

````exercise
id: m39-l03-e4
type: solve
prompt: |
  Extend the snapping model with a limit: in compact width, Apple's view-aligned behavior limits how many views one gesture scrolls by default. Model "at most one card per gesture": given the card targets, the offset where the gesture started and the predicted end, first find the nearest target, then clamp it so it's at most one target away from the target the gesture started on.

  Write `settleLimited(start:predicted:targets:)` and print the result for these gestures over targets `[0, 276, 552, 828, 1012]`:

  ```swift
  for (start, predicted) in [(0.0, 900.0), (552.0, 0.0), (276.0, 300.0), (828.0, 1100.0)] {
      print(Int(start), "→", Int(settleLimited(start: start, predicted: predicted, targets: targets)))
  }
  ```
starter: |
  func settle(predicted: Double, targets: [Double]) -> Double {
      targets.min { abs($0 - predicted) < abs($1 - predicted) } ?? predicted
  }

  func settleLimited(start: Double, predicted: Double, targets: [Double]) -> Double {
      // your code
      predicted
  }

  let targets: [Double] = [0, 276, 552, 828, 1012]
hints:
  - "Work with indexes: the start index is the index of settle(predicted: start, ...)."
  - "Clamp the end index to startIndex − 1 ... startIndex + 1, and to the array's bounds."
rubric:
  - Finds the starting card and the unlimited target by index.
  - Clamps the target index to within one card of the start, inside the array's bounds.
  - Returns the offset of the clamped target.
  - Prints the four expected lines.
solution: |
  ```swift
  func settle(predicted: Double, targets: [Double]) -> Double {
      targets.min { abs($0 - predicted) < abs($1 - predicted) } ?? predicted
  }

  func nearestIndex(_ offset: Double, _ targets: [Double]) -> Int {
      targets.indices.min { abs(targets[$0] - offset) < abs(targets[$1] - offset) } ?? 0
  }

  /// A model of a view-aligned behavior limited to one view per gesture.
  func settleLimited(start: Double, predicted: Double, targets: [Double]) -> Double {
      let startIndex = nearestIndex(start, targets)
      let wanted = nearestIndex(predicted, targets)
      let lower = max(startIndex - 1, 0)
      let upper = min(startIndex + 1, targets.count - 1)
      return targets[min(max(wanted, lower), upper)]
  }

  let targets: [Double] = [0, 276, 552, 828, 1012]
  for (start, predicted) in [(0.0, 900.0), (552.0, 0.0), (276.0, 300.0), (828.0, 1100.0)] {
      print(Int(start), "→", Int(settleLimited(start: start, predicted: predicted, targets: targets)))
  }
  ```

  ```output
  0 → 276
  552 → 276
  276 → 276
  828 → 1012
  ```

  A flick from the first card toward 900 would reach the fourth card, but the limit allows only the next one, 276. A flick back from 552 to 0 stops at 276. A small drag from 276 to 300 settles back on 276, and from 828 the end (1012) is one target away, so it's allowed. Apple's page says only that the behavior "limits the number of views it scrolls" in compact size classes and that `.always` allows "only a few views" at a time; "one" is this model's simplification. `ViewAlignedScrollTargetBehavior.LimitBehavior` also has `alwaysByOne` ("to a single view") and `alwaysByFew`, both iOS 18.
````

````exercise
id: m39-l03-e5
type: find-errors
prompt: "A photo strip that should snap to each photo and report which one is showing. Which of these are real problems?"
code: |
  struct PhotoStrip: View {
      let photos: [Photo]
      @State private var currentID: Photo.ID?

      var body: some View {
          ScrollViewReader { proxy in
              ScrollView(.horizontal) {
                  LazyHStack(spacing: 8) {
                      ForEach(photos) { photo in
                          PhotoView(photo: photo)
                              .frame(width: 300)
                      }
                  }
              }
              .scrollTargetBehavior(.paging)
              .scrollPosition(id: $currentID)
              .onAppear { proxy.scrollTo(photos.last?.id) }
          }
      }
  }
choices:
  - text: "There's no scrollTargetLayout(), so scrollPosition(id:) has no views to track."
    correct: true
    why: "Both scrollPosition and view-aligned settling read the views of the scroll target layout."
  - text: ".paging settles on container-width boundaries, so 300-point photos stop cut off."
    correct: true
    why: "Use .viewAligned for views narrower than the container."
  - text: "frame(width: 300) ignores the device width; containerRelativeFrame adapts."
    correct: true
    why: "On a wide iPad a 300-point photo strip wastes space; on a small phone the peek changes."
  - text: "ScrollViewReader isn't needed: defaultScrollAnchor(.trailing) or writing currentID scrolls to the last photo."
    correct: true
    why: "With scrollPosition(id:) in place, setting the binding scrolls; the reader is redundant."
  - text: "LazyHStack can't be used inside a horizontal ScrollView."
    correct: false
    why: "That's exactly its use."
rubric:
  - Flags the missing scrollTargetLayout.
  - Flags .paging with narrower views.
  - Flags the fixed width.
  - Notes the reader is redundant.
solution: |
  Four real problems. A fixed version:

  ```swift ios
  import SwiftUI

  struct Photo: Identifiable {
      let id: Int
      let name: String
  }

  struct PhotoView: View {
      let photo: Photo

      var body: some View {
          Text(photo.name)
              .frame(maxWidth: .infinity, minHeight: 200)
              .background(.quaternary, in: RoundedRectangle(cornerRadius: 22))
      }
  }

  struct PhotoStrip: View {
      let photos: [Photo]
      @State private var currentID: Photo.ID?

      var body: some View {
          ScrollView(.horizontal) {
              LazyHStack(spacing: 8) {
                  ForEach(photos) { photo in
                      PhotoView(photo: photo)
                          .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 8)
                  }
              }
              .scrollTargetLayout()
          }
          .scrollTargetBehavior(.viewAligned)
          .scrollPosition(id: $currentID)
          .defaultScrollAnchor(.trailing)
          .safeAreaPadding(.horizontal, 16)
      }
  }
  ```

  `scrollTargetLayout()` gives both the binding and the snapping their targets. `.viewAligned` settles on each photo. `containerRelativeFrame` sizes them from the scroll view. And `defaultScrollAnchor(.trailing)` starts at the last photo without a reader or an `onAppear` that runs once per identity.
````

````exercise
id: m39-l03-e6
type: fill-in
prompt: "Complete the iOS 18 code that starts a chat at the bottom, shows which message is at the top, and jumps to the newest on demand."
code: |
  @State private var position = [[1]](idType: Message.ID.self)

  var body: some View {
      ScrollView {
          LazyVStack {
              ForEach(messages) { MessageRow(message: $0) }
          }
          .[[2]]()
      }
      .defaultScrollAnchor(.bottom)
      .scrollPosition($position)
      .toolbar {
          Text("Top: \(position.[[3]](type: Message.ID.self) ?? 0)")
          Button("Newest") {
              position.scrollTo([[4]]: .bottom)
          }
      }
  }
blanks:
  - id: "1"
    answers: ["ScrollPosition"]
  - id: "2"
    answers: ["scrollTargetLayout"]
  - id: "3"
    answers: ["viewID"]
  - id: "4"
    answers: ["edge"]
hints:
  - "The iOS 18 type that holds a view id, an edge or a point."
  - "The method that reads the current id needs the id's type."
solution: |
  ```swift ios 18.0
  import SwiftUI

  struct Message: Identifiable {
      let id: Int
      let text: String
  }

  struct MessageRow: View {
      let message: Message

      var body: some View {
          Text(message.text)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal)
      }
  }

  struct ChatScreen: View {
      let messages: [Message]
      @State private var position = ScrollPosition(idType: Message.ID.self)

      var body: some View {
          ScrollView {
              LazyVStack {
                  ForEach(messages) { MessageRow(message: $0) }
              }
              .scrollTargetLayout()
          }
          .defaultScrollAnchor(.bottom)
          .scrollPosition($position)
          .toolbar {
              Text("Top: \(position.viewID(type: Message.ID.self) ?? 0)")
              Button("Newest") {
                  position.scrollTo(edge: .bottom)
              }
          }
      }
  }
  ```

  `ScrollPosition(idType:)` creates a position that tracks `Int` ids from the `scrollTargetLayout()`. `viewID(type:)` reads the top-most visible message's id, and `scrollTo(edge: .bottom)` jumps to the end without needing the last id.
````

````exercise
id: m39-l03-e7
type: design
prompt: "A product detail screen has a large image gallery at the top (one image per screen width, swipeable), a page indicator, and a navigation bar that should become opaque once the gallery has scrolled out of view. The app supports iOS 17 and 18. Describe the APIs you'd use for each part, what you'd do on iOS 17 for the part that needs iOS 18, and how you'd keep scrolling cheap."
rubric:
  - Gallery with LazyHStack, containerRelativeFrame(.horizontal), scrollTargetLayout and .paging (or .viewAligned).
  - Page indicator from scrollPosition(id:) bound to an optional id, with an accessibility label.
  - Navigation bar change with onScrollGeometryChange transformed to a Bool, behind if #available(iOS 18.0, *).
  - An iOS 17 fallback (bar always visible, or onGeometryChange on the gallery, iOS 16+) and a reason.
  - Mentions keeping the action's value small so few updates happen.
solution: |
  A sample answer:

  - **Gallery:** a horizontal `ScrollView` with a `LazyHStack(spacing: 0)` of images, each `containerRelativeFrame(.horizontal)` so it's one screen wide, `scrollTargetLayout()` on the stack, and `scrollTargetBehavior(.paging)` because pages are exactly container-wide.
  - **Indicator:** `scrollPosition(id: $imageID)` (iOS 17) on the gallery; the dots read `imageID`, treating `nil` as the first image, and are one accessibility element ("Image 2 of 6").
  - **Navigation bar:** on iOS 18, `onScrollGeometryChange(for: Bool.self)` on the *vertical* page scroll view, transforming to "has the user scrolled past the gallery's height?", setting a `Bool` that drives the bar's background (`toolbarBackgroundVisibility(_:for:)` is the iOS 18 modifier for that). Wrapped in a `ViewModifier` with `if #available(iOS 18.0, *)`. On iOS 17, either leave the bar visible (simplest, and correct), or use `onGeometryChange(for:of:action:)` (iOS 16) on the gallery to read its frame in the scroll view's coordinate space and transform it to the same `Bool`.
  - **Cost:** every transform returns a `Bool` or an id, never a raw offset, so the actions run a handful of times per scroll and only the toolbar and dots re-evaluate.
````

## Summary

- `ScrollViewReader` (iOS 14) scrolls on command but can't report the position; never use its proxy inside the content builder.
- `scrollPosition(id:anchor:)` (iOS 17) binds an optional id both ways; it needs `scrollTargetLayout()` on the stack inside the scroll view.
- `ScrollPosition` (iOS 18) adds edges, points, `viewID(type:)` and `isPositionedByUser`. `defaultScrollAnchor(.bottom)` starts a chat at the end.
- `containerRelativeFrame(_:count:span:spacing:)` sizes items from the nearest container with Apple's formula; no `GeometryReader`.
- `.paging` settles on container-sized boundaries, `.viewAligned` on the scroll target views, limited per gesture in compact size classes by default.
- `onScrollGeometryChange` (iOS 18) calls its action only when the transformed value changes; transform to the smallest value that drives the UI. Gate iOS 18 modifiers with `if #available` in a `ViewModifier`.
