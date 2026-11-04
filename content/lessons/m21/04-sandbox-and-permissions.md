---
id: m21-l04
title: Sandbox, permissions and privacy
description: The walls around an iOS app and the doors through them. You learn which container directory each kind of file belongs in and what gets backed up, how purpose strings and authorization requests work for protected resources like the camera, how to handle every authorization status, and what a privacy manifest declares and when App Store Connect requires it.
module: m21
order: 4
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m21-l03]
objectives:
  - Explain what the iOS sandbox prevents and what an app's container holds.
  - Choose between Documents, Application Support, Caches and tmp for a file, and know which are backed up.
  - Add a usage description for a protected resource and explain what happens without one.
  - Check and request authorization at the right moment and handle every status.
  - Describe the four top-level keys of a privacy manifest and the required reason API rules.
terms:
  - term: Sandbox
    definition: "The restriction that keeps every third-party app inside its own container: it can't read or modify other apps' data or change the system, except through services iOS provides."
  - term: Container
    definition: "The app's own directory on the device, randomly assigned at install. It holds Documents, Library (with Application Support and Caches) and tmp."
  - term: Entitlement
    definition: "A signed key-value pair in the app's code signature that grants a capability, such as iCloud or an app group. Being signed, it can't be changed after the fact."
  - term: Purpose string
    definition: "The usage description (for example NSCameraUsageDescription) the system shows when it asks the person for access to a protected resource."
  - term: Protected resource
    definition: "Data or hardware the system guards behind the person's permission: camera, microphone, location, photos, contacts and others."
  - term: Privacy manifest
    definition: "PrivacyInfo.xcprivacy, a property list in the app or SDK bundle that declares tracking, tracking domains, collected data types and the reasons for using required reason APIs."
  - term: Required reason API
    definition: "An API Apple has designated as usable for fingerprinting, such as UserDefaults or file timestamps. You must declare an approved reason for using it in your privacy manifest."
mastery:
  - Put a user's export, the app's database, downloaded thumbnails and a half-finished upload in the right directories and say which get backed up.
  - Write a specific, honest purpose string and add it through the matching Info.plist key.
  - Write the camera permission flow that checks status first and asks only when the feature is used.
  - Explain what the app should do for denied and restricted statuses.
  - Read a privacy manifest and say what each top-level key declares, including a UserDefaults reason.
resources: [apple-platform-security, app-review-guidelines, keychain-services, owasp-masvs]
cards:
  - id: m21-l04-c1
    front: Where do these go? User-created files; the app's database; re-downloadable thumbnails; a file only needed for this launch.
    back: "Documents; Library/Application Support; Library/Caches; tmp. Caches and tmp aren't backed up, and the system may purge them."
  - id: m21-l04-c2
    front: Why should you never store an absolute path to a file in your container?
    back: "The container's location is assigned by the system (randomly at install, per Apple Platform Security). Store paths relative to a standard directory and rebuild the URL each launch."
  - id: m21-l04-c3
    front: What happens if your app uses the camera without NSCameraUsageDescription?
    back: "Access fails and the app may crash; AVFoundation's docs say the system terminates the app. App Review also rejects apps whose code references protected-resource APIs without a purpose string, even from an SDK."
  - id: m21-l04-c4
    front: The four authorization statuses for the camera, and what to do with each?
    back: "notDetermined: request access when the feature is used. authorized: proceed. denied: explain and offer a link to Settings. restricted: the app isn't permitted; explain, don't nag."
  - id: m21-l04-c5
    front: What does a privacy manifest declare?
    back: "NSPrivacyTracking, NSPrivacyTrackingDomains, NSPrivacyCollectedDataTypes and NSPrivacyAccessedAPITypes (the required reason APIs used, each with approved reason codes, such as CA92.1 for app-only UserDefaults)."
---

## The idea in one sentence

Every iOS app lives in a sandbox with its own private folders and no access to anything else, and the only ways out are system services that ask the person first (camera, location, photos) or that you declare in advance (entitlements, privacy manifests).

