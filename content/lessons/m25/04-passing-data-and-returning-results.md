---
id: m25-l04
title: Passing data and returning results
description: How screens hand data to each other without knowing too much. You pass what a screen needs through its initializer, send a result back with a closure or a delegate, choose between the two, keep the back-references weak so nothing leaks, and see why NotificationCenter is the wrong tool for a screen's answer.
module: m25
order: 4
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m25-l03]
objectives:
  - Pass a screen's data through its initializer and explain why that beats setting a property after creating it.
  - Return a result from a pushed or presented screen with a closure property.
  - Return results with a delegate protocol, and choose between a closure and a delegate for a given screen.
  - Capture self weakly in result closures and explain which ownership chain would otherwise leak.
  - Explain why NotificationCenter is a poor fit for returning a result to the screen that asked.
terms:
  - term: Initializer injection
    definition: "Passing a screen's dependencies and data as initializer parameters and storing them in let properties, so the screen can't exist without them."
  - term: Result closure
    definition: "A closure property such as onSave: ((Note) -> Void)? that the screen calls when it finishes. The screen that created it sets the closure."
  - term: Delegate (for results)
    definition: "A weak reference to an object conforming to a protocol you define, such as NoteEditorDelegate, that the screen calls with its result and other events."
  - term: Retain cycle
    definition: "Two or more objects holding strong references to each other, so ARC never releases them (Module 13). A closure stored in a screen that captures its owner strongly is the usual source in navigation code."
  - term: NotificationCenter
    definition: "Foundation's broadcast mechanism: any object posts a named notification, every registered observer receives it. One-to-many and untyped; Module 26 covers when it fits."
mastery:
  - Write a detail controller that takes its model in init and has no optional or implicitly unwrapped data properties.
  - Write an editor with onSave and onCancel closures, and the presenting code that sets them with [weak self] and dismisses.
  - Write the same editor with a @MainActor delegate protocol and a weak delegate property.
  - Show with a plain-Swift model that a strong capture keeps a screen alive and a weak one doesn't.
  - Explain two ways a notification-based result can fail silently.
resources: [swift-book-closures, swift-book-arc, swift-book-protocols, uikit-uiviewcontroller]
cards:
  - id: m25-l04-c1
    front: Why pass a detail screen's model in init instead of setting a var after creating it?
    back: "The screen can't exist without its data: the property is a let, not an optional or an implicitly unwrapped optional, and the compiler rejects any call site that forgets it. Nothing can change it later behind the screen's back."
  - id: m25-l04-c2
    front: Closure or delegate for returning a result?
    back: "A closure for one or two outcomes (onSave, onCancel), set where the screen is created. A delegate when there are several related events or the receiver is a long-lived object that handles many screens. Both need weak back-references."
  - id: m25-l04-c3
    front: "editor.onSave = { self.reload() }: what's the risk?"
    back: "The closure owns self. If self also owns the editor (a property, a coordinator's reference, a presentation that's still active), neither is released. Write { [weak self] in self?.reload() }."
  - id: m25-l04-c4
    front: Why is a delegate property weak, and what does the protocol need for that?
    back: "The delegate usually owns the screen; a strong reference back would form a cycle. weak requires a class type, so the protocol inherits AnyObject. For UIKit screens it's also @MainActor."
  - id: m25-l04-c5
    front: Why not post a notification to return an editor's result?
    back: "It's a broadcast with no compile-time link: a misspelled name or userInfo key fails silently, any number of observers (including none) may react, and the code that asked can't see who answers. Use a closure or delegate for a one-to-one answer."
---

## The idea in one sentence

Data goes **forward** when you create the next screen, through its initializer, and the answer comes **back** through a closure or a delegate that the creator gave it, held weakly so the two screens never keep each other alive.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The plain-Swift models, including the NotificationCenter example, were compiled and run. Nothing was checked in Xcode or the simulator.

## Forward: the initializer

You've done this since lesson 1: the detail screen gets its note in `init`.

```swift ios
import UIKit

struct Recipe {
    let id: Int
    var name: String
    var minutes: Int
}

final class RecipeDetailViewController: UIViewController {
    private let recipe: Recipe

    init(recipe: Recipe) {
        self.recipe = recipe
        super.init(nibName: nil, bundle: nil)
        title = recipe.name
    }

    required init?(coder: NSCoder) {
        fatalError("RecipeDetailViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        print("\(recipe.name) takes \(recipe.minutes) minutes")
    }
}
```

