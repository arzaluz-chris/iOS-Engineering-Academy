---
id: m38-l04
title: Focus and the keyboard
description: "On a phone, the keyboard covers half the screen and the return key is the main way to move through a form. You track which field has focus with @FocusState and an enum, move focus in code, label the return key with submitLabel, handle it with onSubmit, work out the focus order (including fields that are sometimes hidden) in plain Swift, dismiss the keyboard by clearing focus or by scrolling, and add a keyboard toolbar."
module: m38
order: 4
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l03]
objectives:
  - Track and set keyboard focus with @FocusState, using a Bool for one field and an optional enum for several.
  - Move focus to the next field when the user presses return, with onSubmit and submitLabel.
  - Compute focus order and the return key's label in plain Swift, including conditionally visible fields.
  - Dismiss the keyboard by setting focus to nil, with scrollDismissesKeyboard, and from a keyboard toolbar.
  - Tell keyboard focus apart from VoiceOver focus and know where AccessibilityFocusState fits.
terms:
  - term: "@FocusState"
    definition: "A property wrapper (iOS 15) that SwiftUI updates as focus moves between views bound with focused(_:) or focused(_:equals:). Setting it moves focus; setting it to nil or false removes focus, which dismisses the keyboard."
  - term: Submit label
    definition: "The title of the keyboard's return key, set with submitLabel(_:): .next, .done, .go, .join, .search, .send, .continue, .return or .route."
  - term: onSubmit
    definition: "A modifier (iOS 15) that runs an action when the user submits a value, for text fields the return key. Placed on a container, it handles submissions from every field inside."
  - term: Focus order
    definition: "The sequence in which the return key moves through fields. It should match the visual order, skip fields that aren't shown, and end in the screen's main action."
  - term: Accessibility focus
    definition: "The element VoiceOver is on. It's separate from keyboard focus and is read and set with @AccessibilityFocusState (iOS 15)."
mastery:
  - Bind several fields to one @FocusState enum and move focus from code.
  - Make return go to the next visible field, and on the last field submit the form or jump to the first invalid one.
  - Choose the return key's label per field.
  - Offer three ways to put the keyboard away and say which one each screen needs.
  - Move VoiceOver focus to an error message with @AccessibilityFocusState.
resources: [swiftui-focusstate, swiftui-state, swift-book-enumerations, uikit-uitextfielddelegate, hig]
cards:
  - id: m38-l04-c1
    front: "@FocusState with an enum: the pieces?"
    back: "enum Field: Hashable { case name, email }, @FocusState private var focused: Field?, and .focused($focused, equals: .name) on each field. Reading it tells you which field has focus; assigning moves focus; nil removes it and hides the keyboard."
  - id: m38-l04-c2
    front: Why must a multi-field focus state be optional?
    back: "Focus can be nowhere. Apple: 'the wrapped value must be either an optional or a Boolean.' nil means no field in the group has focus."
  - id: m38-l04-c3
    front: How does return move to the next field?
    back: "Give each field .submitLabel(.next) (the last one .done, .go or .join), and in one .onSubmit on the form, switch on the focused field and assign the next one. On the last field, validate and submit, or focus the first invalid field."
  - id: m38-l04-c4
    front: Three ways to dismiss the keyboard in SwiftUI?
    back: "Set the focus state to nil (or false). Let scrolling do it with .scrollDismissesKeyboard(.immediately or .interactively). Add a Done button in a ToolbarItemGroup(placement: .keyboard) that clears focus."
  - id: m38-l04-c5
    front: Keyboard focus vs accessibility focus?
    back: "Keyboard focus is where typing goes (@FocusState). Accessibility focus is the element VoiceOver is reading (@AccessibilityFocusState). Moving one doesn't move the other; to announce a new error, move accessibility focus to it."
---

## The idea in one sentence

Focus is **state**: one optional enum says which field the keyboard is typing into, and moving through a form is just assigning the next case.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so keyboard behavior wasn't observed on a device. Behavior comes from Apple's pages for `FocusState`, `focused(_:equals:)`, `submitLabel(_:)`, `SubmitLabel`, `onSubmit(of:_:)`, `submitScope(_:)`, `scrollDismissesKeyboard(_:)`, `ScrollDismissesKeyboardMode`, `defaultFocus(_:_:priority:)`, `SafeAreaRegions.keyboard`, `ToolbarItemPlacement.keyboard` and `AccessibilityFocusState`, read in November 2026. The focus-order logic is plain Swift, compiled and run with Swift 6.3. UIKit's version of this (`becomeFirstResponder`, `textFieldShouldReturn`) was in Module 22, lesson 5.

