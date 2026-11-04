---
id: m21-l02
title: Entry point, app and scene life cycles
description: How an iOS app starts and what the system tells it afterwards. You trace the launch from @main to the first visible frame, separate the app's process life cycle from each scene's UI life cycle, learn which UIKit and SwiftUI callbacks fire in which order, and decide what work belongs in each one.
module: m21
order: 2
level: intermediate
minutes: 55
codeStatus: reviewed
swiftVersion: "6.4"
prerequisites: [m21-l01]
objectives:
  - Explain what @main does in a UIKit app, a SwiftUI app and a command-line program.
  - List the launch sequence from main() to the first active scene.
  - Tell the app life cycle (process) apart from the scene life cycle (one instance of the UI).
  - Name the four scene states and the UISceneDelegate callback for each transition.
  - Read ScenePhase in SwiftUI and know how it differs at app and view level.
  - Put work in the right callback and know which callbacks you can't rely on.
terms:
  - term: Entry point
    definition: "Where a program starts running. In Swift it's main.swift's top-level code or a type marked @main that provides static func main()."
  - term: UIApplicationMain
    definition: "The UIKit function that creates the UIApplication object and your app delegate, sets up the main run loop and starts processing events. It never returns."
  - term: App delegate
    definition: "Your object conforming to UIApplicationDelegate. It handles process-level events: launch, scene configuration, push registration, termination."
  - term: Scene
    definition: "One instance of your app's UI, represented by a UIWindowScene in UIKit or a Scene such as WindowGroup in SwiftUI. Each scene has its own life cycle."
  - term: Scene delegate
    definition: "Your object conforming to UIWindowSceneDelegate. UIKit tells it when its scene connects, enters the foreground, becomes active, resigns active, enters the background and disconnects."
  - term: ScenePhase
    definition: "SwiftUI's enum for a scene's operational state: active, inactive or background. Read it with @Environment(\\.scenePhase)."
  - term: Suspended
    definition: "A background app whose code isn't running. The system can end a suspended app's process without calling any of your code."
mastery:
  - Write the @main declaration for a UIKit app delegate and for a SwiftUI App, and explain why there can be only one.
  - Recite the launch order from main() through sceneDidBecomeActive(_:).
  - Predict the scene callbacks for opening the app, getting a system alert, going home, coming back and closing it in the app switcher.
  - Decide where to set up a database, refresh visible data, pause playback, hide sensitive data and save drafts.
  - Explain why apps built with the iOS 27 SDK must use the scene life cycle.
resources: [tn3187-scenes, swift-book, apple-documentation]
cards:
  - id: m21-l02-c1
    front: What does UIApplicationMain do, and when does it return?
    back: "It creates the UIApplication object and your app delegate, sets up the main event loop (the main run loop) and starts processing events. It never returns."
  - id: m21-l02-c2
    front: Launch order in a scene-based UIKit app?
    back: "main() → UIApplicationMain → application(_:willFinishLaunchingWithOptions:) → application(_:didFinishLaunchingWithOptions:) → scene(_:willConnectTo:options:) → sceneWillEnterForeground(_:) → sceneDidBecomeActive(_:)."
  - id: m21-l02-c3
    front: Which scene callbacks fire when the user goes to the Home Screen, and when they come back?
    back: "Leaving: sceneWillResignActive(_:) then sceneDidEnterBackground(_:). Coming back: sceneWillEnterForeground(_:) then sceneDidBecomeActive(_:)."
  - id: m21-l02-c4
    front: Why can't you rely on applicationWillTerminate(_:) to save data?
    back: "Apps that support background execution normally move to the background and get suspended; the system can end a suspended app without calling anything. Save when the user finishes an action, and when the scene resigns active or enters the background."
  - id: m21-l02-c5
    front: What happens to apps that don't adopt scenes when built with the iOS 27 SDK?
    back: "They don't launch. TN3187 says the scene life cycle is required in the next major release after iOS 26 when building with the latest SDK."
---

## The idea in one sentence

