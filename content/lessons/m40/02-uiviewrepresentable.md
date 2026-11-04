---
id: m40-l02
title: Wrapping UIKit views with UIViewRepresentable
description: "A UIViewRepresentable is a SwiftUI view that describes a UIKit view: SwiftUI calls makeUIView once, updateUIView whenever something that affects it changes, and dismantleUIView when it goes away. You wrap an existing UIKit component, run a model of that life cycle in plain Swift to see why updates must be cheap and idempotent, answer size proposals with sizeThatFits for a wrapping label, and stop a video player cleanly when the view leaves the screen."
module: m40
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l01]
objectives:
  - Wrap a UIKit view in a UIViewRepresentable with makeUIView(context:) and updateUIView(_:context:).
  - Explain when SwiftUI calls each method and what it controls on the UIKit view.
  - Write updateUIView so it does no redundant work and is safe to call any number of times.
  - Read the environment and the transaction from the context.
  - Answer size proposals with sizeThatFits(_:uiView:context:) (iOS 16).
  - Release resources in the static dismantleUIView(_:coordinator:).
terms:
  - term: UIViewRepresentable
    definition: "A SwiftUI protocol (Body == Never) for a view that creates and manages a UIView. You implement makeUIView(context:) and updateUIView(_:context:); sizeThatFits, dismantleUIView and makeCoordinator are optional."
  - term: makeUIView(context:)
    definition: "Creates the UIKit view and configures its initial state. Apple: the system calls it only once, when it creates the view for the first time."
  - term: updateUIView(_:context:)
    definition: "Called for any changes affecting the UIKit view. It pushes the representable's current values into the existing view. Make it idempotent and cheap."
  - term: dismantleUIView(_:coordinator:)
    definition: "A static method SwiftUI calls before removing the UIKit view, for clean-up such as stopping playback or removing observers. Being static, it can't read the representable's properties."
  - term: ProposedViewSize
    definition: "SwiftUI's size proposal: optional width and height. nil in a dimension means 'what's your ideal size?'. sizeThatFits(_:uiView:context:) receives it and returns a CGSize, or nil for the default sizing."
mastery:
  - Wrap an existing custom UIView so SwiftUI can show it, with its inputs as let properties.
  - Guard each property write in updateUIView and say what goes wrong without the guard.
  - Predict the sequence of make, update and dismantle calls for a series of state changes.
  - Make a multi-line UILabel wrap correctly inside SwiftUI with sizeThatFits.
  - Move clean-up into dismantleUIView and explain why it can't use self.
resources: [uikit-uiview, uikit-intrinsic-content-size, swiftui-layout, swiftui-environment, swiftui-environmentvalues, swiftui-declaring-custom-view]
cards:
  - id: m40-l02-c1
    front: When does SwiftUI call makeUIView and when updateUIView?
    back: "makeUIView once, when it creates the view for the first time. updateUIView for any change affecting the view. In practice it also runs right after makeUIView (observed, not stated by Apple), so write it to set every value-dependent property."
  - id: m40-l02-c2
    front: Why guard writes in updateUIView with if uiView.x != x?
    back: "updateUIView can run many times with the same values. Unconditional writes redo work (rebuilding subviews, reloading, resetting a cursor or scroll position, restarting an animation). Writing only what changed makes it cheap and idempotent."
  - id: m40-l02-c3
    front: Which UIKit view properties must you never set on a represented view?
    back: "center, bounds, frame and transform. Apple: SwiftUI fully controls them, and setting them yourself 'results in undefined behavior'. Size it from SwiftUI with frame modifiers or sizeThatFits."
  - id: m40-l02-c4
    front: A wrapped multi-line UILabel doesn't wrap in SwiftUI. What's the fix?
    back: "Implement sizeThatFits(_:uiView:context:) (iOS 16): take proposal.width, ask uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)), return that height. Return nil for proposals you don't handle."
  - id: m40-l02-c5
    front: Why can't dismantleUIView read the representable's properties?
    back: "It's a static method: static func dismantleUIView(_ uiView: UIViewType, coordinator: Coordinator). It gets only the view and the coordinator. Anything clean-up needs must live on one of them."
---

## The idea in one sentence

