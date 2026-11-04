---
id: m25-l02
title: Tab bar controllers
description: How to split an app into top-level sections with UITabBarController. You give each tab its own navigation controller, configure tab bar items and badges, select tabs from code, intercept a tab tap with the delegate, and use the UITab API from iOS 18 behind an availability check while keeping the iOS 17 viewControllers version working.
module: m25
order: 2
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l01]
objectives:
  - Build a tab bar controller whose tabs each contain their own navigation controller.
  - Configure tab bar items with titles, images and badges, on the controller the tab bar actually reads.
  - Select a tab from code and decide in the delegate whether a tapped tab may be selected.
  - Use UITab and UISearchTab on iOS 18 and later, and viewControllers with UITabBarItem on iOS 17.
  - Explain why a tab bar controller goes at the root and never inside a navigation controller.
terms:
  - term: UITabBarController
    definition: "A container view controller that shows a tab bar and, above it, the content of the selected tab. Each tab has its own root view controller, and the content of the other tabs is kept while you switch."
  - term: UITabBarItem
    definition: "The title, image, selected image and badge that represent a view controller in the tab bar. Each view controller has one in its tabBarItem property."
  - term: UITab
    definition: "iOS 18 and later: an object describing one tab (title, image, unique identifier, badge) with a closure that returns the tab's view controller. Assigned to the tab bar controller's tabs property."
  - term: Badge
    definition: "The small label on a tab, set with badgeValue (a String?). nil removes it."
  - term: More navigation controller
    definition: "With the viewControllers API on iPhone, if there are more tabs than fit, the tab bar shows four plus a More tab that lists the rest. Apple: six or more custom view controllers trigger it."
mastery:
  - Write a function that builds a three-tab interface, each tab a navigation controller with an item and an image.
  - Show a badge with the unread count and remove it when the count is zero.
  - Switch to another tab from code with selectedIndex or selectedTab.
  - Implement tabBarController(_:shouldSelect:) to present a sign-in screen instead of opening a tab.
  - Branch on #available(iOS 18.0, *) to build tabs with UITab while supporting iOS 17.
resources: [uikit-uiviewcontroller, hig, apple-documentation]
cards:
  - id: m25-l02-c1
    front: Tab bar controller inside a navigation controller, or navigation controllers inside a tab bar controller?
    back: "Navigation controllers inside the tabs. Each tab gets its own stack, and the tab bar stays visible. Apple says a navigation controller's root and pushed controllers can't be a tab bar controller."
  - id: m25-l02-c2
    front: Which object's tabBarItem does the tab bar show?
    back: "The tab's root view controller: the object in viewControllers. When a tab is a navigation controller, configure the navigation controller's tabBarItem (or the tab's UITab on iOS 18)."
  - id: m25-l02-c3
    front: How do you build tabs on iOS 18+ while supporting iOS 17?
    back: "if #available(iOS 18.0, *) { tabBarController.tabs = [UITab(title:image:identifier:) { _ in ... }] } else { tabBarController.viewControllers = [...] with UITabBarItems }."
  - id: m25-l02-c4
    front: How do you stop a tab from being selected when tapped?
    back: "Return false from the delegate's tabBarController(_:shouldSelect:) (tabBarController(_:shouldSelectTab:) with UITab). It's called in response to the user tapping a tab, so you can present something else instead."
  - id: m25-l02-c5
    front: How do you show and clear an unread count on a tab?
    back: "Set badgeValue on the tab's UITabBarItem (or UITab) to a string such as \"3\"; set it to nil to remove the badge."
---

## The idea in one sentence

A tab bar controller holds a few independent sections of your app side by side, each with its own navigation stack, and the tab bar lets people jump between them without losing their place in any of them.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target unless the fence says 18.0, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `UITabBarController`, `UITabBarItem`, `UITab`, `UISearchTab` and `UITabBarControllerDelegate`, and the article "Elevating your iPad app with a tab bar and sidebar", read in November 2026. Nothing was checked in Xcode or the simulator. The plain-Swift models were compiled and run.

