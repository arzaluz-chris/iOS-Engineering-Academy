---
id: m24-l02
title: Alerts and action sheets
description: How to ask the user something or warn them with UIAlertController. You build alerts and action sheets with default, cancel and destructive actions, read text fields inside an alert without creating a retain cycle, enable an action only when the input is valid, anchor action sheets correctly on iPad, and present them from the right view controller at the right time.
module: m24
order: 2
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l01]
objectives:
  - Create an alert or an action sheet with UIAlertController and present it from a view controller.
  - Choose between the default, cancel and destructive action styles and set a preferred action.
  - Add text fields to an alert, read their values safely and enable an action only for valid input.
  - Anchor an action sheet to a view or a bar button item so it works as a popover on iPad.
  - Present alerts only from a view controller whose view is on screen.
terms:
  - term: UIAlertController
    definition: "A view controller that shows an alert or an action sheet with a title, a message, actions and (alerts only) text fields. You configure it, then present it with present(_:animated:completion:). It isn't meant to be subclassed."
  - term: Alert
    definition: "The .alert style: a small modal box in the middle of the screen for important information or a decision the user has to make now."
  - term: Action sheet
    definition: "The .actionSheet style: a set of choices related to an action the user just started. On iPhone it slides up from the bottom; in a regular-width environment it's shown as a popover anchored to the control that triggered it."
  - term: Action style
    definition: "UIAlertAction.Style: .default, .cancel (leaves things unchanged) or .destructive (\"might change or delete data\"). The style changes how the button looks and where it goes."
  - term: Preferred action
    definition: "The action an alert emphasizes and triggers with the Return key on a hardware keyboard. It must already be added to the alert."
mastery:
  - Write a delete confirmation alert with a cancel and a destructive action.
  - Write a rename alert with a text field, a disabled Save action that enables when the text is valid, and a handler that reads the text through a weak reference.
  - Present an action sheet from a button and from a bar button item, with the popover anchor set.
  - Explain why presenting an alert in viewDidLoad() doesn't work and where to present it instead.
resources: [uikit-uiviewcontroller, hig, apple-documentation]
cards:
  - id: m24-l02-c1
    front: The three UIAlertAction styles and when to use each?
    back: ".default for ordinary choices, .cancel for the one action that leaves things unchanged, .destructive for an action that might change or delete data. Use at most one cancel action."
  - id: m24-l02-c2
    front: What must you set before presenting an action sheet so it works on iPad?
    back: "Its popoverPresentationController's anchor: sourceItem for a bar button item (iOS 16), or sourceView and sourceRect for a view. Without an anchor, presenting it in a regular-width environment stops the app with an exception."
  - id: m24-l02-c3
    front: How do you read an alert's text field in the action handler without a retain cycle?
    back: "Capture the alert weakly: UIAlertAction(title:style:) { [weak alert] _ in let text = alert?.textFields?.first?.text }. The alert owns its actions, so a strong capture would make the alert own itself."
  - id: m24-l02-c4
    front: Can an action sheet have text fields?
    back: "No. Apple: you can add a text field only if preferredStyle is .alert."
  - id: m24-l02-c5
    front: Where can't you present an alert from, and why?
    back: "From viewDidLoad(), or from a controller whose view isn't in a window yet: there's nothing on screen to present over. Present from viewDidAppear(_:) or in response to a user action, from a controller that's visible and not already presenting something."
---

## The idea in one sentence

An alert or action sheet is a view controller you fill with a title, a message and actions, and present modally from whichever view controller is on screen; UIKit draws it, dismisses it when the user picks an action, and then runs that action's closure.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `UIAlertController`, `UIAlertAction`, `UIPopoverPresentationController` and `present(_:animated:completion:)`, read in November 2026. Two runtime behaviors in this lesson aren't stated on those pages, and the text says so where they appear. The plain-Swift models were compiled and run.

## Alert or action sheet

| | Alert (`.alert`) | Action sheet (`.actionSheet`) |
| --- | --- | --- |
| Use it for | Important information, or a decision that blocks what the user is doing | Choices related to something the user just started |
| Example | "Couldn't save. Try again?" | Tap "Share": Copy Link, Message, Mail, Cancel |
| Text fields | Allowed | Not allowed |
| On iPad | Centered alert | Popover anchored to its source |

