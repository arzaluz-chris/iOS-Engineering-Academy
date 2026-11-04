---
id: m22-l04
title: Building a screen in code
description: You build a complete screen without Interface Builder, an "add expense" form with labels, text fields, a button and a stack view, pinned to the safe area with anchors and wired to logic you can test without UIKit. Along the way you inject dependencies through the initializer, learn why init(coder:) is required, and see how to keep the view controller small.
module: m22
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l03]
objectives:
  - Build a form screen in code with UILabel, UITextField, UIButton and a vertical UIStackView.
  - Pin a stack view to the safe area with anchors and explain why arranged subviews need no constraints of their own.
  - Use Dynamic Type fonts and semantic colors from the start.
  - Pass dependencies through a view controller's initializer and implement the required init(coder:).
  - Keep input parsing and rules in plain Swift that can be tested without UIKit.
  - Show the screen from the scene delegate.
terms:
  - term: Programmatic UI
    definition: "Building views, their properties and their constraints in Swift code instead of a storyboard or XIB."
  - term: UIStackView
    definition: "A view that lays out its arranged subviews in a row or a column, creating the Auto Layout constraints between them for you."
  - term: Arranged subview
    definition: "A view managed by a stack view through addArrangedSubview(_:). The stack view positions and sizes it; you don't constrain it to its siblings."
  - term: Dynamic Type
    definition: "The system text-size setting. Fonts from UIFont.preferredFont(forTextStyle:) follow it, and adjustsFontForContentSizeCategory updates them while the app runs."
  - term: Dependency injection
    definition: "Giving an object what it needs (a store, a service) from outside, usually through its initializer, instead of letting it create or look up those objects itself."
mastery:
  - Write a code-only view controller with four or more controls in a stack view pinned to the safe area.
  - Explain each of the stack view's constraints and why its children need none.
  - Add an initializer that takes a dependency and the init(coder:) that Swift requires with it.
  - Move parsing and validation out of the view controller into a function you can test with print or Swift Testing.
  - Spot the usual mistakes in programmatic layout code.
resources: [apple-documentation, hig, swift-book-initialization, swift-result]
cards:
  - id: m22-l04-c1
    front: Which views need translatesAutoresizingMaskIntoConstraints = false in a stack-view screen?
    back: "Views you constrain yourself, such as the stack view. Not its arranged subviews: UIKit manages their layout, and Apple says not to change the property for arranged subviews."
  - id: m22-l04-c2
    front: You add init(store:) to a UIViewController subclass. What else must you write, and why?
    back: "required init?(coder:). It's a required initializer of UIViewController (UIKit uses it to create controllers from a storyboard), and adding a designated initializer stops it being inherited. Code-only controllers usually implement it with fatalError."
  - id: m22-l04-c3
    front: How do you make a label follow the user's text size?
    back: "font = .preferredFont(forTextStyle: .body) (or another style) and adjustsFontForContentSizeCategory = true. Set numberOfLines = 0 so large text can wrap."
  - id: m22-l04-c4
    front: Where should "is this amount valid?" live in a form screen?
    back: "In a plain Swift function or type that takes a String and returns a result. The view controller reads the field, calls it and shows the outcome. The rule can then be tested without UIKit."
---

## The idea in one sentence

A programmatic screen is four steps in `viewDidLoad()`: create the views, configure them, put them in a hierarchy (usually a stack view), and constrain that hierarchy to the safe area; everything that isn't about views goes into plain Swift that you can test on its own.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run, so you won't see output for them. The parsing logic is plain Swift and was compiled and run. Behavior of stack views and fonts comes from Apple's reference pages, read in November 2026.

## The screen

An "add expense" form:

```plaintext
┌─────────────────────────────┐
│ (safe area top)             │
│ New expense          ← title│
│ ┌─────────────────────────┐ │
│ │ Amount                  │ │ ← text field, decimal keypad
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ Note (optional)         │ │ ← text field
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │       Add expense       │ │ ← filled button
│ └─────────────────────────┘ │
│ Total: 0.00         ← status│
└─────────────────────────────┘
```

Five views in a column. A vertical `UIStackView` lays them out, and four constraints place the stack.

## The logic first, without UIKit

