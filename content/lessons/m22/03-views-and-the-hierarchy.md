---
id: m22-l03
title: Views and the view hierarchy
description: Every pixel your app shows belongs to a UIView, and views form a tree. You learn superview and subviews, what addSubview really does, how z-order follows the subviews array, the exact difference between frame, bounds and center, how to convert points between coordinate systems, and take a first look at positioning views with Auto Layout anchors.
module: m22
order: 3
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l02]
objectives:
  - Describe the view hierarchy as a tree with superview and subviews, and say who owns whom.
  - Predict the effect of addSubview, insertSubview(_:at:), bringSubviewToFront(_:) and removeFromSuperview() on the tree and the drawing order.
  - Tell frame, bounds and center apart, and compute one from the others.
  - Convert a point from a view's coordinate system to its superview's.
  - Pin a view with layout anchors, including translatesAutoresizingMaskIntoConstraints and the safe area.
terms:
  - term: View hierarchy
    definition: "The tree of views on screen. Each view has at most one superview and any number of subviews; the window is at the root."
  - term: Frame
    definition: "A view's rectangle in its superview's coordinate system: where it is and how big it is, as seen by the parent. Undefined when the view has a non-identity transform."
  - term: Bounds
    definition: "A view's rectangle in its own coordinate system. The origin is (0, 0) by default; the size matches the frame's size. Changing the origin shifts what the view shows inside it."
  - term: Center
    definition: "The center of the view's frame, in the superview's coordinate system. Stays valid under a transform."
  - term: Layout anchor
    definition: "An object such as topAnchor or leadingAnchor that creates Auto Layout constraints between views, for example label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)."
mastery:
  - Draw the tree a short sequence of addSubview and removeFromSuperview calls produces.
  - Say which view draws on top of which from the order of the subviews array.
  - Given a frame, write the bounds and center, and recompute the frame after changing the bounds size.
  - Write a function that converts a point from a nested view to the window's coordinates.
  - Write four anchor constraints that pin a label under the safe area's top edge.
resources: [apple-documentation, hig]
cards:
  - id: m22-l03-c1
    front: Frame vs bounds?
    back: "Frame: the view's rectangle in its superview's coordinates (position + size as the parent sees it). Bounds: the rectangle in the view's own coordinates, origin (0, 0) by default, same size. Center: the frame's midpoint, in the superview's coordinates."
  - id: m22-l03-c2
    front: What does addSubview(_:) do besides adding the view to the array?
    back: "Keeps a strong reference to the subview, makes the receiver its next responder, and if the view had another superview, removes it from there first. A view has at most one superview."
  - id: m22-l03-c3
    front: Which subview draws on top?
    back: "The last one in subviews. Index 0 is the back-most view. bringSubviewToFront(_:) moves a view to the end; sendSubviewToBack(_:) to the beginning."
  - id: m22-l03-c4
    front: Why set translatesAutoresizingMaskIntoConstraints = false on views you create in code?
    back: "It defaults to true for views created in code, which makes UIKit generate constraints from the frame. Your own constraints would then conflict with them. Interface Builder sets it to false for you."
  - id: m22-l03-c5
    front: What happens if you activate a constraint between two views with no common ancestor?
    back: "An exception is thrown (Apple's isActive documentation). Add both views to the hierarchy before activating constraints between them."
---

## The idea in one sentence

A screen is a tree of `UIView`s: each view draws a rectangle, positions its children inside its own coordinate system, and is positioned by its parent in the parent's, which is the whole difference between `bounds` and `frame`.

> [!note] About this lesson's code
> Blocks that import UIKit are type-checked against the iOS SDK (iOS 17 target) but not run. The rules come from Apple's `UIView` reference pages, read in November 2026. The plain-Swift models of the tree and of frame and bounds were compiled and run, and they reproduce what those pages describe.

## UIView

`UIView` is "the root class for all views". Labels, buttons, image views, stack views, table views and the window itself are subclasses. A view:

- draws content in a rectangular area (a background color, text, an image),
- lays out and contains other views,
- responds to touches (lesson 5),
- can be animated.

Every view property you'll set in this module (`backgroundColor`, `isHidden`, `alpha`, `frame`) belongs to `UIView`, and `UIView` is `@MainActor`: you create and change views on the main thread only.

## The tree: superview and subviews

Views contain views. Apple calls the containing view the **superview** and the contained one a **subview**. A view controller's root view is at the top of its screen's tree, and the window is above that.

```plaintext
UIWindow
└── root view (owned by the view controller)
    ├── headerView
    │   └── titleLabel
    └── cardView
        ├── iconView
        └── subtitleLabel
```

The relationships, from the reference pages:

- `superview` is "the receiver's superview, or nil if it has none". A view has **at most one** superview.
- `subviews` is the array of immediate children.
- `addSubview(_:)` "establishes a strong reference to view and sets its next responder to the receiver". The parent owns its children; the window owns the root view through the controller. If the view already has a different superview, `addSubview(_:)` removes it from there first.
- `removeFromSuperview()` unlinks the view "from its superview and its window, and removes it from the responder chain". The superview releases it, and constraints that refer to it are removed too.

### Drawing order follows the array

"The order of the subviews in the array reflects their visible order on the screen, with the view at index 0 being the back-most view." Later siblings draw over earlier ones.

| Method | Effect on `subviews` |
| --- | --- |
| `addSubview(_:)` | Appends: the new view is on top |
| `insertSubview(_:at:)` | Inserts at that index |
| `bringSubviewToFront(_:)` | Moves it to the end |
| `sendSubviewToBack(_:)` | Moves it to the beginning |

### A model of the tree

This class follows the documented rules with plain Swift. `superview` is `weak` because the parent already owns the child (Module 13):

```swift
final class View {
    let name: String
    private(set) weak var superview: View?
    private(set) var subviews: [View] = []

    init(name: String) {
        self.name = name
    }

    func addSubview(_ view: View) {
        view.removeFromSuperview()
        subviews.append(view)
        view.superview = self
    }

    func bringSubviewToFront(_ view: View) {
        guard let index = subviews.firstIndex(where: { $0 === view }) else { return }
        subviews.remove(at: index)
        subviews.append(view)
    }

    func removeFromSuperview() {
        superview?.subviews.removeAll { $0 === self }
        superview = nil
    }

    func printTree(indent: String = "") {
        print(indent + name)
        for subview in subviews {
            subview.printTree(indent: indent + "  ")
        }
    }
}

let root = View(name: "root")
let card = View(name: "card")
let banner = View(name: "banner")
let badge = View(name: "badge")

root.addSubview(card)
root.addSubview(banner)
card.addSubview(badge)
root.printTree()

print("--")
banner.addSubview(badge)       // moves it: one superview only
root.bringSubviewToFront(card) // card now draws over banner
root.printTree()
print("badge's superview: \(badge.superview?.name ?? "none")")
```

```output
root
  card
    badge
  banner
--
root
  banner
    badge
  card
badge's superview: banner
```

Adding `badge` to `banner` took it out of `card`: there's one badge, and it can only be in one place. Then `card` moved to the end of `root.subviews`, so on screen it now covers `banner` wherever they overlap.

## Frame, bounds and center

Three properties describe a view's rectangle, and they're measured in **different coordinate systems**. In UIKit the origin of a coordinate system is the top-left corner, x grows to the right and y grows down; Apple's anchor documentation puts it as "Values increase as you move down." Units are points, not pixels: "The coordinates of the frame rectangle are always specified in points."

| Property | Coordinate system | Answers |
| --- | --- | --- |
| `frame` | The superview's | Where is this view inside its parent, and how big is it? |
| `bounds` | The view's own | What part of its own coordinate space does it show, and how big is it? |
| `center` | The superview's | Where is the middle of the frame? |

