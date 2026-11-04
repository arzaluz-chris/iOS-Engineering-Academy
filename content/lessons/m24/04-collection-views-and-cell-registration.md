---
id: m24-l04
title: Collection views and cell registration
description: The modern UIKit list starts here. You build a UICollectionView with a list layout from UICollectionLayoutListConfiguration, create cells with typed UICollectionView.CellRegistration values instead of string identifiers, configure list cells with content configurations and accessories, add swipe actions and selection, and write a custom cell class that plugs into the same registration API.
module: m24
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l03]
objectives:
  - Explain how a collection view splits the work between a data source, a layout object and a delegate.
  - Build a list with UICollectionLayoutListConfiguration and UICollectionViewCompositionalLayout.list(using:).
  - Create a UICollectionView.CellRegistration once and dequeue cells with dequeueConfiguredReusableCell(using:for:item:).
  - Configure UICollectionViewListCell with a content configuration and accessories, and add swipe actions through the list configuration.
  - Register a custom UICollectionViewCell subclass with the same registration API.
terms:
  - term: UICollectionView
    definition: "A scroll view that shows items in sections, arranged by a separate layout object. Lists, grids, carousels and mixed screens are all collection views with different layouts."
  - term: Collection view layout
    definition: "A UICollectionViewLayout subclass that decides the position and size of every item and supplementary view. Current UIKit uses UICollectionViewCompositionalLayout; the older UICollectionViewFlowLayout still exists."
  - term: Cell registration
    definition: "A UICollectionView.CellRegistration<Cell, Item> value (iOS 14) that pairs a cell class with a closure that configures it for an item. Passing it to dequeueConfiguredReusableCell(using:for:item:) registers the class, dequeues a cell and runs the closure."
  - term: UICollectionViewListCell
    definition: "A collection view cell with list features: a default content configuration, accessories such as disclosure indicators and checkmarks, indentation and separators."
  - term: UICollectionLayoutListConfiguration
    definition: "The settings for a list section or list layout: appearance (plain, grouped, insetGrouped, sidebar), separators, header and footer mode, and swipe action providers."
mastery:
  - Build a collection view list screen in code with a list layout and a classic data source.
  - Store a cell registration in a property created once, and explain why creating it inside cellForItemAt breaks reuse.
  - Set a list cell's content configuration and accessories from the item, for every item.
  - Add a trailing swipe action through trailingSwipeActionsConfigurationProvider.
  - Write a custom cell class and a registration whose item type differs from the data source's identifier type.
resources: [uikit-cell-registration, uikit-list-configuration, uikit-uiview, swift-book-generics]
cards:
  - id: m24-l04-c1
    front: What are the three collaborators of a UICollectionView?
    back: "The data source (how many items, which cell for each), the layout object (where each item goes and how big it is), and the delegate (selection, highlighting, display events)."
  - id: m24-l04-c2
    front: How do you make a collection view look like a table view?
    back: "UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped)), with UICollectionViewListCell cells."
  - id: m24-l04-c3
    front: What does UICollectionView.CellRegistration replace?
    back: "String reuse identifiers, register(_:forCellWithReuseIdentifier:) and the cast after dequeuing. The registration is typed by cell class and item type; dequeueConfiguredReusableCell(using:for:item:) registers, dequeues and configures in one call."
  - id: m24-l04-c4
    front: Where must you create a cell registration?
    back: "Once, outside the cell provider or cellForItemAt, for example in viewDidLoad() stored in a property. Apple: creating it inside the cell provider prevents cell reuse and generates an exception in iOS 15 and later."
  - id: m24-l04-c5
    front: How do you add a disclosure indicator to a list cell?
    back: "cell.accessories = [.disclosureIndicator()]. Set the whole accessories array for every item, so a reused cell never keeps an accessory from its previous item."
---

## The idea in one sentence

A collection view is a table view with the layout taken out: the data source still says **what** to show, a separate **layout object** decides **where**, and cells are created through typed **registrations** instead of string identifiers.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The API details come from Apple's reference pages for `UICollectionView`, `UICollectionView.CellRegistration`, `UICollectionLayoutListConfiguration`, `UICollectionViewListCell` and `UICellAccessory`, read in November 2026. The registration model is plain Swift and was compiled and run.

