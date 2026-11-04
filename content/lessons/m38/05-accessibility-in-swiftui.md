---
id: m38-l05
title: Accessibility in SwiftUI
description: "Module 27 taught what VoiceOver needs: a label, a value, traits, sensible elements and actions. SwiftUI gives you most of it from standard views and modifiers. You see what comes for free, write labels and values from your data, decide what's one element with accessibilityElement(children:), move secondary buttons into custom actions, make a custom control speak as a standard one with accessibilityRepresentation, adapt layouts to Dynamic Type with dynamicTypeSize, ScaledMetric and ViewThatFits, and check the result with Accessibility Inspector."
module: m38
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l04, m27-l06]
objectives:
  - Say what standard SwiftUI views expose to VoiceOver by default, and when an image needs a label or should be decorative.
  - Set labels, values, hints and traits with SwiftUI modifiers, writing labels and values from model data.
  - Group views into one element with accessibilityElement(children:), choosing between combine, ignore and contain.
  - Expose secondary actions with accessibilityAction(named:) and adjustable controls with accessibilityAdjustableAction.
  - Make a custom control accessible as a standard one with accessibilityRepresentation.
  - Adapt layout and metrics to Dynamic Type with dynamicTypeSize, isAccessibilitySize, ScaledMetric and ViewThatFits, and test with Accessibility Inspector and previews.
terms:
  - term: accessibilityElement(children:)
    definition: "Creates a new accessibility element from a view, or changes how it treats its children: .combine merges the children's properties into one element, .ignore hides them (you supply the label), .contain keeps them as separate elements inside a container."
  - term: accessibilityRepresentation
    definition: "A modifier (iOS 15) that replaces a view's accessibility elements with those of a view you provide, such as a Toggle or Slider. The representation is hidden and non-interactive; it only generates accessibility."
  - term: Custom action
    definition: "An action an assistive technology can perform on an element, added with accessibilityAction(named:_:). VoiceOver users pick it from the Actions rotor instead of finding a separate small button."
  - term: DynamicTypeSize
    definition: "SwiftUI's enum for the user's text size, from xSmall through xxxLarge and accessibility1 to accessibility5. It's Comparable; isAccessibilitySize is true for the five accessibility sizes."
  - term: "@ScaledMetric"
    definition: "A property wrapper (iOS 14) that scales a number, such as an icon size or spacing, with the current Dynamic Type size, optionally relative to a text style."
mastery:
  - Turn a recipe card with five texts and two buttons into one VoiceOver element with a written label, a value and two custom actions.
  - Explain the difference between .combine and .ignore, and pick one for a given row.
  - Make a custom checkbox read as a toggle with accessibilityRepresentation.
  - Make a star rating adjustable with swipe up and down.
  - Switch a horizontal layout to vertical at accessibility sizes, and scale an icon with @ScaledMetric.
  - Preview a screen at accessibility5 and run an audit in Accessibility Inspector.
resources: [swiftui-accessibility-fundamentals, accessibility-inspector, uikit-supporting-voiceover, uikit-scaling-fonts, hig]
cards:
  - id: m38-l05-c1
    front: ".combine vs .ignore in accessibilityElement(children:)?"
    back: ".combine merges the children's labels and other properties into one element (Apple: some properties may be transformed or ignored). .ignore hides the children and starts with no properties, so you must add a label. Apple suggests considering .combine first."
  - id: m38-l05-c2
    front: When do you need accessibilityRepresentation?
    back: "When a custom-drawn control behaves like a standard one (a checkbox, a slider track). Give it a hidden Toggle or Slider bound to the same state, and VoiceOver treats it as that control, with its traits and actions."
  - id: m38-l05-c3
    front: How do you make a star rating adjustable in SwiftUI?
    back: "accessibilityElement(children: .ignore), a label ('Rating'), a value ('3 of 5 stars'), and accessibilityAdjustableAction { direction in … } handling .increment and .decrement. VoiceOver users swipe up and down."
  - id: m38-l05-c4
    front: "Three Dynamic Type tools beyond text styles?"
    back: "@Environment(\\.dynamicTypeSize) with isAccessibilitySize to change layout; @ScaledMetric to scale non-text numbers like icon sizes; ViewThatFits to fall back to a layout that fits. Cap a range with .dynamicTypeSize(...DynamicTypeSize.accessibility2) only where content truly can't grow."
  - id: m38-l05-c5
    front: Image("chef-hat") and VoiceOver?
    back: "Image(_:bundle:) uses the name as the localization key for its label, so VoiceOver may read 'chef-hat'. Give it a real label with accessibilityLabel, or use Image(decorative:) (or accessibilityHidden(true)) if it adds nothing."
