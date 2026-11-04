---
id: m49-l06
title: Technical communication and growing as an engineer
description: "Most of an engineer's influence travels in writing: design docs that let a team agree before building, pull request descriptions that survive in history, explanations a product manager can act on, and questions that get answered quickly. You learn the shape of each, check a pull request description mechanically, see how mentoring works from both sides, and build a learning plan for after the course with a fixed weekly budget. The description checker and plan allocator are plain Swift, compiled and run."
module: m49
order: 6
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m49-l05]
objectives:
  - Write a design doc with goals, non-goals, a proposed design, alternatives, risks and a rollout plan, and know when one is needed instead of an ADR.
  - Write a pull request description whose first line and body still make sense years later.
  - Explain a technical problem or decision to a non-engineer with the conclusion first and the impact in their terms.
  - Ask a question that includes the goal, what you tried, what happened and a minimal reproduction.
  - Get value from a mentor and mentor someone else without taking over their work.
  - Build a learning plan with goals, a weekly time budget, concrete outputs and review points.
terms:
  - term: Design doc
    definition: "A document written before building something non-trivial, describing the problem, goals, non-goals, proposed design, alternatives and risks, so the team can agree on the approach while it's still cheap to change."
  - term: Non-goal
    definition: "Something a design explicitly won't do, stated so reviewers don't assume it and the scope stays bounded."
  - term: Bottom line up front
    definition: "Putting the conclusion or request in the first sentence, then the supporting detail, so a busy reader gets what they need even if they stop early."
  - term: Minimal reproduction
    definition: "The smallest code or set of steps that still shows a problem, with everything unrelated removed."
  - term: XY problem
    definition: "Asking about your attempted solution (Y) instead of your actual goal (X), so helpers solve the wrong problem."
  - term: Learning plan
    definition: "A short written plan with learning goals, the time you'll spend, what you'll produce to show progress, and when you'll review it."
mastery:
  - Write a one-page design doc for a capstone feature that a reviewer can approve or challenge.
  - Write a pull request description that passes a checklist and explains why, how it was tested and what to review closely.
  - Rewrite a technical status message for a product manager with the decision and impact first.
  - Turn a vague request for help into a question with a goal, attempts, observed and expected results, and a reproduction.
  - Write a 12-week learning plan with a weekly budget, outputs and review dates.
resources: [swift-evolution, github-pull-request-reviews, conventional-commits, swift-api-design-guidelines, hig]
cards:
  - id: m49-l06-c1
    front: How does a design doc differ from an ADR?
    back: "A design doc explores a problem before building: goals, non-goals, a proposed design, alternatives, risks, rollout. It's for agreeing on an approach. An ADR records one decision and its consequences, often one of several that come out of a design doc."
  - id: m49-l06-c2
    front: What should the first line of a pull request description do?
    back: "Summarize specifically what the change does, as a complete sentence in the imperative (\"Add…\", \"Fix…\"), informative enough that someone reading history doesn't need to open the PR. Google's guide calls \"Fix bug\" inadequate."
  - id: m49-l06-c3
    front: What's the structure for explaining something to a non-engineer?
    back: "Bottom line first (the decision or request), then the impact in their terms (users, dates, money, risk), then options if there's a choice, and only as much mechanism as they need to trust the conclusion."
  - id: m49-l06-c4
    front: What goes in a good technical question?
    back: "The goal (not just your attempted fix), what you tried, what happened versus what you expected (exact error text), a minimal reproduction, and your environment (Xcode, iOS, Swift versions)."
  - id: m49-l06-c5
    front: What makes a learning plan work?
    back: "Few goals, a weekly time budget you can actually keep, a concrete output for each goal (an app feature, a write-up, a contribution) and dates to review and adjust it."
---

## The idea in one sentence

Your code is read by a compiler, but your decisions are read by people, so the same habits that make code clear (purpose first, no noise, examples that can be checked) make design docs, pull requests, explanations and questions work.

