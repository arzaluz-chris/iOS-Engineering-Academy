---
id: m38-l01
title: Gestures in SwiftUI
description: "Module 27 built gestures out of UIKit recognizers and delegate methods. SwiftUI describes them as values attached to views. You handle taps the accessible way, drag a card with @GestureState so the live offset resets on its own, decide at the end of a drag with the predicted end translation, use long press, MagnifyGesture and RotateGesture (iOS 17), combine gestures with simultaneously, sequenced and exclusively, and control which gesture wins when a parent and a child both want the touch."
module: m38
order: 1
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l06, m35-l06, m27-l03]
objectives:
  - Choose between Button, onTapGesture and onTapGesture with a location, and make the whole shape of a view tappable with contentShape.
  - Drag a view with DragGesture, keeping the live offset in @GestureState and committing the final offset in @State.
  - Decide what happens at the end of a drag from its translation and predicted end translation.
  - Track pinch and rotation with MagnifyGesture and RotateGesture instead of the deprecated MagnificationGesture and RotationGesture.
  - Combine gestures with simultaneously(with:), sequenced(before:) and exclusively(before:), and read the combined value.
  - Control precedence between a parent's and a child's gestures with gesture, highPriorityGesture, simultaneousGesture and GestureMask.
terms:
  - term: Gesture
    definition: "A value conforming to the Gesture protocol (TapGesture, DragGesture, LongPressGesture, MagnifyGesture…) that you attach to a view with gesture(_:). It reports changes through updating(_:body:), onChanged(_:) and onEnded(_:)."
  - term: "@GestureState"
    definition: "A property wrapper for transient state that a gesture updates through updating(_:body:). When the gesture ends or is cancelled, SwiftUI resets it to its initial value without calling your code."
  - term: Translation
    definition: "DragGesture.Value.translation: the total distance from where the drag started to the current touch, not the distance since the last event."
  - term: Predicted end translation
    definition: "DragGesture.Value.predictedEndTranslation: where the drag would end, based on its current velocity, if the finger lifted now. Used to honor flicks."
  - term: Gesture composition
    definition: "Building one gesture out of two: simultaneously (both recognized at once), sequenced (the second only after the first succeeds) or exclusively (only one succeeds, the first has precedence)."
  - term: Gesture precedence
    definition: "Which gesture handles a touch when a view and its subviews both have gestures. gesture(_:) has lower precedence than the subviews' gestures; highPriorityGesture(_:) has higher; simultaneousGesture(_:) lets both run."
mastery:
  - Replace an onTapGesture on an icon with a Button and say what VoiceOver gains.
  - Write a draggable card whose offset is committed state plus @GestureState, and explain why it never jumps or accumulates.
  - Write the decision function for a swipe-to-dismiss that honors both a long drag and a short, fast flick.
  - Build a pinch-and-rotate photo view with MagnifyGesture and RotateGesture combined simultaneously.
  - Turn a long press followed by a drag into an enum of states using SequenceGesture's value.
  - Make a parent's tap win over a child's tap, or let both run, and say which modifier does each.
resources: [uikit-gesture-state-machine, swiftui-state, swift-book-enumerations, hig]
cards:
  - id: m38-l01-c1
    front: "@GestureState vs @State in a drag?"
    back: "@GestureState holds the live translation and resets to its initial value by itself when the gesture ends or is cancelled. @State holds the committed offset, updated in onEnded. The view shows committed + live, so nothing accumulates and a cancelled drag snaps back."
  - id: m38-l01-c2
    front: Why prefer Button over onTapGesture for an action?
    back: "A Button gets the button trait, a pressed appearance, keyboard and Switch Control activation, and is announced as a button by VoiceOver. onTapGesture only reacts to touches. Use onTapGesture for things that aren't controls, such as tapping a spot on a canvas."
  - id: m38-l01-c3
    front: "MagnificationGesture and RotationGesture today?"
    back: "Use MagnifyGesture (value.magnification) and RotateGesture (value.rotation), both iOS 17. Apple's current documentation marks the older two as deprecated."
  - id: m38-l01-c4
    front: simultaneously, sequenced, exclusively?
    back: "simultaneously(with:): both recognized at once (pinch and rotate). sequenced(before:): the second gets events only after the first succeeds (long press, then drag). exclusively(before:): only one succeeds, and the first has precedence (double tap before single tap)."
  - id: m38-l01-c5
    front: A parent and child both have a tap gesture. Who wins?
    back: "With .gesture on the parent, the child wins: gesture(_:) has lower precedence than the view's own subview gestures. .highPriorityGesture makes the parent win. .simultaneousGesture lets both fire."
---

## The idea in one sentence

