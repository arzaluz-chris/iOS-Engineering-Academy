---
id: m41-l06
title: App Review and incident response
description: "Get through App Review and handle what happens when a release goes wrong. You learn the most common rejection reasons by guideline number, how to reply, resubmit or appeal, when an expedited review is justified, how to run a hotfix, why the App Store has no rollback and what you can do instead, and how to write a blameless postmortem."
module: m41
order: 6
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m41-l05]
objectives:
  - Recognize the most common rejection reasons and cite the App Review Guidelines section for each.
  - Respond to a rejection in App Store Connect, resubmit, use the bug fix submission process or appeal.
  - Decide when to request an expedited review and what to include.
  - Run a hotfix from the release tag, coordinating phased release, versions in review and feature flags.
  - Explain the App Store's rollback limits and design remote kill switches and a minimum supported version.
  - Write a blameless postmortem with a timeline, detection and mitigation times, and action items.
terms:
  - term: App Review Guidelines
    definition: "Apple's rules for apps on the App Store, in five sections: Safety (1), Performance (2), Business (3), Design (4) and Legal (5). Rejections cite a guideline number."
  - term: Appeal
    definition: "A request to the App Review Board when you believe review misunderstood your app or treated you unfairly. One appeal per submission that didn't pass, with specific reasons."
  - term: Expedited review
    definition: "A request to review a submission sooner because of a critical bug fix or a time-sensitive event. Apple asks that it be used only when truly needed."
  - term: Bug fix submission
    definition: "Apple's process for apps already on the store: bug fixes aren't delayed over guideline violations (except legal or safety issues) if you agree to address them in the next submission."
  - term: Hotfix
    definition: "A minimal patch release, branched from the tag of the live version, that fixes one severe problem and nothing else."
  - term: Kill switch
    definition: "A remotely controlled flag that turns a feature off in versions already installed, without a new build."
  - term: Postmortem
    definition: "A written review after an incident: what happened, when, why, and what will change. Blameless means it looks for causes in systems and processes, not people."
mastery:
  - Read a rejection message, find the guideline, and decide whether to fix, reply with information, or appeal.
  - Write an expedited review request for a critical bug with steps to reproduce.
  - Produce a hotfix plan when a newer version is already in review and the broken one is in phased release.
  - Explain to a product manager why "roll back to yesterday's version" isn't possible, and what you'll do instead.
  - Compute time to detect, mitigate and resolve from an incident timeline and turn findings into action items.
resources: [apple-app-review, asc-phased-release, app-review-guidelines, privacy-manifest-files, information-property-list]
cards:
  - id: m41-l06-c1
    front: Which guideline causes the most unresolved App Review issues?
    back: "2.1 App Completeness. Apple's App Review page says that, on average, over 40% of unresolved issues relate to it: crashes, placeholder content, broken links, incomplete information such as a missing demo account."
  - id: m41-l06-c2
    front: "Rejected for metadata only (screenshots, description). Do you need a new build?"
    back: "No. App Store Connect Help: if your app was rejected for a metadata issue, you can resubmit the same build after resolving the issue."
  - id: m41-l06-c3
    front: Can you roll back the App Store to the previous version?
    back: "No. App Store Connect Help: it's not possible to revert to a previous version; you must create and submit a new version. You can pause a phased release, turn features off remotely, or (for legal or usability issues) make versions unavailable, but people who installed the bad version keep it."
  - id: m41-l06-c4
    front: What should an expedited review request for a critical bug include?
    back: "The steps to reproduce the bug on the current App Store version, as Apple asks. Use it only for real emergencies; Apple may reject future requests from developers who abuse it."
  - id: m41-l06-c5
    front: "The 2.6.0 update is in phased release and crashing; 2.7.0 is waiting for review. First three moves?"
    back: "Turn the faulty feature off with its flag if it has one, and pause the phased release. Then branch hotfix 2.6.1 from the v2.6.0 tag; 2.7.0 must leave review (one app version under review per platform) unless you put the fix into 2.7.0 itself."
---

## The idea in one sentence

Most rejections come from a short list of guidelines you can check before submitting, and most incidents are survivable if you prepared the tools in advance, because the App Store can't take a version back: you mitigate with flags and phased release, fix forward with a hotfix, and then learn from it in a postmortem.

