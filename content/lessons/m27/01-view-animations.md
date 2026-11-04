---
id: m27-l01
title: View animations
description: Animate UIKit views the way the system does. You animate properties with UIView.animate and its options, use springs, drive an animation with your finger through UIViewPropertyAnimator, interrupt and reverse it, decide where a view ends up when an animation stops early, and swap motion for a cross-fade when the user turned on Reduce Motion.
module: m27
order: 1
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m26-l05]
objectives:
  - Animate view properties with UIView.animate(withDuration:delay:options:animations:completion:), choosing options such as allowUserInteraction and beginFromCurrentState.
  - Animate Auto Layout changes by updating constraints and calling layoutIfNeeded() inside the animation block.
  - Use spring animations with damping and bounce, and explain what the parameters change.
  - Drive, pause, scrub, reverse and finish an animation with UIViewPropertyAnimator.
  - Decide the final position of an interrupted animation with stopAnimation(_:) and finishAnimation(at:).
  - Replace movement with a cross-fade or no animation when Reduce Motion is on.
terms:
  - term: Animatable property
    definition: "A view property UIKit can interpolate between two values: frame, bounds, center, transform, alpha and backgroundColor, among others. You set the final value inside an animation block and UIKit animates from the current value."
  - term: Timing curve
    definition: "A function that maps the fraction of the duration that has passed to the fraction of the change that should be visible. Linear, ease-in, ease-out and ease-in-out are cubic Bézier curves from (0, 0) to (1, 1)."
  - term: Spring animation
    definition: "An animation whose timing follows a damped spring. A damping ratio of 1 settles without overshooting; lower values oscillate around the final value before settling."
  - term: UIViewPropertyAnimator
    definition: "A UIKit object (iOS 10) that animates view properties and lets you start, pause, scrub with fractionComplete, reverse, stop and finish the animation while it runs."
  - term: Interruptible animation
    definition: "An animation that can be paused, scrubbed or redirected while it's running, usually by a gesture, instead of always running from start to end."
  - term: Reduce Motion
    definition: "An accessibility setting for people sensitive to on-screen movement. UIAccessibility.isReduceMotionEnabled reports it; apps should replace large movement, zooms and parallax with fades or no animation."
mastery:
  - Write an animation that moves and fades a view, keeps it tappable while it runs and runs code only if it finished.
  - Animate a constraint change correctly, with layoutIfNeeded() called on the right view.
  - Build a drawer that follows a pan gesture and completes or reverses with the gesture's velocity.
  - Predict the state, on-screen value and final value of a property animator after pause, scrub, stop and finish calls.
  - Compute where an ease-in-ease-out curve is at a given fraction of its duration.
  - Make an existing animation respect Reduce Motion.
resources: [uikit-uiview, uikit-nslayoutconstraint, uikit-target-action, hig]
cards:
  - id: m27-l01-c1
    front: How do you animate an Auto Layout change?
    back: "Change the constraint (constant, isActive) first, then call layoutIfNeeded() on the superview that owns the constraints inside the animation block. The block animates the layout pass, not the constraint assignment."
  - id: m27-l01-c2
    front: What does the Bool in UIView.animate's completion mean?
    back: "Whether the animations actually finished before the handler was called. It's false when the animation was interrupted, for example by another animation of the same property or by removing the view."
  - id: m27-l01-c3
    front: When do you need UIViewPropertyAnimator instead of UIView.animate?
    back: "When the animation must be paused, scrubbed with fractionComplete, reversed with isReversed, or continued with new timing while it runs, usually because a gesture drives it."
  - id: m27-l01-c4
    front: What do stopAnimation(false) and finishAnimation(at:) do?
    back: "stopAnimation(false) removes the running animation, sets the properties to their current on-screen values and moves the animator to the stopped state. finishAnimation(at:) then runs the completion blocks with .start, .end or .current, and .start or .end set the properties to that end."
  - id: m27-l01-c5
    front: What should an animation do when Reduce Motion is on?
    back: "Replace movement, scaling and parallax with a cross-fade or with no animation, and keep the state change itself. Check UIAccessibility.isReduceMotionEnabled when you start the animation."
---

## The idea in one sentence

In UIKit you don't draw frames of an animation: you set a property to its **final value** inside an animation block, and the system interpolates from the current value over a duration, following a timing curve; everything else in this lesson is about controlling that interpolation.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target unless marked, Swift 6 mode) on the CI runner, not run. API behavior comes from Apple's reference pages for `UIView`, `UIView.AnimationOptions`, `UIViewPropertyAnimator`, `UIViewAnimating`, `UISpringTimingParameters` and `UIAccessibility`, read in November 2026. The timing-curve math and the animator model are plain Swift, compiled and run with Swift 6.3.

## What UIKit animates

Module 23 placed views with frames and constraints. Animating them means changing one of the properties UIKit knows how to interpolate:

| Property | What changes on screen |
| --- | --- |
| `frame`, `bounds`, `center` | Position and size |
| `transform` | Scale, rotation, translation, without touching `frame` |
| `alpha` | Opacity |
| `backgroundColor` | Fill color |

`isHidden` isn't in the list: it's either true or false. Fade with `alpha` instead, and set `isHidden` in the completion if you need the view gone for layout and hit testing.

