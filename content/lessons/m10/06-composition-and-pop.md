---
id: m10-l06
title: Composition and protocol-oriented design
description: You replace a brittle class hierarchy with small protocols and components, combine protocols with A & B, apply dependency inversion by depending on a protocol and injecting the concrete type, test with a fake, and build a notification sender with interchangeable channels that uses the whole module.
module: m10
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l05]
objectives:
  - Explain why a deep class hierarchy breaks when a type needs some but not all inherited behavior.
  - Model capabilities with small protocols and build types that adopt only the ones they need.
  - Build a type from components it holds (has-a) instead of a superclass (is-a).
  - Require several protocols at once with A & B.
  - Apply dependency inversion by injecting a protocol-typed dependency through an initializer.
  - Replace a real dependency with a fake to check behavior without side effects.
terms:
  - term: Composition
    definition: "Building a type out of other values it holds (has-a), or out of several small protocols it adopts, instead of inheriting from a superclass (is-a)."
  - term: Protocol composition
    definition: "A type written A & B that means 'conforms to both A and B'. Usable with some, any and typealias."
  - term: Protocol-oriented programming
    definition: "Designing around protocols and protocol extensions, with value types doing most of the work, instead of around class hierarchies."
  - term: Dependency inversion
    definition: "High-level code depends on an abstraction (a protocol) it defines, not on a concrete low-level type. The concrete type is plugged in from outside."
  - term: Dependency injection
    definition: "Passing a type's dependencies in, usually through its initializer, instead of letting it create them itself."
  - term: Fake
    definition: "A simple stand-in for a real dependency, written for tests. It conforms to the same protocol, records what was asked of it, and returns answers the test controls."
mastery:
  - Point at the method a subclass has to override with "do nothing" and say why that's a design smell.
  - Split a class hierarchy into two or three capability protocols and conform types to the right ones.
  - Write a function that takes some A & B and explain the error when an argument conforms to only one.
  - Refactor a type that creates its own dependency into one that receives a protocol-typed dependency in its init.
  - Write a fake that conforms to the same protocol and records calls, and use it to check one behavior.
  - Explain which parts of the notification program are structs, which is a class, and why.
resources: [swift-book-protocols, swift-book-extensions, swift-book-inheritance, swift-book-initialization]
cards:
  - id: m10-l06-c1
    front: "What's the warning sign that a subclass doesn't really fit its superclass?"
    back: "It overrides an inherited method to do nothing, return a dummy value or crash, like a Penguin whose fly() can't fly. Code using the superclass can no longer trust that method."
  - id: m10-l06-c2
    front: "What does some Named & Aged mean?"
    back: "One concrete type that conforms to both Named and Aged. Passing a type that conforms to only one is a compile error."
  - id: m10-l06-c3
    front: What's dependency inversion, in one line?
    back: "High-level code depends on a protocol it defines, and the concrete implementation is passed in from outside, usually through the initializer."
  - id: m10-l06-c4
    front: Why inject a dependency instead of creating it inside the type?
    back: "So you can swap it: a real payment gateway in the app, a fake that records calls in tests, a different provider later, all without changing the type that uses it."
  - id: m10-l06-c5
    front: "Why is a test fake often a class?"
    back: "The code under test and the test both hold a reference to the same fake, so the test can read what was recorded after the call. A struct would be copied."
---

## The idea in one sentence

Build behavior out of small pieces (protocols a type adopts and values it holds) instead of a tall class tree, and make code depend on protocols so the concrete pieces can be swapped.

## When inheritance doesn't fit

Start with a hierarchy that looks fine on day one:

```swift
class Bird {
    let name: String
    init(name: String) {
        self.name = name
    }
    func fly() -> String {
        "\(name) flies"
    }
}

class Sparrow: Bird {}

class Penguin: Bird {
    override func fly() -> String {
        "\(name) can't fly"
    }
}

func startMigration(_ birds: [Bird]) {
    for bird in birds {
        print(bird.fly())
    }
}

startMigration([Sparrow(name: "Sparrow"), Penguin(name: "Penguin")])
```

```output
Sparrow flies
Penguin can't fly
```