## One field: a Bool

For a single field, a `Bool` is enough:

```swift ios
import SwiftUI

struct SearchBar: View {
    @State private var query = ""
    @FocusState private var isSearching: Bool

    var body: some View {
        HStack {
            TextField("Search recipes", text: $query)
                .focused($isSearching)
                .submitLabel(.search)
                .textFieldStyle(.roundedBorder)
            if isSearching {
                Button("Cancel") {
                    query = ""
                    isSearching = false
                }
            }
        }
        .padding()
        .animation(.snappy, value: isSearching)
    }
}
```

- **`.focused($isSearching)`** binds the field's focus to the property. When the user taps the field, SwiftUI sets it to `true`; when focus leaves, `false`.
- **Reading it** drives the UI: the Cancel button only exists while the user is typing.
- **Writing it** moves focus. `isSearching = false` takes focus away, and with it the keyboard. Apple's `FocusState` page: setting the value to `false` or `nil` removes focus, and "you can also use this to remove focus from a `TextField` and thereby dismiss the keyboard."

## Several fields: an optional enum

With more than one field, use an enum with one case per field, and make the property optional. Apple: "To allow for cases where focus is completely absent from a view tree, the wrapped value must be either an optional or a Boolean."

```swift ios
import SwiftUI

struct LoginForm: View {
    enum Field: Hashable {
        case email, password
    }

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    let logIn: (String, String) -> Void

    var body: some View {
        Form {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
        }
        .onSubmit {
            switch focusedField {
            case .email:
                focusedField = .password
            case .password:
                submit()
            case nil:
                break
            }
        }
    }

    private func submit() {
        if email.isEmpty {
            focusedField = .email
        } else if password.isEmpty {
            focusedField = .password
        } else {
            focusedField = nil
            logIn(email, password)
        }
    }
}
```

Line by line:

- **`.focused($focusedField, equals: .email)`**: when this field gains focus, `focusedField` becomes `.email`; assigning `.email` moves focus here.
- **`.submitLabel(.next)` and `.submitLabel(.go)`** set the return key's title. The choice tells the user what return will do: go to the next field, or perform the action. `SubmitLabel` offers `.continue`, `.done`, `.go`, `.join`, `.next`, `.return`, `.route`, `.search` and `.send`.
- **One `.onSubmit` on the `Form`.** Apple's `onSubmit` page: a text field triggers the action "when the user hits the hardware or software return key," and "you may set this action on an individual view or an entire view hierarchy." Handling it once, switching on the focused field, keeps the order in one place.
- **`submitScope()`** on a field stops its return key from reaching an `onSubmit` higher up. Apple's example is a Tags field inside a login form: return there shouldn't log in.
- **`submit()`** follows Apple's `FocusState` example: if a field is empty, focus moves there; otherwise the keyboard goes away and the login starts.

> [!warning] Two fields, one value
> Binding two fields to the same case is a bug. Apple: "if the app programmatically sets the value to `name`, SwiftUI chooses the first candidate," and "emits a runtime warning in this case, since the repeated binding is likely a programmer error." One case per field.

## Focus order as logic

Real forms have fields that come and go: a "Company" field only for business accounts, an "Apartment" field after the user taps "Add apartment." The return key must skip what isn't there, and the last visible field should get the action label. That's logic worth taking out of the view:

```swift
enum Field: String, CaseIterable {
    case name, email, company, password
}

enum ReturnKey: String {
    case next, join
}

struct SignUpFocus {
    var isBusiness: Bool

    /// The fields on screen, in visual order.
    var visibleFields: [Field] {
        Field.allCases.filter { $0 != .company || isBusiness }
    }

    func field(after field: Field) -> Field? {
        guard let index = visibleFields.firstIndex(of: field) else { return nil }
        let next = visibleFields.index(after: index)
        return next < visibleFields.endIndex ? visibleFields[next] : nil
    }

    func returnKey(for field: Field) -> ReturnKey {
        self.field(after: field) == nil ? .join : .next
    }
}

for isBusiness in [false, true] {
    let focus = SignUpFocus(isBusiness: isBusiness)
    print(isBusiness ? "Business:" : "Personal:")
    for field in focus.visibleFields {
        let next = focus.field(after: field)?.rawValue ?? "submit"
        print("  \(field.rawValue) [\(focus.returnKey(for: field).rawValue)] → \(next)")
    }
}
```