> [!note] Sources and what was checked
> Guideline numbers and quotations come from the App Review Guidelines at developer.apple.com/app-store/review/guidelines/, last updated October 16, 2026, read in November 2026. Review statistics, expedited reviews, appeals and bug fix submissions come from Apple's App Review page (developer.apple.com/distribute/app-review/); rejection handling, version and availability rules from App Store Connect Help ("Reply to App Review messages", "Manage a submission with unresolved issues", "Remove a submission from review", "Create a new version", "Make a version unavailable for download", "Release a version update in phases"). The guidelines change often: check the section numbers against the current page before quoting them to Apple. No submission or appeal was made for this lesson. The Swift blocks are models, compiled and run with Swift 6.3.

## The rejections you can prevent

The guidelines are long, but rejections cluster. Apple's App Review page lists its most common issues; here they are with the guideline text that applies, in the order they bite most teams.

**2.1 App Completeness.** "On average, over 40% of unresolved issues are related to guideline 2.1." 2.1(a): submissions "should be final versions with all necessary metadata and fully functional URLs included; placeholder text, empty websites, and other temporary content should be scrubbed," with demo account information and the back end turned on. "We will reject incomplete app bundles and binaries that crash or exhibit obvious technical problems." 2.1(b): in-app purchases must be "complete, up-to-date, visible to the reviewer and functional." Prevention: lessons 1–5. Tests in CI, a TestFlight round on real devices, a demo account that doesn't expire, live services and specific review notes.

**2.3 Accurate Metadata.** Metadata, "including privacy information, your app description, screenshots, and previews," must "accurately reflect the app's core experience." The sub-rules that come up most:

- 2.3.1(a): new features "must be described with specificity in the Notes for Review section ... (generic descriptions will be rejected) and accessible for review."
- 2.3.3: screenshots "should show the app in use, and not merely the title art, login page, or splash screen."
- 2.3.7: app names "must be limited to 30 characters," and no keyword stuffing with "trademarked terms, popular app names, pricing information."
- 2.3.12: What's New must describe significant changes specifically.