## Tabs and stacks

Navigation controllers go **deeper**; tabs go **sideways**. Apple's example is the Clock app, "each tab of which presents a type of time based information": separate places, each with its own content. In most apps each tab also has its own drill-down, which gives the classic structure:

```text
UIWindow
└── UITabBarController
    ├── UINavigationController → Inbox → Message → Attachment
    ├── UINavigationController → Search
    └── UINavigationController → Settings → Notifications
```

The tab bar controller is the window's root. Each tab's root view controller is a navigation controller, and pushes happen inside that tab. Apple: "If the root view controller is a navigation controller, the tab bar controller makes further adjustments to the size of the displayed navigation content so that it doesn't overlap the tab bar."

The other way around doesn't work. A navigation controller's root "cannot be an instance of the `UITabBarController` class", and a pushed controller "cannot be a tab bar controller".

When people switch tabs, the other tabs keep their stacks. Leave Inbox on a message, check Settings, come back: the message is still there.

## Building tabs for iOS 17

The project's deployment target is iOS 17, so this is the version that always works: one navigation controller per tab, in `viewControllers`, each with a `UITabBarItem`.

```swift ios
import UIKit

final class InboxViewController: UIViewController {
    init(unreadCount: Int) {
        super.init(nibName: nil, bundle: nil)
        title = "Inbox"
    }

    required init?(coder: NSCoder) {
        fatalError("InboxViewController is created in code")
    }
}

final class SearchViewController: UIViewController {}
final class SettingsViewController: UIViewController {}

@MainActor
func makeTabBarController(unreadCount: Int) -> UITabBarController {
    let inbox = UINavigationController(rootViewController: InboxViewController(unreadCount: unreadCount))
    inbox.tabBarItem = UITabBarItem(
        title: "Inbox",
        image: UIImage(systemName: "tray"),
        selectedImage: UIImage(systemName: "tray.fill")
    )
    inbox.tabBarItem.badgeValue = unreadCount > 0 ? String(unreadCount) : nil

    let search = UINavigationController(rootViewController: SearchViewController())
    search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)

    let settings = UINavigationController(rootViewController: SettingsViewController())
    settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)

    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [inbox, search, settings]
    tabBarController.selectedIndex = 0
    return tabBarController
}
```

Line by line:

- **The item goes on the navigation controller.** The tab bar reads `tabBarItem` from each object in `viewControllers`, and those objects are the navigation controllers. Apple: "If you don't provide a custom tab bar item for your view controller, the view controller creates a default item containing no image and the text from the view controller's title property."
- `UITabBarItem(title:image:selectedImage:)` (iOS 7). "If you don't provide selectedImage, the item uses image for both selection states." Use SF Symbols' outline variant for `image` and the filled one for `selectedImage`.
- `UITabBarItem(tabBarSystemItem:tag:)` gives the standard Search item. Apple: "You can't change the title and image properties of an item this method creates."
- `badgeValue` is a `String?`. `nil` removes the badge, so a zero count shows nothing.
- `viewControllers` sets the order, left to right. `selectedIndex` picks the starting tab; it's 0 by default anyway, written here to show where you'd change it.
- The function is `@MainActor`: it creates UIKit objects, which are all main-actor isolated.

In the scene delegate, `window.rootViewController = makeTabBarController(unreadCount: 3)` replaces the single navigation controller from lesson 1.

> [!warning] Configure the item before the tab is shown
> Tabs you haven't opened yet don't load their views. A `tabBarItem` set in a tab's `viewDidLoad()` therefore doesn't appear until the user opens that tab once. Apple's advice, on `tabBarItem`: create the items "in your view controller's initialization code", or, as above, where you build the tab bar.

### More tabs than fit