---

## The idea in one sentence

SwiftUI already builds an accessibility tree from your views; your job is to **correct it where the visual structure isn't the spoken structure**: merge what belongs together, name what's only drawn, and expose what's only reachable by touch.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so nothing here was listened to with VoiceOver. Behavior comes from Apple's pages for `accessibilityLabel(_:)`, `accessibilityValue(_:)`, `accessibilityHint(_:)`, `accessibilityAddTraits(_:)`, `accessibilityElement(children:)`, `AccessibilityChildBehavior` (`combine`, `ignore`, `contain`), `accessibilityAction(named:_:)`, `accessibilityAdjustableAction(_:)`, `accessibilityRepresentation(representation:)`, `Image`, `DynamicTypeSize`, `dynamicTypeSize(_:)`, `ScaledMetric`, `ViewThatFits`, `accessibilityShowsLargeContentViewer()` and the Accessibility Inspector documentation, read in November 2026. The label builders and Dynamic Type logic are plain Swift, compiled and run with Swift 6.3. The concepts (label, value, traits, hints, grouping, actions, testing) are in Module 27, lesson 6; this lesson is the SwiftUI way.

## What you get for free

Standard SwiftUI views are accessible by default:

- **`Text`** is an element whose label is its string.
- **`Button("Save")`** is an element labeled "Save" with the button trait. A button whose label is an `Image(systemName:)` needs `.accessibilityLabel`, as in UIKit.
- **`Toggle`, `Slider`, `Stepper`, `Picker`, `DatePicker`** expose their label, current value, and the right traits and actions (a slider is adjustable).
- **`Label("Favorites", systemImage: "heart")`** reads its title.
- **`Form`, `List` and navigation titles** are structured the way VoiceOver expects.

Images are where you have to decide. Apple's `Image(_:bundle:)` uses the name as "the localization key with which to label the image," so `Image("chef-hat")` may be read as "chef-hat." For an image that carries meaning, add a label; for one that's decoration, use `Image(decorative:)`, which "SwiftUI ignores … for accessibility purposes," or `.accessibilityHidden(true)`.

## Labels, values, hints and traits

The four properties from Module 27 are modifiers:

```swift ios
import SwiftUI

struct VolumeRow: View {
    @Binding var isMuted: Bool
    let level: Int

    var body: some View {
        HStack {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .accessibilityHidden(true)
            Text("Volume")
            Spacer()
            Text(isMuted ? "Muted" : "\(level)%")
                .foregroundStyle(.secondary)
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.wave.2" : "speaker.slash")
            }
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")
            .accessibilityHint("Affects timer alerts only")
        }
    }
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
    }
}
```

- **The speaker icon** repeats what the text says, so it's hidden.
- **The button** has only an icon: its label says what it does, and changes with the state.
- **The hint** adds something the label can't: the scope. Hints are optional; VoiceOver users can turn them off.
- **`.accessibilityAddTraits(.isHeader)`** makes the title a heading, so VoiceOver users can jump between sections with the rotor. `accessibilityRemoveTraits(_:)` removes traits.

### Writing labels from data

Labels are written for the ear. A card that *shows* "★★★★☆ · 25 min · 1.2k" needs a label that *says* something like "4 out of 5 stars, 25 minutes, 1,200 ratings." Building that string is plain Swift, so it can be tested:

```swift
struct RecipeSummary {
    let title: String
    let minutes: Int
    let rating: Int?          // 1...5, nil when unrated
    let ratingCount: Int
    let isFavorite: Bool
}

/// What it is: read first, kept short.
func spokenLabel(for recipe: RecipeSummary) -> String {
    recipe.title
}

/// The details, in the order a sighted user scans them.
func spokenValue(for recipe: RecipeSummary) -> String {
    var parts: [String] = []
    parts.append(recipe.minutes == 1 ? "1 minute" : "\(recipe.minutes) minutes")
    if let rating = recipe.rating {
        let ratings = recipe.ratingCount == 1 ? "1 rating" : "\(recipe.ratingCount) ratings"
        parts.append("\(rating) out of 5 stars, \(ratings)")
    } else {
        parts.append("not rated yet")
    }
    if recipe.isFavorite {
        parts.append("favorite")
    }
    return parts.joined(separator: ", ")
}

let recipes = [
    RecipeSummary(title: "Lemon pasta", minutes: 25, rating: 4, ratingCount: 1200, isFavorite: true),
    RecipeSummary(title: "Overnight oats", minutes: 5, rating: nil, ratingCount: 0, isFavorite: false),
    RecipeSummary(title: "Soft-boiled egg", minutes: 1, rating: 5, ratingCount: 1, isFavorite: false),
]
for recipe in recipes {
    print("\(spokenLabel(for: recipe)) | \(spokenValue(for: recipe))")
}
```

```output
Lemon pasta | 25 minutes, 4 out of 5 stars, 1200 ratings, favorite
Overnight oats | 5 minutes, not rated yet
Soft-boiled egg | 1 minute, 5 out of 5 stars, 1 rating
```

- **Words, not glyphs.** Stars, dots and "min" are visual shorthand. Spell them out.
- **Label versus value.** The title identifies the recipe; the details are its current state. VoiceOver reads the label, then the value.
- **Plurals** are handled by hand here to keep the example small. In a localized app, this text belongs in a String Catalog with plural variants (lesson 6), and the number would be formatted for the user's locale ("1,200" in English).

## One element or many

A card with five texts and two buttons is seven VoiceOver stops. `accessibilityElement(children:)` decides how its children appear, with three behaviors documented on `AccessibilityChildBehavior`:

- **`.combine`**: "Any child accessibility element's properties are merged into the new accessibility element." Quick, and Apple says to consider it first. It also notes that "some properties may be transformed or ignored," for example "a default action may become a named action."
- **`.ignore`**: "Any child accessibility elements become hidden." The new element "has no initial properties," so you must give it a label. Use it when the merged text would be wrong or too long, which is common for cards.
- **`.contain`**: the children stay separate but are grouped: "all children of an accessibility container are navigated in order before navigating through the next accessibility container."

For a recipe card, `.ignore` with the label and value from the functions above, plus custom actions for the buttons:

```swift ios
import SwiftUI

struct RecipeCard: View {
    let title: String
    let minutes: Int
    let rating: Int
    @Binding var isFavorite: Bool
    let share: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            HStack {
                Text(String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating))
                Text("·")
                Text("\(minutes) min")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack {
                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                }
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(minutes) minutes, \(rating) out of 5 stars\(isFavorite ? ", favorite" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: isFavorite ? "Remove from favorites" : "Add to favorites") {
            isFavorite.toggle()
        }
        .accessibilityAction(named: "Share") {
            share()
        }
    }
}
```

- **One stop per card.** VoiceOver reads the title, then the value ("25 minutes, 4 out of 5 stars, favorite"), then the button trait.
- **The buttons became actions.** With `.ignore` they're hidden, so their behavior is re-exposed with `accessibilityAction(named:_:)`. VoiceOver users swipe up or down to choose an action, as Module 27 described for UIKit's custom actions.
- **`.isButton`** because tapping the card opens the recipe (in a real app the card would sit inside a `NavigationLink`, which adds that trait itself).

With `.combine` instead, VoiceOver would read the texts in order ("Lemon pasta, ★★★★☆, ·, 25 min…", depending on how it speaks those characters), which is why the card overrides the label.

### Order

VoiceOver reads elements roughly top to bottom, leading to trailing. When the visual order isn't the reading order (a price shown above the title, a badge in a corner), `accessibilitySortPriority(_:)` reorders elements within a container: higher priorities are read first.

## Controls you drew yourself

### A custom control that behaves like a standard one

A custom checkbox drawn with shapes is just an image and a text to VoiceOver. `accessibilityRepresentation(representation:)` replaces its accessibility with a standard view's. Apple: "SwiftUI hides the view that you provide in the representation closure and makes it non-interactive. The framework uses it only to generate accessibility elements."