## UIView.animate

A card that slides in and fades in:

```swift ios
import UIKit

@MainActor
func showCard(_ card: UIView, in container: UIView) {
    card.alpha = 0
    card.transform = CGAffineTransform(translationX: 0, y: 40)
    container.addSubview(card)

    UIView.animate(
        withDuration: 0.35,
        delay: 0,
        options: [.curveEaseOut, .allowUserInteraction],
        animations: {
            card.alpha = 1
            card.transform = .identity
        },
        completion: { finished in
            if finished {
                print("card is in place")
            }
        }
    )
}
```

Line by line:

1. **Before the block**, the card is set to its starting state (transparent, 40 points lower) without animation.
2. **Inside `animations`**, you assign final values. Apple: "This is where you programmatically change any animatable properties of the views in your view hierarchy." UIKit records the changes and animates from the old values to the new ones.
3. **`duration`** is in seconds. A duration of 0 or less makes the changes immediately, without animating.
4. **`options`** is a set. `.curveEaseOut` starts fast and slows down, which suits things arriving on screen. `.allowUserInteraction` keeps the card tappable: by default, "user interactions are temporarily disabled for the views being animated."
5. **`completion`** receives a `Bool` that "indicates whether or not the animations actually finished before the completion handler was called." When another animation takes over the same property, it's `false`.

The simpler `UIView.animate(withDuration:animations:)` uses `.curveEaseInOut`.

The options you'll use most:

| Option | Effect |
| --- | --- |
| `.curveEaseInOut` (default), `.curveEaseIn`, `.curveEaseOut`, `.curveLinear` | The timing curve |
| `.allowUserInteraction` | Animated views keep receiving touches |
| `.beginFromCurrentState` | Start from the current on-screen value of an animation already in flight |
| `.repeat`, `.autoreverse` | Loop, and play backward on every other pass |
| `.layoutSubviews` | Lay out subviews as part of the animation |

### Animating constraints

A constraint isn't a property UIKit animates. What gets animated is the **layout pass** that moves views after a constraint changes:

```swift ios
import UIKit

final class BannerViewController: UIViewController {
    private let banner = UIView()
    private var bannerTop: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        banner.backgroundColor = .systemYellow
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        bannerTop = banner.topAnchor.constraint(equalTo: view.topAnchor, constant: -80)
        NSLayoutConstraint.activate([
            bannerTop,
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: 80),
        ])
    }

    func setBannerVisible(_ visible: Bool) {
        view.layoutIfNeeded()
        bannerTop.constant = visible ? 0 : -80
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}
```

1. The first `view.layoutIfNeeded()` applies any layout that was already pending, so it doesn't get folded into this animation.
2. `bannerTop.constant` changes **outside** the block. Changing it inside works too, but the change itself is instant either way; what matters is the next line.
3. Inside the block, `layoutIfNeeded()` on **the view that contains both the banner and the constraint's other item**, here the controller's view. Calling it on `banner` alone wouldn't move the banner, because its position is decided by its superview's layout.

### Springs

A spring timing curve overshoots and settles like a physical spring. iOS 17 added a version with two parameters people can reason about:

```swift ios
import UIKit

@MainActor
func popIn(_ badge: UIView) {
    badge.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    UIView.animate(springDuration: 0.5, bounce: 0.3) {
        badge.transform = .identity
    }
}

@MainActor
func popInBeforeIOS17(_ badge: UIView) {
    badge.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    UIView.animate(
        withDuration: 0.5,
        delay: 0,
        usingSpringWithDamping: 0.6,
        initialSpringVelocity: 0,
        options: [],
        animations: { badge.transform = .identity }
    )
}
```

- `animate(springDuration:bounce:initialSpringVelocity:delay:options:animations:completion:)` is iOS 17. Every parameter but the animations has a default (duration 0.5, bounce 0). Apple's page doesn't describe `bounce` further; in practice 0 means no overshoot and larger values bounce more.
- The older `usingSpringWithDamping:` takes a **damping ratio**: "To smoothly decelerate the animation without oscillation, use a value of 1. Employ a damping ratio closer to zero to increase oscillation."
- `initialSpringVelocity` is relative to the distance: "A value of 1 corresponds to the total animation distance traversed in one second." Apple's example: a 200-point move that should start at 100 points per second uses 0.5. You'll use it when a gesture hands off to an animation.

> [!version] iOS 18: SwiftUI animations in UIKit
> iOS 18 added `UIView.animate(_:changes:completion:)`, which takes a SwiftUI `Animation`. It lets a UIKit view animate with exactly the same curve as SwiftUI code next to it:
>
> ```swift ios 18.0
> import SwiftUI
> import UIKit
>
> let dot = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
> UIView.animate(.spring(duration: 0.4)) {
>     dot.center.x = 200
> }
> ```
>
> With the course's iOS 17 target, wrap it in `if #available(iOS 18, *)`.

## Timing curves are just math