## From table view to collection view

| | `UITableView` | `UICollectionView` |
| --- | --- | --- |
| Arrangement | One column of rows, built in | Whatever the layout object says |
| Position in an `IndexPath` | `row` | `item` |
| Cells | `UITableViewCell` | `UICollectionViewCell`, `UICollectionViewListCell` |
| Creating cells | `register` + string identifier + `dequeueReusableCell` | `CellRegistration` + `dequeueConfiguredReusableCell` (or the string API) |
| Reuse | Yes | Yes, with the same rules as lesson 3 |

Three objects cooperate:

- The **data source** (`UICollectionViewDataSource`, or the diffable data source in lesson 5) answers "how many items?" and "which cell for this one?".
- The **layout** (`UICollectionViewLayout` subclass) answers "where does each item go, and how big is it?". It's passed to the initializer, so a collection view never exists without one.
- The **delegate** (`UICollectionViewDelegate`) handles selection, highlighting and display events.

Since iOS 14 a collection view with a **list layout** does everything a table view does: rows, separators, swipe actions, accessories, headers. Apple's own apps and samples use it for new lists, and that's what this lesson builds.

## A list in a collection view

```swift ios
import UIKit

final class LanguagesViewController: UIViewController {
    private let languages = ["Swift", "Kotlin", "Rust", "Go", "TypeScript"]
    private var collectionView: UICollectionView!
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, String>!

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        cellRegistration = UICollectionView.CellRegistration { cell, indexPath, language in
            var content = cell.defaultContentConfiguration()
            content.text = language
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }

        collectionView.dataSource = self
        collectionView.delegate = self
    }
}

extension LanguagesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        languages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: languages[indexPath.item])
    }
}

extension LanguagesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        print("selected \(languages[indexPath.item])")
    }
}
```

Line by line:

1. **`UICollectionLayoutListConfiguration(appearance:)`** describes a list: `.plain`, `.grouped`, `.insetGrouped`, `.sidebar` or `.sidebarPlain`. Same looks as the table view styles, plus sidebars for iPad.
2. **`UICollectionViewCompositionalLayout.list(using:)`** "creates a compositional layout that contains only list sections" with that configuration. Lesson 6 builds compositional layouts by hand; this factory is the shortcut for pure lists.
3. **`UICollectionView(frame:collectionViewLayout:)`**: the layout is required. `autoresizingMask` makes it follow the root view's size, the frame-based option from Module 23; constraints work just as well.
4. **The registration**: `CellRegistration<UICollectionViewListCell, String>`. The generic parameters are the cell class and the item type the closure receives. Here they're inferred from the property's declared type. The closure gets the dequeued cell, its index path and the item, and configures the cell.
5. **`dequeueConfiguredReusableCell(using:for:item:)`** does three things: registers the cell class the first time, dequeues a reusable cell (or creates one), and runs the registration's closure with your item. It returns the cell already typed as `UICollectionViewListCell`, no cast needed.
6. **`indexPath.item`** is the collection view's name for the position within the section.

Apple, on registering: "You don't need to call register(_:forCellWithReuseIdentifier:) … The collection view registers your cell automatically when you pass the cell registration to dequeueConfiguredReusableCell(using:for:item:)."

## Create the registration once

The registration has to exist before the first cell is requested, and it has to be **the same registration** every time. Apple's warning on the `CellRegistration` page:

> "Don't create your cell registration inside a CellProvider closure; doing so prevents cell reuse, and generates an exception in iOS 15 and higher."

The same applies to `cellForItemAt`. Creating it in `viewDidLoad()` and storing it in a property, as above, or creating it as a local constant in the method that builds the data source (lesson 5), are both fine.

Why it breaks reuse: each registration value carries its own identity, and the collection view keeps its reuse queue per registration. A new registration per call is a new, empty queue every time. This model shows the effect:

```swift
import Foundation

final class Cell {
    let number: Int
    var text = ""
    init(number: Int) { self.number = number }
}

struct Registration {
    let id = UUID()
    let configure: (Cell, String) -> Void
}

final class FakeCollectionView {
    private var queues: [UUID: [Cell]] = [:]
    private(set) var cellsCreated = 0

    func dequeue(using registration: Registration, item: String) -> Cell {
        let cell: Cell
        if let reused = queues[registration.id]?.popLast() {
            cell = reused
        } else {
            cellsCreated += 1
            cell = Cell(number: cellsCreated)
        }
        registration.configure(cell, item)
        return cell
    }

    func recycle(_ cell: Cell, using registration: Registration) {
        queues[registration.id, default: []].append(cell)
    }
}

let items = ["A", "B", "C", "D", "E", "F"]

let collectionA = FakeCollectionView()
let shared = Registration { cell, item in cell.text = item }
for item in items {
    let cell = collectionA.dequeue(using: shared, item: item)
    collectionA.recycle(cell, using: shared)
}
print("one shared registration: \(collectionA.cellsCreated) cell(s)")

let collectionB = FakeCollectionView()
for item in items {
    let perCall = Registration { cell, item in cell.text = item }
    let cell = collectionB.dequeue(using: perCall, item: item)
    collectionB.recycle(cell, using: perCall)
}
print("a registration per call: \(collectionB.cellsCreated) cell(s)")
```

```output
one shared registration: 1 cell(s)
a registration per call: 6 cell(s)
```

The model scrolls one item at a time, so a single cell could serve all six. With one shared registration, it does. With a new registration for each item, every queue is new and empty, and every item gets a brand-new cell. UIKit goes further than the model and raises an exception, so you find out immediately.

The model gives each registration a `UUID` when it's created and keys the reuse queues by it. How UIKit identifies a `CellRegistration` internally isn't documented; the effect Apple describes is the same.

## List cells

`UICollectionViewListCell` gives you what you used in table view cells, through configurations:

```swift ios
import UIKit

struct Contact {
    let id: Int
    var name: String
    var email: String
    var isFavorite: Bool
}

let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Contact> { cell, _, contact in
    var content = UIListContentConfiguration.subtitleCell()
    content.text = contact.name
    content.secondaryText = contact.email
    content.image = UIImage(systemName: contact.isFavorite ? "star.fill" : "person")
    content.imageProperties.tintColor = contact.isFavorite ? .systemYellow : .secondaryLabel
    cell.contentConfiguration = content

    cell.accessories = contact.isFavorite
        ? [.label(text: "Favorite"), .disclosureIndicator()]
        : [.disclosureIndicator()]
}
```

- **`contentConfiguration`** works as in lesson 3: build a complete `UIListContentConfiguration`, assign it.
- **`accessories`** is an array of `UICellAccessory` values: `.disclosureIndicator()`, `.checkmark()`, `.delete()`, `.reorder()`, `.multiselect()`, `.outlineDisclosure()`, `.label(text:)`, `.detail()`, `.popUpMenu(_:)` and `.customView(configuration:)`. Most take a `displayed:` argument (`.always`, `.whenEditing`, `.whenNotEditing`).
- **Set the whole array for every item.** The reuse rule from lesson 3 applies: assign `accessories` in both branches, never append to what the cell already had.
- `_` for the index path: the closure has three parameters and this one doesn't need it.

## Swipe actions and headers

Swipe actions belong to the list configuration, not to a delegate method. The provider receives an index path and returns a `UISwipeActionsConfiguration`, the same type table views use:

```swift ios
import UIKit

final class InboxViewController: UIViewController {
    private var subjects = ["Invoice #1021", "Team lunch", "Your flight", "Weekly report"]
    private var collectionView: UICollectionView!
    private var cellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, String>!

    override func viewDidLoad() {
        super.viewDidLoad()

        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfiguration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            let archive = UIContextualAction(style: .normal, title: "Archive") { _, _, completion in
                self?.archive(at: indexPath)
                completion(true)
            }
            archive.backgroundColor = .systemIndigo
            return UISwipeActionsConfiguration(actions: [archive])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        cellRegistration = UICollectionView.CellRegistration { cell, _, subject in
            var content = cell.defaultContentConfiguration()
            content.text = subject
            cell.contentConfiguration = content
        }
        collectionView.dataSource = self
    }

    private func archive(at indexPath: IndexPath) {
        subjects.remove(at: indexPath.item)
        collectionView.deleteItems(at: [indexPath])
    }
}

extension InboxViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        subjects.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: subjects[indexPath.item])
    }
}
```

