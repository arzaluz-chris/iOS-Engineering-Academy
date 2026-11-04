---
id: m27-l07
title: Localization and internationalization
description: Make one UIKit app read naturally in every language and region it supports. You wrap user-facing text in String(localized:) so Xcode fills a String Catalog, add plural variations and see why languages need different numbers of forms, format numbers, currency and dates with FormatStyle instead of string concatenation, pin a Locale and time zone when output must be reproducible, and build layouts that mirror correctly for right-to-left languages with leading and trailing constraints.
module: m27
order: 7
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l06]
objectives:
  - Tell internationalization (preparing code) from localization (translating and adapting it).
  - Make user-facing text localizable with String(localized:), comments, tables and explicit keys.
  - Explain how a String Catalog is filled at build time and how plural variations work.
  - Implement CLDR plural category selection for a few languages and explain why English rules don't generalize.
  - Format numbers, percentages, currency and dates with FormatStyle, and pin Locale and TimeZone where output must be reproducible.
  - Build layouts that mirror for right-to-left languages with leading and trailing constraints, natural text alignment and semantic content attributes.
  - Test localizations with scheme language and region settings.
terms:
  - term: Internationalization
    definition: "Preparing code and resources so they can adapt to any language and region: localizable strings, formatters instead of hand-built text, layouts that grow and mirror."
  - term: Localization
    definition: "Adapting an internationalized app to a specific language and region: translations, plural forms, localized images and other resources."
  - term: String Catalog
    definition: "An .xcstrings file (Xcode 15) that holds every localizable string, its translations and its variations (plural, device). Xcode adds strings it finds in localizable APIs each time you build."
  - term: Plural category
    definition: "One of zero, one, two, few, many and other, defined per language by the Unicode CLDR rules. English uses one and other; Russian uses one, few, many and other; Arabic uses all six."
  - term: FormatStyle
    definition: "Foundation's value-type formatting API (iOS 15): number.formatted(.currency(code:)), date.formatted(.dateTime.year().month().day()) and so on, localized for the current locale unless you pass another."
  - term: Leading and trailing
    definition: "Layout edges that depend on the writing direction: leading is the left edge in left-to-right languages and the right edge in right-to-left languages such as Arabic and Hebrew."
mastery:
  - Wrap a screen's strings in String(localized:) with comments a translator can use.
  - Write the plural variants a String Catalog needs for English and for Russian.
  - Select the plural category for a number in English, French, Russian, Arabic and Japanese.
  - Format a price, a large number and a date for a given locale, and explain why tests pin the locale and time zone.
  - Lay out a row with leading and trailing constraints and decide which views must not mirror.
  - Compute where a view lands when a manual layout is mirrored for right-to-left.
resources: [uikit-nslayoutanchor, uikit-scaling-fonts, swift-book-strings, uikit-uiview]
cards:
  - id: m27-l07-c1
    front: How does text get into a String Catalog?
    back: "Wrap user-facing text in a localizable API such as String(localized:) and build. Xcode finds the strings and adds them to the catalog each time you build. Pass comment: to give translators context."
  - id: m27-l07-c2
    front: Why isn't `count == 1 ? "item" : "items"` enough?
    back: "Plural rules differ by language. French uses the singular for 0 and 1; Russian has one, few and many forms (1 файл, 2 файла, 5 файлов); Arabic has six categories; Japanese has one. Use plural variations in the String Catalog."
  - id: m27-l07-c3
    front: How do you format a price for the user's region?
    back: "Store it as Decimal, not Double, and format it with price.formatted(.currency(code: \"EUR\")). The currency comes from your data; separators, symbol position and spacing come from the user's locale."
  - id: m27-l07-c4
    front: What makes formatted output reproducible in a test?
    back: "Pin the Locale (and the TimeZone and Calendar for dates) instead of using the current ones, for example .locale(Locale(identifier: \"en_US\")). Even then, avoid comparing to hard-coded strings where locale data might change between OS versions."
  - id: m27-l07-c5
    front: Which views shouldn't mirror in right-to-left layouts?
    back: "Playback controls and controls that represent physical directions. Set semanticContentAttribute to .playback or .spatial. Most images don't flip either; only directional ones like a back arrow, with imageFlippedForRightToLeftLayoutDirection()."
---

## The idea in one sentence

