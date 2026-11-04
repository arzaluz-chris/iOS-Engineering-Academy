---
id: m40-l03
title: Coordinators for delegates and events
description: "UIKit views talk back through delegates and target-action, and a SwiftUI struct can't be a delegate. makeCoordinator gives each wrapped view a long-lived object that can. You wrap UITextView with a coordinator that writes into a binding, wrap a UIControl through target-action, keep the coordinator's copy of the representable fresh, and run a plain-Swift model of a map view that adjusts what you set, to see which update guards stop state fights and which don't."
module: m40
order: 3
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l02]
objectives:
  - Explain why a representable needs a coordinator for delegate and target-action callbacks.
  - Write makeCoordinator() and a Coordinator class that conforms to a UIKit delegate protocol.
  - Send UIKit events back to SwiftUI through bindings and closures, keeping the coordinator's copy of the representable current.
  - Recognize and break update loops between updateUIView and delegate callbacks.
  - Mark coordinators @MainActor and read the diagnostic when you don't.
terms:
  - term: Coordinator (representable)
    definition: "The object makeCoordinator() returns. SwiftUI creates it before makeUIView, keeps it for the life of the UIKit view, and passes it in context.coordinator and to dismantleUIView. Not the same thing as Module 25's navigation coordinator."
  - term: makeCoordinator()
    definition: "Optional representable method. Apple: it creates 'the custom instance that you use to communicate changes from your view to other parts of your SwiftUI interface.' Called before makeUIView(context:)."
  - term: Update loop
    definition: "A cycle where updateUIView writes to the UIKit view, the view reports the change through its delegate, the coordinator writes it to SwiftUI state, and SwiftUI updates the view again."
  - term: Last applied value
    definition: "A value the coordinator stores when it pushes SwiftUI state into the UIKit view. Comparing new input with it, instead of with the view's current state, avoids rewriting a view that adjusts what you set."
mastery:
  - Wrap UITextView with a two-way binding through UITextViewDelegate.
  - Wrap a UIControl with addTarget(_:action:for:) pointing at the coordinator.
  - Refresh context.coordinator.parent in updateUIView and predict what goes wrong without it.
  - Choose between comparing with the view's state, ignoring own writes, and tracking the last applied value.
  - Fix the "main actor-isolated property can not be mutated from a nonisolated context" error on a coordinator.
resources: [uikit-target-action, uikit-uitextfielddelegate, swiftui-binding, swift-mainactor, swift-book-protocols, swift-book-arc]
cards:
  - id: m40-l03-c1
    front: Why does a UIViewRepresentable need a coordinator to receive delegate callbacks?
    back: "Delegates and targets must be objects that live as long as the view, and the representable is a struct recreated on every update. makeCoordinator() returns a class instance SwiftUI keeps for the view's whole life; set it as delegate or target in makeUIView."
  - id: m40-l03-c2
    front: Why write context.coordinator.parent = self in updateUIView?
    back: "The coordinator was created with the first representable value. Later values bring new closures and bindings; without refreshing, callbacks go to stale closures that captured old data."
  - id: m40-l03-c3
    front: Does setting UITextView.text in updateUIView trigger textViewDidChange?
    back: "No. Apple: textViewDidChange 'is not called in response to programmatically initiated changes.' Guard the write anyway: assigning text on every update moves the cursor."
  - id: m40-l03-c4
    front: A wrapped MKMapView keeps snapping back to the region in state. Why?
    back: "MapKit may adjust the region you set to fit the view, so map.region never equals the state value and every update calls setRegion again. Compare the input with the last value you applied (stored on the coordinator), not with the map's current region."
  - id: m40-l03-c5
    front: Should a representable's Coordinator be @MainActor?
    back: "Yes, mark it explicitly. A nested class doesn't inherit isolation from the struct around it, and a coordinator that only has @objc target-action methods gets none from a protocol. Without it, writing to main-actor state fails to compile in Swift 6."
---

## The idea in one sentence

**A coordinator is the object your wrapped UIKit view talks to**: SwiftUI creates it once per UIKit view, you make it the delegate or the target, and it forwards what UIKit reports into SwiftUI bindings and closures.

> [!note] About this lesson's code
> UIKit and SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior is quoted from Apple's pages for `UIViewRepresentable`, `makeCoordinator()`, `UITextViewDelegate`, `textViewDidChange(_:)`, `UIControl.sendActions(for:)`, `MKMapView.region`, `setRegion(_:animated:)` and `mapView(_:regionDidChangeAnimated:)`, read in November 2026. The plain-Swift models (the map that adjusts what you set, the stale parent, the event router) and the isolation diagnostic were compiled and run with Swift 6.3; the models follow documented behavior, not UIKit's or SwiftUI's implementation. Nothing was run in the simulator.