On iPhone, Apple's rule for `viewControllers`: "If you add six or more custom view controllers to a tab bar controller, the tab bar controller displays only the first four items plus the standard More item." The rest are listed on a More screen managed by `moreNavigationController`, which isn't in `viewControllers`. So on iPhone, five tabs is the practical limit, and each one should be a real top-level section.

## Building tabs with UITab (iOS 18 and later)

iOS 18 added a second API built around `UITab` objects. You describe each tab and return its view controller from a closure. The same tabs can appear as a tab bar or, on iPad, as a sidebar:

```swift ios
import UIKit

final class InboxViewController: UIViewController {}
final class SearchViewController: UIViewController {}
final class SettingsViewController: UIViewController {}

@MainActor
func makeTabBarController(unreadCount: Int) -> UITabBarController {
    let tabBarController = UITabBarController()

    if #available(iOS 18.0, *) {
        let inbox = UITab(title: "Inbox", image: UIImage(systemName: "tray"), identifier: "inbox") { _ in
            UINavigationController(rootViewController: InboxViewController())
        }
        inbox.badgeValue = unreadCount > 0 ? String(unreadCount) : nil

        let settings = UITab(title: "Settings", image: UIImage(systemName: "gear"), identifier: "settings") { _ in
            UINavigationController(rootViewController: SettingsViewController())
        }

        let search = UISearchTab { _ in
            UINavigationController(rootViewController: SearchViewController())
        }

        tabBarController.tabs = [inbox, settings, search]
    } else {
        let inbox = UINavigationController(rootViewController: InboxViewController())
        inbox.tabBarItem = UITabBarItem(title: "Inbox", image: UIImage(systemName: "tray"), tag: 0)
        inbox.tabBarItem.badgeValue = unreadCount > 0 ? String(unreadCount) : nil

        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)

        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 2)

        tabBarController.viewControllers = [inbox, settings, search]
    }
    return tabBarController
}
```

What's new in the `if` branch:

- `UITab(title:image:identifier:viewControllerProvider:)`. "In the closure, return the view controller your app presents when someone selects the tab." The identifier "must be unique across all the tabs managed by a `UITabBarController`." The reference doesn't say exactly when the closure runs, so don't do work in it that must happen at launch.
- Title, image and badge live on the tab. Apple: "you can change a tab's properties, such as title or image, at runtime, and the system automatically updates its appearance." The article also says to pick the outline variant of an SF Symbol; the system chooses outline or filled.
- `UISearchTab` (iOS 18) is "a tab subclass that represents the system's search tab", with a system-localized title and image. Apple says it "automatically separates the search tab from other tabs when the tab bar is compact."
- `if #available(iOS 18.0, *)` is required: the deployment target is iOS 17, and `UITab` doesn't exist there. The `else` branch is the previous section's code.

Pick one API per tab bar controller and don't mix `tabs` with `viewControllers` assignments. The reference pages document them as two ways to configure the same controller, not as something to combine.

On iPad, the iOS 18 tab bar floats at the top and shares space with the navigation bar. Adding `UITabGroup`s to `tabs`, or setting `mode` to `.tabSidebar`, lets the system show the same tabs as a sidebar. That's beyond this lesson; the article in the note above walks through it.

## Selecting tabs from code

A "View Inbox" button on another tab, or a deep link (lesson 6), needs to switch tabs:

```swift ios
import UIKit

@MainActor
func showInbox(in tabBarController: UITabBarController) {
    if #available(iOS 18.0, *), let inbox = tabBarController.tab(forIdentifier: "inbox") {
        tabBarController.selectedTab = inbox
    } else {
        tabBarController.selectedIndex = 0
    }
}
```

- With `viewControllers`, use `selectedIndex` or `selectedViewController`. The view controller "must be in the `viewControllers` array".
- With `tabs`, `tab(forIdentifier:)` finds a tab by its identifier (or returns `nil`) and `selectedTab` selects it. Identifiers don't change when you reorder tabs; indexes do.
- A view controller inside a tab reaches the tab bar controller through its own `tabBarController` property, "the nearest ancestor in the view controller hierarchy that is a tab bar controller", or `nil`.

