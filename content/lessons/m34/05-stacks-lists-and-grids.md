---
id: m34-l05
title: Stacks, lists and grids
description: "HStack, VStack and ZStack arrange a handful of views; ForEach repeats views for your data; List, lazy stacks and grids handle long collections. You set spacing and alignment, decide between List and a ScrollView with a LazyVStack, and choose between LazyVGrid and Grid. Most of the lesson is about the one thing ForEach needs from your data, a stable and unique id, and you run a model that shows exactly what goes wrong with index or duplicate ids."
module: m34
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l04]
objectives:
  - Arrange views with HStack, VStack and ZStack, using spacing, alignment and Spacer.
  - Repeat views with ForEach over Identifiable data or with an explicit id key path.
  - Explain why ForEach ids must be unique and stable, and predict what index-based or duplicate ids do to row state.
  - Choose between List, ScrollView with a lazy stack, and a plain stack for a collection.
  - Lay out a collection with LazyVGrid and GridItem, and a table of values with Grid and GridRow.
terms:
  - term: Stack
    definition: "HStack, VStack or ZStack: a container that arranges its children along one axis (or on top of each other, for ZStack). It creates all its children at once."
  - term: ForEach
    definition: "A view that computes child views from a collection, identifying each element by its id. It isn't a loop: it's a view inside a builder."
  - term: Identifiable
    definition: "A Swift standard library protocol: a type with an id property of some Hashable type that identifies an entity across changes to its other properties."
  - term: Lazy stack
    definition: "LazyVStack or LazyHStack: a stack that creates its children only as they're needed on screen, usually inside a ScrollView."
  - term: Stable identity
    definition: "An id that stays with the same element as the collection changes. A database key or a UUID created once is stable; an array index isn't."
mastery:
  - Build a row with an icon, a two-line title and a trailing value, aligned on the text baseline.
  - Make a model type Identifiable with an id that survives edits and reordering.
  - Explain why deleting the first row with index ids makes the wrong row keep its state.
  - Show a 10,000-item feed in a ScrollView with a LazyVStack and pinned section headers.
  - Lay out an adaptive photo grid and a two-column stats table.
resources: [swift-book-protocols, swift-book-collection-types, uikit-supporting-voiceover, hig]
cards:
  - id: m34-l05-c1
    front: What does ForEach need from each element?
    back: "A unique, stable identity: either the element is Identifiable or you pass id: with a key path to a Hashable property. SwiftUI uses it to match rows across updates, keeping state and animating inserts, deletes and moves."
  - id: m34-l05-c2
    front: Why are array indices bad ForEach ids?
    back: "They identify positions, not items. Delete the first item and every later item gets a new id; SwiftUI sees the last row as deleted, and per-row state such as an expanded section stays with the position, now showing on the wrong item."
  - id: m34-l05-c3
    front: "When is id: \\.self acceptable?"
    back: "When the values themselves are unique and stable, like a list of distinct tag strings or a range of integers. Duplicates give two rows the same identity, which Apple's documentation says isn't allowed."
  - id: m34-l05-c4
    front: VStack or LazyVStack inside a ScrollView?
    back: "VStack creates every child immediately: fine for a few dozen. LazyVStack creates children as they scroll into view: use it for long or unbounded collections. Apple: switch to lazy stacks as performance issues arise."
  - id: m34-l05-c5
    front: LazyVGrid or Grid?
    back: "Grid (iOS 16) creates all cells at once and aligns cells across rows and columns; use it for small tables. LazyVGrid creates cells on demand from column descriptions (GridItem); use it for long scrolling collections."
---

## The idea in one sentence

Stacks arrange a few views, `ForEach` repeats views for your data, and lists, lazy stacks and grids scale that to long collections, and every one of them depends on each element having a **stable, unique id** so SwiftUI can tell rows apart as the data changes.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run. The identity model is plain Swift and was run; it's a simplified model of the matching that Apple's documentation describes, not SwiftUI's implementation. Container behavior is quoted from Apple's SwiftUI reference, read in November 2026.

## Stacks

