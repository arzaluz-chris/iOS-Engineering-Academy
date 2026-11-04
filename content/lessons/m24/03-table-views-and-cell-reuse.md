---
id: m24-l03
title: Table views and cell reuse
description: The classic UIKit list. You build a table view with a data source and a delegate, dequeue cells and configure them with UIListContentConfiguration, update rows without crashing the table, and learn why cells are reused, what the stale-state bug looks like, and what belongs in prepareForReuse() and what doesn't.
module: m24
order: 3
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l02]
objectives:
  - Implement UITableViewDataSource and UITableViewDelegate for a sectioned list with selection and swipe-to-delete.
  - Register a cell class and dequeue cells with dequeueReusableCell(withIdentifier:for:).
  - Configure cells with UIListContentConfiguration instead of the deprecated textLabel and imageView.
  - Explain why table views reuse cells and reproduce the stale-state bug in a plain-Swift model.
  - Decide what to reset in prepareForReuse() and what to set in tableView(_:cellForRowAt:).
  - Update the model and the table together with deleteRows, insertRows, reloadRows and reconfigureRows.
terms:
  - term: UITableView
    definition: "A scroll view that shows rows in a single column, grouped in sections. It asks its data source for the number of rows and for a cell per visible row."
  - term: Data source
    definition: "The object that adopts UITableViewDataSource and answers the table's questions about content: how many sections and rows, and which cell goes at each index path."
  - term: Reuse identifier
    definition: "A string that names a kind of cell. The table keeps a queue of cells per identifier and hands one back from dequeueReusableCell(withIdentifier:for:) before creating a new one."
  - term: Cell reuse
    definition: "When a cell scrolls off screen, the table puts it in a reuse queue and later returns it for a different row. Only about a screen's worth of cells exists at any time."
  - term: Stale state
    definition: "A value left on a reused cell from the row it showed before, because the code that configured it for the new row didn't set that property."
  - term: UIListContentConfiguration
    definition: "A value type (iOS 14) describing a list cell's standard content: image, text, secondary text and their styling. You get one from cell.defaultContentConfiguration(), fill it in and assign it to cell.contentConfiguration."
mastery:
  - Write a table view controller with two sections, a header per section, selection and swipe-to-delete.
  - Predict which values a reused cell shows when cellForRowAt sets a property in only one branch.
  - Write a prepareForReuse() override that resets only non-content state and calls super.
  - Update a table after deleting from the model in the right order, so the row counts match.
  - Choose reconfigureRows over reloadRows when only a row's content changed.
resources: [uikit-uitableview, uikit-prepareforreuse, uikit-list-content-configuration, uikit-uiview, swift-book-protocols]
cards:
  - id: m24-l03-c1
    front: Why do table and collection views reuse cells?
    back: "Creating views is expensive and a list can have thousands of rows. Only about a screen's worth of cells exists; a cell that scrolls off is queued and handed back by dequeueReusableCell for another row."
  - id: m24-l03-c2
    front: What causes the stale-state bug in a reused cell?
    back: "cellForRowAt sets a property in only some cases (if isFavorite { show star }). A reused cell keeps the value from its previous row. Fix: set every property for every row, in both branches."
  - id: m24-l03-c3
    front: What belongs in prepareForReuse()?
    back: "Resetting non-content state (alpha, editing and selection state) and cancelling work started for the old row, such as an image download. Always call super. Content is set in cellForRowAt for every row, per Apple's documentation."
  - id: m24-l03-c4
    front: In which order do you delete a row?
    back: "Remove it from the model first, then call tableView.deleteRows(at:with:). The table checks that the new row count equals the old count minus the deleted rows; if the model wasn't updated, it raises an exception."
  - id: m24-l03-c5
    front: reconfigureRows(at:) vs reloadRows(at:with:)?
    back: "reconfigureRows (iOS 15) re-runs your cell configuration on the existing cell, without prepareForReuse and without replacing it. reloadRows replaces the cell. Prefer reconfigure unless you need a different cell type."
---

