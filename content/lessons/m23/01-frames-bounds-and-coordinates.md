---
id: m23-l01
title: Frames, bounds and coordinate systems
description: Module 22 introduced frame, bounds and center. This lesson takes them apart. You convert points and rectangles across several levels of the hierarchy, see why a non-zero bounds origin is how scrolling works, learn what a transform does to each property and why Apple says the frame is undefined once a view is rotated or scaled, and find out when frames are actually valid in an Auto Layout screen.
module: m23
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l03, m22-l04]
objectives:
  - Convert a point or rectangle between any two views in the same window, by hand and with convert(_:to:) and convert(_:from:).
  - Explain how the bounds origin shifts a view's content and connect it to contentOffset in a scroll view.
  - Describe what transform does to frame, bounds and center, and use center and bounds when a view is transformed.
  - Read frames only after layout has run, in viewDidLayoutSubviews() or layoutSubviews().
terms:
  - term: Coordinate system
    definition: "The space a set of coordinates is measured in. Every view has its own, with the origin at the top-left of its bounds, x growing right and y growing down, in points."
  - term: Bounds origin
    definition: "The point of a view's own coordinate system that appears at its top-left corner. (0, 0) by default. Changing it shifts everything the view draws and every subview, without moving the view itself."
  - term: Coordinate conversion
    definition: "Translating a point or rectangle from one view's coordinate system to another's. UIKit does it with convert(_:to:) and convert(_:from:), walking up and down the hierarchy."
  - term: Transform
    definition: "A CGAffineTransform (scale, rotation, translation) applied to a view around its anchor point, which is its center by default. It changes how the view is drawn, not its bounds or center."
  - term: Window coordinates
    definition: "The coordinate system of the window that contains the view. Passing nil as the target view to convert(_:to:) converts to it."
mastery:
  - Compute by hand where a point inside a nested view lands in the window, including a scrolled parent.
  - Pick convert(_:to:) or convert(_:from:) and pass the right rectangle (bounds, not frame) for the source view.
  - Move and resize a rotated view without touching its frame.
  - Say in which callback the frames of an Auto Layout screen are final, and why viewDidLoad() is too early.
  - Decide which rows of a scrolled list are visible from their frames and the scroll position.
resources: [uikit-uiview-frame, uikit-uiview, auto-layout-guide]
cards:
  - id: m23-l01-c1
    front: How do you convert a point p from a view to its superview, without a transform?
    back: "pointInSuperview = frame.origin + (p − bounds.origin). Repeat level by level to reach an ancestor; invert it to go down. UIKit does this with convert(_:to:) and convert(_:from:)."
  - id: m23-l01-c2
    front: You want a button's rectangle in the root view's coordinates. What do you pass to convert(_:to:)?
    back: "button.convert(button.bounds, to: root). The receiver's own coordinates are its bounds. Converting button.frame from the button would mix in the superview's coordinate system."
  - id: m23-l01-c3
    front: What happens to frame, bounds and center when you set a rotation transform?
    back: "bounds and center don't change. Apple's docs say frame is then undefined and should be ignored. Move the view with center and resize it with bounds; set transform back to .identity to use frame again."
  - id: m23-l01-c4
    front: What does a non-zero bounds origin do?
    back: "It picks which point of the view's own coordinate space sits at its top-left corner. bounds.origin = (0, 50) shows everything 50 points higher. A scroll view scrolls by moving that origin; contentOffset is that point."
  - id: m23-l01-c5
    front: When are the frames of views laid out with Auto Layout valid?
    back: "After a layout pass: in viewDidLayoutSubviews() of the view controller or layoutSubviews() of the view. In viewDidLoad() the constraints exist but haven't been solved yet."
---

## The idea in one sentence

Every view measures in its own coordinate system, and every number you read from a view (frame, bounds, center, a touch location) only makes sense once you know **which** coordinate system it's in; converting between them is mechanical, and UIKit does it for you if you ask with the right rectangle.

> [!note] About this lesson's code
> The UIKit rules quoted here come from Apple's `UIView` and `UIScrollView` reference pages, read in November 2026. Blocks that import UIKit are type-checked against the iOS 17 SDK on the CI runner but not run; the comments with numbers in them are what the formulas in this lesson give, not observed output. The plain-Swift models use Foundation's `CGPoint` and `CGRect` and were compiled and run with Swift 6.3.

