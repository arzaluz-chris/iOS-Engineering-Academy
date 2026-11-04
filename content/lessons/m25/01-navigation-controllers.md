---
id: m25-l01
title: Navigation controllers, push and pop
description: How drill-down navigation works in UIKit. You put a UINavigationController at the root of a window, push and pop view controllers on its stack, jump back to the root or to any screen, configure titles, bar button items and large titles through each controller's navigation item, and control what the back button says.
module: m25
order: 1
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l06]
objectives:
  - Make a UINavigationController the root of a scene's window and push a detail screen onto it.
  - Pop one screen, pop to the root, pop to a specific screen and replace the whole stack.
  - Configure a screen's title and bar button items through its navigationItem, in the initializer.
  - Turn on large titles for the bar and choose the title size per screen.
  - Control the back button's title from the screen underneath, and explain why it's set there.
terms:
  - term: UINavigationController
    definition: "A container view controller that \"defines a stack-based scheme for navigating hierarchical content\". It shows one child at a time, the top of its stack, and draws a navigation bar with a back button."
  - term: Navigation stack
    definition: "The ordered viewControllers array of a navigation controller. Index 0 is the root view controller (the bottom of the stack); the last element is the top, the screen on display."
  - term: Push and pop
    definition: "Push adds a view controller on top of the stack and animates it in. Pop removes the top one and reveals the one underneath. The root can't be popped."
  - term: UINavigationItem
    definition: "The object each view controller exposes as navigationItem: its title, bar button items, large-title mode and back button settings. The navigation bar reads it when that controller is on top, or is the one just below the top."
  - term: Large title
    definition: "A bigger title shown below the bar's buttons. The bar must allow it (navigationBar.prefersLargeTitles) and each screen chooses with navigationItem.largeTitleDisplayMode."
mastery:
  - Write a scene delegate that installs a navigation controller with a root screen and large titles.
  - Push a detail controller created with the data it needs, and pop back with code.
  - Return to the root after finishing a multi-step flow, and replace a stack in one call.
  - Add bar button items with UIAction handlers that capture self weakly.
  - Set the back button title on the right controller, and choose between backButtonTitle and backButtonDisplayMode.
resources: [uikit-uiviewcontroller, uikit-uiwindowscene, hig, apple-documentation]
cards:
  - id: m25-l01-c1
    front: Which navigation controller method replaces the whole stack, and when do you use it?
    back: "setViewControllers(_:animated:) (or assigning viewControllers, which is the same with animated false). Use it to restore a stack or jump to a deep screen in one transition; the last element becomes the top."
  - id: m25-l01-c2
    front: What does popViewController(animated:) do when only the root is on the stack?
    back: "Nothing, and it returns nil. Apple: you cannot pop the last item on the stack."
  - id: m25-l01-c3
    front: The back button on the Note screen should read "Notes". Which controller do you configure?
    back: "The Notes list underneath: its navigationItem.backButtonTitle (or backBarButtonItem). The back button is built from the navigation item of the controller you go back to."
  - id: m25-l01-c4
    front: Why configure the title and bar button items in the initializer rather than viewDidLoad()?
    back: "Apple: a controller's navigation item may be retrieved independently of its view. When you push or set several controllers at once, the lower ones' views aren't loaded, but the bar still reads their items for the back button."
  - id: m25-l01-c5
    front: What happens if you push a view controller that's already on the stack?
    back: "pushViewController(_:animated:) throws an exception (Apple: if the view controller is already on the navigation stack, this method throws an exception). Create a new instance or pop to the existing one."
---

## The idea in one sentence

A navigation controller keeps an array of view controllers, shows the last one, and gives you a back button and a swipe for free; you move forward by pushing a new controller onto that array and back by popping it off.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `UINavigationController`, `UINavigationItem`, `UINavigationBar` and `UIBarButtonItem`, read in November 2026; where a behavior isn't on those pages, the text says so. Nothing here was checked in Xcode or the simulator. The plain-Swift model of the stack was compiled and run.

## The stack

Open Settings on an iPhone: a list of groups, tap one, a list of settings, tap one, a detail screen. Each level is a view controller, and the navigation controller holds them in order:

| Index | View controller | Role |
| --- | --- | --- |
| 0 | Settings | Root: the bottom of the stack, never popped |
| 1 | General | The **back** controller, at index n − 2 |
| 2 | About | The **top**, at index n − 1: the one on screen |

Apple's description: "The ordered array of view controllers it manages forms the navigation stack. When you push a view controller onto the stack, it animates onscreen and covers the view controller that was previously on top." For every screen except the root, the bar shows a back button, and people "can also remove the topmost view controller by tapping the Back button or performing a swipe gesture. When long-pressed, the Back button presents a hierarchical list of all view controllers people can return to."

Two consequences you'll rely on all module:

- **The navigation controller owns the controllers on its stack.** When a screen is popped, nothing else keeps it alive unless you do, so it's released. You don't write any cleanup.
- **The back button and the swipe pop without asking your code.** If you need to know a screen went away, you have to listen for it. Lesson 5 shows how.

## Installing one

A navigation controller is a view controller, so it goes wherever a view controller can: most often at the root of the window, in the scene delegate from Module 22:

```swift ios
import UIKit

final class FoldersViewController: UIViewController {
    private let folders: [String]

    init(folders: [String]) {
        self.folders = folders
        super.init(nibName: nil, bundle: nil)
        title = "Folders"
    }

    required init?(coder: NSCoder) {
        fatalError("FoldersViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let folders = FoldersViewController(folders: ["Personal", "Work"])
        let navigationController = UINavigationController(rootViewController: folders)
        navigationController.navigationBar.prefersLargeTitles = true

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

- `UINavigationController(rootViewController:)` is "a convenience method for initializing the receiver and pushing a root view controller onto the navigation stack. Every navigation stack must have at least one view controller to act as the root."
- `title = "Folders"` in the initializer. Apple, on `title`: "If the view controller has a valid navigation item or tab-bar item, assigning a value to this property updates the title text of those objects." The bar shows it. Why the initializer and not `viewDidLoad()` is explained below, under bar button items.
- `prefersLargeTitles` belongs to the **bar**, which the navigation controller owns. Setting it once here allows large titles for every screen in this stack.
- The window's root is the navigation controller, not the folders screen. The folders screen is the navigation controller's child.

## Pushing

A list screen creates the detail screen with the data it needs and pushes it:

```swift ios
import UIKit

struct Note {
    let id: Int
    var title: String
    var body: String
}

final class NoteListViewController: UIViewController {
    private let notes: [Note]

    init(notes: [Note]) {
        self.notes = notes
        super.init(nibName: nil, bundle: nil)
        title = "Notes"
    }

