---
id: m25-l03
title: Modal presentation
description: How to show a screen on top of the current one for a self-contained task. You present and dismiss view controllers, choose between sheet, form sheet and full-screen styles, size sheets with detents, stop a swipe from throwing away unsaved work with isModalInPresentation and the adaptive presentation delegate, and decide which object is responsible for dismissing.
module: m25
order: 3
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l02]
objectives:
  - Present a view controller modally, wrapped in a navigation controller when it needs a bar, and dismiss it.
  - Choose a modalPresentationStyle and predict how it adapts in compact width.
  - Configure a sheet's detents, grabber and dimming through sheetPresentationController.
  - Prevent or confirm interactive dismissal with isModalInPresentation and UIAdaptivePresentationControllerDelegate.
  - Explain who dismisses a presented controller and what dismissing a controller lower in the chain does.
terms:
  - term: Modal presentation
    definition: "Showing a view controller on top of the current content with present(_:animated:completion:) for a task the user finishes or cancels. The presenting controller and the presented one are linked through presentedViewController and presentingViewController."
  - term: modalPresentationStyle
    definition: "How a presented controller appears: .automatic (the default), .pageSheet, .formSheet, .fullScreen, .overFullScreen and others. Apple: the style is used as is only in regular width; in compact width some styles take on the behavior of others."
  - term: Sheet
    definition: "A presentation that slides up and leaves part of the content behind it visible. Configured with UISheetPresentationController (iOS 15), reached through the presented controller's sheetPresentationController."
  - term: Detent
    definition: "A height where a sheet naturally rests: .medium() (about half the screen), .large() (full height), or a .custom detent (iOS 16)."
  - term: Interactive dismissal
    definition: "Closing a sheet by swiping it down. isModalInPresentation = true prevents it; the adaptive presentation delegate can refuse it case by case and is told when it was attempted or happened."
mastery:
  - Present an editor in a navigation controller with Cancel and Save, and dismiss it from the presenting side.
  - Present a full-screen player and a medium-height filter sheet with a grabber.
  - Show a "Discard changes?" confirmation when the user swipes down an editor with unsaved changes.
  - Explain why presentationControllerDidDismiss(_:) isn't called after dismiss(animated:) in code.
  - Predict which controllers disappear when a controller in the middle of a presentation chain calls dismiss.
resources: [uikit-sheet-presentation, uikit-adaptive-presentation-delegate, uikit-uiviewcontroller, hig]
cards:
  - id: m25-l03-c1
    front: What does .automatic map to for most view controllers?
    back: "Apple: .formSheet in iOS 18 and later, .pageSheet before iOS 18. In compact width (iPhone portrait) both appear as a sheet; in compact height they behave like .fullScreen."
  - id: m25-l03-c2
    front: You call dismiss(animated:) on a presented controller. What happens?
    back: "UIKit asks its presenting view controller to handle the dismissal. The presenting controller is responsible for dismissing what it presented; called on a controller lower in a chain, it dismisses everything above it."
  - id: m25-l03-c3
    front: How do you configure a half-height sheet with a grabber?
    back: "Before presenting: if let sheet = controller.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }."
  - id: m25-l03-c4
    front: Which delegate method tells you a sheet was swiped away, and when isn't it called?
    back: "UIAdaptivePresentationControllerDelegate.presentationControllerDidDismiss(_:). Apple: it is not called if the presentation is dismissed programmatically."
  - id: m25-l03-c5
    front: After a sheet closes, viewWillAppear(_:) on the screen underneath doesn't run. Why?
    back: "Where the background content stays visible (page and form sheets), Apple says the system doesn't call the presenting controller's viewWillDisappear(_:) and viewDidDisappear(_:). It never disappeared, so it doesn't reappear either. Refresh from the sheet's result instead."
---

## The idea in one sentence

A modal presentation puts a view controller on top of the current one for a task that has a clear end (compose, edit, sign in, pick a filter), and the user leaves it by finishing, cancelling or swiping it away, not with a back button.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `present(_:animated:completion:)`, `dismiss(animated:completion:)`, `UIModalPresentationStyle`, `UISheetPresentationController` and `UIAdaptivePresentationControllerDelegate`, read in November 2026. Nothing was checked in Xcode or the simulator. The plain-Swift models were compiled and run.