### Tapping the selected tab

Tapping the tab that's already selected pops that tab's navigation controller back to its root. People use it to get back to the top quickly. Apple's overview says taps always display the tab's root view "even if the tab was already selected"; the pop itself is long-standing UIKit behavior rather than something the reference page spells out.

### Tabs, modeled

Each tab keeps its own stack, switching tabs doesn't touch them, and tapping the selected tab resets it:

```swift
enum Tab {
    case inbox, search, settings
}

struct TabBarState {
    private(set) var selected = Tab.inbox
    private var stacks: [Tab: [String]] = [
        .inbox: ["Inbox"],
        .search: ["Search"],
        .settings: ["Settings"],
    ]

    var visibleScreen: String {
        let stack = stacks[selected] ?? []
        return stack[stack.count - 1]
    }

    mutating func push(_ screen: String) {
        stacks[selected, default: []].append(screen)
    }

    mutating func tap(_ tab: Tab) {
        if tab == selected {
            let root = stacks[tab, default: []][0]
            stacks[tab] = [root]
        } else {
            selected = tab
        }
    }
}

var tabs = TabBarState()
tabs.push("Message 12")
tabs.push("Attachment")
tabs.tap(.settings)
tabs.push("Notifications")
print(tabs.visibleScreen)
tabs.tap(.inbox)
print(tabs.visibleScreen)
tabs.tap(.inbox)
print(tabs.visibleScreen)
tabs.tap(.settings)
print(tabs.visibleScreen)
```

```output
Notifications
Attachment
Inbox
Notifications
```

Coming back to Inbox shows the attachment where the user left it. Tapping Inbox again pops to the root. Settings kept its own stack the whole time.

## The delegate

`UITabBarControllerDelegate` lets you veto a tab tap. A common case: an Account tab that requires sign-in. Instead of opening it, present the sign-in screen:

```swift ios
import UIKit

final class SignInViewController: UIViewController {}
final class AccountViewController: UIViewController {}
final class HomeViewController: UIViewController {}

final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let home = UINavigationController(rootViewController: HomeViewController())
    private let account = UINavigationController(rootViewController: AccountViewController())
    var isSignedIn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        account.tabBarItem = UITabBarItem(title: "Account", image: UIImage(systemName: "person.crop.circle"), tag: 1)
        viewControllers = [home, account]
        delegate = self
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        guard viewController === account, !isSignedIn else { return true }
        let signIn = UINavigationController(rootViewController: SignInViewController())
        present(signIn, animated: true)
        return false
    }
}
```

- Apple: "The tab bar controller calls this method in response to the user tapping a tab bar item." Return `true` to select it, `false` to stay where you are. It's about user taps; don't count on it to guard a selection your own code makes with `selectedIndex`.
- `===` compares identity: is this the account navigation controller instance?
- `delegate` is `weak`, so a tab bar controller can be its own delegate without a cycle. A separate object works too, as long as something else keeps it alive.
- `present(_:animated:)` shows the sign-in screen modally. Lesson 3 covers presentation.
- With the iOS 18 `tabs` API, the delegate has tab-based versions: `tabBarController(_:shouldSelectTab:)` and `tabBarController(_:didSelectTab:previousTab:)`.

## Hiding the tab bar

Apple, on `tabBar`: "You should never attempt to manipulate the UITabBar object itself stored in this property. If you attempt to do so, the tab bar view throws an exception." Configure tabs through view controllers or `UITab`s. On iOS 18 and later, `isTabBarHidden` and `setTabBarHidden(_:animated:)` hide it, for example on a full-screen media screen; both need `#available` with an iOS 17 target.

## Common mistakes

> [!error] Wrapping the tab bar controller in a navigation controller
> One stack for the whole app, a navigation bar over the tab bar, and pushed screens that cover the tabs. Apple says a navigation controller's root can't be a tab bar controller. Put a navigation controller in each tab instead.

