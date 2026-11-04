---
id: m47-l05
title: Architecture, testing and security questions
description: "Answer the judgment questions: defend an architecture choice with its context, alternatives, cost and the signal that would make you change it; make a hidden dependency injectable; show which test double would have caught a real bug; and build security answers on OWASP MASVS controls, with a deep-link validator and a privacy-safe analytics test you can run."
module: m47
order: 5
level: advanced
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l04]
objectives:
  - Defend an architecture decision with context, alternatives considered, the cost accepted and a trigger for revisiting it.
  - Turn a hidden dependency (the clock, a singleton) into an injected one, and say what a default argument costs.
  - Choose the test double that can catch a given bug, and show a stub that hides it.
  - "Structure a security answer as asset and threat, MASVS control, platform mechanism, what you don't rely on, and how you'd verify it."
  - Validate untrusted input from a deep link precisely, including Unicode digits.
terms:
  - term: Decision record
    definition: "A short written record of an architecture decision: the context, the decision, the alternatives considered and the consequences. Module 49 uses them on a team."
  - term: Seam
    definition: "A place where you can change what code does without editing it, usually a protocol or a function parameter. Dependency injection creates seams."
  - term: Revisit trigger
    definition: "A concrete signal that would make you change a decision: a team size, a number of features, a measured cost. It turns \"it depends\" into a testable statement."
  - term: Untrusted input
    definition: "Anything the app didn't produce itself: deep links, pasteboard contents, push payloads, server responses, files. MASVS-CODE-4 requires validating it."
mastery:
  - Give a two-minute defense of an architecture you'd choose for a described app, ending with what would make you change it.
  - Make a type that reads Date() testable, and write the deterministic check.
  - Show a passing test with a stub and a failing test with a spy for the same bug.
  - Answer a security question by naming the MASVS control and the iOS mechanism, without claiming the client can enforce what only the server can.
  - Write a validator that rejects non-ASCII digits and explain why isNumber isn't enough.
resources: [swift-character-isnumber, fowler-test-double, swift-testing-docs, owasp-masvs, owasp-mastg, security-keychain-accessibility, localauthentication, apple-platform-security]
cards:
  - id: m47-l05-c1
    front: What are the five parts of defending an architecture choice?
    back: "Context (team, constraints, what changes often), the decision, the alternatives you considered and why not, the cost you accepted, and the trigger that would make you revisit it."
  - id: m47-l05-c2
    front: Why can a stub let a bug through that a spy catches?
    back: "A stub returns canned answers whatever it's called with, so a test with it only checks how the code handles the answer. A spy records the calls, so the test can check what the code sent, such as an amount in dollars instead of cents."
  - id: m47-l05-c3
    front: How do you structure a security answer with MASVS?
    back: "Name the asset and threat, the MASVS control (STORAGE-1, AUTH-1, PLATFORM-1, CODE-4…), the iOS mechanism that meets it, what you don't rely on (client-side enforcement, obscurity), and how you'd verify it (the matching MASTG tests)."
  - id: m47-l05-c4
    front: Why isn't Character.isNumber enough to validate an account id?
    back: "It's true for digits in other scripts and for characters like ½. \"٣٤\" passes allSatisfy(\\.isNumber) but Int(\"٣٤\") is nil. Check isASCII as well, or parse with Int and compare."
  - id: m47-l05-c5
    front: "What's the cost of a default argument like `now: @escaping () -> Date = Date.init`?"
    back: "Production call sites stay short and tests can still inject a clock, but nothing forces a caller to think about the dependency, and a test that forgets to pass it silently uses the real clock."
---

## The idea in one sentence

Architecture, testing and security questions don't have one right answer, so the interviewer is grading your reasoning: what you traded for what, how you'd know you were wrong, and which standard or mechanism backs your choice.

> [!note] What this lesson builds on
> Module 32 (MVC, MVVM, MVP, Clean Architecture, dependency injection, modularization), Module 33 (Swift Testing, XCTest, test doubles, async tests), Module 30, lesson 6 (testable clients), Module 42 (threat modeling and OWASP MASVS v2, with the control texts quoted there). The bank covers MVVM's trade-offs, comparing patterns, DI, coordinators, testability, doubles, the test pyramid, token storage, pinning, MASVS and more. The Swift blocks here were compiled and run with Swift 6.3 on Linux. As in Module 33, tests are written as plain checks that print their result, because the course's snippet harness runs programs, not test suites; with Swift Testing each check would be an `#expect`.