## Why a struct can't be a delegate

Lesson 2's wrappers only went one way: SwiftUI values into a UIKit view. Most UIKit views also talk back. A text view tells its **delegate** that the text changed; a control sends **actions** to a **target** (Module 22, lesson 5). Both need an object:

- `UITextView.delegate` is a `weak var` of a class-bound protocol type. A struct can't be stored there.
- `addTarget(_:action:for:)` takes an object and an `@objc` selector.
- The object must live as long as the UIKit view. A representable struct is recreated every time its parent's `body` runs.

Apple's page for the protocol says it plainly: "The system doesn't automatically communicate changes occurring within your view to other parts of your SwiftUI interface. When you want your view to coordinate with other SwiftUI views, you must provide a `Coordinator` instance to facilitate those interactions. For example, you use a coordinator to forward target-action and delegate messages from your view to any SwiftUI views."

> [!note] Two meanings of "coordinator"
> Module 25's coordinator was a navigation object you design. A representable's `Coordinator` is an associated type of `UIViewRepresentable` with a fixed role: the long-lived companion of one wrapped view. Same word, different things. In an app with both, name your navigation types `…FlowCoordinator` or similar to keep them apart.

## makeCoordinator()

Apple: `makeCoordinator()` "Creates the custom instance that you use to communicate changes from your view to other parts of your SwiftUI interface." And the timing: "SwiftUI calls this method before calling the `makeUIView(context:)` method. The system provides your coordinator either directly or as part of a context structure when calling the other methods of your representable instance."

So the life of one wrapped view is:

1. `makeCoordinator()` creates the coordinator.
2. `makeUIView(context:)` creates the view; `context.coordinator` is already there, so you set it as delegate or target.
3. `updateUIView(_:context:)`, many times, with the same coordinator.
4. `dismantleUIView(_:coordinator:)` receives it one last time.

The default `Coordinator` type is `Void`; you replace it by declaring a nested class named `Coordinator` and returning one from `makeCoordinator()`.

## A text view with a binding

SwiftUI has `TextEditor`, and you should use it when it does what you need. You wrap `UITextView` when you need something it doesn't expose (an `inputAccessoryView`, `UITextView` delegate callbacks such as selection changes, a `UITextView` subclass your app already has) or when you're bringing an existing UIKit editor into a SwiftUI screen:

```swift ios
import SwiftUI
import UIKit

struct NotesEditor: UIViewRepresentable {
    @Binding var text: String
    var onEndEditing: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NotesEditor

        init(parent: NotesEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEndEditing(textView.text)
        }
    }
}

struct NoteScreen: View {
    @State private var draft = "Call the plumber at 555-0100"
    @State private var lastSaved = ""

    var body: some View {
        VStack(alignment: .leading) {
            NotesEditor(text: $draft, onEndEditing: save)
            Text("\(draft.count) characters")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func save(_ text: String) {
        lastSaved = text
    }
}
```

Line by line:

- **`Coordinator: NSObject, UITextViewDelegate`.** `NSObject` because UIKit delegate protocols are Objective-C protocols that inherit `NSObjectProtocol`. `@MainActor` explicitly; the last section shows why.
- **`var parent: NotesEditor`.** The coordinator keeps a copy of the representable, so it can reach `parent.text` (the binding) and `parent.onEndEditing` (the closure). Some code stores just the binding (`var text: Binding<String>`); storing `parent` gives access to every input at once.
- **`textView.delegate = context.coordinator`** in `makeUIView`, once. The delegate property is weak; SwiftUI is what keeps the coordinator alive.
- **`textViewDidChange`** writes the text view's text into the binding. That's the UIKit-to-SwiftUI direction. `NoteScreen`'s character count updates as the user types.
- **`updateUIView`** is the SwiftUI-to-UIKit direction, guarded. Apple's page for `textViewDidChange(_:)`: "This method is not called in response to programmatically initiated changes." So writing `uiView.text` there doesn't call the delegate back, and there's no loop. The guard is still required: without it, every keystroke would come back as an update that assigns the same text again, and assigning `text` moves the cursor. Type in the middle of a word and the cursor jumps to the end.
- **`context.coordinator.parent = self`**, first thing in `updateUIView`. The next section explains it.
- **`onEndEditing: save`** passes a method as the closure. `NoteScreen`'s `body` stays a short expression.

### Keeping parent fresh

The coordinator was created from the **first** `NotesEditor` value. Every later `body` run creates a new `NotesEditor` with possibly new closures. For a binding to `@State` the old copy usually still works, since it points at the same storage. Closures are a different story: a closure built in `body` captures the values of that moment. A plain-Swift model of a search field whose submit closure captures the current scope:

```swift
struct SearchField {
    let query: String
    let onSubmit: (String) -> Void
}

final class Coordinator {
    var parent: SearchField

    init(parent: SearchField) {
        self.parent = parent
    }

    // What a UISearchBarDelegate callback would do.
    func searchButtonClicked() {
        parent.onSubmit(parent.query)
    }
}

func makeField(query: String, scope: String) -> SearchField {
    SearchField(query: query, onSubmit: { text in
        print("search '\(text)' in \(scope)")
    })
}

let coordinator = Coordinator(parent: makeField(query: "tea", scope: "All"))

let newer = makeField(query: "teapot", scope: "Photos")

coordinator.searchButtonClicked()
coordinator.parent = newer
coordinator.searchButtonClicked()
```

```output
search 'tea' in All
search 'teapot' in Photos
```

`makeField` plays the parent's `body`, and its closure captures the scope selected when it ran. Without `coordinator.parent = newer`, the callback runs the first closure with the first query: the user searched for "teapot" in Photos and got "tea" in All. That's why the refresh is the first line of `updateUIView`.

## Target-action through the coordinator

A `UIControl` reports with actions. Here's a rating control from an existing app, the interactive sibling of lesson 2's star view. It calls `sendActions(for: .valueChanged)` when the user taps a star; Apple's page for that method: it "calls the action methods associated with the specified events."

```swift ios
import SwiftUI
import UIKit

final class StarRatingControl: UIControl {
    let maximum = 5
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    var rating = 0 {
        didSet { refreshStars() }
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
        for value in 1...maximum {
            let button = makeButton(for: value)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
        refreshStars()
    }

    required init?(coder: NSCoder) {
        fatalError("StarRatingControl is created in code")
    }

    private func makeButton(for value: Int) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
            self?.userSelected(value)
        })
        button.tintColor = .systemYellow
        button.accessibilityLabel = value == 1 ? "1 star" : "\(value) stars"
        return button
    }

    private func userSelected(_ value: Int) {
        rating = value
        sendActions(for: .valueChanged)
    }

    private func refreshStars() {
        for (index, button) in buttons.enumerated() {
            let name = index < rating ? "star.fill" : "star"
            button.setImage(UIImage(systemName: name), for: .normal)
            button.isSelected = index + 1 == rating
        }
    }
}

struct StarRatingPicker: UIViewRepresentable {
    @Binding var rating: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(rating: $rating)
    }

    func makeUIView(context: Context) -> StarRatingControl {
        let control = StarRatingControl()
        control.addTarget(context.coordinator, action: #selector(Coordinator.ratingChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ uiView: StarRatingControl, context: Context) {
        context.coordinator.rating = $rating
        if uiView.rating != rating {
            uiView.rating = rating
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var rating: Binding<Int>

        init(rating: Binding<Int>) {
            self.rating = rating
        }

        @objc func ratingChanged(_ sender: StarRatingControl) {
            rating.wrappedValue = sender.rating
        }
    }
}
```

- The control sends `.valueChanged` **only from `userSelected`**, the user's tap. Setting `rating` from code (which `updateUIView` does) doesn't send actions. That's the same split `UITextView` documents, and it's what keeps this wrapper from looping. When you write a control, keep that convention.
- `addTarget(_:action:for:)` takes the coordinator as target. Apple: "The control does not retain the object in the `target` parameter." SwiftUI is what keeps the coordinator alive.
- This coordinator stores only the binding, and refreshes it in `updateUIView` for the same reason as `parent`.
- `#selector` needs an `@objc` method on an `NSObject` subclass. The coordinator conforms to no protocol, so nothing would infer `@MainActor` for it. It's written explicitly.

## Update loops

The two directions meet in the coordinator:

```text
SwiftUI state ──updateUIView──▶ UIKit view
      ▲                              │
      └──── coordinator ◀─delegate───┘
```

If a write in `updateUIView` makes the view call its delegate, and the delegate writes state, and the new state makes `updateUIView` write again, you have a loop. Text views and well-behaved controls break it at the bottom arrow: programmatic changes don't notify. Not every UIKit view does that.

**`MKMapView` is the classic case.** Apple's page for `mapView(_:regionDidChangeAnimated:)`: "The map view calls this method at the end of a change to the map's visible region." It doesn't limit that to the user's gestures. And the `region` page adds the detail that breaks the simple guard: "When setting this property, the map may adjust the new region value so that it fits the visible area of the map precisely … if you get the value of this property right after setting it, the returned value may not match the value you set."

