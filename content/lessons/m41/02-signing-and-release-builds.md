---
id: m41-l02
title: Signing and release builds in automation
description: "Move release builds off one person's Mac. You learn what a distribution build needs that a development build doesn't, choose between automatic signing with an App Store Connect API key and manual signing with a certificate and profile in CI secrets, set up and tear down a temporary keychain on a runner, and archive and export with xcodebuild and an ExportOptions.plist. Builds on Module 21's signing lesson without repeating it."
module: m41
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m41-l01, m21-l05]
objectives:
  - Say what a distribution certificate and an App Store provisioning profile authorize, and how a profile is checked against a build.
  - Choose between automatic signing with an App Store Connect API key and manual signing in CI, and explain the trade-offs.
  - Store a signing identity, a profile and an API key as CI secrets and install them into a temporary keychain on a macOS runner.
  - Archive with xcodebuild archive and export or upload with xcodebuild -exportArchive and an ExportOptions.plist.
  - Protect release credentials with environments, tag-only triggers and cleanup.
terms:
  - term: Distribution certificate
    definition: "A certificate (with its private key) for signing builds you distribute through TestFlight, the App Store or Ad Hoc. Its common name starts with Apple Distribution."
  - term: App Store distribution profile
    definition: "A provisioning profile for builds uploaded to App Store Connect. It names the App ID, the allowed distribution certificates and the entitlements, and lists no devices, because an App Store-signed build can't run locally."
  - term: App Store Connect API key
    definition: "A key pair created in App Store Connect. Apple keeps the public part; you download the private .p8 once. It signs JSON Web Tokens for the API and can authenticate xcodebuild with the Apple Developer website."
  - term: Archive
    definition: "An .xcarchive bundle produced by xcodebuild archive or Product › Archive: the Release build of the app plus its dSYMs and metadata, ready to be exported or uploaded."
  - term: ExportOptions.plist
    definition: "The property list passed to xcodebuild -exportArchive with -exportOptionsPlist. It says how to distribute the archive: method, upload or local export, team and signing details."
  - term: Temporary keychain
    definition: "A keychain a CI job creates for one run, imports the signing identity into, adds to the search list and deletes at the end."
mastery:
  - Predict whether an App ID, explicit or wildcard, covers a bundle ID, and list what else a profile must allow.
  - Write the CI steps that decode a .p12 and a profile from secrets, create and unlock a keychain, import the identity and clean up.
  - Write an archive and export step with xcodebuild, and an ExportOptions.plist for an App Store Connect upload.
  - Explain when to use automatic signing with an API key and when to sign manually.
  - Keep release credentials out of pull request builds, logs and caches, and know what to revoke when one leaks.
resources: [xcode-distributing-beta-release, xcode-sharing-signing-certificates, asc-api-keys, gha-sign-xcode, tn3125-provisioning-profiles, xcode-build-settings-reference, xcode-build-configuration-file, keychain-services]
cards:
  - id: m41-l02-c1
    front: Why doesn't an App Store distribution profile list any devices?
    back: "TN3125: you can't run an App Store distribution-signed app locally. The App Store checks signing when you upload and re-signs the app, so devices never check that profile."
  - id: m41-l02-c2
    front: What does -allowProvisioningUpdates do, and what does a CI machine need to use it?
    back: "It lets xcodebuild talk to the Apple Developer website: for automatic signing it creates and updates certificates, App IDs and profiles; for manual signing it downloads missing profiles. On a CI machine with no Xcode account, pass an App Store Connect API key with -authenticationKeyPath, -authenticationKeyID and -authenticationKeyIssuerID."
  - id: m41-l02-c3
    front: What do the three -authenticationKey flags of xcodebuild take?
    back: "-authenticationKeyPath: the downloaded .p8 private key. -authenticationKeyID: the key's ID. -authenticationKeyIssuerID: your team's issuer ID. Both IDs are shown in App Store Connect's Users and Access."
  - id: m41-l02-c4
    front: Name the four security steps that make a .p12 usable by codesign on a CI runner.
    back: "security create-keychain (a new keychain with a random password), unlock-keychain, import the .p12 into it (-P password, -k keychain), and list-keychains -d user -s to put it in the search list. GitHub's guide also runs set-key-partition-list so tools can use the key without a prompt."
  - id: m41-l02-c5
    front: "A .p8 App Store Connect key or a .p12 leaked from CI. What do you do?"
    back: "Revoke the API key in App Store Connect immediately (Apple doesn't keep a copy and says to revoke a compromised key); for a .p12, revoke the distribution certificate in the developer account and create a new one. Then rotate the CI secrets and find how it leaked."
---

## The idea in one sentence

A release build is the same app signed with a **distribution** identity and an App Store profile instead of your development ones; doing that in CI means getting those credentials (or an App Store Connect key that can fetch them) onto a fresh Mac for one job, using them, and leaving nothing behind.

