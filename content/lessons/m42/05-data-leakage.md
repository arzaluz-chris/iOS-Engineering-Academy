---
id: m42-l05
title: Keeping sensitive data from leaking
description: "Find the places sensitive data escapes without anyone deciding it should: logs, the app switcher snapshot, the pasteboard, backups and the keyboard. You mark log values private with OSLog and redact what you print yourself, cover the screen before iOS takes its snapshot, copy account numbers with an expiration and no Universal Clipboard, keep re-downloadable files out of backups, and configure text fields so codes and PINs aren't learned or sent through third-party keyboards."
module: m42
order: 5
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l04, m41-l04]
objectives:
  - Use OSLog privacy options correctly, including for integers, and redact sensitive values in any text you log or send.
  - Hide sensitive content before iOS takes the app switcher snapshot, in UIKit and SwiftUI.
  - Copy sensitive values to the pasteboard with localOnly and an expiration, and clear only what the app put there.
  - Decide what belongs in backups and use isExcludedFromBackup knowing it's guidance, not a guarantee.
  - Configure text fields for PINs, one-time codes and account numbers, and reject third-party keyboards app-wide.
terms:
  - term: OSLogPrivacy
    definition: "The privacy option on a Logger interpolation (.public, .private, .sensitive, .auto, with an optional hash mask). By default, dynamic strings and objects are redacted; integers, floating-point values and Booleans aren't."
  - term: App switcher snapshot
    definition: "The image UIKit captures of your UI after the scene enters the background. It's shown in the app switcher and briefly when the app returns."
  - term: Universal Clipboard
    definition: "The general pasteboard's transfer of copied content to nearby devices signed in to the same iCloud account. The localOnly option opts an item out."
  - term: isExcludedFromBackup
    definition: "A URL resource value that tells the system a file or folder can be left out of backups. Apple calls it guidance, not a guarantee."
  - term: Luhn check
    definition: "The checksum digit scheme used by payment card numbers. A redaction filter can use it to recognize card-like digit runs."
mastery:
  - Review a Logger call and say which interpolated values will appear in a collected log.
  - Write a redaction function for free text that masks emails, card numbers and bearer tokens, and test it.
  - Add a privacy cover that appears before the snapshot and disappears when the scene is active again.
  - Write a pasteboard copy that's local-only, expires, and is cleared on background only if it's still the app's content.
  - Choose text field traits for a PIN, a one-time code and an account number, and justify each.
resources: [os-logger, uikit-app-life-cycle, swiftui-scenephase, uikit-encrypting-files, owasp-mastg]
cards:
  - id: m42-l05-c1
    front: "Logger: which interpolated values are redacted by default?"
    back: "Dynamic strings and complex objects are redacted; integers, floating-point values and Booleans aren't. An account number stored as an Int appears in the log unless you mark it .private (optionally with mask: .hash to correlate lines)."
  - id: m42-l05-c2
    front: When does UIKit take the app switcher snapshot?
    back: "After the scene enters the background and your delegate method returns. Hide sensitive content in sceneDidEnterBackground at the latest (many apps also cover in sceneWillResignActive) and remove the cover in sceneDidBecomeActive."
  - id: m42-l05-c3
    front: Two pasteboard options for a copied account number?
    back: "localOnly (no Universal Clipboard to other devices) and expirationDate (the system removes the item at that time), passed to UIPasteboard.setItems(_:options:)."
  - id: m42-l05-c4
    front: Does isExcludedFromBackup guarantee a file isn't backed up?
    back: "No. Apple: it \"exists only to provide guidance to the system ... it's not a mechanism to guarantee those items never appear in a backup or on a restored device.\" It's for re-creatable data; secrets belong in the Keychain with a ThisDeviceOnly class."
  - id: m42-l05-c5
    front: How does an app keep third-party keyboards away from all its fields?
    back: "Implement application(_:shouldAllowExtensionPointIdentifier:) in the app delegate and return false for .keyboard. isSecureTextEntry also keeps individual fields on the system keyboard."
---