```swift ios
import SwiftUI

struct TransactionRow: View {
    let merchant: String
    let category: String
    let amount: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "cart")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(.body)
                Text(category)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount)
                .monospacedDigit()
        }
    }
}

struct AvatarWithBadge: View {
    let unread: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            Text("\(unread)")
                .font(.caption2.bold())
                .padding(4)
                .background(.red, in: Circle())
                .foregroundStyle(.white)
        }
    }
}
```

- **Axis and alignment.** `HStack` lays out left to right (leading to trailing in right-to-left languages) and takes a `VerticalAlignment`: `.top`, `.center` (the default), `.bottom`, `.firstTextBaseline`, `.lastTextBaseline`. `VStack` takes a `HorizontalAlignment`: `.leading`, `.center`, `.trailing`. `ZStack` takes an `Alignment` with both. Baseline alignment lines up the first lines of text even when fonts or icons differ in size, which is what you want in most rows.
- **Spacing.** `spacing: nil`, the default, uses the system's spacing between each pair of children. Pass a number for a fixed gap.
- **`Spacer()`** is "a flexible space that expands along the major axis of its containing stack layout". In the row, it pushes the amount to the trailing edge. Apple adds that a stack without a spacer sizes itself "up to the combined ideal widths of the content of the stack's child views", so a spacer is also what makes a row as wide as the screen.
- **`ZStack`** layers its children: it "assigns each successive subview a higher z-axis value than the one before it, meaning later subviews appear 'on top'". The badge is last, so it's in front.

Compared with Module 23's `UIStackView`, there are no constraints to add and nothing to pin. A stack sizes itself from its children and is placed by its parent. Lesson 6 explains the rules behind that.

## ForEach and identity

`ForEach` turns a collection into views. Apple's `ForEach` page: "Either the collection's elements must conform to `Identifiable` or you need to provide an `id` parameter to the `ForEach` initializer."

```swift ios
import SwiftUI

struct Todo: Identifiable {
    let id: Int
    var title: String
    var isDone: Bool
}

struct TodoListView: View {
    @State private var todos = [
        Todo(id: 10, title: "Buy milk", isDone: false),
        Todo(id: 11, title: "Call Ana", isDone: true),
        Todo(id: 12, title: "Pay rent", isDone: false),
    ]

    var body: some View {
        List {
            Section("Today") {
                ForEach(todos) { todo in
                    Label(todo.title, systemImage: todo.isDone ? "checkmark.circle.fill" : "circle")
                }
                .onDelete { offsets in
                    todos.remove(atOffsets: offsets)
                }
            }
        }
    }
}

struct TagCloud: View {
    let tags: [String]   // assumed unique

    var body: some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text("#" + tag)
            }
        }
    }
}
```

- **`Identifiable`** is a standard library protocol, not a SwiftUI one: a type with an `id` of some `Hashable` type. `Todo`'s `id` comes from wherever todos are stored (a database key, a server id) and never changes, even when the title does.
- **`id: \.self`** uses the value itself as its id. That's fine for `tags` only if no tag appears twice.
- **`onDelete(perform:)`** adds swipe-to-delete in a `List`. It gives you the offsets; you remove them from the data. Apple: "You must delete the corresponding item within `action`, as it will be called after the row has already been removed."

### What the id is for

Every time `body` runs, `ForEach` produces a new set of rows. SwiftUI matches each new row to an old one **by id**: same id means same row, so its state is kept and it can animate to its new position; an id that's new is an insertion; an id that's gone is a deletion. That's lesson 1's identity applied to a collection. Apple's `Identifiable` page describes the requirement on your side: an id that lets you "identify a particular user even if other data fields change, such as the user's name."

Here's that matching as plain Swift, with per-row state (whether a row is expanded) keyed by id. The same three todos are identified two ways: by their real id, and by their array index. The user expands "Call Ana", then deletes "Buy milk":

