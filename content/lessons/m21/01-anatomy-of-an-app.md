---
id: m21-l01
title: Anatomy of an iOS app
description: What Xcode actually builds when you press Run. You follow an app from the project and its targets to the signed bundle on the device, read the Info.plist keys every app has, see where assets and frameworks end up, and draw a clear line between what belongs to the Swift language and what belongs to Apple's SDK.
module: m21
order: 1
level: intermediate
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l01]
objectives:
  - Describe how a project, its targets and their build settings relate to the products Xcode builds.
  - Draw the layout of an iOS app bundle and say what each part is for.
  - Read the core Info.plist keys and explain where Xcode gets their values.
  - Explain what an asset catalog is and how the system picks a variant at runtime.
  - Tell apart the Swift language and standard library, Foundation, and Apple-only SDK frameworks.
terms:
  - term: Project
    definition: "The .xcodeproj that holds your files, targets and build settings. One project can build several products."
  - term: Target
    definition: "One product to build: an app, an app extension, a framework or a test bundle. Each target has its own build settings and source files."
  - term: Bundle
    definition: "A folder with a standard structure that the system treats as one unit. An iOS app is a bundle named <Name>.app holding the executable, Info.plist and resources."
  - term: Info.plist
    definition: "The information property list: key-value pairs at the root of an iOS bundle that tell the system how to identify and run it."
  - term: Bundle ID
    definition: "The CFBundleIdentifier value, in reverse-DNS form (com.example.Weather). It identifies the app on the device and in App Store Connect."
  - term: Asset catalog
    definition: "An .xcassets folder of asset sets (images, colors, data, the app icon). Each set can hold variants for different devices, appearances and languages."
  - term: SDK
    definition: "Software development kit: the headers and libraries for one platform version, such as the iOS 27 SDK. UIKit, SwiftUI and AVFoundation come from it, not from the Swift language."
mastery:
  - Sketch the folder layout of a built iOS app and point to the executable, the Info.plist, resources, Frameworks/ and PlugIns/.
  - Explain where CFBundleIdentifier comes from in a project that generates its Info.plist.
  - Tell CFBundleShortVersionString from CFBundleVersion and give a valid example of each.
  - Say whether a given type (String, URL, UIView, Logger) comes from the standard library, Foundation or an Apple-only framework.
  - Compare dotted version strings numerically instead of as text.
resources: [xcode-create-project, xcode-requirements, apple-documentation, swiftpm-docs]
cards:
  - id: m21-l01-c1
    front: What's the relationship between an Xcode project and its targets?
    back: "The project holds files and shared settings. Each target builds one product (app, extension, framework, tests) with its own build settings; target settings override project settings."
  - id: m21-l01-c2
    front: What's inside an iOS .app bundle, at a minimum?
    back: "The executable and Info.plist at the root, resources (compiled storyboards, asset catalog, other files) also at the root, plus Frameworks/ for embedded frameworks and PlugIns/ for app extensions when the app has them."
  - id: m21-l01-c3
    front: CFBundleShortVersionString vs CFBundleVersion?
    back: "ShortVersionString is the user-visible release version, three period-separated integers like 2.4.1. CFBundleVersion is the build: one to three period-separated integers, required by the App Store."
  - id: m21-l01-c4
    front: In a new Xcode project, where does the Info.plist's CFBundleIdentifier come from?
    back: "From the PRODUCT_BUNDLE_IDENTIFIER build setting. Xcode writes $(PRODUCT_BUNDLE_IDENTIFIER) and substitutes it when it generates the Info.plist during the build."
  - id: m21-l01-c5
    front: Which of these need an Apple SDK, and which run anywhere Swift runs? String, URL, UIView.
    back: "String: standard library, everywhere. URL: Foundation, which also exists outside Apple platforms. UIView: UIKit, Apple's SDK only."
---

## The idea in one sentence

When you press Run, Xcode turns a **target** in your project into a **bundle**: a folder named `Weather.app` that holds one executable, an `Info.plist` telling the system how to run it, and the resources the code loads, and that folder is what gets signed and installed.

> [!note] Where this lesson's facts come from
> The bundle layout, Info.plist keys and Xcode behavior below come from Apple's documentation (Bundle Resources, "Placing content in a bundle", "Managing your app's information property list values", "Configuring a new target in your project"), read in November 2026. Xcode's UI wasn't checked in a running Xcode. The plain Swift blocks were compiled and run with Swift 6.3 on Linux. The two blocks that use `Bundle` and UIKit were only type-checked against the iOS SDK, not run.

