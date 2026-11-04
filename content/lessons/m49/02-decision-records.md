---
id: m49-l02
title: Architecture decision records
description: "An architecture decision record is a short file that says what you decided, why, and what it cost, written for the developer who joins after you. You learn Michael Nygard's format (title, context, decision, status, consequences), which decisions deserve one, how to write them for real choices from the course's apps (the Keychain for tokens, @Observable view models, a JSON cache later replaced by SwiftData), and how to supersede a decision without rewriting history. The status lifecycle is modeled in Swift, compiled and run."
module: m49
order: 2
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m49-l01]
objectives:
  - Explain what problem an architecture decision record solves for a team and for a future reader.
  - Write an ADR with title, context, decision, status and consequences, including alternatives you rejected.
  - Decide whether a choice is significant enough to record.
  - Supersede or deprecate a decision without editing the original record's reasoning.
  - Model the ADR status lifecycle and reject invalid transitions.
terms:
  - term: Architecture decision record (ADR)
    definition: "A short, numbered document that records one significant decision: the forces behind it, the decision, its status and its consequences."
  - term: Architecturally significant
    definition: "In Nygard's words, decisions that affect 'the structure, non-functional characteristics, dependencies, interfaces, or construction techniques' of a system."
  - term: Superseded
    definition: "The status of an ADR whose decision a later ADR replaced. The old record stays, with a link to its replacement."
  - term: Deprecated
    definition: "The status of an ADR whose decision no longer applies but wasn't replaced by a new one, for example because the feature it covered was removed."
  - term: Consequences
    definition: "The section of an ADR that describes the situation after the decision, including the costs and the negative effects, not just the benefits."
mastery:
  - Write a one-page ADR for a decision in your capstone, with at least two rejected alternatives.
  - Look at a list of upcoming choices and say which ones need an ADR and why.
  - Supersede an accepted ADR, updating the status of the old one and the context of the new one.
  - Explain why an ADR's decision text isn't edited after acceptance.
  - Implement a status model where invalid transitions fail.
resources: [nygard-adr, swift-evolution, security-storing-keys-keychain, observation, swiftdata, swift-book-enumerations]
cards:
  - id: m49-l02-c1
    front: What are the five sections of a Nygard-style ADR?
    back: "Title (a short noun phrase), Context (the forces at play, stated neutrally), Decision (\"We will…\"), Status (proposed, accepted, deprecated, superseded) and Consequences (all of them, not just the positive ones)."
  - id: m49-l02-c2
    front: When is a decision worth an ADR?
    back: "When it's architecturally significant: it affects structure, non-functional characteristics, dependencies, interfaces or construction techniques. In practice: it's expensive to reverse, it spans modules, it adds a dependency, or someone will ask \"why?\" in six months."
  - id: m49-l02-c3
    front: How do you change an accepted decision?
    back: "Write a new ADR with the new decision and a context that explains what changed. Mark the old one \"Superseded by ADR-N\" and leave its reasoning as it was. Numbers are never reused."
  - id: m49-l02-c4
    front: Why should Consequences include the downsides?
    back: "Because they're the part a future reader needs most: they tell them which costs were accepted on purpose, and when the context has changed enough that the decision should be revisited."
  - id: m49-l02-c5
    front: Where do ADRs live?
    back: "In the repository, next to the code, as numbered Markdown files (Nygard proposed doc/arch/adr-NNN.md; docs/adr/ is common). They're reviewed in pull requests like code."
---

## The idea in one sentence

An ADR records one significant decision in a page or two (the forces, the choice, its status and everything it costs) so that whoever reads the code later can tell whether the decision still holds instead of guessing.

> [!note] Sources and what was checked
> The format and the quotations come from Michael Nygard's article "Documenting Architecture Decisions" (cognitect.com, November 15, 2011), read in November 2026. The example ADRs are written for this course's projects; they aren't from any company. The Swift blocks are models, compiled and run with Swift 6.3.

## The problem ADRs solve

Open Project 4's code a year after you wrote it. The latest results are cached as JSON files in the Caches directory. Why not Core Data? Why Caches and not Application Support? If you don't remember, you have, as Nygard put it, two choices:

> "Blindly accept the decision. [...] Blindly change it."

