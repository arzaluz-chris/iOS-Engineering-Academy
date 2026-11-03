---
id: m14-l04
title: Pull requests and code review
description: You push a branch to a shared repository, follow a change through the pull request workflow from first push to merge, keep pull requests small and focused, write a description a reviewer can act on, review for correctness, clarity and tests, give and receive feedback that improves the code, and treat CI as a gate a change has to pass.
module: m14
order: 4
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l03]
objectives:
  - Push a branch to a remote with git push -u and keep it in sync with git pull.
  - Describe the pull request workflow from branch to merge and cleanup.
  - Explain why small, single-purpose pull requests get better reviews, and split a large one.
  - Write a pull request description with what, why, how it was tested and what to look at.
  - Review a change for correctness, clarity and tests, and write comments that are specific and actionable.
  - Respond to review feedback with follow-up commits and explain why CI must pass before merging.
terms:
  - term: Remote
    definition: "Another copy of the repository, usually on a server such as GitHub, that you push to and pull from. The default name for it is origin."
  - term: Push
    definition: "Sending your local commits on a branch to the remote."
  - term: Pull
    definition: "Fetching new commits from the remote and merging them into your current branch."
  - term: Pull request
    definition: "A request, on a hosting service like GitHub, to merge one branch into another. It shows the diff and collects discussion, reviews and automated checks. GitLab calls it a merge request."
  - term: Code review
    definition: "Another developer reading a change before it's merged, to catch bugs, improve clarity and share knowledge."
  - term: Continuous integration (CI)
    definition: "A service that builds the project and runs its tests automatically on every push, and reports the result on the pull request."
mastery:
  - Push a new branch with git push -u origin <branch> and explain what the tracking branch is for.
  - Write a pull request description for a change you made, including how you tested it.
  - Review a 20-line diff and leave at least one correctness comment, one clarity comment and one comment about tests.
  - Rewrite a vague or harsh review comment into a specific, kind and actionable one.
  - Explain what a required status check prevents.
resources: [swift-cli-getting-started]
cards:
  - id: m14-l04-c1
    front: What does git push -u origin feature do?
    back: "Sends the feature branch to the remote named origin and sets origin/feature as its upstream, so later a plain git push or git pull knows where to go."
  - id: m14-l04-c2
    front: Why keep pull requests small?
    back: "A reviewer can actually understand a small, single-purpose change, so they find real bugs. It's also faster to review, easier to revert and less likely to conflict."
  - id: m14-l04-c3
    front: What goes in a pull request description?
    back: "What changed, why, how you tested it (commands, devices, screenshots for UI), and anything the reviewer should look at closely or that's out of scope."
  - id: m14-l04-c4
    front: What three things does every review check?
    back: "Correctness (does it work, including edge cases), clarity (can the next person understand and change it) and tests (would they fail if the code broke)."
  - id: m14-l04-c5
    front: How do you answer review feedback on an open pull request?
    back: "Push new commits to the same branch; the pull request updates itself. Reply to each comment with what you changed or why you disagree."
---

## The idea in one sentence

A pull request turns "I pushed a branch" into a conversation about a specific diff, where another person and an automated build both have to agree before the change reaches `main`.

> [!note]
> The Git commands in this lesson were run with Git 2.43.0. A local bare repository (`git init --bare`) stood in for GitHub, so the push output is shorter than what you'll see against a real server, which also prints progress lines and sometimes a link for opening a pull request. The pull request itself happens on the hosting service's website and is described in prose; GitHub's own guide is [Creating a pull request](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request).

## Remotes: push and pull

So far the repository lived only on your machine. A team shares one copy on a server, the **remote**, conventionally called `origin`. You connect it once:

```bash
git remote add origin ../server.git
git remote -v
```

```output
origin	../server.git (fetch)
origin	../server.git (push)
```

With GitHub, the URL looks like `https://github.com/<owner>/<repo>.git`; `git clone` of an existing repository sets up `origin` for you. Send `main`:

```bash
git push -u origin main
```

```output
To ../server.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

`-u` sets the **upstream**: from now on, a plain `git push` or `git pull` on `main` knows it talks to `origin/main`.

## The pull request workflow

The whole loop, with the `Expenses` package. You want a `largest` property that returns the most expensive item.

**1. Start from an up-to-date main, on a new branch.**

```bash
git switch main
git pull
git switch -c largest-expense
```

**2. Make the change, commit, push the branch.**

```bash
git commit -am "Add largest to ExpenseReport"
git push -u origin largest-expense
```

```output
To ../server.git
 * [new branch]      largest-expense -> largest-expense