## From project to product

Module 14 split a Swift package into targets. An Xcode project works the same way, with more kinds of target.

| Piece | What it is | Example |
| --- | --- | --- |
| **Project** | The `.xcodeproj`: files, targets, project-wide build settings | `Weather.xcodeproj` |
| **Target** | One product to build, with its own source files and build settings | `Weather` (the app), `WeatherWidget` (an extension), `WeatherTests` |
| **Build settings** | Hundreds of named options: bundle ID, deployment target, signing, optimization | `PRODUCT_BUNDLE_IDENTIFIER = com.example.Weather` |
| **Product** | What a target produces | `Weather.app`, `WeatherWidget.appex` |

Apple's description of a target: "A target specifies a product to build, such as an app, framework, app extension, or unit test." A project can contain several targets that make up one product: the app, a private framework, an extension and tests. Changes to a target's settings affect only that target; changes at the project level apply to all of them, unless a target overrides them.

Some targets are **embedded** in another. A widget extension is its own target, but its product is copied into the app's bundle, and Xcode adds a dependency so it builds first.

## The app bundle

A bundle is a folder with a standard structure that the system treats as a single thing. On iOS, the structure is flat. This is a small app with one embedded framework and one extension, laid out the way Apple's "Placing content in a bundle" table says:

```plaintext
Weather.app/
├── Info.plist                  ← identifies and configures the bundle
├── Weather                     ← the executable (a Mach-O binary)
├── Assets.car                  ← compiled asset catalog (a resource)
├── PrivacyInfo.xcprivacy       ← privacy manifest (lesson 4)
├── embedded.mobileprovision    ← provisioning profile, in development builds (lesson 5)
├── Frameworks/
│   └── WeatherKit.framework/   ← an embedded framework, itself a bundle
└── PlugIns/
    └── WeatherWidget.appex/    ← an app extension, itself a bundle
```

Read it from the top:

- **`Info.plist`** sits at the root. Its presence is part of what makes the folder a bundle, and its name is case-sensitive.
- **The executable** has the target's product name and sits at the root too. "Code" here means a Mach-O binary; Apple's doc is explicit that shell or Python scripts count as resources, because they have no place to hold a code signature.
- **Resources** are everything that isn't code, and on iOS they also live at the root. Built apps usually contain the compiled asset catalog as `Assets.car`; Apple's bundle documentation doesn't list that file, so nothing in this module depends on its name.
- **`Frameworks/`** holds dynamic frameworks and libraries your app embeds. Each `.framework` is a bundle with its own `Info.plist`.
- **`PlugIns/`** holds app extensions (widgets, share extensions). They're bundles too, which is why "bundles can contain other bundles."
- **`embedded.mobileprovision`** is where a provisioning profile goes in an iOS bundle. Lesson 5 explains what it authorizes.

On macOS the same content lives under `Contents/`, with the executable in `Contents/MacOS/`. If you ever see that layout, you're looking at a Mac app.

Apple warns that putting content in the wrong place causes "hard-to-debug code signing and distribution problems". Xcode puts things in the right place as long as you let it.

> [!warning] The bundle is read-only at runtime
> Your app reads its own bundle (images, JSON files, the Info.plist) but never writes to it. Apple's archived *File System Programming Guide* says the bundle "is signed at installation time" and that writing to it "changes the signature and prevents your app from launching". Files your app creates go in its container directories, which lesson 4 covers.

## Info.plist

The **information property list** is a dictionary of keys and values. Apple: "Some key-value pairs characterize the bundle itself, and others configure the app." These are the ones every app has or that you'll meet in this module:

| Key | What it means | Example value |
| --- | --- | --- |
| `CFBundleIdentifier` | The **bundle ID**. Unique per app. Only letters, digits, hyphens and periods; reverse-DNS by convention; case-insensitive | `com.example.Weather` |
| `CFBundleShortVersionString` | The user-visible release version. Exactly three period-separated integers | `2.4.1` |
| `CFBundleVersion` | The build. One to three period-separated integers; required by the App Store | `317` or `2.4.1` |
| `CFBundleExecutable` | The name of the executable file | `Weather` |
| `MinimumOSVersion` | The oldest iOS version the app runs on. Xcode adds it from the deployment target (lesson 5) | `17.0` |
| `UIApplicationSceneManifest` | Which scenes the app supports and their delegate classes (lesson 2) | a dictionary |
| `NSCameraUsageDescription` and friends | The sentence the system shows when it asks permission (lesson 4) | `"Scan receipts to add expenses."` |

