---
id: m21-l05
title: Signing, deployment target and configurations
description: How an app gets permission to run on a device, which iOS versions it supports, and how one codebase builds for several environments. You learn what certificates and provisioning profiles authorize, what automatic signing manages for you, how the deployment target relates to #available and @available, how Debug, Release and xcconfig files feed settings into your code, and why a key compiled into the app is never a secret.
module: m21
order: 5
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m21-l04]
objectives:
  - Explain what a signing certificate, its private key and a provisioning profile each prove or authorize.
  - Describe what automatic signing manages and what still needs a decision.
  - Choose a deployment target and guard newer APIs with #available and @available.
  - Tell compile-time conditions (#if) from runtime availability checks.
  - Set up build configurations and xcconfig files per environment and read their values in code.
  - Explain why secrets in the app binary aren't secret and what to do instead.
terms:
  - term: Code signing
    definition: "Attaching a digital signature to the app so the system can verify who built it and that nothing changed since. iOS only runs third-party code that's signed and authorized."
  - term: Signing identity
    definition: "A certificate (issued by Apple, binding your Team ID to a public key) plus the matching private key in your keychain. Without the private key, the certificate can't sign anything."
  - term: Provisioning profile
    definition: "A file signed by Apple that authorizes code to run: who may sign it (certificates), which app (App ID), where (devices), until when (expiration) and with which entitlements."
  - term: App ID
    definition: "Your Team ID prefix plus a bundle ID, such as SKMME9E2Y8.com.example.Weather. Profiles name one App ID or a wildcard."
  - term: Deployment target
    definition: "The oldest OS version your app supports. Xcode writes it to the MinimumOSVersion Info.plist key; the compiler then requires availability checks for anything newer."
  - term: Build configuration
    definition: "A named set of build setting values, such as Debug and Release. Schemes choose which configuration each action (Run, Test, Profile, Archive) uses."
  - term: xcconfig
    definition: "A plain-text build configuration file of SETTING = value lines that you attach to a configuration, so settings live in version control instead of the project editor."
mastery:
  - List the five things a provisioning profile authorizes and say why the App Store build has no profile.
  - Explain what happens to your ability to sign if you lose the private key, and why an exported .p12 must be protected.
  - Write an if #available check and an @available annotation, and explain what * means.
  - Explain why #if os(iOS) and #available answer different questions.
  - Create Debug, Staging and Release settings for an API host with xcconfig files and read the value through the Info.plist.
  - Explain to a teammate why an API key in an xcconfig ends up readable by anyone with the app.
resources: [tn3125-provisioning-profiles, xcode-running-code-specific-version, xcode-build-configuration-file, apple-platform-security, owasp-mastg, keychain-services]
cards:
  - id: m21-l05-c1
    front: What five things does a provisioning profile tie together?
    back: "Who may sign (developer certificates), what app (App ID), where it runs (device list, or all devices for some types), when (expiration date) and how it may be entitled (an entitlements allowlist)."
  - id: m21-l05-c2
    front: Why doesn't an app downloaded from the App Store contain a provisioning profile?
    back: "The App Store checks signing and provisioning when you submit, then re-signs the app. Devices don't need to check a profile for that build."
  - id: m21-l05-c3
    front: "What does the * in if #available(iOS 18, *) mean?"
    back: "On any platform not listed, the branch runs (on its minimum deployment target). It's required, so code still compiles for other platforms."
  - id: m21-l05-c4
    front: "#if os(iOS) vs if #available(iOS 18, *)?"
    back: "#if is decided at compile time: code for other platforms isn't compiled at all. #available is checked at runtime on the device, for code that's compiled but needs a newer OS."
  - id: m21-l05-c5
    front: Is an API key safe in an xcconfig, an Info.plist or a Swift constant?
    back: "No. All three end up in the app bundle on the device; anyone with the app can read them. Keep secrets on your server, and give the app short-lived, per-user credentials."
---

## The idea in one sentence

iOS runs your code only if Apple-issued credentials say who signed it and where it may run; the deployment target decides which devices can install it; and build configurations decide which settings, servers and flags go into each build, none of which can hide a secret from the person holding the device.

> [!note] Sources and what was run
> Signing comes from Apple's technotes TN3125 (provisioning profiles) and TN3161 (certificates), and from the Xcode articles on distribution and signing identities. Availability, build configurations and xcconfig files come from "Running code on a specific platform or OS version", "Configuring the build settings of a target", "Adding a build configuration file to your project" and the build settings reference. All read in November 2026; Xcode's panes weren't checked in a running Xcode. Swift blocks were compiled and run with Swift 6.3 on Linux, which also shows what `#available` does on a platform that isn't iOS. The one `Bundle` block was type-checked against the iOS SDK, not run.

## Why apps must be signed

TN3125 starts with the rule: "Apple platforms, except macOS, won't run arbitrary third-party code. All execution of third-party code must be authorized by Apple." Signing proves two things when the app runs:

1. **Nothing changed** since it was signed.
2. **Who signed it**, and that this signer is allowed to run this app here.

The first is a digital signature. The second needs certificates and a provisioning profile.

### Certificates and private keys

A code-signing **certificate** is an X.509 document in which Apple attests, roughly, "this developer is associated with this public key." Apple puts your **Team ID** in the certificate's organizational unit field, and development certificates have common names that begin with `Apple Development:`.

The certificate is public. What signs is the **private key** that matches it, which Xcode generates in your Mac's keychain. Certificate plus private key is your **signing identity**. Two consequences:

- A new Mac doesn't have your private key. Apple's docs: "If you have a certificate but not the corresponding private key, you can't use that certificate for code signing."
- Exporting the identity (a password-protected `.p12`) gives someone the power to sign as you. Apple says anybody with that file and its password "can distribute signed software that appears to users and the operating system to come from your Apple Developer account," and recommends sending the file and the password through different channels.

### Provisioning profiles

A **provisioning profile** is a property list wrapped in a signature made by Apple. TN3125 says it "ties together five criteria":

| Question | Where it lives in the profile |
| --- | --- |
| **Who** may sign? | `DeveloperCertificates`: the certificates allowed |
| **What** app? | The App ID: Team ID prefix + bundle ID, such as `SKMME9E2Y8.com.example.Weather`, or a wildcard ending in `.*` |
| **Where** can it run? | `ProvisionedDevices`, a list of device IDs. App Store profiles have none; some distribution types apply to all devices |
| **When**? | `ExpirationDate`, "typically not more than a year" |
| **How** can it be entitled? | `Entitlements`: an allowlist. Every entitlement the app claims in its signature must be in it |

In a development build, the profile is copied into the bundle as `embedded.mobileprovision` (lesson 1). When you submit to the App Store, Apple checks your signing and provisioning and **re-signs** the app; "the final app doesn't have a provisioning profile."

Devices also need **Developer Mode** turned on to run apps you build and run from Xcode, or development builds installed from an `.ipa`. It doesn't affect App Store or TestFlight installs.

### Automatic and manual signing

The `CODE_SIGN_STYLE` build setting has two values. Apple's description: "Choose `Automatic` to let Xcode automatically create and update profiles, app IDs, and certificates. Choose `Manual` to create and update these yourself on the developer website."

With automatic signing you choose a **team** (`DEVELOPMENT_TEAM`), and Xcode registers your bundle ID, creates certificates when needed, registers devices you run on, and keeps profiles up to date. You still decide:

- **The bundle ID**, permanently, as lesson 1 warned.
- **Capabilities** (push, iCloud, app groups), each of which becomes an entitlement and changes the profile.
- **Who holds the distribution identity** on a team. Larger teams and CI systems often use manual signing (`PROVISIONING_PROFILE_SPECIFIER`, `CODE_SIGN_IDENTITY`) so builds don't depend on one person's Mac. Module 41 sets that up.

## The deployment target

The **deployment target** is the oldest OS your app supports. Xcode turns it into the `MinimumOSVersion` key in the Info.plist, and devices with older versions can't install the app. Xcode 27.2 supports iOS deployment targets from 15 to 27; this course uses **iOS 17** as its baseline.

It's different from the **SDK** you build with (`SDKROOT`, "Base SDK"). You build with the newest SDK, iOS 27 in Xcode 27, so you **can** call iOS 27 APIs; the deployment target says some users run iOS 17, so you **must** check before calling them.

### #available: check at runtime

```swift
if #available(iOS 18, *) {
    print("use the iOS 18 API")
} else {
    print("use the fallback")
}

if #unavailable(iOS 18) {
    print("running on something older than iOS 18")
} else {
    print("not older than iOS 18, or not iOS at all")
}
```

```output
use the iOS 18 API
not older than iOS 18, or not iOS at all
```

That output is from Linux, and it shows what the `*` means. Apple's article: "The `*` matches any other operating system", and on those, the branch runs. On an iPhone with iOS 17 the same program would print `use the fallback` and `running on something older than iOS 18`.

The compiler uses these checks too: inside the `if #available(iOS 18, *)` branch it lets you call iOS 18 APIs; outside, with a deployment target of 17, it reports an error. The deployment target is what makes the check necessary.

### @available: mark your own declarations

When a whole function or type depends on new APIs, annotate it once instead of checking inside:

```swift
@available(iOS 18, *)
func showStreakCelebration() {
    print("celebrating with the iOS 18 animation")
}

if #available(iOS 18, *) {
    showStreakCelebration()
}
```

```output
celebrating with the iOS 18 animation
```

Callers then need their own `#available` check (or must be `@available(iOS 18, *)` themselves), but the body doesn't check again.

The same attribute marks things as deprecated, which is how Apple's SDKs warn you about old APIs (lesson 2's `applicationDidBecomeActive(_:)`, for example). You can do it in your own code:

