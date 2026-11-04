---
id: m34-l02
title: Views and modifiers
description: "A modifier doesn't change a view: it wraps it in a new one. That single fact explains why some View hides the concrete type, why .padding().background() and .background().padding() draw different things, and why Image's resizable() has to come first. You bundle repeated modifiers into a custom ViewModifier, split a long body into small views with clear inputs, and set up #Preview to see each one in Xcode's canvas."
module: m34
order: 2
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l01]
objectives:
  - Explain what a modifier returns and why chaining modifiers builds a nested type.
  - Predict how the order of padding, background, frame and border changes what's drawn.
  - Tell modifiers that wrap one view from modifiers whose effect flows down to child views, like font(_:).
  - Write a custom ViewModifier and expose it as a View extension method.
  - Extract part of a body into its own View struct with only the inputs it needs.
  - Write #Preview blocks for a view in several states.
terms:
  - term: Modifier
    definition: "A method on View, such as padding(_:) or font(_:), that returns a new view wrapping the original with some change in layout, appearance, behavior or environment."
  - term: ModifiedContent
    definition: "The generic struct that modifier(_:) returns: the original content plus the modifier applied to it. Chaining modifiers nests these wrappers."
  - term: ViewModifier
    definition: "A protocol for reusable modifiers. Its body(content:) method receives the view being modified and returns the modified view."
  - term: "#Preview"
    definition: "A Swift macro that registers a view to show in Xcode's canvas. It's development-time only; the closure returns the view to preview."
mastery:
  - Draw the nested wrappers for a chain of four modifiers and say the size of each.
  - Fix a button whose colored background doesn't include its padding.
  - Turn three repeated modifier lines into a ViewModifier plus an extension method.
  - Split a 60-line body into named subviews that each take only the data they show.
  - Write previews for a view's empty, normal and error states.
resources: [swift-book-opaque-types, swift-book-protocols, swift-book-extensions, hig]
cards:
  - id: m34-l02-c1
    front: What does a SwiftUI modifier return?
    back: "A new view that wraps the original one. It doesn't change the original. Chaining modifiers nests wrappers, so each modifier acts on the result of everything before it."
  - id: m34-l02-c2
    front: Text("Save").padding().background(.blue) vs Text("Save").background(.blue).padding()?
    back: "In the first, the background wraps the padded view, so the blue area includes the padding. In the second, the background wraps only the text, and the padding adds transparent space around the blue area."
  - id: m34-l02-c3
    front: Why must Image's resizable() come before frame(...) or padding()?
    back: "resizable() is a method on Image that returns Image. General modifiers return some View, which hides the concrete type, so after them there's no resizable() to call."
  - id: m34-l02-c4
    front: How do you package a set of modifiers for reuse?
    back: "Write a struct conforming to ViewModifier with body(content:) applying the modifiers, then add a View extension method that calls modifier(YourModifier()). Callers write .yourStyle()."
  - id: m34-l02-c5
    front: Why extract subviews in SwiftUI?
    back: "Each subview gets a name, a short body and explicit inputs. It can be previewed and reused on its own, and it depends only on the data passed to it."
---

## The idea in one sentence

A modifier never changes the view you call it on: it **returns a new view that wraps it**, so a chain of modifiers is a set of nested wrappers, read from the inside out, and their order is part of what you're describing.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run. `#Preview` blocks are marked illustrative: they're shown as you'd write them in Xcode but weren't compiled by the course's check. The plain-Swift models were compiled and run. Xcode's canvas is described from Apple's documentation and wasn't checked in Xcode for this lesson.

## A view and its modifiers

```swift ios
import SwiftUI

struct SaveButtonLabel: View {
    var body: some View {
        Text("Save")
            .font(.headline)
            .padding(12)
            .background(.blue)
            .foregroundStyle(.white)
    }
}
```

Each line after `Text("Save")` is a method call on the result of the line above. Apple's View page: "Modifiers work by wrapping the view instance on which you call them in another view with the specified characteristics." So:

1. `Text("Save")` is a text view.
2. `.font(.headline)` returns a text whose font is headline.
3. `.padding(12)` returns a view that contains (2) with 12 points of space around it.
4. `.background(.blue)` returns a view that draws blue behind (3), filling (3)'s whole size.
5. `.foregroundStyle(.white)` returns a view that sets the foreground style for everything inside (4).

