---
id: m27-l02
title: Core Animation and layers
description: Every UIKit view draws through a CALayer. You style layers directly (corners, borders, shadows with a shadow path), tell implicit animations from explicit ones, animate with CABasicAnimation and CAKeyframeAnimation, and learn the model and presentation layers well enough to explain, and fix, the classic bug where a layer snaps back when its animation ends.
module: m27
order: 2
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l01]
objectives:
  - Explain the relationship between a UIView and its backing CALayer, and when to work with the layer directly.
  - Style a layer with corner radius, corner curve, border and shadow, and give the shadow an explicit path.
  - Tell implicit layer animations from explicit ones, and suppress implicit animations with CATransaction.
  - Animate layer properties with CABasicAnimation and CAKeyframeAnimation.
  - Distinguish the model layer from the presentation layer and use presentation() to read in-flight values.
  - Explain why a layer snaps back after an explicit animation and fix it by updating the model value.
terms:
  - term: CALayer
    definition: "The Core Animation object that holds a rectangle's visual state (contents, background, border, shadow, geometry, transform) and animates changes to it. Every UIView on iOS is backed by one."
  - term: Model layer
    definition: "The layer object your code reads and writes. Its properties hold the target values: what the layer should look like when no animation is running."
  - term: Presentation layer
    definition: "A copy that shows the layer as it currently appears on screen, with in-flight animation values. You get it with presentation(); it's only meaningful while an animation runs."
  - term: Implicit animation
    definition: "An animation Core Animation creates by itself when you change an animatable property of a standalone layer. A view's backing layer doesn't animate implicitly outside a UIView animation block."
  - term: Explicit animation
    definition: "A CAAnimation object (CABasicAnimation, CAKeyframeAnimation, a group) that you configure and add with add(_:forKey:). It changes only what's drawn, never the model value."
  - term: CATransaction
    definition: "Core Animation's way of batching layer changes into atomic updates. You use explicit transactions to change the duration of implicit animations or disable them."
mastery:
  - Give a card rounded continuous corners, a border and a shadow with an explicit shadowPath, without clipping the shadow.
  - Move a standalone layer without animation using CATransaction.setDisableActions(true).
  - Write a fade with CABasicAnimation that ends in the right state without fillMode tricks.
  - Write a shake with an additive CAKeyframeAnimation.
  - Predict what's on screen and what the model holds at several moments of an explicit animation.
  - Hit-test a moving layer with its presentation layer.
resources: [quartzcore-calayer, quartzcore-cabasicanimation, uikit-uiview, uikit-uiview-frame]
cards:
  - id: m27-l02-c1
    front: Why does a layer snap back when a CABasicAnimation ends?
    back: "An explicit animation changes only what's drawn (the presentation), never the model value. When it's removed on completion, the layer shows the model value again. Set the property to the final value yourself when you add the animation."
  - id: m27-l02-c2
    front: Why not fix the snap-back with fillMode = .forwards and isRemovedOnCompletion = false?
    back: "The screen keeps showing the end value, but the model still holds the old one, so reading the property, hit testing and later animations all disagree with what's visible, and the animation object stays attached forever."
  - id: m27-l02-c3
    front: Model layer vs presentation layer?
    back: "The model layer holds target values, what your code sets. The presentation layer, from presentation(), holds the in-flight values currently on screen. Read it only while an animation is running, for example to hit-test a moving layer."
  - id: m27-l02-c4
    front: Does changing view.layer.opacity animate by itself?
    back: "No. UIView disables implicit animations for its backing layer, except inside UIView animation blocks. A standalone layer you added as a sublayer does animate implicitly; wrap the change in a CATransaction with setDisableActions(true) to stop it."
  - id: m27-l02-c5
    front: Why set shadowPath on a layer with a shadow?
    back: "Without it, Core Animation computes the shadow's shape from the layer's composited alpha. Apple says that can be expensive and that specifying an explicit path usually improves rendering performance."
---

## The idea in one sentence

A view is a thin, touch-handling wrapper around a `CALayer` that does the actual drawing and animating, and every layer exists twice: the **model** your code sets, and the **presentation** the screen shows while an animation runs; nearly every Core Animation bug comes from confusing the two.

