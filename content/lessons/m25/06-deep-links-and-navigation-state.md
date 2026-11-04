---
id: m25-l06
title: Deep links and navigation state
description: How a link opens the right screen. You compare custom URL schemes with universal links, find where a scene-based app receives each kind at launch and while running, parse a URL into a route enum in plain Swift, rebuild the tab and navigation stack for that route in one transition, and save the current route so a scene comes back where the user left it.
module: m25
order: 6
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l05]
objectives:
  - Explain the difference between a custom URL scheme and a universal link, and why Apple recommends universal links.
  - Receive URLs and universal links in a scene delegate, both when the app launches and when it's already running.
  - Parse a URL into a route enum with URLComponents, rejecting anything malformed or unexpected.
  - Turn a route into a tab and a navigation stack, and apply it with one setViewControllers(_:animated:) call.
  - Save and restore a scene's navigation state with stateRestorationActivity(for:) and the session's stateRestorationActivity.
terms:
  - term: Deep link
    definition: "A link that opens a specific place inside an app (a note, a search, a settings page) rather than just launching it."
  - term: Custom URL scheme
    definition: "A scheme such as notesapp:// that an app registers in its Info.plist (CFBundleURLTypes). Any app can register the same scheme; Apple says which app then opens it is undefined."
  - term: Universal link
    definition: "An ordinary https link to your website that the system opens in your app instead, after verifying an apple-app-site-association file on the domain against the app's associated domains entitlement. Without the app installed, it opens in the browser."
  - term: Route
    definition: "A value, usually an enum with associated values, that names a destination in the app independently of how it was requested: a URL, a notification, a restored state or a button."
  - term: State restoration
    definition: "Bringing a scene back to where the user left it after the system terminated the app. Scene-based apps return an NSUserActivity from stateRestorationActivity(for:) and read it back from UISceneSession.stateRestorationActivity."
mastery:
  - Write a scene delegate that sends URLs and universal links to one handler from all four entry points.
  - Write route(from:) that accepts both a custom scheme and an https link and rejects malformed input.
  - Write destination(for:) that maps every route to a tab and a stack of screens, and test it in a terminal.
  - Rebuild a tab's stack for a route after dismissing anything presented.
  - Encode the current route in an NSUserActivity and restore it at the next connection.
resources: [uikit-uiwindowscene, uikit-specifying-scenes, swift-book-enumerations, apple-documentation]
cards:
  - id: m25-l06-c1
    front: Where does a scene-based app receive a custom-scheme URL?
    back: "If the app isn't running, in scene(_:willConnectTo:options:) through connectionOptions.urlContexts. If it's running or suspended, in scene(_:openURLContexts:). Each UIOpenURLContext has the url."
  - id: m25-l06-c2
    front: Where does a scene-based app receive a universal link?
    back: "As an NSUserActivity of type NSUserActivityTypeBrowsingWeb with the URL in webpageURL: in connectionOptions.userActivities at launch, or in scene(_:continue:) while running."
  - id: m25-l06-c3
    front: Custom URL scheme or universal link?
    back: "Apple: custom schemes are an acceptable form of deep linking, but universal links are strongly recommended. A universal link is a normal https URL verified against your domain; any app can claim a custom scheme."
  - id: m25-l06-c4
    front: Why parse a URL into a route enum instead of acting on it directly?
    back: "The parser validates everything in one testable pure function, malformed links become nil, and the rest of the app only handles a closed set of known destinations. The same route can also come from notifications or restored state."
  - id: m25-l06-c5
    front: Which APIs save and restore a scene's navigation state?
    back: "UISceneDelegate.stateRestorationActivity(for:) returns an NSUserActivity describing the current state; at the next connection UISceneSession.stateRestorationActivity contains a copy. Store an identifier (such as a route URL), not app data."
---

## The idea in one sentence

A deep link is a URL that names a place in your app; you turn it into a route value in plain Swift, reject what you don't recognize, and then rebuild the tabs and stacks so that place is on screen with a sensible back button.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's articles "Defining a custom URL scheme for your app", "Allowing apps and websites to link to your content", "Supporting universal links in your app", "Supporting associated domains", "Restoring your app's state" and the reference pages for `UISceneDelegate`, `UIScene.ConnectionOptions` and `UISceneSession`, read in November 2026. The project settings (URL types, the Associated Domains capability) and the link behavior weren't checked in Xcode or on a device. The route parsing, the stack mapping and the round trip were compiled and run.

## Two kinds of links