It compiles and runs, and it's wrong. `startMigration` was written against `Bird`, which promises `fly()`. `Penguin` is a `Bird` that breaks the promise, so the bug only shows up at run time, in the output. Every function that takes a `Bird` now has to wonder whether it really flies.

Then a duck arrives. It flies **and** swims. Penguins swim too. Where does `swim()` go? Put it in `Bird` and sparrows get it. Make a `SwimmingBird` subclass and the duck can't also inherit from the flying branch, because a class has only one superclass. The tree can't express "some of these, some of those".

> [!tip] The smell
> A subclass that overrides a method to do nothing, return a dummy value or crash doesn't really fit its superclass. Code that uses the superclass can't trust it anymore.

## Capabilities as protocols

Split the behavior into small protocols, one per capability, and let each type adopt what it actually has:

```swift
protocol Flyer {
    func fly() -> String
}

protocol Swimmer {
    func swim() -> String
}

struct Sparrow: Flyer {
    func fly() -> String { "Sparrow flies" }
}

struct Penguin: Swimmer {
    func swim() -> String { "Penguin swims" }
}

struct Duck: Flyer, Swimmer {
    func fly() -> String { "Duck flies" }
    func swim() -> String { "Duck paddles" }
}

func startMigration(_ flyers: [any Flyer]) {
    for flyer in flyers {
        print(flyer.fly())
    }
}

startMigration([Sparrow(), Duck()])
print(Penguin().swim())
```

```output
Sparrow flies
Duck flies
Penguin swims
```

Now the promise is checked by the compiler. A penguin isn't a `Flyer`, so it can't even be passed to code that needs flying:

```swift no-compile requires that 'Penguin' conform to 'Flyer'
protocol Flyer {
    func fly() -> String
}

struct Penguin {}

func launch(_ bird: some Flyer) -> String {
    bird.fly()
}

print(launch(Penguin()))
```

Swift 6.3 says `error: global function 'launch' requires that 'Penguin' conform to 'Flyer'`. The run-time surprise became a compile-time error. And these are structs: no shared mutable state, no initializer chains, no `final` to remember.

## Composition: has-a instead of is-a

The other half of composition is building a type out of **values it holds**. Instead of "an `ElectricCar` **is a** `Car` with a different engine", say "a `Car` **has an** engine", and make the engine a protocol:

```swift
protocol Engine {
    var kind: String { get }
    func range(forLevel level: Int) -> Int
}

struct Electric: Engine {
    let kind = "electric"
    func range(forLevel level: Int) -> Int {
        level * 4
    }
}

struct Petrol: Engine {
    let kind = "petrol"
    func range(forLevel level: Int) -> Int {
        level * 12
    }
}

struct Car {
    let model: String
    var engine: any Engine

    func describe(level: Int) -> String {
        "\(model) (\(engine.kind)): \(engine.range(forLevel: level)) km"
    }
}

var car = Car(model: "Compact", engine: Petrol())
print(car.describe(level: 40))
car.engine = Electric()
print(car.describe(level: 40))
```

```output
Compact (petrol): 480 km
Compact (electric): 160 km
```

`Car` doesn't care which engine it has, only that it has one that meets the `Engine` protocol. You can even swap it at run time, which a superclass can never do. That's why `engine` is `any Engine`: it holds different types over its life (lesson 5).

## Protocol composition: A & B

Sometimes a function needs a value with **several** capabilities. Write them joined with `&`:

```swift
protocol Named {
    var name: String { get }
}

protocol Reachable {
    var email: String { get }
}

struct Customer: Named, Reachable {
    let name: String
    let email: String
    let loyaltyPoints: Int
}

struct Supplier: Named, Reachable {
    let name: String
    let email: String
}

struct Visitor: Named {
    let name: String
}

func invitation(for person: some Named & Reachable) -> String {
    "To: \(person.email) | Dear \(person.name), you're invited."
}

print(invitation(for: Customer(name: "Ana", email: "ana@example.com", loyaltyPoints: 120)))
print(invitation(for: Supplier(name: "Beans Co.", email: "orders@beans.example")))

typealias Contact = Named & Reachable
let contacts: [any Contact] = [
    Customer(name: "Leo", email: "leo@example.com", loyaltyPoints: 0),
    Supplier(name: "Milk Ltd.", email: "hi@milk.example"),
]
for contact in contacts {
    print(contact.name, contact.email)
}
```

