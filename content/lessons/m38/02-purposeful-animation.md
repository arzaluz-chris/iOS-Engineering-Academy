---
id: m38-l02
title: Purposeful animation
description: "Module 35 showed how SwiftUI animates. This lesson is about what to animate and why. You read a spring's duration and bounce as physics, run multi-step effects with phaseAnimator and keyframeAnimator (iOS 17), drive animation from state that means something to the user, add haptics with sensoryFeedback, and keep every effect honest under Reduce Motion."
module: m38
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l01, m35-l06]
objectives:
  - Choose spring parameters (duration and bounce) for a given purpose and relate them to stiffness, damping and overshoot.
  - Run a multi-step effect with phaseAnimator and explain how a trigger walks through the phases.
  - Animate several properties on independent timelines with keyframeAnimator and KeyframeTrack.
  - Derive animation and feedback from domain state transitions instead of decorating views.
  - Play haptics with sensoryFeedback, conditionally, for outcomes that matter.
  - Make phase, keyframe and haptic feedback respect Reduce Motion without losing the information they carry.
terms:
  - term: Spring
    definition: "SwiftUI's Spring type (iOS 17) describes motion toward a target with a duration and a bounce, or equivalently with mass, stiffness and damping. Animation.spring(duration:bounce:) and the .smooth, .snappy and .bouncy presets are springs."
  - term: Bounce
    definition: "How much a spring overshoots its target. 0 is critically damped (no overshoot), positive values up to 1 overshoot more, and negative values down to −1 are overdamped."
  - term: phaseAnimator
    definition: "A modifier (iOS 17) that animates a view through a sequence of phases you provide, either continuously or once per change of a trigger value, returning to the first phase at the end."
  - term: keyframeAnimator
    definition: "A modifier (iOS 17) that animates a value you define along keyframe tracks, one track per property, each with its own timing. It plays when a trigger changes or repeats."
  - term: sensoryFeedback
    definition: "A modifier (iOS 17) that plays haptic and/or audio feedback (success, warning, error, selection, impact…) when a trigger value changes, optionally only when a condition on the old and new values holds."
mastery:
  - Pick a spring for a toggle, a sheet and a playful confirmation, and say what the bounce does in each.
  - Convert a spring's duration and bounce into stiffness and damping, and estimate its overshoot.
  - Write a phaseAnimator for a "added to cart" pop that plays once per tap.
  - Write a keyframeAnimator that shakes a field on a failed submission, with scale and offset on separate tracks.
  - Play a success haptic only when a save actually succeeds.
  - Turn a decorative bounce off under Reduce Motion while keeping its information.
resources: [swiftui-spring, swiftui-phaseanimator, swiftui-sensoryfeedback, hig-playing-haptics, swiftui-withanimation, uikit-reduce-motion, hig, swift-book-enumerations]
cards:
  - id: m38-l02-c1
    front: What do a spring's duration and bounce mean?
    back: "Duration is the pace: roughly how long it takes to settle (for very bouncy springs, the period of oscillation). Bounce is overshoot: 0 means none (critically damped), up to 1 is more bouncy, negative values are overdamped. Spring(duration: 0.5, bounce: 0.3) equals mass 1, stiffness ≈ 157.9, damping ≈ 17.6."
  - id: m38-l02-c2
    front: phaseAnimator with a trigger, in one sentence?
    back: "When the trigger value changes, SwiftUI animates the content from the first phase through each following phase and back to the first, using the animation you return for each phase."
  - id: m38-l02-c3
    front: When keyframeAnimator instead of phaseAnimator?
    back: "When properties need independent timing: each KeyframeTrack animates one property of your value with its own keyframes (linear, spring, cubic, move). phaseAnimator moves all properties together from one phase to the next."
  - id: m38-l02-c4
    front: How do you play a success haptic only on success?
    back: ".sensoryFeedback(.success, trigger: status) { _, new in new == .saved }. The condition receives the old and new trigger values; without it, feedback plays on every change, including saving → failed."
  - id: m38-l02-c5
    front: How do you keep a keyframe bounce from playing under Reduce Motion?
    back: "Make the trigger not change: trigger: reduceMotion ? 0 : bounceCount. Keep the information another way (the badge count still changes, a haptic can still play). Remove repeating decoration entirely."
---

## The idea in one sentence

