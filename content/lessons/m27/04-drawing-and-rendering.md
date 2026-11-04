---
id: m27-l04
title: Drawing with Core Graphics and the render loop
description: When no standard view draws what you need, you draw it yourself. You override draw(_:) with UIBezierPath and Core Graphics, render images off screen with UIGraphicsImageRenderer, tell setNeedsDisplay from setNeedsLayout and know what each triggers in the update cycle, follow a frame through Apple's render loop, and learn which layer effects Apple documents as costly to render and what to do about them.
module: m27
order: 4
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l03]
objectives:
  - Draw custom content in draw(_:) with UIBezierPath and CGContext, and know what UIKit sets up before calling it.
  - Choose between draw(_:), a CAShapeLayer and plain subviews for a custom visual.
  - Render an image with UIGraphicsImageRenderer instead of the deprecated UIGraphicsBeginImageContext.
  - Explain what setNeedsLayout(), layoutIfNeeded() and setNeedsDisplay() each do, and why calls are coalesced.
  - Describe the render loop's stages and the difference between a commit hitch and a render hitch.
  - Name the layer effects Apple documents as expensive (shadows without a path, group opacity, rasterization, complex shape paths) and their mitigations.
terms:
  - term: draw(_:)
    definition: "The UIView method you override to draw the view's content with UIKit and Core Graphics. UIKit calls it with a graphics context already set up; you never call it yourself."
  - term: Update cycle
    definition: "The pass, once per turn of the main run loop, in which UIKit lays out views that asked for layout and redraws views that asked for display, then commits the changes to the render server."
  - term: setNeedsDisplay()
    definition: "Marks a view's content as invalid. The view's draw(_:) runs once in the next drawing cycle, no matter how many times it was called."
  - term: setNeedsLayout()
    definition: "Marks a view's layout as invalid. layoutSubviews() runs in the next update cycle; layoutIfNeeded() forces it immediately."
  - term: UIGraphicsImageRenderer
    definition: "A UIKit object (iOS 10) that creates images from drawing code, managing the Core Graphics context, scale and color format for you."
  - term: Render loop
    definition: "The pipeline that produces each frame: the app handles events and commits UI changes, the render server prepares and renders the frame on the CPU and GPU, and the display shows it at the next vsync."
  - term: Hitch
    definition: "A frame that appears later than expected, interrupting motion. A commit hitch comes from the app's main thread missing the commit deadline; a render hitch from the render server not finishing in time."
mastery:
  - Write a view that draws a progress ring in draw(_:) and redraws when its progress or size changes.
  - Render initials into a circular avatar image with UIGraphicsImageRenderer.
  - Predict how many times layoutSubviews() and draw(_:) run after a series of invalidation calls and a resize.
  - Convert data values into drawing coordinates with a flipped y axis.
  - Explain a render hitch caused by a shadow without a path and fix it.
resources: [uikit-uiview, understanding-hangs, xcode-reduce-memory]
cards:
  - id: m27-l04-c1
    front: setNeedsDisplay() vs setNeedsLayout()?
    back: "setNeedsDisplay() asks for draw(_:) to run again in the next drawing cycle; use it when content or appearance changes. setNeedsLayout() asks for layoutSubviews() in the next update cycle; use it when subviews need repositioning. Both return immediately and are coalesced."
  - id: m27-l04-c2
    front: Does a view that overrides draw(_:) redraw when its bounds change?
    back: "Not by default. Apple: changing geometry typically doesn't redraw; the cached content is adjusted according to contentMode (default scaleToFill, which stretches it). Set contentMode = .redraw to redraw on bounds changes."
  - id: m27-l04-c3
    front: What replaces UIGraphicsBeginImageContext?
    back: "UIGraphicsImageRenderer. UIGraphicsBeginImageContext is deprecated in the iOS 27 SDK. The renderer manages scale and color format, and reusing one renderer reuses its Core Graphics contexts."
  - id: m27-l04-c4
    front: Commit hitch vs render hitch?
    back: "Commit hitch: the app's main thread doesn't finish the UI update before the commit deadline. Render hitch: the app commits in time but the render server can't render the frame before its presentation time, usually because the UI is too complex to render."
  - id: m27-l04-c5
    front: Layer effects Apple documents as costly to render?
    back: "A shadow without shadowPath (Core Animation must compute its shape), group opacity on layers with several components, complex CAShapeLayer paths, and content drawn on the CPU in draw(_:). Mitigations: shadowPath, simpler shapes, opaque layers, and measuring before rasterizing."
---

## The idea in one sentence