The list configuration is a struct, so you set the provider **before** creating the layout from it. `archive(at:)` follows lesson 3's rule: model first, then `deleteItems(at:)`. The index path captured by the swipe action is only used immediately, while it's still valid.

Headers: set `headerMode` on the list configuration to `.supplementary` (you provide a header view, lesson 6) or `.firstItemInSection` (the first item of each section is styled as its header).

## A custom cell

When the list styles don't fit, subclass `UICollectionViewCell` and keep the registration API:

```swift ios
import UIKit

struct Product {
    let id: Int
    var name: String
    var price: String
    var symbolName: String
}

final class ProductCell: UICollectionViewCell {
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemTeal
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        priceLabel.font = .preferredFont(forTextStyle: .subheadline)
        priceLabel.adjustsFontForContentSizeCategory = true
        priceLabel.textColor = .secondaryLabel

        let text = UIStackView(arrangedSubviews: [nameLabel, priceLabel])
        text.axis = .vertical
        let row = UIStackView(arrangedSubviews: [iconView, text])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
        ])

        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    func configure(with product: Product) {
        iconView.image = UIImage(systemName: product.symbolName)
        nameLabel.text = product.name
        priceLabel.text = product.price
        accessibilityLabel = "\(product.name), \(product.price)"
    }
}

let productRegistration = UICollectionView.CellRegistration<ProductCell, Product> { cell, _, product in
    cell.configure(with: product)
}
```

- Subviews go in **`contentView`**, not in the cell itself, so the cell's background, selection and editing states work around them.
- `configure(with:)` sets every displayed property from the product, which makes it reuse-safe by construction.
- **The cell is one accessibility element.** Without that, VoiceOver would stop on the name and the price separately. `isAccessibilityElement = true` plus a combined label reads the row as one item (Module 27 goes further).
- The registration's item type is `Product`. Apple: "The item type for a cell registration doesn't have to match the item identifier type that the diffable data source uses." In lesson 5 the data source will deal in product **ids**, and the cell provider will look up the `Product` to pass to this registration.

## Common mistakes

> [!error] Creating the registration inside cellForItemAt or the cell provider
> Each call creates a new registration, reuse never happens, and on iOS 15 and later UIKit raises an exception. Create it once and store it.

> [!error] Appending accessories
> `cell.accessories.append(.checkmark())` inside the registration closure adds another checkmark every time the cell is reused. Assign the full array from the item.

> [!error] Adding subviews to the cell instead of contentView
> Subviews added directly to the cell can sit above the selection background and ignore list editing insets. Use `contentView`.

> [!error] Changing the list configuration after creating the layout
> `UICollectionLayoutListConfiguration` is a struct copied into the layout. Setting `trailingSwipeActionsConfigurationProvider` after `list(using:)` changes your local copy only. Configure first, then create the layout.

> [!error] Forgetting the delegate for selection
> `didSelectItemAt` lives in `UICollectionViewDelegate`. Without `collectionView.delegate = self` it's never called, silently.

## Exercises

````exercise
id: m24-l04-e1
type: prediction
prompt: "A registration model where the registration also counts how often it configured a cell. What does it print?"
code: |
  final class Cell {
      let number: Int
      var text = ""
      init(number: Int) { self.number = number }
  }

  final class Registration {
      var configured = 0
      func configure(_ cell: Cell, _ item: String) {
          configured += 1
          cell.text = item.uppercased()
      }
  }

  final class Collection {
      var queue: [Cell] = []
      var created = 0
      func dequeue(using registration: Registration, item: String) -> Cell {
          let cell: Cell
          if let reused = queue.popLast() {
              cell = reused
          } else {
              created += 1
              cell = Cell(number: created)
          }
          registration.configure(cell, item)
          return cell
      }
  }

  let collection = Collection()
  let registration = Registration()
  var visible: [Cell] = []
  for item in ["tea", "coffee", "juice", "water"] {
      if visible.count == 2 {
          collection.queue.append(visible.removeFirst())
      }
      let cell = collection.dequeue(using: registration, item: item)
      visible.append(cell)
      print(cell.number, cell.text)
  }
  print(collection.created, registration.configured)
