---
id: m35-l05
title: Navigation state and deep links
description: "Navigation becomes something you can reason about once one object owns it. You move the selected tab, the stack paths and the presented sheet into a router, parse incoming URLs into a tab plus a whole stack of routes in plain Swift, deliver them with onOpenURL, and save and restore where the user was, both as a Codable array of routes and as a NavigationPath.CodableRepresentation, including what to do when the saved data no longer decodes."
module: m35
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l04, m25-l06]
objectives:
  - Put the selected tab, each tab's path and the presented sheet in one router object that views read and write.
  - Parse a URL into a tab and a complete path of routes with URLComponents, rejecting anything unexpected.
  - Receive custom-scheme URLs and universal links in SwiftUI with onOpenURL and send them to the router.
  - Save and restore a [Route] path with JSONEncoder and JSONDecoder, and a NavigationPath with its CodableRepresentation.
  - Handle saved navigation that no longer decodes or points at deleted content.
terms:
  - term: Router
    definition: "An object (here an @Observable class) that owns navigation state, such as the selected tab, each stack's path and the current sheet, and exposes methods like open(_:) that change it. Views bind to it instead of keeping their own copies."
  - term: Destination
    definition: "Here, the result of parsing a deep link: which tab to select, the complete path to push in it, and any extra input such as a search query."
  - term: onOpenURL(perform:)
    definition: "A SwiftUI modifier (iOS 14) that runs a closure with each URL the app receives in that scene: custom-scheme URLs and, Apple says, universal links, which SwiftUI delivers as URLs."
  - term: NavigationPath.CodableRepresentation
    definition: "A Codable form of a NavigationPath (iOS 16), from the path's codable property. It's nil if any element isn't Codable. NavigationPath(_:) rebuilds a path from it."
  - term: SceneStorage
    definition: "A property wrapper (iOS 14) for small per-scene values that the system saves and restores, such as navigation state. Apple makes no guarantee about when it's written, and it's destroyed with the scene."
mastery:
  - Write a router with open(_ url:) that dismisses any sheet, selects a tab and replaces that tab's path.
  - Write a parser that turns cookbook://recipes/Desserts/42/steps/3 into the recipes tab with three routes, and rejects malformed links.
  - Attach onOpenURL to the root view and route the URL through the parser.
  - Encode the recipes path to Data, decode it at launch, and fall back to the root when decoding fails.
  - Trim a restored path at the first route whose recipe no longer exists.
resources: [xcode-custom-url-scheme, xcode-universal-links, foundation-urlcomponents, foundation-encoding-custom-types, swiftui-scenephase, swift-book-enumerations]
cards:
  - id: m35-l05-c1
    front: Why give navigation state a single owner (a router)?
    back: "A deep link, a notification, a restored session and a button all need to change the same state: tab, paths, sheet. If each view keeps its own @State, nothing outside can reach it. One owner makes every navigation change a method call on one object, and lets you test it."
  - id: m35-l05-c2
    front: How does a SwiftUI app receive deep links?
    back: "onOpenURL(perform:) on a view in the scene. It gets custom-scheme URLs and universal links: Apple says SwiftUI passes a universal link directly as a URL rather than as an NSUserActivity. onContinueUserActivity is for other activities, like Handoff."
  - id: m35-l05-c3
    front: What should handling a deep link do, in order?
    back: "Parse the URL into a destination (or reject it), dismiss anything presented, select the tab, then replace that tab's whole path in one assignment so Back works as if the user had tapped their way there."
  - id: m35-l05-c4
    front: "[Route] or NavigationPath: how do you save each?"
    back: "[Route] with Route: Codable: JSONEncoder().encode(path), decode with JSONDecoder().decode([Route].self, from:). NavigationPath: path.codable gives a CodableRepresentation (nil if any element isn't Codable); encode that, then NavigationPath(decodedRepresentation)."
  - id: m35-l05-c5
    front: What can go wrong when restoring navigation, and what do you do?
    back: "The data may not decode (an app update renamed a route) or may point at content that was deleted. Decode with try? and fall back to the root; validate each route and cut the path at the first one that no longer makes sense. Restoring a wrong screen is worse than starting at the root."
---

## The idea in one sentence

Put all navigation state in **one place you own**, and a deep link, a notification, a restored session or a button all become the same operation: compute a destination as plain data, then assign it.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run. Behavior comes from Apple's pages for `onOpenURL(perform:)`, `onContinueUserActivity(_:perform:)`, `NavigationPath`, `NavigationPath.CodableRepresentation` and `SceneStorage`, read in November 2026. URL schemes, associated domains and restoration weren't checked in Xcode or on a device. The parser, the router model and the encoding round trips are plain Swift, compiled and run with Swift 6.3.

## One owner for navigation