An iOS app has one **process** that the system launches and may later end, and one or more **scenes**, each a copy of the UI that moves independently between the foreground and the background; UIKit and SwiftUI tell you about both through callbacks, and your job is to do the right amount of work in each.

> [!note] About this lesson's code
> The UIKit and SwiftUI blocks here are marked as fragments: the course's tests run Swift on Linux, where those frameworks don't exist. Method names, signatures and call order were checked against Apple's documentation (UIKit's life-cycle articles, `UISceneDelegate`, `UIApplicationDelegate`, SwiftUI's `App` and `ScenePhase`, TN3187) in November 2026; they weren't run in Xcode. That's why this lesson is marked `reviewed`. The pure-Swift model near the end and the compiler errors quoted were compiled and run with Swift 6.3.

## Where a Swift program starts

Every executable has exactly one entry point. Swift gives you two ways to write it:

1. **`main.swift`**: a file with that name contains top-level code, and that code is the program. Every snippet you've run in this course was compiled as a `main.swift`.
2. **`@main`** on a type: The Swift Programming Language says the type "must provide a `main` type function that doesn't take any arguments and returns `Void`."

```swift illustrative
@main
struct Backup {
    static func main() {
        print("starting backup")
    }
}
```

You can't have both. Put that `@main` type in a file named `main.swift` and Swift 6.3 refuses:

```output
error: 'main' attribute cannot be used in a module that contains top-level code
```

An app never has a `main.swift`. Its entry point is a type marked `@main`, and you don't write `main()` yourself, because the framework protocol already provides it:

```swift illustrative
// UIKit: UIApplicationDelegate provides static func main().
@main
class AppDelegate: UIResponder, UIApplicationDelegate { … }
```