```swift warning 'fetchFeed()' is deprecated: Use loadFeed() instead
@available(*, deprecated, message: "Use loadFeed() instead")
func fetchFeed() {
    print("fetching")
}

fetchFeed()
```

Swift 6.3 compiles it with `warning: 'fetchFeed()' is deprecated: Use loadFeed() instead`, and it still runs.

### #if: decide at compile time

`#if` is a different tool. It removes code before it's compiled:

```swift
#if os(iOS)
print("compiled for iOS")
#else
print("compiled for another platform")
#endif

#if targetEnvironment(simulator)
print("simulator build")
#else
print("not a simulator build")
#endif
```

```output
compiled for another platform
not a simulator build
```

| | `#if os(iOS)`, `#if DEBUG` | `if #available(iOS 18, *)` |
| --- | --- | --- |
| Decided | When compiling | When running, on the device |
| The other branch | Isn't compiled at all | Is compiled, just not run |
| Use for | Different platforms, build configurations, simulator-only code | APIs newer than your deployment target |

## Build configurations

A **build configuration** is a named set of build setting values. Projects start with **Debug** and **Release**. Apple's scheme documentation: a debug configuration "typically disables code optimizations for faster builds and enables the generation of debugging information"; a release configuration "enables code optimizations for better runtime performance."