Before any view, write the part that decides things. The screen needs to turn the amount field's text into a number or an error message:

```swift
enum AmountError: Error {
    case empty, notANumber, notPositive
}

func parseAmount(_ text: String) -> Result<Double, AmountError> {
    let trimmed = text.filter { !$0.isWhitespace }
    guard !trimmed.isEmpty else { return .failure(.empty) }
    guard let amount = Double(trimmed) else { return .failure(.notANumber) }
    guard amount > 0 else { return .failure(.notPositive) }
    return .success(amount)
}

func message(for error: AmountError) -> String {
    switch error {
    case .empty: "Enter an amount."
    case .notANumber: "That doesn't look like a number."
    case .notPositive: "The amount must be more than zero."
    }
}

for input in ["12.50", " 8 ", "", "twelve", "-3"] {
    switch parseAmount(input) {
    case .success(let amount):
        print("\"\(input)\" → \(amount)")
    case .failure(let error):
        print("\"\(input)\" → \(message(for: error))")
    }
}
```

```output
"12.50" → 12.5
" 8 " → 8.0
"" → Enter an amount.
"twelve" → That doesn't look like a number.
"-3" → The amount must be more than zero.
```

This is Module 12's `Result` and Module 14's separation of concerns applied to a screen. Every rule is checked here, in a terminal, without a simulator. `Double(_:)` always expects a period as the decimal separator; a real app should parse with the user's locale, which Module 43 covers.

## The view controller

```swift ios
import UIKit

enum AmountError: Error {
    case empty, notANumber, notPositive
}

func parseAmount(_ text: String) -> Result<Double, AmountError> {
    let trimmed = text.filter { !$0.isWhitespace }
    guard !trimmed.isEmpty else { return .failure(.empty) }
    guard let amount = Double(trimmed) else { return .failure(.notANumber) }
    guard amount > 0 else { return .failure(.notPositive) }
    return .success(amount)
}

func message(for error: AmountError) -> String {
    switch error {
    case .empty: "Enter an amount."
    case .notANumber: "That doesn't look like a number."
    case .notPositive: "The amount must be more than zero."
    }
}

final class ExpenseStore {
    private(set) var total = 0.0
    func add(_ amount: Double) { total += amount }
}

final class AddExpenseViewController: UIViewController {
    private let store: ExpenseStore

    private let titleLabel = UILabel()
    private let amountField = UITextField()
    private let noteField = UITextField()
    private let addButton = UIButton(configuration: .filled())
    private let statusLabel = UILabel()
    private let stackView = UIStackView()

    init(store: ExpenseStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("AddExpenseViewController is created in code with init(store:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLabels()
        configureFields()
        configureButton()
        configureLayout()
        showTotal()
    }

    private func configureLabels() {
        titleLabel.text = "New expense"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
    }

    private func configureFields() {
        amountField.placeholder = "Amount"
        amountField.keyboardType = .decimalPad
        noteField.placeholder = "Note (optional)"

        for field in [amountField, noteField] {
            field.borderStyle = .roundedRect
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
        }
    }

    private func configureButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Add expense"
        addButton.configuration = configuration
        addButton.addAction(UIAction { [weak self] _ in
            self?.addTapped()
        }, for: .primaryActionTriggered)
    }

    private func configureLayout() {
        let rows: [UIView] = [titleLabel, amountField, noteField, addButton, statusLabel]
        for row in rows {
            stackView.addArrangedSubview(row)
        }
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.setCustomSpacing(24, after: titleLabel)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
        ])
    }

    private func addTapped() {
        switch parseAmount(amountField.text ?? "") {
        case .success(let amount):
            store.add(amount)
            amountField.text = ""
            noteField.text = ""
            showTotal()
        case .failure(let error):
            statusLabel.text = message(for: error)
        }
    }

    private func showTotal() {
        statusLabel.text = "Total: " + String(format: "%.2f", store.total)
    }
}
```

It's long because UIKit is explicit, not because it's complicated. Section by section:

### Properties

Each view is a `private let` created with its initializer. Creating a `UILabel()` is cheap and doesn't put it on screen; nothing appears until it's in a window's hierarchy. Declaring them as properties gives the controller a reference to each one it needs to read or change later. `private` keeps other types from reaching into the screen's views.

