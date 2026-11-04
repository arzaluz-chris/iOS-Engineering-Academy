---
id: m35-l06
title: Transitions and animation
description: "In SwiftUI you don't animate views, you animate state changes. You wrap a change in withAnimation or attach animation(_:value:) to a view, see which views animate and with which curve when both are involved, animate views in and out with transitions, move one view into another's place with matchedGeometryEffect and the iOS 18 zoom navigation transition, and swap motion for fades when Reduce Motion is on."
module: m35
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l05, m27-l01]
objectives:
  - Animate a state change explicitly with withAnimation and implicitly with animation(_:value:), and say which views each one affects.
  - Choose an Animation (default, easeInOut, spring with duration and bounce, smooth, snappy, bouncy) and run code when it finishes on iOS 17.
  - Animate views in and out with transition, using opacity, move, scale, asymmetric and combined transitions.
  - Make one view appear to move into another with matchedGeometryEffect, and use the iOS 18 zoom navigation transition.
  - Respect Reduce Motion by reading accessibilityReduceMotion and replacing movement with fades or no animation.
terms:
  - term: Explicit animation
    definition: "A state change wrapped in withAnimation(_:_:). SwiftUI sets the animation on the update's transaction, so every view affected by the change animates with it."
  - term: Implicit animation
    definition: "An animation attached to a view with animation(_:value:). It applies to that view (and its children) when the given value changes, whatever caused the change."
  - term: Transaction
    definition: "The context of one state update. Its animation property holds the animation for that update, if any; withAnimation sets it, and the transaction(_:) modifier can change it for part of the hierarchy."
  - term: Transition
    definition: "How a view animates when it's inserted into or removed from the hierarchy, set with transition(_:): opacity, move(edge:), scale, slide, or combinations. It needs the insertion or removal to happen inside an animation."
  - term: matchedGeometryEffect
    definition: "A modifier (iOS 14) that links views with the same id in a @Namespace. If one is inserted while another with the same id is removed in the same update, SwiftUI interpolates between their frames so it looks like one view moving."
mastery:
  - Make a favorite button bounce when tapped without animating anything else on the screen.
  - Predict which views animate, and with which animation, when withAnimation and animation(_:value:) are both present.
  - Slide a banner in from the top and fade it out, with an asymmetric transition.
  - Move a selected tag chip from one row to another with matchedGeometryEffect.
  - Turn a zoom or slide into a cross-fade when Reduce Motion is on.
resources: [uikit-reduce-motion, hig, swift-book-closures]
cards:
  - id: m35-l06-c1
    front: withAnimation vs animation(_:value:)?
    back: "withAnimation { change } animates everything the change affects, wherever it is on screen. .animation(anim, value: v) on a view animates that view's changes when v changes, whoever changed it. Use explicit for 'this action animates', implicit for 'this view always animates this property'."
  - id: m35-l06-c2
    front: Why is .animation(.easeIn) without a value a problem?
    back: "It's deprecated since iOS 15 ('Use withAnimation or animation(_:value:) instead.'). It animated every change to the view, including ones you didn't mean to animate. Always pass the value to watch."
  - id: m35-l06-c3
    front: Why doesn't my .transition(.slide) do anything?
    back: "A transition runs when the view is inserted or removed inside an animation. If the state change isn't wrapped in withAnimation (or covered by an animation modifier on a container that stays on screen), the view just appears and disappears."
  - id: m35-l06-c4
    front: matchedGeometryEffect rules?
    back: "Same id, same @Namespace. Insert one view and remove the other in the same update (one withAnimation), and SwiftUI interpolates their frames. Exactly one view per id may have isSource true at a time; otherwise Apple says results are undefined."
  - id: m35-l06-c5
    front: What should an animation do when Reduce Motion is on?
    back: "Read @Environment(\\.accessibilityReduceMotion). Apple: avoid large animations, especially ones that simulate 3D. Replace moves, zooms and scales with a cross-fade (opacity) or no animation, and keep the state change itself."
---

## The idea in one sentence

You never animate a view in SwiftUI: you **change state inside an animation**, and SwiftUI interpolates every animatable property that changed, from what was on screen to what `body` now describes.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target unless marked 18.0, Swift 6 mode), not run, so nothing here was watched on a screen. Behavior comes from Apple's pages for `withAnimation`, `animation(_:value:)`, `Animation`, `Transaction`, `transaction(_:)`, `transition(_:)`, `AnyTransition`, `matchedGeometryEffect`, `navigationTransition(_:)` and `accessibilityReduceMotion`, read in November 2026. The models of which animation applies, of frame interpolation and of the Reduce Motion policy are plain Swift, compiled and run with Swift 6.3; the first is a simplified reading of Apple's pages, not SwiftUI's implementation. Timing curves and springs were covered in Module 27, lesson 1.

