---
id: m25-l05
title: Coordinators
description: How to take navigation decisions out of view controllers. You write a coordinator that creates screens, wires their results and pushes or presents them, keep it alive from the scene delegate, start and release child coordinators for sub-flows, notice the back button and the swipe with UINavigationControllerDelegate, and test the navigation logic in plain Swift with a fake navigator.
module: m25
order: 5
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l04]
objectives:
  - Explain what a coordinator is responsible for and what stays in view controllers.
  - Write a coordinator that owns a navigation controller, creates screens and handles their result closures.
  - Keep the root coordinator alive and manage child coordinators so they're released when their flow ends.
  - Detect pops from the back button and the edge swipe with navigationController(_:didShow:animated:) and remove finished children.
  - Test navigation decisions in plain Swift by putting a navigator protocol between the coordinator and UIKit.
terms:
  - term: Coordinator
    definition: "An object that owns the navigation for a flow: it creates view controllers, gives them their data, listens for their results and decides what comes next. View controllers stop knowing about each other."
  - term: Flow
    definition: "A sequence of screens with one purpose and a clear end, such as onboarding, checkout or editing a recipe."
  - term: Child coordinator
    definition: "A coordinator started by another coordinator for a sub-flow. The parent keeps it in an array while the flow runs and removes it when the flow finishes or the user backs out."
  - term: Navigator protocol
    definition: "A small protocol (push, present, dismiss…) that the coordinator calls instead of UIKit directly. The app uses a UIKit implementation; tests use a fake that records the calls."
  - term: UINavigationControllerDelegate
    definition: "The navigation controller's delegate. navigationController(_:didShow:animated:) runs after every transition, including pops by the back button and the swipe, which your code doesn't otherwise see."
mastery:
  - Move the push and present calls out of a list and an editor into a coordinator, wired through closures.
  - Store the root coordinator in the scene delegate and explain what happens if you don't.
  - Start a child coordinator, remove it when it finishes, and remove it when the user backs out of its first screen.
  - Write a fake navigator and use it to check, without UIKit, that tapping Edit presents the editor and Save dismisses it.
  - Say when a coordinator is overkill.
resources: [swift-book-protocols, swift-book-arc, uikit-uiviewcontroller, uikit-uiwindowscene]
cards:
  - id: m25-l05-c1
    front: What does a coordinator do, and what doesn't it do?
    back: "It creates view controllers, passes them data, receives their results and pushes, presents or dismisses. It doesn't lay out views or hold business rules; screens show things and report events, and models and services do the work."
  - id: m25-l05-c2
    front: Who keeps the root coordinator alive?
    back: "The scene delegate, in a stored property, next to window. A local variable would be released when scene(_:willConnectTo:options:) returns, and every [weak self] closure that leads to it would then do nothing."
  - id: m25-l05-c3
    front: Why does a parent coordinator keep its children in an array?
    back: "Nothing else owns a child coordinator: view controllers reference it only weakly through closures. The array keeps it alive while its flow runs; removing it when the flow ends releases it."
  - id: m25-l05-c4
    front: How does a coordinator find out that the user tapped Back past a child flow's first screen?
    back: "Be the navigation controller's delegate and, in navigationController(_:didShow:animated:), remove every child whose first view controller is no longer in navigationController.viewControllers."
  - id: m25-l05-c5
    front: How do you test a coordinator without UIKit?
    back: "Make it depend on a navigator protocol that speaks in screen values (an enum), not view controllers. A fake navigator records the calls; the test drives the coordinator's event methods and compares the log."
---

## The idea in one sentence

A coordinator is a plain object that decides what screen comes next, so view controllers only show things and report what the user did, and the whole navigation of a flow lives in one place you can read and test.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The coordinator pattern isn't an Apple API; the UIKit behavior it relies on comes from Apple's pages for `UINavigationController` and `UINavigationControllerDelegate`, read in November 2026. The plain-Swift coordinators, fakes and lifetime models were compiled and run. Nothing was checked in Xcode or the simulator.

## The problem

After lesson 4, each screen gets its data in `init` and reports through closures. But someone still has to write `pushViewController` and `present`, and so far that's the screen that came before:

- The recipe list creates `RecipeDetailViewController` and pushes it, so the list knows the detail's class and initializer.
- The detail creates the editor and presents it, so the detail knows the editor.
- Change the flow ("on iPad, show the editor in a popover"; "after saving a new recipe, open it") and you edit three view controllers.

