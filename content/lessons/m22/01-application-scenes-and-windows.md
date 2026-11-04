---
id: m22-l01
title: UIApplication, scenes and windows
description: The objects that sit between the system and your first screen. You meet UIApplication, the window scene and the window, write the scene delegate that builds the window in code and sets its root view controller, configure the scene manifest in the Info.plist or from the app delegate, and learn why the window has to be stored.
module: m22
order: 1
level: intermediate
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m21-l02, m21-l03]
objectives:
  - Describe what UIApplication, UIWindowScene and UIWindow each do, and how they connect to your scene delegate and root view controller.
  - Write a scene delegate that creates a window for its scene, sets the root view controller and shows it.
  - Configure a scene in the Info.plist scene manifest, with or without a storyboard, and from the app delegate instead.
  - Explain why the scene delegate stores the window in a property.
  - Swap the root view controller at runtime, for example after onboarding.
terms:
  - term: UIApplication
    definition: "The single object that represents your running app. UIApplicationMain creates it; you reach it through UIApplication.shared. It routes incoming events, dispatches control actions and owns your app delegate."
  - term: UIWindowScene
    definition: "A scene that manages one instance of your app's UI and the windows displayed in it. UIKit creates it from your scene configuration; you never create one with an initializer."
  - term: UIWindow
    definition: "An invisible container that hosts your views and dispatches events to them. It shows whatever its root view controller provides."
  - term: Root view controller
    definition: "The view controller assigned to a window's rootViewController property. Its view fills the window, and replacing it replaces the whole screen."
  - term: Scene manifest
    definition: "The UIApplicationSceneManifest dictionary in the Info.plist. It says whether the app supports multiple scenes and lists, per role, the scene class, delegate class and optional storyboard UIKit uses to create each scene."
mastery:
  - Draw the chain from UIApplication to the views on screen, naming who owns whom.
  - Write scene(_:willConnectTo:options:) that builds a window in code without looking it up.
  - Write the scene manifest for a code-only app and say what changes if you use a storyboard.
  - Return a UISceneConfiguration from the app delegate and say when you'd do that.
  - Diagnose a black screen caused by a local window, a missing makeKeyAndVisible() or a wrong delegate class name.
resources: [tn3187-scenes, apple-documentation, swift-book-arc]
cards:
  - id: m22-l01-c1
    front: From UIApplication down to a view on screen, what objects are in the chain?
    back: "UIApplication (one per process) → connected UIWindowScene(s) → the scene's delegate, which stores a UIWindow → the window's rootViewController → that controller's view → its subviews."
  - id: m22-l01-c2
    front: The four steps of building a window in scene(_:willConnectTo:options:)?
    back: "Cast the scene to UIWindowScene (guard let … as?), create UIWindow(windowScene:), set rootViewController, call makeKeyAndVisible(). Store the window in the delegate's window property."
  - id: m22-l01-c3
    front: Two places UIKit can get a scene configuration from?
    back: "The UIApplicationSceneManifest in the Info.plist (UISceneConfigurations → role → array of configurations), or application(_:configurationForConnecting:options:) in the app delegate, which you implement if the plist has no configurations or you want to choose one at runtime."
  - id: m22-l01-c4
    front: What does UIKit do when a scene configuration names a storyboard?
    back: "It creates the window for you and installs the storyboard's initial view controller in it. Without a storyboard, your scene delegate creates the window and root view controller in code."
  - id: m22-l01-c5
    front: Why not size a new window with UIScreen.main.bounds?
    back: "UIWindow(windowScene:) attaches the window to its scene and UIKit sizes it. UIWindow(frame:) and UIScreen.main are deprecated in iOS 26, and UIScreen.main assumes one screen."
---

## The idea in one sentence

One `UIApplication` runs the process, each `UIWindowScene` is one copy of your UI, each scene shows a `UIWindow`, and the window displays whatever its **root view controller** provides; your scene delegate is where you connect those pieces.