```output
Personal:
  name [next] → email
  email [next] → password
  password [join] → submit
Business:
  name [next] → email
  email [next] → company
  company [next] → password
  password [join] → submit
```

- **`visibleFields`** is the single source for both what's drawn and the order. If the view draws fields from the same list, the order can't disagree with the screen.
- **`CaseIterable` order is declaration order**, so declare the cases in the order they appear.
- **The last visible field gets `.join`**, because return there creates the account.

What return does on the last field depends on whether the form is valid. Lesson 3's form model knows the errors; the return key only has to pick an action:

```swift
enum Field: String, CaseIterable {
    case name, email, password
}

enum ReturnAction: CustomStringConvertible {
    case moveFocus(to: Field)
    case submit
    case showErrors(focusing: Field)

    var description: String {
        switch self {
        case .moveFocus(let field): "move focus to \(field.rawValue)"
        case .submit: "submit"
        case .showErrors(let field): "show errors, focus \(field.rawValue)"
        }
    }
}

func returnAction(in field: Field, errors: [Field: String]) -> ReturnAction {
    let fields = Field.allCases
    if let index = fields.firstIndex(of: field), index + 1 < fields.count {
        return .moveFocus(to: fields[index + 1])
    }
    if let firstInvalid = fields.first(where: { errors[$0] != nil }) {
        return .showErrors(focusing: firstInvalid)
    }
    return .submit
}

print(returnAction(in: .name, errors: [.name: "Required."]))
print(returnAction(in: .password, errors: [.email: "Enter an email like name@example.com."]))
print(returnAction(in: .password, errors: [:]))
```

```output
move focus to email
show errors, focus email
submit
```

- **Return on an invalid field still moves on.** The name is empty, but pressing return on it goes to the email. Blocking the return key until a field is valid traps the user; errors appear when they try to submit (lesson 3).
- **Return on the last field is the submit button.** If something is wrong, focus jumps to the first invalid field, which is where the user's eyes and keyboard need to be.

## Putting it together

Here's a sign-up form with a conditional field, the return key, a keyboard toolbar with previous, next and Done, and keyboard dismissal on scroll:

```swift ios
import SwiftUI

struct BusinessSignUp: View {
    enum Field: Hashable, CaseIterable {
        case name, email, company, password
    }

    @State private var name = ""
    @State private var email = ""
    @State private var company = ""
    @State private var password = ""
    @State private var isBusiness = false
    @FocusState private var focusedField: Field?

    private var visibleFields: [Field] {
        Field.allCases.filter { $0 != .company || isBusiness }
    }

    private func field(offsetBy offset: Int, from field: Field) -> Field? {
        guard let index = visibleFields.firstIndex(of: field) else { return nil }
        let target = index + offset
        return visibleFields.indices.contains(target) ? visibleFields[target] : nil
    }

    private func submitLabel(for field: Field) -> SubmitLabel {
        self.field(offsetBy: 1, from: field) == nil ? .join : .next
    }

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Business account", isOn: $isBusiness)
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(submitLabel(for: .name))
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(submitLabel(for: .email))
                    if isBusiness {
                        TextField("Company", text: $company)
                            .textContentType(.organizationName)
                            .focused($focusedField, equals: .company)
                            .submitLabel(submitLabel(for: .company))
                    }
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .submitLabel(submitLabel(for: .password))
                }
            }
            .navigationTitle("Create account")
            .onSubmit {
                guard let current = focusedField else { return }
                if let next = field(offsetBy: 1, from: current) {
                    focusedField = next
                } else {
                    focusedField = nil
                    // validate and submit, as in lesson 3
                }
            }
            .onChange(of: isBusiness) { _, isOn in
                if !isOn && focusedField == .company {
                    focusedField = .password
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        if let current = focusedField {
                            focusedField = field(offsetBy: -1, from: current)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .accessibilityLabel("Previous field")
                    .disabled(focusedField.flatMap { field(offsetBy: -1, from: $0) } == nil)

                    Button {
                        if let current = focusedField {
                            focusedField = field(offsetBy: 1, from: current)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Next field")
                    .disabled(focusedField.flatMap { field(offsetBy: 1, from: $0) } == nil)

                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
}
```

