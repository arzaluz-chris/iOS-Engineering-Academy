---
id: m34-l03
title: ViewBuilder and result builders
description: "The braces after VStack aren't special syntax: they're a closure transformed by a result builder, a Swift feature any type can use. You write your own builder in plain Swift, run it, watch the compiler's calls one by one, and see how if, if-else, switch and for become values with a single static type. Then you put @ViewBuilder on your own properties, functions and container views, and learn why for loops need ForEach and when AnyView costs you state."
module: m34
order: 3
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m34-l02]
objectives:
  - Describe what the compiler does with a closure marked by a result builder.
  - Write a result builder with buildBlock, buildOptional, buildEither, buildArray and buildExpression.
  - Explain how a builder turns if, if-else and switch into one static type, and why that makes some View work.
  - Use @ViewBuilder on computed properties, functions and closure parameters of your own container views.
  - Explain why for loops need ForEach in a view builder and what AnyView does to identity.
terms:
  - term: Result builder
    definition: "A type marked @resultBuilder whose static build methods the compiler calls to turn the statements of a closure, function or property body into one value."
  - term: buildBlock
    definition: "The build method that combines the values of the statements in a block into one value. It's the only one a result builder must have."
  - term: buildEither
    definition: "A pair of build methods, buildEither(first:) and buildEither(second:), that wrap the result of each branch of an if-else or switch so both branches have the same type."
  - term: "@ViewBuilder"
    definition: "SwiftUI's result builder for views. View's body requirement, container initializers and many modifiers' closures use it, so you can list views and use if and switch inside them."
  - term: AnyView
    definition: "A type-erased view. It can hold views of different types, but Apple says that when the type it holds changes, the old hierarchy is destroyed and a new one is created."
mastery:
  - Write the sequence of build calls the compiler makes for a closure with an if-else.
  - Implement a small result builder in plain Swift and use it from a protocol requirement.
  - Fix a function that returns some View from an if-else without @ViewBuilder.
  - Write a container view that takes a @ViewBuilder content closure.
  - Replace a for loop and an AnyView in a body with ForEach and a builder.
resources: [swiftui-viewbuilder, swift-book-opaque-types, swift-book-generics, swift-book-closures, swift-book-protocols]
cards:
  - id: m34-l03-c1
    front: What does a result builder do?
    back: "The compiler rewrites a closure (or function or property body) marked with the builder: each statement's value is collected, and the builder's static methods (buildBlock, buildOptional, buildEither, buildArray…) combine them into one value."
  - id: m34-l03-c2
    front: How does a view builder let body contain an if-else that returns different view types?
    back: "Each branch's result is wrapped by buildEither(first:) or buildEither(second:) into one conditional type, _ConditionalContent<TrueContent, FalseContent> in SwiftUI. body always returns that one type, so some View works."
  - id: m34-l03-c3
    front: Why can't you write a for loop inside a VStack's closure?
    back: "ViewBuilder doesn't implement buildArray, so the compiler rejects for loops in it. Use ForEach, which is a view that produces one child per element and identifies them."
  - id: m34-l03-c4
    front: When does a function or computed property need @ViewBuilder?
    back: "When its body lists more than one view or uses if or switch to return different view types. body gets it automatically from the View protocol; your own helpers don't."
  - id: m34-l03-c5
    front: What's the cost of AnyView?
    back: "Apple: whenever the type of view inside an AnyView changes, the old hierarchy is destroyed and a new one created, so state inside it resets. A @ViewBuilder conditional keeps both types visible to SwiftUI instead."
---

## The idea in one sentence

`VStack { Text("A"); Text("B") }` works because the closure is marked with a **result builder**, a Swift feature that tells the compiler to collect each statement's value and combine them with static methods you define, and SwiftUI's `@ViewBuilder` is one such builder.

> [!note] About this lesson's code
> The result builders here are plain Swift: they were compiled and run, and the build-call order you'll see is what Swift 6.3 actually did. SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) but not run. SwiftUI's own builder is described from Apple's `ViewBuilder` reference, read in November 2026.

## A closure that isn't an ordinary closure

An ordinary closure with two expressions and no `return` makes no sense: which one is the result? A result builder answers that question. Mark a closure parameter with a builder type, and the compiler **rewrites** the closure: it evaluates each statement, keeps the values, and passes them to the builder's static methods, which return one combined value.

The feature was added in Swift 5.4 (proposal SE-0289) to support domain-specific languages like SwiftUI, but nothing about it is UI-specific. Here's a tiny "view" system with its own builder:

```swift
protocol Node {
    func lines() -> [String]
}

struct Text: Node {
    let value: String
    init(_ value: String) { self.value = value }
    func lines() -> [String] { [value] }
}

struct Image: Node {
    let name: String
    func lines() -> [String] { ["[\(name)]"] }
}

struct Pair<First: Node, Second: Node>: Node {
    let first: First
    let second: Second
    func lines() -> [String] { first.lines() + second.lines() }
}

struct Triple<A: Node, B: Node, C: Node>: Node {
    let a: A
    let b: B
    let c: C
    func lines() -> [String] { a.lines() + b.lines() + c.lines() }
}

@resultBuilder
enum NodeBuilder {
    static func buildBlock<A: Node>(_ a: A) -> A { a }
    static func buildBlock<A: Node, B: Node>(_ a: A, _ b: B) -> Pair<A, B> {
        Pair(first: a, second: b)
    }
    static func buildBlock<A: Node, B: Node, C: Node>(_ a: A, _ b: B, _ c: C) -> Triple<A, B, C> {
        Triple(a: a, b: b, c: c)
    }
}

func stack<Content: Node>(@NodeBuilder _ content: () -> Content) -> Content {
    content()
}

let built = stack {
    Text("Ana")
    Image(name: "star")
    Text("Premium")
}
print(type(of: built))
print(built.lines())

// What the compiler does with that closure, written by hand:
let v0 = Text("Ana")
let v1 = Image(name: "star")
let v2 = Text("Premium")
let handBuilt = NodeBuilder.buildBlock(v0, v1, v2)
print(type(of: handBuilt))
```

```output
Triple<Text, Image, Text>
["Ana", "[star]", "Premium"]
Triple<Text, Image, Text>
```

Line by line:

- **`@resultBuilder enum NodeBuilder`** declares the builder. An `enum` with no cases is the usual choice, since you never create a value of it; only its `static` methods matter.
- **`buildBlock`** is the one method every builder needs. The compiler calls it with the values of the statements in a block. These overloads keep each child's **exact type** in the result: three children give a `Triple<Text, Image, Text>`, not an array of `any Node`.
- **`@NodeBuilder _ content: () -> Content`** marks the parameter. Any closure passed for it is transformed.
- **The hand-written part** is the transformation. The compiler stores each statement's value in a hidden local and calls `buildBlock` with them. You'll never write this, but it's exactly what happens, and the type is the same.

SwiftUI's `ViewBuilder` keeps exact types the same way. A `VStack` with two `Text`s holds a tuple-typed value of two `Text`s (`TupleView<(Text, Text)>` in the SDKs this course checks against). That static structure is what lets SwiftUI tell views apart by their position, the structural identity from lesson 1.

> [!note] The ten-view limit
> You may read that a builder closure can hold at most ten views. Older SDKs declared one `buildBlock` overload per child count, up to ten, so an eleventh child didn't compile and the workaround was wrapping some in a `Group` (Apple's `Group` page still shows that example). Newer SDKs use Swift 5.9's parameter packs to accept any number of children. This lesson didn't pin down the exact SDK release that changed it, so if you maintain old code, check before relying on more than ten.

## Conditionals

Add an `if`, and the transformation needs more methods. A builder without them rejects the closure:

```swift no-compile closure containing control flow statement cannot be used with result builder 'ComponentBuilder'
protocol Component {}
struct Line: Component {
    let text: String
}

@resultBuilder
enum ComponentBuilder {
    static func buildBlock(_ components: any Component...) -> [any Component] {
        components
    }
}

func make(@ComponentBuilder _ content: () -> [any Component]) -> [any Component] {
    content()
}

let isSignedIn = true
let rows = make {
    Line(text: "Account")
    if isSignedIn {
        Line(text: "Sign out")
    }
}
```

Swift 6.3: `error: closure containing control flow statement cannot be used with result builder 'ComponentBuilder'`. Each kind of statement maps to a build method:

| You write | The compiler calls | SwiftUI's `ViewBuilder` returns |
| --- | --- | --- |
| A list of statements | `buildBlock(…)` | A tuple view of the children |
| `if` without `else` | `buildOptional(_:)` (or the older `buildIf(_:)`) | An optional view, `nil` when the condition is false |
| `if`-`else`, `switch` | `buildEither(first:)` / `buildEither(second:)` | `_ConditionalContent<TrueContent, FalseContent>` |
| `for … in` | `buildArray(_:)` | Not supported: use `ForEach` |
| `if #available(…)` | `buildLimitedAvailability(_:)` | Supported |
| Each expression, if defined | `buildExpression(_:)` | Not listed on Apple's page |