Each view controller is a node that also knows the edges leading out of it. The coordinator pattern moves the edges into one object. It's the single responsibility principle from Module 14 applied to navigation: a screen changes when its UI changes, a coordinator changes when the flow changes.

## A first coordinator

```swift ios
import UIKit

struct Recipe {
    let id: Int
    var name: String
}

final class RecipeListViewController: UIViewController {
    var onSelect: ((Recipe) -> Void)?
    var onAdd: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Recipes"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            self?.onAdd?()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("RecipeListViewController is created in code")
    }
}

final class RecipeDetailViewController: UIViewController {
    var onEdit: (() -> Void)?
    private let recipe: Recipe

    init(recipe: Recipe) {
        self.recipe = recipe
        super.init(nibName: nil, bundle: nil)
        title = recipe.name
    }

    required init?(coder: NSCoder) {
        fatalError("RecipeDetailViewController is created in code")
    }
}

final class EditRecipeViewController: UIViewController {
    var onFinish: ((Recipe?) -> Void)?
    private let recipe: Recipe

    init(recipe: Recipe) {
        self.recipe = recipe
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("EditRecipeViewController is created in code")
    }
}

@MainActor
final class RecipesCoordinator {
    let navigationController: UINavigationController
    private var nextID = 100

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let list = RecipeListViewController()
        list.onSelect = { [weak self] recipe in
            self?.showDetail(for: recipe)
        }
        list.onAdd = { [weak self] in
            self?.showNewRecipe()
        }
        navigationController.setViewControllers([list], animated: false)
    }

    private func showDetail(for recipe: Recipe) {
        let detail = RecipeDetailViewController(recipe: recipe)
        detail.onEdit = { [weak self] in
            self?.showEditor(for: recipe)
        }
        navigationController.pushViewController(detail, animated: true)
    }

    private func showNewRecipe() {
        nextID += 1
        showEditor(for: Recipe(id: nextID, name: ""))
    }

    private func showEditor(for recipe: Recipe) {
        let editor = EditRecipeViewController(recipe: recipe)
        editor.onFinish = { [weak self] saved in
            guard let self else { return }
            if let saved {
                print("saving \(saved.name)")
            }
            self.navigationController.dismiss(animated: true)
        }
        navigationController.present(UINavigationController(rootViewController: editor), animated: true)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: RecipesCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let navigationController = UINavigationController()
        let coordinator = RecipesCoordinator(navigationController: navigationController)
        coordinator.start()
        self.coordinator = coordinator

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

What moved where:

- **The view controllers know nothing about each other.** The list reports `onSelect` and `onAdd`; the detail reports `onEdit`; the editor reports `onFinish` with the saved recipe or `nil` for cancel. None of them pushes, presents or dismisses.
- **The coordinator creates every screen** and wires its closures. Reading `RecipesCoordinator` top to bottom tells you the whole flow: list, then detail, then editor, presented, dismissed by the coordinator. That's lesson 3's rule, "the presenter dismisses", with the coordinator acting for the presenter.
- **`@MainActor`** on the coordinator: it creates and drives UIKit objects, so it lives on the main actor like they do.
- **`[weak self]` in every closure.** The navigation controller owns the screens, the screens own their closures, and the coordinator owns the navigation controller. A strong capture would close that loop.
- **The scene delegate stores the coordinator.** Nothing else holds it: the screens only have weak references to it inside their closures. If `coordinator` were a local constant, it would be released when `scene(_:willConnectTo:options:)` returns, every `self?` would be `nil`, and every button in the app would silently do nothing.

A coordinator is not a place for business rules. "Saving" here is a `print`; in a real app the coordinator hands the recipe to a store or service, and the rules for what a valid recipe is live there. Module 32 covers how coordinators fit with view models and services.

## Child coordinators

Some flows are big enough to deserve their own coordinator: checkout (cart, address, payment, confirmation), onboarding, sign-in. A parent starts a **child coordinator** for each, and the hard part is lifetime.

```swift
@MainActor
final class CheckoutCoordinator {
    let firstScreen = "Cart"
    var onFinish: (() -> Void)?

    deinit {
        print("checkout coordinator released")
    }

    func paymentSucceeded() {
        onFinish?()
    }
}

@MainActor
final class ShopCoordinator {
    private(set) var stack = ["Shop"]
    private var children: [CheckoutCoordinator] = []

    var childCount: Int {
        children.count
    }

