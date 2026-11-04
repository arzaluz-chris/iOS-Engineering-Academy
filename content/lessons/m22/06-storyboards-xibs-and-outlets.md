---
id: m22-l06
title: Storyboards, XIBs, outlets and actions
description: Interface Builder lets you lay out screens visually and connect them to code. You learn what storyboards and XIBs are, how UIKit turns them into objects, how IBOutlet and IBAction connections work underneath, why a broken connection crashes and how to read each crash, how to inject dependencies into storyboard view controllers, and how teams decide between code and Interface Builder.
module: m22
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l05]
objectives:
  - Explain what storyboards and XIB files contain and how UIKit creates objects from them with init(coder:).
  - Declare outlets and actions with @IBOutlet and @IBAction, and say when outlets are connected relative to viewDidLoad().
  - Diagnose the crashes caused by a stale outlet connection, an unconnected outlet and a stale action connection.
  - Load view controllers from a storyboard in code, including with custom dependencies through instantiateViewController(identifier:creator:).
  - Load a view controller's view or a custom view from a XIB.
  - Argue for code, XIBs or storyboards for a given team and project.
terms:
  - term: Interface Builder
    definition: "Xcode's visual editor for storyboard and XIB files. You place views, set their properties and constraints, and connect them to outlets and actions in your classes."
  - term: Storyboard
    definition: "A .storyboard file containing one or more view controller scenes, their views, and the segues between them. One view controller can be marked as the initial one."
  - term: XIB / nib
    definition: "A .xib file describes the views of one view controller or one standalone view. Xcode compiles it into a nib in the app bundle; UINib and init(nibName:bundle:) load it."
  - term: Outlet
    definition: "A property marked @IBOutlet that Interface Builder can connect to an object in the file. UIKit sets it when the file is loaded, before viewDidLoad()."
  - term: Action (IBAction)
    definition: "A method marked @IBAction that Interface Builder can connect to a control event. It's target-action configured in the file instead of in code."
mastery:
  - Write a storyboard-backed view controller with two outlets and one action, using the conventions Apple documents.
  - Explain the load order from init(coder:) to viewDidLoad() and why outlets are nil in init.
  - Name the cause of each of the three classic connection crashes from its symptom.
  - Write the init?(coder:store:) and creator closure that inject a dependency into a storyboard view controller.
  - Load a custom view from a XIB with UINib.
  - Give two concrete reasons a team might avoid storyboards and two reasons to keep them.
resources: [apple-documentation, swift-book-initialization, swift-book-arc]
cards:
  - id: m22-l06-c1
    front: How does UIKit create a view controller from a storyboard?
    back: "With init(coder:). Then it creates each view (also init(coder:)), connects outlets and actions, calls awakeFromNib(), assigns view and calls viewDidLoad(). Outlets are nil in init and set by viewDidLoad()."
  - id: m22-l06-c2
    front: How does Apple declare an outlet in Swift, and why weak?
    back: "@IBOutlet weak var imageView: UIImageView? (many codebases use UIImageView!). Weak because the view hierarchy already owns the view; the outlet is just a reference to it."
  - id: m22-l06-c3
    front: The storyboard still has a connection for an outlet you renamed in code. What happens?
    back: "On iOS, outlets are set with setValue(_:forKey:). No property has the old key, so setValue(_:forUndefinedKey:) raises an undefined-key exception and the app crashes while loading that screen."
  - id: m22-l06-c4
    front: An @IBOutlet declared with ! was never connected. What happens?
    back: "It stays nil. The first line that uses it crashes with Swift's 'Unexpectedly found nil while implicitly unwrapping an Optional value'."
  - id: m22-l06-c5
    front: How do you pass a dependency to a view controller that lives in a storyboard?
    back: "Give it init?(coder: NSCoder, store: Store) that sets the property and calls super.init(coder:), then create it with storyboard.instantiateViewController(identifier:) { coder in MyViewController(coder: coder, store: store) }."
