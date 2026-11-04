---
id: m41-l03
title: Versioning and release management
description: "Give every build a version and a build number that follow Apple's rules, decide the next version with semantic versioning and Conventional Commits, cut releases from branches and tags, generate a changelog people can read, roll updates out with phased release, and separate shipping code from turning features on with deterministic feature flags."
module: m41
order: 3
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m41-l02, m14-l04]
objectives:
  - State Apple's documented format for CFBundleShortVersionString and CFBundleVersion and how each is used.
  - Parse and compare version strings numerically, never as text.
  - Apply the build-number rules for iOS and macOS uploads.
  - Decide the next semantic version from Conventional Commits and generate a changelog from them.
  - Run a release from a release branch and an annotated tag, and know what phased release does and doesn't control.
  - Roll a feature out to a stable percentage of users with a deterministic hash, and explain why hashValue can't do it.
terms:
  - term: CFBundleShortVersionString
    definition: "The user-visible version (MARKETING_VERSION in Xcode), shown on the App Store. Apple documents it as three period-separated integers, Major.Minor.Patch, digits and periods only."
  - term: CFBundleVersion
    definition: "The build string (CURRENT_PROJECT_VERSION in Xcode). One to three period-separated integers; missing ones count as zero and extras are ignored. It uniquely identifies a build in App Store Connect."
  - term: Semantic versioning
    definition: "MAJOR.MINOR.PATCH, where you increment MAJOR for incompatible changes, MINOR for backward-compatible features and PATCH for backward-compatible fixes (semver.org 2.0.0)."
  - term: Conventional Commits
    definition: "A commit message convention: type(scope): description. fix maps to a patch, feat to a minor version, and a ! or a BREAKING CHANGE: footer to a major one."
  - term: Phased release
    definition: "An App Store option that releases an update over 7 days to a growing percentage of users with automatic updates on. It can be paused for up to 30 days in total, and anyone can still download the update manually."
  - term: Feature flag
    definition: "A runtime switch, usually controlled by remote configuration, that decides whether a feature that's already in the binary is turned on for a given user."
  - term: FNV-1a
    definition: "A simple non-cryptographic hash: start from an offset basis, and for each byte XOR it in and multiply by the FNV prime. Deterministic across processes and devices, unlike Swift's hashValue."
mastery:
  - Write a parser that rejects invalid version numbers and compares 2.10.0 and 2.9.3 correctly.
  - Explain which build numbers App Store Connect will accept for an iOS app and for a Mac app.
  - Given a list of commit subjects, say the next version and write the changelog section.
  - Cut a release branch, tag the release commit and merge fixes back to main.
  - Implement percentage rollout with FNV-1a buckets and show that raising the percentage keeps earlier users enabled.
  - Explain how feature flags interact with App Review's rules on hidden features.
resources: [information-property-list, app-review-guidelines, git-merge-reference]
cards:
  - id: m41-l03-c1
    front: CFBundleShortVersionString vs CFBundleVersion?
    back: "ShortVersionString is the user-visible version on the App Store: three integers, Major.Minor.Patch (MARKETING_VERSION). CFBundleVersion is the build string (CURRENT_PROJECT_VERSION): one to three integers, missing ones are zero, and it identifies the build uniquely in App Store Connect."
  - id: m41-l03-c2
    front: Can an iOS app's build number start again at 1 for a new version? A Mac app's?
    back: "Apple's 'Preparing your app for distribution': build strings for Mac apps must increment across all versions; for other platforms they can start over at 1 for a new version. A failed upload's build number can be reused."
  - id: m41-l03-c3
    front: "Commits since 2.4.1: fix(radar): …, chore: …, feat(alerts): …. Next version?"
    back: "2.5.0. The highest bump wins: feat means minor (and resets patch to 0). A ! after the type or a BREAKING CHANGE: footer would make it 3.0.0. chore doesn't affect the version."
  - id: m41-l03-c4
    front: Why can't you use String.hashValue to put users in rollout buckets?
    back: "Swift seeds hashing randomly per process, so hashValue changes between launches and between devices. A user would flip in and out of the rollout. Use a fixed algorithm such as FNV-1a over the UTF-8 bytes of flag + user ID."
  - id: m41-l03-c5
    front: "Phased release: what are the daily percentages, and what doesn't it control?"
    back: "1%, 2%, 5%, 10%, 20%, 50%, 100% over 7 days, for users with automatic updates on. It can be paused for up to 30 days in total. It doesn't stop anyone from updating manually from the App Store, and it can't take a release back."
---

## The idea in one sentence

Every build you upload carries two numbers with different jobs (a version people see and a build string that identifies the upload), and release management is the set of habits around them: decide the next version from what changed, cut and tag releases so you can find the exact code later, roll out gradually, and keep "is the code shipped" separate from "is the feature on."

