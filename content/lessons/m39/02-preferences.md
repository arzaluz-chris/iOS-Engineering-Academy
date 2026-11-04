---
id: m39-l02
title: Preferences and anchor preferences
description: "The environment sends values down the view tree; preferences send them up. You model PreferenceKey's reduce in plain Swift on a fake tree to see exactly how values from many children become one, and why defaultValue must be neutral. Then you align form labels with a preference read in onPreferenceChange, draw a selection underline at a child's bounds with anchorPreference and overlayPreferenceValue, and learn the caveats: update cycles, Swift 6's rule for static stored properties, and the closure isolation change in iOS 18.4."
module: m39
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l01]
objectives:
  - Explain the direction of preferences compared with the environment and bindings.
  - Write a PreferenceKey whose defaultValue and reduce(value:nextValue:) are correct for any number of children.
  - Predict the value an ancestor sees for a tree of views that set, skip or transform a preference.
  - Read a preference with onPreferenceChange to update state, and avoid update cycles.
  - Draw relative to a child's bounds with anchorPreference, overlayPreferenceValue and a GeometryProxy.
terms:
  - term: Preference
    definition: "A value a view produces for its ancestors. A view sets it with preference(key:value:); SwiftUI combines the values from all children of a view, in view-tree order, with the key's reduce method."
  - term: PreferenceKey
    definition: "A protocol with a defaultValue and a static reduce(value:nextValue:) that combines the accumulated value with the next sibling's. The type identifies the preference."
  - term: Anchor
    definition: "An opaque geometry value (a rect or point) recorded in one view's coordinate space. An ancestor converts it to its own coordinates with a GeometryProxy: proxy[anchor]."
  - term: "overlayPreferenceValue(_:_:)"
    definition: "A modifier that reads a preference from the view it modifies and builds an overlay from it, in the same update, without storing it in state."
  - term: Update cycle
    definition: "A loop where state set from a preference changes layout, which changes the preference, which sets state again. It shows up as flicker, extra updates or a runtime warning."
mastery:
  - Write the reduce for a maximum, a minimum, a list and a first-wins value, with a neutral defaultValue for each.
  - Run the tree model by hand and give the value at the root.
  - Fix a PreferenceKey that fails to compile in Swift 6 because of a static var.
  - Align the labels of a form with a preference, and say when a Grid is simpler.
  - Draw an underline under the selected segment with an anchor preference.
resources: [swiftui-grid, swiftui-environment, swiftui-matchedgeometryeffect, swift-book-protocols]
cards:
  - id: m39-l02-c1
    front: How does PreferenceKey.reduce(value:nextValue:) work?
    back: "Apple: it combines \"a sequence of values by modifying the previously-accumulated value\" with the next one, receiving values \"in view-tree order\". You mutate value with what nextValue() returns: max for a maximum, append for a list, value ?? next for first-wins."
  - id: m39-l02-c2
    front: What's the rule for a PreferenceKey's defaultValue?
    back: "Apple: reduce(value: &x, nextValue: { defaultValue }) shouldn't change the meaning of x, because SwiftUI may or may not include the default from views that set nothing. 0 for a maximum of sizes, infinity for a minimum, [] for a list, nil for an optional."
  - id: m39-l02-c3
    front: onPreferenceChange or overlayPreferenceValue?
    back: "To draw something from a preference, overlayPreferenceValue (or backgroundPreferenceValue) builds the view directly, with no state and no extra update. onPreferenceChange is for when the value must be stored, for example to size other views; watch for cycles."
  - id: m39-l02-c4
    front: Why does static var defaultValue = 0 fail in Swift 6?
    back: "A static stored var is global mutable state: 'static property defaultValue is not concurrency-safe because it is nonisolated global shared mutable state'. Use static let for a Sendable value, or a computed static var defaultValue: CGFloat { 0 }."
  - id: m39-l02-c5
    front: How do you get a child's frame in an ancestor's coordinates?
    back: "Child: .anchorPreference(key: K.self, value: .bounds) { anchor in anchor }. Ancestor: .overlayPreferenceValue(K.self) { anchor in GeometryReader { proxy in … proxy[anchor] … } }. proxy[anchor] resolves the anchor to a CGRect in the reader's space."
---

## The idea in one sentence

**Preferences are the environment in reverse**: a child sets a value, SwiftUI combines the values of all children with a function you write, and an ancestor reads the result.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Behavior is quoted from Apple's pages for `PreferenceKey`, `reduce(value:nextValue:)`, `defaultValue`, `preference(key:value:)`, `transformPreference(_:_:)`, `onPreferenceChange(_:perform:)`, `anchorPreference(key:value:transform:)`, `overlayPreferenceValue(_:_:)`, `backgroundPreferenceValue(_:_:)`, `Anchor` and `GeometryProxy`, and from the iOS & iPadOS 18.4 release notes, read in November 2026. The tree model is plain Swift, compiled and run with Swift 6.3. Its protocol mirrors `PreferenceKey`'s two requirements; how it walks the tree is a model of the documented rules, not SwiftUI's implementation.