- **`visibleFields`** drives the order, the submit labels and the arrows, the same way it did in the model.
- **`.onChange(of: isBusiness)`**: if the user turns off "Business account" while typing in Company, that field disappears. Focus moves to the next field instead of vanishing with it.
- **`ToolbarItemGroup(placement: .keyboard)`** puts buttons in a bar above the keyboard. The arrows are icon-only, so they get accessibility labels; they're disabled at the ends of the order.
- **"Done"** clears focus, which dismisses the keyboard.

## Putting the keyboard away

There are three ways, and most forms want more than one:

1. **Clear focus**: `focusedField = nil`, after submitting, from a Done button, or when an action starts.
2. **Scroll**: `scrollDismissesKeyboard(_:)` (iOS 16) sets what scrolling does. `ScrollDismissesKeyboardMode` has `.automatic`, `.immediately` ("Dismiss the keyboard as soon as scrolling starts"), `.interactively` ("Enable people to interactively dismiss the keyboard as part of the scroll operation") and `.never`. Apple: "By default, a `TextEditor` is interactive while other kinds of scrollable content always dismiss the keyboard on a scroll when linked against iOS 16 or later." `.interactively` lets the keyboard follow the finger down, which feels natural in a long form.
3. **A keyboard toolbar** with Done, as above. Number pads have no return key, so a field with `.keyboardType(.numberPad)` needs this or another way out.

You'll see code that dismisses the keyboard when the user taps anywhere on the background, with an `onTapGesture` on the form. It works, but that tap gesture also sees taps meant for the form's controls (lesson 1). Prefer scrolling and Done.

### The keyboard and layout

SwiftUI moves content out from under the keyboard for you. Apple's `ignoresSafeArea(_:edges:)` page: "By default, the SwiftUI layout system sizes and positions views to avoid certain safe areas. This ensures that system content like the software keyboard or edges of the device don't obstruct your views." The keyboard is a safe-area region, `SafeAreaRegions.keyboard`. To let a background image stay put while the keyboard is up, apply `.ignoresSafeArea(.keyboard)` to that background only.

### Starting with the keyboard up

To open a screen with a field already focused, assign the focus state when the screen appears, for example `.onAppear { focusedField = .name }`. iOS 17 also added `defaultFocus(_:_:priority:)`, which "defines a region of the window in which default focus is evaluated"; Apple's example is a window with two fields, and its behavior for text fields on iPhone wasn't checked for this lesson. Either way, only do it when typing is clearly the next step, like a search screen or a "New list" sheet. On a screen people often just read, a keyboard that pops up hides half the content.

## Keyboard focus is not VoiceOver focus

VoiceOver has its own cursor: the element being read. Moving keyboard focus doesn't move it, and a VoiceOver user may not notice that an error appeared at the top of the form. `@AccessibilityFocusState` (iOS 15) is the accessibility counterpart of `@FocusState`. Apple: "Setting the property's value programmatically has the reverse effect, causing accessibility focus to move to whichever accessibility element is associated with the updated value."

```swift ios
import SwiftUI

struct PaymentForm: View {
    @State private var cardNumber = ""
    @State private var errorMessage: String?
    @AccessibilityFocusState private var isErrorFocused: Bool
    let pay: @MainActor (String) async -> String?

    var body: some View {
        Form {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .accessibilityFocused($isErrorFocused)
            }
            TextField("Card number", text: $cardNumber)
                .keyboardType(.numberPad)
                .textContentType(.creditCardNumber)
            Button("Pay") {
                Task {
                    errorMessage = await pay(cardNumber)
                }
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                isErrorFocused = true
            }
        }
    }
}
```

When payment fails, the banner appears and VoiceOver moves to it and reads it. Use this sparingly: taking the VoiceOver cursor away from where the user put it is disorienting unless something important happened. Lesson 5 covers the rest of VoiceOver.

## Common mistakes