**Internationalization** is everything you do in code so the app never assumes a language, a number format or a writing direction, and **localization** is filling in the answers for each language and region; if the first is done right, the second is data, not code changes.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. `String(localized:)` is in Apple's Foundation but not in the Foundation that ships with Swift on Linux, so it only appears in those blocks. The plural rules are plain Swift. The formatting examples pin their locale and time zone and print only outputs that were checked by running them with Swift 6.3; they use locale data, which can change between OS releases, so the lesson says where. Behavior comes from Apple's Xcode articles "Localizing and varying text with a string catalog", "Preparing your app's text for translation", "Preparing dates, currencies, and numbers for translation", "Supporting multiple languages in your app" and "Testing localizations when running your app", and the reference pages for `String`, `UIView` and `UISemanticContentAttribute`, read in November 2026. Xcode's String Catalog editor was not checked for this lesson. Dynamic Type was Module 23, lesson 6; universal links were Module 25, lesson 6.

## Two jobs

Apple's "Supporting multiple languages in your app" separates them: "To make your app multilingual, you first internationalize it by preparing your code and assets for translation into different languages and regions," and "After you internationalize your app, you localize it by translating your strings and varying your assets for multiple languages and regions."

The internationalization checklist from the same article: user-facing text through localizable APIs; dates, currencies and numbers through formatters; grammatical agreement; text direction; "tall languages" that need vertical room (Dynamic Type helps); and localizable images and colors in asset catalogs. This lesson covers the first, second and fourth in depth.

## Localizable strings

Every string a person sees goes through a localizable API. In UIKit code that's `String(localized:)`:

```swift ios
import UIKit

final class InboxViewController: UIViewController {
    private let countLabel = UILabel()
    private let composeButton = UIButton(configuration: .filled())

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Inbox", comment: "Title of the screen that lists messages")
        composeButton.configuration?.title = String(localized: "New Message", comment: "Button that starts a new message")
        composeButton.accessibilityHint = String(
            localized: "Opens an empty message",
            comment: "Accessibility hint for the New Message button"
        )
        countLabel.numberOfLines = 0
        countLabel.font = .preferredFont(forTextStyle: .subheadline)
        countLabel.adjustsFontForContentSizeCategory = true
    }

    func showUnread(_ count: Int) {
        countLabel.text = String(
            localized: "\(count) unread messages",
            comment: "Number of unread messages in the inbox"
        )
    }

    func showSyncError() {
        countLabel.text = String(
            localized: "inbox.syncError",
            defaultValue: "Couldn't refresh. Pull down to try again.",
            table: "Errors",
            comment: "Shown when refreshing the inbox fails"
        )
    }
}
```

- **`String(localized:comment:)`** looks the string up "in the bundle's string table", defaulting to `Localizable`, and uses the string itself as the key and as the fallback: "This parameter also serves as the default value if the system can't find a localized string."
- **The comment** is for the translator. "New Message" could be a button or a heading; "Inbox" could be a noun or, in some languages, need a different form as a title. Xcode copies the comment into the catalog. Apple: "Add comments to give context and assist localizers when translating your text."
- **Interpolation** becomes a format specifier. `"\(count) unread messages"` is stored in the catalog under the key `%lld unread messages`, and the translator writes `%lld` wherever the number goes in their language. Never build sentences by concatenating translated fragments: word order differs between languages.
- **Explicit keys** (`"inbox.syncError"` with `defaultValue:`) are for when the English text might change but the meaning doesn't, or the same English word needs different translations in different places. Apple: use it "To create localizable strings with different keys and values".
- **`table:`** puts strings in another catalog, here `Errors.xcstrings`, to keep large projects organized.
- Accessibility labels, hints and values are user-facing text too.

### The String Catalog

Apple's String Catalog article describes the workflow: add a `Localizable.xcstrings` file, then "choose Product > Build. Xcode discovers the localizable strings in your app and adds them to string catalogs in your project automatically. Each time you build your project, Xcode updates your string catalogs with changes you make to localizable strings in your code." You add languages in the catalog's editor, translators fill in the values, and each string shows a state, from new to translated.

The file is JSON. Abridged, an English entry with plural variants looks roughly like this (Xcode writes and maintains it; you rarely edit it by hand, and the exact fields may differ between Xcode versions):