> [!note] About this lesson's code
> UIKit doesn't run on Linux, so blocks that import UIKit are type-checked against the iOS SDK (Swift 6 mode, iOS 17 deployment target) on the course's macOS runner but not run. The pure-Swift models of the same ideas were compiled and run. API names, availability and quotes come from Apple's UIKit documentation, read in November 2026.

## The chain from the process to the screen

Module 21 followed the launch sequence until `sceneDidBecomeActive(_:)`. Here's the object graph that exists at that moment in a scene-based UIKit app:

```plaintext
UIApplication.shared                 one per process
├── delegate: AppDelegate            process events (launch, push token, scene configuration)
└── connectedScenes
    └── UIWindowScene                one copy of the UI
        ├── delegate: SceneDelegate  scene events, owns the window
        └── windows
            └── UIWindow             invisible container, routes events
                └── rootViewController: InboxViewController
                    └── view         the root view
                        ├── UILabel
                        └── UIButton
```

| Object | Created by | How many | Your job |
| --- | --- | --- | --- |
| `UIApplication` | `UIApplicationMain` | Exactly one | Almost nothing; don't subclass it |
| App delegate | `UIApplicationMain` | One | Process-level setup |
| `UIWindowScene` | UIKit, from your scene configuration | One per open copy of the UI | Never create one |
| Scene delegate | UIKit, one per scene | One per scene | Build the window and root UI |
| `UIWindow` | You (or UIKit, if you use a storyboard) | Usually one per scene | Create, configure, store |
| Root view controller | You | One per window at a time | Everything the user sees |

### UIApplication

Apple calls it "the centralized point of control and coordination for apps running in iOS". Every app has exactly one, created by `UIApplicationMain` and reachable as `UIApplication.shared`. It handles "the initial routing of incoming user events" and "dispatches action messages forwarded to it by control objects" (lesson 5 follows those). It also gives you process-wide services: opening URLs, registering for remote notifications, asking for extra background time.

You rarely touch it. Apple's subclassing note: "Most apps don't need to subclass UIApplication. Instead, use an app delegate."

### UIWindowScene

"A scene that manages one instance of your app's UI, including one or more windows that you display from that scene." The documentation is direct about creating one: "Don't create window scene objects directly." You tell UIKit which classes to use, and UIKit creates the scene when the user (or the system) opens a copy of your UI. On iPhone that's one scene at a time; on iPad, with multiple-scene support turned on, the user can open several side by side.

### UIWindow

"The backdrop for your app's user interface and the object that dispatches events to your views." A window draws nothing itself. Apple: "a window hosts one or more views, which are managed by the window's root view controller." Setting `rootViewController` "installs the view controller's view as the content view of the window", sized to track the window.

Most apps have one window per scene. The window that receives keyboard and other non-touch events is the **key window**; `makeKeyAndVisible()` shows a window and makes it key.

## Building the window in the scene delegate

When your scene configuration has no storyboard, nothing appears on screen until your scene delegate builds the window. This is the whole job:

```swift ios
import UIKit

final class InboxViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Inbox"
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = InboxViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

Line by line:

- `final class SceneDelegate: UIResponder, UIWindowSceneDelegate`. The delegate inherits from `UIResponder` so it can take part in the responder chain (lesson 5), and adopts `UIWindowSceneDelegate`, whose `window` property "is the main window associated with the scene". Every UIKit class here is `@MainActor`, so this class is too; Module 21 lesson 3 explained what that means.
- `var window: UIWindow?` satisfies that optional protocol requirement and, more importantly, **keeps the window alive**. More on that below.
- `scene(_:willConnectTo:options:)` is called "when your app creates or restores an instance of your user interface". The parameter is typed `UIScene`, the general class.
- `guard let windowScene = scene as? UIWindowScene` narrows it. For the app's main role it is always a window scene, but a conditional cast costs nothing and is what Apple's own examples do.
- `UIWindow(windowScene:)` "creates the new window and automatically associates it with the specified scene". You don't pass a size: the scene decides it.
- `window.rootViewController = InboxViewController()` decides the first screen. Creating the controller doesn't create its views yet; lesson 2 covers when that happens.
- `self.window = window` stores it.
- `makeKeyAndVisible()` shows the window and makes it the key window. Without this call the window exists, but it stays hidden.

> [!warning] Don't size windows with UIScreen.main
> Older code writes `UIWindow(frame: UIScreen.main.bounds)` and then sets `windowScene`. Both `UIWindow(frame:)` and `UIScreen.main` are deprecated in iOS 26. Apple's note on `UIScreen.main`: "Use a UIScreen instance found through context instead", such as the window scene's `screen`. Use `UIWindow(windowScene:)`.

### Why the window must be stored

The scene delegate builds the window inside a method. If the only reference to it is a local constant, ARC (Module 13) releases it when nothing else holds a strong reference. UIKit's documentation doesn't promise that the scene keeps a strong reference to a window you create; Apple's templates and examples always store it in the delegate's `window` property, and the usual symptom of a window held only by a local constant is a black screen. Store it.

This model shows the ARC side of the problem with plain classes:

```swift
final class Window {
    let name: String

