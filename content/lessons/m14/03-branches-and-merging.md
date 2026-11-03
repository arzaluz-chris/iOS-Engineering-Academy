---
id: m14-l03
title: Branches, merging and conflicts
description: You create branches with git switch -c, see when a merge is a fast-forward and when it needs a merge commit, cause a real conflict by changing the same line on two branches and resolve it step by step, and learn what rebase does and the rule that keeps it safe.
module: m14
order: 3
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l02]
objectives:
  - Explain what a branch is in Git (a movable name for a commit) and what HEAD is.
  - Create, list, switch and delete branches.
  - Tell a fast-forward merge from a merge that creates a merge commit, and predict which one you'll get.
  - Resolve a merge conflict by reading the markers, editing the file, building, testing, staging and committing.
  - Explain what git rebase does and why you don't rebase commits other people already have.
terms:
  - term: Branch
    definition: "A name that points to a commit and moves forward as you commit on it. Creating one is instant; it doesn't copy files."
  - term: HEAD
    definition: "Git's name for where you are now: usually the current branch, and through it the commit it points to."
  - term: Fast-forward merge
    definition: "A merge where the current branch has no commits of its own since the other branch started, so Git just moves the branch name forward. No new commit is created."
  - term: Merge commit
    definition: "A commit with two parents that joins two lines of history that both have new commits."
  - term: Merge conflict
    definition: "What happens when both branches changed the same lines (or one changed a file the other deleted). Git stops and asks you to choose the result."
  - term: Conflict markers
    definition: "The <<<<<<<, ======= and >>>>>>> lines Git writes into a conflicted file around the two competing versions."
  - term: Rebase
    definition: "Replaying your branch's commits on top of another commit, creating new commits with new hashes, so the history looks as if you started from there."
mastery:
  - Create a branch for a change, commit on it, switch back to main and merge it.
  - Look at a git log --graph and say whether merging will fast-forward.
  - Resolve a conflict in a Swift file, prove the result builds and passes its tests, and conclude the merge.
  - Abort a merge you don't want to finish with git merge --abort.
  - Say when rebasing your own branch is fine and when it would hurt your team.
resources: [git-merge-reference, pro-git-rebasing, swift-cli-getting-started]
cards:
  - id: m14-l03-c1
    front: What is a Git branch, physically?
    back: "A small file holding a commit hash. Committing on the branch moves it to the new commit. Creating one copies nothing."
  - id: m14-l03-c2
    front: When does git merge fast-forward?
    back: "When the branch you're on has no commits the other branch lacks. Git just moves your branch name forward to the other branch's commit; no merge commit is made."
  - id: m14-l03-c3
    front: "What do <<<<<<< HEAD, ======= and >>>>>>> branch mean?"
    back: "Between <<<<<<< HEAD and ======= is your current branch's version; between ======= and >>>>>>> is the incoming branch's version. You replace the whole block with the code you want."
  - id: m14-l03-c4
    front: What are the steps after editing a conflicted file?
    back: "Build and run the tests, then git add the file to mark it resolved, then git commit to conclude the merge. git merge --abort backs out instead."
  - id: m14-l03-c5
    front: What's the golden rule of rebase?
    back: "Don't rebase commits you've already pushed and others may have based work on. Rebase creates new commits with new hashes, and rewriting shared history leaves teammates with duplicates and conflicts."
---

## The idea in one sentence

A branch lets you work on one change without disturbing `main`, and merging brings it back; when two branches changed the same lines, Git stops and you decide the result.

> [!note]
> The commands here continue the repository from the previous lesson. They were run with Git 2.43.0 and the output pasted as printed, with fixed commit dates so the run repeats exactly. Your hashes will differ.

## What a branch is

A branch is a **name that points to a commit**. That's all. When you commit, the current branch moves forward to the new commit. **HEAD** is Git's word for "where you are", which is normally the current branch.

```plaintext
          main
           │
b4042fc ◄─ bc34de1 ◄─ 192dc71 ◄─ 836d2f6
                                    ▲
                                  HEAD → main
```

Creating a branch makes a second name pointing at the same commit. No files are copied, so it's instant, and you should do it for every change, however small.

## Branch, commit, switch, merge

```bash
git branch
```

```output
* main
```

