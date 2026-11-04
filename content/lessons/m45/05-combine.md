---
id: m45-l05
title: Recognizing Combine in existing code
description: "Combine is Apple's publisher-and-subscriber framework from iOS 13, and plenty of production code still runs on it. You read a pipeline as publisher, operators and subscriber, understand demand and why an AnyCancellable must be stored, recognize @Published, subjects, Future and assign(to:), bridge to async/await with values and Future.value, and decide case by case whether to keep a pipeline or migrate it."
module: m45
order: 5
level: advanced
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m45-l04, m29-l06, m36-l04]
objectives:
  - Read a Combine pipeline as a publisher, a chain of operators and a subscriber.
  - Explain demand, and why sink and assign request unlimited values.
  - Explain AnyCancellable's lifetime and the store(in:) pattern, and avoid the retain cycle with assign(to:on:).
  - Recognize @Published, PassthroughSubject, CurrentValueSubject and Future, and what each emits to a new subscriber.
  - Bridge Combine to async/await with values and Future's value.
  - Decide when to keep a pipeline, when to migrate it to async/await or Observation, and how.
terms:
  - term: Publisher
    definition: "A type that can deliver a sequence of values over time, then optionally finish or fail. Declares Output and Failure types. Nothing is produced until a subscriber attaches and asks."
  - term: Subscriber
    definition: "A type that receives a Subscription, then values and a completion from a publisher. It controls the flow through demand. sink and assign(to:on:) create subscribers for you."
  - term: Demand
    definition: "How many more values a subscriber is ready for, requested through the subscription or returned from receive(_:). Demand is additive, and sink and assign ask for unlimited."
  - term: Operator
    definition: "A method on Publisher, such as map, filter, removeDuplicates, debounce or receive(on:), that returns a new publisher which subscribes to the one before it."
  - term: AnyCancellable
    definition: "A cancellation token returned by sink and assign(to:on:). It cancels the subscription when you call cancel() or when it's deinitialized, so the token must be stored for the subscription to stay alive."
  - term: Subject
    definition: "A publisher you push values into with send(_:). PassthroughSubject has no current value and drops values with no subscriber or no demand; CurrentValueSubject keeps the latest value and gives it to new subscribers."
mastery:
  - Annotate a pipeline with what each line produces and on which thread values arrive.
  - Predict what a subscriber receives as tokens are stored, discarded and cancelled.
  - Trace demand through a custom subscriber that asks for a few values at a time.
  - Write a small current-value subject and predict its output for subscribers that come and go.
  - Replace a Future with await and a subject with a for-await loop using values.
  - Recommend keeping or migrating a specific pipeline, with reasons.
resources: [combine, combine-anycancellable, combine-observableobject, swiftui-migrating-to-observable, swift-checkedcontinuation, swift-task, foundation-notificationcenter]
cards:
  - id: m45-l05-c1
    front: Why does a sink stop working as soon as the function that created it returns?
    back: "sink returns an AnyCancellable, and Apple says 'the return value should be held, otherwise the stream will be canceled.' If nothing stores it, it's deinitialized and AnyCancellable cancels on deinit. Store it in a property, usually with .store(in: &cancellables)."
  - id: m45-l05-c2
    front: assign(to:on:) or assign(to:)?
    back: "assign(to: \\.property, on: self) keeps a strong reference to self, so storing its AnyCancellable in self creates a reference cycle. assign(to: &$property) republishes into a @Published property and is cancelled when that property is deinitialized; no AnyCancellable to manage."
  - id: m45-l05-c3
    front: When does @Published publish, and what does a new subscriber get?
    back: "In the property's willSet, so a subscriber reading the property inside its closure sees the old value. A new subscriber to $property receives the current value immediately, then each change."
  - id: m45-l05-c4
    front: How do you consume a Combine publisher from async code?
    back: "for await value in publisher.values (iOS 15; AsyncPublisher when Failure is Never, AsyncThrowingPublisher otherwise, with for try await). A Future's single value is await future.value."
  - id: m45-l05-c5
    front: When is Combine still the better tool?
    back: "When the code relies on time-based or combining operators Apple says only Combine provides (debounce, throttle, merge, combineLatest), when the pipeline works and isn't the thing you're changing, or when a dependency exposes publishers. New one-shot async work should use async/await."
---

## The idea in one sentence

