---
id: m49-l01
title: The final project
description: "Project 8 asks you to pick a domain and deliver an app you can defend. You choose a capstone that reuses what Projects 1 to 7 already gave you, cut it to a scope that fits your calendar, write requirements with acceptance criteria someone else can verify, plan milestones as vertical slices, agree on a definition of done that covers tests, accessibility, localization, security and performance, and decide what goes into the portfolio. The traceability and definition-of-done checks are plain Swift, compiled and run."
module: m49
order: 1
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m48-l01]
objectives:
  - Choose a capstone domain that exercises networking, persistence and sensitive data without needing a back end you can't build.
  - Scope the project to a fixed time budget with must, should and won't lists.
  - Write functional and non-functional requirements with acceptance criteria that can be verified by a test or a written manual check.
  - Plan Project 8's milestones as vertical slices, each shippable on its own.
  - Apply a definition of done that covers tests, accessibility, localization, security, performance and documentation.
  - Decide what a portfolio repository shows and what it must never contain.
terms:
  - term: Capstone
    definition: "The final project of a course, where you combine the skills from earlier work into one deliverable. In this academy it's Project 8."
  - term: Acceptance criterion
    definition: "A condition a requirement must meet to count as done, written so a person or a test can check it with a yes or no answer."
  - term: Vertical slice
    definition: "A piece of work that goes through every layer (UI, domain, data) for one user-visible behavior, so it can be demonstrated and tested on its own."
  - term: Definition of done
    definition: "The checklist every piece of work has to pass before it counts as finished. It's agreed in advance and applies to every slice, not just the last one."
  - term: Traceability
    definition: "Being able to follow each requirement to the criteria that define it and the tests or checks that verify them."
mastery:
  - Pick a capstone domain and justify it against the course's earlier projects in a paragraph.
  - Cut a feature list to fit a time budget and write down what you won't build.
  - Turn a vague requirement into acceptance criteria in Given, When, Then form.
  - Split a project into three to five vertical slices and say what each one demonstrates.
  - Check a finished slice against a definition of done and name what's missing.
  - Write the outline of a README that lets a stranger build, run and judge the app.
resources: [swift-testing-docs, accessibility-performing-audits, xcode-string-catalog, owasp-masvs, xcode-improving-performance, gha-workflow-syntax]
cards:
  - id: m49-l01-c1
    front: What makes an acceptance criterion good?
    back: "Someone other than you can check it and get a yes or no. It names the situation, the action and the observable result (Given, When, Then), and it's verified by an automated test or a written manual check with steps."
  - id: m49-l01-c2
    front: Why plan the capstone as vertical slices instead of layers?
    back: "Each slice goes from UI to data for one behavior, so it can be demonstrated, tested and reviewed on its own. If time runs out you have three finished features instead of a complete data layer with no screens."
  - id: m49-l01-c3
    front: What does a definition of done cover in this course?
    back: "Tests, accessibility, localization, security, performance and documentation. It applies to every slice, and a slice with any item failing or not checked isn't done."
  - id: m49-l01-c4
    front: What should a won't list do for a project?
    back: "Record the features you decided not to build, with the reason, so scope doesn't creep back in and a reviewer sees you made the cut on purpose."
  - id: m49-l01-c5
    front: Name three things a portfolio repository must never contain.
    back: "Secrets (API keys, signing certificates, provisioning profiles), real personal data, and code or assets you don't have the license to publish."
---

## The idea in one sentence

The final project isn't graded on how much you built but on whether someone else can verify what you built: written requirements with checkable criteria, slices that each meet the same definition of done, and decisions you can explain.

## Where Project 8 starts

Project 8 gives you a short brief: pick a domain (personal banking, health and habits, education, or your own idea held to the same bar), write the requirements and acceptance criteria, record your architecture decisions, ship tests, accessibility, performance and error handling, and write a README with build instructions and a quality checklist. It's accepted when someone else can build and run the app from the README alone, every acceptance criterion has been verified, the final review leaves no critical findings open, and you can explain the architecture in 10 minutes.