From the reference pages:

- **`frame`** "describes the view's location and size in its superview's coordinate system." Setting it changes `center` and the size in `bounds`. If the view's `transform` isn't the identity, "the value of this property is undefined and therefore should be ignored."
- **`bounds`** "describes the view's location and size in its own coordinate system." "The default bounds origin is (0,0) and the size is the same as the size of the rectangle in the frame property." Changing its size "grows or shrinks the view relative to its center point."
- **`center`** is "the center point of the view's frame rectangle", in the superview's coordinates. Apple recommends it "when you want to change the position of a view", because it stays valid under rotation and scaling.

Picture a card at x = 20, y = 100, 300 points wide and 200 tall:

```plaintext
frame  = (x: 20, y: 100, width: 300, height: 200)   in the root view's coordinates
bounds = (x: 0,  y: 0,   width: 300, height: 200)   in the card's own coordinates
center = (x: 170, y: 200)                            in the root view's coordinates
```

A label inside the card at `frame` (16, 16, …) is 16 points from the card's corner, whatever the card's position on screen. That's the point of having separate coordinate systems: subviews don't care where their parent is.

### A model of the three properties

The model stores `center` and `bounds`, and computes `frame` from them, the way the documentation describes the relationship:

```swift
struct Point { var x: Double; var y: Double }
struct Size { var width: Double; var height: Double }
struct Rect { var origin: Point; var size: Size }

final class View {
    var center: Point
    var bounds: Rect

    init(frame: Rect) {
        bounds = Rect(origin: Point(x: 0, y: 0), size: frame.size)
        center = Point(x: frame.origin.x + frame.size.width / 2,
                       y: frame.origin.y + frame.size.height / 2)
    }

    var frame: Rect {
        Rect(origin: Point(x: center.x - bounds.size.width / 2,
                           y: center.y - bounds.size.height / 2),
             size: bounds.size)
    }
}

func describe(_ rect: Rect) -> String {
    "(\(rect.origin.x), \(rect.origin.y), \(rect.size.width) × \(rect.size.height))"
}

let card = View(frame: Rect(origin: Point(x: 20, y: 100), size: Size(width: 300, height: 200)))
print("frame  \(describe(card.frame))")
print("bounds \(describe(card.bounds))")
print("center (\(card.center.x), \(card.center.y))")

card.bounds.size = Size(width: 200, height: 100)
print("after shrinking the bounds:")
print("frame  \(describe(card.frame))")
print("center (\(card.center.x), \(card.center.y))")
```

```output
frame  (20.0, 100.0, 300.0 × 200.0)
bounds (0.0, 0.0, 300.0 × 200.0)
center (170.0, 200.0)
after shrinking the bounds:
frame  (70.0, 150.0, 200.0 × 100.0)
center (170.0, 200.0)
```

Shrinking `bounds` kept `center` where it was, so the frame's origin moved: the view shrank around its middle, as the documentation says.

### Changing the bounds origin

The bounds origin is which point of the view's own coordinate space appears at its top-left corner. Set a view's `bounds.origin` to (0, 50) and every subview appears 50 points higher, without any subview's frame changing. Scrolling builds on this idea: a scroll view's `contentOffset` is "the point at which the origin of the content view is offset from the origin of the scroll view". Module 23 covers scroll views.

### Converting between coordinate systems

To find where a point inside a subview lands in its superview, add the subview's frame origin and subtract its bounds origin:

```plaintext
pointInSuperview = frame.origin + (pointInView − bounds.origin)
```

UIKit does this for you with `convert(_:to:)` and `convert(_:from:)`, walking up the tree as many levels as needed:

```swift ios
import UIKit

let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
let card = UIView(frame: CGRect(x: 20, y: 100, width: 350, height: 200))
let badge = UILabel(frame: CGRect(x: 16, y: 16, width: 120, height: 24))
badge.text = "New"

root.addSubview(card)
card.addSubview(badge)

let badgeCornerInRoot = card.convert(badge.frame.origin, to: root)
print(badgeCornerInRoot)          // (36, 116) by the formula above
print(badge.superview === card)
print(root.subviews.count)
```

