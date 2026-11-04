---
id: m49-l04
title: Incidents and on-call
description: "Module 41 covered the App Store side of a bad release: there's no rollback, so you mitigate with flags and phased release and fix forward with a hotfix. This lesson covers the people side. You decide when something is an incident, classify its severity from impact instead of from how loud the report was, split the work into roles so one person isn't debugging and answering Slack at once, write status updates people can act on, choose mitigation before root cause, run a sustainable on-call rotation, and turn a blameless postmortem into action items that actually get done. The severity classifier and action item tracker are plain Swift, compiled and run."
module: m49
order: 4
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m49-l03, m41-l06]
objectives:
  - Decide when a problem should be declared an incident, using written criteria.
  - Define severity levels from impact and map each to a response.
  - Assign incident roles (commander, operations, communication, planning) and hand them off explicitly.
  - Write status updates with impact, current actions and the time of the next update.
  - Prefer mitigation over a root-cause fix during the incident, and track what was changed to mitigate.
  - Set up an on-call rotation with handoffs, runbooks and actionable alerts.
  - Write postmortem action items that are specific, owned, dated and tracked to completion.
terms:
  - term: Incident
    definition: "An unplanned event that harms users or the business and needs a coordinated response, declared by someone according to criteria agreed in advance."
  - term: Severity level
    definition: "A team-defined category (often SEV1 to SEV4) that describes an incident's impact and determines the response: who is paged, how often updates go out, whether a postmortem is required."
  - term: Incident commander
    definition: "The person who holds the overall state of the incident, assigns roles and makes decisions. They coordinate; they usually don't debug."
  - term: Mitigation
    definition: "An action that reduces or stops user impact without necessarily fixing the cause: turning a feature off, pausing a rollout, changing a server response."
  - term: On-call
    definition: "A rotation in which one person at a time is responsible for responding to alerts and reports, with a defined handoff at the end of each shift."
  - term: Runbook
    definition: "Written, step-by-step instructions for responding to a specific alert or failure, kept where the on-call person can find them in the middle of the night."
  - term: Action item
    definition: "A follow-up task from a postmortem that changes a system or process, with one owner, a due date and a priority."
mastery:
  - Apply written criteria to decide whether a report is an incident, and declare it.
  - Classify an incident's severity from its impact and state the response it requires.
  - Run a small incident with roles assigned, including an explicit handoff of command.
  - Write a status update that a support lead or executive can act on without follow-up questions.
  - Choose a mitigation for a mobile incident and record how to undo it afterward.
  - Rewrite vague postmortem action items into specific, owned, dated ones, and report on overdue ones.
resources: [sre-managing-incidents, sre-postmortem-culture, asc-phased-release, xcode-crash-reports, metrickit, os-logger, apple-app-review]
cards:
  - id: m49-l04-c1
    front: What are the three questions in Google's SRE book for declaring an incident?
    back: "Do you need to involve a second team in fixing the problem? Is the outage visible to customers? Is the issue unsolved even after an hour's concentrated analysis? If any is true, it's an incident."
  - id: m49-l04-c2
    front: What are the four incident roles in Google's SRE book?
    back: "Incident command (holds the high-level state), operational work (the only people changing the system), communication (periodic updates to the team and stakeholders) and planning (longer-term issues like handoffs and tracking what was changed)."
  - id: m49-l04-c3
    front: What goes in an incident status update?
    back: "What's affected and how many users, what's known (and what isn't), what's being done, any workaround, and when the next update will come. No speculation about the cause."
  - id: m49-l04-c4
    front: Mitigation or root cause first?
    back: "Mitigation. SRE book: \"Stop the bleeding, restore service, and preserve the evidence for root-causing.\" On mobile: turn the feature off with its flag, pause the phased release, fix the server. The hotfix comes after."
  - id: m49-l04-c5
    front: What makes a postmortem action item good?
    back: "It's specific (a change to a system, not \"be careful\"), it has one owner and a due date, it has a priority, and it's tracked until done. Postmortems without completed action items repeat."