That brief is deliberately open. This lesson turns it into a plan. The rest of the module covers what happens while you execute it: decision records (lesson 2), working with existing code and reviews (lesson 3), what to do when something breaks (lesson 4), estimating the work (lesson 5) and writing about it (lesson 6).

## Choosing the capstone

You aren't starting from zero. Every earlier project left you something to reuse:

| Project | What carries into the capstone |
| --- | --- |
| 1, Command-Line Expense Tracker | Money as integer cents, input validation, per-category summaries |
| 2, Tested Algorithms Library | A package with tests for every edge case; the habit of writing complexity down |
| 3, Reading List (UIKit) | Diffable data sources, forms with validation, empty states, Dynamic Type and VoiceOver |
| 4, UIKit App with a Public API | Pagination, image caching, offline persistence, a repository tested with a fake network client |
| 5, The Same App in SwiftUI | `@Observable` models, `NavigationStack`, a data layer reused unchanged |
| 6, Hybrid UIKit and SwiftUI | Mixing frameworks in one app, a model shared across both |
| 7, Production-Quality App | A documented architecture, Swift 6 mode with no warnings, Keychain and Data Protection, `os.Logger` without personal data, CI |

The capstone should **use most of that, and add one thing you haven't done yet**. Good criteria for the domain:

- **You can explain why a user would open it.** If you can't describe the main task in one sentence, the requirements will drift.
- **It has data worth protecting.** Banking and health give you real reasons to apply Project 7's security checklist. A to-do list doesn't.
- **It doesn't need a back end you can't build or run.** A public API with a license that allows your use, a local-only app, or a small mock server you control. A capstone that depends on a service you can't keep running fails its first acceptance criterion ("someone else can build and run it").
- **It has one hard part.** Offline edits that sync, a chart with an accessible summary, a widget that shares data through an App Group. One, not four.

A worked choice: **Habit Ledger**, a habits app that logs daily check-ins, shows streaks and a weekly chart, works offline and exports a summary. It reuses Project 5's SwiftUI structure and Project 7's checklist (health-adjacent data stays on device and out of logs), and its hard part is getting streaks right across time zones and daylight saving changes. The rest of this module uses it as the running example.

## Scope: fit the project to the calendar

Start from the time you actually have, not from the features you'd like. Six weeks at eight hours a week is 48 hours, and lesson 5 will show you why the first estimate for each feature is optimistic. Then sort the feature list into three groups:

- **Must**: without these, the app doesn't do its job. For Habit Ledger: create a habit, check in, see the current streak, keep data across launches.
- **Should**: valuable, and planned, but the project still passes without them: the weekly chart, reminders.
- **Won't (this time)**: written down with a reason. iCloud sync (needs an account and conflict handling you can't test well alone), Apple Watch app, social sharing.

The won't list matters as much as the must list. It stops scope from creeping back in at week four, and in the final review it shows you made the cut on purpose instead of running out of time.

Cutting to a budget is mechanical once the estimates exist. Musts go in first, in priority order; then shoulds while they fit:

```swift
enum Priority: Int { case must = 0, should = 1, wont = 2 }

struct Feature {
    let name: String
    let priority: Priority
    let hours: Int
}

func plan(_ features: [Feature], budgetHours: Int) -> (included: [String], cut: [String], hoursUsed: Int) {
    var included: [String] = []
    var cut: [String] = []
    var used = 0
    let ordered = features.enumerated().sorted {
        ($0.element.priority.rawValue, $0.offset) < ($1.element.priority.rawValue, $1.offset)
    }
    for (_, feature) in ordered {
        if feature.priority == .wont {
            cut.append(feature.name + " (won't)")
        } else if used + feature.hours <= budgetHours {
            included.append(feature.name)
            used += feature.hours
        } else if feature.priority == .must {
            included.append(feature.name + " (OVER BUDGET)")
            used += feature.hours
        } else {
            cut.append(feature.name + " (no time)")
        }
    }
    return (included, cut, used)
}

let habitLedger = [
    Feature(name: "Weekly chart", priority: .should, hours: 8),
    Feature(name: "Create and edit habits", priority: .must, hours: 10),
    Feature(name: "Daily check-in", priority: .must, hours: 6),
    Feature(name: "Streaks across time zones", priority: .must, hours: 10),
    Feature(name: "iCloud sync", priority: .wont, hours: 20),
    Feature(name: "Reminders", priority: .should, hours: 8),
    Feature(name: "Persistence", priority: .must, hours: 8),
    Feature(name: "CSV export", priority: .should, hours: 4),
]

let result = plan(habitLedger, budgetHours: 48)
print("Included:", result.included.joined(separator: ", "))
print("Cut:", result.cut.joined(separator: ", "))
print("Hours used: \(result.hoursUsed) of 48")
```