    init(name: String) {
        self.name = name
        print("\(name) created")
    }

    deinit {
        print("\(name) released")
    }
}

final class SceneDelegate {
    var window: Window?

    func connectWithLocalWindow() {
        let window = Window(name: "local window")
        print("showing \(window.name)")
    }

    func connectStoringWindow() {
        window = Window(name: "stored window")
        print("showing \(window?.name ?? "nothing")")
    }
}

let delegate = SceneDelegate()
delegate.connectWithLocalWindow()
delegate.connectStoringWindow()
print("both methods returned")
```

```output
local window created
showing local window
local window released
stored window created
showing stored window
both methods returned
```

The local window is released before the method even returns. The stored one outlives the method because the delegate holds it, and the scene holds the delegate.

## Telling UIKit which delegate to use

UIKit creates your scene delegate, so it needs the class name. There are two ways to give it.

### In the Info.plist

The scene manifest (`UIApplicationSceneManifest`) is a dictionary in the Info.plist. Its presence, in Apple's words, "indicates that the app supports scenes and doesn't use an app delegate object to manage transitions to and from the foreground or background". For a code-only app with one window:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneClassName</key>
                <string>UIWindowScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

Reading it from the inside out:

- `UIWindowSceneSessionRoleApplication` is the role: scenes for "content on the device's main screen" that respond to interaction. Its value is an array; "the first item in the array represents the default scene configuration for this role."
- `UISceneConfigurationName` is a name you choose, used to identify the configuration.
- `UISceneClassName` is the scene class: `UIWindowScene` (Apple: "Don't specify UIScene").
- `UISceneDelegateClassName` must name your class including its module, which is why it uses the build setting `$(PRODUCT_MODULE_NAME)` (Module 21, lesson 1).
- `UIApplicationSupportsMultipleScenes` set to `false` means one scene at a time. Turning it on is extra work: "if your scenes use the same shared data structures, they must coordinate access to those structures."

Add `UISceneStoryboardFile` (the storyboard name without `.storyboard`) and the behavior changes. Apple: "UIKit creates a window for your scene automatically and installs the initial view controller from your storyboard in it." Your scene delegate then only needs the `window` property; it doesn't build anything. Lesson 6 covers storyboards.

### From the app delegate

If the plist has no `UISceneConfigurations`, you must implement `application(_:configurationForConnecting:options:)`. You can also implement it to choose a configuration at runtime, for example a different one for a scene opened from a notification. UIKit calls it "shortly before creating a new scene":

```swift ios
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration",
                                                 sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
```

Here the class is a real type (`SceneDelegate.self`), so there's no string to misspell. In a real project the app delegate also carries `@main`, which the type-check can't include; Module 21 lesson 2 showed that form.

## Replacing the root view controller

The root view controller isn't fixed. Assigning a new one swaps the whole screen; Apple: "If the window has an existing view hierarchy, the old views are removed before the new ones are installed." That's the usual way to move from onboarding or login to the main app, where the user should never go back with a back button:

```swift ios
import UIKit