    func startCheckout() {
        let checkout = CheckoutCoordinator()
        checkout.onFinish = { [weak self, weak checkout] in
            guard let self, let checkout else { return }
            self.children.removeAll { $0 === checkout }
            self.stack = ["Shop"]
        }
        children.append(checkout)
        stack += ["Cart", "Payment"]
    }

    func checkoutPaid() {
        children.first?.paymentSucceeded()
    }

    // The navigation controller's delegate calls this after every transition,
    // including pops from the back button and the edge swipe.
    func didShow(stack newStack: [String]) {
        stack = newStack
        children.removeAll { !stack.contains($0.firstScreen) }
    }
}

let shop = ShopCoordinator()
shop.startCheckout()
print(shop.stack, shop.childCount)
shop.didShow(stack: ["Shop", "Cart"])
print("back to Cart:", shop.childCount)
shop.didShow(stack: ["Shop"])
print("back to Shop:", shop.childCount)
shop.startCheckout()
shop.checkoutPaid()
print(shop.stack, shop.childCount)
```

```output
["Shop", "Cart", "Payment"] 1
back to Cart: 1
checkout coordinator released
back to Shop: 0
checkout coordinator released
["Shop"] 0
```

Strings stand for view controllers. The model shows the three rules:

1. **The parent owns its children.** `children.append(checkout)` is the only strong reference to the checkout coordinator. Without it, the child would be released as soon as `startCheckout()` returns.
2. **A child that finishes tells the parent**, through `onFinish`, and the parent removes it. `[weak self, weak checkout]`: the child owns the closure, so capturing the child strongly would make it own itself.
3. **A child the user abandons is removed too.** Going back from Payment to Cart leaves the child running: Cart is its first screen, still on the stack. Going back to Shop removes Cart, so the child's flow is over and `didShow` drops it. Without this rule, every abandoned checkout leaks a coordinator.

The third rule is the one people miss, because nothing in your code runs when the user taps Back.

## Seeing the back button: UINavigationControllerDelegate

The back button and the edge swipe pop without calling any of your methods. The navigation controller does tell its delegate. Apple: `navigationController(_:didShow:animated:)` "notifies the delegate after the navigation controller displays a view controller's view and navigation item properties", which happens after a push, a pop from code, a back tap or a completed swipe. At that point `viewControllers` is the new stack, and that's all you need:

```swift ios
import UIKit

final class CartViewController: UIViewController {
    var onCheckout: (() -> Void)?
}

final class PaymentViewController: UIViewController {
    var onPaid: (() -> Void)?
}

@MainActor
final class CheckoutCoordinator {
    private let navigationController: UINavigationController
    private(set) weak var firstViewController: UIViewController?
    var onFinish: (() -> Void)?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let cart = CartViewController()
        cart.onCheckout = { [weak self] in
            self?.showPayment()
        }
        firstViewController = cart
        navigationController.pushViewController(cart, animated: true)
    }

    private func showPayment() {
        let payment = PaymentViewController()
        payment.onPaid = { [weak self] in
            self?.onFinish?()
        }
        navigationController.pushViewController(payment, animated: true)
    }
}

@MainActor
final class ShopCoordinator: NSObject, UINavigationControllerDelegate {
    private let navigationController: UINavigationController
    private var children: [CheckoutCoordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
        navigationController.delegate = self
    }