A timing curve answers one question: when 25% of the duration has passed, how much of the change should be visible? Core Animation documents its named curves as cubic Bézier curves from (0, 0) to (1, 1). Ease-in-ease-out uses the control points (0.42, 0) and (0.58, 1); ease-in uses (0.42, 0) and (1, 1). (UIKit's `UIView.AnimationCurve` pages don't list control points, so this lesson uses Core Animation's documented values.)

A Bézier curve gives x (time) and y (progress) as functions of a third parameter, so to find the progress at a given time you first find the parameter whose x matches, then read y. Bisection is enough:

```swift
struct CubicTimingCurve {
    let x1: Double, y1: Double, x2: Double, y2: Double

    // One coordinate of a cubic Bézier from (0, 0) to (1, 1) at parameter s.
    private func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
    }

    // Fraction of the change that's visible at a fraction of the duration.
    func progress(atTime time: Double) -> Double {
        var low = 0.0, high = 1.0
        for _ in 0..<50 {
            let mid = (low + high) / 2
            if bezier(mid, x1, x2) < time { low = mid } else { high = mid }
        }
        return bezier((low + high) / 2, y1, y2)
    }
}

func twoDecimals(_ value: Double) -> String {
    let hundredths = Int((value * 100).rounded())
    let fraction = hundredths % 100
    return "\(hundredths / 100)." + (fraction < 10 ? "0" : "") + "\(fraction)"
}

let linear = CubicTimingCurve(x1: 0, y1: 0, x2: 1, y2: 1)
let easeIn = CubicTimingCurve(x1: 0.42, y1: 0, x2: 1, y2: 1)
let easeInEaseOut = CubicTimingCurve(x1: 0.42, y1: 0, x2: 0.58, y2: 1)

print("time  linear  easeIn  easeInOut")
for step in 0...4 {
    let t = Double(step) / 4
    print(twoDecimals(t), " ", twoDecimals(linear.progress(atTime: t)), "  ",
          twoDecimals(easeIn.progress(atTime: t)), "  ", twoDecimals(easeInEaseOut.progress(atTime: t)))
}

let from = 20.0, to = 220.0
let progress = easeInEaseOut.progress(atTime: 0.25)
print("x at 25% of the time:", twoDecimals(from + (to - from) * progress))
```

```output
time  linear  easeIn  easeInOut
0.00   0.00    0.00    0.00
0.25   0.25    0.09    0.13
0.50   0.50    0.32    0.50
0.75   0.75    0.62    0.87
1.00   1.00    1.00    1.00
x at 25% of the time: 45.83
```

- **Linear** shows exactly as much change as time passed. It looks mechanical for movement, which is why it isn't the default.
- **Ease-in** has covered only 9% of the distance after a quarter of the time, and makes up for it at the end: good for things leaving the screen, which accelerate away.
- **Ease-in-ease-out** is symmetric, slow at both ends: 13% at a quarter, half at half time.
- The last line is what UIKit does for each frame: `from + (to − from) × progress`. A view moving from x = 20 to x = 220 is at 45.83 after a quarter of the duration.

`twoDecimals` formats the numbers by hand so the output doesn't depend on how a platform prints a `Double`.

## UIViewPropertyAnimator

`UIView.animate` starts an animation and lets it run. `UIViewPropertyAnimator` (iOS 10) is an **object** that holds the animation, so you can keep a reference and act on it while it runs. Apple lists what that gives you: start, pause, resume and stop; add animations after starting; "Scrub through a paused animation by modifying the fractionComplete property"; "Change the animation's direction using the isReversed property"; and change the timing of a partially complete animation with `continueAnimation(withTimingParameters:durationFactor:)`.

The simplest use is a one-shot animation, like `UIView.animate`:

```swift ios
import UIKit

@MainActor
func fadeOut(_ view: UIView) {
    UIViewPropertyAnimator.runningPropertyAnimator(
        withDuration: 0.25,
        delay: 0,
        options: [],
        animations: { view.alpha = 0 },
        completion: { position in
            if position == .end {
                view.isHidden = true
            }
        }
    )
}
```

`runningPropertyAnimator` starts immediately and uses `.curveEaseInOut` unless you pass a curve. The completion gets a `UIViewAnimatingPosition` instead of a `Bool`: `.end`, `.start` (it was reversed) or `.current` (it was stopped somewhere in between).

The animators you create with an initializer start **inactive** and do nothing until you call `startAnimation()`:

| Initializer | Timing |
| --- | --- |
| `init(duration:curve:animations:)` | A UIKit curve: `.easeInOut`, `.easeIn`, `.easeOut`, `.linear` |
| `init(duration:controlPoint1:controlPoint2:animations:)` | Your own cubic Bézier |
| `init(duration:dampingRatio:animations:)` | A spring; 1 settles without oscillating |
| `init(duration:timingParameters:)` | A `UICubicTimingParameters` or `UISpringTimingParameters` object |

### The animator's states

`UIViewAnimating`, the protocol the animator adopts, defines three states:

```plaintext
            startAnimation() / pauseAnimation()
 inactive ─────────────────────────────────────▶ active (running or paused)
    ▲                                              │        │
    │  finishes on its own, or stopAnimation(true) │        │ stopAnimation(false)
    └──────────────────────────────────────────────┘        ▼
    ◀──────────────────── finishAnimation(at:) ─────── stopped
```

- **inactive**: the starting state, and where it returns after the animations run to their end.
- **active**: running, or paused. `fractionComplete` can be set only while paused: "You can update the value of this property only while the animator is paused."
- **stopped**: after `stopAnimation(false)`. Apple: the method "removes all of the associated animations from the execution stack and sets the values of any animatable properties to their current values." Calling `finishAnimation(at:)` then runs the completion blocks. Calling `finishAnimation(at:)` in any other state is, in Apple's words, "a programmer error".

`stopAnimation(true)` goes straight to inactive and **skips** the completion blocks.

### A model of the animator

The rules are easy to get wrong under pressure, so here they are as a plain-Swift model. It's linear and has no clock, but the states, the values and the completion calls follow Apple's descriptions:

```swift
enum AnimatorState { case inactive, active, stopped }
enum Position { case start, end, current }

final class AnimatorModel {
    let from: Int
    let to: Int
    private(set) var state = AnimatorState.inactive
    private(set) var isRunning = false
    private(set) var modelValue: Int
    private var fraction = 0.0
    private var completions: [(Position) -> Void] = []

    init(from: Int, to: Int) {
        self.from = from
        self.to = to
        modelValue = from
    }

    var onScreen: Int {
        state == .active ? from + Int((Double(to - from) * fraction).rounded()) : modelValue
    }

    var fractionComplete: Double {
        get { fraction }
        set {
            guard state == .active, !isRunning else {
                print("ignored: fractionComplete can only change while paused")
                return
            }
            fraction = newValue
        }
    }

    func addCompletion(_ completion: @escaping (Position) -> Void) {
        completions.append(completion)
    }

    func startAnimation() {
        guard state != .stopped else { return }
        state = .active
        isRunning = true
        modelValue = to
    }

    func pauseAnimation() {
        guard state != .stopped else { return }
        state = .active
        isRunning = false
        modelValue = to
    }

    // Simulates time passing while the animation runs.
    func advance(by amount: Double) {
        guard state == .active, isRunning else { return }
        fraction = min(1, fraction + amount)
        if fraction == 1 {
            state = .inactive
            isRunning = false
            completions.forEach { $0(.end) }
        }
    }

    func stopAnimation(_ withoutFinishing: Bool) {
        guard state == .active else { return }
        modelValue = onScreen
        isRunning = false
        state = withoutFinishing ? .inactive : .stopped
    }

    func finishAnimation(at position: Position) {
        guard state == .stopped else {
            print("programmer error: finishAnimation outside the stopped state")
            return
        }
        switch position {
        case .start: modelValue = from
        case .end: modelValue = to
        case .current: break
        }
        state = .inactive
        completions.forEach { $0(position) }
    }

    func report() -> String {
        "\(state)\(isRunning ? ", running" : ""), on screen \(onScreen), model \(modelValue)"
    }
}

let animator = AnimatorModel(from: 0, to: 300)
animator.addCompletion { print("completion: \($0)") }
print(animator.report())
animator.startAnimation()
animator.advance(by: 0.4)
print(animator.report())
animator.pauseAnimation()
animator.fractionComplete = 0.7
print(animator.report())
animator.stopAnimation(false)
print(animator.report())
animator.finishAnimation(at: .current)
print(animator.report())
```

```output
inactive, on screen 0, model 0
active, running, on screen 120, model 300
active, on screen 210, model 300
stopped, on screen 210, model 210
completion: current
inactive, on screen 210, model 210
```

Read it as a timeline:

1. **Inactive**, nothing has happened; the view is at 0.
2. **`startAnimation()`**, then 40% of the time passes. The view is drawn at 120, but the property already holds **300**. In UIKit, too, the animation block sets the final value immediately; what you see is an in-between rendering. Lesson 2 calls these the model and presentation values.
3. **Paused and scrubbed** to 0.7: the view is drawn at 210. This is what a pan gesture does on every move.
4. **`stopAnimation(false)`** freezes the property at its on-screen value: the model becomes 210. The state is `stopped` and the completion hasn't run.
5. **`finishAnimation(at: .current)`** runs the completion with `.current` and leaves the value at 210. With `.end` it would jump to 300; with `.start`, back to 0.

## Interactive: a drawer that follows your finger

This is the case `UIViewPropertyAnimator` was made for. A drawer slides up from the bottom; a pan gesture (lesson 3 covers gestures in depth) scrubs the animation, and when the finger lifts, the animation continues in the direction the finger was moving, or reverses:

```swift ios
import UIKit

final class DrawerViewController: UIViewController {
    private let drawer = UIView()
    private let closedOffset: CGFloat = 300
    private var isOpen = false
    private var animator: UIViewPropertyAnimator?
    private var fractionAtStart: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        drawer.backgroundColor = .secondarySystemBackground
        drawer.layer.cornerRadius = 16
        drawer.frame = CGRect(x: 0, y: 200, width: 390, height: 400)
        drawer.transform = CGAffineTransform(translationX: 0, y: closedOffset)
        view.addSubview(drawer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        drawer.addGestureRecognizer(pan)
    }

    private func makeAnimator() -> UIViewPropertyAnimator {
        let target = isOpen ? CGAffineTransform(translationX: 0, y: closedOffset) : .identity
        let animator = UIViewPropertyAnimator(duration: 0.4, dampingRatio: 1) {
            self.drawer.transform = target
        }
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            if position == .end {
                isOpen.toggle()
            }
            self.animator = nil
        }
        return animator
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let distance = pan.translation(in: view).y
        let fraction = (isOpen ? distance : -distance) / closedOffset

        switch pan.state {
        case .began:
            let animator = animator ?? makeAnimator()
            animator.pauseAnimation()
            fractionAtStart = animator.fractionComplete
            self.animator = animator
        case .changed:
            animator?.fractionComplete = min(max(fractionAtStart + fraction, 0), 1)
        case .ended, .cancelled:
            guard let animator else { return }
            let velocity = pan.velocity(in: view).y
            let movingTowardTarget = isOpen ? velocity > 0 : velocity < 0
            let isFlick = abs(velocity) > 300
            let shouldComplete = isFlick ? movingTowardTarget : animator.fractionComplete > 0.5
            animator.isReversed = !shouldComplete
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        default:
            break
        }
    }
}
```

What's happening:

- **`.began`** reuses a running animator if there is one and remembers where it was. That's what makes the animation **interruptible**: grab the drawer while it's still moving and it stops under your finger, instead of jumping to the start of a new animation.
- **`pauseAnimation()`** moves an inactive animator to active and paused. Apple: "Calling this method on an inactive animator moves its state to UIViewAnimatingState.active and puts its animations in a paused state right away."
- **`.changed`** adds the finger's travel, as a fraction of the full distance, to the fraction the animation had when the finger landed, clamped to 0…1. The translation is the total since the gesture began, so you compute from it each time.
- **`.ended`** decides the direction. A flick (here, faster than 300 points per second, a value you'd tune by feel) goes the way the finger was moving; a slow release goes to whichever end is closer. `isReversed = true` sends it back. Then **`continueAnimation(withTimingParameters:durationFactor:)`** resumes it; `nil` keeps the spring timing, and a duration factor of 0 keeps the original duration.
- The completion receives `.end` if the drawer reached the target and `.start` if it was reversed, so `isOpen` only toggles when the drawer really moved.

## Reduce Motion

Some people get dizzy or nauseous from movement on screen. The Human Interface Guidelines say that when Reduce Motion is on, your app should respond "by reducing automatic and repetitive animations, including zooming, scaling, and peripheral motion", and list practices such as "Tightening animation springs to reduce bounce effects", "Tracking animations directly with people's gestures" and "Replacing transitions in x-, y-, and z-axes with fades to avoid motion". The state change still has to be visible; it's the movement that goes:

```swift ios
import UIKit

@MainActor
func presentToast(_ toast: UIView, in container: UIView) {
    container.addSubview(toast)

    if UIAccessibility.isReduceMotionEnabled {
        toast.alpha = 0
        UIView.animate(withDuration: 0.2) {
            toast.alpha = 1
        }
    } else {
        toast.transform = CGAffineTransform(translationX: 0, y: 80)
        UIView.animate(springDuration: 0.5, bounce: 0.25) {
            toast.transform = .identity
        }
    }
}
```

- **`UIAccessibility.isReduceMotionEnabled`** is a main-actor property: "A Boolean value that indicates whether the Reduce Motion setting is in an enabled state." Check it each time you animate rather than once at launch; people change it while apps are running.
- If something on screen is already moving when the setting changes (a looping background animation), observe `UIAccessibility.reduceMotionStatusDidChangeNotification` and stop it.
- **`UIAccessibility.prefersCrossFadeTransitions`** is true when Reduce Motion **and** Prefer Cross-Fade Transitions are both on. Use it for screen transitions you build yourself.
- Lesson 6 covers the rest of the visual accessibility settings.

## Common mistakes

> [!error] Calling layoutIfNeeded() on the view whose constraint changed
> `banner.layoutIfNeeded()` doesn't move the banner, because the banner's frame is set by its superview's layout. Call it on the common ancestor, usually `view`, inside the animation block.

> [!error] Animating isHidden
> `isHidden` has no in-between value, so it changes at once. Animate `alpha` to 0 and set `isHidden = true` in the completion, only if `finished` is true.

> [!error] Treating the completion's Bool as "it ended"
> `finished` is `false` when another animation interrupted this one. Code that removes a view or changes state there should check it, or a quick double tap leaves the view removed mid-animation.

> [!error] A gesture that starts a new animator every time
> Creating a fresh `UIViewPropertyAnimator` in `.began` while the old one is still running makes the view jump. Keep the animator in a property and reuse it if it exists; that's what makes the animation interruptible.

> [!error] Setting fractionComplete on a running animator
> Apple: the value can be updated "only while the animator is paused". Call `pauseAnimation()` first, in `.began`.

> [!error] Calling finishAnimation(at:) without stopAnimation(false)
> Apple calls that "a programmer error". `finishAnimation(at:)` is only for an animator in the stopped state.

> [!error] Ignoring Reduce Motion
> A full-screen zoom or a parallax background with no alternative can make the app unusable for some people. Check `UIAccessibility.isReduceMotionEnabled` and fade instead.

## Exercises

````exercise
id: m27-l01-e1
type: prediction
prompt: "Using the same animator model as the lesson (repeated here so it compiles on its own), what does this print?"
code: |
  enum AnimatorState { case inactive, active, stopped }
  enum Position { case start, end, current }

  final class AnimatorModel {
      let from: Int
      let to: Int
      private(set) var state = AnimatorState.inactive
      private(set) var isRunning = false
      private(set) var modelValue: Int
      private var fraction = 0.0
      private var completions: [(Position) -> Void] = []

      init(from: Int, to: Int) {
          self.from = from
          self.to = to
          modelValue = from
      }

      var onScreen: Int {
          state == .active ? from + Int((Double(to - from) * fraction).rounded()) : modelValue
      }

      var fractionComplete: Double {
          get { fraction }
          set {
              guard state == .active, !isRunning else {
                  print("ignored: fractionComplete can only change while paused")
                  return
              }
              fraction = newValue
          }
      }

      func addCompletion(_ completion: @escaping (Position) -> Void) {
          completions.append(completion)
      }

      func startAnimation() {
          guard state != .stopped else { return }
          state = .active
          isRunning = true
          modelValue = to
      }

      func pauseAnimation() {
          guard state != .stopped else { return }
          state = .active
          isRunning = false
          modelValue = to
      }

      func advance(by amount: Double) {
          guard state == .active, isRunning else { return }
          fraction = min(1, fraction + amount)
          if fraction == 1 {
              state = .inactive
              isRunning = false
              completions.forEach { $0(.end) }
          }
      }

      func stopAnimation(_ withoutFinishing: Bool) {
          guard state == .active else { return }
          modelValue = onScreen
          isRunning = false
          state = withoutFinishing ? .inactive : .stopped
      }

      func finishAnimation(at position: Position) {
          guard state == .stopped else {
              print("programmer error: finishAnimation outside the stopped state")
              return
          }
          switch position {
          case .start: modelValue = from
          case .end: modelValue = to
          case .current: break
          }
          state = .inactive
          completions.forEach { $0(position) }
      }

      func report() -> String {
          "\(state)\(isRunning ? ", running" : ""), on screen \(onScreen), model \(modelValue)"
      }
  }

  let fade = AnimatorModel(from: 100, to: 0)
  fade.addCompletion { print("done at \($0)") }
  fade.startAnimation()
  fade.fractionComplete = 0.5
  fade.advance(by: 0.25)
  print(fade.report())
  fade.stopAnimation(true)
  print(fade.report())
  fade.finishAnimation(at: .end)
output: |
  ignored: fractionComplete can only change while paused
  active, running, on screen 75, model 0
  inactive, on screen 75, model 75
  programmer error: finishAnimation outside the stopped state
hints:
  - "Is the animator paused when fractionComplete is set?"
  - "stopAnimation(true) skips the stopped state."
solution: |
  ```output
  ignored: fractionComplete can only change while paused
  active, running, on screen 75, model 0
  inactive, on screen 75, model 75
  programmer error: finishAnimation outside the stopped state
  ```

  1. `fractionComplete = 0.5` on a **running** animator is ignored. Apple allows it only while paused.
  2. A quarter of the time passes: on screen 100 + (0 − 100) × 0.25 = 75, while the model already holds the final value, 0.
  3. `stopAnimation(true)` freezes the property at 75 and goes **straight to inactive**, without running completions.
  4. `finishAnimation(at:)` is then called outside the stopped state, which Apple calls a programmer error. "done at …" never prints: `stopAnimation(true)` skipped the completion blocks for good.
````

````exercise
id: m27-l01-e2
type: comprehension
prompt: "A settings screen expands a section by changing a height constraint from 0 to 120. The section jumps to its new height instead of animating. What's the fix?"
code: |
  UIView.animate(withDuration: 0.3) {
      self.sectionHeight.constant = 120
  }
choices:
  - text: "Keep the constant change, and call self.view.layoutIfNeeded() inside the animation block."
    correct: true
    why: "The block has to contain the layout pass that moves the views. Changing a constant only marks the layout as needing an update."
  - text: "Use UIView.animate(withDuration:delay:options:) with .layoutSubviews and nothing else."
    correct: false
    why: "That option lays out subviews of views being animated; nothing is being animated here, because no layout pass happens in the block."
  - text: "Animate the section's frame instead and leave the constraint at 0."
    correct: false
    why: "Auto Layout would put the frame back on the next layout pass, because the constraint still says 0."
  - text: "Use a UIViewPropertyAnimator; UIView.animate can't animate constraints."
    correct: false
    why: "A property animator has the same requirement: it animates the layout pass you trigger inside the block."
solution: |
  **Call `layoutIfNeeded()` on the common ancestor inside the block.** A constraint isn't an animatable property. Setting `constant` marks the layout as dirty; the views only move during the next layout pass. If that pass happens later, outside the block, it isn't animated. `self.view.layoutIfNeeded()` inside the block runs the layout pass right there, and UIKit animates the frame changes it produces. Calling `view.layoutIfNeeded()` once before changing the constant keeps unrelated pending layout out of the animation.
````

````exercise
id: m27-l01-e3
type: solve
prompt: |
  Extend the timing-curve code into a function that returns the position of a view for each frame of an animation. Write `framePositions(from:to:duration:framesPerSecond:curve:)` that returns one position per frame, from frame 0 (time 0) to the last frame (time = duration), rounded to the nearest whole point. Use the lesson's `CubicTimingCurve`.

  ```swift
  let easeOut = CubicTimingCurve(x1: 0, y1: 0, x2: 0.58, y2: 1)
  print(framePositions(from: 0, to: 100, duration: 0.1, framesPerSecond: 60, curve: easeOut))
  let linear = CubicTimingCurve(x1: 0, y1: 0, x2: 1, y2: 1)
  print(framePositions(from: 50, to: 10, duration: 0.05, framesPerSecond: 60, curve: linear))
  ```

  should print:

  ```plaintext
  [0, 26, 49, 68, 84, 96, 100]
  [50, 37, 23, 10]
  ```

  Ease-out uses Core Animation's documented control points (0, 0) and (0.58, 1).
starter: |
  struct CubicTimingCurve {
      let x1: Double, y1: Double, x2: Double, y2: Double

      private func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
          let u = 1 - s
          return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
      }

      func progress(atTime time: Double) -> Double {
          var low = 0.0, high = 1.0
          for _ in 0..<50 {
              let mid = (low + high) / 2
              if bezier(mid, x1, x2) < time { low = mid } else { high = mid }
          }
          return bezier((low + high) / 2, y1, y2)
      }
  }

  func framePositions(from: Double, to: Double, duration: Double, framesPerSecond: Int, curve: CubicTimingCurve) -> [Int] {
      // your code
      []
  }
hints:
  - "The number of frames after frame 0 is duration × framesPerSecond, rounded."
  - "The time fraction for frame i is i divided by that number."
  - "Position = from + (to − from) × progress."
rubric:
  - The first position is from and the last is to.
  - The frame count comes from duration × framesPerSecond, rounded, not truncated.
  - Positions use the curve's progress, not the time fraction directly.
  - Works when to is smaller than from.
solution: |
  ```swift
  struct CubicTimingCurve {
      let x1: Double, y1: Double, x2: Double, y2: Double

      private func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
          let u = 1 - s
          return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
      }

      func progress(atTime time: Double) -> Double {
          var low = 0.0, high = 1.0
          for _ in 0..<50 {
              let mid = (low + high) / 2
              if bezier(mid, x1, x2) < time { low = mid } else { high = mid }
          }
          return bezier((low + high) / 2, y1, y2)
      }
  }

  func framePositions(from: Double, to: Double, duration: Double, framesPerSecond: Int, curve: CubicTimingCurve) -> [Int] {
      let frames = Int((duration * Double(framesPerSecond)).rounded())
      var positions: [Int] = []
      for frame in 0...frames {
          let time = Double(frame) / Double(frames)
          let value = from + (to - from) * curve.progress(atTime: time)
          positions.append(Int(value.rounded()))
      }
      return positions
  }

  let easeOut = CubicTimingCurve(x1: 0, y1: 0, x2: 0.58, y2: 1)
  print(framePositions(from: 0, to: 100, duration: 0.1, framesPerSecond: 60, curve: easeOut))
  let linear = CubicTimingCurve(x1: 0, y1: 0, x2: 1, y2: 1)
  print(framePositions(from: 50, to: 10, duration: 0.05, framesPerSecond: 60, curve: linear))
  ```

  ```output
  [0, 26, 49, 68, 84, 96, 100]
  [50, 37, 23, 10]
  ```

  The frame count is rounded, not truncated with `Int(...)` alone, because a product that should be a whole number can land just below it in floating point: `1.025 * 120.0` is 122.99999999999999, which `Int` truncates to 122. The ease-out list shows the curve's shape: 26 points in the first frame, 4 in the last. At 120 frames per second the same animation would have twice as many entries; the curve is the same, only sampled more often.
````

````exercise
id: m27-l01-e4
type: find-errors
prompt: "This card dismisses with a swipe. Testers report that the card sometimes vanishes in the middle of a second swipe, that it can't be tapped while it animates, and that people with Reduce Motion still see it fly off. Mark every real problem."
code: |
  func dismissCard() {
      UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseIn], animations: {
          self.card.transform = CGAffineTransform(translationX: 500, y: 0)
          self.card.isHidden = true
      }, completion: { _ in
          self.card.removeFromSuperview()
      })
  }