---

## The idea in one sentence

A storyboard or XIB is an archive of objects you design visually; when UIKit loads it, it re-creates those objects with `init(coder:)` and reconnects them to your code by **name**, which is why a renamed property or method in code can crash the app at runtime instead of failing to compile.

> [!note] About this lesson's code and Xcode
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run, and no storyboard was built for this lesson. Loading behavior comes from Apple's documentation (`UIViewController`, `UIStoryboard`, `UINib`, `awakeFromNib()`, "Displaying and managing views with a view controller", "Responding to control-based events using target-action") and the archived *Resource Programming Guide*, read in November 2026. The few Xcode editor steps mentioned are quoted from Apple's articles and weren't checked in Xcode. The plain-Swift models and the Swift crash message were compiled and run with Swift 6.3.

## Interface Builder files

Interface Builder is the visual editor in Xcode. It edits two kinds of files:

| | Storyboard (`.storyboard`) | XIB (`.xib`) |
| --- | --- | --- |
| Contains | Several view controller **scenes**, their views, and **segues** (transitions) between them | The views of **one** view controller, or one standalone view |
| Entry point | One view controller marked as the **initial** one | None; you load it by name |
| Typical use | A whole app flow or one feature's screens | A reusable custom view or one screen |
| Loaded with | `UIStoryboard`, or automatically through `UISceneStoryboardFile` | `init(nibName:bundle:)` on a view controller, or `UINib` |

Apple's `UIViewController` documentation describes three ways to give a controller its views: in a storyboard ("Storyboards are the preferred way to specify your views"), in a nib file ("A nib file lets you specify the views of a single view controller but doesn't let you define segues or relationships between view controllers"), or in code by overriding `loadView()`. "All of these techniques have the same end result."

Xcode compiles these files into the app bundle. At runtime they're archives: descriptions of objects and their properties that UIKit unarchives into real instances.

### A storyboard as the scene's UI