## The idea in one sentence

Most leaks aren't attacks: they're side effects of normal platform features (logging, the app switcher, copy and paste, backups, keyboard suggestions), so you go through each one, decide what a banking app's data should do there, and make that the default in code.

> [!note] Sources and what was checked
> From Apple: "Generating Log Messages from Your Code", `OSLogPrivacy` and its options, "Preparing your UI to run in the background", `UIPasteboard` (overview, `setItems(_:options:)`, `OptionsKey.localOnly` and `.expirationDate`, `changeCount`, `items`, `detectedPatterns(for:)`), `privacySensitive(_:)` and `redacted(reason:)`, `sceneCaptureState`, `UIScreen.isCaptured`, `userDidTakeScreenshotNotification`, "Optimizing your app's data for iCloud Backup", `isExcludedFromBackup`, `isSecureTextEntry` and `application(_:shouldAllowExtensionPointIdentifier:)`. From OWASP: MASVS-STORAGE-2, MASVS-PLATFORM-3 and the iOS MASTG tests named below. All read in November 2026. The UIKit, SwiftUI and OSLog blocks were type-checked against the iOS SDK, not run. The redaction and masking code is pure Swift, compiled and run with Swift 6.3. Card numbers in this lesson are public test numbers, not real cards.

## The leak map

MASVS-STORAGE-2 covers data "unintentionally stored or exposed to publicly accessible locations; typically as a side-effect of using certain APIs, system capabilities such as backups or logs." MASVS-PLATFORM-3 covers the UI: data that ends up "unintentionally leaked due to platform mechanisms such as auto-generated screenshots or accidentally disclosed via e.g. shoulder surfing." For Harbor Bank:

| Channel | Who can see it | Lesson 1 threat | MASWE |
| --- | --- | --- | --- |
| Device logs | Anyone with the device and a Mac, a sysdiagnose, your crash reporter | T5 | MASWE-0005 |
| App switcher snapshot | Anyone who sees the phone | T6 | MASWE-0038 |
| General pasteboard | Every app the person pastes into, nearby devices | | MASWE-0030 |
| Backups | Whoever holds the backup | T1 | MASWE-0006 |
| Keyboard | Keyboard suggestions; third-party keyboards with full access | | MASWE-0036 and related |

## Logs

Module 21 introduced `Logger`, Module 30 redacted request logs, and Module 41 kept telemetry to an allowlist. Two details are worth knowing exactly.

**What's redacted by default.** Apple: "By default, the system doesn't redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and complex dynamic objects." An account number stored as an `Int` is logged in full unless you mark it:

```swift ios
import os

let log = Logger(subsystem: "com.example.harborbank", category: "transfers")

let transferID = "TX-55102"
let payeeName = "Ana López"
let accountNumber = 10012345678          // an Int: NOT redacted unless you say so
let amountInCents = 2550

log.info("Transfer \(transferID, privacy: .public) to \(payeeName) started")
log.error("Account \(accountNumber, privacy: .private(mask: .hash)) rejected the transfer")
log.debug("Amount \(amountInCents, privacy: .private)")
```

- **`transferID` is `.public`** on purpose: it's an opaque ID you need to correlate with server logs.
- **`payeeName`** gets the default for a dynamic string: redacted.
- **`accountNumber`** is an `Int`, so it's marked `.private(mask: .hash)`. Apple: the hash "is unique for the current process" and lets you see that several lines refer to the same value without seeing it.
- **`.sensitive`** "behaves identically to the private option"; use whichever name your team agrees on.

**Where logs go.** Apple: "The system stores all messages in memory initially, and it writes messages with more severe log levels to disk," while debug and info normally stay in memory. An `.error` line with an account number survives on disk. And `print` isn't safer: MASTG-TEST-0297 lists `NSLog`, `print` and `printf` among the logging APIs it checks, and notes that while other apps can't read these logs, "direct logging is generally discouraged due to its potential for data leakage."

**Text you build yourself.** Crash reporters, support tools and analytics take strings. Anything that turns free text into a log line or an event should run through a redaction function you can test:

```swift
/// The Luhn checksum that card numbers carry: double every second digit from the right.
func passesLuhn(_ digits: [Int]) -> Bool {
    var sum = 0
    for (offset, digit) in digits.reversed().enumerated() {
        if offset % 2 == 1 {
            let doubled = digit * 2
            sum += doubled > 9 ? doubled - 9 : doubled
        } else {
            sum += digit
        }
    }
    return sum % 10 == 0
}

func redactWord(_ word: Substring) -> String {
    if word.contains("@") && word.contains(".") { return "<email>" }
    let digits = word.compactMap { $0.wholeNumberValue }
    let onlyDigitsAndSeparators = word.allSatisfy { $0.isNumber || $0 == "-" }
    if onlyDigitsAndSeparators && (13...19).contains(digits.count) && passesLuhn(digits) {
        return "<card ****\(digits.suffix(4).map(String.init).joined())>"
    }
    if onlyDigitsAndSeparators && digits.count >= 8 { return "<number>" }
    return String(word)
}

/// Redacts word by word. Bearer tokens are dropped along with the word after them.
func redact(_ line: String) -> String {
    var output: [String] = []
    var hideNext = false
    for word in line.split(separator: " ") {
        if hideNext { output.append("<token>"); hideNext = false; continue }
        if word.lowercased() == "bearer" { output.append(String(word)); hideNext = true; continue }
        output.append(redactWord(word))
    }
    return output.joined(separator: " ")
}

let lines = [
    "transfer from 4242424242424242 to 10012345678 failed",
    "card 4242-4242-4242-4241 rejected",
    "support asked ana.lopez@example.com to retry",
    "retrying with Bearer eyJhbGciOiJFUzI1NiJ9.fake.sig",
    "order 20261104 total 52",
]
for line in lines { print(redact(line)) }
```

```output
transfer from <card ****4242> to <number> failed
card <number> rejected
support asked <email> to retry
retrying with Bearer <token>
order <number> total 52
```

- **Luhn** recognizes card-shaped numbers (13 to 19 digits that pass the checksum) and keeps only the last four, the usual display form. `4242424242424242` is a widely published test card number.
- **The second line fails Luhn**, so it's not shown as a card, but it's still a long digit run and gets `<number>`. Failing one rule shouldn't mean leaking.
- **`20261104`** is a date, and it's redacted too. Over-redaction is the right failure mode for logs; if you need a value, log it as a field you've reviewed, not inside free text.
- **The token** is removed by position, after the word `Bearer`, because tokens have no fixed shape.

This is a blocklist, with the weakness Module 41 described: a new kind of sensitive value slips through until someone adds a rule. Use it as a safety net under structured, allowlisted logging, never instead of it.

## The app switcher snapshot

Apple's "Preparing your UI to run in the background": "After your app enters the background and your delegate method returns, UIKit takes a snapshot of your app's current user interface. The system displays the resulting image in the app switcher." And: "Your app's UI must not contain any sensitive user information, such as passwords or credit card numbers. If your interface contains such information, remove it from your views when entering the background." MASTG-TEST-0290 checks this by backgrounding the app on each sensitive screen and inspecting the stored snapshots.

In a UIKit app with scenes, cover the window:

```swift ios
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var privacyCover: UIView?

    func sceneWillResignActive(_ scene: UIScene) {
        coverContent()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        coverContent()           // UIKit takes the app switcher snapshot after this returns
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        privacyCover?.removeFromSuperview()
        privacyCover = nil
    }

    private func coverContent() {
        guard let window, privacyCover == nil else { return }
        let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        cover.frame = window.bounds
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        privacyCover = cover
    }
}
```

- **`sceneDidEnterBackground`** is the one Apple documents for the snapshot. Covering there is the requirement.
- **`sceneWillResignActive`** runs earlier, on any deactivation, including the system alerts and panels Apple mentions. Covering there too hides balances while a system panel is over the app. It's a product decision: some apps prefer the content to stay visible behind a permission alert.
- **`sceneDidBecomeActive`** removes the cover. The `privacyCover == nil` guard makes covering idempotent when both methods run.
- **A blur, not a blank view.** Apple wants the snapshot to "be recognizable to users." A blur of the layout, or your logo, does that without the numbers.

