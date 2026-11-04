---
id: m22-l05
title: Target-action, delegation and the responder chain
description: How a tap reaches your code. You connect controls with target-action and with UIAction closures, write delegate protocols with weak references the way UIKit does, follow an unhandled event or a nil-targeted action up the responder chain from a view to the app delegate, and choose the right mechanism for each kind of communication.
module: m22
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l04]
objectives:
  - Connect a control event to a method with addTarget(_:action:for:) and to a closure with addAction(_:for:).
  - Pick the right UIControl.Event for buttons, switches, sliders and text fields.
  - Implement a UIKit delegate protocol and write your own delegate protocol with a weak delegate property.
  - Explain why delegate properties are weak and UIAction closures capture self weakly.
  - Trace the responder chain from a view to the app delegate and use a nil target to send an action up it.
  - Choose between target-action, closures and delegation for a given interaction.
terms:
  - term: Target-action
    definition: "A pattern where a control stores a target object and an action selector for an event, and calls that method when the event happens. Set up with addTarget(_:action:for:) or in Interface Builder."
  - term: UIAction
    definition: "An object that runs a closure. Controls accept it with addAction(_:for:) (iOS 14) and buttons with UIButton(configuration:primaryAction:) (iOS 15)."
  - term: Delegation
    definition: "A pattern where an object hands some decisions and notifications to another object, its delegate, through a protocol. UIKit delegates are weak references."
  - term: Responder chain
    definition: "The linked list of UIResponder objects (views, view controllers, window, window scene, application, app delegate) that unhandled events and nil-targeted actions travel along, following each responder's next property."
  - term: First responder
    definition: "The responder that receives an event first: for touches, the view hit-testing found; for keyboard input and editing actions, the object that became first responder, such as the active text field."
mastery:
  - Write target-action and UIAction versions of the same button handler.
  - Write a UITextFieldDelegate that moves focus from one field to the next and submits on the last one.
  - Declare a custom delegate protocol for a reusable view and adopt it in a view controller.
  - Show, with a plain-Swift model, that a strong delegate leaks and a weak one doesn't.
  - Name the next responder of a view, a root view, a view controller, a window, a window scene and the application.
resources: [uikit-target-action, uikit-responder-chain, uikit-uitextfielddelegate, swift-book-protocols, swift-book-arc]
cards:
  - id: m22-l05-c1
    front: Does a UIControl retain the target you pass to addTarget(_:action:for:)?
    back: "No. Apple: the control does not retain the target; it's your responsibility to keep a strong reference to it while it's attached. The action method must be @objc (or @IBAction)."
  - id: m22-l05-c2
    front: Why are delegate properties weak?
    back: "The delegate usually owns the object (a view controller owns its text field). A strong reference back would form a cycle and neither would be released. UIKit declares them as weak var delegate, and your protocols need AnyObject to allow weak."
  - id: m22-l05-c3
    front: The responder chain from a subview upwards?
    back: "View → superview … → the view controller's root view → the view controller → (its view's superview, or) the window → the UIWindowScene → UIApplication → the app delegate, if it's a UIResponder."
  - id: m22-l05-c4
    front: What happens when a control's target is nil?
    back: "UIKit searches the responder chain for an object that implements the action method and calls it there. If nobody implements it, nothing happens (UIApplication.sendAction(_:to:from:for:) returns false)."
  - id: m22-l05-c5
    front: Why does a custom delegate protocol for a UIKit view need @MainActor?
    back: "The view controller that adopts it is main-actor isolated. In Swift 6 mode its methods can't satisfy a nonisolated protocol requirement, so the protocol (like UIKit's own delegate protocols) is declared @MainActor."
---

## The idea in one sentence

Controls report what the user did with **target-action** (or its closure form, `UIAction`), views and system objects ask questions and report changes through **delegates**, and anything nobody handles directly travels up the **responder chain** until some object does.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run. The rules come from Apple's documentation (`UIControl`, "Responding to control-based events using target-action", "Using responders and the responder chain to handle events", `UIResponder.next`), read in November 2026. The plain-Swift models of delegation, weak references and the responder chain were compiled and run.

## Target-action

