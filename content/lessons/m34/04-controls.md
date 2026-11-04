---
id: m34-l04
title: Controls
description: "Text, Image, Button, Toggle, TextField, Picker, Slider, Stepper and Label: what each one needs, which initializer to pick, and what VoiceOver gets from it. Controls that change a value take a binding, so you first see what a binding is with a small model you can run. Then you build a settings form, give each control a good accessibility label, value or role, and keep the validation logic in plain Swift where you can test it."
module: m34
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l03, m27-l06]
objectives:
  - Explain what a binding is and why value controls take one with the $ prefix.
  - Choose between Text initializers and Image initializers based on localization and accessibility.
  - Create buttons with roles, system images and styles, and keep icon-only buttons readable by VoiceOver.
  - Use Toggle, TextField, Picker, Slider and Stepper with the right bindings, tags, ranges and keyboard settings.
  - Add accessibility labels, values and hints where the default isn't enough, and hide decorative images.
  - Keep form validation in a plain Swift type and drive disabled(_:) from it.
terms:
  - term: Binding
    definition: "A value that can read and write a piece of state owned by someone else. $name on a @State property produces one. Controls such as Toggle and TextField take a binding so they can both show and change the value."
  - term: Button role
    definition: "A ButtonRole value such as .destructive or .cancel that describes a button's purpose. The system uses it to style the button, for example in red in a menu."
  - term: Decorative image
    definition: "An image that carries no information. Create it with Image(decorative:) or hide it with accessibilityHidden(true) so VoiceOver skips it."
  - term: Accessibility value
    definition: "The current value of an element as VoiceOver reads it, separate from its label: \"Volume\" is the label, \"40 percent\" the value."
  - term: Tag
    definition: "A value attached to a picker option with tag(_:). The picker compares it with its selection binding, so the tag's type must match the selection's type."
mastery:
  - Write a Toggle, a TextField and a Picker bound to @State properties and explain each $.
  - Build an email field with the right keyboard, content type, capitalization and autocorrection settings.
  - Make an icon-only button that VoiceOver reads by its title.
  - Choose Image(decorative:), Image(_:) or an explicit accessibility label for a given image.
  - Write a validation type whose problems list drives the form's error text and its submit button's disabled state.
resources: [uikit-supporting-voiceover, uikit-accessibility-traits, accessibility-inspector, uikit-scaling-fonts, hig]
cards:
  - id: m34-l04-c1
    front: What does $isOn give a Toggle?
    back: "A Binding<Bool>: a way to read and a way to write a value that the view's @State owns. The toggle shows the current value and writes the new one when tapped; the view's body then re-runs."
  - id: m34-l04-c2
    front: Image(_:), Image(decorative:) and Image(systemName:), for accessibility?
    back: "Image(_:) is labeled: its name is also the localization key for its label. Image(decorative:) is ignored by accessibility. A meaningful SF Symbol should get an explicit label (or be part of a Label); a decorative one should be hidden."
  - id: m34-l04-c3
    front: How do you make an icon-only button that VoiceOver still names?
    back: "Give it a title and an icon, Button(\"Delete\", systemImage: \"trash\", action: …), and apply .labelStyle(.iconOnly). Apple: it still uses its title to describe the button in VoiceOver."
  - id: m34-l04-c4
    front: Why does a Picker sometimes not change its selection when you tap an option?
    back: "The options' tags don't match the selection's type, for example Int tags with a String selection. Tag each option with a value of exactly the selection's type, or use ForEach over Identifiable values whose id type matches."
  - id: m34-l04-c5
    front: Where should form validation live in SwiftUI?
    back: "In a plain Swift type (a struct with the form's values and computed problems and canSubmit). The view shows the problems and uses .disabled(!form.canSubmit). The type is testable without SwiftUI."
---

## The idea in one sentence

A control shows a value and lets the user change it, so controls that edit something take a **binding** to state you own, and each one comes with an accessibility label, value and traits that you check and fix where the defaults aren't enough.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode), not run. Control behavior and the accessibility quotes come from Apple's SwiftUI reference pages, read in November 2026. How VoiceOver actually reads each control wasn't checked on a device for this lesson; test your own screens with VoiceOver and Accessibility Inspector, as in Module 27. The binding model and the validation code are plain Swift and were run.

