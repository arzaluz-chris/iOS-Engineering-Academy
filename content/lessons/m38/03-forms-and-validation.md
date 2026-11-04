---
id: m38-l03
title: Forms and validation
description: "A sign-up screen is mostly rules: what's required, what's well formed, what the server still has to confirm. You lay out data entry with Form and Section, write the rules as plain Swift values you can test, decide when an error is allowed to appear, show it next to the field in words, choose between disabling the submit button and explaining on submit, and check a username against the server while the user types, cancelling checks that are no longer wanted."
module: m38
order: 3
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l02, m37-l03]
objectives:
  - Build a data-entry screen with Form, Section, headers and footers, and the right keyboard and content type for each field.
  - Model validation rules and a form's state in plain Swift, with one error message per field.
  - Decide when an error is visible (after the field is left or after a submit attempt) and show it inline, in words.
  - Choose between disabling submit and validating on submit, and always disable it while submitting.
  - Run asynchronous validation with .task(id:), debounced, ignoring cancelled and stale results.
terms:
  - term: Form
    definition: "A SwiftUI container (iOS 13) for grouping controls used for data entry. On iOS it renders its sections as a grouped list, with each control styled for that context."
  - term: Validation rule
    definition: "A check on one value that either passes or produces a message for the user. Modeled as plain data (a message and a predicate) so it can be listed, combined and tested without UI."
  - term: Touched field
    definition: "A field the user has visited and left. Showing errors only for touched fields (or after a submit attempt) avoids scolding the user before they've typed."
  - term: Debounce
    definition: "Waiting until input has paused for a short time before acting on it. With .task(id:), each change cancels the previous task, so a sleep at the start of the task debounces for free."
  - term: Stale result
    definition: "An answer for input the user has already changed, such as an availability check for \"chris\" arriving after they typed \"christian\". It must be discarded, not shown."
mastery:
  - Lay out a sign-up form with sections, a footer with help text, and fields with appropriate keyboards and content types.
  - Write rules for required, minimum length, contains a digit and email shape, and a form that reports the first failing rule per field.
  - Show an error for a field only after it's been left or after a submit attempt, as text below the field.
  - Explain when a disabled submit button helps and when it hides the reason from the user.
  - Debounce a username availability check with .task(id:) and Task.sleep, and treat cancellation as "no result."
resources: [swiftui-managing-ui-state, swift-task, swift-cancellationerror, swift-book-enumerations, swift-book-closures, hig]
cards:
  - id: m38-l03-c1
    front: Why model validation rules outside the view?
    back: "A rule is a message plus a predicate; a form is values plus rules. In plain Swift they can be listed, reused across fields and screens, and unit tested without SwiftUI. The view only asks the form for the error to show."
  - id: m38-l03-c2
    front: When should a field's error appear?
    back: "After the user has left the field (it's 'touched') or after they tried to submit. Not on the first keystroke into an empty field. Once visible, the error can update live as they fix it."
  - id: m38-l03-c3
    front: Disable the submit button or validate on submit?
    back: "Disabling is fine for short forms where what's missing is obvious. For longer ones, keep it enabled: on tap, mark the attempt, show every error and move focus to the first invalid field. Always disable it while the request is in flight."
  - id: m38-l03-c4
    front: "How does .task(id: username) debounce a check?"
    back: "Each change of username cancels the running task and starts a new one. Start the task with try await Task.sleep(for: .milliseconds(…)): if the user keeps typing, the sleep throws CancellationError and no request is made."
  - id: m38-l03-c5
    front: What does a cancelled availability check show?
    back: "Nothing new. Cancellation means the input changed, so the result is stale. Catch it and leave the status for the newer task to set, instead of showing an error."
---

## The idea in one sentence

**Validation is a function from the form's values to messages**: write it in plain Swift, and let the view decide only *when* to show each message and where.