> [!note] About this lesson's code
> UIKit and Core Animation blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `CALayer`, `CABasicAnimation`, `CAKeyframeAnimation`, `CAAnimation`, `CATransaction` and `UIView`, and from the archived *Core Animation Programming Guide* (last updated 2015, still Apple's longest explanation of the layer trees), read in November 2026. The layer model and the keyframe math are plain Swift, compiled and run with Swift 6.3.

## Views and layers

The archived *Core Animation Programming Guide* puts it plainly: "In iOS, every view is backed by a corresponding layer object." The view is the layer's delegate; `UIView`'s documentation warns: "never change the delegate of this layer object." The division of work:

| `UIView` | `CALayer` |
| --- | --- |
| Touches, gestures, the responder chain | No event handling |
| Auto Layout, safe areas, trait collections | Geometry only: `bounds`, `position`, `anchorPoint`, `transform` |
| Accessibility | None |
| `backgroundColor`, `alpha` (forwarded to the layer) | Corner radius, border, shadow, mask, contents, sublayers |

Apple's guide recommends: "For layer-backed views, it is recommended that you manipulate the view, rather than its layer, whenever possible." In practice you reach for the layer for three things: **styling the view doesn't expose** (corners, borders, shadows), **lightweight drawing** with sublayers such as `CAShapeLayer` and `CAGradientLayer`, and **animations UIKit can't express**, like a keyframe shake or a stroke being drawn.

## Styling a layer

A card with rounded corners, a hairline border and a soft shadow:

```swift ios
import UIKit

let card = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
card.backgroundColor = .systemBackground

card.layer.cornerRadius = 16
card.layer.cornerCurve = .continuous
card.layer.borderWidth = 1
card.layer.borderColor = UIColor.separator.cgColor

card.layer.shadowColor = UIColor.black.cgColor
card.layer.shadowOpacity = 0.15
card.layer.shadowRadius = 12
card.layer.shadowOffset = CGSize(width: 0, height: 4)
card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: 16).cgPath
```

- **`cornerRadius`** rounds the background and border. Apple: "By default, the corner radius does not apply to the image in the layer's contents property"; to clip contents and sublayers to the corners you also need `masksToBounds = true`.
- **`cornerCurve`** chooses between `.circular` and `.continuous` corners. Apple's reference pages for these values have no description; `.continuous` blends the corner into the straight edges more gradually than a quarter circle, which you can see by comparing the two at a large radius.
- **Colors are `CGColor`**. A `CGColor` is a fixed value, so a dynamic color like `.separator` won't follow dark mode after you assign it. Set it again when the trait collection changes (Module 23's trait-change registration works for this).
- **`shadowOpacity` defaults to 0**, so no shadow appears until you raise it. `shadowOffset` defaults to (0, −3).
- **`shadowPath`**. Without it, the layer builds the shadow from its "composited alpha channel", which means rendering the content to find its shape. Apple's `shadowPath` page: "Specifying an explicit path usually improves rendering performance." The archived guide is blunter: "Letting Core Animation determine the shape of a shadow can be expensive." Lesson 4 comes back to rendering costs.

### Shadows and clipping don't mix

`masksToBounds = true` clips **everything** outside the bounds, including the shadow. For a card with a photo that must be clipped to the rounded corners **and** a shadow, use two views:

```swift ios
import UIKit

final class PhotoCardView: UIView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 10

        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 16
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }
}
```

The outer view draws the shadow and never clips; the inner image view clips to its corners. The shadow path is updated in `layoutSubviews()`, because it has to match the current bounds; a path computed once in `init` would be wrong as soon as Auto Layout resizes the card.

## Implicit animations

Change an animatable property of a **standalone** layer, one you created and added as a sublayer, and Core Animation animates the change by itself. The guide: "To trigger implicit animations, all you have to do is update the properties of your layer object."

A view's **own** layer behaves differently. The guide again: "The UIView class disables layer animations by default but reenables them inside animation blocks." So `view.layer.opacity = 0` changes instantly, while the same line inside `UIView.animate` animates.

The mechanism behind this is the layer's **action** lookup. When a property changes, the layer asks for an action for that key, first from its delegate's `action(for:forKey:)`. For a backing layer, the delegate is the view, and outside an animation block the view answers "no action".

