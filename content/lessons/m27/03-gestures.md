---
id: m27-l03
title: Gesture recognizers
description: Turn touches into intent. You attach tap, pan, pinch and long-press recognizers, read their states correctly, apply translation and scale without the accumulation bug, let two recognizers work at once through the delegate, make one wait for another with require(toFail:), and write a custom recognizer subclass whose recognition logic is plain Swift you can test.
module: m27
order: 3
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l02]
objectives:
  - Attach UITapGestureRecognizer, UIPanGestureRecognizer, UIPinchGestureRecognizer and UILongPressGestureRecognizer with target-action.
  - Explain the state machine of discrete and continuous recognizers and handle each state in an action method.
  - Apply pan translation and pinch scale as totals since the gesture began, not as deltas.
  - Allow simultaneous recognition with gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:) and filter gestures with gestureRecognizerShouldBegin(_:).
  - Make one recognizer wait for another to fail with require(toFail:), and explain the delay it adds.
  - Write a custom UIGestureRecognizer subclass that sets its state from touch events and resets itself.
terms:
  - term: Gesture recognizer
    definition: "An object attached to a view that watches the touches hit-tested to that view and its subviews and decides whether they form a specific gesture. It isn't in the responder chain."
  - term: Discrete gesture
    definition: "A gesture that happens once, like a tap. The recognizer goes from possible to recognized (ended) or failed, and the action is sent once."
  - term: Continuous gesture
    definition: "A gesture that reports changes while it lasts, like a pan, pinch or long press. The recognizer goes possible, began, changed (any number of times), then ended or cancelled, sending the action at each step."
  - term: Failure requirement
    definition: "A dependency set with require(toFail:): a recognizer stays in the possible state until the other one fails, and fails itself if the other one recognizes."
  - term: Simultaneous recognition
    definition: "Two recognizers recognizing at the same time. By default UIKit doesn't allow it; a delegate returns true from gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:) to allow it."
mastery:
  - Write a pan handler that drags a view and never jumps or accelerates.
  - Handle a long press's began, changed, ended and cancelled states in one action method.
  - Combine pinch and rotation on one view so both work at once.
  - Configure a single tap and a double tap on the same view and say why the single tap now fires later.
  - Predict the state sequence of a long-press recognizer for a given touch sequence.
  - Write a custom recognizer with touchesBegan, touchesMoved, touchesEnded, touchesCancelled and reset.
resources: [uikit-target-action, uikit-responder-chain, uikit-uiview]
cards:
  - id: m27-l03-c1
    front: What does translation(in:) return on each .changed call?
    back: "The total translation since the gesture began, not the change since the last call. Apply it to the value the view had at .began, or call setTranslation(.zero, in:) after applying it each time."
  - id: m27-l03-c2
    front: States of a continuous gesture recognizer?
    back: "possible → began → changed (repeated) → ended, or cancelled if the system interrupts it, or failed if it never matched. The action is sent at began, changed, ended and cancelled."
  - id: m27-l03-c3
    front: What does singleTap.require(toFail:) with a double tap do, and what does it cost?
    back: "The single tap stays in possible until the double tap fails, then recognizes; if the double tap recognizes, the single tap fails. Cost: every single tap is reported only after UIKit decides no second tap is coming."
  - id: m27-l03-c4
    front: How do you let pinch and rotation work at the same time?
    back: "Set a delegate on one of them and return true from gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:). The default is false. Returning true guarantees it; returning false doesn't prevent it if the other recognizer's delegate returns true."
  - id: m27-l03-c5
    front: What must a custom UIGestureRecognizer subclass do?
    back: "Import UIKit.UIGestureRecognizerSubclass for the writable state, override the touches methods (calling super), set state as touches arrive (failed as soon as it can't match), and override reset() to clear its own properties."
---

## The idea in one sentence

A gesture recognizer is a small state machine attached to a view: it watches raw touches before the view gets them, decides whether they form its gesture, and tells your action method at each step, so your job is to configure it, read its state correctly, and settle conflicts between recognizers.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The behavior comes from Apple's reference pages for `UIGestureRecognizer`, its subclasses and `UIGestureRecognizerDelegate`, and from the articles "About the Gesture Recognizer State Machine" and "Implementing a discrete gesture recognizer", read in November 2026. The state-machine models and the recognition logic are plain Swift, compiled and run with Swift 6.3.

## Where recognizers sit

Module 22 handled taps on buttons with `UIAction` and target-action. Buttons are controls with their own touch tracking. For any other view (an image, a card, a canvas) you attach a **gesture recognizer**:

```swift ios
import UIKit

final class PhotoViewController: UIViewController {
    private let photo = UIImageView(image: UIImage(systemName: "photo"))

    override func viewDidLoad() {
        super.viewDidLoad()
        photo.frame = CGRect(x: 40, y: 120, width: 300, height: 200)
        photo.isUserInteractionEnabled = true
        view.addSubview(photo)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        photo.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: photo)
        print("tapped at \(point)")
    }
}
```

- **`addGestureRecognizer(_:)`** attaches it. Apple: "A gesture recognizer operates on touches hit-tested to a specific view and all of that view's subviews."
- **`isUserInteractionEnabled = true`**: `UIImageView` and `UILabel` have it set to `false` by default, so touches pass through them and the recognizer never sees anything. This is the first thing to check when a recognizer on an image does nothing.
- **The action** receives the recognizer, which you ask for details: `location(in:)`, and for continuous gestures, translation, scale or velocity.
- **Order of delivery**: "A window delivers touch events to a gesture recognizer before it delivers them to the hit-tested view attached to the gesture recognizer." When the recognizer recognizes, by default (`cancelsTouchesInView = true`) the view's touches are cancelled.

The concrete recognizers UIKit provides: tap, pinch, rotation, swipe, pan, screen-edge pan, long press and hover.

## The state machine

Every recognizer starts each touch sequence in `.possible`. From there, the two kinds diverge.

```plaintext
discrete (tap, swipe)            continuous (pan, pinch, rotation, long press)

possible ──▶ recognized          possible ──▶ began ──▶ changed ─┬─▶ ended
    │                                │                  ▲  │     └─▶ cancelled
    └──────▶ failed                  └──▶ failed        └──┘
```

- A **discrete** recognizer goes to `.recognized` (the same value as `.ended`) or `.failed`, and the action runs once.
- A **continuous** recognizer reports `.began`, then `.changed` as often as the touches move, then `.ended`. If the system interrupts it, a phone call for example, it reports `.cancelled`.
- UIKit sends the action for `.began`, `.changed`, `.ended` and `.cancelled`. It never sends it for `.failed`.
- After an end state, UIKit resets the recognizer to `.possible` before the next touch sequence.

So the action of a continuous recognizer must switch on the state. A long press that shows a menu, follows the finger, and cleans up:

```swift ios
import UIKit

final class BoardViewController: UIViewController {
    private let card = UIView(frame: CGRect(x: 60, y: 200, width: 120, height: 80))

    override func viewDidLoad() {
        super.viewDidLoad()
        card.backgroundColor = .systemTeal
        view.addSubview(card)

        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0.4
        card.addGestureRecognizer(press)
    }

    @objc private func handlePress(_ press: UILongPressGestureRecognizer) {
        switch press.state {
        case .began:
            UIView.animate(withDuration: 0.15) { self.card.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) }
        case .changed:
            card.center = press.location(in: view)
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.15) { self.card.transform = .identity }
        default:
            break
        }
    }
}
```

The `.cancelled` case matters as much as `.ended`: if a call comes in mid-press and you only handle `.ended`, the card stays enlarged.

### A model of the long-press recognizer

Apple's `UILongPressGestureRecognizer` page gives the rules: the gesture begins when the fingers have been down for `minimumPressDuration` (default 0.5 seconds) "and the touches don't move beyond the allowable range of movement" (`allowableMovement`, default 10 points); "While down, the user's fingers can't move more than a specified distance or the gesture fails"; it changes whenever a finger moves and ends when a finger lifts. Here are those rules in plain Swift. Time passing with the finger still is the `.hold` event, standing in for UIKit's internal timer:

```swift
enum GestureState { case possible, began, changed, ended, cancelled, failed }

enum TouchEvent {
    case down(time: Double)
    case hold(until: Double)
    case move(distance: Double)
    case up
    case cancel
}

struct LongPressModel {
    var minimumPressDuration = 0.5
    var allowableMovement = 10.0
    private(set) var state = GestureState.possible
    private var downTime = 0.0

    mutating func handle(_ event: TouchEvent) {
        switch (event, state) {
        case (.down(let time), .possible):
            downTime = time
        case (.hold(let time), .possible) where time - downTime >= minimumPressDuration:
            state = .began
        case (.move(let distance), .possible) where distance > allowableMovement:
            state = .failed
        case (.move, .began), (.move, .changed):
            state = .changed
        case (.up, .possible):
            state = .failed
        case (.up, .began), (.up, .changed):
            state = .ended
        case (.cancel, .began), (.cancel, .changed):
            state = .cancelled
        default:
            break
        }
    }
}

func run(_ events: [TouchEvent]) {
    var press = LongPressModel()
    var states = [press.state]
    for event in events {
        press.handle(event)
        if states.last != press.state { states.append(press.state) }
    }
    print(states.map { "\($0)" }.joined(separator: " → "))
}

run([.down(time: 0), .hold(until: 0.3), .up])
run([.down(time: 0), .move(distance: 4), .hold(until: 0.6), .move(distance: 40), .up])
run([.down(time: 0), .move(distance: 25), .hold(until: 1.0), .up])
run([.down(time: 0), .hold(until: 0.7), .cancel])
```

