---
id: m23-l05
title: Scroll views
description: A scroll view is a viewport over content that's bigger than it. You learn the four numbers that describe it (frame, contentSize, contentOffset and the content insets), how Auto Layout sizes the content through contentLayoutGuide and frameLayoutGuide, why the content needs an unbroken chain of constraints, how to scroll in code, and how to keep fields visible above the keyboard with keyboardLayoutGuide.
module: m23
order: 5
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m23-l04]
objectives:
  - Describe a scroll view with its frame, contentSize, contentOffset, contentInset and adjustedContentInset.
  - Lay out scrollable content with contentLayoutGuide and frameLayoutGuide, with no ambiguity.
  - Compute the scroll range and the visible part of the content for a given offset.
  - Scroll to a position or a rectangle in code.
  - Keep a form usable when the keyboard appears, using keyboardLayoutGuide and keyboardDismissMode.
terms:
  - term: Content size
    definition: "The size of the scrollable content (contentSize). With Auto Layout it comes from constraints to contentLayoutGuide instead of being set by hand."
  - term: Content offset
    definition: "The point of the content shown at the scroll view's top-left corner (contentOffset). It's the scroll view's bounds origin."
  - term: Adjusted content inset
    definition: "adjustedContentInset: your contentInset plus the safe area insets the scroll view decides to include, according to contentInsetAdjustmentBehavior."
  - term: contentLayoutGuide
    definition: "A layout guide for the scroll view's content rectangle. Constraints from the content's edges to it define contentSize."
  - term: frameLayoutGuide
    definition: "A layout guide for the scroll view's own (untransformed) frame. Use it to size content relative to the visible area, for example to disable horizontal scrolling."
  - term: Keyboard layout guide
    definition: "view.keyboardLayoutGuide (iOS 15): a layout guide for the space the keyboard occupies. When the keyboard is hidden, its top matches the bottom of the safe area."
mastery:
  - Write the constraints that put a vertical stack in a scroll view that only scrolls vertically.
  - Explain why a missing bottom constraint stops a scroll view from scrolling.
  - Compute the minimum and maximum contentOffset for a given content height, scroll view height and insets.
  - Compute the offset that brings a given rectangle into view.
  - Pin a scroll view's bottom to the keyboard layout guide and choose a keyboard dismiss mode.
resources: [apple-documentation]
cards:
  - id: m23-l05-c1
    front: What do contentLayoutGuide and frameLayoutGuide represent?
    back: "contentLayoutGuide is the content rectangle: pin the content's four edges to it to define contentSize. frameLayoutGuide is the scroll view's frame: constrain the content's width to it to scroll only vertically."
  - id: m23-l05-c2
    front: Why doesn't a stack inside a scroll view scroll if you forget its bottom constraint?
    back: "Nothing ties the content's height to the content area, so the content size is undetermined. Apple's guide: you need an unbroken chain of constraints from the content's top edge to its bottom edge."
  - id: m23-l05-c3
    front: contentInset vs adjustedContentInset?
    back: "contentInset is your extra space. adjustedContentInset is what UIKit actually uses: contentInset plus the safe area insets, as decided by contentInsetAdjustmentBehavior (default .automatic)."
  - id: m23-l05-c4
    front: Where is keyboardLayoutGuide's top when the keyboard is hidden?
    back: "At the bottom of the safe area (with the default usesBottomSafeArea = true, iOS 17). Pinning a view's bottom to keyboardLayoutGuide.topAnchor keeps it above the keyboard and above the home indicator."
  - id: m23-l05-c5
    front: Which keyboardDismissMode lets the user drag the keyboard down with the content?
    back: ".interactive: the keyboard follows the dragging touch offscreen and can be pulled back up. .onDrag dismisses it as soon as a drag begins; .none (the default) never does."
---

## The idea in one sentence

A scroll view is a fixed window (its frame) over content of any size (its content size), and scrolling is nothing more than changing which point of the content sits at the window's top-left corner (its content offset).

