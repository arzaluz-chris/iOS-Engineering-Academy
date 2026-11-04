---
id: m34-l01
title: The declarative model
description: "In UIKit you create views once and then change them, event by event. In SwiftUI you write a function from state to a description of the screen, and the framework does the changing. You rebuild Module 22's expense form both ways, see what kind of bug disappears, meet App, Scene and the body property, and get a first, high-level picture of view identity: how SwiftUI decides that the thing on screen now is the same thing as before."
module: m34
order: 1
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l04, m29-l06]
objectives:
  - Explain the difference between updating views imperatively (UIKit) and describing them as a function of state (SwiftUI).
  - Read a SwiftUI view struct and say which parts are inputs, which is state, and what body produces.
  - Describe how App, Scene and WindowGroup replace the app delegate, scene delegate and window from Module 22.
  - Say why body must be cheap and free of side effects.
  - Explain at a high level what view identity is and predict when a view's state is kept or reset.
terms:
  - term: Declarative UI
    definition: "You describe what the interface should look like for the current data, and the framework works out which changes to make on screen. The opposite, imperative UI, is you calling methods that change existing views."
  - term: View (SwiftUI)
    definition: "A value of a type that conforms to the View protocol: a lightweight description of part of the interface. It isn't the thing on screen; SwiftUI creates, discards and recreates view values freely."
  - term: body
    definition: "The View protocol's main requirement: a computed property that returns the view's content. SwiftUI reads it whenever it needs to update the view, possibly many times."
  - term: "@State"
    definition: "A property wrapper that asks SwiftUI to store a value for the view outside the struct. Changing it makes SwiftUI read body again. Covered in depth in Module 36."
  - term: Scene
    definition: "A part of an app's interface with a life cycle managed by the system, such as a WindowGroup. On iPhone and iPad it corresponds to UIKit's UIWindowScene."
  - term: View identity
    definition: "How SwiftUI decides that a view in a new body result is the same one as before, so it keeps its state. It comes from the view's position in the hierarchy, or from an explicit id."
mastery:
  - Take a UIKit event handler that sets three labels and rewrite it as a state change plus a body that reads the state.
  - Point out the state, the inputs and the derived values in a small SwiftUI view.
  - Write an App with one WindowGroup and explain what happens when a second window opens on iPad.
  - Spot work that doesn't belong in a view's init or body.
  - Predict whether a counter's state survives when a condition switches between two if branches, and when an id changes.
resources: [swift-book-opaque-types, swift-book-structures-classes, swift-book-properties, swiftui-scenephase, hig]
cards:
  - id: m34-l01-c1
    front: Imperative vs declarative UI in one sentence each?
    back: "Imperative (UIKit): you create views, then call methods to change them every time something happens. Declarative (SwiftUI): you write body as a function of state, change the state, and SwiftUI updates the screen to match."
  - id: m34-l01-c2
    front: Why must a SwiftUI view's body be cheap and free of side effects?
    back: "SwiftUI reads body whenever it needs to update the view, which can happen many times and at moments you don't choose. Work done there repeats; side effects happen at unpredictable times. Put work in actions, in .task, or in a model."
  - id: m34-l01-c3
    front: What do App, Scene and WindowGroup correspond to in UIKit?
    back: "App: the @main entry point plus app-wide setup (what the app delegate did). Scene: a UIWindowScene's content and life cycle. WindowGroup: the scene type that creates a window for its view hierarchy; on iPad each window gets its own state."
  - id: m34-l01-c4
    front: What is view identity, and why does it matter?
    back: "It's how SwiftUI matches a view in a new body result to the one on screen. Same identity: state is kept and changes can be animated. New identity: the old view and its state go away and a new one starts from its initial state."
  - id: m34-l01-c5
    front: What does the id(_:) modifier do when its value changes?
    back: "Apple: it binds a view's identity to the value, and when the value changes the view's identity, including its state, is reset. SwiftUI treats it as a new view."
---

## The idea in one sentence

In UIKit you build views once and then change them every time something happens; in SwiftUI you write one function from **state to a description of the screen**, change only the state, and the framework makes the screen match.

> [!note] About this lesson's code
> Blocks that import SwiftUI are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run, so there's no output for them. The SwiftUI behavior described here comes from Apple's SwiftUI reference pages, read in November 2026. The plain-Swift models were compiled and run; they're simplified models built to show an idea, not SwiftUI's implementation.