Lessons 2 to 4 kept navigation in `@State` inside views: a path here, a selected tab there, a sheet enum somewhere else. That works until something outside those views needs to navigate. A link like `cookbook://recipes/Desserts/42` has to switch tabs, close the sheet that's open and push two screens, and no single view can do all three.

So move the state up into a router. Module 25 had a coordinator object owning a `UINavigationController`; here the router owns *values*, and SwiftUI turns the values into screens:

```swift ios
import SwiftUI

enum AppTab: String, Hashable, Codable {
    case recipes, search, shopping
}

enum Route: Hashable, Codable {
    case category(String)
    case recipe(id: Int)
    case step(recipeID: Int, number: Int)
}

enum AppSheet: String, Identifiable {
    case newRecipe, settings
    var id: String { rawValue }
}

@Observable
final class Router {
    var tab: AppTab = .recipes
    var recipesPath: [Route] = []
    var searchQuery = ""
    var sheet: AppSheet?

    func show(recipe id: Int, in category: String) {
        sheet = nil
        tab = .recipes
        recipesPath = [.category(category), .recipe(id: id)]
    }

    func popToRoot() {
        recipesPath.removeAll()
    }
}

struct AppRootView: View {
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.recipesPath) {
                RecipesHome(router: router)
                    .navigationDestination(for: Route.self) { route in
                        RouteScreen(route: route, router: router)
                    }
            }
            .tabItem { Label("Recipes", systemImage: "book") }
            .tag(AppTab.recipes)

            NavigationStack {
                Text("Results for \(router.searchQuery)")
                    .navigationTitle("Search")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack {
                Text("Shopping list")
                    .navigationTitle("Shopping")
            }
            .tabItem { Label("Shopping", systemImage: "cart") }
            .tag(AppTab.shopping)
        }
        .sheet(item: $router.sheet) { sheet in
            Text(sheet == .newRecipe ? "New recipe" : "Settings")
        }
    }
}

struct RecipesHome: View {
    let router: Router

    var body: some View {
        List {
            NavigationLink("Desserts", value: Route.category("Desserts"))
            Button("Today's pick") { router.show(recipe: 42, in: "Desserts") }
            Button("New recipe") { router.sheet = .newRecipe }
        }
        .navigationTitle("Recipes")
    }
}

struct RouteScreen: View {
    let route: Route
    let router: Router

    var body: some View {
        switch route {
        case .category(let name):
            List {
                NavigationLink("Flan", value: Route.recipe(id: 42))
            }
            .navigationTitle(name)
        case .recipe(let id):
            VStack {
                Text("Recipe \(id)")
                NavigationLink("Step 1", value: Route.step(recipeID: id, number: 1))
                Button("All recipes") { router.popToRoot() }
            }
        case .step(let recipeID, let number):
            Text("Recipe \(recipeID), step \(number)")
        }
    }
}
```

- **`@Observable`** (iOS 17, from the Observation framework) makes SwiftUI update any view that reads a property of the router when that property changes. Module 36 explains how; for now it's what lets one object drive several views.
- **`@State private var router = Router()`** gives the root view ownership of one router for its lifetime.
- **`$router.tab`, `$router.recipesPath`, `$router.sheet`** are bindings to the router's properties. The tab view, the stack and the sheet read and write the router, not their own copies. When the user taps Back, `recipesPath` shrinks; when they switch tabs, `tab` changes.
- **Child views get the router**, and navigate by calling its methods (`show(recipe:in:)`, `popToRoot()`) or setting its properties. They don't need bindings.
- **`show(recipe:in:)`** is a deep link without the URL: dismiss the sheet, pick the tab, assign the whole path.

Only the recipes tab has a path in the router here, to keep the example short; a real app gives each tab with drill-down its own path property.

## From URL to destination

Module 25's lesson 6 parsed URLs into a `Route` enum and then mapped each route to a tab and a stack of screens. With `NavigationStack` the stack *is* an array of routes, so the parser can produce the final answer directly: which tab, and the full path. The same rules apply as in Module 25: one pure function, `URLComponents` to split the URL, lowercase the scheme and host, check the shape of every part, and return `nil` for anything you don't recognize.