This block is type-checked, not run; the comment is the formula's result, not observed output.

## Clipping and touches

By default a subview can draw outside its superview: `clipsToBounds` "default value is false" (some subclasses, such as `UIScrollView`, set it to `true`). Touches are stricter. UIKit finds the view under a finger with `hitTest(_:with:)`, which "doesn't report points that lie outside the view's bounds as hits, even if they actually lie within one of the view's subviews." A button that sticks out of its parent is visible there but can't be tapped there. Hit testing also skips views that are hidden, have user interaction disabled, or have an alpha below 0.01.

## A first look at Auto Layout anchors

Setting frames by hand breaks as soon as the screen size, the orientation or the text size changes. Real screens describe **relationships** instead: "this label's top is 16 points below the safe area's top". That's Auto Layout, and Module 23 covers it in depth. For this module you need one pattern:

```swift ios
import UIKit

final class BannerViewController: UIViewController {
    private let banner = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        banner.text = "You're offline"
        banner.textAlignment = .center
        banner.backgroundColor = .systemYellow
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
}
```

- `translatesAutoresizingMaskIntoConstraints = false`. Apple: "By default, the system sets this property to true for any view you programmatically create", which makes UIKit generate constraints from the view's frame. Those would fight yours. Interface Builder sets it to `false` for you; in code you set it on every view you constrain.
- `view.addSubview(banner)` comes **before** the constraints. Apple's `isActive` documentation: "If you try to activate a constraint whose items have no common ancestor, an exception is thrown."
- `NSLayoutConstraint.activate(_:)` activates the whole array at once, which Apple says is "typically more efficient" than one by one.
- `safeAreaLayoutGuide` is "the portion of your view that is unobscured by bars and other content": below the status bar and the Dynamic Island, above the home indicator. Pinning the top to `view.topAnchor` instead would put the banner under the status bar.
- Leading and trailing, not left and right: they flip for right-to-left languages.

Four constraints, four unknowns (x, y, width, height). Lesson 4 builds a full screen this way.

## Common mistakes

> [!error] Expecting addSubview to copy a view
> Adding the same label to a second card moves it. A view has one superview. Create a second label.

> [!error] Activating constraints before adding the view
> The two views have no common ancestor yet, and UIKit throws an exception. `addSubview(_:)` first, constraints second.

> [!error] Forgetting translatesAutoresizingMaskIntoConstraints
> A view created in code keeps generating constraints from its frame (zero-sized at the origin if you never set one). Together with your constraints that's a conflict Auto Layout has to break, and the view ends up somewhere you didn't ask for.

> [!error] Reading frame on a rotated or scaled view
> With a non-identity `transform`, `frame` is undefined. Use `center` and `bounds`.

> [!error] Pinning to view.topAnchor instead of the safe area
> Content slides under the status bar and the Dynamic Island. Use `view.safeAreaLayoutGuide.topAnchor` for content; extend only backgrounds to the real edges.

## Exercises

````exercise
id: m22-l03-e1
type: prediction
prompt: "Using a model of the view tree with the documented rules, what does this print? Remember that the last subview draws on top."
code: |
  final class View {
      let name: String
      private(set) weak var superview: View?
      private(set) var subviews: [View] = []
      init(name: String) { self.name = name }

      func addSubview(_ view: View) {
          view.removeFromSuperview()
          subviews.append(view)
          view.superview = self
      }

      func sendSubviewToBack(_ view: View) {
          guard let index = subviews.firstIndex(where: { $0 === view }) else { return }
          subviews.remove(at: index)
          subviews.insert(view, at: 0)
      }

      func removeFromSuperview() {
          superview?.subviews.removeAll { $0 === self }
          superview = nil
      }
  }

  let root = View(name: "root")
  let photo = View(name: "photo")
  let caption = View(name: "caption")
  let shadow = View(name: "shadow")
  root.addSubview(photo)
  root.addSubview(caption)
  root.addSubview(shadow)
  root.sendSubviewToBack(shadow)
  caption.removeFromSuperview()
  photo.addSubview(caption)

  print(root.subviews.map(\.name).joined(separator: ", "))
  print(photo.subviews.map(\.name).joined(separator: ", "))
  print("top of root: \(root.subviews.last?.name ?? "none")")
  print("caption is in \(caption.superview?.name ?? "nothing")")
