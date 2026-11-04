---
id: m47-l03
title: UIKit and SwiftUI questions
description: "Answer UI framework questions with the documented rule behind them: where width-dependent work goes in a view controller, what happens between changing a constraint and seeing the result, why a SwiftUI view updated when you changed something it doesn't show, and why a wrapped text field loses its cursor. Each answer names the Apple behavior it rests on and the module where the course covered it."
module: m47
order: 3
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l02]
objectives:
  - Place work in the right view controller callback and justify it with what UIKit guarantees at that point.
  - Describe the path from a constraint change to a new frame on screen, including what is deferred and why.
  - Explain SwiftUI invalidation in terms of what a body evaluation read, and demonstrate it with withObservationTracking.
  - Diagnose a UIViewRepresentable bug from the order of updates between SwiftUI and UIKit.
  - Point to the module and lesson that backs each part of an answer.
terms:
  - term: Update cycle
    definition: "The pass, once per turn of the main run loop, in which UIKit runs pending constraint updates, layout and drawing for views that asked for them, then commits the changes to the render server."
  - term: Invalidation
    definition: "SwiftUI marking a view as needing a new body evaluation because something its last evaluation read has changed."
  - term: Observation tracking
    definition: "Recording which observable properties a closure reads, so a change to any of them can be reported. SwiftUI does this around each body evaluation; withObservationTracking(_:onChange:) exposes it."
  - term: Idempotent update
    definition: "An update you can apply any number of times with the same inputs and get the same result, with no side effects after the first. updateUIView must be written this way."
mastery:
  - Say why viewDidLoad is too early for size-dependent work and which callback to use instead, quoting what UIKit guarantees there.
  - Walk through a constraint change to the frame on screen without hand-waving the deferred steps.
  - Predict which property changes invalidate an observation, including through a computed property and in-place collection mutation.
  - Find an unconditional write in updateUIView and explain the user-visible bug it causes.
resources: [uikit-layoutsubviews, uikit-uiviewcontroller, uikit-nslayoutconstraint, uikit-compositional-layout, observation-tracking, swiftui-managing-model-data, swiftui-uiviewrepresentable, xcode-swiftui-performance]
cards:
  - id: m47-l03-c1
    front: Where does code that depends on the view's final width go in a view controller?
    back: "If it must run once per appearance, viewIsAppearing(_:) (traits and geometry are up to date). If it must follow every size change, viewDidLayoutSubviews(), guarded so it only acts when the width changed. Not viewDidLoad(): the size isn't final there."
  - id: m47-l03-c2
    front: What happens when you set a constraint's constant?
    back: "The layout is marked invalid and nothing moves yet. In the next update cycle UIKit runs layout (layoutSubviews applies the solved constraints), then drawing for views that asked for it, then commits to the render server. layoutIfNeeded() forces the layout part now."
  - id: m47-l03-c3
    front: Which changes invalidate a SwiftUI view that reads an @Observable model?
    back: "A change to any observable property its last body evaluation read, including properties read through a computed property or a helper. Properties it didn't read don't invalidate it."
  - id: m47-l03-c4
    front: "Does `inbox.messages[0] = \"x\"` notify a view that only read `inbox.messages.count`?"
    back: "Yes. Observation tracks whole properties, not parts of them: the view read `messages`, and an in-place mutation of `messages` is a change to that property."
  - id: m47-l03-c5
    front: Why does a wrapped UITextField jump its cursor while typing?
    back: "updateUIView sets uiView.text unconditionally. Each keystroke updates the binding, SwiftUI calls updateUIView, and writing the text again resets the selection. Guard the write with if uiView.text != text."
---

## The idea in one sentence

UI framework questions are really questions about order and guarantees: what has happened by the time your code runs, what's deferred, and what decides when something runs again.

> [!note] Sources for this lesson
> Every answer here points to the course module that covered the topic in depth, and those modules quote Apple's documentation. UIKit and SwiftUI blocks are type-checked against the iOS SDK on the course's CI runner, not run. The Observation blocks are plain Swift, compiled and run with Swift 6.3 on Linux, where the `Observation` module ships with the toolchain; SwiftUI's own tracking does the same thing around each `body` evaluation, but SwiftUI wasn't run for this lesson.

The bank already covers the first-level questions: the view controller life cycle, frame versus bounds, `setNeedsLayout` versus `layoutIfNeeded`, view identity, `onAppear` versus `task`, and how `UIViewRepresentable` works. The questions below are the ones that come after those, where the interviewer wants to know whether you've debugged it.