```swift
struct Change<ID: Hashable> {
    var inserted: [ID] = []
    var removed: [ID] = []
}

/// Matches old rows to new rows by id.
func reconcile<ID: Hashable>(old: [ID], new: [ID]) -> Change<ID> {
    let oldSet = Set(old)
    let newSet = Set(new)
    return Change(inserted: new.filter { !oldSet.contains($0) },
                  removed: old.filter { !newSet.contains($0) })
}

struct Todo {
    let id: Int
    let title: String
}

let before = [Todo(id: 10, title: "Buy milk"), Todo(id: 11, title: "Call Ana"), Todo(id: 12, title: "Pay rent")]
let after = Array(before.dropFirst())     // "Buy milk" deleted

// Identified by a stable id: "Call Ana" is expanded.
let expandedByID: [Int: Bool] = [11: true]
let byID = reconcile(old: before.map(\.id), new: after.map(\.id))
print("by id: removed \(byID.removed), inserted \(byID.inserted)")
for todo in after {
    print("  \(todo.title)\(expandedByID[todo.id] == true ? " (expanded)" : "")")
}

// Identified by position: "Call Ana" was at index 1.
let expandedByIndex: [Int: Bool] = [1: true]
let byIndex = reconcile(old: Array(before.indices), new: Array(after.indices))
print("by index: removed \(byIndex.removed), inserted \(byIndex.inserted)")
for (index, todo) in after.enumerated() {
    print("  \(todo.title)\(expandedByIndex[index] == true ? " (expanded)" : "")")
}
```

```output
by id: removed [10], inserted []
  Call Ana (expanded)
  Pay rent
by index: removed [2], inserted []
  Call Ana
  Pay rent (expanded)
```

With real ids, the change is exactly what happened: row 10 left, the others stayed, and "Call Ana" is still expanded. With indices, the list looks like it lost its **last** row (index 2), and the expanded state stayed at index 1, which is now "Pay rent". On screen that means the wrong deletion animation and a row that's suddenly expanded for no reason. Any state inside a row (a text field's draft, a toggle, an expanded section, an image being loaded) follows the id.

> [!warning] A model
> SwiftUI's actual diffing isn't documented and is certainly smarter than two sets. The model shows the part that's guaranteed by Apple's description: rows are matched by id, so an id that names a position instead of an item matches the wrong things.

### Rules for ids

- **Unique.** Two elements with the same id are, as far as SwiftUI can tell, the same row. Apple's article "Creating performant scrollable stacks" is explicit: "each element you iterate over must be uniquely identifiable." `ForEach(names, id: \.self)` with "Ana" twice breaks this.
- **Stable.** The same item keeps the same id across updates. Not an index, not `UUID()` computed in a property getter (a new id every time `body` runs means every row is "new" every time).
- **Part of the data.** Create the id when you create the item, or take it from the server or database. If your model has no natural id, add `let id = UUID()` as a stored property, set once at creation.
- **Constant number of views per element**, for performance in lazy containers. Apple's `ForEach` page says containers like `List` and `LazyVStack` query elements lazily, and recommends that each element produce a constant number of views: wrap an `if` inside a row in a stack rather than letting an element produce one view or none.

## Long collections

A `VStack` with a `ForEach` over 10,000 items creates 10,000 rows when it appears. For long collections, use a container that creates rows on demand.

### List

`List` is the SwiftUI counterpart of a table view: lazily created rows, platform styling, separators, sections, swipe actions, selection and editing.

```swift ios
import SwiftUI

struct Contact: Identifiable {
    let id: Int
    var name: String
    var isFavorite: Bool
}

struct ContactsView: View {
    @State private var contacts = [
        Contact(id: 1, name: "Ana Torres", isFavorite: true),
        Contact(id: 2, name: "Ben Okafor", isFavorite: false),
    ]

    var body: some View {
        List {
            ForEach($contacts) { $contact in
                HStack {
                    Text(contact.name)
                    Spacer()
                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .accessibilityLabel("Favorite")
                    }
                }
                .swipeActions {
                    Button(contact.isFavorite ? "Unfavorite" : "Favorite") {
                        contact.isFavorite.toggle()
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
```