| | Custom URL scheme | Universal link |
| --- | --- | --- |
| Looks like | `notesapp://note/42` | `https://notes.example.com/note/42` |
| Set up | A URL type (`CFBundleURLTypes`) in Info.plist | The Associated Domains capability (`applinks:` entries in `com.apple.developer.associated-domains`) plus an `apple-app-site-association` file on your web server |
| Who can claim it | Any app. "If multiple apps register the same scheme, the app the system targets is undefined." | Only your app, after the system verifies the file on your domain |
| App not installed | The link fails | It opens your website in the browser |
| Arrives as | A URL | An `NSUserActivity` of type `NSUserActivityTypeBrowsingWeb` |

Apple's position, from the custom-scheme article: "While custom URL schemes are an acceptable form of deep linking, universal links are strongly recommended." A universal link is a normal web address: one link works on the web and in the app, and nobody else can intercept it.

Both articles carry the same security warning: links "offer a potential attack vector into your app, so make sure to validate all URL parameters and discard any malformed URLs. In addition, limit the available actions to those that don't risk the user's data. For example, don't allow other apps to directly delete content or access sensitive information about the user." A link should **navigate**, never act. "Delete note 42" is a screen with a button, not a URL.

One detail from the universal links article worth knowing before you test: when someone browsing your site in Safari taps a universal link to the same domain, "the system opens that link in Safari, respecting the user's most likely intent to continue within the browser."

## Where links arrive

With scenes, there are four entry points. Apple's articles describe them this way: if the app isn't running, the system "delivers the URL to the `scene(_:willConnectTo:options:)` delegate method after launch, and to `scene(_:openURLContexts:)` when your app opens a URL while running or suspended in memory." Universal links go to `scene(_:willConnectTo:options:)` at launch and to `scene(_:continue:)` while running.

| App state | Custom scheme | Universal link |
| --- | --- | --- |
| Not running | `connectionOptions.urlContexts` | `connectionOptions.userActivities` |
| Running or suspended | `scene(_:openURLContexts:)` | `scene(_:continue:)` |

Send all four to one place:

```swift ios
import UIKit

@MainActor
final class LinkHandler {
    func open(_ url: URL) {
        print("open \(url.absoluteString)")
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let linkHandler = LinkHandler()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UITabBarController()
        self.window = window
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            linkHandler.open(url)
        } else if let url = webURL(in: connectionOptions.userActivities.first) {
            linkHandler.open(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        linkHandler.open(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = webURL(in: userActivity) else { return }
        linkHandler.open(url)
    }

    private func webURL(in activity: NSUserActivity?) -> URL? {
        guard let activity, activity.activityType == NSUserActivityTypeBrowsingWeb else { return nil }
        return activity.webpageURL
    }
}
```

- The normal interface is built **first**, then the link is applied on top of it. A link that turns out to be invalid then leaves the user on the normal first screen instead of a blank one.
- `urlContexts` is a `Set<UIOpenURLContext>`; "an empty set indicates that there are no URLs to open." Each context has `url` and `options`, where `options.sourceApplication` is "the bundle ID of the app that originated the request". `UIOpenURLContext` objects come from the system: "Don't create `UIOpenURLContext` objects yourself."
- For universal links, check `activityType == NSUserActivityTypeBrowsingWeb` and read `webpageURL`. Apple: for this type, "the `webpageURL` property contains the http or https URL associated with the activity."
- `scene(_:continue:)` also receives Handoff activities, which is another reason to check the type.

Without scenes, the older `application(_:open:options:)` and `application(_:continue:restorationHandler:)` app delegate methods received these. With the iOS 27 SDK a UIKit app must use scenes (Module 22), so the scene methods are the ones that matter.

> [!note] Trying a link in the simulator
> A link typed in Notes or Safari on the simulator opens it like a tap would. `xcrun simctl openurl booted notesapp://note/42` from a Mac terminal does the same; that command wasn't run for this lesson.

## From URL to route

Don't scatter `if url.host == ...` checks through view controllers. Parse once, into a type that can only hold valid destinations:

```swift
import Foundation

enum Route: Equatable {
    case inbox
    case note(id: Int)
    case folder(name: String)
    case search(query: String)
    case settings
}

func route(from url: URL) -> Route? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    let pathParts = components.path.split(separator: "/").map(String.init)
    let parts: [String]
    switch components.scheme?.lowercased() {
    case "notesapp":
        guard let host = components.host, !host.isEmpty else { return nil }
        parts = [host.lowercased()] + pathParts
    case "https":
        guard components.host?.lowercased() == "notes.example.com" else { return nil }
        parts = pathParts
    default:
        return nil
    }

    switch parts.first {
    case "inbox" where parts.count == 1:
        return .inbox
    case "note" where parts.count == 2:
        guard let id = Int(parts[1]), id > 0 else { return nil }
        return .note(id: id)
    case "folder" where parts.count == 2:
        return .folder(name: parts[1])
    case "search" where parts.count == 1:
        let query = components.queryItems?.first(where: { $0.name == "q" })?.value ?? ""
        return query.isEmpty ? nil : .search(query: query)
    case "settings" where parts.count == 1:
        return .settings
    default:
        return nil
    }
}

let links = [
    "notesapp://inbox",
    "notesapp://note/42",
    "https://notes.example.com/note/42",
    "notesapp://folder/Work%20Notes",
    "notesapp://search?q=milk",
    "NotesApp://Settings",
    "notesapp://note/abc",
    "notesapp://note/-3",
    "notesapp://note",
    "notesapp://search?q=",
    "https://evil.example.com/note/1",
    "ftp://notes.example.com/note/1",
    "notesapp://delete-everything",
]
for link in links {
    if let url = URL(string: link), let route = route(from: url) {
        print(link, "->", route)
    } else {
        print(link, "-> rejected")
    }
}
```

```output
notesapp://inbox -> inbox
notesapp://note/42 -> note(id: 42)
https://notes.example.com/note/42 -> note(id: 42)
notesapp://folder/Work%20Notes -> folder(name: "Work Notes")
notesapp://search?q=milk -> search(query: "milk")
NotesApp://Settings -> settings
notesapp://note/abc -> rejected
notesapp://note/-3 -> rejected
notesapp://note -> rejected
notesapp://search?q= -> rejected
https://evil.example.com/note/1 -> rejected
ftp://notes.example.com/note/1 -> rejected
notesapp://delete-everything -> rejected
```

How it works:

- **`URLComponents`** splits the URL into scheme, host, path and query. Apple's articles use it ("To ensure the URL is parsed correctly, use NSURLComponents APIs"), and `path` comes back percent-decoded, which is why `Work%20Notes` becomes `"Work Notes"`.
- **Both forms map to the same parts.** In `notesapp://note/42`, `note` is the **host** and `/42` the path; in `https://notes.example.com/note/42`, the host is the domain and both pieces are in the path. The scheme `switch` turns each into `["note", "42"]`.
- **Only your domain**. An https URL for any other host is rejected, and so is any other scheme.
- **Case**: schemes and hosts aren't case-sensitive in URLs, so they're lowercased before comparing. Path pieces such as folder names are kept as typed.
- **Each case checks its shape**: the exact number of parts, an id that's a positive `Int`, a non-empty query. Anything else is `nil`. `case "note" where parts.count == 2` reads as "a note link has exactly two parts".
- **Unknown links are just `nil`**, including the hostile one. The parser has no case that could delete anything.

The function is pure and has no UIKit in it, so every malformed link Apple tells you to test ("make sure your test cases include improperly formatted URLs") is a line in a terminal test.

## From route to screens

A route says where to go. The app still has to decide what the user sees around it: which tab, and which screens below the destination so that Back makes sense. That mapping is plain Swift too:

```swift
enum Route: Equatable {
    case inbox
    case note(id: Int)
    case folder(name: String)
    case search(query: String)
    case settings
}

enum Tab {
    case notes, search, settings
}

enum Screen: Equatable {
    case folders
    case folder(name: String)
    case note(id: Int)
    case searchHome
    case searchResults(query: String)
    case settingsHome
}

func destination(for route: Route) -> (tab: Tab, stack: [Screen]) {
    switch route {
    case .inbox:
        return (.notes, [.folders, .folder(name: "Inbox")])
    case .note(let id):
        return (.notes, [.folders, .folder(name: "Inbox"), .note(id: id)])
    case .folder(let name):
        return (.notes, [.folders, .folder(name: name)])
    case .search(let query):
        return (.search, [.searchHome, .searchResults(query: query)])
    case .settings:
        return (.settings, [.settingsHome])
    }
}

for route in [Route.note(id: 42), .folder(name: "Work"), .search(query: "milk"), .settings] {
    let target = destination(for: route)
    print(target.tab, "|", target.stack.map { "\($0)" }.joined(separator: " > "))
}
```

```output
notes | folders > folder(name: "Inbox") > note(id: 42)
notes | folders > folder(name: "Work")
search | searchHome > searchResults(query: "milk")
settings | settingsHome
```

The link to note 42 doesn't just show the note. It builds Folders → Inbox → Note, so Back goes to a list, and Back again to the folders, as if the user had tapped their way there. Choosing those parent screens is a product decision (here every note opens from the Inbox); the `switch` makes it explicit and testable, and the compiler forces a decision for every new route.

### Applying it in UIKit