## A view controller question: where does width-dependent work go?

**The question:** "You show a grid whose column count depends on the screen width. Where do you compute it, and what happens on rotation?"

**Direct answer.** "Not in `viewDidLoad()`, because the view's size isn't final there. In a collection view I'd let the compositional layout compute it from its environment. If I really need a callback, it's `viewDidLayoutSubviews()`, guarded so it only does work when the width actually changed."

**Mechanism.** Module 22, lesson 2 listed what UIKit does during an appearance, from Apple's documentation: `viewWillAppear(_:)`, then trait and geometry updates, then `viewIsAppearing(_:)`, then `viewWillLayoutSubviews()`, layout, `viewDidLayoutSubviews()`. Two quotes carry the answer:

- `viewIsAppearing(_:)`: traits and geometry "aren't up to date when the system calls viewWillAppear(_:), but they are when the system calls viewIsAppearing(_:)". It runs once per appearance.
- The layout callbacks run "whenever the view performs layout, which can happen at any time while the view is visible": rotation, split view resizing, the keyboard.

So "once per appearance" work goes in `viewIsAppearing(_:)`, and work that must follow every size change goes in `viewDidLayoutSubviews()` and must be cheap and safe to repeat.

**Example.**

```swift ios
import UIKit

final class GalleryViewController: UIViewController {
    private var lastLaidOutWidth: CGFloat = 0
    private(set) var columnCount = 2

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        guard width != lastLaidOutWidth else { return }
        lastLaidOutWidth = width
        columnCount = max(2, Int(width / 160))
        // Rebuild or invalidate the grid's layout here, once per width change.
    }
}
```

The guard matters: layout can run many times at the same width (a label changing its text is enough), and rebuilding a layout on every pass is wasted work at best and a layout loop at worst.

**Trade-off.** For a collection view, Module 24, lesson 6's answer is better: `UICollectionViewCompositionalLayout`'s section provider gets `environment.container.effectiveContentSize` and is called again when the layout is invalidated, for example when the width changes on rotation. The column count lives in the layout, and the view controller has no size code at all.

**When it breaks.** Reading `view.bounds` in `viewDidLoad()` gives whatever size the view had when it was loaded, often the storyboard's or zero for a view built in code. The bug appears only on devices whose size differs from that, which is why it survives testing on one simulator.

> [!tip] Where the course covers it
> Module 22, lesson 2 (life cycle and `viewIsAppearing`), Module 23 (layout), Module 24, lesson 6 (the section provider and its environment). Bank: the view controller life cycle question and the trait collections question.

## A layout question: from constraint to pixels

**The question:** "You set `heightConstraint.constant = 200`. Walk me through everything that happens until the user sees the new height."

**Direct answer.** "Nothing visible happens immediately. Setting the constant invalidates the layout; in the next update cycle UIKit runs layout, which applies the solved constraints to frames, then drawing for views that asked for it, then commits the result to the render server, which renders the frame."

**Mechanism.** One step at a time, each from an earlier module:

1. **The constraint changes.** The Auto Layout engine needs to re-solve, and the views it affects are marked as needing layout. Your code continues; the frame still has its old value. Module 23, lesson 2 built a small constraint solver to show what "solving" means.
2. **The rest of your event handler runs.** Further changes are batched. `setNeedsLayout()` "returns immediately" and waits "for the next update cycle", so ten changes cost one layout pass (Module 27, lesson 4).
3. **The update cycle**, once per turn of the main run loop (Module 21, lesson 3 and Module 27, lesson 4): if a view called `setNeedsUpdateConstraints()`, UIKit calls its `updateConstraints()` "as part of its normal layout pass", before layout; then `layoutSubviews()` runs on views that need layout, setting frames from the solution; then `draw(_:)` runs on views that called `setNeedsDisplay()`. A frame change alone doesn't redraw a view's content.
4. **The commit.** The main thread sends the changed layer tree to the render server, which renders it on the GPU for the next display refresh. If the main thread misses the commit deadline, that frame is late: a hitch (Module 27, lesson 4; Module 43, lesson 2 for hangs).

**Example.** This is why animating a constraint needs `layoutIfNeeded()` inside the animation block: it forces step 3's layout to happen there, so the frame change is captured by the animation. The bank's layout-pass question has the code.