choices:
  - text: "The completion removes the card without checking finished, so an interrupted animation still removes it."
    correct: true
  - text: "Without .allowUserInteraction, the card doesn't receive touches while it animates."
    correct: true
  - text: "isHidden inside the block isn't animated; the card disappears at the start instead of sliding off."
    correct: true
  - text: "There's no Reduce Motion check, so the slide always runs."
    correct: true
  - text: ".curveEaseIn is wrong for something leaving the screen; it must be .curveEaseOut."
    correct: false
    why: "Ease-in suits views leaving the screen: they start slowly and accelerate away. It's a design choice, not a bug."
  - text: "UIView.animate can't animate transform; it needs a UIViewPropertyAnimator."
    correct: false
    why: "transform is one of the properties UIView.animate animates."
rubric:
  - I found the unchecked finished flag.
  - I found the missing allowUserInteraction.
  - I found isHidden inside the animation block.
  - I found the missing Reduce Motion alternative.
solution: |
  Four real problems:

  1. **`finished` ignored.** If a second gesture starts another animation of `transform`, this one ends with `finished == false` and still removes the card.
  2. **No `.allowUserInteraction`.** UIKit disables interaction with views while they animate unless you pass it.
  3. **`isHidden` in the block** takes effect at once, so the card blinks out instead of sliding. Fade `alpha` if you want it to fade, and hide or remove it in the completion.
  4. **No Reduce Motion path.**

  ```swift ios
  import UIKit

  final class CardViewController: UIViewController {
      private let card = UIView()

      func dismissCard() {
          let reduceMotion = UIAccessibility.isReduceMotionEnabled
          UIView.animate(
              withDuration: reduceMotion ? 0.2 : 0.4,
              delay: 0,
              options: [.curveEaseIn, .allowUserInteraction],
              animations: {
                  if reduceMotion {
                      self.card.alpha = 0
                  } else {
                      self.card.transform = CGAffineTransform(translationX: 500, y: 0)
                  }
              },
              completion: { finished in
                  guard finished else { return }
                  self.card.removeFromSuperview()
              }
          )
      }
  }
  ```
