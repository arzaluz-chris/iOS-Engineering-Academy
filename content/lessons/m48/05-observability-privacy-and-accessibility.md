---
id: m48-l05
title: Observability, privacy and accessibility in design
description: "The part of a design answer that separates a demo from something you'd ship: how you'll know it works in the field, how you'll turn it off when it doesn't, what data you refuse to collect, and how people using VoiceOver or large text get the same app. You choose metrics, logs and a crash reporter for a design, evaluate feature flags and kill switches with stable bucketing, sanitize telemetry against a schema, and write accessibility into the requirements and the API. The flag, bucketing and sanitizing logic is plain Swift, compiled and run."
module: m48
order: 5
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l04, m41-l04, m42-l05, m43-l04]
objectives:
  - Choose the few metrics that tell you a design works in the field, and say where each is measured.
  - Decide between MetricKit and a third-party crash reporter for a given app, with the trade-offs.
  - Design feature flags and kill switches with safe defaults, cached values, an evaluation order and stable percentage rollouts.
  - Apply data minimization to telemetry with a per-event schema and coarsened values.
  - Write accessibility as requirements that change the API, the layouts and the tests.
terms:
  - term: Kill switch
    definition: A remotely controlled flag that turns off a feature or code path that's already shipped, without an app update. It only works for code that was built to check it.
  - term: Stable bucketing
    definition: "Assigning each user a fixed number from 0 to 99 per flag, computed from a deterministic hash of the flag name and user ID, so the same person stays in or out of a rollout across launches and devices."
  - term: Data minimization
    definition: "Collecting only the data a stated purpose needs, at the coarsest precision that serves it, and keeping it only as long as needed."
  - term: Telemetry schema
    definition: The list of events the app may send and, for each one, the properties allowed. Anything not in the schema is dropped on the device before it's sent.
  - term: Accessibility requirement
    definition: "A non-functional requirement stated like any other, for example \"every action is reachable with VoiceOver and Voice Control\" or \"layouts work at the largest accessibility text size\", with tests that check it."
mastery:
  - List four to six field metrics for a design and the decision each one informs.
  - Trace a flag's evaluation for a given user, version and configuration.
  - Explain why Swift's hashValue can't be used for rollouts.
  - Strip a telemetry event down to its schema and coarsen sensitive values.
  - Name the API and layout changes that accessibility requirements cause in a feed design.
resources: [metrickit, os-logger, os-oslogprivacy, privacy-manifest-files, app-privacy-details, swiftui-accessibility-fundamentals, accessibility-performing-audits, app-review-guidelines]
cards:
  - id: m48-l05-c1
    front: What should a design's field metrics answer?
    back: "Whether the requirements hold for real people: time to first content, error and failure rates of the key flows (feed load, sync), sync lag and outbox depth, hangs and crashes, and any budget you stated (memory, data). Each metric should map to a decision."
  - id: m48-l05-c2
    front: Why can't a rollout use Swift's hashValue?
    back: "Swift seeds hashing per process, so hashValue changes between launches: a user would flip in and out of the rollout. Use a fixed algorithm (for example FNV-1a) over the flag name and user ID."
  - id: m48-l05-c3
    front: In what order should a flag be evaluated?
    back: "No remote config: the default compiled into the app (or the last cached value). Then kill switch (off), minimum app version (off if older), explicit allowlist (on), then the percentage bucket."
  - id: m48-l05-c4
    front: What does Logger do with interpolated strings by default?
    back: "Apple: \"the system redacts the value of that string or object by default.\" Mark values .public only when they aren't sensitive; use a hash option to correlate messages without revealing the value."
  - id: m48-l05-c5
    front: How do accessibility requirements change a feed's API?
    back: "Images need alt text in the payload (or a flag that they're decorative), actions need names that work as VoiceOver and Voice Control labels, and text can't be baked into images. Layouts must reflow at accessibility text sizes."
---

## The idea in one sentence

**A design isn't finished until you can see it working in the field, switch parts of it off, defend every piece of data it collects, and use it without seeing the screen**, and each of those changes the design itself, not just the release checklist.

> [!note] What was checked
> `Logger` and `OSLogPrivacy` behavior is quoted from Apple's reference pages, and MetricKit's delivery schedule from its framework page, read in November 2026. The App Review guidelines cited are 2.5.19 and 5.1.1(v), as numbered in November 2026. Module 41 covers MetricKit and crash reporting in depth, Module 42 data leakage and privacy manifests, and Module 43 accessibility audits. The flag, bucketing, sanitizing and label code is plain Swift, compiled and run with Swift 6.3.

