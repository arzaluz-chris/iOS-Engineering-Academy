---
id: m49-l05
title: Estimation and planning
description: "\"How long will it take?\" is a question about uncertainty, and a single number hides it. You break a feature into tasks small enough to estimate, including the work that isn't code, give three-point estimates and combine them with the PERT formulas in integer arithmetic, communicate a range instead of a promise, track progress with a burndown that shows scope changes, re-estimate when reality disagrees, and negotiate scope instead of quality when the date is fixed. The estimate and burndown calculations are plain Swift, compiled and run."
module: m49
order: 5
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m49-l04]
objectives:
  - Break a feature into tasks of a day or less, including tests, accessibility, review and release work.
  - Give three-point estimates and combine them into an expected value and a spread with the PERT formulas.
  - Communicate an estimate as a range with its assumptions, and use a time-boxed spike for unknowns.
  - Track progress with a burndown that separates completed work from added scope, and project a finish date from recent pace.
  - Re-estimate and raise a slip as soon as the data shows it.
  - Say no or negotiate scope with concrete options, keeping quality fixed.
terms:
  - term: Estimate
    definition: "A forecast of effort or duration with its uncertainty, based on stated assumptions. It isn't a commitment, though a commitment can be made from it."
  - term: Three-point estimate
    definition: "An estimate given as optimistic, most likely and pessimistic values for the same task."
  - term: PERT
    definition: "Program Evaluation and Review Technique. Its classic formulas estimate a task's expected duration as (O + 4M + P) / 6 and its standard deviation as (P − O) / 6."
  - term: Spike
    definition: "A short, time-boxed investigation whose output is knowledge (and a better estimate), not shippable code."
  - term: Burndown
    definition: "A chart of the work remaining over time, compared with an ideal line from the starting amount to zero on the planned date."
  - term: Scope negotiation
    definition: "Agreeing on what to build, or what to leave out, to meet a date or a budget, instead of compressing the estimate or the quality."
mastery:
  - Break a capstone feature into a task list where nothing is larger than a day and non-coding work is included.
  - Compute the PERT expected value and standard deviation for a list of tasks, and explain why the total is higher than the sum of most-likely values.
  - Answer "how long?" with a range, the assumptions behind it and what would narrow it.
  - Read a burndown, distinguish slow progress from added scope, and project a finish day from recent pace.
  - Write a reply to an unrealistic request that offers at least two concrete options.
resources: [swift-book-basic-operators, swift-array]
cards:
  - id: m49-l05-c1
    front: What are the PERT expected value and standard deviation for one task?
    back: "Expected = (O + 4M + P) / 6. Standard deviation = (P − O) / 6. O, M and P are the optimistic, most likely and pessimistic estimates."
  - id: m49-l05-c2
    front: Why is a project's expected total usually higher than the sum of the most-likely estimates?
    back: "Tasks can overrun by much more than they can underrun, so each task's pessimistic value is further from its most likely than the optimistic value is. The expected value of each task sits above its most likely, and the gap adds up."
  - id: m49-l05-c3
    front: How do you combine the spreads of several independent tasks?
    back: "Add the variances (squares of the standard deviations) and take the square root. Standard deviations don't add directly. If the tasks share a risk, they aren't independent, and the combined spread is wider than this formula says."
  - id: m49-l05-c4
    front: "The burndown went up on day 4. What are the two possible causes, and why does it matter which?"
    back: "Scope was added, or the remaining work was re-estimated upward. Both are information, not failure. Tracking added scope separately shows whether the team is slow or the target moved, which lead to different conversations."
  - id: m49-l05-c5
    front: The date is fixed and the work doesn't fit. What do you negotiate?
    back: "Scope: which features ship by the date and which come later. Not quality: skipping tests, accessibility or review just moves the cost into bugs and incidents."
---

## The idea in one sentence

An estimate is a forecast with uncertainty, so you give it as a range with its assumptions, track it against reality, update it as soon as the data disagrees, and when the date can't move, you change what's built, not how well it's built.

> [!note] Sources and what was checked
> The PERT formulas are the classic ones from the Program Evaluation and Review Technique; they're a convention, not a law of nature, and the lesson says where their assumptions break. The "cone of uncertainty" idea is described at length in Steve McConnell's book *Software Estimation: Demystifying the Black Art* (Microsoft Press, 2006); no figures from it are quoted here. The examples use the course's capstone; none of the numbers are measurements from real projects. The Swift blocks are compiled and run with Swift 6.3.