## The idea in one sentence

A table view never holds your data: it asks a data source how many rows there are and for a cell for each row that's about to appear, and it hands you **recycled cells** to fill in, so `tableView(_:cellForRowAt:)` must set everything a cell shows, every time.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The rules come from Apple's reference pages for `UITableView`, `UITableViewDataSource`, `UITableViewCell`, `prepareForReuse()` and `reconfigureRows(at:)`, read in November 2026. The reuse model is plain Swift and was compiled and run.

> [!version] Where table views stand
> For new lists, current UIKit uses a collection view with a list layout and a diffable data source: lessons 4 to 6. Table views are still everywhere in existing apps and in interviews, and the reuse rules in this lesson apply unchanged to collection views. In the iOS 27 SDK, `UITableViewCell`'s `textLabel` (and its siblings `detailTextLabel` and `imageView`) are deprecated: use content configurations, as this lesson does.

## A first table

A list of countries:

```swift ios
import UIKit

final class CountriesViewController: UIViewController {
    private let countries = ["Argentina", "Chile", "Colombia", "Mexico", "Peru", "Spain", "Uruguay"]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let cellIdentifier = "CountryCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.dataSource = self
        tableView.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}

extension CountriesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        countries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = countries[indexPath.row]
        cell.contentConfiguration = content
        return cell
    }
}

extension CountriesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        print("selected \(countries[indexPath.row])")
    }
}
```

Line by line:

1. **`UITableView(frame:style:)`**: `.plain` (rows edge to edge, sticky section headers), `.grouped` or `.insetGrouped` (rounded sections with margins, the Settings look).
2. **`register(_:forCellReuseIdentifier:)`** tells the table which class to create for an identifier. Apple: you "must do so before calling" `dequeueReusableCell(withIdentifier:for:)`.
3. **`dataSource` and `delegate`** are two roles, usually played by the view controller (Module 22, lesson 5). The data source answers **what** to show; the delegate handles **what happens**: selection, swipe actions, heights.
4. **`numberOfRowsInSection`** returns the count from your model. The table asks; it doesn't store the answer forever.
5. **`cellForRowAt`** is called for each row about to become visible. **`dequeueReusableCell(withIdentifier:for:)`** "returns an existing cell of the specified type, if one is available, or it creates and returns a new cell". It "always returns a valid cell".
6. **`defaultContentConfiguration()`** returns an empty configuration with the system's styling for this cell; you set `text` and assign it.
7. **`didSelectRowAt`** handles a tap. `deselectRow(at:animated:)` removes the highlight; without it the row stays gray after you come back to the screen.

`IndexPath` has a `section` and a `row`. With one section, `row` is enough.

`UITableViewController` is a view controller whose view is already a table view, with `dataSource` and `delegate` set to itself. It saves the setup above; the rest is the same.

## Why cells are reused

A contacts list might have 3,000 rows. Creating 3,000 cells, each with its own subviews, labels and constraints, would take time on launch and hold memory for views nobody sees. A table view only keeps about **a screen's worth** of cells, plus a few:

```plaintext
            ┌──────────────┐
  row 0     │ cell A       │ ← scrolls off the top → reuse queue
  row 1     │ cell B       │
  …         │ …            │      visible area
  row 9     │ cell J       │
            └──────────────┘
  row 10    asks for a cell → dequeue returns cell A, already used for row 0
```

As you scroll, a cell leaving the top goes into a **reuse queue** for its identifier, and the next row appearing at the bottom gets it back from `dequeueReusableCell`. The cell is the same object, with **whatever you set on it for its previous row**. That's the source of the most common table view bug.

## A model of reuse

This plain-Swift model does what the table does with cells, so you can watch it happen:

```swift
final class FakeCell {
    let number: Int
    var title = ""
    var showsStar = false

    init(number: Int) {
        self.number = number
    }
}

final class FakeTable {
    private var reuseQueue: [FakeCell] = []
    private var visible: [Int: FakeCell] = [:]
    private(set) var cellsCreated = 0

    func dequeue() -> FakeCell {
        if let cell = reuseQueue.popLast() {
            return cell
        }
        cellsCreated += 1
        return FakeCell(number: cellsCreated)
    }

    func show(row: Int, configure: (FakeCell) -> Void) {
        let cell = dequeue()
        configure(cell)
        visible[row] = cell
        let star = cell.showsStar ? " ★" : ""
        print("row \(row) → cell #\(cell.number): \(cell.title)\(star)")
    }

    func hide(row: Int) {
        if let cell = visible.removeValue(forKey: row) {
            reuseQueue.append(cell)
        }
    }
}

let titles = ["Buy milk", "Call mom", "Pay rent", "Book flights", "Water plants"]
let favorites: Set<Int> = [1]
let table = FakeTable()

for row in 0..<3 {
    table.show(row: row) { cell in
        cell.title = titles[row]
        if favorites.contains(row) {
            cell.showsStar = true
        }
    }
}

for row in 3..<5 {
    table.hide(row: row - 3)
    table.show(row: row) { cell in
        cell.title = titles[row]
        if favorites.contains(row) {
            cell.showsStar = true
        }
    }
}
print("cells created: \(table.cellsCreated)")
```

```output
row 0 → cell #1: Buy milk
row 1 → cell #2: Call mom ★
row 2 → cell #3: Pay rent
row 3 → cell #1: Book flights
row 4 → cell #2: Water plants ★
cells created: 3
```

Three cells serve five rows. And row 4, "Water plants", shows a star it shouldn't: it got cell #2, which still had `showsStar = true` from "Call mom". The configuration only ever sets the star to `true`; nothing sets it back.

### The fix: set every property for every row

```swift
final class FakeCell {
    let number: Int
    var title = ""
    var showsStar = false

    init(number: Int) {
        self.number = number
    }
}

final class FakeTable {
    private var reuseQueue: [FakeCell] = []
    private var visible: [Int: FakeCell] = [:]
    private var cellsCreated = 0

    func dequeue() -> FakeCell {
        if let cell = reuseQueue.popLast() {
            return cell
        }
        cellsCreated += 1
        return FakeCell(number: cellsCreated)
    }

    func show(row: Int, configure: (FakeCell) -> Void) {
        let cell = dequeue()
        configure(cell)
        visible[row] = cell
        let star = cell.showsStar ? " ★" : ""
        print("row \(row) → cell #\(cell.number): \(cell.title)\(star)")
    }

    func hide(row: Int) {
        if let cell = visible.removeValue(forKey: row) {
            reuseQueue.append(cell)
        }
    }
}

let titles = ["Buy milk", "Call mom", "Pay rent", "Book flights", "Water plants"]
let favorites: Set<Int> = [1]
let table = FakeTable()

func configure(_ cell: FakeCell, row: Int) {
    cell.title = titles[row]
    cell.showsStar = favorites.contains(row)
}

for row in 0..<3 {
    table.show(row: row) { configure($0, row: row) }
}
for row in 3..<5 {
    table.hide(row: row - 3)
    table.show(row: row) { configure($0, row: row) }
}
```

```output
row 0 → cell #1: Buy milk
row 1 → cell #2: Call mom ★
row 2 → cell #3: Pay rent
row 3 → cell #1: Book flights
row 4 → cell #2: Water plants
```

`cell.showsStar = favorites.contains(row)` sets the property to `true` **or** `false` for every row. A configuration written as an assignment from the model, never as "set it only if", can't leave stale state behind.

## prepareForReuse()

`UITableViewCell` has a hook that runs when a cell is about to be reused. From Apple's documentation for `dequeueReusableCell(withIdentifier:for:)`: "If an existing cell was available for reuse, this method calls the cell's prepareForReuse() method instead" of creating one. The `prepareForReuse()` page then sets the boundary:

> "To avoid potential performance issues, you should only reset attributes of the cell that are not related to content, for example, alpha, editing, and selection state. The table view's delegate in tableView(_:cellForRowAt:) should always reset all content when reusing a cell."