output: |
  1 TEA
  2 COFFEE
  1 JUICE
  2 WATER
  2 4
hints:
  - "Two cells are visible at a time; the third item reuses the first cell."
  - "The registration runs for every dequeue, new or reused."
solution: |
  ```output
  1 TEA
  2 COFFEE
  1 JUICE
  2 WATER
  2 4
  ```

  Two cells serve four items, and the registration's closure ran four times: once per dequeue, whether the cell is new or reused. That's how `dequeueConfiguredReusableCell(using:for:item:)` works too: your configuration runs every time, so it must set everything.
````

````exercise
id: m24-l04-e2
type: comprehension
prompt: "Which statement about UICollectionView.CellRegistration is correct?"
choices:
  - text: "Passing the registration to dequeueConfiguredReusableCell(using:for:item:) registers the cell class automatically, so you don't call register(_:forCellWithReuseIdentifier:)."
    correct: true
    why: "That's what Apple's page says, and it's the point of the API."
  - text: "You must create a new registration for each cell so that each one has its own configuration closure."
    correct: false
    why: "That prevents reuse and raises an exception on iOS 15 and later."
  - text: "The item type of the registration must be the same type as the diffable data source's item identifier."
    correct: false
    why: "Apple says it doesn't have to match; a common pattern registers with the model and stores ids in the data source."
  - text: "CellRegistration only works with UICollectionViewListCell."
    correct: false
    why: "The Cell parameter is any UICollectionViewCell subclass, including your own."
solution: |
  **The registration registers the class for you.** The other statements are the usual misunderstandings: registrations are created once, the item type is free (often the full model while the data source holds ids), and any `UICollectionViewCell` subclass works.
````

````exercise
id: m24-l04-e3
type: fill-in
prompt: "Complete a list screen that shows checkmarks on completed steps."
code: |
  struct Step {
      var title: String
      var isDone: Bool
  }

  final class StepsViewController: UIViewController, UICollectionViewDataSource {
      private let steps = [Step(title: "Install Xcode", isDone: true), Step(title: "Create project", isDone: false)]
      private var collectionView: UICollectionView!
      private var registration: UICollectionView.CellRegistration<[[1]], Step>!

      override func viewDidLoad() {
          super.viewDidLoad()
          let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
          let layout = UICollectionViewCompositionalLayout.[[2]](using: configuration)
          collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
          view.addSubview(collectionView)

          registration = UICollectionView.CellRegistration { cell, _, step in
              var content = cell.defaultContentConfiguration()
              content.text = step.title
              cell.contentConfiguration = content
              cell.[[3]] = step.isDone ? [.checkmark()] : []
          }
          collectionView.dataSource = self
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          steps.count
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          collectionView.[[4]](using: registration, for: indexPath, item: steps[indexPath.item])
      }
  }
blanks:
  - id: "1"
    answers: ["UICollectionViewListCell"]
  - id: "2"
    answers: ["list"]
  - id: "3"
    answers: ["accessories"]
  - id: "4"
    answers: ["dequeueConfiguredReusableCell"]
solution: |
  ```swift ios
  import UIKit

  struct Step {
      var title: String
      var isDone: Bool
  }

  final class StepsViewController: UIViewController, UICollectionViewDataSource {
      private let steps = [Step(title: "Install Xcode", isDone: true), Step(title: "Create project", isDone: false)]
      private var collectionView: UICollectionView!
      private var registration: UICollectionView.CellRegistration<UICollectionViewListCell, Step>!

      override func viewDidLoad() {
          super.viewDidLoad()
          let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
          let layout = UICollectionViewCompositionalLayout.list(using: configuration)
          collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
          view.addSubview(collectionView)

          registration = UICollectionView.CellRegistration { cell, _, step in
              var content = cell.defaultContentConfiguration()
              content.text = step.title
              cell.contentConfiguration = content
              cell.accessories = step.isDone ? [.checkmark()] : []
          }
          collectionView.dataSource = self
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          steps.count
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: steps[indexPath.item])
      }
  }
  ```

  `UICollectionViewListCell` provides `defaultContentConfiguration()` and `accessories`. `list(using:)` builds a list-only compositional layout. The accessories line assigns in both cases (a checkmark or an empty array), so a reused cell never keeps a stale checkmark.