```output
possible → failed
possible → began → changed → ended
possible → failed
possible → began → cancelled
```

One line per run:

1. Lifted after 0.3 seconds: too short, **failed**.
2. A 4-point wobble is within the 10-point allowance; at 0.6 seconds it **began**; moving 40 points afterwards is a **change**, not a failure, because the limit applies only while the recognizer is deciding; lifting **ends** it.
3. Moving 25 points before the duration passed: **failed**, and holding afterwards doesn't revive it.
4. Began, then the system cancelled the touches: **cancelled**, and the action runs one last time with that state.

The `switch` on a `(event, state)` tuple is the whole recognizer: each case is one allowed transition, and `default: break` ignores everything else, like events that arrive after a final state.

## Pan: totals, not deltas

`UIPanGestureRecognizer` reports `translation(in:)`, and the most common gesture bug comes from misreading it. Apple: "The x and y values report the total translation over time. They aren't delta values from the last time that the translation was reported. Apply the translation value to the state of the view when the gesture is first recognized — don't concatenate the value each time the handler is called."

The difference in plain numbers. A finger moves right; the recognizer reports these totals on four `.changed` calls:

```swift
// What a pan recognizer reports on each .changed: the total since .began.
let reportedTranslations = [12, 30, 45, 60]

var wrongX = 100
for translation in reportedTranslations {
    wrongX += translation
}
print("added every time:", wrongX)

let startX = 100
var rightX = startX
for translation in reportedTranslations {
    rightX = startX + translation
}
print("start + total:", rightX)

var resetX = 100
var previousTotal = 0
for total in reportedTranslations {
    resetX += total - previousTotal
    previousTotal = total
}
print("delta since last call:", resetX)
```

```output
added every time: 247
start + total: 160
delta since last call: 160
```

The finger moved 60 points, so the view should end at 160. Adding each total moves it 147 points: the view runs ahead of the finger, faster the longer you drag. Two correct patterns:

```swift ios
import UIKit

final class DragViewController: UIViewController {
    private let sticker = UIView(frame: CGRect(x: 100, y: 300, width: 80, height: 80))
    private var centerAtStart = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        sticker.backgroundColor = .systemOrange
        view.addSubview(sticker)
        sticker.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    // Pattern 1: remember where the view was, apply the total.
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            centerAtStart = sticker.center
        case .changed:
            let translation = pan.translation(in: view)
            sticker.center = CGPoint(x: centerAtStart.x + translation.x, y: centerAtStart.y + translation.y)
        default:
            break
        }
    }

    // Pattern 2: apply the total, then reset it to zero, so the next call is a delta.
    @objc private func handlePanResetting(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .changed else { return }
        let translation = pan.translation(in: view)
        sticker.center.x += translation.x
        sticker.center.y += translation.y
        pan.setTranslation(.zero, in: view)
    }
}
```

- Ask for the translation **in the superview's coordinates** (`view` here). Apple: "If you want to adjust a view's location to keep it under the user's finger, request the translation in that view's superview's coordinate system." In the sticker's own coordinates, the reference frame moves with the sticker.
- Pattern 2 works because of `setTranslation(.zero, in:)`. Apple notes that "Changing the translation value resets the velocity of the pan", so if you need `velocity(in:)` at `.ended` (for a flick, as in lesson 1), prefer pattern 1.

### Pinch and rotation follow the same rule

`UIPinchGestureRecognizer.scale` "is an absolute value that varies over time. It isn't the delta value from the last time that the scale was reported." `UIRotationGestureRecognizer.rotation` is described the same way. The same two patterns work: store the transform at `.began` and apply the total to it, or apply it and set `scale = 1` (Apple: "You may set the scale factor, but doing so resets the velocity").

## Two gestures at once

