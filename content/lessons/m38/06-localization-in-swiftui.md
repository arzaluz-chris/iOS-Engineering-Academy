---
id: m38-l06
title: Localization in SwiftUI
description: "Module 27 localized a UIKit app with String(localized:), String Catalogs, plural variants, FormatStyle and leading/trailing constraints. SwiftUI does much of that implicitly, which is convenient until a string isn't translated and you can't see why. You learn when Text localizes and when it doesn't, how interpolation becomes a catalog key, where LocalizedStringResource fits, how plural variants and automatic grammar agreement choose a form, how to format values inside Text, how to preview another locale, and what mirrors in right-to-left layouts."
module: m38
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m38-l05, m27-l07]
objectives:
  - Predict whether a Text, Button or Label localizes its string, and fix one that doesn't.
  - Read the catalog key SwiftUI creates from an interpolated string (%lld, %@) and add a translator comment.
  - Pass localizable text through models with LocalizedStringResource instead of String.
  - Pluralize with catalog variants or with automatic grammar agreement, and know how a form is chosen.
  - Format numbers, currency and dates inside Text with FormatStyle so they follow the environment's locale.
  - Preview a view in another locale and in right-to-left, and decide which images must mirror.
terms:
  - term: LocalizedStringKey
    definition: "SwiftUI's key type for localized lookup. It's ExpressibleByStringLiteral and supports interpolation, so Text(\"Hello\") and Text(\"\\(count) recipes\") create keys; the interpolations become format specifiers like %lld and %@."
  - term: LocalizedStringResource
    definition: "A Foundation type (iOS 16) that carries a localizable string's key, table, bundle and default value until it's resolved. Text(_:) accepts one, so models can hold localizable text without being SwiftUI-specific."
  - term: Automatic grammar agreement
    definition: "Foundation's inflection (iOS 15): Markdown like ^[\\(count) recipe](inflect: true) in a localized string is rewritten to agree with the number (or with other grammatical information) in supported languages."
  - term: Layout direction
    definition: "The environment's LayoutDirection, leftToRight or rightToLeft. SwiftUI lays out leading and trailing according to it, and mirrors stacks and system controls automatically in right-to-left languages."
mastery:
  - Explain why Text(recipe.title) shows the English title in a Spanish app, and choose between LocalizedStringResource and leaving it verbatim.
  - Write the catalog key for Text("Serves \(count)") and give translators a comment.
  - Pick the plural form for a count from a catalog entry, including fallback to other.
  - Show a price and a date in Text with a format style, and preview them in de_DE.
  - Preview a screen right-to-left and mark a custom arrow image to mirror while leaving a photo and a checkmark alone.
resources: [xcode-string-catalog, swiftui-environmentvalues, uikit-semantic-content-attribute, swift-book-strings, hig]
cards:
  - id: m38-l06-c1
    front: When does Text localize?
    back: "Text(\"literal\") and Text(\"literal \\(value)\") create a LocalizedStringKey and look it up. Text(someString) with a String variable shows it verbatim, as does Text(verbatim:). To localize text held in a model, store a LocalizedStringResource."
  - id: m38-l06-c2
    front: What key does Text("\(count) recipes for \(name)") create?
    back: "\"%lld recipes for %@\": an Int interpolation becomes %lld and a String becomes %@. That's the key in the String Catalog, and the place to add plural variants for %lld."
  - id: m38-l06-c3
    front: Two ways to pluralize in SwiftUI?
    back: "Catalog variants: Vary by Plural on the key, and translators fill one/few/many/other per language. Automatic grammar agreement: Text(\"^[\\(count) recipe](inflect: true)\") lets Foundation inflect the noun, in languages that support it (check InflectionRule.canInflect(language:))."
  - id: m38-l06-c4
    front: How do you format a price inside Text?
    back: "Text(price, format: .currency(code: \"EUR\")) or interpolate: Text(\"Total: \\(price, format: .currency(code: \"EUR\"))\"). Both use the environment's locale, so .environment(\\.locale, Locale(identifier: \"de_DE\")) changes the output in a preview."
  - id: m38-l06-c5
    front: What mirrors in right-to-left, and what doesn't?
    back: "Stacks, leading/trailing padding and alignment, navigation and system controls mirror automatically. Icons for direction or reading order (back, forward, text alignment) should mirror; use flipsForRightToLeftLayoutDirection(true) for custom ones. Photos, logos, checkmarks and clocks shouldn't."
---

## The idea in one sentence

In SwiftUI **a string literal is a localization key** and a `String` value is not, so most of localization comes down to knowing which one each view receives.