So with a map, `if uiView.region != region` can be true forever: you set 12, the map shows 10, the next update sees 10 ≠ 12 and sets it again. (For maps in SwiftUI, look at MapKit's SwiftUI `Map` first; this lesson uses `MKMapView`'s documented behavior because it's a clear example of the problem, and many existing apps wrap it.)

Here's a model you can run. The map fits any requested zoom to the nearest multiple of 5 and calls its delegate after every change, whoever caused it. `Screen` plays SwiftUI: it owns the state, runs `body` (which calls the coordinator's update), and counts state writes that happen **while** an update is running. Three coordinator strategies:

```swift
protocol MapDelegate: AnyObject {
    func mapDidChangeZoom(_ map: FakeMapView)
}

/// Like MKMapView: it fits a requested value to what it can show,
/// and tells its delegate after every change, whoever caused it.
final class FakeMapView {
    weak var delegate: (any MapDelegate)?
    private(set) var zoom = 0
    private(set) var programmaticSets = 0

    func setZoom(_ requested: Int) {
        programmaticSets += 1
        apply(requested)
    }

    func userPinched(to requested: Int) {
        apply(requested)
    }

    private func apply(_ requested: Int) {
        zoom = (requested + 2) / 5 * 5
        delegate?.mapDidChangeZoom(self)
    }
}

enum Strategy {
    case naive, ignoreOwnWrites, trackLastApplied
}

final class Coordinator: MapDelegate {
    let strategy: Strategy
    var writeZoom: (Int) -> Void = { _ in }
    private var isApplying = false
    private var lastApplied: Int?

    init(strategy: Strategy) {
        self.strategy = strategy
    }

    // Called from updateUIView.
    func update(_ map: FakeMapView, zoom: Int) {
        let needsWrite = strategy == .trackLastApplied ? lastApplied != zoom : map.zoom != zoom
        guard needsWrite else { return }
        lastApplied = zoom
        isApplying = true
        map.setZoom(zoom)
        isApplying = false
    }

    func mapDidChangeZoom(_ map: FakeMapView) {
        if strategy != .naive && isApplying {
            return
        }
        lastApplied = map.zoom
        writeZoom(map.zoom)
    }
}

/// Plays SwiftUI: owns the state and runs "body", which updates the map.
final class Screen {
    private(set) var zoom = 0
    private(set) var warnings = 0
    private var isUpdating = false
    let map = FakeMapView()
    let coordinator: Coordinator

    init(strategy: Strategy) {
        coordinator = Coordinator(strategy: strategy)
        map.delegate = coordinator
        coordinator.writeZoom = { [unowned self] newValue in
            self.setState(newValue)
        }
    }

    func setState(_ newValue: Int) {
        if isUpdating {
            warnings += 1
        }
        zoom = newValue
    }

    func runBody() {
        isUpdating = true
        coordinator.update(map, zoom: zoom)
        isUpdating = false
    }
}

for strategy in [Strategy.naive, .ignoreOwnWrites, .trackLastApplied] {
    let screen = Screen(strategy: strategy)
    screen.setState(12)
    screen.runBody()
    let afterButton = "state \(screen.zoom), map \(screen.map.zoom)"
    screen.runBody()
    screen.runBody()
    screen.map.userPinched(to: 23)
    screen.runBody()
    screen.runBody()
    print("\(strategy): after button \(afterButton); after pinch state \(screen.zoom), map \(screen.map.zoom); sets \(screen.map.programmaticSets), warnings \(screen.warnings)")
}
```

```output
naive: after button state 10, map 10; after pinch state 25, map 25; sets 1, warnings 1
ignoreOwnWrites: after button state 12, map 10; after pinch state 25, map 25; sets 3, warnings 0
trackLastApplied: after button state 12, map 10; after pinch state 25, map 25; sets 1, warnings 0
```

The script for each strategy: a "Zoom to 12" button sets state, `body` runs three times (one for the button, two for unrelated reasons), the user pinches to 23, and `body` runs twice more.