Drawing in UIKit is **pull-based**: you never draw when your data changes, you mark the view as needing display, and UIKit calls your `draw(_:)` once in its next update cycle, after layout, and then hands the result to a render server that has to finish each frame in a few milliseconds.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior and performance statements come from Apple's reference pages for `UIView`, `UIBezierPath`, `UIGraphicsImageRenderer`, `CALayer` and `UIGraphicsBeginImageContext`, the article "Understanding hitches in your app", and the archived *Core Animation Programming Guide*, read in November 2026. Apple publishes no per-effect timing numbers, and this lesson doesn't invent any. Instruments was not checked for this lesson. The update-cycle model and the coordinate math are plain Swift, compiled and run with Swift 6.3.

## When to draw

Most custom visuals don't need `draw(_:)`. In order of preference:

| Need | Use |
| --- | --- |
| Rectangles, text, images, standard controls | Subviews, laid out with constraints or in `layoutSubviews()` |
| A shape, a stroke, a gradient that may animate | `CAShapeLayer`, `CAGradientLayer` (lesson 2) |
| Many small shapes or text that change together: a chart, a graph, a signature | `draw(_:)` |
| An image built once and reused: an avatar, a thumbnail, a snapshot | `UIGraphicsImageRenderer` |

`draw(_:)` runs on the main thread, on the CPU, and its result is a bitmap the size of the view. Layers like `CAShapeLayer` hand the shape to the render server instead. Apple's `draw(_:)` page: "You don't need to override this method if your view sets its content in other ways", such as a background color or "setting its content directly using the underlying layer object."

## draw(_:)

A progress ring drawn by hand:

```swift ios
import UIKit

final class RingView: UIView {
    var progress: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    var ringColor: UIColor = .systemGreen {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func draw(_ rect: CGRect) {
        let lineWidth: CGFloat = 10
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2

        let track = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        track.lineWidth = lineWidth
        UIColor.systemGray5.setStroke()
        track.stroke()

        let start = -CGFloat.pi / 2
        let arc = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: start,
            endAngle: start + 2 * .pi * progress,
            clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        ringColor.setStroke()
        arc.stroke()
    }
}
```

What UIKit gives you, and what it expects:

- **A context, ready.** "UIKit creates and configures a graphics context for drawing and adjusts the transform of that context so that its origin matches the origin of your view's bounds rectangle." You draw in the view's own coordinates: origin top-left, y growing downward, in points. The scale to pixels is already applied.
- **The `rect` parameter** is "The portion of the view's bounds that needs to be updated". The first time it's usually the whole view. For simple views you can ignore it and draw everything; for expensive ones, skip what lies outside it.
- **`UIBezierPath`** holds geometry plus drawing attributes. `stroke()` and `fill()` use the current stroke and fill colors, set with `UIColor.setStroke()` and `setFill()`, and `stroke()` "automatically saves the current graphics state prior to drawing and restores that state when it is done."
- **Angles are radians**, 0 pointing right. In UIKit's flipped coordinates, `clockwise: true` from −π/2 starts at the top and goes right. Apple's own example: "specifying a start angle of 0 radians, an end angle of π radians, and setting the clockwise parameter to true draws the bottom half of the circle."
- **`isOpaque = false`** because the ring doesn't fill its bounds. Apple: if `isOpaque` is true, "your draw(_:) method must totally fill the specified rectangle with opaque content", otherwise the results are unpredictable. The default for `UIView` is `true`.
- **Don't call `super`** when subclassing `UIView` directly; do call it for other superclasses.
- **Never call `draw(_:)` yourself.** "To invalidate part of your view, and thus cause that portion to be redrawn, call the setNeedsDisplay() or setNeedsDisplay(_:) method instead."

> [!note] Automatic tracking in draw(_:)
> Apple's page adds that since iOS 18, UIKit tracks the traits you read in `draw(_:)` and redraws when they change, and that the method supports automatic observation tracking. With the course's iOS 17 target you still respond to trait changes yourself. Module 31 covers Observation.

### Core Graphics directly

`UIBezierPath` is a wrapper. For lots of lines, or for things it doesn't wrap, use the `CGContext` itself. `UIGraphicsGetCurrentContext()` returns it inside `draw(_:)`; Apple warns not to keep "a strong reference to the graphics context because it can change between calls":

```swift ios
import UIKit

final class GridView: UIView {
    var spacing: CGFloat = 20 {
        didSet { setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        UIColor.systemBackground.setFill()
        context.fill(rect)

        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(1 / traitCollection.displayScale)

        var x: CGFloat = 0
        while x <= bounds.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= bounds.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
            y += spacing
        }
        context.strokePath()
    }
}
```