## What Module 22 gave you

From lesson 3 of Module 22: `frame` is the view's rectangle in its **superview's** coordinates, `bounds` is the same rectangle in the view's **own** coordinates (origin (0, 0) unless you change it), and `center` is the frame's midpoint in the superview's coordinates. You also saw the one-level conversion formula. This lesson uses that formula across several levels, adds the bounds origin and transforms, and connects it to scrolling.

`CGRect`, `CGPoint` and `CGSize` are plain structs from Core Graphics, and Foundation has them on Linux too, so the models below use the real types.

## Conversion, level by level

Going one level **up**, from a view to its superview:

```plaintext
pointInSuperview = frame.origin + (pointInView − bounds.origin)
```

Going one level **down**, from a superview into a subview, is the same formula solved for the other side:

```plaintext
pointInView = pointInSuperview − frame.origin + bounds.origin
```

To go between any two views, go up from the first to the window, then down to the second. This model stores what UIKit stores (frame, bounds origin, superview) and does exactly that. (The `#if canImport(CoreGraphics)` lines are there because on Apple platforms `CGRect`'s initializers and `CGPoint.zero` come from CoreGraphics, which `import UIKit` brings in for you in an app; on Linux, Foundation provides them. With both imports, the same file builds everywhere.)

```swift
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class Box {
    let name: String
    var frame: CGRect
    var boundsOrigin = CGPoint.zero
    var superview: Box?

    init(_ name: String, frame: CGRect, in superview: Box? = nil) {
        self.name = name
        self.frame = frame
        self.superview = superview
    }

    func toSuperview(_ p: CGPoint) -> CGPoint {
        CGPoint(x: frame.origin.x + p.x - boundsOrigin.x,
                y: frame.origin.y + p.y - boundsOrigin.y)
    }

    func fromSuperview(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - frame.origin.x + boundsOrigin.x,
                y: p.y - frame.origin.y + boundsOrigin.y)
    }

    // Up to the root, which plays the window.
    func toWindow(_ p: CGPoint) -> CGPoint {
        var point = p
        var box = self
        while let parent = box.superview {
            point = box.toSuperview(point)
            box = parent
        }
        return point
    }

    // Down from the root: collect the ancestors, then apply them top to bottom.
    func fromWindow(_ p: CGPoint) -> CGPoint {
        var chain: [Box] = []
        var box = self
        while let parent = box.superview {
            chain.insert(box, at: 0)
            box = parent
        }
        var point = p
        for step in chain {
            point = step.fromSuperview(point)
        }
        return point
    }

    func convert(_ p: CGPoint, to other: Box) -> CGPoint {
        other.fromWindow(toWindow(p))
    }
}

func show(_ p: CGPoint) -> String { "(\(p.x), \(p.y))" }

let window = Box("window", frame: CGRect(x: 0, y: 0, width: 390, height: 844))
let list = Box("list", frame: CGRect(x: 0, y: 100, width: 390, height: 600), in: window)
let row = Box("row", frame: CGRect(x: 0, y: 520, width: 390, height: 60), in: list)
let button = Box("button", frame: CGRect(x: 300, y: 10, width: 70, height: 40), in: row)
let banner = Box("banner", frame: CGRect(x: 20, y: 720, width: 350, height: 80), in: window)

print("button's corner in window:", show(button.toWindow(.zero)))
list.boundsOrigin = CGPoint(x: 0, y: 300)
print("after scrolling the list 300 points:", show(button.toWindow(.zero)))
print("same point in banner:", show(button.convert(.zero, to: banner)))
print("round trip:", show(window.convert(button.toWindow(.zero), to: button)))
```

```output
button's corner in window: (300.0, 630.0)
after scrolling the list 300 points: (300.0, 330.0)
same point in banner: (280.0, -390.0)
round trip: (0.0, 0.0)
```

Line by line:

- `toSuperview` is the formula; `toWindow` applies it until there's no parent. The button's top-left corner (0, 0) becomes (300, 10) in the row, (300, 530) in the list and (300, 630) in the window.
- Setting `list.boundsOrigin` to (0, 300) subtracts 300 at the list level only. Nothing about the row or the button changed, yet the button is now 300 points higher on screen. That's scrolling, and the next section is about it.
- `convert(_:to:)` goes up to the window and down into the banner. A negative y means "above the banner's top edge". Coordinates outside a view's bounds are perfectly valid; they just aren't inside it.
- Converting window coordinates back into the button gives (0, 0): the two directions are inverses.

UIKit's methods do the same walk, and Apple's documentation adds two rules: the point you pass is in the **receiver's** local coordinate system (its bounds), and "both `view` and the receiver must belong to the same `UIWindow` object". Passing `nil` converts to or from window coordinates.

```swift ios
import UIKit

let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
let list = UIScrollView(frame: CGRect(x: 0, y: 100, width: 390, height: 600))
let row = UIView(frame: CGRect(x: 0, y: 520, width: 390, height: 60))
let button = UIButton(frame: CGRect(x: 300, y: 10, width: 70, height: 40))

root.addSubview(list)
list.addSubview(row)
row.addSubview(button)
list.contentSize = CGSize(width: 390, height: 1600)
list.contentOffset = CGPoint(x: 0, y: 300)

// The button's own rectangle is its bounds.
let buttonInRoot = button.convert(button.bounds, to: root)     // (300, 330, 70, 40) by the formula
// A rectangle that's already in the list's coordinates (row.frame) converts from the list.
let rowInRoot = root.convert(row.frame, from: list)              // (0, 320, 390, 60)
// Where did a point in the root land inside the row?
let tapInRow = row.convert(CGPoint(x: 330, y: 340), from: root)  // (330, 20)
```

### frame or bounds?

The most common conversion bug passes the wrong rectangle. `button.frame` is in the **row's** coordinates. `button.convert(button.frame, to: root)` treats those numbers as if they were in the button's own coordinates, so the result is off by exactly the button's own position. Two correct ways to say the same thing:

```plaintext
button.convert(button.bounds, to: root)     // from the button's own coordinates
row.convert(button.frame, to: root)         // from the row's coordinates
```

## The bounds origin is how scrolling works

`bounds.origin` answers "which point of my own coordinate space appears at my top-left corner?" With (0, 0), a subview whose frame starts at y = 520 appears 520 points below the top. Set the origin to (0, 300) and the same subview appears at 220. The subviews' frames don't change; the window into them moves.

That's exactly what a scroll needs: the content stays still in its own coordinates and the visible window slides over it. Apple's `UIScrollView` overview describes a scroll view as "a view with an origin that's adjustable over the content view", and `contentOffset` as "the point at which the origin of the content view is offset from the origin of the scroll view". In UIKit that adjustable origin **is** the scroll view's bounds origin, so `contentOffset` and `bounds.origin` are the same point. (The reference doesn't say it in one sentence, and it wasn't checked against a running app for this lesson. The model above shows that the arithmetic is consistent with it.)

Two consequences you'll use in lesson 5:

- The rectangle a scroll view shows, in its content's coordinates, is `CGRect(origin: contentOffset, size: bounds.size)`. A subview is visible if its frame intersects that rectangle.
- A point in a scroll view's coordinates is already a **content** coordinate. `scrollView.convert(field.bounds, from: field)` gives you a rectangle you can hand to `scrollRectToVisible(_:animated:)`.

Changing `bounds.origin` on an ordinary view works too, but nothing in UIKit expects it. Use a scroll view when you mean scrolling.

## Transforms

`transform` is a `CGAffineTransform` (scale, rotation, translation) applied "relative to the center of its bounds", more precisely around the layer's anchor point, which is the center by default. It's the cheap way to animate a pop, a shake or a spin, and Apple's reference makes three points about it:

- It "does not affect Auto Layout. Auto layout calculates a view's alignment rectangle based on its untransformed frame." Rotating a view doesn't move its neighbors.
- `center` "is always valid, even when scaling or rotation factors are applied".
- "When the value of this property is anything other than the identity transform, the value in the `frame` property is undefined and should be ignored." The `frame` page adds: reposition with `center`, resize with `bounds`.

Why undefined? `frame` is one axis-aligned rectangle with an origin and a size. A rotated square isn't axis-aligned, so no such rectangle describes it. The closest thing, the box that encloses it, has a different size from the view itself. The math, with the real types:

```swift
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

func enclosingSize(width: Double, height: Double, degrees: Double) -> (Double, Double) {
    let angle = degrees * Double.pi / 180
    let c = abs(cos(angle))
    let s = abs(sin(angle))
    return (width * c + height * s, width * s + height * c)
}

func rounded(_ value: Double) -> String { String(format: "%.1f", value) }

let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
let center = CGPoint(x: 70, y: 90)
for degrees in [0.0, 30.0, 45.0, 90.0] {
    let (w, h) = enclosingSize(width: Double(bounds.width), height: Double(bounds.height), degrees: degrees)
    print("\(Int(degrees))°: bounds 100 × 100, center (\(center.x), \(center.y)), enclosing box \(rounded(w)) × \(rounded(h))")
}
```

```output
0°: bounds 100 × 100, center (70.0, 90.0), enclosing box 100.0 × 100.0
30°: bounds 100 × 100, center (70.0, 90.0), enclosing box 136.6 × 136.6
45°: bounds 100 × 100, center (70.0, 90.0), enclosing box 141.4 × 141.4
90°: bounds 100 × 100, center (70.0, 90.0), enclosing box 100.0 × 100.0
```

`bounds` and `center` describe the view at every angle. Any single rectangle you could call "the frame" either lies about the size or about the shape, which is why Apple tells you not to read it, and not to set it either.

```swift ios
import UIKit

let badge = UIView(frame: CGRect(x: 20, y: 40, width: 100, height: 100))
badge.transform = CGAffineTransform(rotationAngle: .pi / 4)

// Don't read or write badge.frame from here on. These stay meaningful:
let size = badge.bounds.size      // 100 × 100
badge.center.x += 30              // move it 30 points right
badge.bounds.size.width = 120     // resize it around its center

badge.transform = .identity       // frame is meaningful again
```

Use transforms for **visual effects**, temporary or animated. If a view should permanently be somewhere else or another size, change its constraints (or its center and bounds), not its transform.

## When frames are valid

In a screen built with Auto Layout you don't set frames; the layout engine computes them. That happens in a **layout pass**, after `viewDidLoad()`. Apple's archived Auto Layout Guide describes it as deferred: when constraints change, Auto Layout "schedules a layout pass for the near future", which updates constraints and then "calculates the frames for all the views". In `viewDidLoad()` your constraints exist but every frame you read is still whatever it was before (often zero).

Read geometry where UIKit has just finished laying out: `viewDidLayoutSubviews()` in a view controller, `layoutSubviews()` in a custom view. Both run every layout pass (Module 22, lesson 2), so keep them cheap and don't change constraints there.

```swift ios
import UIKit

final class ProfileViewController: UIViewController {
    private let avatar = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        avatar.backgroundColor = .systemTeal
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(avatar)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            avatar.widthAnchor.constraint(equalToConstant: 96),
            avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor),
        ])
        // avatar.bounds.width is still 0 here.
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avatar.layer.cornerRadius = avatar.bounds.width / 2   // 48 once laid out
    }
}
```

The corner radius uses `bounds`, not `frame`: it's a property of the view's own shape, and it stays right even if someone later adds a transform.

`layoutIfNeeded()` "lays out the subviews immediately, if layout updates are pending". Calling it before reading a frame forces the pass early. It works, but it's usually a sign the code belongs in a layout callback instead.

## Common mistakes

> [!error] Converting a view's frame from the view itself
> `button.convert(button.frame, to: root)` is off by the button's position in its parent. Convert `button.bounds` from the button, or `button.frame` from its superview.

> [!error] Reading or setting frame on a transformed view
> With a non-identity transform, Apple says `frame` is undefined. Use `center` to move and `bounds` to resize, or reset the transform first.

> [!error] Reading frames in viewDidLoad()
> Auto Layout hasn't run yet, so sizes are usually zero. Use `viewDidLayoutSubviews()` or `layoutSubviews()`.

> [!error] Comparing numbers from different coordinate systems
> A touch location from a gesture in the root view and a subview's `frame` are in different spaces. Convert one into the other's system before comparing, or ask the gesture for the location in the view you care about.

> [!error] Using a transform to lay a view out
> Auto Layout ignores transforms. A view moved with a translation transform still occupies its old place as far as its neighbors are concerned. Move it with constraints.

## Exercises

````exercise
id: m23-l01-e1
type: prediction
prompt: "This uses the one-level formula from the lesson. A card sits in a scroll view that's scrolled 200 points. What does it print?"
code: |
  import Foundation
  #if canImport(CoreGraphics)
  import CoreGraphics
  #endif

  func toSuperview(_ p: CGPoint, frame: CGRect, boundsOrigin: CGPoint) -> CGPoint {
      CGPoint(x: frame.origin.x + p.x - boundsOrigin.x,
              y: frame.origin.y + p.y - boundsOrigin.y)
  }

  let label = CGPoint(x: 12, y: 8)
  let cardFrame = CGRect(x: 16, y: 450, width: 358, height: 120)
  let scrollFrame = CGRect(x: 0, y: 90, width: 390, height: 700)

  let inScroll = toSuperview(label, frame: cardFrame, boundsOrigin: .zero)
  let inRoot = toSuperview(inScroll, frame: scrollFrame, boundsOrigin: CGPoint(x: 0, y: 200))
  print(inScroll.x, inScroll.y)
  print(inRoot.x, inRoot.y)
output: |
  28.0 458.0
  28.0 348.0
hints:
  - "The card has a zero bounds origin; the scroll view's is (0, 200)."
  - "Second step: 90 + 458 − 200."
solution: |
  ```output
  28.0 458.0
  28.0 348.0
  ```

  First level: the card is at (16, 450) in the scroll view and its bounds origin is zero, so (12, 8) becomes (28, 458). Second level: the scroll view is at y = 90 in the root and its bounds origin is (0, 200), so y = 90 + 458 − 200 = 348. The scroll offset only enters at the level of the scroll view itself, and it pulls everything inside 200 points up.
````

````exercise
id: m23-l01-e2
type: comprehension
prompt: "A sticker view is rotated 10° with `transform` for a playful look. A drag gesture should move it 40 points right. Which line is correct?"
choices:
  - text: "`sticker.center.x += 40`"
    correct: true
    why: center stays valid under a transform and moves the view without touching its rotation.
  - text: "`sticker.frame.origin.x += 40`"
    correct: false
    why: "With a non-identity transform, Apple says frame is undefined and shouldn't be modified."
  - text: "`sticker.bounds.origin.x += 40`"
    correct: false
    why: That shifts the sticker's content inside it (its subviews move left), not the sticker.
  - text: "`sticker.transform = CGAffineTransform(translationX: 40, y: 0)`"
    correct: false
    why: It replaces the rotation with a translation, so the sticker loses its tilt, and Auto Layout still places it where it was.
solution: |
  **`sticker.center.x += 40`.** `center` is in the superview's coordinates and is "always valid, even when scaling or rotation factors are applied". Changing `bounds.origin` scrolls the view's own content; changing `frame` on a transformed view is undefined; replacing the transform throws away the rotation. If you want to combine them, `transform.translatedBy(x:y:)` would keep the rotation, but for moving a view, `center` is the documented tool.
````

````exercise
id: m23-l01-e3
type: fill-in
prompt: "Complete the code. `avatar` is inside `header`, which is inside the view controller's `view`. Get the avatar's rectangle in `view`'s coordinates, two different ways, and convert a point from window coordinates into the header."
code: |
  let a = avatar.convert(avatar.[[1]], to: view)
  let b = header.convert(avatar.[[2]], to: view)
  let c = view.convert(avatar.frame, [[3]]: header)
  let pointInHeader = header.convert(windowPoint, from: [[4]])
blanks:
  - id: "1"
    answers: ["bounds"]
  - id: "2"
    answers: ["frame"]
  - id: "3"
    answers: ["from"]
  - id: "4"
    answers: ["nil"]
solution: |
  ```plaintext
  let a = avatar.convert(avatar.bounds, to: view)
  let b = header.convert(avatar.frame, to: view)
  let c = view.convert(avatar.frame, from: header)
  let pointInHeader = header.convert(windowPoint, from: nil)
  ```

  `a`, `b` and `c` are the same rectangle. The rule: the rectangle you pass must be in the coordinates of the view it comes **from**. `avatar.bounds` is in the avatar's coordinates; `avatar.frame` is in the header's. With `from:`, the receiver is the destination. `nil` means window coordinates, per Apple's documentation for both methods.
````

````exercise
id: m23-l01-e4
type: find-errors
prompt: "This controller wants a circular photo and a tooltip that appears just below a button that sits inside a card. Mark every real problem."
code: |
  final class PhotoViewController: UIViewController {
      private let photo = UIImageView()
      private let card = UIView()
      private let infoButton = UIButton(type: .infoLight)
      private let tooltip = UILabel()

      override func viewDidLoad() {
          super.viewDidLoad()
          // ... adds photo, card (with infoButton inside) and tooltip, with constraints ...
          photo.layer.cornerRadius = photo.frame.width / 2
          photo.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
      }

      func showTooltip() {
          let anchor = infoButton.convert(infoButton.frame, to: view)
          tooltip.frame.origin = CGPoint(x: anchor.minX, y: anchor.maxY + 8)
          photo.frame.size.width = 200
      }
  }
choices:
  - text: "The corner radius is computed in viewDidLoad(), before Auto Layout has given the photo a size, so it's 0."
    correct: true
  - text: "infoButton.frame is in the card's coordinates, but it's converted from the button's own coordinate system."
    correct: true
  - text: "photo.frame is set while the photo has a non-identity transform."
    correct: true
  - text: "convert(_:to:) can't convert to the view controller's root view."
    correct: false
    why: "Any view in the same window works. The root view is the usual target."
  - text: "A scale transform changes the photo's bounds to 110%."
    correct: false
    why: "The transform changes how the view is drawn. bounds keeps its size; that's why it's the safe property to read."
rubric:
  - I found the corner radius computed before layout.
  - I found the frame converted from the wrong view.
  - I found the frame written on a transformed view.
solution: |
  Three problems:

  1. **Too early.** In `viewDidLoad()` the constraints haven't been solved and `photo.frame.width` is typically 0. Compute the radius in `viewDidLayoutSubviews()`, from `photo.bounds.width`.
  2. **Wrong source coordinates.** `infoButton.frame` is in the card's coordinates. Use `infoButton.convert(infoButton.bounds, to: view)` or `card.convert(infoButton.frame, to: view)`.
  3. **Frame under a transform.** With the 1.1 scale applied, `frame` is undefined. Change `photo.bounds.size.width`, or better, the photo's width constraint, since it's laid out with Auto Layout. (Setting `tooltip.frame.origin` is fine only if the tooltip isn't constrained; mixing manual frames and constraints on the same view is lesson 2's topic.)
````

````exercise
id: m23-l01-e5
type: solve
prompt: |
  A simple vertical list puts its rows in a scroll view, one after another. Write `visibleRows(_:offsetY:height:)` that returns the indexes of the rows that are at least partly visible, given each row's frame (in the scroll view's content coordinates), the scroll view's `contentOffset.y` and its visible height. Use the idea from the lesson: the visible rectangle starts at the bounds origin.

  ```swift
  let rows = (0..<10).map { CGRect(x: 0, y: CGFloat($0) * 80, width: 390, height: 80) }
  print(visibleRows(rows, offsetY: 0, height: 300))
  print(visibleRows(rows, offsetY: 250, height: 300))
  print(visibleRows(rows, offsetY: 720, height: 300))
  ```

  should print `[0, 1, 2, 3]`, `[3, 4, 5, 6]` and `[9]`.