```output
Included: Create and edit habits, Daily check-in, Streaks across time zones, Persistence, Weekly chart, CSV export
Cut: Reminders (no time), iCloud sync (won't)
Hours used: 46 of 48
```

- **The sort key is a tuple** `(priority, original position)`, so features keep the order you listed them within each priority. The standard library doesn't document `sorted(by:)` as stable, so without the position you'd be relying on behavior nobody promised.
- **Reminders (8 hours) didn't fit, but CSV export (4) did.** After the musts (34 hours) and the chart (8), 6 hours were left. That's greedy filling: fine for a first cut, and a reason to order the shoulds by value before running it, since the tool will happily keep a small, low-value feature over a bigger, more useful one.
- **A must that doesn't fit is flagged, not dropped.** If a must is over budget, the plan is wrong, and the answer is a conversation about scope or time (lesson 5), not silently cutting a must.
- **46 of 48 hours leaves no buffer.** The budget should include one: lesson 5 shows how to size it from the uncertainty in each estimate.

## Requirements you can verify

Module 48 separated functional requirements (what the app does) from non-functional ones (how well: performance, offline behavior, privacy, accessibility). The capstone needs both, written so they can be checked.

A requirement is a sentence about behavior. An **acceptance criterion** is a condition that's either met or not, checked by someone who isn't you. The Given, When, Then form keeps criteria concrete:

| Requirement | Weak criterion | Verifiable criterion |
| --- | --- | --- |
| Users can see their streak | "Streaks work correctly." | Given check-ins on Mon, Tue and Wed, when the user opens the habit on Wed, then the streak shows 3. |
| Streaks survive travel | "Handles time zones." | Given a check-in at 23:30 in New York and one at 08:00 the next day in Madrid, then both count as consecutive days in the time zone where each was made. |
| Offline | "Works offline." | Given airplane mode, when the user checks in and relaunches the app, then the check-in is still there. |
| Accessible | "Supports VoiceOver." | With VoiceOver on, a user can create a habit and check in without sighted help; every control has a label; the chart has a text summary. |
| Fast | "Launches quickly." | Cold launch to an interactive list in under 1 second on the oldest supported device, measured with the launch metric in a performance test. |
| Private | "Data is secure." | No habit names or check-in dates appear in logs; the database file uses a Data Protection class that keeps it encrypted while the device is locked. |

Each criterion needs a **way to verify it**: an automated test (unit, UI or performance) or a manual check with written steps, for things like VoiceOver flows that you test by hand. A criterion with neither is a wish. Keep the link between them explicit so you can see coverage at a glance:

```swift
enum Verification {
    case automated(test: String)
    case manual(steps: String)
    case none
}

struct Criterion {
    let id: String
    let summary: String
    let verification: Verification
}

let criteria = [
    Criterion(id: "AC-1", summary: "Streak counts consecutive local days",
              verification: .automated(test: "StreakTests.consecutiveDays")),
    Criterion(id: "AC-2", summary: "Streak survives a time zone change",
              verification: .automated(test: "StreakTests.travelEastward")),
    Criterion(id: "AC-3", summary: "Check-in persists offline across relaunch",
              verification: .automated(test: "CheckInUITests.offlineRelaunch")),
    Criterion(id: "AC-4", summary: "Create and check in with VoiceOver",
              verification: .manual(steps: "docs/manual-checks.md#voiceover")),
    Criterion(id: "AC-5", summary: "No habit names in logs", verification: .none),
]

var unverified: [String] = []
for criterion in criteria {
    switch criterion.verification {
    case .automated(let test):
        print("\(criterion.id)  test    \(test)")
    case .manual(let steps):
        print("\(criterion.id)  manual  \(steps)")
    case .none:
        print("\(criterion.id)  ---     \(criterion.summary)")
        unverified.append(criterion.id)
    }
}
print("Verified: \(criteria.count - unverified.count)/\(criteria.count); missing: \(unverified.joined(separator: ", "))")
```