The other common style creates the controller first and fills a property afterwards:

```swift ios
import UIKit

struct Recipe {
    let id: Int
    var name: String
}

final class LooseRecipeDetailViewController: UIViewController {
    var recipe: Recipe!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = recipe.name
    }
}

@MainActor
func showLoose(_ recipe: Recipe, on navigationController: UINavigationController) {
    let detail = LooseRecipeDetailViewController()
    detail.recipe = recipe
    navigationController.pushViewController(detail, animated: true)
}
```

It compiles, and it's worse in three ways:

1. **Forgetting is a crash, not a compile error.** Remove `detail.recipe = recipe` and the app traps in `viewDidLoad()` when it unwraps `nil`. With `init(recipe:)`, the call site doesn't compile.
2. **Order matters invisibly.** Setting the property after the view has loaded leaves the screen showing old data unless you also write a `didSet`.
3. **Anyone can change it later.** A `var` with internal access is part of the screen's interface.

The `Recipe!` style survives mostly in storyboard projects, where UIKit creates controllers through `init?(coder:)` and you can't add parameters. Module 22 showed the fix for that case: `instantiateViewController(identifier:creator:)` lets you call your own initializer.

### What to pass

- **A value** (a `struct` like `Recipe`) when the screen shows or edits a snapshot. The screen works on its own copy; nothing changes in the list until the screen reports back. Cancelling is free.
- **A reference to a shared object** (a `final class RecipeStore`, or better a protocol it conforms to) when the screen must read or write shared state while it's open. Pass the narrowest protocol that does the job, the interface segregation idea from Module 14.
- **Not** the previous view controller. A detail screen that holds a `RecipeListViewController` to call its methods is tied to that one list forever.

## Back: a result closure

An editor needs to say "saved, here's the result" or "cancelled". The simplest channel is a closure property that the creator sets:

```swift ios
import UIKit

struct Recipe {
    let id: Int
    var name: String
}

final class EditRecipeViewController: UIViewController {
    var onSave: ((Recipe) -> Void)?
    var onCancel: (() -> Void)?
    private var recipe: Recipe
    private let nameField = UITextField()

    init(recipe: Recipe) {
        self.recipe = recipe
        super.init(nibName: nil, bundle: nil)
        title = "Edit Recipe"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.onCancel?()
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [weak self] _ in
            self?.save()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("EditRecipeViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        nameField.text = recipe.name
        view.addSubview(nameField)
    }

    private func save() {
        recipe.name = nameField.text ?? recipe.name
        onSave?(recipe)
    }
}

final class RecipeListViewController: UIViewController {
    private var recipes = [Recipe(id: 1, name: "Pancakes")]

    func edit(_ recipe: Recipe) {
        let editor = EditRecipeViewController(recipe: recipe)
        editor.onSave = { [weak self] updated in
            self?.replace(updated)
            self?.dismiss(animated: true)
        }
        editor.onCancel = { [weak self] in
            self?.dismiss(animated: true)
        }
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    private func replace(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        }
        print("now: \(recipes.map { $0.name })")
    }
}
```

How the pieces fit:

- The editor **doesn't dismiss itself** and doesn't know it was presented. It reports. The list decided to present it, so the list dismisses it (lesson 3's rule).
- The closures are optional and default to `nil`, so an editor with no listener does nothing on Save instead of crashing. That's convenient and also a trap: nothing reminds you to set them. When a result is required, take it in `init` instead: `init(recipe: Recipe, onSave: @escaping (Recipe) -> Void)`.
- `[weak self]` everywhere: in the editor's own `UIAction`s (Module 22) and in the closures the list hands the editor. The next section shows why.
- The editor edits **its own copy** of the struct. Until `onSave` runs, the list's array hasn't changed, so Cancel needs no undo.

The same works for a pushed screen. A color picker pushed in a settings stack calls `onPick(color)`, and the settings screen updates and pops: `navigationController?.popViewController(animated: true)`. Again the receiver closes it, because it knows the picker was pushed.

### The same flow without UIKit

The flow is plain Swift. Here `editor` stands for "the editor is on screen" and `close()` for dismissing it:

```swift
struct Contact {
    let id: Int
    var name: String
}

final class ContactEditor {
    private var contact: Contact
    var onSave: ((Contact) -> Void)?
    var onCancel: (() -> Void)?

    init(contact: Contact) {
        self.contact = contact
    }

    func userTyped(_ name: String) {
        contact.name = name
    }

    func userTappedSave() {
        onSave?(contact)
    }

    func userTappedCancel() {
        onCancel?()
    }
}

final class ContactList {
    private(set) var contacts = [Contact(id: 1, name: "Ana"), Contact(id: 2, name: "Ben")]
    private(set) var editor: ContactEditor?

    func edit(id: Int) {
        guard let contact = contacts.first(where: { $0.id == id }) else { return }
        let editor = ContactEditor(contact: contact)
        editor.onSave = { [weak self] updated in
            self?.save(updated)
        }
        editor.onCancel = { [weak self] in
            self?.close()
        }
        self.editor = editor
    }

    private func save(_ contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        }
        close()
    }

    private func close() {
        editor = nil
        print("list:", contacts.map { $0.name })
    }
}

let list = ContactList()
list.edit(id: 2)
list.editor?.userTyped("Benjamin")
print("before save:", list.contacts.map { $0.name })
list.editor?.userTappedSave()
list.edit(id: 1)
list.editor?.userTyped("Anna")
list.editor?.userTappedCancel()
```

```output
before save: ["Ana", "Ben"]
list: ["Ana", "Benjamin"]
list: ["Ana", "Benjamin"]
```

Typing "Benjamin" changes only the editor's copy; the list still says "Ben" until Save. Cancelling the second edit leaves "Ana" untouched without any undo code.

## Why [weak self]

In the model, `ContactList` owns its editor (`self.editor = editor`), and the editor owns its closures. A closure written as `{ updated in self.save(updated) }` would own the list. That's a cycle: list → editor → closure → list. Here's what each version does:

```swift
final class Editor {
    var onSave: (() -> Void)?

    deinit {
        print("  editor released")
    }
}

final class ListScreen {
    let name: String
    var editor: Editor?

    init(name: String) {
        self.name = name
    }

    deinit {
        print("  \(name) released")
    }

    func openEditor(captureWeakly: Bool) {
        let editor = Editor()
        if captureWeakly {
            editor.onSave = { [weak self] in
                self?.reload()
            }
        } else {
            editor.onSave = {
                self.reload()
            }
        }
        self.editor = editor
    }

    func reload() {
        print("  \(name) reloads")
    }
}

func visit(_ name: String, captureWeakly: Bool) {
    print("open \(name)")
    let screen = ListScreen(name: name)
    screen.openEditor(captureWeakly: captureWeakly)
    screen.editor?.onSave?()
    print("leave \(name)")
}

visit("weak list", captureWeakly: true)
visit("strong list", captureWeakly: false)
print("done")
```

```output
open weak list
  weak list reloads
leave weak list
  weak list released
  editor released
open strong list
  strong list reloads
leave strong list
done
```

Both versions work while the screen is open. Only the weak one is released afterwards. The strong pair never prints a `deinit` line: in an app, that's a list screen and its editor, with all their views, leaking every time.

In UIKit the ownership is less visible. While the editor is presented, the presentation keeps it alive and the presenter can reach it through `presentedViewController`. Once it's dismissed, UIKit lets go. So a strong capture in the presented-editor example may not leak today. It starts leaking the day someone stores the editor in a property, or moves the presenting into a coordinator that keeps references (lesson 5). `[weak self]` costs one `?` and doesn't depend on who owns what this week. Module 13, lesson 4 covers the capture rules in detail.

## Back: a delegate

The delegate version from Module 22, applied to the editor:

```swift ios
import UIKit

struct Recipe {
    let id: Int
    var name: String
}

@MainActor
protocol EditRecipeViewControllerDelegate: AnyObject {
    func editRecipeViewController(_ controller: EditRecipeViewController, didSave recipe: Recipe)
    func editRecipeViewControllerDidCancel(_ controller: EditRecipeViewController)
}

final class EditRecipeViewController: UIViewController {
    weak var delegate: EditRecipeViewControllerDelegate?
    private let recipe: Recipe

    init(recipe: Recipe) {
        self.recipe = recipe
        super.init(nibName: nil, bundle: nil)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.delegate?.editRecipeViewControllerDidCancel(self)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.delegate?.editRecipeViewController(self, didSave: self.recipe)
        })
    }

    required init?(coder: NSCoder) {
        fatalError("EditRecipeViewController is created in code")
    }
}

final class RecipeListViewController: UIViewController, EditRecipeViewControllerDelegate {
    func edit(_ recipe: Recipe) {
        let editor = EditRecipeViewController(recipe: recipe)
        editor.delegate = self
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    func editRecipeViewController(_ controller: EditRecipeViewController, didSave recipe: Recipe) {
        print("saved \(recipe.name)")
        dismiss(animated: true)
    }

    func editRecipeViewControllerDidCancel(_ controller: EditRecipeViewController) {
        dismiss(animated: true)
    }
}
```

- `AnyObject` so the property can be `weak`; `@MainActor` so a view controller can conform in Swift 6 mode (Module 22, lesson 5).
- The sender is the first parameter, so one list can tell two editors apart.
- `guard let self else { return }` inside the actions turns the weak reference into a strong one for the rest of the closure, so `self` can be passed as an argument.

### Which one?

| | Closure | Delegate |
| --- | --- | --- |
| Best for | One or two outcomes from a screen used in one place | Several related events, or one object answering many screens |
| Set up | Where the screen is created, next to the code that shows it | A conformance somewhere else in the receiver |
| Back-reference | `[weak self]` in each closure | `weak var delegate` once |
| Can forget to wire it? | Yes, if optional; take it in `init` to prevent that | Yes; `delegate` is optional by nature |

Most new code uses closures for a screen's result, because the handling sits next to the `present` call that it belongs to. A delegate wins when the protocol has four or five methods, or when the receiver is a coordinator that handles many screens. Either way the screen knows only a closure type or a protocol, never the concrete screen that created it. That's what makes it reusable and lets lesson 5 move the receiving side into a coordinator.

## Why not NotificationCenter

Posting a "note saved" notification and having the list observe it also "works". It's the wrong tool for an answer to a specific question:

```swift
import Foundation

let noteSaved = Notification.Name("NoteSaved")
let center = NotificationCenter.default

let token = center.addObserver(forName: noteSaved, object: nil, queue: nil) { notification in
    let title = notification.userInfo?["title"] as? String ?? "?"
    print("list heard: \(title)")
}

center.post(name: noteSaved, object: nil, userInfo: ["title": "Groceries"])
center.post(name: Notification.Name("NoteSave"), object: nil, userInfo: ["title": "Typo in the name"])
center.post(name: noteSaved, object: nil, userInfo: ["titel": "Typo in the key"])
center.removeObserver(token)
print("done")
```

```output
list heard: Groceries
list heard: ?
done
```

- **A typo in the name** delivers to nobody. No compiler error, no runtime error.
- **A typo in the key** delivers, and the value is lost: `userInfo` is `[AnyHashable: Any]`, so the type and the key are checked only at run time, by your cast.
- **Nobody is responsible.** Zero, one or five observers may react, in an order you don't control. The editor can't tell whether anyone handled the save, and the reader of the list's code can't see where the event comes from.
- **Lifetime is manual.** The observer has to be removed or tied to the observing object's lifetime.

A closure or delegate is a typed, one-to-one connection the compiler checks. Notifications fit genuinely one-to-many, app-wide events (the keyboard appearing, the app entering the background, "the account changed" for every screen that cares). Module 26 compares all the mechanisms side by side.

## Common mistakes

> [!error] An implicitly unwrapped data property
> `var recipe: Recipe!` set after `init` turns a forgotten line into a crash in `viewDidLoad()`. Take it in `init` and make it `let`.

> [!error] The child dismisses or pops itself
> The child assumes how it was shown. Report the result and let the code that showed it close it.

> [!error] A strong self in a stored closure
> `editor.onSave = { self.reload() }` is a cycle the moment the owner keeps the editor. Write `[weak self]`.

> [!error] Passing the parent view controller to the child
> `EditorViewController(list: self)` so the editor can call `list.reload()`. Now the editor works only for that list. Give it a closure or a delegate protocol.

> [!error] A notification as a return value
> One-to-one results belong in a closure or delegate. Notifications fail silently on a typo and leave the reader guessing who reacts.

## Exercises

````exercise
id: m25-l04-e1
type: prediction
prompt: "What does this print? Pay attention to which `deinit` lines appear."
code: |
  protocol PickerDelegate: AnyObject {
      func picker(didPick value: String)
  }

  final class Picker {
      weak var weakDelegate: PickerDelegate?
      var strongDelegate: PickerDelegate?

      deinit {
          print("picker released")
      }

      func pick(_ value: String) {
          weakDelegate?.picker(didPick: value)
          strongDelegate?.picker(didPick: value)
      }
  }

  final class Form: PickerDelegate {
      let picker = Picker()
      var choice = "none"

      init(strong: Bool) {
          if strong {
              picker.strongDelegate = self
          } else {
              picker.weakDelegate = self
          }
      }

      deinit {
          print("form released with \(choice)")
      }

      func picker(didPick value: String) {
          choice = value
      }
  }

  do {
      let form = Form(strong: false)
      form.picker.pick("Red")
  }
  print("---")
  do {
      let form = Form(strong: true)
      form.picker.pick("Blue")
      print(form.choice)
  }
  print("end")
output: |
  form released with Red
  picker released
  ---
  Blue
  end
hints:
  - "The form owns the picker. Who owns the form in each block?"
  - "A deinit prints when the last strong reference goes away. If it never goes away, nothing prints."
solution: |
  ```output
  form released with Red
  picker released
  ---
  Blue
  end
  ```

  In the first block the picker points back weakly. When `form` goes out of scope, nothing else owns the form: its `deinit` runs, then the picker it owned is released. In the second block the picker owns the form and the form owns the picker. The delegate call still works (`Blue`), but neither `deinit` ever runs. That's why every delegate property in UIKit, and in your own screens, is `weak`.
````

````exercise
id: m25-l04-e2
type: comprehension
prompt: "A settings screen pushes a language picker. When the user picks a language, the settings screen must update its label and the picker must go away. Which design is best?"
choices:
  - text: "The picker has onPick: (String) -> Void, set by the settings screen with [weak self]; the settings screen updates its label and pops the picker."
    correct: true
    why: "One outcome, handled next to the push, by the object that knows the picker was pushed."
  - text: "The picker's init takes the SettingsViewController and calls settings.updateLanguage(_:) and then pops itself."
    correct: false
    why: "The picker becomes tied to one screen, and it assumes it was pushed."
  - text: "The picker posts a LanguageChanged notification; the settings screen observes it and pops the picker."
    correct: false
    why: "A broadcast for a one-to-one answer: silent on typos, untyped, and the reader can't see the connection."
  - text: "The picker writes the language to a global variable, and the settings screen reads it in viewWillAppear(_:)."
    correct: false
    why: "Hidden shared state, and it relies on a lifecycle callback instead of the actual event."
solution: |
  **A closure set by the settings screen.** The picker knows only "I report a `String`." The settings screen, which pushed it, sets `onPick = { [weak self] language in self?.show(language); self?.navigationController?.popViewController(animated: true) }`. A delegate would work as well; for one outcome a closure is less code and sits next to the push.
````

````exercise
id: m25-l04-e3
type: find-errors
prompt: "This editor flow works, but it has design and memory problems. Mark every real one."
code: |
  final class TagEditorViewController: UIViewController {
      var tag: Tag!
      var list: TagListViewController!

      func saveTapped() {
          list.tags.append(tag)
          list.tableView.reloadData()
          dismiss(animated: true)
      }
  }

  // In TagListViewController:
  func addTag() {
      let editor = TagEditorViewController()
      editor.tag = Tag(name: "")
      editor.list = self
      self.currentEditor = editor
      present(editor, animated: true)
  }
choices:
  - text: "tag is an implicitly unwrapped var set after init instead of an init parameter."
    correct: true
  - text: "The editor holds a strong reference to the list while the list keeps currentEditor: a retain cycle."
    correct: true
  - text: "The editor reaches into the list's data and table view, so it only works with that one list."
    correct: true
  - text: "The editor dismisses itself instead of reporting the result to the presenter."
    correct: true
  - text: "present(editor, animated: true) is wrong because only navigation controllers can be presented."
    correct: false
    why: "Any view controller can be presented; wrapping it in a navigation controller is only needed for a bar."
rubric:
  - I found the implicitly unwrapped data.
  - I found the cycle between list and editor.
  - I noticed the editor depends on the list's internals.
  - I noticed the self-dismissal.
solution: |
  ```swift ios
  import UIKit

  struct Tag {
      var name: String
  }

  final class TagEditorViewController: UIViewController {
      private let tag: Tag
      private let onSave: (Tag) -> Void

      init(tag: Tag, onSave: @escaping (Tag) -> Void) {
          self.tag = tag
          self.onSave = onSave
          super.init(nibName: nil, bundle: nil)
      }

      required init?(coder: NSCoder) {
          fatalError("TagEditorViewController is created in code")
      }

      func saveTapped() {
          onSave(tag)
      }
  }

  final class TagListViewController: UIViewController {
      private var tags: [Tag] = []

      func addTag() {
          let editor = TagEditorViewController(tag: Tag(name: "")) { [weak self] tag in
              self?.tags.append(tag)
              self?.dismiss(animated: true)
          }
          present(editor, animated: true)
      }
  }
  ```

  The editor takes its data and its single required result in `init`, knows nothing about the list, and doesn't dismiss itself. The list keeps no extra reference to the editor; the presentation already does. The closure captures the list weakly.
````

````exercise
id: m25-l04-e4
type: solve
prompt: |
  A task editor finishes in one of three ways: saved (a new or changed task), deleted, or cancelled. Model that as an enum, and write `apply(_:to:)`, which returns the updated task list:

  - `.saved` replaces the task with the same `id`, or appends it if there is none.
  - `.deleted(id:)` removes the task with that `id`.
  - `.cancelled` returns the list unchanged.

  ```swift
  var tasks = [Todo(id: 1, title: "Buy milk"), Todo(id: 2, title: "Call Ana")]
  let results: [EditorResult] = [
      .saved(Todo(id: 2, title: "Call Ana at 5")),
      .cancelled,
      .saved(Todo(id: 3, title: "Pay rent")),
      .deleted(id: 1),
  ]
  for result in results {
      tasks = apply(result, to: tasks)
      print(tasks.map { "\($0.id): \($0.title)" })
  }
  ```

  should print:

  ```plaintext
  ["1: Buy milk", "2: Call Ana at 5"]
  ["1: Buy milk", "2: Call Ana at 5"]
  ["1: Buy milk", "2: Call Ana at 5", "3: Pay rent"]
  ["2: Call Ana at 5", "3: Pay rent"]
  ```
starter: |
  struct Todo {
      let id: Int
      var title: String
  }

  enum EditorResult {
      // your cases
  }

  func apply(_ result: EditorResult, to tasks: [Todo]) -> [Todo] {
      // your code
      tasks
  }
hints:
  - "Associated values: case saved(Todo), case deleted(id: Int), case cancelled."
  - "firstIndex(where:) finds the task to replace; filter removes one."
rubric:
  - The enum has exactly three cases with the right associated values.
  - The switch is exhaustive, with no default.
  - Saving an unknown id appends; saving a known id replaces in place.
  - The output matches.
solution: |
  ```swift
  struct Todo {
      let id: Int
      var title: String
  }

  enum EditorResult {
      case saved(Todo)
      case deleted(id: Int)
      case cancelled
  }

  func apply(_ result: EditorResult, to tasks: [Todo]) -> [Todo] {
      switch result {
      case .saved(let task):
          var updated = tasks
          if let index = updated.firstIndex(where: { $0.id == task.id }) {
              updated[index] = task
          } else {
              updated.append(task)
          }
          return updated
      case .deleted(let id):
          return tasks.filter { $0.id != id }
      case .cancelled:
          return tasks
      }
  }

  var tasks = [Todo(id: 1, title: "Buy milk"), Todo(id: 2, title: "Call Ana")]
  let results: [EditorResult] = [
      .saved(Todo(id: 2, title: "Call Ana at 5")),
      .cancelled,
      .saved(Todo(id: 3, title: "Pay rent")),
      .deleted(id: 1),
  ]
  for result in results {
      tasks = apply(result, to: tasks)
      print(tasks.map { "\($0.id): \($0.title)" })
  }
  ```

  ```output
  ["1: Buy milk", "2: Call Ana at 5"]
  ["1: Buy milk", "2: Call Ana at 5"]
  ["1: Buy milk", "2: Call Ana at 5", "3: Pay rent"]
  ["2: Call Ana at 5", "3: Pay rent"]
  ```

  With this enum the editor needs a single closure, `onFinish: (EditorResult) -> Void`, instead of three optional ones, and the compiler makes the receiver handle every outcome: add a fourth case later and every `switch` without a `default` stops compiling until it's handled. The receiving side calls `apply`, then dismisses. `apply` is a pure function, so it can be tested without any screen.
````

````exercise
id: m25-l04-e5
type: refactor
prompt: "Refactor this pushed detail screen so it gets its data through the initializer and reports \"favorite toggled\" back through a closure instead of reaching into the list."
code: |
  final class SongDetailViewController: UIViewController {
      var song: Song?
      weak var list: SongListViewController?

      override func viewDidLoad() {
          super.viewDidLoad()
          title = song?.title ?? "Unknown"
      }

      func favoriteTapped() {
          guard var song else { return }
          song.isFavorite.toggle()
          list?.songs[song.id] = song
          list?.reload()
      }
  }
rubric:
  - The song is a let initializer parameter, not an optional var.
  - The title is set in init.
  - The screen reports through a closure taking the updated song, with no reference to the list type.
  - The list's code sets the closure with [weak self] where it creates the screen.
solution: |
  ```swift ios
  import UIKit

  struct Song {
      let id: Int
      var title: String
      var isFavorite: Bool
  }

  final class SongDetailViewController: UIViewController {
      private var song: Song
      private let onChange: (Song) -> Void

      init(song: Song, onChange: @escaping (Song) -> Void) {
          self.song = song
          self.onChange = onChange
          super.init(nibName: nil, bundle: nil)
          title = song.title
      }

      required init?(coder: NSCoder) {
          fatalError("SongDetailViewController is created in code")
      }

      func favoriteTapped() {
          song.isFavorite.toggle()
          onChange(song)
      }
  }

  final class SongListViewController: UIViewController {
      private var songs: [Int: Song] = [:]

      func show(_ song: Song) {
          let detail = SongDetailViewController(song: song) { [weak self] updated in
              self?.songs[updated.id] = updated
              print("updated \(updated.title)")
          }
          navigationController?.pushViewController(detail, animated: true)
      }
  }
  ```

  The detail keeps its own copy of the song (a `var`, because it toggles it) and reports each change. The list owns its dictionary again; nobody else writes into it. The weak `list` property disappears, and with it the detail's dependency on one particular list class.
````

````exercise
id: m25-l04-e6
type: explain
prompt: "A teammate says: \"Delegates are old-fashioned, closures are always better.\" Using this module, explain when you'd still pick a delegate, and what both approaches need to avoid leaks."
code: |
  @MainActor
  protocol PhotoEditorDelegate: AnyObject {
      func photoEditor(_ editor: PhotoEditorViewController, didApply filter: Filter)
      func photoEditor(_ editor: PhotoEditorViewController, didCrop rect: CropRect)
      func photoEditorDidRequestUndo(_ editor: PhotoEditorViewController)
      func photoEditorDidFinish(_ editor: PhotoEditorViewController)
      func photoEditorDidCancel(_ editor: PhotoEditorViewController)
  }
rubric:
  - Gives a case where a delegate is clearer (many related events, one receiver for many screens).
  - Points out that five optional closures are easy to leave unwired.
  - States that delegates are weak references and closures capture self weakly.
  - Mentions that both keep the screen independent of the concrete receiver.
solution: |
  Closures fit one or two outcomes set next to the code that shows the screen. This editor has five related events. As closures, that's five optional properties, any of which can be forgotten at the call site; as a protocol, a conforming type is told by the compiler about every method it hasn't implemented, and the five events read as one contract. A delegate also fits when one long-lived object (a coordinator) receives events from several screens of the same kind; the sender parameter tells them apart.

  Leaks: the delegate property is `weak` (the protocol is `AnyObject`), and every stored closure captures `[weak self]`. Both approaches keep the editor ignorant of who's listening. That's the part that matters; the syntax is secondary.
````

## Summary

- Pass data forward through the initializer, into `let` properties. A screen that can't exist without its data can't be shown without it.
- Pass values for snapshots the screen edits on its own copy; pass a narrow protocol for shared state; never pass the parent view controller.
- Return results with a closure (`onSave`, `onCancel`, or one `onFinish` with a result enum) for one or two outcomes, or a `@MainActor` delegate protocol with a `weak var delegate` for several events.
- The receiver closes the screen: it dismisses what it presented and pops what it pushed.
- Capture `[weak self]` in every stored closure. The cycle appears as soon as anything keeps the child, whatever UIKit does today.
- NotificationCenter is a broadcast: untyped, silent on typos, unclear ownership. Use it for app-wide events, not for a screen's answer.