`UIControl` is the base class of buttons, switches, sliders, segmented controls, steppers, date pickers and text fields. Apple: "Controls use the target-action mechanism to report user interactions to your app. Instead of writing code to track touch events, you write action methods to respond to control-specific events."

You give the control three things: a **target** (the object to call), an **action** (which method) and the **events** to react to:

```swift ios
import UIKit

final class PlayerSettingsViewController: UIViewController {
    private let volumeSlider = UISlider()
    private let muteSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        volumeSlider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)
        muteSwitch.addTarget(self, action: #selector(muteToggled), for: .valueChanged)
    }

    @objc private func volumeChanged(_ sender: UISlider) {
        print("volume: \(sender.value)")
    }

    @objc private func muteToggled() {
        print("muted: \(muteSwitch.isOn)")
    }
}
```

- `#selector(volumeChanged(_:))` names the method. The method must be "available in the Objective-C runtime" (The Swift Programming Language), so it's marked `@objc`. Target-action is an Objective-C mechanism; `@IBAction` (lesson 6) implies `@objc` too.
- Action methods take one of three shapes: no parameters, the sender, or the sender and the `UIEvent`. Use the specific control type for `sender` when you need its value, as `volumeChanged(_:)` does.
- **The control doesn't retain the target.** Apple: "It is your responsibility to maintain a strong reference to the target object while it is attached to a control." Here the controller owns the slider, so that's automatic.
- You can call `addTarget(_:action:for:)` several times to attach several targets or events; adding the same pair twice is safe.

### Which event?

| Control | Usual event | Meaning |
| --- | --- | --- |
| `UIButton` | `.primaryActionTriggered` or `.touchUpInside` | Tapped. The first is "a semantic action triggered by buttons"; the second is "a touch-up event in the control where the finger is inside the bounds" |
| `UISwitch`, `UISlider`, `UISegmentedControl`, `UIStepper`, `UIDatePicker` | `.valueChanged` | The value changed |
| `UITextField` | `.editingChanged` | The text changed while editing |

### UIAction: the closure form

Since iOS 14, `addAction(_:for:)` attaches a `UIAction`, which runs a closure. No selector, no `@objc`, and the code sits where the control is configured:

```swift ios
import UIKit

final class SearchViewController: UIViewController {
    private let queryField = UITextField()
    private let searchButton = UIButton(configuration: .filled())
    private var latestQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        queryField.addAction(UIAction { [weak self] _ in
            self?.latestQuery = self?.queryField.text ?? ""
        }, for: .editingChanged)

        searchButton.addAction(UIAction(title: "Search") { [weak self] _ in
            self?.search()
        }, for: .primaryActionTriggered)
    }

    private func search() {
        print("searching for \(latestQuery)")
    }
}
```

Two details from the documentation. Actions "are uniqued based on their identifier, and subsequent actions with the same identifier replace previously added actions", so you can replace a handler by giving it a fixed `identifier`. And `UIButton(configuration:primaryAction:)` copies the action's title or image into the button, which lesson 4's counter exercise used.

### Why [weak self]

The controller owns the button, the button owns its actions, and each action owns its closure. If the closure captured `self` strongly, the controller would own itself through the button, and it would never be released (Module 13). `[weak self]` breaks the loop. The same rule doesn't apply to `addTarget`: the control holds the target weakly already.

## Delegation

A delegate is an object that another object consults or informs. UIKit uses delegates where a control needs more than "something happened": a text field asks "should I return?", "should I start editing?", and reports "editing ended". `UITextField`'s property is declared:

```swift illustrative
weak var delegate: (any UITextFieldDelegate)? { get set }
```

`weak`, optional, and typed as a protocol. Every method in `UITextFieldDelegate` is optional; you implement the ones you need.

### Adopting a UIKit delegate

A login form that moves from the email field to the password field when the user taps Return, and submits from the last field:

```swift ios
import UIKit

final class LoginViewController: UIViewController {
    private let emailField = UITextField()
    private let passwordField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        emailField.returnKeyType = .next
        passwordField.returnKeyType = .go
        passwordField.isSecureTextEntry = true
        emailField.delegate = self
        passwordField.delegate = self
    }

    private func logIn() {
        print("logging in")
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            logIn()
        }
        return false
    }
}
```