## Observability: decide what you'll look at

In an interview, "I'd add analytics" earns nothing. Name the handful of signals that tell you the requirements hold, and what you'd do when one moves. For Mise:

| Requirement (lesson 1) | Metric | Where it's measured | When it moves, you… |
| --- | --- | --- | --- |
| Feed visible within a second, even offline | Time to first content, p50 and p90, split by cached vs fresh | A signpost-backed timer in the app, sent as an event | Look at what changed in the launch path |
| The list syncs within a minute | Sync lag (edit to server acknowledgment); outbox depth at launch | Sync engine events | Check failure reasons; look for a stuck operation |
| Sync works | Sync outcomes by reason (success, offline, conflict, permanent failure) | Sync engine events | A spike in permanent failures is usually an API change |
| Smooth scrolling, within memory | Hang rate, memory at termination, scroll hitches | MetricKit (daily metrics, immediate diagnostics) | Profile the feed with Instruments |
| Stability | Crash-free sessions; top crash signatures | MetricKit diagnostics or a crash reporter | Fix, or flip a kill switch |
| Images cost what we estimated | Bytes downloaded per session; cache hit rate | Pipeline counters | Revisit sizes and prefetch window |

Three choices to make out loud:

- **Logs for engineers, events for dashboards.** `Logger` writes to the unified logging system for debugging on a device you have; it isn't a pipeline to your servers. Telemetry events are what you aggregate. Module 41 covers both.
- **MetricKit or a third-party crash reporter.** MetricKit needs no SDK, and Apple says it "delivers metric reports about the previous 24 hours to your app at most once per day," with diagnostic reports arriving immediately on iOS 15 and later. A third-party reporter adds grouping, alerting and breadcrumbs, at the cost of an SDK running in your process, its own privacy manifest, and data leaving through someone else's servers. A small team often starts with MetricKit plus its own event pipeline; a large app with an on-call rotation usually wants the reporter. Either answer is fine with a reason.
- **Sample what's expensive.** Every launch timer from every user is more than you need; 10% of sessions, chosen by stable bucketing (below), gives the same percentiles with a tenth of the traffic.

## Feature flags and kill switches

A flag in a mobile app has a constraint the web doesn't: **the code must already be on the device**. A kill switch can turn off the new shopping-list sync only if the app shipped with a check for it and a working fallback. So the design includes:

- **Defaults compiled into the app**, used before the configuration arrives and if it never does.
- **The last fetched configuration cached on disk**, so a launch without network behaves like the previous one.
- **A fetch with a short timeout** at launch, applied on the next relevant screen rather than changing a screen the person is looking at.
- **An evaluation order** that puts safety first: kill switch, then minimum app version, then explicit allowlists (the team, testers), then a percentage rollout.
- **Removal.** Every flag has an owner and a date to delete it; old flags are dead branches nobody tests.

App Review guideline 2.5.19 says: "Don't include any hidden, dormant, or undocumented features in your app." Flags are for gradual rollout and safety, not for switching on things App Review never saw.

### Stable bucketing

A 10% rollout must pick the same 10% every launch. Swift's `hashValue` can't do that: Swift seeds its hashing per process, so the value changes every time the app runs. Use a fixed algorithm instead. FNV-1a is short enough to write from memory:

```swift
/// 64-bit FNV-1a over the UTF-8 bytes. Same input, same output, on every platform and every launch.
func fnv1a(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

/// 0...99 for this user and flag. Salting with the flag name gives each flag its own 10%.
func bucket(user: String, flag: String) -> Int {
    Int(fnv1a("\(flag):\(user)") % 100)
}

for user in ["user-1", "user-2", "user-3"] {
    print(user, bucket(user: user, flag: "list-sync-v2"), bucket(user: user, flag: "new-feed"))
}

var inRollout = 0
for n in 0..<10_000 where bucket(user: "user-\(n)", flag: "list-sync-v2") < 10 {
    inRollout += 1
}
print("10% rollout over 10,000 users: \(inRollout)")
```

```output
user-1 29 31
user-2 96 42
user-3 7 53
10% rollout over 10,000 users: 998
```

