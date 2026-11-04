---
id: m41-l05
title: TestFlight and App Store Connect
description: "Take an uploaded build from processing to testers to App Review. You learn what happens after an upload, the differences between internal and external TestFlight testing and when TestFlight App Review applies, how long builds last, which metadata, screenshots and privacy answers a version needs, what App Review needs from you, and the release options once a version is approved. All limits are quoted from App Store Connect Help."
module: m41
order: 5
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m41-l04]
objectives:
  - Follow a build through upload, processing and its TestFlight statuses, and fix Missing Compliance at the source.
  - Choose internal or external TestFlight testing and know the limits and review rules of each.
  - Prepare the version metadata App Store Connect requires, within its documented limits.
  - Provide App Privacy answers, a privacy policy and App Review information, including a demo account.
  - Submit a version for review and pick a release option.
terms:
  - term: App Store Connect
    definition: "Apple's web tool (and API) for managing apps: app records, builds, TestFlight, metadata, pricing, privacy answers, submissions to App Review and releases."
  - term: Build processing
    definition: "What App Store Connect does after an upload before the build appears: checks and preparation. You get an email when it's done; a build stuck in Processing for more than 24 hours may have an issue."
  - term: Internal tester
    definition: "An App Store Connect user on your team (up to 100) who tests builds through TestFlight. Internal testing doesn't need TestFlight App Review."
  - term: External tester
    definition: "Anyone you invite by email or public link (up to 10,000 per app) who isn't an App Store Connect user. Builds for external testing go through TestFlight App Review."
  - term: TestFlight App Review
    definition: "Apple's review of a beta build for external testing. The first build requires a full review; later builds of the same version might not."
  - term: Export compliance
    definition: "Your declaration about the app's use of encryption, for U.S. export rules. The ITSAppUsesNonExemptEncryption Info.plist key answers it for every upload."
mastery:
  - Read a build's status and say what, if anything, you must do next.
  - Set up an internal group with automatic distribution and an external group with a public link and criteria.
  - Check metadata against App Store Connect's limits, including the 100-byte keyword field.
  - List what App Review needs to test an app with sign-in, and write useful review notes.
  - Pick manual, automatic or scheduled release and combine it with phased release.
resources: [asc-testflight-overview, app-privacy-details, app-review-guidelines, information-property-list, privacy-manifest-files]
cards:
  - id: m41-l05-c1
    front: Internal vs external TestFlight testers?
    back: "Internal: up to 100 App Store Connect users on your team; builds available without beta review. External: up to 10,000 people per app, invited by email or public link; builds need TestFlight App Review (full review for the first build of a version). An external group requires an internal group first."
  - id: m41-l05-c2
    front: How long can a TestFlight build be tested?
    back: "90 days from upload. After that it's Expired. You can also expire it yourself; otherwise testers keep access even after that version goes live on the App Store."
  - id: m41-l05-c3
    front: How do you stop every upload from showing Missing Compliance?
    back: "Set ITSAppUsesNonExemptEncryption in the Info.plist: NO if the app (with its libraries) uses no encryption or only exempt encryption; YES plus ITSEncryptionExportComplianceCode if it uses non-exempt encryption and Apple approved your documentation."
  - id: m41-l05-c4
    front: Which screenshots are required for an iOS app?
    back: "At least one for iPhone with Dynamic Island (medium display) and, if the app runs on iPad, at least one for the iPad 13-inch display; up to 10 per device size, JPEG or PNG, no transparency. App Store Connect scales the largest required ones down for smaller sizes."
  - id: m41-l05-c5
    front: The keyword field is limited to 100 what?
    back: "Bytes, not characters. Accented letters take 2 bytes in UTF-8 and CJK characters 3, so 98 characters can be over the limit. Each keyword must be longer than two characters, and the app and company names are already searchable."
---

## The idea in one sentence

App Store Connect is where an uploaded build becomes a TestFlight beta and then an App Store version, and almost every delay in that path is one of a small number of documented requirements (export compliance, beta review, metadata limits, privacy answers, review access) that you can satisfy before you're asked.