## Bindings, briefly

`Toggle("Wi-Fi", isOn: $isWiFiOn)` needs to do two things: show whether Wi-Fi is on, and change it when tapped. The view owns the value (`@State private var isWiFiOn = false`); the toggle doesn't. So the view hands the toggle a `Binding<Bool>`, which `$isWiFiOn` produces. Apple's `Binding` type has an initializer that shows what it is: `init(get:set:)`, a pair of closures.

A model of that, in plain Swift:

```swift
final class Storage<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void

    var wrappedValue: Value {
        get { get() }
        nonmutating set { set(newValue) }
    }
}

struct Toggle {
    let title: String
    let isOn: Binding<Bool>

    func tap() {
        isOn.wrappedValue.toggle()
    }

    var description: String {
        "\(title): \(isOn.wrappedValue ? "on" : "off")"
    }
}

// The screen's state: SwiftUI keeps this storage for an @State property.
let wifi = Storage(false)

// What $isWiFiOn hands to the toggle: a way to read and a way to write.
let wifiBinding = Binding(get: { wifi.value }, set: { wifi.value = $0 })
let toggle = Toggle(title: "Wi-Fi", isOn: wifiBinding)

print(toggle.description)
toggle.tap()
print(toggle.description, "| state:", wifi.value)
wifi.value = false
print(toggle.description)
```

```output
Wi-Fi: off
Wi-Fi: on | state: true
Wi-Fi: off
```

The toggle holds no Boolean of its own. Tapping it writes through the binding into the screen's storage, and when the screen changes the storage directly, the toggle reads the new value. One source of truth, two views of it. In SwiftUI the write also tells the framework that the state changed, so `body` runs again.

That's all you need to use controls. Module 36 covers `@Binding` properties in your own views, bindings to `@Observable` models with `@Bindable`, and where state should live.

## Text

```swift ios
import SwiftUI

struct TextExamples: View {
    let productName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")                 // a localization key
                .font(.title)
            Text(productName)                    // a variable: shown as is
                .font(.body)
            Text(verbatim: "v2.4 (build 117)")   // a literal that must not be translated
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Your subscription renews every month on the first day.")
                .lineLimit(2)
        }
    }
}
```

- **Literal vs variable.** Apple's `Text` page: a string literal is treated as a localization key; a `String` variable isn't localized; `Text(verbatim:)` bypasses localization for a literal. Module 27 set up localization; this is the SwiftUI side of it.
- **Text styles.** `.font(.title)`, `.body`, `.caption` and the rest are Dynamic Type text styles: they scale with the user's text size setting with no extra code. A fixed `.font(.system(size: 13))` doesn't scale by default, so prefer the styles.
- **Size.** Apple: "A text view always uses exactly the amount of space it needs." When it's given less, it wraps, tightens, scales or truncates; `lineLimit(_:)` caps the lines. Lesson 6 explains who decides the width.

VoiceOver reads a `Text`'s content. Nothing else to do for plain text.

## Image

```swift ios
import SwiftUI

struct ImageExamples: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(decorative: "confetti")                // ignored by VoiceOver
            Image("team-photo")                          // labeled by its name's localization
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Warning")           // a symbol that carries meaning
            Image(systemName: "sparkles")
                .accessibilityHidden(true)               // a symbol that's just decoration
        }
        .imageScale(.large)
    }
}
```

Apple's `Image` page splits images in two: those that are content ("use one of the initializers that takes a label parameter") and those "only present for aesthetic reasons", for which you "use an initializer with the `decorative` parameter; the accessibility systems ignore these images." `Image(_:bundle:)` is the labeled one: its name doubles as the localization key for the label, so name assets accordingly or add `accessibilityLabel(_:)`.

For SF Symbols created with `Image(systemName:)`, decide case by case. A symbol that means something on its own gets an explicit label; one next to text that already says the same thing gets hidden. Most of the time the right answer is a `Label`, below, which pairs the symbol with text.

`resizable()` is how you make an image fill a frame (lesson 2); SF Symbols also scale with the font and with `imageScale(_:)`.

## Button