A SwiftUI gesture is **a value you attach to a view**: it turns touches into a stream of values, and your job is to decide which values are temporary (they reset when the finger lifts) and which ones change the app's state.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so no gesture here was tried on a device. Behavior comes from Apple's pages for `Gesture`, `GestureState`, `DragGesture`, `LongPressGesture`, `MagnifyGesture`, `RotateGesture`, `gesture(_:including:)`, `highPriorityGesture(_:including:)`, `simultaneousGesture(_:including:)`, `GestureMask`, and the articles "Adding interactivity with gestures" and "Composing SwiftUI gestures," read in November 2026. The state models and decision functions are plain Swift, compiled and run with Swift 6.3. Module 27, lesson 3 covered the same ideas with UIKit recognizers.

## What changes from UIKit

In Module 27 you created a recognizer object, added it to a view, and switched on its `state` in an action method. SwiftUI keeps the ideas and drops the object:

| UIKit (Module 27) | SwiftUI |
| --- | --- |
| `UITapGestureRecognizer` | `onTapGesture`, `TapGesture`, or better, a `Button` |
| `UIPanGestureRecognizer`, `translation(in:)` | `DragGesture`, `value.translation` |
| `UILongPressGestureRecognizer` | `onLongPressGesture`, `LongPressGesture` |
| `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer` | `MagnifyGesture`, `RotateGesture` (iOS 17) |
| `.began` / `.changed` / `.ended` / `.cancelled` | `updating(_:body:)`, `onChanged(_:)`, `onEnded(_:)` |
| `shouldRecognizeSimultaneouslyWith` | `simultaneously(with:)`, `simultaneousGesture(_:)` |
| `require(toFail:)` | `exclusively(before:)` |

Apple's "Adding interactivity with gestures" lists three callbacks, and the difference between them is the core of this lesson:

- **`updating(_:body:)`** writes into a `@GestureState` property. SwiftUI "invokes the updating callback as soon as it recognizes the gesture and whenever the value of the gesture changes," and "doesn't invoke the updating callback when the user ends or cancels a gesture. Instead, the gesture state property automatically resets its state back to its initial value."
- **`onChanged(_:)`** runs on every change, for state that "shouldn't reset once the gesture ends."
- **`onEnded(_:)`** runs once, and only when the gesture succeeds. A long press that's released early, for example, never calls it.

## Taps

The first question isn't which gesture. It's whether you need one:

```swift ios
import SwiftUI

struct RecipeRow: View {
    let title: String
    @Binding var isFavorite: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                isFavorite.toggle()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }
}
```

The heart could have been `Image(...).onTapGesture { isFavorite.toggle() }`. It would respond to a finger the same way, but a `Button` also gets the button trait (VoiceOver says "button"), a pressed appearance, and activation from a hardware keyboard, Switch Control and Voice Control. An `onTapGesture` gets none of that. **If tapping performs an action, it's a button.**

`onTapGesture` is the right tool when the tap isn't a control: tapping a canvas to drop a pin, tapping a photo to hide the chrome. iOS 17 added `onTapGesture(count:coordinateSpace:perform:)`, which passes the tap's location:

```swift ios
import SwiftUI

struct PinBoard: View {
    @State private var pins: [CGPoint] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.yellow.opacity(0.15)
            ForEach(pins.indices, id: \.self) { index in
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .position(pins[index])
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            pins.append(location)
        }
        .accessibilityElement()
        .accessibilityLabel("Pin board")
        .accessibilityValue("\(pins.count) pins")
    }
}
```

- **`location`** is in the view's local coordinate space by default, so it can go straight into `.position(_:)`.
- **`.contentShape(Rectangle())`** defines the hit-testing area. Without it, only the parts of a view that draw something receive taps; the gaps in an `HStack` with a `Spacer`, or a transparent area, don't. Here the yellow fill already covers the board, but on a row made of text and a `Spacer` it's the difference between "the row is tappable" and "only the words are."
- **Accessibility.** VoiceOver users can't aim at a spot on a canvas. `accessibilityElement()` makes the board one element so the label and value have somewhere to go; a named accessibility action (lesson 5) that drops a pin in the center would make the feature usable without aiming.

## Dragging: committed state plus gesture state

A draggable card has two offsets: where it **rests** and how far the finger has **moved it right now**. They live in different property wrappers:

```swift ios
import SwiftUI

struct DraggableCard: View {
    @State private var restingOffset = CGSize.zero
    @GestureState private var dragOffset = CGSize.zero

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.orange.gradient)
            .frame(width: 200, height: 120)
            .offset(x: restingOffset.width + dragOffset.width,
                    y: restingOffset.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        restingOffset.width += value.translation.width
                        restingOffset.height += value.translation.height
                    }
            )
    }
}
```

Line by line:

- **`@GestureState private var dragOffset`** is the live part. `updating($dragOffset)` gives you an `inout` copy of it (`state`) to write on each change. The third parameter is the update's `Transaction`, which you could use to animate it; it's ignored here.
- **`value.translation`** is "the total translation from the start of the drag gesture to the current event." It's a total, not a delta, so you assign it; you never add it. That's the same rule Module 27 taught for `translation(in:)`.
- **`onEnded`** adds the final translation to `restingOffset`. At the same time, SwiftUI resets `dragOffset` to `.zero`. The sum the view displays doesn't change at that moment, so the card doesn't jump.
- **Cancellation is free.** If the system cancels the drag (an incoming call, a system gesture), `onEnded` isn't called and `dragOffset` still resets. The card returns to where it rested. In UIKit you had to remember the `.cancelled` case; here forgetting it isn't possible.