```output
AC-1  test    StreakTests.consecutiveDays
AC-2  test    StreakTests.travelEastward
AC-3  test    CheckInUITests.offlineRelaunch
AC-4  manual  docs/manual-checks.md#voiceover
AC-5  ---     No habit names in logs
Verified: 4/5; missing: AC-5
```

The criteria with an id (`AC-1`…) end up in three places: the requirements document, the test names or comments, and the final checklist in the README. Project 8's acceptance asks that "every acceptance criterion in the requirements document has been verified"; this table is how you show it.

## Milestones as vertical slices

Project 8 lists five milestones: requirements (p08-h1), design (p08-h2), incremental implementation (p08-h3), quality (p08-h4), and review and defense (p08-h5). The third one is where most of the time goes, and it says "complete vertical slices, each with tests."

A **vertical slice** goes through every layer for one behavior: the screen, the view model, the domain rule, persistence. The alternative, building the whole data layer first, then the domain, then the UI, means nothing is demonstrable until the end and every integration problem appears in the last week.

For Habit Ledger:

1. **Create a habit and see it in the list.** Smallest slice that touches everything: SwiftUI form, model, persistence, list. Ships the project skeleton, CI and the first ADRs.
2. **Check in and see the streak.** The domain rule with its tests (AC-1, AC-2), the check-in button with an accessibility label.
3. **Offline and relaunch.** Persistence behavior under airplane mode, the UI test for AC-3, Data Protection on the store.
4. **Weekly chart with an accessible summary.** A should: if it slips, the project still passes.
5. **CSV export.** Another should, cut first if time runs short.