> [!error] A non-optional enum focus state
> `@FocusState private var focusedField: Field` has no value for "nothing focused." Apple requires an optional or a `Bool`. Declare `Field?`.

> [!error] The same case on two fields
> Copying a field and forgetting to change `equals: .email` means setting `.email` focuses the first one, and SwiftUI logs a runtime warning. One case per field.

> [!error] Every field labeled Done
> If return moves to the next field, label it `.next`. A Done key that moves on (or a Next key that submits) makes the user hesitate before every press.

> [!error] A number pad with no way out
> `.numberPad` and `.decimalPad` have no return key. Without a keyboard toolbar or scroll dismissal, the keyboard stays up and covers the Continue button.

> [!error] Focus left on a field that disappeared
> Hiding a field while it's focused leaves the user typing into nothing visible, or drops the keyboard unexpectedly. Move focus first, as `onChange(of: isBusiness)` does.

## Exercises

````exercise
id: m38-l04-e1
type: prediction
prompt: "An address form shows the Apartment field only when the user taps \"Add apartment.\" What does this print?"
code: |
  enum Field: String, CaseIterable {
      case street, apartment, city, postcode
  }

  struct AddressFocus {
      var hasApartment: Bool

      var visibleFields: [Field] {
          Field.allCases.filter { $0 != .apartment || hasApartment }
      }

      func field(after field: Field) -> Field? {
          guard let index = visibleFields.firstIndex(of: field) else { return nil }
          let next = visibleFields.index(after: index)
          return next < visibleFields.endIndex ? visibleFields[next] : nil
      }
  }

  let without = AddressFocus(hasApartment: false)
  let with = AddressFocus(hasApartment: true)
  print(without.field(after: .street)?.rawValue ?? "submit")
  print(with.field(after: .street)?.rawValue ?? "submit")
  print(with.field(after: .postcode)?.rawValue ?? "submit")
  print(without.field(after: .apartment)?.rawValue ?? "submit")
output: |
  city
  apartment
  submit
  submit
hints:
  - "Look at what firstIndex(of:) returns for a field that isn't visible."
solution: |
  ```output
  city
  apartment
  submit
  submit
  ```

  Without an apartment, street is followed by city; with one, by apartment. Postcode is last in both. The last line asks for the field after `.apartment` in the form that doesn't show it: `firstIndex(of:)` is `nil`, so the function returns `nil`, printed as "submit." In the view that can't happen as long as the hidden field can't hold focus, which is why `onChange` moves focus away before a field disappears. If you wanted a hidden field to behave differently, this is the function to change and test.
````

````exercise
id: m38-l04-e2
type: prediction
prompt: "The return-key logic from the lesson with a four-field form. What does it print?"
code: |
  enum Field: String, CaseIterable {
      case title, servings, time, notes
  }

  enum ReturnAction: CustomStringConvertible {
      case moveFocus(to: Field)
      case submit
      case showErrors(focusing: Field)

      var description: String {
          switch self {
          case .moveFocus(let field): "move focus to \(field.rawValue)"
          case .submit: "submit"
          case .showErrors(let field): "show errors, focus \(field.rawValue)"
          }
      }
  }

  func returnAction(in field: Field, errors: [Field: String]) -> ReturnAction {
      let fields = Field.allCases
      if let index = fields.firstIndex(of: field), index + 1 < fields.count {
          return .moveFocus(to: fields[index + 1])
      }
      if let firstInvalid = fields.first(where: { errors[$0] != nil }) {
          return .showErrors(focusing: firstInvalid)
      }
      return .submit
  }

  let errors: [Field: String] = [.time: "Required.", .servings: "Between 1 and 24."]
  print(returnAction(in: .time, errors: errors))
  print(returnAction(in: .notes, errors: errors))
  print(returnAction(in: .notes, errors: [.notes: "Too long."]))
output: |
  move focus to notes
  show errors, focus servings
  show errors, focus notes
hints:
  - "A dictionary has no order; the function searches Field.allCases in order."
solution: |
  ```output
  move focus to notes
  show errors, focus servings
  show errors, focus notes
  ```

  Return in `time` isn't the last field, so it moves on regardless of errors. Return in `notes` is the submit: there are errors, and the first invalid field in **declaration order** is `servings`, not `time`, even though `time` was written first in the dictionary literal. In the last call the only error is on `notes` itself, so focus stays there.