Accepting it blindly is fine while the reasons still hold, but "if the project accumulates too many decisions accepted without understanding, then the development team becomes afraid to change anything." Changing it blindly risks "damaging the project's overall value without realizing it": maybe Caches was chosen precisely because iOS may purge it under storage pressure and the data could always be fetched again.

The reasons rarely survive in the code. A comment explains a line, a commit message explains a change, a pull request explains a feature. None of them is the place for "we compared three persistence options and here's why we picked this one." An ADR is.

## The format

Nygard's format has five parts, and he kept it short on purpose: "The whole document should be one or two pages long."

- **Title.** "These documents have names that are short noun phrases." Numbered: `ADR 1: Keychain for the session token`.
- **Context.** "This section describes the forces at play, including technological, political, social, and project local. These forces are probably in tension, and should be called out as such. The language in this section is value-neutral. It is simply describing facts."
- **Decision.** "This section describes our response to these forces. It is stated in full sentences, with active voice. 'We will …'"
- **Status.** "A decision may be 'proposed' if the project stakeholders haven't agreed with it yet, or 'accepted' once it is agreed. If a later ADR changes or reverses a decision, it may be marked as 'deprecated' or 'superseded' with a reference to its replacement."
- **Consequences.** "This section describes the resulting context, after applying the decision. All consequences should be listed here, not just the 'positive' ones."

Two additions many teams make, and Project 7's first milestone asks for the first one:

- **Alternatives considered**, each with the reason it lost. Without them, a reader can't tell whether the obvious option was rejected or never thought of.
- **A date and the people involved**, so the reader knows how old the context is.

Nygard also wrote that each ADR is "a conversation with a future developer," in full sentences, not bullet fragments. Keep that: a context section made of three bullet points is usually missing the tension between them.

### Where they live

In the repository, next to the code, as Markdown. Nygard's article proposed `doc/arch/adr-NNN.md`; `docs/adr/0001-keychain-for-session-token.md` is a common variant. Two rules from the article matter more than the folder name: ADRs "will be numbered sequentially and monotonically. Numbers will not be reused," and "if a decision is reversed, we will keep the old one around, but mark it as superseded."

Because they're files in the repository, ADRs go through pull requests. A common workflow: open the PR with the status **Proposed**, discuss it in review, and change it to **Accepted** in the commit that merges. The review thread then holds the debate, and the ADR holds the outcome.

## Which decisions deserve one

Nygard's test is whether the decision is "architecturally significant": it affects "the structure, non-functional characteristics, dependencies, interfaces, or construction techniques." In an iOS app, that tends to mean:

| Write an ADR | Don't |
| --- | --- |
| Persistence technology (SwiftData, Core Data, files, SQLite) | Naming a view model |
| Where secrets and tokens are stored | Which SF Symbol a button uses |
| UI framework per feature (UIKit, SwiftUI, hybrid) | Formatting rules a linter enforces |
| Adding a third-party dependency | Choosing between two equivalent standard-library methods |
| Module boundaries and what may depend on what | A bug fix, even a big one |
| Minimum deployment target | Anything you'd change in an afternoon without asking anyone |
| How the app talks to the server (pagination, auth, versioning) | |

A shortcut: **write one when reversing the decision would take more than a day, or when someone will reasonably ask "why did we do it this way?" in six months.** If you're unsure, write a short one. A ten-line ADR costs less than an hour of archaeology later.

## Examples from the course's apps

### A full ADR: the session token (Project 7)