**Trade-off.** Deferring layout is what makes batching possible. The cost is that code reading a frame right after changing a constraint sees the old value. Calling `layoutIfNeeded()` to "fix" that throughout a screen undoes the batching.

**When it breaks.** A `layoutSubviews()` that changes a constraint or calls `setNeedsLayout()` on its own view can schedule another pass every time it runs. Use the debugger's view hierarchy and Instruments to find the view that keeps relayouting (Module 23, lesson 6; Module 33, lesson 6).

## A SwiftUI question: why did this view update?

**The question:** "A profile header shows the user's name. Profiling shows its `body` runs when the avatar changes, and also when the last name changes even though the header only uses `displayName`. Explain both."

**Direct answer.** "A view is invalidated when a property its last `body` evaluation read changes. If it re-ran when the avatar changed, it read the avatar somewhere. And reading `displayName` is reading `firstName` and `lastName`, because the computed property reads them during `body`."

**Mechanism.** With the `@Observable` macro, each stored property's getter reports an access to the current tracking scope. SwiftUI evaluates `body` inside such a scope, and Apple's "Managing model data in your app" says a view "forms a dependency on an observable data model object … when the view's `body` property reads a property of the object". Computed properties aren't tracked themselves; the stored properties they read are. Module 36, lesson 5 and Module 39, lesson 4 covered this, and Module 39 noted that a computed **view** property isn't a dependency boundary either.

**Example.** `withObservationTracking(_:onChange:)` runs a closure, records which observable properties it read, and calls `onChange` once, the first time any of them is about to change. That's SwiftUI's mechanism in a form you can run:

```swift
import Observation

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class Profile {
    var firstName = "Ada"
    var lastName = "Lovelace"
    var avatarURL = "a.png"

    var displayName: String { "\(firstName) \(lastName)" }
}

@available(macOS 14, iOS 17, *)
@MainActor
func renderHeader(_ profile: Profile) {
    withObservationTracking {
        print("header: \(profile.displayName)")
    } onChange: {
        print("  header invalidated")
    }
}

if #available(macOS 14, iOS 17, *) {
    let profile = Profile()
    renderHeader(profile)
    print("set avatarURL")
    profile.avatarURL = "b.png"
    print("set lastName")
    profile.lastName = "Byron"
    print("set firstName")
    profile.firstName = "Augusta"
}
```

```output
header: Ada Lovelace
set avatarURL
set lastName
  header invalidated
set firstName
```

- `avatarURL` wasn't read, so changing it doesn't invalidate the header. If the real header did re-run, something in its `body` read `avatarURL`: a shared helper, an `if` on the avatar, a child view built inline.
- `lastName` was read through `displayName`, so changing it invalidates.
- Changing `firstName` prints nothing because tracking is one-shot: after `onChange` fires, the scope is finished. SwiftUI starts a new scope on the next `body` evaluation, which would record the dependencies again.

Here's the header the way you'd write it, with the avatar in its own view so the name and the avatar have separate dependencies:

```swift ios
import SwiftUI

@MainActor
@Observable
final class ProfileModel {
    var firstName = "Ada"
    var lastName = "Lovelace"
    var avatarURL: URL?
}

struct ProfileHeader: View {
    let profile: ProfileModel

    var body: some View {
        HStack {
            AvatarView(profile: profile)
            Text("\(profile.firstName) \(profile.lastName)")
        }
    }
}

struct AvatarView: View {
    let profile: ProfileModel

    var body: some View {
        AsyncImage(url: profile.avatarURL)
            .frame(width: 44, height: 44)
    }
}
```

`ProfileHeader`'s body reads the two names; `AvatarView`'s body reads the URL. A new avatar re-runs only `AvatarView`'s body.

**Trade-off.** Splitting views to narrow dependencies is cheap, but each split is another type to name and pass data to. Do it where Instruments shows a real cost (Module 39, lesson 5), not everywhere.

**When it breaks.** Observation tracks properties, not parts of them. A view that reads `inbox.messages.count` depends on `messages`, so editing one message invalidates it even though the count didn't change. Exercise 4 proves it.

## An interop question: the jumping cursor

**The question:** "You wrapped a `UITextField` in a `UIViewRepresentable`. When the user types in the middle of the text, the cursor jumps to the end. Why?"

**Direct answer.** "`updateUIView` writes `text` back to the field on every update. Each keystroke updates the binding, SwiftUI calls `updateUIView` because the state changed, and assigning `text`, even the same string, resets the selection."

