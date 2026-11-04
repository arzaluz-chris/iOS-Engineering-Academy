---
id: m35-l03
title: Sheets, full-screen covers, alerts and confirmation dialogs
description: "In SwiftUI you don't present a screen, you set state that says it's presented. You drive sheets and full-screen covers from a Bool or from an optional item, see why one optional enum beats a pile of Bools, size sheets with presentation detents, close them from inside with the dismiss action, and ask questions with alerts and confirmation dialogs whose buttons carry roles."
module: m35
order: 3
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m35-l02, m25-l03]
objectives:
  - Present a sheet or full-screen cover from a Bool binding and from an optional Identifiable item, and choose between them.
  - Model every sheet a screen can show as one optional enum instead of several Bools.
  - Offer medium and large sizes with presentationDetents and control interactive dismissal.
  - Dismiss a presented view from inside with @Environment(\.dismiss), reading it in the right view.
  - Ask for confirmation with alert and confirmationDialog, passing data with presenting and using destructive and cancel roles.
terms:
  - term: Sheet
    definition: "A view presented over the current one, as a card the user can drag down on iPhone. In SwiftUI it's shown while a Bool binding is true or an optional item is non-nil."
  - term: Full-screen cover
    definition: "A modal view that covers as much of the screen as possible (fullScreenCover, iOS 14). It has the same Bool and item forms as sheet."
  - term: Presentation detent
    definition: "A height where a sheet naturally rests (iOS 16): .medium, .large, .fraction(_:) or .height(_:). With more than one, people can drag the sheet between them."
  - term: DismissAction
    definition: "The value of the dismiss environment value (iOS 15). Calling it dismisses the presentation, or pops the view from a NavigationStack, depending on where it's read."
  - term: Button role
    definition: "A ButtonRole (iOS 15) that describes a button's purpose: .destructive for irreversible actions, .cancel for backing out. Alerts and dialogs use roles to style and order buttons."
mastery:
  - Present an editor sheet for a tapped recipe with sheet(item:), so the editor always gets the right recipe.
  - Replace three Bool flags for three sheets with one optional enum.
  - Give a sheet medium and large detents and a visible drag indicator.
  - Write a Done button inside a sheet that dismisses it, and explain why reading dismiss in the presenting view doesn't work.
  - Confirm a deletion with a confirmationDialog that has a destructive button and passes the item with presenting.
resources: [uikit-sheet-presentation, uikit-uialertcontroller, swift-book-enumerations, hig]
cards:
  - id: m35-l03-c1
    front: sheet(isPresented:) or sheet(item:)?
    back: "isPresented when the sheet needs no data (an About screen). item when it shows something chosen: the content closure receives the unwrapped item, and Apple says that if the item changes, the system dismisses the sheet and presents a new one. The item must be Identifiable."
  - id: m35-l03-c2
    front: Why one optional enum instead of several Bools for a screen's sheets?
    back: "Two Bools have four combinations, and one (both true) is a state the screen can't show. An optional enum with two cases has exactly three states: none, one, or the other. Make the invalid state impossible to write."
  - id: m35-l03-c3
    front: How do you dismiss a sheet from inside it?
    back: "Read @Environment(\\.dismiss) private var dismiss in the view that's inside the sheet and call dismiss(). If you read it in the presenting view, it refers to that view's environment and fails to dismiss the sheet (Apple's own warning)."
  - id: m35-l03-c4
    front: presentationDetents([.medium, .large])?
    back: "iOS 16. Lets the sheet rest at about half the screen height or full height, and people can drag between them. By default a sheet supports only .large. Apple: .medium is inactive in compact height."
  - id: m35-l03-c5
    front: alert vs confirmationDialog?
    back: "Alert: something the user must know or answer, with few buttons; no cancel button unless you add one with role .cancel. Confirmation dialog: a choice about an action the user just started (Delete?, Discard?); it has a standard dismiss action and shows as a popover in regular size classes."
---

## The idea in one sentence

