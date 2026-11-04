---
id: m32-l06
title: Modularization and choosing trade-offs
description: "Split the reading list app into Swift package targets and let the compiler enforce the architecture. You compare layer modules with feature modules, add an interface module so features don't depend on each other's implementations, see what public, package and internal mean across targets (verified by building a real package), reason about what recompiles when a module changes, and finish with a decision table for MVC, MVVM, MVP, Clean Architecture and coordinators."
module: m32
order: 6
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l05]
objectives:
  - Organize an app into Swift package targets by layer or by feature, and explain what each choice does to dependencies and build times.
  - Use an interface module so one feature can use another without depending on its implementation.
  - Choose public, package or internal for each declaration in a multi-target package, including initializers and protocol requirements.
  - Predict which modules recompile after a change, from the dependency graph.
  - Choose an architecture for a feature from its size, rules, navigation and team, and justify it.
terms:
  - term: Module
    definition: "A unit of code distribution and access control in Swift: a Swift package target, an app target or a framework. Other modules use it through import and see only what it makes visible."
  - term: Feature module
    definition: "A module that holds one feature vertically (its view models, views, use cases), depending on shared core modules but not on other features."
  - term: Interface module
    definition: "A small module with only public protocols and value types that describe what a feature offers. Other features depend on it instead of on the feature's implementation module."
  - term: package access level
    definition: "An access level (Swift 5.9) between internal and public: visible to every target in the same Swift package, invisible to other packages."
  - term: Composition target
    definition: "The app target (or a dedicated module) that depends on every implementation module and wires them together. It's the composition root from lesson 5, at module scale."
mastery:
  - Sketch a Package.swift with domain, interface, feature, infrastructure and app targets, and point every dependency the right way.
  - Explain why a public struct needs an explicit public init to be created from another module.
  - Decide between package and public for a helper shared by two targets.
  - "Given a module graph, list what recompiles when one module's public interface changes, and which modules can build in parallel."
  - Pick an architecture for three different screens and defend the choice with the decision table.
resources: [packagedescription-target, se-0386-package-access, swiftpm-docs, swift-book-access-control, swift-book-protocols, swift-testing-docs]
cards:
  - id: m32-l06-c1
    front: Layer modules vs feature modules?
    back: "Layer modules (Domain, Data, Presentation) mean every feature change touches several modules and a Domain change rebuilds everything. Feature modules keep each feature in one module over shared cores, so features change and build independently."
  - id: m32-l06-c2
    front: What does an interface module buy you?
    back: "Features depend on a tiny module of protocols instead of on each other's implementations. Implementation changes then recompile only that feature, features can't reach each other's internals, and cycles between features can't form."
  - id: m32-l06-c3
    front: What's the difference between package and public?
    back: "package: visible to every target in the same Swift package, not to other packages. public: visible to any module that imports it. Use package for helpers shared between your own targets, public for the API other packages use."
  - id: m32-l06-c4
    front: Why can't another module create your public struct with its memberwise initializer?
    back: "The implicit memberwise initializer is internal. A public struct meant to be created from other modules needs an explicit public init."
  - id: m32-l06-c5
    front: What recompiles when a module changes?
    back: "When only implementation changes, the module itself recompiles (and the app relinks). When its public interface changes, every module that depends on it, directly or transitively, recompiles too."
---

## The idea in one sentence

Splitting an app into modules turns architectural rules into **compiler-enforced boundaries**: a module can only use what it imports and what that module makes visible, so "the domain doesn't know about features" stops being a convention and becomes a build error.

> [!note] How the claims in this lesson were checked
> The `Package.swift`, folder trees and cross-module code below are illustrative, because the snippet tests compile one file at a time. Every claim about access control, dependency errors and recompilation was checked by building a small multi-target package (domain, interface, two features, storage, an app and a test target) with SwiftPM in Swift 6.3 on Linux, in November 2026. The diagnostics quoted are from that build. Xcode projects that use local packages behave the same way for access control; build scheduling details differ between Xcode and SwiftPM.