## Explicit animation: withAnimation

Module 27 animated UIKit views by setting properties inside `UIView.animate`. SwiftUI's version wraps the **state change**:

```swift ios
import SwiftUI

struct IngredientsCard: View {
    @State private var isExpanded = false
    let ingredients = ["2 eggs", "250 ml milk", "100 g sugar"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Ingredients")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            if isExpanded {
                ForEach(ingredients, id: \.self) { item in
                    Text(item)
                }
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
```

Apple's description of `withAnimation(_:_:)`: it "sets the given `Animation` as the `animation` property of the thread's current `Transaction`." Everything that changes because of `isExpanded` in that update animates with `.snappy`: the chevron rotates, the ingredient rows appear (with the default fade, since they have no transition of their own), and the card's background grows. You didn't name any of those views. That's the point of explicit animation: **the action decides that it animates**, and every view involved follows.

`withAnimation`'s first parameter defaults to `.default`, and you can pass `nil` to make a change without animation. From iOS 17, `withAnimation(_:completionCriteria:_:completion:)` runs a closure when the animation is done. Apple: "The completion callback will always be fired exactly one time. If no animations are created by the changes in `body`, then the callback will be called immediately after `body`."

### Choosing an Animation

| Animation | What it is |
| --- | --- |
| `.default` | "A default animation instance" |
| `.easeInOut(duration:)`, `.easeIn`, `.easeOut`, `.linear` | Curves with a duration, as in Module 27 |
| `.spring(duration:bounce:)` | A spring described by how long it takes and how much it overshoots (`bounce` 0 means none) |
| `.smooth` | "A smooth spring animation with a predefined duration and no bounce" |
| `.snappy` | "A spring animation with a predefined duration and small amount of bounce that feels more snappy" |
| `.bouncy` | "A spring animation with a predefined duration and higher amount of bounce" |

Springs are the usual choice for things the user moves or toggles: they settle naturally and, Apple notes for `spring(duration:bounce:blendDuration:)`, when a spring replaces another on the same property it keeps the velocity, so an interrupted animation doesn't jerk. `.smooth`, `.snappy` and `.bouncy` are ready-made springs; Module 27 showed that UIKit can use these same `Animation` values from iOS 18.

## Implicit animation: animation(_:value:)

Sometimes it isn't an action that should animate but a **view**: a favorite heart that bounces however it gets toggled (a tap, a sync from another device, an undo). `animation(_:value:)` "applies the given animation to this view when the specified value changes":

```swift ios
import SwiftUI

struct FavoriteButton: View {
    @Binding var isFavorite: Bool
    let count: Int

    var body: some View {
        Button {
            isFavorite.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.pink : Color.secondary)
                    .scaleEffect(isFavorite ? 1.2 : 1)
                    .animation(.bouncy, value: isFavorite)
                Text("\(count)")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}
```

The heart scales and changes color with a bounce whenever `isFavorite` changes. The count next to it isn't inside the modifier, so it updates without animation. The modifier is scoped to the view it's attached to and its children, and to changes in the value it watches.

> [!warning] animation(_:) without a value
> Old code writes `.animation(.easeIn)`. That form is deprecated since iOS 15 with the message "Use withAnimation or animation(_:value:) instead." It animated every change to the view, including ones you didn't intend, like a list row's content changing when data reloaded. Always say which value the animation is for.

### When both are present

An update can have an explicit animation from `withAnimation` *and* reach views that have their own `animation(_:value:)`. Apple's pages give the pieces: `withAnimation` sets the update's animation; `animation(_:value:)` applies its animation when its value changes, and "if `animation` is `nil`, the view doesn't animate"; and the `transaction(_:)` example shows a modifier near a view *replacing* the animation that `withAnimation` set, for that view only. Here's that reading as a model:

```swift
/// One state update: which state changed, and the animation withAnimation set (nil if none).
struct Update {
    var changed: Set<String>
    var explicitAnimation: String?
}

/// A view: the state it displays, and an optional .animation(_:value:) modifier.
struct ViewNode {
    let name: String
    let reads: Set<String>
    var implicit: (animation: String?, value: String)?
}

func animation(for view: ViewNode, in update: Update) -> String {
    guard !view.reads.isDisjoint(with: update.changed) else { return "doesn't change" }
    if let implicit = view.implicit, update.changed.contains(implicit.value) {
        return implicit.animation ?? "no animation (disabled)"
    }
    return update.explicitAnimation ?? "no animation"
}

let views = [
    ViewNode(name: "heart", reads: ["isFavorite"], implicit: (animation: "bouncy", value: "isFavorite")),
    ViewNode(name: "count", reads: ["count"]),
    ViewNode(name: "panel", reads: ["isExpanded"], implicit: (animation: nil, value: "isExpanded")),
]

let updates = [
    ("tap heart, no withAnimation", Update(changed: ["isFavorite", "count"], explicitAnimation: nil)),
    ("tap heart in withAnimation(.smooth)", Update(changed: ["isFavorite", "count"], explicitAnimation: "smooth")),
    ("expand in withAnimation(.snappy)", Update(changed: ["isExpanded"], explicitAnimation: "snappy")),
]

for (title, update) in updates {
    print(title)
    for view in views {
        print("  \(view.name): \(animation(for: view, in: update))")
    }
}
```

```output
tap heart, no withAnimation
  heart: bouncy
  count: no animation
  panel: doesn't change
tap heart in withAnimation(.smooth)
  heart: bouncy
  count: smooth
  panel: doesn't change
expand in withAnimation(.snappy)
  heart: doesn't change
  count: doesn't change
  panel: no animation (disabled)
```

Read the three updates:

1. **No `withAnimation`.** Only the heart animates, because its own modifier watches `isFavorite`. The count jumps.
2. **`withAnimation(.smooth)`.** The count now animates with `.smooth`, from the transaction. The heart still bounces: its modifier is closer to it than the `withAnimation` call, and wins for that view.
3. **`.animation(nil, value: isExpanded)`** on the panel turns off animation for that view whenever `isExpanded` changes, even inside `withAnimation`. That's the tool for "this part must never animate."

> [!warning] A model
> Real modifiers apply to a whole subtree, and SwiftUI animates individual properties, not whole views. The model keeps the rules you use day to day: an explicit animation reaches everything the change affects; an implicit one wins for its own view when its value changed; `nil` disables.

To change or remove animation for part of the hierarchy whatever the value, `transaction(_:)` gives you the update's `Transaction` to modify: `.transaction { $0.animation = nil }`. Apple advises using it "on leaf views such as `Image` or `Button` rather than container views."

### Animating text

A `Text` whose string changes animates as a cross-fade. For numbers, iOS 17's `contentTransition(.numericText(value:))` animates digit by digit; Apple: "The difference between the old and new values when the text changes will be used to determine the animation direction." Like every content transition, it "only has an effect within the context of an `Animation`."

## Transitions

Animations interpolate a property of a view that stays on screen. A view that's **inserted or removed** (an `if` becoming true or false, a row added to a `ForEach`) has nothing to interpolate from or to. A transition says what to do instead. Apple's `transition(_:)` page: "When this view appears or disappears, the transition will be applied to it, allowing for animating it in and out," and its example toggles the state inside `withAnimation`.

```swift ios
import SwiftUI

struct SavedBanner: View {
    @State private var showsBanner = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            if showsBanner {
                Label("Recipe saved", systemImage: "checkmark.circle.fill")
                    .padding()
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .transition(
                        reduceMotion
                            ? AnyTransition.opacity
                            : .asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                          removal: .opacity)
                    )
            }
            Spacer()
            Button("Save") {
                withAnimation(.snappy) {
                    showsBanner.toggle()
                }
            }
        }
        .padding()
    }
}
```

| Transition | Insertion and removal |
| --- | --- |
| `.opacity` | "from transparent to opaque on insertion, and from opaque to transparent on removal" |
| `.move(edge:)` | "moves the view away, towards the specified edge of the view" |
| `.scale` | Scales the view in and out |
| `.slide` | "inserts by moving in from the leading edge, and removes by moving out towards the trailing edge" |
| `.asymmetric(insertion:removal:)` | "a different transition for insertion versus removal" |
| `a.combined(with: b)` | Both at once |

