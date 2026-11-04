---
id: m49-l03
title: Working in legacy code and reviewing well
description: "Joining a team means learning a codebase you didn't write and reviewing changes to it. You plan your first weeks so your fresh eyes turn into contributions, answer \"why is it like this?\" from version control with git blame, git log --follow and the pickaxe (git log -S), skip formatting commits with an ignore-revs file, review in an order that finds design problems before typos, label comments by weight, respond when a reviewer is wrong, and pick checklist items from what a change touches. The git output comes from a real repository; the checklist evaluator is plain Swift, compiled and run."
module: m49
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m49-l02, m43-l06, m14-l04]
objectives:
  - Plan the first weeks in an unfamiliar codebase so that early questions and fixes become contributions.
  - Find who changed a line, when and why with git blame, git log --follow and git log -S.
  - Exclude formatting-only commits from blame with -w or an ignore-revs file.
  - Review a change in an order that surfaces design and correctness problems before style.
  - Label review comments by weight and respond to feedback you disagree with using evidence.
  - Build a review checklist from what a change touches, and model it in Swift.
terms:
  - term: Legacy code
    definition: "Code you have to change but didn't write and don't fully understand yet, usually without enough tests. Age alone doesn't make code legacy."
  - term: git blame
    definition: "A command that shows, for each line of a file, the last commit that changed it, with author and date."
  - term: Pickaxe
    definition: "git log -S <text>: lists commits that changed the number of occurrences of <text>, which finds when a piece of code was added or removed."
  - term: Ignore-revs file
    definition: "A file (by convention .git-blame-ignore-revs) listing full commit hashes that git blame should skip, such as reformatting commits. Pass it with --ignore-revs-file or the blame.ignoreRevsFile setting."
  - term: Nit
    definition: "A label for a minor, optional review comment. Google's review guide: a point of polish the author 'could choose to ignore.'"
  - term: Stacked pull requests
    definition: "A series of small pull requests where each one is based on the previous one's branch, so a large change can be reviewed in parts."
mastery:
  - Write a plan for your first two weeks on a new codebase that produces at least two contributions.
  - Find the commit that introduced a given line, even across a file move and a reformatting commit.
  - Explain the difference between git log -- <path> and git log --follow -- <path> on a renamed file.
  - Review a pull request starting with design and tests, and write comments labeled blocking, nit, optional or FYI.
  - Answer a review comment you disagree with by citing data or the style guide instead of preference.
  - Derive the checklist items that apply to a change from the areas it touches.
resources: [github-pull-request-reviews, git-commit-reference, swift-api-design-guidelines, conventional-commits]
cards:
  - id: m49-l03-c1
    front: "A line looks wrong. Which git command tells you when and why it was added?"
    back: "git blame -L <n>,<n> <file> to find the commit (with -w or --ignore-revs-file to skip reformatting), then git show <hash> to read its message. git log -S \"<text>\" finds the commit that added or removed that text."
  - id: m49-l03-c2
    front: Why does git log -- Path/File.swift stop at the commit that moved the file?
    back: "With a path filter, git follows that path only. Before the move the file had another name. git log --follow -- Path/File.swift follows renames for a single file."
  - id: m49-l03-c3
    front: What's the senior principle of Google's code review guide?
    back: "Reviewers should favor approving a change once it definitely improves the overall code health of the system, even if it isn't perfect."
  - id: m49-l03-c4
    front: In what order should you review a pull request?
    back: "Description and design first (should this change exist, is it in the right place), then tests, then correctness of the code, then naming and readability, and nits last. A typo comment on a change with the wrong design wastes everyone's time."
  - id: m49-l03-c5
    front: How do you answer a review comment you disagree with?
    back: "With evidence: a test, a measurement, the style guide or the documentation. Google's guide: technical facts and data overrule opinions and personal preferences. If two rounds don't settle it, talk synchronously."
---

## The idea in one sentence

In a codebase you didn't write, the history already knows why most things are the way they are, so you ask it before you change anything, and when you review other people's changes you look for the problems that are expensive to fix later before the ones that are cheap.