```markdown
# ADR 1: Keychain for the session token

Date: 2026-09-14
Status: Accepted
Deciders: Christian

## Context

The finance app signs in against the bank sandbox and receives a session token
that is valid for 30 days. The app needs the token on launch to show balances
without asking the user to sign in again. The token grants read access to
account data, so anyone who obtains it can read the user's balances.

UserDefaults is the simplest storage and is already used for preferences, but it
is a plist inside the app container and is included in device backups,
including unencrypted ones. The
Keychain is encrypted by the system and supports accessibility classes that
control when an item can be read and whether it migrates to another device.
Project 7 requires that a device backup reveals no tokens.

## Decision

We will store the session token in the Keychain as a generic password with
kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly. All access goes through a
TokenStore protocol so the domain and tests never touch the Keychain directly.
We will not log the token or any prefix of it.

## Alternatives considered

- UserDefaults: rejected. Readable from backups, which violates the acceptance
  criterion on backups.
- A file with Data Protection (complete): rejected. The app refreshes balances
  in the background, when complete protection would make the file unreadable.
- Keychain with kSecAttrAccessibleWhenUnlocked: rejected for now. Same
  background refresh problem, and it would migrate to a new device through
  encrypted backups, which we don't want for a session token.

## Consequences

- The token survives app updates and relaunches, and isn't restored onto a new
  device, so users sign in again after migrating. Accepted on purpose.
- The token is readable after the first unlock until the device restarts,
  including while locked. That's what background refresh needs, and a wider
  window than "when unlocked."
- Keychain items aren't removed with the app's container, so a token can
  outlive an uninstall. Sign-out must delete the item explicitly, and the first
  launch after a reinstall should clear stale items.
- Unit tests use an in-memory TokenStore; one integration test on a device
  exercises the real Keychain.
```

Notice what the consequences do: two of the four are costs. The "users sign in again after migrating" line is the one a product manager will ask about one day, and the ADR shows it was a choice, not an oversight. The line about outliving an uninstall turns into a task. The specific behavior of each accessibility constant is in Apple's Keychain documentation (the resources for this lesson); check it there rather than from memory when you write your own.

### Short ADRs for the other projects

Not every ADR needs a full page. These are the context and decision only, for decisions you've already made in earlier projects:

- **ADR 2: `@Observable` view models for SwiftUI screens** (Project 5). *Context:* the data layer from Project 4 is reused unchanged; SwiftUI views need a model they can observe; the deployment target is iOS 17, so Observation is available. *Decision:* we will use one `@Observable` class per screen, created by the parent and passed in, holding view state and calling the repository. *Consequences:* views stay thin and previews can inject a fake repository; property-level tracking means views re-render only for properties they read; iOS 16 is out of reach without a rewrite of the models.
- **ADR 3: Cache the latest results as JSON files in Caches** (Project 4). *Context:* the app shows the last page of results offline; results can always be fetched again; no user edits are stored. *Decision:* we will encode the latest results with `JSONEncoder` into one file per query in the Caches directory. *Consequences:* trivial to implement and test; the system may delete the files when storage is low, which is acceptable because they can be refetched; no queries or relationships, so if the app ever stores user data, this decision has to be revisited.

ADR 3's last consequence is a prediction, and it comes true.

### Superseding a decision

Months later the catalog app gets favorites: books the user marks, with notes, kept forever and filtered by author. That's user data that can't be refetched, in a directory iOS may purge, with queries JSON files can't answer. ADR 3's context has changed.

You don't edit ADR 3. You write ADR 6, and you change exactly one line of ADR 3:

```markdown
# ADR 3: Cache the latest results as JSON files in Caches

Date: 2026-05-02
Status: Superseded by ADR 6
```

```markdown
# ADR 6: SwiftData for favorites and cached results

Date: 2026-10-20
Status: Accepted
Supersedes: ADR 3

## Context

ADR 3 chose JSON files in Caches because the app stored nothing that couldn't be
refetched. Favorites change that: they're user data with notes, they must
survive storage pressure, and users filter them by author. [...]
```

Why keep ADR 3 at all? Nygard: "It's still relevant to know that it was the decision, but is no longer the decision." Someone reading the git history of the cache code will see JSON files until October; ADR 3 explains them. And the reasoning in ADR 3 was right for its context. Rewriting it to look like you always knew about favorites would remove the record of how the context changed.

**Deprecated** is for a decision that stops applying without a replacement: if the app dropped offline support entirely, ADR 3 would be deprecated, with a note saying why.

## The status lifecycle in Swift

The lifecycle is small enough to model and test. A proposed ADR is accepted or rejected; an accepted one may later be deprecated or superseded; the last three are final. (Rejected isn't in Nygard's list, but teams that review ADRs in pull requests often keep rejected proposals, because "we considered this and said no" is worth recording too.)

