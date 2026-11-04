---
id: m35-l01
title: Styling, shapes and SF Symbols
description: "The small decisions that make a SwiftUI screen look finished. You pad views edge by edge and align them inside frames, draw with the built-in shapes, fill and stroke them, clip content to a shape, style text and symbols with foregroundStyle and its hierarchical levels, and pick an SF Symbols rendering mode and variable value on purpose, with the iOS version each API needs."
module: m35
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l06]
objectives:
  - Add padding to chosen edges with padding(_:_:) and per-edge amounts with EdgeInsets, and align content inside a frame.
  - Draw Rectangle, RoundedRectangle, Capsule, Circle and UnevenRoundedRectangle, and choose between fill, stroke and strokeBorder.
  - Put a shape behind a view with background(_:in:) and cut a view to a shape with clipShape(_:style:).
  - Compute a concentric inner corner radius and a capsule's corner radius.
  - Style views with foregroundStyle(_:) and the hierarchical styles primary through quinary.
  - Choose among the monochrome, hierarchical, palette and multicolor rendering modes, and use symbolVariant and variable values.
terms:
  - term: Shape
    definition: "A SwiftUI type that describes a 2D outline and fills the space it's offered: Rectangle, RoundedRectangle, Capsule, Circle, Ellipse and your own Shape types. A shape is also a view."
  - term: Hierarchical shape style
    definition: "One of primary, secondary, tertiary, quaternary and quinary (iOS 16). It doesn't bring a color of its own; it makes the current foreground style less prominent by a fixed degree."
  - term: SF Symbols
    definition: "Apple's library of symbol images that sit next to text, scale with the font, and come with variants (fill, circle, slash…) and several rendering modes. You create one with Image(systemName:)."
  - term: Rendering mode (symbols)
    definition: "How SwiftUI colors a symbol's layers: monochrome (one style for all), hierarchical (one style at decreasing levels), palette (a style per layer), multicolor (the symbol's own colors)."
  - term: Variable value
    definition: "A number from 0 to 1 passed to Image(systemName:variableValue:) (iOS 16). Symbols that support it change their appearance to show the value, like bars of signal strength; others ignore it."
mastery:
  - Build a card with 16 points of horizontal padding, 12 of vertical padding and leading-aligned text that fills the row.
  - Pick strokeBorder over stroke when a border must stay inside the frame, and say why.
  - Compute the corner radius of an image inset 8 points inside a card with a 22-point radius.
  - Replace foregroundColor and cornerRadius in old code with foregroundStyle and clipShape.
  - Render a symbol in palette mode with two colors, and say which layer each color goes to.
  - Show a Wi-Fi strength with a variable-value symbol and give it an accessibility label.
resources: [swiftui-symbolrenderingmode, swiftui-foregroundstyle, hig, uikit-scaling-fonts]
cards:
  - id: m35-l01-c1
    front: stroke(_:lineWidth:) vs strokeBorder(_:lineWidth:)?
    back: "stroke draws the line centered on the shape's edge, so half of it falls outside the frame. strokeBorder (on insettable shapes like Circle, Capsule, RoundedRectangle) insets the shape by half the line width first, so the whole line stays inside."
  - id: m35-l01-c2
    front: How do you pick the corner radius of a view inset inside a rounded rectangle?
    back: "Subtract the inset from the outer radius (never below 0). With circular corners the two curves then share a center and the gap stays even around the corner. Card radius 22 with 8 points of padding: 14."
  - id: m35-l01-c3
    front: What does foregroundStyle(.secondary) do?
    back: "It doesn't pick a color. It takes the current foreground style (the innermost foregroundStyle above it, or the default) and renders it at the second level of prominence. Inside .foregroundStyle(.blue), it's a lighter blue."
  - id: m35-l01-c4
    front: The four SF Symbols rendering modes?
    back: "monochrome: every layer in the foreground style. hierarchical: the first layer in the style, the others in its secondary and tertiary levels. palette: each layer in the next style you pass to foregroundStyle(_:_:) or (_:_:_:). multicolor: the symbol's own colors. All iOS 15."
  - id: m35-l01-c5
    front: Image(systemName:variableValue:)?
    back: "iOS 16. Takes a Double from 0 to 1 that a symbol can use to change its appearance, like filling bars of chart.bar.fill or wifi. Apple: if the symbol doesn't support variable values, the parameter has no effect."
---

## The idea in one sentence