> [!note] Sources and what was checked
> The git commands were run with Git 2.43 in a throwaway repository with fixed dates and fictional authors, and the output is pasted as printed. The quotations from Google's code review guide come from google.github.io/eng-practices/review/ ("The Standard of Code Review," "Speed of Code Reviews," "How to write code review comments"), read in November 2026. The ignore-revs behavior was checked against the git-blame documentation and GitHub's documentation on the blame view. The Swift block is compiled and run with Swift 6.3.

## Building on what you have

Module 14 covered the pull request workflow, writing descriptions and comments, and receiving feedback. Module 43 covered reading an unfamiliar codebase (entry points, one main task end to end, change hotspots), characterization tests, and refactoring in small reversible steps. This lesson doesn't repeat those. It adds three things: how to spend your first weeks, how to ask the repository's history "why?", and how review works when you're the experienced one.

## Your first weeks

You have something nobody else on the team has: you don't know the workarounds yet. Every undocumented setup step, confusing name and surprising behavior is visible to you for about two weeks, and then you'll have absorbed it too. Turn that into contributions:

- **Keep a questions log.** One file, every question you have, with the answer once you find it and where you found it. Some answers become README edits, some become a glossary, and the ones nobody can answer become tickets.
- **Make the setup instructions true.** Your first pull request should be the README fix for whatever didn't work when you followed it. It's low risk, it teaches you the team's review process, and the next person benefits immediately.
- **Find the owners.** Who reviews changes to checkout? A `CODEOWNERS` file, the blame output below, or the history of recent pull requests will tell you. Ask them for 30 minutes, with your questions log open.
- **Take a small bug first.** A real bug with a clear reproduction gets you through the build, the tests, the review and the release process with something small enough to finish.
- **Match conventions before proposing new ones.** If the codebase uses delegates and you prefer closures, use delegates. Consistency helps the next reader more than your preference does. Write your proposal down (lesson 2's ADRs are the place for it) and raise it once you've earned some context.

There's an old rule, usually credited to G. K. Chesterton, that applies to legacy code directly: if you find a fence across a road and can't see why it's there, don't remove it until you find out. In code, most fences have a reason written down somewhere: in a commit message, a ticket, a review thread. The next section is how you find it.

## Asking the history "why?"

Module 43 ended its characterization tests for Pantry's delivery fee with an open question: a subtotal of exactly $50 is **not** free, because the code says `>` and not `>=`. "That might be a bug, or what marketing promised. That's a product question." Before you ask a product manager, ask git. This is the current file:

```swift
func deliveryFee(subtotalCents: Int, distanceMeters: Int, isMember: Bool) -> Int {
    var fee = 499
    if subtotalCents > 5_000 { fee = 0 }
    if distanceMeters > 10_000 { fee += 200 }
    if isMember { fee = fee / 2 }
    return fee
}

print(deliveryFee(subtotalCents: 5_000, distanceMeters: 2_000, isMember: false))
print(deliveryFee(subtotalCents: 5_001, distanceMeters: 2_000, isMember: false))
```

```output
499
0
```

### git blame: the last change to each line

```bash
git blame --date=short Pantry/Checkout/DeliveryFee.swift
```

```output
039417f6 Pantry/Checkout/DeliveryFee.swift (Ben Carter 2024-02-12 1) func deliveryFee(subtotalCents: Int, distanceMeters: Int, isMember: Bool) -> Int {
9a2c85a4 Pantry/Checkout/DeliveryFee.swift (Dana Reyes 2023-04-20 2)     var fee = 499
9a2c85a4 Pantry/Checkout/DeliveryFee.swift (Dana Reyes 2023-04-20 3)     if subtotalCents > 5_000 { fee = 0 }
9a2c85a4 Pantry/Checkout/DeliveryFee.swift (Dana Reyes 2023-04-20 4)     if distanceMeters > 10_000 { fee += 200 }
039417f6 Pantry/Checkout/DeliveryFee.swift (Ben Carter 2024-02-12 5)     if isMember { fee = fee / 2 }
9a2c85a4 Pantry/Checkout/DeliveryFee.swift (Dana Reyes 2023-04-20 6)     return fee
^5054d9e Pantry/DeliveryFee.swift          (Ana Lopez  2020-03-02 7) }
```

Each line shows the commit that last touched it, the path the file had in that commit, the author, the date and the line number. Two things to read here:

- **Dana touched almost everything on one day.** That's suspicious for a fee function, and it's the usual sign of a formatting commit. Blame shows the *last* change to each line, and reformatting is a change.
- **The path column appears** because the file was renamed at some point: line 7 comes from a commit where it was still `Pantry/DeliveryFee.swift`. Blame follows the line across the rename by itself. The `^` before the hash marks the repository's first commit.

### Seeing through formatting commits

The quickest fix is `-w`, which ignores whitespace when matching lines. That works for a reindent. For formatting commits that change more than whitespace (a formatter that rewraps lines, adds trailing commas), list them in a file that blame skips. By convention it's `.git-blame-ignore-revs` at the repository root, with one full hash per line and `#` comments:

```bash
cat .git-blame-ignore-revs
```

```output
# Reindent Swift files to four spaces
9a2c85a4cc6dacb37d565a929764ef90ae29ab82
```

```bash
git blame --ignore-revs-file .git-blame-ignore-revs --date=short -L 2,4 Pantry/Checkout/DeliveryFee.swift
```

```output
^5054d9e Pantry/DeliveryFee.swift (Ana Lopez  2020-03-02 2)     var fee = 499
236470a8 Pantry/DeliveryFee.swift (Ben Carter 2020-06-15 3)     if subtotalCents > 5_000 { fee = 0 }
5177088a Pantry/DeliveryFee.swift (Ana Lopez  2021-01-11 4)     if distanceMeters > 10_000 { fee += 200 }
```

`-L 2,4` limits the output to lines 2 to 4. Line 3, the one you care about, comes from Ben Carter's commit `236470a8` in June 2020. To make the file apply every time, run `git config blame.ignoreRevsFile .git-blame-ignore-revs` once in your clone. GitHub's blame view reads a `.git-blame-ignore-revs` file at the repository root automatically.

> [!tip] Commit the ignore file in the same pull request as the reformat
> When a team reformats a codebase, adding the commit's hash to `.git-blame-ignore-revs` right after it merges keeps blame useful for everyone. Without it, every line in the project "belongs" to whoever ran the formatter.

### Reading the commit

```bash
git show --stat 236470a
```

```output
commit 236470a88a4f0bfa9a436cac364e9b8de3b201e4
Author: Ben Carter <ben@example.com>
Date:   Mon Jun 15 16:30:00 2020 -0500

    Make delivery free for orders over $50
    
    The promotion's terms say "orders over $50", so a subtotal of exactly
    $50.00 still pays the fee. Confirmed with marketing in PROMO-112.

 Pantry/DeliveryFee.swift | 1 +
 1 file changed, 1 insertion(+)
```

There's the answer: `>` is deliberate, it follows the promotion's terms, and there's a ticket to read. The characterization test's note in Module 43 can now say "per PROMO-112" instead of "might be a bug." This is also why Module 14 asked you to write commit messages that explain **why**: four years later, that message was the documentation.

### Following a file across a rename

To list every commit that touched the file, the obvious command stops early:

```bash
git log --oneline -- Pantry/Checkout/DeliveryFee.swift
```

```output
039417f Halve the delivery fee for members
9a2c85a Reindent Swift files to four spaces
fb27833 Move checkout files into the Checkout folder
```

With a path filter, git looks at that path only, and before `fb27833` the file lived somewhere else. `--follow` tracks renames for a single file:

```bash
git log --oneline --follow -- Pantry/Checkout/DeliveryFee.swift
```

```output
039417f Halve the delivery fee for members
9a2c85a Reindent Swift files to four spaces
fb27833 Move checkout files into the Checkout folder
5177088 Add a surcharge for deliveries over 10 km
236470a Make delivery free for orders over $50
5054d9e Add delivery fee calculation
```

### The pickaxe: when did this text appear?

Blame answers "who last changed this line." Sometimes the question is "when did `5_000` first appear, anywhere?" `git log -S` lists commits that changed the number of occurrences of a string:

```bash
git log -S "5_000" --oneline
```

```output
236470a Make delivery free for orders over $50
```

The reindent and the move don't appear: the reindent kept one `5_000`, and git detected the move as a rename, so neither changed the count. The pickaxe is the tool when a line has been edited so many times that blame keeps pointing at the wrong commit, or when the code you're looking for was deleted and blame can't see it at all.

> [!warning] Pickaxe plus a path needs --follow too
> `git log -S "5_000" --oneline -- Pantry/Checkout/DeliveryFee.swift` (without `--follow`) printed `fb27833 Move checkout files into the Checkout folder` in the same repository: from that path's point of view, the move is when the file, and the text, first appeared. Add `--follow`, or drop the path.

### When did the behavior change?

When you know a behavior is broken now and was fine at some older commit, but not which commit changed it, `git bisect` does a binary search through the history: you mark one good and one bad commit, and git checks out the midpoint for you to test, repeatedly. With a script that exits 0 for good and non-zero for bad, `git bisect run` does the whole search by itself:

```bash
git bisect start <bad-commit> <good-commit>
git bisect run ./scripts/check-delivery-fee.sh
git bisect reset
```

It's how you find the commit behind a regression in a few steps instead of reading hundreds of diffs. The script is the part you write: usually a single test, run with `swift test --filter`.

## Reviewing as the experienced one

Module 14 taught the three questions (correctness, clarity, tests) and how to phrase comments. Once you know the codebase, you'll review more than you write, and the job changes in three ways.

### The standard: better, not perfect

Google's code review guide states its senior principle as: "In general, reviewers should favor approving a CL once it is in a state where it definitely improves the overall code health of the system being worked on, even if the CL isn't perfect." (CL, "changelist," is Google's term for a pull request.) Blocking a good change until it matches how you'd have written it costs more than the difference. Blocking a change that makes the code worse is the reviewer's job.

### The order

Review the expensive problems first, because comments on details are wasted if the design changes:

1. **The description.** What problem, why now, how it was tested. If you can't tell, ask before reading the diff.
2. **Design and placement.** Should this change exist? Is it in the right module? Does it fit the ADRs, or does it need a new one?
3. **The tests.** Read them before the implementation: they tell you what the author thinks the code does, and whether a regression would be caught. In legacy code, check that refactoring commits and behavior changes are separate (Module 43), so each can be verified on its own.
4. **Correctness.** Edge cases, concurrency, error paths, what happens on old data.
5. **Readability and naming.**
6. **Nits.**

If the change is too big to review well (a common threshold is a few hundred lines of real change, but your team will have its own), say so and ask for it to be split. Stacked pull requests, each based on the previous one's branch, let a large feature go through review in parts.

### Labels and speed

Label every comment by weight, so the author knows what blocks the merge. Google's guide suggests prefixes such as "Nit:" ("a minor thing. Technically you should do it, but it won't hugely impact things"), "Optional (or Consider):" ("I think this may be a good idea, but it's not strictly required") and "FYI:" ("I don't expect you to do this in this CL, but you may find this interesting to think about for the future"). Anything without a label reads as required, so use one.

Speed matters too: a waiting review blocks someone. Google's guide: "One business day is the maximum time it should take to respond to a code review request (i.e., first thing the next morning)." Responding can mean "I'll review this after lunch" or "I'm not the right reviewer, try Dana."

### When the reviewer is wrong (or you are)

Disagreement in review is normal; the way to settle it is evidence. Google's guide: "Technical facts and data overrule opinions and personal preferences. On matters of style, the style guide is the absolute authority." In practice:

- **Reviewer says it's slower.** Measure it, paste the numbers.
- **Reviewer says a case is broken.** Write the test. If it passes, add it to the pull request anyway: the reviewer's question is now answered permanently.
- **Style disagreement not covered by the guide.** The author's choice wins, and if it keeps coming up, propose an addition to the style guide in its own pull request.
- **Two rounds and no agreement.** Talk on a call, then write the outcome in the thread so the reasoning isn't lost.

And review your own pull request first. Read the diff on the hosting site before requesting review, as if someone else wrote it. You'll catch the debug `print`, the commented-out block and the test you forgot to commit, and your reviewer can spend their time on design.

### A checklist built from what the change touches

A fixed checklist for every pull request either grows until nobody reads it or stays too short to help. A better approach: a short list of items per area, and you apply the areas the change touches. That's a pure function of a few facts about the diff:

```swift
struct Change {
    var linesChanged = 0
    var hasTests = false
    var touchesUI = false
    var addsUserFacingText = false
    var changesStoredModel = false
    var touchesSecretsOrAuth = false
    var addsDependency = false
    var mixesRefactorAndBehavior = false
}

struct Item {
    let text: String
    let blocking: Bool
}

func checklist(for change: Change) -> [Item] {
    var items: [Item] = []
    if !change.hasTests {
        items.append(Item(text: "Add tests that would fail if this broke", blocking: true))
    }
    if change.mixesRefactorAndBehavior {
        items.append(Item(text: "Split the refactor from the behavior change", blocking: true))
    }
    if change.linesChanged > 400 {
        items.append(Item(text: "Consider splitting: \(change.linesChanged) lines", blocking: false))
    }
    if change.touchesUI {
        items.append(Item(text: "VoiceOver labels and largest Dynamic Type checked", blocking: true))
        items.append(Item(text: "Screenshots in the description, light and dark", blocking: false))
    }
    if change.addsUserFacingText {
        items.append(Item(text: "Strings in the String Catalog, no concatenation", blocking: true))
    }
    if change.changesStoredModel {
        items.append(Item(text: "Migration from the previous model tested", blocking: true))
    }
    if change.touchesSecretsOrAuth {
        items.append(Item(text: "No secrets or personal data in code or logs", blocking: true))
    }
    if change.addsDependency {
        items.append(Item(text: "Dependency justified in an ADR, license checked", blocking: true))
    }
    return items
}

func printChecklist(_ title: String, _ change: Change) {
    let items = checklist(for: change)
    let blocking = items.filter(\.blocking).count
    print("\(title): \(items.count) items, \(blocking) blocking")
    for item in items {
        print("  [\(item.blocking ? "blocking" : "optional")] \(item.text)")
    }
}

printChecklist("Fix typo in README", Change(linesChanged: 2, hasTests: true))
printChecklist("Weekly chart", Change(linesChanged: 520, hasTests: true, touchesUI: true, addsUserFacingText: true))
printChecklist("Add notes to check-ins", Change(linesChanged: 180, hasTests: false, changesStoredModel: true, mixesRefactorAndBehavior: true))
```

```output
Fix typo in README: 0 items, 0 blocking
Weekly chart: 4 items, 2 blocking
  [optional] Consider splitting: 520 lines
  [blocking] VoiceOver labels and largest Dynamic Type checked
  [optional] Screenshots in the description, light and dark
  [blocking] Strings in the String Catalog, no concatenation
Add notes to check-ins: 3 items, 3 blocking
  [blocking] Add tests that would fail if this broke
  [blocking] Split the refactor from the behavior change
  [blocking] Migration from the previous model tested
```

- **The facts are booleans the author or a script fills in.** Some come from the diff itself (lines changed, whether test files changed, whether a dependency manifest changed); others need judgment ("mixes refactor and behavior"). A pull request template with checkboxes is the manual version of this function.
- **The typo fix gets no items.** A checklist that asks a two-line README change about VoiceOver trains people to tick boxes without reading them.
- **Size is advice, not a gate.** 520 lines might be one generated file plus a small change. The reviewer decides; the item makes sure someone asked.
- **The notes change fails three ways at once**, and every one is blocking: no tests, a stored-model change without a migration test, and a refactor mixed into a behavior change, which makes the other two harder to review.

## Common mistakes

> [!error] Trusting blame's first answer
> The last commit to touch a line is often a reformat, a rename or a mechanical migration. Use `-w`, an ignore-revs file or the pickaxe, and read the commit message before drawing conclusions.

> [!error] Using blame to find someone to blame
> Blame tells you whom to ask and which commit to read. The person who wrote the line made a reasonable call with what they knew; the commit message usually says what that was.

> [!error] Fixing a fence you don't understand
> Changing `>` to `>=` in the delivery fee would have broken a promotion's terms. Look for the reason first; if there really isn't one, pin the behavior with a test and make the change as a separate, labeled behavior change.

> [!error] Reviewing top to bottom
> Starting with line 1 of the diff means your first ten comments are about naming in a file whose design is wrong. Read the description, the design and the tests first.

> [!error] Unlabeled comments
> The author can't tell which of your fourteen comments block the merge, so they treat all of them as required, or none. Label by weight.

> [!error] Sitting on a review
> A pull request waiting three days for review stalls the author and invites bigger, riskier pull requests. Respond within a business day, even if the response is "I'll get to this tomorrow."

## Exercises

````exercise
id: m49-l03-e1
type: comprehension
prompt: "Habit Ledger's streak code has a line `if gapInDays > 1 { streak = 0 }`. You want to know which commit first introduced the threshold `> 1`, but the line has since been reformatted twice and moved to a new file. Which command answers that most directly?"
choices:
  - text: "git log -S \"gapInDays > 1\" --oneline"
    correct: true
    why: "The pickaxe lists commits that changed how many times the text appears. Reformatting that keeps the text and a detected rename don't count, so the commit that added it stands out."
  - text: "git blame StreakCalculator.swift"
    correct: false
    why: "Blame shows the last change to each line, which here is a reformat."
  - text: "git log --oneline -- Sources/Domain/StreakCalculator.swift"
    correct: false
    why: "Without --follow, history stops at the move, and it lists every commit to the file, not the one that introduced the text."
  - text: "git show HEAD"
    correct: false
    why: "That shows only the latest commit."
solution: |
  **`git log -S "gapInDays > 1" --oneline`.** It lists commits that changed the number of occurrences of the string, so it finds the one that introduced it regardless of later reformatting or moves that kept it intact. Then `git show <hash>` to read why.

  If a reformat did change the text itself (say, `gapInDays>1` to `gapInDays > 1`), that commit would also appear; that's when an ignore-revs file and `git blame` become the better pair. Note also that `-S` matches text literally by default; for a regular expression, use `-G`.
````

````exercise
id: m49-l03-e2
type: prediction
prompt: "A smaller version of the checklist builder. What does this program print?"
code: |
  struct Change {
      var hasTests = false
      var touchesUI = false
      var linesChanged = 0
  }

  func checklist(for change: Change) -> [String] {
      var items: [String] = []
      if !change.hasTests { items.append("tests") }
      if change.touchesUI { items.append("accessibility") }
      if change.linesChanged > 400 { items.append("split") }
      return items
  }

  let changes = [
      Change(hasTests: true),
      Change(touchesUI: true, linesChanged: 400),
      Change(hasTests: true, touchesUI: true, linesChanged: 401),
  ]
  for change in changes {
      let items = checklist(for: change)
      print(items.isEmpty ? "ready" : items.joined(separator: "+"))
  }
output: |
  ready
  tests+accessibility
  accessibility+split
hints:
  - "Properties you don't pass keep their default value."
  - "400 isn't greater than 400."
solution: |
  ```output
  ready
  tests+accessibility
  accessibility+split
  ```

  1. Has tests, no UI, 0 lines: nothing applies.
  2. `hasTests` defaults to `false`, so "tests"; it touches UI, so "accessibility"; 400 lines is exactly the threshold, and `>` excludes it.
  3. Has tests; UI; 401 lines is over the threshold.

  The memberwise initializer lets you skip any property that has a default value, but you must pass the ones you do give in declaration order.
````

````exercise
id: m49-l03-e3
type: find-errors
prompt: "Review comments left on a teammate's pull request that adds notes to check-ins. Mark every comment with a real problem."
code: |
  1. "Line 12: missing space after the comma."  (the first comment on the PR)
  2. "This is confusing."
  3. "Blocking: CheckIn gained a `note` property, but there's no migration test from the version without it. Could you add one that opens a store created by the previous model?"
  4. "Why would anyone use a String here?"
  5. "Nit: `noteText` might read better as `note`, since the type already says it's text."
  6. "LGTM" (posted 4 days after the review was requested, on a 900-line diff)
choices:
  - text: "Comment 1: a style nit posted first, unlabeled, before any comment on design or tests. A formatter should catch it."
    correct: true
  - text: "Comment 2: vague. It doesn't say what is confusing or what would be clearer."
    correct: true
  - text: "Comment 3: it labels the weight, names the risk and proposes a specific test."
    correct: false
  - text: "Comment 4: phrased as an accusation instead of a question or a suggestion with a reason."
    correct: true
  - text: "Comment 5: a labeled nit with a reason."
    correct: false
  - text: "Comment 6: four days late, and an approval of a 900-line diff with no sign it was read; it should have asked for a split."
    correct: true
rubric:
  - I flagged the unlabeled style nit.
  - I flagged the vague comment.
  - I flagged the accusatory question.
  - I flagged the late rubber-stamp approval.
  - I left comments 3 and 5 alone.
solution: |
  Comments 1, 2, 4 and 6 have problems; 3 and 5 are good examples.

  - **1.** Style issues belong to a formatter or linter. If you must mention one, label it "Nit:" and leave it for last.
  - **2.** Rewrite as something like: "I had to read `merge(_:)` three times to see that it keeps the newer note. A name like `keepingNewerNote(_:)` or a one-line comment would help."
  - **4.** Rewrite as a question with your concern: "Notes could get long. Do we want a length limit, or is unbounded fine here?"
  - **6.** Respond within a business day, and for a 900-line change, ask for it to be split rather than approving what you didn't read.
````

````exercise
id: m49-l03-e4
type: solve
prompt: |
  Write `ignoredRevisions(in:)`, which parses the text of a `.git-blame-ignore-revs` file and returns the hashes it lists, in order. Lines may have leading or trailing spaces; blank lines and lines starting with `#` are ignored; a valid hash is exactly 40 characters, all `0-9` or `a-f`. Invalid lines are skipped.

  ```swift
  let file = """
  # Reindent Swift files to four spaces
  9a2c85a4cc6dacb37d565a929764ef90ae29ab82

    # swift-format pass
    1f0e3dad99908345f7439f8ffabdffc4f7f6e6c7  
  9a2c85a
  """
  print(ignoredRevisions(in: file))
  ```

  should print:

  ```output
  ["9a2c85a4cc6dacb37d565a929764ef90ae29ab82", "1f0e3dad99908345f7439f8ffabdffc4f7f6e6c7"]
  ```
starter: |
  func ignoredRevisions(in text: String) -> [String] {
      return []
  }
rubric:
  - Splits the text into lines and trims spaces from each.
  - Skips blank lines and comment lines.
  - Accepts only 40-character lowercase hexadecimal strings.
  - Keeps the order of the file.
hints:
  - "`split(separator: \"\\n\")` gives the lines; trim spaces with `drop(while:)` from both ends, or `filter` the characters you want to keep."
  - "`Character.isHexDigit` also accepts uppercase letters, so check the allowed characters yourself."
solution: |
  ```swift
  func ignoredRevisions(in text: String) -> [String] {
      let allowed = Set("0123456789abcdef")
      var hashes: [String] = []
      for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
          let trimmed = String(rawLine.drop(while: { $0 == " " }).reversed().drop(while: { $0 == " " }).reversed())
          if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
          if trimmed.count == 40 && trimmed.allSatisfy({ allowed.contains($0) }) {
              hashes.append(trimmed)
          }
      }
      return hashes
  }

  let file = """
  # Reindent Swift files to four spaces
  9a2c85a4cc6dacb37d565a929764ef90ae29ab82

    # swift-format pass
    1f0e3dad99908345f7439f8ffabdffc4f7f6e6c7  
  9a2c85a
  """
  print(ignoredRevisions(in: file))
  ```

  ```output
  ["9a2c85a4cc6dacb37d565a929764ef90ae29ab82", "1f0e3dad99908345f7439f8ffabdffc4f7f6e6c7"]
  ```

  - Trimming drops spaces from the front, reverses, drops from the front again, and reverses back. Foundation's `trimmingCharacters(in:)` does the same in one call if you import Foundation.
  - The comment line is indented, so the `#` check has to happen after trimming.
  - `9a2c85a` is an abbreviated hash. The git-blame documentation describes the file as holding one "unabbreviated object name per line," so it's rejected.
````

````exercise
id: m49-l03-e5
type: explain
prompt: "You suggested in review that a teammate replace a loop with `reduce`, saying it's faster. They replied: 'I measured both with 100,000 items in a performance test and the loop was slightly faster; I'd rather keep it because it reads more clearly to the rest of the team.' Explain how you should respond and why."
code: |
  var total = 0
  for checkIn in checkIns where checkIn.counts {
      total += checkIn.points
  }
rubric:
  - Recognizes that the author answered a claim with measurement.
  - Accepts the author's choice, since data overrules preference.
  - Resolves the thread explicitly instead of leaving it open.
  - Optionally suggests keeping the measurement somewhere useful.
solution: |
  Accept it and resolve the thread, something like: "Thanks for measuring. Loop it is." Your comment was a factual claim ("it's faster"), and the author answered it with data; Google's review guide puts it plainly: "Technical facts and data overrule opinions and personal preferences." What's left is readability, where the author's choice wins unless the style guide says otherwise.

  If the performance question is likely to come up again, suggest keeping the performance test in the suite. Then the next reviewer who wonders gets the answer from CI instead of from a thread.
````

````exercise
id: m49-l03-e6
type: design
prompt: "You join a team that maintains a five-year-old UIKit banking app. Write a plan for your first two weeks: what you'll do each few days, what you'll produce, and the questions you'll ask. It should produce at least two merged contributions."
rubric:
  - Builds and runs the app first and records every undocumented step.
  - Includes a questions log or glossary and says where the answers end up.
  - Names a first contribution that's low risk (setup docs, a small bug) and goes through the full review and CI process.
  - Uses history (blame, log, pull requests) and the owners to learn the riskiest areas.
  - Defers convention changes until there's context, and says where proposals will go.
solution: |
  A model plan:

  **Days 1–2.** Clone, build and run on a simulator and a device following only the README. Log every step that's missing or wrong, every warning count, every crash. Start `questions.md`. Read `CODEOWNERS` and the last month of merged pull requests to learn who reviews what.

  **Days 3–4.** First pull request: fix the README with everything from days 1–2. Learn the review process and CI on something harmless. Follow one main task end to end (Module 43's route), for example "transfer between my accounts."

  **Days 5–7.** Pick a small, well-reproduced bug. Before changing anything, read the history of the lines involved (`git blame` with the team's ignore-revs file, `git log --follow`, the linked tickets). Write a characterization test, fix, open the pull request with a description that cites what history told you.

  **Week 2.** 30 minutes each with the owners of two hotspot areas, with the questions log. Turn answered questions into a glossary page. Note conventions you'd change, and why, in a draft ADR, but don't propose it yet.

  **Questions to ask:** How is a release cut and who approves it? Which areas have no tests and everyone avoids? What's the incident process and where do postmortems live? Which ADRs or design docs should I read first?

  Two contributions by the end: the README fix and the bug fix with its test. The questions log, turned into a glossary, is a likely third.
````

## Summary

- Spend your first weeks turning fresh-eyes confusion into contributions: a questions log, a corrected README, a small bug fixed end to end. Match conventions before proposing changes.
- Ask the history before you change a line: `git blame` (with `-w` or an ignore-revs file to skip formatting commits), `git show` for the reason, `git log --follow` across renames, `git log -S` for when text appeared, `git bisect` for when behavior changed.
- Commit messages that explain why are what make history useful. The `>` in Pantry's delivery fee was a decision, and the message said so.
- Review in order of cost: description, design, tests, correctness, readability, nits. Approve changes that clearly improve code health even if they aren't how you'd write them.
- Label comments by weight, respond within a business day, and settle disagreements with tests, measurements and the style guide.
- Build the checklist from what a change touches, and check the output against the input.