- **naive** compares with the map and forwards every delegate call. Its own `setZoom(12)` comes straight back through the delegate and **writes state in the middle of an update** (the one warning), replacing 12 with 10. In SwiftUI, writing state during a view update is something Xcode flags with a runtime warning about modifying state during a view update (the exact text wasn't checked for this lesson), and the behavior isn't defined. In this model the fitted value happens to be stable, so it stops there; with values that keep shifting (floating-point regions are a good candidate), the same wiring keeps going.
- **ignoreOwnWrites** sets an `isApplying` flag around its own write and drops callbacks while it's set. No more state writes during updates. But it still compares with the map, and the map says 10 while the state says 12, so **every** unrelated `body` run calls `setZoom` again: 3 sets instead of 1. On a real map that's a camera that keeps snapping back while the user tries to use it.
- **trackLastApplied** also ignores its own writes, and compares the input with the **last value it applied** instead of with the view. 12 was already applied, so unrelated updates do nothing. When the user pinches, the delegate records the map's value as the last applied one and writes it to state; the update that follows sees 25 = 25.

Use the simplest guard that's correct for the view you're wrapping:

| The UIKit view… | Guard |
| --- | --- |
| Doesn't notify for programmatic changes, and keeps what you set (`UITextView.text`, a well-behaved control) | `if uiView.value != value` |
| Notifies for programmatic changes | Also an `isApplying` flag on the coordinator |
| Adjusts what you set (`MKMapView.region`) | Compare with the last applied value stored on the coordinator |

A related tool: if a delegate callback really must change state while SwiftUI is updating, deferring the write to the next turn of the main run loop (`DispatchQueue.main.async` or a `Task { @MainActor in … }`) gets it out of the update. It's a patch for a callback you can't avoid, not a substitute for the guards above.

## Isolation: mark the coordinator @MainActor

UIKit views and SwiftUI state are main-actor isolated. A coordinator that writes to them must be too. Two facts make this easy to get wrong:

- **A nested type doesn't inherit the global actor of the type around it.** `UIViewRepresentable` is `@MainActor`, so your representable struct is, but the `Coordinator` class nested inside it isn't, unless something else makes it so.
- Conforming to a `@MainActor` delegate protocol such as `UITextViewDelegate` can infer main-actor isolation for the class, but a coordinator that only has `@objc` target-action methods conforms to no such protocol.

The error, without UIKit, using a main-actor store in place of SwiftUI state:

```swift no-compile main actor-isolated property 'text' can not be mutated from a nonisolated context
@MainActor
final class Store {
    var text = ""
}

@MainActor
struct Editor {
    let store: Store

    final class Coordinator {
        let store: Store

        init(store: Store) {
            self.store = store
        }

        func textDidChange(_ newText: String) {
            store.text = newText
        }
    }
}
```

Swift 6.3 reports `error: main actor-isolated property 'text' can not be mutated from a nonisolated context`, with the note "add '@MainActor' to make instance method 'textDidChange' part of global actor 'MainActor'". Take the advice at the class level: `@MainActor final class Coordinator`. Every coordinator in this lesson is written that way, whether or not inference would have covered it.

## Common mistakes

> [!error] Setting the delegate to self
> `textView.delegate = self` inside the representable doesn't compile (the struct isn't a delegate type), and even a class representable would be the wrong object: it's replaced on every update. Use `context.coordinator`.

> [!error] Not refreshing the coordinator's copy
> Without `context.coordinator.parent = self` (or the binding) in `updateUIView`, callbacks run closures from the first `body` evaluation, with the values they captured then.

> [!error] Writing every value back in updateUIView
> For a text view it moves the cursor on every keystroke. Guard with a comparison.

> [!error] Comparing with the view when the view adjusts what you set
> A map never reports exactly the region you set, so `if map.region != region` is true forever and the map keeps snapping back. Compare with the last value you applied.

> [!error] error: main actor-isolated property 'text' can not be mutated from a nonisolated context
> The coordinator isn't main-actor isolated. Nested types don't inherit it from the representable. Write `@MainActor final class Coordinator`.

## Exercises

````exercise
id: m40-l03-e1
type: prediction
prompt: "A coordinator for a rating control keeps the first representable it was given in one case and is refreshed in the other. What does it print?"
code: |
  struct RatingPicker {
      let productName: String
      let onRate: (String, Int) -> Void
  }

  final class Coordinator {
      var parent: RatingPicker

      init(parent: RatingPicker) {
          self.parent = parent
      }

      func controlChanged(to value: Int) {
          parent.onRate(parent.productName, value)
      }
  }

  func makePicker(for product: String, prefix: String) -> RatingPicker {
      RatingPicker(productName: product, onRate: { name, value in
          print("\(prefix): \(name) = \(value)")
      })
  }

  let coordinator = Coordinator(parent: makePicker(for: "Kettle", prefix: "v1"))
  coordinator.controlChanged(to: 3)

  let second = makePicker(for: "Grinder", prefix: "v2")
  coordinator.controlChanged(to: 4)

  coordinator.parent = second
  coordinator.controlChanged(to: 5)
output: |
  v1: Kettle = 3
  v1: Kettle = 4
  v2: Grinder = 5
hints:
  - "Creating a second picker doesn't change the coordinator."
  - "Only the assignment to coordinator.parent does."