- `emailField.delegate = self` is the step people forget. Without it the methods exist but nobody calls them.
- The conformance lives in an extension. Apple suggests this to separate event handling from the rest of the controller.
- `textFieldShouldReturn(_:)` returns whether the field should do "its default behavior for the return button". The first parameter tells you **which** field is asking, so one delegate serves several fields; `===` compares identities.
- `becomeFirstResponder()` moves the keyboard focus; `resignFirstResponder()` gives it up and hides the keyboard. More on first responders below.

### Writing your own delegate protocol

A reusable star-rating view shouldn't know which screen it's on. It reports through a delegate:

```swift ios
import UIKit

@MainActor
protocol RatingViewDelegate: AnyObject {
    func ratingView(_ ratingView: RatingView, didSelect rating: Int)
}

final class RatingView: UIView {
    weak var delegate: RatingViewDelegate?
    private(set) var rating = 0

    func select(_ newRating: Int) {
        rating = newRating
        delegate?.ratingView(self, didSelect: newRating)
    }
}

final class ReviewViewController: UIViewController {
    private let ratingView = RatingView()

    override func viewDidLoad() {
        super.viewDidLoad()
        ratingView.delegate = self
        view.addSubview(ratingView)
    }
}

extension ReviewViewController: RatingViewDelegate {
    func ratingView(_ ratingView: RatingView, didSelect rating: Int) {
        print("rated \(rating) stars")
    }
}
```

The conventions are UIKit's:

- **`AnyObject`** restricts the protocol to classes, which `weak` requires.
- **`weak var delegate`**, optional, because the controller owns the view.
- **The sender is the first parameter** (`ratingView(_:didSelect:)`), so one object can be the delegate of several views. Names use `did`/`will`/`should`, like UIKit's.
- **`@MainActor`** on the protocol. `ReviewViewController` is main-actor isolated, like every `UIViewController`. In Swift 6 mode a main-actor method can't satisfy a requirement of a nonisolated protocol, so the simplest fix is to declare the protocol `@MainActor`, the same as `UITextFieldDelegate`. Module 21, lesson 3 introduced the attribute; Module 29 explains isolation and the other ways out.

### Delegation without UIKit

The pattern is plain Swift. This model has a quantity picker that asks its delegate whether zero is allowed and reports every change:

```swift
protocol QuantityPickerDelegate: AnyObject {
    func quantityPicker(_ picker: QuantityPicker, didChangeTo quantity: Int)
    func quantityPickerShouldAllowZero(_ picker: QuantityPicker) -> Bool
}

final class QuantityPicker {
    weak var delegate: QuantityPickerDelegate?
    private(set) var quantity = 1

    func increment() {
        quantity += 1
        delegate?.quantityPicker(self, didChangeTo: quantity)
    }

    func decrement() {
        if quantity == 1, delegate?.quantityPickerShouldAllowZero(self) != true {
            print("picker: staying at 1")
            return
        }
        quantity -= 1
        delegate?.quantityPicker(self, didChangeTo: quantity)
    }
}

final class CartLine: QuantityPickerDelegate {
    let picker = QuantityPicker()

    init() {
        picker.delegate = self
    }

    func quantityPicker(_ picker: QuantityPicker, didChangeTo quantity: Int) {
        print("cart: quantity is now \(quantity)")
    }

    func quantityPickerShouldAllowZero(_ picker: QuantityPicker) -> Bool {
        false
    }
}

let line = CartLine()
line.picker.increment()
line.picker.decrement()
line.picker.decrement()
```

```output
cart: quantity is now 2
cart: quantity is now 1
picker: staying at 1
```

`delegate?.quantityPickerShouldAllowZero(self) != true` treats "no delegate" (`nil`) the same as "no": the picker picks the safe default when nobody answers. UIKit's "should" methods work the same way when you don't implement them.

### Why weak: proving it

`CartLine` owns its picker, and the picker points back to `CartLine`. Here's what each kind of back-reference does to that pair:

```swift
final class Picker {
    weak var weakDelegate: AnyObject?
    var strongDelegate: AnyObject?
}

final class Screen {
    let name: String
    let picker = Picker()

    init(name: String) {
        self.name = name
    }

    deinit {
        print("\(name) released")
    }
}

func open(_ name: String, strong: Bool) {
    let screen = Screen(name: name)
    if strong {
        screen.picker.strongDelegate = screen
    } else {
        screen.picker.weakDelegate = screen
    }
    print("\(name) closing")
}

open("weak screen", strong: false)
open("strong screen", strong: true)
print("done")
```

```output
weak screen closing
weak screen released
strong screen closing
done
```

The strong version is never released: the screen owns the picker, the picker owns the screen. In a real app that's a whole view controller and its views leaking each time the user opens the screen. Module 13's tools (the memory graph) find exactly this.

## The responder chain

Apple: "Apps receive and handle events using responder objects." A responder is any `UIResponder`: every `UIView` (including `UIWindow`), every `UIViewController`, `UIScene` and `UIApplication`. Each responder has a `next` property, and together they form the **responder chain**. UIKit sends an event to the most appropriate responder, the **first responder**, and anything it doesn't handle moves along `next`.

### Who is next

From `UIResponder.next` and the responder chain article:

| Responder | Its `next` |
| --- | --- |
| A view that isn't a controller's root view | Its superview |
| A view controller's root view | The view controller |
| A view controller | Its view's superview; if its view is a window's root view, the window; if it was presented, the presenting view controller |
| `UIWindow` | Its `UIWindowScene` |
| `UIWindowScene` | `UIApplication` |
| `UIApplication` | The app delegate, "but only if the app delegate is an instance of UIResponder and isn't a view, view controller, or the app object itself" |

That's why lesson 1's `AppDelegate` and `SceneDelegate` inherit from `UIResponder`.

```plaintext
text field → stack view → root view → LoginViewController → UIWindow → UIWindowScene → UIApplication → AppDelegate
```

You can walk it yourself:

```swift ios
import UIKit

let controller = UIViewController()
let card = UIView()
let button = UIButton(configuration: .filled())
controller.view.addSubview(card)
card.addSubview(button)

var responder: UIResponder? = button
while let current = responder {
    print(type(of: current))
    responder = current.next
}
```

This block is type-checked, not run. By the rules above it would print `UIButton`, `UIView` (the card), `UIView` (the root view) and `UIViewController`, and stop there: this controller isn't in a window yet, so its view has no superview.

### Which events use it

- **Touches** go first to the view that hit-testing found: "the deepest subview that contains the specified touch". If that view doesn't handle them, the default `touchesBegan(_:with:)` "forwards the message up the responder chain."
- **Keyboard input, editing commands, shake motion** go to the object that is first responder: usually the active text field, which became first responder when tapped or when you called `becomeFirstResponder()`.
- **Action messages** aren't events, "but they may still take advantage of the responder chain": see the next section.
- Gesture recognizers get touches before their view; Module 27 covers them.

### nil-targeted actions

Pass `nil` as the target and the control searches the chain. Apple: "When the target object of a control is nil, UIKit starts from the target object and traverses the responder chain until it finds an object that implements the appropriate action method." The editing menu works this way: Copy and Paste send `copy(_:)` and `paste(_:)` with no target, and whatever responder implements them handles them.

You can use it to let a deeply nested view trigger something on a controller it doesn't know about:

```swift ios
import UIKit

final class CheckoutViewController: UIViewController {
    @objc func placeOrder(_ sender: Any?) {
        print("placing order")
    }
}

final class OrderSummaryView: UIView {
    private let orderButton = UIButton(configuration: .filled())

    override init(frame: CGRect) {
        super.init(frame: frame)
        orderButton.addTarget(nil, action: #selector(CheckoutViewController.placeOrder(_:)), for: .touchUpInside)
        addSubview(orderButton)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }
}

@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
```

- `addTarget(nil, …)`: when the button is tapped, UIKit searches the responder chain for an object that implements `placeOrder(_:)`. The checkout controller that contains the summary view is on that chain, so it handles the tap, and the view never needed a reference to it.
- `sendAction(_:to:from:for:)` with `to: nil` sends to the first responder; it returns `false` if "no object in the responder chain handled the message". Sending `resignFirstResponder` this way dismisses the keyboard without knowing which field has it. (Within one view, `view.endEditing(true)` does the same.)