**Mechanism.** Module 40, lesson 2: SwiftUI calls `updateUIView(_:context:)` "for any changes affecting the corresponding UIKit view", and it can run many times with the same values, so it has to be idempotent: write only what differs. Module 40, lesson 3 added the update loop between SwiftUI state, `updateUIView` and the coordinator's delegate callbacks.

**Example.** The fixed version, with the guard:

```swift ios
import SwiftUI
import UIKit

struct CodeField: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        if uiView.text != text {
            uiView.text = text
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func editingChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }
    }
}
```

After a keystroke the field already shows the new text, the binding receives the same string, and `updateUIView` sees no difference, so it doesn't touch the field.

**Trade-off.** The guard compares strings on every update, which is trivially cheap next to resetting the field. The real cost is discipline: every property you push into the UIKit view needs the same treatment.

**When it breaks.** If the SwiftUI side transforms the text (uppercases it, trims it, limits its length), the field and the binding differ after every keystroke, the guard passes and the cursor jumps again. Then you either restore the selection yourself after writing, or do the transformation in the coordinator before the field changes. This lesson doesn't verify the exact selection behavior of `UITextField` after an assignment; check it in the simulator before you rely on the details.

## Common mistakes

> [!error] Answering with the callback list instead of the guarantee
> Reciting `viewDidLoad`, `viewWillAppear`, `viewIsAppearing`… doesn't answer "where does this go". Say what's true at the point you chose: size known, runs once, runs on every layout.

> [!error] "SwiftUI re-renders everything"
> SwiftUI re-evaluates `body` for invalidated views. Say what invalidated them; "everything" is how people describe a dependency they didn't know they had.

> [!error] Treating withObservationTracking as a subscription
> It fires once and stops. Code that wants every change has to start tracking again inside or after `onChange`, which is what SwiftUI does by re-evaluating `body`.

## Exercises

````exercise
id: m47-l03-e1
type: comprehension
prompt: "You add a gradient layer that must match the view's bounds, including after rotation. Where do you update the layer's frame?"
choices:
  - text: "In viewDidLoad(), right after creating the layer."
    correct: false
    why: "The view's size isn't final there, and viewDidLoad runs once, so rotation wouldn't update it."
  - text: "In viewIsAppearing(_:), because traits and geometry are up to date."
    correct: false
    why: "Geometry is correct there, but it runs once per appearance; a rotation while the screen is visible wouldn't update the layer."
  - text: "In viewDidLayoutSubviews() (or the view's layoutSubviews()), because layers aren't laid out by Auto Layout and those run after every layout."
    correct: true
    why: "Layers don't take part in Auto Layout, so you size them after layout, every time layout runs."
  - text: "In viewDidAppear(_:), after animations finish."
    correct: false
    why: "Too late (a visible jump on first display) and it doesn't run on rotation."
solution: |
  Layers aren't resized by constraints. Setting `gradientLayer.frame = view.bounds` in `viewDidLayoutSubviews()`, or in a custom view's `layoutSubviews()`, keeps it correct after every layout pass, including rotation. It's cheap and idempotent, so running it many times is fine.
````