The scheme decides which one each action uses. Apple's Instruments tutorial notes that the Profile action builds "in release mode, as debug builds can have different performance characteristics". Archives you distribute are Release builds too.

Configurations reach your Swift code through **Active Compilation Conditions** (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`). If the Debug configuration lists `DEBUG` there, `#if DEBUG` is true in Debug builds:

```swift
#if DEBUG
print("debug build: verbose logging, test server")
#else
print("release build: quiet logging, production server")
#endif
```

```output
release build: quiet logging, production server
```

The snippet was compiled with plain `swiftc`, which defines no `DEBUG`, so the `#else` branch ran. This lesson didn't verify which conditions Xcode 27's templates define; check your target's build settings rather than assuming.

## xcconfig files per environment

Real apps usually need more than two environments: a development server, a staging server that mirrors production, and production. Editing build settings in the project editor for each one is hard to review. A **build configuration file** (`.xcconfig`) puts them in plain text:

```plaintext
// Base.xcconfig — shared by every configuration
PRODUCT_BUNDLE_IDENTIFIER = com.example.Weather
API_SCHEME = https

// Debug.xcconfig
#include "Base.xcconfig"
API_HOST = dev-api.example.com
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG

// Staging.xcconfig
#include "Base.xcconfig"
API_HOST = staging-api.example.com
PRODUCT_BUNDLE_IDENTIFIER = com.example.Weather.staging

// Release.xcconfig
#include "Base.xcconfig"
API_HOST = api.example.com
```

The rules, from Apple's article:

- Each line is `SettingName = SettingValue`. If a setting appears twice, the last one wins.
- `$(inherited)` extends a value instead of replacing it; `$(OTHER_SETTING)` reuses another setting.
- `#include "Other.xcconfig"` pulls in another file (`#include?` doesn't warn if it's missing).
- **`//` starts a comment, to the end of the line.** That's why the host is stored without `https://`: a value like `https://api.example.com` would be cut off after `https:`. Keep the scheme separate and build the URL in code.
- In the project's Info tab you map each configuration (Debug, Release, and any you add, such as Staging) to a file.
- Precedence, highest first: target settings, an xcconfig mapped to the target, project settings, an xcconfig mapped to the project, system defaults.

The different bundle ID for Staging lets both builds sit on one phone side by side.

### Getting a value into Swift

Build settings exist at build time; your code runs later. The bridge is the Info.plist: add a key whose value is a build-setting reference, and Xcode substitutes it while building. Apple's article notes that Xcode **doesn't** turn user-defined `INFOPLIST_KEY_` settings into keys, so put custom keys in an Info.plist file you supply:

```xml
<key>APIHost</key>
<string>$(API_HOST)</string>
```

Then read it, and fail loudly if it's missing:

```swift ios
import Foundation

func apiBaseURL() -> URL {
    guard let host = Bundle.main.object(forInfoDictionaryKey: "APIHost") as? String,
          let url = URL(string: "https://\(host)") else {
        fatalError("APIHost is missing from the Info.plist; check the xcconfig for this configuration")
    }
    return url
}
```

A missing setting is a programmer error in the build, not something a user can fix, so `fatalError` (Module 12) is appropriate: it stops a misconfigured build the first time anyone runs it.

The same logic can be tested without a bundle by passing the dictionary in:

```swift
enum Environment: String {
    case development, staging, production
}

struct AppConfig {
    let environment: Environment
    let apiHost: String

    init?(info: [String: String]) {
        guard let name = info["AppEnvironment"],
              let environment = Environment(rawValue: name),
              let host = info["APIHost"], !host.isEmpty else {
            return nil
        }
        self.environment = environment
        self.apiHost = host
    }

    var baseURL: String { "https://\(apiHost)" }
}

let staging = AppConfig(info: ["AppEnvironment": "staging", "APIHost": "staging-api.example.com"])
print(staging?.baseURL ?? "invalid")
let broken = AppConfig(info: ["AppEnvironment": "prod", "APIHost": "api.example.com"])
print(broken?.baseURL ?? "invalid")
```

```output
https://staging-api.example.com
invalid
```

`"prod"` isn't a raw value of `Environment`, so the failable initializer returns `nil`. A typo in an xcconfig becomes a test failure instead of an app talking to the wrong server.

## Secrets in the binary aren't secret

It's tempting to put an API key in an xcconfig, an Info.plist or a Swift constant. All three end up in the bundle on the person's device: the Info.plist as a file anyone with the app can read, and Swift string literals inside the executable. This was checked by compiling a two-line program on Linux:

```swift illustrative
let weatherAPIKey = "sk_live_4f9a2c7e1b"
print("Calling the weather API with key ending in \(weatherAPIKey.suffix(4))")
```

and running the standard `strings` tool on the optimized binary:

```bash
swiftc -O main.swift -o Weather
strings Weather | grep sk_live
```

```output
sk_live_4f9a2c7e1b
```

The key is right there in the binary. An iOS binary is a different format (Mach-O), but string literals are stored the same basic way.

"Obfuscating" doesn't change that, because the app has to undo the obfuscation to use the key, and so can anyone else:

```swift
let obfuscated: [UInt8] = [0x29, 0x31, 0x05, 0x36, 0x33, 0x2C, 0x3F, 0x05, 0x6E,
                           0x3C, 0x63, 0x3B, 0x68, 0x39, 0x6D, 0x3F, 0x6B, 0x38]
let mask: UInt8 = 0x5A

var revealed = ""
for byte in obfuscated {
    revealed.append(Character(Unicode.Scalar(byte ^ mask)))
}
print(revealed)
```

```output
sk_live_4f9a2c7e1b
```

Each byte was XOR-ed with `0x5A`; XOR-ing again restores it. The decoding code and the mask ship in the same binary as the bytes. Obfuscation slows down a casual look; it doesn't protect a key.

What to do instead:

- **Keep secret keys on your server.** The app calls your backend; your backend calls the third-party API with the key.
- **Give the app per-user, short-lived credentials** after the person signs in, and store them in the **Keychain** (Module 42), never in `UserDefaults` or files.
- **Treat anything in the bundle as public**: hosts, feature flags, public client IDs. That's fine as long as knowing them doesn't grant access.
- **Rotate a key that shipped.** If a secret was ever in a released build, assume it's been extracted.

OWASP's MASVS and MASTG, which Module 42 uses, treat hardcoded secrets as a standard finding in mobile security reviews.

## Common mistakes

> [!error] Losing the private key and "fixing" it by revoking the certificate
> A new Mac doesn't have your private key. Revoking a distribution certificate affects everyone who signs with it. Export the identity securely from the Mac that has it, or create a new certificate deliberately.

> [!error] Raising the deployment target to silence availability errors
> It works, and it drops every user on older iOS versions. Decide the deployment target from your users; use `#available` for the rest.

> [!error] Using #if to check the iOS version
> `#if` is decided at compile time; one binary runs on many iOS versions. Use `if #available`.

> [!error] A full URL in an xcconfig
> `API_URL = https://api.example.com` becomes `https:` because `//` starts a comment. Store the host and build the URL in code.

> [!error] Shipping API keys in the bundle
> xcconfig, Info.plist and Swift constants all end up readable on the device. Move the key behind your server.

## Exercises

````exercise
id: m21-l05-e1
type: prediction
prompt: "This program was compiled with plain `swiftc` (no extra flags) and run on Linux. What does it print?"
code: |
  if #available(iOS 26, *) {
      print("A")
  } else {
      print("B")
  }

  #if os(iOS)
  print("C")
  #else
  print("D")
  #endif

  #if DEBUG
  print("E")
  #else
  print("F")
  #endif