Lesson 1's `setViewControllers(_:animated:)` replaces a whole stack in one transition, and lesson 2's `selectedIndex` switches tabs. One more step comes first: a sheet might be open, and a link should leave it.

```swift ios
import UIKit

enum Tab: Int {
    case notes = 0, search, settings
}

enum Screen {
    case folders
    case folder(name: String)
    case note(id: Int)
    case searchHome
    case searchResults(query: String)
    case settingsHome
}

final class PlaceholderViewController: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("PlaceholderViewController is created in code")
    }
}

@MainActor
final class AppCoordinator {
    let tabBarController = UITabBarController()
    private let notes = UINavigationController()
    private let search = UINavigationController()
    private let settings = UINavigationController()

    func start() {
        notes.tabBarItem = UITabBarItem(title: "Notes", image: UIImage(systemName: "note.text"), tag: 0)
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
        notes.setViewControllers([makeViewController(for: .folders)], animated: false)
        search.setViewControllers([makeViewController(for: .searchHome)], animated: false)
        settings.setViewControllers([makeViewController(for: .settingsHome)], animated: false)
        tabBarController.viewControllers = [notes, search, settings]
    }

    func show(tab: Tab, stack: [Screen], animated: Bool) {
        if tabBarController.presentedViewController != nil {
            tabBarController.dismiss(animated: false)
        }
        tabBarController.selectedIndex = tab.rawValue
        let viewControllers = stack.map { makeViewController(for: $0) }
        navigationController(for: tab).setViewControllers(viewControllers, animated: animated)
    }

    private func navigationController(for tab: Tab) -> UINavigationController {
        switch tab {
        case .notes: notes
        case .search: search
        case .settings: settings
        }
    }

    private func makeViewController(for screen: Screen) -> UIViewController {
        switch screen {
        case .folders: PlaceholderViewController(title: "Folders")
        case .folder(let name): PlaceholderViewController(title: name)
        case .note(let id): PlaceholderViewController(title: "Note \(id)")
        case .searchHome: PlaceholderViewController(title: "Search")
        case .searchResults(let query): PlaceholderViewController(title: "\u{201C}\(query)\u{201D}")
        case .settingsHome: PlaceholderViewController(title: "Settings")
        }
    }
}
```