## Why single numbers go wrong

"Three days" is heard as a promise. You meant "probably three, maybe five if the time zone handling is as messy as I think." The listener plans around three, and when it takes five, the estimate was "wrong," though it was fine as a forecast.

Three habits fix most of this: estimate small pieces, give a range, and say what the range depends on.

## Break the work down

You can't estimate "the weekly chart." You can estimate "aggregate check-ins by local week," because you can picture the code. Two rules:

- **No task larger than about a day.** Anything bigger hides subtasks you haven't thought of yet; breaking it down is how you find them.
- **Include the work that isn't writing the feature.** Tests, the accessibility pass, localization, the ADR if there's a decision, review and the changes it asks for, the release. The definition of done from lesson 1 is a checklist of tasks people forget to estimate.

For Habit Ledger's weekly chart:

1. Aggregate check-ins by local week (the time zone rules from ADR 4)
2. Chart view
3. Accessible chart summary
4. Tests
5. Dynamic Type and dark mode pass
6. Review and fixes

**When a task can't be estimated** because you've never done it ("can Swift Charts give us a custom accessibility summary?"), don't guess. Plan a **spike**: a fixed, short time box (two hours, half a day) to find out, whose output is an answer and a real estimate. The time box is the point: the spike ends when the time is up, with whatever you learned.

## Three-point estimates

