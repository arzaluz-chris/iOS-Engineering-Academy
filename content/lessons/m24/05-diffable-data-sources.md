---
id: m24-l05
title: Diffable data sources
description: Stop counting rows. You fill a collection view with a UICollectionViewDiffableDataSource and NSDiffableDataSourceSnapshot, keep identifiers in the snapshot and models in a store, update items with reconfigureItems instead of reloadItems, apply snapshots with or without animation, and learn the Hashable and Sendable rules that decide whether the diff sees your changes.
module: m24
order: 5
level: intermediate
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l04]
objectives:
  - Create a UICollectionViewDiffableDataSource with a cell provider that uses a cell registration.
  - Build and apply NSDiffableDataSourceSnapshot values to load, insert, delete and move items.
  - Explain why snapshots should hold stable identifiers rather than whole models, and what goes wrong with whole models.
  - Choose between reconfigureItems, reloadItems and applySnapshotUsingReloadData.
  - State the Hashable and Sendable requirements for section and item identifiers and model them in plain Swift.
terms:
  - term: Diffable data source
    definition: "A data source object (UICollectionViewDiffableDataSource, UITableViewDiffableDataSource) that stores section and item identifiers, computes the difference between its current state and a new snapshot, and performs the inserts, deletes and moves for you."
  - term: Snapshot
    definition: "An NSDiffableDataSourceSnapshot value: the sections and items, by identifier, in display order, at one point in time. You build or modify one and apply it."
  - term: Item identifier
    definition: "A Hashable and Sendable value that stands for one item, such as a UUID or an Int id. It must be unique within a snapshot and must not change while the item exists."
  - term: Cell provider
    definition: "The closure you give the diffable data source. It receives the collection view, an index path and an item identifier and returns a configured cell."
  - term: Reconfigure
    definition: "Re-running the cell provider for an item on its existing cell (reconfigureItems, iOS 15), without prepareForReuse and without replacing the cell. The usual way to show a changed property."
mastery:
  - Write a list screen backed by a store and a diffable data source keyed by Recipe.ID.
  - Apply the initial snapshot without animation and later snapshots with animation.
  - Update a changed item with reconfigureItems and explain why a whole-model snapshot can't.
  - Delete an item from a swipe action by updating the store and the snapshot by identifier.
  - Model with CollectionDifference what a diff of identifiers and a diff of whole models report for the same change.
resources: [swift-set, swift-book-protocols, apple-documentation]
cards:
  - id: m24-l05-c1
    front: What are the generic constraints on UICollectionViewDiffableDataSource's section and item identifier types?
    back: "Both must be Hashable and Sendable. If an identifier is a class, it must be an NSObject subclass; Apple recommends structs or enums, such as Int, String or UUID."
  - id: m24-l05-c2
    front: Identifiers or whole models in a snapshot?
    back: "Identifiers. With whole models, any property change makes the item unequal, so the data source sees a delete plus an insert: it loses selection, animates the cell out and in, and you can't use reconfigureItems. Store ids in the snapshot and look up the model in the cell provider."
  - id: m24-l05-c3
    front: reconfigureItems(_:) vs reloadItems(_:)?
    back: "reconfigureItems (iOS 15) re-runs the cell provider on the existing cell, without prepareForReuse. reloadItems replaces the cell. Apple: prefer reconfigure unless you need a different type of cell."
  - id: m24-l05-c4
    front: apply(_:animatingDifferences:) vs applySnapshotUsingReloadData(_:)?
    back: "apply diffs the snapshot against the current state, an O(n) operation, and animates the changes if asked. applySnapshotUsingReloadData skips the diff and resets the collection view, without animation. Use it for the first load or a wholesale replacement."
  - id: m24-l05-c5
    front: Can the same item identifier appear in two sections of one snapshot?
    back: "No. Apple: each item identifier must be unique within a snapshot. For an item shown in two places, wrap it: enum Item: Hashable { case favorite(Recipe.ID), all(Recipe.ID) }."
---

## The idea in one sentence