```json
{
  "sourceLanguage": "en",
  "strings": {
    "%lld unread messages": {
      "comment": "Number of unread messages in the inbox",
      "localizations": {
        "en": {
          "variations": {
            "plural": {
              "one": { "stringUnit": { "state": "translated", "value": "%lld unread message" } },
              "other": { "stringUnit": { "state": "translated", "value": "%lld unread messages" } }
            }
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

At run time, `String(localized:)` picks the variant that matches the number for the current language.

## Plurals

English has two forms, so `count == 1 ? "message" : "messages"` seems to work. It fails as soon as there's a second language. Apple's catalog article: "Languages have different grammatical rules for handling plurals of nouns and units," and when you choose Vary by Plural, "Xcode adds One and Other variants for English when it's the source localization, and One, Few, Many, and Other variants for Russian when you add Russian."

The rules come from the Unicode CLDR project, which assigns each number to a **category** per language. Here are the rules for whole numbers in a few languages, in plain Swift:

```swift
enum PluralCategory { case zero, one, two, few, many, other }

// CLDR plural rules for whole numbers in a few languages.
func pluralCategory(for n: Int, language: String) -> PluralCategory {
    let lastDigit = n % 10
    let lastTwo = n % 100
    switch language {
    case "en", "de", "es", "it":
        return n == 1 ? .one : .other
    case "fr":
        return n == 0 || n == 1 ? .one : .other
    case "ru", "uk":
        if lastDigit == 1 && lastTwo != 11 { return .one }
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return .few }
        return .many
    case "ar":
        if n == 0 { return .zero }
        if n == 1 { return .one }
        if n == 2 { return .two }
        if (3...10).contains(lastTwo) { return .few }
        if (11...99).contains(lastTwo) { return .many }
        return .other
    default:
        return .other
    }
}

let counts = [0, 1, 2, 3, 5, 11, 21, 22, 101, 111]
for language in ["en", "fr", "ru", "ar", "ja"] {
    let categories = counts.map { "\(pluralCategory(for: $0, language: language))" }
    print(language, categories.joined(separator: " "))
}

let russianFiles: [PluralCategory: String] = [.one: "файл", .few: "файла", .many: "файлов"]
for n in [1, 2, 5, 11, 21, 22, 25] {
    print(n, russianFiles[pluralCategory(for: n, language: "ru")] ?? "?")
}
```

```output
en other one other other other other other other other other
fr one one other other other other other other other other
ru many one few few many many one few one many
ar zero one two few few many many many other many
ja other other other other other other other other other other
1 файл
2 файла
5 файлов
11 файлов
21 файл
22 файла
25 файлов
```

The columns are 0, 1, 2, 3, 5, 11, 21, 22, 101 and 111:

- **English**: only 1 is "one". Zero is plural ("0 messages").
- **French**: 0 and 1 are both "one" ("0 message", "1 message").
- **Russian**: the category depends on the last digits. 21 and 101 are "one" (21 файл), 22 is "few", 11 and 111 are "many" because the teens are exceptions. That's why "21 files" can't be produced by English logic.
- **Arabic**: six categories; 101 falls back to "other" because only its last two digits (01) count for few and many.
- **Japanese**: no plural forms at all; everything is "other".

The model leaves out parts of CLDR you won't meet with whole counts of things: categories for decimal numbers, and a French "many" form used for large round numbers such as a million. That's the point of using the catalog: the system has the complete rules for every language. Your job is to pass the number to `String(localized:)` and give translators the variants.

## Numbers, currency and dates

Apple's "Preparing dates, currencies, and numbers for translation": "Some languages use the period (.) as a decimal separator, and others use the comma (,)," and "many regions display time and date differently, despite being part of the same language." The answer is to never build these strings yourself. `FormatStyle` (iOS 15) formats for the user's locale by default; to see or test a specific one, pin it:

```swift
import Foundation

let us = Locale(identifier: "en_US")
let germany = Locale(identifier: "de_DE")
let india = Locale(identifier: "hi_IN")
let britain = Locale(identifier: "en_GB")

let downloads = 1234567
print(downloads.formatted(.number.locale(us)))
print(downloads.formatted(.number.locale(germany)))
print(downloads.formatted(.number.locale(india)))
print(0.25.formatted(.percent.locale(us)))

let price = Decimal(string: "1234.5")!
print(price.formatted(.currency(code: "USD").locale(us)))
print(price.formatted(.currency(code: "GBP").locale(britain)))

let utc = TimeZone(identifier: "UTC")!
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = utc
let launch = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 14, minute: 30))!