```output
To: ana@example.com | Dear Ana, you're invited.
To: orders@beans.example | Dear Beans Co., you're invited.
Leo leo@example.com
Milk Ltd. hi@milk.example
```

`some Named & Reachable` means one concrete type that conforms to **both**. `Visitor` only has a name, so `invitation(for: Visitor(name: "Sam"))` fails with "requires that 'Visitor' conform to 'Reachable'". A `typealias` gives a composition a name you can reuse, with `some` or `any`.

The function asks for exactly what it uses. It doesn't need a `Customer`, so it doesn't ask for one. That's what makes it reusable for suppliers.

A protocol can also build on another: `protocol Pet: Named { var owner: String { get } }` means every `Pet` must also be `Named`. Use that when one capability really implies the other; use `&` when they're independent.

## Dependency inversion

Here's a checkout that charges a card:

```swift illustrative
struct CheckoutService {
    let gateway = StripeGateway()

    func pay(cents: Int, card: String) -> String {
        gateway.charge(cents: cents, card: card) ? "Paid" : "Declined"
    }
}
```

(Marked illustrative because `StripeGateway` is imaginary.) It works, but `CheckoutService` creates its own gateway, a concrete type that talks to a real payment provider. You can't test the checkout without charging a card, and switching providers means editing the checkout.

**Dependency inversion** flips the arrow. The high-level code (the checkout) declares the protocol it needs; the low-level code (each gateway) conforms to it; and the concrete gateway is **passed in** from outside. Passing it in through the initializer is called **dependency injection**.

```swift
enum CheckoutResult {
    case paid(receipt: String)
    case declined
    case invalidAmount
}

protocol PaymentGateway {
    func charge(cents: Int, card: String) -> Bool
}

struct CheckoutService {
    let gateway: any PaymentGateway

    func pay(cents: Int, card: String) -> CheckoutResult {
        guard cents > 0 else {
            return .invalidAmount
        }
        if gateway.charge(cents: cents, card: card) {
            return .paid(receipt: "R-\(cents)")
        }
        return .declined
    }
}

struct CardNetworkGateway: PaymentGateway {
    func charge(cents: Int, card: String) -> Bool {
        print("Contacting the card network for \(cents) cents...")
        return !card.hasPrefix("0000")
    }
}

let checkout = CheckoutService(gateway: CardNetworkGateway())
switch checkout.pay(cents: 1999, card: "4242 4242") {
case .paid(let receipt):
    print("Paid, receipt \(receipt)")
case .declined:
    print("Declined")
case .invalidAmount:
    print("Invalid amount")
}
```

```output
Contacting the card network for 1999 cents...
Paid, receipt R-1999
```

`CheckoutService` now knows nothing about card networks. It knows `PaymentGateway`, a protocol with one method, and that's all it can call. The app decides which gateway to inject.

### Testing with a fake

The payoff: in a test, inject a **fake** that conforms to the same protocol, never touches the network, and records what it was asked to do.

```swift
protocol PaymentGateway {
    func charge(cents: Int, card: String) -> Bool
}

struct CheckoutService {
    let gateway: any PaymentGateway

    func pay(cents: Int, card: String) -> String {
        guard cents > 0 else {
            return "Invalid amount"
        }
        return gateway.charge(cents: cents, card: card) ? "Paid" : "Declined"
    }
}

final class FakeGateway: PaymentGateway {
    var approves = true
    private(set) var charges: [Int] = []

    func charge(cents: Int, card: String) -> Bool {
        charges.append(cents)
        return approves
    }
}

let fake = FakeGateway()
let checkout = CheckoutService(gateway: fake)

print(checkout.pay(cents: 500, card: "any"))
print(checkout.pay(cents: 0, card: "any"))
fake.approves = false
print(checkout.pay(cents: 300, card: "any"))
print("Charges sent: \(fake.charges)")
```

```output
Paid
Invalid amount
Declined
Charges sent: [500, 300]
```