    func startCheckout() {
        let checkout = CheckoutCoordinator(navigationController: navigationController)
        checkout.onFinish = { [weak self, weak checkout] in
            guard let self, let checkout else { return }
            self.children.removeAll { $0 === checkout }
            self.navigationController.popToRootViewController(animated: true)
        }
        children.append(checkout)
        checkout.start()
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController, animated: Bool) {
        let stack = navigationController.viewControllers
        children.removeAll { child in
            guard let first = child.firstViewController else { return true }
            return !stack.contains { $0 === first }
        }
    }
}
```

- **`NSObject`**: `UINavigationControllerDelegate` inherits `NSObjectProtocol`, so the conforming class must be an `NSObject` subclass. Its `init` calls `super.init()` after setting its own properties.
- **`navigationController.delegate = self`**. The property is `weak`, so it doesn't keep the coordinator alive; its parent (or the scene delegate) does.
- **The child shares the parent's navigation controller** and pushes its screens onto it. That's why the parent watches that stack.
- **The check is identity**, `$0 === first`: is this exact controller still on the stack? `firstViewController` is `weak`, so if the cart has already been released it's `nil` and the child is removed too.
- **Finishing normally** goes through `onFinish`: the parent removes the child and pops to its own root. The delegate method then runs again and finds nothing left to remove.

A navigation controller has one delegate. If something else (a custom transition, for example) also needs it, the coordinator becomes the delegate and forwards.

> [!tip] A lighter alternative
> For a single screen rather than a whole flow, the screen can report its own removal: in `viewDidDisappear(_:)`, `isMovingFromParent` is `true` when it's being popped. Apple's page for it has no discussion text, so this wasn't confirmed beyond its one-line description, "whether the view controller is moving from a parent view controller". The delegate approach above covers every child in one place and doesn't depend on each screen remembering to report.

Modal flows have the same issue in a different place: a sheet swiped away calls `presentationControllerDidDismiss(_:)` and nothing else (lesson 3). A child coordinator that presents its flow sets itself as the presentation controller's delegate (it's an `NSObject` for the same reason) and finishes from there as well as from its own Cancel and Done.

## Testing navigation without UIKit

`RecipesCoordinator` above calls `UINavigationController` directly, so testing it needs UIKit and a running app. Put a small protocol in between that speaks in **screens**, not view controllers, and the decisions become plain Swift:

```swift
enum Screen: Equatable {
    case recipeList
    case recipeDetail(id: Int)
    case newRecipe
    case editRecipe(id: Int)
}

@MainActor
protocol Navigator: AnyObject {
    func setRoot(_ screen: Screen)
    func push(_ screen: Screen)
    func present(_ screen: Screen)
    func dismiss()
}

@MainActor
final class RecipesCoordinator {
    private let navigator: any Navigator
    private(set) var savedNames: [String] = []

    init(navigator: any Navigator) {
        self.navigator = navigator
    }

    func start() {
        navigator.setRoot(.recipeList)
    }

    func didSelectRecipe(id: Int) {
        navigator.push(.recipeDetail(id: id))
    }

    func didTapAdd() {
        navigator.present(.newRecipe)
    }

    func didTapEdit(id: Int) {
        navigator.present(.editRecipe(id: id))
    }

    func editorDidFinish(savedName: String?) {
        if let savedName {
            savedNames.append(savedName)
        }
        navigator.dismiss()
    }
}

@MainActor
final class FakeNavigator: Navigator {
    private(set) var log: [String] = []

    func setRoot(_ screen: Screen) { log.append("root \(screen)") }
    func push(_ screen: Screen) { log.append("push \(screen)") }
    func present(_ screen: Screen) { log.append("present \(screen)") }
    func dismiss() { log.append("dismiss") }
}

let navigator = FakeNavigator()
let coordinator = RecipesCoordinator(navigator: navigator)
coordinator.start()
coordinator.didSelectRecipe(id: 4)
coordinator.didTapEdit(id: 4)
coordinator.editorDidFinish(savedName: "Pancakes")
coordinator.didTapAdd()
coordinator.editorDidFinish(savedName: nil)

for entry in navigator.log {
    print(entry)
}
print("saved:", coordinator.savedNames)
print(navigator.log == ["root recipeList", "push recipeDetail(id: 4)", "present editRecipe(id: 4)", "dismiss", "present newRecipe", "dismiss"])
```

```output
root recipeList
push recipeDetail(id: 4)
present editRecipe(id: 4)
dismiss
present newRecipe
dismiss
saved: ["Pancakes"]
true
```

- **`Screen`** is a value describing a destination, with the data it needs (an id, not a whole view controller). Lesson 6 builds on exactly this enum.
- **The coordinator's event methods** (`didSelectRecipe`, `didTapEdit`, `editorDidFinish`) are what the screens' closures call. The test calls them directly, as if the user had tapped.
- **`FakeNavigator`** records what it was asked to do. It's a `final class` so the test and the coordinator share one instance (Module 10).
- **The last line** compares the whole log to the expected one. In a test target that's `#expect(navigator.log == [...])` with Swift Testing; Module 33 sets that up. Here a `print` stands in.

This is dependency inversion from Module 14: the coordinator, the high-level policy, depends on a protocol it owns; UIKit is plugged in from outside.

### The UIKit side

The production navigator turns screens into view controllers and their events into coordinator calls. It's thin on purpose: there's no decision in it worth testing.