```swift illustrative
// SwiftUI: App provides static func main().
@main
struct WeatherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

UIKit's documentation for `UIApplicationDelegate.main()`: "The system calls the `main()` method to launch your app; you never call it yourself. You can have exactly one entry point in your app, which you mark with the `@main` attribute."

> [!error] error: 'UIApplicationMain' is deprecated
> Older projects (and some of Apple's own sample code, including TN3187's) write `@UIApplicationMain`. SE-0383 deprecated it in Swift 5.10 and made it a hard error in the Swift 6 language mode. Swift 6.3 reports exactly this message, with the note `use '@main' instead`. Replace the attribute with `@main`; nothing else changes.

### What main() does in a UIKit app

The provided `main()` calls `UIApplicationMain(_:_:_:_:)`. Apple's description: it "creates the application object and the application delegate and sets up the event cycle", including "the application's run loop", and begins processing events. Its documentation also says, twice, that despite returning `Int32`, **this function never returns**. From that moment your app is a loop that waits for events and calls your code. Lesson 3 is about that loop.

## The launch sequence

Apple's "About the app launch sequence" lists the steps for a scene-based UIKit app:

1. The system runs `main()`, which `@main` provides.
2. `main()` calls `UIApplicationMain`, which creates `UIApplication` and your app delegate.
3. UIKit calls `application(_:willFinishLaunchingWithOptions:)`.
4. UIKit restores view controller state, if your app uses state restoration.
5. UIKit calls `application(_:didFinishLaunchingWithOptions:)`.
6. UIKit prepares a scene and calls your scene delegate's `scene(_:willConnectTo:options:)`.

Then the scene moves to the foreground: `sceneWillEnterForeground(_:)` (Apple: called "both for newly created and connected scenes" and "invariably followed by" the next one) and `sceneDidBecomeActive(_:)`. Only then is the UI on screen and responding to touches.

Before step 6, if your app delegate implements `application(_:configurationForConnecting:options:)`, UIKit asks it which scene configuration to use; otherwise it uses the scene manifest in the Info.plist.

> [!note] Prewarming
> The system may **prewarm** your app: create the process and load its libraries ahead of time, then suspend it "without allowing any application code to run" until the real launch. Don't use process start time as "the moment the user tapped the icon".

### Keep launch short

Every one of those steps runs on the main thread, before the first frame. Apple's guidance: put app-wide setup (a database layer, configuring services) in `willFinishLaunching`/`didFinishLaunching`; put UI-level work in the scene callbacks; defer anything not needed immediately; and move long-running work off the main thread. Launching to the background (for a location event, say) has a time limit too.

## Two life cycles

| | App life cycle | Scene life cycle |
| --- | --- | --- |
| **What it tracks** | The process | One instance of the UI (a window on iPad, the whole screen on iPhone) |
| **How many** | One | One or more |
| **Who hears about it** | The app delegate (`UIApplicationDelegate`) | Each scene's delegate (`UIWindowSceneDelegate`) |
| **Main events** | Launch, scene configuration, push registration, memory warnings, termination | Connect, foreground/active, inactive, background, disconnect |

Until iOS 12, the app delegate handled everything, because an app had exactly one UI. Scenes arrived in iOS 13 so an iPad app could show several windows, each in a different state. When you adopt scenes, UIKit sends foreground and background events to the scene delegates and **stops** calling the matching app-delegate methods. Apple's docs now mark `applicationDidBecomeActive(_:)`, `applicationWillResignActive(_:)` and `applicationWillEnterForeground(_:)` as deprecated in iOS 26.

> [!version] Scenes are required with the iOS 27 SDK
> TN3187: "In the next major release following iOS 26, UIScene lifecycle will be required when building with the latest SDK; otherwise, your app won't launch." That release is iOS 27. Supporting **multiple** scenes stays optional; adopting the scene life cycle isn't. SwiftUI apps built with `App` and `WindowGroup` are scene-based already.

## Scene states

`UIScene.ActivationState` has four cases, and Apple's life-cycle article adds a fifth condition the enum doesn't name:

| State | Meaning |
| --- | --- |
| `unattached` | The scene exists as a session, but it isn't connected to your app; nothing is on screen |
| `foregroundInactive` | On screen but not receiving events: during launch, during a system alert, while the app switcher is up |
| `foregroundActive` | On screen and receiving events. This is where the user interacts |
| `background` | Off screen, running code briefly |
| *suspended* | In the background and not running any code. Not an enum case, and no callback tells you |

The transitions and their callbacks, from `UISceneDelegate`:

| Transition | Callback |
| --- | --- |
| unattached → foreground inactive | `scene(_:willConnectTo:options:)`, then `sceneWillEnterForeground(_:)` |
| foreground inactive → foreground active | `sceneDidBecomeActive(_:)` |
| foreground active → foreground inactive | `sceneWillResignActive(_:)` |
| foreground inactive → background | `sceneDidEnterBackground(_:)` |
| background → foreground inactive | `sceneWillEnterForeground(_:)` |
| background → suspended | none |
| background → unattached | `sceneDidDisconnect(_:)` |

Read the rows in pairs and the usual paths appear. Opening the app: connect, enter foreground, become active. Going to the Home Screen: resign active, then enter background, because an active scene always passes through inactive on its way out. Coming back: enter foreground, become active. Apple adds that UIKit "can disconnect a background or suspended scene at any time to reclaim its resources."

Things that surprise people:

- **A system alert makes you inactive, not background.** `sceneWillResignActive(_:)` fires; when the alert goes away, `sceneDidBecomeActive(_:)` fires. No foreground/background callbacks.
- **Switching to another app doesn't disconnect your scene.** Apple: "UIKit does not automatically disconnect a scene when the user switches to another app." It disconnects when the user closes the scene in the app switcher, or to reclaim memory.
- **Disconnecting isn't quitting.** The scene goes back to `unattached` and its objects are released, but the session can be reconnected later with saved state.
- **Termination often comes with no warning.** `applicationWillTerminate(_:)` is "generally not called when the user quits the app" for apps that support background execution; it may be called if the app is running in the background, not suspended. A suspended app is ended silently.

## A scene delegate in UIKit

The minimal scene delegate creates a window in code (Module 22 builds a full one):

```swift illustrative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = ForecastViewController()
        window?.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // On screen and interactive: start timers, refresh what's visible.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // About to stop receiving events: pause, save unsaved edits.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Off screen: free memory, hide sensitive data before the snapshot.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Coming back: reload data that may be stale.
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // The scene is being released: drop resources tied to it.
    }
}
```

And the Info.plist entry that tells UIKit to use it, from TN3187:

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
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

`$(PRODUCT_MODULE_NAME).SceneDelegate` is the build-setting substitution from lesson 1: the class name has to include your module's name.

> [!warning] Launch options disappear with scenes
> When you adopt scenes, UIKit still calls `application(_:didFinishLaunchingWithOptions:)` but "no longer provides the launch options dictionary." A URL or quick action that launched the app arrives in the `UIScene.ConnectionOptions` passed to `scene(_:willConnectTo:options:)`.

## What to do in each callback

Apple's life-cycle articles give concrete lists. Condensed:

| Callback | Do | Don't |
| --- | --- | --- |
| `didFinishLaunching` | Set up app-wide services: database layer, crash reporting, push registration | Load the UI's data synchronously; block on the network |
| `scene(_:willConnectTo:options:)` | Build the window and root UI; handle the URL or activity in the connection options | Heavy work: the first frame is waiting |
| `sceneWillEnterForeground` | Reload data that may have changed while away | Show a different screen than the user left |
| `sceneDidBecomeActive` | Start timers, resume paused work, refresh visible views | Block: "Don't run any code that might block your activation method" |
| `sceneWillResignActive` | Pause games and playback, invalidate timers, save unsaved user data | Schedule new work |
| `sceneDidEnterBackground` | Free memory you can rebuild, release the camera and shared resources, hide sensitive data | Keep using shared resources: the system may terminate the app to free them |
| `sceneDidDisconnect` | Release references and resources tied to that scene | Treat it as app termination |

Two of these deserve emphasis:

- **The snapshot.** After `sceneDidEnterBackground(_:)` returns, UIKit takes a picture of the scene for the app switcher. If the screen shows a balance, a password or card numbers, hide them before returning, or they'll sit in that snapshot. Module 42 comes back to this for banking apps.
- **Saving.** Apple's `sceneWillResignActive(_:)` documentation: "never save data solely from this method. Instead, save it at appropriate points from your view controllers, usually in response to user actions." The callbacks are a safety net, not your save strategy.

## The SwiftUI life cycle

A SwiftUI app declares its scenes in `body`, and SwiftUI manages the scene objects for you. You observe state changes through `scenePhase`:

```swift illustrative
import SwiftUI

