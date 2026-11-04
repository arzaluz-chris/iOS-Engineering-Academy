---
id: m43-l05
title: Internationalization at scale
description: "Modules 27 and 38 localized single screens. Pantry is adding German, Japanese and Arabic to an app split across an app target and three Swift packages, with a translation agency and a release every two weeks. You put a String Catalog in each module and look strings up in the right bundle, export and import localizations with Xcode and xcodebuild, give translators context, catch untranslated and broken strings in CI, test long, accented and right-to-left text with Xcode's pseudolanguages and your own pseudolocalizer, sort and format with the user's locale instead of code-point order, and review right-to-left layouts against the Human Interface Guidelines."
module: m43
order: 5
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m43-l04, m27-l07, m38-l06]
objectives:
  - Organize localizable strings across an app and its frameworks and packages, and look each string up in the bundle that owns it.
  - Export and import localizations with Xcode and xcodebuild, and know what an Xcode Localization Catalog contains.
  - Check a String Catalog in CI for missing translations, strings needing review and mismatched format specifiers.
  - Test layouts with Xcode's pseudolanguages and a pseudolocalizer that preserves format specifiers.
  - Sort and format user-visible data with locale-aware APIs instead of String's default ordering.
  - Review a right-to-left layout with the HIG's rules for text, numbers, controls, images and icons.
terms:
  - term: Internationalization
    definition: "Making the app able to work in any language and region: localizable APIs, locale-aware formatting, flexible layouts. Localization is then supplying the translations and resources for a specific one."
  - term: Xcode Localization Catalog
    definition: "The .xcloc folder Xcode exports for each language: contents.json, Localized Contents (with an XLIFF file of strings), Notes for screenshots and context, and Source Contents."
  - term: XLIFF
    definition: "XML Localization Interchange File Format, the standard file translators' tools read and write. Xcode puts extracted strings, comments and plural variants into it."
  - term: Pseudolanguage
    definition: "A fake language that transforms your strings (double length, accents, right-to-left, bounded, tall, emoji) so you can find layout problems before real translations exist. Chosen in the scheme's App Language menu."
  - term: "#bundle"
    definition: "A Foundation macro that expands to the bundle most likely to contain resources for the calling code: the main bundle in an app, the framework's bundle in a framework, the resource bundle in a Swift package target."
mastery:
  - Look up a string from a package or framework in its own bundle with #bundle, Bundle.module or BundleDescription.forClass.
  - Run xcodebuild -exportLocalizations and -importLocalizations for a project.
  - Write a CI check that lists untranslated strings and specifier mismatches per language.
  - Pseudolocalize a string without breaking its format specifiers, and explain what each Xcode pseudolanguage finds.
  - Sort product names for display with localizedStandard and explain why sorted() is wrong for it.
  - Decide whether a given icon, control or number should mirror in a right-to-left layout.
resources: [xcode-exporting-localizations, xcode-preparing-interface-localization, xcode-localizing-package-resources, xcode-string-catalog, swiftui-preparing-localization, hig-right-to-left, uikit-semantic-content-attribute, packagedescription-target, foundation-inflectionrule]
cards:
  - id: m43-l05-c1
    front: How does code in a framework or package find its own translations?
    back: "Pass the bundle that owns the strings: #bundle (expands to the right bundle for the calling target), Bundle.module in a package, Bundle(for: SomeClass.self) in a framework, or .forClass(...) for LocalizedStringResource. Without it, lookups use the main bundle and miss the package's catalog."
  - id: m43-l05-c2
    front: Command-line export and import of localizations?
    back: "xcodebuild -exportLocalizations -project <project> -localizationPath <dir> [-exportLanguage <lang>…] (add -includeScreenshots for test screenshots), and xcodebuild -importLocalizations -project <project> -localizationPath <dir>. Enable Use Compiler to Extract Swift Strings so Swift strings are included."
  - id: m43-l05-c3
    front: Name four of Xcode's pseudolanguages and what each finds.
    back: "Double-Length (views that don't grow), Accented (clipping of ascenders and descenders), Bounded String (truncation, by wrapping strings in markers), Right-to-Left (views that don't flip). Also Right-to-Left With Right-to-Left Strings, Tall and Emotional."
  - id: m43-l05-c4
    front: Why not show sorted() product names to users?
    back: "String's < compares Unicode scalar values after normalization: uppercase before lowercase, accented letters after z, \"item 10\" before \"item 9\". Use localizedStandardCompare or sorted(using: .localizedStandard), which sort like the Finder for the current locale."
  - id: m43-l05-c5
    front: Which things don't flip in right-to-left layouts, per the HIG?
    back: "The digits of a number, photos and general artwork, logos, universal marks like a checkmark, icons of real-world objects such as a clock, and controls that refer to an actual direction. Progress, navigation (back points right), ordered sequences and icons showing reading direction or forward motion do flip."
---

## The idea in one sentence

At scale, internationalization stops being about individual strings and becomes **a pipeline**: every module owns its strings, extraction and translation round-trip through files your tools can check, and layout problems are found with fake languages long before the real ones arrive.