## Defending an architecture choice

**The question:** "Walk me through the architecture of an app you'd build for a small team, and defend it."

"It depends" is true and useless. What the interviewer wants is the dependency spelled out. A five-part defense:

| Part | What you say |
| --- | --- |
| **Context** | The facts that drive the decision: team size, how long the app will live, which screens change most, the UI framework, what must be tested |
| **Decision** | The structure, in one sentence |
| **Alternatives** | One or two you considered, and the specific reason you didn't pick them |
| **Cost** | What you accepted in exchange: boilerplate, indirection, onboarding |
| **Revisit trigger** | The signal that would make you change it |

Here's that shape applied to a hypothetical app, a habit tracker built by three engineers:

> "**Context:** three engineers, SwiftUI, iOS 17 and later, a few screens that mostly read and write local data, and a sync service coming next year. The logic worth testing is streak calculation and sync conflicts.
>
> **Decision:** SwiftUI views with `@Observable` models for screens that have real logic, plain views for the rest, and a repository protocol in front of SwiftData so sync can slot in behind it.
>
> **Alternatives:** I didn't choose a view model for every screen, because most screens just display data. Module 37's rule fits better: keep logic in the view until it has a reason to leave, then move it to the smallest thing that solves the problem. I didn't choose a unidirectional framework like TCA: it's a good fit for complex state, but for three people it's another dependency and another way of thinking for little gain at this size.
>
> **Cost:** two patterns in the codebase, so we need a short written rule for when a screen gets a model. The repository adds a layer that does almost nothing until sync exists.
>
> **Revisit:** if more than a couple of screens grow side effects that interact (sync status, offline edits, undo), or the team doubles, I'd look at a more uniform pattern again."

Why it works: every claim can be challenged, and each challenge has an answer already in the defense. "Why a repository if it does nothing?" Because sync is coming and the seam is cheap now. "Why not MVVM everywhere?" Because consistency costs boilerplate on simple screens, and the rule is written down.

> [!tip] Where the course covers it
> Module 32, lesson 6 compared the patterns and their costs; Module 37, lesson 1 is "when you need a view model (and when you don't)"; Module 32, lesson 5 and Module 37, lesson 2 cover injection. Bank: the pattern comparison, the new app with a team of four, and the legacy codebase questions.

## Testability: the hidden dependency

**The question:** "This session check is flaky in tests. Why, and how do you fix it without a mocking framework?"

```swift
import Foundation

struct FlakySessionPolicy {
    let timeout: TimeInterval

    func isExpired(lastActivity: Date) -> Bool {
        Date().timeIntervalSince(lastActivity) >= timeout
    }
}

let policy = FlakySessionPolicy(timeout: 300)
print(policy.isExpired(lastActivity: Date()))
```

```output
false
```

**Direct answer.** "It reads the clock itself, so a test can't control time. A test at the 300-second boundary depends on how fast the machine is, and a test for '5 minutes later' has to wait 5 minutes. Inject the clock."

**Mechanism.** Every source of nondeterminism a function reads directly (`Date()`, `UUID()`, `URLSession.shared`, `UserDefaults.standard`) is a dependency you can't replace. Passing it in creates a seam: production passes the real one, tests pass a controlled one.

**Example.**

```swift
import Foundation

struct SessionPolicy {
    let timeout: TimeInterval
    let now: () -> Date

    init(timeout: TimeInterval, now: @escaping () -> Date = Date.init) {
        self.timeout = timeout
        self.now = now
    }

    func isExpired(lastActivity: Date) -> Bool {
        now().timeIntervalSince(lastActivity) >= timeout
    }
}

let start = Date(timeIntervalSince1970: 1_000)
var current = start
let policy = SessionPolicy(timeout: 300, now: { current })

current = start.addingTimeInterval(299)
print("after 299 s:", policy.isExpired(lastActivity: start))
current = start.addingTimeInterval(300)
print("after 300 s:", policy.isExpired(lastActivity: start))

let production = SessionPolicy(timeout: 300)
print("fresh session expired:", production.isExpired(lastActivity: Date()))
```