So:

| Put it in `prepareForReuse()` | Put it in `cellForRowAt` |
| --- | --- |
| Reset alpha, transforms or animations you applied to the cell | Text, images, colors and accessories that come from the model |
| Cancel work started for the previous row (an image download) | The accessibility label and value for this row |
| Always call `super.prepareForReuse()` | Every property, in every branch |

Two more facts from the same page: the table "doesn't call this method if the cell object doesn't have an associated reuse identifier, or if you use reconfigureRows(at:)", and "if you override this method, you must be sure to invoke the superclass implementation."

### The async image case

The one place `prepareForReuse()` really matters is work that finishes **after** the cell has moved on. A cell starts downloading an avatar for row 3, scrolls off, is reused for row 40, and then the row 3 download completes and sets its image on the cell now showing row 40. Two defenses work together: cancel the old work in `prepareForReuse()`, and when a result arrives, check that the cell still shows the item it was started for:

```swift ios
import UIKit

final class ContactCell: UITableViewCell {
    static let reuseIdentifier = "ContactCell"

    private var avatarTask: Task<Void, Never>?
    private(set) var contactID: String?

    func configure(name: String, contactID: String, loadAvatar: @escaping @MainActor (String) async -> UIImage?) {
        self.contactID = contactID
        var content = defaultContentConfiguration()
        content.text = name
        content.image = UIImage(systemName: "person.crop.circle")
        contentConfiguration = content

        avatarTask = Task { [weak self] in
            let image = await loadAvatar(contactID)
            guard let self, !Task.isCancelled, self.contactID == contactID else { return }
            var updated = defaultContentConfiguration()
            updated.text = name
            updated.image = image
            contentConfiguration = updated
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarTask?.cancel()
        avatarTask = nil
        contactID = nil
    }
}
```

`Task`, `await` and cancellation are Module 29; here the pattern is what matters. `prepareForReuse()` cancels the old task and clears the identity, the task checks both before touching the cell, and the content itself is still set in full by `configure`, which `cellForRowAt` calls for every row.

## Content configurations

`UIListContentConfiguration` describes the standard list content: an image, a primary text, a secondary text, with styling and layout options. You don't create labels; the configuration does.

```swift ios
import UIKit

let cell = UITableViewCell(style: .default, reuseIdentifier: "Setting")

var content = UIListContentConfiguration.valueCell()
content.text = "Storage"
content.secondaryText = "12.4 GB"
content.image = UIImage(systemName: "internaldrive")
content.imageProperties.tintColor = .systemGray
cell.contentConfiguration = content
cell.accessoryType = .disclosureIndicator

var subtitle = UIListContentConfiguration.subtitleCell()
subtitle.text = "Ana Torres"
subtitle.secondaryText = "Last seen 5 minutes ago"
subtitle.secondaryTextProperties.color = .secondaryLabel
```

| Factory | Layout |
| --- | --- |
| `.cell()` | Image and one text |
| `.subtitleCell()` | Text with secondary text below it |
| `.valueCell()` | Text on the left, secondary text on the right (Settings style) |
| `.sidebarCell()`, `.sidebarSubtitleCell()` | Sidebar styles for iPad |

`cell.defaultContentConfiguration()` gives you the cell's default, styled for where the cell appears; the factories pick a specific layout. Either way, the configuration is a **value**: you build it, then assign it, and the cell applies it. That's also why it fits reuse well: assigning a complete new configuration replaces everything the cell showed before. The text and image properties follow Dynamic Type by default.

## Sections, headers and swipe actions

A grouped task list with two sections and swipe-to-delete:

```swift ios
import UIKit

struct TaskItem {
    var title: String
    var isDone: Bool
}

final class TasksViewController: UITableViewController {
    private var sections: [(title: String, tasks: [TaskItem])] = [
        ("Today", [TaskItem(title: "Reply to Ana", isDone: false), TaskItem(title: "Gym", isDone: true)]),
        ("Later", [TaskItem(title: "Renew passport", isDone: false)]),
    ]

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Task")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].tasks.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Task", for: indexPath)
        let task = sections[indexPath.section].tasks[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = task.title
        content.textProperties.color = task.isDone ? .secondaryLabel : .label
        cell.contentConfiguration = content
        cell.accessoryType = task.isDone ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sections[indexPath.section].tasks[indexPath.row].isDone.toggle()
        tableView.reconfigureRows(at: [indexPath])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            sections[indexPath.section].tasks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
```

- `numberOfSections(in:)` defaults to 1 when you don't implement it. `titleForHeaderInSection` returns plain text headers.
- `cellForRowAt` sets the color **and** the accessory from `task.isDone` in both directions, which is the rule from the reuse model.
- **Selecting toggles the model, then reconfigures the row.** The table doesn't know your model changed; you tell it which rows to refresh.
- **Swipe to delete: model first, then table.** `deleteRows(at:with:)` makes the table ask for the new row count and check it against the old count minus the deleted rows. If the model still had the task, the counts wouldn't match and UIKit would stop the app with an "invalid number of rows" exception. Call `completion(true)` to tell UIKit the action was performed.

## Updating the table

| Change | Call, after updating the model |
| --- | --- |
| Everything changed, or you don't know what | `reloadData()`: no animation, every visible cell is requested again |
| Rows removed | `deleteRows(at:with:)` |
| Rows added | `insertRows(at:with:)` |
| Several of the above at once | Wrap them in `performBatchUpdates(_:completion:)` so they animate together and the counts are checked once |
| A row's content changed, same kind of cell | `reconfigureRows(at:)` (iOS 15) |
| A row needs a different cell | `reloadRows(at:with:)` |

Apple on the last two: "For optimal performance, choose to reconfigure rows instead of reloading rows unless you have an explicit need to replace the existing cell with a new cell." `reconfigureRows` runs your `cellForRowAt` again but your dequeue returns the existing cell, so the row doesn't flash and the table "doesn't call prepareForReuse()".

Keeping index paths, counts and model changes in sync by hand is exactly what diffable data sources take over in lesson 5.

## Common mistakes

> [!error] Setting a property in only one branch
> `if task.isDone { cell.accessoryType = .checkmark }` leaves checkmarks on reused cells. Assign from the model every time: `cell.accessoryType = task.isDone ? .checkmark : .none`.

> [!error] Setting content in prepareForReuse()
> Clearing the text there and setting it again in `cellForRowAt` is wasted work, and Apple's documentation says content belongs in `cellForRowAt`. Use `prepareForReuse()` for non-content state and cancelling work, and call `super`.

> [!error] Dequeuing an identifier that was never registered
> `dequeueReusableCell(withIdentifier:for:)` with an identifier the table doesn't know stops the app with an exception asking you to register a nib or class for it. Register in `viewDidLoad()`, before the first reload.

> [!error] Updating the table before (or without) the model
> `deleteRows` with the model unchanged produces an "invalid number of rows" exception. Change the model, then tell the table, inside one batch if there are several changes.

> [!error] Keeping state in the cell
> A cell that remembers "I'm checked" loses it when reused for another row and brings it to the wrong one. State lives in the model; the cell only displays it.

> [!error] Capturing an index path for later
> An index path saved in a closure (a button inside the cell) may point to a different row after inserts or deletes. Look the position up when the event happens (`tableView.indexPath(for: cell)`), or identify rows by a stable id, which is what lesson 5 does.

## Exercises

````exercise
id: m24-l03-e1
type: prediction
prompt: "A smaller reuse model. Two cells are visible at a time. What does this print?"
code: |
  final class Cell {
      let number: Int
      var text = ""
      var isBold = false
      init(number: Int) { self.number = number }
  }

  final class Pool {
      var queue: [Cell] = []
      var created = 0

      func dequeue() -> Cell {
          if let cell = queue.popLast() { return cell }
          created += 1
          return Cell(number: created)
      }
  }

  let pool = Pool()
  let messages = ["Hi", "Lunch?", "Invoice", "See you"]
  let unread: Set<Int> = [0, 2]
  var onScreen: [Cell] = []

  for row in 0..<4 {
      if onScreen.count == 2 {
          pool.queue.append(onScreen.removeFirst())
      }
      let cell = pool.dequeue()
      cell.text = messages[row]
      if unread.contains(row) { cell.isBold = true }
      onScreen.append(cell)
      print("\(row): #\(cell.number) \(cell.text) bold=\(cell.isBold)")
  }