output: |
  A
  D
  F
hints:
  - "On a platform not listed in #available, the * makes the branch run."
  - "#if os(iOS) is false when compiling for Linux."
  - "Nothing defined DEBUG."
solution: |
  ```output
  A
  D
  F
  ```

  - `A`: the `*` covers every platform not listed, so on Linux the first branch runs. On an iPhone with iOS 17 it would print `B`.
  - `D`: `#if os(iOS)` is decided when compiling, and this build was for Linux.
  - `F`: `DEBUG` is only defined if the build passes it, as Xcode's Debug configuration does through Active Compilation Conditions.
````

````exercise
id: m21-l05-e2
type: comprehension
prompt: "Your app runs fine from Xcode on your iPhone, but a colleague's iPhone refuses to run the same development build you sent them. Which part of the provisioning profile most likely explains it?"
choices:
  - text: "Where: the profile's device list doesn't include the colleague's device."
    correct: true
    why: "Development and ad hoc profiles list ProvisionedDevices; other devices can't run builds signed with them."
  - text: "What: the App ID only allows one installation at a time."
    correct: false
    why: The App ID names the app, not how many devices it's on.
  - text: "Who: development certificates only work on the developer's own phone."
    correct: false
    why: "The certificate identifies who signed; the device list decides where it runs."
  - text: "When: development builds expire after one launch."
    correct: false
    why: Profiles expire on a date, typically within a year, not after one launch.