`DragGesture()` starts recognizing after the finger moves 10 points (`minimumDistance` defaults to 10). Pass `DragGesture(minimumDistance: 0)` to track from the first touch, which also means it competes with taps on the same view.

Here's that bookkeeping as plain Swift, so you can see the numbers. `Size` stands in for `CGSize`:

```swift
struct Size: CustomStringConvertible {
    var width = 0.0, height = 0.0
    var description: String { "(\(Int(width)), \(Int(height)))" }
}

/// The two pieces of state behind DraggableCard.
struct CardDrag {
    var resting = Size()   // @State: changes only in onEnded
    var live = Size()      // @GestureState: reset by SwiftUI when the gesture stops

    var displayed: Size {
        Size(width: resting.width + live.width, height: resting.height + live.height)
    }

    mutating func changed(translation: Size) {  // updating(_:body:)
        live = translation
    }

    mutating func ended(translation: Size) {    // onEnded, then the reset
        resting.width += translation.width
        resting.height += translation.height
        live = Size()
    }

    mutating func cancelled() {                 // no callback, only the reset
        live = Size()
    }
}

var card = CardDrag()
card.changed(translation: Size(width: 30, height: 0))
card.changed(translation: Size(width: 80, height: 10))
print("dragging:", card.displayed)
card.ended(translation: Size(width: 80, height: 10))
print("after first drag:", card.displayed)

card.changed(translation: Size(width: -20, height: 40))
print("second drag:", card.displayed)
card.cancelled()
print("after cancel:", card.displayed)
```

```output
dragging: (80, 10)
after first drag: (80, 10)
second drag: (60, 50)
after cancel: (80, 10)
```

The second drag starts from (80, 10) and its translation is measured from where *it* started, so (−20, 40) shows the card at (60, 50). When it's cancelled, only the live part goes away.

> [!tip] Animating the reset
> A cancelled drag snaps back instantly. To animate it, declare the property with a reset transaction, `@GestureState(resetTransaction: Transaction(animation: .snappy)) private var dragOffset = CGSize.zero`; Apple's `GestureState` page lists initializers that take one. It applies to every reset.

### Deciding when the finger lifts

Swipe-to-dismiss, a bottom sheet with detents, a card that's either kept or thrown away: they all decide in `onEnded`. Distance alone feels wrong. A user who flicks quickly moves the finger only a short way but clearly means "throw it." `DragGesture.Value` has `predictedEndTranslation`: "A prediction, based on the current drag velocity, of what the final translation will be if dragging stopped now." Use both:

```swift
enum SwipeOutcome: String {
    case snapBack, dismissLeft, dismissRight
}

/// Decides a horizontal swipe on a card of the given width.
/// Dismiss when the card was dragged past half its width,
/// or when the flick would carry it past its full width.
func swipeOutcome(translation: Double, predictedEnd: Double, cardWidth: Double) -> SwipeOutcome {
    let distanceThreshold = cardWidth / 2
    let flickThreshold = cardWidth
    let goesFarEnough = abs(translation) > distanceThreshold || abs(predictedEnd) > flickThreshold
    guard goesFarEnough else { return .snapBack }
    // Use the predicted end for direction: a flick back toward the center wins.
    return predictedEnd < 0 ? .dismissLeft : .dismissRight
}

let samples: [(String, Double, Double)] = [
    ("slow, short", 120, 140),
    ("slow, long", 220, 230),
    ("quick flick", 70, 480),
    ("long, flicked back", 210, -420),
    ("hesitant", -150, -170),
]
for (name, translation, predicted) in samples {
    print(name, "->", swipeOutcome(translation: translation, predictedEnd: predicted, cardWidth: 340).rawValue)
}
```

```output
slow, short -> snapBack
slow, long -> dismissRight
quick flick -> dismissRight
long, flicked back -> dismissLeft
hesitant -> snapBack
```

- **"quick flick"** moved only 70 points, but the predicted end is 480, past the card's width.
- **"long, flicked back"** is past the distance threshold to the right, yet the finger was moving fast to the left when it lifted. Taking the direction from the prediction respects what the user did last. Whether that case should dismiss at all or snap back is a design decision; the function makes it explicit and testable.
- **The thresholds** (half the width, the full width) are a starting point to tune on a device, not values from Apple.

In the view, `onEnded` calls the function with `value.translation.width` and `value.predictedEndTranslation.width`, then sets state inside `withAnimation`. The function itself has no SwiftUI in it, so it can be unit tested.

## Long press