- **Dismiss first.** If an editor sheet is open, `dismiss` on the tab bar controller removes everything presented above it (lesson 3). Without animation, so the link doesn't play two transitions. Note what that means: a link can throw away an unsaved draft. If your editors hold unsaved work, ask first or save a draft; that's a product decision the link handler has to make explicitly.
- **Select the tab, then set its stack.** Every controller is created fresh, so nothing is pushed twice (lesson 1's exception), and their titles are set in `init`, so the back buttons are right even though only the top view loads (lesson 1, "why in init").
- **One transition**: `setViewControllers(_:animated:)` animates only to the new top. Animate when the app was already running; at launch, pass `false` so the destination is simply there.
- `PlaceholderViewController` stands in for the real screens, which would get their data and closures as in lessons 4 and 5.

The link handler from earlier becomes three lines: `guard let route = route(from: url) else { return }`, `let target = destination(for: route)`, `coordinator.show(tab: target.tab, stack: target.stack, animated: true)`. The same `show` serves push notifications, Spotlight results and state restoration, which all produce a route too.

## Navigation state and restoration

The system may terminate a suspended app to free memory. The user doesn't know that; they expect to come back to the note they were reading. Apple's sample "Restoring your app's state" describes the scene-based way: "In iOS 13 and later, apps save the state for each window scene using NSUserActivity objects", and "Scene-based state restoration is the recommended way to restore the app's user interface."

The two pieces:

- `stateRestorationActivity(for:)` on the scene delegate: "Use this method to return an `NSUserActivity` object with information about your scene's current state. Save enough information to be able to restore that state again after UIKit disconnects and then reconnects the scene."
- `UISceneSession.stateRestorationActivity`: "If you provide that object, the system puts a copy of it in this property. Use the information in the user activity object to restore the scene to its previous state." It can be `nil` early: "The system encrypts your app's state restoration on disk. If the file is unavailable at scene-connection time, perhaps because the device is still locked, the initial value in this property is nil."

You already have a compact description of "where the user is": a route, and a route can be written as a URL. Build the URL from the route and check that parsing gives the same route back:

```swift
import Foundation

enum Route: Equatable {
    case inbox
    case note(id: Int)
    case folder(name: String)
    case search(query: String)
    case settings
}

func route(from url: URL) -> Route? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    let pathParts = components.path.split(separator: "/").map(String.init)
    let parts: [String]
    switch components.scheme?.lowercased() {
    case "notesapp":
        guard let host = components.host, !host.isEmpty else { return nil }
        parts = [host.lowercased()] + pathParts
    case "https":
        guard components.host?.lowercased() == "notes.example.com" else { return nil }
        parts = pathParts
    default:
        return nil
    }

    switch parts.first {
    case "inbox" where parts.count == 1:
        return .inbox
    case "note" where parts.count == 2:
        guard let id = Int(parts[1]), id > 0 else { return nil }
        return .note(id: id)
    case "folder" where parts.count == 2:
        return .folder(name: parts[1])
    case "search" where parts.count == 1:
        let query = components.queryItems?.first(where: { $0.name == "q" })?.value ?? ""
        return query.isEmpty ? nil : .search(query: query)
    case "settings" where parts.count == 1:
        return .settings
    default:
        return nil
    }
}


extension Route {
    var url: URL? {
        var components = URLComponents()
        components.scheme = "notesapp"
        switch self {
        case .inbox:
            components.host = "inbox"
        case .note(let id):
            components.host = "note"
            components.path = "/\(id)"
        case .folder(let name):
            components.host = "folder"
            components.path = "/\(name)"
        case .search(let query):
            components.host = "search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .settings:
            components.host = "settings"
        }
        return components.url
    }
}

let routes: [Route] = [.inbox, .note(id: 7), .folder(name: "Work Notes"), .search(query: "milk & eggs"), .settings]
for original in routes {
    guard let url = original.url else {
        print(original, "-> no URL")
        continue
    }
    let restored = route(from: url)
    print(original, "->", restored == original ? "same route" : "different")
}
print(Route.note(id: 7).url?.absoluteString ?? "no URL")
```

```output
inbox -> same route
note(id: 7) -> same route
folder(name: "Work Notes") -> same route
search(query: "milk & eggs") -> same route
settings -> same route
notesapp://note/7
```

`URLComponents` percent-encodes the space and the ampersand when it builds the URL, and decodes them when it parses, so even awkward names survive the trip. The scene delegate stores the current route's URL in the activity and reads it back:

```swift ios
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var currentRouteURL: URL?

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let currentRouteURL else { return nil }
        let activity = NSUserActivity(activityType: "com.example.notes.restoration")
        activity.addUserInfoEntries(from: ["route": currentRouteURL.absoluteString])
        return activity
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UITabBarController()
        self.window = window
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            print("open link \(url.absoluteString)")
        } else if let activity = session.stateRestorationActivity,
                  let text = activity.userInfo?["route"] as? String,
                  let url = URL(string: text) {
            print("restore \(url.absoluteString)")
        }
    }
}
```

- `currentRouteURL` is updated by the coordinator as the user navigates (from `navigationController(_:didShow:animated:)`, lesson 5, and on tab changes). The block keeps it as a plain property so it stands alone.
- The `userInfo` values must be property-list types; Apple lists `NSArray`, `NSData`, `NSDate`, `NSDictionary`, `NSNull`, `NSNumber`, `NSSet`, `NSString` and `NSURL`. A string is the safest choice.
- **A link wins over restored state.** If the user tapped a link, that's where they want to go.
- The restored URL goes through the same `route(from:)` as a link, so a stale or damaged value is rejected the same way, and the app simply starts at its first screen.
- Info.plist has an `NSUserActivityTypes` key for "the user activity types that the app supports"; list your restoration type there. Whether restoration works without that entry wasn't verified for this lesson.

What to save, from Apple's guide "Preserving your app's UI across launches": "State preservation isn't a substitute for saving your app's data to disk." Save **where** the user is (route identifiers, the selected tab, maybe a scroll position), never the notes themselves, and expect the system to discard it at times. The sample adds a testing detail: "the system automatically deletes its preserved state when the user force quits the app", and also when the app crashes at launch. To test restoration, stop the app from Xcode instead of swiping it away.

### The older mechanism

Before scenes, UIKit restored view controllers themselves: you opted in with `application(_:shouldSaveSecureApplicationState:)` and `application(_:shouldRestoreSecureApplicationState:)`, gave controllers a `restorationIdentifier`, and encoded state in `encodeRestorableState(with:)`. `UINavigationController` and `UITabBarController` still document how they preserve their children that way. You'll see it in older codebases; for a scene-based app, the activity-based approach above is what Apple recommends.

## Common mistakes

> [!error] Handling only one entry point
> The link works when the app is running and does nothing from a cold launch (or the reverse). Handle `connectionOptions` in `scene(_:willConnectTo:options:)` and the running-app methods, for both URLs and universal links.

> [!error] Links that act instead of navigate
> `notesapp://delete?id=42` lets any app or web page delete a note. Apple: limit link actions "to those that don't risk the user's data". Navigate to the note; the user taps Delete.

> [!error] Parsing with string splitting
> `url.absoluteString.components(separatedBy: "/")` breaks on query strings, percent-encoding and a trailing slash. Use `URLComponents`, and check the scheme and host.

> [!error] Pushing the destination onto whatever stack is showing
> The user is three screens deep in Settings with a sheet open; the link pushes a note on top. Dismiss what's presented, select the right tab and replace its stack.

> [!error] Saving app data in the restoration activity
> The activity can be discarded at any time. Save identifiers and reload the data from your store.

## Exercises

````exercise
id: m25-l06-e1
type: prediction
prompt: "What does this route parser print for each link?"
code: |
  import Foundation

  enum Route: Equatable {
      case profile(username: String)
      case post(id: Int)
  }

  func route(from url: URL) -> Route? {
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme == "pics",
            let host = components.host else {
          return nil
      }
      let parts = components.path.split(separator: "/").map(String.init)
      switch (host, parts.count) {
      case ("user", 1):
          return .profile(username: parts[0])
      case ("post", 1):
          guard let id = Int(parts[0]) else { return nil }
          return .post(id: id)
      default:
          return nil
      }
  }

  let links = ["pics://user/ana", "pics://post/12", "pics://post/twelve", "pics://user/ana/followers", "photos://user/ana"]
  for link in links {
      let found = URL(string: link).flatMap { route(from: $0) }
      print(found.map { "\($0)" } ?? "nil")
  }
output: |
  profile(username: "ana")
  post(id: 12)
  nil
  nil
  nil
hints:
  - "For pics://user/ana, the host is user and the path is /ana."
  - "Each case requires exactly one path part, and the scheme must be pics."
solution: |
  ```output
  profile(username: "ana")
  post(id: 12)
  nil
  nil
  nil
  ```

  The first two links have the right scheme, host and one path part. `post/twelve` fails the `Int` conversion. `user/ana/followers` has two path parts, which no case accepts. `photos://` has the wrong scheme. `flatMap` keeps the result `nil` when either `URL(string:)` or `route(from:)` returns `nil`, and `map` turns a found route into its text.
````

````exercise
id: m25-l06-e2
type: comprehension
prompt: "The app isn't running. The user taps https://notes.example.com/note/42, a correctly configured universal link. Where does the app first see the URL?"
choices:
  - text: "In scene(_:willConnectTo:options:), as an NSUserActivity of type NSUserActivityTypeBrowsingWeb in connectionOptions.userActivities, with the URL in webpageURL."
    correct: true
    why: "Apple: if the app isn't running, the system delivers the universal link to scene(_:willConnectTo:options:) after launch."
  - text: "In scene(_:openURLContexts:)."
    correct: false
    why: "That's for URLs (such as custom schemes) while the app is running."
  - text: "In scene(_:continue:)."
    correct: false
    why: "That's for universal links when the app is already running or suspended."
  - text: "In connectionOptions.urlContexts."
    correct: false
    why: "That's where a custom-scheme URL arrives at launch. Universal links come as user activities."
solution: |
  **`connectionOptions.userActivities`** in `scene(_:willConnectTo:options:)`. Universal links always arrive as an `NSUserActivity` with `activityType == NSUserActivityTypeBrowsingWeb`; at launch inside the connection options, later through `scene(_:continue:)`. Custom-scheme URLs use `urlContexts` and `scene(_:openURLContexts:)` instead.
````

````exercise
id: m25-l06-e3
type: fill-in
prompt: "Complete the scene delegate methods that receive links while the app is running, and the one that saves state."
code: |
  func scene(_ scene: UIScene, [[1]] URLContexts: Set<UIOpenURLContext>) {
      guard let url = URLContexts.first?.url else { return }
      open(url)
  }

  func scene(_ scene: UIScene, [[2]] userActivity: NSUserActivity) {
      guard userActivity.activityType == [[3]],
            let url = userActivity.[[4]] else { return }
      open(url)
  }

  func [[5]](for scene: UIScene) -> NSUserActivity? {
      currentActivity()
  }
blanks:
  - id: "1"
    answers: ["openURLContexts"]
  - id: "2"
    answers: ["continue"]
  - id: "3"
    answers: ["NSUserActivityTypeBrowsingWeb"]
  - id: "4"
    answers: ["webpageURL"]
  - id: "5"
    answers: ["stateRestorationActivity"]
solution: |
  ```swift ios
  import UIKit

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
      var window: UIWindow?

      func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
          guard let url = URLContexts.first?.url else { return }
          open(url)
      }

      func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
          guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                let url = userActivity.webpageURL else { return }
          open(url)
      }

      func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
          currentActivity()
      }

      private func open(_ url: URL) {
          print("open \(url.absoluteString)")
      }

      private func currentActivity() -> NSUserActivity? {
          nil
      }
  }
  ```

  The argument label in the first method is `openURLContexts` and the parameter name is `URLContexts`, with a capital URL, exactly as UIKit declares it. A misspelled optional protocol method compiles as an ordinary method and is never called, so copy these signatures carefully.
````

````exercise
id: m25-l06-e4
type: solve
prompt: |
  A shop app accepts `shopapp://` links. Write `shopRoute(from:)`:

  - `shopapp://product/<id>`: `.product(id:)` when the id is a positive `Int`.
  - `shopapp://category/<name>?sort=<order>`: `.category(name:sort:)`. Only `price` and `newest` are accepted as sort orders; anything else, or no `sort`, means `"popular"`.
  - `shopapp://cart` with nothing after it: `.cart`.
  - Anything else, including other schemes, returns `nil`. Compare the scheme and host case-insensitively.

  ```swift
  let links = [
      "shopapp://product/123",
      "shopapp://product/0",
      "shopapp://category/shoes?sort=price",
      "shopapp://category/shoes?sort=cheapest",
      "shopapp://category/shoes",
      "shopapp://cart",
      "shopapp://cart/checkout",
      "https://shop.example.com/product/123",
  ]
  for link in links {
      let found = URL(string: link).flatMap { shopRoute(from: $0) }
      print(link, "->", found.map { "\($0)" } ?? "rejected")
  }
  ```

  should print:

  ```plaintext
  shopapp://product/123 -> product(id: 123)
  shopapp://product/0 -> rejected
  shopapp://category/shoes?sort=price -> category(name: "shoes", sort: "price")
  shopapp://category/shoes?sort=cheapest -> category(name: "shoes", sort: "popular")
  shopapp://category/shoes -> category(name: "shoes", sort: "popular")
  shopapp://cart -> cart
  shopapp://cart/checkout -> rejected
  https://shop.example.com/product/123 -> rejected
  ```
starter: |
  import Foundation

  enum ShopRoute: Equatable {
      case product(id: Int)
      case category(name: String, sort: String)
      case cart
  }

  func shopRoute(from url: URL) -> ShopRoute? {
      // your code
      nil
  }
hints:
  - "URLComponents(url: url, resolvingAgainstBaseURL: false) gives you scheme, host, path and queryItems."
  - "components.path.split(separator: \"/\").map(String.init) turns \"/123\" into [\"123\"]."
  - "An unknown sort value isn't an error here; it falls back to popular."
rubric:
  - Uses URLComponents rather than splitting the string by hand.
  - Rejects other schemes, a zero or non-numeric id, and extra path parts.
  - Falls back to "popular" for a missing or unknown sort.
  - The output matches.
solution: |
  ```swift
  import Foundation

  enum ShopRoute: Equatable {
      case product(id: Int)
      case category(name: String, sort: String)
      case cart
  }

  func shopRoute(from url: URL) -> ShopRoute? {
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "shopapp",
            let host = components.host?.lowercased() else {
          return nil
      }
      let parts = components.path.split(separator: "/").map(String.init)
      switch host {
      case "product":
          guard parts.count == 1, let id = Int(parts[0]), id > 0 else { return nil }
          return .product(id: id)
      case "category":
          guard parts.count == 1 else { return nil }
          let sort = components.queryItems?.first(where: { $0.name == "sort" })?.value ?? "popular"
          return .category(name: parts[0], sort: ["price", "newest"].contains(sort) ? sort : "popular")
      case "cart":
          return parts.isEmpty ? .cart : nil
      default:
          return nil
      }
  }

  let links = [
      "shopapp://product/123",
      "shopapp://product/0",
      "shopapp://category/shoes?sort=price",
      "shopapp://category/shoes?sort=cheapest",
      "shopapp://category/shoes",
      "shopapp://cart",
      "shopapp://cart/checkout",
      "https://shop.example.com/product/123",
  ]
  for link in links {
      let found = URL(string: link).flatMap { shopRoute(from: $0) }
      print(link, "->", found.map { "\($0)" } ?? "rejected")
  }
  ```

  ```output
  shopapp://product/123 -> product(id: 123)
  shopapp://product/0 -> rejected
  shopapp://category/shoes?sort=price -> category(name: "shoes", sort: "price")
  shopapp://category/shoes?sort=cheapest -> category(name: "shoes", sort: "popular")
  shopapp://category/shoes -> category(name: "shoes", sort: "popular")
  shopapp://cart -> cart
  shopapp://cart/checkout -> rejected
  https://shop.example.com/product/123 -> rejected
  ```

  The sort order is checked against a list of known values instead of being passed through: a link can only ask for what the app already supports. An unknown order isn't a reason to reject the whole link, so it falls back to the default; an unknown host or a bad id is, because there's no sensible screen to show. `shopapp://cart/checkout` is rejected on purpose: a link may open the cart, but it shouldn't start a payment.
````

````exercise
id: m25-l06-e5
type: find-errors
prompt: "Review this link handling in a scene delegate. Mark every real problem."
code: |
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
      guard let url = URLContexts.first?.url else { return }
      let parts = url.absoluteString.components(separatedBy: "/")
      if parts[2] == "note" {
          let id = Int(parts[3])!
          let detail = NoteDetailViewController(noteID: id)
          visibleNavigationController()?.pushViewController(detail, animated: true)
      } else if parts[2] == "delete" {
          store.deleteNote(id: Int(parts[3])!)
      }
  }