> [!note] Sources and what was checked
> Quotations about change descriptions come from Google's engineering practices guide, "Writing good CL descriptions" (google.github.io/eng-practices/review/developer/cl-descriptions.html), read in November 2026. The Swift Evolution proposal template's sections were read from the swift-evolution repository's `proposal-templates/0000-swift-template.md` in November 2026. Everything else is recommendation, not data. The Swift blocks are compiled and run with Swift 6.3.

## Design docs

An ADR (lesson 2) records one decision. A **design doc** comes earlier and is bigger: it describes a problem and a proposed solution with several decisions in it, so the team can agree before anyone builds. Write one when a change spans several modules or weeks, when more than one team is involved, or when getting it wrong would be expensive to undo. For your capstone, the hard part (Habit Ledger's streaks across time zones) is a good candidate.

A shape that works:

1. **Context.** What exists today and what's wrong with it, in a paragraph.
2. **Goals.** What this design must achieve, ideally checkable ("a streak never changes after the user travels").
3. **Non-goals.** What it deliberately won't do ("supporting non-Gregorian calendars in streak counting"). Non-goals stop reviewers from asking for them and keep the scope honest.
4. **Proposed design.** Data model, flow, APIs, with a diagram if it helps. Enough detail that a reviewer could spot a flaw.
5. **Alternatives considered**, each with why it lost.
6. **Risks and open questions.** What you're unsure of, and how you'll find out (a spike, a prototype).
7. **Testing, accessibility, privacy and rollout.** How you'll know it works, who could be excluded, what data it touches, whether it ships behind a flag.

You've already read documents with this shape: **Swift Evolution proposals**. The proposal template has sections for a summary, "Motivation," "Proposed solution," "Detailed design," "Source compatibility," "ABI compatibility," "Implications on adoption," "Future directions" and "Alternatives considered." Reading two or three accepted proposals for features you use (and the review threads on the Swift Forums that discuss them) is one of the best ways to see how engineers argue a design in writing.

A design doc is for discussion, so send it out early and ask specific questions ("Is storing the time zone per check-in acceptable for storage size?"), not "thoughts?". When the discussion settles, record the key decisions as ADRs and link them from the doc.

## Pull request descriptions, revisited

Module 14 covered the basics: what changed, why, how you tested it, what to look at. Two things to add now that you've seen history from the reader's side in lesson 3.

**The first line is permanent.** Google's guide: "The first line of a CL description should be a short summary of specifically what is being done by the CL, followed by a blank line. This is what appears in version control history summaries, so it should be informative enough that future code searchers don't have to read your CL or its whole description to understand what your CL actually did or how it differs from other CLs." It also lists descriptions it calls inadequate: "Fix bug," "Fix build," "Add patch," "Moving code from A to B," "Phase 1," "Add convenience functions." Pantry's "Make delivery free for orders over $50" answered a question four years later; "Update fee" wouldn't have.

**The body explains the change to someone without your context.** The same guide: include "a brief description of the problem that's being solved, and why this is the best approach. If there are any shortcomings to the approach, they should be mentioned." Add links to the ticket, the design doc or ADR, screenshots for UI in light and dark mode and at a large text size, and anything risky about rollout (a migration, a flag that defaults to off).

A team can check the mechanical parts automatically, which frees reviewers to read for substance:

```swift
struct DescriptionCheck {
    let title: String
    let body: String
    let changesUI: Bool
}

func problems(in pr: DescriptionCheck) -> [String] {
    var found: [String] = []
    let vague = ["fix bug", "fix build", "add patch", "updates", "wip", "phase 1"]
    if pr.title.count > 72 { found.append("title is \(pr.title.count) characters; keep it under 72") }
    if pr.title.hasSuffix(".") { found.append("title ends with a period") }
    if vague.contains(pr.title.lowercased()) { found.append("title says nothing specific") }
    if let first = pr.title.split(separator: " ").first, first.hasSuffix("ed") || first.hasSuffix("ing") {
        found.append("title starts with '\(first)'; use the imperative ('Add', 'Fix')")
    }
    for heading in ["## Why", "## Testing"] where !pr.body.contains(heading) {
        found.append("missing section '\(heading)'")
    }
    if pr.changesUI && !pr.body.contains("![") {
        found.append("UI change without screenshots")
    }
    return found
}

let examples = [
    DescriptionCheck(title: "Fix bug", body: "", changesUI: false),
    DescriptionCheck(title: "Added weekly chart.", body: "## Why\nRequested in #41.", changesUI: true),
    DescriptionCheck(
        title: "Count streaks in the time zone where each check-in was made",
        body: "## Why\nStreaks changed after travel (#52). See ADR 4.\n## Testing\nStreakTests: 6 new cases.",
        changesUI: false),
]
for pr in examples {
    let found = problems(in: pr)
    print("\(pr.title): \(found.isEmpty ? "ok" : "\(found.count) problems")")
    for problem in found { print("  - \(problem)") }
}
```

```output
Fix bug: 3 problems
  - title says nothing specific
  - missing section '## Why'
  - missing section '## Testing'
Added weekly chart.: 4 problems
  - title ends with a period
  - title starts with 'Added'; use the imperative ('Add', 'Fix')
  - missing section '## Testing'
  - UI change without screenshots
Count streaks in the time zone where each check-in was made: ok
```

- **The imperative check is a heuristic.** A word ending in "ed" or "ing" is a hint, not a grammar check: "Embed" would be flagged wrongly, and plenty of non-imperative titles pass. Automate what can be checked reliably and leave judgment to reviewers.
- **`![` is how Markdown starts an image**, so it's a cheap proxy for "has a screenshot." GitHub's pull request templates and a CI step can run a check like this on every pull request.
- **The third description passes and is also good**, which isn't the same thing. The checker can't tell whether "See ADR 4" explains the change. A reviewer can.
- **72 characters** is an upper bound for this check. Module 14's commit subject guideline is 50; pull request titles on most hosting sites have more room, but the shorter one is still easier to scan.

## Explaining to people who aren't engineers

A product manager, a designer, a support lead or an executive needs to act on what you say, not to understand the code. Put the **bottom line up front**: the decision you need or the conclusion, in the first sentence. Then the impact in their terms (users, dates, money, risk), then options if there's a choice, and only enough mechanism for them to trust the conclusion.

Before:

> We found that the streak calculation uses `Calendar.current`, which picks up the device time zone at evaluation time rather than at check-in time, so when `TimeZone.current` changes the `dateComponents` for older check-ins shift and the consecutive-day logic breaks. We need to migrate the model to store a `TimeZone` identifier per check-in and backfill.

After:

> **Need a decision by Thursday:** users who travel can see their streak drop to zero even though they checked in every day. About 1 in 20 active users traveled across time zones last month, based on our analytics. The fix is about three days of work, and it means a one-time data update when people install the new version. I recommend we do it in the next release instead of the reminders feature, which would move to the release after. Details are in the design doc if you want them.

What changed:

- **The ask is first**, with a deadline.
- **Impact is in user terms** ("streak drops to zero"), with a number and where it came from. (In the example it's from analytics; never present a guess as data.)
- **Cost and trade-off** are explicit: three days, and reminders move.
- **A recommendation**, so they don't have to design the solution.
- **The mechanism is available** but not in the way.

An analogy can help ("it's like a diary that rewrites dates when you change your watch"), as long as you'd be comfortable if they reasoned from it. If the analogy would lead them to a wrong conclusion about cost or risk, leave it out.

## Asking good questions

A good question respects the time of the person answering and gets you a faster answer. Include:

- **The goal**, not only the attempted fix. "How do I force `Calendar` to use UTC?" might get a correct and useless answer if what you actually need is "count streaks in each check-in's own time zone." Asking about your solution instead of your problem is the **XY problem**.
- **What you tried**, so nobody suggests it again.
- **What happened and what you expected**, with exact error text, copied, not paraphrased.
- **A minimal reproduction**: the smallest code that shows the problem. Making one often answers the question by itself.
- **Environment**: Xcode, iOS and Swift versions, device or simulator.

Before asking, time-box your own attempt (for example, 30 to 60 minutes of real effort, depending on the team and the urgency). Too little, and you ask things the docs answer; too long, and you lose a day to something a teammate knows in a minute. Ask in a shared channel rather than a private message when you can: the answer then helps the next person, and more people can answer. When you get the answer, close the loop ("that was it, thanks; I added a note to the README").

## Mentoring, in both directions

**Being mentored** works best when you bring the agenda. Before each conversation, write down two or three specific questions ("How do you decide when a view model is doing too much?"), a recent decision you'd like a second opinion on, and what you're trying to grow toward. Ask for feedback on specific work ("Would you review my ADR before I send it out?"), and when you get it, tell them later what you did with it.

**Mentoring someone** is mostly asking, not telling. A few habits:

- **Ask what they've tried and what they think** before offering your answer. Often they're one question away.
- **Let them drive** when pairing. Your hands on their keyboard teach them that you can do it.
- **Review their work the way lesson 3 describes**: labeled by weight, about the code, with real praise.
- **Explain your reasoning, not only the answer.** "I'd check the history first because…" transfers a habit; "change line 12" transfers a fix.
- **Expect to learn.** Explaining something you know well is the fastest way to find the parts you don't.

You don't need a title to mentor. Writing a clear answer in a shared channel, or a README that gets the next person running in an hour, is mentoring too.

## A learning plan after the course

The course ends here; the work doesn't. A plan keeps the next year from turning into a random walk through tutorials. Keep it small:

- **Three goals at most**, each with a **concrete output** you can point to: "ship Habit Ledger to TestFlight with five external testers," "write an ADR and a blog post on streaks across time zones," "get one pull request merged into an open-source Swift package."
- **A weekly time budget you'll actually keep**, split between goals.
- **Sources that go to the primary material**: Apple's documentation and release notes for each new OS and Xcode, Swift Evolution proposals and their review threads, the Swift Forums. Read the proposal before the blog post about it.
- **Review dates.** Every four weeks: what did you produce, what was harder than expected, what will you change.

The split is easy to get wrong in your head ("about a third each") and easy to compute. The **largest remainder** method allocates whole hours by weight and hands leftover hours to the goals with the largest fractional share, so the total always matches the budget:

```swift
struct Goal {
    let name: String
    let weight: Int
}

func allocate(hours: Int, to goals: [Goal]) -> [(name: String, hours: Int)] {
    let totalWeight = goals.reduce(0) { $0 + $1.weight }
    var shares = goals.enumerated().map { (index, goal) in
        (index: index, name: goal.name,
         hours: hours * goal.weight / totalWeight,
         remainder: hours * goal.weight % totalWeight)
    }
    var leftover = hours - shares.reduce(0) { $0 + $1.hours }
    let byRemainder = shares.sorted { (-$0.remainder, $0.index) < (-$1.remainder, $1.index) }
    for share in byRemainder where leftover > 0 {
        shares[share.index].hours += 1
        leftover -= 1
    }
    return shares.map { ($0.name, $0.hours) }
}

let goals = [
    Goal(name: "Ship Habit Ledger to TestFlight", weight: 3),
    Goal(name: "Accessibility deep dive", weight: 2),
    Goal(name: "Open-source contribution", weight: 2),
]
let weekly = allocate(hours: 6, to: goals)
for goal in weekly { print("\(goal.hours) h/week  \(goal.name)") }
print("Total: \(weekly.reduce(0) { $0 + $1.hours }) h/week; over 12 weeks: \(weekly.reduce(0) { $0 + $1.hours } * 12) h")
```

```output
2 h/week  Ship Habit Ledger to TestFlight
2 h/week  Accessibility deep dive
2 h/week  Open-source contribution
Total: 6 h/week; over 12 weeks: 72 h
```

- **Exact shares are 18/7, 12/7 and 12/7 hours**, about 2.57, 1.71 and 1.71. In whole hours with remainders (in sevenths): 2 r4, 1 r5, 1 r5. That's 4 hours, leaving 2.
- **The leftovers go to the largest remainders**, the two 5s, so the result is 2, 2, 2. The goal with the highest weight doesn't get more hours here, which can be surprising. If the main goal should get 3, give it a weight that says so: at 4:2:2 the whole hours are 3, 1 and 1 (remainders 0, 4 and 4 in eighths), and the one leftover hour goes to the earlier of the tied goals, giving 3, 2, 1.
- **Sorting by `(-remainder, index)`** puts the largest remainder first and breaks ties by the earlier goal. Negating the field you want descending keeps both orders in one tuple and is hard to get backward.
- **The total always equals the budget**, which is the reason to use this method rather than rounding each share: rounding 2.57, 1.71 and 1.71 gives 3, 2, 2, which is 7 hours you don't have.

## Common mistakes

> [!error] A design doc written after the code
> It documents decisions that can no longer change, so nobody reviews it seriously. Write it when the approach is still open, and send it early with specific questions.

> [!error] Leading with the mechanism
> A non-engineer who reads three sentences about `Calendar.current` before learning what you need from them will stop reading first. Put the decision and impact in the first sentence.

> [!error] Asking about your fix instead of your goal
> "How do I disable this warning?" when the goal is "make this type safe to send across actors" gets you an answer that hides the problem. Say what you're trying to achieve.

> [!error] A learning plan with ten goals and no outputs
> "Learn SwiftUI, Combine, Metal, ML, server-side Swift…" with no time budget turns into a list of tabs. Three goals, each with something you'll ship or write, and a review date.

## Exercises

````exercise
id: m49-l06-e1
type: comprehension
prompt: "Which is the best first line for a pull request that makes the weekly chart's VoiceOver summary list each day's count?"
choices:
  - text: "Accessibility fixes"
    correct: false
    why: "Not specific: which fixes, where? Someone reading history learns nothing."
  - text: "Make the weekly chart's VoiceOver summary list each day's check-in count"
    correct: true
    why: "Specific, imperative, and readable on its own in a history list."
  - text: "Updated the accessibilityLabel in WeeklyChartView.swift to include the counts per day as requested."
    correct: false
    why: "Past tense, ends with a period, names the mechanism instead of the behavior, and is too long."
  - text: "Phase 2"
    correct: false
    why: "Google's guide lists \"Phase 1\" among inadequate descriptions; it only makes sense to someone who knows the plan."
solution: |
  **"Make the weekly chart's VoiceOver summary list each day's check-in count."** It's a complete imperative sentence that says what the change does in terms a reader understands, without opening the pull request. The body can then say why (users couldn't tell which days were missed) and how it was tested (VoiceOver on a device, plus a test for the summary text).
````

````exercise
id: m49-l06-e2
type: prediction
prompt: "A smaller description checker. What does this program print?"
code: |
  func check(_ title: String, _ body: String) -> [String] {
      var found: [String] = []
      if title.hasSuffix(".") { found.append("period") }
      if let first = title.split(separator: " ").first, first.hasSuffix("ed") { found.append("past tense") }
      for heading in ["## Why", "## Testing"] where !body.contains(heading) { found.append(heading) }
      return found
  }

  print(check("Embed the chart in a scroll view", "## Why\n## Testing"))
  print(check("Fixed crash.", "## Testing\nRan StreakTests."))
  print(check("Add CSV export", "## Why and ## Testing"))
output: |
  ["past tense"]
  ["period", "past tense", "## Why"]
  []
hints:
  - "\"Embed\" ends with \"ed\"."
  - "`contains` looks for the text anywhere in the body, not only at the start of a line."
solution: |
  ```output
  ["past tense"]
  ["period", "past tense", "## Why"]
  []
  ```

  1. "Embed" is imperative, but it ends in "ed", so the heuristic flags it: a false positive.
  2. A period, a past-tense first word, and no `## Why`.
  3. Both headings appear inside one line, so `contains` finds them, though the body isn't really structured: a false negative.

  Both mistakes come from treating a text pattern as if it were grammar or structure. Heuristic checks are useful as hints in CI, but they shouldn't block a merge on their own.
````

````exercise
id: m49-l06-e3
type: solve
prompt: |
  Write the lesson's allocation with plain arrays: `allocate(hours:weights:)` uses the largest remainder method: each goal gets `hours * weight / totalWeight` whole hours, and the leftover hours go one each to the goals with the largest remainders, ties broken by the earlier goal. Return the hours in the original order.

  ```swift
  print(allocate(hours: 6, weights: [3, 2, 2]))
  print(allocate(hours: 10, weights: [1, 1, 1]))
  print(allocate(hours: 5, weights: [5, 0, 1]))
  ```

  should print:

  ```output
  [2, 2, 2]
  [4, 3, 3]
  [4, 0, 1]
  ```
starter: |
  func allocate(hours: Int, weights: [Int]) -> [Int] {
      return []
  }
rubric:
  - Computes whole hours and remainders with integer arithmetic.
  - Gives the leftover hours to the largest remainders, breaking ties by the earlier index.
  - Returns hours in the original order, and the total equals the budget.
hints:
  - "Sort the indices by `(-remainder, index)` ascending: largest remainder first, earlier index first on ties."
  - "For 6 hours at 3:2:2, exact shares are 2.57, 1.71 and 1.71; the remainders are 4, 5 and 5 sevenths."
solution: |
  ```swift
  func allocate(hours: Int, weights: [Int]) -> [Int] {
      let total = weights.reduce(0, +)
      var result = weights.map { hours * $0 / total }
      let remainders = weights.map { hours * $0 % total }
      var leftover = hours - result.reduce(0, +)
      let order = weights.indices.sorted { (-remainders[$0], $0) < (-remainders[$1], $1) }
      for index in order where leftover > 0 {
          result[index] += 1
          leftover -= 1
      }
      return result
  }

  print(allocate(hours: 6, weights: [3, 2, 2]))
  print(allocate(hours: 10, weights: [1, 1, 1]))
  print(allocate(hours: 5, weights: [5, 0, 1]))
  ```

  ```output
  [2, 2, 2]
  [4, 3, 3]
  [4, 0, 1]
  ```

  1. 6 hours at 3:2:2: whole hours 2, 1, 1 with remainders 4, 5, 5 (in sevenths). Two leftovers go to the two 5s: 2, 2, 2, the same as the lesson's version.
  2. 10 at 1:1:1: 3 each, remainder 1 each, one leftover; the tie goes to the first goal.
  3. 5 at 5:0:1: whole hours 4, 0, 0 with remainders 1, 0, 5 (in sixths). One leftover goes to the 5: the third goal. A zero weight never gets hours, because its remainder is 0 and a larger remainder always exists when there's a leftover.

  Comparing tuples with the sign flipped on the field you want descending, `(-remainder, index)`, keeps both orders in one place and is hard to get backward.
````

````exercise
id: m49-l06-e4
type: explain
prompt: "Rewrite this message for the product manager, who needs to decide whether the release goes out on Thursday. Then explain in two or three sentences what you changed and why."
code: |
  So the SwiftData migration from schema v2 to v3 is a custom stage because we split
  CheckIn.note into a separate model, and on a test device with 3 years of data it
  took 14 s on the main actor before the watchdog kicked in, so I moved it to a
  ModelActor but now the first launch shows an empty list until it's done, which
  might need a loading state, and I haven't tested on an iPhone SE yet.
rubric:
  - The rewrite opens with the decision needed or a recommendation.
  - Impact is described in user terms (who, what they see) with what is and isn't known.
  - Options or a recommendation with its cost are stated.
  - Technical mechanism is reduced to what's needed to trust the conclusion.
  - The explanation names bottom line up front and user-level impact.
solution: |
  A rewrite:

  > **Recommendation: hold Thursday's release until Monday.** On the first launch after updating, long-time users (around three years of data) would see an empty habit list for several seconds while their data is updated, and on older iPhones it might be longer; I haven't measured that yet. I can add an "Updating your data…" screen and test on the oldest supported iPhone by Friday. If Thursday can't move, the alternative is to ship without the notes change, which has no migration, and do it in the next release.

  What changed: the decision comes first, with a recommendation, because that's what the product manager has to act on. The impact is in what users see, with the unknown stated plainly instead of buried at the end. The migration details (schema versions, actors, the watchdog) are gone; they belong in the pull request and the ADR, and they're available if asked.
````

````exercise
id: m49-l06-e5
type: find-errors
prompt: "A question posted in the team's iOS channel. Mark every real problem."
code: |
  @Sam hey, quick question, how do I turn off the Sendable warning? it's
  annoying. tried a few things, doesn't work. thanks!!
choices:
  - text: "It asks about silencing a warning (the attempted fix) instead of stating the goal."
    correct: true
  - text: "No exact warning text, code or reproduction."
    correct: true
  - text: "'Tried a few things' without saying what, so people will suggest them again."
    correct: true
  - text: "No environment information (Swift language mode, Xcode version)."
    correct: true
  - text: "It's in a shared channel instead of a private message to Sam."
    correct: false
rubric:
  - I flagged the XY problem.
  - I flagged the missing warning text and reproduction.
  - I flagged the unspecified attempts.
  - I flagged the missing environment.
solution: |
  Four problems; asking in the shared channel is the right call. A better version:

  > I'm trying to pass a `HabitSnapshot` from the `ModelActor` that loads check-ins to a `@MainActor` view model. Swift 6.3 in Swift 6 mode reports: `[paste the exact diagnostic here]`. Minimal repro (20 lines): [link or code block]. I tried making `HabitSnapshot` a struct, which fixed one error but not this one because it contains a `[CheckIn]` where `CheckIn` is a class. Xcode 26.1. Is the right fix to make `CheckIn` a struct for the snapshot, or is there a pattern you use here?

  It says the goal (move data between actors safely), includes the exact diagnostic, a reproduction and what was tried, and asks a specific question. Tagging one person is fine if they're the expert, but the channel lets anyone answer.
````

````exercise
id: m49-l06-e6
type: design
prompt: "Write your learning plan for the 12 weeks after the course: up to three goals, each with a concrete output, a weekly time budget split across them, the primary sources you'll use for each, and two review dates with the questions you'll ask yourself at each."
rubric:
  - At most three goals, each with an output someone else could see.
  - A weekly budget that's realistic for the learner's schedule, split across goals and adding up.
  - Primary sources (documentation, release notes, Swift Evolution, the Swift Forums) for each goal.
  - Review dates with specific questions, and permission to change the plan.
  - At least one goal involves sharing work with others (shipping, writing, contributing, mentoring).
solution: |
  A model plan, 6 hours a week:

  **Goal 1: ship Habit Ledger to TestFlight with five external testers** (3 h/week). Output: a TestFlight build, a feedback log, and three fixes from tester feedback merged with tests. Sources: App Store Connect Help on TestFlight, the App Review Guidelines (Module 41), Apple's documentation for any API added.

  **Goal 2: accessibility deep dive** (2 h/week). Output: an accessibility audit of Habit Ledger written up as an ADR and a short blog post, with every finding fixed or explained. Sources: Apple's accessibility documentation and the Human Interface Guidelines' accessibility section, Accessibility Inspector, testing with VoiceOver users if possible.

  **Goal 3: one open-source contribution** (1 h/week). Output: a merged pull request (documentation counts) in a Swift package the app uses. Sources: the project's contributing guide, its open issues, Swift Evolution proposals for any language feature involved.

  **Review in week 4:** Did I keep the hours? Which output is behind and why? Is any goal the wrong size? **Review in week 8:** What did I learn that I didn't plan? Should goal 3 change based on what I found in the codebase? Then plan the next 12 weeks.

  Your plan will differ; check that every goal has something you can show, and that the hours are ones you'll actually have.
````

## Summary

- Design docs come before building: context, goals, non-goals, proposed design, alternatives, risks, testing and rollout. Swift Evolution proposals are public examples of the form. Record the resulting decisions as ADRs.
- A pull request's first line is permanent history: specific, imperative, readable alone. The body explains the problem, why this approach, its shortcomings, and how it was tested. Automate the mechanical checks; review for substance.
- For non-engineers, put the bottom line up front: the decision needed, the impact in their terms, options with costs, and only as much mechanism as trust requires.
- Ask questions with the goal, what you tried, exact errors, a minimal reproduction and your environment, after a time-boxed attempt, in a shared channel.
- Bring the agenda to your mentor; when mentoring, ask before telling and let the other person drive.
- After the course: three goals at most, each with an output, a weekly budget you'll keep, primary sources, and review dates. Check your arithmetic with code, and your code against a worked example.