## Why modules

Lesson 4 said folders don't enforce the dependency rule: a file in `Domain/` can import UIKit and nothing complains. Modules do:

- **Visibility.** A module sees another module only if it declares the dependency and imports it, and then only its `public` (or `package`) declarations. Everything else is invisible.
- **Direction.** Swift packages reject cycles between targets. If `BookDomain` depends on `ReadingListFeature`, it can't also be the other way around.
- **Build times.** A module whose code didn't change doesn't need recompiling, and independent modules compile in parallel.
- **Ownership.** A team can own a module, review changes to its public API carefully, and change internals freely.

The cost: more `Package.swift` to maintain, `public` keywords and explicit initializers on everything that crosses a boundary, and more friction when an API needs to change. A single developer with a small app gets little from it. Several developers, a widget and an App Intent sharing code (lesson 5's exercise), or slow incremental builds are the usual reasons to start.

In current iOS projects, modules are usually **targets of a local Swift package** that the Xcode app target depends on. The app target stays thin: the `App` struct or scene delegate and the composition root.

## By layer or by feature

The first decision is what a module contains. Splitting the rings from lesson 4 into modules gives **layer modules**:

```text
App ──▶ Presentation ──▶ Domain ◀── Data
```

It's simple, and it enforces the dependency rule. But every feature lives in all three, so a change to the reading list touches three modules, and since everything depends on `Domain`, any change to it recompiles the whole app. With 30 features, `Presentation` is as big as the app was.

**Feature modules** cut the other way: each feature is a module, built on a few shared core modules.

```text
Bookshelf/
├── Package.swift
├── Sources/
│   ├── BookDomain/              entities, use cases, BookStore protocol
│   ├── Networking/              API client, transport
│   ├── BookStorage/             BookStore adapters (API + cache, SwiftData)
│   ├── DesignSystem/            colors, fonts, shared views
│   ├── ReadingListInterface/    protocols other features may use
│   ├── ReadingListFeature/      view models, views, coordinator
│   └── ProfileFeature/
└── Tests/
    ├── BookDomainTests/
    └── ReadingListFeatureTests/
```

Its dependency graph, where each arrow means "depends on":

```text
App                   → ReadingListFeature, ProfileFeature, BookStorage
ReadingListFeature    → BookDomain, ReadingListInterface, DesignSystem
ProfileFeature        → ReadingListInterface, DesignSystem
BookStorage           → BookDomain, Networking
ReadingListInterface  → (nothing)
BookDomain            → (nothing)
Networking            → (nothing)
DesignSystem          → (nothing)
```

The rules that keep this graph healthy:

1. **Features never depend on other features' implementation modules.** If Profile needs something from the reading list, it goes through `ReadingListInterface`.
2. **Core modules never depend on features.** `BookDomain` and `Networking` know nothing above them.
3. **Only the app target depends on everything**, and it does so to wire things together.

The `Package.swift` that describes it:

```swift illustrative
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bookshelf",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ReadingListFeature", targets: ["ReadingListFeature"]),
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
        .library(name: "BookStorage", targets: ["BookStorage"]),
    ],
    targets: [
        .target(name: "BookDomain"),
        .target(name: "Networking"),
        .target(name: "DesignSystem"),
        .target(name: "BookStorage", dependencies: ["BookDomain", "Networking"]),
        .target(name: "ReadingListInterface"),
        .target(name: "ReadingListFeature", dependencies: ["BookDomain", "ReadingListInterface", "DesignSystem"]),
        .target(name: "ProfileFeature", dependencies: ["ReadingListInterface", "DesignSystem"]),
        .testTarget(name: "BookDomainTests", dependencies: ["BookDomain"]),
        .testTarget(name: "ReadingListFeatureTests", dependencies: ["ReadingListFeature", "BookDomain"]),
    ]
)
```

Each `.target` is a module whose sources are in `Sources/<name>/`. `dependencies` lists what it may import. `products` are what the Xcode app target (or another package) can link against. Features are separate products so the app, a widget extension and an App Intents extension can each link only what they use.

## Interface modules

The profile screen shows "2 of 4 read" under the user's name. That number comes from the reading list feature. Depending on `ReadingListFeature` directly would work, and it would mean every change to the reading list's view models recompiles Profile, and Profile could start using reading list internals that were never meant to be shared.

An **interface module** contains only what other features may know:

```swift illustrative
// Sources/ReadingListInterface/ReadingListInterface.swift
public protocol ReadingSummaryProviding: Sendable {
    func summary() async -> String
}
```

The implementation lives in the feature:

```swift illustrative
// Sources/ReadingListFeature/ReadingListSummary.swift
import BookDomain
import ReadingListInterface

public struct ReadingListSummary: ReadingSummaryProviding {
    private let store: any BookStore

    public init(store: any BookStore) {
        self.store = store
    }

    public func summary() async -> String {
        let books = (try? await store.allBooks()) ?? []
        return "\(books.filter(\.isRead).count) of \(books.count) read"
    }
}
```

Profile depends only on the interface:

```swift illustrative
// Sources/ProfileFeature/ProfileViewModel.swift
import ReadingListInterface

@MainActor
public final class ProfileViewModel {
    private let readingSummary: any ReadingSummaryProviding
    public private(set) var subtitle = ""

    public init(readingSummary: any ReadingSummaryProviding) {
        self.readingSummary = readingSummary
    }

    public func load() async {
        subtitle = await readingSummary.summary()
    }
}
```

And the app, the only module that sees both, connects them in its composition root:

```swift illustrative
// App target
import BookStorage
import ProfileFeature
import ReadingListFeature

let store = InMemoryBookStore(books: [/* ... */])
let profile = ProfileViewModel(readingSummary: ReadingListSummary(store: store))
```

This is lesson 5's injection at module scale. The interface module is tiny and changes rarely, so it rarely triggers rebuilds. Profile's tests pass a fake `ReadingSummaryProviding` and never compile the reading list at all.

## Access control across modules

Inside one module you rarely think about access levels, because `internal`, the default, means "visible in this module". Across modules they're the whole story. From the package build:

| Declared as | Same target | Other target, same package | Other package |
| --- | --- | --- | --- |
| `private` / `fileprivate` | Same scope or file only | No | No |
| `internal` (default) | Yes | No | No |
| `package` | Yes | Yes | No |
| `public` | Yes | Yes | Yes (can't subclass or override) |
| `open` (classes, members) | Yes | Yes | Yes, including subclassing |

What the build reported when the rules were broken:

- The app target called an `internal` static function from `BookDomain`: `error: 'normalized' is inaccessible due to 'internal' protection level`.
- A separate package that depends on `BookDomain` called a `package` function: `error: 'debugDescription' is inaccessible due to 'package' protection level`. The same call from the app target, in the same package, compiled.
- A `public struct Shelf` with `public let` properties and no initializer was created from the app target: `error: 'Shelf' initializer is inaccessible due to 'internal' protection level`. **The implicit memberwise initializer is internal**, even for a public struct. Write a `public init` for every public type other modules create.
- `ReadingListSummary.summary()` without `public`: `error: method 'summary()' must be declared public because it matches a requirement in public protocol 'ReadingSummaryProviding'`.

Two more rules worth knowing:

- **Tests use `@testable import ReadingListFeature`** to reach `internal` members, so you don't make things `public` just to test them. It works in debug builds, which is what `swift test` and Xcode's test action use. (The package's test target called an internal method this way.)
- **`package` is the right default for helpers shared between your own targets.** A logging helper or a test-fixture builder used by three targets but not meant as API doesn't need to be `public`.

### Undeclared dependencies

One trap from the build: `ProfileFeature` got an `import BookDomain` without `BookDomain` in its `dependencies`. A full `swift build` **succeeded**, because `BookDomain` happened to be built already for other targets. Building that target alone (`swift build --target ProfileFeature`) failed with `error: no such module 'BookDomain'`. Passing `--explicit-target-dependency-import-check error` to `swift build` turns the full build into an error too: `Target ProfileFeature imports another target (BookDomain) in the package without declaring it a dependency.` Put that flag in CI, or the graph you drew and the graph you have will drift apart.

And a cycle (`BookDomain` depending on `ReadingListFeature`, which depends on `BookDomain`) is refused before anything compiles: `error: 'Bookshelf': cyclic dependency declaration found: App -> BookDomain -> ReadingListFeature -> BookDomain`.

## Build times and the shape of the graph

Two questions decide how fast a modular app builds:

1. **What recompiles after a change?** In the test package, editing the body of a function in `ReadingListFeature` recompiled only `ReadingListFeature` (and relinked the app). Adding a public protocol to `ReadingListInterface` recompiled `ReadingListInterface`, `ProfileFeature`, `ReadingListFeature` and `App`: everything that depends on it, directly or not. **Interface changes ripple to dependents; implementation changes mostly don't.** That's the case for small, stable interface and core modules, and big, frequently edited feature modules at the edges.
2. **What can build in parallel?** Modules that don't depend on each other compile at the same time. A wide, shallow graph uses all cores; a long chain of modules forces them to build one after another.

You can reason about both from the graph alone:

```swift
let dependencies: [String: [String]] = [
    "App": ["ReadingListFeature", "ProfileFeature", "BookStorage"],
    "ReadingListFeature": ["BookDomain", "ReadingListInterface", "DesignSystem"],
    "ProfileFeature": ["ReadingListInterface", "DesignSystem"],
    "BookStorage": ["BookDomain", "Networking"],
    "ReadingListInterface": [],
    "BookDomain": [],
    "Networking": [],
    "DesignSystem": [],
]

/// Modules grouped into rounds: each round only needs earlier rounds, so a round can build in parallel.
func buildRounds(_ graph: [String: [String]]) -> [[String]] {
    var built: Set<String> = []
    var rounds: [[String]] = []
    while built.count < graph.count {
        let ready = graph.keys
            .filter { !built.contains($0) && graph[$0]!.allSatisfy(built.contains) }
            .sorted()
        guard !ready.isEmpty else { return rounds + [["cycle!"]] }
        rounds.append(ready)
        built.formUnion(ready)
    }
    return rounds
}

/// The module itself plus everything that depends on it, directly or transitively:
/// what recompiles when its public interface changes.
func affected(byInterfaceChangeIn changed: String, in graph: [String: [String]]) -> [String] {
    var result: Set<String> = [changed]
    var grew = true
    while grew {
        grew = false
        for (module, deps) in graph where !result.contains(module) && deps.contains(where: result.contains) {
            result.insert(module)
            grew = true
        }
    }
    return result.sorted()
}

for (index, round) in buildRounds(dependencies).enumerated() {
    print("round \(index + 1): \(round.joined(separator: ", "))")
}
for module in ["ReadingListInterface", "BookDomain", "DesignSystem", "ProfileFeature"] {
    print("\(module) changes -> \(affected(byInterfaceChangeIn: module, in: dependencies).joined(separator: ", "))")
}
```

```output
round 1: BookDomain, DesignSystem, Networking, ReadingListInterface
round 2: BookStorage, ProfileFeature, ReadingListFeature
round 3: App
ReadingListInterface changes -> App, ProfileFeature, ReadingListFeature, ReadingListInterface
BookDomain changes -> App, BookDomain, BookStorage, ReadingListFeature
DesignSystem changes -> App, DesignSystem, ProfileFeature, ReadingListFeature
ProfileFeature changes -> App, ProfileFeature
```

- **Three rounds** for eight modules: the graph is shallow. The longest chain (core, feature, app) sets the minimum build time no matter how many cores you have.
- **A feature change** reaches only the app. That's the payoff of features not depending on each other.
- **`DesignSystem` changes** reach every feature. Shared UI modules are a common source of "everything rebuilds"; keep them stable, and keep things that change often out of them.

This model ignores file-level incremental compilation inside a module, which Swift also does, and Xcode's own scheduling. It's a way to see the shape, not a build-time prediction.

## Choosing an architecture

The module has built the same feature five ways. None is the right answer everywhere; each buys something specific:

| | Separates | Test style | Boilerplate | Fits best | Watch out for |
| --- | --- | --- | --- | --- | --- |
| **MVC** (with extractions) | Data source, model, child controllers out of the view controller | Model and display structs in plain Swift; the controller untested | Lowest | Small UIKit screens; existing MVC codebases | Rendering decisions creeping back into the controller |
| **MVVM** | Display state and inputs from the view | Compare state after inputs | Low | SwiftUI; new UIKit screens; screens that may move to SwiftUI | View model growing into a second massive controller |
| **MVP** | Presentation logic from a passive view | Compare calls on a fake view | Medium (view protocol per screen) | UIKit teams wanting the view's interface written down | Brittle call-order tests; awkward in SwiftUI |
| **Clean** (entities, use cases, gateways) | Business rules and actions from presentation and infrastructure | Entities and use cases with fake gateways | High | Rule-heavy domains, several entry points, large teams | Pass-through use cases; mapping everything twice |
| **Coordinators** | Navigation from screens | Fake navigator, compare the log | Medium | Flows with branches, deep links, reused screens | A coordinator that grows business logic |

Some things the table doesn't show:

- **They combine.** Coordinators are about navigation and pair with any of the others. A common, solid setup is MVVM for screens, coordinators (or SwiftUI navigation state) for flows, entities and gateways for the domain, and use cases only where there's orchestration.
- **Consistency beats local optimization** in a team, up to a point. One default pattern, with permission to go lighter for trivial screens and heavier for rule-dense ones, is easier to live with than every screen choosing.
- **You can move between them.** MVC with a good model becomes MVVM by changing what the model exposes. A view model whose logic grows becomes view model plus use cases. Start light and add structure when a test, a second entry point or a second developer needs it, as lesson 1 put it.

## Common mistakes

> [!error] Features importing features
> `import ReadingListFeature` in `ProfileFeature`. Now a reading list change recompiles Profile, Profile can use reading list internals, and a cycle is one import away. Depend on an interface module.

> [!error] A public struct without a public init
> Other modules can see the type and can't create it: `'Shelf' initializer is inaccessible due to 'internal' protection level`. Write the `public init`.

> [!error] Making everything public
> Marking internals `public` so tests or a sibling target can reach them turns them into API. Use `@testable import` for tests and `package` for sibling targets.

> [!error] Trusting a passing full build
> An undeclared target dependency can compile because the module happened to be built already. Use `--explicit-target-dependency-import-check error` in CI.

> [!error] A "Common" or "Utilities" module everything depends on
> It collects unrelated code, changes often, and every change rebuilds the app. Split it by purpose, keep the pieces stable, and question each thing that goes in.

> [!error] Modularizing before there's a reason
> Twelve modules for a two-screen app with one developer is the lesson 1 settings toggle at package scale. Start with one app target and folders; extract a module when build times, a second target or a team boundary asks for it.

## Exercises

````exercise
id: m32-l06-e1
type: comprehension
prompt: "In the lesson's graph, a developer adds a new public method to the ReadingSummaryProviding protocol in ReadingListInterface. Which modules recompile?"
choices:
  - text: "ReadingListInterface, ReadingListFeature, ProfileFeature and App."
    correct: true
    why: "A public interface change reaches every module that depends on it, directly or transitively."
  - text: "Only ReadingListInterface."
    correct: false
    why: "That's what happens for a change that doesn't touch the public interface."
  - text: "ReadingListInterface and ReadingListFeature, because only the feature implements the protocol."
    correct: false
    why: "ProfileFeature imports the interface too, and the app depends on both features."
  - text: "Every module in the package."
    correct: false
    why: "BookDomain, Networking, BookStorage and DesignSystem don't depend on the interface."
solution: |
  The interface changed, so its dependents recompile: both features import it, and the app depends on both features. `BookDomain`, `Networking`, `DesignSystem` and `BookStorage` are untouched. Also note that adding a requirement to a protocol breaks every conforming type that doesn't implement it, so `ReadingListFeature` must change too, or the new method needs a default implementation in a protocol extension. Interface modules should change rarely and deliberately for exactly this reason.
````

````exercise
id: m32-l06-e2
type: prediction
prompt: "The build-rounds function from the lesson, on a graph with a chain. What does the program print?"
code: |
  let graph: [String: [String]] = [
      "App": ["Checkout", "Catalog"],
      "Checkout": ["Payments", "Cart"],
      "Catalog": ["Cart"],
      "Cart": ["Core"],
      "Payments": ["Core"],
      "Core": [],
  ]

  func buildRounds(_ graph: [String: [String]]) -> [[String]] {
      var built: Set<String> = []
      var rounds: [[String]] = []
      while built.count < graph.count {
          let ready = graph.keys
              .filter { !built.contains($0) && graph[$0]!.allSatisfy(built.contains) }
              .sorted()
          guard !ready.isEmpty else { return rounds + [["cycle!"]] }
          rounds.append(ready)
          built.formUnion(ready)
      }
      return rounds
  }

  for round in buildRounds(graph) {
      print(round)
  }
  var withCycle = graph
  withCycle["Core"] = ["App"]
  print(buildRounds(withCycle))
output: |
  ["Core"]
  ["Cart", "Payments"]
  ["Catalog", "Checkout"]
  ["App"]
  [["cycle!"]]
solution: |
  - Round 1: only `Core` has no dependencies.
  - Round 2: `Cart` and `Payments` need only `Core`.
  - Round 3: `Catalog` needs `Cart`; `Checkout` needs `Payments` and `Cart`. Both are ready.
  - Round 4: `App`.
  - With `Core` depending on `App`, no module has all its dependencies built in the first round (everything leads back to `Core`, which waits on `App`), so the function reports a cycle immediately.

  ```output
  ["Core"]
  ["Cart", "Payments"]
  ["Catalog", "Checkout"]
  ["App"]
  [["cycle!"]]
  ```

  Four rounds for six modules: a deeper graph than the lesson's, because `Cart` sits between `Core` and the features. If `Catalog` and `Checkout` only needed `Core`, there'd be one round fewer. SwiftPM refuses the cyclic version before compiling anything.
````

````exercise
id: m32-l06-e3
type: solve
prompt: "Write an architecture lint for a module graph. Module names ending in \"Feature\" are features, names ending in \"Interface\" are interfaces, \"App\" is the app, and everything else is core. Write `violations(in graph: [String: [String]]) -> [String]` that reports, sorted: every feature that depends on another feature (\"ProfileFeature -> ReadingListFeature: features must not depend on features\"), every core or interface module that depends on a feature (\"... : core must not depend on features\"), and anything that depends on App. Run it on a graph with two violations and on the lesson's clean graph."
starter: |
  enum Kind {
      case app, feature, interface, core
  }

  func kind(of module: String) -> Kind {
      if module == "App" { return .app }
      if module.hasSuffix("Feature") { return .feature }
      if module.hasSuffix("Interface") { return .interface }
      return .core
  }

  // Write violations(in:) and run it.
rubric:
  - Classifies each module by name and checks each edge once.
  - Reports feature-to-feature edges, core- or interface-to-feature edges, and any edge to App.
  - Output is sorted so the lint is deterministic in CI.
  - The clean graph produces no violations.
solution: |
  ```swift
  enum Kind {
      case app, feature, interface, core
  }

  func kind(of module: String) -> Kind {
      if module == "App" { return .app }
      if module.hasSuffix("Feature") { return .feature }
      if module.hasSuffix("Interface") { return .interface }
      return .core
  }

  func violations(in graph: [String: [String]]) -> [String] {
      var found: [String] = []
      for (module, dependencies) in graph {
          for dependency in dependencies {
              let edge = "\(module) -> \(dependency)"
              switch (kind(of: module), kind(of: dependency)) {
              case (_, .app):
                  found.append("\(edge): nothing may depend on App")
              case (.feature, .feature):
                  found.append("\(edge): features must not depend on features")
              case (.core, .feature), (.interface, .feature):
                  found.append("\(edge): core must not depend on features")
              default:
                  break
              }
          }
      }
      return found.sorted()
  }

  let broken: [String: [String]] = [
      "App": ["ReadingListFeature", "ProfileFeature"],
      "ProfileFeature": ["ReadingListFeature", "DesignSystem"],
      "ReadingListFeature": ["BookDomain"],
      "BookDomain": ["ReadingListFeature"],
      "DesignSystem": [],
  ]

  let clean: [String: [String]] = [
      "App": ["ReadingListFeature", "ProfileFeature", "BookStorage"],
      "ReadingListFeature": ["BookDomain", "ReadingListInterface", "DesignSystem"],
      "ProfileFeature": ["ReadingListInterface", "DesignSystem"],
      "BookStorage": ["BookDomain", "Networking"],
      "ReadingListInterface": [],
      "BookDomain": [],
      "Networking": [],
      "DesignSystem": [],
  ]

  for line in violations(in: broken) {
      print(line)
  }
  print("clean graph: \(violations(in: clean).isEmpty ? "no violations" : "violations")")
  ```

  ```output
  BookDomain -> ReadingListFeature: core must not depend on features
  ProfileFeature -> ReadingListFeature: features must not depend on features
  clean graph: no violations
  ```

  Matching on the pair of kinds keeps the rules in one `switch`, and new rules are new cases. In a real project the graph comes from `swift package dump-package` (JSON with every target's dependencies), and a CI step fails when the list isn't empty. Sorting matters because dictionary order varies between runs. (The broken graph also has a cycle, `BookDomain` ↔ `ReadingListFeature`, which SwiftPM would reject before the lint even runs.)
````

````exercise
id: m32-l06-e4
type: fill-in
prompt: "BookDomain is a target in the Bookshelf package. The app target (same package) and a separate WidgetKit package both use it. Fill in the access levels so: the widget package can create Shelf values; makeFixtures() is usable by every target in Bookshelf but not by the widget package; normalized(_:) stays inside BookDomain; and BookDomainTests can still call normalized(_:)."
code: |
  [[1]] struct Shelf: Sendable {
      public let name: String
      public let bookIDs: [Int]

      [[2]] init(name: String, bookIDs: [Int]) {
          self.name = name
          self.bookIDs = bookIDs
      }
  }

  [[3]] func makeFixtures() -> [Shelf] {
      [Shelf(name: "Favorites", bookIDs: [1, 4])]
  }

  [[4]] func normalized(_ title: String) -> String {
      title.lowercased()
  }

  // In Tests/BookDomainTests/ShelfTests.swift:
  // [[5]] import BookDomain
blanks:
  - id: "1"
    answers: ["public"]
  - id: "2"
    answers: ["public"]
  - id: "3"
    answers: ["package"]
  - id: "4"
    answers: ["internal"]
  - id: "5"
    answers: ["@testable"]
solution: |
  `Shelf` and its initializer are `public`, because the widget is another package and the implicit memberwise initializer would be internal. `makeFixtures()` is `package`: every target in Bookshelf sees it, other packages don't. `normalized(_:)` is `internal` (writing nothing means the same), and the test target reaches it through `@testable import BookDomain`.
````

````exercise
id: m32-l06-e5
type: comprehension
multiple: true
prompt: "Which of these are good reasons to split an app into modules? Select all that apply."
choices:
  - text: "The app and a widget extension need to share the domain and storage code."
    correct: true
    why: "A shared package target is the clean way to compile the same code into several targets."
  - text: "Incremental builds take minutes because every change recompiles the whole app target."
    correct: true
    why: "Modules with stable interfaces limit what recompiles."
  - text: "Several teams keep editing each other's code by accident, and reviews can't tell what's API."
    correct: true
    why: "Module boundaries and access control make ownership and API explicit."
  - text: "It's a new one-screen app, and modules look professional."
    correct: false
    why: "No sharing, no build problem, no team boundary: all cost, no benefit yet."
  - text: "You want to stop the domain from importing UIKit by accident."
    correct: true
    why: "A domain module that doesn't depend on UIKit-using modules, built and tested on its own (even on macOS or Linux), makes that a build error."
solution: |
  Modules pay off for sharing code between targets, limiting recompilation, making ownership and API explicit, and enforcing dependency rules with the compiler. "It looks professional" isn't a reason; a one-screen app gets only the costs (Package.swift upkeep, `public` and explicit initializers everywhere). Note that a Swift package target can still import UIKit if it's built for iOS; to make "no UIKit in the domain" a hard rule, also test the domain target on macOS or Linux, where an `import UIKit` fails.
````

````exercise
id: m32-l06-e6
type: design
prompt: "Choose an architecture for each of these three screens in the same app, using the decision table, and say what you'd skip and why. (a) An About screen with the version number and three links. (b) A checkout flow: cart review, address, payment, confirmation, with branches for signed-out users and saved cards, reachable from a deep link. (c) A loan calculator with amortization rules, rounding requirements from the legal team, and the same calculation used by a widget."
rubric:
  - (a) is a plain view or view controller, maybe a small display struct; no view model protocol, use case or coordinator.
  - (b) uses a coordinator (or navigation state) for the flow and MVVM per screen; mentions deep links and branch tests with a fake navigator.
  - (c) puts the calculation in entities or a use case with thorough tests, shared with the widget through a module; the screen is MVVM over it.
  - Justifies each choice by what it protects (rules, navigation, nothing), not by consistency alone.
solution: |
  - **(a) About:** a view (SwiftUI) or a small view controller reading a struct with the version and URLs. Nothing to test beyond "the version string is formatted", which can be a function. No view model protocol, no presenter, no coordinator.
  - **(b) Checkout:** a coordinator, or a navigation-state model in SwiftUI, owns the flow: which step comes next, the signed-out branch, skipping payment entry for a saved card, rebuilding the stack from a deep link. Its decisions are tested with a fake navigator (Module 25). Each step is MVVM with injected services (cart, address validation, payments). Use cases only where steps orchestrate several services, such as placing the order.
  - **(c) Loan calculator:** the amortization and rounding rules are entities and a use case in a domain module with exhaustive tests, including the legal team's rounding cases. The widget links the same module. The screen is a thin view model that turns inputs into a request and results into display strings.

  The common thread: each screen gets the structure that protects what's valuable in it. Nothing in (a), navigation in (b), rules in (c).
````

## Summary

- Modules turn architecture into **compiler-checked boundaries**: a module sees only what it declares as a dependency, and only what that module makes visible. Swift packages reject cyclic dependencies.
- **Feature modules** over a few stable core modules usually beat layer modules: features change and build independently. Features talk through **interface modules**; only the app target depends on everything and wires it together.
- Access levels across modules: `internal` stays in the module, `package` is shared within the package, `public` is API, `open` allows subclassing. Public structs need an explicit `public init`; protocol requirements need `public` implementations; tests use `@testable import`.
- Verified with SwiftPM 6.3: an implementation change recompiles only that module; a public interface change recompiles every dependent. Undeclared target dependencies can slip through a full build, so enable the explicit import check in CI.
- No architecture wins everywhere. MVC, MVVM, MVP, Clean Architecture and coordinators each protect something different, and they combine. Choose per screen by what needs protecting, start light, and add structure when a test, a second entry point or a team needs it.