- **`ForEach($contacts) { $contact in … }`** iterates over bindings to the elements, so a row can change its own contact. Bindings are lesson 4's; this form is how you pass one per row.
- **`swipeActions`** (iOS 15) puts custom buttons behind a swipe, like `UIContextualAction` in UIKit.
- **`listStyle(.insetGrouped)`** chooses the look. There are several, and the default depends on context.

### ScrollView with a lazy stack

When you want full control over the look (cards, no separators, custom spacing), use a `ScrollView` and a lazy stack:

```swift ios
import SwiftUI

struct Post: Identifiable {
    let id: Int
    let author: String
    let text: String
}

struct DaySection: Identifiable {
    let id: String          // "Today", "Yesterday"
    let posts: [Post]
}

struct FeedView: View {
    let days: [DaySection]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                ForEach(days) { day in
                    Section {
                        ForEach(day.posts) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.author)
                                    .font(.headline)
                                Text(post.text)
                            }
                            .padding()
                            .background(.background, in: RoundedRectangle(cornerRadius: 22))
                        }
                    } header: {
                        Text(day.id)
                            .font(.subheadline.bold())
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.bar)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
```

`LazyVStack` "doesn't create items until it needs to render them onscreen", and `pinnedViews: [.sectionHeaders]` keeps each day's header stuck to the top while its posts scroll by. Apple's article "Creating performant scrollable stacks" gives the trade-off: regular stacks "load their child views all at once, making layout fast and reliable", while lazy stacks "trade some degree of layout correctness for performance, because the system only calculates the geometry for subviews as they become visible." Its advice is to start with plain stacks inside a `ScrollView` and "switch to lazy stacks as performance issues arise."

How to choose:

| You need | Use |
| --- | --- |
| A standard list with separators, swipe actions, selection, editing | `List` |
| A long custom-styled feed | `ScrollView` + `LazyVStack` |
| A few dozen views that scroll | `ScrollView` + `VStack` |
| A handful of views that fit | A stack, no scroll view |

## Grids

Two families, for two jobs.

### LazyVGrid: long collections in columns

```swift ios
import SwiftUI

struct Photo: Identifiable {
    let id: Int
    let symbol: String
}

struct PhotoGrid: View {
    let photos: [Photo]
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos) { photo in
                    Image(systemName: photo.symbol)
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Photo \(photo.id)")
                }
            }
            .padding()
        }
    }
}
```

`LazyVGrid` takes an array of `GridItem`s describing its **columns**; rows are created as needed. Each `GridItem.Size` is one of:

- `.fixed(80)`: one column exactly 80 points wide.
- `.flexible(minimum:maximum:)`: one column that shares the remaining width with the other flexible ones.
- `.adaptive(minimum:maximum:)`: Apple describes it as "multiple items in the space of a single flexible item": as many columns of at least `minimum` as fit. One adaptive item gives a grid that has three columns on a narrow phone and more on an iPad, with no code for each size.

### Grid: small tables with aligned cells

```swift ios
import SwiftUI

struct WorkoutStats: View {
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Distance")
                Text("5.2 km").bold()
            }
            GridRow {
                Text("Average pace")
                Text("5:41 /km").bold()
            }
            Divider()
            GridRow {
                Text("Total time")
                Text("29:35").bold()
            }
        }
    }
}
```

`Grid` (iOS 16) creates all its cells at once and sizes each column to its widest cell, so labels and values line up across rows, which separate `HStack`s can't do. A view that isn't in a `GridRow`, like the `Divider`, spans all columns. Apple's guidance on picking: "Only use a lazy grid if profiling your app shows that a `Grid` view performs poorly because it tries to load too many views at once."

## Common mistakes

> [!error] ForEach(items.indices, id: \.self)
> Indices identify positions. Inserting or deleting anywhere but the end shifts every later id, so rows animate wrongly and per-row state jumps to a different item. Make the element `Identifiable` with a stored, stable id.

> [!error] id: \.self on values that can repeat
> `ForEach(["Milk", "Eggs", "Milk"], id: \.self)` gives two rows one identity. Use a struct with its own id for anything a user can enter twice.

