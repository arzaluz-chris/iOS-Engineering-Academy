---
id: m40-l01
title: Hosting SwiftUI in UIKit
description: "UIHostingController is a view controller whose view is a SwiftUI hierarchy, so anything UIKit does with view controllers it can do with SwiftUI. You push one, present one as a sheet, and embed one as a child with Auto Layout, choosing sizingOptions so its height follows its content. You pass data in through the root view or a shared model, get events out through closures without a retain cycle, and put SwiftUI inside collection view cells with UIHostingConfiguration."
module: m40
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m39-l06]
objectives:
  - Push and present a SwiftUI screen from UIKit with UIHostingController.
  - Embed a hosting controller as a child view controller with Auto Layout and pick the right sizingOptions.
  - Pass data into a hosted view and explain why a value passed once goes stale.
  - Get events out of a hosted view through closures without creating a retain cycle.
  - Fill collection view cells with SwiftUI using UIHostingConfiguration.
terms:
  - term: UIHostingController
    definition: "A UIKit view controller that manages a SwiftUI view hierarchy. You give it a root view at creation and can replace it later through its rootView property. It's pushed, presented or embedded like any other view controller."
  - term: rootView
    definition: "The hosting controller's stored SwiftUI view value. Because a View is usually a struct, the controller holds its own copy; changing the data you created it from doesn't change what it shows."
  - term: sizingOptions
    definition: "A UIHostingControllerSizingOptions set (iOS 16) that says how the hosting controller tracks its content's size: .intrinsicContentSize for Auto Layout, .preferredContentSize for containers that read preferredContentSize. The default is the empty set."
  - term: UIHostingConfiguration
    definition: "A content configuration (iOS 16) that hosts SwiftUI views inside a UICollectionViewCell or UITableViewCell. You assign it to the cell's contentConfiguration."
  - term: Event closure
    definition: "A closure property on a SwiftUI view, like onSave: (String) -> Void, that the UIKit owner fills in. It's how a hosted view reports what the user did without knowing who's listening."
mastery:
  - Push a hosting controller onto a navigation controller and present one as a sheet with detents.
  - Add a hosting controller as a child with addChild, addSubview, constraints and didMove(toParent:), in that order.
  - Set sizingOptions to .intrinsicContentSize for a hosted view inside Auto Layout and explain the cost.
  - Predict what a hosted view shows after the UIKit side changes its own copy of the data.
  - Wire Save and Cancel closures from a hosted form to the presenting view controller with [weak self].
  - Configure a list cell with UIHostingConfiguration and adjust its margins.
resources: [uikit-custom-container, uikit-uinavigationcontroller, uikit-sheet-presentation, uikit-intrinsic-content-size, uikit-cell-registration, swift-book-arc]
cards:
  - id: m40-l01-c1
    front: How do you show a SwiftUI view from a UIKit view controller?
    back: "Wrap it: UIHostingController(rootView: MyView()). Then use it like any view controller: pushViewController, present, or addChild plus addSubview plus didMove(toParent:)."
  - id: m40-l01-c2
    front: A hosted SwiftUI view inside Auto Layout keeps its first height when its content grows. What's missing?
    back: "sizingOptions = [.intrinsicContentSize] (iOS 16). The default is the empty set; with the option, the hosting view invalidates its intrinsic content size when its ideal size changes. Apple notes it has a performance cost."
  - id: m40-l01-c3
    front: "You created UIHostingController(rootView: Summary(count: count)) and later changed count. Why doesn't the screen update?"
    back: "The root view is a struct, and the controller stored its own copy. Either assign a new rootView, or pass a shared @Observable model whose properties the view reads."
  - id: m40-l01-c4
    front: How does a hosted SwiftUI form tell its UIKit presenter that the user tapped Save?
    back: "Through a closure property on the view, such as onSave: (Draft) -> Void, filled in by the presenter with [weak self]. Without weak, presenter → hosting controller → rootView → closure → presenter is a cycle."
  - id: m40-l01-c5
    front: How do you put SwiftUI inside a UICollectionView cell?
    back: "cell.contentConfiguration = UIHostingConfiguration { …views… } (iOS 16), usually inside a CellRegistration handler. Modifiers like .margins(_:_:), .background(_:) and .minSize(width:height:) adjust the cell."
---

## The idea in one sentence

**`UIHostingController` is an ordinary view controller whose view happens to be SwiftUI**, so you add SwiftUI to a UIKit app with the tools you already know: push, present, and child view controllers.