solution: |
  **Where.** A development profile lists the devices it covers in `ProvisionedDevices`. Your phone was registered when you ran from Xcode with automatic signing; your colleague's wasn't. Register the device (Xcode does it when the device is a run destination, or add it in the developer account) and regenerate the profile, or share the build through TestFlight instead. Their phone also needs Developer Mode turned on for development builds.
````

````exercise
id: m21-l05-e3
type: fill-in
prompt: Complete the staging xcconfig so it reuses the base file, adds a compilation condition without losing the inherited ones, and sets the API host.
code: |
  [[1]] "Base.xcconfig"
  SWIFT_ACTIVE_COMPILATION_CONDITIONS = [[2]] STAGING
  API_HOST = [[3]]
blanks:
  - id: "1"
    answers: ["#include"]
  - id: "2"
    answers: ["$(inherited)"]
  - id: "3"
    answers: ["staging-api.example.com"]
solution: |
  ```plaintext
  #include "Base.xcconfig"
  SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STAGING
  API_HOST = staging-api.example.com
  ```

  `$(inherited)` keeps whatever conditions lower levels already set and adds `STAGING`, so `#if STAGING` works in Swift. The host has no `https://`, because `//` would start a comment. Any host without a scheme is right for blank 3; the point is not including one.
````

````exercise
id: m21-l05-e4
type: find-errors
prompt: "A teammate's Release.xcconfig and the code that reads it. Mark every real problem."
code: |
  // Release.xcconfig
  #include "Base.xcconfig"
  API_URL = https://api.example.com/v2
  PAYMENTS_SECRET_KEY = sk_live_51Hx9Q
  IPHONEOS_DEPLOYMENT_TARGET = 27.0   // so we don't need #available anywhere

  // Swift
  #if os(iOS) && IOS_27
  useNewCheckout()
  #endif