Three behaviors checked in a few lines: an approved payment, an invalid amount that **never reaches the gateway** (the fake shows only 500 and 300), and a decline. The fake is a `final class` on purpose. The checkout and the test hold references to the **same** instance, so the test can change `approves` and read `charges` after the fact (lesson 1). A struct fake would be copied into the checkout, and the test would be looking at a different copy.

The testing module turns these prints into real test cases with Swift Testing's `#expect`. The design move is the one you made here: **depend on a protocol, inject the concrete type**.

## Putting it together: a notification sender

A program that uses the whole module: structs and a class, a protocol with a default implementation and an extension-only helper, access control, `any`, composition and injection.

Messages go out through channels (email, SMS, push). Each channel decides whether it can reach a recipient. The notifier tries its channels in order until one succeeds, and a shared log records every attempt.

```swift
struct Message {
    let recipient: String
    let text: String
}

protocol NotificationChannel {
    var name: String { get }
    func canReach(_ recipient: String) -> Bool
    func send(_ message: Message) -> Bool
}

extension NotificationChannel {
    func canReach(_ recipient: String) -> Bool {
        true
    }

    func preview(of message: Message) -> String {
        "[\(name)] \(message.recipient): \(message.text)"
    }
}

struct EmailChannel: NotificationChannel {
    let name = "email"

    func canReach(_ recipient: String) -> Bool {
        recipient.contains("@")
    }

    func send(_ message: Message) -> Bool {
        print(preview(of: message))
        return true
    }
}

struct SMSChannel: NotificationChannel {
    let name = "sms"
    let maxLength: Int

    func canReach(_ recipient: String) -> Bool {
        recipient.hasPrefix("+")
    }

    func send(_ message: Message) -> Bool {
        guard message.text.count <= maxLength else {
            return false
        }
        print(preview(of: message))
        return true
    }
}

struct PushChannel: NotificationChannel {
    let name = "push"
    let registeredDevices: Set<String>

    func canReach(_ recipient: String) -> Bool {
        registeredDevices.contains(recipient)
    }

    func send(_ message: Message) -> Bool {
        print(preview(of: message))
        return true
    }
}

final class DeliveryLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

struct Notifier {
    private let channels: [any NotificationChannel]
    private let log: DeliveryLog

    init(channels: [any NotificationChannel], log: DeliveryLog) {
        self.channels = channels
        self.log = log
    }

    func notify(_ message: Message) -> Bool {
        for channel in channels where channel.canReach(message.recipient) {
            if channel.send(message) {
                log.record("\(message.recipient): sent by \(channel.name)")
                return true
            }
            log.record("\(message.recipient): \(channel.name) failed")
        }
        log.record("\(message.recipient): undelivered")
        return false
    }
}

func printReport(_ log: DeliveryLog) {
    print("--- Log ---")
    for entry in log.entries {
        print(entry)
    }
}

let log = DeliveryLog()
let notifier = Notifier(
    channels: [
        PushChannel(registeredDevices: ["ana-phone"]),
        SMSChannel(maxLength: 20),
        EmailChannel(),
    ],
    log: log
)

let messages = [
    Message(recipient: "ana-phone", text: "Your order shipped"),
    Message(recipient: "+34600111222", text: "Code: 4821"),
    Message(recipient: "+34600111222", text: "Your order shipped and arrives Friday"),
    Message(recipient: "leo@example.com", text: "Weekly summary"),
    Message(recipient: "unknown", text: "Hello?"),
]

var delivered = 0
for message in messages where notifier.notify(message) {
    delivered += 1
}
print("Delivered \(delivered) of \(messages.count)")
printReport(log)
```

```output
[push] ana-phone: Your order shipped
[sms] +34600111222: Code: 4821
[email] leo@example.com: Weekly summary
Delivered 3 of 5
--- Log ---
ana-phone: sent by push
+34600111222: sent by sms
+34600111222: sms failed
+34600111222: undelivered
leo@example.com: sent by email
unknown: undelivered
```

Walk through the design decisions:

1. **`Message` is a struct.** It's plain data with no identity; copies are fine.
2. **`NotificationChannel` is a protocol** with three requirements. `canReach` has a default implementation in the extension (a channel that can reach anyone needs no code); `preview(of:)` is an extension-only helper, because no channel should change the format. That's the lesson 4 rule applied: customizable means requirement.
3. **The three channels are structs**, each adopting the protocol its own way. None inherits from another.
4. **`DeliveryLog` is a class**, because the program and the notifier must see the **same** log. The notifier writes to it; `printReport` reads it afterwards. `private(set)` means only `record` can change `entries`.
5. **`Notifier` depends only on the protocol.** Its channels and log are **injected** through the initializer and stored `private`. It never mentions `EmailChannel` or `SMSChannel`. Adding a WhatsApp channel means writing one new struct and adding it to the array.
6. **`[any NotificationChannel]`**, because the array mixes channel types (lesson 5).
7. Message 3 is too long for SMS and its recipient isn't reachable by push or email, so the log shows the SMS failure and then "undelivered". The notifier tries channels in order; the order of the array is the fallback policy.

### Checking the notifier with a fake channel

The same injection lets you check the fallback logic without sending anything:

```swift
struct Message {
    let recipient: String
    let text: String
}

protocol NotificationChannel {
    var name: String { get }
    func canReach(_ recipient: String) -> Bool
    func send(_ message: Message) -> Bool
}

extension NotificationChannel {
    func canReach(_ recipient: String) -> Bool {
        true
    }
}

final class FakeChannel: NotificationChannel {
    let name: String
    let succeeds: Bool
    private(set) var sent: [String] = []

    init(name: String, succeeds: Bool) {
        self.name = name
        self.succeeds = succeeds
    }

    func send(_ message: Message) -> Bool {
        sent.append(message.text)
        return succeeds
    }
}

final class DeliveryLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }
}

struct Notifier {
    private let channels: [any NotificationChannel]
    private let log: DeliveryLog

    init(channels: [any NotificationChannel], log: DeliveryLog) {
        self.channels = channels
        self.log = log
    }

    func notify(_ message: Message) -> Bool {
        for channel in channels where channel.canReach(message.recipient) {
            if channel.send(message) {
                log.record("\(message.recipient): sent by \(channel.name)")
                return true
            }
            log.record("\(message.recipient): \(channel.name) failed")
        }
        log.record("\(message.recipient): undelivered")
        return false
    }
}

let broken = FakeChannel(name: "primary", succeeds: false)
let backup = FakeChannel(name: "backup", succeeds: true)
let log = DeliveryLog()
let notifier = Notifier(channels: [broken, backup], log: log)

let result = notifier.notify(Message(recipient: "ana", text: "Hi"))
print("Result: \(result)")
print("Primary tried: \(broken.sent)")
print("Backup sent: \(backup.sent)")
print(log.entries)
```

```output
Result: true
Primary tried: ["Hi"]
Backup sent: ["Hi"]
["ana: primary failed", "ana: sent by backup"]
```

The fakes prove three things: the notifier tried the primary channel first, fell back to the backup when it failed, and logged both attempts. No email or SMS left the program. The fakes are classes so the check can read `sent` after the call, through the same references the notifier used.

## Common mistakes

> [!error] Overriding to do nothing
> A subclass that stubs out an inherited method (`fly()` returns "can't fly") is a sign the hierarchy is wrong. Split the behavior into protocols and adopt only the ones that fit.

> [!error] error: global function 'launch' requires that 'Penguin' conform to 'Flyer'
> Good: that's the compiler enforcing the capability. Pass a type that has it, or ask for less in the function's signature.

> [!error] Creating dependencies inside the type
> `let gateway = RealGateway()` inside a service makes it impossible to swap or test. Take the dependency in `init`, typed as a protocol.

> [!error] A struct fake whose records you can't see
> The service stores its own copy of a struct fake, so the test's copy never records anything. Make fakes that record calls `final class`es.

> [!error] One giant protocol
> A `protocol Animal` with `fly`, `swim`, `run` and `dig` brings the hierarchy problem back: penguins would have to stub `fly`. Keep protocols small and compose them with `&`.