> [!note] Sources and what was checked
> The version keys come from Apple's Information Property List reference (`CFBundleShortVersionString`, `CFBundleVersion`) and "Preparing your app for distribution"; upload and phased-release rules from App Store Connect Help ("Upload builds", "Build upload statuses", "Create a new version", "Release a version update in phases"); version semantics from semver.org 2.0.0 and conventionalcommits.org 1.0.0; changelog categories from Keep a Changelog 1.1.0; review rules from the App Review Guidelines (last updated October 16, 2026). All read in November 2026. App Store Connect's screens weren't checked. Every Swift block was compiled and run with Swift 6.3.

## Two numbers, two jobs

Apple's Information Property List reference defines both keys. In Xcode you set them as the **Version** (`MARKETING_VERSION`) and **Build** (`CURRENT_PROJECT_VERSION`) fields, which the default Info.plist reads through build settings.

**`CFBundleShortVersionString`**, the version:

> This key is a user-visible string for the version of the bundle. The required format is three period-separated integers, such as 10.14.1. The string can only contain numeric characters (0-9) and periods.

It's what the App Store shows and what App Store Connect's "version" record is called. Each new version you submit gets a new App Store Connect version record ("enter an incremental App Store version number," says the "Create a new version" help page). Note that Xcode's app template starts at `1.0`, two components; the reference says three. Use three and you never have to find out which one a tool enforces.

**`CFBundleVersion`**, the build string:

> This key is a machine-readable string composed of one to three period-separated integers, such as 10.14.1. The string can only contain numeric characters (0-9) and periods. ... You can include more integers but the system ignores them. You can also abbreviate the build version by using only one or two integers, where missing integers in the format are interpreted as zeros.

App Store Connect Help ("Upload builds") says how the two are used when you upload: "the bundle ID and version number ... are used to associate the build with the app and version record in App Store Connect. The build string is used to uniquely identify the build throughout the system."

Here are both rules as a parser. Versions are compared as numbers, field by field:

```swift
struct AppVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// CFBundleShortVersionString: three period-separated integers, digits and periods only.
    init?(marketing text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(part) else { return nil }
            numbers.append(number)
        }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    /// CFBundleVersion: one to three integers; missing ones are zero, extra ones are ignored.
    init?(build text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Int(part) else { return nil }
            numbers.append(number)
        }
        while numbers.count < 3 { numbers.append(0) }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

for text in ["2.10.0", "2.4", "2.4.1-beta", "3.0.0.1", "1..2"] {
    print(text, "→", AppVersion(marketing: text)?.description ?? "invalid version number")
}
for text in ["418", "10.5", "3.0.0.1", "1a"] {
    print(text, "→", AppVersion(build: text)?.description ?? "invalid build string")
}

let a = AppVersion(marketing: "2.10.0")!
let b = AppVersion(marketing: "2.9.3")!
print(a > b, "2.10.0" > "2.9.3")
```

```output
2.10.0 → 2.10.0
2.4 → invalid version number
2.4.1-beta → invalid version number
3.0.0.1 → invalid version number
1..2 → invalid version number
418 → 418.0.0
10.5 → 10.5.0
3.0.0.1 → 3.0.0
1a → invalid build string
true false
```

The last line is the bug this whole section exists to prevent. As **numbers**, 2.10.0 is newer than 2.9.3. As **strings**, `"2.10.0" > "2.9.3"` is `false`, because `"1"` sorts before `"9"`. Any code that compares versions (a minimum-version check against your server, "what's new" logic, a migration that runs "for versions before 3.2") must parse first.

