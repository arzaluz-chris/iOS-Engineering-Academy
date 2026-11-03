---
id: m14-l01
title: Swift packages, modules and dependencies
description: You split a Swift package into a library module, an executable and tests, decide what each module may see with public, package and internal, read the real compiler errors you get when you cross a module boundary the wrong way, add a dependency with a version requirement, and learn what Package.resolved records and why you commit it.
module: m14
order: 1
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l06]
objectives:
  - Name the parts of a package manifest (products, targets, test targets, dependencies) and map each target to its folder.
  - Split code into a library target and an executable target that imports it.
  - Choose between public, package and internal for a declaration based on which modules need it.
  - Read and fix the errors you get when a module uses something it can't see.
  - Add a package dependency with a version requirement and use one of its products.
  - Explain what Package.resolved records, when it changes, and why an app commits it.
terms:
  - term: Module
    definition: "A unit of code that's compiled together and imported as a whole with import. In a Swift package, each target is one module."
  - term: Target
    definition: "A module declared in Package.swift: a library target, an executable target or a test target. Its source files live in a folder with the same name."
  - term: Product
    definition: "What a package offers to the outside: a library other packages can import, or an executable you can run. A product is made of one or more targets."
  - term: Package dependency
    definition: "Another package your package uses, declared in the manifest with a URL (or a local path) and a version requirement."
  - term: Version requirement
    definition: "The range of versions of a dependency your package accepts, for example from 1.5.0 up to, but not including, 2.0.0."
  - term: Semantic versioning
    definition: "The MAJOR.MINOR.PATCH numbering scheme packages use. A major bump may break your code; minor adds features; patch fixes bugs."
  - term: Package.resolved
    definition: "A file SwiftPM writes with the exact version and commit chosen for every dependency, so every build of the project uses the same code."
mastery:
  - Draw the folder layout of a package with a library, an executable and a test target, and write its manifest.
  - Make a type usable from another module by adding public to the type, its members and its initializer.
  - Explain the difference between internal, package and public with one example each.
  - Read "is inaccessible due to 'internal' protection level" and fix it at the declaration, not at the call site.
  - Add swift-argument-parser (or any package) with from, read the version it resolved in Package.resolved, and update it with swift package update.
resources: [swiftpm-docs, swift-cli-getting-started, swift-book-access-control]
cards:
  - id: m14-l01-c1
    front: "In a Swift package, what's the relationship between a target and a module?"
    back: "Each target is one module. Its code lives in Sources/<TargetName> (or Tests/<TargetName> for tests), and other targets use it with import <TargetName> after listing it in their dependencies."
  - id: m14-l01-c2
    front: "internal vs package vs public, across modules?"
    back: "internal (the default): only the same module. package: any module in the same package. public: any module that imports yours, including other packages."
  - id: m14-l01-c3
    front: "Why does a public struct still fail with \"initializer is inaccessible\" in another module?"
    back: "Its memberwise initializer is internal. Another module can only create it if you write a public init yourself."
  - id: m14-l01-c4
    front: "What does from: \"1.5.0\" allow?"
    back: "Any version from 1.5.0 up to, but not including, 2.0.0: new minor and patch versions, never a new major version."
  - id: m14-l01-c5
    front: What is Package.resolved and should you commit it?
    back: "It records the exact version and commit SwiftPM picked for each dependency. Commit it in apps and executables so everyone builds the same code. SwiftPM only reads the root package's file, never a dependency's."
---

## The idea in one sentence

A package splits your code into modules with walls between them, and access control decides which doors in those walls are open; dependencies are other people's modules, pinned to exact versions so every build is the same.

> [!note]
> Every package in this lesson was built, run and tested with Swift 6.3.3 in a Linux container, and the dependency was resolved from GitHub. The progress lines SwiftPM prints (step numbers, timings) will differ on your machine; the files, errors and results won't.

## Package anatomy, revisited

In "Swift from the terminal" you created a package with one executable target and one test target. Real packages have more, and four words carry most of the meaning:

| Word | What it is | Where it lives |
| --- | --- | --- |
| **Target** | One module: a library, an executable or tests | `Sources/<Name>` or `Tests/<Name>` |
| **Product** | What the package offers to others: a library or an executable | Listed in `products:` |
| **Target dependency** | Another target (or a product from another package) this target imports | The target's `dependencies:` |
| **Package dependency** | Another package, with a URL and a version requirement | The package's `dependencies:` |

A **module** is the unit the compiler builds as a whole and that you bring in with `import`. In a package, one target is one module. Your iOS app target is a module too, and so is every framework it uses.

## Splitting code into modules

Here's a small expense tracker split three ways: the logic in a library, a command-line tool on top of it, and tests for the logic.

```plaintext
Expenses/
├── Package.swift
├── Sources/
│   ├── ExpenseCore/
│   │   ├── Expense.swift
│   │   ├── ExpenseReport.swift
│   │   └── Formatting.swift
│   └── expenses/
│       └── main.swift
└── Tests/
    └── ExpenseCoreTests/
        └── ExpenseReportTests.swift
```

The manifest declares one target per folder:

```swift illustrative
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Expenses",
    products: [
        .library(name: "ExpenseCore", targets: ["ExpenseCore"]),
        .executable(name: "expenses", targets: ["expenses"]),
    ],
    targets: [
        .target(name: "ExpenseCore"),
        .executableTarget(
            name: "expenses",
            dependencies: ["ExpenseCore"]
        ),
        .testTarget(
            name: "ExpenseCoreTests",
            dependencies: ["ExpenseCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Line by line:

1. `products:` is the public face of the package. `.library(name: "ExpenseCore", …)` lets **other packages** depend on `ExpenseCore`. `.executable` names the program `swift run expenses` runs.
2. `.target(name: "ExpenseCore")` is a library module. Its code is everything in `Sources/ExpenseCore`.
3. `.executableTarget(name: "expenses", dependencies: ["ExpenseCore"])` is the command-line tool. The dependency is what makes `import ExpenseCore` work inside it.
4. `.testTarget(name: "ExpenseCoreTests", dependencies: ["ExpenseCore"])` holds the tests for the library.

Targets inside one package can depend on each other without being products. Products only matter to the outside world.

Why bother splitting? Three reasons you'll feel on a real project:

- **The compiler enforces the boundaries.** Code in `expenses` can only use what `ExpenseCore` chooses to expose. Nobody reaches into the formatting helper "just this once".
- **Logic you can test without the UI.** In an iOS app, the same split puts your models and rules in a package that `swift test` can check in seconds, with no simulator.
- **Reuse.** An app, its widget extension and a command-line tool can all import the same `ExpenseCore`.

## The library's code

`Sources/ExpenseCore/Expense.swift`:

```swift illustrative
public struct Expense {
    public let title: String
    public let cents: Int

    public init(title: String, cents: Int) {
        self.title = title
        self.cents = cents
    }
}
```

`Sources/ExpenseCore/ExpenseReport.swift`:

```swift illustrative
public struct ExpenseReport {
    public private(set) var expenses: [Expense] = []

    public init() {}

    public mutating func add(_ expense: Expense) {
        expenses.append(expense)
    }

    public var totalCents: Int {
        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        return total
    }

    public func summary() -> String {
        "\(expenses.count) expenses, total \(formatCents(totalCents))"
    }

    package func lines() -> [String] {
        expenses.map { "\($0.title): \(formatCents($0.cents))" }
    }
}
```

`Sources/ExpenseCore/Formatting.swift`:

```swift illustrative
func formatCents(_ cents: Int) -> String {
    let dollars = cents / 100
    let rest = cents % 100
    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
}
```

And the tool, `Sources/expenses/main.swift`:

```swift illustrative
import ExpenseCore

var report = ExpenseReport()
report.add(Expense(title: "Coffee", cents: 450))
report.add(Expense(title: "Lunch", cents: 1299))