> [!error] Setting tabBarItem on the inner controller in viewDidLoad()
> Two problems at once: the tab bar reads the item of the tab's root (the navigation controller), and a tab that hasn't been opened hasn't loaded its view. The tab shows an empty item until the first visit. Set the item on the navigation controller when you build the tabs.

> [!error] Using UITab without an availability check
> With an iOS 17 deployment target, `UITab`, `UISearchTab`, `tabs` and `selectedTab` need `if #available(iOS 18.0, *)`. The compiler reports it as an error, so this one is caught before it ships.

> [!error] Selecting tabs by hard-coded index after a reorder
> `selectedIndex = 2` silently opens the wrong tab once someone adds a tab. Keep the index in one place (an enum), or use `tab(forIdentifier:)` with stable identifiers on iOS 18.

> [!error] Changing the tab bar view directly
> Apple says the tab bar view throws an exception if you manipulate it. Set items through view controllers or tabs.

## Exercises

````exercise
id: m25-l02-e1
type: prediction
prompt: "Using the lesson's tab model, what does this print?"
code: |
  enum Tab {
      case home, library
  }

  struct TabBarState {
      private(set) var selected = Tab.home
      private var stacks: [Tab: [String]] = [.home: ["Home"], .library: ["Library"]]

      var visibleScreen: String {
          let stack = stacks[selected] ?? []
          return stack[stack.count - 1]
      }

      mutating func push(_ screen: String) {
          stacks[selected, default: []].append(screen)
      }

      mutating func tap(_ tab: Tab) {
          if tab == selected {
              let root = stacks[tab, default: []][0]
              stacks[tab] = [root]
          } else {
              selected = tab
          }
      }
  }

  var tabs = TabBarState()
  tabs.tap(.library)
  tabs.push("Album")
  tabs.push("Song")
  tabs.tap(.home)
  tabs.push("Recent")
  print(tabs.visibleScreen)
  tabs.tap(.library)
  print(tabs.visibleScreen)
  tabs.tap(.library)
  tabs.tap(.home)
  tabs.tap(.library)
  print(tabs.visibleScreen)
output: |
  Recent
  Song
  Library
hints:
  - "Each tab has its own array; pushes go to the selected one."
  - "The second tap on library happens while library is selected."
solution: |
  ```output
  Recent
  Song
  Library
  ```

  Album and Song go onto the Library stack, Recent onto Home. Switching back to Library shows Song: stacks survive tab switches. Tapping Library while it's selected resets it to its root, and switching to Home and back doesn't change that.
````

````exercise
id: m25-l02-e2
type: comprehension
prompt: "Each tab of an app is a navigation controller. The code sets `tabBarItem` on the root list controllers inside them, in their `viewDidLoad()`. At launch the tab bar shows items with no images and no titles. What's the best fix?"
choices:
  - text: "Set each navigation controller's tabBarItem where the tab bar controller is built."
    correct: true
    why: "The tab bar reads the item of the objects in viewControllers, and the items exist before any tab is opened."
  - text: "Call loadViewIfNeeded() on every tab at launch so viewDidLoad() runs."
    correct: false
    why: "It forces every tab to build its screen at launch, and the item would still be on the inner controller."
  - text: "Set tabBarController?.tabBar.items directly in viewDidLoad()."
    correct: false
    why: "Apple says manipulating the tab bar view throws an exception."
  - text: "Move the code to viewDidAppear(_:)."
    correct: false
    why: "That's even later; it still waits for the user to open each tab."
solution: |
  **Configure the items where you build the tabs**, on the navigation controllers. Unopened tabs don't load their views, so code in `viewDidLoad()` runs late; and the tab's root view controller, the one the tab bar asks for its item, is the navigation controller. On iOS 18 with `UITab`, the title, image and badge are on the tab itself, so the question doesn't come up.
````