For "do something after holding," `onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)` is the short form. Its defaults are a 0.5-second duration and a 10-point maximum distance, the same as UIKit's. `onPressingChanged` reports when the finger goes down and when it lifts or moves too far, which is where pressed feedback goes:

```swift ios
import SwiftUI

struct HoldToConfirm: View {
    @State private var isPressing = false
    @State private var confirmedCount = 0

    var body: some View {
        Text(isPressing ? "Keep holding…" : "Hold to delete")
            .padding()
            .background(isPressing ? Color.red.opacity(0.3) : Color.gray.opacity(0.2),
                        in: Capsule())
            .scaleEffect(isPressing ? 0.95 : 1)
            .animation(.snappy, value: isPressing)
            .onLongPressGesture(minimumDuration: 1) {
                confirmedCount += 1
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Delete") {
                confirmedCount += 1
            }
    }
}
```

The `accessibilityAction` matters: holding for a second is hard or impossible for some people, and VoiceOver users trigger actions differently. Lesson 5 covers actions properly.

The `LongPressGesture` value type does the same job when you need to compose it or drive `@GestureState`; Apple's `GestureState` example writes `state = currentState` in `updating` to color a circle while it's pressed.

## Pinch and rotate

iOS 17 introduced `MagnifyGesture` and `RotateGesture`. The older `MagnificationGesture` and `RotationGesture` still exist, but Apple's current documentation marks them deprecated; use the new ones. Their values are `value.magnification` (a scale factor, 1 at the start) and `value.rotation` (an `Angle`).

Like translation, both are **totals since the gesture began**, so the same committed-plus-live pattern applies, with multiplication for the scale:

```swift ios
import SwiftUI

struct ZoomablePhoto: View {
    @State private var scale = 1.0
    @State private var angle = Angle.zero
    @GestureState private var liveScale = 1.0
    @GestureState private var liveAngle = Angle.zero

    var body: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .frame(width: 200)
            .scaleEffect(scale * liveScale)
            .rotationEffect(angle + liveAngle)
            .gesture(
                MagnifyGesture()
                    .updating($liveScale) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        scale = min(max(scale * Double(value.magnification), 1), 4)
                    }
                    .simultaneously(with:
                        RotateGesture()
                            .updating($liveAngle) { value, state, _ in
                                state = value.rotation
                            }
                            .onEnded { value in
                                angle += value.rotation
                            }
                    )
            )
            .accessibilityLabel("Photo")
    }
}
```

- **`scale * liveScale`**: pinching to 2× on a photo already at 1.5× shows 3×. Adding instead of multiplying would show 3.5× and feel wrong.
- **Clamping happens at the end**, so the pinch can overshoot while the fingers are down and settles into 1…4 when they lift. With `withAnimation` around the clamp it would spring back; that's the next lesson.
- **`simultaneously(with:)`** combines them so pinching and rotating work in the same two-finger gesture. Without it, whichever gesture recognized first would claim the touches.

## Composing gestures

Apple's "Composing SwiftUI gestures" names three kinds of composition:

- **Simultaneous.** `a.simultaneously(with: b)`: both can be recognized at the same time. Its value has optional `first` and `second`, because either can be missing at a given moment.
- **Sequenced.** `a.sequenced(before: b)`: "the second gesture only receiving events after the first gesture succeeds." Apple's example is a long press followed by a drag, so a view only moves after the user has deliberately picked it up.
- **Exclusive.** `a.exclusively(before: b)`: "only one gesture succeeds, giving precedence to the first gesture." The classic use is a double tap that shouldn't also count as a single tap: `TapGesture(count: 2).exclusively(before: TapGesture())`.

The sequenced value is an enum with two cases, documented on `SequenceGesture.Value`: `.first(First.Value)` while the first gesture hasn't ended, and `.second(First.Value, Second.Value?)` once it has. The second payload is optional because the drag may not have started yet. Apple's article converts it into its own `DragState` enum in `updating`. Here is that conversion in plain Swift, with a `Double` standing in for the drag's translation:

```swift
/// Mirrors SequenceGesture<LongPressGesture, DragGesture>.Value.
/// LongPressGesture's value is a Bool; the drag's value is optional until it starts.
enum PressThenDragValue {
    case first(Bool)
    case second(Bool, Double?)
}

enum DragState: Equatable {
    case inactive
    case pressing
    case dragging(translation: Double)
}

func dragState(for value: PressThenDragValue) -> DragState {
    switch value {
    case .first(true):
        return .pressing                                    // holding, not yet long enough
    case .second(true, let drag):
        return .dragging(translation: drag ?? 0)            // picked up; may not have moved
    default:
        return .inactive
    }
}

let events: [PressThenDragValue] = [.first(true), .second(true, nil), .second(true, 35), .second(true, 120)]
for event in events {
    print(dragState(for: event))
}
```

```output
pressing
dragging(translation: 0.0)
dragging(translation: 35.0)
dragging(translation: 120.0)
```