```swift
import Foundation

enum AppTab: String {
    case recipes, search, shopping
}

enum Route: Hashable {
    case category(String)
    case recipe(id: Int)
    case step(recipeID: Int, number: Int)
}

struct Destination: Equatable {
    var tab: AppTab
    var path: [Route] = []
    var searchQuery: String?
}

enum DeepLink {
    static func destination(from url: URL) -> Destination? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var parts = components.path.split(separator: "/").map(String.init)
        switch components.scheme?.lowercased() {
        case "cookbook":
            guard let host = components.host?.lowercased(), !host.isEmpty else { return nil }
            parts.insert(host, at: 0)
        case "https":
            guard components.host?.lowercased() == "cookbook.example.com" else { return nil }
        default:
            return nil
        }

        switch parts.first {
        case "recipes" where parts.count == 1:
            return Destination(tab: .recipes)
        case "recipes" where parts.count == 2:
            return Destination(tab: .recipes, path: [.category(parts[1])])
        case "recipes" where parts.count == 3:
            guard let id = positive(parts[2]) else { return nil }
            return Destination(tab: .recipes, path: [.category(parts[1]), .recipe(id: id)])
        case "recipes" where parts.count == 5 && parts[3] == "steps":
            guard let id = positive(parts[2]), let step = positive(parts[4]) else { return nil }
            return Destination(tab: .recipes,
                               path: [.category(parts[1]), .recipe(id: id), .step(recipeID: id, number: step)])
        case "search" where parts.count == 1:
            guard let query = components.queryItems?.first(where: { $0.name == "q" })?.value,
                  !query.isEmpty else { return nil }
            return Destination(tab: .search, searchQuery: query)
        case "shopping" where parts.count == 1:
            return Destination(tab: .shopping)
        default:
            return nil
        }
    }

    private static func positive(_ text: String) -> Int? {
        guard let number = Int(text), number > 0 else { return nil }
        return number
    }
}

let links = [
    "cookbook://recipes",
    "cookbook://recipes/Desserts/42",
    "https://cookbook.example.com/recipes/Sweet%20Things/42/steps/3",
    "cookbook://search?q=lemon%20tart",
    "COOKBOOK://Shopping",
    "cookbook://recipes/Desserts/0",
    "cookbook://recipes/Desserts/42/steps",
    "cookbook://search?q=",
    "https://evil.example.com/recipes/Desserts/42",
    "cookbook://admin/reset",
]
for link in links {
    guard let url = URL(string: link), let destination = DeepLink.destination(from: url) else {
        print(link, "-> rejected")
        continue
    }
    let path = destination.path.map { "\($0)" }.joined(separator: " > ")
    let query = destination.searchQuery.map { ", query: \($0)" } ?? ""
    print("\(link) -> \(destination.tab) \(path.isEmpty ? "(root)" : path)\(query)")
}
```

```output
cookbook://recipes -> recipes (root)
cookbook://recipes/Desserts/42 -> recipes category("Desserts") > recipe(id: 42)
https://cookbook.example.com/recipes/Sweet%20Things/42/steps/3 -> recipes category("Sweet Things") > recipe(id: 42) > step(recipeID: 42, number: 3)
cookbook://search?q=lemon%20tart -> search (root), query: lemon tart
COOKBOOK://Shopping -> shopping (root)
cookbook://recipes/Desserts/0 -> rejected
cookbook://recipes/Desserts/42/steps -> rejected
cookbook://search?q= -> rejected
https://evil.example.com/recipes/Desserts/42 -> rejected
cookbook://admin/reset -> rejected
```

What's new compared with Module 25:

- **The result is a whole stack.** A link to step 3 produces three routes, so Back from the step goes to the recipe, then to the Desserts list, then to the root, as if the user had tapped their way there. Choosing those parents is a product decision, made once, in the parser.
- **The parent routes come from the URL.** The category is in the link, so the stack under the recipe is the one the link's author meant. A link with only an id would need a lookup to find its category; that lookup belongs in the router or a model, not in the parser.
- **Nothing the parser returns can do harm.** There's no route for "reset" or "delete," so `cookbook://admin/reset` is just `nil`. A link should only ever *show* something; an action that changes data needs the user to confirm it on screen.

> [!note] Custom schemes and universal links
> Module 25 compared the two: a custom scheme is registered in the app's Info.plist and any app can claim it; a universal link is an https URL on your domain, verified through the associated domains entitlement, and Apple recommends it. The parser accepts both forms and maps them to the same destinations.

## Receiving links with onOpenURL

In UIKit, links arrived in four places in the scene delegate (Module 25). In SwiftUI, one modifier receives them. Apple's description of `onOpenURL(perform:)` (iOS 14): the closure runs "when your app receives a Universal Link or a custom URL," and "SwiftUI passes a Universal Link to your app directly as a URL, which you receive using this modifier." `onContinueUserActivity(_:perform:)` is for other user activities, like Handoff.

The router gets an `open(_:)` method that applies a destination:

```swift ios
import SwiftUI

enum AppTab: String, Hashable {
    case recipes, search, shopping
}

enum Route: Hashable, Codable {
    case category(String)
    case recipe(id: Int)
}

struct Destination {
    var tab: AppTab
    var path: [Route] = []
    var searchQuery: String?
}

enum DeepLink {
    static func destination(from url: URL) -> Destination? {
        // The parser from the lesson, shortened.
        let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host
        return host == "recipes" ? Destination(tab: .recipes, path: [.category("Desserts")]) : nil
    }
}

@Observable
final class Router {
    var tab: AppTab = .recipes
    var recipesPath: [Route] = []
    var searchQuery = ""
    var isShowingSettings = false

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let destination = DeepLink.destination(from: url) else { return false }
        isShowingSettings = false                 // 1. nothing presented on top
        tab = destination.tab                     // 2. the right tab
        if destination.tab == .recipes {
            recipesPath = destination.path        // 3. the whole stack at once
        }
        if let query = destination.searchQuery {
            searchQuery = query
        }
        return true
    }
}

struct LinkedRoot: View {
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.recipesPath) {
                Text("Recipes")
                    .navigationDestination(for: Route.self) { route in
                        Text(String(describing: route))
                    }
            }
            .tabItem { Label("Recipes", systemImage: "book") }
            .tag(AppTab.recipes)

            Text("Search: \(router.searchQuery)")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
        }
        .sheet(isPresented: $router.isShowingSettings) {
            Text("Settings")
        }
        .onOpenURL { url in
            router.open(url)
        }
    }
}
```

The order inside `open(_:)` matters: dismiss what's presented, choose the tab, then replace the path in one assignment. Replacing (not appending) means a link always lands on the same stack whatever the user was doing before. `open(_:)` returns whether the link was understood, so a caller can show "This link isn't supported" instead of silently doing nothing.

The router's logic is plain Swift too, so it can be checked without a simulator:

```swift
import Foundation

enum AppTab: String {
    case recipes, search, shopping
}

enum Route: Hashable {
    case category(String)
    case recipe(id: Int)
}

struct Destination {
    var tab: AppTab
    var path: [Route] = []
}

func destination(from url: URL) -> Destination? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.scheme == "cookbook" else { return nil }
    let parts = [components.host ?? ""] + components.path.split(separator: "/").map(String.init)
    switch parts.first {
    case "recipes" where parts.count == 3:
        guard let id = Int(parts[2]), id > 0 else { return nil }
        return Destination(tab: .recipes, path: [.category(parts[1]), .recipe(id: id)])
    case "shopping" where parts.count == 1:
        return Destination(tab: .shopping)
    default:
        return nil
    }
}

final class Router {
    var tab: AppTab = .recipes
    var recipesPath: [Route] = []
    var sheet: String?

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let destination = destination(from: url) else { return false }
        sheet = nil
        tab = destination.tab
        if destination.tab == .recipes {
            recipesPath = destination.path
        }
        return true
    }

    var summary: String {
        let path = recipesPath.map { "\($0)" }.joined(separator: " > ")
        return "tab: \(tab), recipes: [\(path)], sheet: \(sheet ?? "none")"
    }
}

let router = Router()
router.recipesPath = [.category("Soups"), .recipe(id: 7)]
router.sheet = "settings"
print(router.summary)

router.open(URL(string: "cookbook://recipes/Desserts/42")!)
print(router.summary)

router.open(URL(string: "cookbook://shopping")!)
print(router.summary)

print(router.open(URL(string: "cookbook://recipes/Desserts/oops")!))
print(router.summary)
```

```output
tab: recipes, recipes: [category("Soups") > recipe(id: 7)], sheet: settings
tab: recipes, recipes: [category("Desserts") > recipe(id: 42)], sheet: none
tab: shopping, recipes: [category("Desserts") > recipe(id: 42)], sheet: none
false
tab: shopping, recipes: [category("Desserts") > recipe(id: 42)], sheet: none
```

The first link replaces the Soups stack and closes the sheet. The shopping link switches tabs but leaves the recipes path alone, so when the user goes back to Recipes, they find what they had. A bad link changes nothing and reports `false`.

## Saving and restoring navigation

The system can terminate a suspended app; the user expects to come back to the same screen. Module 25 saved a route URL in an `NSUserActivity`. In SwiftUI the path is already a value, so you encode it.

### A [Route] path

With `Route: Codable`, Swift synthesizes the encoding, and an array of routes encodes like any other array:

```swift
import Foundation

enum Route: Hashable, Codable {
    case category(String)
    case recipe(id: Int)
    case step(recipeID: Int, number: Int)
}

let path: [Route] = [.category("Desserts"), .recipe(id: 42), .step(recipeID: 42, number: 3)]

let encoder = JSONEncoder()
encoder.outputFormatting = .sortedKeys
do {
    let data = try encoder.encode(path)
    let restored = try JSONDecoder().decode([Route].self, from: data)
    print(restored == path)
    for route in restored {
        print(route)
    }
} catch {
    print("couldn't round-trip the path")
}

// What synthesized Codable expects: one key per case, "_0" for an unlabeled value.
let saved = #"[{"category":{"_0":"Soups"}},{"recipe":{"id":7}}]"#
let fromDisk = (try? JSONDecoder().decode([Route].self, from: Data(saved.utf8))) ?? []
print(fromDisk.map { "\($0)" }.joined(separator: " > "))

// Data written by an older version, with a case this version doesn't have.
let old = #"[{"category":{"_0":"Soups"}},{"favorite":{"id":7}}]"#
let restoredOld = (try? JSONDecoder().decode([Route].self, from: Data(old.utf8))) ?? []
print("restored \(restoredOld.count) routes: start at the root")
```