- **The numbers are the same on every run and every machine**, which is the whole point. (`&*` is multiplication that wraps on overflow, which FNV relies on.)
- **The same user lands in different buckets for different flags** because the flag name is part of the input. Without the salt, the same people would be first in line for every experiment.
- **998 of 10,000 users are in the 10% rollout**: close to 10%, not exactly, which is what a hash gives you. Dashboards should compare the rollout group with the rest by rate, not by raw counts. Use the server's user ID, or a random install ID stored in the Keychain for signed-out users, never something personal like an email.

### Evaluating a flag

```swift
struct Version: Comparable {
    let parts: [Int]

    init(_ text: String) {
        parts = text.split(separator: ".").map { Int($0) ?? 0 }
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let l = index < lhs.parts.count ? lhs.parts[index] : 0
            let r = index < rhs.parts.count ? rhs.parts[index] : 0
            if l != r { return l < r }
        }
        return false
    }
}

struct FlagRule {
    var killed = false
    var minimumVersion: Version? = nil
    var allowlist: Set<String> = []
    var rolloutPercent = 0
}

func evaluate(rule: FlagRule?, defaultValue: Bool, user: String, bucket: Int, appVersion: Version) -> String {
    guard let rule else { return "\(defaultValue) (no config: compiled default)" }
    if rule.killed { return "false (kill switch)" }
    if let minimum = rule.minimumVersion, appVersion < minimum { return "false (app older than minimum)" }
    if rule.allowlist.contains(user) { return "true (allowlist)" }
    return bucket < rule.rolloutPercent
        ? "true (bucket \(bucket) < \(rule.rolloutPercent)%)"
        : "false (bucket \(bucket) ≥ \(rule.rolloutPercent)%)"
}

let rollout = FlagRule(minimumVersion: Version("4.2"), allowlist: ["qa-ana"], rolloutPercent: 10)
let killed = FlagRule(killed: true, allowlist: ["qa-ana"], rolloutPercent: 100)

print(evaluate(rule: nil, defaultValue: false, user: "u1", bucket: 3, appVersion: Version("4.3")))
print(evaluate(rule: rollout, defaultValue: false, user: "u1", bucket: 3, appVersion: Version("4.3")))
print(evaluate(rule: rollout, defaultValue: false, user: "u2", bucket: 42, appVersion: Version("4.3")))
print(evaluate(rule: rollout, defaultValue: false, user: "u1", bucket: 3, appVersion: Version("4.1.9")))
print(evaluate(rule: rollout, defaultValue: false, user: "qa-ana", bucket: 80, appVersion: Version("4.2.0")))
print(evaluate(rule: killed, defaultValue: false, user: "qa-ana", bucket: 0, appVersion: Version("5.0")))
```

```output
false (no config: compiled default)
true (bucket 3 < 10%)
false (bucket 42 ≥ 10%)
false (app older than minimum)
true (allowlist)
false (kill switch)
```

- **The kill switch beats the allowlist**: when something is on fire, testers don't get an exception.
- **The minimum version** protects old builds that shipped with a buggy version of the code path: they stay off even if their bucket qualifies.
- **`4.2.0` equals `4.2`**, because missing parts compare as zero. Comparing version strings as text gets "4.10" < "4.9" wrong.
- **The reason string** is worth logging (not sending with every event): "why is this on for me?" is the first question in every flag incident.

## Privacy: collect less, coarsen the rest

Data minimization is a design decision you can state per field: what you collect, why, at what precision, for how long. For Mise:

| Data | Purpose | Decision |
| --- | --- | --- |
| Account email | Sign-in, household invites | Collected; never in logs or events |
| Saved recipes, shopping list | The product | Synced; deleted with the account (guideline 5.1.1(v): "If your app supports account creation, you must also offer account deletion within the app") |
| Location | None in the requirements | Not collected; the API doesn't accept it |
| Search text | Improving search | Not sent as an event; count of results only |
| Device model, OS version, app version | Debugging, flag minimums | Sent with events |
| Precise timings | Performance | Rounded into buckets in events; exact values only in sampled timers |

Logs need the same discipline. `Logger` helps by default: Apple's documentation says that for interpolated strings and objects "the system redacts the value of that string or object by default," and you opt values in with `privacy: .public`. A hash option lets you correlate messages that mention the same value without revealing it.

For events, enforce the schema on the device, so a careless call site can't leak a property:

```swift
let schema: [String: Set<String>] = [
    "recipe_opened": ["recipe_id", "source"],
    "search_performed": ["result_count"],
    "sync_finished": ["outcome", "duration", "pending"],
]

/// Rounds a duration in milliseconds into a coarse bucket.
func durationBucket(_ milliseconds: Int) -> String {
    switch milliseconds {
    case ..<1_000: return "<1s"
    case ..<5_000: return "1-5s"
    case ..<30_000: return "5-30s"
    default: return ">30s"
    }
}

/// Drops events and properties outside the schema, and coarsens values that don't need precision.
func sanitize(_ name: String, _ properties: [String: String]) -> String {
    guard let allowed = schema[name] else { return "\(name): dropped (not in schema)" }
    var kept: [String: String] = [:]
    for (key, value) in properties where allowed.contains(key) {
        if key == "duration", let milliseconds = Int(value) {
            kept[key] = durationBucket(milliseconds)
        } else {
            kept[key] = value
        }
    }
    let removed = Set(properties.keys).subtracting(allowed).sorted()
    let body = kept.keys.sorted().map { "\($0)=\(kept[$0]!)" }.joined(separator: " ")
    return "\(name): \(body)" + (removed.isEmpty ? "" : "  (removed \(removed))")
}

print(sanitize("recipe_opened", ["recipe_id": "r42", "source": "feed", "title": "Grandma's lasagna"]))
print(sanitize("search_performed", ["query": "gluten free bread", "result_count": "12"]))
print(sanitize("sync_finished", ["outcome": "success", "duration": "2350", "pending": "0", "email": "ana@example.com"]))
print(sanitize("location_seen", ["lat": "40.4168", "lon": "-3.7038"]))
```

```output
recipe_opened: recipe_id=r42 source=feed  (removed ["title"])
search_performed: result_count=12  (removed ["query"])
sync_finished: duration=1-5s outcome=success pending=0  (removed ["email"])
location_seen: dropped (not in schema)
```

- **The schema is an allowlist.** A property added at a call site without a schema change never leaves the device. In debug builds you'd make that a test failure or an assertion, so the developer notices; in release it's silently dropped.
- **Search text and titles are personal** even when nobody intends them to be: people type names and health conditions into search boxes.
- **Coarsening keeps the purpose and drops the detail.** "1-5s" answers "is sync slow?" as well as "2,350 ms" does.
- **The schema feeds the declarations.** The same list is what you describe in the App Store's privacy details and, for collected data types, in the privacy manifest (Modules 41 and 42).

## Accessibility is a requirement, so it changes the design

Put accessibility on the non-functional list in phase 1 (lesson 1 did: "usable with VoiceOver and the largest text sizes"), then follow it into every layer:

- **API.** Photos need alt text in the payload, or an explicit "decorative" flag; the client can't invent a description. Recipe steps must be text, not text baked into images. Ingredient quantities should be structured (number and unit) so VoiceOver reads "200 grams", not "200g".
- **Layout.** At accessibility text sizes, a row with a thumbnail beside two lines of text has to stack vertically. Designs with fixed-height cells break; plan self-sizing cells from the start.
- **Interaction.** Every action has a name that works for VoiceOver and Voice Control. Swipe-only actions (swipe to check off) need an alternative: a button or a named accessibility action. Cook mode's timers announce when they finish.
- **Motion and media.** Respect Reduce Motion for autoplaying video in the feed.
- **Testing.** Automated audits in UI tests (Module 43) for each main screen, plus a manual VoiceOver pass of the core tasks before release.

The row's accessibility label is view state, computed like any other (lesson 2's mapping layer), so it can be tested without a device:

```swift
struct RecipeRowState {
    let title: String
    let minutes: Int
    let difficulty: String?
    let photoAltText: String?
    let isSaved: Bool

    /// What VoiceOver reads for the whole row: most important first, no visual-only details.
    var accessibilityLabel: String {
        var parts = [title]
        if let difficulty { parts.append(difficulty) }
        parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        if isSaved { parts.append("Saved") }
        return parts.joined(separator: ", ")
    }

    /// The photo is a separate element only when it has a description; otherwise it's decorative.
    var photoIsAccessible: Bool { !(photoAltText ?? "").isEmpty }
}

let rows = [
    RecipeRowState(title: "Shakshuka", minutes: 25, difficulty: "Easy", photoAltText: "Eggs poached in tomato sauce in a skillet", isSaved: true),
    RecipeRowState(title: "Croissants", minutes: 240, difficulty: nil, photoAltText: nil, isSaved: false),
]

for row in rows {
    print(row.accessibilityLabel, "| photo:", row.photoIsAccessible ? row.photoAltText! : "decorative")
}
let missing = rows.filter { !$0.photoIsAccessible }.count
print("rows without alt text: \(missing) of \(rows.count)")
```