A Combine pipeline is **a publisher, a chain of operators that each wrap the one before, and a subscriber whose token you must keep**, and once you can read that shape you can maintain it, bridge it to async/await, or replace it.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: the Combine overview, `Publisher`, `Subscriber`, "Processing published elements with subscribers", `Subscribers.Demand`, `AnyCancellable`, `sink(receiveValue:)`, `assign(to:on:)`, `assign(to:)`, `Published`, `PassthroughSubject`, `CurrentValueSubject`, `Future`, `values` and `AsyncPublisher`, and "Using Combine for your app's asynchronous code". Combine exists only on Apple platforms, so the Combine blocks are type-checked against the iOS SDK, not run. The publisher, subscriber, token and subject models are plain Swift written for this lesson: they show the protocol shape and documented behavior, not Combine's implementation, and they were compiled and run with Swift 6.3, as was the AsyncStream example.

## Why you still need to read it

Combine arrived in iOS 13, two years before async/await. Many apps built their networking, form validation and view models on it, and SwiftUI's original data flow (`ObservableObject` and `@Published`, Module 36) is Combine. You'll meet it in three places: view models with `@Published` and `cancellables`, services that return `AnyPublisher`, and pipelines with `debounce` or `combineLatest` in search and form screens.

Apple's current position, from "Using Combine for your app's asynchronous code": "You don't need closure-based asynchronicity patterns if you're using the async-await features in Swift 5.5 and later." And from `Publisher`: "only Combine provides time-based operations like `debounce(for:scheduler:options:)` and `throttle(for:scheduler:latest:)`, and combining operations like `merge(with:)` and `combineLatest(_:_:)`." So Combine isn't deprecated, and it isn't where new one-shot async work goes.

## Reading a pipeline

Here's code of the kind Pantry still has, written in 2021:

```swift ios
import Combine
import Foundation

struct CatalogProduct: Decodable, Sendable {
    let id: Int
    let name: String
}

extension Notification.Name {
    static let pantryCartCleared = Notification.Name("PantryCartCleared")
}

@MainActor
final class LegacyCatalogModel: ObservableObject {
    @Published private(set) var products: [CatalogProduct] = []
    @Published private(set) var errorMessage: String?
    @Published var cartCount = 0
    @Published private(set) var badgeText = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        $cartCount
            .map { (count: Int) -> String in count == 0 ? "" : "\(count)" }
            .removeDuplicates()
            .assign(to: &$badgeText)

        NotificationCenter.default.publisher(for: .pantryCartCleared)
            .receive(on: RunLoop.main)
            .sink { [weak self] (_: Notification) in
                self?.cartCount = 0
            }
            .store(in: &cancellables)
    }

    func loadProducts(from url: URL) {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [CatalogProduct].self, decoder: JSONDecoder())
            .receive(on: RunLoop.main)
            .sink { [weak self] (completion: Subscribers.Completion<any Error>) in
                if case .failure = completion {
                    self?.errorMessage = "Couldn't load products."
                }
            } receiveValue: { [weak self] (products: [CatalogProduct]) in
                self?.products = products
            }
            .store(in: &cancellables)
    }
}
```

Read each chain top to bottom, as data flowing down:

- **`$cartCount`** is the publisher `@Published` creates ("You access the publisher with the `$` operator"). `map` turns the count into badge text, `removeDuplicates` skips repeats, and **`assign(to: &$badgeText)`** republishes into another `@Published` property. Apple: it "manages the life cycle of the subscription, canceling the subscription automatically when the `Published` instance deinitializes," so there's no token to store.
- **`NotificationCenter.default.publisher(for:)`** is Foundation's publisher for a notification. `receive(on: RunLoop.main)` moves delivery to the main thread, and **`sink`** runs a closure per value. Its `AnyCancellable` goes into `cancellables` with **`store(in:)`**.
- **`dataTaskPublisher(for:)`** publishes one `(data, response)` value or a `URLError`. `map(\.data)` keeps the data, `decode` turns it into products and changes the failure type to `any Error`, `receive(on:)` moves to the main thread, and `sink(receiveCompletion:receiveValue:)` handles both outcomes. Note what this chain doesn't do: check the HTTP status code. Module 30's rule that a 404 isn't an error to `URLSession` applies here too.

Every operator returns a new publisher that subscribes to the one above it when someone subscribes to it. Apple's example: "A `filter(_:)` operator creates a `Filter` publisher ... The sink subscriber automatically subscribes to the filter publisher, at which point the filter publisher subscribes to its upstream publisher." Nothing runs until the subscriber at the bottom attaches.