`body` returns (5). Its real type is a nest of generic structs, one level per modifier, which is why `body` is declared `some View`: you'd never want to spell that type, and it changes every time you edit the chain. Apple's article "Declaring a custom view" says it directly: "The exact type depends on the body's content, which varies as you edit the body during development. Swift infers the exact type automatically."

## Why order matters

Because each modifier wraps the result so far, a modifier only "sees" what's inside it. Here's a model of that in plain Swift. Each layer is a struct holding the layer inside it and computing its own size:

```swift
struct Size {
    var width: Int
    var height: Int
}

protocol Layer {
    var size: Size { get }
    func describe(indent: String) -> [String]
}

struct TextLayer: Layer {
    let text: String
    var size: Size { Size(width: text.count * 10, height: 20) }
    func describe(indent: String) -> [String] {
        ["\(indent)Text \"\(text)\" \(size.width)×\(size.height)"]
    }
}

struct Padding: Layer {
    let content: any Layer
    let amount: Int
    var size: Size {
        Size(width: content.size.width + 2 * amount, height: content.size.height + 2 * amount)
    }
    func describe(indent: String) -> [String] {
        ["\(indent)padding(\(amount)) \(size.width)×\(size.height)"] + content.describe(indent: indent + "  ")
    }
}

struct Background: Layer {
    let content: any Layer
    let color: String
    var size: Size { content.size }
    func describe(indent: String) -> [String] {
        ["\(indent)\(color) background \(size.width)×\(size.height)"] + content.describe(indent: indent + "  ")
    }
}

extension Layer {
    func padding(_ amount: Int) -> Padding { Padding(content: self, amount: amount) }
    func background(_ color: String) -> Background { Background(content: self, color: color) }
}

let pill = TextLayer(text: "Save").padding(8).background("blue")
let tight = TextLayer(text: "Save").background("blue").padding(8)

for line in pill.describe(indent: "") { print(line) }
print("---")
for line in tight.describe(indent: "") { print(line) }
```

```output
blue background 56×36
  padding(8) 56×36
    Text "Save" 40×20
---
padding(8) 56×36
  blue background 40×20
    Text "Save" 40×20
```

The outermost layer is the **last** modifier in the chain. In `pill`, the background wraps the padded text, so it's as big as the padding: a 56×36 blue pill with the text inside. In `tight`, the background wraps only the 40×20 text, and the padding adds 8 transparent points around the blue. Both are 56×36 in the layout, but they look different.

> [!warning] A model
> Real SwiftUI text measures itself with the font, and padding and backgrounds take part in the layout process from lesson 6. What the model gets right is the nesting: each modifier wraps what's before it, and a background is as large as the thing it wraps.

Apple's "Configuring views" article shows the same effect with `frame` and `border`:

```swift ios
import SwiftUI

struct FrameThenBorder: View {
    var body: some View {
        Text("Title")
            .frame(width: 100)
            .border(.gray)
    }
}

struct BorderThenFrame: View {
    var body: some View {
        Text("Title")
            .border(.gray)
            .frame(width: 100)
    }
}
```

In the first, the border wraps a 100-point-wide frame, so it "outlines the full width of the frame". In the second, the border wraps only the text, and the frame is an invisible 100-point box around an outline that hugs the text. Read chains from the top down as "take this, then wrap it in that".

### Modifiers that flow down

Some modifiers don't draw anything themselves. They set a value for the views inside them, and every descendant that cares uses it, unless a closer modifier overrides it. `font(_:)` is the usual example:

```swift ios
import SwiftUI

struct Notes: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Title")
                .font(.title)          // overrides the stack's font for this text
            Text("First body line.")
            Text("Second body line.")
        }
        .font(.body)                   // default for every text in the stack
    }
}
```

Apple: "The effects of a modifier propagate to child views that don't explicitly override the modifier." A `VStack` has no text of its own, but its texts use the font set on it. `foregroundStyle(_:)` in the first example works the same way. These values travel through the **environment**, which Module 36 covers.

### Type-specific modifiers come first

A few modifiers exist only on one view type and return that type. `Image`'s `resizable()` is the one you'll hit first: it's a method on `Image` that returns `Image`. A general modifier returns `some View`, which hides the concrete type, so after one there's no `resizable()` to call. The same rule in plain Swift:

```swift no-compile value of type 'some Layer' has no member 'resizable'
protocol Layer {}

struct ImageLayer: Layer {
    let name: String
    var isResizable = false
    func resizable() -> ImageLayer {
        ImageLayer(name: name, isResizable: true)
    }
}

struct Padding: Layer {
    let content: any Layer
}

extension Layer {
    func padding() -> some Layer { Padding(content: self) }
}

let ok = ImageLayer(name: "photo").resizable().padding()
let broken = ImageLayer(name: "photo").padding().resizable()
```

Swift 6.3: `error: value of type 'some Layer' has no member 'resizable'`. In SwiftUI the message names `some View` instead. The fix is order: `Image("photo").resizable().scaledToFit().frame(width: 80)`, with the image-specific call right after the initializer.

## A custom ViewModifier

When the same three or four modifiers appear on many views, put them in one place. Apple's pattern, from "Reducing view modifier maintenance": a struct conforming to `ViewModifier`, plus an extension on `View` so callers can write it like a built-in modifier.

```swift ios
import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 22))
            .shadow(radius: 4, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

struct ExpenseCard: View {
    let title: String
    let amount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(amount)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}
```

- **`body(content:)`** is the protocol's requirement. `content` is the view the modifier is applied to (its type is the associated type `Content`, a stand-in SwiftUI provides). You return what it should look like.
- **`modifier(_:)`** applies a `ViewModifier` and returns a `ModifiedContent` of the view and the modifier.
- **The extension** is what makes it read like SwiftUI: `.cardStyle()` instead of `.modifier(CardStyle())`. The name should say what it's for (`cardStyle`, `errorText`), not what it does (`paddedRoundedShadow`).

A plain extension method that applies the modifiers directly (`func cardStyle() -> some View { padding().background(…) }`) also works. A `ViewModifier` struct earns its place when the modifier needs its own state or environment values, because, like a view, it can declare `@State` and `@Environment` properties; you'll see that in Module 36.

Like `View`, `ViewModifier` is isolated to the main actor: Apple's page says a conforming type "inherits `@preconcurrency @MainActor` isolation from the protocol" when the conformance is in the type's declaration.

## Extracting subviews

A `body` grows quickly. Once it doesn't fit on the screen, split it. The tool is the same as everywhere in Swift: give a piece a name and a clear set of inputs.

```swift ios
import SwiftUI

struct Expense: Identifiable {
    let id: Int
    let title: String
    let amount: Double
}

struct ExpenseSummary: View {
    let expenses: [Expense]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TotalHeader(total: expenses.reduce(0) { $0 + $1.amount }, count: expenses.count)
            ForEach(expenses) { expense in
                ExpenseRow(title: expense.title, amount: expense.amount)
            }
        }
        .padding()
    }
}

struct TotalHeader: View {
    let total: Double
    let count: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text(total, format: .currency(code: "USD"))
                .font(.largeTitle.bold())
            Text(count == 1 ? "1 expense" : "\(count) expenses")
                .foregroundStyle(.secondary)
        }
    }
}

struct ExpenseRow: View {
    let title: String
    let amount: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .monospacedDigit()
        }
    }
}
```

- **Each subview takes only what it shows.** `ExpenseRow` takes a title and an amount, not the whole `Expense` or the array. That keeps it reusable and easy to preview, and it makes the dependency visible: Apple's "Declaring a custom view" says that "if an input value changes, SwiftUI notices the change and redraws only the affected parts of your interface."
- **Inputs are `let`.** The memberwise initializer comes for free.
- **Extraction is cheap.** A view struct with two `let` properties is a couple of values; there's no `UIView` allocation behind it. Don't hesitate to make small views.

You can also split a body into computed properties or methods that return `some View`. That works for small pieces inside one view, but they need `@ViewBuilder` if they contain more than one view or an `if`, which is lesson 3's topic. Separate structs are the better default.

## Previews

The `#Preview` macro tells Xcode what to show in the canvas next to your code. Apple's `Preview(_:body:)` page: "Use this macro to display a SwiftUI preview in the canvas. You typically specify at least one preview macro for every View that your app defines."

```swift illustrative
#Preview {
    ExpenseRow(title: "Coffee", amount: 3.5)
        .padding()
}

#Preview("Empty") {
    ExpenseSummary(expenses: [])
}

#Preview("Three expenses") {
    ExpenseSummary(expenses: [
        Expense(id: 1, title: "Coffee", amount: 3.5),
        Expense(id: 2, title: "Lunch", amount: 12),
        Expense(id: 3, title: "Taxi", amount: 18.25),
    ])
}
```