````

````exercise
id: m24-l04-e4
type: find-errors
prompt: "This screen scrolls badly and crashes on iOS 17. Mark every real problem."
code: |
  final class TagsViewController: UIViewController, UICollectionViewDataSource {
      private let tags = ["swift", "uikit", "ios", "xcode"]
      private var collectionView: UICollectionView!

      override func viewDidLoad() {
          super.viewDidLoad()
          var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
          let layout = UICollectionViewCompositionalLayout.list(using: configuration)
          configuration.showsSeparators = false
          collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
          view.addSubview(collectionView)
          collectionView.dataSource = self
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          tags.count
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          let registration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, tag in
              var content = cell.defaultContentConfiguration()
              content.text = "#" + tag
              cell.contentConfiguration = content
              cell.accessories.append(.disclosureIndicator())
          }
          return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: tags[indexPath.item])
      }
  }
choices:
  - text: "The registration is created inside cellForItemAt, which prevents reuse and raises an exception on iOS 15 and later."
    correct: true
  - text: "showsSeparators is changed after the layout was created from the configuration, so it has no effect."
    correct: true
  - text: "accessories.append adds another disclosure indicator every time a cell is reused."
    correct: true
  - text: "A collection view can't use UICollectionViewDataSource; it needs a diffable data source."
    correct: false
    why: "The classic data source protocol still works; diffable is the recommended alternative."
  - text: "\"#\" + tag doesn't compile; use interpolation."
    correct: false
    why: "String concatenation with + is fine."
rubric:
  - I found the registration created per call.
  - I found the configuration changed after creating the layout.
  - I found the appended accessory.
solution: |
  Three problems:

  1. **Registration per call.** Move it to a stored property created in `viewDidLoad()`.
  2. **`showsSeparators` set too late.** The layout copied the struct when `list(using:)` ran. Set it before.
  3. **`append`.** Assign `cell.accessories = [.disclosureIndicator()]`.

  ```swift ios
  import UIKit

  final class TagsViewController: UIViewController, UICollectionViewDataSource {
      private let tags = ["swift", "uikit", "ios", "xcode"]
      private var collectionView: UICollectionView!
      private var registration: UICollectionView.CellRegistration<UICollectionViewListCell, String>!

      override func viewDidLoad() {
          super.viewDidLoad()
          var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
          configuration.showsSeparators = false
          let layout = UICollectionViewCompositionalLayout.list(using: configuration)
          collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
          view.addSubview(collectionView)

          registration = UICollectionView.CellRegistration { cell, _, tag in
              var content = cell.defaultContentConfiguration()
              content.text = "#" + tag
              cell.contentConfiguration = content
              cell.accessories = [.disclosureIndicator()]
          }
          collectionView.dataSource = self
      }

      func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          tags.count
      }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: tags[indexPath.item])
      }
  }
  ```
````

````exercise
id: m24-l04-e5
type: solve
prompt: |
  List cells get their accessories from the item. Model that decision in plain Swift so it can be tested.

  Write an enum `Accessory` with cases `disclosure`, `checkmark`, `badge(Int)` and `reorder`, and a function `accessories(isSelected:unreadCount:isEditing:) -> [Accessory]` with these rules:

  - When editing, the only accessory is `reorder`.
  - Otherwise: `checkmark` if selected; then `badge(n)` if `unreadCount` is greater than 0; then always `disclosure` last.

  Then print the results for the four cases below with a helper that turns them into text.

  ```swift
  print(describe(accessories(isSelected: false, unreadCount: 0, isEditing: false)))
  print(describe(accessories(isSelected: true, unreadCount: 3, isEditing: false)))
  print(describe(accessories(isSelected: false, unreadCount: 12, isEditing: false)))
  print(describe(accessories(isSelected: true, unreadCount: 3, isEditing: true)))
  ```

  should print:

  ```plaintext
  [disclosure]
  [checkmark, badge 3, disclosure]
  [badge 12, disclosure]
  [reorder]
  ```
starter: |
  enum Accessory {
      case disclosure, checkmark, badge(Int), reorder
  }

  func accessories(isSelected: Bool, unreadCount: Int, isEditing: Bool) -> [Accessory] {
      // your code
      []
  }

  func describe(_ list: [Accessory]) -> String {
      // your code
      ""
  }