output: |
  0: #1 Hi bold=true
  1: #2 Lunch? bold=false
  2: #1 Invoice bold=true
  3: #2 See you bold=false
hints:
  - "With two cells on screen, showing row 2 first moves the oldest visible cell to the queue."
  - "Which cell does row 2 get, and what was it showing?"
  - "The bug only shows when a reused cell was bold and the new row isn't."
solution: |
  ```output
  0: #1 Hi bold=true
  1: #2 Lunch? bold=false
  2: #1 Invoice bold=true
  3: #2 See you bold=false
  ```

  Row 2 reuses cell #1 (it was bold, and row 2 is unread anyway), and row 3 reuses cell #2 (it was never bold). So this particular scroll **hides** the bug: every reused cell happens to get a row with the same bold state it already had. Make rows 0 and 1 the unread ones and rows 2 and 3 would both show `bold=true`, inherited from the cells they reuse. That's why stale-state bugs feel random. The fix is the same: `cell.isBold = unread.contains(row)`.
````

````exercise
id: m24-l03-e2
type: prediction
prompt: "This model adds prepareForReuse(). What does it print?"
code: |
  final class Cell {
      let number: Int
      var text = ""
      var alpha = 1.0
      var resets = 0
      init(number: Int) { self.number = number }
      func prepareForReuse() {
          alpha = 1.0
          resets += 1
      }
  }

  final class Pool {
      var queue: [Cell] = []
      var created = 0

      func dequeue() -> Cell {
          if let cell = queue.popLast() {
              cell.prepareForReuse()
              return cell
          }
          created += 1
          return Cell(number: created)
      }
  }

  let pool = Pool()
  let first = pool.dequeue()
  first.text = "Archived"
  first.alpha = 0.4
  pool.queue.append(first)

  let second = pool.dequeue()
  print(second.number, second.text, second.alpha, second.resets)
  second.text = "Inbox"
  print(second.number, second.text, second.alpha, second.resets)
  print(pool.created)
output: |
  1 Archived 1.0 1
  1 Inbox 1.0 1
  1
hints:
  - "The second dequeue finds a cell in the queue."
  - "prepareForReuse() resets alpha, not text."
solution: |
  ```output
  1 Archived 1.0 1
  1 Inbox 1.0 1
  1
  ```

  The second dequeue returns the same cell (#1) after calling `prepareForReuse()`, which resets `alpha` to 1.0 and counts the reset. The text is still "Archived" until the configuration code sets it. That's the division Apple describes: `prepareForReuse()` resets non-content state like alpha; content is the job of `cellForRowAt`. Only one cell was ever created.
````

````exercise
id: m24-l03-e3
type: find-errors
prompt: "Users report checkmarks on the wrong rows, a crash when deleting, and rows that stay highlighted. Mark every real problem."
code: |
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Item", for: indexPath)
      let item = items[indexPath.row]
      var content = cell.defaultContentConfiguration()
      content.text = item.name
      cell.contentConfiguration = content
      if item.isSelected {
          cell.accessoryType = .checkmark
      }
      return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      items[indexPath.row].isSelected.toggle()
      tableView.reconfigureRows(at: [indexPath])
  }

  func deleteItem(at indexPath: IndexPath) {
      tableView.deleteRows(at: [indexPath], with: .automatic)
      items.remove(at: indexPath.row)
  }