Use either sparingly. An alert interrupts; if the information can wait or sit inline (a label under a field, a banner), it should.

## A first alert

A confirmation before deleting something:

```swift ios
import UIKit

final class NoteViewController: UIViewController {
    private let deleteButton = UIButton(configuration: .plain())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        deleteButton.configuration?.title = "Delete Note"
        deleteButton.addAction(UIAction { [weak self] _ in
            self?.confirmDelete()
        }, for: .primaryActionTriggered)
        view.addSubview(deleteButton)
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete this note?",
            message: "This can't be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteNote()
        })
        present(alert, animated: true)
    }

    private func deleteNote() {
        print("note deleted")
    }
}
```

Line by line:

1. `UIAlertController(title:message:preferredStyle:)` creates the controller. Both strings are optional, but an alert needs a title that says what's going on; the message adds detail.
2. `UIAlertAction(title:style:handler:)` describes one button. The handler is optional (`nil` by default), so "Cancel" needs none: tapping any action dismisses the alert on its own.
3. `addAction(_:)` adds it. "The order in which you add those actions determines their order in the resulting alert or action sheet", except that the system places the cancel action itself.
4. `present(alert, animated: true)` shows it. `UIAlertController` is a view controller, so you present it like any other (Module 25 covers presentation in depth).
5. The destructive handler captures `self` weakly. The alert doesn't outlive the screen for long, but the habit costs nothing.

The title is a question that names the thing, and the destructive button repeats the verb ("Delete"), not "OK". People read the button, not the message.

### Action styles

- **`.default`**: an ordinary choice.
- **`.cancel`**: "indicates the action cancels the operation and leaves things unchanged." Use one per alert. (UIKit stops the app with an exception if you add a second cancel action. This isn't stated on the reference page; it's long-standing runtime behavior.)
- **`.destructive`**: "indicates the action might change or delete data." It's drawn in red. It doesn't ask for confirmation by itself; the alert **is** the confirmation.

### The preferred action

`preferredAction` highlights one action and makes the Return key on a hardware keyboard trigger it. Apple's rules: "The preferred action is relevant for the alert style only", and "Assigning an object to this property before adding it with the addAction(_:) method is a programmer error." Add first, then assign:

```swift ios
import UIKit

let alert = UIAlertController(title: "Unsaved changes", message: "Save before closing?", preferredStyle: .alert)
let discard = UIAlertAction(title: "Discard", style: .destructive)
let save = UIAlertAction(title: "Save", style: .default) { _ in
    print("saving")
}
alert.addAction(discard)
alert.addAction(save)
alert.preferredAction = save
```

## Text fields in an alert

Alerts can collect a small amount of text: a name, a passcode. `addTextField(configurationHandler:)` adds one and lets you configure it; `textFields` gives them back in the order you added them. A rename alert:

```swift ios
import UIKit

final class FolderViewController: UIViewController {
    private var folderName = "Untitled"

    func showRenameAlert() {
        let alert = UIAlertController(title: "Rename Folder", message: nil, preferredStyle: .alert)

        alert.addTextField { [folderName] field in
            field.text = folderName
            field.placeholder = "Folder name"
            field.clearButtonMode = .whileEditing
            field.autocapitalizationType = .words
        }

        let save = UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text else { return }
            self?.rename(to: name)
        }

        alert.textFields?.first?.addAction(UIAction { [weak save] action in
            guard let field = action.sender as? UITextField else { return }
            let trimmed = (field.text ?? "").trimmingCharacters(in: .whitespaces)
            save?.isEnabled = !trimmed.isEmpty
        }, for: .editingChanged)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(save)
        alert.preferredAction = save
        present(alert, animated: true)
    }

    private func rename(to name: String) {
        folderName = name
        print("renamed to \(name)")
    }
}
```

What each part is for:

- **`[folderName]` in the configuration closure** captures the current value, not `self`. The closure runs right away, so this is about clarity more than memory.
- **`[weak self, weak alert]` in the Save handler.** The alert owns its actions, and each action owns its handler. If the handler captured `alert` strongly, the alert would own itself through its own action and never be released: the same cycle as `UIAction` and `self` in Module 22, one level down. `weak` breaks it; when the handler runs, the alert is still alive, so `alert?` succeeds.
- **`.editingChanged` on the field** enables Save only when the trimmed text isn't empty. `isEnabled = false` makes the action "appear dimmed", and "taps on the corresponding button have no effect." The field's action captures `save` weakly for the same ownership reason: alert → field → action → closure → save, and the alert already owns `save`.
- **`textFields?.first?.text`**: `textFields` is optional (`nil` when there are none) and `text` is optional, hence the chain.

> [!warning] Text fields are alert-only
> Apple: "You can add a text field only if the preferredStyle property is set to alert." An action sheet can't collect text.

Keep it to one or two fields. Anything longer (an address, a form with validation messages) belongs on its own screen.

## Action sheets

An action sheet offers choices about something the user just started. The same API, a different style:

```swift ios
import UIKit

final class PhotoViewController: UIViewController {
    private let shareButton = UIButton(configuration: .tinted())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        var configuration = UIButton.Configuration.tinted()
        configuration.title = "Share"
        configuration.image = UIImage(systemName: "square.and.arrow.up")
        shareButton.configuration = configuration
        shareButton.addAction(UIAction { [weak self] _ in
            self?.showShareOptions()
        }, for: .primaryActionTriggered)
        view.addSubview(shareButton)
    }

    private func showShareOptions() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            print("link copied")
        })
        sheet.addAction(UIAlertAction(title: "Save to Files", style: .default) { _ in
            print("saved")
        })
        sheet.addAction(UIAlertAction(title: "Delete Photo", style: .destructive) { _ in
            print("deleted")
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(sheet, animated: true)
    }
}
```

- `title` and `message` are often `nil` for action sheets: the button the user tapped is the context.
- **Always include a cancel action.** On iPhone the sheet covers part of the screen, and Cancel is the way out.

### The anchor on iPad

In a regular-width environment (iPad, or a wide window), an action sheet appears as a **popover**, and a popover has to point at something. The alert's `popoverPresentationController` is where you say what:

| Property | Use |
| --- | --- |
| `sourceItem` (iOS 16) | Anchor to "the specified UIBarButtonItem or NSToolbarItem". Views also adopt `UIPopoverPresentationControllerSourceItem` in the current SDK, but for a view the long-standing pair below is the clearest |
| `sourceView` + `sourceRect` | Anchor to a rectangle in a view's coordinate space. "The rectangle must be in the coordinate space of sourceView" (Module 23, lesson 1), which is why the example passes the button's `bounds`, not its `frame` |
| `barButtonItem` | Deprecated. Use `sourceItem` |

On iPhone the sheet isn't shown as a popover, and the anchor is simply unused, so the same code runs on both devices. The `if let` (or `?.`) covers the case where the property is `nil`. Set the anchor every time, even in an iPhone-only design: the same app can run in a resizable window on iPad.

> [!error] An action sheet with no anchor on iPad
> Presenting an action sheet in a regular-width environment without `sourceItem` or `sourceView` stops the app with an exception whose message asks for the popover's location. The reference pages don't spell this out, so the bug survives every iPhone test and appears on the first iPad run. Set the anchor every time.

From a bar button item, `sourceItem` is the whole anchor:

```swift ios
import UIKit

final class InboxViewController: UIViewController {
    private lazy var moreItem = UIBarButtonItem(
        image: UIImage(systemName: "ellipsis.circle"),
        primaryAction: UIAction { [weak self] _ in self?.showMore() }
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        moreItem.accessibilityLabel = "More"
        navigationItem.rightBarButtonItem = moreItem
    }

    private func showMore() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Mark All as Read", style: .default))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceItem = moreItem
        present(sheet, animated: true)
    }
}
```

Apple notes a change in iOS 26: "In iOS 18 and earlier, the popover's arrow points to the specified item. In iOS 26 and later, the popover animates from and replaces the specified item." The code is the same.

> [!tip] For a fixed list of choices, consider a menu
> A button or bar button item with a `menu` shows its choices directly on tap, without a separate presentation. Action sheets still fit confirmations ("Delete Photo" / "Cancel") and choices you build on the fly. Menus come back in Module 27.