var dayMonthYear = Date.FormatStyle.dateTime.year().month().day()
dayMonthYear.timeZone = utc
print(launch.formatted(dayMonthYear.locale(us)))
print(launch.formatted(dayMonthYear.locale(britain)))
print(launch.formatted(dayMonthYear.locale(germany)))
print(launch.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: us, timeZone: utc)))
print(launch.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: germany, timeZone: utc)))
print(launch.formatted(.iso8601))
```

```output
1,234,567
1.234.567
12,34,567
25%
$1,234.50
£1,234.50
Mar 5, 2026
5 Mar 2026
5. März 2026
3/5/2026
5.3.2026
2026-03-05T14:30:00Z
```

- **The same number, three groupings.** Germany swaps the separators; India groups by lakh (12,34,567). Hand-written formatting with `","` gets two of these three wrong.
- **Currency** combines two separate inputs: the **currency code** comes from your data (the price is in pounds), and the **locale** decides the symbol, its position, the separators and the decimals. Use `Decimal` for money; Apple's article: "To ensure accuracy, don't use Float or Double to represent currency in your app. Use Decimal instead."
- **Dates** with the same fields come out in each locale's order and wording: "Mar 5, 2026", "5 Mar 2026", "5. März 2026". You choose **which** fields to show (`.year().month().day()`); the locale chooses the order and punctuation. Apple: "The order of the fields you pass into the formatted(_:) function doesn't matter."
- **The time zone is pinned** to UTC. The date is created from components in UTC and formatted in UTC; with the current time zone, the same instant can be a different calendar day.
- **ISO 8601** is for machines (logs, APIs), not people. It's the one format here that doesn't depend on locale.

The output above was produced by running the code, and it uses locales whose output is stable. Some locales use no-break spaces in numbers and currencies (French groups thousands with a narrow no-break space, and German puts a no-break space before "€"), and locale data is updated with OS releases. So in tests, compare formatted output only when you pin the locale, and prefer checking your logic (which fields, which currency code) over hard-coded strings.

In UIKit code you usually want the **user's** locale, so you don't pass one:

```swift ios
import UIKit

struct Order {
    let total: Decimal
    let currencyCode: String
    let placedAt: Date
    let distanceKilometers: Double
}

@MainActor
func configure(totalLabel: UILabel, dateLabel: UILabel, distanceLabel: UILabel, with order: Order) {
    totalLabel.text = order.total.formatted(.currency(code: order.currencyCode))
    dateLabel.text = order.placedAt.formatted(date: .abbreviated, time: .shortened)
    let distance = Measurement(value: order.distanceKilometers, unit: UnitLength.kilometers)
    distanceLabel.text = distance.formatted(.measurement(width: .abbreviated, usage: .road))
}
```

- `formatted(date:time:)` picks a predefined style; `.abbreviated` dates and `.shortened` times are good defaults for lists.
- **`Measurement`** converts units for the locale. Apple's article: "a distance in feet for the en_US locale appears as meters using the French locale fr_FR." With `usage: .road`, a US user sees miles for a distance stored in kilometers.
- **Lists** have a style too: `["small", "medium", "large"].formatted(.list(type: .and))` gives "small, medium, and large" in US English, and Apple's example shows French "50, 75 et 100".

## Right-to-left layout

Arabic, Hebrew, Persian and Urdu are written right to left, and the whole interface mirrors: navigation goes the other way, the back button points right, leading content is on the right. `Locale.Language` reports a language's direction:

```swift
import Foundation

for code in ["en", "ar", "he", "ja"] {
    let direction = Locale.Language(identifier: code).characterDirection
    print(code, direction == .rightToLeft ? "right to left" : "left to right")
}
```

```output
en left to right
ar right to left
he right to left
ja left to right
```

You don't use that in layout code, though. UIKit mirrors Auto Layout for you as long as you express positions as **leading and trailing**:

```swift ios
import UIKit

final class ContactRowView: UIView {
    let avatar = UIImageView(image: UIImage(systemName: "person.crop.circle"))
    let nameLabel = UILabel()
    let chevron = UIImageView(image: UIImage(systemName: "chevron.forward"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        nameLabel.textAlignment = .natural
        for view in [avatar, nameLabel, chevron] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            avatar.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),

            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevron.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),
            chevron.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }
}

final class PlayerControlsView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .playback
        let rewind = UIButton(configuration: .plain())
        rewind.configuration?.image = UIImage(systemName: "backward.fill")
        let play = UIButton(configuration: .plain())
        play.configuration?.image = UIImage(systemName: "play.fill")
        let forward = UIButton(configuration: .plain())
        forward.configuration?.image = UIImage(systemName: "forward.fill")
        [rewind, play, forward].forEach { addArrangedSubview($0) }
    }

    required init(coder: NSCoder) {
        fatalError("Built in code")
    }
}