output: |
  shadow, photo
  caption
  top of root: photo
  caption is in photo
hints:
  - "After the three adds, root's order is photo, caption, shadow. Then shadow moves to index 0."
  - "Removing caption leaves shadow, photo."
solution: |
  ```output
  shadow, photo
  caption
  top of root: photo
  caption is in photo
  ```

  `sendSubviewToBack(_:)` put `shadow` at index 0 (the back), `caption` left `root` and joined `photo`. `photo` is last in `root.subviews`, so it draws on top of `shadow`, which is what you want for a shadow behind a photo. `caption` now lives in `photo`'s coordinate system and moves with it.
````

````exercise
id: m22-l03-e2
type: prediction
prompt: "The same frame, bounds and center model as the lesson. A 100 × 100 avatar is moved with center, then grows through its bounds. What does it print?"
code: |
  struct Point { var x: Double; var y: Double }
  struct Size { var width: Double; var height: Double }
  struct Rect { var origin: Point; var size: Size }

  final class View {
      var center: Point
      var bounds: Rect
      init(frame: Rect) {
          bounds = Rect(origin: Point(x: 0, y: 0), size: frame.size)
          center = Point(x: frame.origin.x + frame.size.width / 2,
                         y: frame.origin.y + frame.size.height / 2)
      }
      var frame: Rect {
          Rect(origin: Point(x: center.x - bounds.size.width / 2,
                             y: center.y - bounds.size.height / 2),
               size: bounds.size)
      }
  }

  let avatar = View(frame: Rect(origin: Point(x: 0, y: 0), size: Size(width: 100, height: 100)))
  avatar.center = Point(x: 200, y: 300)
  print(avatar.frame.origin.x, avatar.frame.origin.y)
  avatar.bounds.size = Size(width: 160, height: 160)
  print(avatar.frame.origin.x, avatar.frame.origin.y, avatar.frame.size.width)
  print(avatar.bounds.origin.x, avatar.bounds.origin.y)
output: |
  150.0 250.0
  120.0 220.0 160.0
  0.0 0.0
hints:
  - "frame.origin = center − half the bounds size."
  - "Changing the bounds size doesn't move the center."
solution: |
  ```output
  150.0 250.0
  120.0 220.0 160.0
  0.0 0.0
  ```

  With the center at (200, 300) and a 100-point square, the frame starts at (200 − 50, 300 − 50) = (150, 250). Growing the bounds to 160 keeps the center, so the origin becomes (200 − 80, 300 − 80) = (120, 220). The bounds origin never changed: it's still (0, 0) in the avatar's own coordinates. That's how `UIView` behaves: changing the bounds size "grows or shrinks the view relative to its center point".
````

````exercise
id: m22-l03-e3
type: comprehension
prompt: "A card view is rotated 10 degrees with a transform. You want to move it 40 points to the right. What should you change?"
choices:
  - text: "center.x, adding 40."
    correct: true
    why: "Apple: the center point is always valid, even when scaling or rotation factors are applied."
  - text: "frame.origin.x, adding 40."
    correct: false
    why: "With a non-identity transform the frame is undefined and shouldn't be modified."
  - text: "bounds.origin.x, adding 40."
    correct: false
    why: "That shifts the card's content inside it, in the opposite direction, and doesn't move the card."
  - text: "Nothing works until the transform is removed."
    correct: false
    why: "center keeps working under a transform."