Animate **to explain a change** (where something came from, what just happened, whether it worked), and let the state that carries that meaning drive the animation, the haptic and the Reduce Motion fallback together.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so no animation here was watched on a device. Behavior comes from Apple's pages for `Spring`, `spring(duration:bounce:blendDuration:)`, `phaseAnimator(_:trigger:content:animation:)`, `PhaseAnimator`, `keyframeAnimator(initialValue:trigger:content:keyframes:)`, `KeyframeTrack`, `KeyframeTimeline`, `SpringKeyframe`, `LinearKeyframe`, `CubicKeyframe`, `sensoryFeedback(_:trigger:)`, `sensoryFeedback(_:trigger:condition:)`, `SensoryFeedback` and `accessibilityReduceMotion`, read in November 2026. The spring, keyframe, phase and feedback models are plain Swift, compiled and run with Swift 6.3. They're models of the documented behavior, not SwiftUI's code. `withAnimation`, `animation(_:value:)`, transitions and the basics of Reduce Motion are in Module 35, lesson 6.

## What makes an animation purposeful

Every animation costs the user a few hundred milliseconds of waiting. It pays that back when it answers a question they'd otherwise have to work out:

- **Where did that come from?** A sheet slides up from the button that opened it; a chip moves from one row to another (`matchedGeometryEffect`).
- **What changed?** A count ticks up digit by digit; a progress ring fills to the new value.
- **Did it work?** A checkmark pops on save; a field shakes on a wrong password.
- **Can I do something here?** A card lifts when picked up (lesson 1's long press then drag).

An animation that answers none of these is decoration. Decoration isn't forbidden, but it's the first thing to cut under Reduce Motion, and it should never delay the user.

## Springs as physics

Module 35 listed SwiftUI's springs: `.spring(duration:bounce:)` and the presets `.smooth`, `.snappy` and `.bouncy`. iOS 17 added a `Spring` type that describes the same motion and converts between parameterizations. Apple's own example on the `Spring` page:

```swift ios
import SwiftUI

let spring = Spring(duration: 0.5, bounce: 0.3)
let (mass, stiffness, damping) = (spring.mass, spring.stiffness, spring.damping)
// (1.0, 157.9, 17.6)

let spring2 = Spring(mass: 1, stiffness: 100, damping: 10)
let (duration, bounce) = (spring2.duration, spring2.bounce)
// (0.63, 0.5)
```

(That block is type-checked, not run; the values in the comments are Apple's.) The parameters, from `init(duration:bounce:)`:

- **`duration`** "defines the pace of the spring. This is approximately equal to the settling duration, but for springs with very large bounce values, will be the duration of the period of oscillation."
- **`bounce`**: "A value of 0 indicates no bounces (a critically damped spring), positive values indicate increasing amounts of bounciness up to a maximum of 1.0 (corresponding to undamped oscillation), and negative values indicate overdamped springs with a minimum value of -1.0."

Behind those two numbers is a mass on a spring with friction. The standard damped-oscillator formulas reproduce Apple's numbers exactly, which is a good sign they're the same model:

```swift
import Foundation

/// A spring described like Spring(duration:bounce:), for bounce from 0 to 1.
struct SpringModel {
    var duration: Double
    var bounce: Double
    var mass = 1.0

    var stiffness: Double { mass * pow(2 * Double.pi / duration, 2) }
    var damping: Double { mass * 4 * Double.pi * (1 - bounce) / duration }
    var dampingRatio: Double { 1 - bounce }

    /// Progress from the start (0) toward the target (1) at time t, starting at rest.
    func position(at t: Double) -> Double {
        let omega = 2 * Double.pi / duration
        let zeta = dampingRatio
        if zeta >= 1 {
            return 1 - exp(-omega * t) * (1 + omega * t)
        }
        let omegaD = omega * (1 - zeta * zeta).squareRoot()
        let decay = exp(-zeta * omega * t)
        return 1 - decay * (cos(omegaD * t) + zeta * omega / omegaD * sin(omegaD * t))
    }
}

func oneDecimal(_ x: Double) -> Double { (x * 10).rounded() / 10 }
func percent(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }

let example = SpringModel(duration: 0.5, bounce: 0.3)
print("stiffness", oneDecimal(example.stiffness), "damping", oneDecimal(example.damping))

let springs = [SpringModel(duration: 0.5, bounce: 0), SpringModel(duration: 0.5, bounce: 0.3), SpringModel(duration: 0.5, bounce: 0.6)]
print("time  bounce 0, 0.3, 0.6")
for t in [0.1, 0.2, 0.3, 0.4, 0.5, 0.7] {
    print("\(t)s ", springs.map { percent($0.position(at: t)) }.joined(separator: ", "))
}
```

```output
stiffness 157.9 damping 17.6
time  bounce 0, 0.3, 0.6
0.1s  36%, 42%, 51%
0.2s  72%, 87%, 113%
0.3s  89%, 103%, 124%
0.4s  96%, 104%, 107%
0.5s  99%, 101%, 95%
0.7s  100%, 100%, 99%
```

Reading the table:

- **Same duration, same pace.** All three are close to done by 0.5 s; duration is the knob for "how long."
- **Bounce 0 never passes 100%.** It approaches the target and stops: right for things that should feel solid, like a sheet or a list row.
- **Bounce 0.3 overshoots by a few percent**: enough to feel alive without drawing attention. Bounce 0.6 overshoots by about a quarter and swings back below the target: that's a toy, fine for a celebratory pop, wrong for a navigation transition.

Apple's pages for the tunable presets give their starting points: `Spring.smooth(duration:extraBounce:)` adds to "the base bounce of 0," `snappy` to 0.15 and `bouncy` to 0.3, each with a default duration of 0.5. So the first two columns of the table are `.smooth` and `.bouncy`.

> [!warning] A model
> This is the textbook spring with the conversions that match Apple's example values. SwiftUI's springs also preserve velocity when one animation replaces another, and the model wasn't compared frame by frame with SwiftUI's output. Use the model to build intuition about the two knobs, not to predict frames.

How to choose, as a rule of thumb rather than an Apple rule:

| Purpose | Spring |
| --- | --- |
| Layout changes, sheets, rows appearing | `.smooth` or bounce 0 |
| Toggles, selection, things the user taps | `.snappy` (bounce 0.15) |
| Following a finger, then letting go | a short spring; springs keep the velocity when they replace each other |
| A celebration, a playful confirmation | `.bouncy` (bounce 0.3), or up to about 0.5 |

## Multi-step effects: phaseAnimator

Some feedback is a short sequence: an "Added to cart" button that grows, then settles back. With `withAnimation` you'd chain completions. `phaseAnimator` (iOS 17) takes the sequence as data. Apple's `PhaseAnimator` initializer describes the trigger form: "When the value of the `trigger` input changes, the animator reevaluates the `content` closure using the value from the second phase and animates the change. This procedure repeats with each successive phase until reaching the last phase, at which point the animator loops back to the first phase."

```swift ios
import SwiftUI

enum CartPop: CaseIterable {
    case resting, grown, settled

    var scale: Double {
        switch self {
        case .resting: 1
        case .grown: 1.25
        case .settled: 0.95
        }
    }
}

struct AddToCartButton: View {
    @State private var itemCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            itemCount += 1
        } label: {
            Label("Add to cart", systemImage: "cart.badge.plus")
        }
        .buttonStyle(.borderedProminent)
        .phaseAnimator(CartPop.allCases, trigger: reduceMotion ? 0 : itemCount) { content, phase in
            content.scaleEffect(phase.scale)
        } animation: { phase in
            phase == .grown ? Animation.bouncy : Animation.snappy
        }
        .sensoryFeedback(.increase, trigger: itemCount)
        .accessibilityValue("\(itemCount) in cart")
    }
}
```

- **The phases are an enum** with the properties each step needs. `CaseIterable` gives the ordered sequence. The first phase is what the button looks like at rest.
- **`trigger: itemCount`**: each tap changes it, so the button runs `resting → grown → settled → resting` once per tap.
- **`animation: { phase in … }`**: Apple: "A closure that takes the current phase as input. Return the animation to use when transitioning to the next phase. If you return `nil`, the transition doesn't animate."
- **Reduce Motion**: when it's on, the trigger is the constant 0, so it never changes and the pop never plays. The information (the count changed) is still in the accessibility value, on screen elsewhere, and in the haptic.
- **`.sensoryFeedback(.increase, trigger: itemCount)`**: one haptic per tap. More on that below.

Without a trigger, `phaseAnimator(_:content:animation:)` cycles continuously: "As soon as the animation completes, the procedure repeats." That's for indefinite states such as a "listening" pulse. It's also exactly the kind of motion to remove under Reduce Motion.

Here's the trigger rule as a model, including the two cases where nothing plays:

```swift
enum Phase: String, CaseIterable {
    case resting, grown, settled
}

/// What a trigger-driven phase animator plays when its trigger goes from old to new:
/// from the first phase through the others and back to the first, or nothing.
func phasesPlayed<T: Equatable>(from old: T, to new: T, phases: [Phase] = Phase.allCases) -> String {
    guard old != new, let first = phases.first else { return "nothing" }
    return (phases + [first]).map(\.rawValue).joined(separator: " → ")
}

let itemCounts = [0, 1, 1, 2]          // the second update didn't change the count
for (old, new) in zip(itemCounts, itemCounts.dropFirst()) {
    print("\(old) → \(new):", phasesPlayed(from: old, to: new))
}

let reduceMotion = true
print("Reduce Motion, 2 → 3:", phasesPlayed(from: reduceMotion ? 0 : 2, to: reduceMotion ? 0 : 3))
```

```output
0 → 1: resting → grown → settled → resting
1 → 1: nothing
1 → 2: resting → grown → settled → resting
Reduce Motion, 2 → 3: nothing
```

The trigger only has to be `Equatable`; what matters is whether it changed. That's also why the Reduce Motion version works: a constant trigger never changes.

## Independent timelines: keyframeAnimator

A phase moves *every* property from one step to the next at the same time. A bell that rings needs more: it scales up once, rotates back and forth several times, and the two shouldn't share timing. `keyframeAnimator` (iOS 17) animates a value **you** define, with one `KeyframeTrack` per property. Apple's `KeyframeTimeline` page: "keyframes fully define the path that a value takes over time using the tracks that make up their body."

```swift ios
import SwiftUI

struct RingValues {
    var scale = 1.0
    var angle = Angle.zero
}

struct NotificationBell: View {
    let unreadCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.title)
            .keyframeAnimator(initialValue: RingValues(),
                              trigger: reduceMotion ? 0 : unreadCount) { content, value in
                content
                    .rotationEffect(value.angle, anchor: .top)
                    .scaleEffect(value.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.3, duration: 0.1)
                    LinearKeyframe(0.9, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.2, spring: .bouncy)
                }
                KeyframeTrack(\.angle) {
                    LinearKeyframe(.degrees(-15), duration: 0.05)
                    LinearKeyframe(.degrees(15), duration: 0.1)
                    LinearKeyframe(.degrees(-10), duration: 0.1)
                    SpringKeyframe(.zero, duration: 0.2)
                }
            }
            .accessibilityLabel("Notifications")
            .accessibilityValue("\(unreadCount) unread")
    }
}
```

- **`RingValues`** holds everything the effect animates. The `content` closure applies it; Apple notes that closure "will be updated on every frame while animating, so avoid performing any expensive operations directly within `content`."
- **Each `KeyframeTrack(\.property)`** animates one property through its keyframes, in order, with its own durations. The scale finishes in 0.4 s; the rotation in 0.45 s.
- **Keyframe types.** `LinearKeyframe` interpolates in a straight line; `SpringKeyframe` "uses a spring function to interpolate to the given value"; `CubicKeyframe` draws a smooth curve, and Apple notes "Adjacent cubic keyframes result in a Catmull-Rom spline." `MoveKeyframe` jumps to a value immediately.
- **Interruption.** If the trigger changes mid-animation, Apple: "the keyframes closure will be called with the current interpolated value, and the keyframes that you return define a new animation that replaces the old one. The previous velocity will be preserved."

What a linear track computes is simple enough to model. Each keyframe starts where the previous one ended:

```swift
/// One LinearKeyframe: the value to reach and how long it takes to get there.
struct Keyframe {
    let value: Double
    let duration: Double
}

/// The value of a track of linear keyframes at a given time.
/// Each keyframe starts where the previous one ended; after the last one, the value holds.
func value(of track: [Keyframe], startingAt initial: Double, time: Double) -> Double {
    var start = initial
    var elapsed = 0.0
    for keyframe in track {
        if time <= elapsed + keyframe.duration {
            let progress = (time - elapsed) / keyframe.duration
            return start + (keyframe.value - start) * progress
        }
        elapsed += keyframe.duration
        start = keyframe.value
    }
    return start
}

let scaleTrack = [Keyframe(value: 1.3, duration: 0.1), Keyframe(value: 0.9, duration: 0.1), Keyframe(value: 1.0, duration: 0.2)]
let angleTrack = [Keyframe(value: -15, duration: 0.05), Keyframe(value: 15, duration: 0.1), Keyframe(value: 0, duration: 0.05)]

func twoDecimals(_ x: Double) -> Double { (x * 100).rounded() / 100 }

for time in [0.0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4] {
    let scale = twoDecimals(value(of: scaleTrack, startingAt: 1, time: time))
    let angle = Int(value(of: angleTrack, startingAt: 0, time: time).rounded())
    print("t=\(time): scale \(scale), angle \(angle)°")
}
```

```output
t=0.0: scale 1.0, angle 0°
t=0.05: scale 1.15, angle -15°
t=0.1: scale 1.3, angle 0°
t=0.15: scale 1.1, angle 15°
t=0.2: scale 0.9, angle 0°
t=0.3: scale 0.95, angle 0°
t=0.4: scale 1.0, angle 0°
```

The angle track is done at 0.2 s while the scale track is still easing back from 0.9. Neither knows about the other. `KeyframeTimeline` (iOS 17) does this for real SwiftUI keyframes: its `value(time:)` returns the interpolated value at any time, which is useful to test or scrub an effect.

## State that means something

The examples so far animate in response to a counter. In real screens the trigger should be **domain state**: a save that succeeded, a payment that failed. When the meaning lives in an enum, the animation, the haptic and the accessibility announcement can all be derived from the same transition, and they can't drift apart:

```swift
enum SaveStatus: Equatable {
    case idle, saving, saved, failed
}

enum Haptic: String {
    case success, error, none
}

struct Feedback: Equatable {
    var motion: String       // what the view does
    var haptic: Haptic
}

/// What the user should perceive for a status change.
func feedback(from old: SaveStatus, to new: SaveStatus, reduceMotion: Bool) -> Feedback {
    switch (old, new) {
    case (.saving, .saved):
        return Feedback(motion: reduceMotion ? "fade in checkmark" : "pop checkmark", haptic: .success)
    case (.saving, .failed):
        return Feedback(motion: reduceMotion ? "show error text" : "shake field", haptic: .error)
    case (_, .saving):
        return Feedback(motion: "show spinner", haptic: .none)
    default:
        return Feedback(motion: "none", haptic: .none)
    }
}

let transitions: [(SaveStatus, SaveStatus)] = [(.idle, .saving), (.saving, .failed), (.failed, .saving), (.saving, .saved), (.saved, .idle)]
for (old, new) in transitions {
    let normal = feedback(from: old, to: new, reduceMotion: false)
    let reduced = feedback(from: old, to: new, reduceMotion: true)
    print("\(old) → \(new): \(normal.motion) / \(reduced.motion), haptic \(normal.haptic.rawValue)")
}
```

```output
idle → saving: show spinner / show spinner, haptic none
saving → failed: shake field / show error text, haptic error
failed → saving: show spinner / show spinner, haptic none
saving → saved: pop checkmark / fade in checkmark, haptic success
saved → idle: none / none, haptic none
```

Two things the table makes visible. Reduce Motion changes the *motion* column only: the user still learns the save failed. And `saved → idle` (the checkmark going away) gets nothing, because nothing the user needs to know happened. In SwiftUI the same decisions become modifiers keyed on the status.

## Haptics with sensoryFeedback

`sensoryFeedback(_:trigger:)` (iOS 17) "plays the specified `feedback` when the provided `trigger` value changes." `SensoryFeedback` has values for outcomes (`.success`, `.warning`, `.error`), for changes (`.selection`, `.increase`, `.decrease`, `.start`, `.stop`, `.alignment`, `.levelChange`) and physical impacts (`.impact`, `.impact(weight:intensity:)`, `.impact(flexibility:intensity:)`).

Playing on *every* change is rarely right. `sensoryFeedback(_:trigger:condition:)` adds a closure that receives the old and new values:

```swift ios
import SwiftUI

enum SaveStatus: Equatable {
    case idle, saving, saved, failed
}

struct SaveButton: View {
    let status: SaveStatus
    let save: () -> Void
    @State private var failures = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: save) {
            switch status {
            case .saving:
                ProgressView()
            case .saved:
                Label("Saved", systemImage: "checkmark.circle.fill")
            default:
                Text("Save")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(status == .saving)
        .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : failures) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-10, duration: 0.06)
                LinearKeyframe(10, duration: 0.08)
                LinearKeyframe(-6, duration: 0.08)
                SpringKeyframe(0, duration: 0.2)
            }
        }
        .sensoryFeedback(.success, trigger: status) { _, new in new == .saved }
        .sensoryFeedback(.error, trigger: status) { old, new in old == .saving && new == .failed }
        .onChange(of: status) { _, new in
            if new == .failed { failures += 1 }
        }
    }
}
```

- **Two haptics, two conditions.** Success plays only on arriving at `.saved`; error only on `saving → failed`. Going back to `.idle` plays nothing.
- **The shake** is a keyframe animation on a single `Double` (a track with no key path animates the whole value). It's triggered by a failure counter, so two failures in a row shake twice, which a `status` trigger wouldn't do if the status were already `.failed`.
- **Reduce Motion** stops the shake but not the haptic. The failure is also visible in whatever error text the screen shows; a shake alone isn't enough for someone who isn't looking at the button.

Use haptics the way you'd use sound: for outcomes and for physical-feeling interactions (snapping to a detent, reaching a limit). A haptic on every scroll or every keystroke becomes noise, and people stop noticing the ones that matter. The Human Interface Guidelines have a Playing haptics page with Apple's guidance.

## Reduce Motion, revisited

Module 35 showed the basic rule: replace movement with fades, keep the change. With iOS 17's tools there are a few more cases:

- **Trigger-based phase and keyframe animations**: make the trigger constant under Reduce Motion (`trigger: reduceMotion ? 0 : count`), as in the examples. Nothing plays; nothing else changes.
- **Continuous phase animators and `repeatForever`**: don't attach them at all. A pulse that never stops is the clearest case of motion with no information.
- **Springs**: a bounce is movement. `withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy)` keeps a short, non-moving cross-fade where the change needs one.
- **Haptics** aren't motion. They're a good way to keep feedback when the visual effect is gone.

## Common mistakes

> [!error] An animation that delays the user
> A confirmation that must finish before the next screen appears, or a 1-second spring on a button the user taps repeatedly. Keep interactive feedback short, and never block input while an effect plays.

> [!error] A phaseAnimator that never stops
> `phaseAnimator(phases) { … }` without a trigger cycles forever, as Apple documents. That's right for a "recording" indicator and wrong for a one-off pop. Use the trigger form for anything that responds to an event.

> [!error] Capturing view properties in the keyframe content closure
> `keyframeAnimator`'s `content` closure is `@Sendable` and runs every frame. Read only `content` and the interpolated value there; compute anything else before, and put whatever varies into the value type.

> [!error] A haptic on every change
> `.sensoryFeedback(.success, trigger: status)` without a condition also plays when the status changes to `.saving`, `.failed` or `.idle`. Add the `condition` closure, or use separate modifiers per outcome.

> [!error] Hiding meaning in motion
> A shake as the only sign of a wrong password tells VoiceOver users nothing and disappears under Reduce Motion. The motion supports a message; it doesn't replace it.

## Exercises

````exercise
id: m38-l02-e1
type: prediction
prompt: "Using the conversion formulas from the lesson, what does this print?"
code: |
  import Foundation

  struct SpringModel {
      var duration: Double
      var bounce: Double

      var stiffness: Double { pow(2 * Double.pi / duration, 2) }
      var damping: Double { 4 * Double.pi * (1 - bounce) / duration }
  }

  func oneDecimal(_ x: Double) -> Double { (x * 10).rounded() / 10 }

  for spring in [SpringModel(duration: 1, bounce: 0), SpringModel(duration: 0.5, bounce: 0), SpringModel(duration: 0.5, bounce: 0.5)] {
      print(oneDecimal(spring.stiffness), oneDecimal(spring.damping))
  }
output: |
  39.5 12.6
  157.9 25.1
  157.9 12.6
hints:
  - "(2π)² ≈ 39.48 and 4π ≈ 12.57."
  - "Halving the duration multiplies stiffness by 4 and damping by 2."
solution: |
  ```output
  39.5 12.6
  157.9 25.1
  157.9 12.6
  ```

  With a 1-second duration, stiffness is (2π)² ≈ 39.5 and damping 4π ≈ 12.6. Halving the duration makes the spring four times stiffer (157.9) and doubles the damping (25.1), so it's faster but still not bouncy. Adding bounce 0.5 keeps the stiffness and halves the damping: same pace, less friction, so it overshoots. That's the point of the duration/bounce parameterization: each knob changes one thing you perceive.
````

````exercise
id: m38-l02-e2
type: prediction
prompt: "A linear keyframe track for a badge's vertical offset. What does it print?"
code: |
  struct Keyframe {
      let value: Double
      let duration: Double
  }

  func value(of track: [Keyframe], startingAt initial: Double, time: Double) -> Double {
      var start = initial
      var elapsed = 0.0
      for keyframe in track {
          if time <= elapsed + keyframe.duration {
              let progress = (time - elapsed) / keyframe.duration
              return start + (keyframe.value - start) * progress
          }
          elapsed += keyframe.duration
          start = keyframe.value
      }
      return start
  }

  let hop = [Keyframe(value: -20, duration: 0.2), Keyframe(value: 0, duration: 0.2), Keyframe(value: -5, duration: 0.1), Keyframe(value: 0, duration: 0.1)]
  for time in [0.1, 0.2, 0.3, 0.5, 0.6, 1.0] {
      print(Int(value(of: hop, startingAt: 0, time: time).rounded()))
  }
output: |
  -10
  -20
  -10
  -5
  0
  0
hints:
  - "The keyframes end at 0.2, 0.4, 0.5 and 0.6 seconds."
  - "At 0.5 the third keyframe, from 0 to −5, has just finished."
solution: |
  ```output
  -10
  -20
  -10
  -5
  0
  0
  ```

  The track goes up 20 points in 0.2 s, back down in 0.2 s, a small 5-point hop in 0.1 s and down again. At 0.1 s it's halfway up (−10); at 0.2 s it's at the top; at 0.3 s halfway down. At 0.5 s the small hop is at its top, −5. At 0.6 s the last keyframe has just finished, and after the end the value holds at 0.
````

````exercise
id: m38-l02-e3
type: prediction
prompt: "The feedback table from the lesson, with Reduce Motion on, for a sequence of statuses. What does it print?"
code: |
  enum SaveStatus: Equatable {
      case idle, saving, saved, failed
  }

  func feedback(from old: SaveStatus, to new: SaveStatus, reduceMotion: Bool) -> (motion: String, haptic: String) {
      switch (old, new) {
      case (.saving, .saved):
          return (reduceMotion ? "fade in checkmark" : "pop checkmark", "success")
      case (.saving, .failed):
          return (reduceMotion ? "show error text" : "shake field", "error")
      case (_, .saving):
          return ("show spinner", "none")
      default:
          return ("none", "none")
      }
  }

  let statuses: [SaveStatus] = [.idle, .saving, .saved, .saving, .failed, .idle]
  for index in 1..<statuses.count {
      let result = feedback(from: statuses[index - 1], to: statuses[index], reduceMotion: true)
      if result.haptic != "none" {
          print(result.motion, "+", result.haptic)
      }
  }
output: |
  fade in checkmark + success
  show error text + error
hints:
  - "Only transitions out of .saving into .saved or .failed have a haptic."
solution: |
  ```output
  fade in checkmark + success
  show error text + error
  ```

  The loop looks at five transitions: idle → saving, saving → saved, saved → saving, saving → failed, failed → idle. Only two have a haptic, and with Reduce Motion on their motion is the non-moving version. The user still gets both outcomes, through the screen and through the haptic.
````

````exercise
id: m38-l02-e4
type: comprehension
prompt: "A heart icon should grow, tilt left and right twice while growing, then settle back, when the user likes a post. The tilt and the growth have different timings. Which tool fits best?"
choices:
  - text: "keyframeAnimator with one KeyframeTrack for the scale and one for the angle, triggered by the like count."
    correct: true
    why: "Independent timing per property is what keyframe tracks are for, and the trigger plays it once per like."
  - text: "phaseAnimator with phases for each tilt."
    correct: false
    why: "Every phase moves all properties together, so the growth would have to stop and start with each tilt."
  - text: "withAnimation(.bouncy) around isLiked.toggle()."
    correct: false
    why: "That animates from one state to another once; it can't express a back-and-forth tilt."
  - text: "phaseAnimator without a trigger."
    correct: false
    why: "That cycles continuously, forever."
solution: |
  **keyframeAnimator.** Put `scale` and `angle` in a value type, give each a `KeyframeTrack`, and use the like count (or a counter that only increases on like) as the trigger. Make the trigger constant under Reduce Motion, and let the filled heart and its accessibility value carry the information.
````

````exercise
id: m38-l02-e5
type: fill-in
prompt: "Complete the toggle so it plays a selection haptic only when the filter turns on, and a bouncy scale pop that doesn't play under Reduce Motion."
code: |
  struct FilterChip: View {
      @Binding var isOn: Bool
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      var body: some View {
          Toggle("Vegan", isOn: $isOn)
              .toggleStyle(.button)
              .[[1]](.selection, trigger: isOn) { _, new in [[2]] }
              .phaseAnimator([1.0, 1.15], trigger: [[3]]) { content, scale in
                  content.scaleEffect(scale)
              }
      }
  }
blanks:
  - id: "1"
    answers: ["sensoryFeedback"]
  - id: "2"
    answers: ["new", "new == true"]
  - id: "3"
    answers: ["reduceMotion ? false : isOn", "!reduceMotion && isOn", "reduceMotion ? true : isOn"]
hints:
  - "The condition closure receives the old and new trigger values."
  - "A trigger that can't change under Reduce Motion never plays the animation."
solution: |
  ```swift ios
  import SwiftUI

  struct FilterChip: View {
      @Binding var isOn: Bool
      @Environment(\.accessibilityReduceMotion) private var reduceMotion

      var body: some View {
          Toggle("Vegan", isOn: $isOn)
              .toggleStyle(.button)
              .sensoryFeedback(.selection, trigger: isOn) { _, new in new }
              .phaseAnimator([1.0, 1.15], trigger: reduceMotion ? false : isOn) { content, scale in
                  content.scaleEffect(scale)
              }
      }
  }
  ```

  `sensoryFeedback(_:trigger:condition:)` plays only when the closure returns `true`, here when the new value is on. The phase animator walks 1.0 → 1.15 → 1.0 when its trigger changes; with Reduce Motion on, the trigger is always `false`, so it never changes. A `Toggle` already exposes its on/off state to VoiceOver, so no extra accessibility value is needed.
````

````exercise
id: m38-l02-e6
type: solve
prompt: |
  For an underdamped spring, the fraction by which it overshoots its target is `exp(-π × ζ / sqrt(1 − ζ²))`, where the damping ratio ζ = 1 − bounce. For bounce 0 there's no overshoot.

  Write `overshoot(bounce:)` returning that fraction (0 for bounce ≤ 0), and print the overshoot as a whole percentage for bounce 0, 0.15, 0.3, 0.5 and 0.7, like `bounce 0.3: 5%`. Then print the smallest of those bounces whose overshoot is at least 10%.
starter: |
  import Foundation

  func overshoot(bounce: Double) -> Double {
      // your code
      0
  }
hints:
  - "exp, sqrt and Double.pi come with Foundation."
  - "Int((x * 100).rounded()) gives a whole percentage."
  - "first(where:) on the array of bounces finds the smallest one, since they're in increasing order."
rubric:
  - Returns 0 for bounce ≤ 0 and uses the formula otherwise.
  - Prints five lines with rounded percentages.
  - Finds the first bounce with at least 10% overshoot without hard-coding it.
solution: |
  ```swift
  import Foundation

  func overshoot(bounce: Double) -> Double {
      guard bounce > 0 else { return 0 }
      let zeta = 1 - bounce
      return exp(-Double.pi * zeta / sqrt(1 - zeta * zeta))
  }

  let bounces = [0, 0.15, 0.3, 0.5, 0.7]
  for bounce in bounces {
      print("bounce \(bounce): \(Int((overshoot(bounce: bounce) * 100).rounded()))%")
  }
  if let first = bounces.first(where: { overshoot(bounce: $0) >= 0.1 }) {
      print("at least 10% from bounce \(first)")
  }
  ```

  ```output
  bounce 0.0: 0%
  bounce 0.15: 1%
  bounce 0.3: 5%
  bounce 0.5: 16%
  bounce 0.7: 37%
  at least 10% from bounce 0.5
  ```

  Overshoot grows quickly with bounce: 0.15 is barely visible, 0.3 is a gentle 5% (the lesson's table showed a peak around 104%), and 0.5 overshoots by 16%. That's a useful way to pick a bounce: decide how far past the target the thing may travel, then choose the bounce. By the same formula, `.snappy` (base bounce 0.15) overshoots by about 1% and `.bouncy` (0.3) by about 5%, assuming SwiftUI's springs follow the textbook model, which wasn't measured here.
````

## Summary

- Animate to answer a question: where something came from, what changed, whether it worked. Everything else is decoration, and goes first under Reduce Motion.
- A spring is duration (pace) plus bounce (overshoot). Bounce 0 never passes the target; around 0.3 overshoots by a few percent; `Spring` converts to mass, stiffness and damping.
- `phaseAnimator` with a trigger walks from the first phase through the rest and back, once per change. Without a trigger it loops forever.
- `keyframeAnimator` animates your own value type with one `KeyframeTrack` per property, each on its own timeline. `KeyframeTimeline` evaluates keyframes at any time.
- Drive animation and haptics from domain state transitions; `sensoryFeedback(_:trigger:condition:)` plays only for the transitions that matter.
- Under Reduce Motion: make one-shot triggers constant, drop looping motion, keep the information in text, accessibility values and haptics.