> [!note] Sources and what was checked
> The String Catalog workflow, tables, comments and bundles are from Apple's "Localizing and varying text with a string catalog", "Preparing your app's text for translation", "Using generated localizable symbols in your code" and the `#bundle` macro's reference page; export and import from "Exporting localizations" and "Importing localizations"; packages from "Localizing package resources"; pseudolanguages and "Show non-localized strings" from "Preparing your interface for localization"; scheme settings from "Testing localizations when running your app"; right-to-left rules from the Human Interface Guidelines' "Right to left" page; `localizedStandardCompare(_:)`, `localizedStandardContains(_:)` and `SortComparator.localizedStandard` from their reference pages. All read in November 2026. Xcode's catalog editor, export dialog and pseudolanguages weren't used for this lesson. The `.xcstrings` layout used by the CI check is an abridged version of what Xcode writes, as Module 27 showed it; Apple doesn't publish a specification for it, so treat the field names as observed, not guaranteed. Foundation and SwiftUI blocks are type-checked against the iOS SDK, not run. The pseudolocalizer, catalog check, length check and sorting examples are plain Swift, compiled and run with Swift 6.3; the translations in them were written for this lesson, not by a translator.

## Where Pantry starts

Pantry is English-only. Marketing wants German and Japanese next quarter, and Arabic after that. A quick search of the codebase finds:

- Most SwiftUI `Text("…")` literals are already localizable (Module 38), and some UIKit screens use `NSLocalizedString`.
- About 400 user-facing strings are plain `String` values: alert messages built with `+`, labels set from string constants, and every string in the three packages (`CheckoutKit`, `CatalogKit`, `DesignSystem`).
- Prices are formatted with a hard-coded `"$"`; dates with `DateFormatter` and a fixed `"MM/dd/yyyy"` format.
- Product lists are sorted with `sorted()`.

Module 27 covered the basics: `String(localized:)`, comments, plurals, `FormatStyle`, leading and trailing constraints. Finding the remaining strings is step one; Apple's tool for it is in the scheme: Run › Options › **Show non-localized strings**. "When you run your app, the nonlocalized strings appear in all caps." For strings that aren't on screen yet, search for literals in `UILabel.text =`, `setTitle(_:for:)`, `UIAlertController(title:message:…)` and `+` between strings.

## One catalog per module

Apple: "If the number of translations in your string catalog grows too large, consider using multiple string catalogs in one project," selected with the `table` (or `tableName`) parameter. For an app built from modules, the more important boundary is the module itself. Each package or framework owns a catalog, and code looks strings up in **its own bundle**, not the app's.

Apple's article "Preparing your app's text for translation": "When localizable strings reside in another module, framework, or Swift Package, pass the `#bundle` macro as the `bundle` parameter in localizable APIs to tell the system to look up the translation in the bundle associated with that target." The macro "expands to a bundle instance that's most likely to contain resources for the calling code": the main bundle in the app, the framework's bundle in a framework, the package target's resource bundle in a package.

In Pantry's `CheckoutKit` package:

```swift illustrative
// Sources/CheckoutKit/CheckoutStrings.swift
import Foundation

public enum CheckoutStrings {
    public static var placeOrder: String {
        String(localized: "Place order", bundle: #bundle, comment: "Button that submits the order and charges the card")
    }

    public static func itemsInCart(_ count: Int) -> String {
        String(localized: "\(count) items in your cart", bundle: #bundle, comment: "Checkout header; count is the number of products")
    }
}
```

This block is marked illustrative: it belongs in a package target with a `Localizable.xcstrings` resource and `defaultLocalization` in its manifest, which the snippet harness can't build. Apple's reference lists `#bundle` from iOS 15; before Xcode had the macro, packages used `Bundle.module` (generated for targets with resources) and frameworks used `Bundle(for:)`, which you'll see in older code:

```swift ios
import Foundation
import SwiftUI

/// Any class inside the framework works as an anchor for finding its bundle.
final class DesignSystemBundleAnchor {}

enum DesignSystemStrings {
    static var retry: String {
        String(localized: "Retry", bundle: Bundle(for: DesignSystemBundleAnchor.self), comment: "Button that repeats a failed action")
    }

    /// For SwiftUI views and App Intents, which take LocalizedStringResource.
    static var emptyCart: LocalizedStringResource {
        LocalizedStringResource(
            "Your cart is empty",
            bundle: .forClass(DesignSystemBundleAnchor.self),
            comment: "Shown on the cart screen when there are no products"
        )
    }
}

struct EmptyCartView: View {
    var body: some View {
        Text(DesignSystemStrings.emptyCart)
    }
}
```

- **`LocalizedStringResource`** carries its bundle with it (`.main`, `.forClass(_:)` or `.atURL(_:)`), so a view in the app can display a string owned by a package without knowing where it lives. Apple calls it "the recommended type for passing strings in Swift."
- **The lookup happens when the string is displayed**, in the person's language at that moment, which is another reason to pass `LocalizedStringResource` rather than an already-resolved `String` through models (Module 38).
- Apple's warning: "Avoid looking up strings from bundles you don't own. Doing so may prevent automatic string extraction from properly working in the string catalog."

