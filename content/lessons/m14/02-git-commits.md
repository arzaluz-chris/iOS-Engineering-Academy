---
id: m14-l02
title: "Git: commits and history"
description: You put the Expenses package under version control, learn the three places a change passes through (working tree, staging area, repository), make commits with init, status, add and commit, read history with log, diff and show, write commit messages that explain why, and keep build products and personal files out with a .gitignore for SwiftPM and Xcode.
module: m14
order: 2
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m14-l01]
objectives:
  - Explain what version control gives you that a folder of backups doesn't.
  - Describe the working tree, the staging area and the repository, and move a change through them.
  - Create a repository and make commits with git init, status, add and commit.
  - Read history and changes with git log, git diff, git diff --staged and git show.
  - Write a commit message with a short imperative subject and a body that explains why.
  - Write a .gitignore for a SwiftPM or Xcode project and stop tracking a file that was committed by mistake.
terms:
  - term: Version control
    definition: "A system that records snapshots of a project over time, with who made each one and why, so you can compare, undo and combine changes."
  - term: Repository
    definition: "The project folder plus its full history, stored by Git in a hidden .git folder."
  - term: Commit
    definition: "A saved snapshot of every tracked file, with an author, a date, a message and a link to the commit before it (its parent). It's identified by a hash."
  - term: Working tree
    definition: "The files as they are on disk right now, which you edit."
  - term: Staging area
    definition: "Also called the index: the set of changes that will go into the next commit. git add puts changes there."
  - term: Hash
    definition: "The long hexadecimal ID of a commit, computed from its content, author, date and parent. git log --oneline shows the first seven characters."
  - term: .gitignore
    definition: "A file listing patterns of paths Git should not offer to track, such as build output and personal editor settings."
mastery:
  - Read the output of git status and say which changes are staged, which aren't, and which files are untracked.
  - Stage only some of your changes and commit them with a message that has a subject line and a body.
  - Use git diff and git diff --staged to check what you're about to commit.
  - Find a commit in git log and show what it changed with git show.
  - Write a .gitignore that keeps .build/, DerivedData/, xcuserdata/ and .DS_Store out of the repository.
  - Stop tracking an already committed file with git rm --cached without deleting it from disk.
resources: [swift-cli-getting-started, swiftpm-docs]
cards:
  - id: m14-l02-c1
    front: What are the three places a change passes through in Git?
    back: "The working tree (files on disk), the staging area (what the next commit will contain, filled with git add) and the repository (the commits, created with git commit)."
  - id: m14-l02-c2
    front: "git diff vs git diff --staged?"
    back: "git diff shows changes you haven't staged yet. git diff --staged shows what's staged, which is exactly what git commit will record."
  - id: m14-l02-c3
    front: What makes a good commit message?
    back: "A short subject (50 characters or fewer) in the imperative, like \"Format negative amounts with a leading minus\", a blank line, and a body that explains why the change was needed."
  - id: m14-l02-c4
    front: Which paths does a Swift/Xcode .gitignore usually contain?
    back: ".build/ (SwiftPM output), DerivedData/ (Xcode build output, when it's inside the project), xcuserdata/ (per-user Xcode state) and .DS_Store (Finder metadata)."
  - id: m14-l02-c5
    front: "You added a file to .gitignore but Git still shows it as modified. Why, and what's the fix?"
    back: ".gitignore only affects untracked files. The file is already tracked. Run git rm --cached <file> and commit; the file stays on disk and is ignored from then on."
---

## The idea in one sentence

Git records snapshots of your project, each with a message saying why it changed, so you can see how the code got here, compare any two points and undo safely.

> [!note]
> Every command in this lesson was run with Git 2.43.0 against a throwaway copy of the `Expenses` package from the previous lesson, and the output is pasted as Git printed it. The commit dates were fixed so the run is repeatable; your hashes and dates will be different, because a hash is computed from the content, the author and the time.

## Why version control

Without it, you end up with `Expenses-final`, `Expenses-final-2` and `Expenses-really-final.zip`. That has three problems: you can't see **what** changed between two copies without comparing every file by hand, you don't know **why** it changed, and two people can't work on the same code without overwriting each other.