## Push or present?

| | Push (lesson 1) | Present |
| --- | --- | --- |
| Meaning | Go deeper into the same content | Start a separate task |
| Example | Folder → Note | "New Note" editor, sign-in, share options |
| Way out | Back button, edge swipe | Cancel / Done / Save, or swipe down on a sheet |
| Container | Needs a navigation controller | Any visible view controller can present |

If the new screen has its own Cancel and Save, it's almost always modal. If the user is browsing, push.

## Presenting and dismissing

A notes list with a + button that opens an editor. The editor needs Cancel and Save in a bar, so it's wrapped in its own navigation controller before it's presented:

```swift ios
import UIKit

final class NewNoteViewController: UIViewController {
    private let folderName: String

    init(folderName: String) {
        self.folderName = folderName
        super.init(nibName: nil, bundle: nil)
        title = "New Note"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("NewNoteViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

final class NotesViewController: UIViewController {
    init(folderName: String) {
        super.init(nibName: nil, bundle: nil)
        title = folderName
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            self?.showNewNote(in: folderName)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("NotesViewController is created in code")
    }

    private func showNewNote(in folderName: String) {
        let editor = NewNoteViewController(folderName: folderName)
        let navigationController = UINavigationController(rootViewController: editor)
        present(navigationController, animated: true) {
            print("editor is on screen")
        }
    }
}
```

- `present(_:animated:completion:)` "presents a view controller modally". The completion runs "after the `viewDidAppear(_:)` method is called on the presented view controller."
- The **navigation controller** is what's presented. The editor is its root, so it gets a bar for its title and buttons, and it could push a second step if it needed one. This presented navigation controller is a separate stack from the one the notes list lives in.
- After the presentation, `self.presentedViewController` is the navigation controller, and the editor's `presentingViewController` is the controller that presented it. Apple's rule for that property: if a controller wasn't presented itself but an ancestor was, it "contains the view controller that presented the ancestor".
- The Cancel button calls `dismiss(animated:)` on the editor. Apple: "The presenting view controller is responsible for dismissing the view controller it presented. If you call this method on the presented view controller itself, UIKit asks the presenting view controller to handle the dismissal." So it works, and it's the shortest code. Who **should** call it is a design question, at the end of this lesson.
- `dismiss`'s completion runs "after the `viewDidDisappear(_:)` method is called on the presented view controller."

The controller you call `present` on isn't always the one that presents. Apple: "a full-screen presentation must be made by a view controller that itself covers the entire screen. If the current view controller is unable to fulfill a request, it forwards the request up the view controller hierarchy." Presenting from a screen inside a navigation controller works; UIKit finds the right presenter.

### One at a time