```output
after 299 s: false
after 300 s: true
fresh session expired: false
```

The boundary test is exact: 299 seconds isn't expired, 300 is. No waiting, no tolerance.

**Trade-off.** The default argument `= Date.init` keeps production call sites unchanged, which makes the refactor easy to land in a legacy codebase. The cost: nothing forces a caller to think about the clock, and a test that forgets to pass one silently uses real time. Some teams prefer no default in the domain layer and a single place (a composition root, Module 32, lesson 5) that passes the real clock. Swift's `Clock` protocol is the richer option when code also sleeps or measures durations.

**When it breaks.** Injection doesn't help if the dependency is reached some other way: a `static let shared` called deep inside, or a free function that calls `Date()`. Search for them before you claim a type is testable.

## Test doubles: which one catches the bug?

**The question:** "Checkout tests were green, and production charged customers 12 cents instead of $12.50. What kind of test double was the suite using, and what would have caught it?"

**Direct answer.** "Almost certainly a stub: it returned 'approved' whatever amount it was given, so the tests only checked how checkout handles an approval. A spy that records the amount, or a fake gateway that validates it, would have caught it."

**Example.** The bug and both doubles, in one program:

```swift
enum PaymentResult: Equatable {
    case approved
    case declined
}

protocol PaymentGateway {
    func charge(amountInCents: Int, cardToken: String) -> PaymentResult
}

struct Checkout {
    let gateway: any PaymentGateway

    func pay(totalInDollars: Double, cardToken: String) -> PaymentResult {
        gateway.charge(amountInCents: Int(totalInDollars), cardToken: cardToken)  // bug: forgot × 100
    }
}

struct ApprovingStub: PaymentGateway {
    func charge(amountInCents: Int, cardToken: String) -> PaymentResult { .approved }
}

final class GatewaySpy: PaymentGateway {
    private(set) var charges: [(amountInCents: Int, cardToken: String)] = []

    func charge(amountInCents: Int, cardToken: String) -> PaymentResult {
        charges.append((amountInCents, cardToken))
        return .approved
    }
}

let withStub = Checkout(gateway: ApprovingStub())
print("stub test passes:", withStub.pay(totalInDollars: 12.5, cardToken: "tok_1") == .approved)

let spy = GatewaySpy()
let withSpy = Checkout(gateway: spy)
_ = withSpy.pay(totalInDollars: 12.5, cardToken: "tok_1")
print("charged cents:", spy.charges.map(\.amountInCents))
print("spy test passes:", spy.charges.map(\.amountInCents) == [1250])
```

```output
stub test passes: true
charged cents: [12]
spy test passes: false
```

**Mechanism.** In Module 33, lesson 3's vocabulary (from Meszaros, via Fowler): a stub provides canned answers; a spy is a stub that also records how it was called. A test can only fail on what it observes. The stub test observes the return value; the spy test observes the outgoing call.

**Trade-off.** Spies couple the test to the interaction: rename a parameter or batch two calls into one and spy tests break even if the behavior is right. Use them where the outgoing call **is** the behavior (charging, logging, sending), and prefer checking returned values or state elsewhere. Module 33 called overdoing it over-mocking.

**When it breaks.** Doubles make tests pass against your assumptions about the dependency. If the real gateway expects cents and you believe it expects dollars, a spy written with the same belief agrees with the bug. That's what a contract or integration test against the real service (or its sandbox) is for, and why the bank's test pyramid question still has a top layer.

There's also a second bug here: `Double` for money. `Int(12.5 * 100)` happens to be 1250, but binary floating point can't represent most decimal fractions exactly, and a careless conversion truncates a cent. Bring it up if there's time; it's the kind of thing that shows you read code past the first problem.

## Security answers built on MASVS

Module 42 organized security around OWASP MASVS v2: eight control groups (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY), with MASWE weaknesses under each control and MASTG tests to verify them. That structure makes a strong answer shape:

1. **Asset and threat.** What's being protected, from whom.
2. **Control.** Which MASVS control the answer satisfies.
3. **Mechanism.** The iOS API or design that meets it.
4. **What you don't rely on.** Client-side enforcement, secrecy of the binary, a jailbreak check as the only defense.
5. **Verification.** How you'd check it: the MASTG tests for that weakness, a review, a test.