```swift ios
import SwiftUI

struct ButtonExamples: View {
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 12) {
            Button("Save") { log.append("save") }
                .buttonStyle(.borderedProminent)

            Button("Delete draft", role: .destructive) { log.append("delete") }

            Button("Cancel", role: .cancel) { log.append("cancel") }

            Button("Share", systemImage: "square.and.arrow.up") { log.append("share") }
                .labelStyle(.iconOnly)

            Button {
                log.append("custom")
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .accessibilityHidden(true)
                    Text("Add to favorites")
                }
            }
        }
    }
}
```

- **Title and action.** `Button("Save") { … }` is the common form. The title is also what VoiceOver reads.
- **Roles.** `ButtonRole` "describes the purpose of a button". `.destructive` and `.cancel` exist since iOS 15; Apple's documentation adds `.confirm` and `.close` in iOS 26. Apple: "The system uses the button's role to style the button appropriately in every context", for example red for a destructive item in a menu. Use the role instead of coloring the button yourself: the meaning travels with it.
- **Styles.** `.buttonStyle(.bordered)` and `.borderedProminent` (iOS 15) are the standard looks; without a style, a button's look depends on where it is (plain text in a stack, a full-width row in a `List`).
- **Icon-only buttons.** Give the button a title *and* an image, then hide the title visually. Apple's `Button` page: applying `labelStyle(.iconOnly)` "will cause it to only visually display its icon, but still use its title to describe the button in accessibility modes like VoiceOver." A button whose label is only `Image(systemName: "square.and.arrow.up")` has no good name.
- **Custom labels.** The trailing `label:` closure takes any views. VoiceOver combines the text inside, so hide decorative images in it.

## Label

`Label("Archive", systemImage: "archivebox")` is a title plus an icon, laid out the standard way. Containers adapt it: a `List` row shows both, a toolbar may show only the icon. `.labelStyle(.iconOnly)` and `.titleOnly` choose explicitly. Use a `Label` whenever you'd otherwise put an image and a text side by side to say one thing; it keeps the text available for accessibility whatever is visible.

## A settings form

The value controls together, in a `Form`, which gives them the standard grouped look on iOS:

```swift ios
import SwiftUI

enum ReminderFrequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly
    var id: Self { self }
}

struct ReminderSettingsView: View {
    @State private var email = ""
    @State private var remindersOn = true
    @State private var frequency = ReminderFrequency.weekly
    @State private var copies = 1
    @State private var volume = 0.5

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Reminders") {
                Toggle("Send reminders", isOn: $remindersOn)

                Picker("Frequency", selection: $frequency) {
                    ForEach(ReminderFrequency.allCases) { option in
                        Text(option.rawValue.capitalized)
                    }
                }
                .disabled(!remindersOn)

                Stepper("Copies: \(copies)", value: $copies, in: 1...5)

                Slider(value: $volume, in: 0...1, step: 0.1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3")
                }
                .accessibilityValue("\(Int((volume * 100).rounded())) percent")
            }
        }
    }
}
```

### Toggle

`Toggle("Send reminders", isOn: $remindersOn)` takes a title and a `Binding<Bool>`. The title is the visible label and the accessibility label. If the design hides it, use `labelsHidden()`, and still write one: Apple's `labelsHidden()` page says "Always provide a label for controls, even when you hide the label, because SwiftUI uses labels for other purposes, including accessibility."

### TextField

`TextField("Email", text: $email)`: on iOS the title is the placeholder, and VoiceOver uses it as the label. With a `String` binding, Apple says the field "updates this value continuously as the user types"; for non-string values (`TextField(_:value:format:)`), it updates "when the user commits their edits, such as by pressing the Return key."

The modifiers after it match Module 24's `UITextField` settings, now as modifiers:

- `keyboardType(.emailAddress)` picks the keyboard.
- `textContentType(.emailAddress)` tells the system what the field is for, so it can offer AutoFill suggestions.
- `textInputAutocapitalization(.never)` and `autocorrectionDisabled()` stop iOS from "fixing" an address.

For passwords, use `SecureField`, which hides what's typed. `.onSubmit { … }` runs an action when the user presses Return, and `.submitLabel(.next)` changes the Return key's title.

### Picker