> [!note] About this lesson's code
> The rules, the form model and the asynchronous check are plain Swift, compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Behavior comes from Apple's pages for `Form`, `Section`, `TextField`, `SecureField`, `disabled(_:)`, `keyboardType(_:)`, `textContentType(_:)`, `textInputAutocapitalization(_:)` and `autocorrectionDisabled(_:)`, read in November 2026. Loading states and `.task(id:)` cancellation were covered in Module 37, lesson 3; `@FocusState` gets its own lesson next.

## Form and Section

`Form` is "a container for grouping controls used for data entry, such as in settings or inspectors." On iOS it looks like a grouped `List`, and controls inside it adapt: a `Picker` becomes a row that opens a menu or a list, a `Toggle` gets a trailing switch, labels line up. You group related fields with `Section`, which takes a header and a footer.

```swift ios
import SwiftUI

struct ProfileForm: View {
    @State private var name = ""
    @State private var email = ""
    @State private var bio = ""
    @State private var diet = "None"
    @State private var newsletter = true
    let diets = ["None", "Vegetarian", "Vegan", "Gluten-free"]

    var body: some View {
        Form {
            Section("About you") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Bio")
            } footer: {
                Text("Shown on your public recipes.")
            }
            Section("Preferences") {
                Picker("Diet", selection: $diet) {
                    ForEach(diets, id: \.self) { Text($0) }
                }
                Toggle("Weekly newsletter", isOn: $newsletter)
            }
        }
    }
}
```

- **The field modifiers** tell the system what's being typed. `.keyboardType(.emailAddress)` shows a keyboard with @ and a period; `.textContentType(.emailAddress)` lets iOS offer the user's address from AutoFill; autocapitalization and autocorrection are off because they'd "fix" email addresses. For a password, `SecureField` with `.textContentType(.newPassword)` lets iOS suggest a strong password.
- **`TextField(_:text:axis: .vertical)`** grows vertically as the user types, within `lineLimit(3...6)`.
- **The footer** is where help text goes: what the field is for, or the rules it has to meet.

## Rules as values

A rule is a message and a test. Writing them as values, instead of `if` statements scattered through a view, lets you list a field's rules, reuse them across screens, and test them:

```swift
struct Rule {
    let message: String
    let isSatisfied: (String) -> Bool
}

extension Rule {
    static var required: Rule {
        Rule(message: "Required.") { !$0.allSatisfy(\.isWhitespace) }
    }

    static func minLength(_ length: Int) -> Rule {
        Rule(message: "At least \(length) characters.") { $0.count >= length }
    }

    static var containsDigit: Rule {
        Rule(message: "Include at least one number.") { $0.contains(where: \.isNumber) }
    }

    /// A shape check only. Whether the address exists is for the server to find out.
    static var emailShape: Rule {
        Rule(message: "Enter an email like name@example.com.") { value in
            let parts = value.split(separator: "@", omittingEmptySubsequences: false)
            return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".")
        }
    }
}

/// The message of the first rule that fails, or nil when all pass.
func firstError(in value: String, rules: [Rule]) -> String? {
    rules.first { !$0.isSatisfied(value) }?.message
}

let passwordRules: [Rule] = [.required, .minLength(8), .containsDigit]
for candidate in ["", "   ", "pasta", "spaghetti", "spaghetti7"] {
    print("\"\(candidate)\":", firstError(in: candidate, rules: passwordRules) ?? "OK")
}
for email in ["chris@example.com", "chris@", "chris.example.com", "@example.com", "chris@example."] {
    print(email + ":", firstError(in: email, rules: [.required, .emailShape]) ?? "OK")
}
```

```output
"": Required.
"   ": Required.
"pasta": At least 8 characters.
"spaghetti": Include at least one number.
"spaghetti7": OK
chris@example.com: OK
chris@: Enter an email like name@example.com.
chris.example.com: Enter an email like name@example.com.
@example.com: Enter an email like name@example.com.
chris@example.: Enter an email like name@example.com.
```