choices:
  - text: "API_URL is cut off at https: because // starts a comment."
    correct: true
  - text: "The payments secret ships inside the app bundle, where anyone with the app can read it."
    correct: true
  - text: "Raising the deployment target to 27 drops every user on iOS 17 to 26, just to avoid availability checks."
    correct: true
  - text: "#if can't check the iOS version the app is running on; that needs if #available."
    correct: true
  - text: "#include isn't allowed in xcconfig files."
    correct: false
    why: "Apple's article documents #include and #include?."
rubric:
  - I found the // comment problem.
  - I found the secret key in the bundle.
  - I questioned raising the deployment target.
  - I explained #if vs #available.
solution: |
  Four problems:

  1. `API_URL = https://api.example.com/v2` becomes `https:`: everything from `//` is a comment. Store `API_HOST = api.example.com` and build the URL in code.
  2. `PAYMENTS_SECRET_KEY` ends up in the Info.plist or the binary, both readable on the device. A secret payments key must stay on your server.
  3. A deployment target of 27 means devices on iOS 17 to 26 can't install the app. That's a product decision, not a way to avoid writing `#available`.
  4. `#if` is evaluated at compile time; a made-up `IOS_27` flag doesn't know what OS the phone runs. Use `if #available(iOS 27, *) { useNewCheckout() }`.

  `#include` is fine.
````

````exercise
id: m21-l05-e5
type: solve
prompt: |
  Model availability checks in plain Swift. Write `OSVersion`, a `Comparable` struct with `major` and `minor`, and `canUse(introducedIn:on:)`, which returns whether an API introduced in one version can be used on a device running another. Then, with a deployment target of 17.0 and an API introduced in 18.0, print which path each device takes, and whether the compiler would demand an availability check (it does when the deployment target is older than the API).

  Expected output:

  ```output
  iOS 17.4: fallback
  iOS 18.0: new API
  iOS 27.1: new API
  compiler would require a check: true
  ```
starter: |
  struct OSVersion: Comparable {
      let major: Int
      let minor: Int

      static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
          // your code
          return false
      }
  }
hints:
  - "Compare majors first; only if they're equal, compare minors."
  - "Comparable gives you >= for free once you write <."
  - "The compiler's rule in this model: a check is needed when deploymentTarget < introducedIn."
rubric:
  - Implements < by major, then minor.
  - canUse returns device >= introducedIn.
  - Prints the three devices and the compiler line exactly.
solution: |
  ```swift
  struct OSVersion: Comparable {
      let major: Int
      let minor: Int

      static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
          if lhs.major != rhs.major {
              return lhs.major < rhs.major
          }
          return lhs.minor < rhs.minor
      }
  }

  func canUse(introducedIn required: OSVersion, on device: OSVersion) -> Bool {
      device >= required
  }

  let deploymentTarget = OSVersion(major: 17, minor: 0)
  let newAPI = OSVersion(major: 18, minor: 0)
  let devices = [OSVersion(major: 17, minor: 4), OSVersion(major: 18, minor: 0), OSVersion(major: 27, minor: 1)]

  for device in devices {
      let path = canUse(introducedIn: newAPI, on: device) ? "new API" : "fallback"
      print("iOS \(device.major).\(device.minor): \(path)")
  }
  print("compiler would require a check: \(deploymentTarget < newAPI)")
  ```

  ```output
  iOS 17.4: fallback
  iOS 18.0: new API
  iOS 27.1: new API
  compiler would require a check: true
  ```

  Implementing only `<` is enough: `Comparable` derives `>=`, `>` and `<=` from it, and `Equatable` is synthesized for the struct. The last line is the compiler's half of the story: because some supported devices are older than the API, the call needs `#available`. Raise the deployment target to 18.0 and the check is no longer required, at the cost of the iOS 17 users.
````

````exercise
id: m21-l05-e6
type: explain
prompt: "A product manager asks: \"Can't we just put the maps API key in the build settings? They're not in the source code, so nobody can see them.\" Answer them, and propose what to do."
code: |
  // Release.xcconfig
  MAPS_API_KEY = AIzaSy-example-key

  // Info.plist
  <key>MapsAPIKey</key>
  <string>$(MAPS_API_KEY)</string>