- The view keeps the default `isOpaque = true`, so `draw(_:)` fills the rectangle first.
- All the lines go into **one path** and are stroked with one `strokePath()` call.
- `1 / traitCollection.displayScale` is one **pixel**, the thinnest line the screen can show. Apple's `lineWidth` page notes that the rendered width "may vary from the specified width by as much as 2 device pixels, depending on the position of the line with respect to the pixel grid".

### From data to coordinates

Charts are mostly coordinate math, and it's the part worth testing. A sparkline maps values to points inside the view, keeping an inset at the edges. UIKit's y axis grows **downward**, so the highest value gets the **smallest** y:

```swift
struct Point {
    var x: Double
    var y: Double
}

func sparklinePoints(_ values: [Double], width: Double, height: Double, inset: Double) -> [Point] {
    guard let low = values.min(), let high = values.max(), values.count > 1 else { return [] }
    let range = high == low ? 1 : high - low
    let step = (width - 2 * inset) / Double(values.count - 1)
    return values.enumerated().map { index, value in
        let x = inset + Double(index) * step
        let y = inset + (high - value) / range * (height - 2 * inset)
        return Point(x: x, y: y)
    }
}

for point in sparklinePoints([3, 7, 5, 10, 1], width: 120, height: 50, inset: 5) {
    print("(\(Int(point.x.rounded())), \(Int(point.y.rounded())))")
}
```

```output
(5, 36)
(33, 18)
(60, 27)
(88, 5)
(115, 45)
```

The maximum, 10, lands at y = 5 (the top inset) and the minimum, 1, at y = 45 (the bottom). `high - value` instead of `value - low` is what flips the axis. In `draw(_:)` you'd `move(to:)` the first point and `addLine(to:)` the rest. The `range` guard avoids dividing by zero when every value is equal.

## The update cycle

Calling `setNeedsDisplay()` doesn't draw anything. Apple: "This method makes a note of the request and returns immediately. The view is not actually redrawn until the next drawing cycle, at which point all invalidated views are updated." `setNeedsLayout()` works the same way for layout: it "returns immediately" and "waits for the next update cycle, you can use it to invalidate the layout of multiple views before any of those views are updated."

| Call | What it does | Runs |
| --- | --- | --- |
| `setNeedsLayout()` | Marks layout invalid | `layoutSubviews()` in the next update cycle |
| `layoutIfNeeded()` | Lays out now, only if something is pending | `layoutSubviews()` immediately |
| `setNeedsDisplay()` | Marks content invalid | `draw(_:)` in the next drawing cycle |
| Changing `bounds` | Marks layout invalid; content is **not** redrawn unless `contentMode == .redraw` | |

The last row surprises people. Apple: "If you simply change the geometry of the view, the view is typically not redrawn. Instead, its existing content is adjusted based on the value in the view's contentMode property." The default content mode is `.scaleToFill`, so a resized custom-drawn view shows its old drawing stretched. `.redraw` means "redisplay the view when the bounds change by invoking the setNeedsDisplay() method." That's why `RingView` sets it.

A plain-Swift model of these rules:

```swift
enum ContentMode { case scaleToFill, redraw }

final class ModelView {
    let name: String
    var contentMode = ContentMode.scaleToFill
    private(set) var width: Int
    private var needsLayout = true
    private var needsDisplay = true

    init(name: String, width: Int) {
        self.name = name
        self.width = width
    }

    func setNeedsLayout() { needsLayout = true }
    func setNeedsDisplay() { needsDisplay = true }

    func resize(to newWidth: Int) {
        guard newWidth != width else { return }
        width = newWidth
        needsLayout = true
        if contentMode == .redraw { needsDisplay = true }
    }

    // One pass of the update cycle: layout first, then drawing.
    func updateCycle() {
        if needsLayout {
            needsLayout = false
            print("\(name): layoutSubviews at width \(width)")
        }
        if needsDisplay {
            needsDisplay = false
            print("\(name): draw(_:) at width \(width)")
        }
    }
}

let chart = ModelView(name: "chart", width: 300)
chart.updateCycle()
chart.setNeedsDisplay()
chart.setNeedsDisplay()
chart.setNeedsDisplay()
chart.updateCycle()
chart.resize(to: 400)
chart.updateCycle()

let gauge = ModelView(name: "gauge", width: 300)
gauge.contentMode = .redraw
gauge.updateCycle()
gauge.resize(to: 400)
gauge.updateCycle()
gauge.updateCycle()
```