## Presenting from the right place

`present(_:animated:completion:)` needs a view controller whose view is actually on screen. Two rules follow:

1. **Not in `viewDidLoad()`.** The view has been loaded but isn't in a window yet (Module 22, lesson 2), so there's nothing to present over, and UIKit logs a warning instead of showing the alert. Present in response to a user action, or from `viewDidAppear(_:)` if the alert must appear as soon as the screen does.
2. **One presentation at a time.** A view controller that's already presenting something can't present a second controller on top of it from the same place. UIKit logs a warning and the second alert never appears. Check `presentedViewController`, or present from the controller that's currently on top.

```swift ios
import UIKit

final class OnboardingViewController: UIViewController {
    private var hasShownWelcome = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasShownWelcome, presentedViewController == nil else { return }
        hasShownWelcome = true

        let alert = UIAlertController(title: "Welcome", message: "Your data stays on this device.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default))
        present(alert, animated: true)
    }
}
```

`viewDidAppear(_:)` runs every time the view appears, including after the alert itself is dismissed. Without the flag, this screen would show the welcome alert again each time.

> [!note] Don't customize the alert's views
> Apple: "The UIAlertController class is intended to be used as-is and doesn't support subclassing. The view hierarchy for this class is private and must not be modified." If you need custom content, present your own view controller (Module 25).

## The decisions, without UIKit

What the alert **says** is logic you can test. This model builds a delete confirmation for a number of items and checks a planned alert against the rules from this lesson:

```swift
enum Style { case alert, actionSheet }
enum ActionStyle { case normal, cancel, destructive }

struct AlertPlan {
    var style: Style
    var title: String?
    var actions: [(title: String, style: ActionStyle)]
    var textFieldCount = 0
    var hasAnchor = false
}

func deleteConfirmation(count: Int, noun: String) -> AlertPlan {
    let label = count == 1 ? "this \(noun)" : "\(count) \(noun)s"
    return AlertPlan(
        style: .alert,
        title: "Delete \(label)?",
        actions: [("Cancel", .cancel), (count == 1 ? "Delete" : "Delete All", .destructive)]
    )
}

func problems(in plan: AlertPlan) -> [String] {
    var found: [String] = []
    let cancelCount = plan.actions.filter { $0.style == .cancel }.count
    if cancelCount > 1 { found.append("more than one cancel action") }
    if plan.style == .actionSheet && plan.textFieldCount > 0 { found.append("text fields in an action sheet") }
    if plan.style == .actionSheet && !plan.hasAnchor { found.append("no popover anchor for iPad") }
    if plan.style == .actionSheet && cancelCount == 0 { found.append("action sheet without a cancel action") }
    if plan.actions.isEmpty { found.append("no actions") }
    return found
}

for count in [1, 3] {
    let plan = deleteConfirmation(count: count, noun: "photo")
    print(plan.title ?? "-", plan.actions.map { $0.title }, problems(in: plan))
}

let badSheet = AlertPlan(style: .actionSheet, title: nil, actions: [("Copy", .normal)], textFieldCount: 1)
print(problems(in: badSheet))
```

```output
Delete this photo? ["Cancel", "Delete"] []
Delete 3 photos? ["Cancel", "Delete All"] []
["text fields in an action sheet", "no popover anchor for iPad", "action sheet without a cancel action"]
```

The plural is built with the simplest rule that works for this noun. Real apps localize these strings, and plural rules differ between languages, which Module 43 handles with string catalogs.

## Common mistakes

> [!error] Capturing the alert strongly in its own action
> `UIAlertAction(title: "Save", style: .default) { _ in let text = alert.textFields?.first?.text }` makes the alert own itself through its action, and it's never released. Capture `[weak alert]`.

> [!error] Presenting in viewDidLoad()
> The view isn't in a window yet. Nothing appears, and the console shows a presentation warning. Present from `viewDidAppear(_:)` or in response to the user.

> [!error] "OK" on a destructive action
> "Delete this note?" with "OK" / "Cancel" makes people read the title to know what OK does. Name the action with its verb, and give it `.destructive`.

> [!error] Setting preferredAction before addAction
> Apple calls it a programmer error. Add the action first.