A `Picker` binds a selection to one of several options. Each option needs a **tag** of the same type as the selection. Apple's `Picker` page: `ForEach` "automatically assigns a tag to the selection views using each option's `id`," which works here because `ReminderFrequency`'s `id` is `Self`, the same type as `frequency`. With options written out by hand, tag them yourself: `Text("Daily").tag(ReminderFrequency.daily)`.

The look depends on context: in a `Form` on iOS it's a row showing the current value that opens a menu. `.pickerStyle(.segmented)` shows a segmented control, good for two to four short options.

`.disabled(!remindersOn)` greys out the picker and stops interaction while reminders are off. VoiceOver reports it as dimmed. Disabling is a value like any other: it's computed from state on every `body`.

### Stepper and Slider

`Stepper("Copies: \(copies)", value: $copies, in: 1...5)` increments and decrements within the range, by 1 unless you pass `step:`. Putting the value in the title means VoiceOver and the screen both show it.

`Slider(value:in:step:)` needs a floating-point binding and a range. Its first closure is a label, often not shown on iOS but used for accessibility; the minimum and maximum labels show at the ends. Apple notes that "the slider also uses the `step` to increase or decrease the value when a VoiceOver user adjusts the slider." A raw value between 0 and 1 isn't what a person wants to hear, so `accessibilityValue(_:)` gives VoiceOver "50 percent" instead. Round before converting to `Int`, for a reason the second exercise shows.

## Accessibility at a glance

| Control | VoiceOver gets by default | What you add |
| --- | --- | --- |
| `Text` | Its content | Nothing; use text styles for Dynamic Type |
| `Image(_:)` | A label from its name's localization | A better `accessibilityLabel` if the name isn't one |
| `Image(decorative:)` | Nothing (ignored) | Nothing |
| `Image(systemName:)` | Don't rely on it | `accessibilityLabel` if meaningful, `accessibilityHidden(true)` if not, or use a `Label` |
| `Button` | Its title, button trait | A role; a title even when only the icon shows |
| `Toggle`, `Stepper`, `Picker` | Its title and current value | A title even with `labelsHidden()` |
| `TextField` | Its title | Keyboard and content type settings |
| `Slider` | Its label and value | `accessibilityValue` in real units |

Two more modifiers come up often: `accessibilityHint(_:)` describes what happens after an action when the label alone doesn't make it clear ("Removes the photo from all albums"), and `accessibilityInputLabels(_:)` gives Voice Control users shorter alternative names for a control. Module 27's rules about grouping and reading order apply here too; in SwiftUI, `accessibilityElement(children: .combine)` merges a container's children into one element.

## Keep the rules out of the view

A form's rules (what makes the email valid, when the submit button is enabled, which message to show) are logic, and logic is easier to test without a view. Put them in a plain struct and let the view read it:

```swift
struct SignUpForm {
    var email = ""
    var password = ""
    var acceptsTerms = false

    var problems: [String] {
        var result: [String] = []
        if !email.contains("@") {
            result.append("Enter a valid email.")
        }
        if password.count < 8 {
            result.append("Use at least 8 characters.")
        }
        if !acceptsTerms {
            result.append("Accept the terms to continue.")
        }
        return result
    }

    var canSubmit: Bool { problems.isEmpty }
}

var form = SignUpForm()
print(form.canSubmit, form.problems.count)
form.email = "ana@example.com"
form.password = "correct horse"
print(form.problems)
form.acceptsTerms = true
print(form.canSubmit)
```

```output
false 3
["Accept the terms to continue."]
true
```

The view keeps one `@State private var form = SignUpForm()` and binds controls to its properties with `$form.email`, `$form.password` and `$form.acceptsTerms`; a binding can point at a property inside a struct. The submit button gets `.disabled(!form.canSubmit)`, and the footer shows `form.problems.first`. The struct can be tested with Swift Testing in milliseconds (Module 33), and the view stays a thin description.

> [!tip] A disabled button isn't an explanation
> A greyed-out button with no message leaves people guessing, and VoiceOver users only hear "dimmed". Show the first problem next to the button, as in the example above, so the reason is visible and readable.

## Common mistakes