Use nil targets sparingly. They're decoupled, but also invisible: nothing at the call site says who handles the action, and if nobody does, nothing happens and nothing fails.

### A model of the chain

```swift
final class Responder {
    let name: String
    let handles: Set<String>
    var next: Responder?

    init(_ name: String, handles: Set<String> = []) {
        self.name = name
        self.handles = handles
    }
}

func send(_ action: String, from first: Responder) {
    var path: [String] = []
    var current: Responder? = first
    while let responder = current {
        path.append(responder.name)
        if responder.handles.contains(action) {
            print("\(action): " + path.joined(separator: " → ") + " ✓")
            return
        }
        current = responder.next
    }
    print("\(action): " + path.joined(separator: " → ") + " (unhandled)")
}

let field = Responder("textField", handles: ["paste"])
let stack = Responder("stackView")
let root = Responder("rootView")
let controller = Responder("CheckoutVC", handles: ["placeOrder"])
let window = Responder("window")
let scene = Responder("windowScene")
let app = Responder("application")
let appDelegate = Responder("AppDelegate", handles: ["openSettings"])

field.next = stack
stack.next = root
root.next = controller
controller.next = window
window.next = scene
scene.next = app
app.next = appDelegate

send("paste", from: field)
send("placeOrder", from: field)
send("openSettings", from: stack)
send("share", from: root)
```

```output
paste: textField ✓
placeOrder: textField → stackView → rootView → CheckoutVC ✓
openSettings: stackView → rootView → CheckoutVC → window → windowScene → application → AppDelegate ✓
share: rootView → CheckoutVC → window → windowScene → application → AppDelegate (unhandled)
```

The last line is the silent failure mode: the action reaches the end of the chain and disappears.

## Choosing a mechanism

| You need | Use |
| --- | --- |
| A control reports a single kind of interaction | `UIAction` (or target-action, especially in older code and with `@IBAction`) |
| An object asks questions (`should…`) or reports several related events to one owner | A delegate protocol |
| A child reports one event to its parent, and you control both types | A closure property (`var onSelect: ((Int) -> Void)?`) or a delegate |
| A command that whoever is focused or in charge should handle | A nil-targeted action through the responder chain |
| Many unrelated objects need to hear about one change | Notifications or observation, in Module 26 |

## Common mistakes

> [!error] Forgetting to set the delegate
> You implement `textFieldShouldReturn(_:)` and nothing happens, because `textField.delegate = self` is missing (or the connection is missing in the storyboard). There's no error; nobody is calling you.

> [!error] A strong delegate property
> `var delegate: RatingViewDelegate?` without `weak` creates a cycle between the controller and its view. Declare the protocol `AnyObject` and the property `weak`.

> [!error] Capturing self strongly in a UIAction
> `UIAction { _ in self.save() }` inside a view controller ties the controller to its own button. Use `[weak self]` and `self?.save()`.

> [!error] A selector pointing at a non-@objc method
> `#selector` needs a method available to the Objective-C runtime, so the compiler rejects a plain Swift method. Mark it `@objc` (or `@IBAction`), or switch to `UIAction`.

> [!error] A custom delegate protocol without @MainActor
> In Swift 6 mode, a view controller's main-actor methods can't satisfy a nonisolated requirement, and the conformance fails to compile. Mark UI delegate protocols `@MainActor`, as UIKit does.

> [!error] Relying on a nil target that nobody handles
> The action silently goes nowhere. If the handler must exist, use a real target, a delegate or a closure.

## Exercises

````exercise
id: m22-l05-e1
type: prediction
prompt: "Using the lesson's responder chain model, what does this print?"
code: |
  final class Responder {
      let name: String
      let handles: Set<String>
      var next: Responder?
      init(_ name: String, handles: Set<String> = []) {
          self.name = name
          self.handles = handles
      }
  }

  func handler(for action: String, from first: Responder) -> String {
      var current: Responder? = first
      var steps = 0
      while let responder = current {
          if responder.handles.contains(action) {
              return "\(responder.name) after \(steps) step(s)"
          }
          steps += 1
          current = responder.next
      }
      return "nobody after \(steps) step(s)"
  }

  let button = Responder("button")
  let cell = Responder("cell", handles: ["delete"])
  let list = Responder("listView")
  let controller = Responder("InboxVC", handles: ["delete", "archive"])
  let window = Responder("window")
  button.next = cell
  cell.next = list
  list.next = controller
  controller.next = window

  print(handler(for: "delete", from: button))
  print(handler(for: "archive", from: button))
  print(handler(for: "delete", from: list))
  print(handler(for: "print", from: cell))