> [!error] An alert for everything
> Validation messages, success notes and tips don't need to block the screen. Reserve alerts for decisions and for problems the user has to act on now.

## Exercises

````exercise
id: m24-l02-e1
type: prediction
prompt: "Using the lesson's alert plan model, what does this print?"
code: |
  enum Style { case alert, actionSheet }
  enum ActionStyle { case normal, cancel, destructive }

  struct AlertPlan {
      var style: Style
      var actions: [(title: String, style: ActionStyle)]
      var textFieldCount = 0
      var hasAnchor = false
  }

  func problems(in plan: AlertPlan) -> [String] {
      var found: [String] = []
      let cancelCount = plan.actions.filter { $0.style == .cancel }.count
      if cancelCount > 1 { found.append("two cancels") }
      if plan.style == .actionSheet && plan.textFieldCount > 0 { found.append("fields in sheet") }
      if plan.style == .actionSheet && !plan.hasAnchor { found.append("no anchor") }
      return found
  }

  let rename = AlertPlan(style: .alert, actions: [("Cancel", .cancel), ("Save", .normal)], textFieldCount: 1)
  var share = AlertPlan(style: .actionSheet, actions: [("Copy", .normal), ("Cancel", .cancel)])
  print(problems(in: rename))
  print(problems(in: share))
  share.hasAnchor = true
  share.actions.append(("Close", .cancel))
  print(problems(in: share))
output: |
  []
  ["no anchor"]
  ["two cancels"]
hints:
  - "Text fields are only a problem in an action sheet."
  - "share is a var; the last line sees both changes."
solution: |
  ```output
  []
  ["no anchor"]
  ["two cancels"]
  ```

  The rename alert has a text field, which is fine in an alert. The share sheet has no anchor, which would stop the app on iPad. After setting the anchor and adding a second `.cancel` action, the only problem left is the second cancel, which UIKit doesn't accept either.
````

````exercise
id: m24-l02-e2
type: comprehension
prompt: "An iPhone app's Share button shows an action sheet. It works on every iPhone, but the app stops with an exception on iPad as soon as the button is tapped. What's missing?"
choices:
  - text: "The action sheet's popoverPresentationController has no anchor: set sourceItem, or sourceView and sourceRect."
    correct: true
    why: "In a regular-width environment the sheet becomes a popover, which needs to know where to point."
  - text: "Action sheets aren't supported on iPad; use .alert there."
    correct: false
    why: "They are supported, as popovers."
  - text: "The cancel action must be added first on iPad."
    correct: false
    why: "Action order doesn't cause exceptions."
  - text: "The sheet must be presented with animated: false on iPad."
    correct: false
    why: "Animation has nothing to do with the anchor."
solution: |
  **The popover anchor.** On iPad (regular width), an action sheet is presented as a popover, and a popover with no `sourceItem` or `sourceView` has nowhere to point. Set `sheet.popoverPresentationController?.sourceView = shareButton` and `sourceRect = shareButton.bounds`, or `sourceItem = shareButton`. On iPhone the sheet isn't a popover and the anchor goes unused, so the same line is harmless there.
````

````exercise
id: m24-l02-e3
type: find-errors
prompt: "This \"new tag\" alert never gets released, and on some runs Save is enabled for an empty name. Mark every real problem."
code: |
  func showNewTagAlert() {
      let alert = UIAlertController(title: "New Tag", message: nil, preferredStyle: .alert)
      alert.addTextField { field in
          field.placeholder = "Tag name"
      }
      let save = UIAlertAction(title: "OK", style: .default) { _ in
          let name = alert.textFields?.first?.text ?? ""
          self.addTag(name)
      }
      alert.preferredAction = save
      alert.addAction(save)
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
      present(alert, animated: true)
  }
choices:
  - text: "The Save handler captures alert strongly, so the alert owns itself through its action."
    correct: true
  - text: "preferredAction is set before the action is added, which Apple calls a programmer error."
    correct: true
  - text: "Nothing disables Save while the text field is empty."
    correct: true
  - text: "\"OK\" doesn't say what the action does; \"Add\" or \"Create\" would."
    correct: true
  - text: "Alerts can't have text fields; this needs an action sheet."
    correct: false
    why: "It's the reverse: only alerts can have text fields."
  - text: "The Cancel action needs a handler that dismisses the alert."
    correct: false
    why: "Every action dismisses the alert when tapped; a nil handler is fine."