## Three directions

You've moved data three ways in SwiftUI so far:

| Direction | Tool | Example |
| --- | --- | --- |
| Parent to child, explicitly | Initializer arguments, `@Binding` | `Toggle(isOn: $isOn)` |
| Ancestor to any descendant | Environment (Module 36, lesson 3) | `.environment(\.locale, …)` |
| **Descendants to an ancestor** | **Preferences** | The tallest card's height, the selected tab's frame |

A preference is the tool when **the parent needs to know something only its children can know**, usually a size or position decided by layout, and there may be any number of children. Apple's whole description of the protocol is one sentence: "A view with multiple children automatically combines its values for a given preference into a single value visible to its ancestors."

## PreferenceKey, precisely

The protocol has two requirements:

- `static var defaultValue: Value { get }`. Apple: "Views that have no explicit value for the key produce this default value."
- `static func reduce(value: inout Value, nextValue: () -> Value)`. Apple: it combines "a sequence of values by modifying the previously-accumulated value with the result of a closure that provides the next value." And: "This method receives its values in view-tree order. Conceptually, this combines the preference value from one tree with that of its next sibling."

The sentence that decides whether your key is correct is on the `defaultValue` page: "Combining child views may remove an implicit value produced by using the default. This means that `reduce(value: &x, nextValue: {defaultValue})` shouldn't change the meaning of `x`." SwiftUI doesn't promise whether a child that set nothing takes part in the reduction. Your default must be the neutral element of your reduce, so the answer is the same either way.

## A model you can run

Here is the protocol mirrored in plain Swift, a fake view tree, and a walk that combines values the way Apple describes: children in order, each subtree reduced into the accumulated value, views that set nothing skipped (the case Apple warns may happen), and `transformPreference` as a node that edits its subtree's value on the way up.

```swift
/// A model of PreferenceKey and how a tree combines preference values.
/// The protocol mirrors SwiftUI's requirements; the tree walk is a model, not SwiftUI's code.
protocol PreferenceKeyModel {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}

/// A fake view tree: leaves may set a value; containers combine their children in order.
indirect enum Node<Key: PreferenceKeyModel> {
    case leaf(String, Key.Value?)                     // nil: this view doesn't set the preference
    case container(String, [Node])
    case transform(Node, (inout Key.Value) -> Void)   // transformPreference

    /// What an ancestor sees for this subtree. Views that don't set a value are skipped,
    /// which Apple allows ("Combining child views may remove an implicit value").
    func collected() -> Key.Value? {
        switch self {
        case .leaf(_, let value):
            return value
        case .container(_, let children):
            var result: Key.Value?
            for child in children {
                guard let next = child.collected() else { continue }
                if result == nil {
                    result = next
                } else {
                    Key.reduce(value: &result!, nextValue: { next })
                }
            }
            return result
        case .transform(let child, let change):
            var value = child.collected() ?? Key.defaultValue
            change(&value)
            return value
        }
    }

    /// What onPreferenceChange or overlayPreferenceValue at the root would receive.
    var preferenceValue: Key.Value { collected() ?? Key.defaultValue }
}

struct MaxHeightKey: PreferenceKeyModel {
    static var defaultValue: Double { 0 }
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

struct TitlesKey: PreferenceKeyModel {
    static var defaultValue: [String] { [] }
    static func reduce(value: inout [String], nextValue: () -> [String]) {
        value.append(contentsOf: nextValue())
    }
}

struct LastTitleKey: PreferenceKeyModel {
    static var defaultValue: String? { nil }
    static func reduce(value: inout String?, nextValue: () -> String?) {
        value = nextValue() ?? value
    }
}

let heights: Node<MaxHeightKey> = .container("VStack", [
    .leaf("Header", 44),
    .container("HStack", [.leaf("Icon", 24), .leaf("Title", 56), .leaf("Spacer", nil)]),
    .leaf("Footer", 30),
])
print("max height:", Int(heights.preferenceValue))

let titles: Node<TitlesKey> = .container("NavigationStack", [
    .leaf("List", ["Inbox"]),
    .container("Detail", [.leaf("Message", ["Re: Lunch"]), .leaf("Toolbar", nil)]),
])
print("titles:", titles.preferenceValue)

let last: Node<LastTitleKey> = .container("Root", [
    .leaf("A", "Inbox"), .leaf("B", nil), .leaf("C", "Archive"),
])
print("last title:", last.preferenceValue ?? "none")

let empty: Node<MaxHeightKey> = .container("Empty", [.leaf("Spacer", nil)])
print("nobody set it:", Int(empty.preferenceValue))

let doubled: Node<MaxHeightKey> = .transform(heights) { $0 *= 2 }
print("transformed:", Int(doubled.preferenceValue))
```