### Packages

From "Localizing package resources": declare `defaultLocalization` in the manifest ("When you declare a value for `defaultLocalization` in the package manifest, Xcode requires the package to contain localized resources"), and keep resources in the target's `Resources` folder. For `.lproj` directories, Apple's rules are ISO 639 language codes with optional region or script designators, no subdirectories inside them, and Xcode warns about "missing resources for a locale" and "duplicate, conflicting, or inaccessible resources."

```swift illustrative
// Package.swift (excerpt)
let package = Package(
    name: "CheckoutKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [.library(name: "CheckoutKit", targets: ["CheckoutKit"])],
    targets: [
        .target(name: "CheckoutKit", resources: [.process("Resources")]),
    ]
)
```

### Symbols instead of literals

Xcode can generate a symbol for each key you add to a catalog: "for strings without format specifiers, Xcode creates static variables; for strings with format specifiers, Xcode creates functions with parameters." A `TITLE` key in a `Discover` catalog becomes `.Discover.title`, a `LocalizedStringResource`. Older projects enable it with the **Generate String Catalog Symbols** build setting. It's useful when the source text changes often (marketing copy) and code shouldn't; it also turns a typo in a key into a compile error.

## The translation round trip

Translators don't open Xcode projects. Apple's workflow:

1. **Export.** Product › Export Localizations, or on CI:

   ```sh
   xcodebuild -exportLocalizations -project Pantry.xcodeproj -localizationPath build/loc \
       -exportLanguage de -exportLanguage ja -exportLanguage ar
   ```

   Apple: "To include all localizable text in your export, enable the Use Compiler to Extract Swift Strings build setting." Add `-includeScreenshots` to ship the screenshots your UI tests captured in each language.
2. **What goes out.** One Xcode Localization Catalog (`.xcloc`) per language: `contents.json` (metadata), `Localized Contents` (the XLIFF with strings, comments and plural variants), `Notes` (screenshots, "movies, or text files" for context) and `Source Contents` (the files that give context).
3. **Context.** Translators work from the comment and the screenshot. "Order" as a noun (an order you placed) and as a verb (to order) are different words in German. Xcode can generate comments ("Generate Comment," or the "Automatically generate string catalog comments" setting), and marks them "auto-generated" in exports; Pantry treats those as a starting point and has someone review the comments for strings that are ambiguous.
4. **Import.** Product › Import Localizations shows warnings and a comparison before applying, or:

   ```sh
   xcodebuild -importLocalizations -project Pantry.xcodeproj -localizationPath build/loc/de.xcloc
   ```

Packages that Xcode exports with the app should have their own catalogs in the export; check the first export to confirm every module's strings are in it before sending anything.

## Checking catalogs in CI

Importing translations shouldn't be the first time anyone notices that the Japanese catalog is 60% done or that a translator deleted a `%lld`. A String Catalog is JSON, so a script can check it on every pull request. Using the abridged structure from Module 27 (Xcode maintains the file; Apple doesn't publish its schema):

```swift
import Foundation

struct StringCatalog: Decodable {
    struct Unit: Decodable { let state: String; let value: String }
    struct Localization: Decodable { let stringUnit: Unit? }
    struct Entry: Decodable { let localizations: [String: Localization]? }
    let sourceLanguage: String
    let strings: [String: Entry]
}

/// Format specifiers such as %lld, %@, %1$@ or %.2f, in order of appearance.
func specifiers(in text: String) -> [String] {
    var found: [String] = []
    var index = text.startIndex
    while index < text.endIndex {
        guard text[index] == "%" else { index = text.index(after: index); continue }
        var end = text.index(after: index)
        while end < text.endIndex, "0123456789$.lhqz".contains(text[end]) { end = text.index(after: end) }
        if end < text.endIndex {
            let specifier = String(text[index...end])
            if specifier != "%%" { found.append(specifier) }
            index = text.index(after: end)
        } else {
            index = end
        }
    }
    return found
}

let json = """
{
  "sourceLanguage": "en",
  "strings": {
    "%lld items in your cart": { "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "%lld Artikel im Warenkorb" } },
      "ja": { "stringUnit": { "state": "translated", "value": "カートに商品があります" } } } },
    "Place order": { "localizations": {
      "de": { "stringUnit": { "state": "needs_review", "value": "Bestellen" } },
      "ja": { "stringUnit": { "state": "translated", "value": "注文する" } } } },
    "Delivery to %@ at %@": { "localizations": {
      "de": { "stringUnit": { "state": "translated", "value": "Lieferung an %1$@ um %2$@" } } } },
    "Retry": {}
  }
}
"""

let catalog = try JSONDecoder().decode(StringCatalog.self, from: Data(json.utf8))
for language in ["de", "ja"] {
    var problems: [String] = []
    for key in catalog.strings.keys.sorted() {
        guard let unit = catalog.strings[key]?.localizations?[language]?.stringUnit else {
            problems.append("missing: \(key)")
            continue
        }
        if unit.state != "translated" { problems.append("\(unit.state): \(key)") }
        let sourceCount = specifiers(in: key).count
        let translatedCount = specifiers(in: unit.value).count
        if sourceCount != translatedCount {
            problems.append("specifiers \(sourceCount) → \(translatedCount): \(key)")
        }
    }
    print("\(language): \(problems.isEmpty ? "ok" : "\(problems.count) problems")")
    for problem in problems { print("  \(problem)") }
}
```