Git fixes all three. Every **commit** is a snapshot of all tracked files plus who made it, when, a message, and a pointer to the previous commit. The chain of commits is the project's history. You'll use it daily to:

- see exactly what you changed before you commit it,
- find when and why a line changed, months later,
- go back to a version that worked,
- work on several things at once on branches (next lesson),
- share and review code with a team (the lesson after).

## Setting up once

Git puts your name and email in every commit. Set them once per machine:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Without this, the first commit fails:

```output
Author identity unknown

*** Please tell me who you are.

Run

  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"

to set your account's default identity.
Omit --global to set the identity only in this repository.
```

That message came from the test container, which has no identity configured. Set it before your first commit rather than finding out from an error.

## The three places a change lives

```plaintext
 working tree          staging area             repository
 (files on disk)       (next commit)            (history)
      │   git add ──────►   │   git commit ──────►   │
      │                     │                        │
      ◄──── git restore ────┤                        │
```

- The **working tree** is your files as they are now.
- The **staging area** (or index) is what the next commit will contain. `git add` copies a change there.
- The **repository** holds the commits. `git commit` turns the staging area into a new commit.

The staging area is what lets you commit **part** of your work: fix a bug and rename a variable, then commit them separately.

## Your first commits

Inside the `Expenses` folder:

```bash
git init -b main
```

```output
Initialized empty Git repository in /p/l02/Expenses/.git/
```

`git init` creates the hidden `.git` folder that holds the history. `-b main` names the first branch `main`, which is the most common name today. Without `-b`, Git 2.43 names it `master` and prints a hint:

```output
hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint: 
hint: 	git config --global init.defaultBranch <name>
hint: 
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint: 
hint: 	git branch -m <name>
```

Git's documentation says the default will change to `main` in Git 3.0. Running `git config --global init.defaultBranch main` once makes every new repository start on `main`.

### status, add, commit

`git status` is the command you'll run most. It tells you where every change is:

```bash
git status
```

```output
On branch main

No commits yet

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.gitignore
	Package.swift
	Sources/
	Tests/

nothing added to commit but untracked files present (use "git add" to track)
```

**Untracked** means Git sees the files but isn't recording them. Notice that `.build/` isn't listed even though it exists: the `.gitignore` that `swift package init` created keeps it out. More on that below.

```bash
git add .
git status
```

```output
On branch main

No commits yet

Changes to be committed:
  (use "git rm --cached <file>..." to unstage)
	new file:   .gitignore
	new file:   Package.swift
	new file:   Sources/ExpenseCore/Expense.swift
	new file:   Sources/ExpenseCore/ExpenseReport.swift
	new file:   Sources/ExpenseCore/Formatting.swift
	new file:   Sources/expenses/main.swift
	new file:   Tests/ExpenseCoreTests/ExpenseReportTests.swift
```

`git add .` stages everything in the current folder that isn't ignored. Now commit, with `-m` for a one-line message:

```bash
git commit -m "Create Expenses package with report and CLI"
```

```output
[main (root-commit) b4042fc] Create Expenses package with report and CLI
 7 files changed, 92 insertions(+)
 create mode 100644 .gitignore
 create mode 100644 Package.swift
 create mode 100644 Sources/ExpenseCore/Expense.swift
 create mode 100644 Sources/ExpenseCore/ExpenseReport.swift
 create mode 100644 Sources/ExpenseCore/Formatting.swift
 create mode 100644 Sources/expenses/main.swift
 create mode 100644 Tests/ExpenseCoreTests/ExpenseReportTests.swift
```

`b4042fc` is the start of the new commit's hash. `root-commit` means it's the first one, with no parent.

## A change worth committing: a real bug

`formatCents` from the previous lesson has a bug with negative amounts, which is how a refund would be stored. Here it is next to the fix:

```swift
func formatCentsOld(_ cents: Int) -> String {
    let dollars = cents / 100
    let rest = cents % 100
    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
}

func formatCents(_ cents: Int) -> String {
    let sign = cents < 0 ? "-" : ""
    let absolute = abs(cents)
    let dollars = absolute / 100
    let rest = absolute % 100
    return rest < 10 ? "\(sign)$\(dollars).0\(rest)" : "\(sign)$\(dollars).\(rest)"
}

print(formatCentsOld(-450))
print(formatCents(-450))
print(formatCents(1705))
```

```output
$-4.0-50
-$4.50
$17.05
```

In Swift, `%` keeps the sign of the left operand, so `-450 % 100` is `-50`. That's below 10, so the old code inserted a `0` before it. The fix formats the absolute value and puts the sign in front. After changing `Formatting.swift` and adding a test for `-450`:

```bash
git status --short
```

```output
 M Sources/ExpenseCore/Formatting.swift
 M Tests/ExpenseCoreTests/ExpenseReportTests.swift
```

`--short` gives one line per file. The `M` in the **second** column means modified in the working tree but not staged.

### git diff: what changed?

```bash
git diff
```

```output
diff --git a/Sources/ExpenseCore/Formatting.swift b/Sources/ExpenseCore/Formatting.swift
index 00c7f8a..e71cd39 100644
--- a/Sources/ExpenseCore/Formatting.swift
+++ b/Sources/ExpenseCore/Formatting.swift
@@ -1,5 +1,7 @@
 func formatCents(_ cents: Int) -> String {
-    let dollars = cents / 100
-    let rest = cents % 100
-    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
+    let sign = cents < 0 ? "-" : ""
+    let absolute = abs(cents)
+    let dollars = absolute / 100
+    let rest = absolute % 100
+    return rest < 10 ? "\(sign)$\(dollars).0\(rest)" : "\(sign)$\(dollars).\(rest)"
 }
diff --git a/Tests/ExpenseCoreTests/ExpenseReportTests.swift b/Tests/ExpenseCoreTests/ExpenseReportTests.swift
index b40a2e4..9b5955f 100644
--- a/Tests/ExpenseCoreTests/ExpenseReportTests.swift
+++ b/Tests/ExpenseCoreTests/ExpenseReportTests.swift
@@ -11,3 +11,7 @@ import Testing
 @Test func formatsCentsWithTwoDigits() {
     #expect(formatCents(1705) == "$17.05")
 }
+
+@Test func formatsNegativeCentsWithLeadingMinus() {
+    #expect(formatCents(-450) == "-$4.50")
+}
```

How to read it:

- `--- a/…` is the old version, `+++ b/…` the new one.
- `@@ -1,5 +1,7 @@` is a **hunk** header: the old lines 1–5 became new lines 1–7.
- Lines starting with `-` were removed, `+` were added, a space means unchanged context.

Read your own diff before every commit. It's the cheapest code review you'll ever get: debug `print`s, commented-out code and accidental edits jump out here.

### Staging and checking again

```bash
git add Sources/ExpenseCore/Formatting.swift Tests/ExpenseCoreTests/ExpenseReportTests.swift
git diff
```

`git diff` now prints **nothing**: it compares the working tree with the staging area, and they match. To see what's staged, add `--staged` (`--stat` summarizes per file):

```bash
git diff --staged --stat
```

```output
 Sources/ExpenseCore/Formatting.swift            | 8 +++++---
 Tests/ExpenseCoreTests/ExpenseReportTests.swift | 4 ++++
 2 files changed, 9 insertions(+), 3 deletions(-)
```

## Writing the commit message

Run `git commit` without `-m` and Git opens your editor for the message. (For this run the message was saved in a file and passed with `git commit -F ../message.txt`; the result is the same.)

```plaintext
Format negative amounts with a leading minus

formatCents(-450) returned "$-4.0-50" because both the dollars and
the remainder were negative. Format the absolute value and put the
sign in front, so refunds read "-$4.50".
```

```output
[main bc34de1] Format negative amounts with a leading minus
 2 files changed, 9 insertions(+), 3 deletions(-)
```

The shape is a convention Git's own documentation recommends and most teams follow:

1. **Subject line**: a short summary, 50 characters or fewer. Git uses it as the commit's title everywhere (`git log --oneline`, pull request lists).
2. **Imperative mood**, as if giving an order: "Format negative amounts", not "Formatted" or "Formats". A useful test is whether it completes "If applied, this commit will…".
3. **A blank line**, then a **body** wrapped at about 72 characters that explains **why** and anything surprising. The diff already shows **what**.
4. **One logical change per commit.** The fix and its test belong together. A rename of an unrelated variable gets its own commit.

Compare:

| Weak | Better |
| --- | --- |
| `fix` | `Format negative amounts with a leading minus` |
| `changes` | `Add averageCents to ExpenseReport` |
| `Updated ExpenseReport.swift` | `Show the average in the report summary` |
| `WIP stuff and fixed tests and renamed things` | Three commits, one per change |

The weak ones say nothing a reader couldn't get from the file list. Six months from now, "why is the sign handled here?" is answered by the body of one commit.

## Reading history

```bash
git log
```

```output
commit bc34de1a5c7079218b04bf2085c8a4e4d188041b
Author: Christian Example <christian@example.com>
Date:   Tue Nov 3 10:20:00 2026 -0600

    Format negative amounts with a leading minus
    
    formatCents(-450) returned "$-4.0-50" because both the dollars and
    the remainder were negative. Format the absolute value and put the
    sign in front, so refunds read "-$4.50".

commit b4042fca3f9913e4fab4a497e4023d86183b6948
Author: Christian Example <christian@example.com>
Date:   Tue Nov 3 10:00:00 2026 -0600

    Create Expenses package with report and CLI
```

Newest first. The compact version shows the short hash and subject only, which is why the subject line matters:

```bash
git log --oneline
```

```output
bc34de1 Format negative amounts with a leading minus
b4042fc Create Expenses package with report and CLI
```

`git show` displays one commit: its message and its diff. With `--stat`, just the file summary. `HEAD` means "the commit you're on now"; any hash works too (`git show b4042fc`).

```bash
git show --stat HEAD
```

```output
commit bc34de1a5c7079218b04bf2085c8a4e4d188041b
Author: Christian Example <christian@example.com>
Date:   Tue Nov 3 10:20:00 2026 -0600

    Format negative amounts with a leading minus
    
    formatCents(-450) returned "$-4.0-50" because both the dollars and
    the remainder were negative. Format the absolute value and put the
    sign in front, so refunds read "-$4.50".

 Sources/ExpenseCore/Formatting.swift            | 8 +++++---
 Tests/ExpenseCoreTests/ExpenseReportTests.swift | 4 ++++
 2 files changed, 9 insertions(+), 3 deletions(-)
```

## Undoing before you commit

`git status` itself tells you how to back out. With a change staged:

```output
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   a.txt
```

- `git restore --staged a.txt` unstages it. The edit stays in your file.
- `git restore a.txt` throws the edit away and puts back the last committed version.

> [!warning]
> `git restore <file>` on an unstaged change can't be undone: that edit was never committed, so Git has no copy of it. Run `git diff <file>` first and make sure you mean it.

## .gitignore: what not to commit

Some files in a project folder must never be committed:

- **Build output.** `.build/` from SwiftPM, `DerivedData/` from Xcode. It's huge, regenerated on every build and different on every machine.
- **Personal state.** `xcuserdata/` holds your Xcode window layout, breakpoints and scheme choices. Committing it makes every teammate's `git status` noisy with your settings.
- **OS junk.** `.DS_Store` is the file Finder drops in folders on macOS.
- **Secrets.** API keys and passwords. Once they're in a commit, they're in the history, even if a later commit deletes them.

`swift package init` with Swift 6.3.3 writes this `.gitignore`:

```plaintext
.DS_Store
/.build
/Packages
xcuserdata/
DerivedData/
.swiftpm/configuration/registries.json
.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
.netrc
```

The pattern rules you need:

- `name` matches a file or folder with that name anywhere in the project: `.DS_Store` in every folder.
- A trailing `/` matches folders only: `xcuserdata/`.
- A leading `/` anchors the pattern to the folder holding the `.gitignore`: `/.build` is the package's own build folder, not some other `.build` deeper down.
- `*` is a wildcard: `*.log`.
- Lines starting with `#` are comments.