You don't call "present" in SwiftUI: you keep **state that says whether something is presented** (a `Bool`, or an optional value), attach a presentation modifier that reads it, and SwiftUI shows, replaces and dismisses the presentation to match, writing back to your state when the user dismisses it.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run. Behavior comes from Apple's pages for `sheet(isPresented:onDismiss:content:)`, `sheet(item:onDismiss:content:)`, `fullScreenCover`, `presentationDetents(_:)`, `dismiss`, `alert` and `confirmationDialog`, read in November 2026; it wasn't checked in a simulator. The state models are plain Swift, compiled and run with Swift 6.3.

## Sheets from a Bool

Module 25 presented a view controller with `present(_:animated:)` and dismissed it with `dismiss(animated:)`. SwiftUI replaces both calls with one binding:

```swift ios
import SwiftUI

struct ShoppingListView: View {
    @State private var isAddingItem = false
    @State private var items = ["Milk", "Eggs"]

    var body: some View {
        NavigationStack {
            List(items, id: \.self) { item in
                Text(item)
            }
            .navigationTitle("Shopping")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    isAddingItem = true
                }
            }
            .sheet(isPresented: $isAddingItem) {
                AddItemView { newItem in
                    items.append(newItem)
                }
            }
        }
    }
}

struct AddItemView: View {
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item", text: $name)
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
```