> [!note] Sources and what was run
> The sandbox description quotes Apple Platform Security ("Security of runtime process in iOS, iPadOS, and visionOS"). Directories and backups come from Foundation's documentation, "Optimizing Your App's Data for iCloud Backup", and Apple's archived *File System Programming Guide*. Permissions come from "Requesting access to protected resources" and AVFoundation's authorization article; privacy manifests from Bundle Resources. All read in November 2026. Blocks that use Foundation's file APIs, AVFoundation or UIKit were type-checked against the iOS SDK but not run; the pure-Swift blocks were compiled and run with Swift 6.3. Xcode's UI steps weren't checked in Xcode.

## The sandbox

Apple Platform Security, in full: "All third-party apps are sandboxed. Sandboxing is designed to prevent apps from gathering or modifying information stored by other apps or from making changes to the device. Each app has a unique home directory for its files, which is randomly assigned when the app is installed. If a third-party app needs to access information other than its own, it does so only by using services explicitly provided by iOS."

In practice:

- Your app can read its own bundle and read and write its own **container**. Nothing else.
- To reach shared data (photos, contacts, location), you go through a framework that asks the person.
- Capabilities such as iCloud, push notifications or app groups are **entitlements**: key-value pairs in your code signature. Because they're signed, "they can't be changed." Lesson 5 shows where they come from.
- Apps from the same team can share files through an **app group** container (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`), which also needs an entitlement. That's how an app and its widget share data.

## The container

Inside the container, the standard directories each have a job:

| Directory | Put here | Backed up | Purged by the system |
| --- | --- | --- | --- |
| `Documents/` | Files the user creates or would recognize: exports, edited documents | Yes | No |
| `Library/Application Support/` | Files the app needs to run that the user shouldn't see: databases, downloaded configuration | Yes | No |
| `Library/Caches/` | Data you can recreate or download again: thumbnails, cached responses | No | Yes, periodically |
| `tmp/` | Files needed only briefly: an export being assembled, an upload in progress | No | Yes, may be emptied when the app isn't running |

The backup and purge columns come from Apple's iCloud backup article, which says `tmp` and `Library/Caches` are excluded from backup by default because "the system periodically purges these directories". The rest of `Library` and `Documents` are backed up.

Foundation gives you each directory as a URL (iOS 16 and later have the shorter `URL` properties):

```swift ios
import Foundation

let documents = URL.documentsDirectory
let support = URL.applicationSupportDirectory
let caches = URL.cachesDirectory
let temporary = URL.temporaryDirectory

let database = support.appending(path: "Expenses/store.sqlite")
let thumbnail = caches.appending(path: "thumbs/receipt-42.jpg")
print(database.lastPathComponent, thumbnail.lastPathComponent)
```

Rules that follow from the table:

- **Never save an absolute path.** The container is assigned by the system. Save `"Expenses/store.sqlite"` and rebuild the URL from `URL.applicationSupportDirectory` at launch.
- **Create the folder before writing.** `Application Support` may not exist yet in a fresh container; call `FileManager.default.createDirectory(at:withIntermediateDirectories:attributes:)` with `true` for intermediate directories.
- **Don't put big re-downloadable files in Documents.** They inflate the user's backup. If they must persist (offline movies, say), set `isExcludedFromBackup` on them; Apple warns that it's guidance to the system, and that "certain file operations can reset resource values", so set it each time you save.
- **Nothing in Caches is safe.** Read it with a fallback.

```swift ios
import Foundation

func saveOfflineEpisode(_ data: Data, named name: String) throws -> URL {
    let folder = URL.applicationSupportDirectory.appending(path: "Episodes")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var file = folder.appending(path: name)
    try data.write(to: file)

    // Large, re-downloadable, but it must survive purges: keep it, skip the backup.
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try file.setResourceValues(values)
    return file
}
```

Line by line: build the folder URL from the standard directory; create it if it's missing (no error if it exists); write the bytes; then set the resource value on the file, after writing, as Apple recommends.

Here's the decision as a function you can run:

```swift
enum FileKind {
    case userDocument, appDatabase, downloadedThumbnail, uploadInProgress
}

func directory(for kind: FileKind) -> String {
    switch kind {
    case .userDocument: return "Documents"
    case .appDatabase: return "Library/Application Support"
    case .downloadedThumbnail: return "Library/Caches"
    case .uploadInProgress: return "tmp"
    }
}

func isBackedUp(_ directory: String) -> Bool {
    directory != "Library/Caches" && directory != "tmp"
}

for kind in [FileKind.userDocument, .appDatabase, .downloadedThumbnail, .uploadInProgress] {
    let place = directory(for: kind)
    print("\(kind): \(place), backed up: \(isBackedUp(place))")
}
```

```output
userDocument: Documents, backed up: true
appDatabase: Library/Application Support, backed up: true
downloadedThumbnail: Library/Caches, backed up: false
uploadInProgress: tmp, backed up: false
```

> [!warning] Backups and secrets
> A backed-up directory leaves the device. Never store passwords, tokens or keys as files in the container; they belong in the Keychain, which Module 42 covers with its protection classes.

## Protected resources and purpose strings

Some data and hardware need the person's permission: camera, microphone, location, photos, contacts, Bluetooth and more. Apple's rule: "Ensure your app accesses only what it needs to do its job."

The first time your app tries to use one, the system shows a prompt. It writes the title, which includes your app's name; **you** provide the message, the **purpose string**, as an Info.plist key:

| Resource | Key |
| --- | --- |
| Camera | `NSCameraUsageDescription` |
| Microphone | `NSMicrophoneUsageDescription` |
| Photo library (read and write) | `NSPhotoLibraryUsageDescription` |
| Photo library (add only) | `NSPhotoLibraryAddUsageDescription` |
| Location while the app is in use | `NSLocationWhenInUseUsageDescription` |

Apple's documented requirements for a purpose string: not blank or only whitespace; shorter than 4,000 bytes; the type the key expects (a string); and "accurate, meaningful, and specific about why the app needs to access the protected resource." Localize it with a string catalog named `InfoPlist.xcstrings`.

Compare:

- Weak: `"This app needs camera access."` It says nothing the prompt doesn't.
- Good: `"Scan receipts so their amounts are added to your expenses."` It says what you'll do and what the person gets.

What happens without one is severe. Apple: attempts to access the resource "fail, and might cause your app to crash"; AVFoundation's article is blunter, saying that without the key "the system terminates your app." And App Review rejects apps whose code **references** such APIs without a purpose string, with the message `ITMS-90683: Missing purpose string in Info.plist`, **even when the reference comes from a third-party SDK** you never call. "You're responsible for all access of protected resources, including external SDK and library access."

In a project that generates its Info.plist, the purpose string is a build setting such as `INFOPLIST_KEY_NSCameraUsageDescription`. Apple's article describes adding it from the Signing & Capabilities editor.

### Checking and requesting authorization

Each framework has its own status API. For the camera, `AVCaptureDevice.authorizationStatus(for:)` returns an `AVAuthorizationStatus`:

| Status | Apple's description | What the app does |
| --- | --- | --- |
| `.notDetermined` | "the user hasn't yet granted or denied authorization" | Request access, when the feature is used |
| `.authorized` | Access granted | Proceed |
| `.denied` | "the user has explicitly denied an app permission" | Explain what doesn't work, offer to open Settings |
| `.restricted` | "the app isn't permitted to use media capture devices" | Explain; the person may not be able to change it |

The system only prompts once. Apple: "If the person grants permission, the system remembers the person's choice and doesn't prompt again. If the person denies permission, the access attempt that initiates the prompt, and any further attempts, fail in a resource-specific way." People can change the setting at any time in Settings, so **check the status every time** before using the resource.

The flow from AVFoundation's documentation, as a function you'd call when the user taps "Scan receipt":

```swift ios
import AVFoundation
import UIKit

func cameraIsAvailable() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)   // shows the system prompt
    case .denied, .restricted:
        return false
    @unknown default:
        return false
    }
}