branch 'largest-expense' set up to track 'origin/largest-expense'.
```

```bash
git branch -vv
```

```output
* largest-expense c176da2 [origin/largest-expense] Add largest to ExpenseReport
  main            803e8e6 [origin/main] Add csvLine to Expense
```

Each local branch shows the remote branch it tracks in brackets.

**3. Open the pull request.** On the hosting service, you choose the branch to merge (`largest-expense`) and the branch to merge it into (`main`), and write a title and a description. The page then shows the commits, the combined diff, a place for comments, and the results of automated checks.

**4. Review happens.** A teammate reads the diff and leaves comments. They can also check the branch out and run it:

```bash
git clone server.git reviewer
cd reviewer
git switch largest-expense
```

```output
Switched to a new branch 'largest-expense'
branch 'largest-expense' set up to track 'origin/largest-expense'.
```

`git switch` with the name of a branch that exists only on the remote creates a local branch tracking it.

**5. You answer with more commits on the same branch.** You don't open a new pull request; you push to the same branch and the pull request shows the new commits:

```bash
git commit -am "Use max(by:) in largest and test ties"
git push
```

```output
To ../server.git
   c176da2..4cd1450  largest-expense -> largest-expense
```

**6. Merge.** Once it's approved and the checks pass, someone merges the pull request on the website. Hosting services usually offer more than one way to merge (a merge commit, squashing all commits into one, or rebasing them onto `main`); teams pick one and stick to it. Here it was merged with a merge commit.

**7. Clean up locally and on the remote.**

```bash
git switch main
git pull
```

```output
Switched to branch 'main'
Your branch is up to date with 'origin/main'.
From ../server
   803e8e6..e37b1ff  main       -> origin/main
Updating 803e8e6..e37b1ff
Fast-forward
 Sources/ExpenseCore/ExpenseReport.swift         | 4 ++++
 Tests/ExpenseCoreTests/ExpenseReportTests.swift | 8 ++++++++
 2 files changed, 12 insertions(+)
```

"Up to date with 'origin/main'" only means your branch matches the **last thing Git downloaded**; `git pull` is what fetches the new merge. Then delete the branch both locally and on the remote:

```bash
git branch -d largest-expense
git push origin --delete largest-expense
```

```output
Deleted branch largest-expense (was 4cd1450).
To ../server.git
 - [deleted]         largest-expense
```

```bash
git log --oneline --graph -4
```

```output
*   e37b1ff Merge branch 'largest-expense'
|\  
| * 4cd1450 Use max(by:) in largest and test ties
| * c176da2 Add largest to ExpenseReport
|/  
* 803e8e6 Add csvLine to Expense
```

## Small, focused pull requests

The single best thing you can do for your reviewer is to send them less. A 30-line diff with one purpose gets read line by line. A 1,500-line diff that adds a feature, renames a model and updates dependencies gets skimmed and approved, which means it wasn't reviewed.

Ways to keep them small:

- **One purpose per pull request.** If the title needs "and", it's probably two.
- **Separate refactoring from behavior changes.** First a pull request that renames or moves code with no change in behavior (easy to check: the tests still pass, nothing else changed). Then the feature on top.
- **Split by layer when a feature is big.** The model and its tests first, then the logic, then the screen. Each one builds and passes on its own.
- **Don't fix unrelated things on the way.** Note them and send them separately.

## Writing the description

The reviewer arrives cold. Tell them what they need to judge the change, and nothing they can read in the diff anyway. For the `largest` change:

```markdown
## Add `largest` to `ExpenseReport`

The upcoming summary screen highlights the most expensive item. This adds a
public `largest` property to `ExpenseCore` so the screen doesn't compute it.

- Returns `nil` for an empty report.
- On ties, returns the first expense added.

**Testing:** `swift test` (new test covers ties and the empty report).

**Look closely at:** whether ties should prefer the first or the last
expense. I chose the first; the design spec doesn't say.