for line in report.lines() {
    print(line)
}
print(report.summary())
```

```bash
swift run expenses
```

```output
Building for debugging...
[0/2] Write swift-version-24593BA9C3E375BF.txt
Build of product 'expenses' complete! (0.14s)
Coffee: $4.50
Lunch: $12.99
2 expenses, total $17.49
```

Amounts are stored as whole cents in an `Int`, so `0.1 + 0.2` rounding problems can't creep into money.

The multi-file blocks above can't run as one program here, so they're marked illustrative. The same logic in a single file does run; with everything in one module, no `public` is needed:

```swift
struct Expense {
    let title: String
    let cents: Int
}

struct ExpenseReport {
    private(set) var expenses: [Expense] = []

    mutating func add(_ expense: Expense) {
        expenses.append(expense)
    }

    var totalCents: Int {
        var total = 0
        for expense in expenses {
            total += expense.cents
        }
        return total
    }

    func summary() -> String {
        "\(expenses.count) expenses, total \(formatCents(totalCents))"
    }

    func lines() -> [String] {
        expenses.map { "\($0.title): \(formatCents($0.cents))" }
    }
}

func formatCents(_ cents: Int) -> String {
    let dollars = cents / 100
    let rest = cents % 100
    return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
}

var report = ExpenseReport()
report.add(Expense(title: "Coffee", cents: 450))
report.add(Expense(title: "Lunch", cents: 1299))

for line in report.lines() {
    print(line)
}
print(report.summary())
```

```output
Coffee: $4.50
Lunch: $12.99
2 expenses, total $17.49
```

## Access control across modules

In Module 10 you met the six access levels, and saw that in a single file only `private` made a visible difference. Across modules, the rest come alive:

| Level | Who can use it |
| --- | --- |
| `private` | The enclosing declaration and its extensions in the same file |
| `fileprivate` | The same source file |
| `internal` (default) | The same module |
| `package` | Any module in the same package |
| `public` | Any module that imports this one |
| `open` | Like `public`, plus subclassing and overriding from other modules (classes only) |

Read the library again with that table in mind:

- `Expense`, `ExpenseReport`, their properties, `add`, `totalCents` and `summary()` are `public`: they're the API anyone may use.
- `public private(set) var expenses`: everyone can read the list; only `ExpenseReport` can change it.
- `lines()` is `package`: the `expenses` tool in the same package can use it, but an outside package that adds `ExpenseCore` as a dependency can't. Use `package` for things your own modules share that you don't want to promise to strangers.
- `formatCents` has no keyword, so it's `internal`: an implementation detail of `ExpenseCore`.

### What the compiler says when you cross a wall

Each of these was produced by changing one thing in the package above and running `swift build` with Swift 6.3.

Call the internal helper from `main.swift`:

```swift illustrative
print(formatCents(100))
```

```output
error: cannot find 'formatCents' in scope
```

An internal top-level function is invisible from other modules, so the message says "cannot find" rather than "inaccessible". The fix is a decision, not a keyword: either `formatCents` becomes part of the API (`public`), or the tool shouldn't need it.

Change `package func lines()` to plain `func lines()`:

```output
error: 'lines' is inaccessible due to 'internal' protection level
```

Here the method is found, because `ExpenseReport` is public, but it's locked. And from a **second package** that depends on `Expenses`, the original `package func lines()` gives:

```output
error: 'lines' is inaccessible due to 'package' protection level
```

The trap everyone hits once: remove `public init` from `Expense`, leaving the struct and its properties public.

```output
error: 'Expense' initializer is inaccessible due to 'internal' protection level
```

> [!warning] A public struct doesn't get a public memberwise initializer
> Swift writes `init(title:cents:)` for you, but it's `internal`. Other modules can read a public struct's public properties and still not be able to create one. Write `public init` by hand. (`ExpenseReport` has `public init() {}` for the same reason.)

### Why package needs a package

`package` only means something when the compiler knows which package a module belongs to. SwiftPM tells it. Compile a file on its own with `swiftc` and you get:

```swift no-compile requires a package name; set it with the compiler flag -package-name
struct Report {
    package func lines() -> [String] {
        ["Coffee: $4.50"]
    }
}