solution: |
  ```output
  v1: Kettle = 3
  v1: Kettle = 4
  v2: Grinder = 5
  ```

  The second picker exists after the first callback, but the coordinator still holds the first one, so the rating of 4 is reported for the Kettle with the old closure. In SwiftUI terms: the parent's `body` produced a new representable for a different product and `updateUIView` didn't refresh `context.coordinator.parent`. After the refresh, the callback uses the new name and the new closure.
````

````exercise
id: m40-l03-e2
type: comprehension
prompt: "You wrap UITextView. In updateUIView you write if uiView.text != text { uiView.text = text }. A teammate worries this creates an infinite loop with textViewDidChange, which writes the binding. Who's right?"
choices:
  - text: "No loop: Apple documents that textViewDidChange isn't called for programmatic changes, and the guard skips equal text anyway."
    correct: true
    why: "Both facts hold. The guard's main job here is the cursor."
  - text: "There's a loop: every assignment to text calls textViewDidChange, which writes the binding, which calls updateUIView."
    correct: false
    why: "The text view only calls textViewDidChange for user-initiated changes."
  - text: "There's a loop unless the coordinator is @MainActor."
    correct: false
    why: "Isolation decides whether the code compiles, not whether callbacks fire."
  - text: "No loop, but only because SwiftUI never calls updateUIView after a binding changes."
    correct: false
    why: "It does call it; the binding changed state the representable reads."
solution: |
  **No loop.** Apple's page for `textViewDidChange(_:)`: "The text view calls this method in response to user-initiated changes to the text. This method is not called in response to programmatically initiated changes." And the guard skips the write when the text is already equal, which is the common case: the user typed, the binding got the new text, and the update finds the view already showing it. Without the guard there's still no loop, but the cursor jumps to the end on every keystroke.
````

````exercise
id: m40-l03-e3
type: prediction
prompt: "A slider-like control that notifies its target on every change, including programmatic ones, and a coordinator with an isApplying flag in one run and without it in the other. What does it print?"
code: |
  final class FakeSlider {
      var onValueChanged: (Int) -> Void = { _ in }
      private(set) var value = 0

      func setValue(_ newValue: Int) {
          value = newValue
          onValueChanged(newValue)
      }
  }

  final class Coordinator {
      let usesFlag: Bool
      var writeState: (Int) -> Void = { _ in }
      private var isApplying = false
      private(set) var forwarded = 0

      init(usesFlag: Bool) {
          self.usesFlag = usesFlag
      }

      func update(_ slider: FakeSlider, value: Int) {
          guard slider.value != value else { return }
          isApplying = true
          slider.setValue(value)
          isApplying = false
      }

      func sliderChanged(_ value: Int) {
          if usesFlag && isApplying { return }
          forwarded += 1
          writeState(value)
      }
  }

  for usesFlag in [false, true] {
      var state = 0
      var writesDuringUpdate = 0
      var isUpdating = false
      let slider = FakeSlider()
      let coordinator = Coordinator(usesFlag: usesFlag)
      slider.onValueChanged = { coordinator.sliderChanged($0) }
      coordinator.writeState = { newValue in
          if isUpdating { writesDuringUpdate += 1 }
          state = newValue
      }

      for newState in [40, 40, 70] {
          state = newState
          isUpdating = true
          coordinator.update(slider, value: state)
          isUpdating = false
      }
      slider.setValue(55)

      print("flag \(usesFlag): state \(state), forwarded \(coordinator.forwarded), writes during update \(writesDuringUpdate)")
  }
output: |
  flag false: state 55, forwarded 3, writes during update 2
  flag true: state 55, forwarded 1, writes during update 0
hints:
  - "The second 40 is skipped by the guard in update."
  - "slider.setValue(55) at the end is outside any update; it plays the user dragging."
solution: |
  ```output
  flag false: state 55, forwarded 3, writes during update 2
  flag true: state 55, forwarded 1, writes during update 0
  ```

  - Updates with 40, 40 and 70: the guard skips the repeated 40, so the slider is set twice.
  - **Without the flag**, both programmatic sets come back through `sliderChanged` and write state while an update is running: 2 writes during update. Then the user's 55 is forwarded too: 3 in total.
  - **With the flag**, the two programmatic sets are dropped and only the user's change is forwarded.

  Both end with state 55, which is why the bug is easy to miss: the screen looks right. The difference is writing state during a view update, which SwiftUI doesn't define and Xcode flags at runtime.
````