```swift
enum Status: Equatable {
    case proposed
    case accepted
    case rejected
    case deprecated
    case superseded(by: Int)
}

func canMove(from current: Status, to next: Status) -> Bool {
    switch (current, next) {
    case (.proposed, .accepted), (.proposed, .rejected):
        return true
    case (.accepted, .deprecated), (.accepted, .superseded):
        return true
    default:
        return false
    }
}

struct Record {
    let number: Int
    let title: String
    var status: Status
}

func label(_ number: Int) -> String {
    let digits = String(number)
    return "ADR-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
}

func describe(_ status: Status) -> String {
    switch status {
    case .proposed: return "Proposed"
    case .accepted: return "Accepted"
    case .rejected: return "Rejected"
    case .deprecated: return "Deprecated"
    case .superseded(let number): return "Superseded by \(label(number))"
    }
}

struct DecisionLog {
    private(set) var records: [Record] = []

    mutating func propose(_ title: String) -> Int {
        let next = (records.map(\.number).max() ?? 0) + 1
        records.append(Record(number: next, title: title, status: .proposed))
        return next
    }

    mutating func move(_ number: Int, to status: Status) -> Bool {
        guard let index = records.firstIndex(where: { $0.number == number }),
              canMove(from: records[index].status, to: status) else { return false }
        records[index].status = status
        return true
    }

    mutating func supersede(_ old: Int, with new: Int) -> Bool {
        guard let replacement = records.first(where: { $0.number == new }),
              replacement.status == .accepted else { return false }
        return move(old, to: .superseded(by: new))
    }

    func index() -> [String] {
        records.map { "\(label($0.number))  \(describe($0.status))  \($0.title)" }
    }
}

var log = DecisionLog()
let keychain = log.propose("Keychain for the session token")
let observable = log.propose("@Observable view models")
let jsonCache = log.propose("JSON cache in Caches")
let realm = log.propose("Third-party database for the cache")
for number in [keychain, observable, jsonCache] { _ = log.move(number, to: .accepted) }
_ = log.move(realm, to: .rejected)

let swiftData = log.propose("SwiftData for favorites and cache")
print("Supersede before accepting:", log.supersede(jsonCache, with: swiftData))
_ = log.move(swiftData, to: .accepted)
print("Supersede after accepting:", log.supersede(jsonCache, with: swiftData))
print("Reopen a rejected ADR:", log.move(realm, to: .accepted))
print("Supersede twice:", log.supersede(jsonCache, with: swiftData))
for line in log.index() { print(line) }
```

```output
Supersede before accepting: false
Supersede after accepting: true
Reopen a rejected ADR: false
Supersede twice: false
ADR-001  Accepted  Keychain for the session token
ADR-002  Accepted  @Observable view models
ADR-003  Superseded by ADR-005  JSON cache in Caches
ADR-004  Rejected  Third-party database for the cache
ADR-005  Accepted  SwiftData for favorites and cache
```

- **`canMove` switches on a tuple** of the two statuses. The listed pairs are the only legal moves; everything else, including any move out of a final status, falls to `default`.
- **`(.accepted, .superseded)` matches any replacement number**, because the pattern `.superseded` without a binding ignores the associated value.
- **Numbers come from the maximum plus one,** never from `records.count + 1`. If a record were ever removed from the array, `count + 1` would reuse a number, which is exactly what Nygard's rule forbids.
- **`supersede` requires the replacement to be accepted first.** A proposal can't replace an accepted decision; until ADR 5 is agreed, ADR 3 is still the decision.
- **Superseding twice fails** because ADR 3 is already `.superseded`, a final status. If ADR 5 is later replaced too, you supersede ADR 5, not ADR 3 again.
- **To reopen a rejected idea, propose a new ADR** whose context explains what changed. "Reopen a rejected ADR" fails on purpose.

> [!error] error: switch must be exhaustive
> The `describe` function has no `default:` case. That's deliberate: when someone adds a status, every exhaustive switch over `Status` stops compiling until it handles the new case. A `default:` would have compiled and quietly shown the wrong label.

Here's what Swift 6.3 says if you add `.amended` to the enum without updating the switch:

```swift no-compile switch must be exhaustive
enum Status { case proposed, accepted, rejected, deprecated, amended }

func describe(_ status: Status) -> String {
    switch status {
    case .proposed: return "Proposed"
    case .accepted: return "Accepted"
    case .rejected: return "Rejected"
    case .deprecated: return "Deprecated"
    }
}
print(describe(.amended))
```