**The question:** "Product wants 'remember me for 30 days' in a banking app. How do you build it?"

> "**Asset and threat:** a long-lived credential on the device. The threats are someone reading it from a backup or another device, someone using an unlocked phone, and a stolen credential being used after the user signs out.
>
> **Controls and mechanisms:** the refresh token goes in the Keychain, not UserDefaults: that's MASVS-STORAGE-1, storing sensitive data securely. I'd use a `ThisDeviceOnly` accessibility class so it isn't restored onto another device, and `AfterFirstUnlock` only if background refresh needs it (Module 42, lesson 2). The 30 days are enforced by the server, which issues, expires and revokes the token: MASVS-AUTH-1 puts enforcement on the remote endpoint. For a transfer I'd ask for authentication again (MASVS-AUTH-3); if that's biometric, the Keychain item is protected with an access control flag, so the token itself can't be read without Face ID, rather than trusting a Boolean from `evaluatePolicy` (MASVS-AUTH-2).
>
> **Not relied on:** a local timestamp saying 'remember until', which anyone with a debugger can change.
>
> **Verification:** the MASTG tests for sensitive data in local storage and in logs, and a server test that a revoked token stops working."

Every sentence there points to Module 42's material; the bank's token-storage, biometrics and client-trust questions are the first-level versions.

### Untrusted input: a deep link, precisely

**The question:** "Your app handles `bankapp://transfer?to=981&amount=5000`. What do you do with it?"

**Direct answer.** "Treat it as untrusted input from another app: parse it, validate every parameter against an allowlist, and at most open a confirmation screen with the values filled in. A link never performs the transfer."

**Mechanism.** A custom URL scheme can be opened by any app or web page, so its contents are attacker-controlled. Module 42, lesson 6 mapped this to MASVS-PLATFORM-1 (IPC used securely) and MASVS-CODE-4 ("The app validates and sanitizes all untrusted inputs").

**Example.**

```swift
import Foundation

enum Route: Equatable {
    case account(id: String)
    case confirmTransfer(toAccount: String, amountInCents: Int)
    case rejected(String)
}

func isAccountID(_ text: String) -> Bool {
    (1...12).contains(text.count) && text.allSatisfy { $0.isASCII && $0.isNumber }
}

func route(for link: String) -> Route {
    guard let components = URLComponents(string: link), components.scheme == "bankapp" else {
        return .rejected("unknown scheme")
    }
    var query: [String: String] = [:]
    for item in components.queryItems ?? [] where query[item.name] == nil {
        query[item.name] = item.value ?? ""
    }
    switch components.host {
    case "account":
        guard let id = query["id"], isAccountID(id) else { return .rejected("bad account id") }
        return .account(id: id)
    case "transfer":
        guard let to = query["to"], isAccountID(to),
              let amount = Int(query["amount"] ?? ""), (1...1_000_000).contains(amount) else {
            return .rejected("bad transfer parameters")
        }
        return .confirmTransfer(toAccount: to, amountInCents: amount)
    default:
        return .rejected("unknown host")
    }
}

let links = [
    "bankapp://account?id=42",
    "bankapp://transfer?to=981&amount=5000",
    "bankapp://transfer?to=981&amount=-5",
    "bankapp://account?id=42%27%20OR%201=1",
    "bankapp://account?id=%D9%A3%D9%A4",
    "https://evil.example/account?id=42",
]
for link in links {
    print(route(for: link))
}
```

```output
account(id: "42")
confirmTransfer(toAccount: "981", amountInCents: 5000)
rejected("bad transfer parameters")
rejected("bad account id")
rejected("bad account id")
rejected("unknown scheme")
```

- The only transfer route is `confirmTransfer`: a screen that shows the values and requires the user (and re-authentication) to proceed.
- If a parameter appears twice, the first value wins. Pick a rule and make it explicit; ambiguity between what you validate and what you use is a classic bug.
- The amount has a range, not just a type.
- The fifth link carries `٣٤`, Arabic-Indic digits, percent-encoded.

**When it breaks.** That fifth link is why `isAccountID` checks `isASCII`. `Character.isNumber` is a Unicode property, and it's true for digits in other scripts:

```swift
let id = "٣٤"
print(id.allSatisfy(\.isNumber))
print(id.allSatisfy { $0.isASCII && $0.isNumber })
print(Int(id) as Any)
```

```output
true
false
nil
```

A validator using only `isNumber` accepts a string that `Int` can't parse, and that the server may treat in yet another way. Validation and use have to agree on exactly what's allowed. The more precise version of this answer says "ASCII digits only, length 1 to 12", which is a statement anyone can test.

## Common mistakes

> [!error] Defending the pattern instead of the decision
> "MVVM is best practice" isn't a defense. Say what about this app made it the right choice, and what would make it the wrong one.

> [!error] "We mock everything"
> Doubles for every dependency make tests that pass against your assumptions. Say which interactions you verify with spies, what you check through state, and where an integration test covers the real thing.

> [!error] Security answers that end at the client
> Anything enforced only in the app can be bypassed by someone who controls the device. Name what the server enforces, and say the client's checks are for usability.

> [!error] Citing a standard you can't map to a mechanism
> "We follow MASVS" means nothing without a control and the API that meets it. Name one or two specifically rather than the whole list.

## Exercises

````exercise
id: m47-l05-e1
type: prediction
prompt: "A stub and a spy test the same discount code. What does the program print?"
code: |
  protocol PriceService {
      func applyDiscount(percent: Int, toCents: Int) -> Int
  }

  struct HalfPriceStub: PriceService {
      func applyDiscount(percent: Int, toCents: Int) -> Int { toCents / 2 }
  }

  final class PriceSpy: PriceService {
      private(set) var percents: [Int] = []
      func applyDiscount(percent: Int, toCents: Int) -> Int {
          percents.append(percent)
          return toCents - toCents * percent / 100
      }
  }

  struct Cart {
      let service: any PriceService
      func totalWithCoupon(_ cents: Int) -> Int {
          service.applyDiscount(percent: 5, toCents: cents)   // coupon is 50%
      }
  }

  print(Cart(service: HalfPriceStub()).totalWithCoupon(1_000))
  let spy = PriceSpy()
  print(Cart(service: spy).totalWithCoupon(1_000), spy.percents)
output: |
  500
  950 [5]
solution: |
  The stub ignores `percent` and halves the price, so the cart looks right: 500. The spy computes with the percent it receives and records it: 1,000 − 1,000 × 5 / 100 = 950, and the recorded call shows the 5 that should have been 50.

  ```output
  500
  950 [5]
  ```

  A test using the stub passes and hides the typo; a test that checks `spy.percents == [50]` catches it.
````

````exercise
id: m47-l05-e2
type: comprehension
prompt: "Which closing sentence best finishes a defense of \"one view model per screen, injected repositories, no third-party architecture framework\"?"
choices:
  - text: "\"This is what most professional teams do, so it's the safe choice.\""
    correct: false
    why: "An appeal to popularity, and an unverifiable claim. It says nothing about this app."
  - text: "\"It's the cleanest architecture, so we'd never need to change it.\""
    correct: false
    why: "No architecture is final, and \"cleanest\" has no condition."
  - text: "\"If we end up with several screens sharing complex state, like an editor with undo and live sync, I'd revisit a unidirectional store for those features.\""
    correct: true
    why: "A concrete revisit trigger, scoped to where the alternative would pay off."
  - text: "\"Architecture doesn't matter much as long as the code is tested.\""
    correct: false
    why: "Dismisses the question. Testability is one of the things architecture decides."
solution: |
  A defense ends with what would change your mind. The third option names a specific signal and limits the change to the features that need it, which shows you know the alternative's strengths.
````

````exercise
id: m47-l05-e3
type: find-errors
prompt: "A candidate answers \"How do you store and protect a user's session in a banking app?\" Which statements are problems?"
code: |
  "I store the session token in the Keychain (1), and the
  token's expiry time in UserDefaults so the app can log the
  user out after 15 minutes of inactivity; that's what enforces
  the session timeout (2). For extra safety, transfers require
  Face ID: if evaluatePolicy succeeds, we call the transfer
  endpoint (3). I don't log the token (4), and we detect
  jailbreaks, which makes the stored token safe (5)."
