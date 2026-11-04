---
id: m22-l02
title: View controllers and their life cycle
description: A view controller owns one screen's views and loads them lazily. You learn when UIKit calls loadView, viewDidLoad, viewWillAppear, viewIsAppearing, viewDidAppear, viewWillDisappear and viewDidDisappear, what work belongs in each, why geometry isn't ready until viewIsAppearing, and how these callbacks differ from the scene life cycle.
module: m22
order: 2
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l01]
objectives:
  - Explain that a view controller loads its view lazily, the first time the view property is read.
  - List the appearance sequence UIKit documents, from viewWillAppear(_:) to viewDidAppear(_:), including viewIsAppearing(_:) and the layout callbacks.
  - Put one-time setup, per-appearance updates, geometry-dependent work and teardown in the right callback.
  - Override loadView() correctly to supply a custom root view.
  - Tell view controller appearance apart from the scene going to the background.
terms:
  - term: View controller
    definition: "A UIViewController subclass that owns one root view and its subviews, fills them with data and responds to the user's interactions with them."
  - term: Lazy view loading
    definition: "A view controller doesn't create its view in init. The first read of its view property calls loadView() and then viewDidLoad()."
  - term: loadView()
    definition: "Creates the controller's root view and assigns it to view. Override it only to supply a custom root view in code, and don't call super when you do."
  - term: viewIsAppearing(_:)
    definition: "Called once per appearance, after the view is in the hierarchy with up-to-date traits and geometry, and before it's visible. Apple's recommended place to update views for display."
  - term: Balanced callbacks
    definition: "Pairs such as viewWillAppear(_:) / viewDidDisappear(_:) used to start and stop something, so every start has exactly one matching stop."
mastery:
  - Predict which life-cycle methods run, and how many times, when a controller is shown, hidden and shown again.
  - Move a piece of code from the wrong callback to the right one and justify it with Apple's documented order.
  - Write a loadView() override that installs a custom UIView subclass as the root view.
  - Explain why reading view in an initializer is a bug.
  - Say which callbacks fire when the user goes to the Home Screen, and which don't.
resources: [uikit-uiviewcontroller, uikit-viewisappearing, swift-book-inheritance, swift-book-initialization]
cards:
  - id: m22-l02-c1
    front: When does a view controller create its view?
    back: "Lazily: the first time something reads its view property. UIKit then calls loadView() and, once the view exists, viewDidLoad(). isViewLoaded checks without loading."
  - id: m22-l02-c2
    front: Appearance order according to Apple?
    back: "viewWillAppear(_:) → view added to the hierarchy → traits and geometry updated → viewIsAppearing(_:) → viewWillLayoutSubviews() → layout → viewDidLayoutSubviews() → on screen → viewDidAppear(_:) after animations."
  - id: m22-l02-c3
    front: viewWillAppear(_:) or viewIsAppearing(_:) for updating views with the current size and traits?
    back: "viewIsAppearing(_:). In viewWillAppear(_:) traits and geometry aren't up to date yet. Both run in the same CATransaction, so changes in either become visible together. The docs list viewIsAppearing(_:) as available from iOS 13."
  - id: m22-l02-c4
    front: Rules for overriding loadView()?
    back: "Create the root view, assign it to view, don't call super, don't use it if the controller comes from a storyboard or nib. Do further setup in viewDidLoad()."
  - id: m22-l02-c5
    front: Does going to the Home Screen call viewWillDisappear(_:)?
    back: "No. The view isn't removed from its hierarchy; the scene goes to the background. Use scene callbacks (or their notifications) for that."
---

## The idea in one sentence

A view controller creates its views only when someone first asks for them, then UIKit tells it, in a fixed and documented order, each time those views are about to appear, have appeared, are about to disappear and have disappeared; the skill is knowing which of those moments each piece of work belongs to.

> [!note] About this lesson's code
> Blocks that import UIKit are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run. The call orders come from Apple's UIKit documentation ("Displaying and managing views with a view controller" and the reference page for each method), read in November 2026, and are reproduced by plain-Swift models that were compiled and run.

## What a view controller is