```output
Shakshuka, Easy, 25 minutes, Saved | photo: Eggs poached in tomato sauce in a skillet
Croissants, 240 minutes | photo: decorative
rows without alt text: 1 of 2
```

The last line is a metric, too: the share of feed photos without alt text tells the content team where to work. In SwiftUI, the row applies the label to a combined element and exposes "Save" as a named action:

```swift ios
import SwiftUI

struct RecipeRowView: View {
    let title: String
    let detail: String
    let accessibilityText: String
    let isSaved: Bool
    let toggleSave: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: toggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
            }
            .accessibilityHidden(true)          // replaced by the named action below
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: Text(isSaved ? "Remove from saved" : "Save"), toggleSave)
    }
}
```

The visible button stays for people who tap; VoiceOver users get one element per row with its full description and a "Save" action in the actions rotor. Voice Control still needs a name it can match, which `accessibilityInputLabels` adds when the visible text differs (Module 43). This block is type-checked against the iOS SDK on CI; it wasn't run with VoiceOver for this lesson.

## Common mistakes

> [!error] "We'll add analytics" without metrics
> Name the few signals that test your requirements and what you'd do when each one moves.

> [!error] Kill switches for code that can't check them
> A flag only turns off code that shipped with the check and a fallback. Design the fallback with the feature.

> [!error] Rollouts with hashValue
> Swift's hashing is seeded per process; the bucket changes every launch. Use a fixed hash of the flag name and a stable ID.

> [!error] Free-form event properties
> A call site adds `"title"` or `"query"`, and personal data leaves the device. Enforce a schema on the device.

> [!error] Making log values public by default
> `Logger` redacts interpolated values unless you opt in. Opt in only for values that aren't sensitive.

> [!error] Accessibility as a final polish pass
> Alt text needs API fields, large text needs reflowing layouts, swipe actions need alternatives. Those are design decisions, made in phase 1.

## Exercises

````exercise
id: m48-l05-e1
type: prediction
prompt: "The lesson's flag evaluation with a new rule. Buckets are given. What does it print?"
code: |
  struct Rule {
      var killed = false
      var minimumMajor = 0
      var allowlist: Set<String> = []
      var percent = 0
  }

  func evaluate(_ rule: Rule?, user: String, bucket: Int, major: Int) -> String {
      guard let rule else { return "default" }
      if rule.killed { return "off: killed" }
      if major < rule.minimumMajor { return "off: version" }
      if rule.allowlist.contains(user) { return "on: allowlist" }
      return bucket < rule.percent ? "on: \(bucket)" : "off: \(bucket)"
  }

  let rule = Rule(minimumMajor: 5, allowlist: ["dev"], percent: 25)
  print(evaluate(rule, user: "a", bucket: 24, major: 5))
  print(evaluate(rule, user: "b", bucket: 25, major: 6))
  print(evaluate(rule, user: "dev", bucket: 99, major: 4))
  print(evaluate(nil, user: "a", bucket: 0, major: 5))
  print(evaluate(Rule(killed: true, percent: 100), user: "a", bucket: 0, major: 9))
output: |
  on: 24
  off: 25
  off: version
  default
  off: killed
hints:
  - "The rollout is bucket < percent, so 25 is out."
  - "The version check comes before the allowlist."
solution: |
  ```output
  on: 24
  off: 25
  off: version
  default
  off: killed
  ```

  Bucket 24 is under 25%; bucket 25 isn't (buckets 0 through 24 are the 25%). The developer on major version 4 is off because the minimum-version check runs before the allowlist: old builds can't run the new code path safely, even for the team. No rule means the compiled default, and a kill switch wins over a 100% rollout.
````