Instead of telling the collection view which index paths changed, you hand a diffable data source a **snapshot** of what should be on screen now, by identifier, and it works out the inserts, deletes and moves and animates them.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The behavior described comes from Apple's reference pages for `UICollectionViewDiffableDataSource`, `NSDiffableDataSourceSnapshot`, `reconfigureItems(_:)` and the article "Updating collection views using diffable data sources", read in November 2026. The identity and diffing models use Swift's `CollectionDifference` and were compiled and run.

## The problem it solves

Lesson 3 ended with a table of calls (`insertRows`, `deleteRows`, `performBatchUpdates`) and an exception for every time the model and the index paths disagree. Apple's article on diffable data sources puts it this way: a custom data source "uses indices and index paths, which aren't stable. They represent the location of sections and items, which can change." A diffable data source instead "stores a list of section and item identifiers, which represents the identity of each section and item", and "these identifiers are stable."

You stop describing **changes** and start describing **states**:

```plaintext
before: [ramen, tacos, salad]        after: [tacos, salad, curry]
                    ↓ the data source diffs them ↓
        delete ramen, insert curry at the end, animate
```

## The pieces

```swift ios
import UIKit

enum Section {
    case main
}

var snapshot = NSDiffableDataSourceSnapshot<Section, Int>()
snapshot.appendSections([.main])
snapshot.appendItems([10, 20, 30], toSection: .main)
snapshot.deleteItems([20])
snapshot.insertItems([15], beforeItem: 30)
print(snapshot.itemIdentifiers)
print(snapshot.numberOfItems)
```

- `NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>` is a struct. It holds identifiers only, in order.
- The section type here is an enum with one case, and the items are `Int` ids. Enums without associated values are `Hashable` automatically.
- `appendSections`, `appendItems(_:toSection:)`, `insertItems(_:beforeItem:)`, `deleteItems`, `moveItem(_:afterItem:)` change it. All of them talk about identifiers, never index paths.
- By those operations the prints would show `[10, 15, 30]` and `3`. (The block is type-checked, not run: snapshots live in UIKit.)

The generic constraints are on the documentation page, and they matter in Swift 6:

```swift illustrative
struct NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>
    where SectionIdentifierType : Hashable, SectionIdentifierType : Sendable,
          ItemIdentifierType : Hashable, ItemIdentifierType : Sendable
```

`Int`, `String`, `UUID` and your own structs and enums made of them are `Hashable` and `Sendable`. Apple adds: "Use struct or enum Swift value types for your identifiers … If you use a Swift class for your identifiers, your class must be a subclass of NSObject."

## A recipes screen

The pattern from Apple's article: the snapshot holds `Recipe.ID` values, a store holds the recipes, and the cell provider looks one up when it needs to draw it.

```swift ios
import UIKit

struct Recipe: Identifiable {
    let id: UUID
    var title: String
    var minutes: Int
    var isFavorite: Bool
}

@MainActor
final class RecipeStore {
    private(set) var orderedIDs: [Recipe.ID] = []
    private var recipesByID: [Recipe.ID: Recipe] = [:]

    func add(_ recipe: Recipe) {
        orderedIDs.append(recipe.id)
        recipesByID[recipe.id] = recipe
    }

    func recipe(with id: Recipe.ID) -> Recipe? {
        recipesByID[id]
    }

    func toggleFavorite(_ id: Recipe.ID) {
        recipesByID[id]?.isFavorite.toggle()
    }

    func delete(_ id: Recipe.ID) {
        orderedIDs.removeAll { $0 == id }
        recipesByID[id] = nil
    }
}

enum RecipeSection {
    case main
}

final class RecipesViewController: UIViewController {
    private let store: RecipeStore
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<RecipeSection, Recipe.ID>!

    init(store: RecipeStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        loadRecipes()
    }

    private func configureCollectionView() {
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        listConfiguration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
            let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.deleteRecipe(id)
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [delete])
        }
        let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Recipe> { cell, _, recipe in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = recipe.title
            content.secondaryText = "\(recipe.minutes) min"
            content.image = UIImage(systemName: recipe.isFavorite ? "heart.fill" : "heart")
            cell.contentConfiguration = content
            cell.accessibilityValue = recipe.isFavorite ? "Favorite" : nil
        }

        let store = self.store
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            guard let recipe = store.recipe(with: id) else {
                preconditionFailure("The snapshot has an id the store doesn't know: \(id)")
            }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: recipe)
        }
    }

    private func loadRecipes() {
        var snapshot = NSDiffableDataSourceSnapshot<RecipeSection, Recipe.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(store.orderedIDs, toSection: .main)
        dataSource.applySnapshotUsingReloadData(snapshot)
    }

    private func toggleFavorite(_ id: Recipe.ID) {
        store.toggleFavorite(id)
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([id])
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func deleteRecipe(_ id: Recipe.ID) {
        store.delete(id)
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([id])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension RecipesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        toggleFavorite(id)
    }
}
```