````exercise
id: m25-l02-e3
type: fill-in
prompt: "Complete the iOS 18 branch of a tab setup that still supports iOS 17."
code: |
  if [[1]](iOS 18.0, *) {
      let library = UITab(title: "Library", image: UIImage(systemName: "books.vertical"), [[2]]: "library") { _ in
          UINavigationController(rootViewController: LibraryViewController())
      }
      library.[[3]] = "2"
      tabBarController.[[4]] = [library]
  } else {
      let library = UINavigationController(rootViewController: LibraryViewController())
      library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 0)
      tabBarController.[[5]] = [library]
  }
blanks:
  - id: "1"
    answers: ["#available"]
  - id: "2"
    answers: ["identifier"]
  - id: "3"
    answers: ["badgeValue"]
  - id: "4"
    answers: ["tabs"]
  - id: "5"
    answers: ["viewControllers"]
solution: |
  ```swift ios
  import UIKit

  final class LibraryViewController: UIViewController {}

  @MainActor
  func configure(_ tabBarController: UITabBarController) {
      if #available(iOS 18.0, *) {
          let library = UITab(title: "Library", image: UIImage(systemName: "books.vertical"), identifier: "library") { _ in
              UINavigationController(rootViewController: LibraryViewController())
          }
          library.badgeValue = "2"
          tabBarController.tabs = [library]
      } else {
          let library = UINavigationController(rootViewController: LibraryViewController())
          library.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "books.vertical"), tag: 0)
          tabBarController.viewControllers = [library]
      }
  }
  ```

  `#available` checks the OS at run time and lets the compiler accept iOS 18 symbols inside the branch. The identifier must be unique among the controller's tabs, and you'll use it with `tab(forIdentifier:)`.
````

````exercise
id: m25-l02-e4
type: solve
prompt: |
  Write `badgeValue(unread:)`, the plain-Swift rule behind an Inbox badge. It returns `nil` (no badge) for zero or a negative count, the number as text up to 99, and `"99+"` above that.

  ```swift
  for count in [0, 1, 42, 99, 100, 2_500, -3] {
      print(count, badgeValue(unread: count) ?? "no badge")
  }
  ```

  should print:

  ```plaintext
  0 no badge
  1 1
  42 42
  99 99
  100 99+
  2500 99+
  -3 no badge
  ```
starter: |
  func badgeValue(unread: Int) -> String? {
      // your code
      nil
  }
hints:
  - "badgeValue is a String?, and nil means no badge at all."
  - "String(42) turns an Int into \"42\"."
rubric:
  - Zero and negative counts return nil, not "0".
  - Counts above 99 return "99+".
  - No UIKit dependency, so the rule runs in a terminal.
  - The output matches.
solution: |
  ```swift
  func badgeValue(unread: Int) -> String? {
      if unread <= 0 {
          return nil
      }
      if unread > 99 {
          return "99+"
      }
      return String(unread)
  }

  for count in [0, 1, 42, 99, 100, 2_500, -3] {
      print(count, badgeValue(unread: count) ?? "no badge")
  }
  ```

  ```output
  0 no badge
  1 1
  42 42
  99 99
  100 99+
  2500 99+
  -3 no badge
  ```

  The tab code becomes one line: `inbox.tabBarItem.badgeValue = badgeValue(unread: count)` (or `tab.badgeValue` with `UITab`). Returning `nil` for zero matters: a badge reading "0" still draws attention to nothing. Negative counts shouldn't happen, but a bug elsewhere shouldn't put "-3" on screen either.
````

````exercise
id: m25-l02-e5
type: find-errors
prompt: "This app's structure is wrong in several ways. Mark every real problem."
code: |
  @MainActor
  func makeRoot() -> UIViewController {
      let tabs = UITabBarController()
      let feed = FeedViewController()
      let profile = ProfileViewController()
      tabs.viewControllers = [feed, profile]
      tabs.tabBar.items?.first?.title = "Feed"
      return UINavigationController(rootViewController: tabs)
  }