A view controller presents one controller at a time. Present from a controller that's already presenting, and the second presentation doesn't appear (UIKit logs a warning; the exact text wasn't checked here). Present from the top of the chain instead: the presented controller can present on top of itself, building a stack of presentations.

Dismissing that stack follows one rule, from Apple's page: "calling this method on a view controller lower in the stack dismisses its immediate child view controller and all view controllers above that child on the stack." Only the top one animates. A model of the chain:

```swift
final class Screen {
    let name: String
    private(set) var presented: Screen?
    private(set) weak var presenting: Screen?

    init(name: String) {
        self.name = name
    }

    func present(_ screen: Screen) {
        if let presented {
            print("\(name) is already presenting \(presented.name); \(screen.name) not shown")
            return
        }
        presented = screen
        screen.presenting = self
        print("\(name) presents \(screen.name)")
    }

    func dismiss() {
        if let presented {
            var removed: [String] = []
            var next: Screen? = presented
            while let screen = next {
                removed.append(screen.name)
                next = screen.presented
            }
            print("\(name) dismisses \(removed)")
            self.presented = nil
        } else if let presenting {
            print("\(name) asks \(presenting.name)")
            presenting.dismiss()
        } else {
            print("\(name) has nothing to dismiss")
        }
    }
}

let list = Screen(name: "List")
let editor = Screen(name: "Editor")
let picker = Screen(name: "ColorPicker")

list.present(editor)
editor.present(picker)
list.present(Screen(name: "Alert"))
picker.dismiss()
editor.present(Screen(name: "Help"))
list.dismiss()
list.dismiss()
```

```output
List presents Editor
Editor presents ColorPicker
List is already presenting Editor; Alert not shown
ColorPicker asks Editor
Editor dismisses ["ColorPicker"]
Editor presents Help
List dismisses ["Editor", "Help"]
List has nothing to dismiss
```

- The list can't present the alert: it's already presenting the editor. The editor (the top) could have.
- `picker.dismiss()` has nothing presented, so it asks its presenter, the editor. That's the forwarding from Apple's rule.
- `list.dismiss()` removes everything above the list in one call.
- `presenting` is `weak`, like UIKit's back-references: the presenter owns what it presents, not the other way around.

> [!warning] dismiss on a screen that isn't presenting anything closes that screen
> Follow the rule above one step further: if a presented controller calls `dismiss(animated:)` on itself when it has nothing presented, it's the one that goes away. A "close the color picker" call that runs after the picker already closed will close the editor too, along with the user's unsaved text.

## Presentation styles

Set `modalPresentationStyle` on the controller **before** presenting it. The default is `.automatic`:

| Style | What Apple says it does |
| --- | --- |
| `.automatic` | "For most view controllers, UIKit maps this style to: `formSheet` in iOS 18 and later, `pageSheet` in versions of iOS earlier than iOS 18" |
| `.pageSheet` | "Partially covers the underlying content." Roughly page-sized in regular width; a sheet with the background visible near the top in compact width |
| `.formSheet` | Centered, smaller than a page sheet by default, sized with `preferredContentSize` in regular width; a sheet in compact width |
| `.fullScreen` | "The presented view covers the screen." The presenter's views are removed after the presentation |
| `.overFullScreen` | Covers the screen, but the views underneath stay, so transparent areas show them |

Both sheet styles become `.fullScreen` in a compact-height size class (an iPhone in landscape). And Apple's rule for when the style applies at all: "The system uses this value only in regular-width size classes. In compact-width size classes, some styles take on the behavior of other styles."

Full screen is for content that should take over: a video player, a camera, onboarding. A sheet is the default for tasks, because the visible edge of the screen behind it tells people where they'll return.

```swift ios
import UIKit

final class PlayerViewController: UIViewController {}

@MainActor
func play(from presenter: UIViewController) {
    let player = PlayerViewController()
    player.modalPresentationStyle = .fullScreen
    presenter.present(player, animated: true)
}
```

A full-screen controller can't be swiped away, so it needs its own Close button.

> [!warning] The screen under a sheet doesn't disappear
> For page and form sheets, Apple: "Where the background content remains visible, the system doesn't call the presenting view controller's `viewWillDisappear(_:)` and `viewDidDisappear(_:)` methods." The screen never left, so it doesn't "reappear" either when the sheet closes. Code that refreshes a list in `viewWillAppear(_:)` after an editor sheet closes won't run. Have the editor report its result (lesson 4) and refresh then.

## Sheets and detents

Since iOS 15 a sheet can rest at more than one height. You configure it through the presented controller's `sheetPresentationController`, before presenting:

```swift ios
import UIKit

final class FiltersViewController: UIViewController {}

final class MapViewController: UIViewController {
    func showFilters() {
        let filters = FiltersViewController()
        if let sheet = filters.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.largestUndimmedDetentIdentifier = .medium
        }
        present(filters, animated: true)
    }

    func showCompactFilters() {
        let filters = FiltersViewController()
        let small = UISheetPresentationController.Detent.Identifier("small")
        if let sheet = filters.sheetPresentationController {
            sheet.detents = [.custom(identifier: small) { _ in 200 }, .large()]
            sheet.selectedDetentIdentifier = small
        }
        present(filters, animated: true)
    }
}
```

- `sheetPresentationController` contains a sheet controller when `modalPresentationStyle` is `.pageSheet` or `.formSheet`, and is `nil` for other styles. Apple's own example reads it with the default style, which maps to a sheet for most controllers. If you've set a non-sheet style, there's nothing to configure.
- `detents` must contain at least one element, "in order from smallest to largest height". The default is `[.large()]`. `.medium()` is "approximately half the height of the screen, and is inactive in compact height."
- `prefersGrabberVisible` draws the small handle at the top. Apple suggests it "when it isn't apparent that a sheet can resize or when the sheet can't dismiss interactively."
- `largestUndimmedDetentIdentifier = .medium` removes the dimming at the medium height, so the map behind the sheet stays interactive. Without it, the system dims the content behind at every detent.
- `.custom(identifier:resolver:)` (iOS 16) computes a height. The value is "a height within the safe area of the sheet", and returning `nil` makes the detent inactive. The resolver must not set properties on the sheet controller.
- `selectedDetentIdentifier` chooses the starting detent. When it's `nil`, "the sheet displays at the smallest detent you specify in detents". To change detents or the selection while the sheet is visible, do it inside `sheet.animateChanges { }`.

## Stopping a swipe from losing work

A sheet can be swiped down. That's fine for a filter panel and bad for an editor with a paragraph of unsaved text. UIKit gives you two levels of control:

- **`isModalInPresentation = true`** on the presented controller: "UIKit ignores events outside the view controller's bounds and prevents the interactive dismissal of the view controller while it is onscreen." Use it for a screen that must be finished with a button, like a required form.
- **`UIAdaptivePresentationControllerDelegate`**, set on the presentation controller, decides each time and hears about the attempts.

```swift ios
import UIKit

final class EditNoteViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let originalText: String
    private var currentText: String

    init(text: String) {
        originalText = text
        currentText = text
        super.init(nibName: nil, bundle: nil)
        title = "Edit Note"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("EditNoteViewController is created in code")
    }

    private var hasChanges: Bool {
        currentText != originalText
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        !hasChanges
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        let alert = UIAlertController(title: "Discard your changes?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("swiped away with no changes")
    }
}

@MainActor
func edit(text: String, from presenter: UIViewController) {
    let editor = EditNoteViewController(text: text)
    let navigationController = UINavigationController(rootViewController: editor)
    navigationController.presentationController?.delegate = editor
    presenter.present(navigationController, animated: true)
}
```

- The delegate goes on the presentation controller of **what's presented**: the navigation controller, not the editor inside it. `presentationController` exists before presenting; Apple: "accessing this property creates a presentation controller based on the current value in the `modalPresentationStyle` property. Always set the value of that property before accessing any presentation controllers."
- `presentationControllerShouldDismiss(_:)` returns `false` while there are changes, so the swipe is refused. Apple: "The system may call this method at any time... Make sure that your implementation of this method returns quickly."
- `presentationControllerDidAttemptToDismiss(_:)` runs when a swipe was refused, either by `isModalInPresentation` or by `false` from the method above. Apple suggests exactly this: "inform the user why the presentation can't be dismissed, for example, by presenting an instance of UIAlertController."
- The alert is presented **from the editor**, the top of the chain. The editor isn't presenting anything yet, so this is allowed. "Discard" asks the editor's `presentingViewController` (the notes list) to dismiss. Called on the list, `dismiss` removes everything above it, so the editor goes whether or not the alert has finished its own dismissal.
- `presentationControllerDidDismiss(_:)` runs after a swipe that succeeded. Apple: "This method is not called if the presentation is dismissed programmatically." Cancel, Save and Discard all dismiss in code, so if you need cleanup after every kind of close, it can't live only here. Lesson 5 handles that in one place.

The decision itself is plain logic: compare what the editor started with to what it has now. That's the solve exercise below.

## Who dismisses?

Two ways to close the editor when the user taps Save:

1. **The editor dismisses itself**: `dismiss(animated: true)`. Short, and it works because UIKit forwards to the presenter.
2. **The editor reports, the presenter dismisses**: the editor calls back with the saved note, and the list (or a coordinator) saves it and calls `dismiss(animated:)` on itself.

The second is the better default. The presenter decided to show the editor and knows how: presented, pushed in a tab on iPad, embedded in a split view. If the editor dismisses itself, it assumes it was presented, and it breaks the day someone pushes it instead. Apple's own wording backs this up: "The presenting view controller is responsible for dismissing the view controller it presented." Lesson 4 shows how the editor reports back; lesson 5 moves the presenting and dismissing into a coordinator.

## Common mistakes

> [!error] Presenting from a controller that's already presenting
> The second presentation never appears. Present from the top of the chain, or check `presentedViewController == nil` first.

> [!error] Configuring the sheet after presenting it
> Set `modalPresentationStyle`, `detents` and the delegate before calling `present`. Later changes to the sheet need `animateChanges`, and a different style needs a new presentation.

> [!error] Expecting viewWillAppear(_:) after a sheet closes
> The presenter's view never disappeared, so it doesn't reappear. Refresh when the sheet reports its result.

> [!error] Cleanup only in presentationControllerDidDismiss(_:)
> It runs only when the user swipes the sheet away, never after `dismiss(animated:)` in code. Put the cleanup where both paths end up.

> [!error] Setting the delegate on the inner controller's presentation controller
> When you present a navigation controller, the presentation controller belongs to that navigation controller. Set `navigationController.presentationController?.delegate`.

## Exercises

````exercise
id: m25-l03-e1
type: prediction
prompt: "Using the lesson's presentation model, what does this print?"
code: |
  final class Screen {
      let name: String
      private(set) var presented: Screen?
      private(set) weak var presenting: Screen?

      init(name: String) {
          self.name = name
      }

      func present(_ screen: Screen) {
          if let presented {
              print("\(name) busy with \(presented.name)")
              return
          }
          presented = screen
          screen.presenting = self
      }

      func dismiss() {
          if let presented {
              var removed: [String] = []
              var next: Screen? = presented
              while let screen = next {
                  removed.append(screen.name)
                  next = screen.presented
              }
              print("\(name) dismisses \(removed)")
              self.presented = nil
          } else if let presenting {
              presenting.dismiss()
          } else {
              print("\(name): nothing")
          }
      }
  }

  let home = Screen(name: "Home")
  let checkout = Screen(name: "Checkout")
  let card = Screen(name: "AddCard")
  home.present(checkout)
  checkout.present(card)
  home.present(Screen(name: "Promo"))
  checkout.dismiss()
  checkout.dismiss()
  home.dismiss()
output: |
  Home busy with Checkout
  Checkout dismisses ["AddCard"]
  Home dismisses ["Checkout"]
  Home: nothing
hints:
  - "Home is presenting Checkout when it tries to present Promo."
  - "The second checkout.dismiss() happens when Checkout has nothing presented."
solution: |
  ```output
  Home busy with Checkout
  Checkout dismisses ["AddCard"]
  Home dismisses ["Checkout"]
  Home: nothing
  ```

  Home can't present Promo while it's presenting Checkout. The first `checkout.dismiss()` dismisses what Checkout presented, AddCard. The second one finds nothing presented, so it asks Home, which dismisses Checkout itself: this is the "dismiss closes the wrong screen" trap from the lesson. By the time `home.dismiss()` runs, there's nothing left.
````

````exercise
id: m25-l03-e2
type: comprehension
prompt: "An app targets iOS 17 and later. On an iPhone in portrait, a controller is presented with the default modalPresentationStyle. How does it appear?"
choices:
  - text: "As a sheet that leaves part of the screen behind it visible at the top, on both iOS 17 and iOS 18+."
    correct: true
    why: ".automatic maps to .pageSheet before iOS 18 and .formSheet from iOS 18; in compact width both display as a sheet."
  - text: "Full screen, because iPhones always present full screen."
    correct: false
    why: "That was the default before iOS 13. In compact height (landscape) sheets do become full screen, but not in portrait."
  - text: "As a centered form, smaller than the screen, on iOS 18 and later."
    correct: false
    why: "That's .formSheet in regular width (iPad). In compact width it's a sheet."
  - text: "As a popover pointing at the button that was tapped."
    correct: false
    why: "That's .popover, and only with an anchor."
solution: |
  **A sheet.** `.automatic` maps to `.formSheet` in iOS 18 and later and to `.pageSheet` earlier. Apple describes both, in a compact-width, regular-height size class, as "a sheet with part of the background content visible near the top of the screen." The difference between them shows up on iPad. Turn the iPhone to landscape (compact height) and both behave like `.fullScreen`.
````

````exercise
id: m25-l03-e3
type: fill-in
prompt: "Configure and present a half-height sheet with a grabber that refuses to be swiped away."
code: |
  let picker = EmojiPickerViewController()
  if let sheet = picker.[[1]] {
      sheet.detents = [.[[2]](), .large()]
      sheet.[[3]] = true
  }
  picker.[[4]] = true
  [[5]](picker, animated: true)
blanks:
  - id: "1"
    answers: ["sheetPresentationController"]
  - id: "2"
    answers: ["medium"]
  - id: "3"
    answers: ["prefersGrabberVisible"]
  - id: "4"
    answers: ["isModalInPresentation"]
  - id: "5"
    answers: ["present"]
solution: |
  ```swift ios
  import UIKit

  final class EmojiPickerViewController: UIViewController {}

  final class ChatViewController: UIViewController {
      func showEmojiPicker() {
          let picker = EmojiPickerViewController()
          if let sheet = picker.sheetPresentationController {
              sheet.detents = [.medium(), .large()]
              sheet.prefersGrabberVisible = true
          }
          picker.isModalInPresentation = true
          present(picker, animated: true)
      }
  }
  ```

  The grabber still lets people move between the two detents; `isModalInPresentation` only blocks dismissing. Apple suggests showing the grabber precisely when "the sheet can't dismiss interactively". The picker now needs its own Done button.
````

````exercise
id: m25-l03-e4
type: solve
prompt: |
  Write the decision behind the editor's swipe-down handling. `swipeDownBehavior(original:current:)` returns `.close` when the text hasn't really changed (ignoring leading and trailing spaces and newlines) and `.askToDiscard` otherwise.

  ```swift
  let cases = [("", ""), ("", "Milk"), ("Milk", "Milk  "), ("Milk", "Eggs"), ("Milk", "")]
  for (original, current) in cases {
      print("\"\(original)\" -> \"\(current)\":", swipeDownBehavior(original: original, current: current))
  }
  ```

  should print:

  ```plaintext
  "" -> "": close
  "" -> "Milk": askToDiscard
  "Milk" -> "Milk  ": close
  "Milk" -> "Eggs": askToDiscard
  "Milk" -> "": askToDiscard
  ```
starter: |
  import Foundation

  enum SwipeDown {
      case close
      case askToDiscard
  }

  func swipeDownBehavior(original: String, current: String) -> SwipeDown {
      // your code
      .close
  }
hints:
  - "trimmingCharacters(in: .whitespacesAndNewlines) needs import Foundation."
  - "Trim both strings, then compare."
rubric:
  - Whitespace-only differences count as no change.
  - Deleting all the text counts as a change.
  - No UIKit dependency.
  - The output matches.
solution: |
  ```swift
  import Foundation

  enum SwipeDown {
      case close
      case askToDiscard
  }

  func swipeDownBehavior(original: String, current: String) -> SwipeDown {
      let before = original.trimmingCharacters(in: .whitespacesAndNewlines)
      let after = current.trimmingCharacters(in: .whitespacesAndNewlines)
      return before == after ? .close : .askToDiscard
  }

  let cases = [("", ""), ("", "Milk"), ("Milk", "Milk  "), ("Milk", "Eggs"), ("Milk", "")]
  for (original, current) in cases {
      print("\"\(original)\" -> \"\(current)\":", swipeDownBehavior(original: original, current: current))
  }
  ```

  ```output
  "" -> "": close
  "" -> "Milk": askToDiscard
  "Milk" -> "Milk  ": close
  "Milk" -> "Eggs": askToDiscard
  "Milk" -> "": askToDiscard
  ```

  In the editor, `presentationControllerShouldDismiss(_:)` becomes `swipeDownBehavior(original: originalText, current: currentText) == .close`. Apple asks that method to return quickly, and a string comparison does. Emptying a note that had text is a change: the user might have done it by accident, so it's worth a question.
````

````exercise
id: m25-l03-e5
type: find-errors
prompt: "This code presents a settings sheet. The \"Discard?\" confirmation never appears when the user swipes down with changes, and a log line meant to run after every close only runs sometimes. Mark every real problem."
code: |
  func showSettings() {
      let settings = SettingsFormViewController()
      let navigation = UINavigationController(rootViewController: settings)
      settings.presentationController?.delegate = settings
      present(navigation, animated: true)
      navigation.modalPresentationStyle = .formSheet
  }

  // In SettingsFormViewController:
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
      print("settings closed")
  }
