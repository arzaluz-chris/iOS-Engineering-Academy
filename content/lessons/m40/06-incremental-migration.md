---
id: m40-l06
title: Migrating incrementally
description: "Moving a UIKit app to SwiftUI is a series of small, shippable steps, not a rewrite. You rank screens by how often they change and how many connections they have, decide which side owns navigation at each stage, route screens through one place so a single screen can move to SwiftUI and back, share colors, spacing and button styles between both frameworks, test logic below the UI and each framework's surface separately, and recognize the screens you should leave in UIKit."
module: m40
order: 6
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l05]
objectives:
  - Plan a screen-by-screen migration that keeps the app shippable at every step.
  - Choose which framework owns navigation at each stage and keep one owner per stack.
  - Route screens through a coordinator that can switch one screen's implementation, and roll it back.
  - Share design tokens and component styles between UIKit and SwiftUI.
  - Test logic, UIKit screens and SwiftUI screens at the right level during a migration.
  - Decide when a screen should stay in UIKit.
terms:
  - term: Incremental migration
    definition: "Replacing UIKit screens with SwiftUI one at a time, each change shipped on its own, with both frameworks running side by side for as long as the migration takes. Also called the strangler pattern."
  - term: Navigation owner
    definition: "The framework that holds a navigation stack: a UINavigationController (pushing hosting controllers) or a SwiftUI NavigationStack (pushing representables). Each stack has exactly one."
  - term: Screen routing
    definition: "Turning a Screen value into a concrete view controller or view in one place (a coordinator), so the rest of the app asks for 'order detail 7' without knowing which framework draws it."
  - term: Design token
    definition: "A named design value (a color, a spacing, a corner radius, a text style) defined once and read by both UIKit and SwiftUI code."
  - term: Leaf screen
    definition: "A screen that doesn't navigate anywhere else. It has the fewest connections to the rest of the app, which makes it the cheapest to migrate first."
mastery:
  - Rank a list of screens for migration and justify the order.
  - Say who owns navigation at the start, middle and end of a migration.
  - Write a coordinator that builds either a UIKit controller or a hosting controller for a screen based on a flag.
  - Expose brand colors and a primary button style to both frameworks from one definition.
  - Name the screens in an app that you'd wrap or leave in UIKit, and why.
resources: [swiftui-migrating-navigation, uikit-uinavigationcontroller, swiftui-navigationstack, uikit-button-configuration, swift-snapshot-testing, xcuiautomation, swift-testing-docs]
cards:
  - id: m40-l06-c1
    front: Which screens do you migrate to SwiftUI first?
    back: "New features, then leaf screens that change often: few connections (low risk), frequent edits (high payoff). Screens with many links, like a root list, come later; screens that nobody changes may never move."
  - id: m40-l06-c2
    front: Who should own navigation during a migration?
    back: "One owner per stack. While most screens are UIKit, the UIKit coordinator and UINavigationController own it and push hosting controllers. When most are SwiftUI, a NavigationStack owns it and pushes representables for the rest. Never a NavigationStack inside a UIKit-pushed screen."
  - id: m40-l06-c3
    front: Why route screens through one coordinator during a migration?
    back: "Callers ask for a Screen value; one place decides UIKit or SwiftUI. A per-screen flag can switch a migrated screen back without touching callers, and the decision is testable with a fake navigator."
  - id: m40-l06-c4
    front: How do you share brand colors between UIKit and SwiftUI?
    back: "Define them once, for example as named colors in the asset catalog read by UIColor(named:), and expose them to SwiftUI with Color(uiColor:), which preserves the color's adaptability (light and dark)."
  - id: m40-l06-c5
    front: When should a screen stay in UIKit?
    back: "When it's stable and rarely changes, when it depends on UIKit-only APIs or finely tuned UIKit behavior, or when SwiftUI's version would need a newer deployment target than you support. Wrap it if SwiftUI needs to show it."
---

## The idea in one sentence

**Migrate the way you'd refactor: one screen at a time, each step shipped and reversible**, with one owner for navigation and one definition of the design shared by both frameworks.

> [!note] About this lesson's code
> The planning model and the router were compiled and run with Swift 6.3. UIKit and SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. API behavior is quoted from Apple's pages for `Color(uiColor:)`, `UIColor(named:)`, `Color(_:bundle:)` and "Migrating to new navigation types", read in November 2026. The ranking rules and the migration strategy are engineering judgment, not Apple guidance; the lesson says so where it matters.