> [!note] About this lesson's code
> The rules come from Apple's `UIScrollView`, `UIView` and `UIKeyboardLayoutGuide` reference pages, the sample-code article "Adjusting your layout with keyboard layout guide" and the archived *Auto Layout Guide*, read in November 2026. `keyboardLayoutGuide` is available from iOS 15 and the course targets iOS 17, so no availability check is needed. UIKit blocks are type-checked against the iOS 17 SDK on the CI runner, not run. The scroll-range model is plain Swift, compiled and run with Swift 6.3; Apple's pages define each number but don't print the formulas, so treat the model as a model.

## Four numbers

| Property | What it is | Default |
| --- | --- | --- |
| `frame` | The window, in the superview | Set by your constraints |
| `contentSize` | "The size of the content view" | `.zero` |
| `contentOffset` | "The point at which the origin of the content view is offset from the origin of the scroll view" | `.zero` |
| `contentInset` | "The custom distance that the content view is inset from the safe area or scroll view edges" | `.zero` |

Lesson 1 showed the mechanism: `contentOffset` is the scroll view's bounds origin, so subviews placed at content coordinates appear shifted by it. The scroll view "clips the content to its frame" (its `clipsToBounds` defaults to `true`), tracks the user's finger and changes the offset.

Apple adds: "The scroll view must know the size of the content view so it knows when to stop scrolling." Without a content size larger than the frame, there's nothing to scroll.

### Insets and the safe area

A full-screen scroll view usually extends under the status bar and the home indicator, and the content should still be reachable. That's what `adjustedContentInset` is for: "The insets derived from the content insets and the safe area of the scroll view." UIKit adds the safe area insets to your `contentInset`, according to `contentInsetAdjustmentBehavior`:

| Behavior | Apple's description |
| --- | --- |
| `.automatic` (default) | "Content is always adjusted vertically when the scroll view is the content view of a view controller that is currently displayed by a navigation or tab bar controller." Horizontal offsets are adjusted for horizontally scrollable content |
| `.scrollableAxes` | Include the safe area only in directions where the content scrolls (or `alwaysBounceVertical` is on) |
| `.always` | "Always include the safe area insets in the content adjustment." |
| `.never` | "Do not adjust the scroll view insets." For edge-to-edge content such as a photo you want under the status bar |

Read `adjustedContentInset` whenever you compute positions; set `contentInset` only for extra space you want yourself, like room for a floating button.

### The scroll range

With those numbers, the range of `contentOffset.y` follows from the definitions: at the top, the content's top edge sits `adjustedContentInset.top` below the scroll view's top; at the bottom, the content's bottom edge sits `adjustedContentInset.bottom` above the scroll view's bottom. The model:

```swift
struct ScrollState {
    var contentHeight: Double
    var viewHeight: Double
    var insetTop: Double = 0       // adjustedContentInset.top
    var insetBottom: Double = 0    // adjustedContentInset.bottom

    var minOffset: Double { -insetTop }
    var maxOffset: Double { max(contentHeight + insetBottom - viewHeight, minOffset) }

    func clamped(_ offset: Double) -> Double {
        min(max(offset, minOffset), maxOffset)
    }

    // The part of the content you can see, in content coordinates.
    func visibleRange(at offset: Double) -> ClosedRange<Double> {
        offset...(offset + viewHeight)
    }
}

let article = ScrollState(contentHeight: 2000, viewHeight: 844, insetTop: 59, insetBottom: 34)
print(article.minOffset, article.maxOffset)
print(article.clamped(5000))
print(article.visibleRange(at: 300))

let shortNote = ScrollState(contentHeight: 400, viewHeight: 844, insetTop: 59, insetBottom: 34)
print(shortNote.minOffset, shortNote.maxOffset)
```

```output
-59.0 1190.0
1190.0
300.0...1144.0
-59.0 -59.0
```