The view stores `DragState` in `@GestureState`, so it returns to `.inactive` by itself when the finger lifts, and commits the translation in `onEnded` with `guard case .second(true, let drag?) = value`, as in Apple's example. The enum makes the view's code read like the interaction: a shadow while `.pressing`, a border while `.dragging`.

## Who gets the touch

When a view has a gesture and a subview has one too, SwiftUI has to pick. The modifier you use on the parent decides:

- **`gesture(_:)`** attaches a gesture "with a lower precedence than gestures defined by the view." The subview's gesture wins.
- **`highPriorityGesture(_:)`** attaches it "with a higher precedence than gestures defined by the view." The parent's wins.
- **`simultaneousGesture(_:)`** processes it "simultaneously with gestures defined by the view." Both run.

All three take an `including:` mask. `GestureMask` has four values: `.all` (the default: the added gesture and the subviews' gestures), `.gesture` (only the added one; subview gestures are disabled), `.subviews` (only the subviews'; the added one is disabled), and `.none`.

As a model, for a tap on a child that has its own tap gesture inside a parent with another:

```swift
enum ParentAttachment: String {
    case gesture, highPriorityGesture, simultaneousGesture
}

enum Mask: String {
    case all, gesture, subviews, none
}

/// Which tap handlers run when the user taps the child.
func handlers(parent: ParentAttachment, mask: Mask = .all) -> [String] {
    let parentEnabled = mask == .all || mask == .gesture
    let childEnabled = mask == .all || mask == .subviews
    switch (parentEnabled, childEnabled) {
    case (false, false): return []
    case (true, false): return ["parent"]
    case (false, true): return ["child"]
    case (true, true):
        switch parent {
        case .gesture: return ["child"]
        case .highPriorityGesture: return ["parent"]
        case .simultaneousGesture: return ["child", "parent"]
        }
    }
}

for attachment in [ParentAttachment.gesture, .highPriorityGesture, .simultaneousGesture] {
    print(attachment.rawValue, handlers(parent: attachment))
}
print("gesture, including: .gesture", handlers(parent: .gesture, mask: .gesture))
print("gesture, including: .subviews", handlers(parent: .gesture, mask: .subviews))
```

```output
gesture ["child"]
highPriorityGesture ["parent"]
simultaneousGesture ["child", "parent"]
gesture, including: .gesture ["parent"]
gesture, including: .subviews ["child"]
```

> [!warning] A model
> Real precedence is decided per gesture, among all the gestures that recognize the same touches, and `ScrollView`, `List` and controls take part too. The model keeps the rule from Apple's pages that you use most: the modifier on the parent decides whether the parent's gesture yields, wins, or runs alongside.

Two cases you'll meet:

- **A row with a tap and a button inside it.** With `.onTapGesture` on the row, which attaches a tap gesture at normal precedence, tapping the button usually runs the button's action, not the row's. That's usually what you want; check it on a device when the row sits inside a `List`, which adds its own row selection.
- **A drag inside a scroll view.** A `DragGesture` attached with `.gesture` inside a `ScrollView` competes with scrolling. If the drag starts immediately (`minimumDistance: 0`) or is attached with `highPriorityGesture`, the user may not be able to scroll by touching that view. Test it on a device; prefer system components (swipe actions on a `List` row, for example) where they fit.

## Common mistakes

> [!error] Adding the translation in onChanged
> `.onChanged { offset.width += value.translation.width }` adds the total translation again on every event, so the view runs away from the finger. Translation is a total since the gesture began: assign it to `@GestureState` in `updating`, and add it once in `onEnded`.

> [!error] A drag that leaves the view stuck mid-way
> Keeping the live offset in `@State` and resetting it in `onEnded` works until a drag is cancelled: `onEnded` doesn't run, and the view stays wherever the finger was. `@GestureState` resets on cancellation too.

> [!error] onTapGesture as a button
> An icon with `.onTapGesture` looks and works like a button for someone tapping with a finger, and is invisible as a control to VoiceOver, keyboards and Switch Control. Use `Button`, styled however you like.

> [!error] Single tap and double tap both firing
> Two separate `onTapGesture` modifiers for count 1 and count 2 can both run on a double tap. Make the relationship explicit with `TapGesture(count: 2).exclusively(before: TapGesture())`, and read which one succeeded in `onEnded` from the `.first` or `.second` case.

> [!error] Using MagnificationGesture in new code
> Tutorials still use `MagnificationGesture` and `RotationGesture`. Apple's documentation marks them deprecated; with an iOS 17 deployment target use `MagnifyGesture` and `RotateGesture`, whose values are `magnification` and `rotation`.

> [!error] A gesture that's the only way to do something
> Long press, pinch, double tap and swipe are invisible: nothing on screen says they exist, and some people can't perform them. Every gesture-only feature needs a visible alternative (a menu item, a button) or an accessibility action.

## Exercises