> [!note] About this lesson's code
> UIKit and SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior is quoted from Apple's pages for `UIHostingController`, `rootView`, `sizingOptions`, `UIHostingControllerSizingOptions`, `safeAreaRegions`, `UIHostingConfiguration` and its modifiers, read in November 2026. The plain-Swift models (the copied root view and the retain cycle) were compiled and run with Swift 6.3; they model the documented behavior, not SwiftUI's implementation. Nothing was run in the simulator.

## Where you are

You know both halves. Modules 22 and 25 built UIKit screens, navigation controllers, sheets, result closures and coordinators. Modules 34 to 39 built SwiftUI views, state and layout. Most iOS teams with an app older than a few years have both in one codebase, and the usual direction is this one: **a UIKit app that starts writing new screens in SwiftUI**. This lesson is the bridge in that direction. Lessons 2 to 4 go the other way.

## UIHostingController

Apple's description: "A UIKit view controller that manages a SwiftUI view hierarchy." And how to use it: "At creation time, specify the SwiftUI view you want to use as the root view for this view controller; you can change that view later using the `rootView` property. Use the hosting controller like you would any other view controller, by presenting it or embedding it as a child view controller in your interface."

It's a generic class, `UIHostingController<Content> where Content: View`, and it's `@MainActor` like every UIKit controller. The `Content` type is your root view's type, so `UIHostingController<ProfileView>` is a different type from `UIHostingController<SettingsView>`.

### Pushing and presenting

```swift ios
import SwiftUI
import UIKit

struct ProfileView: View {
    let name: String
    let memberSince: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 64))
            Text(name)
                .font(.title2)
            Text("Member since \(String(memberSince))")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

final class AccountViewController: UIViewController {
    func showProfile() {
        let profile = ProfileView(name: "Christian", memberSince: 2024)
        let hosting = UIHostingController(rootView: profile)
        hosting.title = "Profile"
        navigationController?.pushViewController(hosting, animated: true)
    }

    func presentProfile() {
        let profile = ProfileView(name: "Christian", memberSince: 2024)
        let hosting = UIHostingController(rootView: profile)
        if let sheet = hosting.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(hosting, animated: true)
    }
}
```