````

````exercise
id: m38-l04-e3
type: comprehension
prompt: "Why does Apple require a @FocusState used with focused(_:equals:) to be optional (or the Bool form)?"
choices:
  - text: "Because focus can be in none of the bound fields, and the property needs a value for that: nil."
    correct: true
    why: "Apple: 'To allow for cases where focus is completely absent from a view tree, the wrapped value must be either an optional or a Boolean.'"
  - text: "Because enums can't conform to Hashable."
    correct: false
    why: "Enums without associated values are Hashable automatically."
  - text: "Because SwiftUI stores focus in UserDefaults."
    correct: false
    why: "Focus is view state; nothing is persisted."
  - text: "Because optionals are faster to compare."
    correct: false
    why: "Performance isn't the reason."
solution: |
  **Focus can be nowhere.** When the keyboard is down, no field has focus, so the property needs a value meaning "none." With an optional enum that's `nil`; with the `Bool` form it's `false`. Assigning that value is also how you dismiss the keyboard.
````

````exercise
id: m38-l04-e4
type: fill-in
prompt: "Complete the two-field form: return in the name field moves to the email field; return in the email field dismisses the keyboard and saves."
code: |
  struct NewContact: View {
      enum Field { case name, email }

      @State private var name = ""
      @State private var email = ""
      @[[1]] private var focused: Field?

      var body: some View {
          Form {
              TextField("Name", text: $name)
                  .focused($focused, equals: .name)
                  .[[2]](.next)
              TextField("Email", text: $email)
                  .focused($focused, equals: .email)
                  .submitLabel(.done)
          }
          .[[3]] {
              if focused == .name {
                  focused = .email
              } else {
                  focused = [[4]]
                  save()
              }
          }
      }

      func save() { }
  }
blanks:
  - id: "1"
    answers: ["FocusState"]
  - id: "2"
    answers: ["submitLabel"]
  - id: "3"
    answers: ["onSubmit"]
  - id: "4"
    answers: ["nil"]
hints:
  - "An enum without associated values is Hashable, which focused(_:equals:) requires."
solution: |
  `@FocusState` tracks which field has focus; `.submitLabel(.next)` titles the return key; `.onSubmit` on the form handles return from either field; assigning `nil` removes focus, which dismisses the keyboard before saving.
````

````exercise
id: m38-l04-e5
type: find-errors
prompt: "This sign-in screen's focus handling has problems. Which are real?"
code: |
  struct SignIn: View {
      enum Field: Hashable { case email, password, code }

      @State private var email = ""
      @State private var password = ""
      @State private var code = ""
      @State private var focused: Field?

      var body: some View {
          Form {
              TextField("Email", text: $email)
                  .submitLabel(.done)
              SecureField("Password", text: $password)
                  .submitLabel(.done)
              TextField("One-time code", text: $code)
                  .keyboardType(.numberPad)
          }
          .onSubmit {
              focused = .password
          }
      }
  }
choices:
  - text: "focused is @State and no field uses .focused, so assigning it does nothing."
    correct: true
    why: "Use @FocusState and bind each field with .focused($focused, equals: …)."
  - text: "onSubmit always moves to the password, even from the password field, so return never signs in."
    correct: true
    why: "Switch on the focused field: email → password, password → code or submit."
  - text: "The email field's return key says Done but should move on."
    correct: true
    why: "Use .next on fields that move to another field."
  - text: "The number pad has no return key and nothing else dismisses the keyboard."
    correct: true
    why: "Add a keyboard toolbar with Done, or scroll dismissal, or move on automatically when the code is complete."
  - text: "SecureField can't have a submit label."
    correct: false
    why: "submitLabel(_:) applies to SecureField as well."
rubric:
  - Notices the @State instead of @FocusState and the missing focused bindings.
  - Notices that onSubmit doesn't depend on the current field.
  - Flags the misleading submit labels.
  - Flags the number pad without a way out.