The `ViewBuilder` column comes from Apple's reference page, which lists `buildBlock`, `buildIf(_:)`, `buildEither(first:)`, `buildEither(second:)` and `buildLimitedAvailability(_:)`, and gives `buildEither`'s return type as `_ConditionalContent<TrueContent, FalseContent>`. There's no `buildArray`, which is why `for` doesn't work inside a `VStack`'s closure.

Here's the full builder, with every conditional form and loops:

```swift
protocol Node {
    func lines() -> [String]
}

struct Text: Node {
    let value: String
    init(_ value: String) { self.value = value }
    func lines() -> [String] { [value] }
}

struct Image: Node {
    let name: String
    func lines() -> [String] { ["[\(name)]"] }
}

struct Pair<First: Node, Second: Node>: Node {
    let first: First
    let second: Second
    func lines() -> [String] { first.lines() + second.lines() }
}

struct Triple<A: Node, B: Node, C: Node>: Node {
    let a: A
    let b: B
    let c: C
    func lines() -> [String] { a.lines() + b.lines() + c.lines() }
}

enum Either<First: Node, Second: Node>: Node {
    case first(First)
    case second(Second)
    func lines() -> [String] {
        switch self {
        case .first(let node): node.lines()
        case .second(let node): node.lines()
        }
    }
}

extension Optional: Node where Wrapped: Node {
    func lines() -> [String] { self?.lines() ?? [] }
}

struct Repeated<Element: Node>: Node {
    let elements: [Element]
    func lines() -> [String] { elements.flatMap { $0.lines() } }
}

@resultBuilder
enum NodeBuilder {
    static func buildBlock<A: Node>(_ a: A) -> A { a }
    static func buildBlock<A: Node, B: Node>(_ a: A, _ b: B) -> Pair<A, B> {
        Pair(first: a, second: b)
    }
    static func buildBlock<A: Node, B: Node, C: Node>(_ a: A, _ b: B, _ c: C) -> Triple<A, B, C> {
        Triple(a: a, b: b, c: c)
    }
    static func buildOptional<A: Node>(_ a: A?) -> A? { a }
    static func buildEither<F: Node, S: Node>(first: F) -> Either<F, S> { .first(first) }
    static func buildEither<F: Node, S: Node>(second: S) -> Either<F, S> { .second(second) }
    static func buildArray<A: Node>(_ elements: [A]) -> Repeated<A> { Repeated(elements: elements) }
}

protocol Screen {
    associatedtype Body: Node
    @NodeBuilder var body: Body { get }
}

struct Profile: Screen {
    let name: String
    let isPremium: Bool
    let tags: [String]

    var body: some Node {
        Text(name)
        if isPremium {
            Image(name: "star")
        } else {
            Text("Upgrade")
        }
        for tag in tags {
            Text("#" + tag)
        }
    }
}

let premium = Profile(name: "Ana", isPremium: true, tags: ["swift", "ios"])
let free = Profile(name: "Ben", isPremium: false, tags: [])
print(type(of: premium.body))
print(premium.body.lines())
print(free.body.lines())
```

```output
Triple<Text, Either<Image, Text>, Repeated<Text>>
["Ana", "[star]", "#swift", "#ios"]
["Ben", "Upgrade"]
```

Three things to notice:

1. **Both profiles have the same body type.** `Either<Image, Text>` holds whichever branch ran. The `if`-`else` doesn't make `body` return "sometimes an `Image`, sometimes a `Text`"; it returns one type that can hold either. That's why `some Node` works here, and why `some View` works for a SwiftUI `body` with an `if`-`else`.
2. **`body` has no `@NodeBuilder` attribute**, yet it's transformed. The attribute is on the protocol requirement, and Swift applies it to the conforming implementation. `View` does exactly this: its `body` requirement is declared with SwiftUI's builder, so every `body` you write gets it for free.
3. **`for` produced a `Repeated<Text>`.** The loop body runs once per element, and `buildArray` combines the results. `ViewBuilder` has no `buildArray`; SwiftUI's answer is `ForEach`, a *view* that produces its children from a collection and gives each one an identity (lesson 5).

### Why a plain function can't do this

Without a builder, the same `if`-`else` in a function returning an opaque type fails, because an opaque type must be **one** concrete type:

```swift no-compile function declares an opaque return type 'some Component', but the return statements in its body do not have matching underlying types
protocol Component {
    var name: String { get }
}
struct Line: Component {
    let name: String
}
struct Spacer: Component {
    var name: String { "spacer" }
}

func header(compact: Bool) -> some Component {
    if compact {
        return Spacer()
    } else {
        return Line(name: "Header")
    }
}
```

Swift 6.3: `error: function declares an opaque return type 'some Component', but the return statements in its body do not have matching underlying types`. You met this in Module 10. In SwiftUI it shows up as soon as you move part of a `body` into a helper method or computed property, because the helper doesn't get the builder automatically. The fix is to add it.

### Statements that aren't values

A builder collects the value of every expression statement, so a statement that produces nothing useful breaks it. Assigning or calling a function that returns `Void` is the common case:

```swift no-compile type '()' cannot conform to 'Node'
protocol Node {
    func lines() -> [String]
}
struct Text: Node {
    let value: String
    init(_ value: String) { self.value = value }
    func lines() -> [String] { [value] }
}
struct Pair<First: Node, Second: Node>: Node {
    let first: First
    let second: Second
    func lines() -> [String] { first.lines() + second.lines() }
}

@resultBuilder
enum NodeBuilder {
    static func buildBlock<A: Node>(_ a: A) -> A { a }
    static func buildBlock<A: Node, B: Node>(_ a: A, _ b: B) -> Pair<A, B> { Pair(first: a, second: b) }
}

func render(@NodeBuilder _ content: () -> some Node) {
    print(content().lines())
}

var count = 0
render {
    Text("a")
    count += 1
}
```

Swift 6.3: `error: type '()' cannot conform to 'Node'`. The SwiftUI version, `type '()' cannot conform to 'View'`, is what you get from `print("here")` or `count += 1` inside a `body`. Declarations are allowed, though, because they aren't collected: `let total = items.count` is fine, and `let _ = print("body ran")` is a well-known way to log body evaluations while debugging.

## Watching the calls

To see the order of the calls, here's a builder of string arrays that logs each one. It also uses `buildExpression(_:)`, which the compiler calls on each expression before anything else, here to turn a `String` into a one-element array:

```swift
@resultBuilder
enum TraceBuilder {
    static func buildExpression(_ text: String) -> [String] {
        print("expression \(text)")
        return [text]
    }
    static func buildBlock(_ parts: [String]...) -> [String] {
        print("block of \(parts.count)")
        return parts.flatMap { $0 }
    }
    static func buildOptional(_ part: [String]?) -> [String] {
        print("optional \(part == nil ? "nil" : "some")")
        return part ?? []
    }
    static func buildEither(first: [String]) -> [String] {
        print("either first")
        return first
    }
    static func buildEither(second: [String]) -> [String] {
        print("either second")
        return second
    }
}

func lines(@TraceBuilder _ content: () -> [String]) -> [String] {
    content()
}

let isMember = false
let result = lines {
    "Title"
    if isMember {
        "Members area"
    } else {
        "Join"
    }
    if isMember {
        "Badge"
    }
}
print(result)
```

```output
expression Title
expression Join
block of 1
either second
optional nil
block of 3
["Title", "Join"]
```

Read it as the compiler's work, top to bottom: the first expression; the `else` branch's expression, its own one-statement block, and `buildEither(second:)` because the second branch ran; the `if` without `else` whose body never ran, so `buildOptional(nil)`; and finally the outer block with three parts, one per statement. Branches that don't run are never evaluated, which is also true in SwiftUI.

## @ViewBuilder in your own code

`body` gets the builder from the protocol. Everywhere else, you add it.

### On a computed property or method

```swift ios
import SwiftUI

struct InboxRow: View {
    let subject: String
    let unreadCount: Int
    let isFlagged: Bool

    var body: some View {
        HStack {
            Text(subject)
            Spacer()
            badge
        }
    }

    @ViewBuilder
    private var badge: some View {
        if isFlagged {
            Image(systemName: "flag.fill")
                .foregroundStyle(.orange)
        } else if unreadCount > 0 {
            Text("\(unreadCount)")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .background(.blue, in: Capsule())
                .foregroundStyle(.white)
        }
    }
}
```

Without `@ViewBuilder`, `badge` would be a normal getter with an `if` and no `return`, and wouldn't compile. With it, the result is a conditional view that's either the flag, the count, or nothing. An `if`-`else if` chain with no final `else` is built with `buildEither` for the branches and then wrapped by `buildOptional`, because it can produce nothing at all; the course's `NodeBuilder` gives the same shape the type `Optional<Either<Text, Image>>`.

### With switch