Sometimes you want a standalone layer to move **without** animating, for example when you lay it out:

```swift ios
import UIKit

final class MeterView: UIView {
    private let fill = CALayer()
    var level: CGFloat = 0.5 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGray5
        fill.backgroundColor = UIColor.systemGreen.cgColor
        layer.addSublayer(fill)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * level, height: bounds.height)
        CATransaction.commit()
    }

    func setLevelAnimated(_ newLevel: CGFloat) {
        level = newLevel
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.4)
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * newLevel, height: bounds.height)
        CATransaction.commit()
    }
}
```

- **`CATransaction`** batches layer changes. Apple: "Every modification to a layer tree must be part of a transaction." When you don't create one, Core Animation creates an implicit transaction and commits it "when the thread's runloop next iterates".
- **`setDisableActions(true)`** suppresses the implicit animations triggered by changes in that transaction. Without it, the fill would animate every time the view is resized, including during rotation, lagging behind the view.
- **`setAnimationDuration(_:)`** changes the duration of the implicit animations in the transaction; here the fill animates over 0.4 seconds.

## Explicit animations

An explicit animation is an object you configure and attach to a layer. `CABasicAnimation` animates one property between two values:

```swift ios
import UIKit

@MainActor
func fadeOut(_ layer: CALayer) {
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = layer.opacity
    fade.toValue = 0
    fade.duration = 0.5
    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    layer.opacity = 0
    layer.add(fade, forKey: "fade")
}
```

1. **`CABasicAnimation(keyPath:)`** names the property. Key paths can reach into structures: `"position.x"`, `"transform.scale"`, `"transform.rotation.z"`.
2. **`fromValue` and `toValue`** are typed `Any?`; numbers and Core Graphics values are wrapped as `NSNumber` and `NSValue` when they cross into Core Animation. If you leave `fromValue` out, the animation "Interpolates between the current value of keyPath in the target layer's presentation layer and toValue."
3. **`duration`**: if it's zero or negative, `add(_:forKey:)` changes it to the transaction's duration or "the default value of 0.25 seconds".
4. **`layer.opacity = 0`** is the line people forget. Explained in the next section.
5. **`add(_:forKey:)`** copies the animation into the render tree: "subsequent modifications to the object are not propagated." The key identifies it; "Only one animation per unique key is added to the layer", so adding another with the key `"fade"` replaces this one, and `removeAnimation(forKey:)` cancels it.

## Model and presentation

The guide describes two parallel trees of layers. The objects you work with are the **model**: they "contain the target values for an animation". The **presentation** tree holds "the current values as they appear onscreen". And the sentence that explains most Core Animation bugs: "Unlike an implicit animation, which updates the layer object's data value, an explicit animation does not modify the data in the layer tree. Explicit animations only produce the animations."

That explains the most famous Core Animation bug. Here is a plain-Swift model of a layer with a model value and explicit animations that only affect what's drawn:

```swift
struct BasicAnimation {
    let keyPath: String
    var fromValue: Double? = nil
    let toValue: Double
    let duration: Double
    var isRemovedOnCompletion = true
    var fillsForwards = false
}

final class LayerModel {
    private var model: [String: Double]
    private var animations: [String: (animation: BasicAnimation, beginTime: Double)] = [:]

    init(_ values: [String: Double]) {
        model = values
    }

    // Setting a property changes the model layer only.
    func set(_ keyPath: String, to value: Double) {
        model[keyPath] = value
    }

    func modelValue(_ keyPath: String) -> Double {
        model[keyPath] ?? 0
    }

    // An explicit animation never touches the model.
    func add(_ animation: BasicAnimation, forKey key: String, at time: Double) {
        animations[key] = (animation, time)
    }

    // What's drawn on screen at a given time.
    func presentationValue(_ keyPath: String, at time: Double) -> Double {
        let base = modelValue(keyPath)
        for (key, entry) in animations where entry.animation.keyPath == keyPath {
            let animation = entry.animation
            let elapsed = time - entry.beginTime
            if elapsed >= animation.duration {
                if animation.isRemovedOnCompletion {
                    animations[key] = nil
                    return base
                }
                return animation.fillsForwards ? animation.toValue : base
            }
            let from = animation.fromValue ?? base
            return from + (animation.toValue - from) * (elapsed / animation.duration)
        }
        return base
    }
}

func show(_ layer: LayerModel, _ keyPath: String, times: [Double]) {
    let values = times.map { "\(Int((layer.presentationValue(keyPath, at: $0) * 100).rounded()))%" }
    print("on screen:", values.joined(separator: " "), "| model:", "\(Int((layer.modelValue(keyPath) * 100).rounded()))%")
}

let times = [0, 0.25, 0.5, 1, 2]

let snapsBack = LayerModel(["opacity": 1])
snapsBack.add(BasicAnimation(keyPath: "opacity", fromValue: 1, toValue: 0, duration: 1), forKey: "fade", at: 0)
show(snapsBack, "opacity", times: times)

let correct = LayerModel(["opacity": 1])
correct.set("opacity", to: 0)
correct.add(BasicAnimation(keyPath: "opacity", fromValue: 1, toValue: 0, duration: 1), forKey: "fade", at: 0)
show(correct, "opacity", times: times)

let frozen = LayerModel(["opacity": 1])
frozen.add(BasicAnimation(keyPath: "opacity", fromValue: 1, toValue: 0, duration: 1, isRemovedOnCompletion: false, fillsForwards: true), forKey: "fade", at: 0)
show(frozen, "opacity", times: times)
```