> [!note] Sources and what was checked
> Everything about App Store Connect here comes from App Store Connect Help, read in November 2026: "Upload builds", "Build upload statuses", "App build statuses", "TestFlight overview", "Add internal testers", "Invite external testers", "Provide test information", "Stop testing a build", "Provide export compliance information for beta builds", "Platform version information", "Screenshot specifications", "Manage app privacy", "Choose a build to submit", "Overview of submitting for review", "Submit an app" and "Select an App Store version release option". Also the App Review Guidelines and the `ITSAppUsesNonExemptEncryption` reference. App Store Connect's screens weren't opened for this lesson; where steps are described, they're Apple's, and buttons may be named differently by the time you read this. The Swift blocks are models of the documented rules, compiled and run with Swift 6.3.

## After the upload

Lesson 2 ended with `xcodebuild -exportArchive` uploading a build. App Store Connect Help ("Upload builds"):

- "Each time you upload a build, the bundle ID and version number, which are located in the app bundle, are used to associate the build with the app and version record in App Store Connect. The build string is used to uniquely identify the build throughout the system."
- "The build needs to be processed in Apple's system before it appears in App Store Connect. You'll receive an email when this process is complete."
- Supported tools for iOS apps: build with **Xcode 26 or later**, upload with Xcode 14 or later, or with Transporter or `altool` ("Upload for all target types is supported for Transporter and altool"), or through the App Store Connect API.

"Build upload statuses" gives the three states of an upload: **Processing**, **Failed** ("Ensure to resolve all errors prior to re-uploading your build," and "you can reuse the same build number for your next upload"), and **Complete**. "If you upload a build and it remains in the Processing state for more than 24 hours, there may be an issue."

Once processed, the build has a **build status** in the TestFlight tab. The ones you'll see most ("App build statuses"):

| Status | Meaning | What you do |
| --- | --- | --- |
| Missing Compliance | "Your build is missing export compliance documentation." | Answer the questions, or fix the Info.plist (below) |
| Ready to Submit | Can go to internal testers, or be submitted for TestFlight App Review or App Review | Add it to groups |
| Waiting for Review / In Beta Review | With TestFlight App Review | Wait |
| Ready to Test | Approved; no testers added yet | Add testers or notify them |
| Testing | "Being tested by at least one group or tester" | Read feedback and crashes |
| Rejected | "Rejected by TestFlight App Review and can no longer be used in TestFlight" | Fix and upload a new build |
| Expired | "Passed its 90-day availability window" | Upload a newer build |
| Invalid Binary | "Didn't meet all the upload requirements" | Fix and redeliver |

### Missing Compliance, fixed once