choices:
  - text: "The delegate is set on the inner controller's presentation controller, but what's presented is the navigation controller."
    correct: true
  - text: "modalPresentationStyle is set after present, too late to have any effect on this presentation."
    correct: true
  - text: "presentationControllerDidDismiss(_:) isn't called when the sheet is closed with dismiss(animated:) in code, so the log line misses the Cancel and Save paths."
    correct: true
  - text: "A navigation controller can't be presented; only plain view controllers can."
    correct: false
    why: "Presenting a navigation controller is the standard way to give a modal screen a bar."
  - text: "presentationControllerDidDismiss(_:) must return a Bool."
    correct: false
    why: "It returns nothing. presentationControllerShouldDismiss(_:) is the one that returns Bool."
rubric:
  - I found the delegate on the wrong presentation controller.
  - I found the style set after presenting.
  - I explained why the dismiss callback misses programmatic closes.
solution: |
  ```swift ios
  import UIKit

  final class SettingsFormViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
      func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
          print("settings swiped away")
      }
  }

  final class HomeViewController: UIViewController {
      func showSettings() {
          let settings = SettingsFormViewController()
          let navigation = UINavigationController(rootViewController: settings)
          navigation.modalPresentationStyle = .formSheet
          navigation.presentationController?.delegate = settings
          present(navigation, animated: true)
      }
  }
  ```

  Style first, then the presentation controller (Apple: set the style "before accessing any presentation controllers"), then the delegate on the navigation controller's presentation controller, then `present`. The "after every close" work goes where the Cancel and Save paths and the swipe path all end, for example a method the presenter calls from its own dismiss completion and from `presentationControllerDidDismiss(_:)`.