- At rest at the top, the offset is −59: the content starts 59 points down, below the status bar area, while the scroll view itself starts at the screen's top. The 59 is an example value; it varies by device.
- At the bottom, 2000 + 34 − 844 = 1190.
- Any offset you ask for outside that range is clamped (UIKit lets the user drag past the ends and bounces back; programmatic offsets should stay inside).
- A note shorter than the screen has no range at all: min equals max, so it doesn't scroll. Setting `alwaysBounceVertical` lets the user drag it anyway; it's `false` by default.

## Auto Layout inside a scroll view

Constraints made directly between a scroll view and its content have special meanings: per Apple's archived guide, edges attach to the content area, while width, height and centers attach to the frame. The two layout guides added in iOS 11 make that explicit:

- `contentLayoutGuide`: "the layout guide based on the untranslated content rectangle of the scroll view". Constraints to it **define the content size**.
- `frameLayoutGuide`: "the layout guide based on the untransformed frame rectangle of the scroll view". Constraints to it relate content to the **visible area**.

The standard setup is one content view (often a stack view) inside the scroll view:

1. Pin the scroll view to the screen like any other view.
2. Pin the content's four edges to `contentLayoutGuide`. The content now defines the content size.
3. Make the content's width equal to `frameLayoutGuide`'s width (minus any padding). Now it can't be wider than the screen, so it only scrolls vertically.
4. Give the content a height from its own constraints: an "unbroken chain of constraints and views stretching from the content view's top edge to its bottom edge", in the guide's words. A stack view provides that chain for its arranged views.

If step 4 is missing, the content height is ambiguous and the scroll view doesn't know how far to scroll. If step 3 is missing, labels with `numberOfLines = 0` have no width to wrap at, so they grow sideways and the content scrolls horizontally.

## A form that survives the keyboard

`view.keyboardLayoutGuide` (iOS 15) is "a layout guide that represents the space the keyboard occupies in your app's layout." From Apple's article: with `followsUndockedKeyboard` left at `false`, "the guide matches the keyboard when it docks. When the keyboard isn't onscreen, the guide is at the bottom of the window and has a height equal to the bottom of the current `safeAreaInsets`." So its top anchor is the safe area's bottom when there's no keyboard and the keyboard's top when there is.

Pin the scroll view's bottom to that anchor and the scroll view shrinks when the keyboard appears and grows back when it hides. Every field can then be scrolled into view; nothing is behind the keyboard.

```swift ios
import UIKit

final class ShippingFormViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let form = UIStackView()
    private var fields: [UITextField] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        for placeholder in ["Full name", "Street", "City", "Postal code", "Country", "Phone", "Delivery notes"] {
            let field = UITextField()
            field.placeholder = placeholder
            field.borderStyle = .roundedRect
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            fields.append(field)
            form.addArrangedSubview(field)
        }
        form.axis = .vertical
        form.spacing = 16

        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        form.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(form)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            // 1. The scroll view: under the top safe area, down to the keyboard.
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            // 2. The content's edges define the content size.
            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            form.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            form.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            form.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            // 3. As wide as the visible area minus padding: vertical scrolling only.
            form.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -40),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // After the scroll view shrinks for the keyboard, bring the active field back into view.
        if let active = fields.first(where: { $0.isFirstResponder }) {
            let rect = scrollView.convert(active.bounds, from: active).insetBy(dx: 0, dy: -12)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
}
```

Walking through the constraints:

- **The scroll view** has four edges, so its frame is determined. Its top is the safe area's top; its bottom is the keyboard's top (or the safe area's bottom when there's no keyboard).
- **The stack's four edges** go to `contentLayoutGuide` with 20 points of padding. The stack's height is its fitting size (lesson 4), and the content height is that plus 40. That's the unbroken chain.
- **The stack's width** is the frame's width minus 40, which is exactly the width left between the 20-point paddings. Content width = frame width: no horizontal scrolling.
- **`keyboardDismissMode = .interactive`**: "the keyboard follows the dragging touch offscreen, and can be pulled upward again to cancel the dismiss." The default, `.none`, never dismisses on drag; `.onDrag` dismisses as soon as a drag begins.
- **`viewDidLayoutSubviews()`** runs after every layout pass, including the one that shrinks the scroll view for the keyboard. If a field is being edited, the code converts its bounds into the scroll view's coordinates (which are content coordinates, lesson 1), pads it a little and calls `scrollRectToVisible(_:animated:)`. Apple: that method scrolls "so that the area defined by `rect` is just visible inside the scroll view. If the area is already visible, the method does nothing", which is what makes it safe to call on every layout pass. This is one way to do it; it wasn't run on a device for this lesson.

Two more `UIKeyboardLayoutGuide` properties, both iOS 17:

- `usesBottomSafeArea`: "Defaults to `true`, indicating that the layout guide ties to the `bottomAnchor` of the view's `safeAreaLayoutGuide`." Set it to `false` to tie the guide to the view's bottom instead, when you want content to reach the very bottom edge with no keyboard.
- `keyboardDismissPadding`: extra touch area above the keyboard for the interactive dismiss gesture.

On iPad, the keyboard can be undocked, split or floating. With the default `followsUndockedKeyboard = false`, an undocked keyboard is treated like a hidden one. Setting it to `true` makes the guide follow the keyboard anywhere, and `UITrackingLayoutGuide`'s `setConstraints(_:activeWhenNearEdge:)` and `setConstraints(_:activeWhenAwayFrom:)` switch constraints on and off as the keyboard approaches screen edges; Apple's sample "Adjusting your layout with keyboard layout guide" shows the full setup. For a form on iPhone, the default is what you want.

Older code does the same job by observing `keyboardWillShowNotification` and `keyboardWillHideNotification`, reading the keyboard frame from the notification and changing `contentInset.bottom`. You'll see it in existing projects. With an iOS 15+ target, the layout guide replaces all of it.

## Scrolling in code

- `setContentOffset(_:animated:)` scrolls to an exact offset. To scroll to the top, use the minimum offset from the model: `CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)`, not `.zero`, or the first row ends up under the bars.
- `scrollRectToVisible(_:animated:)` scrolls just enough to show a rectangle given in the scroll view's coordinate space.
- `flashScrollIndicators()` shows the indicators briefly, a hint that there's more content.

The amount `scrollRectToVisible(_:animated:)` scrolls is "just enough". The arithmetic, as the exercise below models it: if the rectangle is above the visible range, its top becomes the new top; if it's below, its bottom becomes the new bottom; otherwise nothing moves.

## Common mistakes

> [!error] Pinning the content to the scroll view's frameLayoutGuide on all four edges
> The content is then exactly the size of the scroll view and there's nothing to scroll. The edges go to `contentLayoutGuide`; only the width (or height) goes to `frameLayoutGuide`.

> [!error] A broken chain of vertical constraints
> If the last view in the content isn't tied to the content's bottom, the content height is undetermined. The scroll view doesn't scroll, or scrolls to the wrong place.

> [!error] Setting contentSize by hand while using Auto Layout for the content
> The constraints to `contentLayoutGuide` define the content size. Setting `contentSize` yourself fights them on the next layout pass.

> [!error] Pinning the scroll view's bottom to view.bottomAnchor in a form
> The keyboard covers the last fields and there's no way to reach them. Pin it to `view.keyboardLayoutGuide.topAnchor`.

> [!error] Scrolling to the top with contentOffset = .zero
> With safe-area insets, the real top is `-adjustedContentInset.top`. `.zero` leaves the first content under the status bar or navigation bar.

## Exercises