Each slice ends with a pull request (even if you're the only reviewer, lesson 3 shows how to review your own), a green CI run, and the definition of done below. Milestone p08-h4, "Quality," then becomes a final audit instead of a rescue.

## The definition of done

A **definition of done** is the checklist every slice passes before it counts. Agreeing on it up front is what stops "done" from meaning "works on my phone." For this course, it covers six areas:

- **Tests**: the slice's domain rules have unit tests, including edges; UI flows with acceptance criteria have a UI test or a written manual check. CI is green.
- **Accessibility**: every control has a label; the screen works with VoiceOver and at the largest Dynamic Type size; Xcode's accessibility audit passes or each remaining issue is explained.
- **Localization**: user-facing strings are in the String Catalog, not concatenated; dates, numbers and plurals use formatters and inflection, not hand-built strings. Even a one-language app should be ready for a second.
- **Security and privacy**: no secrets in the repository; sensitive data in the Keychain or protected files; logs without personal data (Project 7's checklist).
- **Performance**: no work on the main thread that scales with data size; scrolling stays smooth with a realistic amount of data; launch measured if the slice touches startup.
- **Documentation**: the README and any ADRs are updated; public types have documentation comments where the name isn't enough.

Areas that don't apply to a slice still have to be **looked at**, then marked as not applicable. Skipping an area is different from checking it and finding nothing to do. The evaluator below treats "not checked" as a failure for exactly that reason:

```swift
enum Area: String, CaseIterable {
    case tests, accessibility, localization, security, performance, documentation
}

enum CheckResult {
    case passed
    case failed(String)
    case notApplicable(String)
}

func evaluate(slice: String, results: [Area: CheckResult]) -> Bool {
    var problems: [String] = []
    for area in Area.allCases {
        switch results[area] {
        case .passed?, .notApplicable?:
            continue
        case .failed(let reason)?:
            problems.append("\(area.rawValue): \(reason)")
        case nil:
            problems.append("\(area.rawValue): not checked")
        }
    }
    if problems.isEmpty {
        print("\(slice): done")
    } else {
        print("\(slice): not done")
        for problem in problems { print("  - \(problem)") }
    }
    return problems.isEmpty
}

let slice2: [Area: CheckResult] = [
    .tests: .passed,
    .accessibility: .failed("check-in button has no label"),
    .security: .passed,
    .performance: .notApplicable("no lists or startup work in this slice"),
    .documentation: .passed,
]
let slice1: [Area: CheckResult] = [
    .tests: .passed, .accessibility: .passed, .localization: .passed,
    .security: .passed, .performance: .passed, .documentation: .passed,
]

let done1 = evaluate(slice: "Slice 1, create a habit", results: slice1)
let done2 = evaluate(slice: "Slice 2, check in and streak", results: slice2)
print("Slices done: \([done1, done2].filter { $0 }.count) of 2")
```

```output
Slice 1, create a habit: done
Slice 2, check in and streak: not done
  - accessibility: check-in button has no label
  - localization: not checked
Slices done: 1 of 2
```

- **The loop walks `Area.allCases`, not the dictionary.** Iterating a Swift dictionary gives an order that can change between runs; iterating the enum's cases gives the same order every time, so the report is stable.
- **`case .passed?, .notApplicable?:`** matches the optional values from the dictionary lookup; `case nil` catches areas nobody filled in.
- **`.notApplicable` needs a reason.** "No lists or startup work in this slice" tells a reviewer you thought about performance. An empty answer would tell them nothing.
- **Slice 2 fails twice:** a real accessibility bug, and an area nobody checked. The second is the easier one to miss, and it's why the checklist exists.

> [!tip] Put the checklist in the pull request template
> GitHub reads `.github/pull_request_template.md` into every new pull request's description. Put the six areas there as checkboxes, so each slice's PR is also its definition-of-done record.

## What goes in the portfolio

The repository is what a hiring engineer will open, sometimes for only a few minutes. Make the first screen count:

- **README first screen**: one sentence on what the app does, two or three screenshots (include one at a large Dynamic Type size and one in dark mode), the build instructions, and the requirements it was built on (Xcode version, iOS deployment target).
- **The quality checklist** Project 8 asks for, with each acceptance criterion and how it was verified (the table from earlier).
- **`docs/adr/`** with the decision records from lesson 2. These show judgment better than any amount of code.
- **Tests that read like a specification**: names such as `streakResetsAfterAMissedLocalDay`, not `test1`.
- **A green CI badge** that's actually green.
- **"What I'd do next"**: the won't list, with what you learned about each item. It shows you know where the app's limits are.

And what must never be there: API keys and tokens (Project 7's per-environment configuration keeps them out), signing certificates and provisioning profiles, real people's data in fixtures or screenshots, and code or assets you're not licensed to publish. If a secret was ever committed, deleting it in a later commit doesn't remove it from history: revoke it and issue a new one.

Finally, prepare the 10-minute walkthrough from Project 8's acceptance criteria: the problem, the architecture in one diagram, two decisions and what they cost, one bug you found and how, and what you'd change. Lesson 6 covers how to explain it.

## Common mistakes

> [!error] Choosing a domain that needs a back end you can't run
> The app works on your machine against a server you started by hand, and nobody else can run it. Pick a public API with a license that allows your use, keep the app local, or ship a mock server with the repository and document how to start it.

> [!error] "Done" means it works on the simulator
> A slice without tests, labels or a localization pass isn't done; it's deferred work. Run the definition of done on every slice, so the quality milestone doesn't turn into a rewrite.

> [!error] Acceptance criteria nobody else can check
> "Works well offline" can't fail, so it can't pass either. Name the situation, the action and the observable result, and link each criterion to a test or written manual steps.

> [!error] Building layer by layer
> A complete persistence layer and no screens at week five is a project that can't be demonstrated. Build thin slices from UI to data and widen them.

> [!error] No won't list
> Without one, every good idea gets added and the musts don't get finished. Write the list on day one and add to it whenever you cut something.

## Exercises

````exercise
id: m49-l01-e1
type: comprehension
prompt: "Which acceptance criterion for Habit Ledger's reminders can be verified by someone who isn't the author?"
choices:
  - text: "Reminders are reliable and arrive on time."
    correct: false
    why: "'Reliable' and 'on time' have no threshold or situation; nobody can check them with a yes or no."
  - text: "Given a habit with a reminder at 20:00 and notifications allowed, when the device clock reaches 20:00, then one notification with the habit's name is delivered, and none is delivered if the user already checked in that day."
    correct: true
    why: "It names the situation, the trigger and the observable result, including the case where nothing should happen."
  - text: "The reminders feature uses UNUserNotificationCenter correctly."
    correct: false
    why: "That's an implementation detail, not behavior a user or tester can observe."
  - text: "Users like the reminders."
    correct: false
    why: "That's a product goal you'd measure with research, not an acceptance criterion for a build."
solution: |
  The second one. It's in Given, When, Then form, it covers the negative case (no notification after a check-in), and a tester can run it on a device by setting the reminder a minute ahead.

  The others fail for different reasons: no threshold ("reliable"), implementation instead of behavior ("uses UNUserNotificationCenter"), or a goal that isn't about the build ("users like").
````

````exercise
id: m49-l01-e2
type: prediction
prompt: "A smaller definition-of-done check. What does this program print?"
code: |
  enum Area: String, CaseIterable { case tests, accessibility, localization, security }

  func report(_ checked: [Area: Bool]) -> String {
      var failing: [String] = []
      for area in Area.allCases {
          if checked[area] != true { failing.append(area.rawValue) }
      }
      return failing.isEmpty ? "done" : "missing " + failing.joined(separator: ", ")
  }

  print(report([.tests: true, .accessibility: true, .localization: true, .security: true]))
  print(report([.tests: true, .security: false, .accessibility: true]))
  print(report([:]))
output: |
  done
  missing localization, security
  missing tests, accessibility, localization, security
hints:
  - "`checked[area]` is an optional Bool. Both `nil` and `false` are not equal to `true`."
  - "The order of the names follows `Area.allCases`, not the dictionary literal."
solution: |
  ```output
  done
  missing localization, security
  missing tests, accessibility, localization, security
  ```

  1. Every area maps to `true`, so `failing` stays empty.
  2. `security` is `false` and `localization` is missing (`nil`). Both fail `!= true`. They're listed in `allCases` order: localization comes before security, even though `.security` was written first in the literal.
  3. An empty dictionary returns `nil` for every area, so all four are missing.

  Comparing an optional Bool with `!= true` is a compact way to treat "not checked" the same as "failed," which is what a definition of done should do.
````

````exercise
id: m49-l01-e3
type: solve
prompt: |
  Write `slices(for:)`, which takes acceptance criteria tagged with the slice that delivers them, and returns one line per slice in ascending slice order: the slice number, how many criteria it has, and how many are verified (by a test or manual steps). Criteria inside a slice don't need to be listed.

  ```swift
  let criteria = [
      (slice: 2, id: "AC-1", verified: true),
      (slice: 2, id: "AC-2", verified: true),
      (slice: 3, id: "AC-3", verified: false),
      (slice: 1, id: "AC-6", verified: true),
      (slice: 3, id: "AC-4", verified: true),
  ]
  for line in slices(for: criteria) { print(line) }
  ```

  should print:

  ```output
  Slice 1: 1/1 verified
  Slice 2: 2/2 verified
  Slice 3: 1/2 verified
  ```
starter: |
  func slices(for criteria: [(slice: Int, id: String, verified: Bool)]) -> [String] {
      // Group by slice, count total and verified, sort by slice number.
      return []
  }
rubric:
  - Groups criteria by slice and counts total and verified per slice.
  - Returns slices in ascending order regardless of input order or dictionary order.
  - Produces exactly the expected format.
hints:
  - "A dictionary from slice number to a (total, verified) pair works; sort its keys before building the lines."
solution: |
  ```swift
  func slices(for criteria: [(slice: Int, id: String, verified: Bool)]) -> [String] {
      var counts: [Int: (total: Int, verified: Int)] = [:]
      for criterion in criteria {
          var entry = counts[criterion.slice, default: (0, 0)]
          entry.total += 1
          if criterion.verified { entry.verified += 1 }
          counts[criterion.slice] = entry
      }
      return counts.keys.sorted().map { slice in
          let entry = counts[slice]!
          return "Slice \(slice): \(entry.verified)/\(entry.total) verified"
      }
  }

  let criteria = [
      (slice: 2, id: "AC-1", verified: true),
      (slice: 2, id: "AC-2", verified: true),
      (slice: 3, id: "AC-3", verified: false),
      (slice: 1, id: "AC-6", verified: true),
      (slice: 3, id: "AC-4", verified: true),
  ]
  for line in slices(for: criteria) { print(line) }
  ```

  ```output
  Slice 1: 1/1 verified
  Slice 2: 2/2 verified
  Slice 3: 1/2 verified
  ```

  - `counts[criterion.slice, default: (0, 0)]` reads an existing pair or starts a new one, so there's no separate "first time" branch.
  - `counts.keys.sorted()` is what makes the output stable. Mapping over `counts` directly would list slices in whatever order the dictionary happens to use.
  - The force unwrap is safe because the key came from the same dictionary. If you'd rather avoid it, build an array of `(slice, total, verified)` tuples and sort that.

  In the project, this report is the "is the slice ready to merge" view; slice 3 isn't, because AC-3 has no verification yet.
````

````exercise
id: m49-l01-e4
type: find-errors
prompt: "A first draft of the capstone plan. Mark every real problem."
code: |
  Domain: a budgeting app that reads transactions from my bank's internal API (I have a login from my internship).
  Must: accounts, transactions, budgets, charts, iCloud sync, Watch app, widgets, Siri.
  Won't: (none yet)
  Milestones: 1. All models. 2. All persistence. 3. All networking. 4. All screens. 5. Polish.
  Acceptance: the app is fast, secure and accessible.
  Definition of done: tests pass.
choices:
  - text: "The domain depends on a private API that other people can't access, so nobody else can build and run it."
    correct: true
  - text: "The must list has eight features, several of them large, and the won't list is empty."
    correct: true
  - text: "Milestones are horizontal layers; nothing is demonstrable until milestone 4."
    correct: true
  - text: "The acceptance criteria can't be checked: no situation, threshold or observable result."
    correct: true
  - text: "The definition of done covers only tests, not accessibility, localization, security, performance or documentation."
    correct: true
  - text: "A budgeting app is too simple a domain for a capstone."
    correct: false
rubric:
  - I flagged the private API.
  - I flagged the oversized must list and empty won't list.
  - I flagged the horizontal milestones.
  - I flagged the unverifiable acceptance criteria.
  - I flagged the narrow definition of done.
solution: |
  Five real problems, one distractor:

  - **Private API.** It fails Project 8's first acceptance criterion, and using an internship login for a personal project is a problem on its own. Use a public API with suitable terms, sample data, or a mock server in the repository.
  - **Scope.** Eight musts, four of them whole platforms or integrations, and nothing cut. Pick the two or three features the app can't do without; move the rest to should or won't with reasons.
  - **Horizontal milestones.** Replace them with slices: "see accounts and balances," "add a transaction," "budget for a category with an alert."
  - **Acceptance.** "Fast, secure and accessible" can't fail. Each needs a measurable criterion (launch under a threshold on a named device, no amounts in logs, VoiceOver flow with written steps).
  - **Definition of done.** "Tests pass" leaves out five of the six areas.

  The domain itself is fine: budgeting has sensitive data, persistence and charts, which is plenty for a capstone.
````

````exercise
id: m49-l01-e5
type: design
prompt: "Pick your own capstone domain (or use Habit Ledger). Write: one sentence on what the app does; a must, should and won't list with one reason per won't; three functional and three non-functional acceptance criteria in Given, When, Then form, each with how it will be verified; and three to five vertical slices in order."
rubric:
  - The one-sentence description names a user and a main task.
  - Musts are few enough to fit a stated time budget; every won't has a reason.
  - Every acceptance criterion has a situation, an action and an observable result.
  - Every criterion names an automated test or a manual check with steps.
  - Non-functional criteria include at least one each for accessibility, privacy or security, and performance.
  - Each slice goes from UI to data and can be demonstrated on its own.
solution: |
  A model answer for a reading tracker, **Shelf**:

  **What it does:** Shelf lets a reader log the books they're reading and see how many pages a day they need to finish by a date they choose.

  **Must:** add a book with total pages and a target date; log pages read; see pages per day needed; keep data across launches. **Should:** search a public book catalog to prefill details; a monthly summary. **Won't:** social sharing (needs accounts and moderation), e-book import (file formats and rights are out of scope), Watch app (no time to test on a device).

  **Functional criteria:**

  - AC-1. Given a 300-page book with 100 pages read and a target 10 days away, when the user opens it, then it shows 20 pages per day. *Test:* `PaceTests.pagesPerDay`.
  - AC-2. Given a target date in the past, when the user opens the book, then it shows "Target date passed" instead of a number. *Test:* `PaceTests.pastTarget`.
  - AC-3. Given no network, when the user adds a book manually, then it's saved and appears in the list after relaunch. *UI test:* `AddBookUITests.offline`.

  **Non-functional criteria:**

  - AC-4 (accessibility). With VoiceOver on, a user can add a book and log pages; the progress ring announces "120 of 300 pages, 20 per day needed." *Manual:* `docs/manual-checks.md#voiceover`.
  - AC-5 (privacy). Given logging at the debug level, when a user adds a book, then the log contains no title or author. *Test* that captures log output through an injected logger.
  - AC-6 (performance). Given 2,000 books, when the list scrolls, then no frame takes longer than the device's frame budget in an Instruments trace. *Manual* with a recorded trace in `docs/perf/`.

  **Slices:** (1) add a book manually and see it in the list, with persistence; (2) log pages and see the pace (AC-1, AC-2); (3) offline and relaunch (AC-3); (4) catalog search; (5) monthly summary.

  Your answer will differ. Check it against the rubric, especially the last point: if a slice is "the networking layer," it's a layer, not a slice.
````

````exercise
id: m49-l01-e6
type: explain
prompt: "A friend's capstone README says: 'Performance: N/A. This is a small app.' In a few sentences, explain why that isn't an acceptable entry in a definition of done and what would be."
code: |
  ## Quality checklist
  - Tests: 42 passing
  - Accessibility: VoiceOver labels on all screens
  - Performance: N/A. This is a small app.
rubric:
  - Explains that not applicable needs a reason that shows the area was examined.
  - Points out that small apps still have performance risks (launch, lists, main-thread work, data growth).
  - Proposes a concrete, checkable entry.
solution: |
  "N/A" without evidence reads as "not checked." Small apps still launch, scroll lists, decode images and read databases on some thread, and data grows: a habit app with three years of daily check-ins has over a thousand rows per habit. An honest entry says what was looked at and what was found, for example:

  > Performance: cold launch measured at 0.4 s on iPhone SE (3rd generation) with `XCTApplicationLaunchMetric`; list scrolling checked in Instruments with 5,000 check-ins, no hitches; persistence runs off the main actor.

  If a slice genuinely has no performance-relevant work, say why ("settings screen with three toggles, no lists or I/O"). The reason is what makes "not applicable" credible.
````

## Summary

- Choose a capstone that reuses Projects 1 to 7, has data worth protecting, doesn't depend on a back end others can't run, and has one hard part.
- Scope from the time budget: must, should and won't, with a reason for every won't. Musts that don't fit mean the plan needs a conversation, not a silent cut.
- Write acceptance criteria someone else can check (Given, When, Then), and link each to an automated test or written manual steps.
- Plan milestones as vertical slices so each one can be demonstrated, tested and reviewed.
- Hold every slice to the same definition of done: tests, accessibility, localization, security, performance and documentation. "Not checked" counts as failing.
- The portfolio repository shows the README, the quality checklist, the ADRs and the tests; it never contains secrets, real personal data or unlicensed assets.