```output
max height: 56
titles: ["Inbox", "Re: Lunch"]
last title: Archive
nobody set it: 0
transformed: 112
```

- **`MaxHeightKey`** reduces with `max`. The `HStack` subtree reduces to 56 (its `Spacer` sets nothing), then the root reduces 44, 56 and 30 in order. The default 0 is neutral for `max` of sizes, which are never negative.
- **`TitlesKey`** appends, so order matters: "in view-tree order" means the list's title comes before the detail's. The default `[]` is neutral for `append`.
- **`LastTitleKey`** keeps the last non-nil value: `C` wins over `A`. Swap to `value = value ?? nextValue()` and the first one wins. Neither is more correct; pick the one your screen needs and make it explicit.
- **Nobody set it:** the ancestor gets `defaultValue`.
- **`transform`** stands for `transformPreference(_:_:)`, which Apple describes as "applies a transformation to a preference value": a view in the middle can edit what its subtree reports before it continues upward.

### The default must be neutral

Here's what goes wrong when it isn't. A key meant to find the narrowest width, written with the default that feels natural:

```swift
protocol PreferenceKeyModel {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}

/// Apple's rule: reduce(value: &x, nextValue: { defaultValue }) shouldn't change x.
func defaultIsNeutral<Key: PreferenceKeyModel>(_ key: Key.Type, for value: Key.Value) -> Bool where Key.Value: Equatable {
    var copy = value
    Key.reduce(value: &copy, nextValue: { Key.defaultValue })
    return copy == value
}

struct MinWidthKey: PreferenceKeyModel {
    static var defaultValue: Double { 0 }
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = min(value, nextValue())
    }
}

struct FixedMinWidthKey: PreferenceKeyModel {
    static var defaultValue: Double { .infinity }
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = min(value, nextValue())
    }
}

let widths = [80.0, 120, 95]
var naive = MinWidthKey.defaultValue
var fixed = FixedMinWidthKey.defaultValue
for width in widths {
    MinWidthKey.reduce(value: &naive, nextValue: { width })
    FixedMinWidthKey.reduce(value: &fixed, nextValue: { width })
}
print("min with default 0:", Int(naive))
print("min with default infinity:", Int(fixed))
print(defaultIsNeutral(MinWidthKey.self, for: 80), defaultIsNeutral(FixedMinWidthKey.self, for: 80))
```

```output
min with default 0: 0
min with default infinity: 80
false true
```

Starting from 0, `min` never rises above it: the answer is always 0. With infinity as the default, the first real width replaces it. The last line checks Apple's rule directly: reducing 80 with the default leaves 80 only for the fixed key. A version of this bug that's easy to miss: `MinWidthKey` works in a preview where every child sets a value and the model never folds a default in, then breaks in the app when a child without a value is included.

### Static stored properties in Swift 6

You'll find many keys online written as `static var defaultValue: CGFloat = 0`. In Swift 6 language mode, that's an error for any type, SwiftUI or not:

```swift no-compile static property 'defaultValue' is not concurrency-safe because it is nonisolated global shared mutable state
protocol PreferenceKeyModel {
    associatedtype Value
    static var defaultValue: Value { get }
}

struct HeightKey: PreferenceKeyModel {
    static var defaultValue: Double = 0
}
print(HeightKey.defaultValue)
```

Swift 6.3 says:

```output
error: static property 'defaultValue' is not concurrency-safe because it is nonisolated global shared mutable state
note: convert 'defaultValue' to a 'let' constant to make 'Sendable' shared state immutable
```

A `static var` with storage is a global variable any thread could write. The requirement is only `{ get }`, so you don't need storage at all: write `static let defaultValue: CGFloat = 0` when the type is `Sendable`, or a computed `static var defaultValue: CGFloat { 0 }`, which works for any type. This lesson uses the computed form throughout, because it also works for `Anchor<CGRect>?` without asking whether `Anchor` is `Sendable`.

## Reading a preference into state: aligned labels

A form where every label should be as wide as the widest one. Each label measures itself and reports its width; the form reads the maximum and hands it back as a fixed width.

```swift ios
import SwiftUI

private struct LabelWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AlignedField: View {
    let label: String
    @Binding var text: String
    let labelWidth: CGFloat?

    var body: some View {
        HStack {
            Text(label)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: LabelWidthKey.self, value: proxy.size.width)
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ShippingForm: View {
    @State private var name = ""
    @State private var street = ""
    @State private var postalCode = ""
    @State private var labelWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AlignedField(label: "Name", text: $name, labelWidth: labelWidth)
            AlignedField(label: "Street", text: $street, labelWidth: labelWidth)
            AlignedField(label: "Postal code", text: $postalCode, labelWidth: labelWidth)
        }
        .onPreferenceChange(LabelWidthKey.self) { width in
            labelWidth = width
        }
        .padding()
    }
}
```