**2.5 Software Requirements.** 2.5.1: "Apps may only use public APIs and must run on the currently shipping OS." 2.5.19: "Don't include any hidden, dormant, or undocumented features in your app" (lesson 3's warning about feature flags).

**3.1.1 In-App Purchase.** "If you want to unlock features or functionality within your app ... you must use in-app purchase. Apps may not use their own mechanisms to unlock content or functionality, such as license keys..." The rules for payments differ by storefront and change often; read the current 3.1 sections for each market you sell in.

**4.2 Minimum Functionality.** "Your app should include features, content, and UI that elevate it beyond a repackaged website." 4.2.2: apps shouldn't "primarily be marketing materials, advertisements, web clippings, content aggregators, or a collection of links."

**4.3 Spam.** 4.3(a): "Don't create multiple Bundle IDs of the same app," for example a separate map app per city.

**4.8 Login Services.** An app that uses a third-party or social login for the user's primary account "must also offer as an equivalent option another login service" that limits data to name and email, lets users keep their email private, and doesn't collect interactions for advertising without consent; the guideline lists exceptions, such as apps that use only your company's own account system.

**5.1.1 Data Collection and Storage.**

- (i) a privacy policy link "in the App Store Connect metadata field and within the app in an easily accessible manner."
- (ii) consent for user or usage data, and purpose strings that "clearly and completely describe your use of the data."
- (v) "If your app supports account creation, you must also offer account deletion within the app."

**5.1.2 Data Use and Sharing.** (i) "You must receive explicit permission from users via the App Tracking Transparency APIs to track their activity," and you must disclose sharing with third parties "including with third-party AI."

Apple's "Before You Submit" checklist is the version of this list to run every time: test for crashes and bugs, complete and accurate metadata, current contact information, full access for the reviewer, live back end, explanations of non-obvious features and in-app purchases in the notes.

## When you're rejected

A rejection arrives as a message in the App Review section of App Store Connect, citing the guideline. App Store Connect Help ("Reply to App Review messages"): "You can correspond with Apple, and include attachments, such as screenshots and supporting documents, until you resubmit." Then one of four paths:

1. **Fix it and resubmit.** Most rejections are right. Fix the problem, upload a new build if the problem is in the binary, and say in the reply what changed.
2. **Fix the metadata only.** "If your app was rejected for a metadata issue, you can resubmit the same build after resolving the issue." No new build, no new TestFlight round.
3. **Explain.** If the reviewer missed something (couldn't find a feature, didn't have the hardware), reply with the information, steps or a video. The guidelines: "If your app has been rejected and you have questions or would like to provide additional information, please use App Store Connect to communicate directly with the App Review team." Often the fastest path.
4. **Appeal.** If you believe the decision is wrong, the App Review Board decides. Apple's App Review page asks you to "provide specific reasons why you believe your app complies," to "submit only one appeal per submission that didn't pass review," and to "respond to any requests for additional information before submitting an appeal."

When a submission has several items and only some are rejected, its status is **Unresolved Issues**; you either edit and resubmit the rejected items or remove them and continue with the accepted ones ("Manage a submission with unresolved issues").

**Bug fix submissions.** For an app that's already on the store, the guidelines promise: "bug fixes will not be delayed over guideline violations except for those related to legal or safety issues." If a hotfix is rejected over an unrelated, long-standing issue, reply that you'd like to use this process and will address the issue in your next submission. This exists precisely so an incident isn't made worse by a policy discussion.

Write replies like a good pull request description: what the reviewer saw, what you changed or why it complies, how to verify it. Calm and specific beats indignant.

## Expedited review

Apple's App Review page: "You can request the review of your app to be expedited if you face extenuating circumstances, such as fixing a critical bug in your app or releasing your app to coincide with an event you're directly associated with." For a critical bug fix, "include the steps to reproduce the bug on the current version of your app." The guidelines add: "Please respect your fellow developers by seeking expedited review only when you truly need it. If we find you're abusing this system, we may reject your requests going forward."

So: data loss, a crash on launch for many users, a security or payment problem, a broken sign-in. Not a missed marketing date, and not a bug that a feature flag already mitigated. Apple's contact form for the request wasn't opened for this lesson.

## There is no rollback

App Store Connect Help ("Create a new version"): "Keep in mind that it's not possible to revert to a previous version on the App Store if you have an issue with your app. You must create and submit a new version."

What you **can** do, and what each costs:

| Tool | What it does | Limits |
| --- | --- | --- |
| Pause phased release | Stops new automatic updates (lesson 3) | Up to 30 days in total; manual downloads continue; people who updated keep the version |
| Feature flag / kill switch | Turns the broken feature off in installed copies, in minutes | Only works for code you put behind a flag before shipping |
| Server-side fix | Changes what the app receives (bad data, a response the app can't parse) | Only for problems that start on the server |
| Minimum supported version | Tells old versions to update before use | Users must be able to update; never lock out the only version available |
| Make a version unavailable | Removes versions from the App Store for "legal or usability issues" | Apple: "you must submit an app update" (or remove the app); installed copies stay |
| Hotfix | A new version with the fix | App Review time, even when expedited |

The phased release pause is the one people misremember. Here's what it does to the rollout, with Apple's percentages:

```swift
// App Store Connect Help, "Release a version update in phases".
let phasedPercentages = [1, 2, 5, 10, 20, 50, 100]   // days 1...7

struct PhasedRelease {
    var day = 1                // the day the rollout has reached
    var pausedDaysUsed = 0
    var isPaused = false

    var percentage: Int { phasedPercentages[min(day, 7) - 1] }

    mutating func advanceOneDay() {
        if isPaused {
            pausedDaysUsed += 1
            if pausedDaysUsed >= 30 { isPaused = false }   // the 30-day pause budget is spent
        } else if day < 7 {
            day += 1
        }
    }
}

var release = PhasedRelease()
var log: [String] = []
for calendarDay in 1...12 {
    if calendarDay == 4 { release.isPaused = true }      // crash spike found on day 3's numbers
    log.append("\(calendarDay):\(release.percentage)%\(release.isPaused ? " paused" : "")")
    if calendarDay == 9 { release.isPaused = false }     // fix confirmed server-side
    release.advanceOneDay()
}
print(log.joined(separator: "  "))
print("pause days used:", release.pausedDaysUsed)
```

```output
1:1%  2:2%  3:5%  4:10% paused  5:10% paused  6:10% paused  7:10% paused  8:10% paused  9:10% paused  10:20%  11:50%  12:100%
pause days used: 5
```

The pause holds the rollout where it was ("your phased release will pick up on the day it was left off"), and resuming continues with day 5's 20%. It doesn't go back to 0%: whoever had the update keeps it. The model assumes the pause takes effect at the start of a day, after that day's step; Apple doesn't document the timing within a day, and the model treats the 30-day limit as a total budget, as the help page describes ("if you pause the release for 10 days and then choose to resume it, you will have 20 days remaining").

### Preparing the escape hatches

The table's useful rows only exist if you built them before the incident. A small remote configuration fetched at launch can carry both a **kill switch** per risky feature and a **minimum supported version**:

```swift
struct RemoteConfig {
    let minimumSupportedVersion: String
    let killedFeatures: Set<String>
}

func parse(_ version: String) -> [Int]? {
    let parts = version.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    var numbers: [Int] = []
    for part in parts {
        guard let n = Int(part), n >= 0 else { return nil }
        numbers.append(n)
    }
    return numbers
}

enum LaunchDecision: Equatable {
    case run(disabled: [String])
    case requireUpdate
}

func decide(appVersion: String, config: RemoteConfig, features: [String]) -> LaunchDecision {
    guard let current = parse(appVersion), let minimum = parse(config.minimumSupportedVersion) else {
        return .run(disabled: [])          // a bad config must never lock everyone out
    }
    if current.lexicographicallyPrecedes(minimum) {
        return .requireUpdate
    }
    return .run(disabled: features.filter { config.killedFeatures.contains($0) })
}

let features = ["radar-v2", "alerts", "widgets"]
let normal = RemoteConfig(minimumSupportedVersion: "2.0.0", killedFeatures: [])
let incident = RemoteConfig(minimumSupportedVersion: "2.0.0", killedFeatures: ["radar-v2"])
let afterFix = RemoteConfig(minimumSupportedVersion: "2.6.1", killedFeatures: [])

print(decide(appVersion: "2.6.0", config: normal, features: features))
print(decide(appVersion: "2.6.0", config: incident, features: features))
print(decide(appVersion: "2.6.0", config: afterFix, features: features))
print(decide(appVersion: "2.10.0", config: afterFix, features: features))
print(decide(appVersion: "2.6.0", config: RemoteConfig(minimumSupportedVersion: "2.6", killedFeatures: []), features: features))
```

```output
run(disabled: [])
run(disabled: ["radar-v2"])
requireUpdate
run(disabled: [])
run(disabled: [])
```

- During the incident, `radar-v2` is switched off for everyone on 2.6.0 within one config fetch.
- After 2.6.1 is live everywhere, raising the minimum to 2.6.1 sends anyone still on 2.6.0 to update; 2.10.0 compares as newer because the versions are parsed (lesson 3).
- The last line is the safety rule: a malformed config (`"2.6"`) fails **open**. A kill switch system that can lock every user out with a typo is itself an incident waiting to happen.

Use the minimum-version lever sparingly. It's right for a security problem or a server API the old version can't use; forcing updates for a cosmetic bug annoys people who can't update right now. Make sure the required version is actually available in every storefront first.

## Running a hotfix

A hotfix is a release with the smallest possible change, made under time pressure, which is exactly when process matters most. A sequence that works:

1. **Mitigate first.** Turn off the feature with its flag, fix the server, or pause the phased release. Mitigation is minutes; a hotfix is hours to days.
2. **Branch from the tag of the live version** (lesson 3), not from `main`, which has weeks of unreviewed-in-production changes: `git switch -c hotfix/2.6.1 v2.6.0`.
3. **Fix one thing, with a test** that fails without the fix (Module 33). Code review still applies, by a second person.
4. **Bump the patch version** and let CI build it (lesson 2). Internal TestFlight testers check the fix and a smoke test on real devices.
5. **Submit with an expedited review request** if it qualifies, with steps to reproduce on the live version.
6. **Release**, usually to all users at once once approved, since the point is to replace the bad version.
7. **Merge the fix back** into `main` and any open release branch, and tag `v2.6.1`.

The awkward case is a newer version already in review. App Store Connect Help says "each platform can have one app version submission under review at a time" and, for creating a version, to "ensure that the current version status is Ready for Distribution to initiate a new version." So 2.7.0 must leave review (removing it makes its status Developer Rejected; "if you resubmit the review process will start over"), unless the fix goes into 2.7.0 itself and 2.7.0 becomes the hotfix. Which is better depends on how risky 2.7.0's other changes are. Exactly how App Store Connect lets you renumber or replace the 2.7.0 version record wasn't checked for this lesson; expect to look at it under pressure the first time, which is a good reason to rehearse.

## Postmortems

After the incident is resolved, write it down while people remember. A **blameless** postmortem looks for the conditions that let a reasonable person's change cause the incident, because "be more careful" isn't an action item and blame teaches people to hide mistakes.

A useful postmortem has:

- **Summary**: one paragraph a non-engineer can read. Impact in users, duration and money if known.
- **Timeline** in UTC, from the change that caused it to the all-clear, with what each person knew at the time.
- **Detection, mitigation and resolution times.** These are what improve over time.
- **Contributing factors**: why the bug was written, why tests and review didn't catch it, why detection took as long as it did.
- **What went well**: the flag that existed, the alert that fired.
- **Action items**, each with an owner and a date, that change systems: a test, an alert threshold, a flag requirement for risky features, a checklist item.

Computing the three times from a timeline:

```swift
struct Event {
    let minute: Int          // minutes since the bad build started reaching users
    let what: String
}

let timeline = [
    Event(minute: 0, what: "2.6.0 phased release day 1 starts"),
    Event(minute: 1_310, what: "crash-free sessions alert fires"),
    Event(minute: 1_335, what: "on-call acknowledges"),
    Event(minute: 1_390, what: "radar-v2 turned off remotely; crash rate back to normal"),
    Event(minute: 1_405, what: "phased release paused"),
    Event(minute: 4_210, what: "2.6.1 approved after expedited review and released"),
]

func minutes(_ m: Int) -> String {
    "\(m / 60)h \(m % 60 < 10 ? "0" : "")\(m % 60)m"
}

func time(to text: String) -> Int? {
    for event in timeline where event.what.contains(text) {
        return event.minute
    }
    return nil
}

if let detected = time(to: "alert"), let mitigated = time(to: "turned off"), let resolved = time(to: "released") {
    print("time to detect:  ", minutes(detected))
    print("time to mitigate:", minutes(mitigated - detected))
    print("time to resolve: ", minutes(resolved))
}
```

```output
time to detect:   21h 50m
time to mitigate: 1h 20m
time to resolve:  70h 10m
```

Read as a postmortem, the numbers say where to invest. Mitigation took 80 minutes because a flag existed: keep requiring flags for risky features. Detection took almost 22 hours, while the bad version reached 1% and then 2% of users: that's the first action item (an alert on the new build's crash-free rate, lesson 4, not the whole app's). Resolution took three days, mostly App Review, which you don't control; that's why mitigation matters more than resolution.

## Common mistakes

> [!error] Submitting what you haven't tested on a device
> Guideline 2.1 rejections are the most common for a reason. Run the release build through TestFlight on real devices with the reviewer's demo account before submitting.

> [!error] Arguing in the first reply
> Most rejections are fixable or caused by missing information. Reply with specifics; appeal only when you can say exactly why the app complies, once per submission.

> [!error] Requesting expedited review for everything
> Apple may stop granting requests to developers who overuse them. Save it for critical bugs (with steps to reproduce) and real event deadlines.

> [!error] Planning on a rollback
> There isn't one. Plan on flags, phased release pauses, server fixes and a fast hotfix path, and rehearse them.

> [!error] Hotfixing from main
> `main` contains changes that have never been in production. Branch from the live version's tag and change one thing.

> [!error] A postmortem that blames a person
> "Ana forgot to test on iPad" leads to nothing. "No iPad device in the TestFlight matrix and no iPad UI test" leads to two action items.

## Exercises

````exercise
id: m41-l06-e1
type: prediction
prompt: "The app checks a minimum supported version from its remote config. What does this program print?"
code: |
  func parse(_ version: String) -> [Int]? {
      let parts = version.split(separator: ".", omittingEmptySubsequences: false)
      guard parts.count == 3 else { return nil }
      var numbers: [Int] = []
      for part in parts {
          guard let n = Int(part), n >= 0 else { return nil }
          numbers.append(n)
      }
      return numbers
  }

  func mustUpdate(appVersion: String, minimum: String) -> Bool {
      guard let current = parse(appVersion), let required = parse(minimum) else { return false }
      return current.lexicographicallyPrecedes(required)
  }

  print(mustUpdate(appVersion: "2.6.0", minimum: "2.6.1"))
  print(mustUpdate(appVersion: "2.6.1", minimum: "2.6.1"))
  print(mustUpdate(appVersion: "2.10.0", minimum: "2.9.0"))
  print(mustUpdate(appVersion: "1.9.9", minimum: "2.0"))
  print(mustUpdate(appVersion: "3.0.0", minimum: "2.6.1") || mustUpdate(appVersion: "2.6.0", minimum: "2.6.1"))
output: |
  true
  false
  false
  false
  true
hints:
  - "lexicographicallyPrecedes is false for equal arrays."
  - "\"2.0\" has two components, so parse returns nil."
solution: |
  ```output
  true
  false
  false
  false
  true
  ```

  1. `[2, 6, 0]` precedes `[2, 6, 1]`: update required.
  2. Equal arrays don't precede each other: the minimum version itself is allowed.
  3. `[2, 10, 0]` vs `[2, 9, 0]`: 10 > 9, so 2.10.0 is newer and doesn't need to update. A string comparison would have forced it to.
  4. `"2.0"` isn't three components, so `parse` returns `nil` and the function returns `false`. 1.9.9 really is older than 2.0, but a malformed config fails open on purpose: a typo in a config file must not lock every user out.
  5. The first call is `false`, the second `true`, so the `||` is `true`.

  Failing open is the right default for a minimum-version gate. Validate the config on the server before publishing it, so the typo is caught there instead of silently disabling the gate.
````

````exercise
id: m41-l06-e2
type: comprehension
prompt: "Your update was rejected under guideline 2.3.3 because the iPad screenshots show only the sign-in screen. The binary is fine. What's the fastest correct path?"
choices:
  - text: "Replace the screenshots with ones showing the app in use, reply in App Review if useful, and resubmit the same build."
    correct: true
    why: "Metadata rejections can be resolved and resubmitted with the same build."
  - text: "Upload a new build with a higher build number, since a rejected build can't be submitted again."
    correct: false
    why: "For a metadata issue, App Store Connect Help says you can resubmit the same build."
  - text: "Appeal to the App Review Board, because screenshots aren't part of the app."
    correct: false
    why: "Screenshots are metadata, and 2.3.3 says they must show the app in use. The rejection is correct."
  - text: "Request an expedited review and explain that the screenshots are temporary."
    correct: false
    why: "Placeholder content is itself a 2.1 problem, and this isn't a critical bug."
solution: |
  **Fix the screenshots and resubmit the same build.** App Store Connect Help: "If your app was rejected for a metadata issue, you can resubmit the same build after resolving the issue." Guideline 2.3.3: "Screenshots should show the app in use, and not merely the title art, login page, or splash screen."

  A one-line reply ("Replaced the iPad screenshots with the forecast, radar and alerts screens") helps the next reviewer see what changed.
````

````exercise
id: m41-l06-e3
type: fill-in
prompt: "Complete the guideline numbers from the App Review Guidelines (October 2026)."
code: |
  Crashes, placeholder content, missing demo account: [[1]] App Completeness
  Account creation requires in-app account deletion: 5.1.1([[2]])
  Unlocking features must use in-app purchase: [[3]] In-App Purchase
  Hidden, dormant or undocumented features: 2.5.[[4]]
blanks:
  - id: "1"
    answers: ["2.1"]
  - id: "2"
    answers: ["v"]
  - id: "3"
    answers: ["3.1.1"]
  - id: "4"
    answers: ["19"]
solution: |
  - **2.1 App Completeness**: final versions, no placeholders, demo account and live back end; "binaries that crash or exhibit obvious technical problems" are rejected.
  - **5.1.1(v) Account Sign-In**: "If your app supports account creation, you must also offer account deletion within the app."
  - **3.1.1 In-App Purchase**: "If you want to unlock features or functionality within your app ... you must use in-app purchase."
  - **2.5.19**: "Don't include any hidden, dormant, or undocumented features in your app."

  Numbers can move when Apple revises the guidelines, so check the current page before citing one in a reply.
````

````exercise
id: m41-l06-e4
type: find-errors
prompt: "An incident runbook draft for the mobile team. Mark every real problem."
code: |
  1. If a release is bad, roll back to the previous version in App Store Connect.
  2. Hotfix branch: create it from main so it includes everything we've fixed since.
  3. Request expedited review for every hotfix, and for releases that miss a marketing date.
  4. Pause the phased release while investigating; that also stops manual downloads.
  5. Raise the minimum supported version to the hotfix as soon as it's submitted.
  6. Postmortem: identify who made the mistake and add them to an extra review list.
choices:
  - text: "Step 1: there's no rollback; you must submit a new version."
    correct: true
  - text: "Step 2: branch from the live version's tag, not from main."
    correct: true
  - text: "Step 3: expedited review is for critical bugs and event deadlines you're directly associated with, and abuse can get requests rejected."
    correct: true
  - text: "Step 4: pausing stops automatic updates only; anyone can still download the update manually."
    correct: true
  - text: "Step 5: requiring a version that isn't approved and available would lock users out."
    correct: true
  - text: "Step 6: blaming a person instead of fixing the conditions."
    correct: true
rubric:
  - I flagged the nonexistent rollback.
  - I flagged branching from main.
  - I flagged the expedited review policy.
  - I flagged the phased release misunderstanding.
  - I flagged forcing an unavailable version.
  - I flagged the blame-based postmortem.
solution: |
  Every step has a problem:

  1. "It's not possible to revert to a previous version on the App Store." Mitigate with flags, the server and a phased release pause; fix forward.
  2. `main` has unshipped changes. `git switch -c hotfix/2.6.1 v2.6.0` and change one thing.
  3. Apple: expedited review is for "extenuating circumstances, such as fixing a critical bug ... or releasing your app to coincide with an event you're directly associated with," and "if we find you're abusing this system, we may reject your requests going forward." A marketing date isn't an event in that sense.
  4. "Apps and app updates in phased release can be manually downloaded from the App Store by anyone at any time."
  5. Raise the minimum only after the hotfix is approved, released and visible in every storefront (release can take up to 24 hours to appear), and only if the old version is truly harmful.
  6. A blameless postmortem asks what let a reasonable change cause harm: missing test, missing alert, missing flag. Action items change systems.
````

````exercise
id: m41-l06-e5
type: solve
prompt: |
  Write `hotfixPlan(live:inReview:phasedReleaseActive:)`, which returns the ordered steps for a hotfix: pause the phased release if one is active; branch `hotfix/<patch>` from tag `v<live>` (the patch version is the live version with the third number plus one); if a version is in review, remove it from review (it becomes Developer Rejected); submit the hotfix with an expedited review request; and if a version was in review, merge the fix into it and resubmit it after the hotfix is released.

  ```swift
  for (index, step) in hotfixPlan(live: "2.6.0", inReview: "2.7.0", phasedReleaseActive: true).enumerated() {
      print("\(index + 1). \(step)")
  }
  print("--")
  for (index, step) in hotfixPlan(live: "3.1.4", inReview: nil, phasedReleaseActive: false).enumerated() {
      print("\(index + 1). \(step)")
  }
  ```

  Expected output:

  ```output
  1. pause the phased release of 2.6.0
  2. branch hotfix/2.6.1 from tag v2.6.0
  3. remove 2.7.0 from review (it becomes Developer Rejected)
  4. submit 2.6.1 and request an expedited review
  5. merge the fix into 2.7.0 and resubmit it after 2.6.1 is released
  --
  1. branch hotfix/3.1.5 from tag v3.1.4
  2. submit 3.1.5 and request an expedited review
  ```
starter: |
  func hotfixPlan(live: String, inReview: String?, phasedReleaseActive: Bool) -> [String] {
      var steps: [String] = []
      // your code
      return steps
  }
hints:
  - "Split the live version on periods, convert to Int and add 1 to the third component."
  - "Append the conditional steps only when inReview isn't nil or the phased release is active."
rubric:
  - Computes the patch version from the live version.
  - Pauses phased release first only when it's active.
  - Removes the in-review version before submitting the hotfix, and merges back afterward.
  - Prints the expected output.
solution: |
  ```swift
  func parse(_ version: String) -> [Int] {
      version.split(separator: ".").map { Int($0) ?? 0 }
  }

  func format(_ parts: [Int]) -> String {
      parts.map(String.init).joined(separator: ".")
  }

  func hotfixPlan(live: String, inReview: String?, phasedReleaseActive: Bool) -> [String] {
      var steps: [String] = []
      if phasedReleaseActive {
          steps.append("pause the phased release of \(live)")
      }
      let liveParts = parse(live)
      let hotfix = format([liveParts[0], liveParts[1], liveParts[2] + 1])
      steps.append("branch hotfix/\(hotfix) from tag v\(live)")
      if let inReview {
          steps.append("remove \(inReview) from review (it becomes Developer Rejected)")
      }
      steps.append("submit \(hotfix) and request an expedited review")
      if let inReview {
          steps.append("merge the fix into \(inReview) and resubmit it after \(hotfix) is released")
      }
      return steps
  }

  for (index, step) in hotfixPlan(live: "2.6.0", inReview: "2.7.0", phasedReleaseActive: true).enumerated() {
      print("\(index + 1). \(step)")
  }
  print("--")
  for (index, step) in hotfixPlan(live: "3.1.4", inReview: nil, phasedReleaseActive: false).enumerated() {
      print("\(index + 1). \(step)")
  }
  ```

  ```output
  1. pause the phased release of 2.6.0
  2. branch hotfix/2.6.1 from tag v2.6.0
  3. remove 2.7.0 from review (it becomes Developer Rejected)
  4. submit 2.6.1 and request an expedited review
  5. merge the fix into 2.7.0 and resubmit it after 2.6.1 is released
  --
  1. branch hotfix/3.1.5 from tag v3.1.4
  2. submit 3.1.5 and request an expedited review
  ```

  The order encodes the documented constraints: one app version under review per platform, so 2.7.0 leaves review before 2.6.1 goes in; removing it makes it Developer Rejected and its review starts over when resubmitted; and the fix must also land in 2.7.0, or 2.7.0 would reintroduce the bug.

  The plan leaves out the step that usually comes first, a kill switch, because it depends on whether the broken feature had a flag. It also assumes the hotfix is a separate version; shipping the fix inside 2.7.0 is the alternative when 2.7.0's other changes are low risk.
````

````exercise
id: m41-l06-e6
type: design
prompt: "Write the outline of a blameless postmortem for this incident, including action items with owners: version 2.6.0 changed how cached forecasts are migrated. On devices with more than 500 saved places, the migration ran on the main thread at launch and the app was killed by the watchdog before it finished, every launch. Phased release reached 5% before anyone noticed, two days in. There was no feature flag around the migration. The hotfix took 3 days including expedited review."
code: |
  Day 1 09:00 UTC  2.6.0 phased release starts (1%)
  Day 2 09:00      2%
  Day 3 09:00      5%
  Day 3 14:20      Support escalates 40 one-star reviews: "app won't open"
  Day 3 15:05      Phased release paused
  Day 3 18:40      Root cause found from a sysdiagnose a user sent
  Day 6 11:00      2.6.1 released to all users
rubric:
  - Summarizes impact and duration without naming individuals as causes.
  - Explains why the organizer and crash SDK missed it (watchdog terminations aren't in the Crashes organizer and can't be caught by a signal handler) and that detection came from support.
  - Identifies contributing factors, such as main-thread migration at launch, no large-data test, no flag, alerting on crashes but not on launch terminations.
  - Notes what went well, such as the phased release limiting exposure and the pause.
  - Lists concrete action items with owners and dates.
solution: |
  **Summary.** For about two and a half days, users of 2.6.0 with more than 500 saved places couldn't open the app: a data migration ran on the main thread at launch and the system's watchdog terminated the app before it finished, on every launch. The phased release limited exposure to about 5% of auto-updating users. Mitigated by pausing the phased release on day 3; resolved by 2.6.1 on day 6.

  **Timeline** as given, in UTC, plus what was known: the crash-free rate looked normal throughout.

  **Detection: 2 days 5 hours, by support, not by monitoring.** Watchdog terminations aren't in the Crashes organizer (Apple lists watchdog events among the reports that are only on the device), and a crash SDK's signal handler never runs when the system kills the process. MetricKit's launch and termination metrics would have shown it, but nobody alerted on them.

  **Contributing factors.** The migration ran synchronously at launch on the main thread. Tests used a fixture with 20 places. TestFlight testers had small data sets. The migration had no flag, so the only fix was a new build. Alerts watched crash-free sessions but not launch time or background and foreground terminations.

  **What went well.** Phased release capped exposure at 5%; the pause was immediate once someone looked; a user's sysdiagnose made the root cause clear within four hours; expedited review was granted.

  **Action items.**
  1. Run migrations off the main thread with progress UI, and resumable (owner: storage team lead, 2 weeks).
  2. Add a migration test with 5,000 places and a launch performance test (owner: iOS platform, 2 weeks).
  3. Alert on the new build's launch-time and termination metrics from MetricKit, not just crashes (owner: on-call rotation lead, 1 week).
  4. Require a remote flag around any one-time data migration so it can be skipped (owner: tech lead, add to the release checklist, 1 week).
  5. Add a large-account tester to the TestFlight external group (owner: QA, this release).
````

## Summary

- Rejections cluster: 2.1 completeness (over 40% of unresolved issues), 2.3 metadata, 2.5 software requirements including hidden features, 3.1.1 in-app purchase, 4.2 minimum functionality, 4.3 spam, 4.8 login services and 5.1 privacy. Run Apple's "Before You Submit" checklist every time.
- When rejected: fix and resubmit (the same build for metadata-only issues), reply with information in App Store Connect, or appeal once with specific reasons. Bug fixes for live apps aren't held up over unrelated guideline issues unless they're legal or safety ones.
- Request expedited review only for critical bugs (with steps to reproduce) and real event deadlines.
- The App Store has no rollback. Prepare kill switches and a minimum supported version that fails open, pause phased releases, fix servers, and hotfix from the live tag.
- Write blameless postmortems with a timeline, detection, mitigation and resolution times, and action items that change systems.