```output
chart: layoutSubviews at width 300
chart: draw(_:) at width 300
chart: draw(_:) at width 300
chart: layoutSubviews at width 400
gauge: layoutSubviews at width 300
gauge: draw(_:) at width 300
gauge: layoutSubviews at width 400
gauge: draw(_:) at width 400
```

- **Coalescing.** Three `setNeedsDisplay()` calls produce one `draw(_:)`. Setting five properties that each call `setNeedsDisplay()` in their `didSet` costs one redraw, not five.
- **Resizing `chart`** lays it out again but doesn't redraw it: its content is scaled. **Resizing `gauge`** (content mode `.redraw`) does both.
- **Nothing pending, nothing runs**: the last `gauge.updateCycle()` prints nothing. Same for `layoutIfNeeded()`: "If no layout updates are pending, this method exits without modifying the layout".
- **Layout before display.** By the time `draw(_:)` runs, the bounds are final.

### layoutSubviews()

`layoutSubviews()` is where a view positions its subviews by hand when constraints don't fit. Apple: "You should override this method only if the autoresizing and constraint-based behaviors of the subviews don't offer the behavior you want." A row of tags that wraps to the next line:

```swift ios
import UIKit

final class TagListView: UIView {
    var tags: [String] = [] {
        didSet {
            subviews.forEach { $0.removeFromSuperview() }
            for tag in tags {
                let label = UILabel()
                label.text = tag
                label.font = .preferredFont(forTextStyle: .footnote)
                label.backgroundColor = .secondarySystemFill
                addSubview(label)
            }
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let spacing: CGFloat = 8

    override func layoutSubviews() {
        super.layoutSubviews()
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        for label in subviews {
            let size = label.sizeThatFits(bounds.size)
            if origin.x > 0 && origin.x + size.width > bounds.width {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            label.frame = CGRect(origin: origin, size: size)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
```

Changing `tags` calls `setNeedsLayout()` instead of laying out right away, so setting `tags` twice in a row lays out once. `layoutSubviews()` also runs whenever the bounds change, so the wrapping follows the width. Apple: "Don't call this method directly." (A real implementation would also report an intrinsic size; Module 23 covered that.)

## Rendering images: UIGraphicsImageRenderer

Sometimes you want a drawing as a `UIImage`: an avatar with initials, a thumbnail, a watermark. `UIGraphicsBeginImageContext(_:)` is **deprecated in the iOS 27 SDK**, with the message "Replace usage of UIGraphicsBeginImageContext with UIGraphicsImageRenderer." Use the renderer:

```swift ios
import UIKit

@MainActor
final class AvatarRenderer {
    private let renderer: UIGraphicsImageRenderer

    init(diameter: CGFloat) {
        let format = UIGraphicsImageRendererFormat.preferred()
        renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter), format: format)
    }

    func image(initials: String, color: UIColor) -> UIImage {
        renderer.image { context in
            let bounds = context.format.bounds
            color.setFill()
            UIBezierPath(ovalIn: bounds).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: bounds.height * 0.4, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let text = initials as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }
}

let avatars = AvatarRenderer(diameter: 40)
let ana = avatars.image(initials: "AT", color: .systemPurple)
let ben = avatars.image(initials: "BK", color: .systemOrange)
```

- **The size is in points.** The format's `scale` ("The display scale determines the number of pixels per point") multiplies it into pixels, so a 40-point avatar on a 3× screen is 120 × 120 pixels.
- **`preferred()`** "Returns the most suitable format for the main screen's current configuration." The renderer's default, `default()`, represents "the highest fidelity that the current device supports", which may use a wider color format than you need. Inside a view, `UIGraphicsImageRendererFormat(for: traitCollection)` matches the view's own traits.
- **Reuse the renderer.** "An image renderer keeps a cache of Core Graphics contexts, so reusing the same renderer can be more efficient than creating new renderers." `AvatarRenderer` creates one and draws every avatar with it.
- **`image(actions:)`** makes the renderer's context current inside the closure, so `UIBezierPath.fill()` and `NSString.draw(at:withAttributes:)` draw into the image. `context.cgContext` gives you the `CGContext` for anything else. `pngData(actions:)` and `jpegData(withCompressionQuality:actions:)` return encoded data instead.

Image renderers aren't tied to the main thread (the class isn't main-actor isolated), which matters for lesson 5, where images are prepared off the main thread.

## The render loop

What happens after your code returns? Apple's article "Understanding hitches in your app" describes the pipeline that produces each frame:

```plaintext
 vsync          vsync            vsync            vsync
   │  app (main  │ render server  │  display       │
   │  thread):   │ CPU: prepare   │  shows the     │
   │  events,    │ GPU: render    │  frame         │
   │  layout,    │ into a buffer  │                │
   │  draw,      │                │                │
   │  commit ───▶│                │                │
```

1. **The app's main thread** handles events, runs layout and `draw(_:)`, and sends the new state of the layer tree to the render server: "the Core Animation commit". It must finish by the **commit deadline**.
2. **The render server**, a separate process, prepares the frame on the CPU and renders it on the GPU.
3. **The display** shows it at the frame's presentation time.

Each stage gets about one refresh interval. Apple's numbers: at 120 Hz the display "updates 120 times per second, or every 8.3 ms"; at 60 Hz, 16.7 ms. While one frame is on screen, the render server works on the next and the app on the one after.

A **hitch** is a frame that arrives late. Apple names two kinds:

- **Commit hitch**: the main thread doesn't finish before the commit deadline. Causes are anything slow on the main thread during scrolling or an animation: decoding a big image, synchronous file or network work, layout of a huge hierarchy, an expensive `draw(_:)`. The same work during a tap or other discrete interaction shows up as a **hang**, which Module 43 profiles; Apple: "If you fix all hangs in the area of the app you're investigating, you're likely to eliminate many hitches as well."
- **Render hitch**: the app commits in time, but the render server can't render the frame before its presentation time. Apple: "a render hitch is usually due to the app, such as when the scheduled UI update is too complex to render in time."

Apple's Hitches metric in Xcode Organizer grades hitch rate in milliseconds of delay per second: at or below 10 ms/s "is good", up to 25 a warning, up to 50 critical, and above 50 "warrants immediate attention". This lesson didn't check how the Organizer or the Hitches instrument display it.

### What makes rendering expensive

Apple's reference pages and the archived guide document a handful of layer features as costly for the render server, or as optimizations:

| Feature | What Apple documents | Mitigation |
| --- | --- | --- |
| Shadow without `shadowPath` | The shadow is built from the layer's "composited alpha channel". The archived guide: "Letting Core Animation determine the shape of a shadow can be expensive." | Set `shadowPath`. "Specifying an explicit path usually improves rendering performance." |
| Group opacity | With `allowsGroupOpacity` (on by default) and `opacity` below 1, the layer composites "as a group separate from its parent", which "may reduce performance". | Fade single layers when you can, rather than a container with many sublayers. |
| `mask`, `masksToBounds` | `masksToBounds` creates "an implicit clipping mask that matches the bounds of the layer and includes any corner radius effects." Apple doesn't quantify its cost. | Clip only where content actually overflows; measure. |
| Complex `CAShapeLayer` paths | Rendering a complex path "might get too expensive", especially if the layer is resized often. "drawing operations happen on the CPU whereas compositing takes place on the GPU." | Break the shape into simpler shape layers; measure. |
| Non-opaque content | An opaque layer lets Core Animation omit the alpha channel; the guide: the compositor then "does not need to blend the contents of your layer with its background content". | Set `isOpaque` on views that fill their bounds with opaque drawing. |
| `shouldRasterize` | The layer "is rendered as a bitmap in its local coordinate space and then composited". | A cache: only worth it for complex content that doesn't change between frames. Measure before and after. |

The talks and community articles that call several of these "offscreen rendering" describe the render server drawing a layer into a separate buffer before compositing it. Apple's current reference pages don't use that term or publish costs per effect, so the rule is the one the archived guide repeats: "you should always measure the current performance of your code before attempting to optimize." The Simulator and Instruments have had debug options that color layers using some of these features; this lesson didn't check their current names.

## Common mistakes

> [!error] Calling draw(_:) directly
> It draws into no context, or the wrong one. Call `setNeedsDisplay()` and let UIKit call `draw(_:)`.

> [!error] A custom-drawn view that stretches when resized
> The default content mode, `.scaleToFill`, scales the old bitmap. Set `contentMode = .redraw`, or call `setNeedsDisplay()` from `layoutSubviews()`.

> [!error] isOpaque left true for a view that doesn't fill its bounds
> `UIView` defaults to `isOpaque = true`. If `draw(_:)` leaves transparent pixels, Apple says the results are unpredictable. Set it to `false` (and use a clear background).

> [!error] Using UIGraphicsBeginImageContext
> Deprecated in the iOS 27 SDK. Use `UIGraphicsImageRenderer`, which also sets the right scale; the old function's simple form used a scale of 1.0, giving blurry images on Retina screens.