> [!note] About this lesson's code
> SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run, so no translation was seen on screen. Behavior comes from Apple's pages for `LocalizedStringKey`, `Text` (`init(_:tableName:bundle:comment:)`, `init(verbatim:)`, `init(_:)` for `StringProtocol` and for `LocalizedStringResource`, `init(_:format:)`), `LocalizedStringResource`, `InflectionRule`, `locale` and `layoutDirection` in `EnvironmentValues`, `flipsForRightToLeftLayoutDirection(_:)`, the articles "Preparing views for localization" and "Localizing and varying text with a string catalog," and the Human Interface Guidelines page "Right to left," read in November 2026. The overload model, plural lookup, formatting and mirroring logic are plain Swift, compiled and run with Swift 6.3. The concepts (catalogs, plural categories, FormatStyle, pinned locales, RTL) are in Module 27, lesson 7.

## Literals localize, variables don't

Apple's `LocalizedStringKey` page states the rule: "When you use the initializer `Text("Hello")`, SwiftUI creates a `LocalizedStringKey` for you and uses that to look up a localization of the `Hello` string." And: "Types whose initializers take a `LocalizedStringKey` usually have a corresponding initializer that accepts a parameter that conforms to `StringProtocol`. Passing a `String` variable to these initializers avoids localization." `Button`, `Label`, `Toggle`, `Picker`, `navigationTitle` and many more follow the same pattern.

So the same view behaves differently depending on what you pass. Here's a model with a key type and a `Text` stand-in that have the same two initializers. The key type records the key a catalog would use:

```swift
/// A stand-in for LocalizedStringKey: built from a literal, it records the catalog key.
struct LocalizationKey: ExpressibleByStringInterpolation {
    let key: String

    init(stringLiteral value: String) {
        key = value
    }

    init(stringInterpolation: KeyBuilder) {
        key = stringInterpolation.key
    }

    struct KeyBuilder: StringInterpolationProtocol {
        var key = ""
        init(literalCapacity: Int, interpolationCount: Int) {}
        mutating func appendLiteral(_ literal: String) { key += literal }
        mutating func appendInterpolation(_ value: Int) { key += "%lld" }
        mutating func appendInterpolation(_ value: String) { key += "%@" }
    }
}

/// A stand-in for Text, with the same kinds of initializer.
struct Label {
    let description: String

    init(_ key: LocalizationKey) {
        description = "looks up \"\(key.key)\""
    }

    @_disfavoredOverload
    init<S: StringProtocol>(_ content: S) {
        description = "shows \"\(content)\" as is"
    }

    init(verbatim content: String) {
        description = "shows \"\(content)\" as is"
    }
}

let userName = "Christian"
let recipeCount = 3
let title = "Recipes"

print(Label("Recipes").description)
print(Label(title).description)
print(Label("Hello, \(userName)").description)
print(Label("\(recipeCount) recipes").description)
print(Label(verbatim: "v2.4.1").description)
```

```output
looks up "Recipes"
shows "Recipes" as is
looks up "Hello, %@"
looks up "%lld recipes"
shows "v2.4.1" as is
```

Line by line:

1. **A literal** becomes a key and is looked up.
2. **A `String` variable** with the same characters is shown as is. This is the most common localization bug in SwiftUI: a title stored in a model as `String` never gets translated, even if the catalog has it.
3. **Interpolation** builds a key with a placeholder: a `String` becomes `%@`. The catalog entry is "Hello, %@", and the translation decides where the name goes ("Hola, %@", "%@さん、こんにちは").
4. **An `Int`** becomes `%lld`, the specifier Apple's catalog article uses for plurals ("`%lld` representing a 64-bit integer").
5. **`verbatim:`** says "never localize this": version numbers, user names, codes.

> [!warning] A model
> `@_disfavoredOverload` is an underscored, unofficial attribute. The model needs it so a literal prefers the key initializer, which is what Apple documents for `Text`; how SwiftUI achieves that isn't part of its documentation, and you shouldn't need the attribute in your own code. The real `LocalizedStringKey` also handles other interpolated types (`Double`, `Date` with a style, values with a format style), each with its own specifier.

### Comments for translators

"Save" could be a verb or a noun; "Home" a screen or a house. Apple's "Preparing views for localization": "To add a hint, use the optional `comment` parameter to the text view initializer." Xcode puts the comment next to the string in the catalog:

```swift ios
import SwiftUI

struct RecipeHeader: View {
    let servings: Int
    let authorName: String

    var body: some View {
        VStack(alignment: .leading) {
            Text("Serves \(servings)",
                 comment: "Number of portions a recipe makes. Shown under the recipe title.")
            Text("By \(authorName)",
                 comment: "Recipe author credit. The argument is the author's display name.")
                .foregroundStyle(.secondary)
            Label {
                Text("Save", comment: "Button that saves the recipe to the user's collection (verb).")
            } icon: {
                Image(systemName: "bookmark")
            }
        }
    }
}
```