output: |
  cell after 1 step(s)
  InboxVC after 3 step(s)
  InboxVC after 1 step(s)
  nobody after 4 step(s)
hints:
  - "steps counts how many responders were passed without handling the action."
  - "The first responder that handles an action wins, even if one further up also handles it."
  - "From cell to the end of the chain there are four responders."
solution: |
  ```output
  cell after 1 step(s)
  InboxVC after 3 step(s)
  InboxVC after 1 step(s)
  nobody after 4 step(s)
  ```

  `delete` from the button stops at `cell`, the first responder that handles it; `InboxVC` never sees it. `archive` passes button, cell and list. Starting at `list`, `delete` skips `cell` because the chain only goes **up**. `print` passes cell, list, InboxVC and window, then runs out of responders: that's the silent "unhandled" case.
````

````exercise
id: m22-l05-e2
type: prediction
prompt: "A form view reports changes to a weak delegate. The delegate goes away halfway through. What does it print?"
code: |
  protocol FormDelegate: AnyObject {
      func formDidChange(_ value: String)
  }

  final class Form {
      weak var delegate: FormDelegate?
      func type(_ value: String) {
          if let delegate {
              delegate.formDidChange(value)
          } else {
              print("no delegate for \(value)")
          }
      }
  }

  final class Screen: FormDelegate {
      let name: String
      init(name: String) { self.name = name }
      func formDidChange(_ value: String) { print("\(name) got \(value)") }
      deinit { print("\(name) released") }
  }

  let form = Form()
  var screen: Screen? = Screen(name: "Profile")
  form.delegate = screen
  form.type("A")
  screen = nil
  form.type("B")
  print(form.delegate == nil)
output: |
  Profile got A
  Profile released
  no delegate for B
  true
hints:
  - "form.delegate is weak, so it doesn't keep the screen alive."
  - "Setting screen to nil removes the last strong reference."
solution: |
  ```output
  Profile got A
  Profile released
  no delegate for B
  true
  ```

  The only strong reference to the screen was the `screen` variable. Setting it to `nil` releases the screen (its `deinit` prints), and the weak `delegate` becomes `nil` automatically. The next call finds no delegate. That's the behavior UIKit relies on: a view never keeps its controller alive, and messages to a delegate that's gone aren't sent.
````

````exercise
id: m22-l05-e3
type: comprehension
prompt: "Your custom view declares `weak var delegate: PhotoPickerDelegate?` and the compiler says weak can't be applied to it. What's the fix?"
choices:
  - text: "Constrain the protocol to classes: protocol PhotoPickerDelegate: AnyObject (and mark it @MainActor for UIKit use)."
    correct: true
    why: "weak needs a class-bound type; AnyObject makes the protocol class-only."
  - text: "Remove weak; delegates should be strong."
    correct: false
    why: "That creates a cycle between the view and the controller that owns it."
  - text: "Make the property unowned instead."
    correct: false
    why: "unowned also needs a class-bound type, and it crashes if the delegate is gone. A delegate is optional by nature."
  - text: "Make the delegate a struct."
    correct: false
    why: "Structs can't be referenced weakly at all, and the delegate is usually a view controller."
solution: |
  **Add `AnyObject` to the protocol.** `weak` only applies to class instances, and a protocol that structs could adopt isn't known to be a class. `protocol PhotoPickerDelegate: AnyObject` fixes that. For a protocol adopted by view controllers, add `@MainActor` as well, as UIKit does for its delegate protocols.
````