let back = UIImage(named: "back-arrow")?.imageFlippedForRightToLeftLayoutDirection()
```

- **Leading and trailing anchors** flip with the layout direction; left and right don't. Module 23 used them from the start for this reason. Apple's `NSLayoutAnchor` page warns that mixing them ("constrain one view's leadingAnchor with another view's leftAnchor") compiles but "crashes at runtime".
- **`.natural` text alignment** aligns text to the leading edge for the current language. `.left` stays left in Arabic, which looks wrong.
- **`chevron.forward`** is an SF Symbol that points in the reading direction; `chevron.right` would point the wrong way in right-to-left layouts.
- **Some views must not mirror.** Apple's `semanticContentAttribute` page: "Some views should not flip when switching between left-to-right and right-to-left layouts. For example, the view is part of the playback controls or represents physical directions." `.playback` is for "Play, Rewind, or Fast Forward buttons or playhead scrubbers"; `.spatial` for "a directional control, such as a segment control for text alignment". Media controls keep rewind on the left in every language.
- **Images**: "most images do not need to flip in a right-to-left layout." A custom back arrow does; `imageFlippedForRightToLeftLayoutDirection()` "returns the current UIImage object with the flipsForRightToLeftLayoutDirection property set to true; it does not return a flipped image." The image view flips it when the layout is right to left.

### Manual layout

Code that sets frames itself (lesson 4's `layoutSubviews()`) gets no automatic mirroring. Ask the view for `effectiveUserInterfaceLayoutDirection` ("When a view's immediate content is being arranged or drawn, you should always consult the value of this property") and mirror x positions yourself: the new x is the container width minus the old x minus the view's width.

```swift
struct Frame {
    var x: Int
    var width: Int
}

func mirrored(_ frame: Frame, inWidth containerWidth: Int) -> Frame {
    Frame(x: containerWidth - frame.x - frame.width, width: frame.width)
}