The catalog gets "Serves %lld" and "By %@" with those comments. `Label("Save", systemImage:)` would also be localized, but it has no `comment` parameter; Apple's article shows the `Label { Text(…, comment:) } icon: { … }` form for that reason.

## Localizable text in models

A recipe category stored as `String` is shown verbatim by `Text(category.title)`. You could write `Text(LocalizedStringKey(category.title))`, which Apple suggests "in the case where you want to localize the value of a string variable," but Xcode can't see which strings will end up in that variable, so it can't add them to the catalog.

The better fit is `LocalizedStringResource` (iOS 16), "a reference to a localizable string" that `Text` accepts directly (`init(_ resource: LocalizedStringResource)`). A literal assigned to a `LocalizedStringResource` is extracted into the catalog like a `Text` literal:

```swift ios
import SwiftUI

enum MealType: CaseIterable, Identifiable {
    case breakfast, lunch, dinner

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }
}

struct MealPicker: View {
    @Binding var selection: MealType

    var body: some View {
        Picker("Meal", selection: $selection) {
            ForEach(MealType.allCases) { meal in
                Text(meal.title)
            }
        }
    }
}
```

- **The model has no SwiftUI import requirement.** `LocalizedStringResource` is Foundation, so the same enum works in a widget, an App Intent or a notification.
- **Resolution is delayed.** The resource carries the key and resolves for the locale where it's displayed, not where it was created.
- **Data from the server or the user isn't localized.** A recipe title someone typed stays `String` and is shown verbatim. That's correct: you can't translate content with a catalog.

## Plurals

### Catalog variants

Module 27 showed why "1 recipe / 3 recipes" logic in code fails in other languages, and how Vary by Plural gives translators one variant per plural category. In SwiftUI there's nothing extra to write: `Text("\(count) recipes")` creates the key "%lld recipes", and you add variants to that key in the catalog. Apple: "Xcode adds One and Other variants for English when it's the source localization, and One, Few, Many, and Other variants for Russian when you add Russian."

At run time the system finds the count's category in the user's language and picks that variant. A model of the lookup, with the category rules from Module 27 cut down to three languages:

```swift
import Foundation

enum PluralCategory {
    case zero, one, two, few, many, other
}

/// CLDR rules for whole numbers, from Module 27 (two languages plus a default).
func pluralCategory(for n: Int, language: String) -> PluralCategory {
    switch language {
    case "en":
        return n == 1 ? .one : .other
    case "ru":
        let lastDigit = n % 10, lastTwo = n % 100
        if lastDigit == 1 && lastTwo != 11 { return .one }
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return .few }
        return .many
    default:
        return .other
    }
}

/// The catalog entry for the key "%lld recipes": the variants translators filled in.
let recipesEntry: [String: [PluralCategory: String]] = [
    "en": [.one: "%lld recipe", .other: "%lld recipes"],
    "ru": [.one: "%lld рецепт", .few: "%lld рецепта", .many: "%lld рецептов"],
    "ja": [.other: "レシピ%lld件"],
]

func localizedRecipes(_ count: Int, language: String) -> String {
    // A language with no translation falls back to the source language, English.
    let resolvedLanguage = recipesEntry[language] == nil ? "en" : language
    let variants = recipesEntry[resolvedLanguage] ?? [:]
    let category = pluralCategory(for: count, language: resolvedLanguage)
    let template = variants[category] ?? variants[.other] ?? "%lld recipes"
    return template.replacingOccurrences(of: "%lld", with: String(count))
}

for language in ["en", "ru", "ja", "fr"] {
    let samples = [1, 3, 5, 21].map { localizedRecipes($0, language: language) }
    print(language + ":", samples.joined(separator: " | "))
}
```

```output
en: 1 recipe | 3 recipes | 5 recipes | 21 recipes
ru: 1 рецепт | 3 рецепта | 5 рецептов | 21 рецепт
ja: レシピ1件 | レシピ3件 | レシピ5件 | レシピ21件
fr: 1 recipe | 3 recipes | 5 recipes | 21 recipes
```

- **Russian** uses three forms for whole numbers: 21 takes the same form as 1 (рецепт), 3 takes "few," 5 takes "many."
- **Japanese** has a single form, `other`, and puts the number in a different place in the sentence. Placement is the translator's choice because the placeholder is part of the variant.
- **French** isn't translated in this model, so the user sees the source language. The model simplifies what the system does with missing translations; the catalog editor shows which ones are missing.