The `*` marks the current branch. `git switch -c` creates a branch and switches to it:

```bash
git switch -c add-average
```

```output
Switched to a new branch 'add-average'
```

Now add an `averageCents` property to `ExpenseReport` with a test, and commit:

```bash
git commit -am "Add averageCents to ExpenseReport"
```

```output
[add-average b2c33b8] Add averageCents to ExpenseReport
 2 files changed, 8 insertions(+)
```

```bash
git branch
```

```output
* add-average
  main
```

`add-average` moved forward; `main` stayed where it was. Go back to `main` and merge:

```bash
git switch main
git merge add-average
```

```output
Switched to branch 'main'
Updating 836d2f6..b2c33b8
Fast-forward
 Sources/ExpenseCore/ExpenseReport.swift         | 4 ++++
 Tests/ExpenseCoreTests/ExpenseReportTests.swift | 4 ++++
 2 files changed, 8 insertions(+)
```

### Fast-forward

`main` had no new commits since `add-average` started, so the branch's history already contains all of `main`. Git doesn't need to combine anything: it just moves the `main` label forward to `b2c33b8`. That's a **fast-forward**. No new commit appears.

```plaintext
before:   836d2f6 (main) ◄─ b2c33b8 (add-average)
after:    836d2f6 ◄─ b2c33b8 (main, add-average)
```

The branch is merged, so delete the name (the commits stay):

```bash
git branch -d add-average
```

```output
Deleted branch add-average (was b2c33b8).
```

`-d` refuses if the branch has commits that aren't merged anywhere:

```output
error: the branch 'other' is not fully merged.
If you are sure you want to delete it, run 'git branch -D other'
```

`-D` deletes anyway. Use it only when you really mean to throw that work away.

### A merge commit

Now both sides move. On a new branch `refunds`, add an `isRefund` property to `Expense` and commit. Meanwhile, back on `main`, someone adds a third expense to the sample in `main.swift` and commits. Then merge:

```bash
git merge --no-edit refunds
```

```output
Merge made by the 'ort' strategy.
 Sources/ExpenseCore/Expense.swift | 4 ++++
 1 file changed, 4 insertions(+)
```

Both branches had commits the other lacked, so moving a label can't produce a history containing both. Git creates a **merge commit** with two parents. (`ort` is the name of Git's default merge strategy; you don't need to choose it. `--no-edit` accepts the default message, "Merge branch 'refunds'"; without it, Git opens your editor with that message.) The graph shows the shape:

```bash
git log --oneline --graph
```

```output
*   95ba036 Merge branch 'refunds'
|\  
| * 98941e9 Add isRefund to Expense
* | debfef6 Add a bus ticket to the sample report
|/  
* b2c33b8 Add averageCents to ExpenseReport
* 836d2f6 Stop tracking build.log
* 192dc71 Add build log
* bc34de1 Format negative amounts with a leading minus
* b4042fc Create Expenses package with report and CLI
```

The two branches touched different files, so Git combined them on its own. Even when both branches edit the same file, Git usually merges on its own, as long as the edits are in separate parts of it.

## A real conflict, step by step

Conflicts happen when both branches change **the same lines**. Here is the `summary()` method both branches start from:

```swift
struct ExpenseReport {
    var expenses: [Int] = []

    var totalCents: Int {
        var total = 0
        for cents in expenses {
            total += cents
        }
        return total
    }

    func summary() -> String {
        "\(expenses.count) expenses, total \(formatCents(totalCents))"
    }
}

func formatCents(_ cents: Int) -> String {
    let dollars = cents / 100
    let rest = cents % 100
    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
}

print(ExpenseReport(expenses: [450, 1299, 275]).summary())
```

```output
3 expenses, total $20.24
```

(The examples in this section store amounts as plain `Int` cents so each block runs on its own; the package uses `Expense` values.)

On branch `summary-wording`, a teammate leads with the total:

```swift illustrative
"Total \(formatCents(totalCents)) for \(expenses.count) expenses"
```

On `main`, you add the average:

```swift illustrative
"\(expenses.count) expenses, total \(formatCents(totalCents)), average \(formatCents(averageCents))"
```

Both commits exist. Merge:

```bash
git merge summary-wording
```