choices:
  - text: "The accessory is only set when the item is selected, so reused cells keep old checkmarks."
    correct: true
  - text: "deleteRows is called before the model changes, so the row counts don't match."
    correct: true
  - text: "didSelectRowAt never calls deselectRow(at:animated:), so the highlight stays."
    correct: true
  - text: "reconfigureRows(at:) can't be used from didSelectRowAt; it must be reloadData()."
    correct: false
    why: "reconfigureRows is the right call for a content change in an existing row."
  - text: "defaultContentConfiguration() must be created once and stored, not per cell."
    correct: false
    why: "It's a value type built per configuration; getting a fresh one each time is the intended use."
rubric:
  - I found the one-branch accessory.
  - I found the delete order.
  - I found the missing deselect.
solution: |
  Three problems:

  1. **One-branch accessory**: `cell.accessoryType = item.isSelected ? .checkmark : .none`.
  2. **Delete order**: `items.remove(at: indexPath.row)` first, then `deleteRows`. During `deleteRows` the table asks the data source for the new count, which must already be one less.
  3. **No deselect**: call `tableView.deselectRow(at: indexPath, animated: true)` in `didSelectRowAt`. (Here the checkmark shows the selection, so the gray highlight should go.)

  ```swift ios
  import UIKit

  struct Item {
      var name: String
      var isSelected: Bool
  }

  final class PickerViewController: UITableViewController {
      private var items = [Item(name: "Small", isSelected: false), Item(name: "Large", isSelected: true)]

      override func viewDidLoad() {
          super.viewDidLoad()
          tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Item")
      }

      override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
          items.count
      }

      override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
          let cell = tableView.dequeueReusableCell(withIdentifier: "Item", for: indexPath)
          let item = items[indexPath.row]
          var content = cell.defaultContentConfiguration()
          content.text = item.name
          cell.contentConfiguration = content
          cell.accessoryType = item.isSelected ? .checkmark : .none
          return cell
      }

      override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
          tableView.deselectRow(at: indexPath, animated: true)
          items[indexPath.row].isSelected.toggle()
          tableView.reconfigureRows(at: [indexPath])
      }

      func deleteItem(at indexPath: IndexPath) {
          items.remove(at: indexPath.row)
          tableView.deleteRows(at: [indexPath], with: .automatic)
      }
  }
  ```
````

````exercise
id: m24-l03-e4
type: solve
prompt: |
  Model what `deleteRows(at:with:)` checks, in plain Swift. Write `validateDelete(oldCount:newCount:deleted:)` that returns `nil` when the update is consistent, or a message when it isn't:

  - Every deleted row must be a valid index in the old data (`0..<oldCount`). Otherwise return `"row <n> doesn't exist"` for the first bad one.
  - `newCount` must equal `oldCount` minus the number of **distinct** deleted rows. Otherwise return `"expected <x> rows, data source has <y>"`.

  ```swift
  print(validateDelete(oldCount: 5, newCount: 4, deleted: [2]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 5, deleted: [2]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 3, deleted: [0, 4]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 4, deleted: [5]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 3, deleted: [1, 1]) ?? "ok")
  ```

  should print:

  ```plaintext
  ok
  expected 4 rows, data source has 5
  ok
  row 5 doesn't exist
  expected 4 rows, data source has 3
  ```
starter: |
  func validateDelete(oldCount: Int, newCount: Int, deleted: [Int]) -> String? {
      // your code
      nil
  }
hints:
  - "Check the indexes first with a for loop over deleted."
  - "Set(deleted).count gives the number of distinct rows."
rubric:
  - Indexes are validated against the old count.
  - Duplicates count once.
  - The messages match exactly.
  - The function returns nil only for consistent updates.