In SwiftUI, mark the sensitive views and redact them whenever the scene isn't active. Apple's `privacySensitive(_:)` page: "SwiftUI redacts views marked with this modifier when you apply the privacy redaction reason."

```swift ios
import SwiftUI

struct BalanceCard: View {
    @Environment(\.scenePhase) private var scenePhase
    let accountName: String
    let balance: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(accountName)
            Text(balance)
                .font(.largeTitle)
                .privacySensitive()
        }
        .redacted(reason: scenePhase == .active ? [] : .privacy)
    }
}
```

Only the balance is redacted; the account name stays readable so the snapshot is still recognizable.

**Screenshots and recording.** There's no API to prevent a person from taking a screenshot of their own screen. `userDidTakeScreenshotNotification` "posts after the screenshot is taken," so it can only inform (some banks show a reminder not to share it). For recording and mirroring, iOS 17 added the `sceneCaptureState` trait; the older `UIScreen.isCaptured` is documented as deprecated as of iOS 27. And `isSecureTextEntry`, below, "in some cases" disables recording of that field's text, in Apple's words.

## The pasteboard

The general pasteboard is shared by every app, and Apple's overview says that "when a user signs into iCloud, the general pasteboard automatically transfers its contents to nearby devices that use the same iCloud account." MASTG has a cluster of tests for it: 0276 (use of the general pasteboard for sensitive data), 0278 (contents not cleared), 0279 (not expiring) and 0280 (not restricted to the local device).

Copying an account number so the person can paste it into a message is a legitimate feature. Make it local and short-lived:

```swift ios
import UIKit
import UniformTypeIdentifiers

/// Copies an account number for pasting into another app, without letting it linger or travel.
@MainActor
final class SensitiveCopy {
    private var changeCountAfterOurCopy: Int?

    func copy(_ accountNumber: String, expiresAfter seconds: TimeInterval = 60) {
        let pasteboard = UIPasteboard.general
        pasteboard.setItems(
            [[UTType.plainText.identifier: accountNumber]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(seconds)]
        )
        changeCountAfterOurCopy = pasteboard.changeCount
    }

    /// Call when the scene goes to the background. Clears only if nobody copied anything since.
    func clearIfStillOurs() {
        let pasteboard = UIPasteboard.general
        guard let ours = changeCountAfterOurCopy, pasteboard.changeCount == ours else { return }
        pasteboard.items = []
        changeCountAfterOurCopy = nil
    }
}
```

- **`.localOnly`** keeps the item off other devices: Apple describes it as "pasteboard items should not be available to other devices through the Handoff feature."
- **`.expirationDate`**: "the system removes the pasteboard items from the pasteboard" at that time.
- **Clearing on background is a trade-off.** MASTG-TEST-0278 suggests clearing when the app moves to the background. But the person copied the number *to paste somewhere else*, which means leaving your app. Clearing immediately breaks the feature; the expiration handles cleanup. If you do clear, only clear your own content: `changeCount` increments whenever the contents change, so comparing it with the value right after your copy tells you whether anything else was copied since.
- **Reading is the other direction.** Since iOS 14 the system tells the person when an app reads pasteboard content from another app without a paste action. To decide whether to offer "Paste account number" without reading, use the `has…` properties (`hasStrings`, `hasURLs`) or the pattern detection API, which Apple says doesn't trigger that notice because it "doesn't allow the app to access the contents":

```swift illustrative
let patterns = try await UIPasteboard.general.detectedPatterns(for: [\UIPasteboard.DetectedValues.number])
let looksLikeNumber = patterns.contains(\UIPasteboard.DetectedValues.number)
```

That fragment is illustrative: `detectedPatterns(for:)` (iOS 15) is async and returns key paths, which aren't `Sendable` in Swift 6, so where you call it from matters, and it wasn't type-checked here.

