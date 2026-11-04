---
id: m37-l01
title: When you need a view model (and when you don't)
description: "A SwiftUI view can hold its own logic, and often should. You see how far @State and computed properties go, pull a rule into a plain struct to test it without a view model, list the signs that a screen does need an @Observable model (async work, rules with states, state shared across screens), count what a view model per screen costs, and compare the MV and MVVM camps on their merits."
module: m37
order: 1
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m36-l06, m32-l03, m33-l05]
objectives:
  - Keep simple screens' logic in the view with @State and computed properties.
  - Test a rule by moving it into a value type, without adding a view model.
  - Recognize the signs that a screen needs an @Observable model.
  - Write a main-actor view model whose state is an enum and whose inputs guard against double submission.
  - Compare MV and MVVM fairly and pick per feature, not per project.
terms:
  - term: View model
    definition: "An object that holds one screen's presentation state and the inputs that change it, so the view only renders and forwards events. In SwiftUI, usually a @MainActor @Observable class owned by the screen in @State."
  - term: MV (Model-View)
    definition: "A SwiftUI style with no per-screen view model: views read @Observable models (stores, services, SwiftData queries) directly and keep view-specific state in @State. The name comes from the community, not from Apple."
  - term: Presentation logic
    definition: "Decisions about what the screen shows: which state to render, what a message says, whether a button is enabled. Distinct from domain logic (the rules of the business) and from layout."
  - term: Double submission
    definition: "The same action started twice because the user tapped again before the first request finished. A view model prevents it by checking and recording an in-flight state before its first await."
mastery:
  - Write a small screen with @State and computed properties and explain why it doesn't need a view model.
  - Extract a calculation from a view into a struct and check it with plain prints or #expect.
  - Name the signs that justify a view model and point at them in a given screen.
  - Build an @Observable view model with an enum status, a derived canSubmit and a guard against double taps, and test it with a fake service.
  - Argue both sides of MV vs MVVM and choose for a specific feature.
resources: [swiftui-managing-ui-state, observation, swiftui-migrating-to-observable, swift-mainactor, swift-testing-docs]
cards:
  - id: m37-l01-c1
    front: Does a SwiftUI screen need a view model by default?
    back: "No. @State plus computed properties covers screens whose logic is local, synchronous and easy to read. Add an @Observable model when there's async work, rules with several states worth testing, or state shared beyond the screen."
  - id: m37-l01-c2
    front: How do you test a rule without a view model?
    back: "Move the rule into a value type or a static function (a struct with inputs and computed outputs). The view calls it; tests call it directly. Testability needs the logic out of body, not necessarily a class."
  - id: m37-l01-c3
    front: How does a @MainActor view model prevent double submission?
    back: "It checks and sets an in-flight state (status = .applying) before the first await. Every call runs on the main actor, so a second tap sees the flag and returns. Derive canSubmit from that state and disable the button with it."
  - id: m37-l01-c4
    front: What does a view model per screen cost?
    back: "Another type per screen, an extra hop between view and data, duplicated state when it copies store data, and init/injection friction (State's default runs on every view init). Worth it when it buys testable presentation logic; not for a screen that only displays data."
  - id: m37-l01-c5
    front: MV vs MVVM in one line each?
    back: "MV: views read shared @Observable models and SwiftData directly; fewer layers, logic lives in models. MVVM: each complex screen gets a view model with display state and inputs; more types, but presentation logic is testable without UI. Most apps mix both."
---

## The idea in one sentence

**Keep a screen's logic in the view until it has a reason to leave**, and when it leaves, move it to the smallest thing that solves the problem: a struct for a rule, an `@Observable` model for state that changes over time.

> [!note] About this lesson's code
> The view models and rules are plain Swift with Observation, compiled and run with Swift 6.3. SwiftUI blocks are type-checked against the iOS 17 SDK in Swift 6 mode, not run. Quotes come from Apple's `State` page and "Managing model data in your app", read in November 2026.

## Where you are

Module 32 built the reading list three ways (MVC, MVVM, MVP) and Module 33 tested its view model. Module 36 gave you `@State`, `@Binding`, `@Observable`, the environment and the rule "store each fact once". This module puts those together into apps that load, page, search, persist and sync. The first question for every screen is the one people argue about most: does it get a view model?

## Logic in the view is fine