@main
struct WeatherApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ForecastView()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                // Every scene is in the background: release what you can.
            }
        }
    }
}
```

`ScenePhase` has three cases: `active`, `inactive` and `background`. Where you read it changes what it means:

- **Inside a view**, it's the phase of the scene containing that view.
- **Inside the `App`**, it's an aggregate over all scenes: Apple says the app reports `active` "if any scene is active", `inactive` "when no scenes are active", and when the app enters `background`, "expect the app to terminate soon after."

If you need an app-delegate callback that SwiftUI doesn't offer (the push notification device token is the usual one), add a delegate with `@UIApplicationDelegateAdaptor`, once, in the `App`:

```swift illustrative
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send the token to your server.
    }
}

@main
struct WeatherApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup { ForecastView() }
    }
}
```

Apple's advice on that property wrapper: "Manage an app's life cycle events without using an app delegate whenever possible", preferring `ScenePhase`.

## A model you can run

The UIKit callbacks can't run here, but their order can be modeled in plain Swift. Each step from one state to the next produces the callbacks Apple documents for it:

```swift
enum SceneState {
    case unattached, foregroundInactive, foregroundActive, background
}

func callbacks(from old: SceneState, to new: SceneState) -> [String] {
    switch (old, new) {
    case (.unattached, .foregroundActive):
        return ["scene(_:willConnectTo:options:)", "sceneWillEnterForeground(_:)", "sceneDidBecomeActive(_:)"]
    case (.foregroundActive, .foregroundInactive):
        return ["sceneWillResignActive(_:)"]
    case (.foregroundInactive, .foregroundActive):
        return ["sceneDidBecomeActive(_:)"]
    case (.foregroundActive, .background):
        return ["sceneWillResignActive(_:)", "sceneDidEnterBackground(_:)"]
    case (.background, .foregroundActive):
        return ["sceneWillEnterForeground(_:)", "sceneDidBecomeActive(_:)"]
    case (.background, .unattached):
        return ["sceneDidDisconnect(_:)"]
    default:
        return ["(not modeled)"]
    }
}