```output
Auto-merging Sources/ExpenseCore/ExpenseReport.swift
CONFLICT (content): Merge conflict in Sources/ExpenseCore/ExpenseReport.swift
Automatic merge failed; fix conflicts and then commit the result.
```

**Step 1: see what's conflicted.**

```bash
git status
```

```output
On branch main
You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
	both modified:   Sources/ExpenseCore/ExpenseReport.swift

no changes added to commit (use "git add" and/or "git commit -a")
```

You're in the middle of a merge. Git merged everything it could and left one file for you. If you want out, `git merge --abort` puts everything back as it was before `git merge`.

**Step 2: read the markers.** Open the file. Git wrote both versions into it:

```plaintext
    public func summary() -> String {
<<<<<<< HEAD
        "\(expenses.count) expenses, total \(formatCents(totalCents)), average \(formatCents(averageCents))"
=======
        "Total \(formatCents(totalCents)) for \(expenses.count) expenses"
>>>>>>> summary-wording
    }
```

- From `<<<<<<< HEAD` to `=======`: **your** side, the branch you're on (`main`).
- From `=======` to `>>>>>>> summary-wording`: the **incoming** side.

**Step 3: decide what the code should be.** This is the real work, and Git can't do it for you. Neither side is "right": your teammate wanted the total first, you wanted the average. The result that respects both:

```plaintext
    public func summary() -> String {
        "Total \(formatCents(totalCents)) for \(expenses.count) expenses, average \(formatCents(averageCents))"
    }
```

Delete all three marker lines. Picking one side wholesale is sometimes correct, but only after you understand what the other side was for.

Here's the resolved method on its own, so you can see it run:

```swift
struct ExpenseReport {
    var expenses: [Int] = []

    var totalCents: Int {
        var total = 0
        for cents in expenses {
            total += cents
        }
        return total
    }

    var averageCents: Int {
        expenses.isEmpty ? 0 : totalCents / expenses.count
    }

    func summary() -> String {
        "Total \(formatCents(totalCents)) for \(expenses.count) expenses, average \(formatCents(averageCents))"
    }
}

func formatCents(_ cents: Int) -> String {
    let dollars = cents / 100
    let rest = cents % 100
    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
}

print(ExpenseReport(expenses: [450, 1299, 275]).summary())
```

```output
Total $20.24 for 3 expenses, average $6.74
```

**Step 4: check the result.** `git diff` during a merge shows a combined diff: the first column is your side, the second the incoming side, and `++` marks a line that's in neither, which is your resolution:

```output
diff --cc Sources/ExpenseCore/ExpenseReport.swift
index 2861046,b8b841e..0000000
--- a/Sources/ExpenseCore/ExpenseReport.swift
+++ b/Sources/ExpenseCore/ExpenseReport.swift
@@@ -20,7 -20,7 +20,7 @@@ public struct ExpenseReport 
      }
  
      public func summary() -> String {
-         "\(expenses.count) expenses, total \(formatCents(totalCents)), average \(formatCents(averageCents))"
 -        "Total \(formatCents(totalCents)) for \(expenses.count) expenses"
++        "Total \(formatCents(totalCents)) for \(expenses.count) expenses, average \(formatCents(averageCents))"
      }
  
      package func lines() -> [String] {
```

Then build and test. A resolution that doesn't compile, or that breaks a test, isn't a resolution:

```bash
swift run expenses
swift test
```

```output
Total $20.24 for 3 expenses, average $6.74
✔ Test run with 4 tests in 0 suites passed after 0.001 seconds.
```

(Only the last line of each command is shown.)

**Step 5: mark it resolved and conclude.**

```bash
git add Sources/ExpenseCore/ExpenseReport.swift
git status
```

```output
On branch main
All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)

Changes to be committed:
	modified:   Sources/ExpenseCore/ExpenseReport.swift
```

```bash
git commit --no-edit
```

```output
[main ebe83a3] Merge branch 'summary-wording'
```

```bash
git log --oneline --graph
```

```output
*   ebe83a3 Merge branch 'summary-wording'
|\  
| * 8905067 Lead the summary with the total
* | 9645e9d Show the average in the summary
|/  
*   95ba036 Merge branch 'refunds'
|\  
| * 98941e9 Add isRefund to Expense
* | debfef6 Add a bus ticket to the sample report
|/  
* b2c33b8 Add averageCents to ExpenseReport
* 836d2f6 Stop tracking build.log
* 192dc71 Add build log
* bc34de1 Format negative amounts with a leading minus
* b4042fc Create Expenses package with report and CLI
```