solution: |
  Four problems. A corrected version:

  ```swift ios
  import SwiftUI

  struct SignIn: View {
      enum Field: Hashable { case email, password, code }

      @State private var email = ""
      @State private var password = ""
      @State private var code = ""
      @FocusState private var focused: Field?

      var body: some View {
          NavigationStack {
              Form {
                  TextField("Email", text: $email)
                      .textContentType(.username)
                      .focused($focused, equals: .email)
                      .submitLabel(.next)
                  SecureField("Password", text: $password)
                      .textContentType(.password)
                      .focused($focused, equals: .password)
                      .submitLabel(.next)
                  TextField("One-time code", text: $code)
                      .keyboardType(.numberPad)
                      .textContentType(.oneTimeCode)
                      .focused($focused, equals: .code)
              }
              .onSubmit {
                  switch focused {
                  case .email: focused = .password
                  case .password: focused = .code
                  case .code, nil: break
                  }
              }
              .toolbar {
                  ToolbarItemGroup(placement: .keyboard) {
                      Spacer()
                      Button("Done") { focused = nil }
                  }
              }
          }
      }
  }
  ```

  `@FocusState` and `.focused` make focus real state. `onSubmit` switches on where the user is. The labels say Next where return moves on. The code field gets `.oneTimeCode` (iOS can fill it from a message) and the toolbar's Done is the way out of the number pad.
````

````exercise
id: m38-l04-e6
type: solve
prompt: |
  Write the logic behind the keyboard toolbar's arrows. Given the visible fields in order, write:

  - `neighbor(of field: Field, offset: Int, in fields: [Field]) -> Field?`, the field `offset` positions away (−1 for previous, +1 for next), or `nil` past either end or when `field` isn't in the list.
  - `arrows(for field: Field, in fields: [Field]) -> String`, which returns `"↑↓"`, `"↑ "`, `" ↓"` or `"  "`, showing which arrows are enabled.

  For the fields `[.name, .email, .password]`, print each field's raw value and its arrows, and then the arrows for `.company`, which isn't visible.
starter: |
  enum Field: String {
      case name, email, company, password
  }

  func neighbor(of field: Field, offset: Int, in fields: [Field]) -> Field? {
      // your code
      nil
  }

  func arrows(for field: Field, in fields: [Field]) -> String {
      // your code
      "  "
  }
hints:
  - "fields.indices.contains(target) checks both ends."
  - "Build the string from two characters: \"↑\" or \" \", then \"↓\" or \" \"."
rubric:
  - neighbor handles both ends and a field that isn't in the list.
  - arrows uses neighbor for both directions.
  - Prints four lines, including the hidden field.
solution: |
  ```swift
  enum Field: String {
      case name, email, company, password
  }

  func neighbor(of field: Field, offset: Int, in fields: [Field]) -> Field? {
      guard let index = fields.firstIndex(of: field) else { return nil }
      let target = index + offset
      return fields.indices.contains(target) ? fields[target] : nil
  }

  func arrows(for field: Field, in fields: [Field]) -> String {
      let up = neighbor(of: field, offset: -1, in: fields) == nil ? " " : "↑"
      let down = neighbor(of: field, offset: 1, in: fields) == nil ? " " : "↓"
      return up + down
  }

  let visible: [Field] = [.name, .email, .password]
  for field in visible + [.company] {
      print("\(field.rawValue): [\(arrows(for: field, in: visible))]")
  }
  ```

  ```output
  name: [ ↓]
  email: [↑↓]
  password: [↑ ]
  company: [  ]
  ```

  The first field can only go down, the last only up, the middle both. A field that isn't visible has no neighbors, so both arrows are disabled. In the view, `.disabled(neighbor(…) == nil)` on each button uses the same function, which keeps the toolbar consistent with the return key.
````

## Summary

- `@FocusState` is focus as state: a `Bool` for one field, an optional enum for several, `.focused($state, equals: .case)` on each field. Assigning moves focus; `nil` or `false` removes it and the keyboard.
- Label the return key with `submitLabel` (`.next` while there's a next field, an action label on the last), and handle it once with `onSubmit` on the form.
- Compute focus order from the list of visible fields, in plain Swift, and move focus away from a field before hiding it.
- Put the keyboard away by clearing focus, with `scrollDismissesKeyboard(.interactively)`, and from a keyboard toolbar; number pads need one of the last two.
- SwiftUI avoids the keyboard safe area by default; `.ignoresSafeArea(.keyboard)` opts a background out.
- VoiceOver focus is separate. `@AccessibilityFocusState` moves it, for important changes only.