````exercise
id: m38-l01-e1
type: prediction
prompt: "The committed-plus-live model from the lesson, with a different sequence of drags. What does it print?"
code: |
  struct Size: CustomStringConvertible {
      var width = 0.0, height = 0.0
      var description: String { "(\(Int(width)), \(Int(height)))" }
  }

  struct CardDrag {
      var resting = Size()
      var live = Size()

      var displayed: Size {
          Size(width: resting.width + live.width, height: resting.height + live.height)
      }

      mutating func changed(translation: Size) { live = translation }

      mutating func ended(translation: Size) {
          resting.width += translation.width
          resting.height += translation.height
          live = Size()
      }

      mutating func cancelled() { live = Size() }
  }

  var card = CardDrag()
  card.changed(translation: Size(width: 0, height: 50))
  card.cancelled()
  print(card.displayed)
  card.changed(translation: Size(width: 10, height: 20))
  card.changed(translation: Size(width: 40, height: 60))
  card.ended(translation: Size(width: 40, height: 60))
  card.changed(translation: Size(width: 5, height: -60))
  print(card.displayed)
  card.ended(translation: Size(width: 5, height: -60))
  print(card.resting, card.live)
output: |
  (0, 0)
  (45, 0)
  (45, 0) (0, 0)
hints:
  - "A cancelled drag changes nothing that stays."
  - "Each changed(translation:) replaces live; it doesn't add to it."
solution: |
  ```output
  (0, 0)
  (45, 0)
  (45, 0) (0, 0)
  ```

  The first drag is cancelled, so only `live` is reset and the card is back at (0, 0). The second drag's last translation, (40, 60), is committed once in `ended`. The third drag shows resting (40, 60) plus live (5, −60) = (45, 0), and ending it commits that, leaving `live` at zero. The middle `changed` call with (10, 20) never affects the result because the next call replaces it: that's why you assign translation instead of adding it.
````

````exercise
id: m38-l01-e2
type: prediction
prompt: "The swipe decision from the lesson on a narrower card. What does it print?"
code: |
  enum SwipeOutcome: String {
      case snapBack, dismissLeft, dismissRight
  }

  func swipeOutcome(translation: Double, predictedEnd: Double, cardWidth: Double) -> SwipeOutcome {
      let goesFarEnough = abs(translation) > cardWidth / 2 || abs(predictedEnd) > cardWidth
      guard goesFarEnough else { return .snapBack }
      return predictedEnd < 0 ? .dismissLeft : .dismissRight
  }

  let width = 200.0
  print(swipeOutcome(translation: 90, predictedEnd: 150, cardWidth: width).rawValue)
  print(swipeOutcome(translation: -40, predictedEnd: -260, cardWidth: width).rawValue)
  print(swipeOutcome(translation: 101, predictedEnd: 20, cardWidth: width).rawValue)
  print(swipeOutcome(translation: 100, predictedEnd: 200, cardWidth: width).rawValue)
output: |
  snapBack
  dismissLeft
  dismissRight
  snapBack
hints:
  - "The distance threshold is 100 and the flick threshold is 200. Both comparisons are strict."
solution: |
  ```output
  snapBack
  dismissLeft
  dismissRight
  snapBack
  ```

  1. 90 isn't past 100, and 150 isn't past 200: snap back.
  2. A short drag but a fast flick to the left (predicted −260): dismiss left.
  3. Past half the width (101 > 100), and the predicted end is still positive: dismiss right, even though the finger was slowing down.
  4. Exactly on both thresholds. `>` is strict, so it snaps back. Whether the boundary counts is a choice; the point is that the function decides it in one place you can test.
````

````exercise
id: m38-l01-e3
type: comprehension
prompt: "A slider-like control shows a tooltip with the current value while the user drags, and saves the final value when they let go. Where should the tooltip's visibility and the saved value live?"
choices:
  - text: "Tooltip visibility in @GestureState, set in updating(_:body:); the saved value in @State, set in onEnded(_:)."
    correct: true
    why: "The tooltip is transient and must disappear even if the drag is cancelled; @GestureState resets by itself. The saved value must persist, and onEnded only runs when the gesture succeeds."
  - text: "Both in @State, set in onChanged(_:)."
    correct: false
    why: "Nothing would hide the tooltip after a cancelled drag, and the value would be saved on every movement, not once."
  - text: "Both in @GestureState."
    correct: false
    why: "@GestureState resets to its initial value when the gesture ends, so the saved value would be lost."
  - text: "The saved value in @GestureState, the tooltip in @State."
    correct: false
    why: "That's backwards: the value would reset and the tooltip would stay."
solution: |
  **Transient in `@GestureState`, permanent in `@State`.** Apple's article puts it the same way: `updating` for "transient UI state," `onEnded` to "update permanent state when a gesture ends." A `@GestureState var isDragging = false` set to `true` in `updating` shows the tooltip and hides it automatically however the drag stops.
````