### Leftover markers don't compile

If you `git add` a file with markers still in it, Git accepts it: to Git it's just text. In a Swift file, the compiler catches it:

```swift no-compile source control conflict marker in source file
func summary(count: Int, total: String) -> String {
<<<<<<< HEAD
    "\(count) expenses, total \(total)"
=======
    "Total \(total) for \(count) expenses"
>>>>>>> summary-wording
}

print(summary(count: 2, total: "$17.49"))
```

Swift 6.3 says `error: source control conflict marker in source file`. In a JSON file, a Markdown file or a project file, nothing would warn you, so search for `<<<<<<<` before committing.

## Switching with uncommitted changes

`git switch` refuses when your uncommitted edits would be overwritten by the other branch's version of the same file:

```output
error: Your local changes to the following files would be overwritten by checkout:
	a.txt
Please commit your changes or stash them before you switch branches.
Aborting
```

Commit the work (on its own branch, if it isn't ready for `main`), or set it aside with `git stash` and bring it back later with `git stash pop`.

## Rebase, carefully

There's a second way to bring a branch up to date. Here a branch `csv-line` has one commit, and `main` has moved on since it started:

```output
* f9f1fdf Use a train ticket in the sample report
| * 532629d Add csvLine to Expense
|/  
*   ebe83a3 Merge branch 'summary-wording'
```

On `csv-line`, `git rebase main` takes the branch's commits and replays them, one by one, on top of the current `main`:

```bash
git switch csv-line
git rebase main
```

```output
Successfully rebased and updated refs/heads/csv-line.
```

```output
* 803e8e6 Add csvLine to Expense
* f9f1fdf Use a train ticket in the sample report
*   ebe83a3 Merge branch 'summary-wording'
```

The history is now a straight line, and merging `csv-line` into `main` fast-forwards. But look at the hash: the commit was `532629d` and is now `803e8e6`. **Rebase doesn't move commits; it creates new ones** with the same changes and a different parent, and the old ones are abandoned. That's harmless while the commits exist only on your machine. It's harmful once you've pushed them and someone else has pulled them or built on them: their copy still has the old commits, yours has new ones that look the same, and the next merge between you produces duplicates and conflicts. So the rule is: **rebase only commits that nobody else has**, typically your own local branch before you share it, and never rewrite `main` or any branch other people use. If a rebase hits a conflict, you resolve it the same way as above, then `git add` the file and run `git rebase --continue` (or `git rebase --abort` to go back); a merge is always the safe choice when in doubt.

## Common mistakes

> [!error] error: Your local changes to the following files would be overwritten by checkout
> Commit or stash your edits before switching. Don't reach for `--force`, which throws them away.

> [!error] error: source control conflict marker in source file
> You staged a file without removing `<<<<<<<`, `=======` and `>>>>>>>`. Fix the file, rebuild, `git add` it again.

> [!error] Resolving by always taking "mine"
> Picking your side without reading the other one silently deletes a teammate's work. Understand both changes, then write the code that serves both.

> [!error] Committing a resolution without building
> Two changes can each be correct and still break when combined (a renamed function on one side, a new call to the old name on the other). Run `swift build` and `swift test` before `git commit`.

> [!error] Working directly on main
> Then every experiment is mixed into the line everyone depends on. Create a branch for each change, even a small one.

## Exercises

````exercise
id: m14-l03-e1
type: comprehension
prompt: "You're on `main`. Since you created `feature`, you made no commits on `main`, and `feature` has three new commits. What does `git merge feature` do?"
choices:
  - text: It creates a merge commit with two parents.
    correct: false
    why: A merge commit is only needed when both sides have new commits.
  - text: It fast-forwards main to feature's last commit, without creating a commit.
    correct: true
    why: main's history is already contained in feature's, so Git just moves the main label forward.
  - text: It copies the three commits onto main with new hashes.
    correct: false
    why: That describes rebase or cherry-pick, not a fast-forward merge.
  - text: It reports a conflict, because feature changed files main also has.
    correct: false
    why: Conflicts need changes to the same lines on both sides. main has no new changes at all.
solution: |
  **It fast-forwards.** `main` points at an ancestor of `feature`, so Git moves `main` to `feature`'s last commit and prints `Fast-forward`. The three commits keep their hashes. If you want a merge commit anyway, for example to record that a feature landed as a group, `git merge --no-ff feature` forces one.
````

````exercise
id: m14-l03-e2
type: prediction
prompt: "After the conflict in this lesson was resolved, `summary()` looks like this. What does the program print?"
code: |
  struct ExpenseReport {
      var expenses: [Int] = []

      var totalCents: Int {
          var total = 0
          for cents in expenses {
              total += cents
          }
          return total
      }

      var averageCents: Int {
          expenses.isEmpty ? 0 : totalCents / expenses.count
      }

      func summary() -> String {
          "Total \(formatCents(totalCents)) for \(expenses.count) expenses, average \(formatCents(averageCents))"
      }
  }

  func formatCents(_ cents: Int) -> String {
      let dollars = cents / 100
      let rest = cents % 100
      return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
  }

  print(ExpenseReport().summary())
  print(ExpenseReport(expenses: [999, 1]).summary())
output: |
  Total $0.00 for 0 expenses, average $0.00
  Total $10.00 for 2 expenses, average $5.00
hints:
  - An empty report has total 0 and, by the isEmpty check, average 0.
  - "999 + 1 is 1000 cents."
solution: |
  ```output
  Total $0.00 for 0 expenses, average $0.00
  Total $10.00 for 2 expenses, average $5.00
  ```

  The empty report never divides, thanks to `expenses.isEmpty ? 0 : …`; without that check, `totalCents / 0` would crash. The second report totals 1000 cents, and 1000 / 2 is 500. Both `formatCents` results have a remainder of 0, which is below 10, so a `0` is added: `$10.00`, `$5.00`. Resolving a conflict is a good moment to run edge cases like these, because the combined line is code nobody wrote before.
````

````exercise
id: m14-l03-e3
type: fill-in
prompt: You're in the middle of a merge with one conflicted file, which you've just fixed and tested. Complete the commands to finish, then clean up the merged branch.
code: |
  git [[1]] Sources/ExpenseCore/ExpenseReport.swift
  git [[2]]
  git branch [[3]] summary-wording
blanks:
  - id: "1"
    answers: ["add"]
  - id: "2"
    answers: ["commit", "commit --no-edit", "merge --continue"]
  - id: "3"
    answers: ["-d"]
solution: |
  ```bash
  git add Sources/ExpenseCore/ExpenseReport.swift
  git commit
  git branch -d summary-wording
  ```

  `git add` marks the file resolved. `git commit` concludes the merge (it opens the editor with "Merge branch 'summary-wording'"; `--no-edit` accepts that message; `git merge --continue` does the same thing). `git branch -d` deletes the name now that its commits are part of `main`.
````

````exercise
id: m14-l03-e4
type: find-errors
prompt: "A teammate describes how they handled a conflict. Mark every real problem."
code: |
  1. git merge feature  -> CONFLICT in Cart.swift
  2. Opened Cart.swift, deleted everything between ======= and >>>>>>> feature
  3. Left the <<<<<<< HEAD line because "it's just a comment"
  4. git add Cart.swift
  5. git commit
  6. Pushed to main, then noticed the build was red
choices:
  - text: They threw away the incoming side without reading what it did.
    correct: true
  - text: "<<<<<<< HEAD isn't a comment; it's a leftover marker and Swift refuses to compile it."
    correct: true
  - text: They didn't build or run the tests before committing the merge.
    correct: true
  - text: They should have run git merge --abort after git add.
    correct: false
    why: "--abort is for backing out before you finish; after resolving, add and commit is correct."
  - text: Conflicts must be resolved in Xcode, not in a text editor.
    correct: false
    why: Any editor works. The file is plain text with markers.
rubric:
  - I found the discarded incoming change.
  - I found the leftover marker and named the compiler error.
  - I found the missing build and test step.
solution: |
  Three real problems:

  - Deleting the incoming side wholesale may drop a fix or feature a teammate needed. Read both sides first.
  - `<<<<<<< HEAD` is a conflict marker. Swift 6.3 reports `error: source control conflict marker in source file`. Every marker line has to go.
  - The merge was committed and pushed without `swift build` and `swift test`. That's how a red build lands on `main`.

  Any editor can resolve a conflict; Xcode is one option.
````

````exercise
id: m14-l03-e5
type: solve
prompt: |
  Make and resolve a conflict yourself, in a throwaway repository:

  1. `git init -b main`, create `Greeting.swift` containing `print("Hello")`, and commit it.
  2. `git switch -c formal`, change the line to `print("Good morning")`, commit.
  3. `git switch main`, change the same line to `print("Hello, Christian")`, commit.
  4. `git merge formal`. Read the markers, write a line that keeps both ideas, run the file with `swift Greeting.swift`, then `git add` and `git commit`.
  5. Show the result with `git log --oneline --graph`.
starter: |
  mkdir conflict-practice
  cd conflict-practice
  git init -b main
hints:
  - "The line between <<<<<<< HEAD and ======= is main's version."
  - "A line that keeps both ideas: print(\"Good morning, Christian\")."
rubric:
  - git merge reported CONFLICT (content) for Greeting.swift.
  - I removed all three marker lines and wrote a combined line.
  - swift Greeting.swift ran and printed the combined greeting before I committed.
  - git log --graph shows a merge commit with two parents.
solution: |
  ```bash
  mkdir conflict-practice
  cd conflict-practice
  git init -b main
  echo 'print("Hello")' > Greeting.swift
  git add Greeting.swift
  git commit -m "Add greeting"
  git switch -c formal
  echo 'print("Good morning")' > Greeting.swift
  git commit -am "Use a formal greeting"
  git switch main
  echo 'print("Hello, Christian")' > Greeting.swift
  git commit -am "Greet Christian by name"
  git merge formal
  ```

  `Greeting.swift` now contains:

  ```plaintext
  <<<<<<< HEAD
  print("Hello, Christian")
  =======
  print("Good morning")
  >>>>>>> formal
  ```

  Replace all five lines with the combined version:

  ```swift
  print("Good morning, Christian")
  ```

  ```output
  Good morning, Christian
  ```

  Then `git add Greeting.swift`, `git commit --no-edit`, and `git log --oneline --graph` shows the merge commit on top, with the two branches joining under it.
````

````exercise
id: m14-l03-e6
type: explain
prompt: "Your branch `csv-line` exists only on your machine. A teammate's branch `payments` was pushed yesterday and two people have pulled it. Explain whether it's OK to rebase each one onto the latest `main`, and why."
code: |
  main       moved on since both branches started
  csv-line   1 commit, never pushed, only on your machine
  payments   2 commits, pushed yesterday, pulled by two teammates
rubric:
  - I explained that rebase creates new commits with new hashes.
  - I said rebasing csv-line is fine because nobody else has its commits.
  - I said rebasing payments rewrites history others have, causing duplicate commits and conflicts for them.
  - I gave the safe alternative for payments (merge main into it, or coordinate with the team first).
solution: |
  Rebase replays commits on top of a new base and gives them **new hashes**; the originals are abandoned.

  - `csv-line` is only on your machine. Nobody has the old commits, so replacing them costs nothing. Rebasing it onto `main` before you share it gives a straight history and a fast-forward merge.
  - `payments` has been pulled by two people. If it's rebased and force-pushed, their copies still contain the old commits, and the branch now contains different ones with the same changes. Their next pull mixes both, with duplicates and conflicts to untangle. Merge `main` into `payments` instead (a merge commit adds history; it doesn't rewrite it), or agree with everyone on the branch before rewriting it.
````

## Summary

- A branch is a movable name for a commit; HEAD is where you are. `git switch -c name` creates one and switches to it.
- `git merge` fast-forwards when your branch has nothing new, and creates a merge commit with two parents when both sides moved.
- A conflict means both sides changed the same lines. Read both sides between the markers, write the code that's right, delete the markers, build and test, then `git add` and `git commit`. `git merge --abort` backs out.
- Leftover markers break a Swift build with `source control conflict marker in source file`; in other files nothing warns you.
- `git rebase` replays your commits on a new base with new hashes. Rebase only commits nobody else has; never rewrite shared history.