- **Measuring.** A `GeometryReader` in the `background` takes the size of the view it's behind, without changing that view's layout (Module 34, lesson 6 explained why a reader in the main flow would). It sets the preference from a `Color.clear`.
- **Order of modifiers.** The background is attached to the `Text` *before* `.frame(width:)`, so it measures the text's own width, not the frame's. That's what keeps this stable: after `labelWidth` is set, each text still reports its natural width, the maximum doesn't change, and `onPreferenceChange` doesn't fire again.
- **Reading.** `onPreferenceChange(_:perform:)` requires `Value: Equatable` and calls the action "when the value for `key` changes." The action stores the width in `@State`, and the next update passes it down.

For this exact layout, a `Grid` with `GridRow`s (iOS 16) aligns the label column with no preference at all. Use the preference version when the labels are in different containers, such as different sections or a custom layout, where a grid can't reach them.

## Caveats of onPreferenceChange

**Cycles.** If the state you set changes the size of the view that reports the preference, you've built a loop: measure, set state, re-layout, measure a different value, set state again. Put the measuring `background` before any modifier that uses the stored value, as above, so the measurement doesn't depend on its own result. SwiftUI's behavior when a cycle doesn't settle isn't documented; developers report flicker, steady CPU use that shows up in Instruments (lesson 5), and runtime warnings in the console.

**It's one update late.** The action runs after SwiftUI has combined the preference, and the state it sets takes effect in a following update. Apple doesn't document the timing; the practical consequence is that the first frame can render with the old value. When you only need to *draw* something from the value, don't go through state at all (next section).

**The closure's isolation changed.** For a while in the iOS 18 SDKs (developers reported it in the Xcode 16.2 betas), the action was declared `@Sendable`, so assigning a `@State` property inside it failed to compile in Swift 6 mode, and code from that time wraps the assignment in `Task { @MainActor in … }` or `MainActor.assumeIsolated { … }`. Apple's iOS & iPadOS 18.4 release notes list it as fixed: "`.onPreferenceChange` modifier's closure argument is required to be `@Sendable`. … This particular closure shouldn't have to be this restrictive." With Xcode 16.3 or later, assign directly, as `ShippingForm` does. If you see the workaround in older code, it's safe to remove when you no longer build with an older SDK.

**Measuring one view.** For a single view's size there's a simpler tool since iOS 16: `onGeometryChange(for:of:action:)`, which transforms a `GeometryProxy` into an `Equatable` value and calls the action when it changes. Preferences earn their keep when many views report and you need them combined.

## Anchor preferences: drawing at a child's bounds

The other classic use: a parent needs to draw something lined up with a child, like an underline under the selected segment or an arrow pointing at a field. The child knows where it is, but in its own coordinate space; the parent needs it in the parent's. An **anchor** solves that. Apple: `Anchor` is "an opaque value derived from an anchor source and a particular view," and "you can convert the anchor to a `Value` in the coordinate space of a target view by using a `GeometryProxy`."

```swift ios
import SwiftUI

private struct SelectedSegmentKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

struct SegmentBar: View {
    let segments: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 20) {
            ForEach(segments, id: \.self) { segment in
                let isSelected = segment == selection
                Button(segment) { selection = segment }
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .anchorPreference(key: SelectedSegmentKey.self, value: .bounds) { anchor in
                        isSelected ? anchor : nil
                    }
            }
        }
        .padding(.bottom, 8)
        .overlayPreferenceValue(SelectedSegmentKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let rect = proxy[anchor]
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: rect.width, height: 3)
                        .offset(x: rect.minX, y: rect.maxY + 4)
                }
            }
        }
        .animation(.snappy, value: selection)
    }
}

struct InboxHeader: View {
    @State private var filter = "All"

    var body: some View {
        SegmentBar(segments: ["All", "Unread", "Flagged"], selection: $filter)
    }
}
```

Line by line:

1. **The key** holds an optional `Anchor<CGRect>`, default `nil`. Its reduce keeps the first non-nil anchor; only one segment is selected, so there's never more than one.
2. **`anchorPreference(key:value:transform:)`** on each button. `value: .bounds` is an `Anchor<CGRect>.Source` for the button's bounds; the transform turns the anchor into the key's value, here the anchor for the selected segment and `nil` for the others. `isSelected` is computed outside the closure so the closure captures a `Bool`, not the view.
3. **`overlayPreferenceValue(_:_:)`** reads the combined value from the `HStack` and builds an overlay from it. Apple: it "reads the specified preference value from the view, using it to produce a second view that is applied as an overlay." No `@State`, no extra update.
4. **`proxy[anchor]`** is `GeometryProxy`'s `subscript(_:)`, which "resolves the value of an anchor to the container view": the selected button's bounds, now in the overlay's coordinates. The capsule takes its width and sits just below it.
5. **`.animation(.snappy, value: selection)`** animates the capsule's frame and offset when the selection changes, because the overlay is computed from the new anchor in the same update.