## Why not a rewrite

A rewrite stops feature work for months, ships everything at once, and rediscovers every edge case the old screens had already handled. An incremental migration keeps the app releasable every week: each SwiftUI screen goes out on its own, behind the same navigation, and a bad one can be switched back. Everything you need is in lessons 1 to 5: hosting controllers for SwiftUI inside UIKit, representables for UIKit inside SwiftUI, a shared `@Observable` model for state both sides show.

The cost is living with two frameworks for a long time. The rest of this lesson is about keeping that cost low.

## Which screens first

Two numbers per screen give a reasonable first order:

- **How often it changes.** Screens the team edits every sprint pay back the migration quickly. A screen nobody has touched in a year pays back nothing.
- **How many connections it has.** Each link to another screen, each delegate, each piece of shared state is an integration point between frameworks. A **leaf screen** (settings, a detail, an empty state, a promo banner) has few.

And two reasons to keep a screen in UIKit, at least for now:

- It depends on UIKit-only APIs or behavior that SwiftUI doesn't expose: wrap it, or leave it.
- It's stable and nobody changes it.

New features are the easiest case of all: they have no UIKit version to replace, so they start in SwiftUI.

This ranking is a judgment call, not a rule from Apple. Here it is as code, so the reasoning is explicit and the plan can be rerun when the numbers change:

```swift
struct ScreenInfo {
    let name: String
    let changesPerQuarter: Int
    let outgoingLinks: Int
    let needsUIKitOnlyAPI: Bool
}

enum Decision {
    case migrate
    case wrap(reason: String)
    case leave(reason: String)
}

func decide(_ screen: ScreenInfo) -> Decision {
    if screen.needsUIKitOnlyAPI {
        return .wrap(reason: "depends on UIKit-only API")
    }
    if screen.changesPerQuarter == 0 {
        return .leave(reason: "stable, nobody touches it")
    }
    return .migrate
}

func migrationOrder(_ screens: [ScreenInfo]) -> [ScreenInfo] {
    screens
        .filter { if case .migrate = decide($0) { return true } else { return false } }
        .sorted { lhs, rhs in
            if lhs.outgoingLinks != rhs.outgoingLinks {
                return lhs.outgoingLinks < rhs.outgoingLinks
            }
            if lhs.changesPerQuarter != rhs.changesPerQuarter {
                return lhs.changesPerQuarter > rhs.changesPerQuarter
            }
            return lhs.name < rhs.name
        }
}

let screens = [
    ScreenInfo(name: "Order list", changesPerQuarter: 5, outgoingLinks: 3, needsUIKitOnlyAPI: false),
    ScreenInfo(name: "Order detail", changesPerQuarter: 8, outgoingLinks: 1, needsUIKitOnlyAPI: false),
    ScreenInfo(name: "Settings", changesPerQuarter: 2, outgoingLinks: 0, needsUIKitOnlyAPI: false),
    ScreenInfo(name: "Promo banner", changesPerQuarter: 9, outgoingLinks: 0, needsUIKitOnlyAPI: false),
    ScreenInfo(name: "Receipt scanner", changesPerQuarter: 3, outgoingLinks: 0, needsUIKitOnlyAPI: true),
    ScreenInfo(name: "Legal", changesPerQuarter: 0, outgoingLinks: 0, needsUIKitOnlyAPI: false),
]

for (index, screen) in migrationOrder(screens).enumerated() {
    print("\(index + 1). \(screen.name) (links \(screen.outgoingLinks), changes \(screen.changesPerQuarter))")
}
for screen in screens {
    switch decide(screen) {
    case .migrate: continue
    case .wrap(let reason): print("wrap: \(screen.name), \(reason)")
    case .leave(let reason): print("leave: \(screen.name), \(reason)")
    }
}
```

```output
1. Promo banner (links 0, changes 9)
2. Settings (links 0, changes 2)
3. Order detail (links 1, changes 8)
4. Order list (links 3, changes 5)
wrap: Receipt scanner, depends on UIKit-only API
leave: Legal, stable, nobody touches it
```