```output
true
category("Desserts")
recipe(id: 42)
step(recipeID: 42, number: 3)
category("Soups") > recipe(id: 7)
restored 0 routes: start at the root
```

- **The round trip** proves nothing is lost. `.sortedKeys` makes the JSON's key order deterministic, which helps when you compare saved data in tests.
- **The saved format** is one JSON object per route, keyed by the case name, with labeled associated values under their labels and unlabeled ones under `_0`, `_1`… That's why **renaming a case or a label breaks old saved data**: an app update that renames `recipe(id:)` to `recipe(recipeID:)` can't read what the previous version saved.
- **`try?` with a fallback** turns any decoding failure into "start at the root." Never let a restoration failure crash the app or land the user on a half-built stack.

A route type that can't be encoded fails at compile time, which is a good reason to keep routes to ids and names:

```swift no-compile type 'Route' does not conform to protocol 'Decodable'
struct Recipe {
    let id: Int
    var title: String
}

enum Route: Codable {
    case recipe(Recipe)
}
```

Swift 6.3 reports that `Route` conforms to neither `Decodable` nor `Encodable`: synthesis needs every associated value to be `Codable`.

In the app, a small `@SceneStorage` value holds the encoded path. Apple: `SceneStorage` "works very similar to `State`, except its initial value is restored by the system if it was previously saved," each scene has its own, and it's for lightweight data only ("Do not use `SceneStorage` with sensitive data"). It supports `Data?`:

```swift ios
import SwiftUI

enum Route: Hashable, Codable {
    case category(String)
    case recipe(id: Int)
}

struct RestoringRecipesTab: View {
    @State private var path: [Route] = []
    @State private var didRestore = false
    @SceneStorage("recipesPath") private var savedPath: Data?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Desserts", value: Route.category("Desserts"))
            }
            .navigationDestination(for: Route.self) { route in
                Text(String(describing: route))
            }
        }
        .onAppear {
            guard !didRestore else { return }
            didRestore = true
            if let savedPath, let routes = try? JSONDecoder().decode([Route].self, from: savedPath) {
                path = routes
            }
        }
        .onChange(of: path) {
            savedPath = try? JSONEncoder().encode(path)
        }
    }
}
```

`onAppear` can run more than once (every time the tab reappears), so the `didRestore` flag makes the restore happen once. Every change of `path` writes the new encoding; `SceneStorage` decides when to persist it, and Apple says "the system makes no guarantees as to when and how often the data will be persisted," so treat it as best effort. If the scene is explicitly destroyed (the user swipes it away in the iPad app switcher), "the data is also destroyed": the next launch starts fresh, which is what users expect.

### A NavigationPath

A `NavigationPath` can't be encoded directly, but its `codable` property gives "a value that describes the contents of this path in a serializable format," and `NavigationPath(_:)` rebuilds a path from it. `codable` "is `nil` if any of the type-erased elements of the path don't conform to the `Codable` protocol," which is why value links that take `Codable` values exist. Apple's `NavigationPath` example saves when the scene goes to the background:

```swift ios
import SwiftUI

struct MixedRestoringStack: View {
    @State private var path = NavigationPath()
    @SceneStorage("mixedPath") private var savedPath: Data?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink("Recipe 42", value: 42)
                NavigationLink("Ana's recipes", value: "Ana")
            }
            .navigationDestination(for: Int.self) { id in
                Text("Recipe \(id)")
            }
            .navigationDestination(for: String.self) { author in
                Text(author)
            }
        }
        .onAppear {
            guard path.isEmpty,
                  let savedPath,
                  let representation = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self,
                                                                 from: savedPath)
            else { return }
            path = NavigationPath(representation)
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .background, let representation = path.codable else { return }
            savedPath = try? JSONEncoder().encode(representation)
        }
    }
}
```

The saved representation is opaque: you can't inspect it to check that recipe 42 still exists before restoring. That's one more reason to prefer a `[Route]` array for your own screens. With an array, you can validate what you restore, which is the last piece.

### Restoring only what still makes sense

Between saving and restoring, the user may have deleted recipe 42 on another device. Restoring a path that ends in "Recipe not found" is worse than restoring less. Check each route and cut the path at the first one that no longer exists; everything above it depended on it anyway. That's exercise 6.

## Common mistakes