@MainActor
func openAppSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

- `requestAccess(for:)` has an `async` version that returns the person's answer, so the code reads top to bottom. (`async`/`await` is Module 29; here it just means "wait for the answer without blocking the main thread".)
- `@unknown default` handles statuses a future SDK might add. Apple's enums can grow, and the compiler warns if a switch over one doesn't handle that case.
- `UIApplication.openSettingsURLString` opens your app's page in Settings, the only fix the person has after denying.

The same decision, separated from the framework so it can run:

```swift
enum CameraAccess {
    case notDetermined, restricted, denied, authorized
}

func nextStep(for status: CameraAccess) -> String {
    switch status {
    case .authorized:
        return "open the scanner"
    case .notDetermined:
        return "ask the system to prompt"
    case .denied:
        return "explain, and offer a button to Settings"
    case .restricted:
        return "explain that the app isn't permitted to use the camera"
    }
}

for status in [CameraAccess.notDetermined, .authorized, .denied, .restricted] {
    print("\(status) → \(nextStep(for: status))")
}
```

```output
notDetermined → ask the system to prompt
authorized → open the scanner
denied → explain, and offer a button to Settings
restricted → explain that the app isn't permitted to use the camera
```

### When to ask

Apple's advice is to request access "only at a time that's appropriate", for example "only when the user invokes your app's camera-related features." Asking for everything at first launch fails twice: the person has no context, so they say no, and since the system won't prompt again, that no is permanent unless they find the switch in Settings.