Lesson 1 showed the scene manifest. If a configuration includes `UISceneStoryboardFile` (the storyboard's name without the extension), Apple says "UIKit creates a window for your scene automatically and installs the initial view controller from your storyboard in it." Your scene delegate then only declares `var window: UIWindow?`. And: "Don't forget to designate an initial view controller in your storyboard. UIKit relies on the presence of this view controller when configuring your UI."

Apple also lists a launch screen storyboard among the resources every UIKit app needs: it's displayed immediately when the app is opened, while the app initializes. It's static; it can't run your code.

## How UIKit loads a storyboard view controller

From "Displaying and managing views with a view controller", when UIKit loads a view controller's views from a storyboard it:

1. Creates each view using the view's `init(coder:)`.
2. Connects views to the corresponding actions and outlets in the view controller.
3. Calls `awakeFromNib()` on each view and the view controller.
4. Assigns the view hierarchy to the controller's `view` property.
5. Calls the controller's `viewDidLoad()`.

The controller itself was created earlier, also with `init(coder:)`: "During the instantiation process, UIStoryboard creates your view controller programmatically using its init(coder:) method." So in `init(coder:)` **every outlet is still `nil`**; in `awakeFromNib()` and `viewDidLoad()` they're connected. Apple's `awakeFromNib()` page: "When an object receives an awakeFromNib message, it is guaranteed to have all its outlet and action connections already established."

## Outlets

An outlet is a property Interface Builder can fill in:

```swift ios
import UIKit

final class ProfileViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var avatarView: UIImageView?

    var userName = "Christian"

    override func viewDidLoad() {
        super.viewDidLoad()
        nameLabel.text = userName
        avatarView?.layer.cornerRadius = 22
    }
}
```

- **`@IBOutlet`** "tells Xcode to expose that property in your storyboard" (Apple). The Swift book adds that it "implies the objc attribute": the property is visible to the Objective-C runtime, which is how UIKit sets it.
- **`weak`**: Apple's article says "include the weak keyword to prevent your view controller from holding a second strong reference to the view—the first originates from the view hierarchy itself." The archived *Resource Programming Guide* gives the general rule: "Outlets should generally be weak, except for those from File's Owner to top-level objects in a nib file (or, in iOS, a storyboard scene) which should be strong."
- **`UILabel!` or `UIImageView?`**: Apple's own example declares outlets as plain optionals. Most codebases use implicitly unwrapped optionals (`!`) instead, because a connected outlet is never `nil` after loading and `!` saves `?` on every use. The cost: if the connection is missing, the first use crashes. Both are fine; know which one you chose.
- Store outlets only for views you'll change later. Apple: "You don't need to store references to all views in your view hierarchy."

### How outlets are set, and the first crash

The *Resource Programming Guide*: "In iOS, the nib-loading code uses the setValue:forKey: method to reconnect each outlet." The key is the outlet's **name**, saved in the storyboard when you made the connection. If the class no longer has a property with that name (you renamed `nameLabel` to `titleLabel` in code, or deleted it, and the storyboard still has the old connection), `setValue(_:forKey:)` falls back on `setValue(_:forUndefinedKey:)`, whose default implementation, per Apple, "raises an NSUndefinedKeyException". The app crashes as soon as it loads that screen.

The console message for this crash usually mentions that the class "is not key value coding-compliant for the key" followed by the old outlet name. That wording is widely reported but wasn't observed for this lesson; the reliable clue is the **key**, which tells you which stale connection to delete in the storyboard's connections.

A plain-Swift model of loading by name:

```swift
final class Label {
    let name: String
    init(name: String) { self.name = name }
}

final class ProfileViewController {
    var titleLabel: Label!       // renamed in code from nameLabel
    var bioLabel: Label!

    func setValue(_ value: Label, forKey key: String) -> Bool {
        switch key {
        case "titleLabel": titleLabel = value
        case "bioLabel": bioLabel = value
        default:
            print("undefined key '\(key)': loading stops here")
            return false
        }
        print("connected \(key) to \(value.name)")
        return true
    }
}

// What the storyboard saved when the connections were made.
let savedConnections = [("bioLabel", "Label B"), ("nameLabel", "Label A")]

let controller = ProfileViewController()
for (key, viewName) in savedConnections {
    guard controller.setValue(Label(name: viewName), forKey: key) else { break }
}
print("titleLabel connected: \(controller.titleLabel != nil)")
```

```output
connected bioLabel to Label B
undefined key 'nameLabel': loading stops here
titleLabel connected: false
```

The model stops and prints; the real app raises an exception and terminates. Either way, the fix is in the storyboard, not in the code.

### The second crash: an outlet that was never connected

The opposite mistake: the property exists, but the connection doesn't (you declared the outlet and forgot to connect it, or deleted the connection). Nothing fails during loading. The outlet stays `nil`, and with `!` the first use stops the program:

```swift runtime-error Unexpectedly found nil while implicitly unwrapping an Optional value
final class Label {
    var text = ""
}

final class ProfileViewController {
    var nameLabel: Label!   // stands in for @IBOutlet weak var nameLabel: UILabel!

    func viewDidLoad() {
        print("viewDidLoad")
        nameLabel.text = "Christian"
        print("name shown")
    }
}

let controller = ProfileViewController()
controller.viewDidLoad()   // no connection ever assigned nameLabel
```

```output
viewDidLoad
```

Swift 6.3 stops with `Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value`, pointing at the `nameLabel.text` line. In a real app the debugger stops on that line in your controller. When an outlet is `nil` in `viewDidLoad()`, check the connection first, and then check that the controller really came from the storyboard (a `ProfileViewController()` created in code has no storyboard, so it has no connections at all).

## Actions

An action is a method Interface Builder can connect to a control event:

```swift ios
import UIKit

final class VolumeViewController: UIViewController {
    @IBOutlet weak var volumeLabel: UILabel!

    @IBAction func volumeChanged(_ sender: UISlider) {
        volumeLabel.text = "\(Int(sender.value * 100))%"
    }

    @IBAction func resetTapped(_ sender: UIButton) {
        volumeLabel.text = "50%"
    }
}
```

`@IBAction` also implies `@objc`. The signatures are the target-action ones from lesson 5: no parameters, the sender, or the sender and the event. In Interface Builder you pick the event when you make the connection (a slider's Value Changed, a button's Touch Up Inside or Primary Action Triggered).

Apple's target-action article describes connecting one: select the control, "Control-drag the control to the view controller in the document outline", and select the action method; or Control-drag from the control into the view controller's source and name the new action, so "Xcode generates the action method for you". It also says you can check a connection by moving the pointer over the circle to the left of the action method, which highlights the control. (These steps are Apple's; they weren't checked in Xcode 27 for this lesson.)

### The third crash: a stale action

An action connection is saved as a selector: the method's Objective-C name, such as `volumeChanged:`. Rename the Swift method to `sliderMoved(_:)` and the storyboard still sends `volumeChanged:` to the controller, which no longer has it. Loading succeeds; the crash comes when the user **moves the slider**, as an "unrecognized selector sent to instance" exception. (That's the usual Objective-C runtime wording; it wasn't observed for this lesson.) The fix, again, is in the storyboard: remove the old connection and connect the new method.

### Summary of connection failures

| Symptom | When | Cause | Fix |
| --- | --- | --- | --- |
| Exception about an undefined key naming an old outlet | Loading the screen | A connection for an outlet that no longer exists | Delete the stale connection in the storyboard |
| `Unexpectedly found nil while implicitly unwrapping an Optional value` on an outlet | First use, often `viewDidLoad()` | Outlet never connected, or controller not created from the storyboard | Connect it, or instantiate from the storyboard |
| "unrecognized selector" | Interacting with the control | A connection to an action method that was renamed or removed | Reconnect to the current method |
| Exception from `UIStoryboard(name:bundle:)` | Creating the storyboard object | No storyboard with that name; Apple documents the description "Could not find a storyboard named 'XXXXXX' in bundle...." | Fix the name or the target membership |
| Exception from `instantiateViewController(identifier:)` | Creating the controller | No view controller has that storyboard ID | Fix the ID in the storyboard or in code |

Every row is the same problem: Interface Builder files refer to code **by strings**, and the compiler can't check strings.

## Loading storyboards in code

You can create view controllers from any storyboard yourself:

```swift ios
import UIKit

final class OnboardingViewController: UIViewController {}

let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
let first = storyboard.instantiateInitialViewController()
let onboarding = storyboard.instantiateViewController(withIdentifier: "Welcome")
let typed: OnboardingViewController = storyboard.instantiateViewController(identifier: "Welcome")
```

- `UIStoryboard(name:bundle:)` finds the file (`nil` means the main bundle).
- `instantiateInitialViewController()` creates the initial controller, returning `UIViewController?`.
- `instantiateViewController(withIdentifier:)` creates the controller with that **storyboard ID**, a string you set on it in Interface Builder. Each call creates a new instance with `init(coder:)`.
- The generic `instantiateViewController(identifier:creator:)` (iOS 13) returns the type you ask for.

### Injecting dependencies into storyboard controllers

Lesson 4 passed a store through `init(store:)`. A storyboard controller is created with `init(coder:)`, so where does the store go? Before iOS 13 the usual answer was a `var store: ExpenseStore!` set after instantiation, which can be forgotten. The `creator` closure fixes that:

```swift ios
import UIKit

final class ExpenseStore {}

final class ExpenseListViewController: UIViewController {
    private let store: ExpenseStore

    init?(coder: NSCoder, store: ExpenseStore) {
        self.store = store
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(coder:store:) through instantiateViewController(identifier:creator:)")
    }
}

let store = ExpenseStore()
let storyboard = UIStoryboard(name: "Expenses", bundle: nil)
let list = storyboard.instantiateViewController(identifier: "ExpenseList") { coder in
    ExpenseListViewController(coder: coder, store: store)
}
```

Apple's rule for the custom initializer: it "must accept an NSCoder parameter and must call the inherited init(coder:) method at some point during its execution. Not doing so is a programmer error." If the closure returns `nil`, UIKit falls back on the default `init(coder:)`, which here stops with a clear message. The controller now can't exist without its store, the same guarantee as the code-only version.

## XIBs

### A view controller with its own XIB

Create `ProfileViewController.xib`, set its File's Owner to `ProfileViewController`, connect the outlets, and create the controller in code:

```swift ios
import UIKit

final class ProfileViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
}

let explicit = ProfileViewController(nibName: "ProfileViewController", bundle: nil)
let byClassName = ProfileViewController()
```

`init(nibName:bundle:)` doesn't load anything yet: "It is loaded the first time the view controller's view is accessed." With `nil` for the name, and without a `loadView()` override, the controller searches for a nib as its `nibName` property describes; according to `loadView()`'s documentation, iOS can find "a nib file in the app bundle with a name based on the view controller's class name", which is why `ProfileViewController()` can work too.

### A reusable view from a XIB

For a custom view designed in a XIB (a badge, a card used on several screens), load it with `UINib`:

```swift ios
import UIKit

final class BadgeView: UIView {
    @IBOutlet weak var titleLabel: UILabel!

    static func loadFromNib() -> BadgeView {
        let nib = UINib(nibName: "BadgeView", bundle: nil)
        guard let view = nib.instantiate(withOwner: nil).first as? BadgeView else {
            fatalError("BadgeView.xib must contain one BadgeView at the top level")
        }
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 8
    }
}
```

`instantiate(withOwner:options:)` "unarchives each object, initializes it, sets its properties to their configured values, and reestablishes any connections", and returns the file's top-level objects. Here the XIB's top-level view has its class set to `BadgeView` and its outlets connected to itself. `awakeFromNib()` is the view's equivalent of `viewDidLoad()`: connections are ready, and Apple requires calling `super`. `UINib` caches the file's contents, so if you create many badges, keep one `UINib` and call `instantiate` repeatedly; Apple recommends this for repeated instantiation, such as cells (Module 24).

## Code, XIBs or storyboards?

All three produce the same objects. The differences are in how a team works with them:

| | Code | XIB per view or screen | Storyboard per flow |
| --- | --- | --- | --- |
| Errors caught by the compiler | Most | Few (connections are strings) | Fewest (also segue and storyboard IDs) |
| Merge conflicts | Ordinary Swift diffs | Small XML files, rare conflicts | Large XML files edited by several people conflict often |
| Code review | Readable diffs | XML diffs are hard to review | Same, at a larger scale |
| Dependency injection | Plain `init` | `init(nibName:bundle:)` plus properties | `init?(coder:…)` with a `creator` closure |
| Seeing the layout | Run it (or use previews) | Visual, immediately | Visual, including the flow between screens |
| Reuse | Subclasses and functions | Good for views | Weak: scenes don't reuse well |

How teams usually decide:

- **Large teams and long-lived apps** often build UI in code, sometimes with XIBs for a few complex views, mainly because of merge conflicts and compile-time checking. Some keep storyboards but split them into one per feature, so two people rarely edit the same file.
- **Small teams, prototypes and simple flows** benefit from seeing screens and transitions at a glance.
- **Existing code** decides more often than taste: you'll maintain storyboards in older apps regardless of what you'd choose.
- **New UI** is increasingly written in SwiftUI (Module 34), which removes the string connections entirely.

You need to read and fix all three. This course builds UIKit screens in code from here on, and uses storyboards where an exercise asks for one.

## Common mistakes

> [!error] Renaming an outlet or action only in code
> The storyboard keeps the old name. Outlets crash on load, actions crash on use. Rename through the storyboard connection too (or delete and reconnect).

> [!error] Using outlets in init
> They're connected after `init(coder:)` returns. Read them from `awakeFromNib()` or `viewDidLoad()` on.

> [!error] Creating a storyboard controller with its plain initializer
> `ProfileViewController()` when the screen lives in a storyboard gives you a controller with no storyboard views and every `!` outlet `nil`. Instantiate it from the storyboard.

> [!error] Overriding loadView() in a storyboard or XIB controller
> Apple: "If you use Interface Builder to create your views and initialize the view controller, you must not override this method." Your override replaces the views the storyboard would load.

> [!error] Forgetting the initial view controller
> With `UISceneStoryboardFile` set, UIKit needs one to install in the window; without it there's nothing to show.

> [!error] Strong outlets to subviews
> They aren't usually leaks, since the hierarchy owns the views anyway, but they keep views alive after you remove them from the hierarchy. Use `weak`, as Apple's examples do.

## Exercises

````exercise
id: m22-l06-e1
type: prediction
prompt: "The same loading model as in the lesson. A teammate deleted bioLabel from the class but not from the storyboard, and added avatarLabel without connecting it. What does it print?"
code: |
  final class Label {
      let name: String
      init(name: String) { self.name = name }
  }

  final class ProfileViewController {
      var titleLabel: Label!
      var avatarLabel: Label!

      func setValue(_ value: Label, forKey key: String) -> Bool {
          switch key {
          case "titleLabel": titleLabel = value
          case "avatarLabel": avatarLabel = value
          default:
              print("undefined key '\(key)'")
              return false
          }
          print("connected \(key)")
          return true
      }
  }

  let savedConnections = [("titleLabel", "Label 1"), ("bioLabel", "Label 2")]
  let controller = ProfileViewController()
  var loaded = true
  for (key, viewName) in savedConnections {
      if !controller.setValue(Label(name: viewName), forKey: key) {
          loaded = false
          break
      }
  }
  print(loaded ? "screen loaded" : "crash while loading")
  print("avatarLabel is \(controller.avatarLabel == nil ? "nil" : "connected")")
output: |
  connected titleLabel
  undefined key 'bioLabel'
  crash while loading
  avatarLabel is nil
hints:
  - "The saved connections come from the storyboard, not from the class."
  - "avatarLabel isn't in savedConnections at all."
solution: |
  ```output
  connected titleLabel
  undefined key 'bioLabel'
  crash while loading
  avatarLabel is nil
  ```

  Two separate bugs. The storyboard still has a connection for `bioLabel`, which the class no longer has: in a real app that's the undefined-key exception while loading. And `avatarLabel` was never connected, so it's `nil`; if the screen had loaded, the first use of `avatarLabel` with `!` would crash. The first bug shows up immediately; the second only when the code touches the outlet.
````

````exercise
id: m22-l06-e2
type: prediction
prompt: "This models a controller whose outlet was never connected. What does it print before it stops?"
code: |
  final class Label {
      var text = ""
  }

  final class SettingsViewController {
      var titleLabel: Label!
      var footerLabel: Label?

      func viewDidLoad() {
          print("loading settings")
          footerLabel?.text = "v1.0"
          print("footer done")
          titleLabel.text = "Settings"
          print("title done")
      }
  }

  let controller = SettingsViewController()
  controller.viewDidLoad()
output: |
  loading settings
  footer done
hints:
  - "Optional chaining on a nil optional does nothing."
  - "An implicitly unwrapped optional is force-unwrapped when you use it."
solution: |
  ```output
  loading settings
  footer done
  ```

  `footerLabel` is a plain optional: `footerLabel?.text = …` quietly does nothing when it's `nil`. `titleLabel` is implicitly unwrapped, so `titleLabel.text = …` unwraps it, finds `nil` and stops the program with "Unexpectedly found nil while implicitly unwrapping an Optional value". That's the trade-off between Apple's `?` outlets and the common `!` outlets: `?` hides a missing connection, `!` crashes on it immediately.
````

````exercise
id: m22-l06-e3
type: comprehension
prompt: When are a storyboard view controller's outlets first safe to use?
choices:
  - text: "In awakeFromNib() and viewDidLoad(), and anywhere after."
    correct: true
    why: "UIKit connects outlets after creating the objects and before calling awakeFromNib() and viewDidLoad()."
  - text: "In init(coder:), right after super.init(coder:)."
    correct: false
    why: "The controller is created first; its views and connections come later."
  - text: "Only in viewDidAppear(_:)."
    correct: false
    why: "They're connected much earlier, before viewDidLoad()."
  - text: "In loadView(), after calling super."
    correct: false
    why: "You must not override loadView() in a controller whose views come from Interface Builder."
solution: |
  **In `awakeFromNib()` and `viewDidLoad()`.** Apple's sequence: create views with `init(coder:)`, connect outlets and actions, call `awakeFromNib()`, assign `view`, call `viewDidLoad()`. In `init(coder:)` the outlets are still `nil`.
````

````exercise
id: m22-l06-e4
type: fill-in
prompt: "Inject a `ReceiptPrinter` into a storyboard view controller with the storyboard ID `Receipt`."
code: |
  final class ReceiptViewController: UIViewController {
      private let printer: ReceiptPrinter

      init?(coder: [[1]], printer: ReceiptPrinter) {
          self.printer = printer
          super.init([[2]]: coder)
      }

      required init?(coder: NSCoder) {
          fatalError("Use init(coder:printer:)")
      }
  }

  let receipt = storyboard.instantiateViewController(identifier: "Receipt") { [[3]] in
      ReceiptViewController(coder: coder, [[4]]: printer)
  }
blanks:
  - id: "1"
    answers: ["NSCoder"]
  - id: "2"
    answers: ["coder"]
  - id: "3"
    answers: ["coder"]
  - id: "4"
    answers: ["printer"]
solution: |
  ```swift ios
  import UIKit

  final class ReceiptPrinter {}

  final class ReceiptViewController: UIViewController {
      private let printer: ReceiptPrinter

      init?(coder: NSCoder, printer: ReceiptPrinter) {
          self.printer = printer
          super.init(coder: coder)
      }

      required init?(coder: NSCoder) {
          fatalError("Use init(coder:printer:)")
      }
  }

  let printer = ReceiptPrinter()
  let storyboard = UIStoryboard(name: "Main", bundle: nil)
  let receipt = storyboard.instantiateViewController(identifier: "Receipt") { coder in
      ReceiptViewController(coder: coder, printer: printer)
  }
  ```

  The custom initializer takes the `NSCoder` UIKit provides and must call `super.init(coder:)`. The closure receives that coder and returns your controller. The `required` initializer still has to exist; it stops with a message if something creates the controller without the printer.
````

````exercise
id: m22-l06-e5
type: solve
prompt: |
  Write a plain-Swift checker for outlet connections, the kind of thing you'd run in a test. Given the outlet names a class declares and the connection keys saved in its storyboard scene, return a list of problems:

  - a key in the storyboard with no outlet: `"stale connection: <key>"` (crashes on load),
  - an outlet with no connection: `"not connected: <name>"` (nil at runtime).

  Report stale connections first, then unconnected outlets, each group sorted alphabetically.

  ```swift
  let problems = auditOutlets(declared: ["titleLabel", "avatarView", "saveButton"],
                              connected: ["titleLabel", "nameLabel", "saveButton", "bioLabel"])
  for problem in problems {
      print(problem)
  }
  ```

  should print:

  ```plaintext
  stale connection: bioLabel
  stale connection: nameLabel
  not connected: avatarView
  ```
starter: |
  func auditOutlets(declared: Set<String>, connected: Set<String>) -> [String] {
      // your code
      return []
  }
hints:
  - "Stale connections are connected minus declared; unconnected outlets are declared minus connected."
  - "Set has subtracting(_:), and sorted() returns an array."
rubric:
  - Uses set differences in both directions.
  - Sorts each group and puts stale connections first.
  - Prints exactly the expected lines.
solution: |
  ```swift
  func auditOutlets(declared: Set<String>, connected: Set<String>) -> [String] {
      let stale = connected.subtracting(declared).sorted().map { "stale connection: \($0)" }
      let missing = declared.subtracting(connected).sorted().map { "not connected: \($0)" }
      return stale + missing
  }

  let problems = auditOutlets(declared: ["titleLabel", "avatarView", "saveButton"],
                              connected: ["titleLabel", "nameLabel", "saveButton", "bioLabel"])
  for problem in problems {
      print(problem)
  }
  ```

  ```output
  stale connection: bioLabel
  stale connection: nameLabel
  not connected: avatarView
  ```

  Each kind of problem is a set difference (Module 7): keys the storyboard has that the class doesn't, and the reverse. Sets have no order, so sorting makes the report stable. A check like this, or a unit test that instantiates every storyboard scene and calls `loadViewIfNeeded()`, catches them before users do.
````

````exercise
id: m22-l06-e6
type: design
prompt: |
  You join a team of eight iOS engineers maintaining a banking app. It has one `Main.storyboard` with 40 scenes. Pull requests regularly have storyboard merge conflicts, and twice this quarter a renamed outlet crashed a screen in QA. Propose what to do over the next few months, in a short paragraph or a list. Consider risk, cost and what to do with new screens versus existing ones.
rubric:
  - Doesn't propose rewriting everything at once.
  - Splits the large storyboard (for example one per feature) or stops adding to it.
  - Chooses a rule for new screens (code, or XIB/small storyboards) and gives a reason.
  - Adds a safety net for connections (a test that loads every scene, or review rules).
  - Mentions dependency injection for storyboard controllers (creator closures) or code.
solution: |
  One reasonable plan:

  1. **Freeze `Main.storyboard`.** No new scenes go into it. New screens are built in code (or a XIB when a complex view benefits from visual layout), which removes merge conflicts for new work and gives compile-time checking.
  2. **Split the existing storyboard by feature** when a feature is being changed anyway: Login, Accounts, Transfers, Settings. A few lines of code that instantiate each feature's storyboard connect the pieces. Smaller files mean fewer people in each one.
  3. **Add a safety net now.** A unit test that instantiates every storyboard ID and calls `loadViewIfNeeded()` catches stale outlets during CI instead of in QA. Make "renamed an outlet or action" a review checklist item.
  4. **Move to creator-based injection** (`instantiateViewController(identifier:creator:)`) when touching a storyboard controller, replacing `var service: Service!` properties that can be forgotten.
  5. **Rewrite a scene in code only when it's being redesigned.** A rewrite of 40 working screens in a banking app is risk without user value.

  The important part is the order: stop the bleeding (freeze, test), then improve incrementally while delivering features.
````

## Summary

- Storyboards hold several view controller scenes and segues; XIBs hold one controller's views or one view. Both are archives that UIKit unarchives with `init(coder:)`.
- Loading order: views created, outlets and actions connected, `awakeFromNib()`, `view` assigned, `viewDidLoad()`. Outlets are `nil` in `init(coder:)`.
- Declare outlets as `@IBOutlet weak var` (Apple uses `?`; many teams use `!`) and actions as `@IBAction func`. Both imply `@objc`.
- Connections are stored by name. A stale outlet crashes on load (undefined key), an unconnected `!` outlet crashes on first use, a stale action crashes on interaction.
- Create storyboard controllers with `UIStoryboard` and storyboard IDs, and inject dependencies with `init?(coder:…)` and `instantiateViewController(identifier:creator:)`. Load reusable views with `UINib`.
- Teams pick code, XIBs or storyboards based on merge conflicts, compile-time checking, review and existing code. You need to work with all three.