For your own app's internal copy and paste of sensitive data (between screens), don't use the general pasteboard at all; pass the value in memory.

## Backups

Module 21 covered what a backup contains: your container's Documents and Library, but not `tmp` or `Library/Caches`. For a bank the rules are short:

- **Credentials and keys:** in the Keychain with a `ThisDeviceOnly` class (Lesson 2). Apple Platform Security: such items, when copied in a backup, are "rendered useless" on a different device.
- **Re-downloadable data** (statements, cached transactions) doesn't need to be in a backup at all. If it's not in `Caches` (which the system may purge), mark it excluded:

```swift ios
import Foundation

/// A folder for files the app can download again: excluded from backups, and complete protection.
func offlineStatementsFolder() throws -> URL {
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
    var folder = support.appending(path: "com.example.harborbank/offline-statements", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                            attributes: [.protectionKey: FileProtectionType.complete])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try folder.setResourceValues(values)
    return folder
}
```

- **Exclude a folder, not each file.** Apple: to exclude a group of files, "move those files into a directory and update the directory's `isExcludedFromBackup` resource value," named with your bundle identifier inside Library.
- **It's guidance.** Apple: it "exists only to provide guidance to the system about which files and directories it can exclude; it's not a mechanism to guarantee those items never appear in a backup or on a restored device." MASTG-TEST-0215 quotes the same sentence. Never use it as the protection for a secret.
- **Some operations reset it.** Apple: "certain file operations can reset resource values, make sure you set an excluded file's resource values each time you save it," and the property "should not be used on user documents." Setting it on the folder each launch is cheap.

## Keyboards and text fields

Two separate concerns: what the system keyboard learns from what's typed, and whether a third-party keyboard sees it at all.

**Learning.** MASTG-TEST-0313 says that "on iOS, the keyboard may suggest previously entered text when typing in any app on the device," that "by default, text input is eligible for keyboard caching," and it checks for `UITextAutocorrectionType`, `isSecureTextEntry` and `spellCheckingType` on sensitive fields.

**Third-party keyboards.** MASTG-TEST-0389: a custom keyboard with "Full Access" "can transmit what the user types off the device," and "high-assurance apps, for example banking apps," reject custom keyboards app-wide. Apple's delegate method for this: "In iOS 8.0, the only type of app extension you can reject is the custom keyboard."

```swift ios
import UIKit

@MainActor
func configureSecurityFields(pin: UITextField, oneTimeCode: UITextField, accountNumber: UITextField) {
    pin.isSecureTextEntry = true               // obscured and can't be copied
    pin.keyboardType = .numberPad

    oneTimeCode.textContentType = .oneTimeCode // lets the system offer the code from Messages
    oneTimeCode.keyboardType = .numberPad
    oneTimeCode.autocorrectionType = .no

    accountNumber.autocorrectionType = .no     // visible, but not offered as a suggestion later
    accountNumber.spellCheckingType = .no
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Banking input never goes through a third-party keyboard.
    func application(_ application: UIApplication,
                     shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        extensionPointIdentifier != .keyboard
    }
}
```

- **`isSecureTextEntry`**, per Apple, "disables the user's ability to copy the text in the view and, in some cases, also disables the user's ability to record and broadcast the text," and in a text field "the text being entered is obscured."
- **`.oneTimeCode`** lets iOS offer a code it received by message, so the person doesn't copy it through the pasteboard.
- **Turning off autocorrection and spell checking** on account and card fields keeps them out of suggestions. For SwiftUI, `autocorrectionDisabled()` and `SecureField` do the same jobs.
- **Rejecting keyboard extensions** is app-wide. It's a bank-appropriate trade-off: people who rely on a third-party keyboard for accessibility or language get the system keyboard in your app.

## Common mistakes

> [!error] `log.error("Login failed for \(accountNumber)")` with an Int
> Integers aren't redacted by default, and error-level messages are written to disk. Mark it `.private`, or log an opaque ID instead.