- **Names** are optional. Without one, Apple says the canvas labels each preview by its line number. With several previews in a file, the canvas lets you pick between them.
- **Preview the states, not just the happy path.** Empty, one item, many items, a very long title, a large Dynamic Type size. A view whose inputs are plain values is trivial to preview in every state, which is one more reason to extract subviews with small inputs.
- **Bindings in previews.** A view that takes a binding needs state to bind to. The `@Previewable` macro lets you declare it inline: `#Preview { @Previewable @State var isOn = false; Toggle("Wi-Fi", isOn: $isOn) }` (Apple lists `Previewable()` as available from iOS 17).

Previews only feed Xcode's canvas; your app never shows them. Treat them as quick visual checks, not tests: Module 33's tests check logic, and previews let you look at layouts.

## Common mistakes

> [!error] The background doesn't include the padding
> `Text("Save").background(.blue).padding()` puts transparent space around a blue box that hugs the text. You wanted `.padding().background(.blue)`. Read the chain as wrappers: the background is only as big as what's before it.

> [!error] error: value of type 'some View' has no member 'resizable'
> `Image("photo").frame(width: 80).resizable()`. `resizable()` exists only on `Image`, and `frame` returned `some View`. Call `resizable()` first.

> [!error] Using deprecated spellings from old answers
> Many examples online use `.foregroundColor(.red)`, `.cornerRadius(12)` or `.background(Color.blue, alignment: …)`. Apple's current documentation marks these deprecated in favor of `foregroundStyle(_:)`, `clipShape(_:)` with a shape, and `background(alignment:content:)` or `background(_:in:)`. They still compile, but new code should use the replacements.

> [!error] One giant body
> A 150-line `body` with nested stacks and conditionals is hard to read and to preview. Extract pieces into structs with explicit inputs. If a piece needs the whole model to work, it's probably two pieces.

## Exercises

````exercise
id: m34-l02-e1
type: prediction
prompt: "The layer model from the lesson, extended with a border layer. What does it print?"
code: |
  struct Size {
      var width: Int
      var height: Int
  }

  protocol Layer {
      var size: Size { get }
      func describe() -> String
  }

  struct TextLayer: Layer {
      let text: String
      var size: Size { Size(width: text.count * 10, height: 20) }
      func describe() -> String { "Text" }
  }

  struct Padding: Layer {
      let content: any Layer
      let amount: Int
      var size: Size {
          Size(width: content.size.width + 2 * amount, height: content.size.height + 2 * amount)
      }
      func describe() -> String { "padding(\(amount)) > " + content.describe() }
  }

  struct Border: Layer {
      let content: any Layer
      var size: Size { content.size }
      func describe() -> String { "border \(size.width)×\(size.height) > " + content.describe() }
  }

  extension Layer {
      func padding(_ amount: Int) -> Padding { Padding(content: self, amount: amount) }
      func border() -> Border { Border(content: self) }
  }

  let a = TextLayer(text: "Hi").padding(4).border().padding(10)
  let b = TextLayer(text: "Hi").border().padding(14)
  print(a.describe())
  print(b.describe())
  print(a.size.width, b.size.width)
output: |
  padding(10) > border 28×28 > padding(4) > Text
  padding(14) > border 20×20 > Text
  48 48
hints:
  - "The last modifier is the outermost layer, so describe() starts with it."
  - "\"Hi\" is 20×20 in this model. The border's size is the size of what it wraps."
solution: |
  ```output
  padding(10) > border 28×28 > padding(4) > Text
  padding(14) > border 20×20 > Text
  48 48
  ```

  In `a`, the border wraps text plus 4 points of padding: 20 + 8 = 28. Ten more points on each side make the whole thing 48 wide. In `b`, the border hugs the 20-point text, and 14 points on each side also total 48. Same outer size, different drawing: `a` has a gap between text and outline, `b` doesn't.
````

````exercise
id: m34-l02-e2
type: comprehension
prompt: "Which chain draws a 100-point-wide gray outline around the word Title?"
choices:
  - text: "Text(\"Title\").frame(width: 100).border(.gray)"
    correct: true
    why: "The border wraps the 100-point frame, so it outlines the frame's full width."
  - text: "Text(\"Title\").border(.gray).frame(width: 100)"
    correct: false
    why: "The border wraps only the text; the frame is an invisible box around it."
  - text: "Both, because modifiers are applied in any order."
    correct: false
    why: "Each modifier wraps the result of the ones before it. Order is part of the description."
  - text: "Neither: border(_:width:) always outlines the whole screen."
    correct: false
    why: "A border outlines the view it wraps."