In `canMove`, by contrast, `default: return false` is right: "anything not listed is forbidden" is the rule you want for transitions.

## Common mistakes

> [!error] Editing an accepted ADR to match the new decision
> The record of why the old decision made sense disappears, and the history of the code no longer matches any ADR. Write a new one and mark the old one superseded. Fixing a typo or a broken link is fine; changing the decision or its reasoning isn't.

> [!error] Consequences with only benefits
> "Simple, fast, testable" tells a reader nothing they'll need. Nygard: "All consequences should be listed here, not just the 'positive' ones." The costs are what tell the next developer when to revisit the decision.

> [!error] A context that argues for the answer
> If the context reads like a sales pitch for the decision, the alternatives were never really in play. State the forces neutrally, including the ones that pull the other way, then decide.

> [!error] Writing ADRs after the fact, all at once
> Ten ADRs written the week before the final review reconstruct reasons you've half forgotten. Write each one when you make the decision, as part of the pull request that implements it.

> [!error] One ADR for many decisions
> "ADR 1: Architecture" covering persistence, networking and navigation can't be superseded in part. One decision per record.

## Exercises

````exercise
id: m49-l02-e1
type: comprehension
multiple: true
prompt: "Which of these choices in your capstone deserve an ADR? Select all that apply."
choices:
  - text: "Using SwiftData instead of Core Data or files for check-ins."
    correct: true
    why: "Persistence is expensive to reverse and shapes the domain and tests."
  - text: "Adding a third-party charting package for the weekly chart."
    correct: true
    why: "A new dependency affects builds, licensing, updates and app size."
  - text: "Renaming HabitListViewModel to HabitsViewModel."
    correct: false
    why: "A rename is cheap to reverse and needs no explanation beyond the commit."
  - text: "Splitting the app into a domain package and an app target, with the rule that the domain can't import SwiftUI."
    correct: true
    why: "Module boundaries and dependency rules are structural, and people will ask why."
  - text: "Fixing a crash when the habit list is empty."
    correct: false
    why: "A bug fix belongs in the commit message and the pull request, and maybe a test."
  - text: "Setting the minimum deployment target to iOS 17."
    correct: true
    why: "It decides which APIs you can use and who can install the app; changing it later is a product decision."
solution: |
  ADRs for persistence, the charting dependency, the module rule and the deployment target. Each is expensive to reverse or will raise "why?" later.

  The rename and the crash fix are ordinary changes: the commit message explains them, and an ADR would bury the important records in noise.
````

````exercise
id: m49-l02-e2
type: prediction
prompt: "Using a smaller version of the status rules, what does this program print?"
code: |
  enum Status: Equatable { case proposed, accepted, rejected, deprecated, superseded }

  func canMove(from current: Status, to next: Status) -> Bool {
      switch (current, next) {
      case (.proposed, .accepted), (.proposed, .rejected): return true
      case (.accepted, .deprecated), (.accepted, .superseded): return true
      default: return false
      }
  }

  var status = Status.proposed
  for next in [Status.deprecated, .accepted, .accepted, .superseded, .accepted] {
      if canMove(from: status, to: next) {
          status = next
          print("now \(next)")
      } else {
          print("refused \(next)")
      }
  }
output: |
  refused deprecated
  now accepted
  refused accepted
  now superseded
  refused accepted
hints:
  - "Moving from a status to itself isn't in the list of allowed pairs."
  - "Interpolating an enum case without associated values prints its name."
solution: |
  ```output
  refused deprecated
  now accepted
  refused accepted
  now superseded
  refused accepted
  ```

  1. Proposed to deprecated: not allowed (only accepted decisions can be deprecated).
  2. Proposed to accepted: allowed.
  3. Accepted to accepted: not in the list, so refused. A model that allows no-op transitions would print "now accepted" twice, which can hide bugs in the code that calls it.
  4. Accepted to superseded: allowed.
  5. Superseded to accepted: superseded is final.
````