> [!error] `.public` to make debugging easier
> It stays public in the release build. Use `.private(mask: .hash)` when you need to correlate lines.

> [!error] Covering the screen in `viewWillDisappear`
> The snapshot is about the scene going to the background, not a view disappearing. Cover in the scene delegate, or use `scenePhase` in SwiftUI.

> [!error] `UIPasteboard.general.string = accountNumber`
> No expiration and Universal Clipboard to every nearby device. Use `setItems(_:options:)` with `.localOnly` and `.expirationDate`.

> [!error] Relying on isExcludedFromBackup for a token
> It's a hint about re-creatable data. Tokens go in the Keychain with a `ThisDeviceOnly` class.

## Exercises

````exercise
id: m42-l05-e1
type: prediction
prompt: "This is the redaction filter's Luhn check. What does it print?"
code: |
  func passesLuhn(_ digits: [Int]) -> Bool {
      var sum = 0
      for (offset, digit) in digits.reversed().enumerated() {
          if offset % 2 == 1 {
              let doubled = digit * 2
              sum += doubled > 9 ? doubled - 9 : doubled
          } else {
              sum += digit
          }
      }
      return sum % 10 == 0
  }

  print(passesLuhn([7, 9, 9, 2, 7, 3, 9, 8, 7, 1, 3]))
  print(passesLuhn([7, 9, 9, 2, 7, 3, 9, 8, 7, 1, 4]))
  print(passesLuhn([0]))
  print(passesLuhn([1, 8]))
output: |
  true
  false
  true
  true
hints:
  - "Start from the rightmost digit at offset 0; double the digits at odd offsets."
  - "A doubled digit above 9 contributes its two digits' sum, which is the same as subtracting 9."