For an Xcode app project, the same four entries do the job: `.DS_Store`, `xcuserdata/`, `DerivedData/` (Xcode keeps it in `~/Library/Developer/Xcode/DerivedData` by default, so this line only matters if you configured it inside the project), and `.build/` if the project includes local packages.

Ignored files don't show up in `git status`. To see them, or to find which rule ignores something:

```bash
git status --ignored
```

```output
On branch main
Ignored files:
  (use "git add -f <file>..." to include in what will be committed)
	.build/

nothing to commit, working tree clean
```

```bash
git check-ignore -v .build
```

```output
.gitignore:2:/.build	.build
```

Line 2 of `.gitignore`, pattern `/.build`.

### Already committed by mistake

`.gitignore` only affects **untracked** files. Here a `build.log` was committed, then `*.log` was added to `.gitignore`, and the log changed again:

```bash
git status --short
```

```output
 M .gitignore
 M build.log
```

Git still tracks it. Remove it from the repository but **keep it on disk** with `--cached`, then commit:

```bash
git rm --cached build.log
git status --short
```

```output
rm 'build.log'
 M .gitignore
D  build.log
```

`D` in the **first** column: the deletion is staged. `git commit -am "Stop tracking build.log"` records it (`-a` also stages the modified `.gitignore`). From then on `build.log` is ignored. Its old versions are still in the history; for a leaked secret, that means the secret must be revoked and replaced, not just untracked.

## Common mistakes

> [!error] fatal: unable to auto-detect email address
> You haven't set `user.name` and `user.email`. Run the two `git config --global` commands, then commit again.

> [!error] no changes added to commit (use "git add" and/or "git commit -a")
> You edited files but didn't stage anything. `git add` the files you mean to commit, or use `git commit -a` to stage every modified tracked file (it never adds untracked ones).

> [!error] Committing .build or xcuserdata
> Usually from running `git add .` before the `.gitignore` existed. Add the patterns, `git rm -r --cached .build`, and commit.

> [!error] One giant commit at the end of the day
> "Lots of changes" can't be reviewed, reverted or understood later. Commit each logical change as soon as it works and its tests pass.

> [!error] Running git commands outside the repository
> `fatal: not a git repository (or any of the parent directories): .git` means your terminal isn't inside the project. `cd` into it; `pwd` shows where you are.

## Exercises

````exercise
id: m14-l02-e1
type: comprehension
prompt: "You edit `Formatting.swift` and run `git add Formatting.swift`. Then you edit it again. What will `git commit` (without `-a`) record?"
choices:
  - text: Both edits.
    correct: false
    why: git add copied the file as it was at that moment. The second edit came later.
  - text: Only the first edit, the version that was staged.
    correct: true
    why: The commit records the staging area. The second edit is still only in the working tree.
  - text: Nothing, because the file changed after git add.
    correct: false
    why: The staged version is still there; Git doesn't discard it.
  - text: Only the second edit.
    correct: false
    why: The second edit was never staged.
solution: |
  **Only the first edit.** `git add` takes a snapshot of the file into the staging area at that moment. `git status` would now show the file twice: once under "Changes to be committed" and once under "Changes not staged for commit". Run `git add` again to include the second edit, and use `git diff --staged` to check what the commit will contain.
````

````exercise
id: m14-l02-e2
type: prediction
prompt: "This is the old `formatCents`, before the fix. What does it print for these amounts?"
code: |
  func formatCents(_ cents: Int) -> String {
      let dollars = cents / 100
      let rest = cents % 100
      return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
  }

  print(formatCents(-5))
  print(formatCents(-1299))
  print(formatCents(1299))
output: |
  $0.0-5
  $-12.0-99
  $12.99
hints:
  - "In Swift, -5 / 100 is 0 and -5 % 100 is -5."
  - "Any negative rest is below 10."