```output
on screen: 100% 75% 50% 100% 100% | model: 100%
on screen: 100% 75% 50% 0% 0% | model: 0%
on screen: 100% 75% 50% 0% 0% | model: 100%
```

Three layers, sampled at 0, 0.25, 0.5, 1 and 2 seconds:

1. **`snapsBack`** only adds the animation. The fade runs, and at 1 second `isRemovedOnCompletion` (default `true`: "the animation is removed from the target layer's animations once its active duration has passed") removes it. Nothing is overriding the model any more, so the screen shows the model value again: **100%. The layer snaps back.**
2. **`correct`** sets the model to 0 and adds the animation with an explicit `fromValue` of 1. The animation covers the change while it runs; when it's removed, the model already says 0, so the screen stays at 0. This is what the guide prescribes: "If you want the changes from an explicit animation to be permanent, you must also update the layer's property."
3. **`frozen`** uses the common workaround: `isRemovedOnCompletion = false` and `fillMode = .forwards`. The screen looks right, but **the model still says 100%**. Anything that reads the property, hit tests the layer or starts the next animation from the model value works with the wrong number, and the finished animation stays attached to the layer.

Order matters in the correct version only in one way: set an explicit `fromValue`. If you set the model to 0 first and leave `fromValue` out, the animation starts from the current presentation value, which is already 0, and nothing visible happens. Apple's guide: "When creating an explicit animation, it is recommended that you always assign a value to the fromValue property of the animation object."

### Reading the presentation layer

`presentation()` "Returns a copy of the presentation layer object that represents the state of the layer as it currently appears onscreen." The guide adds: "You should access objects in the presentation tree only while an animation is in flight."

The classic use is tapping something that moves. The model layer is already at the destination, so testing a tap against `layer.frame` misses a target that's visibly somewhere else:

```swift ios
import UIKit

final class TargetViewController: UIViewController {
    private let target = CALayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        target.backgroundColor = UIColor.systemRed.cgColor
        target.frame = CGRect(x: 20, y: 200, width: 60, height: 60)
        view.layer.addSublayer(target)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    func startMoving() {
        let move = CABasicAnimation(keyPath: "position.x")
        move.fromValue = 50
        move.toValue = 300
        move.duration = 3
        target.position.x = 300
        target.add(move, forKey: "move")
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: view)
        let onScreen = target.presentation() ?? target
        if onScreen.frame.contains(point) {
            print("hit")
        }
    }
}
```

`presentation()` returns an optional: there's no presentation copy before the layer has been rendered once. Falling back to the model layer covers that.

## Keyframe animations

`CAKeyframeAnimation` passes through a list of values. Each value has a **key time**, a fraction of the duration, and with the default `linear` calculation mode the value between two keyframes is interpolated. Apple's rules for `keyTimes`: each value is between 0 and 1, "Each successive value in the array must be greater than, or equal to, the previous value", and in linear mode "the first value in the array must be 0.0 and the last value must be 1.0".