````exercise
id: m22-l05-e4
type: find-errors
prompt: "The Return key doesn't move to the next field, and the screen is never released after it's closed. Mark every real problem."
code: |
  protocol AddressFormDelegate: AnyObject {
      func addressFormDidFinish(_ form: AddressFormView)
  }

  final class AddressFormView: UIView {
      var delegate: AddressFormDelegate?
      let streetField = UITextField()
      let cityField = UITextField()
      let doneButton = UIButton(configuration: .filled())
  }

  final class AddressViewController: UIViewController, UITextFieldDelegate {
      private let form = AddressFormView()

      override func viewDidLoad() {
          super.viewDidLoad()
          form.delegate = self
          form.doneButton.addAction(UIAction { _ in
              self.save()
          }, for: .primaryActionTriggered)
      }

      func textFieldShouldReturn(_ textField: UITextField) -> Bool {
          form.cityField.becomeFirstResponder()
          return false
      }

      private func save() {}
  }
choices:
  - text: "The text fields' delegate is never set to the controller, so textFieldShouldReturn(_:) is never called."
    correct: true
  - text: "delegate in AddressFormView is strong, creating a cycle with the controller."
    correct: true
  - text: "The UIAction closure captures self strongly, another cycle through the button."
    correct: true
  - text: "AddressFormDelegate isn't @MainActor, so a view controller can't conform to it in Swift 6 mode."
    correct: true
  - text: "AddressViewController doesn't conform to AddressFormDelegate, so form.delegate = self doesn't compile."
    correct: true
  - text: "UIViewController subclasses can't adopt UITextFieldDelegate in the class declaration; it must be an extension."
    correct: false
    why: "An extension is a style choice Apple suggests, not a requirement."
rubric:
  - I found the missing streetField.delegate = self.
  - I found the strong delegate property.
  - I found the strong capture in the UIAction.
  - I found the missing @MainActor and the missing conformance.
solution: |
  Five problems:

  1. **`form.streetField.delegate = self` is missing**, so Return does nothing special.
  2. **`var delegate`** should be `weak var delegate`: the controller owns the form.
  3. **`UIAction { _ in self.save() }`** captures the controller strongly through the button. Use `[weak self]` and `self?.save()`.
  4. **`AddressFormDelegate` needs `@MainActor`.** A main-actor view controller can't satisfy a nonisolated requirement in Swift 6 mode.
  5. **The controller never adopts `AddressFormDelegate`** or implements `addressFormDidFinish(_:)`, so `form.delegate = self` doesn't type-check.

  Problems 2 and 3 are each enough to leak the screen.

  ```swift ios
  import UIKit

  @MainActor
  protocol AddressFormDelegate: AnyObject {
      func addressFormDidFinish(_ form: AddressFormView)
  }

  final class AddressFormView: UIView {
      weak var delegate: AddressFormDelegate?
      let streetField = UITextField()
      let cityField = UITextField()
      let doneButton = UIButton(configuration: .filled())
  }

  final class AddressViewController: UIViewController {
      private let form = AddressFormView()

      override func viewDidLoad() {
          super.viewDidLoad()
          form.delegate = self
          form.streetField.delegate = self
          form.cityField.delegate = self
          form.doneButton.addAction(UIAction { [weak self] _ in
              self?.save()
          }, for: .primaryActionTriggered)
      }

      private func save() {}
  }

  extension AddressViewController: UITextFieldDelegate {
      func textFieldShouldReturn(_ textField: UITextField) -> Bool {
          if textField === form.streetField {
              form.cityField.becomeFirstResponder()
          } else {
              textField.resignFirstResponder()
              save()
          }
          return false
      }
  }

  extension AddressViewController: AddressFormDelegate {
      func addressFormDidFinish(_ form: AddressFormView) {
          save()
      }
  }
  ```
````

````exercise
id: m22-l05-e5
type: solve
prompt: |
  Write the delegate side of a download progress component, in plain Swift.

  - A protocol `DownloadDelegate` (class-only) with `download(_:didProgress:)` taking a percentage `Int`, and `downloadDidFinish(_:)`.
  - A class `Download` with a `name`, a weak `delegate`, and a method `simulate(steps:)` that reports progress `100 * i / steps` for `i` in `1...steps`, then finishes.
  - A class `DownloadsScreen` that conforms, sets itself as the delegate of a download it owns, and prints what it receives.

  ```swift
  let screen = DownloadsScreen()
  screen.download.simulate(steps: 4)
  ```

  should print:

  ```plaintext
  report.pdf: 25%
  report.pdf: 50%
  report.pdf: 75%
  report.pdf: 100%
  report.pdf finished
  ```