````exercise
id: m49-l02-e3
type: fill-in
prompt: "Complete the description of Nygard's ADR sections."
code: |
  Title: a short [[1]] phrase, numbered.
  Context: the forces at play, described in [[2]] language.
  Decision: full sentences in active voice, starting "We [[3]] …".
  Status: proposed, accepted, deprecated or [[4]].
  Consequences: [[5]] the consequences, not just the positive ones.
blanks:
  - id: "1"
    answers: ["noun"]
  - id: "2"
    answers: ["value-neutral", "neutral"]
  - id: "3"
    answers: ["will"]
  - id: "4"
    answers: ["superseded"]
  - id: "5"
    answers: ["all"]
solution: |
  - **Title:** "These documents have names that are short noun phrases."
  - **Context:** "The language in this section is value-neutral. It is simply describing facts."
  - **Decision:** "It is stated in full sentences, with active voice. 'We will …'"
  - **Status:** proposed, accepted, and later deprecated or superseded "with a reference to its replacement."
  - **Consequences:** "All consequences should be listed here, not just the 'positive' ones."
````

````exercise
id: m49-l02-e4
type: find-errors
prompt: "A teammate's ADR draft. Mark every real problem."
code: |
  # ADR 4: Architecture

  Status: Accepted

  ## Context
  - SwiftUI is the future.
  - Combine is old.
  - We like clean code.

  ## Decision
  SwiftUI everywhere, MVVM, SwiftData, and the new networking layer.

  ## Consequences
  - Modern, clean and testable.
choices:
  - text: "The title isn't a short noun phrase for one decision; the ADR covers four decisions at once."
    correct: true
  - text: "The context argues for an answer instead of describing the forces neutrally, and gives no facts about the app."
    correct: true
  - text: "The decision isn't written as full sentences in active voice."
    correct: true
  - text: "The consequences list only benefits."
    correct: true
  - text: "There are no alternatives considered."
    correct: true
  - text: "ADRs must be numbered starting at 0, not 1."
    correct: false
rubric:
  - I flagged that one ADR covers several decisions.
  - I flagged the non-neutral, fact-free context.
  - I flagged the fragment decision.
  - I flagged consequences with only benefits.
  - I flagged the missing alternatives.
solution: |
  Five problems:

  - **Four decisions in one record.** Split into "SwiftUI for new screens," "MVVM with `@Observable`," "SwiftData for persistence," and one for the networking layer. Each can then be superseded on its own.
  - **The context is opinion.** "The future," "old," "we like" aren't forces. Facts would be: deployment target, the team's experience, existing UIKit screens, testing needs.
  - **The decision is a fragment.** "We will build new screens in SwiftUI and host them in the existing UIKit navigation until…" says what will actually happen.
  - **Consequences are all upside.** What about existing UIKit screens, iOS versions left behind, a learning curve, a migration cost?
  - **No alternatives.** A reader can't tell whether UIKit, or keeping Combine, was considered.

  Numbering is a team convention; Nygard's examples start at 1. What matters is that numbers increase and aren't reused.
````

````exercise
id: m49-l02-e5
type: solve
prompt: |
  Write `supersede(_:old:new:)` for a plain array of `(number: Int, status: String)` records. It returns `true` and updates the array only when the old record's status is `"Accepted"` and the new record's status is `"Accepted"`; the old record's status becomes `"Superseded by ADR <new>"`. Otherwise it returns `false` and leaves the array unchanged.

  ```swift
  var records = [(number: 1, status: "Accepted"), (number: 2, status: "Proposed"), (number: 3, status: "Accepted")]
  print(supersede(&records, old: 1, new: 2))
  print(supersede(&records, old: 1, new: 3))
  print(supersede(&records, old: 1, new: 3))
  print(supersede(&records, old: 9, new: 3))
  for record in records { print(record.number, record.status) }
  ```

  should print:

  ```output
  false
  true
  false
  false
  1 Superseded by ADR 3
  2 Proposed
  3 Accepted
  ```
starter: |
  func supersede(_ records: inout [(number: Int, status: String)], old: Int, new: Int) -> Bool {
      return false
  }
rubric:
  - Finds both records by number and returns false if either is missing.
  - Requires both to be accepted.
  - Updates only the old record's status, and only on success.
hints:
  - "`firstIndex(where:)` gives you an index you can use to change the element in place."