> [!warning] A model
> The real lookup is done by Foundation from compiled catalogs, with CLDR's complete rules (Module 27 listed what this subset leaves out). The model shows the shape of the decision: category from the number and language, variant from the category, `other` when a variant is missing.

### Automatic grammar agreement

Foundation (iOS 15) can also inflect words for you. In a localized string, Markdown marks the part that has to agree with a number:

```swift ios
import SwiftUI

struct RecipeCount: View {
    let count: Int

    var body: some View {
        Text("You saved ^[\(count) recipe](inflect: true)")
    }
}
```

In English, with `count` 1 it reads "You saved 1 recipe"; with 3, "You saved 3 recipes": the noun is inflected to agree with the number, without plural variants in the catalog. Apple's `InflectionRule` page describes the mechanism: "strings in your app's strings files use the Markdown extension syntax to indicate portions of the string that may require inflection to agree grammatically," and the transformation "occurs when you load the attributed string with methods like `init(localized:options:table:bundle:locale:comment:)`."

It only works for languages Foundation knows how to inflect. When it launched it covered English and Spanish; Apple has added languages since, so ask at run time instead of relying on a list: `InflectionRule.canInflect(language:)` "returns a Boolean value that indicates whether the rule can inflect a given language." For a language it can't inflect, the catalog's plural variants are still the reliable tool. Inflection also handles grammatical gender (`Morphology`, `TermOfAddress` in iOS 17), which plural variants can't.

## Formatting values in Text

Module 27 formatted with `FormatStyle` and pinned locales in tests. In SwiftUI you rarely call `formatted()` yourself: `Text` takes the value and the style, and formats with **the environment's locale**:

```swift ios
import SwiftUI

struct OrderSummary: View {
    let total: Decimal
    let currencyCode: String
    let deliveryDate: Date
    let itemCount: Int
    let discount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(total, format: .currency(code: currencyCode))
                .font(.title.bold())
            Text("Arrives \(deliveryDate, format: .dateTime.weekday(.wide).day().month())")
            Text("\(itemCount) items")
            Text("Discount: \(discount, format: .percent)")
            Text(deliveryDate, style: .relative)
                .foregroundStyle(.secondary)
        }
    }
}

struct OrderSummaryInGermany: View {
    var body: some View {
        OrderSummary(total: 1234.5, currencyCode: "EUR", deliveryDate: .now,
                     itemCount: 3, discount: 0.15)
            .environment(\.locale, Locale(identifier: "de_DE"))
    }
}
```

- **`Text(_:format:)`** (iOS 15) "creates a text view that displays the formatted representation of a nonstring type supported by a corresponding format style." The price uses the locale's symbol position and separators.
- **Interpolation with a format** (`\(deliveryDate, format: …)`) formats inside a localized sentence. The catalog key gets a placeholder, so translators can move the date within the sentence.
- **`Text(_:style: .relative)`** shows the date "relative to now," in the user's language.
- **`.environment(\.locale, …)`** changes the locale for a subtree. That's how you check formatting in a preview, and how `OrderSummaryInGermany` shows "1.234,50 €"-style output without changing the simulator's settings. To see whole translations, run the app with a different App Language in the scheme options (Module 27).

The same separation helps in plain Swift: a function that takes the locale as a parameter, the way a view gets it from the environment, can be tested with pinned locales. These are locales whose output Module 27 verified on both Linux and macOS:

```swift
import Foundation

/// What a view model computes for a price label; the locale comes from outside, like \.locale.
func priceLabel(_ amount: Decimal, currencyCode: String, locale: Locale) -> String {
    amount.formatted(.currency(code: currencyCode).locale(locale))
}

func servingsLabel(_ servings: Int, locale: Locale) -> String {
    servings.formatted(.number.locale(locale))
}

let price = Decimal(string: "1234.5")!
print(priceLabel(price, currencyCode: "USD", locale: Locale(identifier: "en_US")))
print(priceLabel(price, currencyCode: "GBP", locale: Locale(identifier: "en_GB")))
print(servingsLabel(1234567, locale: Locale(identifier: "en_US")))
print(servingsLabel(1234567, locale: Locale(identifier: "de_DE")))
```

```output
$1,234.50
£1,234.50
1,234,567
1.234.567
```

Keep the caution from Module 27: some locales use non-breaking spaces, and locale data changes with OS releases, so pin the locale in tests and prefer checking your logic (which currency code, which fields) over long hard-coded strings.

## Right-to-left