````

````exercise
id: m25-l03-e6
type: explain
prompt: "A teammate's editor sheet saves the note and then calls `dismiss(animated: true)` on itself. The list underneath reloads in `viewWillAppear(_:)`. After saving, the list shows stale data. Explain both reasons the design is fragile and how you'd change it."
code: |
  // EditorViewController
  func save() {
      store.save(note)
      dismiss(animated: true)
  }

  // NoteListViewController
  override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      reloadNotes()
  }
rubric:
  - Explains that a sheet doesn't trigger viewWillDisappear/viewWillAppear on the presenter.
  - Explains that the editor dismissing itself assumes how it was shown.
  - Proposes reporting the result to the presenter, which reloads and dismisses.
solution: |
  1. **`viewWillAppear(_:)` never runs.** With a page or form sheet, Apple says the presenter's `viewWillDisappear(_:)` and `viewDidDisappear(_:)` aren't called because the background stays visible. So the list never "appears" again, and `reloadNotes()` isn't called.
  2. **The editor decides how it leaves.** `dismiss(animated:)` works only because the editor happens to be presented. Push it on iPad, embed it, and Save does the wrong thing.

  Let the editor report: a closure or delegate call with the saved note (lesson 4). The list (or a coordinator, lesson 5) receives it, updates its data, and calls `dismiss(animated:)` itself. The refresh then happens because the data changed, not because of a lifecycle callback.
````

## Summary

- Present for a separate task, push for going deeper. Wrap a presented screen in a `UINavigationController` when it needs a bar.
- `present(_:animated:completion:)` and `dismiss(animated:completion:)`. A controller presents one thing at a time; dismissing a controller lower in the chain removes everything above it, and calling `dismiss` on a controller with nothing presented dismisses that controller itself.
- `.automatic` means a sheet for most controllers (`.formSheet` from iOS 18, `.pageSheet` before). Styles adapt: in compact width both sheet styles slide up from the bottom; in compact height they become full screen.
- Under a sheet, the presenter's disappear and appear methods don't run.
- `sheetPresentationController`: `detents` (`.medium()`, `.large()`, `.custom`), `prefersGrabberVisible`, `largestUndimmedDetentIdentifier`, `selectedDetentIdentifier`; set them before presenting.
- `isModalInPresentation` blocks the swipe; `presentationControllerShouldDismiss(_:)` decides per attempt, `presentationControllerDidAttemptToDismiss(_:)` lets you ask, `presentationControllerDidDismiss(_:)` runs only after a swipe.
- The presenter is responsible for dismissing. Have the presented screen report its result and let the presenter close it.