> [!error] An icon-only button with no title
> `Button { share() } label: { Image(systemName: "square.and.arrow.up") }` gives VoiceOver no good name. Use `Button("Share", systemImage: "square.and.arrow.up", action: share)` with `.labelStyle(.iconOnly)`, or add `accessibilityLabel("Share")`.

> [!error] The picker ignores taps
> The tags don't match the selection's type: `Text("One").tag(1)` with a `String` selection, or `ForEach` over values whose `id` isn't the selection's type. Make the tag type and the selection type the same.

> [!error] Coloring a destructive button instead of giving it a role
> `.foregroundStyle(.red)` makes it red, but menus, alerts and assistive technologies don't know it's destructive. Use `role: .destructive`.

> [!error] Empty labels on controls with hidden labels
> `Toggle("", isOn: $isOn)` looks the same as one with a title and `labelsHidden()`, but VoiceOver has nothing to say. Always write the title.

> [!error] Truncating a computed percentage
> `Int(volume * 100)` with `volume` at 0.29 gives 28, because `0.29 * 100` is 28.999999999999996 in binary floating point. Round first.

## Exercises

````exercise
id: m34-l04-e1
type: prediction
prompt: "The binding model from the lesson, with a stepper whose binding clamps what it writes. What does it print?"
code: |
  final class Storage<Value> {
      var value: Value
      init(_ value: Value) { self.value = value }
  }

  struct Binding<Value> {
      let get: () -> Value
      let set: (Value) -> Void

      var wrappedValue: Value {
          get { get() }
          nonmutating set { set(newValue) }
      }
  }

  struct Stepper {
      let value: Binding<Int>
      func increment() { value.wrappedValue += 2 }
      func decrement() { value.wrappedValue -= 2 }
  }

  let copies = Storage(3)
  let clamped = Binding(
      get: { copies.value },
      set: { copies.value = min(max($0, 1), 6) }
  )
  let stepper = Stepper(value: clamped)

  stepper.increment()
  print(copies.value)
  stepper.increment()
  print(copies.value)
  stepper.decrement()
  stepper.decrement()
  stepper.decrement()
  stepper.decrement()
  print(clamped.wrappedValue)
output: |
  5
  6
  1
hints:
  - "increment() reads 3, adds 2 and writes 5 through set, which clamps to 1...6."
  - "From 6, four decrements write 4, 2, 0 (clamped to 1) and -1 (clamped to 1)."
solution: |
  ```output
  5
  6
  1
  ```

  The stepper only knows how to read and write through its binding. The binding's `set` closure decides what actually gets stored: 3 + 2 = 5, then 7 becomes 6, then 4, 2, 0 → 1, and −1 → 1. `Binding(get:set:)` exists in SwiftUI too, for adapting a value on its way in or out, though a range on the control itself (`Stepper(value:in:)`) is the normal way to limit a stepper.
````

````exercise
id: m34-l04-e2
type: prediction
prompt: "A slider's accessibility value, computed two ways. What does this print?"
code: |
  let volumes = [0.29, 0.57, 0.7]
  for volume in volumes {
      print(Int(volume * 100), Int((volume * 100).rounded()))
  }
output: |
  28 29
  56 57
  70 70
hints:
  - "0.29 and 0.57 can't be stored exactly in binary floating point."
  - "Int(_:) truncates toward zero."
solution: |
  ```output
  28 29
  56 57
  70 70
  ```

  `0.29 * 100` is 28.999999999999996 and `0.57 * 100` is 56.99999999999999, because neither decimal fraction is exact in a `Double`. `Int(_:)` truncates, so VoiceOver would say "28 percent" for a slider showing 29%. `rounded()` first gives the expected numbers. `0.7 * 100` happens to land just above 70, so both agree there.
````

````exercise
id: m34-l04-e3
type: comprehension
prompt: "A recipe screen shows a large photo of the dish, which the title right below already names, and a small flame symbol that means \"spicy\" with no text next to it. What's the best choice for the two images?"
choices:
  - text: "Make the photo decorative (or hide it) and give the flame an accessibility label such as \"Spicy\"."
    correct: true
    why: "The photo repeats the title, so reading it adds noise. The flame carries information that isn't anywhere else."
  - text: "Give both an accessibility label with their file or symbol names."
    correct: false
    why: "\"flame.fill\" isn't a meaningful label, and labeling the photo duplicates the title."
  - text: "Hide both from VoiceOver; images are never important."
    correct: false
    why: "The flame is the only place the screen says the dish is spicy."
  - text: "Leave both as they are; SwiftUI generates good labels automatically."
    correct: false
    why: "Apple's Image page asks you to choose labeled or decorative initializers; don't rely on symbol names."