In `SavedBanner` the banner slides down from the top while fading in, and only fades out when removed. With Reduce Motion on, it only fades. iOS 17 added a `Transition` protocol for writing your own transitions (Apple's example is a `RotatingFadeTransition`); the built-in ones above cover most needs.

## matchedGeometryEffect

Sometimes a view should look like it **moves** from one place in the hierarchy to another: a chip moving from "available tags" to "selected tags," a thumbnail growing into a header. They're two different views in two different places in `body`. `matchedGeometryEffect(id:in:properties:anchor:isSource:)` (iOS 14) links them. Apple: "If inserting a view in the same transaction that another view with the same key is removed, the system will interpolate their frame rectangles in window space to make it appear that there is a single view moving from its old position to its new position."

```swift ios
import SwiftUI

struct TagPicker: View {
    @Namespace private var tagSpace
    @State private var selected: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let allTags = ["Vegan", "Quick", "Spicy", "Budget"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Selected").font(.headline)
            HStack {
                ForEach(selected, id: \.self) { tag in
                    chip(tag)
                }
            }
            .frame(minHeight: 36)

            Text("Available").font(.headline)
            HStack {
                ForEach(allTags.filter { !selected.contains($0) }, id: \.self) { tag in
                    chip(tag)
                }
            }
        }
        .padding()
    }

    private func chip(_ tag: String) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                if let index = selected.firstIndex(of: tag) {
                    selected.remove(at: index)
                } else {
                    selected.append(tag)
                }
            }
        } label: {
            Text(tag)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .matchedGeometryEffect(id: tag, in: tagSpace)
    }
}
```

- **`@Namespace private var tagSpace`** creates the namespace the ids live in. Apple: "New namespaces are created by adding an `@Namespace` variable to a `View` type and reading its value in the view's body method."
- **Same id, different places.** Each tag is in exactly one of the two rows at any moment. Tapping "Quick" removes the chip from Available and inserts one in Selected, in the same `withAnimation`, so SwiftUI animates the frame from the old position to the new one.
- **One source at a time.** `isSource` defaults to `true`. Apple: "If the number of currently-inserted views in the group with `isSource = true` is not exactly one results are undefined." Here that holds because a tag is never in both rows.
- **Only geometry.** "The `matchedGeometryEffect()` modifier only arranges for the geometry of the views to be linked, not their rendering." The chips' own transitions (by default, a fade) decide how the two views blend while the frame moves.

What "interpolate their frame rectangles" means is plain arithmetic. With a linear curve, a frame halfway through the animation is halfway between the two frames in each of x, y, width and height:

```swift
struct Frame {
    var x, y, width, height: Double
}

func interpolate(from start: Frame, to end: Frame, progress t: Double) -> Frame {
    Frame(x: start.x + (end.x - start.x) * t,
          y: start.y + (end.y - start.y) * t,
          width: start.width + (end.width - start.width) * t,
          height: start.height + (end.height - start.height) * t)
}

let thumbnail = Frame(x: 16, y: 300, width: 80, height: 80)
let header = Frame(x: 0, y: 0, width: 390, height: 260)

for t in [0.0, 0.25, 0.5, 1.0] {
    let frame = interpolate(from: thumbnail, to: header, progress: t)
    print("t=\(t): x \(Int(frame.x)), y \(Int(frame.y)), \(Int(frame.width)) × \(Int(frame.height))")
}
```

```output
t=0.0: x 16, y 300, 80 × 80
t=0.25: x 12, y 225, 157 × 125
t=0.5: x 8, y 150, 235 × 170
t=1.0: x 0, y 0, 390 × 260
```

With a spring or ease curve, `t` follows the curve (Module 27, lesson 1) instead of moving at a constant rate, but each frame is still this interpolation at the curve's current progress. (`Int(_:)` truncates: 157.5 prints as 157.)

### Zoom navigation transitions (iOS 18)

iOS 18 brought the same idea to navigation. `navigationTransition(_:)` with `.zoom(sourceID:in:)` makes a pushed view zoom out of the view marked with `matchedTransitionSource(id:in:)`. Apple: add `navigationTransition` "to a view that appears within a `NavigationStack` or a sheet, outside of any containers such as `VStack`."

```swift ios 18.0
import SwiftUI

struct Recipe: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
}

struct RecipeGrid: View {
    @Namespace private var zoomSpace
    let recipes: [Recipe]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                    ForEach(recipes) { recipe in
                        NavigationLink(value: recipe) {
                            Text(recipe.title)
                                .frame(maxWidth: .infinity, minHeight: 140)
                                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .matchedTransitionSource(id: recipe.id, in: zoomSpace)
                    }
                }
                .padding()
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                Text(recipe.title)
                    .font(.largeTitle)
                    .navigationTransition(.zoom(sourceID: recipe.id, in: zoomSpace))
            }
        }
    }
}
```

The grid cell is the source, keyed by the recipe's id; the destination names the same id and namespace. The `navigationDestination` sits on the `ScrollView`, outside the lazy grid (lesson 2). With an iOS 17 deployment target you'd put the `navigationTransition` behind `if #available(iOS 18, *)`, or skip it: the push works without it.

## Reduce Motion

Some people get dizzy or nauseous from motion on screen and turn on Reduce Motion in Settings. SwiftUI exposes the setting as `@Environment(\.accessibilityReduceMotion)` (iOS 13). Apple's guidance on that page: "If this property's value is true, UI should avoid large animations, especially those that simulate the third dimension." Module 27 used `UIAccessibility.isReduceMotionEnabled` for the same purpose in UIKit.

Reducing motion doesn't mean removing feedback. The state change still happens and the user still needs to see it; replace movement with something that doesn't move:

```swift
enum Motion: String {
    case slide, zoom, scale, rotate3D, fade, none
}

/// The motion to use for a change, given what the design asks for and the setting.
func motion(for preferred: Motion, reduceMotion: Bool) -> Motion {
    guard reduceMotion else { return preferred }
    switch preferred {
    case .slide, .zoom, .scale, .rotate3D:
        return .fade          // keep the feedback, drop the movement
    case .fade, .none:
        return preferred
    }
}

for preferred in [Motion.slide, .zoom, .rotate3D, .fade, .none] {
    print(preferred.rawValue, "->", motion(for: preferred, reduceMotion: true).rawValue)
}
```

```output
slide -> fade
zoom -> fade
rotate3D -> fade
fade -> fade
none -> none
```

In SwiftUI, that policy is a ternary where the animation or transition is chosen, as in `SavedBanner` and `TagPicker`:

- `.transition(reduceMotion ? AnyTransition.opacity : .move(edge: .bottom))`: keep the appearance, drop the slide.
- `withAnimation(reduceMotion ? nil : .bouncy) { … }`: apply the change at once. Pick `nil` for movement that adds nothing; pick a short `.easeInOut` with an opacity transition when the fade itself helps people notice the change.
- Repeating or decorative motion (a pulsing badge, a parallax header, symbol effects) should stop entirely.

Module 27 quoted the Human Interface Guidelines on the same setting, including "Replacing transitions in x-, y-, and z-axes with fades to avoid motion." Check your screens with Reduce Motion turned on in the device's accessibility settings; that wasn't done for this lesson.

## Common mistakes

> [!error] A transition that never plays
> The `if` flips without `withAnimation`, so the view appears and disappears instantly. Wrap the state change in `withAnimation`, or attach `animation(_:value:)` to a container that stays on screen and watches the same value.

> [!error] .animation(.spring()) with no value
> Deprecated since iOS 15, and it animates changes you didn't mean to animate. Pass the value: `.animation(.spring, value: isOpen)`.

> [!error] Two sources for one matched id
> Both views are on screen with `isSource` left at `true`. Apple: results are undefined. Make sure a given id is inserted in one place at a time, or mark all but one with `isSource: false`.

> [!error] Inserting and removing in different updates
> `matchedGeometryEffect` interpolates only when one view is removed "in the same transaction" another is inserted. Two separate `withAnimation` calls, or a removal in one and insertion in the next run loop, give two unrelated transitions.

> [!error] Ignoring Reduce Motion
> A full-screen zoom or a 3D flip with Reduce Motion on is exactly what Apple's guidance says to avoid. Read `accessibilityReduceMotion` and fall back to a fade.

## Exercises

````exercise
id: m35-l06-e1
type: prediction
prompt: "The animation model from the lesson with a different screen. What does it print?"
code: |
  struct Update {
      var changed: Set<String>
      var explicitAnimation: String?
  }

  struct ViewNode {
      let name: String
      let reads: Set<String>
      var implicit: (animation: String?, value: String)?
  }

  func animation(for view: ViewNode, in update: Update) -> String {
      guard !view.reads.isDisjoint(with: update.changed) else { return "doesn't change" }
      if let implicit = view.implicit, update.changed.contains(implicit.value) {
          return implicit.animation ?? "no animation (disabled)"
      }
      return update.explicitAnimation ?? "no animation"
  }

  let views = [
      ViewNode(name: "badge", reads: ["unread"], implicit: (animation: "bouncy", value: "unread")),
      ViewNode(name: "list", reads: ["messages", "filter"]),
      ViewNode(name: "chart", reads: ["messages"], implicit: (animation: nil, value: "messages")),
  ]

  let update1 = Update(changed: ["messages", "unread"], explicitAnimation: "smooth")
  let update2 = Update(changed: ["filter"], explicitAnimation: nil)
  for update in [update1, update2] {
      print(views.map { "\($0.name)=\(animation(for: $0, in: update))" }.joined(separator: ", "))
  }
output: |
  badge=bouncy, list=smooth, chart=no animation (disabled)
  badge=doesn't change, list=no animation, chart=doesn't change
hints:
  - "The chart's modifier watches messages and has a nil animation."
  - "The second update has no withAnimation, and only the list reads filter."
solution: |
  ```output
  badge=bouncy, list=smooth, chart=no animation (disabled)
  badge=doesn't change, list=no animation, chart=doesn't change
  ```

  In the first update (new messages arrive inside `withAnimation(.smooth)`), the badge's own modifier watches `unread`, which changed, so it bounces. The list has no modifier and takes the explicit `.smooth`. The chart's `.animation(nil, value: messages)` turns animation off for it, a common choice for charts that would look odd animating every new point. In the second update only the filter changed, without `withAnimation`: the list updates instantly and the others don't change.
````

````exercise
id: m35-l06-e2
type: prediction
prompt: "A card flips over, shrinks away or fades, depending on the design and the Reduce Motion setting. What does this print?"
code: |
  enum Motion: String {
      case slide, zoom, scale, rotate3D, fade, none
  }

  func motion(for preferred: Motion, reduceMotion: Bool) -> Motion {
      guard reduceMotion else { return preferred }
      switch preferred {
      case .slide, .zoom, .scale, .rotate3D:
          return .fade
      case .fade, .none:
          return preferred
      }
  }

  let design: [(String, Motion)] = [("flip card", .rotate3D), ("dismiss toast", .scale), ("swap image", .fade)]
  for reduceMotion in [false, true] {
      let choices = design.map { "\($0.0): \(motion(for: $0.1, reduceMotion: reduceMotion).rawValue)" }
      print(reduceMotion ? "Reduce Motion on:" : "Reduce Motion off:", choices.joined(separator: ", "))
  }
output: |
  Reduce Motion off: flip card: rotate3D, dismiss toast: scale, swap image: fade
  Reduce Motion on: flip card: fade, dismiss toast: fade, swap image: fade
hints:
  - "With the setting off, the design's choice is returned unchanged."
solution: |
  ```output
  Reduce Motion off: flip card: rotate3D, dismiss toast: scale, swap image: fade
  Reduce Motion on: flip card: fade, dismiss toast: fade, swap image: fade
  ```

  Off, every element keeps its designed motion. On, the 3D flip (the kind of animation Apple singles out, "especially those that simulate the third dimension") and the scale both become fades, and the image swap, already a fade, is unchanged. Everyone still sees the card change and the toast leave; only the movement is gone.
````

````exercise
id: m35-l06-e3
type: comprehension
prompt: "An error banner has .transition(.move(edge: .top)) and is shown with `if showsError { ErrorBanner() }`. The network code sets showsError = true when a request fails, and the banner appears instantly with no slide. What's the most likely reason?"
choices:
  - text: "The state change isn't inside an animation, so the insertion isn't animated and the transition has nothing to run in."
    correct: true
    why: "Transitions animate insertions and removals that happen inside an animation: withAnimation around the change, or an animation(_:value:) on a container that watches showsError."
  - text: "move(edge:) only works with NavigationStack."
    correct: false
    why: "It works on any view inserted or removed inside an animation."
  - text: "Transitions require iOS 18."
    correct: false
    why: "AnyTransition and transition(_:) date from iOS 13; iOS 17 added the Transition protocol."
  - text: "The banner needs a matchedGeometryEffect."
    correct: false
    why: "That links two views' frames; a single view appearing needs a transition and an animation."
solution: |
  **No animation around the change.** `showsError = true` from the network code creates an update with no animation, so SwiftUI inserts the banner immediately. Fix it where the state changes, `withAnimation(.snappy) { showsError = true }`, or make the container own it with `.animation(.snappy, value: showsError)` on a `VStack` that stays on screen. The second is useful when several code paths set the flag, since none of them has to remember `withAnimation`.
````

````exercise
id: m35-l06-e4
type: fill-in
prompt: "Complete the view: the details panel slides up from the bottom when shown, unless Reduce Motion is on, in which case it fades. The toggle animates with a snappy spring."
code: |
  struct Details: View {
      @State private var showsDetails = false
      @Environment(\.[[1]]) private var reduceMotion

      var body: some View {
          VStack {
              Button("Details") {
                  [[2]](.snappy) {
                      showsDetails.toggle()
                  }
              }
              if showsDetails {
                  Text("Serves 4. Keeps for 3 days.")
                      .[[3]](reduceMotion ? AnyTransition.opacity : .move(edge: .bottom))
              }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["accessibilityReduceMotion"]
  - id: "2"
    answers: ["withAnimation"]
  - id: "3"
    answers: ["transition"]
hints:
  - "The environment key for the Reduce Motion setting starts with accessibility."
  - "Wrap the state change, not the view."
solution: |
  ```swift ios
  import SwiftUI

  struct Details: View {
      @State private var showsDetails = false
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      var body: some View {
          VStack {
              Button("Details") {
                  withAnimation(.snappy) {
                      showsDetails.toggle()
                  }
              }
              if showsDetails {
                  Text("Serves 4. Keeps for 3 days.")
                      .transition(reduceMotion ? AnyTransition.opacity : .move(edge: .bottom))
              }
          }
      }
  }
  ```

  `accessibilityReduceMotion` reads the setting. `withAnimation` puts the toggle inside an animation, which is what lets the `if`'s insertion and removal use the transition. The ternary chooses a fade or a slide; writing `AnyTransition.opacity` on the first branch tells Swift which type both branches share.
````

````exercise
id: m35-l06-e5
type: find-errors
prompt: "This photo browser was written against an old tutorial. Which of these are real problems?"
code: |
  struct PhotoBrowser: View {
      @Namespace private var space
      @State private var selected: Photo?
      let photos: [Photo]

      var body: some View {
          ZStack {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                  ForEach(photos) { photo in
                      Thumbnail(photo: photo)
                          .matchedGeometryEffect(id: photo.id, in: space)
                          .onTapGesture { selected = photo }
                  }
              }
              if let selected {
                  FullPhoto(photo: selected)
                      .matchedGeometryEffect(id: selected.id, in: space)
                      .rotation3DEffect(.degrees(360), axis: (x: 0, y: 1, z: 0))
              }
          }
          .animation(.spring())
      }
  }
choices:
  - text: "While a photo is open, its thumbnail and the full photo are both inserted with isSource true for the same id."
    correct: true
    why: "Apple: results are undefined unless exactly one view per id is a source. Remove the thumbnail when its photo is open, or mark one side isSource: false."
  - text: ".animation(.spring()) without a value is deprecated and animates every change in the ZStack."
    correct: true
    why: "Use withAnimation around selected = photo, or .animation(.spring, value: selected?.id)."
  - text: "The 3D rotation ignores Reduce Motion."
    correct: true
    why: "Apple's guidance names animations that simulate the third dimension. Drop it or read accessibilityReduceMotion."
  - text: "matchedGeometryEffect needs iOS 18."
    correct: false
    why: "It's iOS 14. The zoom navigation transition is the iOS 18 API."
  - text: "@Namespace can only be used in a NavigationStack."
    correct: false
    why: "Any view can declare a namespace."
rubric:
  - Flags the two simultaneous sources for one id.
  - Flags the deprecated value-less animation modifier.
  - Flags the 3D effect with no Reduce Motion handling.
  - Doesn't claim an iOS 18 requirement or a NavigationStack requirement.
solution: |
  Three problems. A version that addresses them:

  ```swift ios
  import SwiftUI

  struct Photo: Identifiable {
      let id: Int
      let name: String
  }

  struct PhotoBrowser: View {
      @Namespace private var space
      @State private var selected: Photo?
      @Environment(\.accessibilityReduceMotion) private var reduceMotion
      let photos: [Photo]

      var body: some View {
          ZStack {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                  ForEach(photos) { photo in
                      Text(photo.name)
                          .frame(width: 100, height: 100)
                          .background(.quaternary)
                          .matchedGeometryEffect(id: photo.id, in: space, isSource: selected?.id != photo.id)
                          .onTapGesture { open(photo) }
                  }
              }
              if let selected {
                  Text(selected.name)
                      .frame(maxWidth: .infinity, maxHeight: .infinity)
                      .background(.background)
                      .matchedGeometryEffect(id: selected.id, in: space)
                      .onTapGesture { open(nil) }
              }
          }
      }

      private func open(_ photo: Photo?) {
          withAnimation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.2)) {
              selected = photo
          }
      }
  }
  ```

  The thumbnail stops being a source while its photo is open, so exactly one view per id is the source. The animation is explicit and tied to the action. The 3D spin is gone, and with Reduce Motion on the change happens without animation. (`Thumbnail` and `FullPhoto` became `Text` views to keep the example self-contained.)
````

````exercise
id: m35-l06-e6
type: solve
prompt: |
  A matched-geometry animation from a 60 × 60 avatar at (20, 500) to a 200 × 200 profile header at (95, 80) should look like one view moving. Write `interpolate(from:to:progress:)` for a `Frame`, and an `easeOut(_ t: Double) -> Double` that returns `1 - (1 - t) * (1 - t)`.

  Print the frame at progress 0, 0.5 and 1 twice: once with linear progress and once with `easeOut(t)` as the progress, as `x,y w×h` with each number rounded to the nearest whole number. Then print which of the two is further along at t = 0.5, measured by width.
starter: |
  struct Frame {
      var x, y, width, height: Double
  }

  func interpolate(from start: Frame, to end: Frame, progress t: Double) -> Frame {
      // your code
      start
  }

  func easeOut(_ t: Double) -> Double {
      // your code
      t
  }
hints:
  - "Each field: start + (end − start) × t."
  - "easeOut(0.5) = 1 − 0.25 = 0.75."
  - "Int(value.rounded()) rounds to the nearest whole number."
rubric:
  - Interpolates all four fields linearly in progress.
  - easeOut follows the given formula.
  - Prints six frames in the requested format and the comparison line.
solution: |
  ```swift
  struct Frame {
      var x, y, width, height: Double
  }

  func interpolate(from start: Frame, to end: Frame, progress t: Double) -> Frame {
      Frame(x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t,
            width: start.width + (end.width - start.width) * t,
            height: start.height + (end.height - start.height) * t)
  }

  func easeOut(_ t: Double) -> Double {
      1 - (1 - t) * (1 - t)
  }

  func format(_ frame: Frame) -> String {
      let numbers = [frame.x, frame.y, frame.width, frame.height].map { Int($0.rounded()) }
      return "\(numbers[0]),\(numbers[1]) \(numbers[2])×\(numbers[3])"
  }

  let avatar = Frame(x: 20, y: 500, width: 60, height: 60)
  let header = Frame(x: 95, y: 80, width: 200, height: 200)

  let curves: [(name: String, curve: (Double) -> Double)] = [("linear", { $0 }), ("easeOut", easeOut)]
  for (name, curve) in curves {
      let frames = [0.0, 0.5, 1.0].map { format(interpolate(from: avatar, to: header, progress: curve($0))) }
      print(name + ":", frames.joined(separator: " | "))
  }

  let linearWidth = interpolate(from: avatar, to: header, progress: 0.5).width
  let easedWidth = interpolate(from: avatar, to: header, progress: easeOut(0.5)).width
  print(easedWidth > linearWidth ? "easeOut is further along" : "linear is further along")
  ```

  ```output
  linear: 20,500 60×60 | 58,290 130×130 | 95,80 200×200
  easeOut: 20,500 60×60 | 76,185 165×165 | 95,80 200×200
  easeOut is further along
  ```

  Both start and end at the same frames; the curve only changes where the view is in between. Halfway through the time, ease-out has covered three quarters of the distance (`easeOut(0.5) = 0.75`), so it starts fast and slows into place, which suits a view arriving on screen. `57.5` rounds to `58` with `rounded()`, the "schoolbook" rounding that rounds halves away from zero. A spring is the same idea with a curve that can pass 1 and come back.
````

## Summary

- Animation in SwiftUI is a state change inside an animation. `withAnimation` sets the update's animation, and every view affected by the change animates; `animation(_:value:)` animates one view when one value changes. `.animation(_:)` without a value is deprecated since iOS 15.
- A view's own `animation(_:value:)` wins over `withAnimation` for that view; `.animation(nil, value:)` and `transaction(_:)` turn animation off for part of the hierarchy.
- Prefer springs (`.spring(duration:bounce:)`, `.smooth`, `.snappy`, `.bouncy`). iOS 17's `withAnimation(_:completionCriteria:_:completion:)` runs code when it finishes.
- Transitions animate insertion and removal: `.opacity`, `.move(edge:)`, `.scale`, `.slide`, `.asymmetric`, `.combined(with:)`. They only play when the change happens inside an animation.
- `matchedGeometryEffect` interpolates the frames of two views with the same id when one is inserted and the other removed in the same update; one source per id. iOS 18's `.zoom` navigation transition does the same for pushes.
- Read `accessibilityReduceMotion` and replace movement, scaling and 3D effects with a fade or no animation, keeping the state change visible.