- **One message per field at a time.** `firstError` returns the first failing rule, so the order in the array is the order the user fixes things in: first "Required," then length, then the digit.
- **`allSatisfy(\.isWhitespace)`** treats a field of spaces as empty. An empty string also satisfies `allSatisfy`, so `.required` catches both.
- **The email check is deliberately loose.** Real addresses can be surprising, and no pattern tells you whether a mailbox exists. Check the shape to catch typos; let the server send a confirmation.
- **Messages say what to do**, not what went wrong in the abstract: "At least 8 characters," not "Invalid password."

## A form model

The form holds the values, knows each field's rules, and tracks the two facts that decide *visibility*: which fields the user has left, and whether they've tried to submit.

```swift
struct Rule {
    let message: String
    let isSatisfied: (String) -> Bool

    static var required: Rule { Rule(message: "Required.") { !$0.allSatisfy(\.isWhitespace) } }
    static func minLength(_ length: Int) -> Rule {
        Rule(message: "At least \(length) characters.") { $0.count >= length }
    }
    static var containsDigit: Rule {
        Rule(message: "Include at least one number.") { $0.contains(where: \.isNumber) }
    }
}

enum Field: CaseIterable {
    case name, password
}

struct SignUpForm {
    var name = ""
    var password = ""
    var touched: Set<Field> = []
    var submitAttempted = false

    func value(of field: Field) -> String {
        switch field {
        case .name: name
        case .password: password
        }
    }

    func rules(for field: Field) -> [Rule] {
        switch field {
        case .name: [.required]
        case .password: [.required, .minLength(8), .containsDigit]
        }
    }

    func error(for field: Field) -> String? {
        rules(for: field).first { !$0.isSatisfied(value(of: field)) }?.message
    }

    /// The error the screen shows: only for fields the user has left, or after a submit attempt.
    func visibleError(for field: Field) -> String? {
        guard submitAttempted || touched.contains(field) else { return nil }
        return error(for: field)
    }

    var isValid: Bool {
        Field.allCases.allSatisfy { error(for: $0) == nil }
    }

    var firstInvalidField: Field? {
        Field.allCases.first { error(for: $0) != nil }
    }
}

func show(_ form: SignUpForm, _ step: String) {
    let errors = Field.allCases.map { "\($0): \(form.visibleError(for: $0) ?? "-")" }
    let label = step + String(repeating: " ", count: max(0, 16 - step.count))
    print(label, errors.joined(separator: ", "), "| valid:", form.isValid)
}

var form = SignUpForm()
show(form, "empty")
form.name = "Christian"
show(form, "typed a name")
form.touched.insert(.name)
form.password = "pasta"
show(form, "typing password")
form.submitAttempted = true
show(form, "tapped Create")
print("focus goes to:", form.firstInvalidField.map { "\($0)" } ?? "nothing")
form.password = "pasta2026"
show(form, "fixed password")
```

```output
empty            name: -, password: - | valid: false
typed a name     name: -, password: - | valid: false
typing password  name: -, password: - | valid: false
tapped Create    name: -, password: At least 8 characters. | valid: false
focus goes to: password
fixed password   name: -, password: - | valid: true
```

Walk through the steps:

1. **Empty form.** It's invalid, but nothing is shown. The user hasn't done anything wrong yet.
2. **Typing a password.** "pasta" is too short, but the field hasn't been left, so the user isn't interrupted mid-word.
3. **Tapped Create.** `submitAttempted` makes every error visible at once, and `firstInvalidField` says where to put focus (next lesson).
4. **Fixed it.** Once errors are visible they update live, so the message disappears as soon as the password is good.

Because `rules(for:)` switches over every `Field`, adding a field without rules doesn't compile:

```swift no-compile switch must be exhaustive
struct Rule {
    let message: String
    let isSatisfied: (String) -> Bool
}

enum Field: CaseIterable {
    case name, password, email
}

func rules(for field: Field) -> [Rule] {
    switch field {
    case .name: [Rule(message: "Required.") { !$0.isEmpty }]
    case .password: [Rule(message: "At least 8 characters.") { $0.count >= 8 }]
    }
}
```