A shake for a wrong password:

```swift ios
import UIKit

@MainActor
func shake(_ view: UIView) {
    let shake = CAKeyframeAnimation(keyPath: "position.x")
    shake.values = [0, -10, 10, -6, 6, 0]
    shake.keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]
    shake.duration = 0.4
    shake.isAdditive = true
    view.layer.add(shake, forKey: "shake")
}
```

**`isAdditive = true`** adds each value to the current render value: "the value specified by the animation will be added to the current render tree value of the property". The values are offsets from wherever the view is, so the same animation works for any view, and since the last value is 0, the model doesn't need updating: the view ends where it started.

Here's linear keyframe interpolation in plain Swift, using the shake's values:

```swift
func keyframeValue(values: [Double], keyTimes: [Double], at time: Double) -> Double {
    for index in 1..<keyTimes.count where time <= keyTimes[index] {
        let start = keyTimes[index - 1]
        let end = keyTimes[index]
        let fraction = end == start ? 1 : (time - start) / (end - start)
        return values[index - 1] + (values[index] - values[index - 1]) * fraction
    }
    return values[values.count - 1]
}

let values = [0.0, -10, 10, -6, 6, 0]
let keyTimes = [0, 0.2, 0.4, 0.6, 0.8, 1]
for step in 0...10 {
    let time = Double(step) / 10
    let offset = keyframeValue(values: values, keyTimes: keyTimes, at: time)
    print("t=\(step * 10)%: \(Int(offset.rounded()))")
}
```

```output
t=0%: 0
t=10%: -5
t=20%: -10
t=30%: 0
t=40%: 10
t=50%: 2
t=60%: -6
t=70%: 0
t=80%: 6
t=90%: 3
t=100%: 0
```

At 30% the time is halfway between the keyframes at 20% (−10) and 40% (10), so the offset is 0. With `calculationMode = .discrete` the value would jump from keyframe to keyframe instead, and `keyTimes` would need one more entry than `values`.

## Drawing a stroke: CAShapeLayer

A `CAShapeLayer` draws a path. Its `strokeEnd` (0 to 1, default 1) says how much of the path is stroked, "interpreted linearly along the path length", which makes a progress ring a one-property animation. Making the shape layer the view's own layer saves managing a sublayer's frame:

```swift ios
import UIKit

final class ProgressRingView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
    private var ring: CAShapeLayer { layer as! CAShapeLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        ring.fillColor = nil
        ring.strokeColor = UIColor.systemBlue.cgColor
        ring.lineWidth = 8
        ring.lineCap = .round
        ring.strokeEnd = 0
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.width, bounds.height) / 2 - ring.lineWidth / 2
        ring.path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        ).cgPath
    }

    func setProgress(_ progress: CGFloat) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = (ring.presentation() ?? ring).strokeEnd
        animation.toValue = progress
        animation.duration = 0.3
        ring.strokeEnd = progress
        ring.add(animation, forKey: "progress")
    }
}
```

- **`layerClass`** "Returns the class used to create the layer for instances of this class" and is read "only once early in the creation of the view".
- The arc starts at −π/2, the top of the circle, and goes clockwise a full turn.
- **`setProgress`** follows the rule from the model section: `fromValue` is where the ring currently **is** (the presentation value, if a previous animation is still running), the model is set to the new value, and the animation covers the change. Calling it twice quickly continues from the visible position instead of jumping.

## Common mistakes

> [!error] Adding an explicit animation without updating the model
> The layer snaps back when the animation is removed. Set the property to the final value in the same place you add the animation, and give the animation an explicit `fromValue`.

> [!error] fillMode = .forwards with isRemovedOnCompletion = false as the fix
> The screen shows the end value while the model holds the start value. Hit tests, reads of the property and the next animation all use the wrong value, and the animation never leaves the layer.

> [!error] Expecting view.layer changes to animate on their own
> A view's backing layer doesn't animate implicitly outside a UIView animation block. Use `UIView.animate` for properties the view exposes, or an explicit `CABasicAnimation` for layer-only properties like `cornerRadius` or `shadowOpacity`.

> [!error] A standalone sublayer that lags behind during layout
> Setting a sublayer's frame in `layoutSubviews()` triggers an implicit animation. Wrap layout changes in a `CATransaction` with `setDisableActions(true)`.