**Not in this PR:** the summary screen itself.
```

What it does well: the **why** (a screen needs it), the **behavior decisions** spelled out, **how it was tested**, the one place the author is unsure, and the **scope**. For a UI change, add before-and-after screenshots.

## Reviewing a change

Here is the diff of the first commit, as the reviewer saw it:

```output
diff --git a/Sources/ExpenseCore/ExpenseReport.swift b/Sources/ExpenseCore/ExpenseReport.swift
index f90c163..04825a3 100644
--- a/Sources/ExpenseCore/ExpenseReport.swift
+++ b/Sources/ExpenseCore/ExpenseReport.swift
@@ -23,6 +23,14 @@ public struct ExpenseReport {
         "Total \(formatCents(totalCents)) for \(expenses.count) expenses, average \(formatCents(averageCents))"
     }
 
+    public var largest: Expense? {
+        var result: Expense? = nil
+        for expense in expenses where expense.cents > (result?.cents ?? Int.min) {
+            result = expense
+        }
+        return result
+    }
+
     package func lines() -> [String] {
         expenses.map { "\($0.title): \(formatCents($0.cents))" }
     }
```

Go through it with three questions, in this order.

**1. Correctness: does it do what it claims, including at the edges?** Empty list, one element, ties, negative values (refunds), very large values. Don't guess; run it:

```swift
struct Expense {
    let title: String
    let cents: Int
}

func largest(in expenses: [Expense]) -> Expense? {
    var result: Expense? = nil
    for expense in expenses where expense.cents > (result?.cents ?? Int.min) {
        result = expense
    }
    return result
}

let tie = [Expense(title: "Lunch", cents: 1299), Expense(title: "Dinner", cents: 1299)]
let refundsOnly = [Expense(title: "Refund", cents: -500)]

print(largest(in: tie)?.title ?? "none")
print(largest(in: [])?.title ?? "none")
print(largest(in: refundsOnly)?.title ?? "none")
```

```output
Lunch
none
Refund
```

It works: the strict `>` keeps the first of two equal amounts, an empty list gives `nil`, and starting from `Int.min` handles negative amounts.

**2. Clarity: will the next person understand it quickly?** The loop with `where` and `?? Int.min` takes a minute to verify. The standard library already has this:

```swift
struct Expense {
    let title: String
    let cents: Int
}

let tie = [Expense(title: "Lunch", cents: 1299), Expense(title: "Dinner", cents: 1299)]
let empty: [Expense] = []