final class OnboardingViewController: UIViewController {}
final class HomeViewController: UIViewController {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let finished = UserDefaults.standard.bool(forKey: "hasFinishedOnboarding")
        window.rootViewController = finished ? HomeViewController() : OnboardingViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    func showHome() {
        UserDefaults.standard.set(true, forKey: "hasFinishedOnboarding")
        window?.rootViewController = HomeViewController()
    }
}
```

`UserDefaults` is a small key-value store for preferences; Module 31 covers persistence properly. The old onboarding controller is released once nothing else references it.

## Finding the window and scene from a view

Code inside a view controller sometimes needs its scene, for example to read its size or open a second window. Don't reach for app-wide lists: `UIApplication.shared.windows` is deprecated since iOS 15 and `keyWindow` since iOS 13, because with several scenes there's no single "the window". Ask your own view instead:

```swift ios
import UIKit

final class ReceiptViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let scene = view.window?.windowScene {
            print("Showing in a scene with \(scene.windows.count) window(s)")
        }
    }
}
```

`view.window` is `nil` until the view is in a window, which is why this runs in `viewDidAppear(_:)` and not when the controller is created. Lesson 2 explains that timing. `UIApplication.shared.connectedScenes` still exists for app-wide questions; it returns a `Set<UIScene>`, possibly with several entries.

## Common mistakes

> [!error] A black screen with a local window
> `let window = UIWindow(windowScene: windowScene)` without `self.window = window`. The method returns, nothing keeps the window, and you see black. Store it in the delegate's `window` property.

> [!error] A black screen without makeKeyAndVisible()
> A new window is hidden. Call `makeKeyAndVisible()` (or set `isHidden = false` if you only want to show it) after setting the root view controller.

> [!error] The scene delegate class name has no module
> `UISceneDelegateClassName` set to `SceneDelegate` instead of `$(PRODUCT_MODULE_NAME).SceneDelegate`. UIKit looks up the class by its full name, can't find it, and none of your scene code runs. Copy the build-setting form, or return the configuration from the app delegate with `SceneDelegate.self`.

> [!error] Creating a UIWindowScene yourself
> There's no supported way to do it; Apple says not to. UIKit creates scenes from your configuration. To open another one at runtime, call `activateSceneSession(for:errorHandler:)` on `UIApplication` (iOS 17; the older `requestSceneSessionActivation(_:userActivity:options:errorHandler:)` is deprecated in iOS 27).

> [!error] Looking up "the" window through UIApplication
> `UIApplication.shared.windows.first` and `keyWindow` are deprecated and wrong with more than one scene. Use `view.window`, or the scene the delegate method received.

## Exercises

````exercise
id: m22-l01-e1
type: prediction
prompt: "This models the object graph of an iPad app with two scenes open. Then the user finishes onboarding in the second scene. What does it print?"
code: |
  final class ViewController {
      let title: String
      init(title: String) { self.title = title }
  }

  final class Window {
      var rootViewController: ViewController?
  }

  final class WindowScene {
      let name: String
      var windows: [Window] = []
      init(name: String) { self.name = name }
  }

  func describe(_ scenes: [WindowScene]) {
      for scene in scenes {
          for window in scene.windows {
              print("\(scene.name) → \(window.rootViewController?.title ?? "empty")")
          }
      }
  }

  let left = WindowScene(name: "left")
  let right = WindowScene(name: "right")
  let leftWindow = Window()
  leftWindow.rootViewController = ViewController(title: "Inbox")
  left.windows.append(leftWindow)
  let rightWindow = Window()
  rightWindow.rootViewController = ViewController(title: "Onboarding")
  right.windows.append(rightWindow)
  right.windows.append(Window())

  describe([left, right])
  rightWindow.rootViewController = ViewController(title: "Inbox")
  print("--")
  describe([left, right])
output: |
  left → Inbox
  right → Onboarding
  right → empty
  --
  left → Inbox
  right → Inbox
  right → empty
hints:
  - "The right scene has two windows, and one of them never got a root view controller."
  - "Replacing a root view controller changes that window only."
solution: |
  ```output
  left → Inbox
  right → Onboarding
  right → empty
  --
  left → Inbox
  right → Inbox
  right → empty
  ```

  Each scene owns its own windows, and each window has at most one root view controller. Replacing the right window's root changes only that line; the left scene is a separate copy of the UI and doesn't notice. The second window in the right scene has no root view controller, so in a real app it would show nothing at all.
````

````exercise
id: m22-l01-e2
type: comprehension
prompt: Which statement about UIApplication is correct?
choices:
  - text: "There's exactly one per process. UIApplicationMain creates it, you reach it through UIApplication.shared, and it routes events and control actions."
    correct: true
    why: That's how Apple's documentation describes it.
  - text: "You create one per scene in scene(_:willConnectTo:options:)."
    correct: false
    why: "Scenes are created by UIKit; UIApplication is a singleton created once at launch."
  - text: "Most apps subclass it to handle their life cycle."
    correct: false
    why: "Apple: most apps don't need to subclass UIApplication; use an app delegate (and scene delegates) instead."
  - text: "It owns the window directly, so UIApplication.shared.windows.first is the right way to find your window."
    correct: false
    why: "Windows belong to scenes. That property is deprecated since iOS 15 and ambiguous with several scenes."
solution: |
  **The first option.** `UIApplication` is created once by `UIApplicationMain` and lives as long as the process. It routes incoming events, dispatches action messages from controls and offers process-wide services. Your code mostly talks to delegates instead: the app delegate for process events and one scene delegate per scene for the UI.
````

````exercise
id: m22-l01-e3
type: fill-in
prompt: Complete the scene delegate so it shows `SettingsViewController` in a window it builds itself.
code: |
  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? [[1]] else { return }
          let window = UIWindow([[2]]: windowScene)
          window.[[3]] = SettingsViewController()
          self.window = window
          window.[[4]]()
      }
  }
blanks:
  - id: "1"
    answers: ["UIWindowScene"]
  - id: "2"
    answers: ["windowScene"]
  - id: "3"
    answers: ["rootViewController"]
  - id: "4"
    answers: ["makeKeyAndVisible"]
solution: |
  ```swift ios
  import UIKit

  final class SettingsViewController: UIViewController {}

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? UIWindowScene else { return }
          let window = UIWindow(windowScene: windowScene)
          window.rootViewController = SettingsViewController()
          self.window = window
          window.makeKeyAndVisible()
      }
  }
  ```

  Cast to `UIWindowScene`, attach the window with `UIWindow(windowScene:)`, give it a root view controller, store it, and show it with `makeKeyAndVisible()`.
````

````exercise
id: m22-l01-e4
type: find-errors
prompt: "After this change the app launches to a black screen. The Info.plist has `UISceneDelegateClassName` set to `$(PRODUCT_MODULE_NAME).SceneDelegate` and no storyboard. Mark every real problem."
code: |
  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? UIWindowScene else { return }
          let window = UIWindow(windowScene: windowScene)
          window.rootViewController = LoginViewController()
      }
  }
choices:
  - text: The window is never stored in self.window, so nothing keeps it alive after the method returns.
    correct: true
  - text: makeKeyAndVisible() is never called, so the window stays hidden.
    correct: true
  - text: "The cast should be scene as! UIWindowScene; guard let … as? never succeeds."
    correct: false
    why: "Conditional casting is fine and is what Apple's examples do. For the app's main role the cast succeeds."
  - text: "UIWindow(windowScene:) creates a zero-size window; it needs UIScreen.main.bounds."
    correct: false
    why: "The scene sizes the window. UIScreen.main and UIWindow(frame:) are deprecated in iOS 26."
rubric:
  - I found that the window isn't stored.
  - I found the missing makeKeyAndVisible().
  - I didn't flag the conditional cast or the initializer.
solution: |
  Two problems, either of which is enough for a black screen:

  1. The window lives in a local constant. Add `self.window = window`.
  2. A new window is hidden until you call `makeKeyAndVisible()`.

  ```swift ios
  import UIKit

  final class LoginViewController: UIViewController {}

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? UIWindowScene else { return }
          let window = UIWindow(windowScene: windowScene)
          window.rootViewController = LoginViewController()
          self.window = window
          window.makeKeyAndVisible()
      }
  }
  ```
````

````exercise
id: m22-l01-e5
type: solve
prompt: |
  A notes app shows `LockViewController` while the app is locked and `NotesViewController` after the user unlocks it. Write a scene delegate that:

  1. Builds the window in code with `LockViewController` as the root.
  2. Has a method `unlock()` that replaces the root with `NotesViewController`.
  3. Puts `LockViewController` back when the scene enters the background, so the notes are covered before the app-switcher snapshot (Module 21, lesson 2).

  Assume both controllers have plain `init()` initializers.
starter: |
  import UIKit

  final class LockViewController: UIViewController {}
  final class NotesViewController: UIViewController {}

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      // your code
  }
hints:
  - "scene(_:willConnectTo:options:) builds the window; the other two only assign window?.rootViewController."
  - "The snapshot is taken after sceneDidEnterBackground(_:) returns."
rubric:
  - Casts to UIWindowScene and creates the window with UIWindow(windowScene:).
  - Stores the window and calls makeKeyAndVisible().
  - unlock() replaces the root view controller instead of creating a new window.
  - sceneDidEnterBackground(_:) sets LockViewController as the root.
solution: |
  ```swift ios
  import UIKit

  final class LockViewController: UIViewController {}
  final class NotesViewController: UIViewController {}

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          guard let windowScene = scene as? UIWindowScene else { return }
          let window = UIWindow(windowScene: windowScene)
          window.rootViewController = LockViewController()
          self.window = window
          window.makeKeyAndVisible()
      }

      func unlock() {
          window?.rootViewController = NotesViewController()
      }

      func sceneDidEnterBackground(_ scene: UIScene) {
          window?.rootViewController = LockViewController()
      }
  }
  ```

  One window for the life of the scene; only its content changes. Swapping the root replaces the whole view hierarchy, so the notes' views are gone before UIKit takes the snapshot. A real app would also wipe any unlocked state it keeps in memory. Module 42 returns to protecting sensitive screens.
````

````exercise
id: m22-l01-e6
type: explain
prompt: "A teammate asks why the scene manifest says `$(PRODUCT_MODULE_NAME).SceneDelegate` instead of just `SceneDelegate`, and whether they could avoid the string entirely. Answer in a few sentences."
code: |
  <key>UISceneDelegateClassName</key>
  <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
rubric:
  - Explains that UIKit finds the class by its full name, which includes the Swift module.
  - Explains that $(PRODUCT_MODULE_NAME) is substituted at build time, so renaming the target doesn't break it.
  - Mentions application(_:configurationForConnecting:options:) with delegateClass = SceneDelegate.self as the alternative that the compiler checks.
solution: |
  UIKit creates the scene delegate from a class name it reads at runtime, and a Swift class's full name includes its module, so `SceneDelegate` alone doesn't match `MyApp.SceneDelegate`. `$(PRODUCT_MODULE_NAME)` is a build setting that Xcode substitutes when it processes the Info.plist (Module 21, lesson 1), so the value stays right if the target is renamed.

  To avoid the string, remove the configurations from the plist and implement `application(_:configurationForConnecting:options:)` in the app delegate, setting `configuration.delegateClass = SceneDelegate.self`. Then a typo is a compile error instead of a black screen.
````

## Summary

- `UIApplication` is the one app object: created by `UIApplicationMain`, reached through `shared`, routing events and control actions. Don't subclass it.
- A `UIWindowScene` is one copy of your UI. UIKit creates it from your scene configuration; you never do.
- A `UIWindow` hosts views and dispatches events; it shows its `rootViewController`'s view.
- In code-only apps, `scene(_:willConnectTo:options:)` casts to `UIWindowScene`, creates `UIWindow(windowScene:)`, sets the root view controller, stores the window and calls `makeKeyAndVisible()`.
- The scene manifest in the Info.plist names the scene class, the delegate class (with its module) and optionally a storyboard; with a storyboard, UIKit builds the window for you. The app delegate can return a `UISceneConfiguration` instead.
- Replacing `rootViewController` swaps the whole screen. Find the window from `view.window`, not from deprecated app-wide properties.