solution: |
  **Change `center`.** It's in the superview's coordinates and stays valid with any transform. `frame` becomes undefined once the transform isn't the identity, and `bounds.origin` changes what the card shows inside itself, not where the card is.
````

````exercise
id: m22-l03-e4
type: solve
prompt: |
  Using the model below, write `convertToRoot(_:from:)`: given a point in a view's own coordinates, return where it is in the coordinates of the top of its tree (the view with no superview). Use the lesson's formula at each level: `frame.origin + (point − bounds.origin)`, then move to the superview.

  ```swift
  let root = View(origin: Point(x: 0, y: 0), superview: nil)
  let list = View(origin: Point(x: 0, y: 100), superview: root)
  list.boundsOrigin = Point(x: 0, y: 300)   // scrolled down 300 points
  let row = View(origin: Point(x: 0, y: 320), superview: list)
  let point = convertToRoot(Point(x: 10, y: 5), from: row)
  print(point.x, point.y)
  ```

  should print `10.0 125.0`.
starter: |
  struct Point { var x: Double; var y: Double }

  final class View {
      let frameOrigin: Point          // in the superview's coordinates
      var boundsOrigin = Point(x: 0, y: 0)
      let superview: View?
      init(origin: Point, superview: View?) {
          frameOrigin = origin
          self.superview = superview
      }
  }

  func convertToRoot(_ point: Point, from view: View) -> Point {
      // your code
      return point
  }
hints:
  - "Loop while the current view has a superview."
  - "At each step: point = frameOrigin + (point − boundsOrigin) of the current view, then current = superview."
  - "The root has no superview, so its own frame doesn't apply: you're already in its coordinates."
rubric:
  - Walks up the superview chain until there's no superview.
  - Applies the frame origin and subtracts the bounds origin of each view on the way.
  - Doesn't apply the root's frame.
  - Prints 10.0 125.0 for the example.
solution: |
  ```swift
  struct Point { var x: Double; var y: Double }

  final class View {
      let frameOrigin: Point
      var boundsOrigin = Point(x: 0, y: 0)
      let superview: View?
      init(origin: Point, superview: View?) {
          frameOrigin = origin
          self.superview = superview
      }
  }

  func convertToRoot(_ point: Point, from view: View) -> Point {
      var result = point
      var current = view
      while let parent = current.superview {
          result = Point(x: current.frameOrigin.x + (result.x - current.boundsOrigin.x),
                         y: current.frameOrigin.y + (result.y - current.boundsOrigin.y))
          current = parent
      }
      return result
  }

  let root = View(origin: Point(x: 0, y: 0), superview: nil)
  let list = View(origin: Point(x: 0, y: 100), superview: root)
  list.boundsOrigin = Point(x: 0, y: 300)
  let row = View(origin: Point(x: 0, y: 320), superview: list)
  let point = convertToRoot(Point(x: 10, y: 5), from: row)
  print(point.x, point.y)
  ```

  ```output
  10.0 125.0
  ```

  Step by step: in `list`'s coordinates the point is (0 + 10, 320 + 5) = (10, 325). `list` is scrolled 300 points, so in `root` it's (0 + 10 − 0, 100 + 325 − 300) = (10, 125). The row at y = 320 inside the list appears just 20 points below the list's top edge, because the list shows its content from y = 300. `UIView.convert(_:to:)` does this walk for you.
````

````exercise
id: m22-l03-e5
type: find-errors
prompt: "This viewDidLoad() should show the same 'Beta' tag on two cards, pinned under the safe area. Mark every real problem."
code: |
  override func viewDidLoad() {
      super.viewDidLoad()
      let tag = UILabel()
      tag.text = "Beta"

      NSLayoutConstraint.activate([
          firstCard.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
          firstCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      ])
      view.addSubview(firstCard)
      view.addSubview(secondCard)

      firstCard.addSubview(tag)
      secondCard.addSubview(tag)
  }