````

````exercise
id: m27-l01-e5
type: fill-in
prompt: "Complete the pan handler so the gesture scrubs a paused animator and, on release, continues it with the same timing."
code: |
  @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
      switch pan.state {
      case .began:
          let animator = self.animator ?? makeAnimator()
          animator.[[1]]()
          self.animator = animator
      case .changed:
          let fraction = -pan.translation(in: view).y / 300
          animator?.[[2]] = min(max(fraction, 0), 1)
      case .ended:
          animator?.continueAnimation(withTimingParameters: [[3]], durationFactor: 0)
      default:
          break
      }
  }
blanks:
  - id: "1"
    answers: ["pauseAnimation"]
  - id: "2"
    answers: ["fractionComplete"]
  - id: "3"
    answers: ["nil"]
hints:
  - "fractionComplete can only be set while the animator is paused."
  - "Passing no new timing parameters keeps the original ones."
solution: |
  1. **`pauseAnimation`** moves an inactive animator to active and paused (or pauses a running one), so `fractionComplete` can be set.
  2. **`fractionComplete`** scrubs the animation to a point between 0 and 1.
  3. **`nil`** keeps the animator's original timing; a `durationFactor` of 0 keeps its original duration. Pass a `UISpringTimingParameters` with an initial velocity instead if you want the release to carry the finger's speed.