choices:
  - text: "The tab bar controller is the root of a navigation controller, which Apple doesn't allow."
    correct: true
  - text: "The tabs aren't navigation controllers, so screens pushed from Feed have no stack of their own."
    correct: true
  - text: "It changes the tab bar's items directly instead of configuring tabBarItem on the view controllers."
    correct: true
  - text: "viewControllers can't be set before the tab bar controller is on screen."
    correct: false
    why: "Configuring it before it's shown is the normal way."
  - text: "A UITabBarController needs at least three tabs."
    correct: false
    why: "There's no minimum of three."
rubric:
  - I found the tab bar controller inside the navigation controller.
  - I noticed the tabs have no navigation controllers.
  - I found the direct change to the tab bar.
solution: |
  ```swift ios
  import UIKit

  final class FeedViewController: UIViewController {}
  final class ProfileViewController: UIViewController {}

  @MainActor
  func makeRoot() -> UIViewController {
      let feed = UINavigationController(rootViewController: FeedViewController())
      feed.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "list.bullet"), tag: 0)

      let profile = UINavigationController(rootViewController: ProfileViewController())
      profile.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 1)

      let tabs = UITabBarController()
      tabs.viewControllers = [feed, profile]
      return tabs
  }
  ```

  The tab bar controller is the root; each tab is a navigation controller with its own item; nothing touches `tabBar` itself.
````

````exercise
id: m25-l02-e6
type: design
prompt: |
  A recipe app has these screens: a feed of new recipes, a recipe detail, search, saved recipes, a shopping list, user settings, a sign-in screen and a "new recipe" editor. Design the top level: which tabs, what's pushed inside which tab, what's presented modally, and how you'd handle sign-in for Saved. Name the UIKit pieces.
rubric:
  - Picks a small number of real top-level sections as tabs.
  - Each tab is a navigation controller; detail screens are pushed inside the tab they're opened from.
  - The editor and sign-in are presented modally, not tabs.
  - Uses the tab bar controller delegate (or a check on the tab's root screen) for the sign-in requirement.
  - Mentions the iOS 17/18 API split.
solution: |
  - **Tabs** (each a `UINavigationController`): Feed, Search, Saved, Shopping List. Settings can be a fifth tab or a button in the Feed's navigation bar; it's visited rarely, so the bar button is a fair choice.
  - **Pushed**: recipe detail, from Feed, Search or Saved, inside whichever tab the user is in. The same detail class, a new instance each time.
  - **Modal**: the new-recipe editor (a task with Cancel and Save, lesson 3) and the sign-in screen.
  - **Sign-in for Saved**: in `tabBarController(_:shouldSelect:)` (or `shouldSelectTab` with `UITab`), if the user isn't signed in, present sign-in and return `false`. After a successful sign-in, select the Saved tab from code.
  - **API**: `tabs` with `UITab` and `UISearchTab` behind `#available(iOS 18.0, *)`, `viewControllers` with `UITabBarItem`s otherwise.
````

## Summary

- A `UITabBarController` at the window's root holds top-level sections. Each tab's root is a `UINavigationController`, so every tab keeps its own stack. Never put a tab bar controller inside a navigation controller.
- iOS 17 API: `viewControllers` plus a `UITabBarItem` on each tab's root (the navigation controller), with `badgeValue`, and `selectedIndex` to switch.
- iOS 18 API: `tabs` with `UITab(title:image:identifier:viewControllerProvider:)` and `UISearchTab`, `selectedTab` and `tab(forIdentifier:)`. Behind `#available(iOS 18.0, *)` with an iOS 17 target.
- Configure items when you build the tabs, not in a tab's `viewDidLoad()`.
- `tabBarController(_:shouldSelect:)` can refuse a tap and present something else instead.
- Don't manipulate `tabBar` directly; on iOS 18, hide it with `setTabBarHidden(_:animated:)`.