Walking through it:

1. **`Recipe` isn't `Hashable`**, and doesn't need to be. Only `Recipe.ID` (a `UUID`) goes into the snapshot. `Identifiable` gives the type a named `ID`.
2. **`RecipeStore` owns the models** and their order. It's `@MainActor` because it's read from the cell provider, which runs on the main actor with the rest of the UI.
3. **The registration's item is `Recipe`; the data source's item is `Recipe.ID`.** As Apple's sample does, the cell provider receives an id, looks the recipe up, and passes the full recipe to the registration.
4. **`let store = self.store`** lets the cell provider capture the store, not the view controller. The data source is owned by the controller, so capturing `self` strongly would be a cycle.
5. **The `preconditionFailure`** documents an invariant: every id in a snapshot has a recipe in the store. If they disagree, that's a bug worth stopping on.
6. **`loadRecipes()`** builds the first snapshot and uses `applySnapshotUsingReloadData(_:)`, which "resets the UI to reflect the state of the data in the snapshot without computing a diff or animating the changes." That suits a first load.
7. **`toggleFavorite(_:)`** changes the model, then asks the current snapshot to **reconfigure** that id and applies it. The cell provider runs again for the existing cell, and the heart fills in.
8. **`deleteRecipe(_:)`**: store first, then the snapshot, by identifier. No index path arithmetic anywhere.
9. **`itemIdentifier(for:)`** turns an index path from a delegate callback or a swipe into the stable id, right away.

> [!warning] Don't replace the data source
> Apple: "Don't change the dataSource on the collection view after you configure it with a diffable data source." The diffable data source sets itself as the collection view's `dataSource`; setting another one breaks it.

## Applying snapshots

| Call | What it does |
| --- | --- |
| `apply(_:animatingDifferences:completion:)` | Diffs the new snapshot against the current state, "an O(n) operation", and performs the changes, animated if `animatingDifferences` is `true` (the default) |
| `await apply(_:animatingDifferences:)` (iOS 15) | The same, as an `async` method that returns when it's done |
| `applySnapshotUsingReloadData(_:)` (iOS 15) | No diff, no animation: "the system interrupts any ongoing item animations and immediately reloads the collection view's content" |
| `dataSource.snapshot()` | Returns the current state, ready to modify |

Two patterns:

- **Rebuild from the model.** Create a new snapshot from the store every time (`appendSections`, `appendItems(store.orderedIDs)`) and apply it. The diff finds what changed. Simple and hard to get wrong; good when the whole list comes from one query.
- **Modify the current snapshot.** `var snapshot = dataSource.snapshot()`, then `deleteItems`, `reconfigureItems`, `appendItems`. Good for single changes like the swipe above.

Apple notes that `apply` can be called "from a background queue, but you must do so consistently". In a Swift 6 app the data source is `@MainActor`, so you call it from the main actor, which is where your view controller already is.

## Identifiers vs whole models

It's tempting to skip the store and put the models in the snapshot: `NSDiffableDataSourceSnapshot<Section, Recipe>` with a `Hashable` `Recipe`. Apple's article explains what that costs: the `Hashable` and `Equatable` implementations "must incorporate all properties of the structure that can change", so after any change the item "is no longer equal to the previous version", and

> "the diffable data source sees the change as a delete of the old item and an insert of a new item. As a result, the collection view loses important state tied to the item. For instance, a selected item becomes unselected."

You can watch this with Swift's own diffing. `difference(from:)` (part of the standard library) compares two arrays by equality, the way the data source compares identifiers:

```swift
struct Recipe: Hashable {
    let id: Int
    var title: String
    var isFavorite: Bool
}

func report<T>(_ diff: CollectionDifference<T>, name: (T) -> String) {
    for change in diff {
        switch change {
        case .remove(let offset, let element, _):
            print("  delete \(name(element)) at \(offset)")
        case .insert(let offset, let element, _):
            print("  insert \(name(element)) at \(offset)")
        }
    }
    if diff.isEmpty { print("  no changes") }
}

let before = [
    Recipe(id: 1, title: "Ramen", isFavorite: false),
    Recipe(id: 2, title: "Tacos", isFavorite: false),
    Recipe(id: 3, title: "Salad", isFavorite: false),
]
var after = before
after[1].isFavorite = true

print("whole models:")
report(after.difference(from: before)) { "\($0.title)\($0.isFavorite ? " ♥" : "")" }

print("identifiers:")
report(after.map(\.id).difference(from: before.map(\.id))) { "#\($0)" }

let changed = after.filter { recipe in before.first { $0.id == recipe.id } != recipe }
print("reconfigure:", changed.map(\.id))
```

```output
whole models:
  delete Tacos at 1
  insert Tacos ♥ at 1
identifiers:
  no changes
reconfigure: [2]
```

- With whole models, marking Tacos as a favorite is a **delete and an insert**: the cell animates out and in, and a selected Tacos row would lose its selection.
- With identifiers, the list structure **didn't change**, and the diff correctly reports nothing. The content change is a separate fact, which you tell the data source with `reconfigureItems([2])`. That's the split Apple's sample makes: structure through the snapshot, content through reconfigure.

Whole models are acceptable for items that never change, like Apple's sidebar example: "Only use this approach for simple use cases in which items don't change … or when the identity of an item isn't important."

## reconfigureItems vs reloadItems

Both say "this item's content changed". From the documentation:

- **`reconfigureItems(_:)`** (iOS 15) updates "the data for the items you specify in the snapshot, preserving the existing cells." It "doesn't call prepareForReuse for each cell dequeued", and "your cell provider must dequeue the same type of cell". Self-sizing cells are resized afterwards.
- **`reloadItems(_:)`** replaces the cell with a newly dequeued one.

Apple: "For optimal performance, choose to reconfigure items instead of reloading items unless you have an explicit need to replace the existing cell with a new cell." The only common reason to reload is that the item now needs a **different cell class**.

## The Hashable rules, modeled

The identifier's `Hashable` conformance **is** its identity as far as the data source is concerned. Apple's article states the contract: "Two identifiers that are equal must always have the same hash value", and each identifier "must be unique within a snapshot". Two ways to get it wrong, in plain Swift:

```swift
struct Message: Hashable {
    let id: Int
    var text: String

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

let original = Message(id: 7, text: "See you at 6")
let edited = Message(id: 7, text: "See you at 7")

print(original == edited)
print(Set([original, edited]).count)
print([edited].difference(from: [original]).isEmpty)

let ids = [1, 2, 2, 3]
print(ids.count == Set(ids).count)
```

```output
true
1
true
false
```

- This `Message` compares only `id`. That's a consistent `Hashable` (equal values hash the same), so it works as an identifier. But used as a **whole model** in a snapshot, the edited text is invisible to the diff: `difference(from:)` reports nothing, and the cell keeps showing "See you at 6" unless you reconfigure it. Whole models with id-only equality get the worst of both approaches.
- The last line is the uniqueness check: `[1, 2, 2, 3]` has a duplicate. A snapshot with a repeated identifier is invalid, and UIKit stops the app with an exception when you append it. Duplicates usually come from the data (two rows from the server with the same id), so deduplicate before building the snapshot.

## One item in two sections

Uniqueness applies across sections too: "an item identifier can't appear in multiple locations within a snapshot." A screen with a Favorites section above All Recipes would put the same `Recipe.ID` in both. Wrap the id in an enum that says where it's shown:

```swift ios
import UIKit

enum LibrarySection {
    case favorites, all
}

enum LibraryItem: Hashable {
    case favorite(UUID)
    case recipe(UUID)
}

let ramen = UUID()
let tacos = UUID()

var snapshot = NSDiffableDataSourceSnapshot<LibrarySection, LibraryItem>()
snapshot.appendSections([.favorites, .all])
snapshot.appendItems([.favorite(tacos)], toSection: .favorites)
snapshot.appendItems([.recipe(ramen), .recipe(tacos)], toSection: .all)
print(snapshot.numberOfItems)
```