`UIButton(configuration: .filled())` uses the button configuration API (iOS 15): `filled()` is "a configuration for a button with a background filled with the button's tint color".

### The initializer pair

`init(store:)` stores the dependency and calls `super.init(nibName: nil, bundle: nil)`, `UIViewController`'s designated initializer for code; `nil` for both means "no nib". The controller can now never exist without a store, and a test can pass a fresh one.

Adding your own designated initializer means the class no longer inherits `UIViewController`'s initializers, and `init?(coder:)` is `required`, so Swift makes you write it. UIKit uses `init(coder:)` when it creates a controller from a storyboard (lesson 6). This controller is never loaded that way, so `fatalError` with a clear message is the honest implementation: if someone wires it into a storyboard, the app stops at a line that says why.

### viewDidLoad() and the configure methods

`viewDidLoad()` reads like a table of contents. Splitting configuration into small private methods keeps each one short; there's nothing UIKit-specific about that, it's Module 14's naming advice.

- **Fonts.** `preferredFont(forTextStyle:)` returns the font for a text style at the user's current Dynamic Type size, and `adjustsFontForContentSizeCategory = true` makes the label or field update when the size changes while the app runs. `numberOfLines = 0` lets a label wrap instead of truncating with large text sizes. Fixed sizes like `.systemFont(ofSize: 17)` ignore the user's setting.
- **Colors.** `.systemBackground` and `.secondaryLabel` are semantic colors: they adapt to light and dark mode on their own.
- **Text fields.** `.decimalPad` shows a keypad with digits and a decimal separator. `borderStyle = .roundedRect` gives the standard look.

### The button's action

`addAction(_:for:)` attaches a `UIAction`, which runs a closure, to the `.primaryActionTriggered` event, which Apple describes as "a semantic action triggered by buttons". `[weak self]` avoids a reference cycle: the controller owns the button, the button owns the action, and the action's closure would otherwise own the controller. Lesson 5 covers this and the older `addTarget(_:action:for:)` form.

`addTapped()` reads the field (`text` is `String?`, hence `?? ""`), asks `parseAmount` and shows the result. The controller doesn't know any rule about amounts; it only connects views to logic.

### The layout

- The five views go into the stack with `addArrangedSubview(_:)`, which "automatically adds the provided view as a subview of the stack view". `axis = .vertical` makes a column (the default is horizontal); `spacing` is the gap between neighbors, and `setCustomSpacing(_:after:)` overrides it after one view.
- **Only the stack view gets `translatesAutoresizingMaskIntoConstraints = false`** and constraints. The stack view creates the constraints for its arranged subviews, and Apple's documentation says not to modify that property "for views that UIKit classes manage, such as … arrangedSubviews."
- The stack is pinned to the **safe area** on top and on both sides. There's no bottom constraint: the stack is as tall as its content, and the rest of the screen stays empty. With a vertical stack and the default `.fill` alignment, each row stretches to the stack's width, which is why the fields and button span the screen.

Each row has a natural height: a label from its text, a field and a button from their content. Module 23 explains that ("intrinsic content size") and what happens when content doesn't fit, for example with a very large text size on a small phone, where you'd put the stack in a scroll view.

## Showing it

The scene delegate from lesson 1 creates the store and injects it:

```swift ios
import UIKit

final class ExpenseStore {}

final class AddExpenseViewController: UIViewController {
    private let store: ExpenseStore

    init(store: ExpenseStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Created in code with init(store:)")
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let store = ExpenseStore()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = AddExpenseViewController(store: store)
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

(The controller is stubbed so the block stands on its own.) Here the scene owns the store. If several scenes on iPad should share one store, create it in the app delegate instead and pass it down; Module 32 discusses where app-wide objects should live.

## Variations you'll see in real code

**Views as closures.** Many codebases configure each view where it's declared:

```swift ios
import UIKit