```swift ios
import SwiftUI

struct Checkbox: View {
    let title: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.secondary, lineWidth: 2)
                    .background(isChecked ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    .frame(width: 22, height: 22)
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(title, isOn: $isChecked)
        }
    }
}
```

VoiceOver now announces it like any `Toggle`, with its on/off state, and activating it flips `isChecked` through the binding. Apple's own example on that page represents a custom slider track with a `Slider`.

### An adjustable control

For a star rating, the native interaction is "adjustable": swipe up to increase, down to decrease. Apple's `.ignore` example uses exactly this pattern for a page control:

```swift ios
import SwiftUI

struct StarRating: View {
    @Binding var rating: Int
    let maximum = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maximum, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(.orange)
                    .onTapGesture { rating = star }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(rating == 1 ? "1 star" : "\(rating) stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(rating + 1, maximum)
            case .decrement:
                rating = max(rating - 1, 1)
            @unknown default:
                break
            }
        }
    }
}
```

The five tappable stars become one element: "Rating, 3 stars, adjustable." Swiping changes the value and VoiceOver reads the new one. The clamping is the same as in Module 27's UIKit version; `@unknown default` covers directions a future SDK might add.

## Dynamic Type

Text styles (`.font(.body)`, `.headline`…) scale with the user's text size automatically. What doesn't scale on its own is your **layout**: fixed frames, side-by-side arrangements, icon sizes in points. SwiftUI gives you the user's size as `@Environment(\.dynamicTypeSize)`, a `DynamicTypeSize` from `.xSmall` to `.accessibility5`. It's `Comparable`, and `isAccessibilitySize` is true for the five accessibility sizes.

A model of the enum and of a layout decision built on it:

```swift
enum TextSize: Int, Comparable, CaseIterable {
    case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge
    case accessibility1, accessibility2, accessibility3, accessibility4, accessibility5

    static func < (a: TextSize, b: TextSize) -> Bool { a.rawValue < b.rawValue }

    var isAccessibilitySize: Bool { self >= .accessibility1 }
}

enum Axis: String {
    case horizontal, vertical
}

/// Ingredients next to their amounts at normal sizes; stacked at accessibility sizes.
func ingredientRowAxis(for size: TextSize) -> Axis {
    size.isAccessibilitySize ? .vertical : .horizontal
}

/// The size used for a tab-bar-like control that can't grow past accessibility2.
func cappedSize(_ size: TextSize, at limit: TextSize = .accessibility2) -> TextSize {
    min(size, limit)
}

for size in [TextSize.large, .xxxLarge, .accessibility1, .accessibility5] {
    print("\(size): row \(ingredientRowAxis(for: size).rawValue), capped \(cappedSize(size))")
}
```

```output
large: row horizontal, capped large
xxxLarge: row horizontal, capped xxxLarge
accessibility1: row vertical, capped accessibility1
accessibility5: row vertical, capped accessibility2
```

`.large` is the default size. The model mirrors SwiftUI's `DynamicTypeSize` cases and `isAccessibilitySize`; in a view you'd read the real environment value. Here are the three tools together:

```swift ios
import SwiftUI

struct IngredientRow: View {
    let name: String
    let amount: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var iconSize = 24.0

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            Image(systemName: "leaf")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
            Text(name)
            if !typeSize.isAccessibilitySize {
                Spacer()
            }
            Text(amount)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RecipeActions: View {
    let start: () -> Void
    let addToList: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Button("Start cooking", action: start)
                    .buttonStyle(.borderedProminent)
                Button("Add to shopping list", action: addToList)
                    .buttonStyle(.bordered)
            }
            VStack(alignment: .leading) {
                Button("Start cooking", action: start)
                    .buttonStyle(.borderedProminent)
                Button("Add to shopping list", action: addToList)
                    .buttonStyle(.bordered)
            }
        }
    }
}
```

- **`isAccessibilitySize`** switches the row from side by side to stacked. `AnyLayout` with `HStackLayout` and `VStackLayout` (iOS 16) changes the arrangement without changing the views' identity, so nothing is recreated; Module 39 covers layouts in depth. A plain `if`/`else` between an `HStack` and a `VStack` also works.
- **`@ScaledMetric(relativeTo: .body)`** makes the 24-point icon grow at the same rate as body text. Without it, the text grows and the icon stays tiny.
- **`ViewThatFits(in: .horizontal)`** "selects the first child whose ideal size on the constrained axes fits within the proposed size." The buttons sit side by side while they fit, and stack when large text makes them too wide. That's a decision about space, not about the setting, so it also helps on a narrow iPhone or in a split view.
- **`.accessibilityElement(children: .combine)`** on the row: "Flour, 200 g" is one stop. Merging is fine here because the texts in order are exactly what should be read.