```output
de: 2 problems
  needs_review: Place order
  missing: Retry
ja: 3 problems
  specifiers 1 → 0: %lld items in your cart
  missing: Delivery to %@ at %@
  missing: Retry
```

- **The German delivery string passes** even though it reorders its arguments as `%1$@` and `%2$@`. Positional specifiers are how a translator changes word order; the check counts specifiers instead of comparing them literally for that reason.
- **The Japanese cart string dropped `%lld`.** It reads fine, but the number is gone. That's the kind of bug nobody sees in review, because nobody on the team reads Japanese.
- **`needs_review`** is the state Xcode uses for a translation flagged for review; the check reports any state other than `translated`.
- **Keys are sorted** before checking, because a dictionary's order isn't stable. The real check also walks plural variations (Module 27's `variations.plural`), which this abridged decoder skips, and runs for every catalog in every module.
- A missing translation isn't a crash: the lookup falls back to the development language. That's why it's easy to ship half-translated screens without noticing.

## Testing long and unusual text

### Xcode's pseudolanguages

Apple's "Preparing your interface for localization" lists the pseudolanguages in the scheme's Run › Options › App Language menu:

| Pseudolanguage | What it does (Apple) |
| --- | --- |
| Double-Length | "Doubles the length of localizable strings to test whether views adjust their size and position." |
| Right-to-Left | "Simulates a right-to-left writing direction to test whether views flip accordingly." |
| Right-to-Left With Right-to-Left Strings | The same, "using right-to-left strings." |
| Accented | "Adds accents to localizable strings to test whether views adjust to languages that have high and low ascenders." |
| Bounded String | "Wraps strings to identify places where localized strings may appear truncated." |
| Tall | "Simulates languages that require significantly more vertical space." |
| Emotional | "Simulates emojis in a string." |

Pantry's UI tests run each main screen in Double-Length, Accented and Right-to-Left and save screenshots; a person reviews them when a screen changes. Combined with the largest Dynamic Type size (lesson 4), this finds most layout problems before a translator has seen a single string.

### A pseudolocalizer of your own

Pseudolanguages only transform strings that go through localizable APIs. Pantry also shows server-provided text (product names, promotions) and runs snapshot tests in CI without changing the scheme. A small pseudolocalizer covers both, as long as it never corrupts format specifiers:

```swift
let accented: [Character: Character] = [
    "a": "á", "e": "é", "i": "í", "o": "ö", "u": "ü", "c": "ç", "n": "ñ",
    "A": "Å", "E": "É", "I": "Í", "O": "Ö", "U": "Ü",
]

/// Accents letters, pads by `expansionPercent`, and brackets the result. Format specifiers are copied untouched.
func pseudolocalize(_ text: String, expansionPercent: Int = 40) -> String {
    var output = ""
    var visible = 0
    var index = text.startIndex
    while index < text.endIndex {
        let character = text[index]
        if character == "%" {
            var end = text.index(after: index)
            while end < text.endIndex, "0123456789$.lhqz".contains(text[end]) { end = text.index(after: end) }
            let last = end < text.endIndex ? end : text.index(before: end)
            output += text[index...last]
            index = text.index(after: last)
            continue
        }
        output.append(accented[character] ?? character)
        visible += 1
        index = text.index(after: index)
    }
    let padding = String(repeating: "~", count: (visible * expansionPercent + 99) / 100)
    return "[\(output)\(padding)]"
}

for source in ["Add to cart", "%lld items in your cart", "Delivery to %1$@ at %2$@", "Save 20%%"] {
    print(pseudolocalize(source))
}
```

```output
[Ådd tö çárt~~~~~]
[%lld ítéms íñ yöür çárt~~~~~~~~]
[Délívéry tö %1$@ át %2$@~~~~~~~]
[Sávé 20%%~~~]
```

- **Brackets** show truncation at a glance, like the Bounded String pseudolanguage: a screenshot showing `[Ådd tö çá` means the label cut the text off.
- **Accents** test vertical clipping; **tildes** add 40% of the visible characters, rounded up. Apple's Double-Length pseudolanguage is harsher (100%); 40% is Pantry's choice for a check that runs on every build.
- **Specifiers survive intact**, including positional ones and the escaped `%%`, so formatting still works and the specifier check above still passes on pseudo text.
- **Only visible characters count toward padding.** `"%lld items in your cart"` has 19 visible characters once the specifier is skipped (the space after it counts), so it gets 8 tildes; `"Add to cart"` has 11 and gets 5.

### Length budgets as an early warning

Some labels can't grow: tab bar items, a button in a fixed-width toolbar, a badge. A character budget is a crude proxy for width, but it's cheap and catches the worst cases in the catalog before anyone builds the app:

```swift
struct TightLabel {
    let key: String
    let maxCharacters: Int
}

let translations: [String: [String: String]] = [
    "Cart": ["de": "Warenkorb", "ja": "カート", "fr": "Panier"],
    "Checkout": ["de": "Zur Kasse", "ja": "レジに進む", "fr": "Paiement"],
    "Add to cart": ["de": "In den Warenkorb", "ja": "カートに追加", "fr": "Ajouter au panier"],
]
let tight = [TightLabel(key: "Cart", maxCharacters: 8), TightLabel(key: "Add to cart", maxCharacters: 14)]

for label in tight {
    for language in ["de", "fr", "ja"] {
        guard let text = translations[label.key]?[language] else { continue }
        if text.count > label.maxCharacters {
            print("\(label.key) [\(language)]: \"\(text)\" has \(text.count) characters, budget \(label.maxCharacters)")
        }
    }
}
```

```output
Cart [de]: "Warenkorb" has 9 characters, budget 8
Add to cart [de]: "In den Warenkorb" has 16 characters, budget 14
Add to cart [fr]: "Ajouter au panier" has 17 characters, budget 14
```

- **`count` is characters, not width.** Japanese characters are wider than Latin ones and pass this check while possibly overflowing; Arabic shapes letters differently. The check flags candidates; screenshots decide.
- **The fix is rarely a shorter translation.** It's a layout that can wrap or grow (Module 38's `ViewThatFits`), or a shorter source string chosen with the translator. Width variants exist in String Catalogs for the cases that truly can't grow.