For each task, give three numbers: **optimistic** (O: everything goes right), **most likely** (M: what you'd bet on), and **pessimistic** (P: the problems you can foresee happen, short of disaster). The classic PERT formulas turn them into an expected value and a spread:

- expected = (O + 4M + P) / 6
- standard deviation = (P − O) / 6

They weight the most likely value heavily but let a long pessimistic tail pull the expectation up, which matches how software tasks behave: a task can finish a little early, or much later.

To combine tasks: expected values add. **Standard deviations don't**: if the tasks are independent, their variances (squares) add, and the total standard deviation is the square root of the sum.

The Swift below does it in integer arithmetic so the output is the same on every platform: hours in, results in tenths of an hour, a hand-written square root.

```swift
struct Estimate {
    let task: String
    let optimistic: Int    // hours
    let likely: Int
    let pessimistic: Int
}

/// Formats a non-negative number of tenths as "12.3".
func tenths(_ value: Int) -> String { "\(value / 10).\(value % 10)" }

/// Largest integer whose square is at most n.
func integerSquareRoot(_ n: Int) -> Int {
    var root = 0
    while (root + 1) * (root + 1) <= n { root += 1 }
    return root
}

let weeklyChart = [
    Estimate(task: "Aggregate check-ins by local week", optimistic: 3, likely: 5, pessimistic: 12),
    Estimate(task: "Chart view", optimistic: 4, likely: 6, pessimistic: 12),
    Estimate(task: "Accessible chart summary", optimistic: 2, likely: 3, pessimistic: 6),
    Estimate(task: "Tests", optimistic: 2, likely: 4, pessimistic: 6),
    Estimate(task: "Dynamic Type and dark mode pass", optimistic: 1, likely: 2, pessimistic: 4),
    Estimate(task: "Review and fixes", optimistic: 1, likely: 2, pessimistic: 5),
]

var likelySum = 0
var sixthsSum = 0          // sum of (O + 4M + P); divide by 6 for hours
var spreadSquares = 0      // sum of (P - O)^2; its square root / 6 is the standard deviation
for estimate in weeklyChart {
    let sixths = estimate.optimistic + 4 * estimate.likely + estimate.pessimistic
    likelySum += estimate.likely
    sixthsSum += sixths
    spreadSquares += (estimate.pessimistic - estimate.optimistic) * (estimate.pessimistic - estimate.optimistic)
    print("\(tenths((sixths * 10 + 3) / 6)) h  \(estimate.task) (\(estimate.optimistic)-\(estimate.pessimistic))")
}
let expected = (sixthsSum * 10 + 3) / 6                 // tenths of an hour, rounded
let sigma = integerSquareRoot(spreadSquares * 100) / 6   // tenths, rounded down
print("Sum of most likely:  \(likelySum).0 h")
print("Expected (PERT):     \(tenths(expected)) h")
print("Standard deviation:  \(tenths(sigma)) h")
print("Range to communicate: \(tenths(expected - sigma)) to \(tenths(expected + 2 * sigma)) h")
```

```output
5.8 h  Aggregate check-ins by local week (3-12)
6.7 h  Chart view (4-12)
3.3 h  Accessible chart summary (2-6)
4.0 h  Tests (2-6)
2.2 h  Dynamic Type and dark mode pass (1-4)
2.3 h  Review and fixes (1-5)
Sum of most likely:  22.0 h
Expected (PERT):     24.3 h
Standard deviation:  2.3 h
Range to communicate: 22.0 to 28.9 h
```

Line by line:

- **`sixths` keeps the formula exact.** `O + 4M + P` is an integer; dividing by 6 is the only lossy step, so it happens once, at the end. `(sixths * 10 + 3) / 6` converts to tenths and rounds to the nearest tenth: adding 3 (half of 6) before integer division rounds instead of truncating.
- **`tenths` formats without floating point**, so the text can't differ between platforms. It only handles non-negative values, which is all this program produces.
- **The variance trick.** σ in tenths is √(Σ(P−O)²) × 10 / 6, which equals √(Σ(P−O)² × 100) / 6. Multiplying inside the root keeps the integer square root precise to a tenth.
- **Expected is 2.3 hours above the sum of most-likely values.** Every task here has a pessimistic tail longer than its optimistic one (aggregation: 2 hours better or 7 worse). Adding most-likely values is the most common way estimates come out low.
- **The range is asymmetric on purpose**: one σ below, two above, because overruns are more likely and more costly than underruns. That's a convention, not a statistical guarantee.

> [!warning] Where the formulas break
> Combining spreads by adding variances assumes the tasks are **independent**. Here they aren't: if the time zone aggregation turns out messy, the tests for it will take longer too. Correlated risks make the true spread wider than 2.3 hours. The formulas also inherit your blind spots: a pessimistic value that's still optimistic, or a task you didn't list, isn't fixed by arithmetic. Use the numbers to structure the conversation, not to end it.

### Saying the estimate out loud

Compare these answers to "When will the weekly chart be ready?":

- "24 hours." (A promise in disguise, with a false precision of two digits.)
- "About three days of work, likely between 22 and 29 hours. It assumes Swift Charts can take a custom accessibility summary, which I'll confirm in a two-hour spike tomorrow; if it can't, add a day. I'll update you after the spike."

The second is longer and much more useful: a range, the main assumption, what would change it, and when the uncertainty will shrink. That last part is the "cone of uncertainty" in practice: estimates get narrower as you learn, so plan specific points (after the spike, after the first slice) where you'll update them.

Note the unit change too: 24 hours of work isn't three calendar days if you have meetings, reviews to give and an on-call shift. Say which one you mean.

## Tracking and re-estimating

A **burndown** plots the work remaining each day against an ideal line from the starting amount to zero on the planned date. It's only honest if it separates two things that both change "remaining": work completed and scope added.

```swift
struct Day {
    let completed: Int   // points finished that day
    let added: Int       // points of new scope added that day
}

let initialPoints = 40
let plannedDays = 10
let days = [
    Day(completed: 3, added: 0), Day(completed: 5, added: 0), Day(completed: 2, added: 0),
    Day(completed: 4, added: 6), Day(completed: 3, added: 0), Day(completed: 5, added: 0),
]

var remaining = initialPoints
for (index, day) in days.enumerated() {
    let dayNumber = index + 1
    remaining += day.added - day.completed
    let ideal = initialPoints * (plannedDays - dayNumber) / plannedDays
    let bar = String(repeating: "#", count: remaining)
    let note = day.added > 0 ? "  (+\(day.added) scope)" : ""
    print("Day \(dayNumber < 10 ? " " : "")\(dayNumber)  remaining \(remaining)  ideal \(ideal)  \(bar)\(note)")
}

let window = days.suffix(3)
let recentCompleted = window.reduce(0) { $0 + $1.completed }
let daysLeft = (remaining * window.count + recentCompleted - 1) / recentCompleted   // ceiling
let finishDay = days.count + daysLeft
print("Recent pace: \(recentCompleted) points in \(window.count) days")
print("Projected finish: day \(finishDay) of \(plannedDays) planned")
```

```output
Day  1  remaining 37  ideal 36  #####################################
Day  2  remaining 32  ideal 32  ################################
Day  3  remaining 30  ideal 28  ##############################
Day  4  remaining 32  ideal 24  ################################  (+6 scope)
Day  5  remaining 29  ideal 20  #############################
Day  6  remaining 24  ideal 16  ########################
Recent pace: 12 points in 3 days
Projected finish: day 12 of 10 planned
```

- **Day 4 went up**, even though 4 points were completed. Six points of scope were added. Without the `added` column, the chart would say "the team went backward," and the conversation would be about speed instead of about the new scope.
- **The pace uses the last three days**, not the whole history: 12 points in 3 days. `days.suffix(3)` takes them; recent pace reflects the current work better than an average that includes the first, slower days.
- **`(a + b - 1) / b` is integer ceiling division.** 24 points at 4 a day is exactly 6 days; 25 would be 7. A projection should round up: you don't finish on a fraction of a day.
- **Day 12 of 10** is the moment to speak up. Not on day 10.

Re-estimating isn't admitting failure; it's the estimate doing its job. When the data shows a slip, raise it the same day with what you know: the new projection, the cause (here, 6 points of added scope, which accounts for a day and a half at the recent pace), and the options. A slip reported on day 6 leaves room for choices. The same slip reported on day 10 leaves none.

> [!tip] Points or hours
> This example uses points (relative sizes) and the PERT example uses hours. Teams argue about which is better. For a solo capstone, hours are simpler, because you're the only one who has to interpret them. What matters more is that you measure the same thing you estimated, and compare them afterward to learn how your estimates run.

## Saying no and negotiating scope

Sooner or later someone asks for more than fits: "Can we also add reminders before Friday?" There are only a few levers: the date, the scope, the people, and quality. Adding people late rarely helps on a small team (they need onboarding, and the work may not split). **Quality isn't a lever**: skipping tests, the accessibility pass or review doesn't remove that work, it moves it into bugs, incidents and a definition of done that no longer means anything. That leaves date and scope.

A useful shape for the answer:

1. **Acknowledge the goal.** "Reminders before the launch post makes sense."
2. **State the cost in their terms.** "It's about two days with tests and the notification permission flow, and the chart has about two days left."
3. **Offer options, not a refusal.**
   - "Ship the chart Friday and reminders the following Wednesday."
   - "Ship reminders Friday and move the chart to next week."
   - "Ship a simpler reminder Friday (one fixed time, no per-habit schedule), with the full version next week."
4. **Let them choose**, and write the choice down.

Each option is honest about the trade, and the person who owns the priorities makes the call. "No" on its own invites "just try"; options turn it into a decision.

Sometimes the right answer is still a plain no: a request that would mean shipping without the security review, or a date that requires skipping App Review time you don't control. Then say what the risk is, in user and business terms, and who should make the call if they still want it.

For your own capstone, the person asking is often you. The won't list from lesson 1 is how you say no to yourself.

## Common mistakes

> [!error] Estimating only the coding
> The feature estimate covers the view and the model, and then tests, accessibility, review and release take as long again. Put the definition of done into the task list.

> [!error] Adding the most-likely values
> The sum of most-likely values is below the expected total whenever tasks can overrun more than they can underrun, which is almost always. Use three points.

> [!error] Treating the estimate as the commitment
> An estimate says what's likely; a commitment is a choice about which point of the range to promise, given the cost of being late. Make that choice explicitly.

> [!error] Hiding a slip until the deadline
> The data showed it on day 6. Every day you wait removes options. Raise it with the new projection and choices the same day.

> [!error] Cutting quality to meet a date
> It feels like scope, but it isn't optional work; it's deferred work with interest. Cut features, not tests.

## Exercises

````exercise
id: m49-l05-e1
type: comprehension
prompt: "A product manager asks how long CSV export will take. You haven't worked with the file exporter APIs. Which answer is best?"
choices:
  - text: "\"Two days.\""
    correct: false
    why: "A single number hides that you've never used the API; it will be heard as a promise."
  - text: "\"I can't estimate it.\""
    correct: false
    why: "True right now, but it gives them nothing to plan with and no path to an answer."
  - text: "\"Probably one to three days. The unknown is the export API, which I haven't used; I'll spend two hours tomorrow morning finding out and give you a tighter range by noon.\""
    correct: true
    why: "A range, the main uncertainty, a time-boxed spike to reduce it, and when the update will come."
  - text: "\"Whenever you need it. I'll make it work.\""
    correct: false
    why: "That's a commitment with no estimate behind it, and it usually ends with cut quality or a missed date."
solution: |
  The third. It gives a usable range now, names what makes it uncertain, plans a spike to remove that uncertainty and commits to when the better answer will come.

  The first and last turn uncertainty into a promise; the second refuses to forecast at all.
````

````exercise
id: m49-l05-e2
type: prediction
prompt: "Three-point estimates in sixths of an hour. What does this program print?"
code: |
  let tasks = [(o: 2, m: 3, p: 10), (o: 1, m: 2, p: 2), (o: 4, m: 4, p: 4)]
  var sixths = 0
  var likely = 0
  for task in tasks {
      sixths += task.o + 4 * task.m + task.p
      likely += task.m
  }
  print(sixths)
  print(likely)
  print(sixths / 6, sixths % 6)
  print((sixths * 10 + 3) / 6)
output: |
  59
  9
  9 5
  98
hints:
  - "Compute O + 4M + P for each task: 2 + 12 + 10, 1 + 8 + 2, 4 + 16 + 4."
  - "The last line is the expected value in tenths of an hour, rounded."
solution: |
  ```output
  59
  9
  9 5
  98
  ```

  - Sixths: 24 + 11 + 24 = 59.
  - Most likely: 3 + 2 + 4 = 9.
  - 59 / 6 is 9 remainder 5: the expected total is 9 and 5/6 hours, about 9.8.
  - (590 + 3) / 6 = 593 / 6 = 98 (integer division): 9.8 hours in tenths. Without the `+ 3`, 590 / 6 would also give 98 here; the rounding matters when the remainder is small, for example 9 and 1/6, which is 9.17 and should print as 9.2.

  The first task has a long tail (2 to 10 around a likely 3), which pulls the expected total above the most-likely sum of 9. The third task has no uncertainty at all (4, 4, 4), and contributes exactly 4 hours.
````

````exercise
id: m49-l05-e3
type: solve
prompt: |
  Write `projectFinish(initial:completed:added:window:)`. `completed` and `added` are per-day arrays of the same length. Return the day on which the remaining work is projected to reach zero, using the average completed per day over the last `window` days (or all days, if there are fewer), rounding up. Return `nil` if the recent pace is zero. If nothing remains, return the number of days so far.

  ```swift
  print(projectFinish(initial: 40, completed: [3, 5, 2, 4, 3, 5], added: [0, 0, 0, 6, 0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 10, completed: [5, 5], added: [0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 10, completed: [2, 0, 0, 0], added: [0, 0, 0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 20, completed: [4], added: [3], window: 3) ?? -1)
  ```

  should print:

  ```output
  12
  2
  -1
  6
  ```
starter: |
  func projectFinish(initial: Int, completed: [Int], added: [Int], window: Int) -> Int? {
      return nil
  }
rubric:
  - Computes remaining as initial minus total completed plus total added.
  - Uses only the last `window` days (or fewer) for the pace.
  - Uses integer ceiling division, and returns nil for zero pace.
  - Handles the case where nothing remains.
hints:
  - "`completed.suffix(window)` gives at most `window` elements."
  - "Days left is remaining × count ÷ recent total, rounded up."
solution: |
  ```swift
  func projectFinish(initial: Int, completed: [Int], added: [Int], window: Int) -> Int? {
      let remaining = initial - completed.reduce(0, +) + added.reduce(0, +)
      if remaining <= 0 { return completed.count }
      let recent = completed.suffix(window)
      let recentTotal = recent.reduce(0, +)
      guard recentTotal > 0 else { return nil }
      let daysLeft = (remaining * recent.count + recentTotal - 1) / recentTotal
      return completed.count + daysLeft
  }

  print(projectFinish(initial: 40, completed: [3, 5, 2, 4, 3, 5], added: [0, 0, 0, 6, 0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 10, completed: [5, 5], added: [0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 10, completed: [2, 0, 0, 0], added: [0, 0, 0, 0], window: 3) ?? -1)
  print(projectFinish(initial: 20, completed: [4], added: [3], window: 3) ?? -1)
  ```

  ```output
  12
  2
  -1
  6
  ```

  1. The lesson's burndown: 24 remaining, 12 points in the last 3 days, 6 more days, day 12.
  2. Everything done on day 2.
  3. Nothing completed in the last three days: a zero pace means there's no projection, and that's itself the signal to talk about what's blocking the work.
  4. One day: 20 − 4 + 3 = 19 remaining, at 4 a day, which is 4.75 days, rounded up to 5, so day 6.

  `remaining * recent.count / recentTotal` is remaining ÷ (recentTotal ÷ count), rearranged so the division happens last and stays exact until the rounding.
````

````exercise
id: m49-l05-e4
type: find-errors
prompt: "A task list and estimate for adding reminders to Habit Ledger. Mark every real problem."
code: |
  Reminders: 2 days
  - Reminder settings screen: 4 h
  - Schedule local notifications: 4 h
  - Notification permission flow: 2 h
  - Support every calendar system, time zone and DST edge case: 1 h
  Total: 10 h, so we commit to Tuesday.
choices:
  - text: "No tests, accessibility pass, localization or review time in the list."
    correct: true
  - text: "Single numbers per task, with no range or assumptions."
    correct: true
  - text: "The time zone task is large and uncertain but estimated at one hour; it should be broken down or spiked."
    correct: true
  - text: "The commitment is set to the sum of the estimates, with no buffer for the spread."
    correct: true
  - text: "Reminders should never be estimated in hours."
    correct: false
rubric:
  - I flagged the missing non-coding tasks.
  - I flagged the single-number estimates.
  - I flagged the underestimated, unbroken time zone task.
  - I flagged committing to the sum with no buffer.
solution: |
  Four problems:

  - **Missing work.** Tests (scheduling logic, the "no reminder after check-in" rule), VoiceOver and Dynamic Type for the settings screen, strings in the String Catalog, review and fixes. Probably as much as the coding.
  - **No ranges.** Each task needs O, M and P, or at least a range.
  - **The time zone task.** "Every calendar system, time zone and DST edge case" in one hour is a sign of a task nobody has looked at. Break it into specific cases (reminder time across a DST change, after travel) or run a spike first.
  - **Committing to the sum.** The commitment should come from the upper part of the range, and say what it assumes.

  Hours are a fine unit for a task this size; the unit isn't the problem.
````

````exercise
id: m49-l05-e5
type: design
prompt: "It's Wednesday. Your capstone review is Monday. You have about 12 hours of work left on the musts, and you just learned that the reviewers expect the weekly chart (a should, about 10 hours) to be shown. You have about 16 working hours before Monday. Write what you'll do, and the message you'd send to the reviewers."
rubric:
  - Computes that the work doesn't fit (22 hours of work, 16 available) and says so early.
  - Keeps the definition of done for everything that ships, rather than cutting quality.
  - Offers at least two concrete options with their consequences.
  - Asks the reviewers to choose, or proposes a default with a deadline for objections.
  - Updates the plan and the won't list after the decision.
solution: |
  The arithmetic first: 12 + 10 = 22 hours of work, 16 hours available, and that's before any spread on the estimates. It doesn't fit, and Wednesday is the time to say so.

  A message:

  > Hi, the weekly chart is about 10 hours of work and the remaining must-haves about 12, and I have about 16 hours before Monday. Options:
  >
  > 1. Finish the must-haves to the full definition of done and show the chart's design and its data aggregation (with tests), without the chart view. The chart ships next week.
  > 2. Ship a simpler chart: a text list of weekly totals, which is already accessible and takes about 3 hours, plus the must-haves.
  > 3. Move the review to Wednesday and show everything.
  >
  > I'd suggest option 2. If I don't hear otherwise by Thursday noon, I'll go with it. In every option, everything shown passes the same definition of done.

  Then: update the plan, move the full chart to the should list for next week, and note in the README's "what I'd do next" what was cut and why. Cutting the chart's tests or the accessibility pass to squeeze everything in isn't one of the options.
````

## Summary

- Break features into tasks of a day or less, and include tests, accessibility, localization, review and release. Spike what you can't estimate.
- Give three-point estimates. PERT: expected = (O + 4M + P) / 6, σ = (P − O) / 6; expected values add, variances add (for independent tasks). The total comes out above the sum of most-likely values.
- Integer arithmetic (sixths, tenths, an integer square root) keeps the numbers exact and the output identical on every platform.
- Communicate a range with its assumptions and when it will narrow. A commitment is a choice made from the range.
- Track completed work and added scope separately; project from recent pace; raise a slip the day the data shows it.
- When the work doesn't fit, negotiate scope or the date with concrete options. Quality isn't a lever.