**A `UIViewRepresentable` is a description of a UIKit view**: SwiftUI creates the real `UIView` once, then calls your update method to make that view match the description every time something relevant changes.

> [!note] About this lesson's code
> UIKit and SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior is quoted from Apple's pages for `UIViewRepresentable`, `makeUIView(context:)`, `updateUIView(_:context:)`, `sizeThatFits(_:uiView:context:)`, `dismantleUIView(_:coordinator:)`, `UIViewRepresentableContext` and `animate(changes:completion:)`, read in November 2026. The plain-Swift life-cycle model and the diagnostic were compiled and run with Swift 6.3; the model follows the documented rules, not SwiftUI's implementation. Nothing was run in the simulator.

## Why you need it

Lesson 1 put SwiftUI inside UIKit. Now the other direction: a SwiftUI screen that needs a UIKit view. The reasons are concrete:

- **Your own UIKit components.** The app has a chart, a rating control or a rich text editor written in UIKit years ago, tested and accessible. Rewriting it to use it on one new SwiftUI screen is the wrong first move.
- **UIKit views with no SwiftUI equivalent**, or with features the SwiftUI version doesn't expose.
- **Third-party SDKs** that hand you a `UIView`.

The tool is `UIViewRepresentable`. Apple: "A wrapper for a UIKit view that you use to integrate that view into your SwiftUI view hierarchy."

## The protocol

`UIViewRepresentable` refines `View` with `Body == Never`: you don't write `body`. Instead:

| Requirement | When SwiftUI calls it | Your job |
| --- | --- | --- |
| `makeUIView(context:)` | "only once, when it creates your view for the first time" | Create the view, set up what never changes |
| `updateUIView(_:context:)` | "for any changes affecting the corresponding UIKit view" | Make the view match the representable's current values |
| `sizeThatFits(_:uiView:context:)` (optional, iOS 16) | During layout, possibly "more than once with different proposed sizes" | Answer size proposals, or return `nil` |
| `static dismantleUIView(_:coordinator:)` (optional) | Before the view is removed | Clean up: stop, remove observers |
| `makeCoordinator()` (optional) | Before `makeUIView` | Create an object for delegate callbacks (lesson 3) |

The associated type `UIViewType` is inferred from what `makeUIView` returns.

And one rule with no method attached, in a warning box on the protocol's page: "SwiftUI fully controls the layout of the UIKit view's `center`, `bounds`, `frame`, and `transform` properties. Don't directly set these layout-related properties on the view managed by a `UIViewRepresentable` instance from your own code because that conflicts with SwiftUI and results in undefined behavior." You size and place a wrapped view the SwiftUI way: `.frame`, padding, stacks, and `sizeThatFits`.

## A first wrapper

Here's a component from an existing UIKit app: a star rating view that rebuilds its image views whenever `rating` changes. The SwiftUI wrapper is the last struct.

```swift ios
import SwiftUI
import UIKit

final class StarRatingView: UIView {
    let maximum = 5
    private let stack = UIStackView()

    var rating = 0 {
        didSet { rebuildStars() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Rating"
        rebuildStars()
    }

    required init?(coder: NSCoder) {
        fatalError("StarRatingView is created in code")
    }

    private func rebuildStars() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for index in 0..<maximum {
            let name = index < rating ? "star.fill" : "star"
            let imageView = UIImageView(image: UIImage(systemName: name))
            imageView.tintColor = .systemYellow
            stack.addArrangedSubview(imageView)
        }
        accessibilityValue = "\(rating) of \(maximum) stars"
    }
}

struct StarRating: UIViewRepresentable {
    let rating: Int

    func makeUIView(context: Context) -> StarRatingView {
        StarRatingView()
    }

    func updateUIView(_ uiView: StarRatingView, context: Context) {
        if uiView.rating != rating {
            uiView.rating = rating
        }
    }
}

struct ReviewRow: View {
    let title: String
    let rating: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            StarRating(rating: rating)
                .fixedSize()
        }
    }
}
```

Line by line, the wrapper:

- `let rating: Int` is the **input**. A representable is a SwiftUI view struct, recreated by its parent's `body` with fresh values just like `Text("…")`. It holds no state of its own.
- `makeUIView` creates the view and returns it. It doesn't set `rating`; `updateUIView` does that. Keeping all value-dependent configuration in one place means there's one code path to get right. This relies on SwiftUI calling `updateUIView` right after `makeUIView`, which is how it behaves in practice; Apple's pages don't state it in so many words. If you'd rather not rely on it, set the initial values in `makeUIView` too: with guarded writes, the first update then does nothing.
- `updateUIView` gets the **existing** view and writes the new value **only if it differs**. The next section is about why.
- `Context` is a type alias for `UIViewRepresentableContext<StarRating>`, which carries the coordinator, the environment and the transaction.
- In `ReviewRow`, `.fixedSize()` tells SwiftUI to use the stars' ideal size instead of stretching them to fill the proposal. Without it, how the stack view distributes extra space decides what you see. Sizing gets its own section below.

## updateUIView: cheap and idempotent

Apple's description of `updateUIView` is "SwiftUI calls this method for any changes affecting the corresponding UIKit view." It doesn't say "only when your inputs changed", and in practice the parent's `body` runs for many reasons. So treat `updateUIView` as **"make the view match these values"**: it may run with the same values many times, and every run must be cheap and leave the view in the same state. That's idempotence.

To see what an unguarded write costs, here's a model. A host plays SwiftUI's role: it calls `make` the first time it renders a representable and `update` every time. The fake view counts how often it rebuilds, like `StarRatingView` rebuilding its image views:

```swift
final class FakeStarView {
    private(set) var rebuilds = 0

    var rating = 0 {
        didSet { rebuilds += 1 }
    }
}

protocol RepresentableModel {
    associatedtype ViewType
    func makeView() -> ViewType
    func updateView(_ view: ViewType)
}

struct UnguardedStars: RepresentableModel {
    let rating: Int

    func makeView() -> FakeStarView { FakeStarView() }

    func updateView(_ view: FakeStarView) {
        view.rating = rating
    }
}

struct GuardedStars: RepresentableModel {
    let rating: Int

    func makeView() -> FakeStarView { FakeStarView() }

    func updateView(_ view: FakeStarView) {
        if view.rating != rating {
            view.rating = rating
        }
    }
}

final class FakeHost<Representable: RepresentableModel> {
    private(set) var view: Representable.ViewType?
    private(set) var log: [String] = []

    func render(_ representable: Representable) {
        if view == nil {
            view = representable.makeView()
            log.append("make")
        }
        if let view {
            representable.updateView(view)
            log.append("update")
        }
    }
}

// The parent's body runs six times. The rating only changes twice.
let ratings = [3, 3, 3, 4, 4, 5]

let unguarded = FakeHost<UnguardedStars>()
let guarded = FakeHost<GuardedStars>()
for rating in ratings {
    unguarded.render(UnguardedStars(rating: rating))
    guarded.render(GuardedStars(rating: rating))
}

print(guarded.log.joined(separator: " "))
print("unguarded rebuilds:", unguarded.view?.rebuilds ?? 0)
print("guarded rebuilds:  ", guarded.view?.rebuilds ?? 0)
```

```output
make update update update update update update
unguarded rebuilds: 6
guarded rebuilds:   3
```

Six body runs, one `make`, six `update`s. The unguarded wrapper rebuilds the stars six times; the guarded one three times (0 to 3, 3 to 4, 4 to 5). For stars that's a few wasted image views. For other UIKit views the unguarded write is a **bug you can see**:

- `UITextView.text = text` on every update moves the cursor to the end while the user is typing in the middle (lesson 3).
- `UIScrollView.contentOffset = …` jumps the scroll position on every unrelated state change.
- Reloading a table or a web view on every update discards the user's place.
- Restarting an animation or video every update makes it stutter.

The guard is `if uiView.property != newValue`. When the UIKit view's property type isn't `Equatable`, or the comparison is expensive, store the last value you applied (on the coordinator, lesson 3) and compare with that.

## The context

`updateUIView` and `makeUIView` receive a `UIViewRepresentableContext`, which Apple describes as "Contextual information about the state of the system that you use to create and update your UIKit view." Three properties matter:

- **`context.environment`**, the SwiftUI environment at this point in the tree. UIKit views don't see SwiftUI's environment by themselves, so you copy what you need: `context.environment.isEnabled`, `.colorScheme`, `.dynamicTypeSize`, or your own `@Entry` values.
- **`context.transaction`**, the current transaction, including its `animation` if the change happened inside `withAnimation`.
- **`context.coordinator`**, the object from `makeCoordinator()` (lesson 3).

Reading the environment, so a disabled SwiftUI container dims the UIKit view too:

```swift ios
import SwiftUI
import UIKit

struct ProgressRing: UIViewRepresentable {
    let progress: Float

    func makeUIView(context: Context) -> UIProgressView {
        UIProgressView(progressViewStyle: .default)
    }

    func updateUIView(_ uiView: UIProgressView, context: Context) {
        let animated = context.transaction.animation != nil
        if uiView.progress != progress {
            uiView.setProgress(progress, animated: animated)
        }
        let alpha: CGFloat = context.environment.isEnabled ? 1 : 0.4
        if uiView.alpha != alpha {
            uiView.alpha = alpha
        }
    }
}
```

`UIProgressView` stands in for "a UIKit view" here; SwiftUI has `ProgressView`, which you'd use for real. What matters is the pattern: the SwiftUI side says `withAnimation { progress = 0.8 }` and the UIKit side animates because it checked the transaction.

> [!version] context.animate(changes:completion:) (iOS 18)
> From iOS 18 the context has `animate(changes:completion:)`. Apple: "When you start a SwiftUI animation using `withAnimation(_:_:)` and have a mutated SwiftUI state that causes the representable object to update, use this method to animate changes in the representable object using the same `Animation` timing." It runs your UIKit property changes inside the transaction's animation, so the UIKit view moves with the same curve as the SwiftUI views around it. With an iOS 17 deployment target, check `#available(iOS 18, *)` first.

## Sizing: sizeThatFits

Module 34 lesson 6 described SwiftUI layout as a negotiation: the parent proposes a size, the child chooses its own. A represented UIKit view takes part through `sizeThatFits(_:uiView:context:)` (iOS 16). Apple: "Given a proposed size, returns the preferred size of the composite view", and "Returning a value of `nil` indicates that the system should use the default sizing algorithm." It "may be called more than once with different proposed sizes during the same layout pass", and "one of the values returned from this function will always be used as the actual size."

The classic case is a multi-line `UILabel`. A label can't know how tall it is until it knows how wide it may be, and only the proposal says that:

```swift ios
import SwiftUI
import UIKit

struct WrappingLabel: UIViewRepresentable {
    let attributedText: NSAttributedString

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else {
            return nil
        }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }
}
```