Every build starts as Missing Compliance unless the app says how it uses encryption. The `ITSAppUsesNonExemptEncryption` reference: set it to `NO` to say your app "including any third-party libraries you link against, either uses no encryption, or only uses encryption that's exempt from export compliance requirements," or `YES` if it uses non-exempt encryption, typically with an `ITSEncryptionExportComplianceCode` that Apple gives you after reviewing your documentation. Without the key, "App Store Connect walks you through an export compliance questionnaire every time you upload."

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Which value is right for your app is a legal question about the encryption it uses (HTTPS through Apple's APIs is the usual case, but don't take this lesson's word for your app). Apple's "Complying with encryption export regulations" is the reference; get the answer right once, put it in the Info.plist, and CI builds stop waiting for someone to click through a questionnaire.

## TestFlight

TestFlight "lets you distribute beta builds of your app, manage beta testers, and collect feedback." Testers install the TestFlight app and accept an email invitation or a public link.

| | Internal testing | External testing |
| --- | --- | --- |
| Who | "Up to 100 App Store Connect users with access to your content" | "Up to 10,000 external testers per app," who "aren't App Store Connect users" |
| Invitation | Pick team members by role | Email, CSV import or a public link |
| Review | No TestFlight App Review | "When you add the first build of your app to a group, the build gets sent to App Review ... A review is required only for the first build. Subsequent builds may not require a full review." |
| Builds | Automatic distribution available | You add builds and submit them for review |
| Prerequisite | None | "To create an external group ... you must first create an internal group" |

Details from "Add internal testers" and "Invite external testers" that change how you plan:

- **Automatic distribution** for internal groups delivers every build uploaded from Xcode to the group. Builds created by Xcode Cloud must be added to groups manually.
- **TestFlight Internal Only** builds (an Xcode and Xcode Cloud upload option) are marked as internal and "can only be added to internal tester groups"; they can't go to external testers or customers.
- **External review limits.** "You can only have one build of each version in review at a time," and "you can submit up to six builds for TestFlight App Review within a 24-hour period."
- **Test information** is required for external testing: a beta app description and a feedback email, entered under Test Information. Each build also gets **What to Test** text, which testers see.
- **Public links** can be limited to a number of testers (1 to 10,000) and filtered by device and OS version. Testers who join through a link show as anonymous, with their installs, sessions and crashes still visible. "Anyone can share this link."
- **Feedback.** Testers on recent TestFlight versions can send screenshots with comments from inside your app; you read them in App Store Connect's TestFlight Feedback section and in Xcode's Organizer. Their crashes go to the Crashes organizer automatically (lesson 4).

The App Review Guidelines add one rule (2.2): "Demos, betas, and trial versions of your app don't belong on the App Store – use TestFlight instead. Any app submitted for beta distribution via TestFlight should be intended for public distribution and should comply with the App Review Guidelines." TestFlight is for testing an app headed to the store, not a way around review, and testers can't be paid "in exchange for compensation of any kind."

### How long a build lasts

"You can test a build for up to 90 days." After that it's Expired. When you're done with a build, "you have the option to expire a build to stop testing it. If you don't expire your build and submit it to the App Store, testers who received an invitation to test will still be able to test your build even after it goes live on the App Store."

That last sentence matters for incident response (lesson 6): a TestFlight build with a known data-loss bug stays installable for testers until you expire it, even after the fix ships.

## The version page: metadata

Everything customers see about a version is metadata, and Guideline 2.3 requires it to "accurately reflect the app's core experience." The limits from App Store Connect Help's "Platform version information" and the guidelines:

| Field | Limit and rules |
| --- | --- |
| App name | 30 characters (Guideline 2.3.7) |
| Promotional text | 170 characters; can change "without requiring an updated submission" |
| Description | Up to 4000 characters, plain text, required |
| Keywords | "Up to 100 bytes," each keyword "greater than two characters"; don't repeat the app or company name, and "names of other apps or companies aren't allowed" |
| Support URL | Required, "including the protocol"; must lead to real contact information |
| What's New | Up to 4000 characters; "required for all subsequent versions" (not the first) |
| Copyright | Required, "preceded by the year the rights were obtained" |

The keyword limit is in **bytes**, which is a trap for any language with accents:

```swift
struct VersionMetadata {
    let appName: String
    let promotionalText: String
    let description: String
    let keywords: String          // comma-separated
    let whatsNew: String
    let supportURL: String
    let isFirstVersion: Bool
}

func problems(in m: VersionMetadata) -> [String] {
    var found: [String] = []
    if m.appName.count > 30 {
        found.append("app name is \(m.appName.count) characters; the limit is 30")
    }
    if m.promotionalText.count > 170 {
        found.append("promotional text is \(m.promotionalText.count) characters; the limit is 170")
    }
    if m.description.isEmpty || m.description.count > 4000 {
        found.append("description must be 1 to 4000 characters")
    }
    let keywordBytes = m.keywords.utf8.count
    if keywordBytes > 100 {
        found.append("keywords are \(keywordBytes) bytes; the limit is 100")
    }
    let nameWords = Set(m.appName.lowercased().split(separator: " ").map(String.init))
    for keyword in m.keywords.split(separator: ",").map({ $0.trimmingPrefixSpaces() }) {
        if keyword.count <= 2 {
            found.append("keyword \"\(keyword)\" must be longer than two characters")
        }
        if nameWords.contains(keyword.lowercased()) {
            found.append("keyword \"\(keyword)\" repeats the app name")
        }
    }
    if !m.isFirstVersion && m.whatsNew.isEmpty {
        found.append("What's New is required for every version after the first")
    }
    if !(m.supportURL.hasPrefix("https://") || m.supportURL.hasPrefix("http://")) {
        found.append("support URL must include the protocol")
    }
    return found
}

extension Substring {
    func trimmingPrefixSpaces() -> String { String(drop(while: { $0 == " " })) }
}

let update = VersionMetadata(
    appName: "Weather Radar",
    promotionalText: "Severe weather alerts are here.",
    description: "Hourly forecasts, radar and alerts for where you are.",
    keywords: "forecast,radar,rain,storm,uv,météo,prévisions,pluie,orage,temperature,wind,humidity,sunrise,éclair",
    whatsNew: "",
    supportURL: "support.example.com",
    isFirstVersion: false
)
for problem in problems(in: update) {
    print("-", problem)
}
print("keywords:", update.keywords.count, "characters,", update.keywords.utf8.count, "bytes")
```

```output
- keywords are 102 bytes; the limit is 100
- keyword "radar" repeats the app name
- keyword "uv" must be longer than two characters
- What's New is required for every version after the first
- support URL must include the protocol
keywords: 98 characters, 102 bytes
```

98 characters fit in 100, but each `é` is two bytes in UTF-8, so the field is over. `String.count` counts characters; `utf8.count` counts what the limit measures. The "radar" keyword wastes bytes, since the app name is already searchable. Running a check like this in CI, against metadata kept in the repository, catches these before someone finds them in a web form at release time. (Tools that manage App Store metadata as files through the App Store Connect API exist; none were evaluated here.)

### Screenshots

From "Screenshot specifications":

- "You must include at least one screenshot and can upload up to 10 screenshots per device size in .jpeg, .jpg, or .png formats."
- Required sizes for an iOS app: "iPhone: At least one screenshot for iPhone with Dynamic Island (medium display)" and, if the app supports iPadOS, "At least one screenshot for iPad 13-inch display."
- "If your app's user interface is consistent across multiple device sizes and localizations, you only need to provide screenshots for the highest required resolution. App Store Connect automatically scales them down."
- "Images can't include alpha channels or transparencies."

The pixel dimensions for each size class are in Apple's table and change as devices do; take them from the page, not from memory. Guideline 2.3.3: "Screenshots should show the app in use, and not merely the title art, login page, or splash screen." UI tests (Module 33) that navigate to each screen with fixed data are a good way to produce screenshots reproducibly for every size and language.

### App Privacy and the privacy policy

Lesson 4 covered what to declare. Where it goes: the App Privacy section of the app (not the version) holds the data-collection answers, which you **publish**; "Your responses will be published on your product page." A **privacy policy URL** "is required for all apps," and Guideline 5.1.1(i) adds that the app must also link to it "within the app in an easily accessible manner."

## App Review information

Each version has an App Review Information section that customers never see ("Platform version information"):

- **Contact**: name, email and phone number "in international format," for when the reviewer needs you.
- **Notes**: "Include information that may be needed to test your app, such as app-specific settings and test registration or account details." Up to 4000 bytes.
- **Sign-in required**: a demo account's username and password. "The demo account is used during the App Review process and must not expire."

The guidelines repeat it from the other side. "Before You Submit" asks you to "provide App Review with full access to your app," with "either an active demo account or fully-featured demo mode," and to "enable backend services so that they're live and accessible during review." Guideline 2.1(a) says the reviewer will reject "binaries that crash or exhibit obvious technical problems," and Apple's App Review page says that, on average, "over 40% of unresolved issues are related to guideline 2.1: App Completeness."

Good review notes are short and concrete: the demo account and what's in it, how to reach each new feature (lesson 3: flagged features must be accessible), anything that needs hardware or a location, and what the in-app purchases unlock.

## Submitting and releasing

To submit ("Choose a build to submit", "Submit an app"):

1. **Choose the build** for the version. "You can only associate one build with each app version," and you can change it until you submit.
2. **Add for Review**, which puts the version in a draft submission, optionally with other items (in-app events, in-app purchases, custom product pages).
3. **Submit for Review.** The status becomes Waiting for Review and then In Review. "Each platform can have one app version submission under review at a time."

Apple's App Review page says it typically reviews "at least 50% of submissions in less than 24 hours and 90% in less than 48 hours." Plan as if it could take longer.

Before approval you pick a **release option** ("Select an App Store version release option"):

- **Manually release this version.** After approval the status is Pending Developer Release until you click release. Useful when marketing or the backend must go first. "Apple will send you an email reminder if an app remains in Pending Developer Release status for more than 30 days."
- **Automatically release this version** right after approval.
- **Automatically release after App Review, no earlier than** a date and time.

Then, for updates, **phased release** (lesson 3) spreads automatic updates over 7 days. After you release, "it may take up to 24 hours for it to appear on the App Store."

If you find a problem while the version is waiting or in review, you can **remove it from review** ("Remove a submission from review"): its status becomes Developer Rejected, and "if you resubmit the review process will start over."

## Common mistakes

> [!error] Leaving export compliance to the web form
> Every build waits as Missing Compliance until someone answers. Put `ITSAppUsesNonExemptEncryption` in the Info.plist with the correct value.

> [!error] Counting keyword characters instead of bytes
> The field is 100 bytes; accented and non-Latin characters take two or more. Check `utf8.count`, and don't spend bytes on words already in the app name.

> [!error] A demo account that expires or a backend that's off
> App Review needs full access, a demo account that "must not expire," and live services. A reviewer who can't sign in rejects under 2.1.

> [!error] Treating TestFlight as private distribution forever
> Builds expire after 90 days, external builds need review, and Guideline 2.2 says TestFlight apps should be intended for public distribution. For an internal company tool, look at Apple's business distribution options instead.

> [!error] Forgetting to expire a bad beta
> Testers can keep installing a TestFlight build until it expires or you expire it, even after the fixed version is live. Expire builds with serious bugs.

## Exercises

````exercise
id: m41-l05-e1
type: prediction
prompt: "What does this program print? (Each line: the keyword, its character count, its UTF-8 byte count, and whether it's longer than two characters.)"
code: |
  let keywords = ["météo", "radar", "uv", "天気"]
  for keyword in keywords {
      print(keyword, keyword.count, keyword.utf8.count, keyword.count > 2)
  }
  let joined = keywords.joined(separator: ",")
  print(joined.count, joined.utf8.count)
output: |
  météo 5 7 true
  radar 5 5 true
  uv 2 2 false
  天気 2 6 false
  17 23
hints:
  - "é is one Character but two UTF-8 bytes."
  - "Common CJK characters are three UTF-8 bytes each."
  - "The joined string has three commas."
solution: |
  ```output
  météo 5 7 true
  radar 5 5 true
  uv 2 2 false
  天気 2 6 false
  17 23
  ```

  `météo` has two `é`, each two bytes: 5 characters, 7 bytes. `天気` is 2 characters and 6 bytes. Joined with three commas: 5 + 5 + 2 + 2 + 3 = 17 characters and 7 + 5 + 2 + 6 + 3 = 23 bytes.

  App Store Connect limits keywords to 100 **bytes**, so a Japanese or French keyword list fills up faster than its character count suggests. The "greater than two characters" rule applied literally would reject `天気`; how App Store Connect treats short CJK keywords wasn't checked for this lesson, so test it with your localized metadata rather than assuming.
````

````exercise
id: m41-l05-e2
type: comprehension
prompt: "You want 300 people from your beta mailing list to try build 2.6.0 (7351) this week. None of them are App Store Connect users. What's the documented path?"
choices:
  - text: "Create an internal group, then an external group; add the build to the external group, fill in Test Information, submit it to TestFlight App Review, and invite the testers by email, CSV or a public link."
    correct: true
    why: "External testing needs an internal group first, test information, and TestFlight App Review for the first build of a version."
  - text: "Add them as internal testers; internal builds don't need review."
    correct: false
    why: "Internal testers must be App Store Connect users on your team, and there's a limit of 100."
  - text: "Upload the build with the TestFlight Internal Only option and share a public link."
    correct: false
    why: "Internal Only builds can only be added to internal groups."
  - text: "Submit the build to App Review for the App Store and release it manually to those 300 people."
    correct: false
    why: "There's no way to release an App Store version to a list of people; that's what TestFlight is for (Guideline 2.2)."
solution: |
  **Internal group, then an external group with the build, test information, TestFlight App Review, invitations.** From App Store Connect Help: external testers are people "who aren't App Store Connect users," up to 10,000 per app; "to create an external group ... you must first create an internal group"; external builds need TestFlight App Review, with a full review for the first build. Fill in the beta app description and feedback email under Test Information, and What to Test for the build.

  Plan for the review: only one build per version can be in review at a time, and you can submit at most six builds for TestFlight App Review in 24 hours.
````

````exercise
id: m41-l05-e3
type: fill-in
prompt: "Complete the facts from App Store Connect Help."
code: |
  Internal testers: up to [[1]] App Store Connect users.
  External testers: up to [[2]] per app.
  A TestFlight build can be tested for up to [[3]] days.
  Promotional text: up to [[4]] characters.
blanks:
  - id: "1"
    answers: ["100"]
  - id: "2"
    answers: ["10,000", "10000"]
  - id: "3"
    answers: ["90"]
  - id: "4"
    answers: ["170"]
solution: |
  - Internal: "up to 100 App Store Connect users with access to your content."
  - External: "up to 10,000 external testers per app."
  - "You can test a build for up to 90 days"; then its status is Expired.
  - Promotional text "can't be longer than 170 characters," and unlike the description it can be changed without a new submission.
````

````exercise
id: m41-l05-e4
type: find-errors
prompt: "A release checklist a teammate wrote for the first App Store submission of a banking app with sign-in. Mark every real problem."
code: |
  1. Archive and upload from CI. Answer the encryption questions in the web form each time.
  2. Screenshots: the login screen and the splash screen, iPhone only (the app also runs on iPad).
  3. Keywords: "bank, banking, money, Bank of Example, savings, transfer"
  4. What's New: "Bug fixes."
  5. Review notes: "Standard banking app." Demo account: our QA account, password rotates weekly.
  6. Turn the staging backend off over the weekend to save money; review is fast.
choices:
  - text: "Encryption questions every time: set ITSAppUsesNonExemptEncryption in the Info.plist."
    correct: true
  - text: "Login and splash screenshots violate 2.3.3, and an iPad app needs at least one iPad 13-inch screenshot."
    correct: true
  - text: "The keywords repeat the company name, which is already searchable, wasting part of the 100 bytes."
    correct: true
  - text: "A demo account whose password rotates will expire during review; it must not expire, and the notes are too generic."
    correct: true
  - text: "Turning off the backend during review risks a 2.1 rejection; services must be live and accessible."
    correct: true
  - text: "What's New text is required for this first version and \"Bug fixes.\" is too short."
    correct: false
    why: "What's New isn't available for the first version of an app; it's required for later versions."
rubric:
  - I flagged the export compliance step.
  - I flagged the screenshots, both content and the missing iPad size.
  - I flagged keywords that repeat the company name.
  - I flagged the expiring demo account and generic notes.
  - I flagged turning the backend off.
  - I knew What's New doesn't apply to the first version.
solution: |
  Five real problems:

  1. **Encryption questions each time.** Set `ITSAppUsesNonExemptEncryption` (with the right value for a banking app, which may well use non-exempt encryption; check with whoever owns compliance).
  2. **Screenshots.** Guideline 2.3.3: show "the app in use, and not merely the title art, login page, or splash screen." An app that supports iPad must provide at least one iPad 13-inch screenshot.
  3. **Keywords.** "Bank of Example" repeats the company name, which is already searchable ("your app is searchable by app name and company name, so you shouldn't duplicate these values"). Every repeated word wastes part of the 100 bytes.
  4. **Review access.** The demo account "must not expire"; a rotating password will break during review. The notes should explain how to reach each feature, what the demo account contains and how transfers can be tested safely.
  5. **Backend off.** "Before You Submit": "Enable backend services so that they're live and accessible during review." Reviews usually take a day or two, not always.

  What's New "isn't available for the first version of the app," so item 4 is irrelevant now. For later versions, Guideline 2.3.12 allows a generic description only for "simple bug fixes, security updates, and performance improvements."
````

````exercise
id: m41-l05-e5
type: solve
prompt: |
  Write `missingItems(_:)`, a pre-submission check that lists what App Store Connect or App Review will need before this version can be submitted, using the requirements in this lesson: a selected build, export compliance answered, a privacy policy URL, published App Privacy answers, 1 to 10 iPhone screenshots, 1 to 10 iPad screenshots if the app supports iPad, a demo account if sign-in is required, and What's New for any version after the first. Print `ready to submit` if nothing is missing.

  ```swift
  let draft = Submission(
      buildSelected: true,
      exportCompliance: .missing,
      privacyPolicyURL: "https://example.com/privacy",
      privacyAnswersPublished: false,
      iPhoneScreenshots: 6,
      supportsIPad: true,
      iPadScreenshots: 0,
      requiresSignIn: true,
      demoAccount: nil,
      isFirstVersion: false,
      whatsNew: "Severe weather alerts for your saved places."
  )
  let missing = missingItems(draft)
  print(missing.isEmpty ? "ready to submit" : missing.joined(separator: "\n"))
  ```

  Expected output:

  ```output
  answer export compliance
  publish App Privacy answers
  1 to 10 iPad screenshots
  a demo account for App Review
  ```
starter: |
  enum ExportCompliance {
      case missing, answered
  }

  struct Submission {
      let buildSelected: Bool
      let exportCompliance: ExportCompliance
      let privacyPolicyURL: String?
      let privacyAnswersPublished: Bool
      let iPhoneScreenshots: Int          // iPhone with Dynamic Island (medium display)
      let supportsIPad: Bool
      let iPadScreenshots: Int            // iPad 13-inch display
      let requiresSignIn: Bool
      let demoAccount: String?
      let isFirstVersion: Bool
      let whatsNew: String
  }

  func missingItems(_ s: Submission) -> [String] {
      // your code
      return []
  }
hints:
  - "Check each requirement in the order listed and append a message when it isn't met."
  - "(1...10).contains(count) checks the screenshot range."
rubric:
  - Checks every listed requirement, with the iPad and sign-in checks conditional.
  - Uses the 1-to-10 range for screenshots.
  - Requires What's New only after the first version.
  - Prints the expected four lines.
solution: |
  ```swift
  enum ExportCompliance {
      case missing, answered
  }

  struct Submission {
      let buildSelected: Bool
      let exportCompliance: ExportCompliance
      let privacyPolicyURL: String?
      let privacyAnswersPublished: Bool
      let iPhoneScreenshots: Int          // iPhone with Dynamic Island (medium display)
      let supportsIPad: Bool
      let iPadScreenshots: Int            // iPad 13-inch display
      let requiresSignIn: Bool
      let demoAccount: String?
      let isFirstVersion: Bool
      let whatsNew: String
  }

  func missingItems(_ s: Submission) -> [String] {
      var missing: [String] = []
      if !s.buildSelected { missing.append("choose a build") }
      if s.exportCompliance == .missing { missing.append("answer export compliance") }
      if s.privacyPolicyURL == nil { missing.append("add a privacy policy URL") }
      if !s.privacyAnswersPublished { missing.append("publish App Privacy answers") }
      if !(1...10).contains(s.iPhoneScreenshots) { missing.append("1 to 10 iPhone screenshots") }
      if s.supportsIPad && !(1...10).contains(s.iPadScreenshots) { missing.append("1 to 10 iPad screenshots") }
      if s.requiresSignIn && s.demoAccount == nil { missing.append("a demo account for App Review") }
      if !s.isFirstVersion && s.whatsNew.isEmpty { missing.append("What's New text") }
      return missing
  }

  let draft = Submission(
      buildSelected: true,
      exportCompliance: .missing,
      privacyPolicyURL: "https://example.com/privacy",
      privacyAnswersPublished: false,
      iPhoneScreenshots: 6,
      supportsIPad: true,
      iPadScreenshots: 0,
      requiresSignIn: true,
      demoAccount: nil,
      isFirstVersion: false,
      whatsNew: "Severe weather alerts for your saved places."
  )
  let missing = missingItems(draft)
  print(missing.isEmpty ? "ready to submit" : missing.joined(separator: "\n"))
  ```

  ```output
  answer export compliance
  publish App Privacy answers
  1 to 10 iPad screenshots
  a demo account for App Review
  ```

  Each check is one sentence from Apple's help pages: Missing Compliance must be resolved before submitting a build that has it; a privacy policy URL "is required for all apps"; privacy answers are required "to submit new apps and app updates"; "at least one screenshot and ... up to 10 screenshots per device size," with iPad required if the app supports it; a demo account when sign-in is required; What's New for every version after the first.

  A real version of this check would read the metadata from files in the repository (or the App Store Connect API) and run in CI before the release workflow, so a missing item fails a build instead of a release afternoon.
````

````exercise
id: m41-l05-e6
type: design
prompt: "Design the beta program for a fitness app's 3.0 redesign: who tests what, when, and how feedback and crashes flow back. The team has 12 App Store Connect users, a community of 2,000 enthusiastic users, and wants a 4-week beta before submitting 3.0. Cover internal and external groups, review timing, build cadence, expiry, what testers are told, and how you'll decide the build is ready."
rubric:
  - Uses internal testing with automatic distribution for the team, and one or more external groups for the community.
  - Accounts for TestFlight App Review on the first build of the version and the one-in-review and six-per-day limits.
  - Writes useful What to Test notes and provides test information and a feedback email.
  - Uses public link limits or criteria to stage external testers.
  - Expires bad builds and accounts for the 90-day window.
  - Defines readiness with crash-free rate and feedback, then submits the tested build.
solution: |
  - **Week 0.** Internal group "Team" (the 12 users) with automatic distribution: every CI build on `release/3.0` lands there within the hour, no review. Fill in Test Information (beta description, feedback email) now, since external testing needs it.
  - **Week 1.** External group "Early" with a public link limited to 200 testers and criteria for the minimum iOS version the app supports. Submit the first 3.0 build for TestFlight App Review a few days before you need it: the first build of the version gets a full review. Later builds may not, but keep in mind only one build per version can be in review and at most six per 24 hours.
  - **Weeks 2–3.** Raise the link limit to 2,000 (or add a second group "Community") once crash-free sessions in "Early" are stable. Ship external builds twice a week, not on every commit; testers stop reading notes when they update daily. Each build's What to Test says what changed and what to try ("the new workout summary; please try with Apple Watch disconnected").
  - **Feedback and crashes.** Screenshot feedback and crashes arrive in App Store Connect and Xcode's Organizer; triage them daily against the build number. Expire any build with a data-loss or sign-in bug so new testers can't install it.
  - **Ready.** No open crash groups in the top ten, crash-free sessions on the latest build at or above the current App Store version's, and no unresolved high-severity feedback. Submit **that exact build** (the one testers used) for App Review, with review notes describing the redesign and a demo account.
  - **Expiry.** A 4-week beta fits inside the 90-day window; if it slips, upload a fresh build before testers hit Expired.
````

## Summary

- After an upload, a build is Processing, then Complete or Failed; once processed it has a TestFlight status. Set `ITSAppUsesNonExemptEncryption` so builds don't stop at Missing Compliance.
- Internal testing: up to 100 team members, no beta review, automatic distribution. External testing: up to 10,000 people, an internal group first, test information, and TestFlight App Review (full for the first build of a version; one in review at a time; six per 24 hours).
- Builds can be tested for 90 days; expire bad ones yourself, because testers keep access otherwise.
- Version metadata has documented limits: 30-character name, 170-character promotional text, 4000-character description and What's New, 100-**byte** keywords. Screenshots: 1 to 10 per size, iPhone with Dynamic Island (medium display) and iPad 13-inch if supported.
- App Review needs contact details, specific notes, a demo account that doesn't expire and live backend services. Then choose manual, automatic or scheduled release, and phased release for updates.