- **`UIHostingController(rootView:)`** creates the controller. Its `view` is a UIKit view that renders the SwiftUI hierarchy.
- **`hosting.title`** sets the title the navigation bar shows, the same way you'd set it on any controller in Module 25. The navigation bar belongs to the `UINavigationController`, which is UIKit's, so configure it the UIKit way. (Whether `.navigationTitle` inside the hosted view also reaches the UIKit bar wasn't verified for this lesson; setting `title` is the documented route.)
- **`sheetPresentationController`** and detents work exactly as in Module 25, lesson 3, because the presented object is a view controller.
- `String(memberSince)` passes the year as plain text. Interpolating an `Int` straight into a `Text` string literal formats it as a number for the user's locale, which can add a grouping separator to a year.

### Inside a navigation stack: who owns the bar

The pushed SwiftUI view must not create its own `NavigationStack`. The UIKit navigation controller already owns the stack, the bar and the back button. A `NavigationStack` inside the hosted view would start a second, independent stack inside one screen. Lesson 6 is about choosing which side owns navigation; for now the rule is: **if UIKit pushed it, UIKit owns navigation**, and the hosted view reports "the user wants to go to X" through a closure (later in this lesson).

## Embedding as a child

When SwiftUI is only part of a screen, a summary card above a UIKit table for example, embed the hosting controller as a child view controller. This is the containment API from Apple's "Creating a custom container view controller", in its required order:

```swift ios
import SwiftUI
import UIKit

struct OrderSummary: View {
    let itemCount: Int
    let total: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(itemCount) items")
                .font(.headline)
            Text(total)
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

final class CartViewController: UIViewController {
    private let summaryHost: UIHostingController<OrderSummary>

    init(itemCount: Int, total: String) {
        summaryHost = UIHostingController(rootView: OrderSummary(itemCount: itemCount, total: total))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("CartViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        summaryHost.sizingOptions = [.intrinsicContentSize]
        summaryHost.view.backgroundColor = .clear

        addChild(summaryHost)
        summaryHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryHost.view)
        NSLayoutConstraint.activate([
            summaryHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            summaryHost.view.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            summaryHost.view.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
        summaryHost.didMove(toParent: self)
    }

    func cartDidChange(itemCount: Int, total: String) {
        summaryHost.rootView = OrderSummary(itemCount: itemCount, total: total)
    }
}
```

Line by line:

- `addChild(summaryHost)` "creates a parent-child relationship", which Apple calls "necessary when embedding the child view controller's view into the current view controller's content."
- `translatesAutoresizingMaskIntoConstraints = false`, then `addSubview`, then constraints: the Auto Layout routine from Module 23. There's **no height constraint**. The hosted view's height comes from its content.
- `didMove(toParent: self)` finishes the transition. Apple: a container "must call the `didMove(toParent:)` method of the child view controller after the transition to the new controller is complete or, if there is no transition, immediately after calling the `addChild(_:)` method." It's the step people forget, because the view shows up fine without it.
- `view.backgroundColor = .clear` makes sure the hosting view draws no background of its own behind the card, so the material shows what's behind it. Whether you need it depends on the design.
- `cartDidChange` replaces the root view with a new value. More on that below.

### sizingOptions: letting Auto Layout follow the content

With top, leading and trailing pinned and no height, Auto Layout needs the hosted view's **intrinsic content size** (Module 23). That's what `sizingOptions` controls. Apple's page for the property: "The options for how the hosting controller tracks changes to the size of its SwiftUI content." And: "The default value is the empty set."

The two options, both iOS 16:

| Option | Apple's description | Use it when |
| --- | --- | --- |
| `.intrinsicContentSize` | "The hosting controller's view automatically invalidate its intrinsic content size when its ideal size changes." | The hosted view is laid out with Auto Layout, as in `CartViewController` |
| `.preferredContentSize` | "The hosting controller tracks its content's ideal size in its preferred content size." | A container reads the child's `preferredContentSize`: a popover, a sheet sized to fit, a custom container |

Both pages carry the same note: "This option comes with a performance cost because it asks for the ideal size of the content using the unspecified size proposal." That's the `.unspecified` proposal from Module 34, lesson 6: "how big do you want to be with no constraints?" For a small card it's nothing. For a large, frequently changing hierarchy, prefer giving the hosted view a fixed or constrained size.

Without the option, the symptom is specific: the card shows at the right size the first time, then the number of lines changes (a longer total, a bigger Dynamic Type size) and the card **doesn't grow**, clipping or overlapping the content below.

Two related tools:

- `sizeThatFits(in:)` on the hosting controller "calculates and returns the most appropriate size for the current view" for a proposed `CGSize`. Use it when you lay out by hand and need to ask once.
- `safeAreaRegions` (iOS 16.4): "The safe area regions that this view controller adds to its view." The default is `.all`. Apple's example of turning it off: "hosting content that you know should never be affected by the safe area, such as a custom scrollable container."

## Data in: the root view is a copy

`OrderSummary` is a struct. When you write `UIHostingController(rootView: OrderSummary(itemCount: 3, total: "$24.05"))`, the controller stores **its own copy** in `rootView`. Changing the variables you built it from does nothing to that copy. Here's that fact without UIKit, with a stand-in for the hosting controller that, like the real one, just stores the root view in a property:

```swift
struct OrderSummary {
    let itemCount: Int
    let total: String

    func render() -> String {
        "\(itemCount) items, \(total)"
    }
}

final class FakeHostingController<Root> {
    var rootView: Root

    init(rootView: Root) {
        self.rootView = rootView
    }
}

var summary = OrderSummary(itemCount: 3, total: "$24.05")
let host = FakeHostingController(rootView: summary)

summary = OrderSummary(itemCount: 4, total: "$31.10")
print("UIKit's copy: ", summary.render())
print("Hosted copy:  ", host.rootView.render())

host.rootView = summary
print("After reassign:", host.rootView.render())
```

```output
UIKit's copy:  4 items, $31.10
Hosted copy:   3 items, $24.05
After reassign: 4 items, $31.10
```

There are two correct ways to keep a hosted view current:

1. **Assign a new `rootView`** whenever the data changes, as `cartDidChange` does. Apple documents `rootView` as settable. It's simple and explicit, and it's fine for a view with a few inputs that UIKit already tracks.
2. **Pass a shared reference to an `@Observable` model** and let SwiftUI track it. The hosted view reads `model.itemCount` in `body`; when UIKit changes `model.itemCount`, SwiftUI updates the view, because the view's dependency is on the model's property, not on a copied value. Lesson 5 builds this out, including UIKit observing the same model.

The mistake is the third option: passing values once and expecting them to change.

## Events out: closures

A hosted view needs to tell UIKit things: the user tapped Save, picked a row, wants to see details. The SwiftUI view shouldn't know about `UIViewController`; it exposes **closure properties**, and whoever creates it fills them in. That's the result-closure pattern from Module 25, lesson 4, on a SwiftUI view:

```swift ios
import SwiftUI
import UIKit

struct RatingForm: View {
    let productName: String
    let onSubmit: (Int) -> Void
    let onCancel: () -> Void

    @State private var rating = 3

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Rating: \(rating)", value: $rating, in: 1...5)
            }
            .navigationTitle(productName)
            .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Submit", action: submit)
        }
    }

    private func submit() {
        onSubmit(rating)
    }
}

final class ProductViewController: UIViewController {
    private(set) var lastRating: Int?

    func presentRatingForm() {
        let form = RatingForm(
            productName: "Espresso Grinder",
            onSubmit: { [weak self] rating in
                self?.didSubmit(rating: rating)
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        let hosting = UIHostingController(rootView: form)
        hosting.isModalInPresentation = true
        present(hosting, animated: true)
    }

    private func didSubmit(rating: Int) {
        lastRating = rating
        dismiss(animated: true)
    }
}
```

- The form is a **modal task** with its own Cancel and Submit, so it has its own `NavigationStack` for the bar. That's a separate stack from any UIKit one, the same way Module 25 wrapped a presented editor in its own `UINavigationController`. That's fine; the rule against nested stacks was about a pushed screen.
- `toolbarContent` and `submit()` are pulled out of `body`. Short bodies with named pieces keep the type checker fast and the code readable.
- **The presenter dismisses.** `didSubmit` stores the result and calls `dismiss(animated:)` on itself, which dismisses what it presented. Apple's `DismissAction` page describes `@Environment(\.dismiss)` for SwiftUI presentations (sheets, popovers, `NavigationStack`); this lesson doesn't rely on it for a controller UIKit presented. Keeping dismissal on the side that presented is also the "who dismisses" rule from Module 25.
- `isModalInPresentation = true` blocks swipe-to-dismiss so a half-filled form isn't lost. `UIHostingController` lists it under "Checking for modality". If you want the swipe, leave it `false` and handle the interactive dismissal with `UIAdaptivePresentationControllerDelegate`, as in Module 25.

### The cycle hiding in the closure

Follow the references: the product controller presents the hosting controller (UIKit keeps it in `presentedViewController`); the hosting controller stores the root view; the root view stores `onSubmit`; and a closure that captures `self` strongly points back at the product controller. If the product controller also keeps the hosting controller in a property, which is common for a child, that's a cycle and neither is ever freed. A model of exactly that shape, with `deinit` printing when an object is released:

```swift
struct RatingForm {
    let onSubmit: (Int) -> Void
}

final class FakeHostingController<Root> {
    let rootView: Root

    init(rootView: Root) {
        self.rootView = rootView
    }
}

final class ProductScreen {
    let name: String
    var ratingHost: FakeHostingController<RatingForm>?
    var lastRating: Int?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("\(name) released")
    }

    func showFormCapturingStrongly() {
        ratingHost = FakeHostingController(rootView: RatingForm(onSubmit: { rating in
            self.lastRating = rating
        }))
    }

    func showFormCapturingWeakly() {
        ratingHost = FakeHostingController(rootView: RatingForm(onSubmit: { [weak self] rating in
            self?.lastRating = rating
        }))
    }
}

do {
    let screen = ProductScreen(name: "strong")
    screen.showFormCapturingStrongly()
    screen.ratingHost?.rootView.onSubmit(4)
    print("strong got", screen.lastRating ?? 0)
}
do {
    let screen = ProductScreen(name: "weak")
    screen.showFormCapturingWeakly()
    screen.ratingHost?.rootView.onSubmit(5)
    print("weak got", screen.lastRating ?? 0)
}
print("done")
```

```output
strong got 4
weak got 5
weak released
done
```

Both versions deliver the rating. Only the weak one is released at the end of its `do` block; "strong released" never prints. In an app that's a leaked screen, and every leaked product screen keeps its hosted SwiftUI hierarchy alive too. Module 13 covered `[weak self]`; the reason to repeat it here is that the cycle runs through a **struct**, which makes it easy to miss: the struct doesn't hold anything weakly or strongly by itself, but the closure inside it does.

## SwiftUI in cells: UIHostingConfiguration

Module 24 configured collection view cells with content configurations. `UIHostingConfiguration` (iOS 16) is one more: Apple calls it "A content configuration suitable for hosting a hierarchy of SwiftUI views", used "with a `UICollectionViewCell` or `UITableViewCell` to host a hierarchy of SwiftUI views in a collection or table view." No hosting controller, no containment; the cell owns it.

```swift ios
import SwiftUI
import UIKit

struct Contact: Hashable {
    let name: String
    let city: String
    let isFavorite: Bool
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(contact.name)
                Text(contact.city)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if contact.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
    }
}

@MainActor
func makeContactRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Contact> {
    UICollectionView.CellRegistration { cell, _, contact in
        cell.contentConfiguration = UIHostingConfiguration {
            ContactRow(contact: contact)
        }
        .margins(.horizontal, 20)
    }
}
```

- The registration and dequeueing are Module 24's. Only the configuration is new.
- The row is a separate `ContactRow` view. The configuration's closure stays one line, and the row can be previewed and reused.
- `.margins(_:_:)` "Sets the margins around the content of the configuration"; edges you don't list keep the system defaults. `.background(_:)` sets the cell's background, and `.minSize(width:height:)` lets a cell shrink below the default minimum.
- In a list layout, Apple notes that "certain APIs are bridged automatically, like swipe actions and separator alignment": a `.swipeActions` on the row becomes the cell's swipe actions.
- The cell is reused, so everything the row shows must come from `contact`. `@State` inside a hosted row doesn't belong to "the row for Ada"; it belongs to whatever this cell is showing now. Keep cell content stateless and derived from the item.

## Common mistakes

> [!error] The hosted card never grows
> The hosting controller is pinned without a height and its content gets taller (more lines, larger text), but the card keeps its first height. `sizingOptions` defaults to the empty set. Set `[.intrinsicContentSize]` for Auto Layout, or `[.preferredContentSize]` for a container that reads `preferredContentSize`.

> [!error] addChild without didMove(toParent:)
> The view shows up, so it looks fine, but Apple requires the call and the child never learns the transition finished. The order is `addChild`, add the view and its constraints, `didMove(toParent: self)`. Removing reverses it: `willMove(toParent: nil)`, `removeFromSuperview()`, `removeFromParent()`.

> [!error] Expecting the hosted view to follow a value you passed once
> `UIHostingController(rootView: Summary(count: count))` copies `count`. Assign a new `rootView` when it changes, or pass an `@Observable` model (lesson 5).

> [!error] A NavigationStack inside a pushed hosting controller
> The UIKit navigation controller already owns the stack and the bar. A `NavigationStack` inside the pushed screen starts a second stack with its own bar inside one screen. Report navigation intents through closures and let UIKit push.

> [!error] Capturing self strongly in an event closure
> Presenter → hosting controller → root view → closure → presenter. The struct in the middle hides it. Use `[weak self]` in every closure you hand to a hosted view.

## Exercises

````exercise
id: m40-l01-e1
type: comprehension
prompt: "A UIKit profile screen embeds a SwiftUI 'About' card as a child hosting controller, pinned top, leading and trailing with no height constraint. When the user switches to a larger Dynamic Type size, the text wraps onto more lines but the card stays the same height and overlaps the table below. What's the fix?"
choices:
  - text: "Set the hosting controller's sizingOptions to [.intrinsicContentSize]."
    correct: true
    why: "The hosting view then invalidates its intrinsic content size when its ideal size changes, and Auto Layout recomputes the card's height."
  - text: "Set sizingOptions to [.preferredContentSize]."
    correct: false
    why: "That updates preferredContentSize, which a container like a popover reads. Auto Layout reads intrinsic content size."
  - text: "Add a height constraint equal to the card's first measured height."
    correct: false
    why: "That freezes exactly the height that's wrong."
  - text: "Call layoutIfNeeded() on the hosting controller's view in viewDidAppear."
    correct: false
    why: "Layout runs again, with the same stale intrinsic size."
solution: |
  **`[.intrinsicContentSize]`.** `sizingOptions` defaults to the empty set. Apple's page for the option: "The hosting controller's view automatically invalidate its intrinsic content size when its ideal size changes. Use this option when the hosting controller's view is being laid out with Auto Layout." The cost, from the same page: it asks the content for its ideal size with the unspecified proposal. For a small card that's negligible.
````

````exercise
id: m40-l01-e2
type: prediction
prompt: "A stand-in hosting controller, a struct root view and some assignments. What does it print?"
code: |
  struct Badge {
      var count: Int
      func render() -> String { count == 0 ? "no badge" : "badge \(count)" }
  }

  final class FakeHostingController<Root> {
      var rootView: Root
      init(rootView: Root) { self.rootView = rootView }
  }

  var badge = Badge(count: 2)
  let host = FakeHostingController(rootView: badge)
  badge.count = 5
  print(host.rootView.render())

  host.rootView.count += 1
  print(host.rootView.render(), badge.render())

  let second = host
  second.rootView = Badge(count: 0)
  print(host.rootView.render())
output: |
  badge 2
  badge 3 badge 5
  no badge
hints:
  - "Badge is a struct; the host stores a copy."
  - "FakeHostingController is a class. second and host are the same object."
solution: |
  ```output
  badge 2
  badge 3 badge 5
  no badge
  ```

  - The host copied `Badge(count: 2)`. Changing `badge` afterwards doesn't touch that copy: **badge 2**.
  - `host.rootView.count += 1` changes the host's copy to 3; the outer `badge` is still 5.
  - `second` is another reference to the same controller (classes are reference types), so assigning its `rootView` changes what `host` shows: **no badge**.

  That's the real `UIHostingController` too: its `rootView` is a stored copy of a value, and the controller itself is a reference. To update the screen, assign a new `rootView` on the controller, or share a reference model the view reads.
````

````exercise
id: m40-l01-e3
type: fill-in
prompt: "Complete the code that embeds a SwiftUI chart as a child of a UIKit dashboard, with its height following its content."
code: |
  let chartHost = UIHostingController(rootView: SalesChart(sales: sales))
  chartHost.sizingOptions = [[[1]]]
  [[2]](chartHost)
  chartHost.view.translatesAutoresizingMaskIntoConstraints = false
  view.[[3]](chartHost.view)
  NSLayoutConstraint.activate([
      chartHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      chartHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      chartHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
  ])
  chartHost.[[4]](toParent: self)
blanks:
  - id: "1"
    answers: ["[.intrinsicContentSize]", ".intrinsicContentSize"]
  - id: "2"
    answers: ["addChild"]
  - id: "3"
    answers: ["addSubview"]
  - id: "4"
    answers: ["didMove"]
hints:
  - "The option for Auto Layout."
  - "Containment: register the child, add its view, then finish the transition."
solution: |
  ```swift ios
  import Charts
  import SwiftUI
  import UIKit

  struct Sale: Identifiable {
      let id: Int
      let month: String
      let amount: Double
  }

  struct SalesChart: View {
      let sales: [Sale]

      var body: some View {
          Chart(sales) { sale in
              BarMark(x: .value("Month", sale.month), y: .value("Amount", sale.amount))
          }
          .frame(minHeight: 200)
          .padding()
      }
  }

  final class DashboardViewController: UIViewController {
      private let sales = [
          Sale(id: 1, month: "Jan", amount: 1200),
          Sale(id: 2, month: "Feb", amount: 1850)
      ]

      override func viewDidLoad() {
          super.viewDidLoad()
          view.backgroundColor = .systemBackground

          let chartHost = UIHostingController(rootView: SalesChart(sales: sales))
          chartHost.sizingOptions = [.intrinsicContentSize]
          addChild(chartHost)
          chartHost.view.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(chartHost.view)
          NSLayoutConstraint.activate([
              chartHost.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              chartHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              chartHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
          ])
          chartHost.didMove(toParent: self)
      }
  }
  ```

  `[.intrinsicContentSize]` because the chart is laid out with Auto Layout and has no height constraint. `addChild`, `addSubview`, constraints and `didMove(toParent:)` is the containment order. Swift Charts appears here only as a realistic SwiftUI-only view that a UIKit app might want; it isn't covered in this course.
````

````exercise
id: m40-l01-e4
type: prediction
prompt: "A UIKit screen keeps a hosted SwiftUI view whose closure reports taps. Which objects are released, and in what order is everything printed?"
code: |
  struct TipView {
      let onDismiss: () -> Void
  }

  final class FakeHostingController<Root> {
      let rootView: Root
      init(rootView: Root) { self.rootView = rootView }
      deinit { print("host released") }
  }

  final class HomeScreen {
      var tipHost: FakeHostingController<TipView>?
      var tipsDismissed = 0

      deinit { print("home released") }

      func showTip(weakly: Bool) {
          if weakly {
              tipHost = FakeHostingController(rootView: TipView(onDismiss: { [weak self] in
                  self?.tipsDismissed += 1
              }))
          } else {
              tipHost = FakeHostingController(rootView: TipView(onDismiss: {
                  self.tipsDismissed += 1
              }))
          }
      }
  }

  do {
      let home = HomeScreen()
      home.showTip(weakly: true)
      home.tipHost?.rootView.onDismiss()
      print("dismissed:", home.tipsDismissed)
  }
  print("---")
  do {
      let home = HomeScreen()
      home.showTip(weakly: false)
      home.tipHost?.rootView.onDismiss()
      home.tipHost = nil
      print("dismissed:", home.tipsDismissed)
  }
  print("end")
output: |
  dismissed: 1
  home released
  host released
  ---
  host released
  dismissed: 1
  home released
  end
hints:
  - "In the first block nothing points back at home strongly."
  - "In the second block, setting tipHost to nil breaks the cycle before the block ends."
solution: |
  ```output
  dismissed: 1
  home released
  host released
  ---
  host released
  dismissed: 1
  home released
  end
  ```

  - **First block.** The closure captures `home` weakly, so at the end of the block `home`'s only strong reference goes away: it's released, and as part of that its `tipHost` property is released.
  - **Second block.** Strong capture makes a cycle: home → host → `TipView` → closure → home. But `home.tipHost = nil` releases the host right away ("host released" prints before "dismissed"), and with the host gone the closure is gone, so nothing holds `home` except the local constant. It's released at the end of the block.

  Breaking a cycle by hand works when you remember to do it on every path (Cancel, swipe-down, an error). `[weak self]` works on every path without remembering.
````

````exercise
id: m40-l01-e5
type: solve
prompt: |
  A UIKit notes app gets its first SwiftUI screen: a "Rename folder" form. Write:

  - `RenameFolderForm`, a SwiftUI view with the current name, a `TextField` bound to a private `@State` draft, Cancel and Save toolbar buttons, and two closures: `onSave: (String) -> Void` and `onCancel: () -> Void`. Save is disabled when the trimmed draft is empty.
  - `FolderViewController.presentRename()`, which presents the form as a sheet with a medium detent, blocks swipe-to-dismiss, and on Save stores the new name in `folderName`, updates `title`, and dismisses.

  Keep `body` short: pull the toolbar into its own property.
starter: |
  import SwiftUI
  import UIKit

  struct RenameFolderForm: View {
      // your code
  }

  final class FolderViewController: UIViewController {
      private(set) var folderName = "Recipes"

      func presentRename() {
          // your code
      }
  }
hints:
  - "Initialize the @State draft from the current name in the view's init with State(initialValue:)."
  - "trimmingCharacters(in: .whitespaces) and isEmpty for the disabled check."
  - "Both closures capture [weak self]."
rubric:
  - The form exposes onSave and onCancel closures and doesn't reference UIKit.
  - The draft is local @State, initialized from the current name.
  - Save is disabled for an empty or whitespace-only name.
  - The presenter uses [weak self] in both closures and dismisses itself.
  - The sheet has a medium detent and isModalInPresentation is true.
solution: |
  ```swift ios
  import SwiftUI
  import UIKit

  struct RenameFolderForm: View {
      let onSave: (String) -> Void
      let onCancel: () -> Void

      @State private var draft: String

      init(currentName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
          self.onSave = onSave
          self.onCancel = onCancel
          _draft = State(initialValue: currentName)
      }

      var body: some View {
          NavigationStack {
              Form {
                  TextField("Folder name", text: $draft)
              }
              .navigationTitle("Rename Folder")
              .toolbar { toolbarContent }
          }
      }

      private var trimmedDraft: String {
          draft.trimmingCharacters(in: .whitespaces)
      }

      @ToolbarContentBuilder
      private var toolbarContent: some ToolbarContent {
          ToolbarItem(placement: .cancellationAction) {
              Button("Cancel", action: onCancel)
          }
          ToolbarItem(placement: .confirmationAction) {
              Button("Save", action: save)
                  .disabled(trimmedDraft.isEmpty)
          }
      }

      private func save() {
          onSave(trimmedDraft)
      }
  }

  final class FolderViewController: UIViewController {
      private(set) var folderName = "Recipes"

      func presentRename() {
          let form = RenameFolderForm(
              currentName: folderName,
              onSave: { [weak self] newName in
                  self?.didRename(to: newName)
              },
              onCancel: { [weak self] in
                  self?.dismiss(animated: true)
              }
          )
          let hosting = UIHostingController(rootView: form)
          hosting.isModalInPresentation = true
          if let sheet = hosting.sheetPresentationController {
              sheet.detents = [.medium()]
          }
          present(hosting, animated: true)
      }

      private func didRename(to newName: String) {
          folderName = newName
          title = newName
          dismiss(animated: true)
      }
  }
  ```

  - The form knows nothing about UIKit. It could be presented by a SwiftUI `.sheet` tomorrow with the same closures.
  - `_draft = State(initialValue:)` gives the draft its starting value once, when the view's state is created (Module 36, lesson 1).
  - The presenter owns the result: it updates its own state and dismisses what it presented. Both closures are weak, so a presented form never keeps the folder screen alive.
````

````exercise
id: m40-l01-e6
type: find-errors
prompt: "A UIKit settings screen embeds a SwiftUI 'Storage' summary and navigates to a SwiftUI detail screen. Which of these are real problems?"
code: |
  final class SettingsViewController: UIViewController {
      private var usage = StorageUsage(usedGB: 41, totalGB: 128)
      private var storageHost: UIHostingController<StorageSummary>?

      override func viewDidLoad() {
          super.viewDidLoad()
          let host = UIHostingController(rootView: StorageSummary(usage: usage, onTap: {
              self.showStorageDetail()
          }))
          view.addSubview(host.view)
          host.view.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
              host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
          ])
          storageHost = host
      }

      func photosDeleted(freedGB: Int) {
          usage.usedGB -= freedGB
      }

      private func showStorageDetail() {
          let detail = UIHostingController(rootView: NavigationStack { StorageDetail(usage: usage) })
          navigationController?.pushViewController(detail, animated: true)
      }
  }