solution: |
  ```swift
  func validateDelete(oldCount: Int, newCount: Int, deleted: [Int]) -> String? {
      for row in deleted where !(0..<oldCount).contains(row) {
          return "row \(row) doesn't exist"
      }
      let expected = oldCount - Set(deleted).count
      if newCount != expected {
          return "expected \(expected) rows, data source has \(newCount)"
      }
      return nil
  }

  print(validateDelete(oldCount: 5, newCount: 4, deleted: [2]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 5, deleted: [2]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 3, deleted: [0, 4]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 4, deleted: [5]) ?? "ok")
  print(validateDelete(oldCount: 5, newCount: 3, deleted: [1, 1]) ?? "ok")
  ```

  ```output
  ok
  expected 4 rows, data source has 5
  ok
  row 5 doesn't exist
  expected 4 rows, data source has 3
  ```

  The second call is the classic bug: `deleteRows` was called but the model still has 5 items. The last call shows the opposite mistake, two items removed from the model for a single deleted row. UIKit checks the same arithmetic per section after every update and stops the app with an exception when it doesn't add up; the diffable data sources in lesson 5 compute these numbers for you.
````

````exercise
id: m24-l03-e5
type: comprehension
prompt: "A cell starts loading a thumbnail when it's configured. Fast scrolling sometimes shows the wrong thumbnail for a moment. Which combination fixes it?"
choices:
  - text: "Cancel the load in prepareForReuse(), and when a load finishes, apply it only if the cell still shows the item it was started for."
    correct: true
    why: "The first stops most stale results, the second catches any that finish anyway."
  - text: "Call tableView.reloadData() whenever a thumbnail finishes loading."
    correct: false
    why: "That re-requests every visible cell for each image and doesn't stop a stale result from landing on a reused cell."
  - text: "Give each row its own reuse identifier so cells are never reused."
    correct: false
    why: "That defeats reuse and creates a cell per row, which is the problem reuse solves."
  - text: "Set the image to nil in cellForRowAt and never in prepareForReuse()."
    correct: false
    why: "Resetting the placeholder is right, but it doesn't stop the old load from setting its image later."
solution: |
  **Cancel in `prepareForReuse()` and check identity on completion.** A reused cell can receive the result of a load started for its previous row. Cancelling in `prepareForReuse()` stops most of them; comparing the item id stored on the cell with the id the load was for catches results that complete anyway. `cellForRowAt` still sets a placeholder image for every row.
````

````exercise
id: m24-l03-e6
type: explain
prompt: "Explain to a teammate why this cell subclass is a bad idea, and what to do instead."
code: |
  final class FavoriteCell: UITableViewCell {
      var isFavorite = false
      let starButton = UIButton(configuration: .plain())

      func toggle() {
          isFavorite.toggle()
          starButton.configuration?.image = UIImage(systemName: isFavorite ? "star.fill" : "star")
      }
  }
rubric:
  - Explains that the cell is reused for other rows, so isFavorite moves with it.
  - Says the source of truth must be the model, keyed by row or id.
  - Describes the fix - the button reports the tap, the controller updates the model and reconfigures the row.
solution: |
  The cell stores **state**, but cells are recycled. After scrolling, this cell object shows a different row, and `isFavorite` still holds the value from the old one. Tap the star there and you toggle the wrong value; scroll back and the original row's star is gone, because its new cell never knew about it.

  Keep `isFavorite` in the model. The cell only displays it: `cellForRowAt` sets the image from `item.isFavorite` for every row. The button reports the tap (a closure property or a delegate, Module 22), the controller finds the item (by its id, or with `tableView.indexPath(for: cell)` at the moment of the tap), toggles it in the model, and calls `reconfigureRows(at:)`.
````

## Summary

- A table view asks its data source for counts and for one cell per visible row, and its delegate for behavior such as selection and swipe actions.
- Register a cell class, then `dequeueReusableCell(withIdentifier:for:)` in `cellForRowAt`. Configure with `defaultContentConfiguration()` or a `UIListContentConfiguration` factory; `textLabel` is deprecated in the iOS 27 SDK.
- Cells are reused: only about a screen's worth exists. Set every property from the model for every row, in both branches, or old values leak into new rows.
- `prepareForReuse()` resets non-content state and cancels work for the old row; call `super`. Content goes in `cellForRowAt`.
- Change the model first, then tell the table: `deleteRows`, `insertRows`, `performBatchUpdates`; `reconfigureRows` for content changes, `reloadRows` only for a different cell.