The Human Interface Guidelines: "System-provided UI frameworks support right-to-left (RTL) by default, allowing system-provided UI components to flip automatically in the RTL context." In SwiftUI that covers stacks, `leading`/`trailing` alignment and padding, navigation, lists and controls. Your part is images and anything you positioned with absolute directions.

The HIG's rules for icons, as a decision table:

```swift
enum LayoutDirection {
    case leftToRight, rightToLeft
}

enum IconKind {
    case motion           // back, forward, next, previous
    case textDirection    // text alignment, a list with bullets
    case universalMark    // checkmark, plus
    case realWorldObject  // clock, camera
    case logoOrPhoto
}

struct Icon {
    let name: String
    let kind: IconKind
}

/// Whether an icon is drawn mirrored, following the "Right to left" guidance.
func isMirrored(_ icon: Icon, in direction: LayoutDirection) -> Bool {
    guard direction == .rightToLeft else { return false }
    switch icon.kind {
    case .motion, .textDirection:
        return true
    case .universalMark, .realWorldObject, .logoOrPhoto:
        return false
    }
}

/// Where a leading or trailing item ends up on screen.
func screenSide(leading: Bool, in direction: LayoutDirection) -> String {
    (leading == (direction == .leftToRight)) ? "left" : "right"
}

let icons = [
    Icon(name: "back arrow", kind: .motion),
    Icon(name: "align text", kind: .textDirection),
    Icon(name: "checkmark", kind: .universalMark),
    Icon(name: "clock", kind: .realWorldObject),
    Icon(name: "recipe photo", kind: .logoOrPhoto),
]

for direction in [LayoutDirection.leftToRight, .rightToLeft] {
    let mirrored = icons.filter { isMirrored($0, in: direction) }.map(\.name)
    print("\(direction): leading item on the \(screenSide(leading: true, in: direction)), mirrored: \(mirrored)")
}
```

```output
leftToRight: leading item on the left, mirrored: []
rightToLeft: leading item on the right, mirrored: ["back arrow", "align text"]
```

The HIG's wording behind each row: "Flip an interface icon that shows forward or backward motion"; "Flip interface icons that represent text or reading direction"; "Don't flip logos or universal signs and marks"; "avoid flipping interface icons that depict real-world objects" ("clocks work the same everywhere"); "Avoid flipping images like photographs, illustrations, and general artwork." It also says the digits of a number never reverse: "541" stays "541."

In SwiftUI:

```swift ios
import SwiftUI

struct StepRow: View {
    let step: Int
    let instruction: String

    var body: some View {
        HStack(spacing: 12) {
            Text(step, format: .number)
                .font(.headline)
                .frame(minWidth: 28)
            Text(instruction)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image("next-step-arrow")
                .flipsForRightToLeftLayoutDirection(true)
                .accessibilityHidden(true)
            Image(systemName: "checkmark.circle")
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
    }
}

struct StepRowRightToLeft: View {
    var body: some View {
        StepRow(step: 2, instruction: "Whisk the eggs with the sugar.")
            .environment(\.layoutDirection, .rightToLeft)
    }
}
```

- **The `HStack` mirrors** by itself: the step number moves to the right edge, the arrow to the left.
- **`alignment: .leading`** is right-aligned in right-to-left. Never write `.left` for text that should follow the reading direction.
- **The custom arrow** gets `.flipsForRightToLeftLayoutDirection(true)`: "Sets whether this view mirrors its contents horizontally when the layout direction is right-to-left." The checkmark doesn't.
- **SF Symbols** handle their own directional variants. The HIG: "When you use SF Symbols to supply interface icons for your app, you get variants for the RTL context." Prefer names that say direction semantically, such as `chevron.forward` rather than `chevron.right`.
- **`.environment(\.layoutDirection, .rightToLeft)`** previews the mirrored layout without an RTL translation. Real Arabic or Hebrew text is still worth checking, because it changes line lengths and fonts too.

To preview several configurations side by side, put the environment modifiers in `#Preview` blocks:

```swift illustrative
#Preview("German") {
    OrderSummary(total: 1234.5, currencyCode: "EUR", deliveryDate: .now, itemCount: 3, discount: 0.15)
        .environment(\.locale, Locale(identifier: "de_DE"))
}

#Preview("Right to left") {
    StepRow(step: 2, instruction: "Whisk the eggs with the sugar.")
        .environment(\.layoutDirection, .rightToLeft)
}
```