Swift 6.3 reports `error: switch must be exhaustive` and offers to add the missing case. That's the reason to avoid a `default:` here: the compiler reminds you that a new field needs a decision about its rules.

## Showing errors in the view

The view owns a `SignUpForm` in `@State` and asks it for visible errors. A field is touched when focus leaves it; `@FocusState` is the subject of the next lesson, and here it only reports which field the user left:

```swift ios
import SwiftUI

struct Rule {
    let message: String
    let isSatisfied: (String) -> Bool

    static var required: Rule { Rule(message: "Required.") { !$0.allSatisfy(\.isWhitespace) } }
    static func minLength(_ length: Int) -> Rule {
        Rule(message: "At least \(length) characters.") { $0.count >= length }
    }
}

enum Field: CaseIterable, Hashable {
    case name, password
}

struct SignUpForm {
    var name = ""
    var password = ""
    var touched: Set<Field> = []
    var submitAttempted = false

    func error(for field: Field) -> String? {
        switch field {
        case .name:
            [Rule.required].first { !$0.isSatisfied(name) }?.message
        case .password:
            [Rule.required, .minLength(8)].first { !$0.isSatisfied(password) }?.message
        }
    }

    func visibleError(for field: Field) -> String? {
        submitAttempted || touched.contains(field) ? error(for: field) : nil
    }

    var isValid: Bool { Field.allCases.allSatisfy { error(for: $0) == nil } }
}

struct SignUpView: View {
    @State private var form = SignUpForm()
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?
    let createAccount: @MainActor (String, String) async -> Void

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $form.name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                ErrorText(form.visibleError(for: .name))
            }
            Section {
                SecureField("Password", text: $form.password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                ErrorText(form.visibleError(for: .password))
            } footer: {
                Text("At least 8 characters.")
            }
            Section {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Create account")
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .onChange(of: focusedField) { previous, _ in
            if let previous {
                form.touched.insert(previous)
            }
        }
    }

    private func submit() {
        form.submitAttempted = true
        guard form.isValid else {
            focusedField = Field.allCases.first { form.error(for: $0) != nil }
            return
        }
        isSubmitting = true
        Task {
            await createAccount(form.name, form.password)
            isSubmitting = false
        }
    }
}

struct ErrorText: View {
    let message: String?

    init(_ message: String?) {
        self.message = message
    }

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}
```

- **`ErrorText`** renders nothing when there's no message, so the row disappears. When there is one, it's a label with an icon and words. Color alone isn't enough: some people can't tell red from the surrounding text, and VoiceOver doesn't read colors. Being a separate row right after the field, VoiceOver reads it next.
- **`.onChange(of: focusedField) { previous, _ in … }`** marks the field the user just left as touched. The iOS 17 form of `onChange` passes the old and new values.
- **`submit()`** sets `submitAttempted`, which reveals every error, and moves focus to the first invalid field. Only a valid form starts the request.
- **`.disabled(isSubmitting)`** prevents a second account from being created by a double tap while the first request is running. That one is never optional.

### Disable the button, or explain on submit?

The common alternative is `.disabled(!form.isValid)`: the button only works once everything is valid. It's a reasonable choice for a two-field form where what's missing is obvious. On a longer form it has a cost: a grayed-out button doesn't say *why*, and the user has to hunt for the field that's wrong. The approach above keeps the button enabled and answers the question when the user asks it, by tapping. Either way, the rules live in the model, and switching approaches is a one-line change in the view.

## Asynchronous validation

Some rules need the server: is this username taken? Asking on every keystroke would send "c", "ch", "chr"… and the answers could arrive out of order. Two tools from Module 37 solve it:

- **`.task(id: username)`** cancels the running task and starts a new one whenever `username` changes.
- **`Task.sleep` throws `CancellationError`** when its task is cancelled. Put a short sleep at the start of the task and you have a debounce: if the user types again within that time, the sleep throws and no request is sent.

Here is the logic in plain Swift, with a fake service. Cancelling the first task by hand plays the role of SwiftUI cancelling it when the id changes:

```swift
enum Availability: Equatable {
    case unknown, checking, available, taken, invalid
}

struct FakeUsernameService {
    let takenNames: Set<String>

    func isAvailable(_ name: String) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(30))      // the network
        return !takenNames.contains(name.lowercased())
    }
}

/// What .task(id: username) runs: wait for typing to pause, then ask the server.
/// Returns nil when the check was cancelled because the user kept typing.
func checkAvailability(of name: String, using service: FakeUsernameService) async -> Availability? {
    guard name.count >= 3 else { return .invalid }
    do {
        try await Task.sleep(for: .milliseconds(200))     // debounce
        let free = try await service.isAvailable(name)
        return free ? .available : .taken
    } catch {
        return nil
    }
}

let service = FakeUsernameService(takenNames: ["chris", "admin"])

// The user types "chris", then quickly adds "tian".
let first = Task { await checkAvailability(of: "chris", using: service) }
first.cancel()                                             // the id changed: SwiftUI cancels the old task
let second = Task { await checkAvailability(of: "christian", using: service) }

print("chris:", await first.value.map { "\($0)" } ?? "cancelled")
print("christian:", await second.value.map { "\($0)" } ?? "cancelled")
print("admin:", await checkAvailability(of: "Admin", using: service).map { "\($0)" } ?? "cancelled")
print("ab:", await checkAvailability(of: "ab", using: service).map { "\($0)" } ?? "cancelled")
```

```output
chris: cancelled
christian: available
admin: taken
ab: invalid
```

- **"chris" never reaches the server.** Its task is cancelled during the debounce, the sleep throws, and the function returns `nil`: no result, not an error. Showing "taken" for a name the user is no longer typing would be wrong.
- **Local rules first.** "ab" fails the length rule without a network request.
- **`nil` versus `.unknown`.** The function returns `nil` for "I have nothing to say," and the caller simply doesn't assign. The newer task will set the status.

The SwiftUI side is a `.task(id:)` that sets the status before and after:

```swift ios
import SwiftUI

enum Availability: Equatable {
    case unknown, checking, available, taken, invalid
}

protocol UsernameService: Sendable {
    func isAvailable(_ name: String) async throws -> Bool
}

struct UsernameField: View {
    @Binding var username: String
    @State private var availability = Availability.unknown
    let service: any UsernameService

    var body: some View {
        Section {
            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            switch availability {
            case .checking:
                ProgressView("Checking…")
            case .available:
                Label("Available", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            case .taken:
                Label("That username is taken.", systemImage: "xmark.circle")
                    .foregroundStyle(.red)
            case .invalid:
                Label("At least 3 characters.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
            case .unknown:
                EmptyView()
            }
        }
        .task(id: username) {
            guard !username.isEmpty else {
                availability = .unknown
                return
            }
            guard username.count >= 3 else {
                availability = .invalid
                return
            }
            availability = .checking
            do {
                try await Task.sleep(for: .milliseconds(400))
                let free = try await service.isAvailable(username)
                availability = free ? .available : .taken
            } catch is CancellationError {
                // The user kept typing; the next task sets the status.
            } catch {
                availability = .unknown
            }
        }
    }
}
```

- **The status is set inside the task**, which only runs for the current `username`. A cancelled task can't assign a stale result after `Task.sleep` or a service that respects cancellation throws. If your service ignores cancellation and returns anyway, add `guard !Task.isCancelled else { return }` after the `await`, as Module 37 did.
- **A network failure isn't "taken."** It goes back to `.unknown`, and the final submit asks the server again anyway: client-side checks are for the user's convenience; the server's answer at submit time is the one that counts.
- **400 ms** is a common debounce for typing, not a number from Apple. Shorter feels more responsive and sends more requests.