solution: |
  ```output
  $0.0-5
  $-12.0-99
  $12.99
  ```

  Integer division rounds toward zero, so `-5 / 100` is `0` and `-1299 / 100` is `-12`. The remainder keeps the sign of the left operand: `-5` and `-99`. Both are less than 10, so the code inserts a `0` before them. Positive amounts were fine, which is why the bug survived until refunds appeared. The fixed version prints `-$0.05`, `-$12.99` and `$12.99`.
````

````exercise
id: m14-l02-e3
type: fill-in
prompt: Complete the commands to start a repository on `main`, check what's there, stage everything and make the first commit.
code: |
  git init [[1]] main
  git [[2]]
  git [[3]] .
  git [[4]] -m "Create Expenses package"
blanks:
  - id: "1"
    answers: ["-b", "--initial-branch"]
  - id: "2"
    answers: ["status"]
  - id: "3"
    answers: ["add"]
  - id: "4"
    answers: ["commit"]
solution: |
  ```bash
  git init -b main
  git status
  git add .
  git commit -m "Create Expenses package"
  ```

  `-b main` (or `--initial-branch=main`) names the first branch. `git status` shows untracked files; check that nothing like `.build/` is listed before `git add .`. `git commit -m` records the staged snapshot with a one-line message.
````

````exercise
id: m14-l02-e4
type: find-errors
prompt: "A teammate's `git log --oneline` and `.gitignore` for an iOS app. Mark every real problem."
code: |
  $ git log --oneline
  9f1c2ab stuff
  41d0e7e Fixed bug
  c3a9b10 Add login screen, rename models, update all dependencies, fix crash on iPad

  $ cat .gitignore
  .DS_Store
  DerivedData/
choices:
  - text: "\"stuff\" says nothing about what changed or why."
    correct: true
  - text: "\"Fixed bug\" doesn't say which bug; a reader has to open the diff to find out."
    correct: true
  - text: "c3a9b10 mixes four unrelated changes in one commit, so none of them can be reviewed or reverted on its own."
    correct: true
  - text: "The .gitignore is missing xcuserdata/, so per-user Xcode state will show up in git status."
    correct: true
  - text: "Commit subjects must end with a period."
    correct: false
    why: The usual convention is the opposite; no period at the end of a subject line.
  - text: ".gitignore can't ignore folders, only files."
    correct: false
    why: "A trailing / matches folders, like DerivedData/."
rubric:
  - I found the two vague messages.
  - I found the commit that mixes unrelated changes.
  - I found the missing xcuserdata/ entry.
solution: |
  Four real problems:

  - `stuff` and `Fixed bug` don't say what changed. Better: `Fix crash when the expense list is empty`.
  - `c3a9b10` should be four commits. If the dependency update breaks something, you want to revert only that, and a reviewer wants to read the login screen without a rename mixed in.
  - The `.gitignore` lacks `xcuserdata/`. Add it, and if those files were already committed, `git rm -r --cached` them.

  Subjects conventionally have **no** period, and `.gitignore` handles folders fine with a trailing `/`.
````

````exercise
id: m14-l02-e5
type: solve
prompt: |
  Put a Swift package of your own under version control:

  1. Create an executable package (or use `Expenses`) and run `swift build` once so `.build/` exists.
  2. `git init -b main`, set your name and email if you haven't, and check with `git status` that `.build/` is **not** listed.
  3. Make the first commit.
  4. Change the program's output, check the change with `git diff`, stage it, check again with `git diff --staged`, and commit it with a subject and a body that says why.
  5. Show both commits with `git log --oneline`.
starter: |
  mkdir Practice
  cd Practice
  swift package init --type executable
  swift build
hints:
  - "If .build/ shows up as untracked, check that .gitignore exists and contains /.build."
  - "To write a body, run git commit without -m and Git opens an editor; or pass -m twice, once for the subject and once for the body."
rubric:
  - git status before the first commit listed the sources and .gitignore but not .build/.
  - I read git diff before staging and git diff --staged after.
  - The second commit has an imperative subject of 50 characters or fewer and a body explaining why.
  - git log --oneline shows exactly two commits.