> [!error] masksToBounds on a view that has a shadow
> Clipping removes the shadow. Put the shadow on an outer view and clip an inner one.

> [!error] A shadow path computed once
> `shadowPath` doesn't follow the bounds. Update it in `layoutSubviews()`, or the shadow keeps the old shape after a resize.

> [!error] Hit-testing a moving layer with its model frame
> During an animation the model layer is already at the destination. Use `presentation()` while the animation is in flight.

## Exercises

````exercise
id: m27-l02-e1
type: prediction
prompt: "With the lesson's LayerModel (repeated so it compiles on its own), the code sets the model first and leaves fromValue out. What does it print?"
code: |
  struct BasicAnimation {
      let keyPath: String
      var fromValue: Double? = nil
      let toValue: Double
      let duration: Double
      var isRemovedOnCompletion = true
      var fillsForwards = false
  }

  final class LayerModel {
      private var model: [String: Double]
      private var animations: [String: (animation: BasicAnimation, beginTime: Double)] = [:]

      init(_ values: [String: Double]) {
          model = values
      }

      func set(_ keyPath: String, to value: Double) {
          model[keyPath] = value
      }

      func modelValue(_ keyPath: String) -> Double {
          model[keyPath] ?? 0
      }

      func add(_ animation: BasicAnimation, forKey key: String, at time: Double) {
          animations[key] = (animation, time)
      }

      func presentationValue(_ keyPath: String, at time: Double) -> Double {
          let base = modelValue(keyPath)
          for (key, entry) in animations where entry.animation.keyPath == keyPath {
              let animation = entry.animation
              let elapsed = time - entry.beginTime
              if elapsed >= animation.duration {
                  if animation.isRemovedOnCompletion {
                      animations[key] = nil
                      return base
                  }
                  return animation.fillsForwards ? animation.toValue : base
              }
              let from = animation.fromValue ?? base
              return from + (animation.toValue - from) * (elapsed / animation.duration)
          }
          return base
      }
  }

  let layer = LayerModel(["x": 0])
  layer.set("x", to: 200)
  layer.add(BasicAnimation(keyPath: "x", toValue: 200, duration: 1), forKey: "move", at: 0)
  for time in [0, 0.5, 1] {
      print(Int(layer.presentationValue("x", at: time)))
  }
output: |
  200
  200
  200
hints:
  - "Without fromValue, the animation starts from the value the layer already shows."
  - "In this model, what's the base value when the animation is sampled?"
solution: |
  ```output
  200
  200
  200
  ```

  The layer jumps to 200 with no visible animation. The animation has only a `toValue`, so it interpolates from the current value to 200, and the current value is already 200 because the model was set first: it animates from 200 to 200. In Core Animation, a missing `fromValue` means "the current value of keyPath in the target layer's presentation layer", and Apple's guide warns that if you already updated the property to its final value, "that might not yield the results you want." The fix is an explicit `fromValue = 0` with `toValue = 200`, plus `set("x", to: 200)`: it animates and stays at 200.
````

````exercise
id: m27-l02-e2
type: solve
prompt: |
  Extend `keyframeValue` to support the **discrete** calculation mode. In discrete mode the value jumps: between `keyTimes[i]` and `keyTimes[i + 1]` the value is `values[i]`, and `keyTimes` has one more entry than `values` (Apple: "if there are two values, there should be three key times"). At exactly 1.0 the value is the last value.

  Write `keyframeValue(values:keyTimes:at:discrete:)` that handles both modes, so that:

  ```swift
  let values = [0.0, 100, 50]
  for time in [0, 0.25, 0.5, 0.75, 1.0] {
      print(keyframeValue(values: values, keyTimes: [0, 0.5, 1], at: time, discrete: false),
            keyframeValue(values: values, keyTimes: [0, 0.25, 0.75, 1], at: time, discrete: true))
  }
  ```

  prints:

  ```plaintext
  0.0 0.0
  50.0 100.0
  100.0 100.0
  75.0 50.0
  50.0 50.0
  ```
starter: |
  func keyframeValue(values: [Double], keyTimes: [Double], at time: Double, discrete: Bool) -> Double {
      // your code
      0
  }