> [!error] var id: UUID { UUID() }
> A computed id is a new id on every read, so every row is a new row on every update: no preserved state, no correct animations, more work. Store the id: `let id = UUID()`.

> [!error] A VStack with thousands of rows
> Every row is created up front. Use `List` or a `LazyVStack` inside the `ScrollView`.

> [!error] A for loop or an index range to repeat views
> `for` doesn't work in a view builder (lesson 3), and `ForEach(0..<items.count)` is the index problem again. `ForEach(items)` with `Identifiable` elements is almost always what you want.

## Exercises

````exercise
id: m34-l05-e1
type: prediction
prompt: "The reconcile model from the lesson, with a stable-id list where one item is inserted at the top and another deleted. What does it print?"
code: |
  struct Change<ID: Hashable> {
      var inserted: [ID] = []
      var removed: [ID] = []
  }

  func reconcile<ID: Hashable>(old: [ID], new: [ID]) -> Change<ID> {
      let oldSet = Set(old)
      let newSet = Set(new)
      return Change(inserted: new.filter { !oldSet.contains($0) },
                    removed: old.filter { !newSet.contains($0) })
  }

  let oldIDs = ["a1", "b2", "c3", "d4"]
  let newIDs = ["z9", "a1", "c3", "d4"]

  let byID = reconcile(old: oldIDs, new: newIDs)
  print(byID.inserted, byID.removed)

  let byIndex = reconcile(old: Array(oldIDs.indices), new: Array(newIDs.indices))
  print(byIndex.inserted, byIndex.removed)
output: |
  ["z9"] ["b2"]
  [] []
hints:
  - "By id: which ids are new, and which disappeared?"
  - "By index: both lists have four elements."
solution: |
  ```output
  ["z9"] ["b2"]
  [] []
  ```

  With real ids, the change is one insertion (`z9`) and one deletion (`b2`), which is what happened. With indices, both lists are positions 0 through 3, so nothing looks inserted or removed: every row would simply show different content in place, with no insert or delete animation, and any per-row state would stay with its position while the items under it changed.
````

````exercise
id: m34-l05-e2
type: prediction
prompt: "Per-row drafts in a list of comments, keyed by index. The first comment is deleted. Which draft shows next to which comment?"
code: |
  let before = ["Nice photo!", "Where is this?", "Love the colors"]
  var draftByIndex: [Int: String] = [1: "It's Lisbon", 2: "Thanks!"]

  let after = Array(before.dropFirst())
  for (index, comment) in after.enumerated() {
      let draft = draftByIndex[index] ?? "-"
      print("\(comment) -> reply draft: \(draft)")
  }
  draftByIndex = draftByIndex.filter { after.indices.contains($0.key) }
  print(draftByIndex.count)
output: |
  Where is this? -> reply draft: -
  Love the colors -> reply draft: It's Lisbon
  1
hints:
  - "After the deletion, \"Where is this?\" is at index 0, and index 0 has no draft."
  - "Index 2 no longer exists, so its draft is dropped."
solution: |
  ```output
  Where is this? -> reply draft: -
  Love the colors -> reply draft: It's Lisbon
  1
  ```

  The user was replying "It's Lisbon" to "Where is this?" (index 1) and "Thanks!" to "Love the colors" (index 2). After the first comment is deleted, every comment moves up one index, but the drafts stay where they were. "Where is this?" is now at index 0, which has no draft. "Love the colors" is at index 1 and shows the Lisbon reply meant for the other comment. Index 2 no longer exists, so the "Thanks!" draft is thrown away: one draft left. Keyed by each comment's id, both drafts would have stayed with their comments.
````

````exercise
id: m34-l05-e3
type: comprehension
prompt: "A chat screen shows up to several thousand messages in custom bubbles, with no separators and newest at the bottom. Which container fits best?"
choices:
  - text: "A ScrollView containing a LazyVStack with ForEach over Identifiable messages."
    correct: true
    why: "Custom styling and thousands of rows: a lazy stack creates only the bubbles near the visible area."
  - text: "A ScrollView containing a VStack with ForEach."
    correct: false
    why: "A VStack creates every bubble when it appears; thousands is too many."
  - text: "A Grid with one GridRow per message."
    correct: false
    why: "Grid creates all cells at once and is meant for small aligned tables."
  - text: "A VStack with a for loop over the messages."
    correct: false
    why: "for loops aren't allowed in a view builder, and a VStack isn't lazy."