(Illustrative because `#Preview` needs Xcode's preview macros.)

## Common mistakes

> [!error] A String where a key was meant
> `let title = "Settings"; Text(title)` is never translated, and Xcode doesn't extract it. Pass the literal, store a `LocalizedStringResource`, or use `String(localized:)` when you need a `String`.

> [!error] Concatenating translated pieces
> `Text("Serves") + Text(" \(servings)")` gives translators two fragments and no way to reorder them. One sentence, one key: `Text("Serves \(servings)")`.

> [!error] Plural logic in code
> `count == 1 ? "recipe" : "recipes"` is English grammar. Use a single key with plural variants, or automatic grammar agreement where it's supported.

> [!error] Formatting with string interpolation
> `Text("\(price) €")` hard-codes the symbol and its position and uses `Decimal`'s default description. Use `Text(price, format: .currency(code: "EUR"))`.

> [!error] Absolute directions
> `.padding(.left)`, `alignment: .left`, an arrow image that always points right. Use leading and trailing, and mark directional custom images with `flipsForRightToLeftLayoutDirection(true)`.

> [!error] Mirroring everything
> Flipping a photo, a logo or a checkmark changes its meaning. Mirror only what shows direction or reading order.

## Exercises

````exercise
id: m38-l06-e1
type: prediction
prompt: "The key model from the lesson. What does it print?"
code: |
  struct LocalizationKey: ExpressibleByStringInterpolation {
      let key: String

      init(stringLiteral value: String) {
          key = value
      }

      init(stringInterpolation: KeyBuilder) {
          key = stringInterpolation.key
      }

      struct KeyBuilder: StringInterpolationProtocol {
          var key = ""
          init(literalCapacity: Int, interpolationCount: Int) {}
          mutating func appendLiteral(_ literal: String) { key += literal }
          mutating func appendInterpolation(_ value: Int) { key += "%lld" }
          mutating func appendInterpolation(_ value: String) { key += "%@" }
      }
  }

  struct Label {
      let description: String

      init(_ key: LocalizationKey) {
          description = "key: \(key.key)"
      }

      @_disfavoredOverload
      init<S: StringProtocol>(_ content: S) {
          description = "verbatim: \(content)"
      }
  }

  let city = "Lisbon"
  let nights = 4
  let headline = "Trips"
  print(Label("\(nights) nights in \(city)").description)
  print(Label(headline).description)
  print(Label("Trips").description)
  print(Label("Trip to " + city).description)
output: |
  key: %lld nights in %@
  verbatim: Trips
  key: Trips
  verbatim: Trip to Lisbon
hints:
  - "A + between two strings produces a String value before the initializer sees it."
solution: |
  ```output
  key: %lld nights in %@
  verbatim: Trips
  key: Trips
  verbatim: Trip to Lisbon
  ```

  The interpolated literal becomes the key "%lld nights in %@". The variable `headline` is a `String`, so it's verbatim even though a literal with the same text is localized. The last line is the subtle one: `"Trip to " + city` is an expression whose result is a `String`, not a literal, so it's verbatim too. In SwiftUI, `Text("Trip to " + city)` is never translated; `Text("Trip to \(city)")` is.
````

````exercise
id: m38-l06-e2
type: prediction
prompt: "The plural lookup model for the key \"%lld comments\" with a partial Polish translation. What does it print?"
code: |
  import Foundation

  enum PluralCategory {
      case one, few, many, other
  }

  func pluralCategory(for n: Int, language: String) -> PluralCategory {
      switch language {
      case "en":
          return n == 1 ? .one : .other
      case "pl":
          let lastDigit = n % 10, lastTwo = n % 100
          if n == 1 { return .one }
          if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return .few }
          return .many
      default:
          return .other
      }
  }

  let entry: [String: [PluralCategory: String]] = [
      "en": [.one: "%lld comment", .other: "%lld comments"],
      "pl": [.one: "%lld komentarz", .few: "%lld komentarze", .other: "%lld komentarzy?"],
  ]

  func localized(_ count: Int, language: String) -> String {
      let variants = entry[language] ?? entry["en"]!
      let category = pluralCategory(for: count, language: entry[language] == nil ? "en" : language)
      let template = variants[category] ?? variants[.other]!
      return template.replacingOccurrences(of: "%lld", with: String(count))
  }

  print([1, 2, 5, 12, 22].map { localized($0, language: "pl") })
  print(localized(1, language: "de"))
output: |
  ["1 komentarz", "2 komentarze", "5 komentarzy?", "12 komentarzy?", "22 komentarze"]
  1 comment
hints:
  - "Polish 5 and 12 are \"many\", which this entry doesn't have."
  - "German has no entry, so the English variants and rules are used."
solution: |
  ```output
  ["1 komentarz", "2 komentarze", "5 komentarzy?", "12 komentarzy?", "22 komentarze"]
  1 comment
  ```

  Polish (in this cut-down rule) has one, few and many for whole numbers. 1 is "one," 2 and 22 are "few," and 5 and 12 (a teen) are "many." The translator didn't fill in "many," so those counts fall back to "other," which here holds a placeholder with a question mark: exactly the kind of gap the catalog editor flags as incomplete. German has no translation, so the source language and its rules are used.