`backgroundPreferenceValue(_:_:)` is the same thing behind the content. For moving one view into another's place, `matchedGeometryEffect` (Module 35, lesson 6) is often simpler; anchors are the general tool when what you draw isn't a copy of the child, or when several children report.

## Common mistakes

> [!error] error: static property 'defaultValue' is not concurrency-safe because it is nonisolated global shared mutable state
> `static var defaultValue: CGFloat = 0` from older tutorials. Use `static let` for a `Sendable` value or a computed `static var defaultValue: CGFloat { 0 }`.

> [!error] A default that isn't neutral for reduce
> 0 for a minimum, 1 for a sum, a placeholder string for "first title". Check Apple's rule: reducing any value with `defaultValue` must leave it unchanged.

> [!error] value = nextValue() in a key meant to combine
> That's "last view wins," which is what you want only for last-wins keys. For a maximum, `max(value, nextValue())`; for a list, `append(contentsOf:)`.

> [!error] Setting state from a preference that depends on that state
> Measuring a view *after* `.frame(width: storedWidth)` makes the measurement equal the stored value, or change with it every pass. Measure before applying the stored size, or draw with `overlayPreferenceValue` instead of storing.

> [!error] Using GeometryReader in the main layout to measure
> A reader in an `HStack` or `VStack` takes all the space offered and changes the layout you were trying to measure. Put it in a `background` or `overlay`, or use `onGeometryChange`.

## Exercises

````exercise
id: m39-l02-e1
type: prediction
prompt: "The tree model with a list key, a nested container and a transform that a middle view applies. What does it print?"
code: |
  protocol PreferenceKeyModel {
      associatedtype Value
      static var defaultValue: Value { get }
      static func reduce(value: inout Value, nextValue: () -> Value)
  }

  indirect enum Node<Key: PreferenceKeyModel> {
      case leaf(String, Key.Value?)
      case container(String, [Node])
      case transform(Node, (inout Key.Value) -> Void)

      func collected() -> Key.Value? {
          switch self {
          case .leaf(_, let value):
              return value
          case .container(_, let children):
              var result: Key.Value?
              for child in children {
                  guard let next = child.collected() else { continue }
                  if result == nil {
                      result = next
                  } else {
                      Key.reduce(value: &result!, nextValue: { next })
                  }
              }
              return result
          case .transform(let child, let change):
              var value = child.collected() ?? Key.defaultValue
              change(&value)
              return value
          }
      }

      var preferenceValue: Key.Value { collected() ?? Key.defaultValue }
  }

  struct BadgesKey: PreferenceKeyModel {
      static var defaultValue: [String] { [] }
      static func reduce(value: inout [String], nextValue: () -> [String]) {
          value.append(contentsOf: nextValue())
      }
  }

  let tree: Node<BadgesKey> = .container("TabView", [
      .leaf("Home", ["new"]),
      .transform(
          .container("Inbox", [.leaf("List", ["3"]), .leaf("Search", nil), .leaf("Footer", ["sync"])]),
          { $0 = $0.filter { $0 != "sync" } }
      ),
      .leaf("Settings", nil),
      .transform(.leaf("Profile", nil), { $0.append("!") }),
  ])
  print(tree.preferenceValue)
  print(Node<BadgesKey>.container("Empty", [.leaf("A", nil)]).preferenceValue.count)
output: |
  ["new", "3", "!"]
  0
hints:
  - "Children are combined in order. The Inbox subtree is ['3', 'sync'] before its transform runs."
  - "A transform over a subtree that sets nothing starts from defaultValue."
solution: |
  ```output
  ["new", "3", "!"]
  0
  ```

  - **Home** reports `["new"]`.
  - **Inbox** combines its children in order: `["3"]`, nothing from Search, `["sync"]`, giving `["3", "sync"]`. The transform around it removes `"sync"`, so it reports `["3"]`. That's `transformPreference`: a middle view editing its subtree's value.
  - **Settings** sets nothing and is skipped.
  - **Profile** sets nothing, but its transform starts from `defaultValue` (`[]`) and appends `"!"`, so it reports `["!"]`.
  - The root reduces in tree order: `["new", "3", "!"]`. A tree where nobody sets anything gives the default, with 0 elements.
````