`.favorite(tacos)` and `.recipe(tacos)` are different values, so both can be in the snapshot, and the cell provider switches on the case to find the recipe. Declaring `Hashable` is enough for the compiler to synthesize it from the `UUID` payloads, and `Sendable` is inferred because the enum isn't `public` and its payloads are `Sendable`. The print would show `3`.

## Common mistakes

> [!error] Putting mutable models in the snapshot
> A property change turns into delete-plus-insert, selection is lost, and `reconfigureItems` can't target the item. Keep ids in the snapshot and models in a store.

> [!error] Changing the model and forgetting the snapshot
> The data source doesn't watch your store. Apple: "it's the responsibility of the app to detect data changes and tell the diffable data source about those changes, by applying a new snapshot." After a property change, reconfigure; after a structural change, delete, insert or rebuild.

> [!error] Using reloadItems for every change
> It replaces the cell and runs `prepareForReuse`, which costs more and can reset in-cell state such as a running animation. Use `reconfigureItems` unless the cell class changes.

> [!error] Duplicate identifiers
> The same id twice in a snapshot (in one section or two) is invalid and stops the app. Deduplicate the data, or wrap ids in an enum per section.

> [!error] An identifier type that isn't Sendable
> In Swift 6 mode, a class or a struct holding a non-Sendable value doesn't satisfy the `Sendable` constraint, and the data source's generic type doesn't compile. Use value types built from `Sendable` parts, such as `UUID`.

## Exercises

````exercise
id: m24-l05-e1
type: prediction
prompt: "A diff of identifiers, as a diffable data source would compute it. What does this print?"
code: |
  let before = ["ramen", "tacos", "salad"]
  let after = ["tacos", "salad", "curry"]

  let diff = after.difference(from: before)
  for change in diff {
      switch change {
      case .remove(let offset, let element, _):
          print("delete \(element) at \(offset)")
      case .insert(let offset, let element, _):
          print("insert \(element) at \(offset)")
      }
  }
  print(diff.removals.count, diff.insertions.count)
output: |
  delete ramen at 0
  insert curry at 2
  1 1
hints:
  - "tacos and salad are in both arrays in the same relative order."
  - "Removals use offsets in the old array, insertions offsets in the new one."
solution: |
  ```output
  delete ramen at 0
  insert curry at 2
  1 1
  ```

  Only two things changed: `ramen` left (it was at offset 0 in the old array) and `curry` arrived (offset 2 in the new one). `tacos` and `salad` moved up visually, but they kept their identity, so their cells stay and just slide. A diffable data source does this on identifiers when you apply the second snapshot.
````

````exercise
id: m24-l05-e2
type: prediction
prompt: "The same change, once as whole models and once as identifiers. What does it print?"
code: |
  struct Song: Hashable {
      let id: Int
      var title: String
      var plays: Int
  }

  let before = [Song(id: 1, title: "Intro", plays: 10), Song(id: 2, title: "Outro", plays: 4)]
  var after = before
  after[0].plays += 1
  after.append(Song(id: 3, title: "Bonus", plays: 0))

  let modelDiff = after.difference(from: before)
  let idDiff = after.map { $0.id }.difference(from: before.map { $0.id })
  print(modelDiff.removals.count, modelDiff.insertions.count)
  print(idDiff.removals.count, idDiff.insertions.count)

  let toReconfigure = after.filter { song in
      before.contains { $0.id == song.id && $0 != song }
  }.map { $0.id }
  print(toReconfigure)
output: |
  1 2
  0 1
  [1]
hints:
  - "With whole models, Intro with 11 plays isn't equal to Intro with 10."
  - "With ids, only id 3 is new."
  - "toReconfigure keeps songs that existed before but changed."
solution: |
  ```output
  1 2
  0 1
  [1]
  ```

  As whole models, the play count change makes "Intro" a different value: one removal (old Intro) and two insertions (new Intro and Bonus). As identifiers, only Bonus is inserted. The content change to song 1 goes to `reconfigureItems([1])`. That's the reason Apple recommends identifiers: the structure diff stays accurate, and content updates keep the existing cell.