Here's a tip splitter. It has state (the bill, the tip percentage, the number of people), derived values (the tip, the share per person) and one rule (at least one person):

```swift ios
import SwiftUI

struct TipSplitView: View {
    @State private var billCents = 4_850
    @State private var tipPercent = 18
    @State private var people = 2

    private var tipCents: Int { billCents * tipPercent / 100 }
    private var perPersonCents: Int { (billCents + tipCents + people - 1) / people }

    var body: some View {
        Form {
            Stepper("Tip: \(tipPercent)%", value: $tipPercent, in: 0...30)
            Stepper("People: \(people)", value: $people, in: 1...12)
            LabeledContent("Each pays", value: Self.dollars(perPersonCents))
        }
    }

    private static func dollars(_ cents: Int) -> String {
        "$\(cents / 100).\(String(format: "%02d", cents % 100))"
    }
}
```

There's nothing here a view model would improve. The state is local to the screen and dies with it, the derived values are one-line computed properties (Module 36, lesson 6), the rule `1...12` lives in the stepper, and nothing is asynchronous. A view model would add a class, an owner, an initializer and a hop from `body` to the model, and the screen would read the same.

What you'd lose by keeping it here is a cheap test of the rounding: does each person pay enough to cover the bill? That's a fair reason to move the math. It isn't a reason to add a view model.

## Testable doesn't mean view model

Move the rule into a value type. The view keeps its `@State`; the struct holds the calculation:

```swift
struct TipSplit {
    var billCents: Int
    var tipPercent: Int
    var people: Int

    var tipCents: Int { billCents * tipPercent / 100 }
    var totalCents: Int { billCents + tipCents }

    /// Rounded up, so the shares always cover the total.
    var perPersonCents: Int { (totalCents + people - 1) / people }
    var overpaidCents: Int { perPersonCents * people - totalCents }
}

let dinner = TipSplit(billCents: 4_850, tipPercent: 18, people: 3)
print(dinner.tipCents, dinner.totalCents, dinner.perPersonCents, dinner.overpaidCents)

let alone = TipSplit(billCents: 1_000, tipPercent: 0, people: 1)
print(alone.perPersonCents, alone.overpaidCents)
```

```output
873 5723 1908 1
1000 0
```

Three people splitting $57.23 pay $19.08 each and leave one cent extra, which is what rounding up promises. The view now builds a `TipSplit` from its three `@State` values and reads `perPersonCents`. In a test target, the prints become `#expect(dinner.perPersonCents == 1908)`.

The point generalizes: **logic gets testable when it leaves `body`**, and the cheapest place to put it is a struct, an enum or a static function. A view model is the right tool for something else.

## Signs a screen needs a model

Add an `@Observable` model when one of these shows up:

1. **Async work with states.** The screen loads, submits or refreshes, so it has loading, success and failure states, plus cancellation. That's a small state machine, and its transitions are what you want to test.
2. **Rules that depend on those states.** "Disable Apply while a request is running." "Show the server's message for an expired code, a generic one for a network failure." Those decisions mix the state machine with business rules.
3. **State shared beyond the screen.** A cart read by the product page, the cart tab and a badge. That's a shared model in the environment (Module 36, lesson 3), not a per-screen view model, but it still takes logic out of views.
4. **A `body` you can't read.** When half of `body` is `if` statements deciding what to show, the decisions want a name and a home.

A promo code field hits the first two: it calls a service, it has four situations, and it must not submit twice.