````exercise
id: m39-l02-e2
type: prediction
prompt: "Two keys for 'the smallest font scale any child needs', checked against Apple's defaultValue rule. What does it print?"
code: |
  protocol PreferenceKeyModel {
      associatedtype Value
      static var defaultValue: Value { get }
      static func reduce(value: inout Value, nextValue: () -> Value)
  }

  struct ScaleKey: PreferenceKeyModel {
      static var defaultValue: Double { 1 }
      static func reduce(value: inout Double, nextValue: () -> Double) {
          value = min(value, nextValue())
      }
  }

  struct ProductKey: PreferenceKeyModel {
      static var defaultValue: Double { 0 }
      static func reduce(value: inout Double, nextValue: () -> Double) {
          value *= nextValue()
      }
  }

  func combine<Key: PreferenceKeyModel>(_ key: Key.Type, _ values: [Key.Value], includeDefaults: Int) -> Key.Value {
      var all = values
      all.append(contentsOf: Array(repeating: Key.defaultValue, count: includeDefaults))
      var result = all[0]
      for next in all.dropFirst() {
          Key.reduce(value: &result, nextValue: { next })
      }
      return result
  }

  let scales = [0.9, 0.75, 0.8]
  print(combine(ScaleKey.self, scales, includeDefaults: 0), combine(ScaleKey.self, scales, includeDefaults: 2))
  print(combine(ProductKey.self, [2, 3], includeDefaults: 0), combine(ProductKey.self, [2, 3], includeDefaults: 1))
output: |
  0.75 0.75
  6.0 0.0
hints:
  - "Scales are at most 1, so min with a default of 1 changes nothing."
  - "Multiplying by a default of 0 erases everything."
solution: |
  ```output
  0.75 0.75
  6.0 0.0
  ```

  `ScaleKey`'s default, 1, is neutral for `min` as long as no child reports a scale above 1: folding in defaults from views that set nothing leaves 0.75. `ProductKey`'s default is 0, and 0 is the one value that isn't neutral for multiplication: one view that sets nothing turns 6 into 0. Its default should be 1. Because SwiftUI doesn't promise whether defaults are folded in, only `ScaleKey` gives the same answer in every tree.
````

````exercise
id: m39-l02-e3
type: comprehension
prompt: "You want to draw a pointer arrow under whichever text field has focus, aligned with that field. Which approach fits best?"
choices:
  - text: "The focused field sets an anchorPreference with its .bounds; the form reads it with overlayPreferenceValue and positions the arrow with proxy[anchor]."
    correct: true
    why: "The child reports its geometry, the parent draws from it in the same update, no state involved."
  - text: "Each field reads its frame with a GeometryReader in .global coordinates and writes it to an @State in the form through onPreferenceChange."
    correct: false
    why: "It works but stores geometry in state (an extra update, a frame late) and global coordinates break inside scroll views and sheets."
  - text: "Pass the arrow's position down through the environment."
    correct: false
    why: "The environment flows down; the position is only known by the child."
  - text: "Use layoutPriority on the focused field."
    correct: false
    why: "Priority changes how space is shared, not what's drawn where."
solution: |
  **An anchor preference read by `overlayPreferenceValue`.** The field knows its bounds; an anchor carries them up the tree in a form the ancestor can resolve into its own coordinates with `proxy[anchor]`. Because the overlay is built from the preference directly, the arrow moves in the same update as the focus change, and it animates with the rest of the change.
````

````exercise
id: m39-l02-e4
type: solve
prompt: |
  Using the `PreferenceKeyModel` protocol from the lesson, write two keys for a form:

  - `FirstErrorKey`: `String?`, the first error message in view-tree order.
  - `InvalidCountKey`: `Int`, how many fields are invalid (each invalid field reports 1).

  Give each a neutral `defaultValue`. Then write `defaultIsNeutral(_:for:)` (as in the lesson) and print the combined values for this list of field reports, followed by the neutrality check for both keys:

  ```swift
  let errors: [String?] = [nil, "Email is required", nil, "Postal code is too short"]
  let invalid = [0, 1, 0, 1]
  ```
starter: |
  protocol PreferenceKeyModel {
      associatedtype Value
      static var defaultValue: Value { get }
      static func reduce(value: inout Value, nextValue: () -> Value)
  }

  // your keys
hints:
  - "First-wins for an optional: value = value ?? nextValue()."
  - "The neutral element for + is 0; for 'first non-nil' it's nil."
rubric:
  - FirstErrorKey keeps the first non-nil value and has nil as default.
  - InvalidCountKey sums with 0 as default.
  - Combines the reports in order starting from defaultValue.
  - Shows both defaults are neutral.