````exercise
id: m48-l05-e2
type: comprehension
prompt: "A team wants to put 20% of users on a new feed. Which bucketing is correct?"
choices:
  - text: "A fixed hash (such as FNV-1a) of the flag name and the user's server ID, modulo 100, compared with 20."
    correct: true
    why: "Stable across launches and devices, independent per flag."
  - text: "abs(userID.hashValue) % 100 < 20."
    correct: false
    why: "Swift seeds hashing per process, so the value changes on every launch."
  - text: "Int.random(in: 0..<100) < 20, evaluated at each launch."
    correct: false
    why: "A different answer every launch: people flip between feeds."
  - text: "A hash of the user's email address."
    correct: false
    why: "It's stable, but it handles personal data for no reason and changes when the email does. Use an opaque ID."
solution: |
  Stability and independence are the requirements: the same person gets the same answer every launch and on every device, and different flags pick different people. A fixed hash of "flag:userID" gives both. For signed-out people, a random install ID stored in the Keychain is the stable input.
````

````exercise
id: m48-l05-e3
type: solve
prompt: |
  Write `sanitize(_:_:)` using the schema below. Drop unknown events (return `"dropped"`). Keep only allowed properties, round `"items"` down to a bucket (`"0"`, `"1-9"`, `"10+"`), and return the kept properties sorted by key as `key=value` joined by spaces.

  Expected output:

  ```output
  list_shared: items=10+ role=member
  item_checked: source=list
  dropped
  list_shared: items=0 role=owner
  ```
starter: |
  let schema: [String: Set<String>] = [
      "list_shared": ["items", "role"],
      "item_checked": ["source"],
  ]

  func sanitize(_ name: String, _ properties: [String: String]) -> String {
      // your code
      return ""
  }

  print(sanitize("list_shared", ["items": "14", "role": "member", "invitee_email": "bo@example.com"]))
  print(sanitize("item_checked", ["source": "list", "item_name": "Insulin"]))
  print(sanitize("contacts_read", ["count": "120"]))
  print(sanitize("list_shared", ["items": "0", "role": "owner"]))
hints:
  - "guard let allowed = schema[name] else { return \"dropped\" }"
  - "Sort the kept keys before joining; dictionary order isn't stable."
rubric:
  - Drops events not in the schema.
  - Keeps only allowed properties.
  - Buckets the item count.
  - Produces stable, sorted output.
solution: |
  ```swift
  let schema: [String: Set<String>] = [
      "list_shared": ["items", "role"],
      "item_checked": ["source"],
  ]

  func itemBucket(_ count: Int) -> String {
      switch count {
      case 0: return "0"
      case 1...9: return "1-9"
      default: return "10+"
      }
  }

  func sanitize(_ name: String, _ properties: [String: String]) -> String {
      guard let allowed = schema[name] else { return "dropped" }
      var kept: [String: String] = [:]
      for (key, value) in properties where allowed.contains(key) {
          kept[key] = key == "items" ? itemBucket(Int(value) ?? 0) : value
      }
      return "\(name): " + kept.keys.sorted().map { "\($0)=\(kept[$0]!)" }.joined(separator: " ")
  }

  print(sanitize("list_shared", ["items": "14", "role": "member", "invitee_email": "bo@example.com"]))
  print(sanitize("item_checked", ["source": "list", "item_name": "Insulin"]))
  print(sanitize("contacts_read", ["count": "120"]))
  print(sanitize("list_shared", ["items": "0", "role": "owner"]))
  ```

  ```output
  list_shared: items=10+ role=member
  item_checked: source=list
  dropped
  list_shared: items=0 role=owner
  ```

  The invitee's email and the item name never leave the device. "Insulin" is a good reminder that ordinary product data (a shopping list) can reveal health information, which is why the schema is an allowlist rather than a blocklist of known-bad keys.
````

````exercise
id: m48-l05-e4
type: find-errors
prompt: "An observability and flags plan for a design answer. Mark every real problem."
code: |
  - Log every API response body with Logger using privacy: .public, to debug sync.
  - Send an event for every scroll, with the visible recipe titles.
  - Feature flags fetched at launch; until they arrive, all flags are off and the feed waits.
  - Rollout: Int(userID.hashValue) % 100 < percent.
  - A kill switch for the new list sync; the old sync code was deleted in the same release.
