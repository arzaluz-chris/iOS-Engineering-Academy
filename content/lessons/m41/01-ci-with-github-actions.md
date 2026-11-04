---
id: m41-l01
title: Continuous integration with GitHub Actions
description: "Set up CI for an iOS project with GitHub Actions: how a workflow file is put together, which macOS runner and Xcode it uses, how to build and test with xcodebuild and swift test, how caching restores files between runs, and how required status checks make a red build block the merge. Xcode Cloud is described from Apple's documentation as the Apple-hosted alternative."
module: m41
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l06]
objectives:
  - Read and write a GitHub Actions workflow with triggers, permissions, concurrency, jobs and steps.
  - Choose a macOS runner label and pin the Xcode version a job uses.
  - Build and test an app with xcodebuild and a package with swift test, and keep the result bundle when tests fail.
  - Cache dependencies with actions/cache and predict which cache a key and its restore keys restore.
  - Make CI a required status check and avoid the path-filter trap that leaves a check pending forever.
  - Compare GitHub Actions with Xcode Cloud for an iOS team.
terms:
  - term: Workflow
    definition: "A YAML file in .github/workflows that GitHub Actions runs when one of its events happens (a push, a pull request, a schedule, a manual dispatch). It contains one or more jobs."
  - term: Job
    definition: "A set of steps that run in order on one runner. Jobs in a workflow run in parallel unless one declares needs: on another."
  - term: Runner
    definition: "The machine that runs a job. GitHub-hosted runners are fresh virtual machines chosen with runs-on labels such as ubuntu-latest or macos-26; they're destroyed when the job ends."
  - term: Status check
    definition: "A pass, fail or pending result that GitHub shows on a commit or pull request. Each workflow job reports one."
  - term: Required status check
    definition: "A check that a branch protection rule or ruleset says must succeed (or be skipped or neutral) before a pull request can merge into the protected branch."
  - term: Cache key
    definition: "The string actions/cache uses to save and find a cache. An exact match is a cache hit; restore-keys are tried as prefixes when there's no exact match."
  - term: Xcode Cloud
    definition: "Apple's CI/CD service built into Xcode and App Store Connect. It builds, tests, archives and distributes to TestFlight in Apple-hosted environments."
mastery:
  - Write a workflow that runs swift test and xcodebuild test on a pinned Xcode for every pull request into main.
  - Explain why an iOS job needs a macOS runner and roughly what that costs compared with Linux in a private repository.
  - Predict which cache actions/cache restores for a given key, restore keys and set of existing caches.
  - Explain why a path-filtered workflow can block a merge when its check is required, and fix it.
  - Keep secrets out of pull request builds from forks and out of caches.
  - Say what Xcode Cloud gives you that GitHub Actions doesn't, and what it costs in flexibility.
resources: [swiftpm-docs]
cards:
  - id: m41-l01-c1
    front: Why does an iOS CI job need a macOS runner?
    back: "xcodebuild, the iOS SDK and the simulators only exist in Xcode, which only runs on macOS. A Linux runner can run swift test for platform-independent packages, but not build or test the app."
  - id: m41-l01-c2
    front: How do you pin the Xcode version on a GitHub-hosted macOS runner?
    back: "Choose a specific image label (macos-26, not macos-latest), then select one of its installed Xcodes with DEVELOPER_DIR=/Applications/Xcode_26.6.app or sudo xcode-select --switch. Print xcodebuild -version in the log."
  - id: m41-l01-c3
    front: "actions/cache: what's the difference between key and restore-keys?"
    back: "key must match exactly for a cache hit (cache-hit is true). If it doesn't, the action tries the key and then each restore key as prefixes and restores the newest partial match, with cache-hit false. After a successful job on a miss, it saves a new cache under key."
  - id: m41-l01-c4
    front: A required check from a workflow with paths filtering never reports on some pull requests. Why does the PR stay blocked?
    back: "GitHub's docs: if a workflow is skipped by path or branch filtering, its checks stay Pending, and a pull request that requires them can't merge. Don't make path-filtered checks required, or run the workflow always and skip work inside it."
  - id: m41-l01-c5
    front: Are repository secrets available to a pull request from a fork?
    back: "No. With the exception of GITHUB_TOKEN (read-only in that case), secrets aren't passed to the runner when a workflow is triggered from a forked repository. Signing and upload jobs must not run on fork PRs."
---

## The idea in one sentence

Continuous integration means a machine, not a person, builds every change and runs the tests before it merges; on GitHub that machine is a GitHub Actions runner following a YAML workflow you keep in the repository, and for an iOS app it has to be a Mac with the right Xcode.