solution: |
  **`ScrollView` + `LazyVStack` + `ForEach`.** The design is custom, so `List`'s styling would get in the way, and the count is large, so the stack must be lazy. Each message needs a stable id (the server's message id) so new messages insert cleanly and rows keep their state.
````

````exercise
id: m34-l05-e4
type: solve
prompt: |
  Before handing data to `ForEach(items, id: …)`, a debug check can catch duplicate ids. Write a generic function

  ```swift
  func duplicateIDs<Element, ID: Hashable & Comparable>(in items: [Element], id: (Element) -> ID) -> [ID]
  ```

  that returns every id that appears more than once, each listed once, sorted. Then run:

  ```swift
  let groceries = ["Milk", "Eggs", "Milk", "Bread", "Eggs", "Milk"]
  print(duplicateIDs(in: groceries) { $0 })

  struct Song { let title: String; let trackNumber: Int }
  let album = [Song(title: "Intro", trackNumber: 1), Song(title: "Rain", trackNumber: 2), Song(title: "Rain (Live)", trackNumber: 2)]
  print(duplicateIDs(in: album) { $0.trackNumber })
  print(duplicateIDs(in: album) { $0.title })
  ```
starter: |
  func duplicateIDs<Element, ID: Hashable & Comparable>(in items: [Element], id: (Element) -> ID) -> [ID] {
      // your code
      []
  }
hints:
  - "Count each id with a [ID: Int] dictionary."
  - "Keep the keys whose count is more than 1, then sort them."
rubric:
  - Counts ids in one pass with a dictionary.
  - Returns each duplicated id once, sorted.
  - Works for any element type through the id closure.
  - Prints the three expected lines.
solution: |
  ```swift
  func duplicateIDs<Element, ID: Hashable & Comparable>(in items: [Element], id: (Element) -> ID) -> [ID] {
      var counts: [ID: Int] = [:]
      for item in items {
          counts[id(item), default: 0] += 1
      }
      return counts.filter { $0.value > 1 }.map(\.key).sorted()
  }

  let groceries = ["Milk", "Eggs", "Milk", "Bread", "Eggs", "Milk"]
  print(duplicateIDs(in: groceries) { $0 })

  struct Song { let title: String; let trackNumber: Int }
  let album = [Song(title: "Intro", trackNumber: 1), Song(title: "Rain", trackNumber: 2), Song(title: "Rain (Live)", trackNumber: 2)]
  print(duplicateIDs(in: album) { $0.trackNumber })
  print(duplicateIDs(in: album) { $0.title })
  ```

  ```output
  ["Eggs", "Milk"]
  [2]
  []
  ```

  `ForEach(groceries, id: \.self)` would give "Milk" three rows with one identity. The album shows that a property can look like an id and not be one: two tracks share number 2, while titles happen to be unique here. The fix in both cases is a real id stored on each element. The sort makes the output deterministic, since dictionary order isn't.
````

````exercise
id: m34-l05-e5
type: fill-in
prompt: "Complete the grid so it shows as many columns of at least 120 points as fit, creates cells lazily, and scrolls."
code: |
  struct BadgeGrid: View {
      let badges: [Badge]   // Badge: Identifiable
      private let columns = [GridItem(.[[1]](minimum: 120))]

      var body: some View {
          [[2]] {
              [[3]](columns: columns, spacing: 12) {
                  ForEach(badges) { badge in
                      BadgeCell(badge: badge)
                  }
              }
          }
      }
  }
blanks:
  - id: "1"
    answers: ["adaptive"]
  - id: "2"
    answers: ["ScrollView"]
  - id: "3"
    answers: ["LazyVGrid"]
hints:
  - "The GridItem size that fits as many columns as possible."
  - "Lazy grids don't scroll by themselves."