choices:
  - text: "(1) The Keychain is the right place for the token."
    correct: false
    why: "Correct, and maps to MASVS-STORAGE-1."
  - text: "(2) A client-side timestamp can't enforce the timeout; the server must expire the session (MASVS-AUTH-1). The local timer is only for usability."
    correct: true
    why: "Anyone controlling the device can change the stored time or skip the check."
  - text: "(3) Trusting a Boolean from evaluatePolicy can be bypassed; tie the sensitive operation to a Keychain item protected with an access control flag, and have the server require step-up authentication."
    correct: true
    why: "MASVS-AUTH-2 and AUTH-3; Module 42, lesson 2 and the bank's biometrics question."
  - text: "(4) Keeping tokens out of logs is right (MASVS-STORAGE-2)."
    correct: false
    why: "Correct."
  - text: "(5) Jailbreak detection doesn't make anything safe on its own; it's a resilience measure that a determined attacker can bypass."
    correct: true
    why: "MASVS-RESILIENCE controls raise the cost of attacks; they don't replace storage and server-side controls."
rubric:
  - Flags the client-side timeout as enforcement.
  - Flags the Boolean biometric check.
  - Flags jailbreak detection as a guarantee.
  - Accepts the Keychain and the logging statements.
solution: |
  (2), (3) and (5) are the problems; all three put trust in the client. The fixed answer: Keychain for the token, the server expires and revokes sessions, transfers need a server-checked step-up whose biometric part unlocks a Keychain item rather than returning `true`, tokens never reach logs, and jailbreak detection, if used, only adds friction.
````

````exercise
id: m47-l05-e4
type: solve
prompt: "Write a spy for `AnalyticsSink` and use it to check that `SignInViewModel.signInFailed(email:reason:)` logs a `sign_in_failed` event that contains the reason and the email's domain, but not the email itself (MASVS-STORAGE-2 and MASVS-PRIVACY). Print the event names, whether any logged value contains the email, and the sorted property keys."
starter: |
  protocol AnalyticsSink {
      func log(_ event: String, properties: [String: String])
  }

  struct SignInViewModel {
      let analytics: any AnalyticsSink

      func signInFailed(email: String, reason: String) {
          let domain = email.split(separator: "@").last.map(String.init) ?? "unknown"
          analytics.log("sign_in_failed", properties: ["reason": reason, "email_domain": domain])
      }
  }
rubric:
  - The spy records every call's name and properties.
  - The check looks at what was sent, not at a return value.
  - It checks for the absence of the full email in every logged value.
  - The output is deterministic (sorted keys, not dictionary order).
solution: |
  ```swift
  protocol AnalyticsSink {
      func log(_ event: String, properties: [String: String])
  }

  final class AnalyticsSpy: AnalyticsSink {
      private(set) var events: [(name: String, properties: [String: String])] = []

      func log(_ event: String, properties: [String: String]) {
          events.append((event, properties))
      }
  }

  struct SignInViewModel {
      let analytics: any AnalyticsSink

      func signInFailed(email: String, reason: String) {
          let domain = email.split(separator: "@").last.map(String.init) ?? "unknown"
          analytics.log("sign_in_failed", properties: ["reason": reason, "email_domain": domain])
      }
  }

  let spy = AnalyticsSpy()
  let viewModel = SignInViewModel(analytics: spy)
  viewModel.signInFailed(email: "ada@example.com", reason: "wrong_password")

  let loggedValues = spy.events.flatMap { $0.properties.values }
  print("events:", spy.events.map(\.name))
  print("contains the email:", loggedValues.contains { $0.contains("ada@") })
  print("properties:", spy.events[0].properties.keys.sorted())
  ```

  ```output
  events: ["sign_in_failed"]
  contains the email: false
  properties: ["email_domain", "reason"]
  ```

  This is a spy used well: the outgoing call is the behavior under test. Sorting the keys keeps the output stable, because a dictionary's iteration order isn't specified. Whether even the domain is acceptable is a privacy decision for the team; the test makes that decision explicit.
````