## Common mistakes

> [!error] Errors on the first keystroke
> Validating live from the start shows "Enter an email like name@example.com" after the user types "c". Wait until the field is left or a submit is attempted; then update live.

> [!error] Red text as the only signal
> A red border or red label color is invisible to VoiceOver and to many color-blind users. Show the message as text, with an icon, next to the field.

> [!error] A disabled button with no explanation
> On a long form, `.disabled(!form.isValid)` leaves the user guessing. If you disable, make sure every unmet requirement is visible; otherwise validate on tap and point to the first problem.

> [!error] Treating cancellation as a failure
> An availability check that catches every error and shows "Couldn't check username" flashes that message on every keystroke, because each keystroke cancels the previous check. Catch `CancellationError` separately and do nothing.

> [!error] Trusting client-side validation
> The app's rules are a convenience. The server must validate again: the app can be modified, an old version can have old rules, and a username can be taken between the check and the submit.

## Exercises

````exercise
id: m38-l03-e1
type: prediction
prompt: "Rules for a recipe title. What does this print?"
code: |
  struct Rule {
      let message: String
      let isSatisfied: (String) -> Bool
  }

  func firstError(in value: String, rules: [Rule]) -> String? {
      rules.first { !$0.isSatisfied(value) }?.message
  }

  let titleRules = [
      Rule(message: "Required.") { !$0.allSatisfy(\.isWhitespace) },
      Rule(message: "At most 20 characters.") { $0.count <= 20 },
      Rule(message: "Don't start with a number.") { !($0.first?.isNumber ?? false) },
  ]

  for title in ["Pancakes", " ", "3-minute eggs", "The very best banana bread", "1"] {
      print(firstError(in: title, rules: titleRules) ?? "OK")
  }
output: |
  OK
  Required.
  Don't start with a number.
  At most 20 characters.
  Don't start with a number.
hints:
  - "Only the first failing rule's message is printed."
  - "\"The very best banana bread\" has 26 characters."
solution: |
  ```output
  OK
  Required.
  Don't start with a number.
  At most 20 characters.
  Don't start with a number.
  ```

  "Pancakes" passes all three. A single space is all whitespace, so it's "Required." "3-minute eggs" is short enough but starts with a digit. The banana bread title fails the length rule first, which is checked before the digit rule. "1" isn't empty and is short, but starts with a number.
````

````exercise
id: m38-l03-e2
type: prediction
prompt: "The visibility rule from the form model. What does it print?"
code: |
  enum Field: CaseIterable {
      case email, password
  }

  struct FormState {
      var errors: [Field: String] = [:]
      var touched: Set<Field> = []
      var submitAttempted = false

      func visibleError(for field: Field) -> String? {
          guard submitAttempted || touched.contains(field) else { return nil }
          return errors[field]
      }
  }

  var state = FormState(errors: [.email: "Required.", .password: "Too short."])
  print(Field.allCases.map { state.visibleError(for: $0) ?? "-" })
  state.touched.insert(.email)
  print(Field.allCases.map { state.visibleError(for: $0) ?? "-" })
  state.errors[.email] = nil
  state.submitAttempted = true
  print(Field.allCases.map { state.visibleError(for: $0) ?? "-" })
output: |
  ["-", "-"]
  ["Required.", "-"]
  ["-", "Too short."]
hints:
  - "Nothing is visible until a field is touched or a submit is attempted."
solution: |
  ```output
  ["-", "-"]
  ["Required.", "-"]
  ["-", "Too short."]
  ```

  At first both fields have errors but neither is visible. Touching the email shows its error only. Then the email is fixed (its error is gone) and a submit is attempted, which reveals the password's error even though that field was never touched.
````