````exercise
id: m23-l05-e1
type: prediction
prompt: "This uses the lesson's scroll model with a navigation bar area of 103 points at the top and 34 at the bottom. What does it print?"
code: |
  func range(content: Double, view: Double, top: Double, bottom: Double) -> (Double, Double) {
      let low = -top
      let high = max(content + bottom - view, low)
      return (low, high)
  }

  let (low, high) = range(content: 1500, view: 844, top: 103, bottom: 34)
  print(low, high)

  for request in [-200.0, 400.0, 900.0] {
      print(min(max(request, low), high))
  }

  let short = range(content: 600, view: 844, top: 103, bottom: 34)
  print(short.0 == short.1)
output: |
  -103.0 690.0
  -103.0
  400.0
  690.0
  true
hints:
  - "The highest offset is content + bottom inset − view height."
  - "Clamping keeps each request between low and high."
  - "600 + 34 − 844 is negative, below the minimum."
solution: |
  ```output
  -103.0 690.0
  -103.0
  400.0
  690.0
  true
  ```

  The range runs from −103 (the content's top just below the bars) to 1500 + 34 − 844 = 690 (the content's bottom just above the home indicator area). −200 is clamped up to −103 and 900 down to 690; 400 is inside. The 600-point content is shorter than the screen: max(−210, −103) = −103, so the minimum and maximum coincide and there's nothing to scroll.
````

````exercise
id: m23-l05-e2
type: comprehension
prompt: "A vertical stack of labels is inside a scroll view with its four edges pinned to `contentLayoutGuide`. The long labels don't wrap, and the content scrolls sideways. What's missing?"
choices:
  - text: "A constraint making the stack's width equal to the scroll view's frameLayoutGuide width."
    correct: true
    why: Without it, nothing limits the content's width, so labels lay out on one line and the content becomes as wide as the longest one.
  - text: "A height constraint on the stack."
    correct: false
    why: The height comes from the stack's content; the problem is horizontal.
  - text: "Setting scrollView.contentSize.width to the screen width."
    correct: false
    why: With Auto Layout content, constraints to contentLayoutGuide define the content size; setting it by hand fights them.
  - text: "Pinning the stack's leading and trailing edges to frameLayoutGuide instead of contentLayoutGuide."
    correct: false
    why: "It limits the width, but the edges should define the content area. The idiomatic fix is a width constraint to frameLayoutGuide, keeping the four edges on contentLayoutGuide."
solution: |
  **Width equal to `frameLayoutGuide`'s width.** The four edges to `contentLayoutGuide` say "the content area is as big as the stack", but nothing says how big the stack is horizontally, so each label uses its full single-line width. Tying the stack's width to the visible width gives the labels a width to wrap at and makes the content exactly as wide as the screen. The archived guide describes the same trick: "To disable horizontal scrolling, set the content view's width equal to the scroll view's width."
````

````exercise
id: m23-l05-e3
type: fill-in
prompt: "Complete the constraints for a settings screen whose stack `content` scrolls vertically inside `scrollView`, and stays above the keyboard."
code: |
  NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.[[1]].topAnchor),

      content.topAnchor.constraint(equalTo: scrollView.[[2]].topAnchor),
      content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      content.widthAnchor.constraint(equalTo: scrollView.[[3]].widthAnchor),
  ])
  scrollView.keyboardDismissMode = .[[4]]
blanks:
  - id: "1"
    answers: ["keyboardLayoutGuide"]
  - id: "2"
    answers: ["contentLayoutGuide"]
  - id: "3"
    answers: ["frameLayoutGuide"]
  - id: "4"
    answers: ["interactive", "onDrag"]