solution: |
  ```swift ios
  import SwiftUI

  struct Badge: Identifiable {
      let id: Int
      let name: String
  }

  struct BadgeCell: View {
      let badge: Badge

      var body: some View {
          Label(badge.name, systemImage: "rosette")
              .frame(maxWidth: .infinity, minHeight: 80)
      }
  }

  struct BadgeGrid: View {
      let badges: [Badge]
      private let columns = [GridItem(.adaptive(minimum: 120))]

      var body: some View {
          ScrollView {
              LazyVGrid(columns: columns, spacing: 12) {
                  ForEach(badges) { badge in
                      BadgeCell(badge: badge)
                  }
              }
          }
      }
  }
  ```

  One `.adaptive(minimum: 120)` item fits as many columns of at least 120 points as the width allows. `LazyVGrid` creates cells as they're needed, and the `ScrollView` makes it scroll; without it, the grid would simply be cut off.
````

````exercise
id: m34-l05-e6
type: find-errors
prompt: "Which of these are real problems in this shopping list?"
code: |
  struct ShoppingItem {
      var name: String
      var quantity: Int
      var id: UUID { UUID() }
  }

  struct ShoppingListView: View {
      @State private var items: [ShoppingItem] = []

      var body: some View {
          ScrollView {
              VStack {
                  ForEach(items.indices, id: \.self) { index in
                      if items[index].quantity > 0 {
                          Text("\(items[index].quantity) × \(items[index].name)")
                      }
                  }
              }
          }
      }
  }
choices:
  - text: "The id is computed, so it's a new UUID on every read, and it isn't even used."
    correct: true
    why: "An id must be stored and stable. Make it let id = UUID() and conform to Identifiable."
  - text: "ForEach uses indices as ids, so deletions and insertions match the wrong rows."
    correct: true
    why: "Indices identify positions, not items."
  - text: "Each element produces one view or none, which Apple's ForEach page says hurts lazy containers."
    correct: true
    why: "Apple recommends a constant number of views per element; filter the data first or wrap the if in a stack."
  - text: "A non-lazy VStack is a problem for a short shopping list."
    correct: false
    why: "A shopping list has a few dozen items at most; a plain stack in a scroll view is fine. It would matter for thousands."
  - text: "ForEach can't be used inside a ScrollView."
    correct: false
    why: "ForEach works in any view builder: stacks, lists, grids, scroll views."
rubric:
  - Flags the computed id.
  - Flags indices as ids.
  - Flags the variable number of views per element, or suggests filtering before ForEach.
  - Doesn't flag the VStack for a short list.
solution: |
  ```swift ios
  import SwiftUI

  struct ShoppingItem: Identifiable {
      let id = UUID()
      var name: String
      var quantity: Int
  }

  struct ShoppingListView: View {
      @State private var items: [ShoppingItem] = []

      private var itemsToBuy: [ShoppingItem] {
          items.filter { $0.quantity > 0 }
      }

      var body: some View {
          ScrollView {
              VStack(alignment: .leading) {
                  ForEach(itemsToBuy) { item in
                      Text("\(item.quantity) × \(item.name)")
                  }
              }
          }
      }
  }
  ```

  The id is stored once per item, `ShoppingItem` is `Identifiable`, `ForEach` iterates the items rather than their positions, and filtering happens on the data, so every element produces exactly one row. The `VStack` is fine at this size; switch to `LazyVStack` if the list could grow into the thousands.
````

## Summary

- `HStack`, `VStack` and `ZStack` arrange a few views; alignment and spacing are parameters, and `Spacer` takes up the free space along the stack's axis.
- `ForEach` repeats views from data. It needs `Identifiable` elements or an `id:` key path.
- SwiftUI matches rows across updates by id. Ids must be unique and stable: stored on the item, never an index, never computed fresh.
- Use `List` for standard lists, a `ScrollView` with `LazyVStack` for long custom feeds, and plain stacks for short content.
- `LazyVGrid` with `GridItem`s (`fixed`, `flexible`, `adaptive`) handles long grids; `Grid` with `GridRow` aligns small tables.