````exercise
id: m38-l03-e3
type: comprehension
prompt: "A username field uses .task(id: username) with a 400 ms Task.sleep before calling the server, and a catch block that sets availability = .error(\"Couldn't check\") for any error. What does the user see while typing \"christian\" quickly?"
choices:
  - text: "\"Couldn't check\" flickering, because each keystroke cancels the previous task, its sleep throws CancellationError, and the catch shows it as an error."
    correct: true
    why: "Cancellation is expected on every keystroke. Catch CancellationError separately and leave the status alone."
  - text: "Nothing until they stop typing, then the result for \"christian\"."
    correct: false
    why: "That's the intended behavior, which needs CancellationError handled separately."
  - text: "One server request per keystroke."
    correct: false
    why: "The sleep throws before the request for every cancelled task; only the last one reaches the server."
  - text: "The results for every prefix, in order."
    correct: false
    why: "Cancelled tasks never call the server."
solution: |
  **The error flickers.** The debounce works (only the last task reaches the server), but every cancelled task lands in the catch-all block. Add `catch is CancellationError { }` before the general `catch`, or check `Task.isCancelled` in the catch and return.
````

````exercise
id: m38-l03-e4
type: find-errors
prompt: "This checkout form has several validation and submission problems. Which are real?"
code: |
  struct CheckoutView: View {
      @State private var cardNumber = ""
      @State private var isPaying = false

      var isCardValid: Bool { cardNumber.count == 16 }

      var body: some View {
          Form {
              TextField("Card number", text: $cardNumber)
                  .border(isCardValid ? Color.clear : Color.red)
              Button("Pay") {
                  isPaying = true
                  Task {
                      await pay(cardNumber)
                      isPaying = false
                  }
              }
          }
      }

      func pay(_ number: String) async { }
  }
choices:
  - text: "The red border appears before the user types anything, and is the only sign of the problem."
    correct: true
    why: "Show errors after the field is left or after a submit attempt, as text with an icon."
  - text: "The Pay button stays enabled while paying, so a double tap can pay twice."
    correct: true
    why: "Add .disabled(isPaying)."
  - text: "Pay runs even when the card number is invalid."
    correct: true
    why: "Check validity first and show errors; never rely only on the border."
  - text: "The card number field has the default keyboard and no content type."
    correct: true
    why: ".keyboardType(.numberPad) and .textContentType(.creditCardNumber) help typing and AutoFill."
  - text: "Form can't contain a Button."
    correct: false
    why: "Buttons in forms are common; they render as tappable rows."
rubric:
  - Flags the premature, color-only error.
  - Flags the missing disabled state during payment.
  - Flags submitting without validating.
  - Mentions keyboard type and content type.