````exercise
id: m40-l03-e4
type: solve
prompt: |
  Write the event routing for a wrapped search bar, in plain Swift so it can be tested without UIKit:

  - `enum SearchEvent: Equatable` with `began`, `changed(String)`, `submitted(String)` and `cancelled`.
  - `final class SearchCoordinator` with `var onEvent: (SearchEvent) -> Void` and four methods that mirror the delegate callbacks: `didBeginEditing()`, `textDidChange(_:)`, `searchButtonClicked(text:)` and `cancelButtonClicked()`.
  - Rules: trim whitespace before reporting `submitted`, and don't report `submitted` for an empty query. Don't report `changed` if the text is the same as the last reported one.

  Drive it with this sequence and print each event: begin, type "t", "te", "te", "tea ", submit "tea ", submit "   ", cancel.
starter: |
  enum SearchEvent: Equatable {
      // your cases
  }

  final class SearchCoordinator {
      var onEvent: (SearchEvent) -> Void = { _ in }
      // your code
  }
hints:
  - "Store the last reported text in a private optional."
  - "trimmingCharacters(in: .whitespaces) needs Foundation."
rubric:
  - SearchEvent has the four cases with associated text where needed.
  - Duplicate changes are dropped by comparing with the last reported text.
  - Submitted text is trimmed and empty queries aren't reported.
  - The coordinator talks to the outside only through onEvent.
solution: |
  ```swift
  import Foundation

  enum SearchEvent: Equatable {
      case began
      case changed(String)
      case submitted(String)
      case cancelled
  }

  final class SearchCoordinator {
      var onEvent: (SearchEvent) -> Void = { _ in }
      private var lastReportedText: String?

      func didBeginEditing() {
          onEvent(.began)
      }

      func textDidChange(_ text: String) {
          guard text != lastReportedText else { return }
          lastReportedText = text
          onEvent(.changed(text))
      }

      func searchButtonClicked(text: String) {
          let query = text.trimmingCharacters(in: .whitespaces)
          guard !query.isEmpty else { return }
          onEvent(.submitted(query))
      }

      func cancelButtonClicked() {
          lastReportedText = nil
          onEvent(.cancelled)
      }
  }

  var events: [SearchEvent] = []
  let coordinator = SearchCoordinator()
  coordinator.onEvent = { events.append($0) }

  coordinator.didBeginEditing()
  for text in ["t", "te", "te", "tea "] {
      coordinator.textDidChange(text)
  }
  coordinator.searchButtonClicked(text: "tea ")
  coordinator.searchButtonClicked(text: "   ")
  coordinator.cancelButtonClicked()

  for event in events {
      print(event)
  }
  print(events.count)
  ```

  ```output
  began
  changed("t")
  changed("te")
  changed("tea ")
  submitted("tea")
  cancelled
  6
  ```

  In the app, the UIKit `UISearchBarDelegate` methods of a `@MainActor` coordinator call these four methods, and the representable sets `onEvent` from its own closure (refreshed in `updateUIView`). The SwiftUI side gets one closure with a small, testable vocabulary of events, and the rules (trim, skip empty, skip duplicates) are tested here without a simulator.
````