Styling in SwiftUI is a handful of composable modifiers (padding, a shape behind or around a view, a foreground style, a symbol's rendering mode), and getting a screen to look right is mostly a matter of applying them in the right order and knowing what each one does at the edges.

> [!note] About this lesson's code
> Blocks that import SwiftUI are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run, so there are no screenshots or measured sizes. What they look like is described from Apple's SwiftUI reference pages, read in November 2026. The corner-radius math and the rendering-mode model are plain Swift and were compiled and run with Swift 6.3; the model follows Apple's descriptions and is not SwiftUI's implementation.

## Padding and alignment in practice

`padding(_:_:)` takes a set of edges and a length. Both are optional. Apple's page: if you omit the length, "SwiftUI uses a platform-specific default amount," chosen to be "appropriate for the platform and the presentation context." That default isn't a documented number, so when a design asks for exact spacing, pass it.

```swift ios
import SwiftUI

struct TripCard: View {
    let title: String
    let dates: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(dates)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal)
    }
}

struct NewBadge: View {
    var body: some View {
        Text("New")
            .font(.caption.bold())
            .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .background(.yellow, in: Capsule())
    }
}
```

Reading `TripCard` from the top:

1. **`VStack(alignment: .leading, spacing: 4)`** lines the two texts up on their leading edges, 4 points apart. The stack's alignment only positions children relative to each other.
2. **`.padding(.horizontal, 16)` then `.padding(.vertical, 12)`** add space inside the card, edge by edge. Each call wraps what came before, so they add up: 32 points wider, 24 taller.
3. **`.frame(maxWidth: .infinity, alignment: .leading)`** makes the card as wide as it's offered and keeps the content on the leading side. Without it the card would be only as wide as its longest text. The frame's `alignment` is what places the stack inside the larger frame; the stack's own alignment can't do that.
4. **`.background(_:in:)`** draws a filled shape behind everything so far, so it covers the padding and the full width.
5. **The last `.padding(.horizontal)`** is outside the background: transparent space between the card and the screen edges, with the system default length.

`NewBadge` uses `padding(_:)` with an `EdgeInsets` value, the form for "a different padding amount to each edge." Here it's symmetric, so `.padding(.horizontal, 10).padding(.vertical, 4)` would do the same; `EdgeInsets` earns its place when the four numbers differ, and it's a value you can store and reuse.

## Shapes

SwiftUI's built-in shapes all fill the space they're offered (lesson 6 of Module 34) and draw an outline inside it:

| Shape | Outline | iOS |
| --- | --- | --- |
| `Rectangle()` | The frame itself | 13 |
| `RoundedRectangle(cornerRadius:style:)` | Rounded corners, `.circular` or `.continuous` | 13 |
| `UnevenRoundedRectangle(topLeadingRadius:…)` | A different radius per corner | 16 |
| `Capsule()` | "a rounded rectangle where the corner radius is chosen as half the length of the rectangle's smallest edge" | 13 |
| `Circle()` | Radius "equals half the length of the frame rectangle's smallest edge", centered | 13 |
| `Ellipse()` | Fills the frame | 13 |

`RoundedCornerStyle` has two cases. `.circular` makes each corner a quarter circle; `.continuous` makes the curve start gently, the look of app icons and system cards. Pass the style explicitly when it matters. Apple's current documentation declares the default as `.continuous`, but that page reflects a newer SDK than this course's CI uses, and a default you can't see is harder to review than a value you wrote.

A shape is a view, so it can stand alone, but most of the time you **fill** it, **stroke** it, or use it as another view's background or clip:

```swift ios
import SwiftUI

struct ShapeGallery: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Rectangle()
                    .fill(.orange)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.orange)
                Capsule()
                    .fill(.orange)
                Circle()
                    .fill(.orange)
            }
            .frame(height: 60)

            HStack(spacing: 16) {
                Circle()
                    .stroke(.indigo, lineWidth: 8)        // centered on the edge
                Circle()
                    .strokeBorder(.indigo, lineWidth: 8)  // entirely inside the edge
                Circle()
                    .fill(.mint)
                    .stroke(.indigo, lineWidth: 4)        // iOS 17: fill, then stroke the same shape
                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 24, topTrailingRadius: 0,
                                       style: .continuous)
                    .fill(.indigo)
            }
            .frame(height: 60)
        }
        .padding()
    }
}
```

- **`fill(_:style:)`** paints the inside with a color or gradient.
- **`stroke(_:lineWidth:)`** traces the outline. The line is centered on the edge, so with a width of 8, 4 points of it sit outside the shape's frame and can be cut off by a neighbor or the screen edge.
- **`strokeBorder(_:lineWidth:)`**, on shapes that conform to `InsettableShape` (all the built-in ones above; a custom `Shape` has to adopt the protocol itself), is "equivalent to insetting `self` by `lineWidth / 2` and stroking the resulting shape," so the whole line stays inside. It's what you want for a ring or a border that must line up with other views.
- **`fill(_:).stroke(_:lineWidth:)`**: from iOS 17, `fill` returns a shape view that you can stroke as well. Before iOS 17 you needed an overlay with a second copy of the shape.

### Shapes behind and around views

`background(_:in:fillStyle:)` (iOS 15) draws "an insettable shape filled with a style" behind a view. `clipShape(_:style:)` (iOS 13) keeps only the part of the view that's inside the shape; "the clipping shape itself isn't visible."

```swift ios
import SwiftUI

struct PhotoCard: View {
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "photo")
                .resizable()
                .scaledToFill()
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))  // 22 − 8
            Text(caption)
                .font(.footnote)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}
```

The image fills a 140-point-tall area and is clipped to a rounded rectangle; without the clip, `scaledToFill()` would let it spill outside its frame. The card's border is an overlay with `strokeBorder`, so the line sits exactly on the card's edge instead of half outside it.

The image's radius is 14 because it sits 8 points inside a card with radius 22. That's the **concentric** rule. Apple's definition, on the `ConcentricRectangle` page: a corner is concentric with its container's corner "when the corner's radius shares a common center with the containing shape's rounded corner radius." Give the inner shape the outer radius minus the inset, and the gap between the two curves stays the same width all the way around the corner. For circular corners it's exact geometry: an arc moved inward by `d` is an arc of radius `r − d` around the same center. For continuous corners it's a close approximation. When the inset is larger than the radius, the inner corner is square:

```swift
/// The radius for a shape inset `inset` points inside a rounded rectangle with radius `outer`.
func concentricRadius(outer: Double, inset: Double) -> Double {
    max(outer - inset, 0)
}

/// Apple: a capsule is a rounded rectangle whose radius is half its smallest edge.
func capsuleRadius(width: Double, height: Double) -> Double {
    min(width, height) / 2
}

let cardRadius = 22.0
for inset in [8.0, 16.0, 30.0] {
    let inner = concentricRadius(outer: cardRadius, inset: inset)
    print("inset \(Int(inset)): inner radius \(Int(inner))")
}
print("capsule 120 × 44: radius \(Int(capsuleRadius(width: 120, height: 44)))")
print("capsule 30 × 80: radius \(Int(capsuleRadius(width: 30, height: 80)))")
```

```output
inset 8: inner radius 14
inset 16: inner radius 6
inset 30: inner radius 0
capsule 120 × 44: radius 22
capsule 30 × 80: radius 15
```

A vertical capsule (30 × 80) uses half its *width*, which is why the same `Capsule()` works for a horizontal badge and a vertical pill without any numbers. (iOS 26 adds `ConcentricRectangle`, which calculates concentric corners for you from a container shape. It's newer than this course's iOS 17 baseline, so the lesson sticks to the arithmetic.)

## foregroundStyle and hierarchical styles

`foregroundStyle(_:)` (iOS 15) sets the style for "foreground elements like text, shapes, and template images (including symbols)" in a view and everything inside it. The style can be a color, a gradient or a semantic style:

```swift ios
import SwiftUI

struct ForecastRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Rain this afternoon", systemImage: "cloud.rain.fill")
                .font(.headline)
            Text("Starts around 3 PM")
                .foregroundStyle(.secondary)
            Text("Updated 10 minutes ago")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.teal)
    }
}
```

`.secondary` and `.tertiary` aren't colors. Apple's page: hierarchical styles "don't impose a style of their own, but instead modify other styles," using "the innermost containing style that you apply with the `foregroundStyle(_:)`" modifier, or the default foreground style if there isn't one. In `ForecastRow`, the headline is teal, the second line a less prominent teal, the third less again. Remove `.foregroundStyle(.teal)` and the same three levels apply to the default text color, which is how system lists get their gray subtitles in both light and dark mode without any color picked by you.

The levels are `primary`, `secondary`, `tertiary`, `quaternary` (all iOS 15) and `quinary` (iOS 16). The last two are faint enough that they're mostly used for fills and separators, as in `PhotoCard`'s border.

> [!tip] Fill a single shape with fill, not foregroundStyle
> Apple's tip on the `foregroundStyle(_:)` page: "If you want to fill a single `Shape` instance with a style, use the `fill(style:)` shape modifier instead because it's more efficient."

## SF Symbols

`Image(systemName:)` creates a symbol by name. Use the SF Symbols app to find names; a symbol's availability depends on the OS version, and the app shows which release introduced each one. Symbols behave like text: they take the current font, so `.font(.title)` or a text style makes them grow with Dynamic Type, and `imageScale(_:)` picks `.small`, `.medium` or `.large` relative to that font.

### Variants

`symbolVariant(_:)` (iOS 15) asks every symbol in a view for a variant such as `.fill`, `.circle` or `.slash`. Apple's notes: "A symbol that doesn't have the specified variant remains unaffected," the effects of several calls accumulate, and `Label("Airplane", systemImage: "airplane").symbolVariant(.circle.fill)` produces the same image as `airplane.circle.fill`. Some containers pick a variant for you. Apple's `SymbolVariants` page: "SwiftUI automatically applies the `fill` symbol variant for items that appear in the `content` closure of the `swipeActions(edge:allowsFullSwipe:content:)` method, or as the tab bar items of a `TabView`." There, write the plain name (`house`, not `house.fill`).

### Rendering modes

A symbol is drawn in layers. `symbolRenderingMode(_:)` (iOS 15) decides how they're colored:

| Mode | Apple's description |
| --- | --- |
| `.monochrome` | "a single layer filled with the foreground style" |
| `.hierarchical` | "fills the first layer with the foreground style, and the others the secondary, and tertiary variants of the foreground style" |
| `.palette` | "maps each successively defined layer in the image to the next of the primary, secondary, and tertiary variants of the foreground style" |
| `.multicolor` | the layers "may be filled with their own inherent styles, or the foreground style" |

You pass palette styles with `foregroundStyle(_:_:)` or `foregroundStyle(_:_:_:)`. Apple adds that "specifying multiple foreground styles implies switching to palette rendering mode," so the mode can be left out in that case. The hierarchical page says the same two modifiers can set its levels explicitly, and both modes derive the missing levels from a single style, so the real difference is intent, in Apple's one-line summaries: hierarchical applies "different opacities" to one foreground style, palette applies "different styles" to the layers.

Here's a model of those four sentences: give it a number of layers, a mode and the styles you passed, and it says what fills each layer. It covers hierarchical mode with one style only, the common case.

```swift
enum RenderingMode {
    case monochrome, hierarchical, palette, multicolor
}

/// What fills each layer of a symbol, following Apple's description of each mode.
func layerFills(layers: Int, mode: RenderingMode, styles: [String]) -> [String] {
    let levels = ["primary", "secondary", "tertiary"]
    return (0..<layers).map { layer in
        switch mode {
        case .monochrome:
            return styles[0]
        case .hierarchical:   // one style, at decreasing levels
            return "\(styles[0]) (\(levels[min(layer, 2)]))"
        case .palette:
            // With a single style, Apple says SwiftUI derives the other levels from it.
            return styles.count == 1 ? "\(styles[0]) (\(levels[min(layer, 2)]))" : styles[min(layer, styles.count - 1)]
        case .multicolor:
            return "own color \(layer + 1)"
        }
    }
}

// exclamationmark.triangle.fill: layer 1 is the exclamation mark, layer 2 the triangle.
print("monochrome:  ", layerFills(layers: 2, mode: .monochrome, styles: ["purple"]))
print("hierarchical:", layerFills(layers: 2, mode: .hierarchical, styles: ["purple"]))
print("palette:     ", layerFills(layers: 2, mode: .palette, styles: ["yellow", "cyan"]))
print("multicolor:  ", layerFills(layers: 2, mode: .multicolor, styles: ["purple"]))
```

```output
monochrome:   ["purple", "purple"]
hierarchical: ["purple (primary)", "purple (secondary)"]
palette:      ["yellow", "cyan"]
multicolor:   ["own color 1", "own color 2"]
```

The four lines are the four examples on Apple's rendering-mode pages: monochrome purple; hierarchical "purple as the tint color for the exclamation mark, and lower opacity purple for the triangle"; palette "yellow as the tint color for the exclamation mark" with the triangle in cyan; and multicolor's built-in "yellow for the triangle and white for the exclamation mark." The model's handling of palette with fewer styles than layers is a guess: Apple only documents the one-style case.

In SwiftUI:

```swift ios
import SwiftUI

struct WarningSymbols: View {
    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.purple)
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.purple)
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow, .cyan)          // two styles imply .palette
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
        }
        .font(.largeTitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Warning symbols in four rendering modes")
    }
}
```

Which mode to use: monochrome when the symbol should look like the text around it; hierarchical for depth in one tint (the usual choice for a prominent icon); palette when a design calls for specific colors per layer; multicolor when the symbol's meaning is in its colors, like a weather symbol with a yellow sun. Not every symbol has a multicolor version; one without it renders in the foreground style.

### Variable values

`Image(systemName:variableValue:)` (iOS 16) takes "an optional value between `0.0` and `1.0` that the rendered image can use to customize its appearance." Symbols that support it, like `chart.bar.fill` in Apple's example, or `wifi`, fill in more of their layers as the value grows. "If the symbol doesn't support variable values, this parameter has no effect," and the SF Symbols app (version 4 or later) shows which ones do.

```swift ios
import SwiftUI

struct SignalIndicator: View {
    let strength: Double   // 0...1

    var body: some View {
        Image(systemName: "wifi", variableValue: strength)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(strength < 0.34 ? Color.orange : Color.primary)
            .font(.title2)
            .accessibilityLabel("Wi-Fi signal")
            .accessibilityValue("\(Int((strength * 100).rounded())) percent")
    }
}
```

How many arcs light up at a given value is decided by the symbol's design, not by a formula Apple publishes, so don't promise "three bars at 0.5" in a spec without checking in the SF Symbols app. The picture also says nothing to VoiceOver on its own: the label and value do.

> [!note] Symbol effects
> iOS 17 added animated symbol effects. `.symbolEffect(.bounce, value: counter)` bounces the symbols inside a view each time `counter` changes, in Apple's example. They're animation, so they belong with lesson 6's advice on Reduce Motion.

### Availability at a glance

| API | iOS |
| --- | --- |
| `padding(_:_:)`, `padding(_:)` with `EdgeInsets`, `frame`, `clipShape(_:style:)` | 13 |
| `Rectangle`, `RoundedRectangle`, `Capsule`, `Circle`, `Ellipse`, `Shape.stroke(_:lineWidth:)` | 13 |
| `foregroundStyle(_:)`, `(_:_:)`, `(_:_:_:)`, `primary`…`quaternary`, `background(_:in:)` | 15 |
| `symbolRenderingMode(_:)`, `symbolVariant(_:)` | 15 |
| `UnevenRoundedRectangle`, `quinary`, `Image(systemName:variableValue:)` | 16 |
| Fill and stroke chained on one shape, `strokeBorder` returning a shape view, `symbolEffect` | 17 |

All of these were checked against Apple's documentation pages for each symbol. With this course's iOS 17 deployment target, none need an `#available` check.

## Common mistakes

> [!error] foregroundColor and cornerRadius from old answers
> Apple's current documentation marks `foregroundColor(_:)` deprecated (renamed to `foregroundStyle(_:)`) and `cornerRadius(_:antialiased:)` deprecated with "Use `clipShape` or `fill` instead." Module 34 mentioned them; here's the replacement for each: `.foregroundStyle(.red)`, and `.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))` or `.background(.blue, in: RoundedRectangle(…))`.

> [!error] A border that's thinner on one side
> `stroke` puts half the line outside the shape, and a neighboring view or a clip can hide that half. Use `strokeBorder` for borders and rings.

> [!error] The same radius inside and outside
> An image with radius 22 inside a card with radius 22 and 8 points of padding has a gap that's wider at the corners than along the sides. Inner radius = outer − inset.

> [!error] Expecting .secondary to be gray
> It's the second level of whatever foreground style is in effect. Inside `.foregroundStyle(.red)`, `.secondary` is a lighter red. If you need gray, say so with a color.

> [!error] A fixed font size for symbols
> `.font(.system(size: 17))` stops a symbol from following Dynamic Type. Use a text style like `.body` or `.title2`, the same as for text, so icons and labels scale together.

## Exercises

````exercise
id: m35-l01-e1
type: prediction
prompt: "A settings row has a 12-point radius and an icon tile inset 4 points from its top, leading and bottom edges. The icon itself sits 6 points inside the tile. What does this print?"
code: |
  func concentricRadius(outer: Double, inset: Double) -> Double {
      max(outer - inset, 0)
  }

  func capsuleRadius(width: Double, height: Double) -> Double {
      min(width, height) / 2
  }

  let rowRadius = 12.0
  let tileRadius = concentricRadius(outer: rowRadius, inset: 4)
  let iconRadius = concentricRadius(outer: tileRadius, inset: 6)
  print(Int(tileRadius), Int(iconRadius))

  let rowHeight = 44.0
  let tileSide = rowHeight - 4 - 4
  print(Int(tileSide), Int(capsuleRadius(width: tileSide, height: tileSide)))
  print(Int(capsuleRadius(width: 200, height: rowHeight)))
output: |
  8 2
  36 18
  22
hints:
  - "12 − 4, then that result − 6."
  - "A capsule's radius is half its smallest edge; a square capsule is a circle."
solution: |
  ```output
  8 2
  36 18
  22
  ```

  The tile is 4 points inside the row, so its radius is 12 − 4 = 8. The icon is 6 points inside the tile: 8 − 6 = 2. Insets accumulate; each level subtracts its own inset from the level outside it. The tile is 44 − 8 = 36 points square, and a `Capsule` of a square has radius 18, which makes it a circle. A row-shaped capsule 200 × 44 has radius 22, half its height.
````

````exercise
id: m35-l01-e2
type: prediction
prompt: "The rendering-mode model from the lesson, for a three-layer symbol. What does it print?"
code: |
  enum RenderingMode {
      case monochrome, hierarchical, palette, multicolor
  }

  func layerFills(layers: Int, mode: RenderingMode, styles: [String]) -> [String] {
      let levels = ["primary", "secondary", "tertiary"]
      return (0..<layers).map { layer in
          switch mode {
          case .monochrome:
              return styles[0]
          case .hierarchical:   // one style, at decreasing levels
              return "\(styles[0]) (\(levels[min(layer, 2)]))"
          case .palette:
              return styles.count == 1 ? "\(styles[0]) (\(levels[min(layer, 2)]))" : styles[min(layer, styles.count - 1)]
          case .multicolor:
              return "own color \(layer + 1)"
          }
      }
  }

  for fill in layerFills(layers: 3, mode: .hierarchical, styles: ["blue"]) {
      print(fill)
  }
  print(layerFills(layers: 3, mode: .palette, styles: ["blue", "red", "green"]).joined(separator: ", "))
  print(layerFills(layers: 3, mode: .palette, styles: ["blue"]).joined(separator: ", "))
output: |
  blue (primary)
  blue (secondary)
  blue (tertiary)
  blue, red, green
  blue (primary), blue (secondary), blue (tertiary)
hints:
  - "Hierarchical mode only uses the first style."
  - "Palette with one style derives the other levels from it."
solution: |
  ```output
  blue (primary)
  blue (secondary)
  blue (tertiary)
  blue, red, green
  blue (primary), blue (secondary), blue (tertiary)
  ```

  Hierarchical mode fills the first layer with the foreground style and the others with its secondary and tertiary levels. Palette maps layers 1, 2 and 3 to the three styles in order. Palette with a single style is the case where Apple says SwiftUI "automatically derives the others from that style", so in this model it comes out the same as hierarchical. `joined(separator:)` prints the strings themselves, without the quotes an array would show.
````

````exercise
id: m35-l01-e3
type: comprehension
prompt: "A weather app shows cloud.sun.rain.fill next to the forecast. The designer wants the sun yellow, the cloud white and the rain blue, exactly as the symbol is designed, and the same in light and dark mode. Which code fits?"
choices:
  - text: "Image(systemName: \"cloud.sun.rain.fill\").symbolRenderingMode(.multicolor)"
    correct: true
    why: "Multicolor uses the symbol's inherent colors for its layers, which is what the designer described."
  - text: "Image(systemName: \"cloud.sun.rain.fill\").symbolRenderingMode(.hierarchical).foregroundStyle(.yellow)"
    correct: false
    why: "Hierarchical uses one style at three levels of prominence: everything would be shades of yellow."
  - text: "Image(systemName: \"cloud.sun.rain.fill\").foregroundStyle(.white)"
    correct: false
    why: "With one style and no mode, the symbol renders as a single color."
  - text: "Image(systemName: \"cloud.sun.rain.fill\").symbolVariant(.fill)"
    correct: false
    why: "A variant changes which drawing you get (filled, circled), not how it's colored. The name already includes .fill."
solution: |
  **`.symbolRenderingMode(.multicolor)`.** Apple's description: the layers "may be filled with their own inherent styles, or the foreground style." For a weather symbol, the inherent colors are the point. `.palette` with `.foregroundStyle(.white, .yellow, .blue)` could approximate it, but you'd have to know the layer order and you'd be redoing the symbol designer's work.
````

````exercise
id: m35-l01-e4
type: fill-in
prompt: "Complete the badge: the text gets 10 points of padding on the leading and trailing edges and 4 on top and bottom, a capsule background in the tint color, white text, and a symbol before it in palette mode (white checkmark on a translucent white circle)."
code: |
  struct DoneBadge: View {
      var body: some View {
          HStack(spacing: 4) {
              Image(systemName: "checkmark.circle.fill")
                  .[[1]](.white, Color.white.opacity(0.4))
              Text("Done")
          }
          .font(.caption.bold())
          .foregroundStyle(.white)
          .padding(.[[2]], 10)
          .padding(.vertical, 4)
          .background(.tint, in: [[3]]())
      }
  }
blanks:
  - id: "1"
    answers: ["foregroundStyle"]
  - id: "2"
    answers: ["horizontal"]
  - id: "3"
    answers: ["Capsule"]
hints:
  - "Two styles on one call imply palette mode."
  - "Edge.Set has a member for leading and trailing together."
solution: |
  ```swift ios
  import SwiftUI

  struct DoneBadge: View {
      var body: some View {
          HStack(spacing: 4) {
              Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.white, Color.white.opacity(0.4))
              Text("Done")
          }
          .font(.caption.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(.tint, in: Capsule())
      }
  }
  ```

  `foregroundStyle(_:_:)` sets primary and secondary styles, and Apple says multiple foreground styles imply palette mode: the checkmark (first layer) is white, the circle (second layer) translucent white. `.horizontal` is the `Edge.Set` for leading and trailing. `Capsule()` gives a radius of half the badge's height, so it stays a pill at any text size.
````

````exercise
id: m35-l01-e5
type: find-errors
prompt: "This avatar view was copied from an old answer. Which of these are real problems for an iOS 17 app?"
code: |
  struct Avatar: View {
      let initials: String

      var body: some View {
          Text(initials)
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
              .frame(width: 56, height: 56)
              .background(Color.indigo)
              .cornerRadius(28)
              .overlay {
                  Circle().stroke(.white, lineWidth: 4)
              }
      }
  }
choices:
  - text: "foregroundColor(_:) and cornerRadius(_:) are marked deprecated in Apple's current documentation."
    correct: true
    why: "Use foregroundStyle(_:), and a shape: .background(.indigo, in: Circle()) or .clipShape(Circle())."
  - text: "The 4-point stroke is centered on the circle's edge, so half of it falls outside the 56-point frame."
    correct: true
    why: "strokeBorder keeps the whole line inside, so the avatar stays 56 points wide visually."
  - text: "A fixed font size means the initials don't scale with Dynamic Type."
    correct: true
    why: "That may be acceptable for a fixed-size avatar, but it's a choice to make on purpose. A text style plus a frame that scales (or @ScaledMetric, Module 38) keeps it accessible."
  - text: "Text can't have a background."
    correct: false
    why: "Any view can have a background."
  - text: "overlay must come before frame."
    correct: false
    why: "Here the overlay is meant to match the 56-point frame, so it belongs after it."
rubric:
  - Flags both deprecated modifiers and names their replacements.
  - Explains stroke versus strokeBorder.
  - Mentions the fixed font size as a Dynamic Type trade-off.
  - Doesn't flag the background or the overlay order.
solution: |
  Three problems. A version that keeps the look:

  ```swift ios
  import SwiftUI

  struct Avatar: View {
      let initials: String

      var body: some View {
          Text(initials)
              .font(.title3.weight(.semibold))
              .foregroundStyle(.white)
              .frame(width: 56, height: 56)
              .background(.indigo, in: Circle())
              .overlay {
                  Circle().strokeBorder(.white, lineWidth: 4)
              }
      }
  }
  ```

  `background(_:in:)` draws the circle behind the text in one step, which replaces the color plus `cornerRadius(28)`. `strokeBorder` insets the ring by half its width so it isn't clipped by neighbors. The text style follows Dynamic Type; with a fixed 56-point frame, very large text sizes would need the frame to grow too, which Module 38 covers with `@ScaledMetric`.
````

````exercise
id: m35-l01-e6
type: solve
prompt: |
  Badges in your app are a text with padding and a capsule background. Write a plain-Swift helper the design team can use to check numbers:

  - `struct Insets { var top, leading, bottom, trailing: Double }` with a static `func symmetric(horizontal: Double, vertical: Double) -> Insets`.
  - `func badgeSize(textWidth: Double, textHeight: Double, padding: Insets) -> (width: Double, height: Double, radius: Double)`, where the radius is the capsule's (half the smallest edge).

  Then print the size and radius of a 34 × 16 text with symmetric padding 10/4, of a 12 × 16 text (a single digit) with the same padding, and of a 34 × 16 text with insets top 2, leading 12, bottom 6, trailing 8. Format each line as `W×H r=R` with whole numbers.
starter: |
  struct Insets {
      var top, leading, bottom, trailing: Double

      static func symmetric(horizontal: Double, vertical: Double) -> Insets {
          // your code
          Insets(top: 0, leading: 0, bottom: 0, trailing: 0)
      }
  }

  func badgeSize(textWidth: Double, textHeight: Double, padding: Insets) -> (width: Double, height: Double, radius: Double) {
      // your code
      (0, 0, 0)
  }
hints:
  - "Width adds leading and trailing; height adds top and bottom."
  - "radius = min(width, height) / 2."
rubric:
  - symmetric(horizontal:vertical:) sets leading/trailing and top/bottom correctly.
  - badgeSize adds the right insets to each dimension.
  - The radius is half the smallest edge.
  - Prints the three lines in the requested format.
solution: |
  ```swift
  struct Insets {
      var top, leading, bottom, trailing: Double

      static func symmetric(horizontal: Double, vertical: Double) -> Insets {
          Insets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
      }
  }

  func badgeSize(textWidth: Double, textHeight: Double, padding: Insets) -> (width: Double, height: Double, radius: Double) {
      let width = textWidth + padding.leading + padding.trailing
      let height = textHeight + padding.top + padding.bottom
      return (width, height, min(width, height) / 2)
  }

  func describe(_ size: (width: Double, height: Double, radius: Double)) -> String {
      "\(Int(size.width))×\(Int(size.height)) r=\(Int(size.radius))"
  }

  let standard = Insets.symmetric(horizontal: 10, vertical: 4)
  print(describe(badgeSize(textWidth: 34, textHeight: 16, padding: standard)))
  print(describe(badgeSize(textWidth: 12, textHeight: 16, padding: standard)))
  print(describe(badgeSize(textWidth: 34, textHeight: 16,
                           padding: Insets(top: 2, leading: 12, bottom: 6, trailing: 8))))
  ```

  ```output
  54×24 r=12
  32×24 r=12
  54×24 r=12
  ```

  The same total padding gives the same size, whichever edges it's on: the third badge has its text shifted 4 points right and 2 up inside the same 54 × 24 capsule. That's the `EdgeInsets` case where the four values differ. The single-digit badge is still wider than tall, so it stays a pill; if you wanted a circle for one digit you'd give it a minimum width equal to its height with `frame(minWidth:)`.
````

## Summary

- `padding(_:_:)` pads chosen edges; omit the length and you get a platform default that isn't a documented number. `padding(_:)` with `EdgeInsets` sets each edge. A frame's `alignment` places content inside a larger frame; a stack's alignment only lines children up with each other.
- Built-in shapes fill the space offered. Pass the corner style (`.circular`, `.continuous`) explicitly. `Capsule` and `Circle` derive their radius from the smallest edge. `UnevenRoundedRectangle` is iOS 16.
- `fill` paints the inside, `stroke` centers the line on the edge, `strokeBorder` keeps it inside. From iOS 17 you can chain fill and stroke on one shape.
- `background(_:in:)` puts a filled shape behind a view; `clipShape(_:style:)` keeps only what's inside a shape. Inner radius = outer radius − inset.
- `foregroundStyle(_:)` styles text, shapes and symbols; `secondary`…`quinary` are levels of the current style, not colors.
- SF Symbols follow the font. Choose monochrome, hierarchical, palette or multicolor on purpose; two styles in `foregroundStyle` imply palette. `variableValue` (iOS 16) only affects symbols that support it, and still needs an accessibility value.