````exercise
id: m38-l01-e4
type: fill-in
prompt: "Complete the zoomable map: the live pinch is multiplied with the committed zoom, and the committed zoom is updated once when the pinch ends."
code: |
  struct ZoomableMap: View {
      @State private var zoom = 1.0
      @[[1]] private var pinch = 1.0

      var body: some View {
          Image(systemName: "map")
              .resizable()
              .scaledToFit()
              .scaleEffect(zoom * pinch)
              .gesture(
                  [[2]]()
                      .[[3]]($pinch) { value, state, _ in
                          state = value.[[4]]
                      }
                      .onEnded { value in
                          zoom *= Double(value.magnification)
                      }
              )
      }
  }
blanks:
  - id: "1"
    answers: ["GestureState"]
  - id: "2"
    answers: ["MagnifyGesture"]
  - id: "3"
    answers: ["updating"]
  - id: "4"
    answers: ["magnification"]
hints:
  - "The property wrapper that resets when the gesture ends."
  - "The iOS 17 pinch gesture, not the deprecated one."
solution: |
  ```swift ios
  import SwiftUI

  struct ZoomableMap: View {
      @State private var zoom = 1.0
      @GestureState private var pinch = 1.0

      var body: some View {
          Image(systemName: "map")
              .resizable()
              .scaledToFit()
              .scaleEffect(zoom * pinch)
              .gesture(
                  MagnifyGesture()
                      .updating($pinch) { value, state, _ in
                          state = value.magnification
                      }
                      .onEnded { value in
                          zoom *= Double(value.magnification)
                      }
              )
              .accessibilityLabel("Map")
      }
  }
  ```

  `@GestureState` holds the live factor and resets it to 1 when the fingers lift, at the same moment `onEnded` folds the final factor into `zoom`. `MagnifyGesture` (iOS 17) replaces `MagnificationGesture`; its value's `magnification` starts at 1 for each new pinch.
````

````exercise
id: m38-l01-e5
type: find-errors
prompt: "This card is meant to move with the finger, open on double tap, and select on single tap. Which of these are real problems?"
code: |
  struct NoteCard: View {
      @State private var offset = CGSize.zero
      @State private var isOpen = false
      @State private var isSelected = false

      var body: some View {
          Text("Groceries")
              .padding()
              .offset(offset)
              .onTapGesture { isSelected.toggle() }
              .onTapGesture(count: 2) { isOpen = true }
              .gesture(
                  DragGesture()
                      .onChanged { value in
                          offset.width += value.translation.width
                          offset.height += value.translation.height
                      }
              )
      }
  }
choices:
  - text: "onChanged adds the total translation on every event, so the card moves faster and faster than the finger."
    correct: true
    why: "translation is measured from the start of the drag. Assign it to @GestureState and commit it once in onEnded."
  - text: "A cancelled drag leaves the card wherever it was, because the live offset is in @State and nothing resets it."
    correct: true
    why: "@GestureState would reset on cancellation; @State doesn't."
  - text: "The single-tap and double-tap handlers aren't composed, so a double tap may also toggle selection."
    correct: true
    why: "Use TapGesture(count: 2).exclusively(before: TapGesture()) to say which one has precedence."
  - text: "Opening and selecting are actions with no accessible alternative."
    correct: true
    why: "Taps on Text aren't exposed as buttons. Add accessibility actions or use buttons and a context menu."
  - text: "DragGesture can't be attached with .gesture to a Text."
    correct: false
    why: "Any view can have a gesture."
  - text: "offset(_:) only accepts CGPoint."
    correct: false
    why: "offset(_:) takes a CGSize; offset(x:y:) takes two values."
rubric:
  - Identifies the accumulating translation.
  - Identifies that a cancelled drag isn't reset.
  - Identifies the uncomposed taps.
  - Mentions accessibility for the gesture-only actions.
  - Doesn't flag the two false claims.
solution: |
  Four problems. A corrected version:

  ```swift ios
  import SwiftUI

  struct NoteCard: View {
      @State private var restingOffset = CGSize.zero
      @GestureState private var dragOffset = CGSize.zero
      @State private var isOpen = false
      @State private var isSelected = false

      var body: some View {
          Text("Groceries")
              .padding()
              .offset(x: restingOffset.width + dragOffset.width,
                      y: restingOffset.height + dragOffset.height)
              .gesture(
                  TapGesture(count: 2)
                      .exclusively(before: TapGesture())
                      .onEnded { value in
                          switch value {
                          case .first:
                              isOpen = true
                          case .second:
                              isSelected.toggle()
                          }
                      }
              )
              .simultaneousGesture(
                  DragGesture()
                      .updating($dragOffset) { value, state, _ in
                          state = value.translation
                      }
                      .onEnded { value in
                          restingOffset.width += value.translation.width
                          restingOffset.height += value.translation.height
                      }
              )
              .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
              .accessibilityAction(named: "Open") { isOpen = true }
              .accessibilityAction { isSelected.toggle() }
      }
  }
  ```

  The drag uses the committed-plus-live pattern. The taps are one composed gesture where the double tap has precedence, and `onEnded` receives `ExclusiveGesture`'s value: `.first` when the double tap succeeded, `.second` for the single tap. The drag is attached with `simultaneousGesture` so it doesn't depend on the tap's outcome; it only starts after 10 points of movement anyway. The default accessibility action (activating the element) selects, and a named "Open" action replaces the double tap.