> [!error] Each view owns a piece of navigation
> A path in one view's `@State`, the tab in another, the sheet in a third: a deep link can't reach them all. One router, bound from the root.

> [!error] Appending a deep link's routes to the current path
> The result depends on what the user had open. Replace the path in one assignment, so a link always produces the same stack.

> [!error] Navigating under a sheet
> If a sheet is up, changing the tab and path happens behind it, and the user sees nothing. Dismiss presented content first (`sheet = nil`), as `open(_:)` does.

> [!error] Links that perform actions
> `cookbook://recipes/42/delete` is something any web page or message can trigger. Links show things; changes need the user to confirm on screen.

> [!error] Crashing or half-restoring on bad saved data
> `try!` on decode, or restoring routes to deleted content. Decode with `try?`, fall back to the root, and trim invalid routes.

> [!error] Whole models in saved paths
> A `Route.recipe(Recipe)` saves a copy of the recipe in the scene's storage: stale after an edit, bigger than it needs to be, and possibly sensitive. Save ids.

## Exercises

````exercise
id: m35-l05-e1
type: prediction
prompt: "The lesson's parser, shortened to recipe and step links. What does it print?"
code: |
  import Foundation

  enum Route: Hashable {
      case category(String)
      case recipe(id: Int)
      case step(recipeID: Int, number: Int)
  }

  func path(from url: URL) -> [Route]? {
      guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "cookbook",
            let host = components.host?.lowercased(), host == "recipes" else { return nil }
      let parts = components.path.split(separator: "/").map(String.init)
      switch parts.count {
      case 0:
          return []
      case 1:
          return [.category(parts[0])]
      case 2:
          guard let id = Int(parts[1]), id > 0 else { return nil }
          return [.category(parts[0]), .recipe(id: id)]
      case 4 where parts[2] == "steps":
          guard let id = Int(parts[1]), let step = Int(parts[3]), id > 0, step > 0 else { return nil }
          return [.category(parts[0]), .recipe(id: id), .step(recipeID: id, number: step)]
      default:
          return nil
      }
  }

  for link in ["cookbook://Recipes/Soups", "cookbook://recipes/Soups/7/steps/2",
               "cookbook://recipes/Soups/7/step/2", "cookbook://recipes/Soups/-7", "cookbook://recipes"] {
      if let url = URL(string: link), let routes = path(from: url) {
          print(routes.count, routes.last.map { "\($0)" } ?? "root")
      } else {
          print("rejected")
      }
  }
output: |
  1 category("Soups")
  3 step(recipeID: 7, number: 2)
  rejected
  rejected
  0 root
hints:
  - "The host is lowercased before the comparison; the category in the path isn't."
  - "Look carefully at the third link's fourth part."
solution: |
  ```output
  1 category("Soups")
  3 step(recipeID: 7, number: 2)
  rejected
  rejected
  0 root
  ```

  `Recipes` is the host, which is lowercased, so the first link works and keeps `Soups` as typed. The step link produces three routes, with the step on top. The third link says `step`, not `steps`, so the `where` clause fails and it falls through to `default`. `-7` parses as an `Int` but fails `id > 0`. The bare `cookbook://recipes` has no path parts, so it's an empty path: the recipes root.
````

````exercise
id: m35-l05-e2
type: prediction
prompt: "A router that keeps one path per tab. What does this print?"
code: |
  enum Tab: String {
      case recipes, shopping
  }

  final class Router {
      var tab = Tab.recipes
      var paths: [Tab: [String]] = [.recipes: [], .shopping: []]
      var sheet: String?

      func open(tab: Tab, path: [String]) {
          sheet = nil
          self.tab = tab
          paths[tab] = path
      }

      func push(_ screen: String) {
          paths[tab, default: []].append(screen)
      }

      var onScreen: String {
          if let sheet { return "sheet \(sheet)" }
          return paths[tab]?.last ?? "\(tab) root"
      }
  }

  let router = Router()
  router.push("Desserts")
  router.push("Flan")
  router.tab = .shopping
  print(router.onScreen)
  router.sheet = "settings"
  print(router.onScreen)
  router.open(tab: .recipes, path: ["Soups"])
  print(router.onScreen)
  router.tab = .shopping
  router.push("Milk")
  router.tab = .recipes
  print(router.onScreen, router.paths[.shopping]?.count ?? 0)
output: |
  shopping root
  sheet settings
  Soups
  Soups 1
hints:
  - "Each tab keeps its own path; switching tabs doesn't clear anything."
  - "open replaces the recipes path; it doesn't append to it."
solution: |
  ```output
  shopping root
  sheet settings
  Soups
  Soups 1
  ```

  The two pushes go to the recipes path. Switching to shopping shows its empty root. A sheet covers whatever is underneath. `open` dismisses the sheet, selects recipes and **replaces** its path with `["Soups"]`, so Desserts and Flan are gone. Pushing Milk in the shopping tab doesn't touch the recipes path, so going back to recipes still shows Soups, and the shopping path has one screen.