print(Report().lines())
```

Swift 6.3 says `error: the package access level used on 'lines()' requires a package name; set it with the compiler flag -package-name`. Inside a package, `swift build` passes that flag for you.

### Tests and @testable import

The test target has one extra power. `Tests/ExpenseCoreTests/ExpenseReportTests.swift`:

```swift illustrative
import Testing
@testable import ExpenseCore

@Test func totalAddsAllExpenses() {
    var report = ExpenseReport()
    report.add(Expense(title: "Coffee", cents: 450))
    report.add(Expense(title: "Lunch", cents: 1299))
    #expect(report.totalCents == 1749)
}

@Test func formatsCentsWithTwoDigits() {
    #expect(formatCents(1705) == "$17.05")
}
```

`@testable import` lets tests use `internal` declarations such as `formatCents`. It works in debug builds, which is what `swift test` uses. It doesn't reach `private` or `fileprivate`.

```output
✔ Test totalAddsAllExpenses() passed after 0.001 seconds.
✔ Test formatsCentsWithTwoDigits() passed after 0.001 seconds.
✔ Test run with 2 tests in 0 suites passed after 0.001 seconds.
```

## Adding a dependency

Typing amounts into `main.swift` gets old. The tool should read them from the command line: `expenses 450 1299`. Parsing arguments, printing help and rejecting bad input is a solved problem, so use **swift-argument-parser**, the package Apple maintains for command-line tools.

The manifest gains a package dependency and a product dependency:

```swift illustrative
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Expenses",
    products: [
        .library(name: "ExpenseCore", targets: ["ExpenseCore"]),
        .executable(name: "expenses", targets: ["expenses"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(name: "ExpenseCore"),
        .executableTarget(
            name: "expenses",
            dependencies: [
                "ExpenseCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ExpenseCoreTests",
            dependencies: ["ExpenseCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

Two places change:

1. The package-level `dependencies:` says **where to get it** and **which versions are acceptable**.
2. The target's `dependencies:` says **which product this target imports**. `.product(name: "ArgumentParser", package: "swift-argument-parser")` names the library product and the package it comes from (the last part of the URL, without `.git`). Only targets that list it can `import ArgumentParser`; `ExpenseCore` stays free of it.

`main.swift` is replaced by `Sources/expenses/ExpensesCommand.swift`:

```swift illustrative
import ArgumentParser
import ExpenseCore

@main
struct ExpensesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "expenses")

    @Argument(help: "Amounts in cents, for example 450 1299.")
    var amounts: [Int]

    @Flag(help: "Print one line per expense.")
    var verbose = false

    func run() {
        var report = ExpenseReport()
        for amount in amounts {
            report.add(Expense(title: "Item", cents: amount))
        }
        if verbose {
            for line in report.lines() {
                print(line)
            }
        }
        print(report.summary())
    }
}
```

`@Argument` and `@Flag` are property wrappers from the library: attributes that add behavior to a property. You'll use many of them in the SwiftUI modules (`@State`, `@Binding`). Here they tell the parser that `amounts` comes from the positional arguments and `verbose` from `--verbose`. The program now starts at the `@main` type instead of at top-level statements, and the file is named after that type.

The first build fetches the package:

```bash
swift build
```

```output
Fetching https://github.com/apple/swift-argument-parser.git
[1/19330] Fetching swift-argument-parser
Fetched https://github.com/apple/swift-argument-parser.git from cache (2.81s)
Computing version for https://github.com/apple/swift-argument-parser.git
Computed https://github.com/apple/swift-argument-parser.git at 1.8.2 (3.09s)
Creating working copy for https://github.com/apple/swift-argument-parser.git
Working copy of https://github.com/apple/swift-argument-parser.git resolved at 1.8.2
```

After that come the compile steps and `Build complete!`. The fetch lines vary from machine to machine; the line that matters is the version it resolved. Then:

```bash
swift run expenses --verbose 450 1299
```

```output
Item: $4.50
Item: $12.99
2 expenses, total $17.49
```

And with no arguments, the library does the error handling you didn't write:

```output
Error: Missing expected argument '<amounts> ...'

USAGE: expenses <amounts> ... [--verbose]

ARGUMENTS:
  <amounts>               Amounts in cents, for example 450 1299.

OPTIONS:
  --verbose               Print one line per expense.
  -h, --help              Show help information.
```

### Version requirements

Packages are versioned with **semantic versioning**, `MAJOR.MINOR.PATCH`. A patch release fixes bugs, a minor release adds features without breaking existing code, and a major release is allowed to break it. Your requirement says how much change you accept. All four of these were resolved against swift-argument-parser in November 2026, when its newest version was 1.8.2:

| Requirement | Accepts | Resolved to |
| --- | --- | --- |
| `from: "1.5.0"` | 1.5.0 up to, not including, 2.0.0 | 1.8.2 |
| `.upToNextMinor(from: "1.7.0")` | 1.7.0 up to, not including, 1.8.0 | 1.7.2 |
| `"1.6.0"..<"1.8.0"` | That range | 1.7.2 |
| `exact: "1.7.0"` | Only 1.7.0 | 1.7.0 |

`from:` is the usual choice: you get fixes and features, never a breaking major version. `exact:` freezes you out of bug fixes and makes conflicts likely when two packages need the same dependency, so keep it for emergencies.

> [!tip]
> In Xcode, Apple's documentation describes the same choices under *File > Add Package Dependency* ("Up to Next Major Version", "Up to Next Minor Version", a range or an exact version). See [Adding package dependencies to your app](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app). The Xcode steps weren't checked in Xcode for this lesson.

## Package.resolved

A requirement is a range. A build needs one exact version. When SwiftPM picks one, it writes it down in `Package.resolved`, next to `Package.swift`:

```output
{
  "originHash" : "305465f119aa755367443718134b09680159c40c01a788a4ab3ff81a1b840dfe",
  "pins" : [
    {
      "identity" : "swift-argument-parser",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/apple/swift-argument-parser.git",
      "state" : {
        "revision" : "6a52f3251125d74daf04fcbd5e6f08a75d074382",
        "version" : "1.8.2"
      }
    }
  ],
  "version" : 3
}
```

Each **pin** records the version and the exact Git commit (`revision`). From then on:

- `swift build` uses the pinned versions, even if a newer one inside your range comes out. To check, the pin was set to 1.7.0 and the requirement left at `from: "1.5.0"`: `swift build` kept 1.7.0.
- `swift package update` re-resolves within your requirements and rewrites the file. In the same check it moved the pin from 1.7.0 to 1.8.2.
- `swift package show-dependencies` prints the tree:

```output
.
└── swift-argument-parser<https://github.com/apple/swift-argument-parser.git@1.8.2>(traits: default)
```

**Commit `Package.resolved` for apps and executables.** Then your teammate, your CI server and you in six months all build exactly the same dependency code, and updates happen on purpose, in a commit of their own. Xcode projects have the same file, inside the `.xcodeproj` bundle; Apple's documentation also says to commit it.

For a library, the file matters less: SwiftPM reads only the **root** package's `Package.resolved`. When another package depends on `Expenses`, the pins in `Expenses/Package.resolved` are ignored. That was checked too: with the library pinned at 1.7.0, a second package that depended on it resolved swift-argument-parser at 1.8.2.

> [!warning] Don't edit Package.resolved by hand
> Change the requirement in `Package.swift`, then run `swift package resolve` or `swift package update`. If the file gets into a bad state (a messy merge, for example), delete it and resolve again, then review what versions you got before committing.

## Common mistakes

> [!error] error: no such module 'ExpenseCore'
> The target that writes `import ExpenseCore` doesn't list `"ExpenseCore"` in its `dependencies:`. Add it to that target in `Package.swift`. (In this check the error only appeared after deleting `.build`; with an old build lying around, the same mistake showed up later as a linker error instead.)

> [!error] error: 'Expense' initializer is inaccessible due to 'internal' protection level
> The struct is `public`, but the memberwise initializer Swift writes for it is internal. Add a `public init`.

> [!error] error: 'lines' is inaccessible due to 'internal' protection level
> Fix it at the declaration: if another module of the same package needs it, make it `package`; if outsiders need it, `public`. Don't copy the code into the caller.

> [!error] Making everything public
> Every `public` declaration is a promise: change it and other people's code breaks. Start `internal`, open up to `package` or `public` when a real caller needs it.

> [!error] Using a dependency's product from a target that didn't list it
> Adding the package to the package-level `dependencies:` isn't enough. The target that imports it must also list `.product(name:package:)`, or you get `no such module`.

## Exercises

````exercise
id: m14-l01-e1
type: comprehension
prompt: "`ExpenseReport.lines()` should be callable from the `expenses` executable in the same package, but not from other packages that depend on `ExpenseCore`. Which access level?"
choices:
  - text: "`internal`"
    correct: false
    why: "internal stops at the module boundary, so the expenses executable can't call it either."
  - text: "`package`"
    correct: true
    why: "package is visible to every module in the same package and to nothing outside it."
  - text: "`public`"
    correct: false
    why: public also lets other packages call it, which is what you wanted to avoid.
  - text: "`fileprivate`"
    correct: false
    why: fileprivate limits it to one source file, which is narrower than internal.
solution: |
  **`package`**. It was added in Swift 5.9 for exactly this case: two modules of your own that share something you don't want to promise to the world. From another package, calling it gives `error: 'lines' is inaccessible due to 'package' protection level`.
````

````exercise
id: m14-l01-e2
type: prediction
prompt: "This is the `formatCents` function from `ExpenseCore`. What does the program print?"
code: |
  func formatCents(_ cents: Int) -> String {
      let dollars = cents / 100
      let rest = cents % 100
      return rest < 10 ? "$\(dollars).0\(rest)" : "$\(dollars).\(rest)"
  }

  print(formatCents(5))
  print(formatCents(1750))
  print(formatCents(100))
output: |
  $0.05
  $17.50
  $1.00
hints:
  - "Integer division drops the remainder: 5 / 100 is 0."
  - "When rest is below 10, a 0 is inserted before it."
solution: |
  ```output
  $0.05
  $17.50
  $1.00
  ```

  - `5`: dollars `0`, rest `5`, below 10, so `"$0.0" + "5"`.
  - `1750`: dollars `17`, rest `50`, so `"$17.50"`.
  - `100`: dollars `1`, rest `0`, below 10, so `"$1.00"`.

  This is the kind of function to test from `ExpenseCoreTests` with `@testable import`, since it's internal.
````

````exercise
id: m14-l01-e3
type: find-errors
prompt: "A teammate added a `Budget` type to `ExpenseCore` and uses it from the `expenses` tool. Mark every real problem."
code: |
  // Package.swift (targets only)
  .target(name: "ExpenseCore"),
  .executableTarget(name: "expenses"),

  // Sources/ExpenseCore/Budget.swift
  public struct Budget {
      public let limitCents: Int
      func isOver(_ report: ExpenseReport) -> Bool {
          report.totalCents > limitCents
      }
  }

  // Sources/expenses/main.swift
  import ExpenseCore
  let budget = Budget(limitCents: 2000)
  print(budget.isOver(ExpenseReport()))
choices:
  - text: "The executable target doesn't list ExpenseCore in its dependencies, so import ExpenseCore fails with no such module."
    correct: true
  - text: "Budget has no public init, so Budget(limitCents:) is inaccessible from the expenses module."
    correct: true
  - text: "isOver is internal, so the expenses module can't call it."
    correct: true
  - text: "Budget must be a class to be used from another module."
    correct: false
    why: Structs cross module boundaries fine; access control is what matters.
  - text: "public let can't be used on a struct property."
    correct: false
    why: Public stored properties are fine; Expense uses them.
rubric:
  - I found the missing target dependency.
  - I found the missing public init.
  - I found that isOver needs public (or package, since the caller is in the same package).
solution: |
  Three real problems:

  1. `.executableTarget(name: "expenses")` needs `dependencies: ["ExpenseCore"]`. Without it, `import ExpenseCore` gives `error: no such module 'ExpenseCore'`.
  2. The memberwise `init(limitCents:)` is internal. Add `public init(limitCents: Int) { self.limitCents = limitCents }`.
  3. `isOver` is internal. Since only your own tool calls it, `package func isOver` is enough; make it `public` if other packages should be able to use it too.

  Structs and public stored properties are fine across modules.
````

````exercise
id: m14-l01-e4
type: fill-in
prompt: Complete the manifest so the `expenses` executable can `import ArgumentParser`, accepting any 1.x version from 1.5.0 on.
code: |
  dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser.git", [[1]]: "1.5.0"),
  ],
  targets: [
      .target(name: "ExpenseCore"),
      .executableTarget(
          name: "expenses",
          dependencies: [
              "ExpenseCore",
              .[[2]](name: "ArgumentParser", package: "[[3]]"),
          ]
      ),
  ]
blanks:
  - id: "1"
    answers: ["from"]
  - id: "2"
    answers: ["product"]
  - id: "3"
    answers: ["swift-argument-parser"]
solution: |
  ```swift illustrative
  dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
  ],
  targets: [
      .target(name: "ExpenseCore"),
      .executableTarget(
          name: "expenses",
          dependencies: [
              "ExpenseCore",
              .product(name: "ArgumentParser", package: "swift-argument-parser"),
          ]
      ),
  ]
  ```

  `from:` accepts 1.5.0 up to, not including, 2.0.0. `.product(name:package:)` names the library product and the package it comes from; the package name is the last part of the URL without `.git`.
````

````exercise
id: m14-l01-e5
type: comprehension
multiple: true
prompt: "Your manifest says `from: \"1.5.0\"`. Which versions can SwiftPM choose? Mark all that apply."
choices:
  - text: "1.5.0"
    correct: true
    why: The lower bound is included.
  - text: "1.8.2"
    correct: true
    why: Same major version, newer minor and patch.
  - text: "2.0.0"
    correct: false
    why: A new major version may break your code; from stops just before it.
  - text: "1.4.9"
    correct: false
    why: Below the lower bound.
solution: |
  `from: "1.5.0"` means `1.5.0 ..< 2.0.0`. In November 2026 it resolved to 1.8.2. Which version you actually get is then recorded in `Package.resolved`, and stays there until you run `swift package update`.
````

````exercise
id: m14-l01-e6
type: solve
prompt: |
  Add a third module to the `Expenses` package: a library target `ExpenseExport` with a function `csv(for:)` that turns a report into CSV text, one header line `title,cents` and one line per expense. The `expenses` tool should print the CSV. Add a test target `ExpenseExportTests` with one test. Build, run and test with `swift build`, `swift run expenses` and `swift test`.

  With Coffee (450) and Lunch (1299), `swift run expenses` should end with:

  ```output
  title,cents
  Coffee,450
  Lunch,1299
  ```
starter: |
  // Package.swift (targets so far)
  .target(name: "ExpenseCore"),
  .executableTarget(name: "expenses", dependencies: ["ExpenseCore"]),
  .testTarget(name: "ExpenseCoreTests", dependencies: ["ExpenseCore"]),
hints:
  - "A new folder Sources/ExpenseExport and a new .target in the manifest."
  - "ExpenseExport uses ExpenseReport, so it depends on ExpenseCore and imports it."
  - "csv(for:) is called from another module, so it must be public."
  - "report.expenses is readable from outside because it's public private(set)."
rubric:
  - ExpenseExport is a separate target with its own folder and depends on ExpenseCore.
  - csv(for:) is public; nothing in ExpenseCore had to become more visible than it already was.
  - The executable lists ExpenseExport in its dependencies and imports it.
  - The test target imports ExpenseExport and checks the exact CSV text.
  - swift build, swift run and swift test all succeed.
solution: |
  The manifest's targets (add `.library(name: "ExpenseExport", targets: ["ExpenseExport"])` to `products:` only if other packages should use it):

  ```swift illustrative
  .target(name: "ExpenseCore"),
  .target(
      name: "ExpenseExport",
      dependencies: ["ExpenseCore"]
  ),
  .executableTarget(
      name: "expenses",
      dependencies: ["ExpenseCore", "ExpenseExport"]
  ),
  .testTarget(
      name: "ExpenseCoreTests",
      dependencies: ["ExpenseCore"]
  ),
  .testTarget(
      name: "ExpenseExportTests",
      dependencies: ["ExpenseExport"]
  ),
  ```

  `Sources/ExpenseExport/CSVExporter.swift`:

  ```swift illustrative
  import ExpenseCore

  public func csv(for report: ExpenseReport) -> String {
      var text = "title,cents\n"
      for expense in report.expenses {
          text += "\(expense.title),\(expense.cents)\n"
      }
      return text
  }
  ```

  `Sources/expenses/main.swift`:

  ```swift illustrative
  import ExpenseCore
  import ExpenseExport

  var report = ExpenseReport()
  report.add(Expense(title: "Coffee", cents: 450))
  report.add(Expense(title: "Lunch", cents: 1299))

  print(csv(for: report), terminator: "")
  ```

  `Tests/ExpenseExportTests/CSVExporterTests.swift`:

  ```swift illustrative
  import Testing
  import ExpenseCore
  import ExpenseExport

  @Test func csvHasAHeaderAndOneRowPerExpense() {
      var report = ExpenseReport()
      report.add(Expense(title: "Coffee", cents: 450))
      #expect(csv(for: report) == "title,cents\nCoffee,450\n")
  }
  ```

  This exact package was built with Swift 6.3: `swift run expenses` printed the three CSV lines and `swift test` reported `Test run with 3 tests in 0 suites passed`. The test imports `ExpenseCore` too, because it creates an `ExpenseReport`. `terminator: ""` avoids a blank line, since the CSV already ends in a newline.

  The point of the separate module: `ExpenseCore` doesn't know CSV exists. If you later export to JSON, that's another module, and the core doesn't change.
````

````exercise
id: m14-l01-e7
type: explain
prompt: "A teammate asks why `Package.resolved` is in the repository. \"It's generated, so shouldn't it be ignored like `.build`?\" Answer them."
code: |
  # .gitignore proposed in the pull request
  .DS_Store
  /.build
  Package.resolved
rubric:
  - I said Package.resolved records the exact version and commit of every dependency.
  - I explained that swift build uses those pins instead of the newest allowed version.
  - I explained that committing it makes every machine and CI build the same dependency code.
  - I mentioned that updates happen deliberately with swift package update, in their own commit.
  - "I noted the difference from .build: .build can be regenerated identically, Package.resolved can't (a later resolve might pick newer versions)."
solution: |
  `.build` is pure output: delete it and the next build recreates the same thing. `Package.resolved` is a **decision**: of all the versions your requirements allow, it records the one that was picked, down to the Git commit. If it weren't committed, each machine would resolve on its own and could get a different version, depending on what had been released that day. Then "works on my machine" bugs come from code nobody chose.

  With the file committed, `swift build` on any machine uses the same pins. When you want newer versions, run `swift package update`, run the tests, and commit the changed `Package.resolved` on its own so the change is easy to review and easy to revert. For a library package it matters less, because SwiftPM only reads the root package's resolved file, but committing it still keeps your own CI reproducible.
````

## Summary

- A package has targets (modules), products (what others can use) and dependencies. Each target is a folder and a module.
- Split logic into a library target so executables, apps and tests can import it and the compiler enforces the boundary.
- Across modules: `internal` stays in the module, `package` stays in the package, `public` is for everyone. A public struct needs a hand-written `public init`.
- `@testable import` gives test targets access to `internal` declarations.
- Add a dependency in two places: the package's `dependencies:` with a URL and a requirement (usually `from:`), and the target's `dependencies:` with `.product(name:package:)`.
- `Package.resolved` pins exact versions. Commit it for apps; change it on purpose with `swift package update`.