solution: |
  Four problems. A corrected version:

  ```swift ios
  import SwiftUI

  struct CheckoutView: View {
      @State private var cardNumber = ""
      @State private var isPaying = false
      @State private var submitAttempted = false

      var cardError: String? {
          let digits = cardNumber.filter(\.isNumber)
          return digits.count == 16 ? nil : "Enter the 16 digits on your card."
      }

      var body: some View {
          Form {
              Section {
                  TextField("Card number", text: $cardNumber)
                      .keyboardType(.numberPad)
                      .textContentType(.creditCardNumber)
                  if submitAttempted, let cardError {
                      Label(cardError, systemImage: "exclamationmark.circle")
                          .font(.footnote)
                          .foregroundStyle(.red)
                  }
              }
              Button("Pay") {
                  submitAttempted = true
                  guard cardError == nil else { return }
                  isPaying = true
                  Task {
                      await pay(cardNumber)
                      isPaying = false
                  }
              }
              .disabled(isPaying)
          }
      }

      func pay(_ number: String) async { }
  }
  ```

  The error appears only after a submit attempt, in words. The button validates before paying and is disabled while the payment runs. The field gets the number pad and the credit-card content type. (Real card validation also checks the Luhn digit and lengths other than 16; the payment provider's SDK usually does this for you.)
````

````exercise
id: m38-l03-e5
type: fill-in
prompt: "Complete the debounced check. Each change of the query cancels the previous task; a cancelled sleep must not show an error."
code: |
  .task(id: [[1]]) {
      do {
          try await Task.[[2]](for: .milliseconds(400))
          status = try await service.check(query) ? .available : .taken
      } catch is [[3]] {
          // superseded by a newer task
      } catch {
          status = .unknown
      }
  }
blanks:
  - id: "1"
    answers: ["query"]
  - id: "2"
    answers: ["sleep"]
  - id: "3"
    answers: ["CancellationError"]
hints:
  - "The task restarts when its id changes."
solution: |
  `.task(id: query)` restarts the work whenever the query changes. `Task.sleep(for:)` is the debounce: it throws `CancellationError` if the task is cancelled before it finishes, which is caught first and ignored. Any other error (the network) resets the status.
````

````exercise
id: m38-l03-e6
type: solve
prompt: |
  Write a rule set and a function for a **recipe servings** field, typed as text:

  - `servingsError(_ text: String) -> String?` returns `"Required."` for an empty or all-whitespace string, `"Enter a whole number."` when `Int(text)` is `nil`, `"Between 1 and 24."` when the number is outside 1…24, and `nil` otherwise.
  - Print the result (or `OK`) for `""`, `"four"`, `"0"`, `"6"`, `"25"` and `" 6"`, one per line, prefixed with the input in quotes.

  Use the `Rule` struct from the lesson so the order of the checks is the order of an array.
starter: |
  struct Rule {
      let message: String
      let isSatisfied: (String) -> Bool
  }

  func servingsError(_ text: String) -> String? {
      // your code
      nil
  }
hints:
  - "Int(\" 6\") is nil: Int(_:) doesn't skip spaces."
  - "The range rule can use Int(text).map { (1...24).contains($0) } ?? false, since it only runs after the whole-number rule passed."
rubric:
  - Uses an ordered array of rules and returns the first failing message.
  - Distinguishes empty, not a number and out of range.
  - Prints six lines with the inputs in quotes.
  - Notices that " 6" isn't a whole number for Int(_:), and says whether that's acceptable.
solution: |
  ```swift
  struct Rule {
      let message: String
      let isSatisfied: (String) -> Bool
  }

  func servingsError(_ text: String) -> String? {
      let rules = [
          Rule(message: "Required.") { !$0.allSatisfy(\.isWhitespace) },
          Rule(message: "Enter a whole number.") { Int($0) != nil },
          Rule(message: "Between 1 and 24.") { text in
              Int(text).map { (1...24).contains($0) } ?? false
          },
      ]
      return rules.first { !$0.isSatisfied(text) }?.message
  }

  for input in ["", "four", "0", "6", "25", " 6"] {
      print("\"\(input)\":", servingsError(input) ?? "OK")
  }
  ```

  ```output
  "": Required.
  "four": Enter a whole number.
  "0": Between 1 and 24.
  "6": OK
  "25": Between 1 and 24.
  " 6": Enter a whole number.
  ```

  Because the rules run in order and stop at the first failure, the range rule only sees strings that are already whole numbers. `" 6"` fails because `Int(_:)` doesn't skip whitespace. That's probably not what a user expects after an accidental space; trim the value before validating (and before saving), or better, use a `Stepper` or a `TextField` bound to an `Int` with a number format, so there's no text to validate at all.
````

## Summary

- `Form` and `Section` lay out data entry; headers group, footers explain. Give each field its keyboard type, content type, and capitalization and autocorrection settings.
- Write rules as values (a message and a predicate), keep them in plain Swift, and report the first failing rule per field.
- Show an error after the field is left or after a submit attempt, as text with an icon below the field; then update it live.
- Disable submit while the request runs, always. For validity, either disable with visible requirements, or validate on tap and move focus to the first problem.
- For server checks, `.task(id:)` plus a `Task.sleep` debounce sends one request after typing pauses. Treat `CancellationError` as "no result," and let the server have the final say at submit.
