---
id: m24-l01
title: Standard controls
description: The everyday UIKit controls, configured the current way and made usable with VoiceOver. You style buttons with UIButton.Configuration, set up text fields and text views for the input they expect, show images and symbols, use switches, sliders and segmented controls with UIAction, show progress with an activity indicator, and give every one of them the accessibility label, value and traits it needs.
module: m24
order: 1
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m22-l05, m23-l06]
objectives:
  - Configure labels, text fields and text views for Dynamic Type and for the kind of text they hold.
  - Build buttons with UIButton.Configuration, including subtitles, images, a loading state and a configurationUpdateHandler.
  - Use UIImageView, UISwitch, UISlider, UISegmentedControl and UIActivityIndicatorView and react to their changes with UIAction.
  - Name the default accessibility traits of each control and add the label, value, hint or trait it's missing.
  - Decide whether an image is decorative or meaningful and configure it for VoiceOver either way.
terms:
  - term: UIButton.Configuration
    definition: "A value type (iOS 15) that describes a button's title, subtitle, image, colors, size and background. You pick a style (plain, gray, tinted, filled, the bordered variants, and the Liquid Glass styles in iOS 26), change its properties and assign it to the button's configuration property."
  - term: Accessibility label
    definition: "A short, localized word or phrase that names an element for VoiceOver, without saying what kind of element it is: \"Add\", not \"Add button\"."
  - term: Accessibility traits
    definition: "A UIAccessibilityTraits option set that tells assistive technologies what an element is or how it behaves: button, image, header, adjustable, selected, notEnabled and others."
  - term: Accessibility value
    definition: "The current value of an element as text, such as \"40%\" for a slider. VoiceOver reads it after the label."
  - term: Decorative image
    definition: "An image that adds nothing a VoiceOver user needs. You hide it from VoiceOver by setting isAccessibilityElement to false."
mastery:
  - Write a button with a filled configuration, an SF Symbol and a loading state driven by configurationUpdateHandler.
  - Configure an email field and a password field with the right keyboard, content type and return key.
  - Wire a switch, a slider and a segmented control with UIAction and read their values.
  - Give an icon-only button, a symbol image and a slider with units the label and value VoiceOver needs.
  - Pick between UIActivityIndicatorView and a button's showsActivityIndicator for a loading state.
resources: [uikit-target-action, uikit-uistackview, hig, apple-documentation]
cards:
  - id: m24-l01-c1
    front: How do you style a UIButton in current UIKit?
    back: "With a UIButton.Configuration: start from .filled(), .tinted(), .gray(), .plain() (or .glass() on iOS 26), set title, subtitle, image, imagePlacement, buttonSize and cornerStyle, and assign it to button.configuration or pass it to UIButton(configuration:primaryAction:)."
  - id: m24-l01-c2
    front: Where do you change a button's configuration when its state changes (loading, highlighted, selected)?
    back: "In configurationUpdateHandler (or an updateConfiguration() override). Read your own state, copy button.configuration, change it, assign it back. Call setNeedsUpdateConfiguration() when your own state changes."
  - id: m24-l01-c3
    front: An icon-only button with a trash symbol. What does VoiceOver need?
    back: "An accessibilityLabel such as \"Delete\". The button trait is already there by default, so the label must not say \"button\"."
  - id: m24-l01-c4
    front: Default accessibility traits of a slider, and what you usually add?
    back: "User Interaction Enabled and Adjustable. Add an accessibilityLabel (\"Volume\") and, when the raw number means nothing, an accessibilityValue with units (\"40 percent\")."
  - id: m24-l01-c5
    front: Decorative image vs meaningful image for VoiceOver?
    back: "Decorative: isAccessibilityElement = false, so VoiceOver skips it. Meaningful: isAccessibilityElement = true, an accessibilityLabel that says what it shows, and the image trait."
---

## The idea in one sentence

Every standard control comes with sensible behavior and default accessibility, and your job is to configure it for its content (font, keyboard, range, style), connect its event with a `UIAction`, and fill in the accessibility information it can't know: what it's called and, when the raw value means nothing, what its value means.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. The control behavior and the default accessibility traits quoted here come from Apple's reference pages for each class, read in November 2026. The plain-Swift models at the end were compiled and run.

## What you already have

Module 22 built a form with labels, text fields, a filled button and a stack view, connected controls with `UIAction` and target-action, and used a text field delegate. Module 23 laid views out with Auto Layout, stack views and scroll views. This lesson goes through the controls one by one: what each is for, the properties you set on almost every use, and what VoiceOver needs from it.

Apple's `UIControl` page lists the accessibility attributes every control supports: a **label** ("a short, localized word or phrase that succinctly describes the control or view, but doesn't identify the element's type. Examples are Add and Play"), **traits**, a **hint** ("a brief, localized phrase that describes the results of an action", like "Adds a title"), a **value**, and a frame. Controls provide the frame and value themselves. You supply the rest when the control can't infer it.