```swift ios
import UIKit

enum Screen: Equatable {
    case recipeList
    case recipeDetail(id: Int)
    case newRecipe
    case editRecipe(id: Int)
}

@MainActor
protocol RecipeEvents: AnyObject {
    func didSelectRecipe(id: Int)
    func didTapAdd()
    func didTapEdit(id: Int)
    func editorDidFinish(savedName: String?)
}

final class RecipeListViewController: UIViewController {
    var onSelect: ((Int) -> Void)?
    var onAdd: (() -> Void)?
}

final class RecipeDetailViewController: UIViewController {
    var onEdit: (() -> Void)?
    let recipeID: Int

    init(recipeID: Int) {
        self.recipeID = recipeID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("RecipeDetailViewController is created in code")
    }
}

final class EditRecipeViewController: UIViewController {
    var onFinish: ((String?) -> Void)?
    let recipeID: Int?

    init(recipeID: Int?) {
        self.recipeID = recipeID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("EditRecipeViewController is created in code")
    }
}

@MainActor
final class UIKitNavigator {
    private let navigationController: UINavigationController
    weak var events: (any RecipeEvents)?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func setRoot(_ screen: Screen) {
        navigationController.setViewControllers([makeViewController(for: screen)], animated: false)
    }

    func push(_ screen: Screen) {
        navigationController.pushViewController(makeViewController(for: screen), animated: true)
    }

    func present(_ screen: Screen) {
        let wrapped = UINavigationController(rootViewController: makeViewController(for: screen))
        navigationController.present(wrapped, animated: true)
    }

    func dismiss() {
        navigationController.dismiss(animated: true)
    }

    private func makeViewController(for screen: Screen) -> UIViewController {
        switch screen {
        case .recipeList:
            let list = RecipeListViewController()
            list.onSelect = { [weak self] id in self?.events?.didSelectRecipe(id: id) }
            list.onAdd = { [weak self] in self?.events?.didTapAdd() }
            return list
        case .recipeDetail(let id):
            let detail = RecipeDetailViewController(recipeID: id)
            detail.onEdit = { [weak self] in self?.events?.didTapEdit(id: id) }
            return detail
        case .newRecipe, .editRecipe:
            var recipeID: Int?
            if case .editRecipe(let id) = screen {
                recipeID = id
            }
            let editor = EditRecipeViewController(recipeID: recipeID)
            editor.onFinish = { [weak self] name in self?.events?.editorDidFinish(savedName: name) }
            return editor
        }
    }
}
```

In the app, `UIKitNavigator` also declares conformance to `Navigator`, and `RecipesCoordinator` to `RecipeEvents`; the coordinator owns the navigator, and the navigator points back with `weak var events`. The block keeps the two protocols separate only so it stands alone.

The `switch` is exhaustive: add a case to `Screen` and this file stops compiling until the new screen has a view controller.

## When not to use one

A coordinator is one more type per flow and one more indirection when you're reading code. It pays for itself when:

- the same screen is reached from several places and must behave differently after each;
- a flow has branches (signed in or not, iPhone or iPad);
- you want navigation covered by tests;
- deep links have to rebuild a stack (lesson 6).

A settings screen that pushes two static detail pages doesn't need one. Starting with closures (lesson 4) and moving the push calls into a coordinator when a second caller appears is a small, safe refactoring. SwiftUI apps usually express the same idea differently, with navigation state in a model (Module 35).

## Common mistakes

> [!error] The root coordinator in a local variable
> `let coordinator = AppCoordinator(...); coordinator.start()` in the scene delegate, never stored. The first screen appears, then nothing responds: every `[weak self]` closure finds `nil`. Store it in a property.

> [!error] Children that are never removed
> A child that finishes without telling its parent, or a flow the user backs out of, stays in `children` forever with everything it references. Remove on `onFinish` and in `navigationController(_:didShow:animated:)`.

> [!error] Strong captures between coordinator and screens
> `list.onSelect = { self.showDetail(...) }`. The coordinator owns the navigation controller, which owns the list, which owns the closure. `[weak self]`.

> [!error] A coordinator that does everything
> Validation, network calls and formatting creep in because "the coordinator already knows about the recipe". It should know where the user goes next, not what a valid recipe is.

> [!error] A navigator protocol that takes view controllers
> `func push(_ viewController: UIViewController)` still needs UIKit in every test. Make the protocol speak in screen values.

## Exercises