## Sorting and formatting with the user's locale

`sorted()` on strings is deterministic and fast, and wrong for anything a person reads:

```swift
let products = ["zebra cake", "Zoë cookies", "apple pie", "Éclair", "Apple juice", "item 10", "item 9"]
print(products.sorted())
```

```output
["Apple juice", "Zoë cookies", "apple pie", "item 10", "item 9", "zebra cake", "Éclair"]
```

- **Uppercase sorts before lowercase**, so "Zoë" comes before "apple."
- **"Éclair" is last**, after every unaccented letter.
- **"item 10" comes before "item 9"**, comparing character by character.
- Swift's `<` compares strings by Unicode scalar values after canonical normalization, which makes it the same on every device and locale. That's what you want for keys, deduplication and binary search; it's not what people expect in a list.

For display, Apple provides Finder-like comparison: `localizedStandardCompare(_:)` "should be used whenever file names or other strings are presented in lists and tables where Finder-like sorting is appropriate," and its result "is different under different locales." The `SortComparator` form is `.localizedStandard`, "a localized, numeric comparison in the current locale":

```swift ios
import Foundation

struct Product: Identifiable, Sendable {
    let id: Int
    let name: String
    let priceCents: Int
}

func sortedForDisplay(_ products: [Product]) -> [Product] {
    products.sorted(using: KeyPathComparator(\Product.name, comparator: .localizedStandard))
}

func searchMatches(_ products: [Product], query: String) -> [Product] {
    products.filter { $0.name.localizedStandardContains(query) }
}

func cartSummary(names: [String], totalCents: Int, currencyCode: String) -> String {
    let list = names.formatted(.list(type: .and))
    let total = (Decimal(totalCents) / 100).formatted(.currency(code: currencyCode))
    return "\(list): \(total)"
}
```