`UIViewController` is "an object that manages a view hierarchy for your UIKit app". Its root view is in the `view` property, and every screen you build is a subclass. Apple lists its responsibilities: updating views when data changes, responding to user interactions, resizing and laying out views, and coordinating with other objects, including other view controllers.

Two facts drive everything else:

1. **The view is created lazily.** "View controllers load their views lazily. Accessing the view property for the first time loads or creates the view controller's views." Creating `InboxViewController()` creates a controller with no view.
2. **The controller owns its views.** "A view controller is the sole owner of its view and any subviews it creates." You can't share one view between two controllers.

## Loading: loadView() and viewDidLoad()

When something reads `view` and it's `nil`, UIKit calls `loadView()`. The default implementation loads the views from the controller's nib or storyboard if it has one, and otherwise "creates a plain UIView object". Then UIKit calls `viewDidLoad()`.

For a controller that comes from a storyboard, Apple lists the steps:

1. Creates each view with `init(coder:)`.
2. Connects views to the controller's outlets and actions.
3. Calls `awakeFromNib()` on each view and on the controller.
4. Assigns the view hierarchy to `view`.
5. Calls `viewDidLoad()`.

So outlets are connected before `viewDidLoad()` runs. Lesson 6 relies on that.

**What belongs in `viewDidLoad()`:** one-time configuration. Apple: "perform only the one-time configuration steps you need to prepare the view controller for use. Use load time to create and configure any additional views that aren't part of your storyboard. Don't perform tasks that need to happen each time your view controller appears onscreen. For example, don't start animations or update the values of views."

### Overriding loadView()

Override `loadView()` when you want the root view to be your own `UIView` subclass. The rules, all from its reference page: never call it yourself; assign the root view to `view`; "Your custom implementation of this method should not call super"; and don't override it if the controller's views come from Interface Builder.

```swift ios
import UIKit

final class CounterView: UIView {
    let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        countLabel.font = .preferredFont(forTextStyle: .largeTitle)
        addSubview(countLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("CounterView is built in code")
    }
}

final class CounterViewController: UIViewController {
    private let counterView = CounterView()

    override func loadView() {
        view = counterView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        counterView.countLabel.text = "0"
    }
}
```