- `proposal.width` is `nil` when SwiftUI asks for the ideal size, and can be `.infinity` when it asks for the maximum. Neither gives a width to wrap at, so the method returns `nil` and lets SwiftUI use its default for those.
- For a real width, `UILabel.sizeThatFits(_:)` (UIKit's own method on `UIView`) measures the text wrapped at that width. The wrapper takes the full width, like a paragraph, and the measured height.
- Why wrap a label at all? SwiftUI's `Text` handles `AttributedString`. The realistic reason is existing code: an `NSAttributedString` produced by an HTML or Markdown pipeline you already ship, with attributes `Text` doesn't render.

Without `sizeThatFits`, nothing hands the label a width to wrap at, and Apple's pages for the protocol don't describe what the default sizing does instead. (A single unwrapped line is the symptom people usually report; it wasn't checked in the simulator for this lesson.) When a wrapped view sizes itself wrong, this method is where you fix it.

## Clean-up: dismantleUIView

When the representable leaves the hierarchy, SwiftUI removes the UIKit view. Before that, it calls `dismantleUIView(_:coordinator:)`. Apple: "Use this method to perform additional clean-up work related to your custom view. For example, you might use this method to remove observers or update other parts of your SwiftUI interface."

A video clip that must stop playing when the view goes away, not when ARC gets around to it:

```swift ios
import AVFoundation
import SwiftUI
import UIKit

final class PlayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

struct ClipPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        view.player = player
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        // url is fixed for this view's lifetime. To play a different clip,
        // give ClipPlayer a new identity with .id(url).
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.player?.pause()
        uiView.player = nil
    }
}
```

- **It's `static`.** It receives the view and the coordinator, nothing else. The coordinator is `()` here because `ClipPlayer` has none; `Coordinator` defaults to `Void`.
- **`updateUIView` is empty on purpose**, with a comment that says why. If `url` could change, the simplest correct answer is a new identity (`.id(url)`, Module 36 lesson 5): SwiftUI dismantles the old view and makes a new one.
- AVKit's SwiftUI `VideoPlayer` exists; wrapping your own `AVPlayerLayer` view is what you do when you need the bare layer without playback controls.

Because it's static, `dismantleUIView` can't read `url` or any other property. The compiler error, shown with a plain-Swift protocol that has the same shape:

```swift no-compile instance member 'clipName' cannot be used on type 'LoopingClip'
protocol RepresentableModel {
    associatedtype ViewType
    func makeView() -> ViewType
    func updateView(_ view: ViewType)
    static func dismantleView(_ view: ViewType)
}

final class ClipView {
    var isPlaying = false
}

struct LoopingClip: RepresentableModel {
    let clipName: String

    func makeView() -> ClipView {
        let view = ClipView()
        view.isPlaying = true
        return view
    }

    func updateView(_ view: ClipView) {}

    static func dismantleView(_ view: ClipView) {
        print("stopping \(clipName)")
        view.isPlaying = false
    }
}
```

Swift 6.3 says: `error: instance member 'clipName' cannot be used on type 'LoopingClip'`. If clean-up needs data, put it on the view or on the coordinator when you create them.

## Common mistakes

> [!error] Setting frame, bounds, center or transform on the wrapped view
> Apple: SwiftUI fully controls them, and setting them "results in undefined behavior." Size with SwiftUI modifiers and `sizeThatFits`; move and rotate with SwiftUI modifiers on the representable.

> [!error] Configuring the view only in makeUIView
> `makeUIView` runs once. A value set there never updates when the input changes. Set value-dependent properties in `updateUIView`.

> [!error] Creating a new view in updateUIView
> `updateUIView` receives the existing view. Building a new one there does nothing visible, because SwiftUI keeps showing the one `makeUIView` returned, and it throws away work each time.

> [!error] Unguarded writes in updateUIView
> The method runs for any relevant change, often with the same values. Unconditional writes reset cursors, scroll positions and animations. Guard with `if uiView.x != x`.

> [!error] Reading the representable's properties in dismantleUIView
> It's static, so Swift reports `instance member '…' cannot be used on type '…'`, as in the `LoopingClip` example. Put what clean-up needs on the view or the coordinator.

## Exercises

````exercise
id: m40-l02-e1
type: prediction
prompt: "The host model with a representable that logs what it writes. The parent renders four times, then the view is removed. What does it print?"
code: |
  final class FakeLabel {
      var text = ""
  }

  protocol RepresentableModel {
      associatedtype ViewType
      func makeView() -> ViewType
      func updateView(_ view: ViewType)
      static func dismantleView(_ view: ViewType)
  }

  struct Greeting: RepresentableModel {
      let name: String

      func makeView() -> FakeLabel {
          print("make")
          return FakeLabel()
      }

      func updateView(_ view: FakeLabel) {
          let newText = "Hi, \(name)"
          if view.text != newText {
              print("write \(newText)")
              view.text = newText
          }
      }

      static func dismantleView(_ view: FakeLabel) {
          print("dismantle (last text: \(view.text))")
      }
  }

  final class FakeHost<R: RepresentableModel> {
      private var view: R.ViewType?

      func render(_ representable: R) {
          if view == nil {
              view = representable.makeView()
          }
          if let view {
              representable.updateView(view)
          }
      }

      func remove() {
          if let view {
              R.dismantleView(view)
          }
          view = nil
      }
  }

  let host = FakeHost<Greeting>()
  for name in ["Ada", "Ada", "Grace", "Ada"] {
      host.render(Greeting(name: name))
  }
  host.remove()
  host.render(Greeting(name: "Linus"))
output: |
  make
  write Hi, Ada
  write Hi, Grace
  write Hi, Ada
  dismantle (last text: Hi, Ada)
  make
  write Hi, Linus
hints:
  - "make runs only while the host has no view."
  - "The guard skips the second 'Ada', but not the last one: the view says Grace at that point."
  - "After remove(), the next render starts from scratch."
solution: |
  ```output
  make
  write Hi, Ada
  write Hi, Grace
  write Hi, Ada
  dismantle (last text: Hi, Ada)
  make
  write Hi, Linus
  ```

  - The first render makes the view and the update writes "Hi, Ada".
  - The second "Ada" finds the view already saying "Hi, Ada": no write.
  - "Grace" differs, so it's written; then "Ada" differs from "Grace", so it's written again. The guard compares with the **view's current state**, not with "the previous input".
  - `remove()` calls the static dismantle with the view, then drops it. Rendering again means a new view: `make` runs a second time.

  In SwiftUI the same thing happens when a representable leaves the hierarchy and comes back, for example inside an `if`: it's a new UIKit view, created by a new `makeUIView` call.
````

````exercise
id: m40-l02-e2
type: comprehension
prompt: "Which statement about UIViewRepresentable is accurate according to Apple's documentation?"
choices:
  - text: "makeUIView(context:) is called only once, when SwiftUI creates the view for the first time; later changes go through updateUIView(_:context:)."
    correct: true
    why: "That's the wording on makeUIView's page."
  - text: "updateUIView(_:context:) is called only when one of the representable's stored properties changes value."
    correct: false
    why: "Apple says it's called 'for any changes affecting the corresponding UIKit view', with no promise that your values differ."
  - text: "You can position the wrapped view by setting its frame in updateUIView."
    correct: false
    why: "SwiftUI fully controls center, bounds, frame and transform; setting them is undefined behavior."
  - text: "dismantleUIView(_:coordinator:) is an instance method, so it can read the representable's properties."
    correct: false
    why: "It's static and receives only the view and the coordinator."
solution: |
  **The first.** `makeUIView`'s page: "The system calls this method only once, when it creates your view for the first time. For all subsequent updates, the system calls the `updateUIView(_:context:)` method." The others contradict the documentation: update isn't limited to changed values, layout properties belong to SwiftUI, and dismantle is static.
````

````exercise
id: m40-l02-e3
type: prediction
prompt: "A model of sizeThatFits for a label: 8 points per character, 20 points per line, wrapping at whole characters. SwiftUI proposes several sizes. What does it print?"
code: |
  struct Proposal {
      let width: Int?
  }

  struct FakeLabel {
      let text: String
      let characterWidth = 8
      let lineHeight = 20

      func sizeThatFits(width: Int) -> (width: Int, height: Int) {
          let perLine = max(1, width / characterWidth)
          let lines = (text.count + perLine - 1) / perLine
          let usedWidth = min(text.count, perLine) * characterWidth
          return (usedWidth, lines * lineHeight)
      }
  }

  func sizeThatFits(_ proposal: Proposal, label: FakeLabel) -> (width: Int, height: Int)? {
      guard let width = proposal.width else {
          return nil
      }
      let fitting = label.sizeThatFits(width: width)
      return (width, fitting.height)
  }

  let label = FakeLabel(text: String(repeating: "a", count: 50))
  for proposal in [Proposal(width: 400), Proposal(width: 200), Proposal(width: 100), Proposal(width: nil)] {
      if let size = sizeThatFits(proposal, label: label) {
          print("proposed \(proposal.width!): \(size.width) x \(size.height)")
      } else {
          print("proposed nil: default sizing")
      }
  }
output: |
  proposed 400: 400 x 20
  proposed 200: 200 x 40
  proposed 100: 100 x 100
  proposed nil: default sizing
hints:
  - "400 / 8 = 50 characters per line."
  - "200 / 8 = 25 per line, so 2 lines. 100 / 8 = 12 per line (integer division)."
solution: |
  ```output
  proposed 400: 400 x 20
  proposed 200: 200 x 40
  proposed 100: 100 x 100
  proposed nil: default sizing
  ```

  - 400 points fit 50 characters: 1 line, 20 points tall.
  - 200 points fit 25: 2 lines, 40 points.
  - 100 points fit 12 (integer division): 50 characters need 5 lines (4 full lines of 12 is 48, plus 2), 100 points.
  - A `nil` width is SwiftUI asking for the ideal size. The wrapper declines and returns `nil`, which Apple documents as "use the default sizing algorithm".

  The real wrapper does the same with `UILabel.sizeThatFits(_:)` doing the measuring. Narrower proposals make the label taller: that's the behavior a multi-line label needs and doesn't get without this method.
````

````exercise
id: m40-l02-e4
type: find-errors
prompt: "A wrapper around an in-house UIKit chart view. Which of these are real problems?"
code: |
  struct SalesChart: UIViewRepresentable {
      let points: [Double]
      let highlightedIndex: Int?

      func makeUIView(context: Context) -> LegacyChartView {
          let chart = LegacyChartView()
          chart.points = points
          chart.highlightedIndex = highlightedIndex
          chart.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
          return chart
      }

      func updateUIView(_ uiView: LegacyChartView, context: Context) {
          let fresh = LegacyChartView()
          fresh.points = points
          fresh.highlightedIndex = highlightedIndex
      }

      static func dismantleUIView(_ uiView: LegacyChartView, coordinator: ()) {
          uiView.stopAnimations()
      }
  }
choices:
  - text: "makeUIView sets the chart's frame, which SwiftUI controls."
    correct: true
    why: "Setting frame on a represented view is undefined behavior. Use .frame(height: 200) on the representable."
  - text: "updateUIView builds a new chart instead of updating uiView, so the chart on screen never changes."
    correct: true
    why: "SwiftUI keeps showing the view makeUIView returned. Update uiView."
  - text: "Once fixed to update uiView, the writes should be guarded so the chart doesn't redraw on every update."
    correct: true
    why: "if uiView.points != points { … }, and the same for highlightedIndex."
  - text: "dismantleUIView must be an instance method to call stopAnimations()."
    correct: false
    why: "It's static by design and receives the view as a parameter; calling a method on uiView is exactly right."
  - text: "Configuring points in makeUIView is a compile error."
    correct: false
    why: "It compiles; it's only redundant if updateUIView also sets them, since update runs after make."
rubric:
  - Flags the frame assignment.
  - Flags that updateUIView ignores uiView.
  - Mentions guarding the writes.
  - Doesn't flag the static dismantle or the configuration in make as errors.
solution: |
  Three real problems. A corrected version:

  ```swift ios
  import SwiftUI
  import UIKit

  final class LegacyChartView: UIView {
      var points: [Double] = [] {
          didSet { setNeedsDisplay() }
      }
      var highlightedIndex: Int? {
          didSet { setNeedsDisplay() }
      }

      func stopAnimations() {
          layer.removeAllAnimations()
      }
  }

  struct SalesChart: UIViewRepresentable {
      let points: [Double]
      let highlightedIndex: Int?

      func makeUIView(context: Context) -> LegacyChartView {
          LegacyChartView()
      }

      func updateUIView(_ uiView: LegacyChartView, context: Context) {
          if uiView.points != points {
              uiView.points = points
          }
          if uiView.highlightedIndex != highlightedIndex {
              uiView.highlightedIndex = highlightedIndex
          }
      }

      static func dismantleUIView(_ uiView: LegacyChartView, coordinator: ()) {
          uiView.stopAnimations()
      }
  }

  struct SalesCard: View {
      var body: some View {
          SalesChart(points: [3, 5, 4, 8], highlightedIndex: 3)
              .frame(height: 200)
      }
  }
  ```

  The size moved to `.frame(height: 200)` on the SwiftUI side. `makeUIView` only creates; `updateUIView` writes each value into the existing view when it differs. The static dismantle was already correct.
````

````exercise
id: m40-l02-e5
type: solve
prompt: |
  Your app has a UIKit `CountdownView` (below) that shows "mm:ss" and runs its own `CADisplayLink` while `isRunning` is true. Wrap it for SwiftUI as `Countdown`, with inputs `remainingSeconds: Int` and `isRunning: Bool`:

  - Create the view in `makeUIView`; set both values in `updateUIView`, guarded.
  - Stop it in `dismantleUIView`.
  - Use it in a `TimerCard` view with a fixed height of 60 points, set from SwiftUI.

  ```swift
  final class CountdownView: UIView {
      var remainingSeconds = 0 { didSet { updateLabel() } }
      var isRunning = false { didSet { isRunning ? start() : stop() } }
      // start(), stop() and updateLabel() exist; stop() invalidates the display link.
  }
  ```
starter: |
  import SwiftUI
  import UIKit

  struct Countdown: UIViewRepresentable {
      let remainingSeconds: Int
      let isRunning: Bool

      // your code
  }
hints:
  - "The guard matters most for isRunning: setting it to true again would call start() again."
  - "dismantleUIView gets the view; set isRunning to false on it."
rubric:
  - makeUIView only creates the view.
  - updateUIView writes each property only when it differs.
  - dismantleUIView is static and stops the view through its parameter.
  - The height is set with a SwiftUI frame modifier, not the UIKit frame.
solution: |
  ```swift ios
  import SwiftUI
  import UIKit

  final class CountdownView: UIView {
      private let label = UILabel()
      private var displayLink: CADisplayLink?

      var remainingSeconds = 0 {
          didSet { updateLabel() }
      }

      var isRunning = false {
          didSet { isRunning ? start() : stop() }
      }

      override init(frame: CGRect) {
          super.init(frame: frame)
          label.font = .monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
          label.translatesAutoresizingMaskIntoConstraints = false
          addSubview(label)
          NSLayoutConstraint.activate([
              label.centerXAnchor.constraint(equalTo: centerXAnchor),
              label.centerYAnchor.constraint(equalTo: centerYAnchor)
          ])
          updateLabel()
      }

      required init?(coder: NSCoder) {
          fatalError("CountdownView is created in code")
      }

      private func start() {
          guard displayLink == nil else { return }
          let link = CADisplayLink(target: self, selector: #selector(tick))
          link.add(to: .main, forMode: .common)
          displayLink = link
      }

      private func stop() {
          displayLink?.invalidate()
          displayLink = nil
      }

      @objc private func tick() {
          // Redraw a progress indicator, pulse the label…
      }

      private func updateLabel() {
          label.text = String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
      }
  }

  struct Countdown: UIViewRepresentable {
      let remainingSeconds: Int
      let isRunning: Bool

      func makeUIView(context: Context) -> CountdownView {
          CountdownView()
      }

      func updateUIView(_ uiView: CountdownView, context: Context) {
          if uiView.remainingSeconds != remainingSeconds {
              uiView.remainingSeconds = remainingSeconds
          }
          if uiView.isRunning != isRunning {
              uiView.isRunning = isRunning
          }
      }

      static func dismantleUIView(_ uiView: CountdownView, coordinator: ()) {
          uiView.isRunning = false
      }
  }

  struct TimerCard: View {
      let remainingSeconds: Int
      let isRunning: Bool

      var body: some View {
          Countdown(remainingSeconds: remainingSeconds, isRunning: isRunning)
              .frame(height: 60)
      }
  }
  ```

  - Without the `isRunning` guard, every update with `isRunning == true` would run `didSet` and call `start()` again. Here `start()` happens to protect itself, but a component that doesn't would add a second display link on every update.
  - A `CADisplayLink` keeps a strong reference to its target, so a view that's removed while running stays alive and ticking until something invalidates the link. `dismantleUIView` is that something.
  - The 60-point height belongs to SwiftUI.
````

## Summary

- `UIViewRepresentable` wraps a `UIView` for SwiftUI. `makeUIView` creates it once; `updateUIView` runs for any change affecting it; `dismantleUIView` (static) cleans up before removal.
- The representable is a value with `let` inputs, recreated by its parent like any SwiftUI view. The UIKit view is the long-lived object.
- Write `updateUIView` as "make the view match these values": guard each write with a comparison so repeated calls cost nothing and don't reset cursors, scroll positions or animations.
- SwiftUI owns the wrapped view's `frame`, `bounds`, `center` and `transform`. Size it with SwiftUI modifiers and, from iOS 16, `sizeThatFits(_:uiView:context:)`; return `nil` for proposals you don't handle.
- The context gives you the SwiftUI environment, the transaction (for animation) and the coordinator. From iOS 18, `context.animate` applies the transaction's animation to UIKit changes.
- Put clean-up that must happen on removal in `dismantleUIView`. It only sees the view and the coordinator.