```swift ios
import SwiftUI

enum LoadState {
    case loading
    case loaded([String])
    case failed(String)
}

struct ItemsView: View {
    let state: LoadState

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
        case .loaded(let items):
            List(items, id: \.self) { item in
                Text(item)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
        }
    }
}
```

A `switch` over an enum of screen states is the most common conditional in real `body`s. Each case is a branch, and the builder nests `buildEither` calls so the three branches fit one type.

### On a closure parameter: your own containers

To write a container like `VStack`, take the content as a builder closure and make the view generic over its type:

```swift ios
import SwiftUI

struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SettingsScreen: View {
    @State private var notificationsOn = true

    var body: some View {
        Card(title: "Notifications") {
            Toggle("Allow notifications", isOn: $notificationsOn)
            if notificationsOn {
                Text("You'll get a summary every morning.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- **`Card<Content: View>`** is generic, so `content` keeps its exact type, just like `Pair<First, Second>` did.
- **The initializer** marks the closure with `@ViewBuilder` and calls it right away, storing the result. Storing the built view, not the closure, is the usual pattern: the closure runs when `Card` is created, which happens while the parent's `body` runs.
- **Callers** get the same syntax as built-in containers: several views, `if`, `switch`.

> [!version] Xcode 27
> Apple's current documentation introduces `ContentBuilder`, a type alias for `ViewBuilder`, and says that when you build with Xcode 27 the builder "constructs type-agnostic content" for any SwiftUI content type (views, toolbar content, commands). Code that says `@ViewBuilder` keeps working. This course's iOS blocks are checked with Xcode 26, so they use `@ViewBuilder`.

## for loops and AnyView

Two things people reach for when a builder says no:

- **A `for` loop.** Use `ForEach(items) { item in … }` (lesson 5). It's a view, so it fits in a builder, and it identifies each child by the element's id, which a loop couldn't do.
- **`AnyView`.** Wrapping each branch in `AnyView(…)` makes a plain function compile, because both branches then return `AnyView`. Apple's `AnyView` page states the cost: "Whenever the type of view used with an `AnyView` changes, the old hierarchy is destroyed and a new hierarchy is created for the new type." Any state inside is lost on each switch, and SwiftUI can't animate between the two. A `@ViewBuilder` conditional gives the same flexibility while keeping both types visible. Reach for `AnyView` only when the type truly isn't known until run time, such as views chosen from a plugin registry.

## Common mistakes

> [!error] error: function declares an opaque return type 'some View', but the return statements in its body do not have matching underlying types
> A helper like `func icon() -> some View { if done { return Image(…) } else { return Text(…) } }`. Add `@ViewBuilder` and remove the `return`s.

> [!error] error: closure containing control flow statement cannot be used with result builder 'ViewBuilder'
> A `for` loop inside a stack. Replace it with `ForEach`.

> [!error] error: type '()' cannot conform to 'View'
> A `print(…)`, an assignment or a `Void` function call inside `body` or another builder closure. Move the effect into an action, or for temporary debugging write `let _ = print(…)`.

> [!error] AnyView to make the types line up
> It compiles, but every change of the inner type rebuilds that part of the hierarchy and resets its state. Use `@ViewBuilder`, `Group { if … else … }` or a generic container instead.

## Exercises

````exercise
id: m34-l03-e1
type: prediction
prompt: "The trace builder from the lesson, with a switch and two ifs. Predict every line it prints."
code: |
  @resultBuilder
  enum TraceBuilder {
      static func buildExpression(_ text: String) -> [String] {
          print("expression \(text)")
          return [text]
      }
      static func buildBlock(_ parts: [String]...) -> [String] {
          print("block of \(parts.count)")
          return parts.flatMap { $0 }
      }
      static func buildOptional(_ part: [String]?) -> [String] {
          print("optional \(part == nil ? "nil" : "some")")
          return part ?? []
      }
      static func buildEither(first: [String]) -> [String] {
          print("either first")
          return first
      }
      static func buildEither(second: [String]) -> [String] {
          print("either second")
          return second
      }
  }

  func lines(@TraceBuilder _ content: () -> [String]) -> [String] {
      content()
  }

  let unread = 3
  let result = lines {
      if unread > 0 {
          "\(unread) new"
          "Mark all read"
      }
      if unread > 10 {
          "Lots"
      } else {
          "Few"
      }
  }
  print(result)
output: |
  expression 3 new
  expression Mark all read
  block of 2
  optional some
  expression Few
  block of 1
  either second
  block of 2
  ["3 new", "Mark all read", "Few"]
hints:
  - "The first if's body is a block of two expressions, built before buildOptional is called."
  - "unread > 10 is false, so the else branch is built and wrapped with buildEither(second:)."
  - "The outer block has two statements: the if and the if-else."
solution: |
  ```output
  expression 3 new
  expression Mark all read
  block of 2
  optional some
  expression Few
  block of 1
  either second
  block of 2
  ["3 new", "Mark all read", "Few"]
  ```

  The compiler builds each statement's value before the enclosing block. The first `if` runs: its two expressions, then its inner `buildBlock` with 2 parts, then `buildOptional` with a value. The `if`-`else` runs its `else` branch: one expression, a block of 1, `buildEither(second:)`. The outer closure has two statements, so the last call is a block of 2. The `"Lots"` branch is never evaluated.
````

````exercise
id: m34-l03-e2
type: prediction
prompt: "Using the NodeBuilder from the lesson (with buildOptional and buildEither), what are the type and the lines of this body?"
code: |
  protocol Node {
      func lines() -> [String]
  }

  struct Text: Node {
      let value: String
      init(_ value: String) { self.value = value }
      func lines() -> [String] { [value] }
  }

  struct Pair<First: Node, Second: Node>: Node {
      let first: First
      let second: Second
      func lines() -> [String] { first.lines() + second.lines() }
  }

  enum Either<First: Node, Second: Node>: Node {
      case first(First)
      case second(Second)
      func lines() -> [String] {
          switch self {
          case .first(let node): node.lines()
          case .second(let node): node.lines()
          }
      }
  }

  extension Optional: Node where Wrapped: Node {
      func lines() -> [String] { self?.lines() ?? [] }
  }

  @resultBuilder
  enum NodeBuilder {
      static func buildBlock<A: Node>(_ a: A) -> A { a }
      static func buildBlock<A: Node, B: Node>(_ a: A, _ b: B) -> Pair<A, B> {
          Pair(first: a, second: b)
      }
      static func buildOptional<A: Node>(_ a: A?) -> A? { a }
      static func buildEither<F: Node, S: Node>(first: F) -> Either<F, S> { .first(first) }
      static func buildEither<F: Node, S: Node>(second: S) -> Either<F, S> { .second(second) }
  }

  func build<C: Node>(@NodeBuilder _ content: () -> C) -> C { content() }

  let hasError = false
  let isLoading = true
  let screen = build {
      if hasError {
          Text("Error")
      }
      if isLoading {
          Text("Loading")
      } else {
          Text("Done")
          Text("Refresh")
      }
  }
  print(type(of: screen))
  print(screen.lines())
output: |
  Pair<Optional<Text>, Either<Text, Pair<Text, Text>>>
  ["Loading"]
hints:
  - "An if without else becomes an Optional of its block's type."
  - "The else block has two statements, so its type is a Pair."
  - "The type doesn't depend on which branch ran."
solution: |
  ```output
  Pair<Optional<Text>, Either<Text, Pair<Text, Text>>>
  ["Loading"]
  ```

  The first statement is an `if` without `else` around one `Text`, so its type is `Optional<Text>`, and its value is `nil` here. The second is an `if`-`else` whose branches are `Text` and `Pair<Text, Text>`, so it's `Either<Text, Pair<Text, Text>>`. The outer block has two statements: a `Pair` of those. The type spells out both branches even though only `"Loading"` ran, which is the same reason a SwiftUI `body` with conditionals has one static type.
````

````exercise
id: m34-l03-e3
type: fill-in
prompt: "Complete this container view so callers can write TitledSection(\"Account\") { Text(\"Email\"); if isAdmin { Text(\"Admin tools\") } }."
code: |
  import SwiftUI

  struct TitledSection<Content: [[1]]>: View {
      let title: String
      let content: Content

      init(_ title: String, [[2]] content: () -> Content) {
          self.title = title
          self.content = [[3]]
      }

      var body: some View {
          VStack(alignment: .leading) {
              Text(title).font(.headline)
              content
          }
      }
  }
blanks:
  - id: "1"
    answers: ["View"]
  - id: "2"
    answers: ["@ViewBuilder"]
  - id: "3"
    answers: ["content()"]
hints:
  - "The generic parameter is the type of whatever views the caller passes."
  - "The closure needs the builder so it can contain several views and an if."
  - "Store the built view, not the closure."
solution: |
  ```swift ios
  import SwiftUI

  struct TitledSection<Content: View>: View {
      let title: String
      let content: Content

      init(_ title: String, @ViewBuilder content: () -> Content) {
          self.title = title
          self.content = content()
      }

      var body: some View {
          VStack(alignment: .leading) {
              Text(title).font(.headline)
              content
          }
      }
  }

  struct AccountScreen: View {
      let isAdmin: Bool

      var body: some View {
          TitledSection("Account") {
              Text("Email")
              if isAdmin {
                  Text("Admin tools")
              }
          }
      }
  }
  ```

  `Content: View` keeps the caller's exact view type. `@ViewBuilder` on the parameter lets the caller list views and use `if`. Calling `content()` in the initializer stores the built view, the same pattern as the lesson's `Card`.
````

````exercise
id: m34-l03-e4
type: solve
prompt: |
  Write a result builder `ChecklistBuilder` that builds a `[String]` of checklist lines, so this code:

  ```swift
  func checklist(@ChecklistBuilder _ content: () -> [String]) -> [String] {
      content()
  }

  let hasPets = true
  let days = ["Mon", "Wed"]
  let items = checklist {
      "Passport"
      "Charger"
      if hasPets {
          "Pet food"
      }
      if days.count > 3 {
          "Laundry bag"
      } else {
          "Extra shirt"
      }
      for day in days {
          "Medicine for \(day)"
      }
  }
  for item in items {
      print("- [ ] " + item)
  }
  ```

  prints:

  ```output
  - [ ] Passport
  - [ ] Charger
  - [ ] Pet food
  - [ ] Extra shirt
  - [ ] Medicine for Mon
  - [ ] Medicine for Wed
  ```
starter: |
  @resultBuilder
  enum ChecklistBuilder {
      // buildExpression, buildBlock, buildOptional, buildEither, buildArray
  }
hints:
  - "Let buildExpression turn each String into a [String], so every other method works with arrays."
  - "buildBlock(_ parts: [String]...) flattens; buildOptional returns part ?? []."
  - "buildArray receives one [String] per loop iteration: [[String]]."
rubric:
  - Implements buildExpression(String) -> [String] and a variadic buildBlock that flattens.
  - buildOptional returns an empty array for nil.
  - Both buildEither methods pass their argument through.
  - buildArray flattens an array of arrays.
  - The printed checklist matches exactly.
solution: |
  ```swift
  @resultBuilder
  enum ChecklistBuilder {
      static func buildExpression(_ item: String) -> [String] {
          [item]
      }
      static func buildBlock(_ parts: [String]...) -> [String] {
          parts.flatMap { $0 }
      }
      static func buildOptional(_ part: [String]?) -> [String] {
          part ?? []
      }
      static func buildEither(first: [String]) -> [String] {
          first
      }
      static func buildEither(second: [String]) -> [String] {
          second
      }
      static func buildArray(_ parts: [[String]]) -> [String] {
          parts.flatMap { $0 }
      }
  }

  func checklist(@ChecklistBuilder _ content: () -> [String]) -> [String] {
      content()
  }

  let hasPets = true
  let days = ["Mon", "Wed"]
  let items = checklist {
      "Passport"
      "Charger"
      if hasPets {
          "Pet food"
      }
      if days.count > 3 {
          "Laundry bag"
      } else {
          "Extra shirt"
      }
      for day in days {
          "Medicine for \(day)"
      }
  }
  for item in items {
      print("- [ ] " + item)
  }
  ```

  ```output
  - [ ] Passport
  - [ ] Charger
  - [ ] Pet food
  - [ ] Extra shirt
  - [ ] Medicine for Mon
  - [ ] Medicine for Wed
  ```

  `buildExpression` makes every statement an array, so the other methods only deal with `[String]`. The loop's body is built once per day, and `buildArray` gets `[["Medicine for Mon"], ["Medicine for Wed"]]` and flattens it. Unlike `NodeBuilder`, this builder erases structure into a flat array, which is fine for a checklist but is exactly what SwiftUI avoids: it keeps the types so it can tell views apart.
````

````exercise
id: m34-l03-e5
type: find-errors
prompt: "This view doesn't compile, and one part would compile but behave badly. Which of these are real problems?"
code: |
  struct TagList: View {
      let tags: [String]
      let isEditing: Bool

      var body: some View {
          VStack(alignment: .leading) {
              print("rendering \(tags.count) tags")
              for tag in tags {
                  Text(tag)
              }
              footer
          }
      }

      var footer: some View {
          if isEditing {
              return AnyView(TextField("New tag", text: .constant("")))
          } else {
              return AnyView(Text("\(tags.count) tags"))
          }
      }
  }
choices:
  - text: "print(...) inside the stack's closure is a Void statement in a view builder; the compiler rejects it."
    correct: true
    why: "type '()' cannot conform to 'View'. Use let _ = print(...) for temporary debugging."
  - text: "The for loop isn't allowed in a view builder; it needs ForEach."
    correct: true
    why: "ViewBuilder has no buildArray. ForEach(tags, id: \\.self) { Text($0) } is the replacement."
  - text: "footer compiles, but switching isEditing changes the type inside AnyView, so SwiftUI rebuilds that part and any state in the text field is lost."
    correct: true
    why: "Apple's AnyView page: when the type changes, the old hierarchy is destroyed. A @ViewBuilder property with if-else is the better fix."
  - text: "footer must be a separate struct; computed properties can't return views."
    correct: false
    why: "Computed properties returning some View are fine; with conditionals they need @ViewBuilder."
  - text: "VStack(alignment: .leading) needs an explicit spacing argument."
    correct: false
    why: "spacing defaults to nil, which uses the system's default spacing."
rubric:
  - Flags the print statement inside the builder.
  - Flags the for loop and names ForEach as the fix.
  - Explains the AnyView problem in terms of identity or state, and suggests @ViewBuilder.
  - Doesn't flag the computed property or the default spacing.
solution: |
  Three real problems:

  1. **`print(…)`** is a statement whose value is `()`, and a view builder collects every expression's value: `type '()' cannot conform to 'View'`. Remove it, or write `let _ = print(…)` while debugging.
  2. **`for tag in tags`** needs `buildArray`, which `ViewBuilder` doesn't have. Write `ForEach(tags, id: \.self) { tag in Text(tag) }`.
  3. **`AnyView` in `footer`** compiles, but every time `isEditing` flips, the type inside changes and SwiftUI destroys and recreates that part of the hierarchy. Mark `footer` with `@ViewBuilder` and drop the `return`s and `AnyView`s:

  ```swift ios
  import SwiftUI

  struct TagList: View {
      let tags: [String]
      let isEditing: Bool
      @State private var newTag = ""

      var body: some View {
          VStack(alignment: .leading) {
              ForEach(tags, id: \.self) { tag in
                  Text(tag)
              }
              footer
          }
      }

      @ViewBuilder
      private var footer: some View {
          if isEditing {
              TextField("New tag", text: $newTag)
          } else {
              Text("\(tags.count) tags")
          }
      }
  }
  ```

  (`id: \.self` assumes tags are unique; lesson 5 explains why that matters.)
````

````exercise
id: m34-l03-e6
type: comprehension
prompt: "Why does a SwiftUI body with an if-else that shows a Text in one branch and an Image in the other satisfy some View, while a plain function with the same if-else and two returns doesn't?"
choices:
  - text: "The view builder wraps whichever branch runs in one conditional type, so body always returns the same concrete type."
    correct: true
    why: "buildEither(first:) and buildEither(second:) both return _ConditionalContent<TrueContent, FalseContent>."
  - text: "some View is type-erased, like any View, so any type is accepted."
    correct: false
    why: "some View is opaque: one concrete type, known to the compiler. That's why the plain function fails."
  - text: "SwiftUI checks the types at run time and converts them."
    correct: false
    why: "It's resolved at compile time by the builder transformation."
  - text: "Text and Image share a superclass."
    correct: false
    why: "They're unrelated structs; they only share the View protocol."
solution: |
  **One conditional type.** The builder turns the `if`-`else` into `buildEither(first:)` or `buildEither(second:)`, and both return `_ConditionalContent<Text, Image>`. That's a single concrete type, so the opaque `some View` is satisfied. The plain function has two `return` statements with different types, which an opaque return type doesn't allow.
````

## Summary

- A result builder is a type with static `build…` methods. Marking a closure, function or property with it makes the compiler collect each statement's value and combine them with those methods.
- `buildBlock` combines a block's values; `buildOptional`, `buildEither` and `buildArray` handle `if`, `if`-`else`/`switch` and `for`; `buildExpression` converts each expression first.
- Builders that keep exact types (like `ViewBuilder`) turn conditionals into one type that holds either branch, which is what lets `some View` work with `if`-`else`.
- `View`'s `body` gets the builder from the protocol. Your own computed properties and methods need `@ViewBuilder` when they list several views or branch.
- Write containers as generic views taking a `@ViewBuilder` closure and storing its result.
- `ViewBuilder` has no `buildArray`: use `ForEach`. Avoid `AnyView`; a change of the type inside it rebuilds the hierarchy and loses state.