## The protocol shape, as a model

Combine doesn't run on Linux, so here's a small model of its two most important rules, written in plain Swift. It's **a model, not Combine**: the names mimic Combine's to make the shape recognizable.

### Rule 1: the subscription lives as long as its token

From `AnyCancellable`: "An `AnyCancellable` instance automatically calls `cancel()` when deinitialized." And from `sink(receiveValue:)`: "The return value should be held, otherwise the stream will be canceled."

```swift
// A MODEL of Combine's shape in plain Swift, so it runs anywhere. It is not Combine.

/// Like AnyCancellable: cancels when you call cancel(), or when it's deinitialized.
final class CancelToken {
    private var onCancel: (() -> Void)?

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }

    /// Like AnyCancellable.store(in:).
    func store(in tokens: inout [CancelToken]) {
        tokens.append(self)
    }

    deinit {
        cancel()
    }
}

/// Like PassthroughSubject<Output, Never>: send(_:) delivers to every current subscriber.
final class Subject<Output> {
    private var subscribers: [Int: (Output) -> Void] = [:]
    private var nextID = 0

    /// Like sink(receiveValue:): the returned token keeps the subscription alive.
    func sink(_ receiveValue: @escaping (Output) -> Void) -> CancelToken {
        let id = nextID
        nextID += 1
        subscribers[id] = receiveValue
        return CancelToken { [weak self] in
            self?.subscribers[id] = nil
        }
    }

    func send(_ value: Output) {
        for id in subscribers.keys.sorted() {
            subscribers[id]?(value)
        }
    }
}

let cartCount = Subject<Int>()
var tokens: [CancelToken] = []                         // like Set<AnyCancellable>

let badge = cartCount.sink { print("badge:", $0) }     // kept in a constant
_ = cartCount.sink { print("lost:", $0) }              // token discarded: cancelled at once
cartCount.sink { print("label:", $0) }.store(in: &tokens)

cartCount.send(3)
badge.cancel()
cartCount.send(4)
tokens.removeAll()                                     // the owner of the tokens went away
cartCount.send(5)
print("done")
```

```output
badge: 3
label: 3
label: 4
done
```

- **"lost" never prints.** The token is discarded on the same line, its `deinit` cancels, and the subscription is gone before the first `send`. This is the most common Combine bug: a `sink` inside a function whose result isn't stored works in nobody's tests, because it never runs at all.
- **`badge.cancel()`** ends one subscription explicitly.
- **`tokens.removeAll()`** is what happens when a view model is deallocated: its `Set<AnyCancellable>` goes away and every subscription it owned is cancelled. That's why the pattern is a `cancellables` property on the object that owns the work. Module 13's resource-ownership lesson described this design: a subscription that ends when its owner does.
- **`[weak self]`** in the token's closure, and in the real `sink` closures above, prevents a cycle. Apple warns about the other common cycle explicitly: `assign(to:on:)` "maintains a strong reference to object," so `assign(to: \.badgeText, on: self)` stored in `self.cancellables` never lets `self` go. `assign(to: &$badgeText)` exists to solve that.

### Rule 2: subscribers control the flow with demand

From "Processing published elements with subscribers": "a publisher can't send elements until the subscriber attaches and asks for them," either by calling `request(_:)` on the subscription or "by returning a new demand when the publisher calls the subscriber's `receive(_:)` method." "Demand is additive." And: `sink` and `assign(to:on:)` "issue a demand for `unlimited` when they first attach." Most code never sees demand because of that. A custom subscriber, modeled:

```swift
// A MODEL of Combine's demand (back pressure). In Combine, a subscriber receives a
// Subscription, calls request(_:), and returns extra demand from receive(_:).

protocol ModelSubscription: AnyObject {
    func request(_ demand: Int)
}

protocol ModelSubscriber: AnyObject {
    associatedtype Input
    func receive(subscription: any ModelSubscription)
    func receive(_ input: Input) -> Int          // additional demand, 0 for none
    func receiveCompletion()
}

/// Like [1, 2, 3].publisher: emits its elements only as fast as demand allows.
struct ArrayPublisher<Element> {
    let elements: [Element]

    func subscribe<S: ModelSubscriber>(_ subscriber: S) where S.Input == Element {
        let subscription = ArraySubscription(elements: elements, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

final class ArraySubscription<S: ModelSubscriber>: ModelSubscription {
    private let elements: [S.Input]
    private var subscriber: S?
    private var index = 0
    private var demand = 0

    init(elements: [S.Input], subscriber: S) {
        self.elements = elements
        self.subscriber = subscriber
    }

    func request(_ additional: Int) {
        demand += additional
        while demand > 0, index < elements.count, let subscriber {
            demand -= 1
            let element = elements[index]
            index += 1
            demand += subscriber.receive(element)
        }
        if index == elements.count, let subscriber {
            self.subscriber = nil
            subscriber.receiveCompletion()
        }
    }
}

/// Asks for two items, then one more after each item it receives, up to `maximum`.
final class PagingSubscriber: ModelSubscriber {
    private let maximum: Int
    private var received = 0
    private(set) var subscription: (any ModelSubscription)?

    init(maximum: Int) {
        self.maximum = maximum
    }

    func receive(subscription: any ModelSubscription) {
        self.subscription = subscription
        print("subscribed, requesting 2")
        subscription.request(2)
    }

    func receive(_ input: String) -> Int {
        received += 1
        print("received \(input)")
        return received < maximum - 1 ? 1 : 0
    }

    func receiveCompletion() {
        print("finished")
    }
}

let pages = ArrayPublisher(elements: ["page 1", "page 2", "page 3", "page 4", "page 5"])
let reader = PagingSubscriber(maximum: 3)
pages.subscribe(reader)
print("--- later, the reader asks for more")
reader.subscription?.request(5)
```

```output
subscribed, requesting 2
received page 1
received page 2
received page 3
--- later, the reader asks for more
received page 4
received page 5
finished
```

- **Demand adds up.** Two requested, one returned after page 1, none after page 2: three pages in total, and the publisher stops with pages left, waiting.
- **Nothing is lost while it waits.** An array publisher can wait. A `PassthroughSubject` can't: Apple says it "drops values if there are no subscribers, or its current demand is zero." That's a fact worth remembering when you bridge to async code below.
- **Completion** comes once, after the last element, and the subscription releases the subscriber.

### Subjects and @Published

You'll see three ways values get into a pipeline from imperative code:

- **`PassthroughSubject`**: `send(_:)` broadcasts; no current value, no buffer. Good for events ("cart cleared").
- **`CurrentValueSubject`**: "maintains a buffer of the most recently published element"; a new subscriber gets it immediately. Good for state.
- **`@Published`**: a property whose `$` publisher behaves like a current-value subject. Apple's `Published` example subscribes to a temperature of 20 and then sets 25, and the subscriber prints both. One subtlety from the same page: "publishing occurs in the property's willSet block," so code inside the subscriber that reads the property sees the **old** value.

The solve exercise builds a current-value subject in the model.

## Bridging to async/await

New code in Pantry is async/await. Where it meets old publishers, two bridges cover most cases.

**Many values: `values`.** Apple: "the property `values` exposes a publisher's elements as an `AsyncSequence`, allowing you to iterate over them with for-await-in rather than attaching a `Subscriber`." `AsyncPublisher` for publishers that can't fail, `AsyncThrowingPublisher` (with `for try await`) for those that can, both iOS 15.

**One value: `Future.value`.** A `Future` "eventually produces a single value and then finishes or fails"; it was Combine's answer to completion handlers. Its `value` property (iOS 15) is `async`, or `async throws` when the future can fail.

```swift ios
import Combine

/// Old code: a price feed that publishes through Combine.
final class PriceFeed {
    let prices = PassthroughSubject<Int, Never>()
}

/// New code: the lowest of the next `samples` prices, with a for-await loop instead of a sink.
func lowestPrice(in feed: PriceFeed, samples: Int) async -> Int? {
    var lowest: Int?
    for await price in feed.prices.prefix(samples).values {
        lowest = min(lowest ?? price, price)
    }
    return lowest
}

/// Old code: a completion-style API wrapped in a Future.
func legacyStockCount() -> Future<Int, Never> {
    Future { promise in
        promise(.success(12))
    }
}

/// New code: await the Future's single value.
func stockMessage() async -> String {
    let count = await legacyStockCount().value
    return "\(count) in stock"
}
```