````

````exercise
id: m27-l01-e6
type: design
prompt: "A photo app zooms a thumbnail into a full-screen photo: the thumbnail grows from its cell to fill the screen while the background darkens. Design the animation: what you animate and with what, how a swipe down can interrupt and reverse it, and what changes with Reduce Motion. Write a short plan, not code."
rubric:
  - Animates transform or frame of a snapshot or image view, and alpha of a dimming view, with one animator.
  - Uses UIViewPropertyAnimator so a pan can pause, scrub and reverse it, reusing the running animator.
  - Decides completion or reversal from velocity and fraction on release.
  - Keeps the final state consistent in the completion (.end vs .start).
  - Replaces the zoom with a cross-fade when Reduce Motion is on.
solution: |
  A plan that works:

  - **What moves.** An image view showing the photo starts at the thumbnail's frame, converted to the container's coordinates, and animates to the full-screen frame. A black dimming view behind it animates `alpha` from 0 to 1. Both changes go in **one** `UIViewPropertyAnimator` with a spring (damping ratio near 1, so a photo doesn't wobble), so they stay in sync.
  - **Interruption.** Keep the animator in a property. A swipe-down pan on the full-screen photo, in `.began`, reuses the running animator (or creates the dismissal animator), pauses it, and sets `isReversed` if it was still opening. In `.changed`, the vertical translation over the screen height becomes `fractionComplete`.
  - **Release.** Use the pan's velocity and the fraction: fast or far enough means finish, otherwise reverse. `continueAnimation(withTimingParameters:durationFactor:)` resumes it.
  - **Final state.** The completion receives `.end` or `.start`. Only `.end` removes the full-screen view or marks the photo as open; `.start` restores the thumbnail.
  - **Reduce Motion.** Skip the zoom: cross-fade the full-screen photo and the dimming view in with `alpha` over a short duration. If `UIAccessibility.prefersCrossFadeTransitions` is true, use the same fade for the dismissal.
````

## Summary

- Set final values of animatable properties (`frame`, `center`, `transform`, `alpha`, `backgroundColor`) inside an animation block; UIKit animates from the current values.
- Options set the curve, keep views interactive (`.allowUserInteraction`) and start from the in-flight value (`.beginFromCurrentState`). The completion's `Bool` says whether the animation actually finished.
- Animate constraints by changing them and calling `layoutIfNeeded()` on the common ancestor inside the block.
- Springs: `animate(springDuration:bounce:)` on iOS 17, or a damping ratio where 1 means no oscillation.
- Timing curves are cubic Béziers from (0, 0) to (1, 1); the position at each frame is `from + (to − from) × progress`.
- `UIViewPropertyAnimator` is an object you keep: pause it, scrub `fractionComplete`, flip `isReversed`, `continueAnimation`, or `stopAnimation(false)` followed by `finishAnimation(at:)`. Its completion reports `.end`, `.start` or `.current`.
- When Reduce Motion is on, keep the state change but replace movement with a fade or nothing.