> [!error] Forcing layout in a loop
> Calling `layoutIfNeeded()` after every change in a loop runs layout every time. Call `setNeedsLayout()` and let the update cycle coalesce the work.

> [!error] A shadow on every cell with no shadowPath
> In a scrolling list, the render server computes each shadow's shape every frame. Set `shadowPath` in `layoutSubviews()`.

> [!error] shouldRasterize as a general speed-up
> Rasterizing content that changes means re-rendering the cache. Use it only for complex, static content, and measure.

## Exercises

````exercise
id: m27-l04-e1
type: prediction
prompt: "Using the lesson's ModelView (repeated so it compiles on its own), what does this print?"
code: |
  enum ContentMode { case scaleToFill, redraw }

  final class ModelView {
      let name: String
      var contentMode = ContentMode.scaleToFill
      private(set) var width: Int
      private var needsLayout = true
      private var needsDisplay = true

      init(name: String, width: Int) {
          self.name = name
          self.width = width
      }

      func setNeedsLayout() { needsLayout = true }
      func setNeedsDisplay() { needsDisplay = true }

      func resize(to newWidth: Int) {
          guard newWidth != width else { return }
          width = newWidth
          needsLayout = true
          if contentMode == .redraw { needsDisplay = true }
      }

      func updateCycle() {
          if needsLayout {
              needsLayout = false
              print("\(name): layoutSubviews at width \(width)")
          }
          if needsDisplay {
              needsDisplay = false
              print("\(name): draw(_:) at width \(width)")
          }
      }
  }

  let badge = ModelView(name: "badge", width: 50)
  badge.contentMode = .redraw
  badge.resize(to: 60)
  badge.resize(to: 60)
  badge.setNeedsLayout()
  badge.updateCycle()
  badge.resize(to: 80)
  badge.contentMode = .scaleToFill
  badge.resize(to: 90)
  badge.updateCycle()
  badge.updateCycle()
output: |
  badge: layoutSubviews at width 60
  badge: draw(_:) at width 60
  badge: layoutSubviews at width 90
  badge: draw(_:) at width 90
hints:
  - "Nothing runs until updateCycle(); the flags just accumulate."
  - "The resize to 80 happened while the content mode was .redraw."
solution: |
  ```output
  badge: layoutSubviews at width 60
  badge: draw(_:) at width 60
  badge: layoutSubviews at width 90
  badge: draw(_:) at width 90
  ```

  The first cycle runs pending layout and display once each, at the final width, 60: the initial draw, the resize and the explicit `setNeedsLayout()` are coalesced, and the second `resize(to: 60)` does nothing. Then the resize to 80 marks display as needed because the mode was still `.redraw`; switching to `.scaleToFill` doesn't clear that flag. The resize to 90 adds layout. The next cycle draws once at 90. The last cycle has nothing pending and prints nothing.
````

````exercise
id: m27-l04-e2
type: solve
prompt: |
  Write `barRects(values:width:height:spacing:)` for a bar chart drawn in `draw(_:)`. Bars share the width equally with `spacing` points between them (none before the first or after the last), and grow **up** from the bottom edge. The tallest value fills the full height; a value of 0 has height 0. Return one `Rect` per value with whole-number coordinates (round each of x, y, width and height).

  ```swift
  for rect in barRects(values: [2, 8, 4, 0], width: 110, height: 80, spacing: 10) {
      print(rect.x, rect.y, rect.width, rect.height)
  }
  ```

  should print:

  ```plaintext
  0 60 20 20
  30 0 20 80
  60 40 20 40
  90 80 20 0
  ```
starter: |
  struct Rect {
      var x: Int
      var y: Int
      var width: Int
      var height: Int
  }

  func barRects(values: [Double], width: Double, height: Double, spacing: Double) -> [Rect] {
      // your code
      []
  }
hints:
  - "Bar width = (width − spacing × (count − 1)) ÷ count."
  - "In UIKit, y grows downward: the bar's top is height − barHeight."
  - "Guard against an empty array and a maximum of 0."
rubric:
  - Bar widths and spacing fill the available width exactly.
  - Bars grow from the bottom (y = height − barHeight).
  - The tallest value fills the height; zero gives a zero-height bar at the bottom.
  - Handles an empty list and all-zero values without dividing by zero.