- **The loop ends when the publisher finishes.** `prefix(samples)` finishes after that many values; an endless publisher keeps the loop (and its task) alive until the task is cancelled. Run such loops in a `.task` modifier, as with `liveUpdates` in lesson 2.
- **Passthrough subjects drop values without demand.** Combine's documentation doesn't say how much demand `values` requests at a time. Combined with `PassthroughSubject`'s documented rule, a loop that's busy when a value is sent could miss it. If every value matters, put a `buffer(size:prefetch:whenFull:)` operator before `values`, or replace the subject with an `AsyncStream` and its buffering policy (Module 29).
- **Going the other way**, exposing an async function as a publisher for old callers, is possible but awkward under Swift 6's checking. Usually it's simpler to migrate the caller.

### What the migrated code looks like

A pipeline of transformations becomes a loop over an async sequence. Here's Apple's `Publisher` example pipeline (`filter` then a subscriber), with a `map` added, written with an `AsyncStream`, so it runs everywhere:

```swift
// The Combine pipeline  [1, 2, 3, 4, 5].publisher.filter { $0 % 2 == 0 }.map { $0 * 10 }.sink { ... }
// written with Swift concurrency, which runs on every platform.

let (numbers, continuation) = AsyncStream.makeStream(of: Int.self)
for number in 1...5 {
    continuation.yield(number)
}
continuation.finish()

for await value in numbers.filter({ $0 % 2 == 0 }).map({ $0 * 10 }) {
    print("received", value)
}
print("finished")
```

```output
received 20
received 40
finished
```

`filter` and `map` exist on every `AsyncSequence` in the standard library. What doesn't: `debounce`, `throttle`, `combineLatest`, `merge`. Those are the operators Apple names as Combine-only. In SwiftUI, Module 37 built a debounced search with `task(id:)` and `Task.sleep` instead, which is the usual replacement for `$query.debounce(...)` (Module 36's example). Apple also publishes the open-source swift-async-algorithms package with debounce, merge and combine-latest for async sequences; adding it is a dependency decision like any other (Module 42's supply-chain lesson).

## Keep or migrate?

Pantry's rule of thumb, applied pipeline by pipeline:

| You find | Do |
| --- | --- |
| A `Future` or one-shot `dataTaskPublisher` chain | Migrate to an `async` function when you next change it. It's shorter and gets cancellation for free. |
| `ObservableObject` with `@Published` only to drive SwiftUI | Migrate to `@Observable` when you're working on that screen (Module 36's guide, one type at a time). |
| `@Published` plus `$property` pipelines with `debounce`, `combineLatest` | Keep it, or replace it with `task(id:)` and plain methods if the logic is simple. |
| A dependency that exposes publishers | Keep Combine at the boundary; consume with `values` in new code. |
| A working pipeline you aren't changing | Leave it. Migrating code you don't need to touch is risk without benefit. |

Two migration traps. First, `$property` publishers disappear when a type moves to `@Observable` (Module 36), so search for every `$` use before converting. Second, Combine's `receive(on: RunLoop.main)` becomes main-actor isolation: a `@MainActor` view model with `async` methods replaces the scheduler hop, and the compiler checks what `receive(on:)` only promised.

## Common mistakes

> [!error] Not storing the AnyCancellable
> `_ = publisher.sink { ... }`, or a `sink` whose result goes nowhere, is cancelled immediately. Store it with `.store(in: &cancellables)`.

> [!error] assign(to:on: self) stored in self
> The `Assign` subscriber holds `self` strongly; `self` holds the token. Neither is ever freed. Use `assign(to: &$property)` or `sink` with `[weak self]`.

> [!error] Strong self in sink closures
> `sink { self.items = $0 }` stored in `self.cancellables` is the same cycle. Use `[weak self]`.

> [!error] Updating UI state without receive(on:)
> `dataTaskPublisher` delivers on a background queue. Without `receive(on: RunLoop.main)` (or `DispatchQueue.main`), `@Published` changes that drive the UI happen off the main thread.

> [!error] Expecting a PassthroughSubject to remember
> It "drops values if there are no subscribers." Subscribing after the event means never seeing it. Use `CurrentValueSubject` for state.

> [!error] Reading the property inside its own $publisher sink
> `@Published` publishes in `willSet`; the property still holds the old value. Use the value the closure receives.

## Exercises