A pattern that respects this: show your own screen explaining the feature first, then trigger the system prompt when they tap to continue. The system prompt is still the one that decides.

## Privacy manifests

A **privacy manifest** is a property list named `PrivacyInfo.xcprivacy` that an app or a third-party SDK includes in its bundle (at the root for iOS). It declares four things:

| Key | Declares |
| --- | --- |
| `NSPrivacyTracking` | Whether the app or SDK uses data for tracking, as defined by App Tracking Transparency |
| `NSPrivacyTrackingDomains` | The domains it contacts that engage in tracking. If the person hasn't allowed tracking, requests to these domains fail |
| `NSPrivacyCollectedDataTypes` | The types of data collected and how they're used |
| `NSPrivacyAccessedAPITypes` | The **required reason APIs** it uses, each with approved reason codes |

### Required reason APIs

Some ordinary APIs can be misused for **fingerprinting**: building an identifier for a device from its signals. Apple: "Regardless of whether a user gives your app permission to track, fingerprinting is not allowed." The current categories are file timestamps, system boot time, disk space, active keyboards and user defaults. For each category your code uses, you declare reasons from Apple's list.

`UserDefaults` is the one nearly every app hits. Reason `CA92.1` covers reading and writing information "only accessible to the app itself":

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

The dates and rules, from Apple's documentation:

- Since **May 1, 2024**, App Store Connect doesn't accept apps that use required reason APIs without describing the reason in their privacy manifest.
- Since **February 12, 2025**, apps must contain a valid privacy manifest for certain commonly used third-party SDKs, listed in Apple's "Upcoming third-party SDK requirements".
- Each SDK reports its own use. An SDK "can't rely on the privacy manifest files for apps that link the third-party SDK", and each executable or dynamic library that uses a required reason API needs a manifest in the bundle that contains it.
- An invalid manifest (unexpected keys or values) gets the submission rejected.
- You may use the API and its data only for the declared reasons, never for tracking.

Apple says it updates the categories and reasons over time. Check the current list in "Describing use of required reason API" rather than copying a manifest from an old project.

## Common mistakes

> [!error] Storing an absolute file path
> Saved paths like `/var/mobile/Containers/Data/Application/<id>/Documents/a.pdf` break. Store the relative part and rebuild it from `URL.documentsDirectory`.

> [!error] Caching downloads in Documents
> They get backed up and never purged. Recreatable data belongs in `Library/Caches`.

> [!error] Shipping without a purpose string because "we don't use the camera"
> If any code in the app references the API, including an SDK's, App Review asks for the key. Remove the dependency or write an honest string.