rubric:
  - I explained that build settings are substituted into the Info.plist, which ships in the app bundle.
  - I explained that anything in the bundle or the binary can be read by anyone who has the app, and obfuscation can be reversed because the app itself must decode it.
  - I distinguished keys that are meant to be public and restricted from real secrets.
  - I proposed keeping secrets on a server and giving the app per-user, short-lived credentials stored in the Keychain.
solution: |
  Build settings aren't hidden; they're **inputs to the build**. Here `$(MAPS_API_KEY)` is substituted into the Info.plist, which is a file inside the app bundle that ships to every device. Anyone with the app can open it. A key written as a Swift constant isn't better: the lesson found it verbatim in the compiled binary with `strings`. Obfuscating it only adds a step, since the decoding code ships with it.

  So the question is what the key protects. Some keys are designed to be public: a maps SDK key restricted by the provider to your bundle ID is meant to sit in the app, and knowing it doesn't grant much. A key that can spend money or read data (payments, a paid API billed per call) must never ship. Put it on your server, have the app call your backend, and let the backend call the third party. If the app needs credentials, issue them per user after sign-in, make them short-lived, and keep them in the Keychain.

  And if a real secret already shipped in a release, rotate it: assume it's been extracted.
````

````exercise
id: m21-l05-e7
type: design
prompt: |
  Design the configuration for a fitness app with three environments: development (local mock server), staging (pre-production server, installed by testers next to the App Store version) and production. Specify the build configurations, the xcconfig files and their contents, the bundle IDs, how the API host reaches Swift, which compilation conditions exist, and how each Xcode action (Run, Test, Profile, Archive) maps to them.
rubric:
  - Three configurations (Debug, Staging, Release) each mapped to an xcconfig that includes a shared base.
  - A different bundle ID (and display name) for staging so it installs next to production.
  - The API host stored without a scheme, passed through an Info.plist key and validated at launch.
  - Compilation conditions for DEBUG and STAGING added with $(inherited).
  - Run and Test use Debug; Profile uses Release (or a release-like config); Archive uses Release for the App Store and Staging for tester builds.
  - No secrets in any xcconfig.
solution: |
  **Configurations and files**

  ```plaintext
  // Base.xcconfig
  PRODUCT_BUNDLE_IDENTIFIER = com.example.Fitness
  API_SCHEME = https

  // Debug.xcconfig
  #include "Base.xcconfig"
  API_HOST = localhost:8080
  API_SCHEME = http
  SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG

  // Staging.xcconfig
  #include "Base.xcconfig"
  API_HOST = staging-api.example.com
  PRODUCT_BUNDLE_IDENTIFIER = com.example.Fitness.staging
  SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STAGING

  // Release.xcconfig
  #include "Base.xcconfig"
  API_HOST = api.example.com
  ```

  **Into Swift**: an Info.plist file with `APIHost = $(API_HOST)`, `APIScheme = $(API_SCHEME)` and `AppEnvironment` per configuration; an `AppConfig` initializer like the lesson's that returns `nil` (and a `fatalError` at launch) if anything is missing. Plain HTTP is restricted by App Transport Security, so the Debug configuration may need an exception for the local server; Modules 30 and 42 cover ATS.

  **Bundle IDs**: Staging gets its own bundle ID and a display name like "Fitness β", so testers can install it next to the App Store version. It needs its own App ID and profile.

  **Actions**: Run and Test → Debug. Profile → Release, because Apple's tools measure release builds. Archive → Release for the App Store; a second scheme archives Staging for testers.

  **Secrets**: none in the files. Anything secret lives on the server.
````

## Summary

- iOS runs third-party code only when it's signed and authorized. A signing identity is a certificate plus its private key; protect exported identities.
- A provisioning profile authorizes who, what (App ID), where (devices), when (expiration) and how (entitlements). App Store builds are re-signed by Apple and carry no profile.
- Automatic signing manages certificates, App IDs and profiles; you still own the bundle ID, capabilities and who holds distribution signing.
- The deployment target becomes `MinimumOSVersion`. Build with the newest SDK, and guard newer APIs with `if #available` or `@available`. `*` means "any other platform". `#if` decides at compile time and can't check the device's OS version.
- Debug and Release are build configurations; schemes pick one per action. Active Compilation Conditions feed `#if DEBUG`.
- xcconfig files hold per-environment settings in text: `#include`, `$(inherited)`, last value wins, and `//` starts a comment. Values reach Swift through Info.plist substitution.
- Anything in the bundle or binary is public. Keep secrets on the server and per-user credentials in the Keychain.