> [!note] Sources and what was checked
> Signing details come from TN3125 ("Inside Code Signing: Provisioning Profiles"), Apple's Xcode articles "Distributing your app for beta testing and releases" and "Sharing your team's signing certificates", and "Creating API Keys for App Store Connect API". The CI keychain recipe is GitHub's guide "Installing an Apple certificate on macOS runners for Xcode development"; the `security` options were checked against its man page, and `xcodebuild` options against the `xcodebuild` man page. All read in November 2026. No Mac was available, so nothing here was signed, archived or uploaded; the YAML was parsed but not run, and the ExportOptions keys are flagged where they come from `xcodebuild -help` rather than a page that was read. The Swift blocks are models, compiled and run with Swift 6.3.

## What changes for a distribution build

Module 21 explained certificates, private keys and the five things a provisioning profile ties together: who may sign, which App ID, which devices, until when, and which entitlements. A build you upload to App Store Connect differs in two places:

- **The identity is a distribution one.** Development certificates have common names starting with `Apple Development:`; distribution certificates start with `Apple Distribution:`. Same rule as before: the certificate is public, the private key is what signs, and anyone with an exported `.p12` and its password "can distribute signed software that appears to users and the operating system to come from your Apple Developer account."
- **The profile is an App Store distribution profile.** TN3125: "App Store distribution profiles have no `ProvisionedDevices` property because you can't run an App Store distribution signed app locally." When you upload, Apple checks the signing and provisioning and later re-signs the app, so the build customers download has no embedded profile.

Every target in the app needs its own match: the app, each extension (widget, notification service, share extension) and any embedded framework with its own bundle ID. Each extension has its own App ID and needs a profile that covers it.

Here's the check a profile has to pass, as a model. App IDs are the Team ID plus a bundle ID, or a wildcard ending in `.*`:

```swift
enum ProfileKind: String {
    case development, adHoc = "ad hoc", appStore = "App Store distribution"
}

struct Profile {
    let name: String
    let kind: ProfileKind
    let appID: String                  // "TEAMID.bundle.id" or "TEAMID.prefix.*"
    let certificates: Set<String>      // certificates allowed to sign
    let expiration: String             // ISO 8601 date, "2027-03-01"
    let entitlements: Set<String>
}

struct ReleaseBuild {
    let teamID: String
    let bundleID: String
    let signingCertificate: String
    let entitlements: Set<String>
    let date: String
}

func appIDMatches(_ appID: String, team: String, bundleID: String) -> Bool {
    let full = "\(team).\(bundleID)"
    if appID.hasSuffix(".*") {
        return full.hasPrefix(String(appID.dropLast()))
    }
    return appID == full
}

func problems(signing build: ReleaseBuild, with profile: Profile) -> [String] {
    var found: [String] = []
    if profile.kind != .appStore {
        found.append("\(profile.name) is a \(profile.kind.rawValue) profile")
    }
    if !appIDMatches(profile.appID, team: build.teamID, bundleID: build.bundleID) {
        found.append("App ID \(profile.appID) doesn't cover \(build.bundleID)")
    }
    if !profile.certificates.contains(build.signingCertificate) {
        found.append("certificate \(build.signingCertificate) isn't in the profile")
    }
    if profile.expiration <= build.date {
        found.append("profile expired on \(profile.expiration)")
    }
    for entitlement in build.entitlements.sorted() where !profile.entitlements.contains(entitlement) {
        found.append("entitlement \(entitlement) isn't allowed by the profile")
    }
    return found
}

let profile = Profile(
    name: "Weather App Store",
    kind: .appStore,
    appID: "SKMME9E2Y8.com.example.Weather",
    certificates: ["DIST-7F3A"],
    expiration: "2027-08-14",
    entitlements: ["aps-environment", "com.apple.security.application-groups"]
)

let release = ReleaseBuild(
    teamID: "SKMME9E2Y8",
    bundleID: "com.example.Weather",
    signingCertificate: "DIST-7F3A",
    entitlements: ["aps-environment"],
    date: "2026-11-04"
)
print(problems(signing: release, with: profile))

let widget = ReleaseBuild(
    teamID: "SKMME9E2Y8",
    bundleID: "com.example.Weather.Widget",
    signingCertificate: "DIST-91C2",
    entitlements: ["com.apple.developer.weatherkit", "com.apple.security.application-groups"],
    date: "2026-11-04"
)
for problem in problems(signing: widget, with: profile) {
    print("-", problem)
}
```

```output
[]
- App ID SKMME9E2Y8.com.example.Weather doesn't cover com.example.Weather.Widget
- certificate DIST-91C2 isn't in the profile
- entitlement com.apple.developer.weatherkit isn't allowed by the profile
```