````

````exercise
id: m38-l01-e6
type: solve
prompt: |
  A photo viewer keeps a committed zoom and a live pinch factor, like `ZoomablePhoto`. Write:

  - `displayedZoom(committed:pinch:)`, which returns the zoom to show while pinching, with **rubber-banding**: inside 1…4 it's simply `committed * pinch`; outside, only a third of the overshoot is applied (so 5 shows as 4 + (5 − 4) / 3, and 0.4 shows as 1 − (1 − 0.4) / 3).
  - `settledZoom(committed:pinch:)`, the zoom after the fingers lift: `committed * pinch` clamped to 1…4.

  Print, for a committed zoom of 2, the displayed and settled zoom for pinch factors 0.25, 0.5, 1.5 and 3, each rounded to two decimals as `pinch 0.25: shows 0.83, settles 1.0`. Format the numbers yourself: multiply by 100, round, and print with `Double(…) / 100`.
starter: |
  func displayedZoom(committed: Double, pinch: Double) -> Double {
      // your code
      committed * pinch
  }

  func settledZoom(committed: Double, pinch: Double) -> Double {
      // your code
      committed * pinch
  }
hints:
  - "Compute raw = committed × pinch first, then compare it with the bounds."
  - "Above the maximum: max + (raw − max) / 3. Below the minimum: min − (min − raw) / 3."
  - "(x * 100).rounded() / 100 rounds to two decimals."
rubric:
  - displayedZoom returns committed × pinch inside the range and applies a third of the overshoot outside it, on both ends.
  - settledZoom clamps to 1…4.
  - Prints four lines in the requested format.
  - Keeps the functions free of SwiftUI so they can be tested.
solution: |
  ```swift
  let zoomRange = 1.0...4.0

  func displayedZoom(committed: Double, pinch: Double) -> Double {
      let raw = committed * pinch
      if raw > zoomRange.upperBound {
          return zoomRange.upperBound + (raw - zoomRange.upperBound) / 3
      }
      if raw < zoomRange.lowerBound {
          return zoomRange.lowerBound - (zoomRange.lowerBound - raw) / 3
      }
      return raw
  }

  func settledZoom(committed: Double, pinch: Double) -> Double {
      min(max(committed * pinch, zoomRange.lowerBound), zoomRange.upperBound)
  }

  func twoDecimals(_ value: Double) -> Double {
      (value * 100).rounded() / 100
  }

  for pinch in [0.25, 0.5, 1.5, 3.0] {
      let shows = twoDecimals(displayedZoom(committed: 2, pinch: pinch))
      let settles = twoDecimals(settledZoom(committed: 2, pinch: pinch))
      print("pinch \(pinch): shows \(shows), settles \(settles)")
  }
  ```

  ```output
  pinch 0.25: shows 0.83, settles 1.0
  pinch 0.5: shows 1.0, settles 1.0
  pinch 1.5: shows 3.0, settles 3.0
  pinch 3.0: shows 4.67, settles 4.0
  ```

  At 0.25 the raw zoom is 0.5, half a unit below the minimum, so it shows 1 − 0.5 / 3 ≈ 0.83: the photo resists instead of stopping dead, which tells the user they've hit the limit. When the fingers lift it settles at 1. At 3 the raw zoom is 6, shown as 4 + 2 / 3 ≈ 4.67, and it settles at 4. In the view, `scaleEffect(displayedZoom(committed: scale, pinch: liveScale))` uses the first function, and `onEnded` sets `scale = settledZoom(...)` inside `withAnimation(.snappy)` so the overshoot springs back.
````

## Summary

- Prefer `Button` for anything that performs an action. Use `onTapGesture` (with a location from iOS 17) for taps that aren't controls, and `contentShape` to define the tappable area.
- Translation, magnification and rotation are **totals since the gesture began**. Keep the live value in `@GestureState` via `updating`, commit it in `onEnded`, and display committed plus live. Cancellation then resets itself.
- Decide the end of a drag with both `translation` and `predictedEndTranslation`, in a plain function you can test.
- `MagnifyGesture` and `RotateGesture` (iOS 17) replace the deprecated `MagnificationGesture` and `RotationGesture`; multiply scales, add angles.
- `simultaneously` for gestures that happen together, `sequenced` for "first this, then that," `exclusively` for "one or the other, this one first." Map the combined value to your own enum.
- On a parent, `gesture` yields to subviews, `highPriorityGesture` wins, `simultaneousGesture` runs alongside; `GestureMask` turns either side off.
- Every gesture-only feature needs a visible or accessible alternative.