````exercise
id: m45-l05-e1
type: prediction
prompt: "Using the lesson's token and subject model. What does it print?"
code: |
  final class CancelToken {
      private var onCancel: (() -> Void)?

      init(_ onCancel: @escaping () -> Void) {
          self.onCancel = onCancel
      }

      func cancel() {
          onCancel?()
          onCancel = nil
      }

      deinit {
          cancel()
      }
  }

  final class Subject {
      private var subscribers: [Int: (Int) -> Void] = [:]
      private var nextID = 0

      func sink(_ receiveValue: @escaping (Int) -> Void) -> CancelToken {
          let id = nextID
          nextID += 1
          subscribers[id] = receiveValue
          return CancelToken { [weak self] in
              self?.subscribers[id] = nil
          }
      }

      func send(_ value: Int) {
          for id in subscribers.keys.sorted() {
              subscribers[id]?(value)
          }
      }
  }

  let prices = Subject()
  var kept: [CancelToken] = []
  prices.send(1)
  kept.append(prices.sink { print("A", $0) })
  prices.send(2)
  kept.append(prices.sink { print("B", $0 * 10) })
  kept.removeFirst()
  prices.send(3)
output: |
  A 2
  B 30
hints:
  - "A value sent with no subscribers goes nowhere."
  - "removeFirst() releases the first token, the one for A."
solution: |
  ```output
  A 2
  B 30
  ```

  - `send(1)` has no subscribers, like a `PassthroughSubject`: dropped.
  - A subscribes and its token is stored, so `send(2)` reaches it.
  - B subscribes; then `removeFirst()` removes A's token from the array, the last reference, so it's deinitialized and cancels A.
  - `send(3)` reaches only B, which prints 3 × 10.
````

````exercise
id: m45-l05-e2
type: comprehension
prompt: "A view model's init contains `$query.debounce(for: .milliseconds(300), scheduler: RunLoop.main).sink { [weak self] in self?.search($0) }` and nothing else. Searches never run. Why?"
choices:
  - text: "The AnyCancellable returned by sink isn't stored, so the subscription is cancelled as soon as init finishes."
    correct: true
    why: "Apple: the return value 'should be held, otherwise the stream will be canceled.' Store it in a cancellables property."
  - text: "debounce needs DispatchQueue.main instead of RunLoop.main."
    correct: false
    why: "Both are valid schedulers for this."
  - text: "[weak self] makes self nil inside the closure."
    correct: false
    why: "Weak self is nil only if the model was deallocated; it isn't here."
  - text: "@Published properties can't be debounced."
    correct: false
    why: "$query is an ordinary publisher; Module 36 debounced one."
solution: |
  `sink` returns an `AnyCancellable`, and `AnyCancellable` cancels when it's deinitialized. Discarded in `init`, it's deinitialized right away, and the pipeline is torn down before the first keystroke. Add `.store(in: &cancellables)` with `private var cancellables = Set<AnyCancellable>()`. Or, in SwiftUI, replace the pipeline with `task(id: query)` and a short sleep, as in Module 37.
````

````exercise
id: m45-l05-e3
type: find-errors
prompt: "Mark every real problem in this Combine view model."
code: |
  final class OrdersModel: ObservableObject {
      @Published var orders: [Order] = []
      @Published var count = 0
      var cancellables = Set<AnyCancellable>()

      init(service: OrderService) {
          service.ordersPublisher()                       // a dataTaskPublisher chain
              .replaceError(with: [])
              .assign(to: \.orders, on: self)
              .store(in: &cancellables)

          $orders
              .sink { _ in self.count = self.orders.count }
              .store(in: &cancellables)
      }
  }
choices:
  - text: "assign(to:on: self) stored in self.cancellables is a reference cycle: the subscriber holds self strongly."
    correct: true
  - text: "The sink captures self strongly and is stored in self, another cycle."
    correct: true
  - text: "Inside the $orders sink, self.orders is still the old value, because @Published publishes in willSet."
    correct: true
  - text: "Results from the network arrive on a background queue and are assigned to a @Published property without receive(on:)."
    correct: true
  - text: "A class can't have more than one @Published property."
    correct: false
    why: "It can have as many as it needs."
rubric:
  - I flagged the assign(to:on:) cycle.
  - I flagged the strong self in sink.
  - I flagged the willSet timing bug.
  - I flagged the missing receive(on:).