choices:
  - text: "The hosting controller is never added as a child: no addChild and no didMove(toParent:)."
    correct: true
    why: "Only its view is added. The containment relationship is missing."
  - text: "onTap captures self strongly, and self keeps storageHost: a retain cycle."
    correct: true
    why: "Settings → host → StorageSummary → closure → settings. Use [weak self]."
  - text: "photosDeleted changes usage, but the summary keeps showing the old numbers."
    correct: true
    why: "The root view holds a copy of usage. Assign a new rootView or share an @Observable model."
  - text: "sizingOptions isn't set, so the summary won't resize when its content changes."
    correct: true
    why: "It's pinned without a height; the default empty set doesn't track size changes."
  - text: "The pushed detail screen wraps its content in a NavigationStack inside a UIKit navigation controller."
    correct: true
    why: "That's a second stack inside a pushed screen. UIKit already owns navigation here."
  - text: "UIHostingController can't be pushed onto a UINavigationController."
    correct: false
    why: "It's a view controller; pushing it is the documented use."
rubric:
  - Flags the missing child containment.
  - Flags the strong capture.
  - Flags the stale copy of usage.
  - Flags the missing sizingOptions.
  - Flags the nested NavigationStack.
  - Doesn't flag the false claim about pushing.
solution: |
  Five real problems:

  1. **No containment.** Add `addChild(host)` before adding the view and `host.didMove(toParent: self)` after the constraints.
  2. **Retain cycle.** `onTap: { [weak self] in self?.showStorageDetail() }`.
  3. **Stale data.** After `usage.usedGB -= freedGB`, also `storageHost?.rootView = StorageSummary(usage: usage, onTap: …)`, or make `StorageUsage` an `@Observable` class both sides share.
  4. **No sizing.** `host.sizingOptions = [.intrinsicContentSize]`.
  5. **Nested stack.** Push `UIHostingController(rootView: StorageDetail(usage: usage))` and set its `title`; the UIKit navigation controller provides the bar and the back button.

  Pushing a hosting controller is exactly what it's for, so the last claim is false.
````

## Summary

- `UIHostingController(rootView:)` is a view controller that shows a SwiftUI hierarchy. Push it, present it, or embed it as a child, the same way as any other controller.
- Embedding is `addChild`, add the view with constraints, `didMove(toParent:)`. Set `sizingOptions = [.intrinsicContentSize]` (iOS 16) when Auto Layout should follow the content's height; `.preferredContentSize` is for containers. The default is empty, and both options cost an extra ideal-size measurement.
- `rootView` is a stored copy. Keep it current by assigning a new root view or by sharing an `@Observable` model.
- Hosted views report events through closure properties. The UIKit side fills them in with `[weak self]`, and the presenter dismisses what it presented.
- A pushed hosted screen doesn't get its own `NavigationStack`; UIKit owns that stack. A presented modal task can have one.
- `UIHostingConfiguration` (iOS 16) puts SwiftUI in collection and table view cells through `contentConfiguration`, with `.margins`, `.background` and `.minSize` to adjust the cell. Keep cell content derived from the item, not from `@State`.