````exercise
id: m47-l03-e2
type: prediction
prompt: "A badge reads only the number of messages. What does the program print?"
code: |
  import Observation

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Inbox {
      var messages = ["hi", "lunch?"]
      var filter = ""
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  func renderBadge(_ inbox: Inbox) {
      withObservationTracking {
          print("badge: \(inbox.messages.count)")
      } onChange: {
          print("  badge invalidated")
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let inbox = Inbox()
      renderBadge(inbox)
      print("edit first message")
      inbox.messages[0] = "hello"
      renderBadge(inbox)
      print("change filter")
      inbox.filter = "lunch"
      print("append")
      inbox.messages.append("ok")
  }
output: |
  badge: 2
  edit first message
    badge invalidated
  badge: 2
  change filter
  append
    badge invalidated
solution: |
  The badge read `messages` (to get its count), so any change to `messages` invalidates it, including replacing one element: Observation tracks the property, not the count. `renderBadge` is called again to start a new scope, as SwiftUI would re-run `body`. `filter` wasn't read, so changing it prints nothing. The append changes `messages` again.

  ```output
  badge: 2
  edit first message
    badge invalidated
  badge: 2
  change filter
  append
    badge invalidated
  ```

  If this matters for performance, store the count separately or move the badge into a view that receives the count as a plain value from a parent that already depends on `messages`.
````

````exercise
id: m47-l03-e3
type: find-errors
prompt: "This wrapper shows a UISlider bound to a SwiftUI value. Which statements describe real problems?"
code: |
  struct VolumeSlider: UIViewRepresentable {
      @Binding var volume: Float

      func makeUIView(context: Context) -> UISlider {
          UISlider()
      }

      func updateUIView(_ uiView: UISlider, context: Context) {
          uiView.addTarget(context.coordinator,                     // line A
                           action: #selector(Coordinator.changed(_:)),
                           for: .valueChanged)
          uiView.value = volume                                     // line B
      }

      func makeCoordinator() -> Coordinator {
          Coordinator(volume: $volume)                              // line C
      }

      @MainActor
      final class Coordinator: NSObject {
          var volume: Binding<Float>
          init(volume: Binding<Float>) { self.volume = volume }
          @objc func changed(_ sender: UISlider) { volume.wrappedValue = sender.value }
      }
  }
choices:
  - text: "Line A: adding the target in updateUIView repeats setup work on every update; it belongs in makeUIView."
    correct: true
    why: "updateUIView runs many times. One-time setup goes where the view is created."
  - text: "Line B: the unconditional write can fight the user's drag; guard it with if uiView.value != volume."
    correct: true
    why: "Writes in updateUIView should only happen when the value differs."
  - text: "Line C: creating the coordinator with a binding is wrong; coordinators can't hold bindings."
    correct: false
    why: "Holding a binding is the usual pattern. It should also be refreshed in updateUIView, which this code doesn't do, but line C itself is fine."
  - text: "The coordinator's binding is never refreshed in updateUIView, so after the representable is recreated it may write to a stale binding."
    correct: true
    why: "Module 40, lesson 3: set context.coordinator.volume = $volume in updateUIView."
rubric:
  - Moves addTarget to makeUIView.
  - Guards the value write.
  - Refreshes the coordinator's binding on each update.
solution: |
  Three problems: setup in `updateUIView`, an unconditional write, and a coordinator binding that's set once and never refreshed. (Apple's page for `addTarget(_:action:for:)` says it's "safe to call this method multiple times with the same values for the target and action parameters", so this isn't a crash or a double call; it's setup in the wrong place, repeated on every update.) The fixed shape: `addTarget` in `makeUIView`; in `updateUIView`, `context.coordinator.volume = $volume` and then `if uiView.value != volume { uiView.value = volume }`.
````

````exercise
id: m47-l03-e4
type: solve
prompt: "Prove or disprove: \"A view that reads only `cart.items.count` isn't invalidated when the quantity of an existing item changes.\" Write an `@Observable` `Cart` whose `items` is an array of `struct Item { var name: String; var quantity: Int }`, track a closure that reads only the count, change one item's quantity in place, and print what happens."
starter: |
  import Observation

  struct Item {
      var name: String
      var quantity: Int
  }

  // Cart, a tracking function, and the experiment.
rubric:
  - Uses withObservationTracking around a read of items.count only.
  - Mutates one element's quantity in place.
  - "States the conclusion: the claim is false, because tracking is per property."
  - Guards the Observation code with availability, as the course's examples do.
solution: |
  ```swift
  import Observation

  struct Item {
      var name: String
      var quantity: Int
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  @Observable
  final class Cart {
      var items = [Item(name: "Tea", quantity: 1), Item(name: "Milk", quantity: 2)]
  }

  @available(macOS 14, iOS 17, *)
  @MainActor
  func watchCount(_ cart: Cart) {
      withObservationTracking {
          print("count: \(cart.items.count)")
      } onChange: {
          print("  invalidated")
      }
  }

  if #available(macOS 14, iOS 17, *) {
      let cart = Cart()
      watchCount(cart)
      print("tea quantity 1 -> 3")
      cart.items[0].quantity = 3
  }
  ```

  ```output
  count: 2
  tea quantity 1 -> 3
    invalidated
  ```

  The claim is false. `items[0].quantity = 3` is an in-place mutation of the `items` property, and the closure read `items`. If a badge showing the count is expensive, pass it the count as a plain `Int` from a parent, so the badge's own body doesn't read `items`.
````

````exercise
id: m47-l03-e5
type: design
prompt: "An interviewer asks: \"What's the difference between putting work in `viewWillAppear(_:)` and in `viewIsAppearing(_:)`?\" Answer in the five-part shape from lesson 1, and say what you'd still put in `viewWillAppear(_:)`."
rubric:
  - "Direct answer: both run on every appearance, but only viewIsAppearing(_:) sees up-to-date traits and geometry."
  - Mechanism quotes or paraphrases the documented order (traits and geometry are updated between the two calls).
  - Example of view updates that depend on size or traits going in viewIsAppearing(_:).
  - Names Apple's remaining uses for viewWillAppear(_:) (work before the transition starts, such as alongside animations through the transition coordinator, and balanced callbacks that don't depend on geometry).
  - "Mentions that viewIsAppearing(_:) runs once per appearance, unlike the layout callbacks."
solution: |
  - **Direct answer:** "Both run each time the view is about to appear, but traits and geometry are only up to date in `viewIsAppearing(_:)`."
  - **Mechanism:** "Between the two calls, UIKit adds the view to the hierarchy and updates its trait collection and geometry. Apple's page says to use `viewIsAppearing(_:)` to update your views for that reason."
  - **Example:** "Choosing a compact or regular layout from the size class, or scrolling to a selected row that depends on the final height, goes in `viewIsAppearing(_:)`."
  - **Trade-off:** "It runs once per appearance, so it's not a replacement for the layout callbacks when the size changes while the screen is visible."
  - **What stays in `viewWillAppear(_:)`:** "Things that must start before the transition, like animating alongside it with the transition coordinator, and balanced setup like registering for notifications there and unregistering in `viewDidDisappear(_:)`."

  Module 22, lesson 2 has the full order and the quotes.
````

````exercise
id: m47-l03-e6
type: design
prompt: "You're asked: \"An existing UIKit app needs a new settings screen in SwiftUI, embedded as part of an existing view controller, not pushed as a full screen. How do you do it, and what can go wrong?\" Outline your answer: the steps, the data flow in both directions, and two things that go wrong. Name the course lessons you'd draw on."
rubric:
  - "Uses UIHostingController added as a child view controller (addChild, add the view, constrain it, didMove(toParent:)), not just its view as a subview."
  - "Data in: the root view is a value, so either pass an @Observable model the UIKit side also holds, or set rootView again when data changes."
  - Events out through closures or the shared model, with weak captures to avoid a cycle between the controller and the hosting controller's root view.
  - "Sizing: mentions sizingOptions (or invalidating the intrinsic size) so Auto Layout follows the SwiftUI content."
  - Points to Module 40, lessons 1 and 5, and to Module 22's containment material.
solution: |
  - **Embed as a child.** Create `UIHostingController(rootView: SettingsView(model: model))`, call `addChild`, add its view, constrain it, then `didMove(toParent:)`. Adding only the view skips containment, so the hosting controller misses appearance and trait callbacks (Module 40, lesson 1; the bank's containment question).
  - **Data in.** The root view is a copy. Share an `@Observable` model that both sides hold, so changes on either side show up in SwiftUI without reassigning `rootView` (Module 40, lesson 5).
  - **Events out.** Closures on the view (`onSignOut`) or methods on the model. A closure that captures the parent controller strongly, stored in a view the controller owns through the hosting controller, is a cycle: capture weakly (Module 40, lesson 1, "The cycle hiding in the closure").
  - **Sizing.** If the embedded content should drive its container's height, set `sizingOptions = .intrinsicContentSize` so Auto Layout follows the SwiftUI content.
  - **Isolation.** Keep the shared model on the main actor; both frameworks read it on the main thread (Module 40, lesson 5).

  Two things that go wrong: the view appears but never updates because the model was copied into the root view instead of shared, and the parent controller never deallocates because of the closure cycle.
````

## Summary

- Answer UI questions with guarantees, not callback names: in `viewIsAppearing(_:)` traits and geometry are current and it runs once per appearance; layout callbacks run on every layout and must be cheap and repeatable. For collection views, the compositional layout's environment is the better place for width-dependent decisions.
- A constraint change only invalidates layout. In the next update cycle UIKit lays out, draws views that asked for it, and commits to the render server; `layoutIfNeeded()` forces the layout step now.
- A SwiftUI view is invalidated by changes to what its last `body` evaluation read, including through computed properties and helpers. Observation tracks whole properties, so an in-place change to one element invalidates a view that read only the count. `withObservationTracking` shows it in a few lines and fires once.
- In `UIViewRepresentable`, `updateUIView` runs often and must write only what differs; an unconditional write is the jumping-cursor bug. Set up targets in `makeUIView` and refresh the coordinator's binding on each update.