solution: |
  ```swift
  protocol PreferenceKeyModel {
      associatedtype Value
      static var defaultValue: Value { get }
      static func reduce(value: inout Value, nextValue: () -> Value)
  }

  struct FirstErrorKey: PreferenceKeyModel {
      static var defaultValue: String? { nil }
      static func reduce(value: inout String?, nextValue: () -> String?) {
          value = value ?? nextValue()
      }
  }

  struct InvalidCountKey: PreferenceKeyModel {
      static var defaultValue: Int { 0 }
      static func reduce(value: inout Int, nextValue: () -> Int) {
          value += nextValue()
      }
  }

  func combine<Key: PreferenceKeyModel>(_ key: Key.Type, _ values: [Key.Value]) -> Key.Value {
      var result = Key.defaultValue
      for next in values {
          Key.reduce(value: &result, nextValue: { next })
      }
      return result
  }

  func defaultIsNeutral<Key: PreferenceKeyModel>(_ key: Key.Type, for value: Key.Value) -> Bool where Key.Value: Equatable {
      var copy = value
      Key.reduce(value: &copy, nextValue: { Key.defaultValue })
      return copy == value
  }

  let errors: [String?] = [nil, "Email is required", nil, "Postal code is too short"]
  let invalid = [0, 1, 0, 1]
  print(combine(FirstErrorKey.self, errors) ?? "no errors")
  print(combine(InvalidCountKey.self, invalid))
  print(defaultIsNeutral(FirstErrorKey.self, for: "Email is required"), defaultIsNeutral(InvalidCountKey.self, for: 2))
  ```

  ```output
  Email is required
  2
  true true
  ```

  `value ?? nextValue()` keeps the first error and ignores later ones, so the form can show the topmost problem. The count sums, and 0 is neutral for `+`. In SwiftUI, each field would set both preferences with `.preference(key:value:)`, and the form would read them with `onPreferenceChange` to enable the Save button, or with `overlayPreferenceValue` to show the first message.
````

````exercise
id: m39-l02-e5
type: find-errors
prompt: "A view that should make every card in a row as tall as the tallest one. Which of these are real problems?"
code: |
  struct CardHeightKey: PreferenceKey {
      static var defaultValue: CGFloat = 0
      static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
          value = nextValue()
      }
  }

  struct CardRow: View {
      let cards: [String]
      @State private var cardHeight: CGFloat?

      var body: some View {
          HStack(alignment: .top) {
              ForEach(cards, id: \.self) { card in
                  Text(card)
                      .padding()
                      .frame(height: cardHeight)
                      .background {
                          GeometryReader { proxy in
                              Color.clear.preference(key: CardHeightKey.self, value: proxy.size.height)
                          }
                      }
              }
          }
          .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 }
      }
  }
choices:
  - text: "static var defaultValue: CGFloat = 0 doesn't compile in Swift 6 language mode."
    correct: true
    why: "A static stored var is nonisolated global shared mutable state."
  - text: "reduce keeps the last card's height instead of the tallest."
    correct: true
    why: "value = nextValue() is last-wins; it should be max(value, nextValue())."
  - text: "The GeometryReader measures the card after .frame(height: cardHeight), so the measurement depends on the stored height."
    correct: true
    why: "Once set, every card reports cardHeight; a card that needs more space can never make the row taller again."
  - text: "onPreferenceChange requires the value to be Equatable, and CGFloat isn't."
    correct: false
    why: "CGFloat is Equatable."
  - text: "Preferences can't be set inside ForEach."
    correct: false
    why: "Each element's view sets its value; the HStack combines them."
rubric:
  - Flags the static var.
  - Flags the last-wins reduce.
  - Flags measuring after the frame that uses the stored value.
  - Doesn't flag CGFloat or ForEach.
solution: |
  Three real problems: the `static var` (an error in Swift 6), the reduce that keeps the last value instead of the maximum, and the order of modifiers, which measures the framed card instead of its content. Fixed:

  ```swift ios
  import SwiftUI

  struct CardHeightKey: PreferenceKey {
      static var defaultValue: CGFloat { 0 }
      static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
          value = max(value, nextValue())
      }
  }

  struct CardRow: View {
      let cards: [String]
      @State private var cardHeight: CGFloat?

      var body: some View {
          HStack(alignment: .top) {
              ForEach(cards, id: \.self) { card in
                  Text(card)
                      .padding()
                      .fixedSize(horizontal: false, vertical: true)
                      .background {
                          GeometryReader { proxy in
                              Color.clear.preference(key: CardHeightKey.self, value: proxy.size.height)
                          }
                      }
                      .frame(height: cardHeight, alignment: .top)
                      .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
              }
          }
          .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 }
      }
  }
  ```

  Each card measures its content at its natural height, the row stores the tallest, and the frame applied afterward makes every card that tall. The measurement no longer depends on the stored value, so the loop settles after one change.
````

````exercise
id: m39-l02-e6
type: fill-in
prompt: "Complete the code that draws a ring around the selected avatar, aligned with its bounds, without storing geometry in state."
code: |
  private struct SelectedAvatarKey: PreferenceKey {
      static var defaultValue: Anchor<CGRect>? { nil }
      static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
          value = value ?? nextValue()
      }
  }

  // On each avatar:
  .[[1]](key: SelectedAvatarKey.self, value: .[[2]]) { anchor in
      isSelected ? anchor : nil
  }

  // On the row:
  .[[3]](SelectedAvatarKey.self) { anchor in
      GeometryReader { proxy in
          if let anchor {
              let rect = [[4]]
              Circle()
                  .stroke(Color.accentColor, lineWidth: 3)
                  .frame(width: rect.width + 8, height: rect.height + 8)
                  .position(x: rect.midX, y: rect.midY)
          }
      }
  }