solution: |
  ```swift
  struct Rect {
      var x: Int
      var y: Int
      var width: Int
      var height: Int
  }

  func barRects(values: [Double], width: Double, height: Double, spacing: Double) -> [Rect] {
      guard !values.isEmpty else { return [] }
      let maximum = values.max() ?? 0
      let count = Double(values.count)
      let barWidth = (width - spacing * (count - 1)) / count
      return values.enumerated().map { index, value in
          let barHeight = maximum > 0 ? value / maximum * height : 0
          let x = Double(index) * (barWidth + spacing)
          return Rect(
              x: Int(x.rounded()),
              y: Int((height - barHeight).rounded()),
              width: Int(barWidth.rounded()),
              height: Int(barHeight.rounded())
          )
      }
  }

  for rect in barRects(values: [2, 8, 4, 0], width: 110, height: 80, spacing: 10) {
      print(rect.x, rect.y, rect.width, rect.height)
  }
  ```

  ```output
  0 60 20 20
  30 0 20 80
  60 40 20 40
  90 80 20 0
  ```

  Four bars and three gaps: (110 − 30) ÷ 4 = 20 points each. The bar for 8 is the tallest and fills the height; its top is at y = 0. The bar for 2 is a quarter of that, 20 points, so its top is at 80 − 20 = 60. In `draw(_:)` you'd turn each one into `UIBezierPath(rect:)` and fill it. Rounding matters on screen too: a bar edge at a fractional point position is antialiased across two pixels and looks blurry.
````

````exercise
id: m27-l04-e3
type: find-errors
prompt: "A signature view draws the user's strokes. Reviewers report it's blurry after rotation, black around the edges, and slow while drawing. Mark every real problem."
code: |
  final class SignatureView: UIView {
      private var points: [CGPoint] = []

      func add(_ point: CGPoint) {
          points.append(point)
          draw(bounds)
          layoutIfNeeded()
      }

      override func draw(_ rect: CGRect) {
          let path = UIBezierPath()
          guard let first = points.first else { return }
          path.move(to: first)
          for point in points.dropFirst() {
              path.addLine(to: point)
          }
          UIColor.label.setStroke()
          path.stroke()
      }
  }
choices:
  - text: "add(_:) calls draw(_:) directly instead of setNeedsDisplay()."
    correct: true
  - text: "isOpaque is left at its default true, but draw(_:) doesn't fill the background."
    correct: true
  - text: "contentMode is left at .scaleToFill, so after rotation the old drawing is stretched."
    correct: true
  - text: "layoutIfNeeded() on every point forces a layout pass the view doesn't need."
    correct: true
  - text: "UIBezierPath can't draw lines; it only draws rectangles and ovals."
    correct: false
    why: "move(to:) and addLine(to:) build arbitrary polylines."
  - text: "draw(_:) must call super.draw(rect) first."
    correct: false
    why: "Apple: when subclassing UIView directly, your implementation doesn't need to call super."
rubric:
  - I found the direct draw(_:) call.
  - I found the opaque default without a fill.
  - I found the content mode.
  - I found the unnecessary forced layout.
solution: |
  Four problems:

  1. **`draw(bounds)` called directly.** There's no prepared context at that point, so nothing reaches the screen. Call `setNeedsDisplay()`; multiple points added in one turn of the run loop then cost one redraw.
  2. **Opaque but not filled.** `UIView.isOpaque` is `true` by default, and this `draw(_:)` leaves the background unpainted: Apple says the results are unpredictable (here, black). Either set `isOpaque = false` with a clear background, or fill `rect` with a background color first.
  3. **`.scaleToFill`.** After rotation the bounds change and the cached bitmap is stretched. `contentMode = .redraw` redraws it.
  4. **`layoutIfNeeded()`** for every point forces a layout pass. Nothing about the layout changed.

  ```swift ios
  import UIKit

  final class SignatureView: UIView {
      private var points: [CGPoint] = []

      override init(frame: CGRect) {
          super.init(frame: frame)
          isOpaque = false
          backgroundColor = .clear
          contentMode = .redraw
      }

      required init?(coder: NSCoder) {
          fatalError("Built in code")
      }

      func add(_ point: CGPoint) {
          points.append(point)
          setNeedsDisplay()
      }

      override func draw(_ rect: CGRect) {
          guard let first = points.first else { return }
          let path = UIBezierPath()
          path.move(to: first)
          for point in points.dropFirst() {
              path.addLine(to: point)
          }
          path.lineWidth = 2
          path.lineJoinStyle = .round
          UIColor.label.setStroke()
          path.stroke()
      }
  }
  ```

  For long signatures, redrawing every point on each change gets slower as the path grows. A next step is to redraw only the rectangle around the newest segment with `setNeedsDisplay(_:)`, and skip work outside `rect` in `draw(_:)`.
````