````

````exercise
id: m35-l05-e3
type: comprehension
prompt: "Where should a SwiftUI app keep the encoded navigation path so that each window on iPad comes back to its own screen after the system terminates the app?"
choices:
  - text: "In @SceneStorage, one value per scene."
    correct: true
    why: "Apple: each Scene has its own SceneStorage, restored by the system, meant for lightweight data like this."
  - text: "In UserDefaults under one key."
    correct: false
    why: "UserDefaults is app-wide: two windows would overwrite each other's path."
  - text: "In @State in the root view."
    correct: false
    why: "@State lives as long as the view; it doesn't survive the app being terminated."
  - text: "In a file in the Documents folder, written on every change."
    correct: false
    why: "It's app-wide unless you key it by scene yourself, it outlives scenes the user closed, and Documents is for user data."
solution: |
  **`@SceneStorage`.** Navigation state belongs to a window, not to the app: two iPad windows can be on different recipes. `SceneStorage` is per scene, is restored by the system, and is destroyed when the user explicitly closes the scene, which matches what users expect. Apple's limits apply: keep it small, don't store sensitive data, and don't rely on it being written at any particular moment.
````

````exercise
id: m35-l05-e4
type: fill-in
prompt: "Complete the root view: handle incoming links with the router, and restore a NavigationPath from saved data."
code: |
  struct Root: View {
      @State private var router = Router()
      @State private var path = NavigationPath()
      @SceneStorage("path") private var saved: Data?

      var body: some View {
          NavigationStack(path: $path) {
              Text("Home")
          }
          .[[1]] { url in
              router.open(url)
          }
          .onAppear {
              guard let saved,
                    let representation = try? JSONDecoder().decode(NavigationPath.[[2]].self, from: saved)
              else { return }
              path = NavigationPath(representation)
          }
          .onDisappear {
              if let representation = path.[[3]] {
                  saved = try? JSONEncoder().encode(representation)
              }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["onOpenURL"]
  - id: "2"
    answers: ["CodableRepresentation"]
  - id: "3"
    answers: ["codable"]
hints:
  - "The modifier that receives custom-scheme URLs and universal links."
  - "The nested type that NavigationPath encodes to, and the property that produces it."
solution: |
  ```swift ios
  import SwiftUI

  @Observable
  final class Router {
      var lastURL: URL?
      func open(_ url: URL) { lastURL = url }
  }

  struct Root: View {
      @State private var router = Router()
      @State private var path = NavigationPath()
      @SceneStorage("path") private var saved: Data?

      var body: some View {
          NavigationStack(path: $path) {
              Text("Home")
          }
          .onOpenURL { url in
              router.open(url)
          }
          .onAppear {
              guard let saved,
                    let representation = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: saved)
              else { return }
              path = NavigationPath(representation)
          }
          .onDisappear {
              if let representation = path.codable {
                  saved = try? JSONEncoder().encode(representation)
              }
          }
      }
  }
  ```

  `onOpenURL` gets each URL, including universal links. `NavigationPath.CodableRepresentation` is what gets encoded and decoded, and `path.codable` produces it, or `nil` if something in the path isn't `Codable`. Saving in `onDisappear` is a simplification for the exercise: a root view rarely disappears, so the lesson saves on `scenePhase` changing to `.background`, as Apple's example does.
````

````exercise
id: m35-l05-e5
type: find-errors
prompt: "This deep-link handler was written quickly. Which of these are real problems?"
code: |
  func handle(_ url: URL) {
      let parts = url.absoluteString.components(separatedBy: "/")
      let id = Int(parts.last!)!
      router.recipesPath.append(.recipe(id: id))
      if parts.contains("delete") {
          store.deleteRecipe(id: id)
      }
  }
choices:
  - text: "It splits the absolute string by hand instead of using URLComponents, so scheme, host, query and percent-encoding aren't handled."
    correct: true
    why: "URLComponents separates the parts and decodes the path; string splitting treats https://host and custom schemes differently and keeps %20."
  - text: "Force unwraps crash the app on a link that doesn't end in a number."
    correct: true
    why: "Any app or web page can send a malformed link. Return nil and ignore it."
  - text: "It appends to the current path instead of replacing it, so the result depends on what was open (and any sheet stays on top)."
    correct: true
    why: "Replace the path in one assignment after dismissing presented content."
  - text: "A link can delete data without the user confirming."
    correct: true
    why: "Links should only show things. Show the recipe and let the user confirm a deletion on screen."
  - text: "URL can't be passed to a function."
    correct: false
    why: "URL is an ordinary value type."
rubric:
  - Flags the manual string parsing.
  - Flags the force unwraps.
  - Flags appending instead of replacing (and not dismissing).
  - Flags the destructive action.
solution: |
  Four problems, each fixed by the lesson's structure: a pure `DeepLink.destination(from:)` built on `URLComponents` that returns `nil` for anything unexpected (no force unwraps), and a router `open(_:)` that dismisses presented content, selects the tab and **assigns** the whole path. The parser has no case for delete, so the destructive link simply doesn't exist; if a link should lead to deleting something, it opens the recipe and the user taps Delete and confirms, as in lesson 3.
````

````exercise
id: m35-l05-e6
type: solve
prompt: |
  Write `func restoredPath(from data: Data?, existingRecipeIDs: Set<Int>) -> [Route]` that:

  1. Returns `[]` if `data` is `nil` or doesn't decode as `[Route]`.
  2. Otherwise keeps routes from the start up to, but not including, the first route that refers to a recipe that no longer exists (`.recipe(id:)` or `.step(recipeID:number:)` with an id not in the set). Categories are always valid.

  Test it with a saved path encoded from `[.category("Desserts"), .recipe(id: 42), .step(recipeID: 42, number: 3)]`, with existing ids `[42, 7]` and then `[7]`, with `nil` data, and with the bytes of the string `"not json"`. Print the number of routes and the last one (or `root`).
starter: |
  import Foundation

  enum Route: Hashable, Codable {
      case category(String)
      case recipe(id: Int)
      case step(recipeID: Int, number: Int)
  }

  func restoredPath(from data: Data?, existingRecipeIDs: Set<Int>) -> [Route] {
      // your code
      []
  }
hints:
  - "guard let data, let routes = try? JSONDecoder().decode([Route].self, from: data) else { return [] }"
  - "firstIndex(where:) finds the first invalid route; prefix(upTo:) keeps what's before it."
rubric:
  - Returns an empty path for nil or undecodable data without crashing.
  - Validates recipe and step routes against the set.
  - Cuts the path at the first invalid route, keeping everything before it.
  - Prints four lines matching the expected output.
solution: |
  ```swift
  import Foundation

  enum Route: Hashable, Codable {
      case category(String)
      case recipe(id: Int)
      case step(recipeID: Int, number: Int)
  }

  func restoredPath(from data: Data?, existingRecipeIDs: Set<Int>) -> [Route] {
      guard let data, let routes = try? JSONDecoder().decode([Route].self, from: data) else {
          return []
      }
      func isValid(_ route: Route) -> Bool {
          switch route {
          case .category:
              return true
          case .recipe(let id), .step(let id, _):
              return existingRecipeIDs.contains(id)
          }
      }
      guard let firstInvalid = routes.firstIndex(where: { !isValid($0) }) else {
          return routes
      }
      return Array(routes.prefix(upTo: firstInvalid))
  }

  func show(_ path: [Route]) {
      print(path.count, path.last.map { "\($0)" } ?? "root")
  }

  let saved = try? JSONEncoder().encode([Route.category("Desserts"), .recipe(id: 42), .step(recipeID: 42, number: 3)])
  show(restoredPath(from: saved, existingRecipeIDs: [42, 7]))
  show(restoredPath(from: saved, existingRecipeIDs: [7]))
  show(restoredPath(from: nil, existingRecipeIDs: [42]))
  show(restoredPath(from: Data("not json".utf8), existingRecipeIDs: [42]))
  ```

  ```output
  3 step(recipeID: 42, number: 3)
  1 category("Desserts")
  0 root
  0 root
  ```

  With recipe 42 present, the whole path comes back. Without it, the recipe route is the first invalid one, so the path is cut there: the user lands on the Desserts list, which still makes sense, instead of a "not found" screen with a step screen above it. `case .recipe(let id), .step(let id, _)` binds `id` from either case in one pattern. Bad or missing data gives the root, never a crash.
````

## Summary

- Give navigation one owner: a router (an `@Observable` class held in the root view's `@State`) with the tab, each tab's path and the presented sheet. Bind containers to it with `$router.property`; children call its methods.
- Parse URLs in a pure function with `URLComponents` into a destination: a tab plus the complete path of routes. Reject anything you don't recognize; links only show things.
- `onOpenURL` receives custom-scheme URLs and universal links. Apply a destination by dismissing presented content, selecting the tab and assigning the whole path.
- Save a `[Route]` path with `JSONEncoder` (`Route: Codable`) in `@SceneStorage`, and decode it with `try?`, falling back to the root. Renaming cases or labels breaks old data.
- `NavigationPath` saves through `path.codable` (`nil` if anything isn't `Codable`) and `NavigationPath(representation)`; the result is opaque, so prefer arrays when you need to validate.
- Validate restored routes and cut the path at the first one that no longer exists.