choices:
  - text: "Response bodies contain personal data; making them public puts it in logs anyone with the device can read."
    correct: true
  - text: "Per-scroll events with titles are high volume and personal; aggregate and drop the titles."
    correct: true
  - text: "Blocking the feed on the flag fetch makes launch depend on the network; use compiled defaults and the cached config."
    correct: true
  - text: "hashValue is seeded per process, so the rollout changes every launch."
    correct: true
  - text: "A kill switch with no fallback can only break the feature, not restore the old behavior."
    correct: true
  - text: "Flags should never be fetched at launch."
    correct: false
    why: "Fetching at launch is common; the problem is blocking on it."
rubric:
  - I flagged the public logging of bodies.
  - I flagged the per-scroll events with titles.
  - I flagged blocking launch on flags.
  - I flagged hashValue bucketing.
  - I flagged the kill switch without a fallback.
solution: |
  All but the last choice are real problems. Log identifiers and outcomes with default redaction; send aggregated events against a schema; use compiled defaults and the cached configuration, apply fresh values on the next screen; bucket with a fixed hash of flag and ID; and keep the old sync path behind the switch until the new one has proven itself, then delete both the switch and the old path.
````

````exercise
id: m48-l05-e5
type: fill-in
prompt: "Complete the flag design notes."
code: |
  Before the remote config arrives, flags use values [[1]] into the app,
  or the last fetched config [[2]] on disk.
  Evaluation order: [[3]] switch, minimum app version, allowlist, then percentage.
  Buckets come from a fixed hash of the flag name and a stable user ID, never Swift's [[4]].
blanks:
  - id: "1"
    answers: ["compiled", "built", "baked"]
  - id: "2"
    answers: ["cached", "saved", "stored"]
  - id: "3"
    answers: ["kill"]
  - id: "4"
    answers: ["hashValue", "Hasher"]
solution: |
  Defaults are **compiled** into the app; the last fetched configuration is **cached** on disk so offline launches behave like the previous one. The **kill** switch is checked first. Swift's **hashValue** (and `Hasher`) is seeded per process, so it can't give stable buckets.
````

````exercise
id: m48-l05-e6
type: design
prompt: "Add the observability, privacy and accessibility sections to a design for a meditation app with guided audio sessions, streaks and reminders. Give metrics with decisions, the flag plan for a new audio player, a data minimization table, and the accessibility requirements with their design consequences."
rubric:
  - Metrics tied to requirements (time to start playback, playback failures, download success, reminder delivery proxies, crashes and hangs) with what each would trigger.
  - A flag and kill switch for the new player, with the old player kept as the fallback and a removal date.
  - Data minimization that treats mood or health-like data as sensitive and keeps it on device or out of events.
  - Accessibility requirements that change the design (VoiceOver controls for the player, transcripts or captions in the API, Dynamic Type, Reduce Motion for breathing animations).
solution: |
  - **Metrics:** time from tap to audio (p50/p90, cached vs streamed) → investigate the player or the CDN; playback failures by reason → codec or network problems; download success rate → background session issues; hang rate and crashes from MetricKit → profiling; share of reminders opened (a proxy, since delivery itself isn't observable) → reminder timing.
  - **Flags:** `audio-player-v2` with a kill switch, a minimum version, the team on the allowlist, then 1%, 10%, 50%, 100% by stable bucket. The old player stays until v2 has run at 100% for a release; then both the flag and the old player are deleted.
  - **Privacy:** session completions and streaks sync for the account; mood check-ins stay on the device unless the person turns on sync; events carry session IDs and durations in buckets, never mood values or free-text notes; logs use default redaction.
  - **Accessibility:** player controls are named buttons with adjustable actions for seeking; every session has a transcript in the API; layouts reflow at accessibility sizes; the breathing animation respects Reduce Motion with a static alternative and spoken cues; audits run in UI tests for the player and the library.
````

## Summary

- Pick a handful of field metrics that test your requirements, say where each is measured and what you'd do when it moves. Logs are for debugging; events are what you aggregate.
- MetricKit needs no SDK and reports daily metrics and immediate diagnostics; a third-party reporter adds alerting and grouping at the cost of an SDK and a data processor. Choose with a reason.
- Flags need compiled defaults, a cached configuration, a safety-first evaluation order and stable bucketing from a fixed hash; kill switches need a fallback that shipped with them.
- Minimize data per field, enforce an event schema on the device, coarsen values, and rely on `Logger`'s default redaction.
- Accessibility requirements change the API (alt text, structured quantities), the layouts (reflow at large sizes) and the interactions (named actions), and they get tested like any other requirement.