By default, once one recognizer recognizes, others attached to the same touches can't. That's usually right (a tap and a pan shouldn't both fire), but for pinch and rotation on a photo, people expect to do both at once. The delegate decides:

```swift ios
import UIKit

final class CanvasViewController: UIViewController, UIGestureRecognizerDelegate {
    private let photo = UIView(frame: CGRect(x: 60, y: 200, width: 240, height: 240))

    override func viewDidLoad() {
        super.viewDidLoad()
        photo.backgroundColor = .systemIndigo
        view.addSubview(photo)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        pinch.delegate = self
        rotate.delegate = self
        photo.addGestureRecognizer(pinch)
        photo.addGestureRecognizer(rotate)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer.view == otherGestureRecognizer.view
    }

    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard pinch.state == .began || pinch.state == .changed else { return }
        photo.transform = photo.transform.scaledBy(x: pinch.scale, y: pinch.scale)
        pinch.scale = 1
    }

    @objc private func handleRotation(_ rotate: UIRotationGestureRecognizer) {
        guard rotate.state == .began || rotate.state == .changed else { return }
        photo.transform = photo.transform.rotated(by: rotate.rotation)
        rotate.rotation = 0
    }
}
```

- The delegate method returns `true` only for recognizers on the same view, so this screen's other gestures aren't affected.
- Apple: "returning true is guaranteed to allow simultaneous recognition; returning false, on the other hand, is not guaranteed to prevent simultaneous recognition because the other gesture recognizer's delegate may return true." One `true` from either side is enough.
- Each handler uses the **reset pattern**: apply the total to the current transform, then set `scale` back to 1 (or `rotation` back to 0), so the next call reports only the change since this one. With two gestures changing the same transform at once, that's simpler than saving a starting transform for each. Setting the value resets the gesture's velocity, which this screen doesn't use.

### gestureRecognizerShouldBegin

The delegate can also veto a recognizer just as it's about to leave `.possible`: "Returning false causes the gesture recognizer to transition to the UIGestureRecognizer.State.failed state." A common use is a pan that should only react to horizontal movement, so vertical drags go to the scroll view underneath:

```swift ios
import UIKit

@MainActor
final class SwipeRowController: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: pan.view)
        return abs(velocity.x) > abs(velocity.y)
    }
}
```

## One gesture waiting for another

A photo that likes on double tap and shows controls on single tap. With two tap recognizers and nothing else, a double tap first triggers the single tap. `require(toFail:)` creates the dependency:

```swift ios
import UIKit

final class LikeViewController: UIViewController {
    private let photo = UIView(frame: CGRect(x: 20, y: 120, width: 350, height: 350))

    override func viewDidLoad() {
        super.viewDidLoad()
        photo.backgroundColor = .systemGray4
        view.addSubview(photo)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(like))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        singleTap.require(toFail: doubleTap)

        photo.addGestureRecognizer(doubleTap)
        photo.addGestureRecognizer(singleTap)
    }

    @objc private func like() {
        print("liked")
    }

    @objc private func toggleControls() {
        print("controls")
    }
}
```

Apple's description: the method "delays the current gesture recognizer's transition out of UIGestureRecognizer.State.possible". If the double tap fails, the single tap proceeds normally; if the double tap recognizes, the single tap fails.

**The cost is latency.** The single tap can't be reported until UIKit is sure no second tap is coming. A model makes that visible; the double-tap window here is a parameter, because UIKit doesn't document its value:

```swift
func resolveTaps(at times: [Int], doubleTapWindow: Int) {
    var index = 0
    while index < times.count {
        let first = times[index]
        if index + 1 < times.count, times[index + 1] - first <= doubleTapWindow {
            print("double tap recognized at \(times[index + 1]) ms")
            index += 2
        } else {
            print("single tap at \(first) ms recognized at \(first + doubleTapWindow) ms")
            index += 1
        }
    }
}

resolveTaps(at: [0, 200, 1000], doubleTapWindow: 300)
```

```output
double tap recognized at 200 ms
single tap at 1000 ms recognized at 1300 ms
```

The tap at 1000 ms only counts as a single tap once the window has passed without a second tap. That delay is inherent to the dependency. If single-tap feedback must be instant, don't put both gestures on the same view, or make the single-tap action harmless to run before a double tap (Photos-style apps often do the latter).

For dependencies between recognizers created in different places, such as one inside a framework, Apple points to the delegate methods `gestureRecognizer(_:shouldRequireFailureOf:)` and `gestureRecognizer(_:shouldBeRequiredToFailBy:)` instead.

## A custom recognizer

When no built-in recognizer matches, subclass `UIGestureRecognizer`. Apple's checklist from "Implementing a custom gesture recognizer" and the state machine article:

1. Import `UIKit.UIGestureRecognizerSubclass`. It redeclares `state` as writable; without it, `state` is read-only.
2. Override `touchesBegan`, `touchesMoved`, `touchesEnded` and `touchesCancelled`, calling `super`, and update `state` from what the touches do.
3. Fail **early**: "if the initial event sequence does not match your gesture, move your gesture recognizer to the UIGestureRecognizer.State.failed state immediately." UIKit normally lets only one recognizer at a time notify its client; failing quickly gives others a chance.
4. Override `reset()` to clear your own properties. UIKit calls it after an end state and sets `state` back to `.possible` itself.

The example is a **zigzag**: scratching back and forth over a drawing to erase it. A discrete gesture that recognizes after the finger reverses horizontal direction a number of times, each stroke at least 30 points long. The recognition logic doesn't need UIKit, so it lives in a plain struct you can test:

```swift
struct ZigzagDetector {
    enum Result { case undecided, recognized }

    let minimumStroke: Double
    let requiredReversals: Int
    private var anchor: Double?
    private var direction = 0
    private(set) var reversals = 0

    init(minimumStroke: Double, requiredReversals: Int) {
        self.minimumStroke = minimumStroke
        self.requiredReversals = requiredReversals
    }

    mutating func add(x: Double) -> Result {
        if let start = anchor, abs(x - start) >= minimumStroke {
            let newDirection = x > start ? 1 : -1
            if direction != 0 && newDirection != direction {
                reversals += 1
            }
            direction = newDirection
            anchor = x
        } else if anchor == nil {
            anchor = x
        }
        return reversals >= requiredReversals ? .recognized : .undecided
    }
}

var detector = ZigzagDetector(minimumStroke: 30, requiredReversals: 2)
for x in [100.0, 140, 180, 150, 110, 105, 150] {
    print(Int(x), detector.add(x: x), "reversals:", detector.reversals)
}
```

```output
100 undecided reversals: 0
140 undecided reversals: 0
180 undecided reversals: 0
150 undecided reversals: 1
110 undecided reversals: 1
105 undecided reversals: 1
150 recognized reversals: 2
```

The anchor only moves when the finger has traveled at least a full stroke from it, so jitter (110 to 105) doesn't count as a reversal. The first reversal happens at 150 (moving left after moving right), the second at 150 again (moving right after moving left).

The UIKit subclass is a thin wrapper that feeds touch positions to the detector:

```swift ios
import UIKit
import UIKit.UIGestureRecognizerSubclass

struct ZigzagDetector {
    enum Result { case undecided, recognized }

    let minimumStroke: Double
    let requiredReversals: Int
    private var anchor: Double?
    private var direction = 0
    private(set) var reversals = 0

    init(minimumStroke: Double, requiredReversals: Int) {
        self.minimumStroke = minimumStroke
        self.requiredReversals = requiredReversals
    }

    mutating func add(x: Double) -> Result {
        if let start = anchor, abs(x - start) >= minimumStroke {
            let newDirection = x > start ? 1 : -1
            if direction != 0 && newDirection != direction {
                reversals += 1
            }
            direction = newDirection
            anchor = x
        } else if anchor == nil {
            anchor = x
        }
        return reversals >= requiredReversals ? .recognized : .undecided
    }
}

final class ZigzagGestureRecognizer: UIGestureRecognizer {
    private var detector = ZigzagDetector(minimumStroke: 30, requiredReversals: 3)
    private var trackedTouch: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let tracked = trackedTouch {
            for touch in touches where touch != tracked {
                ignore(touch, for: event)
            }
            return
        }
        guard touches.count == 1, let touch = touches.first else {
            state = .failed
            return
        }
        trackedTouch = touch
        _ = detector.add(x: Double(touch.location(in: view).x))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible, let touch = trackedTouch, touches.contains(touch) else { return }
        if detector.add(x: Double(touch.location(in: view).x)) == .recognized {
            state = .recognized
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        if state == .possible {
            state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .failed
    }

    override func reset() {
        super.reset()
        detector = ZigzagDetector(minimumStroke: 30, requiredReversals: 3)
        trackedTouch = nil
    }
}

final class SketchViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let zigzag = ZigzagGestureRecognizer(target: self, action: #selector(erase))
        view.addGestureRecognizer(zigzag)
    }

    @objc private func erase() {
        print("erase drawing")
    }
}
```

- **One finger only.** A first touch event with two fingers fails at once; a second finger arriving later is passed to `ignore(_:for:)`, the same approach as Apple's checkmark example.
- **Recognize as soon as it's certain**, in `touchesMoved`. A discrete recognizer could also wait for the finger to lift, but Apple notes that recognition that happens late "can easily be preempted by continuous gestures attached to the same view".
- **Lifting the finger before recognition fails it.** UIKit never calls the action for `.failed`.
- **Cancellation** sets `.failed` because the gesture hadn't been recognized yet; for a discrete recognizer still in `.possible`, there's nothing to report. (Apple's checkmark sample sets `.cancelled` here instead; either ends the attempt.)
- **`reset()`** builds a fresh detector. UIKit calls it "after the gesture-recognizer state has been set to" an end state, before the next touch sequence.

## Common mistakes

> [!error] A recognizer on an image view that never fires
> `UIImageView` and `UILabel` have `isUserInteractionEnabled` set to `false`. Set it to `true` on the view the recognizer is attached to.

> [!error] Adding translation or scale on every .changed
> They're totals since `.began`. Adding them each time makes the view outrun the finger. Apply the total to the value saved at `.began`, or reset with `setTranslation(.zero, in:)` and `scale = 1` after applying.

> [!error] Translation in the moving view's own coordinates
> `pan.translation(in: sticker)` measures in a coordinate system that moves with the sticker, and the drag jitters. Use the superview.

> [!error] Handling only .ended
> A continuous gesture can end with `.cancelled`. Clean-up code (restoring a transform, committing a change) must run for both.

> [!error] Expecting a single tap to fire instantly next to a double tap
> With `require(toFail:)`, the single tap waits until the double tap fails. That delay is the price of the dependency.

> [!error] A custom recognizer that stays in .possible
> If touches end and you never set `.failed`, other recognizers that require yours to fail wait for it. Fail as soon as the touches can't match, and always by the time they end.

> [!error] Forgetting reset() in a custom recognizer
> UIKit resets `state`, not your properties. Without `reset()`, the second attempt starts with the first attempt's counters.

## Exercises

````exercise
id: m27-l03-e1
type: prediction
prompt: "Using the lesson's long-press model (repeated so it compiles on its own) with a shorter duration, what does this print?"
code: |
  enum GestureState { case possible, began, changed, ended, cancelled, failed }

  enum TouchEvent {
      case down(time: Double)
      case hold(until: Double)
      case move(distance: Double)
      case up
      case cancel
  }

  struct LongPressModel {
      var minimumPressDuration = 0.5
      var allowableMovement = 10.0
      private(set) var state = GestureState.possible
      private var downTime = 0.0

      mutating func handle(_ event: TouchEvent) {
          switch (event, state) {
          case (.down(let time), .possible):
              downTime = time
          case (.hold(let time), .possible) where time - downTime >= minimumPressDuration:
              state = .began
          case (.move(let distance), .possible) where distance > allowableMovement:
              state = .failed
          case (.move, .began), (.move, .changed):
              state = .changed
          case (.up, .possible):
              state = .failed
          case (.up, .began), (.up, .changed):
              state = .ended
          case (.cancel, .began), (.cancel, .changed):
              state = .cancelled
          default:
              break
          }
      }
  }

  var press = LongPressModel()
  press.minimumPressDuration = 0.2
  let events: [TouchEvent] = [.down(time: 1.0), .hold(until: 1.1), .move(distance: 8), .hold(until: 1.3), .move(distance: 3), .move(distance: 50), .up, .move(distance: 5)]
  for event in events {
      press.handle(event)
      print(press.state)
  }
output: |
  possible
  possible
  possible
  began
  changed
  changed
  ended
  ended
hints:
  - "The hold at 1.1 is only 0.1 seconds after the touch went down."
  - "8 points is within the allowance; after .began, movement is a change."
  - "What does the default case do once the state is ended?"
solution: |
  ```output
  possible
  possible
  possible
  began
  changed
  changed
  ended
  ended
  ```

  The touch goes down at 1.0. At 1.1 only 0.1 seconds have passed, short of 0.2: still possible. Moving 8 points is within the 10-point allowance. At 1.3, 0.3 seconds have passed: began. Both moves after that are changes, including the 50-point one, because the allowance only applies before the gesture begins. Lifting ends it. The last move arrives after an end state, so no case matches and the `default: break` ignores it; in UIKit, the recognizer receives no more updates for that touch sequence and is reset before the next one.
````

````exercise
id: m27-l03-e2
type: prediction
prompt: "A pan handler applies translation two ways. The reported totals are below. What does it print?"
code: |
  let totals = [5, 15, 15, 40]
  var startPlusTotal = 0
  var resetting = 0
  var bugged = 0
  var resetOffset = 0
  for total in totals {
      startPlusTotal = 0 + total
      resetting += total - resetOffset
      resetOffset = total
      bugged += total
  }
  print(startPlusTotal, resetting, bugged)
output: |
  40 40 75
hints:
  - "resetOffset plays the role of setTranslation(.zero, in:)."
  - "The bugged version adds every total."
solution: |
  ```output
  40 40 75
  ```

  Applying the latest total to the starting value gives 40. The resetting version adds only what changed since the last call (5, 10, 0, 25), also 40: that's what `setTranslation(.zero, in:)` achieves in UIKit. The bugged version adds 5 + 15 + 15 + 40 = 75, almost twice the real movement. Note the third call: the finger didn't move, but the bugged version still moved the view by 15.
````

````exercise
id: m27-l03-e3
type: solve
prompt: |
  The zigzag detector has no way to fail, so a slow single stroke keeps the recognizer in `.possible` until the finger lifts. Add failure: return `.failed` when the finger moves **vertically** more than `maximumDrift` points away from where it started (the gesture must stay roughly horizontal). Once failed, the detector keeps returning `.failed`.

  Write `ZigzagDetector` with `add(x:y:) -> Result`, where `Result` is `undecided`, `recognized` or `failed`, so that:

  ```swift
  var a = ZigzagDetector(minimumStroke: 30, requiredReversals: 2, maximumDrift: 20)
  for (x, y) in [(100.0, 50.0), (140, 55), (100, 60), (140, 58)] {
      print(a.add(x: x, y: y))
  }
  var b = ZigzagDetector(minimumStroke: 30, requiredReversals: 2, maximumDrift: 20)
  for (x, y) in [(100.0, 50.0), (140, 75), (100, 60)] {
      print(b.add(x: x, y: y))
  }
  ```

  prints:

  ```plaintext
  undecided
  undecided
  undecided
  recognized
  undecided
  failed
  failed
  ```
starter: |
  struct ZigzagDetector {
      enum Result { case undecided, recognized, failed }

      let minimumStroke: Double
      let requiredReversals: Int
      let maximumDrift: Double

      // your properties

      init(minimumStroke: Double, requiredReversals: Int, maximumDrift: Double) {
          self.minimumStroke = minimumStroke
          self.requiredReversals = requiredReversals
          self.maximumDrift = maximumDrift
      }

      mutating func add(x: Double, y: Double) -> Result {
          // your code
          .undecided
      }
  }
hints:
  - "Store the starting y the first time add is called."
  - "Keep a hasFailed flag and check it first."
rubric:
  - The first point sets both the horizontal anchor and the starting y.
  - Vertical drift beyond maximumDrift fails, and the failure sticks.
  - Reversals are counted as in the lesson.
  - The results match the expected output exactly.
solution: |
  ```swift
  struct ZigzagDetector {
      enum Result { case undecided, recognized, failed }

      let minimumStroke: Double
      let requiredReversals: Int
      let maximumDrift: Double

      private var anchor: Double?
      private var startY = 0.0
      private var direction = 0
      private var reversals = 0
      private var hasFailed = false

      init(minimumStroke: Double, requiredReversals: Int, maximumDrift: Double) {
          self.minimumStroke = minimumStroke
          self.requiredReversals = requiredReversals
          self.maximumDrift = maximumDrift
      }

      mutating func add(x: Double, y: Double) -> Result {
          if hasFailed { return .failed }
          guard let start = anchor else {
              anchor = x
              startY = y
              return .undecided
          }
          if abs(y - startY) > maximumDrift {
              hasFailed = true
              return .failed
          }
          if abs(x - start) >= minimumStroke {
              let newDirection = x > start ? 1 : -1
              if direction != 0 && newDirection != direction {
                  reversals += 1
              }
              direction = newDirection
              anchor = x
          }
          return reversals >= requiredReversals ? .recognized : .undecided
      }
  }

  var a = ZigzagDetector(minimumStroke: 30, requiredReversals: 2, maximumDrift: 20)
  for (x, y) in [(100.0, 50.0), (140, 55), (100, 60), (140, 58)] {
      print(a.add(x: x, y: y))
  }
  var b = ZigzagDetector(minimumStroke: 30, requiredReversals: 2, maximumDrift: 20)
  for (x, y) in [(100.0, 50.0), (140, 75), (100, 60)] {
      print(b.add(x: x, y: y))
  }
  ```

  ```output
  undecided
  undecided
  undecided
  recognized
  undecided
  failed
  failed
  ```

  In the UIKit subclass, `touchesMoved` would set `state = .failed` when the detector says so. That's the "fail early" rule: a stroke that drifts downward is probably a scroll, and failing right away lets the scroll view's pan recognizer take over instead of waiting for the finger to lift.
````

````exercise
id: m27-l03-e4
type: find-errors
prompt: "A card can be dragged and double-tapped to flip. Users report the card racing ahead of the finger, the flip also triggering a single-tap action, and the card staying enlarged after a phone call. Mark every real problem."
code: |
  override func viewDidLoad() {
      super.viewDidLoad()
      let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
      let doubleTap = UITapGestureRecognizer(target: self, action: #selector(flip))
      doubleTap.numberOfTapsRequired = 2
      let singleTap = UITapGestureRecognizer(target: self, action: #selector(select))
      card.addGestureRecognizer(pan)
      card.addGestureRecognizer(doubleTap)
      card.addGestureRecognizer(singleTap)
  }

  @objc func drag(_ pan: UIPanGestureRecognizer) {
      switch pan.state {
      case .began:
          card.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
      case .changed:
          let t = pan.translation(in: card)
          card.center.x += t.x
          card.center.y += t.y
      case .ended:
          card.transform = .identity
      default:
          break
      }
  }
choices:
  - text: "The translation is added on every .changed without resetting it, so the card outruns the finger."
    correct: true
  - text: "The translation is measured in the card's own coordinates instead of its superview's."
    correct: true
  - text: "singleTap doesn't require doubleTap to fail, so a double tap also selects."
    correct: true
  - text: ".cancelled isn't handled, so the transform isn't restored when the gesture is interrupted."
    correct: true
  - text: "A view can't have more than two gesture recognizers."
    correct: false
    why: "A view can have any number of recognizers; the issue is how they interact."
  - text: "The pan should be a UISwipeGestureRecognizer to move a view."
    correct: false
    why: "Swipe is discrete and reports only a direction; dragging needs the continuous pan."
rubric:
  - I found the accumulated translation.
  - I found the wrong coordinate space.
  - I found the missing failure requirement.
  - I found the missing .cancelled case.
solution: |
  Four problems:

  1. **Accumulated totals.** Add `pan.setTranslation(.zero, in: view)` after applying, or apply the total to the center saved at `.began`.
  2. **Wrong coordinate space.** `translation(in: card)` moves with the card. Use `view`.
  3. **No failure requirement.** `singleTap.require(toFail: doubleTap)`.
  4. **`.cancelled` ignored.** Restore the transform for `.ended, .cancelled`.

  ```swift ios
  import UIKit

  final class CardViewController: UIViewController {
      private let card = UIView(frame: CGRect(x: 80, y: 200, width: 200, height: 120))

      override func viewDidLoad() {
          super.viewDidLoad()
          view.addSubview(card)
          let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
          let doubleTap = UITapGestureRecognizer(target: self, action: #selector(flip))
          doubleTap.numberOfTapsRequired = 2
          let singleTap = UITapGestureRecognizer(target: self, action: #selector(selectCard))
          singleTap.require(toFail: doubleTap)
          card.addGestureRecognizer(pan)
          card.addGestureRecognizer(doubleTap)
          card.addGestureRecognizer(singleTap)
      }

      @objc private func drag(_ pan: UIPanGestureRecognizer) {
          switch pan.state {
          case .began:
              card.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
          case .changed:
              let translation = pan.translation(in: view)
              card.center.x += translation.x
              card.center.y += translation.y
              pan.setTranslation(.zero, in: view)
          case .ended, .cancelled:
              card.transform = .identity
          default:
              break
          }
      }

      @objc private func flip() {
          print("flip")
      }

      @objc private func selectCard() {
          print("select")
      }
  }
  ```
````

````exercise
id: m27-l03-e5
type: comprehension
prompt: "A map view has your custom pan recognizer for drawing a selection rectangle, and the map's own pan for scrolling. Both start at once and the map scrolls while you draw. Which change gives drawing priority and lets the map scroll when drawing doesn't apply?"
choices:
  - text: "Make the map's pan require your recognizer to fail, and have your recognizer fail quickly when the touch isn't a drawing gesture."
    correct: true
    why: "The map's pan waits for yours; your recognizer must fail early, or scrolling is delayed."
  - text: "Return true from gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)."
    correct: false
    why: "That makes both work at once, which is exactly the current problem."
  - text: "Set cancelsTouchesInView = false on your recognizer."
    correct: false
    why: "That controls touch delivery to the view, not which recognizer wins."
  - text: "Remove the map's pan recognizer while your recognizer is in .possible."
    correct: false
    why: "Mutating the system's recognizers mid-sequence is fragile; failure requirements exist for this."
solution: |
  **A failure requirement plus fast failure.** `mapPan.require(toFail: drawPan)`, or the delegate's `gestureRecognizer(_:shouldRequireFailureOf:)` if the map's recognizer isn't yours to configure directly, makes the map wait. Then your recognizer must decide quickly: if the touch doesn't start the way a drawing gesture should (for example, it isn't preceded by a long press, or a mode isn't on), set `.failed` in `touchesBegan` or the first `touchesMoved`. Every moment it stays in `.possible` is a moment the map can't scroll.
````

## Summary

- A recognizer watches the touches hit-tested to its view before the view gets them. Image views and labels need `isUserInteractionEnabled = true`.
- Discrete recognizers go possible → recognized or failed; continuous ones go possible → began → changed… → ended or cancelled. Actions run for began, changed, ended and cancelled, never for failed. Handle `.cancelled` like `.ended`.
- `translation(in:)`, `scale` and `rotation` are totals since the gesture began. Apply them to the value saved at `.began`, or reset them after applying. Measure translation in the superview.
- `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` returning `true` lets two recognizers work at once; `gestureRecognizerShouldBegin(_:)` can veto one.
- `require(toFail:)` makes one recognizer wait for another, at the cost of delaying it.
- A custom recognizer imports `UIKit.UIGestureRecognizerSubclass`, sets `state` from the touches methods, fails early, and clears its properties in `reset()`. Keep the recognition logic in plain Swift so you can test it.