solution: |
  ```swift ios
  import UIKit

  final class SettingsViewController: UIViewController {
      private let scrollView = UIScrollView()
      private let content = UIStackView()

      override func viewDidLoad() {
          super.viewDidLoad()
          content.axis = .vertical
          content.spacing = 12
          scrollView.translatesAutoresizingMaskIntoConstraints = false
          content.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(scrollView)
          scrollView.addSubview(content)

          NSLayoutConstraint.activate([
              scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

              content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
              content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
              content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
              content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
              content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
          ])
          scrollView.keyboardDismissMode = .interactive
      }
  }
  ```

  The keyboard guide's top is the keyboard's top, or the safe area's bottom when the keyboard is hidden. Four edges to the content guide define the content size; the width to the frame guide stops horizontal scrolling. `.interactive` and `.onDrag` both dismiss the keyboard on scroll; `.interactive` lets the user drag it down gradually and change their mind.
````

````exercise
id: m23-l05-e4
type: find-errors
prompt: "A long terms-of-service screen doesn't scroll, and when the user types in the feedback field at the end, the keyboard covers the Accept button below it. Mark every real problem."
code: |
  NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      stack.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
      stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor),
  ])
  scrollView.contentSize = CGSize(width: 390, height: 3000)
choices:
  - text: "The stack's edges are pinned to frameLayoutGuide, so the content is exactly the size of the visible area."
    correct: true
  - text: "contentSize is set by hand while the content is laid out with constraints."
    correct: true
  - text: "The scroll view's bottom is pinned to view.bottomAnchor, so the keyboard covers the end of the content."
    correct: true
  - text: "The scroll view must not be pinned to view.topAnchor; that always hides content under the status bar."
    correct: false
    why: "That's a valid choice for a full-screen scroll view: adjustedContentInset adds the safe area (in the cases contentInsetAdjustmentBehavior covers) so the content starts below the bars."
  - text: "A UIStackView can't be the content of a scroll view."
    correct: false
    why: It's the most common content view, because it provides the unbroken chain of constraints.
rubric:
  - I found the edges pinned to the frame guide.
  - I found contentSize set by hand.
  - I found the bottom not following the keyboard.
solution: |
  1. **Edges to the frame guide.** The stack is now exactly as big as the scroll view, so the content area matches the visible area. Pin the four edges to `contentLayoutGuide`, and only the width to `frameLayoutGuide`.
  2. **`contentSize` by hand** fights the constraints to the content guide (once they exist) and is wrong as soon as the text or the text size changes. Remove it.
  3. **The keyboard.** Pin the scroll view's bottom to `view.keyboardLayoutGuide.topAnchor` so it shrinks above the keyboard, and the user can scroll the Accept button into view.

  Pinning the top to `view.topAnchor` is fine for a full-screen scroll view; the adjusted insets keep the content reachable. The form in the lesson pins to the safe area instead, which avoids depending on `.automatic`'s rules.
````

````exercise
id: m23-l05-e5
type: solve
prompt: |
  Write `offsetToReveal(top:bottom:currentOffset:viewHeight:)`, which returns the new `contentOffset.y` that makes the content range `top...bottom` visible with the least scrolling, like `scrollRectToVisible(_:animated:)`:

  - If the range is already fully visible, return the current offset.
  - If it starts above the visible part, scroll so its top is at the top.
  - If it ends below the visible part, scroll so its bottom is at the bottom.
  - If it's taller than the view, show its top.

  ```swift
  print(offsetToReveal(top: 900, bottom: 950, currentOffset: 0, viewHeight: 500))
  print(offsetToReveal(top: 100, bottom: 150, currentOffset: 400, viewHeight: 500))
  print(offsetToReveal(top: 450, bottom: 480, currentOffset: 200, viewHeight: 500))
  print(offsetToReveal(top: 1000, bottom: 1800, currentOffset: 0, viewHeight: 500))
  ```

  should print `450.0`, `100.0`, `200.0` and `1000.0`.
starter: |
  func offsetToReveal(top: Double, bottom: Double, currentOffset: Double, viewHeight: Double) -> Double {
      // your code
      return currentOffset
  }
hints:
  - "The visible range is currentOffset...currentOffset + viewHeight."
  - "Check the 'taller than the view' case first."
  - "To put a bottom edge at the bottom of the view: offset = bottom − viewHeight."