> [!error] Asking for every permission at launch
> No context, more denials, and the system won't ask again. Request at the moment of use.

> [!error] Treating denied as notDetermined
> After a denial, `requestAccess` won't show the prompt. Explain what's missing and link to Settings.

> [!error] Relying on an SDK's documentation instead of its manifest
> Each SDK must ship its own privacy manifest for its required reason API use. Your app's manifest doesn't cover it.

## Exercises

````exercise
id: m21-l04-e1
type: comprehension
prompt: "A recipe app downloads 300 photo thumbnails it can fetch again any time. Where should it save them?"
choices:
  - text: "`Library/Caches`"
    correct: true
    why: "Recreatable data. It's excluded from backup and the system can purge it."
  - text: "`Documents`"
    correct: false
    why: Documents is for user-created files and gets backed up.
  - text: "`Library/Application Support`"
    correct: false
    why: "Backed up and never purged, so 300 recreatable files would bloat the backup."
  - text: "Inside the app bundle"
    correct: false
    why: The bundle is signed and read-only.
solution: |
  **`Library/Caches`.** Thumbnails are purgeable data: the app can download or regenerate them. Apple's backup article names `Library/Caches` and `tmp` as the places for such data, excluded from iCloud Backup by default. The code that reads them must handle a missing file, since the system may purge the folder.
````

````exercise
id: m21-l04-e2
type: prediction
prompt: "This classifies files for a notes app using the lesson's rules. What does it print?"
code: |
  enum FileKind {
      case userDocument, appDatabase, downloadedThumbnail, uploadInProgress
  }

  func directory(for kind: FileKind) -> String {
      switch kind {
      case .userDocument: return "Documents"
      case .appDatabase: return "Library/Application Support"
      case .downloadedThumbnail: return "Library/Caches"
      case .uploadInProgress: return "tmp"
      }
  }

  let files: [(String, FileKind)] = [
      ("Trip notes.pdf", .userDocument),
      ("notes.sqlite", .appDatabase),
      ("preview-7.png", .downloadedThumbnail),
  ]
  var backedUp = 0
  for (name, kind) in files {
      let place = directory(for: kind)
      if place != "Library/Caches" && place != "tmp" {
          backedUp += 1
      }
      print("\(place)/\(name)")
  }
  print("\(backedUp) of \(files.count) backed up")
output: |
  Documents/Trip notes.pdf
  Library/Application Support/notes.sqlite
  Library/Caches/preview-7.png
  2 of 3 backed up
hints:
  - "The tuple pattern (name, kind) unpacks each element of the array."
  - "Only Caches and tmp are excluded from backup."
solution: |
  ```output
  Documents/Trip notes.pdf
  Library/Application Support/notes.sqlite
  Library/Caches/preview-7.png
  2 of 3 backed up
  ```

  The PDF and the database are backed up; the preview isn't. In the real app those strings would be relative paths appended to `URL.documentsDirectory` and friends, never stored as absolute paths.
````

````exercise
id: m21-l04-e3
type: fill-in
prompt: Complete a privacy manifest entry for an app that stores its own settings in UserDefaults.
code: |
  <key>NSPrivacy[[1]]</key>
  <array>
      <dict>
          <key>NSPrivacyAccessedAPIType</key>
          <string>NSPrivacyAccessedAPICategory[[2]]</string>
          <key>NSPrivacyAccessedAPITypeReasons</key>
          <array>
              <string>[[3]]</string>
          </array>
      </dict>
  </array>
blanks:
  - id: "1"
    answers: ["AccessedAPITypes"]
  - id: "2"
    answers: ["UserDefaults"]
  - id: "3"
    answers: ["CA92.1"]
solution: |
  ```xml
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
      <dict>
          <key>NSPrivacyAccessedAPIType</key>
          <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
          <key>NSPrivacyAccessedAPITypeReasons</key>
          <array>
              <string>CA92.1</string>
          </array>
      </dict>
  </array>
  ```

  `CA92.1` is the reason for reading and writing information only the app itself can access. If the app shared defaults with its widget through an app group, the reason would be `1C8F.1` instead.