solution: |
  ```output
  true
  false
  true
  true
  ```

  - `79927398713` is a common textbook Luhn example: the sum is 70, a multiple of 10.
  - Changing the last digit from 3 to 4 adds 1 to the sum (it's at offset 0, not doubled), so 71 fails.
  - `[0]`: the sum is 0, and 0 % 10 is 0, so it passes. That's why the filter also requires 13 to 19 digits before calling something a card.
  - `[1, 8]`: 8 at offset 0 counts as 8; 1 at offset 1 is doubled to 2; 10 passes.

  Luhn catches typos, not fraud: about one random digit string in ten passes. In a redaction filter that's fine, because the cost of a false positive is an extra `<card ****1234>` in a log.
````

````exercise
id: m42-l05-e2
type: comprehension
prompt: "Harbor Bank logs `Logger().error(\"Rejected account \\(accountNumber) for \\(customerName)\")`, where `accountNumber` is an `Int` and `customerName` a `String`, with no privacy options. What appears in a log collected from a customer's device?"
choices:
  - text: "The account number in full; the customer name redacted."
    correct: true
    why: "Integers aren't redacted by default; dynamic strings are."
  - text: "Both redacted."
    correct: false
    why: "Apple: \"the system doesn't redact integer, floating-point and Boolean values.\""
  - text: "Both in full."
    correct: false
    why: "Dynamic strings are redacted by default."
  - text: "Nothing, because error messages stay in memory."
    correct: false
    why: "It's the other way around: debug and info normally stay in memory, more severe levels are written to disk."
solution: |
  **The account number appears; the name is redacted.** That asymmetry is the trap: teams test with string identifiers, see `<private>`, and assume everything is safe. Mark the integer explicitly:

  ```swift ios
  import os

  let accountNumber = 10012345678
  let customerName = "Ana López"
  Logger().error("Rejected account \(accountNumber, privacy: .private(mask: .hash)) for \(customerName)")
  ```

  Better still, don't log the account number: log the opaque ID of the operation and look up details on the server.
````

````exercise
id: m42-l05-e3
type: fill-in
prompt: "Complete the copy so the account number never reaches other devices and disappears after two minutes."
code: |
  UIPasteboard.general.[[1]](
      [[UTType.plainText.identifier: accountNumber]],
      options: [.[[2]]: true, .[[3]]: Date().addingTimeInterval([[4]])]
  )
blanks:
  - id: "1"
    answers: ["setItems"]
  - id: "2"
    answers: ["localOnly"]
  - id: "3"
    answers: ["expirationDate"]
  - id: "4"
    answers: ["120", "120.0", "2 * 60"]
solution: |
  ```swift illustrative
  UIPasteboard.general.setItems(
      [[UTType.plainText.identifier: accountNumber]],
      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
  )
  ```

  `setItems(_:options:)` is the only `UIPasteboard` setter that takes options for the whole set of items. `localOnly` stops Universal Clipboard; `expirationDate` is when the system removes the items. These are the two things MASTG-TEST-0280 and 0279 check for. The fragment depends on `accountNumber` from elsewhere; the lesson's `SensitiveCopy` is the complete version.
````

````exercise
id: m42-l05-e4
type: find-errors
prompt: "A pull request adds a \"Share statement\" screen. Mark every real problem."
code: |
  // StatementViewController
  override func viewDidLoad() {
      super.viewDidLoad()
      Logger().info("Showing statement for \(account.number, privacy: .public)")
      ibanLabel.text = account.iban
      try? pdf.write(to: documentsURL.appending(path: "statement.pdf"))
      UIPasteboard.general.string = account.iban
      showToast("IBAN copied")
  }
  // No changes to SceneDelegate.
choices:
  - text: "The account number is logged as .public."
    correct: true
  - text: "The IBAN is copied to the general pasteboard automatically, with no expiration and Universal Clipboard enabled."
    correct: true
  - text: "The statement is written to Documents with the default protection class and will be backed up."
    correct: true
  - text: "Nothing hides the IBAN and statement before the app switcher snapshot."
    correct: true
  - text: "UILabel can't display an IBAN because it's too long."
    correct: false
    why: "A label can show it; whether it should show it in full is a product decision (Exercise 5 masks it)."
rubric:
  - I flagged the public log.
  - I flagged the automatic, unrestricted pasteboard copy.
  - I flagged the file's location, protection class and backup.
  - I flagged the missing snapshot protection.
solution: |
  Four problems:

  1. **`.public` log.** Remove the value or use `.private(mask: .hash)`.
  2. **Automatic copy.** Copying without the person asking puts the IBAN on every app's pasteboard. Copy only on a tap, with `.localOnly` and `.expirationDate`.
  3. **The PDF.** Documents is backed up (and can show up in the Files app if the app enables file sharing); the default protection class leaves it readable after first unlock. Write it to an excluded Application Support folder with `.completeFileProtection`, or keep it in memory and hand it to the share sheet.
  4. **Snapshot.** The scene delegate needs the privacy cover, or the view needs redaction when the scene isn't active.

  Showing the full IBAN on screen may also be more than needed; Exercise 5 shows a masked form.
````

````exercise
id: m42-l05-e5
type: solve
prompt: |
  Write `maskedForDisplay(_:)` for account numbers shown in lists. Remove whitespace and uppercase the value; if what's left isn't 8 or more ASCII letters and digits, return `"invalid account"`. Otherwise keep only the last four characters, and if the value starts with two letters (an IBAN country code), show them first.

  Expected output:

  ```output
  GB •••• 5678
  •••• 5678
  GB •••• 7766
  invalid account
  invalid account
  ```
starter: |
  func maskedForDisplay(_ account: String) -> String {
      // your code
      return ""
  }

  for account in ["GB00 HRBR 0000 0012 3456 78", "10012345678", "gb00hrbr00000099887766", "1234", "ACC-7731-0042"] {
      print(maskedForDisplay(account))
  }
hints:
  - "filter { !$0.isWhitespace } removes the spaces."
  - "Check every character with isASCII and (isLetter || isNumber); the hyphen makes the last input invalid."
  - "prefix(2) and suffix(4) give the pieces."
rubric:
  - Normalizes spaces and case.
  - Rejects short values and characters other than ASCII letters and digits.
  - Shows a country code only when the first two characters are letters.
  - Prints the five expected lines.
solution: |
  ```swift
  /// Shows only what a person needs to recognize the account: country code (for an IBAN) and last 4.
  func maskedForDisplay(_ account: String) -> String {
      let compact = account.filter { !$0.isWhitespace }.uppercased()
      guard compact.count >= 8, compact.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
          return "invalid account"
      }
      let lastFour = String(compact.suffix(4))
      let start = compact.prefix(2)
      if start.allSatisfy({ $0.isLetter }) {
          return "\(start) •••• \(lastFour)"
      }
      return "•••• \(lastFour)"
  }

  for account in ["GB00 HRBR 0000 0012 3456 78", "10012345678", "gb00hrbr00000099887766", "1234", "ACC-7731-0042"] {
      print(maskedForDisplay(account))
  }
  ```

  ```output
  GB •••• 5678
  •••• 5678
  GB •••• 7766
  invalid account
  invalid account
  ```

  This is MASWE-0036, "Unnecessary Exposure of Sensitive Data via the User Interface," solved at the source: lists and confirmations show enough to recognize the account, and the full number appears only on a screen the person opens deliberately (behind authentication if the threat model says so). The account numbers here are made up.

  Validation failing closed ("invalid account") is deliberate: a display function that echoes unexpected input would print whatever a bug put in the field.
````

````exercise
id: m42-l05-e6
type: design
prompt: "Harbor Bank's one-time passcode screen: a 6-digit code arrives by SMS and the person enters it to approve a new payee. Go through every leak channel from this lesson and say what you'd do on this screen for each."
rubric:
  - Logs never contain the code; the request logger redacts it.
  - The screen is covered before the snapshot, and the code field is cleared on background.
  - The field uses .oneTimeCode and numberPad, no pasteboard copy feature, and autocorrection off.
  - Third-party keyboards are rejected app-wide; nothing about the code is written to disk or backups.
solution: |
  - **Logs.** The code is never interpolated into a `Logger` call, not even `.private`. The request that submits it goes through the Module 30 redacting logger with `code` in its parameter list. Crash reports and analytics never see the field's value.
  - **Snapshot.** The scene delegate cover hides the screen; additionally, clear the text field when the scene goes to the background, so a code typed but not submitted doesn't survive.
  - **Pasteboard.** Use `textContentType = .oneTimeCode` so iOS offers the code from Messages directly, and don't add a "copy" or "paste code" button that pushes people to the general pasteboard.
  - **Keyboard.** `.numberPad`, autocorrection and spell checking off. The app delegate already rejects keyboard extensions app-wide. Whether to set `isSecureTextEntry` is a judgment call: obscuring a 6-digit code makes it harder to type and the code expires in minutes; many banks show it.
  - **Backups and files.** Nothing about the code is persisted. If the flow is interrupted, the server issues a new code rather than the app saving the old one.
  - **Server side,** for completeness: short expiry, single use, rate limits and a constant-time comparison (Lesson 3).
````

## Summary

- Logs: dynamic strings are redacted by default, integers, floats and Booleans aren't. Mark sensitive values `.private` (with `mask: .hash` to correlate), never `.public` for convenience, and run free text through a tested redaction function as a safety net under allowlisted logging.
- The app switcher snapshot is taken after the scene enters the background. Cover sensitive content in `sceneDidEnterBackground` (and optionally `sceneWillResignActive`), or use `privacySensitive()` with `.redacted(reason: .privacy)` when the scene isn't active.
- Copy sensitive values with `setItems(_:options:)`, `.localOnly` and `.expirationDate`; clear only content that's still yours; use `has…` properties or pattern detection instead of reading the pasteboard to decide what to offer.
- Keep secrets in the Keychain with `ThisDeviceOnly`; exclude re-downloadable folders from backup, knowing `isExcludedFromBackup` is guidance, not a guarantee.
- Use `.oneTimeCode`, `isSecureTextEntry` and disabled autocorrection on sensitive fields, and reject third-party keyboards app-wide with `application(_:shouldAllowExtensionPointIdentifier:)`.