- `CounterView` is a `UIView` subclass that builds its own subviews in `init(frame:)`. Adding a designated initializer means Swift requires `init?(coder:)` too (it's `required` in `UIView`); a view built only in code traps there with a message. Lesson 4 comes back to that pair.
- `loadView()` assigns the custom view and doesn't call `super`, which would build a second, unused view.
- `viewDidLoad()` still runs afterwards, and **does** call `super`.

## Appearing: from viewWillAppear(_:) to viewDidAppear(_:)

Each time the view is about to go on screen (the first time and every time after), Apple's documentation lists what UIKit does:

1. Calls `viewWillAppear(_:)` at the start of the transition.
2. Adds the view to the hierarchy.
3. Updates the trait collections of the view controller and its view.
4. Updates the geometry of the view: size, position, layout margins and safe area.
5. Calls `viewIsAppearing(_:)`.
6. Calls `viewWillLayoutSubviews()`.
7. Updates the layout of the view hierarchy.
8. Calls `viewDidLayoutSubviews()`.
9. Displays the views on screen.
10. Calls `viewDidAppear(_:)` after any animations complete.

The `animated` parameter says whether the transition is animated.

### viewIsAppearing(_:) is where you update views

Steps 3 and 4 are the reason `viewIsAppearing(_:)` exists. Its reference page: "The traits and geometry aren't up to date when the system calls viewWillAppear(_:), but they are when the system calls viewIsAppearing(_:), so use viewIsAppearing(_:) to update your views." It's called "only once during the appearance transition", unlike the layout methods, so work done there doesn't repeat.

Apple keeps two uses for `viewWillAppear(_:)`: when you need a callback before the transition begins (for example, to add animations alongside it through `transitionCoordinator`), and for "balanced callbacks" that don't depend on traits, hierarchy or geometry, such as "registering for database notifications in viewWillAppear(_:) and unregistering in viewDidDisappear(_:)". Both run inside the same Core Animation transaction, so "changes you make in either method become visible to the user at the same time."

> [!version] viewIsAppearing(_:) and the deployment target
> Older tutorials don't use it, but Apple's documentation lists `viewIsAppearing(_:)` as available from iOS 13.0. The course's iOS 17 target can call and override it without an availability check.

### Layout callbacks run many times

`viewWillLayoutSubviews()` and `viewDidLayoutSubviews()` run "whenever the view performs layout, which can happen at any time while the view is visible": rotation, a size change in split view, the keyboard, a Dynamic Type change. Put only layout-related work there, and make it cheap and safe to repeat. Module 23 covers layout properly.

### viewDidAppear(_:)

The view is on screen and the transition is over. Start things the user should see begin: an animation, a timer that drives the UI, analytics for "screen viewed". It also has a quirk: "If a view controller is presented by a view controller inside of a popover, this method is not invoked on the presenting view controller after the presented controller is dismissed."

## Disappearing

`viewWillDisappear(_:)` is called "before the view is actually removed". Apple suggests it to "commit editing changes, resign the first responder status of the view", or undo something you changed when the view appeared. `viewDidDisappear(_:)` comes after the view has been removed: stop work that only matters while visible, unregister observers you registered on appearance.

The overview of `UIViewController` adds a rule for pairs: "if you start a process in a will callback method, you end the process in both the corresponding did and the opposite will callback method." An appearance can be interrupted (the user starts a swipe-back gesture and cancels it), so a "will" isn't always followed by its "did".

## One controller with every callback

```swift ios
import UIKit

final class ClockTicker {
    private(set) var isRunning = false
    func start() { isRunning = true }
    func stop() { isRunning = false }
}

final class ProfileViewController: UIViewController {
    private let nameLabel = UILabel()
    private let ticker = ClockTicker()
    var userName = "Christian"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Once: build and configure views.
        view.backgroundColor = .systemBackground
        nameLabel.font = .preferredFont(forTextStyle: .title1)
        nameLabel.adjustsFontForContentSizeCategory = true
        view.addSubview(nameLabel)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        // Every appearance, with correct traits and geometry: fill in data.
        nameLabel.text = userName
        nameLabel.sizeToFit()
        nameLabel.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // On screen: start what the user should see start.
        ticker.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Leaving: commit edits, dismiss the keyboard.
        view.endEditing(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Gone: stop what only matters while visible.
        ticker.stop()
    }
}
```

Every override calls `super`. For the appear and disappear methods Apple says "you must call super at some point in your implementation", and for `viewIsAppearing(_:)` "you need to call super". `viewDidLoad()` has no such sentence, but calling `super` is the safe habit: a superclass of yours may do work there. The only override that must **not** call `super` is a custom `loadView()`.

Positioning the label with `center` and `bounds` is a stopgap so the example has something geometry-dependent; lesson 3 explains those properties and Module 23 replaces them with Auto Layout.

## A model you can run

The order can be modeled in plain Swift. This class imitates lazy loading and the main appearance callbacks:

```swift
class ModelViewController {
    let name: String
    private(set) var isViewLoaded = false

    init(name: String) {
        self.name = name
    }

    var view: String {
        if !isViewLoaded {
            loadView()
            isViewLoaded = true
            viewDidLoad()
        }
        return "\(name)'s root view"
    }

    func loadView() { print("\(name): loadView") }
    func viewDidLoad() { print("\(name): viewDidLoad") }
    func viewWillAppear() { print("\(name): viewWillAppear") }
    func viewIsAppearing() { print("\(name): viewIsAppearing") }
    func viewDidAppear() { print("\(name): viewDidAppear") }
    func viewWillDisappear() { print("\(name): viewWillDisappear") }
    func viewDidDisappear() { print("\(name): viewDidDisappear") }
}

func show(_ controller: ModelViewController) {
    _ = controller.view            // UIKit loads the view first, if needed
    controller.viewWillAppear()
    controller.viewIsAppearing()
    controller.viewDidAppear()
}

func hide(_ controller: ModelViewController) {
    controller.viewWillDisappear()
    controller.viewDidDisappear()
}

let settings = ModelViewController(name: "Settings")
print("created, loaded: \(settings.isViewLoaded)")
show(settings)
hide(settings)
show(settings)
```

```output
created, loaded: false
Settings: loadView
Settings: viewDidLoad
Settings: viewWillAppear
Settings: viewIsAppearing
Settings: viewDidAppear
Settings: viewWillDisappear
Settings: viewDidDisappear
Settings: viewWillAppear
Settings: viewIsAppearing
Settings: viewDidAppear
```

Loading happens once; appearance callbacks happen every time. Apple's article describes loading as the first thing UIKit does when you present a controller ("UIKit needs to first load and configure the corresponding views"), which is why the model reads `view` before `viewWillAppear()`. The view can also load earlier than that, whenever any code reads `view`, so don't make `viewDidLoad()` depend on being called right before the screen appears.

## View controller callbacks are not the scene life cycle

Going to the Home Screen doesn't remove your view from its hierarchy. The window stays, the root view controller stays, and only the scene changes state. So `viewWillDisappear(_:)` and `viewDidDisappear(_:)` **aren't called**, and coming back doesn't call `viewWillAppear(_:)`. If a screen must pause when the app leaves the foreground, listen for the scene going inactive or to the background (Module 21, lesson 2) as well as for its own disappearance.

| Event | View controller callbacks | Scene callbacks |
| --- | --- | --- |
| A screen is pushed or presented over this one | `viewWillDisappear`, `viewDidDisappear` | None |
| The covering screen is dismissed | `viewWillAppear` … `viewDidAppear` | None |
| User goes to the Home Screen | None | `sceneWillResignActive`, `sceneDidEnterBackground` |
| User comes back | None | `sceneWillEnterForeground`, `sceneDidBecomeActive` |

## Common mistakes

> [!error] Reading view in init
> `init` runs before the controller is on screen, but `view.backgroundColor = .red` in it forces `loadView()` and `viewDidLoad()` to run immediately, before your initializer finishes and before outlets or injected data are ready. Keep `init` for storing dependencies; touch views from `viewDidLoad()` on.

> [!error] Calling super.loadView() in a custom loadView()
> The default implementation builds a view (from a nib, or a plain `UIView`), which you then throw away by assigning your own. Apple: "should not call super".

> [!error] Using sizes in viewDidLoad() or viewWillAppear(_:)
> `view.bounds` isn't final there; Apple says traits and geometry aren't up to date until `viewIsAppearing(_:)`. Use Auto Layout (Module 23), or do the calculation in `viewIsAppearing(_:)`.

> [!error] Expensive or one-shot work in viewDidLayoutSubviews()
> It can run many times per second during rotation or keyboard changes. A network request or an analytics event there repeats every time.

> [!error] Forgetting super in appearance methods
> Apple requires the call. Skipping it breaks behavior that superclasses (including UIKit's own containers) implement in those methods.

> [!error] Starting in viewWillAppear(_:) and stopping only in viewDidDisappear(_:)
> If the appearance is cancelled midway, you may never get the "did" you expected. Follow Apple's rule: end what you started in a "will" method in both its "did" and the opposite "will".

## Exercises

````exercise
id: m22-l02-e1
type: prediction
prompt: "A model of a screen that's shown, covered by another screen, and shown again. What does it print?"
code: |
  class Screen {
      let name: String
      private var loaded = false
      init(name: String) { self.name = name }

      func loadIfNeeded() {
          if !loaded {
              loaded = true
              print("\(name) didLoad")
          }
      }

      func appear() {
          loadIfNeeded()
          print("\(name) isAppearing")
      }

      func disappear() {
          print("\(name) didDisappear")
      }
  }

  let list = Screen(name: "List")
  let detail = Screen(name: "Detail")
  list.appear()
  list.disappear()
  detail.appear()
  detail.disappear()
  list.appear()
output: |
  List didLoad
  List isAppearing
  List didDisappear
  Detail didLoad
  Detail isAppearing
  Detail didDisappear
  List isAppearing
hints:
  - "Each Screen loads once, the first time it appears."
  - "List was already loaded when it appears the second time."
solution: |
  ```output
  List didLoad
  List isAppearing
  List didDisappear
  Detail didLoad
  Detail isAppearing
  Detail didDisappear
  List isAppearing
  ```

  `List` loads on its first appearance and never again; the second appearance only prints `isAppearing`. That's the real rule too: `viewDidLoad()` is one-time setup, the appearance callbacks run every time the screen comes back. In a real navigation stack the covered screen's view also stays loaded underneath.
````

````exercise
id: m22-l02-e2
type: prediction
prompt: "This model controller sets its background color in init, the way the first mistake in the lesson describes. What does it print?"
code: |
  class ModelViewController {
      let title: String
      private var rootView: String?

      init(title: String) {
          self.title = title
          print("init starts")
          view = "red"
          print("init ends")
      }

      var view: String {
          get {
              if rootView == nil {
                  print("loadView")
                  rootView = "plain"
                  print("viewDidLoad: title is \(title)")
              }
              return rootView ?? ""
          }
          set {
              _ = view
              rootView = newValue
              print("background set to \(newValue)")
          }
      }
  }

  let controller = ModelViewController(title: "Profile")
  print("shown with \(controller.view)")
output: |
  init starts
  loadView
  viewDidLoad: title is Profile
  background set to red
  init ends
  shown with red
hints:
  - "The setter reads view first, the way UIKit has to load a view before you can change it."
  - "Everything in the getter's if runs only while rootView is nil."
solution: |
  ```output
  init starts
  loadView
  viewDidLoad: title is Profile
  background set to red
  init ends
  shown with red
  ```

  Touching `view` inside `init` loads it **during** the initializer: `loadView` and `viewDidLoad` both print before `init ends`. Here `title` was already set, so it worked; in a real controller, anything you assign after that line (injected data, a delegate) isn't there yet when `viewDidLoad()` runs. Store dependencies in `init` and touch views in `viewDidLoad()`.
````

````exercise
id: m22-l02-e3
type: comprehension
prompt: "A settings list must scroll so the selected row is visible every time the screen appears. The scroll offset depends on the view's final size. Which callback does Apple recommend?"
choices:
  - text: "viewIsAppearing(_:)"
    correct: true
    why: "It runs once per appearance, after geometry and traits are updated, before the view is visible. Apple uses this exact example."
  - text: "viewDidLoad()"
    correct: false
    why: "It runs only once, and the view's size isn't final yet."
  - text: "viewWillAppear(_:)"
    correct: false
    why: "Traits and geometry aren't up to date yet when it runs."
  - text: "viewDidLayoutSubviews()"
    correct: false
    why: "It can run many times while the view is visible, so the list would keep jumping back to the selected row."
solution: |
  **`viewIsAppearing(_:)`.** Its documentation gives this case: "because computing a scroll position relies on the view's size and geometry, you might programmatically scroll a collection or table view to ensure a selected cell is visible when the view appears." It runs once per appearance with correct geometry, and changes made there show up in the first visible frame.
````

````exercise
id: m22-l02-e4
type: fill-in
prompt: Complete the order UIKit documents for a view appearing on screen.
code: |
  1. view[[1]]Appear(_:)
  2. the view is added to the hierarchy; traits and geometry are updated
  3. view[[2]]Appearing(_:)
  4. view[[3]]LayoutSubviews()
  5. layout runs
  6. viewDidLayoutSubviews()
  7. the view is displayed
  8. view[[4]]Appear(_:)
blanks:
  - id: "1"
    answers: ["Will"]
  - id: "2"
    answers: ["Is"]
  - id: "3"
    answers: ["Will"]
  - id: "4"
    answers: ["Did"]
solution: |
  ```plaintext
  1. viewWillAppear(_:)
  2. the view is added to the hierarchy; traits and geometry are updated
  3. viewIsAppearing(_:)
  4. viewWillLayoutSubviews()
  5. layout runs
  6. viewDidLayoutSubviews()
  7. the view is displayed
  8. viewDidAppear(_:)
  ```

  `viewWillAppear(_:)` is before the view is even in the hierarchy; `viewIsAppearing(_:)` is the first point with correct traits and size; `viewDidAppear(_:)` comes after any transition animation.
````

````exercise
id: m22-l02-e5
type: find-errors
prompt: "This controller shows a weather forecast. Mark every real problem."
code: |
  final class ForecastViewController: UIViewController {
      private let temperatureLabel = UILabel()
      private let service: ForecastService

      init(service: ForecastService) {
          self.service = service
          super.init(nibName: nil, bundle: nil)
      }

      required init?(coder: NSCoder) { fatalError("code only") }

      override func loadView() {
          super.loadView()
          view = UIView()
      }

      override func viewDidLoad() {
          super.viewDidLoad()
          view.addSubview(temperatureLabel)
          let columns = Int(view.bounds.width / 80)
          temperatureLabel.text = "\(columns) columns"
      }

      override func viewWillAppear(_ animated: Bool) {
          temperatureLabel.text = service.cachedTemperature
      }

      override func viewDidLayoutSubviews() {
          super.viewDidLayoutSubviews()
          service.refresh()
      }
  }
choices:
  - text: "loadView() calls super, which builds a view that's immediately replaced."
    correct: true
  - text: "viewDidLoad() computes from view.bounds, which isn't final yet."
    correct: true
  - text: "viewWillAppear(_:) doesn't call super."
    correct: true
  - text: "viewDidLayoutSubviews() starts a refresh, which can run many times while the screen is visible."
    correct: true
  - text: "The custom init must not call super.init(nibName:bundle:)."
    correct: false
    why: "That's the designated initializer for a code-only controller. Calling it is correct."
  - text: "required init?(coder:) can't use fatalError."
    correct: false
    why: "For a controller that's never loaded from a storyboard this is the common, deliberate choice."
rubric:
  - I found the super call in loadView().
  - I found the geometry read in viewDidLoad().
  - I found the missing super in viewWillAppear(_:).
  - I found the repeated refresh in viewDidLayoutSubviews().
solution: |
  Four problems:

  1. **`super.loadView()`** creates a plain view that's thrown away one line later. Either drop the override (the default already creates a plain `UIView`) or assign your custom view without calling `super`.
  2. **`view.bounds.width` in `viewDidLoad()`** isn't the final width. Do size-dependent work in `viewIsAppearing(_:)`, or better, let Auto Layout handle it.
  3. **`viewWillAppear(_:)` without `super`**. Apple says you must call it. Also, filling in the label belongs in `viewIsAppearing(_:)`.
  4. **`service.refresh()` in `viewDidLayoutSubviews()`** runs on every layout pass. Refresh once per appearance (`viewIsAppearing(_:)` or `viewDidAppear(_:)`) or when the scene returns to the foreground.

  The initializer pair is correct for a controller built in code.
````

````exercise
id: m22-l02-e6
type: solve
prompt: |
  Finish this model of lazy view loading so it behaves like `UIViewController`:

  - `view` creates the view on first read by calling `loadView()` then `viewDidLoad()`, and never again.
  - `isViewLoaded` reports whether the view exists **without** loading it.
  - `loadViewIfNeeded()` loads the view if it isn't loaded, and does nothing otherwise.

  ```swift
  let controller = LazyController()
  print(controller.isViewLoaded)
  controller.loadViewIfNeeded()
  controller.loadViewIfNeeded()
  print(controller.view)
  print(controller.isViewLoaded)
  ```

  should print:

  ```plaintext
  false
  loadView
  viewDidLoad
  root view
  true
  ```
starter: |
  class LazyController {
      private var storedView: String?

      var isViewLoaded: Bool {
          // your code
          return false
      }

      var view: String {
          // your code
          return ""
      }

      func loadViewIfNeeded() {
          // your code
      }

      func loadView() {
          print("loadView")
          storedView = "root view"
      }

      func viewDidLoad() {
          print("viewDidLoad")
      }
  }
hints:
  - "isViewLoaded only checks storedView."
  - "Put the loading in one place, loadViewIfNeeded(), and have the view getter call it."
  - "The getter can return storedView ?? \"\" after loading."
rubric:
  - isViewLoaded doesn't call loadView().
  - loadView() and viewDidLoad() run once, in that order, no matter how many times view or loadViewIfNeeded() is used.
  - The view getter reuses loadViewIfNeeded() instead of duplicating the logic.
solution: |
  ```swift
  class LazyController {
      private var storedView: String?

      var isViewLoaded: Bool {
          storedView != nil
      }

      var view: String {
          loadViewIfNeeded()
          return storedView ?? ""
      }

      func loadViewIfNeeded() {
          guard !isViewLoaded else { return }
          loadView()
          viewDidLoad()
      }

      func loadView() {
          print("loadView")
          storedView = "root view"
      }

      func viewDidLoad() {
          print("viewDidLoad")
      }
  }

  let controller = LazyController()
  print(controller.isViewLoaded)
  controller.loadViewIfNeeded()
  controller.loadViewIfNeeded()
  print(controller.view)
  print(controller.isViewLoaded)
  ```

  ```output
  false
  loadView
  viewDidLoad
  root view
  true
  ```

  `isViewLoaded` reads state and never triggers loading, which is exactly what Apple's documentation promises for the real property. Both `view` and `loadViewIfNeeded()` go through one guarded path, so the second call does nothing. Unit tests use the real `loadViewIfNeeded()` this way: to force `viewDidLoad()` before checking a controller's views (Module 33).
````

````exercise
id: m22-l02-e7
type: design
prompt: |
  A chat screen needs to do the following. For each, pick a callback (`init`, `loadView`, `viewDidLoad`, `viewWillAppear`, `viewIsAppearing`, `viewDidAppear`, `viewWillDisappear`, `viewDidDisappear`, `viewDidLayoutSubviews`, or a scene callback) and justify it in one sentence.

  1. Receive the conversation ID and the message service.
  2. Create the message list, the input bar and their constraints.
  3. Scroll to the newest message, which depends on the list's height.
  4. Mark the conversation as read once the user can actually see it.
  5. Save the unsent draft when the user leaves the screen.
  6. Start observing new messages from the database, and stop when the screen is gone.
  7. Stop the typing indicator when the user switches to another app.
rubric:
  - Dependencies in init, views in viewDidLoad (or loadView for a custom root view).
  - Geometry-dependent scrolling in viewIsAppearing.
  - Mark as read in viewDidAppear.
  - Draft saved in viewWillDisappear.
  - Observation started in viewWillAppear and stopped in viewDidDisappear, as Apple's balanced example.
  - App switching handled with scene callbacks, since no view controller callbacks fire.
solution: |
  1. **`init`**: store the ID and the service; don't touch `view`.
  2. **`viewDidLoad()`**: one-time creation of views and constraints. A custom root view would go in `loadView()`.
  3. **`viewIsAppearing(_:)`**: the list has its real size and the scroll shows in the first frame.
  4. **`viewDidAppear(_:)`**: the screen is visible and the transition is over. A swipe-back that gets cancelled won't count as a read.
  5. **`viewWillDisappear(_:)`**: Apple suggests it for committing edits. Also save after the user types, since this isn't called when the app is backgrounded.
  6. **`viewWillAppear(_:)` / `viewDidDisappear(_:)`**: Apple's own example of balanced callbacks for database notifications.
  7. **`sceneWillResignActive(_:)`** (or the matching notification): switching apps doesn't remove the view, so no view controller callback fires.
````

## Summary

- A view controller owns one root view and creates it lazily: the first read of `view` calls `loadView()`, then `viewDidLoad()`. `isViewLoaded` checks without loading.
- `viewDidLoad()` is for one-time setup. Override `loadView()` only to install a custom root view in code, and don't call `super` there.
- Appearance order: `viewWillAppear(_:)` → added to hierarchy, traits and geometry updated → `viewIsAppearing(_:)` → layout callbacks → visible → `viewDidAppear(_:)`.
- Update views in `viewIsAppearing(_:)` (available from iOS 13 per Apple's docs). Keep `viewWillAppear(_:)` for work before the transition and for balanced start/stop pairs.
- Layout callbacks can run many times; keep them cheap and repeatable.
- `viewWillDisappear(_:)` commits edits; `viewDidDisappear(_:)` stops what only matters on screen. Call `super` in all of these.
- Going to the background doesn't trigger view controller callbacks. That's the scene's life cycle.