rubric:
  - Leaves the offset unchanged when the range is fully visible.
  - Aligns the top edge when the range is above.
  - Aligns the bottom edge when the range is below.
  - Shows the top when the range is taller than the view.
solution: |
  ```swift
  func offsetToReveal(top: Double, bottom: Double, currentOffset: Double, viewHeight: Double) -> Double {
      let visibleTop = currentOffset
      let visibleBottom = currentOffset + viewHeight
      if bottom - top > viewHeight { return top }
      if top < visibleTop { return top }
      if bottom > visibleBottom { return bottom - viewHeight }
      return currentOffset
  }

  print(offsetToReveal(top: 900, bottom: 950, currentOffset: 0, viewHeight: 500))
  print(offsetToReveal(top: 100, bottom: 150, currentOffset: 400, viewHeight: 500))
  print(offsetToReveal(top: 450, bottom: 480, currentOffset: 200, viewHeight: 500))
  print(offsetToReveal(top: 1000, bottom: 1800, currentOffset: 0, viewHeight: 500))
  ```

  ```output
  450.0
  100.0
  200.0
  1000.0
  ```

  1. A field at 900–950 below a view showing 0–500: scroll so 950 is the bottom edge, offset 450.
  2. A field at 100–150 above a view showing 400–900: scroll up so 100 is the top.
  3. 450–480 is inside 200–700 already: no change. That's the "does nothing" case Apple documents, and why calling it after every layout is harmless.
  4. An 800-point section in a 500-point view can't be shown whole; showing its top is the sensible choice.

  A real implementation would also clamp the result to the scroll range from the lesson's model, so it never scrolls past the content's ends.
````

````exercise
id: m23-l05-e6
type: explain
prompt: "Explain to a teammate why these two constraints determine how far the scroll view can scroll, even though no constraint mentions contentSize."
code: |
  stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20)
  stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20)
rubric:
  - The content guide represents the content rectangle, whose size is contentSize.
  - The stack's height is determined by its arranged views (fitting size).
  - The two constraints make the content height equal to the stack's height plus 40.
  - Auto Layout solves for the content guide's size, so contentSize follows; without the bottom constraint it would be undetermined.
solution: |
  `contentLayoutGuide` is a layout guide whose rectangle **is** the content area; its size is the scroll view's `contentSize`. Auto Layout treats the guide's height as an unknown like any other. The stack's height is already determined by its arranged views (its fitting size, from their intrinsic heights and spacing). The two constraints say the guide's top is 20 points above the stack and its bottom 20 points below, so the only solution is "guide height = stack height + 40". Auto Layout computes that, and the scroll view uses it as its content size, which, together with its own height and insets, sets the scroll range. Remove the bottom constraint and the guide's height has no equation tying it down: the chain is broken and the content size is undetermined.
````

## Summary

- A scroll view is a frame over content: `contentSize` is how big the content is, `contentOffset` (the bounds origin) is which part shows, and `adjustedContentInset` (your `contentInset` plus the safe area, per `contentInsetAdjustmentBehavior`) is the extra room at the edges.
- The offset ranges from `-adjustedContentInset.top` to `contentHeight + adjustedContentInset.bottom − height`; content shorter than the view doesn't scroll unless `alwaysBounceVertical` is on.
- With Auto Layout: content's four edges to `contentLayoutGuide` (defines the content size), its width to `frameLayoutGuide` (vertical scrolling only), and an unbroken chain of vertical constraints inside it.
- `setContentOffset(_:animated:)` and `scrollRectToVisible(_:animated:)` scroll in code; the latter does nothing if the rectangle is already visible.
- Pin a form's scroll view bottom to `view.keyboardLayoutGuide.topAnchor` (iOS 15+). With the keyboard hidden it sits at the safe area's bottom. Pick `keyboardDismissMode` `.interactive` or `.onDrag`.