````exercise
id: m40-l03-e5
type: fill-in
prompt: "Complete a wrapper for UIStepper that reports changes through target-action."
code: |
  struct LegacyStepper: UIViewRepresentable {
      @Binding var value: Double

      func [[1]]() -> Coordinator {
          Coordinator(value: $value)
      }

      func makeUIView(context: Context) -> UIStepper {
          let stepper = UIStepper()
          stepper.addTarget(context.[[2]], action: #selector(Coordinator.valueChanged(_:)), for: .[[3]])
          return stepper
      }

      func updateUIView(_ uiView: UIStepper, context: Context) {
          context.coordinator.value = $value
          if uiView.value != value {
              uiView.value = value
          }
      }

      [[4]]
      final class Coordinator: NSObject {
          var value: Binding<Double>

          init(value: Binding<Double>) {
              self.value = value
          }

          [[5]] func valueChanged(_ sender: UIStepper) {
              value.wrappedValue = sender.value
          }
      }
  }
blanks:
  - id: "1"
    answers: ["makeCoordinator"]
  - id: "2"
    answers: ["coordinator"]
  - id: "3"
    answers: ["valueChanged"]
  - id: "4"
    answers: ["@MainActor"]
  - id: "5"
    answers: ["@objc"]
hints:
  - "The coordinator comes from the context in makeUIView."
  - "#selector needs an Objective-C-visible method."
solution: |
  ```swift ios
  import SwiftUI
  import UIKit

  struct LegacyStepper: UIViewRepresentable {
      @Binding var value: Double

      func makeCoordinator() -> Coordinator {
          Coordinator(value: $value)
      }

      func makeUIView(context: Context) -> UIStepper {
          let stepper = UIStepper()
          stepper.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
          return stepper
      }

      func updateUIView(_ uiView: UIStepper, context: Context) {
          context.coordinator.value = $value
          if uiView.value != value {
              uiView.value = value
          }
      }

      @MainActor
      final class Coordinator: NSObject {
          var value: Binding<Double>

          init(value: Binding<Double>) {
              self.value = value
          }

          @objc func valueChanged(_ sender: UIStepper) {
              value.wrappedValue = sender.value
          }
      }
  }
  ```

  `makeCoordinator()` runs before `makeUIView`, so `context.coordinator` is ready to be the target. `.valueChanged` is the control event a stepper sends when the user taps + or −. `@MainActor` because the coordinator writes main-actor state and has no delegate protocol to infer it from; `@objc` because `#selector` names an Objective-C method. SwiftUI's own `Stepper` is the normal choice; this is the shape for any `UIControl` you already have.
````

````exercise
id: m40-l03-e6
type: find-errors
prompt: "A wrapper for an in-house UIKit color picker view that reports through a delegate. Which of these are real problems?"
code: |
  struct BrandColorPicker: UIViewRepresentable {
      @Binding var selection: BrandColor
      let onPick: (BrandColor) -> Void

      func makeCoordinator() -> Coordinator {
          Coordinator(parent: self)
      }

      func makeUIView(context: Context) -> ColorGridView {
          let grid = ColorGridView()
          grid.delegate = context.coordinator
          return grid
      }

      func updateUIView(_ uiView: ColorGridView, context: Context) {
          uiView.selectedColor = selection    // ColorGridView calls its delegate whenever selectedColor is set
      }

      final class Coordinator: NSObject, ColorGridViewDelegate {
          let parent: BrandColorPicker

          init(parent: BrandColorPicker) {
              self.parent = parent
          }

          func colorGrid(_ grid: ColorGridView, didSelect color: BrandColor) {
              parent.selection = color
              parent.onPick(color)
          }
      }
  }
choices:
  - text: "updateUIView writes selectedColor unconditionally, and the grid calls its delegate on every set, so each update writes state and calls onPick."
    correct: true
    why: "Guard the write, and ignore callbacks caused by the coordinator's own writes with an isApplying flag."
  - text: "parent is a let and is never refreshed, so onPick runs the closure from the first body evaluation."
    correct: true
    why: "Make it var and assign context.coordinator.parent = self in updateUIView."
  - text: "The coordinator isn't marked @MainActor."
    correct: true
    why: "If ColorGridViewDelegate isn't a @MainActor protocol, nothing makes the coordinator main-actor isolated, and writing the binding or calling main-actor code won't compile in Swift 6. Mark it explicitly."
  - text: "grid.delegate = context.coordinator should be in updateUIView so it's set on every update."
    correct: false
    why: "The coordinator never changes for this view; setting the delegate once in makeUIView is right."
  - text: "makeCoordinator must be static."
    correct: false
    why: "It's an instance method; SwiftUI calls it on the representable before makeUIView."
rubric:
  - Flags the unguarded write and the callback it triggers.
  - Flags the stale let parent.
  - Flags the missing @MainActor.
  - Doesn't flag the delegate assignment in makeUIView or makeCoordinator.
solution: |
  Three real problems:

  1. **Loop risk and spurious events.** The grid notifies on programmatic sets, so every update writes `selection` during the update and calls `onPick` as if the user had picked. Fix: `if uiView.selectedColor != selection { coordinator.isApplying = true; uiView.selectedColor = selection; coordinator.isApplying = false }`, and in the delegate method return early while `isApplying` is true.
  2. **Stale parent.** `let parent` can't be refreshed. Make it `var` and assign `context.coordinator.parent = self` at the top of `updateUIView`.
  3. **Isolation.** Write `@MainActor final class Coordinator`. Don't depend on inference from a protocol you didn't check.

  Setting the delegate once in `makeUIView` and `makeCoordinator` as an instance method are both correct.
````

## Summary

- Delegates and targets must be objects that live as long as the UIKit view. `makeCoordinator()` creates one; SwiftUI calls it before `makeUIView`, keeps it for the view's life and hands it to every later call.
- Set the coordinator as delegate or target in `makeUIView`. In its callbacks, write bindings and call closures to report to SwiftUI.
- Refresh the coordinator's copy of the representable (or its binding) at the top of `updateUIView`, so callbacks use the latest closures and values.
- Guard every write in `updateUIView`. Add an `isApplying` flag when the UIKit view notifies for programmatic changes, and compare with the last applied value when it adjusts what you set, as `MKMapView` does with regions.
- `UITextView` doesn't call `textViewDidChange` for programmatic changes; the guard is still needed to keep the cursor in place.
- Mark coordinators `@MainActor`. Nested types don't inherit isolation from the representable, and target-action coordinators have no protocol to infer it from.