choices:
  - text: "The constraints are activated before firstCard is in the hierarchy, which throws an exception."
    correct: true
  - text: "The same label is added to both cards; the second addSubview moves it out of the first."
    correct: true
  - text: "firstCard is pinned to view.topAnchor instead of the safe area, so it can end up under the status bar."
    correct: true
  - text: "firstCard never gets translatesAutoresizingMaskIntoConstraints = false (assuming it's created in code)."
    correct: true
  - text: "addSubview must be called before setting the label's text."
    correct: false
    why: "Properties can be set in any order; only constraints need a common ancestor."
rubric:
  - I found the activation before addSubview.
  - I found the shared label.
  - I found the top anchor that ignores the safe area.
  - I found the missing translatesAutoresizingMaskIntoConstraints.
solution: |
  Four problems:

  1. **Constraints before `addSubview(_:)`.** `firstCard` and `view` have no common ancestor yet; Apple documents that activating such a constraint throws.
  2. **One label, two cards.** A view has one superview, so `tag` ends up only in `secondCard`. Make two labels (or a small function that returns a new one).
  3. **`view.topAnchor`** puts the card under the status bar on devices where the safe area starts lower. Use `view.safeAreaLayoutGuide.topAnchor`.
  4. **`translatesAutoresizingMaskIntoConstraints`** is `true` for views made in code, so the card's frame-based constraints conflict with yours.
````

````exercise
id: m22-l03-e6
type: fill-in
prompt: Pin `statusLabel` 20 points below the top of the safe area, with 16 points of margin on both sides.
code: |
  statusLabel.[[1]] = false
  view.addSubview(statusLabel)
  NSLayoutConstraint.[[2]]([
      statusLabel.topAnchor.constraint(equalTo: view.[[3]].topAnchor, constant: 20),
      statusLabel.[[4]].constraint(equalTo: view.leadingAnchor, constant: 16),
      statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
  ])
blanks:
  - id: "1"
    answers: ["translatesAutoresizingMaskIntoConstraints"]
  - id: "2"
    answers: ["activate"]
  - id: "3"
    answers: ["safeAreaLayoutGuide"]
  - id: "4"
    answers: ["leadingAnchor"]
solution: |
  ```swift ios
  import UIKit

  final class StatusViewController: UIViewController {
      private let statusLabel = UILabel()

      override func viewDidLoad() {
          super.viewDidLoad()
          statusLabel.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(statusLabel)
          NSLayoutConstraint.activate([
              statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
              statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
              statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
          ])
      }
  }
  ```

  The trailing constant is negative: for x-axis anchors, Apple's documentation says the first item is positioned "c points after the second". Here the label's trailing edge should be 16 points **before** the view's, so `c = -16`. The label has no height constraint because a label has a natural (intrinsic) height from its text; Module 23 explains that.
````

## Summary

- Views form a tree. `addSubview(_:)` keeps a strong reference to the child, sets the parent as its next responder and moves it out of any previous parent; `removeFromSuperview()` releases it and its constraints.
- In `subviews`, index 0 is at the back and the last view is on top. `bringSubviewToFront(_:)`, `sendSubviewToBack(_:)` and `insertSubview(_:at:)` reorder.
- `frame` is in the superview's coordinates; `bounds` is in the view's own (origin (0, 0) by default); `center` is the frame's midpoint in the superview's coordinates. Changing the bounds size keeps the center. With a transform, use `center` and `bounds`, not `frame`.
- Coordinates start at the top-left, y grows down, units are points. `convert(_:to:)` moves points between views.
- Subviews can draw outside their parent but can't be touched there.
- With anchors: set `translatesAutoresizingMaskIntoConstraints = false`, add the view, then `NSLayoutConstraint.activate` constraints against `safeAreaLayoutGuide` and leading/trailing anchors.