    required init?(coder: NSCoder) {
        fatalError("NoteListViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let openButton = UIButton(configuration: .filled())
        openButton.configuration?.title = "Open First Note"
        openButton.addAction(UIAction { [weak self] _ in
            self?.openFirstNote()
        }, for: .primaryActionTriggered)
        openButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(openButton)
        NSLayoutConstraint.activate([
            openButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            openButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    private func openFirstNote() {
        guard let note = notes.first else { return }
        let detail = NoteDetailViewController(note: note)
        navigationController?.pushViewController(detail, animated: true)
    }
}

final class NoteDetailViewController: UIViewController {
    private let note: Note
    private let bodyLabel = UILabel()

    init(note: Note) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
        title = note.title
        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder: NSCoder) {
        fatalError("NoteDetailViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        bodyLabel.text = note.body
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bodyLabel)
        NSLayoutConstraint.activate([
            bodyLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
}
```

The navigation part is two lines:

1. `NoteDetailViewController(note: note)` creates the next screen and hands it what it shows. Lesson 4 is about this handoff; for now, the detail gets its data in `init` and can't exist without it.
2. `navigationController?.pushViewController(detail, animated: true)` adds it to the stack. `navigationController` is "the nearest ancestor in the view controller hierarchy that is a navigation controller", and it's `nil` if the screen isn't inside one. That's why it's optional, and why a push from a screen that isn't in a navigation controller does nothing at all, silently.

`largeTitleDisplayMode = .never` keeps the detail's title small. The default is `.automatic`, which "causes the title to use the same styling as the previously displayed navigation item": a list with a large title would hand a large title to its detail. The other values are `.always` and, since iOS 17, `.inline`. And if the bar's `prefersLargeTitles` is `false`, Apple says this property "has no effect".

### show(_:sender:)

`show(_:sender:)` is the push you write when the screen shouldn't care what contains it. A navigation controller handles it by pushing "in a similar way as the `pushViewController(_:animated:)` method"; a split view controller handles it its own way. If no ancestor handles it, Apple says it falls back to presenting modally from the window's root. `pushViewController` is more explicit, and it's what this module uses; you'll meet `show` in storyboard segues, which call it.

## Popping

The back button and the edge swipe cover the common case. When your code has to go back (after Save, after a flow finishes), the navigation controller has four ways:

| Call | Effect |
| --- | --- |
| `popViewController(animated:)` | Removes the top controller. "If the view controller at the top of the stack is the root view controller, this method does nothing." Returns the popped controller, or `nil` |
| `popToRootViewController(animated:)` | Removes everything above the root. Returns the popped controllers |
| `popToViewController(_:animated:)` | Removes everything above the given controller, which "must currently be on the navigation stack" |
| `setViewControllers(_:animated:)` | Replaces the whole array. "The last item added to the array becomes the top item" |

A checkout that ends on a confirmation screen goes back to the start:

```swift ios
import UIKit

final class ConfirmationViewController: UIViewController {
    private let orderNumber: String

    init(orderNumber: String) {
        self.orderNumber = orderNumber
        super.init(nibName: nil, bundle: nil)
        title = "Order Placed"
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("ConfirmationViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}
```

`hidesBackButton` hides the back button "when this navigation item is the top item": going back to the payment screen after paying makes no sense. Done goes to the root. The cart, address and payment screens are released on the way, because the stack was the only thing holding them.

`setViewControllers(_:animated:)` deserves a closer look. Apple: "If the view controller is currently in the stack, but is not the topmost item, this method uses a pop transition; if it is the topmost item, no transition is performed. If the view controller is not on the stack, this method uses a push transition. Only one transition is performed." So building three screens in one call animates once, as a single push, and the back button on the top screen already points at the second one. Lesson 6 uses that to open a deep link. Assigning `viewControllers` directly does the same thing with `animated: false`.

> [!warning] Each controller can be on the stack once
> Apple, on `pushViewController(_:animated:)`: "If the view controller is already on the navigation stack, this method throws an exception." Create a new instance for a new screen, or pop to the existing one. Apple also says the pushed controller "cannot be a tab bar controller". Pushing a navigation controller into another navigation controller isn't supported either (UIKit raises an exception; the reference page only names tab bar controllers).

## The stack, modeled

The rules fit in a small struct. Each string stands for one view controller instance:

```swift
struct NavigationStack {
    private(set) var screens: [String]

    init(root: String) {
        screens = [root]
    }

    var top: String {
        screens[screens.count - 1]
    }

    var backButtonTitle: String? {
        screens.count > 1 ? screens[screens.count - 2] : nil
    }

    mutating func push(_ screen: String) {
        if screens.contains(screen) {
            print("exception: \(screen) is already on the stack")
            return
        }
        screens.append(screen)
    }

    mutating func pop() -> String? {
        if screens.count == 1 {
            return nil
        }
        return screens.removeLast()
    }

    mutating func popToRoot() -> [String] {
        let popped = Array(screens.dropFirst())
        screens = [screens[0]]
        return popped
    }
}

var stack = NavigationStack(root: "Folders")
stack.push("Notes")
stack.push("Note 42")
print(stack.screens, "| back:", stack.backButtonTitle ?? "none")
stack.push("Notes")
print(stack.pop() ?? "nothing")
print(stack.top, "| back:", stack.backButtonTitle ?? "none")
stack.push("Note 7")
stack.push("Attachments")
print(stack.popToRoot())
print(stack.pop() ?? "nothing", stack.screens)
```

```output
["Folders", "Notes", "Note 42"] | back: Notes
exception: Notes is already on the stack
Note 42
Notes | back: Folders
["Notes", "Note 7", "Attachments"]
nothing ["Folders"]
```

- `backButtonTitle` is the screen **below** the top. That's where the real back button gets its title too, as the next section shows.
- Pushing "Notes" a second time is the exception from the warning above. The model prints instead of crashing.
- `pop()` on a root-only stack returns `nil`, like `popViewController(animated:)`.

## The navigation item

Each view controller has a `navigationItem`. The bar doesn't belong to your screen; it belongs to the navigation controller, and it redraws itself from the navigation item of whichever controller is on top. So you never touch the bar to add a button. You configure your own item:

```swift ios
import UIKit

final class NoteDetailViewController: UIViewController {
    private var isPinned = false

    init(noteTitle: String) {
        super.init(nibName: nil, bundle: nil)
        title = noteTitle

        let share = UIBarButtonItem(systemItem: .action, primaryAction: UIAction { [weak self] _ in
            self?.share()
        })
        let pinAction = UIAction(title: "Pin", image: UIImage(systemName: "pin")) { [weak self] _ in
            self?.togglePin()
        }
        navigationItem.rightBarButtonItems = [share, UIBarButtonItem(primaryAction: pinAction)]
    }

    required init?(coder: NSCoder) {
        fatalError("NoteDetailViewController is created in code")
    }

    private func share() {
        print("share")
    }

    private func togglePin() {
        isPinned.toggle()
        print(isPinned ? "pinned" : "unpinned")
    }
}
```

- `UIBarButtonItem(systemItem:primaryAction:menu:)` (iOS 14) builds a standard item, here `.action`, the share icon. Others include `.add`, `.done`, `.cancel`, `.close`, `.edit` and `.save`.
- `UIBarButtonItem(primaryAction:)` takes its title and image from the action. Apple: "If you specify primaryAction, it takes precedence over title and image."
- `rightBarButtonItems` holds several items. Apple: "the first item in the array is the rightmost item and other items are added to the left of the previous item." `rightBarButtonItem` is the first element of that array. In a right-to-left language the sides flip on their own, and items that don't fit aren't displayed.
- `[weak self]` in every handler, for the reason from Module 22: the controller owns the item, the item owns the action, the action owns the closure.

Why in `init`? Apple, on `navigationItem`: "Avoid tying the creation of bar button items in your navigation item to the creation of your view controller's view. The navigation item of a view controller may be retrieved independently of the view controller's view. For example, when pushing two view controllers onto a navigation stack, the topmost view controller becomes visible, but the other view controller's navigation item may be retrieved in order to present its back button." A title set in `viewDidLoad()` works when screens are pushed one at a time, because each view loads before the next push. It breaks when you build a stack in one call (lesson 6). Configuring in `init` works both ways.

Since iOS 16, a navigation item also has `leadingItemGroups` and `trailingItemGroups` (and `centerItemGroups` for editor-style bars), which replace the left and right item arrays when you set them. Plain `rightBarButtonItems` is enough for most screens.

## The back button

The back button on screen B is built from the navigation item of screen A, the one you'd go back **to**. Apple's order:

1. If B sets leading items of its own, they're shown instead (and with `leftItemsSupplementBackButton`, next to the back button).
2. Otherwise, if A's `backBarButtonItem` is set, the bar shows it.
3. Otherwise the system builds a back button from A, using A's `backButtonTitle`, or its `title`, according to A's `backButtonDisplayMode`.

So to make the back button on a note read "Notes" while the list's own title is "Notes (12)", configure the list:

```swift ios
import UIKit

final class NoteListViewController: UIViewController {
    init(noteCount: Int) {
        super.init(nibName: nil, bundle: nil)
        title = "Notes (\(noteCount))"
        navigationItem.backButtonTitle = "Notes"
    }

    required init?(coder: NSCoder) {
        fatalError("NoteListViewController is created in code")
    }
}

final class AccountViewController: UIViewController {
    init(accountName: String) {
        super.init(nibName: nil, bundle: nil)
        title = accountName
        navigationItem.backButtonDisplayMode = .minimal
    }

    required init?(coder: NSCoder) {
        fatalError("AccountViewController is created in code")
    }
}
```

- `backButtonTitle` (iOS 11): "When `backButtonTitle` is nil, which is the default value, the navigation item uses its title property as the Back button title." `backBarButtonItem` "takes precedence if you specify both".
- `backButtonDisplayMode` (iOS 14): `.default`, `.generic` (tries a generic title such as "Back", then no title, depending on space) or `.minimal` (only the back indicator image). Screens pushed from the account screen get a back button with no text.
- When the title doesn't fit, Apple says the bar shows only the back image. You don't need to shorten titles by hand for that.

Don't replace the back button with a custom leading item just to change its text. The three properties above change the text and keep the system's back button.

## Showing and hiding the bar

The bar belongs to the navigation controller. Apple: "you must never change its frame, bounds, or alpha values or modify its view hierarchy directly. To show or hide the navigation bar, you should always do so through the navigation controller by changing its `isNavigationBarHidden` property or calling the `setNavigationBarHidden(_:animated:)` method." The same goes for the optional toolbar: it's hidden by default, `setToolbarHidden(_:animated:)` shows it, and it shows the top controller's `toolbarItems`.

The current SDK adds a note about the iOS 26 design: "To prevent interfering with Liquid Glass in your navigation bar, avoid using custom backgrounds and `UIAppearance` APIs." Leave the bar's look to the system unless a design really needs otherwise.

## Common mistakes

> [!error] Pushing from a screen that isn't in a navigation controller
> `navigationController` is `nil`, so `navigationController?.pushViewController(...)` does nothing and there's no error. Check that the window's root (or the tab, lesson 2) is a `UINavigationController` with this screen inside it.

> [!error] Pushing the same instance twice
> Keeping a detail controller in a property and pushing it each time works once. The second push, while it's still on the stack, throws an exception. Create a new controller per push.

> [!error] Setting the back button text on the screen that shows it
> `navigationItem.backButtonTitle = "Notes"` in the detail screen changes the back button of screens pushed **from** the detail, not the detail's own. Set it on the controller underneath.

> [!error] Configuring the title and items in viewDidLoad()
> It looks fine until a stack is built in one call: the lower screens' views never load, and their back buttons fall back to defaults. Configure the navigation item in `init`.

> [!error] Hiding the bar by changing its alpha or frame
> Use `setNavigationBarHidden(_:animated:)`. The navigation controller lays out its children around the bar, and changing the bar behind its back breaks that.

## Exercises

````exercise
id: m25-l01-e1
type: prediction
prompt: "Using the lesson's stack model, what does this print?"
code: |
  struct NavigationStack {
      private(set) var screens: [String]

      init(root: String) {
          screens = [root]
      }

      var backButtonTitle: String? {
          screens.count > 1 ? screens[screens.count - 2] : nil
      }

      mutating func push(_ screen: String) {
          if screens.contains(screen) {
              print("exception: \(screen)")
              return
          }
          screens.append(screen)
      }

      mutating func pop() -> String? {
          if screens.count == 1 {
              return nil
          }
          return screens.removeLast()
      }
  }

  var stack = NavigationStack(root: "Settings")
  stack.push("General")
  stack.push("About")
  stack.push("General")
  print(stack.backButtonTitle ?? "none")
  _ = stack.pop()
  _ = stack.pop()
  print(stack.pop() ?? "nothing", stack.backButtonTitle ?? "none")
  stack.push("Privacy")
  print(stack.screens)
output: |
  exception: General
  General
  nothing none
  ["Settings", "Privacy"]
hints:
  - "The second push of General happens while General is still on the stack."
  - "After two pops only the root is left, and the root can't be popped."
solution: |
  ```output
  exception: General
  General
  nothing none
  ["Settings", "Privacy"]
  ```

  The stack becomes Settings, General, About. Pushing General again is refused, like the real exception. The back button on About comes from the screen below it: General. Two pops remove About and General; the third pop finds only the root, returns `nil`, and with one screen there's no back button. Privacy then goes on top of Settings.
````

````exercise
id: m25-l01-e2
type: comprehension
prompt: "A Projects list (title \"Projects (8)\") pushes a Project screen. You want the back button on the Project screen to read \"Projects\". Where do you write `navigationItem.backButtonTitle = \"Projects\"`?"
choices:
  - text: "In the Projects list controller, ideally in its initializer."
    correct: true
    why: "The back button is built from the navigation item of the controller you go back to."
  - text: "In the Project controller's viewDidLoad()."
    correct: false
    why: "That sets the back button for screens pushed from the Project screen."
  - text: "On the navigation controller's navigationBar."
    correct: false
    why: "The bar reads navigation items; you don't set titles on it."
  - text: "Nowhere: the back button always shows the previous title, and it can't be changed."
    correct: false
    why: "backButtonTitle, backBarButtonItem and backButtonDisplayMode all change it."
solution: |
  **In the Projects list.** When the Project screen is on top, the bar builds its back button from the navigation item just below it, the list's. Setting `backButtonTitle` there overrides the default (the list's `title`, "Projects (8)"). Doing it in the list's `init` means it's ready even if the list's view never loaded, for example when a deep link builds both screens at once.
````

````exercise
id: m25-l01-e3
type: fill-in
prompt: "Complete the navigation calls."
code: |
  // In the scene delegate: allow large titles for the whole stack.
  navigationController.navigationBar.[[1]] = true

  // In a list screen: show the detail.
  navigationController?.[[2]](detail, animated: true)

  // After Save on the detail: go back one screen.
  navigationController?.[[3]](animated: true)

  // At the end of a checkout: go back to the first screen.
  navigationController?.[[4]](animated: true)
blanks:
  - id: "1"
    answers: ["prefersLargeTitles"]
  - id: "2"
    answers: ["pushViewController"]
  - id: "3"
    answers: ["popViewController"]
  - id: "4"
    answers: ["popToRootViewController"]
solution: |
  ```swift ios
  import UIKit

  @MainActor
  func demo(navigationController: UINavigationController, detail: UIViewController) {
      navigationController.navigationBar.prefersLargeTitles = true
      navigationController.pushViewController(detail, animated: true)
      navigationController.popViewController(animated: true)
      navigationController.popToRootViewController(animated: true)
  }
  ```

  `prefersLargeTitles` is a property of the bar, and each screen then chooses with `largeTitleDisplayMode`. The two pop methods return the popped controllers; you can ignore the result. The function is `@MainActor` because it touches UIKit objects.
````

````exercise
id: m25-l01-e4
type: find-errors
prompt: "This library screen misbehaves: the first tap opens the book, the second one crashes, and the toolbar sometimes vanishes. Mark every real problem."
code: |
  final class LibraryViewController: UIViewController {
      private let bookScreen = BookViewController()

      func openBook() {
          navigationController?.pushViewController(bookScreen, animated: true)
      }

      func openBookInItsOwnStack() {
          let stack = UINavigationController(rootViewController: BookViewController())
          navigationController?.pushViewController(stack, animated: true)
      }

      func enterReadingMode() {
          navigationController?.navigationBar.alpha = 0
      }
  }
choices:
  - text: "openBook() pushes the same instance every time; if it's still on the stack, pushing it again throws an exception."
    correct: true
  - text: "openBookInItsOwnStack() pushes a navigation controller into a navigation controller, which UIKit doesn't support."
    correct: true
  - text: "enterReadingMode() changes the bar's alpha; Apple says to use setNavigationBarHidden(_:animated:) instead."
    correct: true
  - text: "navigationController?. is wrong; pushViewController must be called on self."
    correct: false
    why: "pushViewController is a method of UINavigationController; navigationController? is the right receiver."
  - text: "pushViewController needs a completion handler to avoid a crash."
    correct: false
    why: "It has no completion parameter, and none is needed."
rubric:
  - I found the reused instance.
  - I found the nested navigation controller.
  - I found the direct change to the bar.
solution: |
  1. **Reused instance.** Create the book screen inside `openBook()`: `let book = BookViewController()`. Each push gets its own controller, and popped ones are released.
  2. **Nested navigation controller.** Push `BookViewController()` itself. If the book really needs a separate stack, present that navigation controller modally (lesson 3) instead of pushing it.
  3. **Bar alpha.** `navigationController?.setNavigationBarHidden(true, animated: true)`. The navigation controller then lays out the content correctly.
````

````exercise
id: m25-l01-e5
type: solve
prompt: |
  Add `popTo(_:)` to this stack model, the plain-Swift version of `popToViewController(_:animated:)`. It removes every screen above the given one and returns the removed screens in stack order. If the screen isn't on the stack, it changes nothing and returns `nil`.

  ```swift
  var stack = NavigationStack(root: "Shop")
  stack.push("Cart")
  stack.push("Address")
  stack.push("Payment")
  print(stack.popTo("Cart") ?? "not on the stack")
  print(stack.screens)
  print(stack.popTo("Payment") ?? "not on the stack")
  print(stack.popTo("Cart") ?? "not on the stack")
  ```

  should print:

  ```plaintext
  ["Address", "Payment"]
  ["Shop", "Cart"]
  not on the stack
  []
  ```
starter: |
  struct NavigationStack {
      private(set) var screens: [String]

      init(root: String) {
          screens = [root]
      }

      mutating func push(_ screen: String) {
          screens.append(screen)
      }

      mutating func popTo(_ screen: String) -> [String]? {
          // your code
          nil
      }
  }
hints:
  - "firstIndex(of:) gives you the position, or nil."
  - "Everything after that index is popped: screens[(index + 1)...]."
rubric:
  - Returns nil and leaves the stack alone when the screen isn't on it.
  - Removes and returns exactly the screens above the target, in order.
  - Popping to the current top returns an empty array.
  - The output matches.
solution: |
  ```swift
  struct NavigationStack {
      private(set) var screens: [String]

      init(root: String) {
          screens = [root]
      }

      mutating func push(_ screen: String) {
          screens.append(screen)
      }

      mutating func popTo(_ screen: String) -> [String]? {
          guard let index = screens.firstIndex(of: screen) else {
              return nil
          }
          let popped = Array(screens[(index + 1)...])
          screens.removeSubrange((index + 1)...)
          return popped
      }
  }

  var stack = NavigationStack(root: "Shop")
  stack.push("Cart")
  stack.push("Address")
  stack.push("Payment")
  print(stack.popTo("Cart") ?? "not on the stack")
  print(stack.screens)
  print(stack.popTo("Payment") ?? "not on the stack")
  print(stack.popTo("Cart") ?? "not on the stack")
  ```

  ```output
  ["Address", "Payment"]
  ["Shop", "Cart"]
  not on the stack
  []
  ```

  `Array(...)` turns the slice into an array before the removal. Popping to Cart when Cart is already on top removes nothing and returns `[]`, which is different from `nil`: the screen was found. UIKit's version is stricter: the controller "must currently be on the navigation stack", so check before you call it.
````

````exercise
id: m25-l01-e6
type: explain
prompt: "A teammate builds a three-screen stack in one call. Every screen sets its `title` in `viewDidLoad()`. The detail appears with the right title, but its back button doesn't show the list's title. Explain why, and the fix."
code: |
  final class NoteListViewController: UIViewController {
      override func viewDidLoad() {
          super.viewDidLoad()
          title = "Work Notes"
      }
  }

  // Opening a link to note 42:
  navigationController.setViewControllers([folders, list, detail], animated: true)
rubric:
  - Explains that only the top controller's view is loaded by the transition.
  - Connects the back button to the list's navigation item, read without loading its view.
  - Moves the title (and other navigation item setup) into the initializer.
solution: |
  `setViewControllers(_:animated:)` performs one transition, to the top controller. Only the detail's view is loaded and shown, so only the detail's `viewDidLoad()` runs. The back button, though, is built from the **list's** navigation item, and Apple notes that a navigation item "may be retrieved independently of the view controller's view... in order to present its back button." The list's `title` is still `nil` because its `viewDidLoad()` hasn't run, so the bar falls back to a generic back button.

  Set `title` (and `backButtonTitle`, bar button items) in each controller's `init`. Then the items exist as soon as the controller does, however it gets onto the stack.
````

## Summary

- A `UINavigationController` holds a stack of view controllers: root at index 0, top at the end. It owns them; popped controllers are released.
- Forward: `pushViewController(_:animated:)` (or `show(_:sender:)`). Back: `popViewController`, `popToRootViewController`, `popToViewController`, or replace everything with `setViewControllers(_:animated:)`, which animates once.
- Never push an instance that's already on the stack, a tab bar controller, or another navigation controller.
- Each screen configures its own `navigationItem` (title, bar button items, `largeTitleDisplayMode`), in `init`, because the bar may read it before the view loads.
- The back button comes from the screen underneath: set `backButtonTitle`, `backBarButtonItem` or `backButtonDisplayMode` there.
- Show and hide the bar through the navigation controller, never by changing the bar's frame or alpha.