solution: |
  ```swift
  func supersede(_ records: inout [(number: Int, status: String)], old: Int, new: Int) -> Bool {
      guard let oldIndex = records.firstIndex(where: { $0.number == old }),
            let newIndex = records.firstIndex(where: { $0.number == new }),
            records[oldIndex].status == "Accepted",
            records[newIndex].status == "Accepted" else {
          return false
      }
      records[oldIndex].status = "Superseded by ADR \(new)"
      return true
  }

  var records = [(number: 1, status: "Accepted"), (number: 2, status: "Proposed"), (number: 3, status: "Accepted")]
  print(supersede(&records, old: 1, new: 2))
  print(supersede(&records, old: 1, new: 3))
  print(supersede(&records, old: 1, new: 3))
  print(supersede(&records, old: 9, new: 3))
  for record in records { print(record.number, record.status) }
  ```

  ```output
  false
  true
  false
  false
  1 Superseded by ADR 3
  2 Proposed
  3 Accepted
  ```

  - The first call fails because ADR 2 is only proposed.
  - The second succeeds and rewrites ADR 1's status.
  - The third fails because ADR 1 is no longer `"Accepted"`: superseded is final.
  - The fourth fails because there's no ADR 9.

  Using strings for statuses works for an exercise, but it's how typos like `"accepted"` get through. The enum in the lesson makes those mistakes compile errors.
````

````exercise
id: m49-l02-e6
type: design
prompt: "Write an ADR for one real decision in your capstone (or for Habit Ledger: how streaks decide which calendar day a check-in belongs to when the user travels). Use the five sections plus alternatives considered, keep it under two pages, and include at least two consequences that are costs."
rubric:
  - The title is a short noun phrase for exactly one decision.
  - The context states facts and forces neutrally, including ones that pull against the decision.
  - The decision starts with "We will" and is specific enough to implement.
  - At least two alternatives, each with the reason it was rejected.
  - At least two consequences are costs or risks, and at least one says when to revisit.
solution: |
  A model ADR for Habit Ledger:

  **ADR 4: Check-ins belong to the local day where they were made**

  **Status:** Accepted. **Date:** 2026-10-02.

  **Context.** A streak counts consecutive days with a check-in. Users travel: a check-in at 23:30 in New York and one at 08:00 the next morning in Madrid are 2.5 hours apart in absolute time. Users think of "today" as the date on their phone. `Date` is an absolute instant with no time zone; the calendar day depends on which time zone you interpret it in. Storing only the instant loses the time zone the user was in.

  **Decision.** We will store each check-in as the instant plus the time zone identifier at the moment of check-in, and compute its day with a `Calendar` set to that stored time zone. Streaks compare those local days.

  **Alternatives considered.**
  - *Use the device's current time zone when computing streaks:* rejected. The same history would show a different streak after flying, which users would read as data loss.
  - *Store everything in UTC days:* rejected. A check-in at 20:00 in Los Angeles would land on the next UTC day.

  **Consequences.**
  - Streaks match what the user saw on their phone at each check-in.
  - Two check-ins can fall on the same local day even if they're 26 hours apart, or on consecutive days even if they're 2 hours apart. That's intended, and the tests cover both.
  - Cost: one extra stored field per check-in, and a migration if we ever change the model.
  - Cost: a user who changes their phone's time zone manually can game streaks. Accepted for a personal habits app; revisit if streaks ever earn rewards.

  Check yours against the rubric. The last consequence above is the kind that matters: it names the condition under which the decision should be reopened.
````

## Summary

- An ADR records one significant decision in one or two pages: title, context, decision, status, consequences, and in practice alternatives considered and a date.
- Write one when a decision is expensive to reverse, spans modules, adds a dependency, or will make someone ask "why?" later. Write it when you decide, in the same pull request.
- State the context neutrally, write the decision as "We will…", and list every consequence, especially the costs.
- Never rewrite an accepted ADR's reasoning. Supersede it with a new, numbered ADR and link the two; deprecate it if nothing replaces it. Numbers are never reused.
- The lifecycle is small: proposed to accepted or rejected, accepted to deprecated or superseded, and those are final. An exhaustive `switch` without `default` makes the compiler find every place a new status needs handling.