solution: |
  **Photo decorative, flame labeled.** The photo adds nothing the title doesn't say, so `Image(decorative:)` or `accessibilityHidden(true)`. The flame is information, so `.accessibilityLabel("Spicy")`, or better, a `Label("Spicy", systemImage: "flame.fill")` with `.labelStyle(.iconOnly)` if the design shows only the icon.
````

````exercise
id: m34-l04-e4
type: solve
prompt: |
  Write a `TransferForm` struct for a bank transfer screen, in plain Swift, with:

  - `var recipient = ""`, `var amountText = ""` and `var balance: Double`
  - a computed `problems: [String]` that checks, in this order:
    1. the recipient isn't empty after trimming spaces: "Choose a recipient."
    2. `amountText` parses with `Double(_:)`: "Enter an amount." (stop checking the amount if it doesn't parse)
    3. the amount is more than 0: "The amount must be more than zero."
    4. the amount isn't more than `balance`: "The amount is more than your balance."
  - `var canSubmit: Bool`

  Then run:

  ```swift
  var form = TransferForm(balance: 120)
  print(form.problems)
  form.recipient = "  Ana "
  form.amountText = "150"
  print(form.problems)
  form.amountText = "75.5"
  print(form.canSubmit)
  ```
starter: |
  struct TransferForm {
      var recipient = ""
      var amountText = ""
      var balance: Double

      var problems: [String] {
          // your code
          []
      }

      var canSubmit: Bool { problems.isEmpty }
  }
hints:
  - "recipient.trimmingCharacters(in:) needs Foundation; recipient.filter { $0 != \" \" }.isEmpty works without it."
  - "Use guard let amount = Double(amountText) else { … return result } to stop after the parse problem."
rubric:
  - Checks the four rules in order and uses the exact messages.
  - Stops checking the amount when it doesn't parse.
  - canSubmit is derived from problems, not stored.
  - Prints the three expected lines.
solution: |
  ```swift
  struct TransferForm {
      var recipient = ""
      var amountText = ""
      var balance: Double

      var problems: [String] {
          var result: [String] = []
          if recipient.filter({ $0 != " " }).isEmpty {
              result.append("Choose a recipient.")
          }
          guard let amount = Double(amountText) else {
              result.append("Enter an amount.")
              return result
          }
          if amount <= 0 {
              result.append("The amount must be more than zero.")
          } else if amount > balance {
              result.append("The amount is more than your balance.")
          }
          return result
      }

      var canSubmit: Bool { problems.isEmpty }
  }

  var form = TransferForm(balance: 120)
  print(form.problems)
  form.recipient = "  Ana "
  form.amountText = "150"
  print(form.problems)
  form.amountText = "75.5"
  print(form.canSubmit)
  ```

  ```output
  ["Choose a recipient.", "Enter an amount."]
  ["The amount is more than your balance."]
  true
  ```

  The view would hold `@State private var form = TransferForm(balance: account.balance)`, bind `TextField("Recipient", text: $form.recipient)` and `TextField("Amount", text: $form.amountText)` with `.keyboardType(.decimalPad)`, show `form.problems.first` under the button and disable it with `.disabled(!form.canSubmit)`. Every rule is tested here without a simulator. (A real banking app would use `Decimal` for money, not `Double`; the parsing is kept simple for the exercise.)
````

````exercise
id: m34-l04-e5
type: find-errors
prompt: "A teammate's profile settings screen. Which of these are real problems?"
code: |
  struct ProfileSettings: View {
      @State private var nickname = ""
      @State private var theme = "System"
      @State private var showsBadge = true

      var body: some View {
          Form {
              TextField("", text: $nickname)
              Picker("Theme", selection: $theme) {
                  Text("System").tag(0)
                  Text("Light").tag(1)
                  Text("Dark").tag(2)
              }
              Toggle("", isOn: $showsBadge)
                  .labelsHidden()
              Button {
                  deleteAccount()
              } label: {
                  Image(systemName: "trash")
              }
              .foregroundStyle(.red)
          }
      }

      private func deleteAccount() {}
  }
choices:
  - text: "The text field has an empty title, so it has no placeholder and no accessibility label."
    correct: true
    why: "On iOS the title is the placeholder and the label VoiceOver reads."
  - text: "The picker's tags are Int while the selection is a String, so picking an option won't change theme."
    correct: true
    why: "Tags must have the same type as the selection binding."
  - text: "The toggle's title is empty; labelsHidden() hides it visually, but VoiceOver still needs one."
    correct: true
    why: "Apple: always provide a label for controls, even when you hide it."
  - text: "The delete button has only an image and is colored red instead of using role: .destructive."
    correct: true
    why: "No title for VoiceOver, and the destructive meaning is only visual."
  - text: "A Form can't contain a Button."
    correct: false
    why: "Buttons in forms and lists are normal; they take a row's look."
rubric:
  - Flags the empty TextField title.
  - Flags the mismatched tag type.
  - Flags the empty Toggle title.
  - Flags both problems with the delete button (no title, no role).
  - Doesn't flag the button inside the Form.
solution: |
  Four real problems, and a fixed version:

  ```swift ios
  import SwiftUI

  struct ProfileSettings: View {
      @State private var nickname = ""
      @State private var theme = "System"
      @State private var showsBadge = true

      var body: some View {
          Form {
              TextField("Nickname", text: $nickname)
              Picker("Theme", selection: $theme) {
                  Text("System").tag("System")
                  Text("Light").tag("Light")
                  Text("Dark").tag("Dark")
              }
              Toggle("Show badge", isOn: $showsBadge)
              Button("Delete account", systemImage: "trash", role: .destructive) {
                  deleteAccount()
              }
          }
      }

      private func deleteAccount() {}
  }
  ```

  The field and toggle get real titles (the toggle no longer needs `labelsHidden()`; if the design wants it, keep the title and hide it). The tags are now `String`s like the selection; an enum would be better still. The button has a title VoiceOver reads and a destructive role that styles it. Buttons inside a `Form` are fine. (`Button(_:systemImage:role:action:)` combines all three; Apple's documentation lists it as available from iOS 15.)
````

````exercise
id: m34-l04-e6
type: explain
prompt: "Why does Toggle take $isOn rather than isOn? Explain in two or three sentences what would go wrong with a plain Bool."
code: |
  struct WiFiSettings: View {
      @State private var isOn = false

      var body: some View {
          Toggle("Wi-Fi", isOn: $isOn)
      }
  }
rubric:
  - Says a plain Bool would be a copy the toggle can't write back to the view's state.
  - Says the binding lets the toggle read the current value and write a new one into state the view owns.
  - Mentions that the write makes SwiftUI update the view.
solution: |
  A plain `Bool` would be a copy: the toggle could show it, but flipping it would change only the toggle's copy, and the view's `isOn` would never change. `$isOn` is a `Binding<Bool>`, a way to read and write the value that the view's `@State` owns, so the toggle shows the current value and writes the new one back into that storage. That write is a state change, so SwiftUI runs the view's `body` again and everything that reads `isOn` updates.
````

## Summary

- Value controls take a binding (`$name`): a way to read and write state that someone else owns. Module 36 covers bindings in depth.
- `Text` localizes string literals, not variables; `Text(verbatim:)` opts out. Use text styles so text follows Dynamic Type.
- Choose `Image(_:)` for labeled images, `Image(decorative:)` for decoration, and give meaningful SF Symbols a label or use a `Label`.
- Give buttons roles (`.destructive`, `.cancel`) and styles instead of colors; for icon-only buttons, keep the title and use `.labelStyle(.iconOnly)`.
- Toggles, pickers and fields always need a title, even when hidden. Picker tags must match the selection's type.
- Use `accessibilityValue` for values in real units, `accessibilityHint` when a result isn't obvious, and `accessibilityHidden` for decoration.
- Keep form rules in a plain struct; the view binds to its properties and reads `problems` and `canSubmit`.