````

````exercise
id: m24-l05-e3
type: comprehension
prompt: "A playlist screen uses NSDiffableDataSourceSnapshot<Section, Song> where Song is a Hashable struct with id, title and isPlaying. Every time the playing song changes, its row flickers and the user's selection disappears. What's the best fix?"
choices:
  - text: "Use Song.ID as the item identifier, keep songs in a store, and call reconfigureItems for the songs whose isPlaying changed."
    correct: true
    why: "Identity stays stable, so the cells and the selection stay; reconfigure updates the content."
  - text: "Apply snapshots with animatingDifferences: false."
    correct: false
    why: "It hides the animation but still deletes and inserts the item, so selection is still lost."
  - text: "Make Song's == compare only id, and keep Song as the identifier."
    correct: false
    why: "Then the diff sees no change at all and the playing indicator never updates unless you reconfigure, which only works reliably with proper identifiers."
  - text: "Call reloadItems with the whole Song value."
    correct: false
    why: "reloadItems needs the identifier that's in the snapshot; the new Song value isn't, since it's unequal to the old one."
solution: |
  **Switch to identifiers and reconfigure.** With whole models, `isPlaying` changing makes the old and new `Song` unequal, so the data source deletes one item and inserts another: flicker and lost selection. With `Song.ID` in the snapshot, the structure doesn't change, and `reconfigureItems([id])` updates the existing cells.
````

````exercise
id: m24-l05-e4
type: find-errors
prompt: "Mark every real problem in this diffable setup."
code: |
  final class NotesViewController: UIViewController {
      private var collectionView: UICollectionView!
      private var notes: [Note] = []
      private var dataSource: UICollectionViewDiffableDataSource<Int, Note.ID>!

      private func configureDataSource() {
          dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
              let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Note> { cell, _, note in
                  var content = cell.defaultContentConfiguration()
                  content.text = note.title
                  cell.contentConfiguration = content
              }
              let note = self.notes.first { $0.id == id }!
              return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: note)
          }
          collectionView.dataSource = self
      }

      func rename(_ id: Note.ID, to title: String) {
          if let index = notes.firstIndex(where: { $0.id == id }) {
              notes[index].title = title
          }
      }
  }
choices:
  - text: "The cell registration is created inside the cell provider."
    correct: true
  - text: "The cell provider captures self strongly, and the controller owns the data source: a retain cycle."
    correct: true
  - text: "collectionView.dataSource = self replaces the diffable data source."
    correct: true
  - text: "rename updates the model but never applies a snapshot that reconfigures the item."
    correct: true
  - text: "Int can't be a section identifier type."
    correct: false
    why: "Int is Hashable and Sendable; Apple's own examples use it."
rubric:
  - I found the registration inside the provider.
  - I found the strong capture of self.
  - I found the replaced dataSource.
  - I found the missing reconfigure after renaming.
solution: |
  Four problems:

  1. **Registration inside the cell provider**: create it once, before the data source, as a local constant the provider captures.
  2. **Strong `self` in the provider**: the controller owns `dataSource`, which owns the provider. Capture a store object, or `[weak self]`.
  3. **`collectionView.dataSource = self`**: Apple says not to change the data source after configuring a diffable one. Delete the line.
  4. **No snapshot after renaming**: add `var snapshot = dataSource.snapshot()`, `snapshot.reconfigureItems([id])`, `dataSource.apply(snapshot)`.

  The force unwrap in the provider is a design choice (an id without a note is a bug); a `guard` with `preconditionFailure` says the same thing more clearly.
````

````exercise
id: m24-l05-e5
type: solve
prompt: |
  Write `buildSnapshot(items:)` in plain Swift. It models the snapshot you'd build for a list whose data comes from a server, which sometimes sends the same item twice.

  - Input: an array of `(id: Int, title: String)` tuples, in server order.
  - Output: the array of ids to append to the snapshot, keeping the **first** occurrence of each id and dropping later duplicates, plus the list of duplicate ids that were dropped (in the order they were found).

  ```swift
  let result = buildSnapshot(items: [(1, "A"), (2, "B"), (1, "A again"), (3, "C"), (2, "B again"), (2, "B third")])
  print(result.ids)
  print(result.dropped)
  ```

  should print:

  ```plaintext
  [1, 2, 3]
  [1, 2, 2]
  ```