---

## The idea in one sentence

An incident goes better when the decisions were made before it started: what counts as one, how severe it is, who does what, how often people hear from you, and what you'll do first (stop the harm) before what you'll do next (fix the cause).

> [!note] Sources and what was checked
> Quotations about incident roles, declaring incidents and incident management practices come from chapter 14 of Google's *Site Reliability Engineering* book, "Managing Incidents" (written by Andrew Stribblehill, edited by Kavita Guliani). Quotations about postmortems come from chapter 15, "Postmortem Culture: Learning from Failure" (written by John Lunney and Sue Lueder, edited by Gary O'Connor). Both were read at sre.google in November 2026. The book describes server operations at Google; this lesson adapts its practices to a mobile team and says where mobile differs. Severity definitions are examples to adapt, not a standard: there isn't a universal one. The Swift blocks are compiled and run with Swift 6.3.

## What Module 41 already gave you

Module 41's last lesson handled the release side of an incident: the App Store has no rollback; you mitigate with a feature flag, a server-side change or by pausing the phased release; you fix forward with a hotfix branched from the release tag; and afterward you write a blameless postmortem with a timeline and the times to detect, mitigate and resolve. That's the toolkit. This lesson is about the people using it: at 2 a.m., with Slack filling up, a support lead asking for an answer and a product manager asking for an ETA.

## Is this an incident?

Incidents are declared, by a person. The failure mode isn't declaring too many; it's a small group of engineers quietly debugging for three hours while support answers angry users with no information. The SRE book recommends setting clear conditions for declaring one, and gives its team's: "if any of the following is true, the event is an incident":

- "Do you need to involve a second team in fixing the problem?"
- "Is the outage visible to customers?"
- "Is the issue unsolved even after an hour's concentrated analysis?"

For a mobile team, the second question catches most cases: a crash spike in the new version, a sign-in failure, a payment screen that hangs, a privacy problem in what the app sends. Declaring costs little: a channel, a document, a few people paged. You can always downgrade it. Not declaring a real incident costs the hours in which nobody coordinated anything.

## Severity: from impact, not from volume