rubric:
  - I found the strong capture of alert.
  - I found the preferredAction ordering.
  - I found the missing validation.
  - I flagged the vague "OK" title.
solution: |
  Four problems, and the fix for each:

  1. **`alert` captured strongly** in its own action: capture `[weak alert]`. (`self` should be weak too.)
  2. **`preferredAction` before `addAction`**: swap the two lines.
  3. **No validation**: start with `save.isEnabled = false` and enable it from the field's `.editingChanged` action.
  4. **"OK"**: call it "Create".

  ```swift ios
  import UIKit

  final class TagsViewController: UIViewController {
      func showNewTagAlert() {
          let alert = UIAlertController(title: "New Tag", message: nil, preferredStyle: .alert)
          alert.addTextField { field in
              field.placeholder = "Tag name"
          }
          let create = UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
              let name = alert?.textFields?.first?.text ?? ""
              self?.addTag(name)
          }
          create.isEnabled = false
          alert.textFields?.first?.addAction(UIAction { [weak create] action in
              let text = (action.sender as? UITextField)?.text ?? ""
              create?.isEnabled = !text.trimmingCharacters(in: .whitespaces).isEmpty
          }, for: .editingChanged)

          alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
          alert.addAction(create)
          alert.preferredAction = create
          present(alert, animated: true)
      }

      private func addTag(_ name: String) {
          print("tag: \(name)")
      }
  }
  ```
````

````exercise
id: m24-l02-e4
type: solve
prompt: |
  Write the plain-Swift part of a "Leave group" confirmation. `leaveConfirmation(groupName:memberCount:isOwner:)` returns a tuple `(title: String, message: String, destructiveTitle: String)`:

  - The title is always `Leave "<groupName>"?`.
  - If the user is the owner and there are other members, the message is `Ownership passes to the longest-standing member.` and the button is `Leave and Transfer`.
  - If the user is the owner and the only member, the message is `The group will be deleted.` and the button is `Leave and Delete`.
  - Otherwise the message is `You can rejoin with a new invite.` and the button is `Leave`.

  ```swift
  let cases = [(3, true), (1, true), (5, false)]
  for (members, owner) in cases {
      let text = leaveConfirmation(groupName: "Climbing", memberCount: members, isOwner: owner)
      print(text.title, "|", text.message, "|", text.destructiveTitle)
  }
  ```

  should print:

  ```plaintext
  Leave "Climbing"? | Ownership passes to the longest-standing member. | Leave and Transfer
  Leave "Climbing"? | The group will be deleted. | Leave and Delete
  Leave "Climbing"? | You can rejoin with a new invite. | Leave
  ```
starter: |
  func leaveConfirmation(groupName: String, memberCount: Int, isOwner: Bool) -> (title: String, message: String, destructiveTitle: String) {
      // your code
      ("", "", "")
  }
hints:
  - "Write a quote inside a string literal as \\\"."
  - "Check the owner case first, then split it by memberCount."
rubric:
  - The function has no UIKit dependency and returns all three strings.
  - The three cases are distinguished correctly, including the single-member owner.
  - The destructive button names what will happen.
  - The output matches.
solution: |
  ```swift
  func leaveConfirmation(groupName: String, memberCount: Int, isOwner: Bool) -> (title: String, message: String, destructiveTitle: String) {
      let title = "Leave \"\(groupName)\"?"
      if isOwner {
          if memberCount > 1 {
              return (title, "Ownership passes to the longest-standing member.", "Leave and Transfer")
          }
          return (title, "The group will be deleted.", "Leave and Delete")
      }
      return (title, "You can rejoin with a new invite.", "Leave")
  }

  let cases = [(3, true), (1, true), (5, false)]
  for (members, owner) in cases {
      let text = leaveConfirmation(groupName: "Climbing", memberCount: members, isOwner: owner)
      print(text.title, "|", text.message, "|", text.destructiveTitle)
  }
  ```

  ```output
  Leave "Climbing"? | Ownership passes to the longest-standing member. | Leave and Transfer
  Leave "Climbing"? | The group will be deleted. | Leave and Delete
  Leave "Climbing"? | You can rejoin with a new invite. | Leave
  ```

  The view controller then only assembles the alert: a `.cancel` action and a `.destructive` action titled with `destructiveTitle`. Each consequence gets its own button title, so the user knows what happens before tapping, and each case can be tested in a terminal.