starter: |
  import Foundation
  #if canImport(CoreGraphics)
  import CoreGraphics
  #endif

  func visibleRows(_ rows: [CGRect], offsetY: CGFloat, height: CGFloat) -> [Int] {
      // your code
      return []
  }
hints:
  - "Build the visible rectangle: origin (0, offsetY), the width of a row, height `height`. Its minY and maxY are the top and bottom edges."
  - "A row overlaps the visible range if it ends below the top edge and starts above the bottom edge. Use strict comparisons so a row that only touches an edge doesn't count."
  - "Loop with indices so you can return them: for (index, row) in rows.enumerated()."
rubric:
  - Builds the visible rectangle from the offset (the bounds origin) and the visible size.
  - Counts rows that are partly visible, not only fully visible ones.
  - Doesn't count a row that ends exactly at the top edge or starts exactly at the bottom edge.
  - Returns indexes in order.
solution: |
  ```swift
  import Foundation
  #if canImport(CoreGraphics)
  import CoreGraphics
  #endif

  func visibleRows(_ rows: [CGRect], offsetY: CGFloat, height: CGFloat) -> [Int] {
      guard let first = rows.first else { return [] }
      let visible = CGRect(x: first.minX, y: offsetY, width: first.width, height: height)
      var result: [Int] = []
      for (index, row) in rows.enumerated() where row.maxY > visible.minY && row.minY < visible.maxY {
          result.append(index)
      }
      return result
  }

  let rows = (0..<10).map { CGRect(x: 0, y: CGFloat($0) * 80, width: 390, height: 80) }
  print(visibleRows(rows, offsetY: 0, height: 300))
  print(visibleRows(rows, offsetY: 250, height: 300))
  print(visibleRows(rows, offsetY: 720, height: 300))
  ```

  ```output
  [0, 1, 2, 3]
  [3, 4, 5, 6]
  [9]
  ```

  The visible rectangle is the scroll view's bounds expressed in content coordinates: origin = `contentOffset`, size = `bounds.size`. With offset 250 and height 300 it covers y from 250 to 550: row 3 (240–320) is partly in, row 6 (480–560) too. At offset 720, row 9 covers 720–800 and row 8 ends at 720 exactly: it touches the edge but shows no pixels, and the strict `>` leaves it out. The comparisons are written by hand on purpose. `CGRect.intersects(_:)` is tempting, but Foundation on Linux returned `true` for row 8 when this lesson was tested, and whether edge contact counts isn't something you want to depend on; the explicit test says exactly what "visible" means. Table and collection views (Module 24) do this kind of test to decide which cells to create.