> [!note] Sources and what was checked
> Workflow syntax, runners, caching, secrets, billing and branch protection come from GitHub's documentation (docs.github.com: "Workflow syntax for GitHub Actions", "GitHub-hosted runners", "Dependency caching reference", "Using secrets in GitHub Actions", "About protected branches", "GitHub Actions billing"), read in November 2026. Installed Xcode versions and simulators come from the macOS 26 image README in the `actions/runner-images` repository, dated October 2026. `xcodebuild` and `xcode-select` options come from their man pages. Xcode Cloud comes from Apple's Xcode documentation. Every YAML block in this lesson was parsed with a YAML parser; the workflows themselves weren't run, except this repository's own `swift.yml`, which runs on every push. The Swift blocks are models that were compiled and run with Swift 6.3. No GitHub or App Store Connect settings pages were checked.

Module 14 introduced CI as a gate on pull requests and showed this academy's own workflow. This lesson builds the real thing for an iOS app.

## Anatomy of a workflow

Here's this repository's `.github/workflows/swift.yml` in full. It runs on every push and pull request that touches the Swift code or the lessons, including the one that added this lesson, so it's a working starting point:

```yaml
# Builds and tests the challenge solutions and runs the lesson snippets (Swift Testing) on macOS.
# The repository is public, so standard runners don't use up minutes.
name: Swift · challenge tests

on:
  push:
    branches: [main]
    paths: ['swift/**', 'content/lessons/**', '.github/workflows/swift.yml']
  pull_request:
    paths: ['swift/**', 'content/lessons/**', '.github/workflows/swift.yml']
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: swift-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: macos-latest
    timeout-minutes: 15
    defaults:
      run:
        working-directory: swift
    steps:
      - uses: actions/checkout@v7
      - name: Versions
        run: |
          xcodebuild -version
          swift --version
      - name: swift test
        run: swift test
```

Top to bottom:

- **`name`** is what the Actions tab shows.
- **`on`** lists the events that start it. `push` to `main`, any `pull_request`, and `workflow_dispatch` (a "Run workflow" button). `paths` limits the first two to changes under those globs. That filter has a catch you'll meet below.
- **`permissions`** sets what the automatic `GITHUB_TOKEN` can do. GitHub's docs recommend granting "the minimum required access"; `contents: read` is enough to check out code.
- **`concurrency`** puts runs in a group: "at most one running job or workflow in a concurrency group at any time." With `cancel-in-progress: true`, pushing a new commit to a pull request cancels the run for the previous commit instead of making you wait for it. `github.ref` is the branch (or the pull request's merge ref), so different branches don't cancel each other.
- **`jobs`** holds one job, `test`. **`runs-on`** picks the runner, **`timeout-minutes`** kills a hung job, and **`defaults.run.working-directory`** makes every `run` step start in `swift/`.
- **`steps`** run in order. `uses:` runs an action (here `actions/checkout`, which clones the repository at the commit being tested); `run:` runs shell commands. The `Versions` step prints the toolchain so a failure log tells you exactly which Xcode and Swift ran.

Each job reports a **status check** on the commit and the pull request. That's the "Swift · challenge tests / test" line you see under a pull request.

## macOS runners and the Xcode they use

`xcodebuild`, the iOS SDK and the simulators exist only inside Xcode, and Xcode only runs on macOS. A Linux runner can run `swift test` for a package that doesn't import UIKit or SwiftUI; anything that builds the app needs a Mac.

GitHub's runner reference lists these standard macOS labels (November 2026):

| Label | Machine |
| --- | --- |
| `macos-latest`, `macos-26`, `macos-15` | 3-core M1 (arm64), 7 GB RAM |
| `macos-26-intel`, `macos-15-intel` | 4-core Intel, 14 GB RAM |

The `runner-images` README says `-latest` labels point to "the newest stable OS version available," and that the move to a new OS "happens over 1-2 months," during which a workflow on `macos-latest` "may see changes in the OS version." For a release pipeline that's a surprise you don't want. Use a specific label.

Each image ships several Xcodes. The macOS 26 arm64 image lists Xcode 26.0.1 through 26.6, with **26.6 as the default** (`/Applications/Xcode.app` is a symlink to it), and simulators for iOS 26.2, 26.4 and 26.5. Its policy is "only one major version of Xcode will be supported per macOS version"; Xcode 27 is offered as a separate preview image. That matters for this course: the iOS 27 SDK isn't on `macos-26`.

To pick an Xcode, either switch the system-wide developer directory or set an environment variable. The `xcode-select` man page:

- `xcode-select --switch <path>` "Sets the active developer directory... This command must be run with superuser permissions." GitHub's runners have passwordless `sudo`.
- "To set the path without superuser permissions or only for the current shell session, use the `DEVELOPER_DIR` environment variable instead." Its value can be the Xcode app path.

`DEVELOPER_DIR` set at the job level applies to every step, which is the simplest option:

```yaml
jobs:
  test:
    runs-on: macos-26
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.6.app
    steps:
      - run: xcodebuild -version
```

Pin the Xcode you build releases with. Apple's App Store Connect help says iOS apps uploaded for distribution must be built with Xcode 26 or later (as of November 2026), and the course's research notes record Apple announcing the iOS 27 SDK as the requirement from April 2027. When that date comes, moving CI to an image with Xcode 27 is a deliberate change in one pull request, not something that happens to you.

### What macOS minutes cost

GitHub's billing page: standard GitHub-hosted runners are free in public repositories. In private ones they draw from your plan's included usage, and a macOS 3- or 4-core runner is listed at $0.062 per minute against $0.006 for a standard Linux runner, about ten times as much. Two consequences for how you design CI:

- Run platform-independent package tests (`swift test` on a `Core` package) on Linux when you can, and save the Mac for the app.
- `concurrency` with `cancel-in-progress` and a `timeout-minutes` aren't just tidiness; they stop paying for builds nobody will look at.

## Building and testing with xcodebuild and swift test

A typical iOS repository has an app project and one or more local packages. A complete workflow that tests both:

```yaml
name: iOS · build and test

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ios-${{ github.ref }}
  cancel-in-progress: true

jobs:
  core:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - name: Test the platform-independent package
        working-directory: Packages/WeatherCore
        run: swift test

  app:
    runs-on: macos-26
    timeout-minutes: 30
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.6.app
    steps:
      - uses: actions/checkout@v7
      - name: Versions
        run: |
          xcodebuild -version
          swift --version
      - name: Cache Swift package checkouts
        uses: actions/cache@v6
        with:
          path: DerivedData/SourcePackages
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
          restore-keys: |
            spm-${{ runner.os }}-
      - name: Build and test the app
        run: |
          xcodebuild test \
            -project Weather.xcodeproj \
            -scheme Weather \
            -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
            -derivedDataPath DerivedData \
            -resultBundlePath TestResults.xcresult
      - name: Keep the result bundle when tests fail
        if: failure()
        uses: actions/upload-artifact@v7
        with:
          name: TestResults
          path: TestResults.xcresult
```

What each part does:

- **Two jobs run in parallel.** `core` tests the pure-Swift package on a cheap Linux runner; `app` builds and tests the app on a Mac. Each reports its own check.
- **`xcodebuild test`** builds the scheme's test action and runs it. `-destination` uses the man page's syntax (`platform=iOS Simulator,name=...`); the simulator name and OS must exist on the image, which is why the step pins `iPhone 17` and `OS=26.5`, both listed in the macOS 26 image README. `xcodebuild -showdestinations -scheme Weather` lists what's available.
- **`-derivedDataPath`** puts build products in the workspace instead of `~/Library/Developer/Xcode/DerivedData`, so the cache step can find the package checkouts. Xcode keeps resolved Swift package checkouts in a `SourcePackages` folder inside derived data; confirm the path in your own build log before relying on it.
- **`-resultBundlePath`** writes an `.xcresult` bundle. The man page: it contains "build logs, code coverage reports, XML property lists with test results, screenshots and other attachments collected during testing." Open it in Xcode to see exactly which test failed and its attachments.
- **`if: failure()`** runs the upload step only when an earlier step failed, so a green build doesn't store a bundle nobody needs.

Module 33's tests are what run here. A flaky test on CI costs more than a flaky test locally: everyone's pull request goes red at random and people learn to click "Re-run" without reading. Fix or quarantine flaky tests (`.disabled("flaky, see #412")` in Swift Testing) instead of retrying them.

## Caching

Every job starts on a fresh virtual machine, so resolving packages from scratch every time is slow. `actions/cache` saves a directory at the end of a job and restores it at the start of later ones. GitHub's reference describes the lookup:

1. Search for an **exact match** of `key`. That's a **cache hit**, and the action's `cache-hit` output is `true`.
2. Otherwise, search for **partial matches** of the key, then of each `restore-keys` entry in order, as prefixes. "If there are multiple partial matches for a restore key, the action returns the most recently created cache." That restores files, but it's a miss.
3. On a miss, "the action automatically creates a new cache if the job completes successfully," under `key`.

Caches can't be changed after they're saved; a new key makes a new cache. That's why keys include `hashFiles('**/Package.resolved')`: when dependencies change, the hash changes, the key misses, the restore key `spm-macOS-` brings back the previous checkouts (most of which are still valid), and the job saves a fresh cache under the new key.

Here's that lookup as a model you can run:

```swift
struct Cache {
    let key: String
    let created: Int   // higher means newer
}

struct Restore {
    let restoredKey: String?
    let cacheHit: Bool
}

func restore(key: String, restoreKeys: [String], from caches: [Cache]) -> Restore {
    // 1. An exact match is a cache hit.
    for cache in caches where cache.key == key {
        return Restore(restoredKey: cache.key, cacheHit: true)
    }
    // 2. Otherwise try the key, then each restore key, as prefixes.
    //    Several matches for one prefix: the newest wins.
    for prefix in [key] + restoreKeys {
        var newest: Cache? = nil
        for cache in caches where cache.key.hasPrefix(prefix) {
            if newest == nil || cache.created > newest!.created {
                newest = cache
            }
        }
        if let newest {
            return Restore(restoredKey: newest.key, cacheHit: false)
        }
    }
    return Restore(restoredKey: nil, cacheHit: false)
}

let caches = [
    Cache(key: "spm-macOS-3f9a", created: 1),
    Cache(key: "spm-macOS-77c0", created: 2),
]

let sameLockfile = restore(key: "spm-macOS-77c0", restoreKeys: ["spm-macOS-"], from: caches)
print(sameLockfile.restoredKey ?? "nothing", sameLockfile.cacheHit)

let newDependency = restore(key: "spm-macOS-d41e", restoreKeys: ["spm-macOS-"], from: caches)
print(newDependency.restoredKey ?? "nothing", newDependency.cacheHit)

let noRestoreKeys = restore(key: "spm-macOS-d41e", restoreKeys: [], from: caches)
print(noRestoreKeys.restoredKey ?? "nothing", noRestoreKeys.cacheHit)
```

```output
spm-macOS-77c0 true
spm-macOS-77c0 false
nothing false
```

The second case is the useful one: a new `Package.resolved` still gets a warm start from the newest older cache. Without restore keys (third case) every dependency change starts cold.

The model leaves out **scope**. GitHub's rules: a run can restore caches created on its own branch or on the default branch, and a pull request run can also use its base branch's caches. A cache created by a pull request run is scoped to that pull request's merge ref, so other pull requests can't restore it. The search order is: the key and restore keys on the current branch, then the same on the default branch. Exercise 5 adds that.

Two more rules from the reference:

- Caches not accessed in 7 days are removed, and the default limit is 10 GB per repository.
- "We recommend that you don't store any sensitive information, such as access tokens or login credentials, in files in the cache path. Anyone with read access can create a pull request on a repository and access the contents of a cache." Never cache a keychain, a `.p12` or an App Store Connect key.

> [!tip] Cache what's slow to fetch, not what's fast to rebuild
> Package checkouts are a good cache. Caching all of derived data is tempting and often disappointing: it's large, it's tied to the exact Xcode version, and a stale build product can hide a real build failure. Measure the job with and without the cache before keeping it.

## Running on pull requests, and required checks

With `on: pull_request`, every push to a pull request's branch runs the workflow against a merge of the branch into its base, and the check appears on the pull request. That only protects `main` if a red check stops the merge.

On GitHub you add a **branch protection rule** or a **ruleset** for `main` and turn on "Require status checks before merging," then choose which checks are required. From GitHub's docs:

- "Required status checks must have a successful, skipped, or neutral status before collaborators can make changes to a protected branch."
- **Strict** (the default: "Require branches to be up to date before merging" checked) means the branch must include the latest `main` before it merges, so the checks ran against what will actually land. **Loose** saves builds, at the risk that "status checks may fail after you merge your branch if there are incompatible changes with the base branch."
- A **merge queue** gives you the strict guarantee without asking every author to update their branch and wait: it tests each queued pull request on top of `main` plus the pull requests ahead of it.

### The path-filter trap

This repository's `swift.yml` only runs when Swift code or lessons change. That's fine as long as its check isn't required. GitHub's docs are explicit:

> If a workflow is skipped due to path filtering, branch filtering, or a commit message, then checks associated with that workflow will remain in a "Pending" state. A pull request that requires those checks to be successful will be blocked from merging.

A pull request that only edits the README would wait forever for "Swift · challenge tests / test." Two fixes:

- Don't make path-filtered workflows required. Make an always-running workflow required instead.
- Or run the workflow on every pull request and decide inside it, with a first step or job that checks what changed and lets the expensive job be skipped with `if:`. GitHub's page on status checks: "A job that is skipped will report its status as 'Success'. It will not prevent a pull request from merging, even if it is a required check." A workflow that never starts reports nothing.

### Secrets and pull requests from forks

Release jobs need secrets (signing certificates, App Store Connect keys; next lesson). GitHub's docs: "With the exception of `GITHUB_TOKEN`, secrets are not passed to the runner when a workflow is triggered from a forked repository," and the token is read-only there. Dependabot pull requests are treated the same way. So:

- Build and test on `pull_request` without any secrets.
- Sign, archive and upload only on `push` to `main`, a release branch or a tag, or on `workflow_dispatch`, where the code has already been reviewed.
- Don't reach for `pull_request_target` to get secrets into fork builds. It runs with the base repository's privileges, which is exactly what you don't want for code nobody has reviewed.

## Xcode Cloud, the Apple-hosted alternative

Apple's description: "Xcode Cloud is a CI/CD system that uses Git for source control," combined with Xcode, TestFlight and App Store Connect. From Apple's documentation (the setup flow wasn't run for this lesson):

- **Where it's configured.** You start in Xcode's Report navigator; later you can edit workflows in Xcode or App Store Connect. Workflows aren't YAML files in your repository.
- **What a workflow has.** Start conditions (for example, every change to the default branch and every pull request targeting it, which is what Xcode suggests first), the Xcode and macOS versions to use, actions ("build, analyze, test, and archive") and post-actions such as distributing to TestFlight.
- **Source control.** It requires Git and supports GitHub, GitLab and Bitbucket (cloud and self-hosted). It can report a status on pull requests, and Apple notes you can make the Xcode Cloud build required in your SCM provider before merging.
- **Customization** is through three scripts in a `ci_scripts` folder next to the project: `ci_post_clone.sh`, `ci_pre_xcodebuild.sh` and `ci_post_xcodebuild.sh`. They run in zsh unless the file is executable and has a shebang, can't use `sudo`, and can read predefined variables such as `CI_PULL_REQUEST_NUMBER`.
- **Signing and distribution are built in.** Apple: Xcode Cloud "can also sign your app for external testing with TestFlight and submission to app review." Builds get an increasing build number starting at 1 automatically.
- **Retention.** Build information and artifacts are kept for 30 days; Apple says to "always download and archive build artifacts for workflows that publish your app on the App Store" (you need the dSYMs; Module 21 explained why).
- **Cost.** Apple's Xcode Cloud page lists 25 compute hours per month included with Apple Developer Program membership, with paid tiers above that.

| | GitHub Actions | Xcode Cloud |
| --- | --- | --- |
| Configuration | YAML in the repository, reviewed like code | Xcode or App Store Connect UI |
| Signing for TestFlight and the App Store | You set it up: certificates, profiles, keys (next lesson) | Managed for you |
| Other platforms in the same pipeline | Linux, Windows, Android, the backend | Apple platforms only |
| Customization | Any shell step, thousands of community actions | Three hook scripts |
| Choice of Xcode | Whatever the runner image ships | Chosen per workflow from Apple's list |

Some teams use both: GitHub Actions for fast pull request checks (including Linux jobs and lint), Xcode Cloud for the archive and TestFlight step so nobody has to manage signing secrets. Either way, CI decides what merges; the tool is a detail.

## Common mistakes

> [!error] Using macos-latest for release builds
> The label moves to a new macOS image over a month or two, and with it the default Xcode. Pin `macos-26` (or whatever you've validated) and set `DEVELOPER_DIR` to a specific Xcode, then upgrade on purpose.

> [!error] Requiring a check from a path-filtered workflow
> When the workflow is skipped by `paths`, the required check stays "Pending" and the pull request can't merge. Require an always-running workflow, or skip jobs inside it so they report as skipped.

> [!error] A constant cache key
> `key: spm-cache` hits forever and never saves a new cache, because caches can't be updated. Put `hashFiles('**/Package.resolved')` (and anything else that changes the contents) in the key, and use restore keys for warm starts.

> [!error] Expecting secrets in fork pull requests
> They aren't passed, so a signing step fails, or worse, someone "fixes" it with `pull_request_target`. Keep pull request jobs secret-free and sign only after merge.

> [!error] Hiding flaky tests behind automatic retries
> A retry turns a real race condition into a check that's green most of the time. Fix the test, or disable it with a reason and an issue link until someone does.

## Exercises

````exercise
id: m41-l01-e1
type: prediction
prompt: "Using the lesson's cache lookup (exact match first, then the key and each restore key as prefixes, newest partial match wins), what does this program print?"
code: |
  struct Cache {
      let key: String
      let created: Int
  }

  func restore(key: String, restoreKeys: [String], from caches: [Cache]) -> String {
      for cache in caches where cache.key == key {
          return "hit \(cache.key)"
      }
      for prefix in [key] + restoreKeys {
          var newest: Cache? = nil
          for cache in caches where cache.key.hasPrefix(prefix) {
              if newest == nil || cache.created > newest!.created {
                  newest = cache
              }
          }
          if let newest {
              return "partial \(newest.key)"
          }
      }
      return "miss"
  }

  let caches = [
      Cache(key: "deriveddata-26.6-a1", created: 1),
      Cache(key: "deriveddata-26.6-b2", created: 3),
      Cache(key: "deriveddata-26.5-c3", created: 4),
  ]
  print(restore(key: "deriveddata-26.6-b2", restoreKeys: ["deriveddata-"], from: caches))
  print(restore(key: "deriveddata-26.6-e5", restoreKeys: ["deriveddata-26.6-", "deriveddata-"], from: caches))
  print(restore(key: "deriveddata-27.0-f6", restoreKeys: ["deriveddata-"], from: caches))
  print(restore(key: "deriveddata-27.0-f6", restoreKeys: [], from: caches))
output: |
  hit deriveddata-26.6-b2
  partial deriveddata-26.6-b2
  partial deriveddata-26.5-c3
  miss
hints:
  - "Restore keys are tried in order, and the first one that matches anything wins, even if a later one would match something newer."
  - "Within one prefix, the newest cache wins."
solution: |
  ```output
  hit deriveddata-26.6-b2
  partial deriveddata-26.6-b2
  partial deriveddata-26.5-c3
  miss
  ```

  1. The key exists exactly: a hit.
  2. No exact match. The key itself isn't a prefix of anything. The first restore key, `deriveddata-26.6-`, matches `a1` (created 1) and `b2` (created 3); the newest is `b2`. The second restore key would have matched `26.5-c3`, which is newer still, but it's never tried: the first restore key that matches anything wins.
  3. Nothing starts with `deriveddata-27.0-f6`. The restore key `deriveddata-` matches all three; the newest is `26.5-c3`.
  4. Same key with no restore keys: nothing matches, a miss.

  Case 3 is the warning. Put the Xcode version in the key, as here, and a broad restore key still hands a 27.0 build the derived data from 26.5. Order restore keys from most to least specific, and leave out the broad one when restoring something from another toolchain does more harm than good.
````

````exercise
id: m41-l01-e2
type: comprehension
prompt: "Your `main` branch requires the check \"iOS · build and test / app\". The workflow has `on: pull_request: paths: ['App/**', 'Packages/**']`. A pull request that only changes `docs/RELEASING.md` can't be merged. Why?"
choices:
  - text: "The workflow was skipped by its path filter, so the required check never reported and stays Pending."
    correct: true
    why: "That's GitHub's documented behavior for path-filtered workflows with required checks."
  - text: "Documentation-only pull requests always need an admin to approve them."
    correct: false
    why: "Nothing in branch protection treats documentation changes specially."
  - text: "The check failed because there were no Swift files to compile."
    correct: false
    why: "The workflow didn't run at all, so nothing failed."
  - text: "Required checks only accept a success status, and skipped counts as a failure."
    correct: false
    why: "GitHub accepts successful, skipped or neutral. The problem is that there is no status at all."
solution: |
  **The workflow never started.** GitHub: "If a workflow is skipped due to path filtering, branch filtering, or a commit message, then checks associated with that workflow will remain in a 'Pending' state. A pull request that requires those checks to be successful will be blocked from merging."

  A required check accepts a skipped job (GitHub reports it as success), but only a job in a workflow that started. A workflow that was filtered out reports nothing. Fix it by removing `paths` from a workflow whose checks are required, and skipping the expensive job inside it based on what changed; or by requiring a different, always-running check.
````

````exercise
id: m41-l01-e3
type: find-errors
prompt: "A teammate's workflow for pull requests on a private iOS repository. Mark every real problem."
code: |
  name: PR checks
  on:
    pull_request:
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v7
        - uses: actions/cache@v6
          with:
            path: ~/signing
            key: signing
        - name: Install signing certificate
          env:
            P12: ${{ secrets.DISTRIBUTION_P12 }}
          run: ./scripts/install-cert.sh
        - name: Test
          run: xcodebuild test -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 17'
choices:
  - text: "xcodebuild and the iOS simulators don't exist on an Ubuntu runner; the job needs a macOS runner."
    correct: true
  - text: "Signing material is cached. Anyone who can open a pull request can access cache contents."
    correct: true
  - text: "The cache key is a constant, so the cache would never be updated."
    correct: true
  - text: "Testing on a simulator doesn't need a distribution certificate, and fork pull requests won't receive the secret anyway."
    correct: true
  - text: "There's no timeout-minutes or concurrency, so stuck or superseded runs keep billing."
    correct: true
  - text: "actions/checkout must come after the cache step."
    correct: false
    why: "Checkout first is normal; the cache step doesn't depend on order here."
  - text: "pull_request needs a types: list or it won't run."
    correct: false
    why: "Without types, pull_request runs on its default activity types (opened, synchronize, reopened)."
rubric:
  - I flagged the Linux runner for an xcodebuild job.
  - I flagged caching signing material and the constant key.
  - I said the test job doesn't need a distribution certificate and that fork PRs don't get secrets.
  - I flagged the missing timeout and concurrency on a billed macOS job.
solution: |
  Five problems:

  1. **`ubuntu-latest` can't run `xcodebuild`.** Use a pinned macOS label (`macos-26`) and a pinned Xcode via `DEVELOPER_DIR`.
  2. **Signing material in a cache.** GitHub warns that anyone with read access can create a pull request and access cache contents. Certificates belong in secrets, decoded into a temporary keychain only in release jobs.
  3. **`key: signing` is constant.** Caches can't be overwritten, so it would hold whatever the first run saved, forever.
  4. **The test job doesn't need signing at all.** Simulator tests run without a distribution identity, and for pull requests from forks the secret wouldn't be passed anyway. Pull request jobs should have no secrets.
  5. **No `timeout-minutes` and no `concurrency`.** In a private repository macOS minutes cost about ten times Linux minutes; a hung simulator or five pushes in a row add up.

  `actions/checkout` first is fine, and `pull_request` without `types` runs on opened, synchronize and reopened by default.
````

````exercise
id: m41-l01-e4
type: fill-in
prompt: "Complete the job so every step uses Xcode 26.4.1 on the macOS 26 image, and print the version to the log."
code: |
  jobs:
    app:
      runs-on: [[1]]
      env:
        [[2]]: /Applications/Xcode_26.4.1.app
      steps:
        - run: xcodebuild [[3]]
blanks:
  - id: "1"
    answers: ["macos-26"]
  - id: "2"
    answers: ["DEVELOPER_DIR"]
  - id: "3"
    answers: ["-version"]
solution: |
  ```yaml
  jobs:
    app:
      runs-on: macos-26
      env:
        DEVELOPER_DIR: /Applications/Xcode_26.4.1.app
      steps:
        - run: xcodebuild -version
  ```

  `macos-26` pins the image instead of following `macos-latest`. `DEVELOPER_DIR` overrides the active developer directory for every process in the job without `sudo`; the `xcode-select` man page says it can point at the Xcode app itself. The macOS 26 image README lists Xcode 26.4.1 at `/Applications/Xcode_26.4.1.app`. Printing `xcodebuild -version` makes the log self-explanatory when something breaks after an image update.

  `sudo xcode-select --switch /Applications/Xcode_26.4.1.app` in a first step does the same thing system-wide.
````

````exercise
id: m41-l01-e5
type: solve
prompt: |
  Extend the cache lookup with branch scope. A cache now records the branch it was created on. A run on `branch` searches its own branch first (exact key, then the key and restore keys as prefixes, newest partial match wins) and, only if nothing matched there, repeats the same search on `defaultBranch`. Return a string like `"hit <key> on <branch>"`, `"partial <key> on <branch>"` or `"miss"`.

  ```swift
  let caches = [
      Cache(key: "spm-macOS-aaa", branch: "main", created: 1),
      Cache(key: "spm-macOS-bbb", branch: "main", created: 2),
      Cache(key: "spm-macOS-ccc", branch: "feature/radar", created: 3),
      Cache(key: "spm-macOS-ddd", branch: "feature/alerts", created: 4),
  ]
  print(restore(key: "spm-macOS-bbb", restoreKeys: ["spm-macOS-"], branch: "feature/radar", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-zzz", restoreKeys: ["spm-macOS-"], branch: "feature/radar", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-zzz", restoreKeys: ["spm-macOS-"], branch: "feature/maps", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-ddd", restoreKeys: [], branch: "feature/maps", defaultBranch: "main", from: caches))
  ```

  Expected output:

  ```output
  partial spm-macOS-ccc on feature/radar
  partial spm-macOS-ccc on feature/radar
  partial spm-macOS-bbb on main
  miss
  ```
starter: |
  struct Cache {
      let key: String
      let branch: String
      let created: Int
  }

  func restore(key: String, restoreKeys: [String], branch: String, defaultBranch: String, from caches: [Cache]) -> String {
      // your code
      return "miss"
  }
hints:
  - "Write the single-branch search as a helper that takes the scope, then call it for branch and then defaultBranch."
  - "In the first line, the exact key exists, but on main. The feature branch is searched completely first, and the prefix spm-macOS-bbb doesn't match ccc, but the restore key does."
  - "A sibling branch's cache (feature/alerts) is never visible to feature/maps."
rubric:
  - Searches the run's own branch completely (exact, key prefix, restore keys) before the default branch.
  - Picks the newest partial match within a prefix.
  - Never returns a cache from a sibling branch.
  - Prints the four expected lines.
solution: |
  ```swift
  struct Cache {
      let key: String
      let branch: String
      let created: Int
  }

  func search(key: String, restoreKeys: [String], scope: String, in caches: [Cache]) -> String? {
      for cache in caches where cache.branch == scope && cache.key == key {
          return "hit \(cache.key) on \(scope)"
      }
      for prefix in [key] + restoreKeys {
          var newest: Cache? = nil
          for cache in caches where cache.branch == scope && cache.key.hasPrefix(prefix) {
              if newest == nil || cache.created > newest!.created {
                  newest = cache
              }
          }
          if let newest {
              return "partial \(newest.key) on \(scope)"
          }
      }
      return nil
  }

  func restore(key: String, restoreKeys: [String], branch: String, defaultBranch: String, from caches: [Cache]) -> String {
      for scope in [branch, defaultBranch] {
          if let result = search(key: key, restoreKeys: restoreKeys, scope: scope, in: caches) {
              return result
          }
      }
      return "miss"
  }

  let caches = [
      Cache(key: "spm-macOS-aaa", branch: "main", created: 1),
      Cache(key: "spm-macOS-bbb", branch: "main", created: 2),
      Cache(key: "spm-macOS-ccc", branch: "feature/radar", created: 3),
      Cache(key: "spm-macOS-ddd", branch: "feature/alerts", created: 4),
  ]
  print(restore(key: "spm-macOS-bbb", restoreKeys: ["spm-macOS-"], branch: "feature/radar", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-zzz", restoreKeys: ["spm-macOS-"], branch: "feature/radar", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-zzz", restoreKeys: ["spm-macOS-"], branch: "feature/maps", defaultBranch: "main", from: caches))
  print(restore(key: "spm-macOS-ddd", restoreKeys: [], branch: "feature/maps", defaultBranch: "main", from: caches))
  ```

  ```output
  partial spm-macOS-ccc on feature/radar
  partial spm-macOS-ccc on feature/radar
  partial spm-macOS-bbb on main
  miss
  ```

  The first line surprises people: the exact key exists on `main`, yet the run restores a partial match from its own branch. That follows the order GitHub documents ("If there are still no hits in the current branch, the cache action retries the same steps on the default branch"): the whole search runs on the current branch first. The last line shows the isolation rule: `feature/maps` can't see `feature/alerts`'s cache, even with the exact key.

  The real action also scopes pull request runs to the merge ref and lets them read the base branch; this model only has a branch and the default branch.
````

````exercise
id: m41-l01-e6
type: design
prompt: "You join a four-person team with a private repository: a SwiftUI app, a `WeatherCore` package with no UIKit or SwiftUI imports, and a backend in another repository. Today nobody runs tests before merging, and releases are archived on one person's laptop. Design their CI on GitHub Actions: which workflows and jobs, on which events and runners, what's cached, which checks are required on `main`, and what you'd keep out of pull request jobs. Say where Xcode Cloud could fit."
rubric:
  - Runs WeatherCore's swift test on Linux and the app's xcodebuild test on a pinned macOS image and Xcode.
  - Runs on pull_request into main and on push to main, with concurrency cancel-in-progress and timeouts.
  - Caches package checkouts keyed on Package.resolved, with a restore key, and never caches secrets.
  - Makes always-running checks required, with strict mode or a merge queue, and avoids path-filter traps.
  - Keeps signing and upload out of pull request jobs and runs them after merge or on tags.
  - Makes a reasoned call about Xcode Cloud for the archive and TestFlight step.
solution: |
  One reasonable design:

  **Workflow `ci.yml`**, on `pull_request` into `main`, `push` to `main` and `workflow_dispatch`; `permissions: contents: read`; `concurrency` per ref with `cancel-in-progress: true`.

  - Job `core` on `ubuntu-latest`, 10-minute timeout: `swift test` in `Packages/WeatherCore`. Cheap, fast feedback, and it keeps the core platform-independent: the day someone imports UIKit there, this job fails.
  - Job `app` on `macos-26` with `DEVELOPER_DIR` pinned, 30-minute timeout: `xcodebuild test` with an explicit simulator destination that the image lists, `-derivedDataPath DerivedData`, `-resultBundlePath`, and the `.xcresult` uploaded on failure.
  - Cache: `DerivedData/SourcePackages` with `key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}` and `restore-keys: spm-${{ runner.os }}-`. Nothing secret in any cache path.
  - No `paths` filters, so both checks always report.

  **Branch protection or a ruleset on `main`**: require `ci / core` and `ci / app`, one approving review, strict mode. With four people, strict mode's extra builds are tolerable; a merge queue is the upgrade if they become annoying.

  **Release workflow `release.yml`** (next lesson), on tags like `v*` or `workflow_dispatch`: the only place signing secrets appear. Never on `pull_request`.

  **Xcode Cloud** is a reasonable choice for the release workflow alone: it signs and uploads to TestFlight without the team managing a `.p12` and keys in GitHub secrets, and 25 compute hours a month covers a few archives a week. The pull request checks stay on GitHub Actions because they include a Linux job and live as reviewable YAML. The cost: two systems to understand, and Xcode Cloud's artifacts expire after 30 days, so its dSYMs must be downloaded and kept.
````

## Summary

- A workflow is YAML in `.github/workflows`: triggers in `on`, a minimal `permissions` block, `concurrency` to cancel superseded runs, and jobs of steps on runners. Each job reports a status check.
- iOS builds need a macOS runner. Pin the image (`macos-26`) and the Xcode (`DEVELOPER_DIR` or `xcode-select --switch`), print the versions, and set timeouts: in private repositories macOS minutes cost about ten times Linux minutes.
- `xcodebuild test` with an explicit simulator destination and a result bundle tests the app; `swift test` tests packages, on Linux when they don't import Apple frameworks.
- `actions/cache` restores an exact key as a hit, otherwise the newest prefix match of the key and then each restore key, on the current branch and then the default branch. Key on `Package.resolved` and never cache secrets.
- Required status checks turn CI into a gate. Path-filtered workflows leave required checks pending; secrets never reach fork pull requests, so signing belongs after merge.
- Xcode Cloud is Apple's managed alternative with signing and TestFlight built in, configured in Xcode and App Store Connect rather than in the repository.