starter: |
  func buildSnapshot(items: [(id: Int, title: String)]) -> (ids: [Int], dropped: [Int]) {
      // your code
      ([], [])
  }
hints:
  - "Keep a Set<Int> of ids you've already used."
  - "Set's insert(_:) returns a tuple whose inserted field says whether the value was new."
rubric:
  - Keeps order and the first occurrence.
  - Uses a Set for O(1) membership checks.
  - Reports every dropped duplicate.
  - The output matches.
solution: |
  ```swift
  func buildSnapshot(items: [(id: Int, title: String)]) -> (ids: [Int], dropped: [Int]) {
      var seen = Set<Int>()
      var ids: [Int] = []
      var dropped: [Int] = []
      for item in items {
          if seen.insert(item.id).inserted {
              ids.append(item.id)
          } else {
              dropped.append(item.id)
          }
      }
      return (ids, dropped)
  }

  let result = buildSnapshot(items: [(1, "A"), (2, "B"), (1, "A again"), (3, "C"), (2, "B again"), (2, "B third")])
  print(result.ids)
  print(result.dropped)
  ```

  ```output
  [1, 2, 3]
  [1, 2, 2]
  ```

  `insert(_:)` returns `(inserted: Bool, memberAfterInsert:)`, so one call both checks and records the id. In the app, `ids` goes to `appendItems`, and `dropped` goes to a log so the server bug gets noticed instead of crashing the app with a duplicate identifier.
````

````exercise
id: m24-l05-e6
type: explain
prompt: "Explain to a teammate why this identifier type doesn't compile as a diffable item identifier in Swift 6 mode, and two ways to fix it."
code: |
  final class ContactRow: Hashable {
      let id: UUID
      var name: String
      init(id: UUID, name: String) { self.id = id; self.name = name }
      static func == (lhs: ContactRow, rhs: ContactRow) -> Bool { lhs.id == rhs.id }
      func hash(into hasher: inout Hasher) { hasher.combine(id) }
  }

  var dataSource: UICollectionViewDiffableDataSource<Int, ContactRow>!
rubric:
  - Names the Sendable constraint on ItemIdentifierType.
  - Explains that a class with a mutable stored property isn't Sendable.
  - Mentions Apple's rule that class identifiers must be NSObject subclasses.
  - Proposes using UUID (ContactRow.ID) as the identifier, or a struct.
solution: |
  `UICollectionViewDiffableDataSource` requires `ItemIdentifierType: Hashable & Sendable`. `ContactRow` is a class with a `var`, so it isn't `Sendable` (a mutable class can't be shared safely across concurrency domains, Module 29), and the generic type doesn't type-check. Apple's documentation adds a second rule: a class used as an identifier must be an `NSObject` subclass.

  Fixes, best first:

  1. **Use the id itself**: `UICollectionViewDiffableDataSource<Int, UUID>`, with the `ContactRow` objects in a store the cell provider reads from. This is the identifiers-not-models approach from the lesson.
  2. **Make it a struct of Sendable values** (`struct ContactRow: Hashable { let id: UUID; var name: String }`), which is implicitly `Sendable`. As a whole model it still has the delete-plus-insert problem when `name` changes, so prefer option 1 for anything editable.
````

## Summary

- A diffable data source stores identifiers and computes changes from snapshots. You describe the state, not the changes, and index path bookkeeping disappears.
- Section and item identifier types must be `Hashable` and `Sendable`, unique within a snapshot, and stable for the item's lifetime. Prefer `UUID`, `Int` or small enums; wrap ids in an enum to show one item in two sections.
- Keep identifiers in the snapshot and models in a store; the cell provider looks the model up and passes it to a registration created once.
- Structure changes: modify or rebuild the snapshot and `apply` it (animated). First loads: `applySnapshotUsingReloadData`. Content changes: `reconfigureItems`; `reloadItems` only for a different cell.
- The data source doesn't observe your data. Every change to the store needs a snapshot applied afterwards.