1. **`@State private var isAddingItem = false`** is the presentation state. The Add button sets it to `true`.
2. **`.sheet(isPresented: $isAddingItem) { … }`** shows the closure's view while the binding is `true`. When the user drags the sheet down, SwiftUI sets it back to `false`; you don't write that code.
3. **`AddItemView`** gets a closure to report the result, the same "return a result through a closure" pattern as Module 25's lesson 4. It doesn't know who presented it.
4. **`@Environment(\.dismiss)`** inside `AddItemView` gives the action that closes *this* presentation. Both buttons call it.
5. **`NavigationStack` inside the sheet** is there for the title and the toolbar. A sheet is a new presentation with no bar of its own; this is the one place where a stack inside presented content is right (lesson 2's "don't nest" was about pushed views).
6. **`.presentationDetents([.medium, .large])`** goes on the sheet's content, not on the presenting view. More below.

`onDismiss:` takes a closure that runs when the sheet goes away, whichever way it was closed. Apple adds that "in vertically compact environments, such as iPhone in landscape orientation, a sheet presentation automatically adapts to appear as a full-screen cover."

## Sheets from an item

When the sheet shows *something* (the recipe you tapped, the photo to share), drive it from an optional value instead. `sheet(item:onDismiss:content:)` requires the item to be `Identifiable`, and the content closure receives it unwrapped:

```swift ios
import SwiftUI

struct Recipe: Identifiable, Hashable {
    let id: Int
    var title: String
}

struct RecipesView: View {
    @State private var recipes = [Recipe(id: 1, title: "Flan"), Recipe(id: 2, title: "Gazpacho")]
    @State private var editing: Recipe?

    var body: some View {
        List(recipes) { recipe in
            Button(recipe.title) {
                editing = recipe
            }
        }
        .sheet(item: $editing) { recipe in
            Text("Editing \(recipe.title)")
                .presentationDragIndicator(.visible)
        }
    }
}
```

Apple's description of the binding: "When `item` is non-`nil`, the system passes the item's content to the modifier's closure." There's no window where the sheet is up but the data is missing, which is the bug you get with `isPresented` plus a separate `selectedRecipe` variable set in the wrong order. And: "If `item` changes, the system dismisses the sheet and replaces it with a new one using the same process."

Forget the `Identifiable` conformance and the call doesn't compile. The same requirement, on a plain function:

```swift no-compile requires that 'Draft' conform to 'Identifiable'
func sheet<Item: Identifiable>(item: Item?) {}

struct Draft {
    var title: String
}

sheet(item: Draft(title: "Soup"))
```

Swift 6.3 says "global function 'sheet(item:)' requires that 'Draft' conform to 'Identifiable'"; on the SwiftUI modifier, the message names the modifier instead.

### One optional enum for every sheet

A screen that can show several sheets tends to grow one `Bool` per sheet. Two `Bool`s have four combinations, and "both true" is a state you can write but the screen can't show, and Apple's pages don't say what happens then. An optional enum has exactly the states you mean:

```swift
enum Sheet: Identifiable {
    case newRecipe
    case edit(recipeID: Int)
    case share(recipeID: Int)

    var id: String {
        switch self {
        case .newRecipe: "new"
        case .edit(let recipeID): "edit-\(recipeID)"
        case .share(let recipeID): "share-\(recipeID)"
        }
    }
}

// Two Bools: every combination you can store.
for showsNew in [false, true] {
    for showsShare in [false, true] {
        let note = showsNew && showsShare ? "  <- two sheets at once?" : ""
        print("new: \(showsNew), share: \(showsShare)\(note)")
    }
}

// One optional enum: every value you can store is a screen you can draw.
let states: [Sheet?] = [nil, .newRecipe, .edit(recipeID: 7), .share(recipeID: 7)]
print(states.map { $0?.id ?? "none" })
```

```output
new: false, share: false
new: false, share: true
new: true, share: false
new: true, share: true  <- two sheets at once?
["none", "new", "edit-7", "share-7"]
```

The `id` has to be different for different sheets, and different for the same kind of sheet about different data: `edit-7` and `edit-8` are two presentations. That's what lets SwiftUI tell "a new item" from "the same item."

What happens when the screen moves from one sheet to another follows Apple's sentence about item changes. Here's that as a model that logs what the user would see:

```swift
enum Sheet: Identifiable {
    case newRecipe
    case edit(recipeID: Int)

    var id: String {
        switch self {
        case .newRecipe: "new"
        case .edit(let recipeID): "edit-\(recipeID)"
        }
    }
}

struct SheetPresenter {
    private(set) var current: Sheet?

    /// What SwiftUI does when the item binding is set to `newValue`.
    mutating func set(_ newValue: Sheet?) {
        guard newValue?.id != current?.id else {
            print("same item: nothing changes")
            return
        }
        if let current { print("dismiss \(current.id)") }
        if let newValue { print("present \(newValue.id)") }
        current = newValue
    }
}

var presenter = SheetPresenter()
presenter.set(.newRecipe)
presenter.set(.edit(recipeID: 7))
presenter.set(.edit(recipeID: 7))
presenter.set(nil)
```

```output
present new
dismiss new
present edit-7
same item: nothing changes
dismiss edit-7
```

> [!warning] A model
> Apple's page says "if `item` changes"; the model takes that to mean the item's identity, since identity is what `Identifiable` provides. Timing (the dismissal animation finishing before the next sheet appears) isn't modeled.

In SwiftUI the enum drives one modifier:

```swift ios
import SwiftUI

enum RecipeSheet: Identifiable {
    case newRecipe
    case edit(recipeID: Int)

    var id: String {
        switch self {
        case .newRecipe: "new"
        case .edit(let recipeID): "edit-\(recipeID)"
        }
    }
}

struct RecipeHome: View {
    @State private var sheet: RecipeSheet?

    var body: some View {
        VStack(spacing: 12) {
            Button("New recipe") { sheet = .newRecipe }
            Button("Edit recipe 7") { sheet = .edit(recipeID: 7) }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .newRecipe:
                Text("New recipe")
            case .edit(let recipeID):
                Text("Editing recipe \(recipeID)")
            }
        }
    }
}
```

## Full-screen covers

`fullScreenCover(isPresented:onDismiss:content:)` and `fullScreenCover(item:onDismiss:content:)` (iOS 14) present "a modal view that covers as much of the screen as possible." Same bindings, same `dismiss`. Use it for a flow the user should finish or explicitly leave (a camera, an onboarding sequence, a video player), and always give it a visible way out, because there's no card edge to drag.

## Sizing sheets with detents

`presentationDetents(_:)` (iOS 16) sets "the available detents for the enclosing sheet." Apple: "By default, sheets support the `large` detent," and "If you provide more than one detent, people can drag the sheet to resize it."

| Detent | Height |
| --- | --- |
| `.large` | Full height |
| `.medium` | "approximately half the height of the screen, and is inactive in compact height" |
| `.fraction(0.3)` | A fraction of the full height |
| `.height(240)` | A fixed height in points |

Related modifiers, all applied inside the sheet's content:

- `presentationDetents(_:selection:)` (iOS 16) adds a binding to the current detent, so code can expand the sheet.
- `presentationDragIndicator(.visible)` (iOS 16) shows the grabber.
- `interactiveDismissDisabled(_:)` (iOS 15) stops the swipe-down. Apple's example is a license the user must accept: `.interactiveDismissDisabled(!areTermsAccepted)`. It "has no effect on programmatic dismissal."
- `presentationBackgroundInteraction(_:)`, `presentationBackground(_:)` and `presentationCornerRadius(_:)` are iOS 16.4.

Compare Module 25, where `UISheetPresentationController.detents` did the same job on the UIKit side.

## Dismissing from inside

`@Environment(\.dismiss)` (iOS 15) returns a `DismissAction` you call like a function: `dismiss()`. Apple lists what it does: "Dismiss a modal presentation, like a sheet or a popover," and "Pop the current view from a `NavigationStack`." Which one depends on where it's read.

That last sentence is the trap. Apple's page shows it:

```swift ios
import SwiftUI

struct BrokenDetail: View {
    @State private var isSheetPresented = false
    @Environment(\.dismiss) private var dismiss   // the detail view's environment

    var body: some View {
        Button("Show Sheet") {
            isSheetPresented = true
        }
        .sheet(isPresented: $isSheetPresented) {
            Button("Done") {
                dismiss()   // doesn't dismiss the sheet
            }
        }
    }
}
```

"The sheet fails to dismiss because the action applies to the environment where you declared it, which is that of the detail view, rather than the sheet." If that detail view was pushed, the call pops *it*. The fix is to read `dismiss` in a view that's inside the sheet, as `AddItemView` does, or to set the presenting state to `false` from the closure (`isSheetPresented = false`). Apple also notes that "the dismiss action has no effect on a view that isn't currently presented"; `@Environment(\.isPresented)` tells you whether it is.

## Alerts

An alert interrupts with something the user must know or decide. The iOS 15 form takes a title, a `Bool` binding, a builder of buttons and a builder for the message:

```swift ios
import SwiftUI

struct SaveButton: View {
    @State private var saveFailed = false

    var body: some View {
        Button("Save") {
            saveFailed = true   // pretend the save failed
        }
        .alert("Couldn't save the recipe", isPresented: $saveFailed) {
            Button("Retry") {
                // try again
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }
}
```

The rules from Apple's `alert` pages:

- "All actions in an alert dismiss the alert after the action runs." You don't set the binding back to `false`; tapping any button does.
- "If no actions are present, the system includes a standard 'OK' action. No default cancel action is provided. If you want to show a cancel action, use a button with a role of `cancel`."
- "The system may reorder the buttons based on their role and prominence."
- On iOS, "alerts only support controls with labels that are `Text`," and "only unstyled text is supported for the message."

When the alert is *about* something, pass it with `presenting:`. Apple: "For the alert to appear, both `isPresented` must be `true` and `data` must not be `nil`. The data should not change after the presentation occurs."

## Confirmation dialogs

A confirmation dialog is the SwiftUI form of an action sheet: a set of choices about something the user just started, typically with a destructive option. It's what you show for "Delete this recipe?":

```swift ios
import SwiftUI

struct Recipe: Identifiable, Hashable {
    let id: Int
    var title: String
}

struct RecipeRows: View {
    @State private var recipes = [Recipe(id: 1, title: "Flan"), Recipe(id: 2, title: "Gazpacho")]
    @State private var pendingDeletion: Recipe?
    @State private var isConfirmingDeletion = false

    var body: some View {
        List(recipes) { recipe in
            Text(recipe.title)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        pendingDeletion = recipe
                        isConfirmingDeletion = true
                    }
                }
        }
        .confirmationDialog(
            "Delete this recipe?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { recipe in
            Button("Delete \(recipe.title)", role: .destructive) {
                recipes.removeAll { $0.id == recipe.id }
            }
        } message: { recipe in
            Text("\(recipe.title) will be removed from all your devices.")
        }
    }
}
```

- **Two pieces of state**, as in Apple's own `alert(_:isPresented:presenting:…)` example: the `Bool` for "is it up" and the optional for "about what." The buttons and message receive the unwrapped recipe.
- **`titleVisibility: .visible`** shows the title, which the default `.automatic` may hide.
- **`role: .destructive`** marks the button that "deletes user data, or performs an irreversible operation"; the system shows it in red.
- **No Cancel button.** "Dialogs include a standard dismiss action by default. If you provide a button with a role of `cancel`, that button takes the place of the default dismiss action." And "in regular size classes in iOS, the system renders confirmation dialogs as a popover that the user dismisses by tapping anywhere outside the popover."

> [!version] New button roles
> Apple's `ButtonRole` page lists `.close` and `.confirm`, introduced in iOS 26. With this course's iOS 17 target they'd need `if #available(iOS 26, *)`; `.cancel` and `.destructive` (iOS 15) cover alerts and dialogs everywhere.

| You want | Use |
| --- | --- |
| A screen with its own content, short task | `sheet` (with detents if it's small) |
| An immersive flow the user finishes or leaves | `fullScreenCover` |
| A message or a yes/no about something that happened | `alert` |
| Several choices about an action the user started | `confirmationDialog` |

## Common mistakes

> [!error] Reading dismiss in the presenting view
> It's the presenting view's dismiss: the sheet stays up, and if that view was pushed, it pops. Read `dismiss` inside the presented content, or set the presenting state to `false`.

> [!error] isPresented plus a separate selected item
> Setting `showsEditor = true` and `selectedRecipe = recipe` in two steps leaves room for the sheet to build with the old or `nil` selection. Use `sheet(item:)` and let the item be the presentation state.

> [!error] A Bool per sheet
> Three `Bool`s are eight combinations for four real states. One optional enum conforming to `Identifiable`, one `.sheet(item:)`.

> [!error] An alert with only a destructive button
> Alerts don't add a cancel action. With a single "Delete" button the user can't back out. Add `Button("Cancel", role: .cancel) {}`, or use a confirmation dialog, which has a dismiss action by default.

> [!error] presentationDetents on the presenting view
> It configures "the enclosing sheet," so it belongs inside the sheet's content, as in `AddItemView`. On the presenting view it would configure whatever sheet *that* view is in, if any, not the one it presents.

## Exercises

````exercise
id: m35-l03-e1
type: prediction
prompt: "The sheet presenter model from the lesson, with a share sheet added. What does it print?"
code: |
  enum Sheet: Identifiable {
      case newRecipe
      case edit(recipeID: Int)
      case share(recipeID: Int)

      var id: String {
          switch self {
          case .newRecipe: "new"
          case .edit(let recipeID): "edit-\(recipeID)"
          case .share(let recipeID): "share-\(recipeID)"
          }
      }
  }

  struct SheetPresenter {
      private(set) var current: Sheet?

      mutating func set(_ newValue: Sheet?) {
          guard newValue?.id != current?.id else {
              print("same item: nothing changes")
              return
          }
          if let current { print("dismiss \(current.id)") }
          if let newValue { print("present \(newValue.id)") }
          current = newValue
      }
  }

  var presenter = SheetPresenter()
  presenter.set(.edit(recipeID: 3))
  presenter.set(.edit(recipeID: 4))
  presenter.set(.share(recipeID: 4))
  presenter.set(nil)
  presenter.set(nil)
output: |
  present edit-3
  dismiss edit-3
  present edit-4
  dismiss edit-4
  present share-4
  dismiss share-4
  same item: nothing changes
hints:
  - "edit-3 and edit-4 are different ids."
  - "nil compared with nil: the optional ids are equal."
solution: |
  ```output
  present edit-3
  dismiss edit-3
  present edit-4
  dismiss edit-4
  present share-4
  dismiss share-4
  same item: nothing changes
  ```

  Each change of identity dismisses the current sheet and presents the new one, which is Apple's "If `item` changes, the system dismisses the sheet and replaces it with a new one." Editing recipe 4 and sharing recipe 4 are different presentations because their ids differ. Setting `nil` twice: the first dismisses, the second finds `nil == nil` and does nothing.
````

````exercise
id: m35-l03-e2
type: prediction
prompt: "Apple's rule for alerts with data: both isPresented must be true and data must not be nil. Apply it to these four states. What does this print?"
code: |
  struct Recipe {
      let title: String
  }

  func alertTitle(isPresented: Bool, data: Recipe?) -> String {
      guard isPresented, let recipe = data else { return "no alert" }
      return "Delete \(recipe.title)?"
  }

  let flan = Recipe(title: "Flan")
  print(alertTitle(isPresented: true, data: flan))
  print(alertTitle(isPresented: true, data: nil))
  print(alertTitle(isPresented: false, data: flan))
  print(alertTitle(isPresented: false, data: nil))
output: |
  Delete Flan?
  no alert
  no alert
  no alert
hints:
  - "guard with two conditions needs both to hold."
solution: |
  ```output
  Delete Flan?
  no alert
  no alert
  no alert
  ```

  Only the first state shows the alert. The second is the classic bug: the flag was set but the data wasn't, so nothing appears and the user's tap seems to do nothing. That's why the lesson sets `pendingDeletion` before `isConfirmingDeletion`, in the same action, and why Apple adds that the data "should not change after the presentation occurs."
````

````exercise
id: m35-l03-e3
type: comprehension
prompt: "A sheet shows ComposeView. Where should @Environment(\\.dismiss) be read so that its Send button closes the sheet?"
choices:
  - text: "In ComposeView, the view that's inside the sheet."
    correct: true
    why: "The action applies to the environment where it's declared; inside the sheet, that's the sheet's presentation."
  - text: "In the view that has the .sheet modifier, then passed down as a closure."
    correct: false
    why: "That captures the presenting view's dismiss, which Apple shows failing to dismiss the sheet (and popping the presenter if it was pushed)."
  - text: "Anywhere; there's one dismiss action per app."
    correct: false
    why: "It's an environment value, so each part of the hierarchy has its own."
  - text: "Nowhere: sheets can only be dismissed by dragging."
    correct: false
    why: "Programmatic dismissal works through dismiss() or by setting the binding to false."
solution: |
  **Inside `ComposeView`.** Apple's `dismiss` page: "the action applies to the environment where you declared it." The presenting view could instead pass a closure that sets its own state (`isComposing = false`), which also works because it changes the binding the sheet reads. What doesn't work is capturing the presenting view's `dismiss`.
````

````exercise
id: m35-l03-e4
type: fill-in
prompt: "Complete the screen: tapping a photo opens a sheet for that photo that can rest at half height or full height, and the sheet's Delete button is marked destructive."
code: |
  struct Gallery: View {
      let photos: [Photo]
      @State private var selected: Photo?

      var body: some View {
          List(photos) { photo in
              Button(photo.name) { selected = photo }
          }
          .sheet([[1]]: $selected) { photo in
              VStack {
                  Text(photo.name)
                  Button("Delete", role: .[[2]]) {}
              }
              .[[3]]([.medium, .large])
          }
      }
  }
blanks:
  - id: "1"
    answers: ["item"]
  - id: "2"
    answers: ["destructive"]
  - id: "3"
    answers: ["presentationDetents"]
hints:
  - "The sheet is driven by an optional Identifiable value."
  - "The modifier configures the enclosing sheet, so it's inside the content."
solution: |
  ```swift ios
  import SwiftUI

  struct Photo: Identifiable {
      let id: Int
      let name: String
  }

  struct Gallery: View {
      let photos: [Photo]
      @State private var selected: Photo?

      var body: some View {
          List(photos) { photo in
              Button(photo.name) { selected = photo }
          }
          .sheet(item: $selected) { photo in
              VStack {
                  Text(photo.name)
                  Button("Delete", role: .destructive) {}
              }
              .presentationDetents([.medium, .large])
          }
      }
  }
  ```

  `sheet(item:)` hands the closure the unwrapped photo. `.destructive` marks the irreversible action. `presentationDetents` is applied to the sheet's content, so it configures that sheet; with two detents, people can drag between half and full height.
````

````exercise
id: m35-l03-e5
type: find-errors
prompt: "This list lets people archive or delete a note. Which of these are real problems?"
code: |
  struct NotesList: View {
      @State private var notes: [Note] = []
      @State private var showsEditor = false
      @State private var showsArchive = false
      @State private var selectedNote: Note?
      @State private var confirmsDelete = false
      @Environment(\.dismiss) private var dismiss

      var body: some View {
          List(notes) { note in
              Button(note.title) {
                  showsEditor = true
                  selectedNote = note
              }
          }
          .sheet(isPresented: $showsEditor) {
              NoteEditor(note: selectedNote ?? Note(title: ""))
          }
          .sheet(isPresented: $showsArchive) {
              ArchiveView(onDone: { dismiss() })
          }
          .alert("Delete note?", isPresented: $confirmsDelete) {
              Button("Delete", role: .destructive) {}
          }
      }
  }
choices:
  - text: "Two Bool flags for two sheets allow a state where both are true."
    correct: true
    why: "One optional enum with editor and archive cases makes that state impossible."
  - text: "The editor sheet reads selectedNote separately from showsEditor, so it can build with a missing or stale note (note the ?? fallback)."
    correct: true
    why: "sheet(item: $selectedNote) passes the unwrapped note and can't present without one."
  - text: "ArchiveView's onDone calls the list's dismiss, which doesn't dismiss the sheet."
    correct: true
    why: "That dismiss belongs to NotesList's environment. Read it inside ArchiveView, or set showsArchive = false."
  - text: "The alert has no cancel action, so the user can't back out."
    correct: true
    why: "Alerts don't add one. Add Button(\"Cancel\", role: .cancel) {}."
  - text: "A view can't have both .sheet and .alert modifiers."
    correct: false
    why: "It can; they're independent presentation modifiers."
rubric:
  - Flags the two Bools.
  - Flags the separate selection with the fallback.
  - Flags the dismiss read in the presenting view.
  - Flags the missing cancel action.
  - Doesn't flag combining sheet and alert.
solution: |
  ```swift ios
  import SwiftUI

  struct Note: Identifiable {
      let id = UUID()
      var title: String
  }

  enum NotesSheet: Identifiable {
      case editor(Note)
      case archive

      var id: String {
          switch self {
          case .editor(let note): "editor-\(note.id)"
          case .archive: "archive"
          }
      }
  }

  struct NoteEditor: View {
      let note: Note
      var body: some View { Text(note.title) }
  }

  struct ArchiveView: View {
      @Environment(\.dismiss) private var dismiss
      var body: some View {
          Button("Done") { dismiss() }
      }
  }

  struct NotesList: View {
      @State private var notes: [Note] = []
      @State private var sheet: NotesSheet?
      @State private var confirmsDelete = false

      var body: some View {
          List(notes) { note in
              Button(note.title) { sheet = .editor(note) }
          }
          .sheet(item: $sheet) { sheet in
              switch sheet {
              case .editor(let note): NoteEditor(note: note)
              case .archive: ArchiveView()
              }
          }
          .alert("Delete note?", isPresented: $confirmsDelete) {
              Button("Delete", role: .destructive) {}
              Button("Cancel", role: .cancel) {}
          }
      }
  }
  ```

  One enum covers both sheets and carries the note with the editor case, so there's no separate selection to forget. `ArchiveView` reads its own `dismiss`. The alert gets a cancel button. (A real delete would also need to know which note; that's the `presenting:` form from the lesson.)
````

````exercise
id: m35-l03-e6
type: solve
prompt: |
  Write the presentation state for a recipe screen in plain Swift, as one optional enum.

  - `enum RecipeSheet: Identifiable` with cases `newRecipe`, `edit(recipeID: Int)` and `photo(recipeID: Int, index: Int)`. Its `id` must differ whenever the sheet's content would differ.
  - `struct RecipeScreen` with `var sheet: RecipeSheet?` and a method `func title() -> String` that returns `"none"`, `"New Recipe"`, `"Edit #<id>"` or `"Photo <index + 1> of #<id>"`.

  Then print `title()` and the `id` (or `"-"` when there's no sheet) for: no sheet, newRecipe, edit 12, photo of recipe 12 at index 0, and photo of recipe 12 at index 2, and finally print whether the last two ids are equal.
starter: |
  enum RecipeSheet: Identifiable {
      case newRecipe
      case edit(recipeID: Int)
      case photo(recipeID: Int, index: Int)

      var id: String {
          // your code
          ""
      }
  }

  struct RecipeScreen {
      var sheet: RecipeSheet?

      func title() -> String {
          // your code
          ""
      }
  }
hints:
  - "Put every associated value into the id: photo-12-0 and photo-12-2."
  - "switch sheet { case nil: … case .newRecipe?: … } works on an optional enum."
rubric:
  - Ids include every associated value, so different content means different ids.
  - title() handles nil and every case.
  - Prints six lines matching the expected output.
solution: |
  ```swift
  enum RecipeSheet: Identifiable {
      case newRecipe
      case edit(recipeID: Int)
      case photo(recipeID: Int, index: Int)

      var id: String {
          switch self {
          case .newRecipe: "new"
          case .edit(let recipeID): "edit-\(recipeID)"
          case .photo(let recipeID, let index): "photo-\(recipeID)-\(index)"
          }
      }
  }

  struct RecipeScreen {
      var sheet: RecipeSheet?

      func title() -> String {
          switch sheet {
          case nil: "none"
          case .newRecipe?: "New Recipe"
          case .edit(let recipeID)?: "Edit #\(recipeID)"
          case .photo(let recipeID, let index)?: "Photo \(index + 1) of #\(recipeID)"
          }
      }
  }

  let sheets: [RecipeSheet?] = [nil, .newRecipe, .edit(recipeID: 12),
                                .photo(recipeID: 12, index: 0), .photo(recipeID: 12, index: 2)]
  for sheet in sheets {
      let screen = RecipeScreen(sheet: sheet)
      print(screen.title(), "|", sheet?.id ?? "-")
  }
  print(sheets[3]?.id == sheets[4]?.id)
  ```

  ```output
  none | -
  New Recipe | new
  Edit #12 | edit-12
  Photo 1 of #12 | photo-12-0
  Photo 3 of #12 | photo-12-2
  false
  ```

  Every associated value is part of the id, so moving from photo 1 to photo 3 is a new presentation and SwiftUI replaces the sheet. If the id were just `"photo-12"`, Apple's rule would see no change and the sheet would keep showing the first photo. The `?` patterns (`.newRecipe?`) match the enum inside the optional, so one `switch` covers "no sheet" and each sheet.
````

## Summary

- Presentation is state: `sheet(isPresented:)` for a sheet with no data, `sheet(item:)` with an `Identifiable` item for a sheet about something. When the user dismisses, SwiftUI writes back `false` or `nil`.
- With `item`, the content receives the unwrapped value, and a change of item dismisses and replaces the sheet. Model all of a screen's sheets as one optional enum whose `id` includes every associated value.
- `fullScreenCover` has the same two forms and covers the screen; always give it a way out.
- `presentationDetents` (iOS 16) goes inside the sheet's content: `.medium`, `.large`, `.fraction`, `.height`. `interactiveDismissDisabled` stops the swipe, not programmatic dismissal.
- Read `@Environment(\.dismiss)` inside the presented view. Read in the presenter, it fails to dismiss the sheet.
- Alerts dismiss after any action, add OK when you give no actions, and never add a cancel for you. Confirmation dialogs have a dismiss action by default and become popovers in regular width. Use `presenting:` to pass the item, and roles `.destructive` and `.cancel`.