Severity is a label that decides the response. It has to come from **impact** (how many users, how badly, whether there's a workaround, whether data, money or privacy is involved), not from who reported it or how urgent the message sounded.

Every team defines its own levels. An example for a mobile app team, to adapt rather than copy:

| Level | Impact (any of) | Response |
| --- | --- | --- |
| SEV1 | Data loss or corruption; security or privacy exposure; payments broken; crash or blocked core flow for 5% or more of active users with no workaround | Page on-call and a backup now; incident commander assigned; updates every 30 min; postmortem required |
| SEV2 | Core flow broken for a segment (one OS version, one region) or under 5% of users with no workaround | Page on-call; updates every hour; postmortem required |
| SEV3 | A feature degraded, with a workaround | Ticket for business hours; postmortem optional |
| SEV4 | Cosmetic, or affects only internal builds | Normal backlog |

The rules are simple enough to write as a function, and doing so forces the team to agree on them before they matter. Percentages are kept as integer basis points (1 basis point is 0.01%) to avoid floating point:

```swift
enum Severity: Int, Comparable {
    case sev1 = 1, sev2, sev3, sev4
    static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }
}

struct Impact {
    var affectedBasisPoints = 0      // share of active users: 100 = 1%
    var blocksCoreFlow = false
    var hasWorkaround = false
    var dataLoss = false
    var securityOrPrivacy = false
    var paymentsBroken = false
    var internalOnly = false
}

func classify(_ impact: Impact) -> Severity {
    if impact.internalOnly { return .sev4 }
    if impact.dataLoss || impact.securityOrPrivacy || impact.paymentsBroken { return .sev1 }
    if impact.blocksCoreFlow && !impact.hasWorkaround {
        return impact.affectedBasisPoints >= 500 ? .sev1 : .sev2
    }
    if impact.blocksCoreFlow || impact.affectedBasisPoints > 0 { return .sev3 }
    return .sev4
}

func response(_ severity: Severity) -> String {
    switch severity {
    case .sev1: return "page now, IC assigned, updates every 30 min, postmortem"
    case .sev2: return "page on-call, updates every 60 min, postmortem"
    case .sev3: return "ticket, business hours"
    case .sev4: return "backlog"
    }
}

let reports: [(String, Impact)] = [
    ("Crash on launch in 2.6.0, 1% rollout", Impact(affectedBasisPoints: 100, blocksCoreFlow: true)),
    ("Crash on launch in 2.6.0, 7% of actives", Impact(affectedBasisPoints: 700, blocksCoreFlow: true)),
    ("Chart labels overlap in German", Impact(affectedBasisPoints: 300)),
    ("Sign-in fails, password reset works", Impact(affectedBasisPoints: 900, blocksCoreFlow: true, hasWorkaround: true)),
    ("Logs include account numbers", Impact(affectedBasisPoints: 10, securityOrPrivacy: true)),
    ("TestFlight build won't open", Impact(affectedBasisPoints: 0, blocksCoreFlow: true, internalOnly: true)),
]

for (title, impact) in reports {
    let severity = classify(impact)
    print("SEV\(severity.rawValue)  \(title)")
    print("      \(response(severity))")
}
let worst = reports.map { classify($0.1) }.min()!
print("Highest severity open: SEV\(worst.rawValue)")
```

```output
SEV2  Crash on launch in 2.6.0, 1% rollout
      page on-call, updates every 60 min, postmortem
SEV1  Crash on launch in 2.6.0, 7% of actives
      page now, IC assigned, updates every 30 min, postmortem
SEV3  Chart labels overlap in German
      ticket, business hours
SEV3  Sign-in fails, password reset works
      ticket, business hours
SEV1  Logs include account numbers
      page now, IC assigned, updates every 30 min, postmortem
SEV4  TestFlight build won't open
      backlog
Highest severity open: SEV1
```

- **The order of the checks is the policy.** Internal-only comes first, so a broken TestFlight build is SEV4 even though it "blocks the core flow." Data, security and payments come next and override everything else, whatever the user count: 10 basis points (0.1%) of users with account numbers in logs is SEV1.
- **The same crash is SEV2 at a 1% phased rollout and SEV1 at 7%.** Phased release (Module 41) limits impact by design, and severity is about impact. If the rollout keeps going, the severity goes up; pausing it is a mitigation that keeps it down.
- **A workaround moves sign-in failure to SEV3** in this table. Your team might decide that a sign-in problem affecting 9% of users is never SEV3, workaround or not. That's the point of writing it down: the argument happens on a calm afternoon, not during the incident.
- **`Severity` is `Comparable` with SEV1 as the smallest**, so `min()` finds the most severe. Ordering the raw values that way matches how people talk ("SEV1 is the highest").

## Roles

The SRE book's core idea for managing incidents is a "recursive separation of responsibilities": "It's important to make sure that everybody involved in the incident knows their role and doesn't stray onto someone else's turf." Its four roles:

- **Incident command.** "The incident commander holds the high-level state about the incident." They assign roles, make decisions, and keep the incident document. They don't debug.
- **Operational work.** "The operations team should be the only group modifying the system during an incident." On mobile: the people flipping flags, pausing the release, changing the server and preparing the hotfix.
- **Communication.** The public face of the response, responsible for "issuing periodic updates to the incident response team and stakeholders." Support, product, leadership, and if needed, users.
- **Planning.** "The planning role supports Ops by dealing with longer-term issues," such as filing bugs, arranging handoffs, and "tracking how the system has diverged from the norm so it can be reverted once the incident is resolved."

On a team of three iOS engineers, one person will hold more than one role. Two combinations to avoid for more than a few minutes: the incident commander doing operational work (nobody is watching the whole picture while they're deep in a stack trace), and the person debugging also writing status updates (both get done badly).

Handoffs must be explicit. The SRE book: "the outgoing commander should be explicit in their handoff, specifically stating, 'You're now the incident commander, okay?', and should not leave the call until receiving firm acknowledgment of handoff." Then announce it in the channel so everyone knows who's leading.

### The incident document

"The incident commander's most important responsibility is to keep a living incident document." It "can be messy, but must be functional." A minimal one:

```markdown
# INC-2026-11-04: Crash on launch in 2.6.0

Severity: SEV2 (raised from SEV3 at 14:20 UTC)
Commander: Dana   Ops: Sam, Christian   Comms: Priya
Status: Mitigated, monitoring

## Current state
2.6.0 crashes at launch for users with more than 500 saved places.
Phased release paused at day 3 (5%). Flag `places-migration-v2` turned off
at 14:41 UTC; crash rate back to baseline at 14:55 UTC.

## Changes made (undo after resolution)
- 14:38 Phased release paused (App Store Connect).
- 14:41 Remote config: places-migration-v2 = false.

## Timeline (UTC)
- 13:52 Crash-free sessions alert for 2.6.0.
- 14:05 On-call acknowledges, starts investigating.
- 14:20 Declared incident, SEV2. Dana is IC.
- ...

## Next update: 15:30 UTC
```

"Changes made" is the planning role's list. After a mitigation-heavy night, it's the only reliable record of which flags are off, which rollouts are paused and which server settings are temporary.

## Communication

People outside the incident need four things, in every update:

1. **Impact**: who's affected and how, in user terms. "Users with more than 500 saved places can't open the app on 2.6.0," not "migration crash in `PlacesStore`."
2. **What's being done**, and any workaround support can give out.
3. **What isn't known yet.** Saying so is better than guessing.
4. **When the next update will come**, and then sending it at that time even if nothing changed. "No change, still working on X, next update at 16:00" stops people from interrupting the responders to ask.

Things to leave out: speculation about the cause, names of people who made the change, and promises about when the fix ships. For an App Store hotfix, the release time depends on App Review, which you don't control (Module 41); give the steps, not a date.

For mobile apps, the audience includes users who can't read your status page from inside a crashing app. Support needs a short, accurate reply they can paste; a non-crashing part of the app might show a banner from remote config; app store reviews will reflect the incident for a while, and replying to them after the fix ships is part of communication too.

## Mitigate first

The SRE book's first best practice: "Stop the bleeding, restore service, and preserve the evidence for root-causing." In that order.

| | Mitigation | Fix |
| --- | --- | --- |
| Goal | Stop user impact now | Remove the cause |
| Mobile examples | Flag off, pause phased release, server returns a safe response, raise minimum version only if the old one is harmful | Hotfix release with a test that reproduces the bug |
| Time | Minutes, if prepared in advance | Hours to days, including review |
| Risk | Low, if it's a switch you've tested | Higher: new code under pressure |

Mitigation works only if the switches exist before the incident: feature flags for risky features, server-controlled behavior, a tested way to pause rollouts. That's why "add a kill switch" shows up so often in postmortem action items.

"Preserve the evidence" means not destroying what you'll need to find the cause: download the crash logs and the organizer data before they age out, save the server responses, write down what the device looked like, and don't "fix" data by hand before copying it.

> [!warning] Don't start the hotfix as the mitigation
> A hotfix is the fix, not the mitigation. While it's in development and review, users are still affected. Start it in parallel if you like, but the first question is always "what can we switch off right now?"

## On-call that people can sustain

On-call means one person at a time is responsible for responding. A few practices make it work for a mobile team:

- **Alerts must be actionable.** Every page should be something the on-call person can and must act on. An alert that fires every night and gets acknowledged without action trains people to ignore the real one. Delete it or fix its threshold.
- **Alert on the new version, not the whole app.** Module 41's example took almost 22 hours to detect a crash because the alert watched the whole app's crash rate, and the new version was only at 1 to 2% of users.
- **Runbooks next to the alerts.** "Crash-free sessions alert: check the version breakdown in the crash reporter; if one version, pause its phased release; check which flags shipped in it…" Written on a calm day, read at 2 a.m.
- **Handoff notes at the end of each shift.** What happened, what's still open, which temporary changes are in place.
- **Escalation is expected.** On-call means you respond first, not that you solve everything alone. Paging a second person for a SEV1 is the process working.
- **Practice.** The SRE book: "Use the process routinely so it becomes second nature," and rotate roles: "Were you incident commander last time? Take on a different role this time." A tabletop exercise (walking through a fictional incident on paper) costs an hour and finds the missing runbook before a real incident does.
- **Keep the load sustainable.** Agree on how often each person is on call, what happens after a night of pages, and how on-call time is recognized. Those decisions are the team's and the company's to make; a rotation that burns people out stops working.

## Postmortems that change something

Module 41 covered the postmortem's structure: summary, timeline, detection, mitigation and resolution times, contributing factors, what went well, action items. Two more pieces come from the SRE book.

**Triggers, decided in advance.** The book lists common ones: "User-visible downtime or degradation beyond a certain threshold," "Data loss of any kind," "On-call engineer intervention (release rollback, rerouting of traffic, etc.)," "A resolution time above some threshold" and "A monitoring failure (which usually implies manual incident discovery)," adding that "any stakeholder may request a postmortem for an event." For a mobile team, pausing a phased release or turning off a flag in production is "on-call engineer intervention."

**Blameless, in practice.** "For a postmortem to be truly blameless, it must focus on identifying the contributing causes of the incident without indicting any individual or team for bad or inappropriate behavior. A blamelessly written postmortem assumes that everyone involved in an incident had good intentions and did the right thing with the information they had." The question isn't "who shipped the migration on the main thread?" but "what let a migration that blocks the main thread pass review, tests and a 1% rollout without anyone seeing it?"

### Action items

The postmortem's value is in its action items, and only if they get done. Good items:

- **Change a system**, not a person's behavior: "add a launch-time test with 1,000 saved places," not "be more careful with migrations."
- **Have one owner and a due date.** A team isn't an owner.
- **Cover more than prevention.** Ask three questions: what would have *prevented* it, what would have *detected* it sooner, what would have *mitigated* it faster? The flag that let you turn the feature off is a mitigation item from an earlier postmortem paying off.
- **Are tracked like other work**, in the same tracker, reviewed until closed. The SRE book's best practice is "No Postmortem Left Unreviewed"; the same goes for its action items.

A tracker can check those rules mechanically:

```swift
enum Kind: String { case prevent, detect, mitigate }

struct ActionItem {
    let title: String
    let kind: Kind
    let owner: String?
    let dueDay: Int        // days since the incident
    var done = false
}

func review(_ items: [ActionItem], today: Int) {
    var problems: [String] = []
    for item in items where !item.done {
        if item.owner == nil {
            problems.append("no owner: \(item.title)")
        } else if item.dueDay < today {
            problems.append("overdue by \(today - item.dueDay) days: \(item.title) (\(item.owner!))")
        }
    }
    let kinds = Set(items.map(\.kind))
    for kind in [Kind.prevent, .detect, .mitigate] where !kinds.contains(kind) {
        problems.append("no \(kind.rawValue) item")
    }
    let open = items.filter { !$0.done }.count
    print("Day \(today): \(items.count - open) of \(items.count) done")
    for problem in problems { print("  - \(problem)") }
}

var items = [
    ActionItem(title: "Run places migration off the main actor", kind: .prevent, owner: "Sam", dueDay: 7),
    ActionItem(title: "UI test: launch with 1,000 saved places", kind: .prevent, owner: "Christian", dueDay: 14),
    ActionItem(title: "Alert on crash-free sessions per app version", kind: .detect, owner: nil, dueDay: 10),
    ActionItem(title: "Be more careful with migrations", kind: .prevent, owner: "team", dueDay: 30),
]
items[0].done = true
review(items, today: 15)
```

```output
Day 15: 1 of 4 done
  - overdue by 1 days: UI test: launch with 1,000 saved places (Christian)
  - no owner: Alert on crash-free sessions per app version
  - no mitigate item
```

- **The detection item has no owner**, so it'll never be done. It's also the most valuable item here: Module 41's numbers showed detection was the slowest part.
- **No mitigation item**: nothing makes the next migration switchable. A flag around data migrations would be one.
- **"Be more careful with migrations" passes every check** (owner "team", not overdue) and is still useless. A tool catches missing fields; it can't catch a vague item. That's what the postmortem review is for. Rewrite it ("add 'runs off the main actor' to the review checklist for persistence changes") or delete it.
- **"overdue by 1 days"** reads badly. Handling the plural is a one-line fix you'll do in an exercise below.

## Common mistakes

> [!error] Debugging for hours before declaring
> If it's visible to users, declare. A declared incident that turns out small is downgraded in a minute; an undeclared one leaves support and leadership with nothing for hours.

> [!error] Severity from the loudest voice
> An executive's broken screen isn't automatically SEV1, and a quiet privacy leak isn't SEV3. Classify from impact with the table you agreed on.

> [!error] The incident commander debugging
> When the commander opens Xcode, nobody is tracking the state, assigning work or deciding what's next. Hand off operations or hand off command, explicitly.

> [!error] Status updates with a cause and an ETA
> "It's a bug in Sam's migration, fixed by 5 p.m." is likely wrong on both counts and names a person. Give the impact, the actions and the time of the next update.

> [!error] Forgetting the temporary changes
> Flags turned off and rollouts paused during the incident stay that way for months if nobody wrote them down. Keep the "changes made" list and undo each item when you resolve.

> [!error] Action items nobody owns
> A postmortem with "the team" as owner, or no date, produces a document instead of a change. One person, one date, tracked until closed.

## Exercises

````exercise
id: m49-l04-e1
type: comprehension
prompt: "Using the SRE book's criteria, which of these should be declared an incident?"
choices:
  - text: "A teammate notices that a debug menu shows a typo in a TestFlight build."
    correct: false
    why: "Not visible to customers, needs no second team, and it's not an unsolved problem."
  - text: "Users report that pull-to-refresh shows stale balances; the iOS team has spent 75 minutes on it and suspects a server cache, which another team owns."
    correct: true
    why: "It's visible to customers, needs a second team, and is unsolved after an hour. Any one of these is enough."
  - text: "A unit test is flaky on CI."
    correct: false
    why: "Annoying and worth a ticket, but not user-visible."
  - text: "An App Store review mentions that the app icon looks blurry on one device."
    correct: false
    why: "Cosmetic and worth investigating, but it doesn't meet the criteria by itself."
solution: |
  **The stale balances.** All three criteria hold, and one would have been enough: customers see it, the fix probably needs the server team, and it's been more than an hour.

  Declaring it brings in the server team with a clear owner, starts status updates for support (who are getting questions about wrong balances) and starts the timeline for the postmortem.
````

````exercise
id: m49-l04-e2
type: prediction
prompt: "A simpler classifier. What does this program print?"
code: |
  func severity(basisPoints: Int, privacy: Bool, workaround: Bool) -> Int {
      if privacy { return 1 }
      if workaround { return 3 }
      return basisPoints >= 500 ? 1 : 2
  }

  print(severity(basisPoints: 499, privacy: false, workaround: false))
  print(severity(basisPoints: 500, privacy: false, workaround: false))
  print(severity(basisPoints: 9_000, privacy: false, workaround: true))
  print(severity(basisPoints: 1, privacy: true, workaround: true))
output: |
  2
  1
  3
  1
hints:
  - "The checks run in order, and the first `return` wins."
  - "500 basis points is 5%."
solution: |
  ```output
  2
  1
  3
  1
  ```

  1. 4.99%, no workaround: below the threshold, SEV2.
  2. Exactly 5%: `>=` includes it, SEV1.
  3. 90% of users with a workaround: the workaround check comes before the share check, so SEV3. That's the result of the order of the checks, and many teams would consider it wrong: a workaround that 90% of users need is barely a workaround. Policies written as code make that kind of question visible.
  4. Privacy overrides everything: SEV1, even for one basis point and with a workaround.
````

````exercise
id: m49-l04-e3
type: find-errors
prompt: "A status update posted 40 minutes into an incident. Mark every real problem."
code: |
  Update 2 (14:45 UTC)
  Sam's change to PlacesStore broke the migration. We're debugging the stack
  trace in PlacesMigrator.swift:212. Should be fixed by 5pm with the hotfix.
  More soon.
choices:
  - text: "Names a person as the cause."
    correct: true
  - text: "Describes the problem in code terms instead of user impact (who's affected, what they see)."
    correct: true
  - text: "Promises a time for a hotfix that depends on App Review."
    correct: true
  - text: "No time for the next update ('More soon')."
    correct: true
  - text: "Doesn't mention mitigation or a workaround for support."
    correct: true
  - text: "Uses UTC instead of local time."
    correct: false
rubric:
  - I flagged naming a person.
  - I flagged the missing user impact.
  - I flagged the hotfix ETA.
  - I flagged the missing next update time.
  - I flagged the missing mitigation or workaround.
solution: |
  A rewrite:

  > **Update 2 (14:45 UTC).** Users with more than 500 saved places can't open the app on version 2.6.0 (about 5% of 2.6.0 users; 2.6.0 is at 5% of the phased release). We paused the phased release at 14:38 and turned off the new places migration remotely at 14:41; we're confirming that this stops the crashes. Workaround for support: none needed after the flag change; affected users should force-quit and reopen. A fixed version is in progress; its release time depends on App Review. **Next update: 15:30 UTC.**

  UTC is the right choice for a team in several time zones; it's also what the timeline uses.
````

````exercise
id: m49-l04-e4
type: solve
prompt: |
  Write `overdueReport(_:today:)` for action items given as `(title: String, owner: String, dueDay: Int, done: Bool)`. It returns one line per open item that's past due, sorted with the most overdue first (ties keep input order), as `"<owner>: <title> (N day overdue)"` with "day" for 1 and "days" otherwise. If nothing is overdue, return `["Nothing overdue"]`.

  ```swift
  let items = [
      (title: "Alert per version", owner: "Priya", dueDay: 10, done: false),
      (title: "Launch UI test", owner: "Christian", dueDay: 14, done: false),
      (title: "Migration off main actor", owner: "Sam", dueDay: 7, done: true),
      (title: "Flag around migrations", owner: "Dana", dueDay: 12, done: false),
  ]
  for line in overdueReport(items, today: 15) { print(line) }
  print(overdueReport(items, today: 5))
  ```

  should print:

  ```output
  Priya: Alert per version (5 days overdue)
  Dana: Flag around migrations (3 days overdue)
  Christian: Launch UI test (1 day overdue)
  ["Nothing overdue"]
  ```
starter: |
  func overdueReport(_ items: [(title: String, owner: String, dueDay: Int, done: Bool)], today: Int) -> [String] {
      return []
  }
rubric:
  - Skips done items and items not yet due.
  - Sorts by days overdue, descending, keeping input order on ties.
  - Pluralizes day and days correctly.
  - Returns the "Nothing overdue" line when the list would be empty.
hints:
  - "Sort by a tuple that includes the original position, as in lesson 1, so ties are stable."
solution: |
  ```swift
  func overdueReport(_ items: [(title: String, owner: String, dueDay: Int, done: Bool)], today: Int) -> [String] {
      let overdue = items.enumerated()
          .filter { !$0.element.done && $0.element.dueDay < today }
          .sorted { ($0.element.dueDay, $0.offset) < ($1.element.dueDay, $1.offset) }
      if overdue.isEmpty { return ["Nothing overdue"] }
      return overdue.map { entry in
          let days = today - entry.element.dueDay
          return "\(entry.element.owner): \(entry.element.title) (\(days) \(days == 1 ? "day" : "days") overdue)"
      }
  }

  let items = [
      (title: "Alert per version", owner: "Priya", dueDay: 10, done: false),
      (title: "Launch UI test", owner: "Christian", dueDay: 14, done: false),
      (title: "Migration off main actor", owner: "Sam", dueDay: 7, done: true),
      (title: "Flag around migrations", owner: "Dana", dueDay: 12, done: false),
  ]
  for line in overdueReport(items, today: 15) { print(line) }
  print(overdueReport(items, today: 5))
  ```

  ```output
  Priya: Alert per version (5 days overdue)
  Dana: Flag around migrations (3 days overdue)
  Christian: Launch UI test (1 day overdue)
  ["Nothing overdue"]
  ```

  - Sorting by ascending `dueDay` puts the earliest due date, which is the most overdue, first. The offset breaks ties in input order.
  - Sam's item is overdue by date but done, so it's skipped.
  - In an app, plural rules belong in a String Catalog or automatic grammar agreement, because other languages don't follow English's one-or-many rule. For an internal report, the ternary is fine.
````

````exercise
id: m49-l04-e5
type: design
prompt: "Your team is three iOS engineers and one backend engineer, with no incident process. Write a one-page process: when to declare, severity levels with responses, who takes which role in a small incident, the status update template, where the incident document lives, and when a postmortem is required."
rubric:
  - Declaration criteria are written down and include customer visibility.
  - Severity levels are defined by impact (users, data, security, payments, workaround) and each maps to a response.
  - Roles are assigned so the incident commander doesn't also debug, with an explicit handoff rule.
  - The update template has impact, actions, unknowns and the next update time.
  - Postmortem triggers are listed, and action items have owners, dates and a review.
  - "Mobile specifics appear: flags, phased release, App Review timing."
solution: |
  A model process:

  **Declare** if any of: users can see it; it needs the backend engineer and an iOS engineer together; it's unsolved after an hour. Anyone can declare by posting `/incident` in #mobile and creating the document from the template.

  **Severity** (adapt the lesson's table): SEV1 for data, privacy, payments, or a blocked core flow for 5%+ of users; SEV2 for a blocked core flow for fewer users; SEV3 with a workaround; SEV4 cosmetic or internal. SEV1: all four people paged, updates every 30 minutes. SEV2: on-call plus one, hourly updates.

  **Roles.** The person on call starts as incident commander. As soon as a second person joins, the on-call engineer hands command over or keeps command and hands off the debugging, explicitly ("You're now IC, okay?"), announced in the channel. With three people: IC (also comms), ops (flags, release, server), and an investigator. The backend engineer takes ops for server-side mitigations.

  **Updates** use: impact in user terms; what we've done; what we don't know; workaround for support; next update time. No cause speculation, no names, no hotfix dates.

  **Document** in the team's shared docs folder, from a template with current state, changes made (to undo), timeline in UTC, next update.

  **Mitigation first:** flag, pause phased release, server change. The hotfix starts in parallel, never instead.

  **Postmortem** required for SEV1 and SEV2, any data loss, any production flag change or release pause, and any incident found by a user rather than an alert. Blameless, written within five working days, reviewed in the next team meeting. Action items have one owner and a date, live in the normal tracker, and are reviewed weekly until closed.
````

## Summary

- Declare incidents by written criteria: visible to customers, needs a second team, or unsolved after an hour. Declaring early is cheap.
- Severity comes from impact (users, data, security, payments, workarounds) and decides the response. Define your levels in advance; writing them as code exposes the edge cases.
- Separate roles: a commander who holds the state, operations who alone change the system, communication, and planning, which tracks the temporary changes. Hand off explicitly.
- Status updates give impact, actions, unknowns and the next update time. No causes, names or release dates.
- Mitigate before fixing: "Stop the bleeding, restore service, and preserve the evidence." On mobile that's flags, phased release pauses and server changes, prepared before the incident.
- On-call works when alerts are actionable, runbooks exist, handoffs are written and the load is sustainable.
- Postmortems are blameless and pay off through action items with one owner, a date and a review, covering prevention, detection and mitigation.