print(tie.max { $0.cents < $1.cents }?.title ?? "none")
print(empty.max { $0.cents < $1.cents }?.title ?? "none")
```

```output
Lunch
none
```

`max(by:)` returns `nil` for an empty array and, in this run, kept the first of two equal elements, exactly like the loop. That's a clarity win with the same behavior, which the tests should pin down.

**3. Tests: would a test fail if this broke?** The commit adds a public API with two behavior decisions (ties, empty) and **no test**. That's the most important comment on this pull request.

Beyond those three, a reviewer also asks: is this the right place for the code (design and scope)? Is the naming consistent with the rest of the API? Does anything touch security, privacy or performance? Is anything missing, like documentation for a new public property?

### Writing review comments

The comments the reviewer left:

> **Blocking:** `largest` is public and makes two decisions, ties and empty, but there's no test for either. Could you add one that adds two expenses with the same amount and checks which one comes back, plus the empty case? That way a future refactor can't change it silently.

> **Suggestion:** this could be `expenses.max { $0.cents < $1.cents }`. I checked it with your tie example and it also returns the first one. Fine to keep the loop if you prefer.

> I like that it handles refunds by starting from `Int.min`. I wouldn't have thought of that.

What makes them work:

- **About the code, not the person.** "This has no test", not "you forgot the tests again".
- **Specific and actionable.** Which case, what to check, why it matters.
- **Labeled by weight.** Make clear what blocks the merge and what's optional. Many teams prefix small optional points with "nit:".
- **Questions when you're not sure.** "What happens if…?" invites the author to check instead of defending.
- **Real praise, specifically.** It tells the author what to keep doing.

Compare with comments that don't help: "This is confusing." (what is, and what would be clearer?), "Why didn't you use max?" (sounds like an accusation; suggest it instead), "LGTM" on a diff you skimmed.

### Receiving feedback

- **The comments are about the code.** Everyone's code gets comments; that's the process working.
- **Answer every comment**, even with "Done" or "Good catch, fixed in 4cd1450".
- **Push follow-up commits** to the same branch. Reviewers can then see exactly what changed since they last looked.
- **Disagree with reasons, not with silence.** "I kept the loop because…" is a fine answer. If you can't agree in two rounds, talk in person or on a call.
- **Don't merge around a reviewer.** If you need to merge before they're back, ask someone else to review.

The author's follow-up commit addressed both comments:

```output
diff --git a/Sources/ExpenseCore/ExpenseReport.swift b/Sources/ExpenseCore/ExpenseReport.swift
index 04825a3..09f6fe2 100644
--- a/Sources/ExpenseCore/ExpenseReport.swift
+++ b/Sources/ExpenseCore/ExpenseReport.swift
@@ -24,11 +24,7 @@ public struct ExpenseReport {
     }
 
     public var largest: Expense? {
-        var result: Expense? = nil
-        for expense in expenses where expense.cents > (result?.cents ?? Int.min) {
-            result = expense
-        }
-        return result
+        expenses.max { $0.cents < $1.cents }
     }
 
     package func lines() -> [String] {
diff --git a/Tests/ExpenseCoreTests/ExpenseReportTests.swift b/Tests/ExpenseCoreTests/ExpenseReportTests.swift
index 14a4694..3df9727 100644
--- a/Tests/ExpenseCoreTests/ExpenseReportTests.swift
+++ b/Tests/ExpenseCoreTests/ExpenseReportTests.swift
@@ -19,3 +19,11 @@ import Testing
 @Test func averageOfNoExpensesIsZero() {
     #expect(ExpenseReport().averageCents == 0)
 }
+
+@Test func largestKeepsTheFirstOfEqualAmounts() {
+    var report = ExpenseReport()
+    report.add(Expense(title: "Lunch", cents: 1299))
+    report.add(Expense(title: "Dinner", cents: 1299))
+    #expect(report.largest?.title == "Lunch")
+    #expect(ExpenseReport().largest == nil)
+}
```

```bash
swift test
```

```output
✔ Test run with 5 tests in 0 suites passed after 0.001 seconds.
```

## CI as a gate

People miss things; a build server doesn't forget to run the tests. **Continuous integration** runs on every push to a pull request: it checks out the branch, builds it and runs the tests, then reports a pass or fail on the pull request page.

This academy's own repository does it with a GitHub Actions workflow. An excerpt of `.github/workflows/swift.yml`:

```yaml
on:
  pull_request:
    paths: ['swift/**', 'content/lessons/**', '.github/workflows/swift.yml']

jobs:
  test:
    runs-on: macos-latest
    defaults:
      run:
        working-directory: swift
    steps:
      - uses: actions/checkout@v7
      - name: swift test
        run: swift test
```

Every pull request that touches the Swift code or the lessons gets `swift test` on a macOS machine, including the snippet tests that check this lesson's code. GitHub's introduction is [Understanding GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions).

A check only protects `main` if a red result actually stops the merge. On GitHub that's a **branch protection rule** on `main` that requires the status checks to pass and, usually, at least one approving review before the merge is allowed; see [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches). With that in place:

- Nobody merges a change that doesn't build, however small or urgent it looks.
- A reviewer can spend their attention on design and edge cases, because "does it compile, do the tests pass" is already answered.
- A red check is the author's job to fix, on the branch, before asking for another review.

CI can only enforce what the tests check. That's why the review asked for a test for ties: from then on, CI defends that decision on every future pull request.

## Common mistakes

> [!error] fatal: No configured push destination.
> The repository has no remote. Add one with `git remote add origin <url>` (or clone the repository instead of `git init`), then push.

> [!error] Opening the pull request from main
> Committing on your local `main` and pushing it means there's no branch to review, and if `main` is protected the push can be rejected. Create a branch first. If you already committed on `main`, `git switch -c <branch>` puts you on a new branch that has those commits, and `git branch -f main origin/main` moves your local `main` back to match the remote.

> [!error] A new pull request for every round of feedback
> Push follow-up commits to the same branch. The discussion and history stay in one place.

> [!error] Approving without reading
> "LGTM" on a diff you skimmed tells the author and the team it was checked when it wasn't. If you don't have time to review properly, say so.

> [!error] Treating a red check as somebody else's problem
> If CI fails on your branch, it's yours to fix, even if the failure looks unrelated. Find out why before re-running.

## Exercises

````exercise
id: m14-l04-e1
type: comprehension
prompt: You opened a pull request from `largest-expense`. A reviewer asks for a test. What do you do?
choices:
  - text: Close the pull request, add the test, and open a new one.
    correct: false
    why: That throws away the discussion and makes the reviewer start over.
  - text: Commit the test on largest-expense and git push; the pull request updates with the new commit.
    correct: true
    why: A pull request tracks a branch, so new commits pushed to it appear in the same pull request.
  - text: Commit the test directly on main so it's there when the pull request merges.
    correct: false
    why: Bypasses review and CI and splits one change across two places.
  - text: Ask the reviewer to add the test after merging.
    correct: false
    why: The test documents decisions the author made; it belongs in the same change.
solution: |
  **Commit on the same branch and push.** The pull request follows the branch, so it shows the new commit, CI runs again, and the reviewer sees exactly what changed since their comment. Reply to the comment with the commit hash.
````

````exercise
id: m14-l04-e2
type: prediction
prompt: "During review you test the `largest` loop against edge cases. What does this print?"
code: |
  struct Expense {
      let title: String
      let cents: Int
  }

  func largest(in expenses: [Expense]) -> Expense? {
      var result: Expense? = nil
      for expense in expenses where expense.cents > (result?.cents ?? Int.min) {
          result = expense
      }
      return result
  }

  let refunds = [Expense(title: "Shoes", cents: -4000), Expense(title: "Book", cents: -1200)]
  let mixed = [Expense(title: "Taxi", cents: 1800), Expense(title: "Hotel", cents: 9500), Expense(title: "Dinner", cents: 9500)]

  print(largest(in: refunds)?.title ?? "none")
  print(largest(in: mixed)?.title ?? "none")
  print(largest(in: [])?.title ?? "none")
output: |
  Book
  Hotel
  none
hints:
  - "-1200 is greater than -4000."
  - "The comparison is strict: an equal amount doesn't replace the current result."
solution: |
  ```output
  Book
  Hotel
  none
  ```

  - Refunds: the first one (`-4000`) beats `Int.min`; then `-1200 > -4000`, so `Book` wins. The "largest" of two refunds is the smaller refund, which is mathematically right and might surprise a product designer. Worth a question in the review.
  - Mixed: `Hotel` (9500) replaces `Taxi`; `Dinner` (9500) isn't **greater** than 9500, so `Hotel` stays.
  - Empty: the loop never runs, `result` stays `nil`, `?? "none"` prints `none`.
````

````exercise
id: m14-l04-e3
type: find-errors
prompt: "Mark the review comments that should be rewritten."
code: |
  A. "This is wrong."
  B. "nit: `amt` → `amountInCents` would match the rest of ExpenseCore."
  C. "Did you even run this?"
  D. "What happens when `expenses` is empty? I think `averageCents` divides by zero on line 31. Could you add a test for it?"
  E. "LGTM" (the reviewer opened the PR for ten seconds)
choices:
  - text: "A: doesn't say what is wrong or what would be right."
    correct: true
  - text: "C: attacks the author and gives no information about the problem."
    correct: true
  - text: "E: an approval without a review gives false confidence."
    correct: true
  - text: "B: nits should never be written."
    correct: false
    why: Labeled small suggestions are fine; the label tells the author it's optional.
  - text: "D: questions are too indirect for a review."
    correct: false
    why: D is specific (which case, which line, what to add) and phrased so the author checks instead of defending.
rubric:
  - I flagged A, C and E.
  - I kept B and D and said why they work.
  - I rewrote at least one of the bad comments.
solution: |
  Rewrite **A**, **C** and **E**:

  - A → "When two expenses have the same amount this returns the last one, but the description says the first. Is that intended?"
  - C → "I ran this with an empty report and it crashed on line 31 (division by zero). Can you guard that case and add a test?"
  - E → Either review it properly, or say "I don't have time to review this today; can someone else take it?"

  **B** is a labeled, optional, specific suggestion. **D** names the case, the line and the fix, as a question.
````

````exercise
id: m14-l04-e4
type: fill-in
prompt: You've finished work on `csv-export` and want to open a pull request, then clean up after it's merged. Fill in the commands.
code: |
  git push [[1]] origin csv-export
  # ... pull request reviewed and merged on the website ...
  git switch main
  git [[2]]
  git branch [[3]] csv-export
  git push origin [[4]] csv-export
blanks:
  - id: "1"
    answers: ["-u", "--set-upstream"]
  - id: "2"
    answers: ["pull"]
  - id: "3"
    answers: ["-d"]
  - id: "4"
    answers: ["--delete"]
solution: |
  ```bash
  git push -u origin csv-export
  git switch main
  git pull
  git branch -d csv-export
  git push origin --delete csv-export
  ```

  `-u` sets the upstream so later pushes need no arguments. `git pull` brings the merge into your local `main`, so `git branch -d` sees the branch as merged. The last line deletes the branch on the remote; many teams have the hosting service do that automatically on merge.
````

````exercise
id: m14-l04-e5
type: solve
prompt: |
  Write the pull request description for this change, using the structure from the lesson (what, why, decisions, testing, what to look at, out of scope). Invent reasonable details where needed.

  The change: `ExpenseReport` gets a method `expenses(over limitCents: Int) -> [Expense]` that returns the expenses strictly above a limit, in the order they were added. A budget warning screen will use it. Tests cover an empty report, a limit equal to an expense's amount, and negative limits.
starter: |
  ## Add expenses(over:) to ExpenseReport

  ...
rubric:
  - The description says why the change exists (the budget warning screen), not only what it is.
  - It states the behavior decisions (strictly above, order preserved).
  - It says how it was tested, with the command and the cases.
  - It points the reviewer at something specific to check.
  - It says what's out of scope.
solution: |
  ```markdown
  ## Add `expenses(over:)` to `ExpenseReport`

  The budget warning screen lists every expense above the user's limit.
  This adds the query to `ExpenseCore` so the screen only displays results.

  - Returns expenses with `cents` **strictly greater** than the limit;
    an expense equal to the limit isn't included.
  - Keeps the order expenses were added in.

  **Testing:** `swift test`. New tests: empty report, limit equal to an
  amount (excluded), negative limit (refunds below it are excluded).

  **Look closely at:** "strictly greater". If product wants "at or above",
  it's a one-character change, but I'd rather decide it here.

  **Not in this PR:** the warning screen and the user setting for the limit.
  ```

  The behavior decisions are what a reviewer can't read from the code alone without guessing whether they were intended. Naming them invites the right discussion.
````

````exercise
id: m14-l04-e6
type: design
prompt: "Your team ships an iOS app from one repository and has had two incidents: a pull request merged with failing tests, and a 2,000-line pull request that nobody really reviewed. Propose a pull request policy of five to seven rules, each with a one-line reason."
rubric:
  - Includes required CI checks (build and tests) before merge, with branch protection.
  - Includes at least one required approval.
  - Includes a guideline on size or single purpose, and separating refactors from behavior changes.
  - Includes a description standard (why, how tested, screenshots for UI).
  - Includes expectations for reviewers (response time, what to check, how to comment).
  - Every rule has a reason that ties back to the incidents or to review quality.
solution: |
  One reasonable policy:

  1. **`main` is protected: CI (build and `swift test`) must pass and one approval is required.** The first incident can't happen again.
  2. **One purpose per pull request; refactors separate from behavior changes.** Reviews stay small enough to actually read.
  3. **If a pull request is large, the author explains why in the description and offers a walkthrough.** Sometimes it can't be split; then the reviewer needs help.
  4. **Every description says why, how it was tested, and includes screenshots for UI changes.** The reviewer starts with context, not guesses.
  5. **Reviewers respond within one working day, check correctness, clarity and tests, and mark comments as blocking or optional.** Fast, focused reviews mean authors don't batch work into giant pull requests.
  6. **New behavior comes with a test that would fail without it.** CI can only defend what's tested.
  7. **The author merges after approval and deletes the branch.** Clear ownership; no stale branches.
````

## Summary

- `git push -u origin <branch>` publishes a branch and sets its upstream; `git pull` brings in what others merged.
- A pull request asks to merge a branch into `main`. It shows the diff, collects review comments and shows CI results. Follow-up commits go on the same branch.
- Keep pull requests small and single-purpose; separate refactors from behavior changes.
- A good description gives the why, the behavior decisions, how it was tested and where to look closely.
- Review for correctness (run the edge cases), clarity and tests. Comment on the code, be specific, mark what's blocking.
- CI builds and tests every push. With branch protection requiring it, a red check blocks the merge.