````

````exercise
id: m24-l02-e5
type: explain
prompt: "A teammate wrote this to show a tip the first time a screen opens, and says it \"sometimes doesn't show\". Explain both reasons it can fail and where the code should go."
code: |
  override func viewDidLoad() {
      super.viewDidLoad()
      if !UserDefaults.standard.bool(forKey: "seenTip") {
          let alert = UIAlertController(title: "Tip", message: "Swipe left to archive.", preferredStyle: .alert)
          alert.addAction(UIAlertAction(title: "Got It", style: .default))
          present(alert, animated: true)
          UserDefaults.standard.set(true, forKey: "seenTip")
      }
  }
rubric:
  - Explains that in viewDidLoad() the view isn't in a window, so the presentation fails.
  - Points out that the flag is saved even when the alert never appeared, so the tip is lost forever.
  - Moves the code to viewDidAppear(_:) and guards against presenting twice.
  - Optionally questions whether an alert is the right way to show a tip.
solution: |
  1. **`viewDidLoad()` is too early.** The view exists but isn't in a window, so `present` has nothing to present over. UIKit logs a warning and shows nothing.
  2. **The flag is saved anyway.** `seenTip` becomes `true` right after the failed presentation, so the user never sees the tip, not even next time.

  Move it to `viewDidAppear(_:)`, check `presentedViewController == nil`, and set the flag in the action's handler (or after `present`'s completion) so it's only stored once the tip was actually shown. And reconsider the alert: a tip that blocks the screen on first launch is often better as an inline hint near the list. `UserDefaults` itself comes in Module 31.
````

````exercise
id: m24-l02-e6
type: design
prompt: |
  For each situation, say whether you'd use an alert, an action sheet, or neither, and list the actions with their styles.

  1. The user taps "Sign Out" in settings.
  2. Saving a document failed because the disk is full.
  3. The user long-presses a message and should see Reply, Copy and Delete.
  4. A form field contains an invalid email address.
  5. The user taps a "Sort" button in a toolbar, with four sort orders to choose from.
rubric:
  - Sign out is a confirmation (alert or action sheet) with a destructive action and a cancel.
  - The disk-full error is an alert with a clear action.
  - The long-press uses a context menu rather than an action sheet.
  - The invalid email is shown inline, not with an alert.
  - The sort choice is an action sheet anchored to the toolbar item, or a menu.
solution: |
  1. **Action sheet** anchored to the Sign Out row (or an alert): "Sign Out" `.destructive`, "Cancel" `.cancel`. Either is common; the sheet keeps the confirmation near the button.
  2. **Alert**: title "Couldn't save the document", message saying the disk is full, actions "OK" `.cancel` and maybe "Manage Storage" `.default`. It's a problem the user has to know about now.
  3. **Neither**: a context menu (Module 27) is the standard long-press interaction. An action sheet would work but feels dated there.
  4. **Neither**: show the error next to the field. An alert for each typo interrupts typing.
  5. **Action sheet** with the four orders as `.default` actions and a `.cancel`, with `sourceItem` set to the toolbar item; or a button `menu`, which avoids the extra presentation.
````

## Summary

- `UIAlertController(title:message:preferredStyle:)` + `addAction(_:)` + `present(_:animated:)`. Tapping any action dismisses the alert and runs that action's handler.
- Styles: `.default`, one `.cancel`, and `.destructive` for actions that change or delete data. Name buttons with verbs. Set `preferredAction` after adding it.
- Text fields are for alerts only. Read them in the handler through `[weak alert]`, and drive the action's `isEnabled` from the field's `.editingChanged` event.
- Action sheets become popovers in regular width: always set `sourceItem`, or `sourceView` with `sourceRect` in that view's coordinates.
- Present from a visible view controller that isn't already presenting: in response to the user or from `viewDidAppear(_:)`, never `viewDidLoad()`.