## The same screen, two ways

Module 22 built an "add expense" form in UIKit. Look at what the controller did when the button was tapped:

```swift illustrative
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
```

Every line after `store.add(amount)` exists to keep views in sync with data. The controller has to know, for each event, **which views** the event affects and **what** to set on each one. With five views that's manageable. With thirty, and ten events, and some views that depend on several pieces of data, the number of "when X happens, update Y" paths grows fast, and each one is a chance to forget a view.

Here's the same form in SwiftUI:

```swift ios
import SwiftUI

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

struct AddExpenseView: View {
    @State private var amountText = ""
    @State private var noteText = ""
    @State private var total = 0.0
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("Note (optional)", text: $noteText)
            }
            Section {
                Button("Add expense", action: addTapped)
            } footer: {
                Text(errorMessage ?? "Total: " + String(format: "%.2f", total))
            }
        }
    }

    private func addTapped() {
        switch parseAmount(amountText) {
        case .success(let amount):
            total += amount
            amountText = ""
            noteText = ""
            errorMessage = nil
        case .failure(let error):
            errorMessage = message(for: error)
        }
    }
}
```

The parsing functions are Module 22's, unchanged. The rest is different in kind, not just shorter:

- **`struct AddExpenseView: View`.** A view is a struct that conforms to `View`. There's no `viewDidLoad()`, no stored references to text fields or labels, and no layout constraints.
- **`@State private var …`** are the four pieces of data the screen depends on. `@State` asks SwiftUI to store each value outside the struct and to update the view when it changes. That's all you need from it in this module; Module 36 explains where state should live and the other property wrappers.
- **`var body: some View`** describes the screen **for the current values** of that state: a form with two fields, a button, and a footer that shows either the error or the total. It doesn't say "set the footer's text"; it says "the footer's text is this expression".
- **`$amountText`** passes a *binding*, a two-way connection, so the text field can both show and change `amountText`. Lesson 4 looks at bindings from the controls' side.
- **`addTapped()`** changes state and nothing else. It never touches a view. After it runs, SwiftUI reads `body` again, and the footer, the fields and anything else that depends on the changed values come out right.

Apple's article "Declaring a custom view" puts the contrast this way: with an imperative approach "the burden is on your controller code not only to instantiate, lay out, and configure views, but also to continually make updates as conditions change", while with a declarative approach you "create a lightweight description of your user interface" and "SwiftUI then manages drawing and updating these views in response to events like user input or state changes."

## What actually goes away

The bug that disappears is the **stale view**: a view that shows an old value because one code path forgot to update it. Here is a plain-Swift model of both styles. The imperative version has handlers that set "labels"; the declarative one derives every label from state in one function:

```swift
final class Label {
    var text = ""
}

// Imperative: each event updates the labels it knows about.
final class ImperativeScreen {
    let totalLabel = Label()
    let countLabel = Label()
    private var amounts: [Double] = []

    func add(_ amount: Double) {
        amounts.append(amount)
        totalLabel.text = "Total: \(amounts.reduce(0, +))"
        countLabel.text = "\(amounts.count) expenses"
    }

    func removeLast() {
        amounts.removeLast()
        totalLabel.text = "Total: \(amounts.reduce(0, +))"
        // Forgot countLabel.
    }
}

// Declarative: one function from state to what the screen shows.
struct ScreenState {
    var amounts: [Double] = []
}

func render(_ state: ScreenState) -> [String] {
    ["Total: \(state.amounts.reduce(0, +))", "\(state.amounts.count) expenses"]
}

let imperative = ImperativeScreen()
imperative.add(12)
imperative.add(8)
imperative.removeLast()
print("imperative:", imperative.totalLabel.text, "|", imperative.countLabel.text)

var state = ScreenState()
state.amounts.append(12)
state.amounts.append(8)
state.amounts.removeLast()
print("declarative:", render(state).joined(separator: " | "))
```

```output
imperative: Total: 12.0 | 2 expenses
declarative: Total: 12.0 | 1 expenses
```