choices:
  - text: "It splits the string by hand and indexes parts[3] and force-unwraps Int(...), so notesapp://note or notesapp://note/abc crashes the app."
    correct: true
  - text: "A link can delete data, which Apple warns against: links should only navigate."
    correct: true
  - text: "It pushes onto whatever stack is visible, without dismissing a presented sheet or selecting the right tab."
    correct: true
  - text: "Links that arrive at launch through connectionOptions in scene(_:willConnectTo:options:) aren't handled by this method."
    correct: true
  - text: "scene(_:openURLContexts:) is only for universal links."
    correct: false
    why: "It's for URLs such as custom schemes; universal links arrive through scene(_:continue:)."
rubric:
  - I found the crash-prone parsing.
  - I found the destructive link.
  - I found the push onto the current stack.
  - I noticed the missing launch path.
solution: |
  Parse with a pure `route(from:)` built on `URLComponents` that returns `nil` for anything unexpected; drop the delete route entirely; apply a route by dismissing what's presented, selecting the tab and replacing its stack with `setViewControllers(_:animated:)`; and call the same handler from `scene(_:willConnectTo:options:)` for `connectionOptions.urlContexts` (and `userActivities` for universal links).
````

````exercise
id: m25-l06-e6
type: explain
prompt: "A teammate wants to save the full text of the note being edited, the whole list of notes and the selected tab in the scene's state restoration activity, \"so nothing is ever lost\". Explain what's wrong with that and what you'd save instead."
code: |
  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
      let activity = NSUserActivity(activityType: "com.example.notes.restoration")
      activity.addUserInfoEntries(from: [
          "allNotes": store.allNotesAsDictionaries(),
          "editingText": editor?.text ?? "",
          "tab": tabBarController.selectedIndex,
      ])
      return activity
  }