solution: |
  ```bash
  mkdir Practice
  cd Practice
  swift package init --type executable
  swift build
  git init -b main
  git status
  git add .
  git commit -m "Create Practice package"
  # edit Sources/Practice/Practice.swift
  git diff
  git add Sources/Practice/Practice.swift
  git diff --staged
  git commit -m "Greet the user by name" -m "The generic greeting confused testers who ran several tools at once."
  git log --oneline
  ```

  The first `git status` should list `.gitignore`, `Package.swift`, `Sources/` and `Tests/`, and not `.build/`. That's the template's `.gitignore` at work. Passing `-m` twice makes the second one a separate paragraph, which is the body. `git log --oneline` then shows two lines, newest first.
````

````exercise
id: m14-l02-e6
type: explain
prompt: Explain every part of this output. Which changes will the next `git commit` record, and what would you run to include the rest?
code: |
  $ git status
  On branch main
  Changes to be committed:
    (use "git restore --staged <file>..." to unstage)
  	modified:   Sources/ExpenseCore/Formatting.swift

  Changes not staged for commit:
    (use "git add <file>..." to update what will be committed)
    (use "git restore <file>..." to discard changes in working directory)
  	modified:   Sources/ExpenseCore/ExpenseReport.swift

  Untracked files:
    (use "git add <file>..." to include in what will be committed)
  	Sources/ExpenseCore/Budget.swift
rubric:
  - I said only the staged change to Formatting.swift will be committed.
  - I explained that ExpenseReport.swift is tracked and modified but not staged.
  - I explained that Budget.swift is new and Git isn't tracking it yet, so git commit -a wouldn't include it either.
  - I gave the commands to include the rest (git add for both files) and said to check with git diff --staged.
solution: |
  - **Changes to be committed**: the edit to `Formatting.swift` is in the staging area. `git commit` records this and only this.
  - **Changes not staged**: `ExpenseReport.swift` is tracked and has edits on disk that haven't been staged. They stay in the working tree after the commit.
  - **Untracked**: `Budget.swift` is a new file Git has never recorded. `git commit -a` stages modified **tracked** files, so it would pick up `ExpenseReport.swift` but still skip `Budget.swift`.

  If all three belong to one logical change: `git add Sources/ExpenseCore/ExpenseReport.swift Sources/ExpenseCore/Budget.swift`, then `git diff --staged` to read everything, then commit. If they're separate changes, commit the staged one now and the others after.
````

````exercise
id: m14-l02-e7
type: refactor
prompt: "Rewrite these commit messages so a reader of `git log --oneline` understands each change. Invent plausible details where needed and say what you'd put in a body."
code: |
  update
  fixed it
  more changes to report
  asdf
rubric:
  - Every subject is imperative and describes a specific change.
  - Every subject is 50 characters or fewer.
  - At least one message has a body that explains why, not what.
  - I noted when a vague commit probably should have been split.
solution: |
  Possible rewrites (the details are invented; the shape is the point):

  ```plaintext
  Update swift-argument-parser to 1.8.2

  Fix crash when the report has no expenses

  averageCents divided by expenses.count, which is 0 for a new
  report. Return 0 in that case and add a test.

  Show the average in the report summary

  Remove leftover debug prints
  ```

  "more changes to report" might hide several changes; if so, split them into separate commits. "asdf" usually means a work-in-progress commit that should have been combined with the next one before sharing. The body of the crash fix explains the cause and the decision, which the diff alone doesn't.
````

## Summary

- A commit is a snapshot of all tracked files with an author, date, message and parent. The chain of commits is the history.
- Changes go working tree → `git add` → staging area → `git commit` → repository. `git status` tells you where everything is.
- `git diff` shows unstaged changes, `git diff --staged` what you're about to commit. `git log`, `git log --oneline` and `git show` read history.
- Commit messages: short imperative subject, blank line, a body that explains why. One logical change per commit.
- `git init -b main` starts on `main`; Git 2.43 still defaults to `master` and prints a hint.
- `.gitignore` keeps `.build/`, `DerivedData/`, `xcuserdata/` and `.DS_Store` out. It only affects untracked files; use `git rm --cached` for files already committed.