blanks:
  - id: "1"
    answers: ["anchorPreference"]
  - id: "2"
    answers: ["bounds"]
  - id: "3"
    answers: ["overlayPreferenceValue"]
  - id: "4"
    answers: ["proxy[anchor]"]
hints:
  - "The anchor source for a view's whole rectangle."
  - "The GeometryProxy subscript resolves an anchor."
solution: |
  ```swift ios
  import SwiftUI

  private struct SelectedAvatarKey: PreferenceKey {
      static var defaultValue: Anchor<CGRect>? { nil }
      static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
          value = value ?? nextValue()
      }
  }

  struct AvatarRow: View {
      let names: [String]
      @State private var selected = ""

      var body: some View {
          HStack(spacing: 16) {
              ForEach(names, id: \.self) { name in
                  let isSelected = name == selected
                  Button {
                      selected = name
                  } label: {
                      Text(String(name.prefix(1)))
                          .frame(width: 44, height: 44)
                          .background(.quaternary, in: Circle())
                  }
                  .accessibilityLabel(name)
                  .accessibilityAddTraits(isSelected ? .isSelected : [])
                      .anchorPreference(key: SelectedAvatarKey.self, value: .bounds) { anchor in
                          isSelected ? anchor : nil
                      }
              }
          }
          .overlayPreferenceValue(SelectedAvatarKey.self) { anchor in
              GeometryReader { proxy in
                  if let anchor {
                      let rect = proxy[anchor]
                      Circle()
                          .stroke(Color.accentColor, lineWidth: 3)
                          .frame(width: rect.width + 8, height: rect.height + 8)
                          .position(x: rect.midX, y: rect.midY)
                  }
              }
          }
      }
  }
  ```

  `anchorPreference(key:value:transform:)` with `.bounds` records each avatar's rectangle; only the selected one passes it on. `overlayPreferenceValue` reads it on the row, and `proxy[anchor]` converts it to the overlay's coordinates, so `position` can center the ring on the avatar.
````

````exercise
id: m39-l02-e7
type: explain
prompt: "A teammate asks why SwiftUI needs preferences at all when bindings already let a child change a parent's state. Explain the difference in four or five sentences, with one example where a binding is the right tool and one where a preference is."
code: |
  // A binding: the parent hands one child access to its state.
  Toggle("Notifications", isOn: $notificationsOn)

  // A preference: any number of children report, the ancestor reads the combined value.
  ForEach(cards) { card in
      CardView(card: card)
          .background { GeometryReader { Color.clear.preference(key: CardHeightKey.self, value: $0.size.height) } }
  }
  .onPreferenceChange(CardHeightKey.self) { tallest = $0 }
rubric:
  - A binding is passed explicitly to one known child and is for user-driven changes to state the parent owns.
  - A preference is set by any number of descendants, unknown to the parent, and is combined with reduce.
  - Preferences carry layout-derived facts (sizes, anchors) that only exist after the children are laid out.
  - Gives a fitting example of each (toggle bound to a setting; tallest card or selected segment's bounds).
solution: |
  A sample answer: "A binding is a two-way reference the parent hands to a specific child, so the child can change the parent's state, usually because the user did something: a `Toggle` bound to `isOn`. A preference goes the other way without the parent passing anything down: any number of descendants, which the parent may not even know about, report a value, and SwiftUI combines them with the key's `reduce`. That makes preferences the tool for facts that come out of layout, like the tallest card's height or the selected tab's bounds, because they don't exist until the children have been sized. Use a binding when the child edits the parent's data, and a preference when the parent needs to learn something only its children can measure. If you find yourself passing a binding to many children just so each can write its size, you want a preference."
````

## Summary

- Preferences flow up: children set values with `preference(key:value:)` or `anchorPreference`, SwiftUI combines siblings in view-tree order with `reduce(value:nextValue:)`, and an ancestor reads the result.
- `defaultValue` must be neutral for `reduce`: Apple says reducing with it "shouldn't change the meaning" of the value, because views that set nothing may or may not be folded in.
- In Swift 6, write `static var defaultValue: T { … }` (computed) or `static let`; a stored `static var` is an error.
- `onPreferenceChange` stores the value in state: it needs `Equatable`, lands one update later, and can cycle if the measurement depends on the stored value. Since iOS 18.4's SDK, its closure isn't `@Sendable` and can assign `@State` directly.
- `overlayPreferenceValue` and `backgroundPreferenceValue` draw from a preference directly. With an `Anchor` and `proxy[anchor]`, you draw at a child's bounds in the ancestor's coordinates.
- For one view's size, `onGeometryChange`; for a label column in one container, `Grid`. Preferences are for combining facts from many children.