- **Links first, then changes.** Leaves go first because they're cheap and safe, and among leaves the busiest goes first. The order list, with three links, goes last: by then most of its destinations are SwiftUI, and lesson 5's shared state is already in place.
- **The receipt scanner** uses the camera through `UIImagePickerController` (lesson 4). It stays UIKit and gets wrapped when a SwiftUI screen needs it.
- **Legal** hasn't changed in a quarter. Migrating it costs time and risks regressions for no benefit.

Real plans weigh more than two numbers (test coverage, crash rates, who knows the code), and this is a starting point to argue with, not a formula to obey.

## Who owns navigation

The question that shapes a migration more than any other. Lesson 1 gave the rule for a single screen: a stack has one owner. Over a whole migration, the owner changes once:

| Stage | Owner | SwiftUI screens are… | UIKit screens are… |
| --- | --- | --- | --- |
| Start (most screens UIKit) | `UINavigationController` driven by a UIKit coordinator (Module 25) | Hosting controllers, pushed and presented by the coordinator | View controllers, as before |
| End (most screens SwiftUI) | A SwiftUI `NavigationStack` with a path (Module 35) | Views | Wrapped with `UIViewControllerRepresentable` (lesson 4) |

The switch happens **per stack**, not per app. A tab whose screens are all SwiftUI can switch to a `NavigationStack` (hosted at the tab's root) while another tab is still a `UINavigationController`. What you avoid is two owners in one stack: a `NavigationStack` inside a hosting controller that a `UINavigationController` pushed, or UIKit pushing onto a navigation controller from inside a SwiftUI-owned stack.

For the end stage, Apple's article "Migrating to new navigation types" covers moving from `NavigationView` to `NavigationStack` and `NavigationSplitView` with a path you own, which is also the shape that makes deep links work (Module 35, lesson 5).

### One router, two implementations

During the start stage, the most useful structure is Module 25's navigator idea: callers ask for a **screen**, and one place decides how to build it. Add a set of migrated screen kinds, and one flag moves a screen to SwiftUI or back:

```swift
enum Screen: Equatable {
    case orders
    case orderDetail(id: Int)
    case settings
}

enum ScreenKind: Hashable {
    case orders, orderDetail, settings
}

extension Screen {
    var kind: ScreenKind {
        switch self {
        case .orders: return .orders
        case .orderDetail: return .orderDetail
        case .settings: return .settings
        }
    }
}

enum Implementation: String {
    case uikit, swiftui
}

protocol Navigator: AnyObject {
    func push(_ screen: Screen, as implementation: Implementation)
}

final class ShopFlow {
    private let navigator: any Navigator
    var migrated: Set<ScreenKind>

    init(navigator: any Navigator, migrated: Set<ScreenKind>) {
        self.navigator = navigator
        self.migrated = migrated
    }

    func show(_ screen: Screen) {
        let implementation: Implementation = migrated.contains(screen.kind) ? .swiftui : .uikit
        navigator.push(screen, as: implementation)
    }
}

final class FakeNavigator: Navigator {
    private(set) var log: [String] = []

    func push(_ screen: Screen, as implementation: Implementation) {
        log.append("\(implementation.rawValue) \(screen)")
    }
}

let navigator = FakeNavigator()
let flow = ShopFlow(navigator: navigator, migrated: [.settings, .orderDetail])
flow.show(.orders)
flow.show(.orderDetail(id: 7))
flow.migrated.remove(.orderDetail)   // a bug report: roll back one screen
flow.show(.orderDetail(id: 7))
flow.show(.settings)

for entry in navigator.log {
    print(entry)
}
```

```output
uikit orders
swiftui orderDetail(id: 7)
uikit orderDetail(id: 7)
swiftui settings
```

The callers never change: whoever wants an order detail calls `show(.orderDetail(id: 7))`. When the new SwiftUI detail has a problem in production, removing `.orderDetail` from the set (from a remote configuration, for example) puts the UIKit version back without a release that touches every caller. Keep the old screen until the new one has shipped and settled; delete it after.

The UIKit side of the same router, building either a legacy controller or a hosting controller:

```swift ios
import SwiftUI
import UIKit

enum Screen: Equatable {
    case orders
    case orderDetail(id: Int)
}

enum ScreenKind: Hashable {
    case orders, orderDetail
}

struct OrderDetailView: View {
    let orderID: Int
    let onTrackPackage: () -> Void

    var body: some View {
        List {
            Section("Order \(String(orderID))") {
                Text("Shipped")
                Button("Track Package", action: onTrackPackage)
            }
        }
    }
}

final class LegacyOrderDetailViewController: UIViewController {
    let orderID: Int
    var onTrackPackage: (() -> Void)?

    init(orderID: Int) {
        self.orderID = orderID
        super.init(nibName: nil, bundle: nil)
        title = "Order \(orderID)"
    }

    required init?(coder: NSCoder) {
        fatalError("LegacyOrderDetailViewController is created in code")
    }
}

final class LegacyOrdersViewController: UIViewController {}

@MainActor
final class ShopCoordinator {
    private let navigationController: UINavigationController
    var migrated: Set<ScreenKind>

    init(navigationController: UINavigationController, migrated: Set<ScreenKind>) {
        self.navigationController = navigationController
        self.migrated = migrated
    }

    func show(_ screen: Screen) {
        navigationController.pushViewController(makeViewController(for: screen), animated: true)
    }

    private func makeViewController(for screen: Screen) -> UIViewController {
        switch screen {
        case .orders:
            return LegacyOrdersViewController()
        case .orderDetail(let id):
            return makeOrderDetail(id: id)
        }
    }

    private func makeOrderDetail(id: Int) -> UIViewController {
        guard migrated.contains(.orderDetail) else {
            let legacy = LegacyOrderDetailViewController(orderID: id)
            legacy.onTrackPackage = { [weak self] in self?.trackPackage(orderID: id) }
            return legacy
        }
        let view = OrderDetailView(orderID: id, onTrackPackage: { [weak self] in
            self?.trackPackage(orderID: id)
        })
        let host = UIHostingController(rootView: view)
        host.title = "Order \(id)"
        return host
    }

    private func trackPackage(orderID: Int) {
        // Present tracking, in whichever framework it's in today.
    }
}
```

Both versions report "track package" through a closure with the same meaning, so the coordinator's own logic doesn't fork. That symmetry is worth designing for: when the SwiftUI screen's events match the UIKit screen's, switching is a one-line decision.

## Bridging the design system

Two frameworks drawing the same app must look like one app. The way to get there is to **define each design decision once** and give each framework an accessor for it.

**Colors.** Named colors in the asset catalog are already shared: `UIColor(named:)` and SwiftUI's `Color(_:bundle:)` ("Creates a color from a color set that you indicate by name") both read them, with their light and dark variants. To have one Swift entry point, define the UIKit accessor and build SwiftUI's from it with `Color(uiColor:)`, which Apple says "preserves the adaptability of the original."

**Spacing, radii, text styles.** Plain constants in one file, read by both. Use Dynamic Type text styles on both sides (`.preferredFont(forTextStyle:)` in UIKit, `.font(.body)` in SwiftUI) so sizes match and both respond to the user's setting.

**Components.** A primary button exists twice during a migration. Give both versions the same tokens:

```swift ios
import SwiftUI
import UIKit

enum BrandColor: String {
    case accent = "BrandAccent"
    case surface = "BrandSurface"
}

enum BrandMetrics {
    static let cornerRadius: CGFloat = 12
    static let buttonVerticalPadding: CGFloat = 14
    static let spacing: CGFloat = 16
}

extension UIColor {
    static func brand(_ color: BrandColor) -> UIColor {
        UIColor(named: color.rawValue) ?? .systemOrange
    }
}

extension Color {
    static func brand(_ color: BrandColor) -> Color {
        Color(uiColor: .brand(color))
    }
}

extension UIButton.Configuration {
    static func brandPrimary(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .brand(.accent)
        configuration.baseForegroundColor = .white
        configuration.background.cornerRadius = BrandMetrics.cornerRadius
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: BrandMetrics.buttonVerticalPadding,
            leading: BrandMetrics.spacing,
            bottom: BrandMetrics.buttonVerticalPadding,
            trailing: BrandMetrics.spacing
        )
        return configuration
    }
}

struct BrandPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, BrandMetrics.buttonVerticalPadding)
            .padding(.horizontal, BrandMetrics.spacing)
            .frame(maxWidth: .infinity)
            .background(Color.brand(.accent), in: RoundedRectangle(cornerRadius: BrandMetrics.cornerRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

@MainActor
func makeCheckoutButton() -> UIButton {
    UIButton(configuration: .brandPrimary(title: "Check Out"))
}

struct CheckoutBar: View {
    var body: some View {
        Button("Check Out") {}
            .buttonStyle(BrandPrimaryButtonStyle())
            .padding(BrandMetrics.spacing)
    }
}
```

- `UIColor.brand(_:)` is the one place that knows how a brand color is stored. The fallback, `.systemOrange`, only matters if the asset is missing; a unit test that checks `UIColor(named:)` for every case catches that early.
- `UIButton.Configuration` (Module 24) and SwiftUI's `ButtonStyle` are each framework's styling mechanism for buttons. `ButtonStyle` is new here: a protocol whose `makeBody(configuration:)` receives the button's label and pressed state and returns the styled view; `.buttonStyle(_:)` applies it to every button below. Both read the same `BrandMetrics` and `BrandColor`, so a change to the corner radius changes both.
- `BrandColor` and `BrandMetrics` are where a design system starts. When the migration ends, the UIKit half is deleted and the tokens stay.

The other bridging option is to share **one implementation**: host the SwiftUI button in UIKit, or wrap the UIKit one for SwiftUI. That's right for complex components (a chart, a rich editor). For small, frequently used ones like buttons, two native implementations over shared tokens behave better: each gets its framework's accessibility, layout and interaction behavior.

## Testing both sides

A migration changes how screens are drawn. Tests should make sure it doesn't change what they do:

- **Logic below the UI** (models, view models, coordinators, routers) is plain Swift and framework-neutral. The `ShopFlow` test above doesn't care whether order detail is UIKit or SwiftUI. Write these tests **before** migrating a screen, against the UIKit version, and keep them passing after: they're the contract the new screen must meet.
- **UIKit screens** keep the tests they had (Module 33).
- **SwiftUI screens** are hosted in a `UIHostingController` for snapshot tests, as Module 39, lesson 6 did with swift-snapshot-testing. Snapshots of the old and new version of a screen, side by side, are a fast visual review of a migration.
- **UI tests** query the accessibility hierarchy, which both frameworks produce. Give elements the same accessibility identifiers in the UIKit and SwiftUI versions (`accessibilityIdentifier` in UIKit, `.accessibilityIdentifier(_:)` in SwiftUI), and the same UI test runs against either implementation. Flip the routing flag in the test's launch arguments to test both while both exist.

## When not to migrate

Migration is a means. Leave a screen in UIKit when:

- **It's stable.** No planned changes means no payoff.
- **It depends on UIKit-only APIs or UIKit-specific tuning**: camera capture through `UIImagePickerController`, a custom text system, a collection view layout tuned for scrolling performance. Wrap it when SwiftUI needs to show it.
- **The SwiftUI equivalent needs a newer iOS than you support.** Raising the deployment target is a product decision, not a migration step.
- **The team is mid-crunch.** Migrating a screen during a deadline mixes two kinds of risk.

And keep UIKit knowledge on the team either way. Every SwiftUI app still meets UIKit through representables, app delegates and system controllers, and many teams run hybrid apps for years.

## Common mistakes

> [!error] Starting with the root screen
> The root list links to everything, so migrating it first means every destination becomes a cross-framework hop at once. Start at the leaves.

> [!error] Two navigation owners in one stack
> A `NavigationStack` inside a hosting controller that UIKit pushed, or UIKit pushing from inside a SwiftUI stack, gives two independent histories in one place, and neither side's back button or deep-link code knows about the other's. One owner per stack; switch whole stacks.

> [!error] Callers that construct screens directly
> If twenty places write `UIHostingController(rootView: OrderDetailView(…))`, rolling back means twenty edits. Route through one coordinator and a `Screen` value.

> [!error] Hard-coding colors in the new SwiftUI screens
> `Color(red: 1, green: 0.58, blue: 0)` in a new screen and an asset color in the old one drift apart, and the literal ignores dark mode. Read tokens through one accessor.

> [!error] Deleting the UIKit screen in the same release
> Keep it behind the flag until the SwiftUI version has shipped and settled, so a rollback is a configuration change.

## Exercises

````exercise
id: m40-l06-e1
type: comprehension
prompt: "A UIKit banking app starts its migration. Which screen should go to SwiftUI first?"
choices:
  - text: "The account settings screen: no outgoing links and edited almost every sprint."
    correct: true
    why: "A leaf that changes often: low risk, quick payoff."
  - text: "The home screen, because every user sees it."
    correct: false
    why: "It links to almost everything, so it has the most integration points. It goes last."
  - text: "The check-deposit camera screen, because it's the oldest code."
    correct: false
    why: "Camera capture is UIImagePickerController's job; wrap it rather than rewrite it."
  - text: "The terms-of-service screen, because it's the simplest."
    correct: false
    why: "Simple, but if nobody changes it, migrating it buys nothing."
solution: |
  **Account settings.** It has no outgoing links, so nothing else has to cross the framework boundary because of it, and it changes often, so the team gets SwiftUI's benefits on code it actually edits. The home screen comes last, the camera screen gets wrapped, and the terms screen can stay in UIKit indefinitely.
````

````exercise
id: m40-l06-e2
type: prediction
prompt: "The router from the lesson with a different sequence of flag changes. What does it print?"
code: |
  enum Screen: Equatable {
      case orders
      case orderDetail(id: Int)
      case settings
  }

  enum ScreenKind: Hashable {
      case orders, orderDetail, settings
  }

  extension Screen {
      var kind: ScreenKind {
          switch self {
          case .orders: return .orders
          case .orderDetail: return .orderDetail
          case .settings: return .settings
          }
      }
  }

  final class ShopFlow {
      var migrated: Set<ScreenKind>
      private(set) var log: [String] = []

      init(migrated: Set<ScreenKind>) {
          self.migrated = migrated
      }

      func show(_ screen: Screen) {
          let framework = migrated.contains(screen.kind) ? "swiftui" : "uikit"
          log.append("\(framework) \(screen)")
      }
  }

  let flow = ShopFlow(migrated: [])
  flow.show(.settings)
  flow.migrated.insert(.settings)
  flow.show(.settings)
  flow.migrated.insert(.orderDetail)
  flow.show(.orderDetail(id: 2))
  flow.show(.orders)
  flow.migrated = [.orders]
  flow.show(.orderDetail(id: 3))
  flow.show(.orders)
  print(flow.log.joined(separator: "\n"))
  print(flow.log.filter { $0.hasPrefix("swiftui") }.count)
output: |
  uikit settings
  swiftui settings
  swiftui orderDetail(id: 2)
  uikit orders
  uikit orderDetail(id: 3)
  swiftui orders
  3
hints:
  - "The decision happens at each show call, with the set as it is at that moment."
  - "flow.migrated = [.orders] replaces the whole set."
solution: |
  ```output
  uikit settings
  swiftui settings
  swiftui orderDetail(id: 2)
  uikit orders
  uikit orderDetail(id: 3)
  swiftui orders
  3
  ```

  Each `show` reads the set at that moment. Settings moves to SwiftUI after its flag is added; order detail follows; orders is still UIKit until the assignment replaces the whole set with `[.orders]`, which also rolls back settings and order detail. Three of the six pushes were SwiftUI. Replacing a set when you meant to insert is an easy way to roll back more than you intended, which is one reason to keep flags in one place and test them like this.
````

````exercise
id: m40-l06-e3
type: prediction
prompt: "The planning model from the lesson with a different app. What does it print?"
code: |
  struct ScreenInfo {
      let name: String
      let changesPerQuarter: Int
      let outgoingLinks: Int
      let needsUIKitOnlyAPI: Bool
  }

  func isCandidate(_ screen: ScreenInfo) -> Bool {
      !screen.needsUIKitOnlyAPI && screen.changesPerQuarter > 0
  }

  func migrationOrder(_ screens: [ScreenInfo]) -> [String] {
      screens
          .filter(isCandidate)
          .sorted { lhs, rhs in
              if lhs.outgoingLinks != rhs.outgoingLinks {
                  return lhs.outgoingLinks < rhs.outgoingLinks
              }
              if lhs.changesPerQuarter != rhs.changesPerQuarter {
                  return lhs.changesPerQuarter > rhs.changesPerQuarter
              }
              return lhs.name < rhs.name
          }
          .map(\.name)
  }

  let screens = [
      ScreenInfo(name: "Feed", changesPerQuarter: 12, outgoingLinks: 4, needsUIKitOnlyAPI: false),
      ScreenInfo(name: "Profile", changesPerQuarter: 4, outgoingLinks: 1, needsUIKitOnlyAPI: false),
      ScreenInfo(name: "Notifications", changesPerQuarter: 4, outgoingLinks: 1, needsUIKitOnlyAPI: false),
      ScreenInfo(name: "Composer", changesPerQuarter: 6, outgoingLinks: 0, needsUIKitOnlyAPI: true),
      ScreenInfo(name: "About", changesPerQuarter: 0, outgoingLinks: 0, needsUIKitOnlyAPI: false),
      ScreenInfo(name: "Badges", changesPerQuarter: 1, outgoingLinks: 0, needsUIKitOnlyAPI: false),
  ]
  print(migrationOrder(screens))
  print(screens.filter { !isCandidate($0) }.map(\.name))
output: |
  ["Badges", "Notifications", "Profile", "Feed"]
  ["Composer", "About"]
hints:
  - "Fewest links first; ties broken by more changes, then by name."
  - "Profile and Notifications tie on both numbers."
solution: |
  ```output
  ["Badges", "Notifications", "Profile", "Feed"]
  ["Composer", "About"]
  ```

  Composer is excluded for its UIKit-only dependency and About for having no changes. Badges is the only remaining leaf. Profile and Notifications tie on links (1) and changes (4), so the name breaks the tie and Notifications comes first. Feed, with four links, goes last despite changing the most. A plan like this is a conversation starter: the team might move Feed earlier because it changes so often, and should say so explicitly when they do.
````

````exercise
id: m40-l06-e4
type: solve
prompt: |
  Write a migration progress report in plain Swift. Given screens with a `name`, a `status` (`uikit`, `hosted`, `swiftUI`, `wrapped`) and a `stack` name, print for each stack:

  - how many screens are in each framework (`hosted` counts as SwiftUI drawn inside UIKit navigation; `wrapped` counts as UIKit drawn inside SwiftUI navigation),
  - and a recommendation: "UIKit owns navigation" if at least half the screens are UIKit-drawn, otherwise "ready for NavigationStack".

  Use this data and print the stacks in alphabetical order:

  ```swift
  let screens = [
      ("Orders", "orders", "uikit"), ("Order detail", "orders", "hosted"), ("Tracking", "orders", "uikit"),
      ("Settings", "account", "hosted"), ("Profile", "account", "hosted"), ("Avatar camera", "account", "uikit"),
  ]
  ```
starter: |
  enum Status: String {
      case uikit, hosted, swiftUI, wrapped
  }

  struct MigrationScreen {
      let name: String
      let stack: String
      let status: Status
  }

  // your code
hints:
  - "Dictionary(grouping:by:) groups screens by stack."
  - "uikit and wrapped are drawn by UIKit; hosted and swiftUI are drawn by SwiftUI."
rubric:
  - Groups by stack and prints stacks in a stable order.
  - Classifies each status as UIKit-drawn or SwiftUI-drawn.
  - Applies the at-least-half rule for the recommendation.
  - Output is deterministic.
solution: |
  ```swift
  enum Status: String {
      case uikit, hosted, swiftUI, wrapped

      var isDrawnByUIKit: Bool {
          self == .uikit || self == .wrapped
      }
  }

  struct MigrationScreen {
      let name: String
      let stack: String
      let status: Status
  }

  let data = [
      ("Orders", "orders", "uikit"), ("Order detail", "orders", "hosted"), ("Tracking", "orders", "uikit"),
      ("Settings", "account", "hosted"), ("Profile", "account", "hosted"), ("Avatar camera", "account", "uikit"),
  ]
  let screens = data.compactMap { name, stack, status in
      Status(rawValue: status).map { MigrationScreen(name: name, stack: stack, status: $0) }
  }

  let byStack = Dictionary(grouping: screens, by: \.stack)
  for stack in byStack.keys.sorted() {
      let members = byStack[stack] ?? []
      let uikitCount = members.filter(\.status.isDrawnByUIKit).count
      let swiftUICount = members.count - uikitCount
      let recommendation = uikitCount * 2 >= members.count ? "UIKit owns navigation" : "ready for NavigationStack"
      print("\(stack): \(uikitCount) UIKit, \(swiftUICount) SwiftUI -> \(recommendation)")
  }
  ```

  ```output
  account: 1 UIKit, 2 SwiftUI -> ready for NavigationStack
  orders: 2 UIKit, 1 SwiftUI -> UIKit owns navigation
  ```

  - The account stack is mostly SwiftUI already. Switching it to a `NavigationStack` (hosted at the tab root) would turn Settings and Profile into plain views and the avatar camera into a wrapped controller.
  - The orders stack stays with its `UINavigationController` for now.
  - `uikitCount * 2 >= members.count` is "at least half" without division. The threshold itself is a judgment call; the point is to make the decision per stack, from data, instead of per app.
````

````exercise
id: m40-l06-e5
type: design
prompt: "A five-year-old UIKit recipe app has a tab bar with Browse (a compositional-layout grid of recipes, a recipe detail, a step-by-step cooking mode that keeps the screen awake and uses a custom timer view) and Account (profile, settings, subscription management, legal pages). The team wants to adopt SwiftUI over the next year without a release freeze. Write a migration plan: the order, who owns navigation in each tab at each stage, how you share the design and state, how you test, and what you'd leave in UIKit."
rubric:
  - Starts with leaf screens that change often (settings, profile, recipe detail sections), not the Browse grid.
  - Keeps one navigation owner per tab and says when a tab switches to NavigationStack.
  - Routes screens through a coordinator with per-screen flags for rollback.
  - Shares state through @Observable models with one owner and design through shared tokens.
  - Tests logic below the UI before and after each screen, plus snapshots or UI tests with shared identifiers.
  - Names screens to wrap or leave (the tuned grid, the custom timer view, legal pages) with reasons.
solution: |
  A plan that works:

  - **Foundation first (weeks 1–2).** Introduce a `Screen` enum and route both tabs' navigation through coordinators that can build a hosting controller or a UIKit controller per screen, with flags. Add `BrandColor`, `BrandMetrics` and text styles, with UIKit and SwiftUI accessors. Move shared data (the user, favorites, the subscription state) into `@MainActor @Observable` models owned by the scene delegate's dependency container. Write model and coordinator tests against the current UIKit behavior.
  - **Account tab (months 1–3).** Settings, then profile, then subscription management, each as a hosted SwiftUI screen pushed by the UIKit coordinator, each behind a flag. When all but the legal pages are SwiftUI, switch the Account tab's root to a hosting controller with a `NavigationStack` and a path; legal pages stay as wrapped UIKit (or move later; they rarely change, so there's no hurry).
  - **Browse tab, inside out (months 3–9).** Recipe detail first, as a hosted screen. Inside the grid, move cell content to `UIHostingConfiguration` if the cells change often, keeping the compositional layout, which is tuned and works. Cooking mode: rewrite its UI in SwiftUI only if it's on the roadmap; wrap the custom timer view with `UIViewRepresentable` and a coordinator rather than rewriting it. Browse keeps its `UINavigationController` as long as the grid is UIKit.
  - **Testing throughout.** Model and coordinator tests are written before each screen moves and must pass after. Snapshot tests host each new SwiftUI screen in a `UIHostingController`, compared with the old screen's snapshot during review. UI tests use the same accessibility identifiers in both versions and run with the flag on and off.
  - **Leave in UIKit.** The recipe grid's layout (tuned, stable), the timer view (wrapped), legal pages (stable). Revisit in a year with the same ranking: changes per quarter and links.
  - **Release discipline.** One screen per release behind its flag; old screens deleted only after the new ones have been stable for a release or two.
````

## Summary

- Migrate screen by screen, shipping each step. New features start in SwiftUI; existing screens go leaves first, busiest first. Wrap screens that depend on UIKit-only APIs, and leave stable screens alone.
- Each navigation stack has one owner. Early on, UIKit coordinators push hosting controllers; once a stack is mostly SwiftUI, a `NavigationStack` owns it and wraps the remaining UIKit screens. Switch stacks, not the whole app at once.
- Route screens through one coordinator that turns a `Screen` value into a UIKit or SwiftUI implementation. A per-screen flag makes each migration reversible, and the routing logic is testable with a fake.
- Define design tokens once (named colors, metrics, text styles) and give both frameworks accessors; `Color(uiColor:)` keeps a color's light and dark variants. Small components get two native implementations over the same tokens; complex ones get bridged.
- Test the logic below the UI before and after each screen moves, snapshot hosted SwiftUI screens, and give both versions the same accessibility identifiers so UI tests cover either.
- Keep UIKit skills on the team: representables, app delegates and system controllers stay part of every SwiftUI app.