let rowWidth = 320
let leftToRight = [("avatar", Frame(x: 16, width: 40)), ("name", Frame(x: 68, width: 180)), ("chevron", Frame(x: 292, width: 12))]
for (name, frame) in leftToRight {
    let flipped = mirrored(frame, inWidth: rowWidth)
    print(name, frame.x, "→", flipped.x)
}
```

```output
avatar 16 → 264
name 68 → 72
chevron 292 → 16
```

The avatar keeps its 16-point inset, now from the right edge: 320 − 16 − 40 = 264. The chevron, 16 points from the right in left-to-right, ends up 16 points from the left. Widths don't change. In `layoutSubviews()`, you'd compute the left-to-right frames and pass them through this function when `effectiveUserInterfaceLayoutDirection == .rightToLeft`.

## Testing localizations

Apple's "Testing localizations when running your app": "choose Product > Scheme > Edit Scheme", select Run, then Options, and choose the **App Language** and **App Region**. That changes only your app, not the simulator; Apple warns that changing the device's Language & Region settings changes them for "the entire operating system".

What to check in each localization:

- **Text that grows.** Translations are often longer than English. Labels need `numberOfLines = 0` or room to grow, and buttons shouldn't have fixed widths. Apple's "Previewing localizations" article mentions pseudolanguages in Interface Builder previews for catching this before translations exist.
- **Right-to-left** in Arabic or Hebrew: mirrored layout, `.natural` text, directional images, and controls that must not mirror.
- **Region without language.** English with the region set to Germany should show "1.234.567" and dates in day-month order. Region and language are independent settings.
- **Plurals** at 0, 1, 2, 5, 11 and 21 in languages with several forms.
- **Missing translations**: the catalog marks them, and at run time the source-language text appears.

## Common mistakes

> [!error] Building sentences from pieces
> `String(localized: "You have") + " \(count) " + String(localized: "messages")` can't be translated, because other languages put the number and words in a different order. Localize the whole sentence with interpolation.

> [!error] English plural logic in code
> `count == 1 ? "file" : "files"` is wrong for French at 0 and for Russian at 2, 5 or 21. Use plural variations in the String Catalog.

> [!error] Hand-formatted numbers, prices and dates
> `"$\(price)"` or `"\(day)/\(month)/\(year)"` is wrong for most of the world. Use `formatted(...)` with the user's locale, and `Decimal` for money.

> [!error] Tests that depend on the machine's locale or time zone
> A test that formats a date with the current locale passes on your Mac and fails on a CI runner in another region. Pin the locale, the time zone and the calendar.

> [!error] left and right instead of leading and trailing
> Left and right constraints don't mirror for right-to-left languages, and mixing them with leading and trailing crashes at runtime.

> [!error] Mirroring everything
> Media controls, graphs over time in some designs, and physical directions shouldn't mirror. Use `.playback` or `.spatial`, and flip only directional images.

> [!error] Strings without comments
> "Open" could be an adjective or a verb, and translators can't tell. Add a `comment:` to every string that's ambiguous out of context.

## Exercises

````exercise
id: m27-l07-e1
type: prediction
prompt: "Using the lesson's plural rules (repeated so it compiles on its own), what does this print?"
code: |
  enum PluralCategory { case zero, one, two, few, many, other }

  func pluralCategory(for n: Int, language: String) -> PluralCategory {
      let lastDigit = n % 10
      let lastTwo = n % 100
      switch language {
      case "en", "de", "es", "it":
          return n == 1 ? .one : .other
      case "fr":
          return n == 0 || n == 1 ? .one : .other
      case "ru", "uk":
          if lastDigit == 1 && lastTwo != 11 { return .one }
          if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return .few }
          return .many
      case "ar":
          if n == 0 { return .zero }
          if n == 1 { return .one }
          if n == 2 { return .two }
          if (3...10).contains(lastTwo) { return .few }
          if (11...99).contains(lastTwo) { return .many }
          return .other
      default:
          return .other
      }
  }

  print(pluralCategory(for: 0, language: "en"), pluralCategory(for: 0, language: "fr"))
  print(pluralCategory(for: 12, language: "ru"), pluralCategory(for: 32, language: "ru"), pluralCategory(for: 1001, language: "ru"))
  print(pluralCategory(for: 10, language: "ar"), pluralCategory(for: 200, language: "ar"), pluralCategory(for: 1, language: "ja"))
output: |
  other one
  many few one
  few other other
hints:
  - "Russian 12 is one of the teen exceptions; 32 ends in 2."
  - "1001 ends in 1, and its last two digits aren't 11."
  - "For Arabic, only the last two digits of 200 matter for few and many."
solution: |
  ```output
  other one
  many few one
  few other other
  ```

  - English treats 0 as plural; French treats it as singular.
  - Russian: 12 ends in 2 but its last two digits are 12, an exception, so "many". 32 ends in 2 and isn't a teen: "few". 1001 ends in 1 and its last two digits are 01: "one" (1001 файл).
  - Arabic: 10 is in 3...10: "few". 200's last two digits are 00, neither few nor many: "other". Japanese has no plural forms: everything is "other".
````

````exercise
id: m27-l07-e2
type: solve
prompt: |
  Write `localizedCount(_:language:forms:)` that picks a translation by plural category and substitutes the number. `forms` maps each category the language uses to a template with `%d` where the number goes; if the category's form is missing, fall back to the `.other` form. Reuse the lesson's `pluralCategory(for:language:)` (include it in your answer).

  ```swift
  let english: [PluralCategory: String] = [.one: "%d photo", .other: "%d photos"]
  let russian: [PluralCategory: String] = [.one: "%d фото", .few: "%d фото", .many: "%d фото", .other: "%d фото"]
  let french: [PluralCategory: String] = [.one: "%d photo", .other: "%d photos"]
  let arabicIncomplete: [PluralCategory: String] = [.one: "صورة واحدة", .other: "%d صورة"]

  print(localizedCount(1, language: "en", forms: english))
  print(localizedCount(0, language: "en", forms: english))
  print(localizedCount(0, language: "fr", forms: french))
  print(localizedCount(21, language: "ru", forms: russian))
  print(localizedCount(1, language: "ar", forms: arabicIncomplete))
  print(localizedCount(5, language: "ar", forms: arabicIncomplete))
  ```

  should print:

  ```plaintext
  1 photo
  0 photos
  0 photo
  21 фото
  صورة واحدة
  5 صورة
  ```
starter: |
  enum PluralCategory { case zero, one, two, few, many, other }

  // paste pluralCategory(for:language:) from the lesson here

  func localizedCount(_ n: Int, language: String, forms: [PluralCategory: String]) -> String {
      // your code
      ""
  }
hints:
  - "forms[category] ?? forms[.other] ?? \"\" gives the fallback."
  - "replacingOccurrences(of:with:) needs Foundation; String.replacing(_:with:) is in the standard library."
rubric:
  - Uses the plural category for the language.
  - Falls back to the other form when a category is missing.
  - Substitutes the number for %d, and leaves templates without %d unchanged.
  - Output matches exactly.
solution: |
  ```swift
  enum PluralCategory { case zero, one, two, few, many, other }

  func pluralCategory(for n: Int, language: String) -> PluralCategory {
      let lastDigit = n % 10
      let lastTwo = n % 100
      switch language {
      case "en", "de", "es", "it":
          return n == 1 ? .one : .other
      case "fr":
          return n == 0 || n == 1 ? .one : .other
      case "ru", "uk":
          if lastDigit == 1 && lastTwo != 11 { return .one }
          if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return .few }
          return .many
      case "ar":
          if n == 0 { return .zero }
          if n == 1 { return .one }
          if n == 2 { return .two }
          if (3...10).contains(lastTwo) { return .few }
          if (11...99).contains(lastTwo) { return .many }
          return .other
      default:
          return .other
      }
  }

  func localizedCount(_ n: Int, language: String, forms: [PluralCategory: String]) -> String {
      let category = pluralCategory(for: n, language: language)
      let template = forms[category] ?? forms[.other] ?? ""
      return template.replacing("%d", with: String(n))
  }

  let english: [PluralCategory: String] = [.one: "%d photo", .other: "%d photos"]
  let russian: [PluralCategory: String] = [.one: "%d фото", .few: "%d фото", .many: "%d фото", .other: "%d фото"]
  let french: [PluralCategory: String] = [.one: "%d photo", .other: "%d photos"]
  let arabicIncomplete: [PluralCategory: String] = [.one: "صورة واحدة", .other: "%d صورة"]

  print(localizedCount(1, language: "en", forms: english))
  print(localizedCount(0, language: "en", forms: english))
  print(localizedCount(0, language: "fr", forms: french))
  print(localizedCount(21, language: "ru", forms: russian))
  print(localizedCount(1, language: "ar", forms: arabicIncomplete))
  print(localizedCount(5, language: "ar", forms: arabicIncomplete))
  ```

  ```output
  1 photo
  0 photos
  0 photo
  21 фото
  صورة واحدة
  5 صورة
  ```

  Two details mirror what translators do in a String Catalog. The Arabic "one" form has **no number at all** ("one photo" as a phrase), which is common and is why the template, not your code, decides whether the number appears. And the Arabic forms are incomplete, so 5 (category "few") falls back to "other". In the real catalog Xcode adds every category the language needs, and the fallback hides missing translations only until someone fills them in. (Russian "фото" doesn't change form, which is why its four variants are identical; most Russian nouns do change, like файл, файла, файлов.)
````

````exercise
id: m27-l07-e3
type: find-errors
prompt: "This receipt screen ships in English, German and Arabic. Mark every real internationalization problem."
code: |
  func configure(with receipt: Receipt) {
      itemsLabel.text = "\(receipt.items.count) " + (receipt.items.count == 1 ? "item" : "items")
      totalLabel.text = "$" + String(format: "%.2f", receipt.total)
      dateLabel.text = "\(receipt.month)/\(receipt.day)/\(receipt.year)"
      totalLabel.textAlignment = .right
      NSLayoutConstraint.activate([
          totalLabel.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
          itemsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      ])
  }
choices:
  - text: "The item count string isn't localizable and uses English plural logic."
    correct: true
  - text: "The total hard-codes a dollar sign and format, and uses a floating-point value for money."
    correct: true
  - text: "The date is assembled by hand in US month/day/year order."
    correct: true
  - text: "totalLabel uses .right alignment and a right anchor, which don't mirror for Arabic."
    correct: true
  - text: "String(format:) can't format Double values."
    correct: false
    why: "It can, with %f; the problem is that it ignores the locale's separators and currency."
  - text: "Arabic apps can't use Auto Layout."
    correct: false
    why: "Auto Layout mirrors leading and trailing constraints automatically for right-to-left languages."
rubric:
  - I found the non-localized plural string.
  - I found the hard-coded currency formatting and Double.
  - I found the hand-built date.
  - I found the right alignment and right anchor.
solution: |
  Four problems:

  1. **Count**: not localizable, and `== 1` is English plural logic. Use `String(localized: "\(count) items", comment: ...)` with plural variants in the catalog.
  2. **Total**: `$` and `%.2f` ignore the receipt's currency and the user's separators, and `Double` can't represent many decimal amounts exactly. Store a `Decimal` and use `.formatted(.currency(code: receipt.currencyCode))`.
  3. **Date**: month/day/year is a US convention. Use `receipt.date.formatted(date: .abbreviated, time: .omitted)`.
  4. **Alignment and anchors**: `.right` and `rightAnchor` stay on the right in Arabic. Use `.natural` (or `.right` only if the design really means "trailing", in which case compute it from the layout direction) and `trailingAnchor`. Mixing `rightAnchor` with `leadingAnchor` constraints in the same layout is also what Apple warns can crash.

  ```swift ios
  import UIKit

  struct Receipt {
      let itemCount: Int
      let total: Decimal
      let currencyCode: String
      let date: Date
  }

  final class ReceiptHeaderView: UIView {
      let itemsLabel = UILabel()
      let totalLabel = UILabel()
      let dateLabel = UILabel()

      func configure(with receipt: Receipt) {
          itemsLabel.text = String(localized: "\(receipt.itemCount) items", comment: "Number of items on a receipt")
          totalLabel.text = receipt.total.formatted(.currency(code: receipt.currencyCode))
          dateLabel.text = receipt.date.formatted(date: .abbreviated, time: .omitted)
          totalLabel.textAlignment = .natural
          for label in [itemsLabel, totalLabel] {
              label.translatesAutoresizingMaskIntoConstraints = false
              addSubview(label)
          }
          NSLayoutConstraint.activate([
              itemsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
              totalLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
          ])
      }
  }
  ```
````

````exercise
id: m27-l07-e4
type: prediction
prompt: "Using the lesson's mirroring function, a 390-point-wide row is laid out by hand. What does this print?"
code: |
  struct Frame {
      var x: Int
      var width: Int
  }

  func mirrored(_ frame: Frame, inWidth containerWidth: Int) -> Frame {
      Frame(x: containerWidth - frame.x - frame.width, width: frame.width)
  }

  let width = 390
  let badge = Frame(x: 20, width: 24)
  let title = Frame(x: 56, width: 250)
  let flippedBadge = mirrored(badge, inWidth: width)
  let flippedTitle = mirrored(title, inWidth: width)
  print(flippedBadge.x, flippedTitle.x)
  print(mirrored(flippedBadge, inWidth: width).x)
  print(width - (flippedTitle.x + flippedTitle.width))
output: |
  346 84
  20
  56
hints:
  - "New x = container width − old x − width."
  - "What happens when you mirror twice?"
  - "The last line measures the gap between the title's right edge and the container's right edge."
solution: |
  ```output
  346 84
  20
  56
  ```

  The badge: 390 − 20 − 24 = 346. The title: 390 − 56 − 250 = 84. Mirroring twice gives the original position back (20), which is a quick way to check a mirroring function. The last line is the gap on the right of the mirrored title, 390 − (84 + 250) = 56: the title's left inset in the left-to-right layout became its right inset. With Auto Layout and leading and trailing constraints, UIKit does this for you; this arithmetic is only for code that sets frames by hand.
````

````exercise
id: m27-l07-e5
type: explain
prompt: "A teammate's unit test asserts that a formatted delivery date equals \"Mar 5, 2026\". It passes on their Mac and fails on CI. Explain the likely causes and how to fix the test."
rubric:
  - The formatter uses the current locale, which differs between machines.
  - The current time zone can move the instant to another calendar day.
  - Fix - pin Locale, TimeZone and Calendar in the format style and when building the date.
  - Suggests testing the logic (which date, which fields) rather than locale data where possible.
solution: |
  `date.formatted(...)` with no locale uses the **current** locale, and the current **time zone**. The developer's Mac is set to US English in a US time zone; the CI runner may be configured with a different locale (giving "5 Mar 2026" or "5. März 2026") or UTC, and an instant near midnight can fall on March 4 or 6 in another time zone.

  The fix is to pin everything that matters: build the date with a `Calendar` whose `timeZone` is fixed, and format with `.locale(Locale(identifier: "en_US"))` and the same `timeZone` set on the format style, as the lesson's formatting example does. Even then, the expected string comes from locale data that the OS can update, so where you can, assert on the logic instead (the computed delivery date's components, or that the style includes year, month and day) and keep only a few pinned-format assertions.
````

## Summary

- Internationalize first (code that never assumes a language, format or direction), then localize (translations and resources).
- Wrap all user-facing text, including accessibility text, in `String(localized:)` with comments; use interpolation for whole sentences and explicit keys or tables when needed. Building fills the String Catalog.
- Plural forms vary by language: English has one and other, French puts 0 in one, Russian adds few and many, Arabic has six categories, Japanese has one. Use plural variations, never `count == 1`.
- Format numbers, money (`Decimal`) and dates with `FormatStyle` in the user's locale. Pin `Locale`, `TimeZone` and `Calendar` when output must be reproducible, and don't over-trust hard-coded expected strings.
- Lay out with leading and trailing, `.natural` alignment and forward-pointing symbols; keep playback and spatial controls unmirrored; mirror manual frames as width − x − width.
- Test each language and region from the scheme's App Language and App Region.