rubric:
  - States that restoration data can be discarded by the system and isn't a substitute for saving data.
  - Recommends saving identifiers (a route, the tab) and reloading data from the store.
  - Handles unsaved editor text through the app's own persistence (a draft), not restoration.
  - Mentions keeping userInfo small.
solution: |
  Apple: "State preservation isn't a substitute for saving your app's data to disk", and the system may discard it, for example when the user force quits or the app crashes at launch. Notes stored only there can disappear. It's also the wrong size: the restoration file would grow with the whole notes database, and Apple recommends keeping `userInfo` "as small as possible".

  Save **where** the user is: the current route as a URL string (`notesapp://note/42`) and the tab. The notes stay in the app's store, and the restored screen loads note 42 from it. Unsaved editor text is user data, so it belongs in the store too, as a draft saved when the app goes to the background; the restored route can then reopen the editor and load the draft.
````

## Summary

- Custom schemes (`notesapp://`) are easy and claimable by any app; universal links (`https://` on your verified domain) are what Apple strongly recommends. Either way, links navigate and never destroy data.
- Scene-based apps receive links in four places: `connectionOptions.urlContexts` and `userActivities` at launch, `scene(_:openURLContexts:)` and `scene(_:continue:)` while running. Send them all to one handler.
- Parse with `URLComponents` into a route enum in a pure function that returns `nil` for anything malformed or unknown, and test it with bad input.
- Map each route to a tab and a full stack, then dismiss what's presented, select the tab and call `setViewControllers(_:animated:)` once.
- Save navigation state by returning an `NSUserActivity` from `stateRestorationActivity(for:)` and read it back from `session.stateRestorationActivity`. A route URL is a compact, already-validated encoding. Save where the user is, not their data.