solution: |
  ```swift ios
  import Combine
  import Foundation

  struct Order: Sendable {
      let id: Int
  }

  protocol OrderService {
      func ordersPublisher() -> AnyPublisher<[Order], any Error>
  }

  @MainActor
  final class OrdersModel: ObservableObject {
      @Published private(set) var orders: [Order] = []
      @Published private(set) var count = 0

      init(service: any OrderService) {
          service.ordersPublisher()
              .replaceError(with: [])
              .receive(on: RunLoop.main)
              .assign(to: &$orders)

          $orders
              .map { (orders: [Order]) -> Int in orders.count }
              .assign(to: &$count)
      }
  }
  ```

  - `assign(to: &$orders)` replaces `assign(to:on:)`: no token, no cycle, cancelled when the property goes away.
  - The count is derived with `map` from the value the publisher delivers, not by reading `self.orders`, which in `willSet` still holds the old array. A computed `var count: Int { orders.count }` would be simpler still.
  - `receive(on: RunLoop.main)` moves network results to the main thread before they touch UI state; `@MainActor` on the class lets the compiler check it.
  - `replaceError(with: [])` hides failures from the person; a real version would keep an error state, as the lesson's `LegacyCatalogModel` does.
````

````exercise
id: m45-l05-e4
type: fill-in
prompt: "Bridge these Combine APIs to async/await."
code: |
  // Many values: iterate the publisher as an AsyncSequence.
  for await price in feed.prices.prefix(10).[[1]] {
      print(price)
  }

  // One value from a Future that can't fail.
  let count = await legacyStockCount().[[2]]

  // Keep a sink alive for as long as the model exists.
  publisher.sink { [weak self] value in self?.update(value) }
      .[[3]](in: &cancellables)

  // Republish into another @Published property without a token.
  $cartCount.map { "\($0)" }.[[4]](to: &$badgeText)
blanks:
  - id: "1"
    answers: ["values"]
  - id: "2"
    answers: ["value"]
  - id: "3"
    answers: ["store"]
  - id: "4"
    answers: ["assign"]
solution: |
  - `values` (iOS 15) gives an `AsyncPublisher`; `for try await` with `AsyncThrowingPublisher` when the publisher can fail.
  - `Future.value` is `async`, and `async throws` when the future's failure type is an error.
  - `store(in:)` puts the `AnyCancellable` in the set the model owns.
  - `assign(to:)` with `&$badgeText` ties the subscription's life to the `@Published` property.
````

````exercise
id: m45-l05-e5
type: solve
prompt: |
  Using the lesson's `CancelToken`, write `ValueSubject<Output>`, a model of `CurrentValueSubject`: it has a `value` property; setting it delivers the new value to every current subscriber (in subscription order); `sink(_:)` registers a closure, **immediately delivers the current value to it**, and returns a token that removes the subscriber when cancelled or deinitialized.

  Expected output:

  ```output
  display: 21
  display: 25
  log: 25
  display: 18
  log: 18
  display: 19
  current: 30
  ```
starter: |
  final class CancelToken {
      private var onCancel: (() -> Void)?

      init(_ onCancel: @escaping () -> Void) {
          self.onCancel = onCancel
      }

      func cancel() {
          onCancel?()
          onCancel = nil
      }

      deinit {
          cancel()
      }
  }

  final class ValueSubject<Output> {
      // your code: value, init(_:), sink(_:)
  }

  let temperature = ValueSubject(20)
  temperature.value = 21
  let display = temperature.sink { print("display:", $0) }
  temperature.value = 25
  var log: CancelToken? = temperature.sink { print("log:", $0) }
  temperature.value = 18
  log = nil
  temperature.value = 19
  display.cancel()
  temperature.value = 30
  print("current:", temperature.value)
hints:
  - "Store subscribers in a dictionary keyed by an increasing id, and deliver in sorted id order."
  - "A didSet on value can deliver to subscribers."
  - "The token's closure should capture the subject weakly."
rubric:
  - New subscribers get the current value at once, then each change.
  - Cancelling or releasing a token stops delivery to that subscriber only.
  - Delivery order is deterministic, and the subject doesn't retain itself through tokens.