````exercise
id: m10-l06-e1
type: comprehension
prompt: "Which design best fits a game where some characters can attack, some can heal, and a paladin can do both?"
choices:
  - text: "A base class Character with attack() and heal(), and subclasses that override the ones they can't do to do nothing."
    correct: false
    why: "That's the penguin problem. Code that calls heal() on a Character can't trust it."
  - text: "class Attacker and class Healer, and class Paladin inheriting from both."
    correct: false
    why: A Swift class can have only one superclass.
  - text: "protocol Attacker and protocol Healer, with Paladin conforming to both, and functions asking for some Attacker, some Healer or some Attacker & Healer."
    correct: true
    why: Each type adopts exactly the capabilities it has, and the compiler checks every call.
  - text: "One protocol Character with attack() and heal(), and a Bool canHeal property."
    correct: false
    why: "It moves the check to run time. Every caller has to remember to look at canHeal."
solution: |
  **Small capability protocols.** A warrior is `Attacker`, a cleric is `Healer`, a paladin is `Attacker, Healer`. A function that needs both writes `some Attacker & Healer`. Passing a warrior to `heal(ally:with:)` doesn't compile, which is exactly the check you want.
````

````exercise
id: m10-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  protocol Clock {
      func now() -> Int
  }

  struct SystemClock: Clock {
      func now() -> Int { 9 }
  }

  final class FixedClock: Clock {
      var hour: Int
      init(hour: Int) {
          self.hour = hour
      }
      func now() -> Int { hour }
  }

  struct Greeter {
      let clock: any Clock
      func greeting() -> String {
          clock.now() < 12 ? "Good morning" : "Good afternoon"
      }
  }

  let fixed = FixedClock(hour: 15)
  let greeters = [Greeter(clock: SystemClock()), Greeter(clock: fixed)]
  for greeter in greeters {
      print(greeter.greeting())
  }
  fixed.hour = 8
  print(greeters[1].greeting())
output: |
  Good morning
  Good afternoon
  Good morning
hints:
  - "SystemClock here always returns 9."
  - "greeters[1] holds a reference to fixed."
solution: |
  ```output
  Good morning
  Good afternoon
  Good morning
  ```

  The first greeter gets 9 from `SystemClock`, the second gets 15 from the fixed clock. Then the test-style move: change `fixed.hour`. `FixedClock` is a class, so `greeters[1]` holds a reference to the same instance and sees 8. Injecting a clock is a standard way to test time-dependent code, which otherwise gives different results depending on when you run it.
````

````exercise
id: m10-l06-e3
type: fill-in
prompt: |
  Complete the code so `badge(for:)` accepts only values that are both `Named` and `Ranked`, and the program prints `Ana #1`.
code: |
  protocol Named {
      var name: String { get }
  }
  protocol Ranked {
      var rank: Int { get }
  }

  struct Player: Named, Ranked {
      let name: String
      let rank: Int
  }

  func badge(for person: some Named [[1]] [[2]]) -> String {
      "\(person.name) #\(person.[[3]])"
  }

  print(badge(for: Player(name: "Ana", rank: 1)))
blanks:
  - id: "1"
    answers: ["&"]
  - id: "2"
    answers: ["Ranked"]
  - id: "3"
    answers: ["rank"]
solution: |
  ```swift
  protocol Named {
      var name: String { get }
  }
  protocol Ranked {
      var rank: Int { get }
  }

  struct Player: Named, Ranked {
      let name: String
      let rank: Int
  }

  func badge(for person: some Named & Ranked) -> String {
      "\(person.name) #\(person.rank)"
  }

  print(badge(for: Player(name: "Ana", rank: 1)))
  ```

  ```output
  Ana #1
  ```

  `some Named & Ranked` asks for one type with both capabilities. The function can use `name` and `rank` and nothing else, which is all it needs.
````

````exercise
id: m10-l06-e4
type: refactor
prompt: |
  `WeatherReport` creates its own data source, so it can't be tested without the real service. Refactor it with dependency inversion: introduce a protocol, inject the source through the initializer, and show it working with a fake that returns a fixed temperature. The fake should make the program print `Cold: 3°C` and `Warm: 24°C`.
code: |
  struct LiveWeatherService {
      func temperature(in city: String) -> Int {
          // calls a real web service
          0
      }
  }

  struct WeatherReport {
      let service = LiveWeatherService()

      func summary(for city: String) -> String {
          let celsius = service.temperature(in: city)
          return celsius < 10 ? "Cold: \(celsius)°C" : "Warm: \(celsius)°C"
      }
  }