## UILabel

A label displays read-only text. Three settings belong on nearly every label:

```swift ios
import UIKit

let titleLabel = UILabel()
titleLabel.text = "Notifications"
titleLabel.font = .preferredFont(forTextStyle: .title2)
titleLabel.adjustsFontForContentSizeCategory = true
titleLabel.numberOfLines = 0
titleLabel.accessibilityTraits.insert(.header)

let detailLabel = UILabel()
detailLabel.text = "Choose what the app can tell you about, and when."
detailLabel.font = .preferredFont(forTextStyle: .subheadline)
detailLabel.adjustsFontForContentSizeCategory = true
detailLabel.textColor = .secondaryLabel
detailLabel.numberOfLines = 0
```

- `preferredFont(forTextStyle:)` plus `adjustsFontForContentSizeCategory` makes the label follow Dynamic Type while the app runs. Module 23 covered the layout side.
- `numberOfLines = 0` means "as many lines as needed". The default is 1, which truncates large text with an ellipsis.
- Apple: "Labels are accessible to VoiceOver by default. The default accessibility traits for a label are Static Text and User Interaction Enabled." VoiceOver reads the text; you don't set a label.
- **A title that starts a section gets the `.header` trait.** VoiceOver users can jump from header to header, the way sighted users scan headings. `insert(_:)` adds it without removing the defaults, because `accessibilityTraits` is an option set.

## UIButton with a configuration

Since iOS 15, a button's appearance lives in a `UIButton.Configuration` value. You pick a starting style and change its properties:

| Style | Look |
| --- | --- |
| `.plain()` | Text only, no background |
| `.gray()` | Gray background |
| `.tinted()` | Light tint-colored background, tinted text |
| `.filled()` | Solid tint-colored background, white text: the primary action |
| `.borderless()`, `.bordered()`, `.borderedTinted()`, `.borderedProminent()` | The bordered family, used heavily on Mac Catalyst |
| `.glass()`, `.prominentGlass()`, `.clearGlass()`, `.prominentClearGlass()` | Liquid Glass styles, iOS 26 and later |

```swift ios
import UIKit

var configuration = UIButton.Configuration.filled()
configuration.title = "Download"
configuration.subtitle = "2.4 GB"
configuration.image = UIImage(systemName: "arrow.down.circle")
configuration.imagePlacement = .leading
configuration.imagePadding = 8
configuration.buttonSize = .large
configuration.cornerStyle = .capsule

let downloadButton = UIButton(configuration: configuration, primaryAction: UIAction { _ in
    print("download tapped")
})
```

- `Configuration` is a struct. You build a value, then hand it to the button. Changing `configuration` afterwards doesn't touch the button until you assign it again.
- `imagePlacement` is an edge (`.leading`, `.trailing`, `.top`, `.bottom`), so it flips correctly in right-to-left languages.
- Apple: "When using a configuration, the button ignores deprecated methods and properties of UIButton." Don't mix in older calls like `setTitleColor(_:for:)` and expect them to win; set colors with `baseForegroundColor` and `baseBackgroundColor` on the configuration.

### Changing the configuration with state

A button that shows a spinner while it works needs its configuration to follow your state. `configurationUpdateHandler` runs "when the button state changes", and you ask for a run yourself with `setNeedsUpdateConfiguration()` when **your** state changes:

```swift ios
import UIKit

final class CheckoutViewController: UIViewController {
    private let payButton = UIButton(configuration: .filled())
    private var isPaying = false {
        didSet { payButton.setNeedsUpdateConfiguration() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        payButton.configurationUpdateHandler = { [weak self] button in
            guard let self else { return }
            var configuration = button.configuration ?? .filled()
            configuration.title = isPaying ? "Paying…" : "Pay"
            configuration.showsActivityIndicator = isPaying
            button.configuration = configuration
            button.isEnabled = !isPaying
        }

        payButton.addAction(UIAction { [weak self] _ in
            self?.isPaying = true
        }, for: .primaryActionTriggered)

        payButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(payButton)
        NSLayoutConstraint.activate([
            payButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            payButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func paymentFinished() {
        isPaying = false
    }
}
```

1. `isPaying` is the screen's state. Its `didSet` asks the button to update; Apple notes that several calls before the update collapse into one.
2. The handler reads the state, copies the configuration, changes the title and `showsActivityIndicator` ("displays an activity indicator instead of an image"), and assigns it back.
3. `isEnabled = false` stops double taps and makes VoiceOver add "dimmed" to what it reads.
4. `[weak self]` for the same reason as Module 22: the controller owns the button, the button owns the closure.

### Buttons and VoiceOver

Apple: "Buttons are accessible by default. The default accessibility traits for a button are Button and User Interaction Enabled." With a title, VoiceOver has something to read. **An icon-only button has no title**, so you must name it:

```swift ios
import UIKit

var trashConfiguration = UIButton.Configuration.plain()
trashConfiguration.image = UIImage(systemName: "trash")

let deleteButton = UIButton(configuration: trashConfiguration)
deleteButton.accessibilityLabel = "Delete"
deleteButton.accessibilityHint = "Deletes the draft."
```

The label is "Delete", not "Delete button": the trait already says it's a button, and VoiceOver reads both. The hint is optional and read after a pause; keep it to what the action does.

## UITextField

A single line of editable text. Most of the setup is telling the system what the text is, so the keyboard, autocorrection and AutoFill behave:

```swift ios
import UIKit

let emailField = UITextField()
emailField.placeholder = "name@example.com"
emailField.borderStyle = .roundedRect
emailField.font = .preferredFont(forTextStyle: .body)
emailField.adjustsFontForContentSizeCategory = true
emailField.keyboardType = .emailAddress
emailField.textContentType = .emailAddress
emailField.autocapitalizationType = .none
emailField.autocorrectionType = .no
emailField.returnKeyType = .next
emailField.clearButtonMode = .whileEditing
emailField.accessibilityLabel = "Email"

let passwordField = UITextField()
passwordField.placeholder = "Password"
passwordField.borderStyle = .roundedRect
passwordField.isSecureTextEntry = true
passwordField.textContentType = .password
passwordField.returnKeyType = .go
passwordField.accessibilityLabel = "Password"
```

| Property | What it changes |
| --- | --- |
| `keyboardType` | The keyboard layout: `.emailAddress` adds `@` and `.`, `.decimalPad` shows digits and a separator |
| `textContentType` | The meaning of the text, used by AutoFill and the password manager |
| `autocapitalizationType`, `autocorrectionType` | Turn off for emails, usernames, codes |
| `returnKeyType` | The Return key's title (`.next`, `.go`, `.done`, `.search`) |
| `isSecureTextEntry` | Hides the characters |
| `clearButtonMode` | When the ⓧ button appears |

Apple: "Text fields are accessible by default. The default accessibility trait for a text field is User Interaction Enabled." VoiceOver also announces that it's a text field. **Give it an `accessibilityLabel` that matches the visible label next to it.** The placeholder is a sample of the expected format, and it disappears as soon as the user types.

Reacting to the text: `.editingChanged` with `UIAction` for every change, the delegate's `textFieldShouldReturn(_:)` for the Return key (both in Module 22, lesson 5).

## UITextView

Multi-line, scrollable, optionally editable text: notes, comments, terms of service.

```swift ios
import UIKit

let notesView = UITextView()
notesView.font = .preferredFont(forTextStyle: .body)
notesView.adjustsFontForContentSizeCategory = true
notesView.isScrollEnabled = false
notesView.text = ""
notesView.accessibilityLabel = "Notes"

let termsView = UITextView()
termsView.isEditable = false
termsView.dataDetectorTypes = [.link]
termsView.text = "Read the full terms at https://example.com/terms."
```

- **A text view is a scroll view.** Inside a stack view or a scroll view that already scrolls, set `isScrollEnabled = false`: the text view then grows with its text instead of scrolling inside a fixed height. Leave scrolling on when it has a fixed frame of its own.
- `isEditable = false` makes it read-only but still selectable. `dataDetectorTypes` turns links, phone numbers and addresses into tappable items; Apple: "data detection does not occur if the text view's isEditable property is set to true."
- There's no placeholder property. Use a label above it, or a label you hide when text appears.
- Changes arrive through `UITextViewDelegate.textViewDidChange(_:)`. A text view isn't a `UIControl`, so there's no `.editingChanged` event.

## UIImageView

Shows one image, scaled by its `contentMode`:

```swift ios
import UIKit

let avatarView = UIImageView(image: UIImage(systemName: "person.crop.circle"))
avatarView.contentMode = .scaleAspectFit
avatarView.tintColor = .systemBlue
avatarView.isAccessibilityElement = true
avatarView.accessibilityLabel = "Profile photo of Ana"
avatarView.accessibilityTraits = .image

let dividerView = UIImageView(image: UIImage(systemName: "sparkles"))
dividerView.isAccessibilityElement = false
```

| `contentMode` | Result |
| --- | --- |
| `.scaleAspectFit` | Whole image visible, letterboxed |
| `.scaleAspectFill` | Fills the view, crops the overflow. Pair it with `clipsToBounds = true` or the overflow draws outside |
| `.scaleToFill` (default) | Stretches to fill, distorting the aspect ratio |

`UIImage(systemName:)` loads an SF Symbol and returns an optional, `nil` if the name doesn't exist. Symbols are templates: they take the view's `tintColor`.

**Images and VoiceOver.** Apple's `UIImageView` page says image views have the Image trait. Whether VoiceOver stops on one is decided by `isAccessibilityElement`, and the rule for it is "true for standard controls", which an image view isn't. So decide per image and set it explicitly:

- **Meaningful** (a chart, a product photo, a status icon with no text next to it): `isAccessibilityElement = true` and a label that says what it shows.
- **Decorative** (a flourish, an icon repeated by the text beside it): `isAccessibilityElement = false`, so VoiceOver skips it.

## UISwitch

An on/off choice that takes effect immediately:

```swift ios
import UIKit

let soundsLabel = UILabel()
soundsLabel.text = "Sounds"

let soundsSwitch = UISwitch()
soundsSwitch.isOn = true
soundsSwitch.accessibilityLabel = "Sounds"
soundsSwitch.addAction(UIAction { action in
    guard let toggle = action.sender as? UISwitch else { return }
    print("sounds: \(toggle.isOn)")
}, for: .valueChanged)

soundsSwitch.setOn(false, animated: true)
```

- `.valueChanged` is the event for the user "manipulating a control" (Apple's definition). Setting `isOn` or calling `setOn(_:animated:)` from code doesn't send it, so your handler only sees user changes.
- `action.sender` is the control that sent the action, typed `Any?`, so cast it.
- A switch with a label next to it in a row still needs its own `accessibilityLabel`. VoiceOver focuses on the switch as a separate element and reads its value (on or off) and that it's a switch, but it doesn't know the text in the label beside it. Module 27 shows how to merge the row into one element instead.

## UISlider

A value from a continuous range:

```swift ios
import UIKit

let volumeSlider = UISlider()
volumeSlider.minimumValue = 0
volumeSlider.maximumValue = 1
volumeSlider.value = 0.4
volumeSlider.minimumValueImage = UIImage(systemName: "speaker")
volumeSlider.maximumValueImage = UIImage(systemName: "speaker.wave.3")
volumeSlider.accessibilityLabel = "Volume"
volumeSlider.accessibilityValue = "40 percent"

volumeSlider.addAction(UIAction { action in
    guard let slider = action.sender as? UISlider else { return }
    let percent = Int((slider.value * 100).rounded())
    slider.accessibilityValue = "\(percent) percent"
    print("volume: \(percent)%")
}, for: .valueChanged)
```

- `value` is a `Float`, clamped to `minimumValue...maximumValue`.
- `isContinuous` is `true` by default: the slider "triggers the associated target's action method repeatedly, as the user moves the thumb". Set it to `false` when each change is expensive (a network call), and you get one event when the thumb is released.
- Apple: "The default accessibility traits for a slider are User Interaction Enabled and Adjustable." Adjustable means VoiceOver users swipe up and down to change it. VoiceOver reads the label, the value, the traits and the hint. **The default value is a percentage of the range**, which is fine for 0...1 and wrong for a slider from 10 to 30 °C. Set `accessibilityValue` to what the number means, and update it when the value changes, as the handler above does.

## UISegmentedControl

A small set of mutually exclusive options, all visible at once. The `UIAction` initializer (iOS 14) creates one segment per action:

```swift ios
import UIKit

let sortControl = UISegmentedControl(frame: .zero, actions: [
    UIAction(title: "Newest") { _ in print("sort: newest") },
    UIAction(title: "Oldest") { _ in print("sort: oldest") },
    UIAction(title: "A–Z") { _ in print("sort: name") },
])
sortControl.selectedSegmentIndex = 0

let layoutControl = UISegmentedControl(items: ["List", "Grid"])
layoutControl.selectedSegmentIndex = 0
layoutControl.addAction(UIAction { action in
    guard let control = action.sender as? UISegmentedControl else { return }
    print("layout index: \(control.selectedSegmentIndex)")
}, for: .valueChanged)
```

- With `init(frame:actions:)`, "selecting a segment invokes the action's handler, as well as handlers for the valueChanged and primaryActionTriggered control events."
- With `init(items:)`, read `selectedSegmentIndex` in a `.valueChanged` handler. Until the user touches a segment, it's `UISegmentedControl.noSegment` (-1), so set the initial selection yourself.
- Two to five short segments. More options than that belong in a menu or a list.
- VoiceOver reads each segment's title and its position. **Image-only segments need names**: set `accessibilityLabel` on each `UIImage` before you pass it in, for example `listImage?.accessibilityLabel = "List"`.

## UIActivityIndicatorView

The spinner: "a view that shows that a task is in progress", without saying how far along it is.

```swift ios
import UIKit

let spinner = UIActivityIndicatorView(style: .large)
spinner.color = .secondaryLabel
spinner.accessibilityLabel = "Loading messages"
spinner.startAnimating()

spinner.stopAnimating()
print(spinner.isHidden)
```

- Styles are `.medium` and `.large`. The old `.white`, `.whiteLarge` and `.gray` are deprecated.
- `hidesWhenStopped` is `true` by default: `stopAnimating()` also hides it, so the last line would print `true`. You don't toggle `isHidden` yourself.
- Give it a label that says what's loading. For a spinner that replaces a button's content while the button's action runs, use the button's `showsActivityIndicator` instead: the spinner stays inside the control the user just tapped.

## Accessibility at a glance

| Control | Default traits (Apple) | You usually add |
| --- | --- | --- |
| `UILabel` | Static Text | `.header` for section titles |
| `UIButton` | Button | `accessibilityLabel` when it's icon-only; a hint if the result isn't obvious |
| `UITextField` | (announced as a text field) | `accessibilityLabel` matching the visible label |
| `UITextView` | (announced as a text view) | `accessibilityLabel` |
| `UIImageView` | Image | `isAccessibilityElement` set on purpose; a label if meaningful |
| `UISwitch` | (announced as a switch, with its value) | `accessibilityLabel` |
| `UISlider` | Adjustable | `accessibilityLabel`; `accessibilityValue` with units |
| `UISegmentedControl` | (each segment is a button) | Labels on image segments |
| `UIActivityIndicatorView` | — | `accessibilityLabel` saying what's loading |

User Interaction Enabled is also a default on all the interactive ones. Test with VoiceOver on a device or with the Accessibility Inspector in Xcode (Module 27).

## A settings screen

A small screen that combines several controls in a stack view (Module 23), each wired with `UIAction`:

```swift ios
import UIKit

final class NotificationSettingsViewController: UIViewController {
    private let titleLabel = UILabel()
    private let enabledSwitch = UISwitch()
    private let frequencyControl = UISegmentedControl(items: ["Daily", "Weekly"])
    private let volumeSlider = UISlider()
    private let saveButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureControls()
        layOut()
    }

    private func configureControls() {
        titleLabel.text = "Notifications"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits.insert(.header)

        enabledSwitch.isOn = true
        enabledSwitch.accessibilityLabel = "Allow notifications"
        enabledSwitch.addAction(UIAction { [weak self] _ in
            self?.updateEnabledState()
        }, for: .valueChanged)

        frequencyControl.selectedSegmentIndex = 0
        frequencyControl.accessibilityLabel = "Frequency"

        volumeSlider.value = 0.5
        volumeSlider.accessibilityLabel = "Alert volume"
        volumeSlider.accessibilityValue = "50 percent"
        volumeSlider.addAction(UIAction { action in
            guard let slider = action.sender as? UISlider else { return }
            slider.accessibilityValue = "\(Int((slider.value * 100).rounded())) percent"
        }, for: .valueChanged)

        var saveConfiguration = UIButton.Configuration.filled()
        saveConfiguration.title = "Save"
        saveButton.configuration = saveConfiguration
        saveButton.addAction(UIAction { [weak self] _ in
            self?.save()
        }, for: .primaryActionTriggered)
    }

    private func layOut() {
        let switchRow = UIStackView(arrangedSubviews: [makeLabel("Allow notifications"), enabledSwitch])
        switchRow.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleLabel, switchRow, frequencyControl, volumeSlider, saveButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
        ])
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    private func updateEnabledState() {
        let isOn = enabledSwitch.isOn
        frequencyControl.isEnabled = isOn
        volumeSlider.isEnabled = isOn
    }

    private func save() {
        print("enabled: \(enabledSwitch.isOn), frequency: \(frequencyControl.selectedSegmentIndex), volume: \(volumeSlider.value)")
    }
}
```

Disabling the dependent controls when the switch is off does two things at once: they look dimmed, and VoiceOver reads them as "dimmed" (the `notEnabled` trait comes with `isEnabled = false`).

## The logic without UIKit

Two things on a screen like this are plain logic you can test without a simulator: what a control's accessibility value should say, and whether a form can be submitted. This model also shows the order in which VoiceOver reads an element: Apple's slider page says it speaks "the accessibility label, value, traits, and hint".

```swift
struct AccessibleElement {
    var label: String
    var value: String? = nil
    var traits: [String] = []
    var hint: String? = nil

    var spoken: String {
        var parts = [label]
        if let value { parts.append(value) }
        parts += traits
        if let hint { parts.append(hint) }
        return parts.joined(separator: ", ")
    }
}

func temperatureValue(_ celsius: Float) -> String {
    "\(Int(celsius.rounded())) degrees"
}

let thermostat = AccessibleElement(label: "Temperature", value: temperatureValue(21.6), traits: ["adjustable"], hint: "Swipe up or down to adjust.")
let deleteButton = AccessibleElement(label: "Delete", traits: ["button"])
let unnamedButton = AccessibleElement(label: "", traits: ["button"])

print(thermostat.spoken)
print(deleteButton.spoken)
print(unnamedButton.spoken)
```

```output
Temperature, 22 degrees, adjustable, Swipe up or down to adjust.
Delete, button
, button
```

The last line is what an icon-only button without a label is like for a VoiceOver user: a button with no name. (Real VoiceOver may fall back to the image's file name, which is rarely better.) The exact words VoiceOver uses for traits differ from this model; the order is the point.

## Common mistakes

> [!error] An icon-only button with no accessibilityLabel
> VoiceOver reads it as an unnamed button. Every button without a visible title needs `accessibilityLabel`, and the label never includes the word "button".

> [!error] Treating the placeholder as the label
> The placeholder vanishes as soon as there's text, and it's a sample, not a name. Show a real label and set `accessibilityLabel` on the field.

> [!error] Mixing configuration and the old button API
> With a configuration set, the button ignores the deprecated setters and your configuration decides the look. Change colors, titles and images on the configuration, then assign it back.

> [!error] A slider whose value VoiceOver reads as a meaningless percentage
> A 10–30 °C slider at 20 reads as "50%". Set `accessibilityValue` to "20 degrees" and update it in the `.valueChanged` handler.

> [!error] Expecting .valueChanged when you set the value in code
> Assigning `isOn`, `value` or `selectedSegmentIndex` from code doesn't send the event. If code changes a control, update dependent UI in the same place.

> [!error] A text view inside a stack view that stays one line tall
> With scrolling enabled, a text view doesn't size itself to its text. Set `isScrollEnabled = false` when its container should grow with it.

## Exercises

````exercise
id: m24-l01-e1
type: prediction
prompt: "Using the lesson's model of what VoiceOver reads, what does this print?"
code: |
  struct AccessibleElement {
      var label: String
      var value: String? = nil
      var traits: [String] = []
      var hint: String? = nil

      var spoken: String {
          var parts = [label]
          if let value { parts.append(value) }
          parts += traits
          if let hint { parts.append(hint) }
          return parts.joined(separator: ", ")
      }
  }

  var wifi = AccessibleElement(label: "Wi-Fi", value: "on", traits: ["switch button"])
  print(wifi.spoken)
  wifi.value = "off"
  wifi.traits.append("dimmed")
  print(wifi.spoken)

  let rating = AccessibleElement(label: "Rating", value: "3 of 5 stars", traits: ["adjustable"], hint: "Swipe up or down to change.")
  print(rating.spoken)
output: |
  Wi-Fi, on, switch button
  Wi-Fi, off, switch button, dimmed
  Rating, 3 of 5 stars, adjustable, Swipe up or down to change.
hints:
  - "The order is label, value, traits, hint."
  - "wifi is a var, so changing value and appending a trait changes the next line."
solution: |
  ```output
  Wi-Fi, on, switch button
  Wi-Fi, off, switch button, dimmed
  Rating, 3 of 5 stars, adjustable, Swipe up or down to change.
  ```

  `spoken` joins whatever is present in a fixed order: label, value, traits, hint. The second line adds `dimmed`, which is what a disabled control gets in UIKit through the `notEnabled` trait when you set `isEnabled = false`. The rating line shows why sliders and steppers need a meaningful `accessibilityValue`: "3 of 5 stars" says far more than "60%".
````

````exercise
id: m24-l01-e2
type: comprehension
prompt: "A toolbar has three icon-only buttons (share, favorite, delete). VoiceOver users report that they can't tell them apart. What's the right fix?"
choices:
  - text: "Set accessibilityLabel on each button to \"Share\", \"Favorite\" and \"Delete\"."
    correct: true
    why: "Buttons already have the Button trait; what's missing is the name."
  - text: "Set accessibilityLabel to \"Share button\", \"Favorite button\" and \"Delete button\"."
    correct: false
    why: "VoiceOver already reads the trait, so users would hear \"button\" twice. Apple's guidance: the label doesn't identify the element's type."
  - text: "Add the .button trait to each one."
    correct: false
    why: "Buttons have it by default. The problem is the missing label."
  - text: "Set accessibilityHint to describe each action and leave the label empty."
    correct: false
    why: "The hint is optional extra information read after a pause; users still meet three unnamed buttons first."
solution: |
  **Set a label on each button.** An icon-only button has no title for VoiceOver to read. The label names it ("Share"), the default Button trait says what it is, and a hint ("Shares the photo.") is optional on top of that. Putting "button" in the label makes VoiceOver say it twice.
````

````exercise
id: m24-l01-e3
type: fill-in
prompt: "Complete a loading button: the configuration update handler shows a spinner and a different title while isSaving is true, and changing isSaving triggers an update."
code: |
  final class EditorViewController: UIViewController {
      private let saveButton = UIButton(configuration: .filled())
      private var isSaving = false {
          didSet { saveButton.[[1]]() }
      }

      override func viewDidLoad() {
          super.viewDidLoad()
          saveButton.[[2]] = { [weak self] button in
              guard let self else { return }
              var configuration = button.configuration ?? .filled()
              configuration.title = isSaving ? "Saving…" : "Save"
              configuration.[[3]] = isSaving
              button.configuration = configuration
          }
      }
  }
blanks:
  - id: "1"
    answers: ["setNeedsUpdateConfiguration"]
  - id: "2"
    answers: ["configurationUpdateHandler"]
  - id: "3"
    answers: ["showsActivityIndicator"]
solution: |
  ```swift ios
  import UIKit

  final class EditorViewController: UIViewController {
      private let saveButton = UIButton(configuration: .filled())
      private var isSaving = false {
          didSet { saveButton.setNeedsUpdateConfiguration() }
      }

      override func viewDidLoad() {
          super.viewDidLoad()
          saveButton.configurationUpdateHandler = { [weak self] button in
              guard let self else { return }
              var configuration = button.configuration ?? .filled()
              configuration.title = isSaving ? "Saving…" : "Save"
              configuration.showsActivityIndicator = isSaving
              button.configuration = configuration
          }
      }
  }
  ```

  `configurationUpdateHandler` runs whenever UIKit decides the button needs updating: state changes like highlighted or disabled, and your explicit `setNeedsUpdateConfiguration()` calls. The button doesn't know about `isSaving`, so its `didSet` has to ask. `showsActivityIndicator` replaces the button's image with a spinner, positioned by `imagePlacement`.
````

````exercise
id: m24-l01-e4
type: find-errors
prompt: "This sign-up form passes a quick visual check but fails an accessibility review and has an input problem. Mark every real problem."
code: |
  let headerLabel = UILabel()
  headerLabel.text = "Create account"
  headerLabel.font = .systemFont(ofSize: 28, weight: .bold)

  let emailField = UITextField()
  emailField.placeholder = "Email"
  emailField.keyboardType = .default
  emailField.autocapitalizationType = .sentences

  let logo = UIImageView(image: UIImage(named: "brand-swirl"))
  logo.isAccessibilityElement = true

  var closeConfiguration = UIButton.Configuration.plain()
  closeConfiguration.image = UIImage(systemName: "xmark")
  let closeButton = UIButton(configuration: closeConfiguration)
  closeButton.accessibilityLabel = "Close button"
choices:
  - text: "The header uses a fixed font size, so it ignores Dynamic Type, and it lacks the .header trait."
    correct: true
  - text: "The email field relies on the placeholder as its only label and has no accessibilityLabel."
    correct: true
  - text: "The email field has the default keyboard and sentence capitalization, so the first letter of every email is capitalized and there's no @ key."
    correct: true
  - text: "The decorative logo is exposed to VoiceOver with no label."
    correct: true
  - text: "The close button's label says \"button\", which VoiceOver already reads from the trait."
    correct: true
  - text: "UIButton.Configuration.plain() can't show an image; only filled() can."
    correct: false
    why: "Every configuration style can show an image."
rubric:
  - I found the fixed font and missing header trait.
  - I found the placeholder-only label.
  - I found the keyboard and capitalization settings.
  - I found the decorative image exposed to VoiceOver.
  - I found the redundant "button" in the label.
solution: |
  Five problems:

  1. **Fixed font, no header trait.** Use `.preferredFont(forTextStyle: .largeTitle)` with `adjustsFontForContentSizeCategory = true`, and `accessibilityTraits.insert(.header)`.
  2. **Placeholder as label.** Add a visible label and `emailField.accessibilityLabel = "Email"`.
  3. **Wrong input traits.** `keyboardType = .emailAddress`, `textContentType = .emailAddress`, `autocapitalizationType = .none`, `autocorrectionType = .no`.
  4. **Decorative logo exposed.** A brand swirl adds nothing; set `isAccessibilityElement = false`. (If it were meaningful, it would need a label.)
  5. **"Close button".** The label is just "Close".

  ```swift ios
  import UIKit

  let headerLabel = UILabel()
  headerLabel.text = "Create account"
  headerLabel.font = .preferredFont(forTextStyle: .largeTitle)
  headerLabel.adjustsFontForContentSizeCategory = true
  headerLabel.numberOfLines = 0
  headerLabel.accessibilityTraits.insert(.header)

  let emailField = UITextField()
  emailField.placeholder = "name@example.com"
  emailField.keyboardType = .emailAddress
  emailField.textContentType = .emailAddress
  emailField.autocapitalizationType = .none
  emailField.autocorrectionType = .no
  emailField.accessibilityLabel = "Email"

  let logo = UIImageView(image: UIImage(named: "brand-swirl"))
  logo.isAccessibilityElement = false

  var closeConfiguration = UIButton.Configuration.plain()
  closeConfiguration.image = UIImage(systemName: "xmark")
  let closeButton = UIButton(configuration: closeConfiguration)
  closeButton.accessibilityLabel = "Close"
  ```
````

````exercise
id: m24-l01-e5
type: solve
prompt: |
  Write the plain-Swift logic for a "tip" slider, so it can be tested without UIKit.

  - `tipPercent(sliderValue:)` takes the slider's `Float` value (range 0...1) and returns the tip as a whole percentage between 0 and 30, rounded to the nearest whole number (0 → 0, 1 → 30).
  - `tipAccessibilityValue(percent:billCents:)` returns the text VoiceOver should read, for example `"15 percent, 4.50 dollars"`, computing the tip from a bill in cents. Format cents as dollars with two decimals, using integer arithmetic only.

  ```swift
  for value: Float in [0, 0.5, 0.52, 1] {
      let percent = tipPercent(sliderValue: value)
      print(tipAccessibilityValue(percent: percent, billCents: 3000))
  }
  ```

  should print:

  ```plaintext
  0 percent, 0.00 dollars
  15 percent, 4.50 dollars
  16 percent, 4.80 dollars
  30 percent, 9.00 dollars
  ```
starter: |
  func tipPercent(sliderValue: Float) -> Int {
      // your code
      0
  }

  func tipAccessibilityValue(percent: Int, billCents: Int) -> String {
      // your code
      ""
  }
hints:
  - "Multiply the slider value by 30 and round it before converting to Int."
  - "tipCents = billCents * percent / 100. Dollars are tipCents / 100, cents are tipCents % 100."
  - "Pad cents below 10 with a leading zero."
rubric:
  - tipPercent maps 0...1 to 0...30 with rounding.
  - The accessibility value includes the units, not a raw number.
  - Money is computed with integers, and cents are always two digits.
  - The output matches.
solution: |
  ```swift
  func tipPercent(sliderValue: Float) -> Int {
      Int((sliderValue * 30).rounded())
  }

  func tipAccessibilityValue(percent: Int, billCents: Int) -> String {
      let tipCents = billCents * percent / 100
      let dollars = tipCents / 100
      let cents = tipCents % 100
      let paddedCents = cents < 10 ? "0\(cents)" : "\(cents)"
      return "\(percent) percent, \(dollars).\(paddedCents) dollars"
  }

  for value: Float in [0, 0.5, 0.52, 1] {
      let percent = tipPercent(sliderValue: value)
      print(tipAccessibilityValue(percent: percent, billCents: 3000))
  }
  ```

  ```output
  0 percent, 0.00 dollars
  15 percent, 4.50 dollars
  16 percent, 4.80 dollars
  30 percent, 9.00 dollars
  ```

  `0.52 * 30` is 15.6, which rounds to 16. In the view controller, the slider's `.valueChanged` handler calls both functions and assigns the result to `slider.accessibilityValue`, so VoiceOver reads "16 percent, 4.80 dollars" instead of "52%". Integer cents avoid floating-point rounding in money; a real app would format currency with the user's locale (Module 43).
````

````exercise
id: m24-l01-e6
type: design
prompt: |
  Choose a control for each setting and say what VoiceOver needs from it.

  1. Dark mode on or off, applied immediately.
  2. Map style: Standard, Satellite or Hybrid.
  3. Font size for the reader, from 12 to 28 points.
  4. A "Retry" action shown after a failed upload, with only a circular-arrow icon.
  5. A product photo on a detail screen with no caption.
rubric:
  - A switch for 1, a segmented control for 2, a slider (or stepper) for 3.
  - The slider gets an accessibilityValue in points.
  - The icon-only button gets a label without the word "button".
  - The product photo is an accessibility element with a descriptive label.
solution: |
  1. **`UISwitch`**, with `accessibilityLabel = "Dark mode"`. VoiceOver reads its on/off value itself.
  2. **`UISegmentedControl`** with three title segments. Titles are read as they are; give the control a label like "Map style" if nothing on screen names it.
  3. **`UISlider`** from 12 to 28 (or a `UIStepper` if steps of 1 matter). Set `accessibilityValue` to "18 points": the default would read a percentage of the range.
  4. **`UIButton`** with a `.plain()` or `.tinted()` configuration and the `arrow.clockwise` symbol. `accessibilityLabel = "Retry"`, optionally a hint "Uploads the photo again."
  5. **`UIImageView`** with `isAccessibilityElement = true` and a label that describes the product ("Blue running shoe, side view"). It carries information the screen doesn't repeat in text, so it isn't decorative.
````

## Summary

- Labels: Dynamic Type font, `adjustsFontForContentSizeCategory`, `numberOfLines = 0`, and `.header` on section titles.
- Buttons: build a `UIButton.Configuration`, assign it, and change it in `configurationUpdateHandler`; call `setNeedsUpdateConfiguration()` when your own state changes. Name icon-only buttons.
- Text fields: set `keyboardType`, `textContentType`, capitalization, correction and `returnKeyType` for the content; label them for VoiceOver. Text views scroll unless you turn it off, and report changes through their delegate.
- Image views: pick a `contentMode`; decide decorative or meaningful and set `isAccessibilityElement` accordingly.
- Switches, sliders and segmented controls report user changes with `.valueChanged`, not changes you make in code. Sliders need an `accessibilityValue` with units.
- Activity indicators hide themselves when stopped; a button's `showsActivityIndicator` is the better choice for a button's own work.