solution: |
  **`frame(width: 100)` then `border(.gray)`.** The border is applied to the 100-point frame, which is what Apple's "Configuring views" article shows. In the other order the outline hugs the text and the frame adds invisible space around it.
````

````exercise
id: m34-l02-e3
type: fill-in
prompt: "Complete the custom modifier and its extension so callers can write Text(\"Required\").errorText()."
code: |
  import SwiftUI

  struct ErrorText: [[1]] {
      func body(content: [[2]]) -> some View {
          content
              .font(.footnote)
              .foregroundStyle(.red)
      }
  }

  extension [[3]] {
      func errorText() -> some View {
          [[4]](ErrorText())
      }
  }
blanks:
  - id: "1"
    answers: ["ViewModifier"]
  - id: "2"
    answers: ["Content"]
  - id: "3"
    answers: ["View"]
  - id: "4"
    answers: ["modifier"]
hints:
  - "The protocol for reusable modifiers."
  - "body(content:) receives the view being modified as the protocol's associated type."
solution: |
  ```swift ios
  import SwiftUI

  struct ErrorText: ViewModifier {
      func body(content: Content) -> some View {
          content
              .font(.footnote)
              .foregroundStyle(.red)
      }
  }

  extension View {
      func errorText() -> some View {
          modifier(ErrorText())
      }
  }

  struct SignUpField: View {
      var body: some View {
          Text("Required")
              .errorText()
      }
  }
  ```

  `ViewModifier` requires `body(content:)`, where `content` has the associated type `Content`. Extending `View` puts `errorText()` on every view, and `modifier(_:)` applies the struct.
````

````exercise
id: m34-l02-e4
type: solve
prompt: |
  Write a SwiftUI view `ProfileHeader` that takes a `name: String` and a `subtitle: String`, and shows:

  - a circular SF Symbol `person.crop.circle.fill` at 56 × 56 points, resizable and scaled to fit,
  - the name in `.headline` and the subtitle in `.subheadline` with the `.secondary` style, stacked and leading-aligned, to the right of the image,
  - the whole row wrapped in a reusable `cardStyle()` modifier you write (padding, a rounded background, any corner radius).

  Use `foregroundStyle`, not `foregroundColor`, and put `resizable()` where it compiles.
starter: |
  import SwiftUI

  struct ProfileHeader: View {
      let name: String
      let subtitle: String

      var body: some View {
          // your code
          Text(name)
      }
  }
hints:
  - "An HStack holding the Image and a VStack(alignment: .leading)."
  - "Image(systemName:) then .resizable() then .scaledToFit() then .frame(width:height:)."
  - "The modifier is a ViewModifier struct plus an extension View { func cardStyle() -> some View }."
rubric:
  - resizable() is called directly on the Image, before frame.
  - The texts are in a leading-aligned VStack inside an HStack with the image.
  - The card style is a ViewModifier with a View extension method, applied once to the row.
  - Uses foregroundStyle(.secondary) for the subtitle.
solution: |
  ```swift ios
  import SwiftUI

  struct CardStyle: ViewModifier {
      func body(content: Content) -> some View {
          content
              .padding()
              .background(.background, in: RoundedRectangle(cornerRadius: 22))
              .shadow(radius: 4, y: 2)
      }
  }

  extension View {
      func cardStyle() -> some View {
          modifier(CardStyle())
      }
  }

  struct ProfileHeader: View {
      let name: String
      let subtitle: String

      var body: some View {
          HStack(spacing: 12) {
              Image(systemName: "person.crop.circle.fill")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 56, height: 56)
                  .accessibilityHidden(true)
              VStack(alignment: .leading, spacing: 2) {
                  Text(name)
                      .font(.headline)
                  Text(subtitle)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
              }
          }
          .cardStyle()
      }
  }
  ```

  `resizable()` comes right after `Image(systemName:)` because it's an `Image` method; `scaledToFit()` keeps the symbol's proportions inside the 56-point frame. The texts are leading-aligned in their own stack. `cardStyle()` wraps the whole `HStack`, so the padding and background surround the row. The image is decorative here (the name says who it is), so it's hidden from VoiceOver, which lesson 4 explains.
````