hints:
  - "For discrete, find the last key time that's less than or equal to time, but never index past the last value."
  - "Keep the linear branch from the lesson as it is."
rubric:
  - Linear mode interpolates between neighboring keyframes.
  - Discrete mode returns values[i] for keyTimes[i] <= time < keyTimes[i + 1].
  - Time 1.0 returns the last value in both modes.
  - No index goes out of range.
solution: |
  ```swift
  func keyframeValue(values: [Double], keyTimes: [Double], at time: Double, discrete: Bool) -> Double {
      if discrete {
          var index = 0
          for i in 0..<values.count where keyTimes[i] <= time {
              index = i
          }
          return values[index]
      }
      for index in 1..<keyTimes.count where time <= keyTimes[index] {
          let start = keyTimes[index - 1]
          let end = keyTimes[index]
          let fraction = end == start ? 1 : (time - start) / (end - start)
          return values[index - 1] + (values[index] - values[index - 1]) * fraction
      }
      return values[values.count - 1]
  }

  let values = [0.0, 100, 50]
  for time in [0, 0.25, 0.5, 0.75, 1.0] {
      print(keyframeValue(values: values, keyTimes: [0, 0.5, 1], at: time, discrete: false),
            keyframeValue(values: values, keyTimes: [0, 0.25, 0.75, 1], at: time, discrete: true))
  }
  ```

  ```output
  0.0 0.0
  50.0 100.0
  100.0 100.0
  75.0 50.0
  50.0 50.0
  ```

  The discrete loop only looks at the first `values.count` key times, so the extra last key time (1.0) can never produce an index past the end. At 0.25 the linear value is halfway from 0 to 100, while the discrete value has already jumped to 100; at 0.75 the discrete value jumps to 50. These outputs are whole numbers with one decimal, which `print` writes the same way on every platform.
````

````exercise
id: m27-l02-e3
type: comprehension
prompt: "A slider thumb is a CALayer moved with a CABasicAnimation on position. While it moves, taps on the thumb are ignored, but taps on the empty spot where it's heading register as hits. Why?"
choices:
  - text: "The tap is tested against the model layer, which already holds the destination. Test against presentation() while the animation runs."
    correct: true
    why: "The model holds the target value; the presentation layer holds what's on screen."
  - text: "CALayer can't be hit-tested; only views can."
    correct: false
    why: "CALayer has hitTest(_:) and contains(_:); the problem is which copy of the layer you ask."
  - text: "Animations disable hit testing until they finish."
    correct: false
    why: "Core Animation doesn't block taps; UIView.animate disables user interaction only for the animated views, and only without .allowUserInteraction."
  - text: "isRemovedOnCompletion must be false for hit testing to work during the animation."
    correct: false
    why: "That setting is about what happens after the animation ends, and keeping animations attached causes model/presentation mismatches."