The imperative screen says "2 expenses" after removing one, because `removeLast()` forgot a label. The declarative version can't make that mistake: there's no "update the count" step to forget, because the count text is always computed from the current state. (Its "1 expenses" is a plural bug, but it's the same bug everywhere, and you fix it in one place.)

That's the whole model in miniature. SwiftUI's job is to run your `render` (`body`) when the state changes and to change the real screen as little as possible to match the new description. How it does that is SwiftUI's business; Apple doesn't document the internal algorithm, and you don't need it to write correct views.

> [!note] Declarative isn't free
> You give up direct control. You can't say "change this one label now"; you change state and let SwiftUI decide what to redraw. Most of the time that's what you want. When it isn't (a very large list, a view that redraws too often), the fix is to change the shape of your state and views, which Module 36 and the performance module cover.

## Views are values, not objects on screen

A `UILabel` is an object that lives as long as it's in the hierarchy; you keep a reference and change it. A SwiftUI `Text("Total")` is a struct, a few bytes describing a label. `body` returns a fresh tree of these values each time it runs, and SwiftUI throws them away after reading them. The things on screen are SwiftUI's, and you never get a reference to them.

Two practical consequences:

- **You can't mutate a view from outside.** There's no `footer.text = …`. If something should change, it has to be state that `body` reads.
- **A view's stored properties are inputs, not storage.** A plain `var` in a view struct can't be changed from `body` or an action, because `body` is a non-mutating getter. This plain-Swift model has the same shape as a SwiftUI button that tries to count its taps:

```swift no-compile left side of mutating operator isn't mutable: 'self' is immutable
struct Button {
    let title: String
    let action: () -> Void
}

struct CounterView {
    var count = 0

    var body: Button {
        Button(title: "Tapped \(count) times") {
            count += 1
        }
    }
}
```

Swift 6.3: `error: left side of mutating operator isn't mutable: 'self' is immutable`. Inside the getter, `self` is a constant, and the closure captures that constant. In a real SwiftUI view you get the same error for the same reason, and the fix is `@State private var count = 0`: the struct no longer holds the count, it holds a handle to storage SwiftUI keeps for it, and writing through that handle is allowed.

## The body property

`View` has one requirement you implement, `body`:

```swift ios
import SwiftUI

struct Greeting: View {
    let name: String

    var body: some View {
        VStack {
            Text("Hello, \(name)")
                .font(.title)
            Text("Glad to see you.")
        }
    }
}
```

- **`some View`** is an opaque return type (Module 10): `body` returns one specific type, which the compiler knows and you don't have to spell. Here it's a `VStack` of two texts, one of them wrapped in a font modifier. Lesson 3 shows how the two `Text` lines become one value.
- **`let name: String`** is an input. Whoever creates `Greeting(name: "Ana")` passes it, through the memberwise initializer Swift writes for you.
- **When SwiftUI reads it.** Apple: "SwiftUI reads the value of this property any time it needs to update the view, which can happen repeatedly during the life of the view, typically in response to user input or system events."

That last point sets the rules for what goes in `body`:

1. **Keep it cheap.** It may run often. Sorting ten items is fine; parsing a big file isn't.
2. **No side effects.** Don't start network requests, write files, print analytics or change state while computing `body`. You don't control when or how often it runs. Actions (`Button`'s closure), `.task` and `.onChange` are where effects go; you'll use them in later modules.
3. **Keep initializers trivial too.** Apple: "Because the system may reinitialize a view at any time, it's important to avoid doing any significant work in your view's initialization code. It's often best to omit an explicit initializer."

> [!version] Xcode 27
> Apple's `State` page says that "when you build with Xcode 27 or later, the system uses the `State()` macro instead" of the property wrapper. You still write `@State private var count = 0`; what changes is how the compiler implements it. This course's iOS blocks are checked with Xcode 26, so they use the property wrapper.

## App and Scene

Module 22 started an app with an app delegate, a scene delegate that created a `UIWindow`, and a root view controller. A SwiftUI app describes the same structure declaratively:

```swift illustrative
import SwiftUI

@main
struct ExpensesApp: App {
    var body: some Scene {
        WindowGroup {
            AddExpenseView()
        }
    }
}
```

- **`App`** is "a type that represents the structure and behavior of an app". `@main` marks it as the entry point; the protocol provides the `main()` that launches the app. You can have exactly one `@main` in an app.
- **`body: some Scene`** has the same shape as a view's `body`, one level up: it lists the app's scenes.
- **`WindowGroup`** is "a scene that presents a group of identically structured windows". Its closure is the root view of each window. On iPhone there's one window. On iPad, where people can open several, Apple says "every window in the group maintains independent state": each window gets its own storage for the `@State` in its views. That's the scene-per-window model you saw in Module 22, done for you. (iPad multiwindow still needs `UIApplicationSupportsMultipleScenes` in the Info.plist, as in UIKit.)

The block above is marked illustrative because the course's iOS check compiles each block as a `main.swift` file, where `@main` isn't allowed. Without `@main`, the same declaration type-checks:

```swift ios
import SwiftUI

struct ExpensesApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Expenses")
        }
    }
}
```

What happened to the delegate callbacks? Scene life-cycle events arrive through the `scenePhase` environment value (Module 21), and for the few app-delegate callbacks SwiftUI has no equivalent for, such as the push token, you attach a delegate with `@UIApplicationDelegateAdaptor`. You'll rarely write more than the `App` above.

## Identity and lifetime, at a high level

If `body` returns brand-new view values every time, how does a text field keep what you typed, or a toggle stay on? SwiftUI keeps the real interface element and its state, and each time `body` runs it **matches the new description to what's already on screen**. The question it has to answer for each view is: is this the same view as before?

The answer is the view's **identity**. It comes from two places:

- **Position in the hierarchy.** The second child of the `VStack` in the first branch of an `if` is the same view across updates as long as it stays there. This is often called structural identity.
- **An explicit identifier.** `ForEach` identifies its rows by an id you provide (lesson 5), and the `id(_:)` modifier ties a view's identity to a value you choose. This is often called explicit identity.

The view's **lifetime** is the time its identity stays in the hierarchy. Its state lives exactly that long. Apple's `id(_:)` page states the rule for explicit ids: "When the proxy value specified by the `id` parameter changes, the identity of the view — for example, its state — is reset." The structural rule, that the two branches of an `if` are different views, comes from Apple's WWDC21 session on SwiftUI's identity model rather than the reference pages.

Here's a model of that bookkeeping: state stored in a dictionary keyed by an identity path, dropped when the path disappears, created fresh when a new path appears.

```swift
var storage: [String: Int] = [:]   // a counter's state, keyed by identity

func update(_ storage: inout [String: Int], showing paths: [String]) {
    storage = storage.filter { paths.contains($0.key) }   // views that left lose their state
    for path in paths where storage[path] == nil {
        storage[path] = 0                                  // new views start fresh
    }
    print(paths.map { "\($0) = \(storage[$0]!)" }.joined(separator: ", "))
}

// body: if isCompact { Counter() } else { Counter() }
func bodyWithBranches(isCompact: Bool) -> [String] {
    isCompact ? ["VStack/if-then/Counter"] : ["VStack/if-else/Counter"]
}

// body: Counter().padding(isCompact ? 4 : 16)
func bodyWithModifier(isCompact: Bool) -> [String] {
    ["VStack/Counter"]
}

update(&storage, showing: bodyWithBranches(isCompact: false))
storage["VStack/if-else/Counter"] = 3        // the user taps three times
update(&storage, showing: bodyWithBranches(isCompact: true))
update(&storage, showing: bodyWithBranches(isCompact: false))

storage = [:]
update(&storage, showing: bodyWithModifier(isCompact: false))
storage["VStack/Counter"] = 3
update(&storage, showing: bodyWithModifier(isCompact: true))
```

```output
VStack/if-else/Counter = 0
VStack/if-then/Counter = 0
VStack/if-else/Counter = 0
VStack/Counter = 0
VStack/Counter = 3
```

With an `if`/`else`, switching the condition replaces the counter with a different view, so its count of 3 is lost, and switching back doesn't bring it back. With one counter and a modifier whose value depends on the condition, the counter keeps its identity and its count. The practical rule follows: **when only a property differs, change the property, not the branch.** Use `if` when you really mean "a different view".

> [!warning] A model, not the implementation
> SwiftUI doesn't store state in a dictionary of strings, and Apple doesn't document how it does store it. The model is accurate about the observable behavior that Apple describes: state lives as long as identity, and a new identity starts from the initial state.

## Common mistakes

> [!error] Changing a view from an action
> UIKit habit: you want a button to change a label, so you look for a reference to the label. There isn't one. Make the label's text depend on state (`Text(message)`) and change the state in the action.

> [!error] error: left side of mutating operator isn't mutable: 'self' is immutable
> A plain `var` in a view, changed from a button's closure. `body` is a non-mutating getter, so `self` is a constant there. If the value belongs to the view and changes over time, mark it `@State private var`.

> [!error] Work in body or init
> Fetching data, decoding a file or creating an expensive object in `body` or in a view's initializer. Both run more often than you expect. Do the work in an action, in `.task`, or in a model object that outlives the view.

> [!error] Using if/else to change a style
> `if isHighlighted { Text(title).bold() } else { Text(title) }` creates two different views, so any state inside them resets and SwiftUI can't animate one into the other. Prefer one view with a value that changes: `Text(title).bold(isHighlighted)`.

## Exercises

````exercise
id: m34-l01-e1
type: prediction
prompt: "The identity model from the lesson, with a screen that shows a counter in one of two branches and changes an explicit id. What does it print?"
code: |
  var storage: [String: Int] = [:]

  func update(_ storage: inout [String: Int], showing paths: [String]) {
      storage = storage.filter { paths.contains($0.key) }
      for path in paths where storage[path] == nil {
          storage[path] = 0
      }
      print(paths.map { "\($0)=\(storage[$0]!)" }.joined(separator: " "))
  }

  func body(isEditing: Bool, draftID: Int) -> [String] {
      let editor = "Form/Editor#\(draftID)"
      return isEditing ? ["Form/Title", editor] : ["Form/Title"]
  }

  update(&storage, showing: body(isEditing: true, draftID: 1))
  storage["Form/Title"] = 5
  storage["Form/Editor#1"] = 2
  update(&storage, showing: body(isEditing: true, draftID: 1))
  update(&storage, showing: body(isEditing: true, draftID: 2))
  update(&storage, showing: body(isEditing: false, draftID: 2))
  update(&storage, showing: body(isEditing: true, draftID: 2))
output: |
  Form/Title=0 Form/Editor#1=0
  Form/Title=5 Form/Editor#1=2
  Form/Title=5 Form/Editor#2=0
  Form/Title=5
  Form/Title=5 Form/Editor#2=0
hints:
  - "A path that appears in two consecutive updates keeps its value."
  - "Changing draftID changes the editor's path, like changing an id(_:) value."
  - "Leaving the hierarchy drops the state; coming back starts at 0."
solution: |
  ```output
  Form/Title=0 Form/Editor#1=0
  Form/Title=5 Form/Editor#1=2
  Form/Title=5 Form/Editor#2=0
  Form/Title=5
  Form/Title=5 Form/Editor#2=0
  ```

  The title is present in every update, so it keeps 5 throughout. The editor keeps 2 while its path stays `Editor#1`. Changing `draftID` gives it a new identity, which starts at 0, the same thing `id(_:)` does in SwiftUI. Hiding the editor drops its state, so showing it again starts from 0 even though the id is the same as before it was hidden.
````

````exercise
id: m34-l01-e2
type: comprehension
prompt: "In AddExpenseView, the user taps Add expense with \"12\" in the amount field. What updates the footer to \"Total: 12.00\"?"
choices:
  - text: "addTapped() changes total and amountText; SwiftUI then reads body again, and the new description has the new footer text."
    correct: true
    why: "Actions change state; SwiftUI re-evaluates body for views whose state changed and updates the screen to match."
  - text: "addTapped() sets the footer's text directly."
    correct: false
    why: "The view has no reference to the footer. It only changes state."
  - text: "The TextField's binding updates the footer as the user types."
    correct: false
    why: "The binding changes amountText. The footer reads total and errorMessage, which only addTapped() changes."
  - text: "Nothing: body runs once, when the view is created."
    correct: false
    why: "Apple: SwiftUI reads body any time it needs to update the view, which can happen repeatedly."
solution: |
  **State change, then a new body.** `addTapped()` sets `total`, clears the fields and clears `errorMessage`. Because those are `@State`, SwiftUI knows the view depends on them and reads `body` again; the footer expression now evaluates to "Total: 12.00", and SwiftUI updates the screen to match. No code ever "sets" the footer.
````

````exercise
id: m34-l01-e3
type: prediction
prompt: "An imperative screen model with three events. Which labels end up stale? Predict the output."
code: |
  final class Label {
      var text = "-"
  }

  final class CartScreen {
      let itemsLabel = Label()
      let totalLabel = Label()
      let checkoutLabel = Label()
      private var prices: [Int] = []

      func add(_ price: Int) {
          prices.append(price)
          itemsLabel.text = "\(prices.count) items"
          totalLabel.text = "$\(prices.reduce(0, +))"
          checkoutLabel.text = prices.isEmpty ? "Checkout disabled" : "Checkout"
      }

      func clear() {
          prices.removeAll()
          itemsLabel.text = "0 items"
          totalLabel.text = "$0"
      }

      func applyCoupon(_ discount: Int) {
          prices = prices.map { max(0, $0 - discount) }
          totalLabel.text = "$\(prices.reduce(0, +))"
      }
  }

  let screen = CartScreen()
  screen.add(10)
  screen.add(4)
  screen.applyCoupon(5)
  print(screen.itemsLabel.text, screen.totalLabel.text, screen.checkoutLabel.text)
  screen.clear()
  print(screen.itemsLabel.text, screen.totalLabel.text, screen.checkoutLabel.text)
output: |
  2 items $5 Checkout
  0 items $0 Checkout
hints:
  - "After the coupon, the prices are [5, 0]."
  - "Which label does clear() not touch?"
solution: |
  ```output
  2 items $5 Checkout
  0 items $0 Checkout
  ```

  The coupon turns `[10, 4]` into `[5, 0]`, total $5, and the other two labels happen to be right. `clear()` forgets `checkoutLabel`, so the screen says "Checkout" with an empty cart: a stale view. In a declarative version, the checkout text would be an expression in `body`, like `Text(prices.isEmpty ? "Checkout disabled" : "Checkout")`, evaluated from the current state every time, and there'd be nothing to forget.
````

````exercise
id: m34-l01-e4
type: solve
prompt: |
  Rewrite the cart from the previous exercise declaratively, in plain Swift. Write a `CartState` struct holding the prices and a function `render(_:) -> [String]` returning the three label texts in order: items, total, checkout. Then make these state changes and print `render` after each:

  ```swift
  var cart = CartState()
  print(render(cart))
  cart.prices.append(10)
  cart.prices.append(4)
  print(render(cart))
  cart.prices.removeAll()
  print(render(cart))
  ```

  The output should be:

  ```output
  ["0 items", "$0", "Checkout disabled"]
  ["2 items", "$14", "Checkout"]
  ["0 items", "$0", "Checkout disabled"]
  ```
starter: |
  struct CartState {
      var prices: [Int] = []
  }

  func render(_ state: CartState) -> [String] {
      // your code
      []
  }
hints:
  - "Each label text is an expression over state.prices."
  - "The checkout text uses isEmpty, the same expression the imperative add(_:) used."
rubric:
  - CartState holds only the data (the prices); no labels, no derived values stored.
  - render computes all three texts from the state every time.
  - The three printed lines match exactly.
  - There is no separate code path per event that updates labels.
solution: |
  ```swift
  struct CartState {
      var prices: [Int] = []
  }

  func render(_ state: CartState) -> [String] {
      [
          "\(state.prices.count) items",
          "$\(state.prices.reduce(0, +))",
          state.prices.isEmpty ? "Checkout disabled" : "Checkout",
      ]
  }

  var cart = CartState()
  print(render(cart))
  cart.prices.append(10)
  cart.prices.append(4)
  print(render(cart))
  cart.prices.removeAll()
  print(render(cart))
  ```

  ```output
  ["0 items", "$0", "Checkout disabled"]
  ["2 items", "$14", "Checkout"]
  ["0 items", "$0", "Checkout disabled"]
  ```

  The state holds the only real data, the prices. The item count, total and checkout text are derived, so they're computed in `render` rather than stored; storing them would bring back the stale-value problem. Any change to `prices`, from any event, is followed by the same `render`, which is what SwiftUI does with `body`.
````

````exercise
id: m34-l01-e5
type: find-errors
prompt: "This view is meant to show a profile and let the user follow it. Which of these are real problems?"
code: |
  import SwiftUI

  struct ProfileView: View {
      let userID: Int
      var isFollowing = false
      let profile: Profile

      init(userID: Int) {
          self.userID = userID
          self.profile = ProfileLoader().loadFromDisk(id: userID)
      }

      var body: some View {
          Analytics.log("profile shown")
          return VStack {
              Text(profile.name)
              Button(isFollowing ? "Unfollow" : "Follow") {
                  isFollowing.toggle()
              }
          }
      }
  }
choices:
  - text: "isFollowing is a plain var, so the button's closure can't change it; it should be @State private var."
    correct: true
    why: "body is a non-mutating getter. Swift 6.3 rejects isFollowing.toggle() there with \"cannot use mutating member on immutable value: 'self' is immutable\"."
  - text: "The initializer loads the profile from disk, and SwiftUI may create this struct many times."
    correct: true
    why: "Apple advises against significant work in a view's initializer because the system may reinitialize views at any time."
  - text: "body logs an analytics event, a side effect that runs every time SwiftUI reads body."
    correct: true
    why: "body can run many times; use .onAppear or .task for an effect tied to the view appearing."
  - text: "A view struct can't have a let property."
    correct: false
    why: "let properties are the normal way to pass inputs, like userID."
  - text: "body must return exactly one Text."
    correct: false
    why: "body returns any single view, and a VStack is one view containing several."
rubric:
  - Identifies the plain var that's mutated from an action.
  - Identifies the disk load in init.
  - Identifies the side effect in body.
  - Doesn't flag the let input or the VStack.
solution: |
  Three real problems:

  1. **`var isFollowing`** can't be changed from the button's closure; `self` is immutable inside `body`. Make it `@State private var isFollowing = false`.
  2. **Loading in `init`.** SwiftUI may create `ProfileView` values often, for example every time the parent's `body` runs. Each one would read from disk. Load the profile in a model or in `.task`, which Module 37 covers, and pass the result in.
  3. **Logging in `body`.** The log fires on every evaluation, not once per appearance, and at moments you don't control. Move it to `.onAppear { … }` or `.task { … }`.

  `let userID` is a normal input, and a `VStack` is a single view, so `body` is fine on that count.
````

````exercise
id: m34-l01-e6
type: explain
prompt: "A teammate coming from UIKit asks: \"If body builds new Text and Button values on every update, why doesn't the text field lose what I've typed every time?\" Answer in a few sentences, using the word identity."
code: |
  struct SearchView: View {
      @State private var query = ""
      @State private var showsFilters = false

      var body: some View {
          VStack {
              TextField("Search", text: $query)
              Toggle("Filters", isOn: $showsFilters)
          }
      }
  }
rubric:
  - Says that view values are descriptions, not the on-screen elements.
  - Says SwiftUI keeps the on-screen element and its state between updates and matches new descriptions to it.
  - Explains that the match uses identity (position in the hierarchy or an explicit id).
  - Mentions that a change of identity (different branch, new id) does reset state.
solution: |
  A sample answer: "The `TextField` value in `body` is only a description. SwiftUI keeps the real text field, and the state behind it, separately. Each time `body` runs, SwiftUI matches each view in the new description to the one already on screen by its identity, which is its position in the hierarchy or an explicit id. The text field is in the same place, so it's the same view, and what you typed survives. If you moved it into a different `if` branch, or changed its `.id(…)`, it would be a new view and would start empty."
````

## Summary

- UIKit is imperative: you create views and update each one, event by event. SwiftUI is declarative: `body` describes the screen for the current state, and SwiftUI changes the screen to match.
- The declarative style removes stale-view bugs because there's no per-event update step: every displayed value is computed from state.
- A view is a struct, a cheap description. Inputs are plain properties; values the view owns and changes are `@State` (in depth in Module 36).
- `body` can run many times at times you don't choose: keep it, and the view's initializer, cheap and free of side effects.
- `App` with `@main` is the entry point, `body: some Scene` lists scenes, and `WindowGroup` creates a window per scene with its own state.
- SwiftUI matches views across updates by identity: position in the hierarchy or an explicit id. State lives as long as identity; different `if` branches and changed ids start fresh.