Two rules about the bundle ID matter more than they look:

1. It must match the app record in App Store Connect, and after you upload a build, **you can't change it**.
2. It ties into signing: the bundle ID is part of the App ID in your provisioning profile, so changing it means new signing assets.

### Who writes the Info.plist

In a new project you usually won't find an `Info.plist` you can edit. Xcode **generates** it during the build from build settings. When you create a project from a template, Xcode sets `CFBundleIdentifier` to the literal text `$(PRODUCT_BUNDLE_IDENTIFIER)` and fills it in with that build setting's value. Every other key has a matching build setting named after it with an `INFOPLIST_KEY_` prefix, for example `INFOPLIST_KEY_CFBundleDisplayName`.

So the Bundle Identifier field in the target's General pane, the `PRODUCT_BUNDLE_IDENTIFIER` build setting and `CFBundleIdentifier` in the built app are the same value, seen from three places.

When you do need a real file (for keys that have no build setting), you create one and point the `INFOPLIST_FILE` build setting at it. With `GENERATE_INFOPLIST_FILE` set to `YES`, Xcode merges your file with the build-setting values. Apple's docs add one rule people break: **don't add that file to the target's resources**, or Xcode copies it unprocessed into the bundle as a plain resource.

### Reading it at runtime

`Bundle` (from Foundation) represents a bundle on disk, and `Bundle.main` is the one containing the running code. A few keys have properties; the rest you read by name:

```swift ios
import Foundation

let bundleID = Bundle.main.bundleIdentifier                     // CFBundleIdentifier
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
print("\(bundleID ?? "?") \(version ?? "?") (\(build ?? "?"))")
// In an app built with the values above: com.example.Weather 2.4.1 (317)
```

This block was type-checked against the iOS SDK but not run: outside an app bundle these values aren't the ones an app would see. Every value comes back as an optional, because a key may be missing.

## Version strings are numbers, not text

Both version keys are period-separated **integers**. That has a consequence the first time your app reaches version 1.10: compared as text, `"1.10.0"` sorts before `"1.9.0"`, because the character `1` comes before `9`.

```swift
let installed = "1.9.0"
let available = "1.10.0"
print(available > installed)
```

```output
false
```

String comparison looks at characters left to right and stops at the first difference: `"1"` vs `"9"`. To compare versions, split them into integers and compare those:

```swift
func versionNumbers(_ text: String) -> [Int] {
    var numbers: [Int] = []
    for part in text.split(separator: ".") {
        numbers.append(Int(part) ?? 0)
    }
    return numbers
}

func isNewer(_ candidate: String, than current: String) -> Bool {
    var a = versionNumbers(candidate)
    var b = versionNumbers(current)
    while a.count < 3 { a.append(0) }
    while b.count < 3 { b.append(0) }
    for index in 0..<3 {
        if a[index] != b[index] {
            return a[index] > b[index]
        }
    }
    return false
}

print(isNewer("1.10.0", than: "1.9.0"))
print(isNewer("2.0", than: "1.99.9"))
print(isNewer("1.4", than: "1.4.0"))
```

```output
true
true
false
```

Line by line:

1. `versionNumbers` splits on `"."` and converts each piece with `Int(part) ?? 0`. A malformed piece becomes `0` here; the exercises add real validation.
2. Missing components count as zero, which is also how Apple reads `CFBundleVersion`: "10.5 specifies 10.5.0".
3. The loop finds the first component that differs and lets it decide. If none differs, the versions are equal, so `candidate` is not newer.

You'll write this kind of comparison when an app checks whether the server requires a newer version, or when it migrates saved data written by an older build.

## Assets

An **asset catalog** (`Assets.xcassets`, created with every template) organizes resources into **asset sets**. Each set is one logical resource, such as an image, a color, a data file or the app icon, with one or more variants for device characteristics: platform, screen size, resolution, appearance (light and dark) and language. The template's catalog starts with an accent color and an app icon.

In code you ask for the set by name and the system picks the variant for the current device:

```swift ios
import UIKit

let logo = UIImage(named: "Logo")          // picks the variant for this screen and appearance
let brand = UIColor(named: "BrandOrange")  // a color set, with light and dark values
```

Two practical consequences: you never write `if darkMode { "logo-dark" }` yourself, and a name that doesn't exist gives you `nil` at runtime, not a build error.