starter: |
  // your code
hints:
  - "protocol DownloadDelegate: AnyObject { … }"
  - "The delegate methods take the Download as their first parameter, so the screen can read download.name."
  - "Set download.delegate = self in DownloadsScreen's init."
rubric:
  - The protocol is class-bound and the delegate property is weak and optional.
  - Delegate methods take the sender as the first parameter.
  - Download calls the delegate with optional chaining and doesn't know DownloadsScreen.
  - The output matches.
solution: |
  ```swift
  protocol DownloadDelegate: AnyObject {
      func download(_ download: Download, didProgress percent: Int)
      func downloadDidFinish(_ download: Download)
  }

  final class Download {
      let name: String
      weak var delegate: DownloadDelegate?

      init(name: String) {
          self.name = name
      }

      func simulate(steps: Int) {
          for i in 1...steps {
              delegate?.download(self, didProgress: 100 * i / steps)
          }
          delegate?.downloadDidFinish(self)
      }
  }

  final class DownloadsScreen: DownloadDelegate {
      let download = Download(name: "report.pdf")

      init() {
          download.delegate = self
      }

      func download(_ download: Download, didProgress percent: Int) {
          print("\(download.name): \(percent)%")
      }

      func downloadDidFinish(_ download: Download) {
          print("\(download.name) finished")
      }
  }

  let screen = DownloadsScreen()
  screen.download.simulate(steps: 4)
  ```

  ```output
  report.pdf: 25%
  report.pdf: 50%
  report.pdf: 75%
  report.pdf: 100%
  report.pdf finished
  ```

  `Download` knows only the protocol, so any object can listen, and a test can use a fake delegate that records calls. The sender parameter lets one screen manage several downloads. In a UIKit app the protocol would also be `@MainActor`, and real progress would arrive asynchronously (Module 30).
````

````exercise
id: m22-l05-e6
type: design
prompt: |
  For each interaction, choose target-action/UIAction, a delegate protocol, a closure property, or a nil-targeted action, and justify it in one sentence.

  1. A Save button in a form.
  2. A reusable calendar view that asks its owner which dates can be selected and reports the selected date.
  3. A small custom cell view that reports "favorite tapped" to its parent, which you also wrote.
  4. A keyboard shortcut for "New note" that should work on whichever screen is in front.
  5. A slider that updates a preview while it moves.
rubric:
  - Button and slider use UIAction or target-action, with the right events.
  - The calendar uses a delegate because it both asks and reports.
  - The cell uses a closure property or a delegate, with a reason.
  - The shortcut uses the responder chain (nil target).
solution: |
  1. **UIAction on `.primaryActionTriggered`** (or `addTarget`): one control, one interaction.
  2. **A delegate protocol**: it needs answers ("can this date be selected?") and reports events, several related methods with one owner.
  3. **A closure property** (`var onFavorite: (() -> Void)?`): one event, both sides yours, less ceremony than a protocol. Capture `[weak self]` where you assign it. A delegate is also fine if more events are coming.
  4. **A nil-targeted action**: the front-most screen that implements the method handles it, and screens that don't, ignore it. Menus and keyboard commands in UIKit work this way.
  5. **UIAction on `.valueChanged`**: the slider sends it continuously while the thumb moves.
````

## Summary

- Controls report interactions with target-action: `addTarget(_:action:for:)` with an `@objc` method, or `addAction(_:for:)` with a `UIAction` closure. Controls don't retain targets; closures need `[weak self]`.
- Use `.primaryActionTriggered`/`.touchUpInside` for buttons, `.valueChanged` for switches and sliders, `.editingChanged` for text fields.
- Delegates are `weak`, optional, typed as a class-bound protocol, and receive the sender as the first parameter. Set the delegate, or nothing gets called. UI delegate protocols you write are `@MainActor`.
- The responder chain runs view → superview → root view → view controller → window → window scene → application → app delegate. Unhandled touches and nil-targeted actions travel it; if nobody handles an action, it's dropped silently.
- Pick the simplest mechanism that fits: actions for controls, delegates for ask-and-report relationships, closures for one-off callbacks, the responder chain for commands meant for whoever is in front.