let afternoon: [SceneState] = [.unattached, .foregroundActive, .foregroundInactive,
                               .foregroundActive, .background, .foregroundActive]
var current = afternoon[0]
for next in afternoon.dropFirst() {
    print("\(current) → \(next)")
    for name in callbacks(from: current, to: next) {
        print("    \(name)")
    }
    current = next
}
```

```output
unattached → foregroundActive
    scene(_:willConnectTo:options:)
    sceneWillEnterForeground(_:)
    sceneDidBecomeActive(_:)
foregroundActive → foregroundInactive
    sceneWillResignActive(_:)
foregroundInactive → foregroundActive
    sceneDidBecomeActive(_:)
foregroundActive → background
    sceneWillResignActive(_:)
    sceneDidEnterBackground(_:)
background → foregroundActive
    sceneWillEnterForeground(_:)
    sceneDidBecomeActive(_:)
```

That afternoon is: open the app, a system alert appears and is dismissed, go to the Home Screen, come back. Matching on a tuple `(old, new)` lists exactly the transitions the docs describe; anything else falls into `default`. The model leaves out what UIKit adds around these calls (notifications such as `didEnterBackgroundNotification`, the snapshot), and a background launch for a system event, which Apple describes without listing its callbacks.

## Common mistakes

> [!error] Saving only in applicationWillTerminate(_:)
> It's usually not called. A suspended app is ended without warning. Save after user actions, and use `sceneWillResignActive(_:)` and `sceneDidEnterBackground(_:)` as a backstop.

> [!error] Expecting app-delegate life-cycle methods in a scene-based app
> With scenes enabled, UIKit calls `sceneDidEnterBackground(_:)` and does **not** call `applicationDidEnterBackground(_:)`, and the same for the other foreground/background pairs. Code left in the app delegate silently stops running.

> [!error] Reading launchOptions to find the URL that opened the app
> With scenes, the dictionary isn't provided. Read `connectionOptions.urlContexts` in `scene(_:willConnectTo:options:)`, and implement `scene(_:openURLContexts:)` for URLs that arrive while the scene is running.

> [!error] Treating sceneDidDisconnect(_:) as "the app closed"
> It means one scene was released. The process may keep running other scenes, and the disconnected session can come back.

> [!error] Leaving sensitive data on screen when entering the background
> The app-switcher snapshot is taken right after `sceneDidEnterBackground(_:)` returns. Hide it first.

## Exercises

````exercise
id: m21-l02-e1
type: prediction
prompt: "This uses the lesson's model. The user opens the app, presses Home, comes back, presses Home again, and later closes the app in the app switcher. What does it print?"
code: |
  enum SceneState {
      case unattached, foregroundInactive, foregroundActive, background
  }

  func callbacks(from old: SceneState, to new: SceneState) -> [String] {
      switch (old, new) {
      case (.unattached, .foregroundActive):
          return ["willConnect", "willEnterForeground", "didBecomeActive"]
      case (.foregroundActive, .background):
          return ["willResignActive", "didEnterBackground"]
      case (.background, .foregroundActive):
          return ["willEnterForeground", "didBecomeActive"]
      case (.background, .unattached):
          return ["didDisconnect"]
      default:
          return ["?"]
      }
  }

  let steps: [SceneState] = [.unattached, .foregroundActive, .background,
                             .foregroundActive, .background, .unattached]
  var count = 0
  for index in 1..<steps.count {
      let names = callbacks(from: steps[index - 1], to: steps[index])
      count += names.count
      print(names.joined(separator: ", "))
  }
  print("\(count) callbacks")
output: |
  willConnect, willEnterForeground, didBecomeActive
  willResignActive, didEnterBackground
  willEnterForeground, didBecomeActive
  willResignActive, didEnterBackground
  didDisconnect
  10 callbacks
hints:
  - "Six states give five transitions."
  - "Going to the background always passes through resigning active first."
solution: |
  ```output
  willConnect, willEnterForeground, didBecomeActive
  willResignActive, didEnterBackground
  willEnterForeground, didBecomeActive
  willResignActive, didEnterBackground
  didDisconnect
  10 callbacks
  ```

  Five transitions, 3 + 2 + 2 + 2 + 1 = 10 callbacks. Notice there's no `didEnterBackground` before `didDisconnect`: the scene was already in the background. And nothing at all would have fired if the system had ended the suspended process instead of the user closing the scene; that path has no callback.
````

````exercise
id: m21-l02-e2
type: comprehension
prompt: A user is watching a video in your app when a system alert slides down. Which scene callback do you get, and what should the app do?
choices:
  - text: "`sceneWillResignActive(_:)`: pause playback; expect `sceneDidBecomeActive(_:)` when the alert is dismissed."
    correct: true
    why: A temporary interruption makes the scene inactive while it stays on screen.
  - text: "`sceneDidEnterBackground(_:)`: release the video player."
    correct: false
    why: The scene is still visible; it never reaches the background.
  - text: "`sceneDidDisconnect(_:)`: save and tear down the scene."
    correct: false
    why: Disconnection releases the scene. An alert doesn't do that.
  - text: No callback; alerts don't affect the scene.
    correct: false
    why: "Apple's docs say UIKit calls sceneWillResignActive(_:) for temporary interruptions such as system alerts."
solution: |
  **`sceneWillResignActive(_:)`.** The scene goes from `foregroundActive` to `foregroundInactive`: still on screen, not receiving events. Pause the video and timers. When the alert goes away, `sceneDidBecomeActive(_:)` fires and you resume. No foreground/background callbacks are involved.
````

````exercise
id: m21-l02-e3
type: fill-in
prompt: Complete the launch sequence of a scene-based UIKit app.
code: |
  1. main()  →  UIApplication[[1]](_:_:_:_:)
  2. application(_:will[[2]]LaunchingWithOptions:)
  3. application(_:didFinishLaunchingWithOptions:)
  4. scene(_:will[[3]]To:options:)
  5. scene[[4]](_:)
  6. sceneDidBecomeActive(_:)
blanks:
  - id: "1"
    answers: ["Main"]
  - id: "2"
    answers: ["Finish"]
  - id: "3"
    answers: ["Connect"]
  - id: "4"
    answers: ["WillEnterForeground"]
solution: |
  ```plaintext
  1. main()  →  UIApplicationMain(_:_:_:_:)
  2. application(_:willFinishLaunchingWithOptions:)
  3. application(_:didFinishLaunchingWithOptions:)
  4. scene(_:willConnectTo:options:)
  5. sceneWillEnterForeground(_:)
  6. sceneDidBecomeActive(_:)
  ```

  Steps 1–3 belong to the app (the process); 4–6 to the scene. Apple says `sceneWillEnterForeground(_:)` is called for newly connected scenes too, and is always followed by `sceneDidBecomeActive(_:)`.
````

````exercise
id: m21-l02-e4
type: find-errors
prompt: "This scene delegate belongs to a budgeting app. Mark every real problem."
code: |
  class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                 options connectionOptions: UIScene.ConnectionOptions) {
          let data = try? Data(contentsOf: URL(string: "https://example.com/budget.json")!)
          window = UIWindow(windowScene: scene as! UIWindowScene)
          window?.rootViewController = BudgetViewController(data: data)
          window?.makeKeyAndVisible()
      }

      func sceneDidEnterBackground(_ scene: UIScene) {
          // The balance stays visible so the app looks the same when the user returns.
      }

      func sceneDidDisconnect(_ scene: UIScene) {
          saveAllUserData()   // the only place the app saves
      }
  }
choices:
  - text: "It downloads data synchronously in scene(_:willConnectTo:options:), blocking the main thread before the first frame."
    correct: true
  - text: "It leaves the balance on screen when entering the background, so it ends up in the app-switcher snapshot."
    correct: true
  - text: "It saves only in sceneDidDisconnect(_:), which doesn't run when the user switches apps or when a suspended app is ended."
    correct: true
  - text: "A scene delegate must not create its own UIWindow."
    correct: false
    why: "Creating the window in scene(_:willConnectTo:options:) is exactly what Apple's TN3187 example does."
  - text: "sceneDidEnterBackground(_:) is never called in scene-based apps."
    correct: false
    why: It's the scene-based replacement for applicationDidEnterBackground(_:).
rubric:
  - I found the synchronous network load during scene connection.
  - I found the sensitive data left visible for the snapshot.
  - I explained why sceneDidDisconnect(_:) is not a reliable save point.
solution: |
  Three problems:

  1. `Data(contentsOf:)` with a remote URL blocks until the download finishes, on the main thread, before the first frame. Build the UI immediately with cached or empty data and load in the background (Modules 28–30).
  2. The balance should be hidden in `sceneDidEnterBackground(_:)`: UIKit snapshots the scene after that method returns.
  3. `sceneDidDisconnect(_:)` isn't called when the user switches apps, and nothing is called when the system ends a suspended app. Save when the user finishes an edit, and in `sceneWillResignActive(_:)` or `sceneDidEnterBackground(_:)` as a backstop.

  Creating a `UIWindow` in `scene(_:willConnectTo:options:)` is correct. `as!` would be better as `guard let … as? UIWindowScene`, like Apple's example, but it isn't one of the listed problems.
````

````exercise
id: m21-l02-e5
type: solve
prompt: |
  A logging framework records the scene callbacks an app received, using these short names: `connect`, `enterForeground`, `becomeActive`, `resignActive`, `enterBackground`, `disconnect`. Write `isValidSequence(_:)` that returns `true` if a recorded list could have happened according to the scene life cycle in this lesson, starting from `unattached`, and `false` otherwise.

  Use only the transitions the lesson documents: `connect` from unattached (then `enterForeground` must follow), `enterForeground` from connected or background, `becomeActive` from inactive, `resignActive` from active, `enterBackground` from inactive, `disconnect` from background.

  ```swift
  print(isValidSequence(["connect", "enterForeground", "becomeActive"]))
  print(isValidSequence(["connect", "becomeActive"]))
  print(isValidSequence(["connect", "enterForeground", "becomeActive",
                         "resignActive", "enterBackground", "disconnect"]))
  print(isValidSequence(["connect", "enterForeground", "becomeActive", "enterBackground"]))
  ```

  should print `true`, `false`, `true`, `false`.
starter: |
  enum SceneState {
      case unattached, connected, inactive, active, background
  }

  func isValidSequence(_ callbacks: [String]) -> Bool {
      var state = SceneState.unattached
      // your code
      return false
  }
hints:
  - "Walk the list, and for each name check that the current state allows it. If it does, move to the next state; if not, return false."
  - "connected is a short-lived state between connect and enterForeground."
  - "enterForeground leads to inactive; becomeActive to active; resignActive to inactive; enterBackground to background; disconnect to unattached."
rubric:
  - Starts from unattached and processes callbacks in order.
  - Rejects becomeActive straight after connect.
  - Rejects enterBackground straight from active (resignActive must come first).
  - Accepts the documented open, background and close path.
  - Rejects unknown names.
solution: |
  ```swift
  enum SceneState {
      case unattached, connected, inactive, active, background
  }

  func isValidSequence(_ callbacks: [String]) -> Bool {
      var state = SceneState.unattached
      for name in callbacks {
          switch (name, state) {
          case ("connect", .unattached):
              state = .connected
          case ("enterForeground", .connected), ("enterForeground", .background):
              state = .inactive
          case ("becomeActive", .inactive):
              state = .active
          case ("resignActive", .active):
              state = .inactive
          case ("enterBackground", .inactive):
              state = .background
          case ("disconnect", .background):
              state = .unattached
          default:
              return false
          }
      }
      return true
  }

  print(isValidSequence(["connect", "enterForeground", "becomeActive"]))
  print(isValidSequence(["connect", "becomeActive"]))
  print(isValidSequence(["connect", "enterForeground", "becomeActive",
                         "resignActive", "enterBackground", "disconnect"]))
  print(isValidSequence(["connect", "enterForeground", "becomeActive", "enterBackground"]))
  ```

  ```output
  true
  false
  true
  false
  ```

  Matching on the tuple `(name, state)` makes every allowed transition one `case`, and `default` rejects everything else, including unknown names. The fourth list fails because the scene is `active` when `enterBackground` arrives: Apple's docs say it always resigns active first. The model treats the alert case (`resignActive` then `becomeActive`) as valid too, since both transitions are allowed.
````

````exercise
id: m21-l02-e6
type: design
prompt: |
  A podcast app needs to do the following. For each one, choose where it goes (app delegate launch, scene connection, `sceneWillEnterForeground`, `sceneDidBecomeActive`, `sceneWillResignActive`, `sceneDidEnterBackground`, after a user action, or nowhere) and justify it in one sentence.

  1. Open the local database of downloaded episodes.
  2. Refresh the "new episodes" list, which may be hours old.
  3. Save the playback position.
  4. Stop the waveform animation's timer.
  5. Register for push notifications.
  6. Show the episode a deep link points to.
rubric:
  - Database setup at launch (app delegate), since it's app-wide and needed by every scene.
  - Refreshing stale data in sceneWillEnterForeground or sceneDidBecomeActive, without blocking.
  - Saving playback position after user actions or periodically, with resign-active or background as a backstop, not only at termination.
  - Stopping UI timers in sceneWillResignActive.
  - Push registration in the app delegate.
  - Deep links from the scene's connection options (or scene(_:openURLContexts:) when already running).
solution: |
  1. **Launch, in the app delegate.** The database is shared by every scene, so it's app-wide setup. Keep the work small; open the store, don't migrate gigabytes on the main thread.
  2. **`sceneWillEnterForeground(_:)`** (Apple: "load resources from disk and fetch data from the network" when coming from the background). Start the fetch asynchronously and show the old list until it arrives.
  3. **After user actions and periodically**, for example every few seconds while playing and when the user pauses, with `sceneWillResignActive(_:)` as a backstop. Never only at termination.
  4. **`sceneWillResignActive(_:)`**: the docs list invalidating timers there, and it also covers alerts, which don't reach the background.
  5. **App delegate**, at launch. The device token arrives in `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`, which is why SwiftUI apps add `@UIApplicationDelegateAdaptor`.
  6. **Scene connection**: read `connectionOptions.urlContexts` in `scene(_:willConnectTo:options:)` for a cold launch, and implement `scene(_:openURLContexts:)` for a link that arrives while the scene is running.
````

## Summary

- A Swift program has one entry point: `main.swift` or a `@main` type. Apps use `@main` on the app delegate (UIKit) or the `App` (SwiftUI), which provide `main()`. `@UIApplicationMain` is an error in Swift 6 mode.
- `UIApplicationMain` creates the app object and delegate, starts the main run loop, and never returns.
- Launch: `willFinishLaunching` → `didFinishLaunching` → `scene(_:willConnectTo:options:)` → `sceneWillEnterForeground` → `sceneDidBecomeActive`. Keep all of it short.
- The app life cycle is the process; the scene life cycle is each copy of the UI. With scenes, foreground and background events go to scene delegates only. Apps built with the iOS 27 SDK must adopt scenes.
- Scene states: unattached, foreground inactive, foreground active, background; suspended has no callback. Alerts cause resign/become active; going home causes resign active then enter background.
- Pause in resign active, free memory and hide sensitive data in enter background, refresh in enter foreground or become active. Don't count on termination callbacks.
- SwiftUI: read `scenePhase` (`active`, `inactive`, `background`); in the `App` it aggregates all scenes. Use `@UIApplicationDelegateAdaptor` only for what scene phases can't give you.