````

````exercise
id: m21-l04-e4
type: find-errors
prompt: "An expense app's receipt scanner. Mark every real problem."
code: |
  // Info.plist (generated): no NSCameraUsageDescription key

  // Called from didFinishLaunching, before any screen appears
  func setUpScanner() async {
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      UserDefaults.standard.set(granted, forKey: "cameraAllowed")
  }

  // Called when the user taps "Scan receipt"
  func scanTapped() {
      if UserDefaults.standard.bool(forKey: "cameraAllowed") {
          startCaptureSession()
      }
  }
choices:
  - text: "There's no NSCameraUsageDescription, so the system terminates the app when it requests camera access, and App Review would flag it."
    correct: true
  - text: "It asks for access at launch, with no context, instead of when the user taps Scan."
    correct: true
  - text: "It caches the answer in UserDefaults; the person can change the setting in Settings, so the status must be checked each time."
    correct: true
  - text: "requestAccess(for:) can only be called from a view controller."
    correct: false
    why: "It's a class method on AVCaptureDevice; it doesn't need a view controller."
  - text: "Using UserDefaults requires a privacy manifest reason, so this code won't compile."
    correct: false
    why: The manifest is checked by App Store Connect at submission, not by the compiler. The app does need a reason such as CA92.1.
rubric:
  - I found the missing purpose string and its consequences.
  - I found the permission request at launch.
  - I explained why a cached authorization result goes stale.
solution: |
  Three real problems:

  1. **No purpose string.** AVFoundation's docs say the app needs `NSCameraUsageDescription` before it requests access, "otherwise, the system terminates your app." Add a specific sentence, such as "Scan receipts so their amounts are added to your expenses."
  2. **Asking at launch.** The person sees a camera prompt before knowing the app scans receipts. Ask in `scanTapped()`.
  3. **Caching the result.** People change permissions in Settings. Call `AVCaptureDevice.authorizationStatus(for: .video)` every time, as in the lesson's `cameraIsAvailable()`, and handle `.denied` by explaining and offering Settings.

  The `UserDefaults` use does need a privacy manifest entry (`CA92.1`), but that's checked at submission, not by the compiler.
````

````exercise
id: m21-l04-e5
type: solve
prompt: |
  Write `purposeStringProblems(_:)`, which checks a purpose string against two of Apple's documented rules and returns a list of problems (empty if none):

  - it's empty or consists only of whitespace → `"empty or only whitespace"`
  - it's 4,000 bytes or longer in UTF-8 → `"4,000 bytes or longer"`

  Then print one line per candidate: its character count, its byte count and either `ok` or the problems joined with `"; "`.

  ```swift
  let candidates = ["Scan receipts to add expenses.", "   ", String(repeating: "é", count: 2000), ""]
  ```

  Expected output:

  ```output
  30 characters, 30 bytes: ok
  3 characters, 3 bytes: empty or only whitespace
  2000 characters, 4000 bytes: 4,000 bytes or longer
  0 characters, 0 bytes: empty or only whitespace
  ```
starter: |
  func purposeStringProblems(_ text: String) -> [String] {
      var problems: [String] = []
      // your code
      return problems
  }
hints:
  - "allSatisfy on a String checks every Character; Character has isWhitespace. For an empty string, allSatisfy returns true."
  - "text.utf8.count is the length in bytes. \"é\" takes two bytes in UTF-8."
rubric:
  - Treats empty and whitespace-only strings as one problem.
  - Measures bytes with utf8.count, not characters with count.
  - Uses "shorter than 4,000 bytes" correctly, so exactly 4,000 fails.
  - Prints the four lines in the expected format.