````exercise
id: m25-l05-e1
type: prediction
prompt: "What does this print, line by line?"
code: |
  @MainActor
  final class Flow {
      let name: String
      let firstScreen: String

      init(name: String, firstScreen: String) {
          self.name = name
          self.firstScreen = firstScreen
      }

      deinit {
          print("\(name) released")
      }
  }

  @MainActor
  final class Parent {
      private var children: [Flow] = []

      func start(_ flow: Flow) {
          children.append(flow)
      }

      func didShow(stack: [String]) {
          children.removeAll { !stack.contains($0.firstScreen) }
          print("children:", children.map { $0.name })
      }
  }

  let parent = Parent()
  parent.start(Flow(name: "profile", firstScreen: "Profile"))
  parent.start(Flow(name: "photos", firstScreen: "Album"))
  parent.didShow(stack: ["Home", "Profile", "Album", "Photo"])
  parent.didShow(stack: ["Home", "Profile", "Album"])
  parent.didShow(stack: ["Home", "Profile"])
  parent.didShow(stack: ["Home"])
output: |
  children: ["profile", "photos"]
  children: ["profile", "photos"]
  photos released
  children: ["profile"]
  profile released
  children: []
hints:
  - "A child is removed only when its first screen leaves the stack."
  - "The array is the only owner, so removal runs deinit immediately, before the print."
solution: |
  ```output
  children: ["profile", "photos"]
  children: ["profile", "photos"]
  photos released
  children: ["profile"]
  profile released
  children: []
  ```

  Popping Photo leaves Album on the stack, so the photos flow is still running. Popping Album removes the photos flow's first screen: `removeAll` drops the child, it has no other owner, and its `deinit` prints before the `children:` line. Popping Profile does the same for the profile flow. This is the back-button rule from the lesson, in miniature.
````

````exercise
id: m25-l05-e2
type: comprehension
prompt: "An app's first screen shows correctly, but none of its buttons do anything. The scene delegate contains the code below. What's wrong?"
code: |
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
      guard let windowScene = scene as? UIWindowScene else { return }
      let navigationController = UINavigationController()
      let coordinator = AppCoordinator(navigationController: navigationController)
      coordinator.start()
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = navigationController
      self.window = window
      window.makeKeyAndVisible()
  }
choices:
  - text: "The coordinator is a local constant; it's released when the method returns, and the screens' [weak self] closures then do nothing."
    correct: true
    why: "The window keeps the navigation controller and its screens, but nothing keeps the coordinator."
  - text: "start() must be called after makeKeyAndVisible()."
    correct: false
    why: "Building the stack before showing the window is fine and avoids an empty first frame."
  - text: "The navigation controller needs a root view controller in its initializer."
    correct: false
    why: "start() sets the stack with setViewControllers; the empty initializer is fine."
  - text: "Coordinators must be created in the app delegate, not the scene delegate."
    correct: false
    why: "Each scene has its own window and its own navigation, so the scene delegate is the natural owner."
solution: |
  **The coordinator isn't stored.** The window owns the navigation controller, which owns the screens, which hold closures that reference the coordinator weakly. Nothing holds it strongly, so it's released at the end of the method and every `self?.` in those closures is `nil`. Add `private var coordinator: AppCoordinator?` to the scene delegate and assign it.
````