solution: |
  ```swift
  final class CancelToken {
      private var onCancel: (() -> Void)?

      init(_ onCancel: @escaping () -> Void) {
          self.onCancel = onCancel
      }

      func cancel() {
          onCancel?()
          onCancel = nil
      }

      deinit {
          cancel()
      }
  }

  /// A model of CurrentValueSubject (and of what @Published gives you through $property):
  /// a new subscriber receives the current value at once, then every change.
  final class ValueSubject<Output> {
      private var subscribers: [Int: (Output) -> Void] = [:]
      private var nextID = 0

      var value: Output {
          didSet {
              for id in subscribers.keys.sorted() {
                  subscribers[id]?(value)
              }
          }
      }

      init(_ value: Output) {
          self.value = value
      }

      func sink(_ receiveValue: @escaping (Output) -> Void) -> CancelToken {
          let id = nextID
          nextID += 1
          subscribers[id] = receiveValue
          receiveValue(value)
          return CancelToken { [weak self] in
              self?.subscribers[id] = nil
          }
      }
  }

  let temperature = ValueSubject(20)
  temperature.value = 21
  let display = temperature.sink { print("display:", $0) }
  temperature.value = 25
  var log: CancelToken? = temperature.sink { print("log:", $0) }
  temperature.value = 18
  log = nil
  temperature.value = 19
  display.cancel()
  temperature.value = 30
  print("current:", temperature.value)
  ```

  ```output
  display: 21
  display: 25
  log: 25
  display: 18
  log: 18
  display: 19
  current: 30
  ```

  - 20 is replaced by 21 before anyone subscribes, so nobody sees 20. The display subscribes and gets 21 at once, the "current value" rule that separates `CurrentValueSubject` and `@Published` from `PassthroughSubject`.
  - Setting `log` to nil releases its token, so 19 reaches only the display; after `display.cancel()`, 30 reaches nobody, but `value` still holds it.
  - This model delivers in `didSet`, after the value changes. `@Published` delivers in `willSet`, before it changes; that's the difference behind the last common mistake in the lesson.
````

````exercise
id: m45-l05-e6
type: design
prompt: "Pantry's checkout screen has a Combine view model: an ObservableObject with @Published address, payment method and promo code; a combineLatest of the three that enables the Pay button; a debounced promo-code check that calls a dataTaskPublisher; and a Future that places the order. The team targets iOS 17 and is adding Apple Pay. Propose what to keep, what to migrate and in what order, and how you'd keep behavior the same."
rubric:
  - Migrates the order Future to an async function first, since it's one-shot and the code being changed.
  - Moves the promo check to async/await with task(id:) debouncing or keeps the debounce pipeline, with a reason.
  - Replaces the combineLatest validation with a computed property after moving to @Observable, or keeps it while on ObservableObject.
  - Migrates the view model to @Observable as a separate step, checking every $property use first.
  - Protects behavior with tests of the validation and promo logic before and after, and changes one piece per review.
solution: |
  1. **Place order (Future):** the Apple Pay work touches this code, so migrate it first to `func placeOrder(...) async throws -> Order`. The view calls it from a `Task` on the Pay button. One-shot work is exactly what `async` replaces.
  2. **Pay button (combineLatest of three @Published):** that's derived state. Once the model is `@Observable`, it's `var canPay: Bool { address.isValid && payment != nil && promoState != .checking }`; no pipeline needed. Until then, keep the pipeline.
  3. **Promo check (debounce + dataTaskPublisher):** in SwiftUI, `task(id: promoCode)` with a 400 ms `Task.sleep` and an async `checkPromo` (Module 37's pattern) replaces both the debounce and the stale-result handling. If the check must stay in the model (it's shared with the web view), keep the Combine pipeline and consume its result.
  4. **ObservableObject to @Observable:** a separate change after steps 1 to 3, following Module 36's guide; first search for every `$address`, `$promoCode` and `objectWillChange` use.
  5. **Safety net:** before each step, unit tests for `canPay` and for the promo states (valid, invalid, network error, typing quickly), run again after. One step per pull request, so a regression points at one change.
````

## Summary

- A pipeline is a publisher, operators that each subscribe to the one above, and a subscriber at the bottom; nothing runs until the subscriber attaches.
- Subscribers control flow with demand, which is additive; `sink` and `assign(to:on:)` ask for unlimited.
- `sink` and `assign(to:on:)` return an `AnyCancellable` that cancels on `deinit`: store it (`store(in: &cancellables)`), use `[weak self]`, and avoid `assign(to:on: self)`; prefer `assign(to: &$property)`.
- `PassthroughSubject` drops values without subscribers or demand; `CurrentValueSubject` and `@Published` give new subscribers the current value. `@Published` publishes in `willSet`.
- Bridge with `publisher.values` (`for await`, iOS 15) and `await future.value`. `filter` and `map` exist on async sequences; `debounce`, `throttle`, `merge` and `combineLatest` are Combine's (or swift-async-algorithms').
- Migrate one-shot work to `async` functions and SwiftUI-only models to `@Observable` when you're changing that code; keep working pipelines and publisher-based dependencies; protect each step with tests.