The app passes. The widget fails three ways at once, which is typical: someone reused the app's profile for an extension, and the CI machine has a newer certificate than the one the profile was generated with. Xcode's real errors are less tidy, but they're about these same fields. ISO 8601 dates compare correctly as strings, which is why the model can use `<=`; the real profile stores an `ExpirationDate` that you can read with the commands TN3125 shows:

```bash
security cms -D -i Weather_App_Store.mobileprovision -o Weather-payload.plist
plutil -extract ExpirationDate raw -o - Weather-payload.plist
```

TN3125 also warns that "the exact format of provisioning profiles isn't documented and could change at any time," so use this for debugging, not to build tools on.

## Automatic or manual signing in CI

Module 21's `CODE_SIGN_STYLE` setting has two values, and both work in automation. The question is who creates and holds the credentials.

### Automatic signing with an App Store Connect API key

With automatic signing, Xcode creates and updates certificates, App IDs and profiles for you. Apple's distribution article says Xcode "uses cloud-managed signing certificates to automatically code sign your app," which means the distribution private key stays with Apple and nobody exports a `.p12`.

On a CI machine, nobody is signed in to Xcode. The `xcodebuild` man page gives you two options for that:

- `-allowProvisioningUpdates`: "Allow xcodebuild to communicate with the Apple Developer website. For automatically signed targets, xcodebuild will create and update profiles, app IDs, and certificates. For manually signed targets, xcodebuild will download missing or updated provisioning profiles. Requires a developer account to have been added in Xcode's Accounts preference pane."
- `-authenticationKeyPath`, `-authenticationKeyID` and `-authenticationKeyIssuerID`: "If specified, xcodebuild will authenticate with the Apple Developer website using this credential." The path is an App Store Connect API key; the IDs "can be located in the users and access details for your provider."

So the CI recipe is: create an **App Store Connect API key**, store the `.p8` file and the two IDs as secrets, and pass all three flags plus `-allowProvisioningUpdates`.

From Apple's page on creating API keys:

- There are **team keys** ("access to all apps, with varying levels of access based on selected roles") and **individual keys** (the access of one user; they "aren't able to use Provisioning endpoints"). For signing in CI you want a team key, created by an Admin, with the least powerful role that works for your pipeline.
- "The private key is available for download a single time." Apple doesn't keep a copy.
- "Don't share your keys, store keys in a code repository, or include keys in client-side code. If the key becomes lost or compromised, remember to revoke it immediately."

Which role a key needs for cloud signing wasn't checked for this lesson; check App Store Connect's role permissions and start from the narrowest role that lets the archive succeed.

### Manual signing with a certificate and profile

With manual signing, you create the distribution certificate and the App Store profile yourself (or with a tool), export the identity as a `.p12`, and give CI three secrets: the `.p12`, its password and the profile. The build settings name exactly what to use, ideally in a Release xcconfig per target so extensions get their own profile:

```plaintext
// Release.xcconfig for the app target
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = SKMME9E2Y8
CODE_SIGN_IDENTITY = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = Weather App Store
```

Passing these on the `xcodebuild` command line also works, but command-line settings apply to **every** target, so a widget would be told to use the app's profile; the model above shows how that ends.

| | Automatic + API key | Manual + .p12 and profile |
| --- | --- | --- |
| Secrets in CI | `.p8` key and two IDs | `.p12`, its password, every profile |
| Distribution private key | Stays cloud-managed | Exported; anyone with the file and password can sign as you |
| New extension or capability | Profiles update themselves | You regenerate profiles and update secrets |
| Reproducibility | Depends on Apple's service at build time | Exactly the credentials you installed |
| Typical fit | Small teams, Xcode Cloud-like simplicity | Large teams, strict change control, offline or unusual build systems |

Both are reasonable. What isn't reasonable is the setup many small teams start with: one developer's laptop with the only copy of the distribution key.

## The keychain on a CI runner

`codesign` finds identities in keychains on the keychain search list. A runner has no identity of yours, so a manual-signing job creates a keychain just for this run. This is GitHub's guide, with each command explained (options from the `security` man page):

```bash
# Paths in the job's temporary directory, which the runner cleans up.
CERTIFICATE_PATH=$RUNNER_TEMP/build_certificate.p12
PP_PATH=$RUNNER_TEMP/build_pp.mobileprovision
KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db

# The secrets are Base64 text; turn them back into files.
echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $CERTIFICATE_PATH
echo -n "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o $PP_PATH

# A new keychain with a random password, locked again after 6 hours (21600 s) or on sleep.
security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

# Import the identity, then let Apple's tools use the private key without a prompt.
security import $CERTIFICATE_PATH -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

# Make it the user's keychain search list, so codesign finds the identity.
security list-keychain -d user -s $KEYCHAIN_PATH

# Install the profile where Xcode looks for it.
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp $PP_PATH ~/Library/MobileDevice/Provisioning\ Profiles
```

Notes on the parts that look odd:

- **`-A`** on `import` means, in the man page's words, "Allow any application to access the imported key without warning (insecure, not recommended!)". On a disposable runner with a throwaway keychain there's no one to click a prompt, which is why the guide uses it. Don't copy it to a shared Mac.
- **`set-key-partition-list -S apple-tool:,apple:`** sets which partitions may use the key, so `codesign` and other Apple tools aren't blocked by an access prompt.
- **`-lut 21600`**: `-l` locks on sleep, `-u` locks after a timeout, `-t` gives it in seconds.
- **`list-keychain -d user -s`** *replaces* the user's search list with the new keychain. On a GitHub-hosted runner that's fine; on your own Mac it would hide your login keychain from that list.

GitHub's guide notes that hosted runners "are automatically destroyed at the end of the job," so the keychain goes with them. On **self-hosted** runners it doesn't, and the guide adds a cleanup step that runs even when the build fails:

```yaml
- name: Clean up keychain and provisioning profile
  if: ${{ always() }}
  run: |
    security delete-keychain $RUNNER_TEMP/app-signing.keychain-db
    rm ~/Library/MobileDevice/Provisioning\ Profiles/build_pp.mobileprovision
```

Secrets are stored as Base64 because GitHub secrets are text; `base64 -i BUILD_CERTIFICATE.p12 | pbcopy` on your Mac produces the value, as the guide shows. GitHub redacts secrets it knows about from logs, but a value you derive from one (a decoded file's contents, for example) isn't a secret to GitHub. Never `cat` a credential file "to check it."

## Archive, then export

Distribution is two `xcodebuild` steps. First **archive**: a Release build of the scheme for a generic device, with dSYMs, into an `.xcarchive`. Apple: "An archive is a build of your app, including debugging information, that Xcode stores in a bundle."

```bash
xcodebuild archive \
  -project Weather.xcodeproj \
  -scheme Weather \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$RUNNER_TEMP/Weather.xcarchive"
```

Then **export**. The man page: `-exportArchive` "Specifies that an archive should be distributed. Requires `-archivePath` and `-exportOptionsPlist`. For exporting, `-exportPath` is also required," and "the product can either be uploaded to Apple or exported locally."

```bash
xcodebuild -exportArchive \
  -archivePath "$RUNNER_TEMP/Weather.xcarchive" \
  -exportOptionsPlist ci/ExportOptions.plist \
  -exportPath "$RUNNER_TEMP/export" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

The **ExportOptions.plist** decides what kind of distribution this is. The man page doesn't list its keys; it says "`xcodebuild -help` can print the full set of available inputs." The keys below are the ones `xcodebuild -help` documents in recent Xcode versions as far as this lesson knows, but they weren't checked against Xcode 26 or 27 here. Run `xcodebuild -help` on your CI image and compare before you commit this file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>SKMME9E2Y8</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
```

- **`method`** is the distribution method: `app-store-connect` for TestFlight and the App Store (older Xcode versions called it `app-store`; current ones accept the old name with a deprecation warning, as far as this lesson knows).
- **`destination`**: `upload` sends the build to App Store Connect; `export` writes an `.ipa` to `-exportPath` for you to upload another way.
- **`signingStyle`** `manual` requires a `provisioningProfiles` dictionary mapping each bundle ID to a profile name.
- **`uploadSymbols`** sends the dSYMs so the Crashes organizer can symbolicate (lesson 4).
- **`manageAppVersionAndBuildNumber`** corresponds to Xcode's "Manage version and build number" distribution option. Apple's "Preparing your app for distribution" says that with it, "Xcode can update the build number when you upload." Turn it **off** in CI and set the build number yourself (lesson 3), so the number in your logs, tags and crash reports is the one that shipped.

A note on `destination: upload` with an API key: the man page still says uploading with `-exportArchive` needs an Apple account in Xcode's Accounts pane, while the `-authenticationKey` options are described as a credential for the Apple Developer website. Using the key for the upload is common practice, but it wasn't verified for this lesson. If it fails on your setup, export locally and upload the `.ipa` with one of the tools App Store Connect Help lists: Xcode, Transporter, `altool`, or the App Store Connect API.

## A release workflow

Putting lesson 1 and this lesson together: a workflow that runs **only on version tags**, uses automatic signing with an API key, and keeps the archive (with its dSYMs) as an artifact:

```yaml
name: Release · TestFlight

on:
  push:
    tags: ['v*']
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: release
  cancel-in-progress: false

jobs:
  upload:
    runs-on: macos-26
    timeout-minutes: 45
    environment: app-store
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.6.app
    steps:
      - uses: actions/checkout@v7

      - name: Write the App Store Connect key
        env:
          ASC_KEY_BASE64: ${{ secrets.ASC_KEY_BASE64 }}
        run: echo -n "$ASC_KEY_BASE64" | base64 --decode -o "$RUNNER_TEMP/AuthKey.p8"

      - name: Archive
        run: |
          xcodebuild archive \
            -project Weather.xcodeproj \
            -scheme Weather \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath "$RUNNER_TEMP/Weather.xcarchive" \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
            -authenticationKeyID "${{ secrets.ASC_KEY_ID }}" \
            -authenticationKeyIssuerID "${{ secrets.ASC_ISSUER_ID }}" \
            CURRENT_PROJECT_VERSION=${{ github.run_number }}

      - name: Upload to App Store Connect
        run: |
          xcodebuild -exportArchive \
            -archivePath "$RUNNER_TEMP/Weather.xcarchive" \
            -exportOptionsPlist ci/ExportOptions.plist \
            -exportPath "$RUNNER_TEMP/export" \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
            -authenticationKeyID "${{ secrets.ASC_KEY_ID }}" \
            -authenticationKeyIssuerID "${{ secrets.ASC_ISSUER_ID }}"

      - name: Keep the archive and its dSYMs
        uses: actions/upload-artifact@v7
        with:
          name: Weather-${{ github.ref_name }}-${{ github.run_number }}
          path: ${{ runner.temp }}/Weather.xcarchive
```

The decisions in it:

- **Tags, not pull requests.** Code reaches this workflow only after review and merge. Fork pull requests would never get the secrets anyway (lesson 1).
- **`environment: app-store`.** GitHub's docs: "Secrets stored in an environment are only available to workflow jobs that reference the environment. If the environment requires approval, a job cannot access environment secrets until one of the required reviewers approves it." Put the key there, not in repository secrets, and restrict the environment to `v*` tags with its deployment branch and tag rules. (Required reviewers on private repositories need a paid plan, per the same page.)
- **`cancel-in-progress: false`.** Cancelling a release halfway through an upload helps nobody; a second tag waits its turn.
- **`CURRENT_PROJECT_VERSION=${{ github.run_number }}`** sets the build number (`CFBundleVersion`, if the Info.plist uses the build setting, as Xcode's templates do). GitHub's contexts reference: `run_number` is "a unique number for each run of a particular workflow in a repository... This number does not change if you re-run the workflow run." That makes it a ready-made, increasing build number. Lesson 3 has the rules it must satisfy.
- **The archive is kept.** Module 21: "You must retain the Xcode archive for each build of your app you distribute." Artifacts expire too (90 days by default on GitHub, as far as this lesson knows; check your repository's setting), so a release process copies the archive to long-term storage.

## Common mistakes

> [!error] One extension, the app's profile
> Each target with a bundle ID needs a profile whose App ID covers it. Setting `PROVISIONING_PROFILE_SPECIFIER` on the command line pushes the app's profile onto every target. Put signing settings in per-target xcconfig files or use automatic signing.

> [!error] Signing on pull requests
> Pull request jobs don't need a distribution identity, and fork pull requests don't receive secrets. Sign only on tags, release branches or manual dispatch, behind an environment.

> [!error] Leaving the keychain on a self-hosted runner
> Hosted runners are destroyed; your own Mac isn't. Add the `if: always()` cleanup step that deletes the keychain and the profile.

> [!error] Printing a credential to debug it
> GitHub redacts registered secrets, not files decoded from them. Check a profile with `security cms -D` and `plutil -extract` for single fields, never by dumping a `.p12` or `.p8`.

> [!error] Treating a leaked key as "probably fine"
> Revoke an App Store Connect key immediately in App Store Connect; revoke a distribution certificate whose `.p12` leaked and issue a new one. Then rotate the secrets everywhere they were stored.

## Exercises

````exercise
id: m41-l02-e1
type: prediction
prompt: "What does this program print?"
code: |
  func appIDMatches(_ appID: String, team: String, bundleID: String) -> Bool {
      let full = "\(team).\(bundleID)"
      if appID.hasSuffix(".*") {
          return full.hasPrefix(String(appID.dropLast()))
      }
      return appID == full
  }

  let team = "SKMME9E2Y8"
  print(appIDMatches("SKMME9E2Y8.com.example.*", team: team, bundleID: "com.example.Weather"))
  print(appIDMatches("SKMME9E2Y8.com.example.*", team: team, bundleID: "com.example"))
  print(appIDMatches("SKMME9E2Y8.com.example.Weather", team: team, bundleID: "com.example.Weather.Widget"))
  print(appIDMatches("ZZ99ZZ99ZZ.com.example.*", team: team, bundleID: "com.example.Weather"))
  print("2027-01-31" <= "2026-11-04", "2026-11-04" <= "2026-11-04")
output: |
  true
  false
  false
  false
  false true
hints:
  - "dropLast() removes only the *, so the wildcard prefix still ends with a period."
  - "An explicit App ID must equal the team plus the bundle ID exactly."
solution: |
  ```output
  true
  false
  false
  false
  false true
  ```

  1. `SKMME9E2Y8.com.example.Weather` starts with `SKMME9E2Y8.com.example.`: covered.
  2. `SKMME9E2Y8.com.example` doesn't start with `SKMME9E2Y8.com.example.` (the trailing period): not covered. A wildcard covers names *below* the prefix, not the prefix itself.
  3. An explicit App ID covers exactly one bundle ID. The widget needs its own.
  4. The Team ID is part of the App ID; another team's profile never covers your app.
  5. ISO dates compare correctly as strings. `"2027-01-31" <= "2026-11-04"` is `false` (not expired yet); a profile whose expiration equals today counts as expired in the lesson's model (`<=`).
````

````exercise
id: m41-l02-e2
type: comprehension
multiple: true
prompt: "Which statements about App Store Connect API keys are true, according to Apple's documentation?"
choices:
  - text: "You can download the private key only once; Apple doesn't keep a copy."
    correct: true
    why: "Apple: the private key is available for download a single time."
  - text: "Individual keys can't use the Provisioning endpoints."
    correct: true
    why: "That's stated on the page. For signing in CI, use a team key."
  - text: "Committing the .p8 to a private repository is acceptable because the repository isn't public."
    correct: false
    why: "Apple says not to store keys in a code repository, private or not."
  - text: "If a key is compromised, revoke it immediately in App Store Connect."
    correct: true
    why: "Apple says so explicitly."
  - text: "An App Store Connect API key can be used to sign in to other Apple services."
    correct: false
    why: "Apple: these keys are unique to the App Store Connect API and can't be used for other Apple services."
solution: |
  **True: one-time download, individual keys can't provision, revoke when compromised.**

  Store the `.p8` as a CI secret (in an environment, if you use GitHub environments), never in the repository. Apple's wording: "Don't share your keys, store keys in a code repository, or include keys in client-side code." The key ID and issuer ID aren't secret in the same way, but storing them next to the key keeps the configuration in one place. For `xcodebuild` the key authenticates with the Apple Developer website; it isn't an Apple Account password and doesn't work for other services.
````

````exercise
id: m41-l02-e3
type: fill-in
prompt: "Complete the commands that make a .p12 usable by codesign on a GitHub-hosted runner."
code: |
  security [[1]] -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security [[2]] $CERTIFICATE_PATH -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
  security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security list-keychain -d user [[3]] $KEYCHAIN_PATH
blanks:
  - id: "1"
    answers: ["create-keychain"]
  - id: "2"
    answers: ["import"]
  - id: "3"
    answers: ["-s"]
solution: |
  ```bash
  security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security import $CERTIFICATE_PATH -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
  security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
  security list-keychain -d user -s $KEYCHAIN_PATH
  ```

  `create-keychain` makes a new keychain with a password that only this job knows (a random secret). `import` brings in the identity: `-P` is the `.p12` password, `-f pkcs12` the format, `-k` the target keychain. `list-keychain -d user -s` sets the user's search list so `codesign` finds the identity. On a self-hosted runner, finish with `security delete-keychain` in an `if: always()` step.
````

````exercise
id: m41-l02-e4
type: find-errors
prompt: "A release workflow someone proposes. Mark every real problem."
code: |
  on:
    pull_request:
    push:
      branches: [main]
  jobs:
    release:
      runs-on: macos-latest
      steps:
        - uses: actions/checkout@v7
        - run: echo "$ASC_KEY_BASE64" | base64 --decode -o AuthKey.p8 && cat AuthKey.p8
          env:
            ASC_KEY_BASE64: ${{ secrets.ASC_KEY_BASE64 }}
        - run: |
            xcodebuild archive -scheme Weather -archivePath Weather.xcarchive \
              -destination 'generic/platform=iOS' \
              PROVISIONING_PROFILE_SPECIFIER="Weather App Store" CODE_SIGN_STYLE=Manual
        - run: xcodebuild -exportArchive -archivePath Weather.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath out
choices:
  - text: "It runs on pull_request, so unreviewed code would be signed and uploaded (and fork PRs would fail without secrets)."
    correct: true
  - text: "cat AuthKey.p8 prints the private key into the log; GitHub only redacts the registered Base64 secret, not the decoded file."
    correct: true
  - text: "The key file is written into the checkout instead of $RUNNER_TEMP."
    correct: true
  - text: "Setting PROVISIONING_PROFILE_SPECIFIER on the command line applies the app's profile to every target, including extensions."
    correct: true
  - text: "macos-latest can change Xcode under a release pipeline; pin the image and the Xcode."
    correct: true
  - text: "The export step has no credentials, so if it uploads, it can't authenticate."
    correct: true
  - text: "xcodebuild archive needs -exportPath."
    correct: false
    why: "-exportPath belongs to -exportArchive. archive needs -archivePath."
rubric:
  - I flagged the pull_request trigger.
  - I flagged printing the key and writing it into the workspace.
  - I flagged command-line signing settings that hit every target.
  - I flagged the unpinned runner and the export step without credentials.
solution: |
  Six problems:

  1. **Triggered on `pull_request`.** Release jobs run on tags or a manual dispatch, after review, in an environment that holds the secrets.
  2. **`cat AuthKey.p8`.** GitHub masks the secret's registered value; the decoded key is different text and lands in the log in full. Revoke the key if this ever ran.
  3. **`AuthKey.p8` in the workspace.** Write it to `$RUNNER_TEMP`, so it's outside the checkout and cleaned up, and can't be swept into an artifact or cache by accident.
  4. **Command-line `PROVISIONING_PROFILE_SPECIFIER`** applies to all targets; the widget and other extensions get the wrong profile. Use per-target xcconfig files or automatic signing.
  5. **`macos-latest`**: pin `macos-26` and an Xcode with `DEVELOPER_DIR`.
  6. **The export step** passes neither `-allowProvisioningUpdates` nor the `-authenticationKey` flags, and nobody is signed in to Xcode on the runner.

  `-exportPath` is only for `-exportArchive`; the archive step is right to leave it out.
````

````exercise
id: m41-l02-e5
type: solve
prompt: |
  Write `chooseProfile(for:team:today:from:)`. Among the profiles that are App Store profiles, not expired (expiration strictly after `today`) and whose App ID covers the bundle ID, prefer an explicit App ID over a wildcard; among equals, prefer the one that expires latest. Return its name, or `"no usable profile"`.

  ```swift
  let profiles = [
      Profile(name: "Team Wildcard", isAppStore: true, appID: "SKMME9E2Y8.*", expiration: "2027-09-01"),
      Profile(name: "Weather Dev", isAppStore: false, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2027-05-01"),
      Profile(name: "Weather 2026", isAppStore: true, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2026-10-01"),
      Profile(name: "Weather 2027", isAppStore: true, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2027-06-15"),
  ]
  let team = "SKMME9E2Y8"
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2026-11-04", from: profiles))
  print(chooseProfile(for: "com.example.Weather.Widget", team: team, today: "2026-11-04", from: profiles))
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2027-07-01", from: profiles))
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2027-10-01", from: profiles))
  ```

  Expected output:

  ```output
  Weather 2027
  Team Wildcard
  Team Wildcard
  no usable profile
  ```
starter: |
  struct Profile {
      let name: String
      let isAppStore: Bool
      let appID: String
      let expiration: String
  }

  func appIDMatches(_ appID: String, team: String, bundleID: String) -> Bool {
      let full = "\(team).\(bundleID)"
      if appID.hasSuffix(".*") {
          return full.hasPrefix(String(appID.dropLast()))
      }
      return appID == full
  }

  func chooseProfile(for bundleID: String, team: String, today: String, from profiles: [Profile]) -> String {
      // your code
      return "no usable profile"
  }
hints:
  - "Filter first: App Store, expiration > today, App ID matches."
  - "Keep a best-so-far. A candidate replaces it if it's explicit and the best is a wildcard, or if both are the same kind and it expires later."
rubric:
  - Skips development profiles, expired profiles and profiles whose App ID doesn't cover the bundle ID.
  - Prefers explicit App IDs over wildcards.
  - Among the same kind, picks the latest expiration.
  - Prints the four expected lines.
solution: |
  ```swift
  struct Profile {
      let name: String
      let isAppStore: Bool
      let appID: String
      let expiration: String
  }

  func appIDMatches(_ appID: String, team: String, bundleID: String) -> Bool {
      let full = "\(team).\(bundleID)"
      if appID.hasSuffix(".*") {
          return full.hasPrefix(String(appID.dropLast()))
      }
      return appID == full
  }

  func chooseProfile(for bundleID: String, team: String, today: String, from profiles: [Profile]) -> String {
      var best: Profile? = nil
      for profile in profiles {
          guard profile.isAppStore,
                profile.expiration > today,
                appIDMatches(profile.appID, team: team, bundleID: bundleID) else { continue }
          guard let current = best else {
              best = profile
              continue
          }
          let explicit = !profile.appID.hasSuffix(".*")
          let currentExplicit = !current.appID.hasSuffix(".*")
          if explicit && !currentExplicit {
              best = profile
          } else if explicit == currentExplicit && profile.expiration > current.expiration {
              best = profile
          }
      }
      return best?.name ?? "no usable profile"
  }

  let profiles = [
      Profile(name: "Team Wildcard", isAppStore: true, appID: "SKMME9E2Y8.*", expiration: "2027-09-01"),
      Profile(name: "Weather Dev", isAppStore: false, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2027-05-01"),
      Profile(name: "Weather 2026", isAppStore: true, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2026-10-01"),
      Profile(name: "Weather 2027", isAppStore: true, appID: "SKMME9E2Y8.com.example.Weather", expiration: "2027-06-15"),
  ]
  let team = "SKMME9E2Y8"
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2026-11-04", from: profiles))
  print(chooseProfile(for: "com.example.Weather.Widget", team: team, today: "2026-11-04", from: profiles))
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2027-07-01", from: profiles))
  print(chooseProfile(for: "com.example.Weather", team: team, today: "2027-10-01", from: profiles))
  ```

  ```output
  Weather 2027
  Team Wildcard
  Team Wildcard
  no usable profile
  ```

  1. "Weather Dev" isn't an App Store profile and "Weather 2026" has expired; "Weather 2027" (explicit) beats the wildcard.
  2. Only the wildcard covers the widget.
  3. On 2027-07-01 "Weather 2027" has expired, so the wildcard is all that's left. A release that suddenly picks a wildcard profile is a sign someone forgot to renew, and the wildcard won't carry the app's entitlements.
  4. Everything has expired.

  This is roughly the decision Xcode makes with automatic signing, and the reason manual signing needs a calendar reminder: profiles typically last no more than a year (TN3125).
````

````exercise
id: m41-l02-e6
type: explain
prompt: "Your team signs releases manually from CI with a `.p12` and three profiles (app, widget, notification service) stored as secrets. A teammate proposes switching to automatic signing with an App Store Connect API key. Explain what changes, what gets better, what could get worse, and what you'd check before switching."
code: |
  # Today, in release.yml
  - name: Install signing identity and profiles
    run: ./ci/install-signing.sh   # .p12 + 3 profiles from secrets into a temp keychain
  - name: Archive
    run: xcodebuild archive -scheme Weather -configuration Release -destination 'generic/platform=iOS' -archivePath "$RUNNER_TEMP/Weather.xcarchive"

  # Proposed
  - name: Archive
    run: |
      xcodebuild archive -scheme Weather -configuration Release -destination 'generic/platform=iOS' \
        -archivePath "$RUNNER_TEMP/Weather.xcarchive" -allowProvisioningUpdates \
        -authenticationKeyPath "$RUNNER_TEMP/AuthKey.p8" \
        -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
rubric:
  - Explains that automatic signing uses cloud-managed certificates and lets xcodebuild create and update profiles with -allowProvisioningUpdates and the API key flags.
  - Names the gains, such as no exported private key, no profiles to regenerate for new extensions or capabilities, and fewer secrets.
  - Names the risks, such as dependence on Apple's service at build time, a key whose role may be broader than needed, and less control over exactly which profile is used.
  - Lists checks, such as the key type (team) and role, environment-scoped secrets, a dry run on a branch, and revoking the old certificate afterward.
solution: |
  **What changes.** `CODE_SIGN_STYLE` becomes `Automatic` for all three targets. CI stops importing a `.p12` and copying profiles; instead it writes the `.p8` to `$RUNNER_TEMP` and passes `-allowProvisioningUpdates` plus `-authenticationKeyPath/-ID/-IssuerID` to `archive` and `-exportArchive`. The man page: for automatically signed targets, `xcodebuild` "will create and update profiles, app IDs, and certificates." Apple's distribution article says Xcode uses cloud-managed certificates, so no distribution private key needs to be exported.

  **Better.** No `.p12` that "can distribute signed software that appears... to come from your Apple Developer account" sitting in secrets. Adding a fourth extension or a capability no longer means regenerating profiles and updating secrets by hand. Fewer secrets: one key and two IDs.

  **Possibly worse.** The build depends on Apple's developer services being reachable at build time. The key's role may be broader than the old setup's power (a team key can access all apps). You see less of exactly which profile was used, which matters to teams with strict change control.

  **Before switching.** Create a team key with the narrowest role that works and store it in an environment limited to release tags. Run the new workflow on a branch with `workflow_dispatch` and upload to TestFlight internal testing only. Compare the entitlements of the new build with the old one (`codesign -d --entitlements` on a Mac). Once it's proven, revoke the old distribution certificate and delete the `.p12` and profile secrets, so there aren't two ways to sign.
````

## Summary

- A distribution build is signed with an `Apple Distribution` identity and an App Store distribution profile that lists no devices. Every target with a bundle ID needs a profile that covers it, with its entitlements.
- Automatic signing in CI uses an App Store Connect API key with `-allowProvisioningUpdates` and the three `-authenticationKey` flags; manual signing installs a `.p12` and profiles from secrets and names them in per-target build settings.
- On a runner, create a temporary keychain, unlock it, import the identity, set the partition list and search list, install the profile, and delete it all on self-hosted machines with an `if: always()` step.
- `xcodebuild archive` makes an `.xcarchive` with dSYMs; `xcodebuild -exportArchive` with an ExportOptions.plist uploads it or exports an `.ipa`. Check the plist keys against `xcodebuild -help` on your Xcode.
- Release jobs run on tags or manual dispatch, read secrets from a protected environment, never print credentials, set the build number explicitly and keep the archive.