## Frameworks: yours and Apple's

Your app uses two kinds of framework, and they end up in very different places.

- **System frameworks** (UIKit, SwiftUI, Foundation, AVFoundation, os) are part of iOS. Your executable links against them, but they're **not** copied into your bundle; the device already has them. The Swift runtime and standard library also ship with Apple's operating systems, so apps don't carry their own copy.
- **Your frameworks and third-party code.** A framework target or a binary framework you embed goes into `Frameworks/`. Code from Swift packages becomes part of your app too; whether it's linked into your executable or embedded as a framework depends on how the package product is built.

Every embedded framework is code the device has to load at launch and code that has to be signed. That's one reason not to add dependencies casually.

## Swift the language vs the SDK

It's easy to think of "Swift" as everything you type in Xcode. It's really three layers, and knowing which one a type comes from tells you where your code can run:

| Layer | Examples | Where it's available |
| --- | --- | --- |
| **Swift language and standard library** | `Int`, `String`, `Array`, `Dictionary`, `Optional`, `print`, `Result` | Everywhere Swift runs: iOS, macOS, Linux, Windows |
| **Foundation** | `Date`, `URL`, `Data`, `JSONDecoder`, `Bundle`, `FileManager` | Apple platforms, and an open-source implementation on other platforms (not always identical) |
| **Apple SDK frameworks** | `UIKit`, `SwiftUI`, `AVFoundation`, `os` (`Logger`), `CoreLocation` | Apple platforms only, with availability per OS version |

The compiler can tell you which modules exist where it's building. `#if canImport(Module)` checks whether a module could be imported, without importing it:

```swift
#if canImport(Foundation)
print("Foundation: available")
#else
print("Foundation: missing")
#endif

#if canImport(UIKit)
print("UIKit: available")
#else
print("UIKit: not part of this SDK")
#endif

let cities = ["Lima", "Oslo", "Seoul"]
print("The standard library works anywhere: \(cities.count) cities")
```

```output
Foundation: available
UIKit: not part of this SDK
The standard library works anywhere: 3 cities
```

This ran on Linux, where there's no UIKit. Built for iOS, the second check would print "available". That's why this course runs pure-Swift blocks on Linux, while UIKit and SwiftUI blocks are only type-checked against the iOS SDK or marked as fragments.

Why it matters on the job:

- **Testability.** Logic that only uses the standard library and Foundation can live in a Swift package and run with `swift test` in seconds, without a simulator (Module 14).
- **Versions.** The language version comes from your Xcode's compiler (Swift 6.4 in Xcode 27.2). API availability comes from the SDK and the **device's** OS version. A Swift 6.4 feature works on iOS 17; an iOS 27 API doesn't, no matter which compiler you use. Lesson 5 shows how to guard those calls.

## Common mistakes

> [!error] Comparing version strings with < or >
> `"1.10.0" > "1.9.0"` is `false` as text. Split into integers and compare component by component.

> [!error] Adding your Info.plist file to the target's resources
> Apple's docs say this copies the file into the bundle "without processing its values". Point `INFOPLIST_FILE` at it and leave it out of the target's resources.

> [!error] Planning to change the bundle ID later
> After the first upload to App Store Connect, the bundle ID can't change. Pick the organization prefix carefully when you create the project.

> [!error] Writing files into Bundle.main
> The bundle is signed and read-only. Write to your app's container directories instead (lesson 4).

> [!error] Expecting a missing asset name to fail the build
> `UIImage(named: "Logo")` returns `nil` at runtime if no set has that name. Typos show up as blank images, not compiler errors.

## Exercises

````exercise
id: m21-l01-e1
type: comprehension
prompt: Where does an iOS app keep its `Info.plist` and its main executable inside `Weather.app`?
choices:
  - text: Both at the root of `Weather.app`.
    correct: true
    why: "Apple's bundle table puts Info.plist, the main executable and resources at / for iOS, watchOS, tvOS and visionOS."
  - text: "In `Weather.app/Contents/` and `Weather.app/Contents/MacOS/`."
    correct: false
    why: That's the macOS layout.
  - text: "The Info.plist in `Resources/`, the executable in `Frameworks/`."
    correct: false
    why: Frameworks/ is for embedded frameworks and dynamic libraries, not the app's own executable.
  - text: "Neither: they're generated at launch from build settings."
    correct: false
    why: Xcode generates the Info.plist at build time, and it ships inside the bundle.