````

````exercise
id: m23-l01-e6
type: explain
prompt: "A teammate sets `container.bounds.origin = CGPoint(x: 0, y: 40)` and is surprised that the container stays where it was while every subview moves up 40 points. Explain why, using the conversion formula, and say what property of a scroll view works this way."
code: |
  container.bounds.origin = CGPoint(x: 0, y: 40)
  // container.frame is unchanged.
  // Every subview now appears 40 points higher on screen.
rubric:
  - States that frame (the container's place in its superview) doesn't depend on the bounds origin.
  - Uses the formula pointInSuperview = frame.origin + (p − bounds.origin) to show the 40-point shift for every subview.
  - Notes the subviews' own frames don't change.
  - Connects it to contentOffset in a scroll view.
solution: |
  The container's `frame` places it in its superview, and changing `bounds.origin` doesn't touch that. What changes is the mapping from the container's coordinates to its superview's: `pointInSuperview = frame.origin + (p − bounds.origin)`. Every point inside the container, including each subview's frame origin, now has 40 subtracted from its y on the way out, so every subview is drawn 40 points higher, while their own `frame` values stay the same.

  In other words, the bounds origin chooses which part of its own coordinate space a view shows. That's what scrolling is: a scroll view's `contentOffset` is that origin, and dragging changes it while the content stays put in its own coordinates.
````

## Summary

- Going up one level: `frame.origin + (p − bounds.origin)`. Going down is the inverse. Between any two views: up to the window, then down.
- `convert(_:to:)` and `convert(_:from:)` take a point or rectangle in the **source** view's coordinates; pass `bounds` from the view itself or `frame` from its superview. `nil` means the window. Both views must be in the same window.
- The bounds origin shifts what a view shows, not where the view is. A scroll view scrolls by moving it; `contentOffset` is that point, and the visible rectangle is `(contentOffset, bounds.size)`.
- A transform is applied around the center, doesn't change `bounds` or `center`, and is ignored by Auto Layout. With a non-identity transform, `frame` is undefined: use `center` and `bounds`.
- Frames are valid after a layout pass. Read them in `viewDidLayoutSubviews()` or `layoutSubviews()`, not in `viewDidLoad()`.