rubric:
  - A protocol declares temperature(in:).
  - LiveWeatherService conforms to it.
  - WeatherReport stores the protocol type and receives it in its init.
  - A fake conforms and controls the temperature, and the output matches.
solution: |
  ```swift
  protocol TemperatureSource {
      func temperature(in city: String) -> Int
  }

  struct LiveWeatherService: TemperatureSource {
      func temperature(in city: String) -> Int {
          0
      }
  }

  struct WeatherReport {
      let source: any TemperatureSource

      func summary(for city: String) -> String {
          let celsius = source.temperature(in: city)
          return celsius < 10 ? "Cold: \(celsius)°C" : "Warm: \(celsius)°C"
      }
  }

  struct FakeTemperatureSource: TemperatureSource {
      let celsius: Int
      func temperature(in city: String) -> Int {
          celsius
      }
  }

  print(WeatherReport(source: FakeTemperatureSource(celsius: 3)).summary(for: "Oslo"))
  print(WeatherReport(source: FakeTemperatureSource(celsius: 24)).summary(for: "Seville"))
  ```

  ```output
  Cold: 3°C
  Warm: 24°C
  ```

  `WeatherReport` declares what it needs (`TemperatureSource`) and gets it from outside. The app passes `LiveWeatherService()`; checks pass a fake with whatever temperature they want, so both branches of `summary` can be exercised in milliseconds. This fake can be a struct because nothing needs to read back what it recorded; it only returns an answer.
````

````exercise
id: m10-l06-e5
type: solve
prompt: |
  Extend the notification idea. Write:

  - `protocol Channel` with `var name: String { get }` and `func send(_ text: String) -> Bool`,
  - `struct ConsoleChannel: Channel` that prints `"[console] " + text` and returns `true`,
  - `final class RecordingChannel: Channel` (a fake) with `let name: String`, an init that takes the name, and a `private(set) var messages: [String]` that `send` appends to before returning `true`,
  - `struct Broadcaster` that receives `[any Channel]` in its init and has `func broadcast(_ text: String) -> Int`, which sends the text through **every** channel and returns how many succeeded.

  This must print:

  ```output
  [console] Store opens at 9
  2
  ["Store opens at 9"]
  ```

  from:

  ```swift
  let recorder = RecordingChannel(name: "recorder")
  let broadcaster = Broadcaster(channels: [ConsoleChannel(), recorder])
  print(broadcaster.broadcast("Store opens at 9"))
  print(recorder.messages)
  ```
starter: |
  protocol Channel {
      // your code
  }
hints:
  - "ConsoleChannel can have let name = \"console\"."
  - "Broadcaster stores private let channels: [any Channel] and writes its own init, or relies on the memberwise one."
  - "In broadcast, loop over channels and count the ones where send returns true."
rubric:
  - Broadcaster depends only on the Channel protocol.
  - The channels are injected through the initializer.
  - RecordingChannel is a class, so the caller can read messages afterward.
  - The output matches exactly.
solution: |
  ```swift
  protocol Channel {
      var name: String { get }
      func send(_ text: String) -> Bool
  }

  struct ConsoleChannel: Channel {
      let name = "console"

      func send(_ text: String) -> Bool {
          print("[console] " + text)
          return true
      }
  }

  final class RecordingChannel: Channel {
      let name: String
      private(set) var messages: [String] = []

      init(name: String) {
          self.name = name
      }

      func send(_ text: String) -> Bool {
          messages.append(text)
          return true
      }
  }

  struct Broadcaster {
      private let channels: [any Channel]

      init(channels: [any Channel]) {
          self.channels = channels
      }

      func broadcast(_ text: String) -> Int {
          var succeeded = 0
          for channel in channels where channel.send(text) {
              succeeded += 1
          }
          return succeeded
      }
  }

  let recorder = RecordingChannel(name: "recorder")
  let broadcaster = Broadcaster(channels: [ConsoleChannel(), recorder])
  print(broadcaster.broadcast("Store opens at 9"))
  print(recorder.messages)
  ```

  ```output
  [console] Store opens at 9
  2
  ["Store opens at 9"]
  ```

  The console line prints first because it happens inside `broadcast`, before the count is returned and printed. `Broadcaster` never names a concrete channel. The `channels` property is `private`, so the explicit `init` is needed: a memberwise init for a private property would be private too. `RecordingChannel` is a class so `recorder` and the broadcaster's array refer to one instance and the last line can see what was recorded.