solution: |
  **Both at the root.** iOS bundles are flat: `Weather.app/Info.plist`, `Weather.app/Weather` (the executable) and resources such as `Assets.car` all sit at the top level. Embedded frameworks go in `Frameworks/` and app extensions in `PlugIns/`. The `Contents/` folder belongs to macOS bundles.
````

````exercise
id: m21-l01-e2
type: prediction
prompt: An app compares its version with the minimum version the server requires. What does this print?
code: |
  let current = "2.9.1"
  let required = "2.10.0"
  if current < required {
      print("update required")
  } else {
      print("up to date")
  }
  print("10" < "9")
output: |
  up to date
  true
hints:
  - "These are String comparisons, character by character."
  - "\"2.9.1\" and \"2.10.0\" first differ at the third character: \"9\" vs \"1\"."
solution: |
  ```output
  up to date
  true
  ```

  `<` on strings compares characters from the left. `"2.9.1"` and `"2.10.0"` share `"2."`, then `"9"` meets `"1"`, and `"1"` sorts first, so `current < required` is `false` and the app wrongly says it's up to date. `"10" < "9"` is `true` for the same reason. The fix is to compare integer components, as `isNewer(_:than:)` does in the lesson.
````

````exercise
id: m21-l01-e3
type: fill-in
prompt: Complete the Info.plist keys and the build setting behind the first one.
code: |
  CFBundle[[1]]       = $([[2]])    // com.example.Weather
  CFBundle[[3]]       = 2.4.1       // the version people see in the App Store
  CFBundle[[4]]       = 317         // the build, required by the App Store
blanks:
  - id: "1"
    answers: ["Identifier"]
  - id: "2"
    answers: ["PRODUCT_BUNDLE_IDENTIFIER"]
  - id: "3"
    answers: ["ShortVersionString"]
  - id: "4"
    answers: ["Version"]
solution: |
  ```plaintext
  CFBundleIdentifier          = $(PRODUCT_BUNDLE_IDENTIFIER)
  CFBundleShortVersionString  = 2.4.1
  CFBundleVersion             = 317
  ```

  Xcode substitutes `$(PRODUCT_BUNDLE_IDENTIFIER)` with the build setting's value when it generates the Info.plist. `CFBundleShortVersionString` must be three period-separated integers; `CFBundleVersion` takes one to three, so `317` is valid.
````

````exercise
id: m21-l01-e4
type: find-errors
prompt: "A teammate fills in a new target's identity like this. Mark every value that breaks Apple's documented rules."
code: |
  PRODUCT_BUNDLE_IDENTIFIER   = com.example.weather_app
  CFBundleShortVersionString  = 1.0
  CFBundleVersion             = 1.0.0.12
  CFBundleDisplayName         = Weather ☀️
choices:
  - text: "The bundle ID contains an underscore, which isn't allowed."
    correct: true
    why: Only A–Z, a–z, 0–9, hyphens and periods are allowed.
  - text: "CFBundleShortVersionString must have three integers, so 1.0 doesn't follow the documented format."
    correct: true
    why: "Apple: the required format is three period-separated integers, such as 10.14.1."
  - text: "CFBundleVersion can't have four integers; the build fails."
    correct: false
    why: "You can include more integers, but the system ignores them. It's misleading, not invalid."
  - text: "The display name can't contain an emoji."
    correct: false
    why: "Nothing in the rules quoted in this lesson restricts CFBundleDisplayName that way; it isn't the bundle ID."
rubric:
  - I flagged the underscore in the bundle ID.
  - I flagged 1.0 as not matching the three-integer format.
  - I knew extra integers in CFBundleVersion are ignored rather than rejected.
solution: |
  Two real problems:

  1. `com.example.weather_app`: bundle IDs allow only letters, digits, hyphens and periods. Use `com.example.weather-app` or `com.example.WeatherApp`, and do it now, because it can't change after the first upload.
  2. `CFBundleShortVersionString = 1.0`: the documented format is three integers, so write `1.0.0`.

  `1.0.0.12` for the build isn't an error: Apple says you can include more integers but the system ignores them, so the build compares as `1.0.0`. That's a reason not to do it, since builds `1.0.0.12` and `1.0.0.13` would look identical.
````