```swift
import Observation

protocol PromoService: Sendable {
    /// Returns the discount percentage for a valid code.
    func redeem(_ code: String) async throws -> Int
}

enum PromoError: Error {
    case unknownCode, expired
}

@available(macOS 14, iOS 17, *)
@MainActor
@Observable
final class PromoCodeModel {
    enum Status: Equatable {
        case editing
        case applying
        case applied(percent: Int)
        case rejected(message: String)
    }

    var code = "" {
        didSet {
            if case .rejected = status { status = .editing }   // typing clears the error
        }
    }
    private(set) var status = Status.editing

    @ObservationIgnored private let service: any PromoService

    init(service: any PromoService) {
        self.service = service
    }

    private var normalizedCode: String {
        String(code.filter { !$0.isWhitespace }).uppercased()
    }

    var canApply: Bool {
        status != .applying && !normalizedCode.isEmpty
    }

    func apply() async {
        guard canApply else { return }
        status = .applying                       // recorded before the first await
        do {
            let percent = try await service.redeem(normalizedCode)
            status = .applied(percent: percent)
        } catch PromoError.expired {
            status = .rejected(message: "That code has expired.")
        } catch PromoError.unknownCode {
            status = .rejected(message: "We don't recognize that code.")
        } catch {
            status = .rejected(message: "Couldn't reach the store. Try again.")
        }
    }
}

// A fake service that counts requests.
actor FakePromoService: PromoService {
    private(set) var requests: [String] = []

    func redeem(_ code: String) throws -> Int {
        requests.append(code)
        switch code {
        case "SPRING20": return 20
        case "WINTER10": throw PromoError.expired
        default: throw PromoError.unknownCode
        }
    }
}

if #available(macOS 14, iOS 17, *) {
    let service = FakePromoService()
    let model = PromoCodeModel(service: service)
    print(model.canApply)

    model.code = "winter 10"
    await model.apply()
    print(model.status)

    model.code = "spring20"
    print(model.status, model.canApply)

    // Two taps before the first request finishes.
    let first = Task { await model.apply() }
    let second = Task { await model.apply() }
    _ = await (first.value, second.value)
    print(model.status)
    print(await service.requests)
}
```

```output
false
rejected(message: "That code has expired.")
editing true
applied(percent: 20)
["WINTER10", "SPRING20"]
```

What earns this its own type:

- **One `Status` enum** instead of `isLoading`, `errorMessage` and `discount` side by side. The screen is in exactly one situation, and a test compares it with `==`. Lesson 3 builds this into a reusable `LoadState`.
- **`canApply` is derived** from `status` and `code`, so the button's `disabled(!model.canApply)` can't disagree with the model.
- **The double-tap guard is two lines.** `apply()` checks `canApply` and sets `.applying` before its first `await`. Every call runs on the main actor, so the second tap finds `.applying` and returns. Two taps, one request, as the last line of output shows. (If the second task happened to run first, it would make the request and the first would return: still one request.)
- **Error mapping is presentation logic.** The service throws domain errors; the model decides the words. That's the decision you'd otherwise bury in `body`.
- **`didSet` works on an `@Observable` property.** Typing after a rejection clears the message, which is a rule, so it's in the model where a test can see it.

The view is now only layout:

```swift ios
import SwiftUI

protocol PromoService: Sendable {
    func redeem(_ code: String) async throws -> Int
}

@MainActor
@Observable
final class PromoCodeModel {
    enum Status: Equatable {
        case editing, applying
        case applied(percent: Int)
        case rejected(message: String)
    }

    var code = ""
    private(set) var status = Status.editing
    @ObservationIgnored private let service: any PromoService

    init(service: any PromoService) {
        self.service = service
    }

    var canApply: Bool { status != .applying && !code.isEmpty }

    func apply() async {
        guard canApply else { return }
        status = .applying
        do {
            status = .applied(percent: try await service.redeem(code))
        } catch {
            status = .rejected(message: "Couldn't apply that code.")
        }
    }
}

struct PromoCodeSection: View {
    @Bindable var model: PromoCodeModel

    var body: some View {
        Section("Promo code") {
            HStack {
                TextField("Code", text: $model.code)
                    .textInputAutocapitalization(.characters)
                Button("Apply") {
                    Task { await model.apply() }
                }
                .disabled(!model.canApply)
            }
            switch model.status {
            case .editing:
                EmptyView()
            case .applying:
                ProgressView()
            case .applied(let percent):
                Label("\(percent)% off", systemImage: "checkmark.circle")
            case .rejected(let message):
                Text(message).foregroundStyle(.red)
            }
        }
    }
}
```

(The model is repeated in a shorter form so this block type-checks on its own.) `@Bindable` gives `$model.code` (Module 36, lesson 2). The `switch` maps each status to a view and decides nothing.

## What a view model per screen costs

"Every screen gets a view model" is a rule some teams adopt for consistency. Know what it costs before you sign up:

- **More types and more indirection.** The detail screen that shows a book's title and author gets a `BookDetailViewModel` with a `title` and an `author`. Reading the screen now means reading two files.
- **Duplicated state.** A view model that copies data out of a shared store (`self.books = store.books`) has made a stale copy, the bug from Module 36, lesson 6. Either it reads through to the store with computed properties, or it owns the data outright.
- **Ownership and init friction.** A view model in `@State` is built in the view's initializer, and Apple's `State` page warns that "A `State` property always instantiates its default value when SwiftUI instantiates the view." Module 36, lesson 2 showed the fixes: keep the model's `init` cheap and load in `.task`, or have the parent create it and pass it in. Lesson 2 of this module adds dependencies to that.
- **The environment is out of reach.** A view model can't read `@Environment`. Anything from the environment has to be passed to it, by the view, at the right time.

None of that is a reason to avoid view models. It's a reason to add one when the screen gives you something to put in it.

## MV vs MVVM, fairly

Two camps, both with working apps behind them.

**MV ("model-view").** SwiftUI views are already lightweight descriptions bound to state, so a per-screen view model is a layer with nothing to do. Put the logic in models: `@Observable` stores and services shared through the environment, SwiftData models read with `@Query` (lesson 5), plain structs for rules. Views read the models and call their methods. Apple's own documentation leans this way: "Managing model data in your app" builds a `Library` model that views read and change directly, with no view model per screen.

```swift ios
import SwiftUI

@MainActor
@Observable
final class Library {
    private(set) var titles = ["Kindred", "Piranesi"]
    private(set) var favorites: Set<String> = []

    func toggleFavorite(_ title: String) {
        if favorites.contains(title) {
            favorites.remove(title)
        } else {
            favorites.insert(title)
        }
    }
}

struct LibraryList: View {
    @Environment(Library.self) private var library

    var body: some View {
        List(library.titles, id: \.self) { title in
            Button {
                library.toggleFavorite(title)
            } label: {
                Label(title, systemImage: library.favorites.contains(title) ? "heart.fill" : "heart")
            }
        }
    }
}

struct FavoritesBadge: View {
    @Environment(Library.self) private var library

    var body: some View {
        Text("\(library.favorites.count) favorites")
    }
}
```

Two screens, one model, no view models. Each view reads what it shows; the rule (toggling) is a model method a test can call.