````

````exercise
id: m38-l06-e3
type: prediction
prompt: "The mirroring rules from the lesson, for a media player. What does this print?"
code: |
  enum LayoutDirection {
      case leftToRight, rightToLeft
  }

  enum IconKind {
      case motion, textDirection, universalMark, realWorldObject, logoOrPhoto
  }

  func isMirrored(_ kind: IconKind, in direction: LayoutDirection) -> Bool {
      guard direction == .rightToLeft else { return false }
      switch kind {
      case .motion, .textDirection: return true
      case .universalMark, .realWorldObject, .logoOrPhoto: return false
      }
  }

  let player: [(String, IconKind)] = [
      ("skip forward", .motion), ("album art", .logoOrPhoto), ("headphones", .realWorldObject),
      ("lyrics", .textDirection), ("plus", .universalMark),
  ]
  let mirrored = player.filter { isMirrored($0.1, in: .rightToLeft) }.map(\.0)
  print(mirrored.joined(separator: ", "))
  print(player.filter { isMirrored($0.1, in: .leftToRight) }.count)
output: |
  skip forward, lyrics
  0
hints:
  - "In left-to-right nothing is mirrored."
solution: |
  ```output
  skip forward, lyrics
  0
  ```

  "Skip forward" depicts motion in reading direction, and a lyrics icon made of text lines follows reading direction: both mirror. The album art is artwork, headphones are a real-world object, and plus is a universal mark: none mirror. (The HIG notes that playback controls depicting tape direction are a special case worth checking; that's a design decision beyond this table.)
````

````exercise
id: m38-l06-e4
type: comprehension
prompt: "A Category model has `let name: String` with values like \"Desserts\" set in code. The app is translated into Spanish, the catalog has \"Desserts\" = \"Postres\", but Text(category.name) shows \"Desserts\". Why?"
choices:
  - text: "Text with a String variable uses the StringProtocol initializer, which displays the string verbatim without lookup."
    correct: true
    why: "Only literals (LocalizedStringKey) and LocalizedStringResource values are looked up. Change name to LocalizedStringResource."
  - text: "The catalog needs a comment for the string to be used."
    correct: false
    why: "Comments help translators; they don't affect lookup."
  - text: "Spanish is a right-to-left language."
    correct: false
    why: "Spanish is left-to-right, and direction doesn't affect string lookup."
  - text: "Text only localizes inside a Form."
    correct: false
    why: "Text localizes literals anywhere."
solution: |
  **The verbatim initializer.** Apple: "Passing a `String` variable to these initializers avoids localization." Declare `let name: LocalizedStringResource` and set it with a literal (`name: "Desserts"`); `Text(category.name)` then uses `init(_ resource:)`, and Xcode extracts the literal into the catalog. If the names came from a server, they'd need server-side localization instead.
````

````exercise
id: m38-l06-e5
type: find-errors
prompt: "This order row was written for English only. Which localization problems are real?"
code: |
  struct OrderRow: View {
      let itemCount: Int
      let total: Double
      let status: String

      var body: some View {
          HStack {
              Text("\(itemCount) " + (itemCount == 1 ? "item" : "items"))
              Spacer()
              Text("$" + String(format: "%.2f", total))
              Text(status)
              Image("arrow-right")
          }
          .padding(.left, 16)
      }
  }
choices:
  - text: "The item count is built by concatenation with English plural logic, so it's a String and never localized."
    correct: true
    why: "Use Text(\"\\(itemCount) items\") with plural variants, or automatic grammar agreement."
  - text: "The price hard-codes the dollar sign, the symbol position and the decimal separator, and uses Double for money."
    correct: true
    why: "Use Decimal and Text(total, format: .currency(code: currencyCode))."
  - text: "status is a String from code, shown verbatim."
    correct: true
    why: "If it's one of a fixed set of states, model it as an enum with LocalizedStringResource titles."
  - text: "The arrow image won't mirror in right-to-left, and .left padding doesn't follow the layout direction."
    correct: true
    why: "Use .flipsForRightToLeftLayoutDirection(true) or a semantic SF Symbol, and .leading padding."
  - text: "HStack doesn't support right-to-left."
    correct: false
    why: "HStack mirrors automatically."
rubric:
  - Flags concatenation and English plural logic.
  - Flags hand-formatted currency and Double for money.
  - Flags the verbatim status string.
  - Flags the non-mirroring arrow and absolute padding.
solution: |
  Four problems. A version that fixes them:

  ```swift ios
  import SwiftUI

  enum OrderStatus {
      case preparing, shipped, delivered

      var title: LocalizedStringResource {
          switch self {
          case .preparing: "Preparing"
          case .shipped: "Shipped"
          case .delivered: "Delivered"
          }
      }
  }

  struct OrderRow: View {
      let itemCount: Int
      let total: Decimal
      let currencyCode: String
      let status: OrderStatus

      var body: some View {
          HStack {
              Text("\(itemCount) items", comment: "Number of items in an order. Needs plural variants.")
              Spacer()
              Text(total, format: .currency(code: currencyCode))
              Text(status.title)
              Image(systemName: "chevron.forward")
                  .accessibilityHidden(true)
          }
          .padding(.leading, 16)
      }
  }
  ```

  The count is one key, "%lld items," for translators to vary by plural. The price is a `Decimal` formatted by the locale. The status is an enum whose titles are localizable resources. The arrow is a semantic SF Symbol, which has right-to-left variants, and the padding is leading.
````

````exercise
id: m38-l06-e6
type: solve
prompt: |
  Write a function that turns a `LayoutDirection` and a row description into what a user sees, left to right on screen, so you can test a row's mirroring without a simulator.

  - A row is a list of items in **logical order** (leading to trailing), each an `Item` with a `name` and `mirrorsInRTL: Bool`.
  - `screenOrder(_ items: [Item], direction: LayoutDirection) -> String` returns the names left to right, joined by `" | "`, adding `"(mirrored)"` after the name of each item drawn mirrored.

  Print the result for the row `[step number, instruction, arrow (mirrors), checkmark]` in both directions.
starter: |
  enum LayoutDirection {
      case leftToRight, rightToLeft
  }

  struct Item {
      let name: String
      let mirrorsInRTL: Bool
  }

  func screenOrder(_ items: [Item], direction: LayoutDirection) -> String {
      // your code
      ""
  }
hints:
  - "In right-to-left, the leading item is on the right: reverse the logical order to get left-to-right on screen."
  - "Mirroring an item doesn't change its position; it changes how it's drawn."
rubric:
  - Keeps logical order in left-to-right and reverses it in right-to-left.
  - Marks only items that mirror, and only in right-to-left.
  - Prints two lines.
solution: |
  ```swift
  enum LayoutDirection {
      case leftToRight, rightToLeft
  }

  struct Item {
      let name: String
      let mirrorsInRTL: Bool
  }

  func screenOrder(_ items: [Item], direction: LayoutDirection) -> String {
      let isRTL = direction == .rightToLeft
      let ordered = isRTL ? Array(items.reversed()) : items
      return ordered
          .map { isRTL && $0.mirrorsInRTL ? "\($0.name) (mirrored)" : $0.name }
          .joined(separator: " | ")
  }

  let row = [
      Item(name: "2", mirrorsInRTL: false),
      Item(name: "Whisk the eggs", mirrorsInRTL: false),
      Item(name: "arrow", mirrorsInRTL: true),
      Item(name: "checkmark", mirrorsInRTL: false),
  ]
  print(screenOrder(row, direction: .leftToRight))
  print(screenOrder(row, direction: .rightToLeft))
  ```

  ```output
  2 | Whisk the eggs | arrow | checkmark
  checkmark | arrow (mirrored) | Whisk the eggs | 2
  ```

  An `HStack` lays its children out from leading to trailing, so in right-to-left the screen shows them in reverse. Mirroring is separate: the arrow is drawn flipped because of `flipsForRightToLeftLayoutDirection(true)`, the checkmark and the number are not, and the digits of "2" (or "541") never reverse. The instruction's text would be Arabic or Hebrew in a real right-to-left localization; here it only shows position.
````

## Summary

- A literal passed to `Text`, `Button`, `Label` and friends is a `LocalizedStringKey`; a `String` variable is shown verbatim. `Text(verbatim:)` makes "don't localize" explicit.
- Interpolation builds the catalog key: `Int` → `%lld`, `String` → `%@`. Add `comment:` for translators, and keep each sentence in one key.
- Store localizable text in models as `LocalizedStringResource`; leave user and server content as `String`.
- Pluralize with Vary by Plural on the key, or with `^[…](inflect: true)` where `InflectionRule.canInflect(language:)` says it's supported.
- Format inside `Text` with `format:` (or interpolation with `format:`), and preview other locales with `.environment(\.locale, …)`.
- Right-to-left mirrors stacks and system controls for you. Use leading and trailing, mirror directional custom images with `flipsForRightToLeftLayoutDirection(true)`, and leave photos, logos and universal marks alone.