````exercise
id: m21-l01-e5
type: solve
prompt: |
  Write `isValidShortVersion(_:)`, which returns `true` only for strings in the format `CFBundleShortVersionString` requires: exactly three period-separated integers, using only the digits 0–9 and periods. Then print the result for each of these: `"2.4.1"`, `"2.4"`, `"2.4.1-beta"`, `"10.0.12"`, `"2..1"`, `""`.

  Expected output:

  ```output
  2.4.1: true
  2.4: false
  2.4.1-beta: false
  10.0.12: true
  2..1: false
  : false
  ```
starter: |
  func isValidShortVersion(_ text: String) -> Bool {
      // your code
      return false
  }
hints:
  - "split(separator:) drops empty pieces by default; pass omittingEmptySubsequences: false so \"2..1\" yields an empty middle piece."
  - "Each piece must be non-empty and every character must be a digit."
  - "Character has isNumber, but it's also true for digits from other scripts. Compare against \"0\"...\"9\" to stay strict."
rubric:
  - Rejects anything that isn't exactly three pieces.
  - Rejects empty pieces, such as in "2..1" or "".
  - Rejects any character that isn't 0–9.
  - Prints the six results in the format shown.
solution: |
  ```swift
  func isValidShortVersion(_ text: String) -> Bool {
      let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
      if pieces.count != 3 {
          return false
      }
      for piece in pieces {
          if piece.isEmpty {
              return false
          }
          for character in piece {
              if !("0"..."9").contains(character) {
                  return false
              }
          }
      }
      return true
  }

  for candidate in ["2.4.1", "2.4", "2.4.1-beta", "10.0.12", "2..1", ""] {
      print("\(candidate): \(isValidShortVersion(candidate))")
  }
  ```

  ```output
  2.4.1: true
  2.4: false
  2.4.1-beta: false
  10.0.12: true
  2..1: false
  : false
  ```

  `omittingEmptySubsequences: false` is the detail that matters: with the default, `"2..1"` splits into `["2", "1"]`, and `""` into `[]`. Here they become three and one pieces, so the count check and the empty check catch them. `("0"..."9").contains(character)` is a closed range of `Character`, so it accepts exactly the ten ASCII digits.
````

````exercise
id: m21-l01-e6
type: explain
prompt: "A new teammate asks why the course's tests can run `print(cities.count)` on Linux but every block that uses `UIImage` can only be type-checked against the iOS SDK on a Mac. Explain the difference using the three layers from the lesson."
code: |
  import UIKit

  let names = ["Logo", "Banner"]        // line A
  let logo = UIImage(named: names[0])   // line B
rubric:
  - I placed Array and String in the Swift standard library, which ships with the language and runs wherever Swift runs.
  - I placed UIImage in UIKit, part of Apple's iOS SDK, which doesn't exist on Linux.
  - I mentioned that #if canImport(UIKit) is false on Linux, so the import fails there.
  - I connected it to practice, for example keeping logic in a package so it can be tested without a simulator.
solution: |
  Line A only uses the **Swift standard library**: `Array` and `String` come with the language, and the same compiler builds them for iOS, macOS or Linux. Line B uses **UIKit**, which is part of Apple's iOS SDK. Linux has a Swift compiler but no UIKit, so `import UIKit` fails there; `#if canImport(UIKit)` evaluates to `false`, as the lesson's block showed.

  Foundation sits in between: it exists on Linux as an open-source implementation, but some APIs differ, which is why Foundation code that matters on iOS is also type-checked against the iOS SDK.

  The same split pays off in an app: models, parsing and business rules written against the standard library and Foundation can live in a package and be tested with `swift test` in seconds. Only the thin layer that touches UIKit or SwiftUI needs a simulator.
````

## Summary

- A **project** contains **targets**; each target builds one product (app, extension, framework, tests) from its own files and build settings.
- An iOS app is a flat **bundle**: executable, `Info.plist` and resources at the root, `Frameworks/` and `PlugIns/` for embedded code, `embedded.mobileprovision` in development builds. It's signed and read-only.
- `Info.plist` identifies and configures the app. Xcode generates it from build settings: `CFBundleIdentifier` is `$(PRODUCT_BUNDLE_IDENTIFIER)`, and other keys come from `INFOPLIST_KEY_` settings.
- The bundle ID allows letters, digits, hyphens and periods, and can't change after the first upload. Versions are period-separated integers: compare them numerically.
- Asset catalogs hold variants; the system picks the right one at runtime.
- System frameworks live on the device; your embedded frameworks live in your bundle.
- The standard library runs everywhere, Foundation nearly everywhere, and UIKit, SwiftUI and `os` only on Apple platforms.