When content really can't grow (a compact bar of icons), `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` caps the size for that view, and `accessibilityShowsLargeContentViewer()` (iOS 15) shows an enlarged version when the user long-presses. Apple: "Don't use the large content viewer as a replacement for proper Dynamic Type support." Cap little, and never body text.

## Testing

Module 27 covered the tools; here's how they apply to SwiftUI.

**Previews at extreme sizes.** Apple's `dynamicTypeSize(_:)` page suggests it for exactly this: setting a size "can be useful in previews to see your content at a different size." Two previews, one at the default and one at the largest size, catch most layout problems before you run the app:

```swift illustrative
#Preview("Default") {
    IngredientRow(name: "Flour", amount: "200 g")
}

#Preview("accessibility5") {
    IngredientRow(name: "Flour", amount: "200 g")
        .dynamicTypeSize(.accessibility5)
}
```

(Illustrative because `#Preview` needs Xcode's preview macros and these blocks are type-checked as standalone files.)

**Accessibility Inspector.** Apple: "Use Accessibility Inspector to display, query, and test accessibility information for the elements in your app's view hierarchy. Audit your app to confirm that it addresses accessibility issues such as clipped text and unlabeled elements, and uses appropriate text size and color contrast levels." Open it from "Xcode > Open Developer Tool > Accessibility Inspector," point it at the simulator, and check that each card is one element with the label, value and actions you wrote. The audit catches unlabeled buttons and clipped text; it doesn't tell you whether a label makes sense.

**VoiceOver on a device**, for each main task: can you reach everything, in a sensible order, and does every state change get spoken? That wasn't done for this lesson's code.

**UI tests** can run the same audits with `performAccessibilityAudit(for:_:)` on `XCUIApplication` (iOS 17), as Module 33 described.

## Common mistakes

> [!error] Icon-only buttons with no label
> `Button { … } label: { Image(systemName: "trash") }` may be read with a generic or symbol-derived name, or not usefully at all. Add `.accessibilityLabel("Delete")`. The label says what it does, without the word "button."

> [!error] .ignore without a label
> `accessibilityElement(children: .ignore)` starts with no properties. A card grouped this way and given no label is a silent element.

> [!error] Hiding buttons by grouping
> Grouping a row with `.ignore` hides its buttons from VoiceOver. Re-expose each one with `accessibilityAction(named:_:)`, or use `.combine` or `.contain` so they remain reachable.

> [!error] Fixed frames around text
> `.frame(height: 44)` on a row of text clips it at large sizes. Let text determine height, use `minHeight` if you need a minimum, and preview at `.accessibility5`.

> [!error] Labels that read the screen literally
> "Star star star star empty star" and "25 min" are what's drawn, not what's meant. Write labels and values for the ear, from the data.

> [!error] Capping Dynamic Type to fix a layout
> `.dynamicTypeSize(.large)` on a whole screen makes the layout "work" by ignoring the user's setting. Fix the layout (stack, wrap, scroll) and cap only small chrome that has no room to grow.

## Exercises

````exercise
id: m38-l05-e1
type: prediction
prompt: "The spoken-value builder from the lesson, with three more recipes. What does it print?"
code: |
  struct RecipeSummary {
      let title: String
      let minutes: Int
      let rating: Int?
      let ratingCount: Int
      let isFavorite: Bool
  }

  func spokenValue(for recipe: RecipeSummary) -> String {
      var parts: [String] = []
      parts.append(recipe.minutes == 1 ? "1 minute" : "\(recipe.minutes) minutes")
      if let rating = recipe.rating {
          let ratings = recipe.ratingCount == 1 ? "1 rating" : "\(recipe.ratingCount) ratings"
          parts.append("\(rating) out of 5 stars, \(ratings)")
      } else {
          parts.append("not rated yet")
      }
      if recipe.isFavorite {
          parts.append("favorite")
      }
      return parts.joined(separator: ", ")
  }

  print(spokenValue(for: RecipeSummary(title: "Toast", minutes: 3, rating: 2, ratingCount: 2, isFavorite: false)))
  print(spokenValue(for: RecipeSummary(title: "Stew", minutes: 90, rating: nil, ratingCount: 0, isFavorite: true)))
  print(spokenValue(for: RecipeSummary(title: "Tea", minutes: 1, rating: 5, ratingCount: 1, isFavorite: true)))
output: |
  3 minutes, 2 out of 5 stars, 2 ratings
  90 minutes, not rated yet, favorite
  1 minute, 5 out of 5 stars, 1 rating, favorite
hints:
  - "An unrated recipe never mentions a count."
solution: |
  ```output
  3 minutes, 2 out of 5 stars, 2 ratings
  90 minutes, not rated yet, favorite
  1 minute, 5 out of 5 stars, 1 rating, favorite
  ```

  Each value lists time, rating and favorite status in the order a sighted user scans the card. The unrated stew says so in words instead of reading empty stars, and singular forms are used for exactly one minute and one rating.
````

````exercise
id: m38-l05-e2
type: prediction
prompt: "The Dynamic Type model from the lesson. What does this print?"
code: |
  enum TextSize: Int, Comparable, CaseIterable {
      case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge
      case accessibility1, accessibility2, accessibility3, accessibility4, accessibility5

      static func < (a: TextSize, b: TextSize) -> Bool { a.rawValue < b.rawValue }

      var isAccessibilitySize: Bool { self >= .accessibility1 }
  }

  let sizes = TextSize.allCases
  print(sizes.filter(\.isAccessibilitySize).count)
  print(sizes.filter { $0 > .large && !$0.isAccessibilitySize }.map { "\($0)" })
  print(min(TextSize.accessibility4, .xxxLarge), max(TextSize.small, .medium))
output: |
  5
  ["xLarge", "xxLarge", "xxxLarge"]
  xxxLarge medium
hints:
  - "Comparisons use the raw values, which follow the declaration order."
solution: |
  ```output
  5
  ["xLarge", "xxLarge", "xxxLarge"]
  xxxLarge medium
  ```

  Five sizes are accessibility sizes. The three larger-than-default but non-accessibility sizes are xLarge, xxLarge and xxxLarge: the range where layouts usually still work side by side. `min` and `max` work because the enum is `Comparable`, which is also how `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` expresses a cap on the real type.
````

````exercise
id: m38-l05-e3
type: comprehension
prompt: "A message row shows the sender, a preview, a time and an unread dot, and tapping it opens the conversation. It has no buttons. Which grouping fits best?"
choices:
  - text: "accessibilityElement(children: .combine), plus a value or label part that says \"unread\" because the dot is only visual."
    correct: true
    why: "The texts in order make sense when merged, and the unread state must be spoken, not just drawn."
  - text: "accessibilityElement(children: .ignore) with no other modifiers."
    correct: false
    why: ".ignore starts with no properties: the row would be silent."
  - text: "accessibilityElement(children: .contain)."
    correct: false
    why: "The row would still be four stops, just grouped. That's for sections with several interactive items."
  - text: "accessibilityHidden(true) on the row, since the list already says what it is."
    correct: false
    why: "That removes the row from VoiceOver entirely."
solution: |
  **`.combine`, plus the unread state in words.** Merging gives one stop per message: "Ana, Are we still on for Friday?, 9:41 AM." The dot is a drawing, so add `.accessibilityValue(isUnread ? "unread" : "")` or include "unread" in the label. If the merged text read badly (an emoji-heavy preview, a timestamp in an odd format), switch to `.ignore` and write the label yourself.
````

````exercise
id: m38-l05-e4
type: fill-in
prompt: "Complete the custom quantity control so VoiceOver treats it as one adjustable element: \"Servings, 4, adjustable.\""
code: |
  struct ServingsControl: View {
      @Binding var servings: Int

      var body: some View {
          HStack {
              Button("−") { servings = max(servings - 1, 1) }
              Text("\(servings)")
              Button("+") { servings = min(servings + 1, 12) }
          }
          .accessibilityElement(children: .[[1]])
          .[[2]]("Servings")
          .accessibilityValue("\(servings)")
          .[[3]] { direction in
              switch direction {
              case .[[4]]: servings = min(servings + 1, 12)
              case .decrement: servings = max(servings - 1, 1)
              @unknown default: break
              }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["ignore"]
  - id: "2"
    answers: ["accessibilityLabel"]
  - id: "3"
    answers: ["accessibilityAdjustableAction"]
  - id: "4"
    answers: ["increment"]
hints:
  - "The two buttons shouldn't be separate stops."
solution: |
  ```swift ios
  import SwiftUI

  struct ServingsControl: View {
      @Binding var servings: Int

      var body: some View {
          HStack {
              Button("−") { servings = max(servings - 1, 1) }
              Text("\(servings)")
              Button("+") { servings = min(servings + 1, 12) }
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Servings")
          .accessibilityValue("\(servings)")
          .accessibilityAdjustableAction { direction in
              switch direction {
              case .increment: servings = min(servings + 1, 12)
              case .decrement: servings = max(servings - 1, 1)
              @unknown default: break
              }
          }
      }
  }
  ```

  `.ignore` hides the "−", "4" and "+" elements; the label and value describe the control; the adjustable action makes swipe up and down change it with the same limits as the buttons. A standard `Stepper` would give you all of this for free, which is worth considering before building a custom control.
````

````exercise
id: m38-l05-e5
type: find-errors
prompt: "This product tile was built visually. Which accessibility problems are real?"
code: |
  struct ProductTile: View {
      let name: String
      let price: String
      let isOnSale: Bool
      @Binding var isInCart: Bool

      var body: some View {
          VStack {
              Image("product-photo")
              Text(name)
              Text(price)
                  .foregroundStyle(isOnSale ? .red : .primary)
              Image(systemName: isInCart ? "cart.fill" : "cart")
                  .onTapGesture { isInCart.toggle() }
          }
          .frame(width: 160, height: 220)
          .accessibilityElement(children: .ignore)
      }
  }
choices:
  - text: "The tile is grouped with .ignore but has no label, so VoiceOver reads nothing useful."
    correct: true
    why: "Add accessibilityLabel and accessibilityValue, or use .combine."
  - text: "The cart toggle is a tap gesture on an image, now also hidden by .ignore, so VoiceOver users can't add to cart."
    correct: true
    why: "Use a Button, and with .ignore re-expose it as a named action."
  - text: "The sale is shown only by color."
    correct: true
    why: "Say \"on sale\" in the value (and show it as text for sighted users who can't distinguish red)."
  - text: "The fixed 220-point height will clip the texts at large Dynamic Type sizes."
    correct: true
    why: "Use a minimum height or let the content size the tile."
  - text: "The photo will be read using its asset name unless it's decorative or labeled."
    correct: true
    why: "Image(_:) uses the name as its label key. With .ignore it's hidden here, but on its own it would read \"product-photo\"."
  - text: "VStack can't be an accessibility element."
    correct: false
    why: "Any view can be made an element with accessibilityElement(children:)."
rubric:
  - Flags the unlabeled ignored group.
  - Flags the tap-gesture cart toggle hidden from VoiceOver.
  - Flags color-only sale state.
  - Flags the fixed height under Dynamic Type.
  - Mentions the image's default label.
solution: |
  Five problems. A corrected version:

  ```swift ios
  import SwiftUI

  struct ProductTile: View {
      let name: String
      let price: String
      let isOnSale: Bool
      @Binding var isInCart: Bool

      var body: some View {
          VStack {
              Image(decorative: "product-photo")
                  .resizable()
                  .scaledToFit()
              Text(name)
              HStack {
                  Text(price)
                  if isOnSale {
                      Text("Sale")
                          .font(.caption.bold())
                          .foregroundStyle(.red)
                  }
              }
              Button {
                  isInCart.toggle()
              } label: {
                  Image(systemName: isInCart ? "cart.fill" : "cart")
              }
          }
          .frame(width: 160)
          .frame(minHeight: 220)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(name)
          .accessibilityValue(isOnSale ? "\(price), on sale" : price)
          .accessibilityAction(named: isInCart ? "Remove from cart" : "Add to cart") {
              isInCart.toggle()
          }
      }
  }
  ```

  The photo is decorative because the name says what the product is (a product whose photo shows important detail would get a real description instead). The sale is a word, visible and spoken. The cart is a `Button` for touch and a named action for VoiceOver. The height is a minimum, so text can grow.
````

````exercise
id: m38-l05-e6
type: solve
prompt: |
  Write the logic for an adjustable **timer** control: VoiceOver users swipe up and down to change the time in 5-minute steps between 5 and 120 minutes.

  - `adjusted(_ minutes: Int, increment: Bool) -> Int` returns the new value, clamped to 5…120. A value that isn't a multiple of 5 snaps to the next multiple in the swipe direction (so 12 goes up to 15 and down to 10).
  - `spokenValue(_ minutes: Int) -> String` returns `"45 minutes"`, `"1 hour"`, `"1 hour 5 minutes"`, `"2 hours"` and so on (singular for 1).

  Print the spoken value after swiping up from 12, down from 12, up from 120, down from 5, and up from 55.
starter: |
  func adjusted(_ minutes: Int, increment: Bool) -> Int {
      // your code
      minutes
  }

  func spokenValue(_ minutes: Int) -> String {
      // your code
      ""
  }
hints:
  - "Rounding down to a multiple of 5 is (minutes / 5) * 5 with integer division."
  - "Going up from a value that isn't a multiple: round down, then add 5. Going down: round down, and subtract 5 only if it was already a multiple."
  - "Hours are minutes / 60, the rest is minutes % 60."
rubric:
  - Steps by 5, snaps off-grid values in the swipe direction, clamps to 5…120.
  - Formats hours and minutes with correct singular forms and no "0 minutes".
  - Prints five lines.
solution: |
  ```swift
  func adjusted(_ minutes: Int, increment: Bool) -> Int {
      let floor = (minutes / 5) * 5
      let next: Int
      if increment {
          next = floor + 5
      } else {
          next = floor == minutes ? minutes - 5 : floor
      }
      return min(max(next, 5), 120)
  }

  func unit(_ count: Int, _ singular: String) -> String {
      count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
  }

  func spokenValue(_ minutes: Int) -> String {
      let hours = minutes / 60
      let rest = minutes % 60
      switch (hours, rest) {
      case (0, _): return unit(rest, "minute")
      case (_, 0): return unit(hours, "hour")
      default: return unit(hours, "hour") + " " + unit(rest, "minute")
      }
  }

  print(spokenValue(adjusted(12, increment: true)))
  print(spokenValue(adjusted(12, increment: false)))
  print(spokenValue(adjusted(120, increment: true)))
  print(spokenValue(adjusted(5, increment: false)))
  print(spokenValue(adjusted(55, increment: true)))
  ```

  ```output
  15 minutes
  10 minutes
  2 hours
  5 minutes
  1 hour
  ```

  From 12, up snaps to 15 and down to 10, so the first swipe always lands on the grid. At the ends the value stays put (120 and 5), and VoiceOver repeats the same value, which tells the user they've hit a limit. 60 is spoken as "1 hour," not "60 minutes." In the view, `.accessibilityAdjustableAction { direction in minutes = adjusted(minutes, increment: direction == .increment) }` and `.accessibilityValue(spokenValue(minutes))` use these functions. In a localized app, `Duration` or `DateComponentsFormatter` would produce the words for each language (lesson 6).
````

## Summary

- Standard views are accessible by default. Images need a decision: a label if they carry meaning, `Image(decorative:)` or `accessibilityHidden(true)` if not.
- `accessibilityLabel`, `accessibilityValue`, `accessibilityHint` and `accessibilityAddTraits` map one to one to Module 27's properties. Write labels and values for the ear, from data, in plain Swift you can test.
- `accessibilityElement(children:)`: `.combine` when the children read well in order, `.ignore` plus a label when they don't, `.contain` to group separate elements. Re-expose hidden buttons with `accessibilityAction(named:_:)`.
- `accessibilityRepresentation` makes a custom control speak as a standard one; `accessibilityAdjustableAction` makes a value adjustable with swipes.
- For Dynamic Type, change layout at `isAccessibilitySize`, scale numbers with `@ScaledMetric`, fall back with `ViewThatFits`, and cap only small chrome.
- Preview at `.accessibility5`, audit with Accessibility Inspector, and finish with VoiceOver on a device.