````exercise
id: m34-l02-e5
type: refactor
prompt: "This body works, but it's one long block. Refactor it into a parent and two or three subviews with explicit inputs. Say what each subview takes and why."
code: |
  struct OrderScreen: View {
      let order: Order

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading) {
                  Text("Order #\(order.number)")
                      .font(.title2.bold())
                  Text(order.status)
                      .foregroundStyle(order.isLate ? .red : .secondary)
              }
              ForEach(order.items) { item in
                  HStack {
                      Text("\(item.quantity)×")
                          .monospacedDigit()
                      Text(item.name)
                      Spacer()
                      Text(item.price, format: .currency(code: "USD"))
                  }
              }
              HStack {
                  Text("Total")
                      .font(.headline)
                  Spacer()
                  Text(order.total, format: .currency(code: "USD"))
                      .font(.headline)
              }
          }
          .padding()
      }
  }
rubric:
  - Extracts a header view taking number, status and isLate (or equivalent), not the whole Order.
  - Extracts a row view taking quantity, name and price.
  - Extracts or keeps a total row taking only the total.
  - The parent body reads as a short outline of the screen.
  - Explains that small inputs make each subview reusable and easy to preview.
solution: |
  ```swift illustrative
  struct OrderScreen: View {
      let order: Order

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              OrderHeader(number: order.number, status: order.status, isLate: order.isLate)
              ForEach(order.items) { item in
                  OrderItemRow(quantity: item.quantity, name: item.name, price: item.price)
              }
              TotalRow(total: order.total)
          }
          .padding()
      }
  }

  struct OrderHeader: View {
      let number: Int
      let status: String
      let isLate: Bool

      var body: some View {
          VStack(alignment: .leading) {
              Text("Order #\(number)")
                  .font(.title2.bold())
              Text(status)
                  .foregroundStyle(isLate ? .red : .secondary)
          }
      }
  }

  struct OrderItemRow: View {
      let quantity: Int
      let name: String
      let price: Double

      var body: some View {
          HStack {
              Text("\(quantity)×")
                  .monospacedDigit()
              Text(name)
              Spacer()
              Text(price, format: .currency(code: "USD"))
          }
      }
  }

  struct TotalRow: View {
      let total: Double

      var body: some View {
          HStack {
              Text("Total")
              Spacer()
              Text(total, format: .currency(code: "USD"))
          }
          .font(.headline)
      }
  }
  ```

  The parent is now an outline: header, rows, total. Each subview takes plain values rather than the `Order`, so you can preview `OrderItemRow(quantity: 2, name: "A very long product name", price: 9.99)` without building an order, and reuse it elsewhere. `TotalRow` also moved `.font(.headline)` to the stack, since both texts share it. (This block is illustrative because `Order` isn't defined here.)
````

````exercise
id: m34-l02-e6
type: explain
prompt: "Why is a modified view's type something like a nest of wrappers, and how does some View help? Answer in three or four sentences."
code: |
  var body: some View {
      Text("Hello")
          .padding()
          .background(.yellow)
  }
rubric:
  - Says each modifier returns a new view that wraps the previous one.
  - Says the concrete type therefore records every modifier, nested.
  - Says some View lets body return that concrete type without spelling it, and that it changes as the chain is edited.
  - Mentions that the compiler still knows the exact type (opaque, not type-erased).
solution: |
  Each modifier returns a new view that contains the previous one, so the result of `Text("Hello").padding().background(.yellow)` is a background wrapper around a padding wrapper around a `Text`, and its concrete type spells out that nesting. Writing that type by hand would be unreadable, and it would change every time you add or reorder a modifier. `some View` is an opaque return type: the compiler knows exactly which type `body` returns and checks it, but your code only promises "some type that conforms to `View`". Unlike `any View`, nothing is boxed or erased.
````

## Summary

- A modifier returns a new view wrapping the old one. A chain is a set of nested wrappers, and the last modifier is the outermost.
- Order changes the result: a background or border is as large as what it wraps; `frame` and `padding` add space around what's before them.
- Some modifiers set values that flow down to child views, like `font(_:)` and `foregroundStyle(_:)`, unless a child overrides them.
- Type-specific modifiers such as `Image.resizable()` must come before general ones, which return `some View`.
- Bundle repeated modifiers in a `ViewModifier` and expose it through a `View` extension method.
- Extract subviews with small, explicit inputs; they're cheap, reusable and easy to preview.
- `#Preview` shows a view in Xcode's canvas. Preview every state the view can be in.