solution: |
  ```swift
  func purposeStringProblems(_ text: String) -> [String] {
      var problems: [String] = []
      if text.allSatisfy({ $0.isWhitespace }) {
          problems.append("empty or only whitespace")
      }
      if text.utf8.count >= 4000 {
          problems.append("4,000 bytes or longer")
      }
      return problems
  }

  let candidates = ["Scan receipts to add expenses.", "   ", String(repeating: "é", count: 2000), ""]
  for candidate in candidates {
      let problems = purposeStringProblems(candidate)
      let verdict = problems.isEmpty ? "ok" : problems.joined(separator: "; ")
      print("\(candidate.count) characters, \(candidate.utf8.count) bytes: \(verdict)")
  }
  ```

  ```output
  30 characters, 30 bytes: ok
  3 characters, 3 bytes: empty or only whitespace
  2000 characters, 4000 bytes: 4,000 bytes or longer
  0 characters, 0 bytes: empty or only whitespace
  ```

  Two details: `allSatisfy` is `true` for an empty collection, so one check covers both empty and whitespace-only strings. And the limit is in **bytes**: 2,000 `é` characters are 4,000 bytes in UTF-8, which already fails "shorter than 4,000 bytes". The rule a function can't check is the important one: whether the sentence is accurate and specific.
````

````exercise
id: m21-l04-e6
type: design
prompt: |
  A banking app adds check deposit: the person photographs a check, and the app sends the images to the bank. Design the privacy side of the feature:

  - which purpose string key(s) and the exact text,
  - when and how the app asks,
  - what each authorization status leads to,
  - where the check images live on the device and for how long,
  - what goes in the privacy manifest for this feature if the app also stores a "last deposit account" preference in UserDefaults.
rubric:
  - NSCameraUsageDescription with a specific sentence about photographing checks for deposit.
  - Asks only when the person starts a deposit, ideally after an explanation screen.
  - Handles notDetermined, authorized, denied (explain and offer Settings) and restricted.
  - Stores images in tmp (or Caches) only until upload succeeds, then deletes them; never in Documents; nothing backed up.
  - Declares UserDefaults with CA92.1 and the collected data types for the check images in the manifest.
solution: |
  - **Purpose string**: `NSCameraUsageDescription` = "Photograph the front and back of a check to deposit it into your account." It names the action and the benefit. No photo-library key is needed if the app only uses the camera; if it lets people pick an existing photo, add the photo-library key and explain that too.
  - **When**: only after the person taps "Deposit a check", on an explanation screen that shows what to photograph. Then trigger the system prompt.
  - **Statuses**: `.notDetermined` → request; `.authorized` → open the camera; `.denied` → a screen explaining deposits need the camera, with a button to Settings and an alternative (deposit at a branch or ATM); `.restricted` → explain that the device doesn't allow camera use by this app, without a Settings button that can't help.
  - **Storage**: check images are sensitive financial documents. Write them to `tmp`, upload, and delete them as soon as the bank confirms receipt; delete leftovers at the next launch too. Never in `Documents` (backed up, and Apple's guide says its contents can be exposed to the person through file sharing) and never in a backed-up folder.
  - **Manifest**: `NSPrivacyAccessedAPITypes` with `NSPrivacyAccessedAPICategoryUserDefaults` and reason `CA92.1`; `NSPrivacyCollectedDataTypes` describing the financial information collected for app functionality; `NSPrivacyTracking` false with no tracking domains. Module 42 adds the security controls on top: Keychain for credentials, no images in logs, hiding the screen for the app-switcher snapshot.
````

## Summary

- Every app is sandboxed: it reads its signed bundle, reads and writes its own container, and reaches anything else through system services. Capabilities come from signed entitlements.
- `Documents` for user files and `Library/Application Support` for app data are backed up. `Library/Caches` and `tmp` aren't, and the system purges them. Store relative paths, never absolute ones.
- Protected resources need a purpose string (`NSCameraUsageDescription` and friends): specific, non-empty, under 4,000 bytes. Without it the app can be terminated and App Review rejects it, even when only an SDK references the API.
- Check the authorization status every time, request at the moment of use, and handle `notDetermined`, `authorized`, `denied` (explain, link to Settings) and `restricted`.
- `PrivacyInfo.xcprivacy` declares tracking, tracking domains, collected data and required reason APIs. `UserDefaults` with `CA92.1` is the common case. Each SDK ships its own manifest; App Store Connect enforces the rules.