final class GreetingViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
}
```

The closure runs once when the controller is created. It keeps each view's setup next to its declaration; the configure-method style keeps `viewDidLoad()` readable. Both are fine; pick one per project.

**A custom root view.** Large screens often move all the view code into a `UIView` subclass and install it with `loadView()` (lesson 2), leaving the controller with only the logic and the wiring. The trade-off is one more type for one more level of separation.

## Common mistakes

> [!error] Constraining arranged subviews to the stack or to each other
> The stack view already creates those constraints. Adding your own between arranged subviews usually conflicts with them. Constrain the stack, and give arranged subviews only size constraints when you need them (a fixed button height, for example).

> [!error] Forgetting translatesAutoresizingMaskIntoConstraints on the stack
> The stack keeps its zero frame as constraints, which conflict with your four anchors. Set it to `false` on every view you constrain yourself.

> [!error] Fixed font sizes
> `.systemFont(ofSize: 17)` ignores the user's text size. Use `preferredFont(forTextStyle:)` with `adjustsFontForContentSizeCategory = true`, and let labels wrap.

> [!error] Rules inside the action
> `if Double(amountField.text!)! > 0 { … }` in a button handler crashes on empty or invalid input and can't be tested without UIKit. Parse in a plain function that returns a `Result` or an optional, and keep the force unwraps out.

> [!error] A custom init without init(coder:)
> Swift rejects the class: `init(coder:)` is required by `UIViewController` and is no longer inherited. Write it, even if it only calls `fatalError` with a clear message.

## Exercises

````exercise
id: m22-l04-e1
type: prediction
prompt: "A sign-up form uses this plain-Swift check before enabling its button. What does it print?"
code: |
  func problems(username: String, password: String) -> [String] {
      var result: [String] = []
      if username.count < 3 {
          result.append("username too short")
      }
      if username.contains(" ") {
          result.append("username has spaces")
      }
      if password.count < 8 {
          result.append("password too short")
      }
      if !password.contains(where: \.isNumber) {
          result.append("password needs a digit")
      }
      return result
  }

  let attempts = [("al", "secret"), ("ana maria", "password1"), ("christian", "swift2026")]
  for (username, password) in attempts {
      let found = problems(username: username, password: password)
      print(found.isEmpty ? "\(username): ok" : "\(username): " + found.joined(separator: ", "))
  }
output: |
  al: username too short, password too short, password needs a digit
  ana maria: username has spaces
  christian: ok
hints:
  - "Each check is independent; a username can fail more than one."
  - "\"password1\" has 9 characters and a digit."
solution: |
  ```output
  al: username too short, password too short, password needs a digit
  ana maria: username has spaces
  christian: ok
  ```

  `"al"` fails three checks ("secret" has 6 characters and no digit). `"ana maria"` is long enough but has a space, and `"password1"` passes both password rules. `"christian"` and `"swift2026"` pass everything. Because this function has no UIKit in it, you can test every rule like this; the view controller only calls it and shows the messages.
````

````exercise
id: m22-l04-e2
type: comprehension
prompt: "Why does adding init(store:) to a UIViewController subclass force you to write required init?(coder:)?"
choices:
  - text: "init(coder:) is a required initializer of UIViewController, and defining your own designated initializer means the subclass no longer inherits it automatically."
    correct: true
    why: "That's Swift's initializer inheritance rule (Module 10) applied to UIKit's required initializer."
  - text: "UIKit calls init(coder:) every time a view controller is created, even in code."
    correct: false
    why: "Code that calls init(store:) never goes through init(coder:). UIKit uses it when creating the controller from a storyboard."
  - text: "init(coder:) is where viewDidLoad() is called from."
    correct: false
    why: "viewDidLoad() runs after the view is loaded, on first access to view, not from an initializer."
  - text: "It's only needed when the controller has stored properties without default values."
    correct: false
    why: "Any new designated initializer stops the inheritance, whatever the properties."
solution: |
  **The first option.** A subclass inherits its superclass's designated initializers only if it defines none of its own. `init(store:)` is a designated initializer, so the inheritance stops, and because `UIViewController` marks `init?(coder:)` as `required`, every subclass must provide it. Code-only controllers implement it with `fatalError` and a message, since nothing should load them from an archive.
````

````exercise
id: m22-l04-e3
type: fill-in
prompt: Configure a vertical stack view with 8 points between rows and pin it to the safe area's leading and trailing edges.
code: |
  let stack = UIStackView([[1]]: [nameLabel, emailLabel])
  stack.axis = .[[2]]
  stack.[[3]] = 8
  stack.translatesAutoresizingMaskIntoConstraints = false
  view.addSubview(stack)
  NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      stack.leadingAnchor.constraint(equalTo: view.[[4]].leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
  ])
blanks:
  - id: "1"
    answers: ["arrangedSubviews"]
  - id: "2"
    answers: ["vertical"]
  - id: "3"
    answers: ["spacing"]
  - id: "4"
    answers: ["safeAreaLayoutGuide"]
solution: |
  ```swift ios
  import UIKit

  final class ContactViewController: UIViewController {
      private let nameLabel = UILabel()
      private let emailLabel = UILabel()

      override func viewDidLoad() {
          super.viewDidLoad()
          let stack = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
          stack.axis = .vertical
          stack.spacing = 8
          stack.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(stack)
          NSLayoutConstraint.activate([
              stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
              stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
          ])
      }
  }
  ```

  `UIStackView(arrangedSubviews:)` adds both labels as arranged subviews and as subviews. The default axis is horizontal, so a column needs `.vertical`. The labels get no constraints of their own.
````

````exercise
id: m22-l04-e4
type: find-errors
prompt: "This screen shows a name label and a Save button. Mark every real problem."
code: |
  final class EditNameViewController: UIViewController {
      private let nameLabel = UILabel()
      private let saveButton = UIButton(configuration: .filled())
      private let stack = UIStackView()

      init(name: String) {
          super.init(nibName: nil, bundle: nil)
          nameLabel.text = name
      }

      override func viewDidLoad() {
          super.viewDidLoad()
          nameLabel.font = .systemFont(ofSize: 17)
          stack.axis = .vertical
          stack.addArrangedSubview(nameLabel)
          stack.addArrangedSubview(saveButton)
          view.addSubview(stack)
          NSLayoutConstraint.activate([
              stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
              stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
              nameLabel.bottomAnchor.constraint(equalTo: saveButton.topAnchor),
          ])
      }
  }
choices:
  - text: "required init?(coder:) is missing, so the class doesn't compile."
    correct: true
  - text: "The stack view keeps translatesAutoresizingMaskIntoConstraints = true."
    correct: true
  - text: "The fixed 17-point font ignores Dynamic Type."
    correct: true
  - text: "The constraint between nameLabel and saveButton duplicates what the stack view manages and can conflict with it."
    correct: true
  - text: "nameLabel.text can't be set in init because the view isn't loaded."
    correct: false
    why: "nameLabel is the controller's own property, created with the controller. Setting its text doesn't touch view. (Adding it to view would.)"
rubric:
  - I found the missing required initializer.
  - I found the stack's autoresizing constraints.
  - I found the fixed font size.
  - I found the extra constraint between arranged subviews.
solution: |
  Four problems:

  1. **No `required init?(coder:)`.** Adding `init(name:)` stops initializer inheritance; Swift requires the coder initializer.
  2. **The stack still translates its autoresizing mask.** Add `stack.translatesAutoresizingMaskIntoConstraints = false` before activating.
  3. **`.systemFont(ofSize: 17)`** ignores the user's text size. Use `.preferredFont(forTextStyle: .body)` with `adjustsFontForContentSizeCategory = true`.
  4. **`nameLabel.bottomAnchor` to `saveButton.topAnchor`**: the stack view already positions its arranged subviews relative to each other (with `spacing`). Remove it.

  Setting `nameLabel.text` in `init` is fine: the label exists as soon as the controller does. It's reading or changing `view` in `init` that loads the view early (lesson 2).
````

````exercise
id: m22-l04-e5
type: solve
prompt: |
  Build a counter screen in code:

  - A large-title label showing the count, starting at 0.
  - Two buttons in a **horizontal** stack: "+1" (filled) and "Reset" (gray, from `UIButton.Configuration.gray()`).
  - The label and the button row in a **vertical** stack with 16 points of spacing, centered in the safe area.
  - The count lives in a property; the buttons use `UIAction` with `[weak self]`.
starter: |
  import UIKit

  final class CounterViewController: UIViewController {
      private var count = 0
      // your code
  }
hints:
  - "Centering needs only two constraints: centerXAnchor and centerYAnchor to the safe area's."
  - "Write a private method updateLabel() and call it from both actions and from viewDidLoad()."
  - "UIButton(configuration:primaryAction:) copies the action's title into the button."
rubric:
  - Uses a vertical stack containing the label and a horizontal stack of two buttons.
  - Only the outer stack has translatesAutoresizingMaskIntoConstraints = false and constraints.
  - Centers the stack against the safe area layout guide.
  - Uses Dynamic Type for the label.
  - Uses UIAction closures with [weak self] and updates the label from one method.
solution: |
  ```swift ios
  import UIKit

  final class CounterViewController: UIViewController {
      private var count = 0
      private let countLabel = UILabel()

      override func viewDidLoad() {
          super.viewDidLoad()
          view.backgroundColor = .systemBackground

          countLabel.font = .preferredFont(forTextStyle: .largeTitle)
          countLabel.adjustsFontForContentSizeCategory = true
          countLabel.textAlignment = .center

          let increment = UIButton(configuration: .filled(), primaryAction: UIAction(title: "+1") { [weak self] _ in
              self?.count += 1
              self?.updateLabel()
          })
          let reset = UIButton(configuration: .gray(), primaryAction: UIAction(title: "Reset") { [weak self] _ in
              self?.count = 0
              self?.updateLabel()
          })

          let buttons = UIStackView(arrangedSubviews: [increment, reset])
          buttons.axis = .horizontal
          buttons.spacing = 12

          let column = UIStackView(arrangedSubviews: [countLabel, buttons])
          column.axis = .vertical
          column.spacing = 16
          column.alignment = .center
          column.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(column)

          let guide = view.safeAreaLayoutGuide
          NSLayoutConstraint.activate([
              column.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
              column.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
          ])
          updateLabel()
      }

      private func updateLabel() {
          countLabel.text = "\(count)"
      }
  }
  ```

  The inner stack is an arranged subview of the outer one, so it needs no constraints; only `column` is pinned. `alignment = .center` keeps the label and the button row at their natural widths instead of stretching them. `UIButton(configuration:primaryAction:)` takes the title from the action, as its documentation says. Both closures capture `self` weakly because the controller owns the buttons that own the actions.
````

````exercise
id: m22-l04-e6
type: explain
prompt: "A teammate puts the amount validation directly inside the button's action closure and says splitting it out is over-engineering for one screen. Make the case for parseAmount(_:), in a few sentences."
code: |
  addButton.addAction(UIAction { [weak self] _ in
      guard let self, let text = self.amountField.text, let amount = Double(text), amount > 0 else {
          self?.statusLabel.text = "Invalid amount"
          return
      }
      self.store.add(amount)
  }, for: .primaryActionTriggered)
rubric:
  - Points out that the rule can't be tested without creating the controller, its views and simulating a tap.
  - Notes that the combined guard loses which rule failed, so the user gets one vague message.
  - Mentions reuse (an edit screen or an import needs the same rule).
  - Keeps the cost honest - one small function, no new architecture.
solution: |
  The closure mixes three jobs: reading a field, deciding whether an amount is valid, and updating the UI. As written, the only way to test the rule is to build the controller, load its view, type into the field and trigger the button. `parseAmount(_:)` is a pure function you can check with five `print`s or five Swift Testing cases.

  Splitting it also improves the behavior: one `guard` collapses "empty", "not a number" and "negative" into "Invalid amount", while a `Result` with an error enum lets the screen say what's wrong. And the next screen that needs the same rule (editing an expense, importing a CSV) can call it instead of copying the closure. The cost is one function and one enum, not a new architecture.
````

## Summary

- Build programmatic screens in `viewDidLoad()`: create, configure, add to a stack view, constrain the stack to the safe area.
- Only views you constrain yourself need `translatesAutoresizingMaskIntoConstraints = false`; a stack view manages its arranged subviews' layout.
- Use `preferredFont(forTextStyle:)` with `adjustsFontForContentSizeCategory`, `numberOfLines = 0` and semantic colors from the first line.
- Inject dependencies with `init(…)` plus `super.init(nibName: nil, bundle: nil)`, and implement the `required init?(coder:)` Swift then asks for.
- Use `UIAction` with `[weak self]` for button handlers; lesson 5 explains the alternatives.
- Keep parsing and rules in plain Swift; the view controller reads views, calls the logic and shows the result.