solution: |
  **The tap is checked against the model.** When the animation was added, the code also set the position to the destination (correctly, so it doesn't snap back). The model layer is therefore already at the end, while the screen shows the presentation layer moving toward it. `layer.presentation()?.frame.contains(point)` tests what the user actually sees. Apple's guide limits reading the presentation tree to while an animation is in flight; outside an animation, the model is accurate.
````

````exercise
id: m27-l02-e4
type: find-errors
prompt: "A badge should fade its border color to red and stay red. Mark every real problem."
code: |
  func highlight(_ badge: UIView) {
      let animation = CABasicAnimation(keyPath: "borderColor")
      animation.toValue = UIColor.systemRed.cgColor
      animation.duration = 0.3
      animation.fillMode = .forwards
      animation.isRemovedOnCompletion = false
      badge.layer.add(animation, forKey: nil)
      badge.layer.masksToBounds = true
      badge.layer.shadowOpacity = 0.3
  }
choices:
  - text: "The model borderColor is never set to red, so the forwards fill hides a model/presentation mismatch."
    correct: true
  - text: "The animation is added with a nil key, so calling highlight again stacks animations instead of replacing one."
    correct: true
  - text: "masksToBounds = true clips the shadow this function asks for."
    correct: true
  - text: "borderColor isn't animatable; only opacity and position are."
    correct: false
    why: "Core Animation interpolates colors; Apple's CABasicAnimation page shows a backgroundColor animation, and borderColor works the same way."
  - text: "toValue must be a UIColor, not a CGColor."
    correct: false
    why: "Layer color properties are CGColor, so the animation values are CGColors too."
rubric:
  - I found the missing model update.
  - I found the nil key.
  - I found masksToBounds clipping the shadow.
solution: |
  Three problems:

  1. **No model update.** `fillMode = .forwards` with `isRemovedOnCompletion = false` makes the red stay on screen while `badge.layer.borderColor` still returns the old color. Set the model and drop the workaround.
  2. **`forKey: nil`** gives every call a new, anonymous animation, so they pile up on the layer. Use a key, so a new highlight replaces the old one.
  3. **`masksToBounds = true`** clips the shadow. Remove it, or clip an inner view.

  ```swift ios
  import UIKit

  @MainActor
  func highlight(_ badge: UIView) {
      let red = UIColor.systemRed.cgColor
      let animation = CABasicAnimation(keyPath: "borderColor")
      animation.fromValue = badge.layer.borderColor
      animation.toValue = red
      animation.duration = 0.3
      badge.layer.borderColor = red
      badge.layer.add(animation, forKey: "highlight")
      badge.layer.shadowOpacity = 0.3
  }
  ```
````

````exercise
id: m27-l02-e5
type: explain
prompt: "A teammate says: \"Core Animation is just a lower-level UIView.animate. Use whichever you like.\" They point at these two ways of fading a view. Explain where they're right and where they're wrong."
code: |
  UIView.animate(withDuration: 0.3) {
      badge.alpha = 0
  }

  let fade = CABasicAnimation(keyPath: "opacity")
  fade.fromValue = 1
  fade.toValue = 0
  fade.duration = 0.3
  badge.layer.add(fade, forKey: "fade")
rubric:
  - Notes that UIView.animate is built on Core Animation and that view properties should be animated through the view.
  - Names things only layers do - keyframes, additive animations, shape stroke, layer-only properties like cornerRadius or shadowPath.
  - Explains the model/presentation difference - UIView.animate sets the model for you, an explicit CAAnimation doesn't.
  - Mentions that UIView disables implicit layer animations outside animation blocks.
solution: |
  **Right**: `UIView.animate` creates Core Animation animations on the views' layers; it's a convenience layer on top. For properties the view exposes (`frame`, `center`, `alpha`, `transform`, `backgroundColor`), Apple recommends manipulating the view rather than its layer.

  **Wrong** in two ways:

  - **They don't cover the same things.** Only Core Animation gives you keyframe animations, additive animations (a shake that works from any position), `strokeEnd` on a shape layer, animation along a path, and animation of layer-only properties such as `cornerRadius`, `shadowOpacity` or `shadowPath`.
  - **They don't behave the same.** Inside `UIView.animate`, you assign the final value and UIKit animates to it: the model is updated for you. An explicit `CABasicAnimation` only changes what's drawn; if you don't set the property yourself, the layer snaps back when the animation is removed. And changing a view's layer property outside an animation block doesn't animate at all, because UIView disables implicit animations for its own layer, while a standalone sublayer animates implicitly unless you disable actions in a `CATransaction`.
````

## Summary

- Every iOS view is backed by a `CALayer`. Prefer the view's properties; use the layer for corners, borders, shadows, sublayers and animations UIKit can't express.
- Corners: `cornerRadius` and `cornerCurve = .continuous`; `masksToBounds` clips contents but also clips the shadow. Shadows need `shadowOpacity` above 0, and an explicit `shadowPath`, updated in `layoutSubviews()`, avoids an expensive shape computation.
- Standalone layers animate property changes implicitly; a view's own layer doesn't, outside UIView animation blocks. `CATransaction.setDisableActions(true)` stops implicit animations; `setAnimationDuration(_:)` changes their duration.
- Explicit animations (`CABasicAnimation`, `CAKeyframeAnimation`) only change the presentation. Set the model to the final value yourself, with an explicit `fromValue`, or the layer snaps back. Don't use `fillMode = .forwards` with `isRemovedOnCompletion = false` as the fix.
- `presentation()` shows in-flight values; use it, while an animation runs, to hit-test or to continue from the visible position.
- Keyframes interpolate between values at key times; `isAdditive` makes them offsets from the current value.