````exercise
id: m47-l05-e5
type: design
prompt: "Defend an architecture for this app in the five-part shape (context, decision, alternatives, cost, revisit trigger): a UIKit app, eight years old, 60 screens, mostly massive view controllers, two engineers, and a request to add a new checkout flow while improving test coverage."
rubric:
  - Context names the constraints that matter (legacy UIKit, team size, feature work can't stop).
  - "The decision is incremental: new code (the checkout flow) gets a testable structure (for example MVVM or MVP with injected services, plus a coordinator), and legacy screens are changed only when touched."
  - Alternatives include a full rewrite or a big-bang migration, rejected for specific reasons.
  - "Cost: two styles coexist; seams (protocols) must be added around legacy singletons."
  - Revisit trigger is concrete (for example, once most active screens are migrated, or if a framework migration such as SwiftUI becomes the goal).
  - References the bank's legacy question or Modules 32 and 40.
solution: |
  - **Context:** a large UIKit codebase that works, two engineers, a feature to ship, and little test coverage. Feature work can't stop.
  - **Decision:** build checkout with a coordinator for its flow and a view model or presenter per screen, with services injected through protocols so the logic is testable. Wrap the legacy singletons it needs (session, network) in protocols at the boundary. Don't touch other screens unless a change takes us there anyway; then extract logic from that controller as part of the change.
  - **Alternatives:** a rewrite (months without features and a second app to keep in sync), or migrating all 60 screens to one pattern first (same problem, smaller). Moving checkout to SwiftUI is possible with a hosting controller (Module 40), but only if the team wants to learn it now; it's a separate decision.
  - **Cost:** two styles coexist for a long time, and new engineers need a written rule. Protocol seams around singletons add some indirection.
  - **Revisit:** when the screens people change most are migrated, decide whether to finish the rest; if crash or bug reports concentrate in legacy screens, move those up the list.

  The bank's legacy codebase question covers the same ground from the "how do you improve it" side.
````

````exercise
id: m47-l05-e6
type: explain
prompt: "A colleague validates a quantity field with this check and says it's \"numbers only\". Explain what it actually accepts, what goes wrong later, and the fix."
code: |
  func isValidQuantity(_ text: String) -> Bool {
      !text.isEmpty && text.allSatisfy(\.isNumber)
  }
rubric:
  - "Explains that isNumber is a Unicode property, true for digits in other scripts and for characters like ½ or Roman numerals."
  - "Says what goes wrong: Int(text) returns nil, or another system interprets the text differently, so validation and use disagree."
  - "Fixes it by checking isASCII (or isWholeNumber plus ASCII), or better, by parsing with Int and validating the range."
  - Mentions that no length or range limit is checked.
solution: |
  `Character.isNumber` is true for any character Unicode considers numeric: Arabic-Indic digits like `٣`, fractions like `½`, Roman numeral characters. So the check accepts strings that `Int(_:)` can't parse, and the code that uses the value either crashes on a force unwrap, silently treats it as zero, or sends something the server parses differently. It also has no length limit, so a 400-digit string passes.

  Validate what you'll use: parse, then check the range.

  ```swift
  func quantity(from text: String) -> Int? {
      guard text.count <= 3, text.allSatisfy({ $0.isASCII && $0.isNumber }),
            let value = Int(text), (1...100).contains(value) else {
          return nil
      }
      return value
  }

  for input in ["3", "٣", "½", "0", "250", ""] {
      print(input.isEmpty ? "(empty)" : input, quantity(from: input) as Any)
  }
  ```

  ```output
  3 Optional(3)
  ٣ nil
  ½ nil
  0 nil
  250 nil
  (empty) nil
  ```
````

## Summary

- Defend an architecture with context, decision, alternatives, cost and a revisit trigger. The trigger is what turns "it depends" into an answer.
- A type that reads `Date()`, a singleton or the network directly isn't testable; inject the dependency. A default argument eases adoption but lets tests forget to pass one.
- A stub can only reveal how code handles answers; a spy reveals what it sends. Pick the double that observes the bug you care about, and back doubles with contract or integration tests.
- Build security answers on MASVS: asset and threat, control, iOS mechanism, what you don't rely on, verification. The server enforces; the client helps.
- Deep links are untrusted input (MASVS-PLATFORM-1, CODE-4): validate every parameter precisely and only ever route to a confirmation. `isNumber` accepts non-ASCII digits; check ASCII or parse and range-check.