````exercise
id: m25-l05-e3
type: fill-in
prompt: "Complete the parent coordinator that removes a child flow when the user taps Back past its first screen."
code: |
  @MainActor
  final class LibraryCoordinator: [[1]], UINavigationControllerDelegate {
      private let navigationController: UINavigationController
      private var children: [ReaderCoordinator] = []

      init(navigationController: UINavigationController) {
          self.navigationController = navigationController
          super.init()
          navigationController.[[2]] = self
      }

      func navigationController(_ navigationController: UINavigationController,
                                [[3]] viewController: UIViewController, animated: Bool) {
          let stack = navigationController.[[4]]
          children.removeAll { child in
              guard let first = child.firstViewController else { return true }
              return !stack.contains { $0 [[5]] first }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["NSObject"]
  - id: "2"
    answers: ["delegate"]
  - id: "3"
    answers: ["didShow"]
  - id: "4"
    answers: ["viewControllers"]
  - id: "5"
    answers: ["==="]
solution: |
  ```swift ios
  import UIKit

  @MainActor
  final class ReaderCoordinator {
      weak var firstViewController: UIViewController?
  }

  @MainActor
  final class LibraryCoordinator: NSObject, UINavigationControllerDelegate {
      private let navigationController: UINavigationController
      private var children: [ReaderCoordinator] = []

      init(navigationController: UINavigationController) {
          self.navigationController = navigationController
          super.init()
          navigationController.delegate = self
      }

      func navigationController(_ navigationController: UINavigationController,
                                didShow viewController: UIViewController, animated: Bool) {
          let stack = navigationController.viewControllers
          children.removeAll { child in
              guard let first = child.firstViewController else { return true }
              return !stack.contains { $0 === first }
          }
      }
  }
  ```

  `NSObject` because the delegate protocol inherits `NSObjectProtocol`. `didShow` runs after every transition, so `viewControllers` is already the new stack. `===` asks "is this the same instance", which is the question here.
````

````exercise
id: m25-l05-e4
type: solve
prompt: |
  Write an `OnboardingCoordinator` that works against the `OnboardingNavigator` protocol below. The flow: show `.welcome`; when welcome continues, show `.notifications`; when notifications is answered, show `.signIn` if the app needs an account, otherwise finish; when sign-in succeeds, finish.

  Then write `FakeOnboardingNavigator`, which records `"show <screen>"` and `"finish"` in a `log` array. This test code:

  ```swift
  for needsAccount in [false, true] {
      let navigator = FakeOnboardingNavigator()
      let coordinator = OnboardingCoordinator(navigator: navigator, needsAccount: needsAccount)
      coordinator.start()
      coordinator.welcomeDidContinue()
      coordinator.notificationsDidAnswer()
      if needsAccount {
          coordinator.signInDidSucceed()
      }
      print(needsAccount, navigator.log)
  }
  ```

  should print:

  ```plaintext
  false ["show welcome", "show notifications", "finish"]
  true ["show welcome", "show notifications", "show signIn", "finish"]
  ```
starter: |
  enum OnboardingScreen {
      case welcome
      case notifications
      case signIn
  }

  @MainActor
  protocol OnboardingNavigator: AnyObject {
      func show(_ screen: OnboardingScreen)
      func finish()
  }

  // your OnboardingCoordinator and FakeOnboardingNavigator
hints:
  - "The coordinator stores the navigator as any OnboardingNavigator and needsAccount as a let."
  - "\"show \\(screen)\" prints the case name, such as show welcome."
rubric:
  - The coordinator has no UIKit import and depends only on the protocol.
  - Each event method makes exactly one navigation call.
  - The fake is a final class whose log the test can read after the calls.
  - The output matches.
solution: |
  ```swift
  enum OnboardingScreen {
      case welcome
      case notifications
      case signIn
  }

  @MainActor
  protocol OnboardingNavigator: AnyObject {
      func show(_ screen: OnboardingScreen)
      func finish()
  }

  @MainActor
  final class OnboardingCoordinator {
      private let navigator: any OnboardingNavigator
      private let needsAccount: Bool

      init(navigator: any OnboardingNavigator, needsAccount: Bool) {
          self.navigator = navigator
          self.needsAccount = needsAccount
      }

      func start() {
          navigator.show(.welcome)
      }

      func welcomeDidContinue() {
          navigator.show(.notifications)
      }

      func notificationsDidAnswer() {
          if needsAccount {
              navigator.show(.signIn)
          } else {
              navigator.finish()
          }
      }

      func signInDidSucceed() {
          navigator.finish()
      }
  }

  @MainActor
  final class FakeOnboardingNavigator: OnboardingNavigator {
      private(set) var log: [String] = []

      func show(_ screen: OnboardingScreen) {
          log.append("show \(screen)")
      }

      func finish() {
          log.append("finish")
      }
  }

  for needsAccount in [false, true] {
      let navigator = FakeOnboardingNavigator()
      let coordinator = OnboardingCoordinator(navigator: navigator, needsAccount: needsAccount)
      coordinator.start()
      coordinator.welcomeDidContinue()
      coordinator.notificationsDidAnswer()
      if needsAccount {
          coordinator.signInDidSucceed()
      }
      print(needsAccount, navigator.log)
  }
  ```

  ```output
  false ["show welcome", "show notifications", "finish"]
  true ["show welcome", "show notifications", "show signIn", "finish"]
  ```

  The only branch in the flow is in `notificationsDidAnswer()`, and both sides of it are now checked in a terminal. In the app, a UIKit navigator would push each screen onto an onboarding navigation controller, and `finish()` would tell the parent coordinator to replace the window's root with the main interface (Module 22, lesson 1).
````

````exercise
id: m25-l05-e5
type: find-errors
prompt: "Review this coordinator. Mark every real problem."
code: |
  final class ProfileCoordinator {
      let navigationController: UINavigationController
      var children: [PhotoPickerCoordinator] = []

      init(navigationController: UINavigationController) {
          self.navigationController = navigationController
      }

      func start() {
          let profile = ProfileViewController()
          profile.onChangePhoto = {
              self.pickPhoto()
          }
          profile.onSave = { name in
              guard name.count >= 2, name.count <= 30, !name.contains("@") else { return }
              UserDefaults.standard.set(name, forKey: "name")
          }
          navigationController.pushViewController(profile, animated: true)
      }

      func pickPhoto() {
          let picker = PhotoPickerCoordinator(navigationController: navigationController)
          children.append(picker)
          picker.start()
      }
  }
choices:
  - text: "onChangePhoto captures self strongly: coordinator → navigation controller → profile → closure → coordinator."
    correct: true
  - text: "Child picker coordinators are appended but never removed, so each finished or abandoned picker leaks."
    correct: true
  - text: "Name validation and persistence live in the coordinator instead of a model or service."
    correct: true
  - text: "The class isn't @MainActor although it creates and drives UIKit objects; in Swift 6 mode that doesn't compile."
    correct: true
  - text: "A coordinator must not hold a navigation controller; only view controllers may."
    correct: false
    why: "Owning the navigation controller (or receiving it from the parent) is the core of the pattern."
rubric:
  - I found the strong capture.
  - I found the missing child removal.
  - I found the business logic in the coordinator.
  - I noticed the missing @MainActor.
solution: |
  1. **`[weak self]`** in `onChangePhoto`.
  2. **Remove children**: give the picker an `onFinish` that removes it, and make the coordinator the navigation controller's delegate (or the presentation controller's delegate, if the picker is presented) to drop abandoned ones.
  3. **Move the rules out**: a `ProfileValidator` or the profile model decides what a valid name is, and a store saves it. The coordinator only decides what happens next, such as popping after a successful save.
  4. **`@MainActor`** on the class: it calls `ProfileViewController()`, `pushViewController` and other main-actor APIs from its own methods.
````

````exercise
id: m25-l05-e6
type: design
prompt: |
  A banking app has: a tab bar with Accounts, Payments and Profile; in Accounts, a list → account detail → transaction detail; in Payments, a "Send money" flow (recipient → amount → confirm → done) that can be started from Payments and from an account's detail; a sign-in flow shown at launch when there's no session. Sketch the coordinators: which exist, who owns whom, which navigation controller each one uses, and how each child is removed.
rubric:
  - An app coordinator owned by the scene delegate decides between sign-in and the main tabs.
  - One coordinator per tab, each with its own navigation controller.
  - Send money is a child coordinator that can be started by two different parents.
  - Every child has a removal path for finishing and for backing out or swiping away.
solution: |
  - **AppCoordinator** (owned by the scene delegate): at start, shows **SignInCoordinator** as its child if there's no session, otherwise builds the tab bar. When sign-in finishes, it removes that child and replaces the window's root with the tabs.
  - **AccountsCoordinator**, **PaymentsCoordinator**, **ProfileCoordinator**: children of AppCoordinator, one per tab, each owning that tab's `UINavigationController`. Accounts pushes list → detail → transaction itself; those are screens, not flows.
  - **SendMoneyCoordinator**: a child of whichever coordinator starts it. From Payments it can push onto the Payments stack; from an account's detail it's better presented in its own navigation controller so the user doesn't lose their place in Accounts. It takes the starting recipient or account in `init` and reports `onFinish(success:)`.
  - **Removal**: every child calls `onFinish` on completion or cancel. Pushed children are also removed in the parent's `navigationController(_:didShow:animated:)` when their first screen leaves the stack; presented ones in `presentationControllerDidDismiss(_:)` when swiped away.
````

## Summary

- A coordinator creates screens, gives them data, wires their result closures and pushes, presents and dismisses. Screens report events and don't know about each other.
- Keep the root coordinator in the scene delegate. Parents keep children in an array, and that array is the only strong reference to each child.
- Remove a child when it reports that it finished, and when the user backs out: as the navigation controller's delegate (an `NSObject` subclass), check in `navigationController(_:didShow:animated:)` whether each child's first view controller is still in `viewControllers`.
- Capture `[weak self]` (and `[weak child]`) in every closure that connects screens and coordinators.
- To test navigation, make the coordinator depend on a navigator protocol that speaks in a `Screen` enum. A fake records calls; a thin UIKit navigator turns screens into view controllers.
- Use coordinators when flows branch, screens are reused from several places, or deep links must rebuild stacks. Small apps can start with closures.