````exercise
id: m27-l04-e4
type: comprehension
prompt: "A feed scrolls smoothly on a new iPhone but hitches on older ones. Instruments (per your teammate) shows the main thread finishing each frame's work in time. Which explanation and first fix fit Apple's description of the render loop?"
choices:
  - text: "Render hitches: the commit is on time but the render server can't render the frames in time. Look at what each cell asks it to render, starting with shadows without a shadowPath."
    correct: true
    why: "Apple: a render hitch happens when the app's work finishes on time but the render server's doesn't, usually because the UI is too complex to render."
  - text: "Commit hitches: move draw(_:) to a background thread with DispatchQueue."
    correct: false
    why: "The main thread is on time, so it isn't a commit hitch. And UIKit's draw(_:) runs on the main thread; you can't call it from another one."
  - text: "Hangs: the main thread is blocked for more than 100 ms."
    correct: false
    why: "Hangs are long main-thread stalls in discrete interactions; the main thread here is on time."
  - text: "The display refresh rate is too high; cap the app at 30 frames per second."
    correct: false
    why: "That hides the symptom and makes motion worse everywhere; it doesn't reduce the render server's work per frame."
solution: |
  **Render hitches.** Apple separates the two cases: when the app process misses the commit deadline, it's a commit hitch; "When the work in the app process finishes on time, but the work on the render server doesn't, it's called a render hitch", and it's "usually due to the app, such as when the scheduled UI update is too complex to render in time." Older devices have less GPU and CPU headroom for the same layer tree. Start with the documented costs: give shadows a `shadowPath`, avoid group opacity on complex cells, simplify masks and shape layers, and measure each change.
````

````exercise
id: m27-l04-e5
type: design
prompt: "You're building a stock chart that shows 500 prices as a line, a gradient fill under the line, and a crosshair that follows the user's finger. It must scroll horizontally at full frame rate. Decide what to draw with draw(_:), what to use layers for, and what to precompute. Explain each choice."
rubric:
  - Precomputes point coordinates from the data once per data or size change, not per frame.
  - Draws the line and fill once (draw(_:) or a CAShapeLayer path), not while the crosshair moves.
  - Puts the crosshair in its own lightweight layer or view so moving it doesn't redraw the chart.
  - Uses a gradient layer masked by the fill shape, or draws the gradient once, and notes the mask's cost is something to measure.
  - Mentions disabling implicit animations for the crosshair layer and measuring with Instruments.
solution: |
  A layered design:

  - **Precompute** the 500 points (the sparkline math from this lesson) when the data or the chart's size changes, in `layoutSubviews()` or when the data is set. Not in `draw(_:)` on every redraw, and never per frame.
  - **The line**: a `CAShapeLayer` with the polyline as its path. The render server draws it, it stays sharp at any scale, and changing data could animate the path. (A `draw(_:)` view also works, as long as it redraws only when the data changes.)
  - **The fill**: a `CAGradientLayer` masked by a second shape layer whose path is the line closed down to the bottom edge. A mask has a rendering cost Apple doesn't quantify, so measure it; if it hitches on older devices, render the gradient fill into an image once with `UIGraphicsImageRenderer` and display that.
  - **The crosshair**: its own thin layer (or a small view) on top. Moving it changes one `position`, wrapped in a `CATransaction` with `setDisableActions(true)` so it tracks the finger without implicit animation. The chart below isn't redrawn.
  - **Scrolling**: put the chart in a scroll view; moving content doesn't redraw it. Measure with Instruments and watch for render hitches.
````

## Summary

- Prefer subviews and shape or gradient layers; override `draw(_:)` for many shapes that change together. UIKit prepares the context; you draw in points with y growing downward, set `isOpaque = false` if you don't fill the bounds, and never call `draw(_:)` yourself.
- `setNeedsDisplay()` and `setNeedsLayout()` mark work for the next update cycle and are coalesced; `layoutIfNeeded()` lays out immediately. Geometry changes don't redraw unless `contentMode` is `.redraw`.
- `UIGraphicsImageRenderer` replaces the deprecated `UIGraphicsBeginImageContext`. Sizes are in points, the format sets the scale, and reusing a renderer reuses its contexts.
- Each frame goes from the main thread (layout, drawing, commit) to the render server (CPU, then GPU) to the display, with a deadline per stage: 8.3 ms per stage at 120 Hz. A late commit is a commit hitch; a late render is a render hitch.
- Apple documents shadows without a path, group opacity, complex shape paths and non-opaque content as costly for rendering, and rasterization as a cache for static content. Fix what's documented, then measure.