- **The order depends on the locale**, which is why there's no expected output here: Apple says the exact behavior "may be changed in future releases." Tests that need a fixed order should use a fixed comparator, not the current locale.
- **`localizedStandardContains`** ignores case and diacritics the way people expect in search: "eclair" finds "Éclair."
- **`.list(type: .and)`** joins with the language's own conjunction and punctuation; building "A, B and C" with `joined(separator:)` and `" and "` is an English-only sentence.
- **The currency code comes from the data** (the order's currency), not from the locale; the locale decides how it's written (Module 27).

## Reviewing right-to-left layouts

System components flip automatically: the HIG says that "if you use system-provided elements and standard layouts, you might not need to make any changes." What needs review is everything custom. The HIG's rules, as a checklist for Pantry's Arabic release:

**Flip:**
- Controls that show progress (sliders, progress bars), along with the glyphs at their ends.
- Navigation and ordered access: "a back button must point to the right"; next and previous buttons flip.
- Sequences whose order means something (chronological images, step indicators), and the numerals that label progress, in reversed order.
- Icons that represent text or reading direction, or forward and backward motion.

**Don't flip:**
- The digits of a number: "a phone number, or a credit card number — always appear in the same order."
- Photos, illustrations and general artwork; flipping "often changes the image's meaning."
- Logos and universal marks like the checkmark.
- Icons of real-world objects, such as a clock, and controls that refer to an actual direction ("to the right" always points right).

**Text:** align one- and two-line text with the interface direction, but "align a paragraph based on its language, not on the current context," and keep alignment consistent within a list. Arabic and Hebrew have no uppercase, so next to all-caps Latin text the HIG suggests increasing the RTL font size "by about 2 points."

In code, prefer leading and trailing everywhere, SF Symbols (which have right-to-left variants), and directional symbol names such as `chevron.forward` rather than `chevron.right`. For custom images that should mirror:

```swift ios
import UIKit
import SwiftUI

@MainActor
func configureNextButton(_ button: UIButton) {
    let arrow = UIImage(named: "custom-next-arrow")?.imageFlippedForRightToLeftLayoutDirection()
    button.setImage(arrow, for: .normal)
}

struct StepIndicator: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack {
            Image(systemName: "chevron.forward")           // SF Symbols mirror on their own
            Text("Step \(step) of \(total)")
            Image("delivery-truck")                        // artwork: not flipped
            Image("custom-progress-arrow")
                .flipsForRightToLeftLayoutDirection(true)   // custom directional art: flipped
        }
    }
}
```

Then look at every main screen in the Right-to-Left pseudolanguage and, once translations arrive, in Arabic, with the checklist next to you. Numbers deserve a separate look: Apple notes that "Arabic text might use either Western or Eastern Arabic numerals," and number formatting in the user's locale (rather than string interpolation of an `Int`) handles that.

## Common mistakes

> [!error] Looking up a package's strings in the main bundle
> `String(localized: "Retry")` inside a package looks in the app's catalog, doesn't find the key, and shows the English key. Pass `#bundle` (or `Bundle.module`, or `.forClass`).

> [!error] One giant catalog for the whole app
> Every team edits the same file and every merge conflicts. A catalog per module, owned by the module, keeps strings next to the code that uses them.

> [!error] Exporting without context
> "Order" with no comment and no screenshot gets the wrong German word half the time. Comments for every ambiguous string, screenshots in `Notes`.

> [!error] Finding untranslated strings in production
> Missing translations fall back silently to the development language. Check catalogs in CI for missing, unreviewed and specifier-mismatched strings.

> [!error] Sorting display lists with sorted()
> Code-point order puts uppercase first, accented letters last and "10" before "9." Use `.localizedStandard` for anything a person reads.

> [!error] Flipping everything for right-to-left
> Logos, photos, clocks, checkmarks and the digits of a number keep their orientation. Mirror navigation, progress and reading-direction icons only.

## Exercises

````exercise
id: m43-l05-e1
type: prediction
prompt: "The pseudolocalizer with a 50% expansion. What does it print? (Count only visible characters: specifiers don't count.)"
code: |
  let accented: [Character: Character] = ["a": "á", "e": "é", "o": "ö", "u": "ü"]

  func pseudolocalize(_ text: String, expansionPercent: Int) -> String {
      var output = ""
      var visible = 0
      var index = text.startIndex
      while index < text.endIndex {
          let character = text[index]
          if character == "%" {
              var end = text.index(after: index)
              while end < text.endIndex, "0123456789$.lhqz".contains(text[end]) { end = text.index(after: end) }
              let last = end < text.endIndex ? end : text.index(before: end)
              output += text[index...last]
              index = text.index(after: last)
              continue
          }
          output.append(accented[character] ?? character)
          visible += 1
          index = text.index(after: index)
      }
      let padding = String(repeating: "~", count: (visible * expansionPercent + 99) / 100)
      return "[\(output)\(padding)]"
  }

  print(pseudolocalize("Total", expansionPercent: 50))
  print(pseudolocalize("%@ saved", expansionPercent: 50))
  print(pseudolocalize("%lld", expansionPercent: 50))
output: |
  [Tötál~~~]
  [%@ sávéd~~~]
  [%lld]
hints:
  - "\"Total\" has 5 visible characters; 50% of 5 rounded up is 3."
  - "\"%@ saved\": the specifier isn't counted, but the space is."
solution: |
  ```output
  [Tötál~~~]
  [%@ sávéd~~~]
  [%lld]
  ```

  - **"Total"**: o and a are accented (T and l aren't in the table); 5 visible characters, (5 × 50 + 99) / 100 = 3 tildes.
  - **"%@ saved"**: `%@` is copied; " saved" is 6 visible characters including the space, (6 × 50 + 99) / 100 = 3.
  - **"%lld"**: no visible characters, so no padding. A string that's only a specifier isn't text to translate, and padding it would change a number's display.
````

````exercise
id: m43-l05-e2
type: comprehension
prompt: "CatalogKit, a Swift package, shows `String(localized: \"Out of stock\")` in a product cell. The German catalog in the package has a translation, but German users see \"Out of stock.\" What's the most likely cause?"
choices:
  - text: "The lookup uses the main bundle by default; the package must pass #bundle (or Bundle.module)."
    correct: true
    why: "Apple: when strings reside in another module or package, pass the #bundle macro as the bundle parameter."
  - text: "Swift packages can't contain localized strings."
    correct: false
    why: "They can, with defaultLocalization in the manifest and resources in the target."
  - text: "German needs a plural variant for every string."
    correct: false
    why: "Plural variants are only for strings with a number."
  - text: "The device's region must also be Germany."
    correct: false
    why: "The language setting selects the translation; the region affects formats."
solution: |
  Without a `bundle` argument, `String(localized:)` looks in `Bundle.main`, the app's bundle, which doesn't have the package's key, so the lookup falls back to the key itself. `String(localized: "Out of stock", bundle: #bundle, comment: …)` looks in the package's resource bundle. The same applies to `Text` in SwiftUI (`Text("Out of stock", bundle: #bundle)`) and to `LocalizedStringResource` (`bundle: .forClass(…)` or `.atURL(…)`).
````

````exercise
id: m43-l05-e3
type: fill-in
prompt: "Complete Pantry's CI steps for exporting German and Japanese with screenshots, then importing the returned German catalog."
code: |
  xcodebuild -[[1]] -project Pantry.xcodeproj -localizationPath build/loc \
      -exportLanguage de -exportLanguage ja -[[2]]

  xcodebuild -[[3]] -project Pantry.xcodeproj -localizationPath build/loc/de.[[4]]
blanks:
  - id: "1"
    answers: ["exportLocalizations"]
  - id: "2"
    answers: ["includeScreenshots"]
  - id: "3"
    answers: ["importLocalizations"]
  - id: "4"
    answers: ["xcloc"]
solution: |
  ```sh
  xcodebuild -exportLocalizations -project Pantry.xcodeproj -localizationPath build/loc \
      -exportLanguage de -exportLanguage ja -includeScreenshots

  xcodebuild -importLocalizations -project Pantry.xcodeproj -localizationPath build/loc/de.xcloc
  ```

  `-exportLocalizations` writes one Xcode Localization Catalog (`.xcloc`) per language; `-includeScreenshots` adds the screenshots your localization tests generated to each catalog's `Notes` folder. `-importLocalizations` takes the translated catalog back. Make sure "Use Compiler to Extract Swift Strings" is on, or Swift strings may be missing from the export.
````

````exercise
id: m43-l05-e4
type: find-errors
prompt: "Code from Pantry's order history screen, before internationalization. Mark every real problem."
code: |
  let title = "Order " + order.number + " placed on " + DateFormatter.mmddyyyy.string(from: order.date)
  let total = "$" + String(format: "%.2f", order.total)
  let items = order.itemNames.sorted().joined(separator: ", ")
  let summary = items + " and " + "\(order.extraCount) more"
  backButton.setImage(UIImage(named: "arrow-left"), for: .normal)
choices:
  - text: "The title is built by concatenation, so translators can't reorder its parts."
    correct: true
  - text: "The date uses a fixed MM/dd/yyyy format instead of the user's locale."
    correct: true
  - text: "The total hard-codes a dollar sign and a decimal point."
    correct: true
  - text: "Item names are sorted by code point and joined with an English separator and \"and\"."
    correct: true
  - text: "The back arrow is a fixed left-pointing image that won't flip for right-to-left."
    correct: true
  - text: "String(format:) can't be used with Double."
    correct: false
    why: "It can; the problem is the hard-coded currency and format, not the call."
rubric:
  - I flagged concatenated sentences.
  - I flagged the fixed date format and hard-coded currency.
  - I flagged code-point sorting and the English list.
  - I flagged the non-mirroring back arrow.
solution: |
  - **Sentence by concatenation.** Use one localizable string with interpolation: `String(localized: "Order \(order.number) placed on \(order.date.formatted(date: .abbreviated, time: .omitted))")`. The translator gets one sentence with specifiers they can reorder.
  - **Date and currency.** `FormatStyle` with the user's locale, and the currency code from the order: `order.total.formatted(.currency(code: order.currencyCode))`.
  - **List.** `sorted(using: .localizedStandard)` (via a comparator) and `.formatted(.list(type: .and))`. "and 3 more" also needs a plural variant.
  - **Back arrow.** Use `chevron.backward` from SF Symbols, or `imageFlippedForRightToLeftLayoutDirection()` on the custom image; the HIG says a back button must point right in RTL.
````

````exercise
id: m43-l05-e5
type: solve
prompt: |
  Write `specifierProblems(source:translation:)` for the CI check. Return `"ok"` if both have the same number of format specifiers; otherwise describe the difference as `"source N, translation M"`. Ignore `%%`. Count a specifier as `%` followed by any of `0123456789$.lhqz` and one more character.

  Expected output:

  ```output
  ok
  source 1, translation 0
  ok
  source 2, translation 3
  ok
  ```
starter: |
  func specifierProblems(source: String, translation: String) -> String {
      // your code
      return ""
  }

  print(specifierProblems(source: "%lld items", translation: "%lld Artikel"))
  print(specifierProblems(source: "%lld items", translation: "商品があります"))
  print(specifierProblems(source: "Delivery to %@ at %@", translation: "Lieferung an %1$@ um %2$@"))
  print(specifierProblems(source: "%@ of %@", translation: "%@ von %@ (%@)"))
  print(specifierProblems(source: "Save 20%%", translation: "20%% sparen"))
hints:
  - "Write a helper that counts specifiers; call it twice."
  - "Skip characters until %, then skip the flag characters, then take one more."
rubric:
  - Counts specifiers including positional and length-modified forms.
  - Ignores %%.
  - Reports counts when they differ, "ok" otherwise.
solution: |
  ```swift
  func specifierCount(_ text: String) -> Int {
      var count = 0
      var index = text.startIndex
      while index < text.endIndex {
          guard text[index] == "%" else { index = text.index(after: index); continue }
          var end = text.index(after: index)
          while end < text.endIndex, "0123456789$.lhqz".contains(text[end]) { end = text.index(after: end) }
          guard end < text.endIndex else { break }
          if text[index...end] != "%%" { count += 1 }
          index = text.index(after: end)
      }
      return count
  }

  func specifierProblems(source: String, translation: String) -> String {
      let a = specifierCount(source)
      let b = specifierCount(translation)
      return a == b ? "ok" : "source \(a), translation \(b)"
  }

  print(specifierProblems(source: "%lld items", translation: "%lld Artikel"))
  print(specifierProblems(source: "%lld items", translation: "商品があります"))
  print(specifierProblems(source: "Delivery to %@ at %@", translation: "Lieferung an %1$@ um %2$@"))
  print(specifierProblems(source: "%@ of %@", translation: "%@ von %@ (%@)"))
  print(specifierProblems(source: "Save 20%%", translation: "20%% sparen"))
  ```

  ```output
  ok
  source 1, translation 0
  ok
  source 2, translation 3
  ok
  ```

  Counting rather than comparing lets translators use positional specifiers to reorder arguments. A stricter check would also compare the types (`lld` against `lld`, `@` against `@`), because a translator who turns `%lld` into `%@` gets a crash or garbage at run time, not just a wrong word.
````

````exercise
id: m43-l05-e6
type: design
prompt: "Plan Pantry's Arabic release (the first right-to-left language). Cover: what to check before translations arrive, the screens and components most likely to break, numbers and currency, testing, and what the CI pipeline adds."
rubric:
  - Uses the Right-to-Left pseudolanguages and the HIG checklist before real translations exist.
  - Names concrete components that need review (custom arrows, progress, step indicators, charts, carousels) and what must not flip (logos, photos, product images, phone numbers).
  - Formats numbers, prices and dates with the locale instead of interpolation, and considers Eastern Arabic numerals.
  - Adds catalog checks, screenshot review in Arabic, and testing with an Arabic speaker.
solution: |
  **Before translations:** run every main screen in Right-to-Left and Right-to-Left With Right-to-Left Strings; fix layouts that use left and right, custom arrows that don't flip, and text alignment. Review against the HIG checklist.

  **Likely breakage:** custom back and next arrows (use `chevron.backward` or `imageFlippedForRightToLeftLayoutDirection()`), the checkout step indicator (order reverses, numbers don't), the delivery progress bar (flips), image carousels with page dots (order reverses), swipe actions' expectations, and any manual frame math (Module 27). Must not flip: Pantry's logo, product photos, the barcode scanner overlay, phone numbers, order numbers.

  **Numbers:** every number on screen goes through `FormatStyle` with the user's locale so Arabic users get the numerals their region uses; prices use the order's currency code; dates use `.formatted()` styles, never fixed patterns.

  **Pipeline:** the Arabic catalog joins the CI check (missing, unreviewed, specifier counts, all six plural categories that Arabic uses per Module 27); the screenshot job adds Arabic; the export includes screenshots for the translator.

  **People:** a review session with an Arabic-speaking colleague or tester on a device, completing the main tasks from lesson 4's list, before release.
````

## Summary

- Give every module its own String Catalog and look strings up in the owning bundle: `#bundle`, `Bundle.module`, `Bundle(for:)`, or `LocalizedStringResource` with `.forClass`. Generated symbols turn keys into compile-checked names.
- Export and import with Product › Export/Import Localizations or `xcodebuild -exportLocalizations` / `-importLocalizations`; `.xcloc` catalogs carry XLIFF, comments and screenshots. Turn on Use Compiler to Extract Swift Strings, and review ambiguous comments.
- Check catalogs in CI for missing translations, strings not in the translated state, and specifier counts that differ, across every module and plural variant.
- Find non-localized strings with the scheme option, and layout problems with the Double-Length, Accented, Bounded String, Tall and Right-to-Left pseudolanguages; use your own pseudolocalizer for server text and CI snapshots, preserving specifiers.
- Sort and search with `.localizedStandard` and `localizedStandardContains`, join lists with `.list(type: .and)`, and format numbers, prices and dates with the locale. Keep `sorted()` for keys, not for people.
- Review right-to-left with the HIG: flip navigation, progress, ordered sequences and direction icons; keep numbers' digits, photos, logos, universal marks and real-world objects as they are.