**MVVM.** Each non-trivial screen has a view model with display state and inputs (Module 32, lesson 3). The view renders and forwards. Presentation logic (which state, what message, what's enabled) is tested without UI, and teams coming from UIKit already know the shape.

How they compare:

| | MV | MVVM |
| --- | --- | --- |
| Where presentation logic lives | In views, in small helper structs, or in shared models | In a view model per screen |
| Types per screen | Usually just the view | View plus view model |
| Testing | Models and rule structs tested directly; screen logic left in views is tested by UI or snapshot tests | View model tested directly, with fakes, including async states |
| Risk | Logic creeping back into `body`; shared models growing into god objects | Boilerplate view models; stale copies of store data |
| Fits best | Screens that mostly display and edit shared data | Screens with async flows, multi-step state and error handling |

The useful observation is that both camps agree on the hard part: **logic out of `body`, one source of truth, dependencies injected.** They differ on whether a screen-shaped object is the place for that logic. You don't have to pick once per project. The book detail screen reads the library directly; the checkout screen, with payment, promo codes and three kinds of failure, gets a view model. The rest of this module does exactly that.

> [!tip] A quick test
> Try to write the screen's test without a view: "given these inputs, after this event, the screen shows X." If X is something only the screen knows (a status, a message, whether a button is enabled), and the test needs fakes and `await`, give the screen a model. If X is a fact about shared data, test the shared model. If there's no test worth writing, keep it in the view.

## Common mistakes

> [!error] A view model that forwards properties
> `var title: String { book.title }` and nothing else. It adds a type and a hop and tests nothing. Pass the book to the view.

> [!error] Copying store data into a view model
> `init(store:) { books = store.books }` takes a snapshot that goes stale when another screen changes the store. Read through to the store (`var books: [Book] { store.books }`), or make the view model the owner of that data.

> [!error] Booleans instead of a status
> `isApplying`, `errorMessage` and `discount` allow combinations the screen can't show, like applying with an error. One enum makes each situation explicit and comparable.

> [!error] Setting the in-flight state after the await
> `let percent = try await service.redeem(code); isApplying = true` (or setting the flag inside a `Task` the method starts) leaves a window where a second tap passes the guard. Set it before the first suspension point.

> [!error] SwiftUI types in the view model
> A view model that returns `Color` or `Text` can't be tested without SwiftUI and ties presentation to one UI. Expose plain values (a status, a message, a `Bool`) and map them to views in `body`.

## Exercises

````exercise
id: m37-l01-e1
type: prediction
prompt: "A sign-up model checks whether a username is available. What does this print?"
code: |
  protocol UsernameChecker: Sendable {
      func isAvailable(_ name: String) async -> Bool
  }

  actor FakeChecker: UsernameChecker {
      private(set) var checked: [String] = []
      func isAvailable(_ name: String) -> Bool {
          checked.append(name)
          return name != "ana"
      }
  }

  @MainActor
  final class SignUpModel {
      enum Status: Equatable {
          case idle, checking, available, taken, tooShort
      }

      private(set) var status = Status.idle
      private let checker: any UsernameChecker

      init(checker: any UsernameChecker) {
          self.checker = checker
      }

      func check(_ name: String) async {
          guard name.count >= 3 else {
              status = .tooShort
              return
          }
          guard status != .checking else { return }
          status = .checking
          status = await checker.isAvailable(name.lowercased()) ? .available : .taken
      }
  }

  let checker = FakeChecker()
  let model = SignUpModel(checker: checker)
  await model.check("al")
  print(model.status)
  await model.check("Ana")
  print(model.status)
  let a = Task { await model.check("bruno") }
  let b = Task { await model.check("bruno") }
  _ = await (a.value, b.value)
  print(model.status, await checker.checked)
output: |
  tooShort
  taken
  available ["ana", "bruno"]
hints:
  - "\"al\" fails the length guard before any request."
  - "The name is lowercased before it reaches the checker."
  - "status is set to .checking before the await, so the second task returns early."
solution: |
  ```output
  tooShort
  taken
  available ["ana", "bruno"]
  ```

  "al" has two characters, so the model sets `.tooShort` and never calls the checker. "Ana" is lowercased to "ana", which the fake reports as taken. The two tasks for "bruno" both run on the main actor: whichever runs first sets `.checking` before awaiting the checker, and the other sees `.checking` and returns. So the checker recorded "ana" and one "bruno". The final status is `.available`.
````

````exercise
id: m37-l01-e2
type: comprehension
prompt: "Which of these screens most clearly needs its own view model?"
choices:
  - text: "An About screen that shows the app version and a link to the privacy policy."
    correct: false
    why: "Static display. A view with a couple of constants is enough."
  - text: "A color picker sheet that edits a theme color and returns it through a binding."
    correct: false
    why: "Local, synchronous editing. @State or a @Binding covers it."
  - text: "A password reset screen that sends a code, verifies it, lets the user resend after 30 seconds, and shows different messages for wrong, expired and rate-limited codes."
    correct: true
    why: "Async steps, a state machine (send, verify, resend cooldown) and error mapping: exactly what a testable model is for."
  - text: "A book row that shows a title, an author and a heart from the shared library model."
    correct: false
    why: "It reads a shared model. The logic belongs to that model, not to a per-row view model."
solution: |
  **The password reset screen.** It has asynchronous work (send and verify), several states with transitions between them (code sent, verifying, cooldown before resend), and rules that map server errors to messages. Those are the transitions you want to test with a fake service and no UI. The About screen and the color picker are local and synchronous; the row reads a shared model and adds nothing a view model would hold.
````

````exercise
id: m37-l01-e3
type: find-errors
prompt: "A teammate added a view model to the book detail screen. Which comments are fair?"
code: |
  import SwiftUI

  @MainActor
  @Observable
  final class BookDetailViewModel {
      var title: String
      var author: String
      var isFavorite: Bool
      var heartColor: Color { isFavorite ? .red : .gray }

      init(book: Book, library: Library) {
          title = book.title
          author = book.author
          isFavorite = library.favorites.contains(book.id)
      }
  }

  struct BookDetailView: View {
      @State private var viewModel: BookDetailViewModel

      init(book: Book, library: Library) {
          _viewModel = State(initialValue: BookDetailViewModel(book: book, library: library))
      }

      var body: some View {
          VStack {
              Text(viewModel.title)
              Text(viewModel.author)
              Image(systemName: "heart.fill").foregroundStyle(viewModel.heartColor)
          }
      }
  }
choices:
  - text: "isFavorite is a copy of library state; favoriting the book elsewhere won't update this screen."
    correct: true
    why: "The initializer takes a snapshot. The library is the source of truth."
  - text: "title and author are forwarded unchanged; the view could take the book directly."
    correct: true
    why: "The view model adds nothing for those properties."
  - text: "heartColor puts a SwiftUI type in the view model, which ties it to SwiftUI and makes tests import it."
    correct: true
    why: "Expose isFavorite and map it to a color in the view."
  - text: "The view model must be an ObservableObject to work with @State."
    correct: false
    why: "@Observable classes work with @State (Module 36, lesson 2)."
  - text: "Text views can't display properties of an @Observable class."
    correct: false
    why: "They can; reading the property in body tracks it."
rubric:
  - Flags the stale isFavorite copy.
  - Flags the pure forwarding of title and author.
  - Flags Color in the view model.
  - Rejects the ObservableObject and Text claims.
solution: |
  Three fair comments. **`isFavorite` is a stale copy**: it's read once in `init`, so the heart doesn't follow the library. **`title` and `author` are just forwarded**: the view could take the `Book` and read them. **`heartColor` is a SwiftUI `Color`** in what should be plain presentation state.

  The simpler design has no view model at all: `BookDetailView` takes the book, reads the `Library` from the environment, and computes `library.favorites.contains(book.id)` in `body`, which is tracked and always current. If the screen later grows async work (loading reviews, say), that's when a model earns its place.
````

````exercise
id: m37-l01-e4
type: solve
prompt: |
  A reading goal screen lets the user pick a yearly goal and shows progress. Put the rule in a struct, not a view model. Write `struct ReadingGoal` with `goal: Int` and `finished: Int`, and computed properties:

  - `percent`: whole percent of the goal reached, capped at 100 (a goal of 0 counts as 100);
  - `remaining`: books left, never negative;
  - `summary`: `"Goal reached"` when `remaining` is 0, otherwise `"<remaining> to go (<percent>%)"`.

  Then run:

  ```swift
  print(ReadingGoal(goal: 24, finished: 9).summary)
  print(ReadingGoal(goal: 12, finished: 12).summary)
  print(ReadingGoal(goal: 10, finished: 15).percent, ReadingGoal(goal: 10, finished: 15).remaining)
  print(ReadingGoal(goal: 0, finished: 0).summary)
  ```

  ```output
  15 to go (37%)
  Goal reached
  100 0
  Goal reached
  ```
starter: |
  struct ReadingGoal {
      var goal: Int
      var finished: Int
      // percent, remaining, summary
  }
hints:
  - "Integer division rounds down: 9 * 100 / 24 is 37."
  - "Handle goal == 0 before dividing."
  - "max(0, ...) and min(100, ...) do the capping."
rubric:
  - percent handles goal 0 and caps at 100.
  - remaining never goes below 0.
  - summary uses remaining and percent.
  - Output matches exactly.
solution: |
  ```swift
  struct ReadingGoal {
      var goal: Int
      var finished: Int

      var percent: Int {
          guard goal > 0 else { return 100 }
          return min(100, finished * 100 / goal)
      }

      var remaining: Int {
          max(0, goal - finished)
      }

      var summary: String {
          remaining == 0 ? "Goal reached" : "\(remaining) to go (\(percent)%)"
      }
  }

  print(ReadingGoal(goal: 24, finished: 9).summary)
  print(ReadingGoal(goal: 12, finished: 12).summary)
  print(ReadingGoal(goal: 10, finished: 15).percent, ReadingGoal(goal: 10, finished: 15).remaining)
  print(ReadingGoal(goal: 0, finished: 0).summary)
  ```

  ```output
  15 to go (37%)
  Goal reached
  100 0
  Goal reached
  ```

  The screen keeps `@State private var goal` and reads `finished` from wherever the books live; `body` builds `ReadingGoal(goal: goal, finished: finished)` and shows `summary` and a `ProgressView(value: Double(percent), total: 100)`. Every edge case (overshooting the goal, a goal of zero) is covered by a test of the struct, and there's no class, owner or initializer to manage.
````

````exercise
id: m37-l01-e5
type: design
prompt: "You're starting a recipe app with four screens: (1) a recipe list read from local storage, with a favorites filter; (2) recipe detail with a servings stepper; (3) a shopping list shared with a widget, where checking items off must survive relaunch; (4) an import screen that downloads a recipe from a URL, validates it, shows a preview and saves it, with errors for bad URLs, network failures and unsupported sites. For each screen say: view only, view plus a shared model, or a view model, and why."
rubric:
  - Recipe list reads persisted data directly (query or shared store) with filter state in @State; no per-screen view model needed.
  - Detail keeps servings in @State and derives scaled quantities, possibly with a helper struct.
  - Shopping list is a shared persisted model, not a per-screen view model.
  - Import gets a view model for its async multi-step flow and error mapping, tested with a fake downloader.
  - Justifies each choice with the signs from the lesson.
solution: |
  - **Recipe list: view plus shared data.** It displays persisted recipes (a SwiftData `@Query`, lesson 5, or a shared store) and holds a `@State var showsFavoritesOnly`. No async flow, no screen-specific rules worth a type.
  - **Detail: view only, with a helper struct.** `@State private var servings`; scaling quantities is a pure function or a `ScaledRecipe` struct you can test, like `TipSplit`.
  - **Shopping list: shared model.** Several places (the list screen, the widget) read and change it, and it must persist. That's a store or SwiftData model shared through the environment, not a view model owned by one screen.
  - **Import: view model.** Downloading, validating, previewing and saving is a state machine with async steps, cancellation and three kinds of failure mapped to messages. An `@Observable` `RecipeImportModel` with a status enum and an injected downloader is tested without UI, the way `PromoCodeModel` was.
````

````exercise
id: m37-l01-e6
type: explain
prompt: "Here's one screen written two ways. Looking at it, a teammate says: \"SwiftUI views are view models, so MVVM in SwiftUI is always wrong.\" Another says: \"Without a view model per screen, nothing is testable.\" Explain what each gets right and wrong."
code: |
  // Style A: the view reads a shared model.
  struct FavoritesView: View {
      @Environment(Library.self) private var library
      var body: some View {
          List(library.favoriteTitles, id: \.self) { Text($0) }
      }
  }

  // Style B: a view model per screen.
  @MainActor @Observable
  final class FavoritesViewModel {
      private let library: Library
      init(library: Library) { self.library = library }
      var titles: [String] { library.favoriteTitles }
  }

  struct FavoritesScreen: View {
      @State var viewModel: FavoritesViewModel
      var body: some View {
          List(viewModel.titles, id: \.self) { Text($0) }
      }
  }
rubric:
  - First claim gets right that views already bind state and many screens need no extra layer.
  - First claim misses that async flows and presentation rules are hard to test inside a View.
  - Second claim gets right that logic inside body is hard to test.
  - Second claim misses that structs, static functions and shared models are testable without per-screen view models.
  - Concludes with a per-feature choice.
solution: |
  The first teammate is right that a SwiftUI view is a light description bound to state, and that many screens (display, simple edits) need no extra layer: `@State`, computed properties and shared models cover them. They're wrong that it's *always* wrong: a screen with async steps, cancellation and error mapping has presentation logic you want to test with fakes and `await`, and a `View` struct is a poor place to test it.

  The second teammate is right that logic inside `body` is hard to test. They're wrong that a per-screen view model is the only fix: a rule in a struct (`TipSplit`), a static function, or a method on a shared `@Observable` model is just as testable, with less code.

  For this particular screen, style A wins: style B's view model only forwards `favoriteTitles`, so it adds a type and tests nothing that a test of `Library` doesn't already cover. Both teammates agree on what matters: logic out of `body`, one source of truth, injected dependencies. Choose per feature: a view model where the screen has its own state machine, none where it doesn't.
````

## Summary

- Simple screens keep their logic in the view: `@State` for local values, computed properties for derived ones.
- To test a rule, move it into a struct, an enum or a static function. A view model isn't required for testability.
- Add an `@Observable` model when the screen has async work with states, rules that depend on those states, state shared beyond it, or a `body` full of decisions.
- A good view model has one status enum, derived flags like `canApply`, error mapping, and in-flight guards set before the first `await`. It returns plain values, not SwiftUI types.
- A view model per screen costs types, indirection, possible stale copies and init friction. MV and MVVM agree on logic out of `body`; pick per feature.