````

````exercise
id: m10-l06-e6
type: design
prompt: |
  A teammate proposes this for a photo app: `class MediaItem` with `upload()`, `applyFilter()` and `play()`; subclasses `Photo` (whose `play()` does nothing), `Video`, and `LivePhoto` (a photo that also plays). Uploading goes straight to `CloudServer.shared`. Propose a better design: name the protocols, say which types are structs or classes and why, and show how you'd test uploading without a network. A sketch of declarations is enough.
rubric:
  - Splits capabilities into small protocols such as Uploadable, Filterable and Playable, and LivePhoto adopts several.
  - Nothing has to override a method to do nothing.
  - Uses structs for the media values, and justifies any class.
  - Injects an uploader protocol instead of calling a shared server directly, and uses a fake that records uploads in tests.
solution: |
  ```swift
  protocol Filterable {
      func applyingFilter(_ name: String) -> Self
  }

  protocol Playable {
      var durationInSeconds: Int { get }
  }

  struct Photo: Filterable {
      let fileName: String
      var filters: [String] = []

      func applyingFilter(_ name: String) -> Photo {
          var copy = self
          copy.filters.append(name)
          return copy
      }
  }

  struct Video: Playable {
      let fileName: String
      let durationInSeconds: Int
  }

  struct LivePhoto: Filterable, Playable {
      let photo: Photo
      let durationInSeconds: Int

      func applyingFilter(_ name: String) -> LivePhoto {
          LivePhoto(photo: photo.applyingFilter(name), durationInSeconds: durationInSeconds)
      }
  }

  protocol Uploader {
      func upload(fileName: String) -> Bool
  }

  struct MediaLibrary {
      let uploader: any Uploader

      func upload(_ fileNames: [String]) -> Int {
          var uploaded = 0
          for name in fileNames where uploader.upload(fileName: name) {
              uploaded += 1
          }
          return uploaded
      }
  }

  final class FakeUploader: Uploader {
      private(set) var received: [String] = []

      func upload(fileName: String) -> Bool {
          received.append(fileName)
          return true
      }
  }

  let live = LivePhoto(photo: Photo(fileName: "beach.heic"), durationInSeconds: 3)
  let filtered = live.applyingFilter("mono")
  print(filtered.photo.filters, filtered.durationInSeconds)

  let fake = FakeUploader()
  let library = MediaLibrary(uploader: fake)
  print(library.upload(["beach.heic", "party.mov"]), fake.received)
  ```

  ```output
  ["mono"] 3
  2 ["beach.heic", "party.mov"]
  ```

  Each capability is its own protocol, and each type adopts only what it can do, so `Photo` has no `play()` to stub. `LivePhoto` **has** a photo (composition) and adds a duration, instead of inheriting from `Photo`. `Self` in `Filterable` means "the conforming type": filtering a photo gives a photo, filtering a live photo gives a live photo. The media types are structs, plain values with no shared identity. Uploading depends on an `Uploader` protocol injected into the library: the app passes a real network uploader, the check passes `FakeUploader`, a class so its record is visible afterward. No shared singleton is reachable from inside the types.
````

## Summary

- A subclass that has to stub out inherited behavior is a sign the hierarchy is wrong. One superclass can't express "some of these capabilities, some of those".
- Model capabilities as small protocols; each type adopts only what it has, and the compiler checks every use.
- Composition: a type holds components typed as protocols (has-a) and can even swap them at run time.
- `some A & B` and `any A & B` require several protocols at once; a `typealias` names the combination. Ask for exactly what a function uses.
- Dependency inversion: high-level code depends on a protocol; the concrete type is injected, usually through `init`.
- In tests, inject a fake that conforms to the same protocol. Make it a `final class` when the test must read what it recorded.
- Structs for data, a class where identity is shared (a log, a fake), protocols between the parts: that's protocol-oriented design in Swift.