hints:
  - "Return early in the editing case."
  - "Build the array with var result: [Accessory] = [] and append in order."
  - "In describe, switch over each case to produce its text, then join with \", \"."
rubric:
  - The function returns a complete array for every input, never a partial update.
  - Editing overrides everything else.
  - The order matches the rules.
  - The output matches.
solution: |
  ```swift
  enum Accessory {
      case disclosure, checkmark, badge(Int), reorder
  }

  func accessories(isSelected: Bool, unreadCount: Int, isEditing: Bool) -> [Accessory] {
      if isEditing {
          return [.reorder]
      }
      var result: [Accessory] = []
      if isSelected { result.append(.checkmark) }
      if unreadCount > 0 { result.append(.badge(unreadCount)) }
      result.append(.disclosure)
      return result
  }

  func describe(_ list: [Accessory]) -> String {
      let names = list.map { accessory -> String in
          switch accessory {
          case .disclosure: "disclosure"
          case .checkmark: "checkmark"
          case .badge(let count): "badge \(count)"
          case .reorder: "reorder"
          }
      }
      return "[" + names.joined(separator: ", ") + "]"
  }

  print(describe(accessories(isSelected: false, unreadCount: 0, isEditing: false)))
  print(describe(accessories(isSelected: true, unreadCount: 3, isEditing: false)))
  print(describe(accessories(isSelected: false, unreadCount: 12, isEditing: false)))
  print(describe(accessories(isSelected: true, unreadCount: 3, isEditing: true)))
  ```

  ```output
  [disclosure]
  [checkmark, badge 3, disclosure]
  [badge 12, disclosure]
  [reorder]
  ```

  The function always returns the **whole** list, which is what the registration closure assigns to `cell.accessories`. In UIKit the mapping is one switch away: `.checkmark()`, `.label(text: "\(count)")`, `.disclosureIndicator()`, `.reorder()`. Because it's a pure function, every combination can be tested without a simulator.
````

````exercise
id: m24-l04-e6
type: design
prompt: "A teammate asks: \"Table views work fine. Why would we build our new settings screen with a collection view list instead?\" Give an honest answer, including when a table view is still reasonable."
rubric:
  - Mentions that list layouts give the same features (separators, swipe actions, accessories, headers) with configurations.
  - Mentions that one collection view can mix list sections with grids and carousels (compositional layout).
  - Mentions diffable data sources and cell registrations as the current API Apple builds on.
  - Accepts table views for existing code, simple screens, or where the team's code already depends on them.
solution: |
  A collection view list does everything the table view does (rows, separators, swipe actions, accessories, headers, sidebars) through the same configuration types (`UIListContentConfiguration`, `UICellAccessory`, list configurations). On top of that:

  - **One view, any layout.** A screen that's a list today and needs a horizontal carousel of featured items tomorrow only changes its layout (lesson 6). A table view can't do that.
  - **The current API.** Cell registrations, list layouts and diffable data sources (lesson 5) are what Apple's newer samples use, and new list features tend to arrive there.

  A table view is still reasonable when you're extending a screen that already uses one, for a short static list, or when the team's shared code is built around `UITableView`. Diffable data sources also exist for table views (`UITableViewDiffableDataSource`), so the snapshot model applies to both. What isn't reasonable is avoiding collection views because they look harder: for a list, the setup is about the same length.
````

## Summary

- A collection view separates content (data source), arrangement (layout object) and behavior (delegate). With a list layout it does everything a table view does.
- `UICollectionLayoutListConfiguration(appearance:)` + `UICollectionViewCompositionalLayout.list(using:)` builds a list. Configure the struct fully before creating the layout.
- `UICollectionView.CellRegistration<Cell, Item>` pairs a cell class with a configuration closure. Create it once; `dequeueConfiguredReusableCell(using:for:item:)` registers, dequeues and configures.
- `UICollectionViewListCell` uses `contentConfiguration` and `accessories`; assign both completely for every item.
- Swipe actions come from the list configuration's providers. Custom cells subclass `UICollectionViewCell`, put subviews in `contentView`, and use the same registration API.