Two things the parser deliberately rejects: pre-release suffixes like `-beta` (fine in semantic versioning, not allowed by Apple's "only numeric characters (0-9) and periods") and a fourth component in the marketing version. Betas of an iOS app are distinguished by **build** number in TestFlight, not by a suffix.

### Build number rules

From Apple's documentation:

- "Preparing your app for distribution": "Build strings for Mac apps must increment across all versions of your app. Build strings for apps built for other platforms can start back over at 1 for new versions."
- "Build upload statuses": "If the build upload fails, you can reuse the same build number for your next upload."
- The build string identifies the build, so within one version two uploads can't share it.

That leaves a lot of freedom for iOS apps. The simplest scheme that satisfies every platform at once is a number that only goes up: CI's run number (lesson 2 used `github.run_number`), Xcode Cloud's build number (Apple: it "automatically increases with each build, starting from 1"), or a count of commits on `main`. Don't use a timestamp formatted with dots or dashes: `2026.11.04` would be read as three integers, and `20261104-1` isn't valid at all.

> [!warning] Don't let two systems number builds
> If Xcode's "Manage version and build number" option is on and CI also sets `CURRENT_PROJECT_VERSION`, the build in App Store Connect may not be the number in your CI log or git tag. Pick one owner. In automation that's CI, with the export option turned off.

## Deciding the next version

[Semantic versioning](https://semver.org) gives the version number a meaning: "Given a version number MAJOR.MINOR.PATCH, increment the MAJOR version when you make incompatible API changes, MINOR version when you add functionality in a backward compatible manner, PATCH version when you make backward compatible bug fixes." It was written for libraries, where "incompatible" has a precise meaning. For an app, teams adapt it:

- **Patch** (2.4.0 → 2.4.1): fixes only. A hotfix is always a patch.
- **Minor** (2.4.1 → 2.5.0): new features, the normal release.
- **Major** (2.5.0 → 3.0.0): something users or integrators must adapt to: dropping an iOS version, a redesign, a server API the old app can't talk to.

For the Swift packages your app depends on (Module 14), semantic versioning is the contract SwiftPM relies on when it resolves `from: "2.4.0"`; there it isn't a convention, it's how updates are chosen.

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) make the decision mechanical by putting the kind of change in the commit subject. From the spec: "fix: ... (this correlates with PATCH in Semantic Versioning)", "feat: ... (this correlates with MINOR)", and a "BREAKING CHANGE: footer, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR)." Other types (`chore`, `docs`, `test`, `refactor`) are allowed and "have no implicit effect in Semantic Versioning (unless they include a BREAKING CHANGE)."

The next version is the **largest** bump among the commits since the last release:

```swift
enum Bump: Int, Comparable {
    case none, patch, minor, major
    static func < (lhs: Bump, rhs: Bump) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Commit {
    let subject: String
    let body: String
}

/// "feat(radar)!: drop iOS 16" → ("feat", "radar", true, "drop iOS 16")
func parse(_ subject: String) -> (type: String, scope: String?, breaking: Bool, description: String)? {
    guard let colon = subject.firstIndex(of: ":") else { return nil }
    var head = String(subject[..<colon])
    let description = String(subject[subject.index(after: colon)...].drop(while: { $0 == " " }))
    var breaking = false
    if head.hasSuffix("!") {
        breaking = true
        head.removeLast()
    }
    var scope: String? = nil
    if let open = head.firstIndex(of: "("), head.hasSuffix(")") {
        scope = String(head[head.index(after: open)..<head.index(before: head.endIndex)])
        head = String(head[..<open])
    }
    guard !head.isEmpty, head.allSatisfy({ $0.isLetter }) else { return nil }
    return (head, scope, breaking, description)
}

func bump(for commits: [Commit]) -> Bump {
    var result = Bump.none
    for commit in commits {
        guard let parsed = parse(commit.subject) else { continue }
        let level: Bump
        if parsed.breaking || commit.body.contains("BREAKING CHANGE:") {
            level = .major
        } else if parsed.type == "feat" {
            level = .minor
        } else if parsed.type == "fix" {
            level = .patch
        } else {
            level = .none
        }
        result = max(result, level)
    }
    return result
}

func next(after version: (Int, Int, Int), _ bump: Bump) -> String {
    let (major, minor, patch) = version
    switch bump {
    case .major: return "\(major + 1).0.0"
    case .minor: return "\(major).\(minor + 1).0"
    case .patch: return "\(major).\(minor).\(patch + 1)"
    case .none: return "\(major).\(minor).\(patch)"
    }
}

let sinceLastTag = [
    Commit(subject: "fix(radar): stop the map from jumping on rotation", body: ""),
    Commit(subject: "chore: bump swift-format", body: ""),
    Commit(subject: "feat(alerts): severe weather notifications", body: ""),
]
let level = bump(for: sinceLastTag)
print(level, next(after: (2, 4, 1), level))

let withBreak = sinceLastTag + [Commit(subject: "refactor!: require iOS 18", body: "")]
print(bump(for: withBreak), next(after: (2, 4, 1), bump(for: withBreak)))

print(bump(for: [Commit(subject: "docs: release checklist", body: "")]))
print(parse("feat(radar)!: drop iOS 16")!)
print(parse("Fixed the radar") == nil)
```

```output
minor 2.5.0
major 3.0.0
none
(type: "feat", scope: Optional("radar"), breaking: true, description: "drop iOS 16")
true
```

Bumping a component resets the ones to its right: a minor bump from 2.4.1 is 2.5.0, not 2.5.1. A subject that doesn't follow the convention (`Fixed the radar`) doesn't parse and doesn't count, which is why teams that rely on this check commit subjects in CI. With squash merges (Module 14), the pull request title becomes the commit subject, so that's the one to check.

The tool decides the minimum; people decide the rest. A redesign with no breaking API is still a reasonable 3.0.0 for marketing reasons. What the convention prevents is the opposite mistake: shipping a breaking change as a patch.

## Changelogs

Keep a Changelog's first principle: "Changelogs are for humans, not machines." It groups entries as **Added** for new features, **Changed** for changes in existing functionality, **Deprecated**, **Removed**, **Fixed** for any bug fixes, and **Security** in case of vulnerabilities. The commit history is the raw material; the changelog is the edited version.

Generating a first draft from Conventional Commits is cheap:

```swift
func parse(_ subject: String) -> (type: String, scope: String?, breaking: Bool, description: String)? {
    guard let colon = subject.firstIndex(of: ":") else { return nil }
    var head = String(subject[..<colon])
    let description = String(subject[subject.index(after: colon)...].drop(while: { $0 == " " }))
    var breaking = false
    if head.hasSuffix("!") {
        breaking = true
        head.removeLast()
    }
    var scope: String? = nil
    if let open = head.firstIndex(of: "("), head.hasSuffix(")") {
        scope = String(head[head.index(after: open)..<head.index(before: head.endIndex)])
        head = String(head[..<open])
    }
    guard !head.isEmpty, head.allSatisfy({ $0.isLetter }) else { return nil }
    return (head, scope, breaking, description)
}

func changelog(version: String, date: String, subjects: [String]) -> String {
    var breaking: [String] = []
    var added: [String] = []
    var fixed: [String] = []
    for subject in subjects {
        guard let commit = parse(subject) else { continue }
        let line = commit.scope.map { "**\($0):** \(commit.description)" } ?? commit.description
        if commit.breaking {
            breaking.append(line)
        } else if commit.type == "feat" {
            added.append(line)
        } else if commit.type == "fix" {
            fixed.append(line)
        }
        // chore, docs, test, refactor without "!": not for users
    }
    var text = "## [\(version)] - \(date)\n"
    for (title, lines) in [("Changed (breaking)", breaking), ("Added", added), ("Fixed", fixed)] where !lines.isEmpty {
        text += "\n### \(title)\n"
        for line in lines {
            text += "- \(line)\n"
        }
    }
    return text
}

let subjects = [
    "feat(alerts): severe weather notifications",
    "fix(radar): stop the map from jumping on rotation",
    "chore: bump swift-format",
    "fix: wrong unit in the hourly chart",
    "Merge pull request #212 from weather/alerts",
    "feat!: require iOS 18",
]
print(changelog(version: "3.0.0", date: "2026-11-04", subjects: subjects), terminator: "")
```

```output
## [3.0.0] - 2026-11-04

### Changed (breaking)
- require iOS 18

### Added
- **alerts:** severe weather notifications

### Fixed
- **radar:** stop the map from jumping on rotation
- wrong unit in the hourly chart
```

The merge commit and the chore are dropped: users don't care. Then a person edits. "stop the map from jumping on rotation" is a developer's description; the App Store's **What's New** text needs the user's view ("The radar map no longer jumps when you rotate your phone"). The App Review Guidelines (2.3.12) require it: "Apps must clearly describe new features and product changes in their 'What's New' text. Simple bug fixes, security updates, and performance improvements may rely on a generic description, but more significant changes must be listed in the notes." App Store Connect Help limits What's New to 4000 characters and requires it for every version after the first.

## Release branches and tags

Module 14 used short-lived feature branches merged into `main`. Releases add two things:

- A **tag** on the exact commit that was archived. Without it, "which code is in 2.5.0 (build 7342)?" has no reliable answer, and you can't symbolicate or reproduce.
- Optionally, a **release branch** cut from `main` when the release is feature-complete, so `main` keeps moving while the release is tested in TestFlight and reviewed.

```bash
# Feature-complete: cut the release branch from main.
git switch main
git pull
git switch -c release/2.5

# TestFlight finds a bug: fix it on the release branch, through a pull request as usual.
# ...then bring the fix back to main so the next release has it too.
git switch main
git merge release/2.5

# The build that passed review: tag the commit it was built from and push the tag.
git switch release/2.5
git tag -a v2.5.0 -m "Weather 2.5.0 (build 7342)"
git push origin v2.5.0
```

Annotated tags (`-a`) record who tagged and when, and the message is a natural place for the build number. Pushing a `v*` tag is also what started lesson 2's release workflow, so "tag" and "build for the App Store" become the same action.

Release branches cost a merge back for every fix. Small teams that release from `main` (tag the commit, build, ship) and fix forward are making a legitimate choice. What matters is that every shipped build maps to one commit.

## Phased release

Release management doesn't end at "Ready for Distribution." App Store Connect Help ("Release a version update in phases") describes the App Store's own gradual rollout, for version updates (not a first release):

> Selecting this option will release your app's update gradually over 7 days. A random sample of users with automatic updates on eligible devices will receive the update, without any notification of their participation in the phased release.

| Day | Percentage of users |
| --- | --- |
| 1 | 1% |
| 2 | 2% |
| 3 | 5% |
| 4 | 10% |
| 5 | 20% |
| 6 | 50% |
| 7 | 100% |

What it gives you and what it doesn't, from the same page:

- You can **pause** "for up to 30 days, with no limit on the number of pauses," and resuming "will pick up on the day it was left off."
- You can **release to all users** at any time.
- It only applies to automatic updates: "apps and app updates in phased release can be manually downloaded from the App Store by anyone at any time."
- It's not a rollback. Pausing stops new automatic updates; everyone who already has the version keeps it. Lesson 6 covers what you can do then.

Phased release is coarse: it controls who gets the **binary**, on Apple's schedule, by random sample. For finer control you need the code to decide.

## Feature flags

A **feature flag** separates shipping code from turning it on. The radar redesign ships in 2.5.0, switched off; a remote configuration (your server, or a service) turns it on for 1% of users, then 10%, then everyone, and can turn it off again in minutes without a new build. That last property is why lesson 6 calls flags your real rollback mechanism.

Percentage rollout needs each user to land in a **stable bucket**: the same user must get the same answer every launch, on every device, and raising the percentage from 10 to 50 must keep the first 10% enabled. That calls for a hash of the user ID that never changes.

Swift's `hashValue` is the wrong tool. Swift seeds its hashing randomly for each process, so `"u-1001".hashValue` is different every time the app launches. A user would bounce in and out of the rollout. Use a fixed, documented algorithm. **FNV-1a** is about the simplest: start from a constant (the offset basis), and for each byte, XOR it in and multiply by a prime, letting the multiplication wrap (`&*`):

```swift
/// 64-bit FNV-1a over the UTF-8 bytes. Same input, same output, on every device and every launch.
func fnv1a(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325        // offset basis
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3        // FNV prime, wrapping multiply
    }
    return hash
}

/// A stable bucket from 0 to 99 for this user and this flag.
func bucket(flag: String, userID: String) -> Int {
    Int(fnv1a("\(flag):\(userID)") % 100)
}

func isEnabled(flag: String, userID: String, rolloutPercent: Int) -> Bool {
    bucket(flag: flag, userID: userID) < rolloutPercent
}

print(String(fnv1a("a"), radix: 16))    // published test vector: af63dc4c8601ec8c

let users = ["u-1001", "u-1002", "u-1003", "u-1004", "u-1005", "u-1006"]
for user in users {
    let b = bucket(flag: "radar-v2", userID: user)
    let at10 = isEnabled(flag: "radar-v2", userID: user, rolloutPercent: 10)
    let at50 = isEnabled(flag: "radar-v2", userID: user, rolloutPercent: 50)
    print(user, b, at10, at50)
}
print(bucket(flag: "radar-v2", userID: "u-1001"), bucket(flag: "alerts", userID: "u-1001"))

var enabledAt = [0, 0, 0, 0]
let percents = [1, 10, 50, 100]
for n in 0..<10_000 {
    let b = bucket(flag: "radar-v2", userID: "u-\(n)")
    for (i, p) in percents.enumerated() where b < p { enabledAt[i] += 1 }
}
print(enabledAt)
```

```output
af63dc4c8601ec8c
u-1001 36 false true
u-1002 69 false false
u-1003 58 false false
u-1004 3 true true
u-1005 92 false false
u-1006 25 false true
36 32
[97, 1015, 5051, 10000]
```

What it shows:

- The first line matches FNV-1a's published 64-bit test vector for `"a"`, so the constants are right.
- **Monotonic rollout.** `u-1004` (bucket 3) is in at 10% and still in at 50%. Anyone enabled at a lower percentage stays enabled at a higher one, because the test is `bucket < percent`.
- **Per-flag buckets.** The flag name is part of the hashed text, so `u-1001` is in bucket 36 for `radar-v2` and 32 for `alerts`. Without that, the same 10% of users would be the guinea pigs for every experiment.
- **Close to uniform.** Over 10,000 synthetic IDs, 1% enables 97 users, 10% enables 1,015 and 50% enables 5,051.

Hash a stable identifier: an account ID, or a random install ID you generate once and store. Never hash personal data such as an email address into a request to a third-party flag service; lesson 4 explains why.

### Flags and App Review

Flags meet two rules in the App Review Guidelines:

- **2.3.1(a)**: "All new features, functionality, and product changes must be described with specificity in the Notes for Review section of App Store Connect (generic descriptions will be rejected) and accessible for review."
- **2.5.19**: "Don't include any hidden, dormant, or undocumented features in your app; your app's functionality should be clear to end users and App Review."

So a flag is for **rolling out** a feature that review has seen, not for hiding one from review. If 2.5.0 contains the radar redesign behind a flag, say so in the review notes and tell the reviewer how to see it (a demo account where it's on, for example). Flags that switch between two reviewed experiences, or that switch off a broken feature, are the normal use.

Flags have a cost: every one doubles the paths through that code. Give each flag an owner and a removal date, and delete it once the rollout reaches 100%.

## Common mistakes

> [!error] Comparing versions as strings
> `"2.10.0" > "2.9.3"` is `false`. Parse into integers and compare field by field; the same goes for minimum-version checks on your server.

> [!error] A suffix or a date in the version
> `2.5.0-beta` and `2026.11.04-1` aren't valid: Apple allows only digits and periods. Betas are distinguished by build number in TestFlight.

> [!error] Using hashValue for rollout buckets
> Swift's hashing is seeded per process, so buckets change every launch. Use FNV-1a (or another fixed algorithm) over UTF-8 bytes of flag plus user ID.

> [!error] Hiding a feature from App Review with a flag
> Guidelines 2.3.1(a) and 2.5.19 require new features to be described and accessible for review, and forbid hidden or dormant features. Describe flagged features in the review notes.

> [!error] No tag on the shipped commit
> Without it you can't say which code a crash came from or rebuild that version. Tag the commit you archived, with the build number in the message.

## Exercises

````exercise
id: m41-l03-e1
type: prediction
prompt: "What does this program print?"
code: |
  func parts(_ version: String) -> [Int] {
      var numbers: [Int] = []
      for part in version.split(separator: ".") {
          numbers.append(Int(part) ?? -1)
      }
      while numbers.count < 3 { numbers.append(0) }
      return numbers
  }

  func isNewer(_ a: String, than b: String) -> Bool {
      parts(a).lexicographicallyPrecedes(parts(b)) == false && parts(a) != parts(b)
  }

  print(isNewer("2.10.0", than: "2.9.3"))
  print("2.10.0" > "2.9.3")
  print(isNewer("3.0", than: "3.0.0"))
  print(parts("10.5"), parts("2.4.1-beta"))
  print(["2.9.3", "2.10.0", "2.1.12"].sorted())
output: |
  true
  false
  false
  [10, 5, 0] [2, 4, -1]
  ["2.1.12", "2.10.0", "2.9.3"]
hints:
  - "lexicographicallyPrecedes compares arrays element by element, numerically for Int."
  - "Int(\"1-beta\") is nil."
  - "sorted() on strings sorts them as text."
solution: |
  ```output
  true
  false
  false
  [10, 5, 0] [2, 4, -1]
  ["2.1.12", "2.10.0", "2.9.3"]
  ```

  1. `[2, 10, 0]` vs `[2, 9, 3]`: 10 > 9, so 2.10.0 is newer.
  2. As text, `"2.1..."` sorts before `"2.9..."`, so the string comparison says the opposite.
  3. `"3.0"` pads to `[3, 0, 0]`, the same as `3.0.0`: not newer. That's Apple's rule for build strings (missing integers are zero).
  4. `"10.5"` pads to `[10, 5, 0]`. In `"2.4.1-beta"`, `Int("1-beta")` is `nil`, so this sloppy parser records `-1` instead of rejecting the string. The lesson's parser returns `nil` for the whole version, which is safer.
  5. Sorting version strings as text puts 2.10.0 between 2.1.12 and 2.9.3. A "latest version" picked with `.sorted().last` would be 2.9.3, which is wrong.
````

````exercise
id: m41-l03-e2
type: comprehension
prompt: "Commits since 4.2.3, squash-merged: `fix(sync): retry on 503`, `docs: update README`, `feat(widgets): lock screen widget`, `refactor(storage)!: move to SwiftData, old caches are deleted`. What's the next version?"
choices:
  - text: "5.0.0"
    correct: true
    why: "The ! after refactor(storage) marks a breaking change, which is a major bump. Minor and patch reset to 0."
  - text: "4.3.0"
    correct: false
    why: "That would be right without the breaking refactor. The largest bump wins."
  - text: "4.3.1"
    correct: false
    why: "Bumping minor resets patch to 0, and the breaking change makes it a major bump anyway."
  - text: "4.2.4"
    correct: false
    why: "fix alone would give a patch, but the other commits require more."
solution: |
  **5.0.0.** The largest bump among the commits decides: `fix` is a patch, `docs` nothing, `feat` a minor, and `refactor(storage)!` a major because of the `!`. Conventional Commits: a `!` after the type/scope "introduces a breaking API change (correlating with MAJOR in Semantic Versioning)." Bumping major resets minor and patch.

  For an app you could argue that deleting a local cache isn't "breaking" for users. That's a judgment call for the team, but then the commit shouldn't carry a `!`; the convention only works if the markers are honest.
````

````exercise
id: m41-l03-e3
type: fill-in
prompt: "Complete the Info.plist reference: the user-visible version key, the build key, and what a missing integer in a build string counts as."
code: |
  [[1]]: three period-separated integers, e.g. 2.5.0 (MARKETING_VERSION)
  [[2]]: one to three integers, e.g. 7342 (CURRENT_PROJECT_VERSION)
  "10.5" as a build string means 10.5.[[3]]
blanks:
  - id: "1"
    answers: ["CFBundleShortVersionString"]
  - id: "2"
    answers: ["CFBundleVersion"]
  - id: "3"
    answers: ["0"]
solution: |
  - `CFBundleShortVersionString` is the version the App Store shows. Apple: "The required format is three period-separated integers."
  - `CFBundleVersion` is the build string. "One to three period-separated integers"; App Store Connect uses it to "uniquely identify the build throughout the system."
  - "Missing integers in the format are interpreted as zeros. For example, 0 specifies 0.0.0, 10 specifies 10.0.0, and 10.5 specifies 10.5.0."
````

````exercise
id: m41-l03-e4
type: find-errors
prompt: "A teammate's feature-flag code for rolling out a new onboarding flow to 20% of users. Mark every real problem."
code: |
  func isNewOnboardingEnabled(email: String, percent: Int) -> Bool {
      let bucket = abs(email.hashValue) % 100
      return bucket <= percent
  }

  // Sent to the third-party flag service on every launch:
  // { "user": "ana@example.com", "flag": "onboarding-v2" }
choices:
  - text: "hashValue is seeded randomly per process, so the same user gets a different bucket on every launch."
    correct: true
  - text: "bucket <= percent enables 21 buckets (0 through 20) at 20%, and bucket 0 is enabled even at 0%."
    correct: true
  - text: "The flag name isn't part of the hash, so every flag would pick the same users."
    correct: true
  - text: "The email address is personal data sent to a third party just to bucket users; a stable random install or account ID would do."
    correct: true
  - text: "abs(Int.min) traps, so this can crash in the rare case hashValue is Int.min."
    correct: true
  - text: "% 100 can never produce buckets above 99."
    correct: false
    why: "That's true, and it's fine: it's the point of using 100 buckets."
rubric:
  - I flagged hashValue's per-process seeding.
  - I flagged the off-by-one comparison.
  - I flagged the missing flag name in the hashed text.
  - I flagged the email being sent to a third party.
  - I noticed abs can trap on Int.min.
solution: |
  Five problems:

  1. **`hashValue`** changes every launch (Swift seeds hashing per process), so the user flips in and out of the rollout. Use FNV-1a over UTF-8 bytes.
  2. **`<=`** makes 20% mean 21 buckets, and 0% still enables bucket 0. Use `<`.
  3. **No flag name in the hash.** Hash `"onboarding-v2:\(id)"` so each flag gets an independent sample.
  4. **The email goes to a third party.** It identifies a person; the flag service only needs a stable opaque ID. This also has to be declared in App Store privacy details if it's collected (lesson 4).
  5. **`abs(Int.min)`** overflows and traps. Unlikely, but a crash in a flag check takes the whole feature with it. An unsigned hash with `% 100` avoids the question.

  `% 100` giving 0 to 99 is correct.
````

````exercise
id: m41-l03-e5
type: solve
prompt: |
  Write `check(_:platform:accepted:)`, which says whether App Store Connect would accept an upload's build string, using Apple's documented rules: a build string is one to three integers (missing ones are zero, extras ignored); for iOS, the build string must be unique within its version; for macOS it must be higher than every previously accepted build, across all versions. Treat `"1"` and `"1.0"` as the same build string, since missing integers are zero.

  ```swift
  let accepted = [
      Upload(version: "2.4.0", build: "1"),
      Upload(version: "2.4.0", build: "2"),
      Upload(version: "2.5.0", build: "1"),
  ]
  print(check(Upload(version: "2.5.0", build: "2"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.5.0", build: "1.0"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "1"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "1"), platform: .macOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "3"), platform: .macOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "3b"), platform: .iOS, accepted: accepted))
  ```

  Expected output:

  ```output
  accepted
  rejected: 2.5.0 (1.0) already exists
  accepted
  rejected: 1 isn't higher than 1
  accepted
  rejected: 3b isn't a valid build string
  ```
starter: |
  enum Platform {
      case iOS, macOS
  }

  struct Upload {
      let version: String
      let build: String
  }

  func check(_ upload: Upload, platform: Platform, accepted: [Upload]) -> String {
      // your code
      return "accepted"
  }
hints:
  - "Write a helper that turns a build string into exactly three Ints, or nil if it's invalid."
  - "[Int] arrays compare with == and lexicographicallyPrecedes."
  - "For macOS, compare against every accepted upload, not just the same version."
rubric:
  - Rejects build strings with anything other than digits and periods, or empty components.
  - Pads to three components and ignores extras, so 1 and 1.0 are equal.
  - Applies uniqueness within the version for iOS and strictly increasing across versions for macOS.
  - Prints the six expected lines.
solution: |
  ```swift
  enum Platform {
      case iOS, macOS
  }

  struct Upload {
      let version: String
      let build: String
  }

  /// "418" → [418, 0, 0]; "10.5" → [10, 5, 0]; extra components are ignored.
  func buildComponents(_ build: String) -> [Int]? {
      var numbers: [Int] = []
      for part in build.split(separator: ".", omittingEmptySubsequences: false) {
          guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(part) else { return nil }
          numbers.append(n)
      }
      guard !numbers.isEmpty else { return nil }
      while numbers.count < 3 { numbers.append(0) }
      return Array(numbers.prefix(3))
  }

  func check(_ upload: Upload, platform: Platform, accepted: [Upload]) -> String {
      guard let new = buildComponents(upload.build) else { return "rejected: \(upload.build) isn't a valid build string" }
      switch platform {
      case .iOS:
          for previous in accepted where previous.version == upload.version {
              if buildComponents(previous.build) == new {
                  return "rejected: \(upload.version) (\(upload.build)) already exists"
              }
          }
      case .macOS:
          for previous in accepted {
              if let old = buildComponents(previous.build), !old.lexicographicallyPrecedes(new) {
                  return "rejected: \(upload.build) isn't higher than \(previous.build)"
              }
          }
      }
      return "accepted"
  }

  let accepted = [
      Upload(version: "2.4.0", build: "1"),
      Upload(version: "2.4.0", build: "2"),
      Upload(version: "2.5.0", build: "1"),
  ]
  print(check(Upload(version: "2.5.0", build: "2"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.5.0", build: "1.0"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "1"), platform: .iOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "1"), platform: .macOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "3"), platform: .macOS, accepted: accepted))
  print(check(Upload(version: "2.6.0", build: "3b"), platform: .iOS, accepted: accepted))
  ```

  ```output
  accepted
  rejected: 2.5.0 (1.0) already exists
  accepted
  rejected: 1 isn't higher than 1
  accepted
  rejected: 3b isn't a valid build string
  ```

  Line 3 is the iOS rule Apple states: build strings "can start back over at 1 for new versions." Line 4 is the Mac rule: they "must increment across all versions." Line 2 follows from "missing integers ... are interpreted as zeros"; whether App Store Connect reports that exact case as a duplicate wasn't tested for this lesson. Uploads whose processing failed aren't in `accepted`, matching Apple's note that a failed upload's build number can be reused.

  A single increasing counter, such as CI's run number, passes both rules without any of this logic.
````

````exercise
id: m41-l03-e6
type: design
prompt: "Your team ships every two weeks from `main`. The next release contains a rewritten checkout flow (risky, revenue-critical), three small features and a dozen fixes. Design the release: versioning, branching and tagging, build numbers, changelog and What's New, phased release, and how the checkout rewrite is rolled out and protected. Mention what App Review needs to know."
rubric:
  - Picks a version from the commits (a minor bump unless something is breaking) and a single owner for build numbers.
  - Cuts a release branch or tags main, merges fixes back, and tags the archived commit.
  - Produces a changelog draft from commits and a user-facing What's New.
  - Puts the checkout rewrite behind a flag with deterministic percentage rollout and a kill switch, independent of phased release.
  - Uses phased release, with a plan for pausing, and notes it can't roll back or stop manual downloads.
  - Describes the flagged checkout in the review notes and gives the reviewer a way to see it.
solution: |
  One reasonable plan:

  - **Version.** The commits contain `feat`s and `fix`es and nothing breaking: 2.5.0 → **2.6.0**. Build numbers come only from CI's run number; Xcode's "Manage version and build number" is off.
  - **Branching.** Cut `release/2.6` from `main` when the release is feature-complete. TestFlight fixes land on the release branch through pull requests and are merged back to `main` the same day. The commit that's archived for submission gets an annotated tag `v2.6.0` with the build number; that tag starts the release workflow.
  - **Changelog.** Generate the draft from Conventional Commits (Added, Fixed); edit it into a What's New that names the user-visible changes. Per guideline 2.3.12, the checkout change is significant, so it's listed specifically.
  - **Checkout.** The rewrite ships behind `checkout-v2`, off by default, with buckets from FNV-1a over `"checkout-v2:\(accountID)"`. Roll out 1% → 5% → 25% → 100% over a week or two, watching conversion and error rates for each step. The old flow stays in the binary until v2 has been at 100% for a full release; then the flag and the old code are deleted. Turning the flag off is the rollback.
  - **Phased release** on for the binary, independently of the flag: it limits exposure to anything else in 2.6.0. If crash rates jump on day 2, pause it (up to 30 days total). It doesn't affect people who update manually and doesn't take anything back, which is why the risky part also has a flag.
  - **App Review.** The review notes describe the new checkout and how to see it (a demo account for which the flag is forced on), per 2.3.1(a), since 2.5.19 forbids hidden or dormant features.
````

## Summary

- `CFBundleShortVersionString` is the user-visible version: three integers, digits and periods only. `CFBundleVersion` is the build string: one to three integers, missing ones zero, and it identifies the build in App Store Connect.
- Compare versions numerically. iOS build strings must be unique within a version and may restart at 1; Mac build strings must increase across versions. One increasing counter owned by CI satisfies both.
- Semantic versioning plus Conventional Commits makes the next version mechanical: the largest bump wins. Generate a changelog draft from the same commits, then write What's New for people.
- Tag the commit you archived; use a release branch when `main` must keep moving during testing and review.
- Phased release spreads an update over 7 days (1% to 100%), can pause for up to 30 days, and can't stop manual downloads or take a release back.
- Feature flags decide at runtime whether shipped code is on. Bucket users with a fixed hash such as FNV-1a, never `hashValue`, and describe flagged features to App Review.
